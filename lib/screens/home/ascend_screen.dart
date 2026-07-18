import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/protocol.dart';
import '../../models/scan_record.dart' show ScanRecord;
import '../../services/ascension_service.dart';
import '../../services/mission_catalog.dart';
import '../../services/mission_engine.dart';
import '../../services/local_store_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/ascend/ascension_map.dart';
import '../../widgets/charmr/metrics_panel.dart';
import '../../widgets/common/streak_badge.dart';

/// v281 — ASCENSION home tab.
///
/// Total rebuild. The previous AscendScreen MEASURED progress (three
/// pillar score cards, percentages, deltas). Bro:
///
///   > Your current Progress screen measures.
///   > A retention screen motivates.
///   > Those are completely different jobs.
///
/// New job: answer one question — "Who do I become if I finish?" —
/// and surface the fear of not finishing alongside the status of
/// who they're becoming.
///
/// Seven sections, in order:
///   1. HERO — massive flame ring, DAY N / 60, identity rank inside,
///      days-remaining + tagline below.
///   2. COST OF QUITTING — rotating fear-card. Day-anchored copy so
///      it cycles instead of going stale.
///   3. TODAY'S ASCENSION — 5 daily MISSIONS (not tasks). 4/5 COMPLETE
///      header, each tick visibly feeds the flame.
///   4. RANK PROGRESSION — Observer → Initiate → Contender →
///      Dangerous → Magnetic → ImHim. Status ladder, not stats.
///   5. ASCENSION RECORD — timeline of milestones. "This becomes
///      their story."
///   6. STREAK — huge flame number. Users protect streaks, not scores.
///   7. FINAL FORM — Day-60 unlock card, locked + blurred. Anticipation
///      IS the retention.
class AscendScreen extends StatefulWidget {
  /// Switch the bottom-nav to a specific tab. 1=Looks, 2=Game, 3=Rizz.
  final ValueChanged<int> onJumpToTab;

  /// Pull-to-refresh hook — re-reads the home-screen state (scores,
  /// streak, mission flags) so Ascend updates without a tab switch.
  /// Same gesture the Looks tab uses.
  final Future<void> Function()? onRefresh;

  /// Active 60-day protocol, if any. Drives Day-N, streak,
  /// completedToday, and rank progression.
  final Protocol? protocol;

  /// Latest scan in history (used for the Ascension Record timeline).
  final ScanRecord? latest;

  /// All scans the user has logged (chronological → reverse-chronological
  /// in the timeline). Empty list when fresh-install.
  final List<ScanRecord> allScans;

  /// Current daily streak from StreakService (via home_screen). Used in
  /// the masthead flame + the streak panel.
  final int dayStreak;

  /// Longest daily streak the user has ever reached (StreakService).
  final int longestStreak;

  /// Earned ascension day (total days shown up, 1..60) from
  /// StreakService.progress via home_screen. Drives the DAY N/60 flame
  /// ring, the rank ladder, and the final-form unlock.
  final int ascensionDay;

  /// Rolling 7-day mission-completion consistency (0..100) from
  /// StreakService.progress. The 30% CONSISTENCY component of the
  /// IMHIM score.
  final int consistency;

  /// Did the user complete their protocol check-in today?
  final bool looksDoneToday;

  /// Did the user complete a Free Flow / roleplay session today?
  final bool gameDoneToday;

  /// v289 — Did the user generate a rizz reply today?
  final bool rizzDoneToday;

  /// v301 — Did the user copy a pickup line today?
  final bool pickupLineDoneToday;

  /// v289 — latest Looks pillar score, 0-100 raw scale. Feeds the
  /// IMHIM-score formula.
  final int looksScore100;

  /// v289 — best Free Flow / Game pillar score, 0-100 raw scale.
  /// Feeds the IMHIM-score formula.
  final int gameScore100;

