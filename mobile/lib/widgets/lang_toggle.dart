/// Language toggle widget — cycles through KZ, EN, RU.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class LangToggle extends StatelessWidget {
  const LangToggle({super.key});

  String _getFlag(String lang) {
    switch (lang) {
      case 'kz':
        return '🇰🇿';
      case 'en':
        return '🇬🇧';
      case 'ru':
        return '🇷🇺';
      default:
        return '🇰🇿';
    }
  }

  @override
  Widget build(BuildContext context) {
    final langService = context.watch<LanguageService>();

    return GestureDetector(
      onTap: () => langService.toggleLang(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getFlag(langService.lang),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              langService.lang.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
