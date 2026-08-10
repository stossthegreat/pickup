import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/league_crest.dart';

/// Everything the reveal needs, handed over via route extra.
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

/// THE REVEAL — the moment after every scored session. Staged like a
/// results screen, not a report: the number climbs with haptic ticks,
/// the five axes pour in one after another, the ELO chip lands, the
/// tier ring fills, and if it went well the screen throws confetti.
class ScoreRevealScreen extends StatefulWidget {
  final ScoreRevealPayload payload;
  const ScoreRevealScreen({super.key, required this.payload});

  @override
  State<ScoreRevealScreen> createState() => _ScoreRevealScreenState();
}

class _ScoreRevealScreenState extends State<ScoreRevealScreen> {
  int _lastTick = 0;
  bool _celebrated = false;

  ScoreRevealPayload get p => widget.payload;

  /// A gain in rating is the honest "that went well" signal.
  bool get _good => p.eloDelta >= 0;

  @override
  void initState() {
    super.initState();
    // Fire the celebration once the number has finished climbing.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _good) {
        HapticFeedback.heavyImpact();
        setState(() => _celebrated = true);
      }
    });
  }

  void _share() {
    HapticFeedback.selectionClick();
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
    final accent = _good ? kNeon : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(children: [
        // Ambient glow behind the number.
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (_celebrated) Positioned.fill(child: Burst(color: kNeon)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('SESSION SCORED',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 11,
                      letterSpacing: 3.4,
                      fontWeight: FontWeight.w900,
                    )).animate().fadeIn(duration: 260.ms),
                const SizedBox(height: 3),
                Text(p.scenario.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    )).animate().fadeIn(delay: 90.ms, duration: 260.ms),

                // ── The number ────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p.score.toDouble()),
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeOutQuart,
                      builder: (_, v, __) {
                        final tick =
                            (v / (p.score.clamp(1, 9999) / 14)).floor();
                        if (tick != _lastTick) {
                          _lastTick = tick;
                          HapticFeedback.selectionClick();
                        }
                        return Text(
                          v.round().toString(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 104,
                            height: 1,
                            letterSpacing: -4,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                  color: accent.withValues(alpha: 0.55),
                                  blurRadius: 70),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Rubric bars — poured in one by one ────────────
                for (final (i, entry) in p.rubric.entries.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RubricBar(label: entry.key, value: entry.value)
                        .animate()
                        .fadeIn(delay: (1250 + i * 130).ms, duration: 300.ms)
                        .slideX(begin: 0.08, end: 0, curve: Curves.easeOut),
                  ),

                const SizedBox(height: 8),

                // ── Rating block: crest + delta + ring ────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: tier.color.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    LeagueCrest(division: _divisionForTier(tier), size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tier.name,
                              style: GoogleFonts.inter(
                                color: tier.color,
                                fontSize: 15,
                                letterSpacing: 2.2,
                                fontWeight: FontWeight.w900,
                                shadows: tier.glow
                                    ? [
                                        Shadow(
                                            color: tier.color
                                                .withValues(alpha: 0.6),
                                            blurRadius: 16)
                                      ]
                                    : null,
                              )),
                          const SizedBox(height: 2),
                          Text(
                              next == null
                                  ? 'TOP OF THE LADDER'
                                  : '${next.min - p.newRating} TO ${next.name}',
                              style: GoogleFonts.inter(
                                color: AppColors.textTertiary,
                                fontSize: 10.5,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        '${_good ? '+' : ''}${p.eloDelta}',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 1950.ms)
                        .scale(
                            begin: const Offset(0.6, 0.6),
                            end: const Offset(1, 1),
                            curve: Curves.easeOutBack),
                    const SizedBox(width: 10),
                    ProgressRing(
                      value: tierProgress(p.newRating),
                      size: 44,
                      stroke: 4.5,
                      color: tier.color,
                      center: Text('${p.newRating}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ]),
                ).animate().fadeIn(delay: 1850.ms, duration: 340.ms),

                const SizedBox(height: 16),

                // ── CTAs ─────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: GameButton(
                      label: 'SHARE',
                      color: AppColors.surface2,
                      icon: Icons.ios_share_rounded,
                      onTap: _share,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GameButton(
                      label: 'RUN IT BACK',
                      pulse: true,
                      onTap: () => context.pop('rematch'),
                    ),
                  ),
                ]).animate().fadeIn(delay: 2150.ms, duration: 320.ms),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('NEXT',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      )),
                ).animate().fadeIn(delay: 2300.ms),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// Map the five ELO tiers onto the five crest designs.
  int _divisionForTier(RizzTier t) {
    final i = kTiers.indexOf(t);
    return (i < 0 ? 0 : i) + 1;
  }
}

class _RubricBar extends StatelessWidget {
  final String label;
  final int value; // 0..100
  const _RubricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final strong = value >= 80;
    final color = strong
        ? kNeon
        : value >= 55
            ? AppColors.red
            : AppColors.textTertiary;
    return Row(children: [
      SizedBox(
        width: 92,
        child: Text(label.toUpperCase(),
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            )),
      ),
      Expanded(
        child: Stack(alignment: Alignment.centerLeft, children: [
          Container(
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.65),
                    color,
                  ]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5), blurRadius: 10)
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 30,
        child: Text('$value',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: strong ? kNeon : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            )),
      ),
    ]);
  }
}
