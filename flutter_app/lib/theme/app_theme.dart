import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const scaffoldBg = Color(0xFF0F1115);
  static const cardBg = Color(0xFF1A1C23);
  static const emerald = Color(0xFF10B981);
  static const emerald500 = Color(0xFF10B981);
  static const amber = Color(0xFFD4A843);
  static const gold = Color(0xFFF0C850);
  static const violet = Color(0xFF8B5CF6);
  static const purple = Color(0xFF7C3AED);
}

ThemeData appTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.emerald,
      secondary: AppColors.amber,
      surface: AppColors.cardBg,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.emerald.withValues(alpha: 0.5)),
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  );
}

TextStyle serifBold(double size, {Color? color}) {
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
    color: color ?? Colors.white,
  );
}
