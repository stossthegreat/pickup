import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../data/rizz_lines.dart';
import 'screenshot_ocr_service.dart';

/// One rewritten reply suggestion. [tag] is the small-caps move
/// label that explains WHY the line works — SELF-AWARE OPEN,
/// FRAME CHECK, PUSH-PULL, MISINTERPRETATION, etc. Mirrors the
/// labels on the curated arsenal cards so the user learns the
/// move, not just the words.
class RizzReply {
  final String text;
  final String tag;
  const RizzReply({required this.text, required this.tag});
}

/// Five tonal vibes the user can request. AUTO lets the model pick
/// based on her cadence. The other four are hard pulls.
enum RizzVibe { auto, funny, flirty, smooth, bold }

extension RizzVibeLabel on RizzVibe {
  String get label => switch (this) {
        RizzVibe.auto   => 'AUTO',
        RizzVibe.funny  => 'FUNNY',
        RizzVibe.flirty => 'FLIRTY',
        RizzVibe.smooth => 'SMOOTH',
        RizzVibe.bold   => 'BOLD',
      };

  String get directive => switch (this) {
        RizzVibe.auto   => 'auto — pick whichever move actually pulls best',
        RizzVibe.funny  => 'funny — short, witty, makes her screenshot it',
        RizzVibe.flirty => 'flirty — push-pull / heat, never thirsty',
        RizzVibe.smooth => 'smooth — high-agency, confident, scarce',
        RizzVibe.bold   => 'bold — frame-check / disqualifier, calls her out',
      };
}

