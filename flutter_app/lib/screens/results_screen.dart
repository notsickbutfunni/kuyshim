import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final t = provider.t;
    final result = provider.lastResult!;
    final user = provider.user;
    final size = MediaQuery.of(context).size;

    Color rankColor;
    switch (result.rank) {
      case 'S':
        rankColor = Colors.yellow[400]!;
        break;
      case 'A':
        rankColor = AppColors.emerald;
        break;
      case 'B':
        rankColor = Colors.blue[400]!;
        break;
      default:
        rankColor = Colors.white.withValues(alpha: 0.6);
    }

    return Scaffold(
      body: Row(
        children: [
          // Left — Hero Rank
          SizedBox(
            width: size.width * 0.4,
            child: Stack(
              children: [
                // Glow
                Center(
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emerald.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.performanceRank,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                letterSpacing: 4,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 16),
                        Text(
                          result.rank,
                          style: TextStyle(
                            fontSize: 140,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -8,
                            color: rankColor,
                            shadows: [
                              Shadow(
                                color: rankColor.withValues(alpha: 0.3),
                                blurRadius: 50,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          result.score.toString(),
                          style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2),
                        ),
                        Text(t.finalScore,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                letterSpacing: 3,
                                fontFamily: 'monospace')),

                        // ML Score badge (if available)
                        if (result.hasMLData && result.mlFinalScore != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.emerald.withValues(alpha: 0.2),
                                  Colors.cyan.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color:
                                      AppColors.emerald.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 16, color: AppColors.emerald),
                                const SizedBox(width: 8),
                                Text(
                                  '${t.aiPowered}: ${result.mlFinalScore!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emerald),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Score saved indicator
                        if (result.performanceId != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_done,
                                  size: 14,
                                  color:
                                      Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(width: 6),
                              Text(t.scoreSaved,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white
                                          .withValues(alpha: 0.3))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right — Breakdown
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${result.lessonTitle} — ${t.analysis}',
                      style: serifBold(24)),
                  const SizedBox(height: 32),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                              label: t.perfect,
                              value: '${result.perfect}',
                              color: Colors.yellow[400]!)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: t.good,
                              value: '${result.good}',
                              color: AppColors.emerald)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: t.miss,
                              value: '${result.miss}',
                              color: Colors.red[400]!)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── AI Analysis Section ────────────────────────
                  if (result.hasMLData) ...[
                    _AiAnalysisCard(result: result, t: t),
                    const SizedBox(height: 24),
                  ],

                  // Suggestion
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  size: 16, color: AppColors.emerald),
                            ),
                            const SizedBox(width: 12),
                            Text(t.smartSuggestion,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 2,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '"${result.suggestion}"',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Guest CTA
                  if (user.isGuest) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add,
                                size: 20, color: AppColors.emerald),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.saveProgress,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Text(t.saveProgressDesc,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.4))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                provider.navigateTo(AppScreen.onboarding),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            child: Text(t.createAccount,
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          provider.navigateTo(AppScreen.library),
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      label: Text(t.nextLesson,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallBtn(
                          icon: Icons.replay,
                          label: t.restart,
                          onTap: () =>
                              provider.navigateTo(AppScreen.game),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallBtn(
                          icon: Icons.menu,
                          label: t.menu,
                          onTap: () =>
                              provider.navigateTo(AppScreen.library),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallBtn(
                          icon: Icons.share,
                          label: t.share,
                          onTap: () {},
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

// ── AI Analysis Card ──────────────────────────────────────────────
class _AiAnalysisCard extends StatelessWidget {
  final dynamic result;
  final dynamic t;

  const _AiAnalysisCard({required this.result, required this.t});

  @override
  Widget build(BuildContext context) {
    final mlAccuracy = result.mlAccuracy as double?;
    final timingOffset = result.timingOffset as double?;
    final noteConsistency = result.noteConsistency as double?;
    final predictedChord = result.predictedChord as String?;
    final referenceChord = result.referenceChord as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.cyan.withValues(alpha: 0.08),
            AppColors.emerald.withValues(alpha: 0.06),
            Colors.blue.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.3),
                      AppColors.emerald.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, size: 20, color: Colors.cyan),
              ),
              const SizedBox(width: 12),
              Text(
                t.aiAnalysis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                  color: Colors.cyan.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 10, color: Colors.cyan.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(t.aiPowered,
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.cyan.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Metric Bars
          if (mlAccuracy != null)
            _MetricBar(
              label: t.accuracy,
              value: mlAccuracy,
              color: AppColors.emerald,
              icon: Icons.track_changes,
            ),
          if (timingOffset != null) ...[
            const SizedBox(height: 12),
            _MetricBar(
              label: t.timing,
              value: (100 - timingOffset).clamp(0, 100),
              color: Colors.amber,
              icon: Icons.timer,
            ),
          ],
          if (noteConsistency != null) ...[
            const SizedBox(height: 12),
            _MetricBar(
              label: t.consistency,
              value: noteConsistency,
              color: Colors.cyan,
              icon: Icons.equalizer,
            ),
          ],

          // Chord Detection
          if (predictedChord != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.amber.withValues(alpha: 0.3),
                          AppColors.amber.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note,
                        size: 20, color: AppColors.amber),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.chordDetected,
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                              color:
                                  Colors.white.withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Text(
                        predictedChord,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (referenceChord != null) ...[
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Reference',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontFamily: 'monospace',
                                color: Colors.white
                                    .withValues(alpha: 0.3))),
                        const SizedBox(height: 4),
                        Text(
                          referenceChord,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  Colors.white.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Metric Bar ────────────────────────────────────────────────────
class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.6),
                      color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace'),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 2,
                  fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
