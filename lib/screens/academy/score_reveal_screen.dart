import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';

/// Everything the reveal needs, handed over via route extra. The scoring
/// Edge Function produces these numbers server-side; until it's live any
/// caller can push demo values to exercise the screen.
class ScoreRevealPayload {
  final int score; // headline, 0..9999
  final Map<String, int> rubric; // axis name -> 0..100
  final int eloDelta; // signed
  final int newRating;
  final String scenario;
  const ScoreRevealPayload({
    required this.score,
    required this.rubric,
    required this.eloDelta,
    required this.newRating,
    required this.scenario,
  });
}

/// THE moment. Full-screen takeover after every scored voice session:
/// the number counts up with haptic ticks, the five rubric bars stagger
/// in, the ELO chip lands, tier progress breathes. RUN IT BACK is the
/// replay engine — the gap to the next rank is on screen when the
/// button appears.
class ScoreRevealScreen extends StatefulWidget {
  final ScoreRevealPayload payload;
  const ScoreRevealScreen({super.key, required this.payload});

  @override
  State<ScoreRevealScreen> createState() => _ScoreRevealScreenState();
}

class _ScoreRevealScreenState extends State<ScoreRevealScreen> {
  int _lastTick = 0;

  ScoreRevealPayload get p => widget.payload;

  void _share() {
    HapticFeedback.selectionClick();
    // The rendered Academy card — 0–9999 number, tier stamp, rubric
    // bars and the gauntlet line. Every share is a challenge.
    // ignore: discarded_futures
    ShareService.shareRizzScore(
      context: context,
      scenario: p.scenario,
      score: p.score,
      rating: p.newRating,
      rubric: p.rubric,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(p.newRating);
    final next = nextTier(p.newRating);
    final up = p.eloDelta >= 0;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SESSION SCORED',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w800,
                  )).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: 2),
              Text(p.scenario,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  )).animate().fadeIn(duration: 250.ms, delay: 80.ms),

              // ── The number ──────────────────────────────────────────
              Expanded(
                flex: 5,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: p.score.toDouble()),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutQuart,
                    builder: (_, v, __) {
                      // Haptic tick roughly every ~8% of the climb.
                      final tick = (v / (p.score.clamp(1, 9999) / 12)).floor();
                      if (tick != _lastTick) {
                        _lastTick = tick;
                        HapticFeedback.selectionClick();
                      }
                      return Text(
                        v.round().toString(),
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 96,
                          height: 1,
                          letterSpacing: -3,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: AppColors.red.withValues(alpha: 0.45),
                                blurRadius: 60),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Rubric bars, staggered ──────────────────────────────
              for (final (i, entry) in p.rubric.entries.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _RubricBar(
                          label: entry.key, value: entry.value)
                      .animate()
                      .fadeIn(delay: (1250 + i * 120).ms, duration: 300.ms)
                      .slideX(begin: 0.06, end: 0, curve: Curves.easeOut),
                ),

              const SizedBox(height: 6),

              // ── ELO delta + tier ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (up ? kNeon : AppColors.red)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: (up ? kNeon : AppColors.red)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${up ? '+' : ''}${p.eloDelta} ELO',
                      style: GoogleFonts.inter(
                        color: up ? kNeon : AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(tier.name,
                      style: GoogleFonts.inter(
                        color: tier.color,
                        fontSize: 13,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w800,
                        shadows: tier.glow
                            ? [
                                Shadow(
                                    color:
                                        tier.color.withValues(alpha: 0.7),
                                    blurRadius: 18)
                              ]
                            : null,
                      )),
                ],
              ).animate().fadeIn(delay: 1900.ms, duration: 350.ms),

              const SizedBox(height: 10),

              // Tier progress — the gap to the next rank, always visible.
              if (next != null)
                Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: tierProgress(p.newRating),
                      minHeight: 5,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation(tier.color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${next.min - p.newRating} TO ${next.name}',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 10.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]).animate().fadeIn(delay: 2100.ms, duration: 350.ms),

              const SizedBox(height: 18),

              // ── CTAs ────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _share,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text('SHARE',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.pop('rematch');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text('RUN IT BACK',
                          style: GoogleFonts.inter(
                              fontSize: 13.5,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ]).animate().fadeIn(delay: 2300.ms, duration: 350.ms),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('NEXT',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    )),
              ).animate().fadeIn(delay: 2450.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _RubricBar extends StatelessWidget {
  final String label;
  final int value; // 0..100
  const _RubricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 92,
        child: Text(label.toUpperCase(),
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            )),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(
                  value >= 80 ? kNeon : AppColors.red),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 30,
        child: Text('$value',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            )),
      ),
    ]);
  }
}
