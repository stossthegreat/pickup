import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/dev_flags.dart';
import '../../services/analytics_service.dart';
import '../../services/local_store_service.dart';
import '../../services/purchase_service.dart';
import '../../services/review_prompt_service.dart';
import '../../services/win_back_service.dart';
import '../../theme/app_colors.dart';
import '../../services/trial_service.dart';

/// ImHim paywall — "paywall-final" carousel.
///
/// A swipeable three-panel story (Practice → Game → Him). The header
/// copy + classified progress tracker change per panel, the CTA / price
/// / legal row stay pinned at the bottom. (The RIZZ panel was pulled
/// from the carousel — its widget is kept below, marked unused, so it
/// can be dropped back in.)
///
/// Auto-tour behaviour: on open the carousel advances one panel every
/// 6 s, plays through all panels, returns to panel 1 and then STOPS —
/// from there the user swipes manually. Any manual touch also stops the
/// tour immediately.
///
/// Weekly-only. The annual tier is commented out (see `_Tier` /
/// `_priceLine`); only the weekly package is ever purchased.
///
/// Apple 3.1.2: the full auto-renewal + cancellation disclosure now
/// lives in Terms of Use (SUBSCRIPTIONS & AUTO-RENEWAL) rather than
/// bloating the paywall. The paywall keeps the required essentials —
/// price, billing cadence, an "auto-renews · cancel anytime" line, and
/// functional Terms / Privacy / Restore links directly under the CTA.
///
/// Routing contract (unchanged):
///   - `/paywall`                                 → standalone entry.
///   - `/paywall` with extra `{afterPurchase:'/report', imageBytes,
///     geometry, extraImages}`                    → scan-gated entry.
///   - `/paywall` with extra `{unlockInPlace:true}`→ locked-report teaser.
class PaywallScreen extends StatefulWidget {
  /// Optional context forwarded from the scan gate / report teaser.
  final Map<String, dynamic>? context;

  const PaywallScreen({super.key, this.context});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

// Weekly is the only sellable tier now. Annual + rescue remain in the
// enum so the offerings plumbing / analytics stay intact, but the UI
// only ever surfaces and purchases weekly.
enum _Tier { weekly, monthly, annual, rescue }

// Per-panel header copy — (headline, subhead). 1:1 with the mock.
const List<(String, String)> _copy = [
  ('Practice Before It Matters.', 'Train with AI until confidence feels natural.'),
  ('Practice Every Conversation.', 'Handle rejection, flirting and pressure before it\'s real.'),
  ('Practice With AI. Prove It In Real Life.', 'Complete daily missions and become him in 60 days.'),
];

// Classified progress-tracker section labels, one per panel.
const List<String> _sections = ['PRACTICE', 'GAME', 'HIM'];

// Neon green used for the projected score + the final HIM pulse. The
// mock uses a brighter green than the app's signalGreen, so it's local.
const Color _neon = Color(0xFF2EE87A);
const Color _tile = Color(0xFF111113);

class _PaywallScreenState extends State<PaywallScreen> {
  PurchaseOfferings _offerings = PurchaseOfferings.empty();
  bool _purchasing = false;
  /// Defaults FALSE, deliberately. Until we've read the flag we show
  /// the paid copy — over-promising a trial reads as a bait; under-
  /// promising is a slightly duller headline for half a second.
  bool _trialEligible = false;
  /// Monthly by default — it is the tier the trial is attached to and
  /// the one we want him on. Falls back to weekly in _pickDefault() if
  /// the store never delivered a monthly package.
  _Tier _picked = _Tier.monthly;


  // Auto-tour state.

  // Drives the ladder climb on panel 5 — bumped each time that panel
  // becomes visible so the sub-widget restarts its animation.

