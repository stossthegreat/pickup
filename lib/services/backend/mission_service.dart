import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

class Mission {
  final String id;
  final String title;
  final String prompt;
  final int tier;
  const Mission(
      {required this.id,
      required this.title,
      required this.prompt,
      required this.tier});
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
      final r = rows.first;
      return Mission(
        id: r['id'] as String,
        title: r['title'] as String,
        prompt: r['prompt'] as String,
        tier: (r['tier'] as num).toInt(),
      );
    } catch (e) {
      debugPrint('MissionService.todayMission: $e');
      return null;
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
