import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/villain/scenes.dart';
import '../../../theme/auralay_app_colors.dart';
import '../../../theme/auralay_app_typography.dart';
import '../../../widgets/safe_close_button.dart';
import 'arena_session_screen.dart';

/// THE ARENA — scene picker.
///
/// One card per scene. Each shows the title, the one-line hook, and
/// the objective. No catalogues, no chapters, no progress numbers.
/// The apprentice picks; the scene starts.
class ArenaScenesScreen extends StatelessWidget {
  const ArenaScenesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            // Atmospheric red halo.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 0.9,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 14, 8),
                    child: Row(
                      children: [
                        Text('THE ARENA',
                            style: AppTypography.label.copyWith(
                              color: AppColors.accent,
                              fontSize: 11,
                              letterSpacing: 3.6,
                              fontWeight: FontWeight.w900,
                            )),
                        const Spacer(),
                        const SafeCloseButton(),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pick the room.',
                            style: AppTypography.display.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 38,
                              letterSpacing: -1.4,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            )),
                        const SizedBox(height: 10),
                        Text('She is already in it.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.accent,
                              fontSize: 14,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            )),
                      ],
                    ),
                  ),
                ),

                // ── Scene grid ───────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final scene = VillainScenes.all[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SceneCard(
                            scene: scene,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    ArenaSessionScreen(scene: scene),
                              ));
                            },
                          ).animate()
                            .fadeIn(duration: 220.ms, delay: (40 * i).ms)
                            .slideY(begin: 0.06, end: 0, duration: 280.ms),
                        );
                      },
                      childCount: VillainScenes.all.length,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final VillainScene scene;
  final VoidCallback onTap;
  const _SceneCard({required this.scene, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentBorder, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(scene.title,
                      style: AppTypography.label.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      )),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.accent, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text('"${scene.oneLine}"',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.accent,
                  fontSize: 13.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                )),
            const SizedBox(height: 14),
            // What he's actually teaching you here — the seduction law.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentBorder, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded,
                          color: AppColors.accent, size: 13),
                      const SizedBox(width: 7),
                      Text('TEACHES  ·  ${scene.law}',
                          style: AppTypography.label.copyWith(
                            color: AppColors.accent,
                            fontSize: 10.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w900,
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(scene.lawLine,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OBJECTIVE',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(scene.objective,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.45,
                      )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
