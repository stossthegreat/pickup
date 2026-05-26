import 'gaze_lesson.dart';

/// THE GAZE — Lucien's seductive-eye masterclass.
///
/// Ten named eye MOVES, taught deadly and tight: each lesson is ONE
/// punch of POWER (why this move works on her), ONE line of HOW
/// (exactly what to do), then he sends the user in. No slow-motion,
/// no rambling — the script is built to land like a viral clip.
///
/// Flow per lesson: POWER → HOW → trigger → drill (practice) →
/// correction ("you did X, fix it, Again.") → drill (graded) → score.
///
/// Grounded in real research so it survives a skeptic: ~3.2s is the
/// most comfortable mutual-gaze length (Binetti 2016); mutual gaze
/// manufactures closeness (Aron 1997); a hard stare trips the threat
/// circuit while soft eyes read as warmth; the anxious man breaks gaze
/// down/away within a second, the confident man owns it.
abstract final class GazeSyllabus {
  static const all = <GazeLesson>[
    // ── LESSON 1 — THE LOCK ─────────────────────────────────────────
    GazeLesson(
      id: 'the_lock',
      number: 1,
      name: 'THE LOCK',
      oneLine: 'Three seconds. Hold, then break like you chose to.',
      objective: 'Hold my eyes. Three seconds. Break on your terms.',
      story: [
        'Eye contact is power. Hold hers for three seconds without '
            'flinching and her brain reads the rarest thing in the room: '
            'a man who isn\'t afraid of her.',
      ],
      demo: [
        'How: lock onto one eye. Hold. Three full seconds. Then break '
            'because YOU decided to — not because you cracked.',
      ],
      instruct: [
        'Lock my eyes now. Don\'t flinch. Three seconds. Go.',
      ],
      drillSeconds: 12,
      targetBlinks: 3,
      weights: {
        GazeDimension.eyeStability: 0.45,
        GazeDimension.blinkControl: 0.15,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.30,
        GazeDimension.smileControl: 0.10,
      },
      isRhythmLesson: false,
      correction: [
        'You blinked the second it got heavy. That flinch tells her '
            'you\'re shocked she\'s still looking at you.',
        'Hold it like you expected her to. Again.',
      ],
    ),

    // ── LESSON 2 — THE DROP ─────────────────────────────────────────
    GazeLesson(
      id: 'the_drop',
      number: 2,
      name: 'THE DROP',
      oneLine: 'When you break, break down. Never up and away.',
      objective: 'Hold. Then drop your eyes down — slow. Never up.',
      story: [
        'The way you break the look says more than the look. Break DOWN '
            'and it reads as desire. Break up and away and it reads as '
            '"I\'m bored, who else is here."',
      ],
      demo: [
        'How: hold her eyes, then let them fall — slow — toward her '
            'mouth. Down is intimate. Up is dismissive.',
      ],
      instruct: [
        'Hold my eyes. Then drop them slow. Down, never up. Go.',
      ],
      drillSeconds: 12,
      targetBlinks: 3,
      weights: {
        GazeDimension.eyeStability: 0.35,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.25,
        GazeDimension.tension:      0.25,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You broke up and away — you looked like you were scanning for '
            'the exit.',
        'Let your eyes fall slow, like they\'re heavy. Down. Again.',
      ],
    ),

    // ── LESSON 3 — SOFT EYES ────────────────────────────────────────
    GazeLesson(
      id: 'soft_eyes',
      number: 3,
      name: 'SOFT EYES',
      oneLine: 'The smolder. Warmth in the eyes, not a hard stare.',
      objective: 'Relax the brow. Let the warmth reach your eyes.',
      story: [
        'A hard, wide stare trips an alarm in her brain — it reads as a '
            'threat and she pulls back. Soft eyes read as "I like what I '
            'see and I\'ve got all night." That\'s the smolder.',
      ],
      demo: [
        'How: drop the tension in your brow, soften the corners of your '
            'eyes, a breath of a smile in the eyes only — not the mouth.',
      ],
      instruct: [
        'Hold my eyes — soft. Relax the brow. Smolder. Go.',
      ],
      drillSeconds: 12,
      targetBlinks: 4,
      weights: {
        GazeDimension.eyeStability: 0.35,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.35,
      },
      isRhythmLesson: false,
      correction: [
        'That was a hard stare — tense, like you were winning a fight '
            'nobody started.',
        'Half the tension. Make her feel wanted, not hunted. Again.',
      ],
    ),

    // ── LESSON 4 — CAUGHT ───────────────────────────────────────────
    GazeLesson(
      id: 'caught',
      number: 4,
      name: 'CAUGHT',
      oneLine: 'She catches you looking. You don\'t flinch. You smile.',
      objective: 'Get caught. Hold half a beat. Let a smile start.',
      story: [
        'She WILL catch you looking. The boy snaps away, ashamed — he '
            'just confessed he\'s scared of wanting her. The man holds '
            'it and smiles. Owning the look is the entire move.',
      ],
      demo: [
        'How: when your eyes meet, don\'t run. Hold half a second '
            'longer, and let a slow half-smile start.',
      ],
      instruct: [
        'You\'ve been caught looking. Hold. Half-smile. Go.',
      ],
      drillSeconds: 10,
      targetBlinks: 3,
      weights: {
        GazeDimension.eyeStability: 0.40,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.30,
      },
      isRhythmLesson: false,
      correction: [
        'You looked away fast — you apologised with your whole face.',
        'Never apologise for looking. Hold, and smile. Again.',
      ],
    ),

    // ── LESSON 5 — THE SILENT HOLD ──────────────────────────────────
    GazeLesson(
      id: 'silent_hold',
      number: 5,
      name: 'THE SILENT HOLD',
      oneLine: 'Anyone can hold eyes talking. Hold them in silence.',
      objective: 'Hold my eyes through the silence. Say nothing.',
      story: [
        'Two strangers who hold a gaze in silence feel closer than two '
            'who talked for an hour — that\'s a real study. The silence '
            'is the weapon most men are too scared to use.',
      ],
      demo: [
        'How: hold her eyes and say nothing. Don\'t fill the gap. Let '
            'it get heavy. The one who breaks first loses.',
      ],
      instruct: [
        'Hold my eyes. Silence. Don\'t break first. Go.',
      ],
      drillSeconds: 15,
      targetBlinks: 4,
      weights: {
        GazeDimension.eyeStability: 0.45,
        GazeDimension.blinkControl: 0.15,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.30,
        GazeDimension.smileControl: 0.10,
      },
      isRhythmLesson: false,
      correction: [
        'The silence got heavy and you cracked — you looked away to '
            'make it stop.',
        'Let HER be the one who can\'t take it. Again.',
      ],
    ),

    // ── LESSON 6 — THE SLOW BLINK ───────────────────────────────────
    GazeLesson(
      id: 'slow_blink',
      number: 6,
      name: 'THE SLOW BLINK',
      oneLine: 'Unhurried eyes. The blink of a man with nowhere to be.',
      objective: 'Slow everything. Long, lazy blinks. No darting.',
      story: [
        'Fast, fluttering, darting eyes scream anxiety — she feels it '
            'before she knows why. Slow, lazy eyes say the most '
            'attractive thing there is: I am not nervous and I\'m not '
            'going anywhere.',
      ],
      demo: [
        'How: slow your blinks right down — long and lazy, like waking '
            'from a nap. Nothing scanning. Nothing twitching.',
      ],
      instruct: [
        'Hold my eyes. Slow, lazy blinks. No darting. Go.',
      ],
      drillSeconds: 12,
      targetBlinks: 2,
      weights: {
        GazeDimension.eyeStability: 0.35,
        GazeDimension.blinkControl: 0.40,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: false,
      correction: [
        'Your eyes were a strobe light — every blink screamed nerves.',
        'Slow them down on purpose until the calm becomes real. Again.',
      ],
    ),

    // ── LESSON 7 — THE TRIANGLE ─────────────────────────────────────
    GazeLesson(
      id: 'the_triangle',
      number: 7,
      name: 'THE TRIANGLE',
      oneLine: 'Eye. Eye. Mouth. Back up. The look that isn\'t friendly.',
      objective: 'Eye to eye to mouth, then back. Slow. Deliberate.',
      story: [
        'You look at a friend one way and a woman you want another. The '
            'friendly look stays on the eyes. The other one travels to '
            'her mouth and back — and it tells her exactly what this is, '
            'with zero words.',
      ],
      demo: [
        'How: one eye, the other, then down to her mouth — slow — and '
            'back up. Slow is the whole point. Fast is a twitch.',
      ],
      instruct: [
        'Hold my eyes. Travel slow to the mouth. Back up. Go.',
      ],
      drillSeconds: 12,
      targetBlinks: 3,
      weights: {
        GazeDimension.eyeStability: 0.30,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.30,
        GazeDimension.tension:      0.25,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You flicked down too fast — it looked like a nervous tic, not '
            'intent.',
        'Slow the route down. Let her feel it. Again.',
      ],
    ),

    // ── LESSON 8 — THE RETURN ───────────────────────────────────────
    GazeLesson(
      id: 'the_return',
      number: 8,
      name: 'THE RETURN',
      oneLine: 'Break to build the tension. Then come back, slower.',
      objective: 'Lock. Drift away slow. Return slower than you left.',
      story: [
        'A non-stop laser stare is exhausting, not magnetic. The power '
            'is in the RETURN: you look away, then come back slower than '
            'you left — telling her she was still the most interesting '
            'thing in the room.',
      ],
      demo: [
        'How: lock on, drift away calm and slow, then return — slower '
            'than you left. Deciding, not escaping.',
      ],
      instruct: [
        'Lock my eyes. Drift slow. Return slower. Go.',
      ],
      drillSeconds: 14,
      targetBlinks: 4,
      weights: {
        GazeDimension.eyeStability: 0.30,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.35,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'Your return was a snap — like you got caught looking elsewhere '
            'and rushed back.',
        'The return is always slower than the exit. Again.',
      ],
    ),

    // ── LESSON 9 — THE ENTRANCE ─────────────────────────────────────
    GazeLesson(
      id: 'the_entrance',
      number: 9,
      name: 'THE ENTRANCE',
      oneLine: 'Find her across the room. Hold. Look away on your terms.',
      objective: 'Find her. Hold the look. Be the one who breaks it.',
      story: [
        'Before you say a word, the look across the room has already '
            'told her who you are. Find her eyes, hold one beat too '
            'long, then YOU break it first — that\'s a man who doesn\'t '
            'wait for permission.',
      ],
      demo: [
        'How: find her eyes from distance, hold one second past '
            'comfortable, then break it first — your call, not hers.',
      ],
      instruct: [
        'Find my eyes across the room. Hold too long. Break first. Go.',
      ],
      drillSeconds: 10,
      targetBlinks: 3,
      weights: {
        GazeDimension.eyeStability: 0.40,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.15,
        GazeDimension.tension:      0.30,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You held it and let HER break first — you handed her control '
            'before you crossed the room.',
        'You break first. Your beat. Again.',
      ],
    ),

    // ── LESSON 10 — THE LISTENING GAZE ──────────────────────────────
    GazeLesson(
      id: 'listening_gaze',
      number: 10,
      name: 'THE LISTENING GAZE',
      oneLine: 'Hold her eyes while SHE talks. Almost no one does.',
      objective: 'Hold the gaze while she speaks. Don\'t look away.',
      story: [
        'Every man holds eye contact while HE talks. The second she '
            'speaks, his eyes wander. Hold her eyes while SHE talks and '
            'you become the rarest thing in her week — a man who is '
            'fully, dangerously present.',
      ],
      demo: [
        'How: while she speaks, stay on her eyes. Not your drink, not '
            'the door, not your phone. Soft, present, unwavering.',
      ],
      instruct: [
        'She\'s talking. Hold her eyes the whole time. Don\'t drift. Go.',
      ],
      drillSeconds: 15,
      targetBlinks: 5,
      weights: {
        GazeDimension.eyeStability: 0.45,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.25,
      },
      isRhythmLesson: false,
      correction: [
        'Your eyes wandered the moment it was her turn — she noticed. '
            'They always notice.',
        'Stay locked while she speaks. Outclass every man she\'s met. '
            'Again.',
      ],
    ),

    // ── SOCIALS 1 — THE REEL ────────────────────────────────────────
    // Cinematic. Lucien calls the moves out loud while you perform them
    // to camera — built to be filmed and posted.
    GazeLesson(
      id: 'the_reel',
      number: 11,
      name: 'THE REEL',
      oneLine: 'The look that goes viral. Move after move, on camera.',
      objective: 'Hit every move as he calls it. Film it.',
      story: [
        'This one\'s for the camera. The look influencers build a whole '
            'feed on — and you\'re about to run it move by move.',
      ],
      demo: [
        'I call it, you hit it. Smooth, slow, no rushing between the '
            'beats. Let the camera roll the whole way.',
      ],
      instruct: [
        'Lock onto the lens. When I call the move, you make it. Slow. '
            'Begin.',
      ],
      // The reel itself — each cue spoken live as you perform it.
      sequenceCues: [
        'Lock the lens.',
        'Now look away — slow, to the side.',
        'Bring it back. Find the lens again.',
        'Soften them. Smoulder.',
        'Down. Slow.',
        'Back up — like you just decided something.',
        'Now. The smile. Half of one.',
      ],
      drillSeconds: 18,
      targetBlinks: 6,
      weights: {
        GazeDimension.eyeStability: 0.20,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.35,
        GazeDimension.tension:      0.15,
        GazeDimension.smileControl: 0.20,
      },
      isRhythmLesson: true,
      correction: [
        'Stiff. You rushed the beats and the smile came too early.',
        'Slower between moves. Let each one land for the camera. Again.',
      ],
    ),

    // ── SOCIALS 2 — THE SLOW BURN REEL ──────────────────────────────
    GazeLesson(
      id: 'the_slow_burn_reel',
      number: 12,
      name: 'THE SLOW BURN',
      oneLine: 'Like you\'re looking at something you want. On camera.',
      objective: 'Hold the heat. Hit each move slow as he calls it.',
      story: [
        'Same idea, more heat. This is the look that says you\'ve '
            'already decided — and the camera catches every second of it.',
      ],
      demo: [
        'Heavier this time. Slower. Like you\'re looking at the last '
            'thing you want before you take it.',
      ],
      instruct: [
        'Eyes on the lens. Heavy. I\'ll call it. Begin.',
      ],
      sequenceCues: [
        'Find the lens. Hold it heavy.',
        'Slow drop — down.',
        'Drag it back up.',
        'Tilt the head. Barely.',
        'Soften. Let it burn.',
        'Look away like it was your choice.',
        'Back. And the slow half-smile.',
      ],
      drillSeconds: 18,
      targetBlinks: 5,
      weights: {
        GazeDimension.eyeStability: 0.25,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.30,
        GazeDimension.tension:      0.15,
        GazeDimension.smileControl: 0.20,
      },
      isRhythmLesson: true,
      correction: [
        'Too fast — it read as nervous, not hungry.',
        'Half the speed. Let every move smoulder. Again.',
      ],
    ),
  ];

  static GazeLesson byId(String id) =>
      all.firstWhere((l) => l.id == id, orElse: () => all.first);
}
