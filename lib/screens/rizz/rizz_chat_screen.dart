import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_colors.dart';

/// CHAT WITH MIRRORLY — a clean ask-anything chat with the rizz mentor.
/// Editorial bubbles: red for the user, dark surface for the assistant.
/// Backed by the existing /chat endpoint with mode=rizz_mentor; falls
/// back to a friendly error message when the backend is unreachable.
class RizzChatScreen extends StatefulWidget {
  const RizzChatScreen({super.key});

  @override
  State<RizzChatScreen> createState() => _RizzChatScreenState();
}

class _RizzMsg {
  final String role; // 'user' | 'assistant'
  final String text;
  const _RizzMsg(this.role, this.text);
}

class _RizzChatScreenState extends State<RizzChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_RizzMsg> _msgs = const <_RizzMsg>[
    _RizzMsg('assistant',
        'What\'s up. I\'m Mirrorly — your dating + self-improvement '
        'coach. Ask me anything: how to text her, how to ask her '
        'out, how to look better in photos. I\'ll give it to you '
        'straight.'),
  ].toList();
  bool _sending = false;

  static const _examples = <String>[
    'How do I get her to text back?',
    'What\'s the best way to ask her out?',
    'How do I level up my style?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    HapticFeedback.selectionClick();
    setState(() {
      _msgs.add(_RizzMsg('user', msg));
      _sending = true;
    });
    _ctrl.clear();
    _scrollToBottom();
    final reply = await _ask(msg);
    if (!mounted) return;
    setState(() {
      _msgs.add(_RizzMsg('assistant', reply));
      _sending = false;
    });
    _scrollToBottom();
  }

  Future<String> _ask(String text) async {
    final history = _msgs
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    history.add({'role': 'user', 'text': text});
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.backendBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': history,
              'face': const <String, dynamic>{},
              'mode': 'rizz_mentor',
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = (body['reply'] as String?)?.trim() ?? '';
        if (reply.isNotEmpty) return reply;
      }
    } catch (_) {/* fall through */}
    return 'Network glitch — couldn\'t reach the coach. Try again in a sec.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                itemCount: _msgs.length + (_sending ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == _msgs.length) {
                    return const _TypingBubble();
                  }
                  return _ChatBubble(msg: _msgs[i]);
                },
              ),
            ),
            // Example chips shown until the user has sent anything.
            if (_msgs.length == 1) ...[
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final e in _examples)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ExampleChip(
                          label: e,
                          onTap: () => _send(e),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            _InputBar(
              controller: _ctrl,
              sending: _sending,
              onSend: () => _send(_ctrl.text),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          ),
          const SizedBox(width: 4),
          Text('MIRRORLY',
            style: GoogleFonts.inter(
              color: AppColors.red,
              fontSize: 12, letterSpacing: 3.6,
              fontWeight: FontWeight.w800,
            )),
          const Spacer(),
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.red, size: 22),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _RizzMsg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isUser ? AppColors.red : AppColors.surface1,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(20),
                topRight:    const Radius.circular(20),
                bottomLeft:  Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: isUser
                  ? null
                  : Border.all(color: AppColors.surface3, width: 0.6),
              boxShadow: isUser
                  ? [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.28),
                        blurRadius: 16, spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Text(msg.text,
              style: GoogleFonts.inter(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 15, height: 1.4,
                fontWeight: FontWeight.w500,
              )),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(20),
              topRight:    Radius.circular(20),
              bottomLeft:  Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.surface3, width: 0.6),
          ),
          child: const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.0, color: AppColors.red),
          ),
        ),
      ],
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppColors.red.withValues(alpha: 0.4), width: 0.8),
          ),
          alignment: Alignment.center,
          child: Text(label,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 12.5, height: 1,
              fontWeight: FontWeight.w600,
            )),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
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
                cursorColor: AppColors.red,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15, height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask anything…',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 15, height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                  border:           InputBorder.none,
                  enabledBorder:    InputBorder.none,
                  focusedBorder:    InputBorder.none,
                  contentPadding:   const EdgeInsets.symmetric(vertical: 14),
                  isDense:          true,
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
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  child: sending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
