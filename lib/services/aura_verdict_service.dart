import 'dart:math';
import '../models/face_metrics.dart';

/// Elite verdict engine.
///
/// Takes a session's averaged metrics and produces:
///   * tier word           (single-word brand stamp — UNTOUCHABLE / MAGNETIC / …)
///   * one-line roast      (brutal, screenshot-ready, charisma-coach voice)
///   * score               (0–100 — already computed by the detector, surfaced here)
///   * dimension labels    (which of the four dimensions drove the result)
///
/// The big upgrade vs. the old service: roasts and strength calls now reference
/// the FOUR dimensions (Presence / Composure / Warmth / Range), not just the
/// raw signals. This lets the share card and post-session reveal tell a
/// coherent story about WHY the score landed where it did.
class AuraVerdictService {
  /// Build the verdict from a session's averaged metrics.
  ///
  /// All dimension values are 0–100.
  static AuraVerdict fromSession({
    required int score,
    required double presencePct,
    required double composurePct,
    required double warmthPct,
    required double rangePct,
    // Legacy raw signals — kept for the failure-triage logic that picks a
    // targeted roast line. If the caller only has the old 4-metric shape,
    // they can pass 0s and the engine gracefully falls back to dimensions.
    double eyeContactPct = 0,
    double stabilityPct  = 0,
    double smilePct      = 0,
    double blinkRate     = 0,
  }) {
    final tier = _tierFor(score);

    final dims = <_DimScore>[
      _DimScore('Presence',  presencePct),
      _DimScore('Composure', composurePct),
      _DimScore('Warmth',    warmthPct),
      _DimScore('Range',     rangePct),
    ];
    dims.sort((a, b) => b.value.compareTo(a.value));
    final strongest = dims.first;
    final weakest   = dims.last;

    final roast = _roastFor(
      score: score,
      weakest: weakest,
      strongest: strongest,
      eyeContactPct: eyeContactPct,
      stabilityPct: stabilityPct,
      blinkRate: blinkRate,
    );

    return AuraVerdict(
      score: score,
      tier: tier,
      roast: roast,
      strongestDimension: strongest.name,
      weakestDimension:   weakest.name,
      dimensionPcts: {
        for (final d in dims) d.name: d.value,
      },
    );
  }

  /// Legacy adapter — keeps old callers working while we migrate.
  static AuraVerdict fromSessionAverages({
    required int score,
    required double eyeContactPct,
    required double stabilityPct,
    required double smilePct,
    required double blinkRate,
  }) {
    // Derive loose dimension proxies from the raw signals so the tier/roast
    // logic still has something to chew on when the caller hasn't migrated.
    final presence  = (eyeContactPct * 0.65 + stabilityPct * 0.35);
    final composure = _blinkNormalised(blinkRate) * 100 * 0.55 + stabilityPct * 0.45;
    final warmth    = smilePct * 0.85 + 15;
    final range     = 50.0; // unknown — neutral

    return fromSession(
      score: score,
      presencePct:  presence,
      composurePct: composure,
      warmthPct:    warmth,
      rangePct:     range,
      eyeContactPct: eyeContactPct,
      stabilityPct:  stabilityPct,
      smilePct:      smilePct,
      blinkRate:     blinkRate,
    );
  }

  /// Convenience for live-frame metrics (less ideal — averages are stronger).
  static AuraVerdict fromMetrics(FaceMetrics m) {
    return fromSession(
      score:        m.overallAura.round(),
      presencePct:  m.presencePct,
      composurePct: m.composurePct,
      warmthPct:    m.warmthPct,
      rangePct:     m.rangePct,
      eyeContactPct: m.eyeContactPct,
      stabilityPct:  m.stabilityPct,
      smilePct:      m.smilePct,
      blinkRate:     m.blinkRate,
    );
  }

