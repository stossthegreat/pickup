import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/backend/squad_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_feel.dart';
import 'squad_chrome.dart';

/// THE ASK — one prompt, at the only moment it works.
///
/// The onboarding squad page sells the idea and lets him skip, on
/// purpose: at that point he has no score, no streak and nothing to be
/// accountable for, so "invite your mates to watch you do nothing" is a
/// weak ask and a pushed squad is an ignored squad.
///
/// This is the strong version. It fires the instant his first real score
/// lands, when he is holding a number he didn't have ninety seconds ago
/// and "send this to someone who'll try to beat it" is a sentence rather
/// than a favour. Sharing a score is a brag; the squad is the thing he
/// accidentally builds by bragging.
///
/// It fires ONCE, ever. A second showing turns the best moment in the
/// app into a nag, and the whole point is that the ask is welcome.
class BragSheet {
  static const _kShown = 'brag.ask.shown.v1';

  /// Show it if he's just scored, isn't already in a squad, and hasn't
  /// seen it. Returns quietly in every other case — the caller doesn't
  /// need to know the rules.
  static Future<void> maybeShow(
    BuildContext context, {
    required String score,
    required String scaleLabel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kShown) == true) return;
      // Already has a squad → he's done the thing this asks for.
      if (await SquadService.mySquad() != null) return;
      if (!context.mounted) return;
      await prefs.setBool(_kShown, true);

      Feel.best();
      Sfx.personalBest();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _Sheet(score: score, scaleLabel: scaleLabel),
      );
    } catch (_) {
      // Never block the reveal's exit on a prompt.
    }
  }
}

class _Sheet extends StatelessWidget {
  final String score, scaleLabel;
  const _Sheet({required this.score, required this.scaleLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 26),
        const SquadCrest(name: 'YOU', accent: AppColors.red, size: 68),
        const SizedBox(height: 20),

        // His number, big. The ask only works while he's still looking
        // at it, so it comes with him into the sheet.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(score,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 46,
                  height: 1,
                  letterSpacing: -2.4,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(width: 6),
            Text(scaleLabel,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
        const SizedBox(height: 18),
        Text('NOW IT NEEDS SOMEONE\nTO BEAT IT.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 25,
              height: 1.08,
              letterSpacing: -1.1,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 10),
        Text(
            'Send it to one mate. He gets the same woman, the same day, '
            'blind — and tomorrow one of you has to explain himself.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 24),
        _Btn(
          label: 'SEND MY SCORE',
          filled: true,
          onTap: () {
            Feel.banked();
            Share.share(
                'Scored $score $scaleLabel on ImHim Rizz today. Same woman, '
                'same day, everyone blind. Beat it.');
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 10),
        _Btn(
          label: 'START A SQUAD',
          filled: false,
          onTap: () {
            Feel.tick();
            Navigator.of(context).pop();
            context.push('/squad');
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Not yet',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Btn(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.red : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.14)),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.4),
                      blurRadius: 24)
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: filled ? Colors.white : AppColors.textSecondary,
              fontSize: 13.5,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }
}
