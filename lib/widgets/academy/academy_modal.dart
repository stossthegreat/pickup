import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// THE pop-up. One primitive for every celebration and interruption in
/// the Academy layer — rank-ups, challenges, squad votes, streaks —
/// so the app never accumulates five competing dialog styles.
///
/// Black glass over a blurred scrim, hairline red edge-glow, one entry
/// curve, one haptic. Content is a slot; identity is fixed.
class AcademyModal {
  static Future<T?> show<T>(
    BuildContext context, {
    required String kicker, // micro-label, e.g. 'RANK UP' / 'CHALLENGE'
    required Widget child,
    Color accent = AppColors.red,
    bool dismissible = true,
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: kicker,
      barrierColor: AppColors.scrim,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => _Shell(
        kicker: kicker,
        accent: accent,
        child: child,
      ),
      transitionBuilder: (ctx, anim, _, page) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 6 * curved.value, sigmaY: 6 * curved.value),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curved),
              child: page,
            ),
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  final String kicker;
  final Color accent;
  final Widget child;
  const _Shell(
      {required this.kicker, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: accent.withValues(alpha: 0.4), width: 1),
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 42,
                    spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker,
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10.5,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    )).animate().fadeIn(duration: 200.ms),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The standard full-width CTA used inside modals (and reveal screens),
/// pre-styled to the Academy voice.
class AcademyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  const AcademyButton(
      {super.key, required this.label, required this.onTap, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ghost
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800)),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                disabledBackgroundColor:
                    AppColors.red.withValues(alpha: 0.25),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900)),
            ),
    );
  }
}
