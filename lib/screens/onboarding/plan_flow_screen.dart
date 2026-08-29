import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE 60-DAY PLAN — the promise the funnel makes, finally kept.
/// ══════════════════════════════════════════════════════════════════════
///
/// THE LEAK THIS PLUGS. The story funnel ends on a button that says
/// SEE MY 60-DAY PLAN. Tap it and you got a name field, a consent box, a
/// handle, and a grid of ten strangers. The app promised a plan at the
/// emotional peak of the whole product and delivered a form. Everything
/// spent on those eleven beats leaked out of that one gap.
///
/// These four screens are the plan. They sit after the handle and before
/// the first rep, and they are written to do one job each:
///
///   1 THE TRUTH   — you are not shy, you are untrained
///   2 THE CLIMB   — how we train you: progressively harder conversations
///   3 LIVE VOICE  — and you actually SPEAK, not just type
///   4 THE GAME    — every rep measured, scored, turned into progression
///   5 THE HABIT   — keep taking reps until what made you freeze is normal
///
/// One idea has to survive the whole thing: GAME IS TRAINABLE, AND THIS
/// GIVES ME THE REPS TO TRAIN IT UNTIL IT IS NATURAL. Nothing else gets
/// sold here — not XP, not achievements, not rescues, not the coach's
/// full range. Every extra feature added to this flow dilutes the one
/// sentence it exists to leave behind.
///
/// ── WHY THE GUT PUNCH IS FAIR ───────────────────────────────────────
///
/// It isn't a trick. He is carrying two problems at once and they feed
/// each other: he is afraid, AND he was never taught. Fear stops the
/// reps, no reps means no skill, no skill justifies the fear. Naming
/// that loop out loud is a relief, not an insult — it tells him the
/// thing he thought was his personality is a rep count. And it is the
/// honest description of what the product fixes: practice kills the
/// fear, scoring builds the skill, both ends at once.
///
/// ── AND IT SAYS THE FUN PART OUT LOUD ───────────────────────────────
///
/// The second promise, carried on every screen: this is a GAME. Scores,
/// ranks, duels, a streak. Men do not sustain sixty days of
/// self-improvement — they sustain sixty days of something they enjoy
/// that happens to improve them.
///
/// Squads are the third item on the last page and a quiet secondary
/// action — never a step of their own. This flow used to end on a squad
/// pitch, which implied the product needs other men to work. It does
/// not: most users run it alone and it is fully effective alone, and
/// implying otherwise both overstates squads and loses the man who has
/// nobody to bring.
class PlanFlowScreen extends StatefulWidget {
  const PlanFlowScreen({super.key});

  @override
  State<PlanFlowScreen> createState() => _PlanFlowScreenState();
}

class _PlanFlowScreenState extends State<PlanFlowScreen> {
  final _pages = PageController();
  int _i = 0;
  static const _count = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// NAVIGATION ONLY EVER FROM A DELIBERATE PRESS. No timers, no
  /// network callbacks, nothing that can move a man off a screen he did
  /// not ask to leave. Learned the hard way.
  void _next() {
    HapticFeedback.mediumImpact();
    if (_i >= _count - 1) {
      context.go('/onboarding/first-rep');
      return;
    }
    _pages.nextPage(
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  /// The squad door, from the last page. PUSH not go, so backing out of
  /// the squad room returns him to the flow rather than dropping him
  /// somewhere with no way forward.
  Future<void> _openSquad() async {
    HapticFeedback.selectionClick();
    await context.push('/squad');
  }

  static const _ctas = [
    'I WANT THAT',
    'SHOW ME THE CLIMB',
    'WHAT ELSE?',
    'HOW DO I START?',
    'START TRAINING',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.7),
                  radius: 1.2,
                  colors: [Color(0x2EE8222A), Colors.black],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      color: i <= _i
                          ? AppColors.red
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  const _GutPunch(),
                  const _Ladder(),
                  const _Voice(),
                  const _TheGame(),
                  _Habit(onSquad: _openSquad),
                ],
              ),
            ),
            _Cta(label: _ctas[_i], onTap: _next),
          ]),
        ),
      ]),
    );
  }
}

