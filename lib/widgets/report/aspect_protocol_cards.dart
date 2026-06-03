import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/face_geometry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// ASPECT PROTOCOL CARDS — replaces the loose "FIXES" text cards.
///
/// Three named axes the apprentice can actually move in 60 days. Each
/// card shows: the axis, a science-anchored daily-plan teaser (three
/// rolling phases over the 60 days), and a START 60-DAY PROTOCOL CTA
/// that routes to `/protocol` with that axis as the chosen pulldown
/// — the existing ProtocolService picks up the right template and
/// scheduler.
///
/// Skin = highest-ROI by evidence (tretinoin + SPF + sleep). Jaw =
/// the bones+composition axis users care about most. Hair = AGA early-
/// stage intervention with the strongest RCT base in the literature.
/// The other six protocol axes (Hunter Eyes, Symmetry, Chin, Posture,
/// Puffiness, Foundations) stay available through ProtocolService
/// but aren\'t surfaced as top-level cards — the data is unanimous
/// that those three carry most of the realistic ROI.
class AspectProtocolCards extends StatelessWidget {
  final FaceGeometry geometry;
  final String?      savedImagePath;
  const AspectProtocolCards({
    super.key,
    required this.geometry,
    this.savedImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final aspects = _aspects(geometry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('60-DAY PROTOCOLS',
          style: AppTypography.label.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 2.6,
            fontSize: 10.5,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Each plan targets ONE axis. Clean. Daily. Science.',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 11.5,
            height: 1.4,
            fontStyle: FontStyle.italic,
          )),
        const SizedBox(height: 12),
        for (int i = 0; i < aspects.length; i++) ...[
          _AspectCard(
            aspect: aspects[i],
            onTap: () {
              HapticFeedback.mediumImpact();
              context.push(
                '/protocol',
                extra: {
                  'axis':           aspects[i].axisKey,
                  'pulldown':       aspects[i].pulldownString,
                  'geometry':       geometry,
                  'savedImagePath': savedImagePath,
                },
              );
            },
          ),
          if (i < aspects.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─── Aspect catalogue ──────────────────────────────────────────────────
  //
  // Order is by realistic ROI per the verified-evidence research: skin
  // (tretinoin + SPF + sleep) is the cheapest fastest visible win, jaw
  // is the structural one most users came for, hair is the AGA
  // intervention with the deepest RCT base. Each entry carries the
  // axis key used by ProtocolService and the three 14/30/60 day-band
  // teasers rendered on the card body.
  List<_Aspect> _aspects(FaceGeometry g) {
    return [
      _Aspect(
        axisKey:        'skin',
        pulldownString: 'Skin',
        title:          'SKIN',
        oneLiner:       'The fastest visible win on the face.',
        evidence:       'Tretinoin + SPF50 + 7-9h sleep — RCT-backed',
        color:          AppColors.signalGreen,
        phases: const [
          _Phase(label: 'DAYS 1-14',  body: 'Baseline photos. SPF 30+ every AM. Tretinoin 0.025% every third night. Sleep on your back.'),
          _Phase(label: 'DAYS 15-30', body: 'Tretinoin nightly. Add niacinamide 5% AM. Alcohol ≤4/wk. Track skin clarity sub-score weekly.'),
          _Phase(label: 'DAYS 31-60', body: 'Re-scan day 45 and 60. Hydration audit. Ramp retinoid if tolerated. Lock the routine.'),
        ],
      ),
      _Aspect(
        axisKey:        'jaw',
        pulldownString: 'Jaw definition',
        title:          'JAW',
        oneLiner:       'Bones, masseter, and the 12-14% body-fat unlock.',
        evidence:       'Sell 2017: upper-body strength = 70% of body attractiveness variance',
        color:          AppColors.red,
        phases: const [
          _Phase(label: 'DAYS 1-14',  body: 'Baseline weight + side profile. Compound lifts 3-5×/wk. Neck training 2×/wk. Protein 1.6-2.2 g/kg.'),
          _Phase(label: 'DAYS 15-30', body: 'Bodyfat audit. If above 18%, lean cut. Hard gum 10 min/day for masseter. Track week-over-week jaw line photo.'),
          _Phase(label: 'DAYS 31-60', body: 'Re-scan day 45. Refine beard line along the inferior mandibular border. Reassess composition vs jaw definition score.'),
        ],
      ),
      _Aspect(
        axisKey:        'hair',
        pulldownString: 'Hair',
        title:          'HAIR',
        oneLiner:       'AGA early-stage intervention — measurable in 6 months.',
        evidence:       'Kaufman 2003: finasteride 1mg = 93% reduction in further visible loss at 5 years',
        color:          AppColors.measure,
        phases: const [
          _Phase(label: 'DAYS 1-14',  body: 'Hairline baseline photo at the same lighting + angle. Sleep on a silk pillowcase. Audit hairline progression with a derm if Norwood 2+.'),
          _Phase(label: 'DAYS 15-30', body: 'Topical minoxidil 5% AM + PM if recession visible. Hairline track every 2 weeks. Consult re: oral finasteride 1mg.'),
          _Phase(label: 'DAYS 31-60', body: 'Re-scan + hairline photo day 60. Expect shedding wks 2-8, regrowth phase. Judge density at 6 months, not now.'),
        ],
      ),
    ];
  }
}

class _Aspect {
  final String        axisKey;        // ProtocolService canonical key
  final String        pulldownString; // String resolveAxis maps to axisKey
  final String        title;
  final String        oneLiner;
  final String        evidence;       // ≤80 chars, science-anchored
  final Color         color;
  final List<_Phase>  phases;
  const _Aspect({
    required this.axisKey,
    required this.pulldownString,
    required this.title,
    required this.oneLiner,
    required this.evidence,
    required this.color,
    required this.phases,
  });
}

class _Phase {
  final String label;
  final String body;
  const _Phase({required this.label, required this.body});
}

class _AspectCard extends StatelessWidget {
  final _Aspect       aspect;
  final VoidCallback  onTap;
  const _AspectCard({required this.aspect, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(
              color: aspect.color.withValues(alpha: 0.55), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: aspect.color.withValues(alpha: 0.16),
                blurRadius: 18, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: aspect.color,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(aspect.title,
                      style: AppTypography.label.copyWith(
                        color: Colors.black, fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('60-day protocol',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontStyle: FontStyle.italic,
                      )),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: aspect.color.withValues(alpha: 0.7), size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(aspect.oneLiner,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                )),
              const SizedBox(height: 6),
              Text(aspect.evidence,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  height: 1.4,
                )),
              const SizedBox(height: 12),
              for (final p in aspect.phases) ...[
                _PhaseRow(phase: p, color: aspect.color),
                if (p != aspect.phases.last) const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aspect.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: aspect.color.withValues(alpha: 0.55),
                    width: 1.0,
                  ),
                ),
                child: Text('START 60-DAY PROTOCOL',
                  style: AppTypography.label.copyWith(
                    color: aspect.color,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final _Phase phase;
  final Color  color;
  const _PhaseRow({required this.phase, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(phase.label,
                style: AppTypography.label.copyWith(
                  color: color,
                  fontSize: 9.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                )),
              const SizedBox(height: 2),
              Text(phase.body,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                )),
            ],
          ),
        ),
      ],
    );
  }
}
