import 'dart:math' as math;
import 'dart:ui';

import '../../models/face_metrics.dart';
import '../voice/voice_coach.dart';
import 'charisma_test_engine.dart';

/// AURALAY VIRAL SEDUCTION TEST — 60-second scripted hook.
///
/// Post-paywall first-experience. Five measurable, viral moves drawn
/// from the dark-charisma research. The Vulnerability Break (THE FALL)
/// is the differentiator — most apps teach dominance posturing only.
///
///   PHASE             TIME  WHAT THE USER DOES                   DETECTION
///   ────────────────  ────  ───────────────────────────────────  ──────────────────────
///   1. THE SMOLDER    12s   lower-lid lifts (squinch), gaze      eye-aperture in 0.22-
///                            stays locked on target               0.32 sweet spot +
///                                                                 gaze-on-target
///   2. THE FALL       10s   head pitches DOWN (chin drops),      head pitch positive
///                            hold 2s, slowly look back UP         then return slowly
///                                                                 (the "vulnerability
///                                                                 break / dark rejection")
///   3. THE STILLNESS  12s   zero head motion while screen        head pose variance
///                            flashes try to break you             through flash window
///   4. THE SLOW BURN  12s   eyes narrow first, mouth-smile        timing delta between
///                            arrives ≥ 300ms LATER                eye-narrow + smile-rise
///   5. THE TAKE-AWAY  14s   lock 5s, target fades, look away,    gaze excursion +
///                            target returns, snap back + smile    return timing
///
/// All five are detectable with MLKit signals + the existing gazePoint
/// estimate. No iris required — works today on every device.
class SeductionTestEngine {
  SeductionTestEngine({required this.voice});

  final VoiceCoach voice;

  static const phases = <_TestPhase>[
    _TestPhase(
      id: TestPhaseId.smolder,
      label: 'THE SMOLDER',
      caption: 'Eyes half-lidded. Like you have a secret.',
      altCue: VoiceCoach.theSmolder,
      fallbackCue: VoiceCoach.lockHold,
      duration: Duration(seconds: 12),
    ),
    _TestPhase(
      id: TestPhaseId.theFall,
      label: 'THE FALL',
      caption: 'Look down. Stay there. Slowly come back up.',
      altCue: VoiceCoach.theFall,
      fallbackCue: VoiceCoach.nowBack,
      duration: Duration(seconds: 10),
    ),
    _TestPhase(
      id: TestPhaseId.stillness,
      label: 'THE STILLNESS',
      caption: "Don't flinch. Don't move. Just be.",
      altCue: VoiceCoach.theStillness,
      fallbackCue: VoiceCoach.dontMove,
      duration: Duration(seconds: 12),
    ),
    _TestPhase(
      id: TestPhaseId.slowBurn,
      label: 'THE SLOW BURN',
      caption: 'Eyes first. Then the smile.',
      altCue: VoiceCoach.theSlowBurn,
      fallbackCue: VoiceCoach.smileBuild,
      duration: Duration(seconds: 12),
    ),
    _TestPhase(
      id: TestPhaseId.takeAway,
      label: 'THE TAKE-AWAY',
      caption: 'Hold. Now away. Now snap back.',
      altCue: VoiceCoach.theTakeAway,
      fallbackCue: VoiceCoach.nowBack,
      duration: Duration(seconds: 14),
    ),
  ];

  static Duration get totalDuration =>
      phases.fold(Duration.zero, (a, p) => a + p.duration);

  // ── Live state ─────────────────────────────────────────────────────────
  DateTime? _started;
  int _phaseIndex = 0;
  Duration _phaseStartedAt = Duration.zero;
  bool _phaseAnnounced = false;
  bool _finished = false;

  final Map<TestPhaseId, _TestAccum> _scores = {
    for (final p in phases) p.id: _TestAccum(),
  };

  // Phase-specific tracking buffers.
  // THE FALL — track the chin-drop event (head pitch goes positive),
  //            its hold duration, and the slow look-back-up.
  double? _fallBaselinePitch;
  bool _fallDropped = false;
  bool _fallHeld = false;
  bool _fallReturned = false;
  DateTime? _fallDroppedAt;
  DateTime? _fallReturnedAt;
  // SLOW BURN — track when eyes start narrowing AND when smile starts
  //             rising, so we can grade the timing delta.
  DateTime? _eyesNarrowedAt;
  DateTime? _smileStartedAt;
  double _bestSmileTimingMs = 0;
  // TAKE-AWAY — scripted target visibility flag (set by _targetForPhase).
  // We track whether the user's gaze followed the script.
  bool _takeAwayBroke = false;
  bool _takeAwaySnappedBack = false;
  DateTime? _takeAwayBreakAt;
  DateTime? _takeAwayReturnAt;
  // STILLNESS — flash distractions fire at scripted offsets.
  // _flashActive is read by the screen for the white-flash overlay.
  bool _flashActive = false;
  bool get flashActive => _flashActive;

