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

  // ── GOOGLE SIGN-IN ──────────────────────────────────────────────────
  //
  // STATUS: NOT SET UP. Both IDs are empty, so signInWithGoogle() bails
  // at its own guard and the button is hidden (see account_screen.dart).
  // Apple sign-in is unaffected and is the lane that actually matters on
  // iOS — this can ship empty.
  //
  // ── ANDROID ONLY. THIS BUTTON DOES NOT EXIST ON iOS ─────────────────
  //
  // account_screen.dart gates it on `!Platform.isIOS`. iOS runs the
  // Apple lane alone — one button, no Google Cloud setup, and no App
  // Review questions about a second provider. So there is NO iOS OAuth
  // client to create and NO reversed URL scheme to add to Info.plist:
  // an iPhone will never reach this code path. Testing on an iPhone and
  // finding no Google button is the system working as designed.
  //
  // ── WHAT FIREBASE DID AND DIDN'T DO ─────────────────────────────────
  //
  // A Firebase project IS a Google Cloud project — this one is
  // `imhim-75991`. Registering an Android app there with a SHA-1
  // fingerprint auto-creates the ANDROID OAuth client in that project's
  // credentials, which is a real, necessary step. But Firebase itself is
  // inert in this app: the google-services gradle plugin is not applied,
  // nothing calls a Firebase SDK, and auth runs entirely through
  // Supabase. The google-services.json in the tree is stale (its
  // `oauth_client` array is empty) and no code reads it.
  //
  // Firebase cannot create the client that's actually missing.
  //
  // ── THE ONE THING LEFT: A WEB CLIENT ────────────────────────────────
  //
  // Google Cloud Console → project `imhim-75991` → APIs & Services →
  // Credentials → Create credentials → OAuth client ID → **Web
  // application**. There is no Firebase screen for this.
  //
  // That ID goes in TWO places and both are required:
  //
  //   1. googleWebClientId below. It's passed as `serverClientId`, which
  //      is what makes Google mint an ID TOKEN rather than just a local
  //      session. Without it there is no token to hand Supabase.
  //   2. Supabase → Authentication → Providers → Google → "Client ID".
  //      The token's audience is this web client, so this is the value
  //      Supabase verifies against. Mismatch = every sign-in rejected.
  //
  // googleIosClientId stays empty forever — see the iOS note above.
  //
  // ── THE SHA-1 THAT ACTUALLY MATTERS ────────────────────────────────
  //
  // With Play App Signing, Google re-signs the app after upload, so the
  // certificate users run is NOT the upload key. Register the SHA-1
  // from Play Console → Test and release → App integrity → App signing
  // key certificate. Using the upload key's fingerprint is the classic
  // failure here: sign-in works in every internal build and dies for
  // every real user with a silent cancel and no error anywhere. Register
  // BOTH if you're also testing debug builds — a client can hold many.
  //
  static const googleWebClientId = '';
  static const googleIosClientId = '';
}
