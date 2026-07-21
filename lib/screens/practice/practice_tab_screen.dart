import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/local_store_service.dart';
import '../../services/paywall_gate.dart';
import '../../services/roster.dart';
import '../../services/streak_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import '../game/freeflow/free_flow_screen.dart';
import '../roleplay/girl_chat_screen.dart';

/// PRACTICE — the relationship hub. A grid of the 10 AI women, each a real
/// name + her character chip + how far you've gotten with her (her stage).
/// Tap her and choose how to practise: text her, or take it live on voice.
/// Both remember you (the memory layer), so you pick up where you left off.
class PracticeTabScreen extends StatefulWidget {
  const PracticeTabScreen({super.key});

  @override
  State<PracticeTabScreen> createState() => _PracticeTabScreenState();
}

class _PracticeTabScreenState extends State<PracticeTabScreen> {
  Map<String, int> _stages = const {};
  int _day = 1; // earned ascension day — gates who's unlocked

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final s = <String, int>{};
    for (final g in kRoster) {
      s[g.id] = await LocalStoreService.girlStage(g.id);
    }
    int day = 1;
    try {
      day = (await StreakService.progress()).ascensionDay;
    } catch (_) {/* default day 1 → only the starters unlocked */}
    if (mounted) {
      setState(() {
        _stages = s;
        _day = day;
      });
    }
  }

  bool _locked(GirlBrief g) => _day < g.unlockDay;

  Future<void> _tap(GirlBrief g) async {
    if (_locked(g)) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${g.name} unlocks on Day ${g.unlockDay}. '
            'Keep climbing — you\'re on Day $_day.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ));
      return;
    }
    // Free to browse the roster — but talking to her is Pro. Paywall on tap.
    if (!await PaywallGate.isPro()) {
      if (!mounted) return;
      await PaywallGate.open(context, source: 'practice');
      // Demo build: X unlocked the app, so fall through into the chat. Real
      // build: still not pro, so stop here.
      if (!mounted || !await PaywallGate.isPro()) return;
    }
    if (!mounted) return;
    _choose(g);
  }

  GirlChatConfig _configFor(GirlBrief g) => GirlChatConfig(
        characterId: g.id,
        vibeKey: g.vibeKey,
        name: g.name,
        archetype: g.archetype,
        portraitAsset: g.asset,
        accent: g.accent,
        opener: g.opener,
      );

  Future<void> _openText(GirlBrief g) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => GirlChatScreen(config: _configFor(g))),
    );
    _load(); // her stage may have moved
  }

  void _openVoice(GirlBrief g) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => FreeFlowScreen(initialVibeKey: g.vibeKey)),
    );
  }

  void _choose(GirlBrief g) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet(
        girl: g,
        stage: _stages[g.id] ?? 1,
        onText: () {
          Navigator.pop(context);
          _openText(g);
        },
        onVoice: () {
          Navigator.pop(context);
          _openVoice(g);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unlocked women first, then the locked ones grouped by the day they
    // open (Day 10 group, then Day 20, then 30, then 40) — a clear climb.
    final unlocked = [for (final g in kRoster) if (!_locked(g)) g];
    final locked = [for (final g in kRoster) if (_locked(g)) g]
      ..sort((a, b) => a.unlockDay.compareTo(b.unlockDay));
    final roster = [...unlocked, ...locked];
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: MirrorlyMasthead(
              eyebrow: 'PRACTICE · TEXT + VOICE',
              title: 'Who\'s it tonight?',
              subtitle: 'Text her or take it live — she remembers you either '
                  'way. Unlock more women as you climb the 60 days.',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Sp.sm + 4,
                crossAxisSpacing: Sp.sm + 4,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final g = roster[i];
                  return _GirlCard(
                    girl: g,
                    stage: _stages[g.id] ?? 1,
                    locked: _locked(g),
                    onTap: () { _tap(g); },
                  )
                      .animate()
                      .fadeIn(delay: (55 * i).ms, duration: 320.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOut);
                },
                childCount: roster.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GirlCard extends StatelessWidget {
  final GirlBrief girl;
  final int stage;
  final bool locked;
  final VoidCallback onTap;
  const _GirlCard({
    required this.girl,
    required this.stage,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = girl.accent;
    final stageLabel = (stage >= 1 && stage < kRelationshipStages.length)
        ? kRelationshipStages[stage]
        : 'Matched';
    // Warmer stages read greener; day-one 'Matched' stays muted.
    final stageColor = stage >= 3 ? AppColors.signalGreen : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Locked portraits are darkened + desaturated so she reads as a
            // silhouette you have to earn — the chase.
            ColorFiltered(
              colorFilter: locked
                  ? const ColorFilter.matrix(<double>[
                      0.25, 0.25, 0.25, 0, 0,
                      0.25, 0.25, 0.25, 0, 0,
                      0.25, 0.25, 0.25, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.asset(girl.asset, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface2,
                        child: Icon(Icons.person_outline_rounded, color: accent, size: 40),
                      )),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: locked
                      ? [Colors.black54, Colors.black45, Colors.black]
                      : [Colors.black38, Colors.transparent, Colors.black],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            // Top-left badge — relationship stage when unlocked, the unlock
            // day when locked.
            Positioned(
              top: Sp.sm + 2,
              left: Sp.sm + 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: (locked ? AppColors.red : stageColor).withOpacity(0.5),
                      width: 0.8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(locked ? Icons.lock_rounded : Icons.favorite_rounded,
                      size: 9, color: locked ? AppColors.red : stageColor),
                  const SizedBox(width: 4),
                  Text(locked ? 'DAY ${girl.unlockDay}' : stageLabel.toUpperCase(),
                      style: AppTypography.label.copyWith(
                          color: locked ? AppColors.red : stageColor,
                          fontSize: 8,
                          letterSpacing: 1.2)),
                ]),
              ),
            ),
            // Centered lock glyph for locked girls.
            if (locked)
              Center(
                child: Icon(Icons.lock_rounded,
                    size: 34, color: Colors.white.withOpacity(0.85)),
              ),
            // Name + character chip + hook — bottom.
            Positioned(
              left: Sp.md,
              right: Sp.md,
              bottom: Sp.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Little character chip.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(locked ? 0.10 : 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accent.withOpacity(locked ? 0.30 : 0.55), width: 0.8),
                    ),
                    child: Text(girl.type,
                        style: AppTypography.label.copyWith(
                            color: accent.withOpacity(locked ? 0.7 : 1),
                            fontSize: 8,
                            letterSpacing: 1.4)),
                  ),
                  const SizedBox(height: 8),
                  Text(girl.name,
                      style: AppTypography.h3.copyWith(
                          color: locked ? Colors.white70 : Colors.white,
                          fontSize: 21,
                          height: 1.0,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(locked ? 'Unlocks on Day ${girl.unlockDay}' : girl.archetype,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                          color: locked ? AppColors.red : Colors.white70,
                          height: 1.3,
                          fontSize: 11.5,
                          fontWeight: locked ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The practice-choice sheet — text or voice, both route to the screens
/// we built (GirlChatScreen / FreeFlowScreen).
class _ChoiceSheet extends StatelessWidget {
  final GirlBrief girl;
  final int stage;
  final VoidCallback onText;
  final VoidCallback onVoice;
  const _ChoiceSheet({
    required this.girl,
    required this.stage,
    required this.onText,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    final stageLabel = (stage >= 1 && stage < kRelationshipStages.length)
        ? kRelationshipStages[stage]
        : 'Matched';
    return Container(
      padding: EdgeInsets.fromLTRB(22, 16, 22, 22 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.surface3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.surface3, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: girl.accent.withOpacity(0.7), width: 1.4),
                ),
                child: ClipOval(
                  child: Image.asset(girl.asset, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surface2,
                          child: Icon(Icons.person, color: girl.accent))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(girl.name, style: AppTypography.h2),
                    const SizedBox(height: 2),
                    Text('${girl.type}  ·  $stageLabel'.toUpperCase(),
                        style: AppTypography.label
                            .copyWith(color: girl.accent, letterSpacing: 1.4, fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _choice(context, 'TEXT HER', 'Rizz her over text — she replies in character.',
              Icons.chat_bubble_rounded, AppColors.red, onText),
          const SizedBox(height: 10),
          _choice(context, 'CALL HER · VOICE', 'Take it live on the voice orb.',
              Icons.call_rounded, AppColors.accent, onVoice),
        ],
      ),
    );
  }

  Widget _choice(BuildContext context, String label, String sub, IconData icon,
      Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.label
                            .copyWith(color: color, letterSpacing: 1.4, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
