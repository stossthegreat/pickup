import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/analytics_service.dart';
import '../../services/backend/catch_up_service.dart';
import '../../services/backend/squad_broadcast.dart';
import '../../services/local_store_service.dart';
import '../../services/mission_catalog.dart';
import '../../services/mission_engine.dart';
import '../../services/paywall_gate.dart';
import '../../services/roster.dart';
import '../../services/streak_rescue_service.dart';
import '../../services/streak_service.dart';
import '../../services/achievements.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../services/shield_service.dart';
import '../../services/standing.dart';
import '../academy/payout_screen.dart';
import '../../widgets/academy/ascend_reveal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/academy/live_toast.dart';
import '../../widgets/academy/callout.dart';
import '../../widgets/academy/rescue_sheet.dart';
import '../../widgets/academy/shield_sheet.dart';
import '../../widgets/academy/game_button.dart' show Burst;
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
  /// 0 Missions · 1 Practice · 2 Battles · 3 Progress.
  ///
  /// Progress is index 3 and is NOT in the bottom bar — it's a
  /// destination reached by the flame icon on every tab. See the
  /// note where that icon is built.
  final ValueChanged<int> onGoToTab;
  const MissionsTabScreen({super.key, required this.onGoToTab});

  @override
  State<MissionsTabScreen> createState() => _MissionsTabScreenState();
}

class _MissionsTabScreenState extends State<MissionsTabScreen> {
  List<MissionSpec> _missions = const [];
  Map<String, bool> _done = const {};
  int _xp = 0;
  int _streak = 0;
  int? _voiceScore;
  int? _chatScore;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
    // WHILE YOU WERE GONE — a returning user never opens to a static
    // screen. Runs after the first frame so it lands on top of home.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // THE SHIELD GOES BEFORE EVERYTHING, including the rescue.
      //
      // It has already fired by now (see _load, which runs it before it
      // reads the streak) — this is only the telling. Order matters: a
      // run the shield saved has nothing left to rescue, so offering him
      // a rescue for it would be the app trying to sell him a fix for a
      // problem it already solved.
      final saved = await ShieldService.takeUnseenSave();
      if (!mounted) return;
      if (saved != null) {
        await ShieldSheet.show(context, saved);
        if (!mounted) return;
        await _load();
        return; // one heavy moment per open
      }

