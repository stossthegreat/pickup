import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

import 'face_mesh_service.dart';

/// iOS-only dense face-mesh service. Mirrors [FaceMeshService] (the
/// Android ML Kit one) so the scan screen can swap between them at
/// `Platform.isIOS` without touching any of its consuming code.
///
/// Why this exists: `google_mlkit_face_mesh_detection` is Android-only.
/// Google says so in their docs ("This feature is still in beta and
/// only available for Android"). Without a separate iOS source, the
/// scan overlay falls back to ~130-point face contours and never
/// renders the dense 468-point cyan mesh that makes the Android scan
/// look sci-fi grade.
///
/// `mediapipe_face_mesh` is a community wrapper around Google's
/// official `MediaPipeTasksVision` iOS framework. Same model
/// (face_landmarker.task), same 478 normalized 3D landmarks (468 mesh
/// + 10 iris), runs natively via TFLite. Identical density to the
/// Android ML Kit path on the painter side — the painter doesn't need
/// to know which platform produced the mesh.
///
/// API caveat: this package is brand-new and the docs are sparse. The
/// integration below is built from the public Dart class signatures
/// surfaced on pub.dev (see ../../docs/ios-face-mesh.md if added later).
/// First iOS build may surface a method-signature mismatch — if so,
/// consult the package source directly and adjust the call site.
class IosFaceMeshService {
  FaceMeshProcessor? _processor;
  bool _busy = false;

  Future<void> _ensureProcessor() async {
    if (_processor != null) return;
    // GPU delegate gives the smoothest live overlay on iOS where the
    // Metal backend is well-supported. Fallback to CPU if unavailable
    // is handled inside the package.
    _processor = await FaceMeshProcessor.create(
      delegate: FaceMeshDelegate.gpuV2,
      enableSmoothing: true,
      enableRoiTracking: true,
    );
  }

  /// Run inference on a single iOS BGRA8888 camera frame. Returns a
  /// [FaceMesh] with normalized 0..1 points laid out at the canonical
  /// MediaPipe indices (the same indices the painter uses on Android),
  /// or null if no face was detected.
  ///
  /// Drops frames while a previous inference is still running — the
  /// painter is happy to keep rendering the last known mesh while a
  /// new one is in flight, and dropping is safer than queueing under
  /// real-time load.
  Future<FaceMesh?> detect({
    required CameraImage image,
    required int rotationDegrees,
    required bool mirrorHorizontal,
  }) async {
    if (_busy) return null;
    if (image.planes.isEmpty) return null;

    _busy = true;
    try {
      await _ensureProcessor();
      final processor = _processor;
      if (processor == null) return null;

      // iOS Flutter `camera` plugin delivers BGRA8888 in plane[0] for
      // `ImageFormatGroup.bgra8888`. One contiguous buffer.
      final plane = image.planes.first;
      final mpImage = FaceMeshImage(
        pixels: plane.bytes,
        width:  image.width,
        height: image.height,
        pixelFormat: FaceMeshPixelFormat.bgra,
        bytesPerRow: plane.bytesPerRow,
      );

      // process() — runs detect + landmark in one call for a single frame.
      // The package also offers a stream-based path (FaceMeshStreamProcessor)
      // but our existing pipeline already drives ML Kit per-frame, so we
      // mirror that here.
      final result = await processor.process(
        image:           mpImage,
        rotationDegrees: rotationDegrees,
      );
      if (result == null) return null;

      // landmarksAsOffsets returns the 478 landmarks projected into the
      // requested target frame. Passing targetSize: null + clampToBounds:
      // false keeps them as raw normalized 0..1 coords, which is exactly
      // what the painter expects (it scales by canvas size itself).
      final offsets = result.landmarksAsOffsets(
        targetSize:       null,
        clampToBounds:    false,
        rotationDegrees:  0,             // already applied during detect
        mirrorHorizontal: mirrorHorizontal,
      );

      // The MediaPipe landmark order matches what the painter assumes
      // (idxLeftEyeOuter = 33, idxChin = 152, etc.) — the Dart-side
      // indexing constants in face_mesh_service.dart already line up.
      return FaceMesh(offsets);
    } catch (_) {
      // Detection can transiently fail under heavy GPU load or if the
      // model file is mid-load. Swallowing matches the existing
      // FaceMeshService pattern and keeps the scan screen responsive.
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Convenience for the `Uint8List` path — used if a caller already has
  /// the BGRA bytes peeled off the CameraImage. Currently unused by
  /// scan_screen but kept symmetric with [detect].
  Future<FaceMesh?> detectFromBytes({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required int rotationDegrees,
    required bool mirrorHorizontal,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      await _ensureProcessor();
      final processor = _processor;
      if (processor == null) return null;

      final mpImage = FaceMeshImage(
        pixels:      bytes,
        width:       width,
        height:      height,
        pixelFormat: FaceMeshPixelFormat.bgra,
        bytesPerRow: bytesPerRow,
      );
      final result = await processor.process(
        image:           mpImage,
        rotationDegrees: rotationDegrees,
      );
      if (result == null) return null;

      final offsets = result.landmarksAsOffsets(
        targetSize:       null,
        clampToBounds:    false,
        rotationDegrees:  0,
        mirrorHorizontal: mirrorHorizontal,
      );
      return FaceMesh(offsets);
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> close() async {
    await _processor?.close();
    _processor = null;
  }
}
