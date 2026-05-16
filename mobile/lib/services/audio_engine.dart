/// AudioEngine — сервис захвата микрофона и определения высоты тона (pitch) в реальном времени.
///
/// Использует [flutter_audio_capture] для получения потока сырых PCM-сэмплов
/// и [pitch_detector_dart] (алгоритм Yin) для определения частоты (Hz).
///
/// Архитектура:
///   - AudioEngine изолирован от UI — предоставляет только currentHz и currentNote.
///   - GameScreen использует эти значения в игровом цикле для проверки попаданий.
///   - При dispose() все ресурсы (микрофон, подписки) корректно освобождаются.
///   - Поддерживает калибровку тюнинга домбры (смещение в центах).
///   - Использует pitch smoothing (медианный фильтр) для стабильности.
library;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Таблица соответствия нот → частоты (Hz) для домбры.
/// Тюнинг: бас — A2 (110 Hz), верхняя — D3 (146.83 Hz).
/// Расширена до 19 ладов (покрывает полный диапазон до G4).
const Map<String, double> _noteFrequencies = {
  // Bass string open + frets (A2 upward)
  'A2': 110.00,
  'A#2': 116.54,
  'B2': 123.47,
  'C3': 130.81,
  'C#3': 138.59,
  // Treble string open (D3) — overlap zone
  'D3': 146.83,
  'D#3': 155.56,
  'E3': 164.81,
  'F3': 174.61,
  'F#3': 185.00,
  'G3': 196.00,
  'G#3': 207.65,
  'A3': 220.00,
  'A#3': 233.08,
  'B3': 246.94,
  // Extended range for higher frets (frets 10-18)
  'C4': 261.63,
  'C#4': 277.18,
  'D4': 293.66,
  'D#4': 311.13,
  'E4': 329.63,
  'F4': 349.23,
  'F#4': 369.99,
  'G4': 392.00,
};

/// SharedPreferences key for calibration offset
const String _calibrationKey = 'dombra_calibration_cents';

class AudioEngine extends ChangeNotifier {
  // ── Конфигурация ──────────────────────────────────────────────
  /// Частота дискретизации (44100 — стандарт для большинства устройств)
  static const int sampleRate = 44100;

  /// Размер буфера для pitch detection (степень двойки)
  static const int bufferSize = 2048;

  /// Минимальная пороговая громкость (RMS) для фильтрации тишины.
  /// Если сигнал ниже порога — считаем, что звука нет.
  static const double silenceThreshold = 0.015;

  /// Количество фреймов для медианного сглаживания pitch
  static const int _smoothingWindow = 3;

  // ── Внутренние объекты ────────────────────────────────────────
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  late final PitchDetector _pitchDetector;

  /// Предварительно выделенный буфер фиксированного размера для избежания аллокаций
  final Float64List _audioBuffer = Float64List(bufferSize);
  int _bufferIndex = 0;

  /// Флаг, чтобы не обрабатывать несколько чанков одновременно
  bool _isProcessing = false;

  /// История pitch значений для медианного сглаживания
  final List<double> _pitchHistory = [];

  // ── Публичное состояние (читается из UI) ─────────────────────
  /// Текущая определённая частота в Hz (0.0 если тишина)
  double currentHz = 0.0;

  /// Текущая определённая нота ("-" если тишина / не определено)
  String currentNote = '-';

  /// Флаг: работает ли микрофон
  bool isListening = false;

  /// Callback для уведомления UI об обновлении данных
  VoidCallback? onPitchDetected;

  // ── Калибровка ────────────────────────────────────────────────
  /// Смещение тюнинга домбры в центах.
  /// Положительное = домбра настроена выше стандарта (sharp).
  /// Отрицательное = домбра настроена ниже стандарта (flat).
  /// Используется для корректировки определённой частоты перед сравнением.
  double calibrationCents = 0.0;

  /// Откалиброванная частота: currentHz со смещением на calibrationCents.
  /// Если калибровка = 0, возвращает currentHz без изменений.
  double get calibratedHz {
    if (currentHz <= 0.0 || calibrationCents == 0.0) return currentHz;
    // Сдвигаем определённую частоту в обратную сторону от смещения,
    // чтобы компенсировать разницу в тюнинге.
    return currentHz * math.pow(2, -calibrationCents / 1200.0);
  }

