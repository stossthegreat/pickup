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

  /// Ratings for a specific set of users (the SQUAD scope), ranked.
  static Future<List<LeaderboardEntry>> forUsers(List<String> ids) async {
    if (!BackendService.enabled || ids.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('rizz_elo')
          .select('user_id, rating, tier, profiles(handle, avatar_url)')
          .inFilter('user_id', ids)
          .order('rating', ascending: false);
      return [
        for (final r in rows)
          LeaderboardEntry(
            userId: r['user_id'] as String,
            handle: (r['profiles'] as Map?)?['handle'] as String?,
            avatarUrl: (r['profiles'] as Map?)?['avatar_url'] as String?,
            rating: (r['rating'] as num).toInt(),
            tier: r['tier'] as String? ?? 'OBSERVER',
          )
      ];
    } catch (e) {
      debugPrint('LeaderboardService.forUsers: $e');
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

/// One row of the TEXT board. Ranked on best score, not ELO — text has
/// its own ladder (see migration 0009 for why they don't mix).
class ChatBoardEntry {
  final String userId;
  final String? handle;
  final String? avatarUrl;
  final int best;
  final int attempts;
  final int average;
  const ChatBoardEntry({
    required this.userId,
    this.handle,
    this.avatarUrl,
    required this.best,
    required this.attempts,
    required this.average,
  });
}

/// Chat-rizz leaderboard reads. Same guarantee as the voice board:
/// chat_score is written EXCLUSIVELY by the score-chat Edge Function
/// under the service role, so no phone can post its own number.
class ChatLeaderboardService {
  static SupabaseClient get _sb => BackendService.client;

  static Future<List<ChatBoardEntry>> global({int limit = 50}) async {
    if (!BackendService.enabled) return const [];
    try {
      final rows = await _sb.from('chat_leaderboard').select().limit(limit);
      return [
        for (final r in rows)
          ChatBoardEntry(
            userId: r['id'] as String,
            handle: r['handle'] as String?,
            avatarUrl: r['avatar_url'] as String?,
            best: (r['best'] as num?)?.toInt() ?? 0,
            attempts: (r['attempts'] as num?)?.toInt() ?? 0,
            average: (r['average'] as num?)?.toInt() ?? 0,
          )
      ];
    } catch (e) {
      debugPrint('ChatLeaderboardService.global: $e');
      return const [];
    }
  }
}
