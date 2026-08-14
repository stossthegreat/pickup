import 'dart:ui';

import 'economy.dart';

/// DIVISIONS — the ranked identity for RIZZ RATING.
///
/// RR was an invisible integer. A number with no name attached is a
/// measurement; a number with GOLD II attached is a place you live, and
/// men will grind for months to move house. Every ranked game worth
/// anything has learned this and none of them ship a bare number.
///
/// SEVEN TIERS, THREE STEPS EACH, so there are twenty-one rungs between
/// the floor and the summit. That granularity is deliberate: at three
/// wins per promotion the ladder always has a visible next rung, which
/// is the difference between "I'm 1,284" and "I'm 72 off Gold I."
///
/// A NOTE ON THE OTHER LADDER — AND WHY THIS ISN'T A SECOND ONE.
///
/// tiers.dart carries OBSERVER → HIM: five names, the ones the paywall
/// sells and the Home rank pill prints. This carries seven divisions and
/// twenty-one rungs. They are NOT two ladders, because they are computed
/// from the same integer: the RR in rizz_elo, which only the scoring
/// Edge Function can write.
///
/// It's one ladder at two zoom levels. OBSERVER → HIM is the coarse
/// public name — the thing he tells people he is, and the thing he
/// bought. BRONZE III → LEGEND I is the competitive readout, fine enough
/// that a duel he wins tonight visibly moves him.
///
/// That distinction is deliberate, not a compromise. Five rungs across a
/// 2,000-point range means a man can win nine duels in a row and watch
/// the same word sit there — which is precisely how a ranked system dies.
/// Twenty-one rungs means there is always a next one, and the Battles
/// hero prints the tier name underneath the division so he can see with
/// his own eyes that they're the same climb.
enum Div { bronze, silver, gold, platinum, diamond, master, legend }

extension DivX on Div {
  String get label => switch (this) {
        Div.bronze => 'BRONZE',
        Div.silver => 'SILVER',
        Div.gold => 'GOLD',
        Div.platinum => 'PLATINUM',
        Div.diamond => 'DIAMOND',
        Div.master => 'MASTER',
        Div.legend => 'LEGEND',
      };

  /// The RR floor for step III of this division.
  int get floor => switch (this) {
        Div.bronze => 0,
        Div.silver => 1100,
        Div.gold => 1300,
        Div.platinum => 1500,
        Div.diamond => 1700,
        Div.master => 1900,
        Div.legend => 2100,
      };

  /// Width of the whole division in RR. Legend is open-ended — there is
  /// no rung above it and there shouldn't be.
  int get span => switch (this) {
        Div.bronze => 1100,
        Div.legend => 600,
        _ => 200,
      };

  Color get color => switch (this) {
        Div.bronze => const Color(0xFFB4713C),
        Div.silver => const Color(0xFFB9C2CC),
        Div.gold => const Color(0xFFFFC53D),
        Div.platinum => const Color(0xFF5EE7C6),
        Div.diamond => const Color(0xFF56C7FF),
        Div.master => const Color(0xFFC084FC),
        Div.legend => const Color(0xFFFF4757),
      };

  /// Second colour for the emblem's metal gradient. A flat fill reads as
  /// a swatch; two stops read as a cast object.
  Color get shade => switch (this) {
        Div.bronze => const Color(0xFF6E3F1E),
        Div.silver => const Color(0xFF6C7683),
        Div.gold => const Color(0xFF9A6E00),
        Div.platinum => const Color(0xFF1E8B78),
        Div.diamond => const Color(0xFF1B6FA8),
        Div.master => const Color(0xFF6B2FA8),
        Div.legend => const Color(0xFF8B0F1A),
      };

  bool get glows => index >= Div.diamond.index;
}

/// A man's exact standing: division, step (3 → 1, lowest to highest),
/// and how far to the next rung.
class Rank {
  final Div div;

  /// 3, 2 or 1. III is the entry step, I is the top — the convention
  /// every ranked game uses, and it means promotion counts DOWN, which
  /// reads as closing in.
  final int step;

  final int rating;

  const Rank({required this.div, required this.step, required this.rating});

  static Rank of(int rating) {
    var d = Div.bronze;
    for (final x in Div.values) {
      if (rating >= x.floor) d = x;
    }
    final into = rating - d.floor;
    final third = d.span / 3;
    // Clamped so the top of Legend doesn't fall off the end of the enum.
    final s = 3 - (into ~/ third).clamp(0, 2);
    return Rank(div: d, step: s, rating: rating);
  }

  /// "GOLD II"
  String get label => '${div.label} ${_roman(step)}';

