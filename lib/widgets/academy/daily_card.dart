import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/daily_game_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE DAILY card on home — the appointment, impossible to miss.
/// Not attempted → pulsing red gradient: "SHE'S COLD. ONE SHOT."
/// Attempted     → your score + world rank, calm state.
/// Under both: the league line — division · rank · zone · lock clock.
/// Offline / backend down → renders nothing (fail-soft).
class DailyCard extends StatefulWidget {
  const DailyCard({super.key});

  @override
  State<DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<DailyCard> {
  DailyStatus? _s;
  bool _loaded = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {}); // keep the lock clock honest
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DailyGameService.status();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loaded = true;
    });
  }

  String _lockLabel(DateTime locksAt) {
    final d = locksAt.difference(DateTime.now().toUtc());
    if (d.isNegative) return 'LOCKED';
    if (d.inDays > 0) return 'LOCKS ${d.inDays}D ${d.inHours % 24}H';
    if (d.inHours > 0) return 'LOCKS ${d.inHours}H ${d.inMinutes % 60}M';
    return 'LOCKS ${d.inMinutes}M';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _s == null) return const SizedBox.shrink();
    final s = _s!;
    final label = s.scenarioKey.replaceAll('_', ' ').toUpperCase();
    final l = s.league;
    final zoneColor = switch (l.zone) {
      'promotion' => kNeon,
      'drop' => AppColors.red,
      _ => AppColors.textSecondary,
    };

    Widget card = GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await context.push('/daily');
        _load();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: s.attempted
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.red.withValues(alpha: 0.28),
                    AppColors.surface1,
                  ],
                ),
          color: s.attempted ? AppColors.surface1 : null,
          border: Border.all(
              color: s.attempted
                  ? Colors.white.withValues(alpha: 0.07)
                  : AppColors.red.withValues(alpha: 0.6)),
          boxShadow: s.attempted
              ? null
              : const [BoxShadow(color: AppColors.redGlow, blurRadius: 26)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('THE DAILY',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 10,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w900,
                )),
            const Spacer(),
            if (s.attempted && s.myScore != null)
              Text('${s.myScore}',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ))
            else
              Text('ONE SHOT',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ]),
          const SizedBox(height: 4),
          Text(
              s.attempted
                  ? 'Shot taken. New scenario at reset.'
                  : 'SHE\'S $label. The whole world gets one attempt.',
              style: GoogleFonts.inter(
                color: s.attempted
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                fontSize: s.attempted ? 11.5 : 14,
                fontWeight:
                    s.attempted ? FontWeight.w500 : FontWeight.w800,
              )),
          const SizedBox(height: 10),
          // The league line — always on, the tension is permanent.
          Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: zoneColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                  '${l.divisionName} · #${l.rank} OF ${l.size}'
                  '${l.zone == 'drop' ? ' · DROP ZONE' : l.zone == 'promotion' ? ' · PROMOTION' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: zoneColor,
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  )),
            ),
            Text(_lockLabel(l.locksAt),
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ]),
      ),
    );

    if (!s.attempted) {
      card = card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.012, duration: 1100.ms);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: card.animate().fadeIn(duration: 300.ms),
    );
  }
}
