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
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/academy/academy_modal.dart';
import '../../widgets/academy/game_button.dart';

/// THE SQUAD ROOM. Not a settings page — a room you walk into. The
/// banner tells you who you are, the WEEK BOARD tells you who showed
/// up, the mission card asks you to call your shot in front of them,
/// and the pulse is the room talking. Comms live in Discord; the truth
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
      _snack('Invalid code — check it with your squad.');
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
      _celebrate(m.title);
      _load();
    }
  }

  /// Full-screen moment with confetti — a filled square is a real win.
  void _celebrate(String title) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.93),
      barrierDismissible: true,
      barrierLabel: 'done',
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, _, __) => Material(
        color: Colors.transparent,
        child: Stack(children: [
          const Positioned.fill(child: Burst(color: kNeon)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kNeon.withValues(alpha: 0.14),
                    border: Border.all(color: kNeon, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: kNeon.withValues(alpha: 0.45),
                          blurRadius: 44)
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 52, color: kNeon),
                ).animate().scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    duration: 520.ms,
                    curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text('SQUARE FILLED',
                    style: GoogleFonts.inter(
                      color: kNeon,
                      fontSize: 30,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w900,
                    )).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 10),
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 4),
                Text('The squad saw it.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )).animate().fadeIn(delay: 430.ms),
                const SizedBox(height: 28),
                SizedBox(
                  width: 230,
                  child: GameButton(
                    label: 'BACK TO THE ROOM',
                    color: kNeon,
                    textColor: Colors.black,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ).animate().fadeIn(delay: 540.ms),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _shareInvite() {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.selectionClick();
    Share.share('Join my squad "${s.name}" on ImHim Rizz. '
        'Code: ${s.inviteCode}');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
    ));
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
    final done = _marks.where((m) => m.completed).length;
    final possible = _roster.length * 7;
    return RefreshIndicator(
      color: AppColors.red,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
        children: [
          Row(children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              onPressed: _shareInvite,
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  size: 20, color: AppColors.red),
            ),
          ]),

          // ── BANNER — who you are ──────────────────────────────────
          _banner(squad, done, possible),
          const SizedBox(height: 20),

          // ── THE WEEK BOARD ────────────────────────────────────────
          _label('THE WEEK BOARD', 'Who showed up.'),
          const SizedBox(height: 12),
          _WeekBoard(roster: _roster, marks: _marks),
          const SizedBox(height: 22),

          // ── CALL YOUR SHOT ────────────────────────────────────────
          _label("TODAY'S MISSION", 'Call it in front of them.'),
          const SizedBox(height: 12),
          _MissionCard(
            mission: _mission,
            state: _missionState,
            onCommit: _commit,
            onComplete: _complete,
          ),
          const SizedBox(height: 22),

          // ── THE PULSE ─────────────────────────────────────────────
          _label('THE PULSE', 'The room, live.'),
          const SizedBox(height: 12),
          if (_pulse.isEmpty)
            Text('Silence. Someone make a move.',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ))
          else
            for (final (i, e) in _pulse.take(14).indexed)
              _PulseRow(
                event: e,
                roster: _roster,
                first: i == 0,
                last: i == _pulse.take(14).length - 1,
              ),
        ],
      ),
    );
  }

  /// Squad banner — emblem, name, member faces, the code chip and the
  /// week's progress bar. The identity object of the whole feature.
  Widget _banner(Squad squad, int done, int possible) {
    final pct = possible == 0 ? 0.0 : done / possible;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.red.withValues(alpha: 0.24),
            AppColors.surface1,
            AppColors.surface1,
          ],
        ),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
        boxShadow: const [BoxShadow(color: AppColors.redGlow, blurRadius: 30)],
      ),
      child: Column(children: [
        Row(children: [
          // Emblem — the squad initial struck into a disc.
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B70), AppColors.red, Color(0xFF7E0E12)],
              ),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.28), width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.5),
                    blurRadius: 26)
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              squad.name.characters.first.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8)
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(squad.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.05,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 4),
                Text('${_roster.length} OPERATIVES',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Week progress — the squad's shared number.
        Row(children: [
          Text('$done',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
              )),
          Text(' / $possible SQUARES',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              )),
          const Spacer(),
          Text('${done * 100} PTS',
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation(AppColors.red),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Invite code — big, tappable, the growth loop.
        GestureDetector(
          onTap: _shareInvite,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.45)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.ios_share_rounded,
                  size: 15, color: AppColors.red),
              const SizedBox(width: 10),
              Text(squad.inviteCode,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 19,
                    letterSpacing: 7,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }

  Widget _label(String title, String sub) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(title, style: AppTypography.labelBold.copyWith(fontSize: 10.5)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(sub,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            )),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  NO SQUAD — the recruiting hero
// ══════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
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
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.red.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.6), width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.redGlow, blurRadius: 34)
              ],
            ),
            child: const Icon(Icons.shield_rounded,
                size: 42, color: AppColors.red),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.05, duration: 1600.ms),
        ),
        const SizedBox(height: 24),
        Text('THE SQUAD', textAlign: TextAlign.center,
            style: AppTypography.label).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Text('Nobody changes alone.',
            textAlign: TextAlign.center,
            style: AppTypography.h1Italic)
            .animate()
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        Text(
            'Five men, one week. They see your missions, your streak — '
            'and your silence. That\'s the point.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall)
            .animate()
            .fadeIn(delay: 120.ms, duration: 400.ms),
        const SizedBox(height: 30),
        _Field(controller: nameCtrl, hint: 'SQUAD NAME'),
        const SizedBox(height: 12),
        GameButton(label: 'FOUND A SQUAD', onTap: onCreate, pulse: true),
        const SizedBox(height: 26),
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
        const SizedBox(height: 26),
        _Field(
            controller: codeCtrl,
            hint: 'INVITE CODE',
            caps: true,
            letterSpacing: 6),
        const SizedBox(height: 12),
        GameButton(
            label: 'ENTER WITH CODE',
            color: AppColors.surface2,
            onTap: onJoin),
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
      textAlign: caps ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 16,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w800,
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.red, width: 1.6),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE WEEK BOARD — faces down the side, seven tiles across
// ══════════════════════════════════════════════════════════════════════

