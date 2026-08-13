import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import '../../services/sfx_service.dart';
import 'game_feel.dart';
import 'grade_stamp.dart';

/// THE RIZZ-OFF REVEAL — the daily dopamine moment, staged properly.
///
/// A result you WATCH LAND is worth ten of the same result handed to
/// you. So nothing appears at once:
///
///   1. Black. One small pulse. (You just spoke; let it breathe.)
///   2. The five axes land one at a time, each with a tick.
///   3. They collapse inward and become a single number out of 10.
///   4. The grade slams in with a shockwave, shake and flash.
///   5. SQUAD REVEAL — everyone's cards slam into rank order.
///
/// Scores are out of 10 because a human reads 8.7 instantly. The 0–9999
/// resolution the grader stores is a server-side implementation detail
/// and never reaches the screen.
class RizzOffReveal extends StatefulWidget {
  final int score; // 0..9999
  final Map<String, int> rubric; // axis → 0..100
  final int rankToday;
  final int worldAvg;
  final String girlName;
  final Color girlAccent;

  /// Squad state for the final slam. Empty = solo, and the whole squad
  /// act is skipped rather than shown as a lonely single card.
  final List<SquadMember> roster;
  final List<DailyMark> squadMarks;

  /// SCALE. Voice is stored 0..9999 and read out of 10; chat is stored
  /// 0..100 and read out of 100. Everything else about the reveal — the
  /// count-up, the grade slam, the squad cards — is identical, so the
  /// two challenges share this rather than getting two animations that
  /// almost match.
  ///
  /// [gradeScore] is always on the 0..9999 band the grade thresholds are
  /// cut against; a chat caller passes score * 99.99.
  final double divisor;
  final int decimals;
  final String suffix;
  final int? gradeScore;
  final String kicker;

  /// The rubric's axes, in weighted order, and their labels. Text is
  /// graded on different things to voice — you can't hear a written
  /// line's delivery — so the reveal has to be able to say so.
  final List<String> axes;
  final Map<String, String> axisLabels;

  const RizzOffReveal({
    super.key,
    required this.score,
    required this.rubric,
    required this.rankToday,
    required this.worldAvg,
    required this.girlName,
    required this.girlAccent,
    this.roster = const [],
    this.squadMarks = const [],
    this.divisor = 999.9,
    this.decimals = 1,
    this.suffix = '/ 10',
    this.gradeScore,
    this.kicker = 'THE DAILY',
    this.axes = const ['confidence', 'flow', 'wit', 'recovery', 'close'],
    this.axisLabels = const {
      'confidence': 'CONFIDENCE',
      'flow': 'FLOW',
      'wit': 'WIT',
      'recovery': 'RECOVERY',
      'close': 'CLOSE',
    },
  });

  @override
  State<RizzOffReveal> createState() => _RizzOffRevealState();
}

