import 'dart:ui';

/// Per-frame metrics surfaced to the UI + scoring pipeline.
///
/// All positional fields (faceCenter, leftEyePos, rightEyePos, faceRect,
/// contourPoints, contours) are in PREVIEW-SPACE 0..1 — ready to plot as
/// `(x * canvasW, y * canvasH)` inside a CustomPaint that sits as a CHILD
/// of CameraPreview. The rotation-aware normalization is handled by the
/// detector (see MlkitGazeDetector._normalize).
///
/// Invariants:
///   * All *Score fields are in 0–1 (percentage helpers clamp to 0–100)
///   * Euler angles are in degrees (pitch = up/down, yaw = left/right, roll = tilt)
///   * headYaw: positive = turned right (user's right)
///   * headPitch: positive = chin down
class FaceMetrics {
  // ── Core behavioral signals ─────────────────────────────────────────────
  final double eyeContactScore;   // 0–1: composite gaze signal
  final double gazeConfidence;    // 0–1: detector's confidence in the gaze reading
  final double blinkRate;         // blinks per minute (rolling 60s window)
  final double smileAuthenticity; // 0–1: Duchenne marker (mouth × eye-contraction)
  final double headStability;     // 0–1: inverse of euler variance

  // ── Four-dimension charisma breakdown (0-1 each) ────────────────────────
  final double presenceScore;     // gaze + stillness (the "dominant range")
  final double warmthScore;       // smile + open expression (the "magnetic range")
  final double composureScore;    // blink + micro-motion control (the "unshakeable")
  final double rangeScore;        // expressive variance over session (the "alive")

  // ── Raw pose ────────────────────────────────────────────────────────────
  final double headPitch;
  final double headYaw;
  final double headRoll;

  // ── Framing (ALL IN PREVIEW SPACE 0..1) ────────────────────────────────
  final Offset faceCenter;
  final double faceSize;          // normalized face bbox width
  final Rect?  faceRect;          // full face bbox (for oval overlay guide)
  /// Flat list of ALL contour points. Kept for legacy painters.
  /// New painter code should use [contours] instead so lines don't zigzag
  /// across unrelated face regions.
  final List<Offset> contourPoints;
  /// Contour points grouped by FaceContourType.name
  /// (faceOval, leftEye, rightEye, lips, noseBridge, ...). Each list is a
  /// polyline in drawing order — safe to connect consecutive points.
  final Map<String, List<Offset>> contours;

  // ── Eye data ────────────────────────────────────────────────────────────
  final Offset? leftEyePos;       // preview-space center of left eye landmark
  final Offset? rightEyePos;
  final double? leftEyeAperture;  // height / width of eye contour bbox
  final double? rightEyeAperture;

  /// Estimated point on the screen where the user is looking, in preview-
  /// space 0..1. With MediaPipe iris this is a real iris-vector projection;
  /// with MLKit it's a head-pose approximation derived from yaw + pitch +
  /// face position (good enough for a "is the user staring at this target?"
  /// signal, but not pixel-accurate).
  ///
  /// (0.5, 0.5) means user appears to be looking at the center of the
  /// preview. Null when the detector can't compute a gaze direction yet.
  final Offset? gazePoint;

  // ── Composite ───────────────────────────────────────────────────────────
  final double overallAura;       // 0–100

  /// True when the user has passed the calibration phase and scores are
  /// computed relative to their neutral baseline.
  final bool calibrated;

  const FaceMetrics({
    required this.eyeContactScore,
    required this.gazeConfidence,
    required this.blinkRate,
    required this.smileAuthenticity,
    required this.headStability,
    required this.presenceScore,
    required this.warmthScore,
    required this.composureScore,
    required this.rangeScore,
    required this.headPitch,
    required this.headYaw,
    required this.headRoll,
    required this.faceCenter,
    required this.faceSize,
    required this.faceRect,
    required this.contourPoints,
    required this.contours,
    required this.overallAura,
    required this.calibrated,
    this.leftEyePos,
    this.rightEyePos,
    this.leftEyeAperture,
    this.rightEyeAperture,
    this.gazePoint,
  });

  static const FaceMetrics empty = FaceMetrics(
    eyeContactScore: 0,
    gazeConfidence: 0,
    blinkRate: 0,
    smileAuthenticity: 0,
    headStability: 0,
    presenceScore: 0,
    warmthScore: 0,
    composureScore: 0,
    rangeScore: 0,
    headPitch: 0,
    headYaw: 0,
    headRoll: 0,
    faceCenter: Offset(0.5, 0.5),
    faceSize: 0,
    faceRect: null,
    contourPoints: [],
    contours: {},
    overallAura: 0,
    calibrated: false,
  );

  // ── Display helpers ─────────────────────────────────────────────────────
  double get eyeContactPct => (eyeContactScore * 100).clamp(0, 100);
  double get smilePct       => (smileAuthenticity * 100).clamp(0, 100);
  double get stabilityPct   => (headStability * 100).clamp(0, 100);
  double get presencePct    => (presenceScore * 100).clamp(0, 100);
  double get warmthPct      => (warmthScore * 100).clamp(0, 100);
  double get composurePct   => (composureScore * 100).clamp(0, 100);
  double get rangePct       => (rangeScore * 100).clamp(0, 100);

  bool get isGoodEyeContact  => eyeContactScore > 0.65;
  bool get isGoodStability   => headStability > 0.70;
  bool get isSmiling         => smileAuthenticity > 0.45;
  bool get isBlinkingTooFast => blinkRate > 25;
  bool get isBlinkingTooSlow => blinkRate < 8 && blinkRate > 0;
  bool get isFaceCentered    => (faceCenter.dx - 0.5).abs() < 0.15 &&
                                (faceCenter.dy - 0.5).abs() < 0.15;

  String get coachLine {
    if (!isGoodEyeContact) return 'Hold the gaze. Eyes straight.';
    if (isBlinkingTooFast) return 'Blink rate too high — slow down.';
    if (!isGoodStability)  return 'Keep your head still.';
    if (!isSmiling && smileAuthenticity < 0.2) return 'Relax your face.';
    return 'Good. Hold it.';
  }
}
