import 'dart:math' as math;
import 'dart:ui';

import '../../models/face_metrics.dart';
import '../voice/voice_coach.dart';

/// AURALAY 30-second charisma test — 5-phase script.
///
///   PHASE                  TIME  TARGET                  VOICE                 SCORED
///   ─────────────────────  ────  ──────────────────────  ────────────────────  ──────────────────────
///   1. THE LOCK            8s    center, hold            "Hold the gaze."      iris-on-target + blink
///   2. THE SMILE           6s    center, hold            "Now let it build."   Duchenne smile + lock
///   3. THE BREAK           5s    center → upper-right    "Follow it. Slowly."  tracking smoothness
///   4. THE RETURN          5s    upper-right → center    "Now back. Hold."     return + re-lock
///   5. THE STILL           6s    fade out                "Don't move."         stillness + composure
///
/// The engine produces:
///   * a per-frame [TestFrame] (current phase + target position + locked
///     state + intensity) so the UI can render the eye target, captions
///     and live score
///   * voice cue triggers via the VoiceCoach passed in
///   * a final [CharismaTestResult] with the 5 phase scores + an overall
///     0–100 aura score and the average 4-dimension breakdown
///
/// Driven by [tick] from the parent screen on each detector frame
/// (typically ~30Hz) — keeps timing decoupled from a Timer so phase
/// transitions land precisely when frames advance.
class CharismaTestEngine {
  CharismaTestEngine({required this.voice});

  final VoiceCoach voice;

  // ── 5-phase script ─────────────────────────────────────────────────────
  static const phases = <_PhaseSpec>[
    _PhaseSpec(
      id: TestPhaseId.lock,
      label: 'THE LOCK',
      caption: 'Hold the gaze. Don\'t flinch.',
      cue: VoiceCoach.lockHold,
      duration: Duration(seconds: 8),
    ),
    _PhaseSpec(
      id: TestPhaseId.smile,
      label: 'THE SMILE',
      caption: 'Now let the smile build. Slowly.',
      cue: VoiceCoach.smileBuild,
      duration: Duration(seconds: 6),
    ),
    _PhaseSpec(
      id: TestPhaseId.breakAway,
      label: 'THE BREAK',
      caption: 'Follow it. Slowly.',
      cue: VoiceCoach.followSlow,
      duration: Duration(seconds: 5),
    ),
    _PhaseSpec(
      id: TestPhaseId.returnHome,
      label: 'THE RETURN',
      caption: 'Now back. Hold.',
      cue: VoiceCoach.nowBack,
      duration: Duration(seconds: 5),
    ),
    _PhaseSpec(
      id: TestPhaseId.still,
      label: 'THE STILL',
      caption: 'Don\'t move. Don\'t blink. Just be.',
      cue: VoiceCoach.dontMove,
      duration: Duration(seconds: 6),
    ),
  ];

  static Duration get totalDuration =>
      phases.fold(Duration.zero, (a, p) => a + p.duration);

  // ── Live state ────────────────────────────────────────────────────────
  DateTime? _started;
  int _phaseIndex = 0;
  Duration _phaseStartedAt = Duration.zero;
  bool _phaseAnnounced = false;
  DateTime? _lastReactiveCue;

  // Per-phase score accumulators (sums of per-frame contributions).
  final Map<TestPhaseId, _PhaseAccum> _scores = {
    for (final p in phases) p.id: _PhaseAccum(),
  };

  // Tracking-phase needs gaze-velocity smoothness — we keep last gaze
  // points to estimate jerkiness.
  final List<Offset> _gazeTrail = [];

  // Whole-test averages for the 4-dim charisma breakdown.
  final List<double> _presenceHist = [];
  final List<double> _composureHist = [];
  final List<double> _warmthHist = [];
  final List<double> _rangeHist = [];

  // Plain-English readout signals.
  // _blinkRateSamples: per-frame BPM readings — averaged at the end so we
  //   can say "you blinked X times in the 30 seconds" (BPM × 0.5).
  // _smileDuringSmilePhase: smile probability sampled ONLY during the
  //   SMILE phase, for the "your smile peaked at X" line.
  // _lookAwayCount: times the user dropped below the lock threshold during
  //   any locked phase — fired once per drop, not per frame.
  final List<double> _blinkRateSamples = [];
  final List<double> _smileDuringSmilePhase = [];
  int _lookAwayCount = 0;
  bool _wasLockedLastFrame = false;

