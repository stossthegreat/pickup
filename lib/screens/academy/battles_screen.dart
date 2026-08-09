import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backend/battle_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/academy_modal.dart';
import '../game/freeflow/free_flow_screen.dart';

/// RIZZ BATTLES — two men, the same AI woman, both play blind, higher
/// score takes the ELO. Two doors in: CHALLENGE A FRIEND (code) and
/// FIND AN OPPONENT (the line). The attempt itself is a normal Free
/// Flow session — the battle just claims its transcript.
class BattlesScreen extends StatefulWidget {
  const BattlesScreen({super.key});

  @override
  State<BattlesScreen> createState() => _BattlesScreenState();
}

class _BattlesScreenState extends State<BattlesScreen> {
  List<Battle> _battles = const [];
  Map<String, String> _handles = const {};
  bool _loading = true;
  bool _inLine = false;
  Timer? _poll;
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // Results arrive when the OTHER man finishes — poll while open so
    // a settled duel appears without the user doing anything.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _codeCtrl.dispose();
    if (_inLine) BattleService.leaveQueue(); // never strand a queue entry
    super.dispose();
  }

  Future<void> _load() async {
    final battles = await BattleService.myBattles();
    final handles = await BattleService.handles(battles);
    if (!mounted) return;
    setState(() {
      _battles = battles;
      _handles = handles;
      _loading = false;
    });
  }

  Future<void> _tick() async {
    if (!mounted) return;
    if (_inLine) {
      final battle = await BattleService.findOpponent();
      if (battle != null && mounted) {
        setState(() => _inLine = false);
        HapticFeedback.heavyImpact();
        _load();
        return;
      }
    }
    _load();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _challenge() async {
    HapticFeedback.mediumImpact();
    final battle = await BattleService.createChallenge();
    if (battle == null || !mounted) return;
    _load();
    AcademyModal.show(
      context,
      kicker: 'CHALLENGE MINTED',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(battle.scenarioLabel,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Same woman. Both blind. Higher score takes the ELO.',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),
          Center(
            child: Text(battle.inviteCode ?? '',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 40,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(height: 18),
          AcademyButton(
            label: 'SEND THE CHALLENGE',
            onTap: () {
              Share.share(
                  'I challenge you on ImHim Rizz — scenario "${battle.scenarioLabel}". '
                  'Same AI woman, both blind, higher score wins. '
                  'Code: ${battle.inviteCode}');
            },
          ),
          const SizedBox(height: 8),
          AcademyButton(
            label: 'RUN MY ATTEMPT NOW',
            ghost: true,
            onTap: () {
              Navigator.of(context).pop();
              _run(battle);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _findOpponent() async {
    HapticFeedback.mediumImpact();
    setState(() => _inLine = true);
    final battle = await BattleService.findOpponent();
    if (!mounted) return;
    if (battle != null) {
      setState(() => _inLine = false);
      HapticFeedback.heavyImpact();
      _load();
    }
    // else: stay in line; _tick polls until paired.
  }

  Future<void> _cancelLine() async {
    HapticFeedback.selectionClick();
    setState(() => _inLine = false);
    await BattleService.leaveQueue();
  }

  Future<void> _joinByCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) return;
    HapticFeedback.mediumImpact();
    final battle = await BattleService.joinChallenge(code);
    if (!mounted) return;
    if (battle == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Invalid code — or the duel is already claimed.',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.toastBg,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _codeCtrl.clear();
    FocusScope.of(context).unfocus();
    _load();
  }

  /// Launch the attempt: arm the battle, push Free Flow locked to the
  /// duel's scenario. Session end submits the transcript automatically.
  Future<void> _run(Battle b) async {
    HapticFeedback.heavyImpact();
    BattleService.armedBattleId = b.id;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => FreeFlowScreen(initialVibeKey: b.scenario),
    ));
    BattleService.armedBattleId = null; // safety if they bailed early
    _load();
  }

  void _shareResult(Battle b) {
    HapticFeedback.selectionClick();
    final vs = _handles[b.opponentId] ?? 'a rival';
    Share.share(b.iWon
        ? 'WON my Rizz Battle vs $vs — ${b.myScore} to ${b.theirScore} '
            'on "${b.scenarioLabel}". Who\'s next?'
        : 'Rizz Battle vs $vs: ${b.myScore} to ${b.theirScore} on '
            '"${b.scenarioLabel}". Running it back.');
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 20, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
              Text('BATTLES',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('Same woman. Both blind.\nHigher score takes the ELO.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 18),

                // ── The two doors ─────────────────────────────────────
                if (_inLine)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.red)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('IN THE LINE — waiting for a stranger…',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                      GestureDetector(
                        onTap: _cancelLine,
                        child: Text('CANCEL',
                            style: GoogleFonts.inter(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 250.ms)
                else ...[
                  AcademyButton(
                      label: 'FIND AN OPPONENT', onTap: _findOpponent),
                  const SizedBox(height: 10),
                  AcademyButton(
                      label: 'CHALLENGE A FRIEND',
                      ghost: true,
                      onTap: _challenge),
                ],
                const SizedBox(height: 14),

                // ── Got a code? ───────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'GOT A CODE?',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                        filled: true,
                        fillColor: AppColors.surface1,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _joinByCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface2,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ENTER',
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── My battles ────────────────────────────────────────
                if (_loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.red)),
                  ))
                else if (_battles.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text('No duels yet. Someone has to be first.',
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  )
                else
                  for (final b in _battles)
                    _BattleCard(
                      battle: b,
                      opponent: _handles[b.opponentId],
                      onRun: () => _run(b),
                      onShare: () => _shareResult(b),
                    ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _BattleCard extends StatelessWidget {
  final Battle battle;
  final String? opponent;
  final VoidCallback onRun;
  final VoidCallback onShare;
  const _BattleCard(
      {required this.battle,
      required this.opponent,
      required this.onRun,
      required this.onShare});

  @override
  Widget build(BuildContext context) {
    final b = battle;
    final vs = opponent ?? (b.opponentId == null ? 'AWAITING RIVAL' : 'ANON');

    final Color edge;
    final Widget status;
    if (b.settled) {
      final (label, color) = b.tie
          ? ('DRAW', AppColors.textSecondary)
          : b.iWon
              ? ('VICTORY', const Color(0xFF2EE87A))
              : ('DEFEAT', AppColors.red);
      edge = color.withValues(alpha: 0.5);
      status = Row(children: [
        Text(label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 15,
              letterSpacing: 2.6,
              fontWeight: FontWeight.w900,
              shadows: b.iWon
                  ? [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 16)]
                  : null,
            )),
        const Spacer(),
        Text('${b.myScore ?? '—'}  ·  ${b.theirScore ?? '—'}',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onShare,
          child: const Icon(Icons.ios_share_rounded,
              size: 17, color: AppColors.textSecondary),
        ),
      ]);
    } else if (b.iSubmitted) {
      edge = Colors.white.withValues(alpha: 0.08);
      status = Text(
        'YOUR ${b.myScore} IS LOCKED IN — WAITING FOR THEM',
        style: GoogleFonts.inter(
          color: AppColors.textTertiary,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      );
    } else {
      edge = AppColors.red.withValues(alpha: 0.45);
      status = SizedBox(
        height: 46,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onRun,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13)),
          ),
          child: Text('RUN YOUR ATTEMPT',
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: edge),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(b.scenarioLabel,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 10.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w800,
              )),
          const Spacer(),
          if (b.inviteCode != null && b.state == 'open')
            Text(b.inviteCode!,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                )),
        ]),
        const SizedBox(height: 4),
        Text('VS ${vs.toUpperCase()}',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 12),
        status,
      ]),
    );
  }
}