class _RizzOffRevealState extends State<RizzOffReveal>
    with SingleTickerProviderStateMixin {
  final _shakeKey = GlobalKey<ImpactShakeState>();
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  /// 0 breathe · 1 axes · 2 collapse+score · 3 squad · 4 actions
  int _stage = 0;
  bool _burst = false;
  final _timers = <Timer>[];

  List<String> get _axes => widget.axes;
  Map<String, String> get _labels => widget.axisLabels;

  RizzGrade get _grade => RizzGrade.of(widget.gradeScore ?? widget.score);

  /// The headline number on its own scale.
  double get _shown =>
      (widget.score / widget.divisor).clamp(0, 9999).toDouble();
  String get _outOfTen => _shown.toStringAsFixed(widget.decimals);

  List<DailyMark> get _finished =>
      widget.squadMarks.where((m) => m.finished).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

  bool get _hasSquad => widget.roster.length > 1;

  /// THE NEAR MISS — the line that brings him back tomorrow.
  ///
  /// Computed against the man directly above him on today's board. We
  /// don't manufacture it the way a machine would; there genuinely is
  /// someone 0.2 ahead, and saying so out loud turns a score into a
  /// grudge. Null when nothing is close enough to be worth naming —
  /// crying "so close" over a wide gap is how a screen loses credibility.
  String? get _near {
    final ranked = _finished;
    if (ranked.length < 2) return null;
    final me = AuthService.userId;
    final i = ranked.indexWhere((m) => m.userId == me);
    if (i <= 0) return null; // not on the board, or already top
    final above = ranked[i - 1];
    final mine = (ranked[i].score ?? 0) / widget.divisor;
    final his = (above.score ?? 0) / widget.divisor;
    String nameOf(String id) {
      for (final m in widget.roster) {
        if (m.userId == id) return m.handle ?? 'him';
      }
      return 'him';
    }

    // "Close" scales with the board: a tenth of a point out of 10, or
    // four points out of 100.
    final within = (100 / widget.divisor) * 0.04;
    return nearMissLine(
      mine: mine,
      above: his,
      aboveName: nameOf(above.userId),
      closeWithin: within < 0.2 ? 0.2 : within,
    );
  }

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));

    // THE HOLD. The dopamine is not in the number, it's in the gap
    // between committing and knowing — which is the only thing a slot
    // machine actually sells. We used to spend that gap in 700ms. Now
    // she "decides" for a beat and a half first, with a slow pulse under
    // it, and the axes mean more when they finally start landing.
    const hold = 1500;
    Sfx.hold();
    at(240, Feel.tick);
    at(820, Feel.tick);

    // One tick per axis as it lands — you feel the score being built.
    for (var i = 0; i < _axes.length; i++) {
      at(hold + 200 + i * 520, () {
        Feel.reel();
        Sfx.axis();
      });
    }
    at(hold, () => setState(() => _stage = 1));
    final axesEnd = hold + 200 + _axes.length * 520;
    at(axesEnd, () {
      setState(() => _stage = 2);
      // The number lands like a thing with weight, then the grade
      // stamps a beat later — two events, not one.
      Feel.land();
      Sfx.scoreLand();
    });
    at(axesEnd + 900, () {
      // Best-ever and near-miss get their own signatures, so the phone
      // has told him the outcome before his eyes have.
      Sfx.gradeSlam();
      if (_near != null) {
        Feel.nearMiss();
        Sfx.nearMiss();
      } else if (const ['S', 'A', 'B'].contains(_grade.letter)) {
        Feel.win();
        Sfx.win();
      }
    });
    if (_hasSquad) {
      at(axesEnd + 2600, () => setState(() => _stage = 3));
    }
    at(axesEnd + (_hasSquad ? 4200 : 2400), () => setState(() => _stage = 4));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flash.dispose();
    super.dispose();
  }

  void _onImpact() {
    if (!mounted) return;
    _shakeKey.currentState?.shake();
    _flash.forward(from: 0);
    if (widget.score >= 6200) setState(() => _burst = true);
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade;
    return Material(
      color: Colors.black,
      child: Stack(children: [
        if (_burst) Positioned.fill(child: Burst(color: grade.color)),
        SafeArea(
          child: ImpactShake(
            key: _shakeKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 18),
              child: Column(children: [
                // ── Kicker ──────────────────────────────────────────
                Text('${widget.kicker} · ${widget.girlName.toUpperCase()}',
                        style: GoogleFonts.inter(
                          color: widget.girlAccent,
                          fontSize: 10.5,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w900,
                        ))
                    .animate()
                    .fadeIn(duration: 400.ms),

                Expanded(
                  child: Center(
                    child: _stage == 0
                        ? _breath()
                        : _stage == 1
                            ? _axesList()
                            : _scoreBlock(grade),
                  ),
                ),

                // THE NEAR MISS. Placed under the squad slam because it
                // only means anything once you've seen whose name is
                // above yours — and the screen flinches when it lands.
                if (_stage >= 3 && _near != null)
                  Flinch(
                    active: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 14, color: AppColors.red),
                          const SizedBox(width: 8),
                          Text(_near!.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: AppColors.red,
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                  ),
                if (_stage >= 3 && _hasSquad) _squadSlam(),
                if (_stage >= 4) _actions(grade),
              ]),
            ),
          ),
        ),

        // Impact flash, above everything, never eats a tap.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, __) {
                if (_flash.value == 0) return const SizedBox.shrink();
                final a = (1 - Curves.easeOutQuart.transform(_flash.value))
                    .clamp(0.0, 1.0);
                return ColoredBox(
                    color: grade.color.withValues(alpha: a * 0.45));
              },
            ),
          ),
        ),
      ]),
    );
  }

  /// Stage 0 — one slow pulse on black. You've just spoken to her; the
  /// silence before the verdict is the whole point.
  /// Stage 0 — THE HOLD. A dot breathing in the dark and three words.
  /// Naming the wait is what converts dead time into tension: silence
  /// reads as a spinner, "she's deciding" reads as a verdict coming.
  Widget _breath() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: widget.girlAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: widget.girlAccent.withValues(alpha: 0.6),
                blurRadius: 24)
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.7, end: 1.5, duration: 700.ms)
          .fade(begin: 0.4, end: 1),
      const SizedBox(height: 26),
      Text('SHE\'S DECIDING',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 4.5,
                fontWeight: FontWeight.w900,
              ))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.35, end: 1, duration: 900.ms),
    ]);
  }

  /// Stage 1 — the axes land one at a time, each sliding in from the
  /// left with its bar drawing behind the number.
  Widget _axesList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, axis) in _axes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _AxisRow(
              label: _labels[axis]!,
              value: widget.rubric[axis] ?? 0,
            )
                .animate()
                .fadeIn(delay: (200 + i * 520).ms, duration: 260.ms)
                .slideX(begin: -0.12, end: 0, curve: Curves.easeOutCubic),
          ),
      ],
    );
  }

  /// Stage 2 — the axes are gone; one number, the grade on top of it.
  Widget _scoreBlock(RizzGrade grade) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 210,
        child: Stack(alignment: Alignment.center, children: [
          // The number rises out of where the axes collapsed.
          Positioned(
            top: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                      begin: 0,
                      end: double.parse(_outOfTen)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    v.toStringAsFixed(widget.decimals),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 76,
                      height: 1,
                      letterSpacing: -3.5,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: grade.color.withValues(alpha: 0.5),
                            blurRadius: 50)
                      ],
                    ),
                  ),
                ),
                Text(' ${widget.suffix}',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            )
                .animate()
                .fadeIn(duration: 380.ms)
                .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic)
                .then(delay: 1200.ms)
                .moveY(begin: 0, end: -18, duration: 300.ms)
                .scaleXY(begin: 1, end: 0.62, duration: 300.ms),
          ),
          Positioned(
            top: 56,
            child: GradeStamp(
              grade: grade,
              delay: const Duration(milliseconds: 1500),
              size: 124,
              onImpact: _onImpact,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Column(children: [
              Text(grade.verdict,
                  style: GoogleFonts.inter(
                    color: grade.color,
                    fontSize: 12.5,
                    letterSpacing: 4.4,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 5),
              Text('RIZZ SCORE',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 8.5,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w900,
                  )),
            ])
                .animate()
                .fadeIn(delay: 1980.ms, duration: 260.ms)
                .slideY(begin: 0.6, end: 0, curve: Curves.easeOut),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      // World context — the reason to come back tomorrow.
      Text('#${widget.rankToday} IN THE WORLD TODAY',
              style: GoogleFonts.inter(
                color: grade.color,
                fontSize: 12,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(delay: 2200.ms)
          .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack),
      const SizedBox(height: 4),
      Text('World average '
          '${(widget.worldAvg / widget.divisor).toStringAsFixed(widget.decimals)}',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ))
          .animate()
          .fadeIn(delay: 2340.ms),
    ]);
  }

  /// Stage 3 — everyone's cards slam into rank order, one after the
  /// other. Nobody's number was visible until this instant.
  Widget _squadSlam() {
    final finished = _finished;
    final waiting = widget.roster.where((m) {
      for (final d in widget.squadMarks) {
        if (d.userId == m.userId && d.finished) return false;
      }
      return true;
    }).toList();

    String nameOf(String id) {
      for (final m in widget.roster) {
        if (m.userId == id) {
          return m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');
        }
      }
      return 'ANON';
    }

    return Column(children: [
      Text('SQUAD REVEAL',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9,
                letterSpacing: 3.4,
                fontWeight: FontWeight.w900,
              ))
          .animate()
          .fadeIn(duration: 240.ms),
      const SizedBox(height: 10),
      for (final (i, d) in finished.indexed)
        _SlamRow(
          position: i + 1,
          name: nameOf(d.userId),
          score: (d.score ?? 0) / widget.divisor,
          mine: d.userId == AuthService.userId,
          delay: (i * 240).ms,
        ),
      for (final (i, m) in waiting.indexed)
        _SlamRow(
          position: finished.length + i + 1,
          name: m.userId == AuthService.userId
              ? 'YOU'
              : (m.handle ?? 'ANON'),
          score: null,
          mine: m.userId == AuthService.userId,
          delay: ((finished.length + i) * 240).ms,
        ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _actions(RizzGrade grade) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: GameButton(
          label: 'SHARE IT',
          color: grade.color,
          textColor:
              grade.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          icon: Icons.ios_share_rounded,
          onTap: () => Share.share(
              '${widget.kicker} on ImHim Rizz: $_outOfTen ${widget.suffix} — grade '
              '${grade.letter}, #${widget.rankToday} in the world today. '
              'One attempt. Same girl for everyone. Your turn.'),
        ),
      ),
      const SizedBox(height: 8),
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
}

/// One axis: label, a bar that draws, and the number out of 10.
class _AxisRow extends StatelessWidget {
  final String label;
  final int value; // 0..100
  const _AxisRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ten = (value / 10).clamp(0, 10);
    final strong = value >= 75;
    final color = strong
        ? kNeon
        : value >= 50
            ? AppColors.red
            : AppColors.textTertiary;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              letterSpacing: 2.6,
              fontWeight: FontWeight.w900,
            )),
        const Spacer(),
        Text(ten.toStringAsFixed(1),
            style: GoogleFonts.inter(
              color: strong ? kNeon : Colors.white,
              fontSize: 22,
              height: 1,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w900,
            )),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(children: [
          Container(
              height: 3, color: Colors.white.withValues(alpha: 0.07)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.55), blurRadius: 8)
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// A squad card that slams in from the right and settles.
///
/// Stateful purely so the impact haptic can be fired from a Timer keyed
/// to the same delay as the entrance. flutter_animate has a callback
/// effect, but its exact signature isn't something to guess at when the
/// package can't be compiled here — a Timer is unambiguous.
class _SlamRow extends StatefulWidget {
  final int position;
  final String name;
  final double? score; // null = hasn't run it
  final bool mine;
  final Duration delay;

  const _SlamRow({
    required this.position,
    required this.name,
    required this.score,
    required this.mine,
    required this.delay,
  });

  @override
  State<_SlamRow> createState() => _SlamRowState();
}

class _SlamRowState extends State<_SlamRow> {
  Timer? _thud;

  static const _medals = ['1', '2', '3'];

  @override
  void initState() {
    super.initState();
    _thud = Timer(widget.delay + const Duration(milliseconds: 120), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _thud?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final name = widget.name;
    final score = widget.score;
    final mine = widget.mine;
    final delay = widget.delay;
    final podium = position <= 3 && score != null;
    final colour = position == 1 && score != null
        ? const Color(0xFFFFD34D)
        : mine
            ? AppColors.red
            : AppColors.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.red.withValues(alpha: 0.10)
            : AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: mine
                ? AppColors.red.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        SizedBox(
          width: 20,
          child: Text(podium ? _medals[position - 1] : '$position',
              style: GoogleFonts.inter(
                color: colour,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: mine ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w900,
              )),
        ),
        Text(score == null ? '—' : score!.toStringAsFixed(1),
            style: GoogleFonts.inter(
              color: score == null ? AppColors.textMuted : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
      ]),
    )
        .animate()
        .fadeIn(delay: delay, duration: 180.ms)
        // Slams in from the right and overshoots — weight, not a fade.
        .slideX(begin: 0.5, end: 0, curve: Curves.easeOutBack, duration: 340.ms);
  }
}
