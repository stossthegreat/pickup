import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_history_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';

/// THE CHAIN — the squad's one shared, losable thing.
///
/// This is the highest-leverage object in the app and it costs one
/// database read. Every other mechanic here motivates one man in
/// isolation; this one puts four of them in a room and makes today's
/// effort visible to people whose opinion he actually cares about.
/// Social facilitation beats every solo incentive we could design, and
/// unlike a reward it doesn't cost anything to hand out.
///
/// It is drawn as an actual chain rather than a row of dots for a
/// reason. A dot that didn't light up is a missing data point. A link
/// that SNAPPED, with the two halves pulled apart, is damage — and the
/// difference between those two readings is the difference between
/// "I should catch up" and "that was me".
///
/// Nothing in here is decorative-only:
///   · the number is what he's protecting
///   · the break is where it went and roughly whose it was
///   · the quorum line is the exact price of banking today
///   · the armband is a status object he can lose in his sleep
///   · the bench is the door left open for the man who fell off
class SquadStreakHero extends StatelessWidget {
  final SquadHistory history;
  final List<SquadMember> roster;
  final Color accent;

  /// Fires when he taps the "run it" affordance on an unbanked day.
  final VoidCallback? onRun;

  const SquadStreakHero({
    super.key,
    required this.history,
    required this.roster,
    required this.accent,
    this.onRun,
  });

  List<String> get _ids => [for (final m in roster) m.userId];

  String _name(String id) {
    for (final m in roster) {
      if (m.userId == id) {
        return m.userId == AuthService.userId
            ? 'YOU'
            : (m.handle ?? 'ANON').toUpperCase();
      }
    }
    return 'ANON';
  }