/// Same proportions, same red, same weight as the story funnel's bar —
/// this has to read as the next beat of that film, not a new app.
class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          22, 12, 22, 16 + MediaQuery.of(context).padding.bottom * 0.4),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Material(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Text(label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 2.8,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared type, lifted from the story funnel so the film continues ───

Widget _kicker(String t) => Text(t,
        style: GoogleFonts.inter(
          color: AppColors.red,
          fontSize: 11.5,
          letterSpacing: 4,
          fontWeight: FontWeight.w800,
        ))
    .animate()
    .fadeIn(duration: 400.ms);

Widget _headline(String t, {double size = 36}) => Text(t,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: size,
          height: 1.06,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w900,
        ))
    .animate()
    .fadeIn(duration: 480.ms)
    .slideY(begin: 0.06, end: 0);

Widget _body(String t, {double size = 16, Color? color, int delayMs = 180}) =>
    Text(t,
            style: GoogleFonts.inter(
              color: color ?? Colors.white.withValues(alpha: 0.78),
              fontSize: size,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ))
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 480.ms);

Widget _pad(List<Widget> children) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

/// ── 1 · THE GUT PUNCH ───────────────────────────────────────────────
///
/// The loop, named. Short lines, hard stops. It has to be recognisable
/// enough that he thinks "that's me" before he thinks "this is an ad".
class _GutPunch extends StatelessWidget {
  const _GutPunch();

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('THE TRUTH'),
      const SizedBox(height: 18),
      _headline('It was never\nyour looks.'),
      const SizedBox(height: 20),
      _body('Every man who makes it look effortless learned it. None of '
          'them were born knowing what to say to a woman who gives him '
          'nothing back.'),
      const SizedBox(height: 26),
      // The loop, as three beats with the trap named at the end.
      _LoopLine('You freeze, so you never get the reps.', 0),
      _LoopLine('No reps, so the game never gets better.', 1),
      _LoopLine('Game never gets better, so you keep freezing.', 2),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
        ),
        child: Text(
            'You are not shy. You are untrained.\n'
            'Those are completely different problems — and only one of '
            'them is permanent.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.5,
              height: 1.5,
              fontWeight: FontWeight.w800,
            )),
      ).animate().fadeIn(delay: 1100.ms, duration: 520.ms).slideY(
          begin: 0.08, end: 0, curve: Curves.easeOutCubic),
      const SizedBox(height: 18),
      _body('Enough reps and the answer stops being something you search '
          'for. It just arrives.',
          delayMs: 1500),
      const SizedBox(height: 8),
    ]);
  }
}

class _LoopLine extends StatelessWidget {
  final String text;
  final int index;
  const _LoopLine(this.text, this.index);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: const BoxDecoration(
                color: AppColors.red, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
      ).animate().fadeIn(delay: (420 + index * 200).ms, duration: 420.ms).slideX(
          begin: -0.05, end: 0, curve: Curves.easeOut);
}

/// ── 2 · THE LADDER ──────────────────────────────────────────────────
///
/// The real roster, in real difficulty order, with the top rung named
/// and locked. This is the screen that turns "an AI chat app" into a
/// mountain with a summit on it.
class _Ladder extends StatelessWidget {
  const _Ladder();

  static const _rungs = [
    ('INTO YOU', 'Already a little into you. Easy — on purpose.', false),
    ('SWEET', 'Warm and genuine. Kill the arrogance.', false),
    ('UNPREDICTABLE', 'Scattered. Keep it fun, never deep.', false),
    ('CHAOS', 'Fast, loud, jumps topics. Keep up.', false),
    ('SOCIAL MAGNET', 'Everyone wants her. Stand out or blend in.', false),
    ('TESTING YOU', 'Smart. Testing you constantly.', false),
    ('HIGH VALUE', 'High bar, short patience. Bring substance.', true),
    ('ICE THEN FIRE', 'Starts ice cold. Warms only if you hold.', true),
    ('ICE QUEEN', 'Selective. Gives you nothing. Earn every inch.', true),
  ];

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('THE CLIMB'),
      const SizedBox(height: 18),
      _headline('From into you\nto ice queen.'),
      const SizedBox(height: 18),
      _body('Ten women. Ten completely different personalities. Each one '
          'harder than the last.'),
      const SizedBox(height: 24),
      for (final (i, (name, note, locked)) in _rungs.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: i == 0 ? AppColors.surface2 : AppColors.surface1,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: i == 0
                      ? AppColors.red.withValues(alpha: 0.55)
                      : AppColors.divider),
            ),
            child: Row(children: [
              SizedBox(
                width: 26,
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      color: i == 0 ? AppColors.red : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 2),
                      Text(note,
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          )),
                    ]),
              ),
              if (i == 0)
                Text('START HERE',
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 8.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ))
              else if (locked)
                const Icon(Icons.lock_rounded,
                    size: 14, color: AppColors.textMuted),
            ]),
          ),
        )
            .animate()
            .fadeIn(delay: (260 + i * 70).ms, duration: 380.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
      const SizedBox(height: 14),
      _body('Get comfortable with the Ice Queen and you stop panicking '
          'when someone gives you nothing back.',
          color: Colors.white, delayMs: 1100),
      const SizedBox(height: 8),
    ]);
  }
}

