/// API service — backend communication for authentication, lesson data, and progress.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiServiceUrl {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
}

class ApiService {
  final String _baseUrl = ApiServiceUrl.baseUrl;
  static const String _tokenKey = 'auth_token';

  // ── Helper ────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool isJson = false}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Auth ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: await _headers(isJson: true),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Login failed: ${response.statusCode}';
      try {
        final err = jsonDecode(response.body);
        if (err['detail'] != null) {
          errorMessage = err['detail'];
        }
      } catch (_) {
        // Could not parse error body, keep generic message
      }
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['access_token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, data['access_token']);
    }
    return data;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: await _headers(isJson: true),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = 'Registration failed: ${response.statusCode}';
      try {
        final err = jsonDecode(response.body);
        if (err['detail'] != null) {
          errorMessage = err['detail'];
        }
      } catch (_) {
        // Could not parse error body, keep generic message
      }
      throw Exception(errorMessage);
    }
    return login(username, password); // Auto login
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> resetPassword(String username, String email, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: await _headers(isJson: true),
      body: jsonEncode({
        'username': username,
        'email': email,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Password reset failed';
      try {
        final err = jsonDecode(response.body);
        if (err['detail'] != null) {
          errorMessage = err['detail'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Lessons ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchLessons({String? level}) async {
    final params = level != null ? '?level=$level' : '';
    final response = await http.get(
      Uri.parse('$_baseUrl/lessons$params'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch lessons');
    }

    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateLessonProgress(
    String lessonId,
    String progressStatus,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/lessons/$lessonId/progress'),
      headers: await _headers(isJson: true),
      body: jsonEncode({'status': progressStatus}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update progress');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitLessonScore(
    String lessonId, {
    required double accuracy,
    required double timingOffset,
    required double noteConsistency,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/lessons/$lessonId/score'),
      headers: await _headers(isJson: true),
      body: jsonEncode({
        'accuracy': accuracy,
        'timing_offset': timingOffset,
        'note_consistency': noteConsistency,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to submit score');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Kuis (unauthenticated) ────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchKuis() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/kuis'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch kuis: ${response.statusCode}');
    }

    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Health ────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'), headers: await _headers())
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Tuner Results ────────────────────────────────────────
  /// Save a tuner chord recognition result to the backend.
  Future<void> saveTunerResult({
    required String predictedClass,
    required double confidence,
    Map<String, double>? top5,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/tuner/result'),
        headers: await _headers(isJson: true),
        body: jsonEncode({
          'predicted_class': predictedClass,
          'confidence': confidence,
          if (top5 != null) 'top_5': top5,
        }),
      );
    } catch (_) {
      // Silently fail — tuner result saving is non-critical
    }
  }

  /// Fetch the user's tuner recognition history.
  Future<List<Map<String, dynamic>>> fetchTunerHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tuner/results'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