  bool get isRunning => _started != null && !_finished;
  bool _finished = false;
  bool get isFinished => _finished;
  TestPhaseId get currentPhaseId => phases[_phaseIndex].id;
  String get currentLabel => phases[_phaseIndex].label;
  String get currentCaption => phases[_phaseIndex].caption;

  /// Time elapsed since [start] was called.
  Duration get elapsed =>
      _started == null ? Duration.zero : DateTime.now().difference(_started!);

  /// Time remaining in the entire test.
  Duration get remaining {
    final r = totalDuration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// Fraction of THIS phase completed, 0..1.
  double get phaseProgress {
    final phase = phases[_phaseIndex];
    final inPhase = elapsed - _phaseStartedAt;
    return (inPhase.inMilliseconds / phase.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  void start() {
    _started = DateTime.now();
    _phaseIndex = 0;
    _phaseStartedAt = Duration.zero;
    _phaseAnnounced = false;
    _finished = false;
    _gazeTrail.clear();
    _presenceHist.clear();
    _composureHist.clear();
    _warmthHist.clear();
    _rangeHist.clear();
    _blinkRateSamples.clear();
    _smileDuringSmilePhase.clear();
    _lookAwayCount = 0;
    _wasLockedLastFrame = false;
    for (final v in _scores.values) {
      v.reset();
    }
  }

  void cancel() {
    _started = null;
    _finished = true;
  }

  /// Call once per detector frame. Advances phase, fires voice cues,
  /// scores the current frame against the active phase rubric.
  /// Returns the current [TestFrame] for the UI to render.
  TestFrame tick(FaceMetrics? metrics) {
    if (_started == null || _finished) {
      return TestFrame.idle();
    }

    final el = elapsed;
    final phase = phases[_phaseIndex];

    // Phase transition?
    if (el - _phaseStartedAt >= phase.duration) {
      if (_phaseIndex < phases.length - 1) {
        _phaseIndex++;
        _phaseStartedAt = el;
        _phaseAnnounced = false;
      } else {
        // Test complete.
        _finished = true;
        voice.play(VoiceCoach.testComplete);
        return TestFrame.complete();
      }
    }

    // First frame of a phase — fire the direction cue.
    final activePhase = phases[_phaseIndex];
    if (!_phaseAnnounced) {
      voice.play(activePhase.cue);
      _phaseAnnounced = true;
    }

    // Compute target position for this phase + frame.
    final target = _targetForPhase(activePhase.id, phaseProgress);

    // Score the frame.
    bool locked = false;
    if (metrics != null) {
      locked = _scoreFrame(activePhase.id, target, metrics);
      _maybeFireReactive(activePhase.id, metrics, locked);

      // Charisma 4-dim averages — running.
      _presenceHist.add(metrics.presenceScore);
      _composureHist.add(metrics.composureScore);
      _warmthHist.add(metrics.warmthScore);
      _rangeHist.add(metrics.rangeScore);

      // Plain-English readout signals.
      _blinkRateSamples.add(metrics.blinkRate);
      if (activePhase.id == TestPhaseId.smile) {
        _smileDuringSmilePhase.add(metrics.smileAuthenticity);
      }
      // Count "look-away" events: rising-edge transitions from locked
      // to not-locked during the LOCK or SMILE phases (the held phases).
      // Skip the first 600ms of each phase so transitions don't trigger.
      if (_wasLockedLastFrame &&
          !locked &&
          (activePhase.id == TestPhaseId.lock ||
           activePhase.id == TestPhaseId.smile) &&
          phaseProgress > 0.08) {
        _lookAwayCount++;
      }
      _wasLockedLastFrame = locked;
    }

    // Phase intensity — fade in over first 400ms, full hold, fade out
    // last 400ms. Smooth visual transitions.
    final phaseMs = activePhase.duration.inMilliseconds;
    final inMs = (el - _phaseStartedAt).inMilliseconds;
    double intensity = 1.0;
    if (inMs < 400)               { intensity = inMs / 400.0; }
    else if (inMs > phaseMs - 400){ intensity = (phaseMs - inMs) / 400.0; }
    intensity = intensity.clamp(0.0, 1.0);

    return TestFrame(
      phaseId:   activePhase.id,
      label:     activePhase.label,
      caption:   activePhase.caption,
      target:    target,
      locked:    locked,
      intensity: intensity,
      hidden:    activePhase.id == TestPhaseId.still &&
                 phaseProgress > 0.25,  // target fades during STILL
      phaseProgress: phaseProgress,
      overallProgress: (el.inMilliseconds /
                        totalDuration.inMilliseconds).clamp(0.0, 1.0),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Per-phase scoring
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns whether the user is "locked" on the current target this frame.
  bool _scoreFrame(TestPhaseId phaseId, Offset target, FaceMetrics m) {
    final accum = _scores[phaseId]!;
    accum.frames++;

    final gaze = m.gazePoint;
    final gazeDistance = gaze == null
        ? 1.0
        : (gaze - target).distance.clamp(0.0, 1.0);
    // Locked if within ~12% of preview width — generous so users don't
    // feel like they're failing on minor wobble.
    final locked = gazeDistance < 0.12;
    final lockScore = (1.0 - gazeDistance / 0.25).clamp(0.0, 1.0);

    switch (phaseId) {
      case TestPhaseId.lock:
        // Pure gaze hold + blink composure.
        accum.add(lockScore * 0.85 + _blinkBonus(m.blinkRate) * 0.15);
        break;

      case TestPhaseId.smile:
        // Gaze must hold AND a Duchenne smile must build.
        // Reward the GROWTH of the smile across the phase, not just
        // the absolute level — that's the "delayed smile" technique.
        final smileGrowth = math.max(0.0,
            m.smileAuthenticity - accum.firstSmile);
        if (accum.firstSmile == -1) accum.firstSmile = m.smileAuthenticity;
        accum.add(lockScore * 0.55 +
                  (m.smileAuthenticity * 0.6 + smileGrowth * 0.4) * 0.45);
        break;

      case TestPhaseId.breakAway:
      case TestPhaseId.returnHome:
        // Tracking smoothness: are they following the target with a
        // controlled velocity, or snapping?
        final smooth = _trackingSmoothness(gaze);
        accum.add(lockScore * 0.45 + smooth * 0.55);
        break;

      case TestPhaseId.still:
        // Stillness wins here — head + face micro-motion penalised.
        // Gaze still matters but less since target is fading.
        accum.add(m.headStability * 0.7 +
                  _blinkBonus(m.blinkRate) * 0.3);
        break;

      // Seduction-lesson + seduction-test phases — engine doesn't score
      // these. Their dedicated engines (SeductionLessonEngine /
      // SeductionTestEngine) handle their own rubrics.
      case TestPhaseId.lookUp:
      case TestPhaseId.slowBlink:
      case TestPhaseId.sideGlance:
      case TestPhaseId.knowingSmile:
      case TestPhaseId.theFlow:
      case TestPhaseId.smolder:
      case TestPhaseId.theFall:
      case TestPhaseId.stickyEyes:
      case TestPhaseId.stillness:
      case TestPhaseId.slowBurn:
      case TestPhaseId.takeAway:
        break;
    }

    return locked;
  }

  double _blinkBonus(double rate) {
    if (rate == 0) return 0.6;
    if (rate < 6) return rate / 6.0;
    if (rate <= 18) return 1.0;
    return math.max(0, 1.0 - (rate - 18) / 14.0);
  }

  double _trackingSmoothness(Offset? gaze) {
    if (gaze == null) return 0.5;
    _gazeTrail.add(gaze);
    if (_gazeTrail.length > 8) _gazeTrail.removeAt(0);
    if (_gazeTrail.length < 3) return 0.5;

    // Average frame-to-frame jump.
    double total = 0;
    for (int i = 1; i < _gazeTrail.length; i++) {
      total += (_gazeTrail[i] - _gazeTrail[i - 1]).distance;
    }
    final avgJump = total / (_gazeTrail.length - 1);
    // 0.04 = smooth follow, 0.15+ = snapping. Bell-curve.
    return math.exp(-math.pow((avgJump - 0.045) / 0.06, 2).toDouble())
        .clamp(0.0, 1.0);
  }

  void _maybeFireReactive(TestPhaseId phaseId, FaceMetrics m, bool locked) {
    final now = DateTime.now();
    if (_lastReactiveCue != null &&
        now.difference(_lastReactiveCue!) < VoiceCoach.reactiveCooldown) {
      return;
    }
    String? cue;
    if (!locked && phaseId == TestPhaseId.lock) {
      cue = VoiceCoach.eyesBack;
    } else if (m.isBlinkingTooFast) {
      cue = VoiceCoach.blinkLess;
    } else if (phaseId == TestPhaseId.breakAway && _gazeTrail.length >= 3) {
      // Read smoothness off the existing trail without re-pushing.
      double total = 0;
      for (int i = 1; i < _gazeTrail.length; i++) {
        total += (_gazeTrail[i] - _gazeTrail[i - 1]).distance;
      }
      final avgJump = total / (_gazeTrail.length - 1);
      if (avgJump > 0.10) cue = VoiceCoach.slower;
    } else if (phaseId == TestPhaseId.smile && !locked) {
      cue = VoiceCoach.lockIn;
    }

    if (cue != null) {
      voice.playReactive(cue);
      _lastReactiveCue = now;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Target position per phase
  // ═══════════════════════════════════════════════════════════════════════

  static const _center      = Offset(0.5, 0.42);
  static const _upperRight  = Offset(0.74, 0.32);

  Offset _targetForPhase(TestPhaseId id, double t) {
    switch (id) {
      case TestPhaseId.lock:
      case TestPhaseId.smile:
      case TestPhaseId.still:
        return _center;
      case TestPhaseId.breakAway:
        // Center → upper-right, eased.
        final eased = _easeInOutCubic(t);
        return Offset.lerp(_center, _upperRight, eased)!;
      case TestPhaseId.returnHome:
        final eased = _easeInOutCubic(t);
        return Offset.lerp(_upperRight, _center, eased)!;
      // Seduction phases default to center — their engines override
      // with phase-specific paths.
      case TestPhaseId.lookUp:
      case TestPhaseId.slowBlink:
      case TestPhaseId.sideGlance:
      case TestPhaseId.knowingSmile:
      case TestPhaseId.theFlow:
      case TestPhaseId.smolder:
      case TestPhaseId.theFall:
      case TestPhaseId.stickyEyes:
      case TestPhaseId.stillness:
      case TestPhaseId.slowBurn:
      case TestPhaseId.takeAway:
        return _center;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Final result
  // ═══════════════════════════════════════════════════════════════════════

  CharismaTestResult buildResult() {
    final scores = <TestPhaseId, double>{};
    for (final entry in _scores.entries) {
      scores[entry.key] = entry.value.average;
    }

    // Overall aura — weighted blend of the 5 phase scores.
    // LOCK is the marquee signal so it's the heaviest.
    const w = <TestPhaseId, double>{
      TestPhaseId.lock:       0.30,
      TestPhaseId.smile:      0.20,
      TestPhaseId.breakAway:  0.18,
      TestPhaseId.returnHome: 0.17,
      TestPhaseId.still:      0.15,
    };
    double overall = 0;
    for (final entry in w.entries) {
      overall += (scores[entry.key] ?? 0) * entry.value;
    }
    overall = (overall * 100).clamp(0, 100);

    // Plain-English readout signals.
    final avgBpm = _avg(_blinkRateSamples);
    // Test runs ~30s, so blinks-in-test ≈ avgBpm × (testSec / 60).
    final testSec = totalDuration.inSeconds.toDouble();
    final blinkCount = (avgBpm * testSec / 60.0).round();
    final peakSmile = _smileDuringSmilePhase.isEmpty
        ? 0.0
        : _smileDuringSmilePhase.reduce(math.max);

    return CharismaTestResult(
      overallScore:  overall.round(),
      phaseScores:   scores.map((k, v) => MapEntry(k, (v * 100).clamp(0, 100))),
      avgPresence:   _avg(_presenceHist) * 100,
      avgComposure:  _avg(_composureHist) * 100,
      avgWarmth:     _avg(_warmthHist) * 100,
      avgRange:      _avg(_rangeHist) * 100,
      blinkCount:    blinkCount,
      avgBlinkRate:  avgBpm,
      peakSmilePct:  peakSmile * 100,
      lookAwayCount: _lookAwayCount,
      testSeconds:   testSec.round(),
    );
  }

  double _avg(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
}

// ═════════════════════════════════════════════════════════════════════════
//  Public types
// ═════════════════════════════════════════════════════════════════════════

enum TestPhaseId {
  // Charisma-test phases (5)
  lock,
  smile,
  breakAway,
  returnHome,
  still,
  // Seduction-lesson phases (5) — used by SeductionLessonEngine
  lookUp,
  slowBlink,
  sideGlance,
  knowingSmile,
  theFlow,
  // Viral SEDUCTION TEST phases (5) — used by SeductionTestEngine
  // The dark-charisma research distilled into a 60-second scripted test.
  smolder,        // squinch / lower-lid raise + locked gaze
  theFall,        // vulnerability break — chin drops, slow look-back-up
  stillness,      // zero motion under a flash distraction
  slowBurn,       // eyes-narrow precedes mouth-smile (timing matters)
  takeAway,       // lock → look away (side) → snap-back (push-pull)
  // Legacy seduction-test slot kept so existing data structures
  // referencing TestPhaseId.stickyEyes still compile. Not used by the
  // current SeductionTestEngine.
  stickyEyes,
}

extension TestPhaseIdLabel on TestPhaseId {
  String get displayLabel {
    switch (this) {
      case TestPhaseId.lock:         return 'LOCK';
      case TestPhaseId.smile:        return 'SMILE';
      case TestPhaseId.breakAway:    return 'BREAK';
      case TestPhaseId.returnHome:   return 'RETURN';
      case TestPhaseId.still:        return 'STILL';
      case TestPhaseId.lookUp:       return 'LOOK UP';
      case TestPhaseId.slowBlink:    return 'SLOW BLINK';
      case TestPhaseId.sideGlance:   return 'SIDE GLANCE';
      case TestPhaseId.knowingSmile: return 'HALF SMILE';
      case TestPhaseId.theFlow:      return 'THE FLOW';
      case TestPhaseId.smolder:      return 'SMOLDER';
      case TestPhaseId.theFall:      return 'THE FALL';
      case TestPhaseId.stickyEyes:   return 'STICKY EYES';
      case TestPhaseId.stillness:    return 'STILLNESS';
      case TestPhaseId.slowBurn:     return 'SLOW BURN';
      case TestPhaseId.takeAway:     return 'TAKE-AWAY';
    }
  }
}

class TestFrame {
  final TestPhaseId? phaseId;
  final String label;
  final String caption;
  final Offset target;
  final bool locked;
  final double intensity;     // 0..1 fade for phase entry/exit
  final bool hidden;          // true = hide target (still phase)
  final double phaseProgress;
  final double overallProgress;
  final bool complete;

  const TestFrame({
    required this.phaseId,
    required this.label,
    required this.caption,
    required this.target,
    required this.locked,
    required this.intensity,
    required this.hidden,
    required this.phaseProgress,
    required this.overallProgress,
    this.complete = false,
  });

  factory TestFrame.idle() => const TestFrame(
        phaseId:    null,
        label:      '',
        caption:    '',
        target:     Offset(0.5, 0.42),
        locked:     false,
        intensity:  0,
        hidden:     true,
        phaseProgress: 0,
        overallProgress: 0,
      );

  factory TestFrame.complete() => const TestFrame(
        phaseId:    null,
        label:      'COMPLETE',
        caption:    'Reading your aura.',
        target:     Offset(0.5, 0.42),
        locked:     false,
        intensity:  0,
        hidden:     true,
        phaseProgress: 1,
        overallProgress: 1,
        complete:   true,
      );
}

class CharismaTestResult {
  final int overallScore;
  final Map<TestPhaseId, double> phaseScores; // 0..100
  final double avgPresence;
  final double avgComposure;
  final double avgWarmth;
  final double avgRange;

  // Plain-English readout signals — feed the WHY copy on result reveal.
  final int blinkCount;       // total blinks across the test
  final double avgBlinkRate;  // blinks / minute average
  final double peakSmilePct;  // best smile reached during SMILE phase
  final int lookAwayCount;    // gaze-drop events during locked phases
  final int testSeconds;      // total test duration (for context lines)

  const CharismaTestResult({
    required this.overallScore,
    required this.phaseScores,
    required this.avgPresence,
    required this.avgComposure,
    required this.avgWarmth,
    required this.avgRange,
    required this.blinkCount,
    required this.avgBlinkRate,
    required this.peakSmilePct,
    required this.lookAwayCount,
    required this.testSeconds,
  });
}

// ── Internal types ─────────────────────────────────────────────────────

class _PhaseSpec {
  final TestPhaseId id;
  final String label;
  final String caption;
  final String cue;
  final Duration duration;
  const _PhaseSpec({
    required this.id,
    required this.label,
    required this.caption,
    required this.cue,
    required this.duration,
  });
}

class _PhaseAccum {
  double sum = 0;
  int frames = 0;
  double firstSmile = -1;

  void add(double v) {
    sum += v.clamp(0.0, 1.0);
  }

  double get average => frames == 0 ? 0 : (sum / frames).clamp(0.0, 1.0);

  void reset() {
    sum = 0;
    frames = 0;
    firstSmile = -1;
  }
}

// Avoid pulling material.dart into a service file. Inline cubic ease so
// we don't collide with flutter's Curves class when the engine + flutter/
// material are both imported by a screen.
double _easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final f = (2 * t) - 2;
  return 0.5 * f * f * f + 1;
}
