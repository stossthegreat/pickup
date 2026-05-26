/// The "Laws Behind The Laws" — reference book that sits at the bottom of
/// the Rhetoric tab. Not interactive lessons; just the canon, in
/// plain-English. Tappable cards reveal the full content + a CTA that
/// jumps to the most relevant lesson.
///
/// Four sections:
///   1. ARISTOTLE   — The Three Appeals (Ethos / Pathos / Logos)
///   2. CICERO      — The Five Canons (Invention → Delivery)
///   3. ANTONAKIS   — The 12 Charismatic Leadership Tactics
///   4. THE FIGURES — Named rhetorical devices (Anaphora, Tricolon, etc.)
class CanonSection {
  final String id;
  final String title;
  final String subtitle;
  final String intro;          // one-paragraph framing
  final List<CanonEntry> entries;

  const CanonSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.entries,
  });
}

class CanonEntry {
  final String name;
  final String summary;        // plain-English in one short sentence
  final String example;        // worked example
  final String? lessonId;      // optional jump-to-lesson CTA

  const CanonEntry({
    required this.name,
    required this.summary,
    required this.example,
    this.lessonId,
  });
}

abstract final class CharismaCanon {
  static const aristotle = CanonSection(
    id: 'aristotle',
    title: 'ARISTOTLE',
    subtitle: 'The Three Appeals',
    intro:
        'Every persuasive sentence ever written runs on three engines. '
        'Aristotle named them in the 4th century BC and nothing has changed. '
        'Ethos is who you are. Pathos is what they feel. Logos is what '
        'they think. Strong speakers run all three.',
    entries: [
      CanonEntry(
        name: 'ETHOS',
        summary: 'Credibility. The listener trusting you before you finish.',
        example: '"I have run twelve campaigns. Eight won. Four taught me '
                 'what I am about to tell you."',
        lessonId: 'conviction',
      ),
      CanonEntry(
        name: 'PATHOS',
        summary: 'Emotion. What the listener feels as the words land.',
        example: '"She left, and that — was devastating." The pause is '
                 'the emotion. The strong word is the feeling.',
        lessonId: 'end_strong',
      ),
      CanonEntry(
        name: 'LOGOS',
        summary: 'Logic. The argument that holds up under daylight.',
        example: '"Three of the four highest-margin products were '
                 'launched in Q2. We launch in Q2."',
        lessonId: 'specificity',
      ),
    ],
  );

  static const cicero = CanonSection(
    id: 'cicero',
    title: 'CICERO',
    subtitle: 'The Five Canons',
    intro:
        'Cicero taught Rome how to make a sentence carry the weight of a '
        'city. His five canons map every step from the idea in your head '
        'to the moment it leaves your mouth. Most men skip step five — '
        'and lose every room they enter.',
    entries: [
      CanonEntry(
        name: 'I · INVENTION',
        summary: 'Find the argument. What are you actually claiming?',
        example: 'Before you speak — name the one sentence you would die '
                 'on. Everything else serves it.',
      ),
      CanonEntry(
        name: 'II · ARRANGEMENT',
        summary: 'Order it. Strong opener, weakest middle, strong close.',
        example: 'Hook → evidence → story → strongest line. Always.',
        lessonId: 'hook_first',
      ),
      CanonEntry(
        name: 'III · STYLE',
        summary: 'The texture of the words. Specific. Concrete. Sharp.',
        example: 'Replace every abstract with a named thing.',
        lessonId: 'specificity',
      ),
      CanonEntry(
        name: 'IV · MEMORY',
        summary: 'Internalise it. Reading from a page is the death of weight.',
        example: 'If you cannot say it from the kitchen sink at midnight, '
                 'you do not know it yet.',
      ),
      CanonEntry(
        name: 'V · DELIVERY',
        summary: 'The body. Pitch. Pace. Pause. The same words, transformed.',
        example: 'Lower the pitch. Slow the pace. End on silence.',
        lessonId: 'conviction',
      ),
    ],
  );