  const AscendScreen({
    super.key,
    required this.onJumpToTab,
    this.onRefresh,
    this.longestStreak = 0,
    this.protocol,
    this.latest,
    this.allScans = const [],
    this.dayStreak = 0,
    this.ascensionDay = 1,
    this.consistency = 0,
    this.looksDoneToday = false,
    this.gameDoneToday = false,
    this.rizzDoneToday = false,
    this.pickupLineDoneToday = false,
    this.looksScore100 = 0,
    this.gameScore100 = 0,
  });

  @override
  State<AscendScreen> createState() => _AscendScreenState();
}

class _AscendScreenState extends State<AscendScreen> {
  /// Cached weekly delta — the diff between the user's current
  /// IMHIM score and the prior weekly snapshot. Pre-loaded on first
  /// build so the score hero can render the arrow synchronously.
  int _weeklyDelta = 0;
  bool _deltaLoaded = false;
  int _xp = 0;
  List<MissionSpec> _newMissions = const [];
  Map<String, bool> _newDone = const {};

  @override
  void initState() {
    super.initState();
    _loadDeltaAndSnapshot();
  }

  String _fmtXp(int xp) {
    final s = xp.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b XP';
  }

  /// Read whatever prior snapshot the prefs have, compute the
  /// delta, then write today's score back so the next visit has a
  /// fresh reference point. Idempotent per calendar day — multiple
  /// taps on the tab don't move the "prior" slot.
  Future<void> _loadDeltaAndSnapshot() async {
    final score = AscensionService.imhimScoreFromComponents(
      looks:       widget.looksScore100,
      game:        widget.gameScore100,
      consistency: widget.consistency,
    );
    final delta = await AscensionService.weeklyDeltaFor(score);
    await AscensionService.snapshotTodayScore(score);
    final xp = await LocalStoreService.xpTotal();
    final missions = await MissionEngine.loadToday();
    final done = <String, bool>{};
    for (final m in missions) {
      done[m.id] = await LocalStoreService.isMissionDoneToday(m.id);
    }
    if (!mounted) return;
    setState(() {
      _weeklyDelta = delta;
      _deltaLoaded = true;
      _xp = xp;
      _newMissions = missions;
      _newDone = done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final day            = widget.ascensionDay;
    final daysLeft       = AscensionService.daysRemainingFor(day);
    final missions       = _buildMissions();
    final missionsDone   = missions.where((m) => m.done).length;
    final todayMsg       = AscensionService.todayMessageFor(
      day: day, streak: widget.dayStreak);
    final milestones     = _buildMilestones();
    final finalUnlocked  = AscensionService.finalFormUnlockedFor(day);
    final longestStreak  = widget.longestStreak > widget.dayStreak
        ? widget.longestStreak
        : widget.dayStreak;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.red,
          backgroundColor: AppColors.surface1,
          onRefresh: () async {
            await widget.onRefresh?.call();
            await _loadDeltaAndSnapshot();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Sp.xl),
            children: [
            // v292 — masthead matches Looks / Rizz: wordmark, then
            // the streak flame (gated > 0 like the other tabs so a
            // brand-new user doesn't see a dead "0 day" chip),
            // progress chart, settings cog. Bro: "add the progress
            // and streak icons on rizz and ascend."
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // XP counter, matching the Missions tab. Wordmark lives
                  // only on Missions now; the old progress-chart icon is
                  // gone (this IS the progress tab).
                  XpBadge(label: _fmtXp(_xp)),
                  const Spacer(),
                  if (widget.dayStreak > 0) ...[
                    StreakBadge(days: widget.dayStreak),
                    const SizedBox(width: 8),
                  ],
                  _MastheadSettingsCog(
                    onTap: () => context.push('/settings')),
                ],
              ),
            ),

            const SizedBox(height: Sp.lg),

            // ── 1 — HERO. THE ASCENSION MAP. The visible path from where
            // the user is today to "Become Him". Every other system feeds
            // it: finishing missions moves you forward, bosses sit at the
            // 10-day nodes, unlocks appear on the node that grants them.
            // The map is the front door — CLIMB jumps straight to today's
            // missions.
            AscensionMap(
              day:        day,
              onContinue: () => widget.onJumpToTab(0),
            ).animate().fadeIn(duration: 480.ms)
              .slideY(begin: 0.04, curve: Curves.easeOut),

            const SizedBox(height: Sp.lg),

            // ── 2 — THE FIVE. Charmr's scored dimensions replace the
            // old im-him composite: Confidence, Presence, Humor,
            // Listening, Game → a weighted total. One character to level.
            const MetricsPanel()
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: Sp.md),

