import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // When running as Flutter Web (Docker/Nginx), use relative URLs
  // so the Nginx reverse proxy forwards requests to the backend.
  // For native mobile builds, use the direct backend URL.
  // For Android emulator use: http://10.0.2.2:8000
  // For iOS simulator / desktop: http://localhost:8000
  static String get _baseUrl => kIsWeb ? '' : 'http://10.0.2.2:8000';
  static const String _tokenKey = 'kui_token';

  // ── Token Management ─────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Helper ───────────────────────────────────────────────
  static Future<http.Response> _apiFetch(
    String path, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$_baseUrl$path');
    final reqHeaders = <String, String>{
      if (headers != null) ...headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: reqHeaders, body: body);
        break;
      case 'PUT':
        response = await http.put(uri, headers: reqHeaders, body: body);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: reqHeaders);
        break;
      default:
        response = await http.get(uri, headers: reqHeaders);
    }

    // If 401 on non-auth endpoint, clear token
    if (response.statusCode == 401 && !path.startsWith('/auth/')) {
      await clearToken();
    }

    return response;
  }

  // ── Health ───────────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final res = await _apiFetch('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── ML Service Health (proxied through backend) ──────────
  static Future<Map<String, dynamic>> checkMlHealth() async {
    try {
      final res = await _apiFetch('/ml/health');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'status': 'unavailable', 'model_loaded': false};
    } catch (_) {
      return {'status': 'unavailable', 'model_loaded': false};
    }
  }

  // ── Auth ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final res = await _apiFetch(
      '/auth/login',
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
    );

    if (res.statusCode != 200) {
      final err = _tryParseJson(res.body);
      throw Exception(err?['detail'] ?? 'Login failed');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await setToken(data['access_token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await _apiFetch(
      '/auth/register',
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      final err = _tryParseJson(res.body);
      throw Exception(err?['detail'] ?? 'Registration failed');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resetPassword(
      String username, String email, String newPassword) async {
    final res = await _apiFetch(
      '/auth/reset-password',
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'new_password': newPassword,
      }),
    );

    if (res.statusCode != 200) {
      final err = _tryParseJson(res.body);
      throw Exception(err?['detail'] ?? 'Password reset failed');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Lessons ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchLessons({String? level}) async {
    final params = level != null ? '?level=$level' : '';
    final res = await _apiFetch('/lessons$params');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch lessons');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> updateLessonProgress(
      int lessonId, String status) async {
    final res = await _apiFetch(
      '/lessons/$lessonId/progress',
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update progress');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitLessonScore(
    int lessonId, {
    required double accuracy,
    required double timingOffset,
    required double noteConsistency,
  }) async {
    final res = await _apiFetch(
      '/lessons/$lessonId/score',
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accuracy': accuracy,
        'timing_offset': timingOffset,
        'note_consistency': noteConsistency,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to submit score');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── ML-Powered Audio Analysis ────────────────────────────
  /// Upload user audio for ML-powered performance analysis.
  /// Sends audio to backend which proxies to ML service.
  /// Returns analysis with accuracy, timing, chord detection, etc.
  static Future<Map<String, dynamic>> analyzePerformance(
    int lessonId,
    Uint8List audioBytes,
    String filename,
  ) async {
    final token = await getToken();
    final uri = Uri.parse('$_baseUrl/lessons/$lessonId/analyze');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: filename,
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      final err = _tryParseJson(res.body);
      throw Exception(err?['detail'] ?? 'Analysis failed');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Performance History ──────────────────────────────────
  /// Fetch user's performance history for a specific lesson.
  static Future<List<Map<String, dynamic>>> fetchPerformances(
      int lessonId) async {
    final res = await _apiFetch('/lessons/$lessonId/performances');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch performances');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Audio URL builder ────────────────────────────────────
  static String getAudioUrl(String level, String audioFile) {
    return '$_baseUrl/static/lessons/$level/${Uri.encodeComponent(audioFile)}';
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
