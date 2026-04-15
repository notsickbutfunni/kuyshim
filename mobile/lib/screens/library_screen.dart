/// LibraryScreen — Lesson browser with beginner/pro tabs.
/// Mirrors LibraryScreen.tsx from the React app.
/// All sizes are percentage-based via MediaQuery to prevent overflow.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../main.dart';
import '../models/lesson_model.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../widgets/lang_toggle.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeTab = 'beginner';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final appState = context.watch<AppState>();
    final user = appState.user;
    final lessons = appState.lessons;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final filteredLessons =
        lessons.where((l) => l.level == _activeTab).toList();
    final beginnerLessons =
        lessons.where((l) => l.level == 'beginner').toList();
    final proLessons = lessons.where((l) => l.level == 'pro').toList();
    final beginnerCompleted = beginnerLessons
        .where((l) => l.progressStatus == 'completed')
        .length;
    final proCompleted =
        proLessons.where((l) => l.progressStatus == 'completed').length;

    return Scaffold(
      backgroundColor: KColors.background,
      body: Row(
        children: [
          // ── Sidebar Navigation ────────────────────────────
          _SidebarNav(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),

          // ── Content ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.025,
                    screenHeight * 0.06,
                    screenWidth * 0.025,
                    screenHeight * 0.02,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.libraryTitle,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: screenHeight * 0.06,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Text(
                              user.isGuest
                                  ? t.guestAccess
                                  : '${t.welcomeBack}, ${user.username}',
                              style: TextStyle(
                                fontSize: screenHeight * 0.032,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const LangToggle(),
                      SizedBox(width: screenWidth * 0.012),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.015,
                          vertical: screenHeight * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(
                              screenHeight * 0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events,
                                size: screenHeight * 0.04,
                                color: KColors.yellow),
                            SizedBox(width: screenWidth * 0.006),
                            Text(
                              user.isGuest ? '0 XP' : '2,450 XP',
                              style: TextStyle(
                                fontSize: screenHeight * 0.032,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Level Tabs
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.025),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _LevelTab(
                          label: t.beginner,
                          icon: Icons.menu_book,
                          isActive: _activeTab == 'beginner',
                          count:
                              '$beginnerCompleted/${beginnerLessons.length}',
                          color: KColors.emerald,
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          onTap: () => setState(
                              () => _activeTab = 'beginner'),
                        ),
                        SizedBox(width: screenWidth * 0.012),
                        _LevelTab(
                          label: t.pro,
                          icon: Icons.auto_awesome,
                          isActive: _activeTab == 'pro',
                          count:
                              '$proCompleted/${proLessons.length}',
                          color: KColors.violet,
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          onTap: () =>
                              setState(() => _activeTab = 'pro'),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        // Stats
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: screenHeight * 0.03,
                                color: KColors.emerald
                                    .withOpacity(0.6)),
                            SizedBox(width: screenWidth * 0.005),
                            Text(
                              '${beginnerCompleted + proCompleted} ${t.completed.toLowerCase()}',
                              style: TextStyle(
                                fontSize: screenHeight * 0.028,
                                color:
                                    Colors.white.withOpacity(0.2),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.008),
                            Text('•',
                                style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(0.2))),
                            SizedBox(width: screenWidth * 0.008),
                            Text(
                              '${lessons.length} ${t.totalLessons}',
                              style: TextStyle(
                                fontSize: screenHeight * 0.028,
                                color:
                                    Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),

                // Lesson Cards — horizontal ListView
                Expanded(
                  child: filteredLessons.isEmpty
                      ? _buildEmptyState(t, screenWidth, screenHeight)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.025),
                          itemCount: filteredLessons.length,
                          itemBuilder: (context, index) {
                            final lesson = filteredLessons[index];
                            return _LessonCard(
                              lesson: lesson,
                              isLocked: user.isGuest &&
                                  lesson.requiresAuth,
                              isPro: _activeTab == 'pro',
                              t: t,
                              screenWidth: screenWidth,
                              screenHeight: screenHeight,
                              onTap: () async {
                                await appState
                                    .selectLesson(lesson);
                                if (context.mounted) {
                                  context.go('/game');
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      dynamic t, double screenWidth, double screenHeight) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FractionallySizedBox(
            widthFactor: 0.15,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius:
                      BorderRadius.circular(screenHeight * 0.06),
                ),
                child: Icon(Icons.music_note,
                    size: screenHeight * 0.08,
                    color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          Text(
            t.noLessonsFound,
            style: TextStyle(
              fontSize: screenHeight * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _activeTab == 'beginner' ? t.beginnerHint : t.proHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenHeight * 0.032,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar Navigation ──────────────────────────────────────────
class _SidebarNav extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const _SidebarNav({
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = screenWidth * 0.08;
    final btnSize = screenHeight * 0.12;
    final iconSize = screenHeight * 0.055;
    final logoSize = screenHeight * 0.12;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.06),
          // Logo
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: KColors.emerald,
              borderRadius: BorderRadius.circular(logoSize * 0.33),
              boxShadow: [
                BoxShadow(
                  color: KColors.emerald.withOpacity(0.2),
                  blurRadius: screenHeight * 0.03,
                ),
              ],
            ),
            child: Icon(Icons.music_note,
                color: Colors.white, size: iconSize),
          ),
          SizedBox(height: screenHeight * 0.06),

          // Nav buttons
          _NavButton(
            icon: Icons.play_arrow,
            isActive: true,
            btnSize: btnSize,
            iconSize: iconSize,
            onTap: () {},
          ),
          SizedBox(height: screenHeight * 0.04),
          _NavButton(
            icon: Icons.settings,
            isActive: false,
            btnSize: btnSize,
            iconSize: iconSize,
            onTap: () => context.go('/tuner'),
          ),
          SizedBox(height: screenHeight * 0.04),
          _NavButton(
            icon: Icons.person,
            isActive: false,
            btnSize: btnSize,
            iconSize: iconSize,
            onTap: () => context.go('/profile'),
          ),

          const Spacer(),
          Icon(Icons.bolt,
              color: KColors.yellow, size: iconSize * 0.85),
          SizedBox(height: screenHeight * 0.06),
        ],
      ),
    );
  }
}

// ── Sidebar Nav Button ──────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final double btnSize;
  final double iconSize;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.isActive,
    required this.btnSize,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(btnSize * 0.25),
        child: Container(
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(btnSize * 0.25),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: isActive
                ? Colors.white
                : Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

// ── Level Tab ───────────────────────────────────────────────
class _LevelTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final String count;
  final Color color;
  final double screenWidth;
  final double screenHeight;
  final VoidCallback onTap;

  const _LevelTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.count,
    required this.color,
    required this.screenWidth,
    required this.screenHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.02,
          vertical: screenHeight * 0.025,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(screenHeight * 0.04),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: screenHeight * 0.03,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: screenHeight * 0.045,
                color: isActive
                    ? color
                    : Colors.white.withOpacity(0.4)),
            SizedBox(width: screenWidth * 0.008),
            Text(
              label,
              style: TextStyle(
                fontSize: screenHeight * 0.032,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? color
                    : Colors.white.withOpacity(0.4),
              ),
            ),
            SizedBox(width: screenWidth * 0.008),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.008,
                vertical: screenHeight * 0.005,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(screenHeight * 0.025),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: screenHeight * 0.025,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? color.withOpacity(0.8)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lesson Card ─────────────────────────────────────────────
class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isLocked;
  final bool isPro;
  final dynamic t;
  final double screenWidth;
  final double screenHeight;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.isLocked,
    required this.isPro,
    required this.t,
    required this.screenWidth,
    required this.screenHeight,
    required this.onTap,
  });

  Widget _getStatusBadge() {
    final badgePaddingH = screenWidth * 0.01;
    final badgePaddingV = screenHeight * 0.01;
    final badgeFontSize = screenHeight * 0.025;
    final badgeIconSize = screenHeight * 0.03;
    final badgeRadius = screenHeight * 0.03;

    if (lesson.progressStatus == 'completed') {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: badgePaddingH, vertical: badgePaddingV),
        decoration: BoxDecoration(
          color: KColors.emerald.withOpacity(0.15),
          borderRadius: BorderRadius.circular(badgeRadius),
          border:
              Border.all(color: KColors.emerald.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                size: badgeIconSize, color: KColors.emerald),
            SizedBox(width: screenWidth * 0.004),
            Text(t.completed,
                style: TextStyle(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w600,
                    color: KColors.emerald)),
          ],
        ),
      );
    }
    if (lesson.progressStatus == 'started') {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: badgePaddingH, vertical: badgePaddingV),
        decoration: BoxDecoration(
          color: KColors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(badgeRadius),
          border: Border.all(color: KColors.amber.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time,
                size: badgeIconSize, color: KColors.amber),
            SizedBox(width: screenWidth * 0.004),
            Text(t.inProgress,
                style: TextStyle(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w600,
                    color: KColors.amber)),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: badgePaddingH, vertical: badgePaddingV),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(badgeRadius),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(t.newLabel,
          style: TextStyle(
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.3))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isPro ? KColors.violet : KColors.emerald;
    final cardWidth = screenWidth * 0.35;
    final cardRadius = screenHeight * 0.06;
    final overlayPad = screenHeight * 0.02;
    final labelFontSize = screenHeight * 0.02;
    final titleFontSize = screenHeight * 0.035;
    final composerFontSize = screenHeight * 0.02;
    final descFontSize = screenHeight * 0.022;
    final noteDotSize = screenHeight * 0.022;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(
          right: screenWidth * 0.02,
          top: screenHeight * 0.01,
          bottom: screenHeight * 0.02,
        ),
        decoration: BoxDecoration(
          color: KColors.surface,
          borderRadius: BorderRadius.circular(cardRadius),
          border:
              Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              Expanded(
                flex: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(cardRadius)),
                      child: lesson.localImageAsset != null
                          ? Image.asset(
                              lesson.localImageAsset!,
                              fit: BoxFit.cover,
                            )
                          : CachedNetworkImage(
                              imageUrl: lesson.image,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  color: Colors.white
                                      .withOpacity(0.05)),
                              errorWidget: (_, __, ___) =>
                                  Container(
                                color: Colors.white
                                    .withOpacity(0.05),
                                child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white24),
                              ),
                            ),
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: screenHeight * 0.1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              KColors.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Lock overlay
                    if (isLocked)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(cardRadius)),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.all(
                                screenHeight * 0.03),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      screenHeight * 0.05),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.2)),
                            ),
                            child: Icon(Icons.lock,
                                color: Colors.white,
                                size: screenHeight * 0.06),
                          ),
                        ),
                      ),
                    // Cloud/Download indicator for remote lessons
                    if (lesson.isRemote &&
                        lesson.audioFile != null)
                      Positioned(
                        top: overlayPad,
                        right: overlayPad,
                        child: FutureBuilder<bool>(
                          future: Provider.of<AppState>(context,
                                  listen: false)
                              .levelManager
                              .isCached(lesson.audioFile!),
                          builder: (context, snapshot) {
                            final isCached =
                                snapshot.data ?? false;
                            if (isCached) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: EdgeInsets.all(
                                  screenHeight * 0.015),
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  Icons.cloud_download,
                                  size: screenHeight * 0.04,
                                  color: Colors.white70),
                            );
                          },
                        ),
                      ),
                    // Level badge
                    Positioned(
                      top: overlayPad,
                      left: overlayPad,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.008,
                          vertical: screenHeight * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color:
                              accentColor.withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(
                                  screenHeight * 0.025),
                          border: Border.all(
                              color: accentColor
                                  .withOpacity(0.3)),
                        ),
                        child: Text(
                          isPro
                              ? '⚡ ${t.pro}'
                              : '🎵 ${t.beginner}',
                          style: TextStyle(
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.bold,
                            color: accentColor
                                .withOpacity(0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    // Difficulty dots
                    if (!lesson.isRemote ||
                        lesson.audioFile == null)
                      Positioned(
                        top: overlayPad,
                        right: overlayPad,
                        child: Row(
                          children: List.generate(5, (i) {
                            return Padding(
                              padding: EdgeInsets.only(
                                  left:
                                      screenWidth * 0.002),
                              child: Icon(
                                Icons.music_note,
                                size: noteDotSize,
                                color: i < lesson.difficulty
                                    ? accentColor
                                    : Colors.white
                                        .withOpacity(0.2),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),

              // Text content
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.012,
                    screenHeight * 0.015,
                    screenWidth * 0.012,
                    screenHeight * 0.015,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics:
                            const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lesson.composer,
                                          style: TextStyle(
                                            fontSize:
                                                composerFontSize,
                                            fontFamily:
                                                'monospace',
                                            color: Colors
                                                .white
                                                .withOpacity(
                                                    0.3),
                                            letterSpacing:
                                                1.2,
                                          ),
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),
                                      ),
                                      _getStatusBadge(),
                                    ],
                                  ),
                                  SizedBox(
                                      height:
                                          screenHeight *
                                              0.01),
                                  Text(
                                    lesson.title,
                                    style: TextStyle(
                                      fontSize:
                                          titleFontSize,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                  ),
                                  if (lesson.description !=
                                          null &&
                                      constraints
                                              .maxHeight >
                                          screenHeight *
                                              0.25) ...[
                                    SizedBox(
                                        height:
                                            screenHeight *
                                                0.005),
                                    Text(
                                      lesson
                                          .description!,
                                      style: TextStyle(
                                        fontSize:
                                            descFontSize,
                                        color: Colors
                                            .white
                                            .withOpacity(
                                                0.3),
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(
                                  height:
                                      screenHeight *
                                          0.015),
                              // Action button
                              SizedBox(
                                width: double.infinity,
                                child:
                                    ElevatedButton.icon(
                                  onPressed: isLocked
                                      ? null
                                      : onTap,
                                  icon: isLocked
                                      ? const SizedBox
                                          .shrink()
                                      : Icon(
                                          Icons
                                              .play_arrow,
                                          size:
                                              screenHeight *
                                                  0.025,
                                          color: isPro
                                              ? Colors
                                                  .white
                                              : Colors
                                                  .black,
                                        ),
                                  label: Text(
                                    isLocked
                                        ? t.signInToPlay
                                        : lesson.progressStatus ==
                                                'completed'
                                            ? t.practiceAgain
                                            : lesson.progressStatus ==
                                                    'started'
                                                ? t.continueLabel
                                                : t.startPractice,
                                    style: TextStyle(
                                        fontSize:
                                            screenHeight *
                                                0.022),
                                  ),
                                  style: ElevatedButton
                                      .styleFrom(
                                    backgroundColor:
                                        isLocked
                                            ? Colors
                                                .white
                                                .withOpacity(
                                                    0.05)
                                            : isPro
                                                ? KColors
                                                    .violet
                                                : Colors
                                                    .white,
                                    foregroundColor:
                                        isLocked
                                            ? Colors
                                                .white
                                                .withOpacity(
                                                    0.2)
                                            : isPro
                                                ? Colors
                                                    .white
                                                : Colors
                                                    .black,
                                    padding: EdgeInsets
                                        .symmetric(
                                      vertical:
                                          screenHeight *
                                              0.015,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  screenHeight *
                                                      0.025),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
