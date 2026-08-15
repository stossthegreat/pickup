import 'ascension_service.dart';
import 'backend/squad_history_service.dart';
import 'division.dart';
import 'economy.dart';

/// ══════════════════════════════════════════════════════════════════════
///  STANDING — every ladder in the app, and the one rule that keeps them
///  from lying to each other
/// ══════════════════════════════════════════════════════════════════════
///
/// THE BUG THIS FILE EXISTS TO KILL.
///
/// A man opened Home and read INITIATE. He opened the ascension screen
/// and read OBSERVER. Both were correct, because the app had THREE
/// separate ladders sharing the same five words:
///
///   · tiers.dart      OBSERVER → HIM, gated on rizz_elo.rating
///   · ascension       OBSERVER → BECOME HIM, gated on days shown up
///   · division.dart   BRONZE → LEGEND, gated on rizz_elo.rating
///
/// And rizz_elo.rating was being moved by TWO unrelated things: the
/// score-voice function drifts it up to ±40 on every solo daily, and
/// battle-action swings it on every duel. So one number meant "how well
/// you spoke on your own" and "whether you beat Jake" at the same time,
/// and one of the words for it — INITIATE — could arrive on day two off
/// two good voice sessions while the same word on another screen was
/// forty days of work away.
///
/// He was not confused because he'd misread it. He was confused because
/// it was incoherent.
///
/// ── THE LAW ──────────────────────────────────────────────────────────
///
/// FOUR LADDERS. FOUR SEPARATE VOCABULARIES. NO WORD APPEARS TWICE.
///
/// ┌────────────┬──────────────────────┬───────────────┬──────────────┐
/// │ LADDER     │ WORDS                │ EARNED BY     │ PACE         │
/// ├────────────┼──────────────────────┼───────────────┼──────────────┤
/// │ RANK       │ OBSERVER · INITIATE  │ DAYS SHOWN UP │ 10 days each │
/// │ (identity) │ CONTENDER·DANGEROUS  │ — nothing     │ — cannot be  │
/// │            │ HIM · ELITE ·        │ else          │ rushed, ever │
/// │            │ BECOME HIM           │               │              │
/// ├────────────┼──────────────────────┼───────────────┼──────────────┤
/// │ LEVEL      │ LVL 1 … LVL 99       │ XP (missions) │ days         │
/// ├────────────┼──────────────────────┼───────────────┼──────────────┤
/// │ DIVISION   │ BRONZE III …         │ RR — BATTLES  │ duels        │
/// │            │ LEGEND I             │ ONLY          │              │
/// ├────────────┼──────────────────────┼───────────────┼──────────────┤
/// │ SQUAD LVL  │ SQUAD LVL 1 …        │ the squad's   │ shared       │
/// │            │                      │ own score     │              │
/// └────────────┴──────────────────────┴───────────────┴──────────────┘
///
/// WHY RANK IS DAYS AND NOT PERFORMANCE. Because it's the one thing in
/// the app that's supposed to describe HIM rather than a result, and a
/// description of a man that can be won in an afternoon describes
/// nothing. Ten days per rung means the word he's wearing was paid for
/// in attendance, which is also the only thing that actually changes
/// anyone. It's what the paywall promises, it's what the 60-day map
/// draws, and it cannot jump.
///
/// WHY LEVEL IS ALLOWED TO BE FAST. Different job. RANK is who he is;
/// LEVEL is the needle that has to visibly move today or he stops
/// playing. Every game worth anything runs both — a slow identity and a
/// fast counter — and the mistake was never that LEVEL moved quickly, it
/// was that LEVEL and RANK were wearing each other's clothes.
///
/// NOTHING MAY BE ADDED HERE without answering: which of the four is it,
/// and what word does it use that no other ladder uses?
abstract final class Standing {
  // ══════════════════════════════════════════════════════════════════
  //  RANK — the identity ladder
  // ══════════════════════════════════════════════════════════════════

  /// Days of work per rung. Six rungs above OBSERVER, sixty days.
  static const daysPerRank = 10;

  /// His rank from EARNED DAYS. Not days since install — days he
  /// actually showed up, which is [AscensionSnapshot.ascensionDay].
  static AscendRank rankFor(int earnedDays) =>
      AscensionService.rankFor(earnedDays < 1 ? 1 : earnedDays);

  /// The rung index, 0 (OBSERVER) upward. What milestone detection
  /// compares — a label is a string and strings make bad thresholds.
  static int rungFor(int earnedDays) {
    final d = earnedDays < 1 ? 1 : earnedDays;
    var rung = 0;
    for (final (i, r) in AscensionService.ranks().indexed) {
      if (d >= r.minDay) rung = i;
    }
    return rung;
  }

  /// Days until the next rung, or null at the summit. The line that
  /// turns a status into a target: "4 DAYS TO CONTENDER".
  static int? daysToNextRank(int earnedDays) {
    final d = earnedDays < 1 ? 1 : earnedDays;
    final next = AscensionService.nextRankFor(d);
    if (next == null) return null;
    final gap = next.minDay - d;
    return gap < 1 ? 1 : gap;
  }

  /// "4 DAYS TO CONTENDER" — null at the summit, and null on the day it
  /// lands, because on that day he gets the ceremony instead.
  static String? nextRankLine(int earnedDays) {
    final d = daysToNextRank(earnedDays);
    if (d == null) return null;
    final next = AscensionService.nextRankFor(earnedDays < 1 ? 1 : earnedDays);
    if (next == null) return null;
    return '$d DAY${d == 1 ? '' : 'S'} TO ${next.label}';
  }

  /// 0..1 through the current rung — for the ring under the badge.
  static double rankProgress(int earnedDays) {
    final d = earnedDays < 1 ? 1 : earnedDays;
    final cur = rankFor(d);
    final next = AscensionService.nextRankFor(d);
    if (next == null) return 1;
    final span = next.minDay - cur.minDay;
    if (span <= 0) return 1;
    return ((d - cur.minDay) / span).clamp(0.0, 1.0);
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE OTHER THREE — thin, so screens ask ONE object
  // ══════════════════════════════════════════════════════════════════

  static int levelFor(int totalXp) => Economy.levelFor(totalXp);

  /// DIVISION comes off the BATTLE rating, never the voice one. If the
  /// two ever get crossed again this is the line that did it.
  static Rank divisionFor(int battleRating) => Rank.of(battleRating);

  static int squadLevelOf(SquadHistory h) => h.level;
}
