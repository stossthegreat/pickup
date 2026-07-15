import 'package:shared_preferences/shared_preferences.dart';

import '../config/auralay_dev_flags.dart';
import 'diablo_unlock_store.dart';

/// The ONE master switch for creator access on this device.
///
/// Gated behind [AuralayDevFlags.creatorPassword] from Settings → CREATOR. One
/// password does everything: it turns on UNCHAINED everywhere (Free Flow,
/// Arena, Council all pass `creator: true` to the backend, swapping Lucien
/// and the women into the savage, roasting persona) AND unlocks all Diablo
/// content. Turning it off re-locks everything to the store-safe persona.
///
/// Persisted so a creator doesn't re-enter the password every launch.
class CreatorModeStore {
  static const _key = 'creator_unchained_active';

  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Returns true if [input] matches the creator password and turns the
  /// mode ON. Wrong password leaves it untouched.
  static Future<bool> tryActivate(String input) async {
    final ok =
        input.trim().toUpperCase() == AuralayDevFlags.creatorPassword.toUpperCase();
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      await DiabloUnlockStore.setUnlocked(true);
    }
    return ok;
  }

  /// Turn the mode OFF — re-locks everything back to the store-safe persona.
  static Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    await DiabloUnlockStore.setUnlocked(false);
  }
}
