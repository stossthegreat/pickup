import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Shareable 9:16 composite — this is what users screenshot or share to
/// TikTok / IG Stories. Rendered off-screen (via RepaintBoundary) then
/// exported as PNG via ShareService.
///
/// Layout:
///   ┌──────────────────────────┐
///   │ Mirrorly · gold dot      │
///   │                          │
///   │  NOW         MAXIMIZED   │
///   │ ┌──────┐ │ ┌──────────┐  │
///   │ │ user │ │ │   flux   │  │
///   │ └──────┘ │ └──────────┘  │
///   │                          │
///   │  "verdict one-liner"     │
///   │                          │
///   │  87  ·  Elite  ·  Arch   │
///   │  mirrorly.app            │
///   └──────────────────────────┘
class ShareCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? afterUrl;
  final int score;
  final String tier;
  final String archetype;
  final String verdict;

  const ShareCard({
    super.key,
    required this.beforeBytes,
    required this.afterUrl,
    required this.score,
    required this.tier,
    required this.archetype,
    required this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.base,
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [
              AppColors.gold.withValues(alpha: 0.12),
              AppColors.base,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand
            Row(
              children: [
                Text('Mirrorly',
                  style: AppTypography.h1.copyWith(
                    fontSize: 28, letterSpacing: -0.7, height: 1)),
                const SizedBox(width: 8),
                Container(
                  width: 5, height: 5, margin: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.65), width: 0.8),
                  ),
                  child: Text('$score · ${tier.toUpperCase()}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.gold, fontSize: 11, letterSpacing: 2.0,
                      fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('THE FACE, MEASURED',
              style: AppTypography.label.copyWith(
                color: AppColors.textMuted, fontSize: 8, letterSpacing: 2.8)),

            const SizedBox(height: 26),

            // Before / after
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      blurRadius: 28),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Expanded(child: _Half(
                        bytes: beforeBytes,
                        label: 'NOW',
                        color: AppColors.textSecondary)),
                      Container(width: 1.2, color: AppColors.gold),
                      Expanded(child: _Half(
                        url: afterUrl,
                        label: 'MAXIMIZED',
                        color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Verdict
            if (verdict.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text('"$verdict"',
                  style: AppTypography.h1Italic.copyWith(
                    fontSize: 17, color: AppColors.textPrimary, height: 1.35,
                    letterSpacing: -0.1)),
              ),

            const Spacer(),

            // Archetype + brand
            Row(
              children: [
                Text(archetype,
                  style: AppTypography.label.copyWith(
                    color: AppColors.gold,
                    fontSize: 10, letterSpacing: 2.8, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('mirrorly.app',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 9, letterSpacing: 2.0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;
  final String label;
  final Color color;
  const _Half({this.bytes, this.url, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes!, fit: BoxFit.cover)
        else if (url != null && url!.isNotEmpty)
          Image.network(url!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface1))
        else
          const ColoredBox(color: AppColors.surface1),

        // Top label pill
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(label,
              textAlign: label == 'MAXIMIZED' ? TextAlign.right : TextAlign.left,
              style: AppTypography.label.copyWith(
                color: color,
                fontSize: 10, letterSpacing: 2.4, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
