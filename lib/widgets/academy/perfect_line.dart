import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backend/tiers.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';
// ImpactShake lives with the grade stamp, not with the button — the
// screen-strike is part of the reveal vocabulary, not the control set.
import 'grade_stamp.dart';

/// PERFECT LINE — the jackpot.
///
/// Every other reward in this app is scheduled. He knows a verdict comes
/// at the end of a conversation, he knows the chain banks at quorum, he
/// knows the reel spins when he opens the daily. Scheduled rewards
/// build habits; they do not build the thing that makes someone open an
/// app for no reason. That needs a reward he cannot see coming.
///
/// So: one line, mid-conversation, out of nowhere. He typed a sentence,
/// hit send, expected her reply — and instead the screen takes over and
/// tells him that sentence was perfect.
///
/// THE RULES THAT KEEP IT A JACKPOT:
///   · It must be RARE. Once per conversation and once per day, hard.
///     A jackpot that pays twice in an evening is a participation
///     trophy, and there is no way back from that.
///   · It must be EARNED, not rolled. The bar is a genuinely
///     exceptional line as graded by the same model that grades
///     everything else. Faking the trigger would be the one lie in this
///     app men could actually detect — they'd notice it firing on
///     rubbish, and then every real one is worthless too.
///   · It must be SHORT. Under four seconds. An interrupt that outstays
///     its welcome trains him to dread the thing it's rewarding.
///
/// The line he wrote is the hero of the screen. Not a score, not a
/// grade — his own sentence, in the biggest type in the app.
class PerfectLine {
  /// The delta at which a single line counts as perfect. The backend
  /// hands back roughly -10..+10, `strong` is its own flag, and the
  /// conjunction of both is deliberately hard to hit.
  static const bar = 9.0;

  static const _kDay = 'perfect.day.v1';

  static int _today() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  /// Has today's already gone? Checked before the animation so a second
  /// perfect line in one evening simply passes silently — she still
  /// reacts in the chat, he just doesn't get the fanfare twice.
  static Future<bool> availableToday() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_kDay) ?? 0) != _today();
  }

  static Future<void> spend() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDay, _today());
  }

  /// Fire it. Returns when he's dismissed it.
  static Future<void> show(
    BuildContext context, {
    required String line,
    required String girlName,
    required Color accent,
  }) async {
    await spend();
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      barrierLabel: 'perfect',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) =>
          _PerfectAct(line: line, girlName: girlName, accent: accent),
    );
  }
}

class _PerfectAct extends StatefulWidget {
  final String line;
  final String girlName;
  final Color accent;
  const _PerfectAct({
    required this.line,
    required this.girlName,
    required this.accent,
  });

  @override
  State<_PerfectAct> createState() => _PerfectActState();
}

class _PerfectActState extends State<_PerfectAct> {
  final _shakeKey = GlobalKey<ImpactShakeState>();
  final _timers = <Timer>[];
  bool _out = false;

  @override
  void initState() {
    super.initState();
    void at(int ms, VoidCallback fn) =>
        _timers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) fn();
        }));
    // Hits immediately and hard. There is no hold here on purpose — the
    // hold belongs to a verdict he's waiting for, and the whole value of
    // this one is that he wasn't.
    Feel.best();
    Sfx.personalBest();
    at(60, () => _shakeKey.currentState?.shake());
    at(1500, () {
      if (mounted) setState(() => _out = true);
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(child: Burst(color: kNeon, pieces: 60)),
        // A hot core behind the words so the screen reads as struck
        // rather than as a dialog that opened.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kNeon.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                  radius: 0.9,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: ImpactShake(
            key: _shakeKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
              child: Column(children: [
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.bolt_rounded, size: 20, color: kNeon),
                  const SizedBox(width: 9),
                  Text('PERFECT LINE',
                      style: GoogleFonts.inter(
                        color: kNeon,
                        fontSize: 15,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: kNeon.withValues(alpha: 0.7),
                              blurRadius: 26)
                        ],
                      )),
                ])
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .scale(
                        begin: const Offset(1.5, 1.5),
                        end: const Offset(1, 1),
                        duration: 340.ms,
                        curve: Curves.easeOutBack),
                const SizedBox(height: 34),

                // HIS SENTENCE. The biggest type in the app, and the
                // only place in it where the hero of the screen is
                // something the user wrote rather than something we
                // scored.
                Text('"${widget.line}"',
                        textAlign: TextAlign.center,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: widget.line.length > 90 ? 22 : 29,
                          height: 1.28,
                          letterSpacing: -0.8,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: kNeon.withValues(alpha: 0.35),
                                blurRadius: 40)
                          ],
                        ))
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 380.ms)
                    .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 26),
                Text('${widget.girlName.toUpperCase()} DIDN\'T SEE THAT COMING',
                        style: GoogleFonts.inter(
                          color: widget.accent,
                          fontSize: 10,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w900,
                        ))
                    .animate()
                    .fadeIn(delay: 620.ms),
                const Spacer(),

                if (_out)
                  Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        label: 'KEEP GOING',
                        color: kNeon,
                        textColor: Colors.black,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        Feel.tick();
                        Share.share(
                            'Perfect line on ImHim Rizz:\n\n'
                            '"${widget.line}"\n\n'
                            '${widget.girlName} didn\'t see it coming.');
                      },
                      child: Text('SHARE IT',
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ]).animate().fadeIn(duration: 280.ms),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
