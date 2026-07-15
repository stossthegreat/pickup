import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/face_geometry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The precision card — every measurement taken, translated into plain
/// English, with value + status dot. This is the "you actually measured me"
/// moment that differentiates us from PSL-style rating apps. Screenshot-ready.
class MeasurementGrid extends StatelessWidget {
  final FaceGeometry g;
  const MeasurementGrid({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.measure.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('MEASUREMENTS · MILLIMETER LEVEL',
                style: AppTypography.label.copyWith(
                  color: AppColors.measure, letterSpacing: 2.8, fontSize: 9)),
              const Spacer(),
              Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.measure, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('What we actually measured.',
            style: AppTypography.h1Italic.copyWith(
              fontSize: 15, color: AppColors.textSecondary, letterSpacing: 0.2)),
          const SizedBox(height: Sp.md),
          for (var i = 0; i < rows.length; i++) ...[
            _MetricRow(
              row: rows[i],
              delay: Duration(milliseconds: i * 45),
            ),
            if (i < rows.length - 1)
              Container(height: 1, color: AppColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 2)),
          ],
        ],
      ),
    );
  }

  List<_MetricData> _rows() => [
    _MetricData(
      label:   'Eye tilt',
      tech:    'canthal',
      value:   '${g.canthalTilt.toStringAsFixed(1)}°',
      ideal:   '3–5°',
      status:  g.canthalTilt >= 2 ? 3 : (g.canthalTilt >= 0 ? 2 : 1),
      plain:   g.canthalTilt >= 2 ? 'positive — hunter eye shape'
             : g.canthalTilt >= 0 ? 'neutral' : 'droopy, fightable with lid lift',
    ),
    _MetricData(
      label:   'Symmetry',
      tech:    'left ↔ right',
      value:   '${g.symmetryScore.toStringAsFixed(0)}/100',
      ideal:   '85+',
      status:  g.symmetryScore >= 85 ? 3 : (g.symmetryScore >= 70 ? 2 : 1),
      plain:   g.symmetryScore >= 85 ? 'exceptional'
             : g.symmetryScore >= 70 ? 'good — subtle asymmetry reads natural'
             : 'noticeable — posture + chewing-side adjustments help',
    ),
    _MetricData(
      label:   'Face thirds',
      tech:    'upper / mid / lower',
      value:   '${g.facialThirdTop.toStringAsFixed(0)}/${g.facialThirdMid.toStringAsFixed(0)}/${g.facialThirdLow.toStringAsFixed(0)}',
      ideal:   '33/33/33',
      status:  _thirdsStatus(g),
      plain:   _thirdsPlain(g),
    ),
    _MetricData(
      label:   'Face width ratio',
      tech:    'FWHR',
      value:   g.fwhr.toStringAsFixed(2),
      ideal:   '1.80–2.00',
      status:  _fwhrStatus(g.fwhr),
      plain:   _fwhrPlain(g.fwhr),
    ),
    _MetricData(
      label:   'Head shape',
      tech:    'length / width',
      value:   _capitalize(g.headShape),
      ideal:   'Oval',
      status:  g.headShape == 'oval' ? 3 : (g.headShape == 'square' ? 2 : 1),
      plain:   _headShapePlain(g),
    ),
    _MetricData(
      label:   'Jaw angle',
      tech:    'gonial',
      value:   '${g.jawAngle.toStringAsFixed(0)}°',
      ideal:   '115–125°',
      status:  (g.jawAngle >= 115 && g.jawAngle <= 125) ? 3
               : (g.jawAngle <= 135) ? 2 : 1,
      plain:   g.jawAngle <= 120 ? 'sharp, defined'
             : g.jawAngle <= 130 ? 'moderate — stubble sharpens it'
             : 'soft — body-fat + beard will rebuild edge',
    ),
    _MetricData(
      label:   'Chin projection',
      tech:    'forward from lip',
      value:   g.chinProjection.toStringAsFixed(2),
      ideal:   '0.25+',
      status:  g.chinProjection >= 0.25 ? 3 : (g.chinProjection >= 0.15 ? 2 : 1),
      plain:   g.chinProjection >= 0.25 ? 'forward — reads strong'
             : g.chinProjection >= 0.15 ? 'neutral'
             : 'retrusive — squared beard adds ~3mm virtual projection',
    ),
    _MetricData(
      label:   'Eye spacing',
      tech:    'interpupillary',
      value:   g.interpupillaryRatio.toStringAsFixed(2),
      ideal:   '0.44–0.48',
      status:  (g.interpupillaryRatio >= 0.44 && g.interpupillaryRatio <= 0.48) ? 3
               : (g.interpupillaryRatio >= 0.40 && g.interpupillaryRatio <= 0.52) ? 2 : 1,
      plain:   g.interpupillaryRatio < 0.42 ? 'close-set — reads intense'
             : g.interpupillaryRatio > 0.50 ? 'wide-set — reads boyish'
             : 'balanced',
    ),
    _MetricData(
      label:   'Brow-to-eye gap',
      tech:    'vertical',
      value:   g.brow2EyeGap.toStringAsFixed(3),
      ideal:   '0.03–0.05',
      status:  (g.brow2EyeGap >= 0.03 && g.brow2EyeGap <= 0.05) ? 3
               : (g.brow2EyeGap >= 0.02 && g.brow2EyeGap <= 0.07) ? 2 : 1,
      plain:   g.brow2EyeGap < 0.03 ? 'tight — reads dominant / brooding'
             : g.brow2EyeGap > 0.05 ? 'wide — reads softer'
             : 'balanced',
    ),
    _MetricData(
      label:   'Nose length',
      tech:    'relative to midface',
      value:   g.noseLengthRatio.toStringAsFixed(2),
      ideal:   '0.25–0.35',
      status:  (g.noseLengthRatio >= 0.25 && g.noseLengthRatio <= 0.35) ? 3
               : (g.noseLengthRatio >= 0.20 && g.noseLengthRatio <= 0.40) ? 2 : 1,
      plain:   g.noseLengthRatio < 0.25 ? 'short — proportional'
             : g.noseLengthRatio > 0.35 ? 'long — compensate with forehead exposure'
             : 'balanced',
    ),
    _MetricData(
      label:   'Lip fullness',
      tech:    'total lip area',
      value:   g.lipFullness.toStringAsFixed(2),
      ideal:   '0.4–0.7',
      status:  (g.lipFullness >= 0.4 && g.lipFullness <= 0.7) ? 3
               : (g.lipFullness >= 0.3 && g.lipFullness <= 0.8) ? 2 : 1,
      plain:   g.lipFullness < 0.4 ? 'thin — hydration + subtle volume reads best'
             : g.lipFullness > 0.7 ? 'full — preserve with SPF + hydration'
             : 'balanced',
    ),
    _MetricData(
      label:   'Philtrum',
      tech:    'upper-lip ridge',
      value:   g.philtrumRatio.toStringAsFixed(2),
      ideal:   '0.30–0.40',
      status:  (g.philtrumRatio >= 0.30 && g.philtrumRatio <= 0.40) ? 3
               : (g.philtrumRatio >= 0.25 && g.philtrumRatio <= 0.45) ? 2 : 1,
      plain:   g.philtrumRatio < 0.30 ? 'short'
             : g.philtrumRatio > 0.40 ? 'long — mustache shortens visually'
             : 'balanced',
    ),
  ];

  int _thirdsStatus(FaceGeometry g) {
    final dev = ((g.facialThirdTop - 33.33).abs()
                + (g.facialThirdMid - 33.33).abs()
                + (g.facialThirdLow - 33.33).abs()) / 3;
    if (dev <= 2) return 3;
    if (dev <= 5) return 2;
    return 1;
  }

  String _thirdsPlain(FaceGeometry g) {
    final dev = ((g.facialThirdTop - 33.33).abs()
                + (g.facialThirdMid - 33.33).abs()
                + (g.facialThirdLow - 33.33).abs()) / 3;
    if (dev <= 2) return 'near-perfect balance';
    if (g.facialThirdLow > 36) return 'long lower third — masculine read';
    if (g.facialThirdTop > 36) return 'long forehead — fringe compresses';
    if (g.facialThirdMid > 36) return 'long midface — shorter hair on top helps';
    return 'minor imbalance — grooming can compensate';
  }

  int _fwhrStatus(double v) {
    if (v >= 1.8 && v <= 2.0) return 3;
    if (v >= 1.65 && v <= 2.15) return 2;
    return 1;
  }

  String _fwhrPlain(double v) {
    if (v >= 2.0) return 'broad / dominant — skip wide haircuts';
    if (v >= 1.8) return 'ideal masculine band';
    if (v >= 1.65) return 'neutral — slightly narrow';
    return 'narrow — height-on-top cuts compensate';
  }

  String _headShapePlain(FaceGeometry g) {
    switch (g.headShape) {
      case 'long':   return 'long / narrow — long hair works against you';
      case 'broad':  return 'broad — skip crops, go taller on top';
      case 'square': return 'square jaw — short cuts carry';
      case 'round':  return 'round — add vertical via length or volume';
      case 'oval':
      default:       return 'oval — most cuts work, pick by jaw';
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _MetricData {
  final String label, tech, value, ideal, plain;
  final int status; // 1=weak, 2=neutral, 3=strong
  _MetricData({
    required this.label, required this.tech, required this.value,
    required this.ideal, required this.plain, required this.status,
  });
}

class _MetricRow extends StatelessWidget {
  final _MetricData row;
  final Duration delay;
  const _MetricRow({required this.row, required this.delay});

  @override
  Widget build(BuildContext context) {
    final color = row.status == 3 ? AppColors.signalGreen
                : row.status == 2 ? AppColors.signalAmber
                :                   AppColors.signalRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: color.withValues(alpha: 0.45), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 10),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(row.label,
                      style: AppTypography.h3.copyWith(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(row.tech,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textMuted, letterSpacing: 1.4, fontSize: 8)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(row.plain,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Value + ideal
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(row.value,
                  style: AppTypography.measurement.copyWith(
                    color: color, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text('ideal ${row.ideal}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textMuted, fontSize: 8, letterSpacing: 1.0)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay, duration: 300.ms)
      .slideX(begin: -0.02, end: 0, delay: delay, duration: 300.ms);
  }
}
