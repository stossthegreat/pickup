import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

class LeaderboardEntry {
  final String userId;
  final String? handle;
  final String? avatarUrl;
  final int rating;
  final String tier;
  const LeaderboardEntry(
      {required this.userId,
      this.handle,
      this.avatarUrl,
      required this.rating,
      required this.tier});
}

/// Voice-rizz leaderboard reads. Ratings are written EXCLUSIVELY by the
/// scoring Edge Function (service role) — there is no client path that
/// can touch rizz_elo, so the board can't be cheated from a phone.
class LeaderboardService {
  static SupabaseClient get _sb => BackendService.client;

  /// Global top N via the leaderboard_global view.
  static Future<List<LeaderboardEntry>> global({int limit = 50}) async {
    if (!BackendService.enabled) return const [];
    try {
      final rows =
          await _sb.from('leaderboard_global').select().limit(limit);
      return [
        for (final r in rows)
          LeaderboardEntry(
            userId: r['id'] as String,
            handle: r['handle'] as String?,
            avatarUrl: r['avatar_url'] as String?,
            rating: (r['rating'] as num).toInt(),
            tier: r['tier'] as String? ?? 'OBSERVER',
          )
      ];
    } catch (e) {
      debugPrint('LeaderboardService.global: $e');
      return const [];
    }
  }

  /// The signed-in user's own rating row (rank ladder chip, profile).
  static Future<LeaderboardEntry?> me() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final r = await _sb
          .from('rizz_elo')
          .select('rating, tier')
          .eq('user_id', uid)
          .single();
      return LeaderboardEntry(
        userId: uid,
        rating: (r['rating'] as num).toInt(),
        tier: r['tier'] as String? ?? 'OBSERVER',
      );
    } catch (e) {
      debugPrint('LeaderboardService.me: $e');
      return null;
    }
  }
}
