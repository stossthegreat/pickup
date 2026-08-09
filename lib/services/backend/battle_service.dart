import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

/// One duel, shaped for the UI.
class Battle {
  final String id;
  final String scenario; // vibe key: cold | into_you | chaos | ...
  final String mode; // code | random
  final String? inviteCode;
  final String? playerA, playerB;
  final int? aScore, bScore;
  final String? winner;
  final String state; // open | active | scored
  const Battle({
    required this.id,
    required this.scenario,
    required this.mode,
    this.inviteCode,
    this.playerA,
    this.playerB,
    this.aScore,
    this.bScore,
    this.winner,
    required this.state,
  });

  factory Battle.fromRow(Map<String, dynamic> r) => Battle(
        id: r['id'] as String,
        scenario: r['scenario'] as String? ?? 'cold',
        mode: r['mode'] as String? ?? 'code',
        inviteCode: r['invite_code'] as String?,
        playerA: r['player_a'] as String?,
        playerB: r['player_b'] as String?,
        aScore: (r['a_score'] as num?)?.toInt(),
        bScore: (r['b_score'] as num?)?.toInt(),
        winner: r['winner'] as String?,
        state: r['state'] as String? ?? 'open',
      );

  String get scenarioLabel => scenario.replaceAll('_', ' ').toUpperCase();

  bool get mine => AuthService.userId == playerA || AuthService.userId == playerB;
  bool get iAmA => AuthService.userId == playerA;
  int? get myScore => iAmA ? aScore : bScore;
  int? get theirScore => iAmA ? bScore : aScore;
  String? get opponentId => iAmA ? playerB : playerA;
  bool get iSubmitted => myScore != null;
  bool get settled => state == 'scored';
  bool get iWon => settled && winner != null && winner == AuthService.userId;
  bool get tie => settled && winner == null && aScore != null && bScore != null;
}

/// RIZZ BATTLES — same scenario, both play blind, higher score takes
/// the ELO. All lifecycle writes go through the battle-action Edge
/// Function; this service is the thin client.
class BattleService {
  static SupabaseClient get _sb => BackendService.client;

  /// Set right before a battle attempt launches the voice screen; the
  /// session-end hook reads it, submits the transcript to this battle,
  /// and clears it. Static because FreeFlowScreen is pushed far from
  /// any battle context.
  static String? armedBattleId;

  static Future<Map<String, dynamic>?> _invoke(
      Map<String, dynamic> body) async {
    if (!BackendService.enabled) return null;
    try {
      final res = await _sb.functions.invoke('battle-action', body: body);
      return (res.data as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('BattleService ${body['action']}: $e');
      return null;
    }
  }

  /// Mint a code duel (caller = player A). Null offline.
  static Future<Battle?> createChallenge({String? scenario}) async {
    final d = await _invoke({
      'action': 'create',
      if (scenario != null) 'scenario': scenario,
    });
    final row = d?['battle'];
    return row == null ? null : Battle.fromRow((row as Map).cast());
  }

  /// Claim an open duel by its code.
  static Future<Battle?> joinChallenge(String code) async {
    final d = await _invoke({'action': 'join', 'code': code});
    final row = d?['battle'];
    return row == null ? null : Battle.fromRow((row as Map).cast());
  }

  /// Random matchmaking. Returns the battle when paired instantly, or
  /// null while waiting in the line (poll again).
  static Future<Battle?> findOpponent() async {
    final d = await _invoke({'action': 'queue'});
    final row = d?['battle'];
    return row == null ? null : Battle.fromRow((row as Map).cast());
  }

  static Future<void> leaveQueue() async {
    await _invoke({'action': 'leave_queue'});
  }

  /// Submit the caller's attempt transcript. Returns the updated battle.
  static Future<Battle?> submit(String battleId, String transcript) async {
    final d = await _invoke({
      'action': 'submit',
      'battle_id': battleId,
      'transcript': transcript,
    });
    final row = d?['battle'];
    return row == null ? null : Battle.fromRow((row as Map).cast());
  }

  /// The caller's battles, newest first (RLS scopes the read).
  static Future<List<Battle>> myBattles({int limit = 20}) async {
    if (!BackendService.enabled || AuthService.userId == null) return const [];
    try {
      final rows = await _sb
          .from('battles')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) Battle.fromRow(r)];
    } catch (e) {
      debugPrint('BattleService.myBattles: $e');
      return const [];
    }
  }

  /// Opponent handles for a set of battles (one round-trip).
  static Future<Map<String, String>> handles(List<Battle> battles) async {
    final ids = <String>{
      for (final b in battles)
        if (b.opponentId != null) b.opponentId!,
    };
    if (ids.isEmpty || !BackendService.enabled) return const {};
    try {
      final rows = await _sb
          .from('profiles')
          .select('id, handle')
          .inFilter('id', ids.toList());
      return {
        for (final r in rows)
          r['id'] as String: (r['handle'] as String?) ?? 'ANON',
      };
    } catch (e) {
      debugPrint('BattleService.handles: $e');
      return const {};
    }
  }
}
