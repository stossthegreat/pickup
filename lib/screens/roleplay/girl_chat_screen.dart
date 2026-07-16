import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/auralay_dev_flags.dart';
import '../../services/creator_mode_store.dart';
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
  final String who; // 'her' | 'you' | 'coach'
  final String text;
  final String? coachMove; // when who == 'coach'
  const _Msg(this.who, this.text, {this.coachMove});
}

/// GIRL CHAT — texting roleplay with an AI girl. She replies in
/// character; a coach cut-in lands every few turns; her interest meter
/// moves with every line. Tap the 📞 to take it live on voice.
///
/// Runs on POST /v1/date/turn (unified backend). Backend-down degrades
/// to a graceful in-character beat so the screen is always demoable.
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
  bool _creator = false;
  int _turnIndex = 0;

  /// Her interest, 0–100. Starts guarded, moves with each turn's delta.
  double _heat = 32;

  @override
  void initState() {
    super.initState();
    // Practice mode: she opens. Post mode: the post IS the opener and she
    // waits for his comment, so no first bubble from her.
    if (widget.config.post == null) {
      _msgs.add(_Msg('her', widget.config.opener));
    }
    // ignore: discarded_futures
    CreatorModeStore.isActive().then((v) {
      if (mounted) setState(() => _creator = v);
    });
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
    _ctrl.clear();
    _scrollToBottom();

    final result = await _turn(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.her.isNotEmpty) _msgs.add(_Msg('her', result.her));
      if (result.coach != null) {
        _msgs.add(_Msg('coach', result.coach!.$2, coachMove: result.coach!.$1));
      }
      _heat = (_heat + result.delta * 3).clamp(0.0, 100.0).toDouble();
    });
    if (result.strong) HapticFeedback.lightImpact();
    _scrollToBottom();
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
    try {
      final res = await http
          .post(
            Uri.parse('${AuralayDevFlags.apiBaseUrl}/v1/date/turn'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'characterId': widget.config.characterId,
              'focus': widget.config.focus,
              'creator': _creator,
              'history': history,
              'text': text,
              'turnIndex': _turnIndex,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        final her = (b['her'] as String?)?.trim() ?? '';
        final delta = (b['delta'] as num?)?.toDouble() ?? 0.0;
        final strong = b['strong'] == true;
        (String, String)? coach;
        final c = b['coach'];
        if (c is Map && (c['line'] != null || c['move'] != null)) {
          coach = (
            (c['move'] as String?)?.trim().isNotEmpty == true
                ? (c['move'] as String).trim()
                : 'THE MOVE',
            (c['line'] as String?)?.trim() ?? '',
          );
        }
        if (her.isNotEmpty && her != '…') {
          return _TurnResult(her: her, delta: delta, strong: strong, coach: coach);
        }
      }
    } catch (_) {
      // fall through to the graceful beat below
    }
    // Backend not live yet / hiccup — keep the scene alive with a soft
    // in-character beat instead of an error. The UI stays fully demoable.
    return const _TurnResult(her: '…', delta: 0, strong: false, coach: null);
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
                  ],
                ),
              ),
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
  final (String, String)? coach; // (move, line)
  const _TurnResult({
    required this.her,
    required this.delta,
    required this.strong,
    required this.coach,
  });
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: config.accent.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(config.portraitAsset, fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.surface2)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(post.context.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 8.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(post.caption,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ],
      ),
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
    if (msg.who == 'coach') return _CoachNote(msg: msg);
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

/// Bro's coach cut-in — a distinct, tighter note so it never reads as
/// the girl talking.
class _CoachNote extends StatelessWidget {
  final _Msg msg;
  const _CoachNote({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 5),
              Text('BRO · ${(msg.coachMove ?? 'THE MOVE').toUpperCase()}',
                  style: GoogleFonts.inter(
                    color: AppColors.accent,
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(msg.text,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              )),
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
