import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _pulseController.repeat(reverse: false);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isLandscape = constraints.maxWidth > constraints.maxHeight;

            // Strict Rule 4: Adaptable scrolling layout wrapping EVERYTHING
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Stack(
                    children: [
                      // Kazakh ornaments background
                      Positioned.fill(child: _buildOrnaments(context)),
                      
                      Padding(
                        padding: const EdgeInsets.all(16.0), // Minimal padding exception
                        child: _buildMainContent(context, isLandscape),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isLandscape) {
    if (isLandscape) {
      // Landscape Layout -> Left: Nav + Card, Right: Circle Button
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopNav(context),
                _buildBottomCard(context),
              ],
            ),
          ),
          const SizedBox(width: 24), // Minimal constraint exception
          Expanded(
            flex: 1,
            child: Center(
              child: _buildCenterButton(context),
            ),
          ),
        ],
      );
    } else {
      // Portrait Layout -> Top: Nav, Center: Button, Bottom: Card
      return Column(
        children: [
          _buildTopNav(context),
          Expanded(
            flex: 3,
            child: Center(
              child: _buildCenterButton(context),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomCard(context),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTopNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Music Recognition',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          onPressed: () {
             // Future history connection
          },
        ),
      ],
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
           return FractionallySizedBox(
             widthFactor: 0.6,
             child: AspectRatio(
               aspectRatio: 1.0,
               child: CustomPaint(
                  painter: PulseVisualizerPainter(
                    animationValue: _pulseController.value,
                    isListening: _isListening,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          KColors.emerald.withOpacity(0.2),
                          KColors.amber.withOpacity(0.2),
                          KColors.emerald.withOpacity(0.2),
                        ],
                        transform: GradientRotation(_pulseController.value * 2 * math.pi),
                      ),
                      boxShadow: _isListening ? [
                        BoxShadow(color: KColors.emerald.withOpacity(0.4), blurRadius: 40, spreadRadius: 10 * _pulseController.value),
                        BoxShadow(color: KColors.amber.withOpacity(0.2), blurRadius: 60, spreadRadius: 20 * _pulseController.value),
                      ] : [],
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Icon(
                            Icons.audiotrack_rounded, // Stylized music recognition icon
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
               ),
             ),
           );
        },
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1.0, // Ensures width behaves properly without hardcoded width
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Prevents blowing out proportions vertically
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Flexible(
                   child: FittedBox(
                     fit: BoxFit.scaleDown,
                     child: Text(
                       _isListening ? "Recognizing Kui..." : "Waiting for sound...",
                       style: GoogleFonts.inter(
                         color: Colors.white,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                 ),
                 if (_isListening) ...[
                   const SizedBox(height: 16), // Minimal spacing exception
                   const Flexible(
                     child: FractionallySizedBox(
                       widthFactor: 0.15,
                       child: AspectRatio(
                         aspectRatio: 1.0,
                         child: CircularProgressIndicator(
                           valueColor: AlwaysStoppedAnimation<Color>(KColors.amber),
                           strokeWidth: 3,
                         ),
                       ),
                     ),
                   ),
                 ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrnaments(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: FractionallySizedBox(
            widthFactor: 0.25,
            heightFactor: 0.25,
            child: CustomPaint(painter: OrnamentPainter()),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(math.pi),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(math.pi), // Flips correctly to the bottom right
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.25,
              child: CustomPaint(painter: OrnamentPainter()),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Custom Painters for Dynamic Real-Time Audio Visualizer and Kazakh Patterns
// ──────────────────────────────────────────────────────────────────────────

class PulseVisualizerPainter extends CustomPainter {
  final double animationValue;
  final bool isListening;

  PulseVisualizerPainter({required this.animationValue, required this.isListening});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final numBars = 64;
    for (int i = 0; i < numBars; i++) {
       final angle = (i * 2 * math.pi) / numBars;
       
       // Real-time dynamic visualizer feel using sine wave generation over time
       final wave1 = math.sin(angle * 4 + animationValue * 2 * math.pi);
       final wave2 = math.cos(angle * 7 - animationValue * 4 * math.pi);
       final noise = (wave1 + wave2) / 2; // Output varies cleanly between -1 and 1
       
       // Bar extends and shrinks based on simulated frequency peaks
       final barLength = radius * 0.15 + (noise * radius * 0.15);
       
       final innerRadius = radius * 1.08;
       final outerRadius = innerRadius + barLength.clamp(0.0, radius * 0.4);

       final startPoint = Offset(
         center.dx + innerRadius * math.cos(angle),
         center.dy + innerRadius * math.sin(angle)
       );
       final endPoint = Offset(
         center.dx + outerRadius * math.cos(angle),
         center.dy + outerRadius * math.sin(angle)
       );

       // Alternate dynamic visualizer bars matching 'KColors'
       paint.color = i % 2 == 0 
           ? KColors.emerald.withOpacity(0.7) 
           : KColors.amber.withOpacity(0.7);
       paint.strokeWidth = radius * 0.04;

       canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PulseVisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isListening != isListening;
  }
}

class OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.min(size.width, size.height) * 0.05;

    final path = Path();
    path.moveTo(size.width * 0.1, 0);
    path.lineTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.9, size.width * 0.3, size.height * 0.9);
    path.lineTo(size.width, size.height * 0.9);
    
    final innerPath = Path();
    innerPath.moveTo(size.width * 0.3, 0);
    innerPath.lineTo(size.width * 0.3, size.height * 0.5);
    innerPath.quadraticBezierTo(size.width * 0.3, size.height * 0.7, size.width * 0.5, size.height * 0.7);
    innerPath.lineTo(size.width, size.height * 0.7);

    canvas.drawPath(path, paint);
    canvas.drawPath(innerPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
