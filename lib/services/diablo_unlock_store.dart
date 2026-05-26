import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether Diablo content is unlocked on this device.
///
/// No longer has its own password — Creator mode is the single master
/// switch (see [CreatorModeStore]). Activating Creator unlocks this too;
/// deactivating re-locks it. Kept as a separate flag so any Diablo-gated
/// content can read it independently.
class DiabloUnlockStore {
  static const _key = 'diablo_unlocked';

  static Future<bool> isUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
