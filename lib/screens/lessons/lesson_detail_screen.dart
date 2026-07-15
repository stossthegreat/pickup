import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/technique.dart';
import '../../theme/auralay_app_colors.dart';
import '../../theme/auralay_app_typography.dart';

/// Reads the user through one technique in full. Tagline → description →
/// scienceNote → drill instruction → CTA to train it.
///
/// Visual: pure black, sexy red accents only, italic Playfair for the
/// tagline + science quote. Locked techniques show a paywall-aware lock
/// state instead of the train CTA.
class LessonDetailScreen extends StatelessWidget {
  final String techniqueId;
  final int currentDay;

  const LessonDetailScreen({
    super.key,
    required this.techniqueId,
    required this.currentDay,
  });

  Technique? get _technique {
    for (final t in Technique.all) {
      if (t.id == techniqueId) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _technique;
    if (t == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Lesson not found',
            style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final unlocked = t.isUnlocked(currentDay);
    final mastered = t.isMastered(currentDay);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
              children: [
                // ── Top bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (mastered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.signalGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.signalGreen.withValues(alpha: 0.55),
                            width: 0.7),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                              color: AppColors.signalGreen, size: 12),
                            SizedBox(width: 4),
                            Text('MASTERED',
                              style: TextStyle(
                                color: AppColors.signalGreen,
                                fontSize: 9, letterSpacing: 1.6,
                                fontWeight: FontWeight.w900)),
                          ],
                        ),
                      )
                    else if (!unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.textTertiary, width: 0.7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                              color: AppColors.textTertiary, size: 12),
                            const SizedBox(width: 4),
                            Text('UNLOCKS DAY ${t.day}',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 9, letterSpacing: 1.6,
                                fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Day chip
                Text('LESSON · DAY ${t.day}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accent,
                    fontSize: 10, letterSpacing: 3.0,
                    fontWeight: FontWeight.w900,
                  )).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 12),

                // ── Name
                Text(t.name,
                  style: AppTypography.h1.copyWith(
                    fontSize: 38, height: 1.05, letterSpacing: -1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  )).animate()
                    .fadeIn(delay: 80.ms, duration: 460.ms)
                    .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 14),

                // ── Tagline (italic Playfair pull-quote)
                Text(t.tagline,
                  style: AppTypography.h1Italic.copyWith(
                    fontSize: 19, height: 1.4, letterSpacing: -0.2,
                    color: AppColors.accent,
                  )).animate()
                    .fadeIn(delay: 200.ms, duration: 420.ms),

                const SizedBox(height: 28),

                // ── Description
                _SectionLabel('THE TECHNIQUE'),
                const SizedBox(height: 10),
                Text(t.description,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.65, fontSize: 15.5, fontWeight: FontWeight.w400,
                  )).animate().fadeIn(delay: 280.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // ── Science (boxed)
                _SectionLabel('THE SCIENCE'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      width: 0.8),
                  ),
                  child: Text(t.scienceNote,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.65, fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                    )),
                ).animate().fadeIn(delay: 360.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // ── Drill
                _SectionLabel('THE DRILL'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3, height: 38,
                        margin: const EdgeInsets.only(top: 2, right: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(t.drillInstruction,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.55, fontSize: 15,
                            fontWeight: FontWeight.w500,
                          )),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 440.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // ── Coaching phrases preview (the in-session script)
                _SectionLabel('IN-SESSION SCRIPT'),
                const SizedBox(height: 10),
                ...t.coachingPhrases.take(5).toList().asMap().entries.map((e) {
                  final int i = e.key;
                  final phrase = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}',
                            style: AppTypography.label.copyWith(
                              color: AppColors.accent.withValues(alpha: 0.7),
                              fontSize: 11, fontWeight: FontWeight.w900,
                            )),
                        ),
                        Expanded(
                          child: Text(phrase,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14, height: 1.4,
                              fontStyle: FontStyle.italic,
                            )),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(
                    delay: Duration(milliseconds: 520 + i * 60),
                    duration: 320.ms);
                }),

                const SizedBox(height: 12),

                // Completion line as a footer pull-quote
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 22, 0, 0),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(
                      color: AppColors.divider, width: 0.6)),
                  ),
                  child: Text('"${t.completionLine}"',
                    textAlign: TextAlign.center,
                    style: AppTypography.h1Italic.copyWith(
                      fontSize: 16, height: 1.45, letterSpacing: -0.1,
                      color: AppColors.textSecondary,
                    )),
                ).animate().fadeIn(delay: 900.ms, duration: 500.ms),
              ],
            ),

            // ── Sticky CTA
            Positioned(
              left: 24, right: 24, bottom: 16,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: unlocked ? AppColors.accent
                                              : AppColors.surface2,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: unlocked
                      ? () {
                          HapticFeedback.mediumImpact();
                          context.go('/train');
                        }
                      : null,
                  child: Text(
                    unlocked
                        ? (mastered ? 'TRAIN AGAIN' : 'TRAIN THIS NOW')
                        : 'KEEP TRAINING TO UNLOCK',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14, letterSpacing: 2.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
      style: AppTypography.label.copyWith(
        color: AppColors.textTertiary,
        fontSize: 10, letterSpacing: 2.4,
        fontWeight: FontWeight.w800,
      ));
  }
}
