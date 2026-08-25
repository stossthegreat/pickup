import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../services/backend/auth_service.dart';
import '../../services/achievements.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../services/backend/mission_service.dart';
import '../../services/backend/squad_broadcast.dart';
import '../../services/backend/squad_day.dart';
import '../../services/backend/squad_live_service.dart';
import '../../services/backend/squad_history_service.dart';
import '../../services/squad_moments_service.dart';
import '../../services/backend/squad_service.dart';
import '../../services/live_events.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/academy/academy_modal.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe, scenarioOfToday;
import '../../widgets/academy/day_beat.dart';
import '../../widgets/academy/five_journey.dart';
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/squad_chrome.dart';
import '../../widgets/academy/streak_chain.dart';
import '../../widgets/academy/squad_grade.dart';
import '../../widgets/academy/squad_gauge.dart';
import '../../widgets/academy/today_board.dart';
import '../../widgets/academy/your_five.dart';
import '../../services/my_moves.dart';

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
  SquadHistory _history = SquadHistory.empty;
  /// Missions this phone knows he finished today. Home writes to local
  /// prefs and the squad board reads the server, and the two systems
  /// share no ids — without this the room reported his own work as zero.
  /// See MyMoves.
  int _myMoves = 0;
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
      // Thirty days of daily_attempts for this roster — the chain, the
      // quorum, the armband and the bench all derive from this one read.
      // Same table and RLS policy dailyToday already goes through, so
      // there is nothing to migrate and nothing to switch on.
      SquadHistory.load(ids),
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
      _history = results[5] as SquadHistory;
      _myStates = myStates;
      _loading = false;
    });
    // Local and cheap — read after the frame rather than blocking it,
    // exactly as Squad home does.
    final mine = await MyMoves.today();
    if (mounted) setState(() => _myMoves = mine);
    // ignore: discarded_futures
    _moments(ids);
  }

  /// THE TWO MOMENTS. Fired after the frame that renders them, once per
  /// occurrence, so the chain banking and the armband changing hands
  /// land as events rather than as numbers that were already different
  /// when he looked.
  Future<void> _moments(List<String> ids) async {
    final m = await SquadMoments.check(_history, ids);
    if (!mounted) return;
    final banked = m.banked;
    if (banked != null) {
      HapticFeedback.heavyImpact();
      _celebrate('CHAIN $banked');
      return; // one moment at a time — two dialogs is neither
    }
    final captain = m.captain;
    if (captain == null) return;
    final mine = captain == AuthService.userId;
    String who() {
      for (final r in _roster) {
        if (r.userId == captain) return (r.handle ?? 'SOMEONE').toUpperCase();
      }
      return 'SOMEONE';
    }

    // Losing it is the sharper signal, so it gets the sharper colour.
    LiveEvents.milestone(
      mine ? 'YOU TOOK THE ARMBAND' : '${who()} TOOK THE ARMBAND',
      mine
          ? 'Most runs in the squad this week.'
          : m.lostArmband
              ? 'You had it. Out-run him and take it back.'
              : 'Most runs in the squad this week.',
      color: m.lostArmband ? AppColors.red : const Color(0xFFFFD34D),
    );
  }

  /// The single source of truth for every number on this screen.
  SquadDay get _day => SquadDay(
        roster: _roster,
        board: _board,
        squadStates: _squadStates,
        daily: _daily,
        // THE TWO ARGUMENTS THIS SCREEN WAS MISSING.
        //
        // SquadDay has carried the local-mission bridge since it was
        // written, and Squad home passed it. This screen — the one
        // whose entire job is showing what the squad did — did not, so
        // it read the server alone and told a man who had done all five
        // missions that nobody had moved yet.
        myMoves: _myMoves,
        myUserId: AuthService.userId,
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
    // Nudging is the one purely social act in the app and it had no
    // reward attached at all — see the NUDGES family in achievements.
    MilestoneService.pushTrophies(await Achievements.bump(Stat.nudges));
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
    if (!mounted) return;
    if (squad == null) {
      // Never fail silently again — a dead button is the worst possible
      // outcome because there's nothing to act on.
      _explain('Couldn\'t found the squad',
          SquadService.lastError ?? 'Unknown error.');
      return;
    }
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
      // The database raises in its own words; a man typing a code should
      // read something he can act on. Migration 0011 added the one that
      // matters — one man, one squad — and that needs an answer, not a
      // Postgres string.
      final raw = SquadService.lastError ?? '';
      final msg = raw.contains('already in a squad')
          ? 'You\'re already in a squad. Leave that one first — the '
              'button\'s at the top of the room.'
          : raw.contains('full')
              ? 'That squad is full. Five is the most.'
              : raw.contains('invalid')
                  ? 'No squad with that code. Check it with your mate.'
                  : (raw.isEmpty
                      ? 'Invalid code — check it with your squad.'
                      : raw);
      _explain('Couldn\'t join', msg);
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
      // THIS WAS A LIE. It fired a toast reading "+100 XP" and never
      // called addXp — the app told him he'd been paid and paid him
      // nothing. It now grants a real mission's worth through the one
      // door, and the toast is the receipt rather than the whole event.
      await Rewards.squad(m.title);
      if (!mounted) return;
      _celebrate(m.title);
      _load();
    }
  }

  /// A node opens the brief and the one action it needs — call your
  /// shot, or mark it done. A sheet rather than a page: the journey
  /// stays behind it so you never lose your place on the spine.
  void _openMission(Mission m) {
    final state = _myStates[m.id];
    final completed = state == 'completed';
    final committed = state == 'committed';
    AcademyModal.show(
      context,
      kicker: completed
          ? 'COMPLETED'
          : committed
              ? 'CALLED IT'
              : 'MISSION',
      accent: completed ? kNeon : AppColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                height: 1.15,
                letterSpacing: -0.4,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 10),
          Text(m.prompt,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 18),
          if (completed)
            Text('DONE. THE SQUAD SAW IT.',
                style: GoogleFonts.inter(
                  color: kNeon,
                  fontSize: 11.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ))
          else if (committed) ...[
            GameButton(
                label: 'MARK IT DONE',
                height: 52,
                onTap: () {
                  Navigator.of(context).pop();
                  _complete(m);
                }),
            const SizedBox(height: 8),
            Text('You called it. They\'re watching for the check.',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                )),
          ] else ...[
            GameButton(
                label: 'CALL YOUR SHOT',
                height: 52,
                pulse: true,
                onTap: () {
                  Navigator.of(context).pop();
                  _commit(m);
                }),
            const SizedBox(height: 8),
            Text('Committing posts it to the squad. No hiding after.',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ],
      ),
    );
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

  /// A failure the user can act on: the real reason, copyable.
  void _explain(String title, String detail) {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(title,
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: SelectableText(detail,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ignore: discarded_futures
              Clipboard.setData(ClipboardData(text: detail));
              Navigator.of(ctx).pop();
            },
            child: Text('COPY',
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
                style: GoogleFonts.inter(
                    color: AppColors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
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
    final day = _day;
    final accent = day.won ? kNeon : AppColors.red;
    // Today's woman, resolved with the SAME rule the server uses. The
    // squad's voice slot is not a second challenge — it is the Daily,
    // and there's only one credit a day for it, so the room shows her
    // face rather than a generic "voice run" card.
    final girl = girlForVibe(scenarioOfToday());

    return RefreshIndicator(
      color: AppColors.red,
      backgroundColor: AppColors.surface1,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── THE MASTHEAD — full bleed, atmospheric, one identity ──
          _masthead(squad, day, accent),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── THE CHAIN — the headline, not a chapter ─────────
                //
                // The room's complaint was that nothing stood out: seven
                // numbered sections of near-identical cards, so the eye
                // had nowhere to land and every section read as equally
                // important, which means none of them were. This sits
                // ABOVE the numbering on purpose. It's the only thing on
                // the screen the squad can lose, and losable beats
                // measurable every time.
                SquadStreakHero(
                  history: _history,
                  roster: _roster,
                  accent: accent,
                  onRun: () => context.push('/daily'),
                ),
                const SizedBox(height: 26),

                // ── YOUR FIVE — portraits, arcs, empty seats ────────
                ChapterMark(
                  index: '01',
                  title: 'YOUR FIVE',
                  sub: 'The men in it with you.',
                  accent: accent,
                  trailing: Text(
                      '${_roster.length}/${SquadDay.maxMembers}',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w900,
                      )),
                ),
                YourFive(
                  day: day,
                  onRecruit: _shareInvite,
                  onNudge: _nudge,
                ),
                const SizedBox(height: 16),

                // The code sits right under the seats — the moment you
                // notice an empty one is the moment you want the invite.
                InviteTicket(
                  code: squad.inviteCode,
                  openSeats: day.openSeats,
                  onCopy: _copyCode,
                  onShare: _shareInvite,
                  accent: accent,
                ),
                const SizedBox(height: 26),

                if (!day.live) ...[
                  _needTwo(),
                  const SizedBox(height: 26),
                ],

                // ── TODAY'S BOARD — the whole day, one grid ─────────
                // The screen's answer to "what has everyone actually
                // done?". It goes first because it's the question you
                // open the room to ask.
                ChapterMark(
                  index: '02',
                  title: "TODAY'S BOARD",
                  sub: 'Everyone, everything, one look.',
                  accent: accent,
                ),
                TodayBoard(day: day),
                const SizedBox(height: 26),

                // ── THE RIZZ-OFF — her, and who's faced her ─────────
                ChapterMark(
                  index: '03',
                  title: 'THE RIZZ-OFF',
                  sub: 'Same woman as your Daily. One credit each.',
                  accent: accent,
                ),
                _DailyRunCard(roster: _roster, marks: _daily, girl: girl),
                const SizedBox(height: 26),

                // ── THE FIVE — the day as a journey ─────────────────
                ChapterMark(
                  index: '04',
                  title: 'THE FIVE',
                  sub: 'Same five for everyone today.',
                  accent: accent,
                ),
                if (_board.isEmpty)
                  const _EmptyBoard()
                else
                  FiveJourney(
                    day: day,
                    myStates: _myStates,
                    girl: girl,
                    onOpenMission: _openMission,
                    onOpenRizzOff: () => context.push('/daily'),
                  ),
                const SizedBox(height: 26),

                // ── THE RATING — who's carrying, who's hiding ───────
                ChapterMark(
                  index: '05',
                  title: 'SQUAD REPORT',
                  sub: 'Graded every week.',
                  accent: accent,
                ),
                SquadReport(roster: _roster, marks: _marks),
                const SizedBox(height: 26),

                // ── THE WEEK BOARD ──────────────────────────────────
                ChapterMark(
                  index: '06',
                  title: 'THE WEEK',
                  sub: 'Seven days, who showed up.',
                  accent: accent,
                ),
                _WeekBoard(roster: _roster, marks: _marks),
                const SizedBox(height: 26),

                // ── THE PULSE ───────────────────────────────────────
                ChapterMark(
                  index: '07',
                  title: 'THE PULSE',
                  sub: 'The room, live.',
                  accent: accent,
                ),
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
          ),
        ],
      ),
    );
  }

  // ── THE MASTHEAD ────────────────────────────────────────────────────
  //  Full-bleed, with the squad's colour blooming behind the dial. The
  //  room used to open on a bare back-arrow and a chart; now it opens on
  //  an identity — crest, name, state — the way every other good screen
  //  in this app opens on a poster.
  Widget _masthead(Squad squad, SquadDay day, Color accent) {
    final String state;
    if (!day.live) {
      state = 'One more man and the day starts scoring';
    } else if (day.won) {
      state = 'Day won · ${day.complete}/${day.possible} moves';
    } else if (day.complete == 0) {
      state = 'Live · nobody has moved yet';
    } else {
      state = 'Live · ${day.remaining} to go';
    }

    return Stack(children: [
      Positioned.fill(child: SquadAtmosphere(accent: accent)),
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
          child: Row(children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              onPressed: _shareInvite,
              icon: Icon(Icons.person_add_alt_1_rounded,
                  size: 20, color: accent),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            SquadCrest(name: squad.name, accent: accent, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THE SQUAD',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 8.5,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text(squad.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.0,
                        letterSpacing: -1.2,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 16)
                        ],
                      )),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day.live ? accent : AppColors.textMuted,
                        boxShadow: day.live
                            ? [
                                BoxShadow(
                                    color: accent.withValues(alpha: 0.7),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(state,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),

        // ── THE GAUGE — one hero instrument ───────────────────────
        // Five segments, one per seat, each filling with that man's
        // five moves. The team's whole day, no legend needed.
        SquadGauge(
          day: day,
          squadName: squad.name,
          caption: 'TODAY',
          onWin: _dayWon,
        ),
        const SizedBox(height: 12),

        // ── THE BEAT — the day's clock, right under the dial ──────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: DayBeat(day: day),
        ),
        const SizedBox(height: 6),
      ]),
    ]);
  }

  /// Below the minimum the day can't be scored — one man ticking his own
  /// boxes isn't accountability. Said plainly, without calling the squad
  /// broken.
  Widget _needTwo() {
    return Panel(
      hot: true,
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
      padding: EdgeInsets.zero,
      children: [
        // ── The hero band, same atmosphere as the room itself ───────
        Stack(children: [
          const Positioned.fill(child: SquadAtmosphere(accent: AppColors.red)),
          Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            // The crest fills in live as you type the name — you can
            // see the badge you're about to own before you commit to it.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameCtrl,
              builder: (_, v, __) => SquadCrest(
                name: v.text.trim().isEmpty ? 'YOU' : v.text,
                accent: AppColors.red,
                size: 92,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.04, duration: 1800.ms),
            const SizedBox(height: 22),
            Text('THE SQUAD',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 9.5,
                  letterSpacing: 3.4,
                  fontWeight: FontWeight.w900,
                )).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('NOBODY CHANGES ALONE.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        height: 1.02,
                        letterSpacing: -1.4,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18)
                        ],
                      ))
                  .animate()
                  .fadeIn(duration: 400.ms),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                      'You do the reps whether anyone watches or not. You '
                      'just do more of them when they do. Two men is enough '
                      '— five is the most.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall)
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 400.ms),
            ),
            const SizedBox(height: 26),
          ]),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HOW IT WORKS — three lines. The invite-code system was
              // never explained anywhere, so "how does anyone actually
              // join?" was a fair question with no answer on screen.
              ChapterMark(
                index: '?',
                title: 'HOW IT WORKS',
                sub: 'Thirty seconds, then you\'re in.',
              ),
              _How(n: '1', text: 'Found a squad — you get a 6-letter code'),
              _How(n: '2', text: 'Send the code to your mate'),
              _How(
                  n: '3',
                  text: 'He types it in below — that\'s it, you\'re a squad'),
              const SizedBox(height: 24),

              // ── Two clean cards. One decision each, nothing else on
              // them. The old screen was a loose column of fields and
              // buttons with a divider in the middle and you had to read
              // it to work out which half was which.
              Panel(
                hot: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.add_moderator_rounded,
                          size: 15, color: AppColors.red),
                      const SizedBox(width: 8),
                      Text('START ONE',
                          style: GoogleFonts.inter(
                            color: AppColors.red,
                            fontSize: 9.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w900,
                          )),
                    ]),
                    const SizedBox(height: 4),
                    Text('Name it. You get the code.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 14),
                    _Field(controller: nameCtrl, hint: 'SQUAD NAME'),
                    const SizedBox(height: 12),
                    GameButton(
                        label: 'FOUND A SQUAD', onTap: onCreate, pulse: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Panel(
                accent: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.confirmation_number_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('GOT A CODE?',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w900,
                          )),
                    ]),
                    const SizedBox(height: 4),
                    Text('Type the six letters your mate sent you.',
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 14),
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
                ),
              ),
            ],
          ),
        ),
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
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 15),
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
//  THE AI RUN — the voice Daily, seen by the squad
// ══════════════════════════════════════════════════════════════════════

