import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/ai_consent_dialog.dart';

/// Config that turns a real-world mission into a coached chat.
///
/// The header shows an AI-girl portrait + a task-specific banner (the
/// "specific thing at the top depending on the task"), and the coach is
/// seeded with an opening line + a hidden backend context so its replies
/// are about THIS mission from the first turn.
class MissionChatConfig {
  /// Mission title, shown as the header name (e.g. "Comment on her story").
  final String taskTitle;

  /// Small classified tier pill (e.g. "REAL · TEXTS").
  final String tier;

  /// XP reward, shown next to the tier (e.g. "150").
  final String xp;

  /// Portrait asset for the girl at the top of the screen.
  final String girlAsset;

  /// Accent colour for the header ring + chips.
  final Color accent;

  /// One-line situation under the title — sets the scene.
  final String situation;

  /// Coach's opening bubble (client-side seed, not sent to the model).
  final String opening;

  /// Task-specific quick-start chips the user can tap in the fresh state.
  final List<String> starters;

  /// Hidden preamble prepended to the FIRST user turn sent to the
  /// backend, so the coach knows exactly which mission it's helping with
  /// without the user having to explain. Never shown in a bubble.
  final String backendContext;

  const MissionChatConfig({
    required this.taskTitle,
    required this.tier,
    required this.xp,
    required this.girlAsset,
    required this.accent,
    required this.situation,
    required this.opening,
    required this.starters,
    required this.backendContext,
  });
}

class _Msg {
  final String role; // 'user' | 'assistant'
  final String text;
  final Uint8List? image;
  const _Msg(this.role, this.text, {this.image});
}

