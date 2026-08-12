import 'package:flutter/foundation.dart';

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
