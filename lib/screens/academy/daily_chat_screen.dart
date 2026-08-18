import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../services/backend/auth_service.dart';
import '../../services/backend/chat_score_service.dart';
import '../../services/backend/daily_chat_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../services/milestone_service.dart';
import '../../services/mission_catalog.dart';
import '../../services/rewards.dart';
import '../../services/today_targets.dart';
import '../../services/roster.dart';
import 'payout_screen.dart';
import '../../widgets/academy/brag_sheet.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/game_feel.dart';
import '../../widgets/academy/rizz_off_reveal.dart';
import '../roleplay/girl_chat_screen.dart';

/// THE CHAT CHALLENGE — the Daily, in writing.
///
/// Built as a deliberate mirror of the voice Daily rather than a
/// different screen that happens to do a similar job: same poster, same
/// one-shot framing, and the same count-up reveal at the end. They are
/// one event in two mediums and they should feel like it — the only
/// things that change are the scale (out of 100, not 10) and the rubric,
/// because you cannot hear a written line's delivery.
class DailyChatScreen extends StatefulWidget {
  const DailyChatScreen({super.key});

  @override
  State<DailyChatScreen> createState() => _DailyChatScreenState();
}

class _DailyChatScreenState extends State<DailyChatScreen> {
  bool _loading = true;
  /// The reel runs once per screen open, before she's named. It's
  /// theatre, not chance — see SlotReel — but it's the difference
  /// between being shown today's woman and watching her land.
  bool _spun = false;
  ChatMark? _mine;
  List<SquadMember> _roster = const [];
  List<ChatMark> _marks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final squad = await SquadService.mySquad();
    final roster = squad == null
        ? <SquadMember>[
            if (AuthService.userId != null)
              SquadMember(
                  userId: AuthService.userId!, handle: null, role: 'owner')
          ]
        : await SquadService.roster(squad.id);
    final marks =
        await DailyChatService.today([for (final m in roster) m.userId]);
    if (!mounted) return;
    final me = AuthService.userId;
    setState(() {
      _roster = roster;
      _marks = marks;
      _mine = marks.where((m) => m.userId == me).firstOrNull;
      _loading = false;
    });
  }

  Future<void> _run() async {
    if (_mine != null) return;
    HapticFeedback.heavyImpact();
    final girl = girlForVibe(scenarioOfToday());
    ChatScoreService.lastResult = null;

    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: girl.id,
            vibeKey: girl.vibeKey,
            name: girl.name,
            archetype: girl.archetype,
            portraitAsset: girl.asset,
            accent: girl.accent,
            opener: girl.opener,
            taskMode: true,
            scoreSurface: DailyChatService.surface,
            // This screen owns the ending — RizzOffReveal with the squad
            // slam in it. A verdict on the way out would be a second
            // full-screen result stacked behind the first.
            verdictOnFinish: false,
          ),
        ),
      ),
    );
    if (!mounted) return;

    // Same one-a-day guard as the voice reveal, and for the same reason:
    // the grade is submitted without await at the end of the chat, so it
    // can land after this read and re-fire the moment on the next visit.
    final r = ChatScoreService.lastResult;
    final already = await ChatScoreService.revealShownToday();
    if (r != null && !already) {
      ChatScoreService.lastResult = null;
      await ChatScoreService.markRevealShown();
      await _reveal(r);
      if (mounted) {
        await BragSheet.maybeShow(context,
            score: '${r.score}', scaleLabel: '/ 100');
      }
    }
    if (mounted) _load();
  }

  Future<void> _reveal(ChatResult r) async {
    final girl = girlForVibe(scenarioOfToday());
    // Pull the squad in so the final slam has other men in it. The chat
    // marks are reshaped into DailyMarks because the reveal already
    // knows how to rank those — one animation, both challenges.
    final marks = await DailyChatService.today(
        [for (final m in _roster) m.userId]);
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'scored',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, _, __) => RizzOffReveal(
        score: r.score,
        // The grade thresholds are cut against the 0..9999 band, so the
        // 0..100 chat score is put back on it for grading only. The
        // number on screen stays out of 100.
        gradeScore: (r.score * 99.99).round(),
        rubric: r.rubric,
        rankToday: 0,
        worldAvg: r.average,
        girlName: girl.name,
        girlAccent: kNeon,
        roster: _roster,
        squadMarks: [
          for (final m in marks)
            DailyMark(userId: m.userId, score: m.score, finished: true)
        ],
        divisor: 1,
        decimals: 0,
        suffix: '/ 100',
        kicker: 'THE CHAT CHALLENGE',
        axes: const [
          'opening',
          'relevance',
          'personality',
          'momentum',
          'restraint'
        ],
        axisLabels: const {
          'opening': 'OPENING',
          'relevance': 'RELEVANCE',
          'personality': 'PERSONALITY',
          'momentum': 'MOMENTUM',
          'restraint': 'RESTRAINT',
        },
      ),
      transitionBuilder: (ctx, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );

    // Same fix as the voice Daily: this graded a real conversation and
    // paid nothing. Chat already scores 0–100 so it needs no conversion.
    await Rewards.daily(r.score);
    // Same stone, the writing half: the message battle IS his AI text
    // mission rather than a second one under another name.
    await TodayTargets.credit(MissionKind.aiText);
    MilestoneService.pushTrophies(await Achievements.bump(Stat.dailies));
    MilestoneService.pushTrophies(await Achievements.bump(Stat.talks));
    if (r.score >= 90) {
      MilestoneService.pushTrophies(await Achievements.bump(Stat.nineties));
    }
    if (mounted) await PayoutScreen.cashOut(context);
  }

  @override
  Widget build(BuildContext context) {
    final girl = girlForVibe(scenarioOfToday());
    final done = _mine != null;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: _loading
          ? const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kNeon)))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── HER — the poster, same language as the voice Daily.
                SizedBox(
                  height: 470,
                  child: Stack(fit: StackFit.expand, children: [
                    if (!_spun && !done)
                      SlotReel(
                        pool: kRoster,
                        target: kRoster.indexWhere((g) => g.id == girl.id) < 0
                            ? 0
                            : kRoster.indexWhere((g) => g.id == girl.id),
                        accent: kNeon,
                        height: 470,
                        onLanded: () {
                          if (mounted) setState(() => _spun = true);
                        },
                      )
                    else
                      Image.asset(
                        girl.asset,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.08),
                        errorBuilder: (_, __, ___) => const DecoratedBox(
                          decoration:
                              BoxDecoration(color: AppColors.surface1),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: Colors.white),
                              ),
                            ]),
                            const Spacer(),
                            if (_spun || done)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TODAY · IN WRITING · SAME WOMAN',
                                      style: GoogleFonts.inter(
                                        color: kNeon,
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
                                              color: Colors.black
                                                  .withValues(alpha: 0.7),
                                              blurRadius: 18)
                                        ],
                                      )),
                                  const SizedBox(height: 4),
                                  Text(girl.archetype,
                                      style: GoogleFonts.inter(
                                        color: Colors.white
                                            .withValues(alpha: 0.82),
                                        fontSize: 13.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  const SizedBox(height: 16),
                                  if (done)
                                    _ScoredStrip(score: _mine!.score)
                                  else
                                    GameButton(
                                      label: 'ONE SHOT — RUN IT',
                                      color: kNeon,
                                      pulse: true,
                                      onTap: _run,
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                      done
                                          ? 'Scored. New woman at reset.'
                                          : 'No drafts. No retries. Type it '
                                              'like it counts.',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),

                // ── THE ROOM ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TODAY'S BOARD",
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 12),
                      if (!done)
                        Text('Nobody\'s number shows until you\'ve taken '
                            'yours.',
                            style: GoogleFonts.inter(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ))
                      else
                        for (final m in _roster) _row(m),

                      // ── WHAT YOU'RE JUDGED ON ────────────────────
                      // Half this screen was empty black before you'd
                      // run it, which read as unfinished. It's also the
                      // one moment a man will actually read the rubric:
                      // he's about to be given a number and he wants to
                      // know what moves it. A score you understand is
                      // worth chasing; one you don't is just a number.
                      const SizedBox(height: 30),
                      Text('WHAT SHE\'S JUDGING',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 14),
                      const _Axis(
                          label: 'OPENING',
                          body: 'Does the first line earn a reply on its '
                              'own merit.'),
                      const _Axis(
                          label: 'RELEVANCE',
                          body: 'You engage with what SHE said, not a '
                              'script you had ready.'),
                      const _Axis(
                          label: 'PERSONALITY',
                          body: 'A specific human is visible. Opinions, '
                              'humour, a point of view.'),
                      const _Axis(
                          label: 'MOMENTUM',
                          body: 'The thread goes somewhere. Hooks get '
                              'picked up.'),
                      const _Axis(
                          label: 'RESTRAINT',
                          body: 'Length, neediness, double-texting. '
                              'Wanting it less reads as wanting it more.'),
                      const SizedBox(height: 22),
                      Container(height: 1, color: AppColors.divider),
                      const SizedBox(height: 14),
                      Text(
                          'Fifteen messages ends it. Graded 0–100 on a '
                          'real-world standard — 50 is a forgettable '
                          'thread, 70 is genuinely good, 85 is rare. '
                          'Every point banks into your Rizz Chat total.',
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(SquadMember m) {
    final mark = _marks.where((x) => x.userId == m.userId).firstOrNull;
    final me = m.userId == AuthService.userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mark != null
                ? kNeon.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
                color: mark != null
                    ? kNeon.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text((me ? 'YOU' : (m.handle ?? 'A')).characters.first,
              style: GoogleFonts.inter(
                color: mark != null ? kNeon : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(me ? 'YOU' : (m.handle ?? 'ANON'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: me ? Colors.white : AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              )),
        ),
        Text(mark != null ? '${mark.score}' : 'MISSING',
            style: GoogleFonts.inter(
              color: mark != null ? Colors.white : AppColors.textMuted,
              fontSize: mark != null ? 17 : 9.5,
              letterSpacing: mark != null ? -0.5 : 1.4,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

/// One rubric axis. Reads as a rule of the game rather than a help
/// article — short label, one sentence, no hedging.
class _Axis extends StatelessWidget {
  final String label, body;
  const _Axis({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: kNeon),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    color: kNeon,
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 2),
              Text(body,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ScoredStrip extends StatelessWidget {
  final int score;
  const _ScoredStrip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kNeon.withValues(alpha: 0.7), width: 1.6),
        boxShadow: [
          BoxShadow(color: kNeon.withValues(alpha: 0.3), blurRadius: 22)
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$score',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 30,
              height: 1,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 8),
        Text('OUT OF 100',
            style: GoogleFonts.inter(
              color: kNeon,
              fontSize: 8.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}
