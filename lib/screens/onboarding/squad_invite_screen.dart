import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/squad_chrome.dart';

/// THE SQUAD PITCH — one page, straight after he picks his name.
///
/// WHY IT'S ITS OWN PAGE AND NOT BOLTED TO THE USERNAME SCREEN:
/// that screen asks one question and gets a high completion rate because
/// of it. Two call-to-actions on one screen doesn't get you both — it
/// gets you fewer of each, and the one people drop is whichever they
/// understand least. A squad is the thing he understands least at this
/// exact moment, so it needs the page to itself.
///
/// WHY IT'S HERE AT ALL, RATHER THAN LATER:
/// he has to know squads EXIST before he starts, or the feature may as
/// well not ship — nobody goes looking in a menu for a social layer they
/// were never told about. But he has no score, no streak and nothing to
/// be accountable for yet, so this page sells the IDEA and makes
/// skipping completely painless. The hard ask comes later, at the moment
/// it actually lands: right after his first scored run, when he has a
/// number and "send this to someone who'll try to beat it" is a real
/// sentence rather than a favour.
///
/// The three points are the three real reasons, in the order they
/// persuade: the honest one (you'll quit alone), the fun one (beat your
/// mates), and the objection-killer (this isn't another feed).
class SquadInviteScreen extends StatefulWidget {
  const SquadInviteScreen({super.key});

  @override
  State<SquadInviteScreen> createState() => _SquadInviteScreenState();
}

class _SquadInviteScreenState extends State<SquadInviteScreen> {
  /// SET THE MOMENT HE MOVES, AND CHECKED BY EVERY ASYNC PATH.
  ///
  /// This is the bug that made the reel flash and vanish. initState
  /// fires a network call to ask whether he already has a squad. On a
  /// slow connection that call is still in the air when he taps through
  /// — and `mounted` is still true for the frame or two before this
  /// route is torn down, so the late reply won its race and sent him
  /// home over the top of the screen he had just opened. The reel got
  /// one frame and then the network answered a question nobody was
  /// asking any more.
  ///
  /// `mounted` cannot catch this on its own: it answers "is this widget
  /// alive", and the widget IS alive during the handover. The question
  /// that matters is "has he already gone somewhere", which only this
  /// screen can know.
  bool _left = false;

  // NO AUTO-NAVIGATION. EVER. This screen used to fire a network call
  // in initState asking "does he already have a squad?" and warp to
  // home when the answer was yes. That call races the user's own taps,
  // and it kept winning: the reply landed a beat after he had moved
  // on, and yanked him off whatever screen he had just opened — the
  // tour got one frame and vanished. Guards shrank the window; nothing
  // closes it, because the answer can always arrive at a bad time.
  //
  // So the rule is absolute now: a screen in the onboarding chain may
  // only navigate from a deliberate user gesture. A man who already
  // has a squad taps through one extra page once in his life — that
  // costs him two seconds. The race cost the whole flow.

  /// PUSH, NOT GO. `go` replaces the whole stack, so the squad room
  /// opened from onboarding had nothing behind it and the back gesture
  /// died — a dead end in the one flow a new man cannot escape. Pushing
  /// keeps this page underneath, and finishing lands him home.
  Future<void> _openSquad(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await context.push('/squad');
    if (!mounted || _left) return;
    // Came back with a squad → onboarding is done. Came back without one
    // → he's still on the pitch, which is where he should be.
    if (await SquadService.mySquad() != null && mounted && !_left) {
      _left = true;
      context.go('/onboarding/plan');
    }
  }

  /// Into the 60-DAY PLAN, not home. The story funnel's last button
  /// promised a plan and the app used to answer it with a name field and
  /// a grid of strangers; this is where that promise finally gets kept.
  void _finish(BuildContext context) {
    if (_left) return;
    _left = true;
    HapticFeedback.mediumImpact();
    context.go('/onboarding/plan');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(children: [
        const Positioned.fill(child: SquadAtmosphere(accent: AppColors.red)),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            children: [
              const SizedBox(height: 20),
              Center(
                child: const SquadCrest(
                        name: 'YOU', accent: AppColors.red, size: 92)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1.0, end: 1.04, duration: 1800.ms),
              ),
              const SizedBox(height: 26),
              Text('ONE LAST THING',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 9.5,
                    letterSpacing: 3.4,
                    fontWeight: FontWeight.w900,
                  )).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 10),
              Text('NOBODY CHANGES\nALONE.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        height: 1.02,
                        letterSpacing: -1.6,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18)
                        ],
                      ))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOut),
              const SizedBox(height: 26),

              const _Point(
                n: '01',
                title: 'On your own, you\'ll skip it',
                body: 'Everyone does. Tuesday comes, you don\'t feel like '
                    'it, nobody notices. A man who knows someone will see '
                    'the empty square does it anyway.',
              ),
              const _Point(
                n: '02',
                title: 'Same woman. Both blind.',
                body: 'You and your mates get the identical challenge every '
                    'day, run it without seeing each other\'s attempt, then '
                    'the scores land side by side. That\'s the whole game.',
              ),
              const _Point(
                n: '03',
                title: 'Two to five men. Not a feed.',
                body: 'Private, no strangers, no likes, nothing to scroll. '
                    'Just who showed up today and who didn\'t.',
              ),

              const SizedBox(height: 24),
              _Cta(
                label: 'START A SQUAD',
                filled: true,
                onTap: () => _openSquad(context),
              ),
              const SizedBox(height: 11),
              _Cta(
                label: 'I\'VE GOT A CODE',
                filled: false,
                onTap: () => _openSquad(context),
              ),
              const SizedBox(height: 18),
              // A real skip, not a dark pattern. A man pushed into a squad
              // he didn't want is a man who ignores it — and the mechanic
              // only works if he actually cares who's watching.
              Center(
                child: TextButton(
                  onPressed: () => _finish(context),
                  child: Text('Not now — I\'ll do it after my first run',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Point extends StatelessWidget {
  final String n, title, body;
  const _Point({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.red.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
          ),
          child: Text(n,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15.5,
                    height: 1.2,
                    letterSpacing: -0.3,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 5),
              Text(body,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ]),
    ).animate().fadeIn(delay: (120 * int.parse(n)).ms, duration: 380.ms);
  }
}

class _Cta extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Cta(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.red : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.14)),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.4),
                      blurRadius: 24)
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: filled ? Colors.white : AppColors.textSecondary,
              fontSize: 13.5,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }
}
