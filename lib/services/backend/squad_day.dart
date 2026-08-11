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

  const SquadDay({
    required this.roster,
    required this.board,
    required this.squadStates,
    required this.daily,
  });

  /// Moves this member has banked today, 0..5.
  int movesFor(String userId) {
    var n = 0;
    for (final m in board.take(missionsPerDay)) {
      if (squadStates[m.id]?.completed.contains(userId) ?? false) n++;
    }
    if (_daily(userId)?.finished ?? false) n++;
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