            // Flex your game — a sick share card of THE FIVE + your rank.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              child: Material(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () { HapticFeedback.mediumImpact(); _shareStats(); },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.ios_share_rounded,
                            color: AppColors.red, size: 18),
                        const SizedBox(width: 10),
                        Text('SHARE MY GAME',
                            style: GoogleFonts.inter(
                              color: AppColors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 260.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── 3 — TODAY'S MESSAGE. Single rotating identity line
            // (v289 replaced Cost of Quitting — fear was a one-shot
            // drug, identity is the loop).
            if (todayMsg.isNotEmpty) ...[
              _TodayMessageCard(line: todayMsg)
                .animate().fadeIn(delay: 280.ms, duration: 400.ms),
              const SizedBox(height: Sp.lg),
            ],

            // ── 4 — TODAY'S ASCENSION. Pillar-mapped missions.
            _MissionsPanel(
              missions: missions,
              done:     missionsDone,
            ).animate().fadeIn(delay: 360.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── 5 — STREAK. Hero treatment per the consultant. (The rank
            // ladder that used to sit here is now the Ascension Map hero.)
            _StreakPanel(
              current: widget.dayStreak,
              longest: longestStreak,
            ).animate().fadeIn(delay: 520.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── 7 — ASCENSION RECORD. Timeline of milestones.
            _RecordTimeline(milestones: milestones)
              .animate().fadeIn(delay: 600.ms, duration: 400.ms),

            const SizedBox(height: Sp.lg),

            // ── 8 — FINAL FORM. Locked premium reward / unlocked
            // certificate generator.
            _FinalFormCard(
              unlocked:    finalUnlocked,
              daysLeft:    daysLeft,
              onGenerate:  finalUnlocked ? _generateCertificate : null,
            ).animate().fadeIn(delay: 680.ms, duration: 400.ms),

            const SizedBox(height: Sp.xl),
          ],
        ),
        ),
      ),
    );
  }

  // ── Mission builder ─────────────────────────────────────────────────────
  // Mirrors the exact daily set the Missions tab shows (the MissionEngine),
  // so the Progress panel and the Missions tab never disagree. Tapping any
  // row jumps to the Missions tab to actually do it.
  List<AscendMission> _buildMissions() {
    // The NEW daily-missions engine — the exact set the Missions tab shows.
    // (The old looks / scan / render mission copy is gone.)
    return [
      for (final m in _newMissions)
        AscendMission(
          title: m.title,
          hint: (_newDone[m.id] == true) ? 'done — banked.' : m.sub,
          done: _newDone[m.id] == true,
          onTap: () => widget.onJumpToTab(0),
        ),
    ];
  }

  /// Share a flex card of THE FIVE + overall + rank. Reuses the proven
  /// ScoreShareCard (ImHim wordmark = clear app name, big score, five metric
  /// bars, a killer line) so it always reads as one brand.
  Future<void> _shareStats() async {
    final dims    = await LocalStoreService.dimensionScores();
    final overall = await LocalStoreService.overallScore();
    final day     = widget.ascensionDay;
    final rank    = AscensionService.rankFor(day);
    const order = <(String, String)>[
      ('confidence', 'CONFIDENCE'),
      ('presence', 'PRESENCE'),
      ('game', 'GAME'),
      ('humor', 'HUMOUR'),
      ('listening', 'LISTENING'),
    ];
    final stats = [
      for (final (k, l) in order)
        (label: l, score: ((dims[k] ?? 0) / 10).round()),
    ];
    if (!mounted) return;
    await ShareService.shareScore(
      context:   context,
      kindLabel: 'MY GAME',
      subLabel:  'DAY $day',
      score:     (overall / 10).round(),
      badge:     rank.label,
      verdict:   _killerLine(overall),
      stats:     stats,
    );
  }

  String _killerLine(int overall) {
    if (overall >= 80) return 'The room already knows.';
    if (overall >= 65) return 'I don\'t miss the moment anymore.';
    if (overall >= 45) return 'Sharper every single rep.';
    return 'Watch what 60 days does.';
  }

  /// Generate the BECOME HIM certificate — a commitment card, not a looks
  /// before/after. Pulls the honest "showed up" numbers straight from the
  /// on-device stores so it renders offline: days shown up, best streak,
  /// consistency, The Five (+ breakdown), total XP, and the reached rank.
  Future<void> _generateCertificate() async {
    if (!mounted) return;
    final day = widget.ascensionDay;
    final streak = widget.longestStreak > widget.dayStreak
        ? widget.longestStreak
        : widget.dayStreak;
    final consistency = widget.consistency;
    final dims    = await LocalStoreService.dimensionScores();
    final overall = await LocalStoreService.overallScore();
    final xp      = await LocalStoreService.xpTotal();
    final commit  = AscensionService.commitmentTierFor(
      day: day, consistency: consistency, streak: streak);
    final rank    = AscensionService.rankFor(day);

    if (!mounted) return;
    await ShareService.shareCertificate(
      context:         context,
      rankLabel:       rank.label,
      day:             day,
      streak:          streak,
      consistency:     consistency,
      overall:         overall,
      dims:            dims,
      commitmentLabel: commit.label,
      commitmentScore: commit.score,
      xp:              xp,
    );
  }

  // ── Milestone builder ────────────────────────────────────────────────────
  //
  // Real records, derived from existing data. Bro: "This becomes
  // their story." For v1 we surface:
  //   - Protocol start ("DAY 1 — You committed.")
  //   - Each completed scan ("DAY N — Rescan logged.")
  //   - Streak milestones (3, 7, 14, 30 day flags)
  //   - Today's day count (always last entry, "DAY N — Today.")
  // Sorted reverse-chronological so the latest action is at the top
  // of the visible list.
  List<AscendMilestone> _buildMilestones() {
    final out = <AscendMilestone>[];
    final p   = widget.protocol;
    if (p != null) {
      out.add(AscendMilestone(
        day:    1,
        title:  'You committed',
        detail: 'Day 1 of the ${p.lengthDays}-day ascension.',
      ));
      // Streak flags
      for (final mark in const [3, 7, 14, 21, 30, 45, 60]) {
        if (p.effectiveStreak >= mark) {
          out.add(AscendMilestone(
            day:    mark,
            title:  '$mark-day streak',
            detail: 'You showed up $mark days in a row.',
          ));
        }
      }
    }
    // Scan history — newest at the top of this loop; we'll sort below.
    for (final s in widget.allScans.take(8)) {
      final dayAt = p == null
          ? 1
          : (s.takenAt.difference(p.startedAt).inDays + 1).clamp(1, 999);
      out.add(AscendMilestone(
        day:    dayAt,
        title:  'Scan logged',
        detail: 'Score ${s.score} · ${_humanDate(s.takenAt)}',
      ));
    }
    out.sort((a, b) => b.day.compareTo(a.day));
    return out;
  }

  static String _humanDate(DateTime t) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 1 — FLAME HERO
