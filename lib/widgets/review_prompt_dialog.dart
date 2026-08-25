import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';

import '../config/app_store_config.dart';
import '../services/analytics_service.dart';
import '../services/review_prompt_service.dart';

/// v249 — smooth two-stage iOS-style review prompt.
///
/// Bro: "look smooth as hell, drives comments, does it after aha
/// moments." The previous dark Playfair editorial card with a comment
/// text field felt like a long-form survey; bro's reference screens
/// (LooksMax AI) use the compact pre-prompt pattern every high-rated
/// iOS app uses:
///
///   Stage 1 — "Enjoying ImHim? Tap a star to rate it on the App
///             Store." + a row of empty stars + "Not Now."
///   Stage 2 — once any star is tapped: filled orange-gold stars +
///             "Thanks for your feedback. You can also write a
///             review." + "Write a Review" (primary) + "OK"
///             (secondary).
///
/// "Write a Review" opens the live store listing — on iOS it deep-links
/// to the App Store review section via openStoreListing(appStoreId), the
/// same path Settings → Rate us uses; on Android it tries the native
/// Play in-app review and falls back to the Play Store listing. (The old
/// requestReview()-only path was rate-limited by Apple and often did
/// nothing in TestFlight, so the button appeared to just close.)
///
/// Visual language deliberately leaves the dark editorial Mirrorly
/// chrome behind. iOS users recognise this floating white-card
/// pattern as "the rate prompt", which lifts tap-through.
class ReviewPromptDialog extends StatefulWidget {
  /// Which ask this is, 1-based. The copy sharpens as it climbs: the
  /// first is a polite question, the last says out loud that it is the
  /// last. A man who has ignored three asks does not need a fourth
  /// identical one — he needs a different sentence.
  final int ask;
  const ReviewPromptDialog({super.key, this.ask = 1});

  @override
  State<ReviewPromptDialog> createState() => _ReviewPromptDialogState();
}

/// THE ASK, ESCALATING.
///
/// Never names a number of stars and never offers anything for one.
/// App Store Review Guideline 1.1.7 and Play policy both forbid
/// soliciting a specific rating or paying for reviews, and a listing
/// pulled for it would cost more than every review it ever bought.
/// What IS allowed — and what actually works — is telling a man the
/// truth about why it matters.
const _asks = <(String, String)>[
  ('Enjoying ImHim?',
   'Tap a star. Ten seconds, and it genuinely helps.'),
  ('Do us one favour.',
   'Ratings are the only reason the next man ever finds this.'),
  ('Still worth it?',
   'You have put the reps in. Thirty seconds says whether it worked.'),
  ('One rating. That is the whole ask.',
   'No app grows without them. This one included.'),
  ('Last time we will ask.',
   'If it has helped you, say so. If it has not, say that instead.'),
];

class _ReviewPromptDialogState extends State<ReviewPromptDialog> {
  int _rating = 0;
  bool _opening = false;

  void _onStarTap(int stars) {
    HapticFeedback.selectionClick();
    setState(() => _rating = stars);
    // ignore: discarded_futures
    AnalyticsService.reviewRatingChosen(stars);
  }

  Future<void> _writeReview() async {
    if (_opening) return;
    setState(() => _opening = true);
    HapticFeedback.mediumImpact();
    // The only signal either platform gives us that he acted — neither
    // will say whether a review was actually written. The ladder backs
    // off on this, so it has to be recorded before the store takes over
    // the screen.
    // ignore: discarded_futures
    ReviewPromptService.markSentToStore();
    try {
      final reviewer = InAppReview.instance;
      // Mirror Settings → Rate us so "Write a Review" actually lands the
      // user on the store's review section. The old path called
      // requestReview() on both platforms — but Apple rate-limits that
      // sheet and shows NOTHING in TestFlight / after it has fired once,
      // which is why the button just closed the dialog.
      if (Platform.isIOS) {
        // iOS — deep-link to the ImHim listing's review tab once we know the
        // App Store ID; until then the native prompt targets the CURRENT app
        // (never the old Mirrorly listing). See lib/config/app_store_config.
        if (kAppStoreId.isNotEmpty) {
          await reviewer.openStoreListing(appStoreId: kAppStoreId);
        } else {
          await reviewer.requestReview();
        }
      } else {
        // Android — native Play in-app review when available, else the
        // Play Store listing (bundle id resolved automatically).
        if (await reviewer.isAvailable()) {
          await reviewer.requestReview();
        } else {
          await reviewer.openStoreListing();
        }
      }
    } catch (_) {/* best effort */}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _ok() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  void _notNow() {
    HapticFeedback.selectionClick();
    // ignore: discarded_futures
    AnalyticsService.reviewDismissed();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tapped = _rating > 0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/appstore.png',
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 44, height: 44),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tapped
                          ? 'Thanks. One more thing.'
                          : _asks[(widget.ask - 1)
                              .clamp(0, _asks.length - 1)].$1,
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 17, fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tapped
                          // The stars are the easy half. Written reviews
                          // are what a man actually reads before he
                          // downloads, so the second stage pushes for
                          // the words rather than thanking him and
                          // getting out of the way.
                          ? 'The stars help. The words are what make '
                            'another man try it.'
                          : _asks[(widget.ask - 1)
                              .clamp(0, _asks.length - 1)].$2,
                        style: GoogleFonts.inter(
                          color: Colors.black.withValues(alpha: 0.65),
                          fontSize: 13.5, fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stars row — outline when untapped, filled gold when tapped.
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _opening ? null : () => _onStarTap(i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                        size: 34,
                        color: filled
                          ? const Color(0xFFFFB100)
                          : const Color(0xFF3B82F6),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // Action row depends on stage.
            if (!tapped)
              _PillButton(
                label: 'Not Now',
                bold: false,
                onTap: _notNow,
              )
            else ...[
              _PillButton(
                label: 'Write a Review',
                bold: true,
                loading: _opening,
                onTap: _writeReview,
              ),
              const SizedBox(height: 8),
              _PillButton(
                label: 'OK',
                bold: false,
                onTap: _ok,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS-style pill button — light grey background, black text. Used
/// for both the Not Now / OK secondary actions and the Write a Review
/// primary action (primary uses w700, secondary uses w500).
class _PillButton extends StatelessWidget {
  final String label;
  final bool bold;
  final bool loading;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.bold,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Center(
              child: loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
                : Text(label,
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: bold
                        ? FontWeight.w700
                        : FontWeight.w500,
                    )),
            ),
          ),
        ),
      ),
    );
  }
}
