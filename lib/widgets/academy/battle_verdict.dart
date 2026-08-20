import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../services/division.dart';
import '../../services/economy.dart';
import '../../services/roster.dart';
import '../../services/sfx_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../share/duel_card.dart';
import 'game_button.dart';
import 'game_feel.dart';
// ImpactShake lives here, not in game_feel.dart.
import 'grade_stamp.dart';
import 'lucien_says.dart';
import 'rank_emblem.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE VERDICT — how a duel is allowed to end
/// ══════════════════════════════════════════════════════════════════════
///
/// A battle used to end as a row on a list: two numbers and the word
/// VICTORY in green. That is a receipt, not an ending, and it is the
/// reason nobody ran a second one.
///
/// WHAT THIS DOES INSTEAD, and why each beat is there:
///
///  · HIS NUMBER FIRST, ALONE. He knows what he scored and still doesn't
///    know if it was enough. That gap is the entire product — it is the
///    same gap as the reels still spinning, and it is where the feeling
///    lives.
///
///  · THE RIVAL'S NUMBER SLAMS. Not fades. The peak-end rule says a
///    memory is built almost entirely from its most intense moment and
///    its last one, so the intense moment is engineered: flash, shake,
///    heavy haptic, sound.
///
///  · DEFEAT GETS THE SAME PRODUCTION AS VICTORY, in a darker key. An
///    app that celebrates loudly and loses quietly teaches men to fear
///    the button. A loss that lands properly — and immediately names
///    what he'd take back — is the one that gets run again.
///
///  · THE RR MOVES ON SCREEN. The number climbs from the old rating to
///    the new one rather than appearing at the new one. Watching it
///    move is watching something be taken from someone.
///
///  · PROMOTION IS AN EVENT. Twenty-one rungs exist so that this fires
///    often enough to matter; when it fires it gets confetti, a colour
///    change and its own line, because "GOLD III → GOLD II" is the
///    smallest possible unit of a man's life improving.
///
///  · IT ENDS ON THE NEXT FIGHT. The last thing on screen is RUN IT
///    BACK with the streak now at stake. Zeigarnik: an open loop is
///    remembered and a closed one isn't, so the screen refuses to close
///    the loop.
class BattleVerdict extends StatefulWidget {
  /// Both scores, already on the 0–100 scale everything else speaks.
  final int myScore;
  final int theirScore;
  final bool iWon;
  final bool tie;

  final String opponent;

  /// HIS OWN NAME. It said the literal string YOU, which is right on a
  /// live screen and wrong the moment the screen is shared — a card
  /// reading "YOU 61" is anonymous in the exact place it should brag.
  /// Callers pass his handle; the fallback keeps old sites honest.
  final String me;

  final GirlBrief girl;

  /// RR after settlement, and how far it moved. [delta] is null when the
  /// movement couldn't be measured — several duels settling at once, or
  /// a first look at the ladder. Nothing is guessed: an unmeasurable
  /// movement is simply not printed.
  final Rank rank;
  final int? delta;
  final bool promoted;
  final bool demoted;
  final Rank? from;

  /// Win streak AFTER this result.
  final int streak;

  /// True when this duel settled while he was away — the reveal he walks
  /// back into rather than the one he just played.
  final bool whileAway;

  final VoidCallback? onRunItBack;

  const BattleVerdict({
    super.key,
    required this.myScore,
    required this.theirScore,
    required this.iWon,
    required this.tie,
    required this.opponent,
    this.me = 'YOU',
    required this.girl,
    required this.rank,
    required this.delta,
    required this.promoted,
    required this.demoted,
    required this.from,
    required this.streak,
    this.whileAway = false,
    this.onRunItBack,
  });

