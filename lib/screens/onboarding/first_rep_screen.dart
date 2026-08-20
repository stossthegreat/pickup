import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/roster.dart';
import '../../theme/app_colors.dart';
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
class FirstRepScreen extends StatelessWidget {
  const FirstRepScreen({super.key});

  Future<void> _start(BuildContext context) async {
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
            // ends on the real scorecard — the number is what turns a
            // man from evaluating an app into owning a result.
            taskMode: true,
            taskGoal: 5,
            scoreSurface: 'first_rep',
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    // Scored or bailed, the funnel ends the same way: at the price. A
    // man who quit his first rep after two lines is not a man to send
    // to a home screen he has no reason to open again.
    context.go('/paywall');
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
            ]),
          ),
        ),
      ]),
    );
  }
}
