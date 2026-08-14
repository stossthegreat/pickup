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
      height: 372,
      child: Stack(children: [
        const Positioned.fill(child: SquadAtmosphere(accent: AppColors.red)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.base],
                stops: const [0.6, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
            child: Column(children: [
              Text(name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 19,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 16)
                    ],
                  )),
              if (globalRank != null) ...[
                const SizedBox(height: 4),
                Text('#$globalRank GLOBAL',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w900,
                    )),
              ],
              const SizedBox(height: 16),

              // ── THE EMBLEM ────────────────────────────────────────
              // The level was a flat progress bar under a flat number:
              // two rectangles, no weight, nothing to want. It's a ring
              // now — the score sits inside the level, the arc IS the
              // progress, and the whole thing reads as one object a
              // squad owns rather than two stats stacked up.
              SizedBox(
                width: 208,
                height: 208,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, __) => CustomPaint(
                    painter: _EmblemPainter(
                      progress: h.levelProgress * t,
                      accent: accent,
                      banked: banked,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('SQUAD SCORE',
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 8,
                                letterSpacing: 3.6,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 4),
                          Text(_commas((h.score * t).round()),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 52,
                                height: 1,
                                letterSpacing: -2.6,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                      color: accent.withValues(alpha: 0.6),
                                      blurRadius: 34)
                                ],
                              )),
                          const SizedBox(height: 6),
                          // The level lives INSIDE the ring that shows
                          // it. One object, one meaning.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.5)),
                            ),
                            child: Text('LEVEL ${h.level}',
                                style: GoogleFonts.inter(
                                  color: accent,
                                  fontSize: 9.5,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w900,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── THE LINE THAT MAKES HIM MOVE ─────────────────────
              // Not a status report. The delta if there is one, the ask
              // if there isn't. Either way it names the next thing.
              if (h.scoreToday > 0)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_upward_rounded, size: 14, color: accent),
                  const SizedBox(width: 5),
                  Text('${_commas(h.scoreToday)} TODAY',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 13,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w900,
                      )),
                ]).animate().fadeIn(delay: 800.ms, duration: 400.ms)
              else
                Text('BE THE FIRST NAME ON TODAY',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w900,
                    )).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
                    begin: 0.5, end: 1, duration: 1300.ms),

              const Spacer(),
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

/// THE EMBLEM — the level as a ring around the score.
///
/// A progress bar is a measurement. A ring with the number sitting
/// inside it is a crest, and men want crests. Same data, and the second
/// one is the difference between a screen you check and a screen you
/// want to fill.
///
/// Three passes, outermost first: a dim track so the unfilled part is
/// still an object, the lit arc for progress with a glow under it, and
/// tick marks at the quarters so the arc has somewhere to be going.
class _EmblemPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final bool banked;
  const _EmblemPainter(
      {required this.progress,
      required this.accent,
      required this.banked});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;

    // The unfilled track.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white.withValues(alpha: 0.055));

    // Quarter ticks — the arc needs somewhere to be going.
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r + 8);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r + 13);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.16));
    }

    if (progress > 0.001) {
      final rect = Rect.fromCircle(center: c, radius: r);
      const start = -math.pi / 2;
      final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);

      // Glow under the lit arc.
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..color = accent.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + math.pi * 2,
              colors: [AppColors.redDim, accent, accent],
              stops: const [0, 0.6, 1],
              transform: GradientRotation(start),
            ).createShader(rect));

      // The head of the arc — a bright cap so progress has a leading
      // edge rather than just ending.
      final head = start + sweep;
      canvas.drawCircle(
          c + Offset(math.cos(head), math.sin(head)) * r,
          5,
          Paint()..color = Colors.white);
      canvas.drawCircle(
          c + Offset(math.cos(head), math.sin(head)) * r,
          9,
          Paint()
            ..color = accent.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // A banked day rings the whole emblem — the one visual that says
    // "today is safe" without a word on it.
    if (banked) {
      canvas.drawCircle(
          c,
          r + 17,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = accent.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.banked != banked;
}
