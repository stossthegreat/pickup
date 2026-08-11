import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/squad_day.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE BEAT — the daily pulse the whole product runs on.
///
/// This is the mechanism, not decoration. Nobody gets better at talking
/// to people by reading about it; they get better by doing reps, and
/// reps only happen if something makes today matter more than tomorrow.
/// A day that resets is that something. Miss it and it's gone — you
/// can't grind five missions on Sunday to cover the week.
///
/// So the reset is made visible and physical: a bar that drains, a
/// countdown that shortens, and a dot that literally beats. Late in the
/// day with moves outstanding it beats faster. When the squad wins, it
/// stops and holds — the day is closed, rest.
///
/// Everything resets on the UTC day boundary, the same one THE DAILY
/// uses, so the whole world's board turns over at the same instant and
/// nobody gets a timezone advantage.
class DayBeat extends StatefulWidget {
  final SquadDay? day;

  /// Solo users get the beat too — the reps matter whether or not
  /// anyone's watching. Squad state just gives the line more to say.
  const DayBeat({super.key, this.day});

  @override
  State<DayBeat> createState() => _DayBeatState();
}

class _DayBeatState extends State<DayBeat> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // One repaint a minute is enough for a countdown in hours+minutes.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tick?.cancel();
    super.dispose();
  }

  Duration get _untilReset {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day)
        .add(const Duration(days: 1))
        .difference(now);
  }

  /// 0 at reset, 1 the instant before the next one.
  double get _elapsed {
    final left = _untilReset.inSeconds / 86400;
    return (1 - left).clamp(0.0, 1.0);
  }

  String get _phase {
    final h = DateTime.now().hour;
    if (h < 12) return 'MORNING';
    if (h < 17) return 'AFTERNOON';
    if (h < 21) return 'EVENING';
    return 'LAST CALL';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final won = d?.won ?? false;
    final left = _untilReset;
    final elapsed = _elapsed;

    // The beat quickens as the day runs out with work outstanding.
    // Urgency you can feel before you've read a word.
    final urgent = !won && elapsed > 0.7 && (d?.remaining ?? 1) > 0;
    _pulse.duration =
        Duration(milliseconds: won ? 2600 : (urgent ? 620 : 1400));

    final accent = won
        ? kNeon
        : urgent
            ? AppColors.red
            : AppColors.textTertiary;

    // Plain if/else rather than a switch: Dart doesn't promote a
    // nullable across switch arms, so `d.live` after `_ when d == null`
    // wouldn't compile.
    final String line;
    if (d == null) {
      line = 'Five moves. Every day. That\'s the whole game.';
    } else if (won) {
      line = 'Day closed. Rest — it starts again at reset.';
    } else if (!d.live) {
      line = 'One more man and the day starts scoring.';
    } else if (d.remaining == 1) {
      line = 'One move saves the day.';
    } else if (urgent) {
      line = '${d.remaining} moves left. Clock\'s going.';
    } else if (d.complete == 0) {
      line = 'Nobody has moved yet today.';
    } else {
      line = '${d.complete} of ${d.possible} moves banked.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        Row(children: [
          // The beating dot.
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              // Two quick beats then rest — a heartbeat, not a blink.
              final t = _pulse.value;
              final b = math.max(
                math.exp(-18 * t) * math.sin(t * math.pi * 5).abs(),
                math.exp(-18 * (t - 0.22).abs()) * 0.7,
              );
              return Container(
                width: 8 + b * 4,
                height: 8 + b * 4,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.25 + b * 0.55),
                        blurRadius: 6 + b * 12),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(won ? 'DAY WON' : _phase,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 9.5,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text(
              won
                  ? 'NEXT IN ${_fmt(left)}'
                  : 'RESETS IN ${_fmt(left)}',
              style: GoogleFonts.inter(
                color: urgent ? AppColors.red : AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 10),
        // The bar drains left-to-right across the day.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(
                height: 4, color: Colors.white.withValues(alpha: 0.06)),
            FractionallySizedBox(
              widthFactor: elapsed,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent.withValues(alpha: 0.25),
                    accent,
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
            child: Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
      ]),
    );
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}H ${m.toString().padLeft(2, '0')}M' : '${m}M';
  }
}
