import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';
import 'lucien_says.dart';

/// ══════════════════════════════════════════════════════════════════════
///  DAY WON — the streak stops being a number
/// ══════════════════════════════════════════════════════════════════════
///
/// The streak is the strongest mechanic in the app and it was the least
/// celebrated thing in it. It ticked from 6 to 7 inside a pill. The one
/// number a man is genuinely afraid to lose, and the moment he EARNED
/// another day of it passed without the app saying a word.
///
/// So the day gets its own moment: a flame that is visibly bigger than
/// it was yesterday, the day count stamped into it, and one line naming
/// what the day was actually for.
///
/// ── THE FLAME GROWS ──────────────────────────────────────────────────
///
/// This is the whole design. A static icon at day 3 and day 40 says the
/// forty days were worth the same as the three. The fire is drawn from
/// the streak: more tongues, taller, hotter, and from day 30 it throws
/// light onto the screen behind it. He can see his run without reading
/// the number.
///
/// ── AND ONE LINE ABOUT WHO HE'S BECOMING ─────────────────────────────
///
/// "DAY 12" is a stat. The line under it is the product's actual
/// promise, and this is the one screen with the standing to make it —
/// he's just done the work, so it isn't marketing, it's a receipt.
/// They're written to be about the MAN, never about the app.
class DayWon extends StatelessWidget {
  final int streak;

  const DayWon({super.key, required this.streak});

  static Future<void> show(BuildContext context, int streak) {
    Feel.best();
    Sfx.personalBest();
    HapticFeedback.heavyImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'day',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => DayWon(streak: streak),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  /// What today bought him. Escalates with the run, because the same
  /// sentence at day 2 and day 45 is wrong for one of them.
  String get _line {
    if (streak >= 60) {
      return 'Sixty days. You set out to become someone and you did it.';
    }
    if (streak >= 30) return 'A month of this. It isn\'t discipline any more, it\'s just who you are.';
    if (streak >= 14) return 'Two weeks. The nerves before you speak are getting quieter and you\'ve noticed.';
    if (streak >= 7) return 'A full week. This is the point most men quit at.';
    if (streak >= 3) return 'Three days. That\'s a habit starting, not a fluke.';
    return 'Day one is the only one that takes nothing but a decision.';
  }

  /// The identity line. Deliberately about him, never about the app.
  String get _becoming {
    if (streak >= 30) return 'THIS IS THE MAN WHO GETS THE GIRL';
    if (streak >= 14) return 'YOU ARE BECOMING HIM';
    if (streak >= 7) return 'THE WORK IS SHOWING';
    return 'THE WORK HAS STARTED';
  }

  @override
  Widget build(BuildContext context) {
    final hot = streak >= 30;
    return Material(
      color: Colors.black,
      child: Stack(children: [
        // The room warms as the run gets longer.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 1.1,
                colors: [
                  AppColors.red.withValues(alpha: hot ? 0.30 : 0.18),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: Burst(color: AppColors.red, pieces: hot ? 46 : 30)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
            child: Column(children: [
              Text('DAY WON',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: AppColors.red.withValues(alpha: 0.7),
                              blurRadius: 26)
                        ],
                      ))
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scaleXY(begin: 1.5, end: 1, curve: Curves.easeOutBack),

              const Spacer(),

              // THE FIRE. Bigger than it was yesterday.
              SizedBox(
                width: 220,
                height: 240,
                child: _Flame(streak: streak),
              )
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),

              const SizedBox(height: 6),
              Text('$streak',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 68,
                        height: 1,
                        letterSpacing: -3,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: AppColors.red.withValues(alpha: 0.8),
                              blurRadius: 44)
                        ],
                      ))
                  .animate()
                  .fadeIn(delay: 320.ms, duration: 220.ms)
                  .scaleXY(begin: 1.8, end: 1, curve: Curves.easeOutBack),
              Text(streak == 1 ? 'DAY' : 'DAYS IN A ROW',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                    letterSpacing: 3.4,
                    fontWeight: FontWeight.w900,
                  )),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.55)),
                ),
                child: Text(_becoming,
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 10.5,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w900,
                    )),
              )
                  .animate()
                  .fadeIn(delay: 620.ms, duration: 300.ms)
                  .slideY(begin: 0.6, end: 0, curve: Curves.easeOutBack),

              const SizedBox(height: 16),
              Text(_line,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ))
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 340.ms),

              const Spacer(),

              LucienSays(
                line: streak >= 7
                    ? 'You\'ve done the hard bit. Don\'t hand it back.'
                    : 'Again tomorrow. That\'s the whole trick.',
                delay: const Duration(milliseconds: 1000),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: 'AGAIN TOMORROW',
                  height: 54,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 300.ms),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A fire that grows with the run.