/// Rizz God — generates 3 ranked reply options for a message she sent.
///
/// Strategy:
///   1. Calls /rizz/reply on the Mirrorly backend with {her, vibe, ctx}.
///   2. If the route doesn't exist yet (404) or returns malformed JSON,
///      falls back to /chat with a heavy system preamble that instructs
///      GPT to output ONLY the JSON shape we need.
///   3. If both backend paths fail, returns three lines from the curated
///      arsenal matched against the requested vibe — guarantees the
///      "no trash" rule even on a dead backend.
class RizzReplyService {
  static Future<List<RizzReply>> generate({
    String herMessage = '',
    Uint8List? screenshotBytes,
    required RizzVibe vibe,
    String context = '',
    String scenario = '',
  }) async {
    var her = herMessage.trim();
    final ctx = context.trim();
    final scn = scenario.trim();
    final hasImage = screenshotBytes != null && screenshotBytes.isNotEmpty;
    if (her.isEmpty && !hasImage && scn.isEmpty) return _fallbackFromArsenal(vibe);

    // ── SILENT OCR ────────────────────────────────────────────────────
    // When a screenshot is supplied, extract the chat text on-device
    // via ML Kit BEFORE hitting the backend. The user never sees this
    // step (no "running OCR…" pill) — they just see results. Sending
    // the extracted text instead of the raw image bytes means the
    // backend doesn't need GPT vision; the existing /chat endpoint
    // (text in, JSON out) handles it natively.
    if (hasImage && her.isEmpty) {
      final ocrText = await _ocrSilently(screenshotBytes);
      if (ocrText.isNotEmpty) her = ocrText;
    }

    final imageB64 = hasImage ? base64Encode(screenshotBytes) : null;

    // 1) Try the dedicated rizz endpoint first. Future-route; the
    // payload here is the clean shape that backend ought to expose.
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.backendBaseUrl}/rizz/reply'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'her':      her,
              'vibe':     vibe.name,
              'ctx':      ctx,
              'scenario': scn,
              if (imageB64 != null) 'imageBase64': imageB64,
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final parsed = _parseReplies(res.body);
        if (parsed.length >= 3) return parsed.take(3).toList();
      }
    } catch (_) {/* fall through */}

    // 2) Fall back to /chat. GPT-4o vision reads the screenshot
    // directly when imageBase64 is included — no OCR step needed.
    try {
      final messageText = _buildPrompt(her, vibe, ctx,
          scenario: scn, hasScreenshot: hasImage);
      final res = await http
          .post(
            Uri.parse('${ApiConfig.backendBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                {'role': 'user', 'text': messageText},
              ],
              'face': const <String, dynamic>{},
              'mode': 'rizz_reply',
              if (imageB64 != null) 'imageBase64': imageB64,
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (body['reply'] as String?) ?? '';
        final parsed = _parseReplies(reply);
        if (parsed.length >= 3) return parsed.take(3).toList();
      }
    } catch (_) {/* fall through */}

    // 3) Final fallback — curated lines that match the vibe so the
    // user is never stranded on a dead backend.
    return _fallbackFromArsenal(vibe);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /// Write the in-memory screenshot bytes to a tmp file (ML Kit needs
  /// a path, not bytes), run text recognition on the tmp file, then
  /// delete it. Returns the joined text from the last few chat
  /// bubbles, ready to feed straight into the RIZZ GOD prompt. Any
  /// failure (no text, ML Kit error, file write fails) returns ''
  /// so the caller can fall through to the image-bytes path.
  static Future<String> _ocrSilently(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rizz_ocr_'
          '${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      try {
        final text = await ScreenshotOcrService.extractRecent(path);
        return text;
      } finally {
        // Best-effort cleanup; don't block on failure.
        try { await file.delete(); } catch (_) {}
      }
    } catch (_) {
      return '';
    }
  }

  /// Parse the model's reply into [RizzReply]s. The /chat endpoint is
  /// a general chat surface, not a structured-output API, so models
  /// sometimes wrap the JSON in fences ("```json…```"), chat preamble
  /// ("Sure! Here are three options: …"), or fall out of JSON entirely
  /// and return a numbered list. We try every format we've seen so the
  /// UI always lands real rizz instead of falling through to the
  /// curated arsenal fallback.
  static List<RizzReply> _parseReplies(String raw) {
    if (raw.trim().isEmpty) return const [];

    // 1) Try strict JSON array — the format we ask for in the prompt.
    final jsonResult = _tryParseJsonArray(raw);
    if (jsonResult.length >= 3) return jsonResult;

    // 2) Try line-by-line — numbered list, bullets, or plain lines.
    final lineResult = _tryParseLines(raw);
    if (lineResult.length >= 3) return lineResult;

    // Return whatever we got even if < 3 — the caller falls back to
    // the curated arsenal when this list is shorter than 3.
    return jsonResult.isNotEmpty ? jsonResult : lineResult;
  }

  static List<RizzReply> _tryParseJsonArray(String raw) {
    final start = raw.indexOf('[');
    final end   = raw.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    final slice = raw.substring(start, end + 1);
    try {
      final decoded = jsonDecode(slice) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => RizzReply(
                text: ((e['text'] ?? e['line'] ?? e['reply']) as String?)
                        ?.trim() ??
                    '',
                tag: ((e['tag'] ?? e['move'] ?? 'RIZZ') as String?)
                        ?.toString()
                        .toUpperCase() ??
                    'RIZZ',
              ))
          .where((r) => r.text.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Last-ditch parser — pull up to 3 reply lines out of:
  ///   1. "ngl your aura is unforgivable"
  ///   2. "we'd date six months..."
  ///   3. ...
  /// or
  ///   • line one
  ///   • line two
  /// or just plain newline-separated quoted strings.
  static List<RizzReply> _tryParseLines(String raw) {
    final out = <RizzReply>[];
    final stripped = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    // Strip leading list-marker characters and any trailing tag/punc.
    final numbered = RegExp(r'^(?:\s*(?:\d+[\.\)]|[-*•])\s*)?');
    for (final rawLine in stripped.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(numbered, '');
      // Drop wrapping quotes.
      if ((line.startsWith('"') && line.endsWith('"')) ||
          (line.startsWith('"') && line.endsWith('"'))) {
        line = line.substring(1, line.length - 1).trim();
      }
      // Skip lines that look like chat preamble or labels.
      final lower = line.toLowerCase();
      if (lower.length > 140) continue;
      if (lower.startsWith('here') ||
          lower.startsWith('sure') ||
          lower.startsWith('option') ||
          lower.startsWith('safest') ||
          lower.startsWith('boldest') ||
          lower.startsWith('reply')) {
        continue;
      }
      if (line.isEmpty) continue;
      out.add(RizzReply(text: line, tag: 'RIZZ'));
      if (out.length == 3) break;
    }
    return out;
  }

  /// THE RIZZ GOD — elite system prompt embedded as a user message
  /// (since /chat is chat-style). Treats the model as the friend who
  /// has actually slept with the prom queen, not a corporate chatbot.
  /// Gives it room to be charming, sensual, vulnerable, dominant —
  /// whatever the moment calls for — within a tight quality bar.
  ///
  /// When [hasScreenshot] is true, the model reads the attached image
  /// (Hinge/Tinder/iMessage) and identifies HER most recent bubble
  /// natively. No OCR. When [scenario] is set, that biases the move
  /// pool (PLAN A DATE → DATE PROPOSAL emphasis, etc).
  static String _buildPrompt(String her, RizzVibe vibe, String ctx,
      {String scenario = '', bool hasScreenshot = false}) {
    final taskHeader = hasScreenshot
        ? 'The attached image is a chat screenshot (Hinge / Tinder / '
          'iMessage / Instagram DM). Identify HER most recent message — '
          'the LAST bubble that is not from the user. Treat that as HER.'
        : (her.isEmpty
              ? 'No specific message yet — the user is opening cold or '
                'planning their first move.'
              : 'HER LAST MESSAGE: """$her"""');

    final scenarioLine = scenario.isEmpty
        ? ''
        : '\nSCENARIO: "$scenario" — bias your three replies toward '
          'lines that move the conversation through this scenario.';

    return '''
You are RIZZ — the man whose texts make her phone go off on the bedside
table at 11pm. Not a chatbot. Not a coach with a worksheet. The friend
who has actually slept with the prom queen, the editor of GQ, and the
girl every guy in his year wanted. He is writing the message the user
should send, NOT the message the user is brave enough to send.

THE TRUTH ABOUT WOMEN 18-30 IN 2026 (you understand this in your bones):

- She gets 40 boring openers a day. She has stopped reading the first
  six words. You have to disrupt or you are noise.
- She feels DESIRE when she catches herself smiling at her phone
  ALONE. Your job is to be the message that makes her group-chat go
  off — "girls he just said..."
- She loses interest the second she senses effort. Confidence reads
  as ease, not as edge. Tryhard kills faster than dry.
- She has a "type" she tells her friends about and a type she actually
  responds to. The second is calmer, more amused, harder to impress.
- She likes a man who doesn't NEED her to like him. Scarcity beats
  enthusiasm every time. Wanting is sexy; needing is not.
- She wants to feel SEEN, not flattered. A specific observation beats
  ten compliments.
- The SCREENSHOT TEST is everything. If she would share the line with
  her group chat with no commentary, it pulled. If she would react
  "ok", it failed.

YOUR REPERTOIRE — the moves that pull in 2026:

- COMPRESSED CINEMA       implies a whole relationship in 12 words
                          "we'd date six months, fight at a wedding,
                          write songs about each other"
- ARCHETYPE READ          tells her what kind of girl she is, accurately
                          "you give 'her parents don't approve' energy"
- INTIMATE PRESUMPTION    acts like you already know her well
                          "be honest, are you the friend everyone has
                          a crush on"
- VULNERABLE FLEX         admits a "weakness" that's actually a flex
                          "i'm normally calm but you make me text
                          like i'm 19"
- MISINTERPRETATION       misreads her in a flirty direction
                          "saying 'lol' is a marriage proposal where
                          i'm from"
- FRAME CHECK             assumes the outcome, forces her to disagree
                          "tell me you have a bf so i can move on
                          with my life"
- PUSH-PULL               playfully pushes her away, she has to chase
                          "we're not going to work out. i can't
                          promise that"
- HIGH-AGENCY             scarce, secure, decisive
                          "give me your number before i lose interest
                          in my own bit"
- DOMESTIC PROJECTION     paints a future scene she has to react to
                          "be honest — what would we fight about in
                          three months"
- INAPPROPRIATE COMPLIMENT  too-specific to be generic, almost rude
                            "your photos commit acts of psychological
                            warfare"
- DATE PROPOSAL           moves it offline directly
                          "let's argue about something over wine"

HARD RULES — the no-trash rule (your reputation is at stake):

- ≤ 14 words per line. Phone-fatigue threshold.
- No 2014 PUA. No "you'd be cute if". Negs read mean now, not bold.
- No essays. No back-to-back questions stacked together.
- No emojis unless they are load-bearing. Lowercase mostly.
- Specific > generic. Observation > question.
- Sensual is fine. Suggestive is fine if she opened that door first.
  Explicitly sexual is for AFTER the date.
- Confident, not arrogant. Charming, not slick. Direct, not desperate.
- BOLDEST line should pass this test: "if she screenshotted this to
  her group chat, would they say 'answer him RIGHT NOW' or 'block'?"
  It must be the first.

VIBE the user chose: ${vibe.directive}

$taskHeader$scenarioLine
${ctx.isEmpty ? '' : 'CONTEXT (one line of background): "$ctx"'}

WRITE THREE replies, ranked SAFEST → MIDDLE → BOLDEST.
Each gets a small-caps MOVE LABEL drawn from your repertoire
(COMPRESSED CINEMA · ARCHETYPE READ · INTIMATE PRESUMPTION ·
VULNERABLE FLEX · MISINTERPRETATION · FRAME CHECK · PUSH-PULL ·
HIGH-AGENCY · DOMESTIC PROJECTION · INAPPROPRIATE COMPLIMENT ·
DATE PROPOSAL · SELF-AWARE OPEN · META-FLIRT · REFRAME · TEASE).

OUTPUT — return ONLY this JSON array. No fences. No prose. No
commentary. The user is reading this output INSIDE an iMessage-style
bubble UI — every character that is not the line itself is noise:

[
  {"text": "...", "tag": "MOVE LABEL"},
  {"text": "...", "tag": "MOVE LABEL"},
  {"text": "...", "tag": "MOVE LABEL"}
]
''';
  }

  /// Final fallback when the backend is down. Picks three lines from the
  /// curated arsenal that match the vibe. Guarantees the "no trash" rule
  /// because everything here was hand-picked.
  static List<RizzReply> _fallbackFromArsenal(RizzVibe vibe) {
    // Map vibe → which two categories to draw from.
    final slugs = switch (vibe) {
      RizzVibe.funny  => ['tease', 'openers'],
      RizzVibe.flirty => ['heat', 'tease'],
      RizzVibe.smooth => ['heat', 'close'],
      RizzVibe.bold   => ['cold', 'close'],
      RizzVibe.auto   => ['openers', 'tease'],
    };
    final pool = <RizzLine>[];
    for (final cat in RizzArsenal.categories) {
      if (slugs.contains(cat.slug)) pool.addAll(cat.lines);
    }
    pool.shuffle();
    return pool
        .take(3)
        .map((l) => RizzReply(text: l.text, tag: l.tag))
        .toList();
  }
}
