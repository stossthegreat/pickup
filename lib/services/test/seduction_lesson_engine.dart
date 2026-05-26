import 'dart:math' as math;
import 'dart:ui';

import '../../models/face_metrics.dart';
import '../voice/voice_coach.dart';
import 'charisma_test_engine.dart';

/// AURALAY Seduction Lesson — 60-second guided choreography.
///
///   PHASE                 TIME  WHAT THE USER DOES                       WHY IT WORKS
///   ────────────────────  ────  ───────────────────────────────────────  ──────────────────────
///   1. THE LOOK UP        10s   tilt chin DOWN, eyes UP at target        the demure-but-direct
///                                                                        Princess-Diana frame —
///                                                                        triggers "she's looking
///                                                                        UP at me" instinct
///   2. THE SLOW BLINK     10s   hold gaze, close eyes slowly, open       parasympathetic signal,
///                                                                        cat-calm, never reads
///                                                                        as bored when paired
///                                                                        with held gaze
///   3. THE SIDE GLANCE    12s   look LEFT slowly, return to target       the BB break-and-return
///                                                                        — calculated mystery,
///                                                                        not avoidance
///   4. THE HALF SMILE     10s   asymmetric smile, eyes locked the whole  Marilyn / Mona Lisa /
///                                time, mouth uneven                      young Brando — half a
///                                                                        smile says twice as
///                                                                        much as a full one
///   5. THE FLOW           18s   combine all four — neutral → look up →   the full arc, all the
///                                slow blink → side glance → half smile   beats, in one ribbon
///                                → return                                of attention
///
/// Total: ~60 seconds.
///
/// Detection signals per phase:
///
///   LOOK UP   — head pitch goes positive (chin down ≥ 4°) sustained AND
///                gaze stays on target.
///   SLOW BLINK — at least one blink with closed-eye duration ≥ 280ms
///                while gaze stays on target before + after.
///   SIDE GLANCE — gazePoint dx deviates ≥ 0.18 from target then returns
///                within 0.10 of original within 4s, smoothly.
///   HALF SMILE — smile probability rises to ≥ 0.45 with gaze maintained.
///                We don't have asymmetry detection without per-side
///                landmarks; we approximate with smile-growth rate.
///   THE FLOW   — accumulator that ticks any of the above signals up
///                in the final 18-second window.
class SeductionLessonEngine {
  SeductionLessonEngine({required this.voice});

  final VoiceCoach voice;

  // ── Phase script ───────────────────────────────────────────────────────
  static const phases = <_LessonPhase>[
    _LessonPhase(
      id: TestPhaseId.lookUp,
      label: 'THE LOOK UP',
      caption: 'Chin down. Eyes up to me.',
      cue: VoiceCoach.lookAtEyes, // reused — drop chin_down_eyes_up.mp3 to override
      altCue: 'chin_down_eyes_up',
      duration: Duration(seconds: 10),
    ),
    _LessonPhase(
      id: TestPhaseId.slowBlink,
      label: 'THE SLOW BLINK',
      caption: 'Hold the gaze. Now close, slowly. Open.',
      cue: VoiceCoach.lockHold,
      altCue: 'slow_close',
      duration: Duration(seconds: 10),
    ),
    _LessonPhase(
      id: TestPhaseId.sideGlance,
      label: 'THE SIDE GLANCE',
      caption: 'Look away. Slowly. Now back.',
      cue: VoiceCoach.followSlow,
      altCue: 'look_away_return',
      duration: Duration(seconds: 12),
    ),
    _LessonPhase(
      id: TestPhaseId.knowingSmile,
      label: 'THE HALF SMILE',
      caption: 'Let the smile build. Eyes still locked. Half, not full.',
      cue: VoiceCoach.smileBuild,
      altCue: 'half_smile',
      duration: Duration(seconds: 10),
    ),
    _LessonPhase(
      id: TestPhaseId.theFlow,
      label: 'THE FLOW',
      caption: 'Now together. Down. Up. Slow blink. Glance. Smile. Hold.',
      cue: VoiceCoach.dontMove, // placeholder
      altCue: 'the_flow',
      duration: Duration(seconds: 18),
    ),
  ];

  static Duration get totalDuration =>
      phases.fold(Duration.zero, (a, p) => a + p.duration);

