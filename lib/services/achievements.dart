import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// ══════════════════════════════════════════════════════════════════════
///  ACHIEVEMENTS — badges, and the two rules that stop them being junk
/// ══════════════════════════════════════════════════════════════════════
///
/// Achievements are the right call and they are also the most commonly
/// botched system in mobile products, so this file is opinionated about
/// how.
///
/// HOW THEY FAIL, every time: an app ships eighty of them, most are
/// unreachable, none are visible until they fire, and the trophy screen
/// becomes a grey wall of locks that makes a new user feel behind on day
/// one. The badge stops being a reward and becomes a list of things he
/// hasn't done.
///
/// TWO RULES, and everything below follows from them.
///
/// ── RULE 1: TIERED FAMILIES, NOT ONE-SHOTS ───────────────────────────
/// Ten families of three (BRONZE / SILVER / GOLD) rather than thirty
/// unrelated badges. A family gives THREE wins off one behaviour, the
/// first one is deliberately cheap, and there is always a visible next
/// rung on something he's already doing. That's endowed progress: people
/// finish a card that's already stamped twice, and abandon an empty one.
///
/// ── RULE 2: NOTHING IS SECRET AND NOTHING IS IMPOSSIBLE ──────────────
/// Every badge shows its target and his number against it. No hidden
/// achievements — a reward you didn't know existed can't motivate
/// anything, it can only surprise you once. And no lifetime grinds: the
/// hardest thing in here is reachable inside a couple of months of real
/// use, because a bar nobody can finish is a bar nobody looks at.
///
/// ── WHAT THEY MEASURE ────────────────────────────────────────────────
/// Behaviours, not outcomes he can't control. "Fifty conversations" is
/// his to earn; "beat a LEGEND" depends on who queues. Every family
/// below is something he can decide to do this week.
///
/// The counters are on-device and monotonic — they only ever climb, so
/// nothing here can be lost to a bad day, and none of it waits on a
/// migration or a deploy.
enum Stat {
  /// AI conversations finished, any surface.
  talks,

  /// Real-world approaches (the fear button).
  approaches,

  /// Duels settled.
  duels,

  /// Duels won.
  wins,

  /// Days shown up in a row — mirrors the streak, banked at its peak so
  /// a broken run doesn't erase the badge he already earned.
  streakPeak,

  /// Numbers won off women in the Rolodex.
  numbers,

  /// Dailies completed.
  dailies,

  /// AI scores of 90+.
  nineties,

  /// Days the squad chain was banked while he was in it.
  chain,

  /// Squad nudges sent — the one purely social behaviour worth naming.
  nudges,
}

/// One rung of one family.
///
/// Named Trophy and not Badge because `Badge` is a Material widget —
/// any file that imported both would fail to resolve the name, and this
/// class is meant to be imported by widgets.
class Trophy {
  final Stat stat;
  final int need;
  final String name;
  final String line;
  final Tier tier;
  const Trophy({
    required this.stat,
    required this.need,
    required this.name,
    required this.line,
    required this.tier,
  });

  String get id => '${stat.name}_$need';
}

enum Tier { bronze, silver, gold }

extension TierX on Tier {
  Color get color => switch (this) {
        Tier.bronze => const Color(0xFFB4713C),
        Tier.silver => const Color(0xFFB9C2CC),
        Tier.gold => const Color(0xFFFFC53D),
      };

  Color get shade => switch (this) {
        Tier.bronze => const Color(0xFF6E3F1E),
        Tier.silver => const Color(0xFF6C7683),
        Tier.gold => const Color(0xFF9A6E00),
      };

  String get label => switch (this) {
        Tier.bronze => 'BRONZE',
        Tier.silver => 'SILVER',
        Tier.gold => 'GOLD',
      };
}

