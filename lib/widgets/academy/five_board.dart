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
    // LEADER FIRST, because it's a table now and a table is read from
    // the top. The old strip sorted the laggard to the LEFT so he
    // couldn't be missed — right instinct, wrong shape: in a vertical
    // list last place is the bottom line, which is just as unmissable
    // and reads the way every league table anyone has ever seen does.
    // The Rizz-Off score breaks ties, so two men on 4/5 are separated by
    // the one thing that actually compares them.
    final sorted = [...roster]
      ..sort((a, b) {
        final byMoves =
            day.movesFor(b.userId).compareTo(day.movesFor(a.userId));
        if (byMoves != 0) return byMoves;
        final sa = day.dailyFor(a.userId)?.score ?? -1;
        final sb = day.dailyFor(b.userId)?.score ?? -1;
        return sb.compareTo(sa);
      });

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
      const SizedBox(height: 12),
      // ── ONE ROW PER MAN, READ TOP TO BOTTOM ─────────────────────────
      //
      // This was a horizontal strip of rings with "1/5" under each. It
      // told you the TOTAL and nothing else — you could see Anon was on
      // 0 and had no idea what he'd skipped, and the Rizz-Off score, the
      // one number that's actually comparable between two men, wasn't on
      // it at all.
      //
      // A ring is also the wrong shape for the job. Five circles in a
      // row is a set of gauges; ranking them means reading five numbers
      // and sorting in your head. A stack of rows is a league table —
      // top is winning, bottom is lacking, no work.
      //
      // Each row spends its width on the things that differ: four
      // mission pips, then the Rizz-Off with its score beside a cup,
      // then the total. Same five moves, laid out so you can see WHICH
      // ones are missing rather than just how many.
      for (final (i, m) in sorted.indexed)
        _ManRow(
          member: m,
          day: day,
          rank: i,
          onTap: () => _open(context, m),
        ).animate().fadeIn(delay: (60 * i).ms, duration: 280.ms),
      // Empty seats read as an invitation, not a gap.
      for (var i = 0; i < day.openSeats; i++) const _EmptySeat(),
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
/// ONE MAN, ONE LINE. Avatar, name, what he's done, what he scored.
///
/// The five moves are shown as five slots, not as a fraction — four
/// mission pips and the Rizz-Off. Which ones are empty is the useful
/// information: "Anon has done nothing" and "Anon has done everything
/// except the Rizz-Off" are completely different conversations, and the
/// old ring collapsed both to a number.
///
/// The Rizz-Off slot is deliberately the odd one out. Every other move
/// is pass/fail — a mission is done or it isn't — but the Rizz-Off is
/// the same woman for every man in the squad, so it's the one thing
/// here that can be SCORED against each other. It gets the cup and the
/// number; the rest get a tick.
class _ManRow extends StatelessWidget {
  final SquadMember member;
  final SquadDay day;

  /// Position in the table. Only the top man is crowned — a medal for
  /// third of three is a participation trophy and reads as one.
  final int rank;

  final VoidCallback onTap;

  const _ManRow({
    required this.member,
    required this.day,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final me = member.userId == AuthService.userId;
    final moves = day.movesFor(member.userId);
    final missionMoves = day.missionMovesFor(member.userId);
    final mark = day.dailyFor(member.userId);
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
        decoration: BoxDecoration(
          // HIS OWN ROW IS LIT. In a table of near-identical lines the
          // first job is finding yourself.
          color: me ? AppColors.surface2 : AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: me
                ? AppColors.red.withValues(alpha: 0.34)
                : AppColors.divider.withValues(alpha: 0.5),
            width: 0.9,
          ),
        ),
        child: Row(children: [
          // ── Who ──────────────────────────────────────────────────
          SizedBox(
            width: 38,
            height: 38,
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween(begin: 0, end: moves / SquadDay.movesPerMember),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(
                painter: _RingPainter(progress: v, tone: tone, mine: me),
                child: Center(
                  child: Text(initials,
                      style: GoogleFonts.inter(
                        color: me ? Colors.white : AppColors.textSecondary,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Row(children: [
              Flexible(
                // His real name, not YOU — the lit row and the red ring
                // already say which one is him, and a table where one
                // row speaks in the second person reads like the app
                // talking over the squad. Auto call-signs (see
                // AuthService._ensureHandle) mean this is never ANON.
                child: Text(handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: me ? Colors.white : AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              // Only the leader, and only once anyone has actually moved
              // — a crown on 0/5 at 6am is a joke at everyone's expense.
              if (rank == 0 && moves > 0) ...[
                const SizedBox(width: 4),
                const Icon(Icons.emoji_events_rounded,
                    size: 11, color: Color(0xFFFFC53D)),
              ],
            ]),
          ),
          const Spacer(),

          // ── The four missions ────────────────────────────────────
          for (var i = 0; i < SquadDay.missionsPerDay; i++) ...[
            _Pip(filled: i < missionMoves, tone: tone),
            const SizedBox(width: 5),
          ],

          // A rule, because the next slot is a different KIND of thing —
          // scored, not ticked.
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            color: AppColors.divider,
          ),

          // ── The Rizz-Off ─────────────────────────────────────────
          _Duel(mark: mark),

          const SizedBox(width: 10),
          SizedBox(
            width: 26,
            child: Text('$moves/${SquadDay.movesPerMember}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: done ? kNeon : AppColors.textTertiary,
                  fontSize: 11.5,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ]),
      ),
    );
  }
}

/// One mission move. A filled square, not a tick — at 9pt a tick is
/// mush, and the eye counts blocks faster than it reads glyphs.
class _Pip extends StatelessWidget {
  final bool filled;
  final Color tone;
  const _Pip({required this.filled, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: filled ? tone : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: filled ? tone : AppColors.surface3,
            width: 1.4,
          ),
          boxShadow: filled
              ? [BoxShadow(color: tone.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
      );
}

/// The Rizz-Off slot: a cup and his score, or a dash if he hasn't
/// played. The dash matters — an empty space would read as a rendering
/// gap rather than as the man not having shown up.
class _Duel extends StatelessWidget {
  final DailyMark? mark;
  const _Duel({required this.mark});

  static const _gold = Color(0xFFFFC53D);

  @override
  Widget build(BuildContext context) {
    final played = mark?.finished ?? false;
    final score = mark?.score;

    if (!played || score == null) {
      return SizedBox(
        width: 40,
        child: Text('—',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            )),
      );
    }

    return SizedBox(
      width: 40,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.emoji_events_rounded, size: 11, color: _gold),
        const SizedBox(width: 3),
        Text('$score',
            style: GoogleFonts.inter(
              color: _gold,
              fontSize: 13,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0x66FFC53D), blurRadius: 10),
              ],
            )),
      ]),
    );
  }
}

/// A seat nobody is in. Dashed and quiet — an invitation, not a gap.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surface3, width: 0.9),
        ),
        child: Row(children: [
          // group_add_rounded, proven in squad_room_screen. There is no
          // SDK here to check an icon constant against and a wrong one
          // is a red screen on his phone rather than a build warning.
          const Icon(Icons.group_add_rounded,
              size: 15, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text('EMPTY SEAT',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
        ]),
      );
}

// _Man — the old vertical ring-and-caption tile — is gone. It was the
// single-column form of the strip that the table replaced. The ring
// itself survives inside _ManRow, at 38pt rather than 54.

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
