import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE GRADE — the single glyph the whole reveal is built around.
///
/// A raw score of 741 means nothing on its own; a letter does. Fighting
/// games, rhythm games and racers all land the result the same way: one
/// big letter, slammed, with a verdict under it. That's what makes a
/// results screen feel like a result instead of a receipt.
class RizzGrade {
  final String letter;
  final Color color;
  final String verdict;
  const RizzGrade(this.letter, this.color, this.verdict);

  /// Scores come back 0..9999 (weighted 0..100 × 99.99), NOT 0..1000 —
  /// these thresholds were an order of magnitude out, which graded an
  /// average attempt as S. The grader's own scale is the reference:
  /// 50 = average nervous attempt, 70 = genuinely good, 85+ = rare.
  static RizzGrade of(int score) {
    if (score >= 8800) {
      return const RizzGrade('S', Color(0xFFFFD34D), 'UNTOUCHABLE');
    }
    if (score >= 7500) return const RizzGrade('A', kNeon, 'SHE FELT THAT');
    if (score >= 6200) {
      return const RizzGrade('B', AppColors.signalGreen, 'SOLID WORK');
    }
    if (score >= 4500) {
      return const RizzGrade('C', AppColors.signalAmber, 'YOU SURVIVED');
    }
    if (score >= 3000) {
      return const RizzGrade('D', AppColors.red, 'SHE DRIFTED');
    }
    return const RizzGrade('F', AppColors.redDim, 'RUN IT BACK');
  }
}

/// The stamp itself: the letter drops from way above scale, lands with
/// a heavy haptic, and throws two expanding shockwave rings.
class GradeStamp extends StatefulWidget {
  final RizzGrade grade;
  final Duration delay;
  final double size;

  /// Fired the frame the letter lands, so the parent can shake the
  /// screen and flash on the exact impact.
  final VoidCallback? onImpact;

  const GradeStamp({
    super.key,
    required this.grade,
    this.delay = const Duration(milliseconds: 1500),
    this.size = 132,
    this.onImpact,
  });

  @override
  State<GradeStamp> createState() => _GradeStampState();
}

class _GradeStampState extends State<GradeStamp>
    with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _drop.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_landed) {
        _landed = true;
        HapticFeedback.heavyImpact();
        _wave.forward();
        widget.onImpact?.call();
      }
    });
    Future.delayed(widget.delay, () {
      if (mounted) _drop.forward();
    });
  }

  @override
  void dispose() {
    _drop.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.grade.color;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drop, _wave]),
        builder: (_, __) {
          // Overshoot on the way in — the letter is heavier than it looks.
          final t = Curves.easeInCubic.transform(_drop.value);
          final scale = 3.4 - 2.4 * t;
          final tilt = (1 - t) * -0.35;
          return Stack(alignment: Alignment.center, children: [
            if (_wave.value > 0)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ShockwavePainter(progress: _wave.value, color: c),
                ),
              ),
            Opacity(
              opacity: _drop.value == 0 ? 0 : (0.35 + 0.65 * t),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    widget.grade.letter,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: widget.size * 0.72,
                      height: 1,
                      letterSpacing: -6,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: c, blurRadius: 34),
                        Shadow(color: c.withValues(alpha: 0.6), blurRadius: 70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Two rings racing outward from the impact point, thinning as they go.
class _ShockwavePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  const _ShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 1.25;
    for (var i = 0; i < 2; i++) {
      final p = (progress - i * 0.18).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final eased = Curves.easeOutQuart.transform(p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - eased) + 0.5
        ..color = color.withValues(alpha: (1 - eased) * 0.75);
      canvas.drawCircle(center, maxR * eased, paint);
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) =>
      old.progress != progress || old.color != color;
}

/// Screen shake. Wrap the results column, hold a
/// `GlobalKey<ImpactShakeState>`, and call `shake()` from the stamp's
/// impact callback — the whole layout jolts once like a hit landed.
class ImpactShake extends StatefulWidget {
  final Widget child;
  const ImpactShake({super.key, required this.child});

  @override
  State<ImpactShake> createState() => ImpactShakeState();
}

class ImpactShakeState extends State<ImpactShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Call to jolt the screen.
  void shake() {
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // ── ALWAYS THE SAME SHAPE. THIS LINE WAS THE WHOLE PLAGUE ────
        //
        // This used to return `child!` bare when idle and wrap it in a
        // Transform while shaking. Same child, different WRAPPER — and
        // Flutter reconciles by type at each slot, so every time the
        // wrapper appeared or vanished the ENTIRE subtree underneath
        // was unmounted and inflated fresh. This widget wraps the whole
        // score ceremony.
        //
        // Which built a perfect perpetual-motion machine: the grade
        // stamp lands → onImpact → shake() → shape changes → subtree
        // remounts → a NEW stamp waits its delay and lands again →
        // onImpact → shake() → … forever. Every score screen in the app
        // "kept counting again and again" — and every fix inside the
        // tree (per-day claims, notifiers, caches, owned controllers,
        // finally a static number) was real, and none could hold,
        // because this line kept throwing the whole tree away from the
        // outside. Ten reports; this line.
        //
        // A Transform at Offset.zero costs nothing to compose and keeps
        // the tree the same shape from the first frame to the last, so
        // the subtree is never remounted at all.
        final v = _c.value;
        if (v == 0 || _c.isCompleted) {
          return Transform.translate(offset: Offset.zero, child: child);
        }
        // Decaying sine — big first swing, gone in half a second.
        final decay = 1 - v;
        final dx = math.sin(v * math.pi * 7) * 13 * decay * decay;
        final dy = math.cos(v * math.pi * 5) * 7 * decay * decay;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: widget.child,
    );
  }
}
