import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class KuiModel {
  final int id;
  final String title;
  final String artist;
  final String audioUrl;
  final String imageUrl;
  final String jsonUrl;

  KuiModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.imageUrl,
    required this.jsonUrl,
  });

  factory KuiModel.fromJson(Map<String, dynamic> json) => KuiModel(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        audioUrl: json['audio_url'],
        imageUrl: json['image_url'],
        jsonUrl: json['json_file'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'audio_url': audioUrl,
        'image_url': imageUrl,
        'json_file': jsonUrl,
      };
}

class SyncService {
  final String _baseUrl = ApiServiceUrl.baseUrl;
  final Dio _dio = Dio();
  static const String _kuisCacheKey = 'cached_kuis_list';

  /// 1. Fetch Remote List and Compare / Cache
  Future<List<KuiModel>> syncMetadataAndJson() async {
    try {
      // Read saved language and send Accept-Language header
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('kui_lang') ?? 'kz';
      final acceptLang = lang == 'kz' ? 'kk' : lang;
      final response = await _dio.get(
        '$_baseUrl/kuis',
        options: Options(headers: {'Accept-Language': acceptLang}),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<KuiModel> remoteKuis = data.map((json) => KuiModel.fromJson(json)).toList();

        // Save metadata to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kuisCacheKey, jsonEncode(remoteKuis.map((k) => k.toJson()).toList()));

        // Sync JSON Beatmaps
        await _syncJsonBeatmaps(remoteKuis);

        return remoteKuis;
      } else {
        return _getLocalKuis();
      }
    } catch (e) {
      print('Sync failed: $e');
      return _getLocalKuis();
    }
  }

  Future<List<KuiModel>> _getLocalKuis() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kuisCacheKey);
    if (cached != null) {
      final List<dynamic> data = jsonDecode(cached);
      return data.map((json) => KuiModel.fromJson(json)).toList();
    }
    return [];
  }

  /// 2. Download missing JSON maps
  Future<void> _syncJsonBeatmaps(List<KuiModel> kuis) async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${dir.path}/kui_maps');
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }

    for (final kui in kuis) {
      if (kui.jsonUrl.isEmpty) continue;
      
      final fileName = kui.jsonUrl.split('/').last;
      if (fileName.isEmpty) continue;

      final file = File('${mapsDir.path}/$fileName');
      
      if (!await file.exists()) {
        try {
          // Assuming jsonUrl is a full url or relative to your CDN/backend
          String downloadUrl = kui.jsonUrl;
          if (!downloadUrl.startsWith('http')) {
            downloadUrl = 'http://192.168.1.72:8000$downloadUrl';
          }
          await _dio.download(downloadUrl, file.path);
        } catch (e) {
          print('Failed to download JSON for ${kui.title}: $e');
        }
      }
    }
  }

  /// 3. Download MP3 on Demand
  Future<File?> getOrDownloadAudio(KuiModel kui, Function(double) onProgress) async {
    if (kui.audioUrl.isEmpty) return null;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final fileName = kui.audioUrl.split('/').last;
    if (fileName.isEmpty) return null;

    final file = File('${audioDir.path}/$fileName');

    if (await file.exists()) {
      return file;
    }

    try {
      String downloadUrl = kui.audioUrl;
      if (!downloadUrl.startsWith('http')) {
          downloadUrl = 'http://192.168.1.72:8000$downloadUrl';
      }

      await _dio.download(
        downloadUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );
      return file;
    } catch (e) {
      print('Failed to download audio for ${kui.title}: $e');
      return null;
    }
  }
}
