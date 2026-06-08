/// StoryScreen — Visual novel style küy story experience.
/// Full-screen background image with a dialog box at the bottom.
/// Swipe or tap to navigate between slides. Reusable design for 3-7 pages.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../main.dart';
import '../constants/story_data.dart';
import '../models/lesson_model.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../constants/strings.dart';

class StoryScreen extends StatefulWidget {
  final String? initialLessonId;
  const StoryScreen({super.key, this.initialLessonId});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with TickerProviderStateMixin {
  int _currentSlide = 0;
  /// When null, show the story library. When set, show the slide viewer.
  String? _viewingLessonId;
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;
  late AnimationController _bgFadeController;
  late Animation<double> _bgFadeAnimation;

  @override
  void initState() {
    super.initState();
    _viewingLessonId = widget.initialLessonId;
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeInOut,
    );
    _bgFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bgFadeAnimation = CurvedAnimation(
      parent: _bgFadeController,
      curve: Curves.easeIn,
    );
    _textFadeController.forward();
    _bgFadeController.forward();
  }

  @override
  void dispose() {
    _textFadeController.dispose();
    _bgFadeController.dispose();
    super.dispose();
  }

  void _goToSlide(int index, int totalSlides) {
    if (index < 0 || index >= totalSlides) return;
    _textFadeController.reverse().then((_) {
      _bgFadeController.reset();
      setState(() => _currentSlide = index);
      _bgFadeController.forward();
      _textFadeController.forward();
    });
  }

  void _openStory(String lessonId) {
    _currentSlide = 0;
    _bgFadeController.reset();
    _textFadeController.reset();
    setState(() => _viewingLessonId = lessonId);
    _bgFadeController.forward();
    _textFadeController.forward();
  }