/// TASK CHAT — an elite, roleplay-app-styled coaching chat tied to one
/// real-world mission. Girl portrait + task banner up top; a clean
/// bubble thread below where the coach helps the user land the exact
/// line before they send it for real. Runs on the same /rizz/chat
/// endpoint the Texts tab uses, so no new backend wiring is needed.
class TaskChatScreen extends StatefulWidget {
  final MissionChatConfig config;
  const TaskChatScreen({super.key, required this.config});

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final List<_Msg> _msgs;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgs = [_Msg('assistant', widget.config.opening)];
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
        _scrollCtrl.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text, {Uint8List? image}) async {
    final msg = text.trim();
    if ((msg.isEmpty && image == null) || _sending) return;
    // AI consent gate (App Store 5.1.2(i)) — nothing reaches the model
    // without permission. Silent once granted.
    if (!await AiConsentDialog.ensure(context)) return;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _msgs.add(_Msg('user', msg.isEmpty ? '(screenshot)' : msg, image: image));
      _sending = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    final reply = await _ask(image: image);

    // Day-stamp the RIZZ CHAT mission + daily streak — a coached
    // exchange counts as showing up today (same key the Texts tab writes).
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(
          'rizz_chat_done_ymd', now.year * 10000 + now.month * 100 + now.day);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg('assistant', reply));
      _sending = false;
    });
    _scrollToBottom();
  }

  /// POST the thread to /rizz/chat. The FIRST user turn is silently
  /// enriched with [config.backendContext] so the coach is anchored to
  /// this mission; the visible bubbles stay clean. Same endpoint +
  /// payload shape as the Texts-tab coach, so it plugs straight in.
  Future<String> _ask({Uint8List? image}) async {
    final history = <Map<String, dynamic>>[];
    var injected = false;
    for (final m in _msgs) {
      if (m.role != 'user') continue;
      var content = m.text;
      if (!injected) {
        content = '${widget.config.backendContext}\n\n'
            'My message: $content';
        injected = true;
      }
      history.add({'role': 'user', 'content': content});
    }
    if (history.isEmpty) {
      history.add({'role': 'user', 'content': widget.config.backendContext});
    }

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.backendBaseUrl}/rizz/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': history,
              if (image != null) 'imageBase64': base64Encode(image),
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (body['reply'] as String?)?.trim() ?? '';
        if (reply.isNotEmpty) return reply;
      }
    } catch (_) {
      // fall through to the graceful fallback below
    }
    return 'Try that again — connection hiccup on my end.';
  }

  Future<void> _attach() async {
    HapticFeedback.selectionClick();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !mounted) return;
      await _send(_ctrl.text, image: bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Couldn\'t attach that photo — try again.',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _msgs.length == 1 && !_sending;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              _TaskHeader(config: widget.config),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  itemCount: _msgs.length + (_sending ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) return const _TypingBubble();
                    return _Bubble(msg: _msgs[i], accent: widget.config.accent);
                  },
                ),
              ),
              if (fresh) ...[
                _StarterStrip(
                  starters: widget.config.starters,
                  accent: widget.config.accent,
                  onPick: (s) => _send(s),
                ),
                const SizedBox(height: 8),
              ],
              _InputBar(
                controller: _ctrl,
                sending: _sending,
                accent: widget.config.accent,
                onSend: () => _send(_ctrl.text),
                onAttach: _attach,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER — the "ai girl at the top" + task-specific banner
// ══════════════════════════════════════════════════════════════════════
class _TaskHeader extends StatelessWidget {
  final MissionChatConfig config;
  const _TaskHeader({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            config.accent.withOpacity(0.16),
            AppColors.base,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 14),
      child: Column(
        children: [
          // Row 1 — back button + tier / xp on the right.
          Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: config.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: config.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(config.tier,
                        style: GoogleFonts.inter(
                          color: config.accent,
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(width: 6),
                    Icon(Icons.bolt_rounded, size: 11, color: config.accent),
                    Text('+${config.xp}',
                        style: GoogleFonts.inter(
                          color: config.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Row 2 — the girl + the task.
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: config.accent.withOpacity(0.7), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: config.accent.withOpacity(0.3), blurRadius: 14),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(config.girlAsset, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface2,
                            child: Icon(Icons.person_rounded,
                                color: config.accent, size: 28),
                          )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.signalGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('COACHING',
                            style: GoogleFonts.inter(
                              color: AppColors.signalGreen,
                              fontSize: 8.5,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(config.taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.1,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 3),
                    Text(config.situation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  BUBBLES — coach prose loose on the page, user in a red card, quoted
//  lines extracted into SEND THIS copy cards.
// ══════════════════════════════════════════════════════════════════════
class _Bubble extends StatelessWidget {
  final _Msg msg;
  final Color accent;
  const _Bubble({required this.msg, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    if (!isUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.text.trim().isNotEmpty)
            SelectableText(msg.text,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                )),
          ..._copyableLines(context),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (msg.image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: Image.memory(msg.image!, fit: BoxFit.contain),
                    ),
                  ),
                  if (msg.text != '(screenshot)') const SizedBox(height: 6),
                ],
                if (msg.text != '(screenshot)' || msg.image == null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.red.withValues(alpha: 0.3),
                            blurRadius: 16),
                      ],
                    ),
                    child: SelectableText(msg.text,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.42,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _copyableLines(BuildContext context) {
    final out = <Widget>[];
    final matches = RegExp(r'"([^"\n]{6,160})"').allMatches(msg.text);
    final seen = <String>{};
    for (final m in matches) {
      final line = (m.group(1) ?? '').trim();
      if (line.length < 6 || seen.contains(line)) continue;
      seen.add(line);
      out.add(const SizedBox(height: 8));
      out.add(_SendThisCard(line: line, accent: accent));
      if (out.length > 8) break;
    }
    return out;
  }
}

class _SendThisCard extends StatelessWidget {
  final String line;
  final Color accent;
  const _SendThisCard({required this.line, required this.accent});

  Future<void> _copy(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: line));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied. Send it for real.',
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copy(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.55), width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('"$line"',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    )),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded,
                        color: Colors.white, size: 11),
                    const SizedBox(width: 4),
                    Text('SEND THIS',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.3), blurRadius: 10),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.surface3, width: 0.6),
          ),
          child: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.8, color: AppColors.red),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  STARTER CHIPS + INPUT
// ══════════════════════════════════════════════════════════════════════
class _StarterStrip extends StatelessWidget {
  final List<String> starters;
  final Color accent;
  final ValueChanged<String> onPick;
  const _StarterStrip(
      {required this.starters, required this.accent, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final s in starters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  onTap: () => onPick(s),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: accent.withOpacity(0.4), width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Text(s,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Color accent;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.accent,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.surface3, width: 0.6),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAttach,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface3, width: 0.8),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white, size: 19),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                  hintText: 'Tell me the situation…',
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