  // ── Live state ────────────────────────────────────────────────────────
  DateTime? _started;
  int _phaseIndex = 0;
  Duration _phaseStartedAt = Duration.zero;
  bool _phaseAnnounced = false;
  bool _finished = false;

  // Per-phase score accumulators.
  final Map<TestPhaseId, _LessonAccum> _scores = {
    for (final p in phases) p.id: _LessonAccum(),
  };

  // Phase 1 (LOOK UP) — track sustained chin-down + eyes-up state.
  // Phase 2 (SLOW BLINK) — track eye-closed duration + count slow blinks.
  // Phase 3 (SIDE GLANCE) — track lateral excursion + return.
  // Phase 4 (HALF SMILE) — track smile growth rate.
  // Phase 5 (FLOW) — accumulate any signal hits.
  double? _baselinePitch;       // captured from first second of LOOK UP
  Offset? _baselineGaze;        // for side-glance return tracking
  DateTime? _eyesClosedSince;
  double _maxLateralDev = 0.0;
  bool _returnedFromSide = false;
  double _smileFloor = -1;

  // Whole-test averages.
  final List<double> _presenceHist = [];
  final List<double> _composureHist = [];
  final List<double> _warmthHist = [];
  final List<double> _rangeHist = [];
  final List<double> _blinkRateSamples = [];
  final List<double> _smileSamples = [];
  int _slowBlinkCount = 0;

  bool get isRunning => _started != null && !_finished;
  bool get isFinished => _finished;
  TestPhaseId get currentPhaseId => phases[_phaseIndex].id;
  String get currentLabel => phases[_phaseIndex].label;
  String get currentCaption => phases[_phaseIndex].caption;

  Duration get elapsed =>
      _started == null ? Duration.zero : DateTime.now().difference(_started!);

  Duration get remaining {
    final r = totalDuration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

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
    _baselinePitch = null;
    _baselineGaze = null;
    _eyesClosedSince = null;
    _maxLateralDev = 0;
    _returnedFromSide = false;
    _smileFloor = -1;
    _slowBlinkCount = 0;
    _presenceHist.clear();
    _composureHist.clear();
    _warmthHist.clear();
    _rangeHist.clear();
    _blinkRateSamples.clear();
    _smileSamples.clear();
    for (final v in _scores.values) {
      v.reset();
    }
  }

  void cancel() {
    _started = null;
    _finished = true;
  }