  /// "II" on its own — what the emblem paints inside the plate.
  ///
  /// Public because Dart privacy is per-LIBRARY, not per-class: the
  /// painter lives in another file and cannot see [_roman] no matter
  /// what class it hangs off.
  String get stepLabel => _roman(step);

  /// The rung, 0 (BRONZE III) to 20 (LEGEND I). One integer that orders
  /// the whole ladder, so promotion is a comparison rather than a pair
  /// of nested checks.
  int get rung => div.index * 3 + (3 - step);

  /// RR at which the next rung opens. Null at the summit.
  int? get nextAt {
    if (div == Div.legend && step == 1) return null;
    final third = (div.span / 3).round();
    if (step > 1) return div.floor + (4 - step) * third;
    final next = Div.values[div.index + 1];
    return next.floor;
  }

  /// "72 RR TO GOLD I" — the line that turns a number into a target.
  /// A rating with no next rung named is just a stat.
  String? get toNext {
    final at = nextAt;
    if (at == null) return null;
    final gap = at - rating;
    if (gap <= 0) return null;
    final ahead = Rank.of(at);
    return '$gap ${Economy.rrShort} TO ${ahead.label}';
  }

  /// 0..1 through the current rung — for the emblem's arc.
  double get progress {
    final at = nextAt;
    if (at == null) return 1;
    final third = (div.span / 3).round();
    final from = at - third;
    if (at <= from) return 1;
    return ((rating - from) / (at - from)).clamp(0.0, 1.0);
  }

  static String _roman(int s) => switch (s) { 1 => 'I', 2 => 'II', _ => 'III' };
}

/// ══════════════════════════════════════════════════════════════════════
///  WIN STREAKS — the thing that puts tension in a button
/// ══════════════════════════════════════════════════════════════════════
///
/// A ranked ladder gives every match a consequence. A win streak gives
/// the NEXT match a consequence, which is a different and stronger
/// thing: it converts "I could play" into "I have something to lose."
///
/// The names matter more than the number. "5 wins" is a stat.
/// "DOMINATING" is a description of him, and he'll queue again to keep
/// being described that way.
abstract final class Streaks {
  static String? title(int n) {
    if (n >= 10) return 'UNTOUCHABLE';
    if (n >= 5) return 'DOMINATING';
    if (n >= 3) return 'ON FIRE';
    if (n >= 2) return 'WIN STREAK';
    return null;
  }

  static String? emoji(int n) {
    if (n >= 10) return '👑';
    if (n >= 5) return '⚡';
    if (n >= 2) return '🔥';
    return null;
  }

  /// The line on the queue button when there's something on the line.
  /// Only from three — threatening a man with a two-game streak reads
  /// as desperate, and the mechanic only works while it's credible.
  static String? onTheLine(int n) =>
      n >= 3 ? '$n WIN STREAK ON THE LINE' : null;
}

/// ══════════════════════════════════════════════════════════════════════
///  STAKES
/// ══════════════════════════════════════════════════════════════════════
///
/// Elo, shown BEFORE the match rather than after. "WIN +31 / LOSE −14"
/// against a higher-ranked man is the single line that turns an AI
/// conversation into something with consequences — he can see he's the
/// underdog and that the upside is asymmetric, which is exactly when
/// people play.
abstract final class Stakes {
  /// Standard Elo. K of 32 is the chess default and moves a new man's
  /// rating fast enough that his first ten games actually place him,
  /// which is the whole job of a provisional period.
  static const k = 32;

  static ({int win, int lose}) forMatch({
    required int mine,
    required int theirs,
  }) {
    final expected = 1 / (1 + _pow10((theirs - mine) / 400));
    final win = (k * (1 - expected)).round();
    final lose = (k * (0 - expected)).round();
    return (win: win < 1 ? 1 : win, lose: lose > -1 ? -1 : lose);
  }

  /// Underdog by enough that it's worth saying so out loud.
  static bool underdog({required int mine, required int theirs}) =>
      theirs - mine >= 75;

  static double _pow10(double e) {
    // 10^e without dart:math — this file is imported by widgets and
    // painters and shouldn't drag maths in for one call.
    var r = 1.0;
    final neg = e < 0;
    var n = neg ? -e : e;
    while (n >= 1) {
      r *= 10;
      n -= 1;
    }
    // Fractional part via a short series that's plenty accurate for a
    // number we render as a whole integer.
    r *= 1 + n * 2.302585 + n * n * 2.650949 + n * n * n * 2.034678;
    return neg ? 1 / r : r;
  }
}
