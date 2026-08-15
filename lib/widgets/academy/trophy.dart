import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../theme/app_colors.dart';

/// THE MEDAL — painted, not commissioned.
///
/// Thirty badges across three metals. As artwork that's thirty files to
/// draw, name, export at three densities and keep consistent forever;
/// as a painter it's one shape, one gradient and a glyph, and every
/// badge exists at every size the day it's written. The app has shipped
/// zero custom art so far and this is not the feature to break that on.
///
/// The shape is a laurel-less star-cut disc: a circle with a notched rim
/// and a ribbon notch at the bottom. It reads as a medal at 34pt and at
/// 120pt, which is the only test that matters.
class TrophyMedal extends StatelessWidget {
  final Trophy trophy;
  final double size;

  /// Locked badges render as a dark silhouette with the glyph knocked
  /// out. Visible, never secret — see the rules in achievements.dart —
  /// but obviously not his yet.
  final bool earned;

  /// 0..1 toward the target. Drawn as a rim arc on locked medals so a
  /// shelf shows momentum rather than a wall of grey.
  final double progress;

  const TrophyMedal({
    super.key,
    required this.trophy,
    this.size = 84,
    this.earned = true,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalPainter(
          tier: trophy.tier,
          earned: earned,
          progress: progress,
        ),
        child: Center(
          child: Icon(
            _glyph(trophy.stat),
            size: size * 0.34,
            color: earned
                ? Colors.white
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }

  /// One glyph per family, all proven elsewhere in the app — there's no
  /// SDK in the build environment to check a new icon constant against,
  /// and a wrong one is a red screen on his phone rather than a warning.
  static IconData _glyph(Stat s) => switch (s) {
        Stat.talks => Icons.forum_rounded,
        Stat.approaches => Icons.directions_walk_rounded,
        Stat.duels => Icons.sports_mma_rounded,
        Stat.wins => Icons.workspace_premium_rounded,
        Stat.streakPeak => Icons.local_fire_department_rounded,
        Stat.numbers => Icons.call_rounded,
        Stat.dailies => Icons.graphic_eq_rounded,
        Stat.nineties => Icons.auto_awesome_rounded,
        Stat.chain => Icons.link_rounded,
        Stat.nudges => Icons.campaign_rounded,
      };
}

class _MedalPainter extends CustomPainter {
  final Tier tier;
  final bool earned;
  final double progress;
  const _MedalPainter({
    required this.tier,
    required this.earned,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;

    if (earned) {
      // Glow, gold only. If every metal glowed, none of them would.
      if (tier == Tier.gold) {
        canvas.drawCircle(
          c,
          r + 2,
          Paint()
            ..color = tier.color.withValues(alpha: 0.55)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, size.width * 0.11),
        );
      }

      // The notched rim — twelve teeth, so it reads as struck metal
      // rather than a coloured circle.
      final teeth = Path();
      for (var i = 0; i < 12; i++) {
        final a = (math.pi * 2 / 12) * i;
        teeth.addOval(Rect.fromCircle(
          center: c + Offset(math.cos(a), math.sin(a)) * (r * 1.05),
          radius: r * 0.16,
        ));
      }
      canvas.drawPath(
          teeth, Paint()..color = tier.shade.withValues(alpha: 0.95));

      // The face.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tier.color, tier.shade],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );

      // One specular sweep across the top-left. The difference between
      // metal and a swatch.
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - r, c.dy - r)
          ..lineTo(c.dx + r, c.dy - r)
          ..lineTo(c.dx - r, c.dy + r * 0.4)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
      canvas.restore();

      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.02
          ..color = Colors.white.withValues(alpha: 0.3),
      );
      return;
    }

    // ── LOCKED ────────────────────────────────────────────────────────
    canvas.drawCircle(c, r, Paint()..color = AppColors.surface2);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..color = Colors.white.withValues(alpha: 0.07),
    );

    // The progress arc. A locked shelf that shows how close he is to
    // three of them is a to-do list; one that shows thirty grey discs is
    // a list of his failures.
    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.045
          ..strokeCap = StrokeCap.round
          ..color = tier.color.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MedalPainter old) =>
      old.earned != earned || old.progress != progress || old.tier != tier;
}

/// THE NEXT ONE — a single line, and the highest-value thing this whole
/// system produces.
///
/// A trophy shelf gets opened once. One named badge with "8 / 10" under
/// it, sitting on a screen he already visits, gets ACTED ON. See
/// [Achievements.next] for why it picks the closest started badge rather
/// than the rarest one.
class NextBadgeStrip extends StatefulWidget {
  final VoidCallback? onTap;
  const NextBadgeStrip({super.key, this.onTap});

  @override
  State<NextBadgeStrip> createState() => _NextBadgeStripState();
}

class _NextBadgeStripState extends State<NextBadgeStrip> {
  ({Trophy trophy, int have})? _next;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final n = await Achievements.next();
    if (mounted) setState(() => _next = n);
  }

  @override
  Widget build(BuildContext context) {
    final n = _next;
    if (n == null) return const SizedBox.shrink();
    final b = n.trophy;
    final frac = (n.have / b.need).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: b.tier.color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          TrophyMedal(trophy: b, size: 40, earned: false, progress: frac),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT BADGE',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 8.5,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text(b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(children: [
                    Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: 0.07)),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(height: 4, color: b.tier.color),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${n.have}/${b.need}',
              style: GoogleFonts.inter(
                color: b.tier.color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ),
    );
  }
}
