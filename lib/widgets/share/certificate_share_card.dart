import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart' as base;
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';

/// ImHim — BECOME HIM certificate share card.
///
/// The receipt of the 60-day Ascension. Locked until Day 60; on unlock the
/// user generates and shares it from the Ascend tab's Become Him panel.
///
/// This is NOT a looks before/after — ImHim measures how hard you SHOWED UP.
/// The headline is a COMMITMENT tier (Warming Up → Unbreakable), backed by the
/// numbers that earned it: days shown up, best streak, consistency, The Five,
/// and total XP banked.
///
///   ┌──────────── 9 × 16 ────────────┐
///   │ BECOME HIM · CERTIFIED         │ ← red eyebrow
///   │            ImHim               │ ← wordmark + divider
///   │        [ HIM ]  rank stamp     │
///   │                                │
///   │         COMMITMENT             │
///   │            88                  │ ← big number
///   │        RELENTLESS              │ ← tier label
///   │                                │
///   │   "60 days. You are Him."      │ ← italic verdict
///   │            — LUCIEN            │
///   │                                │
///   │   DAYS IN        60 / 60       │ ← the receipt
///   │   BEST STREAK    42            │
///   │   CONSISTENCY    88%           │
///   │   THE FIVE       74            │
///   │   ▸ five mini-bars             │
///   │                                │
///   │        12,480 XP BANKED        │
///   │   ImHim · BECOME THE GUY … app │
///   └────────────────────────────────┘
class CertificateShareCard extends StatelessWidget {
  /// The reached rank label (e.g. "HIM" / "BECOME HIM").
  final String rankLabel;

  /// Days shown up out of the 60-day ascension.
  final int day;
  final int totalDays;

  /// Best daily streak reached.
  final int streak;

  /// Rolling consistency, 0-100.
  final int consistency;

  /// The Five weighted overall, 0-100.
  final int overall;

  /// The five dimensions (confidence/presence/game/humor/listening), 0-100.
  final Map<String, int> dims;

  /// Commitment tier label + score.
  final String commitmentLabel;
  final int commitmentScore;

  /// Total XP banked — the flex number.
  final int xp;

  /// One italic verdict line.
  final String verdict;

  const CertificateShareCard({
    super.key,
    required this.rankLabel,
    required this.day,
    required this.streak,
    required this.consistency,
    required this.overall,
    required this.dims,
    required this.commitmentLabel,
    required this.commitmentScore,
    required this.xp,
    this.totalDays = 60,
    this.verdict = '60 days. You\'re not the man who started this.',
  });

  static const _dimOrder = <(String, String)>[
    ('confidence', 'CONFIDENCE'),
    ('presence', 'PRESENCE'),
    ('game', 'GAME'),
    ('humor', 'HUMOUR'),
    ('listening', 'LISTENING'),
  ];

  String get _date {
    final n = DateTime.now();
    const m = ['JAN','FEB','MAR','APR','MAY','JUN',
               'JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${m[n.month - 1]} ${n.day.toString().padLeft(2, '0')} ${n.year}';
  }

  String _fmtXp(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width, height: size.height, color: AppColors.base,
      child: Stack(
        children: [
          // Atmospheric red halo — same brand keying as the other cards.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.0,
                  colors: [
                    base.AppColors.red.withValues(alpha: 0.26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 96, 64, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Eyebrow + brand
                Text('BECOME HIM · CERTIFIED',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: base.AppColors.red,
                    fontSize: 26, letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 16),
                _ImHimMark(fontSize: 100),
                const SizedBox(height: 14),
                Container(width: 110, height: 3, color: base.AppColors.red),
                const SizedBox(height: 22),
                // Rank stamp — the level reached.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  decoration: BoxDecoration(
                    color: base.AppColors.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: base.AppColors.red, width: 2),
                  ),
                  child: Text(rankLabel.toUpperCase(),
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontSize: 30, letterSpacing: 5,
                      fontWeight: FontWeight.w900,
                    )),
                ),

                const Spacer(flex: 2),

                // ── COMMITMENT — the headline.
                Text('COMMITMENT',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: base.AppColors.red,
                    fontSize: 30, letterSpacing: 8,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 6),
                Text('$commitmentScore',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 260, height: 0.9,
                    letterSpacing: -8,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 4),
                Text(commitmentLabel.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: base.AppColors.red,
                    fontSize: 54, height: 1.0,
                    letterSpacing: 1,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  )),

                const Spacer(flex: 2),

                if (verdict.isNotEmpty) ...[
                  Text('"$verdict"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 32, height: 1.35,
                      letterSpacing: -0.6,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(height: 8),
                  Text('— LUCIEN',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 18, letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    )),
                  const SizedBox(height: 30),
                ],

                // ── The receipt — the numbers that earned it.
                _StatLine(label: 'DAYS IN',     value: '$day / $totalDays'),
                const SizedBox(height: 14),
                _StatLine(label: 'BEST STREAK',  value: '$streak'),
                const SizedBox(height: 14),
                _StatLine(label: 'CONSISTENCY',  value: '$consistency%'),
                const SizedBox(height: 14),
                _StatLine(label: 'THE FIVE',     value: '$overall'),

                const SizedBox(height: 22),

                // ── The Five breakdown — mini bars.
                for (final (key, label) in _dimOrder) ...[
                  _DimBar(label: label, value: dims[key] ?? 0),
                  const SizedBox(height: 10),
                ],

                const Spacer(flex: 2),

                // ── XP flex
                Text('${_fmtXp(xp)} XP BANKED',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: AppColors.signalAmber,
                    fontSize: 26, letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  )),

                const SizedBox(height: 24),

                // ── Footer wordmark + date
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
                Text('BECOME THE GUY WHO OWNS THE ROOM  ·  imhim.app',
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
}

/// One receipt line — "DAYS IN            60 / 60".
class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(label,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 26, letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        ),
        Text(value,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 48, height: 1,
            letterSpacing: -1.2,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
          )),
      ],
    );
  }
}

/// One of the five dimension bars.
class _DimBar extends StatelessWidget {
  final String label;
  final int value;
  const _DimBar({required this.label, required this.value});

  Color get _tint => value >= 70
      ? AppColors.signalGreen
      : (value <= 45 ? base.AppColors.red : AppColors.accent);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Text(label,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 22, letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(_tint),
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 70,
          child: Text('$value',
            textAlign: TextAlign.right,
            style: AppTypography.label.copyWith(
              color: _tint,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            )),
        ),
      ],
    );
  }
}

/// Two-tone ImHim wordmark — italic Playfair, white "Im" + red "Him".
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
