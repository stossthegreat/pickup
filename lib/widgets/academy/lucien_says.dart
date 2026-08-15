import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  LUCIEN, ON SCREEN
/// ══════════════════════════════════════════════════════════════════════
///
/// Duo is not a mascot, he is the reason the notifications work. Over
/// weeks the characters stop being voices and become relationships, and
/// a message from someone you have a relationship with is a completely
/// different object to a message from a brand.
///
/// This app already has Lucien. He writes every retention notification
/// (see retention_service.dart), the man knows his name — and he has
/// never once appeared inside the product. A coach who only ever texts
/// you and is never in the room isn't a character, he's a sender ID.
///
/// So he shows up. At the end of a payout, after a duel, when a shield
/// caught a fall. One line, his face, then gone.
///
/// ── THE RULES HE OBEYS ───────────────────────────────────────────────
///
/// · ONE LINE. He notices; he does not instruct. The moment he starts
///   explaining, he's a tooltip.
///
/// · HE IS NEVER INSULTING. "You think you'll get game like that" is
///   funny once and corrosive by the fourth time. Men leave apps that
///   make them feel small, and this one is already built on a sore
///   spot — the whole product is for people who find this hard.
///
/// · HE NEVER SPEAKS OVER THE REWARD. He arrives AFTER the number has
///   landed, never on top of it. The payout is the point; he's the
///   full stop.
class LucienSays extends StatelessWidget {
  final String line;

  /// Delay before he slides in, so he can be told to wait for whatever
  /// else is animating.
  final Duration delay;

  const LucienSays({
    super.key,
    required this.line,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface2,
          border: Border.all(
              color: AppColors.signalAmber.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Image.asset(
          'assets/characters/lucien/lucien.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.25),
          // The portrait may not be bundled on every build. A glyph is a
          // fine Lucien; a red error box is not.
          // Proven-in-repo constant: there's no Flutter SDK in the build
          // environment to check a new icon name against.
          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
              size: 20, color: AppColors.signalAmber),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LUCIEN',
                style: GoogleFonts.inter(
                  color: AppColors.signalAmber,
                  fontSize: 8.5,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 3),
            Text(line,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    ])
        .animate()
        .fadeIn(delay: delay, duration: 340.ms)
        .slideX(begin: -0.12, end: 0, curve: Curves.easeOutCubic);
  }
}

/// What he says, and when.
///
/// Pools rather than single lines because the same sentence on the
/// fourth payout stops being a person and becomes a string constant.
/// Salt is whatever varies — the XP, the day count — so it's stable
/// within one screen and different across them.
abstract final class LucienLines {
  static const _afterPayout = <String>[
    'That counted. Do the next one before you talk yourself out of it.',
    'Good. Nobody\'s watching, which is exactly why it counts.',
    'You\'re doing the boring version of what everyone else only talks about.',
    'Bank it. Same time tomorrow.',
  ];

  static const _bigPayout = <String>[
    'Now that was worth getting off the sofa for.',
    'That\'s the kind of night that shows up in six weeks.',
    'You went and did the hard one. I noticed.',
  ];

  static const _firstTime = <String>[
    'First one\'s always the worst one. It\'s behind you now.',
    'That\'s the hardest rep you\'ll ever do. Everything after is easier.',
  ];

  static const _shieldSaved = <String>[
    'I covered you. Don\'t make a habit of it.',
    'Your run\'s still standing. You didn\'t do that — I did. Even it up.',
    'That would have been a long way back. It isn\'t now.',
  ];

  static const _afterLoss = <String>[
    'He had the better of it. That\'s all that happened.',
    'You lost a conversation, not an argument about who you are.',
    'Everyone good at this lost more than you have.',
  ];

  static String afterPayout(int amount, {bool first = false}) {
    if (first) return _firstTime[amount % _firstTime.length];
    final pool = amount >= 250 ? _bigPayout : _afterPayout;
    return pool[amount % pool.length];
  }

  static String shieldSaved(int run) =>
      _shieldSaved[run % _shieldSaved.length];

  static String afterLoss(int salt) => _afterLoss[salt.abs() % _afterLoss.length];
}
