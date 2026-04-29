/// User model — mirrors the React User interface.
class ActivityEntry {
  final String date;
  final int value;

  const ActivityEntry({required this.date, required this.value});
}

class AppBadge {
  final String key;
  final String unlockedAt;

  const AppBadge({required this.key, required this.unlockedAt});
}

class UserStats {
  final String totalPractice;
  final int mastery;
  final int streak;
  final int? avgBpm;
  final int? noteAccuracy;

  const UserStats({
    required this.totalPractice,
    required this.mastery,
    required this.streak,
    this.avgBpm,
    this.noteAccuracy,
  });
}

class AppUser {
  final bool isGuest;
  final String username;
  final String avatar;
  final int level;
  final String rank; // 'Student' | 'Akyn' | 'Master' | 'Legend'
  final UserStats stats;
  final List<ActivityEntry> activity;
  final List<AppBadge> badges;

  const AppUser({
    required this.isGuest,
    required this.username,
    required this.avatar,
    required this.level,
    required this.rank,
    required this.stats,
    required this.activity,
    required this.badges,
  });

  AppUser copyWith({
    bool? isGuest,
    String? username,
    String? avatar,
    int? level,
    String? rank,
    UserStats? stats,
    List<ActivityEntry>? activity,
    List<AppBadge>? badges,
  }) {
    return AppUser(
      isGuest: isGuest ?? this.isGuest,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      stats: stats ?? this.stats,
      activity: activity ?? this.activity,
      badges: badges ?? this.badges,
    );
  }

  static const AppUser guest = AppUser(
    isGuest: true,
    username: 'Guest Player',
    avatar: 'https://picsum.photos/seed/guest/200/200',
    level: 1,
    rank: 'Student',
    stats: UserStats(totalPractice: '0h', mastery: 0, streak: 0),
    activity: [],
    badges: [],
  );
}
