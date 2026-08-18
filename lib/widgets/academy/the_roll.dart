import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/boon_service.dart';
import '../../services/rolodex_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';

/// THE ROLL — the roulette, built honestly.
///
/// The reel on the daily is theatre over a known result and says so.
/// This one is the real thing: he does not know where it lands, and it
/// genuinely might land on nothing. That's not a flaw to design around,
/// it IS the mechanic — variable-ratio reinforcement is the most
/// persistent schedule known, more persistent than always-reward,
/// precisely because the brain can't build a prediction. A wheel that
/// always pays is a cutscene with extra steps.
///
/// Two hard rules, both about keeping it clean:
///
///  1. IT ONLY EVER GIVES. There is no segment that takes something
///     away. Gambling for a bonus is a good time; gambling with what you
///     already earned is a different product and not one I'll build.
///
///  2. IT CANNOT PAY IN ANYTHING EARNED. No scores, no grades, no board
///     positions, no Rolodex cards. See BoonService for why: one woman
///     handed over by a wheel makes every woman he actually won worth
///     less, and he will remember which was which.
///
/// The physical design does the rest of the work — the pointer, the
/// deceleration, the tick as each segment passes under it. A wheel that
/// slows down is doing the same job as a woman taking four seconds to
/// answer: selling the gap between committing and knowing.
class TheRoll {
  /// Offer the wheel. Returns the boon he landed (after any chained
  /// spin), or null if he walked away without spinning.
  static Future<Boon?> show(
    BuildContext context, {
    required Color accent,
  }) async {
    return showGeneralDialog<Boon>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      barrierDismissible: false,
      barrierLabel: 'roll',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => _RollAct(accent: accent),
    );
  }

  /// Apply whatever he won. Kept out of the widget so the payout can't
  /// silently depend on a screen still being mounted.
  static Future<void> apply(Boon b) async {
    switch (b) {
      case Boon.headStart:
        await BoonService.grantHeadStart();
      case Boon.shield:
        final cold = await Rolodex.coldest();
        // No cards yet, or nothing cooling — the shield goes to whoever
        // is nearest the edge, and if he owns nobody it quietly becomes
        // a head start instead. A prize that does nothing is worse than
        // no prize.
        if (cold != null) {
          await Rolodex.shield(cold.girlId, days: BoonService.shieldDays);
        } else {
          await BoonService.grantHeadStart();
        }
      case Boon.nothing:
      case Boon.again:
        break;
    }
  }
}

class _RollAct extends StatefulWidget {
  final Color accent;
  const _RollAct({required this.accent});

  @override
  State<_RollAct> createState() => _RollActState();
}

