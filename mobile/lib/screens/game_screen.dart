/// GameScreen — Yousician-style 2-string dombra rhythm game.
/// Uses just_audio for pitch-preserving tempo, CustomPainter for rendering.
///
/// Performance architecture:
///   - _timeNotifier (ValueNotifier<int>) drives the painter and time display
///     WITHOUT rebuilding the entire widget tree.
///   - setState is only called when game state actually changes (score, combo,
///     play/pause, feedback text) — NOT every frame.
///   - AudioEngine no longer triggers setState; its data is read during gameTick.
library;
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
import '../services/language_service.dart';
import '../services/level_manager.dart' show AudioSourceType;
import '../constants/tutorial_data.dart';
import '../screens/learn_screen.dart' show LearnPathState;
import 'game_painter.dart';
import '../widgets/calibration_dialog.dart';

const List<String> _hitTexts = ['КЕРЕМЕТ!', 'ЖАРАЙСЫҢ!', 'ТАМАША!', 'ДҰРЫС!'];
const List<String> _goodTexts = ['ЖАҚСЫ!', 'ЖАМАН ЕМЕС!'];

class GameScreen extends StatefulWidget {
  final bool isTutorialMode;
  const GameScreen({super.key, this.isTutorialMode = false});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Audio
  final ja.AudioPlayer _player = ja.AudioPlayer();
  final ja.AudioPlayer _beepPlayer = ja.AudioPlayer();
  final AudioEngine _audioEngine = AudioEngine();

  // Training mode — read from AppState
  bool get _isTrainingMode =>
      !widget.isTutorialMode &&
      (context.read<AppState>().isTrainingMode);

  // State
  bool _isPlaying = false;
  bool _isLoaded = false;
  bool _kuiOn = true;
  double _tempoRate = 1.0;
  double _duration = 0;

  // ── Performance: time is driven by ValueNotifier, NOT setState ──
  /// This notifier updates every frame and only rebuilds the painter +
  /// the time display via ValueListenableBuilder — not the entire tree.
  final ValueNotifier<int> _timeNotifier = ValueNotifier<int>(0);

  // Notes
  List<KuiNote> _allNotes = [];
  List<KuiNote> _activeNotes = [];
  List<double> _beatTimes = [];
  String _mapTitle = '';

  // Score — only setState when these change
  int _score = 0, _combo = 0, _maxCombo = 0;
  int _perfectCount = 0, _goodCount = 0, _missCount = 0;
  String? _feedbackText;
  int _feedbackKey = 0;

  // Cached previous HUD values to avoid unnecessary setState

  // Game loop
  Ticker? _ticker;
  /// Index of the first note that hasn't been played/missed yet.
  /// Avoids scanning all notes every frame in competitive mode.
  int _nextNoteIndex = 0;

  // Tutorial mode
  bool _tutorialWaiting = false;
  int _tutorialTargetIdx = 0;
  Duration? _lastTickDuration;
  int _simulatedTimeMs = 0;

  // Snappy Pitch Matching history
  int _lastHitRealTimeMs = 0;
  String _lastHitNote = '';

  // Random instance — reuse instead of creating per-hit
  final math.Random _rng = math.Random();

  Future<void> _safePlay() async {
    try {
      if (!_player.playing) {
        await _player.play();
      }
    } catch (e) {
      debugPrint('[GameScreen] safePlay error: $e');
    }
  }

  Future<void> _safePause() async {
    try {
      if (_player.playing) {
        await _player.pause();
      }
    } catch (e) {
      debugPrint('[GameScreen] safePause error: $e');
    }
  }

  bool _isNoteMatch(KuiNote note) {
    if (!_audioEngine.isFrequencyMatch(note.primaryHz, toleranceCents: 100.0, stringName: note.stringName)) {
      return false;
    }
    // Frequency matches! Now check if we should accept it.
    // 1. If we have a clean onset, always accept.
    if (_audioEngine.hasRecentOnset) return true;
    
    // 2. If it's a different note than the last hit, accept (change of pitch is enough).
    if (note.primaryNote != _lastHitNote) return true;
    
    // 3. If it's the same note but enough real-time has passed, accept.
    //    Reduced from 600ms→250ms — a dombra player can re-pluck the same
    //    string in ~200ms, and the old 600ms blocked fast repeated notes.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitRealTimeMs > 250) return true;
    
    return false;
  }

