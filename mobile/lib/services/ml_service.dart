/// ML Service — communicates with the Dombra ML FastAPI microservice.
/// Handles chord/fret prediction from audio bytes.
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class MlServiceUrl {
  static const String baseUrl = 'http://127.0.0.1:8001';
}

/// Result of a chord prediction from the ML model.
class ChordPrediction {
  final String predictedClass;
  final double confidence;
  final Map<String, double> top5;

  ChordPrediction({
    required this.predictedClass,
    required this.confidence,
    required this.top5,
  });

  factory ChordPrediction.fromJson(Map<String, dynamic> json) {
    final top5Raw = json['top_5'] as Map<String, dynamic>? ?? {};
    final top5 = top5Raw.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return ChordPrediction(
      predictedClass: json['predicted_class'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      top5: top5,
    );
  }
}

class MlService {
  final String _baseUrl = MlServiceUrl.baseUrl;

  /// Check if the ML service is running and the model is loaded.
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['model_loaded'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Send recorded audio bytes to the ML /predict endpoint.
  /// Returns a [ChordPrediction] with the detected chord and confidence.
  Future<ChordPrediction> predictChord(Uint8List audioBytes) async {
    final uri = Uri.parse('$_baseUrl/predict');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio', // field name expected by the API
        audioBytes,
        filename: 'recording.wav',
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 15),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final detail = _extractDetail(response.body);
      throw MlServiceException('Prediction failed: $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChordPrediction.fromJson(data);
  }

  String _extractDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

class MlServiceException implements Exception {
  final String message;
  MlServiceException(this.message);

  @override
  String toString() => 'MlServiceException: $message';
}
