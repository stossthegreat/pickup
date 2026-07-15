import 'package:flutter/material.dart';

import '../theme/auralay_app_colors.dart';
import '../theme/auralay_app_typography.dart';
import 'safe_close_button.dart';

/// LESSON RESULTS — the honest stats card shown after every lesson.
///
/// No fake scores. No vanity numbers. The card shows exactly what
/// happened:
///   - How many moves the apprentice passed.
///   - Real session stats (blink count, average contact, time).
///   - A per-move breakdown with the actual pass criterion AND the
///     value he hit. If he failed, he sees why.
///
/// Used by EyesSessionScreen at the end of a lesson. Voice / rizz
/// realtime sessions don't have hard metrics, so they use a simpler
/// card.
class LessonResultsCard extends StatelessWidget {
  /// Big title — "LESSON COMPLETE" or "LESSON FAILED".
  final String title;

  /// Lesson name shown small above the title.
  final String lessonName;

  /// Pass count over total move count, e.g. (1, 2).
  final int passCount;
  final int totalMoves;

  /// Session-level stats — each entry is a (label, value) tuple shown
  /// as a chip row.
  final List<ResultStat> stats;

  /// Per-move breakdown. Each row shows the move name, pass/fail flag,
  /// and a one-line reason / criterion comparison.
  final List<MoveResultRow> moves;

  /// DONE CTA.
  final VoidCallback onDone;

  const LessonResultsCard({
    super.key,
    required this.title,
    required this.lessonName,
    required this.passCount,
    required this.totalMoves,
    required this.stats,
    required this.moves,
    required this.onDone,
  });

  bool get _isFullPass => passCount == totalMoves;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        _isFullPass ? AppColors.signalGreen : AppColors.accent;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 0.95,
                colors: [
                  accentColor.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 8, right: 14,
          child: SafeCloseButton(onTearDown: () async => onDone()),
        ),

        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lessonName,
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10.5,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 10),
                Text(title,
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      color: accentColor,
                      fontSize: 32,
                      letterSpacing: -1.0,
                      height: 1.0,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 22),

                // Headline score — "2 / 2 PASSED".
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 0.8),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$passCount',
                            style: AppTypography.display.copyWith(
                              color: accentColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.8,
                            ),
                          ),
                          TextSpan(
                            text: '  /  $totalMoves PASSED',
                            style: AppTypography.label.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('YOUR STATS',
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: AppColors.divider, width: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.label,
                                style: AppTypography.label.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 9.5,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(width: 6),
                            Text(s.value,
                                style: AppTypography.label.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                if (moves.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Text('MOVE BREAKDOWN',
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 12),
                  ...moves.asMap().entries.map((e) {
                    final row = e.value;
                    final rowColor =
                        row.passed ? AppColors.signalGreen : AppColors.accent;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: row.passed
                                  ? AppColors.signalGreenBorder
                                  : AppColors.signalRedBorder,
                              width: 0.8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              row.passed
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: rowColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(row.name,
                                            style: AppTypography.label.copyWith(
                                              color: Colors.white,
                                              fontSize: 12,
                                              letterSpacing: 1.8,
                                              fontWeight: FontWeight.w900,
                                            )),
                                      ),
                                      Text(row.passed ? 'PASSED' : 'FAILED',
                                          style: AppTypography.label.copyWith(
                                            color: rowColor,
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w900,
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(row.detail,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        height: 1.4,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: onDone,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('DONE',
                        style: AppTypography.label.copyWith(
                          color: Colors.white,
                          fontSize: 12.5,
                          letterSpacing: 3.6,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ResultStat {
  final String label;
  final String value;
  const ResultStat(this.label, this.value);
}

class MoveResultRow {
  final String name;
  final bool passed;
  /// One-line breakdown — actual values vs. the pass criterion, so the
  /// apprentice can see exactly why he passed or failed. Example:
  /// "contact 0.62 (≥0.55) · 1 blink (<5)"
  final String detail;
  const MoveResultRow({
    required this.name,
    required this.passed,
    required this.detail,
  });
}
