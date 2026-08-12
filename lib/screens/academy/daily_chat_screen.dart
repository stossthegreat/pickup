import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/chat_score_service.dart';
import '../../services/backend/daily_chat_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../widgets/academy/game_button.dart';
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
                    Image.asset(
                      girl.asset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.08),
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(color: AppColors.surface1),
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
