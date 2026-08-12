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
import '../roleplay/girl_chat_screen.dart';

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
    final girl = girlForVibe(scenarioOfToday());
    // The chat challenge IS a graded conversation with today's woman —
    // no separate engine, just the roleplay screen in task mode tagged
    // to the daily_chat surface so it lands on the right board.
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
                          const SizedBox(height: 26),

                          // The full room stays one tap away — the board,
                          // the week, the pulse, the invite code.
                          if (_squad != null)
                            _RoomLink(
                                name: _squad!.name,
                                onTap: () async {
                                  await context.push('/squad');
                                  if (mounted) _load();
                                })
                          else
                            _RoomLink(
                                name: null,
                                onTap: () async {
                                  await context.push('/squad');
                                  if (mounted) _load();
                                }),
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
            Row(children: [
              Expanded(
                  child: _Stat(
                      value: '${day.form}',
                      label: 'FORM',
                      accent: accent)),
              Expanded(
                  child: _Stat(
                      value: '${day.complete}/${day.possible}',
                      label: 'MOVES',
                      accent: accent)),
              Expanded(
                  child: _Stat(
                      value: '${_roster.length}',
                      label: _roster.length == 1 ? 'MAN' : 'MEN',
                      accent: accent)),
            ]),
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

class _RoomLink extends StatelessWidget {
  final String? name;
  final VoidCallback onTap;
  const _RoomLink({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      accent: name == null ? Colors.white : AppColors.red,
      child: Row(children: [
        Icon(name == null ? Icons.group_add_rounded : Icons.meeting_room_rounded,
            size: 18,
            color: name == null ? AppColors.textSecondary : AppColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              name == null
                  ? 'Start a squad — two men is enough'
                  : 'The room · board, week, pulse',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              )),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textTertiary),
      ]),
    );
  }
}
