import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    if (_sb.auth.currentUser != null) {
      // Already in — but he may still be nameless (see below).
      // ignore: discarded_futures
      _ensureHandle();
      return;
    }
    try {
      await _sb.auth.signInAnonymously();
      // ignore: discarded_futures
      _ensureHandle();
    } catch (e) {
      debugPrint('AuthService.ensureSignedIn: $e'); // offline → retry next open
    }
  }

  /// ══════════════════════════════════════════════════════════════════
  ///  NOBODY IS ANON. A name is assigned before one is chosen.
  ///  ══════════════════════════════════════════════════════════════════
  ///
  /// Every surface that shows another human — the boards, the squad
  /// roster, a duel verdict — fell back to the literal string ANON when
  /// his handle was null, and most handles were null: naming yourself is
  /// an optional onboarding step most men skip. So the app's social
  /// fabric read as a wall of ANON vs ANON, which kills the entire point
  /// of fighting a real person — beating ANON feels like beating a bot.
  ///
  /// The fix is upstream of every single one of those surfaces: the
  /// moment an identity exists it gets a generated call-sign (WOLF-482),
  /// so a null handle stops being a state that can reach a screen. The
  /// handle screen still lets him pick his own; this is the floor, not
  /// the ceiling.
  ///
  /// Fire-and-forget from [ensureSignedIn]; a checked flag makes the
  /// common path one prefs read, not a network call per launch.
  static const _kHandleChecked = 'auth.handle.seeded.v1';

  static const _callSigns = [
    'WOLF', 'HAWK', 'VIPER', 'ACE', 'BLADE', 'DUKE', 'JET', 'ONYX',
    'RHINO', 'SABER', 'TITAN', 'NOVA', 'RAZOR', 'STORM', 'DRIFT', 'KODA',
    'MAVERICK', 'ORION', 'ATLAS', 'BANDIT', 'COBRA', 'DIESEL', 'FALCON',
    'GHOST',
  ];

  static Future<void> _ensureHandle() async {
    final uid = userId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kHandleChecked) == true) return;

      final have = await getHandle();
      if (have != null && have.trim().isNotEmpty) {
        await prefs.setBool(_kHandleChecked, true);
        return;
      }

      // Derived from the uid rather than random — the same account
      // lands on the same name on every device, and Date.now-free code
      // stays deterministic under test.
      final seed = uid.hashCode.abs();
      for (var attempt = 0; attempt < 6; attempt++) {
        final word = _callSigns[(seed + attempt * 7) % _callSigns.length];
        // Not called `num` — that shadows the numeric supertype and is
        // exactly the kind of legal-but-cursed Dart that bites later.
        final tag = ((seed ~/ 31) + attempt * 137) % 900 + 100;
        final name = '$word-$tag';
        if (await setHandle(name)) {
          await prefs.setBool(_kHandleChecked, true);
          return;
        }
        // Collision on the unique index → try the next variation.
      }
    } catch (e) {
      debugPrint('AuthService._ensureHandle: $e'); // retry next launch
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
  ///
  /// iOS ONLY, ENFORCED HERE AND NOT JUST IN THE UI. Both screens that
  /// offer this already hide it on Android, but a guard in the service
  /// is the one that can't be undone by someone adding a third button
  /// later. sign_in_with_apple off an Apple device falls back to a web
  /// redirect flow that needs a Services ID and a return URL this app
  /// has never configured — so on Android it doesn't fail loudly, it
  /// opens a browser that goes nowhere. Refusing outright is better.
  static Future<bool> signInWithApple() async {
    lastError = null;
    if (!Platform.isIOS && !Platform.isMacOS) {
      lastError = 'Sign in with Apple is only available on Apple devices.';
      debugPrint('AuthService.signInWithApple: refused on non-Apple platform');
      return false;
    }
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
        // ECHO THE TOKEN'S OWN NONCE BACK. See _nonceFromIdToken.
        nonce: _nonceFromIdToken(idToken),
      );
      return true;
    } on AuthException catch (e) {
      // THE HINT HAS TO MATCH THE ACTUAL FAILURE. This used to blame a
      // missing Web client ID for every rejection, which sent a man who
      // had already pasted it in round the same loop again. Supabase
      // rejects a Google token for three distinct reasons and they have
      // three different fixes.
      final m = e.message.toLowerCase();
      final hint = m.contains('nonce mismatch') || m.contains('nonces mismatch')
          ? 'Both sides sent a nonce and the server did not accept them '
              'as equal.\n\n'
              'Fix: Supabase → Authentication → Providers → Google → '
              'turn ON "Skip nonce checks". The app already echoes '
              'Google\'s own nonce back, so nothing else can be done '
              'from this side.'
          : m.contains('nonce')
          // Google's iOS SDK puts a nonce claim in the id_token. We
          // don't pass one (google_sign_in gives us no way to set it),
          // and GoTrue rejects a token where one side has a nonce and
          // the other doesn't. The provider-level switch is the
          // supported way through — Apple sign-in is unaffected, it
          // does its own nonce properly.
          ? 'The Google SDK put a nonce in the token and the server '
              'expected either both or neither. The app now reads that '
              'nonce out of the token and passes it back, so seeing '
              'this means the build is older than b201.'
          : (m.contains('audience') || m.contains('client'))
              ? 'The token was issued for a different client than the '
                  'one Supabase is checking against.\n\n'
                  'Fix: the Client ID in Supabase → Authentication → '
                  'Providers → Google must be the WEB client ID, and '
                  'must match googleWebClientId in backend_config.dart '
                  'exactly.'
              : 'Check Supabase → Authentication → Providers → Google '
                  'is enabled and its Client ID is the Web client ID.';
      lastError = 'Supabase rejected the Google token:\n${e.message}\n\n$hint';
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('AuthService.signInWithGoogle: $e');
      return false;
    }
  }

  /// ── READ THE NONCE BACK OUT OF GOOGLE'S OWN TOKEN ─────────────────
  ///
  /// Google's iOS SDK stamps a `nonce` claim into the id_token. We never
  /// asked it to and we cannot stop it — google_sign_in exposes no way
  /// to supply or suppress one. The server's rule is that the nonce must
  /// be present on both sides or neither, so passing nothing got every
  /// sign-in rejected with "Passed nonce and nonce in id_token should
  /// either both exist or not" AFTER the user had already picked their
  /// account. The furthest possible point to fail.
  ///
  /// There is a dashboard switch for this. Relying on it means the app
  /// only works while a setting in a web console stays flipped, which is
  /// not a thing to bet sign-in on — so this handles it in code and the
  /// switch becomes irrelevant either way.
  ///
  /// WHY ECHOING IT IS NOT A HOLE. A nonce binds a token to the request
  /// that asked for it, and it only does that when the CALLER generates
  /// it. Here the SDK does, so we could never have checked anything —
  /// echoing it back is exactly as strong as the check we were already
  /// not performing, and no weaker than the dashboard switch. The real
  /// protection is elsewhere and unaffected: the server still verifies
  /// Google's signature on the token and that its audience is our Web
  /// client. Apple's lane is untouched and still does a proper nonce —
  /// it generates the raw value, sends only the SHA-256 to Apple, and
  /// hands the raw half to the server to match.
  ///
  /// Returns null when there's no nonce claim, which is the correct
  /// value to pass then: neither side has one, and the rule is met.
  static String? _nonceFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      // JWTs are base64URL and unpadded; base64.decode needs both fixed.
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final claims =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final nonce = claims['nonce'];
      return (nonce is String && nonce.isNotEmpty) ? nonce : null;
    } catch (e) {
      // A token we can't read is a token the server will reject on its
      // own terms, with a better message than anything we'd invent.
      debugPrint('AuthService._nonceFromIdToken: $e');
      return null;
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
