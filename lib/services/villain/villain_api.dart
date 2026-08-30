import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config/auralay_dev_flags.dart';
import '../auralay_api.dart' show AuralayApiError;
import '../install_id.dart';

/// Thin HTTP client for the /v1/villain/* family.
///
/// Three Arena calls + one Council call. All return text + base64 mp3
/// audio decoded into bytes the caller can hand straight to
/// audioplayers via BytesSource.
///
///   sceneOpen   — Diabla speaks the scene's opening line (TTS only,
///                 no GPT call).
///   sceneTurn   — Apprentice audio in → Diabla's next in-scene line
///                 + audio out.
///   sceneCoach  — Lucien's 4-section tactical cut-in + audio out.
///                 The reply text ends with the literal [COACH_DONE]
///                 sentinel so the client knows the cut-in is over.
///   council     — Apprentice text in → Lucien's chat reply +
///                 audio out (his voice).
abstract final class VillainApi {
  static String get _base => AuralayDevFlags.apiBaseUrl;
  static bool get available => AuralayDevFlags.hasBackend;

  // ─── Arena ─────────────────────────────────────────────────────────────

  /// Lucien's cinematic narration that opens the scene. Returns 4-6
  /// short sentences in his voice setting the temperature, placing
  /// the apprentice in the room, warning him about her, and stating
  /// the goal — then audio in his ash voice.
  static Future<VillainTurn> sceneIntro({
    required String sceneId,
    bool creator = false,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/scene/intro');
    final resp = await http.post(
      uri,
      headers: BackendHeaders.json,
      body: jsonEncode({'sceneId': sceneId, 'creator': creator}),
    ).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) throw _err(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: '',
      reply:      (json['reply'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  static Future<VillainTurn> sceneOpen({
    required String sceneId,
    required String opening,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/scene/open');
    final resp = await http.post(
      uri,
      headers: BackendHeaders.json,
      body: jsonEncode({'sceneId': sceneId, 'opening': opening}),
    ).timeout(const Duration(seconds: 45));
    if (resp.statusCode != 200) throw _err(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: '',
      reply:      (json['reply'] as String?) ?? opening,
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  static Future<VillainTurn> sceneTurn({
    required String sceneId,
    required File audioFile,
    required List<VillainHistoryEntry> history,
    String? memoryBlock,
    bool creator = false,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/scene/turn');
    final req = http.MultipartRequest('POST', uri)
      ..fields['sceneId'] = sceneId
      ..fields['creator'] = creator.toString()
      ..fields['history'] = jsonEncode(
          history.map((h) => {'role': h.role, 'text': h.text}).toList())
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    if (memoryBlock != null && memoryBlock.isNotEmpty) {
      req.fields['memoryBlock'] = memoryBlock;
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw AuralayApiError('http_${streamed.statusCode}', body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: (json['transcript'] as String?) ?? '',
      reply:      (json['reply'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  static Future<VillainTurn> sceneCoach({
    required String sceneId,
    required String lastApprenticeLine,
    required String lastDiablaLine,
    String? memoryBlock,
    bool creator = false,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/scene/coach');
    final resp = await http.post(
      uri,
      headers: BackendHeaders.json,
      body: jsonEncode({
        'sceneId':            sceneId,
        'lastApprenticeLine': lastApprenticeLine,
        'lastDiablaLine':     lastDiablaLine,
        'creator':            creator,
        if (memoryBlock != null && memoryBlock.isNotEmpty)
          'memoryBlock': memoryBlock,
      }),
    ).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) throw _err(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: '',
      reply:      (json['reply'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  // ─── Council ───────────────────────────────────────────────────────────

  /// Voice-in variant of /council. Apprentice records audio; backend
  /// Whisper-transcribes, runs the Lucien council prompt, returns both
  /// the transcript AND Lucien's reply text + audio.
  static Future<VillainTurn> councilVoice({
    required File audioFile,
    required List<VillainHistoryEntry> history,
    String? memoryBlock,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/council/voice');
    final req = http.MultipartRequest('POST', uri)
      ..fields['history'] = jsonEncode(
          history.map((h) => {'role': h.role, 'text': h.text}).toList())
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    if (memoryBlock != null && memoryBlock.isNotEmpty) {
      req.fields['memoryBlock'] = memoryBlock;
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw AuralayApiError('http_${streamed.statusCode}', body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: (json['transcript'] as String?) ?? '',
      reply:      (json['reply']      as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  /// Streaming voice-in variant of /council. Emits a sequence of
  /// [CouncilStreamEvent]s: first a `transcript`, then a run of
  /// `delta`s as Lucien's words generate token-by-token, then a
  /// single `done` carrying the full reply + mp3 audio bytes. On any
  /// backend error, a `error` event is emitted (and the stream ends).
  /// Backed by the /council/stream NDJSON endpoint.
  static Stream<CouncilStreamEvent> councilVoiceStream({
    required File audioFile,
    required List<VillainHistoryEntry> history,
    String? memoryBlock,
    bool creator = false,
  }) async* {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/council/stream');
    final req = http.MultipartRequest('POST', uri)
      ..fields['creator'] = creator.toString()
      ..fields['history'] = jsonEncode(
          history.map((h) => {'role': h.role, 'text': h.text}).toList())
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    if (memoryBlock != null && memoryBlock.isNotEmpty) {
      req.fields['memoryBlock'] = memoryBlock;
    }

    final client = http.Client();
    try {
      final streamed =
          await client.send(req).timeout(const Duration(seconds: 90));
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw AuralayApiError('http_${streamed.statusCode}', body);
      }
      var buffer = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer += chunk;
        int nl;
        while ((nl = buffer.indexOf('\n')) >= 0) {
          final line = buffer.substring(0, nl).trim();
          buffer = buffer.substring(nl + 1);
          if (line.isEmpty) continue;
          final ev = _parseStreamLine(line);
          if (ev != null) yield ev;
        }
      }
      final tail = buffer.trim();
      if (tail.isNotEmpty) {
        final ev = _parseStreamLine(tail);
        if (ev != null) yield ev;
      }
    } finally {
      client.close();
    }
  }

  static CouncilStreamEvent? _parseStreamLine(String line) {
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      return CouncilStreamEvent(
        type:       (obj['type'] as String?) ?? '',
        text:       (obj['text'] as String?) ?? (obj['reply'] as String?) ?? '',
        audioBytes: _decodeAudio(obj['audio'] as String?),
        detail:     (obj['detail'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<VillainTurn> council({
    required String text,
    required List<VillainHistoryEntry> history,
    String? memoryBlock,
    bool creator = false,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/council');
    final resp = await http.post(
      uri,
      headers: BackendHeaders.json,
      body: jsonEncode({
        'text':    text,
        'history': history.map((h) => {'role': h.role, 'text': h.text}).toList(),
        'creator': creator,
        if (memoryBlock != null && memoryBlock.isNotEmpty)
          'memoryBlock': memoryBlock,
      }),
    ).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) throw _err(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return VillainTurn(
      transcript: '',
      reply:      (json['reply'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  /// Scores a finished free-flow conversation. [transcript] is the full
  /// back-and-forth as {role: "her"|"user", text}. Returns Lucien's
  /// /10 verdict + the deadly line + voiced audio.
  static Future<FreeFlowScore> freeflowScore({
    required List<Map<String, String>> transcript,
    required String vibeLabel,
    bool creator = false,
  }) async {
    _requireBackend();
    final uri = Uri.parse('$_base/v1/villain/freeflow/score');
    final resp = await http.post(
      uri,
      headers: BackendHeaders.json,
      body: jsonEncode({
        'transcript': transcript,
        'vibeLabel':  vibeLabel,
        'creator':    creator,
      }),
    ).timeout(const Duration(seconds: 45));
    if (resp.statusCode != 200) throw _err(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    // Five dimension scores (0-100): confidence · presence · game ·
    // humor · listening. Null when the model didn't return them.
    Map<String, int>? dims;
    final rawDims = json['dimensions'];
    if (rawDims is Map) {
      dims = {
        for (final k in const ['confidence', 'presence', 'game', 'humor', 'listening'])
          k: (((rawDims[k] as num?)?.toInt() ?? 0).clamp(0, 100)).toInt(),
      };
    }
    return FreeFlowScore(
      score:      (json['score'] as num?)?.toInt() ?? 0,
      verdict:    (json['verdict'] as String?) ?? '',
      landed:     (json['landed'] as String?) ?? '',
      flopped:    (json['flopped'] as String?) ?? '',
      line:       (json['line'] as String?) ?? '',
      dimensions: dims,
      breakdown:  (json['breakdown'] as String?) ?? '',
      audioBytes: _decodeAudio(json['audio'] as String?),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  static void _requireBackend() {
    if (!available) {
      throw const AuralayApiError(
        'backend_not_configured',
        'AURALAY_API env var not set at build time — Villain mode '
        'needs the Railway backend.',
      );
    }
  }

  static AuralayApiError _err(http.Response resp) => AuralayApiError(
        'http_${resp.statusCode}',
        resp.body.length > 1200
            ? '${resp.body.substring(0, 1200)}…(${resp.body.length} chars)'
            : resp.body,
      );

  static Uint8List? _decodeAudio(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

class VillainTurn {
  final String transcript;        // Whisper transcript of user audio (turn only)
  final String reply;             // What Diabla or Lucien said
  final Uint8List? audioBytes;    // mp3 of the reply, null if TTS failed
  const VillainTurn({
    required this.transcript,
    required this.reply,
    required this.audioBytes,
  });
}

class VillainHistoryEntry {
  /// For Arena scenes: "user" | "diabla"
  /// For Council chat:  "user" | "lucien"
  final String role;
  final String text;
  const VillainHistoryEntry({required this.role, required this.text});
}

/// Lucien's end-of-free-flow scorecard.
class FreeFlowScore {
  /// THE BACKEND'S OWN SCALE, AND IT IS NOT THE ONE WE SHOW.
  ///
  /// freeflowScorePrompt asks for `"score": <integer 0-10>` while asking
  /// for its five dimensions 0-100 in the same breath. That is the
  /// backend's contract and it is left alone — see [outOf100] for the
  /// number the app actually displays.
  final int score;            // 0..10
  final String verdict;       // the deadly one-liner
  final String landed;        // what worked
  final String flopped;       // what killed it
  final String line;          // the line he should have used
  /// Five dimension scores 0-100: confidence · presence · game · humor ·
  /// listening. Null when the backend didn't return them.
  final Map<String, int>? dimensions;
  /// Short Lucien breakdown across the five dimensions.
  final String breakdown;
  final Uint8List? audioBytes;
  /// ── THE NUMBER THE APP SHOWS, OUT OF 100 ─────────────────────────
  ///
  /// The scorecard was changed to read "/ 100" and the raw 0-10 was
  /// left underneath it, so a 6 rendered as "6 / 100" when it meant 60.
  /// Frontend bug, not the grader.
  ///
  /// Fixed by DERIVING the total from the five dimensions rather than
  /// multiplying the coarse one by ten. They are already 0-100, they are
  /// what the Progress tab keeps, and weighting them is exactly how the
  /// chat side builds its number (see supabase/_shared/grade-chat.ts) —
  /// so voice and text are now the same number built the same way, and
  /// a man gets 63 instead of a rounded 60.
  ///
  /// Falls back to score * 10 when the grader returned no dimensions,
  /// which is the old behaviour and never wrong, only coarser.
  int get outOf100 {
    final d = dimensions;
    if (d == null || d.isEmpty) return (score * 10).clamp(0, 100);
    const weights = <String, double>{
      'confidence': 0.26,
      'presence': 0.20,
      'game': 0.24,
      'humor': 0.16,
      'listening': 0.14,
    };
    var sum = 0.0, used = 0.0;
    weights.forEach((axis, w) {
      final v = d[axis];
      if (v != null) {
        sum += v * w;
        used += w;
      }
    });
    if (used == 0) return (score * 10).clamp(0, 100);
    return (sum / used).round().clamp(0, 100);
  }

  const FreeFlowScore({
    required this.score,
    required this.verdict,
    required this.landed,
    required this.flopped,
    required this.line,
    this.dimensions,
    this.breakdown = '',
    required this.audioBytes,
  });
}

/// One event off the /council/stream NDJSON pipe.
///   type "transcript" — text is the Whisper transcript of the user.
///   type "delta"      — text is the next chunk of Lucien's reply.
///   type "done"       — text is the full reply; audioBytes is the mp3.
///   type "error"      — detail describes the failure.
class CouncilStreamEvent {
  final String type;
  final String text;
  final Uint8List? audioBytes;
  final String detail;
  const CouncilStreamEvent({
    required this.type,
    required this.text,
    required this.audioBytes,
    required this.detail,
  });
}
