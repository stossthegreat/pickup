import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/economy.dart';
import '../../theme/app_colors.dart';

/// YOUR FIVE — the roster as portrait cards, not a Discord member list.
///
/// One card per man, sized to the squad: two members get big cards,
/// five compress intelligently. Each carries a name, a moves count and
/// a thin progress arc — and nothing else. Complexity appears on
/// interaction: tap and the card expands IN PLACE into the breakdown
/// rather than pushing a statistics screen.
///
/// Empty seats are shown deliberately. A two-man squad with three
/// visible + RECRUIT seats reads as "room for more" and puts the invite
/// one tap from the most-looked-at screen in the feature.
class YourFive extends StatefulWidget {
  final SquadDay day;
  final VoidCallback onRecruit;
  final void Function(SquadMember member)? onNudge;

  const YourFive({
    super.key,
    required this.day,
    required this.onRecruit,
    this.onNudge,
  });

  @override
  State<YourFive> createState() => _YourFiveState();
}

class _YourFiveState extends State<YourFive> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final expanded = _open;

    return Column(children: [
      Row(children: [
        for (final m in d.roster) ...[
          Expanded(child: _card(m)),
          const SizedBox(width: 8),
        ],
        for (var i = 0; i < d.openSeats; i++) ...[
          Expanded(child: _seat()),
          if (i != d.openSeats - 1) const SizedBox(width: 8),
        ],
      ]),
      // The expanded panel lives BELOW the row so the row never reflows
      // — cards stay exactly where your thumb left them.
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: expanded == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _detail(
                    d.roster.firstWhere((m) => m.userId == expanded)),
              ),
      ),
    ]);
  }

  String _nameOf(SquadMember m) =>
      m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');

  Widget _card(SquadMember m) {
    final d = widget.day;
    final moves = d.movesFor(m.userId);
    final full = moves >= SquadDay.movesPerMember;
    final mine = m.userId == AuthService.userId;
    final active = d.activeNow(m.userId);
    final isOpen = _open == m.userId;
    // Two members → big portraits. Five → compressed.
    final big = d.roster.length <= 2;
    final size = big ? 92.0 : (d.roster.length <= 3 ? 74.0 : 56.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _open = isOpen ? null : m.userId);
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            // The arc IS the stat — no badge soup on the portrait.
            TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: 0, end: moves / SquadDay.movesPerMember),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(
                size: Size.square(size),
                painter: _ArcPainter(
                  value: v,
                  color: full ? kNeon : AppColors.red,
                  stroke: big ? 4 : 3,
                ),
              ),
            ),
            Container(
              width: size - (big ? 16 : 12),
              height: size - (big ? 16 : 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2,
                border: Border.all(
                    color: mine
                        ? AppColors.red.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.10)),
                image: m.avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(m.avatarUrl!), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: m.avatarUrl != null
                  ? null
                  : Text(_nameOf(m).characters.first.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: big ? 26 : 18,
                        fontWeight: FontWeight.w900,
                      )),
            ),
            // Live dot — he's got something in flight right now.
            if (active)
              Positioned(
                right: 2,
                top: 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.base, width: 1.6),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.35, end: 1, duration: 900.ms),
              ),
          ]),
        ),
        const SizedBox(height: 7),
        Text(_nameOf(m),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: mine ? AppColors.red : Colors.white,
              fontSize: big ? 12 : 10.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 1),
        Text('$moves/${SquadDay.movesPerMember}',
            style: GoogleFonts.inter(
              color: full ? kNeon : AppColors.textMuted,
              fontSize: big ? 11 : 9.5,
              fontWeight: FontWeight.w800,
            )),
      ]),
    );
  }

  Widget _seat() {
    final big = widget.day.roster.length <= 2;
    final size = big ? 92.0 : (widget.day.roster.length <= 3 ? 74.0 : 56.0);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onRecruit();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DottedCircle(size: size),
        const SizedBox(height: 7),
        Text('RECRUIT',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: big ? 10 : 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 1),
        Text('—',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: big ? 11 : 9.5,
              fontWeight: FontWeight.w800,
            )),
      ]),
    );
  }

  /// The breakdown, revealed on tap. Split by what the moves actually
  /// are, so it explains the model rather than restating the number.
  Widget _detail(SquadMember m) {
    final d = widget.day;
    final missions = d.missionMovesFor(m.userId);
    final daily = d.dailyFor(m.userId);
    final took = daily?.finished ?? false;
    final bailed = daily != null && !daily.finished;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
              '${_nameOf(m)} · ${d.movesFor(m.userId)}'
              '/${SquadDay.movesPerMember}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          if (d.activeNow(m.userId))
            Text('CURRENTLY ACTIVE',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                )),
        ]),
        const SizedBox(height: 12),
        _Bar(
            label: 'REPS',
            value: missions,
            max: SquadDay.missionsPerDay,
            color: kNeon),
        const SizedBox(height: 8),
        _Bar(
            label: 'RIZZ-OFF',
            value: took ? 1 : 0,
            max: 1,
            color: AppColors.red,
            // Same reason as the others — 'bottled' is British.
            note: bailed ? 'BAILED' : null),
        if (took && daily?.score != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Text('VOICE',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(width: 8),
            Text(voiceOutOfTen(daily!.score!),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                )),
            Text(' / 100',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                )),
          ]),
        ],
        if (m.userId != AuthService.userId && widget.onNudge != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onNudge!(m);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.red.withValues(alpha: 0.5)),
              ),
              child: Text('NUDGE',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Voice scores on the ONE scale — see lib/services/economy.dart rule 2.
///
/// This used to render out of 10 while chat rendered out of 100 and
/// battles leaked the raw four-digit grade. Three scales for one concept
/// meant a man could see 2,450, 8.7 and 84 in a single session with no
/// way to know they were the same kind of number. The grader still
/// stores 0–9999 for resolution; that never reaches a screen again.
///
/// Name kept so every existing call site keeps compiling — what it
/// returns is what changed, and it changed in exactly one place.
String voiceOutOfTen(int raw) => '${Economy.aiScoreFromVoice(raw)}';

class _Bar extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color;
  final String? note;
  const _Bar(
      {required this.label,
      required this.value,
      required this.max,
      required this.color,
      this.note});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 68,
        child: Text(label,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            )),
      ),
      Expanded(
        child: Row(children: [
          for (var i = 0; i < max; i++) ...[
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < value
                      ? color
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: i < value
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 8)
                        ]
                      : null,
                ),
              ),
            ),
            if (i != max - 1) const SizedBox(width: 4),
          ],
        ]),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 44,
        child: Text(note ?? '$value/$max',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: note != null ? AppColors.red : AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            )),
      ),
    ]);
  }
}

/// An open seat. Dashed rather than solid so it reads as a space to
/// fill, not a broken avatar.
class DottedCircle extends StatelessWidget {
  final double size;
  const DottedCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DottedPainter(),
        child: Center(
          child: Icon(Icons.add_rounded,
              size: size * 0.32, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);
    const dashes = 26;
    const sweep = (math.pi * 2) / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        i * sweep,
        sweep * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedPainter old) => false;
}

class _ArcPainter extends CustomPainter {
  final double value; // 0..1
  final Color color;
  final double stroke;
  const _ArcPainter(
      {required this.value, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2 - 1;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    const start = -math.pi / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      start,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(
      rect,
      start,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}
