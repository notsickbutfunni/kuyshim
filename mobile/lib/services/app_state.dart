/// App state — central ChangeNotifier for user, lessons, and navigation state.
library;
import 'dart:io' as java_io;
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/lesson_model.dart';
import '../models/game_models.dart';
import '../constants/lessons.dart' as lesson_data;
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/level_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  final LevelManager levelManager = LevelManager();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  ConnectivityService? _connectivity;
  ConnectivityService? get connectivity => _connectivity;

  AppUser _user = AppUser.guest;
  List<Lesson> _lessons = [];
  Lesson? _selectedLesson;
  GameResult? _lastResult;
  bool _isOnline = false;
  bool _backendOnline = false;
  String _gameMode = 'competitive'; // 'competitive' or 'training'

  AppUser get user => _user;
  List<Lesson> get lessons => _lessons;
  Lesson? get selectedLesson => _selectedLesson;
  GameResult? get lastResult => _lastResult;
  bool get isOnline => _isOnline;
  bool get backendOnline => _backendOnline;
  String get gameMode => _gameMode;
  bool get isTrainingMode => _gameMode == 'training';

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
        avatar: profile['avatar_url'] != null ? 'http://192.168.1.72:8000${profile['avatar_url']}' : 'https://picsum.photos/seed/${profile['username'] ?? 'guest'}/200/200',
        level: profile['level'] ?? 1,
        rank: profile['rank'] ?? 'Student',
        stats: UserStats(
          totalPractice: profile['total_practice'] ?? '0h',
          mastery: profile['mastery_score'] ?? 0,
          streak: profile['streak_days'] ?? 0,
        ),
        activity: const [],
        badges: const [],
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

    if (_isOnline && _backendOnline) {
      // 1. Fetch all kuis from the unauthenticated endpoint (works for guests too)
      try {
        final kuisData = await api.fetchKuis();
        final remoteKuis = kuisData.map((json) => Lesson.fromJson(json)).toList();
        
        final localIds = currentLessons.map((e) => e.id).toSet();
        for (final kui in remoteKuis) {
          if (!localIds.contains(kui.id)) {
            currentLessons.add(kui);
          }
        }
      } catch (e) {
        print('Failed to fetch kuis: $e');
      }

      // 2. If logged in, also fetch lesson progress to update statuses
      if (!_user.isGuest) {
        try {
          final remoteData = await api.fetchLessons();
          final remoteLessons = remoteData.map((json) => Lesson.fromJson(json)).toList();
          
          // Update progress status for lessons that match
          for (final remote in remoteLessons) {
            final idx = currentLessons.indexWhere((l) => l.id == remote.id);
            if (idx != -1 && remote.progressStatus != null) {
              currentLessons[idx] = currentLessons[idx].copyWith(
                progressStatus: remote.progressStatus,
              );
            }
          }
        } catch (e) {
          print('Failed to fetch lesson progress: $e');
        }
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

  Future<void> signIn(String username, String password) async {
    await api.login(username, password);
    _user = AppUser(
      isGuest: false,
      username: username,
      avatar: 'https://picsum.photos/seed/$username/200/200',
      level: 5,
      rank: 'Akyn',
      stats: const UserStats(
        totalPractice: '0h',
        mastery: 0,
        streak: 0,
      ),
      activity: const [],
      badges: const [],
    );
    await refreshStats();
    _refreshLessons();
    notifyListeners();
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        // NOTE: For Flutter Web, you MUST provide 'clientId'.
        // For Android (without google-services.json), you MUST provide 'serverClientId' with the Web Client ID.
        // Replace this placeholder with your actual Web Client ID from Google Cloud Console.
        const webClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: 'YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com');
        
        await _googleSignIn.initialize(
          clientId: webClientId,
          serverClientId: webClientId,
        );
        _googleSignInInitialized = true;
      }
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      _user = AppUser(
        isGuest: false,
        username: googleUser.displayName ?? 'Google User',
        avatar: googleUser.photoUrl ?? 'https://picsum.photos/seed/${googleUser.email}/200/200',
        level: 1,
        rank: 'Student',
        stats: const UserStats(
          totalPractice: '0h',
          mastery: 0,
          streak: 0,
        ),
        activity: const [],
        badges: const [],
      );

      // Attempt to sync with backend using Google ID as dummy password
      if (_backendOnline) {
        String safeUsername = (googleUser.displayName ?? 'user').replaceAll(' ', '').toLowerCase();
        if (safeUsername.isEmpty) safeUsername = 'user${googleUser.id.substring(0, 5)}';
        try {
          await api.register(safeUsername, googleUser.email, googleUser.id);
        } catch (e) {
          try {
            await api.login(safeUsername, googleUser.id);
          } catch (_) {}
        }
        await refreshStats();
      }

      _refreshLessons();
      notifyListeners();
    } catch (e) {
      throw Exception('Google Sign In failed: $e');
    }
  }

  Future<void> refreshStats() async {
    if (_user.isGuest) return;
    try {
      final statsData = await api.fetchUserStats();
      
      final activity = (statsData['activity'] as List).map((e) => ActivityEntry(
        date: e['date'],
        value: e['value'],
      )).toList();

      final badges = (statsData['achievements'] as List).map<AppBadge>((e) => AppBadge(
        key: e['key'],
        unlockedAt: e['unlocked_at'],
      )).toList();

      final stats = UserStats(
        totalPractice: statsData['totalPractice'],
        mastery: statsData['mastery'],
        streak: statsData['streak'],
        avgBpm: statsData['avgBpm'],
        noteAccuracy: statsData['noteAccuracy'],
      );

      _user = _user.copyWith(
        stats: stats,
        activity: activity,
        badges: badges,
      );
      notifyListeners();
    } catch (e) {
      print('Failed to load user stats: $e');
    }
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
      badges: const [],
    );
    await refreshStats();
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

  // ── Profile Updates ────────────────────────────────────────
  Future<void> updateUsername(String newUsername) async {
    final response = await api.updateProfile(newUsername);
    _user = _user.copyWith(username: response['username']);
    notifyListeners();
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    await api.updatePassword(currentPassword, newPassword);
  }

  Future<void> uploadAvatar(java_io.File file) async {
    final response = await api.uploadAvatar(file);
    if (response['avatar_url'] != null) {
      _user = _user.copyWith(avatar: 'http://192.168.1.72:8000${response['avatar_url']}');
      notifyListeners();
    }
  }

  /// Select a lesson to play.
  Future<void> selectLesson(Lesson lesson, {String mode = 'competitive'}) async {
    _selectedLesson = lesson;
    _gameMode = mode;
    notifyListeners();
  }

  /// Called when game finishes.
  Future<void> finishGame(GameResult result) async {
    _lastResult = result;
    if (!_user.isGuest && _selectedLesson != null && _gameMode == 'competitive') {
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
