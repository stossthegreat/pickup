import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

/// One Pulse entry — a squad-visible event (join/commit/complete/score).
class SquadEvent {
  final String actorId;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  const SquadEvent(
      {required this.actorId,
      required this.kind,
      required this.payload,
      required this.createdAt});
}

/// One Week Grid cell source — a member's mission activity this week.
class WeekMark {
  final String userId;
  final DateTime day;
  final bool completed; // false = committed but not completed yet
  final String? missionTitle;
  const WeekMark(
      {required this.userId,
      required this.day,
      required this.completed,
      this.missionTitle});
}

/// A squad roster row, shaped for the UI.
class SquadMember {
  final String userId;
  final String? handle;
  final String? avatarUrl;
  final String role;
  const SquadMember(
      {required this.userId, this.handle, this.avatarUrl, required this.role});
}

class Squad {
  final String id;
  final String name;
  final String inviteCode;
  const Squad({required this.id, required this.name, required this.inviteCode});
}

/// Squads — the accountability layer. Comms live in Discord; the app
/// owns membership, progression and the notification feed.
class SquadService {
  static SupabaseClient get _sb => BackendService.client;

  // Unambiguous alphabet (no 0/O/1/I) — codes get read out loud.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String _mintCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)])
        .join();
  }

  /// Create a squad and join it as captain. Returns null offline.
  static Future<Squad?> create(String name) async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final code = _mintCode();
      final row = await _sb
          .from('squads')
          .insert({'name': name, 'invite_code': code, 'created_by': uid})
          .select()
          .single();
      await _sb.from('squad_members').insert({
        'squad_id': row['id'],
        'user_id': uid,
        'role': 'captain',
      });
      return Squad(
          id: row['id'] as String,
          name: row['name'] as String,
          inviteCode: row['invite_code'] as String);
    } catch (e) {
      debugPrint('SquadService.create: $e');
      return null;
    }
  }

  /// Join by invite code. Goes through the join_squad_by_code RPC
  /// (SECURITY DEFINER) because RLS correctly stops non-members from
  /// reading squads — the function is the one sanctioned door in.
  static Future<Squad?> joinByCode(String code) async {
    if (AuthService.userId == null) return null;
    try {
      final row = await _sb.rpc('join_squad_by_code',
          params: {'code': code.trim().toUpperCase()});
      if (row == null) return null;
      final m = (row as List).first as Map<String, dynamic>;
      return Squad(
          id: m['id'] as String,
          name: m['name'] as String,
          inviteCode: m['invite_code'] as String);
    } catch (e) {
      debugPrint('SquadService.joinByCode: $e'); // bad code lands here too
      return null;
    }
  }

  /// The user's current squad (v1: one squad per user), or null.
  static Future<Squad?> mySquad() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final rows = await _sb
          .from('squad_members')
          .select('squads(id, name, invite_code)')
          .eq('user_id', uid)
          .eq('status', 'active')
          .limit(1);
      if (rows.isEmpty) return null;
      final s = rows.first['squads'] as Map<String, dynamic>;
      return Squad(
          id: s['id'] as String,
          name: s['name'] as String,
          inviteCode: s['invite_code'] as String);
    } catch (e) {
      debugPrint('SquadService.mySquad: $e');
      return null;
    }
  }

  static Future<List<SquadMember>> roster(String squadId) async {
    try {
      final rows = await _sb
          .from('squad_members')
          .select('user_id, role, profiles(handle, avatar_url)')
          .eq('squad_id', squadId)
          .eq('status', 'active');
      return [
        for (final r in rows)
          SquadMember(
            userId: r['user_id'] as String,
            role: r['role'] as String,
            handle: (r['profiles'] as Map?)?['handle'] as String?,
            avatarUrl: (r['profiles'] as Map?)?['avatar_url'] as String?,
          )
      ];
    } catch (e) {
      debugPrint('SquadService.roster: $e');
      return const [];
    }
  }

  static Future<void> leave(String squadId) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    try {
      await _sb
          .from('squad_members')
          .delete()
          .match({'squad_id': squadId, 'user_id': uid});
    } catch (e) {
      debugPrint('SquadService.leave: $e');
    }
  }

  /// Monday 00:00 of the current week (device-local).
  static DateTime weekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// THE WEEK GRID — every member's commits + completions this week.
  /// Readable because migration 0003 opens user_missions to active
  /// squadmates (and nobody else).
  static Future<List<WeekMark>> weekMarks(List<String> memberIds) async {
    if (memberIds.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('user_missions')
          .select(
              'user_id, state, committed_at, completed_at, missions(title)')
          .inFilter('user_id', memberIds)
          .gte('created_at', weekStart().toIso8601String());
      return [
        for (final r in rows)
          if (r['committed_at'] != null || r['completed_at'] != null)
            WeekMark(
              userId: r['user_id'] as String,
              completed: r['state'] == 'completed',
              day: DateTime.parse((r['completed_at'] ?? r['committed_at'])
                      as String)
                  .toLocal(),
              missionTitle: (r['missions'] as Map?)?['title'] as String?,
            )
      ];
    } catch (e) {
      debugPrint('SquadService.weekMarks: $e');
      return const [];
    }
  }

  /// Latest Pulse events, newest first.
  static Future<List<SquadEvent>> pulse(String squadId,
      {int limit = 30}) async {
    try {
      final rows = await _sb
          .from('squad_events')
          .select('actor, kind, payload, created_at')
          .eq('squad_id', squadId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final r in rows)
          SquadEvent(
            actorId: r['actor'] as String,
            kind: r['kind'] as String,
            payload:
                (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          )
      ];
    } catch (e) {
      debugPrint('SquadService.pulse: $e');
      return const [];
    }
  }

  /// Post a Pulse event as the signed-in user (RLS enforces membership).
  static Future<void> postEvent(String squadId, String kind,
      [Map<String, dynamic> payload = const {}]) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    try {
      await _sb.from('squad_events').insert({
        'squad_id': squadId,
        'actor': uid,
        'kind': kind,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('SquadService.postEvent: $e');
    }
  }

  /// Live Pulse — fires on every new squad event while the room is open.
  static RealtimeChannel watchPulse(
      String squadId, void Function() onChange) {
    return _sb
        .channel('pulse-$squadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'squad_events',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'squad_id',
              value: squadId),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static void unwatch(RealtimeChannel channel) {
    try {
      _sb.removeChannel(channel);
    } catch (_) {}
  }

  /// Live roster feed — fires on every join/leave in the squad. This is
  /// the engine behind squad notifications ("Marcus joined", "2/5 done
  /// today"): Supabase Realtime, no push infrastructure needed while
  /// the app is open. (APNs push for closed-app alerts is a later phase.)
  static RealtimeChannel watchRoster(
      String squadId, void Function() onChange) {
    return _sb
        .channel('squad-$squadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'squad_members',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'squad_id',
              value: squadId),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
