import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/achievements.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/ascend_reveal.dart';

/// THE FEAR BUTTON — for the exact second training has to become
/// behaviour. He's frozen. He knows what he should do. This screen
/// exists to get him through the next ten seconds.
///
/// Design law for this moment: ZERO latency, zero decisions, zero AI
/// round-trips. Everything is local and instant — a spinner here would
/// kill the entire feature. One instruction. One line. One countdown.
/// GO.
///
/// Flow: opener line + "READY" → 10-second countdown with rising
/// haptics → GO → honest debrief (SAID IT / NOT THIS TIME). Both
/// debrief paths are respectful — the rep was showing up at all.
class FearButtonScreen extends StatefulWidget {
  const FearButtonScreen({super.key});

  @override
  State<FearButtonScreen> createState() => _FearButtonScreenState();
}

enum _Phase { armed, counting, go, debrief, done }

class _FearButtonScreenState extends State<FearButtonScreen> {
  // Openers — respectful, situational, in HIS voice. The move is always
  // honesty about the moment, never a routine. Rotates per open.
  static const _lines = [
    "Hey — total stranger moment, but I'd have kicked myself "
        "if I didn't say hi. I'm …",
    "Hi. I've got about ten seconds of courage here, so — "
        "I'm …. What's your name?",
    "Hey — I noticed you and figured the worst that happens "
        "is a short story. I'm …",
    "Excuse me — you seem like the most interesting person "
        "in here. Had to find out. I'm …",
    "Hi — I promised myself I'd stop letting these moments "
        "pass. I'm …. How's your day actually going?",
    "Hey, quick one before I talk myself out of it — I'm …. "
        "What are you drinking?",
    "Hi — my day gets better or this gets awkward, and I'm "
        "fine with both. I'm …",
    "Hey. No line. I just wanted to meet you. I'm …",
  ];


  // ── WHY HE HASN'T MOVED ─────────────────────────────────────────────
  //
  // The screen used to open with "Shoulders back. Breathe out slow." —
  // body-language advice for a problem that isn't in the body. A man
  // standing there with his phone out is not under-oxygenated. He's
  // running a specific piece of reasoning, and until that reasoning is
  // named and taken apart he will keep standing there.
  //
  // So each of these is a REAL reason men don't approach, said out loud,
  // followed by the thing that dismantles it. Not encouragement —
  // encouragement is what he's already given himself six times in the
  // last ten minutes and it didn't move him. An argument might.
  //
  // Rotates per open, paired with a fresh opener, so the button never
  // says the same thing twice in a row to the same man.
  static const _truths = <(String, String)>[
    ("You're not scared of her.\nYou're scared of being watched trying.",
        'Nobody in this room will remember by the time they\'re in the car. '
        'You will remember it for years. That is the whole trade.'),
    ('While you haven\'t asked,\nshe might have said yes.',
        'That\'s what you\'re protecting. A maybe that isn\'t real. It is '
        'worth nothing and it is costing you everything.'),
    ('You\'re not scared of a no.\nYou\'re scared of what it means.',
        'It means nothing. One person, one mood, one Tuesday. It is not a '
        'verdict on you and it never was.'),
    ('The scene in your head\ndoesn\'t happen.',
        'The laugh, the friends turning round — that isn\'t how it goes. '
        'What happens is a short, polite answer and you walk. Every time.'),
    ('Doing nothing feels free\nbecause the bill comes later.',
        'You have paid it a hundred times already and called it a normal '
        'night. This is the cheaper option.'),
    ('You don\'t need a better line.',
        'You have had a good enough line for twenty minutes. What you are '
        'doing now is called waiting, and it does not end on its own.'),
    ('She forgets you in four minutes.',
        'You would have carried this one for four years. That asymmetry is '
        'the only argument you need.'),
    ('Every man you\'d swap places with\nhas been told no more than you.',
        'More times than you have opened your mouth. That is the entire '
        'difference between you and him. Not looks. Reps.'),
  ];

  late final (String, String) _truth;

