import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/backend_config.dart';
import 'backend_service.dart';

/// Identity. Two lanes, deliberately:
///
///  1. ANONYMOUS (the entry lane) — [ensureSignedIn] runs silently at
///     launch so every user has a real server identity (ELO row, squad
///     eligibility) with zero friction. Nobody sees a login screen.
///  2. APPLE (the claim lane) — [signInWithApple] upgrades to a durable
///     account the moment the user has something to lose (a rank, a
///     streak, a squad). Native id-token flow, no browser bounce.
///
/// NOTE: Sign in with Apple additionally needs the capability ticked on
/// the com.imhimrizz.app App ID (Apple Developer portal) + the matching
/// entitlement in Xcode Signing & Capabilities. Until then only the
/// anonymous lane is active — the Apple button simply isn't shown.
class AuthService {
  static SupabaseClient get _sb => BackendService.client;

  static bool get signedIn =>
      BackendService.enabled && _sb.auth.currentUser != null;

  /// Server user id (uuid) or null when offline / not signed in.
  static String? get userId =>
      BackendService.enabled ? _sb.auth.currentUser?.id : null;

  /// True when the account is claimed (Apple), not just anonymous.
  static bool get isClaimed =>
      signedIn && !(_sb.auth.currentUser?.isAnonymous ?? true);

  /// Silent identity at launch. Safe to call every open — resumes the
  /// stored session when one exists, mints an anonymous user otherwise.
  /// Fire-and-forget from main(); never blocks the first frame.
  static Future<void> ensureSignedIn() async {
    if (!BackendService.enabled) return;
    if (_sb.auth.currentUser != null) return;
    try {
      await _sb.auth.signInAnonymously();
    } catch (e) {
      debugPrint('AuthService.ensureSignedIn: $e'); // offline → retry next open
    }
  }

  /// Why the last sign-in attempt failed, in the provider's own words.
  ///
  /// Both sign-in methods used to swallow every failure into `false`, so
  /// the UI could only ever say "that didn't work". The overwhelmingly
  /// common cause is a dashboard field, not a bug — Supabase rejects a
  /// perfectly good Apple token when the app's bundle id isn't listed
  /// under the Apple provider's "Client IDs", and the message says so.
  /// Throwing that away turned a 30-second fix into a guessing game.
  static String? lastError;

