import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../widgets/common/share_card.dart';

/// Captures any widget via RepaintBoundary + exports a PNG + opens the
/// system share sheet. Supports:
/// - Simple repaint-boundary share (widget already on screen)
/// - Off-screen ShareCard render (composed just for sharing, never shown)
class ShareService {
  /// Screenshot an existing widget wrapped in RepaintBoundary via GlobalKey.
  static Future<void> shareFromKey(
    GlobalKey key, {
    String suggestedName = 'mirrorly.png',
    String? text,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      await _shareBytes(byteData.buffer.asUint8List(), suggestedName, text);
    } catch (_) {}
  }

  /// Render a ShareCard off-screen, capture as PNG, open share sheet.
  /// The card never appears in the UI — this is pure composition.
  static Future<void> shareComposed({
    required BuildContext context,
    required Uint8List? beforeBytes,
    required String? afterUrl,
    required int score,
    required String tier,
    required String archetype,
    required String verdict,
    String? text,
  }) async {
    try {
      final card = ShareCard(
        beforeBytes: beforeBytes,
        afterUrl:    afterUrl,
        score:       score,
        tier:        tier,
        archetype:   archetype,
        verdict:     verdict,
      );
      final bytes = await _captureOffscreen(
        context: context, widget: card, logicalSize: const Size(1080, 1920));
      if (bytes == null) return;
      await _shareBytes(bytes, 'mirrorly-${DateTime.now().millisecondsSinceEpoch}.png', text);
    } catch (_) {}
  }

  static Future<void> _shareBytes(
      Uint8List bytes, String name, String? text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: text,
    );
  }

  /// Render any widget off-screen at an explicit logical size. Uses a
  /// MediaQuery + Theme + Directionality wrapper so text/fonts resolve.
  static Future<Uint8List?> _captureOffscreen({
    required BuildContext context,
    required Widget widget,
    required Size logicalSize,
    double pixelRatio = 3.0,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: View.of(context),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(
        alignment: Alignment.center, child: repaintBoundary),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    final buildOwner = BuildOwner(focusManager: FocusManager());
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
          child: Theme(
            data: Theme.of(context),
            child: ColoredBox(color: AppColors.base, child: widget),
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
