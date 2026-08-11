import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/analytics_service.dart';
import '../../services/backend/auth_service.dart';
import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// THE DOOR — sign in, agree, go.
///
/// This screen used to print the entire AI-disclosure essay inline:
/// three headed sections of body copy the user had to scroll past
/// before reaching two checkboxes, with sign-in on a separate screen
/// afterwards. Nobody reads a wall of terms, it looks amateur, and it
/// split one decision across two pages.
///
/// The professional shape, and the one every serious app uses: the
/// sign-in buttons first, the consent as two short ticked lines, and
/// the legal text behind links for the people who genuinely want it.
/// The full disclosure still exists verbatim in the Privacy Policy —
/// this screen names what's shared in one sentence and links out.
///
/// Consent is still explicit, still two separate ticks (18+/Terms, and
/// Privacy/AI processing), and still blocks entry until both are given,
/// so 5.1.1(i) / 5.1.2(i) are satisfied exactly as before.
class AiConsentScreen extends StatefulWidget {
  const AiConsentScreen({super.key});

  @override
  State<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends State<AiConsentScreen> {
  bool _agreedTerms = false; // 18+ and Terms of Use
  bool _agreedPrivacy = false; // Privacy Policy + AI data processing
  bool _busy = false;

  bool get _canContinue => _agreedTerms && _agreedPrivacy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await LocalStoreService.hasAiConsent() && mounted) {
        context.go('/home');
      }
    });
    AnalyticsService.consentShown();
  }

  Future<void> _persistConsent() async {
    await LocalStoreService.setAiConsent(true);
    AnalyticsService.consentGranted();
  }

  /// Both providers land here: record consent, sign in, then go pick a
  /// name. A failure never blocks entry — you can always claim later.
  Future<void> _claim(Future<bool> Function() provider) async {
    if (!_canContinue || _busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    await _persistConsent();
    final ok = await provider();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      context.go('/onboarding/handle');
      return;
    }
    final why = AuthService.lastError;
    if (why == null) return; // user cancelled the sheet — say nothing
    _showFailure(why);
  }

  /// Sign-in failures used to surface as a shrug. The provider's own
  /// message names the cause — nearly always a dashboard field — so it
  /// gets shown, and copied, instead of thrown away.
  void _showFailure(String why) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('Sign-in failed',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: SelectableText(why,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12.5, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ignore: discarded_futures
              Clipboard.setData(ClipboardData(text: why));
              Navigator.of(ctx).pop();
            },
            child: Text('COPY',
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
                style: GoogleFonts.inter(
                    color: AppColors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _skip() async {
    if (!_canContinue) return;
    HapticFeedback.mediumImpact();
    await _persistConsent();
    if (!mounted) return;
    context.go('/onboarding/handle');
  }

  @override
  Widget build(BuildContext context) {
    final ready = _canContinue && !_busy;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const ImHimWordmark(fontSize: 28, letterSpacing: -0.7),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 11),
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle),
                ),
              ]),

              const Spacer(flex: 2),

              Text('Save your progress.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(duration: 320.ms),
              const SizedBox(height: 8),
              Text(
                  'Sign in so your rank, streak and squad survive a lost '
                  'phone. Or skip — everything works without it.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  )).animate().fadeIn(delay: 70.ms, duration: 320.ms),

              const SizedBox(height: 26),

              // ── SIGN IN — above the small print, like every real app ──
              _ProviderButton(
                label: 'CONTINUE WITH APPLE',
                icon: Icons.apple,
                filled: true,
                enabled: ready,
                onTap: () => _claim(AuthService.signInWithApple),
              ),
              const SizedBox(height: 10),
              _ProviderButton(
                label: 'CONTINUE WITH GOOGLE',
                glyph: 'G',
                filled: false,
                enabled: ready,
                onTap: () => _claim(AuthService.signInWithGoogle),
              ),
              const SizedBox(height: 10),
              _ProviderButton(
                label: 'SKIP FOR NOW',
                filled: false,
                muted: true,
                enabled: ready,
                onTap: _skip,
              ),

              const Spacer(flex: 3),

              // ── THE TWO TICKS — short lines, links, no essay ─────────
              _Tick(
                value: _agreedTerms,
                onChanged: (v) => setState(() => _agreedTerms = v),
                child: _legal(
                  'I\'m 18 or over and agree to the ',
                  linkText: 'Terms of Use',
                  onTap: () => context.push('/terms'),
                ),
              ),
              const SizedBox(height: 12),
              _Tick(
                value: _agreedPrivacy,
                onChanged: (v) => setState(() => _agreedPrivacy = v),
                child: _legal(
                  'I agree to the ',
                  linkText: 'Privacy Policy',
                  onTap: () => context.push('/privacy'),
                  tail: ' and to my voice, messages and screenshots being '
                      'sent to OpenAI to power the AI features.',
                ),
              ),
              const SizedBox(height: 14),
              if (!_canContinue)
                Text('Tick both to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legal(String lead,
      {required String linkText,
      required VoidCallback onTap,
      String? tail}) {
    final base = GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 12.5,
      height: 1.45,
      fontWeight: FontWeight.w500,
    );
    return RichText(
      text: TextSpan(style: base, children: [
        TextSpan(text: lead),
        TextSpan(
          text: linkText,
          style: base.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.red,
          ),
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ),
        if (tail != null) TextSpan(text: tail),
      ]),
    );
  }
}

/// Big tap target — the whole row toggles, not just the 20pt box.
class _Tick extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  const _Tick(
      {required this.value, required this.onChanged, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: value ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: value ? AppColors.red : Colors.white.withValues(alpha: 0.25),
              width: 1.8,
            ),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ]),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? glyph;
  final bool filled;
  final bool muted;
  final bool enabled;
  final VoidCallback onTap;
  const _ProviderButton({
    required this.label,
    this.icon,
    this.glyph,
    required this.filled,
    this.muted = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled
        ? Colors.black
        : muted
            ? AppColors.textTertiary
            : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 10),
              ],
              if (glyph != null) ...[
                Text(glyph!,
                    style: GoogleFonts.inter(
                      color: fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(width: 10),
              ],
              Text(label,
                  style: GoogleFonts.inter(
                    color: fg,
                    fontSize: 13,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
