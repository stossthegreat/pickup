import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  WHAT THIS IS — six title cards. Black, white, red. Nothing else.
/// ══════════════════════════════════════════════════════════════════════
///
/// THE PROBLEM. Onboarding ended and a man landed on a grid of ten
/// women. Nothing had told him there were squads, or duels, or that the
/// coach exists — so he used a tenth of what he'd signed up for and
/// judged the product on that tenth.
///
/// ── WHAT THE FIRST ATTEMPT GOT WRONG, SO IT ISN'T REPEATED ──────────
///
/// Four cards, each with a kicker, a two-line headline, a paragraph AND
/// a payoff line — sixty words — held for five seconds. Unreadable. Then
/// four different accent colours across four cards, which turned a black
/// app with one red into a colour swatch. Every fault came from the same
/// instinct: saying more, and dressing it up.
///
/// ── SO: ONE THOUGHT A FRAME, AND ONE COLOUR ─────────────────────────
///
/// A tag, a headline of one or two words, and a single line under it.
/// Nine words a frame. The headline does the work and everything else
/// gets out of its way — which is the only reason a word can land at
/// all, because a word only hits hard when it is the loudest thing on
/// the screen.
///
/// Black, white, and the app's red. A brand is what you refuse to add.
///
/// ── AND TIME TO ACTUALLY READ IT ────────────────────────────────────
///
/// Nine words held for 4.2 seconds, with everything on screen by 900ms.
/// Three clear seconds of reading on every frame, against sixty words in
/// five seconds before. Tap right to move on if that's still slow, left
/// to go back, hold to pause.
class WhatThisIsScreen extends StatefulWidget {
  const WhatThisIsScreen({super.key});

  @override
  State<WhatThisIsScreen> createState() => _WhatThisIsScreenState();
}

class _Frame {
  final String tag;
  final String head;
  final String line;
  const _Frame(this.tag, this.head, this.line);
}

class _WhatThisIsScreenState extends State<WhatThisIsScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _i = 0;

  /// One clock drives the bar fill AND the page turn, so the bar can
  /// never disagree with when the frame actually changes.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _advance();
    });

  /// HEADLINES STAY SHORT ON PURPOSE. The tag says which part of the app
  /// it is, so the headline never has to name it — it only has to hit.
  /// Short also keeps every frame's type at the same size, and six
  /// headlines set at six different sizes reads as a bug.
  static const _frames = <_Frame>[
    _Frame('PRACTICE', 'TALK',
        'Ten women. Voice or text. They remember you.'),
    _Frame('YOUR COACH', 'LUCIEN',
        'Stuck mid-sentence? Tap him. He hands you the line.'),
    _Frame('MISSIONS', 'FIVE A DAY',
        'Three on the AI. Two in the real world.'),
    _Frame('THE VERDICT', 'SCORED',
        'Out of 100. What landed, what flopped, every run.'),
    _Frame('YOUR SQUAD', 'NO HIDING',
        'Two to five men. They see what you skipped.'),
    _Frame('RIZZ BATTLES', 'FIGHT',
        'Same woman. Both blind. Better conversation wins.'),
  ];

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

  /// The clock ran out by itself — turn the page, and on the last frame
  /// do nothing at all.
  ///
  /// It plays through and STOPS, with START waiting. The last frame is
  /// the one he's most likely to still be reading, and a screen that
  /// ejects a man because a timer expired is an ad he can't pause.
  /// Never navigating from here also means nothing can tear this widget
  /// — and _clock with it — down from inside _clock's own notification.
  void _advance() {
    if (_i >= _frames.length - 1) return;
    _pages.nextPage(
        duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  /// A deliberate tap is a different thing: he's asked to move on, so on
  /// the last frame that means into the app.
  void _next() {
    HapticFeedback.selectionClick();
    if (_i >= _frames.length - 1) {
      _done();
      return;
    }
    _advance();
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_i == 0) {
      _clock.forward(from: 0); // replay — a dead tap reads as a dead screen
      return;
    }
    _pages.previousPage(
        duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  bool _leaving = false;

  void _done() {
    if (!mounted || _leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  void _onPage(int i) {
    setState(() => _i = i);
    _clock.forward(from: 0); // every frame gets its full beat
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _frames.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ONE red light, low and to the left, sitting under the type.
        // Static. The previous version had a coloured gradient orbiting
        // the screen, which is motion for its own sake — it pulls the
        // eye away from the only thing that matters, which is the word.
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.7, 0.45),
                  radius: 1.0,
                  colors: [Color(0x33E8222A), Colors.black],
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // ── The bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                for (var i = 0; i < _frames.length; i++)
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

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(children: [
                Text('${(_i + 1).toString().padLeft(2, '0')} / '
                    '${_frames.length.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                TextButton(
                  onPressed: _done,
                  child: Text('SKIP',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ]),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: _onPage,
                itemCount: _frames.length,
                // The tap handler lives INSIDE the page. A layer behind
                // a PageView never receives a tap — a Scrollable is
                // opaque to hit tests and swallows them before anything
                // under it is asked. Swipes still work; the drag
                // recognizer takes those and leaves taps alone.
                itemBuilder: (_, i) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) =>
                      d.localPosition.dx < MediaQuery.sizeOf(context).width / 3
                          ? _back()
                          : _next(),
                  onLongPressStart: (_) => _clock.stop(),
                  onLongPressEnd: (_) => _clock.forward(),
                  child: _FrameView(frame: _frames[i]),
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
                      child: Text('START',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            letterSpacing: 4,
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

/// A bar segment. Repaints off the shared clock, so the fill and the
/// page turn are the same event rather than two things kept in step.
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

/// One frame. Anchored LOW and left, the way a film title is — centred
/// text floats and reads as a splash screen. Everything is on screen by
/// 900ms so the rest of the beat is his to read in.
class _FrameView extends StatelessWidget {
  final _Frame frame;
  const _FrameView({required this.frame});

  @override
  Widget build(BuildContext context) {
    // The headline is the whole design, so it takes whatever width the
    // phone has. Small phones get 44, large ones 60.
    final w = MediaQuery.sizeOf(context).width;
    final headSize = (w * 0.145).clamp(40.0, 62.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(frame.tag,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11,
                    letterSpacing: 4.5,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.25, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 14),

          // MASK REVEAL, NOT A FADE. The word starts fully below its own
          // clip and is wiped upward into place — it arrives from
          // somewhere with weight behind it. A fade is a word gradually
          // becoming visible, which is the opposite of landing.
          //
          // FittedBox is the safety net, not the plan: the headlines are
          // written short enough to fit at full size on a normal phone,
          // and this only bites on a very narrow screen or a large
          // accessibility text scale. Without it those cases are a
          // yellow-and-black overflow stripe across the best thing on
          // the page. ClipRect sits INSIDE it so the mask is measured
          // against the text, not against the scaled-down result.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ClipRect(
                child: Text(frame.head,
                        maxLines: 1,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: headSize,
                          height: 1.0,
                          letterSpacing: -2.2,
                          fontWeight: FontWeight.w900,
                        ))
                    .animate()
                    .slideY(
                        begin: 1,
                        end: 0,
                        duration: 480.ms,
                        curve: Curves.easeOutCubic)
                    .fadeIn(duration: 200.ms),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Container(height: 2, width: 46, color: AppColors.red)
              .animate()
              .fadeIn(delay: 380.ms, duration: 160.ms)
              .scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft),

          const SizedBox(height: 18),

          Text(frame.line,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 17,
                    height: 1.5,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w600,
                  ))
              .animate()
              .fadeIn(delay: 480.ms, duration: 380.ms)
              .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
