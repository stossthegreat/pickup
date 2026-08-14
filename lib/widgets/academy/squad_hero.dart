import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/squad_history_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import 'squad_chrome.dart';

/// SQUAD HOME — THE HERO. "How are we doing?"
///
/// The old first screen answered "what squad features exist" — a menu
/// with chapters. Nobody opens a squad to browse a menu. They open it to
/// find out how the five of them are doing, and whether they're the one
/// holding it up. So the top of the screen is one number, one bar, and
/// two facts.
///
/// THE NUMBER IS SHARED AND ONLY GOES UP. That's what makes it safe to
/// put at the top: a man who's had a bad week doesn't open this and see
/// himself punished, he sees the thing the five of them have built. The
/// chain is the fragile object, and it lives further down where losing
/// it is a call to action rather than the first thing he reads.
///
/// THE DELTA IS THE POINT. A cumulative total that never visibly moves
/// is wallpaper. "▲ 620 TODAY" is what makes a man run one more mission
/// before midnight, and it's the only number on here that changes while
/// he's looking at it.
class SquadHero extends StatelessWidget {
  final String name;
  final SquadHistory history;
  final int memberCount;

  /// Global placing, when the board is live. Null hides the line rather
  /// than printing a fake rank — an invented number on the hero would
  /// poison every real number under it.
  final int? globalRank;

  const SquadHero({
    super.key,
    required this.name,
    required this.history,
    required this.memberCount,
    this.globalRank,
  });

  @override
  Widget build(BuildContext context) {
    final h = history;
    final banked = h.todayBanked;
    final accent = banked ? kNeon : AppColors.red;

    return SizedBox(
      height: 302,
      child: Stack(children: [
        const Positioned.fill(child: SquadAtmosphere(accent: AppColors.red)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.base],
                stops: const [0.55, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
            child: Column(children: [
              // ── Identity ────────────────────────────────────────
              Text(name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 4.5,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 16)
                    ],
                  )),
              if (globalRank != null) ...[
                const SizedBox(height: 5),
                Text('#$globalRank GLOBAL',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w900,
                    )),
              ],
              const SizedBox(height: 20),

              // ── The number ──────────────────────────────────────
              Text('SQUAD SCORE',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 8.5,
                    letterSpacing: 4.2,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: h.score.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(_commas(v.round()),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 58,
                      height: 1,
                      letterSpacing: -3,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 40)
                      ],
                    )),
              ),
              const SizedBox(height: 6),
              if (h.scoreToday > 0)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_upward_rounded, size: 13, color: accent),
                  const SizedBox(width: 4),
                  Text('${_commas(h.scoreToday)} TODAY',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      )),
                ]).animate().fadeIn(delay: 700.ms, duration: 400.ms)
              else
                Text('NOBODY HAS MOVED TODAY',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w900,
                    )),

              const Spacer(),

              // ── The level bar ───────────────────────────────────
              _LevelBar(level: h.level, progress: h.levelProgress),
              const SizedBox(height: 13),

              // ── Two facts, and nothing else ─────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _fact(
                  h.streak > 0 ? '${h.streak} DAY CHAIN' : 'NO CHAIN YET',
                  h.streak > 0 ? AppColors.red : AppColors.textMuted,
                ),
                Container(
                  width: 1,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                _fact('${h.activeToday}/$memberCount ACTIVE TODAY',
                    h.activeToday >= memberCount
                        ? kNeon
                        : AppColors.textSecondary),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _fact(String s, Color c) => Text(s,
      style: GoogleFonts.inter(
        color: c,
        fontSize: 9.5,
        letterSpacing: 2,
        fontWeight: FontWeight.w900,
      ));

  static String _commas(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// LEVEL 14 ███████░░ LEVEL 15.
///
/// Bounded progress next to an unbounded score. The score says how much
/// they've done ever; the bar says how close the next thing is, and a
/// near-full bar is worth more effort at 11pm than any total.
class _LevelBar extends StatelessWidget {
  final int level;
  final double progress;
  const _LevelBar({required this.level, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _cap('LVL $level', Colors.white),
      const SizedBox(width: 10),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(height: 7, color: Colors.white.withValues(alpha: 0.08)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v.clamp(0.02, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.redDim, AppColors.red]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.7),
                          blurRadius: 12)
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      _cap('LVL ${math.min(level + 1, 99)}', AppColors.textMuted),
    ]);
  }

  Widget _cap(String s, Color c) => Text(s,
      style: GoogleFonts.inter(
        color: c,
        fontSize: 9,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w900,
      ));
}
