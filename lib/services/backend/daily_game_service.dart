import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../live_events.dart';
import 'backend_service.dart';

class DailyBoardEntry {
  final String userId;
  final String? handle;
  final int score;
  const DailyBoardEntry(
      {required this.userId, this.handle, required this.score});
}

class LeagueStanding {
  final String userId;
  final String? handle;
  final String? avatarUrl;
  final int points;
  const LeagueStanding(
      {required this.userId,
      this.handle,
      this.avatarUrl,
      required this.points});
}

class LeagueState {
  final int division;
  final String divisionName;
  final int rank;
  final int points;
  final int size;
  final DateTime locksAt;
  final String zone; // promotion | safe | drop
  final int promoteTop;
  final int relegateBottom;
  final List<LeagueStanding> standings;
  const LeagueState(
      {required this.division,
      required this.divisionName,
      required this.rank,
      required this.points,
      required this.size,
      required this.locksAt,
      required this.zone,
      this.promoteTop = 10,
      this.relegateBottom = 5,
      this.standings = const []});
}

class FixtureState {
  final String opponentId;
  final String? opponentHandle;
  final String opponentRecord; // "7W-2L"
  final int myPoints;
  final int theirPoints;
  final DateTime locksAt;
  const FixtureState(
      {required this.opponentId,
      this.opponentHandle,
      required this.opponentRecord,
      required this.myPoints,
      required this.theirPoints,
      required this.locksAt});

  bool get winning => myPoints > theirPoints;
  bool get level => myPoints == theirPoints;
}

class DailyStatus {
  final String scenarioKey;
  final bool attempted;
  final int? myScore;
  final List<DailyBoardEntry> board;
  final int? worldAvg;
  final LeagueState league;
  final FixtureState? fixture; // null: no squad / bye week
  final String? ceremony; // promoted | relegated | held | null
  final String? fixtureCeremony; // won | lost | draw | null
  const DailyStatus(
      {required this.scenarioKey,
      required this.attempted,
      this.myScore,
      required this.board,
      this.worldAvg,
      required this.league,
      this.fixture,
      this.ceremony,
      this.fixtureCeremony});
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

  // ── REVEAL ONCE ─────────────────────────────────────────────────────
  // The reveal is the day's big moment and it was replaying. Clearing
  // lastResult on read wasn't enough: submit() is fired without await at
  // session end, so it can land AFTER the Daily screen has already read
  // null, then sit there and re-fire on the next return. A persisted
  // per-day stamp makes the moment idempotent regardless of what order
  // the futures settle in.
  static const _kRevealYmd = 'daily.reveal.shown.ymd';

  static int _todayInt() {
    final n = DateTime.now().toUtc();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  /// CHECK AND SET IN ONE BREATH. Returns true exactly once per day.
  ///
  /// A separate has-it-shown read followed by a mark-it-shown write is
  /// two awaits with a gap in the middle, and anything that can call the
  /// ending twice —
  /// a double tap, a session that ends from both the finish button and
  /// dispose, a rebuild that re-enters — can have both callers read
  /// false before either writes. Then the day's ceremony plays twice,
  /// or five times, which is what was happening.
  ///
  /// Collapsing it into one call closes that window: the second caller
  /// reads a stamp the first already wrote.
  static Future<bool> claimReveal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kRevealYmd) == _todayInt()) return false;
    await prefs.setInt(_kRevealYmd, _todayInt());
    return true;
  }

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
      final f = d['fixture'] == null
          ? null
          : (d['fixture'] as Map).cast<String, dynamic>();
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
          promoteTop: (l['promoteTop'] as num?)?.toInt() ?? 10,
          relegateBottom: (l['relegateBottom'] as num?)?.toInt() ?? 5,
          standings: [
            for (final r in ((l['standings'] as List?) ?? const []))
              LeagueStanding(
                userId: r['userId'] as String,
                handle: r['handle'] as String?,
                avatarUrl: r['avatarUrl'] as String?,
                points: (r['points'] as num).toInt(),
              )
          ],
        ),
        fixture: f == null
            ? null
            : FixtureState(
                opponentId: f['opponentId'] as String,
                opponentHandle: f['opponentHandle'] as String?,
                opponentRecord: f['opponentRecord'] as String? ?? '0W-0L',
                myPoints: (f['myPoints'] as num).toInt(),
                theirPoints: (f['theirPoints'] as num).toInt(),
                locksAt: DateTime.parse(f['locksAt'] as String),
              ),
        ceremony: d['ceremony'] as String?,
        fixtureCeremony: d['fixtureCeremony'] as String?,
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
    LiveEvents.scored(result.score, 'The Daily · #${result.rankToday} today');
    return result;
  }
}
