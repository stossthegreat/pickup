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
import '../../services/local_store_service.dart';
import '../../services/roster.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/ai_consent_dialog.dart';
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

  // Fed to the AI so she uses his name + pitches to his age band.
  String? _name;
  String? _ageGroup;

  /// Her interest, 0–100. Starts guarded, moves with each turn's delta.
  /// Set per-character in initState — cold girls start lower. Persisted
  /// per girl so warmth carries between sessions (the memory layer).
  double _heat = 20;

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
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
      builder: (_) => FreeFlowScreen(initialVibeKey: widget.config.vibeKey),
    ));
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
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
    // Real girls double-text. The model marks separate bubbles with '\n';
    // reveal them one at a time so it reads like she's firing off texts.
    final bubbles = result.her
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    setState(() {
      _sending = false;
      _heat = _applyDelta(_heat, result.delta);
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
    // A genuinely sharp line nudges The Five — practice moves your score.
    if (result.strong) {
      // ignore: discarded_futures
      LocalStoreService.bumpDimensions(const {'game': 1, 'humor': 1, 'listening': 1});
    }
    _scrollToBottom();
    if (result.strong) HapticFeedback.lightImpact();
    for (var i = 1; i < bubbles.length; i++) {
      await Future.delayed(Duration(milliseconds: 650 + bubbles[i].length * 22));
      if (!mounted) return;
      setState(() => _msgs.add(_Msg('her', bubbles[i])));
      HapticFeedback.selectionClick();
      _scrollToBottom();
    }
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
          err = 'Lucien got no reply — set OPENAI_API_KEY on the backend.';
        }
      } else {
        err = 'Lucien unavailable (${res.statusCode}).';
      }
    } catch (e) {
      err = 'Couldn\'t reach Lucien — $e';
    }
    if (!mounted) return;
    setState(() {
      _helping = false;
      if (help != null) {
        _msgs.add(_Msg('lucien', help));
      } else {
        _msgs.add(_Msg('error', err ?? 'Lucien unavailable.'));
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
                              fontStyle: FontStyle.italic,
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
              // Lucien "Get Help" bar — on-demand rizz, no sporadic cut-ins.
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
  const _Header({required this.config, required this.heat, required this.onVoice});

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
              Text('LUCIEN',
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
                  Text('Get help from Lucien',
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
          Text('Lucien\'s thinking…',
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
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
