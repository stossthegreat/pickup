import 'dart:math' as math;
import '../models/face_geometry.dart';

/// Reference geometry profile for an archetype. Values are normalized
/// targets derived from composite studies of celebrity/archetypal faces
/// — close enough to ring true, aspirational enough to drive sharing.
class Archetype {
  final String name;
  final String tagline;
  final String story;
  final double canthalTilt;
  final double symmetryScore;
  final double thirdsBalance; // composite: deviation from 33/33/33 (inverted)
  final double fwhr;
  final double eyeSpacingRatio;
  final double jawAngle;
  final double chinProjection;

  const Archetype({
    required this.name,
    required this.tagline,
    required this.story,
    required this.canthalTilt,
    required this.symmetryScore,
    required this.thirdsBalance,
    required this.fwhr,
    required this.eyeSpacingRatio,
    required this.jawAngle,
    required this.chinProjection,
  });
}

class ArchetypeMatch {
  final Archetype archetype;
  final double match; // 0..1 → display as %
  const ArchetypeMatch(this.archetype, this.match);
}

class ArchetypeService {
  /// Universal archetype library. Named by FEATURE PROFILE, not ethnicity
  /// or culture. Each label is short, identity-forming, globally readable.
  /// Users tell friends "I'm a MONARCH" — that's the virality lever.
  static const library = <Archetype>[
    Archetype(
      name: 'MONARCH',
      tagline: 'Elite across every axis',
      story:
        'Top-tier across the full measurement set. Symmetric, defined, '
        'proportional. The apex read — rare, camera-ready.',
      canthalTilt: 3.5,
      symmetryScore: 92,
      thirdsBalance: 0.95,
      fwhr: 1.92,
      eyeSpacingRatio: 0.46,
      jawAngle: 118,
      chinProjection: 3.5,
    ),
    Archetype(
      name: 'HUNTER',
      tagline: 'Sharp eyes, sharp jaw',
      story:
        'Positive canthal tilt and a defined mandible. Reads intense, '
        'unbothered, magnetic. Your eyes do the work before you speak.',
      canthalTilt: 4.2,
      symmetryScore: 86,
      thirdsBalance: 0.88,
      fwhr: 1.88,
      eyeSpacingRatio: 0.45,
      jawAngle: 116,
      chinProjection: 3.0,
    ),
    Archetype(
      name: 'SOVEREIGN',
      tagline: 'Classical proportion',
      story:
        'Near-golden thirds, balanced FWHR, strong symmetry. Reads timeless '
        'over trendy. The sculptor\'s template.',
      canthalTilt: 2.8,
      symmetryScore: 90,
      thirdsBalance: 0.96,
      fwhr: 1.85,
      eyeSpacingRatio: 0.46,
      jawAngle: 121,
      chinProjection: 2.8,
    ),
    Archetype(
      name: 'EXECUTIVE',
      tagline: 'Authority, presence, dominance',
      story:
        'Forward chin, wide FWHR, mature structural weight. Reads '
        'authoritative — the face that runs the room.',
      canthalTilt: 1.8,
      symmetryScore: 82,
      thirdsBalance: 0.85,
      fwhr: 2.05,
      eyeSpacingRatio: 0.47,
      jawAngle: 119,
      chinProjection: 4.0,
    ),
    Archetype(
      name: 'SCULPTED',
      tagline: 'Angular, carved, high-contrast',
      story:
        'Pronounced zygomatic and jaw angle, strong brow ridge. Reads '
        'photographic — hard shadows and defined lines.',
      canthalTilt: 3.2,
      symmetryScore: 84,
      thirdsBalance: 0.86,
      fwhr: 2.10,
      eyeSpacingRatio: 0.45,
      jawAngle: 114,
      chinProjection: 3.6,
    ),
    Archetype(
      name: 'PROTOTYPE',
      tagline: 'Clean foundation · room to build',
      story:
        'Balanced geometry with upside on every axis. Nothing is breaking; '
        'nothing is elite yet. High-leverage starting point.',
      canthalTilt: 2.0,
      symmetryScore: 78,
      thirdsBalance: 0.82,
      fwhr: 1.80,
      eyeSpacingRatio: 0.46,
      jawAngle: 124,
      chinProjection: 2.5,
    ),
  ];

  static ArchetypeMatch bestMatch(FaceGeometry g) {
    final matches = library.map((a) => ArchetypeMatch(a, _similarity(g, a))).toList();
    matches.sort((a, b) => b.match.compareTo(a.match));
    return matches.first;
  }

  static List<ArchetypeMatch> rankAll(FaceGeometry g) {
    final matches = library.map((a) => ArchetypeMatch(a, _similarity(g, a))).toList();
    matches.sort((a, b) => b.match.compareTo(a.match));
    return matches;
  }

  /// Weighted inverse-distance similarity, mapped to 0..1.
  /// Each axis is first normalized so its natural range contributes ~equally.
  static double _similarity(FaceGeometry g, Archetype a) {
    final userThirdsBalance = _thirdsBalanceOf(g);
    final components = <(double /*user*/, double /*target*/, double /*scale*/, double /*w*/)>[
      (g.canthalTilt,      a.canthalTilt,      6.0,   1.3),
      (g.symmetryScore,    a.symmetryScore,    25.0,  1.0),
      (userThirdsBalance,  a.thirdsBalance,    0.30,  1.1),
      (g.fwhr,             a.fwhr,             0.50,  1.4),
      (g.eyeSpacingRatio,  a.eyeSpacingRatio,  0.10,  0.8),
      (g.jawAngle,         a.jawAngle,         18.0,  1.3),
      (g.chinProjection,   a.chinProjection,   5.0,   1.0),
    ];

    double sumWeighted = 0;
    double sumWeights  = 0;
    for (final (u, t, scale, w) in components) {
      final dev = ((u - t) / scale).abs();
      final axisSim = math.max(0.0, 1.0 - dev);
      sumWeighted += axisSim * w;
      sumWeights  += w;
    }
    final raw = sumWeighted / sumWeights;
    // Expand the middle of the distribution so archetypes feel distinct
    // (75 % never reads as "meh" — push toward decisive match).
    return math.pow(raw, 0.75).toDouble().clamp(0.0, 1.0);
  }

  static double _thirdsBalanceOf(FaceGeometry g) {
    const ideal = 33.33;
    final dev = math.sqrt(
      (math.pow(g.facialThirdTop - ideal, 2) +
       math.pow(g.facialThirdMid - ideal, 2) +
       math.pow(g.facialThirdLow - ideal, 2)) / 3,
    );
    return (1.0 - dev / 10).clamp(0.0, 1.0);
  }
}