  static Future<void> show(BuildContext context, BattleVerdict verdict) {
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'verdict',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => verdict,
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  @override
  State<BattleVerdict> createState() => _BattleVerdictState();
}

class _BattleVerdictState extends State<BattleVerdict>
    with SingleTickerProviderStateMixin {
  /// 0 hold · 1 my score · 2 his score + stamp · 3 the RR · 4 actions
  ///
  /// NOTIFIERS, NOT setState — same fault, same fix as RizzOffReveal.
  /// A setState here rebuilds the whole verdict, and the chained
  /// `.animate()` calls all over it construct fresh effect lists on
  /// every build, which reads as a new animation and replays from the
  /// top. Five stage changes meant five replays of the count-up and
  /// every fade on the screen. A ValueNotifier rebuilds only the branch
  /// that listens to it.
  final ValueNotifier<int> _stage = ValueNotifier(0);
  final ValueNotifier<bool> _burst = ValueNotifier(false);

  /// Built once, cached forever — same reasoning as RizzOffReveal: the
  /// gated branch reruns its builder on every later stage tick, and a
  /// reconstructed `.animate()` chain replays from the top. A cached
  /// widget instance cannot be replayed because it is never rebuilt.
  Widget? _wordCache;
  Widget? _marginCache;
  Widget? _rrCache;
  Widget? _actionsCache;
  final _shakeKey = GlobalKey<ImpactShakeState>();
  final _timers = <Timer>[];

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Color get _tone => widget.tie
      ? AppColors.textSecondary
      : widget.iWon
          ? kNeon
          : AppColors.red;

  String get _headline =>
      widget.tie ? 'DEAD HEAT' : (widget.iWon ? 'VICTORY' : 'DEFEAT');

  /// The old rating, reconstructed from the movement we measured. Only
  /// shown when there IS a measurement.
  int? get _wasRating =>
      widget.delta == null ? null : widget.rank.rating - widget.delta!;

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));

    Sfx.hold();
    at(1100, () {
      _stage.value = 1;
      Feel.tick();
      Sfx.axis();
    });
    at(2600, () {
      _stage.value = 2;
      _shakeKey.currentState?.shake();
      _flash.forward(from: 0);
      HapticFeedback.heavyImpact();
      Sfx.gradeSlam();
      if (widget.iWon) {
        _burst.value = true;
        Feel.win();
        Sfx.win();
      } else if (!widget.tie) {
        Feel.lost();
        Sfx.lost();
      }
    });
    at(4200, () {
      _stage.value = 3;
      Feel.reel();
      if (widget.promoted) {
        _timers.add(Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _burst.value = true;
          Feel.best();
          Sfx.personalBest();
        }));
      }
    });
    at(widget.promoted ? 6600 : 5800, () => _stage.value = 4);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flash.dispose();
    _stage.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: _stage,
            builder: (_, stage, __) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.15,
                  colors: [
                    _tone.withValues(alpha: stage >= 2 ? 0.18 : 0.06),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _burst,
              builder: (_, on, __) =>
                  on ? Burst(color: _tone) : const SizedBox.shrink(),
            ),
          ),
        ),
        SafeArea(
          child: ImpactShake(
            key: _shakeKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(children: [
                Text(
                    widget.whileAway
                        ? 'SETTLED WHILE YOU WERE GONE'
                        : 'THE VERDICT · ${widget.girl.name.toUpperCase()}',
                    style: GoogleFonts.inter(
                      color: widget.whileAway
                          ? AppColors.signalAmber
                          : widget.girl.accent,
                      fontSize: 10.5,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w900,
                    )).animate().fadeIn(duration: 340.ms),

                const Spacer(),

                // ── THE TWO NUMBERS ────────────────────────────────────
                ValueListenableBuilder<int>(
                  valueListenable: _stage,
                  builder: (_, stage, __) => Row(children: [
                    Expanded(
                      child: _Side(
                        name: widget.me.toUpperCase(),
                        score: stage >= 1 ? widget.myScore : null,
                        color: widget.iWon ? kNeon : Colors.white,
                        lit: stage >= 1,
                      ),
                    ),
                    Text('—',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        )),
                    Expanded(
                      child: _Side(
                        name: widget.opponent.toUpperCase(),
                        score: stage >= 2 ? widget.theirScore : null,
                        color: !widget.iWon && !widget.tie
                            ? AppColors.red
                            : Colors.white,
                        lit: stage >= 2,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 22),

                // ── THE WORD, THE RR, THE ACTIONS ─────────────────────
                // All stage-gated, so one listener carries the lot and
                // nothing above it rebuilds when a stage ticks over.
                ValueListenableBuilder<int>(
                  valueListenable: _stage,
                  builder: (_, stage, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stage >= 2)
                        _wordCache ??= Text(_headline,
                                style: GoogleFonts.inter(
                                  color: _tone,
                                  fontSize: 42,
                                  height: 1,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: _tone.withValues(alpha: 0.65),
                                        blurRadius: 44)
                                  ],
                                ))
                            .animate()
                            .fadeIn(duration: 180.ms)
                            .scaleXY(
                                begin: 2.1,
                                end: 1,
                                curve: Curves.easeOutBack),
                      if (stage >= 2) ...[
                        const SizedBox(height: 8),
                        _marginCache ??= Text(_margin,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ))
                            .animate()
                            .fadeIn(delay: 420.ms, duration: 300.ms),
                      ],
                      if (stage >= 3) ...[
                        const SizedBox(height: 26),
                        _rrCache ??= _ratingBlock(),
                      ],
                      if (stage >= 4) ...[
                        const SizedBox(height: 26),
                        _actionsCache ??= _actions(),
                      ],
                    ],
                  ),
                ),

                const Spacer(),
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
                return ColoredBox(color: _tone.withValues(alpha: a * 0.4));
              },
            ),
          ),
        ),
      ]),
    );
  }

  /// One line naming what actually happened. A margin of one point and a
  /// margin of forty are different events and the screen should say so —
  /// "he edged you by two" is the sentence that makes a man queue again;
  /// "DEFEAT" on its own is the one that makes him close the app.
  String get _margin {
    final gap = (widget.myScore - widget.theirScore).abs();
    if (widget.tie) {
      return 'Identical. Neither of you gave her a reason to pick.';
    }
    if (widget.iWon) {
      if (gap <= 3) return 'By $gap. That could have gone either way.';
      if (gap <= 12) return 'You had the better of it.';
      return 'Not close. You were $gap clear.';
    }
    if (gap <= 3) {
      return '$gap point${gap == 1 ? '' : 's'}. You lost this on one line.';
    }
    if (gap <= 12) return 'He read her better. $gap points in it.';
    return 'Comfortably his. $gap points.';
  }

  Widget _ratingBlock() {
    final was = _wasRating;
    final d = widget.delta;
    final up = (d ?? 0) > 0;

    return Column(children: [
      // The bar he's moving along, with the emblem sat on it.
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        RankEmblem(rank: widget.rank, size: 56, showProgress: false),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.rank.label,
              style: GoogleFonts.inter(
                color: widget.rank.div.color,
                fontSize: 17,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          // The number CLIMBS from where it was. Watching it move is the
          // point; landing on it isn't.
          if (was != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: was.toDouble(), end: widget.rank.rating.toDouble()),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(Economy.rr(v.round()),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  )),
            )
          else
            Text(Economy.rr(widget.rank.rating),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
        ]),
        if (d != null && d != 0) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: (up ? kNeon : AppColors.red).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: (up ? kNeon : AppColors.red).withValues(alpha: 0.55)),
            ),
            child: Text('${up ? '+' : ''}$d',
                style: GoogleFonts.inter(
                  color: up ? kNeon : AppColors.red,
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 240.ms)
              .slideY(begin: -0.6, end: 0, curve: Curves.easeOutBack),
        ],
      ]),

      // PROMOTION — its own line, its own colour, its own confetti.
      if (widget.promoted) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: widget.rank.div.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: widget.rank.div.color.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                  color: widget.rank.div.color.withValues(alpha: 0.3),
                  blurRadius: 26)
            ],
          ),
          child: Text(
              widget.from == null
                  ? 'PROMOTED TO ${widget.rank.label}'
                  : '${widget.from!.label} → ${widget.rank.label}',
              style: GoogleFonts.inter(
                color: widget.rank.div.color,
                fontSize: 12,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
        )
            .animate()
            .fadeIn(delay: 800.ms, duration: 260.ms)
            .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),
      ] else if (widget.demoted) ...[
        const SizedBox(height: 14),
        Text('DROPPED TO ${widget.rank.label}',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                ))
            .animate()
            .fadeIn(delay: 700.ms, duration: 260.ms),
      ] else if (widget.rank.toNext != null) ...[
        const SizedBox(height: 12),
        // ENDOWED PROGRESS. Naming the gap to the next rung right after
        // a result is what turns one duel into two: he is never at a
        // rating, he is always a specific distance from the next one.
        Text(widget.rank.toNext!,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w900,
                ))
            .animate()
            .fadeIn(delay: 700.ms, duration: 260.ms),
      ],

      // THE STREAK. Only from two — one win is not a run, and calling it
      // one cheapens the word for when he actually has one.
      if (Streaks.title(widget.streak) != null) ...[
        const SizedBox(height: 16),
        Text('${Streaks.emoji(widget.streak)} '
            '${widget.streak} ${Streaks.title(widget.streak)}',
                style: GoogleFonts.inter(
                  color: AppColors.signalAmber,
                  fontSize: 14,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: AppColors.signalAmber.withValues(alpha: 0.45),
                        blurRadius: 22)
                  ],
                ))
            .animate()
            .fadeIn(delay: 900.ms, duration: 280.ms)
            .scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack),
      ],
    ]).animate().fadeIn(duration: 340.ms);
  }

  Widget _actions() {
    return Column(children: [
      // LUCIEN, ON A LOSS ONLY.
      //
      // A win doesn't need him — the number, the confetti and the RR
      // climbing have already said it. A loss is where a man decides
      // whether to queue again, and the difference between him doing
      // that and closing the app is whether anything in the room takes
      // his side. See lucien_says.dart for why he's never insulting.
      if (!widget.iWon && !widget.tie) ...[
        LucienSays(
          line: LucienLines.afterLoss(widget.myScore),
          delay: const Duration(milliseconds: 150),
        ),
        const SizedBox(height: 14),
      ],
      if (widget.onRunItBack != null)
        SizedBox(
          width: double.infinity,
          child: GameButton(
            // The loop is left open on purpose. After a win there's a
            // streak to protect; after a loss there's a rematch to take.
            label: widget.iWon ? 'RUN IT BACK' : 'GET IT BACK',
            height: 54,
            icon: Icons.radar_rounded,
            pulse: true,
            onTap: () {
              Navigator.of(context).pop();
              widget.onRunItBack!();
            },
          ),
        ),
      const SizedBox(height: 9),
      SizedBox(
        width: double.infinity,
        child: GameButton(
          label: 'SHARE IT',
          height: 46,
          color: AppColors.surface2,
          icon: Icons.ios_share_rounded,
          onTap: _share,
        ),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('CLOSE',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            )),
      ),
    ]).animate().fadeIn(duration: 300.ms);
  }

  void _share() {
    HapticFeedback.selectionClick();
    ShareService.shareDuel(
      context: context,
      data: DuelShareData(
        me: widget.me,
        opponent: widget.opponent,
        myScore: widget.myScore,
        theirScore: widget.theirScore,
        iWon: widget.iWon,
        tie: widget.tie,
        girlName: widget.girl.name,
        rank: widget.rank,
        delta: widget.delta,
      ),
      text: widget.iWon
          ? 'Won my Rizz Battle ${widget.myScore}\u2013${widget.theirScore}. '
              '${widget.rank.label}. Who\'s next?'
          : 'Rizz Battle: ${widget.myScore}\u2013${widget.theirScore}. '
              'Running it back.',
    );
  }
}

/// One man's number, hidden until his beat.
class _Side extends StatelessWidget {
  final String name;
  final int? score;
  final Color color;
  final bool lit;
  const _Side({
    required this.name,
    required this.score,
    required this.color,
    required this.lit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 6),
      SizedBox(
        height: 56,
        child: score == null
            // The unknown number breathes. A blank space is a loading
            // state; a pulsing question mark is a result being withheld.
            ? Text('?',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 47,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.25, end: 0.7, duration: 620.ms)
            : Text('$score',
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 47,
                      height: 1,
                      letterSpacing: -2,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 30)
                      ],
                    ))
                .animate()
                .fadeIn(duration: 160.ms)
                .scaleXY(begin: 1.9, end: 1, curve: Curves.easeOutBack),
      ),
      Text('OUT OF 100',
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 8,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }
}
