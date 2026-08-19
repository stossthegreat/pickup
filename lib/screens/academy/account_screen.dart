import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import 'package:google_fonts/google_fonts.dart';

import '../../config/backend_config.dart';
import '../../services/backend/auth_service.dart';
import '../../services/progress_sync.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/academy_modal.dart';

/// YOUR NAME ON THE BOARD. Two jobs, both about identity:
///   1. The handle — kills the wall of ANONs on every board and roster.
///   2. The claim — Apple / Google sign-in so the rank, streak and
///      squad survive a lost phone. Anonymous play stays first-class;
///      claiming is pitched as protecting what you've earned.
class AccountScreen extends StatefulWidget {
  /// True when shown as the final onboarding step: no back arrow, a
  /// SKIP FOR NOW exit, and both skip + successful claim land on /home.
  /// Nobody is ever forced to sign in — anonymous play is first-class.
  final bool onboarding;

  const AccountScreen({super.key, this.onboarding = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _handleCtrl = TextEditingController();
  bool _saving = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final handle = await AuthService.getHandle();
    if (mounted && handle != null && _handleCtrl.text.isEmpty) {
      setState(() => _handleCtrl.text = handle);
    }
  }

  Future<void> _saveHandle() async {
    final handle = _handleCtrl.text.trim();
    if (handle.length < 2) {
      _snack('Handle needs at least 2 characters.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final ok = await AuthService.setHandle(handle);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(ok
        ? 'Locked in. That\'s your name on the Board.'
        : 'Couldn\'t save — handle may be taken. Try another.');
  }

  Future<void> _claim(Future<bool> Function() flow, String provider) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final ok = await flow();
    // THE CLAIM IS THE RESTORE. This screen promises that rank and
    // streak survive a lost phone, and this call is the only reason
    // that sentence is true — it pulls whatever the last device banked
    // and merges it upward. On the phone he already plays on it finds
    // nothing bigger and does nothing, which is the common case.
    final restored = ok && await ProgressSync.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AcademyModal.show(
        context,
        kicker: restored ? 'PROGRESS RESTORED' : 'ACCOUNT CLAIMED',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(restored
                    ? 'We got your run back.'
                    : 'Your progress is protected.',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(restored
                ? 'Your XP and streak are back on this phone, and they '
                  'survive the next one too. Signed with $provider.'
                : 'Rank, streak and squad now survive a lost phone or a '
                  'reinstall. Signed with $provider.',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            AcademyButton(
                label: 'DONE',
                onTap: () {
                  Navigator.of(context).pop();
                  if (widget.onboarding) context.go('/home');
                }),
          ],
        ),
      );
      setState(() {});
    } else {
      _snack(provider == 'Google' &&
              !AuthService.signedIn
          ? 'Google sign-in isn\'t configured yet.'
          : 'Sign-in didn\'t complete — nothing changed.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final claimed = AuthService.isClaimed;
    final provider = AuthService.claimedProvider;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
          children: [
            Row(children: [
              if (!widget.onboarding)
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white),
                ),
              Text('YOUR IDENTITY',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
            const SizedBox(height: 20),

            // ── Handle — the name on the Board ─────────────────────
            Text('NAME ON THE BOARD',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _handleCtrl,
                  maxLength: 16,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. MARCUS',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: AppColors.surface1,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveHandle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('SAVE',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('This is what your squad and rivals see. Choose wisely.',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 30),

            // ── The claim ──────────────────────────────────────────
            Text('PROTECT YOUR PROGRESS',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 10),
            if (claimed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          const Color(0xFF2EE87A).withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_rounded,
                      size: 20, color: Color(0xFF2EE87A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'CLAIMED${provider != null ? ' · ${provider.toUpperCase()}' : ''} — rank, streak and squad are safe.',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms)
            else ...[
              Text(
                  // With no provider configured at all there is nothing
                  // to offer, so it must not promise a one-tap claim.
                  (Platform.isIOS || BackendConfig.googleWebClientId.isNotEmpty)
                      ? 'You\'re playing anonymously — fine for now, but '
                          'your rank, streak and squad die with a lost '
                          'phone. Claim them in one tap:'
                      : 'You\'re playing anonymously. Everything works, but '
                          'your rank, streak and squad live on this handset '
                          'alone — sign-in is coming.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 14),
              // APPLE ONLY ON APPLE, and AuthService refuses it outright
              // off an Apple device so the UI isn't the only thing
              // holding the line. sign_in_with_apple on Android falls
              // back to a web-redirect flow this app never configured —
              // it doesn't fail loudly, it opens a browser that goes
              // nowhere, which is worse than a dead button.
              if (Platform.isIOS)
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _claim(AuthService.signInWithApple, 'Apple'),
                  icon: const Icon(Icons.apple, size: 22),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  label: Text('CONTINUE WITH APPLE',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              // GOOGLE ONLY EXISTS WHEN GOOGLE EXISTS.
              //
              // Gated on the config, not the platform: the client IDs
              // are filled in now, so this shows on iOS and Android
              // alike. It stays gated because an empty ID means
              // signInWithGoogle() bails at its own guard and returns
              // false — a button that opens a sheet-less failure and a
              // snackbar saying it isn't configured. A button that can
              // only fail is worse than no button; the user reads it as
              // the app being broken.
              //
              // Apple above is iOS-only in the other direction, since
              // sign_in_with_apple off an Apple device needs a
              // web-redirect flow this app never wired up.
              if (BackendConfig.googleWebClientId.isNotEmpty) ...[
              // Only spaced off Apple when Apple is actually there —
              // otherwise Android inherits a 24pt hole where the hidden
              // button used to be.
              if (Platform.isIOS) const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _claim(AuthService.signInWithGoogle, 'Google'),
                  icon: Text('G',
                      style: GoogleFonts.inter(
                          color: Platform.isIOS
                              ? AppColors.textPrimary
                              : Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  // Outlined under Apple on iOS, solid when it stands
                  // alone on Android. The only provider on a screen has
                  // to look like the thing to press; a lone outlined
                  // button reads as secondary to nothing.
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        Platform.isIOS ? Colors.transparent : Colors.white,
                    foregroundColor:
                        Platform.isIOS ? AppColors.textPrimary : Colors.black,
                    side: Platform.isIOS
                        ? BorderSide(
                            color: Colors.white.withValues(alpha: 0.25))
                        : BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  label: Text('CONTINUE WITH GOOGLE',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              ],
            ],

            if (claimed && !widget.onboarding) ...[
              const SizedBox(height: 26),
              Center(
                child: TextButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await AuthService.signOut();
                    if (mounted) setState(() {});
                  },
                  child: Text('SIGN OUT',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ],

            // Onboarding exit — claiming is optional, always.
            if (widget.onboarding) ...[
              const SizedBox(height: 30),
              AcademyButton(
                label: claimed ? 'ENTER THE APP' : 'SKIP FOR NOW',
                ghost: !claimed,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.go('/home');
                },
              ),
              if (!claimed) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text('You can claim any time in Settings.',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
