import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import 'game_feel.dart';

/// THE FIVE — who has done today's programme, and who needs pushing.
///
/// This is the functional heart of a squad and the old board buried it
/// in a grid of ticks that took real effort to read. One row of faces,
/// each in its own completion ring, sorted so the man holding everyone
/// up is impossible to miss. Half a second to read; that's the bar.
///
/// ──────────────────────────────────────────────────────────────────
/// THE DIFFERENT-STAGES PROBLEM, SOLVED BY NOT HAVING IT
/// ──────────────────────────────────────────────────────────────────
/// Two men at different points in the 60-day map get different missions,
/// so a board that compared WHICH missions they did would be nonsense —
/// and worse, it would punish the man who's further on for having harder
/// work.
///
/// So this board never compares mission identity. It compares MOVES
/// MADE OUT OF FIVE. Everyone has exactly five a day whatever their
/// stage, so 4/5 means the same thing for a day-3 man and a day-50 man:
/// he showed up and did four fifths of what was asked of him.
///
/// The two things that ARE identical for everyone — the daily voice
/// Rizz-Off and the chat challenge, same woman worldwide — are compared
/// on SCORE, further down. Effort where the work differs, score where it
/// doesn't. That distinction is the whole answer.
///
/// ──────────────────────────────────────────────────────────────────
/// AND IT HAS TO DO SOMETHING
/// ──────────────────────────────────────────────────────────────────
/// Showing that Tyler is on 1/5 is information. Tapping Tyler, seeing
/// exactly which four he's missing, and putting your name on a nudge is
/// a mechanic. The squad only retains anybody if the men in it can act
/// on each other, so every face here is a door to that.
class FiveBoard extends StatelessWidget {
  final SquadDay day;
  final List<SquadMember> roster;

  /// Fires with the member he wants to push.
  final void Function(SquadMember) onNudge;

  const FiveBoard({
    super.key,
    required this.day,
    required this.roster,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    // Behind first. The man who needs pushing should never be the one
    // you have to scan for.
    final sorted = [...roster]
      ..sort((a, b) => day.movesFor(a.userId).compareTo(day.movesFor(b.userId)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('TODAY',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w900,
            )),
        const Spacer(),
        Text('${day.complete} / ${day.possible}',
            style: GoogleFonts.inter(
              color: day.won ? kNeon : AppColors.red,
              fontSize: 13,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 5),
        Text('MOVES',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 8.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            )),
      ]),
      const SizedBox(height: 14),
      Row(
        children: [
          for (final (i, m) in sorted.indexed)
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == sorted.length - 1 ? 0 : 8),
                child: _Man(
                  member: m,
                  moves: day.movesFor(m.userId),
                  onTap: () => _open(context, m),
                ).animate().fadeIn(delay: (60 * i).ms, duration: 280.ms),
              ),
            ),
          // Empty seats read as an invitation, not a gap.
          for (var i = 0; i < day.openSeats && sorted.length < 5; i++)
            const Expanded(child: SizedBox()),
        ],
      ),
    ]);
  }

  void _open(BuildContext context, SquadMember m) {
    Feel.tick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManSheet(
        member: m,
        day: day,
        onNudge: () {
          Navigator.of(context).maybePop();
          onNudge(m);
        },
      ),
    );
  }
}

/// One man: a ring that fills with his moves, his initials, his count.
class _Man extends StatelessWidget {
  final SquadMember member;
  final int moves;
  final VoidCallback onTap;
  const _Man(
      {required this.member, required this.moves, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final me = member.userId == AuthService.userId;
    final done = moves >= SquadDay.movesPerMember;
    final behind = moves <= 1;
    final tone = done
        ? kNeon
        : behind
            ? AppColors.red
            : AppColors.signalAmber;
    final handle = (member.handle ?? 'ANON').toUpperCase();
    final initials = handle.length >= 2 ? handle.substring(0, 2) : handle;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        SizedBox(
          height: 54,
          width: 54,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: moves / SquadDay.movesPerMember),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => CustomPaint(
              painter: _RingPainter(progress: v, tone: tone, mine: me),
              child: Center(
                child: Text(initials,
                    style: GoogleFonts.inter(
                      color: me ? Colors.white : AppColors.textSecondary,
                      fontSize: 15,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(me ? 'YOU' : handle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: me ? Colors.white : AppColors.textTertiary,
              fontSize: 8.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 2),
        Text('$moves/${SquadDay.movesPerMember}',
            style: GoogleFonts.inter(
              color: tone,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color tone;
  final bool mine;
  const _RingPainter(
      {required this.progress, required this.tone, required this.mine});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.08));

    if (progress > 0) {
      if (progress >= 0.999) {
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = tone.withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = tone,
      );
    }

    // His own ring gets a filled core so he finds himself instantly.
    canvas.drawCircle(
        c,
        r - 4,
        Paint()
          ..color = mine
              ? tone.withValues(alpha: 0.16)
              : AppColors.surface1.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.tone != tone || old.mine != mine;
}

/// Tap a man → exactly what he's missing, and a button with your name
/// on it. Information plus a lever, which is the only combination that
/// changes anybody's behaviour.
class _ManSheet extends StatelessWidget {
  final SquadMember member;
  final SquadDay day;
  final VoidCallback onNudge;
  const _ManSheet(
      {required this.member, required this.day, required this.onNudge});

  @override
  Widget build(BuildContext context) {
    final me = member.userId == AuthService.userId;
    final handle = (member.handle ?? 'ANON').toUpperCase();
    final moves = day.movesFor(member.userId);
    final done = moves >= SquadDay.movesPerMember;
    final missions = day.board.take(SquadDay.missionsPerDay).toList();
    final ranDaily = day.dailyFor(member.userId)?.finished ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 22),
        Text('${me ? 'YOUR' : '$handle’S'} TODAY',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 5),
        Text('$moves OF ${SquadDay.movesPerMember} MOVES',
            style: GoogleFonts.inter(
              color: done ? kNeon : AppColors.red,
              fontSize: 9.5,
              letterSpacing: 2.6,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 20),

        for (final m in missions)
          _Line(
            label: m.title,
            done: day.squadStates[m.id]?.completed.contains(member.userId) ??
                false,
          ),
        _Line(label: 'The daily Rizz-Off', done: ranDaily),

        const SizedBox(height: 20),
        if (!me && !done)
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                Feel.banked();
                onNudge();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.45),
                        blurRadius: 24)
                  ],
                ),
                child: Text('NUDGE $handle',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
          )
        else if (done)
          Text(me ? 'All five. Done.' : '$handle is done for today.',
              style: GoogleFonts.inter(
                color: kNeon,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        const SizedBox(height: 6),
        if (!me && !done)
          Text('The whole squad sees it.',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final bool done;
  const _Line({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        // circle_outlined isn't proven anywhere else in this repo and
        // the SDK isn't here to check against — a filled dot at low
        // opacity reads the same and can't fail to compile.
        Icon(done ? Icons.check_circle_rounded : Icons.circle,
            size: done ? 17 : 11,
            color: done ? kNeon : AppColors.textMuted),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: done ? AppColors.textSecondary : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textMuted,
              )),
        ),
      ]),
    );
  }
}