  /// "TOM", "TOM AND JAKE", "TOM, JAKE AND 2 MORE" — never a wall.
  String _list(List<String> ids) {
    if (ids.isEmpty) return '';
    final names = [for (final id in ids) _name(id)];
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} AND ${names[1]}';
    return '${names[0]}, ${names[1]} AND ${names.length - 2} MORE';
  }

  @override
  Widget build(BuildContext context) {
    final h = history;
    final streak = h.streak;
    final alive = streak > 0;
    final banked = h.todayBanked;
    final tone = banked ? kNeon : (alive ? accent : AppColors.textTertiary);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.11),
            AppColors.surface1,
            AppColors.base,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: tone.withValues(alpha: alive ? 0.4 : 0.14)),
        boxShadow: alive
            ? [BoxShadow(color: tone.withValues(alpha: 0.16), blurRadius: 28)]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _topLine(h, tone, alive),
        const SizedBox(height: 14),
        // THE CHAIN ITSELF.
        SizedBox(
          height: 46,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => CustomPaint(
              painter: _ChainPainter(
                days: h.tail(14),
                banked: {for (final d in h.tail(14)) d: h.banked(d)},
                todayYmd: h.todayYmd,
                accent: tone,
                reveal: t,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _quorumLine(h, banked),
        _armband(h),
        _bench(h),
        _memory(h, alive),
      ]),
    );
  }

  // ── The number ──────────────────────────────────────────────────────
  Widget _topLine(SquadHistory h, Color tone, bool alive) {
    final best = h.best;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SQUAD STREAK',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 8.5,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: h.streak.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${v.round()}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 44,
                  height: 1,
                  letterSpacing: -2.4,
                  fontWeight: FontWeight.w900,
                  shadows: alive
                      ? [
                          Shadow(
                              color: tone.withValues(alpha: 0.55),
                              blurRadius: 26)
                        ]
                      : null,
                )),
          ),
          const SizedBox(width: 7),
          Text(h.streak == 1 ? 'DAY' : 'DAYS',
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 11,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ]),
      const Spacer(),
      // The number to beat. A broken streak with no high-water mark is
      // just a zero; with one it's a target, and a target is startable.
      if (best > 0)
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$best',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          Text('BEST',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 7.5,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              )),
        ]),
    ]);
  }

  // ── The price of today ──────────────────────────────────────────────
  Widget _quorumLine(SquadHistory h, bool banked) {
    if (h.memberCount < 2) {
      return Text('One more man and the chain starts.',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ));
    }
    if (banked) {
      return Row(children: [
        const Icon(Icons.verified_rounded, size: 15, color: kNeon),
        const SizedBox(width: 8),
        Expanded(
          // Named, not tallied. "3 of 4 ran it" is a report; "CHAIN
          // SECURED · DAY 14" is the thing he'll screenshot.
          child: Text(
              h.streak > 0
                  ? 'CHAIN SECURED · DAY ${h.streak}'
                  : 'CHAIN SECURED · ${h.ranToday} OF ${h.memberCount} RAN IT',
              style: GoogleFonts.inter(
                color: kNeon,
                fontSize: 10.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              )),
        ),
      ]);
    }

    final short = h.shortToday;
    final waiting = h.missingToday(_ids);
    // IS HE ONE OF THE MISSING? "2 more men bank today" is a status
    // report about other people. "Your squad is waiting on you" is a
    // debt. Same data; only one of them gets a man off the sofa, and
    // it's never the one written in the passive voice.
    final mine = !h.whoRan(h.todayYmd).contains(AuthService.userId) &&
        !h.benched(AuthService.userId ?? '');
    return GestureDetector(
      onTap: onRun,
      behavior: HitTestBehavior.opaque,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                mine
                    ? 'YOU HAVEN\'T BANKED TODAY'
                    : short == 1
                        ? '1 MAN LEFT TO SAVE THE CHAIN'
                        : '$short MEN LEFT TO SAVE THE CHAIN',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 10.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ])
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.62, end: 1, duration: 1100.ms),
        if (mine) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 23),
            child: Text('YOUR SQUAD IS WAITING ON YOU',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 9.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ] else if (waiting.isNotEmpty) ...[
          const SizedBox(height: 5),
          // NAMED, AS FACT. This single line does more work than any
          // reward in the app — and it stays effective only while it
          // stays fair, so benched men are excluded and nobody is
          // called anything.
          Padding(
            padding: const EdgeInsets.only(left: 23),
            child: Text('WAITING ON ${_list(waiting)}',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 9.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      ]),
    );
  }

  // ── The armband ─────────────────────────────────────────────────────
  Widget _armband(SquadHistory h) {
    final id = h.captainOf(_ids);
    if (id == null) return const SizedBox.shrink();
    final mine = id == AuthService.userId;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD34D).withValues(alpha: 0.14),
            border: Border.all(
                color: const Color(0xFFFFD34D).withValues(alpha: 0.6)),
          ),
          child: const Icon(Icons.shield_rounded,
              size: 11, color: Color(0xFFFFD34D)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              mine
                  ? 'YOU HAVE THE ARMBAND · ${h.runsRecent(id)} RUNS'
                  : '${_name(id)} HAS THE ARMBAND · ${h.runsRecent(id)} RUNS',
              style: GoogleFonts.inter(
                color: const Color(0xFFFFD34D),
                fontSize: 10,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w900,
              )),
        ),
      ]),
    );
  }

  // ── The bench ───────────────────────────────────────────────────────
  Widget _bench(SquadHistory h) {
    final out = h.benchedOf(_ids);
    if (out.isEmpty) return const SizedBox.shrink();
    final mine = out.contains(AuthService.userId);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.signalAmber.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(11),
          border:
              Border.all(color: AppColors.signalAmber.withValues(alpha: 0.28)),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded,
              size: 14, color: AppColors.signalAmber),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
                mine
                    ? 'YOU\'RE BENCHED. One run puts you straight back in.'
                    : '${_list(out)} ${out.length == 1 ? 'IS' : 'ARE'} BENCHED — '
                        'not counted against the chain until back.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
      ),
    );
  }

  // ── Where the last one died ─────────────────────────────────────────
  Widget _memory(SquadHistory h, bool alive) {
    if (alive) return const SizedBox.shrink();
    final b = h.lastBreak(_ids);
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
          'The last one died at ${b.run} on ${SquadHistory.pretty(b.ymd)}'
          '${b.missing.isEmpty ? '.' : ' — ${_list(b.missing)} didn\'t run.'}',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE PAINTER
