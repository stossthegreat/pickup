import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/auralay_app_colors.dart';

/// Two eye-shape targets drawn over the camera preview — the focal point
/// of the 30-second charisma test.
///
/// Visual design: cold scan-blue almonds with sharp red glow on lock.
/// The user's job is to LOOK AT these eyes; when they do, the target
/// glows brighter. The targets do NOT move their irises around (an early
/// version did this — the "look back" effect — but it confused users
/// into thinking they were supposed to follow the iris). Now the irises
/// stare straight ahead and only the outer glow reacts to lock state.
///
///   * [center] — normalized 0..1 position of the midpoint between the
///     two eyes, in the parent's coordinate space (typically the camera
///     preview). When the engine moves the target between phases (BREAK
///     phase glides upper-right) the position tweens smoothly.
///   * [size]   — overall width of the two-eye composition in pixels.
///   * [locked] — true when the user's gaze is near the target.
///   * [intensity] — 0..1 fade for phase entry/exit.
///   * [hidden] — fade out completely (used during the final STILL phase).
class EyeTargetOverlay extends StatefulWidget {
  final Offset center;
  final double size;
  final bool locked;
  final double intensity;
  final bool hidden;

  const EyeTargetOverlay({
    super.key,
    required this.center,
    this.size = 168,
    this.locked = false,
    this.intensity = 1.0,
    this.hidden = false,
  });

  @override
  State<EyeTargetOverlay> createState() => _EyeTargetOverlayState();
}

