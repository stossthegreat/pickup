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

  /// The mistake this tactic is the cure for.
  final String instead;

  const Tactic({
    required this.id,
    required this.name,
    required this.axis,
    required this.what,
    required this.why,
    required this.example,
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
      what: 'Guess something about her instead of asking.',
      why:
          'A question makes her do the work and gives her nothing to react '
          'to. A guess hands her something to agree with, correct or fight '
          '— all three of which are a conversation. It also signals you '
          'formed an opinion, which is the opposite of interviewing her.',
      example: '"You look like you\'re the one who organises everyone else."',
      instead: 'Asking "so what do you do?"',
    ),
    Tactic(
      id: 'thread',
      name: 'THREADING',
      axis: Skill.flow,
      what: 'Pick the interesting word out of what she said and pull it.',
      why:
          'Most conversations die because both people answer the question '
          'and stop. Every sentence she says contains three or four threads; '
          'taking one means you never have to think of a new topic — she '
          'has been handing you them the whole time.',
      example: '"Wait — you said you MOVED here. From where?"',
      instead: 'Answering, then going quiet, then panicking.',
    ),
    Tactic(
      id: 'detail',
      name: 'THE HOOK',
      axis: Skill.flow,
      what: 'Put a specific detail in your answer she can grab.',
      why:
          'A closed answer ends the exchange and makes her do all the work '
          'of restarting it. One odd detail is a handle — it is the single '
          'cheapest way to stop being hard to talk to.',
      example: '"Good, yeah — nearly got thrown out of a pub quiz though."',
      instead: '"Yeah I\'m good, you?"',
    ),
    Tactic(
      id: 'story',
      name: 'THE STORY',
      axis: Skill.flow,
      what: 'Answer with a moment, not a fact.',
      why:
          'People do not remember your job, they remember the time you '
          'nearly got arrested in Lisbon. A thirty-second story does more '
          'for how she feels about you than an hour of accurate answers.',
      example: '"That reminds me — the last time I tried that, I…"',
      instead: 'Listing facts about yourself and waiting.',
    ),

    // ── WIT — the ones that make him fun ──────────────────────────────
    Tactic(
      id: 'callback',
      name: 'THE CALLBACK',
      axis: Skill.wit,
      what: 'Bring back something she said earlier, later.',
      why:
          'It proves you were actually listening rather than waiting to '
          'talk, and it manufactures an inside joke out of thin air. Two '
          'people with an inside joke have a history — and history is what '
          'makes a stranger feel like someone you know.',
      example: '"So are you still defending that terrible music taste?"',
      instead: 'Treating every message like the first one.',
    ),
    Tactic(
      id: 'tease',
      name: 'THE TEASE',
      axis: Skill.wit,
      what: 'Poke at something small and obviously untrue.',
      why:
          'Agreeing with everything reads as trying to be liked, which is '
          'the least attractive thing there is. A tease says you are not '
          'auditioning. It only works on something she is secure about — '
          'aim it at her opinions, never her insecurities.',
      example: '"Pineapple on pizza. And you seemed so normal."',
      instead: 'Complimenting everything she says.',
    ),
    Tactic(
      id: 'misread',
      name: 'PLAYFUL MISREAD',
      axis: Skill.wit,
      what: 'Deliberately take her the wrong way, obviously.',
      why:
          'It turns a flat statement into a game, and it is the fastest '
          'way to change the register from polite to playful. The key word '
          'is OBVIOUSLY — if she has to wonder whether you meant it, it '
          'lands as odd rather than funny.',
      example: '"Asking me to help you move? Bold. We\'ve known each other '
          'four minutes."',
      instead: 'Taking every sentence at face value.',
    ),
    Tactic(
      id: 'exaggerate',
      name: 'THE EXAGGERATION',
      axis: Skill.wit,
      what: 'Take her small thing and run it somewhere ridiculous.',
      why:
          'Humour is mostly scale. Escalating a mundane detail past the '
          'point of sense is the easiest joke to make in real time, and it '
          'invites her to escalate back — which is when a conversation '
          'starts building instead of exchanging.',
      example: '"Two coffees a day? So you\'re basically a medical case."',
      instead: 'Waiting until you think of something clever.',
    ),
    Tactic(
      id: 'pushpull',
      name: 'PUSH–PULL',
      axis: Skill.wit,
      what: 'A small knock, then a genuine warm line.',
      why:
          'Pure warmth reads as needy and pure teasing reads as unkind. '
          'The two together read as someone with standards who has decided '
          'he likes you, which is the actual thing being communicated.',
      example: '"You\'re trouble. Which, unfortunately, I like."',
      instead: 'Picking one gear and staying in it all night.',
    ),

    // ── CONFIDENCE — the ones about saying the thing ──────────────────
    Tactic(
      id: 'intent',
      name: 'HONEST INTENT',
      axis: Skill.confidence,
      what: 'Say you\'re interested, plainly, once.',
      why:
          'Ambiguity is not mystery, it is just work you have handed to '
          'her. Stating it clearly is rarer than any line and it forces a '
          'real answer — which is what you wanted, even when the answer '
          'is no.',
      example: '"For the record, I\'m talking to you because I fancy you."',
      instead: 'Hinting for six weeks and calling it patience.',
    ),
    Tactic(
      id: 'disagree',
      name: 'THE DISAGREEMENT',
      axis: Skill.confidence,
      what: 'Say you think she\'s wrong, warmly.',
      why:
          'A man who agrees with everything has told you he has no '
          'opinions or that he is hiding them to be liked. Disagreeing '
          'without getting cross is the clearest possible signal that you '
          'are not performing — and it is more interesting to talk to.',
      example: '"Nah, I think that\'s completely wrong. Convince me."',
      instead: 'Nodding along to something you don\'t believe.',
    ),
    Tactic(
      id: 'anchor',
      name: 'HOLDING FRAME',
      axis: Skill.confidence,
      what: 'Don\'t rush to fill a silence or soften a line.',
      why:
          'The urge to explain a joke, apologise for a statement or fill a '
          'gap is the single loudest tell of nerves. Letting a line sit is '
          'the cheapest confident thing you can do, because it requires '
          'doing nothing at all.',
      example: '(Say the thing. Then stop typing.)',
      instead: 'Sending a second message to soften the first.',
    ),
    Tactic(
      id: 'qualify',
      name: 'QUALIFICATION',
      axis: Skill.confidence,
      what: 'Ask her to prove something to you.',
      why:
          'Flips the usual direction. Most men spend a conversation '
          'auditioning; asking her for a reason implies you are choosing '
          'too — and, crucially, it makes her invest, which is what people '
          'actually mistake for chemistry.',
      example: '"Alright, sell it to me. Why should I care about that?"',
      instead: 'Trying to be impressive enough to be picked.',
    ),

    // ── RECOVERY — the ones for when it goes wrong ────────────────────
    Tactic(
      id: 'own',
      name: 'OWNING IT',
      axis: Skill.recovery,
      what: 'Name the awkward thing out loud, lightly.',
      why:
          'Awkwardness only has power while everyone pretends it is not '
          'happening. Saying it makes it a shared joke instead of your '
          'private disaster, and it demonstrates you are not fragile — '
          'which is worth more than the line you fluffed.',
      example: '"That came out so much worse than it sounded in my head."',
      instead: 'Pretending it didn\'t happen and going stiff.',
    ),
    Tactic(
      id: 'reframe',
      name: 'THE REFRAME',
      axis: Skill.recovery,
      what: 'Accept the knock and turn it into the joke.',
      why:
          'Arguing with a tease means it landed. Agreeing and going '
          'further means it can\'t. This is the whole skill of being '
          'unrattleable, and it is learnable in about a week.',
      example: '"Correct, and I\'d do it again."',
      instead: 'Defending yourself, seriously, at length.',
    ),
    Tactic(
      id: 'reset',
      name: 'CHANGING THE THREAD',
      axis: Skill.recovery,
      what: 'A dying topic is dropped, not resuscitated.',
      why:
          'Most men try harder on the subject that is already failing. '
          'Abandoning it cleanly and opening something else costs nothing '
          '— she will not notice the switch, she will only notice that it '
          'got fun again.',
      example: '"Anyway — unrelated, but I have to ask you something."',
      instead: 'Asking three more questions about a topic she\'s done with.',
    ),

    // ── CLOSE — the one nobody does ───────────────────────────────────
    Tactic(
      id: 'close',
      name: 'THE ASK',
      axis: Skill.close,
      what: 'Suggest a specific thing, at a specific time.',
      why:
          'A vague "we should do something" puts the work on her and gives '
          'her nothing to say yes to. Specific is easy to accept and easy '
          'to decline, and both of those are better than the conversation '
          'quietly ending because neither of you moved.',
      example: '"There\'s a place near me that does this properly. Thursday?"',
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
