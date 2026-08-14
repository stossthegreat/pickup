import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import 'game_feel.dart';

/// One man's mark on today's challenge, already on the 0–100 AI Score
/// band — see economy.dart rule 2. The caller converts; this widget
/// never divides anything.
class RowMark {
  final String userId;
  final int? score;
  const RowMark({required this.userId, required this.score});
}

/// TODAY'S CHALLENGE — a scoreboard, not a status bar.
///
/// The first version of this shrank the poster down correctly and then
/// under-sold the half that matters: the scores were a small grey row at
/// the bottom. But the scores ARE the card. "0 of 5 have played" is
/// admin; five numbers in rank order with a crown on the leader and a
/// dash where someone hasn't shown up is the thing that gets opened
/// before bed.
///
/// So the card is bigger, the numbers are big, and the whole board is
/// the bottom two thirds of it. Voice is red and chat is green — the
/// two challenges should never be told apart by reading, only by colour,
/// because a man checks this thirty times a week.
///
/// ── HOW IT HOLDS FIVE ────────────────────────────────────────────────
/// Every man gets an equal-width column, so the row is laid out by
/// division rather than by fixed widths: two men or five, it fills the
/// card exactly and can never overflow on a narrow phone. Handles are
/// clipped to three characters — at five columns there is room for a
/// number and an identifier, and the number is what he came for.
///
/// ── SCORES STAY HIDDEN UNTIL HE'S RUN IT ─────────────────────────────
/// Everyone blind, then everyone at once, is the mechanic. Showing him
/// what to beat before he speaks would quietly wreck the daily, so
/// before his own attempt the board is a locked strip instead.
class ChallengeRow extends StatelessWidget {
  final String kicker;
  final IconData icon;
  final Color accent;
  final GirlBrief girl;
  final List<SquadMember> roster;
  final List<RowMark> marks;
  final VoidCallback onRun;

  const ChallengeRow({
    super.key,
    required this.kicker,
    required this.icon,
    required this.accent,
    required this.girl,
    required this.roster,
    required this.marks,
    required this.onRun,
  });

  int? _scoreFor(String id) {
    for (final m in marks) {
      if (m.userId == id && m.score != null) return m.score;
    }
    return null;
  }

  bool get _iRan {
    final me = AuthService.userId;
    return me != null && _scoreFor(me) != null;
  }

  int get _played {
    var n = 0;
    for (final m in roster) {
      if (_scoreFor(m.userId) != null) n++;
    }
    return n;
  }

  int? get _top {
    int? best;
    for (final m in roster) {
      final s = _scoreFor(m.userId);
      if (s == null) continue;
      if (best == null || s > best) best = s;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final iRan = _iRan;

    return GestureDetector(
      onTap: () {
        Feel.tick();
        onRun();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // The colour IS the identity. A man checks this thirty times a
          // week and should never have to read a word to know which
          // challenge he's looking at.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: iRan ? 0.10 : 0.20),
              AppColors.surface1,
              AppColors.base,
            ],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(
            color: accent.withValues(alpha: iRan ? 0.35 : 0.7),
            width: iRan ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: iRan ? 0.10 : 0.24),
                blurRadius: 26)
          ],
        ),
        child: Column(children: [
          // ── Her, and the state of play ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.4), blurRadius: 16)
                  ],
                ),
                child: Image.asset(girl.asset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.35),
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.surface2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon, size: 13, color: accent),
                      const SizedBox(width: 6),
                      Text(kicker,
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 9,
                            letterSpacing: 2.6,
                            fontWeight: FontWeight.w900,
                          )),
                    ]),
                    const SizedBox(height: 5),
                    Text(girl.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.02,
                          letterSpacing: -0.6,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 4),
                    Text('$_played of ${roster.length} have played',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
              if (!iRan)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('YOUR',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      )),
                  Text('TURN',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      )),
                  Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                ])
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.55, end: 1, duration: 1000.ms)
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
            ]),
          ),

          // ── THE BOARD ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 13),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              border: Border(
                  top: BorderSide(color: accent.withValues(alpha: 0.22))),
            ),
            child: iRan ? _board() : _locked(),
          ),
        ]),
      ),
    );
  }

  Widget _locked() => Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        const Icon(Icons.lock_rounded, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 9),
        Text('EVERYONE BLIND UNTIL YOU RUN IT',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 9.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w900,
            )),
      ]);

  /// Every man, ranked, in an equal-width column. Division rather than
  /// fixed widths is what lets this hold two men or five on any phone
  /// without a single overflow.
  Widget _board() {
    final ranked = [...roster]..sort((a, b) {
        final sa = _scoreFor(a.userId), sb = _scoreFor(b.userId);
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
    final top = _top;

    return Row(
      children: [
        for (final (i, m) in ranked.take(5).indexed)
          Expanded(
            child: _Slot(
              score: _scoreFor(m.userId),
              handle: m.userId == AuthService.userId
                  ? 'YOU'
                  : (m.handle ?? 'ANON').toUpperCase(),
              mine: m.userId == AuthService.userId,
              leader: top != null && _scoreFor(m.userId) == top,
              accent: accent,
              delay: i,
            ),
          ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  final int? score;
  final String handle;
  final bool mine;
  final bool leader;
  final Color accent;
  final int delay;

  const _Slot({
    required this.score,
    required this.handle,
    required this.mine,
    required this.leader,
    required this.accent,
    required this.delay,
  });

  static const _gold = Color(0xFFFFD34D);

  @override
  Widget build(BuildContext context) {
    final s = score;
    final crowned = leader && s != null;
    // Three characters is what fits at five columns. The number is what
    // he came for; the handle only has to be enough to tell them apart.
    final short = handle.length > 3 ? handle.substring(0, 3) : handle;

    return Column(children: [
      SizedBox(
        height: 13,
        child: crowned
            ? const Icon(Icons.emoji_events_rounded, size: 12, color: _gold)
            : null,
      ),
      const SizedBox(height: 2),
      Text(s == null ? '—' : '$s',
          style: GoogleFonts.inter(
            color: s == null
                ? AppColors.textMuted
                : (crowned ? _gold : Colors.white),
            fontSize: 24,
            height: 1,
            letterSpacing: -1,
            fontWeight: FontWeight.w900,
            shadows: crowned
                ? [const Shadow(color: _gold, blurRadius: 18)]
                : null,
          )),
      const SizedBox(height: 4),
      Text(short,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: GoogleFonts.inter(
            color: mine ? accent : AppColors.textTertiary,
            fontSize: 8,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w900,
          )),
    ]).animate().fadeIn(delay: (70 * delay).ms, duration: 260.ms).slideY(
        begin: 0.25, end: 0, curve: Curves.easeOutBack);
  }
}