// ═══════════════════════════════════════════════════════════════════════════

/// Big flame + ring. Day-N / total-N inside, identity rank label
/// directly under, days-remaining + rank tagline beneath that.
class _FlameHero extends StatefulWidget {
  final int day;
  final int total;
  final AscendRank rank;
  final int daysLeft;
  const _FlameHero({
    required this.day,
    required this.total,
    required this.rank,
    required this.daysLeft,
  });
  @override
  State<_FlameHero> createState() => _FlameHeroState();
}

class _FlameHeroState extends State<_FlameHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final progress = (widget.day / widget.total).clamp(0.0, 1.0);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.red.withValues(alpha: 0.30 + 0.20 * t),
                            blurRadius: 60 + 24 * t,
                            spreadRadius: 4 + 4 * t,
                          ),
                        ],
                      ),
                    ),
                    // Progress ring
                    CustomPaint(
                      size: Size.infinite,
                      painter: _ProgressRingPainter(progress: progress),
                    ),
                    // Inner flame disc
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF14141A),
                              AppColors.red.withValues(alpha: 0.55),
                              AppColors.accentDeep.withValues(alpha: 0.9),
                            ],
                            stops: const [0.34, 0.8, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.55),
                              blurRadius: 40 + 12 * t,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('DAY',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14, letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                )),
                              const SizedBox(height: 6),
                              Text('${widget.day}',
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontSize: 96, height: 1,
                                  letterSpacing: -3,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                )),
                              const SizedBox(height: 2),
                              Text('/ ${widget.total}',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14, letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: Sp.md),
        Text(widget.rank.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 14, letterSpacing: 4,
            fontWeight: FontWeight.w900,
          )),
        const SizedBox(height: 4),
        Text(
          widget.daysLeft == 0
            ? 'You did it. Day 60.'
            : '${widget.daysLeft} day${widget.daysLeft == 1 ? "" : "s"} remaining',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13, letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Sp.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.rank.tagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 18, height: 1.35,
              letterSpacing: -0.4,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  _ProgressRingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final track = Paint()
      ..color = AppColors.surface3.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFE8222A), Color(0xFFFF7A45), Color(0xFFE8222A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final sweep = (2 * math.pi) * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fill,
    );
  }
  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 2 — COST OF QUITTING
