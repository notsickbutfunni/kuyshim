/// GameScreen — Yousician-style 2-string dombra rhythm game.
/// Uses just_audio for pitch-preserving tempo, CustomPainter for rendering.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/kui_note.dart';
import '../models/game_models.dart';
import '../services/app_state.dart';
import '../services/audio_engine.dart';
import '../services/level_manager.dart' show AudioSource, AudioSourceType;
import 'game_painter.dart';

const List<String> _hitTexts = ['КЕРЕМЕТ!', 'ЖАРАЙСЫҢ!', 'ТАМАША!', 'ДҰРЫС!'];
const List<String> _goodTexts = ['ЖАҚСЫ!', 'ЖАМАН ЕМЕС!'];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Audio
  final ja.AudioPlayer _player = ja.AudioPlayer();
  final AudioEngine _audioEngine = AudioEngine();

  // State
  bool _isPlaying = false;
  bool _isLoaded = false;
  bool _kuiOn = true;
  double _tempoRate = 1.0;
  int _currentTimeMs = 0;
  double _duration = 0;

  // Notes
  List<KuiNote> _allNotes = [];
  List<KuiNote> _activeNotes = [];
  List<double> _beatTimes = [];
  String _mapTitle = '';

  // Score
  int _score = 0, _combo = 0, _maxCombo = 0;
  int _perfectCount = 0, _goodCount = 0, _missCount = 0;
  String? _feedbackText;
  int _feedbackKey = 0;

  // Game loop
  Ticker? _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  // Config
  static const int perfectWindowMs = 50;
  static const int goodWindowMs = 150;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _initGame();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _stopwatch.stop();
    _audioEngine.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── INIT ───────────────────────────────────────────────────
  Future<void> _initGame() async {
    await _loadMap();
    if (mounted) await _initAudio();
    try {
      await _audioEngine.start();
    } catch (_) {}
    _audioEngine.onPitchDetected = () { if (mounted) setState(() {}); };
    if (mounted) setState(() => _isLoaded = true);
  }

  Future<void> _loadMap() async {
    if (!mounted) return;
    final lesson = context.read<AppState>().selectedLesson;
    String? jsonStr;

    // 1. Try cached kui_maps from sync service (remote lessons)
    if (lesson?.jsonMapFile != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final fname = lesson!.jsonMapFile!.split('/').last;
        final f = File('${dir.path}/kui_maps/$fname');
        if (await f.exists()) jsonStr = await f.readAsString();
      } catch (_) {}
    }

    // 2. Try bundled asset matching the lesson's jsonMapFile
    if (jsonStr == null && lesson?.jsonMapFile != null) {
      final fname = lesson!.jsonMapFile!.split('/').last;
      try {
        jsonStr = await rootBundle.loadString('assets/kui_maps/$fname');
      } catch (_) {}
    }

    // 3. No map found — use empty notes (don't load wrong map)
    if (jsonStr != null) {
      _parseMap(jsonStr);
    } else {
      debugPrint('[GameScreen] No JSON map found for lesson: ${lesson?.title}');
      _allNotes = []; _activeNotes = []; _duration = 60;
    }
  }

  void _parseMap(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>? ?? {};
    _mapTitle = meta['title'] as String? ?? 'Unknown';
    _duration = (meta['duration_sec'] as num?)?.toDouble() ?? 60;

    final notesList = data['notes'] as List? ?? [];
    _allNotes = notesList.map((n) => KuiNote.fromJson(n)).toList();
    _activeNotes = _allNotes.where((n) => n.isActive).toList()
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    final beats = data['beat_times_sec'] as List? ?? [];
    _beatTimes = beats.map((b) => (b as num).toDouble()).toList();
  }

  Future<void> _initAudio() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final lesson = appState.selectedLesson;
    if (lesson == null) return;

    try {
      var source = await appState.levelManager.resolveAudio(lesson);
      if (source.type == AudioSourceType.remote) {
        final path = await appState.levelManager.downloadAndCache(lesson);
        source = AudioSource(type: AudioSourceType.cachedFile, path: path);
      }
      if (!mounted) return;

      if (source.type == AudioSourceType.asset) {
        await _player.setAsset('assets/${source.path}');
      } else {
        await _player.setFilePath(source.path);
      }
      await _player.setSpeed(_tempoRate);
      await _player.setVolume(_kuiOn ? 1.0 : 0.0);

      _player.positionStream.listen((p) {
        if (mounted && _isPlaying) _currentTimeMs = p.inMilliseconds;
      });
      _player.playerStateStream.listen((s) {
        if (s.processingState == ja.ProcessingState.completed && mounted) {
          _handleFinish();
        }
      });
    } catch (e) {
      debugPrint('[GameScreen] Audio init error: $e');
    }
  }

  // ── GAME LOOP ──────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    _currentTimeMs = _stopwatch.elapsedMilliseconds;
    _gameTick();
    if (mounted) setState(() {});
  }

  void _gameTick() {
    for (final note in _activeNotes) {
      if (note.isPlayed || note.isMissed) continue;
      final diff = _currentTimeMs - note.timeMs;

      if (diff.abs() <= goodWindowMs) {
        if (_audioEngine.isFrequencyMatch(note.primaryHz, toleranceHz: 7.0)) {
          note.isPlayed = true;
          _combo++;
          _maxCombo = math.max(_maxCombo, _combo);
          final mult = math.min(_combo, 8);

          if (diff.abs() <= perfectWindowMs) {
            note.hitQuality = 'perfect';
            _perfectCount++;
            _score += 100 * mult;
            _feedbackText = _hitTexts[math.Random().nextInt(_hitTexts.length)];
          } else {
            note.hitQuality = 'good';
            _goodCount++;
            _score += 50 * mult;
            _feedbackText = _goodTexts[math.Random().nextInt(_goodTexts.length)];
          }
          _feedbackKey++;
        }
      } else if (diff > goodWindowMs) {
        note.isMissed = true;
        _missCount++;
        _combo = 0;
      }
    }

    if (_activeNotes.isNotEmpty && _activeNotes.every((n) => n.isPlayed || n.isMissed)) {
      _handleFinish();
    }
  }

  // ── CONTROLS ───────────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      _stopwatch.stop();
      _ticker?.stop();
      try { await _player.pause(); } catch (_) {}
      setState(() => _isPlaying = false);
    } else {
      try { await _player.play(); } catch (_) {}
      _stopwatch.start();
      _ticker?.start();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _restart() async {
    _ticker?.stop();
    _stopwatch.stop();
    _stopwatch.reset();
    try { await _player.seek(Duration.zero); } catch (_) {}
    for (final n in _activeNotes) { n.reset(); }
    setState(() {
      _currentTimeMs = 0; _score = 0; _combo = 0; _maxCombo = 0;
      _perfectCount = 0; _goodCount = 0; _missCount = 0;
      _feedbackText = null; _isPlaying = false;
    });
  }

  void _handleFinish() {
    _ticker?.stop();
    _stopwatch.stop();
    setState(() => _isPlaying = false);
    final total = _perfectCount + _goodCount + _missCount;
    if (total == 0) return;
    final acc = ((_perfectCount + _goodCount) / total * 100).round();
    String rank = acc > 95 ? 'S' : acc > 85 ? 'A' : acc > 70 ? 'B' : 'C';

    final appState = context.read<AppState>();
    appState.finishGame(GameResult(
      score: _score, perfect: _perfectCount, good: _goodCount,
      miss: _missCount, accuracy: acc,
      lessonTitle: appState.selectedLesson?.title ?? _mapTitle,
      rank: rank,
      suggestion: acc >= 85
          ? 'Керемет орындадыңыз! Келесі күйге дайынсыз.'
          : 'Жаттығуды жалғастырыңыз. Ырғақты баяу жылдамдықта тыңдап көріңіз.',
    ));
    if (mounted) context.go('/results');
  }

  Future<void> _setTempo(double rate) async {
    _tempoRate = rate;
    try { await _player.setSpeed(rate); } catch (_) {}
    setState(() {});
  }

  Future<void> _toggleKui() async {
    _kuiOn = !_kuiOn;
    try { await _player.setVolume(_kuiOn ? 1.0 : 0.0); } catch (_) {}
    setState(() {});
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final lesson = appState.selectedLesson;
    final sz = MediaQuery.of(context).size;
    final sw = sz.width, sh = sz.height;

    if (!_isLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0806),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: hitLineColor, strokeWidth: sh * 0.008),
          SizedBox(height: sh * 0.03),
          Text('Loading...', style: TextStyle(color: Colors.white38, fontSize: sh * 0.03)),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0806),
      body: Stack(children: [
        // Fretboard painter
        RepaintBoundary(
          child: CustomPaint(
            size: Size(sw, sh),
            painter: GamePainter(
              sw: sw, sh: sh,
              currentTimeMs: _currentTimeMs,
              activeNotes: _activeNotes,
              beatTimesSec: _beatTimes,
              isPlaying: _isPlaying,
            ),
          ),
        ),

        // Feedback popup
        if (_feedbackText != null)
          Positioned(
            left: sw * 0.3, top: sh * 0.12,
            child: _FeedbackWidget(key: ValueKey(_feedbackKey),
              text: _feedbackText!, sw: sw, sh: sh),
          ),

        // Top HUD
        _buildTopHUD(sw, sh, lesson),

        // Bottom controls
        _buildBottomBar(sw, sh),
      ]),
    );
  }

  Widget _buildTopHUD(double sw, double sh, dynamic lesson) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(sw * 0.02, sh * 0.015, sw * 0.02, sh * 0.01),
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF0A0806), const Color(0xFF0A0806).withOpacity(0.8), Colors.transparent],
        )),
        child: Row(children: [
          // Back
          GestureDetector(
            onTap: () {
              _ticker?.stop(); _stopwatch.stop();
              try { _player.stop(); } catch (_) {}
              _audioEngine.stop();
              context.go('/library');
            },
            child: Container(
              padding: EdgeInsets.all(sw * 0.01),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(sw * 0.012),
              ),
              child: Icon(Icons.chevron_left, size: sw * 0.025, color: Colors.white54),
            ),
          ),
          SizedBox(width: sw * 0.015),

          // Combo
          Container(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.015, vertical: sh * 0.008),
            decoration: BoxDecoration(
              color: _combo >= 5 ? hitLineColor.withOpacity(0.15) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(sw * 0.01),
              border: Border.all(color: _combo >= 5 ? hitLineColor.withOpacity(0.3) : Colors.white10),
            ),
            child: Text('${math.min(_combo + 1, 8)}x', style: TextStyle(
              fontSize: sw * 0.022, fontWeight: FontWeight.w900, fontFamily: 'monospace',
              color: _combo >= 5 ? hitLineColor : Colors.white38,
            )),
          ),

          const Spacer(),

          // Mic display
          Container(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.015, vertical: sh * 0.005),
            decoration: BoxDecoration(
              color: _audioEngine.currentHz > 0 ? bassColor.withOpacity(0.1) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(sw * 0.012),
              border: Border.all(color: _audioEngine.currentHz > 0 ? bassColor.withOpacity(0.3) : Colors.white10),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('MIC', style: TextStyle(fontSize: sh * 0.013, letterSpacing: 2, fontFamily: 'monospace', color: Colors.white30)),
              Text(
                _audioEngine.currentHz > 0 ? '${_audioEngine.currentHz.toStringAsFixed(1)} Hz' : '— Hz',
                style: TextStyle(fontSize: sw * 0.018, fontWeight: FontWeight.w800, fontFamily: 'monospace',
                  color: _audioEngine.currentHz > 0 ? bassColor : Colors.white24),
              ),
              Text(_audioEngine.currentNote, style: GoogleFonts.playfairDisplay(
                fontSize: sw * 0.02, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic,
                color: _audioEngine.currentHz > 0 ? Colors.white : Colors.white24,
              )),
            ]),
          ),

          const Spacer(),

          // Title
          Flexible(child: ShaderMask(
            shaderCallback: (b) => const LinearGradient(colors: [KColors.amber, KColors.amberLight, KColors.amber]).createShader(b),
            child: Text('"${lesson?.title ?? _mapTitle}"',
              style: GoogleFonts.playfairDisplay(fontSize: sh * 0.035, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.white),
              overflow: TextOverflow.ellipsis),
          )),

          const Spacer(),

          // Score
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text('SCORE', style: TextStyle(fontSize: sh * 0.015, letterSpacing: 2, fontFamily: 'monospace', color: hitLineColor.withOpacity(0.4))),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(colors: [KColors.amberLight, KColors.amber]).createShader(b),
              child: Text('$_score', style: TextStyle(fontSize: sw * 0.025, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBottomBar(double sw, double sh) {
    final progress = _duration > 0 ? (_currentTimeMs / 1000) / _duration : 0.0;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFF0A0806), const Color(0xFF0A0806).withOpacity(0.85), Colors.transparent],
        )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Timeline
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.08),
            child: Container(
              height: sh * 0.03,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(sh * 0.01)),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0), alignment: Alignment.centerLeft,
                child: Container(decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(sh * 0.01),
                  gradient: const LinearGradient(colors: [KColors.amber, KColors.amberLight]),
                )),
              ),
            ),
          ),

          // Controls row
          Padding(
            padding: EdgeInsets.fromLTRB(sw * 0.03, sh * 0.008, sw * 0.03, sh * 0.015),
            child: Row(children: [
              _iconBtn(Icons.pause, Icons.play_arrow, _isPlaying, _togglePlay, sw, sh),
              SizedBox(width: sw * 0.008),
              _iconBtn(Icons.refresh, Icons.refresh, true, _restart, sw, sh),
              SizedBox(width: sw * 0.015),
              Text(_fmt(_currentTimeMs), style: TextStyle(fontSize: sh * 0.022, fontFamily: 'monospace', color: hitLineColor.withOpacity(0.5))),
              Text(' / ${_fmt((_duration * 1000).round())}', style: TextStyle(fontSize: sh * 0.022, fontFamily: 'monospace', color: Colors.white.withOpacity(0.2))),

              const Spacer(),

              // Kui On/Off
              GestureDetector(
                onTap: _toggleKui,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: sw * 0.012, vertical: sh * 0.006),
                  decoration: BoxDecoration(
                    color: _kuiOn ? bassColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(sh * 0.015),
                    border: Border.all(color: _kuiOn ? bassColor.withOpacity(0.3) : Colors.white10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_kuiOn ? Icons.music_note : Icons.music_off, size: sh * 0.022, color: _kuiOn ? bassColor : Colors.white38),
                    SizedBox(width: sw * 0.004),
                    Text(_kuiOn ? 'KUI' : 'OFF', style: TextStyle(fontSize: sh * 0.018, fontWeight: FontWeight.w700, color: _kuiOn ? bassColor : Colors.white38)),
                  ]),
                ),
              ),
              SizedBox(width: sw * 0.01),

              // Tempo
              Container(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.008, vertical: sh * 0.004),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(sh * 0.015)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.speed, size: sh * 0.02, color: Colors.white38),
                  SizedBox(
                    width: sw * 0.08,
                    child: SliderTheme(
                      data: SliderThemeData(
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: sh * 0.01),
                        trackHeight: sh * 0.005,
                        activeTrackColor: hitLineColor,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: hitLineColor,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(value: _tempoRate, min: 0.5, max: 1.0,
                        divisions: 4, onChanged: _setTempo),
                    ),
                  ),
                  Text('${(_tempoRate * 100).round()}%', style: TextStyle(fontSize: sh * 0.016, fontFamily: 'monospace', color: Colors.white38)),
                ]),
              ),
              SizedBox(width: sw * 0.01),

              // Stats
              _StatBadge(label: 'P', value: '$_perfectCount', color: KColors.yellow, sh: sh),
              SizedBox(width: sw * 0.008),
              _StatBadge(label: 'G', value: '$_goodCount', color: bassColor, sh: sh),
              SizedBox(width: sw * 0.008),
              _StatBadge(label: 'M', value: '$_missCount', color: KColors.red, sh: sh),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData active, IconData inactive, bool isActive, VoidCallback onTap, double sw, double sh) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(sw * 0.01),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(sw * 0.012), border: Border.all(color: Colors.white10)),
        child: Icon(isActive ? active : inactive, size: sw * 0.022, color: Colors.white60),
      ),
    );
  }
}

