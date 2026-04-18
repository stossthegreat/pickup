import 'dart:math' as math;
import 'package:flutter/foundation.dart';

@immutable
class FaceGeometry {
  final double canthalTilt;        // degrees, positive = hunter eyes
  final double symmetryScore;      // 0–100, 100 = perfect symmetry
  final double facialThirdTop;     // % of face height (hairline→brow)
  final double facialThirdMid;     // % of face height (brow→nose base)
  final double facialThirdLow;     // % of face height (nose base→chin)
  final double fwhr;               // facial width-to-height ratio
  final double eyeSpacingRatio;    // interocular / face width
  final double jawAngle;           // degrees
  final double chinProjection;     // chin tip relative to nose
  final bool hasReliableData;

  const FaceGeometry({
    required this.canthalTilt,
    required this.symmetryScore,
    required this.facialThirdTop,
    required this.facialThirdMid,
    required this.facialThirdLow,
    required this.fwhr,
    required this.eyeSpacingRatio,
    required this.jawAngle,
    required this.chinProjection,
    required this.hasReliableData,
  });

  // Canthal tilt rating
  String get canthalTiltLabel {
    if (canthalTilt > 3.0) return 'Positive — hunter';
    if (canthalTilt > 0.5) return 'Neutral-positive';
    if (canthalTilt > -1.0) return 'Neutral';
    return 'Negative — drooping';
  }

  // Symmetry tier
  String get symmetryLabel {
    if (symmetryScore >= 88) return 'Exceptional';
    if (symmetryScore >= 78) return 'High';
    if (symmetryScore >= 65) return 'Average';
    return 'Below average';
  }

  // Facial thirds deviation from ideal (33/33/33)
  double get thirdsDeviation {
    final ideal = 33.33;
    return (math.pow(facialThirdTop - ideal, 2) +
            math.pow(facialThirdMid - ideal, 2) +
            math.pow(facialThirdLow - ideal, 2)) /
        3;
  }

  // FWHR interpretation
  String get fwhrLabel {
    if (fwhr >= 2.1) return 'High — dominant';
    if (fwhr >= 1.8) return 'Ideal range';
    return 'Low';
  }

  Map<String, String> get summaryMap => {
    'Canthal tilt': '${canthalTilt.toStringAsFixed(1)}° — $canthalTiltLabel',
    'Symmetry': '${symmetryScore.toStringAsFixed(0)}% — $symmetryLabel',
    'Facial thirds': '${facialThirdTop.toStringAsFixed(0)} / ${facialThirdMid.toStringAsFixed(0)} / ${facialThirdLow.toStringAsFixed(0)}',
    'FWHR': '${fwhr.toStringAsFixed(2)} — $fwhrLabel',
    'Eye spacing': '${(eyeSpacingRatio * 100).toStringAsFixed(0)}% of face width',
    'Jaw angle': '${jawAngle.toStringAsFixed(0)}°',
  };
}
