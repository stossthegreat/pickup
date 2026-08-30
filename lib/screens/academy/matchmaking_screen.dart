import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/battle_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/tiers.dart' show kNeon;
import '../../services/division.dart';
import '../../services/economy.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe;
import '../../widgets/academy/game_feel.dart';
import '../../widgets/academy/rank_emblem.dart';

/// ══════════════════════════════════════════════════════════════════════
///  MATCHMAKING — the search IS the feature
/// ══════════════════════════════════════════════════════════════════════
///
/// The old version of this was a spinner on a card that said "waiting for
/// a stranger…". It did the job and it threw away the single best moment
/// the app owns.
///
/// THE PSYCHOLOGY, in the order it happens on screen:
///
///  1. ANTICIPATION IS THE PRODUCT. The dopamine spike in every study of
///     this sits BEFORE the reward, in the gap between committing and
///     knowing. Slot machines don't sell coins, they sell the two
///     seconds the reels are still spinning. So the search is held for a
///     beat and a half even when the server pairs him instantly — not to
///     waste his time, but because an event that resolves in 200ms never
///     happened.
///
///  2. THE POOL IS VISIBLE. Ratings flicker past while the radar sweeps
///     and then LAND on the real one. That flicker is the reason a slot
///     reel slows down instead of stopping dead: watching a number
///     resolve is watching the outcome be decided. Nothing invented is
///     shown — no fake handles, no imaginary opponents being rejected —
///     just a readout of the band scrolling until it settles on a man
///     who actually exists.
///
///  3. OPPONENT FOUND IS A SLAM, not a transition. Heavy haptic, a
///     flash, and his card arriving from the right hard enough to shake
///     the screen. This is the instant a solo AI conversation becomes a
///     fight with someone in it.
///
///  4. STAKES BEFORE THE FIGHT. "WIN +31 / LOSE −14" is the whole
///     mechanic in one line. Loss aversion is roughly twice as strong as
///     the pull of the equivalent gain, so a man shown what he stands to
///     lose engages harder than one shown what he might win — and
///     against a higher-ranked rival the asymmetry is visible, which is
///     exactly when people take the fight.
///
///  5. THE WOMAN LAST. She's revealed after the stakes, so the last
///     thing he sees before the countdown is her face and the words
///     BOTH BLIND — a reminder that the man across from him is getting
///     the identical opening line and has no idea either.
///
///  6. A COUNTDOWN HE CANNOT SKIP THE FIRST TIME, and can skip forever
///     after. Ceremony that can't be dismissed is a cutscene, and every
///     man who's seen it fifty times comes to hate it.
class MatchmakingScreen extends StatefulWidget {
  /// 'chat' | 'voice'. The queue keeps a separate line per medium — a
  /// spoken attempt and a typed one can't be scored against each other,
  /// so they are never paired. See migration 0016.
  final String medium;

  const MatchmakingScreen({super.key, this.medium = 'chat'});