  late final String _line;
  _Phase _phase = _Phase.armed;
  int _count = 10;
  Timer? _timer;
  bool _saidIt = false;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _line = _lines[r.nextInt(_lines.length)];
    _truth = _truths[r.nextInt(_truths.length)];
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.counting;
      _count = 10;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_count <= 1) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _Phase.go);
        // GO holds the screen for a beat, then asks the only question
        // that matters. He's walking (or he isn't) — either way the
        // phone goes in the pocket.
        Timer(const Duration(seconds: 6), () {
          if (mounted && _phase == _Phase.go) {
            setState(() => _phase = _Phase.debrief);
          }
        });
      } else {
        // Rising urgency — soft ticks early, hard from 3.
        if (_count <= 4) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.selectionClick();
        }
        setState(() => _count--);
      }
    });
  }

  Future<void> _answer(bool saidIt) async {
    HapticFeedback.mediumImpact();
    _saidIt = saidIt;
    if (saidIt) {
      // Count the rep — fuel for a future "fear reps" surface.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fear_reps', (prefs.getInt('fear_reps') ?? 0) + 1);

      // THE BIGGEST HOLE IN THE WHOLE APP WAS HERE.
      //
      // A man walked up to a stranger in real life — the hardest thing
      // this product ever asks of anyone, and the thing every AI
      // conversation in here is practice FOR — and the app incremented
      // a private counter and gave him nothing. No XP, no badge, no
      // ceremony. He got more for ticking a box on the missions tab.
      //
      // It now pays the largest single grant in the economy (see
      // rewards.dart) and drives the one badge family that measures
      // what the product actually promises.
      await Rewards.realApproach();
      MilestoneService.pushTrophies(
          await Achievements.bump(Stat.approaches));
    }
    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _phase == _Phase.go ? AppColors.red : AppColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: switch (_phase) {
            _Phase.armed => _armed(),
            _Phase.counting => _counting(),
            _Phase.go => _go(),
            _Phase.debrief => _debrief(),
            _Phase.done => _done(),
          },
        ),
      ),
    );
  }

  // ── ARMED — the line + READY ──────────────────────────────────────
  Widget _armed() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded,
              size: 22, color: Colors.white),
        ),
      ),
      const Spacer(),
      Text("YOU'RE BOTTLING IT.",
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 13,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w900,
          )).animate().fadeIn(duration: 250.ms),
      const SizedBox(height: 16),
      // THE REASON, named.
      Text(_truth.$1,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.9,
            fontWeight: FontWeight.w900,
          )).animate().fadeIn(delay: 150.ms, duration: 350.ms),
      const SizedBox(height: 12),
      // And the thing that takes it apart.
      Text(_truth.$2,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          )).animate().fadeIn(delay: 320.ms, duration: 400.ms),
      const SizedBox(height: 22),
      Row(children: [
        Text('SAY THIS',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 9,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
              height: 1, color: AppColors.red.withValues(alpha: 0.28)),
        ),
      ]).animate().fadeIn(delay: 440.ms),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: AppColors.red.withValues(alpha: 0.5)),
          boxShadow: const [
            BoxShadow(color: AppColors.redGlow, blurRadius: 30),
          ],
        ),
        child: Text('“$_line”',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 19,
              height: 1.45,
              fontWeight: FontWeight.w600,
            )),
      ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
      const SizedBox(height: 12),
      Text('Your words beat these words. This is just the door.',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          )).animate().fadeIn(delay: 500.ms),
      const Spacer(),
      SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
          ),
          child: Text('START THE COUNT',
              style: GoogleFonts.inter(
                fontSize: 15,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
        ),
      ).animate().fadeIn(delay: 600.ms),
      const SizedBox(height: 10),
      Text('10 seconds. Then you walk.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
    ]);
  }

  // ── COUNTING — the ten seconds ────────────────────────────────────
  Widget _counting() {
    return Column(children: [
      const Spacer(),
      Text('WALK ON ZERO.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          )),
      Expanded(
        flex: 3,
        child: Center(
          child: Text('$_count',
              key: ValueKey(_count),
              style: GoogleFonts.inter(
                color: _count <= 3 ? AppColors.red : Colors.white,
                fontSize: 200,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: AppColors.red
                          .withValues(alpha: _count <= 3 ? 0.7 : 0.3),
                      blurRadius: 80),
                ],
              )).animate(key: ValueKey('c$_count')).scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(1, 1),
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
        ),
      ),
      Text('“$_line”',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          )),
      const Spacer(),
    ]);
  }

  // ── GO ────────────────────────────────────────────────────────────
  Widget _go() {
    return Column(children: [
      const Spacer(),
      Text('GO.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 140,
            height: 1,
            letterSpacing: -4,
            fontWeight: FontWeight.w900,
          )).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 300.ms,
            curve: Curves.easeOutBack,
          ),
      const SizedBox(height: 14),
      Text('PHONE IN POCKET. WALK.',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          )),
      const Spacer(),
    ]);
  }

  // ── DEBRIEF — the only question ───────────────────────────────────
  Widget _debrief() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Text('DID YOU SAY IT?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 34,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 30),
      SizedBox(
        height: 60,
        child: ElevatedButton(
          onPressed: () => _answer(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('SAID IT',
              style: GoogleFonts.inter(
                fontSize: 15,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 60,
        child: OutlinedButton(
          onPressed: () => _answer(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('NOT THIS TIME',
              style: GoogleFonts.inter(
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              )),
        ),
      ),
      const Spacer(),
    ]);
  }

  // ── DONE — both answers end with respect ──────────────────────────
  Widget _done() {
    final (head, sub) = _saidIt
        ? (
            'THAT\'S THE REP.',
            'That ten seconds is the whole skill. '
                'Everything else is practice.'
          )
        : (
            'YOU SHOWED UP.',
            'Opening this screen WAS a rep. The next '
                'moment will come — and you\'ll be one rep readier.'
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Spacer(),
      Text(head,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: _saidIt ? const Color(0xFF2EE87A) : AppColors.textPrimary,
            fontSize: 34,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w900,
            shadows: _saidIt
                ? [
                    Shadow(
                        color: const Color(0xFF2EE87A)
                            .withValues(alpha: 0.5),
                        blurRadius: 40)
                  ]
                : null,
          )).animate().scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: 350.ms,
            curve: Curves.easeOutBack,
          ),
      const SizedBox(height: 14),
      Text(sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          )),
      const Spacer(),
      SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed: () async {
            HapticFeedback.selectionClick();
            // The ceremony plays HERE, not the instant he taps the
            // answer — this screen's own words ("THAT'S THE REP") are
            // the point of the moment and a medal landing on top of
            // them would step on it. He reads it, then he's paid.
            await AscendReveal.settle(context);
            if (context.mounted) context.pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface2,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('BACK TO IT',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              )),
        ),
      ),
    ]);
  }
}