// ═══════════════════════════════════════════════════════════════════════════

/// v289 — IMHIM SCORE hero. The composite that levels the whole
/// app into one character. Hero number in red, weekly delta arrow
/// underneath, three component pillars stacked below as the
/// "built from" credit row. Sits directly under the flame so the
/// user reads day + score as one unit.
class _ImHimScoreHero extends StatelessWidget {
  final int score;
  final int delta;
  final bool deltaReady;
  final int looks;
  final int game;
  final int consistency;
  const _ImHimScoreHero({
    required this.score,
    required this.delta,
    required this.deltaReady,
    required this.looks,
    required this.game,
    required this.consistency,
  });

  @override
  Widget build(BuildContext context) {
    final deltaText = !deltaReady
        ? '—'
        : delta == 0
            ? '+0 this week'
            : delta > 0
                ? '↑ +$delta this week'
                : '↓ $delta this week';
    final deltaColor = !deltaReady || delta == 0
        ? AppColors.textTertiary
        : delta > 0
            ? AppColors.signalGreen
            : AppColors.signalAmber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('IMHIM SCORE',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10.5, letterSpacing: 3.2,
                fontWeight: FontWeight.w900,
              )),
            const SizedBox(height: 6),
            Text('$score',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 72, height: 1,
                letterSpacing: -2.4,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              )),
            const SizedBox(height: 6),
            Text(deltaText,
              style: GoogleFonts.inter(
                color: deltaColor,
                fontSize: 12.5, letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              )),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5,
              color: AppColors.divider),
            const SizedBox(height: 14),
            Text('BUILT FROM',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 9, letterSpacing: 2.4,
                fontWeight: FontWeight.w800,
              )),
            const SizedBox(height: 10),
            _ImHimComponentRow(label: 'Looks',       value: looks,        accent: AppColors.measure),
            const SizedBox(height: 6),
            _ImHimComponentRow(label: 'Game',        value: game,         accent: AppColors.accent),
            const SizedBox(height: 6),
            _ImHimComponentRow(label: 'Consistency', value: consistency,  accent: AppColors.red),
          ],
        ),
      ),
    );
  }
}

