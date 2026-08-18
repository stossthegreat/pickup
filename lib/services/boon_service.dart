import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// THE BOONS — what a spin is allowed to pay out.
///
/// A slot machine is the strongest reward schedule ever found, and it is
/// also the easiest thing in the world to build dishonestly. The rule
/// this file exists to enforce: A SPIN MAY NEVER PAY IN ANYTHING EARNED.
///
/// Not scores. Not grades. Not a place on a board. Not a Rolodex card.
/// The moment a wheel can hand him a woman he didn't win, every card he
/// DID win is worth less — and he'll know, because he'll remember which
/// ones he actually earned. One corrupt payout devalues the whole case.
///
/// So the wheel pays in time and position instead:
///
///   WARMTH SHIELD  five extra days before a woman cools. Costs nothing,
///                  changes nothing about who he beat, and is genuinely
///                  wanted the moment he owns more than two cards.
///   HEAD START     his next conversation opens fifteen points warmer.
///                  Makes a hard woman reachable sooner; doesn't make
///                  her easier to keep, because the bar to win her is
///                  untouched.
///   SPIN AGAIN     the jackpot that isn't a prize. A chained spin is
///                  the most exciting outcome on any real machine and it
///                  costs us nothing to give.
///   NOTHING        the most common result, and non-negotiable. A wheel
///                  that always pays is a cutscene. The whole value of
///                  the mechanic is the moment before it lands, and that
///                  moment only exists if losing is real.
class BoonService {
  static const _kHeadStart = 'boon.headstart.v1';

  /// How much warmer his next conversation opens.
  static const headStartPoints = 15;

  /// Days of protection a shield buys.
  static const shieldDays = 5;

  static Future<bool> headStartPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHeadStart) ?? false;
  }

  static Future<void> grantHeadStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHeadStart, true);
  }

  /// Spend it. Returns true if there was one to spend, so the caller can
  /// tell him it was used rather than silently applying a number he
  /// can't account for — an invisible buff is not a reward.
  static Future<bool> takeHeadStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kHeadStart) != true) return false;
    await prefs.remove(_kHeadStart);
    return true;
  }
}

/// The wheel's faces, in the order they sit around it.
enum Boon { nothing, shield, headStart, again }

extension BoonX on Boon {
  String get label => switch (this) {
        Boon.nothing => 'NOTHING',
        Boon.shield => 'WARMTH\nSHIELD',
        Boon.headStart => 'HEAD\nSTART',
        Boon.again => 'SPIN\nAGAIN',
      };

  String get headline => switch (this) {
        Boon.nothing => 'NOTHING THIS TIME',
        Boon.shield => 'WARMTH SHIELD',
        Boon.headStart => 'HEAD START',
        Boon.again => 'SPIN AGAIN',
      };

  String get detail => switch (this) {
        Boon.nothing => 'The wheel owes you nothing. That\'s why it\'s worth spinning.',
        Boon.shield =>
          'Five extra days before she goes cold. Buys you a weekend off.',
        Boon.headStart =>
          'Your next conversation opens fifteen points warmer. She still has to be won.',
        Boon.again => 'Free spin. And this one can\'t land on nothing.',
      };

  /// Relative weight. NOTHING dominates on purpose — see the note above.
  int get weight => switch (this) {
        Boon.nothing => 40,
        Boon.shield => 30,
        Boon.headStart => 20,
        Boon.again => 10,
      };
}

/// Weighted pick. [noBlank] is the guarantee a chained spin carries.
Boon rollBoon({required bool noBlank, math.Random? rng}) {
  final r = rng ?? math.Random();
  final pool = [
    for (final b in Boon.values)
      if (!(noBlank && b == Boon.nothing)) b,
  ];
  // A chained spin also can't chain forever — two free spins in a row is
  // a bug report, not a jackpot.
  final faces = noBlank ? pool.where((b) => b != Boon.again).toList() : pool;
  var total = 0;
  for (final b in faces) {
    total += b.weight;
  }
  var n = r.nextInt(total);
  for (final b in faces) {
    n -= b.weight;
    if (n < 0) return b;
  }
  return faces.last;
}
