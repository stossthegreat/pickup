import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/shield_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';
import 'lucien_says.dart';

/// "A SHIELD HELD YOUR RUN."
///
/// He is being told about something that already happened, and that is
/// the entire emotional trick. The alternative — a dialog on the way in
/// asking "spend a shield?" — puts a decision between a distracted man
/// and his fourteen days, and the distracted man is exactly the one it
/// was built for.
///
/// So this never asks. It reports. Relief with nothing owed, which is a
/// far stronger feeling than permission granted, and it costs nothing to
/// dismiss because there is nothing to dismiss.
///
/// The tone is deliberately not a celebration. He didn't earn this — he
/// missed a day and something he'd banked earlier covered him. Lucien
/// says as much, because a shield presented as a win teaches a man that
/// missing days is fine.
class ShieldSheet {
  static Future<void> show(BuildContext context, int run) {
    Feel.best();
    HapticFeedback.heavyImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: false,
      barrierLabel: 'shield',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => _ShieldSheet(run: run),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }
}

class _ShieldSheet extends StatelessWidget {
  final int run;
  const _ShieldSheet({required this.run});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 132,
              height: 132,
              child: CustomPaint(painter: _ShieldPainter()),
            )
                .animate()
                .fadeIn(duration: 320.ms)
                .scaleXY(begin: 0.5, end: 1, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text('A SHIELD HELD',
                    style: GoogleFonts.inter(
                      color: AppColors.measure,
                      fontSize: 12,
                      letterSpacing: 4.6,
                      fontWeight: FontWeight.w900,
                    ))
                .animate()
                .fadeIn(delay: 260.ms, duration: 300.ms),
            const SizedBox(height: 10),
            Text('YOUR $run DAYS ARE STILL THERE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.15,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w900,
                    ))
                .animate()
                .fadeIn(delay: 380.ms, duration: 320.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            Text(
                'You missed yesterday. One of the shields you earned by '
                'showing up spent itself so the run didn\'t break. You '
                'weren\'t asked because you weren\'t here to ask.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                )).animate().fadeIn(delay: 520.ms, duration: 320.ms),
            const SizedBox(height: 22),
            LucienSays(
                line: LucienLines.shieldSaved(run),
                delay: const Duration(milliseconds: 700)),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: GameButton(
                label: 'DON\'T NEED IT TOMORROW',
                color: AppColors.measure,
                height: 54,
                onTap: () => Navigator.of(context).pop(),
              ),
            ).animate().fadeIn(delay: 860.ms, duration: 300.ms),
            const SizedBox(height: 10),
            FutureBuilder<int>(
              future: ShieldService.held(),
              builder: (_, snap) {
                final left = snap.data;
                if (left == null) return const SizedBox(height: 16);
                return Text(
                    left == 0
                        ? 'NO SHIELDS LEFT'
                        : '$left SHIELD${left == 1 ? '' : 'S'} LEFT',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    ));
              },
            ).animate().fadeIn(delay: 980.ms),
          ]),
        ),
      ),
    );
  }
}

/// A crest. Painted for the same reason every other emblem in this app
/// is painted — it exists at every size on day one and there's no art to
/// commission.
class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);

    Path shield(double s) {
      final ww = w * 0.62 * s, hh = h * 0.72 * s;
      final l = c.dx - ww / 2, r = c.dx + ww / 2;
      final t = c.dy - hh / 2, b = c.dy + hh / 2;
      return Path()
        ..moveTo(l, t)
        ..lineTo(r, t)
        ..lineTo(r, t + hh * 0.52)
        // The point at the bottom is what makes it read as a shield
        // rather than a badge.
        ..quadraticBezierTo(r, b - hh * 0.06, c.dx, b)
        ..quadraticBezierTo(l, b - hh * 0.06, l, t + hh * 0.52)
        ..close();
    }

    canvas.drawPath(
      shield(1.06),
      Paint()
        ..color = AppColors.measure.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(
      shield(1.0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.measure, AppColors.measureDim],
        ).createShader(Rect.fromCircle(center: c, radius: w / 2)),
    );
    // Specular edge.
    canvas.save();
    canvas.clipPath(shield(1.0));
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(0, h * 0.62)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
    canvas.restore();
    canvas.drawPath(
      shield(1.0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // A flame inside it — the thing that was protected.
    final f = Path();
    final fx = c.dx, fy = c.dy + h * 0.02, fs = h * 0.16;
    f.moveTo(fx, fy - fs);
    f.quadraticBezierTo(fx + fs * 0.95, fy - fs * 0.1, fx + fs * 0.5, fy + fs * 0.6);
    f.quadraticBezierTo(fx, fy + fs * 1.05, fx - fs * 0.5, fy + fs * 0.6);
    f.quadraticBezierTo(fx - fs * 0.95, fy - fs * 0.1, fx, fy - fs);
    canvas.drawPath(f, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawPath(
      f,
      Paint()
        ..color = AppColors.red.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fs * 0.35),
    );

    // Four sparks, because a still crest reads as a sticker.
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + (math.pi / 2) * i;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (w * 0.40),
        2.2,
        Paint()..color = AppColors.measure.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) => false;
}