  /// Claim the account with Apple (native sheet → Supabase id-token).
  /// Returns true on success.
  static Future<bool> signInWithApple() async {
    lastError = null;
    if (!BackendService.enabled) {
      lastError = 'No backend connection.';
      return false;
    }
    try {
      // Raw nonce goes to Supabase, its sha256 goes to Apple — Supabase
      // verifies the pair so a stolen token can't be replayed.
      final rawNonce = _sb.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) return false;

      await _sb.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled the sheet — not an error worth surfacing.
      if (e.code == AuthorizationErrorCode.canceled) return false;
      lastError = 'Apple: ${e.code.name} — ${e.message}';
      debugPrint('AuthService.signInWithApple: $e');
      return false;
    } on AuthException catch (e) {
      // Supabase refused the token. Nine times out of ten this is
      // "Unacceptable audience in id_token", meaning the bundle id is
      // missing from Supabase → Auth → Providers → Apple → Client IDs.
      lastError = 'Supabase rejected the Apple token: ${e.message}\n\n'
          'Usually means com.imhimrizz.app is missing from '
          'Supabase → Authentication → Providers → Apple → Client IDs.';
      debugPrint('AuthService.signInWithApple (supabase): $e');
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('AuthService.signInWithApple: $e');
      return false;
    }
  }

  /// Is this handle free? The DB has `handle text unique`, so the real
  /// guarantee is server-side — this is the fast pre-check that lets the
  /// picker say "taken" while you're still typing instead of failing on
  /// save. Returns null when we genuinely can't tell (offline).
  static Future<bool?> isHandleFree(String handle) async {
    if (!BackendService.enabled) return null;
    final clean = handle.trim();
    if (clean.isEmpty) return null;
    try {
      final rows = await _sb
          .from('profiles')
          .select('id')
          .ilike('handle', clean) // case-insensitive: no Dave vs dave
          .limit(1);
      if (rows.isEmpty) return true;
      return rows.first['id'] == userId; // my own handle is "free" to me
    } catch (e) {
      debugPrint('AuthService.isHandleFree: $e');
      return null;
    }
  }

  /// Claim the account with Google (native sheet → Supabase id-token).
  /// Returns false when cancelled, offline, or not yet configured
  /// (BackendConfig.googleWebClientId empty).
  static Future<bool> signInWithGoogle() async {
    lastError = null;
    if (!BackendService.enabled) {
      lastError = 'No backend connection.';
      return false;
    }
    if (BackendConfig.googleWebClientId.isEmpty) {
      lastError = 'Google isn\'t configured yet — the Web client ID is '
          'still empty in backend_config.dart.';
      debugPrint('AuthService.signInWithGoogle: no client IDs configured');
      return false;
    }
    try {
      final google = GoogleSignIn(
        clientId: BackendConfig.googleIosClientId.isEmpty
            ? null
            : BackendConfig.googleIosClientId,
        serverClientId: BackendConfig.googleWebClientId,
      );
      final account = await google.signIn();
      if (account == null) return false; // user cancelled the sheet
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return false;
      await _sb.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      return true;
    } on AuthException catch (e) {
      lastError = 'Supabase rejected the Google token: ${e.message}\n\n'
          'Usually means the Web client ID is missing from '
          'Supabase → Authentication → Providers → Google.';
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('AuthService.signInWithGoogle: $e');
      return false;
    }
  }

  /// Sign out, then immediately mint a fresh anonymous identity so the
  /// app never sits in a signed-out limbo state.
  static Future<void> signOut() async {
    if (!BackendService.enabled) return;
    try {
      await _sb.auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut: $e');
    }
    await ensureSignedIn();
  }

  /// Which provider claimed this account ('apple' / 'google'), or null
  /// while anonymous.
  static String? get claimedProvider {
    if (!isClaimed) return null;
    final ids = _sb.auth.currentUser?.identities;
    if (ids == null || ids.isEmpty) return null;
    return ids.first.provider;
  }

  /// Current public handle, or null when unset / offline.
  static Future<String?> getHandle() async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final r = await _sb
          .from('profiles')
          .select('handle')
          .eq('id', uid)
          .single();
      return r['handle'] as String?;
    } catch (e) {
      debugPrint('AuthService.getHandle: $e');
      return null;
    }
  }

  /// Set/replace the public handle shown on leaderboards + squad rosters.
  /// Set the public handle, and PROVE it landed.
  ///
  /// This used to be a bare `.update()` that returned true unconditionally.
  /// An update matching ZERO rows is not an error in Postgres — it's a
  /// no-op — so if the profiles row didn't exist (the on_auth_user_created
  /// trigger only fires for users created AFTER it was installed, and
  /// linking an anonymous account to Apple can leave you on a different
  /// id than the one you typed the name under), the app cheerfully said
  /// "saved" and you stayed ANON on every board forever.
  ///
  /// Now: upsert, so a missing row is created rather than silently
  /// skipped, then read it straight back and only report success if the
  /// value is actually there.
  static Future<bool> setHandle(String handle) async {
    lastError = null;
    final uid = userId;
    if (uid == null) {
      lastError = 'Not signed in.';
      return false;
    }
    final clean = handle.trim();
    try {
      await _sb.from('profiles').upsert({'id': uid, 'handle': clean});
    } catch (e) {
      final s = e.toString();
      lastError = s.contains('duplicate') || s.contains('unique')
          ? 'That name is already taken.'
          : 'Could not save the name.\n\n$e';
      debugPrint('AuthService.setHandle: $e');
      return false;
    }
    // Trust nothing — read it back.
    try {
      final row = await _sb
          .from('profiles')
          .select('handle')
          .eq('id', uid)
          .maybeSingle();
      final saved = (row?['handle'] as String?) ?? '';
      if (saved.toLowerCase() != clean.toLowerCase()) {
        lastError = 'The name did not stick — the server still has '
            '"${saved.isEmpty ? '(nothing)' : saved}". '
            'Your profile row may be missing.';
        return false;
      }
      return true;
    } catch (e) {
      lastError = 'Saved, but could not confirm it.\n\n$e';
      debugPrint('AuthService.setHandle (verify): $e');
      return false;
    }
  }
}
