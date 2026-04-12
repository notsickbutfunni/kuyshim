/// Ornamental border painter — Kazakh ornament SVG-like pattern.
/// Used in the GameScreen for decorative side borders.
import 'package:flutter/material.dart';
import 'dart:math' as math;

class OrnamentBorderPainter extends CustomPainter {
  final bool isLeft;

  OrnamentBorderPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final circlePaint = Paint()..style = PaintingStyle.fill;

    final patternCount = (size.height / 40).floor();

    for (int i = 0; i < patternCount; i++) {
      final t = i / patternCount;
      final opacity = (0.1 + 0.5 * math.sin(t * math.pi)).clamp(0.1, 0.6);

      paint.color = const Color(0xFFD4A843).withOpacity(opacity);
      circlePaint.color = const Color(0xFFD4A843).withOpacity(opacity * 0.6);

      final xOffset = isLeft ? 8.0 : 16.0;
      final yOffset = i * 40.0;

      // Diamond shape
      final path = Path();
      path.moveTo(xOffset + 12, yOffset);
      path.quadraticBezierTo(xOffset + 24, yOffset + 10, xOffset + 12, yOffset + 20);
      path.quadraticBezierTo(xOffset, yOffset + 10, xOffset + 12, yOffset);
      canvas.drawPath(path, paint);

      // Center circle
      canvas.drawCircle(Offset(xOffset + 12, yOffset + 10), 2, circlePaint);

      // Arrow below
      final arrowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFD4A843).withOpacity(opacity * 0.4);

      final arrowPath = Path();
      arrowPath.moveTo(xOffset + 6, yOffset + 20);
      arrowPath.lineTo(xOffset + 12, yOffset + 28);
      arrowPath.lineTo(xOffset + 18, yOffset + 20);
      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OrnamentBorder extends StatelessWidget {
  final bool isLeft;

  const OrnamentBorder({super.key, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: CustomPaint(
        painter: OrnamentBorderPainter(isLeft: isLeft),
        child: const SizedBox.expand(),
      ),
    );
  }
}
