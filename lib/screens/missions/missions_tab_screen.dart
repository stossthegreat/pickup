import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/analytics_service.dart';
import '../../services/local_store_service.dart';
import '../../services/mission_catalog.dart';
import '../../services/mission_engine.dart';
import '../../services/paywall_gate.dart';
import '../../services/roster.dart';
import '../../services/streak_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/imhim_wordmark.dart';
import '../../widgets/common/streak_badge.dart';
import '../game/freeflow/free_flow_screen.dart';
import '../roleplay/girl_chat_screen.dart';
import 'task_chat_screen.dart';

/// MISSIONS — the daily engine, live. 3 AI + 2 real, generated from the
/// user's level so they escalate and hit the deep end fast. AI missions
/// complete when you practise; real missions complete on a one-tap "I did
/// it", with an optional Lucien game-plan first. Everything banks real
/// XP and feeds The Five — real missions worth far more.
class MissionsTabScreen extends StatefulWidget {
  final ValueChanged<int> onGoToTab; // 1 = Practice, 2 = Texts
  const MissionsTabScreen({super.key, required this.onGoToTab});

  @override
  State<MissionsTabScreen> createState() => _MissionsTabScreenState();
}

class _MissionsTabScreenState extends State<MissionsTabScreen> {
  List<MissionSpec> _missions = const [];
  Map<String, bool> _done = const {};
  int _xp = 0;
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final missions = await MissionEngine.loadToday();
    final done = <String, bool>{};
    for (final m in missions) {
      done[m.id] = await LocalStoreService.isMissionDoneToday(m.id);
    }
    final xp = await LocalStoreService.xpTotal();
    final streak = await StreakService.current();
    if (!mounted) return;
    setState(() {
      _missions = missions;
      _done = done;
      _xp = xp;
      _streak = streak;
      _loading = false;
    });
  }

  int get _doneCount => _missions.where((m) => _done[m.id] == true).length;

  Map<String, int> _dimBump(MissionSpec m) => switch (m.kind) {
        MissionKind.realApproach => const {'confidence': 4, 'presence': 3, 'game': 2},
        MissionKind.realText => const {'confidence': 2, 'game': 3, 'listening': 2},
        MissionKind.aiVoice => const {'presence': 2, 'game': 2, 'humor': 1},
        MissionKind.aiText => const {'game': 2, 'humor': 2, 'listening': 1},
        MissionKind.aiPost => const {'game': 2, 'humor': 1},
      };

  Future<void> _complete(MissionSpec m) async {
    if (_done[m.id] == true) return;
    await LocalStoreService.markMissionDone(m.id);
    await LocalStoreService.addXp(m.xp);
    await LocalStoreService.bumpDimensions(_dimBump(m));
    if (m.isReal) await LocalStoreService.markRealMissionDoneToday();
    // ignore: discarded_futures
    AnalyticsService.missionCompleted(kind: m.kind.name, title: m.title, xp: m.xp);
    HapticFeedback.mediumImpact();
    await _load();
    if (mounted) _toast('+${m.xp} XP  ·  ${m.title}');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ));
  }

  void _tap(MissionSpec m) {
    // ignore: discarded_futures
    AnalyticsService.missionOpened(kind: m.kind.name, title: m.title);
    switch (m.kind) {
      case MissionKind.aiVoice:
        _openVoice(m);
      case MissionKind.aiPost:
      case MissionKind.aiText:
        _openGirlChat(m);
      case MissionKind.realApproach:
      case MissionKind.realText:
        _showRealSheet(m);
    }
  }

  Future<void> _openGirlChat(MissionSpec m) async {
    // AI roleplay is Pro — paywall on the action.
    if (!await PaywallGate.isPro()) {
      if (!mounted) return;
      await PaywallGate.open(context, source: 'mission_chat');
      // Demo build: X unlocked → open the chat. Real build: not pro → stop.
      if (!mounted || !await PaywallGate.isPro()) return;
    }
    if (!mounted) return;
    final g = girlById(m.girlId!);
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => GirlChatScreen(
        config: GirlChatConfig(
          characterId: g.id,
          vibeKey: g.vibeKey,
          name: g.name,
          archetype: g.archetype,
          portraitAsset: g.asset,
          accent: g.accent,
          opener: g.opener,
          taskMode: true, // mission task → COMPLETE bar + score card at the end
          post: m.kind == MissionKind.aiPost
              ? GirlPost(
                  context: m.postContext ?? 'She just posted.',
                  caption: m.postCaption ?? 'out tonight ✨')
              : null,
        ),
      ),
    ));
    await _complete(m);
  }

  Future<void> _openVoice(MissionSpec m) async {
    final g = girlById(m.girlId!);
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => FreeFlowScreen(initialVibeKey: g.vibeKey),
    ));
    await _complete(m);
  }

  Future<void> _openCoach(MissionSpec m) async {
    // Lucien's AI game-plan is Pro — paywall on the action.
    if (!await PaywallGate.isPro()) {
      if (!mounted) return;
      await PaywallGate.open(context, source: 'mission_coach');
      // Demo build: X unlocked → open the coach. Real build: not pro → stop.
      if (!mounted || !await PaywallGate.isPro()) return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => TaskChatScreen(
        config: MissionChatConfig(
          taskTitle: m.title,
          tier: 'REAL · TEXTS',
          xp: '${m.xp}',
          girlAsset: 'assets/characters/women/arena.png',
          accent: AppColors.red,
          situation: m.sub,
          opening:
              'Real-world mission: ${m.title}.\n\nTell me the situation and '
              'I\'ll hand you the exact line to send — short, confident, '
              'reply-baiting. No "hey", no try-hard.',
          starters: const ['She went quiet', 'We just matched', 'From my past', 'Never really talked'],
          backendContext: m.coachContext ??
              'You are my dating text coach. Help me craft the exact line for: ${m.title}.',
        ),
      ),
    ));
  }

  Future<void> _showRealSheet(MissionSpec m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RealSheet(mission: m, done: _done[m.id] == true),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'coach':
        _openCoach(m);
      case 'did':
        await _complete(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TopBar(xp: _xp, streak: _streak)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
              child: _Heading(done: _doneCount, total: _missions.length),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
              sliver: SliverList.builder(
                itemCount: _missions.length,
                itemBuilder: (context, i) {
                  final m = _missions[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Sp.sm + 4),
                    child: _MissionCard(
                      mission: m,
                      done: _done[m.id] == true,
                      onTap: () => _tap(m),
                    )
                        .animate()
                        .fadeIn(delay: (70 * i).ms, duration: 340.ms)
                        .slideY(begin: 0.07, curve: Curves.easeOut),
                  );
                },
              ),
            ),
          if (!_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, 120),
                child: Center(
                  child: Text('Real reps build real game.',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top bar: wordmark · streak · settings · real XP ──────────────────────
class _TopBar extends StatelessWidget {
  final int xp;
  final int streak;
  const _TopBar({required this.xp, required this.streak});

  String get _xpLabel {
    final s = xp.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b XP';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.md, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ImHimWordmark(fontSize: 34, letterSpacing: -0.6),
              const SizedBox(width: 7),
              // Small "Rizz" set toward the wordmark's baseline — italic
              // Playfair to match the mark, muted so ImHim stays the hero.
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  'Rizz',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    height: 1.0,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Spacer(),
              if (streak > 0) ...[
                StreakBadge(days: streak),
                const SizedBox(width: 8),
              ],
              _IconBtn(icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              XpBadge(label: _xpLabel),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
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
  final int done;
  final int total;
  const _Heading({required this.done, required this.total});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('TODAY', style: AppTypography.label),
            const Spacer(),
            if (total > 0)
              Text('$done / $total DONE',
                  style: AppTypography.label.copyWith(
                      color: done == total && total > 0
                          ? AppColors.signalGreen
                          : AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Today\'s Mission', style: AppTypography.h1Italic),
        const SizedBox(height: 6),
        Text('Practice on AI. Then prove it in real life.',
            style: AppTypography.bodySmall),
      ],
    );
  }
}

// ── The mission card ─────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final MissionSpec mission;
  final bool done;
  final VoidCallback onTap;
  const _MissionCard({required this.mission, required this.done, required this.onTap});

  bool get _isAi =>
      mission.kind == MissionKind.aiPost ||
      mission.kind == MissionKind.aiText ||
      mission.kind == MissionKind.aiVoice;
  Color get _accent => _isAi ? AppColors.accent : AppColors.red;
  String get _tierLabel => switch (mission.kind) {
        MissionKind.aiVoice => 'AI · VOICE',
        MissionKind.aiPost => 'AI · POST',
        MissionKind.aiText => 'AI · TEXT',
        MissionKind.realApproach => 'REAL · APPROACH',
        MissionKind.realText => 'REAL · TEXTS',
      };
  String get _action => done
      ? 'DONE'
      : switch (mission.kind) {
          MissionKind.aiVoice => 'START',
          MissionKind.aiPost => 'RIZZ HER',
          MissionKind.aiText => 'TEXT HER',
          MissionKind.realApproach => 'DO IT',
          MissionKind.realText => 'GET THE LINE',
        };
  IconData get _icon => switch (mission.kind) {
        MissionKind.aiVoice => Icons.graphic_eq_rounded,
        MissionKind.aiPost => Icons.favorite_rounded,
        MissionKind.aiText => Icons.chat_bubble_rounded,
        MissionKind.realApproach => Icons.directions_walk_rounded,
        MissionKind.realText => Icons.send_rounded,
      };
  String? get _asset {
    if (!_isAi || mission.girlId == null) return null;
    return girlById(mission.girlId!).asset;
  }

  @override
  Widget build(BuildContext context) {
    final accent = done ? AppColors.signalGreen : _accent;
    return Opacity(
      opacity: done ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Rd.xl),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary, height: 1.35)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(done ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                            size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(_action,
                            style: AppTypography.label
                                .copyWith(color: accent, letterSpacing: 2)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(Color accent) {
    final asset = _asset;
    if (asset != null) {
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
          child: Image.asset(asset, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.surface3, child: Icon(_icon, color: accent))),
        ),
      );
    }
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
        child: Text(_tierLabel,
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

// ── Real-world mission sheet — Lucien game-plan · I did it ───────────────
class _RealSheet extends StatelessWidget {
  final MissionSpec mission;
  final bool done;
  const _RealSheet({required this.mission, required this.done});

  @override
  Widget build(BuildContext context) {
    final isText = mission.kind == MissionKind.realText;
    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 22 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.surface3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surface3, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Text('REAL WORLD · +${mission.xp} XP',
              style: AppTypography.label.copyWith(color: AppColors.red, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(mission.title, style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(mission.sub,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 18),
          _sheetBtn(
              context,
              isText ? 'GET THE LINE FROM LUCIEN' : 'GET A GAME PLAN FROM LUCIEN',
              Icons.auto_awesome_rounded,
              AppColors.accent,
              () => Navigator.pop(context, 'coach')),
          const SizedBox(height: 10),
          if (done)
            Center(
              child: Text('✓ Done today',
                  style: AppTypography.label.copyWith(color: AppColors.signalGreen)),
            )
          else
            _sheetBtn(context, 'I DID IT  →  +${mission.xp} XP',
                Icons.check_circle_rounded, AppColors.red, () => Navigator.pop(context, 'did'),
                filled: true),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Not yet',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
            ),
          ),
          if (!done) ...[
            const SizedBox(height: 4),
            Center(
              child: Text('Your streak is safe either way — but only real reps move your score.',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary, letterSpacing: 0.2, height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sheetBtn(BuildContext context, String label, IconData icon, Color color,
      VoidCallback onTap, {bool filled = false}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : color),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTypography.label.copyWith(
                      color: filled ? Colors.white : color, letterSpacing: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
