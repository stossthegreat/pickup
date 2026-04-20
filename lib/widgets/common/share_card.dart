import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/trait_builder_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 9:16 composed image — the share unit. All text is BAKED into the image.
/// No separate caption, no attached writing — one file that travels
/// everywhere and reads the same.
///
/// Layout:
///   Brand wordmark
///   82 · THE MONARCH
///   TOP 14% · +14 POTENTIAL
///   NOW | MAXED split (before/after)
///   4 trait badges
///   mirrorly.app footer
class ShareCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? afterUrl;
  final int score;
  final String tier;           // retained for backwards compat; not shown
  final String archetype;
  final String verdict;        // retained for backwards compat; not shown
  final int percentile;        // e.g. 14 → "TOP 14%"
  final int potentialDelta;    // e.g. 14 → "+14 POTENTIAL"
  final List<Trait> traits;    // top 4 rendered

  const ShareCard({
    super.key,
    required this.beforeBytes,
    required this.afterUrl,
    required this.score,
    required this.tier,
    required this.archetype,
    required this.verdict,
    required this.percentile,
    required this.potentialDelta,
    required this.traits,
  });

  @override
  Widget build(BuildContext context) {
    final showTraits = traits.take(4).toList();
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.3,
            colors: [
              AppColors.gold.withValues(alpha: 0.14),
              const Color(0xFF0A0A0A),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand
            Row(
              children: [
                Text('Mirrorly',
                  style: AppTypography.h1.copyWith(
                    fontSize: 28, letterSpacing: -0.8, height: 1)),
                const SizedBox(width: 8),
                Container(
                  width: 5, height: 5, margin: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('MEASURED · NOT GUESSED',
              style: AppTypography.label.copyWith(
                color: AppColors.textMuted, fontSize: 8.5, letterSpacing: 2.8)),

            const SizedBox(height: 36),

            // Hero — score + archetype, centered
            Center(
              child: Column(
                children: [
                  Text('$score',
                    style: AppTypography.display.copyWith(
                      fontSize: 108, height: 0.95, letterSpacing: -4,
                      color: AppColors.gold,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 22),
                      ])),
                  const SizedBox(height: 6),
                  Container(height: 1, width: 64,
                    color: AppColors.gold.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(archetype,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 17, letterSpacing: 5.0,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip('TOP $percentile%', AppColors.gold),
                      const SizedBox(width: 8),
                      _chip('+$potentialDelta POTENTIAL', AppColors.signalGreen),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // NOW | MAXED split
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Expanded(child: _half(beforeBytes, null, 'NOW',
                        AppColors.textSecondary)),
                      Container(width: 1.2, color: AppColors.gold),
                      Expanded(child: _half(null, afterUrl, 'MAXED',
                        AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Trait badges — 2×2 mini grid
            if (showTraits.isNotEmpty)
              _TraitsStrip(traits: showTraits),

            const Spacer(),

            // Footer
            Row(
              children: [
                Text('MEASURED · NOT GUESSED',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary, fontSize: 8, letterSpacing: 2.0)),
                const Spacer(),
                Text('mirrorly.app',
                  style: AppTypography.label.copyWith(
                    color: AppColors.gold,
                    fontSize: 9, letterSpacing: 2.2,
                    fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c.withValues(alpha: 0.7), width: 0.7),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
        style: AppTypography.label.copyWith(
          color: c, fontSize: 9.5, letterSpacing: 2.2,
          fontWeight: FontWeight.w900)),
    );
  }

  Widget _half(Uint8List? bytes, String? url, String label, Color color) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes, fit: BoxFit.cover)
        else if (url != null && url.isNotEmpty)
          Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface1))
        else
          const ColoredBox(color: AppColors.surface1),
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(label,
              textAlign: label == 'MAXED' ? TextAlign.right : TextAlign.left,
              style: AppTypography.label.copyWith(
                color: color,
                fontSize: 10.5, letterSpacing: 2.6, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _TraitsStrip extends StatelessWidget {
  final List<Trait> traits;
  const _TraitsStrip({required this.traits});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.6,
      children: [
        for (final t in traits) _traitMini(t),
      ],
    );
  }

  Widget _traitMini(Trait t) {
    final color = t.kind == TraitKind.strength
        ? AppColors.signalGreen : AppColors.signalRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.6),
      ),
      child: Row(
        children: [
          Text(t.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 9, letterSpacing: 1.5,
                    fontWeight: FontWeight.w900)),
                Text(t.pct,
                  style: AppTypography.label.copyWith(
                    color: color, fontSize: 7.5, letterSpacing: 1.2,
                    fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
