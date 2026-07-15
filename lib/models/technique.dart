class Technique {
  final String id;
  final String name;
  final String tagline;
  final int day;
  final String description;
  final String scienceNote;
  final String drillInstruction;
  final List<String> coachingPhrases;
  final String completionLine;

  const Technique({
    required this.id,
    required this.name,
    required this.tagline,
    required this.day,
    required this.description,
    required this.scienceNote,
    required this.drillInstruction,
    required this.coachingPhrases,
    required this.completionLine,
  });

  static const all = [
    gazeHold,
    delayedSmile,
    smize,
    chinLock,
    eyebrowFlash,
    blinkCalibration,
    theStill,
    knowingSmile,
    theSequence,
    slowTurn,
  ];

  static Technique forDay(int day) {
    if (day <= 0) return gazeHold;
    final idx = (day - 1).clamp(0, all.length - 1);
    return all[idx];
  }

  bool isUnlocked(int currentDay) => day <= currentDay;
  bool isMastered(int currentDay) => day < currentDay;

  // ── THE GAZE HOLD ──────────────────────────────────────────────────────────
  static const gazeHold = Technique(
    id: 'gaze_hold',
    name: 'The Gaze Hold',
    tagline: 'The silence before the storm.',
    day: 1,
    description:
        'Most people have never held eye contact past two seconds without flinching, '
        'looking away, or hiding behind a smile. What feels unbearable to you reads '
        'as magnetic to them. The hold is not aggression. It is presence. '
        'It says: I am not going anywhere.',
    scienceNote:
        'Dominant individuals hold eye contact 68% of the time while speaking, '
        '28% while listening. Subordinates invert this ratio. It is called '
        'Visual Dominance Behavior — and your current numbers are telling every '
        'room exactly where you stand.',
    drillInstruction: 'Hold eye contact with the camera. When you feel the urge to look away — stay.',
    coachingPhrases: [
      'Look straight in.',
      "Don't move.",
      "You're about to break. Don't.",
      'Feel the pull. That\'s the gap between you and them.',
      'Hold…',
      'They can feel this.',
      "Good. Don't smile yet.",
      'Hold it.',
      'Now let it go.',
    ],
    completionLine:
        'You held it longer than most people ever will. That\'s where it starts.',
  );

  // ── THE DELAYED SMILE ──────────────────────────────────────────────────────
  static const delayedSmile = Technique(
    id: 'delayed_smile',
    name: 'The Delayed Smile',
    tagline: 'What takes half a second to appear takes days to forget.',
    day: 2,
    description:
        'An instant smile says: I want your approval. A delayed smile says: '
        'I am genuinely pleased — and I do not give this away easily. '
        'The build is the whole thing. Slow onset. Eyes follow last. '
        'Not a performance — a revelation.',
    scienceNote:
        'Smiles with a 0.5s onset are rated significantly more flirtatious, more '
        'authentic, and more attractive than smiles with a 0.1s onset. The slow '
        'build mimics genuine emotional arousal. It cannot be convincingly faked '
        'because the timing requires real internal alignment.',
    drillInstruction: 'Start with a completely neutral face. Let the smile arrive slowly — no rushing.',
    coachingPhrases: [
      'Start with nothing.',
      'Hold neutral.',
      'Now… let it come.',
      'Slowly.',
      'Not yet—',
      'Let it reach your eyes.',
      'There.',
      'Hold it.',
      "Don't rush the exit.",
    ],
    completionLine:
        'That timing is permanent now. Everyone who meets you will feel the difference.',
  );

  // ── THE SMIZE ──────────────────────────────────────────────────────────────
  static const smize = Technique(
    id: 'smize',
    name: 'The Smize',
    tagline: 'Warmth without hunger.',
    day: 3,
    description:
        'The most seductive look is not a full smile. It is warmth through the eyes '
        'with a still mouth. The cheeks lift slightly, the lids narrow, and the mouth '
        'stays quiet. It reads as depth — like you are genuinely glad someone exists, '
        'but you are not performing it for their benefit.',
    scienceNote:
        'The orbicularis oculi — the muscle that creates crow\'s feet and cheek lift — '
        'is harder to activate voluntarily than the mouth muscles. This is why '
        'eye-led warmth reads as authentic even when the mouth stays back. '
        'It bypasses the social smile entirely.',
    drillInstruction: 'Keep the mouth completely still. Let the warmth come only from the eyes.',
    coachingPhrases: [
      'Mouth still.',
      'Let the warmth come from behind your eyes.',
      'Not a smile. Something deeper.',
      'Cheeks slightly up.',
      'Eyes soft.',
      'There. Hold it.',
      "Don't let the mouth come in.",
      'This is what they cannot look away from.',
    ],
    completionLine:
        'Warmth without appeasement. That is the rarest combination in a room.',
  );

  // ── CHIN LOCK ──────────────────────────────────────────────────────────────
  static const chinLock = Technique(
    id: 'chin_lock',
    name: 'Chin Lock',
    tagline: 'One degree changes everything.',
    day: 4,
    description:
        'A 3–5 degree downward chin tilt changes how your entire face is read — '
        'without moving a single muscle. It creates the illusion of lowered brows, '
        'the oldest dominance signal in primate biology. This is not a nod. '
        'It is not submission. It is structural gravity.',
    scienceNote:
        'Validated cross-culturally on isolated populations with no media exposure. '
        'Downward head tilt universally increased dominance perception. '
        'The mechanism: your skull angle creates an Action Unit imposter — '
        'the geometry fakes a facial expression the brain reads as strength.',
    drillInstruction: 'Bring your chin down 3–5 degrees and hold that angle without movement.',
    coachingPhrases: [
      'Bring your chin down. Just slightly.',
      'Not a nod. An angle.',
      'Hold.',
      'Eyes stay forward.',
      "Don't let the chin come back up.",
      'Feel the weight of it.',
      'This is what composed looks like.',
      'Hold that angle.',
    ],
    completionLine:
        'You have changed how you are perceived at a structural level. This carries everywhere.',
  );

  // ── THE EYEBROW FLASH ──────────────────────────────────────────────────────
  static const eyebrowFlash = Technique(
    id: 'eyebrow_flash',
    name: 'The Eyebrow Flash',
    tagline: '200 milliseconds. Every culture on earth.',
    day: 5,
    description:
        'A brief brow raise lasting 200 milliseconds has been documented in every '
        'human society ever studied — Papua New Guinea, the Kalahari, the Amazon, '
        'European capitals. Complete strangers. The same signal. It says: I see you. '
        'I am open. Hold it to 400ms and the meaning shifts from recognition to invitation.',
    scienceNote:
        'Evolutionary biologists classify the eyebrow flash as a distance greeting — '
        'a universal signal that bypasses cultural conditioning and goes directly to '
        'the limbic system. The difference between a 200ms and 400ms flash is '
        'the difference between a greeting and a statement of intent.',
    drillInstruction: 'Lift the brows quickly and let them drop. Train the 200ms and 400ms versions separately.',
    coachingPhrases: [
      'Lift. Fast.',
      'Let it drop naturally.',
      'Again — quicker.',
      'Now hold it longer.',
      'Feel the difference.',
      '200 milliseconds. Then 400.',
      'Control the duration.',
      'That distinction is everything.',
    ],
    completionLine:
        'You are now operating at frequencies most people do not even know exist.',
  );

  // ── BLINK CALIBRATION ──────────────────────────────────────────────────────
  static const blinkCalibration = Technique(
    id: 'blink_calibration',
    name: 'Blink Calibration',
    tagline: 'Your nervous system, on display.',
    day: 6,
    description:
        'The average person blinks 17–25 times per minute. Under stress: higher. '
        'When genuinely drawn to someone: 7–10. You cannot fake this — it is a '
        'live broadcast of your internal state. But you can train your system '
        'to run at a lower frequency. Slower system. Heavier lids. Everything lands harder.',
    scienceNote:
        'Blink rate is controlled by the basal ganglia and modulated by dopamine. '
        'Reduced blink rate correlates directly with reduced anxiety and increased '
        'attentional focus. The heavy-lidded look — narrowed aperture, slower '
        'blinks — signals maturity and intensity, not fatigue.',
    drillInstruction: 'Let your blink rate slow down naturally. Do not force the eyes open — let them rest heavy.',
    coachingPhrases: [
      'Let your blink slow down.',
      "Don't force the eye open. Let it rest.",
      'Breathe through it.',
      'Slower. Like you have all the time in the world.',
      'The lids narrow slightly — that is correct.',
      'Your system is dropping.',
      'This is what composure looks like from the outside.',
    ],
    completionLine:
        'Your nervous system just learned a new resting frequency. Use it.',
  );

  // ── THE STILL ─────────────────────────────────────────────────────────────
  static const theStill = Technique(
    id: 'the_still',
    name: 'The Still',
    tagline: 'Stop moving. Start mattering.',
    day: 7,
    description:
        'High-status people move less. Not because they are cold — because they '
        'do not need constant motion to fill space. Every micro-movement you '
        'eliminate makes the ones you keep land three times harder. '
        'Stillness is compression. The most advanced technique here. '
        'The one nobody teaches.',
    scienceNote:
        'In primate hierarchies, subordinates signal submission through constant '
        'nervous movement — fidgeting, adjusting, grooming. Dominants are still. '
        'Humans retain this read at the limbic level. When you stop moving, '
        'attention concentrates on you involuntarily.',
    drillInstruction: 'Maintain complete stillness — face, head, expression — for the full duration.',
    coachingPhrases: [
      "Don't move.",
      'Not your face. Not your head. Nothing.',
      'This is harder than it looks.',
      'The urge to move — that is the whole point.',
      'Still.',
      'Four more seconds.',
      'There is power building here.',
      'Hold.',
      'You are different from most people right now.',
    ],
    completionLine:
        'Most people never learn to stop. You just stopped for thirty seconds. That is a different level.',
  );

  // ── THE KNOWING SMILE ──────────────────────────────────────────────────────
  static const knowingSmile = Technique(
    id: 'knowing_smile',
    name: 'The Knowing Smile',
    tagline: 'Half a smile says twice as much.',
    day: 9,
    description:
        'A symmetric smile says happiness. An asymmetric smile — one side pulling '
        'fractionally higher, the other held back — says something else entirely. '
        'Amusement. Dominance. The sense that you know something they do not. '
        'Marilyn Monroe had it. Young Marlon Brando had it. Let the left side lead.',
    scienceNote:
        'The left hemiface is more emotionally expressive — it fires first and '
        'moves more, because the right hemisphere processes emotion and controls '
        'the left face. Asymmetric smiles are perceived as more dominant, more intense, '
        'and in seductive contexts, significantly more compelling than symmetric ones.',
    drillInstruction: 'Let the left side of the mouth lead. Hold the right side back. Less is more.',
    coachingPhrases: [
      'Let the left side lead.',
      'Right side holds back.',
      'This is not a grin. It is a signal.',
      'Less. Even less.',
      'Hold it there.',
      "Don't let it go symmetric.",
      'There it is.',
      'That expression belongs to very few people.',
    ],
    completionLine:
        'That expression belongs to people who do not need the room\'s approval. Now it belongs to you.',
  );

  // ── THE SEQUENCE ───────────────────────────────────────────────────────────
  static const theSequence = Technique(
    id: 'the_sequence',
    name: 'The Sequence',
    tagline: 'A four-second arc that rewires the room.',
    day: 10,
    description:
        'This is the full choreography — built from every technique you have already '
        'trained. Neutral. Contact. Hold. The smile builds slowly. The break. '
        'The return. Each beat lands differently because of everything that came '
        'before it. This is what real presence looks like when it has been '
        'trained into the body.',
    scienceNote:
        'The sequence triggers a predictable neurological arc in the observer: '
        'attention capture, emotional engagement, threat-free approach activation, '
        'emotional implication at the break, completion drive on return. '
        'Each phase primes the next. The entire arc takes under five seconds.',
    drillInstruction: 'Move through the full sequence: neutral, hold, smile, break, return. Take your time.',
    coachingPhrases: [
      'Start neutral. Nothing on your face.',
      'Make the contact. Hold.',
      'Now let the smile come — slowly.',
      "Don't rush it.",
      'Break. Look away.',
      'Pause there.',
      'Come back.',
      "That's the whole thing. That's it.",
    ],
    completionLine:
        'In four seconds, you moved someone through an emotional arc they did not see coming. '
        'That is not technique anymore. That is presence.',
  );

  // ── THE SLOW TURN ──────────────────────────────────────────────────────────
  static const slowTurn = Technique(
    id: 'slow_turn',
    name: 'The Slow Turn',
    tagline: 'Speed is submission. Slowness is power.',
    day: 11,
    description:
        'When someone calls your name and you snap your head around instantly, '
        'you have just told them they control your attention. A 1.5-second turn '
        'says: I decide what I respond to, and when. This single adjustment '
        'changes every interaction from the first second. Everything you have '
        'trained leads here.',
    scienceNote:
        'Response latency to social stimuli is a reliable status indicator across '
        'primate species and human cultures. High-status individuals respond more '
        'slowly because their environment does not control them — they control '
        'their environment. The pause is the power.',
    drillInstruction: 'Begin a slow, deliberate head turn. Let the body lead. Eyes arrive last.',
    coachingPhrases: [
      'Begin the turn. Slower.',
      'Even slower than that.',
      'Let the body lead.',
      'Eyes arrive last.',
      'Now hold where you land.',
      "Don't rush the arrival.",
      'Own the space you have turned into.',
    ],
    completionLine:
        'You just took your attention back. That is the last thing most people ever give away.',
  );
}
