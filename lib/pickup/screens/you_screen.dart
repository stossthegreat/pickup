import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../models/metrics.dart';
import '../state/game_state.dart';
import '../widgets/pickup_widgets.dart';

/// YOU — the RPG character sheet. Aura Level, the five metrics, the total,
/// streak. The screen you screenshot and flex.
class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('YOUR RECORD', style: AppTypography.label),
                Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text('${g.streakDays} DAYS',
                      style: AppTypography.label.copyWith(color: AppColors.red)),
                ]),
              ],
            ),
            const SizedBox(height: Sp.lg),
            // Hero: ring + total
            Center(
              child: Column(children: [
                AuraRing(
                  level: g.auraLevel,
                  progress: g.levelProgress,
                  rank: g.rankTitle,
                  size: 150,
                ),
                const SizedBox(height: Sp.md),
                Text('${g.xpForNextLevel - g.xpIntoLevel} XP to Aura ${g.auraLevel + 1}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ]),
            ),
            const SizedBox(height: Sp.xl),
            SectionLabel('The Five',
                trailing: Row(children: [
                  Text('TOTAL ', style: AppTypography.label),
                  Text(g.totalScore.toStringAsFixed(0),
                      style: AppTypography.measurement
                          .copyWith(color: AppColors.red, fontSize: 14)),
                ])),
            PickupCard(
              child: Column(
                children: [
                  for (final m in Metric.values)
                    StatBar(
                      label: m.label,
                      glyph: m.glyph,
                      value: g.metrics.get(m),
                      color: m.color,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.xl),
            SectionLabel('This Week'),
            Row(children: [
              Expanded(child: _stat('SCENES', '12', AppColors.accent)),
              const SizedBox(width: Sp.sm),
              Expanded(child: _stat('REAL MOVES', '3', AppColors.red)),
              const SizedBox(width: Sp.sm),
              Expanded(child: _stat('3-STARS', '5', AppColors.signalAmber)),
            ]),
            const SizedBox(height: Sp.xl),
            SectionLabel('Share'),
            PickupCard(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppColors.surface3,
                  content: Text('Share card export — wire to share_service next.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textPrimary)),
                ));
              },
              child: Row(children: [
                const Text('📸', style: TextStyle(fontSize: 20)),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Post your Aura card',
                          style: AppTypography.h3),
                      Text('"Aura ${g.auraLevel} · ${g.rankTitle}" — flex the climb',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ]),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => PickupCard(
        padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.sm),
        child: Column(children: [
          Text(value, style: AppTypography.display.copyWith(fontSize: 30, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(fontSize: 9)),
        ]),
      );
}
