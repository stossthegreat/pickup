import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_geometry.dart';

class FaceGeometryService {
  /// Extract geometry measurements from ML Kit face detection result.
  static FaceGeometry computeGeometry(Face face, double imgW, double imgH) {
    final contours = face.contours;

    // ── Eye corner landmarks ────────────────────────────────────────────────
    final leftEyeContour  = contours[FaceContourType.leftEye]?.points ?? [];
    final rightEyeContour = contours[FaceContourType.rightEye]?.points ?? [];
    final faceOval        = contours[FaceContourType.face]?.points ?? [];
    final noseBridge      = contours[FaceContourType.noseBridge]?.points ?? [];
    final noseBottom      = contours[FaceContourType.noseBottom]?.points ?? [];
    final leftEyebrow     = contours[FaceContourType.leftEyebrowTop]?.points ?? [];

    final hasData = leftEyeContour.length >= 4 &&
        rightEyeContour.length >= 4 &&
        faceOval.length >= 10;

    if (!hasData) {
      return const FaceGeometry(
        canthalTilt: 0, symmetryScore: 70, facialThirdTop: 33,
        facialThirdMid: 33, facialThirdLow: 34, fwhr: 1.9,
        eyeSpacingRatio: 0.46, jawAngle: 125, chinProjection: 0,
        hasReliableData: false,
      );
    }

    // Normalize helper
    Offset norm(math.Point<int> p) =>
        Offset(p.x / imgW, p.y / imgH);

    // ── Canthal tilt ──────────────────────────────────────────────────────
    // Left eye: inner corner = first point, outer = last point (ML Kit ordering)
    final leftInner  = norm(leftEyeContour.first);
    final leftOuter  = norm(leftEyeContour.last);
    final rightInner = norm(rightEyeContour.last);
    final rightOuter = norm(rightEyeContour.first);

    final leftTiltRad  = math.atan2(
        -(leftOuter.dy - leftInner.dy), leftOuter.dx - leftInner.dx);
    final rightTiltRad = math.atan2(
        -(rightOuter.dy - rightInner.dy), rightOuter.dx - rightInner.dx);
    final canthalTilt  =
        ((leftTiltRad + rightTiltRad) / 2) * (180 / math.pi);

    // ── Eye centers ───────────────────────────────────────────────────────
    final leftEyeCX  = leftEyeContour.map((p) => p.x).reduce((a, b) => a + b) /
        leftEyeContour.length;
    final leftEyeCY  = leftEyeContour.map((p) => p.y).reduce((a, b) => a + b) /
        leftEyeContour.length;
    final rightEyeCX = rightEyeContour.map((p) => p.x).reduce((a, b) => a + b) /
        rightEyeContour.length;
    // ── Face bounding box from oval ────────────────────────────────────────
    final ovalXs = faceOval.map((p) => p.x.toDouble()).toList();
    final ovalYs = faceOval.map((p) => p.y.toDouble()).toList();
    final faceLeft   = ovalXs.reduce(math.min);
    final faceRight  = ovalXs.reduce(math.max);
    final faceTop    = ovalYs.reduce(math.min);
    final faceBottom = ovalYs.reduce(math.max);
    final faceWidth  = faceRight - faceLeft;
    final faceHeight = faceBottom - faceTop;

    if (faceWidth < 10 || faceHeight < 10) {
      return const FaceGeometry(
        canthalTilt: 0, symmetryScore: 70, facialThirdTop: 33,
        facialThirdMid: 33, facialThirdLow: 34, fwhr: 1.9,
        eyeSpacingRatio: 0.46, jawAngle: 125, chinProjection: 0,
        hasReliableData: false,
      );
    }

    // ── Symmetry ──────────────────────────────────────────────────────────
    final faceCX = (faceLeft + faceRight) / 2;
    final leftEyeDistFromCenter  = (faceCX - leftEyeCX).abs();
    final rightEyeDistFromCenter = (rightEyeCX - faceCX).abs();
    final eyeAsymmetry = (leftEyeDistFromCenter - rightEyeDistFromCenter).abs() /
        faceWidth;
    final symmetryScore = ((1.0 - eyeAsymmetry * 6.0).clamp(0.4, 1.0) * 100);

    // ── FWHR ──────────────────────────────────────────────────────────────
    // Width at cheekbones (approx middle of face oval)
    final midY        = (faceTop + faceBottom) / 2;
    final cheekPoints = faceOval.where((p) => (p.y - midY).abs() < faceHeight * 0.15);
    final cheekWidth  = cheekPoints.isEmpty
        ? faceWidth
        : (cheekPoints.map((p) => p.x.toDouble()).reduce(math.max) -
               cheekPoints.map((p) => p.x.toDouble()).reduce(math.min));
    // Height: brow to upper lip
    final browY      = leftEyebrow.isNotEmpty
        ? leftEyebrow.map((p) => p.y.toDouble()).reduce(math.min)
        : leftEyeCY - faceHeight * 0.05;
    final noseBaseY  = noseBottom.isNotEmpty
        ? noseBottom.map((p) => p.y.toDouble()).reduce(math.max)
        : leftEyeCY + faceHeight * 0.3;
    final upperLipY  = noseBaseY + (faceBottom - noseBaseY) * 0.3;
    final fwhrHeight = (upperLipY - browY).abs();
    final fwhr       = fwhrHeight > 0 ? cheekWidth / fwhrHeight : 1.9;

    // ── Facial thirds ─────────────────────────────────────────────────────
    final hairlineY = faceTop;
    final chin      = faceBottom;
    final totalH    = chin - hairlineY;
    final browYNorm = browY;
    final noseBaseYNorm = noseBaseY;

    final topThird  = (browYNorm - hairlineY) / totalH * 100;
    final midThird  = (noseBaseYNorm - browYNorm) / totalH * 100;
    final lowThird  = (chin - noseBaseYNorm) / totalH * 100;

    // ── Eye spacing ratio ─────────────────────────────────────────────────
    final interocular   = (rightEyeCX - leftEyeCX).abs();
    final eyeSpacingRatio = interocular / faceWidth;

    // ── Jaw angle (approx) ────────────────────────────────────────────────
    double jawAngle = 125;
    if (faceOval.length >= 16) {
      // Bottom quarter of face oval — left jaw, chin, right jaw
      final bottomPoints = faceOval
          .where((p) => p.y > faceTop + faceHeight * 0.65)
          .toList();
      if (bottomPoints.length >= 3) {
        final leftJaw  = bottomPoints
            .reduce((a, b) => a.x < b.x ? a : b);
        final rightJaw = bottomPoints
            .reduce((a, b) => a.x > b.x ? a : b);
        final chinPt   = bottomPoints
            .reduce((a, b) => a.y > b.y ? a : b);
        final v1x = leftJaw.x - chinPt.x;
        final v1y = leftJaw.y - chinPt.y;
        final v2x = rightJaw.x - chinPt.x;
        final v2y = rightJaw.y - chinPt.y;
        final dot = v1x * v2x + v1y * v2y;
        final mag = math.sqrt(v1x * v1x + v1y * v1y) *
                    math.sqrt(v2x * v2x + v2y * v2y);
        if (mag > 0) jawAngle = math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
      }
    }

    // ── Nose/chin projection ─────────────────────────────────────────────
    final noseTipY   = noseBridge.isNotEmpty
        ? noseBridge.map((p) => p.y.toDouble()).reduce(math.max)
        : 0.0;
    final chinProjection = faceHeight > 0
        ? (faceBottom - noseTipY) / faceHeight
        : 0.0;

    return FaceGeometry(
      canthalTilt: canthalTilt.clamp(-10.0, 10.0),
      symmetryScore: symmetryScore.clamp(0.0, 100.0),
      facialThirdTop: topThird.clamp(0.0, 100.0),
      facialThirdMid: midThird.clamp(0.0, 100.0),
      facialThirdLow: lowThird.clamp(0.0, 100.0),
      fwhr: fwhr.clamp(1.0, 3.0),
      eyeSpacingRatio: eyeSpacingRatio.clamp(0.2, 0.8),
      jawAngle: jawAngle.clamp(80.0, 180.0),
      chinProjection: chinProjection.clamp(0.0, 0.5),
      hasReliableData: true,
    );
  }

}
