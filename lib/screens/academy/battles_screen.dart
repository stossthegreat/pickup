import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/achievements.dart';
import '../../services/backend/battle_service.dart';
import '../../services/backend/leaderboard_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/battle_meta_service.dart';
import '../../services/division.dart';
import '../../services/economy.dart';
import '../../services/local_store_service.dart';
import '../../services/streak_service.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../services/roster.dart';
import '../../services/share_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/streak_badge.dart';
import 'payout_screen.dart';
import '../../widgets/academy/battle_verdict.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe;
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/rank_emblem.dart';
import '../../widgets/academy/rizz_off_reveal.dart';
import '../../widgets/share/rizz_card.dart';
import '../roleplay/girl_chat_screen.dart';
import 'matchmaking_screen.dart';

/// ══════════════════════════════════════════════════════════════════════
///  RIZZ BATTLES — ranked
/// ══════════════════════════════════════════════════════════════════════
///
/// The old screen was a headline, two equal-weight buttons, a text field
/// and a list. Everything on it was the same size, which meant nothing on
/// it was the point. A man landed here and had to DECIDE what to do,
/// and a screen that asks you to decide is a screen you leave.
///
/// This one has exactly one thing on it. The rank hero says who he is;
/// the button says what to press. Everything else — challenging a mate,
/// entering a code, the history — is deliberately quieter, because those
/// are things he does occasionally and queueing is the thing he should
/// do now.
///
/// THE FOUR MECHANICS THIS SCREEN RUNS:
///
///  1. A LADDER WITH A VISIBLE NEXT RUNG. See division.dart. He is never
///     "1,284"; he is always "72 RR off GOLD I".
///
///  2. A STREAK WITH SOMETHING TO LOSE. From three wins the queue button
///     stops saying RANKED and starts saying what's at stake. Loss
///     aversion runs about twice as strong as the equivalent gain, and
///     this is the only honest way to use it — the streak is real and he
///     built it.
///
///  3. AN UNCLOSED LOOP. A duel where the other man hasn't answered yet
///     sits on this screen as an open question. Zeigarnik: unfinished
///     business is what gets remembered, and it's the reason to come
///     back tonight rather than a notification asking him to.
///
///  4. A VERDICT HE WALKS INTO. Duels settle while he's asleep. When he
///     opens the app the result detonates in his face rather than
///     appearing as a row he has to notice — see battle_verdict.dart.
class BattlesScreen extends StatefulWidget {
  /// Set when this is the third TAB rather than a pushed route.
  ///
  /// A tab has no "back" — the arrow would pop the whole shell. It gets
  /// the same header furniture the other two tabs carry instead.
  final ValueChanged<int>? onGoToTab;

  const BattlesScreen({super.key, this.onGoToTab});

  bool get tabMode => onGoToTab != null;

  @override
  State<BattlesScreen> createState() => _BattlesScreenState();
}

class _BattlesScreenState extends State<BattlesScreen> {
  List<Battle> _battles = const [];
  Map<String, String> _handles = const {};
  Map<String, int> _oppRatings = const {};
  int? _rating;
  Standing _standing = const Standing(streak: 0, best: 0, won: 0, lost: 0, drawn: 0);

  bool _loading = true;
  int _xp = 0;
  int _streak = 0;
  bool _showingVerdict = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
    // A rival answering while the screen is up should land. Skipped
    // whenever this screen isn't the one being looked at — the duel
    // screen and the chat are pushed on top of it and this state object
    // stays alive underneath them, so an unguarded poll would fire a
    // verdict over a conversation in progress.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      // ignore: discarded_futures
      _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  // ── Load ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final battles = await BattleService.myBattles();
    final handles = await BattleService.handles(battles);

    // Opponent ratings, so a past duel can say WHO he beat rather than
    // just that he won. One round-trip for the whole list.
    final ids = <String>{
      for (final b in battles)
        if (b.opponentId != null) b.opponentId!,
    };
    // RR, not the voice rating. See leaderboard_service.dart — these two
    // numbers were one column until migration 0012 and this screen is
    // the one that most needed them apart.
    final ratings = ids.isEmpty
        ? const <String, int>{}
        : await LeaderboardService.battleRatings(ids.toList());

