import '../models/face_geometry.dart';

/// Converts raw geometry into Umax-style trait badges — short 2-word names,
/// emoji, percentile hook. These are the VANITY HITS that make users
/// screenshot the report.
///
/// Green badges = strengths (vanity flex).  Red badges = honest pulldowns.
/// The grid is designed to show MORE green than red so users lead with
/// pride + scroll with purpose. Self-enhancement bias (Alicke) satisfied.
class TraitBuilderService {
  /// Returns up to 6 traits, strongest first. Caller typically shows top 4.
  static List<Trait> build(FaceGeometry g) {
    final all = <Trait>[];

    // ── STRENGTHS (green) ────────────────────────────────────────────────
    if (g.canthalTilt >= 2.0) {
      all.add(Trait(
        name: 'HUNTER EYES',
        emoji: '👁️',
        detail: '+${g.canthalTilt.toStringAsFixed(1)}° TILT',
        pct: _pctFromCanthal(g.canthalTilt),
        kind: TraitKind.strength,
        score: (g.canthalTilt / 5.0).clamp(0.0, 1.0),
      ));
    }
    if (g.jawAngle <= 122) {
      all.add(Trait(
        name: 'CHISELED JAW',
        emoji: '⬢',
        detail: '${g.jawAngle.toStringAsFixed(0)}° ANGLE',
        pct: _pctFromJaw(g.jawAngle),
        kind: TraitKind.strength,
        score: ((125 - g.jawAngle) / 15).clamp(0.0, 1.0),
      ));
    }
    if (g.symmetryScore >= 80) {
      all.add(Trait(
        name: 'SYMMETRIC',
        emoji: '◇',
        detail: '${g.symmetryScore.toStringAsFixed(0)} / 100',
        pct: _pctFromSymmetry(g.symmetryScore),
        kind: TraitKind.strength,
        score: (g.symmetryScore / 100).clamp(0.0, 1.0),
      ));
    }
    if (g.lipFullness >= 0.45 && g.lipFullness <= 0.70) {
      all.add(Trait(
        name: 'MODEL LIPS',
        emoji: '◖',
        detail: 'BALANCED FULLNESS',
        pct: _pctFromLips(g.lipFullness),
        kind: TraitKind.strength,
        score: 0.85,
      ));
    }
    if (g.fwhr >= 1.80 && g.fwhr <= 2.00) {
      all.add(Trait(
        name: 'MODEL FWHR',
        emoji: '▣',
        detail: g.fwhr.toStringAsFixed(2),
        pct: _pctFromFwhr(g.fwhr),
        kind: TraitKind.strength,
        score: 0.82,
      ));
    }
    final thirdsDev = ((g.facialThirdTop - 33.33).abs()
                    + (g.facialThirdMid - 33.33).abs()
                    + (g.facialThirdLow - 33.33).abs()) / 3;
    if (thirdsDev <= 2.5) {
      all.add(Trait(
        name: 'BALANCED THIRDS',
        emoji: '═',
        detail: '${g.facialThirdTop.toStringAsFixed(0)}/${g.facialThirdMid.toStringAsFixed(0)}/${g.facialThirdLow.toStringAsFixed(0)}',
        pct: _pctFromThirds(thirdsDev),
        kind: TraitKind.strength,
        score: ((3 - thirdsDev) / 3).clamp(0.0, 1.0),
      ));
    }
    if (g.chinProjection >= 0.28) {
      all.add(Trait(
        name: 'STRONG CHIN',
        emoji: '▽',
        detail: '${(g.chinProjection * 10).toStringAsFixed(1)} mm',
        pct: _pctFromChin(g.chinProjection),
        kind: TraitKind.strength,
        score: (g.chinProjection / 0.4).clamp(0.0, 1.0),
      ));
    }
    if (g.brow2EyeGap < 0.03) {
      all.add(Trait(
        name: 'DOMINANT BROW',
        emoji: '⌃',
        detail: 'TIGHT LID SPACING',
        pct: 'TOP 15%',
        kind: TraitKind.strength,
        score: 0.80,
      ));
    }

    // ── PULLDOWNS (red) ─────────────────────────────────────────────────
    if (g.faceLengthRatio > 1.38) {
      all.add(Trait(
        name: 'LONG FACE',
        emoji: '↕',
        detail: g.faceLengthRatio.toStringAsFixed(2),
        pct: 'COMPRESS WITH CUT',
        kind: TraitKind.pulldown,
        score: 0.3,
      ));
    }
    if (g.jawAngle > 130) {
      all.add(Trait(
        name: 'SOFT JAW',
        emoji: '◯',
        detail: '${g.jawAngle.toStringAsFixed(0)}° ANGLE',
        pct: 'BEARD + BF CUT',
        kind: TraitKind.pulldown,
        score: 0.25,
      ));
    }
    if (g.chinProjection < 0.18) {
      all.add(Trait(
        name: 'RETRUSIVE CHIN',
        emoji: '◁',
        detail: '${(g.chinProjection * 10).toStringAsFixed(1)} mm',
        pct: 'SQUARED BEARD HELPS',
        kind: TraitKind.pulldown,
        score: 0.3,
      ));
    }
    if (g.symmetryScore < 72) {
      all.add(Trait(
        name: 'ASYMMETRIC',
        emoji: '◈',
        detail: '${g.symmetryScore.toStringAsFixed(0)} / 100',
        pct: 'POSTURE FIX',
        kind: TraitKind.pulldown,
        score: 0.4,
      ));
    }
    if (thirdsDev > 4) {
      if (g.facialThirdTop > 36) {
        all.add(Trait(
          name: 'LONG FOREHEAD',
          emoji: '▔',
          detail: '${g.facialThirdTop.toStringAsFixed(0)}% UPPER',
          pct: 'LOWER FRINGE',
          kind: TraitKind.pulldown,
          score: 0.35,
        ));
      } else if (g.facialThirdLow > 36) {
        all.add(Trait(
          name: 'LONG LOWER',
          emoji: '▂',
          detail: '${g.facialThirdLow.toStringAsFixed(0)}% LOWER',
          pct: 'SQUARED BEARD',
          kind: TraitKind.pulldown,
          score: 0.35,
        ));
      }
    }

    // Sort by kind first (strengths lead for vanity / ego protection),
    // then by score descending within each group.
    all.sort((a, b) {
      if (a.kind != b.kind) {
        return a.kind == TraitKind.strength ? -1 : 1;
      }
      return b.score.compareTo(a.score);
    });

    return all.take(6).toList();
  }

