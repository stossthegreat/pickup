import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'tactics.dart';

/// ══════════════════════════════════════════════════════════════════════
///  MILESTONES — the part that was missing
/// ══════════════════════════════════════════════════════════════════════
///
/// "I just went up a level in one day and there was no reveal."
///
/// That is the whole problem with the app's gamification stated in one
/// sentence, and it isn't a UI problem. The app HAD levels, ranks,
/// divisions and squad levels. Every one of them changed silently, in a
/// number that redraws itself the next time you happen to look at the
/// right pill. A number that changes while you aren't watching did not
/// happen.
///
/// THE RESEARCH, in one line each:
///
///  · The reward has to be MARKED. Dopamine tracks prediction error —
///    the gap between what you expected and what arrived. A counter
///    ticking from 4 to 5 has no gap in it. A screen that stops
///    everything, goes dark, and hands you the number does.
///
///  · PEAK-END. People remember an experience by its most intense
///    moment and its last one, not its average. Levelling up IS the
///    natural peak of a session, and the app was letting it happen off
///    screen — which means sessions had no peak at all.
///
///  · CELEBRATION IS THE PRICE OF THE NEXT ASK. Every product that
///    successfully asks people to come back tomorrow pays them at the
///    end of today. Duolingo's whole loop is a lesson followed by a
///    thirty-second party.
///
/// WHAT THIS DOES. It watches three of the four ladders (see
/// standing.dart — division belongs to the battle verdict), notices
/// crossings, and queues them. It does NOT decide what they look like —
/// ascend_reveal.dart does that. It also survives being wrong: a first
/// run records where you already are and celebrates nothing, so an
/// update can never ambush a man with six levels he earned last month.
class MilestoneService {
  static const _kLevel = 'ms.level.v1';
  static const _kRung = 'ms.rank_rung.v1';
  static const _kSquad = 'ms.squad_level.v1';
  static const _kStreak = 'ms.streak.v1';

  /// Queue of milestones earned but not yet shown. A man who completes
  /// his fifth mission, banks the chain and ranks up in one tap should
  /// see all three, one after the other — not whichever the last
  /// setState happened to catch.
  static final List<Milestone> _pending = [];

  static List<Milestone> get pending => List.unmodifiable(_pending);
  static bool get hasPending => _pending.isNotEmpty;

  /// Take the next one to show, or null. Removing it here means a
  /// screen that gets disposed mid-ceremony loses that one moment
  /// rather than looping it forever.
  static Milestone? take() => _pending.isEmpty ? null : _pending.removeAt(0);

  static void clear() => _pending.clear();

  /// Queue earned trophies. Called by whatever bumped the counter — the
  /// achievement engine returns what it just unlocked and this is where
  /// those turn into moments.
  ///
  /// Trophies go to the FRONT. A badge is the rarest thing a single
  /// action can produce, and making a man sit through a routine level-up
  /// before he sees GOLD gets the order of the evening wrong.
  static void pushTrophies(List<Trophy> earned) {
    if (earned.isEmpty) return;
    _pending.insertAll(0, [
      for (final t in earned)
        Milestone(
          kind: MilestoneKind.badge,
          title: t.name,
          sub: '${t.tier.label} · ${t.stat.name.toUpperCase()}',
          value: t.need,
          trophy: t,
        )
    ]);
  }

  /// Queue newly discovered tactics.
  ///
  /// Front of the queue, same as trophies: a man who just found out the
  /// thing he did has a NAME shouldn't have to sit through a level-up
  /// first. Discovery is the whole teaching mechanic — see tactics.dart.
  static void pushTactics(List<Tactic> found) {
    if (found.isEmpty) return;
    // ONE celebration per session end, not a gauntlet. A good first
    // conversation can legitimately demonstrate five tactics at once —
    // and five full-screen reveals in a row is a punishment, not a
    // reward (founder got hit with exactly that). Tactics.claim() has
    // ALREADY banked every discovery into the cabinet, so nothing is
    // lost: the best one gets the moment, the rest are waiting in the
    // collection — and undiscovered ones will re-fire on a later
    // conversation anyway.
    final t = found.first;
    _pending.insert(0,
        Milestone(
          kind: MilestoneKind.tactic,
          title: t.name,
          sub: 'TACTIC DISCOVERED',
          value: 0,
          tactic: t,
        ));
  }

  // ══════════════════════════════════════════════════════════════════
  //  DETECTION
  // ══════════════════════════════════════════════════════════════════

