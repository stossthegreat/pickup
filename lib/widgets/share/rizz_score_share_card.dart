import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// The Academy share card — the brag that recruits.
///
/// 9:16, rendered off-screen by [ShareService.shareRizzScore]. Unlike
/// the /10 session card, this one carries the COMPETITIVE identity:
/// the 0–9999 score, the tier stamp, the rubric bars, and a challenge
/// line — "Think you'd survive it?" — so every share is a gauntlet,
/// not a boast.
///
///   RIZZ SCORE · CERTIFIED
///   ImHim  ← two-tone wordmark
///   ─────────────
///   {SCENARIO}
///
///        8,942
///      [ DANGEROUS ]
///
///   CONFIDENCE  ████████░░  84
///   ...
///
///   THINK YOU'D SURVIVE IT?
///   ImHim · imhim.app
class RizzScoreShareCard extends StatelessWidget {
  static const String domain = 'imhim.app';

  final String scenario;
  final int score; // 0..9999
  final int rating; // ELO → tier stamp
  final Map<String, int> rubric; // AXIS -> 0..100
  final String? handle;

  const RizzScoreShareCard({
    super.key,
    required this.scenario,
    required this.score,
    required this.rating,
    required this.rubric,
    this.handle,
  });

  String get _scoreText {
    final s = score.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(rating);
    return Container(
      color: AppColors.base,
      padding: const EdgeInsets.fromLTRB(72, 110, 72, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Masthead ─────────────────────────────────────────────
          Text('RIZZ SCORE · CERTIFIED',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 26,
                letterSpacing: 12,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 26),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 110,
                height: 1,
                letterSpacing: -3,
                fontWeight: FontWeight.w900,
              ),
              children: const [
                TextSpan(
                    text: 'Im', style: TextStyle(color: Colors.white)),
                TextSpan(
                    text: 'Him',
                    style: TextStyle(color: AppColors.red)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(width: 220, height: 3, color: AppColors.surface3),
          const SizedBox(height: 40),
          Text(scenario.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 34,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              )),

          // ── The number ───────────────────────────────────────────
          const Spacer(),
          Text(_scoreText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 320,
                height: 0.95,
                letterSpacing: -12,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: AppColors.red.withValues(alpha: 0.5),
                      blurRadius: 120),
                ],
              )),
          const SizedBox(height: 34),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tier.color, width: 3),
              boxShadow: tier.glow
                  ? [
                      BoxShadow(
                          color: tier.color.withValues(alpha: 0.4),
                          blurRadius: 60)
                    ]
                  : null,
            ),
            child: Text(tier.name,
                style: GoogleFonts.inter(
                  color: tier.color,
                  fontSize: 40,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w900,
                )),
          ),
          if (handle != null) ...[
            const SizedBox(height: 22),
            Text('@$handle',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                )),
          ],
          const Spacer(),

          // ── Rubric bars ──────────────────────────────────────────
          for (final e in rubric.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(children: [
                SizedBox(
                  width: 300,
                  child: Text(e.key,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 28,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: e.value / 100,
                      minHeight: 16,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation(
                          e.value >= 80 ? kNeon : AppColors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                SizedBox(
                  width: 70,
                  child: Text('${e.value}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 40),

          // ── The gauntlet ─────────────────────────────────────────
          Text("THINK YOU'D SURVIVE IT?",
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 40,
                letterSpacing: 8,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 28),
          Text('ImHim · $domain',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 26,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
