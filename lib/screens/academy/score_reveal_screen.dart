import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart';
import '../../services/division.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/grade_stamp.dart';
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

class _ScoreRevealScreenState extends State<ScoreRevealScreen>
    with SingleTickerProviderStateMixin {
  /// A notifier, not a field flipped in setState. The one setState this
  /// screen had — flipping this at grade impact — rebuilt the whole
  /// tree, and every chained `.animate()` on it reconstructs its effects
  /// on rebuild and replays from the top. So the score counted itself up
  /// twice: once on entry, once when its own grade landed. The notifier
  /// rebuilds the confetti layer and nothing else.
  final ValueNotifier<bool> _celebrated = ValueNotifier(false);
  final _shakeKey = GlobalKey<ImpactShakeState>();

  /// White-out on the frame the grade lands. One frame of pure light is
  /// what sells an impact — every fighting game does it.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  ScoreRevealPayload get p => widget.payload;

  RizzGrade get _grade => RizzGrade.of(p.score);

  /// A gain in rating is the honest "that went well" signal.
  bool get _good => p.eloDelta >= 0;

  @override
  void dispose() {
    _flash.dispose();
    _celebrated.dispose();
    super.dispose();
  }

  /// The grade hit the screen: shake, flash, confetti if it earned it.
  void _onImpact() {
    if (!mounted) return;
    _shakeKey.currentState?.shake();
    _flash.forward(from: 0);
    HapticFeedback.heavyImpact();
    // A win throws confetti; anything below a B just takes the hit.
    if (_good || p.score >= 680) _celebrated.value = true;
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
    // The daily moves the VOICE rating. It is not his identity rank
    // (that's earned days) and it is not his battle division — it is
    // how well he speaks, and the only honest thing to print beside
    // it is the number. See standing.dart.
    final tier = Rank.of(p.newRating);
    final grade = _grade;
    // The GRADE drives the palette now, not the ELO sign — an S-rank
    // that happens to lose a point of rating should still read gold.
    final accent = grade.color;

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
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _celebrated,
              builder: (_, on, __) => on
                  ? Burst(color: grade.color)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        SafeArea(
          child: ImpactShake(
            key: _shakeKey,
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

                // ── The number climbs, then the GRADE lands on it ──
                Expanded(
                  flex: 5,
                  child: Stack(alignment: Alignment.center, children: [
                    // STATIC. Score numbers are never animated anywhere
                    // in this app any more — every counting number
                    // eventually found a rebuild to replay off, and this
                    // one carried a haptic per tick, so a replay BUZZED
                    // while it spammed. Rendered at its final size and
                    // resting place; the grade stamp still lands below.
                    Transform.translate(
                      offset: const Offset(0, -74),
                      child: Text(
                        p.score.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 46,
                          height: 1,
                          letterSpacing: -1.8,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: accent.withValues(alpha: 0.55),
                                blurRadius: 34),
                          ],
                        ),
                      ),
                    ),

                    // THE GRADE.
                    Padding(
                      padding: const EdgeInsets.only(top: 46),
                      child: GradeStamp(
                        grade: grade,
                        delay: const Duration(milliseconds: 1900),
                        onImpact: _onImpact,
                      ),
                    ),

                    // The verdict, under the letter.
                    Positioned(
                      bottom: 4,
                      child: Text(grade.verdict,
                              style: GoogleFonts.inter(
                                color: grade.color,
                                fontSize: 13,
                                letterSpacing: 4.5,
                                fontWeight: FontWeight.w900,
                              ))
                          .animate()
                          .fadeIn(delay: 2380.ms, duration: 260.ms)
                          .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),
                    ),
                  ]),
                ),

                // ── Rubric bars — poured in one by one ────────────
                for (final (i, entry) in p.rubric.entries.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RubricBar(label: entry.key, value: entry.value)
                        .animate()
                        .fadeIn(delay: (2520 + i * 120).ms, duration: 300.ms)
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
                        color: tier.div.color.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    LeagueCrest(division: _crestFor(tier), size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tier.label,
                              style: GoogleFonts.inter(
                                color: tier.div.color,
                                fontSize: 15,
                                letterSpacing: 2.2,
                                fontWeight: FontWeight.w900,
                                shadows: tier.div.glows
                                    ? [
                                        Shadow(
                                            color: tier.div.color
                                                .withValues(alpha: 0.6),
                                            blurRadius: 16)
                                      ]
                                    : null,
                              )),
                          const SizedBox(height: 2),
                          Text(tier.toNext ?? 'TOP OF THE LADDER',
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
                        .fadeIn(delay: 3220.ms)
                        .scale(
                            begin: const Offset(0.6, 0.6),
                            end: const Offset(1, 1),
                            curve: Curves.easeOutBack),
                    const SizedBox(width: 10),
                    ProgressRing(
                      value: tier.progress,
                      size: 44,
                      stroke: 4.5,
                      color: tier.div.color,
                      center: Text('${p.newRating}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ]),
                ).animate().fadeIn(delay: 3120.ms, duration: 340.ms),

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
                ]).animate().fadeIn(delay: 3360.ms, duration: 320.ms),
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
                ).animate().fadeIn(delay: 3480.ms),
              ],
            ),
            ),
          ),
        ),

        // ── IMPACT FLASH — sits above everything, ignores taps ──────
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, __) {
                if (_flash.value == 0) return const SizedBox.shrink();
                // Instant white-out, fast fall-off.
                final a = (1 - Curves.easeOutQuart.transform(_flash.value))
                    .clamp(0.0, 1.0);
                return ColoredBox(
                    color: grade.color.withValues(alpha: a * 0.5));
              },
            ),
          ),
        ),
      ]),
    );
  }

  /// Map a division onto one of the five crest designs. Seven divisions,
  /// five crests — the top three share the best one, which is correct:
  /// the crest is a picture of "how high", not a unique ID.
  int _crestFor(Rank r) {
    final i = r.div.index;
    return (i > 4 ? 4 : i) + 1;
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