  /// Pushes the search and returns the paired duel, or null if he backed
  /// out / nobody was there.
  static Future<Battle?> find(BuildContext context, {String medium = 'chat'}) {
    return Navigator.of(context, rootNavigator: true).push<Battle>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => MatchmakingScreen(medium: medium),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  /// 0 scanning · 1 found · 2 stakes · 3 her · 4 countdown
  int _stage = 0;

  Battle? _battle;
  int _myRating = 1000;
  int? _oppRating;

  /// The number spinning through the band during the scan.
  int _flicker = 1000;

  bool _bailed = false;

  /// ── THE QUEUE HAD NO END ──────────────────────────────────────────
  ///
  /// This loop polled until it found someone or the man gave up, with
  /// no ceiling. With nobody else in the line — a new app, a quiet
  /// hour, a thin medium — he sat in the scanning animation
  /// indefinitely, and an animation that never resolves does not read
  /// as "nobody is here", it reads as broken.
  ///
  /// After this long with no pair we leave the line the same way the
  /// man would, THROUGH _bail — same state flag, same
  /// BattleService.leaveQueue call, same pop. Nothing about how pairing
  /// works is touched; this only decides when to stop asking.
  static const _searchCeiling = Duration(seconds: 45);

  /// True when the last search ended on the ceiling rather than on a
  /// pair or a deliberate exit. Read by the Battles screen so it can
  /// offer the thing that always works — a friend — instead of leaving
  /// him on a screen that just said no. Static because `find` returns a
  /// Battle? and a timeout is still null; widening that return type
  /// would change a signature the duel flow depends on.
  static bool lastTimedOut = false;
  int _seconds = 0;
  int _count = 3;

  final _timers = <Timer>[];
  Timer? _flickerTimer;
  Timer? _clock;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  final _rng = math.Random();

  /// Real, from the ladder. Falls back to an even fight rather than
  /// printing stakes we can't stand behind.
  Rank get _myRank => Rank.of(_myRating);
  Rank get _oppRank => Rank.of(_oppRating ?? _myRating);

  ({int win, int lose}) get _stakes =>
      Stakes.forMatch(mine: _myRating, theirs: _oppRating ?? _myRating);

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _boot();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flickerTimer?.cancel();
    _clock?.cancel();
    _sweep.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _at(int ms, VoidCallback fn) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) fn();
      }));

  Future<void> _boot() async {
    // RR — the duel ladder. Never the voice rating; see migration 0012.
    final rr = await LeaderboardService.myBattleRating();
    if (mounted && rr != null) setState(() => _myRating = rr);

    // The readout scrolls through the band around his own rating. It is
    // a scanner display, not a queue of men being rejected — which is
    // why it's a bare number and never a name.
    _flickerTimer =
        Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted || _stage > 0) return;
      setState(() => _flicker =
          (_myRating - 180 + _rng.nextInt(360)).clamp(600, 2600));
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stage == 0) setState(() => _seconds += 1);
    });

    Sfx.hold();
    await _search();
  }

  /// Poll the queue until someone's there. The Edge Function pairs on the
  /// server; this just asks again.
  Future<void> _search() async {
    final began = DateTime.now();
    MatchmakingScreen.lastTimedOut = false;
    while (mounted && !_bailed && _battle == null) {
      if (DateTime.now().difference(began) >= _searchCeiling) {
        MatchmakingScreen.lastTimedOut = true;
        await _bail();
        return;
      }
      final b = await BattleService.findOpponent(medium: widget.medium);
      if (!mounted || _bailed) return;
      if (b != null) {
        // THE MINIMUM. An instant pair still gets its beat and a half —
        // an event that resolves before he's registered it didn't
        // happen, and the anticipation is the part that's worth having.
        final held = DateTime.now().difference(began).inMilliseconds;
        final wait = held < 2200 ? 2200 - held : 0;
        _at(wait, () => _found(b));
        return;
      }
      // A SECOND, NOT THREE.
      //
      // Pairing is one-sided: the man who arrives second gets the duel
      // in his own response, and the man already waiting only learns
      // about it on his next ask. That gap IS his wait, so every second
      // of this interval is a second of one player staring at a spinner
      // while the fight already exists. The server now answers "you're
      // already in one" before anything else (see the queue action), so
      // this poll is cheap and the tighter loop is what makes the pair
      // land on both phones at once.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }
  }

  Future<void> _found(Battle b) async {
    _flickerTimer?.cancel();
    _clock?.cancel();

    // His real rating, so the stakes on screen are the real stakes.
    final id = b.opponentId;
    if (id != null) {
      final rows = await LeaderboardService.battleRatings([id]);
      _oppRating = rows[id];
    }
    if (!mounted) return;

    setState(() {
      _battle = b;
      _flicker = _oppRating ?? _myRating;
      _stage = 1;
    });
    Feel.land();
    Sfx.scoreLand();
    _flash.forward(from: 0);
    HapticFeedback.heavyImpact();

    _at(1500, () {
      setState(() => _stage = 2);
      Feel.tick();
      Sfx.axis();
    });
    _at(3700, () {
      setState(() => _stage = 3);
      Sfx.axis();
    });
    _at(5500, _startCount);
  }

  void _startCount() {
    if (!mounted) return;
    setState(() {
      _stage = 4;
      _count = 3;
    });
    for (var i = 1; i <= 3; i++) {
      _at(i * 700, () {
        setState(() => _count = 3 - i);
        if (_count > 0) {
          Feel.tick();
          Sfx.axis();
        } else {
          Feel.land();
          Sfx.gradeSlam();
        }
      });
    }
    _at(2500, _go);
  }

  void _go() {
    if (!mounted) return;
    final b = _battle;
    if (b == null) return;
    Navigator.of(context).pop(b);
  }

  /// Anywhere from OPPONENT FOUND onwards, a tap ends the ceremony. Men
  /// who've seen it fifty times get to skip it; men who haven't get the
  /// whole thing.
  void _skip() {
    if (_stage == 0 || _battle == null) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _go();
  }

  Future<void> _bail() async {
    setState(() => _bailed = true);
    HapticFeedback.selectionClick();
    await BattleService.leaveQueue();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          // A red field breathing behind everything — the room is hot
          // before anything is on it.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [
                    AppColors.red.withValues(alpha: _stage == 0 ? 0.13 : 0.2),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _stage == 0 ? _scanning() : _matched(),
          ),
          // Impact flash on OPPONENT FOUND.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (_, __) {
                  if (_flash.value == 0) return const SizedBox.shrink();
                  final a =
                      (1 - Curves.easeOutQuart.transform(_flash.value))
                          .clamp(0.0, 1.0);
                  return ColoredBox(
                      color: Colors.white.withValues(alpha: a * 0.35));
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  STAGE 0 — THE SCAN
  // ══════════════════════════════════════════════════════════════════

  Widget _scanning() {
    final r = _myRank;
    return Column(children: [
      const SizedBox(height: 10),
      Row(children: [
        IconButton(
          onPressed: _bail,
          icon: const Icon(Icons.close_rounded,
              size: 22, color: AppColors.textTertiary),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Text(_seconds < 60 ? '${_seconds}s' : '${_seconds ~/ 60}m',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
        ),
      ]),

      const Spacer(),

      // The radar, with his own emblem sat in the middle of it — he is
      // the thing the sweep is measuring from.
      SizedBox(
        width: 250,
        height: 250,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _sweep,
            builder: (_, __) => CustomPaint(
              size: const Size(250, 250),
              painter: _RadarPainter(t: _sweep.value, color: AppColors.red),
            ),
          ),
          RankEmblem(rank: r, size: 88, showProgress: false),
        ]),
      ),

      const SizedBox(height: 26),
      Text('SCANNING THE LADDER',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 5,
                fontWeight: FontWeight.w900,
              ))
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.45, end: 1, duration: 800.ms),
      const SizedBox(height: 12),

      // The readout. It's the band, scrolling — and in a moment it will
      // stop on a real man.
      Text(Economy.commas(_flicker),
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 40,
            height: 1,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: AppColors.red.withValues(alpha: 0.5), blurRadius: 28)
            ],
          )),
      const SizedBox(height: 4),
      Text('${Economy.rrLong} IN RANGE',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 9.5,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          )),

      const Spacer(),

      // The honest line. After twenty seconds it stops pretending the
      // pool is full — an app that says "still looking" keeps its
      // credibility; one that spins forever loses it.
      if (_seconds >= 20)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
              'Quiet out there. Stay in the line and we\'ll pair you the '
              'second someone queues — or back out and challenge a mate '
              'by code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              )).animate().fadeIn(duration: 400.ms),
        ),
      const SizedBox(height: 18),
      TextButton(
        onPressed: _bail,
        child: Text('LEAVE THE LINE',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            )),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════
  //  STAGES 1–4 — FOUND, STAKES, HER, COUNT
  // ══════════════════════════════════════════════════════════════════

  Widget _matched() {
    final b = _battle!;
    final girl = girlForVibe(b.scenario);
    final s = _stakes;
    final under = Stakes.underdog(mine: _myRating, theirs: _oppRating ?? _myRating);

    return Column(children: [
      const SizedBox(height: 18),
      Text('OPPONENT FOUND',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 13,
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: AppColors.red.withValues(alpha: 0.7),
                      blurRadius: 24)
                ],
              ))
          .animate()
          .fadeIn(duration: 220.ms)
          .scaleXY(begin: 1.6, end: 1, curve: Curves.easeOutBack),

      const Spacer(),

      // The two men. His card arrives from the left, the rival's from the
      // right, and they meet on VS.
      Row(children: [
        Expanded(
          child: _Fighter(rank: _myRank, name: 'YOU', mine: true)
              .animate()
              .fadeIn(duration: 260.ms)
              .slideX(begin: -0.35, end: 0, curve: Curves.easeOutBack),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('VS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(delay: 200.ms, duration: 200.ms)
              .scaleXY(begin: 2.4, end: 1, curve: Curves.easeOutBack),
        ),
        Expanded(
          child: _Fighter(
            rank: _oppRank,
            name: 'RIVAL',
            mine: false,
            unknown: _oppRating == null,
          )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideX(begin: 0.35, end: 0, curve: Curves.easeOutBack),
        ),
      ]),

      const SizedBox(height: 24),

      // ── STAKES ──────────────────────────────────────────────────────
      if (_stage >= 2)
        Column(children: [
          Text('WHAT\'S ON THE LINE',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9,
                letterSpacing: 3.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Stake(label: 'WIN', value: '+${s.win}', color: kNeon),
            const SizedBox(width: 12),
            Container(width: 1, height: 34, color: AppColors.surface3),
            const SizedBox(width: 12),
            _Stake(label: 'LOSE', value: '${s.lose}', color: AppColors.red),
          ]),
          if (under) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.signalAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.signalAmber.withValues(alpha: 0.5)),
              ),
              // The underdog line exists because asymmetric upside is
              // the single most reliable reason a person takes a fight.
              child: Text('UNDERDOG · HE\'S ABOVE YOU',
                  style: GoogleFonts.inter(
                    color: AppColors.signalAmber,
                    fontSize: 10,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ],
        ])
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

      const Spacer(),

      // ── HER ─────────────────────────────────────────────────────────
      if (_stage >= 3)
        Column(children: [
          Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface2,
              border: Border.all(color: girl.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: girl.accent.withValues(alpha: 0.45), blurRadius: 34)
              ],
            ),
            child: Image.asset(
              girl.asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: girl.accent.withValues(alpha: 0.25)),
            ),
          ),
          const SizedBox(height: 12),
          Text(girl.name.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: -0.6,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 3),
          Text('SAME WOMAN · BOTH BLIND',
              style: GoogleFonts.inter(
                color: girl.accent,
                fontSize: 10,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w900,
              )),
        ])
            .animate()
            .fadeIn(duration: 340.ms)
            .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack),

      const Spacer(),

      // ── THE COUNT ───────────────────────────────────────────────────
      SizedBox(
        height: 84,
        child: _stage >= 4
            ? Center(
                child: _count > 0
                    ? Text('$_count',
                            key: ValueKey(_count),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 68,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                    color: AppColors.red
                                        .withValues(alpha: 0.7),
                                    blurRadius: 40)
                              ],
                            ))
                        .animate()
                        .scaleXY(
                            begin: 1.8,
                            end: 1,
                            duration: 260.ms,
                            curve: Curves.easeOutBack)
                        .fadeIn(duration: 140.ms)
                    : Text('BATTLE',
                            style: GoogleFonts.inter(
                              color: AppColors.red,
                              fontSize: 40,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                    color: AppColors.red
                                        .withValues(alpha: 0.8),
                                    blurRadius: 46)
                              ],
                            ))
                        .animate()
                        .scaleXY(
                            begin: 2.2,
                            end: 1,
                            duration: 300.ms,
                            curve: Curves.easeOutBack)
                        .fadeIn(duration: 160.ms),
              )
            : Center(
                child: Text('TAP TO SKIP',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    )),
              ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

