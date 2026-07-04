import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Cinematic onboarding reel — the original engine: black surface, italic
/// Playfair serif, red accents. Words reveal left-to-right inside each
/// line (130ms/word), the line holds ~620ms, then the next line drops in.
/// One line on screen at a time — never stacked. No images.
///
/// Progress dashes track the 8 story beats (screens); the finale reveals
/// BEGIN.
class IntroReelScreen extends StatefulWidget {
  /// Route to advance to when the user taps BEGIN or SKIP.
  final String next;
  const IntroReelScreen({super.key, this.next = '/onboarding/gender'});

  @override
  State<IntroReelScreen> createState() => _IntroReelScreenState();
}

class _IntroReelScreenState extends State<IntroReelScreen> {
  int _i = 0;
  Timer? _t;

  static const _wordMs   = 130;   // gap between word reveals
  static const _wordFade = 320;   // each word fades in over this long
  static const _holdMs   = 620;   // line sits for this long after last word
  static const _gapMs    = 260;   // extra breath when [_Line.bigBreath]

  // Number of story beats — drives the progress dashes.
  static const _screenCount = 8;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _queueNext();
  }

  void _queueNext() {
    if (_i >= _lines.length - 1) return;
    final line = _lines[_i];
    final words = line.words.length;
    final lifetimeMs = (words - 1) * _wordMs + _wordFade + _holdMs
        + (line.bigBreath ? _gapMs : 0);
    _t?.cancel();
    _t = Timer(Duration(milliseconds: lifetimeMs), () {
      if (!mounted) return;
      setState(() => _i++);
      _queueNext();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _go() {
    HapticFeedback.mediumImpact();
    context.go(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_i];
    final isLast = _i == _lines.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Faint red halo behind the copy.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      AppColors.red.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // SKIP — top right.
            Positioned(
              top: 8, right: 14,
              child: GestureDetector(
                onTap: _go,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('SKIP',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11, letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                    )),
                ),
              ),
            ),

            // Centred line — words reveal in sequence, one line at a time.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve:  Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _SentenceView(
                    key:      ValueKey(_i),
                    line:     line,
                    wordMs:   _wordMs,
                    wordFade: _wordFade,
                  ),
                ),
              ),
            ),

            // BEGIN — only on the last line.
            if (isLast)
              Positioned(
                bottom: 56, left: 28, right: 28,
                child: _BeginButton(onTap: _go)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 900.ms)
                    .slideY(begin: 0.18, end: 0, duration: 400.ms,
                        delay: 900.ms, curve: Curves.easeOut),
              ),

            // Progress dashes — one per story beat (screen).
            Positioned(
              bottom: 22, left: 0, right: 0,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var s = 0; s < _screenCount; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width:  s == line.screen ? 16 : 5,
                          height: 3,
                          decoration: BoxDecoration(
                            color: s <= line.screen
                                ? AppColors.red
                                : AppColors.surface3,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single line. Words fade + rise in sequence, left to right.
class _SentenceView extends StatelessWidget {
  final _Line line;
  final int wordMs;
  final int wordFade;
  const _SentenceView({
    super.key,
    required this.line,
    required this.wordMs,
    required this.wordFade,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        for (var i = 0; i < line.words.length; i++)
          _Word(
            text:   line.words[i],
            color:  line.colorFor(i),
            size:   line.size,
            italic: line.italicFor(i),
            weight: line.weightFor(i),
            delayMs: i * wordMs,
            fadeMs:  wordFade,
          ),
      ],
    );
  }
}

class _Word extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final bool italic;
  final FontWeight weight;
  final int delayMs;
  final int fadeMs;
  const _Word({
    required this.text,
    required this.color,
    required this.size,
    required this.italic,
    required this.weight,
    required this.delayMs,
    required this.fadeMs,
  });

  @override
  Widget build(BuildContext context) {
    return Text(text,
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        color: color,
        fontSize: size,
        height: 1.12,
        letterSpacing: -0.8,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: weight,
      ),
    )
        .animate()
        .fadeIn(
          duration: Duration(milliseconds: fadeMs),
          delay:    Duration(milliseconds: delayMs),
          curve:    Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.22, end: 0,
          duration: Duration(milliseconds: fadeMs),
          delay:    Duration(milliseconds: delayMs),
          curve:    Curves.easeOutCubic,
        );
  }
}

class _BeginButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BeginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.45),
                blurRadius: 36, spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('BEGIN',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15, letterSpacing: 4.2,
                  fontWeight: FontWeight.w900,
                )),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line + its styling. [words] reveal one by one. [screen] is the
/// story-beat index (0-7) so the progress dashes track which of the 8
/// screens we're on.
class _Line {
  final List<String> words;
  final int screen;
  final double size;
  final bool italic;
  /// Word indices that render in brand red.
  final List<int> redIndices;
  /// Word indices that render bold non-italic (LOOKS / GAME / ImHim).
  final List<int> boldIndices;
  /// Extra breath after lines that end a thought.
  final bool bigBreath;

