import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

class Mission {
  final String id;
  final String title;
  final String prompt;
  final int tier;
  final String category;
  const Mission(
      {required this.id,
      required this.title,
      required this.prompt,
      required this.tier,
      this.category = 'presence'});

  static Mission fromRow(Map<String, dynamic> r) => Mission(
        id: r['id'] as String,
        title: r['title'] as String,
        prompt: r['prompt'] as String,
        tier: (r['tier'] as num).toInt(),
        category: (r['category'] as String?) ?? 'presence',
      );
}

/// v1 mission loop: today's mission → COMMIT (call your shot) →
/// COMPLETE. The adaptive escalation ladder replaces todayMission()
/// server-side later — the client contract stays identical.
class MissionService {
  static SupabaseClient get _sb => BackendService.client;

  /// Today's mission for this user: the lowest-tier active mission they
  /// haven't completed yet. Null when the catalog is empty or done.
  static Future<Mission?> todayMission() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final done = await _sb
          .from('user_missions')
          .select('mission_id')
          .eq('user_id', uid)
          .eq('state', 'completed');
      final doneIds = [for (final r in done) r['mission_id'] as String];
      var q = _sb.from('missions').select().eq('active', true);
      if (doneIds.isNotEmpty) {
        q = q.not('id', 'in', '(${doneIds.join(',')})');
      }
      final rows = await q.order('tier', ascending: true).limit(1);
      if (rows.isEmpty) return null;
      return Mission.fromRow(rows.first);
    } catch (e) {
      debugPrint('MissionService.todayMission: $e');
      return null;
    }
  }

  /// TODAY'S BOARD — the day's whole slate, not a single card.
  ///
  /// THE FIVE — today's mission board. THE SAME FIVE FOR EVERYONE.
  ///
  /// This used to serve "the five lowest-tier missions THIS USER hasn't
  /// completed", which quietly broke the entire squad feature: two
  /// squadmates at different points in the ladder were looking at
  /// different missions, so "3/5 SQUAD DONE" was counting people against
  /// a mission that wasn't even on their board. The number was noise.
  ///
  /// Now the day picks the five, not the user. A rotating window over
  /// the catalog, seeded by the UTC day number — the same rule every
  /// client runs, so everyone in the world opens the app to the same
  /// five missions, the same way everyone gets the same Daily scenario
  /// (see scenarioOfToday()). That is what makes a shared count mean
  /// something, and what gives the room something to talk about.
  ///
  /// Completed missions are NOT filtered out here — if you've done one
  /// before, it still shows, marked done. The board is a shared board;
  /// hiding rows per-person would break the shared-ness all over again.
  static Future<List<Mission>> todayBoard({int count = 5}) async {
    try {
      // Order by id so every device folds the catalog identically.
      final rows =
          await _sb.from('missions').select().eq('active', true).order('id');
      final all = [for (final r in rows) Mission.fromRow(r)];
      if (all.length <= count) return all;
      final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      final start = (day * count) % all.length;
      return [for (var i = 0; i < count; i++) all[(start + i) % all.length]];
    } catch (e) {
      debugPrint('MissionService.todayBoard: $e');
      return const [];
    }
  }

  /// My state on every mission on the board, in one round trip:
  /// missionId → 'committed' | 'completed'. Absent key = untouched.
  static Future<Map<String, String>> myStatesToday(
      List<String> missionIds) async {
    final uid = AuthService.userId;
    if (uid == null || missionIds.isEmpty) return const {};
    try {
      final now = DateTime.now();
      final iso = DateTime(now.year, now.month, now.day).toIso8601String();
      final rows = await _sb
          .from('user_missions')
          .select('mission_id, state')
          .eq('user_id', uid)
          .inFilter('mission_id', missionIds)
          .gte('created_at', iso);
      return {
        for (final r in rows) r['mission_id'] as String: r['state'] as String,
      };
    } catch (e) {
      debugPrint('MissionService.myStatesToday: $e');
      return const {};
    }
  }

  /// Today's user_missions row for [missionId] (committed or completed),
  /// or null if the shot hasn't been called yet.
  static Future<String?> todayState(String missionId) async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final dayStart = DateTime.now();
      final iso =
          DateTime(dayStart.year, dayStart.month, dayStart.day).toIso8601String();
      final rows = await _sb
          .from('user_missions')
          .select('state')
          .eq('user_id', uid)
          .eq('mission_id', missionId)
          .gte('created_at', iso)
          .limit(1);
      return rows.isEmpty ? null : rows.first['state'] as String;
    } catch (e) {
      debugPrint('MissionService.todayState: $e');
      return null;
    }
  }

  /// CALL YOUR SHOT — public commitment. Returns true on success.
  static Future<bool> commit(String missionId) async {
    final uid = AuthService.userId;
    if (uid == null) return false;
    try {
      await _sb.from('user_missions').insert({
        'user_id': uid,
        'mission_id': missionId,
        'state': 'committed',
        'committed_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('MissionService.commit: $e');
      return false;
    }
  }

  /// Mark the committed mission done (proof lives in Discord).
  static Future<bool> complete(String missionId) async {
    final uid = AuthService.userId;
    if (uid == null) return false;
    try {
      await _sb
          .from('user_missions')
          .update({
            'state': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .match({'user_id': uid, 'mission_id': missionId}).neq(
              'state', 'completed');
      return true;
    } catch (e) {
      debugPrint('MissionService.complete: $e');
      return false;
    }
  }
}
