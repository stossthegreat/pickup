import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/tactics.dart';
import '../../theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════════════
///  THE PLAYBOOK — a collection, never a curriculum
/// ══════════════════════════════════════════════════════════════════════
///
/// It is not called Learn and it is not called Lessons, and that is the
/// most important decision on this screen. A course section in a game
/// app is the thing everybody builds and nobody opens: it competes with
/// the fun and loses, and its existence makes the whole product feel
/// like homework.
///
/// So it's a cabinet. Sixteen mechanics, most of them locked, and the
/// only way to unlock one is to USE IT in a conversation. He isn't
/// studying, he's completing a set — the same reason the badges work.
///
/// ── LOCKED ONES SHOW THEIR NAME ──────────────────────────────────────
///
/// Not the content — the name and which axis it belongs to. A completely
/// hidden card teaches nothing and can't be aimed at; a fully visible
/// one removes the reason to go and earn it. The name alone is enough
/// for a man to think "what's THE REFRAME?" and go looking.
///
/// ── AND EVERY UNLOCKED ONE CARRIES HIS OWN LINE ──────────────────────
///
/// The sentence HE wrote that unlocked it, quoted underneath. That's the
/// whole teaching mechanism: you never forget a lesson you had already
/// passed before it was taught to you.
class TacticsScreen extends StatefulWidget {
  const TacticsScreen({super.key});

  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  Set<String> _found = const {};
  Map<String, String> _lines = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final f = await Tactics.discovered();
    final l = await Tactics.unlockLines();
    if (!mounted) return;
    setState(() {
      _found = f;
      _lines = l;
      _loading = false;
    });
  }

  Color _tone(Skill a) => switch (a) {
        Skill.confidence => AppColors.red,
        Skill.flow => AppColors.measure,
        Skill.wit => AppColors.signalAmber,
        Skill.recovery => AppColors.accent,
        Skill.close => const Color(0xFF2EE87A),
      };

  @override
  Widget build(BuildContext context) {
    final total = Tactics.all.length;
    final got = _found.length;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 16, 2),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
              Text('THE PLAYBOOK',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              Text('$got / $total',
                  style: GoogleFonts.inter(
                    color: AppColors.measure,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red)),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                        got == 0
                            ? 'Sixteen things that actually work. You don\'t '
                                'unlock them by reading — you unlock one the '
                                'moment you use it on someone.'
                            : 'You unlocked these by doing them. Every card '
                                'holds the line of yours that found it.',
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  for (final a in Skill.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(width: 3, height: 13, color: _tone(a)),
                        const SizedBox(width: 8),
                        Text(a.label,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11.5,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(a.means,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ]),
                    ),
                    for (final t in Tactics.forAxis(a))
                      _Card(
                        tactic: t,
                        tone: _tone(a),
                        found: _found.contains(t.id),
                        line: _lines[t.id],
                      ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

class _Card extends StatefulWidget {
  final Tactic tactic;
  final Color tone;
  final bool found;
  final String? line;
  const _Card({
    required this.tactic,
    required this.tone,
    required this.found,
    required this.line,
  });

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tactic;
    final found = widget.found;
    final tone = found ? widget.tone : AppColors.textMuted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _open = !_open);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: found ? AppColors.surface1 : AppColors.base,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: found
                  ? widget.tone.withValues(alpha: 0.32)
                  : AppColors.surface3),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(found ? Icons.check_circle_rounded : Icons.lock_rounded,
                size: 15, color: tone),
            const SizedBox(width: 9),
            Expanded(
              child: Text(t.name,
                  style: GoogleFonts.inter(
                    color: found ? Colors.white : AppColors.textTertiary,
                    fontSize: 13,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            // Proven-in-repo constants only — no SDK here to check a new
            // icon name against, and a wrong one is a red screen.
            Icon(
                _open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textMuted),
          ]),

          // LOCKED CARDS SAY WHAT TO DO, NOT WHAT IT IS. Enough to aim
          // at, not enough to make earning it pointless.
          if (!found && !_open) ...[
            const SizedBox(height: 6),
            Text('Use it in a conversation to discover this one.',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                )),
          ],

          if (_open || found) ...[
            const SizedBox(height: 9),
            Text(t.what,
                style: GoogleFonts.inter(
                  color: found ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                )),
          ],

          if (_open) ...[
            const SizedBox(height: 10),
            Text(t.why,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 12),
            _row('SAY SOMETHING LIKE', t.example, widget.tone),
            const SizedBox(height: 10),
            _row('INSTEAD OF', t.instead, AppColors.red),
            // HIS OWN SENTENCE. The whole reason this teaches rather
            // than informs — he reads a line he wrote.
            if (found && widget.line != null && widget.line!.length > 4) ...[
              const SizedBox(height: 12),
              _row('YOU UNLOCKED IT WITH', '"${widget.line}"', kNeonish),
            ],
          ],
        ]),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _row(String label, String body, Color tone) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 8.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 3),
          Text(body,
              style: GoogleFonts.inter(
                color: tone,
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              )),
        ],
      );
}

/// The green used for his own words. Named locally so this screen
/// doesn't reach into tiers.dart for one colour.
const kNeonish = Color(0xFF2EE87A);
