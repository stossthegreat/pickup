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

/// b174 REDESIGN — the card was a black void with floating text: one
/// Spacer() swallowed every spare pixel of the 1920–2600px canvas, the
/// girl was an 84px stamp, and a card meant to be POSTED looked like a
/// terminal. The founder's brief: "my app's UI is elite, the share cards
/// have to be cover-worthy — fill the page, place the numbers and the
/// images right, leave about a centimetre top and bottom."
///
/// The rebuild keeps the RizzShareData contract byte-identical (all nine
/// share surfaces upgrade at once) and pulls every visual move from the
/// app itself, so the card reads as the app:
///   · THE MEDALLION — the girl inside a glowing accent ring, the exact
///     motif of the live-call screen. When a card is about one woman she
///     IS the card, 470px of her, not a postage stamp.
///   · THE DUEL SPLIT — "61 — 40" renders as two scores, yours in the
///     accent with a glow, theirs dimmed white, exactly like the in-app
///     settle screen the founder called "perfect".
///   · THE TICKET — an invite code renders inside a bordered ticket
///     block. A code is a physical thing you hand someone; it gets a
///     shape, not a font size.
///   · Stats as bordered pills, the squad push as a framed banner, a
///     hairline poster frame around the whole card, and radial accent
///     glows so the black has depth instead of emptiness.
///
/// Vertical rhythm: THREE flex spacers (2/3/3) distribute the slack of
/// the variable-height canvas between the masthead, the hero block and
/// the footer — no single dead gap, any device aspect. NO flutter_animate
/// here on purpose: the card is captured off-screen in one frame, so an
/// entrance animation would freeze at t=0 and render invisible content.
class RizzShareCard extends StatelessWidget {
  final RizzShareData data;
  const RizzShareCard({super.key, required this.data});

  // ── Layout detection (data contract stays untouched) ────────────────
  /// "61 — 40" → duel layout. Only when both halves are short numbers,
  /// so a trophy name with a dash can never false-positive.
  ({String left, String right})? get _duel {
    final m = RegExp(r'^\s*(\d{1,3})\s*[—–-]\s*(\d{1,3})\s*$')
        .firstMatch(data.hero);
    if (m == null) return null;
    return (left: m.group(1)!, right: m.group(2)!);
  }

  bool get _isCode => data.heroSub == 'ENTER THIS CODE';