// ══════════════════════════════════════════════════════════════════════

/// An actual interlocking chain: links alternate flat and upright and
/// overlap, the way real chain does. Banked days are lit and glowing;
/// missed days are dark; the day a run ENDED is drawn snapped, its two
/// halves pulled apart.
///
/// The snap is the whole reason this is a painter and not ten Containers
/// in a Row. Damage reads instantly and it reads as damage.
class _ChainPainter extends CustomPainter {
  final List<int> days;
  final Map<int, bool> banked;
  final int todayYmd;
  final Color accent;

  /// 0..1 — the chain assembles left to right on first paint.
  final double reveal;

  const _ChainPainter({
    required this.days,
    required this.banked,
    required this.todayYmd,
    required this.accent,
    required this.reveal,
  });

  bool _on(int i) => banked[days[i]] ?? false;

  /// A link is SNAPPED when it's the day a run of two or more ended —
  /// not merely any day nobody showed up. Drawing every gap as damage
  /// makes damage meaningless.
  bool _snapped(int i) {
    if (_on(i)) return false;
    var run = 0;
    for (var j = i - 1; j >= 0 && _on(j); j--) {
      run++;
    }
    return run >= 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = days.length;
    if (n == 0 || size.width <= 0) return;

    final pitch = size.width / n;
    final len = pitch * 1.62; // > pitch, so consecutive links overlap
    final cy = size.height / 2;
    final stroke = math.min(3.0, math.max(2.0, pitch * 0.13));

    for (var i = 0; i < n; i++) {
      // Assemble left to right, each link popping in slightly late.
      final t = ((reveal * n) - i).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final cx = pitch * (i + 0.5);
      final flat = i.isEven;
      final w = flat ? len : len * 0.46;
      final hgt = flat ? len * 0.46 : len * 0.86;

      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * t,
        height: hgt * t,
      );
      final rr = RRect.fromRectAndRadius(
          rect, Radius.circular(math.min(rect.width, rect.height) / 2));
      final path = Path()..addRRect(rr);

      final on = _on(i);
      final today = days[i] == todayYmd;
      final snapped = _snapped(i);

      final colour = on
          ? accent
          : today
              ? AppColors.signalAmber
              : (snapped ? AppColors.redDim : AppColors.surface3);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: on ? 1 : (today ? 0.9 : 0.75));

      // Glow under the lit links only — a glow on the dead ones would
      // flatten the whole row back into decoration.
      if (on) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke + 1.4
            ..color = accent.withValues(alpha: 0.34)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }

      if (snapped) {
        _drawSnapped(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
        // Today, still open: a hollow pulse ring so the newest link
        // reads as unfinished rather than failed.
        if (today && !on) {
          canvas.drawCircle(
            Offset(cx, cy),
            math.max(rect.width, rect.height) * 0.13,
            Paint()..color = AppColors.signalAmber.withValues(alpha: 0.55),
          );
        }
      }
    }
  }

  /// The link, cut and pulled apart. Two arcs off the same outline so
  /// the break is unmistakably THIS link rather than a missing one.
  void _drawSnapped(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      final l = metric.length;
      if (l <= 0) continue;
      final a = metric.extractPath(0, l * 0.40);
      final b = metric.extractPath(l * 0.60, l);
      canvas
        ..save()
        ..translate(0, -3.0)
        ..drawPath(a, paint)
        ..restore()
        ..save()
        ..translate(0, 3.0)
        ..drawPath(b, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChainPainter old) =>
      old.reveal != reveal ||
      old.accent != accent ||
      old.days.length != days.length ||
      old.todayYmd != todayYmd;
}
