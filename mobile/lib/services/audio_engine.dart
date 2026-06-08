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
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Таблица соответствия нот → частоты (Hz) для домбры.
/// Тюнинг Оң бұрау: бас (үстіңгі ішек) — D3 (146.83 Hz), мелодия (астыңғы ішек) — G3 (196.00 Hz).
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
const String _calibrationBassKey = 'dombra_calibration_bass_cents';
const String _calibrationTrebleKey = 'dombra_calibration_treble_cents';

class AudioEngine extends ChangeNotifier {
  // ── Конфигурация ──────────────────────────────────────────────
  /// Requested sample rate. The actual rate may differ — see [_actualSampleRate].
  static const int _requestedSampleRate = 44100;

  /// Actual sample rate the device opened with.
  /// Populated in [start()]. Defaults to requested rate.
  int _actualSampleRate = _requestedSampleRate;

  /// Размер буфера для pitch detection (степень двойки).
  /// 4096 samples @ 44100 Hz ≈ 93 ms — captures ~13 full cycles of the
  /// lowest dombra note (D3 ≈ 146 Hz), giving YIN plenty of data.
  static const int bufferSize = 4096;

  static const double silenceThreshold = 0.012;

  /// Количество фреймов для медианного сглаживания pitch.
  /// Reduced from 3→2 to cut ~93ms of latency — each chunk is ~93ms,
  /// so window=2 stabilizes in ~186ms instead of ~279ms.
  static const int _smoothingWindow = 2;

  // ── Внутренние объекты ────────────────────────────────────────
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  PitchDetector? _pitchDetector;

  /// Предварительно выделенный буфер фиксированного размера для избежания аллокаций
  final Float64List _audioBuffer = Float64List(bufferSize);
  int _bufferIndex = 0;

  /// Флаг, чтобы не обрабатывать несколько чанков одновременно
  bool _isProcessing = false;

  /// История pitch значений для медианного сглаживания
  final List<double> _pitchHistory = [];

  /// RMS value from previous chunk — used for onset (pluck) detection.
  double _previousRms = 0.0;

  /// Timestamp (ms since epoch) of the last detected onset (pluck).
  int _lastOnsetMs = 0;

  /// Number of leading samples to trim from an onset chunk.
  /// YIN is unreliable during the first ~30ms of a pluck (transient noise),
  /// but we no longer skip the entire ~93ms chunk — instead we trim only the
  /// transient and analyze the remaining stable portion.
  int _onsetTrimSamples = 0; // computed in start() from actual sample rate

  /// Minimum RMS ratio (current / previous) to count as a pluck.
  /// Lowered from 2.0→1.6 to catch lighter grace-note re-plucks.
  static const double _onsetRmsRatio = 1.6;

  /// Minimum absolute RMS to trigger onset (prevents micro-noise spikes).
  static const double _onsetMinRms = 0.012;

  /// How long (ms) an onset is considered "recent" for game matching.
  /// Must exceed the game's goodWindowMs (now 450ms) to cover the full hit window.
  static const int _onsetWindowMs = 600;

  // ── Публичное состояние (читается из UI) ─────────────────────
  /// Текущая определённая частота в Hz (0.0 если тишина)
  double currentHz = 0.0;

  /// Текущая определённая нота ("-" если тишина / не определено)
  String currentNote = '-';

  /// Флаг: работает ли микрофон
  bool isListening = false;

  /// Callback для уведомления UI об обновлении данных
  VoidCallback? onPitchDetected;

  /// Whether a pluck (onset) was detected recently.
  /// Used by GameScreen to require an actual pluck instead of sustained noise.
  /// Onset is detected via sudden RMS spike, not by frequency appearing.
  bool get hasRecentOnset =>
      DateTime.now().millisecondsSinceEpoch - _lastOnsetMs < _onsetWindowMs;

  // ── Калибровка ────────────────────────────────────────────────
  /// Смещение тюнинга домбры в центах для басовой струны D3 (Үстіңгі ішек).
  double calibrationBassCents = 0.0;

