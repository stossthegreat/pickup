import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/squad_day.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE SQUAD GAUGE — one hero instrument, not a wall of icons.
///
/// A precision instrument rather than a fitness ring: a wide arc broken
/// into one segment PER MEMBER, each filling with that member's five
/// moves. You read the whole team's day in a single glance — who's
/// carrying it, who hasn't moved — without a legend, a list, or a
/// number per person.
///
/// It breathes while the squad is short of target and locks solid the
/// moment the day is won. Empty seats render as hairline ghost segments
/// so a two-man squad looks deliberately unfinished rather than broken.
class SquadGauge extends StatefulWidget {
  final SquadDay day;
  final String squadName;

  /// Fires the frame the day is won, so the room can celebrate.
  final VoidCallback? onWin;

  const SquadGauge({
    super.key,
    required this.day,
    required this.squadName,
    this.onWin,
  });

  @override
  State<SquadGauge> createState() => _SquadGaugeState();
}

class _SquadGaugeState extends State<SquadGauge>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  /// Segments sweep out on first paint and re-sweep whenever a move
  /// lands, so a squadmate finishing something is physically visible.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  bool _celebrated = false;

  @override
  void didUpdateWidget(covariant SquadGauge old) {
    super.didUpdateWidget(old);
    if (old.day.complete != widget.day.complete) {
      _fill.forward(from: 0.72); // short re-sweep, not a full replay
    }
    if (widget.day.won && !_celebrated) {
      _celebrated = true;
      widget.onWin?.call();
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final won = d.won;

    return AspectRatio(
      aspectRatio: 1.35,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _fill]),
        builder: (_, __) {
          // Breathing stops once the day is won — a finished instrument
          // sits still. Restraint is what makes it read as expensive.
          final glow = won ? 1.0 : 0.55 + 0.45 * _breathe.value;
          return Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: Size.infinite,
              painter: _GaugePainter(
                day: d,
                sweep: Curves.easeOutCubic.transform(_fill.value),
                glow: glow,
                won: won,
              ),
            ),
            // ── Centre stack ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.squadName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: d.form.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    v.round().toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 68,
                      height: 0.95,
                      letterSpacing: -3.5,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: (won ? kNeon : AppColors.red)
                                .withValues(alpha: 0.45 * glow),
                            blurRadius: 40),
                      ],
                    ),
                  ),
                ),
                Text('SQUAD FORM',
                    style: GoogleFonts.inter(
                      color: won ? kNeon : AppColors.red,
                      fontSize: 9.5,
                      letterSpacing: 3.4,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
            ),
            // ── The two lines under the dial ────────────────────────
            Positioned(
              bottom: 2,
              child: Column(children: [
                Text('${d.complete} / ${d.possible} MOVES COMPLETE',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 3),
                Text(
                    won
                        ? 'DAY WON'
                        : d.remaining == 1
                            ? '1 MORE TO WIN THE DAY'
                            : '${d.remaining} MORE TO WIN THE DAY',
                    style: GoogleFonts.inter(
                      color: won ? kNeon : AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final SquadDay day;
  final double sweep; // 0..1 entrance
  final double glow;
  final bool won;

  const _GaugePainter({
    required this.day,
    required this.sweep,
    required this.glow,
    required this.won,
  });

  // A wide arc with a gap at the bottom — an instrument, not a ring.
  static const _start = math.pi * 0.75;
  static const _total = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.56);
    final radius = math.min(size.width, size.height) * 0.42;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    // Seats include the empty ones, so a 2-man squad shows 3 ghosts and
    // reads as "room for more" rather than "something is missing".
    final seats = SquadDay.maxMembers;
    const gap = 0.055; // radians between segments
    final segment = (_total - gap * (seats - 1)) / seats;

    for (var i = 0; i < seats; i++) {
      final from = _start + i * (segment + gap);
      final filled = i < day.roster.length;

      // Track
      canvas.drawArc(
        rect,
        from,
        segment,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = filled ? 13 : 5
          ..strokeCap = StrokeCap.round
          ..color = filled
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.035),
      );

      if (!filled) continue;

      final moves = day.movesFor(day.roster[i].userId);
      final pct = (moves / SquadDay.movesPerMember).clamp(0.0, 1.0) * sweep;
      if (pct <= 0) continue;

      final colour = won
          ? kNeon
          : moves >= SquadDay.movesPerMember
              ? kNeon
              : AppColors.red;

      // Glow pass, then the solid stroke on top — restrained bloom.
      canvas.drawArc(
        rect,
        from,
        segment * pct,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.20 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawArc(
        rect,
        from,
        segment * pct,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: from,
            endAngle: from + segment,
            colors: [colour.withValues(alpha: 0.55), colour],
          ).createShader(rect),
      );
    }

    // Target notch — the point on the dial the squad is aiming at.
    if (!won && day.possible > 0) {
      final at = _start + _total * SquadDay.winThreshold;
      final inner = centre + Offset(math.cos(at), math.sin(at)) * (radius - 12);
      final outer = centre + Offset(math.cos(at), math.sin(at)) * (radius + 12);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.sweep != sweep ||
      old.glow != glow ||
      old.won != won ||
      old.day.complete != day.complete ||
      old.day.roster.length != day.roster.length;
}
