import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/comeback_service.dart';
import '../../services/rolodex_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';

/// SHE MESSAGED FIRST — what he sees when he comes back.
///
/// The whole design brief for this screen is: give him nothing to
/// decide. No streak obituary, no "you missed 4 days", no summary of
/// what he lost. One woman, one unread message, one button that says
/// REPLY.
///
/// The temptation is to use this moment to tell him what it cost him —
/// it's the most attention we'll get all week and there's a lot we could
/// say. That instinct is exactly backwards. A man who opens an app after
/// a lapse is already braced for a telling-off, and confirming it is how
/// you make the fifth day back the last one. He can find the chain and
/// the board himself in ten seconds if he wants them.
class ComebackSheet extends StatelessWidget {
  final ComebackOffer offer;

  /// Fires with her card when he taps REPLY.
  final void Function(NumberCard) onReply;

  const ComebackSheet({
    super.key,
    required this.offer,
    required this.onReply,
  });

  static Future<void> show(
    BuildContext context,
    ComebackOffer offer, {
    required void Function(NumberCard) onReply,
  }) {
    Feel.banked();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComebackSheet(offer: offer, onReply: onReply),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = offer.card.girl;
    final tint = g.accent;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.16), AppColors.base],
          stops: const [0, 0.55],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),

        // Her, with the unread dot. The dot is doing more work than
        // anything else on the screen — it's the one piece of visual
        // language everybody on earth already reads as "answer this".
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint, width: 2),
              boxShadow: [
                BoxShadow(color: tint.withValues(alpha: 0.45), blurRadius: 28)
              ],
            ),
            child: ClipOval(
              child: Image.asset(g.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  errorBuilder: (_, __, ___) => ColoredBox(
                        color: AppColors.surface2,
                        child: Center(
                          child: Text(g.name.characters.first.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: tint,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                      )),
            ),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.base, width: 2.5),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.22, duration: 780.ms),
          ),
        ])
            .animate()
            .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack),

        const SizedBox(height: 16),
        Text(g.name.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 4),
        Text('MESSAGED YOU',
            style: GoogleFonts.inter(
              color: tint,
              fontSize: 8.5,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 22),

        // Her line, as a bubble. Same shape as the ones in the chat he's
        // about to open, so this reads as the conversation already being
        // underway rather than as a screen about a conversation.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 268),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(19),
                bottomLeft: Radius.circular(19),
                bottomRight: Radius.circular(19),
              ),
              border: Border.all(color: tint.withValues(alpha: 0.3)),
            ),
            child: Text(offer.opener,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                )),
          ),
        )
            .animate()
            .fadeIn(delay: 320.ms, duration: 360.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),

        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: GameButton(
            label: 'REPLY',
            color: tint,
            textColor:
                tint.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            pulse: true,
            onTap: () {
              Navigator.of(context).maybePop();
              onReply(offer.card);
            },
          ),
        ),
        const SizedBox(height: 4),
        // Deliberately soft. A man who doesn't want to be here right now
        // should be able to leave without a fight — the sheet has already
        // done its job by existing.
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text('LATER',
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
