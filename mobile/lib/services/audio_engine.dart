/// AudioEngine — сервис захвата микрофона и определения высоты тона (pitch) в реальном времени.
///
/// Использует [flutter_audio_capture] для получения потока сырых PCM-сэмплов
/// и [pitch_detector_dart] (алгоритм Yin) для определения частоты (Hz).
///
/// Архитектура:
///   - AudioEngine изолирован от UI — предоставляет только currentHz и currentNote.
///   - GameScreen использует эти значения в игровом цикле для проверки попаданий.
///   - При dispose() все ресурсы (микрофон, подписки) корректно освобождаются.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';

/// Таблица соответствия нот → частоты (Hz) для домбры.
/// Тюнинг: бас — A2 (110 Hz), верхняя — D3 (146.83 Hz), 9 ладов.
const Map<String, double> _noteFrequencies = {
  'A2': 110.00,
  'A#2': 116.54,
  'B2': 123.47,
  'C3': 130.81,
  'C#3': 138.59,
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
};

class AudioEngine {
  // ── Конфигурация ──────────────────────────────────────────────
  /// Частота дискретизации (44100 — стандарт для большинства устройств)
  static const int sampleRate = 44100;

  /// Размер буфера для pitch detection (степень двойки)
  static const int bufferSize = 2048;

  /// Минимальная пороговая громкость (RMS) для фильтрации тишины.
  /// Если сигнал ниже порога — считаем, что звука нет.
  static const double silenceThreshold = 0.02;

  // ── Внутренние объекты ────────────────────────────────────────
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  late final PitchDetector _pitchDetector;

  /// Буфер аудио-сэмплов для накопления до нужного размера
  final List<double> _audioBuffer = [];

  /// Флаг, чтобы не обрабатывать несколько чанков одновременно
  bool _isProcessing = false;

  // ── Публичное состояние (читается из UI) ─────────────────────
  /// Текущая определённая частота в Hz (0.0 если тишина)
  double currentHz = 0.0;

  /// Текущая определённая нота ("-" если тишина / не определено)
  String currentNote = '-';

  /// Флаг: работает ли микрофон
  bool isListening = false;

  /// Callback для уведомления UI об обновлении данных
  VoidCallback? onPitchDetected;

  // ── Инициализация ─────────────────────────────────────────────
  AudioEngine() {
    _pitchDetector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: bufferSize,
    );
  }

  /// Запуск микрофона и начало прослушивания.
  ///
  /// Аудио-сэмплы поступают через callback [_onAudioData],
  /// накапливаются в буфере и обрабатываются pitch-детектором.
  Future<void> start() async {
    if (isListening) return; // Уже запущен — ничего не делаем

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
      debugPrint('[AudioEngine] Микрофон запущен (sampleRate=$sampleRate)');
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
    _audioBuffer.clear();
    currentHz = 0.0;
    currentNote = '-';
    debugPrint('[AudioEngine] Микрофон остановлен');
  }

  /// Полная очистка ресурсов. Вызывать в dispose() виджета.
  Future<void> dispose() async {
    await stop();
  }

  // ── Обработка аудио-потока ────────────────────────────────────

  /// Callback: получаем сырые PCM-сэмплы от микрофона.
  /// flutter_audio_capture 1.1.12 передаёт Float32List.
  void _onAudioData(Float32List data) {
    // Конвертируем Float32List → List<double> для pitch_detector_dart
    final samples = data.map((f) => f.toDouble()).toList();

    // Добавляем новые сэмплы в накопительный буфер
    _audioBuffer.addAll(samples);

    // Обрабатываем, когда накопилось достаточно для pitch detection
    if (_audioBuffer.length >= bufferSize && !_isProcessing) {
      final chunk = List<double>.from(_audioBuffer.sublist(0, bufferSize));
      _audioBuffer.removeRange(0, bufferSize);
      _processChunk(chunk);
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
          onPitchDetected?.call();
        }
        _isProcessing = false;
        return;
      }

      // 2. Определяем высоту тона (pitch) — асинхронный метод
      final result = await _pitchDetector.getPitchFromFloatBuffer(chunk);

      if (result.pitched) {
        final detectedHz = result.pitch;

        // Фильтруем нереалистичные значения для домбры (80–500 Hz)
        if (detectedHz >= 80 && detectedHz <= 500) {
          currentHz = detectedHz;
          currentNote = _hzToNoteName(detectedHz);
          onPitchDetected?.call();
        }
      } else {
        // Pitch не определён (шум / неразборчиво)
        if (currentHz != 0.0) {
          currentHz = 0.0;
          currentNote = '-';
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

  /// Проверяет, совпадает ли текущая частота с целевой (с допуском ±tolerance Hz).
  ///
  /// [targetHz] — ожидаемая частота ноты из карты.
  /// [toleranceHz] — допустимая погрешность (по умолчанию 7 Hz для акустического инструмента).
  ///
  /// Возвращает true, если |currentHz - targetHz| <= toleranceHz.
  bool isFrequencyMatch(double targetHz, {double toleranceHz = 7.0}) {
    if (currentHz <= 0.0) return false; // Тишина — не совпадение
    return (currentHz - targetHz).abs() <= toleranceHz;
  }
}