  // Whole-test averages (for the readout panel + 4-dim breakdown).
  final List<double> _presenceHist = [];
  final List<double> _composureHist = [];
  final List<double> _warmthHist = [];
  final List<double> _rangeHist = [];
  final List<double> _blinkRateSamples = [];
  final List<double> _smileSamples = [];

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

  /// Live per-phase signal level (0..1) — used by the screen to draw a
  /// real-time meter for the current move (squinch level, stillness ring,
  /// take-away beat indicator). Not the same as the accumulated score.
  double signalLevel = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  void start() {
    _started = DateTime.now();
    _phaseIndex = 0;
    _phaseStartedAt = Duration.zero;
    _phaseAnnounced = false;
    _finished = false;
    _fallBaselinePitch = null;
    _fallDropped = false;
    _fallHeld = false;
    _fallReturned = false;
    _fallDroppedAt = null;
    _fallReturnedAt = null;
    _eyesNarrowedAt = null;
    _smileStartedAt = null;
    _bestSmileTimingMs = 0;
    _takeAwayBroke = false;
    _takeAwaySnappedBack = false;
    _takeAwayBreakAt = null;
    _takeAwayReturnAt = null;
    _flashActive = false;
    _presenceHist.clear();
    _composureHist.clear();
    _warmthHist.clear();
    _rangeHist.clear();
    _blinkRateSamples.clear();
    _smileSamples.clear();
    for (final v in _scores.values) {
      v.reset();
    }
    signalLevel = 0;
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
      voice.playFirstAvailable([activePhase.altCue, activePhase.fallbackCue]);
      _phaseAnnounced = true;
    }

    // Drive phase-specific behaviours that the screen renders (flash,
    // target visibility for take-away).
    _updatePhaseEffects(activePhase.id, phaseProgress);

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

    // TAKE-AWAY — target should fade out during the "look away" window
    // so the user gets a visual prompt to break gaze.
    final hidden = activePhase.id == TestPhaseId.takeAway &&
                   phaseProgress >= 0.36 && phaseProgress < 0.64;

