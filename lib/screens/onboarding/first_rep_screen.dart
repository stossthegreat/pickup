import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/chat_score_service.dart';
import '../../services/local_store_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/rizz_off_reveal.dart';
import '../roleplay/girl_chat_screen.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE FIRST REP — the last screen before the app stops talking.
/// ══════════════════════════════════════════════════════════════════════
///
/// Everything up to here has been the app making a case. This is where
/// it shuts up and hands him the thing. Sofia — rung one, INTO YOU, the
/// woman he just saw lit at the bottom of the ladder — is already
/// waiting with her opener.
///
/// FIVE MESSAGES, NOT AN OPEN CHAT. A cap makes it a rep instead of a
/// demo: it ends on a score rather than trailing off when he gets bored,
/// and a score is the thing that converts. taskMode gives him the
/// progress bar and the scorecard for free — this is the real practice
/// surface, not a mock-up of it, which is the whole point.
///
/// WHY A HOLDING SCREEN AT ALL. Dropping a man straight into a chat
/// from a marketing beat is jarring — he needs one breath to understand
/// that the pitch is over and this is now HIM. One line of framing, one
/// button, then it is a conversation.
class FirstRepScreen extends StatefulWidget {
  const FirstRepScreen({super.key});

  @override
  State<FirstRepScreen> createState() => _FirstRepScreenState();
}