  /// Смещение тюнинга домбры в центах для высокой струны G3 (Астыңғы ішек).
  double calibrationTrebleCents = 0.0;

  /// Откалиброванная частота: currentHz со смещением на калибровку.
  /// Выбирает соответствующее смещение в зависимости от диапазона частот (разделитель 170 Гц).
  /// Используется в основном для вывода на UI.
  double get calibratedHz {
    if (currentHz <= 0.0) return 0.0;
    final double offset = currentHz < 170.0 ? calibrationBassCents : calibrationTrebleCents;
    return currentHz * math.pow(2, -offset / 1200.0);
  }

  // ── Инициализация ─────────────────────────────────────────────
  AudioEngine();

  /// (Re-)creates the pitch detector with the given sample rate.
  void _initPitchDetector(int rate) {
    _actualSampleRate = rate;
    _pitchDetector = PitchDetector(
      audioSampleRate: rate.toDouble(),
      bufferSize: bufferSize,
    );
  }

  /// Загружает сохранённую калибровку из SharedPreferences.
  Future<void> loadCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      calibrationBassCents = prefs.getDouble(_calibrationBassKey) ?? 0.0;
      calibrationTrebleCents = prefs.getDouble(_calibrationTrebleKey) ?? 0.0;
      debugPrint('[AudioEngine] Калибровка загружена: Bass=${calibrationBassCents.toStringAsFixed(1)}c, Treble=${calibrationTrebleCents.toStringAsFixed(1)}c');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка загрузки калибровки: $e');
      calibrationBassCents = 0.0;
      calibrationTrebleCents = 0.0;
    }
  }

  /// Сохраняет калибровку в SharedPreferences.
  Future<void> saveCalibration(double bassCents, double trebleCents) async {
    calibrationBassCents = bassCents;
    calibrationTrebleCents = trebleCents;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_calibrationBassKey, bassCents);
      await prefs.setDouble(_calibrationTrebleKey, trebleCents);
      debugPrint('[AudioEngine] Калибровка сохранена: Bass=${bassCents.toStringAsFixed(1)}c, Treble=${trebleCents.toStringAsFixed(1)}c');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка сохранения калибровки: $e');
    }
    notifyListeners();
  }

  /// Сбрасывает калибровку к стандартному тюнингу.
  Future<void> resetCalibration() async {
    await saveCalibration(0.0, 0.0);
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

      // Use the requested rate; the device may negotiate a different one.
      // We pass bufferSize (4096) as the capture chunk size as well so
      // that each callback delivers exactly one processing window.
      await _audioCapture.start(
        _onAudioData,   // listener: получает Float32List
        _onAudioError,  // onError: обработчик ошибок
        sampleRate: _requestedSampleRate,
        bufferSize: bufferSize,
      );

      // Determine the actual sample rate the hardware is using.
      // Android's AudioRecord typically honours 44100 Hz; iOS AVAudioSession
      // often defaults to 48000 Hz. When the OS resamples transparently
      // the pitch math still works, but when it doesn't, we need the
      // correct rate. Use platform detection as a best-effort heuristic.
      int actualRate = _requestedSampleRate;
      if (Platform.isIOS) {
        // iOS commonly forces 48000
        actualRate = 48000;
      }
      _initPitchDetector(actualRate);
      _onsetTrimSamples = (actualRate * 0.025).round(); // trim ~25ms of transient

      isListening = true;
      _pitchHistory.clear();
      debugPrint('[AudioEngine] Микрофон запущен (requested=$_requestedSampleRate, actual=$_actualSampleRate, bufferSize=$bufferSize, calibration: Bass=${calibrationBassCents.toStringAsFixed(1)}c, Treble=${calibrationTrebleCents.toStringAsFixed(1)}c)');
    } catch (e) {
      debugPrint('[AudioEngine] Ошибка запуска микрофона: $e');
      // Fallback: initialise pitch detector with requested rate anyway
      _initPitchDetector(_requestedSampleRate);
      _onsetTrimSamples = (_requestedSampleRate * 0.025).round();
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
    _previousRms = 0.0;
    _onsetTrimSamples = 0;
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
      debugPrint('[AudioEngine] chunk RMS=${rms.toStringAsFixed(4)}, prevRMS=${_previousRms.toStringAsFixed(4)}');

      // 2. Onset detection: detect pluck via sudden RMS spike.
      //    Case A: sound appearing from silence.
      //    Case B: sudden loudness jump (new pluck during sustain/decay).
      final bool isOnset = rms >= _onsetMinRms && (
          _previousRms < silenceThreshold ||
          rms / _previousRms >= _onsetRmsRatio
      );
      _previousRms = rms;

      if (isOnset) {
        _lastOnsetMs = DateTime.now().millisecondsSinceEpoch;
        _pitchHistory.clear(); // Fresh start — don't dilute new pitch with old
        debugPrint('[AudioEngine] Onset detected! RMS=${rms.toStringAsFixed(4)}');
        // Trim the transient attack (~25ms) instead of skipping the entire chunk.
        // This preserves ~68ms of usable stable pitch data.
        if (_onsetTrimSamples > 0 && chunk.length > _onsetTrimSamples * 2) {
          // Trim the transient attack (~25ms) by taking the sublist, and then pad
          // it back to the expected bufferSize (4096) by wrapping/repeating the
          // stable portion to avoid InvalidAudioBufferException in PitchDetector.
          final stablePortion = chunk.sublist(_onsetTrimSamples);
          final padded = Float64List(bufferSize);
          for (int i = 0; i < bufferSize; i++) {
            padded[i] = stablePortion[i % stablePortion.length];
          }
          chunk = padded;
        }
      }

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

      // No longer skipping entire onset chunks — transient is trimmed above.

      // 2. Определяем высоту тона (pitch) — асинхронный метод
      if (_pitchDetector == null) {
        _isProcessing = false;
        return;
      }
      final result = await _pitchDetector!.getPitchFromFloatBuffer(chunk);

      if (result.pitched) {
        final detectedHz = result.pitch;
        debugPrint('[AudioEngine] YIN pitched=true, rawHz=${detectedHz.toStringAsFixed(1)}');

        // Фильтруем нереалистичные значения для домбры:
        // A2 (110 Hz) — G#4 (415 Hz) с небольшим запасом.
        // Голос человека (85–255 Hz) частично перекрывается, но
        // onset detection + tolerance 50¢ отсекают ложные срабатывания.
        if (detectedHz >= 100 && detectedHz <= 420) {
          // Применяем медианное сглаживание для стабильности
          final smoothedHz = _smoothedPitch(detectedHz);

          currentHz = smoothedHz;
          currentNote = _hzToNoteName(calibratedHz);
          debugPrint('[AudioEngine] ✓ ACCEPTED rawHz=${detectedHz.toStringAsFixed(1)} → smoothed=${smoothedHz.toStringAsFixed(1)} note=$currentNote');
          notifyListeners();
          onPitchDetected?.call();
        } else {
          debugPrint('[AudioEngine] ✗ REJECTED rawHz=${detectedHz.toStringAsFixed(1)} — outside 100-420 range');
        }
      } else {
        debugPrint('[AudioEngine] YIN pitched=false (unpitched/noise)');
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
  /// Previously this returned mean-squared (no sqrt), making the effective
  /// threshold much higher than intended and choking sustained notes.
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / samples.length);
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
  bool isFrequencyMatch(double targetHz, {double toleranceCents = 50.0, String stringName = 'bass'}) {
    if (currentHz <= 0.0 || targetHz <= 0.0) return false;

    // Apply the offset corresponding to the string being checked
    double centsOffset = 0.0;
    if (stringName == 'bass') {
      centsOffset = calibrationBassCents;
    } else if (stringName == 'treble') {
      centsOffset = calibrationTrebleCents;
    } else {
      // 'both' or unknown -> use average
      centsOffset = (calibrationBassCents + calibrationTrebleCents) / 2;
    }

    final calibrated = currentHz * math.pow(2, -centsOffset / 1200.0);
    final cents = (1200.0 * (math.log(calibrated / targetHz) / math.ln2)).abs();
    return cents <= toleranceCents;
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
