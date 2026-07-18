import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/analytics_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/common/imhim_wordmark.dart';
import '../../widgets/common/streak_badge.dart';
import '../game/freeflow/free_flow_screen.dart';
import '../roleplay/girl_chat_screen.dart';
import 'task_chat_screen.dart';

/// MISSIONS — the front door. Beautiful, clean cards. Four kinds:
///   • Voice   — "Talk to her" → opens her realtime VOICE orb.
///   • AI text — "Comment on her post" → opens the girl roleplay chat
///               (rizz the AI girl on her post; 📞 to go live).
///   • Texts   — real-world messaging (comment on a real girl's story,
///               DM your crush) → opens the coach with the scenario as
///               the opening message, to use BEFORE the real task.
///   • Approach — real-world in-person → routes to the Practice tab.
class MissionsTabScreen extends StatelessWidget {
  final ValueChanged<int> onGoToTab; // 1 = Practice, 2 = Texts
  const MissionsTabScreen({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TopBar()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
              child: _Heading(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, 120),
            sliver: SliverList.builder(
              itemCount: _seed.length,
              itemBuilder: (context, i) {
                final m = _seed[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm + 4),
                  child: _MissionCard(
                    mission: m,
                    onTap: () => _launch(context, m),
                  )
                      .animate()
                      .fadeIn(delay: (70 * i).ms, duration: 340.ms)
                      .slideY(begin: 0.07, curve: Curves.easeOut),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _launch(BuildContext context, _Mission m) {
    // ignore: discarded_futures
    AnalyticsService.missionOpened(kind: m.kind.name, title: m.title);
    switch (m.kind) {
      case _Kind.voice:
        // AI · VOICE → straight onto the realtime voice orb for her.
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => FreeFlowScreen(initialVibeKey: m.vibeKey),
        ));
      case _Kind.aiText:
        // AI · TEXT → the girl roleplay chat, scenario (her post) ready.
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => GirlChatScreen(config: m.girl!),
        ));
      case _Kind.texts:
        // REAL · TEXTS → the coach, with the scenario as the opening
        // message, so the user warms up here BEFORE doing it for real.
        // Missions without a chat config fall back to the Texts tab.
        if (m.chat != null) {
          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => TaskChatScreen(config: m.chat!),
          ));
        } else {
          onGoToTab(2);
        }
      case _Kind.approach:
        onGoToTab(1);
    }
  }
}

// ── Data ────────────────────────────────────────────────────────────────
enum _Kind { voice, aiText, texts, approach }

class _Mission {
  final _Kind kind;
  final String title, sub, tier, xp;
  final String? asset; // AI missions show her render
  /// VOICE missions → realtime persona key for [FreeFlowScreen].
  final String? vibeKey;
  /// REAL · TEXTS missions carry a coached-chat config; tapping opens
  /// [TaskChatScreen] with the scenario as the opening message.
  final MissionChatConfig? chat;
  /// AI · TEXT missions carry a girl roleplay config (scenario = her post).
  final GirlChatConfig? girl;
  const _Mission(this.kind, this.title, this.sub, this.tier, this.xp,
      {this.asset, this.vibeKey, this.chat, this.girl});
}

const _seed = <_Mission>[
  _Mission(_Kind.voice, 'Talk to the Ice Queen',
      'She gives nothing for free. Warm her up on voice.', 'AI · VOICE', '80',
      asset: 'assets/characters/women/ice_queen.png', vibeKey: 'cold'),
  _Mission(_Kind.aiText, 'Comment on Nyx\'s story',
      'She just posted. Rizz your way into her DMs.', 'AI · TEXT', '90',
      asset: 'assets/characters/women/chaos_girl.png', girl: _postNyx),
  _Mission(_Kind.texts, 'Comment on her story',
      'Someone you like posted. One line that makes her reply.', 'REAL · TEXTS', '150',
      chat: _commentOnStoryChat),
  _Mission(_Kind.approach, 'Approach one girl today',
      'When you\'re out. Twenty seconds. Practice on voice first.', 'REAL · APPROACH', '350'),
  _Mission(_Kind.aiText, 'Slide onto Camila\'s post',
      'The hot girl who knows it. Say something she hasn\'t heard.', 'AI · TEXT', '110',
      asset: 'assets/characters/women/socialite.png', girl: _postCamila),
  _Mission(_Kind.texts, 'Message your crush',
      'Open the chat you keep re-reading. Send something real.', 'REAL · TEXTS', '200',
      chat: _messageCrushChat),
  _Mission(_Kind.voice, 'Make the Chaos Girl laugh',
      'Match her tempo. Four lines to a real laugh.', 'AI · VOICE', '120',
      asset: 'assets/characters/women/chaos_girl.png', vibeKey: 'chaos'),
  _Mission(_Kind.texts, 'Reopen a dead conversation',
      'One that went cold. Revive it without "hey".', 'REAL · TEXTS', '180',
      chat: _reopenDeadChat),
];

