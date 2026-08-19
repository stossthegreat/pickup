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
  // ── BOTH PLATFORMS ──────────────────────────────────────────────────
  //
  // Google shows on iOS and Android; Apple shows on iOS only, because
  // sign_in_with_apple off an Apple device needs a web-redirect flow
  // this app never wired up. So an iPhone offers two buttons and an
  // Android one offers Google. App Store guideline 4.8 is satisfied by
  // Apple being present alongside the third-party option, which it is.
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
  // googleIosClientId is the iOS half. google_sign_in needs it as
  // `clientId` on iOS (Android passes null and is matched by package +
  // fingerprint instead), and its REVERSED form is in Info.plist under
  // CFBundleURLSchemes — that scheme is how the Google sheet hands
  // control back to the app. Without it the sheet opens and hangs.
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
  static const googleIosClientId =
      '94590135779-37sj39doa8rikv9it3d9o5n8oahb14uj.apps.googleusercontent.com';
}
