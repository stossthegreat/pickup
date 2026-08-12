import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/daily_chat_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/challenge_card.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../widgets/academy/day_beat.dart';
import '../../widgets/academy/squad_chrome.dart';
import '../../widgets/academy/your_five.dart' show voiceOutOfTen;

/// TODAY — the whole day on one screen, three cards.
///
/// Home used to stack the day gauge, the Daily and the squad strip on
/// top of each other, which meant three competing invitations before you
/// reached the missions. It's one card there now, and this is where it
/// goes: your standing, then the two challenges, in the order you'd
/// actually do them.
///
///   01 WHERE YOU'RE AT — the crest, the form, the day's clock
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
    ]);
    if (!mounted) return;
    setState(() {
      _squad = squad;
      _roster = roster;
      _board = results[0] as List<Mission>;
      _squadStates = results[1] as Map<String, MissionPulse>;
      _voice = results[2] as List<DailyMark>;
      _chat = results[3] as List<ChatMark>;
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 01 · THE SQUAD. It was a thin link buried at
                          // the very bottom — the door to the whole room,
                          // below two full-bleed posters, which is the
                          // last place anyone looks. It leads now.
                          ChapterMark(
                            index: '01',
                            title: 'YOUR SQUAD',
                            sub: 'Where the day stands.',
                            accent: accent,
                          ),
                          _SquadStatsCard(
                            name: _squad?.name ?? 'SOLO',
                            accent: accent,
                            form: day.form,
                            complete: day.complete,
                            possible: day.possible,
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

class _Stat extends StatelessWidget {
  final String value, label;
  final Color accent;
  const _Stat(
      {required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 24,
            height: 1,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 3),
      Text(label,
          style: GoogleFonts.inter(
            color: accent,
            fontSize: 8.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }
}

/// 01 — THE SQUAD. The crest, the three numbers that matter, and the
/// way into the room. One object rather than a stat strip stuck to the
/// masthead and a thin link stranded at the bottom of the scroll.
class _SquadStatsCard extends StatelessWidget {
  final String name;
  final Color accent;
  final int form, complete, possible, men;
  final bool hasSquad;
  final VoidCallback onTap;

  const _SquadStatsCard({
    required this.name,
    required this.accent,
    required this.form,
    required this.complete,
    required this.possible,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                  accent.withValues(alpha: 0.14), AppColors.surface2),
              AppColors.surface1,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 12)),
            BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 30),
          ],
        ),
        child: Column(children: [
          Row(children: [
            SquadCrest(name: name, accent: accent, size: 48),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasSquad ? 'THE SQUAD' : 'SOLO RUN',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 8.5,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 3),
                  Text(name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.05,
                        letterSpacing: -0.9,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _Stat(
                    value: '$form', label: 'FORM', accent: accent)),
            Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.07)),
            Expanded(
                child: _Stat(
                    value: '$complete/$possible',
                    label: 'MOVES',
                    accent: accent)),
            Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.07)),
            Expanded(
                child: _Stat(
                    value: '$men',
                    label: men == 1 ? 'MAN' : 'MEN',
                    accent: accent)),
          ]),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 11),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(hasSquad ? Icons.meeting_room_rounded : Icons.group_add_rounded,
                size: 14, color: accent),
            const SizedBox(width: 8),
            Text(
                hasSquad
                    ? 'OPEN THE ROOM · BOARD, WEEK, PULSE'
                    : 'START A SQUAD — TWO MEN IS ENOUGH',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ]),
      ),
    );
  }
}
