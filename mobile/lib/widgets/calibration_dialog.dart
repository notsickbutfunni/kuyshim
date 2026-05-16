/// CalibrationDialog — Modal dialog for calibrating dombra tuning.
///
/// Flow:
///   1. User opens dialog → AudioEngine starts listening
///   2. Dialog shows the standard dombra tuning format (D3 & G3).
///   3. User plays their open bass string (Lower String).
///   4. App captures stable frequency, compares to standard D3 (146.83 Hz)
///   5. Calculates offset in cents and saves via SharedPreferences
///   6. Shows result: "Your dombra is X cents sharp/flat"
///
/// Accessible from: Profile Settings → "Dombra Tuning"
library;
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/audio_engine.dart';
import '../services/language_service.dart';

/// Standard open bass string frequency for Dombra (D3 - 146.83 Hz)
const double _referenceHz = 146.83;

/// Show the calibration dialog.
Future<void> showCalibrationDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _CalibrationDialog(),
  );
}

class _CalibrationDialog extends StatefulWidget {
  const _CalibrationDialog();

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

enum _CalibrationStep { listening, done }

class _CalibrationDialogState extends State<_CalibrationDialog>
    with SingleTickerProviderStateMixin {
  final AudioEngine _engine = AudioEngine();
  _CalibrationStep _step = _CalibrationStep.listening;

  /// Collected stable frequency readings
  final List<double> _readings = [];
  static const int _requiredReadings = 8;

  /// Result
  double _detectedHz = 0.0;
  double _offsetCents = 0.0;

  Timer? _sampleTimer;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startListening();
  }

  Future<void> _startListening() async {
    await _engine.start();

    // Sample the microphone every 300ms
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_step != _CalibrationStep.listening) return;
      if (!_engine.isListening) return;

      final hz = _engine.currentHz;
      // Only accept readings in the plausible range for the bass string (D3)
      // D3 = 146.83 Hz, but allow range from ~130 Hz to ~165 Hz
      if (hz >= 130 && hz <= 165) {
        _readings.add(hz);
        if (mounted) setState(() {});

        if (_readings.length >= _requiredReadings) {
          _finishCalibration();
        }
      }
    });
  }

  void _finishCalibration() {
    _sampleTimer?.cancel();
    _pulseCtrl.stop();

    // Calculate median of readings for robustness
    final sorted = List<double>.from(_readings)..sort();
    _detectedHz = sorted[sorted.length ~/ 2];

    // Calculate offset in cents from D3 reference
    _offsetCents = 1200 * math.log(_detectedHz / _referenceHz) / math.ln2;

    _saveCalibration();

    setState(() {
      _step = _CalibrationStep.done;
    });
  }

  Future<void> _saveCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dombra_calibration_cents', _offsetCents);
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _pulseCtrl.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 600 ? 500.0 : size.width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: KColors.background, // Fast opaque background
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: KColors.emerald.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: KColors.emerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: KColors.emerald,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.dombraTuning,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              t.standardTuning, // 'Standard Tuning (Oń Buraý)'
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Standard Tuning Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard Format',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: KColors.emerald.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildStringInstruction(
                          title: 'Upper String (Üstingi)',
                          note: 'G3 (196.0 Hz)',
                          icon: Icons.music_note,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.white12, height: 1),
                        ),
                        _buildStringInstruction(
                          title: 'Lower String (Astyngy)',
                          note: 'D3 (146.8 Hz)',
                          icon: Icons.music_note_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Body — depends on step
                  if (_step == _CalibrationStep.listening)
                    _buildListeningBody(t)
                  else
                    _buildDoneBody(t),

                  const SizedBox(height: 24),

                  // Bottom actions
                  _buildActions(t),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildStringInstruction({
    required String title,
    required String note,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          note,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: KColors.emerald.withOpacity(0.8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildListeningBody(dynamic t) {
    final progress = _readings.length / _requiredReadings;
    final liveHz = _engine.currentHz;

    return Column(
      children: [
        // Pulsing mic indicator
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final scale = 1.0 + 0.15 * math.sin(_pulseCtrl.value * 2 * math.pi);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KColors.emerald.withOpacity(0.1),
                  border: Border.all(
                    color: KColors.emerald.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KColors.emerald.withOpacity(0.2 * _pulseCtrl.value),
                      blurRadius: 30,
                      spreadRadius: 10 * _pulseCtrl.value,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 36,
                  color: liveHz > 0
                      ? KColors.emerald
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Instruction
        Text(
          t.playOpenBass, // "Play open bass string"
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        Text(
          'Target: D3 (146.8 Hz)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: KColors.emerald.withOpacity(0.7),
          ),
        ),

        const SizedBox(height: 8),

        // Live Hz display
        Text(
          liveHz > 0 ? '${liveHz.toStringAsFixed(1)} Hz' : '— Hz',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: liveHz > 0 ? KColors.emerald : Colors.white24,
          ),
        ),

        const SizedBox(height: 16),

        // Progress bar
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.calibrating,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                Text(
                  '${_readings.length}/$_requiredReadings',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    color: KColors.emerald.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(KColors.emerald),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoneBody(dynamic t) {
    final absOffset = _offsetCents.abs().round();
    final isSharp = _offsetCents > 0;
    final direction = isSharp ? t.centsSharp : t.centsFlat;

    return Column(
      children: [
        // Success icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KColors.emerald.withOpacity(0.15),
            border: Border.all(
              color: KColors.emerald.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 40,
            color: KColors.emerald,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          t.calibrationComplete,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: KColors.emerald,
          ),
        ),

        const SizedBox(height: 12),

        // Detected frequency
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Text(
                '${_detectedHz.toStringAsFixed(1)} Hz',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                absOffset <= 5
                    ? t.perfectTune
                    : '$absOffset $direction',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: absOffset <= 5 ? KColors.emerald : KColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(dynamic t) {
    return Row(
      children: [
        if (_step == _CalibrationStep.done) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _readings.clear();
                setState(() => _step = _CalibrationStep.listening);
                _startListening();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                t.tryAgain,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              _step == _CalibrationStep.done ? t.done : t.cancel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
