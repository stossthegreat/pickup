import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backend/daily_game_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/academy_modal.dart';
import '../game/freeflow/free_flow_screen.dart';

/// THE DAILY — the appointment. One scenario, the same for the whole
/// world, ONE attempt. Below it: your league, with the promotion zone,
/// the drop zone, and the Sunday-21:00 lock counting down on screen.
/// This screen is the Duolingo engine wearing our black-and-red.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DailyStatus? _s;
  bool _loading = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // drive the countdowns
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DailyGameService.status();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
    // Week-end verdict — fire the ceremony once.
    if (s?.ceremony == 'promoted' || s?.ceremony == 'relegated') {
      final promoted = s!.ceremony == 'promoted';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AcademyModal.show(
          context,
          kicker: promoted ? 'PROMOTED' : 'RELEGATED',
          accent: promoted ? kNeon : AppColors.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  promoted
                      ? 'You climbed to ${s.league.divisionName}.'
                      : 'You dropped to ${s.league.divisionName}.',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                  promoted
                      ? 'New league. Harder men. Keep climbing.'
                      : 'One week to take it back. Run the daily.',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              AcademyButton(
                  label: promoted ? 'KEEP CLIMBING' : 'TAKE IT BACK',
                  onTap: () => Navigator.of(context).pop()),
            ],
          ),
        );
      });
    }
  }

  /// Launch the one attempt — armed session; the transcript submits
  /// itself at session end (same pattern as battles).
  Future<void> _run() async {
    final s = _s;
    if (s == null || s.attempted) return;
    HapticFeedback.heavyImpact();
    DailyGameService.armedDaily = true;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => FreeFlowScreen(initialVibeKey: s.scenarioKey),
    ));
    DailyGameService.armedDaily = false;
    if (!mounted) return;
    // The hook parked the result — reveal it.
    final r = DailyGameService.lastResult;
    if (r != null) {
      DailyGameService.lastResult = null;
      final beatWorld = r.score >= r.worldAvg;
      AcademyModal.show(
        context,
        kicker: 'THE DAILY — SCORED',
        accent: beatWorld ? kNeon : AppColors.red,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${r.score}',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('#${r.rankToday} IN THE WORLD TODAY · AVG ${r.worldAvg}',
                style: GoogleFonts.inter(
                    color: beatWorld ? kNeon : AppColors.textSecondary,
                    fontSize: 12.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AcademyButton(
              label: 'SHARE IT',
              onTap: () {
                Share.share('THE DAILY on ImHim Rizz: ${r.score} — '
                    '#${r.rankToday} in the world today (avg ${r.worldAvg}). '
                    'One attempt. Same scenario. Your turn.');
              },
            ),
            const SizedBox(height: 8),
            AcademyButton(
                label: 'CLOSE',
                ghost: true,
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
    }
    _load();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    if (d.inDays > 0) return '${d.inDays}D ${two(h % 24)}H';
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  Duration get _untilReset {
    final now = DateTime.now().toUtc();
    final midnight =
        DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
    return midnight.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red)))
            : s == null
                ? _offline()
                : RefreshIndicator(
                    color: AppColors.red,
                    backgroundColor: AppColors.surface1,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      children: [
                        Row(children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18, color: Colors.white),
                          ),
                          Text('THE DAILY',
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
                              )),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('RESETS ${_fmt(_untilReset)}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800,
                                )),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _scenarioHero(s),
                        const SizedBox(height: 22),
                        _board(s),
                        const SizedBox(height: 22),
                        _league(s.league),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _offline() => Center(
        child: Text('THE DAILY needs a connection.',
            style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  // ── Scenario hero + the one shot ────────────────────────────────────
  Widget _scenarioHero(DailyStatus s) {
    final label = s.scenarioKey.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.red.withValues(alpha: 0.22),
            AppColors.surface1,
          ],
        ),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(color: AppColors.redGlow, blurRadius: 34)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TODAY · THE WHOLE WORLD · ONE SHOT EACH',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 10,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 8),
        Text('SHE\'S $label.',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 34,
              height: 1.05,
              letterSpacing: -1,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 16),
        if (s.attempted) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${s.myScore}',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: AppColors.red.withValues(alpha: 0.5),
                        blurRadius: 30)
                  ],
                )),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                  s.worldAvg == null ? 'SCORED' : 'WORLD AVG ${s.worldAvg}',
                  style: GoogleFonts.inter(
                    color: (s.myScore ?? 0) >= (s.worldAvg ?? 0)
                        ? kNeon
                        : AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Shot taken. New scenario at reset.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ] else ...[
          SizedBox(
            height: 58,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('ONE SHOT — RUN IT',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.02, duration: 900.ms),
          const SizedBox(height: 8),
          Text('No retries. No warm-up. This is the rep that counts.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              )),
        ],
      ]),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ── Today's world board ─────────────────────────────────────────────
  Widget _board(DailyStatus s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TODAY\'S BOARD',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 10.5,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 10),
      if (s.board.isEmpty)
        Text('Nobody has taken their shot yet. Be first.',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ))
      else
        for (final (i, e) in s.board.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              SizedBox(
                width: 30,
                child: Text('#${i + 1}',
                    style: GoogleFonts.inter(
                      color: i == 0 ? AppColors.red : AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              Expanded(
                child: Text(e.handle ?? 'ANON',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              Text('${e.score}',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
    ]);
  }

  // ── The league — zones + the Sunday lock ────────────────────────────
  Widget _league(LeagueState l) {
    final untilLock = l.locksAt.difference(DateTime.now().toUtc());
    final (zoneColor, zoneText) = switch (l.zone) {
      'promotion' => (kNeon, 'PROMOTION ZONE — TOP 10 GO UP'),
      'drop' => (AppColors.red, 'DROP ZONE — BOTTOM 5 GO DOWN'),
      _ => (AppColors.textSecondary, 'SAFE — FOR NOW'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zoneColor.withValues(alpha: 0.5)),
        boxShadow: l.zone != 'safe'
            ? [BoxShadow(color: zoneColor.withValues(alpha: 0.2), blurRadius: 26)]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.divisionName,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 15,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text('LOCKS ${_fmt(untilLock)}',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              )),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('#${l.rank}',
              style: GoogleFonts.inter(
                color: zoneColor,
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: l.zone != 'safe'
                    ? [
                        Shadow(
                            color: zoneColor.withValues(alpha: 0.6),
                            blurRadius: 22)
                      ]
                    : null,
              )),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('OF ${l.size} · ${l.points} PTS',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
        const SizedBox(height: 8),
        Text(zoneText,
            style: GoogleFonts.inter(
              color: zoneColor,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 6),
        Text(
            'Every rep counts — dailies, roleplay sessions, battles all '
            'feed your points. Sunday it locks: top 10 climb, bottom 5 drop.',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            )),
      ]),
    ).animate().fadeIn(duration: 350.ms);
  }
}
