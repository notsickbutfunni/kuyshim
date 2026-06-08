/// KuiNote — модель одной ноты из JSON-карты уровня.
///
/// Парсит поля из beatmap JSON:
///   id, time_ms, type, primary_hz, primary_note, lane,
///   string ("bass"/"treble"/"both"), fret (0-9), technique ("sherpe"/"qagys").
class KuiNote {
  final int id;
  final int timeMs;
  final int type;
  final double primaryHz;
  final String primaryNote;
  final int lane;

  /// Which dombra string: "bass", "treble", or "both"
  final String stringName;

  /// Fret number (0 = open string, 1-9 = fretted)
  final int fret;

  /// Playing technique: "sherpe" (pluck) or "qagys" (strum)
  final String technique;

  /// Stroke direction: "up", "down", or null
  final String? strokeDirection;

  bool isPlayed;
  bool isMissed;

  /// Hit quality: 'perfect', 'good', or null
  String? hitQuality;

  KuiNote({
    required this.id,
    required this.timeMs,
    required this.type,
    required this.primaryHz,
    required this.primaryNote,
    required this.lane,
    required this.stringName,
    required this.fret,
    required this.technique,
    this.strokeDirection,
    this.isPlayed = false,
    this.isMissed = false,
    this.hitQuality,
  });

  factory KuiNote.fromJson(Map<String, dynamic> json) {
    return KuiNote(
      id: json['id'] as int? ?? 0,
      timeMs: json['time_ms'] as int? ?? 0,
      type: json['type'] as int? ?? 0,
      primaryHz: (json['primary_hz'] as num?)?.toDouble() ?? 0.0,
      primaryNote: json['primary_note'] as String? ?? '',
      lane: json['lane'] as int? ?? 0,
      stringName: json['string'] as String? ?? 'bass',
      fret: json['fret'] as int? ?? 0,
      technique: json['technique'] as String? ?? 'sherpe',
      strokeDirection: json['stroke_direction'] as String?,
    );
  }

  bool get isActive => type == 1;
  bool get isPause => type == 0;
  double get timeSec => timeMs / 1000.0;

  void reset() {
    isPlayed = false;
    isMissed = false;
    hitQuality = null;
  }

  @override
  String toString() =>
      'KuiNote(id=$id, t=${timeMs}ms, type=$type, '
      'note=$primaryNote, hz=$primaryHz, string=$stringName, '
      'fret=$fret, tech=$technique, played=$isPlayed, missed=$isMissed)';
}
