/// GameScreen — Rhythm highway game with horizontal scrolling notes.
/// Designed for two-string dombra, inspired by Yousician.
/// All sizes are percentage-based via MediaQuery to prevent overflow.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart' show AudioPlayer, AssetSource, DeviceFileSource;

import '../main.dart';
import '../models/game_models.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../services/level_manager.dart' show AudioSource, AudioSourceType;

// ── Fret color palette ──────────────────────────────────────────
const List<Color> _fretColors = [
  Color(0xFF10B981), // 0 – emerald
  Color(0xFFEF8B34), // 1 – orange
  Color(0xFF8B5CF6), // 2 – violet
  Color(0xFF3B82F6), // 3 – blue
  Color(0xFFEF4444), // 4 – red
  Color(0xFFF0C850), // 5 – gold
  Color(0xFF06B6D4), // 6 – cyan
];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 0;
  double _playbackSpeed = 1;
  bool _isMuted = false;
  bool _isLoaded = false;

  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfectCount = 0;
  int _goodCount = 0;
  int _missCount = 0;

  List<ScrollNote> _notes = [];
  String? _feedbackText;
  int _feedbackKey = 0;

  Timer? _gameTimer;
  double _lastHitTime = 0;

  /// Scroll speed in logical-pixels-per-second (scales with screenWidth)
  late double _scrollSpeed;

  static const double _hitLinePercent = 0.18;
  static const List<String> _feedbackTexts = [
    'MUZIKER!', 'КЕРЕМЕТ!', 'ЖАРАЙСЫҢ!', 'ТАМАША!'
  ];

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    final appState = context.read<AppState>();
    final lesson = appState.selectedLesson;
    if (lesson == null) {
      // No lesson selected — show game with generated notes
      if (mounted) {
        setState(() {
          _duration = 60;
          _isLoaded = true;
          _notes = _generateNotes(60);
        });
      }
      return;
    }

    try {
      var source = await appState.levelManager.resolveAudio(lesson);

      if (source.type == AudioSourceType.remote) {
        final localPath = await appState.levelManager.downloadAndCache(lesson);
        source = AudioSource(type: AudioSourceType.cachedFile, path: localPath);
      }

      if (source.type == AudioSourceType.asset) {
        await _audioPlayer.setSource(AssetSource(source.path));
      } else {
        await _audioPlayer.setSource(DeviceFileSource(source.path));
      }

      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) {
          setState(() {
            _duration = d.inMilliseconds / 1000.0;
            _isLoaded = true;
            _notes = _generateNotes(_duration);
          });
        }
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) {
          setState(() => _currentTime = p.inMilliseconds / 1000.0);
        }
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
          _handleFinish();
        }
      });

      // Fallback: if duration event never fires within 5 seconds, force load
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isLoaded) {
          debugPrint('[GameScreen] Duration event timeout — forcing loaded state');
          setState(() {
            _duration = 60;
            _isLoaded = true;
            _notes = _generateNotes(60);
          });
        }
      });
    } catch (e, st) {
      debugPrint('[GameScreen] Audio init error: $e\n$st');
      // Audio load error — continue with visual-only mode
      if (mounted) {
        setState(() {
          _duration = 60;
          _isLoaded = true;
          _notes = _generateNotes(60);
        });
      }
    }
  }

  List<ScrollNote> _generateNotes(double duration) {
    if (duration <= 0) return [];
    final notes = <ScrollNote>[];
    final random = math.Random(42);
    int id = 0;
    final patterns = [
      [0.0, 0.5, 1.2, 1.8],
      [0.0, 0.4, 0.8, 1.5, 2.0],
      [0.0, 0.6, 1.0, 1.6],
      [0.0, 0.3, 0.9, 1.4, 2.1],
    ];
    double t = 1;
    int patIdx = 0;
    while (t < duration - 1) {
      final pattern = patterns[patIdx % patterns.length];
      for (final offset in pattern) {
        if (t + offset >= duration - 0.5) break;
        notes.add(ScrollNote(
          id: id++,
          time: t + offset,
          string: random.nextInt(2) + 1,
          fret: random.nextInt(7),
          duration: 0.2 + random.nextDouble() * 0.3,
        ));
      }
      t += 2.5 + random.nextDouble();
      patIdx++;
    }
    return notes;
  }

  void _startGameLoop() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isPlaying) return;
      _processNotes();
    });
  }

  void _processNotes() {
    const hitWindow = 0.25;
    bool changed = false;
    for (final note in _notes) {
      if (!note.hit && (_currentTime - note.time).abs() < hitWindow &&
          _currentTime - _lastHitTime > 0.15) {
        note.hit = true;
        changed = true;
        _lastHitTime = _currentTime;
        final isPerfect = (_currentTime - note.time).abs() < 0.1;
        if (isPerfect) {
          _perfectCount++;
          _score += 150 * math.min(_combo + 1, 8);
        } else {
          _goodCount++;
          _score += 80 * math.min(_combo + 1, 8);
        }
        _combo++;
        _maxCombo = math.max(_maxCombo, _combo);
        final txt = _feedbackTexts[
            math.Random().nextInt(_feedbackTexts.length)];
        _feedbackText = isPerfect ? txt : 'GOOD!';
        _feedbackKey++;
      } else if (!note.hit && note.time < _currentTime - hitWindow * 2) {
        note.hit = true;
        changed = true;
        _missCount++;
        _combo = 0;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _handleFinish() {
    _gameTimer?.cancel();
    final total = _perfectCount + _goodCount + _missCount;
    if (total == 0) return;
    final accuracy =
        ((_perfectCount + _goodCount * 0.7) / total * 100).round();
    String rank = 'C';
    if (accuracy > 95) {
      rank = 'S';
    } else if (accuracy > 85) {
      rank = 'A';
    } else if (accuracy > 70) {
      rank = 'B';
    }

    final appState = context.read<AppState>();
    final lesson = appState.selectedLesson;
    final result = GameResult(
      score: _score,
      perfect: _perfectCount,
      good: _goodCount,
      miss: _missCount,
      accuracy: accuracy,
      lessonTitle: lesson?.title ?? '',
      rank: rank,
      suggestion: accuracy >= 85
          ? 'Керемет орындадыңыз! Келесі күйге дайынсыз. / Amazing performance!'
          : 'Жаттығуды жалғастырыңыз. Ырғақты 0.75x жылдамдықта тыңдап көріңіз. / Keep practicing!',
    );
    appState.finishGame(result);
    if (mounted) context.go('/results');
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _gameTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.resume();
      _startGameLoop();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _restart() async {
    await _audioPlayer.seek(Duration.zero);
    setState(() {
      _currentTime = 0;
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _perfectCount = 0;
      _goodCount = 0;
      _missCount = 0;
      _feedbackText = null;
      _lastHitTime = 0;
      _notes = _generateNotes(_duration);
    });
    await _audioPlayer.resume();
    _startGameLoop();
    setState(() => _isPlaying = true);
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _audioPlayer.setPlaybackRate(speed);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _audioPlayer.setVolume(_isMuted ? 0 : 0.8);
  }

  String _formatTime(double s) {
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final appState = context.watch<AppState>();
    final lesson = appState.selectedLesson;
    final screenSize = MediaQuery.of(context).size;
    final sw = screenSize.width;
    final sh = screenSize.height;
    final progress = _duration > 0 ? _currentTime / _duration : 0.0;

    _scrollSpeed = sw * 0.15;

    if (lesson == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0806),
        body: Center(
          child: CircularProgressIndicator(
            color: KColors.amber,
            strokeWidth: sh * 0.008,
          ),
        ),
      );
    }

    // String Y positions — centered in screen
    final stringsAreaTop = sh * 0.30;
    final stringsAreaBottom = sh * 0.70;
    final string1Y = stringsAreaTop + (stringsAreaBottom - stringsAreaTop) * 0.33;
    final string2Y = stringsAreaTop + (stringsAreaBottom - stringsAreaTop) * 0.66;
    final hitLineX = sw * _hitLinePercent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0806),
      body: Stack(
        children: [
          // ── Layer 1: Background gradient + grid ─────────────
          CustomPaint(
            size: Size(sw, sh),
            painter: _BackgroundPainter(sw: sw, sh: sh),
          ),

          // ── Layer 2: Strings + hit line (CustomPainter) ────
          CustomPaint(
            size: Size(sw, sh),
            painter: _StringsPainter(
              sw: sw,
              sh: sh,
              string1Y: string1Y,
              string2Y: string2Y,
              hitLineX: hitLineX,
              isPlaying: _isPlaying,
            ),
          ),

          // ── Layer 3: Scrolling notes ───────────────────────
          ..._buildScrollingNotes(sw, sh, string1Y, string2Y, hitLineX),

          // ── Layer 4: Feedback text ─────────────────────────
          if (_feedbackText != null)
            Positioned(
              left: hitLineX - sw * 0.06,
              top: sh * 0.15,
              child: _FeedbackWidget(
                key: ValueKey(_feedbackKey),
                text: _feedbackText!,
                sw: sw,
                sh: sh,
              ),
            ),

          // ── Layer 5: Top HUD ───────────────────────────────
          _buildTopHUD(t, lesson, sw, sh),

          // ── Layer 6: Bottom controls + timeline ────────────
          _buildBottomBar(t, sw, sh, progress),

          // ── Pause + Restart buttons (bottom-left) ──────────
          Positioned(
            left: sw * 0.02,
            bottom: sh * 0.14,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: sw * 0.055,
                    height: sw * 0.055,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(sw * 0.015),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: sw * 0.03,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
                SizedBox(width: sw * 0.01),
                GestureDetector(
                  onTap: _restart,
                  child: Container(
                    width: sw * 0.055,
                    height: sw * 0.055,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(sw * 0.015),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.refresh,
                      size: sw * 0.03,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Hand indicator (bottom-right) ──────────────────
          Positioned(
            right: sw * 0.03,
            bottom: sh * 0.14,
            child: _HandIndicator(sw: sw, sh: sh),
          ),

          // ── Download overlay ───────────────────────────────
          if (!_isLoaded)
            Container(
              color: const Color(0xFF0A0806).withOpacity(0.9),
              child: const DombraLoader(),
            ),
        ],
      ),
    );
  }

  // ── Build scrolling notes ──────────────────────────────────
  List<Widget> _buildScrollingNotes(
    double sw, double sh, double s1Y, double s2Y, double hitX,
  ) {
    final noteH = sh * 0.08;
    final minNoteW = sw * 0.06;
    final widgets = <Widget>[];

    for (final note in _notes) {
      if (note.hit) continue;
      final timeDelta = note.time - _currentTime;
      final x = hitX + timeDelta * _scrollSpeed;

      // Cull off-screen notes
      if (x < -sw * 0.15 || x > sw * 1.1) continue;

      final y = note.string == 1 ? s1Y : s2Y;
      final noteW = minNoteW + (note.duration * sw * 0.08);
      final fretColor = _fretColors[note.fret % _fretColors.length];

      widgets.add(
        Positioned(
          left: x,
          top: y - noteH / 2,
          child: Container(
            width: noteW,
            height: noteH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(noteH / 2),
              color: fretColor.withOpacity(0.25),
              border: Border.all(
                color: fretColor.withOpacity(0.8),
                width: sh * 0.004,
              ),
              boxShadow: [
                BoxShadow(
                  color: fretColor.withOpacity(0.35),
                  blurRadius: sh * 0.02,
                  spreadRadius: sh * 0.002,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${note.fret}',
              style: TextStyle(
                fontSize: sw * 0.02,
                fontWeight: FontWeight.w900,
                color: fretColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // ── Top HUD ────────────────────────────────────────────────
  Widget _buildTopHUD(dynamic t, dynamic lesson, double sw, double sh) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          sw * 0.03, sh * 0.03, sw * 0.03, sh * 0.02,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0806),
              const Color(0xFF0A0806).withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () {
                _audioPlayer.stop();
                _gameTimer?.cancel();
                context.go('/library');
              },
              child: Container(
                width: sw * 0.045,
                height: sw * 0.045,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(sw * 0.012),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.chevron_left,
                    size: sw * 0.025, color: Colors.white54),
              ),
            ),

            SizedBox(width: sw * 0.015),

            // Multiplier
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.012,
                vertical: sh * 0.012,
              ),
              decoration: BoxDecoration(
                color: _combo >= 5
                    ? KColors.amber.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(sw * 0.01),
                border: Border.all(
                  color: _combo >= 5
                      ? KColors.amber.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                '${math.min(_combo + 1, 8)}x',
                style: TextStyle(
                  fontSize: sw * 0.022,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: _combo >= 5
                      ? KColors.amberLight
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),

            const Spacer(),

            // Title & composer
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.currentKui.toUpperCase(),
                    style: TextStyle(
                      fontSize: sh * 0.022,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                      color: KColors.amber.withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: sh * 0.005),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        const LinearGradient(
                      colors: [
                        KColors.amber,
                        KColors.amberLight,
                        KColors.amber,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      '"${lesson.title}"',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: sh * 0.05,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${t.by} ${lesson.composer}',
                    style: TextStyle(
                      fontSize: sh * 0.022,
                      letterSpacing: 2,
                      color: KColors.amber.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.score.toUpperCase(),
                  style: TextStyle(
                    fontSize: sh * 0.022,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    color: KColors.amber.withOpacity(0.4),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      const LinearGradient(
                    colors: [KColors.amberLight, KColors.amber],
                  ).createShader(bounds),
                  child: Text(
                    _score.toString(),
                    style: TextStyle(
                      fontSize: sw * 0.03,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(width: sw * 0.02),

            // Combo
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.combo.toUpperCase(),
                  style: TextStyle(
                    fontSize: sh * 0.022,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    color: KColors.amber.withOpacity(0.4),
                  ),
                ),
                Text(
                  'x$_combo',
                  style: TextStyle(
                    fontSize: sw * 0.03,
                    fontWeight: FontWeight.w900,
                    color: _combo >= 20
                        ? Colors.redAccent
                        : _combo >= 10
                            ? KColors.amberLight
                            : _combo >= 5
                                ? KColors.yellow
                                : Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Bar ─────────────────────────────────────────────
  Widget _buildBottomBar(
      dynamic t, double sw, double sh, double progress) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF0A0806),
              const Color(0xFF0A0806).withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timeline progress bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sw * 0.1),
              child: GestureDetector(
                onTapDown: (details) {
                  if (_duration <= 0) return;
                  final ratio = details.localPosition.dx / (sw * 0.8);
                  _audioPlayer.seek(Duration(
                    milliseconds:
                        (ratio.clamp(0, 1) * _duration * 1000).round(),
                  ));
                },
                child: Container(
                  height: sh * 0.05,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(sh * 0.015),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0, 1).toDouble(),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(sh * 0.015),
                        gradient: const LinearGradient(
                          colors: [
                            KColors.amber,
                            KColors.amberLight,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Controls row
            Padding(
              padding: EdgeInsets.fromLTRB(
                sw * 0.04, sh * 0.015, sw * 0.04, sh * 0.02,
              ),
              child: Row(
                children: [
                  // Time
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _formatTime(_currentTime),
                          style: TextStyle(
                            fontSize: sh * 0.028,
                            fontFamily: 'monospace',
                            color: KColors.amber.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(
                            fontSize: sh * 0.028,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        Text(
                          _duration > 0
                              ? _formatTime(_duration)
                              : '0:00',
                          style: TextStyle(
                            fontSize: sh * 0.028,
                            fontFamily: 'monospace',
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        SizedBox(width: sw * 0.01),
                        GestureDetector(
                          onTap: _toggleMute,
                          child: Icon(
                            _isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: sh * 0.04,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Speed selector
                  Container(
                    padding: EdgeInsets.all(sh * 0.005),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius:
                          BorderRadius.circular(sh * 0.03),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [0.5, 0.75, 1.0].map((speed) {
                        final isActive =
                            _playbackSpeed == speed;
                        return GestureDetector(
                          onTap: () => _changeSpeed(speed),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: sw * 0.012,
                              vertical: sh * 0.012,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? KColors.amber
                                      .withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(
                                      sh * 0.025),
                            ),
                            child: Text(
                              '${speed}x',
                              style: TextStyle(
                                fontSize: sh * 0.025,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? KColors.amberLight
                                    : Colors.white
                                        .withOpacity(0.3),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(width: sw * 0.02),

                  // Stats
                  _StatBadge(
                    label: t.perfect,
                    value: '$_perfectCount',
                    color: KColors.amber,
                    sh: sh,
                  ),
                  SizedBox(width: sw * 0.015),
                  _StatBadge(
                    label: t.good,
                    value: '$_goodCount',
                    color: KColors.emerald,
                    sh: sh,
                  ),
                  SizedBox(width: sw * 0.015),
                  _StatBadge(
                    label: t.miss,
                    value: '$_missCount',
                    color: KColors.red,
                    sh: sh,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════

/// Paints the dark gradient background and vertical beat grid lines.
class _BackgroundPainter extends CustomPainter {
  final double sw;
  final double sh;

  _BackgroundPainter({required this.sw, required this.sh});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A0806),
          const Color(0xFF12100D),
          const Color(0xFF0A0806),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Vertical beat lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    final spacing = sw * 0.2;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => false;
}

/// Paints the two horizontal strings and the vertical hit line.
class _StringsPainter extends CustomPainter {
  final double sw;
  final double sh;
  final double string1Y;
  final double string2Y;
  final double hitLineX;
  final bool isPlaying;

  _StringsPainter({
    required this.sw,
    required this.sh,
    required this.string1Y,
    required this.string2Y,
    required this.hitLineX,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stringThickness = sh * 0.01;

    // String 1 — upper (amber/gold)
    final s1Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          KColors.amber.withOpacity(0.1),
          KColors.amber.withOpacity(0.6),
          KColors.amberLight.withOpacity(0.8),
          KColors.amber.withOpacity(0.6),
          KColors.amber.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(0, string1Y, size.width, stringThickness));
    canvas.drawRect(
      Rect.fromLTWH(0, string1Y - stringThickness / 2,
          size.width, stringThickness),
      s1Paint,
    );

    // String 2 — lower (cyan/blue)
    final s2Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.1),
          Colors.cyanAccent.withOpacity(0.6),
          Colors.cyanAccent.withOpacity(0.8),
          Colors.cyanAccent.withOpacity(0.6),
          Colors.cyanAccent.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(0, string2Y, size.width, stringThickness));
    canvas.drawRect(
      Rect.fromLTWH(0, string2Y - stringThickness / 2,
          size.width, stringThickness),
      s2Paint,
    );

    // Hit line — vertical
    final hitPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          KColors.amber.withOpacity(0.6),
          KColors.amberLight,
          KColors.amber.withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(hitLineX, 0, 3, size.height));
    canvas.drawRect(
      Rect.fromLTWH(hitLineX - 1.5, sh * 0.15, 3, sh * 0.7),
      hitPaint,
    );

    // Hit zone glow circles on each string
    if (isPlaying) {
      final glowPaint1 = Paint()
        ..shader = RadialGradient(
          colors: [
            KColors.amber.withOpacity(0.2),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(hitLineX, string1Y), radius: sh * 0.08));
      canvas.drawCircle(
          Offset(hitLineX, string1Y), sh * 0.08, glowPaint1);

      final glowPaint2 = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.cyanAccent.withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(hitLineX, string2Y), radius: sh * 0.08));
      canvas.drawCircle(
          Offset(hitLineX, string2Y), sh * 0.08, glowPaint2);
    }
  }

  @override
  bool shouldRepaint(covariant _StringsPainter old) =>
      old.isPlaying != isPlaying;
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════

/// Animated feedback text ("Perfect!", "GOOD!", etc.)
class _FeedbackWidget extends StatefulWidget {
  final String text;
  final double sw;
  final double sh;

  const _FeedbackWidget({
    super.key,
    required this.text,
    required this.sw,
    required this.sh,
  });

  @override
  State<_FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends State<_FeedbackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween(begin: 0.5, end: 1.2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGood = widget.text == 'GOOD!';
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isGood
                  ? [KColors.emerald, KColors.emeraldDark]
                  : [KColors.amberLight, KColors.amber],
            ).createShader(bounds),
            child: Text(
              widget.text,
              style: GoogleFonts.inter(
                fontSize: widget.sw * 0.03,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hand indicator with finger-color hints.
class _HandIndicator extends StatelessWidget {
  final double sw;
  final double sh;

  const _HandIndicator({required this.sw, required this.sh});

  @override
  Widget build(BuildContext context) {
    final size = sw * 0.07;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.back_hand_outlined,
              size: size * 0.45,
              color: Colors.white.withOpacity(0.4)),
          SizedBox(height: sh * 0.005),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _fingerDot(_fretColors[0], size * 0.08),
              SizedBox(width: size * 0.04),
              _fingerDot(_fretColors[1], size * 0.08),
              SizedBox(width: size * 0.04),
              _fingerDot(_fretColors[2], size * 0.08),
              SizedBox(width: size * 0.04),
              _fingerDot(_fretColors[3], size * 0.08),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fingerDot(Color c, double r) {
    return Container(
      width: r,
      height: r,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.4), blurRadius: r),
        ],
      ),
    );
  }
}

/// Stat badge for Perfect/Good/Miss counters.
class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double sh;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: sh * 0.02,
            letterSpacing: 2,
            color: color.withOpacity(0.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: sh * 0.035,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class DombraLoader extends StatelessWidget {
  const DombraLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Пропорциональный размер контейнера для анимации
          SizedBox(
            width: screenWidth * 0.2, // 20% от ширины экрана
            height: screenWidth * 0.2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Внешний вращающийся круг
                CircularProgressIndicator(
                  strokeWidth: screenWidth * 0.01,
                  valueColor: const AlwaysStoppedAnimation<Color>(KColors.emerald),
                ),
                // Твоя кастомная иконка домбры в центре
                Icon(
                  Icons.music_note, // Замени на Image.asset('assets/dombra_icon.png')
                  size: screenWidth * 0.08,
                  color: Colors.white.withOpacity(0.8),
                ),
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            "Loading Kui...",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
