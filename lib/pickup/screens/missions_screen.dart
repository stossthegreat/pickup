import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../data/characters.dart';
import '../data/missions.dart';
import '../models/mission.dart';
import '../state/game_state.dart';
import '../widgets/pickup_widgets.dart';
import 'chat/roleplay_chat_screen.dart';
import 'realworld/mission_debrief_sheet.dart';

/// SCREEN ONE. Missions is the front door — real-world action laddered
/// alongside endless roleplay reps, all feeding one Aura Level.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final rw = Missions.today.where((m) => m.isRealWorld).toList();
    final rp = Missions.today.where((m) => !m.isRealWorld).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(g)),
          const SliverToBoxAdapter(child: SizedBox(height: Sp.xl)),
          _sectionSliver(
            'The Real World',
            'Where the level-up actually happens. Weighs the most.',
            rw,
            g,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Sp.xl)),
          _sectionSliver(
            'Practice Reps',
            'Train the move on AI first. Endless, scored, laddered.',
            rp,
            g,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _sectionSliver(
      String title, String sub, List<Mission> items, GameState g) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      sliver: SliverList.list(children: [
        SectionLabel(title),
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.md),
          child: Text(sub, style: AppTypography.bodySmall),
        ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm + 2),
            child: _MissionCard(items[i])
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 320.ms)
                .slideY(begin: 0.08, curve: Curves.easeOut),
          ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final GameState g;
  const _Header(this.g);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TODAY', style: AppTypography.label),
              _StreakChip(g.streakDays),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Text('Go get her.', style: AppTypography.h1Italic),
          const SizedBox(height: Sp.lg),
          PickupCard(
            border: AppColors.surface3,
            child: Row(
              children: [
                AuraRing(
                  level: g.auraLevel,
                  progress: g.levelProgress,
                  rank: g.rankTitle,
                  size: 116,
                ),
                const SizedBox(width: Sp.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL SCORE', style: AppTypography.label),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(g.totalScore.toStringAsFixed(0),
                              style: AppTypography.display.copyWith(fontSize: 40)),
                          Text(' /100',
                              style: AppTypography.mono
                                  .copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                      const SizedBox(height: Sp.sm),
                      Text(
                        '${g.xpForNextLevel - g.xpIntoLevel} XP to Aura ${g.auraLevel + 1}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int days;
  const _StreakChip(this.days);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.redGlow,
          borderRadius: BorderRadius.circular(Rd.sm),
          border: Border.all(color: AppColors.red.withOpacity(0.35)),
        ),
        child: Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text('$days DAY STREAK',
              style: AppTypography.label
                  .copyWith(color: AppColors.red, letterSpacing: 1.4)),
        ]),
      );
}

class _MissionCard extends StatelessWidget {
  final Mission m;
  const _MissionCard(this.m);

  @override
  Widget build(BuildContext context) {
    final g = context.read<GameState>();
    final done = g.isDone(m.id);
    final locked = g.isLocked(m.unlockLevel);
    final accent = m.isRealWorld ? AppColors.red : AppColors.accent;

    return PickupCard(
      border: done
          ? AppColors.signalGreen.withOpacity(0.4)
          : (m.isRealWorld ? AppColors.red.withOpacity(0.28) : AppColors.surface3),
      onTap: locked ? null : () => _launch(context, m),
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(Rd.md),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  done ? '✓' : (m.isRealWorld ? '🌍' : '🎭'),
                  style: TextStyle(
                      fontSize: done ? 18 : 16,
                      color: done ? AppColors.signalGreen : null),
                ),
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill(m.tier.label, color: accent, filled: true),
                    const SizedBox(width: 6),
                    Pill('+${m.xp} XP', color: AppColors.textTertiary),
                  ]),
                  const SizedBox(height: 8),
                  Text(m.title,
                      style: AppTypography.h3.copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? AppColors.textTertiary
                              : AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    locked
                        ? 'Unlocks at Aura ${m.unlockLevel}'
                        : m.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                        color: locked
                            ? AppColors.signalAmber
                            : AppColors.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.sm),
            Icon(
                locked
                    ? Icons.lock_outline
                    : (done ? Icons.replay : Icons.chevron_right),
                size: 18,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _launch(BuildContext context, Mission m) {
    if (m.isRealWorld) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MissionDebriefSheet(mission: m),
      );
    } else {
      final ch = Roster.byId(m.characterId ?? 'ice_queen');
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RoleplayChatScreen(character: ch, mission: m),
      ));
    }
  }
}
