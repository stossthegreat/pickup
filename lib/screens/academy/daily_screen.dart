import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/daily_game_service.dart';
import '../../services/backend/squad_broadcast.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../services/achievements.dart';
import '../../services/economy.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe;
import '../../widgets/academy/brag_sheet.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/league_crest.dart';
import '../../widgets/academy/ascend_reveal.dart';
import '../../widgets/academy/rizz_off_reveal.dart';
import '../game/freeflow/free_flow_screen.dart';

/// THE DAILY — the arena. Her face fills the top third like a fight
/// poster, the crest carries the division, the league panel shows the
/// promotion and drop zones with the Sunday lock counting down, and the
/// weekly fixture puts one squadmate's name against yours.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DailyStatus? _s;
  bool _loading = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // drive the countdowns
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DailyGameService.status();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
    if (s == null) return;
    // Week-end verdicts — league first, then the fixture.
    if (s.ceremony == 'promoted' || s.ceremony == 'relegated') {
      _ceremony(promoted: s.ceremony == 'promoted', league: s.league);
    } else if (s.fixtureCeremony == 'won' || s.fixtureCeremony == 'lost') {
      _fixtureCeremony(won: s.fixtureCeremony == 'won');
    }
  }

  // ── Ceremonies — full-screen, with confetti ─────────────────────────
  void _ceremony({required bool promoted, required LeagueState league}) {
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        barrierLabel: 'result',
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (ctx, _, __) => _CeremonySheet(
          title: promoted ? 'PROMOTED' : 'RELEGATED',
          subtitle: promoted
              ? 'You climbed into ${league.divisionName}.'
              : 'You dropped to ${league.divisionName}.',
          body: promoted
              ? 'New league. Harder men. Keep climbing.'
              : 'One week to take it back. Run the daily.',
          division: league.division,
          accent: promoted ? kNeon : AppColors.red,
          confetti: promoted,
          cta: promoted ? 'KEEP CLIMBING' : 'TAKE IT BACK',
        ),
        transitionBuilder: (ctx, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(
                CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      );
    });
  }

  void _fixtureCeremony({required bool won}) {
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        barrierLabel: 'fixture',
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (ctx, _, __) => _CeremonySheet(
          title: won ? 'FIXTURE WON' : 'FIXTURE LOST',
          subtitle: won
              ? 'You outworked your man this week.'
              : 'He outworked you this week.',
          body: won
              ? 'One in the record. New fixture Monday.'
              : 'New fixture Monday. Even it up.',
          division: _s?.league.division ?? 1,
          accent: won ? kNeon : AppColors.red,
          confetti: won,
          cta: won ? 'NICE' : 'RUN IT BACK',
        ),
        transitionBuilder: (ctx, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(
                CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      );
    });
  }

  /// The one attempt — armed session; the transcript submits itself.
  Future<void> _run() async {
    final s = _s;
    if (s == null || s.attempted) return;
    HapticFeedback.heavyImpact();
    // Tell the room he's in it before he starts, so bailing is visible.
    // ignore: discarded_futures
    SquadBroadcast.dailyStarted(s.scenarioKey);
    DailyGameService.armedDaily = true;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => FreeFlowScreen(initialVibeKey: s.scenarioKey),
    ));
    DailyGameService.armedDaily = false;
    if (!mounted) return;
    final r = DailyGameService.lastResult;
    // ONCE A DAY, AND ONCE ONLY. Clearing lastResult wasn't enough: the
    // submit that sets it is fire-and-forget inside FreeFlowScreen, so it
    // can land after this read, survive, and re-fire the reveal on the
    // next return — which is why it kept replaying. The guard is now a
    // persisted per-day stamp, so the big moment can only happen on the
    // day it was earned no matter what order the futures settle in.
    final alreadyRevealed = await DailyGameService.revealShownToday();
    if (r != null && !alreadyRevealed) {
      DailyGameService.lastResult = null;
      await DailyGameService.markRevealShown();
      // Pull the squad in for the final slam. Fail-soft: solo users and
      // anyone offline just get the personal reveal, never a stall.
      var roster = <SquadMember>[];
      var marks = <DailyMark>[];
      try {
        final squad = await SquadService.mySquad();
        if (squad != null) {
          roster = await SquadService.roster(squad.id);
          marks = await SquadService.dailyToday(
              [for (final m in roster) m.userId],
              squadId: squad.id);
        }
      } catch (_) {/* solo reveal */}
      if (!mounted) return;

      final girl = girlForVibe(s.scenarioKey);
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.black,
        barrierDismissible: false,
        barrierLabel: 'scored',
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (ctx, _, __) => RizzOffReveal(
          score: r.score,
          rubric: r.rubric,
          rankToday: r.rankToday,
          worldAvg: r.worldAvg,
          girlName: girl.name,
          girlAccent: girl.accent,
          roster: roster,
          squadMarks: marks,
        ),
        transitionBuilder: (ctx, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      );
      // THE DAILY PAID NOTHING. A live voice conversation with a woman,
      // graded on five axes, the flagship event of the day — and the
      // progression bar did not move. See rewards.dart; this was the
      // single biggest hole in the economy.
      final ai = Economy.aiScoreFromVoice(r.score);
      await Rewards.daily(ai);
      MilestoneService.pushTrophies(await Achievements.bump(Stat.dailies));
      MilestoneService.pushTrophies(await Achievements.bump(Stat.talks));
      if (ai >= 90) {
        MilestoneService.pushTrophies(await Achievements.bump(Stat.nineties));
      }
      if (mounted) await AscendReveal.settle(context);

      // THE ASK, at the only moment it lands: he's holding a number he
      // didn't have ninety seconds ago. Fires once ever, and never for a
      // man who already has a squad.
      if (mounted) {
        await BragSheet.maybeShow(context, score: '$ai', scaleLabel: '/ 100');
      }
    }
    _load();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    String two(int v) => v.toString().padLeft(2, '0');
    if (d.inDays > 0) return '${d.inDays}D ${two(d.inHours % 24)}H';
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Duration get _untilReset {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day)
        .add(const Duration(days: 1))
        .difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: _loading
          ? const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red)))
          : s == null
              ? SafeArea(child: _offline())
              : RefreshIndicator(
                  color: AppColors.red,
                  backgroundColor: AppColors.surface1,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _hero(s),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                        child: Column(children: [
                          if (s.fixture != null) ...[
                            _fixture(s.fixture!),
                            const SizedBox(height: 18),
                          ],
                          _league(s.league),
                          const SizedBox(height: 18),
                          _board(s),
                        ]),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Offline state. The message alone was a dead end — you saw the
  /// failure and had nowhere to go with it. Now the diagnostic is one
  /// tap away FROM THE SCREEN THAT FAILED, not buried in settings.
  Widget _offline() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 34, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text('THE DAILY needs a connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'The server didn\'t answer. Run the check below and '
                'it will tell you exactly which call failed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            GameButton(
              label: 'RUN BACKEND CHECK',
              color: AppColors.red,
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/backend-check');
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _load,
              child: Text('Try again',
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );

  // ── HERO — her face, the poster ─────────────────────────────────────
  Widget _hero(DailyStatus s) {
    final girl = girlForVibe(s.scenarioKey);
    return SizedBox(
      // Taller frame, crop pushed down the render. At 430/-0.25 the poster
      // cut her off around the eyeline and handed the rest of the screen to
      // chrome — you never actually met her. 470 with the crop near centre
      // carries the frame from mid-face down past the chin, which is the
      // part of a portrait that does the work.
      height: 470,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(
          girl.asset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.08),
          errorBuilder: (_, __, ___) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  girl.accent.withValues(alpha: 0.4),
                  AppColors.base
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // The scrim now stays off her face and only ramps up under
              // the chin, where the type sits. Darkening the middle third
              // was what made her look flat and the screen look cheap.
              colors: [
                Colors.black.withValues(alpha: 0.46),
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.78),
                AppColors.base,
              ],
              stops: const [0.0, 0.44, 0.82, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Text('RESETS ${_fmt(_untilReset)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ]),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TODAY · ONE SHOT · THE WHOLE WORLD',
                          style: GoogleFonts.inter(
                            color: girl.accent,
                            fontSize: 10,
                            letterSpacing: 2.6,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 8),
                      Text(girl.name.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 54,
                            height: 0.94,
                            letterSpacing: -2.4,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  blurRadius: 18)
                            ],
                          )),
                      const SizedBox(height: 4),
                      Text(girl.archetype,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 16),
                      if (s.attempted)
                        _scoredStrip(s)
                      else
                        GameButton(
                          label: 'ONE SHOT — RUN IT',
                          pulse: true,
                          onTap: _run,
                        ),
                      if (!s.attempted) ...[
                        const SizedBox(height: 8),
                        Text('No retries. No warm-up. This is the rep.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _scoredStrip(DailyStatus s) {
    final beat = (s.myScore ?? 0) >= (s.worldAvg ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (beat ? kNeon : Colors.white).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CountUp(
          value: s.myScore ?? 0,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Text(s.worldAvg == null ? 'SCORED' : 'WORLD AVG ${s.worldAvg}',
            style: GoogleFonts.inter(
              color: beat ? kNeon : AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            )),
        const Spacer(),
        Icon(beat ? Icons.trending_up_rounded : Icons.remove_rounded,
            size: 18, color: beat ? kNeon : AppColors.textTertiary),
      ]),
    );
  }

  // ── FIXTURE — you vs one squadmate, all week ────────────────────────
  Widget _fixture(FixtureState f) {
    final me = f.myPoints, them = f.theirPoints;
    final total = (me + them) == 0 ? 1 : (me + them);
    final lead = f.winning
        ? kNeon
        : f.level
            ? AppColors.textSecondary
            : AppColors.red;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lead.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: lead.withValues(alpha: 0.14), blurRadius: 24)
        ],
      ),
      child: Column(children: [
        Row(children: [
          Text('THIS WEEK\'S FIXTURE',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 10,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w800,
              )),
          const Spacer(),
          Text('LOCKS ${_fmt(f.locksAt.difference(DateTime.now().toUtc()))}',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              )),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(children: [
              Text('YOU',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              CountUp(
                value: me,
                style: GoogleFonts.inter(
                  color: f.winning ? kNeon : Colors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
          Column(children: [
            Text('VS',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 4),
            Container(width: 1, height: 30, color: AppColors.surface3),
          ]),
          Expanded(
            child: Column(children: [
              Text((f.opponentHandle ?? 'RIVAL').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              CountUp(
                value: them,
                style: GoogleFonts.inter(
                  color: !f.winning && !f.level ? AppColors.red : Colors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Tug-of-war bar — the lead is visible, not implied.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              Expanded(
                flex: (me * 100 ~/ total).clamp(1, 99),
                child: Container(color: kNeon),
              ),
              Expanded(
                flex: (them * 100 ~/ total).clamp(1, 99),
                child: Container(color: AppColors.red),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            f.level
                ? 'Dead level. Every rep counts.'
                : f.winning
                    ? 'You\'re ahead — don\'t coast.'
                    : 'You\'re behind. ${f.opponentRecord} on his record.',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            )),
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }

  // ── LEAGUE — crest, ring, zones ─────────────────────────────────────
  Widget _league(LeagueState l) {
    final until = l.locksAt.difference(DateTime.now().toUtc());
    final (zoneColor, zoneText) = switch (l.zone) {
      'promotion' => (kNeon, 'PROMOTION ZONE · TOP 10 CLIMB'),
      'drop' => (AppColors.red, 'DROP ZONE · BOTTOM 5 FALL'),
      _ => (AppColors.textSecondary, 'SAFE — FOR NOW'),
    };
    // Progress toward the promotion cut (rank 10 of the table).
    final progress = l.size <= 1
        ? 0.0
        : ((l.size - l.rank) / (l.size - 1)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
        boxShadow: l.zone != 'safe'
            ? [BoxShadow(color: zoneColor.withValues(alpha: 0.16), blurRadius: 28)]
            : null,
      ),
      child: Column(children: [
        Row(children: [
          LeagueCrest(division: l.division, size: 66),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.divisionName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text('${l.points} PTS · ${l.size} MEN',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: zoneColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(zoneText,
                      style: GoogleFonts.inter(
                        color: zoneColor,
                        fontSize: 9.5,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ],
            ),
          ),
          ProgressRing(
            value: progress,
            size: 68,
            color: zoneColor,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('#${l.rank}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  )),
              Text('OF ${l.size}',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 8,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.lock_clock_rounded, size: 13, color: AppColors.red),
          const SizedBox(width: 6),
          Text('LOCKS IN ${_fmt(until)}',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text('SUNDAY 21:00',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }

  // ── TODAY'S BOARD ───────────────────────────────────────────────────
  Widget _board(DailyStatus s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TODAY\'S BOARD',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 10.5,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 10),
      if (s.board.isEmpty)
        Text('Nobody has taken their shot yet. Be first.',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ))
      else
        for (final (i, e) in s.board.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
              border: i == 0
                  ? Border.all(
                      color: const Color(0xFFF5C542).withValues(alpha: 0.55))
                  : null,
            ),
            child: Row(children: [
              SizedBox(
                width: 30,
                child: i == 0
                    ? const Icon(Icons.emoji_events_rounded,
                        size: 17, color: Color(0xFFF5C542))
                    : Text('${i + 1}',
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        )),
              ),
              Expanded(
                child: Text(e.handle ?? 'ANON',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              Text('${e.score}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CEREMONIES — full-screen moments with confetti
// ══════════════════════════════════════════════════════════════════════

class _CeremonySheet extends StatelessWidget {
  final String title, subtitle, body, cta;
  final int division;
  final Color accent;
  final bool confetti;
  const _CeremonySheet({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.cta,
    required this.division,
    required this.accent,
    required this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        if (confetti) Positioned.fill(child: Burst(color: accent)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LeagueCrest(division: division, size: 132)
                  .animate()
                  .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 520.ms,
                      curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1100.ms, color: Colors.white54),
              const SizedBox(height: 26),
              Text(title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 38,
                        letterSpacing: 3,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: accent.withValues(alpha: 0.6),
                              blurRadius: 34)
                        ],
                      ))
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 340.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 12),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )).animate().fadeIn(delay: 380.ms),
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  )).animate().fadeIn(delay: 480.ms),
              const SizedBox(height: 30),
              SizedBox(
                width: 240,
                child: GameButton(
                  label: cta,
                  color: accent,
                  textColor: accent == kNeon ? Colors.black : Colors.white,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ).animate().fadeIn(delay: 620.ms),
            ]),
          ),
        ),
      ]),
    );
  }
}
