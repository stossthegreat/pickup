import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 9:16 share unit. Editorial black with a single surgical red accent.
/// Fashion-drop energy (Supreme / Y3 / CELINE), not "AI app".
///
/// Stack:
///   Mirrorly          — 40pt Playfair white
///   3 FIXES.          — 120pt italic serif, WHITE
///   SAME FACE.        — 120pt italic serif, RED (the pop)
///   [BEFORE | AFTER]  — tight 5:6 face crop, eyes in upper third
///   You're not unattractive.
///   You're unoptimized.      — 32pt italic serif white, centered
///   TOP 3% HUNTER EYES       — 28pt Inter-600 white, all-caps plain text
///   TOP 5% SYMMETRY
///   STRONG JAW
///   Measured. Not guessed.             mirrorly.app
class ShareCard extends StatelessWidget {
  static const Color accentRed = Color(0xFFE8222A);

  final Uint8List? beforeBytes;
  final String? afterUrl;
  final int correctionsCount;
  final List<String> microProofs;

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
          padding: const EdgeInsets.fromLTRB(56, 70, 56, 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wordmark — 40pt pure white, dominant.
              Text('Mirrorly',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 40, letterSpacing: -1.0,
                  fontWeight: FontWeight.w600, height: 1,
                )),

              const SizedBox(height: 56),

              // Headline — the verdict. White line one, RED line two.
              // Red draws the eye to "SAME FACE." — the magic beat.
              Text('$correctionsCount FIXES.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 120, letterSpacing: -4.5,
                  fontWeight: FontWeight.w900, height: 0.92,
                  fontStyle: FontStyle.italic,
                )),
              Text('SAME FACE.',
                style: GoogleFonts.playfairDisplay(
                  color: accentRed,
                  fontSize: 120, letterSpacing: -4.5,
                  fontWeight: FontWeight.w900, height: 0.96,
                  fontStyle: FontStyle.italic,
                )),

              const SizedBox(height: 44),

              // Image — the main event. 5:6 tight portrait, face-biased crop.
              AspectRatio(
                aspectRatio: 5 / 6,
                child: Row(
                  children: [
                    Expanded(child: _half(
                      bytes: beforeBytes, url: null,
                      label: 'NOW', align: Alignment.bottomLeft)),
                    Container(width: 1, color: Colors.white),
                    Expanded(child: _half(
                      bytes: null, url: afterUrl,
                      label: 'FIXED', align: Alignment.bottomRight)),
                  ],
                ),
              ),

              const SizedBox(height: 44),

              // Tagline — italic serif, centered, bigger so it reads.
              Center(
                child: Text(
                  "You're not unattractive.\nYou're unoptimized.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 32, letterSpacing: -0.6,
                    fontWeight: FontWeight.w400, height: 1.24,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const Spacer(),

              // Proof lines — BIG. All-caps Inter w600 so each line reads
              // like a credit on a magazine cover. No bullets, no boxes,
              // no diamond glyphs. Typography alone.
              for (final p in proofs) ...[
                Text(
                  p.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26, letterSpacing: 1.6,
                    fontWeight: FontWeight.w700, height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Measured. Not guessed.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14, letterSpacing: 0.4,
                      fontWeight: FontWeight.w400,
                    )),
                  const Spacer(),
                  Text('mirrorly.app',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14, letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                    )),
                ],
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

        Positioned(
          left: 0, right: 0, bottom: 0, height: 110,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Align(
            alignment: align,
            child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13, letterSpacing: 3.8,
                fontWeight: FontWeight.w700,
              )),
          ),
        ),
      ],
    );
  }
}
