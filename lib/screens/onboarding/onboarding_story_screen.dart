import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/analytics_service.dart';
import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// ImHim onboarding — a cinematic 10-beat funnel. Full-bleed portrait art
/// melts into black under editorial serif headlines; question beats sit on
/// a red-black bloom. The segmented progress pins to the top and the CTA
/// pins to the bottom as Column siblings — the button can never overlap
/// content, and every beat is scroll-safe on any screen.
class OnboardingStoryScreen extends StatefulWidget {
  const OnboardingStoryScreen({super.key});

  @override
  State<OnboardingStoryScreen> createState() => _OnboardingStoryScreenState();
}

class _OnboardingStoryScreenState extends State<OnboardingStoryScreen> {
  final _pc = PageController();
  int _page = 0;
  final Map<int, int> _answers = {};

  late final List<_Beat> _beats = _buildBeats();
  int get _count => _beats.length;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    LocalStoreService.setOnbStep('/onboarding/story');
    // ignore: discarded_futures
    AnalyticsService.onbStarted();
    // ignore: discarded_futures
    AnalyticsService.onbStoryBeat(0);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _count - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutCubic);
    } else {
      // THE CLOSE, ONE STEP LONGER. The beats end on "what do I
      // score?", and the answer is a microphone he has to reach for.
      // The voice test screen puts her, the scoreboard and the record
      // ring in front of him; pressing it is the intent, and the price
      // is what answers it. Nothing before that button is the free
      // sample — the test IS what he is buying.
      context.go('/onboarding/voice-test');
    }
  }

  void _back() {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    _pc.previousPage(
        duration: const Duration(milliseconds: 340), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beat = _beats[_page];
    final isQuestion = beat is _QuestionBeat;
    final answered = _answers[_page] != null;
    final canContinue = !isQuestion || answered;
    final label = (isQuestion && !answered) ? 'PICK ONE TO CONTINUE' : beat.cta;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Per-beat background bleeds full-screen (behind the notch + CTA).
          Positioned.fill(child: _Background(beat: beat)),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopChrome(
                    page: _page,
                    count: _count,
                    onBack: _page == 0 ? null : _back),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() => _page = i);
                      // ignore: discarded_futures
                      AnalyticsService.onbStoryBeat(i);
                    },
                    itemCount: _count,
                    itemBuilder: (_, i) => _BeatView(
                      key: ValueKey(i),
                      beat: _beats[i],
                      selected: _answers[i],
                      onPick: (opt) {
                        HapticFeedback.selectionClick();
                        setState(() => _answers[i] = opt);
                        // The "Your Level" answer sets where missions start.
                        final b = _beats[i];
                        if (b is _QuestionBeat && b.kicker.contains('YOUR LEVEL')) {
                          // ignore: discarded_futures
                          LocalStoreService.setUserLevel(opt);
                        }
                      },
                    ),
                  ),
                ),
                _CtaBar(label: label, enabled: canContinue, onTap: _next),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── The 10 beats ──────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  //  SEVEN BEATS. No test, no paywall until the end.
  //
  //  The old flow was eleven beats of persuasion, then a SECOND
  //  five-page sell, then the rep — seventeen screens of being told
  //  before one screen of being shown. This replaces all of it.
  //
  //  The job of these seven is exactly four things, in order: he has
  //  this problem, it is trainable, this is how ImHim trains it, and it
  //  can measure him. Then voice (he cannot fake it), then progression,
  //  then the transformation.
  //
  //  He arrives at the paywall with ONE unresolved question — what do I
  //  score? — which is the entire close. Nothing before the paywall
  //  answers it, which is why there is no free test any more.
  // ══════════════════════════════════════════════════════════════════
  List<_Beat> _buildBeats() => const [
        // 01 — THE HOOK. Names the problem in his words, then reframes
        // it as trainable in the same breath.
        _HeroBeat(
          headline: 'You don\'t need better\nlines. You need\nbetter game.',
          body: 'When it matters, you hesitate. You think of the right '
              'thing afterwards. You play it safe instead of saying what '
              'you actually mean.\n\n'
              'Game isn\'t something you\'re born with. It\'s something '
              'you train.',
          cta: 'SHOW ME HOW',
        ),

        // 02 — THE DIAGNOSIS. The hardest screen in the funnel: it
        // names the LOOP rather than the feeling, so the way out reads
        // as mechanical rather than motivational. "Untrained, not shy"
        // is the whole product thesis in five words.
        _DiagnosisBeat(
          headline: 'It was never\nyour looks.',
          body: 'Every man you envy learned this. None of them were born '
              'knowing what to say to a woman who gives him nothing back.',
          loop: [
            'You freeze, so you never get the reps.',
            'No reps, so the game never gets better.',
            'Game never gets better, so you keep freezing.',
          ],
          verdict: 'You are not shy. You are untrained. Those are '
              'completely different problems — and only one of them '
              'is permanent.',
          closer: 'Sixty days from now you are either still guessing, or '
              'you are the man who always knows what to say.',
          cta: 'I WANT THAT',
        ),

        // 03 — THE REFRAME.
        _StatementBeat(
          kicker: '01 — THE REFRAME',
          headline: 'This isn\'t your\npersonality.\nIt\'s a skill.',
          body: 'Nobody gets confident by thinking about being confident. '
              'They get there through reps.\n\n'
              'The more situations you\'ve handled before, the less there '
              'is to freeze over.',
        ),

        // 04 — THE SYSTEM. Not "conversation → score → feedback →
        // repeat", which is what the old copy said and undersold by a
        // mile. Four stages with four DIFFERENT jobs — and the one that
        // was missing entirely is TRAIN WITH HELP. Telling a man he is
        // weak on wit is a diagnosis; sitting with him while he fixes it
        // is the product, and the funnel never mentioned it.
        //
        // The order is also the order he lives it: tested, coached,
        // tested again without the coach, then ranked.
        _LoopBeat(
          kicker: '02 — THE SYSTEM',
          headline: 'Test. Train.\nRep. Level up.',
          steps: [
            ('GET TESTED', 'Find out exactly where your game stands '
                'across five key skills.'),
            ('TRAIN WITH HELP', 'Practice real conversations. Get '
                'coaching, suggested answers and feedback whenever you '
                'need it.'),
            ('DO YOUR REPS', 'Put what you\'ve learned to the test — '
                'without help — in AI challenges and real-world '
                'missions.'),
            ('LEVEL UP', 'Get scored, beat your Game Score, build XP '
                'and climb the ranks.'),
          ],
          cta: 'HOW AM I SCORED?',
        ),

        // 05 — THE SCORE. The axes are shown with their values HIDDEN.
        // A filled-in example would answer the question we want him
        // carrying to the paywall.
        //
        // THESE ARE THE REAL FIVE. They are the dimensions the voice
        // grader actually returns, the five on the Progress tab and the
        // five on the share card — so the number he is promised here is
        // the number he is given, on the same axes, for the next sixty
        // days. The old list (Flow / Wit / Recovery / Close) named a
        // rubric he never sees, on a screen whose entire job is to make
        // the score feel real.
        _ScoreBeat(
          kicker: '03 — THE MEASURE',
          headline: 'Five parts of\nyour game.\nOne score.',
          axes: ['CONFIDENCE', 'PRESENCE', 'GAME', 'HUMOUR', 'LISTENING'],
          footerTitle: 'What\'s costing you points?',
          footer: 'Your first test finds the weakest part of your game and '
              'gives you something specific to train.',
          cta: 'FIND MY WEAKNESS',
        ),

        // 05 — VOICE. The differentiator, and the reason the score is
        // honest: typing lets him draft, talking does not.
        _VoiceBeat(
          kicker: '04 — LIVE VOICE',
          headline: 'Typing gives you\ntime. Talking\ndoesn\'t.',
          body: 'Talk to her in real time. She hears the pauses. The '
              'hesitation. The confidence. The moment you lose your '
              'flow.\n\nAnd she responds immediately.',
          footer: 'This is where you find out how good your game actually is.',
          cta: 'I WANT MY SCORE',
        ),

        // 06 — THE CLIMB. Progression, not a roster. Five rungs, not
        // ten profiles — the point is that they get harder, not who
        // they are.
        _ClimbBeat(
          kicker: '05 — THE CLIMB',
          headline: 'They get harder\nas you get better.',
          rungs: [
            ('INTO YOU', 'Easy. She\'s already interested.'),
            ('SWEET', ''),
            ('CHAOS', ''),
            ('TESTING YOU', ''),
            ('ICE QUEEN', 'Gives you nothing. Earn every inch.'),
          ],
          footer: 'Your scores decide what you need to work on. Your '
              'progress takes you further up the climb.',
          cta: 'HOW FAR CAN I GET?',
        ),

        // 07 — THE TRANSFORMATION. Day 1 is deliberately unknown — the
        // question marks are the close. The retention mechanics get one
        // line each here and nowhere else; they are not why he buys.
        _TransformBeat(
          kicker: '06 — 60 DAYS',
          headline: 'Your first score is\nonly the beginning.',
          extras: 'Practice with AI. Take real-world missions. Get coached. '
              'Battle other players. Build your streak.',
          closer: 'First, let\'s find out where you actually stand.',
          cta: 'TAKE MY FIRST TEST',
        ),
      ];
}

