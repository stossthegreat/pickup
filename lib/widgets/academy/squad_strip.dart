import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../theme/app_colors.dart';

/// THE SQUAD STRIP — the liveness engine, mounted at the top of home.
///
/// The lesson from every app that owns daily habits: the social state
/// lives on the FIRST screen, not behind a tab. Strava puts friends'
/// runs in your feed; Duolingo puts the league on the path; BeReal puts
/// everyone's status on open. So the squad lives here — every open of
/// the app answers "where is everyone at?" without a single tap:
///
///   · member faces with live status rings (done / committed / silent)
///   · SQUAD PTS for the week
///   · the latest Pulse line ("MARCUS called his shot · 14:32")
///
/// No squad → the recruiting card with create/join one tap away.
/// Offline / backend down → renders nothing (zero clutter, fail-soft).
class SquadStrip extends StatefulWidget {
  const SquadStrip({super.key});

  @override
  State<SquadStrip> createState() => _SquadStripState();
}

class _SquadStripState extends State<SquadStrip> {
  // ignore: unused_field
  bool _loaded = false;
  Squad? _squad;
  List<SquadMember> _roster = const [];
  List<WeekMark> _marks = const [];
  SquadEvent? _latest;
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
      setState(() {
        _squad = null;
        _loaded = true;
      });
      return;
    }
    final roster = await SquadService.roster(squad.id);
    final results = await Future.wait([
      SquadService.weekMarks([for (final m in roster) m.userId]),
      SquadService.pulse(squad.id, limit: 1),
    ]);
    if (!mounted) return;
    _pulse ??= SquadService.watchPulse(squad.id, () {
      if (mounted) _load(); // a new event repaints the strip live
    });
    setState(() {
      _squad = squad;
      _roster = roster;
      _marks = results[0] as List<WeekMark>;
      final events = results[1] as List<SquadEvent>;
      _latest = events.isEmpty ? null : events.first;
      _loaded = true;
    });
  }

  /// done > committed > silent, for TODAY only.
  String _statusToday(String userId) {
    var status = 'silent';
    final now = DateTime.now();
    for (final m in _marks) {
      if (m.userId != userId) continue;
      if (m.day.year == now.year &&
          m.day.month == now.month &&
          m.day.day == now.day) {
        if (m.completed) return 'done';
        status = 'committed';
      }
    }
    return status;
  }

  String _pulseLine(SquadEvent e) {
    String who = 'SOMEONE';
    for (final m in _roster) {
      if (m.userId == e.actorId) {
        who = m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');
      }
    }
    final what = switch (e.kind) {
      'joined' => 'joined the squad',
      'committed' => 'called their shot',
      'completed' => 'completed ${e.payload['mission'] ?? 'the mission'}',
      'scored' => 'scored ${e.payload['score'] ?? ''}',
      'rankup' => 'ranked up',
      _ => 'made a move',
    };
    final t = e.createdAt;
    return '$who $what · '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Even before the backend answers, show the recruiting card — an
    // empty gap on home is what made the app feel dead.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: _squad == null ? _recruit(context) : _live(context),
    );
  }

  // ── No squad — the recruiting card ─────────────────────────────────
  Widget _recruit(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/squad');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
          boxShadow: const [
            BoxShadow(color: AppColors.redGlow, blurRadius: 24),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.shield_outlined, size: 26, color: AppColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GET IN A SQUAD',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text('Train alone and you\'ll quit alone. Create one or '
                    'enter a code.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 22, color: AppColors.textTertiary),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Squad — the live strip ─────────────────────────────────────────
  Widget _live(BuildContext context) {
    final done = _marks.where((m) => m.completed).length;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/squad');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_squad!.name.toUpperCase(),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                )),
            const Spacer(),
            Text('${done * 100} PTS',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w900,
                )),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ]),
          const SizedBox(height: 10),
          // Faces with live status rings — where is everyone at, today.
          Row(children: [
            for (final m in _roster.take(8)) ...[
              _face(m),
              const SizedBox(width: 8),
            ],
          ]),
          if (_latest != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.red, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.3, end: 1, duration: 900.ms),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_pulseLine(_latest!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ]),
          ],
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _face(SquadMember m) {
    final status = _statusToday(m.userId);
    final ring = switch (status) {
      'done' => AppColors.red,
      'committed' => AppColors.red.withValues(alpha: 0.55),
      _ => Colors.white.withValues(alpha: 0.14),
    };
    final mine = m.userId == AuthService.userId;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface2,
            border: Border.all(
                color: ring, width: status == 'silent' ? 1.2 : 2),
            image: m.avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(m.avatarUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: m.avatarUrl == null
              ? Center(
                  child: Text(
                    (mine ? 'YOU' : (m.handle ?? 'A'))
                        .characters
                        .first
                        .toUpperCase(),
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
        ),
        if (status == 'done')
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface1, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 9, color: Colors.white),
            ),
          ),
      ]),
    ]);
  }
}
