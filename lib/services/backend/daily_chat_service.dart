import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'backend_service.dart';

/// One man's run at today's chat challenge.
class ChatMark {
  final String userId;
  final int score; // 0..100
  const ChatMark({required this.userId, required this.score});
}

/// THE DAILY CHAT CHALLENGE.
///
/// The voice Rizz-Off had no counterpart in writing, which left the
/// squad with one shared event a day and nothing for the men who won't
/// talk out loud in a shared flat at 11pm. Same woman, same day, same
/// squad — she just types back instead.
///
/// Deliberately built on the machinery that already exists rather than a
/// fourth scoring system: it is a graded chat attempt like any other,
/// tagged `surface = 'daily_chat'`, so it feeds RIZZ POINTS (0010) and
/// the text board with no new table and no new Edge Function. "Today's"
/// is a read over created_at rather than a server lock, which is the
/// right trade here — the text ladder is cumulative, so a second run
/// can't win anyone a rank they didn't earn, it just pays them for the
/// reps they actually did.
class DailyChatService {
  static const surface = 'daily_chat';

  /// Everyone in [userIds] who has run today's chat challenge, best
  /// score first for each man.
  static Future<List<ChatMark>> today(List<String> userIds) async {
    if (!BackendService.enabled || userIds.isEmpty) return const [];
    try {
      final now = DateTime.now();
      final since = DateTime(now.year, now.month, now.day).toUtc();
      final rows = await BackendService.client
          .from('chat_attempts')
          .select('user_id, score')
          .inFilter('user_id', userIds)
          .eq('surface', surface)
          .gte('created_at', since.toIso8601String());

      // One mark per man — his best of the day, so a second run can
      // improve the board rather than muddy it with two rows.
      final best = <String, int>{};
      for (final r in rows) {
        final uid = r['user_id'] as String;
        final s = (r['score'] as num?)?.toInt() ?? 0;
        if (s > (best[uid] ?? -1)) best[uid] = s;
      }
      return [
        for (final e in best.entries) ChatMark(userId: e.key, score: e.value)
      ];
    } catch (e) {
      debugPrint('DailyChatService.today: $e');
      return const [];
    }
  }

  /// Have I taken today's chat challenge?
  static Future<ChatMark?> mine() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    final marks = await today([uid]);
    return marks.isEmpty ? null : marks.first;
  }
}
