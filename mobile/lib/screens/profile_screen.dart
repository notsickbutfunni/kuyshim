/// ProfileScreen — User profile with badges, activity, and settings.
/// Mirrors ProfileScreen.tsx from the React app.
/// NOTE: Subscription button and related content have been REMOVED per requirements.
library;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/user_model.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../widgets/calibration_dialog.dart';
import '../widgets/settings_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showSettings = false;

  String _getLanguageName(String lang) {
    switch (lang) {
      case 'kz':
        return 'Қазақша (KZ)';
      case 'en':
        return 'English (EN)';
      case 'ru':
        return 'Русский (RU)';
      default:
        return 'Қазақша (KZ)';
    }
  }

  Color _getRankGradientStart(String rank) {
    switch (rank) {
      case 'Legend':
        return const Color(0xFFFACC15);
      case 'Master':
        return const Color(0xFFC084FC);
      case 'Akyn':
        return KColors.emerald;
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Color _getRankGradientEnd(String rank) {
    switch (rank) {
      case 'Legend':
        return const Color(0xFFF97316);
      case 'Master':
        return const Color(0xFFEC4899);
      case 'Akyn':
        return KColors.blue;
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _showProfileSettingsDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    final t = context.read<LanguageService>().t;
    final TextEditingController usernameController = TextEditingController(text: appState.user.username);
    File? selectedImage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: KColors.surface,
              scrollable: true,
              title: Text(t.profileDetails, style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setStateDialog(() {
                          selectedImage = File(pickedFile.path);
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: selectedImage != null 
                        ? FileImage(selectedImage!) as ImageProvider
                        : CachedNetworkImageProvider(appState.user.avatar),
                      child: const Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KColors.emerald)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (selectedImage != null) {
                        await appState.uploadAvatar(selectedImage!);
                      }
                      if (usernameController.text != appState.user.username) {
                        await appState.updateUsername(usernameController.text);
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showSecuritySettingsDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    final t = context.read<LanguageService>().t;
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: KColors.surface,
          scrollable: true,
          title: Text(t.security, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KColors.emerald)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KColors.emerald)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await appState.updatePassword(currentPasswordController.text, newPasswordController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final langService = context.read<LanguageService>();
    final appState = context.read<AppState>();
    final t = langService.t;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: KColors.surface,
          title: Text(t.language, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Қазақша (KZ)', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(dialogContext, 'kz'),
              ),
              ListTile(
                title: const Text('English (EN)', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(dialogContext, 'en'),
              ),
              ListTile(
                title: const Text('Русский (RU)', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(dialogContext, 'ru'),
              ),
            ],
          ),
        );
      },
    );

    // Dialog is now fully closed — safe to change language
    if (selected != null) {
      await langService.setLang(selected);
      appState.refreshLessons();
    }
  }

  String? _getUnlockDate(List<AppBadge> badges, String key) {
    for (final b in badges) {
      if (b.key == key) return b.unlockedAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final appState = context.watch<AppState>();
    final user = appState.user;
    final screenSize = MediaQuery.of(context).size;

    final badges = [
      _Badge(
        name: t.badgeFirstSteps,
        icon: '⚡',
        date: user.isGuest ? t.locked : (_getUnlockDate(user.badges, 'badgeFirstSteps') ?? t.locked),
      ),
      _Badge(
        name: t.badgeLearner,
        icon: '📜',
        date: user.isGuest ? t.locked : (_getUnlockDate(user.badges, 'badgeLearner') ?? t.locked),
      ),
      _Badge(
        name: t.badgeTalent,
        icon: '🔥',
        date: user.isGuest ? t.locked : (_getUnlockDate(user.badges, 'badgeTalent') ?? t.locked),
      ),
      _Badge(
        name: t.badgeKuishi,
        icon: '👑',
        date: user.isGuest ? t.locked : (_getUnlockDate(user.badges, 'badgeKuishi') ?? t.locked),
      ),
    ];

    return Scaffold(
      backgroundColor: KColors.background,
      body: Stack(
        children: [
          Row(
            children: [
              // ── Left Panel: Identity & Growth ─────────────
              SizedBox(
                width: screenSize.width * 0.35,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Header buttons
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  context.go('/library'),
                              icon: const Icon(
                                  Icons.chevron_left,
                                  size: 28),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() =>
                                      _showSettings = true),
                              icon: Icon(
                                Icons.settings,
                                size: 20,
                                color: Colors.white
                                    .withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Avatar
                        Container(
                          width: screenSize.height * 0.22,
                          height: screenSize.height * 0.22,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _getRankGradientStart(user.rank),
                                _getRankGradientEnd(user.rank),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getRankGradientStart(
                                        user.rank)
                                    .withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: KColors.background,
                              borderRadius:
                                  BorderRadius.circular(30),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(28),
                              child: user.isGuest
                                  ? Container(
                                      color: Colors.white
                                          .withOpacity(0.05),
                                      child: Icon(
                                        Icons.person,
                                        size: 48,
                                        color: Colors.white
                                            .withOpacity(0.2),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: user.avatar,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) =>
                                              Container(
                                        color: Colors.white
                                            .withOpacity(0.05),
                                        child: const Icon(
                                          Icons.person,
                                          size: 48,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Username
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Rank
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${t.rank}: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                  color: Colors.white
                                      .withOpacity(0.4),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user.isGuest
                                    ? Colors.white
                                        .withOpacity(0.05)
                                    : KColors.emerald
                                        .withOpacity(0.2),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.rank,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: user.isGuest
                                      ? Colors.white
                                          .withOpacity(0.4)
                                      : KColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Progress bar (logged in only)
                        if (!user.isGuest) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white
                                    .withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${t.progressTo} ${user.level + 1}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          letterSpacing: 1.5,
                                          color: Colors.white
                                              .withOpacity(0.4),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${user.stats.mastery}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        letterSpacing: 1.5,
                                        color: Colors.white
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(4),
                                  child:
                                      LinearProgressIndicator(
                                    value: user.stats.mastery /
                                        100,
                                    backgroundColor: Colors
                                        .white
                                        .withOpacity(0.05),
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                      KColors.emerald,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Guest hint / Logout
                        if (user.isGuest) ...[
                          Text(
                            t.guestProfileHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Colors.white.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/library'),
                            icon: const Icon(
                              Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(t.startLearning),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              await appState.logout();
                              if (context.mounted) {
                                context.go('/onboarding');
                              }
                            },
                            icon: const Icon(Icons.logout,
                                size: 18,
                                color: KColors.red),
                            label: Text(
                              t.logOut,
                              style: const TextStyle(
                                  color: KColors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    KColors.red.withOpacity(0.2),
                              ),
                              backgroundColor:
                                  KColors.red.withOpacity(0.1),
                            ),
                          ),
                        ],

                        // Detailed Analytics (logged in only)
                        if (!user.isGuest) ...[
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.detailedAnalytics.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.white
                                    .withOpacity(0.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _AnalyticCard(
                                  label: t.avgBpm,
                                  value:
                                      '${user.stats.avgBpm ?? 0}',
                                  color: KColors.emerald,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AnalyticCard(
                                  label: t.accuracy,
                                  value:
                                      '${user.stats.noteAccuracy ?? 0}%',
                                  color: KColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Right Panel: Achievements & Activity ─────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Achievements header
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              t.yourAchievements,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isGuest) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                t.playToUnlock.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                  color: Colors.white
                                      .withOpacity(0.2),
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Badges grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              screenSize.width > 1000 ? 4 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: badges.length,
                        itemBuilder: (context, index) {
                          final badge = badges[index];
                          final isLocked =
                              badge.date == t.locked;

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.white
                                      .withOpacity(0.02)
                                  : Colors.white
                                      .withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(24),
                              border: Border.all(
                                color: isLocked
                                    ? Colors.white
                                        .withOpacity(0.05)
                                    : Colors.white
                                        .withOpacity(0.1),
                              ),
                            ),
                            child: Opacity(
                              opacity: isLocked ? 0.4 : 1.0,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  isLocked
                                      ? Icon(
                                          Icons.lock,
                                          size: 32,
                                          color: Colors.white
                                              .withOpacity(
                                                  0.2),
                                        )
                                      : Text(
                                          badge.icon,
                                          style:
                                              const TextStyle(
                                                  fontSize:
                                                      32),
                                        ),
                                  const SizedBox(height: 8),
                                  Text(
                                    badge.name,
                                    textAlign:
                                        TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    badge.date,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                      color: Colors.white
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Activity Tracker
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            t.activityTracker,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${t.totalHours}: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                      color: Colors.white
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  Text(
                                    user.stats.totalPractice,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${t.streak}: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                      color: Colors.white
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  Text(
                                    '${user.stats.streak} ${t.days}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: KColors.yellow,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Activity heatmap
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(32),
                          border: Border.all(
                            color:
                                Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(
                                  24, (i) {
                                final dayStr = (i + 1)
                                    .toString()
                                    .padLeft(2, '0');
                                final activity =
                                    user.activity.where(
                                  (a) => a.date.endsWith(
                                      dayStr),
                                );
                                final intensity =
                                    activity.isNotEmpty
                                        ? activity.first.value
                                        : 0;
                                Color color;
                                if (intensity == 0) {
                                  color = Colors.white
                                      .withOpacity(0.05);
                                } else if (intensity == 1) {
                                  color = const Color(
                                      0xFF064E3B);
                                } else if (intensity == 2) {
                                  color = const Color(
                                      0xFF047857);
                                } else if (intensity == 3) {
                                  color = KColors.emerald;
                                } else {
                                  color = const Color(
                                      0xFF34D399);
                                }
                                return Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius:
                                        BorderRadius.circular(
                                            3),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(
                                  'January',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5,
                                    color: Colors.white
                                        .withOpacity(0.2),
                                  ),
                                ),
                                Text(
                                  'February',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5,
                                    color: Colors.white
                                        .withOpacity(0.2),
                                  ),
                                ),
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

          // ── Settings Modal Overlay ────────────────────────
          // NOTE: Subscription button and related content are REMOVED.
          if (_showSettings)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showSettings = false),
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {}, // prevent close on modal tap
                      child: Container(
                      width: screenSize.width > 600 ? screenSize.width * 0.5 : screenSize.width * 0.9,
                      constraints: BoxConstraints(
                        maxHeight: screenSize.height * 0.9,
                      ),
                      decoration: BoxDecoration(
                        color: KColors.surface,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Settings header
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    t.accountSettings,
                                    style:
                                        GoogleFonts.playfairDisplay(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(
                                      () => _showSettings =
                                          false),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Settings items
                            // NOTE: Subscription item is intentionally omitted
                            SettingsItem(
                              icon: Icons.person,
                              label: t.profileDetails,
                              sub: t.profileDetailsSub,
                              onTap: () => _showProfileSettingsDialog(context),
                            ),
                            const SizedBox(height: 12),
                            SettingsItem(
                              icon: Icons.shield,
                              label: t.security,
                              sub: t.securitySub,
                              onTap: () => _showSecuritySettingsDialog(context),
                            ),
                            const SizedBox(height: 12),
                            SettingsItem(
                              icon: Icons.notifications,
                              label: t.notifications,
                              sub: t.notificationsSub,
                            ),
                            const SizedBox(height: 12),
                            SettingsItem(
                              icon: Icons.tune_rounded,
                              label: t.dombraTuning,
                              sub: t.dombraTuningSub,
                              onTap: () => showCalibrationDialog(context),
                            ),
                            const SizedBox(height: 12),
                            SettingsItem(
                              icon: Icons.language_rounded,
                              label: t.language,
                              sub: _getLanguageName(context.read<LanguageService>().lang),
                              onTap: () => _showLanguageDialog(context),
                            ),

                            const SizedBox(height: 32),

                            // Footer buttons
                            Container(
                              padding:
                                  const EdgeInsets.only(top: 24),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white
                                        .withOpacity(0.05),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await appState
                                            .logout();
                                        if (context.mounted) {
                                          context.go(
                                              '/onboarding');
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.logout,
                                        size: 20,
                                        color: KColors.red,
                                      ),
                                      label: Text(
                                        t.logOut,
                                        style:
                                            const TextStyle(
                                          color: KColors.red,
                                        ),
                                      ),
                                      style: OutlinedButton
                                          .styleFrom(
                                        side: BorderSide(
                                          color: KColors.red
                                              .withOpacity(
                                                  0.2),
                                        ),
                                        backgroundColor:
                                            KColors.red
                                                .withOpacity(
                                                    0.1),
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() =>
                                              _showSettings =
                                                  false),
                                      style: ElevatedButton
                                          .styleFrom(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                vertical: 16),
                                      ),
                                      child: Text(
                                          t.saveChanges),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _Badge {
  final String name;
  final String icon;
  final String date;

  const _Badge({
    required this.name,
    required this.icon,
    required this.date,
  });
}

class _AnalyticCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticCard({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
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
