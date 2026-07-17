import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// ImHim onboarding — the 10-beat "mind-reading" funnel. Exposes the
/// pattern (you freeze, someone else moves), shows the cost, then sells
/// the 60-day transformation and hands off to the paywall.
///
/// Forward-only (Continue drives it); question beats require a pick so
/// the user invests. Screens 7 + 9 are LIVE dashboards built in code.
/// Image beats (1, 3, 5) use assets/onboarding/*.jpg with a graceful
/// dark fallback so the build never breaks before the art lands.
class OnboardingStoryScreen extends StatefulWidget {
  const OnboardingStoryScreen({super.key});

  @override
  State<OnboardingStoryScreen> createState() => _OnboardingStoryScreenState();
}

class _OnboardingStoryScreenState extends State<OnboardingStoryScreen> {
  final _pc = PageController();
  int _page = 0;
  // Selected option index per question page (by page index).
  final Map<int, int> _answers = {};

  late final List<_Beat> _beats = _buildBeats();

  int get _count => _beats.length;

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _count - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    // Name + age band next (feeds the AI), then the AI-consent gate, then
    // the paywall. onboarded/gender get stamped on the profile screen.
    context.go('/onboarding/profile');
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
    final canContinue = !isQuestion || _answers[_page] != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content pager (swipe forward allowed; taps drive it too).
          PageView.builder(
            controller: _pc,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _count,
            itemBuilder: (_, i) => _BeatView(
              beat: _beats[i],
              pageIndex: i,
              selected: _answers[i],
              onPick: (opt) {
                HapticFeedback.selectionClick();
                setState(() => _answers[i] = opt);
              },
            ),
          ),