  @override
  void initState() {
    super.initState();

    // Dev-flag bypass: auto-redirect unless the caller passed
    // `force:true` (the manual preview path). Every other entry bounces
    // straight through so the user stays in-flow.
    final ctx = widget.context ?? const <String, dynamic>{};
    final force = ctx['force'] == true;
    if (kBypassPaywall && !force) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ctx['unlockInPlace'] == true) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
          return;
        }
        final after = ctx['afterPurchase'] as String?;
        if (after != null && ctx.isNotEmpty) {
          context.go(after, extra: ctx);
        } else {
          context.go('/home');
        }
      });
      return;
    }

    AnalyticsService.paywallShown(
        (widget.context?['afterPurchase'] as String?) ?? 'standalone');
    _loadOfferings();
    _autoUnlockIfAlreadyPro();
  }

  /// SELF-HEALING GATE. If this user ALREADY has an active subscription
  /// (bought on an earlier build whose strict entitlement check rejected
  /// it, or on another device), the paywall recognises it the moment it
  /// opens and forwards as a success — no re-buy, no restore tap needed.
  /// This rescues the doom-loop where Apple says "you're currently
  /// subscribed" but the app never flipped the local flag. Silent no-op
  /// for genuinely free users.
  Future<void> _autoUnlockIfAlreadyPro() async {
    try {
      final live = await PurchaseService.isProLive()
          .timeout(const Duration(seconds: 5));
      if (live != true) return;
      if (!mounted || _purchasing) return;
      // isProLive already repainted the local cache to true. Forward
      // exactly like a fresh purchase so scan-gated / unlock-in-place
      // context is honoured.
      await LocalStoreService.setOnboarded(true);
      if (!mounted) return;
      _snack('Subscription active — unlocked.');
      _forwardOnSuccess();
    } catch (_) {
      // Network / timeout — stay on the paywall, normal flow applies.
    }
  }

  // ── Purchase actions (weekly only) ────────────────────────────────

  Package? _packageFor(_Tier t) => switch (t) {
        _Tier.weekly => _offerings.weekly,
        _Tier.monthly => _offerings.monthly,
        _Tier.annual => _offerings.annual,
        _Tier.rescue => _offerings.rescue,
      };

  static const _placeholderDash = '—';

  String _priceFor(_Tier t) {
    final pkg = _packageFor(t);
    if (pkg != null) return pkg.storeProduct.priceString;
    return _placeholderDash;
  }

  /// The free trial attached to the weekly product, if the store is
  /// offering one and this device has not already used one.
  ///
  /// WHY NOT checkTrialOrIntroductoryPriceEligibility(): its return type
  /// is not exported from purchases_flutter, and RevenueCat's own docs
  /// say "Android always returns introEligibilityStatusUnknown" — so it
  /// answers on one platform out of two and cannot be named on either.
  /// The local "has this device ever been in a trial" flag is the same
  /// answer in the overwhelming case and works everywhere.
  ///
  /// THE STORE REMAINS THE AUTHORITY. If he reinstalls and we get this
  /// wrong, Apple's and Google's own purchase sheets still show the real
  /// terms before he confirms, and bill him correctly. This copy is
  /// best-effort; the sheet after it is not.
  IntroductoryPrice? get _trial {
    if (!_trialEligible) return null;
    // The SELECTED tier's offer, not weekly's. The trial lives on
    // monthly; reading weekly's would advertise a trial on the tier that
    // does not have one and hide the one that does.
    final intro = _packageFor(_picked)?.storeProduct.introductoryPrice;
    if (intro == null) return null;
    // A discounted intro period is NOT a free trial. Only a zero price
    // may be called free.
    if (intro.price > 0) return null;
    return intro;
  }

  /// "3 days" / "1 week" — built from the store's own numbers so it can
  /// never contradict what Apple actually charges.
  String _trialLength(IntroductoryPrice t) {
    final n = t.periodNumberOfUnits;
    final unit = switch (t.periodUnit) {
      PeriodUnit.day   => 'day',
      PeriodUnit.week  => 'week',
      PeriodUnit.month => 'month',
      PeriodUnit.year  => 'year',
      _                => 'day',
    };
    return '$n $unit${n == 1 ? '' : 's'}';
  }

  Future<void> _buy() async {
    if (_purchasing) return;
    final pkg = _packageFor(_picked);
    if (pkg == null) {
      // NO PACKAGE = the store never handed us a purchasable product, so
      // there is nothing to charge. This branch used to end at a vague
      // "check your connection" toast — which is exactly backwards: an
      // empty offering does NOT throw, so loadOfferings() returns
      // normally, nothing is logged, and the one screen that could name
      // the cause stayed silent. The diagnostic now runs HERE, where the
      // failure actually happens, instead of only on a purchase error we
      // can never reach from this state.
      HapticFeedback.mediumImpact();
      final diag = await PurchaseService.diagnose();
      if (!mounted) return;
      _showDiagnostic(
          'No purchasable subscription came back from the store, so the '
          'purchase was never started.\n\n──────────\n$diag');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);

    // v285 WATCHDOG — covers the TestFlight failure where the StoreKit
    // sheet completes ("Done") but the Flutter purchase future hangs or
    // resolves as cancelled, so none of the outcome handling below ever
    // runs. The customer-info listener in PurchaseService.init() flips
    // the local subscribed flag the moment RevenueCat registers the
    // transaction; poll it while the future is in flight so a completed
    // payment ALWAYS routes the user forward. Skipped when the user was
    // already subscribed before tapping (nothing to detect).
    var settled = false;
    final wasSubscribed = await LocalStoreService.isSubscribed();
    if (!wasSubscribed) {
      Timer.periodic(const Duration(seconds: 2), (t) async {
        if (settled || !mounted) {
          t.cancel();
          return;
        }
        if (await LocalStoreService.isSubscribed()) {
          t.cancel();
          if (settled || !mounted) return;
          settled = true;
          await LocalStoreService.setOnboarded(true);
          if (!mounted) return;
          setState(() => _purchasing = false);
          _forwardOnSuccess();
        }
      });
    }

    final outcome = await PurchaseService.purchase(pkg);

    if (settled) return; // watchdog already routed forward
    settled = true;
    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (outcome) {
      case PurchaseOutcome.success:
        // Belt-and-suspenders: force the local subscribed flag true here
        // too (purchase() already does, but this guarantees it's on disk
        // before _forwardOnSuccess pops and the report re-reads isPro).
        await LocalStoreService.setSubscribed(true);
        await LocalStoreService.setOnboarded(true);
        if (!mounted) return;
        _forwardOnSuccess();
        break;
      case PurchaseOutcome.cancelled:
        // Never silent — if StoreKit misreports a completed sheet as a
        // cancel we need to SEE it on-device instead of guessing. The
        // watchdog above still unlocks if the transaction actually went
        // through. Harmless for a genuine cancel.
        _snack('Purchase cancelled — you were not charged.');
        break;
      case PurchaseOutcome.noPriorPurchases:
        _snack('No previous purchases found.');
        break;
      case PurchaseOutcome.notConfigured:
        // FAIL CLOSED. This used to unlock the app — permanently, with no
        // transaction behind it and nothing able to take it back: when the
        // store isn't configured, _refreshEntitlementCache() never runs
        // either, so that flag would sit true forever. One failed
        // Purchases.configure() and that user had the paid app for good.
        // A store that won't configure is an error to show, not a gift.
        _snack('Store unavailable right now. Nothing was charged — '
            'try again in a moment.');
        break;
      case PurchaseOutcome.error:
        // Last chance: the RC listener may have registered the
        // transaction even though the purchase call errored. If the
        // flag flipped, the user PAID — forward, don't scare them.
        if (await LocalStoreService.isSubscribed()) {
          await LocalStoreService.setOnboarded(true);
          if (mounted) _forwardOnSuccess();
          break;
        }
        // Purchase didn't unlock. Surface the FULL RevenueCat state so we
        // can see exactly what the store returned (offering, weekly
        // product id, active subs, "pro" entitlement) instead of a vague
        // toast — this is how we diagnose "paid but nothing unlocked".
        final diag = await PurchaseService.diagnose();
        if (!mounted) return;
        final detail = PurchaseService.lastErrorMessage;
        _showDiagnostic('${detail ?? 'Purchase could not complete.'}'
            '\n\n──────────\n$diag');
        break;
    }
  }

  Future<void> _restore() async {
    HapticFeedback.selectionClick();
    final outcome = await PurchaseService.restore();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        _snack('Subscription restored.');
        if (mounted) _forwardOnSuccess();
        break;
      case PurchaseOutcome.noPriorPurchases:
        _snack('No previous purchases found.');
        break;
      case PurchaseOutcome.notConfigured:
        _snack('Store not yet configured.');
        break;
      case PurchaseOutcome.cancelled:
      case PurchaseOutcome.error:
        _snack('Could not restore purchases.');
        break;
    }
  }

  void _forwardOnSuccess() {
    // He paid — the ladder stops immediately and permanently. Nothing
    // reads worse than being sold something you already bought.
    // ignore: discarded_futures
    WinBackService.markConverted();
    final ctx = widget.context;
    if (ctx != null && ctx['afterPurchase'] == '/report') {
      context.go('/report', extra: {
        'imageBytes': ctx['imageBytes'],
        'geometry': ctx['geometry'],
        'extraImages': ctx['extraImages'] ?? const <dynamic>[],
      });
    } else if (ctx != null && ctx['afterPurchase'] == '/onboarding/profile') {
      // Straight on to the test, via the one screen that asks his name
      // and age — both feed the woman he is about to be scored against,
      // so it earns its place. Nothing else stands between the payment
      // and the number he paid for.
      context.go('/onboarding/profile');
    } else if (ctx != null && ctx['unlockInPlace'] == true) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      context.go('/home');
    }
    // ignore: discarded_futures
    ReviewPromptService.maybePromptAfterPurchase(context);
  }

  void _close() async {
    HapticFeedback.selectionClick();
    AnalyticsService.paywallDismissed(
        (widget.context?['afterPurchase'] as String?) ?? 'standalone');
    // THE WALK. He read the whole thing and closed it — the most
    // recoverable user in the funnel, and the one generic "open the app!"
    // copy is most wasted on. Arm the win-back ladder with the gate he
    // bounced off so the first message can name it.
    await WinBackService.markPaywallWalked(
        (widget.context?['source'] as String?) ?? 'standalone');
    if (kPaywallDemoUnlock) {
      // DEMO / RECORDING ONLY — pressing X unlocks the app so the paid features
      // can be shown after the paywall. Never true in the submitted build.
      await LocalStoreService.setSubscribed(true);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      // Explicit white text — default snackbar styling rendered this
      // black-on-black (invisible strip) on the black background.
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35)),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showDiagnostic(String diag) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Store status',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: SelectableText(diag,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.4)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diag));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied. Paste into chat for help.')));
            },
            child: const Text('COPY'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _trial;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // ── Chrome: close only. No share — a man has nothing to share
          //    yet, and the button that dismisses the price should not
          //    have a twin next to it competing for the same tap.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Row(children: [
              _CloseX(onTap: _close),
              const Spacer(),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(children: [
                _kicker('YOUR FIRST TEST IS READY'),
                const SizedBox(height: 10),
                _headline(),
                const SizedBox(height: 6),
                const _ScoreMark(),
                const SizedBox(height: 10),
                Text('One live conversation. No scripts. No hints.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 18),
                const _AxisRow(),
                const SizedBox(height: 26),
                _sectionRule(t == null
                    ? 'WHAT YOU GET'
                    : 'TRY THE FULL SYSTEM FREE'),
                const SizedBox(height: 18),
                // Every line is something the app actually does. "Unlimited
                // voice" and "all characters" were both false — voice is
                // metered at 14 min/week and the roster unlocks by
                // ascension day, not by paying.
                const _Feature(
                  icon: Icons.mic_rounded,
                  title: 'VOICE GAME TEST',
                  body: 'Get your score and find your weakest skill',
                ),
                const _Feature(
                  icon: Icons.chat_bubble_rounded,
                  title: 'UNLIMITED CHAT PRACTICE',
                  body: 'Train your game with unlimited reps',
                ),
                const _Feature(
                  icon: Icons.group_rounded,
                  title: '10 AI WOMEN',
                  body: 'Progress from Into You  →  Ice Queen',
                ),
                const SizedBox(height: 6),
                Text('+ Coaching · Missions · Battles · Squads · Ranks',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 22),
                _tier(_Tier.monthly, 'MONTH', trial: t),
                const SizedBox(height: 10),
                _tier(_Tier.weekly, 'WEEK', trial: null),
              ]),
            ),
          ),
          _bottom(t),
        ]),
      ),
    );
  }

  Widget _kicker(String text) => Row(children: [
        Expanded(child: Container(height: 1, color: AppColors.red.withValues(alpha: 0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 11.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
              )),
        ),
        Expanded(child: Container(height: 1, color: AppColors.red.withValues(alpha: 0.35))),
      ]);

  Widget _headline() => Column(children: [
        Text('HOW GOOD IS',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 42,
              height: 1.0,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
        Text('YOUR GAME?',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 42,
              height: 1.05,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
      ]);

  Widget _sectionRule(String label) => Row(children: [
        Expanded(child: Container(height: 1, color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              )),
        ),
        Expanded(child: Container(height: 1, color: Colors.white24)),
      ]);

  /// One price row. Price and period come from the store, never from
  /// here — a hardcoded figure is wrong the moment someone opens the app
  /// outside your country, and both stores treat that as a review issue.
  Widget _tier(_Tier tier, String period, {IntroductoryPrice? trial}) {
    final pkg = _packageFor(tier);
    final sel = _picked == tier;
    final price = _priceFor(tier);
    final live = pkg != null;
    return Opacity(
      opacity: live ? 1 : 0.4,
      child: GestureDetector(
        onTap: live
            ? () {
                HapticFeedback.selectionClick();
                setState(() => _picked = tier);
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.red.withValues(alpha: 0.12)
                : const Color(0xFF121216),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: sel ? AppColors.red : Colors.white12,
                width: sel ? 2 : 1),
            boxShadow: sel
                ? [BoxShadow(color: AppColors.red.withValues(alpha: 0.28), blurRadius: 22)]
                : null,
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trial != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${_trialLength(trial).toUpperCase()} FREE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic, children: [
                    Text(price,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 5),
                    Text('/ $period',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                      !live
                          ? 'Not available on this store yet'
                          : trial != null
                              ? 'Then $price/${period.toLowerCase()} after your trial'
                              : 'No free trial',
                      style: GoogleFonts.inter(
                        color: trial != null
                            ? AppColors.red
                            : AppColors.textTertiary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? AppColors.red : Colors.white30, width: 2),
                color: sel ? AppColors.red : Colors.transparent,
              ),
              child: sel
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }

  /// CTA + the disclosure Apple 3.1.2 requires: length, what follows,
  /// and the renewing price, before the tap.
  Widget _bottom(IntroductoryPrice? t) {
    final price = _priceFor(_picked);
    final period = _picked == _Tier.monthly ? 'month' : 'week';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.45),
                    blurRadius: 28, spreadRadius: 1),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _purchasing ? null : _buy,
              child: _purchasing
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            t == null
                                ? 'START TRAINING'
                                : 'START MY ${_trialLength(t).toUpperCase()} FREE TRIAL',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 1),
                        Text('Take your first voice test now',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            )),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            t == null
                ? '$price per $period · auto-renews · cancel anytime'
                : '${_trialLength(t)} free, then $price/$period. '
                  'Subscription auto-renews. Cancel anytime.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            )),
        // The one limit that would otherwise be a surprise. A man who
        // starts a trial expecting unlimited voice, hits the wall after a
        // minute and refunds costs more than the one who never converted.
        if (t != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
                'Trial includes ${TrialService.trialVoiceMinutes} minute of '
                'live voice. Texting is unlimited.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LinkButton(label: 'Restore', onTap: _restore),
            _LinkButton(
                label: 'Terms of Use',
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/terms');
                }),
            _LinkButton(
                label: 'Privacy Policy',
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/privacy');
                }),
          ],
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════



