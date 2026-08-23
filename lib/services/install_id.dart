import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable, anonymous per-install identifier, and the one place that
/// builds headers for calls to our own backend.
///
/// WHY THIS EXISTS — CARRIER NAT.
///
/// The backend rate-limits to protect against a runaway client burning
/// real OpenAI money. That limit has to be keyed by *something*, and the
/// obvious key — the client IP — is wrong for a mobile app. Cellular
/// carriers put tens of thousands of subscribers behind a handful of
/// NAT egress addresses, so to our server an entire network reads as one
/// client. At a few hundred users the limit never trips. At a few
/// hundred thousand it throttles a whole carrier at once, and every one
/// of those users sees the app "break" simultaneously with nothing in
/// our logs but 429s.
///
/// So each install sends its own key and is limited on its own usage.
/// The server keeps a much higher per-IP ceiling underneath as a
/// backstop, because a header is client-supplied and an attacker can
/// rotate it — see server.js.
///
/// It is a random number and nothing else: no device identifier, no ad
/// ID, no account, nothing that survives an uninstall or identifies a
/// person. It exists to say "these requests are one app instance".
abstract final class InstallId {
  static const _key = 'install_id';

  /// Synchronous cache — hot paths (session mint, every chat turn) must
  /// never await a prefs read. Hydrated once at launch.
  static String cached = '';

  /// Call once from main(), before any backend call.
  static Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key) ?? '';
    if (id.length != 32) {
      final r = Random.secure();
      final b = StringBuffer();
      for (var i = 0; i < 16; i++) {
        b.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
      }
      id = b.toString();
      await prefs.setString(_key, id);
    }
    cached = id;
  }
}

/// Headers for every request to our own Railway backend.
///
/// Use this instead of writing the content-type literal inline, so the
/// rate-limit key rides on every call automatically and a new endpoint
/// can never quietly fall back to IP-keyed limiting.
abstract final class BackendHeaders {
  static Map<String, String> get json => {
        'content-type': 'application/json',
        // Empty until hydrate() has run — the server falls back to IP
        // keying for those, which is correct behaviour, not an error.
        if (InstallId.cached.isNotEmpty) 'x-client-id': InstallId.cached,
      };
}