/// THE CATALOGUE. Ten families, three rungs each, thirty badges.
///
/// The names are doing real work. "TALKED TO 50 WOMEN" is a statistic;
/// "SILVER TONGUE" is a thing he is, and a thing he'll mention to
/// someone. Every gold rung is a sentence a man would actually say out
/// loud, because the only free marketing this app has is a screenshot.
abstract final class Achievements {
  static const all = <Trophy>[
    // ── TALKING ───────────────────────────────────────────────────────
    Trophy(
        stat: Stat.talks,
        need: 5,
        tier: Tier.bronze,
        name: 'FIRST WORDS',
        line: 'Five conversations. You opened your mouth.'),
    Trophy(
        stat: Stat.talks,
        need: 50,
        tier: Tier.silver,
        name: 'SILVER TONGUE',
        line: 'Fifty conversations. It\'s starting to feel normal.'),
    Trophy(
        stat: Stat.talks,
        need: 250,
        tier: Tier.gold,
        name: 'NEVER STUCK',
        line: 'Two hundred and fifty. You don\'t run out of things to say.'),

    // ── THE REAL WORLD — the family that matters most ─────────────────
    Trophy(
        stat: Stat.approaches,
        need: 1,
        tier: Tier.bronze,
        name: 'THE FIRST ONE',
        line: 'You walked up to somebody. Nothing is ever as hard again.'),
    Trophy(
        stat: Stat.approaches,
        need: 10,
        tier: Tier.silver,
        name: 'NO HESITATION',
        line: 'Ten approaches. The gap between thinking and moving is gone.'),
    Trophy(
        stat: Stat.approaches,
        need: 50,
        tier: Tier.gold,
        name: 'HE JUST GOES',
        line: 'Fifty. Most men never do it once.'),

    // ── BATTLES ───────────────────────────────────────────────────────
    Trophy(
        stat: Stat.duels,
        need: 1,
        tier: Tier.bronze,
        name: 'STEPPED IN',
        line: 'You took a fight against a stranger.'),
    Trophy(
        stat: Stat.wins,
        need: 10,
        tier: Tier.silver,
        name: 'TEN SCALPS',
        line: 'Ten men beaten on the same woman.'),
    Trophy(
        stat: Stat.wins,
        need: 50,
        tier: Tier.gold,
        name: 'THE PROBLEM',
        line: 'Fifty wins. You\'re who they don\'t want to draw.'),

    // ── SHOWING UP ────────────────────────────────────────────────────
    Trophy(
        stat: Stat.streakPeak,
        need: 7,
        tier: Tier.bronze,
        name: 'ONE WEEK',
        line: 'Seven days straight. This is where most people stop.'),
    Trophy(
        stat: Stat.streakPeak,
        need: 30,
        tier: Tier.silver,
        name: 'A MONTH DEEP',
        line: 'Thirty days. It isn\'t a phase any more.'),
    Trophy(
        stat: Stat.streakPeak,
        need: 60,
        tier: Tier.gold,
        name: 'THE FULL CLIMB',
        line: 'Sixty days. You finished the thing you started.'),

    // ── CLOSING ───────────────────────────────────────────────────────
    Trophy(
        stat: Stat.numbers,
        need: 1,
        tier: Tier.bronze,
        name: 'SHE SAID YES',
        line: 'Your first number.'),
    Trophy(
        stat: Stat.numbers,
        need: 5,
        tier: Tier.silver,
        name: 'THE ROLODEX',
        line: 'Five women who wanted to keep talking.'),
    Trophy(
        stat: Stat.numbers,
        need: 10,
        tier: Tier.gold,
        name: 'FULL HOUSE',
        line: 'Every woman in the app. All ten.'),

    // ── THE DAILY ─────────────────────────────────────────────────────
    Trophy(
        stat: Stat.dailies,
        need: 5,
        tier: Tier.bronze,
        name: 'ON THE BOARD',
        line: 'Five dailies. Same woman, same day, everyone watching.'),
    Trophy(
        stat: Stat.dailies,
        need: 25,
        tier: Tier.silver,
        name: 'RELIABLE',
        line: 'Twenty-five. You show up when it counts.'),
    Trophy(
        stat: Stat.dailies,
        need: 100,
        tier: Tier.gold,
        name: 'THE REGULAR',
        line: 'A hundred dailies. Nobody outworked you.'),

    // ── QUALITY ───────────────────────────────────────────────────────
    Trophy(
        stat: Stat.nineties,
        need: 1,
        tier: Tier.bronze,
        name: 'NINETY',
        line: 'One conversation graded 90 or better.'),
    Trophy(
        stat: Stat.nineties,
        need: 10,
        tier: Tier.silver,
        name: 'NO FLUKE',
        line: 'Ten of them. It\'s repeatable now.'),
    Trophy(
        stat: Stat.nineties,
        need: 40,
        tier: Tier.gold,
        name: 'THAT\'S THE LEVEL',
        line: 'Forty. Ninety is just how you talk.'),

    // ── THE SQUAD ─────────────────────────────────────────────────────
    Trophy(
        stat: Stat.chain,
        need: 7,
        tier: Tier.bronze,
        name: 'LINK IN THE CHAIN',
        line: 'Seven days your squad banked with you in it.'),
    Trophy(
        stat: Stat.chain,
        need: 30,
        tier: Tier.silver,
        name: 'NEVER THE WEAK ONE',
        line: 'Thirty. Nobody has ever been waiting on you.'),
    Trophy(
        stat: Stat.chain,
        need: 90,
        tier: Tier.gold,
        name: 'UNBREAKABLE',
        line: 'Ninety days of a chain you helped hold.'),

    Trophy(
        stat: Stat.nudges,
        need: 5,
        tier: Tier.bronze,
        name: 'DRAGGED HIM BACK',
        line: 'Five nudges. You noticed someone had gone quiet.'),
    Trophy(
        stat: Stat.nudges,
        need: 25,
        tier: Tier.silver,
        name: 'THE CAPTAIN',
        line: 'Twenty-five. The squad runs because you run it.'),

    // ── THE LONG ONE ──────────────────────────────────────────────────
    Trophy(
        stat: Stat.talks,
        need: 500,
        tier: Tier.gold,
        name: 'FIVE HUNDRED',
        line: 'Five hundred conversations. You are not the same man.'),
  ];

