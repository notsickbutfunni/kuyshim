class GameResult {
  final int score;
  final int perfect;
  final int good;
  final int miss;
  final int accuracy;
  final String lessonTitle;
  final String rank;
  final String suggestion;

  // ML analysis fields (populated after backend returns)
  final double? mlAccuracy;
  final double? timingOffset;
  final double? noteConsistency;
  final double? mlFinalScore;
  final String? predictedChord;
  final String? referenceChord;
  final int? performanceId;

  const GameResult({
    required this.score,
    required this.perfect,
    required this.good,
    required this.miss,
    required this.accuracy,
    required this.lessonTitle,
    required this.rank,
    required this.suggestion,
    this.mlAccuracy,
    this.timingOffset,
    this.noteConsistency,
    this.mlFinalScore,
    this.predictedChord,
    this.referenceChord,
    this.performanceId,
  });

  GameResult copyWith({
    int? score,
    int? perfect,
    int? good,
    int? miss,
    int? accuracy,
    String? lessonTitle,
    String? rank,
    String? suggestion,
    double? mlAccuracy,
    double? timingOffset,
    double? noteConsistency,
    double? mlFinalScore,
    String? predictedChord,
    String? referenceChord,
    int? performanceId,
  }) {
    return GameResult(
      score: score ?? this.score,
      perfect: perfect ?? this.perfect,
      good: good ?? this.good,
      miss: miss ?? this.miss,
      accuracy: accuracy ?? this.accuracy,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      rank: rank ?? this.rank,
      suggestion: suggestion ?? this.suggestion,
      mlAccuracy: mlAccuracy ?? this.mlAccuracy,
      timingOffset: timingOffset ?? this.timingOffset,
      noteConsistency: noteConsistency ?? this.noteConsistency,
      mlFinalScore: mlFinalScore ?? this.mlFinalScore,
      predictedChord: predictedChord ?? this.predictedChord,
      referenceChord: referenceChord ?? this.referenceChord,
      performanceId: performanceId ?? this.performanceId,
    );
  }

  bool get hasMLData => mlAccuracy != null || performanceId != null;
}
