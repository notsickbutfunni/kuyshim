/// Language service — provides translations and language toggle.
/// Supports 3 languages: Kazakh, English, Russian.
library;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/strings.dart';

class LanguageService extends ChangeNotifier {
  static const String _storageKey = 'kui_lang';
  static const List<String> _langCycle = ['kz', 'en', 'ru'];

  String _lang = 'kz'; // Default to Kazakh
  AppStrings _t = kz;

  String get lang => _lang;
  AppStrings get t => _t;

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && allStrings.containsKey(saved)) {
      _lang = saved;
      _t = allStrings[_lang]!;
      notifyListeners();
    }
  }

  Future<void> toggleLang() async {
    final currentIndex = _langCycle.indexOf(_lang);
    final nextIndex = (currentIndex + 1) % _langCycle.length;
    _lang = _langCycle[nextIndex];
    _t = allStrings[_lang]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _lang);
    notifyListeners();
  }

  Future<void> setLang(String newLang) async {
    if (allStrings.containsKey(newLang)) {
      _lang = newLang;
      _t = allStrings[_lang]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _lang);
      notifyListeners();
    }
  }
}
