import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../services/milestone_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';
import 'day_won.dart';
import 'grade_stamp.dart';
import 'trophy.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE ASCEND — one ceremony, three ladders
/// ══════════════════════════════════════════════════════════════════════
///
/// Everything the app celebrates on a schedule comes through here, so
/// levelling up, ranking up and the squad gaining a level all FEEL like
/// the same product congratulating you. Bespoke celebrations drift
/// within a month and the app stops having a voice.
///
/// The battle verdict is the one deliberate exception — a duel result
/// needs both men's scores on screen and can't be reduced to a word and
/// a colour — but it plays the same beats in the same order.
///
/// THE SHAPE, and why it's this shape:
///
///  1. IT TAKES THE SCREEN. Not a toast, not a banner. A reward you can
///     scroll past is a reward that didn't happen, and the whole reason
///     the man said "there was no reveal" is that every one of these was
///     previously a number quietly redrawing itself in a pill.
///
///  2. IT GOES DARK FIRST. Half a second of nothing. You cannot land a
///     hit without a wind-up, and the silence is what makes the light
///     that follows mean something.
///
///  3. THE LIGHT ARRIVES BEFORE THE WORD. Rays sweep out from behind
///     where the badge is about to be, so the eye is already at the
///     right spot when the thing he earned slams into it.
///
///  4. IT NAMES THE WORK, NOT THE NUMBER. "TEN DAYS OF WORK" under
///     CONTENDER. "YOU ALL DID THAT" under a squad level. A number
///     without its cost attached is a score; a number with its cost
///     attached is an achievement, and only one of those is worth
///     anything to the person holding it.
///
///  5. RANK GETS THE LONG VERSION. Six ranks in sixty days, so it can
///     afford to hold the screen. A level-up lands every day or two and
///     is deliberately shorter — ceremony that outstays its welcome is
///     the fastest way to make people resent the reward.
class AscendReveal extends StatefulWidget {
  final Milestone milestone;

  /// The ladder's colour. Passed in rather than derived so a caller can
  /// hand it a specific metal when it has one.
  final Color accent;

  /// Optional line of context under the sub — the rank tagline, or what
  /// this rung unlocks.
  final String? footnote;

  const AscendReveal({
    super.key,
    required this.milestone,
    required this.accent,
    this.footnote,
  });

  static Future<void> show(
    BuildContext context,
    Milestone milestone, {
    required Color accent,
    String? footnote,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'ascend',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => AscendReveal(
        milestone: milestone,
        accent: accent,
        footnote: footnote,
      ),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  /// Drain the whole queue, one after the other. A tap that finishes the
  /// fifth mission, banks the chain AND ranks him up should play all
  /// three — the alternative is the app picking one and throwing the
  /// others away, which is exactly what it used to do.
  static Future<void> drain(
    BuildContext context, {
    required Color Function(Milestone) accentOf,
    String? Function(Milestone)? footnoteOf,
  }) async {
    while (MilestoneService.hasPending) {
      final m = MilestoneService.take();
      if (m == null) break;
      if (!context.mounted) return;
      // THE DAY GETS ITS OWN SCREEN. Every other milestone is a word and
      // a colour; a streak is a fire that has to be visibly bigger than
      // it was yesterday, which no shared template can do.
      if (m.kind == MilestoneKind.day) {
        await DayWon.show(context, m.value);
        continue;
      }
      await show(
        context,
        m,
        accent: accentOf(m),
        footnote: footnoteOf?.call(m),
      );
    }
  }

  /// The one line every screen calls after it has banked a reward.
  ///
  /// Rewards and Achievements queue silently — they have no context and
  /// no business owning one. This is where the queue gets played, and
  /// it lives on the widget so no screen has to remember two calls.
  static Future<void> settle(BuildContext context) =>
      drain(context, accentOf: ascendTint);

  @override
  State<AscendReveal> createState() => _AscendRevealState();
}

class _AscendRevealState extends State<AscendReveal>
    with TickerProviderStateMixin {
  /// 0 dark · 1 light · 2 the word · 3 the button
  int _stage = 0;
  bool _burst = false;
  final _shakeKey = GlobalKey<ImpactShakeState>();
  final _timers = <Timer>[];

  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  bool get _major => widget.milestone.isMajor;

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));

    // The wind-up. Nothing on screen, one soft tick, so the light that
    // follows has something to be louder than.
    Sfx.hold();
    at(120, Feel.tick);
    at(520, () {
      setState(() => _stage = 1);
      Feel.reel();
      Sfx.axis();
    });
    at(_major ? 1250 : 980, () {
      setState(() {
        _stage = 2;
        _burst = true;
      });
      _shakeKey.currentState?.shake();
      _flash.forward(from: 0);
      HapticFeedback.heavyImpact();
      Sfx.gradeSlam();
      // A rank is worth the full celebration sound and a second haptic
      // a beat later — two events, so the phone tells him twice.
      if (_major) {
        _timers.add(Timer(const Duration(milliseconds: 260), () {
          if (!mounted) return;
          Feel.best();
          Sfx.personalBest();
        }));
      } else {
        Feel.win();
        Sfx.win();
      }
    });
    at(_major ? 3100 : 2200, () => setState(() => _stage = 3));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _rays.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final c = widget.accent;

