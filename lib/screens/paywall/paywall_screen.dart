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

  Future<void> _loadOfferings() async {
    final off = await PurchaseService.loadOfferings();
    // Both stores allow one intro offer per subscription group, ever. A
    // device that has already been in a trial is not getting another, so
    // do not advertise one to it.
    final eligible = !(await TrialService.everStarted());
    if (!mounted) return;
    setState(() {
      _offerings = off;
      _trialEligible = eligible;
      // Never sit on a tier the store did not deliver — the CTA would be
      // a button that cannot transact.
      if (off.monthly == null && off.weekly != null) _picked = _Tier.weekly;
    });
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
      await _markOnboarded();
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
          await _markOnboarded();
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
        await _markOnboarded();
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
          await _markOnboarded();
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

  /// Onboarding is finished on the HANDLE screen, not here.
  ///
  /// Paying is not the same as being set up: sign-in and handle both sit
  /// after this screen, so stamping "onboarded" on a purchase meant a man
  /// who paid and then closed the app came back to /home with no account
  /// and no name, and was never asked again. Inside the funnel we leave
  /// the flag alone and let the resume marker carry him; everywhere else
  /// (the scan gate, the locked report, a mid-app upsell) he is already
  /// onboarded and this is the harmless no-op it always was.
  Future<void> _markOnboarded() async {
    final after = widget.context?['afterPurchase'] as String?;
    if (after == '/onboarding/profile') return;
    await LocalStoreService.setOnboarded(true);
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
    // CLOSING THE PRICE IS NOT LEAVING THE FUNNEL.
    //
    // This used to pop, or fall through to /home. Inside onboarding that
    // meant one tap on the X dropped him at the home screen having never
    // signed in and never picked a handle — both of those screens live
    // AFTER the paywall. He looked like a user with no account, because
    // he was one, and nothing ever asked him again.
    //
    // He does not get the product by closing this — every voice session
    // and every mission is still gated on PaywallGate. He gets the rest
    // of his setup, which was never the thing being sold.
    final after = widget.context?['afterPurchase'] as String?;
    if (after == '/onboarding/profile') {
      context.go('/onboarding/profile');
      return;
    }
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

  /// The per-day cost of a package, in the store's own currency.
  ///
  /// Derived from the LOCALISED priceString rather than formatted from
  /// the raw double: there is no intl package here, and hand-formatting
  /// a currency puts the symbol on the wrong side in half of Europe and
  /// the decimal separator on the wrong character in the other half.
  /// Swapping the number inside the string the store already gave us
  /// keeps the symbol, its position and the separator exactly right.
  ///
  /// Returns null rather than guessing — a wrong price is a review
  /// issue; a missing line is a gap.
  String? _perDay(_Tier t, int days) {
    final p = _packageFor(t)?.storeProduct;
    if (p == null || p.price <= 0) return null;
    final m = RegExp(r'\d[\d.,  ]*\d|\d').firstMatch(p.priceString);
    if (m == null) return null;
    final numeric = p.priceString.substring(m.start, m.end);
    // The LAST separator is the decimal one, so "1.234,56" and
    // "1,234.56" both resolve correctly.
    final cut = numeric.lastIndexOf(',') > numeric.lastIndexOf('.')
        ? numeric.lastIndexOf(',')
        : numeric.lastIndexOf('.');
    // …unless it is followed by exactly THREE digits, in which case it
    // is a thousands separator and this currency has no minor unit.
    // "¥2,999" was becoming "¥99,97" — a yen price with pence in it.
    final tail = cut < 0 ? 0 : numeric.length - cut - 1;
    final zeroDecimal = cut < 0 || tail == 3;
    final sep = cut < 0 ? '.' : numeric[cut];
    final raw = p.price / days;
    final per = zeroDecimal
        ? raw.round().toString()
        : raw.toStringAsFixed(2).replaceAll('.', sep);
    return p.priceString.replaceRange(m.start, m.end, per);
  }

  /// Natural (unscaled) height of the pitch block, in logical pixels.
  /// Everything between the top bar and the CTA is sized as a fraction
  /// of the room actually available, and this is the denominator. It is
  /// measured from the laid-out design, not guessed — if the block below
  /// grows, this number grows with it.
  static const double _contentDesignHeight = 540;

  @override
  Widget build(BuildContext context) {
    final t = _trial;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          _topBar(),

          // ONE SCREEN, ALWAYS — and never a blank one.
          //
          // b235 did this with FittedBox(scaleDown), which hands its
          // child UNBOUNDED height. The tier row inside used
          // CrossAxisAlignment.stretch, which requires a bounded cross
          // axis, so the subtree threw during layout and painted
          // NOTHING: top bar, black void, CTA. That is the screenshot.
          //
          // This measures instead of scaling. LayoutBuilder reports the
          // real room left between the bar and the CTA, every size below
          // is a fraction of it, and a scroll view sits underneath as a
          // safety valve — so a font fallback or a large accessibility
          // setting overflows harmlessly instead of blanking the screen.
          // Nothing in here is ever handed an unbounded constraint.
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final s =
                  (box.maxHeight / _contentDesignHeight).clamp(0.70, 1.0).toDouble();
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _pitch(s, t),
                  ),
                ),
              );
            }),
          ),

          _cta(t),
        ]),
      ),
    );
  }

  /// The pitch: promise, the loop, the withheld number, the price.
  /// `s` is the density factor — 1.0 on a big phone, ~0.8 on an SE.
  Widget _pitch(double s, IntroductoryPrice? t) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _headline(s),
          SizedBox(height: 6 * s),
          Text('Stop guessing. Start training.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15.5 * s,
                fontWeight: FontWeight.w500,
              )),
          SizedBox(height: 14 * s),
          _Step(
            n: '1',
            title: 'GET TESTED ACROSS KEY METRICS',
            body: 'Get your score across 5 key skills:',
            // THE REAL FIVE — the dimensions the grader returns and
            // the Progress tab keeps. Naming a rubric he never sees
            // was a promise the app could not show him afterwards.
            axes: 'Confidence · Presence · Game · Humour · Listening',
            scale: s,
          ),
          _Step(
            n: '2',
            title: 'TRAIN WITH AI & GET PERSONAL ADVICE',
            body: 'Practice real conversations, get scored, and get told '
                'exactly what to fix next.',
            scale: s,
          ),
          _Step(
            n: '3',
            title: 'COMPLETE REAL WORLD MISSIONS',
            body: 'Take it into the real world with daily missions and '
                'watch your game level up.',
            last: true,
            scale: s,
          ),
          SizedBox(height: 10 * s),
          _ScoreStrip(scale: s),
          SizedBox(height: 10 * s),
          // IntrinsicHeight is what makes `stretch` legal here: it
          // measures the taller card and passes a TIGHT height down, so
          // the Row's cross axis is bounded and both cards match. The
          // b235 version had the stretch without it.
          IntrinsicHeight(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: _tierCard(_Tier.monthly, 'MONTH', t, 30, s)),
                  SizedBox(width: 10 * s),
                  Expanded(
                      child: _tierCard(_Tier.weekly, 'WEEK', null, 7, s)),
                ]),
          ),
        ],
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        child: Row(children: [
          _CloseX(onTap: _close),
          Expanded(
            child: Text('IMHIM PRO',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 15,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
          ),
          GestureDetector(
            onTap: _restore,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text('Restore',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
        ]),
      );

  Widget _headline(double s) => Column(children: [
        Text('LEVEL UP',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 46 * s,
              height: 0.98,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
        Text('YOUR GAME.',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 46 * s,
              height: 1.0,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
      ]);

  /// One price card. Every figure on it comes from the store.
  Widget _tierCard(_Tier tier, String period, IntroductoryPrice? trial,
      int daysInPeriod, double s) {
    final pkg = _packageFor(tier);
    final live = pkg != null;
    final sel = _picked == tier;
    final perDay = _perDay(tier, daysInPeriod);
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
          padding: EdgeInsets.fromLTRB(13 * s, 10 * s, 13 * s, 10 * s),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.red.withValues(alpha: 0.10)
                : const Color(0xFF121216),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: sel ? AppColors.red : Colors.white12,
                width: sel ? 2 : 1),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.30),
                        blurRadius: 22)
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The badge and its absence take the same height, so the
              // two cards stay level whichever one carries the trial.
              SizedBox(
                height: 18 * s,
                child: trial == null
                    ? null
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                              '${_trialLength(trial).toUpperCase()} FREE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                      ),
              ),
              SizedBox(height: 6 * s),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_priceFor(tier),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 26 * s,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(width: 4),
                      Text('/ $period',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
              ),
              SizedBox(height: 3 * s),
              // THE PER-DAY LINE. The monthly price is a decision; the
              // same money said per day is a rounding error, and it is
              // the unit he already thinks about spending in.
              Text(
                  !live
                      ? 'Not on this store yet'
                      : perDay != null
                          ? 'Just $perDay a day'
                          : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: perDay != null
                        ? AppColors.red
                        : AppColors.textTertiary,
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w800,
                  )),
              SizedBox(height: 7 * s),
              Row(children: [
                Container(
                  width: 18 * s,
                  height: 18 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: sel ? AppColors.red : Colors.white30, width: 2),
                    color: sel ? AppColors.red : Colors.transparent,
                  ),
                  child: sel
                      ? Icon(Icons.check_rounded,
                          size: 12 * s, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 7 * s),
                Expanded(
                  child: Text(trial != null ? 'Most Popular' : 'No free trial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: trial != null
                            ? AppColors.red
                            : AppColors.textTertiary,
                        fontSize: 12 * s,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Pinned. Never inside anything that can scroll or scale away.
  Widget _cta(IntroductoryPrice? t) {
    final price = _priceFor(_picked);
    final period = _picked == _Tier.monthly ? 'month' : 'week';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 1),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _purchasing ? null : _buy,
              child: _purchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            t == null
                                ? 'START TRAINING'
                                : 'START MY ${_trialLength(t).toUpperCase()} FREE TRIAL',
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                      const SizedBox(height: 2),
                      Text('Take your first voice test now',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          )),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            t == null
                ? '$price per $period · auto-renews · cancel anytime'
                : '${_trialLength(t)} free, then $price/$period. '
                    'Auto-renews. Cancel anytime.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w600,
            )),
        if (t != null)
          Text(
              'Trial includes one ${TrialService.trialVoiceMinutes}-minute '
              'voice test. Texting is unlimited.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              )),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _LinkButton(label: 'Restore Purchases', onTap: _restore),
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
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SHARED
// ══════════════════════════════════════════════════════════════════════

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

/// One numbered promise. Three of these ARE the pitch — the whole
/// product loop stated once, in order, with nothing between them.
class _Step extends StatelessWidget {
  final String n, title, body;
  final String? axes;
  final bool last;
  final double scale;
  const _Step({
    required this.n,
    required this.title,
    required this.body,
    required this.scale,
    this.axes,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10 * s),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28 * s,
            height: 28 * s,
            margin: EdgeInsets.only(top: 1 * s),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: Icon(Icons.check_rounded, size: 16 * s, color: AppColors.red),
          ),
          SizedBox(width: 11 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$n. $title',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15 * s,
                      height: 1.15,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w900,
                    )),
                SizedBox(height: 3 * s),
                Text(body,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13.5 * s,
                      height: 1.32,
                      fontWeight: FontWeight.w500,
                    )),
                if (axes != null) ...[
                  SizedBox(height: 2 * s),
                  // Named, because the five axes ARE the product. A man
                  // who can name what he is being marked on believes the
                  // mark more than one who is told he gets "a score".
                  Text(axes!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13 * s,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ),
        ]),
        if (!last) ...[
          SizedBox(height: 10 * s),
          Container(
              height: 1,
              margin: EdgeInsets.only(left: 39 * s),
              color: Colors.white.withValues(alpha: 0.08)),
        ],
      ]),
    );
  }
}

/// The withheld number, as a strip rather than a hero — the same object
/// as onboarding beat 4, but this screen has a price to get to and the
/// question only needs restating, not re-asking.
class _ScoreStrip extends StatelessWidget {
  final double scale;
  const _ScoreStrip({required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.fromLTRB(15 * s, 11 * s, 15 * s, 11 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('YOUR FIRST GAME TEST IS READY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 10 * s,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  )),
              SizedBox(height: 2 * s),
              Text('YOUR SCORE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17 * s,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ),
        Container(width: 1, height: 32 * s, color: Colors.white12),
        SizedBox(width: 13 * s),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('?',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 36 * s,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  )),
              Text('/100',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28 * s,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  )),
            ]),
      ]),
    );
  }
}
