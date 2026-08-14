import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/battle_service.dart';
import '../../services/backend/tiers.dart';
import '../../services/roster.dart';
import '../../services/economy.dart';
import '../../services/share_service.dart';
import '../../widgets/share/rizz_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/daily_card.dart' show girlForVibe;
import '../../widgets/academy/game_button.dart';
import '../../widgets/academy/rizz_off_reveal.dart';
import '../roleplay/girl_chat_screen.dart';

/// RIZZ BATTLES — two men, the same woman, both blind. Higher score
/// takes the ELO. Every duel is a card with her face on it; every
/// result is a verdict, not a row.
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
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _codeCtrl.dispose();
    if (_inLine) BattleService.leaveQueue();
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
    final girl = girlForVibe(battle.scenario);
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      barrierLabel: 'challenge',
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, _, __) => Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Portrait(girl: girl, size: 110, ring: girl.accent),
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
              Text('Same woman. Both blind. Higher AI Score takes the ${Economy.rrShort}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.55)),
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
                    Navigator.of(context).pop();
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

  /// BATTLES ARE TEXT NOW, not voice.
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
  /// It also gives the ladder a shop window: you meet her here first and
  /// then you want to earn her properly.
  Future<void> _run(Battle b) async {
    HapticFeedback.heavyImpact();
    final girl = girlForVibe(b.scenario);
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
            // The duel closes on its own reveal against the other man.
            verdictOnFinish: false,
          ),
        ),
      ),
    );
    if (!mounted) return;

    // THE DUEL GETS THE SAME MOMENT AS THE DAILY. It used to hand the
    // number back on a list row — the one event in the app with a named
    // opponent, and it landed quieter than a solo practice run. Same
    // count-up, same axes, same grade slam.
    final r = BattleService.lastResult;
    if (r != null) {
      BattleService.lastResult = null;
      final girl = girlForVibe(b.scenario);
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
    }
    if (mounted) _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 20, 4),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
              ),
              Text('BATTLES',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  )),
              const Spacer(),
              const Icon(Icons.sports_mma_rounded,
                  size: 20, color: AppColors.red),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface1,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                children: [
                  Text('SAME WOMAN.\nBOTH BLIND.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.05,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text('Higher AI Score takes the RR.',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 13,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 20),

                  if (_inLine)
                    _lineCard()
                  else ...[
                    GameButton(
                        label: 'FIND AN OPPONENT',
                        icon: Icons.radar_rounded,
                        pulse: true,
                        onTap: _findOpponent),
                    const SizedBox(height: 11),
                    GameButton(
                        label: 'CHALLENGE A FRIEND',
                        color: AppColors.surface2,
                        icon: Icons.link_rounded,
                        onTap: _challenge),
                  ],
                  const SizedBox(height: 14),
                  _codeRow(),
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
                    ))
                  else if (_battles.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Text('No duels yet. Someone has to be first.',
                            style: GoogleFonts.inter(
                              color: AppColors.textTertiary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    )
                  else
                    for (final (i, b) in _battles.indexed)
                      _BattleCard(
                        battle: b,
                        opponent: _handles[b.opponentId],
                        onRun: () => _run(b),
                        onShare: () => _shareResult(b),
                      ).animate().fadeIn(
                          delay: (60 * i).clamp(0, 400).ms,
                          duration: 280.ms),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _lineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.55)),
        boxShadow: const [BoxShadow(color: AppColors.redGlow, blurRadius: 26)],
      ),
      child: Row(children: [
        // Pulsing radar dot — someone is out there.
        SizedBox(
          width: 34,
          height: 34,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.5)),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(begin: 0.5, end: 1.25, duration: 1500.ms)
                .fadeOut(duration: 1500.ms),
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                  color: AppColors.red, shape: BoxShape.circle),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IN THE LINE',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  )),
              Text('Waiting for a stranger…',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        GestureDetector(
          onTap: _cancelLine,
          child: Text('CANCEL',
              style: GoogleFonts.inter(
                color: AppColors.textTertiary,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              )),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _codeRow() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 6,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            hintText: 'GOT A CODE?',
            hintStyle: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: AppColors.surface1,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.red, width: 1.6),
            ),
          ),
        ),
      ),
      const SizedBox(width: 9),
      SizedBox(
        width: 92,
        child: GameButton(
          label: 'ENTER',
          height: 50,
          color: AppColors.surface2,
          onTap: _joinByCode,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  BATTLE CARD — her face, the VS, the verdict
// ══════════════════════════════════════════════════════════════════════

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
    final girl = girlForVibe(b.scenario);
    final vs = opponent ?? (b.opponentId == null ? 'AWAITING RIVAL' : 'ANON');

    final Color edge;
    if (b.settled) {
      edge = b.tie
          ? AppColors.textSecondary
          : b.iWon
              ? kNeon
              : AppColors.red;
    } else if (b.iSubmitted) {
      edge = Colors.white.withValues(alpha: 0.10);
    } else {
      edge = girl.accent.withValues(alpha: 0.6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge, width: 1.4),
        boxShadow: b.settled && b.iWon
            ? [BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 24)]
            : null,
      ),
      child: Column(children: [
        // Her strip — the woman both men face.
        SizedBox(
          height: 92,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(
              girl.asset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.36),
              errorBuilder: (_, __, ___) => ColoredBox(
                  color: girl.accent.withValues(alpha: 0.22)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
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
                      letterSpacing: -0.3,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
              ]),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Column(children: [
            // VS row
            Row(children: [
              Expanded(
                child: _side(
                  name: 'YOU',
                  score: b.myScore,
                  color: b.settled && b.iWon ? kNeon : Colors.white,
                ),
              ),
              Text('VS',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  )),
              Expanded(
                child: _side(
                  name: vs.toUpperCase(),
                  score: b.theirScore,
                  color: b.settled && !b.iWon && !b.tie
                      ? AppColors.red
                      : Colors.white,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (b.settled)
              _verdict(b)
            else if (b.iSubmitted)
              Text('YOUR ${battleScore(b.myScore)} IS LOCKED IN — '
                  'WAITING FOR HIM',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ))
            else
              GameButton(
                  label: 'RUN YOUR ATTEMPT',
                  color: girl.accent,
                  height: 50,
                  onTap: onRun),
          ]),
        ),
      ]),
    );
  }

  Widget _side({required String name, int? score, required Color color}) {
    return Column(children: [
      Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          )),
      const SizedBox(height: 3),
      Text(battleScore(score),
          style: GoogleFonts.inter(
            color: color,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w900,
            shadows: color == kNeon
                ? [Shadow(color: kNeon.withValues(alpha: 0.5), blurRadius: 18)]
                : null,
          )),
    ]);
  }

  Widget _verdict(Battle b) {
    final (label, color) = b.tie
        ? ('DRAW', AppColors.textSecondary)
        : b.iWon
            ? ('VICTORY', kNeon)
            : ('DEFEAT', AppColors.red);
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 14,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
                shadows: b.iWon
                    ? [
                        Shadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 16)
                      ]
                    : null,
              )),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onShare,
        child: Container(
          width: 44,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.ios_share_rounded,
              size: 17, color: AppColors.textSecondary),
        ),
      ),
    ]);
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

/// BATTLE SCORES READ OUT OF 100 NOW.
///
/// The grader stores full resolution server-side (five axes weighted into
/// 0..1, then x99.99 → 0..9999) and that number was going straight onto
/// the card. It looked like an arcade score and, worse, it disagreed with
/// every other text number in the app: the chat challenge and the Rizz
/// Points board both speak out of 100. A man who scores 82 in a duel and
/// 82 on the daily should see the same number twice.
String battleScore(int? raw) =>
    raw == null ? '—' : '${Economy.aiScoreFromVoice(raw)}';
