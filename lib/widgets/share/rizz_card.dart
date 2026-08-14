import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE SHARE CARD for everything built since b142 — one card, many uses.
///
/// The Rolodex, the Perfect Line, the Chain and the Verdict were all
/// shipping plain text into the share sheet. Text shares get read and
/// forgotten; an image gets posted, and a posted image is the only
/// marketing in this app that costs nothing and compounds. The app
/// already had a proper off-screen render pipeline (ShareService), so
/// this is about routing the new features through machinery that
/// already works rather than inventing anything.
///
/// ONE CARD, NOT FIVE. Five bespoke cards would drift in a fortnight and
/// the app would stop looking like one product. This takes a kicker, a
/// hero, a body and some optional furniture, and every new feature that
/// wants to be shareable fills those in rather than designing a card.
///
/// EVERY CARD PUSHES SQUADS. That's deliberate and it's the whole reason
/// to bother: a score someone posts is a flex, but a score with "SQUADS
/// OF 2–5 · SAME WOMAN EVERY DAY" under it is a recruitment poster, and
/// the squad is the mechanic that actually retains people. A man who
/// joins alone churns; a man who joins because his mate posted this has
/// somebody watching from day one.
class RizzShareData {
  /// Small caps line at the top — 'THE ROLODEX', 'PERFECT LINE'.
  final String kicker;

  /// The one big thing. A number, usually.
  final String hero;

  /// Sits under the hero in small caps — 'OF 10 NUMBERS', 'DAY STREAK'.
  final String? heroSub;

  /// A sentence in his own words, or hers, set in quotes. This is the
  /// half people actually read.
  final String? quote;

  /// One line of context under the quote.
  final String? line;

  final Color accent;

  /// Portrait assets for the medallion strip — used by the Rolodex so
  /// the card shows the collection rather than describing it. Locked
  /// ones render as silhouettes, exactly like in-app.
  final List<({String asset, bool owned})> faces;

  /// Bottom row, max three.
  final List<({String label, String value})> stats;

  const RizzShareData({
    required this.kicker,
    required this.hero,
    this.heroSub,
    this.quote,
    this.line,
    this.accent = AppColors.red,
    this.faces = const [],
    this.stats = const [],
  });
}

class RizzShareCard extends StatelessWidget {
  final RizzShareData data;
  const RizzShareCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final a = data.accent;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(84, 110, 84, 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Wordmark ────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('IMHIM',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 34,
                  letterSpacing: 9,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(width: 10),
            Text('RIZZ',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 34,
                  letterSpacing: 9,
                  fontWeight: FontWeight.w900,
                )),
          ]),
          const SizedBox(height: 78),

          Text(data.kicker,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: a,
                fontSize: 26,
                letterSpacing: 11,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 40),

          // ── The hero ────────────────────────────────────────────────
          Text(data.hero,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: data.hero.length > 3 ? 130 : 210,
                height: 0.92,
                letterSpacing: -8,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: a.withValues(alpha: 0.55), blurRadius: 110),
                ],
              )),
          if (data.heroSub != null) ...[
            const SizedBox(height: 14),
            Text(data.heroSub!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 26,
                  letterSpacing: 7,
                  fontWeight: FontWeight.w900,
                )),
          ],

          if (data.quote != null) ...[
            const SizedBox(height: 62),
            Text('"${data.quote}"',
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 40,
                  height: 1.3,
                  letterSpacing: -0.8,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w800,
                )),
          ],
          if (data.line != null) ...[
            const SizedBox(height: 26),
            Text(data.line!,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 28,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                )),
          ],

          if (data.faces.isNotEmpty) ...[
            const SizedBox(height: 60),
            SizedBox(height: 116, child: _faceStrip(a)),
          ],

          const Spacer(),

          if (data.stats.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final s in data.stats.take(3))
                  Column(children: [
                    Text(s.value,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 46,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 8),
                    Text(s.label,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 19,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
              ],
            ),
            const SizedBox(height: 54),
          ],

          // ── THE SQUAD PUSH. The reason the card exists. ─────────────
          Container(height: 2, color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 34),
          Text('SQUADS OF 2 TO 5',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: kNeon,
                fontSize: 30,
                letterSpacing: 7,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 14),
          Text(
              'Same woman every day. Everyone blind.\n'
              'Scores land side by side.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 27,
                height: 1.45,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 26),
          Text('IMHIM RIZZ',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 21,
                letterSpacing: 8,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }

  /// The collection, shown rather than described. Locked women are pure
  /// silhouettes here for the same reason they are in the app: a row
  /// that's mostly black is the ask.
  Widget _faceStrip(Color a) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final f in data.faces.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: 84,
              height: 116,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: f.owned
                      ? a.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 2,
                ),
              ),
              child: f.owned
                  ? _img(f.asset)
                  : ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF121216), BlendMode.srcIn),
                      child: _img(f.asset),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _img(String asset) => Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.3),
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: AppColors.surface2),
      );
}
