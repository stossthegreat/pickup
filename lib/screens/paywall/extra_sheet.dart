import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Package;

import '../../config/purchase_config.dart';
import '../../services/backend/tiers.dart';
import '../../services/extra_service.dart';
import '../../services/local_store_service.dart';
import '../../services/paywall_gate.dart';
import '../../services/purchase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/game_feel.dart';

/// EXTRA — voice minutes, sold at the exact moment they're wanted.
///
/// Before this existed the code at the cap said, in as many words,
/// "Pro user out of weekly minutes — nothing to sell, so no paywall
/// trip." He was mid-conversation, he wanted to keep going, and the
/// app told him to come back Monday. That is the highest-intent moment
/// this product will ever have and it was being spent on an apology.
///
/// ──────────────────────────────────────────────────────────────────
/// THE RULES THIS SHEET OBEYS
/// ──────────────────────────────────────────────────────────────────
///
/// PRO ONLY. A man who isn't subscribed has no minutes to run out of,
/// so he can never legitimately reach this sheet. If he somehow does,
/// he gets the paywall instead — selling a £4.99 pack to someone who
/// hasn't taken the £6.99 subscription teaches him to buy packs
/// forever and never subscribe, which is a worse business at every
/// volume.
///
/// NO HARDCODED PRICES, EVER. Every figure comes from RevenueCat's
/// storeProduct.priceString, which is already localised into his
/// currency by the store. A hardcoded price is wrong the moment
/// someone opens the app outside your country, and both stores treat
/// misrepresented pricing as a review issue.
///
/// NO DEAD BUTTONS. If the packs aren't in the current offering —
/// which is the normal state on iOS until the consumables clear App
/// Store Connect — the sheet says so plainly instead of rendering a
/// CTA that cannot transact.
///
/// THE VALUE MATHS IS SHOWN AS A PERCENTAGE, not a per-minute price.
/// A percentage needs no currency formatting, so it can't be wrong in
/// any locale, and "SAVE 17%" is the number he's actually deciding on.
class ExtraSheet {
  /// Open it. [remainingMinutes] 0 means he's hit the wall; anything
  /// higher is the soft nudge before he does.
  ///
  /// Returns true if he bought something, so the caller can carry on
  /// with whatever he was blocked from doing.
  static Future<bool> show(
    BuildContext context, {
    required int remainingMinutes,
  }) async {
    // Never sell a top-up to someone who hasn't subscribed.
    if (!await PaywallGate.isPro()) {
      if (!context.mounted) return false;
      await PaywallGate.open(context, source: 'voice_cap');
      return PaywallGate.isPro();
    }
    if (!context.mounted) return false;
    final bought = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExtraSheet(remainingMinutes: remainingMinutes),
    );
    return bought ?? false;
  }
}

class _ExtraSheet extends StatefulWidget {
  final int remainingMinutes;
  const _ExtraSheet({required this.remainingMinutes});

  @override
  State<_ExtraSheet> createState() => _ExtraSheetState();
}

