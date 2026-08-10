import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_service.dart';
import '../../theme/app_colors.dart';

/// A squad's week, graded. Not a progress bar — a verdict.
class SquadGrade {
  final String letter; // A+ .. F
  final String label; // ELITE / STRONG / SLIPPING / DEAD
  final String verdict; // one line that reads like a coach talking
  final Color color;
  final double pct; // 0..1 squares filled

  const SquadGrade(
      this.letter, this.label, this.verdict, this.color, this.pct);

  static const _neon = Color(0xFF2EE87A);
  static const _gold = Color(0xFFF5C542);

  /// [done] squares filled, [possible] members × 7.
  factory SquadGrade.of(int done, int possible) {
    final pct = possible == 0 ? 0.0 : done / possible;
    if (pct >= 0.85) {
      return SquadGrade('A+', 'ELITE',
          'This squad is operating. Nobody is hiding.', _neon, pct);
    }
    if (pct >= 0.70) {
      return SquadGrade('A', 'STRONG',
          'Serious week. One more push and you\'re elite.', _neon, pct);
    }
    if (pct >= 0.55) {
      return SquadGrade(
          'B', 'SOLID', 'Good, not dangerous. Who\'s carrying?', _gold, pct);
    }
    if (pct >= 0.40) {
      return SquadGrade('C', 'SLIPPING',
          'Half the squad is coasting. Say something.', _gold, pct);
    }
    if (pct >= 0.20) {
      return SquadGrade('D', 'WEAK',
          'This is a group chat, not a squad. Move.', AppColors.red, pct);
    }
    return SquadGrade('F', 'DEAD',
        'Nobody has shown up. Somebody go first.', AppColors.red, pct);
  }
}

/// THE SQUAD REPORT — the grade, the meter, and every man's
/// contribution so it's obvious who's carrying and who's hiding.
class SquadReport extends StatelessWidget {
  final List<SquadMember> roster;
  final List<WeekMark> marks;
  const SquadReport({super.key, required this.roster, required this.marks});

  @override
  Widget build(BuildContext context) {
    final done = marks.where((m) => m.completed).length;
    final possible = roster.length * 7;
    final g = SquadGrade.of(done, possible);

    // Per-man contribution, best first — the pecking order, visible.
    final rows = [
      for (final m in roster)
        (
          m,
          marks
              .where((w) => w.userId == m.userId && w.completed)
              .length,
        )
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.surface2, g.color, 0.10)!,
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8)),
          BoxShadow(color: g.color.withValues(alpha: 0.14), blurRadius: 26),
        ],
      ),
      child: Column(children: [
        Row(children: [
          // The grade — struck, glowing, unmissable.
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  g.color.withValues(alpha: 0.30),
                  g.color.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: g.color, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: g.color.withValues(alpha: 0.45), blurRadius: 26)
              ],
            ),
            alignment: Alignment.center,
            child: Text(g.letter,
                style: GoogleFonts.inter(
                  color: g.color,
                  fontSize: g.letter.length > 1 ? 30 : 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: g.color.withValues(alpha: 0.6),
                        blurRadius: 18)
                  ],
                )),
          )
              .animate()
              .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 620.ms,
                  curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 1400.ms, color: Colors.white24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SQUAD RATING',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 3),
                Text(g.label,
                    style: GoogleFonts.inter(
                      color: g.color,
                      fontSize: 20,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 4),
                Text(g.verdict,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // The meter.
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: g.pct),
                duration: const Duration(milliseconds: 950),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: AppColors.surface2,
                  valueColor: AlwaysStoppedAnimation(g.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$done/$possible',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 16),
        Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 12),
        // Who's carrying, who's hiding.
        for (final (i, r) in rows.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 9),
            child: _contribution(r.$1, r.$2, i),
          ),
      ]),
    );
  }

  Widget _contribution(SquadMember m, int done, int rank) {
    final mine = m.userId == AuthService.userId;
    final carrying = rank == 0 && done > 0;
    final hiding = done == 0;
    final color = hiding
        ? AppColors.textMuted
        : carrying
            ? const Color(0xFFF5C542)
            : AppColors.red;
    return Row(children: [
      SizedBox(
        width: 18,
        child: carrying
            ? const Icon(Icons.local_fire_department_rounded,
                size: 15, color: Color(0xFFF5C542))
            : Text('${rank + 1}',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                )),
      ),
      const SizedBox(width: 8),
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface2,
          border: Border.all(
              color: mine ? AppColors.red : Colors.white24, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          (mine ? 'YOU' : (m.handle ?? 'A')).characters.first.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(mine ? 'YOU' : (m.handle ?? 'ANON'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: mine ? Colors.white : AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: mine ? FontWeight.w900 : FontWeight.w700,
            )),
      ),
      // Seven pips — his week at a glance.
      Row(children: [
        for (var d = 0; d < 7; d++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: d < done ? color : AppColors.surface3,
              shape: BoxShape.circle,
              boxShadow: d < done
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6)
                    ]
                  : null,
            ),
          ),
      ]),
      const SizedBox(width: 10),
      SizedBox(
        width: 34,
        child: Text(
          hiding ? 'HIDING' : '$done',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            color: hiding ? AppColors.textMuted : color,
            fontSize: hiding ? 8.5 : 13,
            letterSpacing: hiding ? 0.8 : 0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ]);
  }
}