class _ImHimComponentRow extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;
  const _ImHimComponentRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final width = (value / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12.5, letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: AppColors.surface3.withValues(alpha: 0.55),
                ),
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: 5,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text('$value',
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textPrimary,
              fontSize: 13, letterSpacing: 0.3,
              fontWeight: FontWeight.w800,
            )),
        ),
      ],
    );
  }
}

/// v289 — Today's Message. Single rotating identity line that
/// replaces the manufactured fear of the Cost of Quitting card.
/// Day-indexed copy, streak-milestone overrides — see
/// [AscensionService.todayMessageFor].
class _TodayMessageCard extends StatelessWidget {
  final String line;
  const _TodayMessageCard({required this.line});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border(
            left: BorderSide(color: AppColors.red, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10, letterSpacing: 2.8,
                fontWeight: FontWeight.w900,
              )),
            const SizedBox(height: 8),
            Text(line,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textPrimary,
                fontSize: 18, height: 1.35,
                letterSpacing: -0.4,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 3 — TODAY'S ASCENSION (missions)
// ═══════════════════════════════════════════════════════════════════════════

class _MissionsPanel extends StatelessWidget {
  final List<AscendMission> missions;
  final int done;
  const _MissionsPanel({required this.missions, required this.done});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('TODAY\'S ASCENSION',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11, letterSpacing: 2.8,
                    fontWeight: FontWeight.w900,
                  )),
                const Spacer(),
                Text('$done / ${missions.length} COMPLETE',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11, letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  )),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < missions.length; i++) ...[
              _MissionRow(mission: missions[i]),
              if (i != missions.length - 1)
                Divider(
                  height: 1, thickness: 0.6,
                  color: AppColors.surface3.withValues(alpha: 0.55),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final AscendMission mission;
  const _MissionRow({required this.mission});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: mission.onTap == null ? null : () {
          HapticFeedback.selectionClick();
          mission.onTap!();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _MissionCheck(done: mission.done),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.title,
                      style: GoogleFonts.inter(
                        color: mission.done
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                        fontSize: 15, height: 1.2,
                        fontWeight: FontWeight.w700,
                        decoration: mission.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      )),
                    if (mission.hint.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(mission.hint,
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 12, height: 1.3,
                          fontWeight: FontWeight.w500,
                        )),
                    ],
                  ],
                ),
              ),
              if (mission.onTap != null && !mission.done)
                const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionCheck extends StatelessWidget {
  final bool done;
  const _MissionCheck({required this.done});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.red : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.red : AppColors.surface3,
          width: 1.5,
        ),
      ),
      child: done
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
        : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 4 — RANK PROGRESSION
// ═══════════════════════════════════════════════════════════════════════════