class _EyeTargetOverlayState extends State<EyeTargetOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;     // breathing scale
  late final AnimationController _lockBoost; // brief glow flare on lock

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _lockBoost = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant EyeTargetOverlay old) {
    super.didUpdateWidget(old);
    if (widget.locked && !old.locked) {
      _lockBoost.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _lockBoost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        // Smooth target-position glide between phases.
        return TweenAnimationBuilder<Offset>(
          tween: Tween(begin: widget.center, end: widget.center),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
          builder: (_, pos, __) {
            return Stack(
              children: [
                Positioned(
                  left: pos.dx * c.maxWidth  - widget.size / 2,
                  top:  pos.dy * c.maxHeight - widget.size * 0.3,
                  width: widget.size,
                  height: widget.size * 0.6,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: widget.hidden ? 0.0 : widget.intensity,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _lockBoost]),
                      builder: (_, __) {
                        return CustomPaint(
                          painter: _EyeTargetPainter(
                            pulse: _pulse.value,
                            lockBoost: _lockBoost.value,
                            locked: widget.locked,
                          ),
                          size: Size(widget.size, widget.size * 0.6),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

class _EyeTargetPainter extends CustomPainter {
  final double pulse;       // 0..1 from controller
  final double lockBoost;   // 0..1 from controller
  final bool locked;

  _EyeTargetPainter({
    required this.pulse,
    required this.lockBoost,
    required this.locked,
  });

  // Brand palette for the targets. Cold scan-blue when idle, warm red
  // accent on lock — the colour shift IS the feedback signal.
  static const _baseBlue   = Color(0xFF60A5FA);
  static const _brightBlue = Color(0xFFA8D0FF);
  static const _deepBlue   = Color(0xFF1D4ED8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final eyeWidth = w * 0.42;
    final eyeHeight = h * 0.55;
    final gap = w * 0.16;

    final leftCenter  = Offset(w / 2 - gap / 2 - eyeWidth / 2, h / 2);
    final rightCenter = Offset(w / 2 + gap / 2 + eyeWidth / 2, h / 2);

    // Soft breathing scale ±2%.
    final breath = 1.0 + math.sin(pulse * math.pi * 2) * 0.018;

    // Ghost ALPHA — semi-transparent base so the user can see their own
    // face through the targets. Alignment-by-overlay matters more than
    // a solid icon. Lock state pumps opacity up briefly to confirm.
    final ghostAlpha = locked ? 0.78 : 0.55;

    // Glow paint — outer halo. Cold blue at rest, hot red on lock.
    final glowColor = locked
        ? AppColors.accent.withValues(alpha: 0.42 * ghostAlpha)
        : _baseBlue.withValues(alpha: 0.20 * ghostAlpha);
    final glow = Paint()
      ..color = glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal,
          locked ? 22 + lockBoost * 12 : 18);
    _drawAlmond(canvas, leftCenter,  eyeWidth * breath, eyeHeight * breath, glow);
    _drawAlmond(canvas, rightCenter, eyeWidth * breath, eyeHeight * breath, glow);

    // Outline — crisp almond. Translucent so user's own face shows through.
    final outlineColor = locked
        ? AppColors.accentBright.withValues(alpha: ghostAlpha)
        : _brightBlue.withValues(alpha: ghostAlpha * 0.92);
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = locked ? 2.0 : 1.5
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawAlmond(canvas, leftCenter,  eyeWidth * breath, eyeHeight * breath, outline);
    _drawAlmond(canvas, rightCenter, eyeWidth * breath, eyeHeight * breath, outline);

    // NO inner wash — keeping the almond hollow lets the user's own eyes
    // show through. The whole point of going ghost is alignment-on-eyes.

    // Iris dots — translucent, dead-centered. Sized small so they don't
    // cover the user's actual pupil behind the overlay.
    final irisR = eyeHeight * 0.22;
    final irisColor = locked
        ? AppColors.accentBright.withValues(alpha: ghostAlpha * 0.85)
        : _brightBlue.withValues(alpha: ghostAlpha * 0.75);
    final iris = Paint()..color = irisColor;
    canvas.drawCircle(leftCenter,  irisR, iris);
    canvas.drawCircle(rightCenter, irisR, iris);

    // Pupil — small dark core, much fainter than before so it doesn't
    // hide the user's actual pupil.
    final pupil = Paint()..color = Colors.black.withValues(alpha: 0.32 * ghostAlpha);
    canvas.drawCircle(leftCenter,  irisR * 0.38, pupil);
    canvas.drawCircle(rightCenter, irisR * 0.38, pupil);

    // Catch-light — fainter so it doesn't compete with the user's own eye gleam.
    final catchlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * ghostAlpha);
    final clOffset = Offset(-irisR * 0.32, -irisR * 0.32);
    canvas.drawCircle(leftCenter  + clOffset, irisR * 0.14, catchlight);
    canvas.drawCircle(rightCenter + clOffset, irisR * 0.14, catchlight);

    // Lock flash — brief radial pulse the moment the user locks on.
    if (lockBoost > 0 && lockBoost < 1) {
      final flash = Paint()
        ..color = AppColors.accent.withValues(alpha: (1 - lockBoost) * 0.40)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * lockBoost);
      canvas.drawCircle(Offset(w / 2, h / 2),
          (w / 2) * (0.6 + lockBoost * 0.6), flash);
    }
  }

  void _drawAlmond(Canvas canvas, Offset center, double w, double h, Paint p) {
    // Almond = two arcs joined at sharp inner/outer corners. Built as a
    // cubic Bezier path so the corners read as tapered, not perfect oval.
    final path = Path();
    final left  = center.dx - w / 2;
    final right = center.dx + w / 2;
    final top   = center.dy - h / 2;
    final bot   = center.dy + h / 2;

    path.moveTo(left, center.dy);
    // Upper arc — outer corner sweep
    path.cubicTo(
      left + w * 0.22, top - h * 0.05,
      right - w * 0.22, top - h * 0.05,
      right, center.dy);
    // Lower arc
    path.cubicTo(
      right - w * 0.22, bot + h * 0.05,
      left + w * 0.22, bot + h * 0.05,
      left, center.dy);
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _EyeTargetPainter old) =>
      old.pulse != pulse ||
      old.lockBoost != lockBoost ||
      old.locked != locked;
}
