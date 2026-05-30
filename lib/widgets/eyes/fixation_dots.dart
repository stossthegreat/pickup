import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../common/mirrorly_components.dart';

/// Gaze training target — the partner's face filling the upper area
/// with two soft red gleams sitting on her eyes. Drawn OUTSIDE the
/// camera transform stack so it sits at absolute screen coords
/// regardless of the camera preview's mirror / rotation / scale.
///
/// Two gleams in the upper third are the user's gaze targets during a
/// drill. When the gaze engine reports lock the gleams brighten and a
/// soft red glow blooms around her face — visual confirmation that
/// the eye contact landed.
///
/// Previously this was two abstract red dots on a black screen; the
/// partner face gives the user something REAL to lock onto, which is
/// the whole point of exposure-style eye-contact training.
class FixationDots extends StatelessWidget {
  /// True when the gaze engine has locked on — gleams + rim brighten.
  final bool isLocked;
  const FixationDots({super.key, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    // CRITICAL: IgnorePointer wraps the WHOLE widget so the
    // Positioned.fill we sit inside doesn't absorb taps. Without
    // this, every button on the session screens (X, pause, mic, the
    // share-card pills) became unresponsive — the fill consumed
    // their gestures.
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Partner face fills the upper ~55% of the screen. The image
          // is composed face-tight (per the artwork brief in
          // assets/eyes/partners/README.md) so cover-cropping with a
          // slight upward bias keeps her eyes near the top third.
          final faceHeight = h * 0.55;
          // The two gleam targets sit just under the visible eye line
          // of the rendered image. y = 28% of the screen matches the
          // composition spec (eyes at 1/3 from top of the cropped
          // face) so they land directly on her pupils.
          final eyeY = h * 0.28;

          return Stack(
            children: [
              // ── Her face — the real training target.
              Positioned(
                top: 0, left: 0, right: 0, height: faceHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      MirrorlyAssets.gazeNeutral,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.35),
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    ),
                    // Bottom fade so her face dissolves into the
                    // camera background instead of cutting hard.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              AppColors.base.withValues(alpha: 0.85),
                              AppColors.base,
                            ],
                            stops: const [0.0, 0.55, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Soft red wash that blooms when the gaze locks —
                    // a subtle "you've got her" cue without changing
                    // the photo itself.
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      opacity: isLocked ? 0.20 : 0.0,
                      child: Container(color: AppColors.red),
                    ),
                  ],
                ),
              ),

              // ── Eye gleams — two soft pulsing markers sitting on her
              // pupils. Brighten when locked, dim when drifting.
              Positioned(
                left: w * 0.36 - 9, top: eyeY - 9,
                child: _Gleam(isLocked: isLocked),
              ),
              Positioned(
                left: w * 0.64 - 9, top: eyeY - 9,
                child: _Gleam(isLocked: isLocked),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Gleam extends StatelessWidget {
  final bool isLocked;
  const _Gleam({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.red.withValues(
              alpha: isLocked ? 0.95 : 0.62),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(
                  alpha: isLocked ? 0.70 : 0.30),
              blurRadius: isLocked ? 22 : 12,
              spreadRadius: isLocked ? 2 : -1,
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 1200.ms)
        .then().fadeOut(duration: 1200.ms),
    );
  }
}
