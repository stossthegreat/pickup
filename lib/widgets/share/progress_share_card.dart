import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart' as base;
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';

/// ImHim PROGRESS share card — the receipt of the glow-up.
///
/// 9:16 composition rendered off-screen by [ShareService.shareProgress]
/// at 1080×device-aspect logical size. Designed to read as a SINGLE
/// brutal claim from the For You feed:
///
///   ┌───────────────── 9 × 16 ─────────────────┐
///   │   DAY 14 · GLOW UP · CERTIFIED           │
///   │                                          │
///   │             ImHim                        │
///   │             ─────                        │
///   │                                          │
///   │             DAY                          │
///   │              14                          │
///   │           STREAK · 14 🔥                 │
///   │                                          │
///   │   AESTHETIC INDEX  →  60   (+12)         │
///   │   VOICE GAME       →  72   (+25)         │
///   │   EYE CONTACT      →  84   (+19)         │
///   │                                          │
///   │   ▁▁▂▃▅▆█  ←  spark line of the arc      │
///   │                                          │
///   │   2 SCANS · 6 GAME REPS · 4 DRILLS       │
///   │                                          │
///   │     "I scanned my face and committed."    │
///   │                                          │
///   │   ImHim · BECOME THE GUY WHO OWNS THE ROOM │
///   │   imhim.app                              │
///   └──────────────────────────────────────────┘
///
/// The psychology brief — why this gets posted:
///  1. CURIOSITY GAP — a number on a black card with no explanation
///     makes the viewer scroll back and tap profile (= app discovery).
///  2. RECEIPT FRAMING — "DAY 14" / "STREAK 14" doubles as proof of
///     consistency, which is the trait the user is broadcasting.
///  3. ROOM FOR DUNK — leaving a verdict line ("committed") lets the
///     poster narrate their own version to their followers.
///  4. SAME WORDMARK AS THE APP — anyone who's seen ImHim once
///     recognises the mark instantly.
class ProgressShareCard extends StatelessWidget {
  /// Days into the protocol (1..N).
  final int day;

  /// Consecutive streak days. May equal [day] (perfect streak) or be
  /// less (recovered streak).
  final int streakDays;

  /// Total scans the user has captured.
  final int scanCount;

  /// Total Free Flow reps.
  final int gameReps;

  /// Total drills done across Eyes + Voice surfaces.
  final int drillsCount;

  /// Latest aesthetic-index score (0..100).
  final int? aestheticNow;

  /// Delta from first scan to most-recent (positive = improved).
  final int? aestheticDelta;

  /// Latest voice-game score (0..100).
  final int? voiceNow;

  /// Delta in voice score across the user's reps.
  final int? voiceDelta;

  /// Aura score (0..100) — the Auralay-imported combined index.
  final int? auraNow;

  /// v290 — IMHIM SCORE composite (0..100). The hero of the card.
  /// Looks + Game demoted to "BUILT FROM" inputs underneath; the
  /// score on top is what the viewer reads first.
  final int? imhimNow;

  /// v290 — IMHIM SCORE delta from the prior weekly snapshot.
  /// Positive numbers render as green ↑; null / 0 hide the chip
  /// rather than show a confusing "+0".
  final int? imhimDelta;

  /// One-line user-facing verdict — usually the highest-scoring
  /// surface's last verdict so the card has a quote attached. If empty
  /// the quote block is hidden.
  final String verdict;

  const ProgressShareCard({
    super.key,
    required this.day,
    required this.streakDays,
    required this.scanCount,
    required this.gameReps,
    required this.drillsCount,
    this.aestheticNow,
    this.aestheticDelta,
    this.voiceNow,
    this.voiceDelta,
    this.auraNow,
    this.imhimNow,
    this.imhimDelta,
    this.verdict = '',
  });

