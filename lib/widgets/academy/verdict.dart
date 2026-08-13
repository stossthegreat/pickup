import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/rolodex_service.dart';
import '../../services/roster.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';

/// THE VERDICT — the app's payout, redenominated.
///
/// The reveal already had good theatre: a hold, a count-up, a grade that
/// slams. What it paid out was arithmetic. A number cannot hurt you, and
/// a reward that cannot hurt cannot thrill either — the two run on the
/// same circuit, and losing about twice as hard as you win is the whole
/// reason a slot machine works.
///
/// So the payout stops being a score and becomes HER DECISION, in three
/// bands, with the number demoted to a footnote:
///
///   OUT   — "Sofia is typing…" for four seconds. Then it stops. Nothing
///           arrives. That silence is the single most valuable thing on
///           this screen, it costs nothing to build, and it is the only
///           punishment in the app a man will actually feel.
///   IN    — she replies. A real line, in her voice, and a different one
///           each time so the payout can't be predicted.
///   WON   — she gives you the number, and the card flips into the
///           Rolodex. Rare, earned, permanent.
///
/// Bands scale with her rarity (see [Rarity.bar] / [Rarity.floor]) so an
/// ICE card is a genuine trophy rather than the tenth identical one.
///
/// PEAK-END: what he remembers is the peak and the ending. The ending is
/// therefore never the number — it is always her.

enum VerdictBand { out, interested, won }

class Verdict {
  final VerdictBand band;
  final Rarity rarity;

  /// Her interest at the end, 0..100.
  final int score;

  /// The highest it ever got. On a loss this is the whole story: "she
  /// was at 71 after your fourth message" turns a flat failure into a
  /// near miss, which is the version he runs back.
  final int peak;

  const Verdict({
    required this.band,
    required this.rarity,
    required this.score,
    required this.peak,
  });

  factory Verdict.of({
    required GirlBrief girl,
    required int score,
    required int peak,
  }) {
    final r = rarityOf(girl);
    final band = score >= r.bar
        ? VerdictBand.won
        : score >= r.floor
            ? VerdictBand.interested
            : VerdictBand.out;
    return Verdict(band: band, rarity: r, score: score, peak: peak);
  }

  bool get lost => band == VerdictBand.out;

  /// How far off the next band he finished. Named out loud only when
  /// it's genuinely close — "so close" over a wide gap is how a screen
  /// loses its credibility, and credibility is the thing the near miss
  /// is spending.
  int? get shortBy {
    final target = band == VerdictBand.out ? rarity.floor : rarity.bar;
    if (band == VerdictBand.won) return null;
    final gap = target - peak;
    return (gap > 0 && gap <= 12) ? gap : null;
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HER WORDS
// ══════════════════════════════════════════════════════════════════════

/// Deterministic per result so it never changes under him mid-animation,
/// varied across results so the payout stays unpredictable. Variable
/// reward doesn't need randomness — it needs him to be unable to guess.
String _pick(List<String> pool, int seed) => pool[seed.abs() % pool.length];

const _interested = <String>[
  'ok. that was actually good.',
  'you\'re more interesting than you look.',
  'i\'ll give you that one.',
  'hm. don\'t ruin it now.',
  'alright. i\'m listening.',
  'you almost had me there.',
  'keep going and we\'ll see.',
];

const _won = <String>[
  'here. don\'t make me regret it.',
  'fine. you win. text me tonight.',
  'ok. you earned that.',
  'take it before i change my mind.',
  'don\'t be weird about it.',
];

// ══════════════════════════════════════════════════════════════════════
//  THE ACT
// ══════════════════════════════════════════════════════════════════════

/// The staged reveal. Push it full-screen; it pops itself.
///
/// [ceremony] false skips the four-second wait and goes straight to the
/// outcome — used when he's already seen this verdict land once, because
/// the second time she gives you her number it is not a moment.
class VerdictAct extends StatefulWidget {
  final GirlBrief girl;
  final Verdict verdict;

  /// The line of his that moved her most. Kept on the card forever.
  final String line;

  final bool ceremony;

  /// True when this win created a NEW Rolodex card.
  final bool newCard;

  const VerdictAct({
    super.key,
    required this.girl,
    required this.verdict,
    required this.line,
    this.ceremony = true,
    this.newCard = false,
  });

  @override
  State<VerdictAct> createState() => _VerdictActState();
}

class _VerdictActState extends State<VerdictAct> {
  /// 0 typing · 1 the beat of nothing · 2 outcome · 3 actions
  int _stage = 0;
  final _timers = <Timer>[];

  Verdict get _v => widget.verdict;
  Color get _accent => widget.girl.accent;

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));