// ══════════════════════════════════════════════════════════════════════
//  BACKGROUND — full-bleed art that melts to black, or a red bloom
// ══════════════════════════════════════════════════════════════════════
class _Background extends StatelessWidget {
  final _Beat beat;
  const _Background({required this.beat});

  @override
  Widget build(BuildContext context) {
    final b = beat;
    if (b is _ImageBeat) {
      // Square art, full width, bleeds from the top edge and dissolves
      // into black — shown at true 1:1 (never cropped or stretched).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(b.asset, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF160B0D))),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x00000000), Colors.black],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ).animate(key: ValueKey(b.asset)).fadeIn(duration: 700.ms).scale(
              begin: const Offset(1.04, 1.04),
              end: const Offset(1, 1),
              duration: 8.seconds,
              curve: Curves.easeOut),
          const Expanded(child: ColoredBox(color: Colors.black)),
        ],
      );
    }
    // Non-image beats: deep red bloom on black.
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.1,
          colors: [Color(0x2BE53935), Color(0xFF000000)],
          stops: [0.0, 0.7],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CHROME
// ══════════════════════════════════════════════════════════════════════
class _TopChrome extends StatelessWidget {
  final int page;
  final int count;
  final VoidCallback? onBack;
  const _TopChrome({required this.page, required this.count, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: onBack == null
                ? null
                : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= page
                            ? AppColors.red
                            : Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: i == page
                            ? [
                                BoxShadow(
                                    color: AppColors.red.withValues(alpha: 0.7),
                                    blurRadius: 9)
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _CtaBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _CtaBar({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          22, 12, 22, 16 + MediaQuery.of(context).padding.bottom * 0.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          width: double.infinity,
          height: 62,
          child: Material(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: enabled ? onTap : null,
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  BEAT MODEL
// ══════════════════════════════════════════════════════════════════════
abstract class _Beat {
  const _Beat();
  String get cta => 'CONTINUE';
}

class _ImageBeat extends _Beat {
  final String kicker, asset, headline, body;
  const _ImageBeat({
    required this.kicker,
    required this.asset,
    required this.headline,
    required this.body,
  });
}

class _QuestionBeat extends _Beat {
  final String kicker, question;
  final String? sub;
  final String? note; // small clarifier under the options
  final List<String> options;
  const _QuestionBeat({
    required this.kicker,
    required this.question,
    this.sub,
    this.note,
    required this.options,
  });
}

class _HeroBeat extends _Beat {
  final String headline, body;
  final String _cta;
  const _HeroBeat(
      {required this.headline, required this.body, required String cta})
      : _cta = cta;
  @override
  String get cta => _cta;
}

class _StatementBeat extends _Beat {
  final String kicker, headline, body;
  const _StatementBeat(
      {required this.kicker, required this.headline, required this.body});
}

class _HowBeat extends _Beat {
  final String kicker, headline, footer;
  const _HowBeat(
      {required this.kicker, required this.headline, required this.footer});
}

class _DashboardBeat extends _Beat {
  final String kicker, headline, body;
  const _DashboardBeat(
      {required this.kicker, required this.headline, required this.body});
}

class _BarsBeat extends _Beat {
  final String kicker, headline, body;
  const _BarsBeat(
      {required this.kicker, required this.headline, required this.body});
}

/// The product loop — four named steps with a rule between each.
class _LoopBeat extends _Beat {
  final String kicker, headline;
  final List<(String, String)> steps;
  final String _cta;
  const _LoopBeat({
    required this.kicker,
    required this.headline,
    required this.steps,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

/// THE DIAGNOSIS. A headline, a short read, the three-step loop he is
/// actually stuck in, the line that reframes it, and the promise. It is
/// the hardest-hitting screen in the funnel and it earns its own shape.
class _DiagnosisBeat extends _Beat {
  final String headline, body, verdict, closer;
  final List<String> loop;
  final String _cta;
  const _DiagnosisBeat({
    required this.headline,
    required this.body,
    required this.loop,
    required this.verdict,
    required this.closer,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

/// The five axes with their values DELIBERATELY hidden. Showing a
/// worked example here would answer the one question we want him
/// carrying into the paywall.
class _ScoreBeat extends _Beat {
  final String kicker, headline, footerTitle, footer;
  final List<String> axes;
  final String _cta;
  const _ScoreBeat({
    required this.kicker,
    required this.headline,
    required this.axes,
    required this.footerTitle,
    required this.footer,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

/// Live voice, sold on the one thing text can't do.
class _VoiceBeat extends _Beat {
  final String kicker, headline, body, footer;
  final String _cta;
  const _VoiceBeat({
    required this.kicker,
    required this.headline,
    required this.body,
    required this.footer,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

/// The difficulty ladder. Rungs with an empty blurb render as a name
/// only — the point is the climb, not ten character descriptions.
class _ClimbBeat extends _Beat {
  final String kicker, headline, footer;
  final List<(String, String)> rungs;
  final String _cta;
  const _ClimbBeat({
    required this.kicker,
    required this.headline,
    required this.rungs,
    required this.footer,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

/// Day 1 -> Day 60, with Day 1 unknown. The question marks are the
/// close; the retention mechanics get one line and no more.
class _TransformBeat extends _Beat {
  final String kicker, headline, extras, closer;
  final String _cta;
  const _TransformBeat({
    required this.kicker,
    required this.headline,
    required this.extras,
    required this.closer,
    required String cta,
  }) : _cta = cta;
  @override
  String get cta => _cta;
}

class _FinaleBeat extends _Beat {
  final String headline, body;
  final String _cta;
  const _FinaleBeat(
      {required this.headline, required this.body, required String cta})
      : _cta = cta;
  @override
  String get cta => _cta;
}

// ══════════════════════════════════════════════════════════════════════
//  BEAT VIEW
// ══════════════════════════════════════════════════════════════════════
class _BeatView extends StatelessWidget {
  final _Beat beat;
  final int? selected;
  final ValueChanged<int> onPick;
  const _BeatView({
    super.key,
    required this.beat,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final b = beat;
    if (b is _HeroBeat) return _scroll(_heroBeat(b), center: true);
    if (b is _ImageBeat) return _imageBeat(b);
    if (b is _QuestionBeat) return _scroll(_questionBeat(b), top: true);
    if (b is _DiagnosisBeat) return _scroll(_diagnosisBeat(b), top: true);
    if (b is _StatementBeat) return _scroll(_statementBeat(b), center: true);
    if (b is _HowBeat) return _scroll(_howBeat(b), top: true);
    if (b is _DashboardBeat) return _scroll(_dashboardBeat(b), top: true);
    if (b is _BarsBeat) return _scroll(_barsBeat(b), top: true);
    if (b is _LoopBeat) return _scroll(_loopBeat(b), top: true);
    if (b is _ScoreBeat) return _scroll(_scoreBeat(b), top: true);
    if (b is _VoiceBeat) return _scroll(_voiceBeat(b), top: true);
    if (b is _ClimbBeat) return _scroll(_climbBeat(b), top: true);
    if (b is _TransformBeat) return _scroll(_transformBeat(b), top: true);
    if (b is _FinaleBeat) return _scroll(_finaleBeat(b), center: true);
    return const SizedBox();
  }

  /// Scroll-safe frame for text/question beats: centres or top-aligns and
  /// scrolls only if a small screen can't fit it.
  Widget _scroll(Widget child, {bool top = false, bool center = false}) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: center
                ? MainAxisAlignment.center
                : (top ? MainAxisAlignment.start : MainAxisAlignment.center),
            crossAxisAlignment:
                center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [child],
          ),
        ),
      ),
    );
  }

  // ── Image beat: headline + body anchored to the bottom, over the black.
  //    Scroll-safe — bottom-anchors when it fits, scrolls on small screens
  //    so the copy never overflows.
  Widget _imageBeat(_ImageBeat b) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _kicker(b.kicker),
              const SizedBox(height: 16),
              _headline(b.headline),
              const SizedBox(height: 16),
              _body(b.body),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionBeat(_QuestionBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 16),
        _headline(b.question, size: 32),
        if (b.sub != null) ...[
          const SizedBox(height: 12),
          _body(b.sub!),
        ],
        const SizedBox(height: 30),
        for (var i = 0; i < b.options.length; i++) ...[
          _OptionCard(
            label: b.options[i],
            selected: selected == i,
            onTap: () => onPick(i),
          )
              .animate()
              .fadeIn(delay: (90 + i * 70).ms, duration: 340.ms)
              .slideY(begin: 0.06, end: 0),
          if (i != b.options.length - 1) const SizedBox(height: 12),
        ],
        if (b.note != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(b.note!,
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    )),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ],
    );
  }

  // ── Hero: brand + the promise, front and centre ───────────────────────
  Widget _heroBeat(_HeroBeat b) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ImHimWordmark(fontSize: 60, letterSpacing: -1.8)
            .animate()
            .fadeIn(duration: 560.ms)
            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
        const SizedBox(height: 34),
        Text(b.headline,
                textAlign: TextAlign.center, style: _headlineStyle(38))
            .animate()
            .fadeIn(delay: 200.ms, duration: 560.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 20),
        Text(b.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 16.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
            )).animate().fadeIn(delay: 420.ms, duration: 560.ms),
      ],
    );
  }

  // ── Statement: a pure, bold truth (no bullets) ────────────────────────
  Widget _statementBeat(_StatementBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 38),
        const SizedBox(height: 22),
        _body(b.body, size: 16.5),
      ],
    );
  }

  // ── How it works: three clean steps ───────────────────────────────────
  Widget _howBeat(_HowBeat b) {
    const steps = <(IconData, String, String)>[
      (Icons.smart_toy_rounded, 'Practise with AI',
          'Roleplay realistic voice and text conversations until knowing '
              'what to say becomes natural.'),
      (Icons.public_rounded, 'Complete real missions',
          'Take what you\'ve practised into real life.'),
      (Icons.support_agent_rounded, 'Use your AI wingman',
          'Get help before, during and after every conversation.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 16),
        _headline(b.headline),
        const SizedBox(height: 30),
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                ),
                child: Icon(steps[i].$1, color: AppColors.red, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(steps[i].$2,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text(steps[i].$3,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: (140 + i * 120).ms, duration: 420.ms)
              .slideX(begin: 0.05, end: 0),
          if (i != steps.length - 1) const SizedBox(height: 20),
        ],
        const SizedBox(height: 26),
        Text(b.footer,
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w700,
            )).animate().fadeIn(delay: 560.ms, duration: 400.ms),
      ],
    );
  }

  Widget _dashboardBeat(_DashboardBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 16),
        _headline(b.headline),
        const SizedBox(height: 26),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.asset('assets/onboarding/dashboard.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MockDashboard()),
          ),
        ).animate().fadeIn(duration: 480.ms),
        const SizedBox(height: 22),
        _body(b.body),
      ],
    );
  }

  Widget _barsBeat(_BarsBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 16),
        _headline(b.headline),
        const SizedBox(height: 34),
        const _ClimbingBars(),
        const SizedBox(height: 30),
        _body(b.body),
      ],
    );
  }

