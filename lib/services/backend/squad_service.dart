import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

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
