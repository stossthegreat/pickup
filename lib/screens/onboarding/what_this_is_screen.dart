import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  WHAT THIS IS — the reel. Four rooms, ninety seconds, then he's in.
/// ══════════════════════════════════════════════════════════════════════
///
/// THE PROBLEM THIS SOLVES. Onboarding ended and a man landed on a grid
/// of ten women. Nothing had told him there were squads, or battles, or
/// that the coach exists, or that the whole thing is a sixty-day climb —
/// so he used one tenth of what he'd just signed up for and judged the
/// product on that tenth.
///
/// ── IT PLAYS. IT IS NOT A FORM ──────────────────────────────────────
///
/// The first version was four cards with a NEXT button, which is a
/// slideshow, and nobody has ever been sold anything by a slideshow.
/// This one runs on its own like a story: a segmented bar fills across
/// the top, each card holds for its own beat, and it moves whether he
/// touches it or not. He can drive it if he wants — tap the right side
/// to skip ahead, the left to go back, hold anywhere to pause — but
/// doing nothing is a valid way to watch it, which is the entire
/// difference between a reel and a wizard.
///
/// ── ONE ROOM PER CARD ───────────────────────────────────────────────
///
/// PRACTISE · PROVE IT · BE HELD TO IT · FIGHT, in the order of the
/// actual loop: you rehearse, you do it for real, your squad checks, and
/// when you fancy it you put it against another man.
///
/// Each card owns a colour, and everything on screen takes it — the
/// wash behind, the drifting light, the giant ghost numeral, the rule,
/// the bar. Swiping doesn't change the text on a page, it changes the
/// room you're standing in. That's what makes four screens feel like one
/// film instead of four forms.
///
/// ── HE CAN LEAVE AT ANY POINT ───────────────────────────────────────
///
/// SKIP is on every frame. A man who wants to get on with it has already
/// decided to use the app, and holding him hostage to four screens is
/// how you turn a signup into an uninstall.
class WhatThisIsScreen extends StatefulWidget {
  const WhatThisIsScreen({super.key});

  @override
  State<WhatThisIsScreen> createState() => _WhatThisIsScreenState();
}

class _Card {
  final String kicker;
  final String title;
  final String body;
  final String proof;
  final IconData icon;
  final Color tone;
  const _Card(this.kicker, this.title, this.body, this.proof, this.icon,
      this.tone);
}

