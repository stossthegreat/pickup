/// ══════════════════════════════════════════════════════════════════════
///  THE TACTICS — teaching, disguised as a collection
/// ══════════════════════════════════════════════════════════════════════
///
/// THE RULE THIS FILE OBEYS: never make a man stop playing in order to
/// learn. There is no lessons tab, no course, no "Chapter 3". A tactic
/// is DISCOVERED by doing it, named the moment he does, and then sits in
/// a cabinet he's completing.
///
/// He isn't studying. He's collecting. That's the only version of this
/// anyone actually finishes.
///
/// ── WHY DETECTION IS RULES AND NOT AI ────────────────────────────────
///
/// The grader is a server round-trip that returns five numbers and
/// nothing else — no spans, no quotes, no classification. Waiting on a
/// deploy to change that would mean this feature ships in a month.
///
/// But most of what makes a conversation good is structurally visible in
/// the text. A callback is literally "she said a distinctive word four
/// messages ago and he just reused it". An assumption opens with a
/// handful of stems. Interview mode is two factual questions in a row.
/// So detection is local, instant, free, and works offline.
///
/// The cost is honest: rules find MOST instances, not all, and they can
/// occasionally fire on an accident. That's the right trade for a
/// collection — a missed detection costs him a discovery he'll get next
/// time, and a generous one costs nothing at all. This system must never
/// be used to PUNISH, only to notice.
///
/// ── AND THE CONTENT HAS TO BE TRUE ───────────────────────────────────
///
/// Every "why" below is a real mechanic that works in a real
/// conversation with a real person, not app-flavoured mysticism. If a
/// man reads one of these and uses it on Saturday, it has to hold up.
/// That means: no manipulation framing, no scripts to recite, nothing
/// that treats her as an obstacle. The tactics that survive are the ones
/// that make him more interesting to talk to, because that's the only
/// thing that actually works twice.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';


/// The five things the grader measures — and the curriculum spine.
///
/// Named Skill and not Axis because `Axis` is a Flutter enum exported by
/// material.dart; a widget importing both would fail to resolve it. Same
/// trap that caught Badge in b156.
enum Skill { confidence, flow, wit, recovery, close }

extension SkillX on Skill {
  String get label => switch (this) {
        Skill.confidence => 'CONFIDENCE',
        Skill.flow => 'FLOW',
        Skill.wit => 'WIT',
        Skill.recovery => 'RECOVERY',
        Skill.close => 'CLOSE',
      };

  /// What the axis is actually measuring, in his words rather than the
  /// grader's. "FLOW 4.8" means nothing until this sentence exists.
  String get means => switch (this) {
        Skill.confidence =>
          'Whether you said what you meant, or hedged it into nothing.',
        Skill.flow => 'Whether the conversation had somewhere to go.',
        Skill.wit => 'Whether you were fun to talk to.',
        Skill.recovery => 'What you did when it went badly.',
        Skill.close => 'Whether you ever actually asked for anything.',
      };
}

/// One named mechanic.
class Tactic {
  final String id;
  final String name;

  /// The axis it belongs to. The five scores are the curriculum
  /// architecture — a man weak on WIT gets taught teasing, not closing.
  final Skill axis;

  /// One sentence. What it is.
  final String what;

  /// One sentence. Why it works on an actual human being.
  final String why;

  /// A concrete example he could say out loud tonight.
  final String example;

  /// A second killer line — same weapon, different room. Two examples
  /// is the difference between memorising a line and owning a move.
  final String example2;

  /// The mistake this tactic is the cure for.
  final String instead;

  const Tactic({
    required this.id,
    required this.name,
    required this.axis,
    required this.what,
    required this.why,
    required this.example,
    required this.example2,
    required this.instead,
  });
}

