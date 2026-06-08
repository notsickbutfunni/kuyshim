import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // for KColors
import '../constants/learn_path_data.dart';
import '../models/lesson_model.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';

// Global state for passing the custom learn node into GameScreen
class LearnPathState {
  static LearnNode? currentNode;
  static int currentIndex = 0;
  static void Function(bool success)? onNodeCompleted;
}

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _highestUnlockedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initProgress();
  }

  Future<void> _initProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _highestUnlockedIndex = prefs.getInt('learn_path_progress') ?? 0;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProgress(int newIndex) async {
    if (newIndex > _highestUnlockedIndex) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('learn_path_progress', newIndex);
      setState(() {
        _highestUnlockedIndex = newIndex;
      });
    }
  }

  void _startNode(int index, LearnNode node, dynamic t) async {
    LearnPathState.currentNode = node;
    LearnPathState.currentIndex = index;
    LearnPathState.onNodeCompleted = (bool success) {
      if (success) {
        _saveProgress(index + 1);
      }
    };

    // Video nodes open the video lesson screen
    if (node.type == NodeType.video) {
      if (mounted) {
        context.go('/video-lesson');
      }
      return;
    }

    final localizedTitle = t.learnNodeTitles[node.id] ?? node.title;
    final localizedDesc = t.learnNodeDescriptions[node.id] ?? node.description;

    final dummyLesson = Lesson(
      id: 'learn_path_${node.id}',
      title: localizedTitle,
      composer: t.learningPath,
      difficulty: 1,
      description: localizedDesc,
      level: 'beginner',
      image: 'https://picsum.photos/seed/${node.id}/400/400',
      jsonMapFile: 'learn_path', // Special flag
    );

    final appState = context.read<AppState>();
    await appState.selectLesson(dummyLesson, mode: 'training');

    if (mounted) {
      context.go('/game');
    }
  }

  /// Whether the screen is in landscape / wide mode (web, tablet landscape)
  bool _isLandscape(BoxConstraints c) => c.maxWidth > c.maxHeight;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: KColors.background,
        body: Center(child: CircularProgressIndicator(color: KColors.emerald)),
      );
    }

    final t = context.watch<LanguageService>().t;

    return Scaffold(
      backgroundColor: const Color(0xFF12141A),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLand = _isLandscape(constraints);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                _buildHeader(context, t, constraints, isLand),

                // ── Body ────────────────────────────────────────
                Expanded(
                  child: isLand
                      ? _buildLandscapeBody(t, constraints)
                      : _buildPortraitBody(t, constraints),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context, dynamic t, BoxConstraints c, bool isLand) {
    final short = math.min(c.maxWidth, c.maxHeight);
    final titleSize = (short * 0.045).clamp(18.0, 36.0);
    final iconSize = (short * 0.03).clamp(16.0, 28.0);
    final pad = (short * 0.025).clamp(8.0, 24.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: iconSize),
            onPressed: () => context.go('/library'),
          ),
          SizedBox(width: pad * 0.4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                t.learningPath,
                style: GoogleFonts.playfairDisplay(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
          // Progress badge
          if (!context.watch<AppState>().user.isGuest)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: pad * 0.6,
                vertical: pad * 0.4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars,
                      color: KColors.amber, size: iconSize * 0.9),
                  const SizedBox(width: 4),
                  Text(
                    '${((_highestUnlockedIndex / learnNodes.length) * 100).toInt()}${t.donePercentage}',
                    style: TextStyle(
                      fontSize: (short * 0.02).clamp(11.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── LANDSCAPE BODY (web / tablet) ──────────────────────────────
  Widget _buildLandscapeBody(dynamic t, BoxConstraints constraints) {
    final sw = constraints.maxWidth;
    final sh = constraints.maxHeight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.03,
        vertical: sh * 0.035,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _buildHorizontalPath(sw, sh, t),
      ),
    );
  }

  // ── PORTRAIT BODY (phone) ─────────────────────────────────────
  Widget _buildPortraitBody(dynamic t, BoxConstraints constraints) {
    final sw = constraints.maxWidth;

    // Build a flat list of items: module headers, connectors, cards
    final items = _buildVerticalItems(t);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.05,
        vertical: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }

  // ── Horizontal path elements (landscape) ──────────────────────
  List<Widget> _buildHorizontalPath(double sw, double sh, dynamic t) {
    final elements = <Widget>[];
    // Adaptive card sizing for landscape
    final cardW = (sw * 0.2).clamp(160.0, 320.0);
    final cardH = (sh * 0.72).clamp(220.0, 480.0);
    final modW = (sw * 0.14).clamp(110.0, 240.0);
    final connW = (sw * 0.03).clamp(24.0, 60.0);
    final scale = (math.min(sw, sh) / 500).clamp(0.6, 1.4);

    // MODULE 1
    elements.add(_buildLandscapeModuleHeader(
      index: 1,
      title: '${t.module} 1',
      subtitle: t.theBasics,
      description: t.masterFoundation,
      color: KColors.amber,
      width: modW,
      height: cardH,
      scale: scale,
    ));
    elements.add(_buildHorizConnector(0 <= _highestUnlockedIndex, connW, cardH, scale));

    // Nodes 0-7 (Module 1: 8 nodes including intro video)
    for (int i = 0; i < 8; i++) {
      if (i < learnNodes.length) {
        elements.add(_LearnNodeCard(
          node: learnNodes[i],
          index: i,
          isUnlocked: i <= _highestUnlockedIndex,
          isCompleted: i < _highestUnlockedIndex,
          onTap: () => i <= _highestUnlockedIndex
              ? _startNode(i, learnNodes[i], t)
              : null,
          cardWidth: cardW,
          cardHeight: cardH,
          scale: scale,
        ));
        if (i < 7) {
          elements.add(_buildHorizConnector(
              (i + 1) <= _highestUnlockedIndex, connW, cardH, scale));
        }
      }
    }

    elements.add(_buildHorizConnector(8 <= _highestUnlockedIndex, connW, cardH, scale));

    // MODULE 2
    elements.add(_buildLandscapeModuleHeader(
      index: 2,
      title: '${t.module} 2',
      subtitle: t.upstrokes,
      description: t.learnAlternatePicking,
      color: KColors.violet,
      width: modW,
      height: cardH,
      scale: scale,
    ));
    elements.add(_buildHorizConnector(8 <= _highestUnlockedIndex, connW, cardH, scale));

    // Nodes 8-9
    for (int i = 8; i < 10; i++) {
      if (i < learnNodes.length) {
        elements.add(_LearnNodeCard(
          node: learnNodes[i],
          index: i,
          isUnlocked: i <= _highestUnlockedIndex,
          isCompleted: i < _highestUnlockedIndex,
          onTap: () => i <= _highestUnlockedIndex
              ? _startNode(i, learnNodes[i], t)
              : null,
          cardWidth: cardW,
          cardHeight: cardH,
          scale: scale,
        ));
        if (i < 9) {
          elements.add(_buildHorizConnector(
              (i + 1) <= _highestUnlockedIndex, connW, cardH, scale));
        }
      }
    }

    return elements;
  }

  // ── Vertical list items (portrait phone) ──────────────────────
  List<Widget> _buildVerticalItems(dynamic t) {
    final items = <Widget>[];

    // MODULE 1 header
    items.add(_buildPortraitModuleHeader(
      index: 1,
      title: '${t.module} 1',
      subtitle: t.theBasics,
      description: t.masterFoundation,
      color: KColors.amber,
    ));
    items.add(_buildVertConnector(0 <= _highestUnlockedIndex));

    // Nodes 0-7 (8 nodes including intro video)
    for (int i = 0; i < 8; i++) {
      if (i < learnNodes.length) {
        items.add(_PortraitNodeCard(
          node: learnNodes[i],
          index: i,
          isUnlocked: i <= _highestUnlockedIndex,
          isCompleted: i < _highestUnlockedIndex,
          onTap: () => i <= _highestUnlockedIndex
              ? _startNode(i, learnNodes[i], t)
              : null,
        ));
        if (i < 7) {
          items.add(
              _buildVertConnector((i + 1) <= _highestUnlockedIndex));
        }
      }
    }

    items.add(_buildVertConnector(8 <= _highestUnlockedIndex));

    // MODULE 2 header
    items.add(_buildPortraitModuleHeader(
      index: 2,
      title: '${t.module} 2',
      subtitle: t.upstrokes,
      description: t.learnAlternatePicking,
      color: KColors.violet,
    ));
    items.add(_buildVertConnector(8 <= _highestUnlockedIndex));

    // Nodes 8-9
    for (int i = 8; i < 10; i++) {
      if (i < learnNodes.length) {
        items.add(_PortraitNodeCard(
          node: learnNodes[i],
          index: i,
          isUnlocked: i <= _highestUnlockedIndex,
          isCompleted: i < _highestUnlockedIndex,
          onTap: () => i <= _highestUnlockedIndex
              ? _startNode(i, learnNodes[i], t)
              : null,
        ));
        if (i < 9) {
          items.add(
              _buildVertConnector((i + 1) <= _highestUnlockedIndex));
        }
      }
    }

    // Bottom spacer
    items.add(const SizedBox(height: 32));

    return items;
  }

  // ── Landscape module header ────────────────────────────────────
  Widget _buildLandscapeModuleHeader({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required double width,
    required double height,
    required double scale,
  }) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 20 * scale,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48 * scale,
            height: 48 * scale,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$index',
                style: GoogleFonts.inter(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          SizedBox(height: 12 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 6 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            description,
            style: TextStyle(
              fontSize: 9 * scale,
              color: Colors.white.withOpacity(0.4),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Horizontal connector (landscape) ──────────────────────────
  Widget _buildHorizConnector(
      bool isActive, double width, double height, double scale) {
    final color =
        isActive ? KColors.emerald : Colors.white.withOpacity(0.08);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: KColors.emerald.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          Container(
            width: 18 * scale,
            height: 18 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFF12141A),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.chevron_right,
                size: 12 * scale,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Portrait module header ─────────────────────────────────────
  Widget _buildPortraitModuleHeader({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Number badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$index',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: color.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vertical connector (portrait) ─────────────────────────────
  Widget _buildVertConnector(bool isActive) {
    final color =
        isActive ? KColors.emerald : Colors.white.withOpacity(0.08);
    return SizedBox(
      height: 40,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: KColors.emerald.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF12141A),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 12,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LANDSCAPE NODE CARD
// ─────────────────────────────────────────────────────────────────────

class _LearnNodeCard extends StatefulWidget {
  final LearnNode node;
  final int index;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback onTap;
  final double cardWidth;
  final double cardHeight;
  final double scale;

  const _LearnNodeCard({
    required this.node,
    required this.index,
    required this.isUnlocked,
    required this.isCompleted,
    required this.onTap,
    required this.cardWidth,
    required this.cardHeight,
    required this.scale,
  });

  @override
  State<_LearnNodeCard> createState() => _LearnNodeCardState();
}

class _LearnNodeCardState extends State<_LearnNodeCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final node = widget.node;
    final isUnlocked = widget.isUnlocked;
    final isCompleted = widget.isCompleted;
    final isKui = node.type == NodeType.kui;
    final isVideo = node.type == NodeType.video;
    final isBoss = node.id == 'node_3_erkem_full';
    final accentColor = isVideo
        ? KColors.blue
        : (isBoss
            ? Colors.amber.shade400
            : (isKui ? KColors.emerald : KColors.amber));
    final nodeColor = isCompleted
        ? KColors.emerald
        : (isUnlocked ? accentColor : Colors.white.withOpacity(0.15));
    final s = widget.scale;
    final radius = 16.0 * s;
    final overlayPad = 8.0 * s;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: widget.cardWidth,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            color: isUnlocked
                ? KColors.surface.withOpacity(_isHovering ? 0.95 : 0.85)
                : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: _isHovering
                  ? nodeColor.withOpacity(0.6)
                  : nodeColor.withOpacity(isUnlocked ? 0.25 : 0.08),
              width: _isHovering ? 2.5 : 1.5,
            ),
            boxShadow: _isHovering && isUnlocked
                ? [
                    BoxShadow(
                      color: nodeColor.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 1,
                    )
                  ]
                : isUnlocked
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                        )
                      ]
                    : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Image / Icon Area
                Expanded(
                  flex: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isVideo
                                ? [
                                    const Color(0xFF1E40AF).withOpacity(0.8),
                                    const Color(0xFF1E3A5F).withOpacity(0.6),
                                  ]
                                : (isBoss
                                ? [
                                    Colors.amber.shade700.withOpacity(0.8),
                                    Colors.amber.shade900.withOpacity(0.6),
                                  ]
                                : (isKui
                                    ? [
                                        const Color(0xFF0F766E).withOpacity(0.8),
                                        const Color(0xFF115E59).withOpacity(0.6),
                                      ]
                                    : [
                                        const Color(0xFFB45309).withOpacity(0.8),
                                        const Color(0xFF92400E).withOpacity(0.6),
                                      ])),
                          ),
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: isUnlocked ? 0.25 : 0.08,
                            child: Icon(
                              isVideo
                                  ? Icons.play_circle_fill_rounded
                                  : (isBoss
                                      ? Icons.workspace_premium_rounded
                                      : (isKui
                                          ? Icons.music_note_rounded
                                          : Icons.school_rounded)),
                              size: 64 * s,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Pattern overlay
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.15,
                          child: CustomPaint(
                            painter: _CardPatternPainter(accentColor),
                          ),
                        ),
                      ),
                      // Gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 40 * s,
                        child: Container(
                          decoration: const BoxDecoration(
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
                      // Lock Overlay
                      if (!isUnlocked)
                        Container(
                          color: Colors.black.withOpacity(0.55),
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.all(12 * s),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.15)),
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 24 * s,
                              ),
                            ),
                          ),
                        ),
                      // Tag
                      Positioned(
                        top: overlayPad,
                        left: overlayPad,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * s,
                            vertical: 3 * s,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8 * s),
                            border: Border.all(
                                color: accentColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            isVideo ? t.videoTag : (isKui ? t.songTag : t.skillTag),
                            style: GoogleFonts.inter(
                              fontSize: (8 * s).clamp(7.0, 13.0),
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      // Checkmark
                      if (isCompleted)
                        Positioned(
                          top: overlayPad,
                          right: overlayPad,
                          child: Container(
                            padding: EdgeInsets.all(4 * s),
                            decoration: const BoxDecoration(
                              color: KColors.emerald,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: KColors.emerald, blurRadius: 8)
                              ],
                            ),
                            child: Icon(Icons.check,
                                color: Colors.white, size: 12 * s),
                          ),
                        ),
                    ],
                  ),
                ),
                // 2. Info + Button
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.all(12 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text — shrinks if needed
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isVideo
                                    ? t.videoIntroTitle
                                    : (t.learnNodeTitles[node.id] ?? node.title),
                                style: GoogleFonts.inter(
                                  fontSize: (14 * s).clamp(11.0, 20.0),
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4 * s),
                              Flexible(
                                child: Text(
                                  isVideo
                                      ? t.videoIntroDescription
                                      : (t.learnNodeDescriptions[node.id] ??
                                          node.description),
                                  style: TextStyle(
                                    fontSize: (10 * s).clamp(9.0, 15.0),
                                    color: isUnlocked
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.2),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Button — fixed at bottom, compact layout
                        SizedBox(
                          width: double.infinity,
                          height: (34 * s).clamp(34.0, 52.0),
                          child: ElevatedButton(
                            onPressed: isUnlocked ? widget.onTap : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted
                                  ? Colors.white.withOpacity(0.08)
                                  : (isUnlocked
                                      ? accentColor
                                      : Colors.white.withOpacity(0.03)),
                              foregroundColor: isCompleted
                                  ? Colors.white
                                  : (isUnlocked
                                      ? ((isKui || isVideo)
                                          ? Colors.white
                                          : Colors.black)
                                      : Colors.white.withOpacity(0.2)),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: 6 * s,
                                vertical: 0,
                              ),
                              side: isCompleted
                                  ? BorderSide(
                                      color: Colors.white.withOpacity(0.15))
                                  : BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10 * s),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isVideo
                                        ? (isCompleted ? Icons.replay_rounded : Icons.play_circle_outline_rounded)
                                        : (isCompleted
                                            ? Icons.replay_rounded
                                            : (isUnlocked
                                                ? Icons.play_arrow_rounded
                                                : Icons.lock_outline_rounded)),
                                    size: (14 * s).clamp(14.0, 20.0),
                                  ),
                                  SizedBox(width: 4 * s),
                                  Text(
                                    isVideo
                                        ? (isCompleted ? t.practiceAgain : t.watchVideo)
                                        : (isCompleted
                                            ? t.practiceAgain
                                            : (isUnlocked
                                                ? t.startPractice
                                                : t.locked)),
                                    style: GoogleFonts.inter(
                                      fontSize: (11 * s).clamp(11.0, 16.0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
}

// ─────────────────────────────────────────────────────────────────────
// PORTRAIT NODE CARD (vertical layout for phones)
// ─────────────────────────────────────────────────────────────────────

class _PortraitNodeCard extends StatelessWidget {
  final LearnNode node;
  final int index;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback onTap;

  const _PortraitNodeCard({
    required this.node,
    required this.index,
    required this.isUnlocked,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final isKui = node.type == NodeType.kui;
    final isVideo = node.type == NodeType.video;
    final isBoss = node.id == 'node_3_erkem_full';
    final accentColor = isVideo
        ? KColors.blue
        : (isBoss
            ? Colors.amber.shade400
            : (isKui ? KColors.emerald : KColors.amber));
    final nodeColor = isCompleted
        ? KColors.emerald
        : (isUnlocked ? accentColor : Colors.white.withOpacity(0.15));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isUnlocked
              ? KColors.surface.withOpacity(0.85)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: nodeColor.withOpacity(isUnlocked ? 0.25 : 0.08),
            width: 1.5,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image area
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isVideo
                              ? [
                                  const Color(0xFF1E40AF).withOpacity(0.8),
                                  const Color(0xFF1E3A5F).withOpacity(0.6),
                                ]
                              : (isBoss
                              ? [
                                  Colors.amber.shade700.withOpacity(0.8),
                                  Colors.amber.shade900.withOpacity(0.6),
                                ]
                              : (isKui
                                  ? [
                                      const Color(0xFF0F766E).withOpacity(0.8),
                                      const Color(0xFF115E59).withOpacity(0.6),
                                    ]
                                  : [
                                      const Color(0xFFB45309).withOpacity(0.8),
                                      const Color(0xFF92400E).withOpacity(0.6),
                                    ])),
                        ),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: isUnlocked ? 0.25 : 0.08,
                          child: Icon(
                            isVideo
                                ? Icons.play_circle_fill_rounded
                                : (isBoss
                                    ? Icons.workspace_premium_rounded
                                    : (isKui
                                        ? Icons.music_note_rounded
                                        : Icons.school_rounded)),
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.15,
                        child: CustomPaint(
                          painter: _CardPatternPainter(accentColor),
                        ),
                      ),
                    ),
                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(
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
                    if (!isUnlocked)
                      Container(
                        color: Colors.black.withOpacity(0.55),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white.withOpacity(0.4),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    // Tag
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: accentColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          isVideo ? t.videoTag : (isKui ? t.songTag : t.skillTag),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    // Checkmark
                    if (isCompleted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: KColors.emerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: KColors.emerald, blurRadius: 8)
                            ],
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
              // Info + button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVideo
                          ? t.videoIntroTitle
                          : (t.learnNodeTitles[node.id] ?? node.title),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Fixed height for 2-line description consistency
                    SizedBox(
                      height: 38, // 13 * 1.4 * 2 ≈ 36.4, rounded up
                      child: Text(
                        isVideo
                            ? t.videoIntroDescription
                            : (t.learnNodeDescriptions[node.id] ?? node.description),
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnlocked
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: isUnlocked ? onTap : null,
                        icon: Icon(
                          isVideo
                              ? (isCompleted ? Icons.replay_rounded : Icons.play_circle_outline_rounded)
                              : (isCompleted
                                  ? Icons.replay_rounded
                                  : (isUnlocked
                                      ? Icons.play_arrow_rounded
                                      : Icons.lock_outline_rounded)),
                          size: 18,
                        ),
                        label: Text(
                          isVideo
                              ? (isCompleted ? t.practiceAgain : t.watchVideo)
                              : (isCompleted
                                  ? t.practiceAgain
                                  : (isUnlocked ? t.startPractice : t.locked)),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted
                              ? Colors.white.withOpacity(0.08)
                              : (isUnlocked
                                  ? accentColor
                                  : Colors.white.withOpacity(0.03)),
                          foregroundColor: isCompleted
                              ? Colors.white
                              : (isUnlocked
                                  ? ((isKui || isVideo) ? Colors.white : Colors.black)
                                  : Colors.white.withOpacity(0.2)),
                          elevation: 0,
                          side: isCompleted
                              ? BorderSide(
                                  color: Colors.white.withOpacity(0.15))
                              : BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
}

// ─────────────────────────────────────────────────────────────────────
// PATTERN PAINTER (shared)
// ─────────────────────────────────────────────────────────────────────

class _CardPatternPainter extends CustomPainter {
  final Color color;
  _CardPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double i = -size.width; i < size.width; i += 30) {
      path.moveTo(i, 0);
      path.lineTo(i + size.height, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
