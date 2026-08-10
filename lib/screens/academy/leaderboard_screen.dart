import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/daily_game_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/league_crest.dart';

/// THE BOARD — the league table, built the way the best ones are: the
/// crest as the hero, the full field ranked, and the two lines that
/// create all the tension — the PROMOTION CUT and the RELEGATION CUT.
/// You always see exactly how far you are from climbing and how close
/// you are to falling.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _league = true; // league table vs all-time
  bool _loading = true;
  DailyStatus? _s;
  List<LeaderboardEntry> _allTime = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await DailyGameService.status();
    final all = await LeaderboardService.global();
    if (!mounted) return;
    setState(() {
      _s = s;
      _allTime = all;
      _loading = false;
    });
  }

  String _fmt(Duration d) {
    if (d.isNegative) return 'LOCKED';
    if (d.inDays > 0) return '${d.inDays}D ${d.inHours % 24}H';
    if (d.inHours > 0) return '${d.inHours}H ${d.inMinutes % 60}M';
    return '${d.inMinutes}M';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: _loading
          ? const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red)))
          : SafeArea(
              child: Column(children: [
                _topBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.red,
                    backgroundColor: AppColors.surface1,
                    onRefresh: _load,
                    child: _league ? _leagueTable() : _allTimeTable(),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 18, 8),
      child: Row(children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.white),
        ),
        Expanded(
          child: Row(children: [
            _tab('LEAGUE', _league, () => setState(() => _league = true)),
            const SizedBox(width: 8),
            _tab('ALL TIME', !_league, () => setState(() => _league = false)),
          ]),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            context.push('/battles');
          },
          icon: const Icon(Icons.sports_mma_rounded,
              size: 20, color: AppColors.red),
        ),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.35),
                      blurRadius: 16)
                ]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: active ? Colors.white : AppColors.textTertiary,
              fontSize: 10.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE LEAGUE TABLE
  // ══════════════════════════════════════════════════════════════════

  Widget _leagueTable() {
    final s = _s;
    if (s == null) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(
          child: Text('The league needs a connection.',
              style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
    }
    final l = s.league;
    final me = AuthService.userId;
    final rows = l.standings;
    final promoteCut = l.promoteTop;
    final dropCut = rows.length - l.relegateBottom;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        _leagueHero(l),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          _emptyLeague()
        else
          for (var i = 0; i < rows.length; i++) ...[
            // ── The cut lines: where all the tension lives ─────────
            if (i == promoteCut && rows.length > promoteCut)
              _cutLine('PROMOTION CUT', kNeon, Icons.arrow_upward_rounded),
            if (i == dropCut && dropCut > promoteCut)
              _cutLine(
                  'RELEGATION CUT', AppColors.red, Icons.arrow_downward_rounded),
            _row(
              rank: i + 1,
              handle: rows[i].handle,
              points: rows[i].points,
              mine: rows[i].userId == me,
              zone: i < promoteCut
                  ? 'promotion'
                  : i >= dropCut
                      ? 'drop'
                      : 'safe',
            ).animate().fadeIn(
                delay: (28 * i).clamp(0, 600).ms, duration: 240.ms),
          ],
      ],
    );
  }

  Widget _leagueHero(LeagueState l) {
    final zone = switch (l.zone) {
      'promotion' => kNeon,
      'drop' => AppColors.red,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            crestPalette(l.division).metalMid.withValues(alpha: 0.18),
            AppColors.surface1,
          ],
        ),
        border: Border.all(
            color: crestPalette(l.division)
                .metalMid
                .withValues(alpha: 0.45)),
      ),
      child: Column(children: [
        LeagueCrest(division: l.division, size: 96)
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack),
        const SizedBox(height: 12),
        Text(l.divisionName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 4),
        Text('TOP ${l.promoteTop} CLIMB · BOTTOM ${l.relegateBottom} FALL',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: zone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: zone.withValues(alpha: 0.55)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_clock_rounded, size: 13, color: zone),
            const SizedBox(width: 7),
            Text('LOCKS IN ${_fmt(l.locksAt.difference(DateTime.now().toUtc()))}',
                style: GoogleFonts.inter(
                  color: zone,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ),
      ]),
    );
  }

  /// The dashed cut line — the single most important pixel on the board.
  Widget _cutLine(String label, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: _Dashes(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 9.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ),
        Expanded(child: _Dashes(color: color)),
      ]),
    );
  }

  Widget _row({
    required int rank,
    required String? handle,
    required int points,
    required bool mine,
    required String zone,
  }) {
    final zoneColor = switch (zone) {
      'promotion' => kNeon,
      'drop' => AppColors.red,
      _ => AppColors.textMuted,
    };
    final medal = switch (rank) {
      1 => const Color(0xFFF5C542),
      2 => const Color(0xFFC5CDD8),
      3 => const Color(0xFFCE8946),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: mine ? AppColors.surface2 : AppColors.surface1,
        borderRadius: BorderRadius.circular(15),
        border: mine
            ? Border.all(color: AppColors.red, width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: mine
            ? [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.28),
                    blurRadius: 22)
              ]
            : null,
      ),
      child: Row(children: [
        // Zone edge — a colour stripe so the band is readable at a glance.
        Container(
          width: 4,
          height: 54,
          decoration: BoxDecoration(
            color: zone == 'safe' ? Colors.transparent : zoneColor,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(15)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 26,
          child: medal != null
              ? Icon(Icons.workspace_premium_rounded, size: 19, color: medal)
              : Text('$rank',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  )),
        ),
        const SizedBox(width: 10),
        _Avatar(
          label: mine ? 'YOU' : (handle ?? 'A'),
          ring: medal ?? (mine ? AppColors.red : Colors.white24),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(mine ? 'YOU' : (handle ?? 'ANON'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: mine ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: mine ? FontWeight.w900 : FontWeight.w700,
              )),
        ),
        Text('$points',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 4),
        Text('PTS',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(width: 14),
      ]),
    );
  }

  Widget _emptyLeague() {
    return Column(children: [
      const SizedBox(height: 20),
      Text('YOUR LEAGUE IS FORMING',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 8),
      Text('Take today\'s shot and you\'re on the table.\n'
          'Every session, mission and battle adds points.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          )),
      const SizedBox(height: 20),
      SizedBox(
        width: 220,
        child: GameButton(
          label: 'RUN THE DAILY',
          onTap: () => context.push('/daily'),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════
  //  ALL TIME (ELO / tiers)
  // ══════════════════════════════════════════════════════════════════

  Widget _allTimeTable() {
    if (_allTime.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 70),
        Center(
          child: Text('No scored sessions yet. First one takes #1.',
              style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ]);
    }
    final me = AuthService.userId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        for (final (i, e) in _allTime.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: e.userId == me ? AppColors.surface2 : AppColors.surface1,
              borderRadius: BorderRadius.circular(15),
              border: e.userId == me
                  ? Border.all(color: AppColors.red, width: 1.5)
                  : Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              SizedBox(
                width: 26,
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(width: 8),
              _Avatar(
                label: e.userId == me ? 'YOU' : (e.handle ?? 'A'),
                ring: tierFor(e.rating).color,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.userId == me ? 'YOU' : (e.handle ?? 'ANON'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        )),
                    Text(tierFor(e.rating).name,
                        style: GoogleFonts.inter(
                          color: tierFor(e.rating).color,
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
              Text('${e.rating}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
      ],
    );
  }
}

// ── Small parts ───────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String label;
  final Color ring;
  const _Avatar({required this.label, required this.ring});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
        border: Border.all(color: ring.withValues(alpha: 0.85), width: 1.8),
      ),
      alignment: Alignment.center,
      child: Text(label.characters.first.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

/// Dashed rule used by the cut lines.
class _Dashes extends StatelessWidget {
  final Color color;
  const _Dashes({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final n = (c.maxWidth / 9).floor().clamp(1, 60);
      return Row(
        children: List.generate(
          n,
          (_) => Container(
            width: 5,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: color.withValues(alpha: 0.45),
          ),
        ),
      );
    });
  }
}
