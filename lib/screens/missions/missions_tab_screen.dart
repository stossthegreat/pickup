import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/villain/scenes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../game/arena/arena_session_screen.dart';

/// MISSIONS — the front door. Beautiful, clean cards. Three kinds:
///   • AI  — "Talk to her" → opens her voice roleplay right away.
///   • Texts — real-world messaging (comment on her story, DM your crush)
///            → routes to the Texts tab to practice the line first.
///   • Approach — real-world in-person → routes to the Practice tab.
class MissionsTabScreen extends StatelessWidget {
  final ValueChanged<int> onGoToTab; // 1 = Practice, 2 = Texts
  const MissionsTabScreen({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TopBar()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
              child: _Heading(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, 120),
            sliver: SliverList.builder(
              itemCount: _seed.length,
              itemBuilder: (context, i) {
                final m = _seed[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm + 4),
                  child: _MissionCard(
                    mission: m,
                    onTap: () => _launch(context, m),
                  )
                      .animate()
                      .fadeIn(delay: (70 * i).ms, duration: 340.ms)
                      .slideY(begin: 0.07, curve: Curves.easeOut),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _launch(BuildContext context, _Mission m) {
    switch (m.kind) {
      case _Kind.ai:
        final scene = VillainScenes.all
            .firstWhere((s) => s.id == m.sceneId, orElse: () => VillainScenes.all.first);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArenaSessionScreen(scene: scene),
        ));
      case _Kind.texts:
        onGoToTab(2);
      case _Kind.approach:
        onGoToTab(1);
    }
  }
}

// ── Data ────────────────────────────────────────────────────────────────
enum _Kind { ai, texts, approach }

class _Mission {
  final _Kind kind;
  final String title, sub, tier, xp;
  final String? asset; // AI missions show her render
  final String? sceneId;
  const _Mission(this.kind, this.title, this.sub, this.tier, this.xp,
      {this.asset, this.sceneId});
}

const _seed = <_Mission>[
  _Mission(_Kind.ai, 'Talk to the Ice Queen',
      'She gives nothing for free. Warm her up on voice.', 'AI · VOICE', '80',
      asset: 'assets/characters/women/ice_queen.png', sceneId: 'ice_girl'),
  _Mission(_Kind.texts, 'Comment on her story',
      'Someone you like posted. One line that makes her reply.', 'REAL · TEXTS', '150'),
  _Mission(_Kind.approach, 'Approach one girl today',
      'When you\'re out. Twenty seconds. Practice on voice first.', 'REAL · APPROACH', '350'),
  _Mission(_Kind.texts, 'Message your crush',
      'Open the chat you keep re-reading. Send something real.', 'REAL · TEXTS', '200'),
  _Mission(_Kind.ai, 'Make the Chaos Girl laugh',
      'Match her tempo. Four lines to a real laugh.', 'AI · VOICE', '120',
      asset: 'assets/characters/women/chaos_girl.png', sceneId: 'chaos_girl'),
  _Mission(_Kind.texts, 'Reopen a dead conversation',
      'One that went cold. Revive it without "hey".', 'REAL · TEXTS', '180'),
];

// ── Top bar: streak · XP · progress · settings ───────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.md, 0),
      child: Row(
        children: [
          _Chip(icon: Icons.local_fire_department_rounded, label: '4', color: AppColors.red),
          const SizedBox(width: Sp.sm),
          _Chip(icon: Icons.bolt_rounded, label: '2,140 XP', color: AppColors.accent),
          const Spacer(),
          _IconBtn(icon: Icons.insights_rounded, onTap: () => context.push('/progress')),
          _IconBtn(icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(Rd.sm),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTypography.label.copyWith(color: color, letterSpacing: 1)),
        ]),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textSecondary, size: 22),
        splashRadius: 22,
      );
}

class _Heading extends StatelessWidget {
  const _Heading();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY', style: AppTypography.label),
        const SizedBox(height: 6),
        Text('Go get her.', style: AppTypography.h1Italic),
        const SizedBox(height: 6),
        Text('Your missions for today. Practice on AI, then do it for real.',
            style: AppTypography.bodySmall),
      ],
    );
  }
}

// ── The elite mission card ───────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final _Mission mission;
  final VoidCallback onTap;
  const _MissionCard({required this.mission, required this.onTap});

  Color get _accent => mission.kind == _Kind.ai ? AppColors.accent : AppColors.red;
  String get _action => switch (mission.kind) {
        _Kind.ai => 'START',
        _Kind.texts => 'PRACTICE',
        _Kind.approach => 'TRAIN',
      };
  IconData get _icon => switch (mission.kind) {
        _Kind.ai => Icons.graphic_eq_rounded,
        _Kind.texts => Icons.chat_bubble_outline_rounded,
        _Kind.approach => Icons.directions_walk_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface2, AppColors.surface1],
            ),
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(color: accent.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(Sp.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _leading(accent),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pillRow(accent),
                    const SizedBox(height: 8),
                    Text(mission.title,
                        style: AppTypography.h3.copyWith(
                            color: AppColors.textPrimary, height: 1.15)),
                    const SizedBox(height: 4),
                    Text(mission.sub,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary, height: 1.35)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text(_action,
                          style: AppTypography.label
                              .copyWith(color: accent, letterSpacing: 2)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leading(Color accent) {
    if (mission.asset != null) {
      // AI mission — her render in a rounded tile with an accent ring.
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Rd.lg - 2),
          child: Image.asset(mission.asset!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.surface3, child: Icon(_icon, color: accent))),
        ),
      );
    }
    // Real-world mission — accent-tinted icon tile.
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.22), accent.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Icon(_icon, color: accent, size: 26),
    );
  }

  Widget _pillRow(Color accent) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(Rd.sm),
        ),
        child: Text(mission.tier,
            style: AppTypography.label
                .copyWith(color: accent, fontSize: 8.5, letterSpacing: 1.4)),
      ),
      const SizedBox(width: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text('+${mission.xp}',
            style: AppTypography.label
                .copyWith(color: AppColors.textTertiary, fontSize: 9)),
      ]),
    ]);
  }
}
