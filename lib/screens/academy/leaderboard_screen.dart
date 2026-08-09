import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

enum _Scope { squad, friends, weekly, global }

/// The board. Podium top-3 with tier glow, ranked list, and YOUR row
/// pinned to the bottom permanently — the gap to the next man is always
/// on screen. WEEKLY resets Monday: "I can win this one."
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _Scope _scope = _Scope.global;
  bool _loading = true;
  List<LeaderboardEntry> _entries = const [];
  LeaderboardEntry? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<LeaderboardEntry> entries = const [];
    switch (_scope) {
      case _Scope.global:
      case _Scope.weekly: // weekly board goes live with the first season
        entries = await LeaderboardService.global();
        break;
      case _Scope.squad:
        final squad = await SquadService.mySquad();
        if (squad != null) {
          final roster = await SquadService.roster(squad.id);
          entries = await LeaderboardService.forUsers(
              [for (final m in roster) m.userId]);
        }
        break;
      case _Scope.friends:
        entries = const []; // friend graph ships with challenges
        break;
    }
    final me = await LeaderboardService.me();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _me = me;
      _loading = false;
    });
  }

  int? get _myRank {
    final uid = AuthService.userId;
    if (uid == null) return null;
    final i = _entries.indexWhere((e) => e.userId == uid);
    return i < 0 ? null : i + 1;
  }

  @override
  Widget build(BuildContext context) {
    final podium = _entries.take(3).toList();
    final rest = _entries.length > 3 ? _entries.sublist(3) : const <LeaderboardEntry>[];

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
              Text('THE BOARD',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
            ]),
          ),

          // ── Scope tabs ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(children: [
              for (final s in _Scope.values) ...[
                if (s != _Scope.values.first) const SizedBox(width: 6),
                Expanded(child: _ScopeChip(
                  label: s.name.toUpperCase(),
                  active: s == _scope,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scope = s);
                    _load();
                  },
                )),
              ],
            ]),
          ),

          // ── Body ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.red)))
                : _entries.isEmpty
                    ? _EmptyBoard(scope: _scope)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        children: [
                          if (podium.isNotEmpty)
                            _Podium(entries: podium)
                                .animate()
                                .fadeIn(duration: 350.ms),
                          const SizedBox(height: 16),
                          for (final (i, e) in rest.indexed)
                            _BoardRow(rank: i + 4, entry: e, mine: e.userId == AuthService.userId)
                                .animate()
                                .fadeIn(
                                    delay: (60 * i).clamp(0, 500).ms,
                                    duration: 250.ms),
                        ],
                      ),
          ),

          // ── Your row — pinned. The gap is always visible. ─────────
          if (_me != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.redGlow, blurRadius: 24),
                ],
              ),
              child: Row(children: [
                Text(_myRank == null ? '—' : '#$_myRank',
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(width: 14),
                Text('YOU',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                _TierTag(rating: _me!.rating),
                const SizedBox(width: 12),
                Text('${_me!.rating}',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ScopeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active
                  ? AppColors.red
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: active ? Colors.white : AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            )),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd · 1st · 3rd
    final order = [
      if (entries.length > 1) (2, entries[1], 84.0),
      (1, entries[0], 108.0),
      if (entries.length > 2) (3, entries[2], 68.0),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (rank, e, h) in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _PodiumSpot(rank: rank, entry: e, height: h),
            ),
          ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final double height;
  const _PodiumSpot(
      {required this.rank, required this.entry, required this.height});

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(entry.rating);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Avatar(entry: entry, size: rank == 1 ? 58 : 46, glow: rank == 1),
      const SizedBox(height: 6),
      Text(entry.handle ?? 'ANON',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          )),
      Text('${entry.rating}',
          style: GoogleFonts.inter(
            color: tier.color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 6),
      Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.red.withValues(alpha: rank == 1 ? 0.55 : 0.22),
              AppColors.surface1,
            ],
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 8),
        child: Text('$rank',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            )),
      ),
    ]);
  }
}

class _BoardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool mine;
  const _BoardRow(
      {required this.rank, required this.entry, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.surface2 : AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: mine
            ? Border.all(color: AppColors.red.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text('#$rank',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              )),
        ),
        _Avatar(entry: entry, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Text(entry.handle ?? 'ANON',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              )),
        ),
        _TierTag(rating: entry.rating),
        const SizedBox(width: 12),
        Text('${entry.rating}',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

class _TierTag extends StatelessWidget {
  final int rating;
  const _TierTag({required this.rating});

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(rating);
    return Text(tier.name,
        style: GoogleFonts.inter(
          color: tier.color,
          fontSize: 9.5,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
          shadows: tier.glow
              ? [Shadow(color: tier.color.withValues(alpha: 0.7), blurRadius: 12)]
              : null,
        ));
  }
}

class _Avatar extends StatelessWidget {
  final LeaderboardEntry entry;
  final double size;
  final bool glow;
  const _Avatar({required this.entry, required this.size, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(entry.rating);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
        border: Border.all(color: tier.color.withValues(alpha: 0.7), width: 1.6),
        boxShadow: glow
            ? [BoxShadow(color: tier.color.withValues(alpha: 0.4), blurRadius: 22)]
            : null,
        image: entry.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(entry.avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: entry.avatarUrl == null
          ? Center(
              child: Text(
                (entry.handle ?? 'A').characters.first.toUpperCase(),
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  final _Scope scope;
  const _EmptyBoard({required this.scope});

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (scope) {
      _Scope.squad => ('NO SQUAD YET',
          'Join a squad and this board becomes personal.'),
      _Scope.friends => ('NO RIVALS YET',
          'Challenge someone — beaten rivals appear here.'),
      _ => ('THE BOARD IS EMPTY', 'First scored session takes #1.'),
    };
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 6),
        Text(sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }
}
