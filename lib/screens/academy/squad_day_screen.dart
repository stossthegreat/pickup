import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/daily_chat_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_history_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/comeback_service.dart';
import '../../services/economy.dart';
import '../../services/mirror_service.dart';
import '../../services/rolodex_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/battle_card.dart';
import '../../widgets/academy/challenge_row.dart';
import '../../widgets/academy/five_board.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../widgets/academy/comeback_sheet.dart';
import '../../widgets/academy/mirror_band.dart';
import '../../widgets/academy/rolodex_shelf.dart';
import '../../widgets/academy/squad_hero.dart';
import '../../widgets/academy/streak_chain.dart';
import '../roleplay/girl_chat_screen.dart';

/// SQUAD HOME — not a menu for squad features.
///
/// The screen you land on after tapping your squad used to be a
/// contents page: numbered chapters, a door to the room, a link to the
/// board. Nobody opens a squad to browse. The job of this screen is one
/// sentence:
///
///     MAKE THE FIVE OF THEM PUSH EACH OTHER THROUGH TODAY.
///
/// Everything on it either competes, completes, or pressures somebody
/// else to complete. In that order:
///
///   1  HOW ARE WE DOING   score, level bar, chain, active today
///   2  THE FIVE           who's done today's programme — behind first
///   3  THE CHALLENGES     voice + message, everyone's marks on the face
///   4  THE CHAIN          the thing they can lose
///   5  BATTLES            the thing that moves his rating
///
/// Deeper things live behind the two badged icons top-right, so the
/// activity feed stops competing with the challenges for attention.
///
/// ── THE DIFFERENT-STAGES PROBLEM ──────────────────────────────────
/// Two men at different points on the 60-day map get different
/// missions, so comparing WHICH missions they did would be nonsense and
/// would punish the man who's further on for having harder work.
///
/// So nothing here compares mission identity. The Five compares MOVES
/// MADE OUT OF FIVE — everyone has exactly five a day whatever their
/// stage. The two things that ARE identical for everybody, the daily
/// voice and chat challenges (same woman worldwide), are compared on
/// SCORE. Effort where the work differs, score where it doesn't.
class SquadDayScreen extends StatefulWidget {
  const SquadDayScreen({super.key});

  @override
  State<SquadDayScreen> createState() => _SquadDayScreenState();
}

class _SquadDayScreenState extends State<SquadDayScreen> {
  bool _loading = true;
  Squad? _squad;
  List<SquadMember> _roster = const [];
  List<Mission> _board = const [];
  Map<String, MissionPulse> _squadStates = const {};
  List<DailyMark> _voice = const [];
  List<ChatMark> _chat = const [];
  SquadHistory _history = SquadHistory.empty;
  List<SquadEvent> _pulse = const [];

  /// Things the squad did today. The badge number — an icon says "there
  /// is a thing here", a badged icon says "three things happened while
  /// you were gone", and only one of those gets tapped.
  int get _unseenPulse {
    final now = DateTime.now();
    var n = 0;
    for (final e in _pulse) {
      final d = e.createdAt.toLocal();
      if (d.year == now.year && d.month == now.month && d.day == now.day) n++;
    }
    return n > 99 ? 99 : n;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final squad = await SquadService.mySquad();
    // Solo men get this screen too. The challenges are global — the only
    // thing a squad adds is other people's marks under yours — so a man
    // with no squad still sees his own day rather than a locked door.
    final roster = squad == null
        ? <SquadMember>[
            if (AuthService.userId != null)
              SquadMember(
                  userId: AuthService.userId!, handle: null, role: 'owner')
          ]
        : await SquadService.roster(squad.id);
    final ids = [for (final m in roster) m.userId];

    final results = await Future.wait([
      MissionService.todayBoard(count: SquadDay.missionsPerDay),
      SquadService.missionPulseToday(ids),
      SquadService.dailyToday(ids, squadId: squad?.id),
      DailyChatService.today(ids),
      // Thirty days of daily_attempts for this roster. Same table, same
      // RLS policy dailyToday already reads through — the only
      // difference is the ymd filter is a range. Nothing to deploy.
      SquadHistory.load(ids),
      squad == null
          ? Future<List<SquadEvent>>.value(const [])
          : SquadService.pulse(squad.id),
    ]);
    if (!mounted) return;
    setState(() {
      _squad = squad;
      _roster = roster;
      _board = results[0] as List<Mission>;
      _squadStates = results[1] as Map<String, MissionPulse>;
      _voice = results[2] as List<DailyMark>;
      _chat = results[3] as List<ChatMark>;
      _history = results[4] as SquadHistory;
      _pulse = results[5] as List<SquadEvent>;
      _loading = false;
    });
    // ignore: discarded_futures
    _reentry();
  }

  /// THE FIFTH DAY BACK — the moment retention is actually won or lost,
  /// and the one almost nobody designs for.
  ///
  /// Order matters here. The comeback runs FIRST and, if it fires, the
  /// mirror waits until next time. A man returning after a lapse gets
  /// exactly one thing to look at, and it is a woman who noticed he was
  /// gone — not a stack of sheets telling him what else changed while he
  /// wasn't here.
  Future<void> _reentry() async {
    final offer = await ComebackService.take();
    if (!mounted) return;
    if (offer != null) {
      _offerOpener = offer.opener;
      await ComebackSheet.show(context, offer, onReply: _openHer);
      return;
    }
    await _mirrorMoment();
  }

