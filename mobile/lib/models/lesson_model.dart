/// Lesson and GameNote models — mirrors the React types.
/// Extended with storageType for hybrid offline/online architecture.

/// Determines where the lesson audio/image is stored.
enum StorageType {
  /// Bundled in assets/audio/ — always available offline
  local,

  /// Must be downloaded from Firebase Storage (cached after first download)
  remote,
}

class GameNote {
  final double time; // in seconds
  final int string; // 1 or 2
  final int fret;
  final double duration;

  const GameNote({
    required this.time,
    required this.string,
    required this.fret,
    required this.duration,
  });
}

class Lesson {
  final String id;
  final String title;
  final String composer;
  final int difficulty; // 1-5
  final int progress;
  final String image;
  final List<GameNote> notes;
  final bool requiresAuth;
  final String level; // 'beginner' | 'pro'
  final String? progressStatus; // 'started' | 'completed' | null
  final String? description;
  final String? tabUrl;
  final String? videoUrl;
  final String? audioFile;

  /// Whether this lesson's audio is bundled locally or remote.
  final StorageType storageType;

  /// Local asset path for images bundled in assets/ (null = use network image URL).
  final String? localImageAsset;

  const Lesson({
    required this.id,
    required this.title,
    required this.composer,
    required this.difficulty,
    this.progress = 0,
    required this.image,
    this.notes = const [],
    this.requiresAuth = false,
    this.level = 'beginner',
    this.progressStatus,
    this.description,
    this.tabUrl,
    this.videoUrl,
    this.audioFile,
    this.storageType = StorageType.remote,
    this.localImageAsset,
  });

  /// Whether this lesson is available offline (bundled in assets).
  bool get isLocal => storageType == StorageType.local;

  /// Whether this lesson needs internet to access.
  bool get isRemote => storageType == StorageType.remote;

  Lesson copyWith({
    String? id,
    String? title,
    String? composer,
    int? difficulty,
    int? progress,
    String? image,
    List<GameNote>? notes,
    bool? requiresAuth,
    String? level,
    String? progressStatus,
    String? description,
    String? tabUrl,
    String? videoUrl,
    String? audioFile,
    StorageType? storageType,
    String? localImageAsset,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      difficulty: difficulty ?? this.difficulty,
      progress: progress ?? this.progress,
      image: image ?? this.image,
      notes: notes ?? this.notes,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      level: level ?? this.level,
      progressStatus: progressStatus ?? this.progressStatus,
      description: description ?? this.description,
      tabUrl: tabUrl ?? this.tabUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioFile: audioFile ?? this.audioFile,
      storageType: storageType ?? this.storageType,
      localImageAsset: localImageAsset ?? this.localImageAsset,
    );
  }

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      composer: json['composer'] ?? '',
      difficulty: json['difficulty'] ?? 1,
      progress: json['progress'] ?? 0,
      image: json['image'] ?? 'https://picsum.photos/seed/${json['title']}/800/450',
      notes: const [], // Parsing notes logic could be added here if needed
      requiresAuth: true, // As per user request, remote items now require auth
      level: json['level'] ?? 'beginner',
      progressStatus: json['progress_status'],
      description: json['description'],
      tabUrl: json['tab_url'],
      videoUrl: json['video_url'],
      audioFile: json['audio_file'] ?? json['video_url']?.replaceAll('.mp4', '.mp3'),
      storageType: StorageType.remote, // Assume fetched lessons are remote
    );
  }
}
