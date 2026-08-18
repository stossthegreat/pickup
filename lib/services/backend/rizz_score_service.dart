import 'package:flutter/foundation.dart';

import '../../screens/academy/score_reveal_screen.dart';
import 'backend_service.dart';
import 'squad_service.dart';

/// Client bridge to the score-voice Edge Function — the only path a
/// score or ELO change can take. Call [scoreSession] at the end of a
/// roleplay, push '/score-reveal' with the returned payload, done.
class RizzScoreService {
  /// Grade a finished session. Returns null offline / on failure —
  /// callers just skip the reveal rather than showing a fake number.
  static Future<ScoreRevealPayload?> scoreSession({
    required String scenario,
    required String transcript,
  }) async {
    if (!BackendService.enabled) return null;
    try {
      final res = await BackendService.client.functions.invoke(
        'score-voice',
        body: {'scenario': scenario, 'transcript': transcript},
      );
      final d = res.data as Map<String, dynamic>;
      final rubric = (d['rubric'] as Map).map(
          (k, v) => MapEntry(k.toString().toUpperCase(), (v as num).toInt()));
      final payload = ScoreRevealPayload(
        score: (d['score'] as num).toInt(),
        rubric: rubric,
        eloDelta: (d['eloDelta'] as num).toInt(),
        newRating: (d['newRating'] as num).toInt(),
        scenario: scenario,
      );

      // Fire the squad Pulse — "he scored 8,942" is a reason for five
      // other men to open the app. Fire-and-forget; never blocks reveal.
      // ignore: discarded_futures
      _pulseScore(payload.score);

      return payload;
    } catch (e) {
      debugPrint('RizzScoreService.scoreSession: $e');
      return null;
    }
  }

  static Future<void> _pulseScore(int score) async {
    final squad = await SquadService.mySquad();
    if (squad != null) {
      await SquadService.postEvent(squad.id, 'scored', {'score': score});
    }
  }
}
