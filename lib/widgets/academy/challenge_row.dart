import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import 'game_feel.dart';

/// One man's mark on today's challenge.
class RowMark {
  final String userId;

  /// Already on the 0–100 AI Score band — see economy.dart rule 2. The
  /// caller converts; this widget never divides anything.
  final int? score;
  const RowMark({required this.userId, required this.score});
}

/// TODAY'S CHALLENGE, as a row rather than a poster.
///
/// The old cards were full-bleed portraits the height of a phone third,
/// two of them stacked, and between them they pushed everything that
/// actually mattered below the fold. The woman is the same one for the
/// whole world every day — she's a fact about today, not a headline, and
/// a fact belongs in a thumbnail.
///
/// So: her face at 56pt, the state of play in one line, and EVERY MAN'S
/// SCORE ON THE FACE OF THE CARD. That last part is the whole reason
/// this exists. "3/5 have played" is a status bar; "EJ 91 · MB 84 ·
/// YOU —" is a reason to open the app before bed. Tapping opens the full
/// poster screen, which is where the reveal, the reel and the rubric
/// live — the big version is earned by a tap, not forced on him twice a
/// day.
///
/// Scores stay HIDDEN until he's run it himself. Everyone blind, then
/// everyone at once, is the mechanic; showing him what to beat before he
/// speaks would quietly wreck the daily.
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

  RowMark? _markFor(String id) {
    for (final m in marks) {
      if (m.userId == id && m.score != null) return m;
    }
    return null;
  }

  bool get _iRan {
    final me = AuthService.userId;
    return me != null && _markFor(me) != null;
  }

  int get _played => [
        for (final m in roster)
          if (_markFor(m.userId) != null) 1
      ].length;

  /// Top mark, and whose. Null until at least one man has run it.
  ({String handle, int score})? get _leader {
    ({String handle, int score})? best;
    for (final m in roster) {
      final mark = _markFor(m.userId);
      final s = mark?.score;
      if (s == null) continue;
      final b = best;
      if (b == null || s > b.score) {
        best = (
          handle: m.userId == AuthService.userId
              ? 'YOU'
              : (m.handle ?? 'ANON').toUpperCase(),
          score: s,
        );
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final iRan = _iRan;
    final total = roster.length;

    return GestureDetector(
      onTap: () {
        Feel.tick();
        onRun();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: iRan
                ? Colors.white.withValues(alpha: 0.07)
                : accent.withValues(alpha: 0.45),
          ),
          boxShadow: iRan
              ? null
              : [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.13), blurRadius: 20)
                ],
        ),
        child: Column(children: [
          Row(children: [
            // Her, as a thumbnail. Tap opens the full poster.
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Image.asset(girl.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.35),
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppColors.surface2)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 12, color: accent),
                    const SizedBox(width: 6),
                    Text(kicker,
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 8.5,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
                  const SizedBox(height: 4),
                  Text(girl.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.05,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 3),
                  Text('$_played of $total have played',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
            if (!iRan)
              Row(children: [
                Text('YOUR TURN',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w900,
                        ))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.6, end: 1, duration: 1000.ms),
                Icon(Icons.chevron_right_rounded, size: 17, color: accent),
              ])
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: AppColors.textTertiary),
          ]),

          // ── The board ─────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 10),
          if (!iRan)
            Row(children: [
              const Icon(Icons.lock_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('EVERYONE BLIND UNTIL YOU RUN IT',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ])
          else
            _scores(),
        ]),
      ),
    );
  }

  /// Every man's mark, leader first, dashes for the men still to go.
  /// A dash is doing work — it's the empty square someone will be asked
  /// about.
  Widget _scores() {
    final ranked = [...roster]..sort((a, b) {
        final sa = _markFor(a.userId)?.score;
        final sb = _markFor(b.userId)?.score;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
    final top = _leader;

    return Row(children: [
      for (final (i, m) in ranked.take(5).indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Builder(builder: (_) {
          final s = _markFor(m.userId)?.score;
          final me = m.userId == AuthService.userId;
          final isTop = top != null && s != null && s == top.score;
          return Column(children: [
            Text(s == null ? '—' : '$s',
                style: GoogleFonts.inter(
                  color: s == null
                      ? AppColors.textMuted
                      : (isTop ? const Color(0xFFFFD34D) : Colors.white),
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 3),
            Text(
                me
                    ? 'YOU'
                    : (m.handle ?? 'ANON').toUpperCase().padRight(1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: me ? kNeon : AppColors.textTertiary,
                  fontSize: 7.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                )),
          ]);
        }),
      ],
      const Spacer(),
    ]);
  }
}
