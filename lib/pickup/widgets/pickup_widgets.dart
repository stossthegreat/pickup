import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// ── Editorial section header ────────────────────────────────────────────
/// All-caps tracked label + optional trailing. The signature "lab report"
/// heading used across every screen.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.md),
        child: Row(
          children: [
            Container(width: 14, height: 1, color: AppColors.red),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(text.toUpperCase(), style: AppTypography.label)),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// ── The Aura Level ring — the hero number ───────────────────────────────
class AuraRing extends StatelessWidget {
  final int level;
  final double progress; // 0..1 into next level
  final String rank;
  final double size;
  const AuraRing({
    super.key,
    required this.level,
    required this.progress,
    required this.rank,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AURA', style: AppTypography.label.copyWith(fontSize: 9)),
              Text('$level',
                  style: AppTypography.displayXL.copyWith(
                    fontSize: size * 0.44,
                    fontStyle: FontStyle.normal,
                    height: 1,
                    color: AppColors.textPrimary,
                  )),
              Text(rank,
                  style: AppTypography.label.copyWith(
                      fontSize: 9, color: AppColors.red, letterSpacing: 3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppColors.surface3;
    canvas.drawCircle(c, r, track);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..shader = const SweepGradient(
        colors: [AppColors.accentDeep, AppColors.red, AppColors.measure],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    final arc = 2 * math.pi * progress.clamp(0.02, 1);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, arc, false, glow);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.accent, AppColors.red, AppColors.measure],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, arc, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// ── Thin measurement-style stat bar ─────────────────────────────────────
class StatBar extends StatelessWidget {
  final String label;
  final String glyph;
  final double value; // 0..100
  final Color color;
  const StatBar({
    super.key,
    required this.label,
    required this.glyph,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$glyph  ',
                  style: TextStyle(fontSize: 12, color: color)),
              Expanded(
                child: Text(label.toUpperCase(),
                    style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary, letterSpacing: 1.6)),
              ),
              Text(value.toStringAsFixed(0),
                  style: AppTypography.measurement
                      .copyWith(color: color, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 3, color: AppColors.surface3),
                LayoutBuilder(
                  builder: (_, cst) => Container(
                    height: 3,
                    width: cst.maxWidth * (value / 100).clamp(0, 1),
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Reusable elevated card surface ──────────────────────────────────────
class PickupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final VoidCallback? onTap;
  const PickupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.md),
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.lg),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(Rd.lg),
            border: Border.all(color: border ?? AppColors.surface3, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ── Small tracked pill (tier / xp badges) ───────────────────────────────
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const Pill(this.text, {super.key, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(Rd.sm),
          border: Border.all(color: color.withOpacity(filled ? 0.4 : 0.3)),
        ),
        child: Text(text.toUpperCase(),
            style: AppTypography.label
                .copyWith(color: color, fontSize: 9, letterSpacing: 1.4)),
      );
}
