import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../models/character.dart';
import '../../models/metrics.dart';
import '../../models/mission.dart';
import '../../state/game_state.dart';
import '../../widgets/pickup_widgets.dart';
import 'roleplay_sim.dart';
import 'scene_result_sheet.dart';

/// THE hero screen. You chat the girl; Bro (the coach) cuts in mid-scene to
/// show what he'd have said and names the move — learn-as-you-go, no lessons.
///
/// Frontend-first: her replies + Bro's coaching come from RoleplaySim (local).
/// Swapping in backend2 `/v1/villain/scene/{open,turn,coach}` replaces the sim
/// without touching this widget.
class RoleplayChatScreen extends StatefulWidget {
  final Character character;
  final Mission? mission;
  const RoleplayChatScreen({super.key, required this.character, this.mission});

  @override
  State<RoleplayChatScreen> createState() => _RoleplayChatScreenState();
}

enum _Who { her, you, bro }

class _Line {
  final _Who who;
  final String text;
  final String? move; // Bro cut-ins name the technique
  final String? suggestion; // Bro's "what I'd have said"
  _Line(this.who, this.text, {this.move, this.suggestion});
}

class _RoleplayChatScreenState extends State<RoleplayChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lines = <_Line>[];
  late final RoleplaySim _sim;
  final _controller = TextEditingController();

  int _turns = 0;
  static const _maxTurns = 6;
  double _focusScore = 40; // the mission's scored metric, live
  bool _herTyping = false;

  Metric get _focus => widget.mission?.focus ?? Metric.game;

  @override
  void initState() {
    super.initState();
    _sim = RoleplaySim(widget.character, _focus);
    _lines.add(_Line(_Who.her, widget.character.opener));
  }

  @override
  void dispose() {
    _input.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _herTyping) return;
    _input.clear();

    final eval = _sim.evaluate(text);
    setState(() {
      _lines.add(_Line(_Who.you, text));
      _focusScore = (_focusScore + eval.delta).clamp(0, 100);
      // Bro cuts in when the move was weak (or every 3rd turn), teaching live.
      if (eval.coach != null) {
        _lines.add(_Line(_Who.bro, eval.coachNote!,
            move: eval.coach!.move, suggestion: eval.coach!.line));
      }
      _turns++;
      _herTyping = true;
    });
    _scrollDown();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _lines.add(_Line(_Who.her, _sim.herReply(text, eval)));
      _herTyping = false;
    });
    _scrollDown();

    if (_turns >= _maxTurns) _finish();
  }

  void _askBro() {
    final tip = _sim.hint(_lines.lastWhere((l) => l.who == _Who.her).text);
    setState(() {
      _lines.add(_Line(_Who.bro, tip.note, move: tip.move, suggestion: tip.line));
    });
    _scrollDown();
  }

  void _finish() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final g = context.read<GameState>();
      final gained = (widget.mission?.xp ?? 100);
      g.awardResult(
        gainedXp: gained,
        deltas: {_focus: (_focusScore - 40) * 0.25 + 4},
        completeMissionId: widget.mission?.id,
      );
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SceneResultSheet(
          character: widget.character,
          focus: _focus,
          focusScore: _focusScore,
          xp: gained,
        ),
      ).then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final accent = Color(c.accentValue);
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Column(
        children: [
          _HerHeader(character: c, focus: _focus, score: _focusScore),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md),
              itemCount: _lines.length + (_herTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _lines.length) return _TypingDots(accent: accent);
                return _Bubble(line: _lines[i], accent: accent, onUse: (s) {
                  _input.text = s;
                });
              },
            ),
          ),
          _InputBar(
            controller: _input,
            onSend: _send,
            onAskBro: _askBro,
            enabled: !_herTyping && _turns < _maxTurns,
          ),
        ],
      ),
    );
  }
}

// ── Her header: image, name, live focus meter ─────────────────────────────
class _HerHeader extends StatelessWidget {
  final Character character;
  final Metric focus;
  final double score;
  const _HerHeader(
      {required this.character, required this.focus, required this.score});

