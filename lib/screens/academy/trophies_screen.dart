import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/trophy.dart';
import '../../widgets/share/rizz_card.dart';

/// THE CABINET.
///
/// Grouped by family rather than by earned/locked, so every row reads as
/// a ladder he is partway up rather than a wall of things he hasn't
/// done. The one thing a trophy screen must never do is make a new user
/// feel behind on day one, and sorting by "earned first" does exactly
/// that — it puts his three medals at the top and twenty-seven grey
/// discs underneath.
///
/// Locked medals carry their progress on the rim. The bronze rung of
/// every family is deliberately cheap, so within a week a new man's
/// cabinet has movement in six or seven rows at once.
class TrophiesScreen extends StatefulWidget {
  const TrophiesScreen({super.key});

  @override
  State<TrophiesScreen> createState() => _TrophiesScreenState();
}

class _TrophiesScreenState extends State<TrophiesScreen> {
  Set<String> _earned = const {};
  Map<Stat, int> _values = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final earned = await Achievements.earned();
    final values = <Stat, int>{};
    for (final s in Stat.values) {
      values[s] = await Achievements.valueOf(s);
    }
    if (!mounted) return;
    setState(() {
      _earned = earned;
      _values = values;
      _loading = false;
    });
  }

  static String _familyName(Stat s) => switch (s) {
        Stat.talks => 'CONVERSATIONS',
        Stat.approaches => 'REAL APPROACHES',
        Stat.duels => 'BATTLES',
        Stat.wins => 'DUELS WON',
        Stat.streakPeak => 'DAYS IN A ROW',
        Stat.numbers => 'NUMBERS',
        Stat.dailies => 'THE DAILY',
        Stat.nineties => 'SCORES OF 90+',
        Stat.chain => 'THE CHAIN',
        Stat.nudges => 'NUDGES',
      };

  @override
  Widget build(BuildContext context) {
    final total = Achievements.all.length;
    final got = _earned.length;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 16, 2),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
              Text('THE CABINET',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              Text('$got / $total',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFC53D),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
          if (!_loading) _hero(got, total),
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red)),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.red,
                backgroundColor: AppColors.surface1,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: [
                    for (final (i, s) in Stat.values.indexed)
                      _row(s).animate().fadeIn(
                          delay: (40 * i).clamp(0, 320).ms, duration: 240.ms),
                    const SizedBox(height: 10),
                    Text(
                        'Nothing here is secret and nothing is out of reach. '
                        'Every badge shows what it costs and how close you are.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  /// THE CASE.
  ///
  /// The screen opened straight onto a grid of small grey discs, which
  /// is the exact failure the whole system was designed to avoid: a
  /// wall of things he hasn't done. So the first thing on it is now the
  /// three metals he HAS won, counted out, with the gold total lit.
  ///
  /// Counting by metal rather than by total is deliberate. "7 / 30" is a
  /// completion percentage and completion percentages are depressing at
  /// the start. "2 GOLD" is a boast.
  Widget _hero(int got, int total) {
    var bronze = 0, silver = 0, gold = 0;
    for (final t in Achievements.all) {
      if (!_earned.contains(t.id)) continue;
      switch (t.tier) {
        case Tier.bronze:
          bronze++;
        case Tier.silver:
          silver++;
        case Tier.gold:
          gold++;
      }
    }
    final pct = total == 0 ? 0.0 : got / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFC53D).withValues(alpha: gold > 0 ? 0.16 : 0.06),
              AppColors.surface1,
              AppColors.base,
            ],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(
              color: const Color(0xFFFFC53D)
                  .withValues(alpha: gold > 0 ? 0.4 : 0.14)),
          boxShadow: gold > 0
              ? [
                  BoxShadow(
                      color: const Color(0xFFFFC53D).withValues(alpha: 0.16),
                      blurRadius: 30)
                ]
              : null,
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Metal(count: bronze, tier: Tier.bronze),
            const SizedBox(width: 26),
            _Metal(count: silver, tier: Tier.silver),
            const SizedBox(width: 26),
            _Metal(count: gold, tier: Tier.gold),
          ]),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(children: [
              Container(height: 5, color: Colors.white.withValues(alpha: 0.07)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => FractionallySizedBox(
                  widthFactor: v.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC53D),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFFC53D)
                                .withValues(alpha: 0.6),
                            blurRadius: 10)
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
              got == 0
                  ? 'THE CASE IS EMPTY. THE FIRST ONE IS CHEAP.'
                  : got == total
                      ? 'EVERY BADGE IN THE APP. NOBODY ELSE HAS THIS.'
                      : '$got OF $total CLAIMED',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 9.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _row(Stat s) {
    final family = Achievements.family(s);
    if (family.isEmpty) return const SizedBox.shrink();
    final have = _values[s] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_familyName(s),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 8),
          Text('$have',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final t in family)
              Expanded(
                child: _Medal(
                  trophy: t,
                  earned: _earned.contains(t.id),
                  have: have,
                  onTap: () => _open(t, _earned.contains(t.id), have),
                ),
              ),
            // Families with two rungs instead of three keep their
            // columns the same width as everyone else's.
            for (var i = family.length; i < 3; i++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ]),
    );
  }

  void _open(Trophy t, bool earned, int have) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.base,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            26, 18, 26, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 22),
          TrophyMedal(
            trophy: t,
            size: 110,
            earned: earned,
            progress: (have / t.need).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 18),
          Text(t.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: earned ? Colors.white : AppColors.textSecondary,
                fontSize: 22,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 6),
          Text(t.tier.label,
              style: GoogleFonts.inter(
                color: t.tier.color,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 14),
          Text(t.line,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 18),
          if (earned)
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _share(t);
              },
              icon: const Icon(Icons.ios_share_rounded,
                  size: 16, color: AppColors.textSecondary),
              label: Text('SHARE IT',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
            )
          else
            Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(children: [
                  Container(
                      height: 6, color: Colors.white.withValues(alpha: 0.07)),
                  FractionallySizedBox(
                    widthFactor: (have / t.need).clamp(0.0, 1.0),
                    child: Container(height: 6, color: t.tier.color),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('$have OF ${t.need}',
                  style: GoogleFonts.inter(
                    color: t.tier.color,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
        ]),
      ),
    );
  }

  void _share(Trophy t) {
    ShareService.shareRizzCard(
      context: context,
      data: RizzShareData(
        kicker: '${t.tier.label} BADGE',
        hero: t.name,
        heroSub: 'IMHIM RIZZ',
        line: t.line,
        accent: t.tier.color,
        stats: [
          (label: 'CABINET', value: '${_earned.length}/${Achievements.all.length}'),
        ],
      ),
      text: 'Unlocked ${t.name} on ImHim Rizz. ${t.line}',
    );
  }
}

