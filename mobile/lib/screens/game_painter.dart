/// GamePainter — CustomPainter for 2-string dombra fretboard rendering.
/// Draws: fretboard background, 2 strings, scrolling notes, hit line, bouncing ball.
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

  GamePainter({
    required this.sw,
    required this.sh,
    required this.currentTimeMs,
    required this.activeNotes,
    required this.beatTimesSec,
    required this.isPlaying,
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
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
      ).createShader(Rect.fromLTWH(0, fretboardTop, sw, fretboardH));
    canvas.drawRect(Rect.fromLTWH(0, fretboardTop, sw, fretboardH), paint);

    // Subtle horizontal dividers
    final divPaint = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final y = fretboardTop + fretboardH * i / 5;
      canvas.drawLine(Offset(0, y), Offset(sw, y), divPaint);
    }
  }

  void _drawBeatLines(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 1;
    for (final bt in beatTimesSec) {
      final x = hitLineX + (bt * 1000 - currentTimeMs) * pxPerMs;
      if (x < 0 || x > sw) continue;
      canvas.drawLine(Offset(x, fretboardTop), Offset(x, fretboardBottom), paint);
    }
  }

  void _drawStrings(Canvas canvas) {
    // Treble string
    final tp = Paint()
      ..shader = LinearGradient(colors: [
        trebleColor.withOpacity(0.05), trebleColor.withOpacity(0.4),
        trebleColor.withOpacity(0.6), trebleColor.withOpacity(0.4),
        trebleColor.withOpacity(0.05),
      ]).createShader(Rect.fromLTWH(0, trebleY - 2, sw, 4));
    canvas.drawRect(Rect.fromLTWH(0, trebleY - 2, sw, 4), tp);

    // Bass string
    final bp = Paint()
      ..shader = LinearGradient(colors: [
        bassColor.withOpacity(0.05), bassColor.withOpacity(0.4),
        bassColor.withOpacity(0.6), bassColor.withOpacity(0.4),
        bassColor.withOpacity(0.05),
      ]).createShader(Rect.fromLTWH(0, bassY - 2, sw, 4));
    canvas.drawRect(Rect.fromLTWH(0, bassY - 2, sw, 4), bp);

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
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.transparent, hitLineColor.withOpacity(0.6),
          hitLineColor, hitLineColor.withOpacity(0.6), Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(hitLineX - 1.5, fretboardTop - sh * 0.03, 3, fretboardH + sh * 0.06));
    canvas.drawRect(
      Rect.fromLTWH(hitLineX - 1.5, fretboardTop - sh * 0.03, 3, fretboardH + sh * 0.06),
      paint,
    );

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

      // Choose appearance based on state
      Color fillColor;
      Color borderColor;
      if (note.isPlayed) {
        fillColor = (note.hitQuality == 'perfect' ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
            .withOpacity(0.4);
        borderColor = fillColor.withOpacity(0.6);
      } else if (note.isMissed) {
        fillColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red.withOpacity(0.3);
      } else {
        fillColor = color.withOpacity(0.2 + 0.4 * proximity);
        borderColor = color.withOpacity(0.5 + 0.5 * proximity);
      }

      // Note body
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: noteW, height: h),
        Radius.circular(h / 2),
      );
      canvas.drawRRect(rrect, Paint()..color = fillColor);
      canvas.drawRRect(rrect, Paint()
        ..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2.5);

      // Glow for close notes
      if (!note.isPlayed && !note.isMissed && proximity > 0.7) {
        canvas.drawRRect(rrect, Paint()
          ..color = color.withOpacity(0.1 * proximity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      }

      // Fret number text
      if (!note.isPlayed && !note.isMissed) {
        final tp = TextPainter(
          text: TextSpan(text: '${note.fret}', style: TextStyle(
            color: Colors.white.withOpacity(0.7 + 0.3 * proximity),
            fontSize: noteH * 0.45, fontWeight: FontWeight.w800,
          )),
          textDirection: TextDirection.ltr,
        )..layout();
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
    canvas.drawCircle(Offset(hitLineX, ballY), ballR * 3, Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Ball
    canvas.drawCircle(Offset(hitLineX, ballY), ballR, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(hitLineX, ballY), ballR * 0.5, Paint()
      ..color = Colors.white.withOpacity(0.9));
  }

  double _stringY(String s) {
    if (s == 'treble') return trebleY;
    if (s == 'both') return (trebleY + bassY) / 2;
    return bassY;
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => old.currentTimeMs != currentTimeMs;
}