/// One man's corner: emblem, division, rating.
class _Fighter extends StatelessWidget {
  final Rank rank;
  final String name;
  final bool mine;

  /// True when the ladder wouldn't tell us his rating. We show the
  /// division as unknown rather than printing a number we invented.
  final bool unknown;

  const _Fighter({
    required this.rank,
    required this.name,
    required this.mine,
    this.unknown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (unknown)
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface1,
            border: Border.all(color: AppColors.surface3, width: 2),
          ),
          child: Text('?',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              )),
        )
      else
        RankEmblem(rank: rank, size: 76, showProgress: false),
      const SizedBox(height: 10),
      Text(name,
          style: GoogleFonts.inter(
            color: mine ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 3),
      Text(unknown ? 'UNRANKED' : rank.label,
          style: GoogleFonts.inter(
            color: unknown ? AppColors.textMuted : rank.div.color,
            fontSize: 12.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 2),
      Text(unknown ? '—' : Economy.rr(rank.rating),
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          )),
    ]);
  }
}

class _Stake extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stake(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 9.5,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 2),
      Text('$value ${Economy.rrShort}',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 25,
            height: 1.1,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.45), blurRadius: 20)
            ],
          )),
    ]);
  }
}

/// Concentric rings and a sweeping wedge. Painted rather than animated
/// as an asset because the sweep has to be continuous — a looping GIF
/// stutters at the seam and the whole illusion is that something is
/// genuinely out there being looked for.
class _RadarPainter extends CustomPainter {
  final double t; // 0..1, one full rotation
  final Color color;
  const _RadarPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Rings.
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        c,
        r * i / 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.13),
      );
    }
    // Cross hairs.
    final hair = Paint()..color = color.withValues(alpha: 0.08);
    canvas.drawRect(Rect.fromLTWH(0, c.dy - 0.5, size.width, 1), hair);
    canvas.drawRect(Rect.fromLTWH(c.dx - 0.5, 0, 1, size.height), hair);

    // The sweep — six thin wedges fading behind the leading edge. A
    // stack of flat wedges rather than one gradient-shaded one, because
    // a sweep gradient's angles have to be reasoned about at every
    // frame and this reads identically for a tenth of the thinking.
    final a = t * math.pi * 2 - math.pi / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    const slice = 0.16;
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(
        rect,
        a - slice * (i + 1),
        slice + 0.01, // hairline overlap so the wedges don't seam
        true,
        Paint()..color = color.withValues(alpha: 0.30 * (1 - i / 6)),
      );
    }
    // The leading edge, bright.
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * r,
      Paint()
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}
