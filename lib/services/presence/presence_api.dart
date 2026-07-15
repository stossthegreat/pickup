import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/auralay_dev_flags.dart';
import '../auralay_api.dart' show AuralayApiError;

/// Thin HTTP client for /v1/presence/score — the voice-side scorer
/// for the PRESENCE curriculum.
///
/// The frontend records the apprentice delivering the lesson's target
/// line, packs the audio + lesson context into a multipart POST, and
/// receives back the Whisper transcript, computed WPM, four
/// voice-side dimension scores (0..1 each), and a one-line fatal-flaw
/// stamp in Lucien's voice for the share card.
///
/// The remaining three dimensions — eye contact, tension, and the
/// charisma composite — are computed locally in the session screen.
abstract final class PresenceApi {
  static String get _base => AuralayDevFlags.apiBaseUrl;
  static bool get available => AuralayDevFlags.hasBackend;

  static Future<PresenceScoreResponse> score({
    required File   audioFile,
    required int    audioMs,
    required String lessonId,
    required String targetLine,
    required String deliveryCue,
    required int    targetWpmLow,
    required int    targetWpmHigh,
    required bool   warmthExpected,
  }) async {
    if (!available) {
      throw const AuralayApiError(
        'backend_not_configured',
        'AURALAY_API env var not set at build time — Presence '
        'scoring needs the Railway backend.',
      );
    }
    final uri = Uri.parse('$_base/v1/presence/score');
    final req = http.MultipartRequest('POST', uri)
      ..fields['lessonId']       = lessonId
      ..fields['targetLine']     = targetLine
      ..fields['deliveryCue']    = deliveryCue
      ..fields['targetWpmLow']   = targetWpmLow.toString()
      ..fields['targetWpmHigh']  = targetWpmHigh.toString()
      ..fields['warmthExpected'] = warmthExpected ? 'true' : 'false'
      ..fields['audioMs']        = audioMs.toString()
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw AuralayApiError(
        'http_${streamed.statusCode}',
        body.length > 1200
            ? '${body.substring(0, 1200)}…(${body.length} chars)'
            : body,
      );
    }
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final scores = (json['scores'] as Map?) ?? const {};
      return PresenceScoreResponse(
        transcript:     (json['transcript'] as String?) ?? '',
        wpm:            (json['wpm']        as num?)?.toInt() ?? 0,
        fatalFlaw:      (json['fatalFlaw']  as String?) ?? '',
        voiceAuthority: _double(scores['voiceAuthority']),
        pace:           _double(scores['pace']),
        confidence:     _double(scores['confidence']),
        warmth:         _double(scores['warmth']),
      );
    } catch (e) {
      throw AuralayApiError('bad_response',
          'Could not decode presence score payload: $e');
    }
  }

  static double _double(dynamic v) =>
      v is num ? v.toDouble().clamp(0.0, 1.0) : 0.0;
}

class PresenceScoreResponse {
  final String transcript;
  final int    wpm;
  final String fatalFlaw;
  final double voiceAuthority;
  final double pace;
  final double confidence;
  final double warmth;

  const PresenceScoreResponse({
    required this.transcript,
    required this.wpm,
    required this.fatalFlaw,
    required this.voiceAuthority,
    required this.pace,
    required this.confidence,
    required this.warmth,
  });
}
