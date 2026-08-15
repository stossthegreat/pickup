import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../services/boost_service.dart';
import '../../services/economy.dart';
import '../../services/rewards.dart';
import '../../services/sfx_service.dart';
import '../../services/standing.dart';
import '../../services/streak_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/ascend_reveal.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/game_feel.dart';
import '../../widgets/academy/lucien_says.dart';
import '../../widgets/academy/trophy.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE PAYOUT — four bars moving off one action
/// ══════════════════════════════════════════════════════════════════════
///
/// This is the single most-copied screen in mobile and the reason is not
/// that it's pretty. It's that ONE action visibly advances FOUR separate
/// systems at the same time, in one frame, and the brain reads that as
/// "everything I do here counts."
///
/// THE GAP IT FILLS. This app HAD four systems — XP/level, the streak,
/// badges, and the identity rank — and no moment where they moved
/// together. A man finished a daily and saw a score. Somewhere behind
/// that, XP went up. Somewhere else, a badge counter incremented. His
/// streak was extended by a service he never saw. All real, all
/// invisible, all separately. Four quiet systems feel like none.
///
/// THE ORDER IS THE DESIGN:
///
///  1. THE NUMBER HE EARNED, big and alone. Before anything else moves,
///     he sees what the last five minutes were worth.
///
///  2. THE XP BAR FILLS — and if it crosses a level, it visibly empties
///     and refills. Watching a bar cross is the whole reason bars exist;
///     a bar that has already been redrawn at its new value is a
///     statistic.
///
///  3. THE STREAK, stamped. Loss aversion runs about twice as strong as
///     the equivalent gain, so this is the row he's protecting, and it
///     gets a flame and a day count rather than a tick.
///
///  4. THE BADGE bar advances from where it was to where it is. Never
///     appears at the new value.
///
///  5. THE RANK line, last and quiet: how many days to the next one.
///     Slow, unrushable, and the only row that isn't celebrating —
///     it's the row that says come back tomorrow.
///
/// Each row lands with its own tick and haptic. Four small hits in
/// sequence beat one big one, because the sequence is what makes it feel
/// like a payout being counted out rather than a total being displayed.
class PayoutScreen extends StatefulWidget {
  final Grant grant;
  final int streak;
  final int earnedDays;
  final ({Trophy trophy, int have, int had})? badge;

  const PayoutScreen({
    super.key,
    required this.grant,
    required this.streak,
    required this.earnedDays,
    required this.badge,
  });