/// ── 3 · LIVE VOICE ──────────────────────────────────────────────────
///
/// THE BIGGEST HOOK IN THE PRODUCT, AND IT WAS A BULLET POINT.
///
/// Everyone has seen an AI that types. Almost nobody has held a phone
/// to their ear and had a woman push back on them out loud, in real
/// time, in a real voice. That is the thing that makes a man show
/// somebody else the app, and it is what the marketing will be built
/// on — so it gets a screen of its own, and the screen SHOWS the call
/// rather than describing it: a live waveform, a running timer, and
/// Lucien cutting in mid-sentence with the line.
///
/// It is also the honest reason the product costs money. Text is cheap;
/// a live voice conversation is not. Showing its worth here is what
/// makes the price feel like a price instead of a wall.
class _Voice extends StatefulWidget {
  const _Voice();
  @override
  State<_Voice> createState() => _VoiceState();
}

class _VoiceState extends State<_Voice> with SingleTickerProviderStateMixin {
  /// Never stops while the screen is up. A "live call" that is not
  /// moving is a screenshot, and a screenshot cannot sell a live call.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('LIVE VOICE'),
      const SizedBox(height: 18),
      _headline('Not typing.\nTalking.'),
      const SizedBox(height: 18),
      _body('Put the phone to your ear and actually speak. She hears the '
          'pauses, the hesitation and the confidence — and answers '
          'instantly.'),
      const SizedBox(height: 22),
      // The call, running.
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withValues(alpha: 0.12), blurRadius: 40)
          ],
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
                      alpha: 0.45 + 0.55 * _wave.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('LIVE · SERAPHINA',
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
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: AnimatedBuilder(
              animation: _wave,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 26; i++)
                    Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 7 +
                          30 *
                              (0.5 +
                                      0.5 *
                                          math.sin(_wave.value * 2 * math.pi +
                                              i * 0.8))
                                  .abs(),
                      decoration: BoxDecoration(
                        color: i % 3 == 0
                            ? AppColors.red
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.bolt_rounded, size: 15, color: AppColors.red),
              const SizedBox(width: 9),
              Expanded(
                child: Text('LUCIEN: "she went quiet on purpose — let it '
                    'sit, do not fill it"',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          ),
        ]),
      )
          .animate()
          .fadeIn(delay: 260.ms, duration: 520.ms)
          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      const SizedBox(height: 20),
      Text('Ten women. Ten different voices. Each one feels completely '
          'different to talk to.',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w600,
          )).animate().fadeIn(delay: 700.ms, duration: 480.ms),
      const SizedBox(height: 14),
      Text('Freeze? Lucien is one tap away with live coaching in your ear.',
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w800,
          )).animate().fadeIn(delay: 900.ms, duration: 480.ms),
      const SizedBox(height: 8),
    ]);
  }
}

/// ── 4 · THE GAME ────────────────────────────────────────────────────
///
/// Everything that turns practice into something he WANTS to open. The
/// order is deliberate: the score is the hook (a number he wants to
/// beat), the board makes it public, duels make it a fight, and the
/// squad is one line at the end — offered as a multiplier, never as a
/// requirement. Most men will run this alone and it works alone; saying
/// otherwise would be a lie and would scare off the man who has nobody
/// to bring.
class _TheGame extends StatelessWidget {
  const _TheGame();

