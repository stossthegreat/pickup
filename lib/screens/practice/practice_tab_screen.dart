import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/game_test.dart';
import '../../services/local_store_service.dart';
import '../../services/paywall_gate.dart';
import '../../services/roster.dart';
import '../../services/streak_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/mirrorly_components.dart';
import '../roleplay/girl_chat_screen.dart';
import 'dojo_screen.dart';

/// PRACTICE — the relationship hub. A grid of the 10 AI women, each a real
/// name + her character chip + how far you've gotten with her (her stage).
/// Tap her and you're texting — the 📞 in her chat header takes it live on
/// voice whenever he wants. She remembers you (the memory layer).
class PracticeTabScreen extends StatefulWidget {
  /// 0 Missions · 1 Practice · 2 Battles · 3 Progress. Progress isn't
  /// in the bottom bar any more — the flame in this header goes to it.
  final ValueChanged<int>? onGoToTab;

  const PracticeTabScreen({super.key, this.onGoToTab});

  @override
  State<PracticeTabScreen> createState() => _PracticeTabScreenState();
}

class _PracticeTabScreenState extends State<PracticeTabScreen> {
  Map<String, int> _stages = const {};
  /// His last GAME TEST score, out of 100. Null until he has taken one.
  int? _score;
  bool _testing = false;
  int _day = 1; // earned ascension day — gates who's unlocked
  bool _creator = false; // owner creator mode → every girl unlocked

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
    final creator = await LocalStoreService.isCreatorActive();
    final score = await LocalStoreService.gameScore();
    if (mounted) {
      setState(() {
        _stages = s;
        _day = day;
        _creator = creator;
        _score = score;
      });
    }
  }

  /// THE GAME TEST. Five messages, one number out of 100.
  ///
  /// THE FIRST ONE IS FREE, AND ONLY THE FIRST. A man who has never seen
  /// his number has no reason to care about the app and every reason to
  /// close it; a man who has seen it has a number he wants to beat. That
  /// is worth one graded rep of text. Every retest after it is Pro —
  /// beating the score is the product, finding out the score is the hook.
  Future<void> _runGameTest() async {
    if (_testing) return;
    HapticFeedback.mediumImpact();
    final firstEver = _score == null;
    final pro = firstEver ? true : await PaywallGate.isPro();
    if (!pro) {
      if (!mounted) return;
      final bought = await PaywallGate.open(context, source: 'game_test');
      if (!mounted || !bought) return;
    }
    if (!mounted) return;
    setState(() => _testing = true);
    try {
      await GameTest.run(context,
          surface: 'game_test',
          kicker: firstEver ? 'YOUR GAME SCORE' : 'YOUR NEW SCORE');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
    if (!mounted) return;
    await _load();
  }

  // A girl is locked until her ascension day arrives. Creator mode
  // (owner-only, password-gated) unlocks the whole roster immediately.
  //
  // The ladder day now falls to 0 on a missed day (it tracks the streak),
  // so the gate is floored at 1: the Day-1 starters are the way back in
  // and must never lock. Everything above them does drop when you drop —
  // that's the point of tying the ladder to showing up.
  bool _locked(GirlBrief g) =>
      !_creator && (_day < 1 ? 1 : _day) < g.unlockDay;

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
    // STRAIGHT INTO THE CHAT. The text/voice choice sheet is gone —
    // it was one tap of friction that asked a question the chat screen
    // already answers (the 📞 in her header takes it live any time).
    // Text carries the free-message funnel; voice still paywalls at
    // _goLive inside FreeFlow. Nothing to choose, so nothing to ask.
    _openText(g);
  }

  GirlChatConfig _configFor(GirlBrief g) => GirlChatConfig(
        // PRACTICE IS THE ONE PLACE THE COACH LIVES. It scores
        // nothing anyone else can see and feeds no ladder, so being
        // shown a good line here is teaching rather than cheating.
        // Every graded surface defaults to false — see the note on
        // GirlChatConfig.coachAllowed.
        coachAllowed: true,
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

  @override
  Widget build(BuildContext context) {
    // Order by EARNED ascension day only — never by the creator flag — so
    // toggling creator mode (which unlocks every girl) can NOT reshuffle the
    // grid. Girls whose day has arrived lead (in roster order); the rest
    // follow grouped by the day they open (10 → 20 → 30 → 40) as a clear
    // climb. Creator mode only strips the lock overlay + allows the tap; a
    // girl's position on the grid stays exactly where it was.
    final earned = [for (final g in kRoster) if (_day >= g.unlockDay) g];
    final notYet = [for (final g in kRoster) if (_day < g.unlockDay) g]
      ..sort((a, b) => a.unlockDay.compareTo(b.unlockDay));
    final roster = [...earned, ...notYet];
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              // Sp.sm at the top, matching the Missions and Progress
              // mastheads exactly — this tab sat Sp.md lower than the
              // other two, so switching tabs nudged the whole page.
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THE TITLE SITS ON THE ICON LINE.
                  //
                  // It had a row to itself and the whole left half of
                  // the cog row was dead space on every screenful. One
                  // word in that gap buys back a full row of height and
                  // pulls the grid up the page.
                  //
                  // It's PRACTICE, not the sentence. The sentence is
                  // the red line underneath — that's what a subtitle is
                  // for, and running it as the title made a masthead
                  // that wrapped to two lines and said the same thing
                  // twice.
                  //
                  // FittedBox scaleDown, not ellipsis: on the narrowest
                  // phone the word shrinks a point rather than turning
                  // into "PRACTI…", which is the one thing a masthead
                  // must never do.
                  //
                  // THE XP / STREAK / RANK PILLS ARE NOT HERE ANYMORE.
                  // They belong on Home, where standing IS the subject.
                  // Repeated on all three tabs they became furniture —
                  // three rows of the same numbers pushing the actual
                  // content of each tab a hundred points down the page,
                  // and a number you see everywhere is a number you stop
                  // reading. Everything below moves up to fill the gap.
                  //
                  // ORDER, READ FROM THE RIGHT: settings, progress, board.
                  //
                  // FULL 26pt MASTHEAD, not the inline 22. The DOJO pill
                  // was wedged into this row and the title had to shrink
                  // to make room — the masthead paying rent for a button.
                  // With the pill moved below, PRACTICE at full size and
                  // three 38pt cogs fit the line with space to spare.
                  Row(children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('TRAIN',
                            maxLines: 1,
                            style: AppTypography.masthead),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _BoardCog(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/leaderboard');
                        }),
                    const SizedBox(width: 6),
                    _BoardCog(
                        icon: Icons.trending_up_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onGoToTab?.call(3);
                        }),
                    const SizedBox(width: 6),
                    _SettingsCog(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/settings');
                        }),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Voice calls, texts and scenarios that prepare you '
                    'for real conversations.',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.red),
                  ),
                  const SizedBox(height: 12),
                  // ── THE DOJO, ON ITS OWN LINE ────────────────────────
                  //
                  // Right-aligned directly above the roster, in the same
                  // shape as BOTTLING IT on Home. A cog row is
                  // navigation furniture — board, progress, settings —
                  // and the DOJO is none of those; it's the one thing on
                  // this screen that teaches rather than measures, so it
                  // reads as an offer sitting on top of the women rather
                  // than a fourth setting.
                  // ── TEST YOUR GAME ───────────────────────────────────
                  //
                  // The score goes ABOVE the women, not behind them. It is
                  // the one thing on this screen that answers "am I any
                  // good", and it was buried at the end of onboarding —
                  // seen once, never again. Here it is the first thing he
                  // sees every time he opens the app, and once he has a
                  // number it stops being an offer and becomes a record
                  // he wants to beat.
                  _GameTestCard(
                    score: _score,
                    busy: _testing,
                    onTap: _runGameTest,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DojoPill(onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const DojoScreen()),
                      );
                    }),
                  ),
                ],
              ),
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

