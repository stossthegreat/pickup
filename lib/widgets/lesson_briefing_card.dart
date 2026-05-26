import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/auralay_app_colors.dart';
import '../theme/auralay_app_typography.dart';
import 'safe_close_button.dart';

/// LESSON BRIEFING — the clean card shown at the start of every lesson.
///
/// Before any voice plays, before the camera starts, before the realtime
/// session opens — the apprentice sees this card. It tells him what
/// tonight is, what he is going to do, and what success looks like.
/// One CTA: BEGIN. He taps it, the session opens.
///
/// Used by:
///   - EyesSessionScreen   — eye-contact moves
///   - TeacherSessionScreen — voice / rizz / roleplay / practice
class LessonBriefingCard extends StatelessWidget {
  /// Small label above the title, e.g. "LESSON 01" or "ROLEPLAY".
  final String topLabel;

  /// Big title — the lesson / scene / mode name.
  final String title;

  /// Italic subtitle — the one-line tagline (oneLine on Lesson/EyeLesson).
  final String subtitle;

  /// Section label above the items list, e.g. "TONIGHT YOU'LL PERFORM"
  /// or "TONIGHT YOU'LL DELIVER" or "SETTING".
  final String sectionLabel;

  /// The items in the briefing list. Each item has a primary line
  /// (e.g. move name or target line) and an optional secondary line
  /// (the cue / hint). May be empty (e.g. for practice mode).
  final List<BriefingItem> items;

  /// One-sentence success criterion.
  final String goal;

  /// CTA fires when the apprentice is ready to begin.
  final VoidCallback onBegin;

  const LessonBriefingCard({
    super.key,
    required this.topLabel,
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    required this.items,
    required this.goal,
    required this.onBegin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 0.95,
                colors: [
                  AppColors.accent.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top chrome — close button only. The briefing is the first
        // thing he sees; no other chrome until he hits BEGIN.
        Positioned(
          top: 8, right: 14,
          child: const SafeCloseButton(),
        ),

        // Body — the briefing card.
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top label — "LESSON 01"
                Text(topLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 11,
                      letterSpacing: 3.6,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 14),

                // Title — big italic display
                Text(title,
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 38,
                      letterSpacing: -1.2,
                      height: 1.0,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 14),

                // Subtitle — italic
                Text('"$subtitle"',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.accent,
                      fontSize: 14.5,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    )),

                if (items.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  // Section label — "TONIGHT YOU'LL PERFORM"
                  Text(sectionLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 14),
                  // Items list
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.divider, width: 0.8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22, height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: AppColors.accentBorder, width: 0.6),
                              ),
                              child: Text('${i + 1}',
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w900,
                                  )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.primary,
                                      style: AppTypography.label.copyWith(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        letterSpacing: 1.8,
                                        height: 1.3,
                                        fontWeight: FontWeight.w900,
                                      )),
                                  if (item.secondary != null &&
                                      item.secondary!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.secondary!,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          height: 1.45,
                                          fontStyle: FontStyle.italic,
                                        )),
                                  ],
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

                // Goal — single sentence, framed.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accentBorder, width: 0.8),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GOAL',
                          style: AppTypography.label.copyWith(
                            color: AppColors.accent,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 6),
                      Text(goal,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            height: 1.45,
                            fontStyle: FontStyle.italic,
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // CTA — BEGIN.
                GestureDetector(
                  onTap: onBegin,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.accentGlow,
                          blurRadius: 24,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Text('BEGIN',
                        style: AppTypography.label.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 3.6,
                          fontWeight: FontWeight.w900,
                        )),
                  )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shimmer(
                      duration: 1800.ms,
                      color: AppColors.accentBright.withValues(alpha: 0.4),
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

/// One line in the briefing list. [primary] is the main line (move name
/// / target line / setting); [secondary] is the optional cue / hint /
/// extra context.
class BriefingItem {
  final String primary;
  final String? secondary;
  const BriefingItem({required this.primary, this.secondary});
}