  @override
  Widget build(BuildContext context) {
    final a = data.accent;
    final duel = _duel;
    final medallion = data.faces.length == 1;
    final strip = data.faces.length > 1;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Depth: radial accent glow behind the hero zone ──────────
          Positioned(
            top: -260,
            left: -320,
            right: -320,
            height: 1450,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    a.withValues(alpha: 0.20),
                    a.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Counter-glow bottom so the footer doesn't sit in a pit.
          Positioned(
            bottom: -500,
            left: -200,
            right: -200,
            height: 1000,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kNeon.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Poster frame — hairline inset border, instantly "designed"
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          // ~72px top/bottom at 1080 wide ≈ the founder's "one cm each".
          Padding(
            padding: const EdgeInsets.fromLTRB(84, 78, 84, 74),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _wordmark(),
                const Spacer(flex: 2),

                _kickerChip(a),
                const SizedBox(height: 46),

                if (medallion) ...[
                  _medallion(a, data.faces.first.asset),
                  const SizedBox(height: 52),
                ],

                if (duel != null)
                  _duelHero(a, duel)
                else if (_isCode)
                  _codeTicket(a)
                else
                  _standardHero(a),

                if (data.quote != null) ...[
                  const SizedBox(height: 56),
                  _quote(a),
                ],
                if (data.line != null) ...[
                  const SizedBox(height: 30),
                  Text(data.line!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 29,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      )),
                ],

                if (strip) ...[
                  const SizedBox(height: 58),
                  _faceStrip(a),
                ],

                const Spacer(flex: 3),

                if (data.stats.isNotEmpty) ...[
                  _statPills(a),
                  const SizedBox(height: 44),
                ],

                _squadBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Masthead ─────────────────────────────────────────────────────────
  Widget _wordmark() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('IMHIM',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 36,
            letterSpacing: 10,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(width: 12),
      Text('RIZZ',
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 36,
            letterSpacing: 10,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }

  /// The kicker in a bordered chip instead of naked floating caps.
  Widget _kickerChip(Color a) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 18),
        decoration: BoxDecoration(
          color: a.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: a.withValues(alpha: 0.75), width: 2.5),
        ),
        child: Text(data.kicker,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: a,
              fontSize: 27,
              letterSpacing: 10,
              fontWeight: FontWeight.w900,
            )),
      ),
    ]);
  }

  // ── The girl, at scale — the live-call ring, the app's own icon ─────
  Widget _medallion(Color a, String asset) {
    // A quote card carries a paragraph below the hero; pull the ring in
    // so the richest variant still clears the 1920px minimum canvas.
    final double d = data.quote != null ? 380 : 470;
    return Center(
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: a, width: 7),
          boxShadow: [
            BoxShadow(
              color: a.withValues(alpha: 0.50),
              blurRadius: 130,
              spreadRadius: 6,
            ),
          ],
        ),
        child: ClipOval(child: _img(asset)),
      ),
    );
  }

  // ── Hero variants ────────────────────────────────────────────────────
  /// Two scores, not one string: yours in the accent with a glow,
  /// theirs alive but dimmed. The in-app settle screen, exported.
  Widget _duelHero(Color a, ({String left, String right}) d) {
    TextStyle num_(Color c, {List<Shadow>? sh}) => GoogleFonts.inter(
          color: c,
          fontSize: 220,
          height: 0.95,
          letterSpacing: -8,
          fontWeight: FontWeight.w900,
          shadows: sh,
        );
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(d.left,
              style: num_(a, sh: [
                Shadow(color: a.withValues(alpha: 0.65), blurRadius: 90),
              ])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Container(
              width: 64,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Text(d.right, style: num_(Colors.white.withValues(alpha: 0.55))),
        ],
      ),
      if (data.heroSub != null) ...[
        const SizedBox(height: 26),
        Text(data.heroSub!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 28,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            )),
      ],
    ]);
  }

  /// An invite code is a thing you HAND someone — it gets a ticket, a
  /// shape with edges, not a lonely font size.
  Widget _codeTicket(Color a) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 44, 48, 52),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: a.withValues(alpha: 0.70), width: 3),
        boxShadow: [
          BoxShadow(color: a.withValues(alpha: 0.22), blurRadius: 90),
        ],
      ),
      child: Column(children: [
        Text('ENTER THIS CODE',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 24,
              letterSpacing: 9,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 26),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(data.hero,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 148,
                height: 1,
                letterSpacing: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: a.withValues(alpha: 0.55), blurRadius: 80),
                ],
              )),
        ),
      ]),
    );
  }

  Widget _standardHero(Color a) {
    final isWordy = data.hero.length > 7;
    final size = isWordy ? 96.0 : (data.hero.length > 3 ? 156.0 : 250.0);
    return Column(children: [
      Text(isWordy ? data.hero.toUpperCase() : data.hero,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: size,
            height: 0.96,
            letterSpacing: isWordy ? 0 : -9,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: a.withValues(alpha: 0.60), blurRadius: 110),
            ],
          )),
      if (data.heroSub != null) ...[
        const SizedBox(height: 22),
        Text(data.heroSub!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 28,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            )),
      ],
    ]);
  }

  /// The half people actually read — set editorial, not UI.
  Widget _quote(Color a) {
    return Column(children: [
      Text('"',
          style: GoogleFonts.playfairDisplay(
            color: a,
            fontSize: 92,
            height: 0.4,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 6),
      Text(data.quote!,
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 46,
            height: 1.28,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
          )),
    ]);
  }

  // ── Furniture ────────────────────────────────────────────────────────
  Widget _statPills(Color a) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final s in data.stats.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 216),
              padding:
                  const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 2,
                ),
              ),
              child: Column(children: [
                Text(s.value,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 50,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 10),
                Text(s.label,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 19,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
            ),
          ),
      ],
    );
  }

  /// THE SQUAD PUSH — the reason the card exists, framed as its own
  /// banner instead of loose text over a divider.
  Widget _squadBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(44, 38, 44, 36),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kNeon.withValues(alpha: 0.40), width: 2),
      ),
      child: Column(children: [
        Text('SQUADS OF 2 TO 5',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: kNeon,
              fontSize: 31,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Text('IMHIM RIZZ',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }

  /// The collection, shown rather than described. Locked women are pure
  /// silhouettes here for the same reason they are in the app: a row
  /// that's mostly black is the ask.
  Widget _faceStrip(Color a) {
    return SizedBox(
      height: 128,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final f in data.faces.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: 86,
                height: 128,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(18),
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
      ),
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