class _RollActState extends State<_RollAct>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  /// Where the wheel comes to rest, in turns.
  double _target = 0;

  Boon? _landed;
  bool _spinning = false;
  bool _chained = false;
  int _lastTick = -1;

  static const _faces = Boon.values;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onFrame);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _settle();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onFrame);
    _c.dispose();
    super.dispose();
  }

  void _onFrame() {
    // One tick per segment under the pointer, thinning as it slows —
    // most of why a physical wheel feels alive is the sound of it
    // running out of energy.
    final idx = (_angle / (2 * math.pi / _faces.length)).floor();
    if (idx != _lastTick) {
      _lastTick = idx;
      if (_c.value < 0.99) {
        Feel.reel();
        Sfx.reelTick();
      }
    }
    setState(() {});
  }

  /// Radians travelled, decelerating hard.
  double get _angle =>
      Curves.easeOutQuart.transform(_c.value) * _target * 2 * math.pi;

  void _spin() {
    if (_spinning) return;
    final result = rollBoon(noBlank: _chained);
    final i = _faces.indexOf(result);
    final seg = 2 * math.pi / _faces.length;
    // Five full turns plus the offset that puts segment i under the
    // pointer, plus a nudge so it never stops dead-centre — a wheel that
    // lands perfectly every time reads as scripted.
    final jitter = (math.Random().nextDouble() - 0.5) * seg * 0.55;
    _target = 5 + ((_faces.length - i) * seg + jitter) / (2 * math.pi);
    setState(() {
      _spinning = true;
      _landed = result;
    });
    Sfx.hold();
    _c.forward(from: 0);
  }

  Future<void> _settle() async {
    final b = _landed;
    if (b == null || !mounted) return;
    if (b == Boon.nothing) {
      Feel.nearMiss();
      Sfx.nearMiss();
    } else {
      Feel.win();
      Sfx.win();
    }
    await TheRoll.apply(b);
    if (mounted) setState(() => _spinning = false);
  }

  void _again() {
    setState(() {
      _chained = true;
      _landed = null;
      _lastTick = -1;
    });
    _spin();
  }

  @override
  Widget build(BuildContext context) {
    final landed = _landed;
    final done = landed != null && !_spinning && _c.isCompleted;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
          child: Column(children: [
            const Spacer(),
            Text(_chained ? 'FREE SPIN' : 'THE ROLL',
                style: GoogleFonts.inter(
                  color: _chained ? kNeon : AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 26),

            // ── The wheel ────────────────────────────────────────────
            SizedBox(
              width: 260,
              height: 274,
              child: Stack(alignment: Alignment.topCenter, children: [
                Positioned(
                  top: 14,
                  child: Transform.rotate(
                    angle: _angle,
                    child: CustomPaint(
                      size: const Size(260, 260),
                      painter: _WheelPainter(
                          faces: _faces, accent: widget.accent),
                    ),
                  ),
                ),
                // The pointer, fixed. Everything moves under it.
                CustomPaint(
                  size: const Size(26, 20),
                  painter: _PointerPainter(color: widget.accent),
                ),
              ]),
            ),

            const SizedBox(height: 26),
            SizedBox(
              height: 92,
              child: done
                  ? _result(landed)
                  : Text(
                      _spinning
                          ? '...'
                          : 'It owes you nothing.\nThat\'s what makes it worth spinning.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      )),
            ),
            const Spacer(),

            if (!_spinning && landed == null)
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: 'SPIN',
                  color: widget.accent,
                  textColor: Colors.white,
                  pulse: true,
                  onTap: _spin,
                ),
              ),
            if (done)
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: landed == Boon.again ? 'SPIN IT' : 'TAKE IT',
                  color: landed == Boon.nothing ? AppColors.surface3 : kNeon,
                  textColor:
                      landed == Boon.nothing ? Colors.white : Colors.black,
                  onTap: landed == Boon.again
                      ? _again
                      : () => Navigator.of(context).pop(landed),
                ),
              ),
            const SizedBox(height: 8),
            if (!_spinning)
              TextButton(
                onPressed: () => Navigator.of(context).pop(_landed),
                child: Text(landed == null ? 'NOT NOW' : 'CLOSE',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    )),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _result(Boon b) {
    final blank = b == Boon.nothing;
    final tint = blank ? AppColors.textTertiary : kNeon;
    return Column(children: [
      Text(b.headline,
              style: GoogleFonts.inter(
                color: tint,
                fontSize: 20,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
                shadows: blank
                    ? null
                    : [Shadow(color: tint.withValues(alpha: 0.6), blurRadius: 26)],
              ))
          .animate()
          .fadeIn(duration: 260.ms)
          .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack),
      const SizedBox(height: 9),
      Text(b.detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ))
          .animate()
          .fadeIn(delay: 200.ms),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  PAINTERS
// ══════════════════════════════════════════════════════════════════════

class _WheelPainter extends CustomPainter {
  final List<Boon> faces;
  final Color accent;
  const _WheelPainter({required this.faces, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final seg = 2 * math.pi / faces.length;

    for (var i = 0; i < faces.length; i++) {
      // -pi/2 puts segment 0 under the pointer at rest.
      final start = -math.pi / 2 - seg / 2 + i * seg;
      final blank = faces[i] == Boon.nothing;
      final fill = blank
          ? AppColors.surface2
          : (faces[i] == Boon.again
              ? kNeon.withValues(alpha: 0.22)
              : accent.withValues(alpha: 0.16 + 0.06 * i));

      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        seg,
        true,
        Paint()..color = fill,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        seg,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.10),
      );

      // The label, laid along the segment's own radius so it reads at
      // rest and blurs into the spin the way a real wheel's does.
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: faces[i].label,
          style: GoogleFonts.inter(
            color: blank ? AppColors.textMuted : Colors.white,
            fontSize: 11,
            height: 1.15,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.75);

      canvas.save();
      canvas.translate(
          c.dx + math.cos(mid) * r * 0.58, c.dy + math.sin(mid) * r * 0.58);
      canvas.rotate(mid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Rim and hub — the two details that stop it reading as a pie chart.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = accent.withValues(alpha: 0.75));
    canvas.drawCircle(c, 16, Paint()..color = AppColors.base);
    canvas.drawCircle(
        c,
        16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.accent != accent || old.faces.length != faces.length;
}

class _PointerPainter extends CustomPainter {
  final Color color;
  const _PointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) => old.color != color;
}
