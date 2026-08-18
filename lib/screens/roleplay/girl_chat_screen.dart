import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/auralay_dev_flags.dart';
import '../../services/analytics_service.dart';
import '../../services/creator_mode_store.dart';
import '../../services/backend/battle_service.dart';
import '../../services/backend/chat_score_service.dart';
import '../../services/boon_service.dart';
import '../../services/local_store_service.dart';
import '../../services/language_service.dart';
import '../../services/mirror_service.dart';
import '../../services/paywall_gate.dart';
import '../../services/achievements.dart';
import '../../services/coaching.dart' show Coaching;
import '../../services/tactics.dart';
import '../../services/milestone_service.dart';
import '../../services/rewards.dart';
import '../../services/rolodex_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/perfect_line.dart';
import '../../widgets/academy/the_roll.dart';
import '../../widgets/academy/verdict.dart';
import '../../widgets/common/ai_consent_dialog.dart';
import '../academy/rolodex_screen.dart';
import '../game/freeflow/free_flow_screen.dart';

/// A story / post the AI girl dropped — the "scenario ready" for a
/// COMMENT-ON-HER-POST mission. When present, the chat opens on her post
/// and the user has to rizz his way in with a comment.
class GirlPost {
  final String context; // "Posted a story · 3am"
  final String caption; // the words on her post
  const GirlPost({required this.context, required this.caption});
}

/// Everything a roleplay chat with one AI girl needs. Shared by the
/// Practice tab (flirt back-and-forth) and the Missions tab (comment on
/// her post). The [vibeKey] is the handoff to the realtime VOICE orb so
/// the 📞 button in the header opens her live on [FreeFlowScreen].
class GirlChatConfig {
  /// Backend /v1/date character id (e.g. 'ice_queen', 'chaos', 'shy').
  final String characterId;

  /// Realtime persona key for the voice handoff (FreeFlowScreen).
  final String vibeKey;

  final String name; // display name / archetype
  final String archetype; // one-line tagline under the name
  final String portraitAsset;
  final Color accent;

  /// Her first line in practice mode. Ignored when [post] is set.
  final String opener;

  /// Scoring focus handed to the backend ('game' | 'confidence' | …).
  final String focus;

  /// When set, the chat is a COMMENT-ON-HER-POST scene: her post shows
  /// at the top and she waits for the user's opener.
  final GirlPost? post;

  /// When true this is a MISSION task chat (not free Practice): a COMPLETE
  /// bar tracks progress, the user must actually trade [taskGoal] lines, and
  /// a score card slides up at the end. Free Practice chats leave this false.
  final bool taskMode;
  final int taskGoal;

  /// Which ladder this conversation is graded under. Defaults to
  /// ordinary practice; the daily chat challenge passes 'daily_chat' so
  /// DailyChatService can find today's run without a table of its own.
  final String scoreSurface;

  /// Set when this conversation IS a battle. The transcript then goes to
  /// the duel rather than the solo grader — battle-action grades it,
  /// settles the duel, and records the chat attempt itself, so sending
  /// it both ways would double-count the man's points.
  final String? battleId;

  /// Whether finishing this conversation ends on THE VERDICT.
  ///
  /// False for the surfaces that already own their ending — the daily
  /// chat challenge and battles both close on the full reveal with the
  /// squad slam in it, and stacking a second full-screen result behind
  /// the first is precisely the "it keeps showing again and again"
  /// problem. The mid-conversation win is NOT suppressed by this: her
  /// folding is a different event from a score landing, it's rare, and
  /// an interrupt he didn't schedule is the whole reason it works.
  final bool verdictOnFinish;

  /// ══════════════════════════════════════════════════════════════════
  ///  THE COACH IS OFF BY DEFAULT
  /// ══════════════════════════════════════════════════════════════════
  ///
  /// Lucien writes the line for you. That is a fine feature and a fatal
  /// one on any surface that produces a number other people can see.
  ///
  /// A leaderboard where the score can be typed for you is not a
  /// leaderboard, it's a list of who used the help button most. A duel
  /// where one man was fed his opener isn't a duel. And an AI mission
  /// that pays XP for a conversation the coach wrote pays for nothing —
  /// the man walks away having learnt that the app can talk to women.
  ///
  /// DEFAULTS TO FALSE ON PURPOSE. Not "off where it matters" — off
  /// everywhere, opted back IN by the one surface that should have it.
  /// A new graded screen written a year from now is safe without its
  /// author having to know this rule exists; the failure mode of
  /// forgetting is a missing button, not a corrupted ladder.
  ///
  /// PRACTICE KEEPS IT, and keeps it entirely. Practice is where you're
  /// meant to be shown what a good line looks like — it scores nothing
  /// anyone else can see, it feeds no ladder, and stripping the coach
  /// out of it would remove the only place in the app that actually
  /// teaches.
  final bool coachAllowed;

  const GirlChatConfig({
    required this.characterId,
    required this.vibeKey,
    required this.name,
    required this.archetype,
    required this.portraitAsset,
    required this.accent,
    required this.opener,
    this.focus = 'game',
    this.post,
    this.taskMode = false,
    this.taskGoal = 15,
    this.scoreSurface = 'roleplay',
    this.battleId,
    this.verdictOnFinish = true,
    this.coachAllowed = false,
  });
}