  const _Line(
    this.words, {
    required this.screen,
    this.size = 32,
    this.italic = true,
    this.redIndices  = const [],
    this.boldIndices = const [],
    this.bigBreath   = false,
  });

  Color colorFor(int i) =>
      redIndices.contains(i) ? AppColors.red : Colors.white;

  bool italicFor(int i) =>
      boldIndices.contains(i) ? false : italic;

  FontWeight weightFor(int i) =>
      boldIndices.contains(i) ? FontWeight.w900 : FontWeight.w700;
}

// Sizes tuned per line so every sentence fits clean: short punchy lines
// run big, longer sentences step down so they never overflow.
const _lines = <_Line>[
  // ── SCREEN 1 · THE PAIN
  _Line(['Every', 'man', 'knows', 'that', 'feeling…'],
      screen: 0, size: 36),
  _Line(['Watching', 'another', 'guy', 'become', 'the', 'man', 'you',
      'always', 'wanted', 'to', 'be.'],
      screen: 0, size: 27, bigBreath: true),

  // ── SCREEN 2 · THE WOUND
  _Line(['You', 'tell', 'yourself', 'it', 'doesn\'t', 'matter…'],
      screen: 1, size: 32),
  _Line(['But', 'every', 'rejection', 'makes', 'you', 'question',
      'yourself', 'a', 'little', 'more.'],
      screen: 1, size: 27, bigBreath: true),

  // ── SCREEN 3 · THE SPIRAL
  _Line(['Eventually…'], screen: 2, size: 42),
  _Line(['You', 'stop', 'wondering', 'why', 'she', 'didn\'t', 'choose',
      'you…'],
      screen: 2, size: 29),
  _Line(['…and', 'start', 'believing', 'nobody', 'ever', 'will.'],
      screen: 2, size: 31, redIndices: [3, 4, 5], bigBreath: true),

  // ── SCREEN 4 · THE REVEAL
  _Line(['What', 'if', 'you\'ve', 'been', 'fighting', 'with', 'half',
      'the', 'system?'],
      screen: 3, size: 28),
  _Line(['👤', 'Looks', 'get', 'you', 'noticed.'],
      screen: 3, size: 34, boldIndices: [1]),
  _Line(['💬', 'Game', 'gets', 'you', 'chosen.'],
      screen: 3, size: 34, redIndices: [1], boldIndices: [1]),
  _Line(['Master', 'both…', 'and', 'everything', 'changes.'],
      screen: 3, size: 32, redIndices: [3, 4], bigBreath: true),

  // ── SCREEN 5 · LOOKS
  _Line(['Imagine', 'walking', 'into', 'a', 'room…'],
      screen: 4, size: 34),
  _Line(['…and', 'being', 'the', 'guy', 'everyone', 'notices.'],
      screen: 4, size: 31),
  _Line(['See', 'your', 'future', 'glow-up.'],
      screen: 4, size: 35),
  _Line(['Know', 'exactly', 'what', 'to', 'improve.'],
      screen: 4, size: 32),
  _Line(['Then', 'become', 'him.'],
      screen: 4, size: 44, redIndices: [2], bigBreath: true),

  // ── SCREEN 6 · GAME
  _Line(['Imagine', 'never', 'freezing', 'again.'],
      screen: 5, size: 36),
  _Line(['Walk', 'over.'], screen: 5, size: 44),
  _Line(['Start', 'the', 'conversation.'], screen: 5, size: 38),
  _Line(['Flirt', 'naturally.'], screen: 5, size: 44),
  _Line(['Lead', 'with', 'confidence.'], screen: 5, size: 38),
  _Line(['Until', 'the', 'man', 'you', 'always', 'wanted', 'to', 'be…',
      'becomes', 'who', 'you', 'are.'],
      screen: 5, size: 26, bigBreath: true),

  // ── SCREEN 7 · BECOME HIM
  _Line(['Imagine', 'becoming', 'unforgettable.'],
      screen: 6, size: 37),
  _Line(['The', 'guy', 'she', 'notices.'],
      screen: 6, size: 35, redIndices: [3]),
  _Line(['The', 'guy', 'she', 'remembers.'],
      screen: 6, size: 35, redIndices: [3]),
  _Line(['The', 'guy', 'she', 'chooses.'],
      screen: 6, size: 40, redIndices: [3], bigBreath: true),

  // ── SCREEN 8 · CLOSE
  _Line(['The', 'next', 'time', 'someone', 'asks…'],
      screen: 7, size: 32),
  _Line(['"How', 'did', 'you', 'change', 'so', 'much?"'],
      screen: 7, size: 33),
  _Line(['You\'ll', 'know', 'the', 'answer.'],
      screen: 7, size: 37, bigBreath: true),
  _Line(['Welcome', 'to', 'ImHim.'],
      screen: 7, size: 46, redIndices: [2], boldIndices: [2]),
];
