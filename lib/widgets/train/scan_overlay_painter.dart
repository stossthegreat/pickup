import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/face_metrics.dart';
import '../../theme/auralay_app_colors.dart';

/// Scan states drive the painter's visual stack.
enum ScanState { searching, scanning, locking, locked, training }

/// The AURALAY live scan overlay.
///
/// Rewritten (2026-04-22) after user feedback: "the mesh doesn't actually
/// go on my face — catches blinks but nothing else works."
///
/// Root causes from that feedback:
/// 1. Dots were 1.1px at 50% alpha — near-invisible on real devices.
/// 2. All contour points were flattened into one list, so the line pass
///    zigzagged across unrelated regions (face → eye → lip → nose…).
/// 3. Coord space was sensor-frame not preview-frame — the mesh literally
///    didn't know where the face was in the visible image.
///
/// New painter:
/// - Reads `metrics.contours` — a `Map<regionName, polyline>`. Each region
///   (face oval, left eye, right eye, upper lip, lower lip, etc) is drawn
///   as its own closed ghost-blue line. No more zigzag.
/// - Mesh dots now 2.6px with a soft glow underlay — readable even in
///   daylight on a phone screen.
/// - Eyes get a brighter accent pass (iris-tracking feel).
/// - The face-rect (bounding box) drives corner brackets so brackets
///   hug the face, not the screen.
/// - Coords are already preview-space 0..1 (normalized by face_detector_
///   service's norm() helper). Painter just plots at (x*W, y*H).
class ScanOverlayPainter extends CustomPainter {
  final ScanState state;
  final FaceMetrics? metrics;
  final double animValue;    // 0..1 loops
  final double lockProgress; // 0..1 one-shot during LOCKING

  const ScanOverlayPainter({
    required this.state,
    required this.metrics,
    required this.animValue,
    required this.lockProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    switch (state) {
      case ScanState.searching: _paintSearching(canvas, size);
      case ScanState.scanning:  _paintLiveFaceMesh(canvas, size, intensity: 0.85);
      case ScanState.locking:   _paintLiveFaceMesh(canvas, size, intensity: 1.0);
      case ScanState.locked:    _paintLiveFaceMesh(canvas, size, intensity: 1.0);
      case ScanState.training:  _paintLiveFaceMesh(canvas, size, intensity: 1.0);
    }
  }

  // ── SEARCHING — no face yet, show a hunting reticle ────────────────────────
  void _paintSearching(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer rotating dashed ring
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(animValue * math.pi * 2);
    _drawDashedArc(canvas, size.width * 0.38,
      Paint()
        ..color = AppColors.scanBlue.withValues(alpha: 0.32)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
      dashCount: 36);
    canvas.restore();

    // Inner counter-rotating ring
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-animValue * math.pi * 2 * 0.6);
    _drawDashedArc(canvas, size.width * 0.28,
      Paint()
        ..color = AppColors.scanBlue.withValues(alpha: 0.18)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
      dashCount: 24);
    canvas.restore();

    // Corner brackets — screen-level, because no face yet
    _drawCornerBrackets(canvas,
      Rect.fromCenter(center: Offset(cx, cy),
        width: size.width * 0.80, height: size.height * 0.60),
      AppColors.scanBlue.withValues(alpha: 0.50), 22);

    // Center pulse
    final pr = 3.0 + math.sin(animValue * math.pi * 2) * 1.2;
    canvas.drawCircle(Offset(cx, cy), pr,
      Paint()..color = AppColors.scanBlue.withValues(alpha: 0.80));
  }

  // ── LIVE FACE MESH — scanning / locking / locked / training all use this ──
  //
  // Draws, in order:
  //   1. Face-bbox corner brackets (hug the actual face, not the screen)
  //   2. Region polylines (face oval, eyes, lips, nose, brows) in ghost blue
  //   3. Mesh dots on every contour point (2.6px with glow)
  //   4. Eye highlights — bright blue iris markers + eye outline emphasis
  //   5. A single scan-line sweep during SCANNING state
  //   6. Lock brackets that tighten during LOCKING / LOCKED
  void _paintLiveFaceMesh(Canvas canvas, Size size, {required double intensity}) {
    final m = metrics;
    if (m == null) return;

    // 1. Corner brackets on the face bounding box
    if (m.faceRect != null) {
      final rect = Rect.fromLTRB(
        m.faceRect!.left   * size.width,
        m.faceRect!.top    * size.height,
        m.faceRect!.right  * size.width,
        m.faceRect!.bottom * size.height,
      );
      final bracketColor = state == ScanState.training
          ? AppColors.signalGreen.withValues(alpha: 0.55)
          : AppColors.scanBlue.withValues(alpha: 0.55 * intensity);
      _drawCornerBrackets(canvas, rect, bracketColor, 20);
    }

    // 2. Region polylines — each contour drawn as its OWN line.
    //    Thin, glowing, readable — user wanted "more lines so I can see my
    //    eyes, less beady." So lines do the heavy lifting, dots are subtle.
    final lineAlpha = 0.80 * intensity;
    for (final entry in m.contours.entries) {
      final pts = entry.value;
      if (pts.length < 2) continue;
      // Eyes get brightest emphasis — they're the hero feature.
      final isEye = entry.key.contains('Eye');
      final color = isEye
          ? AppColors.scanBlue.withValues(alpha: (lineAlpha + 0.15).clamp(0.0, 1.0))
          : AppColors.scanBlue.withValues(alpha: lineAlpha * 0.75);
      final stroke = isEye ? 1.8 : 1.1;

      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final x = pts[i].dx * size.width;
        final y = pts[i].dy * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Glow underlay — gives the mesh the "ghost" feel without being beady.
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 3
        ..color = color.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

      // Crisp foreground stroke
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color);
    }

