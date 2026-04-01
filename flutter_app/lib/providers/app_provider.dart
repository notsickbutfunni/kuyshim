import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/lesson.dart';
import '../models/game_result.dart';
import '../services/api_service.dart';
import '../constants/lessons.dart';
import '../l10n/strings.dart';

enum AppScreen { onboarding, library, game, tuner, profile, results }

class AppProvider extends ChangeNotifier {
  AppScreen _currentScreen = AppScreen.onboarding;
  User _user = User.guest;
  List<Lesson> _lessons = kAllLessons;
  Lesson? _selectedLesson;
  GameResult? _lastResult;
  bool _backendOnline = false;
  bool _mlOnline = false;
  bool _mlModelLoaded = false;
  AppLang _lang = AppLang.en;

  AppScreen get currentScreen => _currentScreen;
  User get user => _user;
  List<Lesson> get lessons => _lessons;
  Lesson? get selectedLesson => _selectedLesson;
  GameResult? get lastResult => _lastResult;
  bool get backendOnline => _backendOnline;
  bool get mlOnline => _mlOnline;
  bool get mlModelLoaded => _mlModelLoaded;
  AppLang get lang => _lang;
  AppStrings get t => AppStrings.get(_lang);

  void toggleLanguage() {
    switch (_lang) {
      case AppLang.en:
        _lang = AppLang.kz;
        break;
      case AppLang.kz:
        _lang = AppLang.ru;
        break;
      case AppLang.ru:
        _lang = AppLang.en;
        break;
    }
    notifyListeners();
  }

  void navigateTo(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  Future<void> init() async {
    _backendOnline = await ApiService.checkHealth();
    if (_backendOnline) {
      // Check ML service health through the backend proxy
      _checkMlStatus();

      final token = await ApiService.getToken();
      if (token != null) {
        try {
          await _loadLessonsFromBackend();
          _user = User(
            isGuest: false,
            username: 'Logged In User',
            avatar: 'https://picsum.photos/seed/user/200/200',
            level: 5,
            rank: 'Akyn',
            stats: const UserStats(totalPractice: '12h', mastery: 65, streak: 3),
            activity: const [],
          );
          _currentScreen = AppScreen.library;
        } catch (_) {
          await ApiService.clearToken();
          _currentScreen = AppScreen.onboarding;
        }
      }
    }
    notifyListeners();
  }

  /// Check ML service health (non-blocking).
  Future<void> _checkMlStatus() async {
    try {
      final mlHealth = await ApiService.checkMlHealth();
      _mlOnline = mlHealth['status'] == 'ok';
      _mlModelLoaded = mlHealth['model_loaded'] == true;
      notifyListeners();
    } catch (_) {
      _mlOnline = false;
      _mlModelLoaded = false;
    }
  }

  /// Refresh ML status (callable from UI).
  Future<void> refreshMlStatus() async {
    await _checkMlStatus();
  }

  Future<void> _loadLessonsFromBackend() async {
    try {
      final lessonsFromApi = await ApiService.fetchLessons();
      if (lessonsFromApi.isNotEmpty) {
        _lessons = lessonsFromApi.map((l) => Lesson.fromApi(l)).toList();
      }
    } catch (_) {
      _lessons = kAllLessons;
    }
  }

  void startGuest() {
    _lessons = kAllLessons;
    _currentScreen = AppScreen.library;
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    await ApiService.login(username, password);
    _user = User(
      isGuest: false,
      username: username,
      avatar: 'https://picsum.photos/seed/$username/200/200',
      level: 5,
      rank: 'Akyn',
      stats: const UserStats(
        totalPractice: '12h',
        mastery: 65,
        streak: 3,
        avgBpm: 110,
        noteAccuracy: 85,
      ),
      activity: const [
        ActivityEntry(date: '2026-03-01', value: 2),
        ActivityEntry(date: '2026-03-02', value: 1),
        ActivityEntry(date: '2026-03-03', value: 3),
        ActivityEntry(date: '2026-03-04', value: 0),
        ActivityEntry(date: '2026-03-05', value: 2),
      ],
    );
    _currentScreen = AppScreen.library;
    notifyListeners();
    await _loadLessonsFromBackend();
    _checkMlStatus();
    notifyListeners();
  }

  Future<void> register(String username, String email, String password) async {
    await ApiService.register(username, email, password);
    await signIn(username, password);
  }

  void logout() {
    ApiService.clearToken();
    _user = User.guest;
    _lessons = kAllLessons;
    _currentScreen = AppScreen.onboarding;
    notifyListeners();
  }

  Future<void> selectLesson(Lesson lesson) async {
    _selectedLesson = lesson;
    _currentScreen = AppScreen.game;
    notifyListeners();
    if (!_user.isGuest) {
      try {
        await ApiService.updateLessonProgress(int.parse(lesson.id), 'started');
      } catch (_) {}
    }
  }

  /// Called when the game finishes. Submits scores to the backend
  /// and enriches the result with ML-powered analysis data.
  Future<void> finishGame(GameResult result, {Uint8List? audioBytes, String? audioFilename}) async {
    _lastResult = result;
    _currentScreen = AppScreen.results;
    notifyListeners();

    if (_selectedLesson != null && !_user.isGuest && _backendOnline) {
      try {
        final total = result.perfect + result.good + result.miss;
        final gameAccuracy = total > 0
            ? ((result.perfect + result.good * 0.7) / total * 100)
            : 0.0;
        final gameConsistency = total > 0
            ? (result.perfect / total * 100)
            : 0.0;
        // Timing offset: lower miss ratio = better timing
        final gameTimingOffset = total > 0
            ? (result.miss / total * 100)
            : 0.0;

        Map<String, dynamic> scoreResult;

        if (audioBytes != null && audioBytes.isNotEmpty) {
          // Send real audio to ML microservice
          scoreResult = await ApiService.analyzePerformance(
            int.parse(_selectedLesson!.id),
            audioBytes,
            audioFilename ?? 'recording.wav',
          );
        } else {
          // Submit mock score to backend → stores in Performance table
          scoreResult = await ApiService.submitLessonScore(
            int.parse(_selectedLesson!.id),
            accuracy: gameAccuracy,
            timingOffset: gameTimingOffset,
            noteConsistency: gameConsistency,
          );
        }

        // Enrich result with backend ML data
        _lastResult = result.copyWith(
          mlAccuracy: (scoreResult['accuracy'] as num?)?.toDouble(),
          timingOffset: (scoreResult['timing_offset'] as num?)?.toDouble(),
          noteConsistency:
              (scoreResult['note_consistency'] as num?)?.toDouble(),
          mlFinalScore: (scoreResult['final_score'] as num?)?.toDouble(),
          predictedChord: scoreResult['predicted_chord'] as String?,
          referenceChord: scoreResult['reference_chord'] as String?,
          performanceId: scoreResult['performance_id'] ?? scoreResult['id'] as int?,
        );

        // Mark lesson as completed
        await ApiService.updateLessonProgress(
            int.parse(_selectedLesson!.id), 'completed');

        notifyListeners();
      } catch (e) {
        debugPrint('Score submission failed: $e');
        // Score submission failed silently — local result still shown
      }
    }
  }
}
