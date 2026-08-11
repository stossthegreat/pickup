import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../services/backend/auth_service.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_broadcast.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_live_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/live_events.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/academy/academy_modal.dart';
import '../../widgets/academy/day_beat.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/squad_grade.dart';
import '../../widgets/academy/squad_gauge.dart';
import '../../widgets/academy/today_board.dart';
import '../../widgets/academy/your_five.dart';

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
  List<Mission> _board = const [];
  Map<String, String> _myStates = const {}; // missionId → committed|completed
  Map<String, MissionPulse> _squadStates = const {};
  List<DailyMark> _daily = const [];
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
      MissionService.todayBoard(count: SquadDay.missionsPerDay),
      SquadService.missionPulseToday(ids),
      SquadService.dailyToday(ids, squadId: squad.id),
    ]);
    final board = results[2] as List<Mission>;
    final myStates =
        await MissionService.myStatesToday([for (final m in board) m.id]);
    if (!mounted) return;

    _pulseChannel ??= SquadService.watchPulse(squad.id, _refreshSoft);
    _rosterChannel ??= SquadService.watchRoster(squad.id, _refreshSoft);

    setState(() {
      _squad = squad;
      _roster = roster;
      _marks = results[0] as List<WeekMark>;
      _pulse = results[1] as List<SquadEvent>;
      _board = board;
      _squadStates = results[3] as Map<String, MissionPulse>;
      _daily = results[4] as List<DailyMark>;
      _myStates = myStates;
      _loading = false;
    });
  }

  /// The single source of truth for every number on this screen.
  SquadDay get _day => SquadDay(
        roster: _roster,
        board: _board,
        squadStates: _squadStates,
        daily: _daily,
      );

  bool _wonShown = false;

  /// The gauge closing is the day's big moment — full-screen, heavy
  /// haptic, once per day.
  void _dayWon() {
    if (_wonShown || !mounted) return;
    _wonShown = true;
    HapticFeedback.heavyImpact();
    _celebrate('DAY WON');
  }

  /// A nudge is a squad-visible poke, not a private DM — the point is
  /// that the room sees you were called out.
  Future<void> _nudge(SquadMember m) async {
    final s = _squad;
    if (s == null) return;
    await SquadService.postEvent(s.id, 'nudge', {
      'target': m.userId,
      'handle': m.handle ?? 'ANON',
    });
    if (!mounted) return;
    _snack('Nudged ${m.handle ?? 'them'}. The room saw it.');
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
    SquadBroadcast.invalidate();
    // ignore: discarded_futures
    SquadLiveService.start();
    LiveEvents.milestone('SQUAD FOUNDED', squad.name);
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
    SquadBroadcast.invalidate();
    // ignore: discarded_futures
    SquadLiveService.start();
    LiveEvents.milestone('YOU\'RE IN', squad.name);
    _load();
  }

  Future<void> _commit(Mission m) async {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.heavyImpact();
    if (await MissionService.commit(m.id)) {
      await SquadService.postEvent(s.id, 'committed', {'mission': m.title});
      LiveEvents.fire(const LiveEvent(
        title: 'Shot called',
        subtitle: 'Your squad can see it now.',
        icon: Icons.campaign_rounded,
        color: AppColors.red,
      ));
      _load();
    }
  }

  Future<void> _complete(Mission m) async {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.heavyImpact();
    if (await MissionService.complete(m.id)) {
      await SquadService.postEvent(s.id, 'completed', {'mission': m.title});
      LiveEvents.xp(100, 'Mission complete');
      if (!mounted) return;
      _celebrate(m.title);
      _load();
    }
  }

  /// Leaving is destructive and irreversible without the code, so it
  /// asks first and says plainly what is lost.
  Future<void> _confirmLeave() async {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.selectionClick();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('Leave ${s.name}?',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(
            'You drop off their board and lose the squad grade you built '
            'together. You can rejoin with the code ${s.inviteCode}.',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('STAY',
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('LEAVE',
                style: GoogleFonts.inter(
                    color: AppColors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await SquadService.leave(s.id);
    SquadBroadcast.invalidate();
    if (!mounted) return;
    _snack('You left ${s.name}.');
    _load();
  }

  /// Tap the code = it's on the clipboard. Sharing is a second, separate
  /// action — most invites get read out or pasted into a group chat, and
  /// a share sheet is the wrong tool for both.
  void _copyCode() {
    final s = _squad;
    if (s == null) return;
    HapticFeedback.mediumImpact();
    // ignore: discarded_futures
    Clipboard.setData(ClipboardData(text: s.inviteCode));
    _snack('Code ${s.inviteCode} copied — send it to your boys.');
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
    Share.share(
        'Get in my squad on ImHim Rizz.\n\n'
        'Squad: ${s.name}\n'
        'Code: ${s.inviteCode}\n\n'
        'Open the app → Squad → type the code. Five missions a day, '
        'one voice rizz-off, and we both see who actually did them.');
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
            // LEAVE. SquadService.leave() existed from day one but
            // nothing ever called it — you could join a squad and had
            // no way out, which is both a trap and an App Review
            // problem for anything social.
            IconButton(
              onPressed: _confirmLeave,
              icon: const Icon(Icons.logout_rounded,
                  size: 19, color: AppColors.textTertiary),
            ),
          ]),

          // ── THE GAUGE — one hero instrument, top third ────────────
          // Replaces the old banner-of-stats. Five segments, one per
          // seat, each filling with that man's five moves. The team's
          // whole day, readable without a legend.
          SquadGauge(
            day: _day,
            squadName: squad.name,
            onWin: _dayWon,
          ),
          const SizedBox(height: 14),

          // ── THE BEAT — the day's clock, right under the dial ──────
          DayBeat(day: _day),
          const SizedBox(height: 20),

          // ── YOUR FIVE — portraits, arcs, empty seats ──────────────
          Row(children: [
            Text('YOUR FIVE',
                style: AppTypography.labelBold.copyWith(fontSize: 10.5)),
            const SizedBox(width: 8),
            Text('${_roster.length}/${SquadDay.maxMembers}',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                )),
            const Spacer(),
            if (_day.openSeats > 0)
              Text(
                  _day.openSeats == 1
                      ? 'ONE SEAT OPEN'
                      : '${_day.openSeats} SEATS OPEN',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  )),
          ]),
          const SizedBox(height: 12),
          YourFive(
            day: _day,
            onRecruit: _shareInvite,
            onNudge: _nudge,
          ),
          const SizedBox(height: 14),

          // The code sits right under the seats — the moment you notice
          // an empty one is the moment you want the invite.
          _codeStrip(squad),
          const SizedBox(height: 22),

          if (!_day.live) ...[
            _needTwo(),
            const SizedBox(height: 22),
          ],

          // ── TODAY'S BOARD — the whole day, one grid ───────────────
          // This is the screen's answer to "what has everyone actually
          // done?". It goes FIRST because it's the question you open the
          // room to ask. Rows are men, columns are the five missions,
          // last column is the scored voice run.
          _label("TODAY'S BOARD", 'Everyone, everything, one look.'),
          const SizedBox(height: 12),
          TodayBoard(
            roster: _roster,
            board: _board,
            squadStates: _squadStates,
            daily: _daily,
          ),
          const SizedBox(height: 22),

          // ── THE AI RUN — did they get to the end? ─────────────────
          _label("TODAY'S VOICE RUN", 'Who went the distance.'),
          const SizedBox(height: 12),
          _DailyRunCard(roster: _roster, marks: _daily),
          const SizedBox(height: 22),

          // ── CALL YOUR SHOT — the whole slate ──────────────────────
          // Numbered 1..5 to match the board's columns above, so the
          // grid and the cards are obviously the same five things.
          _label("THE FIVE", 'Same five for everyone today.'),
          const SizedBox(height: 12),
          if (_board.isEmpty)
            const _EmptyBoard()
          else
            for (final (i, m) in _board.indexed) ...[
              _MissionCard(
                mission: m,
                state: _myStates[m.id],
                pulse: _squadStates[m.id],
                squadSize: _roster.length,
                roster: _roster,
                index: i,
                onCommit: () => _commit(m),
                onComplete: () => _complete(m),
              ),
              if (m != _board.last) const SizedBox(height: 10),
            ],
          const SizedBox(height: 22),

          // ── THE RATING — who's carrying, who's hiding ─────────────
          _label('SQUAD REPORT', 'Graded every week.'),
          const SizedBox(height: 12),
          SquadReport(roster: _roster, marks: _marks),
          const SizedBox(height: 22),

          // ── THE WEEK BOARD ────────────────────────────────────────
          _label('THE WEEK', 'Seven days, who showed up.'),
          const SizedBox(height: 12),
          _WeekBoard(roster: _roster, marks: _marks),
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

  /// The invite, sitting directly under the empty seats.
  Widget _codeStrip(Squad squad) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _copyCode,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SQUAD CODE — TAP TO COPY',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 8.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text(squad.inviteCode,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.1,
                      letterSpacing: 7,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ),
        _CodeAction(
            icon: Icons.copy_rounded, label: 'COPY', onTap: _copyCode),
        const SizedBox(width: 6),
        _CodeAction(
            icon: Icons.ios_share_rounded, label: 'SEND', onTap: _shareInvite),
      ]),
    );
  }

  /// Below the minimum the day can't be scored — one man ticking his own
  /// boxes isn't accountability. Said plainly, without calling the squad
  /// broken.
  Widget _needTwo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.group_add_rounded, size: 18, color: AppColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              'One more man and the day starts scoring. Two is enough — '
              'you don\'t need five.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
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
              fontWeight: FontWeight.w600,
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
        Text('NOBODY CHANGES ALONE.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 30,
              height: 1.05,
              letterSpacing: -1,
              fontWeight: FontWeight.w900,
            ))
            .animate()
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        Text(
            'You do the reps whether anyone watches or not. You just do '
            'more of them when they do. Two men is enough — five is the '
            'most.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall)
            .animate()
            .fadeIn(delay: 120.ms, duration: 400.ms),
        const SizedBox(height: 26),

        // HOW IT WORKS — three lines. The invite-code system was never
        // explained anywhere, so "how does anyone actually join?" was a
        // fair question with no answer on screen.
        _How(n: '1', text: 'Found a squad — you get a 6-letter code'),
        _How(n: '2', text: 'Send the code to your mate'),
        _How(n: '3', text: 'He types it in below — that\'s it, you\'re a squad'),

        const SizedBox(height: 26),
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
        Text('GOT A CODE FROM A MATE?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 12),
        _Field(
            controller: codeCtrl,
            hint: 'ABC123',
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
//  CODE ACTIONS
// ══════════════════════════════════════════════════════════════════════

class _CodeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CodeAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: AppColors.red),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 8,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE AI RUN — the voice Daily, seen by the squad
// ══════════════════════════════════════════════════════════════════════

/// A real-life mission is binary. The AI run isn't — the interesting
/// number is how many opened it versus how many stayed in it to the
/// end, because bailing at line two is the exact thing the squad is
/// meant to make expensive.
class _DailyRunCard extends StatelessWidget {
  final List<SquadMember> roster;
  final List<DailyMark> marks;
  const _DailyRunCard({required this.roster, required this.marks});

  @override
  Widget build(BuildContext context) {
    final finished = marks.where((m) => m.finished).toList();
    final bailed = marks.where((m) => !m.finished).toList();
    final untouched = roster.length - marks.length;
    final best = finished.isEmpty
        ? null
        : finished.reduce((a, b) => (a.score ?? 0) >= (b.score ?? 0) ? a : b);

    String nameOf(String userId) {
      for (final m in roster) {
        if (m.userId == userId) {
          return m.userId == AuthService.userId ? 'YOU' : (m.handle ?? 'ANON');
        }
      }
      return 'ANON';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kNeon.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.graphic_eq_rounded, size: 16, color: kNeon),
          const SizedBox(width: 8),
          Text('VOICE RIZZ-OFF',
              style: GoogleFonts.inter(
                color: kNeon,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              )),
          const Spacer(),
          Text('${finished.length}/${roster.length} FINISHED',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 12),
        // Three states, one row: went the distance / walked / no-show.
        Row(children: [
          for (final f in finished) ...[
            _RunPip(
                label: nameOf(f.userId),
                value: '${f.score ?? 0}',
                color: kNeon,
                icon: Icons.check_rounded),
            const SizedBox(width: 8),
          ],
          for (final b in bailed) ...[
            _RunPip(
                label: nameOf(b.userId),
                value: 'BAILED',
                color: AppColors.red,
                icon: Icons.close_rounded),
            const SizedBox(width: 8),
          ],
          if (untouched > 0)
            _RunPip(
                label: '$untouched',
                value: 'NO-SHOW',
                color: AppColors.textMuted,
                icon: Icons.remove_rounded),
        ]),
        if (best != null) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.emoji_events_rounded, size: 14, color: kNeon),
            const SizedBox(width: 8),
            Text('${nameOf(best.userId)} leads the squad — ${best.score}',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                )),
          ]),
        ],
        if (marks.isEmpty) ...[
          const SizedBox(height: 4),
          Text('Nobody has taken today\'s run. Be the first name on it.',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              )),
        ],
      ]),
    ).animate().fadeIn(duration: 340.ms);
  }
}

