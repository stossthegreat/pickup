import 'package:flutter/material.dart';

import '../../models/face_metrics.dart';

/// AURALAY's face overlay — clean translucent blue lines around the
/// EYES and the LIPS, plus two fixation dots near the top of the
/// screen for the apprentice to lock his gaze onto during a drill.
///
/// Design brief (verbatim from the user): "lines around the eyes and
/// then around the mouth blue but like translucent like see through
/// blue clean" and "something on the screen for the user to
/// concentrate on like maybe two red dots a bit up the screen".
///
/// What this paints:
///   - Ice-blue arcs lifted ABOVE each eye (upper-lid → brow), never
///     across the eyeball — the eyes stay clean and unobstructed
///   - Ice-blue contours along the four lip segments (upperLipTop,
///     upperLipBottom, lowerLipTop, lowerLipBottom)
///   - Two small ruby-red fixation dots in the upper third of the
///     screen, spaced like an imagined partner's eyes — the
///     apprentice locks gaze on these during a drill
///
/// What it deliberately does NOT paint:
///   - Face oval, eyebrows, nose, mesh dots — visual noise
///
/// Mirror correction: iOS auto-mirrors the front-cam preview but
/// MLKit returns landmarks in raw sensor frame. We flip x before
/// plotting so the lines slide WITH the apprentice's face.
class AuralayFaceOverlayPainter extends CustomPainter {
  final FaceMetrics? metrics;
  /// 0..1 pulse — drives a subtle alpha lift on the fixation dots so
  /// they breathe rather than sit dead on the screen.
  final double pulse;
  /// True when the gaze engine reports locked-on. Brightens the eyes
  /// and the fixation dots together — confirms the lock.
  final bool isLocked;
  /// When true, draws the red fixation dots. Off during the warm-up
  /// and the score card; on during ritual phases.
  final bool showFixation;

  /// Translucent ice blue — the only colour for face contours.
  static const Color _blue = Color(0xFFAFD3FF);

  /// Ruby red — the only colour for the fixation dots.
  static const Color _red = Color(0xFFFF3D45);

  const AuralayFaceOverlayPainter({
    required this.metrics,
    required this.pulse,
    required this.isLocked,
    this.showFixation = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final m = metrics;

    // ── EYES — a clean arc ABOVE each eye, never across it ──────────
    // The eyes are the whole point of the app; a closed loop drawn over
    // the eyeball looked like a smudge and blocked the gaze. Instead we
    // trace only the upper-lid points and LIFT them toward the brow, so
    // it reads as a sleek tracking accent that leaves the eyes clean.
    if (m != null) {
      final eyeAlpha = 0.55 + (isLocked ? 0.15 + pulse * 0.05 : 0.0);
      final eyePaint = Paint()
        ..color = _blue.withValues(alpha: eyeAlpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final eyeGlow = Paint()
        ..color = _blue.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      for (final key in const ['leftEye', 'rightEye']) {
        final pts = m.contours[key];
        if (pts == null || pts.length < 3) continue;
        final path = _upperLidArc(pts, size);
        if (path == null) continue;
        canvas.drawPath(path, eyeGlow);
        canvas.drawPath(path, eyePaint);
      }
      // Lips intentionally NOT drawn — the contour over the mouth read as
      // visual noise. Smile is still measured (smileAuthenticity feeds
      // scoring); we just don't paint it.
    }

    // ── FIXATION DOTS — two ruby targets the apprentice locks onto.
    // Positioned in the upper third of the screen, spaced like an
    // imagined partner's eyes. Fixed screen coords (not face-relative)
    // — the point is to give him an EXTERNAL gaze target, the way a
    // real conversation does.
    if (showFixation) {
      final dotAlpha = 0.78 + (isLocked ? 0.15 : 0.0) + pulse * 0.05;
      final dotColor = _red.withValues(alpha: dotAlpha.clamp(0.0, 1.0));
      final dotPaint = Paint()..color = dotColor;
      final dotGlow = Paint()
        ..color = dotColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      // Vertical position: 28% from the top. Horizontal: 34% and
      // 66% — roughly an inter-pupillary spacing for the screen.
      final y = size.height * 0.28;
      final leftDot  = Offset(size.width * 0.34, y);
      final rightDot = Offset(size.width * 0.66, y);
      const r = 6.5;

      canvas.drawCircle(leftDot,  r + 4, dotGlow);
      canvas.drawCircle(rightDot, r + 4, dotGlow);
      canvas.drawCircle(leftDot,  r, dotPaint);
      canvas.drawCircle(rightDot, r, dotPaint);
    }
  }

  /// Builds an open arc that hugs the UPPER lid and is lifted toward
  /// the brow, so nothing is ever drawn across the eyeball. Takes the
  /// contour points above the eye's vertical centre, sorts them L→R,
  /// and shifts them up by a fraction of the eye's height.
  Path? _upperLidArc(List<Offset> pts, Size size) {
    double minY = double.infinity, maxY = -double.infinity, sumY = 0;
    for (final p in pts) {
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
      sumY += p.dy;
    }
    final centreY = sumY / pts.length;
    final height = (maxY - minY);
    // Lift the arc up off the lid, toward the brow.
    final lift = height * 0.55;

    final upper = pts.where((p) => p.dy <= centreY + height * 0.05).toList()
      ..sort((a, b) => a.dx.compareTo(b.dx));
    if (upper.length < 2) return null;

    final path = Path();
    for (int i = 0; i < upper.length; i++) {
      // X-flip for iOS front-cam mirror; lift y toward the brow.
      final x = (1.0 - upper[i].dx) * size.width;
      final y = (upper[i].dy - lift) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant AuralayFaceOverlayPainter old) =>
      old.metrics      != metrics      ||
      old.pulse        != pulse        ||
      old.isLocked     != isLocked     ||
      old.showFixation != showFixation;
}
