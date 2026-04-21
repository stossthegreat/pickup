import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The share unit. 9:16 image that travels everywhere.
///
/// Design: editorial black-and-white. No gold, no gradients, no pills, no
/// cards. Pure black bg, pure white type, one piece of imagery, three
/// sentences of proof. Should read like a Nike ad or an Apple press shot,
/// never like "an AI app".
///
/// Stack (top → bottom):
///   Mirrorly          — tiny serif wordmark
///   3 FIXES.          — huge serif headline (line 1)
///   SAME FACE.        — huge serif headline (line 2)
///   [BEFORE | AFTER]  — tightly-cropped face image, eyes in upper third
///   You're not unattractive.
///   You're unoptimized.                — italic serif tagline, centered
///   Top 3% eyes / Top 5% symmetry / …  — three plain proof lines
///   Measured. Not guessed.             — small footer, bottom-left
///                           mirrorly.app   — bottom-right
class ShareCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? afterUrl;
  final int correctionsCount;     // 3 → "3 FIXES."
  final List<String> microProofs; // up to 3 short lines

  const ShareCard({
    super.key,
    required this.beforeBytes,
    required this.afterUrl,
    required this.correctionsCount,
    required this.microProofs,
  });

  @override
  Widget build(BuildContext context) {
    final proofs = microProofs.take(3).toList();

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 64, 56, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Wordmark (top-left, bigger + pure white, no accent dot) ─
              Text('Mirrorly',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 30, letterSpacing: -0.8,
                  fontWeight: FontWeight.w500, height: 1,
                )),

              const SizedBox(height: 52),

              // ── Headline — the verdict. Two lines, tight leading. ─────
              Text('$correctionsCount FIXES.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 108, letterSpacing: -3.5,
                  fontWeight: FontWeight.w900, height: 0.94,
                  fontStyle: FontStyle.italic,
                )),
              Text('SAME FACE.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 108, letterSpacing: -3.5,
                  fontWeight: FontWeight.w900, height: 0.96,
                  fontStyle: FontStyle.italic,
                )),

              const SizedBox(height: 44),

              // ── Image (THE MAIN EVENT) ───────────────────────────────
              // Tall 5:6 frame so face dominates. BoxFit.cover +
              // alignment(0,-0.35) biases the crop toward the top so the
              // eyes land in the upper third and the chest/background
              // falls away — exactly what the Nike/Apple reference asks
              // for. Labels are rendered INSIDE the image in the bottom
              // corners at 50% opacity so they never compete with the
              // headline or the tagline.
              AspectRatio(
                aspectRatio: 5 / 6,
                child: Row(
                  children: [
                    Expanded(child: _half(
                      bytes: beforeBytes,
                      url: null,
                      label: 'NOW',
                      labelAlignment: Alignment.bottomLeft,
                    )),
                    // One-pixel white hairline — structural, not decorative.
                    Container(width: 1, color: Colors.white),
                    Expanded(child: _half(
                      bytes: null,
                      url: afterUrl,
                      label: 'FIXED',
                      labelAlignment: Alignment.bottomRight,
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 38),

              // ── Tagline — serif italic, centered. The punch. ─────────
              Center(
                child: Text(
                  "You're not unattractive.\nYou're unoptimized.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28, letterSpacing: -0.4,
                    fontWeight: FontWeight.w400, height: 1.28,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const Spacer(),

              // ── Proof block — plain text, no boxes, no bullets. ───────
              // Three short lines, Inter, medium weight. Reads like a
              // credit line on a magazine spread.
              for (final p in proofs) ...[
                Text(
                  _prettyCase(p),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 19, letterSpacing: 0.2,
                    fontWeight: FontWeight.w500, height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              const SizedBox(height: 24),

              // ── Footer row ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Measured. Not guessed.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12, letterSpacing: 0.3,
                      fontWeight: FontWeight.w400,
                    )),
                  const Spacer(),
                  Text('mirrorly.app',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12, letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One half of the before/after. The image fills the frame via
  /// BoxFit.cover biased upward so we get a tight face crop. A bottom
  /// corner carries the small NOW / FIXED label at 60% opacity over a
  /// subtle black-to-transparent gradient so the text always reads
  /// cleanly regardless of the image underneath.
  Widget _half({
    required Uint8List? bytes,
    required String? url,
    required String label,
    required Alignment labelAlignment,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
          )
        else if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0E0E0E)),
          )
        else
          const ColoredBox(color: Color(0xFF0E0E0E)),

        // Subtle scrim under the label so text is always legible.
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: 90,
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
            alignment: labelAlignment,
            child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11, letterSpacing: 3.2,
                fontWeight: FontWeight.w700,
              )),
          ),
        ),
      ],
    );
  }

  /// "TOP 3% HUNTER EYES" → "Top 3% eyes".
  /// Editorial share card reads better in sentence case than screaming-caps.
  String _prettyCase(String s) {
    final lower = s.toLowerCase();
    if (lower.isEmpty) return s;
    // Capitalise first letter; preserve any % number intact.
    return lower[0].toUpperCase() + lower.substring(1);
  }
}
