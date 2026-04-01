import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeTab = 'beginner';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final t = provider.t;
    final user = provider.user;
    final lessons = provider.lessons;

    final filtered = lessons.where((l) => l.level == _activeTab).toList();
    final beginnerLessons = lessons.where((l) => l.level == 'beginner').toList();
    final proLessons = lessons.where((l) => l.level == 'pro').toList();
    final beginnerCompleted =
        beginnerLessons.where((l) => l.progressStatus == 'completed').length;
    final proCompleted =
        proLessons.where((l) => l.progressStatus == 'completed').length;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 72,
            decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.music_note, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 24),
                _SidebarBtn(
                  icon: Icons.play_arrow,
                  active: true,
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                _SidebarBtn(
                  icon: Icons.settings,
                  onTap: () => provider.navigateTo(AppScreen.tuner),
                ),
                const SizedBox(height: 16),
                _SidebarBtn(
                  icon: Icons.person,
                  onTap: () => provider.navigateTo(AppScreen.profile),
                ),
                const Spacer(),
                Icon(Icons.bolt, color: Colors.yellow[700], size: 20),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.libraryTitle, style: serifBold(28)),
                            const SizedBox(height: 4),
                            Text(
                              user.isGuest
                                  ? t.guestAccess
                                  : '${t.welcomeBack}, ${user.username}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Lang toggle
                      GestureDetector(
                        onTap: () => provider.toggleLanguage(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            AppStrings.langLabel(provider.lang),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events,
                                size: 16, color: Colors.yellow[700]),
                            const SizedBox(width: 8),
                            Text(
                              '${user.isGuest ? '0' : '2,450'} XP',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      _TabButton(
                        label: t.beginner,
                        icon: Icons.menu_book,
                        count: '$beginnerCompleted/${beginnerLessons.length}',
                        active: _activeTab == 'beginner',
                        color: AppColors.emerald,
                        onTap: () => setState(() => _activeTab = 'beginner'),
                      ),
                      const SizedBox(width: 12),
                      _TabButton(
                        label: t.pro,
                        icon: Icons.star,
                        count: '$proCompleted/${proLessons.length}',
                        active: _activeTab == 'pro',
                        color: AppColors.violet,
                        onTap: () => setState(() => _activeTab = 'pro'),
                      ),
                      const Spacer(),
                      Text(
                        '${beginnerCompleted + proCompleted} ${t.completed.toLowerCase()} • ${lessons.length} ${t.totalLessons}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lesson Cards
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(Icons.music_note,
                                    size: 32,
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              const SizedBox(height: 24),
                              Text(t.noLessonsFound,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                _activeTab == 'beginner'
                                    ? t.beginnerHint
                                    : t.proHint,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final lesson = filtered[i];
                            final isLocked =
                                user.isGuest && lesson.isPremium;
                            final accent = _activeTab == 'pro'
                                ? AppColors.violet
                                : AppColors.emerald;
                            return Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: _LessonCard(
                                lesson: lesson,
                                isLocked: isLocked,
                                accent: accent,
                                isPro: _activeTab == 'pro',
                                t: t,
                                onTap: isLocked
                                    ? null
                                    : () => provider.selectLesson(lesson),
                              ),
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
}

class _SidebarBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SidebarBtn({
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 24,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? color : Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: active ? color : Colors.white.withValues(alpha: 0.4))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(count,
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color:
                          active ? color : Colors.white.withValues(alpha: 0.3))),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isLocked;
  final Color accent;
  final bool isPro;
  final dynamic t;
  final VoidCallback? onTap;

  const _LessonCard({
    required this.lesson,
    required this.isLocked,
    required this.accent,
    required this.isPro,
    required this.t,
    this.onTap,
  });

  Widget _statusBadge() {
    if (lesson.progressStatus == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 12, color: AppColors.emerald),
            const SizedBox(width: 4),
            Text(t.completed,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald)),
          ],
        ),
      );
    }
    if (lesson.progressStatus == 'started') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 12, color: Colors.amber),
            const SizedBox(width: 4),
            Text(t.inProgress,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(t.newLabel,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.3))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Image.asset(
                      lesson.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(Icons.music_note,
                            color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.cardBg,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Lock overlay
                  if (isLocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child:
                              const Icon(Icons.lock, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  // Level badge
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isPro ? '⚡ ${t.pro}' : '🎵 ${t.beginner}',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accent,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  // Difficulty
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      children: List.generate(5, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.music_note,
                            size: 12,
                            color: i < lesson.difficulty
                                ? accent
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lesson.composer,
                            style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                color: Colors.white.withValues(alpha: 0.3),
                                letterSpacing: 2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _statusBadge(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(lesson.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (lesson.description != null) ...[
                      const SizedBox(height: 4),
                      Text(lesson.description!,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.3)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const Spacer(),
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: Icon(
                          isLocked ? Icons.lock : Icons.play_arrow,
                          size: 16,
                          color: isLocked
                              ? Colors.white.withValues(alpha: 0.2)
                              : (isPro ? Colors.white : Colors.black),
                        ),
                        label: Text(
                          isLocked
                              ? t.premiumOnly
                              : lesson.progressStatus == 'completed'
                                  ? t.practiceAgain
                                  : lesson.progressStatus == 'started'
                                      ? t.continueLabel
                                      : t.startPractice,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isLocked
                                ? Colors.white.withValues(alpha: 0.2)
                                : (isPro ? Colors.white : Colors.black),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? Colors.white.withValues(alpha: 0.05)
                              : isPro
                                  ? AppColors.violet
                                  : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
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
    );
  }
}