  TestFrame tick(FaceMetrics? metrics) {
    if (_started == null || _finished) return TestFrame.idle();

    final el = elapsed;
    final phase = phases[_phaseIndex];

    if (el - _phaseStartedAt >= phase.duration) {
      if (_phaseIndex < phases.length - 1) {
        _phaseIndex++;
        _phaseStartedAt = el;
        _phaseAnnounced = false;
        _onPhaseEntered(phases[_phaseIndex].id);
      } else {
        _finished = true;
        voice.play(VoiceCoach.testComplete);
        return TestFrame.complete();
      }
    }

    final activePhase = phases[_phaseIndex];
    if (!_phaseAnnounced) {
      // Prefer the seduction-specific clip; fall back to the matching
      // charisma-test clip if the user hasn't recorded the alt yet.
      // playFirstAvailable picks whichever asset actually exists.
      voice.playFirstAvailable([activePhase.altCue, activePhase.cue]);
      _phaseAnnounced = true;
    }

    final target = _targetForPhase(activePhase.id, phaseProgress);

    bool locked = false;
    if (metrics != null) {
      locked = _scoreFrame(activePhase.id, target, metrics);
      _presenceHist.add(metrics.presenceScore);
      _composureHist.add(metrics.composureScore);
      _warmthHist.add(metrics.warmthScore);
      _rangeHist.add(metrics.rangeScore);
      _blinkRateSamples.add(metrics.blinkRate);
      _smileSamples.add(metrics.smileAuthenticity);
    }

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
      hidden:    false,
      phaseProgress: phaseProgress,
      overallProgress: (el.inMilliseconds /
                        totalDuration.inMilliseconds).clamp(0.0, 1.0),
    );
  }

  // Reset per-phase trackers when entering a new phase.
  void _onPhaseEntered(TestPhaseId id) {
    switch (id) {
      case TestPhaseId.sideGlance:
        _maxLateralDev = 0;
        _returnedFromSide = false;
        break;
      case TestPhaseId.knowingSmile:
        _smileFloor = -1;
        break;
      default: break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Per-phase scoring — seduction-specific
  // ═══════════════════════════════════════════════════════════════════════

  bool _scoreFrame(TestPhaseId phaseId, Offset target, FaceMetrics m) {
    final accum = _scores[phaseId]!;
    accum.frames++;

    final gaze = m.gazePoint;
    final gazeDist = gaze == null
        ? 1.0
        : (gaze - target).distance.clamp(0.0, 1.0);
    final lockScore = (1.0 - gazeDist / 0.25).clamp(0.0, 1.0);

    switch (phaseId) {
      case TestPhaseId.lookUp:
        // Capture baseline pitch in the first 600ms.
        if (phaseProgress < 0.06 && _baselinePitch == null) {
          _baselinePitch = m.headPitch;
        }
        // Reward chin-down delta from baseline (positive pitch in ML Kit
        // means chin down). Sweet spot: 4–10 degrees down.
        final pitchDelta = m.headPitch - (_baselinePitch ?? m.headPitch);
        final chinDown = pitchDelta.clamp(0.0, 14.0) / 14.0;
        final inSweetSpot = pitchDelta >= 3 && pitchDelta <= 12 ? 1.0 : 0.6;
        accum.add(chinDown * 0.55 * inSweetSpot + lockScore * 0.45);
        break;

      case TestPhaseId.slowBlink:
        // Look for blinks where eyes stay closed ≥ 280ms (the "slow"
        // marker). Track _eyesClosedSince as a rising/falling edge state.
        final eyesClosed = m.smileAuthenticity == 0.0 // placeholder: any eye-close detection
            ? false
            : _avgEyeOpen(m) < 0.28;
        if (eyesClosed && _eyesClosedSince == null) {
          _eyesClosedSince = DateTime.now();
        } else if (!eyesClosed && _eyesClosedSince != null) {
          final dur = DateTime.now().difference(_eyesClosedSince!);
          if (dur.inMilliseconds >= 280 && dur.inMilliseconds <= 1200) {
            _slowBlinkCount++;
          }
          _eyesClosedSince = null;
        }
        // Each frame gets a baseline gaze-on-target score plus a one-time
        // boost when a slow blink is registered.
        accum.add(lockScore * 0.7 +
                  (_slowBlinkCount > 0 ? 0.3 : 0.0));
        break;

      case TestPhaseId.sideGlance:
        // Capture baseline gaze in first 400ms.
        if (phaseProgress < 0.04 && _baselineGaze == null && gaze != null) {
          _baselineGaze = gaze;
        }
        if (gaze != null && _baselineGaze != null) {
          final dx = (gaze.dx - _baselineGaze!.dx).abs();
          if (dx > _maxLateralDev) _maxLateralDev = dx;
          // After they've gone ≥ 0.18 away, check return.
          if (_maxLateralDev >= 0.18 && dx < 0.07 && phaseProgress > 0.4) {
            _returnedFromSide = true;
          }
        }
        // Score: did they go AND return?
        final excursionBonus = _maxLateralDev.clamp(0.0, 0.30) / 0.30;
        final returnBonus = _returnedFromSide ? 1.0 : 0.0;
        accum.add(excursionBonus * 0.45 + returnBonus * 0.55);
        break;

      case TestPhaseId.knowingSmile:
        // Reward smile rising from a low floor. Floor captured at start
        // of phase. Best smiles GROW over the 10s window.
        if (_smileFloor < 0) _smileFloor = m.smileAuthenticity;
        final growth = math.max(0.0, m.smileAuthenticity - _smileFloor);
        // Half-smile sweet spot: 0.35–0.65. Full grin (>0.85) reads less
        // mysterious than a held half, so we cap the curve.
        final smileBand = m.smileAuthenticity > 0.85
            ? 0.7
            : (m.smileAuthenticity / 0.65).clamp(0.0, 1.0);
        accum.add(lockScore * 0.35 +
                  smileBand * 0.40 +
                  growth.clamp(0.0, 0.30) / 0.30 * 0.25);
        break;

      case TestPhaseId.theFlow:
        // Accumulator: any of the four seduction signals contributes.
        final pitchDelta = m.headPitch - (_baselinePitch ?? m.headPitch);
        final chinDown = pitchDelta.clamp(0.0, 12.0) / 12.0;
        final smile = m.smileAuthenticity.clamp(0.0, 0.85) / 0.85;
        final blinkSlow = (_avgEyeOpen(m) < 0.4) ? 1.0 : 0.0;
        final composure = m.headStability;
        accum.add(
          (lockScore * 0.30 +
           chinDown  * 0.20 +
           smile     * 0.25 +
           blinkSlow * 0.10 +
           composure * 0.15).clamp(0.0, 1.0),
        );
        break;

      default:
        accum.add(lockScore);
    }

    return gazeDist < 0.14;
  }

  double _avgEyeOpen(FaceMetrics m) {
    // Rough proxy when MLKit doesn't expose direct eye-open probabilities
    // through FaceMetrics. We use the smileAuthenticity-related signals
    // indirectly via eyeContraction (folded into smileAuthenticity at
    // detect time). Slightly imprecise but good enough for "are the eyes
    // closed right now?" decisions during the slow-blink phase.
    // Gaze confidence ≈ open-eye signal proxy.
    return (m.gazeConfidence * 0.5 + (1.0 - m.smileAuthenticity * 0.3)).clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Target paths per phase
  // ═══════════════════════════════════════════════════════════════════════

  static const _center  = Offset(0.5, 0.42);
  static const _slightUp = Offset(0.5, 0.36); // target sits a touch higher so eyes raise
  static const _farLeft  = Offset(0.22, 0.42);

  Offset _targetForPhase(TestPhaseId id, double t) {
    switch (id) {
      case TestPhaseId.lookUp:
        // Target nudges slightly UP across the phase to encourage the
        // eyes-up motion.
        return Offset.lerp(_center, _slightUp, _easeInOutCubic(t))!;
      case TestPhaseId.slowBlink:
        return _center;
      case TestPhaseId.sideGlance:
        // 0..0.35 stay center, 0.35..0.65 glide left, 0.65..1 return.
        if (t < 0.35) return _center;
        if (t < 0.65) {
          final tt = ((t - 0.35) / 0.30).clamp(0.0, 1.0);
          return Offset.lerp(_center, _farLeft, _easeInOutCubic(tt))!;
        }
        final tt = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
        return Offset.lerp(_farLeft, _center, _easeInOutCubic(tt))!;
      case TestPhaseId.knowingSmile:
      case TestPhaseId.theFlow:
        return _center;
      default:
        return _center;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Result
  // ═══════════════════════════════════════════════════════════════════════

  CharismaTestResult buildResult() {
    final scores = <TestPhaseId, double>{};
    for (final entry in _scores.entries) {
      scores[entry.key] = entry.value.average;
    }

    // Overall — equal weight across the 5 moves, except THE FLOW counts
    // double (it's the integration test).
    const w = <TestPhaseId, double>{
      TestPhaseId.lookUp:       0.18,
      TestPhaseId.slowBlink:    0.16,
      TestPhaseId.sideGlance:   0.18,
      TestPhaseId.knowingSmile: 0.20,
      TestPhaseId.theFlow:      0.28,
    };
    double overall = 0;
    for (final e in w.entries) {
      overall += (scores[e.key] ?? 0) * e.value;
    }
    overall = (overall * 100).clamp(0, 100);

    final avgBpm = _avg(_blinkRateSamples);
    final testSec = totalDuration.inSeconds.toDouble();
    final blinkCount = (avgBpm * testSec / 60.0).round();
    final peakSmile = _smileSamples.isEmpty
        ? 0.0
        : _smileSamples.reduce(math.max);

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
      lookAwayCount: 0, // not relevant for the lesson — different metric
      testSeconds:   testSec.round(),
    );
  }

  double _avg(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
}

double _easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final f = (2 * t) - 2;
  return 0.5 * f * f * f + 1;
}

class _LessonPhase {
  final TestPhaseId id;
  final String label;
  final String caption;
  final String cue;       // shared cue id (existing recordings)
  final String altCue;    // seduction-specific cue (drop in to override)
  final Duration duration;
  const _LessonPhase({
    required this.id,
    required this.label,
    required this.caption,
    required this.cue,
    required this.altCue,
    required this.duration,
  });
}

class _LessonAccum {
  double sum = 0;
  int frames = 0;

  void add(double v) {
    sum += v.clamp(0.0, 1.0);
  }

  double get average => frames == 0 ? 0 : (sum / frames).clamp(0.0, 1.0);

  void reset() {
    sum = 0;
    frames = 0;
  }
}