/// A real-life mission is binary. The AI run isn't — the interesting
/// number is how many opened it versus how many stayed in it to the
/// end, because bailing at line two is the exact thing the squad is
/// meant to make expensive.
class _DailyRunCard extends StatelessWidget {
  final List<SquadMember> roster;
  final List<DailyMark> marks;

  /// Today's woman. Not a decoration — the squad's voice slot IS the
  /// Daily, one credit, one attempt, and showing a nameless "voice run"
  /// card made it look like a second challenge people were missing out
  /// on. Her face is the clearest possible way to say it's the same run.
  final GirlBrief girl;

  const _DailyRunCard(
      {required this.roster, required this.marks, required this.girl});

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

    return Panel(
      accent: kNeon,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: kNeon.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(color: kNeon.withValues(alpha: 0.22), blurRadius: 14)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5),
              child: Image.asset(girl.asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: const Icon(Icons.graphic_eq_rounded,
                          size: 22, color: kNeon))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY · ONE CREDIT EACH',
                    style: GoogleFonts.inter(
                      color: kNeon,
                      fontSize: 8.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text(girl.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.05,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text(girl.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          Text('${finished.length}/${roster.length}',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15,
                letterSpacing: -0.5,
                fontWeight: FontWeight.w900,
              )),
        ]),
        const SizedBox(height: 14),
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
    return Panel(
      padding: const EdgeInsets.all(18),
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
      // Same fix as squad_live_service: the `tier` in this payload was
      // one of the five identity words derived from a voice rating, so
      // the room was told a man had "ranked up to INITIATE" because he'd
      // had a good practice session. Identity is earned in days now and
      // announced by its own ceremony. See standing.dart.
      'rankup' => (Icons.trending_up_rounded, '$who levelled up', kNeon),
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
