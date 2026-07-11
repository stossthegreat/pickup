import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../models/character.dart';
import '../../models/metrics.dart';
import '../../widgets/pickup_widgets.dart';

/// Post-scene scorecard. One focus metric graded, XP awarded, star rating to
/// chase. Bro's verdict closes it out.
class SceneResultSheet extends StatelessWidget {
  final Character character;
  final Metric focus;
  final double focusScore;
  final int xp;
  const SceneResultSheet({
    super.key,
    required this.character,
    required this.focus,
    required this.focusScore,
    required this.xp,
  });

  int get stars => focusScore >= 75 ? 3 : (focusScore >= 55 ? 2 : 1);

  String get verdict {
    if (stars == 3) return 'She\'s in. That\'s exactly how you run a frame.';
    if (stars == 2) return 'You had her, then wobbled. Tighten the close.';
    return 'You got in your own way. Watch the cut-ins and run it back.';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentValue);
    return Container(
      padding: EdgeInsets.only(
        left: Sp.lg,
        right: Sp.lg,
        top: Sp.lg,
        bottom: MediaQuery.of(context).padding.bottom + Sp.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
        border: Border(top: BorderSide(color: AppColors.accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: Sp.lg),
          const SectionLabel('Scene complete'),
          Row(children: [
            for (var i = 0; i < 3; i++)
              Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i < stars ? AppColors.signalAmber : AppColors.surface3,
                      size: 36)
                  .animate()
                  .scale(delay: (120 * i).ms, duration: 300.ms, curve: Curves.elasticOut),
          ]),
          const SizedBox(height: Sp.lg),
          StatBar(
            label: focus.label,
            glyph: focus.glyph,
            value: focusScore,
            color: accent,
          ),
          const SizedBox(height: Sp.md),
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(Rd.md),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('👊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(verdict,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textPrimary)),
              ),
            ]),
          ),
          const SizedBox(height: Sp.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('+$xp', style: AppTypography.display.copyWith(fontSize: 34)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('XP',
                    style: AppTypography.label.copyWith(color: AppColors.red)),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentDeep,
                padding: const EdgeInsets.symmetric(vertical: Sp.md),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Rd.md)),
              ),
              child: Text('DONE',
                  style: AppTypography.labelBold.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
