import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../models/mission.dart';
import '../../state/game_state.dart';
import '../../widgets/pickup_widgets.dart';

/// The real-world loop is honor + reflection, never surveillance. You report
/// what happened; the reflection becomes memory Bro and Her reference later.
class MissionDebriefSheet extends StatefulWidget {
  final Mission mission;
  const MissionDebriefSheet({super.key, required this.mission});

  @override
  State<MissionDebriefSheet> createState() => _MissionDebriefSheetState();
}

class _MissionDebriefSheetState extends State<MissionDebriefSheet> {
  int _outcome = -1; // 0 did it, 1 partial, 2 chickened out
  final _reflection = TextEditingController();

  static const _outcomes = [
    ('I did it', '💪', AppColors.signalGreen),
    ('Partial', '◐', AppColors.signalAmber),
    ('Chickened out', '🫥', AppColors.textTertiary),
  ];

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Container(
      padding: EdgeInsets.only(
        left: Sp.lg,
        right: Sp.lg,
        top: Sp.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sp.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
        border: Border(top: BorderSide(color: AppColors.red, width: 2)),
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
          const SectionLabel('Real-world mission'),
          Text(m.title, style: AppTypography.h2),
          const SizedBox(height: 6),
          Text(m.subtitle, style: AppTypography.bodySmall),
          const SizedBox(height: Sp.xl),
          Text('HOW DID IT GO?', style: AppTypography.label),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              for (var i = 0; i < _outcomes.length; i++) ...[
                if (i > 0) const SizedBox(width: Sp.sm),
                Expanded(child: _outcomeTile(i)),
              ],
            ],
          ),
          const SizedBox(height: Sp.lg),
          Text('WHAT HAPPENED?', style: AppTypography.label),
          const SizedBox(height: Sp.sm),
          TextField(
            controller: _reflection,
            maxLines: 3,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: _outcome == 2
                  ? 'What stopped you? Name the fear — that\'s the rep.'
                  : 'What did she say? How did you feel after?',
              hintStyle: AppTypography.body
                  .copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              contentPadding: const EdgeInsets.all(Sp.md),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: const BorderSide(color: AppColors.surface3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rd.md),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          _logButton(context),
        ],
      ),
    );
  }

  Widget _outcomeTile(int i) {
    final (label, glyph, color) = _outcomes[i];
    final sel = _outcome == i;
    return GestureDetector(
      onTap: () => setState(() => _outcome = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: Sp.md),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.14) : AppColors.surface2,
          borderRadius: BorderRadius.circular(Rd.md),
          border: Border.all(
              color: sel ? color : AppColors.surface3, width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          Text(glyph, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.label
                  .copyWith(color: sel ? color : AppColors.textTertiary)),
        ]),
      ),
    );
  }

  Widget _logButton(BuildContext context) {
    final enabled = _outcome >= 0;
    // Chickening out still earns partial XP — never punish the attempt.
    final xp = switch (_outcome) {
      0 => widget.mission.xp,
      1 => (widget.mission.xp * 0.6).round(),
      2 => (widget.mission.xp * 0.25).round(),
      _ => 0,
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled
            ? () {
                context.read<GameState>().awardResult(
                      gainedXp: xp,
                      completeMissionId: _outcome == 2 ? null : widget.mission.id,
                      realWorld: true,
                    );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppColors.surface3,
                  content: Text(
                    _outcome == 2
                        ? 'Logged. Showing up counts. +$xp XP — next time you don\'t freeze.'
                        : 'Logged. Bro saw that. +$xp XP',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ));
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? AppColors.red : AppColors.surface3,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: Sp.md),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rd.md)),
        ),
        child: Text(enabled ? 'LOG IT  ·  +$xp XP' : 'PICK AN OUTCOME',
            style: AppTypography.labelBold.copyWith(color: Colors.white)),
      ),
    );
  }
}
