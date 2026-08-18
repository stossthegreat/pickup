import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// TODAY'S BOARD — one grid that answers "what has everyone actually
/// done today?" without a single tap.
///
/// The squad room used to make you infer this. The week grid showed
/// squares but not WHICH mission; the mission cards showed a count but
/// not WHO; the AI run was a separate card. Three places, none of them
/// the whole picture — so nobody could see what their mates had done.
///
/// This is the whole picture: one row per squadmate, one column per
/// mission (the same five for everyone, every day), plus a final column
/// for the voice Daily carrying the actual SCORE. Read across a row to
/// see one man's day; read down a column to see who's carrying a
/// mission and who's ducking it.
class TodayBoard extends StatelessWidget {
  final List<SquadMember> roster;
  final List<Mission> board;
  final Map<String, MissionPulse> squadStates;
  final List<DailyMark> daily;

  const TodayBoard({
    super.key,
    required this.roster,
    required this.board,
    required this.squadStates,
    required this.daily,
  });

  DailyMark? _dailyFor(String userId) {
    for (final d in daily) {
      if (d.userId == userId) return d;
    }
    return null;
  }

  String _nameOf(SquadMember m) =>
      m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');

  /// Missions done today across the whole squad, over the possible max.
  (int, int) get _tally {
    var done = 0;
    for (final m in board) {
      done += squadStates[m.id]?.completed.length ?? 0;
    }
    return (done, board.length * roster.length);
  }

  @override
  Widget build(BuildContext context) {
    final (done, possible) = _tally;
    final ran = daily.where((d) => d.finished).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        // ── Header: the two numbers that matter ──────────────────────
        Row(children: [
          Text('TODAY',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          _Stat(label: 'MISSIONS', value: '$done/$possible',
              color: done > 0 ? kNeon : AppColors.textMuted),
          const SizedBox(width: 14),
          _Stat(label: 'VOICE RUN', value: '$ran/${roster.length}',
              color: ran > 0 ? AppColors.red : AppColors.textMuted),
        ]),
        const SizedBox(height: 12),

        // ── Column headers: M1..M5 then the voice Daily ──────────────
        Row(children: [
          const SizedBox(width: 78),
          for (var i = 0; i < board.length; i++)
            Expanded(
              child: Center(
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
          SizedBox(
            width: 46,
            child: Center(
              child: Icon(Icons.graphic_eq_rounded,
                  size: 13, color: AppColors.red.withValues(alpha: 0.8)),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // ── One row per man ──────────────────────────────────────────
        for (final (i, m) in roster.indexed) ...[
          _row(context, m),
          if (i != roster.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Container(height: 1, color: AppColors.divider),
            ),
        ],

        if (roster.length < 2) ...[
          const SizedBox(height: 12),
          Text(
              'A squad of one is just you. Send your code — the board '
              'fills up the moment someone joins.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              )),
        ],
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }

  Widget _row(BuildContext context, SquadMember m) {
    final mine = m.userId == AuthService.userId;
    final d = _dailyFor(m.userId);
    var mineDone = 0;
    for (final mission in board) {
      if (squadStates[mission.id]?.completed.contains(m.userId) ?? false) {
        mineDone++;
      }
    }

    return Row(children: [
      // Name + personal tally
      SizedBox(
        width: 78,
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface2,
              border: Border.all(
                  color: mine ? AppColors.red : Colors.white24, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(_nameOf(m).characters.first.toUpperCase(),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nameOf(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: mine ? AppColors.red : AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    )),
                Text('$mineDone/${board.length}',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ]),
      ),

      // One cell per mission
      for (final mission in board)
        Expanded(
          child: Center(
            child: _cell(context, m, mission),
          ),
        ),

      // The voice Daily — the only cell that carries a NUMBER, because
      // it's the only thing that's scored.
      SizedBox(
        width: 46,
        child: Center(child: _dailyCell(d)),
      ),
    ]);
  }

  Widget _cell(BuildContext context, SquadMember m, Mission mission) {
    final pulse = squadStates[mission.id];
    final done = pulse?.completed.contains(m.userId) ?? false;
    final onIt = pulse?.committed.contains(m.userId) ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${_nameOf(m)} · ${mission.title} — '
              '${done ? "done" : onIt ? "called their shot" : "not yet"}',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.toastBg,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ));
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: done ? kNeon.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: done
                ? kNeon
                : onIt
                    ? AppColors.red
                    : Colors.white.withValues(alpha: 0.10),
            width: done || onIt ? 1.7 : 1,
          ),
          boxShadow: done
              ? [BoxShadow(color: kNeon.withValues(alpha: 0.4), blurRadius: 9)]
              : null,
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 14, color: kNeon)
            : onIt
                ? const Icon(Icons.more_horiz_rounded,
                    size: 13, color: AppColors.red)
                : null,
      ),
    );
  }

  Widget _dailyCell(DailyMark? d) {
    if (d == null) {
      return Container(
        width: 34,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: Text('—',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            )),
      );
    }
    if (!d.finished) {
      // Opened it and walked. The squad should see that.
      return Container(
        width: 34,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.7)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close_rounded, size: 13, color: AppColors.red),
      );
    }
    return Container(
      width: 34,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.red),
        boxShadow: [
          BoxShadow(color: AppColors.red.withValues(alpha: 0.35), blurRadius: 9)
        ],
      ),
      alignment: Alignment.center,
      child: Text('${d.score ?? 0}',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 8,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }
}
