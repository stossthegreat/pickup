import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/daily_game_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'league_crest.dart';

/// Today's opponent, resolved from the daily scenario key.
GirlBrief girlForVibe(String vibeKey) => kRoster.firstWhere(
      (g) => g.vibeKey == vibeKey,
      orElse: () => kRoster.first,
    );

/// THE DAILY — the hero card on home. Her face, full bleed. Her name in
/// display type. The division crest riding the corner. One chunky
/// button. This is the appointment, and it should look like a fight
/// poster, not a list row.
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
      if (mounted) setState(() {});
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

  Future<void> _open() async {
    HapticFeedback.mediumImpact();
    await context.push('/daily');
    _load();
  }

  String _lock(DateTime at) {
    final d = at.difference(DateTime.now().toUtc());
    if (d.isNegative) return 'LOCKED';
    if (d.inDays > 0) return '${d.inDays}D ${d.inHours % 24}H';
    if (d.inHours > 0) return '${d.inHours}H ${d.inMinutes % 60}M';
    return '${d.inMinutes}M';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _s == null) return const SizedBox.shrink();
    final s = _s!;
    final girl = girlForVibe(s.scenarioKey);
    final l = s.league;
    final zone = switch (l.zone) {
      'promotion' => kNeon,
      'drop' => AppColors.red,
      _ => AppColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: GestureDetector(
        onTap: _open,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: s.attempted
                    ? Colors.white.withValues(alpha: 0.08)
                    : girl.accent.withValues(alpha: 0.55),
                width: 1.4),
            boxShadow: s.attempted
                ? null
                : [
                    BoxShadow(
                        color: girl.accent.withValues(alpha: 0.28),
                        blurRadius: 34,
                        spreadRadius: -4)
                  ],
          ),
          child: Stack(children: [
            // ── HER FACE, full bleed ──────────────────────────────
            Positioned.fill(
              child: Image.asset(
                girl.asset,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.32),
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        girl.accent.withValues(alpha: 0.35),
                        AppColors.surface1,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Scrim — legibility without hiding her.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
            if (s.attempted)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),

            // ── Content ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: girl.accent,
                                    shape: BoxShape.circle),
                              )
                                  .animate(
                                      onPlay: (c) => c.repeat(reverse: true))
                                  .fade(begin: 0.25, end: 1, duration: 850.ms),
                              const SizedBox(width: 7),
                              Text('THE DAILY',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w900,
                                  )),
                            ]),
                            const SizedBox(height: 10),
                            Text(girl.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 40,
                                  height: 0.98,
                                  letterSpacing: -1.6,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        blurRadius: 14)
                                  ],
                                )),
                            const SizedBox(height: 2),
                            Text(girl.type,
                                style: GoogleFonts.inter(
                                  color: girl.accent,
                                  fontSize: 11.5,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w800,
                                )),
                          ],
                        ),
                      ),
                      // The crest — the thing they're climbing toward.
                      Column(children: [
                        LeagueCrest(division: l.division, size: 52),
                        const SizedBox(height: 4),
                        Text('#${l.rank}',
                            style: GoogleFonts.inter(
                              color: zone,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            )),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (s.attempted) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      CountUp(
                        value: s.myScore ?? 0,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            s.worldAvg == null
                                ? 'SHOT TAKEN'
                                : 'WORLD AVG ${s.worldAvg}',
                            style: GoogleFonts.inter(
                              color: (s.myScore ?? 0) >= (s.worldAvg ?? 0)
                                  ? kNeon
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                      const Spacer(),
                      Text('NEXT DROP AT RESET',
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 9.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                  ] else
                    GameButton(
                      label: 'ONE SHOT — RUN IT',
                      color: girl.accent,
                      pulse: true,
                      onTap: _open,
                    ),

                  const SizedBox(height: 14),
                  // League ribbon — the permanent tension line.
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: zone, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                          '${l.divisionName} · ${l.points} PTS'
                          '${l.zone == 'drop' ? ' · DROP ZONE' : l.zone == 'promotion' ? ' · PROMOTION' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: zone,
                            fontSize: 10.5,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    Icon(Icons.lock_clock_rounded,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(_lock(l.locksAt),
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        )),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.05, end: 0),
    );
  }
}
