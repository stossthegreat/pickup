import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Package;

import '../../config/purchase_config.dart';
import '../../services/paywall_gate.dart';
import '../../services/purchase_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';

/// OUT OF MINUTES — the highest-intent screen in the app.
///
/// He is mid-conversation with a woman, it is going well, and the clock
/// has run out. There is no moment in this product where a man wants
/// something more than he wants the next sixty seconds of that call.
///
/// The bottom sheet that used to serve this moment treated it as a
/// utility — pick a pack, pay, dismiss. This is full-screen and it opens
/// on HER, because what he is buying is not minutes, it is the rest of
/// the conversation he was in the middle of.
///
/// RULES IT KEEPS FROM THE SHEET, because they were right:
///   * PRO ONLY. A man who has not subscribed has no minutes to run out
///     of. If he somehow lands here he gets the subscription paywall —
///     selling a top-up to a non-subscriber teaches him to buy packs
///     forever and never subscribe, which is a worse business at every
///     volume.
///   * NO HARDCODED PRICES. Every figure is storeProduct.priceString,
///     already localised by the store. A hardcoded price is wrong the
///     moment someone opens the app outside your country, and both
///     stores treat misrepresented pricing as a review issue.
///   * NO DEAD BUTTONS. If the packs are not in the current offering —
///     the normal state on iOS until the consumables clear App Store
///     Connect — it says so plainly instead of rendering a CTA that
///     cannot transact.
class MinutesPaywall {
  /// Returns true if he bought minutes, so the caller can carry straight
  /// on with the call he was blocked from.
  static Future<bool> show(
    BuildContext context, {
    /// The woman he was talking to, if we know. Her face is the whole
    /// argument — without it this is a receipt.
    String? girlId,
  }) async {
    if (!await PaywallGate.isPro()) {
      if (!context.mounted) return false;
      await PaywallGate.open(context, source: 'voice_cap');
      return PaywallGate.isPro();
    }
    if (!context.mounted) return false;
    final bought = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => _MinutesPaywall(girlId: girlId),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    return bought ?? false;
  }
}

class _MinutesPaywall extends StatefulWidget {
  final String? girlId;
  const _MinutesPaywall({this.girlId});

  @override
  State<_MinutesPaywall> createState() => _MinutesPaywallState();
}

class _MinutesPaywallState extends State<_MinutesPaywall> {
  PurchaseOfferings? _offerings;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _picked = 0;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final o = await PurchaseService.loadOfferings();
    if (!mounted) return;
    setState(() {
      _offerings = o;
      // Default to the middle pack where there is one. The largest is
      // the best per-minute deal and the sheet used to preselect it,
      // but preselecting the most expensive thing on a screen a man
      // reached by being interrupted reads as a stitch-up.
      _picked = o.extras.isEmpty ? 0 : (o.extras.length >= 3 ? 1 : 0);
      _loading = false;
    });
  }

  List<Package> get _packs => _offerings?.extras ?? const [];

  int _minutesOf(Package p) =>
      PurchaseConfig.minutesFor(p.storeProduct.identifier);

  /// Per-minute saving of [p] against the SMALLEST pack, whole percent.
  /// Null when it cannot be computed from two real prices — a claimed
  /// saving that isn't true is worse than no badge.
  int? _saving(Package p) {
    if (_packs.length < 2) return null;
    final base = _packs.first;
    if (identical(base, p)) return null;
    final mb = _minutesOf(base), mp = _minutesOf(p);
    if (mb <= 0 || mp <= 0) return null;
    final pb = base.storeProduct.price, pp = p.storeProduct.price;
    if (pb <= 0 || pp <= 0) return null;
    final perBase = pb / mb, perThis = pp / mp;
    if (perThis >= perBase) return null;
    return ((1 - perThis / perBase) * 100).round();
  }

  Future<void> _buy() async {
    if (_busy || _packs.isEmpty) return;
    final pkg = _packs[_picked.clamp(0, _packs.length - 1)];
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    final outcome = await PurchaseService.purchase(pkg);
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        // The minutes are credited inside PurchaseService the instant
        // the transaction returns, keyed by store transaction id so a
        // replay cannot double-grant. Nothing to do here but confirm
        // and get out of his way — he is mid-conversation.
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(true);
      case PurchaseOutcome.cancelled:
        // A cancel is not an error and must never be dressed as one.
        setState(() => _busy = false);
      case PurchaseOutcome.error:
      case PurchaseOutcome.notConfigured:
      case PurchaseOutcome.noPriorPurchases:
        setState(() {
          _busy = false;
          _error = PurchaseService.lastErrorMessage ??
              'That didn\'t go through. Nothing was charged.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final girl = widget.girlId == null ? null : girlById(widget.girlId!);
    final accent = girl?.accent ?? AppColors.red;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(children: [
        // HER, full bleed, faded into the page. This is the argument.
        if (girl != null)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.28, 0.62],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset(girl.asset,
                  fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 26),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("YOU'RE OUT OF MINUTES",
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 10),
                  Text(
                      girl == null
                          ? 'Mid-sentence.'
                          : '${girl.name.toUpperCase()} IS\nSTILL WAITING.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.02,
                        letterSpacing: -1.6,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 12),
                  Text(
                      'Your weekly minutes reset on Monday. Or you pick '
                      'the conversation back up right now.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            _body(accent),
          ]),
        ),
      ]),
    );
  }

  Widget _body(Color accent) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 44),
        child: SizedBox(
          height: 34,
          width: 34,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    if (_packs.isEmpty) {
      // Say the true thing. A CTA here could not transact.
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top-ups are not available on this store yet.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text('Your minutes reset on Monday and everything else — texting, '
              'battles, the map — is untouched in the meantime.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              )),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(children: [
        for (final (i, p) in _packs.indexed) ...[
          _PackRow(
            minutes: _minutesOf(p),
            price: p.storeProduct.priceString,
            saving: _saving(p),
            selected: i == _picked,
            accent: accent,
            onTap: _busy
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _picked = i);
                  },
          ),
          const SizedBox(height: 10),
        ],
        if (_error != null) ...[
          const SizedBox(height: 2),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _busy ? null : _buy,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text('KEEP TALKING',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    )),
          ),
        ),
        const SizedBox(height: 10),
        // Was "minutes never expire" — see extra_sheet.dart. They
        // last 30 days now and the man buying has to be told so here,
        // before he pays, not after they lapse.
        Text('One-time purchase · minutes last 30 days · not a subscription',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            )),
      ]).animate().fadeIn(duration: 260.ms),
    );
  }
}

/// One pack. The minutes lead because that is what he is short of; the
/// price is secondary and the saving is a badge, not a headline.
class _PackRow extends StatelessWidget {
  final int minutes;
  final String price;
  final int? saving;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  const _PackRow({
    required this.minutes,
    required this.price,
    required this.saving,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.13)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? accent : Colors.white24, width: 2),
              color: selected ? accent : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 14),
          Text('$minutes MIN',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 17,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w900,
              )),
          if (saving != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('SAVE $saving%',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ],
          const Spacer(),
          Text(price,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              )),
        ]),
      ),
    );
  }
}