class _WeekBoard extends StatelessWidget {
  final List<SquadMember> roster;
  final List<WeekMark> marks;
  const _WeekBoard({required this.roster, required this.marks});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 104),
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: d == today
                        ? AppColors.red.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_days[d],
                      style: GoogleFonts.inter(
                        color:
                            d == today ? AppColors.red : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      )),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        for (final m in roster) ...[
          _row(context, m, today),
          if (m != roster.last)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Container(height: 1, color: AppColors.divider),
            ),
        ],
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }

  Widget _row(BuildContext context, SquadMember m, int today) {
    final mine = m.userId == AuthService.userId;
    final weekDone = marks
        .where((w) => w.userId == m.userId && w.completed)
        .length;
    return Row(children: [
      SizedBox(
        width: 104,
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface2,
              border: Border.all(
                  color: mine ? AppColors.red : Colors.white24, width: 1.6),
            ),
            alignment: Alignment.center,
            child: Text(
              (mine ? 'YOU' : (m.handle ?? 'A')).characters.first.toUpperCase(),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mine ? 'YOU' : (m.handle ?? 'ANON'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: mine ? AppColors.red : AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    )),
                Text('$weekDone/7',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ]),
      ),
      for (var d = 0; d < 7; d++)
        Expanded(child: Center(child: _tile(context, m, d, today))),
    ]);
  }

  Widget _tile(BuildContext context, SquadMember m, int day, int today) {
    WeekMark? mark;
    for (final w in marks) {
      if (w.userId == m.userId && w.day.weekday - 1 == day) {
        if (mark == null || (w.completed && !mark.completed)) mark = w;
      }
    }
    final future = day > today;
    final captured = mark;

    Widget tile;
    if (captured != null && captured.completed) {
      tile = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B70), AppColors.red],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withValues(alpha: 0.55), blurRadius: 12)
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    } else if (captured != null) {
      tile = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.red, width: 1.8),
        ),
      );
    } else {
      tile = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: future ? Colors.transparent : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: future
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
      );
    }

    if (captured == null) return tile;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        AcademyModal.show(
          context,
          kicker: captured.completed ? 'COMPLETED' : 'COMMITTED',
          accent: captured.completed ? kNeon : AppColors.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(captured.missionTitle ?? 'Mission',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
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
      child: tile,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  MISSION CARD
// ══════════════════════════════════════════════════════════════════════

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
    final committed = state == 'committed';
    final completed = state == 'completed';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: completed
                ? kNeon.withValues(alpha: 0.5)
                : committed
                    ? AppColors.red.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.06)),
        boxShadow: committed
            ? const [BoxShadow(color: AppColors.redGlow, blurRadius: 22)]
            : null,
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
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.5)),
                  ),
                  child: Text('TIER ${m.tier}',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      )),
                ),
                const Spacer(),
                if (completed)
                  const Icon(Icons.check_circle_rounded,
                      size: 20, color: kNeon),
              ]),
              const SizedBox(height: 12),
              Text(m.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.1,
                    letterSpacing: -0.4,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 8),
              Text(m.prompt,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 18),
              if (completed)
                Row(children: [
                  Text('DONE. SQUARE FILLED.',
                      style: GoogleFonts.inter(
                        color: kNeon,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      )),
                ])
              else if (committed) ...[
                GameButton(label: 'MARK IT DONE', onTap: onComplete),
                const SizedBox(height: 8),
                Text('You called it. They\'re watching for the check.',
                    style: GoogleFonts.inter(
                      color: AppColors.red,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    )),
              ] else ...[
                GameButton(
                    label: 'CALL YOUR SHOT', onTap: onCommit, pulse: true),
                const SizedBox(height: 8),
                Text('Committing posts it to the squad. No hiding after.',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ]),
    ).animate().fadeIn(duration: 340.ms);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  PULSE — a timeline, not a list
// ══════════════════════════════════════════════════════════════════════

class _PulseRow extends StatelessWidget {
  final SquadEvent event;
  final List<SquadMember> roster;
  final bool first, last;
  const _PulseRow(
      {required this.event,
      required this.roster,
      required this.first,
      required this.last});

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
          kNeon
        ),
      'scored' => (
          Icons.graphic_eq_rounded,
          '$who scored ${event.payload['score'] ?? '—'}',
          Colors.white
        ),
      'rankup' => (
          Icons.trending_up_rounded,
          '$who ranked up to ${event.payload['tier'] ?? ''}',
          kNeon
        ),
      _ => (Icons.circle, '$who made a move', AppColors.textTertiary),
    };
    final t = event.createdAt;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Timeline spine
        SizedBox(
          width: 26,
          child: Column(children: [
            Container(
                width: 1.5,
                height: 6,
                color: first ? Colors.transparent : AppColors.divider),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Icon(icon, size: 11, color: color),
            ),
            Expanded(
              child: Container(
                  width: 1.5,
                  color: last ? Colors.transparent : AppColors.divider),
            ),
          ]),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
