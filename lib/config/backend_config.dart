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
  // STATUS: LIVE ON ANDROID. Project imhimrizz-cb182 (94590135779) holds
  // all three OAuth clients — Android (com.imhim.app, SHA-1 registered),
  // iOS (com.imhimrizz.app), and the Web client whose ID is below.
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
  // ── HOW FIREBASE AND SUPABASE SPLIT THE WORK ────────────────────────
  //
  // Firebase is real and running in this app — firebase_core plus
  // firebase_analytics, started from firebase_options.dart rather than
  // from the config files, which is why analytics works without the
  // google-services gradle plugin ever being applied. What Firebase
  // does NOT do here is authentication: sign-in is Supabase end to end.
  //
  // They meet at Google Cloud. A Firebase project IS a Cloud project —
  // `imhimrizz-cb182` — so registering the Android app there with a
  // SHA-1 auto-creates the ANDROID OAuth client, and switching the
  // Google provider on in Firebase Auth auto-creates the WEB one. We
  // never use Firebase Auth to sign anybody in; we just take the web
  // client id it minted and hand it to Supabase, which is the thing
  // that actually verifies the token.
  //
  // ── THE WEB CLIENT IS THE ONE THAT MATTERS ──────────────────────────
  //
  // Counter-intuitively it is NOT the Android client that gets named in
  // code. The Android client is matched implicitly by package name plus
  // signing fingerprint and is never referenced here; the WEB client id
  // is passed as `serverClientId`, and that is what makes Google mint an
  // ID TOKEN rather than just a local session. No web client, no token,
  // nothing to hand Supabase.
  //
  // The same string must ALSO sit in Supabase → Authentication →
  // Providers → Google → "Client ID", because the token's audience is
  // this web client and that is the value Supabase verifies against.
  // Set in one place only and every sign-in is rejected.
  //
  // googleIosClientId stays empty — the button is Android-only, so the
  // iOS client Firebase auto-created is simply unused. Turning Google on
  // for iOS later means: fill it in, add the REVERSED_CLIENT_ID from
  // GoogleService-Info.plist to Info.plist CFBundleURLSchemes, and drop
  // the !Platform.isIOS gate in ai_consent_screen + account_screen.
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
  static const googleWebClientId =
      '94590135779-rlc0e497v8k5nc30grgqna79mpltu29v.apps.googleusercontent.com';
  static const googleIosClientId = '';
}
