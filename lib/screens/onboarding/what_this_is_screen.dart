import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';

/// ══════════════════════════════════════════════════════════════════════
///  WHAT THIS IS — the four things, before he's dropped in the deep end
/// ══════════════════════════════════════════════════════════════════════
///
/// THE PROBLEM THIS SOLVES. Onboarding ended and a man landed on a grid
/// of ten women. Nothing had told him there were squads, or battles, or
/// that the coach exists, or that the whole thing is a sixty-day climb —
/// so he used one tenth of what he'd just signed up for and judged the
/// product on that tenth.
///
/// ── FOUR CARDS, ONE VERB EACH ───────────────────────────────────────
///
/// PRACTISE · PROVE · BE HELD TO IT · FIGHT. In that order, because it
/// is the actual loop: you rehearse, you do it for real, your squad
/// checks, and when you fancy it you put it against another man.
///
/// Each card is one line of what it is and one line of why it exists.
/// Not a feature list — a feature list is what an app writes when it
/// doesn't know which of its features is the point.
///
/// ── HE CAN LEAVE AT ANY POINT ───────────────────────────────────────
///
/// SKIP is visible on every card. A man who wants to get on with it has
/// already decided to use the app, and holding him hostage to four
/// screens is how you turn a signup into an uninstall.
class WhatThisIsScreen extends StatefulWidget {
  const WhatThisIsScreen({super.key});

  @override
  State<WhatThisIsScreen> createState() => _WhatThisIsScreenState();
}

class _Card {
  final String kicker;
  final String title;
  final String body;
  final IconData icon;
  final Color tone;
  const _Card(this.kicker, this.title, this.body, this.icon, this.tone);
}

class _WhatThisIsScreenState extends State<WhatThisIsScreen> {
  final _pages = PageController();
  int _i = 0;

  static const _cards = <_Card>[
    _Card(
      'PRACTISE',
      'Ten women.\nAs often as you like.',
      'Text them or call them — the phone icon in her header takes it '
          'live. They remember you, they warm up or they don\'t, and '
          'your coach is in there with you: tap him any time and he '
          'hands you the line you were reaching for.',
      Icons.forum_rounded,
      AppColors.red,
    ),
    _Card(
      'PROVE IT',
      'Five missions.\nEvery single day.',
      'Three on the AI, two in the real world. The real ones are worth '
          'the most, because talking to a stranger on a Tuesday is the '
          'thing that actually changes you. Everything you do is scored '
          'out of a hundred.',
      Icons.bolt_rounded,
      AppColors.signalAmber,
    ),
    _Card(
      'BE HELD TO IT',
      'Two to five men.\nNobody hides.',
      'Your squad sees what you did and what you skipped. Same woman '
          'every day, everyone blind, scores side by side. When you go '
          'quiet, they can call you out — and you\'ll feel it.',
      Icons.groups_rounded,
      Color(0xFF2EE87A),
    ),
    _Card(
      'FIGHT',
      'Same woman.\nBoth blind.',
      'Queue against a stranger or send a mate a code. You both talk to '
          'her, neither of you sees the other\'s attempt, and the better '
          'conversation takes the rating. Voice or text — you pick.',
      Icons.sports_mma_rounded,
      Color(0xFF8B94F5),
    ),
  ];

  void _next() {
    HapticFeedback.selectionClick();
    if (_i >= _cards.length - 1) {
      _done();
      return;
    }
    _pages.nextPage(
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  void _done() {
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cards[_i];
    final last = _i == _cards.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // The wash takes the current card's colour, so swiping through
        // FEELS like four different rooms rather than one page with the
        // text swapped.
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.25,
                colors: [c.tone.withValues(alpha: 0.20), Colors.black],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _done,
                child: Text('SKIP',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (i) => setState(() => _i = i),
                itemCount: _cards.length,
                itemBuilder: (_, i) => _Page(card: _cards[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _cards.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _i ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _i ? c.tone : AppColors.surface3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: GameButton(
                  label: last ? 'START' : 'NEXT',
                  onTap: _next,
                  color: c.tone,
                  // Amber and green are bright enough that white text on
                  // them is unreadable — pick the ink from the paint.
                  textColor: c.tone.computeLuminance() > 0.45
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Page extends StatelessWidget {
  final _Card card;
  const _Page({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: card.tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: card.tone.withValues(alpha: 0.5)),
            ),
            child: Icon(card.icon, size: 28, color: card.tone),
          ).animate().fadeIn(duration: 340.ms).scaleXY(begin: 0.86, end: 1),
          const SizedBox(height: 26),
          Text(card.kicker,
                  style: GoogleFonts.inter(
                    color: card.tone,
                    fontSize: 12,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(delay: 100.ms, duration: 320.ms),
          const SizedBox(height: 12),
          Text(card.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.12,
                    letterSpacing: -0.9,
                    fontWeight: FontWeight.w900,
                  ))
              .animate()
              .fadeIn(delay: 180.ms, duration: 340.ms)
              .slideY(begin: 0.14, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 16),
          Text(card.body,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ))
              .animate()
              .fadeIn(delay: 300.ms, duration: 360.ms),
        ],
      ),
    );
  }
}
