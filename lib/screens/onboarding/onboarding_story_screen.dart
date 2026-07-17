import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _count - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutCubic);
    } else {
      context.go('/onboarding/profile');
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
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _count,
                    itemBuilder: (_, i) => _BeatView(
                      key: ValueKey(i),
                      beat: _beats[i],
                      selected: _answers[i],
                      onPick: (opt) {
                        HapticFeedback.selectionClick();
                        setState(() => _answers[i] = opt);
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
  List<_Beat> _buildBeats() => const [
        _ImageBeat(
          kicker: '01 — THE PATTERN',
          asset: 'assets/onboarding/hesitation.png',
          headline: 'You already know\nhow this ends.',
          body: 'You see the moment. You hesitate.\nSomeone else takes it.',
        ),
        _QuestionBeat(
          kicker: '02 — BE HONEST',
          question: 'Which one hurts\nbecause it\'s true?',
          options: [
            'I\'ll do it next time.',
            'I knew what to say… afterwards.',
            'I watched someone else do what I couldn\'t.',
            'I keep waiting until I feel confident.',
          ],
        ),
        _ImageBeat(
          kicker: '03 — THE REGRET',
          asset: 'assets/onboarding/1am.png',
          headline: 'The worst part\nisn\'t rejection.',
          body: 'It\'s wondering what would\'ve happened\nif you had just moved.',
        ),
        _QuestionBeat(
          kicker: '04 — THE COST',
          question: 'How many chances\nhas hesitation cost you?',
          options: ['A few', 'More than I\'d like', 'More than I want to admit'],
        ),
        _ImageBeat(
          kicker: '05 — THE MIRROR',
          asset: 'assets/onboarding/mirror.png',
          headline: 'You\'re getting\nused to watching.',
          body: 'Not because you don\'t care.\nBecause when it matters, you freeze.',
        ),
        _QuestionBeat(
          kicker: '06 — THE TRUTH',
          question: 'Be honest.',
          sub: 'When did you last actually train this?',
          options: ['Never', 'A few times', 'Regularly'],
        ),
        _DashboardBeat(
          kicker: '07 — THE PLAN',
          headline: 'This is what the\nnext 60 days changes.',
          body: 'Not what you say you\'ll become.\nWhat you measurably become.',
        ),
        _TextBeat(
          kicker: '08 — THE WORK',
          headline: 'You do the reps.\nThe reps change you.',
          body: 'Every single day:',
          bullets: [
            'Real AI conversations',
            'Real-world missions',
            'A correction after every miss',
            'Progress you can actually see',
          ],
          footer: 'No guessing. No hoping. Measurable change.',
        ),
        _BarsBeat(
          kicker: '09 — THE SHIFT',
          headline: 'One day, something\nfeels different.',
          body: 'You stop overthinking.\nYou stop standing there.\nYou just move.',
        ),
        _FinaleBeat(
          headline: 'The next 60 days\nwill pass anyway.',
          body: 'At the end of them you\'ll either still be watching —\nor you\'ll be ImHim.',
          cta: 'SEE MY PLAN',
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
  final List<String> options;
  const _QuestionBeat({
    required this.kicker,
    required this.question,
    this.sub,
    required this.options,
  });
}

class _TextBeat extends _Beat {
  final String kicker, headline, body, footer;
  final List<String> bullets;
  const _TextBeat({
    required this.kicker,
    required this.headline,
    required this.body,
    required this.bullets,
    required this.footer,
  });
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
    if (b is _ImageBeat) return _imageBeat(b);
    if (b is _QuestionBeat) return _scroll(_questionBeat(b), top: true);
    if (b is _TextBeat) return _scroll(_textBeat(b), top: true);
    if (b is _DashboardBeat) return _scroll(_dashboardBeat(b), top: true);
    if (b is _BarsBeat) return _scroll(_barsBeat(b), top: true);
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

  // ── Image beat: headline + body anchored to the bottom, over the black ──
  Widget _imageBeat(_ImageBeat b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 8),
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
      ],
    );
  }

  Widget _textBeat(_TextBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _kicker(b.kicker),
        const SizedBox(height: 16),
        _headline(b.headline),
        const SizedBox(height: 20),
        _body(b.body, color: AppColors.textSecondary, size: 15.5),
        const SizedBox(height: 18),
        for (final line in b.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.red, size: 21),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(line,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
        const SizedBox(height: 8),
        Text(b.footer,
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 14.5,
              height: 1.4,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            )),
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
  Widget _kicker(String text) => Text(text,
      style: GoogleFonts.inter(
        color: AppColors.red,
        fontSize: 11.5,
        letterSpacing: 4,
        fontWeight: FontWeight.w800,
      )).animate().fadeIn(duration: 400.ms);

  TextStyle _headlineStyle(double size) => GoogleFonts.playfairDisplay(
        color: Colors.white,
        fontSize: size,
        height: 1.06,
        letterSpacing: -0.6,
        fontStyle: FontStyle.italic,
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
    ('CONFIDENCE', 59, 76),
    ('PRESENCE', 48, 71),
    ('GAME', 60, 83),
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
