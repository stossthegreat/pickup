import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/battle_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/division.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';
import 'game_button.dart';
import 'game_feel.dart';

/// THE BATTLE CARD — the app's best feature, finally sized like it.
///
/// Battles were a chip. A rounded pill next to the XP badge, the same
/// visual weight as a filter, for the one mode where two real men run
/// the same woman blind and the better conversation wins. Everything the
/// product is actually about is in that sentence, and it was a pill.
///
/// This is also where the economy becomes legible, because a battle is
/// the ONLY place RIZZ RATING moves. The card therefore carries his RR
/// and his league at the top: he sees the number, he sees the one door
/// that changes it, and the connection needs no explaining.
///
///     TRAIN (missions → XP)
///     PROVE (real world → XP ×3)
///     COMPETE (battles → RR)     ← this card
///
/// Three states, and the order matters — the card leads with whichever
/// is most urgent rather than always leading with the same headline:
///   · YOUR TURN — a duel is waiting on him. Nothing outranks this.
///   · RESULTS IN — settled duels he hasn't looked at.
///   · OPEN — no duels; the pitch, and a button.
class BattleCard extends StatefulWidget {
  final VoidCallback onOpen;
  const BattleCard({super.key, required this.onOpen});

  @override
  State<BattleCard> createState() => _BattleCardState();
}

class _BattleCardState extends State<BattleCard> {
  List<Battle> _battles = const [];
  int? _rr;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final battles = await BattleService.myBattles();
    final rr = await LeaderboardService.myBattleRating();
    if (!mounted) return;
    setState(() {
      _battles = battles;
      _rr = rr;
      _ready = true;
    });
  }

  bool _isMine(Battle b, String uid) => b.playerA == uid || b.playerB == uid;

  /// Duels with both men in and no score from him yet.
  int get _yourTurn {
    final uid = AuthService.userId;
    if (uid == null) return 0;
    var n = 0;
    for (final b in _battles) {
      if (b.state != 'active' || !_isMine(b, uid)) continue;
      final mine = b.playerA == uid ? b.aScore : b.bScore;
      if (mine == null) n++;
    }
    return n;
  }

  ({int won, int lost}) get _record {
    final uid = AuthService.userId;
    var w = 0, l = 0;
    if (uid == null) return (won: 0, lost: 0);
    for (final b in _battles) {
      if (b.state != 'scored' || !_isMine(b, uid)) continue;
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
    final turn = _yourTurn;
    final rec = _record;
    // DIVISION off the BATTLE rating. This card used to print the same
    // five words the 60-day identity ladder uses, off a rating that
    // moved on every solo voice session — two different bugs stacked on
    // each other. See standing.dart and migration 0012.
    final tier = Rank.of(_rr ?? 0);
    final urgent = turn > 0;
    final tone = urgent ? AppColors.red : tier.div.color;

    return GestureDetector(
      onTap: () {
        Feel.tick();
        widget.onOpen();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tone.withValues(alpha: 0.13),
              AppColors.surface1,
              AppColors.base,
            ],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(color: tone.withValues(alpha: urgent ? 0.6 : 0.3)),
          boxShadow: urgent
              ? [BoxShadow(color: tone.withValues(alpha: 0.22), blurRadius: 30)]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── RIZZ RATING. The card leads with it because a battle is
          // the only thing in the app that moves it, and putting the
          // number directly above its one cause is the whole of making
          // an economy legible.
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Economy.rrLong,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 8.5,
                    letterSpacing: 3.4,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 4),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(me == null ? '—' : Economy.commas(me.rating),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1,
                          letterSpacing: -1.6,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 6),
                    Text(Economy.rrShort,
                        style: GoogleFonts.inter(
                          color: tier.div.color,
                          fontSize: 11,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tier.label,
                  style: GoogleFonts.inter(
                    color: tier.div.color,
                    fontSize: 12,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w900,
                    shadows: tier.div.glows
                        ? [
                            Shadow(
                                color: tier.div.color.withValues(alpha: 0.6),
                                blurRadius: 20)
                          ]
                        : null,
                  )),
              const SizedBox(height: 4),
              // A record is history, and history is what makes a number
              // feel earned rather than assigned.
              Text(
                  rec.won + rec.lost == 0
                      ? 'NO DUELS YET'
                      : '${rec.won}W — ${rec.lost}L',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ]),

          const SizedBox(height: 15),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 13),

          if (!_ready)
            Text('...',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ))
          else if (urgent)
            Row(children: [
              const Icon(Icons.sports_mma_rounded,
                  size: 16, color: AppColors.red),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                    turn == 1
                        ? 'YOUR TURN — ONE DUEL WAITING'
                        : 'YOUR TURN — $turn DUELS WAITING',
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 11,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ])
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.6, end: 1, duration: 1100.ms)
          else
            Text(
                'Same woman. Both blind. The better conversation takes '
                'the ${Economy.rrShort}.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                )),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              label: urgent ? 'TAKE YOUR SHOT' : 'FIND AN OPPONENT',
              color: urgent ? AppColors.red : AppColors.surface2,
              textColor: Colors.white,
              icon: Icons.sports_mma_rounded,
              pulse: urgent,
              height: 50,
              onTap: widget.onOpen,
            ),
          ),
        ]),
      ),
    );
  }
}
