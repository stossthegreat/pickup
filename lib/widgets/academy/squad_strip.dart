import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_service.dart';
import '../../theme/app_colors.dart';

/// THE SQUAD STRIP — the liveness engine, at the top of home.
///
/// The social state belongs on the FIRST screen, not behind a tab. But
/// this used to be a mini dashboard — grade disc, name, points, member
/// faces, pulse line — five things competing for attention on the screen
/// people look at most.
///
/// It's now ONE component that changes its REASON through the day.
/// Morning: the day is live. Afternoon: who's taken their shot. Evening:
/// what's left to save it. Done: you won. Same pixels, a different pull
/// each time you glance at it — far more sophisticated than more icons.
class SquadStrip extends StatefulWidget {
  const SquadStrip({super.key});

  @override
  State<SquadStrip> createState() => _SquadStripState();
}

class _SquadStripState extends State<SquadStrip> {
  Squad? _squad;
  List<SquadMember> _roster = const [];
  List<Mission> _board = const [];
  Map<String, MissionPulse> _squadStates = const {};
  List<DailyMark> _daily = const [];
  RealtimeChannel? _pulse;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_pulse != null) SquadService.unwatch(_pulse!);
    super.dispose();
  }

  Future<void> _load() async {
    final squad = await SquadService.mySquad();
    if (!mounted) return;
    if (squad == null) {
      setState(() => _squad = null);
      return;
    }
    final roster = await SquadService.roster(squad.id);
    final ids = [for (final m in roster) m.userId];
    final results = await Future.wait([
      MissionService.todayBoard(count: SquadDay.missionsPerDay),
      SquadService.missionPulseToday(ids),
      SquadService.dailyToday(ids, squadId: squad.id),
    ]);
    if (!mounted) return;
    // A squadmate's move repaints the number on your home screen while
    // you're looking at it. That's the whole trick.
    _pulse ??= SquadService.watchPulse(squad.id, () {
      if (mounted) _load();
    });
    setState(() {
      _squad = squad;
      _roster = roster;
      _board = results[0] as List<Mission>;
      _squadStates = results[1] as Map<String, MissionPulse>;
      _daily = results[2] as List<DailyMark>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: _squad == null ? _recruit(context) : _line(context),
    );
  }

  // ── No squad — one quiet line, not a red slab ──────────────────────
  Widget _recruit(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/squad');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(children: [
            const Icon(Icons.shield_outlined,
                size: 17, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Start a squad — you only need one mate.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _line(BuildContext context) {
    final day = SquadDay(
      roster: _roster,
      board: _board,
      squadStates: _squadStates,
      daily: _daily,
    );
    final won = day.won;
    final accent = won ? AppColors.signalGreen : AppColors.red;

    // The line is chosen by where the day actually is — this is the
    // whole component.
    final String line;
    if (!day.live) {
      line = 'One more man and the day starts scoring';
    } else if (won) {
      line = 'Day won — ${day.complete}/${day.possible} moves';
    } else if (day.complete == 0) {
      line = 'The five are live — nobody has moved yet';
    } else if (day.remaining <= 2) {
      line = day.remaining == 1
          ? '1 move to save the day'
          : '${day.remaining} moves to save the day';
    } else {
      final took = day.daily.where((d) => d.finished).length;
      line = took > 0
          ? '$took/${_roster.length} have taken their shot'
          : '${day.complete}/${day.possible} moves in';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/squad');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          // Form is the one stat worth carrying to the home screen.
          SizedBox(
            width: 42,
            child: Column(children: [
              Text('${day.form}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w900,
                  )),
              Text('FORM',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 7.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 30,
              color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_squad!.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text(line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