// ══════════════════════════════════════════════════════════════════════
//  PANEL 1 — THE AI GIRLS (roleplay showcase)
// ══════════════════════════════════════════════════════════════════════



// ══════════════════════════════════════════════════════════════════════
//  PANEL (legacy) — PHOTO + SCORE  ·  no longer in the carousel
// ══════════════════════════════════════════════════════════════════════

// ignore: unused_element






// ══════════════════════════════════════════════════════════════════════
//  PANEL (legacy) — PROTOCOL LIST  ·  no longer in the carousel
// ══════════════════════════════════════════════════════════════════════

// ignore: unused_element




// ══════════════════════════════════════════════════════════════════════
//  PANEL 3 — ORB / HOLD TO SPEAK
// ══════════════════════════════════════════════════════════════════════





// ══════════════════════════════════════════════════════════════════════
//  PANEL (legacy) — RIZZ ACTIONS  ·  no longer in the carousel
// ══════════════════════════════════════════════════════════════════════

// ignore: unused_element


// ignore: unused_element


// ══════════════════════════════════════════════════════════════════════
//  PANEL 5 — ASCENSION LADDER
// ══════════════════════════════════════════════════════════════════════





// ══════════════════════════════════════════════════════════════════════
//  CLASSIFIED PROGRESS TRACKER
// ══════════════════════════════════════════════════════════════════════