class _SettingsCog extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsCog({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.settings_outlined,
              size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _BoardCog extends StatelessWidget {
  final VoidCallback onTap;

  /// Defaults to the board's trophy — the same cog now also carries the
  /// progress flame, so it takes its glyph rather than hard-coding one.
  final IconData icon;

  const _BoardCog({required this.onTap, this.icon = Icons.emoji_events_outlined});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// The DOJO pill — red-edged, all caps, sits in the masthead icon row.
/// Deliberately the only text pill up there: the cogs are utilities, the
/// Dojo is a destination, and it should read like a door.
class _DojoPill extends StatelessWidget {
  final VoidCallback onTap;
  const _DojoPill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        // BOTTLING IT's exact proportions — see the fear button in
        // missions_tab_screen. It was 38pt tall because it had to match
        // the cogs it sat between; off that row it's free to be what it
        // actually is, and the app already has one shape for "a small
        // red offer you can take or leave". Two of those in different
        // sizes is two languages.
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: AppColors.red.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.whatshot_rounded,
                size: 12, color: AppColors.red),
            const SizedBox(width: 4),
            Text('THE DOJO',
                style: AppTypography.label
                    .copyWith(color: AppColors.red, fontSize: 8.5)),
          ]),
        ),
      ),
    );
  }
}

/// THE GAME TEST CARD. Before he has a score it is a question; after, it
/// is his number with a way to beat it. Same card, two states.
class _GameTestCard extends StatelessWidget {
  final int? score;
  final bool busy;
  final VoidCallback onTap;
  const _GameTestCard({
    required this.score,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final taken = score != null;
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withValues(alpha: 0.18), blurRadius: 26),
          ],
        ),
        child: Row(children: [
          // The number, or the question mark standing in for it.
          SizedBox(
            width: 74,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(taken ? '$score' : '?',
                        style: AppTypography.masthead.copyWith(
                          color: AppColors.red,
                          fontSize: 40,
                          height: 1.0,
                        )),
                    Text('/100',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        )),
                  ]),
            ]),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 44, color: Colors.white12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(taken ? 'YOUR GAME SCORE' : 'TEST YOUR GAME',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    )),
                const SizedBox(height: 3),
                Text(
                    taken
                        ? 'Run it again and beat it.'
                        : 'Five messages. One number. Free.',
                    maxLines: 2,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.red)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(taken ? 'RETEST' : 'START',
                  style: AppTypography.label
                      .copyWith(color: Colors.white, fontSize: 11)),
            ),
        ]),
      ),
    );
  }
}