  /// Show it only if something actually moved. Called at the end of
  /// every reward flow; a silent no-op when nothing was granted, so
  /// callers never have to check.
  ///
  /// CONSUMES the parked state. A payout can only ever be shown once,
  /// which is what stops a screen rebuild from replaying it.
  static Future<void> showIfEarned(BuildContext context) async {
    final grant = Rewards.lastGrant;
    Rewards.lastGrant = null;
    final bump = Achievements.lastBump;
    Achievements.lastBump = null;
    if (grant == null || grant.amount <= 0) return;

    final snap = await StreakService.progress();

    ({Trophy trophy, int have, int had})? badge;
    if (bump != null && bump.after > bump.before) {
      // The closest unfinished rung of the family he just moved — the
      // one his action was actually progress toward.
      final family = Achievements.family(bump.stat);
      final done = await Achievements.earned();
      for (final t in family) {
        if (!done.contains(t.id)) {
          badge = (trophy: t, have: bump.after, had: bump.before);
          break;
        }
      }
    }
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'payout',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => PayoutScreen(
        grant: grant,
        streak: snap.streak,
        earnedDays: snap.ascensionDay,
        badge: badge,
      ),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  /// THE ONE LINE EVERY REWARD FLOW ENDS ON.
  ///
  /// Payout first, ceremonies second, and the order matters: he watches
  /// the bars move, and THEN the level or the badge he just crossed
  /// detonates. Reversed, the ceremony spoils its own build-up — you'd
  /// be told you levelled and then shown the bar that was about to say
  /// so.
  ///
  /// Both halves are silent no-ops when nothing moved, so a caller never
  /// has to check anything.
  static Future<void> cashOut(BuildContext context) async {
    await showIfEarned(context);
    if (context.mounted) await AscendReveal.settle(context);
  }

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  /// 0 the number · 1 xp bar · 2 streak · 3 badge · 4 rank + button
  int _stage = 0;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));

    Feel.land();
    Sfx.scoreLand();
    // THE TRAP AT THE EXIT. Session-end is the biggest churn point any
    // app has, so the window opens at the exact moment he was about to
    // put the phone down — see boost_service.dart for why it fires every
    // time rather than randomly.
    // ignore: discarded_futures
    BoostService.start();
    for (var i = 1; i <= 4; i++) {
      at(500 + (i - 1) * 620, () {
        setState(() => _stage = i);
        if (i < 4) {
          Feel.tick();
          Sfx.axis();
        } else {
          Feel.banked();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  int get _levelBefore => Standing.levelFor(widget.grant.xpBefore);
  int get _levelAfter => Standing.levelFor(widget.grant.xpAfter);
  bool get _levelled => _levelAfter > _levelBefore;

  @override
  Widget build(BuildContext context) {
    final g = widget.grant;
    final b = widget.badge;

    return Material(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 1.0,
                colors: [
                  AppColors.accent.withValues(alpha: 0.16),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
            child: Column(children: [
              Text(g.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        letterSpacing: 3.4,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(duration: 300.ms),

              // EVERYTHING BETWEEN THE KICKER AND THE BUTTON SCROLLS.
              //
              // This screen grew: the number, the boost card, three
              // progress rows and a badge. On a small phone that stack
              // is taller than the viewport, and Spacers don't shrink
              // past zero — the old layout would have overflowed rather
              // than adapted. A scroll view costs nothing here because
              // on a normal handset it never scrolls, and on a small one
              // it degrades instead of breaking.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
              const SizedBox(height: 18),

              // ── 1 · WHAT IT WAS WORTH ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('+',
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      )),
                  CountUp(
                    value: g.amount,
                    duration: const Duration(milliseconds: 850),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 78,
                      height: 1,
                      letterSpacing: -3,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: AppColors.accent.withValues(alpha: 0.6),
                            blurRadius: 46)
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Economy.xpShort,
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              )
                  .animate()
                  .fadeIn(duration: 260.ms)
                  .scaleXY(begin: 1.5, end: 1, curve: Curves.easeOutBack),

              // WHY IT WAS THAT BIG. A doubled number he can't account
              // for teaches him nothing; a doubled number with the
              // reason printed on it teaches him to come back inside
              // the window.
              if (g.firstTime || g.boosted) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.signalAmber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.signalAmber.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                      g.firstTime ? 'FIRST ONE · DOUBLE' : 'BOOST · DOUBLE',
                      style: GoogleFonts.inter(
                        color: AppColors.signalAmber,
                        fontSize: 10.5,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w900,
                      )),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 280.ms)
                    .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),
              ],

              const SizedBox(height: 22),

              // ── THE EXIT TRAP ───────────────────────────────────────
              if (_stage >= 1) const _BoostCard(),

              // ── 2 · THE LEVEL BAR ───────────────────────────────────
              if (_stage >= 1) _levelRow(),

              // ── 3 · THE STREAK ──────────────────────────────────────
              if (_stage >= 2) ...[
                const SizedBox(height: 14),
                _Row(
                  icon: Icons.local_fire_department_rounded,
                  tone: AppColors.red,
                  label: 'STREAK',
                  value: 'DAY ${widget.streak}',
                  // Loss aversion is the strongest force in the app and
                  // this is the row it lives on, so it says what he is
                  // protecting rather than congratulating him.
                  caption: widget.streak >= 2
                      ? 'Come back tomorrow or it goes to zero.'
                      : 'Two days in a row is where it starts.',
                  progress: 1,
                ),
              ],

              // ── 4 · THE BADGE ───────────────────────────────────────
              if (_stage >= 3 && b != null) ...[
                const SizedBox(height: 14),
                _BadgeRow(trophy: b.trophy, had: b.had, have: b.have),
              ],

                  ]),
                ),
              ),

              // ── 5 · TOMORROW ────────────────────────────────────────
              // Pinned below the scroll, so the way out is always on
              // screen no matter how much landed above it.
              SizedBox(
                height: 156,
                child: _stage >= 4
                    ? Column(children: [
                        // LUCIEN. After the number, never over it — he's
                        // the full stop on the moment, not part of it.
                        LucienSays(
                          line: LucienLines.afterPayout(g.amount,
                              first: g.firstTime),
                          delay: 200.ms,
                        ),
                        const SizedBox(height: 12),
                        Text(
                            Standing.nextRankLine(widget.earnedDays) ??
                                'YOU HAVE FINISHED THE CLIMB',
                            style: GoogleFonts.inter(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GameButton(
                            label: 'KEEP GOING',
                            color: AppColors.accent,
                            height: 54,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ]).animate().fadeIn(duration: 280.ms)
                    : null,
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The bar that crosses. If he levelled, it fills to full, then empties
  /// and refills to the new position — the crossing is the event, and a
  /// bar redrawn at its new value throws it away.
  Widget _levelRow() {
    final from = Economy.levelProgress(widget.grant.xpBefore);
    final to = Economy.levelProgress(widget.grant.xpAfter);
    return _Row(
      icon: Icons.bolt_rounded,
      tone: AppColors.accent,
      label: 'LEVEL $_levelAfter',
      value: _levelled ? 'LEVELLED UP' : '${Economy.xpToNext(widget.grant.xpAfter)} TO GO',
      caption: null,
      progress: to,
      from: _levelled ? 0 : from,
      crossed: _levelled,
    );
  }
}

/// One line of the payout: icon, name, number, and a bar that moves.
class _Row extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String label;
  final String value;
  final String? caption;
  final double progress;
  final double from;
  final bool crossed;

  const _Row({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    required this.caption,
    required this.progress,
    this.from = 0,
    this.crossed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 17, color: tone),
          const SizedBox(width: 9),
          Text(label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(height: 7, color: Colors.white.withValues(alpha: 0.07)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: from, end: progress.clamp(0.0, 1.0)),
              duration: Duration(milliseconds: crossed ? 900 : 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: tone,
                    boxShadow: [
                      BoxShadow(
                          color: tone.withValues(alpha: 0.6), blurRadius: 10)
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(caption!,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ]),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic);
  }
}

/// The badge row carries its medal, because the whole point of a badge
/// is that it's an object rather than a number.
class _BadgeRow extends StatelessWidget {
  final Trophy trophy;
  final int had;
  final int have;
  const _BadgeRow({
    required this.trophy,
    required this.had,
    required this.have,
  });

  @override
  Widget build(BuildContext context) {
    final tone = trophy.tier.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        TrophyMedal(
          trophy: trophy,
          size: 38,
          earned: have >= trophy.need,
          progress: (have / trophy.need).clamp(0.0, 1.0),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(trophy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      )),
                ),
                Text('$have/${trophy.need}',
                    style: GoogleFonts.inter(
                      color: tone,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(children: [
                  Container(
                      height: 6, color: Colors.white.withValues(alpha: 0.07)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: (had / trophy.need).clamp(0.0, 1.0),
                      end: (have / trophy.need).clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(height: 6, color: tone),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic);
  }
}

/// DOUBLE XP, COUNTING DOWN, at the moment he was about to leave.
///
/// Fifteen minutes on a live clock. The countdown is the whole design:
/// a static "2× active" badge is information, a number visibly falling
/// is a reason to open one more thing right now. See boost_service.dart.
class _BoostCard extends StatefulWidget {
  const _BoostCard();

  @override
  State<_BoostCard> createState() => _BoostCardState();
}

class _BoostCardState extends State<_BoostCard> {
  int _left = BoostService.minutes * 60;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      final n = await BoostService.remaining();
      if (mounted) setState(() => _left = n);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.signalAmber.withValues(alpha: 0.18),
              AppColors.surface1,
            ],
          ),
          border: Border.all(
              color: AppColors.signalAmber.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
                color: AppColors.signalAmber.withValues(alpha: 0.16),
                blurRadius: 22)
          ],
        ),
        child: Row(children: [
          const Icon(Icons.bolt_rounded,
              size: 20, color: AppColors.signalAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DOUBLE ${Economy.xpShort} IS LIVE',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    )),
                Text('Everything you do now pays twice.',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Text(BoostService.clock(_left),
                  style: GoogleFonts.inter(
                    color: AppColors.signalAmber,
                    fontSize: 19,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w900,
                  ))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.65, end: 1, duration: 900.ms),
        ]),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack);
  }
}
