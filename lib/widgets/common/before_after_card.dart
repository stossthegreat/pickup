import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'fullscreen_image.dart';

/// Universal before/after card. The proven viral format — "NOW · MAXIMIZED"
/// split down the middle with a gold divider. Tappable (fullscreen zoom),
/// captioned, aspect-locked.
///
/// Used for: Maximized Twin on report, every tryon result in chat + report.
class BeforeAfterCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? beforeUrl;
  final String? afterUrl;
  final String? caption; // e.g. "mid-fade with textured crop"
  final String beforeLabel;
  final String afterLabel;

  const BeforeAfterCard({
    super.key,
    this.beforeBytes,
    this.beforeUrl,
    required this.afterUrl,
    this.caption,
    this.beforeLabel = 'NOW',
    this.afterLabel  = 'MAXIMIZED',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.lg),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(child: _ImageHalf(
                    bytes: beforeBytes, url: beforeUrl, onTap: _openBefore)),
                  Container(width: 1.2, color: AppColors.gold),
                  Expanded(child: _ImageHalf(
                    url: afterUrl, onTap: _openAfter)),
                ],
              ),
              // Top gradient + labels
              Positioned(
                left: 0, right: 0, top: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(beforeLabel,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 9, letterSpacing: 2.4))),
                      Expanded(child: Text(afterLabel,
                        textAlign: TextAlign.right,
                        style: AppTypography.label.copyWith(
                          color: AppColors.gold,
                          fontSize: 9, letterSpacing: 2.4))),
                    ],
                  ),
                ),
              ),
              // Bottom caption pill
              if (caption != null)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(caption!,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary, fontSize: 11.5, height: 1.35,
                        fontStyle: FontStyle.italic)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBefore(BuildContext context) => FullscreenImage.open(
    context, bytes: beforeBytes, url: beforeUrl, caption: beforeLabel);
  void _openAfter(BuildContext context) => FullscreenImage.open(
    context, url: afterUrl, caption: afterLabel);
}

class _ImageHalf extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;
  final void Function(BuildContext) onTap;
  const _ImageHalf({this.bytes, this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(context),
        child: SizedBox.expand(
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : (url != null && url!.isNotEmpty
                  ? Image.network(url!, fit: BoxFit.cover,
                      loadingBuilder: (_, child, p) => p == null ? child
                        : const Center(child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.gold, strokeWidth: 2))),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF0E0E12)))
                  : const ColoredBox(color: Color(0xFF0E0E12))),
        ),
      ),
    );
  }
}