class _Msg {
  final String who; // 'her' | 'you' | 'lucien' | 'error'
  final String text;
  const _Msg(this.who, this.text);
}

/// GIRL CHAT — texting roleplay with an AI girl. She replies in
/// character; her interest meter moves with every line. Tap "Get help
/// from Lucien" for an on-demand rizz line, or 📞 to take it live on
/// voice.
///
/// Runs on POST /v1/date/turn + /v1/date/help (unified backend).
class GirlChatScreen extends StatefulWidget {
  final GirlChatConfig config;
  const GirlChatScreen({super.key, required this.config});

  @override
  State<GirlChatScreen> createState() => _GirlChatScreenState();
}

class _GirlChatScreenState extends State<GirlChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _msgs = [];
  bool _sending = false;
  bool _helping = false; // Lucien "Get Help" request in flight
  bool _creator = false;
  int _turnIndex = 0;
  bool _taskDone = false; // mission task: score card already shown

  // Fed to the AI so she uses his name + pitches to his age band.
  String? _name;
  String? _ageGroup;

  /// Her interest, 0–100. Starts guarded, moves with each turn's delta.
  /// Set per-character in initState — cold girls start lower. Persisted
  /// per girl so warmth carries between sessions (the memory layer).
  double _heat = 20;

  /// THE HIGH-WATER MARK. Where she got to at her warmest, which is the
  /// only number worth showing him when it ends badly — "she was at 71
  /// before it went" is a near miss, and a near miss is the version of a
  /// loss a man runs back. The final score alone is just a verdict.
  double _peak = 0;

  /// The line of his that moved her most, and by how much. Captured live
  /// because it can't be reconstructed later: this is what goes on the
  /// Rolodex card if she folds, and the card is worth keeping precisely
  /// because he wrote that sentence himself.
  String _bestLine = '';
  double _bestDelta = -999;

  /// Was his last line a stumble? Feeds the mirror's SECOND WIND axis —
  /// "his best line is the one straight after a bad one" is only
  /// measurable if you remember the bad one.
  bool _stumbled = false;

  /// WHERE HE LOST HER. The mirror of _bestLine, and the single most
  /// useful thing this screen can hand the reveal.
  ///
  /// The grader returns five numbers and nothing else — no spans, no
  /// quotes — so "the line that cost you" could never come from the
  /// server. But this screen scores EVERY message locally on its way
  /// past, so it has always known and has always thrown it away.
  String _worstLine = '';
  double _worstDelta = 999;

  /// Everything she's said, for callback detection. A callback has to
  /// reach further back than the message he's answering, or every reply
  /// would count as one.
  final List<String> _herLines = [];
  String _hisPrevious = '';

  /// Tactics this conversation demonstrated, banked at the end so a man
  /// isn't interrupted mid-flow by a card.
  final List<String> _tacticsSeen = [];

  /// PERFECT LINE fires at most once in a conversation, on top of the
  /// once-a-day cap. Rare is the entire mechanic.
  bool _perfectShown = false;

  /// The verdict fires exactly once per conversation. She can't hand you
  /// her number twice, and a second showing turns the biggest moment in
  /// the app into a dialog.
  bool _verdictShown = false;

  /// Relationship arc: what she remembers about him + which stage they're
  /// at (1 Matched → 5 Together). Loaded on open, saved as it moves.
  String _memory = '';
  int _stage = 1;

  /// How hard SHE is to win over. >1 = every degree of warmth costs more;
  /// <1 = she warms faster. Keyed to the character so each girl feels
  /// distinct — the Ice Queen is a grind, the girl who's into you isn't.
  double get _difficulty => switch (widget.config.characterId) {
        'ice_queen' => 1.7, // selective, gives nothing
        'socialite' => 1.6, // ice → fire, earned across many turns
        'intellectual' => 1.45, // tests you constantly
        'chaos' => 1.2, // fun but a moving target
        'shy' => 0.95, // warm, but arrogance sets her back
        'into_you' => 0.8, // already leaning in
        _ => 1.2,
      };

  /// Where her interest sits before you've said anything.
  double get _startHeat => switch (widget.config.characterId) {
        'ice_queen' => 8,
        'socialite' => 10,
        'intellectual' => 14,
        'chaos' => 22,
        'shy' => 30,
        'into_you' => 40,
        _ => 20,
      };

  /// Move her interest for one turn. This is the GAME: warmth is earned
  /// slowly and the last stretch is the hardest.
  ///  • A good line gives less the warmer she already is (headroom curve),
  ///    so "closing" from 80→100 is a real grind, not two messages.
  ///  • Difficulty divides the gains — the Ice Queen barely budges.
  ///  • A bad line stings at closer to full value (loss aversion) and is
  ///    NOT softened by difficulty — you can always blow it.
  double _applyDelta(double heat, double delta) {
    double next;
    if (delta >= 0) {
      // Headroom shrinks as she warms; ^1.2 makes the top sticky, so the
      // "close" from 80→100 is a long grind, not two messages.
      final headroom = (1 - heat / 100).clamp(0.0, 1.0);
      var gain = delta * 1.5 * math.pow(headroom, 1.2).toDouble() / _difficulty;
      // A genuinely strong line (delta ≥ 8) always creeps her forward, so
      // a sustained flawless run can actually finish the close at 100.
      if (delta >= 8) gain = math.max(gain, 0.9 / _difficulty);
      next = heat + gain;
    } else {
      // Losses land hard and fast — one needy move should hurt, and
      // difficulty does NOT soften it. You can always blow it.
      next = heat + delta * 1.7;
    }
    return next.clamp(0.0, 100.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _heat = _startHeat;
    _peak = _heat;
    // Talking to her at all brings a Rolodex card back to full warmth.
    // Re-entry has to be the cheapest action in the app — a man who has
    // to work to undo a lapse simply doesn't.
    // ignore: discarded_futures
    Rolodex.touch(widget.config.characterId);
    // ignore: discarded_futures
    AnalyticsService.roleplayOpened(
      character: widget.config.characterId,
      mode: widget.config.post != null ? 'post' : 'practice',
    );
    // Practice mode: she opens. Post mode: the post IS the opener and she
    // waits for his comment, so no first bubble from her.
    if (widget.config.post == null) {
      _msgs.add(_Msg('her', widget.config.opener));
    }
    // ignore: discarded_futures
    CreatorModeStore.isActive().then((v) {
      if (mounted) setState(() => _creator = v);
    });
    // ignore: discarded_futures
    _loadProfile();
    // ignore: discarded_futures
    _loadMemory();
    // ignore: discarded_futures
    _takeHeadStart();
  }

  /// A HEAD START won on the wheel. Applied on open and announced —
  /// an invisible buff is not a reward, and a number that moved for
  /// reasons he can't account for makes the whole system feel arbitrary.
  Future<void> _takeHeadStart() async {
    if (!await BoonService.takeHeadStart()) return;
    if (!mounted) return;
    setState(() {
      _heat = (_heat + BoonService.headStartPoints).clamp(0, 100).toDouble();
      if (_heat > _peak) _peak = _heat;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'HEAD START · she opens ${BoonService.headStartPoints} warmer'),
      backgroundColor: AppColors.toastBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2600),
    ));
  }

  Future<void> _loadProfile() async {
    final name = await LocalStoreService.userName();
    final age = await LocalStoreService.userAgeGroup();
    if (!mounted) return;
    setState(() {
      _name = name;
      _ageGroup = age;
    });
  }

  /// Persist the arc after a turn — her warmth, stage and remembered note.
  Future<void> _persistArc() async {
    final id = widget.config.characterId;
    await LocalStoreService.setGirlInterest(id, _heat.round());
    await LocalStoreService.setGirlStage(id, _stage);
    if (_memory.isNotEmpty) await LocalStoreService.setGirlMemory(id, _memory);
  }

  void _showStageUp() {
    if (!mounted) return;
    final label = (_stage >= 1 && _stage < kRelationshipStages.length)
        ? kRelationshipStages[_stage]
        : '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.config.name} — $label 💘'),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2400),
    ));
  }

  /// Restore the arc: her remembered warmth, stage and note, so she picks
  /// up where you left off instead of resetting to a stranger.
  Future<void> _loadMemory() async {
    final id = widget.config.characterId;
    final interest = await LocalStoreService.girlInterest(id);
    final stage = await LocalStoreService.girlStage(id);
    final memory = await LocalStoreService.girlMemory(id);
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _memory = memory;
      // In practice mode, carry her real warmth in. Post mode always
      // opens cold (it's a fresh comment on a new post).
      if (widget.config.post == null && interest > 0) _heat = interest.toDouble();
      if (_heat > _peak) _peak = _heat;
    });
  }

  Map<String, dynamic>? get _profilePayload {
    if ((_name == null || _name!.isEmpty) &&
        (_ageGroup == null || _ageGroup!.isEmpty)) {
      return null;
    }
    return {
      if (_name != null && _name!.isNotEmpty) 'name': _name,
      if (_ageGroup != null && _ageGroup!.isNotEmpty) 'ageGroup': _ageGroup,
    };
  }

  @override
  void dispose() {
    _submitForScoring();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _submitted = false;

  /// Hand the conversation to the text grader on the way out.
  ///
  /// This is what turns a text mission from a flat +50 XP into a real
  /// number. Fire-and-forget and context-free, so it's safe from
  /// dispose(); the result parks in ChatScoreService.lastResult for
  /// whichever screen wants to show it.
  ///
  /// Only submits a conversation with something in it — three lines from
  /// you, minimum. Anything less isn't a performance to judge, and a
  /// board full of two-word attempts would be worthless.
  /// AWAITABLE ON PURPOSE. This used to be fire-and-forget from
  /// dispose(), which meant the grade was requested at the exact moment
  /// the screen popped — so the caller read ChatScoreService.lastResult
  /// a microsecond later and always found null. The chat challenge's
  /// reveal could never fire. _finishTask now awaits it BEFORE popping;
  /// dispose() still calls it as the backstop for men who leave early,
  /// and the _submitted guard means it can only ever run once.
  Future<void> _submitForScoring() {
    // Parked BEFORE the async body runs, so a caller that reads it on
    // the frame after this screen pops always finds the future — see
    // ChatScoreService.grading.
    final f = _submitInner();
    ChatScoreService.grading = f;
    return f;
  }

  Future<void> _submitInner() async {
    if (_submitted) return;
    _submitted = true;
    final mine = _msgs.where((m) => m.who == 'you').length;
    // SLOW BURN's evidence. Length is the one mirror axis that can only
    // be known once it's over, and this method is the single place both
    // exit paths converge on.
    // ignore: discarded_futures
    MirrorService.endConversation(mine);
    if (mine < 3) return;
    final transcript = [
      for (final m in _msgs)
        if (m.who == 'you' || m.who == 'her')
          '${m.who == 'you' ? 'YOU' : 'HER'}: ${m.text}',
    ].join('\n');

    // A battle transcript goes to the duel and nowhere else —
    // battle-action grades it, settles the fight AND records the chat
    // attempt, so also calling the solo grader would pay the man twice
    // for one conversation.
    // ── HAND THE REVEAL WHAT ONLY THIS SCREEN KNOWS ──────────────────
    // The worst line, and every tactic the conversation demonstrated.
    // Banked here rather than mid-chat: a card interrupting him at turn
    // four would be the app talking over the thing it's teaching.
    Coaching.lastWorstLine = _worstLine;
    if (_tacticsSeen.isNotEmpty) {
      final fresh = await Tactics.claim(_tacticsSeen, _bestLine.isEmpty
          ? _tacticsSeen.first
          : _bestLine);
      MilestoneService.pushTactics(fresh);
    }

    final battle = widget.config.battleId;
    if (battle != null) {
      await BattleService.submit(battle, transcript);
      return;
    }
    await ChatScoreService.score(
      transcript: transcript,
      surface: widget.config.scoreSurface,
      scenario: widget.config.name,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 260,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _openVoice() {
    HapticFeedback.mediumImpact();
    // ignore: discarded_futures
    AnalyticsService.roleplayVoiceHandoff(widget.config.characterId);
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      // Inherits the permission: hopping from a practice chat into
      // voice is still practice, and hopping out of a graded one is
      // still graded. The hop must never be a way round the rule.
      builder: (_) => FreeFlowScreen(
          initialVibeKey: widget.config.vibeKey,
          coachAllowed: widget.config.coachAllowed,
          // A task chat's woman was assigned, so the hop to voice must
          // not re-run the practice day-lock over her. A practice
          // chat's woman is already unlocked, so the flag is moot there.
          assigned: widget.config.taskMode),
    ));
  }

  /// Mission task finished — the verdict, then back to Missions (which
  /// auto-completes the mission on return).
  ///
  /// THIS USED TO BE A SCORE CARD: her face, a number out of 100, and a
  /// sentence of commentary. The number was the payout, and a number
  /// cannot hurt — which means it cannot thrill either, because the two
  /// run on the same circuit. So the payout is now her decision, and the
  /// number is a footnote on it. Same data, completely different organ.
  Future<void> _finishTask() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    // Fire the grade NOW and let it run under the reveal — by the time
    // he's watched her decide, the result is parked, so the caller's
    // squad reveal actually has something to show.
    final grading = _submitForScoring();

    final girl = girlById(widget.config.characterId);
    final v = Verdict.of(
      girl: girl,
      score: _heat.round(),
      peak: _peak.round(),
    );
    // If she folded mid-conversation we've already run the full
    // ceremony. Selling a man the same moment twice in ninety seconds is
    // how a jackpot becomes a dialog box, so the replay skips the wait
    // and goes straight to the outcome.
    final firstTime = !_verdictShown;
    _verdictShown = true;
    final fresh = v.band == VerdictBand.won && firstTime
        ? await Rolodex.win(
            girlId: girl.id, line: _bestLine, score: _heat.round())
        : false;
    // A NUMBER IS A CLOSE. It was banking a card and paying nothing —
    // the one outcome in the app that maps directly to the real thing
    // it's training, and it wasn't worth a single point.
    if (fresh) {
      await Rewards.number(girl.name);
      MilestoneService.pushTrophies(await Achievements.bump(Stat.numbers));
    }
    if (!mounted) return;
    // The daily challenge and battles close on their own full reveal.
    // The card is still banked above — he keeps the win, he just doesn't
    // watch two result screens in a row to get it.
    if (widget.config.verdictOnFinish) {
      await _showVerdict(girl, ceremony: firstTime, newCard: fresh);
      // THE ROLL rides on the back of the verdict rather than getting
      // its own trigger. He's just been told an outcome he couldn't
      // control; the wheel is the one moment in the app where he gets to
      // gamble on purpose, and it only ever gives. It cannot pay in
      // anything earned — see BoonService.
      if (mounted) {
        await TheRoll.show(context, accent: girl.accent);
      }
    }

    // Pop with TRUE — this is the only path that proves the task was
    // genuinely run, and Missions completes on that result alone. Every
    // other exit (back arrow, swipe) returns null and leaves the mission
    // open, which is the point: opening a chat is not doing it.
    await grading;
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    // ── THE FUNNEL — 10 free text messages, then the paywall ──────────────
    // A non-pro user gets kFreeTextMessages free sends with the AI women
    // (cheap-first: no RevenueCat call until the allowance is actually
    // spent). Once spent, the very next send opens the paywall instead of
    // texting her — they got in, they saw everything, they felt it, now
    // they pay. Pro + creator text unlimited. Voice is paid separately at
    // every _goLive. The user's typed line stays in the box so they don't
    // lose it if they come back as Pro.
    if (await PaywallGate.textCapReached()) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await PaywallGate.open(context, source: 'text_cap');
      // Came back still not pro → stop here (don't burn the send).
      if (!mounted || await PaywallGate.textCapReached()) return;
    }
    if (!await AiConsentDialog.ensure(context)) return;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _msgs.add(_Msg('you', text));
      _sending = true;
      _turnIndex++;
    });
    // ignore: discarded_futures
    AnalyticsService.roleplayMessageSent(
        character: widget.config.characterId, turn: _turnIndex);
    _ctrl.clear();
    _scrollToBottom();

    final result = await _turn(text);
    if (!mounted) return;
    if (result.error != null) {
      // Surface the REAL reason instead of a silent "…" so a broken
      // backend is obvious on-device (not deployed / no key / bad URL).
      setState(() {
        _sending = false;
        _msgs.add(_Msg('error', result.error!));
      });
      _scrollToBottom();
      return;
    }
    // Count this successful send toward the free text allowance (the funnel).
    // No-op weight for Pro/creator — textCapReached() ignores the counter
    // for them, so an over-count never matters; we just always tally.
    // ignore: discarded_futures
    LocalStoreService.markFreeTextUsed();
    // Real girls double-text. The model marks separate bubbles with '\n';
    // reveal them one at a time so it reads like she's firing off texts.
    final bubbles = result.her
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // THE MIRROR, fed before the heat moves. `heat` here is her interest
    // BEFORE this line, which is what makes THE CLOSER mean "strong
    // while she was already warm" rather than crediting him for the
    // line that warmed her.
    final girlTier = girlById(widget.config.characterId).tier;
    final wasStumble = _stumbled;
    // ignore: discarded_futures
    MirrorService.record(
      turnIndex: _turnIndex,
      delta: result.delta,
      heat: _heat,
      girlTier: girlTier,
      afterStumble: wasStumble,
    );
    _stumbled = result.delta < 0;

    setState(() {
      _sending = false;
      _heat = _applyDelta(_heat, result.delta);
      if (_heat > _peak) _peak = _heat;
      // The best line so far — captured now because the transcript alone
      // can't tell you which sentence did the work.
      if (result.delta > _bestDelta) {
        _bestDelta = result.delta;
        _bestLine = text;
      }
      // The other half. Only counted once the conversation is properly
      // under way — the opener is allowed to be clumsy and calling it
      // out would be the app kicking a man for starting.
      if (_turnIndex >= 2 && result.delta < _worstDelta) {
        _worstDelta = result.delta;
        _worstLine = text;
      }
      if (result.memory.isNotEmpty) _memory = result.memory;
      if (bubbles.isNotEmpty) _msgs.add(_Msg('her', bubbles.first));
    });
    // Win a stage when she's fully warmed to him (Matched → … → Together).
    if (_heat >= 92 && _stage < 5) {
      setState(() => _stage += 1);
      HapticFeedback.mediumImpact();
      _showStageUp();
    }
    // ignore: discarded_futures
    _persistArc();
    // MISSION TASK: once he's traded enough real lines, the task completes
    // and the score card slides up. Free Practice chats never trigger this.
    if (widget.config.taskMode &&
        !_taskDone &&
        _turnIndex >= widget.config.taskGoal) {
      _taskDone = true;
      // ignore: discarded_futures
      _finishTask();
    }
    // ── WHAT THAT LINE DEMONSTRATED ───────────────────────────────────
    // Local, instant, free. See tactics.dart for why detection is rules
    // rather than a server round-trip, and what that trade costs.
    // Everything older than the message he's replying to is fair game
    // for a callback.
    final reachBack = _herLines.length > 1
        ? _herLines.sublist(0, _herLines.length - 1)
        : const <String>[];
    for (final id in Tactics.detect(
      line: text,
      herEarlier: reachBack,
      hisPrevious: _hisPrevious,
      delta: result.delta,
    )) {
      if (!_tacticsSeen.contains(id)) _tacticsSeen.add(id);
    }
    _hisPrevious = text;
    if (bubbles.isNotEmpty) _herLines.add(bubbles.first);

    // A genuinely sharp line nudges The Five — practice moves your score.
    if (result.strong) {
      // ignore: discarded_futures
      LocalStoreService.bumpDimensions(const {'game': 1, 'humor': 1, 'listening': 1});
    }
    _scrollToBottom();
    if (result.strong) HapticFeedback.lightImpact();

    // ── PERFECT LINE ──────────────────────────────────────────────────
    // The only unscheduled reward in the app. He sent a sentence and
    // was waiting for her reply; instead the screen takes over and tells
    // him that sentence was perfect. Fires before her follow-up texts so
    // it genuinely interrupts rather than politely queueing behind them.
    //
    // Rare by construction: an exceptional grade AND once per
    // conversation AND once per day. A jackpot that pays twice in an
    // evening is a participation trophy and there's no way back from
    // that.
    if (result.strong &&
        result.delta >= PerfectLine.bar &&
        !_perfectShown &&
        await PerfectLine.availableToday()) {
      _perfectShown = true;
      if (!mounted) return;
      await PerfectLine.show(
        context,
        line: text,
        girlName: widget.config.name,
        accent: widget.config.accent,
      );
      if (!mounted) return;
    }

    for (var i = 1; i < bubbles.length; i++) {
      await Future.delayed(Duration(milliseconds: 650 + bubbles[i].length * 22));
      if (!mounted) return;
      setState(() => _msgs.add(_Msg('her', bubbles[i])));
      HapticFeedback.selectionClick();
      _scrollToBottom();
    }
    // SHE FOLDS THE INSTANT SHE FOLDS — not at the end of the session.
    //
    // An interrupt he didn't schedule is worth several times the same
    // event delivered onto a results screen he was already waiting for.
    // He's mid-conversation, she's just fired off two texts, and then
    // the typing indicator takes the screen and she gives him her
    // number. Nothing about that was predictable, which is the entire
    // reason it will stick.
    //
    // Last thing in the turn on purpose: her texts land first, so the
    // verdict reads as the conversation continuing rather than an
    // animation interrupting it.
    // ignore: discarded_futures
    _maybeWinHer();
  }

  /// Has she just crossed her bar? If so, run the ceremony once.
  ///
  /// The bar scales with her rarity (see [Rarity.bar]) — Daisy folds at
  /// 70, Seraphina at 90 — so the ICE cards are genuinely worth more
  /// than the common ones instead of being ten identical trophies with
  /// different faces on them.
  Future<void> _maybeWinHer() async {
    if (_verdictShown || !mounted) return;
    final girl = girlById(widget.config.characterId);
    if (_heat < rarityOf(girl).bar) return;
    _verdictShown = true; // set synchronously — nothing else may claim it
    final fresh = await Rolodex.win(
      girlId: girl.id,
      line: _bestLine,
      score: _heat.round(),
    );
    if (fresh) {
      await Rewards.number(girl.name);
      MilestoneService.pushTrophies(await Achievements.bump(Stat.numbers));
    }
    if (!mounted) return;
    await _showVerdict(girl, ceremony: true, newCard: fresh);
  }

  /// The verdict, full screen. Returns the action he chose, if any.
  Future<String?> _showVerdict(
    GirlBrief girl, {
    required bool ceremony,
    bool newCard = false,
  }) async {
    final action = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => VerdictAct(
          girl: girl,
          verdict: Verdict.of(
            girl: girl,
            score: _heat.round(),
            peak: _peak.round(),
          ),
          line: _bestLine,
          ceremony: ceremony,
          newCard: newCard,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (action == 'rolodex' && mounted) {
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RolodexScreen()));
    }
    return action;
  }

  Future<_TurnResult> _turn(String text) async {
    // Build history in the backend's shape: {who:'her'|'you', text}.
    final history = _msgs
        .where((m) => m.who == 'her' || m.who == 'you')
        .map((m) => {'who': m.who, 'text': m.text})
        .toList();
    // Drop the just-added user turn from history — it goes in `text`.
    if (history.isNotEmpty && history.last['who'] == 'you') {
      history.removeLast();
    }
    final base = AuralayDevFlags.apiBaseUrl;
    try {
      final res = await http
          .post(
            Uri.parse('$base/v1/date/turn'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'characterId': widget.config.characterId,
              // Her language. Voice has sent this since day one and the
              // text side never did — so a Spanish user got a Spanish-
              // speaking woman on calls and an English-only one in
              // texts. Same field name the realtime session config
              // uses; a server that predates it just ignores it.
              'language': LanguageService.cachedCode,
              'focus': widget.config.focus,
              'creator': _creator,
              'history': history,
              'text': text,
              'turnIndex': _turnIndex,
              'stage': _stage,
              if (_memory.isNotEmpty) 'memory': _memory,
              if (_profilePayload != null) 'userProfile': _profilePayload,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        final her = (b['her'] as String?)?.trim() ?? '';
        final delta = (b['delta'] as num?)?.toDouble() ?? 0.0;
        final strong = b['strong'] == true;
        final memory = (b['memory'] as String?)?.trim() ?? '';
        if (her.isNotEmpty && her != '…') {
          return _TurnResult(her: her, delta: delta, strong: strong, memory: memory);
        }
        // 200 but she gave nothing — the backend degraded its own reply,
        // almost always because OPENAI_API_KEY isn't set on the server.
        final be = (b['error'] as String?) ?? 'empty reply';
        return _TurnResult.err(
            'Reached the backend but got no reply ($be). Set OPENAI_API_KEY '
            'on the Railway backend.');
      }
      return _TurnResult.err(
          'Backend returned ${res.statusCode} for /v1/date/turn. Deploy the '
          'backend (it needs the /v1/date route) to $base.');
    } on TimeoutException {
      return _TurnResult.err('Timed out reaching $base/v1/date/turn.');
    } catch (e) {
      return _TurnResult.err('Couldn\'t reach $base/v1/date/turn — $e');
    }
  }

  // ── Lucien "Get Help" — on-demand rizz suggestion for the live convo ──
  Future<void> _getHelp() async {
    // Refuses even if something ever calls it directly. The UI hides
    // the bar; this makes the rule true rather than merely invisible.
    if (!widget.config.coachAllowed) return;
    if (_helping || _sending) return;
    if (!await AiConsentDialog.ensure(context)) return;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    // ignore: discarded_futures
    AnalyticsService.roleplayHelpTapped(widget.config.characterId);
    setState(() => _helping = true);
    _scrollToBottom();

    final history = _msgs
        .where((m) => m.who == 'her' || m.who == 'you')
        .map((m) => {'who': m.who, 'text': m.text})
        .toList();
    final base = AuralayDevFlags.apiBaseUrl;
    String? help;
    String? err;
    try {
      final res = await http
          .post(
            Uri.parse('$base/v1/date/help'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'characterId': widget.config.characterId,
              'creator': _creator,
              'history': history,
              if (_profilePayload != null) 'userProfile': _profilePayload,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        final h = (b['help'] as String?)?.trim() ?? '';
        if (h.isNotEmpty) {
          help = h;
        } else {
          err = 'Coach got no reply — set OPENAI_API_KEY on the backend.';
        }
      } else {
        err = 'Coach unavailable (${res.statusCode}).';
      }
    } catch (e) {
      err = 'Couldn\'t reach the coach — $e';
    }
    if (!mounted) return;
    setState(() {
      _helping = false;
      if (help != null) {
        _msgs.add(_Msg('lucien', help));
      } else {
        _msgs.add(_Msg('error', err ?? 'Coach unavailable.'));
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.config.post;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                config: widget.config,
                heat: _heat,
                onVoice: _openVoice,
                taskMode: widget.config.taskMode,
                taskProgress: (_turnIndex / widget.config.taskGoal)
                    .clamp(0.0, 1.0)
                    .toDouble(),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    if (post != null) ...[
                      _PostCard(config: widget.config, post: post),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('Drop a comment that makes her look twice',
                            style: GoogleFonts.inter(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                      const SizedBox(height: 14),
                    ],
                    for (var i = 0; i < _msgs.length; i++) ...[
                      _MsgView(msg: _msgs[i], config: widget.config),
                      const SizedBox(height: 12),
                    ],
                    if (_sending) const _TypingBubble(),
                    if (_helping) const _LucienThinking(),
                  ],
                ),
              ),
              // THE COACH, ONLY WHERE HE'S ALLOWED. Graded surfaces —
              // battles, the daily, AI missions — don't render this at
              // all. Not disabled, not greyed: absent. A dead button is
              // a promise the app can't keep and an invitation to keep
              // pressing it. See GirlChatConfig.coachAllowed.
              if (widget.config.coachAllowed)
                _HelpBar(busy: _helping || _sending, onTap: _getHelp),
              _InputBar(
                controller: _ctrl,
                sending: _sending,
                accent: widget.config.accent,
                hint: post != null
                    ? 'Type your comment…'
                    : 'Say something…',
                onSend: () => _send(_ctrl.text),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnResult {
  final String her;
  final double delta;
  final bool strong;
  final String memory; // her updated note about him (the arc/memory layer)
  final String? error; // set when the turn failed — shown on-device
  const _TurnResult({
    required this.her,
    required this.delta,
    required this.strong,
    this.memory = '',
    this.error,
  });

  const _TurnResult.err(String message)
      : her = '',
        delta = 0,
        strong = false,
        memory = '',
        error = message;
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER — portrait + name + interest meter + 📞 voice handoff
// ══════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final GirlChatConfig config;
  final double heat;
  final VoidCallback onVoice;
  final bool taskMode;
  final double taskProgress; // 0..1, mission task completion
  const _Header({
    required this.config,
    required this.heat,
    required this.onVoice,
    this.taskMode = false,
    this.taskProgress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [config.accent.withOpacity(0.18), AppColors.base],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: config.accent.withOpacity(0.75), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: config.accent.withOpacity(0.3), blurRadius: 12),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(config.portraitAsset, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface2,
                            child: Icon(Icons.person_rounded,
                                color: config.accent, size: 22),
                          )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.05,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.signalGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(config.archetype,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 📞 → take it live on voice
              Material(
                color: config.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onVoice,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: config.accent.withOpacity(0.5),
                            blurRadius: 14),
                      ],
                    ),
                    child: const Icon(Icons.call_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          // Mission task progress — fills as he trades real lines.
          if (taskMode) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Text('COMPLETE',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 8.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: taskProgress.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: AppColors.surface2,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.signalGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(taskProgress.clamp(0.0, 1.0) * 100).round()}%',
                      style: GoogleFonts.inter(
                        color: AppColors.signalGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Interest meter.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text('HER INTEREST',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 8.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (heat / 100).clamp(0.0, 1.0).toDouble(),
                      minHeight: 5,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation(config.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${heat.round()}',
                    style: GoogleFonts.inter(
                      color: config.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  POST CARD — "she just posted" scenario for comment-on-her-post
// ══════════════════════════════════════════════════════════════════════
class _PostCard extends StatelessWidget {
  final GirlChatConfig config;
  final GirlPost post;
  const _PostCard({required this.config, required this.post});

  @override
  Widget build(BuildContext context) {
    // Snapchat-style story reply: the WHOLE post shown as a small
    // portrait thumbnail on the left, the caption + context on the right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Small whole-image portrait — the full post, just shrunk.
        Container(
          width: 122,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: config.accent.withOpacity(0.5), width: 1.2),
            color: AppColors.surface2,
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Image.asset(config.portraitAsset, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: Icon(Icons.person_rounded,
                          color: config.accent, size: 32),
                    )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(post.context.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: config.accent,
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              // Her caption, in a story-reply bubble.
              Container(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(color: AppColors.surface3, width: 0.6),
                ),
                child: Text(post.caption,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, curve: Curves.easeOut);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  MESSAGES
// ══════════════════════════════════════════════════════════════════════
class _MsgView extends StatelessWidget {
  final _Msg msg;
  final GirlChatConfig config;
  const _MsgView({required this.msg, required this.config});

  @override
  Widget build(BuildContext context) {
    if (msg.who == 'lucien') return _LucienCard(text: msg.text);
    if (msg.who == 'error') return _ErrorNote(msg: msg);
    final isYou = msg.who == 'you';
    if (isYou) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(msg.text,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    )),
              ),
            ),
          ),
        ],
      );
    }
    // Her bubble — avatar + surface bubble on the left.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: config.accent.withOpacity(0.6), width: 1.2),
          ),
          child: ClipOval(
            child: Image.asset(config.portraitAsset, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: Icon(Icons.person_rounded,
                          color: config.accent, size: 14),
                    )),
          ),
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.surface3, width: 0.6),
              ),
              child: Text(msg.text,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  )),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lucien's on-demand rizz — the SAME brilliant-rizz voice as the Texts
/// tab, in a clean indigo card. Any "quoted line" pops out as a
/// tap-to-copy SEND THIS card underneath.
class _LucienCard extends StatelessWidget {
  final String text;
  const _LucienCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.45), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('YOUR COACH',
                  style: GoogleFonts.inter(
                    color: AppColors.accent,
                    fontSize: 10,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          if (text.trim().isNotEmpty)
            SelectableText(text,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                )),
          ..._copyLines(),
        ],
      ),
    );
  }

  List<Widget> _copyLines() {
    final out = <Widget>[];
    final matches = RegExp(r'"([^"\n]{6,160})"').allMatches(text);
    final seen = <String>{};
    for (final m in matches) {
      final line = (m.group(1) ?? '').trim();
      if (line.length < 6 || seen.contains(line)) continue;
      seen.add(line);
      out.add(const SizedBox(height: 8));
      out.add(_SendThisCard(line: line, accent: AppColors.red));
      if (out.length > 8) break;
    }
    return out;
  }
}

/// A tap-to-copy "SEND THIS" line — one of Lucien's suggested replies,
/// lifted out of his card so the user can drop it straight into the chat.
class _SendThisCard extends StatefulWidget {
  final String line;
  final Color accent;
  const _SendThisCard({required this.line, required this.accent});

  @override
  State<_SendThisCard> createState() => _SendThisCardState();
}

class _SendThisCardState extends State<_SendThisCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.line));
    if (!mounted) return;
    setState(() => _copied = true);
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: widget.accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withOpacity(0.45), width: 0.9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(widget.line,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              const SizedBox(width: 8),
              Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 15, color: widget.accent),
              const SizedBox(width: 3),
              Text(_copied ? 'COPIED' : 'SEND THIS',
                  style: GoogleFonts.inter(
                    color: widget.accent,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Get help from Lucien" pill above the input bar. Replaces the old
/// sporadic Bro cut-ins with on-demand help.
class _HelpBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _HelpBar({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(99),
                border:
                    Border.all(color: AppColors.accent.withOpacity(0.5), width: 0.9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14,
                      color: busy ? AppColors.textTertiary : AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Get help from your coach',
                      style: GoogleFonts.inter(
                        color: busy ? AppColors.textTertiary : AppColors.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LucienThinking extends StatelessWidget {
  const _LucienThinking();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Text('Your coach is thinking…',
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

/// Dev diagnostic bubble — shown when a turn fails so the real reason
/// (backend not deployed / no OPENAI_API_KEY / bad URL) is visible
/// on-device instead of a silent "…".
class _ErrorNote extends StatelessWidget {
  final _Msg msg;
  const _ErrorNote({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.5), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 15, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg.text,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppColors.surface3, width: 0.6),
          ),
          child: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.red),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Color accent;
  final String hint;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.accent,
    required this.hint,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.surface3, width: 0.6),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                maxLines: 1,
                cursorColor: accent,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: AppColors.red,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: sending ? null : onSend,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
