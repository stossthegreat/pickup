import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/division.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';

/// THE EMBLEM — a rank you can look at.
///
/// A hexagonal plate with a metal gradient, a rim, a progress arc and
/// the step in Roman numerals. Painted rather than drawn as an asset so
/// every division exists at every size on day one, with no art to
/// commission and nothing to ship.
///
/// The arc is the point. A static badge tells him where he is; a badge
/// with his progress to the next rung burned into its rim tells him how
/// close he is, and "close" is the only state that makes anyone queue
/// one more time.
class RankEmblem extends StatelessWidget {
  final Rank rank;
  final double size;

  /// Draw the progress arc. Off for small inline uses where the arc
  /// would be a smudge rather than information.
  final bool showProgress;

  const RankEmblem({
    super.key,
    required this.rank,
    this.size = 96,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmblemPainter(
          rank: rank,
          progress: showProgress ? rank.progress : 0,
        ),
        child: Center(
          child: Text(
            rank.stepLabel,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: size * 0.3,
              height: 1,
              letterSpacing: size * 0.02,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: size * 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  final Rank rank;
  final double progress;
  const _EmblemPainter({required this.rank, required this.progress});

  Path _hex(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      // Flat-top hexagon — point-up reads as a warning sign, flat-top
      // reads as a shield.
      final a = math.pi / 3 * i;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.40;
    final d = rank.div;

    // Outer glow for the divisions that have earned one.
    if (d.glows) {
      canvas.drawPath(
          _hex(c, r + 3),
          Paint()
            ..color = d.color.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.1));
    }

    // The plate — two stops, so it reads as a cast object rather than a
    // colour swatch.
    canvas.drawPath(
      _hex(c, r),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [d.color, d.shade],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // A highlight across the top-left face. One specular edge is the
    // difference between metal and paper.
    canvas.save();
    canvas.clipPath(_hex(c, r));
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r, c.dy - r)
        ..lineTo(c.dx + r, c.dy - r)
        ..lineTo(c.dx - r, c.dy + r * 0.35)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();

    // Rim.
    canvas.drawPath(
      _hex(c, r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.022
        ..color = Colors.white.withValues(alpha: 0.28),
    );

    // The progress arc, outside the plate. How close he is to the next
    // rung, burned into the badge itself.
    if (progress > 0.001) {
      final rr = r + size.width * 0.085;
      final rect = Rect.fromCircle(center: c, radius: rr);
      canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.035
            ..color = Colors.white.withValues(alpha: 0.07));
      canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * progress.clamp(0.0, 1.0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.035
            ..strokeCap = StrokeCap.round
            ..color = d.color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.rank.div != rank.div ||
      old.rank.step != rank.step ||
      old.progress != progress;
}

/// The rank, written out, next to its emblem. Used on the Battles hero
/// and anywhere a standing needs to be stated rather than glanced at.
class RankPlate extends StatelessWidget {
  final Rank rank;
  final int? worldRank;
  const RankPlate({super.key, required this.rank, this.worldRank});

  @override
  Widget build(BuildContext context) {
    final d = rank.div;
    final next = rank.toNext;
    return Column(children: [
      RankEmblem(rank: rank, size: 110),
      const SizedBox(height: 14),
      Text(rank.label,
          style: GoogleFonts.inter(
            color: d.color,
            fontSize: 26,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            shadows: d.glows
                ? [Shadow(color: d.color.withValues(alpha: 0.6), blurRadius: 26)]
                : null,
          )),
      const SizedBox(height: 5),
      Text(Economy.rr(rank.rating),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          )),
      if (next != null) ...[
        const SizedBox(height: 5),
        Text(next,
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w900,
            )),
      ],
      if (worldRank != null) ...[
        const SizedBox(height: 4),
        Text('#${Economy.commas(worldRank!)} WORLDWIDE',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 9,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            )),
      ],
    ]);
  }
}
