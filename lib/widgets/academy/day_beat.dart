import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/squad_day.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE BEAT — the daily pulse the whole product runs on.
///
/// This is the mechanism, not decoration. Nobody gets better at talking
/// to people by reading about it; they get better by doing reps, and
/// reps only happen if something makes today matter more than tomorrow.
/// A day that resets is that something.
///
/// The first version was a countdown over a bar that filled with ELAPSED
/// TIME. At 00:14 that bar is a 1%-full grey line and the whole component
/// says nothing you didn't already know — the clock is on your phone.
/// It measured the day instead of measuring YOU.
///
/// It now measures both, and the tension between them is the point:
///
///   · one SEGMENT per move you owe today, filling as you bank them
///   · a PACE MARKER riding across that track at the speed of the day
///
/// If your fills are past the marker you're ahead of the clock. If the
/// marker is out in front of you, the day is getting away — and you can
/// see that in a glance, before you've read a word. A bar that only knew
/// what time it was could never do that.
///
/// Everything resets on the UTC day boundary, the same one THE DAILY
/// uses, so the whole world's board turns over at the same instant and
/// nobody gets a timezone advantage.
class DayBeat extends StatefulWidget {
  /// Squad state, when there is one. The squad's day is the whole
  /// roster's moves; solo, it's your own five.
  final SquadDay? day;

  /// Solo counts — how many of today's moves are banked, out of how many
  /// were offered. Ignored when [day] is supplied.
  final int done;
  final int total;

  const DayBeat({super.key, this.day, this.done = 0, this.total = 5});

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
    // One repaint every 30s is enough for a countdown in hours+minutes
    // and keeps the pace marker visibly creeping.
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
    final total = d != null ? d.possible : widget.total;
    final done = d != null ? d.complete : widget.done;
    final won = d != null ? d.won : (total > 0 && done >= total);
    final left = _untilReset;
    final elapsed = _elapsed;

    // Where you SHOULD be by now if you were pacing the day evenly.
    final pace = total == 0 ? 0.0 : done / total;
    final behind = !won && pace < elapsed - 0.08;

    // The beat quickens as the day runs out with work outstanding.
    // Urgency you can feel before you've read a word.
    final outstanding = d != null ? d.remaining > 0 : done < total;
    final urgent = !won && elapsed > 0.7 && outstanding;
    _pulse.duration =
        Duration(milliseconds: won ? 2600 : (urgent ? 620 : 1400));

    final accent = won
        ? kNeon
        : urgent || behind
            ? AppColors.red
            : AppColors.accent;

    // Plain if/else rather than a switch: Dart doesn't promote a
    // nullable across switch arms, so `d.live` after `_ when d == null`
    // wouldn't compile.
    final String line;
    if (d == null) {
      if (won) {
        line = 'All $total banked. Day closed — rest.';
      } else if (done == 0 && elapsed < 0.35) {
        line = '$total moves. Every day. That\'s the whole game.';
      } else if (done == 0) {
        line = 'Nothing banked yet and the day\'s half gone.';
      } else if (total - done == 1) {
        line = 'One move off a clean day.';
      } else if (behind) {
        line = '$done of $total — the clock\'s ahead of you.';
      } else {
        line = '$done of $total banked — ahead of the clock.';
      }
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
    } else if (behind) {
      line = '$done of $total — the clock\'s ahead of the squad.';
    } else {
      line = '$done of $total moves banked.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: 0.07), AppColors.surface2),
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8)),
          if (won || urgent)
            BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 24),
        ],
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
          // The score of the day, big enough to be the headline it is.
          Text('$done',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 17,
                height: 1,
                letterSpacing: -0.8,
                fontWeight: FontWeight.w900,
              )),
          Text('/$total',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 10),
          Container(width: 1, height: 13, color: AppColors.surface3),
          const SizedBox(width: 10),
          Text(_fmt(left),
              style: GoogleFonts.inter(
                color: urgent ? AppColors.red : AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 13),

        // ── THE TRACK — your moves, and the day racing them ──────────
        _Track(done: done, total: total, elapsed: elapsed, accent: accent),

        const SizedBox(height: 11),
        Row(children: [
          Expanded(
            child: Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: behind ? AppColors.red : AppColors.textSecondary,
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

// ══════════════════════════════════════════════════════════════════════
//  THE TRACK
// ══════════════════════════════════════════════════════════════════════

/// One segment per move, plus the pace marker riding across them at the
/// speed of the day. Above ten moves (a big squad) the segments would be
/// slivers, so it falls back to one continuous bar — same marker, same
/// meaning.
class _Track extends StatelessWidget {
  final int done, total;
  final double elapsed;
  final Color accent;
  const _Track({
    required this.done,
    required this.total,
    required this.elapsed,
    required this.accent,
  });

  static const _h = 11.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      // A degenerate zero-width pass would make the marker's clamp range
      // invalid (lower > upper), which asserts in debug.
      final w = c.maxWidth.isFinite ? c.maxWidth : 0.0;
      final markerMax = w > 2 ? w - 2 : 0.0;
      final segmented = total > 0 && total <= 10;

      return SizedBox(
        height: _h + 9,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: segmented ? _segments() : _bar(),
          ),
          // THE PACE MARKER. It is the day itself, moving. Fills behind
          // it are moves you banked on time; empty track behind it is
          // time you've already spent.
          Positioned(
            left: (w * elapsed).clamp(0.0, markerMax),
            top: 0,
            child: _Marker(hot: accent == AppColors.red),
          ),
        ]),
      );
    });
  }

  Widget _segments() {
    return Row(children: [
      for (var i = 0; i < total; i++) ...[
        Expanded(child: _seg(i)),
        if (i != total - 1) const SizedBox(width: 5),
      ],
    ]);
  }

  Widget _seg(int i) {
    final filled = i < done;
    final next = i == done;
    final seg = Container(
      height: _h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.28), accent),
                  accent,
                ],
              )
            : null,
        color: filled ? null : Colors.white.withValues(alpha: 0.05),
        border: next
            ? Border.all(color: accent.withValues(alpha: 0.55), width: 1.2)
            : null,
        boxShadow: filled
            ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 9)]
            : null,
      ),
    );
    // The next one up breathes. Everything else holds still — one moving
    // thing on a screen is a pointer, five is noise.
    if (!next) return seg;
    return seg
        .animate(onPlay: (a) => a.repeat(reverse: true))
        .fadeIn(duration: 900.ms, begin: 0.45);
  }

  Widget _bar() {
    final frac = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(children: [
        Container(height: _h, color: Colors.white.withValues(alpha: 0.05)),
        FractionallySizedBox(
          widthFactor: frac,
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accent.withValues(alpha: 0.55),
                accent,
              ]),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 9)
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// The day, as an object on the track. A hairline with a cap, so it
/// reads as a measuring instrument rather than another bar.
class _Marker extends StatelessWidget {
  final bool hot;
  const _Marker({required this.hot});

  @override
  Widget build(BuildContext context) {
    final c = hot ? AppColors.red : Colors.white;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.85),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)
          ],
        ),
      ),
      Container(
        width: 1.5,
        height: 15,
        color: c.withValues(alpha: 0.5),
      ),
    ]);
  }
}
