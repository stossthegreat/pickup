import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import 'game_button.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE CALLOUT — a nudge that actually lands on the man it names
/// ══════════════════════════════════════════════════════════════════════
///
/// THE HOLE THIS FILLS. Nudging existed and did nothing. The sender got
/// a toast ("the squad saw it"), a badge family counted it — and the
/// TARGET never heard about it at all: the event was posted to
/// squad_events and no consumer anywhere read the 'nudge' kind. The one
/// purely social pressure mechanic in the app was a message to nobody.
///
/// A squad is only worth anything if the men in it can lean on each
/// other, and leaning has to be FELT. So a nudge aimed at you is not a
/// feed row — it's a full-screen moment you walk into on your next
/// open, in the same visual register as the battle verdict: your name
/// was put up in front of the squad, and this screen is where you find
/// out.
///
/// ── DELIBERATELY NOT A GUILT SCREEN ─────────────────────────────────
///
/// The copy points forward ("N moves left today"), never backward
/// ("you've done nothing"). Shame with no exit is churn; the entire
/// screen is a door to the missions that clear it, and the button is
/// the biggest thing on it.
abstract final class Callout {
  /// Who called him out — parked by whichever pipe saw the event first
  /// (live channel or the catch-up sweep), drained by the missions tab.
  /// Last caller wins; two callouts in one gap is still one moment,
  /// because two of these screens back to back is a punishment.
  static String? pending;

  static String? take() {
    final p = pending;
    pending = null;
    return p;
  }
}

class CalloutScreen extends StatelessWidget {
  final String who;

  /// Moves he still has today, so the screen can name the size of the
  /// climb instead of vaguely gesturing at it.
  final int movesLeft;

  const CalloutScreen({super.key, required this.who, required this.movesLeft});

  static Future<void> show(
    BuildContext context, {
    required String who,
    required int movesLeft,
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'callout',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) =>
          CalloutScreen(who: who, movesLeft: movesLeft),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 1.08, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  AppColors.red.withValues(alpha: 0.22),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
            child: Column(children: [
              const Spacer(),
              Text('THE SQUAD IS WATCHING',
                      style: GoogleFonts.inter(
                        color: AppColors.signalAmber,
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 26),
              Text('CALLED OUT',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 44,
                        height: 1,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: AppColors.red.withValues(alpha: 0.6),
                              blurRadius: 44),
                        ],
                      ))
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 200.ms)
                  .scaleXY(begin: 1.9, end: 1, curve: Curves.easeOutBack),
              const SizedBox(height: 18),
              Text('${who.toUpperCase()} put your name up\nin front of the squad.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.45,
                        fontWeight: FontWeight.w800,
                      ))
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 300.ms),
              const SizedBox(height: 10),
              Text(
                      movesLeft > 0
                          ? '$movesLeft move${movesLeft == 1 ? '' : 's'} left today. '
                              'Don\'t be the reason they lose the day.'
                          : 'You\'ve already answered it — walk in and let them see.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ))
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 300.ms),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: movesLeft > 0 ? 'ANSWER IT' : 'SHOW THEM',
                  icon: Icons.bolt_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ).animate().fadeIn(delay: 900.ms, duration: 300.ms),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('LATER',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