    if (!widget.ceremony) {
      _stage = 2;
      at(600, () => setState(() => _stage = 3));
      return;
    }

    // THE WAIT. Four seconds of her deciding. Long enough to be
    // uncomfortable, which is the point — the gap between committing and
    // knowing is the only thing a slot machine actually sells, and it is
    // the one part of the machine that costs nothing to build.
    Sfx.hold();
    at(600, Feel.tick);
    at(1800, Feel.tick);
    at(3000, Feel.tick);

    if (_v.lost) {
      // The dots stop. Then a full second where LITERALLY NOTHING
      // HAPPENS. Every instinct says fill it; filling it is what turns a
      // gut-punch back into a form validation error.
      at(3900, () => setState(() => _stage = 1));
      at(5100, () {
        setState(() => _stage = 2);
        Feel.lost();
        Sfx.lost();
      });
      at(6000, () => setState(() => _stage = 3));
    } else {
      at(3900, () {
        setState(() => _stage = 2);
        if (_v.band == VerdictBand.won) {
          Feel.win();
          Sfx.win();
        } else {
          Feel.banked();
          Sfx.scoreLand();
        }
      });
      at(_v.band == VerdictBand.won ? 5400 : 4800,
          () => setState(() => _stage = 3));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = _v.band == VerdictBand.won;
    return Material(
      color: Colors.black,
      child: Stack(children: [
        if (won && _stage >= 2)
          Positioned.fill(child: Burst(color: _accent, pieces: 44)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 14, 26, 20),
            child: Column(children: [
              _header(),
              Expanded(child: Center(child: _body())),
              if (_stage >= 3) _actions(),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Her, at the top, the whole way through ────────────────────────
  Widget _header() {
    // On a loss she desaturates as the verdict lands — she is leaving
    // the screen, not just the conversation.
    final gone = _v.lost && _stage >= 2;
    return Column(children: [
      AnimatedOpacity(
        opacity: gone ? 0.28 : 1,
        duration: const Duration(milliseconds: 900),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: gone ? AppColors.surface3 : _accent, width: 2),
            boxShadow: gone
                ? null
                : [
                    BoxShadow(
                        color: _accent.withValues(alpha: 0.45),
                        blurRadius: 30)
                  ],
          ),
          child: ClipOval(
            child: Image.asset(
              widget.girl.asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              errorBuilder: (_, __, ___) => ColoredBox(
                color: AppColors.surface2,
                child: Center(
                  child: Text(widget.girl.name.characters.first.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _accent,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(widget.girl.name.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 5),
      _RarityChip(rarity: _v.rarity),
    ]);
  }

  Widget _body() {
    if (_stage == 0) return _typing();
    if (_stage == 1) return const SizedBox.shrink(); // the beat of nothing
    return switch (_v.band) {
      VerdictBand.out => _outcomeOut(),
      VerdictBand.interested => _outcomeIn(),
      VerdictBand.won => _outcomeWon(),
    };
  }

  /// Stage 0 — three dots, exactly like a real messaging app, because
  /// that is the exact anxiety we're borrowing.
  Widget _typing() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 7),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(
                      begin: 0.25,
                      end: 1,
                      duration: 480.ms,
                      delay: (i * 160).ms),
            ),
        ]),
      ),
      const SizedBox(height: 22),
      Text('${widget.girl.name.toUpperCase()} IS TYPING',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 10.5,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }

  /// She's gone. No bubble, no consolation, no "nice try". The screen
  /// says the one true thing and then shuts up.
  Widget _outcomeOut() {
    final short = _v.shortBy;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('SHE LEFT THE CHAT',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 17,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(duration: 700.ms),
      const SizedBox(height: 18),
      // The peak is the mercy, and it's also the hook: he didn't fail
      // flat, he was in it and lost it, and he knows roughly where.
      Text('She was at ${_v.peak} before it went.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ))
          .animate()
          .fadeIn(delay: 500.ms, duration: 500.ms),
      if (short != null) ...[
        const SizedBox(height: 14),
        Flinch(
          active: true,
          child: Text('$short SHORT OF KEEPING HER.',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 12,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
              )),
        ).animate().fadeIn(delay: 900.ms),
      ],
    ]);
  }

  /// The partial reward — the band most runs land in. It has to read as
  /// progress, or the middle of the distribution becomes a place men
  /// stop visiting.
  Widget _outcomeIn() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Bubble(text: _pick(_interested, _v.score * 7 + _v.peak), accent: _accent)
          .animate()
          .fadeIn(duration: 420.ms)
          .slideY(begin: 0.35, end: 0, curve: Curves.easeOutBack),
      const SizedBox(height: 26),
      Text('SHE\'S IN',
              style: GoogleFonts.inter(
                color: _accent,
                fontSize: 14,
                letterSpacing: 4.5,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(delay: 450.ms),
      const SizedBox(height: 10),
      Text('Not her number. Not yet.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ))
          .animate()
          .fadeIn(delay: 620.ms),
      const SizedBox(height: 18),
      // The goal gradient: effort accelerates near a visible finish, so
      // the bar he missed is stated as a number he can picture.
      Text('${_v.rarity.bar} KEEPS HER · YOU HIT ${_v.peak}',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(delay: 800.ms),
    ]);
  }

  /// The jackpot. Everything here is designed to be screenshotted.
  Widget _outcomeWon() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Bubble(text: _pick(_won, _v.score * 3 + _v.peak), accent: _accent)
          .animate()
          .fadeIn(duration: 380.ms)
          .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
      const SizedBox(height: 24),
      // The number itself, rendered as a thing you'd save.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.call_rounded, size: 17, color: _accent),
          const SizedBox(width: 11),
          Text(Rolodex.numberFor(widget.girl.id),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
        ]),
      )
          .animate()
          .fadeIn(delay: 520.ms, duration: 320.ms)
          .scale(
              begin: const Offset(0.86, 0.86),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack),
      const SizedBox(height: 22),
      Text(widget.newCard ? 'SAVED TO YOUR ROLODEX' : 'STILL YOURS',
              style: GoogleFonts.inter(
                color: kNeon,
                fontSize: 11.5,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(delay: 900.ms),
      if (widget.line.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('THE LINE THAT DID IT',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 8.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                ))
            .animate()
            .fadeIn(delay: 1100.ms),
        const SizedBox(height: 7),
        Text('"${widget.line}"',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ))
            .animate()
            .fadeIn(delay: 1220.ms),
      ],
    ]);
  }

  Widget _actions() {
    final won = _v.band == VerdictBand.won;
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: GameButton(
          label: won ? 'SEE THE ROLODEX' : 'RUN IT BACK',
          color: won ? kNeon : AppColors.red,
          textColor: won ? Colors.black : Colors.white,
          icon: won
              ? Icons.person_add_alt_1_rounded
              : Icons.refresh_rounded,
          onTap: () => Navigator.of(context).pop(won ? 'rolodex' : 'again'),
        ),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(won ? 'LATER' : 'LEAVE IT',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            )),
      ),
    ]).animate().fadeIn(duration: 320.ms);
  }
}

/// One of her messages, shaped like the ones in the chat he just left so
/// the verdict reads as the same conversation continuing.
class _Bubble extends StatelessWidget {
  final String text;
  final Color accent;
  const _Bubble({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

class _RarityChip extends StatelessWidget {
  final Rarity rarity;
  const _RarityChip({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final tint = rarity.tint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Text(rarity.label,
          style: GoogleFonts.inter(
            color: tint,
            fontSize: 8,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}
