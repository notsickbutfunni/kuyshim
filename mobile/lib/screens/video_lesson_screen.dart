/// VideoLessonScreen — Plays an intro video lesson with language-aware audio.
/// Uses video_player for the video and just_audio for the language narration track.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../main.dart';
import '../constants/learn_path_data.dart';
import '../services/language_service.dart';
import '../screens/learn_screen.dart';

class VideoLessonScreen extends StatefulWidget {
  const VideoLessonScreen({super.key});

  @override
  State<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<VideoLessonScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  just_audio.AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isVideoFinished = false;
  bool _showControls = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  LearnNode? _node;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _node = LearnPathState.currentNode;
    if (_node != null && _node!.videoAsset != null) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final lang = context.read<LanguageService>().lang;

      // Initialize video (muted — audio comes from the narration track)
      _videoController = VideoPlayerController.asset(
        _node!.videoAsset!,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      final audioPath = _node!.audioAssets?[lang];
      if (audioPath != null) {
        _audioPlayer = just_audio.AudioPlayer();
      }

      // Initialize both concurrently to speed up loading
      await Future.wait([
        _videoController!.initialize(),
        if (_audioPlayer != null && audioPath != null)
          _audioPlayer!.setAsset(audioPath),
      ]);

      _videoController!.setVolume(0.0); // mute video track
      _videoController!.setLooping(false);
      _videoController!.addListener(_onVideoProgress);

      if (mounted) {
        setState(() => _isInitialized = true);

        // Auto-play
        _videoController!.play();
        _audioPlayer?.play();
      }
    } catch (e) {
      debugPrint('VideoLessonScreen: Error initializing video: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _onVideoProgress() {
    if (_videoController == null) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;

    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200 &&
        !_isVideoFinished) {
      setState(() => _isVideoFinished = true);
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _audioPlayer?.pause();
      } else {
        _videoController!.play();
        _audioPlayer?.play();
      }
    });
  }

  void _onComplete() {
    // Mark the learn path node as completed
    LearnPathState.onNodeCompleted?.call(true);
    if (mounted) {
      context.go('/learn');
    }
  }

  void _onSkip() {
    // Mark as completed even when skipping
    LearnPathState.onNodeCompleted?.call(true);
    if (mounted) {
      context.go('/learn');
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    _audioPlayer?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final sz = MediaQuery.of(context).size;
    final sw = sz.width;
    final sh = sz.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video Area ──────────────────────────────────────
            if (_isInitialized && _videoController != null)
              GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else if (_hasError)
              _buildErrorState(t, sh, sw)
            else
              _buildLoadingState(sh),

            // ── Top Bar (Skip button + Title) ───────────────────
            _buildTopBar(t, sh, sw),

            // ── Bottom Controls ─────────────────────────────────
            if (_isInitialized) _buildBottomControls(t, sh, sw),

            // ── Finish Overlay ───────────────────────────────────
            if (_isVideoFinished) _buildFinishOverlay(t, sh, sw),
          ],
        ),
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────
  Widget _buildLoadingState(double sh) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: sh * 0.06,
            height: sh * 0.06,
            child: const CircularProgressIndicator(
              color: KColors.emerald,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: sh * 0.03),
          Text(
            '...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: sh * 0.025,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────
  Widget _buildErrorState(dynamic t, double sh, double sw) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_rounded,
            color: Colors.white.withOpacity(0.3),
            size: sh * 0.1,
          ),
          SizedBox(height: sh * 0.02),
          Text(
            'Video not available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: sh * 0.03,
            ),
          ),
          SizedBox(height: sh * 0.03),
          ElevatedButton(
            onPressed: _onSkip,
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sh * 0.02),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.04,
                vertical: sh * 0.02,
              ),
            ),
            child: Text(
              t.continueLabel,
              style: GoogleFonts.inter(
                fontSize: sh * 0.025,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar(dynamic t, double sh, double sw) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.fromLTRB(sw * 0.02, sh * 0.04, sw * 0.02, sh * 0.02),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => context.go('/learn'),
                child: Container(
                  padding: EdgeInsets.all(sh * 0.015),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(sh * 0.015),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: sh * 0.025,
                  ),
                ),
              ),
              SizedBox(width: sw * 0.015),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.videoIntroTitle,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: sh * 0.03,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sh * 0.003),
                    Text(
                      t.videoIntroDescription,
                      style: TextStyle(
                        fontSize: sh * 0.017,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Skip button
              if (!_isVideoFinished)
                GestureDetector(
                  onTap: _onSkip,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: sw * 0.015,
                      vertical: sh * 0.012,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(sh * 0.015),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.skipVideo,
                          style: TextStyle(
                            fontSize: sh * 0.02,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: sw * 0.005),
                        Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: sh * 0.025,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom controls (progress bar + play/pause) ───────────────
  Widget _buildBottomControls(dynamic t, double sh, double sw) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.fromLTRB(sw * 0.03, sh * 0.02, sw * 0.03, sh * 0.04),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoController!,
                builder: (context, value, child) {
                  final duration = value.duration.inMilliseconds;
                  final position = value.position.inMilliseconds;
                  final progress = duration > 0 ? position / duration : 0.0;

                  return Column(
                    children: [
                      // Time labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(value.position),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: sh * 0.018,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: sh * 0.018,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: sh * 0.008),
                      // Progress track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(sh * 0.005),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              KColors.emerald),
                          minHeight: sh * 0.008,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: sh * 0.015),
              // Play/Pause button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: EdgeInsets.all(sh * 0.02),
                      decoration: BoxDecoration(
                        color: KColors.emerald.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KColors.emerald.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: KColors.emerald.withOpacity(0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: KColors.emerald,
                        size: sh * 0.04,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Finish overlay ────────────────────────────────────────────
  Widget _buildFinishOverlay(dynamic t, double sh, double sw) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              padding: EdgeInsets.all(sh * 0.03),
              decoration: BoxDecoration(
                color: KColors.emerald.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: KColors.emerald.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: KColors.emerald.withOpacity(0.2),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                color: KColors.emerald,
                size: sh * 0.06,
              ),
            ),
            SizedBox(height: sh * 0.03),
            Text(
              t.done,
              style: GoogleFonts.playfairDisplay(
                fontSize: sh * 0.045,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: sh * 0.01),
            Text(
              t.videoIntroDescription,
              style: TextStyle(
                fontSize: sh * 0.022,
                color: Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sh * 0.04),
            // Continue button
            GestureDetector(
              onTap: _onComplete,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sw * 0.06,
                  vertical: sh * 0.02,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [KColors.emerald, KColors.emeraldDark],
                  ),
                  borderRadius: BorderRadius.circular(sh * 0.02),
                  boxShadow: [
                    BoxShadow(
                      color: KColors.emerald.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: sh * 0.03,
                    ),
                    SizedBox(width: sw * 0.01),
                    Text(
                      t.continueLabel,
                      style: GoogleFonts.inter(
                        fontSize: sh * 0.025,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
