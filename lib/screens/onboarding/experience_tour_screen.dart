import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE EXPERIENCE TOUR — six frames that SHOW the app, ending at the
///  paywall.
/// ══════════════════════════════════════════════════════════════════════
///
/// WHAT DIED SO THIS COULD EXIST. Two text reels: one with sixty words a
/// card in four colours, one with nine words a card in none. Both made
/// the same mistake at different volumes — they DESCRIBED the app. A
/// description of a conversation is a paragraph; the conversation itself
/// is the product. So every frame here is a little piece of the real
/// thing running: her bubbles land, Lucien slides the line in, the score
/// counts, the missions tick, the squad board fills, the duel settles.
/// The words on each frame exist to caption what the eye already saw.
///
/// ── THE ORDER IS THE FUNNEL ─────────────────────────────────────────
///
/// Talk → Lucien → Scored → Missions → Squad → Battles. Each frame
/// raises the stakes one notch: alone with her, then helped, then
/// measured, then daily, then witnessed, then versus. A man can stop
/// caring at any frame and everything before it already sold him
/// something he'd use tonight. And it ends on the paywall, because that
/// is the moment he has just been shown everything the sub unlocks.
///
/// ── EVERY ANIMATION RUNS ONCE, BY CONSTRUCTION ──────────────────────
///
/// Hard lesson from the score screens: chained `.animate()` in anything
/// that can rebuild replays from the top. There is not one `.animate()`
/// in this file. Every vignette owns one AnimationController, started in
/// initState, with every element staggered off it via Intervals — a
/// parent rebuild hands the vignette new props, never a new controller,
/// so nothing here can run twice. Swiping BACK to a frame replays its
/// vignette from zero, which is the one replay that is correct.
class ExperienceTourScreen extends StatefulWidget {
  const ExperienceTourScreen({super.key});

  @override
  State<ExperienceTourScreen> createState() => _ExperienceTourScreenState();
}

class _ExperienceTourScreenState extends State<ExperienceTourScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _i = 0;

  /// One clock drives the segment fill AND the auto page-turn, so the
  /// bar can never disagree with when the frame actually changes.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5600),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _autoAdvance();
    });

  static const _count = 6;

  @override
  void initState() {
    super.initState();
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// The clock ran out — turn the page, and on the last frame do
  /// nothing: the tour stops with the button waiting rather than
  /// ejecting a man mid-read. Never navigating from here also means the
  /// automatic path can't tear this widget down from inside its own
  /// animation notification.
  void _autoAdvance() {
    if (_i >= _count - 1) return;
    _pages.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_i >= _count - 1) {
      _done();
      return;
    }
    _autoAdvance();
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_i == 0) {
      _clock.forward(from: 0); // replay — a dead tap reads as broken
      return;
    }
    _pages.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  bool _leaving = false;

  /// The tour's one exit is the paywall — he has just been shown, not
  /// told, everything the subscription unlocks, and that is the only
  /// honest moment to ask. The paywall's own close paths land on home.
  void _done() {
    if (!mounted || _leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    context.go('/paywall');
  }

  void _onPage(int i) {
    setState(() => _i = i);
    _clock.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _count - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.75),
                  radius: 1.1,
                  colors: [Color(0x26E8222A), Colors.black],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _Segment(
                        progress: i < _i
                            ? const AlwaysStoppedAnimation<double>(1)
                            : i > _i
                                ? const AlwaysStoppedAnimation<double>(0)
                                : _clock,
                      ),
                    ),
                  ),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _done,
                child: Text('SKIP',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: _onPage,
                itemCount: _count,
                // Taps live INSIDE the page — a layer behind a PageView
                // never receives one; a Scrollable is opaque to hit
                // tests. Right two-thirds advances, left third goes
                // back, hold pauses the clock.
                itemBuilder: (_, i) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => d.localPosition.dx <
                          MediaQuery.sizeOf(context).width / 3
                      ? _back()
                      : _next(),
                  onLongPressStart: (_) => _clock.stop(),
                  onLongPressEnd: (_) => _clock.forward(),
                  child: _TourFrame(index: i),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: AnimatedOpacity(
                opacity: last ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !last,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _done,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text('GET STARTED',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            letterSpacing: 3.4,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A bar segment reading straight off the shared clock.
class _Segment extends StatelessWidget {
  final Animation<double> progress;
  const _Segment({required this.progress});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 2,
          child: Stack(children: [
            Positioned.fill(
                child:
                    ColoredBox(color: Colors.white.withValues(alpha: 0.14))),
            AnimatedBuilder(
              animation: progress,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.value.clamp(0.0, 1.0),
                child: const ColoredBox(color: AppColors.red),
              ),
            ),
          ]),
        ),
      );
}

/// One frame: header at the top — tag, headline, one clear sentence —
/// and the live vignette as the hero underneath. The header is read in
/// the first second; the vignette then acts it out.
class _TourFrame extends StatelessWidget {
  final int index;
  const _TourFrame({required this.index});