/// SIXTEEN. Enough to be a collection, few enough to finish.
///
/// Ordered roughly by how early a man needs them, so the ones a beginner
/// trips over are the ones he discovers first.
abstract final class Tactics {
  static const all = <Tactic>[
    // ── FLOW — the ones that stop a conversation dying ────────────────
    Tactic(
      id: 'assumption',
      name: 'THE ASSUMPTION',
      axis: Skill.flow,
      what: 'Read her out loud instead of asking her questions.',
      why:
          'A question makes her work. A read makes her FEEL SEEN — and '
          'being seen is the first thing that separates you from every '
          'man who interviewed her this week. Right or wrong doesn\'t '
          'matter: right is intimacy, wrong is a game of her correcting '
          'you, and both are tension.',
      example: '"You\'ve got the face of someone who causes trouble and '
          'then acts innocent when it lands."',
      example2: '"Let me guess — you\'re the dangerous one of your '
          'friends and they all pretend it\'s not true."',
      instead: 'Asking "so what do you do?"',
    ),
    Tactic(
      id: 'thread',
      name: 'THREADING',
      axis: Skill.flow,
      what: 'Catch the loaded word she dropped and pull it.',
      why:
          'Women test in details. She says "we got up to some stuff in '
          'Ibiza" and watches whether you let it slide. Catching the '
          'word proves you\'re actually IN the conversation — present, '
          'sharp, dangerous to say things around. That\'s magnetic.',
      example: '"Hold on. \'Some stuff\'. You don\'t get to say that '
          'and move on."',
      example2: '"Wait — you MOVED here? Who broke whose heart?"',
      instead: 'Letting her best material sail past you.',
    ),
    Tactic(
      id: 'detail',
      name: 'THE HOOK',
      axis: Skill.flow,
      what: 'Leave one loaded detail in your answer — bait she can\'t ignore.',
      why:
          'Seduction is pull, not push. A flat answer gives her nothing; '
          'a hook makes HER lean in and ask — and the moment she\'s '
          'asking about you, she\'s chasing. The detail should raise a '
          'question you don\'t answer until she works for it.',
      example: '"Good week. Made one decision I\'m definitely not '
          'telling you about yet."',
      example2: '"I\'m banned from one country. Anyway — how was '
          'your day?"',
      instead: '"Yeah I\'m good, you?"',
    ),
    Tactic(
      id: 'story',
      name: 'THE STORY',
      axis: Skill.flow,
      what: 'Give her a moment she can feel, not a fact she can file.',
      why:
          'Attraction lives in the body, not the CV. A story puts her IN '
          'a scene with you — she feels the night, the risk, the laugh — '
          'and feelings transfer. She won\'t remember your job title. '
          'She\'ll remember that her heart rate changed while you talked.',
      example: '"Last time someone dared me to do that, I ended up on a '
          'stranger\'s boat at 4am wearing someone else\'s jacket."',
      example2: '"I\'ve only slow-danced once in my life. Rome. Power '
          'cut. Long story — you\'ve been warned."',
      instead: 'Listing facts about yourself and waiting.',
    ),

    // ── WIT — the ones that build tension ─────────────────────────────
    Tactic(
      id: 'callback',
      name: 'THE CALLBACK',
      axis: Skill.wit,
      what: 'Bring back her words from earlier — now it\'s an inside joke.',
      why:
          'An inside joke is a private world with a population of two. '
          'The fastest way to make a stranger feel like a lover is to '
          'have history — and a callback manufactures history out of '
          'thin air. It says: I keep what you say. Nobody forgets the '
          'man who does that.',
      example: '"Careful. That\'s big talk from someone who screamed at '
          'a moth twenty minutes ago."',
      example2: '"This is exactly what you warned me about when you '
          'said you were \'basically an angel\'."',
      instead: 'Treating every message like the first one.',
    ),
    Tactic(
      id: 'tease',
      name: 'THE TEASE',
      axis: Skill.wit,
      what: 'Poke her about something small — with a grin she can hear.',
      why:
          'Agreement is invisible. A tease is friction, and friction is '
          'heat: it says you\'re not auditioning, you\'re PLAYING with '
          'her — and play is where attraction actually happens. Aim at '
          'her taste and her swagger, never her insecurities.',
      example: '"Pineapple on pizza. Unbelievable. We were doing so '
          'well."',
      example2: '"You\'re cute. Terrible taste in films, but cute."',
      instead: 'Complimenting everything she says.',
    ),
    Tactic(
      id: 'misread',
      name: 'PLAYFUL MISREAD',
      axis: Skill.wit,
      what: 'Frame HER as the one making moves — obviously, playfully.',
      why:
          'It flips the poles. All night men have been chasing her; you '
          'casually accuse her of chasing YOU and suddenly she\'s '
          'laughing, denying it, and thinking about it. The frame where '
          'she wants you is now sitting in her head — you put it there '
          'with a smile.',
      example: '"Dinner? I mean — you could\'ve just said you liked me, '
          'this elaborate plan wasn\'t necessary."',
      example2: '"Stop looking at me like that, we\'re in public."',
      instead: 'Taking every sentence at face value.',
    ),
    Tactic(
      id: 'exaggerate',
      name: 'THE EXAGGERATION',
      axis: Skill.wit,
      what: 'Take her small confession and blow it into a saga.',
      why:
          'It turns talking into playing. You escalate, she escalates '
          'back, and two minutes later you\'ve built something absurd '
          'TOGETHER — and co-creating is bonding. A woman who\'s '
          'building a bit with you has already stopped judging you.',
      example: '"Three espressos a day? So this is a hostage situation '
          'and the barista is your captor."',
      example2: '"You re-watch it every year? That\'s not a comfort '
          'show, that\'s a religion. I respect it."',
      instead: 'Waiting until you think of something clever.',
    ),
    Tactic(
      id: 'pushpull',
      name: 'PUSH–PULL',
      axis: Skill.wit,
      what: 'Pull her in warm, push her off playful — same sentence.',
      why:
          'Certainty is comfortable and comfort is forgettable. The '
          'push-pull keeps her reading you: does he like me or not? '
          'That tiny unresolved question is tension, and tension is the '
          'entire chemistry of early attraction. Both halves must be '
          'real — real warmth, playful push.',
      example: '"You\'re dangerously my type. God, that\'s annoying."',
      example2: '"I was going to flirt with you properly tonight, but '
          'you\'ve been far too pleased with yourself. Maybe later."',
      instead: 'Picking one gear and staying in it all night.',
    ),

    // ── CONFIDENCE — the ones about wanting her out loud ──────────────
    Tactic(
      id: 'intent',
      name: 'HONEST INTENT',
      axis: Skill.confidence,
      what: 'Say you want her. Plainly. Once. Then carry on.',
      why:
          'Desire stated calmly, with zero apology and zero neediness, '
          'is the rarest move she\'ll see all year. Hints make her do '
          'the work; a clean declaration puts heat in the room and then '
          '— crucially — you go back to the banter like you didn\'t '
          'just do that. The contrast is devastating.',
      example: '"For the record: I\'m not being friendly. I fancy you. '
          'Anyway — you were saying?"',
      example2: '"I\'m into you. Thought you should have that '
          'information before you order dessert."',
      instead: 'Hinting for six weeks and calling it patience.',
    ),
    Tactic(
      id: 'disagree',
      name: 'THE DISAGREEMENT',
      axis: Skill.confidence,
      what: 'Tell her she\'s wrong — warm, certain, unbothered.',
      why:
          'She spends her life being agreed with by men who want '
          'something. The one who says "no, that\'s wrong" — smiling, '
          'relaxed, holding eye contact — is instantly different: he '
          'has a spine, he isn\'t performing, and winning HIS approval '
          'suddenly means something.',
      example: '"Nah, completely wrong. Enemies now. Shame — this was '
          'going somewhere."',
      example2: '"Bold of you to say that out loud. Convince me or '
          'take it back."',
      instead: 'Nodding along to something you don\'t believe.',
    ),
    Tactic(
      id: 'anchor',
      name: 'HOLDING FRAME',
      axis: Skill.confidence,
      what: 'Drop the line. Then hold the silence like it\'s comfortable.',
      why:
          'The silence AFTER a bold line is where it actually lands — '
          'and most men torch it in two seconds by explaining, joking '
          'it away, or apologising. Holding it says: I meant that, and '
          'I\'m fine watching you decide what to do with it. Nerve is '
          'the most seductive thing a man can transmit.',
      example: '(Say the thing. Then let the silence do the heavy '
          'lifting. She felt it — let her.)',
      example2: '(She reads the message twice. You\'re not typing. '
          'That\'s the move.)',
      instead: 'Sending a second message to soften the first.',
    ),
    Tactic(
      id: 'qualify',
      name: 'QUALIFICATION',
      axis: Skill.confidence,
      what: 'Make HER audition. You\'re choosing too.',
      why:
          'Whoever is proving themselves is the one chasing. One '
          'playful "convince me" flips the frame: now she\'s selling, '
          'you\'re considering — and the effort she spends winning you '
          'over becomes real investment. People value what they '
          'worked for. Make her work, lightly.',
      example: '"You\'re gorgeous, sure — but what else have you got? '
          'Everyone\'s gorgeous."',
      example2: '"Hmm. Undecided about you. Sell it to me in one '
          'sentence."',
      instead: 'Trying to be impressive enough to be picked.',
    ),

    // ── RECOVERY — the ones for when it wobbles ───────────────────────
    Tactic(
      id: 'own',
      name: 'OWNING IT',
      axis: Skill.recovery,
      what: 'Name the stumble out loud, grinning, zero shame.',
      why:
          'Everyone fumbles. What she\'s watching is whether it RATTLES '
          'you — because a man who can stand in his own awkward moment, '
          'amused, is a man who isn\'t fragile, and unshakeable is '
          'attractive at a level lines never reach.',
      example: '"Okay, that line was a war crime. Deleting it from the '
          'record. Where were we."',
      example2: '"I practised that in the mirror and it STILL came out '
          'like that. Incredible."',
      instead: 'Pretending it didn\'t happen and going stiff.',
    ),
    Tactic(
      id: 'reframe',
      name: 'THE REFRAME',
      axis: Skill.recovery,
      what: 'She knocks you — you agree, and raise it.',
      why:
          'Defending yourself proves the hit landed. Agreeing and '
          'DOUBLING DOWN proves nothing can land — you\'ve turned her '
          'attack into your material, in front of her. That\'s frame '
          'control she can feel, and it\'s the exact skill that makes '
          'a man impossible to fluster.',
      example: '"Guilty. And I\'d do it again, slower, while you '
          'watched."',
      example2: '"Correct, I\'m a menace. You\'re the one still '
          'talking to me though — what does that make you?"',
      instead: 'Defending yourself, seriously, at length.',
    ),
    Tactic(
      id: 'reset',
      name: 'CHANGING THE THREAD',
      axis: Skill.recovery,
      what: 'Kill the dying topic. Open a hotter door.',
      why:
          'Chemistry dies in topics that have run out, and most men '
          'stand in the ashes asking follow-up questions. The man who '
          'says "new subject" and drops something charged has just '
          'shown he DRIVES the conversation — and a man who steers is '
          'a man she can relax and be swept along by.',
      example: '"Anyway, that topic\'s dead, we killed it. New one: '
          'what\'s the most trouble you\'ve ever been in?"',
      example2: '"Right, enough small talk. Tell me something you\'ve '
          'never said on a first date."',
      instead: 'Asking three more questions about a topic she\'s done with.',
    ),

    // ── CLOSE — the one nobody does ───────────────────────────────────
    Tactic(
      id: 'close',
      name: 'THE ASK',
      axis: Skill.close,
      what: 'Name the plan, the day, and that it\'s a date.',
      why:
          'All the tension you built is a bill that comes due at the '
          'ask — and "we should hang out sometime" refunds it. A '
          'specific, confident, unmistakable ask converts the whole '
          'conversation: easy to say yes to, impossible to file under '
          '"just friendly". Vague never gets the girl. Specific does.',
      example: '"Thursday. That wine bar I mentioned. Wear something '
          'you\'d want to be seen in — it\'s a date."',
      example2: '"I\'m taking you for the best taco of your life on '
          'Saturday. 7pm. Say yes."',
      instead: '"We should hang out sometime."',
    ),
  ];