class _Medal extends StatelessWidget {
  final Trophy trophy;
  final bool earned;
  final int have;
  final VoidCallback onTap;
  const _Medal({
    required this.trophy,
    required this.earned,
    required this.have,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        TrophyMedal(
          trophy: trophy,
          size: 66,
          earned: earned,
          progress: (have / trophy.need).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 7),
        Text(trophy.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: earned ? Colors.white : AppColors.textMuted,
              fontSize: 8.5,
              height: 1.25,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 2),
        Text(earned ? '✓' : '$have/${trophy.need}',
            style: GoogleFonts.inter(
              color: earned ? trophy.tier.color : AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

/// One metal, counted. Big number, small word, the medal behind it —
/// so the three of them read as a trophy case rather than a stat line.
class _Metal extends StatelessWidget {
  final int count;
  final Tier tier;
  const _Metal({required this.count, required this.tier});

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return Column(children: [
      Text('$count',
          style: GoogleFonts.inter(
            color: has ? tier.color : AppColors.textMuted,
            fontSize: 34,
            height: 1,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w900,
            shadows: has
                ? [
                    Shadow(
                        color: tier.color.withValues(alpha: 0.55),
                        blurRadius: 22)
                  ]
                : null,
          )),
      const SizedBox(height: 5),
      Text(tier.label,
          style: GoogleFonts.inter(
            color: has ? tier.color.withValues(alpha: 0.8) : AppColors.textMuted,
            fontSize: 8.5,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }
}