          // Top chrome — progress + back.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: _page == 0
                        ? const SizedBox()
                        : IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _pc.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: Colors.white70),
                          ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _count; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              height: 3,
                              decoration: BoxDecoration(
                                color: i <= _page
                                    ? AppColors.red
                                    : Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(3),
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
            ),
          ),

          // Bottom CTA.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: canContinue
                        ? AppColors.red
                        : AppColors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: canContinue ? _next : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        alignment: Alignment.center,
                        child: Text(beat.cta,
                            style: GoogleFonts.inter(
                              color: canContinue
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 14.5,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                    ),
                  ),
                ),
              ),
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
          headline: 'You already know how this ends.',
          body: 'You see the moment.\nYou hesitate.\nSomeone else takes it.',
        ),
        _QuestionBeat(
          question: 'Which one hurts because it\'s true?',
          options: [
            'I\'ll do it next time.',
            'I knew what to say… afterwards.',
            'I watched someone else do what I couldn\'t.',
            'I keep waiting until I feel confident.',
          ],
        ),
        _ImageBeat(
          asset: 'assets/onboarding/1am.png',
          headline: 'The worst part isn\'t rejection.',
          body: 'It\'s wondering what would\'ve happened\nif you had just moved.',
        ),
        _QuestionBeat(
          question: 'How many chances have you lost to hesitation?',
          options: ['1–5', '5–20', 'More than I want to admit'],
        ),
        _ImageBeat(
          asset: 'assets/onboarding/mirror.png',
          headline: 'You\'re getting used to watching.',
          body: 'Not because you don\'t care.\nBecause when the moment comes,\nyou freeze.',
        ),
        _QuestionBeat(
          question: 'Be honest.',
          sub: 'When was the last time you actually trained this?',
          options: ['Never', 'A few times', 'Regularly'],
        ),
        _DashboardBeat(
          headline: 'This is what the next 60 days changes.',
          body: 'Not what you say you\'ll become.\nWhat you actually become.',
        ),
        _TextBeat(
          headline: 'You do the reps.\nThe reps change you.',
          body: 'Every day you complete:',
          bullets: [
            'AI conversations',
            'Real-world missions',
            'Corrections after every miss',
            'Progress tracking',
          ],
          footer: 'No guessing. No hoping. Just measurable change.',
        ),
        _BarsBeat(
          headline: 'One day, something feels different.',
          body: 'You stop overthinking.\nYou stop standing there.\nYou just act.',
        ),
        _FinaleBeat(
          headline: 'The next 60 days will pass anyway.',
          body: 'At the end of them, you\'ll either still be watching —\n\nor you\'ll become ImHim.',
          cta: 'SEE MY PLAN',
        ),
      ];
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
//  BEAT VIEW — routes each beat type to its layout
// ══════════════════════════════════════════════════════════════════════
class _BeatView extends StatelessWidget {
  final _Beat beat;
  final int pageIndex;
  final int? selected;
  final ValueChanged<int> onPick;
  const _BeatView({
    required this.beat,
    required this.pageIndex,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final b = beat;
    if (b is _ImageBeat) return _imageLayout(b);
    if (b is _QuestionBeat) return _questionLayout(b);
    if (b is _TextBeat) return _textLayout(b);
    if (b is _DashboardBeat) return _dashboardLayout(b);
    if (b is _BarsBeat) return _barsLayout(b);
    if (b is _FinaleBeat) return _finaleLayout(b);
    return const SizedBox();
  }

  // Full-bleed painful image; headline + body over a dark bottom scrim.
  Widget _imageLayout(_ImageBeat b) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(b.asset, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0B0B0E))),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x66000000), Color(0xF2000000)],
              stops: [0.0, 0.45, 0.92],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 110),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.headline,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.08,
                      letterSpacing: -0.8,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w800,
                    )).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 14),
                Text(b.body,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    )).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shell({required Widget child}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.7),
              radius: 1.2,
              colors: [AppColors.red.withValues(alpha: 0.14), Colors.black],
              stops: const [0.0, 0.65],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 60, 26, 100),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _questionLayout(_QuestionBeat b) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(b.question,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 30,
                height: 1.12,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              )).animate().fadeIn(duration: 420.ms),
          if (b.sub != null) ...[
            const SizedBox(height: 10),
            Text(b.sub!,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                )),
          ],
          const SizedBox(height: 24),
          for (var i = 0; i < b.options.length; i++) ...[
            _OptionCard(
              label: b.options[i],
              selected: selected == i,
              onTap: () => onPick(i),
            ).animate().fadeIn(delay: (100 + i * 70).ms, duration: 360.ms)
                .slideY(begin: 0.06, end: 0),
            const SizedBox(height: 10),
          ],
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _textLayout(_TextBeat b) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(b.headline,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 34,
                height: 1.1,
                letterSpacing: -0.6,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              )).animate().fadeIn(duration: 420.ms),
          const SizedBox(height: 18),
          Text(b.body,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 14),
          for (final line in b.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.red, shape: BoxShape.circle),
                  ),
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
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(b.footer,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 14.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              )),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _dashboardLayout(_DashboardBeat b) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          // Designed dashboard preview; falls back to the in-code mock
          // if the asset isn't bundled yet.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/onboarding/dashboard.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _MockDashboard()),
          ),
          const SizedBox(height: 26),
          Text(b.headline,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 28,
                height: 1.12,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 10),
          Text(b.body,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              )),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _barsLayout(_BarsBeat b) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const _ClimbingBars(),
          const SizedBox(height: 28),
          Text(b.headline,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 28,
                height: 1.12,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 10),
          Text(b.body,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              )),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _finaleLayout(_FinaleBeat b) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ImHimWordmark(fontSize: 54, letterSpacing: -1.6)
              .animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 34),
          Text(b.headline,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 30,
                height: 1.12,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              )).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 18),
          Text(b.body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w500,
              )).animate().fadeIn(delay: 400.ms, duration: 500.ms),
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
  const _OptionCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.red.withValues(alpha: 0.14) : AppColors.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.red : AppColors.surface3,
              width: selected ? 1.4 : 0.8,
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
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.red, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SCREEN 7 — mock dashboard (Day 1 of 60)
// ══════════════════════════════════════════════════════════════════════
class _MockDashboard extends StatelessWidget {
  const _MockDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.red.withValues(alpha: 0.14), blurRadius: 28, spreadRadius: -6),
        ],
      ),
      child: Column(
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
          const SizedBox(height: 16),
          _row('CONFIDENCE', 0.59),
          const SizedBox(height: 12),
          _row('GAME', 0.60),
          const SizedBox(height: 12),
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
              const SizedBox(height: 16),
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (from + (to - from) * t) / 100.0,
            minHeight: 7,
            backgroundColor: AppColors.surface3,
            valueColor: const AlwaysStoppedAnimation(AppColors.signalGreen),
          ),
        ),
      ],
    );
  }
}
