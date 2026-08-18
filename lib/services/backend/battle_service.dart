import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_service.dart';

/// One duel, shaped for the UI.
class Battle {
  final String id;
  final String scenario; // vibe key: cold | into_you | chaos | ...
  final String mode; // code | random

  /// 'chat' | 'voice' — which room this duel is fought in. Defaults to
  /// chat so a row written before migration 0016 reads as what it was.
  final String medium;
  final String? inviteCode;
  final String? playerA, playerB;
  final int? aScore, bScore;
  final String? winner;
  final String state; // open | active | scored
  const Battle({
    required this.id,
    required this.scenario,
    required this.mode,
    this.medium = 'chat',
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
        medium: r['medium'] as String? ?? 'chat',
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

  bool get isVoice => medium == 'voice';

  /// A duel neither man has started. The only kind that can be binned
  /// outright — see BattleService.cancelChallenge.
  bool get untouched => aScore == null && bScore == null;
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
  static Future<Battle?> createChallenge({
    String? scenario,
    String medium = 'chat',
  }) async {
    final d = await _invoke({
      'action': 'create',
      'medium': medium,
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
  static Future<Battle?> findOpponent({String medium = 'chat'}) async {
    final d = await _invoke({'action': 'queue', 'medium': medium});
    final row = d?['battle'];
    return row == null ? null : Battle.fromRow((row as Map).cast());
  }

  /// ══════════════════════════════════════════════════════════════
  ///  LIVE. A duel is a conversation between two phones.
  ///  ══════════════════════════════════════════════════════════════
  ///
  /// Everything here used to move on a 30-second poll, and it showed:
  /// a man submitted his attempt, watched "he hasn't answered yet", and
  /// kept watching it long after the other man had answered. Both
  /// screens sat on stale rows telling both players the fight was still
  /// open. On the queue it was worse — the paired man could wait
  /// minutes to be told he had an opponent.
  ///
  /// Postgres already knows the instant either of those changes. Two
  /// subscriptions — one per player slot, because a filter can only
  /// test one column and a duel can have me in either — and the screen
  /// reloads on the same beat the row moves.
  ///
  /// Poll stays as the backstop. Realtime over a phone network drops,
  /// and a duel that silently never resolves is worse than a slow one.
  static List<RealtimeChannel> watchMine(void Function() onChange) {
    final uid = AuthService.userId;
    if (!BackendService.enabled || uid == null) return const [];
    RealtimeChannel chan(String column) => _sb
        .channel('battles-$column-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battles',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: uid),
          callback: (_) => onChange(),
        )
        .subscribe();
    return [chan('player_a'), chan('player_b')];
  }

  static Future<void> leaveQueue() async {
    await _invoke({'action': 'leave_queue'});
  }

  /// Bin an open challenge nobody took.
  ///
  /// A minted code used to be permanent — the card sat on the Battles
  /// screen forever and there was no way to remove it, so codes piled up
  /// and pushed the one button that matters further down the page every
  /// time.
  ///
  /// It goes through the Edge Function because RLS gives clients
  /// read-only access to `battles`; a direct delete from the phone is
  /// denied, which is correct — the server decides who may destroy a
  /// duel. Only the creator, only while it's still open, only if nobody
  /// has joined.
  static Future<bool> cancelChallenge(String battleId) async {
    final d = await _invoke({'action': 'cancel', 'battle_id': battleId});
    return d?['ok'] == true;
  }

  /// The last submitted attempt's grade, parked for the reveal.
  ///
  /// A duel deserves the same moment as the Daily — the count-up, the
  /// axes landing one at a time, the grade slam. The grade only exists
  /// inside this call, so it's held here for the screen that comes back.
  static BattleResult? lastResult;

  /// Submit the caller's attempt transcript. Returns the updated battle.
  static Future<Battle?> submit(String battleId, String transcript) async {
    final d = await _invoke({
      'action': 'submit',
      'battle_id': battleId,
      'transcript': transcript,
    });
    if (d != null && d['yourScore'] != null) {
      final rubric = <String, int>{};
      final raw = d['rubric'];
      if (raw is Map) {
        raw.forEach((k, v) {
          final n = (v as num?)?.toInt();
          if (n != null) rubric['$k'] = n;
        });
      }
      lastResult = BattleResult(
        score: (d['yourScore'] as num).toInt(),
        rubric: rubric,
        settled: d['settled'] == true,
      );
    }
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

/// One graded duel attempt, on its way to the reveal.
class BattleResult {
  /// 0..9999 internally — the same band the voice grader uses, because
  /// battles share its rubric. The screen divides it down to 0..100.
  final int score;
  final Map<String, int> rubric;

  /// True when both men are in and the duel has a winner.
  final bool settled;

  const BattleResult({
    required this.score,
    required this.rubric,
    required this.settled,
  });
}
