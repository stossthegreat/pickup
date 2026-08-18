import 'mission_service.dart';
import 'squad_service.dart';

/// THE DAY, SCORED — one honest model the whole squad layer reads from.
///
/// Five different numbers were being computed in five different widgets
/// and none of them agreed. This is the single definition:
///
///   Every member has exactly FIVE MOVES a day.
///     · 4 missions from today's board (the same four for everyone)
///     · 1 voice Rizz-Off — taking your shot IS the move
///
///   A move is COMPLETION, not quality. Squad Form measures showing up.
///   Skill lives in the voice score, ranking lives in ELO, and the two
///   never touch this number. That's deliberate: if quality drove team
///   score, squads would start dropping people for being new, and the
///   whole point is "show up", not "be naturally better than everyone".
///
/// SQUAD FORM is participation normalised to a percentage, so a pair
/// isn't punished for being a pair: 8/10 and 20/25 are both 80.
class SquadDay {
  /// Moves available to one person per day.
  static const movesPerMember = 5;

  /// Missions on the board. The fifth move is the Rizz-Off.
  static const missionsPerDay = movesPerMember - 1;

  /// Participation needed to win the day. Scales automatically with
  /// squad size because it's a percentage of the possible, not a count.
  static const winThreshold = 0.8;

  /// Squads are 2–5. Two is enough for accountability and is instantly
  /// reachable; five is the ceiling before a squad becomes a crowd and
  /// nobody feels individually responsible.
  static const minMembers = 2;
  static const maxMembers = 5;

  final List<SquadMember> roster;
  final List<Mission> board;
  final Map<String, MissionPulse> squadStates;
  final List<DailyMark> daily;

  /// MY OWN MISSIONS, COUNTED FROM THE PHONE.
  ///
  /// THE BUG THIS FIXES: a man finished all five of today's missions on
  /// Home and his ring on the squad board still read 0/5.
  ///
  /// It was reading `mission_progress` — the SERVER-side squad board,
  /// written only by MissionService.complete, which only the squad room
  /// screen ever calls. Home's missions are a different system entirely:
  /// local ids from MissionEngine, ticked into SharedPreferences. Two
  /// mission systems, no bridge, so the work he actually did was
  /// invisible to the one screen built to show it.
  ///
  /// The honest bridge without a migration: Home already knows how many
  /// of today's five he's done, so that number is passed in and used for
  /// HIM. Everyone else still comes off the server, which is all we can
  /// see of them — so the board never invents a number for another man,
  /// it only stops under-reporting this one.
  final int? myMoves;

  /// Who "mine" is. Kept explicit rather than reading AuthService here
  /// so the model stays testable and has no service dependency.
  final String? myUserId;

  const SquadDay({
    required this.roster,
    required this.board,
    required this.squadStates,
    required this.daily,
    this.myMoves,
    this.myUserId,
  });

  /// Moves this member has banked today, 0..5.
  int movesFor(String userId) {
    var n = 0;
    for (final m in board.take(missionsPerDay)) {
      if (squadStates[m.id]?.completed.contains(userId) ?? false) n++;
    }
    if (_daily(userId)?.finished ?? false) n++;

    // The higher of what the server saw and what his phone knows he
    // did. Never the lower — a man is not made to look worse by whichever
    // of the two systems happened to miss something.
    if (myUserId != null && userId == myUserId && myMoves != null) {
      final mine = myMoves!.clamp(0, movesPerMember);
      if (mine > n) return mine;
    }
    return n;
  }

  /// Missions only (excludes the Rizz-Off) — for the per-member split.
  int missionMovesFor(String userId) {
    var n = 0;
    for (final m in board.take(missionsPerDay)) {
      if (squadStates[m.id]?.completed.contains(userId) ?? false) n++;
    }
    return n;
  }

  DailyMark? _daily(String userId) {
    for (final d in daily) {
      if (d.userId == userId) return d;
    }
    return null;
  }

  DailyMark? dailyFor(String userId) => _daily(userId);

  /// Has this member got something in flight right now?
  bool activeNow(String userId) {
    for (final p in squadStates.values) {
      if (p.committed.contains(userId)) return true;
    }
    return false;
  }

  int get possible => roster.length * movesPerMember;

  int get complete {
    var n = 0;
    for (final m in roster) {
      n += movesFor(m.userId);
    }
    return n;
  }

  /// 0..100. The number in the middle of the gauge.
  int get form => possible == 0 ? 0 : ((complete / possible) * 100).round();

  /// Moves needed to win the day.
  int get target => (possible * winThreshold).ceil();

  int get remaining => (target - complete).clamp(0, possible);

  bool get won => complete >= target;

  /// Seats left before the squad is full.
  int get openSeats => (maxMembers - roster.length).clamp(0, maxMembers);

  /// A squad below the minimum can't score a day — it's one person
  /// talking to themselves.
  bool get live => roster.length >= minMembers;
}