  String get _date {
    final n = DateTime.now();
    const m = ['JAN','FEB','MAR','APR','MAY','JUN',
               'JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${m[n.month - 1]} ${n.day.toString().padLeft(2, '0')} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // v290 — IMHIM SCORE leads. Bro: "imhim score is in the progress
    // icon share right now its game looks scores but above them in
    // the middle needs imhim score". Same atmospheric halo, same
    // brand. The hero number is now the unified composite (320pt
    // italic), with LOOKS / GAME demoted to the BUILT FROM input row
    // underneath. This is the consultant's "one character to level"
    // psychology applied to the share asset.

    return Container(
      width: size.width, height: size.height, color: AppColors.base,
      child: Stack(
        children: [
          // Atmospheric halo — keyed off the red brand so the card
          // doesn't shift mood when scores change.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.95,
                  colors: [
                    base.AppColors.red.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 90, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Eyebrow — what this is.
                Text('MY GLOW UP · CERTIFIED',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 24, letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 16),
                // ── Brand — two-tone ImHim.
                _ImHimMark(fontSize: 100),
                const SizedBox(height: 12),
                Container(width: 100, height: 3, color: base.AppColors.red),
                const SizedBox(height: 22),

                // ── TAGLINE.
                Text('LOOKS GET ATTENTION.\nGAME KEEPS IT.',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 28, letterSpacing: 2.4,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  )),

                const SizedBox(height: 40),

                // ── IMHIM SCORE HERO. The unified composite.
                _ImHimScoreShareHero(
                  score: imhimNow,
                  delta: imhimDelta,
                ),

                const SizedBox(height: 24),

                // ── Day + streak pill — anchors the score in TIME.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: base.AppColors.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: base.AppColors.red.withValues(alpha: 0.55),
                        width: 2),
                  ),
                  child: Text(
                    streakDays > 0
                        ? 'DAY $day  ·  STREAK $streakDays 🔥'
                        : 'DAY $day  ·  RAW',
                    style: AppTypography.label.copyWith(
                      color: base.AppColors.red,
                      fontSize: 22, letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    )),
                ),

                const Spacer(),

                // ── BUILT FROM — the input row underneath the hero.
                // Looks + Game (and Aura if active) demoted from their
                // old hero-twin treatment so the IMHIM number on top
                // gets the full read; viewers still see the inputs so
                // the composite reads as honest, not magic.
                Text('BUILT FROM',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 18, letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 16),
                _BuiltFromRow(
                  label: 'LOOKS',
                  value: aestheticNow,
                  delta: aestheticDelta,
                  accent: AppColors.accent,
                ),
                const SizedBox(height: 10),
                _BuiltFromRow(
                  label: 'GAME',
                  value: voiceNow,
                  delta: voiceDelta,
                  accent: AppColors.signalAmber,
                ),
                if (auraNow != null && auraNow! > 0) ...[
                  const SizedBox(height: 10),
                  _BuiltFromRow(
                    label: 'AURA',
                    value: auraNow,
                    delta: null,
                    accent: AppColors.signalGreen,
                  ),
                ],

                const SizedBox(height: 20),

                // ── Activity strip — single line of proof.
                Text(_activityLine,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 18, letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  )),

                if (verdict.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('"$verdict"',
                    textAlign: TextAlign.center,
                    style: AppTypography.h1Italic.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 26, height: 1.4,
                      fontStyle: FontStyle.italic,
                    )),
                ],

                const SizedBox(height: 22),

                // Footer wordmark + date.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ImHimMark(fontSize: 28),
                    const SizedBox(width: 14),
                    Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.textTertiary,
                        shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 14),
                    Text('CERTIFIED  $_date',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 22, letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      )),
                  ],
                ),
                const SizedBox(height: 10),
                Text("BECOME THE GUY WHO OWNS THE ROOM  ·  imhim.app",
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 20, letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _activityLine {
    final parts = <String>[];
    if (scanCount   > 0) parts.add('$scanCount SCAN${scanCount   == 1 ? '' : 'S'}');
    if (gameReps    > 0) parts.add('$gameReps GAME REP${gameReps == 1 ? '' : 'S'}');
    if (drillsCount > 0) parts.add('$drillsCount DRILL${drillsCount == 1 ? '' : 'S'}');
    return parts.isEmpty ? 'FIRST DAY ON THE PROTOCOL' : parts.join('  ·  ');
  }
}

