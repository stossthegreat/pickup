import 'package:flutter/foundation.dart';

import 'backend_service.dart';

/// THE SQUAD'S SHARED STAKE — streak, quorum, the armband, the bench.
///
/// A group with nothing it owns together is a chatroom. Squad Form told
/// you how today was going and then forgot; nothing carried, nothing
/// could be LOST, and loss is the only force strong enough to get a man
/// to run a challenge at 11:52pm. So the squad gets one object it holds
/// jointly and can break: a streak, on a quorum.
///
/// THREE FAILURE MODES THIS FIXES, IN ORDER OF HOW OFTEN THEY KILL A
/// SQUAD:
///
///  1. ONE DEAD MAN KILLS IT. Under unanimity every member holds a veto
///     over everyone else's effort, one bad week teaches the group the
///     streak is unwinnable, and the whole thing is abandoned. So the
///     bar is a QUORUM — half, rounded up — and a man who's gone quiet
///     is BENCHED rather than counted as a failure. Benching drags
///     nobody down, and one run undoes it.
///
///  2. THE CARELESS CAPTAIN. Appointed leadership rots: the man who
///     created the squad in week one is not necessarily the man showing
///     up in week six, and there is no way to fix that which doesn't
///     cause a falling-out. So the armband is COMPUTED, never given —
///     highest run count over the last seven days, recalculated every
///     time this loads. It rotates silently, no admin, no confrontation.
///     And because it's lost rather than revoked it's worth far more
///     than an appointment: a status object you can wake up without is
///     one men check every morning.
///
///  3. NOTHING IS PUBLIC. Social facilitation beats every solo incentive
///     we could design, and it costs nothing. "The streak died at 14"
///     with a name attached does more work than any reward in the app.
///
/// COSTS NOTHING TO DEPLOY. Every number here is derived on-device from
/// `daily_attempts` — the same table, columns and RLS policy that
/// SquadService.dailyToday already reads successfully for the squad.
/// The only change is the ymd filter becomes a range instead of a day.
/// No migration, no Edge Function, nothing to switch on: it works the
/// moment the build lands.
class SquadHistory {
  /// ymd → the set of members who got scored that day.
  final Map<int, Set<String>> ranOn;

  /// Oldest → newest, inclusive of today.
  final List<int> days;

  final int memberCount;

  const SquadHistory({
    required this.ranOn,
    required this.days,
    required this.memberCount,
  });

  static const empty = SquadHistory(
      ranOn: <int, Set<String>>{}, days: <int>[], memberCount: 0);

  /// A man is benched after this many COMPLETED days of silence. Today
  /// never counts against him — the day isn't over.
  static const benchAfterDays = 3;

  /// The armband is decided over this window. Short enough that it can
  /// actually change hands, long enough that one good Tuesday doesn't
  /// take it.
  static const armbandWindow = 7;

  /// How far back the chain is drawn.
  static const window = 30;

  // ── Loading ─────────────────────────────────────────────────────────

  static int ymdOf(DateTime t) {
    final u = t.toUtc();
    return u.year * 10000 + u.month * 100 + u.day;
  }

  static List<int> lastDays(int n) {
    final today = DateTime.now().toUtc();
    return [
      for (var i = n - 1; i >= 0; i--)
        ymdOf(today.subtract(Duration(days: i))),
    ];
  }

  static Future<SquadHistory> load(List<String> memberIds) async {
    final days = lastDays(window);
    if (memberIds.isEmpty || days.isEmpty) return empty;
    try {
      final rows = await BackendService.client
          .from('daily_attempts')
          .select('user_id, ymd')
          .inFilter('user_id', memberIds)
          .gte('ymd', days.first);
      final map = <int, Set<String>>{};
      for (final r in rows) {
        final ymd = (r['ymd'] as num?)?.toInt();
        final uid = r['user_id'] as String?;
        if (ymd == null || uid == null) continue;
        map.putIfAbsent(ymd, () => <String>{}).add(uid);
      }
      return SquadHistory(
          ranOn: map, days: days, memberCount: memberIds.length);
    } catch (e) {
      // Offline or the table isn't reachable — the room degrades to
      // "no streak yet" rather than an error. A squad screen that can't
      // render because history is missing is worse than no history.
      debugPrint('SquadHistory.load: $e');
      return SquadHistory(
          ranOn: const <int, Set<String>>{},
          days: days,
          memberCount: memberIds.length);
    }
  }

