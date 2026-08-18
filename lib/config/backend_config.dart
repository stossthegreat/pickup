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
  // The Firebase files already in the tree (android/app/
  // google-services.json, ios/Runner/GoogleService-Info.plist) do NOT
  // help: they were generated for Firebase Analytics with Google
  // Sign-In switched off, so `oauth_client` is an empty array and the
  // iOS plist carries no CLIENT_ID at all. They are the same Google
  // project (imhim-75991) but they are not credentials.
  //
  // ── TO TURN IT ON ──────────────────────────────────────────────────
  //
  // Google Cloud Console → project `imhim-75991` → APIs & Services →
  // Credentials. Create THREE OAuth clients:
  //
  //   WEB      → paste its ID into googleWebClientId below, AND into
  //              Supabase → Authentication → Providers → Google as the
  //              "Client ID". This is the one Supabase verifies tokens
  //              against; without it every sign-in is rejected.
  //   iOS      → bundle id `com.imhimrizz.app`. Paste its ID into
  //              googleIosClientId below, and add its REVERSED form
  //              (com.googleusercontent.apps.NNN-xxx) to Info.plist
  //              CFBundleURLSchemes — the Google sheet returns to the
  //              app through that scheme and never comes back without it.
  //   ANDROID  → package `com.imhim.app` + a SHA-1 fingerprint. Nothing
  //              to paste; it just has to exist.
  //
  // Then add the iOS and Android client IDs to Supabase's "Authorized
  // Client IDs" field, or it accepts the web token and rejects both
  // native ones.
  //
  // ── THE SHA-1 THAT ACTUALLY MATTERS ────────────────────────────────
  //
  // With Play App Signing, Google re-signs the app after upload, so the
  // certificate users run is NOT the upload key. Register the SHA-1
  // from Play Console → Test and release → App integrity → App signing
  // key certificate. Using the upload key's fingerprint is the classic
  // failure here: sign-in works in every internal build and dies for
  // every real user with a silent cancel and no error anywhere.
  static const googleWebClientId = '';
  static const googleIosClientId = '';
}