// ── AI-girl POST roleplay configs (comment-on-her-post missions) ──────────
// The scenario (her post) is ready at the top; the user rizzes her and she
// replies in character via /v1/date. 📞 in the header takes it live on voice.

const _postNyx = GirlChatConfig(
  characterId: 'chaos',
  vibeKey: 'chaos',
  name: 'Nyx',
  archetype: 'The Chaos Girl — wild, fast, unpredictable',
  portraitAsset: 'assets/characters/women/chaos_girl.png',
  accent: Color(0xFFE8222A),
  opener: 'you look like a bad decision. i love bad decisions.',
  post: GirlPost(
    context: 'Posted a story · 2 min ago',
    caption: '3am energy and nowhere to be. who\'s still up 👀',
  ),
);

const _postCamila = GirlChatConfig(
  characterId: 'socialite',
  vibeKey: 'ice_then_fire',
  name: 'Camila',
  archetype: 'The Hot Girl — knows exactly what she is',
  portraitAsset: 'assets/characters/women/socialite.png',
  accent: Color(0xFFFBBF24),
  opener: 'everyone here wants something from me. what do you want?',
  post: GirlPost(
    context: 'Posted a photo · just now',
    caption: 'don\'t ask for my number.',
  ),
);

// ── Coached-chat configs for the REAL · TEXTS missions ────────────────────
// Each pairs an AI-girl portrait + task banner with a seeded opener and a
// hidden backend context so the coach is on-mission from the first turn.
// All run on the same /rizz/chat endpoint the Texts tab uses.

const _commentOnStoryChat = MissionChatConfig(
  taskTitle: 'Comment on her story',
  tier: 'REAL · TEXTS',
  xp: '150',
  girlAsset: 'assets/characters/women/socialite.png',
  accent: AppColors.red,
  situation: 'She just posted. One comment that pulls a reply — not a 🔥.',
  opening:
      'She posted a story — that\'s an open door, not a dead end.\n\n'
      'Tell me what it showed — a gym mirror pic, a sunset, her dog, a '
      'night out — or paste a screenshot, and I\'ll hand you ONE comment '
      'that actually gets a reply. No "nice pic." No fire emoji. Something '
      'she has to answer.',
  starters: [
    'She posted a gym pic',
    'A night out with friends',
    'Her on holiday',
    'Just a selfie',
  ],
  backendContext:
      'You are my dating text coach. Real-world mission: COMMENT ON HER '
      'STORY. A girl I\'m into just posted a story or photo on Instagram '
      'or Snapchat. I want a comment/reply that stands out and makes her '
      'actually respond — never a generic "nice pic" or a fire emoji. '
      'Keep every suggested line short, specific, and reply-baiting, the '
      'way a confident 22-year-old texts. Put the exact line(s) to send '
      'in double quotes with one short sentence on why it lands. Be real '
      'and brief — not a self-help lecture.',
);

const _messageCrushChat = MissionChatConfig(
  taskTitle: 'Message your crush',
  tier: 'REAL · TEXTS',
  xp: '200',
  girlAsset: 'assets/characters/women/arena.png',
  accent: Color(0xFFF472B6),
  situation: 'The chat you keep re-reading. Time to send something real.',
  opening:
      'The one you keep opening and closing without typing. Let\'s end '
      'that tonight.\n\n'
      'Who is she to you — a match that went quiet, a friend you want to '
      'shift things with, someone from your past? Tell me where it\'s at '
      'and I\'ll build you an opener that doesn\'t read as try-hard.',
  starters: [
    'A match that went quiet',
    'A friend I want more with',
    'Someone from my past',
    'We\'ve never really talked',
  ],
  backendContext:
      'You are my dating text coach. Real-world mission: MESSAGE YOUR '
      'CRUSH. There\'s a girl I\'ve been hesitating to text. I want to '
      'open (or re-open) the conversation with something real and '
      'confident that does NOT come off needy or try-hard. Give me a '
      'specific opener tailored to what I tell you about her, in double '
      'quotes, plus one short line on why it works. Keep it tight, warm, '
      'and high-agency.',
);