  // ── The rules ───────────────────────────────────────────────────────

  /// How many men have to show up for the day to bank.
  ///
  /// Half, rounded up, floored at two. The floor is what stops a pair's
  /// streak being carried indefinitely by one man while the other never
  /// opens the app — at which point it isn't accountability, it's a
  /// solo streak with an audience.
  int get quorum {
    final n = memberCount;
    if (n < 2) return n;
    final half = (n / 2).ceil();
    return half < 2 ? 2 : (half > n ? n : half);
  }

  Set<String> whoRan(int ymd) => ranOn[ymd] ?? const <String>{};

  bool banked(int ymd) => whoRan(ymd).length >= quorum;

  int get todayYmd => days.isEmpty ? 0 : days.last;

  bool get todayBanked => days.isNotEmpty && banked(todayYmd);

  int get ranToday => whoRan(todayYmd).length;

  int get shortToday => (quorum - ranToday).clamp(0, quorum);

  /// THE STREAK. Consecutive banked days ending today.
  ///
  /// Today is exempt while it's still running: an unbanked today doesn't
  /// break anything, it just isn't counted yet. Punishing a man at 9am
  /// for a day he still has fourteen hours of is how a streak mechanic
  /// teaches people to stop looking.
  int get streak {
    if (days.isEmpty || memberCount < 2) return 0;
    var n = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (banked(days[i])) {
        n++;
      } else if (i == days.length - 1) {
        continue; // today isn't over
      } else {
        break;
      }
    }
    return n;
  }

  /// The longest run inside the window — the number to beat, which is
  /// the only thing that makes a broken streak worth starting again.
  int get best {
    var run = 0, top = 0;
    for (final d in days) {
      if (banked(d)) {
        run++;
        if (run > top) top = run;
      } else {
        run = 0;
      }
    }
    return top < streak ? streak : top;
  }

  /// Completed days only — today is excluded everywhere a judgement is
  /// being made about a man.
  List<int> get _settled =>
      days.length < 2 ? const [] : days.sublist(0, days.length - 1);

  /// Runs in the armband window, completed days only.
  int runsRecent(String userId) {
    final settled = _settled;
    final from = settled.length > armbandWindow
        ? settled.sublist(settled.length - armbandWindow)
        : settled;
    var n = 0;
    for (final d in from) {
      if (whoRan(d).contains(userId)) n++;
    }
    return n;
  }

  /// Most recent day he ran, or null.
  int? lastRan(String userId) {
    for (var i = days.length - 1; i >= 0; i--) {
      if (whoRan(days[i]).contains(userId)) return days[i];
    }
    return null;
  }

  /// BENCHED — [benchAfterDays] completed days without a run.
  ///
  /// Not kicked. Nobody has to do the socially expensive thing of
  /// removing a friend, the squad stops being dragged down by a man who
  /// isn't there, and his door stays open at the cost of one run.
  bool benched(String userId) {
    final settled = _settled;
    if (settled.length < benchAfterDays) return false;
    final recent = settled.sublist(settled.length - benchAfterDays);
    for (final d in recent) {
      if (whoRan(d).contains(userId)) return false;
    }
    return true;
  }

  List<String> benchedOf(List<String> memberIds) =>
      [for (final id in memberIds) if (benched(id)) id];

  /// THE ARMBAND. Highest run count over the window; ties broken by who
  /// ran most recently, then by id so it can never flicker between two
  /// men on consecutive loads.
  ///
  /// Null when nobody has run at all — an armband handed out for zero
  /// effort is worth nothing and devalues it permanently.
  String? captainOf(List<String> memberIds) {
    String? best;
    var bestRuns = 0;
    var bestLast = 0;
    for (final id in memberIds) {
      final runs = runsRecent(id);
      if (runs == 0) continue;
      final last = lastRan(id) ?? 0;
      final b = best;
      if (b == null ||
          runs > bestRuns ||
          (runs == bestRuns && last > bestLast) ||
          (runs == bestRuns && last == bestLast && id.compareTo(b) < 0)) {
        best = id;
        bestRuns = runs;
        bestLast = last;
      }
    }
    return best;
  }

  /// Who hasn't run today, out of the men who aren't benched. This is
  /// the list the room names out loud — stated as fact, never as an
  /// insult, because the mechanic only works while it stays fair.
  List<String> missingToday(List<String> memberIds) {
    final ran = whoRan(todayYmd);
    return [
      for (final id in memberIds)
        if (!ran.contains(id) && !benched(id)) id,
    ];
  }

  /// The day the last streak died, and who was missing on it. Null when
  /// there's nothing to point at.
  ({int ymd, int run, List<String> missing})? lastBreak(
      List<String> memberIds) {
    // Walk back past the live streak to the first unbanked settled day.
    final settled = _settled;
    var i = settled.length - 1;
    while (i >= 0 && banked(settled[i])) {
      i--;
    }
    if (i < 0) return null;
    final broken = settled[i];
    // How long the run before it was.
    var len = 0;
    for (var j = i - 1; j >= 0 && banked(settled[j]); j--) {
      len++;
    }
    if (len < 2) return null; // a one-day run isn't a loss worth naming
    final ran = whoRan(broken);
    return (
      ymd: broken,
      run: len,
      missing: [for (final id in memberIds) if (!ran.contains(id)) id],
    );
  }

  // ── THE SQUAD SCORE ─────────────────────────────────────────────────
  //
  // One number the five of them are building together, derived from the
  // same daily_attempts read everything else here uses — no migration,
  // no new table, live the moment the build lands.
  //
  // TWO INPUTS, DELIBERATELY:
  //   · every scored attempt by any member  → 20   (individual effort)
  //   · every day the quorum banked         → 100  (the collective act)
  //
  // The banked day is worth five attempts on purpose. A squad where
  // everyone grinds alone and nobody coordinates should score lower
  // than one where they turn up together, because turning up together
  // is the entire product. The score is the reason to drag Tyler back.

  /// Points per individual scored attempt.
  static const ptsPerAttempt = 20;

  /// Points per day the quorum landed.
  static const ptsPerBankedDay = 100;

  int get score {
    var attempts = 0, banks = 0;
    for (final d in days) {
      attempts += whoRan(d).length;
      if (banked(d)) banks++;
    }
    return attempts * ptsPerAttempt + banks * ptsPerBankedDay;
  }

  /// What today has put on the board so far — the "▲ 620 TODAY" line.
  /// A total that never visibly moves is wallpaper; the delta is what
  /// makes a man run one more mission before midnight.
  int get scoreToday {
    final a = ranToday * ptsPerAttempt;
    return a + (todayBanked ? ptsPerBankedDay : 0);
  }

  /// SQUAD LEVEL. Same shape as the personal one in economy.dart —
  /// shallow at the start so a new squad sees movement in week one,
  /// steepening after, so a level means more the higher it goes.
  static const _lvlBase = 500.0;
  static const _lvlStep = 1.18;

  int get level {
    var lvl = 1, guard = 0;
    var cost = _lvlBase, spent = 0.0;
    final s = score;
    while (s >= spent + cost && guard++ < 200) {
      spent += cost;
      cost *= _lvlStep;
      lvl++;
    }
    return lvl;
  }

  /// 0..1 through the current level.
  double get levelProgress {
    var guard = 0;
    var cost = _lvlBase, spent = 0.0;
    final s = score;
    while (s >= spent + cost && guard++ < 200) {
      spent += cost;
      cost *= _lvlStep;
    }
    return ((s - spent) / cost).clamp(0.0, 1.0);
  }

  /// Members who have run today. "4/5 ACTIVE" is the line that tells
  /// him whether he's the one holding it up.
  int get activeToday => ranToday;

    /// A ymd as "12 Aug" for the copy.
  static String pretty(int ymd) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = ymd % 100;
    final m = (ymd ~/ 100) % 100;
    return '$d ${m >= 1 && m <= 12 ? months[m] : ''}'.trim();
  }

  /// The last [n] days for the chain, newest last.
  List<int> tail(int n) =>
      days.length <= n ? days : days.sublist(days.length - n);
}
