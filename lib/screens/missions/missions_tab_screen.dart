import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';

/// MISSIONS tab — real-world action + AI drills, one daily slate. Reuses the
/// app's elite components so it reads as one system with Roleplay + Progress.
///
/// [onOpenRoleplay] switches the shell to the Roleplay tab when an AI drill is
/// tapped (wired from HomeScreen). Real-world missions open an honor check-in.
class MissionsTabScreen extends StatefulWidget {
  final VoidCallback? onOpenRoleplay;
  const MissionsTabScreen({super.key, this.onOpenRoleplay});

  @override
  State<MissionsTabScreen> createState() => _MissionsTabScreenState();
}

class _RealMission {
  final String title, sub, tier, xp;
  const _RealMission(this.title, this.sub, this.tier, this.xp);
}

class _Drill {
  final String name, line, asset;
  final bool locked;
  const _Drill(this.name, this.line, this.asset, {this.locked = false});
}

class _MissionsTabScreenState extends State<MissionsTabScreen> {
  final Set<int> _done = {};

  static const _real = <_RealMission>[
    _RealMission('Hold eye contact with 3 strangers',
        'One beat longer than comfortable. Then look away calm.', 'WARM-UP', '120'),
    _RealMission('Give one genuine compliment out loud',
        'Specific, not looks. To a stranger. No agenda.', 'STANDARD', '200'),
    _RealMission('Start one conversation with someone new',
        'Twenty seconds. That is the whole mission.', 'BOLD', '350'),
  ];

  static const _drills = <_Drill>[
    _Drill('The Ice Queen', 'Open her without a boring "hey".',
        'assets/characters/women/ice_queen.png'),
    _Drill('The Chaos Girl', 'Make her laugh in four messages.',
        'assets/characters/women/chaos_girl.png'),
    _Drill('The Intellectual', 'Hold your frame — don\'t posture.',
        'assets/characters/women/intellectual.png', locked: true),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 120),
        children: [
          const MirrorlyMasthead(eyebrow: 'TODAY', title: 'Missions'),
          const SizedBox(height: Sp.lg),
          const StatStrip(stats: [
            StatPoint(icon: Icons.local_fire_department_rounded, value: '4', label: 'STREAK'),
            StatPoint(icon: Icons.check_circle_outline_rounded, value: '2/6', label: 'DONE'),
            StatPoint(icon: Icons.bolt_rounded, value: '640', label: 'XP TODAY'),
          ]),
          const SizedBox(height: Sp.xl),
          const DisplayBlock(
            lineOne: 'The real',
            lineTwo: 'world.',
            body: 'Where the level-up actually happens. Weighs the most — you '
                'can\'t max out from the couch.',
          ),
          const SizedBox(height: Sp.lg),
          for (var i = 0; i < _real.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm + 2),
              child: _realCard(i)
                  .animate()
                  .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOut),
            ),
          const SizedBox(height: Sp.xl),
          const DisplayBlock(
            lineOne: 'AI',
            lineTwo: 'drills.',
            body: 'Train the move on AI first. Scored, endless, laddered.',
          ),
          const SizedBox(height: Sp.lg),
          for (final d in _drills)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm + 2),
              child: RoleplayTile(
                name: d.name,
                line: d.line,
                assetPath: d.asset,
                locked: d.locked,
                onTap: () {
                  if (!d.locked) widget.onOpenRoleplay?.call();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _realCard(int i) {
    final m = _real[i];
    final done = _done.contains(i);
    return _MissionCard(
      title: m.title,
      sub: m.sub,
      tier: m.tier,
      xp: m.xp,
      done: done,
      onTap: () => _checkIn(i),
    );
  }

  void _checkIn(int i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebriefSheet(
        mission: _real[i],
        onLogged: () => setState(() => _done.add(i)),
      ),
    );
  }
}

// ── Elite real-world mission card ─────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final String title, sub, tier, xp;
  final bool done;
  final VoidCallback onTap;
  const _MissionCard({
    required this.title,
    required this.sub,
    required this.tier,
    required this.xp,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.lg),
        child: Ink(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(Rd.lg),
            border: Border.all(
                color: done
                    ? AppColors.signalGreen.withOpacity(0.4)
                    : AppColors.red.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.redGlow,
                  borderRadius: BorderRadius.circular(Rd.md),
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: Center(
                    child: Text(done ? '✓' : '🌍',
                        style: TextStyle(
                            fontSize: done ? 18 : 16,
                            color: done ? AppColors.signalGreen : null))),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _pill(tier, AppColors.red),
                      const SizedBox(width: 6),
                      _pill('+$xp XP', AppColors.textTertiary),
                    ]),
                    const SizedBox(height: 8),
                    Text(title,
                        style: AppTypography.h3.copyWith(
                            decoration: done ? TextDecoration.lineThrough : null,
                            color: done ? AppColors.textTertiary : AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Icon(done ? Icons.replay_rounded : Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withOpacity(0.14),
          borderRadius: BorderRadius.circular(Rd.sm),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Text(t.toUpperCase(),
            style: AppTypography.label.copyWith(color: c, fontSize: 9, letterSpacing: 1.4)),
      );
}

// ── Honor check-in sheet ──────────────────────────────────────────────────
class _DebriefSheet extends StatefulWidget {
  final _RealMission mission;
  final VoidCallback onLogged;
  const _DebriefSheet({required this.mission, required this.onLogged});
  @override
  State<_DebriefSheet> createState() => _DebriefSheetState();
}

class _DebriefSheetState extends State<_DebriefSheet> {
  int _outcome = -1;
  final _c = TextEditingController();
  static const _opts = [('I did it', '💪'), ('Partial', '◐'), ('Chickened out', '🫥')];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: Sp.lg),
          Text(widget.mission.title, style: AppTypography.h2),
          const SizedBox(height: Sp.lg),
          Text('HOW DID IT GO?', style: AppTypography.label),
          const SizedBox(height: Sp.sm),
          Row(children: [
            for (var i = 0; i < _opts.length; i++) ...[
              if (i > 0) const SizedBox(width: Sp.sm),
              Expanded(child: _tile(i)),
            ],
          ]),
          const SizedBox(height: Sp.lg),
          SizedBox(
            width: double.infinity,
            child: PrimaryCta(
              label: _outcome < 0 ? 'PICK AN OUTCOME' : 'LOG IT',
              icon: Icons.check_rounded,
              locked: _outcome < 0,
              onTap: () {
                if (_outcome < 0) return;
                widget.onLogged();
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int i) {
    final sel = _outcome == i;
    return GestureDetector(
      onTap: () => setState(() => _outcome = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: Sp.md),
        decoration: BoxDecoration(
          color: sel ? AppColors.redGlow : AppColors.surface2,
          borderRadius: BorderRadius.circular(Rd.md),
          border: Border.all(color: sel ? AppColors.red : AppColors.surface3),
        ),
        child: Column(children: [
          Text(_opts[i].$2, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(_opts[i].$1.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.label
                  .copyWith(color: sel ? AppColors.red : AppColors.textTertiary)),
        ]),
      ),
    );
  }
}