/// v290 — IMHIM SCORE share hero. Single massive italic numeral on
/// top of the share card, "/100" anchored beneath, optional weekly
/// delta pill underneath. The composite is the hook; viewers read
/// the number first, then the BUILT FROM row tells them how it was
/// earned. Same italic Playfair language as the in-app score block.
class _ImHimScoreShareHero extends StatelessWidget {
  final int? score;
  final int? delta;
  const _ImHimScoreShareHero({required this.score, required this.delta});

  @override
  Widget build(BuildContext context) {
    final hasValue   = score != null;
    final hasDelta   = hasValue && delta != null && delta != 0;
    final positive   = (delta ?? 0) >= 0;
    final deltaColor = positive ? AppColors.signalGreen : AppColors.signalRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('IMHIM SCORE',
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: base.AppColors.red,
            fontSize: 36, letterSpacing: 8,
            fontWeight: FontWeight.w900,
          )),
        const SizedBox(height: 18),
        Text(hasValue ? '${score!}' : '—',
          textAlign: TextAlign.center,
          style: AppTypography.display.copyWith(
            color: hasValue ? AppColors.textPrimary
                            : AppColors.textTertiary,
            fontSize: 360, height: 0.92,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            letterSpacing: -10,
          )),
        const SizedBox(height: 4),
        Text(hasValue ? '/ 100' : 'NOT YET',
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: AppColors.textTertiary,
            fontSize: 26, letterSpacing: 4,
            fontWeight: FontWeight.w900,
          )),
        if (hasDelta) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: deltaColor.withValues(alpha: 0.6), width: 1.8),
            ),
            child: Text(
              '${positive ? "↑ +" : "↓ "}$delta THIS WEEK',
              style: AppTypography.label.copyWith(
                color: deltaColor,
                fontSize: 22, letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
          ),
        ],
      ],
    );
  }
}

/// v290 — BUILT FROM input row. One label on the left, a thin
/// progress bar through the middle, the value pinned right. Three
/// stacked rows under the IMHIM hero make the composite read as
/// honest evidence rather than a magic number. Optional delta chip
/// hangs off the right when we have a non-zero delta for the
/// component.
class _BuiltFromRow extends StatelessWidget {
  final String label;
  final int?   value;
  final int?   delta;
  final Color  accent;
  const _BuiltFromRow({
    required this.label,
    required this.value,
    required this.delta,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue   = value != null;
    final hasDelta   = hasValue && delta != null && delta != 0;
    final positive   = (delta ?? 0) >= 0;
    final deltaColor = positive ? AppColors.signalGreen : AppColors.signalRed;
    final width      = hasValue ? (value! / 100).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
            style: AppTypography.label.copyWith(
              color: accent,
              fontSize: 26, letterSpacing: 4,
              fontWeight: FontWeight.w900,
            )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: AppColors.textTertiary.withValues(alpha: 0.25),
                ),
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: 10,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: Text(hasValue ? '${value!}' : '—',
            textAlign: TextAlign.right,
            style: AppTypography.display.copyWith(
              color: AppColors.textPrimary,
              fontSize: 36, height: 1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            )),
        ),
        if (hasDelta) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${positive ? "+" : ""}$delta',
              style: AppTypography.label.copyWith(
                color: deltaColor,
                fontSize: 16, letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
          ),
        ] else
          const SizedBox(width: 44), // align even when no chip
      ],
    );
  }
}

/// Two-tone ImHim wordmark — italic Playfair, white "Im" + red "Him".
/// Duplicated locally so the share card has no theme-variant dependency.
class _ImHimMark extends StatelessWidget {
  final double fontSize;
  const _ImHimMark({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.playfairDisplay(
      fontSize:      fontSize,
      height:        1.0,
      letterSpacing: -fontSize * 0.02,
      fontStyle:     FontStyle.italic,
      fontWeight:    FontWeight.w900,
    );
    return RichText(
      text: TextSpan(
        style: style.copyWith(color: Colors.white),
        children: [
          const TextSpan(text: 'Im'),
          TextSpan(
            text: 'Him',
            style: style.copyWith(color: base.AppColors.red),
          ),
        ],
      ),
    );
  }
}