// ══════════════════════════════════════════════════════════════════════
//  SHARED
// ══════════════════════════════════════════════════════════════════════

/// The withheld number. Same object as onboarding beat 4 — the whole
/// funnel asks one question and this is the last place it goes
/// unanswered.
class _ScoreMark extends StatelessWidget {
  const _ScoreMark();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 96,
              height: 1.0,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              shadows: [
                BoxShadow(color: AppColors.red.withValues(alpha: 0.7), blurRadius: 40)
                    .toShadow(),
              ],
            )),
        Text('/100',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 62,
              height: 1.0,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
      ],
    );
  }
}

extension _ShadowX on BoxShadow {
  Shadow toShadow() => Shadow(color: color, blurRadius: blurRadius);
}

/// The five axes as locked tiles. Named, so he knows what is being
/// measured; locked, so he knows he has not been measured yet.
class _AxisRow extends StatelessWidget {
  const _AxisRow();
  static const _axes = <(IconData, String)>[
    (Icons.psychology_rounded, 'CONFIDENCE'),
    (Icons.waves_rounded, 'FLOW'),
    (Icons.lightbulb_rounded, 'WIT'),
    (Icons.restart_alt_rounded, 'RECOVERY'),
    (Icons.gps_fixed_rounded, 'CLOSE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, a) in _axes.indexed) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121216),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(children: [
                Icon(a.$1, color: AppColors.red, size: 22),
                const SizedBox(height: 7),
                Text(a.$2,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8.5,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// One thing he gets, with the detail underneath so the title can stay
/// short enough to read in a glance.
class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Feature(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.red, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 2),
              Text(body,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CloseX extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseX({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.22), width: 0.8),
          ),
          child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            color: const Color(0xFFC9C9D0),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