  static List<Trophy> family(Stat s) =>
      [for (final b in all) if (b.stat == s) b]..sort((a, b) => a.need - b.need);

  // ══════════════════════════════════════════════════════════════════
  //  COUNTERS
  // ══════════════════════════════════════════════════════════════════

  static const _kStats = 'ach.stats.v1';
  static const _kEarned = 'ach.earned.v1';

  static Future<Map<String, int>> _stats() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStats);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          '${e.key}': (e.value is num) ? (e.value as num).toInt() : 0
      };
    } catch (_) {
      return {};
    }
  }

  static Future<int> valueOf(Stat s) async => (await _stats())[s.name] ?? 0;

  /// Add to a counter and return any badges it just earned.
  ///
  /// Counters only ever climb. A man who loses a streak keeps ONE WEEK,
  /// because he did earn it, and taking it back would make every badge
  /// in the app feel like a loan.
  static Future<List<Trophy>> bump(Stat s, [int by = 1]) async {
    final stats = await _stats();
    final next = (stats[s.name] ?? 0) + by;
    return _write(s, next, stats);
  }

  /// Set a counter to a high-water mark — for stats that are a PEAK
  /// rather than a tally, like the streak.
  static Future<List<Trophy>> raiseTo(Stat s, int value) async {
    final stats = await _stats();
    if ((stats[s.name] ?? 0) >= value) return const [];
    return _write(s, value, stats);
  }

  /// The last counter that moved, parked for the payout screen so the
  /// badge bar can animate FROM where it was rather than appearing at
  /// its new value. A bar that jumps is a fact; a bar you watch move is
  /// a reward.
  static ({Stat stat, int before, int after})? lastBump;

  static Future<List<Trophy>> _write(
      Stat s, int next, Map<String, int> stats) async {
    lastBump = (stat: s, before: stats[s.name] ?? 0, after: next);
    final p = await SharedPreferences.getInstance();
    stats[s.name] = next;
    await p.setString(_kStats, jsonEncode(stats));

    final earned = (p.getStringList(_kEarned) ?? const <String>[]).toSet();
    final fresh = <Trophy>[];
    for (final b in family(s)) {
      if (next >= b.need && !earned.contains(b.id)) {
        earned.add(b.id);
        fresh.add(b);
      }
    }
    if (fresh.isNotEmpty) {
      await p.setStringList(_kEarned, earned.toList());
    }
    return fresh;
  }

  static Future<Set<String>> earned() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_kEarned) ?? const <String>[]).toSet();
  }

  /// THE NEXT ONE. The single badge he is closest to finishing, among
  /// those he's already made a start on.
  ///
  /// This is the most important function in the file and it's why the
  /// families are tiered. A trophy shelf is a museum; ONE named badge
  /// with "8 / 10" under it is a task. The shelf gets browsed once; the
  /// next-one line gets acted on.
  static Future<({Trophy trophy, int have})?> next() async {
    final stats = await _stats();
    final done = await earned();
    ({Trophy trophy, int have})? best;
    var bestFrac = -1.0;
    for (final b in all) {
      if (done.contains(b.id)) continue;
      final have = stats[b.stat.name] ?? 0;
      if (have <= 0) continue; // not started — don't nag about it
      final frac = have / b.need;
      if (frac > bestFrac) {
        bestFrac = frac;
        best = (trophy: b, have: have);
      }
    }
    // Nothing started at all — point him at the cheapest thing there is
    // rather than showing nothing, because "0 of 30 badges" on day one
    // is the exact feeling this system has to avoid.
    if (best == null) {
      final first = all.firstWhere((b) => b.stat == Stat.talks);
      return (trophy: first, have: 0);
    }
    return best;
  }

  /// Progress on one badge, 0..1.
  static Future<double> progressOf(Trophy b) async {
    final have = (await _stats())[b.stat.name] ?? 0;
    return (have / b.need).clamp(0.0, 1.0);
  }

  static Future<({int earned, int total})> tally() async {
    final done = await earned();
    return (earned: done.length, total: all.length);
  }
}
