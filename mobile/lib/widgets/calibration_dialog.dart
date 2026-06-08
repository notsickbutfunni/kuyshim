/// CalibrationDialog — Modal dialog for calibrating dombra tuning.
///
/// Features a semicircular gauge (like a half-clock / speedometer) with a
/// needle that shows real-time pitch deviation. Center = perfect tune.
///
/// Standard Tuning: Оң бұрау (G3-D3)
///   Bottom String (Астыңғы ішек — melody string): G3 = 196.00 Hz
///   Top String (Үстіңгі ішек — drone string):    D3 = 146.83 Hz
///
/// Accessible from: Profile Settings → "Dombra Tuning"
library;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/audio_engine.dart';
import '../services/language_service.dart';

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

/// Calibration proceeds: first the top string (D3, lower pitch),
/// then the bottom string (G3, higher pitch).
enum _CalibrationStep { listeningBass, listeningTreble, done }

class _CalibrationDialogState extends State<_CalibrationDialog>
    with TickerProviderStateMixin {
  final AudioEngine _engine = AudioEngine();
  _CalibrationStep _step = _CalibrationStep.listeningBass;

  /// Collected stable frequency readings
  final List<double> _readings = [];
  static const int _requiredReadings = 8;

  // References — Оң бұрау standard tuning
  // Top string (Үстіңгі ішек) = drone string = D3
  static const double _referenceBassHz = 146.83; // D3
  // Bottom string (Астыңғы ішек) = melody string = G3
  static const double _referenceTrebleHz = 196.00; // G3

  /// Results
  double _bassDetectedHz = 0.0;
  double _trebleDetectedHz = 0.0;
  double _bassOffsetCents = 0.0;
  double _trebleOffsetCents = 0.0;

  /// Live cents offset for the gauge needle
  double _liveCentsOffset = 0.0;

  Timer? _sampleTimer;

  late AnimationController _pulseCtrl;
  late AnimationController _needleCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _needleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startListening();
  }

  Future<void> _startListening() async {
    await _engine.start();

    _sampleTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_step == _CalibrationStep.done) return;
      if (!_engine.isListening) return;

      final hz = _engine.currentHz;
      if (hz <= 0.0) {
        if (mounted) setState(() => _liveCentsOffset = 0.0);
        return;
      }

      final isBass = _step == _CalibrationStep.listeningBass;
      final targetHz = isBass ? _referenceBassHz : _referenceTrebleHz;
      // D3 range: 120-175 Hz, G3 range: 160-230 Hz
      final minHz = isBass ? 120.0 : 160.0;
      final maxHz = isBass ? 175.0 : 230.0;

      // Calculate live cents offset for needle
      if (hz >= minHz * 0.7 && hz <= maxHz * 1.3) {
        final cents = 1200.0 * (math.log(hz / targetHz) / math.ln2);
        if (mounted) {
          setState(() => _liveCentsOffset = cents.clamp(-50.0, 50.0));
        }
      }

      if (hz >= minHz && hz <= maxHz) {
        // Require onset to start collecting
        if (_readings.isEmpty && !_engine.hasRecentOnset) {
          return;
        }

        // Cents-based stability check
        if (_readings.isNotEmpty) {
          final lastHz = _readings.last;
          final centsDiff = (1200.0 * (math.log(hz / lastHz) / math.ln2)).abs();
          if (centsDiff > 15.0) {
            _readings.clear();
            if (mounted) setState(() {});
            return;
          }
        }

        _readings.add(hz);
        if (mounted) setState(() {});

        if (_readings.length >= _requiredReadings) {
          _advanceStep();
        }
      }
    });
  }

  void _advanceStep() {
    final sorted = List<double>.from(_readings)..sort();
    final medianHz = sorted[sorted.length ~/ 2];

    if (_step == _CalibrationStep.listeningBass) {
      _bassDetectedHz = medianHz;
      _bassOffsetCents = 1200 * math.log(_bassDetectedHz / _referenceBassHz) / math.ln2;
      _readings.clear();
      setState(() {
        _step = _CalibrationStep.listeningTreble;
        _liveCentsOffset = 0.0;
      });
    } else if (_step == _CalibrationStep.listeningTreble) {
      _trebleDetectedHz = medianHz;
      _trebleOffsetCents = 1200 * math.log(_trebleDetectedHz / _referenceTrebleHz) / math.ln2;
      _finishCalibration();
    }
  }

  void _finishCalibration() {
    _sampleTimer?.cancel();
    _pulseCtrl.stop();
    _saveCalibration();
    _glowCtrl.forward();
    setState(() {
      _step = _CalibrationStep.done;
    });
  }

  Future<void> _saveCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    // AudioEngine uses 170 Hz as the threshold to separate D3 (<170 Hz) and G3 (>170 Hz).
    await prefs.setDouble('dombra_calibration_bass_cents', _bassOffsetCents);
    await prefs.setDouble('dombra_calibration_treble_cents', _trebleOffsetCents);
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _pulseCtrl.dispose();
    _needleCtrl.dispose();
    _glowCtrl.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Available space for the dialog
          final maxW = size.width > 600 ? 520.0 : size.width * 0.92;
          final maxH = size.height * 0.92;

          // Scale factor based on available height (baseline: 360px landscape)
          final hScale = (maxH / 360).clamp(0.6, 1.5);
          final padding = (16.0 * hScale).clamp(8.0, 28.0);
          final spacing = (10.0 * hScale).clamp(6.0, 20.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(24 * hScale.clamp(0.8, 1.2)),
            child: Container(
              width: maxW,
              constraints: BoxConstraints(maxHeight: maxH),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF141820),
                    KColors.background,
                    const Color(0xFF0D1117),
                  ],
                ),
                borderRadius: BorderRadius.circular(24 * hScale.clamp(0.8, 1.2)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: KColors.emerald.withOpacity(0.08),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────
                  _buildHeader(t, hScale),
                  SizedBox(height: spacing),

                  // ── String selector tabs ────────────────
                  _buildStringTabs(t, hScale),
                  SizedBox(height: spacing),

                  // ── Main body ───────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      child: _step != _CalibrationStep.done
                          ? _buildGaugeBody(t, hScale, maxW)
                          : _buildDoneBody(t, hScale, maxW),
                    ),
                  ),
                  SizedBox(height: spacing),

                  // ── Actions ─────────────────────────────
                  _buildActions(t, hScale),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader(dynamic t, double hScale) {
    final iconPad = (8.0 * hScale).clamp(6.0, 12.0);
    final iconSize = (18.0 * hScale).clamp(14.0, 22.0);
    final titleSize = (16.0 * hScale).clamp(13.0, 19.0);
    final subtitleSize = (9.0 * hScale).clamp(7.0, 10.0);

    return Row(
      children: [
        // Tuning icon with glow
        Container(
          padding: EdgeInsets.all(iconPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                KColors.amber.withOpacity(0.2),
                KColors.emerald.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12 * hScale.clamp(0.8, 1.2)),
            border: Border.all(
              color: KColors.amber.withOpacity(0.2),
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: KColors.amber,
            size: iconSize,
          ),
        ),
        SizedBox(width: (10.0 * hScale).clamp(6.0, 14.0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.dombraTuning,
                style: GoogleFonts.playfairDisplay(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                t.standardTuning,
                style: TextStyle(
                  fontSize: subtitleSize,
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                  color: KColors.amber.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Close button
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.3),
              size: (18.0 * hScale).clamp(14.0, 22.0),
            ),
            constraints: BoxConstraints(
              minWidth: (32.0 * hScale).clamp(28.0, 40.0),
              minHeight: (32.0 * hScale).clamp(28.0, 40.0),
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ── STRING SELECTOR TABS ──────────────────────────────────────
  Widget _buildStringTabs(dynamic t, double hScale) {
    final isBassActive = _step == _CalibrationStep.listeningBass;
    final isTrebleActive = _step == _CalibrationStep.listeningTreble;
    final isBassDone = _step == _CalibrationStep.listeningTreble || _step == _CalibrationStep.done;
    final isTrebleDone = _step == _CalibrationStep.done;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Top string tab (D3) — first to calibrate
          Expanded(
            child: _buildStringTab(
              label: t.topString,
              note: 'D3',
              hz: '146.83 Hz',
              isActive: isBassActive,
              isDone: isBassDone,
              hScale: hScale,
            ),
          ),
          const SizedBox(width: 3),
          // Bottom string tab (G3)
          Expanded(
            child: _buildStringTab(
              label: t.bottomString,
              note: 'G3',
              hz: '196.00 Hz',
              isActive: isTrebleActive,
              isDone: isTrebleDone,
              hScale: hScale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStringTab({
    required String label,
    required String note,
    required String hz,
    required bool isActive,
    required bool isDone,
    required double hScale,
  }) {
    Color borderColor;
    Color bgColor;
    Color textColor;
    IconData? trailingIcon;

    if (isDone) {
      borderColor = KColors.emerald.withOpacity(0.4);
      bgColor = KColors.emerald.withOpacity(0.08);
      textColor = KColors.emerald;
      trailingIcon = Icons.check_circle_rounded;
    } else if (isActive) {
      borderColor = KColors.amber.withOpacity(0.5);
      bgColor = KColors.amber.withOpacity(0.08);
      textColor = KColors.amber;
      trailingIcon = Icons.fiber_manual_record;
    } else {
      borderColor = Colors.transparent;
      bgColor = Colors.transparent;
      textColor = Colors.white.withOpacity(0.25);
      trailingIcon = null;
    }

    final labelSize = (9.0 * hScale).clamp(7.0, 11.0);
    final noteSize = (14.0 * hScale).clamp(11.0, 18.0);
    final hzSize = (8.0 * hScale).clamp(6.0, 9.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: (8.0 * hScale).clamp(6.0, 12.0),
        vertical: (6.0 * hScale).clamp(4.0, 10.0),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: (2.0 * hScale).clamp(1.0, 3.0)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        note,
                        style: GoogleFonts.inter(
                          fontSize: noteSize,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(width: (4.0 * hScale).clamp(3.0, 6.0)),
                    Flexible(
                      child: Text(
                        hz,
                        style: TextStyle(
                          fontSize: hzSize,
                          fontFamily: 'monospace',
                          color: textColor.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            Icon(
              trailingIcon,
              size: isDone ? (14.0 * hScale).clamp(10.0, 18.0) : (8.0 * hScale).clamp(6.0, 10.0),
              color: textColor,
            ),
        ],
      ),
    );
  }

  // ── GAUGE BODY (the half-clock meter) ─────────────────────────
  Widget _buildGaugeBody(dynamic t, double hScale, double dialogWidth) {
    final liveHz = _engine.currentHz;
    final isBass = _step == _CalibrationStep.listeningBass;
    final targetHz = isBass ? _referenceBassHz : _referenceTrebleHz;
    final targetNote = isBass ? 'D3' : 'G3';
    final progress = _readings.length / _requiredReadings;

    // Responsive gauge — scales with available height
    final gaugeSize = (120.0 * hScale).clamp(80.0, 260.0);
    final gaugeHeight = gaugeSize * 0.577;

    // Determine color based on offset
    final absCents = _liveCentsOffset.abs();
    Color gaugeColor;
    String tuneHint;
    if (liveHz <= 0) {
      gaugeColor = Colors.white.withOpacity(0.15);
      tuneHint = '';
    } else if (absCents <= 5) {
      gaugeColor = KColors.emerald;
      tuneHint = t.perfectTune;
    } else if (absCents <= 15) {
      gaugeColor = KColors.amber;
      tuneHint = _liveCentsOffset < 0 ? t.tightenSlightly : t.tuneDown;
    } else {
      gaugeColor = KColors.red;
      tuneHint = _liveCentsOffset < 0 ? t.tightenSlightly : t.tuneDown;
    }

    final hzFontSize = (22.0 * hScale).clamp(16.0, 32.0);
    final hintFontSize = (10.0 * hScale).clamp(8.0, 12.0);
    final targetFontSize = (8.0 * hScale).clamp(7.0, 10.0);
    final vGap = (4.0 * hScale).clamp(2.0, 8.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Semicircular gauge ──────────────────
        SizedBox(
          width: gaugeSize,
          height: gaugeHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _liveCentsOffset),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            builder: (context, animatedCents, child) {
              return AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TunerGaugePainter(
                      centsOffset: animatedCents,
                      gaugeColor: gaugeColor,
                      isListening: liveHz > 0,
                      pulseValue: _pulseCtrl.value,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              );
            },
          ),
        ),

        SizedBox(height: vGap),

        // ── Live Hz display ─────────────────────
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            liveHz > 0 ? '${liveHz.toStringAsFixed(1)} Hz' : '— Hz',
            style: GoogleFonts.inter(
              fontSize: hzFontSize,
              fontWeight: FontWeight.w800,
              color: liveHz > 0 ? gaugeColor : Colors.white.withOpacity(0.12),
            ),
          ),
        ),

        SizedBox(height: (2.0 * hScale).clamp(1.0, 4.0)),

        // ── Tune hint text ──────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            tuneHint.isNotEmpty ? tuneHint : (isBass ? t.playOpenBass : t.playOpenTreble),
            key: ValueKey(tuneHint),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hintFontSize,
              fontWeight: FontWeight.w600,
              color: tuneHint.isNotEmpty
                  ? gaugeColor
                  : Colors.white.withOpacity(0.35),
            ),
          ),
        ),

        SizedBox(height: (2.0 * hScale).clamp(1.0, 4.0)),

        // ── Target reference ────────────────────
        Text(
          'Target: $targetNote (${targetHz.toStringAsFixed(2)} Hz)',
          style: TextStyle(
            fontSize: targetFontSize,
            fontFamily: 'monospace',
            letterSpacing: 1.0,
            color: Colors.white.withOpacity(0.2),
          ),
        ),

        SizedBox(height: vGap),

        // ── Progress bar ────────────────────────
        _buildProgressBar(t, progress, hScale),
      ],
    );
  }

  Widget _buildProgressBar(dynamic t, double progress, double hScale) {
    final fontSize = (9.0 * hScale).clamp(7.0, 10.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.calibrating,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            Text(
              '${_readings.length}/$_requiredReadings',
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                color: KColors.amber.withOpacity(0.5),
              ),
            ),
          ],
        ),
        SizedBox(height: (4.0 * hScale).clamp(2.0, 6.0)),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.04),
            valueColor: const AlwaysStoppedAnimation<Color>(KColors.amber),
            minHeight: (3.0 * hScale).clamp(2.0, 4.0),
          ),
        ),
      ],
    );
  }

  // ── DONE BODY ─────────────────────────────────────────────────
  Widget _buildDoneBody(dynamic t, double hScale, double dialogWidth) {
    final absOffsetBass = _bassOffsetCents.abs().round();
    final absOffsetTreble = _trebleOffsetCents.abs().round();

    final isBassSharp = _bassOffsetCents > 0;
    final isTrebleSharp = _trebleOffsetCents > 0;

    final bassDir = isBassSharp ? t.centsSharp : t.centsFlat;
    final trebleDir = isTrebleSharp ? t.centsSharp : t.centsFlat;

    // Responsive done gauge
    final doneGaugeSize = (100.0 * hScale).clamp(70.0, 200.0);
    final doneGaugeHeight = doneGaugeSize * 0.575;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success gauge — needle centered
        SizedBox(
          width: doneGaugeSize,
          height: doneGaugeHeight,
          child: CustomPaint(
            painter: _TunerGaugePainter(
              centsOffset: 0,
              gaugeColor: KColors.emerald,
              isListening: false,
              pulseValue: 0,
            ),
          ),
        ),

        SizedBox(height: (6.0 * hScale).clamp(4.0, 12.0)),

        // Success text
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            t.calibrationComplete,
            style: GoogleFonts.playfairDisplay(
              fontSize: (14.0 * hScale).clamp(12.0, 18.0),
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: KColors.emerald,
            ),
          ),
        ),

        SizedBox(height: (8.0 * hScale).clamp(4.0, 16.0)),

        // Results card
        Container(
          padding: EdgeInsets.all((10.0 * hScale).clamp(8.0, 16.0)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResultRow(
                label: '${t.topString} (D3)',
                hz: _trebleDetectedHz,
                offset: absOffsetTreble,
                direction: trebleDir,
                t: t,
                hScale: hScale,
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: (6.0 * hScale).clamp(4.0, 10.0)),
                child: Divider(
                  color: Colors.white.withOpacity(0.06),
                  height: 1,
                ),
              ),
              _buildResultRow(
                label: '${t.bottomString} (G3)',
                hz: _bassDetectedHz,
                offset: absOffsetBass,
                direction: bassDir,
                t: t,
                hScale: hScale,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow({
    required String label,
    required double hz,
    required int offset,
    required String direction,
    required dynamic t,
    required double hScale,
  }) {
    final isPerfect = offset <= 5;
    final labelSize = (8.0 * hScale).clamp(7.0, 10.0);
    final hzSize = (14.0 * hScale).clamp(11.0, 18.0);
    final badgeSize = (9.0 * hScale).clamp(7.0, 11.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${hz.toStringAsFixed(1)} Hz',
                style: GoogleFonts.inter(
                  fontSize: hzSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: (7.0 * hScale).clamp(5.0, 10.0),
              vertical: (3.0 * hScale).clamp(2.0, 4.0),
            ),
            decoration: BoxDecoration(
              color: (isPerfect ? KColors.emerald : KColors.amber).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isPerfect ? KColors.emerald : KColors.amber).withOpacity(0.3),
              ),
            ),
            child: Text(
              isPerfect ? t.perfectTune : '$offset $direction',
              style: TextStyle(
                fontSize: badgeSize,
                fontFamily: 'monospace',
                color: isPerfect ? KColors.emerald : KColors.amber,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ── ACTIONS ───────────────────────────────────────────────────
  Widget _buildActions(dynamic t, double hScale) {
    final btnPadding = (10.0 * hScale).clamp(8.0, 14.0);
    final btnFontSize = (12.0 * hScale).clamp(10.0, 15.0);
    final iconSize = (14.0 * hScale).clamp(12.0, 18.0);

    return Row(
      children: [
        if (_step == _CalibrationStep.done) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _readings.clear();
                _glowCtrl.reset();
                setState(() {
                  _step = _CalibrationStep.listeningTreble;
                  _liveCentsOffset = 0.0;
                });
                _pulseCtrl.repeat();
                _startListening();
              },
              icon: Icon(Icons.refresh_rounded, size: iconSize),
              label: Text(
                t.tryAgain,
                style: TextStyle(fontSize: btnFontSize),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: btnPadding),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SizedBox(width: (8.0 * hScale).clamp(6.0, 12.0)),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _step == _CalibrationStep.done
                  ? KColors.emerald
                  : Colors.white.withOpacity(0.08),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: btnPadding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              _step == _CalibrationStep.done ? t.done : t.cancel,
              style: TextStyle(
                fontSize: btnFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Semicircular Tuner Gauge Painter (half-clock style)
// ─────────────────────────────────────────────────────────────────

class _TunerGaugePainter extends CustomPainter {
  final double centsOffset;  // -50 to +50
  final Color gaugeColor;
  final bool isListening;
  final double pulseValue;

  _TunerGaugePainter({
    required this.centsOffset,
    required this.gaugeColor,
    required this.isListening,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width * 0.42;

    // ── Draw arc ticks / scale marks ────────────────
    _drawScaleMarks(canvas, center, radius, size);

    // ── Draw colored arc segments ───────────────────
    _drawColoredArc(canvas, center, radius);

    // ── Draw the needle ─────────────────────────────
    _drawNeedle(canvas, center, radius, size);

    // ── Draw center pivot ───────────────────────────
    _drawPivot(canvas, center);

    // ── Draw flat/sharp labels ──────────────────────
    _drawLabels(canvas, center, radius, size);
  }

  void _drawScaleMarks(Canvas canvas, Offset center, double radius, Size size) {
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round;

    const totalTicks = 41; // -50 to +50 in steps of ~2.5
    for (int i = 0; i <= totalTicks; i++) {
      final fraction = i / totalTicks;
      final angle = math.pi + fraction * math.pi; // 180° to 360°

      final isMajor = i % 10 == 0;
      final isMid = i % 5 == 0;

      final innerMult = isMajor ? 0.82 : (isMid ? 0.87 : 0.91);
      const outerMult = 0.95;

      final innerPoint = Offset(
        center.dx + radius * innerMult * math.cos(angle),
        center.dy + radius * innerMult * math.sin(angle),
      );
      final outerPoint = Offset(
        center.dx + radius * outerMult * math.cos(angle),
        center.dy + radius * outerMult * math.sin(angle),
      );

      tickPaint.strokeWidth = isMajor ? 2.5 : (isMid ? 1.5 : 0.8);
      tickPaint.color = isMajor
          ? Colors.white.withOpacity(0.35)
          : Colors.white.withOpacity(0.12);

      // Center tick is special
      if (i == totalTicks ~/ 2) {
        tickPaint.color = KColors.emerald.withOpacity(0.8);
        tickPaint.strokeWidth = 3;
      }

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  void _drawColoredArc(Canvas canvas, Offset center, double radius) {
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.75);

    // Background arc
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withOpacity(0.04)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, math.pi, math.pi, false, bgPaint);

    // Green center zone
    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = KColors.emerald.withOpacity(0.3);
    // Center 10% = ±5 cents
    final centerStart = math.pi + math.pi * 0.4;
    final centerSweep = math.pi * 0.2;
    canvas.drawArc(arcRect, centerStart, centerSweep, false, greenPaint);

    // Amber zones (±5 to ±15 cents)
    final amberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = KColors.amber.withOpacity(0.2);
    // Left amber
    canvas.drawArc(arcRect, math.pi + math.pi * 0.3, math.pi * 0.1, false, amberPaint);
    // Right amber
    canvas.drawArc(arcRect, math.pi + math.pi * 0.6, math.pi * 0.1, false, amberPaint);

    // Red outer zones
    final redPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = KColors.red.withOpacity(0.15);
    canvas.drawArc(arcRect, math.pi, math.pi * 0.3, false, redPaint);
    canvas.drawArc(arcRect, math.pi + math.pi * 0.7, math.pi * 0.3, false, redPaint);
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius, Size size) {
    // Needle angle: 0 cents = straight up (270° / 3π/2)
    // Map -50 to +50 cents → π to 2π
    final normalizedOffset = (centsOffset + 50) / 100; // 0 to 1
    final angle = math.pi + normalizedOffset * math.pi;

    final needleLength = radius * 0.72;
    final tipPoint = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    // Needle shadow
    final shadowPaint = Paint()
      ..color = gaugeColor.withOpacity(0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(center, tipPoint, shadowPaint);

    // Needle body
    final needlePaint = Paint()
      ..color = gaugeColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tipPoint, needlePaint);

    // Needle tip glow
    if (isListening) {
      final glowPaint = Paint()
        ..color = gaugeColor.withOpacity(0.4 + 0.2 * math.sin(pulseValue * 2 * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(tipPoint, 4, glowPaint);
    }
  }

  void _drawPivot(Canvas canvas, Offset center) {
    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);

    // Glow
    final glowPaint = Paint()
      ..color = gaugeColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 6, glowPaint);
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, Size size) {
    // "♭" on the left
    final flatPainter = TextPainter(
      text: TextSpan(
        text: '♭',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: KColors.red.withOpacity(0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    flatPainter.paint(
      canvas,
      Offset(center.dx - radius * 0.95 - flatPainter.width / 2, center.dy - 20),
    );

    // "♯" on the right
    final sharpPainter = TextPainter(
      text: TextSpan(
        text: '♯',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: KColors.red.withOpacity(0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sharpPainter.paint(
      canvas,
      Offset(center.dx + radius * 0.95 - sharpPainter.width / 2, center.dy - 20),
    );

    // Center "0" marker
    final zeroPainter = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: KColors.emerald.withOpacity(0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zeroPainter.paint(
      canvas,
      Offset(center.dx - zeroPainter.width / 2, center.dy - radius * 0.98 - 14),
    );
  }

  @override
  bool shouldRepaint(covariant _TunerGaugePainter oldDelegate) {
    return oldDelegate.centsOffset != centsOffset ||
        oldDelegate.gaugeColor != gaugeColor ||
        oldDelegate.isListening != isListening ||
        oldDelegate.pulseValue != pulseValue;
  }
}