class _FirstRepScreenState extends State<FirstRepScreen> {
  /// Re-entry guard only: one tap opens one rep, and NOT RIGHT NOW
  /// stops working the moment the rep is under way.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    LocalStoreService.setOnbStep('/onboarding/first-rep');
  }

  Future<void> _start(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    final g = girlById('into_you');
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: g.id,
            vibeKey: g.vibeKey,
            name: g.name,
            archetype: g.archetype,
            portraitAsset: g.asset,
            accent: g.accent,
            opener: g.opener,
            // A REP, NOT A DEMO. taskMode gives the completion bar and
            // the real ending.
            taskMode: true,
            taskGoal: 5,
            scoreSurface: 'first_rep',
            // ASK LUCIEN, ON. This defaults to FALSE and the first build
            // of this screen never set it — so the one beat the whole
            // funnel promises ("stuck? tap Lucien") was missing from the
            // only place it had to appear.
            coachAllowed: true,
            // This screen owns the ending: the /100 with the five axes,
            // not the girl-verdict ceremony. A man being sold on the
            // score has to actually SEE a score.
            verdictOnFinish: false,
            // THE REP MUST REACH ITS SCORE. Five messages against a
            // three-message allowance meant the paywall landed on
            // message four, mid-conversation — the funnel closing on a
            // man who was interrupted instead of convinced. Exempt at
            // the call site only; the gate itself is untouched.
            bypassTextCap: true,
          ),
        ),
      ),
    );
    if (!mounted) return;

    // ── SHOW HIM THE NUMBER ───────────────────────────────────────────
    //
    // The grade is fired without await from the chat's teardown, so the
    // result is often still in the air the instant this screen comes
    // back. Reading it now and shrugging is how a man who ran the whole
    // rep gets no score — the single most valuable screen in the funnel,
    // lost to a race. So we wait for the parked future, capped, and only
    // then give up.
    var r = ChatScoreService.lastResult;
    if (r == null && ChatScoreService.grading != null) {
      // No setState — nothing on this screen renders off _busy, and a
      // rebuild while a route is mid-transition buys only risk.
      try {
        await ChatScoreService.grading!.timeout(const Duration(seconds: 20));
      } catch (_) {/* slow or dead network — fall through to the price */}
      r = ChatScoreService.lastResult;
    }
    if (!mounted) return;

    if (r != null) {
      ChatScoreService.lastResult = null;
      // A FINAL binding before the closure. `r` is reassignable (the
      // wait above rewrites it), and Dart refuses to null-promote an
      // assigned local inside a closure — so r.score in the dialog's
      // pageBuilder would be a compile error, not a runtime one. This
      // exact trap failed an iOS archive earlier in the week.
      final res = r;
      final g = girlById('into_you');
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.black,
        barrierDismissible: false,
        barrierLabel: 'first-rep',
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => RizzOffReveal(
          score: res.score,
          // The grade bands are cut against the 0..9999 rubric, so the
          // 0..100 chat score is put back on that band for the LETTER
          // only. The number on screen stays out of 100.
          gradeScore: (res.score * 99.99).round(),
          rubric: res.rubric,
          rankToday: 0,
          worldAvg: res.average,
          girlName: g.name,
          girlAccent: g.accent,
          divisor: 1,
          decimals: 0,
          suffix: '/ 100',
          kicker: 'YOUR FIRST REP',
          // THE FIVE BARS THAT ALL READ ZERO.
          //
          // RizzOffReveal defaults to the VOICE axes. This is a TEXT
          // score, graded on a different five entirely, so without
          // these the reveal looked up confidence/flow/wit/recovery/
          // close, found none of them, and animated five bars to 0 —
          // then showed him a real number out of 100 underneath. On the
          // first rep in onboarding, which is the screen the whole
          // funnel is built to reach.
          axes: kChatAxes,
          axisLabels: kChatAxisLabels,
        ),
        transitionBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      );
    }
    if (!mounted) return;
    // THE REP NOW COMES AFTER THE PRICE, NOT BEFORE IT.
    //
    // It used to end here at the paywall — the rep was the free sample
    // and the score was the pitch. The funnel is inverted now: the
    // seven-beat story sells, he pays to find out his number, and this
    // screen is the first thing he gets for the money. So it ends at
    // home, with his score behind him.
    // Now the account. He has a score, and "claim it" is a far better
    // reason to sign in than "sign in to continue" ever was.
    context.go('/onboarding/consent');
  }

  /// THE WAY OUT, AND IT STILL ENDS AT THE PRICE.
  ///
  /// Forcing the rep is the design — a man who has done it converts far
  /// better than a man who has been told about it. But a screen with no
  /// exit at all is a trap, and a trapped man does not buy, he uninstalls
  /// and leaves one star. This is deliberately quiet, deliberately not a
  /// button, and it goes exactly where the rep goes.
  void _skip() {
    if (_busy) return;
    HapticFeedback.selectionClick();
    // He has already paid by the time he sees this. Skipping the test
    // must not send him back to a price he has settled.
    // Now the account. He has a score, and "claim it" is a far better
    // reason to sign in than "sign in to continue" ever was.
    context.go('/onboarding/consent');
  }

  @override
  Widget build(BuildContext context) {
    final g = girlById('into_you');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 1.1,
                  colors: [g.accent.withValues(alpha: 0.22), Colors.black],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            child: Column(children: [
              const Spacer(flex: 2),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: g.accent.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: g.accent.withValues(alpha: 0.35),
                        blurRadius: 40)
                  ],
                  image: DecorationImage(
                      image: AssetImage(g.asset), fit: BoxFit.cover),
                ),
              )
                  .animate()
                  .fadeIn(duration: 520.ms)
                  .scaleXY(begin: 0.86, end: 1, curve: Curves.easeOutBack),
              const SizedBox(height: 26),
              Text('RUNG ONE · ${g.type}',
                      style: GoogleFonts.inter(
                        color: g.accent,
                        fontSize: 11,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 420.ms),
              const SizedBox(height: 14),
              Text('${g.name} is\nalready typing.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.08,
                        letterSpacing: -0.8,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(delay: 320.ms, duration: 480.ms)
                  .slideY(begin: 0.06, end: 0),
              const SizedBox(height: 16),
              Text('Five messages. She is into you already, so this is the '
                      'easy one — and you still get scored on it.\n\n'
                      'Stuck? Tap Lucien. He will hand you the line.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 15.5,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ))
                  .animate()
                  .fadeIn(delay: 480.ms, duration: 480.ms),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: Material(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => _start(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Center(
                      child: Text('REPLY TO HER',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 2.8,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 420.ms),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _skip,
                child: Text('NOT RIGHT NOW',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w800,
                    )),
              ).animate().fadeIn(delay: 1100.ms, duration: 420.ms),
            ]),
          ),
        ),
      ]),
    );
  }
}