// ── HELPER WIDGETS ───────────────────────────────────────────
class _FeedbackWidget extends StatefulWidget {
  final String text;
  final double sw, sh;
  const _FeedbackWidget({super.key, required this.text, required this.sw, required this.sh});
  @override
  State<_FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends State<_FeedbackWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween(begin: 0.5, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [KColors.amberLight, KColors.amber]).createShader(b),
          child: Text(widget.text, style: GoogleFonts.inter(
            fontSize: widget.sw * 0.04, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white,
          )),
        )),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  final double sh;
  const _StatBadge({required this.label, required this.value, required this.color, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: sh * 0.014, letterSpacing: 1, color: color.withOpacity(0.5))),
      Text(value, style: TextStyle(fontSize: sh * 0.025, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

class DombraLoader extends StatelessWidget {
  const DombraLoader({super.key});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: w * 0.2, height: w * 0.2, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(strokeWidth: w * 0.01, valueColor: const AlwaysStoppedAnimation<Color>(KColors.emerald)),
        Icon(Icons.music_note, size: w * 0.08, color: Colors.white.withOpacity(0.8)),
      ])),
      SizedBox(height: w * 0.04),
      Text("Loading Kui...", style: TextStyle(fontSize: w * 0.04, color: Colors.white.withOpacity(0.5), letterSpacing: 1.2)),
    ]));
  }
}
