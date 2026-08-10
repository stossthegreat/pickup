import 'dart:math' as math;

import 'package:flutter/material.dart';

/// THE CREST — a real painted emblem, one per division. Not a text
/// label in a box: a metal shield with a bevel, a cut gem, a rotating
/// shine sweep and a coloured glow. This is the object users screenshot
/// and chase.
///
/// Divisions: 1 ROOKIE (bronze) · 2 PLAYER (steel) · 3 SAVAGE (gold) ·
/// 4 ELITE (crimson) · 5 HIM (neon).
class LeagueCrest extends StatefulWidget {
  final int division; // 1..5
  final double size;

  /// Locked crests render desaturated + dim — the "what's next" tease.
  final bool locked;

  const LeagueCrest({
    super.key,
    required this.division,
    this.size = 84,
    this.locked = false,
  });

  @override
  State<LeagueCrest> createState() => _LeagueCrestState();
}

class _LeagueCrestState extends State<LeagueCrest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = crestPalette(widget.division);
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.16,
      child: AnimatedBuilder(
        animation: _shine,
        builder: (_, __) => CustomPaint(
          painter: _CrestPainter(
            palette: p,
            shine: _shine.value,
            locked: widget.locked,
          ),
        ),
      ),
    );
  }
}

/// Metal + gem colours per division.
class CrestPalette {
  final Color metalLight, metalMid, metalDark, gem, gemGlow;
  final String label;
  const CrestPalette(this.metalLight, this.metalMid, this.metalDark, this.gem,
      this.gemGlow, this.label);
}

CrestPalette crestPalette(int division) => switch (division) {
      5 => const CrestPalette(Color(0xFF9CFFC9), Color(0xFF2EE87A),
          Color(0xFF0B6E3A), Color(0xFFEAFFF3), Color(0xFF2EE87A), 'HIM'),
      4 => const CrestPalette(Color(0xFFFF7A80), Color(0xFFE8222A),
          Color(0xFF6E0B0F), Color(0xFFFFE3E4), Color(0xFFE8222A), 'ELITE'),
      3 => const CrestPalette(Color(0xFFFFE9A3), Color(0xFFF5C542),
          Color(0xFF8A6410), Color(0xFFFFF8E1), Color(0xFFF5C542), 'SAVAGE'),
      2 => const CrestPalette(Color(0xFFE8ECF2), Color(0xFFA9B4C2),
          Color(0xFF4A525C), Color(0xFFF4F8FF), Color(0xFFA9B4C2), 'PLAYER'),
      _ => const CrestPalette(Color(0xFFE0A879), Color(0xFFB87333),
          Color(0xFF5E3612), Color(0xFFFFE7D0), Color(0xFFB87333), 'ROOKIE'),
    };

class _CrestPainter extends CustomPainter {
  final CrestPalette palette;
  final double shine; // 0..1 sweep position
  final bool locked;
  _CrestPainter(
      {required this.palette, required this.shine, required this.locked});

  /// Classic shield: flat shouldered top, swept sides, point at the base.
  Path _shield(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.96, h * 0.14)
      ..cubicTo(w * 0.96, h * 0.52, w * 0.86, h * 0.82, w * 0.5, h)
      ..cubicTo(w * 0.14, h * 0.82, w * 0.04, h * 0.52, w * 0.04, h * 0.14)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shield = _shield(size);
    final c = Offset(size.width * 0.5, size.height * 0.45);

    Color dim(Color x) => locked
        ? Color.lerp(x, const Color(0xFF23232A), 0.72)!
        : x;

    // ── Outer glow ────────────────────────────────────────────────
    if (!locked) {
      canvas.drawPath(
        shield,
        Paint()
          ..color = palette.gemGlow.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // ── Metal body ────────────────────────────────────────────────
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            dim(palette.metalLight),
            dim(palette.metalMid),
            dim(palette.metalDark),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );

    // ── Inner bevel (inset shield, lighter rim) ───────────────────
    canvas.save();
    canvas.translate(size.width * 0.09, size.height * 0.075);
    final inner = _shield(Size(size.width * 0.82, size.height * 0.84));
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [
            dim(palette.metalLight).withValues(alpha: 0.55),
            dim(palette.metalDark).withValues(alpha: 0.30),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = dim(palette.metalLight).withValues(alpha: 0.85),
    );
    canvas.restore();

    // ── The gem — a cut diamond at the heart ──────────────────────
    final r = size.width * 0.19;
    final gem = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.82, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.82, c.dy)
      ..close();
    if (!locked) {
      canvas.drawPath(
        gem,
        Paint()
          ..color = palette.gemGlow.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dim(palette.gem), dim(palette.gemGlow)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Facet line — the cut that makes it read as gem, not rhombus.
    canvas.drawLine(
      Offset(c.dx - r * 0.82, c.dy),
      Offset(c.dx + r * 0.82, c.dy),
      Paint()
        ..color = Colors.white.withValues(alpha: locked ? 0.15 : 0.6)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - r),
      Offset(c.dx, c.dy + r),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );

    // ── Shine sweep — a diagonal band travelling across the metal ──
    if (!locked) {
      canvas.save();
      canvas.clipPath(shield);
      final x = -size.width + shine * (size.width * 3);
      canvas.drawRect(
        Rect.fromLTWH(x, -size.height, size.width * 0.42, size.height * 3),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.34),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
              Rect.fromLTWH(x, 0, size.width * 0.42, size.height))
          ..blendMode = BlendMode.plus,
      );
      canvas.restore();
    }

    // ── Rim ───────────────────────────────────────────────────────
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dim(palette.metalLight),
            dim(palette.metalDark),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CrestPainter old) =>
      old.shine != shine || old.locked != locked || old.palette != palette;
}

/// Glowing circular progress arc — for "points to promotion", streaks,
/// tier progress. Reads as a game HUD element, not a LinearProgressBar.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final Color color;
  final double stroke;
  final Widget? center;
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.color = const Color(0xFFE8222A),
    this.stroke = 6,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(
          painter: _RingPainter(v, color, stroke),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;
  _RingPainter(this.value, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFF16161B),
    );
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [color.withValues(alpha: 0.7), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
