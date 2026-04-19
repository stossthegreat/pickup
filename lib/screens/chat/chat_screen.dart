import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/face_geometry.dart';
import '../../services/archetype_service.dart';
import '../../services/chat_service.dart';
import '../../services/scoring_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/fullscreen_image.dart';
import '../../widgets/common/quick_tryon_chips.dart';

/// Face-aware advisor chat. Text replies + inline Flux Kontext renders
/// showing the user with the suggested change applied.
///
/// `embedded=true` when used as a tab in the home hub — hides the back
/// button (tab nav replaces it) so it doesn't pop the entire home stack.
/// `imagePath` is the local scan image path used for identity-preserved tryon.
class ChatScreen extends StatefulWidget {
  final FaceGeometry geometry;
  final String? imagePath;
  final bool embedded;
  /// If provided, auto-sends this string as the first user turn on mount.
  /// Used when a QuickTryonChip is tapped on the report screen.
  final String? autoSend;

  const ChatScreen({
    super.key,
    required this.geometry,
    this.imagePath,
    this.embedded = false,
    this.autoSend,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scrollCtl = ScrollController();
  bool _sending = false;
  late final AestheticScore _score;
  late final ArchetypeMatch _match;

  @override
  void initState() {
    super.initState();
    _score = ScoringService.compute(widget.geometry);
    _match = ArchetypeService.bestMatch(widget.geometry);
    _messages.add(ChatMessage(ChatRole.assistant, _openingLine()));
    if (widget.autoSend != null && widget.autoSend!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _send(widget.autoSend!);
      });
    }
  }

  String _openingLine() {
    return "I've read your face. You scored ${_score.value} (${_score.tierLabel}), "
        "closest archetype ${_match.archetype.name} at ${(_match.match * 100).round()}%. "
        "Your strongest read: ${_score.strongestAxis.$1.toLowerCase()}. "
        "Your pulldown: ${_score.weakestAxis.$1.toLowerCase()}. "
        "Ask me what to do — haircut, beard, skin, glasses, surgery, whatever. "
        "I'll answer against your actual numbers and, when it helps, show you the change on your face.";
  }

  Future<void> _send([String? prefilled]) async {
    final text = (prefilled ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(ChatMessage(ChatRole.user, text));
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();

    final reply = await ChatService.send(
      history:   _messages,
      geometry:  widget.geometry,
      imagePath: widget.imagePath,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        ChatRole.assistant, reply.text,
        imageUrl:      reply.imageUrl,
        imageCaption:  reply.styleRequest,
      ));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtl,
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (c, i) {
                  if (i == _messages.length) return const _TypingIndicator();
                  final m = _messages[i];
                  return _MessageBubble(
                    message: m,
                    isFirst: i == 0 && m.role == ChatRole.assistant,
                  );
                },
              ),
            ),
            // Persistent smart-tryon chips — always visible above the input
            QuickTryonChips(
              geometry: widget.geometry,
              compact: true,
              onTap: (style, _) => _send(style),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
      child: Row(
        children: [
          if (!widget.embedded)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface1, shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
                ),
              ),
            ),
          if (!widget.embedded) const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Advisor',
                      style: AppTypography.h1.copyWith(
                        fontSize: 24, letterSpacing: -0.6, height: 1)),
                    const SizedBox(width: 8),
                    Container(
                      width: 4, height: 4, margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.gold, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('KNOWS YOUR BONES · ANSWERS FROM YOUR NUMBERS',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textMuted, fontSize: 8, letterSpacing: 2.6)),
              ],
            ),
          ),
          _scoreBadge(),
        ],
      ),
    );
  }

  Widget _scoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Text('${_score.value}',
            style: AppTypography.measurement.copyWith(
              color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text('/ 100',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary, fontSize: 8, letterSpacing: 1.4)),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.md, Sp.sm, Sp.md,
        MediaQuery.of(context).viewInsets.bottom > 0 ? Sp.sm : Sp.md,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.24), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about your face…',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sending ? null : () => _send(),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _sending
                      ? AppColors.surface3
                      : AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: _sending ? null : [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 12),
                    ],
                  ),
                  child: Icon(
                    _sending ? Icons.more_horiz : Icons.arrow_upward_rounded,
                    size: 18,
                    color: _sending ? AppColors.textTertiary : AppColors.base,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirst;
  const _MessageBubble({required this.message, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _avatarDot(),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface1,
                    borderRadius: BorderRadius.only(
                      topLeft:  Radius.circular(isUser ? 18 : 6),
                      topRight: Radius.circular(isUser ? 6 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    border: Border.all(
                      color: (isUser ? AppColors.accent : AppColors.gold)
                          .withValues(alpha: isFirst ? 0.4 : 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFirst)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('YOUR ANALYSIS',
                            style: AppTypography.label.copyWith(
                              color: AppColors.gold, letterSpacing: 2.4, fontSize: 8)),
                        ),
                      Text(message.content,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          height: 1.55)),
                    ],
                  ),
                ),
                // Inline Flux render attached to an assistant reply
                if (!isUser && message.imageUrl != null) ...[
                  const SizedBox(height: 10),
                  _InlineRender(
                    url:     message.imageUrl!,
                    caption: message.imageCaption),
                ],
              ],
            ).animate().fadeIn(duration: 260.ms).slideY(
              begin: 0.08, end: 0, duration: 260.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _avatarDot() {
    return Container(
      width: 28, height: 28, margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 0.8),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 13, color: AppColors.gold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Inline Flux render — shown under assistant messages when a tryon fired
// ═══════════════════════════════════════════════════════════════════════════
class _InlineRender extends StatelessWidget {
  final String url;
  final String? caption;
  const _InlineRender({required this.url, this.caption});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => FullscreenImage.open(context, url: url, caption: caption),
        borderRadius: BorderRadius.circular(Rd.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Rd.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.surface1)),
                  Image.network(url, fit: BoxFit.cover,
                    loadingBuilder: (_, child, p) => p == null ? child
                      : const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8, color: AppColors.gold))),
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image_rounded,
                        color: AppColors.textMuted, size: 24))),
                  // Caption pill
                  if (caption != null)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: Text(caption!,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.gold,
                            fontSize: 9, letterSpacing: 1.8)),
                      ),
                    ),
                  // Zoom hint
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                        size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 38),
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Opacity(
                opacity: _dotOpacity(i, _ac.value),
                child: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
                ),
              ),
              if (i < 2) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
  double _dotOpacity(int i, double t) {
    final phase = (t - i * 0.15) % 1.0;
    if (phase < 0.5) return 0.3 + phase * 1.4;
    return 1.0 - (phase - 0.5) * 1.4;
  }
}
