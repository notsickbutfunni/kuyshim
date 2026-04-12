/// App state — central ChangeNotifier for user, lessons, and navigation state.
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/lesson_model.dart';
import '../models/game_models.dart';
import '../constants/lessons.dart' as lesson_data;
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/level_manager.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  final LevelManager levelManager = LevelManager();

  ConnectivityService? _connectivity;
  ConnectivityService? get connectivity => _connectivity;

  AppUser _user = AppUser.guest;
  List<Lesson> _lessons = [];
  Lesson? _selectedLesson;
  GameResult? _lastResult;
  bool _isOnline = false;
  bool _backendOnline = false;

  AppUser get user => _user;
  List<Lesson> get lessons => _lessons;
  Lesson? get selectedLesson => _selectedLesson;
  GameResult? get lastResult => _lastResult;
  bool get isOnline => _isOnline;
  bool get backendOnline => _backendOnline;

  /// Set connectivity service reference (called from main).
  void setConnectivity(ConnectivityService service) {
    _connectivity = service;
    _isOnline = service.isOnline;
    service.addListener(_onConnectivityChanged);
    _refreshLessons();
  }

  void _onConnectivityChanged() {
    final wasOnline = _isOnline;
    _isOnline = _connectivity?.isOnline ?? false;
    if (wasOnline != _isOnline) {
      _checkBackendHealth();
      _refreshLessons();
      notifyListeners();
    }
  }

  Future<void> init() async {
    await levelManager.init();
    await _checkBackendHealth();
    
    // Automatically try to get profile if session exists
    try {
      final profile = await api.getProfile();
      _user = AppUser(
        isGuest: false,
        username: profile['username'] ?? 'User',
        avatar: profile['avatar_url'] ?? 'https://picsum.photos/seed/user/200/200',
        level: profile['level'] ?? 1,
        rank: profile['rank'] ?? 'Student',
        stats: UserStats(
          totalPractice: profile['total_practice'] ?? '0h',
          mastery: profile['mastery_score'] ?? 0,
          streak: profile['streak_days'] ?? 0,
        ),
        activity: const [],
      );
    } catch (_) {
      // Not logged in or backend down
    }

    _refreshLessons();
    notifyListeners();
  }

  Future<void> _checkBackendHealth() async {
    if (!_isOnline) {
      _backendOnline = false;
    } else {
      _backendOnline = await api.checkHealth();
    }
    notifyListeners();
  }

  /// Refresh available lessons based on current state.
  Future<void> _refreshLessons() async {
    List<Lesson> currentLessons = List.from(lesson_data.offlineLessons);

    if (_isOnline && !_user.isGuest && _backendOnline) {
      try {
        final remoteData = await api.fetchLessons();
        final remoteLessons = remoteData.map((json) => Lesson.fromJson(json)).toList();
        
        // Merge offline and newly fetched remote lessons 
        // Avoid duplicate IDs if the backend returns lessons we already have locally
        final localIds = currentLessons.map((e) => e.id).toSet();
        for (final remoteInfo in remoteLessons) {
          if (!localIds.contains(remoteInfo.id)) {
            currentLessons.add(remoteInfo);
          }
        }
      } catch (_) {
        // If fetch fails, we just keep the offline lessons
      }
    }

    _lessons = currentLessons;
    notifyListeners();
  }

  /// Start as a guest.
  void startGuest() {
    _refreshLessons();
    notifyListeners();
  }

  /// Sign in with backend.
  Future<void> signIn(String username, String password) async {
    await api.login(username, password);
    _user = AppUser(
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
    _refreshLessons();
    notifyListeners();
  }

  /// Register with backend.
  Future<void> register(String username, String email, String password) async {
    await api.register(username, email, password);
    _user = AppUser(
      isGuest: false,
      username: username,
      avatar: 'https://picsum.photos/seed/$username/200/200',
      level: 1,
      rank: 'Student',
      stats: const UserStats(
        totalPractice: '0h',
        mastery: 0,
        streak: 0,
      ),
      activity: const [],
    );
    _refreshLessons();
    notifyListeners();
  }

  /// Log out and reset state.
  Future<void> logout() async {
    await api.logout();
    _user = AppUser.guest;
    _refreshLessons();
    notifyListeners();
  }

  /// Select a lesson to play.
  Future<void> selectLesson(Lesson lesson) async {
    _selectedLesson = lesson;
    notifyListeners();
  }

  /// Called when game finishes.
  Future<void> finishGame(GameResult result) async {
    _lastResult = result;
    if (!_user.isGuest && _selectedLesson != null) {
      try {
        await api.submitLessonScore(
          _selectedLesson!.id,
          accuracy: result.accuracy.toDouble(),
          timingOffset: 0.0,
          noteConsistency: 1.0,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivity?.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