  static Tactic? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<Tactic> forAxis(Skill a) =>
      [for (final t in all) if (t.axis == a) t];

  // ══════════════════════════════════════════════════════════════════
  //  DETECTION — local, instant, generous
  // ══════════════════════════════════════════════════════════════════

  static const _stop = <String>{
    'that','this','with','have','from','they','what','your','just','like',
    'been','were','when','then','them','than','into','some','more','very',
    'about','would','could','should','there','their','which','because',
    'really','think','know','going','still','never','always','yeah','okay',
  };

  /// The distinctive words in a line — long, not common. Used for
  /// callback detection.
  static Set<String> _keywords(String s) {
    final out = <String>{};
    for (final w in s.toLowerCase().split(RegExp(r'[^a-z]+'))) {
      if (w.length >= 5 && !_stop.contains(w)) out.add(w);
    }
    return out;
  }

  static bool _has(String s, List<String> stems) {
    final l = s.toLowerCase();
    for (final st in stems) {
      if (l.contains(st)) return true;
    }
    return false;
  }

  static int _questions(String s) => '?'.allMatches(s).length;

  /// What this one message demonstrated.
  ///
  /// [line] is what he just said. [herEarlier] is everything she said
  /// BEFORE the previous turn — a callback has to reach back further
  /// than the message he's replying to, or every reply is a callback.
  /// [hisPrevious] is his last message, for spotting interview mode.
  /// [delta] is how much the line moved her.
  static List<String> detect({
    required String line,
    required List<String> herEarlier,
    required String hisPrevious,
    required double delta,
  }) {
    final found = <String>[];
    final l = line.toLowerCase();
    if (l.trim().length < 4) return found;

    // CALLBACK — a distinctive word of hers, from further back than the
    // message he's answering.
    final mine = _keywords(line);
    for (final earlier in herEarlier) {
      if (_keywords(earlier).intersection(mine).isNotEmpty) {
        found.add('callback');
        break;
      }
    }

    // ASSUMPTION — a guess rather than a question.
    if (_has(l, [
      'you look like',
      'you seem',
      'i bet you',
      'you\'re definitely',
      'youre definitely',
      'you strike me',
      'let me guess',
      'you\'re the type',
      'youre the type',
    ])) {
      found.add('assumption');
    }

    // THREADING — quoting her word back with a follow-up question.
    if (_questions(line) > 0 &&
        _has(l, ['wait', 'hold on', 'you said', 'back up']) ) {
      found.add('thread');
    }

    // MISREAD / TEASE / EXAGGERATION are hard to separate mechanically,
    // so each has its own narrow stem set and only fires on a clear one.
    if (_has(l, ['so you\'re saying', 'so youre saying', 'are you asking me',
        'is that an invitation', 'bold of you'])) {
      found.add('misread');
    }
    if (_has(l, ['and you seemed', 'that\'s a red flag', 'thats a red flag',
        'you\'re trouble', 'youre trouble', 'absolute menace',
        'i\'m judging you', 'im judging you'])) {
      found.add('tease');
    }
    if (_has(l, ['basically a', 'that\'s not a', 'thats not a',
        'genuinely concerning', 'medical'])) {
      found.add('exaggerate');
    }

    // HONEST INTENT.
    if (_has(l, ['i fancy you', 'i like you', 'i\'m interested',
        'im interested', 'for the record', 'i\'m into you', 'im into you'])) {
      found.add('intent');
    }

    // DISAGREEMENT — said warmly, not a row.
    if (_has(l, ['i disagree', 'that\'s wrong', 'thats wrong', 'nah,',
        'hard disagree', 'convince me', 'i don\'t buy', 'i dont buy'])) {
      found.add('disagree');
    }

    // QUALIFICATION — making her invest.
    if (_has(l, ['sell it to me', 'why should i', 'convince me',
        'prove it', 'make the case'])) {
      found.add('qualify');
    }

    // OWNING IT.
    if (_has(l, ['came out wrong', 'worse than it sounded', 'that was bad',
        'i\'ll be honest that', 'ill be honest that', 'awkward'])) {
      found.add('own');
    }

    // THE REFRAME — agreeing with a knock and going further.
    if (_has(l, ['correct, and', 'guilty', 'and i\'d do it again',
        'and id do it again', 'you\'re not wrong', 'youre not wrong'])) {
      found.add('reframe');
    }

    // CHANGING THE THREAD.
    if (_has(l, ['anyway', 'unrelated', 'different question',
        'changing the subject'])) {
      found.add('reset');
    }

    // THE ASK — a specific plan, not "sometime".
    if (_has(l, ['are you free', 'let\'s go', 'lets go', 'come with me',
        'thursday', 'friday', 'saturday', 'sunday', 'monday', 'tuesday',
        'wednesday', 'tonight', 'tomorrow']) &&
        !_has(l, ['sometime', 'some time', 'one day'])) {
      found.add('close');
    }

    // THE HOOK and THE STORY are judged on shape rather than stems: a
    // long answer that isn't a question, which landed well.
    if (delta > 0 && _questions(line) == 0) {
      final words = line.trim().split(RegExp(r'\s+')).length;
      if (words >= 22) {
        found.add('story');
      } else if (words >= 10) {
        found.add('detail');
      }
    }

    return found;
  }