class _RunPip extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _RunPip(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.6),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: 48,
        child: Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            )),
      ),
      Text(value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  MISSION CARD — one of five, with the squad's count on it
// ══════════════════════════════════════════════════════════════════════

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
          'Board clear — you\'ve run every mission in the catalog. The '
          'next tier drops with the update.',
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

class _MissionCard extends StatefulWidget {
  final Mission mission;
  final String? state;
  final MissionPulse? pulse;
  final int squadSize;
  final List<SquadMember> roster;
  final int index;
  final VoidCallback onCommit;
  final VoidCallback onComplete;
  const _MissionCard({
    required this.mission,
    required this.state,
    required this.pulse,
    required this.squadSize,
    required this.roster,
    required this.index,
    required this.onCommit,
    required this.onComplete,
  });

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  /// Five open cards would be a wall of text. Collapsed by default, and
  /// whatever you've already committed to opens itself.
  late bool _open = widget.state != null;

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    final committed = widget.state == 'committed';
    final completed = widget.state == 'completed';
    final doneCount = widget.pulse?.completed.length ?? 0;
    final onIt = widget.pulse?.committed.length ?? 0;
    final accent = completed
        ? kNeon
        : committed
            ? AppColors.red
            : AppColors.textTertiary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: completed
                ? kNeon.withValues(alpha: 0.5)
                : committed
                    ? AppColors.red.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.06)),
        boxShadow: committed
            ? const [BoxShadow(color: AppColors.redGlow, blurRadius: 18)]
            : null,
      ),
      child: Column(children: [
        // ── Header row — always visible, tap to open ──────────────
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _open = !_open);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(children: [
              // Tier disc doubles as the completed check.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.7), width: 1.5),
                ),
                alignment: Alignment.center,
                child: completed
                    ? const Icon(Icons.check_rounded, size: 16, color: kNeon)
                    // The card's number is its COLUMN on today's board,
                    // not its ladder tier — the two were being confused.
                    : Text('${widget.index + 1}',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        )),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.15,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 3),
                    // THE SQUAD NUMBER — the whole point of five cards.
                    Row(children: [
                      Text('$doneCount/${widget.squadSize} SQUAD DONE',
                          style: GoogleFonts.inter(
                            color: doneCount > 0
                                ? kNeon
                                : AppColors.textMuted,
                            fontSize: 9.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w900,
                          )),
                      if (onIt > 0) ...[
                        const SizedBox(width: 8),
                        Text('· $onIt ON IT',
                            style: GoogleFonts.inter(
                              color: AppColors.red,
                              fontSize: 9.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w900,
                            )),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SquadDots(
                  roster: widget.roster,
                  pulse: widget.pulse,
                  size: widget.squadSize),
              const SizedBox(width: 6),
              Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textTertiary),
            ]),
          ),
        ),

        // ── Body — the brief and the action ───────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                Text(m.prompt,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 14),
                if (completed)
                  Text('DONE. SQUARE FILLED.',
                      style: GoogleFonts.inter(
                        color: kNeon,
                        fontSize: 11.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ))
                else if (committed) ...[
                  GameButton(
                      label: 'MARK IT DONE',
                      height: 50,
                      onTap: widget.onComplete),
                  const SizedBox(height: 7),
                  Text('You called it. They\'re watching for the check.',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      )),
                ] else ...[
                  GameButton(
                    label: 'CALL YOUR SHOT',
                    height: 50,
                    onTap: widget.onCommit,
                    pulse: widget.index == 0,
                  ),
                  const SizedBox(height: 7),
                  Text('Committing posts it to the squad. No hiding after.',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ],
            ),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
        ),
      ]),
    )
        .animate()
        .fadeIn(delay: (widget.index * 60).ms, duration: 300.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
  }
}

