/// ResultsScreen — Post-game performance summary.
/// Mirrors ResultsScreen.tsx from the React app.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final appState = context.watch<AppState>();
    final result = appState.lastResult;
    final user = appState.user;
    final screenSize = MediaQuery.of(context).size;

    if (result == null) {
      return Scaffold(
        backgroundColor: KColors.background,
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/library'),
            child: Text(t.menu),
          ),
        ),
      );
    }

    final rankColor = result.rank == 'S'
        ? KColors.yellow
        : result.rank == 'A'
            ? KColors.emerald
            : result.rank == 'B'
                ? KColors.blue
                : Colors.white60;

    return Scaffold(
      backgroundColor: KColors.background,
      body: Row(
        children: [
          // ── Left Side: Hero Stats ─────────────────────────
          SizedBox(
            width: screenSize.width * 0.45,
            child: Stack(
              children: [
                // Background glow
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          KColors.emerald.withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Border
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),

                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.performanceRank.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 3,
                            fontFamily: 'monospace',
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Big rank letter
                        Text(
                          result.rank,
                          style: GoogleFonts.inter(
                            fontSize: screenSize.height * 0.35,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: rankColor,
                            height: 1,
                          ),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              delay: 500.ms,
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),

                        const SizedBox(height: 16),

                        // Score
                        Text(
                          result.score.toString(),
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        Text(
                          t.finalScore.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Right Side: Breakdown & Actions ───────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.04,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.lessonTitle} — ${t.analysis}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: t.perfect,
                          value: '${result.perfect}',
                          color: KColors.yellow,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: t.good,
                          value: '${result.good}',
                          color: KColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: t.miss,
                          value: '${result.miss}',
                          color: KColors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Smart Suggestion
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: KColors.emerald
                                    .withOpacity(0.2),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: KColors.emerald,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              t.smartSuggestion.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white
                                    .withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"${result.suggestion}"',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color:
                                Colors.white.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Guest save prompt
                  if (user.isGuest)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: KColors.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              KColors.emerald.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KColors.emerald
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add,
                              size: 20,
                              color: KColors.emerald,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.saveProgress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  t.saveProgressDesc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white
                                        .withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                context.go('/onboarding'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KColors.emerald,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              t.createAccount,
                              style:
                                  const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/library'),
                      icon: const Icon(Icons.arrow_forward,
                          size: 20),
                      label: Text(t.nextLesson),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/game'),
                          icon: const Icon(Icons.refresh,
                              size: 18),
                          label: Text(t.restart),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go('/library'),
                          icon:
                              const Icon(Icons.menu, size: 18),
                          label: Text(t.menu),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Share functionality placeholder
                          },
                          icon:
                              const Icon(Icons.share, size: 18),
                          label: Text(t.share),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
