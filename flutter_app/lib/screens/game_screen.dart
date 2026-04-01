import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';

import '../models/game_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ScrollNote {
  final int id;
  final double time;
  final int string;
  final int fret;
  final double duration;
  bool hit;

  ScrollNote({
    required this.id,
    required this.time,
    required this.string,
    required this.fret,
    required this.duration,
    this.hit = false,
  });
}

List<ScrollNote> generateNotesForDuration(double duration) {
  if (duration <= 0) return [];
  final notes = <ScrollNote>[];
  final rand = Random(42);
  final patterns = [
    [0.0, 0.5, 1.2, 1.8],
    [0.0, 0.4, 0.8, 1.5, 2.0],
    [0.0, 0.6, 1.0, 1.6],
    [0.0, 0.3, 0.9, 1.4, 2.1],
  ];
  int id = 0;
  double t = 1;
  int patIdx = 0;
  while (t < duration - 1) {
    final pattern = patterns[patIdx % patterns.length];
    for (final offset in pattern) {
      if (t + offset >= duration - 0.5) break;
      notes.add(ScrollNote(
        id: id++,
        time: t + offset,
        string: rand.nextInt(2) + 1,
        fret: rand.nextInt(7),
        duration: 0.2 + rand.nextDouble() * 0.3,
      ));
    }
    t += 2.5 + rand.nextDouble();
    patIdx++;
  }
  return notes;
}

String formatTime(double s) {
  final m = (s / 60).floor();
  final sec = (s % 60).floor();
  return '$m:${sec.toString().padLeft(2, '0')}';
}

