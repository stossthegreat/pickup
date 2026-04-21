import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 9:16 share unit — a stand-alone export of the hero card.
///
/// Stack (matches the on-screen hero exactly, one tweak):
///   1. Score transition   56  →  78   (red arrow, the single pop)
///      CURRENT   PROJECTED            (captions)
///   2. Before/After image              (tight crop, eyes upper third)
///      "Mirrorly" overlays top-left of the NOW half so the brand
///      sits inside the image itself instead of competing with the
///      score numbers. Bottom-corner "NOW"/"FIXED" labels preserved.
///   3. Tagline                         (italic serif, same as hero)
///   4. 3 proof lines                   (22pt all-caps, same as hero)
///
/// Padding tightened vs the previous share card so everything fits
/// comfortably in the 9:16 frame.
class ShareCard extends StatelessWidget {
  static const Color accentRed = Color(0xFFE8222A);

  final int currentScore;
  final int projectedScore;
  final String tagline;
  final Uint8List? beforeBytes;
  final String? afterUrl;
  final List<String> microProofs;

  const ShareCard({
    super.key,
    required this.currentScore,
    required this.projectedScore,
    required this.tagline,
    required this.beforeBytes,
    required this.afterUrl,
    required this.microProofs,
  });

  @override
  Widget build(BuildContext context) {
    final proofs = microProofs.take(3).toList();
    final hasScores = currentScore > 0 && projectedScore > 0;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 56, 40, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1 · SCORE TRANSITION (or just "Mirrorly" if no scores) ──
              if (hasScores) ...[
                _ScoreTransitionStatic(
                  currentScore:   currentScore,
                  projectedScore: projectedScore,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 112, child: Text('CURRENT',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13, letterSpacing: 3.4,
                        fontWeight: FontWeight.w700,
                      ))),
                    const SizedBox(width: 76),
                    SizedBox(width: 112, child: Text('PROJECTED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13, letterSpacing: 3.4,
                        fontWeight: FontWeight.w700,
                      ))),
                  ],
                ),
              ] else
                Text('Mirrorly',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 40, letterSpacing: -1.0,
                    fontWeight: FontWeight.w600, height: 1,
                  )),

              // Tight gap — user wanted "numbers closer to the picture".
              const SizedBox(height: 20),

              // ── 2 · IMAGE (Mirrorly wordmark overlaid top-left of NOW) ──
              AspectRatio(
                aspectRatio: 5 / 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(child: _half(
                        bytes: beforeBytes, url: null,
                        label: 'NOW', align: Alignment.bottomLeft,
                        showBrandWordmark: true,   // brand lives on the NOW side
                      )),
                      Container(width: 1, color: Colors.white),
                      Expanded(child: _half(
                        bytes: null, url: afterUrl,
                        label: 'FIXED', align: Alignment.bottomRight,
                        showBrandWordmark: false,
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── 3 · TAGLINE ──
              Center(
                child: Text(tagline,
                  textAlign: TextAlign.center,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28, letterSpacing: -0.4,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500, height: 1.24,
                  )),
              ),

              const Spacer(),

              // ── 4 · PROOF LINES ──
              for (var i = 0; i < proofs.length; i++) ...[
                Text(proofs[i].toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24, letterSpacing: 1.5,
                    fontWeight: FontWeight.w700, height: 1.35,
                  )),
                if (i != proofs.length - 1) const SizedBox(height: 4),
              ],

              const SizedBox(height: 20),

              // ── Footer — just the domain now that "Mirrorly" is in the
              // NOW image. Minimal so it doesn't compete.
              Align(
                alignment: Alignment.centerRight,
                child: Text('mirrorly.app',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13, letterSpacing: 0.4,
                    fontWeight: FontWeight.w500,
                  )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _half({
    required Uint8List? bytes,
    required String? url,
    required String label,
    required Alignment align,
    required bool showBrandWordmark,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35))
        else if (url != null && url.isNotEmpty)
          Image.network(url,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0C0C0C)))
        else
          const ColoredBox(color: Color(0xFF0C0C0C)),

        // Soft scrim along the top of the NOW half so the Mirrorly
        // wordmark is legible over any skin tone / bright highlight.
        if (showBrandWordmark)
          Positioned(
            left: 0, right: 0, top: 0, height: 78,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        if (showBrandWordmark)
          Positioned(
            left: 14, top: 12,
            child: Text('Mirrorly',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 22, letterSpacing: -0.5,
                fontWeight: FontWeight.w600, height: 1,
              )),
          ),

        // Bottom scrim under the corner label (same as hero card's).
        Positioned(
          left: 0, right: 0, bottom: 0, height: 90,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Align(
            alignment: align,
            child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12, letterSpacing: 3.4,
                fontWeight: FontWeight.w700,
              )),
          ),
        ),
      ],
    );
  }
}

/// Static (non-animated) score transition for off-screen captures. Share
/// renders happen at a single frame, so we can't animate — draw the final
/// state directly. Geometry matches the hero card's animated version so
/// the share is visually identical to what the user sees on screen.
class _ScoreTransitionStatic extends StatelessWidget {
  final int currentScore;
  final int projectedScore;

  const _ScoreTransitionStatic({
    required this.currentScore,
    required this.projectedScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: Text('$currentScore',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 84, height: 1.0, letterSpacing: -2.4,
              color: Colors.white.withValues(alpha: 0.62),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            )),
        ),
        const SizedBox(width: 36),
        Text('→',
          style: GoogleFonts.inter(
            color: ShareCard.accentRed,
            fontSize: 52, height: 1,
            fontWeight: FontWeight.w300,
          )),
        const SizedBox(width: 36),
        SizedBox(
          width: 112,
          child: Text('$projectedScore',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 100, height: 1.0, letterSpacing: -2.8,
              color: Colors.white,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            )),
        ),
      ],
    );
  }
}
