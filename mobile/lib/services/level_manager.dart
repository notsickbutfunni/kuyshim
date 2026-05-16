/// LevelManager — resolves audio sources for lessons.
/// Handles local assets, cached files, and Backend HTTP downloads.
library;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

import '../models/lesson_model.dart';
import 'api_service.dart';

/// Represents a resolved audio source ready for playback.
class AudioSource {
  final AudioSourceType type;
  final String path;

  const AudioSource({required this.type, required this.path});
}

enum AudioSourceType {
  /// Bundled in app assets (e.g., 'audio/file.mp3')
  asset,

  /// Cached on device filesystem
  cachedFile,

  /// Needs download from Backend Server
  remote,
}

class LevelManager extends ChangeNotifier {
  static const String _cacheDirName = 'kuyshim_audio_cache';

  String? _cacheDir;

  /// Initialize — pre-compute cache directory.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = '${dir.path}/$_cacheDirName';
    final cacheDir = Directory(_cacheDir!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  /// Get the cache directory path.
  String get cacheDirPath => _cacheDir ?? '';

  /// Resolve how to play a lesson's audio.
  /// Returns an [AudioSource] with type and path.
  Future<AudioSource> resolveAudio(Lesson lesson) async {
    // 1. Local asset — always available
    if (lesson.storageType == StorageType.local && lesson.audioFile != null) {
      return AudioSource(
        type: AudioSourceType.asset,
        path: 'audio/${lesson.audioFile}',
      );
    }

    // 2. Check cache
    if (lesson.audioFile != null) {
      final cacheKey = _getCacheKey(lesson.audioFile!);
      final cached = await _getCachedPath(cacheKey);
      if (cached != null) {
        return AudioSource(
          type: AudioSourceType.cachedFile,
          path: cached,
        );
      }
    }

    // 3. Remote — needs download
    final remoteUrl = _buildRemoteUrl(lesson);
    return AudioSource(
      type: AudioSourceType.remote,
      path: remoteUrl,
    );
  }

  /// Check if a lesson's audio is available offline (local or cached).
  Future<bool> isAvailableOffline(Lesson lesson) async {
    if (lesson.storageType == StorageType.local) return true;
    if (lesson.audioFile == null) return false;
    final cacheKey = _getCacheKey(lesson.audioFile!);
    final cached = await _getCachedPath(cacheKey);
    return cached != null;
  }

  /// Download a lesson's audio from Backend Server and cache it.
  /// Returns the local file path after download.
  /// [onProgress] callback provides download progress (0.0 - 1.0).
  Future<String> downloadAndCache(
    Lesson lesson, {
    Function(double)? onProgress,
  }) async {
    if (lesson.audioFile == null) {
      throw Exception('No audio file configured for lesson ${lesson.id}');
    }

    await init(); // Ensure cache dir exists

    final remoteUrl = _buildRemoteUrl(lesson);
    final cacheKey = _getCacheKey(lesson.audioFile!);
    final localPath = '$_cacheDir/$cacheKey';
    final localFile = File(localPath);

    // If already cached, return immediately
    if (await localFile.exists()) {
      return localPath;
    }

    // Download with progress via http
    final request = http.Request('GET', Uri.parse(remoteUrl));
    final response = await http.Client().send(request);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download audio: ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    int bytesTransferred = 0;
    
    final sink = localFile.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesTransferred += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(bytesTransferred / contentLength);
      }
    }
    await sink.close();

    return localPath;
  }

  /// Check if a specific file is cached.
  Future<bool> isCached(String audioFile) async {
    final cacheKey = _getCacheKey(audioFile);
    final cached = await _getCachedPath(cacheKey);
    return cached != null;
  }

  /// Clear a specific cached audio file.
  Future<void> clearCache(String audioFile) async {
    if (_cacheDir == null) return;
    final cacheKey = _getCacheKey(audioFile);
    final file = File('$_cacheDir/$cacheKey');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clear all cached audio files.
  Future<void> clearAllCache() async {
    if (_cacheDir == null) return;
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }

  /// Get total cache size in bytes.
  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ── Private helpers ────────────────────────────────────────

  /// Build the correct remote URL for a lesson's audio.
  /// Handles: full URLs, server-relative paths, and plain filenames.
  String _buildRemoteUrl(Lesson lesson) {
    final audioFile = lesson.audioFile ?? '';
    // Already a full URL (http:// or https://)
    if (audioFile.startsWith('http://') || audioFile.startsWith('https://')) {
      return audioFile;
    }
    // Server-relative path like /static/audio/file.mp3
    if (audioFile.startsWith('/')) {
      final baseHost = ApiServiceUrl.baseUrl.replaceAll('/api', '');
      return '$baseHost$audioFile';
    }
    // Plain filename — construct the old-style URL
    return '${ApiServiceUrl.baseUrl}/static/lessons/${lesson.level}/${Uri.encodeComponent(audioFile)}';
  }

  /// Extract a safe filename for caching from any audio URL/path.
  String _getCacheKey(String audioFile) {
    if (audioFile.startsWith('http://') || audioFile.startsWith('https://')) {
      return Uri.parse(audioFile).pathSegments.last;
    }
    return audioFile.split('/').last;
  }

  /// Returns the cached file path if it exists, null otherwise.
  Future<String?> _getCachedPath(String audioFile) async {
    if (_cacheDir == null) await init();
    final path = '$_cacheDir/$audioFile';
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }
}