    final mine = await LeaderboardService.myBattleRating();
    if (mine != null) await BattleMeta.seedRating(mine);

    final settled = battles.where((b) => b.settled).toList();
    await _catchUp(settled);
    final standing = await BattleMeta.standing();
    final xp = await LocalStoreService.xpTotal();
    final streak = await StreakService.current();

    if (!mounted) return;
    setState(() {
      _battles = battles;
      _handles = handles;
      _oppRatings = ratings;
      _rating = mine;
      _standing = standing;
      _xp = xp;
      _streak = streak;
      _loading = false;
    });
  }

  /// EVERY DUEL THAT RESOLVED WHILE HE WASN'T LOOKING.
  ///
  /// Banks them into his record, then plays the verdict for the newest
  /// one. Only the newest — five verdicts back to back is a punishment,
  /// and the others are on the list where he can find them.
  Future<void> _catchUp(List<Battle> settled) async {
    // First run: reconstruct the record from what the server still has,
    // and swallow the verdicts. A man updating the app does not want
    // nine old fights replayed at him.
    final before = await BattleMeta.standing();
    if (before.played == 0 && settled.isNotEmpty) {
      var w = 0, l = 0, d = 0, streak = 0;
      var counting = true;
      for (final b in settled) {
        // Newest first — the current streak is the run at the top.
        if (b.tie) {
          d++;
        } else if (b.iWon) {
          w++;
          if (counting) streak++;
        } else {
          l++;
          counting = false;
        }
      }
      await BattleMeta.seedFromHistory(
          won: w, lost: l, drawn: d, streak: streak);
      await BattleMeta.swallow([for (final b in settled) b.id]);
      return;
    }

    final unseenIds = await BattleMeta.unseen([for (final b in settled) b.id]);
    if (unseenIds.isEmpty) return;

    // GUARD BEFORE BANKING, not after. If this screen isn't the one on
    // top — he's mid-conversation, or a verdict is already playing —
    // we do nothing at all and pick it up on the next pass. Banking
    // first and then bailing would mark the duel seen and he'd never
    // get the moment.
    if (!mounted ||
        _showingVerdict ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }

    final fresh = [
      for (final b in settled)
        if (unseenIds.contains(b.id)) b
    ];
    // Bank oldest first so the streak ends up in the right order.
    for (final b in fresh.reversed) {
      await BattleMeta.record(won: b.iWon, tie: b.tie);
    }
    await BattleMeta.markSeen(unseenIds);

    if (!mounted) return;
    final newest = fresh.first;

    // RR movement is only attributable when ONE duel settled. Two at
    // once and the delta belongs to both, so we show the verdict without
    // a number rather than assigning the whole swing to one fight.
    final rr = await LeaderboardService.myBattleRating();
    final move = rr == null ? null : await BattleMeta.noteRating(rr);
    final attributable = fresh.length == 1;

    if (!mounted) return;
    await _playVerdict(
      newest,
      move: move,
      delta: attributable ? move?.delta : null,
      whileAway: true,
    );
  }

  Future<void> _playVerdict(
    Battle b, {
    required Move? move,
    required int? delta,
    bool whileAway = false,
  }) async {
    if (move == null) return;
    _showingVerdict = true;
    final standing = await BattleMeta.standing();
    if (!mounted) {
      _showingVerdict = false;
      return;
    }
    await BattleVerdict.show(
      context,
      BattleVerdict(
        myScore: Economy.aiScoreFromVoice(b.myScore ?? 0),
        theirScore: Economy.aiScoreFromVoice(b.theirScore ?? 0),
        iWon: b.iWon,
        tie: b.tie,
        opponent: _handles[b.opponentId] ?? 'ANON',
        girl: girlForVibe(b.scenario),
        rank: move.rank,
        delta: delta,
        promoted: move.promoted,
        demoted: move.demoted,
        from: move.from,
        streak: standing.streak,
        whileAway: whileAway,
        onRunItBack: _findRival,
      ),
    );
    _showingVerdict = false;
  }

  // ── Actions ─────────────────────────────────────────────────────────

  /// THE BUTTON. Search is a full-screen event now, not a spinner on a
  /// card — see matchmaking_screen.dart for why that's the whole point.
  Future<void> _findRival() async {
    HapticFeedback.mediumImpact();
    final battle = await MatchmakingScreen.find(context);
    if (!mounted) return;
    if (battle == null) {
      await _load();
      return;
    }
    // Paired and counted in — straight into the fight, no second tap.
    await _run(battle);
  }

  /// Bin an open challenge. Confirmed, because a code he's already sent
  /// to a mate disappearing on a mis-tap is worse than the clutter.
  Future<void> _cancel(Battle b) async {
    HapticFeedback.selectionClick();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('BIN THIS CHALLENGE?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            )),
        content: Text(
            'Code ${b.inviteCode ?? ''} stops working. If you\'ve already '
            'sent it to someone, they won\'t be able to take the fight.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('KEEP IT',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                )),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('BIN IT',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await BattleService.cancelChallenge(b.id);
    if (!mounted) return;
    if (!ok) {
      _toast('Couldn\'t bin it — someone may have already taken it.');
    }
    await _load();
  }

  Future<void> _challenge() async {
    HapticFeedback.mediumImpact();
    final battle = await BattleService.createChallenge();
    if (battle == null || !mounted) {
      if (mounted) _toast('Couldn\'t mint a challenge. Try again in a sec.');
      return;
    }
    // ignore: discarded_futures
    _load();
    final girl = girlForVibe(battle.scenario);
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      barrierDismissible: true,
      barrierLabel: 'challenge',
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (ctx, _, __) => Material(
        color: Colors.transparent,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Portrait(girl: girl, size: 108, ring: girl.accent),
              const SizedBox(height: 18),
              Text('CHALLENGE MINTED',
                  style: GoogleFonts.inter(
                    color: girl.accent,
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 8),
              Text(girl.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 30,
                    letterSpacing: -0.8,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 4),
              Text(
                  'Same woman. Both blind. Higher AI Score takes the '
                  '${Economy.rrShort}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.55)),
                ),
                child: Text(battle.inviteCode ?? '',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 30,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 250,
                child: GameButton(
                  label: 'SEND THE CHALLENGE',
                  icon: Icons.ios_share_rounded,
                  onTap: () => ShareService.shareRizzCard(
                    context: context,
                    data: RizzShareData(
                      kicker: 'CHALLENGE',
                      hero: battle.inviteCode ?? '',
                      heroSub: 'ENTER THIS CODE',
                      line: '${girl.name}. Same woman, both blind, '
                          'text only. Higher AI Score takes the RR.',
                      accent: girl.accent,
                      faces: [(asset: girl.asset, owned: true)],
                    ),
                    text: 'I challenge you on ImHim Rizz — ${girl.name}. '
                        'Same woman, both blind, higher score wins. '
                        'Code: ${battle.inviteCode}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 250,
                child: GameButton(
                  label: 'RUN MY ATTEMPT NOW',
                  color: AppColors.surface2,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // ignore: discarded_futures
                    _run(battle);
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
      transitionBuilder: (ctx, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  /// The code entry lives in a sheet now rather than a permanent field.
  /// A text box sitting on the main screen forever is a thing 98% of men
  /// will never type in, taking up the space directly under the only
  /// button that matters.
  Future<void> _enterCode() async {
    HapticFeedback.selectionClick();
    final ctrl = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.base,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              22, 18, 22, 22 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('ENTER A CODE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 4),
            Text('Someone challenged you. Take it.',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 18),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 9,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 22,
                  letterSpacing: 9,
                  fontWeight: FontWeight.w900,
                ),
                filled: true,
                fillColor: AppColors.surface1,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.red, width: 1.6),
                ),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                label: 'TAKE THE FIGHT',
                onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              ),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (code == null || code.length < 6 || !mounted) return;

    final battle = await BattleService.joinChallenge(code);
    if (!mounted) return;
    if (battle == null) {
      _toast('Invalid code — or the duel is already claimed.');
      return;
    }
    await _run(battle);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// BATTLES ARE TEXT, not voice.
  ///
  /// Two reasons, and the money one is the smaller of them. Live voice is
  /// the single most expensive action in the app (OpenAI Realtime audio),
  /// and a man already gets a voice rep every day from the Daily — paying
  /// for unlimited duels on top of that is a bill with no ceiling.
  ///
  /// The better reason is that duels work in writing. A battle is meant
  /// to be run whenever you fancy it, in a pub, on a bus, at 1am with
  /// someone asleep next to you — and none of those are places you talk
  /// out loud to your phone. Voice stays the once-a-day event that costs
  /// you something to show up for; text is the thing you can always do.
  ///
  /// AND EVERY WOMAN IS UNLOCKED IN HERE. The 60-day ladder gates her in
  /// Practice and it should — the climb is the product. But a duel isn't
  /// practice, it's a fight you agreed to, and being handed someone
  /// twenty days above your level is the point rather than a mistake.
  Future<void> _run(Battle b) async {
    HapticFeedback.heavyImpact();
    final girl = girlForVibe(b.scenario);

    // The rating BEFORE, so the movement afterwards is measured rather
    // than predicted. The server owns the Elo maths; this screen only
    // reports what it did.
    final before = await LeaderboardService.myBattleRating();
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => GirlChatScreen(
          config: GirlChatConfig(
            characterId: girl.id,
            vibeKey: girl.vibeKey,
            name: girl.name,
            archetype: girl.archetype,
            portraitAsset: girl.asset,
            accent: girl.accent,
            opener: girl.opener,
            taskMode: true,
            // The transcript goes to the duel, which grades it, settles
            // the fight and banks the chat attempt in one call.
            battleId: b.id,
            // The duel closes on its own verdict against the other man.
            verdictOnFinish: false,
          ),
        ),
      ),
    );
    if (!mounted) return;

    // HIS OWN NUMBER FIRST — the same count-up, axes and grade slam the
    // Daily gets. He learns what he scored here and still doesn't know
    // whether it was enough.
    final r = BattleService.lastResult;
    if (r != null) {
      BattleService.lastResult = null;
      // The conversation happened whether or not the other man has
      // answered yet, so it counts toward the talking families now
      // rather than waiting on someone else to open the app.
      MilestoneService.pushTrophies(await Achievements.bump(Stat.talks));
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.black,
        barrierDismissible: false,
        barrierLabel: 'battle',
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (ctx, _, __) => RizzOffReveal(
          score: Economy.aiScoreFromVoice(r.score),
          gradeScore: r.score,
          rubric: r.rubric,
          rankToday: 0,
          worldAvg: 0,
          girlName: girl.name,
          girlAccent: girl.accent,
          divisor: 1,
          decimals: 0,
          suffix: '/ 100',
          kicker: 'BATTLE',
        ),
        transitionBuilder: (ctx, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      );
      if (!mounted) return;

      // THEN THE FIGHT. Only if the other man is already in — otherwise
      // the duel stays open and the verdict detonates whenever he
      // answers, which is the better version anyway.
      if (r.settled) {
        final fresh = await BattleService.myBattles();
        if (!mounted) return;
        Battle? settled;
        for (final x in fresh) {
          if (x.id == b.id) settled = x;
        }
        if (settled != null && settled.settled) {
          await BattleMeta.record(won: settled.iWon, tie: settled.tie);
          await BattleMeta.markSeen([settled.id]);
          // A DUEL PAID NOTHING IN XP. He fought another human on the
          // same woman and his level didn't move. Losing pays too — a
          // ladder where defeat costs RR *and* pays zero is one men stop
          // queueing on after two bad nights.
          await Rewards.battle(won: settled.iWon);
          MilestoneService.pushTrophies(await Achievements.bump(Stat.duels));
          if (settled.iWon) {
            MilestoneService.pushTrophies(await Achievements.bump(Stat.wins));
          }
          final after = await LeaderboardService.myBattleRating();
          if (!mounted) return;
          final move =
              after == null ? null : await BattleMeta.noteRating(after);
          if (!mounted) return;
          await _playVerdict(
            settled,
            move: move,
            delta: before == null || after == null ? null : after - before,
          );
        }
      }
    }
    if (mounted) await _load();
    if (mounted) await PayoutScreen.cashOut(context);
  }

  void _shareResult(Battle b) {
    HapticFeedback.selectionClick();
    final vs = _handles[b.opponentId] ?? 'a rival';
    final girl = girlForVibe(b.scenario);
    ShareService.shareRizzCard(
      context: context,
      data: RizzShareData(
        kicker: b.iWon ? 'VICTORY' : 'BATTLE',
        hero: '${battleScore(b.myScore)} — ${battleScore(b.theirScore)}',
        heroSub: 'YOU  ·  ${vs.toUpperCase()}',
        line: 'Same woman. Both blind. '
            '${girl.name} didn\'t know either of us was being scored.',
        accent: b.iWon ? kNeon : AppColors.red,
        faces: [(asset: girl.asset, owned: true)],
        stats: [
          (label: 'YOU', value: battleScore(b.myScore)),
          (label: vs.toUpperCase(), value: battleScore(b.theirScore)),
        ],
      ),
      text: b.iWon
          ? 'Won my Rizz Battle vs $vs — ${battleScore(b.myScore)} to '
              '${battleScore(b.theirScore)}. Who\'s next?'
          : 'Rizz Battle vs $vs: ${battleScore(b.myScore)} to '
              '${battleScore(b.theirScore)}. Running it back.',
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  List<Battle> get _myMove =>
      _battles.where((b) => !b.settled && !b.iSubmitted).toList();
  List<Battle> get _waiting =>
      _battles.where((b) => !b.settled && b.iSubmitted).toList();
  List<Battle> get _past => _battles.where((b) => b.settled).toList();

  @override
  Widget build(BuildContext context) {
    final rank = Rank.of(_rating ?? 0);
    final onTheLine = Streaks.onTheLine(_standing.streak);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          // THE SAME HEADER AS THE OTHER TWO TABS: icons on their own
          // line, then the three pills, then the title and its red line.
          // The 1–1 record used to sit up here beside the title — it's a
          // stat, not navigation, and it's already on the hero.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (!widget.tabMode)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                    ),
                  const Spacer(),
                  if (widget.tabMode) ...[
                    _Cog(
                        icon: Icons.local_fire_department_rounded,
                        onTap: () => widget.onGoToTab!(3)),
                    const SizedBox(width: 6),
                    _Cog(
                        icon: Icons.emoji_events_outlined,
                        onTap: () => context.push('/leaderboard')),
                    const SizedBox(width: 6),
                    _Cog(
                        icon: Icons.settings_outlined,
                        onTap: () => context.push('/settings')),
                  ],
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  XpBadge(label: '${Economy.commas(_xp)} XP'),
                  const SizedBox(width: 8),
                  if (_streak > 0) StreakBadge(days: _streak),
                  if (_streak > 0) const SizedBox(width: 8),
                  const RankBadge(),
                ]),
                const SizedBox(height: 14),
                Text('Rizz Battles', style: AppTypography.h1Italic),
                const SizedBox(height: 6),
                Text(
                  'Same woman. Both blind. The better conversation takes '
                  'the rating.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.red),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface1,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                children: [
                  // ── THE HERO ────────────────────────────────────────
                  _hero(rank),
                  const SizedBox(height: 20),

                  // ── THE BUTTON ──────────────────────────────────────
                  _RivalButton(
                    onTap: _findRival,
                    stakeLine: onTheLine,
                  ),
                  const SizedBox(height: 12),

                  // Quiet, on purpose. These are occasional things.
                  Row(children: [
                    Expanded(
                      child: _Quiet(
                        icon: Icons.link_rounded,
                        label: 'CHALLENGE A MATE',
                        onTap: _challenge,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Quiet(
                        // Proven-in-repo icon. There's no SDK in this
                        // environment to check a new one against, and a
                        // wrong constant is a red screen on his phone.
                        icon: Icons.lock_open_rounded,
                        label: 'ENTER A CODE',
                        onTap: _enterCode,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 26),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.red)),
                      ),
                    ),

                  // ── YOUR MOVE ───────────────────────────────────────
                  if (_myMove.isNotEmpty) ...[
                    _heading('YOUR MOVE', _myMove.length, AppColors.red),
                    for (final (i, b) in _myMove.indexed)
                      _LiveDuel(
                        battle: b,
                        opponent: _handles[b.opponentId],
                        oppRating: _oppRatings[b.opponentId],
                        myRating: _rating,
                        onRun: () => _run(b),
                        // Only an unclaimed challenge can be binned —
                        // once a rival is in, it's his fight too.
                        onCancel: b.opponentId == null && b.state == 'open'
                            ? () => _cancel(b)
                            : null,
                      ).animate().fadeIn(
                          delay: (60 * i).clamp(0, 300).ms, duration: 260.ms),
                    const SizedBox(height: 10),
                  ],

                  // ── WAITING ON HIM ──────────────────────────────────
                  if (_waiting.isNotEmpty) ...[
                    _heading('WAITING ON HIM', _waiting.length,
                        AppColors.signalAmber),
                    for (final b in _waiting)
                      _Waiting(
                        battle: b,
                        opponent: _handles[b.opponentId],
                      ),
                    const SizedBox(height: 10),
                  ],

                  // ── SETTLED ─────────────────────────────────────────
                  if (_past.isNotEmpty) ...[
                    _heading('SETTLED', _past.length, AppColors.textTertiary),
                    for (final (i, b) in _past.indexed)
                      _PastDuel(
                        battle: b,
                        opponent: _handles[b.opponentId],
                        oppRating: _oppRatings[b.opponentId],
                        onShare: () => _shareResult(b),
                      ).animate().fadeIn(
                          delay: (40 * i).clamp(0, 300).ms, duration: 240.ms),
                  ],

                  if (!_loading && _battles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                          'No duels yet. Someone has to be first — and the '
                          'first rung is the cheapest one you\'ll ever climb.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// The hero. Emblem, division, rating, the gap to the next rung.
  ///
  /// IT USED TO PRINT AN IDENTITY TIER UNDER THIS — "OBSERVER TIER" — on
  /// the theory that showing both zoom levels would prove they were one
  /// climb. It proved the opposite. A man read INITIATE on Home and
  /// OBSERVER here and concluded, correctly, that the app didn't know
  /// what it was measuring.
  ///
  /// So this surface now speaks ONE vocabulary and it's the competitive
  /// one: BRONZE III → LEGEND I, moved by duels. His identity rank is on
  /// Home, earned in days, and never appears here. See standing.dart.
  Widget _hero(Rank rank) {
    final streakTitle = Streaks.title(_standing.streak);

    return Column(children: [
      RankEmblem(rank: rank, size: 118),
      const SizedBox(height: 14),
      Text(rank.label,
          style: GoogleFonts.inter(
            color: rank.div.color,
            fontSize: 27,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            shadows: rank.div.glows
                ? [
                    Shadow(
                        color: rank.div.color.withValues(alpha: 0.6),
                        blurRadius: 28)
                  ]
                : null,
          )),
      const SizedBox(height: 5),
      Text(_rating == null ? '—' : Economy.rr(rank.rating),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 6),
      if (rank.toNext != null)
        Text(rank.toNext!,
            style: GoogleFonts.inter(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            )),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Chip(
          label: _standing.played == 0
              ? 'NO DUELS YET'
              : '${_standing.line} RECORD',
          color: AppColors.textTertiary,
          icon: Icons.sports_mma_rounded,
        ),
        if (streakTitle != null) ...[
          const SizedBox(width: 8),
          _Chip(
            label: '${Streaks.emoji(_standing.streak)} '
                '${_standing.streak} $streakTitle',
            color: AppColors.signalAmber,
          ),
        ] else if (_standing.winRate != null) ...[
          const SizedBox(width: 8),
          _Chip(
            label: '${_standing.winRate}% WIN RATE',
            color: AppColors.textTertiary,
          ),
        ],
      ]),
    ]);
  }

  Widget _heading(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(children: [
        Container(width: 3, height: 13, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11.5,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 7),
        Text('$count',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE BUTTON
// ══════════════════════════════════════════════════════════════════════

/// One enormous thing to press.
///
/// It is deliberately bigger than anything else on the screen, it
/// breathes, and a shine crosses it every few seconds. That shine is not
/// decoration: a static element becomes invisible within about two
/// visits, and a moving one keeps drawing the eye back to the single
/// action this screen exists for.
///
/// The sub-label is the honest half. When he has a streak it stops
/// saying RANKED and starts naming what he's putting at risk.
class _RivalButton extends StatefulWidget {
  final VoidCallback onTap;
  final String? stakeLine;
  const _RivalButton({required this.onTap, this.stakeLine});

  @override
  State<_RivalButton> createState() => _RivalButtonState();
}

class _RivalButtonState extends State<_RivalButton>
    with TickerProviderStateMixin {
  bool _down = false;

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _breathe.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stake = widget.stakeLine;
    const edge = 7.0;
    const h = 118.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (_, child) => Transform.scale(
          scale: 1 + _breathe.value * 0.012,
          child: child,
        ),
        child: SizedBox(
          height: h + edge,
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: edge,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(AppColors.red, Colors.black, 0.5),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _down ? edge : 0,
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF3B43), Color(0xFFB3151B)],
                    ),
                    boxShadow: _down
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.45),
                              blurRadius: 34,
                              offset: const Offset(0, 6),
                            )
                          ],
                  ),
                  child: Stack(children: [
                    // The shine.
                    AnimatedBuilder(
                      animation: _shine,
                      builder: (_, __) {
                        final x = -1.4 + _shine.value * 3.0;
                        return Align(
                          alignment: Alignment(x, 0),
                          child: Transform.rotate(
                            angle: 0.36,
                            child: Container(
                              width: 62,
                              height: 260,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded,
                              size: 30, color: Colors.white),
                          const SizedBox(height: 8),
                          Text('FIND A RIVAL',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 25,
                                height: 1,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 6),
                          Text(
                              stake ??
                                  'RANKED · ${Economy.rrLong} ON THE LINE',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 10,
                                letterSpacing: 2.6,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The two things he does occasionally, sized like it.
class _Quiet extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quiet({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surface3),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
        ],
        Text(label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE DUELS
// ══════════════════════════════════════════════════════════════════════

/// A fight he hasn't run yet. Her face, who's across from him, what it's
/// worth — and one button.
class _LiveDuel extends StatelessWidget {
  final Battle battle;
  final String? opponent;
  final int? oppRating;
  final int? myRating;
  final VoidCallback onRun;

  /// Null unless this is an open challenge he minted and nobody took.
  final VoidCallback? onCancel;

  const _LiveDuel({
    required this.battle,
    required this.opponent,
    required this.oppRating,
    required this.myRating,
    required this.onRun,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final b = battle;
    final girl = girlForVibe(b.scenario);
    final open = b.opponentId == null;
    final vs = opponent ?? (open ? 'AWAITING A RIVAL' : 'ANON');
    final s = (myRating != null && oppRating != null)
        ? Stakes.forMatch(mine: myRating!, theirs: oppRating!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: girl.accent.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(children: [
        SizedBox(
          height: 88,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(
              girl.asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.36),
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: girl.accent.withValues(alpha: 0.22)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    AppColors.surface1,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Text(girl.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 10)
                      ],
                    )),
                const SizedBox(width: 8),
                Text(b.scenarioLabel,
                    style: GoogleFonts.inter(
                      color: girl.accent,
                      fontSize: 9.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    )),
                const Spacer(),
                if (b.inviteCode != null && b.state == 'open')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(b.inviteCode!,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                // THE BIN. Deliberately small and to the right of the
                // code — it's the rarely-wanted action on a card whose
                // whole job is the button underneath it.
                if (onCancel != null)
                  GestureDetector(
                    onTap: onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Column(children: [
            Row(children: [
              if (oppRating != null)
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: RankEmblem(
                      rank: Rank.of(oppRating!), size: 34, showProgress: false),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vs.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                        )),
                    Text(
                        oppRating != null
                            ? Rank.of(oppRating!).label
                            : (open
                                ? 'SEND THE CODE TO SOMEONE'
                                : 'UNRANKED'),
                        style: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
              // The stakes, on the card, before he taps. The number he
              // stands to lose is doing more work here than the one he
              // stands to win.
              if (s != null)
                Text('+${s.win} / ${s.lose}',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    )),
            ]),
            const SizedBox(height: 12),
            GameButton(
              label: open ? 'RUN YOUR ATTEMPT' : 'FIGHT',
              color: girl.accent,
              height: 50,
              onTap: onRun,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// His attempt is in and the other man hasn't answered. This is the open
/// loop — the reason he checks back tonight. It says nothing about his
/// score beyond that it's locked, because a number he can see is a
/// closed loop and this one has to stay open.
class _Waiting extends StatelessWidget {
  final Battle battle;
  final String? opponent;
  const _Waiting({required this.battle, required this.opponent});

  @override
  Widget build(BuildContext context) {
    final girl = girlForVibe(battle.scenario);
    final vs = opponent ?? 'YOUR RIVAL';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.signalAmber.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: girl.accent.withValues(alpha: 0.6)),
          ),
          child: Image.asset(
            girl.asset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.2),
            errorBuilder: (_, __, ___) =>
                ColoredBox(color: girl.accent.withValues(alpha: 0.25)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LOCKED IN vs ${vs.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  )),
              Text('He hasn\'t answered ${girl.name} yet.',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        Text('?',
                style: GoogleFonts.inter(
                  color: AppColors.signalAmber,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.35, end: 1, duration: 900.ms),
      ]),
    );
  }
}

/// A finished fight. Compact — the drama already happened on the verdict
/// screen and a history that shouts is a history nobody scrolls.
class _PastDuel extends StatelessWidget {
  final Battle battle;
  final String? opponent;
  final int? oppRating;
  final VoidCallback onShare;
  const _PastDuel({
    required this.battle,
    required this.opponent,
    required this.oppRating,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final b = battle;
    final girl = girlForVibe(b.scenario);
    final vs = opponent ?? 'ANON';
    final (label, tone) = b.tie
        ? ('DRAW', AppColors.textSecondary)
        : b.iWon
            ? ('WON', kNeon)
            : ('LOST', AppColors.red);

    return GestureDetector(
      onTap: onShare,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(width: 3, height: 30, color: tone),
          const SizedBox(width: 10),
          if (oppRating != null) ...[
            RankEmblem(
                rank: Rank.of(oppRating!), size: 30, showProgress: false),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vs.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    )),
                Text(girl.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: girl.accent,
                      fontSize: 9.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
          Text('${battleScore(b.myScore)}–${battleScore(b.theirScore)}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(label,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: tone,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ]),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  final GirlBrief girl;
  final double size;
  final Color ring;
  const _Portrait(
      {required this.girl, required this.size, required this.ring});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
        border: Border.all(color: ring, width: 2.5),
        boxShadow: [
          BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: 30)
        ],
      ),
      child: Image.asset(
        girl.asset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.2),
        errorBuilder: (_, __, ___) =>
            ColoredBox(color: ring.withValues(alpha: 0.25)),
      ),
    );
  }
}

/// BATTLE SCORES READ OUT OF 100.
///
/// The grader stores full resolution server-side (five axes weighted into
/// 0..1, then ×99.99 → 0..9999) and that number used to go straight onto
/// the card. It looked like an arcade score and, worse, it disagreed with
/// every other text number in the app: the chat challenge and the Rizz
/// Points board both speak out of 100. A man who scores 82 in a duel and
/// 82 on the daily should see the same number twice.
String battleScore(int? raw) =>
    raw == null ? '—' : '${Economy.aiScoreFromVoice(raw)}';

/// The header cog, same object the other two tabs use.
class _Cog extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Cog({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