  Widget _finaleBeat(_FinaleBeat b) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ImHimWordmark(fontSize: 58, letterSpacing: -1.8)
            .animate()
            .fadeIn(duration: 560.ms),
        const SizedBox(height: 36),
        Text(b.headline,
                textAlign: TextAlign.center, style: _headlineStyle(30))
            .animate()
            .fadeIn(delay: 220.ms, duration: 560.ms),
        const SizedBox(height: 20),
        Text(b.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w500,
            )).animate().fadeIn(delay: 440.ms, duration: 560.ms),
      ],
    );
  }

  // ── Shared type ───────────────────────────────────────────────────────
  // ── THE LOOP: four named steps, a rule between each ───────────────────
  // ── THE DIAGNOSIS ─────────────────────────────────────────────────────
  //
  // The one screen that names the loop rather than the feeling. The
  // three lines are a closed circle on purpose — freeze, no reps, no
  // improvement, freeze — so the boxed verdict lands as the way out of
  // something he can see the shape of, not as reassurance.
  Widget _diagnosisBeat(_DiagnosisBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        _headline(b.headline, size: 40),
        const SizedBox(height: 18),
        _body(b.body, size: 16.5),
        const SizedBox(height: 22),
        for (final (i, line) in b.loop.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 8, right: 14),
                decoration: const BoxDecoration(
                    color: AppColors.red, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(line,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ])
                .animate()
                .fadeIn(delay: (200 + i * 150).ms, duration: 420.ms)
                .slideX(begin: -0.04, end: 0),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.75)),
          ),
          child: Text(b.verdict,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 19,
                height: 1.42,
                fontWeight: FontWeight.w800,
              )),
        ).animate().fadeIn(delay: 740.ms, duration: 460.ms),
        const SizedBox(height: 22),
        _body(b.closer, size: 16.5),
      ],
    );
  }

  Widget _loopBeat(_LoopBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 34),
        const SizedBox(height: 26),
        for (final (i, step) in b.steps.indexed) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 26,
              child: Text('0${i + 1}',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text(step.$2,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
          ])
              .animate()
              .fadeIn(delay: (160 + i * 130).ms, duration: 420.ms)
              .slideX(begin: -0.04, end: 0),
          if (i != b.steps.length - 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
              child: Container(
                  width: 1.4,
                  height: 18,
                  color: AppColors.red.withValues(alpha: 0.45)),
            ),
        ],
      ],
    );
  }

  // ── THE MEASURE: the five axes, values withheld ───────────────────────
  //
  // Every bar reads "?" on purpose. A worked example here would answer
  // the exact question we want him to still have at the paywall, and
  // the question IS the close.
  Widget _scoreBeat(_ScoreBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 34),
        const SizedBox(height: 22),
        // ── THE HERO SCORE ────────────────────────────────────────────
        //
        // The five bars are the breakdown; THIS is the thing he is
        // buying. It sits above them at four times the size, still
        // unanswered, so the shape of the screen says "one number, and
        // here is what it is made of" instead of listing five equal
        // rows and hoping he assembles the headline himself.
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('?',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 76,
                        height: 1.0,
                        letterSpacing: -3,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      )),
                  Text('/100',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 26,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      )),
                ]),
            const SizedBox(height: 4),
            Text('YOUR GAME SCORE',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ).animate().fadeIn(delay: 120.ms, duration: 460.ms),
        const SizedBox(height: 24),
        for (final (i, axis) in b.axes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(children: [
              SizedBox(
                width: 108,
                child: Text(axis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('?',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  )),
            ])
                .animate()
                .fadeIn(delay: (180 + i * 110).ms, duration: 400.ms),
          ),
        const SizedBox(height: 16),
        Text(b.footerTitle,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            )).animate().fadeIn(delay: 760.ms, duration: 420.ms),
        const SizedBox(height: 8),
        _body(b.footer, size: 15.5),
      ],
    );
  }

  // ── LIVE VOICE ────────────────────────────────────────────────────────
  Widget _voiceBeat(_VoiceBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 34),
        const SizedBox(height: 24),
        const _VoiceWave(),
        const SizedBox(height: 24),
        _body(b.body, size: 16),
        const SizedBox(height: 18),
        Text(b.footer,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w800,
            )).animate().fadeIn(delay: 520.ms, duration: 420.ms),
      ],
    );
  }

  // ── THE CLIMB: five rungs, hardest last ───────────────────────────────
  Widget _climbBeat(_ClimbBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 34),
        const SizedBox(height: 26),
        for (final (i, rung) in b.rungs.indexed) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The ladder darkens as it climbs — the last rung is the
                // one he can't reach yet, and it should look like it.
                color: Color.lerp(AppColors.red,
                    Colors.white.withValues(alpha: 0.25), i / b.rungs.length),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rung.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                      )),
                  if (rung.$2.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(rung.$2,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ],
              ),
            ),
          ])
              .animate()
              .fadeIn(delay: (150 + i * 110).ms, duration: 400.ms),
          if (i != b.rungs.length - 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
              child: Container(
                  width: 1.4,
                  height: 16,
                  color: Colors.white.withValues(alpha: 0.16)),
            ),
        ],
        const SizedBox(height: 18),
        _body(b.footer, size: 15.5),
      ],
    );
  }

  // ── 60 DAYS. Day 1 is unknown, and that is the close ──────────────────
  Widget _transformBeat(_TransformBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 18),
        _headline(b.headline, size: 32),
        const SizedBox(height: 26),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Expanded(child: _DayCard(day: 'DAY 1', unknown: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.red.withValues(alpha: 0.8)),
          ),
          const Expanded(child: _DayCard(day: 'DAY 60', unknown: false)),
        ]).animate().fadeIn(delay: 200.ms, duration: 480.ms),
        const SizedBox(height: 14),
        Center(
          child: Text('TRAIN.  GET SCORED.  IMPROVE.',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w800,
              )),
        ).animate().fadeIn(delay: 420.ms, duration: 420.ms),
        const SizedBox(height: 26),
        _body(b.extras, size: 14.5),
        const SizedBox(height: 20),
        Text(b.closer,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w900,
            )).animate().fadeIn(delay: 640.ms, duration: 440.ms),
      ],
    );
  }

  Widget _kicker(String text) => Text(text,
      style: GoogleFonts.inter(
        color: AppColors.red,
        fontSize: 11.5,
        letterSpacing: 4,
        fontWeight: FontWeight.w800,
      )).animate().fadeIn(duration: 400.ms);

  TextStyle _headlineStyle(double size) => GoogleFonts.inter(
        color: Colors.white,
        fontSize: size,
        height: 1.06,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w800,
      );

  Widget _headline(String text, {double size = 36}) =>
      Text(text, style: _headlineStyle(size))
          .animate()
          .fadeIn(duration: 480.ms)
          .slideY(begin: 0.06, end: 0);

  Widget _body(String text, {double size = 16, Color? color}) => Text(text,
      style: GoogleFonts.inter(
        color: color ?? Colors.white.withValues(alpha: 0.78),
        fontSize: size,
        height: 1.5,
        fontWeight: FontWeight.w500,
      )).animate().fadeIn(delay: 180.ms, duration: 480.ms);
}

