import 'package:flutter/foundation.dart';

import 'backend_service.dart';

class DailyBoardEntry {
  final String userId;
  final String? handle;
  final int score;
  const DailyBoardEntry(
      {required this.userId, this.handle, required this.score});
}

class LeagueState {
  final int division;
  final String divisionName;
  final int rank;
  final int points;
  final int size;
  final DateTime locksAt;
  final String zone; // promotion | safe | drop
  const LeagueState(
      {required this.division,
      required this.divisionName,
      required this.rank,
      required this.points,
      required this.size,
      required this.locksAt,
      required this.zone});
}

class DailyStatus {
  final String scenarioKey;
  final bool attempted;
  final int? myScore;
  final List<DailyBoardEntry> board;
  final int? worldAvg;
  final LeagueState league;
  final String? ceremony; // promoted | relegated | held | null
  const DailyStatus(
      {required this.scenarioKey,
      required this.attempted,
      this.myScore,
      required this.board,
      this.worldAvg,
      required this.league,
      this.ceremony});
}

class DailyResult {
  final int score;
  final Map<String, int> rubric;
  final int rankToday;
  final int worldAvg;
  const DailyResult(
      {required this.score,
      required this.rubric,
      required this.rankToday,
      required this.worldAvg});
}

/// THE DAILY + LEAGUE — client for the daily-game Edge Function.
class DailyGameService {
  /// Armed right before the daily attempt launches the voice screen —
  /// the session-end hook submits the transcript as THE attempt.
  static bool armedDaily = false;

  /// The submit result, parked here by the session-end hook so the
  /// Daily screen can show the reveal when the user returns.
  static DailyResult? lastResult;

  static Future<Map<String, dynamic>?> _invoke(
      Map<String, dynamic> body) async {
    if (!BackendService.enabled) return null;
    try {
      final res = await BackendService.client.functions
          .invoke('daily-game', body: body);
      return (res.data as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('DailyGameService ${body['action']}: $e');
      return null;
    }
  }

  static Future<DailyStatus?> status() async {
    final d = await _invoke({'action': 'status'});
    if (d == null) return null;
    try {
      final l = (d['league'] as Map).cast<String, dynamic>();
      return DailyStatus(
        scenarioKey: d['scenarioKey'] as String,
        attempted: d['attempted'] == true,
        myScore: (d['myScore'] as num?)?.toInt(),
        worldAvg: (d['worldAvg'] as num?)?.toInt(),
        board: [
          for (final r in (d['board'] as List))
            DailyBoardEntry(
              userId: r['userId'] as String,
              handle: r['handle'] as String?,
              score: (r['score'] as num).toInt(),
            )
        ],
        league: LeagueState(
          division: (l['division'] as num).toInt(),
          divisionName: l['divisionName'] as String,
          rank: (l['rank'] as num).toInt(),
          points: (l['points'] as num).toInt(),
          size: (l['size'] as num).toInt(),
          locksAt: DateTime.parse(l['locksAt'] as String),
          zone: l['zone'] as String,
        ),
        ceremony: d['ceremony'] as String?,
      );
    } catch (e) {
      debugPrint('DailyGameService.status parse: $e');
      return null;
    }
  }

  static Future<DailyResult?> submit(String transcript) async {
    final d = await _invoke({'action': 'submit', 'transcript': transcript});
    if (d == null || d['score'] == null) return null;
    final result = DailyResult(
      score: (d['score'] as num).toInt(),
      rubric: (d['rubric'] as Map).map(
          (k, v) => MapEntry(k.toString().toUpperCase(), (v as num).toInt())),
      rankToday: (d['rankToday'] as num).toInt(),
      worldAvg: (d['worldAvg'] as num).toInt(),
    );
    lastResult = result;
    return result;
  }
}
