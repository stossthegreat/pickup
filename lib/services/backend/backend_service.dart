import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/backend_config.dart';

/// Supabase bootstrap. Called once from main() before runApp.
///
/// FAIL-SOFT by design (same contract as AnalyticsService.init): if the
/// device is offline or Supabase is unreachable, the app still launches
/// and every backend feature quietly degrades — roleplay, scans and the
/// whole solo experience never depend on this succeeding.
class BackendService {
  static bool _enabled = false;

  /// True once initialize succeeded this launch. Feature services check
  /// this and no-op when false, so callers never need their own guard.
  static bool get enabled => _enabled;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: BackendConfig.url,
        anonKey: BackendConfig.publishableKey,
      );
      _enabled = true;
    } catch (e) {
      // Offline / DNS / captive portal — solo app keeps working.
      debugPrint('BackendService.init failed (continuing offline): $e');
    }
  }
}
