import 'package:shared_preferences/shared_preferences.dart';

import 'backend/auth_service.dart';
import 'backend/squad_history_service.dart';

/// THE MOMENTS — the two events in the squad layer that must never
/// arrive as a re-render.
///
/// A streak that silently ticks from 13 to 14 is a counter. The same
/// event announced once, the instant the quorum lands, is the reason a
/// man opens the app tomorrow. Same for the armband: a status object
/// that changes hands invisibly is worth nothing, and one that announces
/// itself — *MARCUS TOOK THE ARMBAND* — is checked every morning.
///
/// Everything here is a persisted stamp comparison, so each moment fires
/// EXACTLY ONCE per occurrence, on one device, and surviving a reinstall
/// costs nothing if it doesn't. The failure mode that actually matters
/// is firing twice: a celebration that repeats stops being one, and this
/// app has already been burned by exactly that with the score reveal.
class SquadMoments {
  static const _kBanked = 'squad.moment.banked_ymd.v1';
  static const _kCaptain = 'squad.moment.captain.v1';
  static const _kStreak = 'squad.moment.streak.v1';

  /// What (if anything) to show right now.
  ///
  /// [banked] — today's quorum just landed, with the streak it made.
  /// [captain] — the armband changed hands; the user id now holding it.
  /// [lostArmband] — it was HIS and now isn't. Losing a status object in
  /// your sleep is a stronger pull than winning one, so it gets its own
  /// signal rather than being folded into [captain].
  static Future<({int? banked, String? captain, bool lostArmband})> check(
    SquadHistory h,
    List<String> memberIds,
  ) async {
    if (memberIds.length < 2) {
      return (banked: null, captain: null, lostArmband: false);
    }
    final prefs = await SharedPreferences.getInstance();

    int? banked;
    if (h.todayBanked) {
      final seen = prefs.getInt(_kBanked) ?? 0;
      if (seen != h.todayYmd) {
        await prefs.setInt(_kBanked, h.todayYmd);
        await prefs.setInt(_kStreak, h.streak);
        banked = h.streak;
      }
    }

    String? captain;
    var lost = false;
    final now = h.captainOf(memberIds);
    final was = prefs.getString(_kCaptain);
    if (now != null && now != was) {
      await prefs.setString(_kCaptain, now);
      // Only announce a HANDOVER. The first time we ever compute it
      // there's no previous holder, so there's nothing to announce —
      // saying "you took the armband" on day one, for a squad that has
      // never seen it exist, reads as noise.
      if (was != null && was.isNotEmpty) {
        captain = now;
        lost = was == AuthService.userId && now != AuthService.userId;
      }
    }

    return (banked: banked, captain: captain, lostArmband: lost);
  }

  /// The streak the last banked day produced — used to tell an increase
  /// from a re-render after a reinstall.
  static Future<int> lastStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStreak) ?? 0;
  }
}