class _WhatThisIsScreenState extends State<WhatThisIsScreen>
    with TickerProviderStateMixin {
  final _pages = PageController();
  int _i = 0;

  /// Drives the segment fill AND the auto-advance — one clock, so the
  /// bar can never disagree with when the page actually turns.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _hold,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _advance();
    });

  /// Never stops — the slow light behind everything, which is most of
  /// why the screen reads as filmed rather than laid out.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 11),
  )..repeat();

  static const _hold = Duration(milliseconds: 5200);

  static const _cards = <_Card>[
    _Card(
      'PRACTISE',
      'Ten women.\nAs often as you like.',
      'Text them or call them for real — her header has a phone icon and '
          'it goes live. They remember you. They warm up, or they don\'t.',
      'Your coach sits in every conversation. Tap him and he hands you '
          'the line you were reaching for.',
      Icons.forum_rounded,
      AppColors.red,
    ),
    _Card(
      'PROVE IT',
      'Five missions.\nEvery single day.',
      'Three on the AI. Two out there. The real ones pay the most, '
          'because talking to a stranger on a Tuesday is the thing that '
          'actually changes you.',
      'Everything you do comes back scored out of a hundred, with what '
          'landed and what didn\'t.',
      Icons.bolt_rounded,
      AppColors.signalAmber,
    ),
    _Card(
      'BE HELD TO IT',
      'Two to five men.\nNobody hides.',
      'Your squad sees what you did and what you skipped. Same woman '
          'every day, everyone blind, scores side by side.',
      'Go quiet and they can call you out in front of everyone. You will '
          'feel it. That is the point.',
      Icons.groups_rounded,
      Color(0xFF2EE87A),
    ),
    _Card(
      'FIGHT',
      'Same woman.\nBoth blind.',
      'Queue against a stranger or send a mate a code. You both talk to '
          'her. Neither of you sees the other\'s attempt.',
      'The better conversation takes it. Voice or text — you pick your '
          'weapon.',
      Icons.sports_mma_rounded,
      Color(0xFF8B94F5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    _drift.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// THE CLOCK RAN OUT ON ITS OWN — so this turns the page, and on the
  /// last frame it does nothing at all.
  ///
  /// The reel plays itself through all four rooms and then STOPS, with
  /// START sitting there waiting. It deliberately does not walk him out
  /// of the door: the last card is the one he is most likely to still
  /// be reading, and a screen that ejects a man mid-sentence because a
  /// timer expired is the same rudeness as an ad he cannot pause.
  ///
  /// Doing nothing here also means the automatic path never navigates,
  /// so nothing can tear this widget — and _clock with it — down from
  /// inside _clock's own status notification.
  void _advance() {
    if (_i >= _cards.length - 1) return;
    _pages.nextPage(
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  /// A DELIBERATE TAP, which is a different thing. He has asked to move
  /// on, so on the last card that means into the app.
  void _next() {
    HapticFeedback.selectionClick();
    if (_i >= _cards.length - 1) {
      _done();
      return;
    }
    _advance();
  }

  void _back() {
    if (_i == 0) {
      // Restart the beat rather than sit there doing nothing — a tap
      // that produces no response reads as a dead screen.
      _clock.forward(from: 0);
      return;
    }
    HapticFeedback.selectionClick();
    _pages.previousPage(
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  /// Guarded because there are three ways out — SKIP, START, and a tap
  /// on the last frame — and two of them can land in the same frame.
  bool _leaving = false;

  void _done() {
    if (!mounted || _leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  void _onPage(int i) {
    setState(() => _i = i);
    _clock.forward(from: 0); // every room gets its full beat
  }

  @override
  Widget build(BuildContext context) {
    final c = _cards[_i];
    final last = _i == _cards.length - 1;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── THE ROOM ────────────────────────────────────────────────
        // Two washes, not one: a fixed pool of colour high on the
        // screen, and a second one orbiting slowly underneath it. The
        // orbit is what stops a still page from looking still.
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.62),
                radius: 1.15,
                colors: [c.tone.withValues(alpha: 0.26), Colors.black],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (_, __) {
                final t = _drift.value * 2 * math.pi;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(math.cos(t) * 0.7, math.sin(t) * 0.5),
                      radius: 0.85,
                      colors: [
                        c.tone.withValues(alpha: 0.13),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ── THE GHOST NUMERAL ───────────────────────────────────────
        // Enormous, barely there, and it tells him how far through he
        // is without a word. Sits behind everything.
        Positioned(
          right: -size.width * 0.14,
          bottom: size.height * 0.20,
          child: IgnorePointer(
            child: Text('${_i + 1}',
                style: GoogleFonts.inter(
                  color: c.tone.withValues(alpha: 0.075),
                  fontSize: size.width * 0.92,
                  height: 0.8,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // ── THE BAR ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                for (var i = 0; i < _cards.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: _Segment(
                        tone: c.tone,
                        // Past segments are full, future ones empty, and
                        // the current one is the clock made visible.
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
                itemCount: _cards.length,
                // ── DRIVE IT BY HAND ────────────────────────────────
                //
                // Left third goes back, the rest goes on, hold pauses.
                // This has to sit INSIDE the page rather than as a
                // layer behind the PageView: a Scrollable is opaque to
                // hit tests, so it swallows every tap before anything
                // underneath it in the Stack is ever asked. Swipes
                // still work — the drag recognizer takes those and
                // leaves the taps alone.
                itemBuilder: (_, i) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) =>
                      d.localPosition.dx < MediaQuery.sizeOf(context).width / 3
                          ? _back()
                          : _next(),
                  onLongPressStart: (_) => _clock.stop(),
                  onLongPressEnd: (_) => _clock.forward(),
                  child: _Page(card: _cards[i]),
                ),
              ),
            ),

            // ── THE WAY OUT ─────────────────────────────────────────
            // Only on the last frame. Before that the reel is running
            // and a button under it is just something to press instead
            // of watching.
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
              child: AnimatedOpacity(
                opacity: last ? 1 : 0,
                duration: const Duration(milliseconds: 360),
                child: IgnorePointer(
                  ignoring: !last,
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _done,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.tone,
                        foregroundColor:
                            c.tone.computeLuminance() > 0.45
                                ? Colors.black
                                : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('START',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            letterSpacing: 3,
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

/// One bar segment. Repaints off the shared clock, so the fill and the
/// page turn are the same event rather than two things kept in step.
class _Segment extends StatelessWidget {
  final Animation<double> progress;
  final Color tone;
  const _Segment({required this.progress, required this.tone});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 2.5,
          child: Stack(children: [
            Positioned.fill(
                child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.16))),
            AnimatedBuilder(
              animation: progress,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.value.clamp(0.0, 1.0),
                child: ColoredBox(color: tone),
              ),
            ),
          ]),
        ),
      );
}

/// One room. Everything enters on a stagger — icon, kicker, headline,
/// rule, body, then the proof line — so the eye is walked down the page
/// instead of being handed a block of text.
class _Page extends StatelessWidget {
  final _Card card;
  const _Page({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: card.tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: card.tone.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                    color: card.tone.withValues(alpha: 0.28), blurRadius: 26),
              ],
            ),
            child: Icon(card.icon, size: 27, color: card.tone),
          )
              .animate()
              .fadeIn(duration: 380.ms)
              .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack),

          const SizedBox(height: 24),
          Text(card.kicker,
                  style: GoogleFonts.inter(
                    color: card.tone,
                    fontSize: 11.5,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(delay: 120.ms, duration: 340.ms)
              .slideX(begin: -0.12, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 12),
          Text(card.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.08,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(delay: 220.ms, duration: 380.ms)
              .slideY(begin: 0.16, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 20),
          // The rule draws itself. Small thing, and it is the moment the
          // page stops feeling like it loaded and starts feeling like it
          // is being written.
          Container(height: 2, width: 54, color: card.tone)
              .animate()
              .fadeIn(delay: 420.ms, duration: 200.ms)
              .scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft),

          const SizedBox(height: 18),
          Text(card.body,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 15,
                    height: 1.58,
                    fontWeight: FontWeight.w500,
                  ))
              .animate()
              .fadeIn(delay: 520.ms, duration: 400.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 16),
          // THE PAYOFF LINE, tinted and set apart. Every card keeps one
          // sentence back and lands it a beat late — the bit he should
          // still remember on the home screen.
          Text(card.proof,
                  style: GoogleFonts.inter(
                    color: card.tone.withValues(alpha: 0.95),
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ))
              .animate()
              .fadeIn(delay: 900.ms, duration: 460.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