  /// INTERVIEW MODE — the mistake, not a tactic.
  ///
  /// Two factual questions in a row with nothing of his own in between.
  /// Detected separately because it's the single most common reason a
  /// conversation dies and the coaching needs to be able to name it.
  static bool interviewing(String line, String previous) {
    final a = _questions(previous) > 0 && previous.trim().length < 90;
    final b = _questions(line) > 0 && line.trim().length < 90;
    return a && b;
  }

  // ══════════════════════════════════════════════════════════════════
  //  THE COLLECTION
  // ══════════════════════════════════════════════════════════════════

  static const _kFound = 'tac.found.v1';
  static const _kLines = 'tac.lines.v1';

  static Future<Set<String>> discovered() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_kFound) ?? const <String>[]).toSet();
  }

  /// The line of HIS OWN that unlocked each tactic. This is the whole
  /// reason the collection teaches rather than informs — he opens the
  /// cabinet and reads a sentence he wrote.
  static Future<Map<String, String>> unlockLines() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLines);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {for (final e in m.entries) '${e.key}': '${e.value}'};
    } catch (_) {
      return {};
    }
  }

  /// Bank whatever this line demonstrated. Returns only the ones that
  /// were NEW, so a man who uses callbacks constantly isn't congratulated
  /// every time.
  static Future<List<Tactic>> claim(List<String> ids, String line) async {
    if (ids.isEmpty) return const [];
    final p = await SharedPreferences.getInstance();
    final found = (p.getStringList(_kFound) ?? const <String>[]).toSet();
    final lines = await unlockLines();

    final fresh = <Tactic>[];
    for (final id in ids) {
      if (found.contains(id)) continue;
      final t = byId(id);
      if (t == null) continue;
      found.add(id);
      lines[id] = line.trim();
      fresh.add(t);
    }
    if (fresh.isEmpty) return const [];

    await p.setStringList(_kFound, found.toList());
    await p.setString(_kLines, jsonEncode(lines));
    return fresh;
  }

  static Future<({int found, int total})> tally() async {
    final d = await discovered();
    return (found: d.length, total: all.length);
  }
}
