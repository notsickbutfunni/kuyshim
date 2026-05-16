/// GamePainter — CustomPainter for 2-string dombra fretboard rendering.
/// Draws: fretboard background, 2 strings, scrolling notes, hit line, bouncing ball.
///
/// Performance optimizations:
///   - Paint objects are cached and reused across frames instead of
///     allocating new ones per draw call.
///   - MaskFilter.blur (expensive GPU op) is limited to only the 2 closest notes.
///   - TextPainter reuse for fret numbers via a small cache.
library;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/kui_note.dart';

// Note colors by fret number (Yousician-style)
Color fretColor(int fret) {
  if (fret == 0) return const Color(0xFF9CA3AF);
  if (fret <= 2) return const Color(0xFF10B981);
  if (fret <= 4) return const Color(0xFFF59E0B);
  if (fret <= 6) return const Color(0xFF8B5CF6);
  return const Color(0xFF3B82F6);
}

const Color bassColor = Color(0xFF10B981);
const Color trebleColor = Color(0xFFF0C850);
const Color hitLineColor = Color(0xFFF0C850);

class GamePainter extends CustomPainter {
  final double sw, sh;
  final int currentTimeMs;
  final List<KuiNote> activeNotes;
  final List<double> beatTimesSec;
  final bool isPlaying;
  final int? tutorialWaitingNoteId;

  // Layout constants derived from screen size
  late final double hitLineX = sw * 0.15;
  late final double fretboardTop = sh * 0.25;
  late final double fretboardBottom = sh * 0.75;
  late final double fretboardH = fretboardBottom - fretboardTop;
  late final double trebleY = fretboardTop + fretboardH * 0.35;
  late final double bassY = fretboardTop + fretboardH * 0.70;
  late final double visibleWidth = sw - hitLineX;
  static const double visibleWindowSec = 4.0;
  late final double pxPerMs = visibleWidth / (visibleWindowSec * 1000);
  late final double noteW = sw * 0.05;
  late final double noteH = sh * 0.065;