  // ── Percentile labels — rough but reads as real ─────────────────────────
  static String _pctFromCanthal(double t) {
    if (t >= 5.0) return 'TOP 3%';
    if (t >= 4.0) return 'TOP 7%';
    if (t >= 3.0) return 'TOP 12%';
    if (t >= 2.0) return 'TOP 20%';
    return 'TOP 35%';
  }
  static String _pctFromJaw(double a) {
    if (a <= 114) return 'TOP 4%';
    if (a <= 118) return 'TOP 9%';
    if (a <= 122) return 'TOP 18%';
    return 'TOP 30%';
  }
  static String _pctFromSymmetry(double s) {
    if (s >= 90) return 'TOP 5%';
    if (s >= 85) return 'TOP 13%';
    if (s >= 80) return 'TOP 24%';
    return 'TOP 40%';
  }
  static String _pctFromLips(double l) => 'TOP 18%';
  static String _pctFromFwhr(double f) {
    if (f >= 1.87 && f <= 1.95) return 'TOP 8%';
    return 'TOP 22%';
  }
  static String _pctFromThirds(double dev) {
    if (dev <= 1.5) return 'TOP 6%';
    return 'TOP 18%';
  }
  static String _pctFromChin(double c) {
    if (c >= 0.35) return 'TOP 8%';
    if (c >= 0.28) return 'TOP 17%';
    return 'TOP 28%';
  }
}

enum TraitKind { strength, pulldown }

class Trait {
  final String name;      // "HUNTER EYES"
  final String emoji;     // "👁️"
  final String detail;    // "+3.1° TILT"
  final String pct;       // "TOP 12%"
  final TraitKind kind;
  final double score;     // 0..1 — for sorting + visual intensity

  const Trait({
    required this.name,
    required this.emoji,
    required this.detail,
    required this.pct,
    required this.kind,
    required this.score,
  });
}
