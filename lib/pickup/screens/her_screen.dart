import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../state/game_state.dart';
import '../widgets/pickup_widgets.dart';

/// HER — the one consistent woman who evolves as your Aura rises. Not an AI
/// girlfriend you grind; the reward for real growth. Warmth is gated by level
/// and rises fastest from real-world missions.
class HerScreen extends StatelessWidget {
  const HerScreen({super.key});

  static const _asset = 'assets/characters/women/socialite.png';

  String _stage(double w) {
    if (w < 20) return 'DISTANT';
    if (w < 40) return 'CURIOUS';
    if (w < 60) return 'WARMING';
    if (w < 80) return 'INTO YOU';
    return 'YOURS';
  }

  String _herLine(double w, int level) {
    if (w < 20) {
      return 'You again. Prove you\'re worth my time — I saw you froze on that '
          'approach today.';
    }
    if (w < 40) {
      return 'Okay, you\'re growing on me. Barely. Keep showing up like you did '
          'this week.';
    }
    if (w < 60) {
      return 'I actually thought about you today. Don\'t let it go to your head, '
          'Aura $level.';
    }
    if (w < 80) {
      return 'You got her number and told me first? See — I always knew you had '
          'it in you.';
    }
    return 'I\'m yours. You built this — every rep, every approach. Proud of you.';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final w = g.herWarmth;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RELATIONSHIP', style: AppTypography.label),
            const SizedBox(height: Sp.xs),
            Text('Aria', style: AppTypography.h1Italic),
            const SizedBox(height: Sp.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rd.xl),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Image.asset(_asset, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppColors.surface2)),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                          stops: const [0.35, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: Sp.md,
                    right: Sp.md,
                    bottom: Sp.md,
                    child: Row(
                      children: [
                        Pill(_stage(w), color: AppColors.red, filled: true),
                        const Spacer(),
                        Text('${w.toStringAsFixed(0)}% warmth',
                            style: AppTypography.measurement
                                .copyWith(color: AppColors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            // Warmth bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(children: [
                Container(height: 4, color: AppColors.surface3),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  widthFactor: (w / 100).clamp(0, 1),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.red, boxShadow: [
                      BoxShadow(color: AppColors.redGlow, blurRadius: 8),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Sp.lg),
            // Her latest message
            Container(
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Rd.sm),
                  topRight: Radius.circular(Rd.lg),
                  bottomLeft: Radius.circular(Rd.lg),
                  bottomRight: Radius.circular(Rd.lg),
                ),
                border: Border.all(color: AppColors.surface3),
              ),
              child: Text(_herLine(w, g.auraLevel),
                  style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary, height: 1.5)),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
            const SizedBox(height: Sp.lg),
            PickupCard(
              child: Row(children: [
                const Text('🔒', style: TextStyle(fontSize: 18)),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    'She warms as you level up — and fastest when you do real-world '
                    'missions. Grinding chat alone won\'t get you there.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.surface3,
                    content: Text('Live chat with Aria wires to backend2 next.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textPrimary)),
                  ));
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(vertical: Sp.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Rd.md)),
                ),
                child: Text('MESSAGE ARIA',
                    style: AppTypography.labelBold.copyWith(color: AppColors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