  @override
  Widget build(BuildContext context) {
    final accent = Color(character.accentValue);
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.surface3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.md, Sp.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.textSecondary),
                ),
                _Avatar(asset: character.asset, ring: accent, size: 42),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(character.name, style: AppTypography.h3),
                      Text(character.archetype,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                Pill('LIVE', color: AppColors.signalGreen, filled: true),
              ],
            ),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Text('${focus.glyph} ${focus.label.toUpperCase()}',
                  style: AppTypography.label.copyWith(color: accent)),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(children: [
                    Container(height: 3, color: AppColors.surface3),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      widthFactor: (score / 100).clamp(0, 1),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(color: accent, boxShadow: [
                          BoxShadow(color: accent.withOpacity(0.6), blurRadius: 6)
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Text(score.toStringAsFixed(0),
                  style: AppTypography.measurement.copyWith(color: accent)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String asset;
  final Color ring;
  final double size;
  const _Avatar({required this.asset, required this.ring, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 1.5),
          color: AppColors.surface2,
        ),
        child: ClipOval(
          child: Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
            return Center(
                child: Icon(Icons.person, color: ring, size: size * 0.5));
          }),
        ),
      );
}

// ── Chat bubbles (her / you / Bro coach card) ─────────────────────────────
class _Bubble extends StatelessWidget {
  final _Line line;
  final Color accent;
  final ValueChanged<String> onUse;
  const _Bubble({required this.line, required this.accent, required this.onUse});

  @override
  Widget build(BuildContext context) {
    if (line.who == _Who.bro) return _broCard(context);
    final mine = line.who == _Who.you;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 11),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: mine ? AppColors.accentDeep : AppColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Rd.lg),
            topRight: const Radius.circular(Rd.lg),
            bottomLeft: Radius.circular(mine ? Rd.lg : Rd.sm),
            bottomRight: Radius.circular(mine ? Rd.sm : Rd.lg),
          ),
        ),
        child: Text(line.text,
            style: AppTypography.body.copyWith(
                color: mine ? Colors.white : AppColors.textPrimary,
                height: 1.4)),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.15, curve: Curves.easeOut);
  }

  Widget _broCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Sp.sm),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('👊', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text('BRO', style: AppTypography.labelBold.copyWith(color: AppColors.accent)),
            const Spacer(),
            if (line.move != null) Pill(line.move!, color: AppColors.accent, filled: true),
          ]),
          const SizedBox(height: Sp.sm),
          Text(line.text, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          if (line.suggestion != null) ...[
            const SizedBox(height: Sp.sm),
            GestureDetector(
              onTap: () => onUse(line.suggestion!),
              child: Container(
                padding: const EdgeInsets.all(Sp.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.base,
                  borderRadius: BorderRadius.circular(Rd.md),
                  border: Border.all(color: AppColors.surface3),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text('"${line.suggestion!}"',
                        style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                            fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(width: Sp.sm),
                  Text('USE',
                      style: AppTypography.label.copyWith(color: AppColors.accent)),
                ]),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.96, curve: Curves.easeOut);
  }
}

class _TypingDots extends StatelessWidget {
  final Color accent;
  const _TypingDots({required this.accent});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(Rd.lg),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                    color: AppColors.textTertiary, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: (150 * i).ms, duration: 400.ms)
                  .then()
                  .fadeOut(duration: 400.ms),
          ]),
        ),
      );
}

// ── Input bar with Ask Bro ────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAskBro;
  final bool enabled;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAskBro,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md,
          MediaQuery.of(context).padding.bottom + Sp.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.surface3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: enabled ? onAskBro : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: Sp.sm),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Rd.sm),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('👊', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text('ASK BRO',
                      style: AppTypography.label
                          .copyWith(color: AppColors.accent, letterSpacing: 1.6)),
                ]),
              ),
            ),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled ? 'Say something…' : 'Scene complete',
                  hintStyle:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rd.xl),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Sp.sm),
            GestureDetector(
              onTap: enabled ? onSend : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.red : AppColors.surface3,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