  // ── Инициализация ─────────────────────────────────────────────
  AudioEngine() {
    _pitchDetector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: bufferSize,
    );
  }

  /// Загружает сохранённую калибровку из SharedPreferences.
  Future<void> loadCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      calibrationCents = prefs.getDouble(_calibrationKey) ?? 0.0;
      debugPrint('[AudioEngine] Калибровка загружена: ${calibrationCents.toStringAsFixed(1)} центов');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка загрузки калибровки: $e');
      calibrationCents = 0.0;
    }
  }

  /// Сохраняет калибровку в SharedPreferences.
  Future<void> saveCalibration(double cents) async {
    calibrationCents = cents;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_calibrationKey, cents);
      debugPrint('[AudioEngine] Калибровка сохранена: ${cents.toStringAsFixed(1)} центов');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка сохранения калибровки: $e');
    }
    notifyListeners();
  }

  /// Сбрасывает калибровку к стандартному тюнингу.
  Future<void> resetCalibration() async {
    await saveCalibration(0.0);
  }

  /// Запуск микрофона и начало прослушивания.
  ///
  /// Аудио-сэмплы поступают через callback [_onAudioData],
  /// накапливаются в буфере и обрабатываются pitch-детектором.
  Future<void> start() async {
    if (isListening) return; // Уже запущен — ничего не делаем

    // Загружаем калибровку при старте
    await loadCalibration();

    try {
      // Запрашиваем разрешение на микрофон перед инициализацией
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('[AudioEngine] Отказ в доступе к микрофону');
        return;
      }

      // flutter_audio_capture требует init() перед start()
      await _audioCapture.init();

      await _audioCapture.start(
        _onAudioData,   // listener: получает Float32List
        _onAudioError,  // onError: обработчик ошибок
        sampleRate: sampleRate,
        bufferSize: 3000,
      );
      isListening = true;
      _pitchHistory.clear();
      debugPrint('[AudioEngine] Микрофон запущен (sampleRate=$sampleRate, calibration=${calibrationCents.toStringAsFixed(1)}c)');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка запуска микрофона: $e');
      isListening = false;
    }
  }

  /// Остановка микрофона и очистка буфера.
  Future<void> stop() async {
    if (!isListening) return;

    try {
      await _audioCapture.stop();
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка остановки микрофона: $e');
    }

    isListening = false;
    _bufferIndex = 0;
    _pitchHistory.clear();
    currentHz = 0.0;
    currentNote = '-';
    debugPrint('[AudioEngine] Микрофон остановлен');
  }

  /// Полная очистка ресурсов. Вызывать в dispose() виджета.
  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ── Обработка аудио-потока ────────────────────────────────────

  /// Callback: получаем сырые PCM-сэмплы от микрофона.
  /// flutter_audio_capture 1.1.12 передаёт Float32List.
  void _onAudioData(Float32List data) {
    if (_isProcessing) return; // Пропускаем фреймы если не успеваем, предотвращает утечки памяти

    for (int i = 0; i < data.length; i++) {
      _audioBuffer[_bufferIndex++] = data[i].toDouble();

      // Обрабатываем, когда накопилось достаточно для pitch detection
      if (_bufferIndex >= bufferSize) {
        final chunk = Float64List.fromList(_audioBuffer); // Копируем для асинхронной обработки
        _bufferIndex = 0;
        _processChunk(chunk);
        break; // Обрабатываем только один чанк за вызов, чтобы не блокировать
      }
    }
  }

  /// Callback: ошибка в аудио-потоке.
  void _onAudioError(Object error) {
    debugPrint('[AudioEngine] Ошибка аудио-потока: $error');
  }

  /// Обработка одного чанка (буфера) аудио-данных.
  Future<void> _processChunk(List<double> chunk) async {
    _isProcessing = true;

    try {
      // 1. Проверяем, есть ли звук (RMS > порог тишины)
      final rms = _calculateRMS(chunk);

      if (rms < silenceThreshold) {
        // Тишина — сбрасываем текущие значения
        if (currentHz != 0.0) {
          currentHz = 0.0;
          currentNote = '-';
          _pitchHistory.clear();
          notifyListeners();
          onPitchDetected?.call();
        }
        _isProcessing = false;
        return;
      }

      // 2. Определяем высоту тона (pitch) — асинхронный метод
      final result = await _pitchDetector.getPitchFromFloatBuffer(chunk);

      if (result.pitched) {
        final detectedHz = result.pitch;

        // Фильтруем нереалистичные значения для домбры (80–600 Hz)
        // Расширен верхний предел для высоких ладов
        if (detectedHz >= 80 && detectedHz <= 600) {
          // Применяем медианное сглаживание для стабильности
          final smoothedHz = _smoothedPitch(detectedHz);

          currentHz = smoothedHz;
          currentNote = _hzToNoteName(calibratedHz);
          notifyListeners();
          onPitchDetected?.call();
        }
      } else {
        // Pitch не определён (шум / неразборчиво)
        if (currentHz != 0.0) {
          currentHz = 0.0;
          currentNote = '-';
          _pitchHistory.clear();
          notifyListeners();
          onPitchDetected?.call();
        }
      }
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка pitch detection: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Утилиты ───────────────────────────────────────────────────

  /// Медианный фильтр для сглаживания pitch-значений.
  /// Уменьшает дрожание (jitter) от фрейма к фрейму.
  double _smoothedPitch(double rawHz) {
    _pitchHistory.add(rawHz);
    if (_pitchHistory.length > _smoothingWindow) {
      _pitchHistory.removeAt(0);
    }
    // Если недостаточно данных — возвращаем как есть
    if (_pitchHistory.length < 2) return rawHz;
    // Медиана
    final sorted = List<double>.from(_pitchHistory)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Вычисляет RMS (Root Mean Square) — среднюю громкость буфера.
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    return (sumSquares / samples.length).clamp(0.0, 1.0);
  }

  /// Определяет ближайшую ноту по частоте (Hz).
  /// Сравнивает со всеми нотами из таблицы домбры и возвращает ближайшую.
  String _hzToNoteName(double hz) {
    String closestNote = '-';
    double minDiff = double.infinity;

    for (final entry in _noteFrequencies.entries) {
      final diff = (hz - entry.value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNote = entry.key;
      }
    }

    return closestNote;
  }

  /// Проверяет, совпадает ли текущая (откалиброванная) частота с целевой.
  ///
  /// Использует **цент-основанную** систему допуска вместо фиксированных Hz.
  /// 100 центов = 1 полутон. По умолчанию 60 центов (~чуть больше половины полутона).
  ///
  /// [targetHz] — ожидаемая частота ноты из карты.
  /// [toleranceCents] — допустимая погрешность в центах (по умолчанию 60).
  ///
  /// Цент-основанная система даёт одинаковую музыкальную точность
  /// на всех частотах (в отличие от фиксированных Hz).
  bool isFrequencyMatch(double targetHz, {double toleranceCents = 80.0}) {
    final hz = calibratedHz;
    if (hz <= 0.0 || targetHz <= 0.0) return false;

    // Расстояние в центах: cents = 1200 * log2(f1 / f2)
    final cents = (1200.0 * (math.log(hz / targetHz) / math.ln2)).abs();
    
    // Допускаем совпадение на октаву (1200 центов разницы) из-за особенностей pitch detection
    final centsModulo = cents % 1200.0;
    final distanceToOctave = math.min(centsModulo, 1200.0 - centsModulo);
    
    return cents <= toleranceCents || distanceToOctave <= toleranceCents;
  }

  /// Вычисляет смещение калибровки в центах между определённой частотой
  /// и эталонной частотой.
  ///
  /// Используется в CalibrationDialog для расчёта offset.
  static double calculateCentsOffset(double detectedHz, double referenceHz) {
    if (detectedHz <= 0 || referenceHz <= 0) return 0.0;
    return 1200.0 * (math.log(detectedHz / referenceHz) / math.ln2);
  }
}
