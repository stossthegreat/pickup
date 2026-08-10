import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// THE BUTTON. A solid face sitting on a darker edge — press it and the
/// face travels DOWN into the edge, like a real key. This one component
/// is the difference between "an app" and "a game"; every game-feeling
/// product on the store uses this exact trick.
class GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final double height;

  /// Slow breathing scale — for the one button that wants to be pressed
  /// right now (today's daily, the challenge, the claim).
  final bool pulse;

  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.red,
    this.textColor,
    this.icon,
    this.height = 58,
    this.pulse = false,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  static const _edge = 5.0; // depth of the 3D lip

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _breathe.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GameButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    } else if (!widget.pulse && _breathe.isAnimating) {
      _breathe.stop();
      _breathe.value = 0;
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final face = enabled
        ? widget.color
        : Color.lerp(widget.color, AppColors.surface2, 0.65)!;
    // The lip is the same hue, driven darker — reads as one moulded part.
    final lip = Color.lerp(face, Colors.black, 0.42)!;
    final fg = widget.textColor ??
        (enabled ? Colors.white : AppColors.textMuted);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              HapticFeedback.mediumImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (_, child) => Transform.scale(
          scale: 1 + (_breathe.value * 0.015),
          child: child,
        ),
        child: SizedBox(
          height: widget.height + _edge,
          child: Stack(children: [
            // The lip — always drawn at the bottom.
            Positioned(
              left: 0,
              right: 0,
              top: _edge,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: lip,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // The face — travels down onto the lip when pressed.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _down ? _edge : 0,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(face, Colors.white, 0.14)!,
                      face,
                    ],
                  ),
                  boxShadow: enabled && !_down
                      ? [
                          BoxShadow(
                            color: face.withValues(alpha: 0.38),
                            blurRadius: 22,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 19, color: fg),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          color: fg,
                          fontSize: 15,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A number that counts up with a spring — every score, every points
/// total. Numbers that snap into place feel dead; numbers that climb
/// feel earned.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (_, v, __) => Text(v.round().toString(), style: style),
    );
  }
}

/// CONFETTI. Fires once on promotion / victory / a crown taken. Cheap
/// (no package, one painter) and it's the difference between "you
/// ranked up" as a sentence and as a moment.
class Burst extends StatefulWidget {
  final Color color;
  final int pieces;
  const Burst({super.key, this.color = AppColors.red, this.pieces = 34});

  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final List<_Piece> _pieces = List.generate(widget.pieces, (i) {
    final r = math.Random(i * 7919);
    return _Piece(
      angle: r.nextDouble() * math.pi * 2,
      speed: 90 + r.nextDouble() * 190,
      spin: (r.nextDouble() - 0.5) * 10,
      size: 4 + r.nextDouble() * 7,
      tint: r.nextDouble(),
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BurstPainter(_pieces, _c.value, widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  final double angle, speed, spin, size, tint;
  const _Piece(
      {required this.angle,
      required this.speed,
      required this.spin,
      required this.size,
      required this.tint});
}

class _BurstPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t; // 0..1
  final Color color;
  _BurstPainter(this.pieces, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in pieces) {
      // Ballistic: outward burst + gravity, easing out.
      final d = p.speed * (1 - math.pow(1 - t, 2.4));
      final pos = origin +
          Offset(math.cos(p.angle) * d,
              math.sin(p.angle) * d + 340 * t * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 1.7),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = Color.lerp(color, Colors.white, p.tint * 0.6)!
              .withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