    // 3. Subtle dots ONLY on the face oval and face boundary contours —
    //    NOT on eye contours (those stay clean so the user can actually see
    //    their eyes). Dots are small (1.3px) with a tiny glow halo.
    final dotPaint = Paint()
      ..color = AppColors.scanBlue.withValues(alpha: 0.85 * intensity)
      ..style = PaintingStyle.fill;
    final dotGlow = Paint()
      ..color = AppColors.scanBlue.withValues(alpha: 0.28 * intensity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final entry in m.contours.entries) {
      // Skip eye regions — let the eyes breathe.
      if (entry.key.contains('Eye')) continue;
      for (final p in entry.value) {
        final pos = Offset(p.dx * size.width, p.dy * size.height);
        canvas.drawCircle(pos, 2.4, dotGlow);
        canvas.drawCircle(pos, 1.3, dotPaint);
      }
    }

    // 4. Eye iris markers — sit exactly on the landmark position, bright.
    //    These are the "gaze tracker" cue the user looks for.
    //    (Note: ML Kit face_detection returns the EYE CENTER landmark —
    //    not the iris itself. It tracks HEAD position, not GAZE. For true
    //    iris/gaze tracking we'd need MediaPipe iris_landmarker or ARKit.)
    void drawIris(Offset? pos) {
      if (pos == null) return;
      final c = Offset(pos.dx * size.width, pos.dy * size.height);
      canvas.drawCircle(c, 14, Paint()
        ..color = AppColors.scanBlue.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(c, 9, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.scanBlue);
      canvas.drawCircle(c, 3.2, Paint()..color = AppColors.scanBlue);
    }
    drawIris(m.leftEyePos);
    drawIris(m.rightEyePos);

    // 5. Scan sweep during SCANNING — horizontal line crossing the face rect
    if (state == ScanState.scanning && m.faceRect != null) {
      final rect = m.faceRect!;
      final top    = rect.top    * size.height;
      final bottom = rect.bottom * size.height;
      final sweepT = (animValue * 2) % 1.0;
      final sweepY = top + (bottom - top) * sweepT;
      final left   = rect.left  * size.width;
      final right  = rect.right * size.width;
      canvas.drawLine(
        Offset(left  - 12, sweepY),
        Offset(right + 12, sweepY),
        Paint()
          ..color = AppColors.scanBlue.withValues(alpha: 0.80)
          ..strokeWidth = 1.4);
    }

    // 6. Lock brackets contract during LOCKING
    if (state == ScanState.locking && m.faceRect != null) {
      final rect = Rect.fromLTRB(
        m.faceRect!.left   * size.width,
        m.faceRect!.top    * size.height,
        m.faceRect!.right  * size.width,
        m.faceRect!.bottom * size.height,
      );
      _drawLockArcs(canvas, rect, lockProgress);
    }
  }

  // ── Corner brackets around a rectangle ─────────────────────────────────────
  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color, double arm) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // TL
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(arm, 0), p);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, arm), p);
    // TR
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-arm, 0), p);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, arm), p);
    // BL
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(arm, 0), p);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -arm), p);
    // BR
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-arm, 0), p);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -arm), p);
  }

  void _drawLockArcs(Canvas canvas, Rect rect, double t) {
    final p = Paint()
      ..color = AppColors.scanBlue.withValues(alpha: 0.9 * t)
      ..strokeWidth = 2.2 + t * 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final inset = rect.shortestSide * 0.08 * t;
    final r = rect.deflate(inset);
    final arm = rect.shortestSide * 0.18 * (1 - t * 0.4);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(arm, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, arm), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(-arm, 0), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, arm), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(arm, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -arm), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-arm, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -arm), p);
  }

  void _drawDashedArc(Canvas canvas, double radius, Paint paint, {
    required int dashCount,
  }) {
    const twoPi = 2 * math.pi;
    final arcLen = twoPi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      final start = i * arcLen;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start, arcLen * 0.8, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter old) =>
    old.state != state ||
    old.metrics != metrics ||
    old.animValue != animValue ||
    old.lockProgress != lockProgress;
}
