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
import '../../theme/app_typography.dart';
import '../../widgets/academy/academy_style.dart';
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

  /// VOICE and TEXT are separate ladders on purpose — see migration
  /// 0009. Voice ELO moves on voice only; text has its own best-score
  /// board. Mixing them would let someone grind text to a voice rank.
  bool _voice = true;
  List<ChatBoardEntry> _chat = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await DailyGameService.status();
    final all = await LeaderboardService.global();
    final chat = await ChatLeaderboardService.global();
    if (!mounted) return;
    setState(() {
      _s = s;
      _allTime = all;
      _chat = chat;
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
                    child: !_voice
                        ? _chatTable()
                        : _league
                            ? _leagueTable()
                            : _allTimeTable(),
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
        // TWO LADDERS, and they are deliberately different shapes.
        // VOICE is one attempt a day, skill-rated, and the ELO can fall —
        // it rewards being good. CHAT is unlimited and cumulative, so it
        // rewards turning up and doing it again. Ranking an uncapped
        // surface on best-of would have made extra reps worthless.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_voice ? Icons.graphic_eq_rounded : Icons.forum_rounded,
                    size: 13, color: AppColors.red),
                const SizedBox(width: 6),
                Text(_voice ? 'VOICE RANKINGS' : 'RIZZ CHAT POINTS',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _tab('VOICE', _voice, () => setState(() => _voice = true)),
                const SizedBox(width: 6),
                _tab('CHAT', !_voice, () => setState(() => _voice = false)),
                if (_voice) ...[
                  Container(
                      width: 1,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.12)),
                  _tab('WEEK', _league,
                      () => setState(() => _league = true)),
                  const SizedBox(width: 6),
                  _tab('ALL TIME', !_league,
                      () => setState(() => _league = false)),
                ],
              ]),
            ],
          ),
        ),
        // BATTLES used to sit here and it never belonged: four pills in
        // one header, the last one a different mode rather than another
        // filter, and on a narrow phone it overlapped ALL TIME. It lives
        // on home now, at full size, where it reads as a way to play.
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
    if (s == null) return _leaguePreview();
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

  /// Before the league answers, SHOW THE LEAGUE — the five divisions,
  /// the rules, and the way in. An empty screen with one grey sentence
  /// was the single worst surface in the app.
  Widget _leaguePreview() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        const AcademyHeading(
          kicker: 'THE LEAGUE',
          title: 'Climb or fall.',
          sub: 'Every week. 30 men. Nobody stands still.',
        ),
        const SizedBox(height: 20),

        // The five divisions — the ladder, visible from day one.
        AcademyCard(
          accent: AppColors.accent,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var d = 1; d <= 5; d++)
                  Column(children: [
                    LeagueCrest(
                        division: d, size: d == 1 ? 48 : 40, locked: d != 1),
                    const SizedBox(height: 6),
                    Text(crestPalette(d).label,
                        style: AppTypography.label.copyWith(
                          fontSize: 7.5,
                          letterSpacing: 0.8,
                          color: d == 1
                              ? crestPalette(d).metalMid
                              : AppColors.textMuted,
                        )),
                  ]),
              ],
            ),
            const SizedBox(height: 16),
            Text('You start in ROOKIE. Win your week and you climb.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall),
          ]),
        ),
        const SizedBox(height: 14),

        // The rules, as three readable lines.
        AcademyCard(
          accent: kNeon,
          child: Column(children: [
            _rule(Icons.arrow_upward_rounded, kNeon, 'TOP 10 CLIMB',
                'Finish in the top ten and you move up a division.'),
            const SizedBox(height: 14),
            _rule(Icons.arrow_downward_rounded, AppColors.red,
                'BOTTOM 5 FALL', 'Finish in the last five and you drop.'),
            const SizedBox(height: 14),
            _rule(Icons.lock_clock_rounded, AppColors.textSecondary,
                'LOCKS SUNDAY 21:00',
                'Then it resets and everyone starts level again.'),
          ]),
        ),
        const SizedBox(height: 14),

        AcademyCard(
          accent: AppColors.red,
          hot: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How you earn points',
                style: AppTypography.h3
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Every roleplay you run, every daily you take and every '
                'battle you win adds points. You don\'t have to opt in — '
                'just use the app and you\'re on the table.',
                style: AppTypography.bodySmall),
            const SizedBox(height: 14),
            GameButton(
              label: 'RUN THE DAILY',
              pulse: true,
              onTap: () => context.push('/daily'),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _rule(IconData icon, Color color, String title, String body) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: AppTypography.label
                  .copyWith(color: color, fontSize: 9.5, letterSpacing: 1.6)),
          const SizedBox(height: 3),
          Text(body, style: AppTypography.bodySmall.copyWith(fontSize: 12.5)),
        ]),
      ),
    ]);
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

  Widget _chatTable() {
    if (_chat.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 70),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(children: [
              const Icon(Icons.forum_rounded,
                  size: 30, color: AppColors.textTertiary),
              const SizedBox(height: 14),
              Text('No graded conversations yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  'Run a battle, or text one of the women. Every graded '
                  'conversation adds points and there is no daily cap.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]);
    }

    final me = AuthService.userId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        for (final (i, e) in _chat.indexed)
          _ChatRow(entry: e, position: i + 1, mine: e.userId == me),
        const SizedBox(height: 16),
        Text(
            'Every graded conversation adds its score (0–100) to your '
            'total, and a battle win banks +50 on top. Unlimited — this '
            'board rewards turning up, and it only ever climbs.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  Widget _allTimeTable() {
    if (_allTime.isEmpty) {
      // Empty here means one of two things — nobody has scored yet, OR
      // the board never loaded. The user can't tell those apart, so the
      // diagnostic sits right here rather than in settings.
      return ListView(children: [
        const SizedBox(height: 70),
        Center(
          child: Text('No scored sessions yet. First one takes #1.',
              style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/backend-check');
            },
            icon: const Icon(Icons.wifi_tethering_rounded,
                size: 15, color: AppColors.textTertiary),
            label: Text('Board empty? Run backend check',
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
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


class _ChatRow extends StatelessWidget {
  final ChatBoardEntry entry;
  final int position;
  final bool mine;
  const _ChatRow(
      {required this.entry, required this.position, required this.mine});

  @override
  Widget build(BuildContext context) {
    final podium = position <= 3;
    final colour = position == 1
        ? const Color(0xFFFFD34D)
        : mine
            ? AppColors.red
            : AppColors.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? AppColors.red.withValues(alpha: 0.10) : AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: mine
                ? AppColors.red.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('$position',
              style: GoogleFonts.inter(
                color: colour,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              )),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface2,
            border: Border.all(
                color: podium ? colour : Colors.white24, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
              (mine ? 'YOU' : (entry.handle ?? 'A'))
                  .characters
                  .first
                  .toUpperCase(),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mine ? 'YOU' : (entry.handle ?? 'ANON'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: mine ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 1),
              // The credibility line. 400 points off 40 battles reads
              // very differently to 400 off four, so the board says
              // which it is rather than showing a bare total.
              Text(
                  entry.battles > 0
                      ? '${entry.wins}W · ${entry.battles} battles · avg ${entry.average}'
                      : '${entry.attempts} graded · avg ${entry.average}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
        Text('${entry.points}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w900,
            )),
        Text(' PTS',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 8.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}
