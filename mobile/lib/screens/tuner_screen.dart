import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../constants/strings.dart';
import '../main.dart';
import '../services/language_service.dart';
import '../services/ml_service.dart';

// ── State machine ───────────────────────────────────────────────
enum RecognitionState { idle, recording, analyzing, result, error }

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with TickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────
  final MlService _mlService = MlService();
  final AudioRecorder _recorder = AudioRecorder();

  // ── State ─────────────────────────────────────────────────────
  RecognitionState _state = RecognitionState.idle;
  bool _mlAvailable = false;
  String? _errorMessage;

  // Recording
  static const int _recordDurationSec = 6;
  int _secondsRemaining = _recordDurationSec;
  Timer? _countdownTimer;

  // Result
  ChordPrediction? _prediction;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _resultFadeController;
  late Animation<double> _resultFadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _resultFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultFadeAnim = CurvedAnimation(
      parent: _resultFadeController,
      curve: Curves.easeOutCubic,
    );

    _checkMlHealth();
  }

  Future<void> _checkMlHealth() async {
    final ok = await _mlService.checkHealth();
    if (mounted) setState(() => _mlAvailable = ok);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _resultFadeController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Recording flow ────────────────────────────────────────────
  Future<void> _startRecognition() async {
    // Check mic permission
    if (!await _recorder.hasPermission()) {
      setState(() {
        _state = RecognitionState.error;
        _errorMessage = 'noMicrophone';
      });
      return;
    }

    // Reset
    _prediction = null;
    _resultFadeController.reset();

    // Start recording to a temp file
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/kuyshim_record_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: filePath,
    );

    setState(() {
      _state = RecognitionState.recording;
      _secondsRemaining = _recordDurationSec;
    });
    _pulseController.repeat();

    // Countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _stopAndAnalyze(filePath);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _stopAndAnalyze(String filePath) async {
    _countdownTimer?.cancel();
    _pulseController.stop();
    _pulseController.value = 0.0;

    await _recorder.stop();

    setState(() => _state = RecognitionState.analyzing);

    try {
      // Read file bytes
      final file = File(filePath);
      if (!await file.exists()) {
        throw MlServiceException('Recording file not found');
      }
      final audioBytes = await file.readAsBytes();

      // Send to ML
      final prediction = await _mlService.predictChord(audioBytes);

      if (mounted) {
        setState(() {
          _prediction = prediction;
          _state = RecognitionState.result;
        });
        _resultFadeController.forward();
      }

      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = RecognitionState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _reset() {
    _countdownTimer?.cancel();
    _pulseController.stop();
    _pulseController.value = 0.0;
    _resultFadeController.reset();
    setState(() {
      _state = RecognitionState.idle;
      _prediction = null;
      _errorMessage = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;

    return Scaffold(
      backgroundColor: KColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Kazakh ornaments background
                Positioned.fill(child: _buildOrnaments()),

                // Main content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.025,
                    vertical: constraints.maxHeight * 0.03,
                  ),
                  child: Column(
                    children: [
                      _buildTopNav(context, t, constraints),
                      SizedBox(height: constraints.maxHeight * 0.02),
                      Expanded(
                        child: Row(
                          children: [
                            // Left: status info
                            Expanded(
                              flex: 2,
                              child: _buildStatusPanel(t, constraints),
                            ),

                            // Center: record button
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: _buildCenterButton(
                                    context, t, constraints),
                              ),
                            ),

                            // Right: results
                            Expanded(
                              flex: 3,
                              child: _buildResultsPanel(t, constraints),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Top navigation bar ────────────────────────────────────────
  Widget _buildTopNav(
      BuildContext context, AppStrings t, BoxConstraints constraints) {
    final iconSize = constraints.maxHeight * 0.05;
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: iconSize),
          onPressed: () => context.go('/library'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              t.kuiRecognition,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: constraints.maxHeight * 0.06,
              ),
            ),
          ),
        ),
        // ML health indicator
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.012,
            vertical: constraints.maxHeight * 0.015,
          ),
          decoration: BoxDecoration(
            color:
                (_mlAvailable ? KColors.emerald : KColors.red).withOpacity(0.12),
            borderRadius: BorderRadius.circular(constraints.maxHeight * 0.04),
            border: Border.all(
              color: (_mlAvailable ? KColors.emerald : KColors.red)
                  .withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _mlAvailable ? Icons.check_circle : Icons.cloud_off,
                size: constraints.maxHeight * 0.035,
                color: _mlAvailable ? KColors.emerald : KColors.red,
              ),
              SizedBox(width: constraints.maxWidth * 0.005),
              Text(
                _mlAvailable ? 'ML Online' : 'ML Offline',
                style: TextStyle(
                  fontSize: constraints.maxHeight * 0.028,
                  fontWeight: FontWeight.w600,
                  color: _mlAvailable ? KColors.emerald : KColors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Left status panel ─────────────────────────────────────────
  Widget _buildStatusPanel(AppStrings t, BoxConstraints constraints) {
    final labelStyle = TextStyle(
      fontSize: constraints.maxHeight * 0.028,
      color: Colors.white.withOpacity(0.4),
      fontFamily: 'monospace',
      letterSpacing: 1.2,
    );

    return Padding(
      padding: EdgeInsets.only(right: constraints.maxWidth * 0.01),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // State indicator
          _buildStateChip(t, constraints),
          SizedBox(height: constraints.maxHeight * 0.04),

          // Recording timer
          if (_state == RecognitionState.recording) ...[
            Text(
              '$_secondsRemaining',
              style: GoogleFonts.inter(
                fontSize: constraints.maxHeight * 0.12,
                fontWeight: FontWeight.w200,
                color: KColors.amber,
              ),
            ),
            Text(t.recordingSeconds, style: labelStyle),
          ],

          if (_state == RecognitionState.idle) ...[
            Icon(
              Icons.music_note_rounded,
              size: constraints.maxHeight * 0.08,
              color: Colors.white.withOpacity(0.15),
            ),
            SizedBox(height: constraints.maxHeight * 0.02),
            Text(
              t.tapToRecognize,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: constraints.maxHeight * 0.025,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStateChip(AppStrings t, BoxConstraints constraints) {
    String label;
    Color color;
    IconData icon;

    switch (_state) {
      case RecognitionState.idle:
        label = t.startListening;
        color = Colors.white.withOpacity(0.3);
        icon = Icons.hearing;
        break;
      case RecognitionState.recording:
        label = t.recording;
        color = KColors.red;
        icon = Icons.fiber_manual_record;
        break;
      case RecognitionState.analyzing:
        label = t.analyzingAudio;
        color = KColors.amber;
        icon = Icons.analytics_outlined;
        break;
      case RecognitionState.result:
        label = t.chordDetected;
        color = KColors.emerald;
        icon = Icons.check_circle;
        break;
      case RecognitionState.error:
        label = t.tryAgain;
        color = KColors.red;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.012,
        vertical: constraints.maxHeight * 0.015,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(constraints.maxHeight * 0.03),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: constraints.maxHeight * 0.03, color: color),
          SizedBox(width: constraints.maxWidth * 0.005),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: constraints.maxHeight * 0.025,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Center record/pulse button ────────────────────────────────
  Widget _buildCenterButton(
      BuildContext context, AppStrings t, BoxConstraints constraints) {
    final bool canTap = _state == RecognitionState.idle ||
        _state == RecognitionState.result ||
        _state == RecognitionState.error;

    return GestureDetector(
      onTap: canTap ? _startRecognition : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return FractionallySizedBox(
            widthFactor: 0.7,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: CustomPaint(
                painter: PulseVisualizerPainter(
                  animationValue: _pulseController.value,
                  isListening: _state == RecognitionState.recording,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _getButtonColor().withOpacity(0.2),
                        _getButtonSecondaryColor().withOpacity(0.2),
                        _getButtonColor().withOpacity(0.2),
                      ],
                      transform: GradientRotation(
                          _pulseController.value * 2 * math.pi),
                    ),
                    boxShadow: _state == RecognitionState.recording
                        ? [
                            BoxShadow(
                              color: KColors.red.withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 10 * _pulseController.value,
                            ),
                            BoxShadow(
                              color: KColors.amber.withOpacity(0.2),
                              blurRadius: 60,
                              spreadRadius: 20 * _pulseController.value,
                            ),
                          ]
                        : _state == RecognitionState.analyzing
                            ? [
                                BoxShadow(
                                  color: KColors.amber.withOpacity(0.3),
                                  blurRadius: 30,
                                ),
                              ]
                            : [],
                  ),
                  child: Center(
                    child: _buildButtonContent(t, constraints),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonContent(AppStrings t, BoxConstraints constraints) {
    switch (_state) {
      case RecognitionState.idle:
      case RecognitionState.result:
      case RecognitionState.error:
        return FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  _state == RecognitionState.idle
                      ? t.tapToRecognize
                      : t.tryAgain,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      case RecognitionState.recording:
        return FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  color: KColors.red,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  t.recording,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      case RecognitionState.analyzing:
        return const FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KColors.amber),
                strokeWidth: 3,
              ),
            ),
          ),
        );
    }
  }

  Color _getButtonColor() {
    switch (_state) {
      case RecognitionState.recording:
        return KColors.red;
      case RecognitionState.analyzing:
        return KColors.amber;
      case RecognitionState.result:
        return KColors.emerald;
      default:
        return KColors.emerald;
    }
  }

  Color _getButtonSecondaryColor() {
    switch (_state) {
      case RecognitionState.recording:
        return KColors.amber;
      case RecognitionState.analyzing:
        return KColors.amberLight;
      case RecognitionState.result:
        return KColors.emeraldDark;
      default:
        return KColors.amber;
    }
  }

  // ── Right results panel ───────────────────────────────────────
  Widget _buildResultsPanel(AppStrings t, BoxConstraints constraints) {
    if (_state == RecognitionState.error) {
      return _buildErrorCard(t, constraints);
    }

    if (_state == RecognitionState.result && _prediction != null) {
      return FadeTransition(
        opacity: _resultFadeAnim,
        child: _buildResultCard(t, constraints),
      );
    }

    if (_state == RecognitionState.analyzing) {
      return _buildAnalyzingCard(t, constraints);
    }

    // idle / recording → empty placeholder
    return _buildIdlePlaceholder(t, constraints);
  }

  Widget _buildIdlePlaceholder(AppStrings t, BoxConstraints constraints) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.equalizer_rounded,
            size: constraints.maxHeight * 0.1,
            color: Colors.white.withOpacity(0.08),
          ),
          SizedBox(height: constraints.maxHeight * 0.02),
          Text(
            t.playAString,
            style: TextStyle(
              fontSize: constraints.maxHeight * 0.03,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingCard(AppStrings t, BoxConstraints constraints) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(constraints.maxHeight * 0.05),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(constraints.maxHeight * 0.04),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius:
                  BorderRadius.circular(constraints.maxHeight * 0.05),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: constraints.maxHeight * 0.06,
                  height: constraints.maxHeight * 0.06,
                  child: const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(KColors.amber),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.03),
                Text(
                  t.analyzingAudio,
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.03,
                    color: KColors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(AppStrings t, BoxConstraints constraints) {
    final pred = _prediction!;
    final confPercent = (pred.confidence * 100).toStringAsFixed(1);

    // Sort top 5 by value desc
    final sortedTop5 = pred.top5.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(left: constraints.maxWidth * 0.015),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(constraints.maxHeight * 0.05),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: EdgeInsets.all(constraints.maxHeight * 0.035),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius:
                    BorderRadius.circular(constraints.maxHeight * 0.05),
                border:
                    Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chord name — big hero
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                            constraints.maxHeight * 0.02),
                        decoration: BoxDecoration(
                          color: KColors.emerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                              constraints.maxHeight * 0.025),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: KColors.emerald,
                          size: constraints.maxHeight * 0.05,
                        ),
                      ),
                      SizedBox(
                          width: constraints.maxWidth * 0.01),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.chordDetected,
                              style: TextStyle(
                                fontSize:
                                    constraints.maxHeight * 0.022,
                                color: Colors.white
                                    .withOpacity(0.4),
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              pred.predictedClass,
                              style: GoogleFonts.playfairDisplay(
                                fontSize:
                                    constraints.maxHeight * 0.065,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Confidence bar
                  Text(
                    '${t.confidence}: $confPercent%',
                    style: TextStyle(
                      fontSize: constraints.maxHeight * 0.025,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.01),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                        constraints.maxHeight * 0.01),
                    child: LinearProgressIndicator(
                      value: pred.confidence,
                      minHeight: constraints.maxHeight * 0.015,
                      backgroundColor:
                          Colors.white.withOpacity(0.08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(
                        pred.confidence > 0.7
                            ? KColors.emerald
                            : pred.confidence > 0.4
                                ? KColors.amber
                                : KColors.red,
                      ),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Top 5 predictions
                  Text(
                    t.topPredictions,
                    style: TextStyle(
                      fontSize: constraints.maxHeight * 0.022,
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.015),

                  ...sortedTop5.take(5).map((entry) {
                    final pct =
                        (entry.value * 100).toStringAsFixed(1);
                    final isTop = entry.key == pred.predictedClass;
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: constraints.maxHeight * 0.008),
                      child: Row(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth * 0.08,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize:
                                    constraints.maxHeight * 0.022,
                                fontWeight: isTop
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isTop
                                    ? KColors.emerald
                                    : Colors.white
                                        .withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                              width:
                                  constraints.maxWidth * 0.005),
                          Expanded(
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: entry.value,
                                minHeight:
                                    constraints.maxHeight * 0.01,
                                backgroundColor: Colors.white
                                    .withOpacity(0.05),
                                valueColor:
                                    AlwaysStoppedAnimation<
                                        Color>(
                                  isTop
                                      ? KColors.emerald
                                          .withOpacity(0.7)
                                      : Colors.white
                                          .withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              width:
                                  constraints.maxWidth * 0.005),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize:
                                  constraints.maxHeight * 0.02,
                              fontFamily: 'monospace',
                              color: isTop
                                  ? KColors.emerald
                                  : Colors.white
                                      .withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(AppStrings t, BoxConstraints constraints) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(constraints.maxHeight * 0.05),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(constraints.maxHeight * 0.04),
            decoration: BoxDecoration(
              color: KColors.red.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(constraints.maxHeight * 0.05),
              border: Border.all(color: KColors.red.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: KColors.red,
                  size: constraints.maxHeight * 0.06,
                ),
                SizedBox(height: constraints.maxHeight * 0.02),
                Text(
                  _errorMessage == 'noMicrophone'
                      ? t.noMicrophone
                      : (_errorMessage ?? t.mlOffline),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.028,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.025),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: Icon(Icons.refresh,
                      size: constraints.maxHeight * 0.03),
                  label: Text(t.tryAgain),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          constraints.maxHeight * 0.03),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Ornaments (kept from original) ────────────────────────────
  Widget _buildOrnaments() {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: FractionallySizedBox(
            widthFactor: 0.25,
            heightFactor: 0.25,
            child: CustomPaint(painter: OrnamentPainter()),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(math.pi),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(math.pi),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Custom Painters
// ──────────────────────────────────────────────────────────────────────────

class PulseVisualizerPainter extends CustomPainter {
  final double animationValue;
  final bool isListening;

  PulseVisualizerPainter(
      {required this.animationValue, required this.isListening});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final numBars = 64;
    for (int i = 0; i < numBars; i++) {
      final angle = (i * 2 * math.pi) / numBars;

      final wave1 = math.sin(angle * 4 + animationValue * 2 * math.pi);
      final wave2 = math.cos(angle * 7 - animationValue * 4 * math.pi);
      final noise = (wave1 + wave2) / 2;

      final barLength = radius * 0.15 + (noise * radius * 0.15);

      final innerRadius = radius * 1.08;
      final outerRadius =
          innerRadius + barLength.clamp(0.0, radius * 0.4);

      final startPoint = Offset(center.dx + innerRadius * math.cos(angle),
          center.dy + innerRadius * math.sin(angle));
      final endPoint = Offset(center.dx + outerRadius * math.cos(angle),
          center.dy + outerRadius * math.sin(angle));

      paint.color = i % 2 == 0
          ? KColors.red.withOpacity(0.7)
          : KColors.amber.withOpacity(0.7);
      paint.strokeWidth = radius * 0.04;

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PulseVisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isListening != isListening;
  }
}

class OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.min(size.width, size.height) * 0.05;

    final path = Path();
    path.moveTo(size.width * 0.1, 0);
    path.lineTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.1, size.height * 0.9, size.width * 0.3, size.height * 0.9);
    path.lineTo(size.width, size.height * 0.9);

    final innerPath = Path();
    innerPath.moveTo(size.width * 0.3, 0);
    innerPath.lineTo(size.width * 0.3, size.height * 0.5);
    innerPath.quadraticBezierTo(
        size.width * 0.3, size.height * 0.7, size.width * 0.5, size.height * 0.7);
    innerPath.lineTo(size.width, size.height * 0.7);

    canvas.drawPath(path, paint);
    canvas.drawPath(innerPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
