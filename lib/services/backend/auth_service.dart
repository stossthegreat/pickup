import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Claim the account with Apple (native sheet → Supabase id-token).
  /// Returns true on success.
  static Future<bool> signInWithApple() async {
    if (!BackendService.enabled) return false;
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
      debugPrint('AuthService.signInWithApple: $e');
      return false;
    } catch (e) {
      debugPrint('AuthService.signInWithApple: $e');
      return false;
    }
  }

  /// Set/replace the public handle shown on leaderboards + squad rosters.
  static Future<bool> setHandle(String handle) async {
    final uid = userId;
    if (uid == null) return false;
    try {
      await _sb.from('profiles').update({'handle': handle}).eq('id', uid);
      return true;
    } catch (e) {
      debugPrint('AuthService.setHandle: $e');
      return false;
    }
  }
}
