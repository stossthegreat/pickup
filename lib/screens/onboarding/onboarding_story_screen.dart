import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// ImHim onboarding — a 10-beat emotional funnel that names the pattern
/// (you freeze, someone else moves), shows the cost, then sells the
/// 60-day transformation and hands off to the profile → consent → paywall.
///
/// Architecture: a FIXED FRAME. The segmented progress pins to the top and
/// the CONTINUE bar pins to the bottom; only the middle swipes. Because the
/// CTA is a sibling in the Column (not a floating overlay), it can NEVER
/// overlap content — every beat is bounded and scroll-safe on any screen.
class OnboardingStoryScreen extends StatefulWidget {
  const OnboardingStoryScreen({super.key});

  @override
  State<OnboardingStoryScreen> createState() => _OnboardingStoryScreenState();
}

class _OnboardingStoryScreenState extends State<OnboardingStoryScreen> {
  final _pc = PageController();
  int _page = 0;
  // Selected option index per question page (keyed by page index).
  final Map<int, int> _answers = {};

  late final List<_Beat> _beats = _buildBeats();
  int get _count => _beats.length;

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _count - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    _pc.previousPage(
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  void _finish() => context.go('/onboarding/profile');

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
    final ctaLabel = (isQuestion && !answered) ? 'PICK ONE TO CONTINUE' : beat.cta;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // A single, calm backdrop behind everything — soft red bloom on
          // black. Shared by every beat so the frame reads as one piece.
          const _Backdrop(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopChrome(
                  page: _page,
                  count: _count,
                  onBack: _page == 0 ? null : _back,
                ),
                // The only moving part. Bounded height → content can never
                // spill under the CTA.
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
                _CtaBar(
                  label: ctaLabel,
                  enabled: canContinue,
                  onTap: _next,
                ),
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
          asset: 'assets/onboarding/hesitation.png',
          headline: 'You already know\nhow this ends.',
          body: 'You see the moment. You hesitate.\nSomeone else takes it.',
        ),
        _QuestionBeat(
          question: 'Which one hurts\nbecause it\'s true?',
          options: [
            'I\'ll do it next time.',
            'I knew what to say… afterwards.',
            'I watched someone else do what I couldn\'t.',
            'I keep waiting until I feel confident.',
          ],
        ),
        _ImageBeat(
          asset: 'assets/onboarding/1am.png',
          headline: 'The worst part\nisn\'t rejection.',
          body: 'It\'s wondering what would\'ve happened\nif you had just moved.',
        ),
        _QuestionBeat(
          question: 'How many chances\nhas hesitation cost you?',
          options: ['A few', 'More than I\'d like', 'More than I want to admit'],
        ),
        _ImageBeat(
          asset: 'assets/onboarding/mirror.png',
          headline: 'You\'re getting\nused to watching.',
          body: 'Not because you don\'t care.\nBecause when the moment comes, you freeze.',
        ),
        _QuestionBeat(
          question: 'Be honest.',
          sub: 'When did you last actually train this?',
          options: ['Never', 'A few times', 'Regularly'],
        ),
        _DashboardBeat(
          headline: 'This is what the\nnext 60 days changes.',
          body: 'Not what you say you\'ll become.\nWhat you measurably become.',
        ),
        _TextBeat(
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
//  SHARED CHROME
// ══════════════════════════════════════════════════════════════════════

/// Soft red bloom on pure black — the whole funnel's backdrop.
class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.55),
          radius: 1.15,
          colors: [Color(0x24E53935), Color(0xFF000000)],
          stops: [0.0, 0.72],
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  final int page;
  final int count;
  final VoidCallback? onBack;
  const _TopChrome({required this.page, required this.count, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: onBack == null
                ? null
                : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white70),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= page
                            ? AppColors.red
                            : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: i == page
                            ? [
                                BoxShadow(
                                    color: AppColors.red.withValues(alpha: 0.6),
                                    blurRadius: 8)
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
          22, 10, 22, 18 + MediaQuery.of(context).padding.bottom * 0.5),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(16),
            elevation: enabled ? 0 : 0,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Text(label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 2.6,
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
  final String asset, headline, body;
  const _ImageBeat({required this.asset, required this.headline, required this.body});
}

class _QuestionBeat extends _Beat {
  final String question;
  final String? sub;
  final List<String> options;
  const _QuestionBeat({required this.question, this.sub, required this.options});
}

class _TextBeat extends _Beat {
  final String headline, body, footer;
  final List<String> bullets;
  const _TextBeat({
    required this.headline,
    required this.body,
    required this.bullets,
    required this.footer,
  });
}

class _DashboardBeat extends _Beat {
  final String headline, body;
  const _DashboardBeat({required this.headline, required this.body});
}

class _BarsBeat extends _Beat {
  final String headline, body;
  const _BarsBeat({required this.headline, required this.body});
}

class _FinaleBeat extends _Beat {
  final String headline, body;
  final String _cta;
  const _FinaleBeat({required this.headline, required this.body, required String cta})
      : _cta = cta;
  @override
  String get cta => _cta;
}

// ══════════════════════════════════════════════════════════════════════
//  BEAT VIEW — routes each beat to its layout, inside a scroll-safe frame
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
    if (b is _ImageBeat) return _frame(_imageContent(b));
    if (b is _QuestionBeat) return _frame(_questionContent(b), top: true);
    if (b is _TextBeat) return _frame(_textContent(b));
    if (b is _DashboardBeat) return _frame(_dashboardContent(b));
    if (b is _BarsBeat) return _frame(_barsContent(b));
    if (b is _FinaleBeat) return _frame(_finaleContent(b), center: true);
    return const SizedBox();
  }

  /// Scroll-safe frame: the child is centred when it fits and scrolls when
  /// it doesn't, so nothing ever overflows or hides under the CTA. [top]
  /// left-aligns for question beats; [center] hard-centres the finale.
  Widget _frame(Widget child, {bool top = false, bool center = false}) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 10, 26, 26),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 36),
            child: Column(
              // min → sizes to max(content, viewport); never tries to fill
              // the scroll view's unbounded height, so it can't overflow.
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: center
                  ? MainAxisAlignment.center
                  : (top ? MainAxisAlignment.start : MainAxisAlignment.center),
              crossAxisAlignment:
                  center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (top) const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Image beat: true-square art card + headline + body ────────────────
  Widget _imageContent(_ImageBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Perfect 1:1 — the source art is square, so it's shown at its
        // real proportion, never stretched or awkwardly cropped.
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: -12),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(b.asset, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF14090B))),
                // Gentle bottom fade so any caption weight sits well.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x55000000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).scale(
            begin: const Offset(0.98, 0.98), end: const Offset(1, 1)),
        const SizedBox(height: 28),
        _headline(b.headline),
        const SizedBox(height: 14),
        _body(b.body),
      ],
    );
  }

  // ── Question beat ─────────────────────────────────────────────────────
  Widget _questionContent(_QuestionBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headline(b.question, size: 30),
        if (b.sub != null) ...[
          const SizedBox(height: 12),
          _body(b.sub!, size: 16),
        ],
        const SizedBox(height: 28),
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

  // ── Reps beat ─────────────────────────────────────────────────────────
  Widget _textContent(_TextBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headline(b.headline),
        const SizedBox(height: 18),
        _body(b.body, size: 15.5, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        for (final line in b.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(line,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
        const SizedBox(height: 6),
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

  // ── Dashboard beat ────────────────────────────────────────────────────
  Widget _dashboardContent(_DashboardBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headline(b.headline),
        const SizedBox(height: 22),
        // The designed preview is square; keep it square, or fall back to
        // the in-code mock so the build never breaks.
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.asset('assets/onboarding/dashboard.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MockDashboard()),
          ),
        ).animate().fadeIn(duration: 460.ms),
        const SizedBox(height: 20),
        _body(b.body),
      ],
    );
  }

  // ── Bars beat ─────────────────────────────────────────────────────────
  Widget _barsContent(_BarsBeat b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headline(b.headline),
        const SizedBox(height: 28),
        const _ClimbingBars(),
        const SizedBox(height: 26),
        _body(b.body),
      ],
    );
  }

  // ── Finale ────────────────────────────────────────────────────────────
  Widget _finaleContent(_FinaleBeat b) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ImHimWordmark(fontSize: 52, letterSpacing: -1.6)
            .animate()
            .fadeIn(duration: 520.ms),
        const SizedBox(height: 32),
        Text(b.headline,
            textAlign: TextAlign.center,
            style: _headlineStyle(30)).animate().fadeIn(delay: 200.ms, duration: 520.ms),
        const SizedBox(height: 18),
        Text(b.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w500,
            )).animate().fadeIn(delay: 400.ms, duration: 520.ms),
      ],
    );
  }

  // ── Shared text bits ──────────────────────────────────────────────────
  TextStyle _headlineStyle(double size) => GoogleFonts.playfairDisplay(
        color: Colors.white,
        fontSize: size,
        height: 1.1,
        letterSpacing: -0.6,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
      );

  Widget _headline(String text, {double size = 33}) => Text(text,
          style: _headlineStyle(size))
      .animate()
      .fadeIn(duration: 460.ms)
      .slideY(begin: 0.06, end: 0);

  Widget _body(String text, {double size = 16, Color? color}) => Text(text,
      style: GoogleFonts.inter(
        color: color ?? Colors.white.withValues(alpha: 0.80),
        fontSize: size,
        height: 1.5,
        fontWeight: FontWeight.w500,
      )).animate().fadeIn(delay: 180.ms, duration: 460.ms);
}

// ══════════════════════════════════════════════════════════════════════
//  OPTION CARD
// ══════════════════════════════════════════════════════════════════════
class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.red.withValues(alpha: 0.16) : AppColors.surface1,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.red : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1,
            ),
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
//  SCREEN 7 — mock dashboard fallback (Day 1 of 60)
// ══════════════════════════════════════════════════════════════════════
class _MockDashboard extends StatelessWidget {
  const _MockDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 20),
          _row('CONFIDENCE', 0.59),
          const SizedBox(height: 14),
          _row('GAME', 0.60),
          const SizedBox(height: 14),
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
        const SizedBox(height: 6),
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
//  SCREEN 9 — climbing score bars (59→76, 48→71, 60→83)
// ══════════════════════════════════════════════════════════════════════
class _ClimbingBars extends StatefulWidget {
  const _ClimbingBars();
  @override
  State<_ClimbingBars> createState() => _ClimbingBarsState();
}

class _ClimbingBarsState extends State<_ClimbingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
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
              const SizedBox(height: 18),
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
        const SizedBox(height: 7),
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
