/// Supabase backend — ImHim Rizz project.
///
/// The publishable key is DESIGNED to ship inside the app (it's the old
/// "anon key" renamed). It can only do what row-level security allows:
/// users read/write their own rows, leaderboards are read-only, and
/// anything that affects rank or score is written exclusively by the
/// server through the secret key (which NEVER appears in this codebase).
class BackendConfig {
  static const url = 'https://xfmnvmuhabrkiemtvdzg.supabase.co';
  static const publishableKey =
      'sb_publishable_j3gDimIL8j-aZkN9PzLang_0HqnaYUa';

  // ── Google Sign-In (paste from Google Cloud Console → Credentials) ──
  // 1. Create an OAuth client of type WEB → its client ID goes here AND
  //    into Supabase → Authentication → Providers → Google.
  // 2. Create an OAuth client of type IOS (bundle com.imhimrizz.app) →
  //    its client ID goes here; add its reversed form to Info.plist
  //    URL schemes.
  // Empty strings = the Google button quietly reports "not configured"
  // instead of crashing, so the app ships fine before this is done.
  static const googleWebClientId = '';
  static const googleIosClientId = '';
}
