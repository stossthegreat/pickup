import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../services/backend/auth_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/academy_modal.dart';

/// THE SQUAD ROOM. Not a settings page — a room you walk into.
/// Week Grid (who did what, what day) · Call Your Shot · The Pulse ·
/// War Room (Discord) · invite card. Comms live in Discord; the truth
/// lives here.
class SquadRoomScreen extends StatefulWidget {
  const SquadRoomScreen({super.key});

  @override
  State<SquadRoomScreen> createState() => _SquadRoomScreenState();
}

class _SquadRoomScreenState extends State<SquadRoomScreen> {
  bool _loading = true;
  Squad? _squad;
  List<SquadMember> _roster = const [];
  List<WeekMark> _marks = const [];
  List<SquadEvent> _pulse = const [];
  Mission? _mission;
  String? _missionState; // null | committed | completed
  RealtimeChannel? _pulseChannel;
  RealtimeChannel? _rosterChannel;

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_pulseChannel != null) SquadService.unwatch(_pulseChannel!);
    if (_rosterChannel != null) SquadService.unwatch(_rosterChannel!);
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final squad = await SquadService.mySquad();
    if (!mounted) return;
    if (squad == null) {
      setState(() {
        _squad = null;
        _loading = false;
      });
      return;
    }
    final roster = await SquadService.roster(squad.id);
    final ids = [for (final m in roster) m.userId];
    final results = await Future.wait([
      SquadService.weekMarks(ids),
      SquadService.pulse(squad.id),
      MissionService.todayMission(),
    ]);
    final mission = results[2] as Mission?;
    final state =
        mission == null ? null : await MissionService.todayState(mission.id);
    if (!mounted) return;

    // Live wires — pulse + roster changes repaint the room instantly.
    _pulseChannel ??= SquadService.watchPulse(squad.id, _refreshSoft);
    _rosterChannel ??= SquadService.watchRoster(squad.id, _refreshSoft);

    setState(() {
      _squad = squad;
      _roster = roster;
      _marks = results[0] as List<WeekMark>;
      _pulse = results[1] as List<SquadEvent>;
      _mission = mission;
      _missionState = state;
      _loading = false;
    });
  }

  void _refreshSoft() {
    if (mounted) _load();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.mediumImpact();
    final squad = await SquadService.create(name);
    if (squad == null || !mounted) return;
    await SquadService.postEvent(squad.id, 'joined');
    _load();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) return;
    HapticFeedback.mediumImpact();
    final squad = await SquadService.joinByCode(code);
    if (!mounted) return;
    if (squad == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invalid code — check it with your squad.',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.toastBg,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await SquadService.postEvent(squad.id, 'joined');
    _load();
  }

  Future<void> _commit() async {
    final m = _mission;
    final s = _squad;
    if (m == null || s == null) return;
    HapticFeedback.heavyImpact();
    if (await MissionService.commit(m.id)) {
      await SquadService.postEvent(s.id, 'committed', {'mission': m.title});
      _load();
    }
  }

  Future<void> _complete() async {
    final m = _mission;
    final s = _squad;
    if (m == null || s == null) return;
    HapticFeedback.heavyImpact();
    if (await MissionService.complete(m.id)) {
      await SquadService.postEvent(s.id, 'completed', {'mission': m.title});
      if (!mounted) return;
      AcademyModal.show(
        context,
        kicker: 'MISSION COMPLETE',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.title,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Your square is filled. The squad saw it.',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            AcademyButton(
                label: 'BACK TO THE ROOM',
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
      _load();
    }
  }

  void _shareInvite() {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.selectionClick();
    Share.share('Join my squad "${s.name}" on ImHim Rizz. '
        'Code: ${s.inviteCode}');
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red)))
            : _squad == null
                ? _NoSquad(
                    nameCtrl: _nameCtrl,
                    codeCtrl: _codeCtrl,
                    onCreate: _create,
                    onJoin: _join,
                    onBack: () => context.pop(),
                  )
                : _room(),
      ),
    );
  }

  Widget _room() {
    final squad = _squad!;
    return RefreshIndicator(
      color: AppColors.red,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
            Expanded(
              child: Text(squad.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            GestureDetector(
              onTap: _shareInvite,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.5)),
                ),
                child: Text(squad.inviteCode,
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 12,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${_roster.length} OPERATIVES · TAP CODE TO RECRUIT',
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),

          // ── THE WEEK GRID ─────────────────────────────────────────
          _SectionLabel('THIS WEEK — WHO SHOWED UP'),
          const SizedBox(height: 10),
          _WeekGrid(roster: _roster, marks: _marks)
              .animate()
              .fadeIn(duration: 350.ms),
          const SizedBox(height: 22),

          // ── CALL YOUR SHOT ────────────────────────────────────────
          _SectionLabel("TODAY'S MISSION"),
          const SizedBox(height: 10),
          _MissionCard(
            mission: _mission,
            state: _missionState,
            onCommit: _commit,
            onComplete: _complete,
          ),
          const SizedBox(height: 22),

          // ── THE PULSE ─────────────────────────────────────────────
          _SectionLabel('THE PULSE'),
          const SizedBox(height: 10),
          if (_pulse.isEmpty)
            Text('Silence. Someone make a move.',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ))
          else
            for (final e in _pulse.take(12))
              _PulseRow(event: e, roster: _roster),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NO-SQUAD HERO — create or join
// ════════════════════════════════════════════════════════════════════

class _NoSquad extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onBack;
  const _NoSquad(
      {required this.nameCtrl,
      required this.codeCtrl,
      required this.onCreate,
      required this.onJoin,
      required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 18),
        Text('NOBODY\nCHANGES ALONE.',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 34,
              height: 1.05,
              letterSpacing: -1,
              fontWeight: FontWeight.w900,
            )).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 10),
        Text(
            'A squad sees your missions. Your streak. Your silence. '
            'That\'s the point.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            )).animate().fadeIn(delay: 120.ms, duration: 400.ms),
        const SizedBox(height: 32),
        _Field(controller: nameCtrl, hint: 'SQUAD NAME'),
        const SizedBox(height: 10),
        AcademyButton(label: 'FOUND A SQUAD', onTap: onCreate),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: Container(height: 1, color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                )),
          ),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ]),
        const SizedBox(height: 28),
        _Field(
            controller: codeCtrl,
            hint: 'INVITE CODE',
            caps: true,
            letterSpacing: 6),
        const SizedBox(height: 10),
        AcademyButton(label: 'ENTER WITH CODE', onTap: onJoin, ghost: true),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool caps;
  final double letterSpacing;
  const _Field(
      {required this.controller,
      required this.hint,
      this.caps = false,
      this.letterSpacing = 0.5});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.words,
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 15,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: AppColors.surface1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  WEEK GRID — rows = members · cols = Mon..Sun
// ════════════════════════════════════════════════════════════════════

