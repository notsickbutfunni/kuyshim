/// Game result and scroll-note models for the rhythm game.
class GameResult {
  final int score;
  final int perfect;
  final int good;
  final int miss;
  final int accuracy;
  final String lessonTitle;
  final String rank; // 'S' | 'A' | 'B' | 'C'
  final String suggestion;

  const GameResult({
    required this.score,
    required this.perfect,
    required this.good,
    required this.miss,
    required this.accuracy,
    required this.lessonTitle,
    required this.rank,
    required this.suggestion,
  });
}

class ScrollNote {
  final int id;
  final double time;
  final int string; // 1 or 2
  final int fret;
  final double duration;
  bool hit;

  ScrollNote({
    required this.id,
    required this.time,
    required this.string,
    required this.fret,
    required this.duration,
    this.hit = false,
  });
}
