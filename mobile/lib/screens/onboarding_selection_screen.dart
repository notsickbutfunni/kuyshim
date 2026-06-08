import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../widgets/calibration_dialog.dart';

class OnboardingSelectionScreen extends StatefulWidget {
  const OnboardingSelectionScreen({super.key});

  @override
  State<OnboardingSelectionScreen> createState() => _OnboardingSelectionScreenState();
}

class _OnboardingSelectionScreenState extends State<OnboardingSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // If user is already signed in, skip to library
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (!appState.user.isGuest) {
        context.go('/library');
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSelection(bool isNewToDombra) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    if (!mounted) return;

    // Show calibration dialog on first install
    await showCalibrationDialog(context);

    if (!mounted) return;

    if (isNewToDombra) {
      context.go('/game-tutorial');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final screenSize = MediaQuery.of(context).size;
    final sw = screenSize.width;
    final sh = screenSize.height;

    return Scaffold(
      backgroundColor: const Color(0xFF242525),
      body: Stack(
        children: [
          // Background glow
          Center(
            child: Container(
              width: sw * 0.5,
              height: sw * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KColors.emerald.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),


          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header Logo & Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseCtrl.value * 0.05);
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            width: sh * 0.15,
                            height: sh * 0.15,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(sh * 0.03),
                              boxShadow: [
                                BoxShadow(
                                  color: KColors.emerald.withOpacity(0.2),
                                  blurRadius: sh * 0.05,
                                  spreadRadius: sh * 0.01,
                                ),
                              ],
                            ),
                            child: SvgPicture.asset(
                              'assets/dombra_icon_green.svg',
                              width: sh * 0.15,
                              height: sh * 0.15,
                            ),
                          ),
                        ).animate().scale(duration: 800.ms, curve: Curves.easeOut).fadeIn(),
                        
                        SizedBox(width: sw * 0.03),
                        
                        Text(
                          'Kuyshim',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: sh * 0.1,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 800.ms),
                      ],
                    ),
                    
                    SizedBox(height: sh * 0.12),
                    
                    // Options
                    SizedBox(
                      width: sw * 0.6,
                      child: ElevatedButton(
                        onPressed: () => _handleSelection(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KColors.emerald,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: sh * 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(sh * 0.04),
                          ),
                          elevation: 8,
                          shadowColor: KColors.emerald.withOpacity(0.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.newToDombra,
                              style: TextStyle(
                                fontSize: sh * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ).animate().slideY(begin: 0.5, end: 0, delay: 400.ms, duration: 600.ms, curve: Curves.easeOutCubic).fadeIn(delay: 400.ms),
                    
                    SizedBox(height: sh * 0.05),
                    
                    SizedBox(
                      width: sw * 0.6,
                      child: OutlinedButton(
                        onPressed: () => _handleSelection(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
                          padding: EdgeInsets.symmetric(vertical: sh * 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(sh * 0.04),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.alreadyKnowDombra,
                              style: TextStyle(
                                fontSize: sh * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ).animate().slideY(begin: 0.5, end: 0, delay: 500.ms, duration: 600.ms, curve: Curves.easeOutCubic).fadeIn(delay: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