    return Material(
      color: Colors.black,
      child: Stack(children: [
        // The field, coming up from nothing.
        AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.18),
              radius: 1.1,
              colors: [
                c.withValues(alpha: _stage >= 2 ? 0.26 : (_stage >= 1 ? 0.1 : 0)),
                Colors.black,
              ],
            ),
          ),
        ),

        // The rays. They start turning before the word arrives, which is
        // what puts the eye in the right place.
        if (_stage >= 1)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _rays,
                builder: (_, __) => CustomPaint(
                  painter: _RayPainter(t: _rays.value, color: c),
                  size: Size.infinite,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms),
          ),

        if (_burst) Positioned.fill(child: Burst(color: c, pieces: _major ? 54 : 34)),

        SafeArea(
          child: ImpactShake(
            key: _shakeKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(children: [
                const Spacer(),

                if (_stage >= 2) ...[
                  // THE MEDAL, when there is one. A badge that arrives
                  // as text is a notification; a badge that arrives as a
                  // struck piece of metal is a thing he screenshots.
                  if (m.trophy != null) ...[
                    TrophyMedal(trophy: m.trophy!, size: 116)
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .scaleXY(
                            begin: 0.3, end: 1, curve: Curves.easeOutBack),
                    const SizedBox(height: 20),
                  ],
                  Text(_kicker(m.kind),
                          style: GoogleFonts.inter(
                            color: c.withValues(alpha: 0.9),
                            fontSize: 10.5,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w900,
                          ))
                      .animate()
                      .fadeIn(duration: 260.ms),
                  const SizedBox(height: 14),

                  // THE WORD.
                  Text(m.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: m.title.length > 12 ? 34 : 46,
                            height: 1.02,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                  color: c.withValues(alpha: 0.75),
                                  blurRadius: 48)
                            ],
                          ))
                      .animate()
                      .fadeIn(duration: 180.ms)
                      .scaleXY(
                          begin: 2.2, end: 1, curve: Curves.easeOutBack),

                  const SizedBox(height: 12),

                  // THE COST. The half that turns a number into a thing
                  // he did.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.withValues(alpha: 0.5)),
                    ),
                    child: Text(m.sub,
                        style: GoogleFonts.inter(
                          color: c,
                          fontSize: 11,
                          letterSpacing: 2.6,
                          fontWeight: FontWeight.w900,
                        )),
                  )
                      .animate()
                      .fadeIn(delay: 460.ms, duration: 300.ms)
                      .slideY(begin: 0.7, end: 0, curve: Curves.easeOutBack),

                  if (widget.footnote != null) ...[
                    const SizedBox(height: 18),
                    Text(widget.footnote!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ))
                        .animate()
                        .fadeIn(delay: 760.ms, duration: 340.ms),
                  ],
                ],

                const Spacer(),

                SizedBox(
                  height: 66,
                  child: _stage >= 3
                      ? SizedBox(
                          width: double.infinity,
                          child: GameButton(
                            label: _major ? 'I\'M HIM' : 'KEEP GOING',
                            color: c,
                            textColor: c.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ).animate().fadeIn(duration: 300.ms)
                      : null,
                ),
              ]),
            ),
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, __) {
                if (_flash.value == 0) return const SizedBox.shrink();
                final a = (1 - Curves.easeOutQuart.transform(_flash.value))
                    .clamp(0.0, 1.0);
                return ColoredBox(color: c.withValues(alpha: a * 0.5));
              },
            ),
          ),
        ),
      ]),
    );
  }

  /// Each ladder announces itself, so four different things arriving in
  /// the same frame are never mistaken for each other.
  static String _kicker(MilestoneKind k) => switch (k) {
        MilestoneKind.level => 'LEVEL UP',
        MilestoneKind.rank => 'YOU RANKED UP',
        MilestoneKind.squad => 'THE SQUAD LEVELLED',
        MilestoneKind.badge => 'BADGE UNLOCKED',
        MilestoneKind.day => 'DAY WON',
      };
}

/// THE COLOUR OF EACH LADDER. One place, so a level-up is the same
/// indigo everywhere it can happen and a rank is always gold.
///
/// Gold is reserved for RANK and nothing else. It's the rarest thing in
/// the app — six of them across sixty days — and a colour that shows up
/// for a routine level-up stops meaning "rare" within a week.
/// Takes the whole milestone, not just the kind, because a trophy
/// arrives in ITS OWN metal — bronze, silver or gold — so the colour is
/// the rarity before a word has been read.
Color ascendTint(Milestone m) =>
    m.trophy?.tier.color ??
    switch (m.kind) {
      MilestoneKind.level => AppColors.accent,
      MilestoneKind.rank => const Color(0xFFFFC53D),
      MilestoneKind.squad => const Color(0xFF2EE87A),
      MilestoneKind.badge => const Color(0xFFB9C2CC),
      // Never used — the day is intercepted in drain() and gets its own
      // screen — but the switch has to be exhaustive.
      MilestoneKind.day => AppColors.red,
    };

/// Light coming from behind the word. Painted, slow, and deliberately
/// low-contrast — rays you can SEE are a graphic, rays you can only feel
/// are lighting.
class _RayPainter extends CustomPainter {
  final double t; // 0..1, one full turn
  final Color color;
  const _RayPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = size.longestSide;
    const n = 14;
    final a0 = t * math.pi * 2;
    for (var i = 0; i < n; i++) {
      final a = a0 + (math.pi * 2 / n) * i;
      // Alternating widths so it reads as light rather than a pie chart.
      final w = i.isEven ? 0.10 : 0.05;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        w,
        true,
        Paint()..color = color.withValues(alpha: i.isEven ? 0.075 : 0.045),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) => old.t != t;
}
