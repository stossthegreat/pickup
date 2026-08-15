import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/daily_game_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Today's opponent, resolved from the daily scenario key.
GirlBrief girlForVibe(String vibeKey) => kRoster.firstWhere(
      (g) => g.vibeKey == vibeKey,
      orElse: () => kRoster.first,
    );

/// The daily rotation, computed client-side with the SAME rule the
/// server uses, so the card renders today's real woman before (or
/// without) a backend answer.
const kDailyScenarios = [
  'cold',
  'into_you',
  'chaos',
  'testing',
  'ice_then_fire',
  'sweet',
];

String scenarioOfToday() {
  final epochDay = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
  return kDailyScenarios[epochDay % kDailyScenarios.length];
}

/// THE DAILY — built in the app's own mission-card shape: portrait
/// thumb, pill row, title, action. It sits ABOVE the missions as the
/// first card of the day, not as a billboard on top of them.
class DailyCard extends StatefulWidget {
  const DailyCard({super.key});

  @override
  State<DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<DailyCard> {
  DailyStatus? _s;
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
    setState(() => _s = s);
  }

  Future<void> _open() async {
    HapticFeedback.selectionClick();
    await context.push('/daily');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final girl = girlForVibe(s?.scenarioKey ?? scenarioOfToday());
    final done = s?.attempted == true;
    final accent = done ? AppColors.signalGreen : AppColors.red;

    // No padding of its own. The home stack owns the gutter and the
    // rhythm for all three top cards — when each card carried its own,
    // they drifted to three different insets and two of them ended up
    // 2px apart.
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(Rd.xl),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surface2, AppColors.surface1],
              ),
              borderRadius: BorderRadius.circular(Rd.xl),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
                if (!done)
                  BoxShadow(
                      color: accent.withValues(alpha: 0.16), blurRadius: 22),
              ],
            ),
            padding: const EdgeInsets.all(Sp.md),
            child: Row(children: [
              // Her portrait — same 62pt thumb as every mission card.
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Rd.lg),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.25), blurRadius: 10)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Rd.lg - 2),
                  child: Image.asset(girl.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surface3,
                          child: Icon(Icons.person_rounded, color: accent))),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pill row, exactly like the missions.
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(Rd.sm),
                        ),
                        child: Text('THE DAILY',
                            style: AppTypography.label.copyWith(
                                color: accent,
                                fontSize: 8.5,
                                letterSpacing: 1.4)),
                      ),
                      const SizedBox(width: 6),
                      if (s?.league != null) ...[
                        Icon(Icons.shield_moon_rounded,
                            size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Text('#${s!.league.rank}',
                            style: AppTypography.label.copyWith(
                                color: AppColors.textTertiary, fontSize: 9)),
                      ] else
                        Text('ONE SHOT',
                            style: AppTypography.label.copyWith(
                                color: AppColors.textTertiary, fontSize: 9)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      done ? '${s!.myScore}' : girl.name,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        height: 1.1,
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'Scored. New woman at reset.'
                          : '${girl.type} — one attempt, same for everyone.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text(done ? 'SEE THE BOARD' : 'RUN IT',
                          style: AppTypography.label.copyWith(
                              color: accent,
                              fontSize: 10,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: accent),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      )
        .animate(
            onPlay: (c) => done ? null : c.repeat(reverse: true),
            target: done ? 0 : 1)
        .fadeIn(duration: 300.ms);
  }
}