class _RankProgression extends StatelessWidget {
  final int currentDay;
  const _RankProgression({required this.currentDay});
  @override
  Widget build(BuildContext context) {
    final ranks = AscensionService.ranks();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THE MAN YOU ARE BUILDING',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10, letterSpacing: 2.8,
                fontWeight: FontWeight.w900,
              )),
            const SizedBox(height: 14),
            for (var i = 0; i < ranks.length; i++) ...[
              _RankRow(
                rank:     ranks[i],
                isPassed: currentDay > ranks[i].minDay,
                isCurrent: currentDay >= ranks[i].minDay &&
                           (i == ranks.length - 1 ||
                            currentDay < ranks[i + 1].minDay),
              ),
              if (i != ranks.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final AscendRank rank;
  final bool isPassed;
  final bool isCurrent;
  const _RankRow({
    required this.rank,
    required this.isPassed,
    required this.isCurrent,
  });
  @override
  Widget build(BuildContext context) {
    final reached = isPassed || isCurrent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text('DAY ${rank.minDay}',
            style: GoogleFonts.inter(
              color: reached ? AppColors.red : AppColors.textTertiary,
              fontSize: 10, letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
        ),
        const SizedBox(width: 8),
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
              ? AppColors.red
              : (isPassed ? AppColors.red.withValues(alpha: 0.65)
                          : Colors.transparent),
            border: Border.all(
              color: reached ? AppColors.red : AppColors.surface3,
              width: 1.5,
            ),
            boxShadow: isCurrent
              ? [BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.6),
                  blurRadius: 12)]
              : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(rank.label,
            style: GoogleFonts.inter(
              color: reached ? AppColors.textPrimary : AppColors.textTertiary,
              fontSize: 16, height: 1.2,
              letterSpacing: 1.4,
              fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
              fontStyle: isCurrent ? FontStyle.italic : FontStyle.normal,
            )),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('YOU',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 9, letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              )),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 5 — ASCENSION RECORD (timeline)
// ═══════════════════════════════════════════════════════════════════════════

class _RecordTimeline extends StatelessWidget {
  final List<AscendMilestone> milestones;
  const _RecordTimeline({required this.milestones});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASCENSION RECORD',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10, letterSpacing: 2.8,
                fontWeight: FontWeight.w900,
              )),
            const SizedBox(height: 14),
            if (milestones.isEmpty)
              Text('Your record writes itself the moment you log day one.',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 13, height: 1.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                )),
            for (var i = 0; i < milestones.length; i++) ...[
              _MilestoneRow(milestone: milestones[i]),
              if (i != milestones.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final AscendMilestone milestone;
  const _MilestoneRow({required this.milestone});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text('DAY ${milestone.day}',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 10, letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(milestone.title,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14, height: 1.3,
                  fontWeight: FontWeight.w700,
                )),
              if (milestone.detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(milestone.detail,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 12, height: 1.35,
                    fontWeight: FontWeight.w500,
                  )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 6 — STREAK
// ═══════════════════════════════════════════════════════════════════════════

/// v303 — Streak panel rebuilt. Flame icon + numeral are now ONE
/// lockup. Bro: "the streak is dislocated and a dud. fix it
/// production grade only fix perfectly." Old layout had the flame
/// floating up in the label row and the numeral isolated below —
/// they read as two unrelated things. New layout pins the flame
/// directly against the number at matching visual weight so the
/// pair anchors as a single hero element.
class _StreakPanel extends StatelessWidget {
  final int current;
  final int longest;
  const _StreakPanel({required this.current, required this.longest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          // Warm red radial behind the lockup so the flame reads
          // as actually glowing on the surface, not a flat icon.
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.2),
            radius: 1.2,
            colors: [
              AppColors.red.withValues(alpha: 0.20),
              AppColors.surface1,
            ],
          ),
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.42), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.28),
              blurRadius: 32, spreadRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Eyebrow row: label left, LONGEST right.
            Row(
              children: [
                Text('STREAK',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11, letterSpacing: 3.2,
                    fontWeight: FontWeight.w900,
                  )),
                const Spacer(),
                Text('LONGEST $longest',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 10, letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  )),
              ],
            ),
            const SizedBox(height: 10),

            // ── THE LOCKUP — flame, number, "DAY" label, all on
            // the same baseline at matching visual weight. Stack
            // gives the flame a soft outer halo before the icon
            // renders so it reads as glowing, not stamped.
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Halo behind the flame.
                  Positioned(
                    left: -6, bottom: 4,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.red.withValues(alpha: 0.42),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.red, size: 88),
                      const SizedBox(width: 6),
                      // The numeral. Italic Playfair, white, sized
                      // to match the flame's optical height so the
                      // pair reads as one unit.
                      Text('$current',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 92, height: 1,
                          letterSpacing: -3.4,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: AppColors.red.withValues(alpha: 0.45),
                              blurRadius: 18),
                          ],
                        )),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(current == 1 ? 'DAY' : 'DAYS',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 14, letterSpacing: 3.0,
                            fontWeight: FontWeight.w900,
                          )),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(_streakStatusLine(current, longest),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13, height: 1.4,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
              )),
          ],
        ),
      ),
    );
  }

  /// Honest one-line status, not fake percentile copy. Reads off
  /// the user's actual numbers.
  static String _streakStatusLine(int current, int longest) {
    if (current == 0)                return 'No streak yet. Log today and ignite.';
    if (current == 1)                return 'Day one. Make it stick.';
    if (current >= longest)          return 'Best run yet. Don\'t break it.';
    return 'Longest: $longest. Catch it.';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 7 — FINAL FORM (locked or unlocked at day 60)
// ═══════════════════════════════════════════════════════════════════════════

class _FinalFormCard extends StatelessWidget {
  final bool unlocked;
  final int daysLeft;
  /// v291 — invoked when the user taps GENERATE CERTIFICATE on the
  /// unlocked card. The State subclass owns the data collection
  /// (first/last scan, looks/game arcs, IMHIM start/end) and the
  /// ShareService call. Null when locked so the build path can
  /// hide the CTA entirely.
  final Future<void> Function()? onGenerate;
  const _FinalFormCard({
    required this.unlocked,
    required this.daysLeft,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(
            color: unlocked
              ? AppColors.red
              : AppColors.red.withValues(alpha: 0.35),
            width: unlocked ? 1.6 : 0.8,
          ),
          boxShadow: unlocked
            ? [BoxShadow(
                color: AppColors.red.withValues(alpha: 0.30),
                blurRadius: 42, spreadRadius: 0)]
            : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: AppColors.red, size: 16),
                const SizedBox(width: 8),
                Text(unlocked ? 'UNLOCKED · DAY 60' : 'LOCKED · DAY 60',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 10, letterSpacing: 2.8,
                    fontWeight: FontWeight.w900,
                  )),
              ],
            ),
            const SizedBox(height: 10),
            Text('BECOME HIM',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textPrimary,
                fontSize: 30, height: 1.1,
                letterSpacing: -0.8,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              )),
            const SizedBox(height: 14),
            Text(
              unlocked
                ? 'You finished the 60 days. Generate your card — your '
                  'commitment level, best streak, consistency, The Five and '
                  'the XP you banked, on one card people will screenshot.'
                : 'Reach Day 60 to unlock:',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13.5, height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in const [
              'Your commitment level — Warming Up → Unbreakable',
              'Days shown up + best streak',
              'Consistency + The Five breakdown',
              'Total XP banked',
              'Shareable Become Him card',
            ]) Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_rounded,
                    color: unlocked
                      ? AppColors.red
                      : AppColors.red.withValues(alpha: 0.45),
                    size: 14),
                  const SizedBox(width: 8),
                  Text(line,
                    style: GoogleFonts.inter(
                      color: unlocked
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                      fontSize: 13, height: 1.4,
                      fontWeight: FontWeight.w600,
                    )),
                ],
              ),
            ),
            if (!unlocked) ...[
              const SizedBox(height: 8),
              Text('$daysLeft day${daysLeft == 1 ? "" : "s"} to go.',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 12, letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                )),
            ],
            if (unlocked && onGenerate != null) ...[
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () { HapticFeedback.mediumImpact(); onGenerate!(); },
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.5),
                          blurRadius: 22, spreadRadius: 0),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text('GENERATE CERTIFICATE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12, letterSpacing: 2.4,
                            fontWeight: FontWeight.w900,
                          )),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  v292 — Ascend masthead chips. Same visual treatment the Looks +
//  Rizz mastheads use; duplicated locally so the Ascend tab stays
//  self-contained (those tabs have their own private chip widgets,
//  and dragging them into a shared file would couple three
//  unrelated screens).
// ═══════════════════════════════════════════════════════════════════════════

/// v303 — Masthead streak chip. Solid red fill (was 14% tinted
/// ghost), white flame + white digit, soft red glow shadow so the
/// chip reads as one of the strongest visual elements on the
/// chrome row instead of disappearing into the background. Same
/// lockup the Looks + Rizz mastheads now use for consistency.

class _MastheadSettingsCog extends StatelessWidget {
  final VoidCallback onTap;
  const _MastheadSettingsCog({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.divider, width: 0.8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.tune,
            size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
