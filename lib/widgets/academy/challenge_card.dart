import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';

/// One man's result in a challenge, normalised so voice and chat can
/// share a card. [display] is already formatted for its own scale —
/// voice reads out of 10, chat out of 100.
class ChallengeMark {
  final String userId;
  final int raw; // for ranking; scale is per-challenge
  final String display;
  const ChallengeMark({
    required this.userId,
    required this.raw,
    required this.display,
  });
}

/// THE CHALLENGE CARD — her poster, the badge, and the whole squad's
/// day on one object.
///
/// Voice and chat are the same event in two mediums, so they get the
/// same card rather than two designs that happen to sit near each other.
/// Everything above the divider is the invitation; everything below is
/// the scoreboard, and the scoreboard only exists once you've run it —
/// you don't get to scout the room before you swing.
class ChallengeCard extends StatelessWidget {
  /// VOICE / CHAT.
  final String kicker;
  final IconData icon;
  final Color accent;

  /// Today's woman — the same one for both challenges and for everyone.
  final GirlBrief girl;

  /// The squad, and who has posted a mark.
  final List<SquadMember> roster;
  final List<ChallengeMark> marks;

  /// Out-of line under the badge ("OUT OF 10" / "OUT OF 100").
  final String scaleLabel;

  final VoidCallback onRun;

  const ChallengeCard({
    super.key,
    required this.kicker,
    required this.icon,
    required this.accent,
    required this.girl,
    required this.roster,
    required this.marks,
    required this.scaleLabel,
    required this.onRun,
  });

  ChallengeMark? get _mine {
    final me = AuthService.userId;
    if (me == null) return null;
    for (final m in marks) {
      if (m.userId == me) return m;
    }
    return null;
  }

  ChallengeMark? get _winner {
    if (marks.isEmpty) return null;
    return marks.reduce((a, b) => a.raw >= b.raw ? a : b);
  }

  String _nameOf(String userId) {
    if (userId == AuthService.userId) return 'YOU';
    for (final m in roster) {
      if (m.userId == userId) return m.handle ?? 'ANON';
    }
    return 'ANON';
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final took = mine != null;
    final winner = _winner;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 12)),
          BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 30),
        ],
      ),
      child: Column(children: [
        // ── HER. The poster, same crop language as the Daily. ────────
        SizedBox(
          height: 210,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(
              girl.asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.12),
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.35),
                      AppColors.surface1
                    ],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.86),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 12, color: accent),
                    const SizedBox(width: 6),
                    Text(kicker,
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 9.5,
                          letterSpacing: 2.6,
                          fontWeight: FontWeight.w900,
                        )),
                    const Spacer(),
                    if (took)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.6)),
                        ),
                        child: Text('DONE',
                            style: GoogleFonts.inter(
                              color: accent,
                              fontSize: 8.5,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                  ]),
                  const Spacer(),
                  Text(girl.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.0,
                        letterSpacing: -1.6,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 16)
                        ],
                      )),
                  const SizedBox(height: 2),
                  Text(girl.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ]),
        ),

        // ── THE BADGE — your mark, or the invitation. ────────────────
        Container(
          width: double.infinity,
          color: AppColors.surface1,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(children: [
            if (took) ...[
              _Badge(value: mine.display, accent: accent, label: scaleLabel),
              const SizedBox(height: 14),
            ] else ...[
              _RunButton(
                label: 'RUN IT',
                accent: accent,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onRun();
                },
              ),
              const SizedBox(height: 8),
              Text('One attempt. Same woman for the whole squad.',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 14),
            ],

            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // ── THE ROOM. Everyone, scored or missing. ───────────────
            if (!took)
              Text('SCORES HIDDEN UNTIL YOU RUN IT',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  ))
            else
              Column(children: [
                for (final m in roster)
                  _Line(
                    name: _nameOf(m.userId),
                    mark: _markFor(m.userId),
                    accent: accent,
                    isWinner:
                        winner != null && winner.userId == m.userId,
                    mine: m.userId == AuthService.userId,
                  ),
              ]),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.04);
  }

  ChallengeMark? _markFor(String userId) {
    for (final m in marks) {
      if (m.userId == userId) return m;
    }
    return null;
  }
}

/// The score, worn like a medal. Same shape for both challenges so a
/// 7.4 and an 82 read as the same kind of achievement.
class _Badge extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;
  const _Badge({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.6),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 22)
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 30,
              height: 1,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 8.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

class _RunButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _RunButton(
      {required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 22)
          ],
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            )),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.015, duration: 1400.ms);
  }
}

/// One man's line: his mark, or the fact he hasn't shown up. The
/// missing ones are the whole point of showing the room.
class _Line extends StatelessWidget {
  final String name;
  final ChallengeMark? mark;
  final Color accent;
  final bool isWinner;
  final bool mine;
  const _Line({
    required this.name,
    required this.mark,
    required this.accent,
    required this.isWinner,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    // Copied to a local first. `mark` is a public field, and Dart won't
    // promote those to non-null across a check — the field could in
    // principle be overridden by a getter — so `mark.display` after
    // `mark != null` is a compile error. A local has no such doubt.
    final m = mark;
    final done = m != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? accent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
                color: done
                    ? accent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(name.characters.first.toUpperCase(),
              style: GoogleFonts.inter(
                color: done ? accent : AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: mine ? Colors.white : AppColors.textSecondary,
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                  )),
            ),
            if (isWinner) ...[
              const SizedBox(width: 6),
              const Icon(Icons.emoji_events_rounded, size: 13, color: kNeon),
            ],
          ]),
        ),
        Text(done ? m.display : 'MISSING',
            style: GoogleFonts.inter(
              color: done ? Colors.white : AppColors.textMuted,
              fontSize: done ? 15 : 9,
              letterSpacing: done ? -0.4 : 1.4,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}