  void _backToLibrary() {
    setState(() => _viewingLessonId = null);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final langService = context.watch<LanguageService>();
    final t = langService.t;
    final lesson = appState.selectedLesson;
    final sz = MediaQuery.of(context).size;
    final sw = sz.width;
    final sh = sz.height;

    // Determine which lesson to show slides for:
    // 1. If navigated with an initialLessonId or tapped a küy in the grid → _viewingLessonId
    // 2. Otherwise → show the story library grid
    final activeLessonId = _viewingLessonId;

    if (activeLessonId != null) {
      return _buildSlideViewerLoader(
        context, t, langService, appState, activeLessonId, sw, sh,
      );
    }

    // No story to show → display the story library
    return _buildStoryLibrary(context, t, langService, appState, sw, sh);
  }
  // ── STORY LIBRARY GRID ─────────────────────────────────────
  Widget _buildStoryLibrary(
    BuildContext context,
    AppStrings t,
    LanguageService langService,
    AppState appState,
    double sw,
    double sh,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: appState.api.fetchStoriesPreviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: KColors.background,
            body: Center(
              child: CircularProgressIndicator(color: KColors.amber),
            ),
          );
        }

        final previews = snapshot.data ?? [];
        
        // Collect lessons that have story previews
        final storiesWithLessons = <Map<String, dynamic>>[];
        for (final preview in previews) {
          final kuiIdStr = preview['kui_id'].toString();
          final lesson = appState.lessons
              .cast<Lesson?>()
              .firstWhere((l) => l!.id == kuiIdStr, orElse: () => null);
          if (lesson != null) {
            storiesWithLessons.add({
              'lesson': lesson,
              'preview': preview,
            });
          }
        }

    return Scaffold(
      backgroundColor: KColors.background,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.04,
          vertical: sh * 0.05,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/library'),
                  child: Container(
                    padding: EdgeInsets.all(sh * 0.015),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(sh * 0.02),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        color: Colors.white70, size: sh * 0.035),
                  ),
                ),
                SizedBox(width: sw * 0.015),
                Icon(Icons.auto_stories_rounded,
                    color: KColors.amber, size: sh * 0.05),
                SizedBox(width: sw * 0.01),
                Text(
                  langService.lang == 'kz'
                      ? 'Күй аңыздары'
                      : langService.lang == 'ru'
                          ? 'Легенды күев'
                          : 'Küy Stories',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: sh * 0.055,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: sw * 0.01,
                    vertical: sh * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: KColors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(sh * 0.015),
                    border: Border.all(
                      color: KColors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${storiesWithLessons.length} ${langService.lang == 'kz' ? 'аңыз' : langService.lang == 'ru' ? 'историй' : 'stories'}',
                    style: TextStyle(
                      fontSize: sh * 0.025,
                      color: KColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: sh * 0.04),

            // Story cards grid
            Expanded(
              child: storiesWithLessons.isEmpty
                  ? Center(
                      child: Text(
                        langService.lang == 'kz'
                            ? 'Аңыздар жоқ'
                            : langService.lang == 'ru'
                                ? 'Истории не найдены'
                                : 'No stories available',
                        style: TextStyle(
                            color: Colors.white38, fontSize: sh * 0.03),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: storiesWithLessons.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: sw * 0.025),
                      itemBuilder: (context, index) {
                        final data = storiesWithLessons[index];
                        return _buildStoryCard(
                          context, t, langService, data['lesson'], data['preview'],
                          sw, sh,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    },
    );
  }

  Widget _buildSlideViewerLoader(
    BuildContext context,
    AppStrings t,
    LanguageService langService,
    AppState appState,
    String activeLessonId,
    double sw,
    double sh,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: appState.api.fetchKuiStory(activeLessonId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
             backgroundColor: KColors.background,
             body: Center(child: CircularProgressIndicator(color: KColors.amber)),
           );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
           return Scaffold(
             backgroundColor: KColors.background,
             body: Center(child: Text("Story not found", style: TextStyle(color: Colors.white))),
           );
        }
        
        final slidesData = snapshot.data!;
        final story = KuiStory(
          lessonId: activeLessonId,
          slides: slidesData.map((s) => StorySlide.fromJson(s)).toList(),
        );

        final lessonData = appState.lessons
            .cast<Lesson?>()
            .firstWhere((l) => l?.id == activeLessonId, orElse: () => null);
        final displayTitle = lessonData != null
            ? t.lessonTitle(lessonData.id, lessonData.title)
            : activeLessonId;
            
        return _buildSlideViewer(
          context, t, langService, story, displayTitle, sw, sh,
          showBackToLibrary: _viewingLessonId != null,
        );
      }
    );
  }

  // ── STORY CARD ────────────────────────────────────────────
  Widget _buildStoryCard(
    BuildContext context,
    AppStrings t,
    LanguageService langService,
    Lesson lesson,
    Map<String, dynamic> preview,
    double sw,
    double sh,
  ) {
    final cardWidth = sw * 0.28;
    final String imageUrl = preview['first_slide_image'] ?? '';
    final String previewText = preview['first_slide_text'] ?? '';
    final int slideCount = preview['slide_count'] ?? 0;

    return GestureDetector(
      onTap: () => _openStory(lesson.id),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(sh * 0.03),
          border: Border.all(
            color: KColors.amber.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: sh * 0.03,
              offset: Offset(0, sh * 0.01),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(sh * 0.03),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1A1C23),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: KColors.amber.withOpacity(0.5),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A1C23),
                  child: Icon(Icons.image_not_supported_rounded,
                      color: Colors.white24, size: sh * 0.06),
                ),
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // Slide count badge
              Positioned(
                top: sh * 0.02,
                right: sw * 0.01,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: sw * 0.008,
                    vertical: sh * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(sh * 0.01),
                    border: Border.all(
                      color: KColors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_rounded,
                          color: KColors.amber, size: sh * 0.02),
                      SizedBox(width: sw * 0.004),
                      Text(
                        '$slideCount',
                        style: TextStyle(
                          color: KColors.amber,
                          fontSize: sh * 0.018,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title + preview text at bottom
              Positioned(
                left: sw * 0.012,
                right: sw * 0.012,
                bottom: sh * 0.025,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Composer
                    Text(
                      lesson.composer,
                      style: TextStyle(
                        fontSize: sh * 0.018,
                        color: KColors.amber.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sh * 0.005),
                    // Title
                    Text(
                      t.lessonTitle(lesson.id, lesson.title),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: sh * 0.035,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sh * 0.01),
                    // Preview text
                    Text(
                      previewText,
                      style: TextStyle(
                        fontSize: sh * 0.02,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sh * 0.015),
                    // Read button
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: sw * 0.012,
                        vertical: sh * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: KColors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(sh * 0.012),
                        border: Border.all(
                          color: KColors.amber.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              color: KColors.amber, size: sh * 0.022),
                          SizedBox(width: sw * 0.005),
                          Text(
                            langService.lang == 'kz'
                                ? 'Оқу'
                                : langService.lang == 'ru'
                                    ? 'Читать'
                                    : 'Read',
                            style: TextStyle(
                              fontSize: sh * 0.02,
                              color: KColors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SLIDE VIEWER (existing visual novel) ──────────────────
  Widget _buildSlideViewer(
    BuildContext context,
    AppStrings t,
    LanguageService langService,
    KuiStory story,
    String displayTitle,
    double sw,
    double sh, {
    bool showBackToLibrary = false,
  }) {
    final slides = story.slides;
    final currentSlideData = slides[_currentSlide];
    final slideText = currentSlideData.text(langService.lang);
    final isLastSlide = _currentSlide == slides.length - 1;
    final isFirstSlide = _currentSlide == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap right half to go next, left half to go back
        onTapUp: (details) {
          final dx = details.globalPosition.dx;
          if (dx > sw * 0.5) {
            if (isLastSlide) return;
            _goToSlide(_currentSlide + 1, slides.length);
          } else {
            if (isFirstSlide) return;
            _goToSlide(_currentSlide - 1, slides.length);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen background image ──
            FadeTransition(
              opacity: _bgFadeAnimation,
              child: CachedNetworkImage(
                key: ValueKey(currentSlideData.imageUrl),
                imageUrl: currentSlideData.imageUrl,
                fit: BoxFit.cover,
                width: sw,
                height: sh,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF0D0E12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: KColors.amber.withOpacity(0.5),
                      strokeWidth: sh * 0.005,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF0D0E12),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      color: Colors.white24,
                      size: sh * 0.1,
                    ),
                  ),
                ),
              ),
            ),

            // ── Dark gradient overlay (bottom) ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // ── Top-left: Title badge ──
            Positioned(
              top: sh * 0.04,
              left: sw * 0.02,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sw * 0.015,
                  vertical: sh * 0.012,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(sh * 0.02),
                  border: Border.all(
                    color: KColors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_rounded,
                        color: KColors.amber, size: sh * 0.03),
                    SizedBox(width: sw * 0.006),
                    Text(
                      'KUISHIM',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: sh * 0.022,
                        fontWeight: FontWeight.bold,
                        color: KColors.amber,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Top-right: Back button ──
            Positioned(
              top: sh * 0.04,
              right: sw * 0.02,
              child: GestureDetector(
                onTap: showBackToLibrary
                    ? _backToLibrary
                    : () => context.go('/library'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: sw * 0.012,
                    vertical: sh * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(sh * 0.02),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white70, size: sh * 0.035),
                ),
              ),
            ),

            // ── Bottom: Dialog box with text ──
            Positioned(
              left: sw * 0.04,
              right: sw * 0.04,
              bottom: sh * 0.04,
              child: FadeTransition(
                opacity: _textFadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text dialog box
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(sh * 0.03),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1C23).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(sh * 0.03),
                        border: Border.all(
                          color: KColors.amber.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: sh * 0.04,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Küy title in dialog
                          Row(
                            children: [
                              SizedBox(width: sw * 0.008),
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: sh * 0.028,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    color: KColors.amber,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Slide counter
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: sw * 0.008,
                                  vertical: sh * 0.006,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(sh * 0.012),
                                ),
                                child: Text(
                                  '${_currentSlide + 1}/${slides.length}',
                                  style: TextStyle(
                                    fontSize: sh * 0.018,
                                    color: Colors.white.withOpacity(0.5),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: sh * 0.015),

                          // Divider
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  KColors.amber.withOpacity(0.3),
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: sh * 0.015),

                          // Story text
                          Text(
                            slideText,
                            style: GoogleFonts.inter(
                              fontSize: sh * 0.028,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.6,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: sh * 0.015),

                    // Navigation + dot indicators + action button
                    Row(
                      children: [
                        // Previous button
                        _SlideNavButton(
                          icon: Icons.chevron_left_rounded,
                          enabled: !isFirstSlide,
                          sh: sh,
                          sw: sw,
                          onTap: () =>
                              _goToSlide(_currentSlide - 1, slides.length),
                        ),

                        SizedBox(width: sw * 0.01),

                        // Dot indicators
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(slides.length, (idx) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.symmetric(
                                    horizontal: sw * 0.003),
                                width: _currentSlide == idx
                                    ? sw * 0.02
                                    : sw * 0.008,
                                height: sh * 0.01,
                                decoration: BoxDecoration(
                                  color: _currentSlide == idx
                                      ? KColors.amber
                                      : Colors.white.withOpacity(0.25),
                                  borderRadius:
                                      BorderRadius.circular(sh * 0.008),
                                ),
                              );
                            }),
                          ),
                        ),

                        SizedBox(width: sw * 0.01),

                        // Next / Start Training button
                        if (isLastSlide)
                          _StartTrainingButton(
                            label: t.startTraining,
                            sh: sh,
                            sw: sw,
                            onTap: () => context.go('/game'),
                          )
                        else
                          _SlideNavButton(
                            icon: Icons.chevron_right_rounded,
                            enabled: true,
                            sh: sh,
                            sw: sw,
                            onTap: () =>
                                _goToSlide(_currentSlide + 1, slides.length),
                          ),
                      ],
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
}

/// ─── REUSABLE: Slide navigation arrow button ───────────────
class _SlideNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final double sh;
  final double sw;
  final VoidCallback onTap;

  const _SlideNavButton({
    required this.icon,
    required this.enabled,
    required this.sh,
    required this.sw,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(sh * 0.015),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(sh * 0.02),
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white70 : Colors.white24,
          size: sh * 0.035,
        ),
      ),
    );
  }
}

/// ─── REUSABLE: Start Training button (appears on last slide) ──
class _StartTrainingButton extends StatelessWidget {
  final String label;
  final double sh;
  final double sw;
  final VoidCallback onTap;

  const _StartTrainingButton({
    required this.label,
    required this.sh,
    required this.sw,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.02,
          vertical: sh * 0.018,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [KColors.emerald, KColors.emeraldDark],
          ),
          borderRadius: BorderRadius.circular(sh * 0.025),
          boxShadow: [
            BoxShadow(
              color: KColors.emerald.withOpacity(0.3),
              blurRadius: sh * 0.03,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: sh * 0.03),
            SizedBox(width: sw * 0.005),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: sh * 0.022,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
