import 'roster.dart';

enum MissionKind { aiPost, aiVoice, aiText, realApproach, realText }

/// One mission. AI missions are generated from a [GirlBrief]; real-world
/// missions come from the escalation ladder below. `id` is stable and
/// self-describing so the daily set can be frozen as a list of ids and
/// rebuilt (see MissionEngine).
class MissionSpec {
  final String id;
  final MissionKind kind;
  final int tier;          // 1..5 difficulty
  final int xp;            // reward — real missions are worth far more
  final String title;
  final String sub;
  final String? girlId;    // AI missions
  final String? postCaption;
  final String? postContext;
  final String? reflectPrompt; // real missions
  final String? coachContext;  // realText: hidden coach preamble
  const MissionSpec({
    required this.id,
    required this.kind,
    required this.tier,
    required this.xp,
    required this.title,
    required this.sub,
    this.girlId,
    this.postCaption,
    this.postContext,
    this.reflectPrompt,
    this.coachContext,
  });

  bool get isReal =>
      kind == MissionKind.realApproach || kind == MissionKind.realText;
}

int _aiXp(int tier) => 40 + tier * 10;   // 50..90
int _realXp(int tier) => 120 + tier * 45; // 165..345  (~3-4x AI)

// ── The real-world escalation ladder — front-loaded, gets brutal ────────
// Grouped by tier. `realApproach` = go do it, confirm after.
// `realText` = coach helps craft the line first (opens TaskChatScreen).
const _ladder = <MissionSpec>[
  // Tier 1 — break the freeze
  MissionSpec(id: 'real:eye', kind: MissionKind.realApproach, tier: 1, xp: 165,
    title: 'Hold eye contact + smile', sub: 'One girl. Look, smile, hold it a beat. That\'s the whole mission.',
    reflectPrompt: 'Did she catch it — and how did holding it feel?'),
  MissionSpec(id: 'real:story', kind: MissionKind.realText, tier: 1, xp: 165,
    title: 'Comment on her story', sub: 'Someone you like posted. One line that pulls a reply — not a 🔥.',
    reflectPrompt: 'Did she reply?',
    coachContext: 'I want to reply to a girl\'s story/post I like and actually start a conversation. Help me craft one line that stands out.'),
  // Tier 2 — the open
  MissionSpec(id: 'real:open1', kind: MissionKind.realApproach, tier: 2, xp: 210,
    title: 'Open one girl', sub: 'Walk up. One real sentence. Doesn\'t matter what she says back.',
    reflectPrompt: 'What did you open with, and what happened?'),
  MissionSpec(id: 'real:crush', kind: MissionKind.realText, tier: 2, xp: 210,
    title: 'Message your crush', sub: 'The one you keep not texting. Send something today.',
    reflectPrompt: 'Did you send it?',
    coachContext: 'I have a crush I keep not texting. Help me craft a confident, low-pressure opener to send her today.'),
  // Tier 3 — volume
  MissionSpec(id: 'real:open3', kind: MissionKind.realApproach, tier: 3, xp: 255,
    title: 'Open three girls today', sub: 'Reps kill the fear faster than perfect lines. Three, any three.',
    reflectPrompt: 'How many did you actually open — and which felt easiest?'),
  MissionSpec(id: 'real:compliment', kind: MissionKind.realApproach, tier: 3, xp: 255,
    title: 'Genuine compliment to a stranger', sub: 'Not her looks. Something you actually noticed. Then hold the moment.',
    reflectPrompt: 'What did you notice, and how did she react?'),
  MissionSpec(id: 'real:reopen', kind: MissionKind.realText, tier: 3, xp: 255,
    title: 'Reopen a dead conversation', sub: 'A chat that died. Revive it without \'hey\' or an apology.',
    reflectPrompt: 'Did it come back to life?',
    coachContext: 'I have a conversation with a girl that went dead. Help me craft a message that reopens it naturally — no \'hey\', no apology.'),
  // Tier 4 — the stretch
  MissionSpec(id: 'real:league', kind: MissionKind.realApproach, tier: 4, xp: 300,
    title: 'Approach one out of your league', sub: 'The one you\'d normally talk yourself out of. Do it anyway.',
    reflectPrompt: 'You did it. What happened — and was she actually out of your league?'),
  MissionSpec(id: 'real:number', kind: MissionKind.realApproach, tier: 4, xp: 300,
    title: 'Get one number', sub: 'Have a real conversation and ask for the number before you leave.',
    reflectPrompt: 'Did you get it? How did you ask?'),
  // Tier 5 — the close
  MissionSpec(id: 'real:date', kind: MissionKind.realApproach, tier: 5, xp: 345,
    title: 'Set a date', sub: 'Turn a number into a plan. A time and a place.',
    reflectPrompt: 'When and where — and how did you set it up?'),
  MissionSpec(id: 'real:ondate', kind: MissionKind.realApproach, tier: 5, xp: 345,
    title: 'Go on the date', sub: 'The whole point. Show up as the man you\'ve been training to be.',
    reflectPrompt: 'How did it go?'),
];

List<MissionSpec> realLadderForTier(int tier) {
  final t = tier.clamp(1, 5);
  final at = _ladder.where((m) => m.tier == t).toList();
  return at.isNotEmpty ? at : _ladder.where((m) => m.tier == 5).toList();
}

// ── AI mission builders (from a roster girl) ────────────────────────────
MissionSpec aiPostMission(GirlBrief g) => MissionSpec(
      id: 'aiPost:${g.id}', kind: MissionKind.aiPost, tier: g.tier, xp: _aiXp(g.tier),
      title: 'Comment on ${g.name}\'s post', sub: 'She just posted. Rizz your way into her DMs.',
      girlId: g.id,
      postContext: '${g.name} just posted a story from her night out.',
      postCaption: _postCaptionFor(g));

MissionSpec aiVoiceMission(GirlBrief g) => MissionSpec(
      id: 'aiVoice:${g.id}', kind: MissionKind.aiVoice, tier: g.tier, xp: _aiXp(g.tier) + 15,
      title: 'Warm up ${g.name} on voice', sub: g.archetype, girlId: g.id);

MissionSpec aiTextMission(GirlBrief g) => MissionSpec(
      id: 'aiText:${g.id}', kind: MissionKind.aiText, tier: g.tier, xp: _aiXp(g.tier),
      title: 'Text ${g.name}', sub: g.archetype, girlId: g.id);

String _postCaptionFor(GirlBrief g) {
  switch (g.id) {
    case 'chaos': return 'nights like this don\'t need a caption 🍸';
    case 'socialite': return 'rooftop views and a drink i\'m ignoring';
    case 'ice_queen': return 'gallery opening. mostly here for the art.';
    case 'simone': return 'dressed up with nowhere better to be';
    default: return 'out tonight ✨';
  }
}

/// Rebuild a spec from a stored daily id.
MissionSpec? specFromId(String id) {
  if (id.startsWith('real:')) {
    for (final m in _ladder) {
      if (m.id == id) return m;
    }
    return null;
  }
  final parts = id.split(':');
  if (parts.length != 2) return null;
  final g = girlById(parts[1]);
  switch (parts[0]) {
    case 'aiPost': return aiPostMission(g);
    case 'aiVoice': return aiVoiceMission(g);
    case 'aiText': return aiTextMission(g);
  }
  return null;
}