  static const _tags = [
    'PRACTICE',
    'YOUR COACH',
    'THE VERDICT',
    'EVERY DAY',
    'YOUR SQUAD',
    'RIZZ BATTLES',
  ];
  static const _heads = [
    'Talk to her.',
    'Ask Lucien.',
    'Scored, every time.',
    'Five missions a day.',
    'Nobody hides.',
    'Fight.',
  ];
  static const _subs = [
    'Ten women. Text them, or call and speak. They remember you.',
    'Your coach sits in every conversation — voice and text. Stuck? '
        'He hands you the line.',
    'Every run graded out of 100 — what landed, what flopped.',
    'Short daily reps. Most on the AI, a couple out in the real world.',
    'Two to five friends, same challenge daily. Everyone sees who '
        'showed up.',
    'Duel a friend or a stranger. Same woman, both blind. Better '
        'conversation wins.',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_tags[index],
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 11,
              letterSpacing: 4.5,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 10),
        Text(_heads[index],
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 34,
              height: 1.04,
              letterSpacing: -1.3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 10),
        Text(_subs[index],
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 22),
        Expanded(
          child: switch (index) {
            0 => const _ChatVignette(),
            1 => const _LucienVignette(),
            2 => const _ScoreVignette(),
            3 => const _MissionsVignette(),
            4 => const _SquadVignette(),
            _ => const _BattleVignette(),
          },
        ),
      ]),
    );
  }
}

/// ── SHARED VIGNETTE PLUMBING ────────────────────────────────────────

/// Fade + rise driven by a slice of the owning vignette's controller.
class _Rise extends StatelessWidget {
  final AnimationController c;
  final double from;
  final double to;
  final Widget child;
  const _Rise(this.c, this.from, this.to, {required this.child});

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
        parent: c, curve: Interval(from, to, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) => Opacity(
        opacity: t.value,
        child: Transform.translate(
            offset: Offset(0, (1 - t.value) * 16), child: child),
      ),
    );
  }
}

/// A chat bubble in the app's own visual language.
class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  const _Bubble(this.text, {this.mine = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.red.withValues(alpha: 0.22)
              : AppColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? Border.all(color: AppColors.red.withValues(alpha: 0.35))
              : null,
        ),
        child: Text(text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

/// ── 1 · TALK — her opener lands, he answers, she cracks ────────────
class _ChatVignette extends StatefulWidget {
  const _ChatVignette();
  @override
  State<_ChatVignette> createState() => _ChatVignetteState();
}

class _ChatVignetteState extends State<_ChatVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Rise(_c, 0.0, 0.18,
          child: const _Bubble(
              'ok. you have ten seconds to be interesting. go \u{1F60F}')),
      _Rise(_c, 0.26, 0.44,
          child: const _Bubble("then stop counting — you'll lose track "
              'once I start', mine: true)),
      _Rise(_c, 0.55, 0.73,
          child: const _Bubble('…okay. that was smooth \u{1F633}')),
      const Spacer(),
      // The voice hint — the other half of practice, one glance.
      _Rise(
        _c,
        0.8,
        0.98,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_rounded, size: 16, color: AppColors.red),
            const SizedBox(width: 10),
            Text('or call her — live, out loud',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

/// ── 2 · LUCIEN — the stuck moment, and the line handed over ────────
class _LucienVignette extends StatefulWidget {
  const _LucienVignette();
  @override
  State<_LucienVignette> createState() => _LucienVignetteState();
}

class _LucienVignetteState extends State<_LucienVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Rise(_c, 0.0, 0.18,
          child: const _Bubble(
              'so… why exactly should I give you my number? \u{1F440}')),
      _Rise(
        _c,
        0.3,
        0.46,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: AppColors.red.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppColors.red),
              const SizedBox(width: 6),
              Text('ASK LUCIEN',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _Rise(
        _c,
        0.56,
        0.78,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LUCIEN',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 9.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 8),
            Text('"You shouldn\'t — numbers are earned. '
                'We\'re not done yet."',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
      ),
      _Rise(
        _c,
        0.84,
        1.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('send it, or make it yours',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
      const Spacer(),
    ]);
  }
}

/// ── 3 · SCORED — the number counts once, then the two verdicts ─────
class _ScoreVignette extends StatefulWidget {
  const _ScoreVignette();
  @override
  State<_ScoreVignette> createState() => _ScoreVignetteState();
}

class _ScoreVignetteState extends State<_ScoreVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  static const _count = Interval(0.05, 0.45, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _row(String tag, String text, Color tone, IconData icon) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: 10),
          Text(tag,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 6),
      AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${(84 * _count.transform(_c.value)).round()}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 74,
                  height: 1,
                  letterSpacing: -3.5,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Color(0x80E8222A), blurRadius: 46)
                  ],
                )),
            Text(' /100',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
      ),
      const SizedBox(height: 26),
      _Rise(_c, 0.55, 0.75,
          child: _row('LANDED', 'the callback tease — she chased it', kNeon,
              Icons.check_rounded)),
      _Rise(_c, 0.72, 0.92,
          child: _row('FLOPPED', 'interviewing her at the end', AppColors.red,
              Icons.close_rounded)),
      const Spacer(),
    ]);
  }
}