  /// Feed it what you own, get back whatever crossed.
  ///
  /// EVERY LADDER IS OPTIONAL, and that is load-bearing rather than
  /// convenience. Each has exactly ONE owner — Home does level and rank,
  /// the battle verdict does division, squad home does the squad — and
  /// an owner passes only its own. A screen that passed a placeholder
  /// for a ladder it doesn't own would drag that ladder's high-water
  /// mark down with it and re-fire the whole climb on the next check.
  static Future<List<Milestone>> check({
    int? level,
    int? rankRung,
    String? rankLabel,
    int? squadLevel,
    int? streak,
  }) async {
    final p = await SharedPreferences.getInstance();
    final found = <Milestone>[];

    // ── LEVEL ────────────────────────────────────────────────────────
    if (level != null) {
      final wasLevel = p.getInt(_kLevel);
      if (wasLevel == null) {
        await p.setInt(_kLevel, level);
      } else if (level > wasLevel) {
        await p.setInt(_kLevel, level);
        // Only the one he landed on. Crossing three levels at once is a
        // reason for one big moment, not three identical ones.
        found.add(Milestone(
          kind: MilestoneKind.level,
          title: 'LEVEL $level',
          sub: wasLevel + 1 == level
              ? 'LEVEL $wasLevel → $level'
              : '${level - wasLevel} LEVELS IN ONE GO',
          value: level,
        ));
      } else if (level < wasLevel) {
        // Can't happen with XP, but a wiped install shouldn't leave a
        // stale high-water mark that suppresses the next real level.
        await p.setInt(_kLevel, level);
      }
    }

    // ── RANK — the identity ladder, ten days a rung ──────────────────
    if (rankRung != null && rankLabel != null) {
      final wasRung = p.getInt(_kRung);
      if (wasRung == null) {
        await p.setInt(_kRung, rankRung);
      } else if (rankRung > wasRung) {
        await p.setInt(_kRung, rankRung);
        found.add(Milestone(
          kind: MilestoneKind.rank,
          title: rankLabel,
          sub: 'TEN DAYS OF WORK',
          value: rankRung,
        ));
      }
    }

    // ── THE DAY ──────────────────────────────────────────────────────
    //
    // The strongest mechanic in the app and the least celebrated: the
    // streak ticked from 6 to 7 inside a pill. It gets its own ceremony
    // now — see day_won.dart, where the fire is drawn from the run so
    // day 40 is visibly bigger than day 4.
    if (streak != null) {
      final was = p.getInt(_kStreak);
      if (was == null) {
        await p.setInt(_kStreak, streak);
      } else if (streak > was) {
        await p.setInt(_kStreak, streak);
        found.add(Milestone(
          kind: MilestoneKind.day,
          title: 'DAY $streak',
          sub: 'ANOTHER ONE BANKED',
          value: streak,
        ));
      } else if (streak < was) {
        // A broken run. Silent — the rescue and the shield own that
        // moment, and a "you lost it" ceremony on top of theirs would
        // be the app kicking a man who already knows.
        await p.setInt(_kStreak, streak);
      }
    }

    // ── SQUAD LEVEL — theirs, not his ────────────────────────────────
    if (squadLevel != null) {
      final wasSquad = p.getInt(_kSquad);
      if (wasSquad == null) {
        await p.setInt(_kSquad, squadLevel);
      } else if (squadLevel > wasSquad) {
        await p.setInt(_kSquad, squadLevel);
        found.add(Milestone(
          kind: MilestoneKind.squad,
          title: 'SQUAD LEVEL $squadLevel',
          // Deliberately plural. The one number in the app he did not
          // earn on his own, and the copy has to say so or the squad
          // stops feeling like a squad.
          sub: 'YOU ALL DID THAT',
          value: squadLevel,
        ));
      } else if (squadLevel < wasSquad) {
        await p.setInt(_kSquad, squadLevel);
      }
    }

    _pending.addAll(found);
    return found;
  }

  /// Wipe the high-water marks. Debug only — shipping a way for a man
  /// to re-trigger his own ceremonies would make them worthless.
  static Future<void> reset() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_kLevel, _kRung, _kSquad, _kStreak]) {
      await p.remove(k);
    }
    _pending.clear();
  }
}

/// Division promotions are deliberately absent: the
/// battle verdict already celebrates one in context, mid-fight, with the
/// rating climbing and the streak on screen — and a second, thinner
/// celebration for the same event on the next Home load would cheapen
/// both. One owner per ladder, and division's owner is the verdict.
enum MilestoneKind { level, rank, squad, badge, day, tactic }

class Milestone {
  final MilestoneKind kind;

  /// The big words. 'LEVEL 12', 'CONTENDER', 'GOLD II'.
  final String title;

  /// The small line under them.
  final String sub;

  /// The rung/level itself, for anything that needs to scale its
  /// production to how big a deal this is.
  final int value;

  /// Set only on [MilestoneKind.badge] — the reveal paints the medal
  /// instead of a word.
  final Trophy? trophy;

  /// Set only on [MilestoneKind.tactic] — the reveal shows the mechanic,
  /// why it works, and the line of his own that unlocked it.
  final Tactic? tactic;

  const Milestone({
    required this.kind,
    required this.title,
    required this.sub,
    required this.value,
    this.trophy,
    this.tactic,
  });

  /// RANK is the rare one — six of them in sixty days — so it gets the
  /// longest ceremony and the loudest sound, and a GOLD trophy earns the
  /// same treatment. A level-up every couple of days cannot hold the
  /// screen for six seconds without becoming the thing he dreads between
  /// missions.
  bool get isMajor =>
      kind == MilestoneKind.rank || trophy?.tier == Tier.gold;
}
