import 'package:flutter/material.dart';

import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';

/// MIRRORLY universal score share card — the one that gets posted.
///
/// 9:16 composition rendered off-screen by [ShareService.shareScore] at
/// 1080×1920 logical size. Used by every result in the app — The Gaze,
/// Eye Contact + Voice, and Free Flow — so a shared card always reads as
/// the same brand, scored the same way: out of 10.
///
///   MIRRORLY
///   ───────────────
///   THE GAZE · THE LOCK
///
///            8
///          / 10
///
///        [ MAGNETIC ]
///
///   "One brutal italic line about how it went."
///                  — LUCIEN
///
///   EYE STABILITY     ██████████░░  9
///   TENSION           ████████░░░░  7
///   ...
///
///   MIRRORLY · OWN THE ROOM
class ScoreShareCard extends StatelessWidget {
  /// Brand shown at the very top. Change this one constant to re-skin the
  /// whole share system for another app (e.g. MIRRORLY).
  static const String brand = 'MIRRORLY';
  static const String tagline = 'OWN THE ROOM';

  /// What this card is for — e.g. "THE GAZE", "FREE FLOW",
  /// "EYE CONTACT + VOICE".
  final String kindLabel;

  /// The specific lesson / scene — e.g. "THE LOCK", "COLD".
  final String subLabel;

  /// 0–10.
  final int score;

  /// Single-word verdict stamp — MAGNETIC / DECIDED / 8/10 vibe word.
  final String badge;

  /// One brutal italic line (Lucien's verdict / the lesson quote).
  final String verdict;

  /// Optional breakdown rows: (label, 0–10).
  final List<({String label, int score})> stats;

  const ScoreShareCard({
    super.key,
    required this.kindLabel,
    required this.subLabel,
    required this.score,
    required this.badge,
    required this.verdict,
    this.stats = const [],
  });

  Color get _scoreColor => score >= 7
      ? AppColors.signalGreen
      : (score <= 3 ? AppColors.signalRed : AppColors.accent);

  String get _date {
    final n = DateTime.now();
    const m = ['JAN','FEB','MAR','APR','MAY','JUN',
               'JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${m[n.month - 1]} ${n.day.toString().padLeft(2, '0')} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Fill the device-aspect canvas the ShareService composes us into, so
    // the exported card is the SAME size as the in-app full screen.
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: AppColors.base,
      child: Stack(
        children: [
          // Atmospheric halo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.9,
                  colors: [
                    _scoreColor.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(96, 120, 96, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Certificate eyebrow — says exactly what this is.
                Text('CERTIFICATE OF GAME',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 22),
                // Brand.
                Text(brand,
                    style: AppTypography.display.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 80,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    )),
                const SizedBox(height: 20),
                Container(
                    width: 120, height: 3, color: AppColors.accent),
                const SizedBox(height: 28),
                Text('$kindLabel  ·  $subLabel'.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 30,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    )),

                const Spacer(flex: 2),

                // The number.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$score',
                        style: AppTypography.display.copyWith(
                          color: _scoreColor,
                          fontSize: 360,
                          height: 0.9,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -12,
                        )),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 70),
                      child: Text(' / 10',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 54,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: AppColors.accentBorder, width: 2),
                  ),
                  child: Text(badge.toUpperCase(),
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 34,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w900,
                      )),
                ),

                const Spacer(flex: 1),

                if (verdict.isNotEmpty) ...[
                  Text('"$verdict"',
                      textAlign: TextAlign.center,
                      style: AppTypography.h1Italic.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 46,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      )),
                  const SizedBox(height: 20),
                  Text('— LUCIEN',
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 26,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w900,
                      )),
                ],

                const Spacer(flex: 2),

                // Breakdown.
                if (stats.isNotEmpty)
                  ...stats.take(5).map((s) => _StatRow(
                        label: s.label,
                        score: s.score,
                      )),

                const Spacer(flex: 2),

                Text('CERTIFIED ON $brand  ·  $_date',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 12),
                Text('$tagline  ·  mirrorly.app',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 22,
                      letterSpacing: 5,
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

class _StatRow extends StatelessWidget {
  final String label;
  final int score;
  const _StatRow({required this.label, required this.score});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 360,
            child: Text(label.toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 10).clamp(0.0, 1.0),
                minHeight: 14,
                backgroundColor: AppColors.surface3,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 56,
            child: Text('$score',
                textAlign: TextAlign.right,
                style: AppTypography.display.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                )),
          ),
        ],
      ),
    );
  }
}
