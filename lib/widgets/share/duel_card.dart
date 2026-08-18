import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../services/division.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';
import '../academy/rank_emblem.dart';
import '../common/imhim_wordmark.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE DUEL CARD — the verdict screen, frozen and branded
/// ══════════════════════════════════════════════════════════════════════
///
/// The old share card was a generic template with the scores poured into
/// slots, and it looked like one — while the screen the man had JUST
/// been looking at was the best-looking thing in the app. So the card
/// stopped being its own design. This is the verdict screen's exact
/// anatomy at poster scale: same black, same radial glow in the result's
/// colour, same glowing score pair, same VICTORY slam, same margin line,
/// same rank emblem — plus the one thing a screenshot can't carry, the
/// brand block at the foot.
///
/// Every size in here is the verdict's size × 2.77, because the screen
/// composes at ~390pt wide and this canvas is 1080. Scale the layout,
/// not the design.
class DuelShareData {
  final String me;
  final String opponent;
  final int myScore;
  final int theirScore;
  final bool iWon;
  final bool tie;

  /// The woman both were run against — named in the context line.
  final String girlName;

  /// Standing after the fight. Null when unknown (sharing an old row).
  final Rank? rank;
  final int? delta;

  const DuelShareData({
    required this.me,
    required this.opponent,
    required this.myScore,
    required this.theirScore,
    required this.iWon,
    required this.tie,
    required this.girlName,
    this.rank,
    this.delta,
  });
}

class DuelShareCard extends StatelessWidget {
  final DuelShareData data;
  const DuelShareCard({super.key, required this.data});

  Color get _tone =>
      data.tie ? AppColors.signalAmber : (data.iWon ? kNeon : AppColors.red);

  String get _headline => data.tie ? 'DRAW' : (data.iWon ? 'VICTORY' : 'DEFEAT');

  /// Verbatim from battle_verdict.dart — the card must say what the
  /// screen said, not a summary of it.
  String get _margin {
    final gap = (data.myScore - data.theirScore).abs();
    if (data.tie) return 'Identical. Neither of us gave her a reason to pick.';
    if (data.iWon) {
      if (gap <= 3) return 'By $gap. That could have gone either way.';
      if (gap <= 12) return 'I had the better of it.';
      return 'Not close. $gap clear.';
    }
    if (gap <= 3) return '$gap point${gap == 1 ? '' : 's'} in it.';
    if (gap <= 12) return 'He read her better. $gap points in it.';
    return 'His day. $gap points.';
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Container(
      width: 1080,
      height: 1920,
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 1.15,
                colors: [tone.withValues(alpha: 0.20), Colors.black],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 120, 72, 84),
          child: Column(children: [
            Text('RIZZ BATTLE',
                style: GoogleFonts.inter(
                  color: AppColors.signalAmber,
                  fontSize: 34,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 140),

            // ── THE TWO NUMBERS ──────────────────────────────────────
            Row(children: [
              Expanded(
                child: _Side(
                  name: data.me,
                  score: data.myScore,
                  color: data.iWon ? kNeon : Colors.white,
                ),
              ),
              Text('—',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  )),
              Expanded(
                child: _Side(
                  name: data.opponent,
                  score: data.theirScore,
                  color: !data.iWon && !data.tie ? AppColors.red : Colors.white,
                ),
              ),
            ]),

            const SizedBox(height: 90),
            Text(_headline,
                style: GoogleFonts.inter(
                  color: tone,
                  fontSize: 118,
                  height: 1,
                  letterSpacing: 11,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: tone.withValues(alpha: 0.65), blurRadius: 120)
                  ],
                )),
            const SizedBox(height: 26),
            Text(_margin,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 35,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                )),

            const Spacer(),

            // ── STANDING ─────────────────────────────────────────────
            if (data.rank != null) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                RankEmblem(rank: data.rank!, size: 150, showProgress: false),
                const SizedBox(width: 44),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.rank!.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 52,
                        height: 1.05,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 8),
                  Text('${Economy.commas(data.rank!.rating)} RR',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      )),
                ]),
                if (data.delta != null) ...[
                  const SizedBox(width: 36),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: (data.delta! >= 0 ? kNeon : AppColors.red)
                              .withValues(alpha: 0.8),
                          width: 3),
                    ),
                    child: Text(
                        '${data.delta! >= 0 ? '+' : ''}${data.delta}',
                        style: GoogleFonts.inter(
                          color: data.delta! >= 0 ? kNeon : AppColors.red,
                          fontSize: 44,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ],
              ]),
              const Spacer(),
            ],

            // ── THE BRAND — the one thing the screen never carries ──
            Container(height: 2, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 46),
            const ImHimWordmark(fontSize: 72, letterSpacing: -2),
            const SizedBox(height: 16),
            Text(
                'Same woman. Both blind. ${data.girlName} never knew '
                'either of us was being scored.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 30,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
      ]),
    );
  }
}

class _Side extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  const _Side({required this.name, required this.score, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 31,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 20),
        Text('$score',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 132,
              height: 1,
              letterSpacing: -5,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.45), blurRadius: 84)
              ],
            )),
        const SizedBox(height: 14),
        Text('OUT OF 100',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 22,
              letterSpacing: 5,
              fontWeight: FontWeight.w900,
            )),
      ]);
}