    return TestFrame(
      phaseId:   activePhase.id,
      label:     activePhase.label,
      caption:   activePhase.caption,
      target:    target,
      locked:    locked,
      intensity: intensity,
      hidden:    hidden,
      phaseProgress: phaseProgress,
      overallProgress: (el.inMilliseconds /
                        totalDuration.inMilliseconds).clamp(0.0, 1.0),
    );
  }

  void _onPhaseEntered(TestPhaseId id) {
    _eyesNarrowedAt = null;
    _smileStartedAt = null;
    _takeAwayBroke = false;
    _takeAwaySnappedBack = false;
    _takeAwayBreakAt = null;
    _takeAwayReturnAt = null;
    _flashActive = false;
    signalLevel = 0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Phase-effect drivers (visible to the screen)
  // ═══════════════════════════════════════════════════════════════════════

  void _updatePhaseEffects(TestPhaseId id, double t) {
    // STILLNESS — fire 3 white flashes at scripted offsets to test if the
    // user flinches. Each flash lasts ~120ms.
    if (id == TestPhaseId.stillness) {
      // Flash windows: 0.20–0.215, 0.50–0.515, 0.80–0.815.
      final inFlash = (t > 0.20 && t < 0.215) ||
                      (t > 0.50 && t < 0.515) ||
                      (t > 0.80 && t < 0.815);
      _flashActive = inFlash;
    } else {
      _flashActive = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Per-phase scoring rubrics
  // ═══════════════════════════════════════════════════════════════════════

  bool _scoreFrame(TestPhaseId id, Offset target, FaceMetrics m) {
    final accum = _scores[id]!;
    accum.frames++;

    final gaze = m.gazePoint;
    final gazeDist = gaze == null ? 1.0 : (gaze - target).distance.clamp(0.0, 1.0);
    final lockScore = (1.0 - gazeDist / 0.25).clamp(0.0, 1.0);

    switch (id) {
      // ── SMOLDER ─────────────────────────────────────────────────────
      // Squinch sweet spot — eyes partially closed but not blinking.
      // ML Kit's leftEyeOpenProbability isn't on FaceMetrics directly;
      // we use eye-aperture height/width ratio as a proxy. Below 0.20
      // = blinking; 0.22-0.32 = squinch; above 0.36 = bug-eyed.
      case TestPhaseId.smolder:
        final l = m.leftEyeAperture ?? 0.30;
        final r = m.rightEyeAperture ?? 0.30;
        final ap = (l + r) / 2.0;
        // Bell curve centered on 0.27 (the squinch zone).
        final squinchScore = math.exp(
          -math.pow((ap - 0.27) / 0.06, 2).toDouble(),
        ).clamp(0.0, 1.0);
        signalLevel = squinchScore;
        accum.add(lockScore * 0.45 + squinchScore * 0.55);
        break;

      // ── THE FALL — Vulnerability Break / Dark Rejection ─────────────
      // 3-beat move: chin drops (pitch +ve), holds for ~2s, slowly
      // returns to neutral. The visual is unambiguous (head goes down,
      // then up) and the meaning is psychologically loaded.
      //
      //   Beat A (0–0.3):  capture pitch baseline + watch for a drop
      //                     of ≥ 6° (chin goes down).
      //   Beat B (0.3–0.7): hold the dropped position. Reward sustained
      //                     low pitch.
      //   Beat C (0.7–1.0): slow return — pitch crosses back to within
      //                     2° of baseline, but slow (rate < 25°/s).
      case TestPhaseId.theFall:
        if (phaseProgress < 0.10 && _fallBaselinePitch == null) {
          _fallBaselinePitch = m.headPitch;
        }
        final base = _fallBaselinePitch ?? m.headPitch;
        final dropMag = (m.headPitch - base).clamp(-30.0, 30.0);
        // ML Kit pitch sign: positive = chin DOWN.
        if (!_fallDropped && dropMag >= 6.0) {
          _fallDropped = true;
          _fallDroppedAt = DateTime.now();
        }
        if (_fallDropped && phaseProgress >= 0.30 && phaseProgress < 0.70 &&
            dropMag >= 5.0) {
          _fallHeld = true;
        }
        if (_fallHeld && phaseProgress >= 0.70 && dropMag.abs() <= 3.0 &&
            !_fallReturned) {
          _fallReturned = true;
          _fallReturnedAt = DateTime.now();
        }
        // Per-frame signal — what % of the move have we completed?
        signalLevel = (
          (_fallDropped ? 0.33 : 0.0) +
          (_fallHeld    ? 0.33 : 0.0) +
          (_fallReturned ? 0.34 : 0.0)
        ).clamp(0.0, 1.0);
        // Per-frame score: combine drop magnitude + lock + completion.
        // The dark-rejection move scores HIGH only when all three beats
        // landed (chin dropped, held, slow return).
        final dropScore = (dropMag.clamp(0.0, 12.0)) / 12.0;
        accum.add(
          (lockScore * 0.20 +
           dropScore * 0.30 +
           (_fallDropped ? 0.15 : 0.0) +
           (_fallHeld    ? 0.15 : 0.0) +
           (_fallReturned ? 0.20 : 0.0)).clamp(0.0, 1.0),
        );
        break;

      // ── STILLNESS ───────────────────────────────────────────────────
      // Pure stability — extra weight when a flash just fired.
      case TestPhaseId.stillness:
        final stab = m.headStability;
        final boost = _flashActive ? 0.3 : 0.0;
        signalLevel = stab;
        accum.add(stab * (0.7 + boost) + lockScore * 0.3);
        break;

      // ── SLOW BURN ───────────────────────────────────────────────────
      // Detect EYE-NARROW before MOUTH-SMILE. Reward timing delta of
      // 300–600ms. Instant smiles (<150ms) score lower.
      case TestPhaseId.slowBurn:
        final ap = ((m.leftEyeAperture ?? 0.30) + (m.rightEyeAperture ?? 0.30)) / 2.0;
        final eyesNarrow = ap < 0.28;
        final smileRising = m.smileAuthenticity > 0.35;

        if (eyesNarrow && _eyesNarrowedAt == null) {
          _eyesNarrowedAt = DateTime.now();
        }
        if (smileRising && _smileStartedAt == null && _eyesNarrowedAt != null) {
          _smileStartedAt = DateTime.now();
          final delta = _smileStartedAt!.difference(_eyesNarrowedAt!).inMilliseconds.toDouble();
          // Sweet spot: 300–700ms. Bell curve centered on 500.
          final timingScore = math.exp(
            -math.pow((delta - 500) / 220, 2).toDouble(),
          ).clamp(0.0, 1.0);
          if (timingScore > _bestSmileTimingMs) _bestSmileTimingMs = timingScore;
        }
        signalLevel = _bestSmileTimingMs * 0.5 +
                      (eyesNarrow ? 0.25 : 0) +
                      (smileRising ? 0.25 : 0);
        accum.add(lockScore * 0.30 +
                  _bestSmileTimingMs * 0.45 +
                  m.smileAuthenticity.clamp(0.0, 0.85) / 0.85 * 0.25);
        break;

      // ── TAKE-AWAY ──────────────────────────────────────────────────
      // Scripted: 0–0.36 lock, 0.36–0.64 look away, 0.64–1.0 snap back.
      case TestPhaseId.takeAway:
        final t = phaseProgress;
        if (t < 0.36) {
          // Pre-break: just lock.
          signalLevel = lockScore;
          accum.add(lockScore);
        } else if (t < 0.64) {
          // Look-away window — reward gaze deviation NOT lock.
          final excursion = gazeDist.clamp(0.0, 0.40) / 0.40;
          if (gazeDist > 0.18 && _takeAwayBreakAt == null) {
            _takeAwayBroke = true;
            _takeAwayBreakAt = DateTime.now();
          }
          signalLevel = excursion;
          accum.add(excursion * 0.85 + (1 - lockScore) * 0.15);
        } else {
          // Snap-back window. Reward fast return to lock + smile.
          if (lockScore > 0.6 && _takeAwayReturnAt == null && _takeAwayBroke) {
            _takeAwaySnappedBack = true;
            _takeAwayReturnAt = DateTime.now();
          }
          // Bonus for smile during snap-back.
          final smileBonus = m.smileAuthenticity.clamp(0.0, 0.6) / 0.6;
          signalLevel = lockScore * 0.6 + smileBonus * 0.4;
          accum.add(lockScore * 0.5 +
                    smileBonus * 0.3 +
                    (_takeAwaySnappedBack ? 0.2 : 0));
        }
        break;

      default:
        accum.add(lockScore);
    }

    return gazeDist < 0.14;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Target paths
  // ═══════════════════════════════════════════════════════════════════════

  static const _center = Offset(0.5, 0.42);
  // STICKY EYES — the target stays put. The user's INSTRUCTION is to
  // turn their head while keeping eyes locked. Visual nudge: the
  // surrounding HUD (a frame or arrow) tilts to suggest motion, but the
  // target itself never moves. That's the whole point of "sticky."
  Offset _targetForPhase(TestPhaseId id, double t) {
    switch (id) {
      case TestPhaseId.smolder:
      case TestPhaseId.stickyEyes:
      case TestPhaseId.stillness:
      case TestPhaseId.slowBurn:
        return _center;
      case TestPhaseId.takeAway:
        // Center for the lock + snap-back windows. Target fades during
        // the look-away window (0.36–0.64) handled by `hidden` flag.
        return _center;
      default:
        return _center;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Build result
  // ═══════════════════════════════════════════════════════════════════════

  CharismaTestResult buildResult() {
    final scores = <TestPhaseId, double>{};
    for (final entry in _scores.entries) {
      scores[entry.key] = entry.value.average;
    }

    // Weights — TAKE-AWAY (integration) and THE FALL (the dark-charisma
    // marquee move) carry the most weight. SMOLDER + STILLNESS + SLOW
    // BURN balance the bottom.
    const w = <TestPhaseId, double>{
      TestPhaseId.smolder:    0.18,
      TestPhaseId.theFall:    0.22,
      TestPhaseId.stillness:  0.18,
      TestPhaseId.slowBurn:   0.18,
      TestPhaseId.takeAway:   0.24,
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
      lookAwayCount: 0,
      testSeconds:   testSec.round(),
    );
  }

  double _avg(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
}

class _TestPhase {
  final TestPhaseId id;
  final String label;
  final String caption;
  final String altCue;
  final String fallbackCue;
  final Duration duration;
  const _TestPhase({
    required this.id,
    required this.label,
    required this.caption,
    required this.altCue,
    required this.fallbackCue,
    required this.duration,
  });
}

class _TestAccum {
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