  static double _blinkNormalised(double r) {
    if (r == 0) return 0.6;
    if (r < 8)  return r / 8.0;
    if (r <= 18) return 1.0;
    return max(0, 1.0 - (r - 18) / 14.0);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TIER LADDER — single-word brand stamps
  // ══════════════════════════════════════════════════════════════════════

  static String _tierFor(int score) {
    if (score >= 92) return 'UNTOUCHABLE';
    if (score >= 85) return 'MAGNETIC';
    if (score >= 75) return 'SHARP';
    if (score >= 65) return 'COMPOSED';
    if (score >= 50) return 'FOUNDATION';
    if (score >= 35) return 'GROWING';
    return 'RAW';
  }

  /// Dark-charisma tier ladder for the SEDUCTION TEST specifically.
  /// Hits a different register than the charisma-test ladder — pulls
  /// vocabulary from the seduction-research framing (predator / phantom /
  /// apex). Use [seductionTierFor] when reporting a seduction-test score.
  static String seductionTierFor(int score) {
    if (score >= 92) return 'THE PHANTOM';
    if (score >= 85) return 'THE APEX';
    if (score >= 75) return 'THE HEARTBREAKER';
    if (score >= 65) return 'THE OPERATOR';
    if (score >= 50) return 'THE OBSERVER';
    if (score >= 35) return 'COLD START';
    return 'NPC';
  }

  // ══════════════════════════════════════════════════════════════════════
  //  ROAST GENERATOR
  //  Picks a roast keyed to the WEAKEST of the four dimensions when the
  //  user underperformed in one, or a tier-band strength roast when they
  //  didn't. Raw-signal overrides still fire for the old-school bug cases
  //  (blink spiraling, total eye flinch, etc.) because those are more
  //  actionable than a dimension label.
  // ══════════════════════════════════════════════════════════════════════

  static String _roastFor({
    required int score,
    required _DimScore weakest,
    required _DimScore strongest,
    required double eyeContactPct,
    required double stabilityPct,
    required double blinkRate,
  }) {
    // Raw signal emergency overrides — these are sharper than dimension
    // language because they name the specific failure.
    if (eyeContactPct > 0 && eyeContactPct < 45) {
      return _pick(_eyesPool, score);
    }
    if (blinkRate > 28) {
      return _pick(_blinkHighPool, score);
    }
    if (blinkRate > 0 && blinkRate < 5) {
      return _pick(_blinkLowPool, score);
    }
    if (stabilityPct > 0 && stabilityPct < 45) {
      return _pick(_stillPool, score);
    }

    // Dimension-weighted roasts. If the weakest dimension is materially
    // weaker than the rest (>15pt gap), call it out by name.
    if (weakest.value < 55 && (strongest.value - weakest.value) > 15) {
      final pool = _dimFailPool[weakest.name];
      if (pool != null) return _pick(pool, score);
    }

    // Otherwise: strength call keyed to tier band.
    return _pick(_strengthPoolFor(score), score);
  }

  static String _pick(List<String> pool, int seed) {
    final rng = Random(seed * 7 + 13);
    return pool[rng.nextInt(pool.length)];
  }

  // ── RAW-SIGNAL POOLS (screenshot-bait, charisma-coach voice) ──────────
  static const _eyesPool = [
    'Your eyes flinched first. Everything else is decoration.',
    'You broke contact before the room read you. That is the whole job.',
    'Glances are not gaze. Hold it until it gets uncomfortable. Then keep holding.',
    'Looking away first means you bring the lower status to every interaction.',
    'The eyes are the ante. You folded.',
  ];
  static const _stillPool = [
    'Your head was broadcasting anxiety louder than your voice ever could.',
    'Every micro-adjustment costs you a point. You made dozens.',
    'Stillness is dominance. You were not still.',
    'You move like you are explaining something to a stranger. Lock the head.',
  ];
  static const _blinkHighPool = [
    'You blinked your way through this like the camera was interrogating you.',
    'High blink rate is the body screaming. The room hears it before you speak.',
    'Blink less. The pace is reading your cortisol out loud.',
  ];
  static const _blinkLowPool = [
    'Frozen-eye stare is not presence — it is uncanny. Let yourself blink.',
    'You over-corrected. A natural blink is part of the read.',
  ];

  // ── DIMENSION POOLS ────────────────────────────────────────────────────
  static const _dimFailPool = <String, List<String>>{
    'Presence': [
      'Presence is the gaze plus the stillness. You had neither.',
      'The room can feel when you are not fully in it. This was not in it.',
      'Presence is not effort — it is arrival. You were still on your way.',
    ],
    'Composure': [
      'Your nervous system was showing. Composure is the one thing nobody can fake.',
      'Every twitch, every over-blink is a leak. Close the leaks.',
      'Composure is what they feel when they cannot read you. You were readable.',
    ],
    'Warmth': [
      'The score is there but the warmth is not. That reads as cold, not magnetic.',
      'You were competent, not compelling. Let something move across your face.',
      'Control without warmth is just a wall. Open it 10 percent.',
    ],
    'Range': [
      'Stillness is not a corpse. Let something shift — eyebrow, half-smile, anything.',
      'A frozen face scores high on control and zero on alive. Both matter.',
      'The best operators move exactly enough. You moved not at all.',
    ],
  };

  // ── STRENGTH POOLS ─────────────────────────────────────────────────────
  static List<String> _strengthPoolFor(int score) {
    if (score >= 92) {
      return const [
        'Untouchable. Most people will never get within 20 points of this.',
        'This is the score actors get paid for. Hold it.',
        'Nothing flinched. Nothing leaked. That is the whole game.',
      ];
    }
    if (score >= 85) {
      return const [
        'Magnetic range. People reorient toward this without knowing why.',
        'You took up the room without saying a word. That is the lift.',
        'This is the score that gets second looks.',
      ];
    }
    if (score >= 75) {
      return const [
        'Sharp. You hold the room — most do not even know what that means.',
        'This is composure most men train for years to land. Push for 85.',
        'Eyes locked, head still. Now go push the duration.',
      ];
    }
    if (score >= 65) {
      return const [
        'Composed. The foundation is there. Now make it effortless.',
        'You are above average. Every notch from here is leverage.',
        'Solid range. Warmth is your next 10 points.',
      ];
    }
    if (score >= 50) {
      return const [
        'Foundation laid. Repetition turns this into something real.',
        'You showed up. The score will compound — keep at it.',
      ];
    }
    if (score >= 35) {
      return const [
        'Growing. Day one of anything looks like this. Keep going.',
        'You can see what is missing now. That is the unlock.',
      ];
    }
    return const [
      'Raw. Everyone starts here. The graph only goes up if you train.',
      'Day one. Now show up tomorrow.',
    ];
  }
}

class AuraVerdict {
  final int score;
  final String tier;
  final String roast;
  final String strongestDimension;
  final String weakestDimension;
  final Map<String, double> dimensionPcts;

  const AuraVerdict({
    required this.score,
    required this.tier,
    required this.roast,
    required this.strongestDimension,
    required this.weakestDimension,
    required this.dimensionPcts,
  });
}

class _DimScore {
  final String name;
  final double value;
  const _DimScore(this.name, this.value);
}
