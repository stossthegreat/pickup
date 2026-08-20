import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE EXPERIENCE TOUR — the loop, shown running, then the close.
/// ══════════════════════════════════════════════════════════════════════
///
/// EIGHT FRAMES, AND THEY ARE THE PRODUCT'S OWN LOOP IN ORDER:
///
///   talk → missions → Lucien → voice → scored & ranked → battles →
///   squad → the close.
///
/// Singular first because anyone can do it tonight alone; missions turn
/// it into a habit; Lucien is the help that makes practice compound;
/// voice is where it becomes a real skill; the score and the ladder make
/// progress visible; battles make it fun; the squad makes it stick. Each
/// frame's caption says what it is AND why it works on you, in one
/// breath — by the last frame the case for paying has already been made
/// by the frames, so the close only has to say it out loud.
///
/// Every frame is a live vignette of the real feature — her bubbles
/// landing, the coach card sliding in, a call running, the board
/// climbing — because a description of a conversation is a paragraph and
/// the conversation itself is the product.
///
/// ── NAVIGATION IS DEAF TO EVERYTHING BUT A DELIBERATE GESTURE ───────
///
/// Two dead reels and one skipped tour taught the same lesson three
/// ways: anything that can move a man off a screen without him asking
/// eventually will, at the worst moment. So:
///
///   · the auto-play only ever turns PAGES — it cannot leave the screen
///   · a tap only ever turns pages — on the last frame it does nothing
///   · the ONLY exits are the GET STARTED button and SKIP, both real
///     buttons needing a real press, both going to the paywall — which
///     is the designed end of this funnel, never a surprise mid-flow
///
/// ── AND NOTHING CAN PLAY TWICE ──────────────────────────────────────
///
/// No `.animate()` anywhere. Every vignette owns one controller started
/// in initState with Interval staggering — rebuilds hand it props, never
/// a new controller.
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
  /// bar can never disagree with when the frame changes.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6200),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _autoAdvance();
    });

  static const _count = 8;

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

  /// Auto-play turns pages and NOTHING ELSE. On the last frame it goes
  /// quiet and the button waits. Never navigating from here also means
  /// the clock can't tear its own widget down from inside its own
  /// status notification.
  void _autoAdvance() {
    if (_i >= _count - 1) return;
    _pages.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  /// A tap turns pages and NOTHING ELSE either — on the last frame it is
  /// deliberately dead. A thumb resting on glass must never be able to
  /// buy a paywall visit.
  void _next() {
    if (_i >= _count - 1) return;
    HapticFeedback.selectionClick();
    _autoAdvance();
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_i == 0) {
      _clock.forward(from: 0); // replay the beat — a dead tap reads broken
      return;
    }
    _pages.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  bool _leaving = false;

  /// The one and only way off this screen: a real press on GET STARTED
  /// or SKIP. Both land on the paywall — the designed end of the
  /// funnel, at the one moment he has just been SHOWN everything the
  /// subscription unlocks. The paywall's own close paths land on home.
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
                // never receives one (a Scrollable is opaque to hit
                // tests). Right two-thirds forward, left third back,
                // hold pauses. Swipes untouched.
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

/// One frame: tag, headline, one caption that says what it is AND why
/// it works — then the vignette acts it out underneath.
class _TourFrame extends StatelessWidget {
  final int index;
  const _TourFrame({required this.index});

  static const _tags = [
    'PRACTICE',
    'EVERY DAY',
    'REAL HELP',
    'OUT LOUD',
    'THE LADDER',
    'RIZZ BATTLES',
    'YOUR SQUAD',
    'IMHIM',
  ];
  static const _heads = [
    'Talk to her.',
    'Five missions.',
    'Ask Lucien.',
    'Now say it live.',
    'Scored. Ranked.',
    'Fight.',
    'Nobody hides.',
    'From intro\nto ice queen.',
  ];
  static const _subs = [
    'Ten women, voice or text. They remember you — so it never '
        'resets to zero.',
    'Small daily reps, most on the AI. Show up daily and the fear '
        'dies quietly.',
    'Stuck mid-chat? He hands you the exact line — and you learn why '
        'it works.',
    'Your real voice, live. This is where it stops being an app and '
        'becomes a skill.',
    'Every run out of 100. Watch your name climb, week over week.',
    'Same woman, both blind — better conversation wins. Fun that '
        'sharpens you.',
    'Two to five friends, same challenge daily. Accountability is '
        'the cheat code.',
    'Keep the loop running and nothing you meet in real life will '
        'shake you.',
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
              fontSize: 33,
              height: 1.06,
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
        const SizedBox(height: 20),
        Expanded(
          child: switch (index) {
            0 => const _ChatVignette(),
            1 => const _MissionsVignette(),
            2 => const _LucienVignette(),
            3 => const _VoiceVignette(),
            4 => const _LadderVignette(),
            5 => const _BattleVignette(),
            6 => const _SquadVignette(),
            _ => const _CloseVignette(),
          },
        ),
      ]),
    );
  }
}