  // THE REAL FIVE, same as everywhere else. Flow / Wit / Recovery /
  // Close named a rubric the user is never shown.
  static const _axes = [
    ('CONFIDENCE', 78, kNeon),
    ('PRESENCE', 71, kNeon),
    ('GAME', 34, AppColors.red),
    ('HUMOUR', 62, AppColors.signalAmber),
    ('LISTENING', 45, AppColors.signalAmber),
  ];

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('THE GAME'),
      const SizedBox(height: 18),
      _headline('Every rep\nscored out of 100.'),
      const SizedBox(height: 16),
      _body('Not a vibe. Five scores that show exactly where your game is '
          'strong — and where it breaks down.'),
      const SizedBox(height: 20),
      for (final (i, (label, v, tone)) in _axes.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(children: [
            SizedBox(
              width: 92,
              child: Text(label,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(height: 6, color: AppColors.surface2),
                  FractionallySizedBox(
                    widthFactor: v / 100,
                    child: Container(height: 6, color: tone),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: Text('$v',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    color: tone,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ]),
        )
            .animate()
            .fadeIn(delay: (240 + i * 90).ms, duration: 400.ms)
            .slideX(begin: -0.04, end: 0, curve: Curves.easeOut),
      const SizedBox(height: 6),
      Text('WIT 34. Now you know what to work on tonight.',
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w800,
          )).animate().fadeIn(delay: 760.ms, duration: 440.ms),
      const SizedBox(height: 26),
      _Feature(
        icon: Icons.leaderboard_rounded,
        title: 'THE LEADERBOARD',
        note: 'Every score you earn puts you on it. Watch your name climb '
            'past men who started before you.',
        delayMs: 880,
      ),
      _Feature(
        icon: Icons.sports_mma_rounded,
        title: 'RIZZ BATTLES',
        note: 'Duel another man on the SAME woman — both blind, better '
            'conversation wins. Send a friend the code and settle it.',
        delayMs: 1010,
      ),
      _Feature(
        icon: Icons.local_fire_department_rounded,
        title: 'MISSIONS & STREAKS',
        note: 'Daily reps with no help and no safety net. That is where the '
            'game actually hardens.',
        delayMs: 1140,
      ),
      const SizedBox(height: 4),
      Text('Every rep counts. Every score gives you something to beat next '
          'time.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w800,
          )).animate().fadeIn(delay: 1280.ms, duration: 520.ms),
      const SizedBox(height: 8),
    ]);
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String note;
  final int delayMs;
  const _Feature(
      {required this.icon,
      required this.title,
      required this.note,
      required this.delayMs});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 16, color: AppColors.red),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text(note,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 13,
                        height: 1.42,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
          ),
        ]),
      ).animate().fadeIn(delay: delayMs.ms, duration: 420.ms).slideX(
          begin: -0.04, end: 0, curve: Curves.easeOut);
}

/// ── 5 · THE HABIT ───────────────────────────────────────────────────
///
/// THE LAST PAGE SELLS THE HABIT, NOT THE SQUAD.
///
/// This slot used to be the squad pitch, and its underlying message was
/// wrong rather than merely long: it implied the product needs other
/// men to work. It does not. Most users will run this alone and it is
/// fully effective alone — saying otherwise both overstates squads and
/// loses the man who has nobody to bring.
///
/// So the final beat is the loop itself: one rep a day, watch the number
/// move, come back and beat it. Squads keep their place as the third
/// item and a quiet secondary action — an enhancement to the core
/// product, which is exactly what they are.
///
/// It also carries no new features. Coach, XP, achievements, rescues and
/// the rest do not need selling here; the flow has to leave exactly one
/// idea behind, and every extra thing dilutes it: GAME IS TRAINABLE, AND
/// THIS GIVES ME THE REPS TO TRAIN IT UNTIL IT IS NATURAL.
class _Habit extends StatelessWidget {
  final VoidCallback onSquad;
  const _Habit({required this.onSquad});

  static const _steps = [
    (
      '01',
      'ONE REP EVERY DAY',
      'Your challenge is waiting. Run it, get scored, come back tomorrow '
          'and beat it.',
    ),
    (
      '02',
      'WATCH YOUR GAME CHANGE',
      'Scores, streaks and rank make progress impossible to miss.',
    ),
    (
      '03',
      'WANT MORE PRESSURE?',
      'Bring 2–5 mates into a Squad. Same challenge, blind attempts, '
          'scores revealed side by side.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('ONE LAST THING'),
      const SizedBox(height: 18),
      _headline('Get good by\nshowing up.'),
      const SizedBox(height: 26),
      for (final (i, (num, title, note)) in _steps.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 34,
              child: Text(num,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 15,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 6),
                    Text(note,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        )),
                  ]),
            ),
          ]),
        )
            .animate()
            .fadeIn(delay: (240 + i * 180).ms, duration: 460.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
      const SizedBox(height: 4),
      // The squad door, kept open and kept quiet. Secondary by design:
      // it is the one action here that is genuinely optional.
      Center(
        child: TextButton(
          onPressed: onSquad,
          child: Text('START / JOIN A SQUAD',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w800,
              )),
        ),
      ).animate().fadeIn(delay: 900.ms, duration: 460.ms),
      const SizedBox(height: 8),
    ]);
  }
}

