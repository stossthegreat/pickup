import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'paywall_gate.dart';
import 'streak_service.dart';

/// THE RESCUE — the one feature that stops a man deleting the app.
///
/// Losing a long streak is the single biggest churn event in any app
/// built on one, and we made it worse on purpose: since b123 the streak
/// and the 60-day ascension day are the same number, so one missed
/// Tuesday doesn't cost a flame, it costs the whole climb. That coupling
/// is what makes showing up mean anything, and it's also exactly the
/// moment a man decides the app is a waste of time and goes.
///
/// So there's a door out — and it is deliberately NOT a free one.
///
/// WHY IT'S CAPPED EVEN FOR SUBSCRIBERS: a rescue you can always use
/// isn't a rescue, it's a setting that turns the streak off. The number
/// only means something because it can die, and a man who knows he can
/// always buy his way back has nothing at stake on a Tuesday night. One
/// a month free, one a week on Pro. Enough that a genuine bad day
/// doesn't end the run; never enough to stop caring.
///
/// WHAT IT WILL NOT DO: rescue a gap of more than one day, or reach
/// further back than yesterday. Two missed days isn't a slip, it's a
/// stop, and a streak that survives a fortnight away is a lie the whole
/// leaderboard has to carry.
class StreakRescue {
  static const _kUsed = 'streak.rescue.used.ymds';

  /// A rescue puts the missed day into the active set, tagged so we can
  /// always tell a bought day from an earned one.
  static const _kRescued = 'streak.rescue.days';

  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Yesterday, the only day a rescue can ever reach.
  static int _yesterday() =>
      _ymd(DateTime.now().subtract(const Duration(days: 1)));

  /// Is there a break worth offering to fix?
  ///
  /// True only when yesterday was missed AND the day before it was
  /// active — i.e. a live run that stopped one day ago. Anything longer
  /// is not a slip and gets no offer.
  static Future<RescueOffer?> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final days = await StreakService.activeDays();
      final y = _yesterday();
      final dayBefore =
          _ymd(DateTime.now().subtract(const Duration(days: 2)));
      final today = _ymd(DateTime.now());

      // Already active yesterday → nothing broke.
      if (days.contains(y)) return null;
      // Nothing before it either → he isn't mid-run, he's starting.
      if (!days.contains(dayBefore)) return null;
      // Already rescued this break.
      final rescued = prefs.getStringList(_kRescued) ?? const [];
      if (rescued.contains('$y')) return null;

      // How long the run was before it stopped — this is what he's
      // being asked to save, and naming it is most of the persuasion.
      var run = 0;
      var d = DateTime.now().subtract(const Duration(days: 2));
      while (days.contains(_ymd(d))) {
        run++;
        d = d.subtract(const Duration(days: 1));
      }
      if (run < 2) return null; // a two-day run isn't worth a rescue

      final pro = await PaywallGate.isPro();
      final used = prefs.getStringList(_kUsed) ?? const [];
      final window = pro ? 7 : 31;
      final cutoff = _ymd(DateTime.now().subtract(Duration(days: window)));
      final recent =
          used.where((s) => (int.tryParse(s) ?? 0) >= cutoff).length;

      return RescueOffer(
        lostDay: y,
        runLength: run,
        available: recent < 1,
        isPro: pro,
        todayYmd: today,
      );
    } catch (e) {
      debugPrint('StreakRescue.check: $e');
      return null;
    }
  }

  /// Spend the rescue. Writes yesterday into the active-day set so the
  /// run reconnects, and records both the spend (for the cap) and the
  /// fact that this particular day was bought rather than earned.
  static Future<bool> spend(RescueOffer offer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!offer.available) return false;

      await StreakService.markDayActive(offer.lostDay);

      final used = [...(prefs.getStringList(_kUsed) ?? const <String>[])];
      used.add('${offer.todayYmd}');
      await prefs.setStringList(_kUsed, used);

      final rescued = [...(prefs.getStringList(_kRescued) ?? const <String>[])];
      rescued.add('${offer.lostDay}');
      await prefs.setStringList(_kRescued, rescued);
      return true;
    } catch (e) {
      debugPrint('StreakRescue.spend: $e');
      return false;
    }
  }

  /// Days that were bought, not earned. Consistency deliberately still
  /// counts them as zero-mission days — the streak survives, the honest
  /// score doesn't pretend work happened.
  static Future<Set<int>> rescuedDays() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final s in prefs.getStringList(_kRescued) ?? const <String>[])
        if (int.tryParse(s) != null) int.parse(s)
    };
  }
}

/// A live break, and whether he can do anything about it.
class RescueOffer {
  /// The missed day, in YYYYMMDD form.
  final int lostDay;

  /// How many consecutive days the run had reached before it stopped.
  /// This is the number on the sheet — it's what he's about to lose.
  final int runLength;

  /// False when he's already spent his rescue inside the window.
  final bool available;
  final bool isPro;
  final int todayYmd;

  const RescueOffer({
    required this.lostDay,
    required this.runLength,
    required this.available,
    required this.isPro,
    required this.todayYmd,
  });
}
