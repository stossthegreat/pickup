import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/face_geometry.dart';
import '../models/mirror_analysis.dart';

class MirrorApiService {
  static Map<String, dynamic> _geometryToJson(FaceGeometry g) => {
    'canthalTilt':     g.canthalTilt,
    'symmetryScore':   g.symmetryScore,
    'facialThirdTop':  g.facialThirdTop,
    'facialThirdMid':  g.facialThirdMid,
    'facialThirdLow':  g.facialThirdLow,
    'fwhr':            g.fwhr,
    'eyeSpacingRatio': g.eyeSpacingRatio,
    'jawAngle':        g.jawAngle,
    'chinProjection':  g.chinProjection,
  };

  /// Run full scan: analyse + maximize in one round-trip.
  static Future<MirrorAnalysis> scan({
    required Uint8List imageBytes,
    required FaceGeometry geometry,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.backendBaseUrl}/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'imageBase64': base64Encode(imageBytes),
        'geometry':    _geometryToJson(geometry),
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('Backend ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return MirrorAnalysis.fromJson(decoded);
  }
}
