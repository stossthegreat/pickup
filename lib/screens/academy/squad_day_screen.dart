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
import '../../theme/app_colors.dart';
import '../../widgets/academy/challenge_card.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../widgets/academy/day_beat.dart';
import '../../widgets/academy/rolodex_shelf.dart';
import '../../widgets/academy/squad_chrome.dart';
import '../../widgets/academy/streak_chain.dart';
import '../../widgets/academy/your_five.dart' show voiceOutOfTen;

/// TODAY — the whole day on one screen, three cards.
///
/// Home used to stack the day gauge, the Daily and the squad strip on
/// top of each other, which meant three competing invitations before you
/// reached the missions. It's one card there now, and this is where it
/// goes: your standing, then the two challenges, in the order you'd
/// actually do them.
///
///   01 THE CHAIN — the streak, the quorum, the armband, the bench
///   02 THE VOICE CHALLENGE — out of 10
///   03 THE CHAT CHALLENGE  — out of 100
///
/// Both challenges are the SAME woman on the same day for the whole
/// squad and the whole world, so a score means something next to
/// someone else's. Under each one sits every man in the squad: his mark,
/// or the fact he hasn't shown up, and a trophy on whoever's leading.
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
      _loading = false;
    });
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
    // Goes to the poster, not straight into the conversation. The voice
    // challenge gets a screen that sets it up before you commit and the
    // chat one was dropping you into a keyboard — same event, so it gets
    // the same run-up and the same reveal on the way out.
    await context.push('/daily-chat');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final girl = girlForVibe(scenarioOfToday());
    final day = _day;
    final accent = day.won ? kNeon : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: _loading
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
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── 01 · WHERE YOU'RE AT ────────────────────────
                    _stats(day, accent),

                    // THE SHELF — deliberately not a card. One line of
                    // faces, most of them still black, sitting above the
                    // three challenges. It's the only thing on this
                    // screen that shows him something he OWNS, and the
                    // only thing that shows him what's missing.
                    RolodexShelf(
                      onTap: () async {
                        await context.push('/rolodex');
                        if (mounted) _load();
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 01 · THE CHAIN. This replaced the squad
                          // stats card, which reported the same day in
                          // a weaker form: a percentage nobody can lose.
                          // The chain is the one thing the squad holds
                          // jointly and can break, and a thing you can
                          // lose outperforms a thing you can measure.
                          ChapterMark(
                            index: '01',
                            title: 'THE CHAIN',
                            sub: 'What the squad can lose.',
                            accent: accent,
                          ),
                          SquadStreakHero(
                            history: _history,
                            roster: _roster,
                            accent: accent,
                            onRun: _runVoice,
                          ),
                          const SizedBox(height: 9),
                          _RoomDoor(
                            name: _squad?.name ?? 'SOLO',
                            accent: accent,
                            form: day.form,
                            men: _roster.length,
                            hasSquad: _squad != null,
                            onTap: () async {
                              await context.push('/squad');
                              if (mounted) _load();
                            },
                          ),
                          const SizedBox(height: 26),

                          ChapterMark(
                            index: '02',
                            title: 'THE VOICE CHALLENGE',
                            sub: 'Out loud. One attempt.',
                            accent: accent,
                          ),
                          ChallengeCard(
                            kicker: 'VOICE · TODAY',
                            icon: Icons.graphic_eq_rounded,
                            accent: AppColors.red,
                            girl: girl,
                            roster: _roster,
                            scaleLabel: 'OUT OF 10',
                            marks: [
                              for (final v in _voice)
                                if (v.finished)
                                  ChallengeMark(
                                    userId: v.userId,
                                    raw: v.score ?? 0,
                                    display: voiceOutOfTen(v.score ?? 0),
                                  ),
                            ],
                            onRun: _runVoice,
                          ),
                          const SizedBox(height: 26),

                          ChapterMark(
                            index: '03',
                            title: 'THE CHAT CHALLENGE',
                            sub: 'Same woman, in writing.',
                            accent: accent,
                          ),
                          ChallengeCard(
                            kicker: 'CHAT · TODAY',
                            icon: Icons.forum_rounded,
                            accent: kNeon,
                            girl: girl,
                            roster: _roster,
                            scaleLabel: 'OUT OF 100',
                            marks: [
                              for (final c in _chat)
                                ChallengeMark(
                                  userId: c.userId,
                                  raw: c.score,
                                  display: '${c.score}',
                                ),
                            ],
                            onRun: _runChat,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 01 — the crest, the standing, the clock. The badge card he asked
  /// for: one look tells you who you are and how today is going.
  Widget _stats(SquadDay day, Color accent) {
    final name = _squad?.name ?? 'SOLO';
    return Stack(children: [
      Positioned.fill(child: SquadAtmosphere(accent: accent)),
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
          child: Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/leaderboard');
              },
              icon: const Icon(Icons.emoji_events_outlined,
                  size: 20, color: AppColors.textSecondary),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Column(children: [
            SquadCrest(name: name, accent: accent, size: 84),
            const SizedBox(height: 14),
            Text(_squad == null ? 'TODAY' : 'YOUR SQUAD',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 9,
                  letterSpacing: 3.4,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 5),
            Text(name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 18)
                  ],
                )),
            const SizedBox(height: 16),
            DayBeat(day: _squad == null ? null : day),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    ]);
  }
}

/// THE DOOR — the way into the room, as one line rather than a card.
///
/// This replaced a stats card carrying FORM / MOVES / MEN in three big
/// numbers. Those numbers were true and nobody could lose any of them,
/// which is exactly why they never moved anyone; the chain above says
/// the same thing with a stake attached. What the card was still good
/// for was being the door, so that's all this is now — and the day
/// screen carries one less block of visual weight for it.
class _RoomDoor extends StatelessWidget {
  final String name;
  final Color accent;
  final int form;
  final int men;
  final bool hasSquad;
  final VoidCallback onTap;

  const _RoomDoor({
    required this.name,
    required this.accent,
    required this.form,
    required this.men,
    required this.hasSquad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Icon(hasSquad ? Icons.meeting_room_rounded : Icons.group_add_rounded,
              size: 15, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
                hasSquad
                    ? '${name.toUpperCase()}  ·  $men ${men == 1 ? 'MAN' : 'MEN'}  ·  FORM $form'
                    : 'START A SQUAD  ·  NOTHING TO LOSE ON YOUR OWN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: hasSquad ? AppColors.textSecondary : accent,
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}
