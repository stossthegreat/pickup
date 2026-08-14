import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/battle_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/economy.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import 'daily_card.dart' show girlForVibe, scenarioOfToday;
import 'game_feel.dart';

/// RIZZ BATTLES on Home — the second of the two permanent systems.
///
/// Battles was a rounded pill beside the XP badge: the visual weight of
/// a filter chip, for the one mode where two real men run the same
/// woman blind and the better conversation takes the rating. It's not a
/// mission and it doesn't belong among them — missions are today's work,
/// battles are a standing system. So Home now reads:
///
///     WHO YOU ARE     wordmark · XP · streak
///     SOCIAL          your squad
///     COMPETITIVE     rizz battles      ← this
///     ─────────────
///     TODAY'S WORK    the five missions
///
/// THE HEADLINE IS NOT "BATTLES". "Battles" is a category name and it
/// sells nothing. **SAME WOMAN. BOTH BLIND.** is the entire pitch, it
/// explains the mechanic in four words, and it's what goes on the card.
///
/// THE IMAGE IS THE SAME WOMAN, MIRRORED. Two portraits of two
/// different women would look like a face-off and be a lie — the whole
/// point is that both men get the SAME one. So it's today's woman on
/// both sides of a hard seam, the right half flipped, darkened almost to
/// black. It reads as a confrontation and it's literally true. One
/// asset, no new art.
///
/// Deliberately not built like the squad card. Two identical rectangles
/// stacked on each other is how a home screen turns into a list; the
/// squad card is a crest on a flat panel, this one is full-bleed
/// photography going dark. Same footprint, opposite texture.
class BattleStrip extends StatefulWidget {
  final VoidCallback onTap;
  const BattleStrip({super.key, required this.onTap});

  @override
  State<BattleStrip> createState() => _BattleStripState();
}

class _BattleStripState extends State<BattleStrip> {
  List<Battle> _battles = const [];
  LeaderboardEntry? _me;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final battles = await BattleService.myBattles();
    final me = await LeaderboardService.me();
    if (!mounted) return;
    setState(() {
      _battles = battles;
      _me = me;
    });
  }

  bool _mine(Battle b, String uid) => b.playerA == uid || b.playerB == uid;

  /// Duels where both men are in and he still hasn't spoken.
  int get _yourTurn {
    final uid = AuthService.userId;
    if (uid == null) return 0;
    var n = 0;
    for (final b in _battles) {
      if (b.state != 'active' || !_mine(b, uid)) continue;
      if ((b.playerA == uid ? b.aScore : b.bScore) == null) n++;
    }
    return n;
  }

  ({int won, int lost}) get _record {
    final uid = AuthService.userId;
    var w = 0, l = 0;
    if (uid == null) return (won: 0, lost: 0);
    for (final b in _battles) {
      if (b.state != 'scored' || !_mine(b, uid)) continue;
      final winner = b.winner;
      if (winner == null) continue;
      if (winner == uid) {
        w++;
      } else {
        l++;
      }
    }
    return (won: w, lost: l);
  }

  @override
  Widget build(BuildContext context) {
    final girl = girlForVibe(scenarioOfToday());
    final turn = _yourTurn;
    final urgent = turn > 0;
    final me = _me;
    final tier = me == null ? kTiers.first : tierFor(me.rating);
    final rec = _record;

    return GestureDetector(
      onTap: () {
        Feel.tick();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 76,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: urgent
                ? AppColors.red.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.08),
            width: urgent ? 1.4 : 1,
          ),
          boxShadow: urgent
              ? [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.24),
                      blurRadius: 24)
                ]
              : null,
        ),
        child: Stack(fit: StackFit.expand, children: [
          // ── The face-off ──────────────────────────────────────────
          Row(children: [
            Expanded(child: _half(girl, flip: false)),
            Expanded(child: _half(girl, flip: true)),
          ]),

          // Darken hard. This sits above the fold on the busiest screen
          // in the app — it has to read as texture, not as a photo
          // competing with the missions underneath it.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0, 0.28, 0.5, 0.72, 1],
                ),
              ),
            ),
          ),

          // The seam. One hairline down the middle is what turns two
          // crops into a confrontation.
          Center(
            child: Container(
              width: 1.4,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.6),
                      blurRadius: 12)
                ],
              ),
            ),
          ),

          // ── The words ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.sports_mma_rounded,
                      size: 13, color: AppColors.red),
                  const SizedBox(width: 6),
                  Text('RIZZ BATTLES',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 9,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w900,
                      )),
                  const Spacer(),
                  Text(tier.name,
                      style: GoogleFonts.inter(
                        color: tier.color,
                        fontSize: 9.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.9),
                              blurRadius: 8)
                        ],
                      )),
                ]),

                // THE PITCH. Four words that explain the whole mode.
                Text('SAME WOMAN. BOTH BLIND.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.06,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: Colors.black.withValues(alpha: 0.95),
                            blurRadius: 14)
                      ],
                    )),

                Row(children: [
                  if (urgent)
                    Text(
                            turn == 1
                                ? 'YOUR TURN · 1 WAITING'
                                : 'YOUR TURN · $turn WAITING',
                            style: GoogleFonts.inter(
                              color: AppColors.red,
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w900,
                            ))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 0.55, end: 1, duration: 950.ms)
                  else
                    Text(
                        me == null
                            ? 'HIGHER AI SCORE TAKES THE ${Economy.rrShort}'
                            : '${Economy.commas(me.rating)} ${Economy.rrShort}'
                                '${rec.won + rec.lost == 0 ? '' : '  ·  ${rec.won}W—${rec.lost}L'}',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                blurRadius: 8)
                          ],
                        )),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: urgent
                          ? AppColors.red
                          : AppColors.textSecondary),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// One side of the seam. The right half is mirrored so the two crops
  /// face each other — same woman, two sides, which is the mechanic.
  Widget _half(GirlBrief g, {required bool flip}) {
    final img = Image.asset(
      g.asset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.42),
      errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface1),
    );
    return flip ? Transform.scale(scaleX: -1, child: img) : img;
  }
}