const feedbackTexts = ['MUZIKER!', 'КЕРЕМЕТ!', 'ЖАРАЙСЫҢ!', 'ТАМАША!'];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 0;
  double _playbackSpeed = 1;

  bool _loadError = false;
  bool _isMuted = false;

  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfect = 0;
  int _good = 0;
  int _miss = 0;

  String? _feedbackText;

  List<ScrollNote> _notes = [];
  double _lastHitTime = 0;
  Timer? _ticker;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  void _setupAudio() async {
    final provider = context.read<AppProvider>();
    final lesson = provider.selectedLesson!;
    final audioFile = lesson.audioFile;
    if (audioFile == null) {
      setState(() => _loadError = true);
      return;
    }

    final url = ApiService.getAudioUrl(lesson.level ?? 'beginner', audioFile);

    _player.onDurationChanged.listen((d) {
      setState(() {
        _duration = d.inMilliseconds / 1000.0;

        _notes = generateNotesForDuration(_duration);
      });
    });

    _player.onPositionChanged.listen((p) {
      setState(() {
        _currentTime = p.inMilliseconds / 1000.0;
      });
      _checkHits();
    });

    _player.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
      _handleFinish();
    });

    try {
      await _player.setSourceUrl(url);
    } catch (_) {
      setState(() => _loadError = true);
    }
  }

  void _checkHits() {
    if (!_isPlaying) return;
    final now = _currentTime;
    const hitWindow = 0.25;
    bool changed = false;

    for (final n in _notes) {
      if (!n.hit && (n.time - now).abs() < hitWindow && now - _lastHitTime > 0.15) {
        n.hit = true;
        _lastHitTime = now;
        changed = true;
        final isPerfect = (n.time - now).abs() < 0.1;
        if (isPerfect) {
          _perfect++;
          _score += 150 * min(_combo + 1, 8);
        } else {
          _good++;
          _score += 80 * min(_combo + 1, 8);
        }
        _combo++;
        _maxCombo = max(_maxCombo, _combo);

        final txt = feedbackTexts[Random().nextInt(feedbackTexts.length)];
        _feedbackText = isPerfect ? txt : 'GOOD!';
      }
      if (!n.hit && n.time < now - hitWindow * 2) {
        n.hit = true;
        _miss++;
        _combo = 0;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          _recordingPath = '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.wav';
        } else {
          _recordingPath = null;
        }
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: _recordingPath ?? '',
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<String?> _stopRecording() async {
    if (!_isRecording) return null;
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  void _handleFinish() async {
    final path = await _stopRecording();
    Uint8List? audioBytes;
    String filename = 'recording.wav';
    
    if (path != null) {
      try {
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          audioBytes = response.bodyBytes;
        } else {
          audioBytes = await File(path).readAsBytes();
          filename = path.split('/').last;
        }
      } catch (e) {
        debugPrint('Error reading recording: $e');
      }
    }

    final total = _perfect + _good + _miss;
    if (total == 0) return;
    final accuracy =
        ((_perfect + _good * 0.7) / total * 100).round();
    String rank = 'C';
    if (accuracy > 95) {
      rank = 'S';
    } else if (accuracy > 85) {
      rank = 'A';
    } else if (accuracy > 70) {
      rank = 'B';
    }

    final provider = context.read<AppProvider>();
    final lesson = provider.selectedLesson!;

    provider.finishGame(
      GameResult(
        score: _score,
        perfect: _perfect,
        good: _good,
        miss: _miss,
        accuracy: accuracy,
        lessonTitle: lesson.title,
        rank: rank,
        suggestion: accuracy >= 85
            ? 'Керемет орындадыңыз! Келесі күйге дайынсыз. / Amazing performance!'
            : 'Жаттығуды жалғастырыңыз. / Keep practicing!',
      ),
      audioBytes: audioBytes,
      audioFilename: filename,
    );
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (_isRecording) {
        await _audioRecorder.pause();
      }
    } else {
      await _player.resume();
      if (_isRecording) {
        await _audioRecorder.resume();
      } else {
        await _startRecording();
      }
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _restart() async {
    await _stopRecording();
    await _player.seek(Duration.zero);
    setState(() {
      _currentTime = 0;
      _score = 0;
      _combo = 0;
      _maxCombo = 0;

      _perfect = 0;
      _good = 0;
      _miss = 0;
      _feedbackText = null;
      _lastHitTime = 0;
      if (_duration > 0) _notes = generateNotesForDuration(_duration);
    });
    await _player.resume();
    setState(() => _isPlaying = true);
  }

  void _changeSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setPlaybackRate(speed);
    setState(() {});
  }

  void _toggleMute() async {
    _isMuted = !_isMuted;
    await _player.setVolume(_isMuted ? 0 : 0.8);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _player.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lesson = provider.selectedLesson!;
    final t = provider.t;
    final progress = _duration > 0 ? _currentTime / _duration : 0.0;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0806),
      body: Column(
        children: [
          // Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 16, 48, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    _player.stop();
                    provider.navigateTo(AppScreen.library);
                  },
                  icon: Icon(Icons.chevron_left,
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
                const Spacer(),
                Column(
                  children: [
                    Text(t.currentKui,
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 4,
                            color: AppColors.amber.withValues(alpha: 0.6),
                            fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFD4A843),
                          Color(0xFFF5D97A),
                          Color(0xFFD4A843),
                        ],
                      ).createShader(bounds),
                      child: Text('"${lesson.title}"',
                          style: serifBold(22, color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    Text('${t.by} ${lesson.composer}',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.amber.withValues(alpha: 0.4),
                            letterSpacing: 3)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.score,
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.amber.withValues(alpha: 0.4),
                            letterSpacing: 2,
                            fontFamily: 'monospace')),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFF0C850), Color(0xFFD4A843)],
                      ).createShader(bounds),
                      child: Text(
                        _score.toString(),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.combo,
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.amber.withValues(alpha: 0.4),
                            letterSpacing: 2,
                            fontFamily: 'monospace')),
                    Text(
                      'x$_combo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _combo >= 20
                            ? Colors.red[400]
                            : _combo >= 10
                                ? Colors.amber[300]
                                : _combo >= 5
                                    ? Colors.yellow[400]
                                    : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rhythm Highway
          Expanded(
            child: Stack(
              children: [
                // Ambient glow
                Center(
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber.withValues(alpha: 0.04),
                    ),
                  ),
                ),

                // String lanes
                Center(
                  child: SizedBox(
                    width: 400,
                    child: Stack(
                      children: [
                        // String 1
                        Positioned(
                          left: 400 * 0.33,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.amber.withValues(alpha: 0.05),
                                  AppColors.amber.withValues(alpha: 0.3),
                                  AppColors.amber.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // String 2
                        Positioned(
                          left: 400 * 0.66,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.cyan.withValues(alpha: 0.05),
                                  Colors.cyan.withValues(alpha: 0.3),
                                  Colors.cyan.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Hit zone line
                        Positioned(
                          left: 0,
                          right: 0,
                          top: screenHeight * 0.55,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.amber,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Notes
                        ..._notes.where((n) => !n.hit).map((note) {
                          final timeUntilHit = note.time - _currentTime;
                          final hitZonePx = screenHeight * 0.55;
                          final y = hitZonePx - timeUntilHit * 120;
                          if (y < -60 || y > screenHeight) {
                            return const SizedBox.shrink();
                          }
                          final x = note.string == 1 ? 400 * 0.33 : 400 * 0.66;
                          final isAmber = note.string == 1;
                          return Positioned(
                            left: x - 24,
                            top: y - 24,
                            child: Transform.rotate(
                              angle: 0.785,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAmber
                                        ? AppColors.amber.withValues(alpha: 0.8)
                                        : Colors.cyan.withValues(alpha: 0.8),
                                    width: 2,
                                  ),
                                  color: isAmber
                                      ? AppColors.amber.withValues(alpha: 0.2)
                                      : Colors.cyan.withValues(alpha: 0.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isAmber
                                          ? AppColors.amber.withValues(alpha: 0.3)
                                          : Colors.cyan.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: -0.785,
                                    child: Text(
                                      '${note.fret}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: isAmber
                                            ? Colors.amber[300]
                                            : Colors.cyan[300],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        // Feedback text
                        if (_feedbackText != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: screenHeight * 0.55 - 80,
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: _feedbackText == 'GOOD!'
                                      ? [
                                          const Color(0xFF34D399),
                                          const Color(0xFF10B981)
                                        ]
                                      : [
                                          const Color(0xFFF5D97A),
                                          const Color(0xFFD4A843),
                                          const Color(0xFFF0C850)
                                        ],
                                ).createShader(bounds),
                                child: Text(
                                  _feedbackText!,
                                  style: serifBold(28, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Difficulty indicator (left side)
                Positioned(
                  left: 48,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Container(
                            width: 6,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i < lesson.difficulty
                                  ? AppColors.amber.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Controls
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppColors.amber.withValues(alpha: 0.1)),
              ),
              color: const Color(0xFF0A0806).withValues(alpha: 0.8),
            ),
            child: Column(
              children: [
                // Progress bar
                GestureDetector(
                  onTapDown: (details) {
                    if (_duration <= 0) return;
                    final w = MediaQuery.of(context).size.width;
                    final ratio = details.localPosition.dx / w;
                    _player.seek(Duration(
                        milliseconds: (ratio * _duration * 1000).toInt()));
                  },
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFB47D2B), AppColors.amber],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  child: Row(
                    children: [
                      // Time
                      Text(formatTime(_currentTime),
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.amber.withValues(alpha: 0.4))),
                      Text(' / ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.1),
                              fontSize: 11)),
                      Text(
                          _duration > 0
                              ? formatTime(_duration)
                              : '0:00',
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.white.withValues(alpha: 0.2))),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),

                      const Spacer(),

                      // Controls
                      _CtrlBtn(
                        icon: Icons.replay,
                        onTap: _restart,
                      ),
                      const SizedBox(width: 12),
                      // Play button
                      GestureDetector(
                        onTap: _loadError ? null : _togglePlay,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFD4A843),
                                Color(0xFFF0C850),
                                Color(0xFFD4A843),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFF0A0806),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Speed selector
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [0.5, 0.75, 1.0].map((speed) {
                            final active = _playbackSpeed == speed;
                            return GestureDetector(
                              onTap: () => _changeSpeed(speed),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.amber.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${speed}x',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: active
                                            ? Colors.amber[300]
                                            : Colors.white.withValues(alpha: 0.3))),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const Spacer(),

                      // Stats
                      _StatMini(label: t.perfect, value: '$_perfect',
                          color: AppColors.amber),
                      const SizedBox(width: 16),
                      _StatMini(label: t.good, value: '$_good',
                          color: AppColors.emerald),
                      const SizedBox(width: 16),
                      _StatMini(label: t.miss, value: '$_miss',
                          color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CtrlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatMini(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 7,
                color: color.withValues(alpha: 0.3),
                letterSpacing: 2,
                fontFamily: 'monospace')),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