class _ExtraSheetState extends State<_ExtraSheet> {
  PurchaseOfferings? _offerings;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Defaults to the bigger pack — it's the better deal per minute and
  /// pre-selecting it is honest rather than sly.
  bool _pickBig = true;

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
      // If only one pack made it into the offering, select that one.
      if (o.extra20 == null) _pickBig = false;
      _loading = false;
    });
  }

  Package? get _selected {
    final o = _offerings;
    if (o == null) return null;
    return _pickBig ? (o.extra20 ?? o.extra10) : (o.extra10 ?? o.extra20);
  }

  int _minutesOf(Package? p) =>
      p == null ? 0 : PurchaseConfig.minutesFor(p.storeProduct.identifier);

  /// How much better the big pack is per minute, as a whole percent.
  /// Null when we can't compute it honestly from two real prices.
  int? get _saving {
    final o = _offerings;
    final small = o?.extra10;
    final big = o?.extra20;
    if (small == null || big == null) return null;
    final ms = _minutesOf(small), mb = _minutesOf(big);
    if (ms <= 0 || mb <= 0) return null;
    final ps = small.storeProduct.price, pb = big.storeProduct.price;
    if (ps <= 0 || pb <= 0) return null;
    final perSmall = ps / ms, perBig = pb / mb;
    if (perBig >= perSmall) return null; // no saving to claim
    return ((1 - perBig / perSmall) * 100).round();
  }

  Future<void> _buy() async {
    final pkg = _selected;
    if (pkg == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Feel.tick();
    final outcome = await PurchaseService.purchase(pkg);
    if (!mounted) return;

    switch (outcome) {
      case PurchaseOutcome.success:
        // The minutes were credited inside PurchaseService the moment
        // the transaction returned — see the grant there. Nothing to do
        // here but confirm it and get out of his way.
        Feel.win();
        if (mounted) Navigator.of(context).pop(true);
      case PurchaseOutcome.cancelled:
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
    final o = _offerings;
    final out = widget.remainingMinutes <= 0;
    final available = o != null && o.hasExtra;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (out ? AppColors.red : kNeon).withValues(alpha: 0.13),
            AppColors.base,
          ],
          stops: const [0, 0.5],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, 22 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),

        Text(out ? 'OUT OF MINUTES' : 'MINUTES RUNNING LOW',
            style: GoogleFonts.inter(
              color: out ? AppColors.red : AppColors.signalAmber,
              fontSize: 11,
              letterSpacing: 4.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 14),

        // The number he's actually looking at.
        Text(out ? '0' : '${widget.remainingMinutes}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 66,
                  height: 1,
                  letterSpacing: -3,
                  fontWeight: FontWeight.w900,
                ))
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(
                begin: const Offset(0.86, 0.86),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack),
        const SizedBox(height: 4),
        Text('MINUTES LEFT THIS WEEK',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 8.5,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 20),

        Text(
            out
                ? 'Your free minutes renew next week.\nOr keep talking right now.'
                : 'Enough for one more conversation.\nTop up before she gets interesting.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 24),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.red)),
          )
        else if (!available)
          // No dead buttons. On iOS this is the normal state until the
          // consumables clear App Store Connect.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
                'Top-ups aren\'t available on this device yet.\n'
                'Your minutes renew next week.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                )),
          )
        else ...[
          Row(children: [
            if (o.extra10 != null)
              Expanded(
                child: _PackTile(
                  pkg: o.extra10!,
                  minutes: _minutesOf(o.extra10),
                  selected: !_pickBig,
                  badge: null,
                  onTap: () {
                    Feel.tick();
                    setState(() => _pickBig = false);
                  },
                ),
              ),
            if (o.extra10 != null && o.extra20 != null)
              const SizedBox(width: 11),
            if (o.extra20 != null)
              Expanded(
                child: _PackTile(
                  pkg: o.extra20!,
                  minutes: _minutesOf(o.extra20),
                  selected: _pickBig,
                  badge: _saving == null ? 'BEST VALUE' : 'SAVE ${_saving}%',
                  onTap: () {
                    Feel.tick();
                    setState(() => _pickBig = true);
                  },
                ),
              ),
          ]),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.signalRed,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: GameButton(
              label: _busy
                  ? 'ONE SECOND…'
                  : 'GET ${_minutesOf(_selected)} MINUTES',
              color: kNeon,
              textColor: Colors.black,
              pulse: !_busy,
              onTap: _busy ? null : _buy,
            ),
          ),
          const SizedBox(height: 8),
          // Required honesty, and it's also reassuring: a one-off is a
          // smaller decision than a subscription and saying so out loud
          // removes the main hesitation.
          Text('One-off payment. Not a subscription. Minutes never expire.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              )),
        ],

        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(out ? 'I\'LL WAIT' : 'NOT NOW',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              )),
        ),
      ]),
    );
  }
}

/// One pack. Price always from the store, never from us.
class _PackTile extends StatelessWidget {
  final Package pkg;
  final int minutes;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _PackTile({
    required this.pkg,
    required this.minutes,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = selected ? kNeon : AppColors.surface3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? kNeon.withValues(alpha: 0.10)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? kNeon : tint.withValues(alpha: 0.7),
              width: selected ? 1.8 : 1),
          boxShadow: selected
              ? [BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 22)]
              : null,
        ),
        child: Column(children: [
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kNeon.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                  style: GoogleFonts.inter(
                    color: kNeon,
                    fontSize: 7.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            const SizedBox(height: 9),
          ] else
            const SizedBox(height: 22),
          Text('$minutes',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 34,
                height: 1,
                letterSpacing: -1.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          Text('MINUTES',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 8,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 11),
          // Localised by the store. Never ours to invent.
          Text(pkg.storeProduct.priceString,
              style: GoogleFonts.inter(
                color: selected ? kNeon : AppColors.textSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ),
    );
  }
}

/// Convenience for the voice screen: how many whole minutes are left,
/// counting the bank. Lives here so the sheet and its trigger can never
/// disagree about the number.
Future<int> voiceMinutesLeft() async =>
    (await LocalStoreService.voiceMsRemaining()) ~/ 60000;

/// The soft nudge threshold. Below this he gets offered a top-up BEFORE
/// he's stuck, which converts far better than the wall does — he's still
/// enjoying himself rather than being interrupted, and nobody resents an
/// offer they didn't need to accept.
const int kExtraNudgeMinutes = 3;

/// Has he already been nudged this week? Prevents the soft offer
/// becoming a nag, which would poison the hard one.
Future<bool> extraNudgeDue() async {
  final left = await voiceMinutesLeft();
  if (left <= 0 || left > kExtraNudgeMinutes) return false;
  if (await ExtraService.bankedMs() > 0) return false;
  return !await ExtraService.nudgedToday();
}
