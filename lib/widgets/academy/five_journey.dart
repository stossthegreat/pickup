import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';

/// THE FIVE — one journey, not five identical cards.
///
/// Five equal cards said nothing about what the day IS. Rendered as a
/// staged run down a spine, the shape of the day becomes the message:
///
///   TRAIN    01, 02   warm up against AI
///   COMPETE  03       the Rizz-Off — the shared daily event
///   PROVE    04, 05   out in the real world
///
/// The Rizz-Off node is deliberately the largest: it's the one thing
/// the entire world does at the same time on the same woman, and the
/// only thing that moves competitive rank.
///
/// Under every node sits one thin illuminated mark per squadmate, so a
/// glance down the spine tells you who's carrying which stage and where
/// the squad is stalling — enormous information density, no clutter.
class FiveJourney extends StatelessWidget {
  final SquadDay day;
  final Map<String, String> myStates; // missionId → committed|completed
  final void Function(Mission m) onOpenMission;
  final VoidCallback onOpenRizzOff;

  /// Today's woman — the SAME one the Daily serves the whole world.
  /// The squad's voice slot isn't a second challenge; it IS the daily,
  /// and you only get one credit for it, so the node has to show her
  /// face or people reasonably assume they're two different runs.
  final GirlBrief girl;

  const FiveJourney({
    super.key,
    required this.day,
    required this.myStates,
    required this.onOpenMission,
    required this.onOpenRizzOff,
    required this.girl,
  });

  @override
  Widget build(BuildContext context) {
    final board = day.board;
    // 4 missions split around the Rizz-Off. Fewer than 4 (a thin
    // catalog) still renders — the split just shifts.
    final train = board.take(2).toList();
    final prove = board.skip(2).take(2).toList();

    return Column(children: [
      _Stage(label: 'TRAIN', sub: 'Warm up on her'),
      for (final (i, m) in train.indexed)
        _MissionNode(
          index: i + 1,
          mission: m,
          day: day,
          mine: myStates[m.id],
          onTap: () => onOpenMission(m),
        ),
      _Stage(label: 'COMPETE', sub: 'Same woman, one shot, whole world'),
      _RizzOffNode(day: day, girl: girl, onTap: onOpenRizzOff),
      _Stage(label: 'PROVE', sub: 'Off the screen'),
      for (final (i, m) in prove.indexed)
        _MissionNode(
          index: i + 4,
          mission: m,
          day: day,
          mine: myStates[m.id],
          onTap: () => onOpenMission(m),
          last: i == prove.length - 1,
        ),
    ]);
  }
}

/// A stage heading with the spine running through it.
class _Stage extends StatelessWidget {
  final String label, sub;
  const _Stage({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Center(
            child: Container(
                width: 1.5,
                height: 18,
                color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
        Text(label,
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 9.5,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}

/// One illuminated mark per squadmate. Filled = done, ringed = on it,
/// hollow = hasn't moved. No text, no legend needed.
class _Marks extends StatelessWidget {
  final SquadDay day;
  final bool Function(String userId) done;
  final bool Function(String userId)? onIt;
  const _Marks({required this.day, required this.done, this.onIt});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in day.roster) ...[
        Builder(builder: (_) {
          final isDone = done(m.userId);
          final busy = !isDone && (onIt?.call(m.userId) ?? false);
          final mine = m.userId == AuthService.userId;
          return Container(
            width: mine ? 14 : 10,
            height: 3,
            decoration: BoxDecoration(
              color: isDone
                  ? kNeon
                  : busy
                      ? AppColors.red
                      : Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                          color: kNeon.withValues(alpha: 0.55), blurRadius: 6)
                    ]
                  : null,
            ),
          );
        }),
        const SizedBox(width: 4),
      ],
    ]);
  }
}

class _MissionNode extends StatelessWidget {
  final int index;
  final Mission mission;
  final SquadDay day;
  final String? mine;
  final VoidCallback onTap;
  final bool last;

