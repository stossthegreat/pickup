/// THE ECONOMY — four numbers, and nothing else may exist.
///
/// This file is the law. Before it, the app was showing a man EIGHT
/// different quantities and asking him to hold them all in his head:
/// XP, a 0–100 chat score, a four-digit voice score, a "/10" voice
/// score, PTS, ELO, Squad Form and a streak. Every one of them was
/// individually defensible. Together they were noise, and noise is what
/// makes a pile of good screens feel like a pile of good screens rather
/// than a game.
///
/// A player can hold four currencies. He cannot hold eight. So:
///
/// ┌──────────────┬───────────────┬──────────────────┬────────────────┐
/// │ NUMBER       │ EARNED BY     │ DRIVES           │ SCALE          │
/// ├──────────────┼───────────────┼──────────────────┼────────────────┤
/// │ XP           │ missions      │ LEVEL            │ unbounded      │
/// │ RIZZ RATING  │ BATTLES ONLY  │ LEAGUE           │ ~1000–2000     │
/// │ AI SCORE     │ one attempt   │ nothing — it IS  │ 0–100          │
/// │              │               │ the performance  │                │
/// │ CHAIN        │ the squad     │ accountability   │ days           │
/// └──────────────┴───────────────┴──────────────────┴────────────────┘
///
/// THE FOUR RULES, IN ORDER OF HOW BADLY BREAKING THEM HURTS:
///
///  1. RIZZ RATING COMES FROM BATTLES AND NOTHING ELSE.
///     The instant a mission, a streak, a purchase or a daily bonus can
///     move RR, the league stops measuring skill and starts measuring
///     attendance — and a ladder that measures attendance is one nobody
///     respects, including the people at the top of it. Missions pay XP.
///     Only a standardised, blind, same-woman duel pays RR.
///
///  2. AI SCORE IS ALWAYS OUT OF 100. NEVER FOUR DIGITS, NEVER OUT OF 10.
///     The grader stores voice at 0–9999 for resolution. That is a
///     storage detail and it has been leaking onto screens for months —
///     a man saw 2,450 in a battle and 8.7 on his daily and had no way
///     to know they were the same kind of number. One scale, everywhere:
///     YOU 81 — 74 JAKE.
///
///  3. XP NEVER COMPETES. It is progression, it only goes up, and it is
///     therefore the safe place to reward the thing we most want and
///     can least verify: real-world approaches. A real mission pays
///     roughly 3–4× an AI one, because AI practice is TRAINING and a
///     real conversation is PROOF, and the whole product only means
///     anything if that difference is expressed somewhere.
///
///  4. THE CHAIN IS THE SQUAD'S, NOT HIS. It is the only number in the
///     app another man can cost you, which is exactly why it works.
///
/// THE SPINE, which every screen should be legible against:
///
///     TRAIN  (AI missions, practice)   → XP
///     PROVE  (real-world missions)     → XP, ×3
///     COMPETE(battles, the daily)      → RIZZ RATING
///
/// Anything that doesn't sit on that line is decoration and should be
/// cut rather than defended.
library;

abstract final class Economy {
  // ── Names. Used everywhere so a rename is one edit, and so no screen
  // can quietly invent its own word for a number that already has one.
  static const rrLong = 'RIZZ RATING';
  static const rrShort = 'RR';
  static const xpShort = 'XP';
  static const aiScoreLabel = 'AI SCORE';
  static const aiScaleLabel = 'OUT OF 100';

  /// The band the voice grader stores on. A storage detail — see rule 2.
  static const voiceRaw = 9999;

  /// Raw voice score (0–9999) → the only scale users ever see.
  ///
  /// Rounded, not truncated to a decimal: "81" is a score, "8.1" is a
  /// rating out of ten, and having both in one app was half the
  /// confusion this file exists to end.
  static int aiScoreFromVoice(int raw) =>
      (raw / 99.99).round().clamp(0, 100);

  /// Chat already grades 0–100. Here so call sites never have to know
  /// which surface they're on — they just ask the economy.
  static int aiScoreFromChat(int raw) => raw.clamp(0, 100);

  /// Display string for a possibly-missing score.
  static String show(int? score) => score == null ? '—' : '$score';

  /// "+22 RR" / "−18 RR". The sign is the point: an RR line with no
  /// direction is a stat, and with one it's an outcome.
  static String rrDelta(int delta) {
    if (delta == 0) return '0 $rrShort';
    return '${delta > 0 ? '+' : '−'}${delta.abs()} $rrShort';
  }

  /// "1,438 RR"
  static String rr(int rating) => '${commas(rating)} $rrShort';

  /// "2,840 XP"
  static String xp(int amount) => '${commas(amount)} $xpShort';

  /// Thousands separator. Public because screens legitimately need the
  /// bare number when they're already showing the unit beside it.
  static String commas(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$b';
  }

  /// LEVEL from XP. Deliberately shallow early and slow later: the first
  /// three levels should arrive inside the first session, because a
  /// progression bar that hasn't moved by the end of day one is a
  /// progression bar he never sees move at all.
  ///
  /// 250 XP for level 2, then each level costs 15% more than the last.
  static int levelFor(int totalXp) {
    var level = 1;
    var cost = 250.0;
    var spent = 0.0;
    while (totalXp >= spent + cost && level < 99) {
      spent += cost;
      cost *= 1.15;
      level++;
    }
    return level;
  }

  /// 0..1 through the current level — the bar, not the badge.
  static double levelProgress(int totalXp) {
    var level = 1;
    var cost = 250.0;
    var spent = 0.0;
    while (totalXp >= spent + cost && level < 99) {
      spent += cost;
      cost *= 1.15;
      level++;
    }
    if (level >= 99) return 1;
    return ((totalXp - spent) / cost).clamp(0.0, 1.0);
  }

  /// XP still owed for the next level. "180 to LVL 13" outperforms a
  /// bar with no number on it, because a bar is a feeling and a number
  /// is a plan.
  static int xpToNext(int totalXp) {
    var level = 1;
    var cost = 250.0;
    var spent = 0.0;
    while (totalXp >= spent + cost && level < 99) {
      spent += cost;
      cost *= 1.15;
      level++;
    }
    return (spent + cost - totalXp).round().clamp(0, 1 << 30);
  }
}