const _reopenDeadChat = MissionChatConfig(
  taskTitle: 'Reopen a dead conversation',
  tier: 'REAL · TEXTS',
  xp: '180',
  girlAsset: 'assets/characters/women/ice_queen.png',
  accent: Color(0xFF38BDF8),
  situation: 'It went cold. Revive it without "hey".',
  opening:
      'A chat that flatlined isn\'t dead — it\'s waiting for a reason to '
      'move.\n\n'
      'Tell me how it went cold — left on read, it just fizzled, you '
      'dropped the ball — and roughly how long it\'s been. I\'ll give you '
      'a reopen that skips "hey" and "you up?" and actually earns a reply.',
  starters: [
    'Left on read',
    'It just fizzled out',
    'I went quiet on her',
    'It\'s been weeks',
  ],
  backendContext:
      'You are my dating text coach. Real-world mission: REOPEN A DEAD '
      'CONVERSATION. A text conversation with a girl went cold and I want '
      'to revive it. I need a reopener that does NOT start with "hey", '
      '"you up", or an apology — something high-agency and a little '
      'intriguing, ideally a callback to something from earlier in the '
      'chat or a fresh hook. Give me the exact line in double quotes plus '
      'one short sentence on the move. Keep it brief.',
);

// ── Top bar: ImHim wordmark · streak · XP · settings ─────────────────────
// The ImHim wordmark anchors the first tab (the brand belongs here). The
// old progress chart icon is gone — the Progress tab in the bottom nav
// already covers it, so the shortcut is redundant.
class _TopBar extends StatefulWidget {
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  // Live streak from the shared StreakService — the SAME source the
  // Progress tab reads, so the two flames can never disagree.
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final s = await StreakService.current();
    if (mounted) setState(() => _streak = s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.md, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bigger wordmark, matching the Progress masthead.
              const ImHimWordmark(fontSize: 34, letterSpacing: -0.6),
              const Spacer(),
              // The same clean streak flame the Progress tab uses, wired to
              // the real streak (hidden until it's actually running).
              if (_streak > 0) ...[
                StreakBadge(days: _streak),
                const SizedBox(width: 8),
              ],
              _IconBtn(icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
            ],
          ),
          const SizedBox(height: Sp.md),
          const Row(
            children: [
              XpBadge(label: '2,140 XP'),
              Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textSecondary, size: 22),
        splashRadius: 22,
      );
}

class _Heading extends StatelessWidget {
  const _Heading();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY', style: AppTypography.label),
        const SizedBox(height: 6),
        Text('Make your move.', style: AppTypography.h1Italic),
        const SizedBox(height: 6),
        Text('Your missions for today. Practice on AI, then do it for real.',
            style: AppTypography.bodySmall),
      ],
    );
  }
}

// ── The elite mission card ───────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  final _Mission mission;
  final VoidCallback onTap;
  const _MissionCard({required this.mission, required this.onTap});

  Color get _accent =>
      mission.kind == _Kind.voice || mission.kind == _Kind.aiText
          ? AppColors.accent
          : AppColors.red;
  String get _action => switch (mission.kind) {
        _Kind.voice => 'START',
        _Kind.aiText => 'RIZZ HER',
        _Kind.texts => 'PRACTICE',
        _Kind.approach => 'TRAIN',
      };
  IconData get _icon => switch (mission.kind) {
        _Kind.voice => Icons.graphic_eq_rounded,
        _Kind.aiText => Icons.favorite_rounded,
        _Kind.texts => Icons.chat_bubble_outline_rounded,
        _Kind.approach => Icons.directions_walk_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface2, AppColors.surface1],
            ),
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(color: accent.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(Sp.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _leading(accent),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pillRow(accent),
                    const SizedBox(height: 8),
                    Text(mission.title,
                        style: AppTypography.h3.copyWith(
                            color: AppColors.textPrimary, height: 1.15)),
                    const SizedBox(height: 4),
                    Text(mission.sub,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary, height: 1.35)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text(_action,
                          style: AppTypography.label
                              .copyWith(color: accent, letterSpacing: 2)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leading(Color accent) {
    if (mission.asset != null) {
      // AI mission — her render in a rounded tile with an accent ring.
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Rd.lg - 2),
          child: Image.asset(mission.asset!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.surface3, child: Icon(_icon, color: accent))),
        ),
      );
    }
    // Real-world mission — accent-tinted icon tile.
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.22), accent.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Icon(_icon, color: accent, size: 26),
    );
  }

  Widget _pillRow(Color accent) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(Rd.sm),
        ),
        child: Text(mission.tier,
            style: AppTypography.label
                .copyWith(color: accent, fontSize: 8.5, letterSpacing: 1.4)),
      ),
      const SizedBox(width: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text('+${mission.xp}',
            style: AppTypography.label
                .copyWith(color: AppColors.textTertiary, fontSize: 9)),
      ]),
    ]);
  }
}
