import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_service.dart';

/// One graded text conversation.
class ChatResult {
  final int score; // 0..100 — the real number, not a flat +50
  final Map<String, int> rubric; // axis → 0..100
  final int best;
  final int attempts;
  final int average;
  final bool isBest;
  const ChatResult({
    required this.score,
    required this.rubric,
    required this.best,
    required this.attempts,
    required this.average,
    required this.isBest,
  });
}

/// THE TEXT RUBRIC'S AXES, AND THEIR LABELS.
///
/// Must stay in step with CHAT_AXES in
/// supabase/functions/_shared/grade-chat.ts — that function decides
/// them and this is only how they are spelled on screen.
///
/// They live here rather than at each call site because every screen
/// that shows a text score has to pass them to RizzOffReveal, whose
/// defaults are the VOICE five. Onboarding's first rep forgot, so it
/// looked up confidence/flow/wit/recovery/close against a rubric that
/// has none of them and rendered five zeros.
const kChatAxes = <String>[
  'opening',
  'relevance',
  'personality',
  'momentum',
  'restraint',
];

const kChatAxisLabels = <String, String>{
  'opening': 'OPENING',
  'relevance': 'RELEVANCE',
  'personality': 'PERSONALITY',
  'momentum': 'MOMENTUM',
  'restraint': 'RESTRAINT',
};

/// THE TEXT LADDER — client for the score-chat Edge Function.
///
/// Text used to pay a flat +50 XP whether you wrote something devastating
/// or typed "hey". That made a text leaderboard impossible (everyone who
/// finishes is identical) and quietly taught people that effort doesn't
/// matter. Now every text conversation gets graded on its own rubric and
/// the number is real.
///
/// Deliberately separate from voice ELO: grinding text to a voice rank
/// you never earned would make the competitive board a lie, and the two
/// skills genuinely aren't the same.
class ChatScoreService {
  /// The most recent result, parked here by the submit call so whichever
  /// screen the user lands on can show the reveal. Same pattern as
  /// DailyGameService.lastResult.
  static ChatResult? lastResult;

  /// THE GRADE IN FLIGHT. The chat screen's two exit paths are not
  /// equal: the finish button awaits the grade before popping, but the
  /// back-arrow path fires it from dispose() — which cannot await — so
  /// the caller read [lastResult] a beat before the network came back
  /// and concluded, wrongly, that nothing was scored. The squad chat
  /// challenge showed no score at all for any man who left with the X.
  ///
  /// The chat screen parks its submit future here on every exit;
  /// whoever needs the result awaits this first. Nulled by the next
  /// submission, not consumed on read — two screens may both want it.
  static Future<void>? grading;

  // ── REVEAL ONCE ─────────────────────────────────────────────────────
  // Same guard as the voice Daily, for the same reason: the grade is
  // submitted without await when the chat closes, so it can land after
  // the screen has read null and then re-fire the moment on the next
  // visit. A persisted per-day stamp makes it idempotent.
  static const _kRevealYmd = 'chat.reveal.shown.ymd';

  static int _todayInt() {
    final n = DateTime.now().toUtc();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  /// One-shot per day, atomically. See DailyGameService.claimReveal for
  /// why the read-then-write pair was not enough.
  static Future<bool> claimReveal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kRevealYmd) == _todayInt()) return false;
    await prefs.setInt(_kRevealYmd, _todayInt());
    return true;
  }

  /// Grade a text conversation. Returns null when offline, when the
  /// transcript is too thin to judge, or when the grader is down — all
  /// of which must read as "no score recorded", never as a zero, or a
  /// network blip would permanently dent someone's average.
  static Future<ChatResult?> score({
    required String transcript,
    String surface = 'roleplay',
    String? scenario,
  }) async {
    if (!BackendService.enabled) return null;
    if (transcript.trim().length < 20) return null;
    try {
      final res = await BackendService.client.functions.invoke(
        'score-chat',
        body: {
          'transcript': transcript,
          'surface': surface,
          if (scenario != null) 'scenario': scenario,
        },
      );
      final data = res.data;
      if (data is! Map) return null;
      if (data['error'] != null) {
        debugPrint('ChatScoreService.score: ${data['error']}');
        return null;
      }
      final rubric = <String, int>{};
      final raw = data['rubric'];
      if (raw is Map) {
        raw.forEach((k, v) {
          final n = (v as num?)?.toInt();
          if (n != null) rubric['$k'] = n;
        });
      }
      final result = ChatResult(
        score: (data['score'] as num).toInt(),
        rubric: rubric,
        best: (data['best'] as num?)?.toInt() ?? 0,
        attempts: (data['attempts'] as num?)?.toInt() ?? 0,
        average: (data['average'] as num?)?.toInt() ?? 0,
        isBest: data['isBest'] == true,
      );
      lastResult = result;
      return result;
    } catch (e) {
      debugPrint('ChatScoreService.score: $e');
      return null;
    }
  }
}