/// One dot per squadmate: filled = done, ringed = on it, hollow = not
/// yet. Reads at a glance without a single word.
class _SquadDots extends StatelessWidget {
  final List<SquadMember> roster;
  final MissionPulse? pulse;
  final int size;
  const _SquadDots(
      {required this.roster, required this.pulse, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in roster.take(6))
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Builder(builder: (_) {
            final done = pulse?.completed.contains(m.userId) ?? false;
            final on = pulse?.committed.contains(m.userId) ?? false;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? kNeon : Colors.transparent,
                border: Border.all(
                  color: done
                      ? kNeon
                      : on
                          ? AppColors.red
                          : Colors.white.withValues(alpha: 0.18),
                  width: 1.6,
                ),
                boxShadow: done
                    ? [
                        BoxShadow(
                            color: kNeon.withValues(alpha: 0.6),
                            blurRadius: 7)
                      ]
                    : null,
              ),
            );
          }),
        ),
    ]);
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
      'started' => (
          Icons.play_circle_fill_rounded,
          '$who started ${event.payload['mission'] ?? 'a mission'}',
          AppColors.accent
        ),
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
      // A nudge is public on purpose — being called out in front of the
      // room is the whole point, so it reads as an event, not a DM.
      'nudge' => (
          Icons.campaign_rounded,
          '$who nudged ${event.payload['handle'] ?? 'someone'}',
          AppColors.signalAmber
        ),
      'daily_started' => (
          Icons.graphic_eq_rounded,
          '$who stepped into the rizz-off',
          AppColors.red
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

/// One numbered step. Three of these replace the paragraph nobody read.
class _How extends StatelessWidget {
  final String n, text;
  const _How({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(n,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              )),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}