  static const antonakis = CanonSection(
    id: 'antonakis',
    title: 'ANTONAKIS',
    subtitle: 'The 12 Tactics That Actually Work',
    intro:
        'In 2011, John Antonakis ran controlled studies on what makes a '
        'leader sound charismatic. Twelve tactics emerged — empirically '
        'validated, replicable, trainable. Use three of them in any speech '
        'and listener ratings of your charisma double. This is the '
        'shortlist. Memorise it.',
    entries: [
      CanonEntry(
        name: 'METAPHOR',
        summary: 'A picture beats a paragraph.',
        example: '"This city is a museum. Manchester still bites."',
      ),
      CanonEntry(
        name: 'STORY',
        summary: 'Specific lived narrative — not opinion.',
        example: 'Replace "I think discipline matters" with the year you '
                 'lived it.',
        lessonId: 'story_over_opinion',
      ),
      CanonEntry(
        name: 'CONTRAST',
        summary: 'X, not Y. The shape of conviction.',
        example: '"Ask not what your country can do for you — ask what '
                 'you can do for your country."',
      ),
      CanonEntry(
        name: 'RULE OF THREE',
        summary: 'Three beats. The mind groups them as inevitable.',
        example: '"Veni. Vidi. Vici."',
      ),
      CanonEntry(
        name: 'RHETORICAL QUESTION',
        summary: 'A question you answer yourself — frames the answer.',
        example: '"Why does this matter? Because the alternative is '
                 'irrelevance."',
        lessonId: 'frame_the_question',
      ),
      CanonEntry(
        name: 'MORAL CONVICTION',
        summary: 'Stake out a value. Not opinion — a value.',
        example: '"I will not work for people who lie to their teams. '
                 'Ever."',
        lessonId: 'take_a_position',
      ),
      CanonEntry(
        name: 'COLLECTIVE SENTIMENT',
        summary: 'Name the thing we already feel together.',
        example: '"We are tired of being told to be patient."',
      ),
      CanonEntry(
        name: 'HIGH EXPECTATIONS',
        summary: 'Tell them what they are capable of.',
        example: '"You are the kind of people who do not flinch."',
      ),
      CanonEntry(
        name: 'CONFIDENCE',
        summary: 'Voice the certainty that the goal is achievable.',
        example: '"We will be there by March. Watch."',
      ),
      CanonEntry(
        name: 'ANIMATED VOICE',
        summary: 'Pitch range + pace variation. Not monotone.',
        example: 'Drop on the loaded word. Rise on the question.',
        lessonId: 'conviction',
      ),
      CanonEntry(
        name: 'ANIMATED FACE',
        summary: 'Eyes, brows, mouth — the face commits.',
        example: 'Same line, dead face vs. lit face. Watch the difference.',
      ),
      CanonEntry(
        name: 'ANIMATED BODY',
        summary: 'The body backs the claim. Open. Decided.',
        example: 'Hands open. Feet planted. Chest up.',
      ),
    ],
  );

  static const figures = CanonSection(
    id: 'figures',
    title: 'THE FIGURES',
    subtitle: 'Named devices, two-thousand-year half-life',
    intro:
        'Most "charisma" is just a man using devices that have names. '
        'These are the figures Cicero named, Lincoln used, Churchill stole, '
        'and every great closing argument still runs. Learn the names. '
        'Use them on purpose.',
    entries: [
      CanonEntry(
        name: 'ANAPHORA',
        summary: 'Repetition at the start of consecutive clauses.',
        example: '"We shall fight on the beaches. We shall fight on the '
                 'landing grounds. We shall fight in the fields."',
      ),
      CanonEntry(
        name: 'TRICOLON',
        summary: 'Three-part list. The brain accepts three as inevitable.',
        example: '"Government of the people, by the people, for the people."',
      ),
      CanonEntry(
        name: 'ANTITHESIS',
        summary: 'X not Y. Sharp contrast in the same sentence.',
        example: '"It was the best of times, it was the worst of times."',
      ),
      CanonEntry(
        name: 'CHIASMUS',
        summary: 'X is Y, Y is X. Mirror image. Maximum stickiness.',
        example: '"Ask not what your country can do for you — ask what '
                 'you can do for your country."',
      ),
      CanonEntry(
        name: 'HYPOPHORA',
        summary: 'Ask a question. Answer it yourself.',
        example: '"Why do I bring this up? Because the alternative '
                 'has already cost us five years."',
      ),
      CanonEntry(
        name: 'ASYNDETON',
        summary: 'No conjunctions. Fast. Sharp. Final.',
        example: '"I came, I saw, I conquered."',
      ),
      CanonEntry(
        name: 'POLYSYNDETON',
        summary: 'Lots of conjunctions. Weight. Inevitability.',
        example: '"And the rain came, and the wind came, and the night '
                 'came, and we waited."',
      ),
      CanonEntry(
        name: 'LITOTES',
        summary: 'Understatement by double negative. Devastating.',
        example: '"He is not unfamiliar with the subject."',
      ),
    ],
  );

  static const all = [aristotle, cicero, antonakis, figures];
}
