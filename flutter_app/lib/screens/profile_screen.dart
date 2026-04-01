import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final t = provider.t;
    final user = provider.user;
    final size = MediaQuery.of(context).size;

    final badges = [
      {'name': t.badgeFastFingers, 'icon': '⚡', 'date': user.isGuest ? t.locked : 'Feb 12'},
      {'name': t.badgeTraditionKeeper, 'icon': '📜', 'date': user.isGuest ? t.locked : 'Feb 15'},
      {'name': t.badgePerfectAdai, 'icon': '🔥', 'date': user.isGuest ? t.locked : 'Feb 18'},
      {'name': t.badgeEarlyBird, 'icon': '🌅', 'date': t.locked},
    ];

    Color rankGradientStart;
    Color rankGradientEnd;
    switch (user.rank) {
      case 'Legend':
        rankGradientStart = Colors.yellow;
        rankGradientEnd = Colors.orange;
        break;
      case 'Master':
        rankGradientStart = Colors.purple;
        rankGradientEnd = Colors.pink;
        break;
      case 'Akyn':
        rankGradientStart = AppColors.emerald;
        rankGradientEnd = Colors.blue;
        break;
      default:
        rankGradientStart = Colors.grey;
        rankGradientEnd = Colors.grey[700]!;
    }

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Left Panel — Identity
              SizedBox(
                width: size.width > 900 ? 400 : size.width * 0.45,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () =>
                                provider.navigateTo(AppScreen.library),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Row(
                            children: [
                              // Lang toggle
                              GestureDetector(
                                onTap: () => provider.toggleLanguage(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Text(
                                    AppStrings.langLabel(provider.lang),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showSettings = true),
                                icon: Icon(Icons.settings,
                                    color:
                                        Colors.white.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Avatar
                      Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          gradient: LinearGradient(
                            colors: [rankGradientStart, rankGradientEnd],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: rankGradientStart.withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            color: AppColors.scaffoldBg,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: user.isGuest
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                  child: Icon(Icons.person,
                                      size: 48,
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: CachedNetworkImage(
                                    imageUrl: user.avatar,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      if (!user.isGuest)
                        Transform.translate(
                          offset: const Offset(40, -16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.yellow[700],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.scaffoldBg, width: 3),
                            ),
                            child: Text('Lvl ${user.level}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(user.username,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${t.rank}: ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 2,
                                  fontFamily: 'monospace')),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user.isGuest
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(user.rank,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: user.isGuest
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : AppColors.emerald)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Progress bar (logged in only)
                      if (!user.isGuest) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${t.progressTo} ${user.level + 1}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                          letterSpacing: 2,
                                          color: Colors.white.withValues(alpha: 0.4))),
                                  Text('${user.stats.mastery}%',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                          letterSpacing: 2,
                                          color: Colors.white.withValues(alpha: 0.4))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: user.stats.mastery / 100,
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppColors.emerald),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (user.isGuest) ...[
                        Text(t.guestProfileHint,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () =>
                              provider.navigateTo(AppScreen.library),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(t.startLearning),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => provider.logout(),
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(t.logOut),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            foregroundColor: Colors.red[400],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.2)),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Analytics (logged in)
                      if (!user.isGuest) ...[
                        Text(t.detailedAnalytics,
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.2),
                                letterSpacing: 3,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _AnalyticsCard(
                                label: t.avgBpm,
                                value: '${user.stats.avgBpm ?? '-'}',
                                color: AppColors.emerald,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AnalyticsCard(
                                label: t.accuracy,
                                value: '${user.stats.noteAccuracy ?? '-'}%',
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),

              // Right Panel — Achievements & Activity
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Achievements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.yourAchievements, style: serifBold(22)),
                          if (user.isGuest)
                            Text(t.playToUnlock,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withValues(alpha: 0.2),
                                    letterSpacing: 2,
                                    fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                        children: badges.map((badge) {
                          final isLocked = badge['date'] == t.locked;
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: isLocked
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                isLocked
                                    ? Icon(Icons.lock,
                                        size: 32,
                                        color: Colors.white.withValues(alpha: 0.2))
                                    : Text(badge['icon'] as String,
                                        style: const TextStyle(fontSize: 32)),
                                const SizedBox(height: 12),
                                Text(badge['name'] as String,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 4),
                                Text(badge['date'] as String,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withValues(alpha: 0.3),
                                        letterSpacing: 2,
                                        fontFamily: 'monospace')),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 48),

                      // Activity Tracker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.activityTracker, style: serifBold(22)),
                          Row(
                            children: [
                              Text('${t.totalHours}: ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                      color: Colors.white.withValues(alpha: 0.4))),
                              Text(user.stats.totalPractice,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white)),
                              const SizedBox(width: 16),
                              Text('${t.streak}: ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                      color: Colors.white.withValues(alpha: 0.4))),
                              Text('${user.stats.streak} ${t.days}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.yellow[400])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(24, (i) {
                                final activity = user.activity
                                    .where((a) => a.date.endsWith(
                                        '${i + 1 < 10 ? '0' : ''}${i + 1}'))
                                    .firstOrNull;
                                final intensity = activity?.value ?? 0;
                                Color color;
                                switch (intensity) {
                                  case 1:
                                    color = Colors.green[900]!;
                                    break;
                                  case 2:
                                    color = Colors.green[700]!;
                                    break;
                                  case 3:
                                    color = Colors.green[500]!;
                                    break;
                                  default:
                                    color = Colors.white.withValues(alpha: 0.05);
                                }
                                return Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('January',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        letterSpacing: 2,
                                        color: Colors.white.withValues(alpha: 0.2))),
                                Text('February',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        letterSpacing: 2,
                                        color: Colors.white.withValues(alpha: 0.2))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Settings Modal
          if (_showSettings)
            GestureDetector(
              onTap: () => setState(() => _showSettings = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // absorb tap
                    child: Container(
                      width: 550,
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.accountSettings,
                                  style: serifBold(24)),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showSettings = false),
                                icon: const Icon(Icons.close,
                                    color: Colors.white38),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _SettingsItem(
                              icon: Icons.person,
                              label: t.profileDetails,
                              sub: t.profileDetailsSub,
                              onTap: () {},
                          ),
                          const SizedBox(height: 12),
                          _SettingsItem(
                              icon: Icons.shield,
                              label: t.security,
                              sub: t.securitySub,
                              onTap: () {},
                          ),
                          const SizedBox(height: 12),
                          _SettingsItem(
                              icon: Icons.notifications,
                              label: t.notifications,
                              sub: t.notificationsSub,
                              onTap: () {},
                          ),
                          const SizedBox(height: 32),
                          Divider(color: Colors.white.withValues(alpha: 0.05)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => provider.logout(),
                                  icon: const Icon(Icons.logout, size: 20),
                                  label: Text(t.logOut),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withValues(alpha: 0.1),
                                    foregroundColor: Colors.red[400],
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide(
                                        color:
                                            Colors.red.withValues(alpha: 0.2)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      setState(() => _showSettings = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(t.saveChanges,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticsCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white70),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