  const _MissionNode({
    required this.index,
    required this.mission,
    required this.day,
    required this.mine,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final pulse = day.squadStates[mission.id];
    final completed = mine == 'completed';
    final committed = mine == 'committed';
    final accent = completed
        ? kNeon
        : committed
            ? AppColors.red
            : AppColors.textTertiary;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── The spine ────────────────────────────────────────────
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(
                width: 1.5,
                height: 10,
                color: Colors.white.withValues(alpha: 0.10)),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? kNeon.withValues(alpha: 0.18)
                    : AppColors.base,
                border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.6),
              ),
              alignment: Alignment.center,
              child: completed
                  ? const Icon(Icons.check_rounded, size: 13, color: kNeon)
                  : Text('$index',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      )),
            ),
            Expanded(
              child: Container(
                  width: 1.5,
                  color: last
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.10)),
            ),
          ]),
        ),
        // ── The node ─────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: committed
                        ? AppColors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(mission.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13.5,
                            letterSpacing: -0.2,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                    if (committed)
                      Text('CALLED IT',
                          style: GoogleFonts.inter(
                            color: AppColors.red,
                            fontSize: 8.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                          )),
                  ]),
                  const SizedBox(height: 7),
                  _Marks(
                    day: day,
                    done: (u) => pulse?.completed.contains(u) ?? false,
                    onIt: (u) => pulse?.committed.contains(u) ?? false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The jewel node — bigger, brighter, and the only one that scores.
class _RizzOffNode extends StatelessWidget {
  final SquadDay day;
  final GirlBrief girl;
  final VoidCallback onTap;
  const _RizzOffNode({
    required this.day,
    required this.girl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mine = AuthService.userId == null
        ? null
        : day.dailyFor(AuthService.userId!);
    final took = mine?.finished ?? false;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(
                width: 1.5,
                height: 10,
                color: Colors.white.withValues(alpha: 0.10)),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.red.withValues(alpha: 0.18),
                border: Border.all(color: AppColors.red, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.45),
                      blurRadius: 16)
                ],
              ),
              alignment: Alignment.center,
              child: took
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : const Icon(Icons.graphic_eq_rounded,
                      size: 14, color: Colors.white),
            )
                .animate(
                    onPlay: (c) => took ? null : c.repeat(reverse: true),
                    target: took ? 0 : 1)
                .scaleXY(begin: 1, end: 1.08, duration: 1200.ms),
            Expanded(
              child: Container(
                  width: 1.5, color: Colors.white.withValues(alpha: 0.10)),
            ),
          ]),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.red.withValues(alpha: 0.22),
                    AppColors.surface1,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.55)),
                boxShadow: const [
                  BoxShadow(color: AppColors.redGlow, blurRadius: 20)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // HER. Same face as the Daily, because it is the
                    // Daily — one woman, one credit, one attempt.
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.75),
                            width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: AppColors.redGlow, blurRadius: 12)
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11.5),
                        child: Image.asset(girl.asset,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.3),
                            errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surface2,
                                child: const Icon(Icons.person_rounded,
                                    size: 20, color: AppColors.red))),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DAILY RIZZ-OFF',
                              style: GoogleFonts.inter(
                                color: AppColors.red,
                                fontSize: 9,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 2),
                          Text(girl.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.05,
                                letterSpacing: -0.6,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                    Text(took ? voiceScoreOf(mine) : 'ONE SHOT',
                        style: GoogleFonts.inter(
                          color: AppColors.red,
                          fontSize: took ? 18 : 9,
                          letterSpacing: took ? -0.5 : 1.6,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
                  const SizedBox(height: 9),
                  Text(
                      took
                          ? 'Done for today. She changes at reset.'
                          : 'Your one voice credit today — same woman as '
                              'the Daily.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 9),
                  // Locked marks: nobody's score shows until you've taken
                  // yours, so you can't scout before you swing.
                  Row(children: [
                    _Marks(
                      day: day,
                      done: (u) => day.dailyFor(u)?.finished ?? false,
                    ),
                    const Spacer(),
                    if (!took)
                      Text('SCORES HIDDEN UNTIL YOU RUN IT',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 8,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Score out of 10 — see voiceOutOfTen in your_five.dart for why.
String voiceScoreOf(dynamic mark) {
  final s = mark?.score as int?;
  if (s == null) return '—';
  return '${Economy.aiScoreFromVoice(s)}';
}
