import 'package:shared_preferences/shared_preferences.dart';

/// THE DAILY STREAK — single source of truth for the flame the user
/// protects.
///
/// History / why this exists: the old streak lived inline in
/// home_screen as a "triple streak" that only advanced when LOOKS +
/// AURA + GAME were all completed the same day. But the AURA pillar's
/// only completion path was the Eyes tab, which is no longer in the
/// nav — so `aura_done_ymd` is never stamped and the streak could never
/// leave 0. Worse, the Rizz tab read the raw `triple_streak_count` pref
/// directly, so the surfaces disagreed.
///
/// This service replaces that. A day counts toward the streak the
/// moment the user completes ANY of the daily missions that actually
/// ship:
///   • LOOKS  — a scan or a protocol check-in   (`looks_done_ymd`)
///   • GAME   — a Free Flow / roleplay rep        (`game_done_ymd`)
///   • RIZZ   — a rizz reply generation           (`rizz_done_ymd`)
///   • PICKUP — copied a pickup line              (`pickup_line_done_ymd`)
///
/// [refresh] is idempotent per calendar day — call it from any surface
/// load; it advances the streak at most once per day and returns the
/// live (current, longest) pair so every masthead + the Ascend panel
/// read the same number.
class StreakService {
  static const _kCount   = 'daily_streak_count';
  static const _kLongest = 'daily_streak_longest';
  static const _kLastYmd = 'daily_streak_last_ymd';

  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  static int _todayYmd() => _ymd(DateTime.now());

  /// True if the user has completed at least one daily mission today.
  static Future<bool> didQualifyToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayYmd();
    return (prefs.getInt('looks_done_ymd')       ?? 0) == today
        || (prefs.getInt('game_done_ymd')        ?? 0) == today
        || (prefs.getInt('rizz_done_ymd')        ?? 0) == today
        || (prefs.getInt('pickup_line_done_ymd') ?? 0) == today;
  }

  /// Advance the streak if the user qualified today and it hasn't been
  /// counted yet, then return the live `(current, longest)` pair.
  ///
  /// Idempotent per day: the first qualifying call each calendar day
  /// extends (or resets) the chain and stamps today; later calls the
  /// same day just read it back.
  static Future<(int current, int longest)> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayYmd();
    final yesterday =
        _ymd(DateTime.now().subtract(const Duration(days: 1)));

    final did     = await didQualifyToday();
    int count     = prefs.getInt(_kCount)   ?? 0;
    int longest   = prefs.getInt(_kLongest) ?? 0;
    final lastYmd = prefs.getInt(_kLastYmd) ?? 0;

    // First qualifying action today → extend if yesterday counted,
    // else start a fresh day-1 chain.
    if (did && lastYmd != today) {
      count = (lastYmd == yesterday) ? count + 1 : 1;
      await prefs.setInt(_kCount, count);
      await prefs.setInt(_kLastYmd, today);
      if (count > longest) {
        longest = count;
        await prefs.setInt(_kLongest, longest);
      }
      return (count, longest);
    }

    // No new qualifying action this call — report the live state:
    //   • already counted today          → still `count`
    //   • yesterday counted, today pending → still `count` (alive)
    //   • older than that                  → chain broke, show 0
    if (lastYmd == today || lastYmd == yesterday) {
      return (count, longest);
    }
    return (0, longest);
  }

  /// Read-only view of the current streak (no advance). Used where a
  /// surface only needs to display and another path owns the advance.
  static Future<int> current() async {
    final (cur, _) = await refresh();
    return cur;
  }
}
