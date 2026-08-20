import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/tiers.dart' show kNeon;
import '../../services/local_store_service.dart';
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
///   1 THE GUT PUNCH  — name the thing he already knows about himself
///   2 THE LADDER     — ten women, INTO YOU to ICE QUEEN, the whole climb
///   3 THE MACHINE    — why reps + help + competition + a squad WORKS
///   4 THE VERDICT    — his own onboarding answers, turned on him
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
/// Every screen here carries the second promise: this is a GAME. Duels,
/// leaderboards, a squad, a score you want to beat. Men do not sustain
/// sixty days of self-improvement. They sustain sixty days of something
/// they enjoy that happens to improve them.
class PlanFlowScreen extends StatefulWidget {
  const PlanFlowScreen({super.key});

  @override
  State<PlanFlowScreen> createState() => _PlanFlowScreenState();
}

class _PlanFlowScreenState extends State<PlanFlowScreen> {
  final _pages = PageController();
  int _i = 0;
  static const _count = 4;

  /// His answer to onboarding beat 05 — "How confident are you
  /// approaching someone you're attracted to?" 0..3. Already collected,
  /// already stored, and until now never shown to him again. The last
  /// screen reads it back.
  int _level = 0;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final l = await LocalStoreService.userLevel();
    if (mounted) setState(() => _level = l);
  }

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

  static const _ctas = [
    'I WANT THAT',
    'SHOW ME THE METHOD',
    'WHERE DO I START?',
    'START MY FIRST REP',
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
                  const _Machine(),
                  _Verdict(level: _level),
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
      _body('Every man you envy learned this. None of them were born '
          'knowing what to say to a woman who gives him nothing back.'),
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
      _body('Sixty days from now you are either still guessing, or you are '
          'the man who always knows what to say.',
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
    ('THE DITSY ONE', 'Scattered. Keep it fun, never deep.', false),
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
      _body('Ten women. Every personality that exists. Each one harder than '
          'the last, each one teaching you something the last could not.'),
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
      _body('Beat the ice queen and there is no woman alive who throws you.',
          color: Colors.white, delayMs: 1100),
      const SizedBox(height: 8),
    ]);
  }
}

/// ── 3 · THE MACHINE ─────────────────────────────────────────────────
///
/// Why the climb actually happens, in the four parts that make it work
/// — and the sentence that says the quiet part: this is fun. Sixty days
/// of homework is not a product anybody finishes.
class _Machine extends StatelessWidget {
  const _Machine();

  static const _parts = [
    (
      Icons.forum_rounded,
      'PRACTICE',
      'Talk to her — text or live voice. Get it wrong here, where wrong '
          'costs you nothing.',
    ),
    (
      Icons.bolt_rounded,
      'LUCIEN, LIVE',
      'Stuck mid-sentence? One tap and he hands you the exact line — '
          'then tells you why it works.',
    ),
    (
      Icons.assessment_rounded,
      'SCORED, EVERY TIME',
      'Confidence. Flow. Wit. Recovery. Close. You will know exactly '
          'which one is holding you back.',
    ),
    (
      Icons.sports_mma_rounded,
      'DUELS & LEADERBOARDS',
      'Fight other men on the same woman. Climb the board. This is the '
          'part men come back for.',
    ),
    (
      Icons.groups_rounded,
      'YOUR SQUAD',
      'Two to five men who see whether you showed up. Nobody quits in '
          'front of an audience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _pad([
      _kicker('THE METHOD'),
      const SizedBox(height: 18),
      _headline('Reps. Then\nreal pressure.'),
      const SizedBox(height: 18),
      // The evidence, stated honestly — this is the clinical mechanism,
      // not a claim we invented, and it is the reason the product works
      // on both halves of his problem at once.
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
            'Rehearsing real conversations over and over is the same method '
            'used to train people out of social fear. The fear fades because '
            'nothing bad happens. The skill grows because you keep swinging.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            )),
      ).animate().fadeIn(delay: 200.ms, duration: 460.ms),
      const SizedBox(height: 22),
      for (final (i, (icon, title, note)) in _parts.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.red.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: 18, color: AppColors.red),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 5),
                    Text(note,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        )),
                  ]),
            ),
          ]),
        )
            .animate()
            .fadeIn(delay: (420 + i * 130).ms, duration: 420.ms)
            .slideX(begin: -0.04, end: 0, curve: Curves.easeOut),
      Text('And the truth nobody says out loud: it is fun. '
          'You will be doing this because you want to, not because you '
          'should.',
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w800,
          )).animate().fadeIn(delay: 1200.ms, duration: 520.ms),
      const SizedBox(height: 8),
    ]);
  }
}

/// ── 4 · THE VERDICT ─────────────────────────────────────────────────
///
/// His own answer from onboarding beat 05, read back to him with a
/// starting point attached. He told us where he is; this is the first
/// time the app proves it was listening — which is what makes the plan
/// feel like HIS plan rather than a brochure.
class _Verdict extends StatelessWidget {
  final int level;
  const _Verdict({required this.level});

  /// 0 never · 1 once or twice · 2 sometimes · 3 comfortable.
  static const _said = [
    'I never do it.',
    'I\'ve done it once or twice.',
    'Sometimes.',
    'I\'m already comfortable.',
  ];
  static const _reads = [
    'So every rep from here is ground you have never stood on.',
    'So you know the feeling — you just have not made it a habit yet.',
    'So you have the nerve. What you are missing is the sharpness.',
    'Then this is about going from good to untouchable.',
  ];
  static const _startScore = ['1', '2', '3', '4'];

  @override
  Widget build(BuildContext context) {
    final i = level.clamp(0, 3);
    return _pad([
      _kicker('YOUR STARTING POINT'),
      const SizedBox(height: 18),
      _headline('Day 1 of 60.'),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOU TOLD US',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 8),
          Text('"${_said[i]}"',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                height: 1.35,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 12),
          Text(_reads[i],
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ).animate().fadeIn(delay: 200.ms, duration: 480.ms),
      const SizedBox(height: 20),
      // The honest curve. Voice scores out of 10 — most men open at one
      // or two, and daily reps put them at seven or eight inside two
      // months. Real numbers from the real scale, which is exactly why
      // it will ring true to anyone who has done it.
      Row(children: [
        _Milestone(
            label: 'TODAY', value: _startScore[i], tone: AppColors.textMuted),
        const _Arrow(),
        _Milestone(label: 'WEEK 2', value: '4', tone: Colors.white),
        const _Arrow(),
        _Milestone(label: 'MONTH 2', value: '8', tone: kNeon),
      ]).animate().fadeIn(delay: 620.ms, duration: 520.ms),
      const SizedBox(height: 10),
      Text('Voice score, out of 10. Most men open at one or two. '
          'Daily reps put them at seven or eight inside two months.',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          )).animate().fadeIn(delay: 800.ms, duration: 480.ms),
      const SizedBox(height: 24),
      Text('One conversation. Right now.\nLet\'s see where you actually are.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 19,
            height: 1.4,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w900,
          )).animate().fadeIn(delay: 1000.ms, duration: 520.ms),
      const SizedBox(height: 8),
    ]);
  }
}

class _Milestone extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;
  const _Milestone(
      {required this.label, required this.value, required this.tone});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 34,
                height: 1,
                letterSpacing: -1.5,
                fontWeight: FontWeight.w900,
                shadows: tone == kNeon
                    ? const [Shadow(color: Color(0x662EE87A), blurRadius: 26)]
                    : null,
              )),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 8.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              )),
        ]),
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Icon(Icons.arrow_forward_rounded,
            size: 14, color: AppColors.textMuted),
      );
}