  /// Straight into the conversation, with HER line already sent. The
  /// whole point of the comeback is that he never has to start anything
  /// — GirlChatConfig.opener already does exactly this job, so replying
  /// needs no new chat machinery at all.
  Future<void> _openHer(NumberCard card) async {
    final g = card.girl;
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: g.id,
            vibeKey: g.vibeKey,
            name: g.name,
            archetype: g.archetype,
            portraitAsset: g.asset,
            accent: g.accent,
            opener: _offerOpener,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Held between the sheet and the push so her exact line survives the
  /// hop — the chat has to open on the SAME sentence he just read, or
  /// the illusion that she messaged him breaks on the first frame.
  String _offerOpener = '';

  Future<void> _mirrorMoment() async {
    final t = await MirrorService.takeChange();
    if (t == null || !mounted) return;
    await showMirrorSheet(context, t, announce: true);
  }

  SquadDay get _day => SquadDay(
        roster: _roster,
        board: _board,
        squadStates: _squadStates,
        daily: _voice,
      );

  Future<void> _runVoice() async {
    await context.push('/daily');
    if (mounted) _load();
  }

  Future<void> _runChat() async {
    await context.push('/daily-chat');
    if (mounted) _load();
  }

  /// A nudge is squad-visible, never a private DM. The point isn't that
  /// Tyler gets told — it's that the room watched you tell him.
  Future<void> _nudge(SquadMember m) async {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.mediumImpact();
    await SquadService.postEvent(s.id, 'nudge', {
      'target': m.userId,
      'handle': m.handle ?? 'ANON',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Nudged ${m.handle ?? 'them'}. The squad saw it.'),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final girl = girlForVibe(scenarioOfToday());
    final day = _day;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: _loading
          ? const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red)))
          : RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface1,
              onRefresh: _load,
              child: Stack(children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ══ 1 · HOW ARE WE DOING ════════════════════════
                    // One number, one bar, two facts. Nobody opens a
                    // squad to browse a menu; they open it to find out
                    // how the five of them are doing and whether
                    // they're the one holding it up.
                    SquadHero(
                      name: _squad?.name ?? 'SOLO',
                      history: _history,
                      memberCount: _roster.length,
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ══ 2 · THE FIVE ══════════════════════════
                          // The functional heart. Behind-first ordering
                          // so the man holding it up can't be missed,
                          // and every face is a door to nudging him.
                          FiveBoard(
                            day: day,
                            roster: _roster,
                            onNudge: _nudge,
                          ),
                          const SizedBox(height: 26),

                          // ══ 3 · TODAY'S CHALLENGES ════════════════
                          // Rows, not posters. Her face is a fact about
                          // today, not a headline — the big version is
                          // earned by a tap rather than forced on him
                          // twice a day. Everyone's score sits on the
                          // face of the card, hidden until he's run it.
                          Text('TODAY\'S CHALLENGES',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 3.4,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 14),
                          ChallengeRow(
                            kicker: 'VOICE RIZZ-OFF',
                            icon: Icons.graphic_eq_rounded,
                            accent: AppColors.red,
                            girl: girl,
                            roster: _roster,
                            marks: [
                              for (final v in _voice)
                                if (v.finished)
                                  RowMark(
                                    userId: v.userId,
                                    score: Economy.aiScoreFromVoice(
                                        v.score ?? 0),
                                  ),
                            ],
                            onRun: _runVoice,
                          ),
                          const SizedBox(height: 11),
                          ChallengeRow(
                            kicker: 'MESSAGE BATTLE',
                            icon: Icons.forum_rounded,
                            accent: kNeon,
                            girl: girl,
                            roster: _roster,
                            marks: [
                              for (final c in _chat)
                                RowMark(
                                    userId: c.userId,
                                    score: Economy.aiScoreFromChat(c.score)),
                            ],
                            onRun: _runChat,
                          ),
                          const SizedBox(height: 26),

                          // ══ 4 · WHAT THE SQUAD CAN LOSE ═══════════
                          SquadStreakHero(
                            history: _history,
                            roster: _roster,
                            accent: day.won ? kNeon : AppColors.red,
                            onRun: _runVoice,
                          ),
                          const SizedBox(height: 26),

                          // ══ 5 · COMPETE ═══════════════════════════
                          BattleCard(
                            onOpen: () async {
                              await context.push('/battles');
                              if (mounted) _load();
                            },
                          ),
                          const SizedBox(height: 22),

                          // Personal things, kept small and last — this
                          // screen belongs to the five, not to him.
                          const MirrorBand(),
                          const SizedBox(height: 6),
                          RolodexShelf(
                            onTap: () async {
                              await context.push('/rolodex');
                              if (mounted) _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ══ TOP RIGHT · TWO DOORS ═══════════════════════════
                // Everything deeper lives behind these. The activity
                // feed used to run down the bottom of the screen where
                // it competed with the challenges for attention and won;
                // as a badged icon it says the same thing in 20 square
                // points and stays out of the way.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 6,
                  right: 6,
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                    const Spacer(),
                    _TopIcon(
                      icon: Icons.wifi_tethering_rounded,
                      count: _unseenPulse,
                      onTap: () async {
                        await context.push('/squad');
                        if (mounted) _load();
                      },
                    ),
                    _TopIcon(
                      icon: Icons.show_chart_rounded,
                      count: 0,
                      onTap: () async {
                        await context.push('/squad');
                        if (mounted) _load();
                      },
                    ),
                  ]),
                ),
              ]),
            ),
    );
  }
}

/// A top-right door with a red count on it. The number is the whole
/// point — an icon says "there is a thing here", a badged icon says
/// "three things happened while you were gone", and only one of those
/// gets tapped.
class _TopIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _TopIcon(
      {required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 17),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.base, width: 2),
                ),
                child: Text(count > 9 ? '9+' : '$count',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
        ]),
      ),
    );
  }
}