  // Countdown before competitive game starts
  int _countdownValue = 0; // 5, 4, 3, 2, 1, 0 (0 = done)
  bool _showGo = false; // brief "GO!" flash
  Timer? _countdownTimer;
  bool _audioStarted = false;

  // Config — hit windows
  // Widened from 150/350 to give more room for audio processing latency.
  static const int perfectWindowMs = 200;
  static const int goodWindowMs = 450;
  /// Latency compensation: shifts the hit window to account for
  /// the ~80-100ms audio pipeline delay (mic → buffer → YIN → game tick).
  /// Without this, physically-on-time plucks always register as "late".
  static const int latencyOffsetMs = 80;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _initGame();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker?.dispose();
    _timeNotifier.dispose();
    _audioEngine.dispose();
    _player.dispose();
    _beepPlayer.dispose();
    super.dispose();
  }

  // ── INIT ───────────────────────────────────────────────────
  Future<void> _initGame() async {
    if (widget.isTutorialMode) {
      _loadTutorialMap();
      try {
        await _audioEngine.start();
      } catch (_) {}
      
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _isPlaying = true;
        });
        _ticker?.start();
      }
    } else if (_isTrainingMode) {
      // Training mode: load real lesson map, load audio, use tutorial-style tick
      await _loadMap();
      if (mounted) await _initAudio();
      try {
        await _audioEngine.start();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _isPlaying = true;
        });
        _simulatedTimeMs = -2000; // 2 seconds pre-roll
        _audioStarted = false;
        _ticker?.start();
      }
    } else {
      await _loadMap();
      if (mounted) await _initAudio();
      try {
        await _audioEngine.start();
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoaded = true);
        // Start 5-4-3-2-1 countdown before playing
        _startCountdown();
      }
    }
  }

  /// 5-4-3-2-1 countdown with beep sounds before competitive game starts.
  void _startCountdown() {
    _countdownValue = 5;
    _showGo = false;
    _playCountdownBeep(isGo: false);
    setState(() {});
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _countdownValue--;
      if (_countdownValue <= 0) {
        timer.cancel();
        _countdownValue = 0;
        _showGo = true;
        _playCountdownBeep(isGo: true);
        setState(() {});
        // Brief "GO!" flash, then start the game
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _showGo = false;
          setState(() => _isPlaying = true);
          _simulatedTimeMs = -2000; // 2 seconds pre-roll
          _audioStarted = false;
          _lastTickDuration = null;
          _ticker?.start();
        });
      } else {
        _playCountdownBeep(isGo: false);
        setState(() {});
      }
    });
  }

  /// Play countdown beep sound from assets.
  Future<void> _playCountdownBeep({required bool isGo}) async {
    try {
      final asset = isGo ? 'assets/sounds/countdown_go.wav' : 'assets/sounds/countdown_tick.wav';
      await _beepPlayer.setAsset(asset);
      await _beepPlayer.seek(Duration.zero);
      await _beepPlayer.play();
    } catch (e) {
      debugPrint('[GameScreen] Beep play error: $e');
    }
  }

  void _loadTutorialMap() {
    _mapTitle = tutorialMeta['title'];
    _duration = tutorialMeta['duration_sec'];
    _allNotes = tutorialNotes.map((n) => KuiNote.fromJson(n)).toList();
    _activeNotes = _allNotes.toList();
    _beatTimes = [];
  }

  Future<void> _loadMap() async {
    if (!mounted) return;
    final lesson = context.read<AppState>().selectedLesson;
    String? jsonStr;

    if (lesson?.jsonMapFile == 'learn_path' && LearnPathState.currentNode != null) {
      _mapTitle = LearnPathState.currentNode!.title;
      _duration = 60.0; // Default for skill nodes
      _allNotes = List.from(LearnPathState.currentNode!.notes);
      _activeNotes = _allNotes.toList();
      _beatTimes = [];
      return;
    }

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
      final source = await appState.levelManager.resolveAudio(lesson);
      if (!mounted) return;

      if (source.type == AudioSourceType.asset) {
        // Local bundled audio
        await _player.setAsset('assets/${source.path}');
      } else if (source.type == AudioSourceType.cachedFile) {
        // Previously cached file on device
        await _player.setFilePath(source.path);
      } else {
        // Remote — stream directly from backend, no download needed
        await _player.setUrl(source.path);
      }
      await _player.setSpeed(_tempoRate);
      await _player.setVolume(_kuiOn ? 1.0 : 0.0);

      _player.playerStateStream.listen((s) {
        if (s.processingState == ja.ProcessingState.completed && mounted) {
          _handleFinish();
        }
      });
    } catch (e) {
      debugPrint('[GameScreen] Audio init error: $e');
      // Game still works — notes scroll and scoring happens,
      // just without background küy audio.
    }
  }

  // ── GAME LOOP ──────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;

    bool usePitchGate = widget.isTutorialMode || _isTrainingMode;
    
    // Override for specific Learn Path nodes
    if (_isTrainingMode && context.read<AppState>().selectedLesson?.jsonMapFile == 'learn_path') {
      if (LearnPathState.currentNode != null && !LearnPathState.currentNode!.isPitchGate) {
        usePitchGate = false;
      }
    }

    if (usePitchGate) {
      _tutorialTick(elapsed);
    } else {
      _continuousTick(elapsed);
    }
  }

  void _continuousTick(Duration elapsed) {
    if (!_audioStarted) {
      if (_lastTickDuration == null) {
        _lastTickDuration = elapsed;
        return;
      }
      final deltaMs = (elapsed - _lastTickDuration!).inMilliseconds;
      _lastTickDuration = elapsed;

      _simulatedTimeMs += deltaMs;
      if (_simulatedTimeMs < 0) {
        _timeNotifier.value = _simulatedTimeMs;
        _gameTick();
      } else {
        _audioStarted = true;
        _safePlay();
        _timeNotifier.value = 0;
        _gameTick();
      }
    } else {
      // If there's no audio track (e.g. skill nodes), just advance simulated time
      if (_player.duration == null || _player.duration == Duration.zero) {
        if (_lastTickDuration == null) {
          _lastTickDuration = elapsed;
          return;
        }
        final deltaMs = (elapsed - _lastTickDuration!).inMilliseconds;
        _lastTickDuration = elapsed;
        _simulatedTimeMs += deltaMs;
        _timeNotifier.value = _simulatedTimeMs;
      } else {
        _timeNotifier.value = _player.position.inMilliseconds;
      }
      _gameTick();
    }
  }

  void _tutorialTick(Duration elapsed) {
    if (_lastTickDuration == null) {
      _lastTickDuration = elapsed;
      return;
    }
    final deltaMs = (elapsed - _lastTickDuration!).inMilliseconds;
    _lastTickDuration = elapsed;

    if (_tutorialTargetIdx >= _activeNotes.length) {
      _handleFinish();
      return;
    }

    final targetNote = _activeNotes[_tutorialTargetIdx];
    bool hudChanged = false;

    // Check if the user hits the note while it is within the hit window.
    // Apply latency compensation so on-time plucks don't register as "late".
    final diff = (_simulatedTimeMs - targetNote.timeMs) + latencyOffsetMs;

    if (_isNoteMatch(targetNote) && diff.abs() <= goodWindowMs) {
      // User hit the note in real-time!
      targetNote.isPlayed = true;
      targetNote.hitQuality = diff.abs() <= perfectWindowMs ? 'perfect' : 'good';

      _score += targetNote.hitQuality == 'perfect' ? 100 : 50;
      _combo++;
      _maxCombo = math.max(_maxCombo, _combo);
      if (targetNote.hitQuality == 'perfect') {
        _perfectCount++;
        _feedbackText = _hitTexts[_rng.nextInt(_hitTexts.length)];
      } else {
        _goodCount++;
        _feedbackText = _goodTexts[_rng.nextInt(_goodTexts.length)];
      }
      _feedbackKey++;
      hudChanged = true;

      _lastHitNote = targetNote.primaryNote;
      _lastHitRealTimeMs = DateTime.now().millisecondsSinceEpoch;

      _tutorialWaiting = false;
      _tutorialTargetIdx++;

      if (_audioStarted && !_player.playing) {
        _safePlay();
      }
    } else {
      // User hasn't hit it yet
      if (!_tutorialWaiting) {
        if (_audioStarted && _player.duration != null) {
          _simulatedTimeMs = _player.position.inMilliseconds;
        } else {
          _simulatedTimeMs += deltaMs;
        }

        // Start player when simulated time crosses 0 (pre-roll ends)
        if (!_audioStarted && _simulatedTimeMs >= 0) {
          _audioStarted = true;
          _safePlay();
        }

        // If we pass the note and haven't hit it, enter waiting state
        if (_simulatedTimeMs >= targetNote.timeMs) {
          _tutorialWaiting = true;
          _simulatedTimeMs = targetNote.timeMs; // freeze perfectly
          _safePause(); // Pause backing track while waiting!
        }
      } else {
        // We are waiting at the frozen note.
        // (Note match is handled by the check at the top of the tick on the next frame)
      }
    }

    if (hudChanged && mounted) {
      setState(() {});
    }

    _timeNotifier.value = _simulatedTimeMs;
  }

  void _gameTick() {
    final currentTimeMs = _timeNotifier.value;
    bool hudChanged = false;

    // Scan only notes near the current time (starting from _nextNoteIndex)
    for (int i = _nextNoteIndex; i < _activeNotes.length; i++) {
      final note = _activeNotes[i];
      // Apply latency compensation so physically-on-time plucks
      // aren't penalised by audio pipeline delay.
      final diff = (currentTimeMs - note.timeMs) + latencyOffsetMs;

      // Stop scanning if we're looking too far ahead
      if (diff < -goodWindowMs) break;

      if (note.isPlayed || note.isMissed) continue;

      if (diff.abs() <= goodWindowMs) {
        if (_isNoteMatch(note)) {
          note.isPlayed = true;
          _combo++;
          _maxCombo = math.max(_maxCombo, _combo);
          final mult = math.min(_combo, 8);

          if (diff.abs() <= perfectWindowMs) {
            note.hitQuality = 'perfect';
            _perfectCount++;
            _score += 100 * mult;
            _feedbackText = _hitTexts[_rng.nextInt(_hitTexts.length)];
          } else {
            note.hitQuality = 'good';
            _goodCount++;
            _score += 50 * mult;
            _feedbackText = _goodTexts[_rng.nextInt(_goodTexts.length)];
          }
          _feedbackKey++;
          
          _lastHitNote = note.primaryNote;
          _lastHitRealTimeMs = DateTime.now().millisecondsSinceEpoch;
          
          hudChanged = true;
        }
      } else if (diff > goodWindowMs) {
        note.isMissed = true;
        _missCount++;
        _combo = 0;
        hudChanged = true;
      }
    }

    // Advance _nextNoteIndex past played/missed notes
    while (_nextNoteIndex < _activeNotes.length &&
        (_activeNotes[_nextNoteIndex].isPlayed || _activeNotes[_nextNoteIndex].isMissed)) {
      _nextNoteIndex++;
    }

    // Only rebuild HUD widgets when score/stats actually changed
    if (hudChanged && mounted) {
      setState(() {});
    }

    if (_activeNotes.isNotEmpty && _activeNotes.every((n) => n.isPlayed || n.isMissed)) {
      _handleFinish();
    }
  }

  // ── CONTROLS ───────────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      setState(() => _isPlaying = false);
      _ticker?.stop();
      _safePause();
    } else {
      setState(() => _isPlaying = true);
      _lastTickDuration = null;
      _ticker?.start();
      if (_audioStarted) {
        _safePlay();
      }
    }
  }

  Future<void> _restart() async {
    _ticker?.stop();
    _countdownTimer?.cancel();
    setState(() => _isPlaying = false);
    
    try { 
      await _safePause();
      await _player.seek(Duration.zero); 
    } catch (_) {}
    for (final n in _activeNotes) { n.reset(); }
    _timeNotifier.value = 0;
    
    setState(() {
      _score = 0; _combo = 0; _maxCombo = 0;
      _perfectCount = 0; _goodCount = 0; _missCount = 0;
      _feedbackText = null;
      _tutorialWaiting = false;
      _tutorialTargetIdx = 0;
      _simulatedTimeMs = -2000; // Reset to -2000 for pre-roll!
      _lastTickDuration = null;
      _countdownValue = 0;
      _showGo = false;
      _audioStarted = false;
      
      _lastHitRealTimeMs = 0;
      _lastHitNote = '';
      _nextNoteIndex = 0;
    });

    // Re-trigger countdown for competitive mode
    if (!widget.isTutorialMode && !_isTrainingMode) {
      _startCountdown();
    } else {
      setState(() => _isPlaying = true);
      _ticker?.start();
    }
  }

  void _handleFinish() {
    _ticker?.stop();
    setState(() => _isPlaying = false);
    
    if (widget.isTutorialMode) {
      if (mounted) context.go('/onboarding');
      return;
    }
    
    final total = _perfectCount + _goodCount + _missCount;
    final acc = total > 0 ? ((_perfectCount + _goodCount) / total * 100).round() : 100;
    final appState = context.read<AppState>();
    
    // If it's a Learn Path node, report completion
    if (appState.selectedLesson?.jsonMapFile == 'learn_path') {
      // Pitch gate nodes require >= 70% accuracy; kui/story nodes always pass
      final isPitchGate = LearnPathState.currentNode?.isPitchGate == true;
      final success = isPitchGate ? (acc >= 70) : true;
      LearnPathState.onNodeCompleted?.call(success);
      if (mounted) context.go('/learn');
      return;
    }

    if (total == 0) return;
    
    String rank = acc > 95 ? 'S' : acc > 85 ? 'A' : acc > 70 ? 'B' : 'C';

    appState.finishGame(GameResult(
      score: _score, perfect: _perfectCount, good: _goodCount,
      miss: _missCount, accuracy: acc,
      lessonTitle: appState.selectedLesson?.title ?? _mapTitle,
      rank: rank,
      suggestion: _isTrainingMode
          ? (acc >= 85
              ? 'Жаттығу аяқталды! Енді соревновательный режимді көріңіз.'
              : 'Жаттығуды жалғастырыңыз. Әр нотаны мұқият тыңдаңыз.')
          : (acc >= 85
              ? 'Керемет орындадыңыз! Келесі күйге дайынсыз.'
              : 'Жаттығуды жалғастырыңыз. Ырғақты баяу жылдамдықта тыңдап көріңіз.'),
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
    final t = context.watch<LanguageService>().t;
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
        // Fretboard painter — driven by ValueNotifier, NOT setState
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _timeNotifier,
            builder: (context, timeMs, _) {
              return CustomPaint(
                size: Size(sw, sh),
                painter: GamePainter(
                  sw: sw, sh: sh,
                  currentTimeMs: timeMs,
                  activeNotes: _activeNotes,
                  beatTimesSec: _beatTimes,
                  isPlaying: _isPlaying,
                  tutorialWaitingNoteId: ((widget.isTutorialMode || _isTrainingMode) && _tutorialWaiting && _tutorialTargetIdx < _activeNotes.length)
                      ? _activeNotes[_tutorialTargetIdx].id
                      : null,
                ),
              );
            },
          ),
        ),

        // Feedback popup
        if (_feedbackText != null)
          Positioned(
            left: sw * 0.3, top: sh * 0.12,
            child: _FeedbackWidget(key: ValueKey(_feedbackKey),
              text: _feedbackText!, sw: sw, sh: sh),
          ),

        // Training mode indicator
        if (_isTrainingMode)
          Positioned(
            top: sh * 0.12, right: sw * 0.02,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: sw * 0.015, vertical: sh * 0.01),
              decoration: BoxDecoration(
                color: KColors.emerald.withOpacity(0.15),
                borderRadius: BorderRadius.circular(sh * 0.02),
                border: Border.all(color: KColors.emerald.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_rounded, size: sh * 0.03, color: KColors.emerald),
                SizedBox(width: sw * 0.005),
                Text('ОБУЧАЮЩИЙ', style: TextStyle(
                  fontSize: sh * 0.02, fontWeight: FontWeight.w700,
                  color: KColors.emerald, letterSpacing: 1.5,
                )),
              ]),
            ),
          ),

        // Top HUD
        _buildTopHUD(sw, sh, lesson),

        // Bottom controls
        _buildBottomBar(sw, sh),

        // Countdown overlay (competitive mode)
        if (_countdownValue > 0 || _showGo)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0806).withOpacity(0.7),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_showGo ? -1 : _countdownValue),
                  tween: Tween(begin: 1.5, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => LinearGradient(
                          colors: _showGo
                              ? [const Color(0xFF4CAF50), const Color(0xFF81C784), const Color(0xFF4CAF50)]
                              : [KColors.amber, KColors.amberLight, KColors.amber],
                        ).createShader(b),
                        child: Text(
                          _showGo ? 'GO!' : '$_countdownValue',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: sh * (_showGo ? 0.20 : 0.25),
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (!_showGo)
                        Text(
                          t.getReady,
                          style: TextStyle(
                            fontSize: sh * 0.035,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                            fontFamily: 'monospace',
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildTopHUD(double sw, double sh, dynamic lesson) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: RepaintBoundary(
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
                _ticker?.stop();
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

            const Spacer(),

            // Mic / Tuning display
            AnimatedBuilder(
              animation: _audioEngine,
              builder: (context, child) {
                final hasSignal = _audioEngine.calibratedHz > 0;
                return GestureDetector(
                  onTap: () async {
                    // Pause game if playing
                    if (_isPlaying) {
                      await _togglePlay();
                    }
                    if (mounted) {
                      // Stop audio engine before opening modal to avoid resource conflict
                      await _audioEngine.stop();
                      
                      await showCalibrationDialog(context);
                      
                      // Restart audio engine and reload calibration
                      await _audioEngine.start();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: sw * 0.018, vertical: sh * 0.006),
                    decoration: BoxDecoration(
                      color: hasSignal ? bassColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(sw * 0.015),
                      border: Border.all(
                        color: hasSignal ? bassColor.withOpacity(0.4) : Colors.white10,
                        width: 1.5,
                      ),
                      boxShadow: hasSignal ? [
                        BoxShadow(
                          color: bassColor.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: sw * 0.018, color: hasSignal ? bassColor : Colors.white30),
                        SizedBox(width: sw * 0.008),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TAP TO TUNE',
                              style: TextStyle(
                                fontSize: sh * 0.011,
                                letterSpacing: 1.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: hasSignal ? bassColor.withOpacity(0.7) : Colors.white30,
                              ),
                            ),
                            Text(
                              hasSignal ? '${_audioEngine.calibratedHz.toStringAsFixed(1)} Hz' : '— Hz',
                              style: TextStyle(
                                fontSize: sw * 0.016,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: hasSignal ? bassColor : Colors.white24,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: sw * 0.008),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: sw * 0.008, vertical: sh * 0.002),
                          decoration: BoxDecoration(
                            color: hasSignal ? Colors.white.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(sw * 0.005),
                          ),
                          child: Text(
                            _audioEngine.currentNote,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: sw * 0.02,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: hasSignal ? Colors.white : Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      ),
    );
  }

  Widget _buildBottomBar(double sw, double sh) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.only(bottom: sh * 0.01),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [const Color(0xFF0A0806), const Color(0xFF0A0806).withOpacity(0.9), Colors.transparent],
          )),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Timeline — driven by ValueNotifier
            ValueListenableBuilder<int>(
              valueListenable: _timeNotifier,
              builder: (context, timeMs, _) {
                final progress = _duration > 0 ? (timeMs / 1000) / _duration : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
                  child: Container(
                    height: sh * 0.025,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(sh * 0.008)),
                    clipBehavior: Clip.antiAlias,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0), alignment: Alignment.centerLeft,
                      child: Container(decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(sh * 0.008),
                        gradient: const LinearGradient(colors: [KColors.amber, KColors.amberLight]),
                      )),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: sh * 0.008),

            // Row 1: KUI toggle + Tempo slider + Stats
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sw * 0.03),
              child: Row(children: [
                // Kui On/Off
                GestureDetector(
                  onTap: _toggleKui,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: sw * 0.02, vertical: sh * 0.01),
                    decoration: BoxDecoration(
                      color: _kuiOn ? bassColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(sh * 0.015),
                      border: Border.all(color: _kuiOn ? bassColor.withOpacity(0.3) : Colors.white10, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_kuiOn ? Icons.music_note : Icons.music_off, size: sh * 0.028, color: _kuiOn ? bassColor : Colors.white38),
                      SizedBox(width: sw * 0.005),
                      Text(_kuiOn ? 'KUI' : 'OFF', style: TextStyle(fontSize: sh * 0.02, fontWeight: FontWeight.w700, color: _kuiOn ? bassColor : Colors.white38)),
                    ]),
                  ),
                ),
                SizedBox(width: sw * 0.012),

                // Tempo slider — hidden in training mode
                if (!_isTrainingMode) ...[
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: sw * 0.01, vertical: sh * 0.005),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(sh * 0.015)),
                      child: Row(children: [
                        Icon(Icons.speed, size: sh * 0.024, color: Colors.white38),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: sh * 0.012),
                              trackHeight: sh * 0.006,
                              activeTrackColor: hitLineColor,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: hitLineColor,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(value: _tempoRate, min: 0.2, max: 1.0,
                              divisions: 8, onChanged: _setTempo),
                          ),
                        ),
                        Text('${_tempoRate.toStringAsFixed(1)}x', style: TextStyle(fontSize: sh * 0.018, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: _tempoRate < 1.0 ? hitLineColor : Colors.white38)),
                      ]),
                    ),
                  ),
                  SizedBox(width: sw * 0.012),
                ],

                // Training mode label in bottom bar
                if (_isTrainingMode) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: sw * 0.015, vertical: sh * 0.01),
                    decoration: BoxDecoration(
                      color: KColors.emerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(sh * 0.015),
                      border: Border.all(color: KColors.emerald.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.mic, size: sh * 0.028, color: KColors.emerald),
                      SizedBox(width: sw * 0.005),
                      Text('НОТАНЫ ОЙНА', style: TextStyle(fontSize: sh * 0.02, fontWeight: FontWeight.w700, color: KColors.emerald)),
                    ]),
                  ),
                  const Spacer(),
                ],

                // Stats
                _StatBadge(label: 'P', value: '$_perfectCount', color: KColors.yellow, sh: sh),
                SizedBox(width: sw * 0.006),
                _StatBadge(label: 'G', value: '$_goodCount', color: bassColor, sh: sh),
                SizedBox(width: sw * 0.006),
                _StatBadge(label: 'M', value: '$_missCount', color: KColors.red, sh: sh),
              ]),
            ),
            SizedBox(height: sh * 0.008),

            // Row 2: Play/Pause + Restart + Time
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sw * 0.03),
              child: Row(children: [
                // Play/Pause — big prominent button
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: EdgeInsets.all(sw * 0.025),
                    decoration: BoxDecoration(
                      color: _isPlaying ? hitLineColor.withOpacity(0.15) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(sw * 0.02),
                      border: Border.all(color: _isPlaying ? hitLineColor.withOpacity(0.4) : Colors.white24, width: 2),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: sw * 0.05,
                      color: _isPlaying ? hitLineColor : Colors.white70,
                    ),
                  ),
                ),
                SizedBox(width: sw * 0.012),

                // Restart button
                GestureDetector(
                  onTap: _restart,
                  child: Container(
                    padding: EdgeInsets.all(sw * 0.02),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(sw * 0.018),
                      border: Border.all(color: Colors.white12, width: 1.5),
                    ),
                    child: Icon(Icons.refresh_rounded, size: sw * 0.04, color: Colors.white60),
                  ),
                ),
                SizedBox(width: sw * 0.02),

                // Time display
                ValueListenableBuilder<int>(
                  valueListenable: _timeNotifier,
                  builder: (context, timeMs, _) {
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_fmt(timeMs), style: TextStyle(fontSize: sh * 0.025, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: hitLineColor.withOpacity(0.6))),
                      Text(' / ${_fmt((_duration * 1000).round())}', style: TextStyle(fontSize: sh * 0.025, fontFamily: 'monospace', color: Colors.white.withOpacity(0.2))),
                    ]);
                  },
                ),
              ]),
            ),
          ]),
        ),
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
