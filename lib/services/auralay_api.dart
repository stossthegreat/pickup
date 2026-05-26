import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/auralay_dev_flags.dart';

/// Thin HTTP client over the AURALAY Railway backend.
///
/// Two endpoints today:
///   * [diabloTurn]    POST /v1/diablo/turn   — audio → transcript + Diablo
///                                              reply + base64 mp3
///   * [scoreRhetoric] POST /v1/rhetoric/score — transcript → 6-dim score +
///                                              one-line verdict
///
/// Both throw [AuralayApiError] on non-200 responses. Call sites should
/// catch and fall back to the local stubs so the app never goes dark when
/// the backend is offline.
class AuralayApi {
  static String get _base => AuralayDevFlags.apiBaseUrl;
  static bool get available => AuralayDevFlags.hasBackend;

  // ─── POST /v1/diablo/turn ─────────────────────────────────────────────

  static Future<DiabloTurnResponse> diabloTurn({
    required File audioFile,
    required String mode,
    required Map<String, dynamic> context,
    required List<DiabloHistoryEntry> history,
  }) async {
    if (!available) {
      throw const AuralayApiError('backend_not_configured',
          'AURALAY_API was not set at build time.');
    }
    final uri = Uri.parse('$_base/v1/diablo/turn');
    final req = http.MultipartRequest('POST', uri)
      ..fields['mode']    = mode
      ..fields['context'] = jsonEncode(context)
      ..fields['history'] = jsonEncode(
          history.map((h) => {'role': h.role, 'text': h.text}).toList())
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw AuralayApiError('http_${streamed.statusCode}', body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return DiabloTurnResponse(
      transcript: (json['transcript'] as String?) ?? '',
      reply:      (json['reply'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
      mode:       (json['mode'] as String?) ?? mode,
    );
  }

  // ─── POST /v1/diablo/speak ────────────────────────────────────────────
  //
  // Pure TTS. Hands a string to the backend, gets back Diablo's voice
  // performing it. Used for lesson intros, model-answer playback, the
  // verdict line, the scene opener — anywhere the app needs her voice
  // without sending a user recording first.

  /// Throws [AuralayApiError] on any non-200 / exception, so the caller
  /// can surface it in the debug panel. Returns null only when the
  /// backend isn't configured at all (offline build).
  static Future<Uint8List?> diabloSpeak({
    required String text,
    required String mode,
  }) async {
    if (!available) {
      throw const AuralayApiError(
        'backend_not_configured',
        'AURALAY_API env var not set at build time — TTS unavailable.',
      );
    }
    final uri = Uri.parse('$_base/v1/diablo/speak');
    final http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'text': text, 'mode': mode}),
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AuralayApiError('network_error', e.toString());
    }
    if (resp.statusCode != 200) {
      throw AuralayApiError(
        'http_${resp.statusCode}',
        resp.body.length > 800
            ? '${resp.body.substring(0, 800)}…(${resp.body.length} chars)'
            : resp.body,
      );
    }
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return _decodeAudio(json['audio'] as String?);
    } catch (e) {
      throw AuralayApiError('bad_response',
          'Could not decode audio payload: $e');
    }
  }

  // ─── POST /v1/rhetoric/drill ──────────────────────────────────────────
  //
  // Low-latency rhetoric path. ONE round trip:
  //   audio in → transcribe + score + verdict + TTS audio out
  //
  // Saves ~1.5s vs calling /diablo/turn + /rhetoric/score back-to-back.

  static Future<DrillResponse?> rhetoricDrill({
    required File audioFile,
    required String lessonId,
  }) async {
    if (!available) return null;
    final uri = Uri.parse('$_base/v1/rhetoric/drill');
    final req = http.MultipartRequest('POST', uri)
      ..fields['lessonId'] = lessonId
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        return null;
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final dimsRaw = (json['dimensions'] as Map?) ?? {};
      final dims = dimsRaw.map((k, v) => MapEntry(
            k as String,
            (v is num) ? v.toInt() : 0,
          ));
      return DrillResponse(
        transcript: (json['transcript'] as String?) ?? '',
        dimensions: dims,
        verdict:    (json['verdict']    as String?) ?? '',
        total:      (json['total']      as num?)?.toInt() ??
            dims.values.fold<int>(0, (a, b) => a + b),
        audioBytes: _decodeAudio(json['audio'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── POST /v1/rhetoric/score ──────────────────────────────────────────
  //
  // Text-only fallback. Used by the rizz verdict path where we already
  // have the transcript stitched from multiple turns.

  static Future<ScoreResponse> scoreRhetoric({
    required String lessonId,
    required String transcript,
  }) async {
    if (!available) {
      throw const AuralayApiError('backend_not_configured',
          'AURALAY_API was not set at build time.');
    }
    final uri = Uri.parse('$_base/v1/rhetoric/score');
    final resp = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'lessonId': lessonId, 'transcript': transcript}),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw AuralayApiError('http_${resp.statusCode}', resp.body);
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final dimsRaw = (json['dimensions'] as Map?) ?? {};
    final dims = dimsRaw.map((k, v) => MapEntry(
          k as String,
          (v is num) ? v.toInt() : 0,
        ));
    return ScoreResponse(
      dimensions: dims,
      verdict: (json['verdict'] as String?) ?? '',
      total: (json['total'] as num?)?.toInt() ??
          dims.values.fold<int>(0, (a, b) => a + b),
    );
  }

  static Uint8List? _decodeAudio(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

class DiabloTurnResponse {
  final String transcript;        // what Whisper heard
  final String reply;             // Diablo's text reply
  final Uint8List? audioBytes;    // mp3 bytes — null if TTS failed
  final String mode;

  const DiabloTurnResponse({
    required this.transcript,
    required this.reply,
    required this.audioBytes,
    required this.mode,
  });
}

class DiabloHistoryEntry {
  final String role;   // "user" | "diablo"
  final String text;
  const DiabloHistoryEntry({required this.role, required this.text});
}

class DrillResponse {
  final String transcript;
  final Map<String, int> dimensions;
  final String verdict;
  final int total;
  final Uint8List? audioBytes;
  const DrillResponse({
    required this.transcript,
    required this.dimensions,
    required this.verdict,
    required this.total,
    required this.audioBytes,
  });
}

class ScoreResponse {
  final Map<String, int> dimensions;
  final String verdict;
  final int total;

  const ScoreResponse({
    required this.dimensions,
    required this.verdict,
    required this.total,
  });
}

class AuralayApiError implements Exception {
  final String code;
  final String message;
  const AuralayApiError(this.code, this.message);
  @override
  String toString() => 'AuralayApiError($code): $message';
}