      // THE RESCUE GOES FIRST. A man opening the app to a dead 12-day run
      // is the single biggest churn moment there is, and it has to be the
      // first thing he sees — not queued behind a catch-up summary of the
      // squad's week. Silent no-op unless a run genuinely stopped
      // yesterday.
      final offer = await StreakRescue.check();
      if (!mounted) return;
      if (offer != null) {
        final saved = await RescueSheet.show(context, offer);
        if (!mounted) return;
        if (saved) await _load();
        return; // one heavy moment per open; the catch-up can wait
      }
      final events = await CatchUpService.collect();
      // THE CALLOUT LANDS BEFORE THE FEED. If a squadmate put his name
      // up while he was away, that's not a row in a summary — it's the
      // moment he walks into. collect() parks it (see callout.dart);
      // this is the first screen with a context, so it drains here.
      final calledBy = Callout.take();
      if (mounted && calledBy != null) {
        await CalloutScreen.show(context,
            who: calledBy, movesLeft: _missions.length - _doneCount);
        if (!mounted) return;
      }
      if (mounted && events.isNotEmpty) {
        await CatchUpSheet.show(context, events);
      }
      // Last, and only if nothing heavier ran: a rank earned on
      // yesterday's fifth mission still deserves its moment today.
      if (mounted) await _milestones();
    });
  }

  Future<void> _load() async {
    // BEFORE ANYTHING READS THE STREAK. If a live run died yesterday and
    // there's a shield banked, it spends itself here — no prompt, no
    // decision, no dialog between a distracted man and his fourteen
    // days. He is told about it afterwards. See shield_service.dart.
    await ShieldService.autoSave();
    final missions = await MissionEngine.loadToday();
    final done = <String, bool>{};
    for (final m in missions) {
      done[m.id] = await LocalStoreService.isMissionDoneToday(m.id);
    }
    final xp = await LocalStoreService.xpTotal();
    final streak = await StreakService.current();
    final voice = await LocalStoreService.voiceScore();
    final chat = await LocalStoreService.chatScore();
    // Protection accrues from the exact behaviour it protects: one
    // shield per five consecutive days, capped at two.
    await ShieldService.accrue(streak);
    if (!mounted) return;
    setState(() {
      _missions = missions;
      _done = done;
      _xp = xp;
      _streak = streak;
      _voiceScore = voice;
      _chatScore = chat;
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
    // ONE DOOR. Rewards is the only thing that grants XP now — it holds
    // the rates, the daily caps and the milestone check, so a new source
    // can't be added without them. See rewards.dart.
    await Rewards.mission(m.xp, m.title);
    await LocalStoreService.bumpDimensions(_dimBump(m));
    if (m.isReal) await LocalStoreService.markRealMissionDoneToday();
    // ignore: discarded_futures
    AnalyticsService.missionCompleted(kind: m.kind.name, title: m.title, xp: m.xp);
    HapticFeedback.mediumImpact();
    // A REAL-WORLD MISSION IS AN APPROACH. It is the single most
    // valuable thing anyone does in this product and it was counting
    // toward nothing.
    if (m.isReal) {
      MilestoneService.pushTrophies(await Achievements.bump(Stat.approaches));
    }
    // ignore: discarded_futures
    SquadBroadcast.completed(m.title, xp: m.xp, girlId: m.girlId);
    await _load();
    // THE MOMENT. Finishing a mission is the only time XP moves, so it
    // is the only time a level can land — and it used to land silently
    // in a pill he wasn't looking at. See milestone_service.dart.
    await _milestones();
  }

  /// HOME OWNS TWO LADDERS: his LEVEL and his RANK. Both are read from
  /// local state — total XP and earned days — so this costs nothing and
  /// can run on every completion.
  ///
  /// It owns those two and no others on purpose. The battle verdict
  /// celebrates a DIVISION promotion because that's where one happens,
  /// and squad home celebrates a SQUAD LEVEL because that's where the
  /// squad's numbers already are. One owner per ladder; anything else
  /// and two screens race to congratulate him for the same thing.
  Future<void> _milestones() async {
    final xp = await LocalStoreService.xpTotal();
    final snap = await StreakService.progress();
    final days = snap.ascensionDay;
    final rank = Standing.rankFor(days);
    // The streak badge family is a PEAK, not a tally — a broken run
    // never takes back ONE WEEK, because he did earn it.
    MilestoneService.pushTrophies(
        await Achievements.raiseTo(Stat.streakPeak, snap.streak));
    await MilestoneService.check(
      level: Standing.levelFor(xp),
      rankRung: Standing.rungFor(days),
      rankLabel: rank.label,
    );
    if (!mounted) return;
    // THE PAYOUT FIRST. Home is also the safety net: a grant made
    // somewhere that has no natural end screen — practice, for one —
    // is still parked in memory and gets counted out here rather than
    // vanishing.
    await PayoutScreen.showIfEarned(context);
    if (!mounted) return;
    await AscendReveal.drain(
      context,
      accentOf: ascendTint,
      footnoteOf: (m) => m.kind == MilestoneKind.rank
          ? '${rank.tagline}\n\n${rank.unlock}'
          : null,
    );
  }

  // ignore: unused_element
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
    // Tell the squad he STARTED it — 'Marcus is on Daisy's post right
    // now' is a far stronger pull than only hearing about finishes.
    // ignore: discarded_futures
    SquadBroadcast.started(m.title, girlId: m.girlId);
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
    // THE MISSION MUST ACTUALLY BE DONE. This used to call _complete()
    // on ANY pop — open the chat, hit back, mission ticked. Five taps and
    // a "5/5 DONE" day with nothing behind it, which makes the streak,
    // the squad board and the ascension ladder all lies.
    //
    // GirlChatScreen already knows when the task genuinely finished — it
    // sets _taskDone once enough real lines have been traded and shows
    // the score card. It now pops `true` on that path only, so a back
    // button returns null and completes nothing.
    final done = await Navigator.of(context, rootNavigator: true)
        .push<bool>(MaterialPageRoute(
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
    if (done == true) {
      await _complete(m);
    } else {
      _notDone('Not completed — you have to actually run the conversation.');
    }
  }

  /// Left without finishing. Say so, or the mission silently stays open
  /// and the app looks broken rather than strict.
  void _notDone(String msg) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2600),
    ));
  }

  Future<void> _openVoice(MissionSpec m) async {
    // Live voice roleplay is the MOST expensive action in the app (OpenAI
    // Realtime audio). Paywall BEFORE the screen opens so a non-Pro user
    // can never open — let alone connect — a voice session. Pro / creator
    // pass; everyone else is stopped here.
    if (!await PaywallGate.isPro()) {
      if (!mounted) return;
      await PaywallGate.open(context, source: 'mission_voice');
      if (!mounted || !await PaywallGate.isPro()) return;
    }
    if (!mounted) return;
    final g = girlById(m.girlId!);
    // Same rule for voice, proved a different way. FreeFlowScreen has
    // several exit paths (X, back, the scored sheet), so rather than
    // making every one of them return a value we check the durable
    // record: a scored session appends to the game-score history. One
    // more entry than we went in with means he actually ran it and got
    // graded; anything else — including opening it and backing straight
    // out — leaves the mission open.
    final before = (await LocalStoreService.loadGameScores()).length;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      // ASSIGNED — the mission engine picked her, he didn't. The
      // practice day-lock stays in Practice, where climbing to her is
      // the point; on an assigned task it can only ever lock a man out
      // of his own work (the ladder drops with the streak, missions
      // don't). Same rule as the Daily and duels.
      builder: (_) =>
          FreeFlowScreen(initialVibeKey: g.vibeKey, assigned: true),
    ));
    final after = (await LocalStoreService.loadGameScores()).length;
    if (after > before) {
      await _complete(m);
    } else {
      _notDone('Not completed — the voice session has to be scored.');
    }
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
          SliverToBoxAdapter(
              child: _TopBar(
                  xp: _xp,
                  streak: _streak,
                  onGoToTab: widget.onGoToTab)),

          // ── ONE CARD ───────────────────────────────────────────────
          // Home used to stack three invitations before you reached the
          // missions: the day gauge, the Daily, and the squad strip. Each
          // was asking for the same tap and they competed rather than
          // stacked. There is one card now — your squad — and it opens
          // TODAY, where the standing and both challenges live together.
          // ── THE TWO PERMANENT SYSTEMS ──────────────────────────
          // Home reads top to bottom as: who you are (masthead + XP),
          // the SOCIAL system (squad), the COMPETITIVE system
          // (battles), then today's work (the five). Squad and Battles
          // are standing modes and belong together above the fold;
          // missions are what you do today and belong below the rule.
          //
          // Deliberately not two identical rectangles — that's how a
          // home screen becomes a list. The squad is a crest on a flat
          // panel; battles is full-bleed photography gone almost black.
          // Same footprint, opposite texture.
          // ── THE TWO SCORES, ABOVE EVERYTHING ───────────────────
          //
          // The squad crest stood here and has gone to Battles, where
          // the other men are. What takes its place is the only thing
          // on this screen that is purely HIS: what he scores on voice
          // and what he scores on text, side by side in one frame.
          //
          // NO RETEST BUTTON. It is a scoreboard, not a launcher —
          // every voice session and every chat already writes to it, so
          // a button here would be a second door to something he does
          // ten times a day anyway. The number is the hero; the way to
          // change it is to go and talk to someone.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, 0),
              child: _ScoreCard(voice: _voiceScore, chat: _chatScore),
            ),
          ),
          // BATTLES CAME OFF HOME when it took the third tab. A card
          // here AND a permanent tab is the same door twice — and the
          // card was the workaround for it being buried, which it no
          // longer is.

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
              child: _Heading(
                done: _doneCount,
                total: _missions.length,
                onPanic: () {
                  HapticFeedback.heavyImpact();
                  context.push('/fear');
                },
              ),
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

  /// The tab switcher, for the progress flame. This is a StatelessWidget
  /// — there is no `widget` here — so the callback has to be handed down
  /// from the screen that owns it.
  final ValueChanged<int> onGoToTab;

  const _TopBar({
    required this.xp,
    required this.streak,
    required this.onGoToTab,
  });

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
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Spacer(),

              // THE BOARD. The squad shield used to sit here too, but the
              // squad already has its own card further down this very
              // screen — two doors to one room is clutter, and the card
              // carries live state the icon never could.
              // The fear button used to sit here and it squeezed the
              // masthead — the streak flame ended up jammed against the
              // wordmark. It's moved down to the mission heading, which
              // is where you actually are when you bottle it.
              // PROGRESS IS AN ICON NOW, NOT A TAB. The bottom bar is
              // three things you DO — missions, practice, battles.
              // Progress is a thing you LOOK AT, and a destination you
              // visit once a week doesn't deserve a permanent third of
              // the navigation. It's reachable from every tab instead.
              //
              // A RISING LINE, NOT A FLAME. The flame is the streak —
              // it's already on the pill two rows down and on the day
              // ceremony. Using it here as well made one glyph mean two
              // different things, and the door it opens is a graph.
              //
              // ORDER, READ FROM THE RIGHT: settings, progress, board.
              // The thumb lands on the right of this row, so the order
              // runs outward from there — the two you open often sit
              // closest, the board furthest.
              _IconBtn(
                  icon: Icons.emoji_events_outlined,
                  onTap: () => context.push('/leaderboard')),
              _IconBtn(
                  icon: Icons.trending_up_rounded,
                  onTap: () => onGoToTab(3)),
              _IconBtn(icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
            ],
          ),
          const SizedBox(height: Sp.md),
          // BATTLES USED TO BE A PILL HERE. A rounded chip beside the XP
          // badge — the visual weight of a filter, for the one mode
          // where two real men run the same woman blind. It's a
          // standing system, not a toggle, so it's a full card below the
          // squad now. Removing it also gives the masthead its air back.
          // TWO PILLS, ONE ROW: what he's earned, and where he stands.
          // The personal tier used to sit in the corner of the Battles
          // card, which read as a property of battles rather than of
          // him. It's his, so it lives next to his XP.
          // THREE PILLS, ONE ROW, ONE ORDER EVERYWHERE: what he's
          // earned, what he's protecting, where he stands. The flame
          // used to sit up in the wordmark row on this tab and in the
          // pill row on Practice — same two screens, two different
          // places for the same object.
          Row(children: [
            XpBadge(label: _xpLabel),
            const SizedBox(width: 8),
            if (streak > 0) StreakBadge(days: streak),
            if (streak > 0) const SizedBox(width: 8),
            const RankBadge(),
          ]),
          // THE NEXT BADGE MOVED TO PROGRESS. It sat here, under the
          // pills, on the tab you open to WORK — and the badge shelf is
          // something you go and LOOK at, which is what the Progress
          // screen is for. It's section 04 there now, next to the map,
          // the streak and the record, where the rest of the standing
          // already lives. Everything below moves up into the gap.
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
        splashRadius: 22,
      );
}