/// ── 4 · MISSIONS — three rows tick, one is the real world ──────────
class _MissionsVignette extends StatefulWidget {
  const _MissionsVignette();
  @override
  State<_MissionsVignette> createState() => _MissionsVignetteState();
}

class _MissionsVignetteState extends State<_MissionsVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _mission(String title, String xp, double tickAt,
      {bool real = false}) {
    final tick = CurvedAnimation(
        parent: _c,
        curve: Interval(tickAt, (tickAt + 0.1).clamp(0.0, 1.0),
            curve: Curves.easeOutBack));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: real
                ? AppColors.signalAmber.withValues(alpha: 0.4)
                : AppColors.divider),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: tick,
          builder: (_, __) => Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(
                  Colors.transparent, kNeon.withValues(alpha: 0.2), tick.value),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Color.lerp(AppColors.surface3, kNeon, tick.value)!),
            ),
            child: Transform.scale(
              scale: tick.value,
              child: const Icon(Icons.check_rounded, size: 13, color: kNeon),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
                if (real)
                  Text('REAL WORLD',
                      style: GoogleFonts.inter(
                        color: AppColors.signalAmber,
                        fontSize: 8.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                      )),
              ]),
        ),
        Text(xp,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Rise(_c, 0.0, 0.16,
          child: _mission('Reopen Maya — on voice', '+25 XP', 0.3)),
      _Rise(_c, 0.12, 0.28,
          child: _mission('Hold frame with Lexi', '+25 XP', 0.52)),
      _Rise(_c, 0.24, 0.4,
          child:
              _mission('Say hi to one stranger', '+40 XP', 0.76, real: true)),
      const Spacer(),
    ]);
  }
}

/// ── 5 · SQUAD — the board fills, and one man is named ──────────────
class _SquadVignette extends StatefulWidget {
  const _SquadVignette();
  @override
  State<_SquadVignette> createState() => _SquadVignetteState();
}

class _SquadVignetteState extends State<_SquadVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _man(String name, String right, Color tone,
      {bool crowned = false, bool ghost = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Text(name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w900,
            )),
        if (crowned) ...[
          const SizedBox(width: 6),
          const Icon(Icons.emoji_events_rounded,
              size: 13, color: Color(0xFFFFC53D)),
        ],
        const Spacer(),
        if (ghost)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.45)),
            ),
            child: Text('NOTHING TODAY',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 8.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                )),
          )
        else
          Text(right,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Rise(_c, 0.0, 0.18, child: _man('DIEGO', '5/5', kNeon, crowned: true)),
      _Rise(_c, 0.16, 0.34, child: _man('YOU', '4/5', AppColors.signalAmber)),
      _Rise(_c, 0.32, 0.5,
          child: _man('MARCO', '', AppColors.red, ghost: true)),
      _Rise(
        _c,
        0.62,
        0.82,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.campaign_rounded,
                size: 15, color: AppColors.red),
            const SizedBox(width: 8),
            Text('call him out — the whole squad sees it',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ),
      const Spacer(),
    ]);
  }
}

/// ── 6 · BATTLE — two numbers, one word ──────────────────────────────
class _BattleVignette extends StatefulWidget {
  const _BattleVignette();
  @override
  State<_BattleVignette> createState() => _BattleVignetteState();
}

class _BattleVignetteState extends State<_BattleVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  static const _mine = Interval(0.05, 0.4, curve: Curves.easeOutCubic);
  static const _his = Interval(0.25, 0.55, curve: Curves.easeOutCubic);
  static const _word = Interval(0.66, 0.82, curve: Curves.easeOutBack);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _side(String name, int score, double t, Color tone) =>
      Column(children: [
        Text(name,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 10.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 8),
        Text('${(score * t).round()}',
            style: GoogleFonts.inter(
              color: tone,
              fontSize: 52,
              height: 1,
              letterSpacing: -2.5,
              fontWeight: FontWeight.w900,
            )),
      ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final w = _word.transform(_c.value);
        return Column(children: [
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _side('YOU', 84, _mine.transform(_c.value), kNeon)),
            Text('—',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )),
            Expanded(
                child: _side(
                    'MARCO', 71, _his.transform(_c.value), Colors.white)),
          ]),
          const SizedBox(height: 30),
          Opacity(
            opacity: w.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 2.0 - w.clamp(0.0, 1.0),
              child: Text('VICTORY',
                  style: GoogleFonts.inter(
                    color: kNeon,
                    fontSize: 38,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0x662EE87A), blurRadius: 40)
                    ],
                  )),
            ),
          ),
          const Spacer(),
        ]);
      },
    );
  }
}