///
/// Painted, animated, and driven off the streak: tongue count, height
/// and colour all scale, so day 40 is visibly a bigger fire than day 4
/// without a single new asset.
class _Flame extends StatefulWidget {
  final int streak;
  const _Flame({required this.streak});

  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _FlamePainter(t: _c.value, streak: widget.streak),
        size: Size.infinite,
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final double t; // 0..1 loop
  final int streak;
  const _FlamePainter({required this.t, required this.streak});

  /// 0..1 — how far up the 60-day climb this run is. Everything scales
  /// off it.
  double get _grow => (streak / 60).clamp(0.12, 1.0);

  Path _tongue(Offset base, double w, double h, double lean) {
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
          base.dx - w, base.dy - h * 0.45, base.dx + lean, base.dy - h)
      ..quadraticBezierTo(base.dx + w, base.dy - h * 0.45, base.dx, base.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.88);
    final g = _grow;
    final h = size.height * (0.36 + 0.46 * g);
    final w = size.width * (0.13 + 0.10 * g);

    // Heat haze. From day 30 the fire lights the room.
    if (streak >= 30) {
      canvas.drawCircle(
        base.translate(0, -h * 0.45),
        h * 0.62,
        Paint()
          ..color = AppColors.red.withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.35),
      );
    }

    // Outer tongues — one more every ten days, to a cap.
    final tongues = 2 + (streak ~/ 10).clamp(0, 3);
    for (var i = 0; i < tongues; i++) {
      // Each tongue breathes on its own phase so the fire never pulses
      // as one solid shape — that's the tell that it's a graphic.
      final phase = (t + i / tongues) % 1.0;
      final flick = math.sin(phase * math.pi * 2);
      final side = i.isEven ? 1.0 : -1.0;
      final off = (i + 1) / tongues;
      canvas.drawPath(
        _tongue(
          base.translate(side * w * off * 0.9, 0),
          w * (0.55 + 0.2 * off),
          h * (0.55 + 0.25 * off) * (1 + flick * 0.07),
          side * flick * w * 0.35,
        ),
        Paint()
          ..color = AppColors.red.withValues(alpha: 0.30 + 0.14 * g),
      );
    }

    // The body.
    final bodyFlick = math.sin(t * math.pi * 2);
    canvas.drawPath(
      _tongue(base, w, h * (1 + bodyFlick * 0.05), bodyFlick * w * 0.18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF7A1A),
            AppColors.red,
            AppColors.red.withValues(alpha: 0.75),
          ],
        ).createShader(
            Rect.fromLTWH(base.dx - w, base.dy - h, w * 2, h)),
    );

    // The white core — the hottest part, and the bit that makes it read
    // as fire rather than a leaf.
    canvas.drawPath(
      _tongue(
        base.translate(0, -h * 0.06),
        w * 0.42,
        h * 0.52 * (1 + bodyFlick * 0.08),
        bodyFlick * w * 0.1,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white,
            const Color(0xFFFFD34D),
            const Color(0xFFFFD34D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(
            base.dx - w * 0.5, base.dy - h * 0.6, w, h * 0.6)),
    );

    // Embers rising, more of them the longer the run.
    final embers = 3 + (streak ~/ 8).clamp(0, 7);
    for (var i = 0; i < embers; i++) {
      final p = (t + i / embers) % 1.0;
      final x = base.dx + math.sin((i * 2.3) + p * 3) * w * 1.5;
      final y = base.dy - h * 0.2 - (h * 1.15 * p);
      canvas.drawCircle(
        Offset(x, y),
        1.6 + (i % 3) * 0.7,
        Paint()
          ..color = const Color(0xFFFFD34D)
              .withValues(alpha: (1 - p).clamp(0.0, 1.0) * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) =>
      old.t != t || old.streak != streak;
}