/// ── SHARED PLUMBING ─────────────────────────────────────────────────

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

Widget _card({required Widget child, Color? borderTint}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: borderTint?.withValues(alpha: 0.4) ?? AppColors.divider),
      ),
      child: child,
    );

/// ── 1 · TALK ────────────────────────────────────────────────────────
class _ChatVignette extends StatefulWidget {
  const _ChatVignette();
  @override
  State<_ChatVignette> createState() => _ChatVignetteState();
}

class _ChatVignetteState extends State<_ChatVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
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
      _Rise(_c, 0.28, 0.46,
          child: const _Bubble("then stop counting — you'll lose track "
              'once I start', mine: true)),
      _Rise(_c, 0.58, 0.76,
          child: const _Bubble('…okay. that was smooth \u{1F633}')),
      const Spacer(),
      _Rise(
        _c,
        0.82,
        1.0,
        child: _card(
          child: Row(children: [
            const Icon(Icons.psychology_rounded,
                size: 16, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'she remembers this tomorrow — cold, warm, or won over',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// ── 2 · MISSIONS ────────────────────────────────────────────────────
class _MissionsVignette extends StatefulWidget {
  const _MissionsVignette();
  @override
  State<_MissionsVignette> createState() => _MissionsVignetteState();
}

class _MissionsVignetteState extends State<_MissionsVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
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
    return _card(
      borderTint: real ? AppColors.signalAmber : null,
      child: Row(children: [
        AnimatedBuilder(
          animation: tick,
          builder: (_, __) => Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(Colors.transparent,
                  kNeon.withValues(alpha: 0.2), tick.value),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      _Rise(
        _c,
        0.84,
        1.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 15, color: AppColors.red),
            const SizedBox(width: 8),
            Text('a streak you will not want to lose',
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

/// ── 3 · LUCIEN ──────────────────────────────────────────────────────
class _LucienVignette extends StatefulWidget {
  const _LucienVignette();
  @override
  State<_LucienVignette> createState() => _LucienVignetteState();
}

class _LucienVignetteState extends State<_LucienVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
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
          child: Text('send it as-is, or make it yours — that\'s the rep',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
      const Spacer(),
    ]);
  }
}

/// ── 4 · VOICE — a live call, running ────────────────────────────────
class _VoiceVignette extends StatefulWidget {
  const _VoiceVignette();
  @override
  State<_VoiceVignette> createState() => _VoiceVignetteState();
}

class _VoiceVignetteState extends State<_VoiceVignette>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..forward();

  /// The waveform breathes for the whole frame — a live call that isn't
  /// moving reads as a frozen screenshot, the one thing a vignette must
  /// never be.
  late final AnimationController _wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Rise(
        _c,
        0.0,
        0.2,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Row(children: [
              AnimatedBuilder(
                animation: _wave,
                builder: (_, __) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(
                        alpha: 0.5 +
                            0.5 *
                                (0.5 +
                                    0.5 *
                                        math.sin(
                                            _wave.value * 2 * math.pi))),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('LIVE · MAYA',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 10.5,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              Text('01:24',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: AnimatedBuilder(
                animation: _wave,
                builder: (_, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 24; i++)
                      Container(
                        width: 3.5,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2.5),
                        height: 8 +
                            30 *
                                (0.5 +
                                        0.5 *
                                            math.sin(_wave.value *
                                                    2 *
                                                    math.pi +
                                                i * 0.9))
                                    .abs(),
                        decoration: BoxDecoration(
                          color: i % 3 == 0
                              ? AppColors.red
                              : Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      _Rise(
        _c,
        0.5,
        0.72,
        child: _card(
          borderTint: AppColors.red,
          child: Row(children: [
            const Icon(Icons.bolt_rounded, size: 15, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Lucien, mid-call: "slow down — let her chase the pause"',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ]),
        ),
      ),
      _Rise(
        _c,
        0.8,
        1.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('the voice that shakes in week one doesn\'t in week three',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
      const Spacer(),
    ]);
  }
}

/// ── 5 · SCORED & RANKED — the number, then the ladder ──────────────
class _LadderVignette extends StatefulWidget {
  const _LadderVignette();
  @override
  State<_LadderVignette> createState() => _LadderVignetteState();
}

class _LadderVignetteState extends State<_LadderVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward();

  static const _count = Interval(0.02, 0.36, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _row(String pos, String name, String pts, {bool me = false}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: me ? AppColors.surface2 : AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: me
                  ? AppColors.red.withValues(alpha: 0.45)
                  : AppColors.divider),
        ),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Text(pos,
                style: GoogleFonts.inter(
                  color: me ? AppColors.red : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                )),
          ),
          Text(name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text(pts,
              style: GoogleFonts.inter(
                color: me ? Colors.white : AppColors.textTertiary,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
                  fontSize: 62,
                  height: 1,
                  letterSpacing: -3,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Color(0x80E8222A), blurRadius: 40)
                  ],
                )),
            Text(' /100',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _Rise(_c, 0.42, 0.58, child: _row('#11', 'KING-204', '1,240')),
      _Rise(_c, 0.52, 0.68, child: _row('#12', 'YOU', '1,180', me: true)),
      _Rise(_c, 0.62, 0.78, child: _row('#13', 'WOLF-88', '1,110')),
      _Rise(
        _c,
        0.84,
        1.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.trending_up_rounded,
                size: 15, color: kNeon),
            const SizedBox(width: 7),
            Text('tonight\'s 84 goes straight on the board',
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

/// ── 6 · BATTLE ──────────────────────────────────────────────────────
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
        final w = _word.transform(_c.value).clamp(0.0, 1.0);
        return Column(children: [
          const SizedBox(height: 8),
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
          const SizedBox(height: 26),
          Opacity(
            opacity: w,
            child: Transform.scale(
              scale: 2.0 - w,
              child: Text('VICTORY',
                  style: GoogleFonts.inter(
                    color: kNeon,
                    fontSize: 36,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0x662EE87A), blurRadius: 40)
                    ],
                  )),
            ),
          ),
          const SizedBox(height: 18),
          Opacity(
            opacity: w,
            child: Text('queue a stranger, or send a friend the code',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
          const Spacer(),
        ]);
      },
    );
  }
}

/// ── 7 · SQUAD ───────────────────────────────────────────────────────
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
    return _card(
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

/// ── 8 · THE CLOSE — everything he just watched, stacked ────────────
class _CloseVignette extends StatefulWidget {
  const _CloseVignette();
  @override
  State<_CloseVignette> createState() => _CloseVignetteState();
}

class _CloseVignetteState extends State<_CloseVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  static const _lines = [
    'Ten women who remember you',
    'Lucien in every conversation — text and live voice',
    'Every run scored out of 100',
    'Missions, streaks and a ladder that shows the climb',
    'Battles to prove it, a squad to keep you honest',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, l) in _lines.indexed)
        _Rise(
          _c,
          0.08 + i * 0.14,
          (0.28 + i * 0.14).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Icon(Icons.check_rounded,
                  size: 16, color: AppColors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          ),
        ),
      const Spacer(),
      _Rise(
        _c,
        0.85,
        1.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('The loop is waiting. Run it.',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    ]);
  }
}
