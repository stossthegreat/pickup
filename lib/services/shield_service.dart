import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streak_service.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE SHIELD — the mechanic almost nobody copies correctly
/// ══════════════════════════════════════════════════════════════════════
///
/// Duolingo's Streak Freeze cut churn by roughly a fifth among users who
/// were about to break a streak. Every product on the store has copied
/// the idea. Almost none of them copied the part that makes it work:
///
///   THE PROTECTION DEPLOYS WITHOUT A DECISION.
///
/// That single design choice is the whole thing. If a shield is
/// something you BUY, the men who buy it are the ones organised enough
/// not to need it, and the at-risk man — distracted, busy, halfway to
/// gone — is empty-handed at the exact moment protection would have
/// saved him. If a shield is something you're PROMPTED to spend, you
/// have to already be in the app to use it, which is precisely what
/// didn't happen.
///
/// So: he EARNS them by showing up, they sit there silently, and they
/// spend THEMSELVES the moment a run would otherwise die. He finds out
/// afterwards.
///
/// ── HOW IT DIFFERS FROM THE RESCUE WE ALREADY HAD ────────────────────
///
/// streak_rescue_service.dart offers to fix a broken run when he next
/// opens the app. It is good and it stays — but it is a NEGOTIATION
/// after a death, and it requires him to open the app and say yes. The
/// shield fires first, before there's anything to negotiate about, and
/// asks him nothing. The rescue is now the fallback for a man who had
/// no shield.
///
/// ── THE THREE RULES ──────────────────────────────────────────────────
///
/// 1. EARNED, NEVER BOUGHT. One per five consecutive days, so protection
///    accrues from the exact behaviour it protects. A man who has been
///    here two weeks has two; a man who joined yesterday has none and
///    has nothing to lose yet either.
///
/// 2. CAPPED AT TWO. A stockpile is a licence not to show up. Two means
///    a bad week survives and a bad month doesn't, which is correct —
///    the streak has to be able to die or it isn't worth anything.
///
/// 3. IT NEVER SAVES A RUN THAT WASN'T REAL. A one-day run isn't a
///    streak and doesn't get a shield spent on it.
class ShieldService {
  static const _kCount = 'shield.count.v1';
  static const _kEarnedAt = 'shield.earned_at_streak.v1';
  static const _kUsedDay = 'shield.used_day.v1';
  static const _kUnseen = 'shield.unseen_save.v1';

  /// Days of showing up per shield.
  static const perDays = 5;

  /// Never more than this in the bank.
  static const maxHeld = 2;

  /// Below this, a run isn't worth protecting.
  static const minRunToSave = 3;

  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static Future<int> held() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kCount) ?? 0;
  }

  /// Award shields for streak milestones crossed since we last looked.
  ///
  /// Called on every load. Returns how many were newly earned so a
  /// surface can mention it — quietly, once. A shield announced with a
  /// fanfare becomes a thing he plans around, and a shield he plans
  /// around is a licence to skip tomorrow.
  static Future<int> accrue(int streak) async {
    final p = await SharedPreferences.getInstance();
    final lastAt = p.getInt(_kEarnedAt) ?? 0;
    final due = streak ~/ perDays;
    final had = lastAt ~/ perDays;
    if (due <= had) {
      // Streak reset below the last award point — re-anchor so the next
      // run earns its own shields rather than inheriting the old run's.
      if (streak < lastAt) await p.setInt(_kEarnedAt, streak);
      return 0;
    }
    final count = p.getInt(_kCount) ?? 0;
    final room = maxHeld - count;
    if (room <= 0) {
      await p.setInt(_kEarnedAt, streak);
      return 0;
    }
    final gained = (due - had) > room ? room : (due - had);
    await p.setInt(_kCount, count + gained);
    await p.setInt(_kEarnedAt, streak);
    return gained;
  }

  /// THE WHOLE POINT.
  ///
  /// Call once on app open, BEFORE anything reads the streak. If a live
  /// run died yesterday and there's a shield in the bank, it spends
  /// itself, the day is written back into the active set, and the run
  /// never breaks. No prompt, no decision, no dialog standing between a
  /// distracted man and his fourteen days.
  ///
  /// Returns the run length it saved, or null if nothing needed saving
  /// or nothing was there to save it with.
  static Future<int?> autoSave() async {
    try {
      final p = await SharedPreferences.getInstance();
      final count = p.getInt(_kCount) ?? 0;
      if (count <= 0) return null;

      final days = await StreakService.activeDays();
      final now = DateTime.now();
      final yesterday = _ymd(now.subtract(const Duration(days: 1)));
      final today = _ymd(now);

      // Nothing broke.
      if (days.contains(yesterday)) return null;
      // Already spent one on this exact gap — a shield covers a day, not
      // an absence.
      if (p.getInt(_kUsedDay) == yesterday) return null;

      // How long was the run behind the gap?
      var run = 0;
      var d = now.subtract(const Duration(days: 2));
      while (days.contains(_ymd(d))) {
        run++;
        d = d.subtract(const Duration(days: 1));
      }
      if (run < minRunToSave) return null;

      await StreakService.markDayActive(yesterday);
      await p.setInt(_kCount, count - 1);
      await p.setInt(_kUsedDay, yesterday);
      // Parked so the next surface with a screen can tell him. Stored
      // rather than shown here because this runs before there IS a
      // screen — that's the point.
      await p.setInt(_kUnseen, run + 1);
      debugPrint('Shield: saved a $run-day run (${count - 1} left)');
      return run + 1;
    } catch (e) {
      debugPrint('ShieldService.autoSave: $e');
      return null;
    }
  }

  /// The saved run he hasn't been told about yet, consumed on read.
  static Future<int?> takeUnseenSave() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getInt(_kUnseen);
    if (n == null || n <= 0) return null;
    await p.remove(_kUnseen);
    return n;
  }

  /// Was today already covered? Used by the streak row so it can say
  /// "a shield held this" instead of claiming he showed up.
  static Future<bool> savedRecently() async {
    final p = await SharedPreferences.getInstance();
    final used = p.getInt(_kUsedDay);
    if (used == null) return false;
    final yesterday =
        _ymd(DateTime.now().subtract(const Duration(days: 1)));
    return used == yesterday;
  }
}
