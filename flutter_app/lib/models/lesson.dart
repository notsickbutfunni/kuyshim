class Lesson {
  final String id;
  final String title;
  final String composer;
  final int difficulty;
  final int progress;
  final String image;
  final List<GameNote> notes;
  final bool isPremium;
  final String? level;
  final String? progressStatus;
  final String? description;
  final String? tabUrl;
  final String? videoUrl;
  final String? audioFile;

  const Lesson({
    required this.id,
    required this.title,
    required this.composer,
    required this.difficulty,
    required this.progress,
    required this.image,
    required this.notes,
    required this.isPremium,
    this.level,
    this.progressStatus,
    this.description,
    this.tabUrl,
    this.videoUrl,
    this.audioFile,
  });

  Lesson copyWith({
    String? id,
    String? title,
    String? composer,
    int? difficulty,
    int? progress,
    String? image,
    List<GameNote>? notes,
    bool? isPremium,
    String? level,
    String? progressStatus,
    String? description,
    String? tabUrl,
    String? videoUrl,
    String? audioFile,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      difficulty: difficulty ?? this.difficulty,
      progress: progress ?? this.progress,
      image: image ?? this.image,
      notes: notes ?? this.notes,
      isPremium: isPremium ?? this.isPremium,
      level: level ?? this.level,
      progressStatus: progressStatus ?? this.progressStatus,
      description: description ?? this.description,
      tabUrl: tabUrl ?? this.tabUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioFile: audioFile ?? this.audioFile,
    );
  }

  factory Lesson.fromApi(Map<String, dynamic> json) {
    final level = json['level'] as String? ?? 'beginner';
    final progressStatus = json['progress_status'] as String?;
    final title = json['title'] as String? ?? '';
    return Lesson(
      id: json['id'].toString(),
      title: title,
      composer: json['composer'] as String? ?? 'Unknown',
      difficulty: level == 'pro' ? 4 : 2,
      progress: progressStatus == 'completed'
          ? 100
          : progressStatus == 'started'
              ? 50
              : 0,
      image: _lessonImage(json['id']),
      notes: [],
      isPremium: level == 'pro',
      level: level,
      progressStatus: progressStatus,
      description: json['description'] as String?,
      tabUrl: json['tab_url'] as String?,
      videoUrl: json['video_url'] as String?,
      audioFile: json['audio_path'] as String?,
    );
  }
}

class GameNote {
  final double time;
  final int string;
  final int fret;
  final double duration;

  const GameNote({
    required this.time,
    required this.string,
    required this.fret,
    required this.duration,
  });
}

const List<String> lessonImages = [
  'assets/images/lessons/dombra_1.jpg',
  'assets/images/lessons/dombra_2.jpg',
  'assets/images/lessons/dombra_3.jpg',
  'assets/images/lessons/dombra_4.jpg',
  'assets/images/lessons/dombra_5.webp',
  'assets/images/lessons/dombra_6.jpg',
  'assets/images/lessons/dombra_7.png',
  'assets/images/lessons/dombra_8.jpg',
  'assets/images/lessons/dombra_9.jpeg',
  'assets/images/lessons/dombra_10.jpg',
  'assets/images/lessons/dombra_11.jpg',
  'assets/images/lessons/dombra_12.jpg',
  'assets/images/lessons/dombra_13.jpg',
  'assets/images/lessons/dombra_14.jpg',
  'assets/images/lessons/dombra_15.jpg',
  'assets/images/lessons/dombra_16.jpg',
  'assets/images/lessons/dombra_17.jpg',
  'assets/images/lessons/dombra_18.jpg',
];

String _lessonImage(dynamic id) {
  final index = (id is int ? id : id.hashCode) % lessonImages.length;
  return lessonImages[index.abs()];
}

String lessonImageByIndex(int index) {
  return lessonImages[index % lessonImages.length];
}
