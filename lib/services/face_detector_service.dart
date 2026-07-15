import 'package:camera/camera.dart';

import '../models/face_metrics.dart';
import 'gaze/gaze_detector.dart';
import 'gaze/mlkit_gaze_detector.dart';
import 'gaze/mediapipe_gaze_detector.dart';

/// Face detection coordinator.
///
/// Thin delegate over a pluggable [GazeDetector] so we can swap engines
/// at runtime:
///
///   FaceDetectorService()                             // MLKit (default)
///   FaceDetectorService(engine: GazeEngine.mediapipe) // MediaPipe iris
///
/// The MLKit path carries Mirrorly's proven rotation-aware preview-space
/// normalization, the 15°-tightened eye-contact sigmoid, AND the upgraded
/// calibration + eye-aperture + 4-dimension layer in a single detector.
class FaceDetectorService {
  final GazeEngine engine;
  late final GazeDetector _detector;

  FaceDetectorService({this.engine = GazeEngine.mlkit}) {
    _detector = _detectorFor(engine);
  }

  GazeDetector _detectorFor(GazeEngine e) {
    switch (e) {
      case GazeEngine.mediapipe: return MediaPipeGazeDetector();
      case GazeEngine.mlkit:     return MlkitGazeDetector();
    }
  }

  String get engineName => _detector.engineName;
  bool get hasIris      => _detector.hasIris;
  bool get isCalibrated => _detector.isCalibrated;

  Future<void> init() => _detector.init();

  Future<FaceMetrics?> process(
    CameraImage image,
    int sensorOrientation, {
    bool isFrontCam = true,
  }) =>
      _detector.process(image, sensorOrientation, isFrontCam: isFrontCam);

  void startCalibration({Duration duration = const Duration(seconds: 3)}) =>
      _detector.startCalibration(duration: duration);

  void resetCalibration() => _detector.resetCalibration();

  Future<void> dispose() => _detector.dispose();
}