class _Heading extends StatefulWidget {
  final int done;
  final int total;
  /// THE FEAR BUTTON, rehoused. It lived in the masthead and squashed
  /// the streak flame against the wordmark. Top-right of the five tasks
  /// is where it belongs anyway — you bottle it looking at the missions,
  /// not looking at your XP.
  final VoidCallback onPanic;
  const _Heading(
      {required this.done, required this.total, required this.onPanic});

  @override
  State<_Heading> createState() => _HeadingState();
}

class _HeadingState extends State<_Heading> {
  /// FIVE OF FIVE gets confetti, once, on the transition.
  ///
  /// Not on every rebuild — a celebration that fires whenever the
  /// screen happens to repaint stops being one, and this app has been
  /// bitten by exactly that before. It fires on the frame the fifth
  /// mission lands and never again that session.
  bool _burst = false;
  bool _celebrated = false;

  void _maybeCelebrate(int done, int total) {
    if (total <= 0 || done < total || _celebrated) return;
    _celebrated = true;
    HapticFeedback.heavyImpact();
    setState(() => _burst = true);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _burst = false);
    });
  }

  @override
  void initState() {
    super.initState();
    // A man who opens the app already finished shouldn't get confetti
    // for arriving — only for the move that completed it.
    _celebrated = widget.total > 0 && widget.done >= widget.total;
  }

  @override
  void didUpdateWidget(covariant _Heading old) {
    super.didUpdateWidget(old);
    if (widget.done > old.done) _maybeCelebrate(widget.done, widget.total);
    // Reset at the day roll so tomorrow's fifth still lands.
    if (widget.done < old.done) _celebrated = false;
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.done;
    final total = widget.total;
    final onPanic = widget.onPanic;
    return Stack(clipBehavior: Clip.none, children: [
      if (_burst)
        Positioned(
          left: 0,
          right: 0,
          top: -60,
          height: 260,
          child: IgnorePointer(
              child: Burst(color: AppColors.signalGreen, pieces: 48)),
        ),
      _body(context, done, total, onPanic),
    ]);
  }

  Widget _body(
      BuildContext context, int done, int total, VoidCallback onPanic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('TODAY', style: AppTypography.label),
            const Spacer(),
            GestureDetector(
              onTap: onPanic,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded,
                      size: 12, color: AppColors.red),
                  const SizedBox(width: 3),
                  // BOTTLING IT is British for losing your nerve, and
                  // means nothing to an American reader — which is a
                  // hard fail on a label whose whole job is to sting.
                  // CHICKENING OUT lands the same everywhere.
                  Text('CHICKENING OUT',
                      style: AppTypography.label.copyWith(
                          color: AppColors.red, fontSize: 8.5)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // THE COUNT SITS WITH THE TITLE, not in a caption above it. It
        // was a separate line of small caps saying the same thing twice;
        // as a number beside the headline it's the one thing on the
        // screen that changes while he works, which is exactly what a
        // progress figure should be.
        // ONE MASTHEAD FACE ACROSS THE THREE TABS — tracked caps, see
        // AppTypography.masthead. This was a lowercase 30pt sentence and
        // Battles was 15pt tracked caps, so the three tabs never looked
        // like the same app.
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
          Flexible(
            child: Text('TODAY\'S REPS', style: AppTypography.masthead),
          ),
          if (total > 0) ...[
            const SizedBox(width: 12),
            Text('$done/$total',
                style: GoogleFonts.inter(
                  color: done >= total
                      ? AppColors.signalGreen
                      : AppColors.textTertiary,
                  fontSize: 20,
                  height: 1.1,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w900,
                  shadows: done >= total
                      ? [
                          const Shadow(
                              color: AppColors.signalGreen, blurRadius: 18)
                        ]
                      : null,
                )),
          ],
        ]),
        const SizedBox(height: 6),
        Text('Practice on AI. Then prove it in real life.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.red, fontWeight: FontWeight.w700)),
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


/// THE TWO SCORES. One rectangle, two numbers, no buttons.
///
/// Voice and text are graded on different rubrics and a man is rarely
/// the same on both — which is the point of showing them together. A
/// dash means he has not been scored on that surface yet; it is a gap in
/// the record, not a zero, and it should read like one.
class _ScoreCard extends StatelessWidget {
  final int? voice;
  final int? chat;
  const _ScoreCard({required this.voice, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('YOUR GAME',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 2,
            )),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _Half(
                        label: 'VOICE',
                        icon: Icons.graphic_eq_rounded,
                        score: voice)),
                Container(width: 1, color: Colors.white12),
                Expanded(
                    child: _Half(
                        label: 'CHAT',
                        icon: Icons.chat_bubble_rounded,
                        score: chat)),
              ]),
        ),
      ]),
    );
  }
}

class _Half extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? score;
  const _Half({required this.label, required this.icon, required this.score});

  @override
  Widget build(BuildContext context) {
    final has = score != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Text(label,
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 1.6,
            )),
      ]),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(has ? '$score' : '—',
                  style: AppTypography.masthead.copyWith(
                    color: has ? AppColors.red : AppColors.textTertiary,
                    fontSize: 42,
                    height: 1.0,
                  )),
              const SizedBox(width: 2),
              Text('/100',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  )),
            ]),
      ),
    ]);
  }
}
