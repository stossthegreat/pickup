import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/local_store_service.dart';
import '../../services/analytics_service.dart';
import '../../services/paywall_gate.dart';
import '../game/freeflow/free_flow_screen.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';

/// THE VOICE TEST — the last thing he sees before the price.
///
/// The story beats end on "what do I score?". This screen puts the
/// scoreboard, the woman and the microphone in front of him and lets him
/// reach for it — and the reach is the moment the paywall opens.
///
/// WHY IT DOES NOT CONNECT. Live voice is the single most expensive
/// action in the app, and the rule has not changed: talk is never free,
/// the minute belongs to people who start the trial. So nothing here
/// opens a socket, spends a token, or fakes a connection — there is no
/// "connecting…" theatre and no scripted reply. He sees exactly what he
/// is buying, presses the button that starts it, and the price arrives
/// in the same breath as the intent. The real session, the real score
/// and the real minute are all on the other side of that button.
///
/// The five axes are named and left as `?` for the same reason they are
/// on the paywall: a man who can name what he is marked on believes the
/// mark, and an unanswered number is the only thing on this screen he
/// cannot get anywhere else.
class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  /// Sofia — the day-one woman, and the one he already met in the
  /// story beats. Falls back to the head of the roster if the id ever
  /// moves, so this screen can never render an empty frame.
  static final GirlBrief _her = kRoster.firstWhere(
    (g) => g.id == 'into_you',
    orElse: () => kRoster.first,
  );

  /// THE REAL FIVE. What the voice grader returns, what the Progress
  /// tab keeps, and what the share card posts — one set of words for
  /// the whole app, so the promise and the result never disagree.
  static const _axes = ['Confidence', 'Presence', 'Game', 'Humour', 'Listening'];

  /// Has he paid? The screen has two lives either side of that answer.
  bool _live = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    LocalStoreService.setOnbStep('/onboarding/voice-test');
    // ignore: discarded_futures
    AnalyticsService.onbStoryBeat(100); // 100 = the voice test beat
    // ignore: discarded_futures
    _resolveLive();
  }

  Future<void> _resolveLive() async {
    final pro = await PaywallGate.isPro();
    if (mounted) setState(() => _live = pro);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// ONE BUTTON, TWO LIVES.
  ///
  /// Before he pays, the reach IS the paywall — talk is never free and
  /// pressing the mic is the intent the price answers.
  ///
  /// After he pays it has to do the thing it said. This screen promises
  /// sixty seconds with her and a number; landing him on a name form
  /// instead is the app taking his money and then not delivering the one
  /// demonstration it sold him. So on the paid pass the same button
  /// opens the real voice session — the actual live screen, her actual
  /// voice, the actual scoring path — and the chat test follows it.
  Future<void> _start() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();

    if (!_live) {
      // ignore: discarded_futures
      AnalyticsService.onbFinished();
      context.go('/paywall', extra: const {
        'source': 'onboarding_voice',
        'afterPurchase': '/onboarding/profile',
      });
      return;
    }

    setState(() => _busy = true);
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => FreeFlowScreen(
          initialVibeKey: _her.vibeKey,
          // SHE WAS ASSIGNED, NOT CHOSEN — the day-lock is a Practice
          // mechanic and this is a set test, not a pick.
          assigned: true,
          // No coach in a test, exactly as on the text side. A score
          // with a ghostwriter behind it measures nothing.
          coachAllowed: false,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // Voice done, text next. He has been scored on how he sounds; the
    // chat test scores how he writes, and they are not the same man.
    context.go('/onboarding/first-rep');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // ── Her, full bleed, dropped back far enough to read over ──
        Image.asset(_her.asset, fit: BoxFit.cover, alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC000000),
                Color(0x55000000),
                Color(0xEE000000),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.34, 0.66, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final s = (box.maxHeight / 620).clamp(0.72, 1.0).toDouble();
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  // TWO GROUPS, NOT A SPACER. Spacer is an Expanded, and
                  // this Column sits inside a scroll view — an unbounded
                  // main axis. A flex child there throws during layout and
                  // paints nothing, which is exactly how the paywall went
                  // blank. spaceBetween needs no flex child to do the same
                  // job, so the gap is free and the screen cannot fail.
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          _kicker(s),
                          SizedBox(height: 10 * s),
                          _headline(s),
                          SizedBox(height: 10 * s),
                          _liveCard(s),
                        ]),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          _axisRow(s),
                          SizedBox(height: 16 * s),
                          _mic(s),
                          SizedBox(height: 12 * s),
                          Text(
                              '60 seconds with her. Then you get your number.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 13 * s,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              )),
                          // THE WAY PAST, ONCE HE HAS PAID. Before the
                          // price the paywall's own X is the exit; after
                          // it, this screen would be the only one in the
                          // app with no way forward but a live call — and
                          // a man who cannot leave a screen does not buy
                          // again, he uninstalls. Deliberately quiet, and
                          // it goes exactly where the test goes.
                          if (_live) ...[
                            SizedBox(height: 4 * s),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      context.go('/onboarding/first-rep');
                                    },
                              child: Text('NOT RIGHT NOW',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textTertiary,
                                    fontSize: 11 * s,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ),
                          ],
                        ]),
                      ]),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _kicker(double s) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7 * s,
            height: 7 * s,
            decoration: const BoxDecoration(
                color: AppColors.red, shape: BoxShape.circle),
          ),
          SizedBox(width: 8 * s),
          Text('YOUR VOICE TEST',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 12 * s,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
        ],
      );

  Widget _headline(double s) => Column(children: [
        Text('TALK TO HER.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 38 * s,
              height: 1.0,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
        Text('GET SCORED.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 38 * s,
              height: 1.0,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            )),
      ]);

  /// Her name, her chip, and the line she opens on — the thing he will
  /// have to answer out loud in about four seconds.
  Widget _liveCard(double s) => Container(
        padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
        decoration: BoxDecoration(
          color: const Color(0xCC0C0C10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(_her.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15 * s,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  )),
              SizedBox(width: 8 * s),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 7 * s, vertical: 3 * s),
                  decoration: BoxDecoration(
                    color: _her.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_her.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _her.accent,
                        fontSize: 9.5 * s,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ]),
            SizedBox(height: 7 * s),
            Text('"${_her.opener}"',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.5 * s,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                )),
          ],
        ),
      );

  /// The five axes, unanswered. This is the whole question the funnel
  /// has been building toward, stated as a scoreboard he cannot fill in.
  Widget _axisRow(double s) => Container(
        padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 6 * s),
        decoration: BoxDecoration(
          color: const Color(0xB30A0A0E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final a in _axes)
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('?',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 24 * s,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      )),
                  SizedBox(height: 4 * s),
                  Text(a.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 8.5 * s,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      )),
                ]),
              ),
          ],
        ),
      );

  /// The reach. A live-looking record ring — pressing it is the intent
  /// signal, and the price answers it.
  Widget _mic(double s) => GestureDetector(
        // ignore: discarded_futures
        onTap: _busy ? null : _start,
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          SizedBox(
            height: 116 * s,
            width: 116 * s,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final v = _pulse.value;
                return Stack(alignment: Alignment.center, children: [
                  // Two rings a half-cycle apart, expanding and fading —
                  // the visual grammar of a live mic, borrowed from the
                  // real voice screen so this reads as the same object.
                  for (final o in const [0.0, 0.5])
                    Opacity(
                      opacity: (1 - ((v + o) % 1.0)) * 0.45,
                      child: Container(
                        width: (70 + ((v + o) % 1.0) * 46) * s,
                        height: (70 + ((v + o) % 1.0) * 46) * s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.red, width: 1.6),
                        ),
                      ),
                    ),
                  child!,
                ]);
              },
              child: Container(
                width: 74 * s,
                height: 74 * s,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.55),
                        blurRadius: 34,
                        spreadRadius: 2),
                  ],
                ),
                child: Icon(Icons.mic_rounded,
                    size: 36 * s, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          Text('START THE TEST',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 17 * s,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
              )),
        ]),
      );
}