class _WeekGrid extends StatelessWidget {
  final List<SquadMember> roster;
  final List<WeekMark> marks;
  const _WeekGrid({required this.roster, required this.marks});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1; // 0..6
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        // Day header
        Row(children: [
          const SizedBox(width: 86),
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Center(
                child: Text(_days[d],
                    style: GoogleFonts.inter(
                      color: d == today
                          ? AppColors.red
                          : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        for (final m in roster) ...[
          _memberRow(context, m, today),
          if (m != roster.last) const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Widget _memberRow(BuildContext context, SquadMember m, int today) {
    final mine = m.userId == AuthService.userId;
    return Row(children: [
      SizedBox(
        width: 86,
        child: Text(
          mine ? 'YOU' : (m.handle ?? 'ANON'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: mine ? AppColors.red : AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      for (var d = 0; d < 7; d++)
        Expanded(child: Center(child: _cell(context, m, d, today))),
    ]);
  }

  Widget _cell(BuildContext context, SquadMember m, int day, int today) {
    WeekMark? mark;
    for (final w in marks) {
      if (w.userId == m.userId && w.day.weekday - 1 == day) {
        // Completed beats committed if both exist that day.
        if (mark == null || (w.completed && !mark.completed)) mark = w;
      }
    }
    final future = day > today;
    final Widget dot;
    if (mark != null && mark.completed) {
      dot = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: AppColors.redGlow, blurRadius: 10)
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      );
    } else if (mark != null) {
      dot = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.red, width: 1.4),
        ),
      );
    } else {
      dot = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: future ? Colors.transparent : AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: future
              ? Border.all(color: Colors.white.withValues(alpha: 0.05))
              : null,
        ),
      );
    }
    final captured = mark;
    return GestureDetector(
      onTap: captured == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              AcademyModal.show(
                context,
                kicker: captured.completed ? 'COMPLETED' : 'COMMITTED',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(captured.missionTitle ?? 'Mission',
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${m.handle ?? 'ANON'} · '
                        '${captured.day.hour.toString().padLeft(2, '0')}:'
                        '${captured.day.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
      child: dot,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  MISSION CARD — call your shot / mark it done
// ════════════════════════════════════════════════════════════════════

class _MissionCard extends StatelessWidget {
  final Mission? mission;
  final String? state;
  final VoidCallback onCommit;
  final VoidCallback onComplete;
  const _MissionCard(
      {required this.mission,
      required this.state,
      required this.onCommit,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: state == 'committed'
                ? AppColors.red.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: m == null
          ? Text(
              'The mission engine is arming. First drop lands with the '
              'next update.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TIER ${m.tier}',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 9.5,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 6),
              Text(m.title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              Text(m.prompt,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 16),
              if (state == 'completed')
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF2EE87A)),
                  const SizedBox(width: 8),
                  Text('DONE. SQUARE FILLED.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2EE87A),
                        fontSize: 12,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      )),
                ])
              else if (state == 'committed')
                AcademyButton(label: 'MARK IT DONE', onTap: onComplete)
              else
                AcademyButton(label: 'CALL YOUR SHOT', onTap: onCommit),
              if (state == null) ...[
                const SizedBox(height: 8),
                Text('Committing posts it to the squad. No hiding after.',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PULSE ROW
// ════════════════════════════════════════════════════════════════════

class _PulseRow extends StatelessWidget {
  final SquadEvent event;
  final List<SquadMember> roster;
  const _PulseRow({required this.event, required this.roster});

  @override
  Widget build(BuildContext context) {
    String who = 'ANON';
    for (final m in roster) {
      if (m.userId == event.actorId) {
        who = m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');
      }
    }
    final (icon, text, color) = switch (event.kind) {
      'joined' => (Icons.bolt_rounded, '$who joined the squad',
          AppColors.textSecondary),
      'committed' => (
          Icons.radio_button_checked_rounded,
          '$who called their shot'
              '${event.payload['mission'] != null ? ' — ${event.payload['mission']}' : ''}',
          AppColors.red
        ),
      'completed' => (
          Icons.check_circle_rounded,
          '$who completed'
              '${event.payload['mission'] != null ? ' ${event.payload['mission']}' : ' the mission'}',
          const Color(0xFF2EE87A)
        ),
      'scored' => (
          Icons.graphic_eq_rounded,
          '$who scored ${event.payload['score'] ?? '—'}',
          AppColors.textPrimary
        ),
      'rankup' => (
          Icons.trending_up_rounded,
          '$who ranked up to ${event.payload['tier'] ?? ''}',
          const Color(0xFF2EE87A)
        ),
      _ => (Icons.circle, '$who did something', AppColors.textTertiary),
    };
    final t = event.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              )),
        ),
        Text(
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
          color: AppColors.textTertiary,
          fontSize: 10.5,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w800,
        ));
  }
}
