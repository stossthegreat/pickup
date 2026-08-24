import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lucien_mirror.dart';
import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE MIRROR CARD — Lucien, in the room, after the line is gone
/// ══════════════════════════════════════════════════════════════════════
///
/// This is the teaching moment and it has one job: land like a brick and
/// then get out of the way. It sits INLINE in the conversation, under
/// the message it is about, because a full-screen takeover mid-chat
/// would be the app interrupting the exact thing it is trying to train.
///
/// ── THE SHAPE IS THE ARGUMENT ───────────────────────────────────────
///
///   his line, quoted small and grey   — the evidence, his own words
///   ↓
///   the read                          — one sentence, what it did
///   ↓
///   THE MOVE, named                   — the weapon has a name
///   ↓
///   two lines he could have said      — in gold, unmissable
///
/// The order matters. Diagnosis before prescription, evidence before
/// diagnosis. Show him the weapon first and he has no reason to want it.
///
/// ── GOLD, DELIBERATELY ──────────────────────────────────────────────
///
/// Red is the streak's. Blue is the tactic reveal's. Lucien speaks in
/// gold because he is the rarest voice in the app and the only one that
/// is a person rather than a system.
class MirrorCard extends StatelessWidget {
  final LucienMirror mirror;

  /// Fires when he taps the silence toggle inside the card.
  final VoidCallback onSilence;

  /// True the first time a mirror has ever appeared — shows the one-off
  /// line telling him he can shut Lucien up. Shown ONCE, ever: an app
  /// that keeps explaining its own controls does not trust its user.
  final bool showHint;

  const MirrorCard({
    super.key,
    required this.mirror,
    required this.onSilence,
    this.showHint = false,
  });

  static const _gold = Color(0xFFFFC53D);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                _gold.withValues(alpha: 0.09), AppColors.surface2),
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.42), width: 1.1),
        boxShadow: [
          BoxShadow(
              color: _gold.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -6),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Who's talking ────────────────────────────────────────────
        Row(children: [
          Container(
            width: 26,
            height: 26,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.7)),
            ),
            child: Image.asset(
              'assets/characters/lucien/lucien.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: _gold.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(width: 9),
          Text('LUCIEN',
              style: GoogleFonts.inter(
                color: _gold,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          // THE OFF SWITCH, AND IT LOOKS LIKE ONE.
          //
          // This was a bare 15pt speaker glyph and nobody could see it,
          // which made an uninvited coach feel like something you were
          // stuck with. A labelled pill with a border reads as a
          // control at a glance — the word MUTE is doing the work the
          // icon alone could never do.
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onSilence();
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.textMuted.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.volume_off_rounded,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('MUTE',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      )),
                ]),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 11),

        // ── His own words, as evidence ───────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                  color: AppColors.textMuted.withValues(alpha: 0.55),
                  width: 2.5),
            ),
          ),
          child: Text(_quoted(mirror.hisLine),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              )),
        ),

        const SizedBox(height: 10),
        Text(mirror.read,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            )),

        const SizedBox(height: 14),

        // ── THE MOVE ─────────────────────────────────────────────────
        Row(children: [
          Container(width: 3, height: 15, color: _gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(mirror.move,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ]),
        if (mirror.why.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(mirror.why,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              )),
        ],

        const SizedBox(height: 12),
        Text('SAY THIS INSTEAD',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 8.5,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 7),
        for (var i = 0; i < mirror.lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _line(mirror.lines[i]),
        ],

        // ── The one-off "you can shut me up" ─────────────────────────
        if (showHint) ...[
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.volume_off_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'I\'ll speak up when I see something worth saying. '
                    'Hit MUTE any time and I\'m gone.',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ]),
          ),
        ],
      ]),
    )
        .animate()
        .fadeIn(duration: 260.ms)
        .slideY(begin: 0.14, end: 0, curve: Curves.easeOutCubic);
  }

  /// One pair of quotes, wherever the line came from.
  static String _quoted(String s) {
    final t = s.trim();
    final bare = t.replaceAll(RegExp(r'^[""\u201C\u201D]+|[""\u201C\u201D]+$'), '');
    return '"$bare"';
  }

  Widget _line(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border(
            left: BorderSide(color: _gold, width: 2.5),
          ),
        ),
        // The line as Lucien wrote it. NOT re-quoted — he returns bare
        // text, and the old tactic examples carried their own quote
        // marks, which is where the ""double quoted"" cards came from.
        child: Text(_quoted(text),
            style: GoogleFonts.inter(
              color: _gold,
              fontSize: 13,
              height: 1.42,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            )),
      );
}