// ══════════════════════════════════════════════════════════════════════
//  VOICE WAVE — the live-call visual, standing in for a screenshot
// ══════════════════════════════════════════════════════════════════════
class _VoiceWave extends StatefulWidget {
  const _VoiceWave();
  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bars = 34;
    return SizedBox(
      height: 84,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < bars; i++)
              () {
                final t = i / (bars - 1);
                // A speech-shaped envelope: loud in the middle, quiet at
                // the edges, wobbling on the controller.
                final env = math.sin(t * math.pi);
                final wob = math.sin((t * 9) + _c.value * math.pi * 2);
                final h = 6 + (env * (0.55 + 0.45 * wob.abs())) * 66;
                final live = t > 0.3 && t < 0.7;
                return Container(
                  width: 3.4,
                  height: h.clamp(5.0, 78.0),
                  decoration: BoxDecoration(
                    color: live
                        ? AppColors.red
                        : Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DAY CARD — Day 1 unknown, Day 60 unwritten. Both on purpose.
// ══════════════════════════════════════════════════════════════════════
class _DayCard extends StatelessWidget {
  final String day;
  final bool unknown;
  const _DayCard({required this.day, required this.unknown});

  @override
  Widget build(BuildContext context) {
    // Day 1 shows "?" because he has not been tested. Day 60 shows a
    // dash because we will not invent a number he might not reach —
    // a fabricated "82" is a promise the product cannot keep.
    final mark = unknown ? '?' : '—';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unknown
                ? AppColors.red.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day,
              style: GoogleFonts.inter(
                color: unknown ? AppColors.red : Colors.white54,
                fontSize: 10.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 10),
          // Three OF THE REAL FIVE, never a sixth invented one. Every
          // axis word anywhere in this funnel is a dimension the
          // grader actually returns.
          for (final label in const ['GAME', 'CONFIDENCE', 'PRESENCE'])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(mark,
                      style: GoogleFonts.inter(
                        color: unknown ? AppColors.red : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  OPTION CARD
// ══════════════════════════════════════════════════════════════════════
class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF1E0C0E)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? AppColors.red : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: -6)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              const SizedBox(width: 10),
              AnimatedScale(
                scale: selected ? 1 : 0.4,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.red, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SCREEN 7 — mock dashboard fallback
// ══════════════════════════════════════════════════════════════════════
class _MockDashboard extends StatelessWidget {
  const _MockDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('YOUR TRANSFORMATION',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 10,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('DAY 1 / 60',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _row('CONFIDENCE', 0.59),
          const SizedBox(height: 15),
          _row('GAME', 0.60),
          const SizedBox(height: 15),
          _row('PRESENCE', 0.48),
        ],
      ),
    );
  }

  Widget _row(String label, double v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                )),
            const Spacer(),
            Text('${(v * 100).round()}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: AppColors.surface3,
            valueColor: const AlwaysStoppedAnimation(AppColors.red),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SCREEN 9 — climbing score bars
// ══════════════════════════════════════════════════════════════════════
class _ClimbingBars extends StatefulWidget {
  const _ClimbingBars();
  @override
  State<_ClimbingBars> createState() => _ClimbingBarsState();
}

class _ClimbingBarsState extends State<_ClimbingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..forward();

  static const _rows = <(String, int, int)>[
    ('CONFIDENCE', 31, 78),
    ('PRESENCE', 26, 71),
    ('GAME', 38, 85),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Column(
          children: [
            for (final (label, from, to) in _rows) ...[
              _bar(label, from, to, t),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }

  Widget _bar(String label, int from, int to, double t) {
    final val = (from + (to - from) * t).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                )),
            const Spacer(),
            Text('$from → ',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            Text('$val',
                style: GoogleFonts.inter(
                  color: AppColors.signalGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (from + (to - from) * t) / 100.0,
            minHeight: 8,
            backgroundColor: AppColors.surface3,
            valueColor: const AlwaysStoppedAnimation(AppColors.signalGreen),
          ),
        ),
      ],
    );
  }
}
