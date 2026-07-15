import 'dart:async';
import 'package:camera/camera.dart';

import '../../models/face_metrics.dart';

/// Pluggable gaze / face detector contract.
///
/// Two implementations live side-by-side:
///   * [MlkitGazeDetector]     — ships today. Uses google_mlkit_face_detection.
///                               Best-effort gaze from head pose + eye-aperture
///                               deltas against a calibrated baseline. Does NOT
///                               track iris position (ML Kit doesn't expose it).
///
///   * [MediaPipeGazeDetector] — elite path. Native plugin over MethodChannel,
///                               backed by MediaPipe Tasks FaceLandmarker with
///                               refineLandmarks=true (iris landmarks 468–477).
///                               Gives true pupil-in-socket gaze vector, even
///                               when the head is still.
///
/// Both detectors return the same [FaceMetrics] shape so the UI + scoring
/// pipeline never has to care which engine is live.
abstract class GazeDetector {
  /// Human-readable engine name for debug overlays.
  String get engineName;

  /// Does this engine produce true iris-level gaze (vs. head-pose proxy)?
  bool get hasIris;

  /// Allocate the detector. Safe to call repeatedly.
  Future<void> init();

  /// Process one camera frame. Returns null when no face is found.
  ///
  /// [sensorOrientation] is the camera sensor orientation in degrees
  /// (Flutter `camera` plugin exposes it via CameraDescription).
  /// [isFrontCam] controls the horizontal-flip branch of the rotation-aware
  /// preview-space normalization — front cams need an explicit mirror on
  /// rotation 0°/180°; rotation 270° already bakes the flip in.
  Future<FaceMetrics?> process(
    CameraImage image,
    int sensorOrientation, {
    bool isFrontCam = true,
  });

  /// Start a calibration pass. The detector captures a neutral baseline
  /// (eye aperture, head pose) over [duration] and from then on scores
  /// deviations from that baseline. Session scoring is gated on this.
  ///
  /// Safe to call mid-stream; will overwrite the prior baseline.
  void startCalibration({Duration duration = const Duration(seconds: 3)});

  /// True once calibration has captured enough samples.
  bool get isCalibrated;

  /// Reset calibration (e.g. new user in front of camera).
  void resetCalibration();

  /// Release native resources.
  Future<void> dispose();
}

/// Currently active engine — the app boots on MLKit and can upgrade to
/// MediaPipe once the native plugin ships + the model file is bundled.
/// Swap via [detectorFor] at service init time.
enum GazeEngine { mlkit, mediapipe }
