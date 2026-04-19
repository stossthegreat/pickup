import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/face_geometry.dart';
import '../../services/face_geometry_service.dart';
import '../../services/face_mesh_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/scan/geometry_overlay_painter.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  CameraController? _camera;
  FaceDetector?     _faceDetector;
  FaceMeshService?  _meshService;

  ScanPhase    _phase    = ScanPhase.searching;
  FaceMesh?    _mesh;
  FaceGeometry? _geometry;
  double       _progress = 0.0;
  int          _countdown = 3;
  bool         _busy = false;

  Timer? _measureTimer;
  Timer? _countdownTimer;

  int _faceFrames = 0;
  static const int _requiredFrames = 10;

  bool _processing = false;

  // Rotating copy per phase
  static const _scanCopy = [
    '468 landmarks',
    'Orbital vector resolving',
    'Jaw angle acquired',
    'FWHR locking',
    'Structural archetype match running',
  ];
  int _copyIdx = 0;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.25,
      ),
    );

    _meshService = FaceMeshService();

    _camera = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    try {
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {});
      _camera!.startImageStream(_processFrame);
    } catch (e) {
      debugPrint('Camera init: $e');
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;

    final rotation = Platform.isIOS
        ? InputImageRotationValue.fromRawValue(camera.description.sensorOrientation)
              ?? InputImageRotation.rotation0deg
        : (camera.description.sensorOrientation == 90
              ? InputImageRotation.rotation90deg
              : InputImageRotation.rotation270deg);

    // iOS front camera: bgra8888, single plane, ML Kit expects this
    // Android front camera: nv21, single plane
    final format = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormat.nv21;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing ||
        _phase == ScanPhase.capturing ||
        _phase == ScanPhase.analysing) { return; }
    _processing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // Run both detectors in parallel
      final results = await Future.wait([
        _faceDetector!.processImage(inputImage),
        _meshService!.detect(inputImage, imgW, imgH),
      ]);

      if (!mounted) return;

      final faces = results[0] as List<Face>;
      final mesh  = results[1] as FaceMesh?;

      if (faces.isEmpty || mesh == null || !mesh.isValid) {
        _faceFrames = 0;
        if (_phase != ScanPhase.searching) {
          setState(() {
            _phase    = ScanPhase.searching;
            _progress = 0;
            _mesh     = null;
          });
        }
        return;
      }

      _faceFrames++;
      final face = faces.first;
      final geom = FaceGeometryService.computeGeometry(face, imgW, imgH);

      setState(() {
        _mesh     = mesh;
        _geometry = geom;
      });

      if (_phase == ScanPhase.searching && _faceFrames >= 2) {
        _startScanning();
      }

      if (_phase == ScanPhase.scanning) {
        final p = (_faceFrames / _requiredFrames).clamp(0.0, 1.0);
        setState(() => _progress = p);

        if (_faceFrames >= _requiredFrames) {
          _startMeasuring();
        }
      }
    } finally {
      _processing = false;
    }
  }

  void _startScanning() {
    setState(() {
      _phase    = ScanPhase.scanning;
      _progress = 0;
    });
    HapticFeedback.lightImpact();
    _copyTimer?.cancel();
    _copyTimer = Timer.periodic(700.ms, (_) {
      if (!mounted) return;
      setState(() => _copyIdx = (_copyIdx + 1) % _scanCopy.length);
    });
  }

  void _startMeasuring() {
    setState(() {
      _phase    = ScanPhase.measuring;
      _progress = 0.6;
    });
    HapticFeedback.mediumImpact();
    _measureTimer?.cancel();
    _measureTimer = Timer.periodic(30.ms, (t) {
      if (!mounted) { t.cancel(); return; }
      final np = _progress + 0.02;
      setState(() => _progress = np.clamp(0.0, 1.0));
      if (np >= 1.0) {
        t.cancel();
        _startCapture();
      }
    });
  }

  void _startCapture() {
    setState(() {
      _phase     = ScanPhase.capturing;
      _progress  = 1.0;
      _countdown = 3;
    });
    HapticFeedback.mediumImpact();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        HapticFeedback.lightImpact();
        setState(() => _countdown--);
      } else {
        t.cancel();
        HapticFeedback.heavyImpact();
        await _captureAndShip();
      }
    });
  }

  Future<void> _captureAndShip() async {
    if (_busy) return;
    _busy = true;
    setState(() => _phase = ScanPhase.analysing);

    try {
      await _camera?.stopImageStream();
      final file = await _camera?.takePicture();
      if (file == null) throw Exception('capture failed');
      final bytes = await File(file.path).readAsBytes();

      if (!mounted) return;
      final geometry = _geometry ??
          const FaceGeometry(
            canthalTilt: 0, symmetryScore: 70, facialThirdTop: 33,
            facialThirdMid: 33, facialThirdLow: 34, fwhr: 1.9,
            eyeSpacingRatio: 0.46, jawAngle: 125, chinProjection: 0,
            hasReliableData: false,
          );

      context.go('/report', extra: {
        'imageBytes': bytes,
        'geometry':   geometry,
      });
    } catch (e) {
      debugPrint('Capture/ship error: $e');
      if (mounted) {
        setState(() {
          _phase = ScanPhase.searching;
          _faceFrames = 0;
        });
        _camera?.startImageStream(_processFrame);
        _busy = false;
      }
    }
  }

  String get _phaseTitle {
    switch (_phase) {
      case ScanPhase.searching:  return 'POSITION YOUR FACE';
      case ScanPhase.scanning:   return _scanCopy[_copyIdx];
      case ScanPhase.measuring:  return 'GEOMETRY RESOLVED';
      case ScanPhase.capturing:  return 'HOLD STILL';
      case ScanPhase.analysing:  return 'COMPOSITING';
    }
  }

  String get _phaseSub {
    switch (_phase) {
      case ScanPhase.searching:  return 'Look directly into the lens';
      case ScanPhase.scanning:   return 'Mapping 468 landmarks at 30fps';
      case ScanPhase.measuring:  return 'Structural archetype match running';
      case ScanPhase.capturing:  return 'Capturing reference frame';
      case ScanPhase.analysing:  return 'Rendering maximized version';
    }
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _countdownTimer?.cancel();
    _copyTimer?.cancel();
    _camera?.stopImageStream();
    _camera?.dispose();
    _faceDetector?.close();
    _meshService?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _camera;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (preview != null && preview.value.isInitialized)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Camera preview natural size is landscape-ish.
                  // Force it to cover the full portrait screen.
                  final previewRatio = preview.value.aspectRatio;
                  final screenRatio  = constraints.maxWidth / constraints.maxHeight;
                  double w, h;
                  if (screenRatio < previewRatio) {
                    h = constraints.maxHeight;
                    w = h * previewRatio;
                  } else {
                    w = constraints.maxWidth;
                    h = w / previewRatio;
                  }
                  return ClipRect(
                    child: OverflowBox(
                      maxWidth: w,
                      maxHeight: h,
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: CameraPreview(preview),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          // Darken edges for focus
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // The mesh overlay (scroll-stopping visual)
          Positioned.fill(
            child: CustomPaint(
              painter: GeometryOverlayPainter(
                mesh:      _mesh,
                phase:     _phase,
                progress:  _progress,
                countdown: _countdown,
              ),
            ),
          ),

          // Phase HUD — bottom
          Positioned(
            left: 0, right: 0, bottom: 72,
            child: Column(
              children: [
                Text(_phaseTitle,
                  key: ValueKey('$_phase-$_copyIdx'),
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.measure,
                    fontSize: 12,
                    letterSpacing: 2.5,
                  ),
                ).animate(key: ValueKey('$_phase-$_copyIdx'))
                  .fadeIn(duration: 220.ms),
                const SizedBox(height: 6),
                Text(_phaseSub,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ).animate(key: ValueKey(_phase))
                  .fadeIn(duration: 300.ms),
              ],
            ),
          ),

          // Progress bar during scanning
          if (_phase == ScanPhase.scanning || _phase == ScanPhase.measuring)
            Positioned(
              left: 48, right: 48, bottom: 54,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.surface3,
                  valueColor: const AlwaysStoppedAnimation(AppColors.measure),
                  minHeight: 2,
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text('MIRROR',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      letterSpacing: 4,
                    )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('MESH · 468',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 8,
                        letterSpacing: 1.5,
                      )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