  // ── Cached Paint objects (reused across draw calls) ──
  late final Paint _bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
    ).createShader(Rect.fromLTWH(0, fretboardTop, sw, fretboardH));

  late final Paint _divPaint = Paint()
    ..color = Colors.white.withOpacity(0.03)
    ..strokeWidth = 1;

  late final Paint _beatPaint = Paint()
    ..color = Colors.white.withOpacity(0.06)
    ..strokeWidth = 1;

  late final Paint _treblePaint = Paint()
    ..shader = LinearGradient(colors: [
      trebleColor.withOpacity(0.05), trebleColor.withOpacity(0.4),
      trebleColor.withOpacity(0.6), trebleColor.withOpacity(0.4),
      trebleColor.withOpacity(0.05),
    ]).createShader(Rect.fromLTWH(0, trebleY - 2, sw, 4));

  late final Paint _bassPaint = Paint()
    ..shader = LinearGradient(colors: [
      bassColor.withOpacity(0.05), bassColor.withOpacity(0.4),
      bassColor.withOpacity(0.6), bassColor.withOpacity(0.4),
      bassColor.withOpacity(0.05),
    ]).createShader(Rect.fromLTWH(0, bassY - 2, sw, 4));

  // Reusable paint objects for notes (color is set per-note)
  final Paint _noteFillPaint = Paint();
  final Paint _noteBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final Paint _noteGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  // Ball paints
  late final Paint _ballGlowPaint = Paint()
    ..color = Colors.white.withOpacity(0.08)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _ballPaint = Paint()..color = Colors.white;
  final Paint _ballCorePaint = Paint()..color = Colors.white.withOpacity(0.9);

  // TextPainter cache for fret numbers
  final Map<int, TextPainter> _fretTextCache = {};

  TextPainter _getFretText(int fret, double size) {
    if (!_fretTextCache.containsKey(fret)) {
      _fretTextCache[fret] = TextPainter(
        text: TextSpan(text: '$fret', style: TextStyle(
          color: Colors.white.withOpacity(0.9), // Static opacity for cache
          fontSize: size, fontWeight: FontWeight.w800,
        )),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _fretTextCache[fret]!;
  }

  GamePainter({
    required this.sw,
    required this.sh,
    required this.currentTimeMs,
    required this.activeNotes,
    required this.beatTimesSec,
    required this.isPlaying,
    this.tutorialWaitingNoteId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawFretboardBg(canvas);
    _drawBeatLines(canvas);
    _drawStrings(canvas);
    _drawHitLine(canvas);
    _drawNotes(canvas);
    _drawBouncingBall(canvas);
  }

  void _drawFretboardBg(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, fretboardTop, sw, fretboardH), _bgPaint);

    // Subtle horizontal dividers
    for (int i = 1; i < 5; i++) {
      final y = fretboardTop + fretboardH * i / 5;
      canvas.drawLine(Offset(0, y), Offset(sw, y), _divPaint);
    }
  }

  void _drawBeatLines(Canvas canvas) {
    for (final bt in beatTimesSec) {
      final x = hitLineX + (bt * 1000 - currentTimeMs) * pxPerMs;
      if (x < 0 || x > sw) continue;
      canvas.drawLine(Offset(x, fretboardTop), Offset(x, fretboardBottom), _beatPaint);
    }
  }

  void _drawStrings(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, trebleY - 2, sw, 4), _treblePaint);
    canvas.drawRect(Rect.fromLTWH(0, bassY - 2, sw, 4), _bassPaint);

    // String labels (left side)
    _drawLabel(canvas, 'D3', hitLineX - sw * 0.05, trebleY, trebleColor);
    _drawLabel(canvas, 'A2', hitLineX - sw * 0.05, bassY, bassColor);
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, Color c) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: c.withOpacity(0.5), fontSize: sh * 0.02,
        fontWeight: FontWeight.w700, fontFamily: 'monospace',
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _drawHitLine(Canvas canvas) {
    final hitRect = Rect.fromLTWH(hitLineX - 1.5, fretboardTop - sh * 0.03, 3, fretboardH + sh * 0.06);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.transparent, hitLineColor.withOpacity(0.6),
          hitLineColor, hitLineColor.withOpacity(0.6), Colors.transparent,
        ],
      ).createShader(hitRect);
    canvas.drawRect(hitRect, paint);

    // Glow circles on strings
    if (isPlaying) {
      for (final sy in [trebleY, bassY]) {
        final glow = Paint()
          ..shader = RadialGradient(colors: [
            hitLineColor.withOpacity(0.15), Colors.transparent,
          ]).createShader(Rect.fromCircle(center: Offset(hitLineX, sy), radius: sh * 0.05));
        canvas.drawCircle(Offset(hitLineX, sy), sh * 0.05, glow);
      }
    }
  }

  void _drawNotes(Canvas canvas) {
    // Track the closest unplayed notes for glow effect (limit blur to 2 max)
    int glowCount = 0;
    const maxGlowNotes = 2;

    for (final note in activeNotes) {
      final x = hitLineX + (note.timeMs - currentTimeMs) * pxPerMs;
      if (x < -noteW * 2 || x > sw + noteW) continue;

      // Y position based on string
      double y;
      double h = noteH;
      if (note.stringName == 'treble') {
        y = trebleY;
      } else if (note.stringName == 'both') {
        y = (trebleY + bassY) / 2;
        h = bassY - trebleY + noteH;
      } else {
        y = bassY;
      }

      final color = fretColor(note.fret);
      final proximity = 1.0 - ((x - hitLineX).abs() / visibleWidth).clamp(0.0, 1.0);

      // Choose appearance based on state — reuse cached Paint objects
      if (note.isPlayed) {
        _noteFillPaint.color = (note.hitQuality == 'perfect' ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
            .withOpacity(0.4);
        _noteBorderPaint.color = _noteFillPaint.color.withOpacity(0.6);
      } else if (note.isMissed) {
        _noteFillPaint.color = Colors.red.withOpacity(0.15);
        _noteBorderPaint.color = Colors.red.withOpacity(0.3);
      } else {
        _noteFillPaint.color = color.withOpacity(0.2 + 0.4 * proximity);
        _noteBorderPaint.color = color.withOpacity(0.5 + 0.5 * proximity);
      }

      // Note body
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: noteW, height: h),
        Radius.circular(h / 2),
      );
      canvas.drawRRect(rrect, _noteFillPaint);
      canvas.drawRRect(rrect, _noteBorderPaint);

      // Glow for close notes — LIMITED to maxGlowNotes to avoid GPU overload
      if (!note.isPlayed && !note.isMissed && proximity > 0.7 && glowCount < maxGlowNotes) {
        _noteGlowPaint.color = color.withOpacity(0.1 * proximity);
        canvas.drawRRect(rrect, _noteGlowPaint);
        glowCount++;
      }

      // Tutorial waiting pulse
      if (tutorialWaitingNoteId != null && note.id == tutorialWaitingNoteId) {
        final pulse = (math.sin(currentTimeMs * 0.005) + 1) / 2; // 0 to 1
        final pulsePaint = Paint()
          ..color = Colors.amber.withOpacity(0.5 + 0.5 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 + 4.0 * pulse;
        
        final pulseRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: noteW + 10 * pulse, height: h + 10 * pulse),
          Radius.circular((h + 10 * pulse) / 2),
        );
        canvas.drawRRect(pulseRect, pulsePaint);
        
        // "Play!" hint text
        final hintTp = TextPainter(
          text: TextSpan(text: '🎸 Ойна!', style: TextStyle(
            color: Colors.amber, fontSize: noteH * 0.5, fontWeight: FontWeight.bold,
          )),
          textDirection: TextDirection.ltr,
        )..layout();
        hintTp.paint(canvas, Offset(x - hintTp.width / 2, y + h / 2 + 10));
      }

      // Fret number text
      if (!note.isPlayed && !note.isMissed) {
        final tp = _getFretText(note.fret, noteH * 0.45);
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  void _drawBouncingBall(Canvas canvas) {
    // Find previous and next note relative to current time
    KuiNote? prev, next;
    for (final n in activeNotes) {
      if (n.timeMs <= currentTimeMs && n.isActive) prev = n;
      if (n.timeMs > currentTimeMs && n.isActive && next == null) next = n;
    }

    final mid = (trebleY + bassY) / 2;
    double prevY = prev != null ? _stringY(prev.stringName) : mid;
    double nextY = next != null ? _stringY(next.stringName) : mid;
    int prevT = prev?.timeMs ?? (currentTimeMs - 500);
    int nextT = next?.timeMs ?? (currentTimeMs + 500);

    double t = ((currentTimeMs - prevT) / math.max(nextT - prevT, 1)).clamp(0.0, 1.0);

    // Parabolic arc between strings
    double ballY = prevY + (nextY - prevY) * t;
    double arcH = (prevY - nextY).abs() * 0.4 + sh * 0.04;
    ballY -= arcH * 4 * t * (1 - t);

    final ballR = sh * 0.015;

    // Glow
    canvas.drawCircle(Offset(hitLineX, ballY), ballR * 3, _ballGlowPaint);

    // Ball
    canvas.drawCircle(Offset(hitLineX, ballY), ballR, _ballPaint);
    canvas.drawCircle(Offset(hitLineX, ballY), ballR * 0.5, _ballCorePaint);
  }

  double _stringY(String s) {
    if (s == 'treble') return trebleY;
    if (s == 'both') return (trebleY + bassY) / 2;
    return bassY;
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => old.currentTimeMs != currentTimeMs;
}
