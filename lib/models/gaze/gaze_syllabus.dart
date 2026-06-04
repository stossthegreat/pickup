import 'gaze_lesson.dart';

/// THE GAZE — Lucien's seductive-eye masterclass.
///
/// Twelve named eye MOVES taught the way a real seducer teaches: ONE
/// punch of WHY this move works on her, then a VIVID anatomy-named
/// HOW (her LEFT eye, your top lid, her top lip, slow, heavy, dead
/// brow). No CEO talk, no general "be confident" — every line names
/// the part of the face, the speed, the feeling. That's how a man
/// actually learns to look at a woman.
///
/// Flow per lesson:  WHY → HOW (vivid) → trigger → drill → correction
/// → drill (graded) → score.
///
/// Grounded in real research: ~3.2s is the most comfortable
/// mutual-gaze length (Binetti 2016); mutual gaze manufactures
/// closeness (Aron 1997); hard stare trips the threat circuit, soft
/// eyes read as warmth; the anxious man breaks down/away inside a
/// second, the confident man owns it.
abstract final class GazeSyllabus {
  static const all = <GazeLesson>[
    // ── LESSON 1 — THE LOCK ─────────────────────────────────────────
    GazeLesson(
      id: 'the_lock',
      number: 1,
      name: 'THE LOCK',
      oneLine: 'Four seconds. One iris. You break first.',
      objective: 'Four seconds on one iris. Brow dead. You break.',
      story: [
        'You walked into the bar.',
        'Three women at a table. They haven\'t noticed you.',
        'Pick one. The one in the middle.',
      ],
      demo: [
        'Look at me.',
        'Find my left eye. The iris.',
        'Drop your brow — dead, like you just woke up.',
        'Top lid down a hair. Heavy. Not closed.',
        'Now don\'t move.',
        'Hold... one.',
        '...two.',
        '...three. She felt you.',
        'Break down — not sideways — like you decided.',
      ],
      instruct: [
        'Find her eye. Four seconds. Begin.',
      ],
      // Binetti 2016: 3.3s mean preferred mutual gaze (95% CI 3.2-3.4)
      // across 498 participants from 56 countries. Moore 1985:
      // female-solicitation glance pattern is 2-3s × 3 bouts. Four
      // seconds sits at the upper edge of comfortable for THE LOCK —
      // first contact, decisive, not creepy.
      drillSeconds: 4,
      targetBlinks: 1,
      weights: {
        // No smileControl on THE LOCK — this drill is pure hold, the
        // mouth is irrelevant. Re-distributed across the three axes
        // that actually matter for an unflinching stare.
        GazeDimension.eyeStability: 0.55,
        GazeDimension.blinkControl: 0.20,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.25,
        GazeDimension.smileControl: 0.00,
      },
      isRhythmLesson: false,
      correction: [
        'You broke at second two — she felt you flinch before your lid hit the bottom.',
        'Past three this time. Hold like you meant to be there. Again.',
      ],
    ),

    // ── LESSON 2 — THE DROP ─────────────────────────────────────────
    GazeLesson(
      id: 'the_drop',
      number: 2,
      name: 'THE DROP',
      oneLine: 'When you break, break down. Never up.',
      objective: 'Lock. Then drop slow to her mouth. Down only.',
      story: [
        'You\'re at the bar with her. Close.',
        'She\'s mid-sentence about her week.',
      ],
      demo: [
        'Lock her eye. The iris.',
        'One beat.',
        'Now let it fall — slow, heavy.',
        'Down to the tiny dip above her top lip.',
        'Stay there. One beat.',
        'Climb back to her eye. Smooth.',
        'She just stopped mid-sentence, didn\'t she.',
      ],
      instruct: [
        'She\'s talking. Lock. Drop. Begin.',
      ],
      // 5s = lock-to-her-eye for ~2s, slow drop down to mouth for ~1s,
      // ~2s on the lip, climb back. The journey is the move; rushing
      // kills it. 12s was holding-style stare-off territory.
      drillSeconds: 5,
      targetBlinks: 2,
      weights: {
        GazeDimension.eyeStability: 0.35,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.25,
        GazeDimension.tension:      0.25,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You flicked instead of fell — that\'s a tic, not the drop.',
        'Half the speed. The journey down is the move. Again.',
      ],
    ),

    // ── LESSON 3 — SOFT EYES (SMOULDER) ─────────────────────────────
    GazeLesson(
      id: 'soft_eyes',
      number: 3,
      name: 'SOFT EYES',
      oneLine: 'Brow dead. Top lid down a hair. The smoulder.',
      objective: 'Drop the brow. Half-lid. Smile in the mouth only.',
      story: [
        'You\'re at her table. Close.',
        'Candle between you. Music low.',
      ],
      demo: [
        'Lock her eye.',
        'Drop your brow. Dead.',
        'Top lid down — half. Not quite closed.',
        'Lower lid up a hair. Hunter.',
        'One corner of your mouth lifts. Just one.',
        'Don\'t say a word.',
        'Hold five seconds. That\'s the smoulder.',
      ],
      instruct: [
        'Smoulder. Five seconds. Begin.',
      ],
      // 5s is enough to set the smoulder and hold it — past that it
      // tips into "less trustworthy" territory (Tracy / Live Science:
      // heavy-lid gaze reads as sexually-interested AND less
      // trustworthy at sustained durations).
      drillSeconds: 5,
      targetBlinks: 2,
      weights: {
        GazeDimension.eyeStability: 0.35,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.35,
      },
      isRhythmLesson: false,
      correction: [
        'Your eyes went wide — that\'s a salesman, not a smoulder.',
        'Halve the lid. Slow the breath. Want her, don\'t sell her. Again.',
      ],
    ),

    // ── LESSON 4 — CAUGHT ───────────────────────────────────────────
    GazeLesson(
      id: 'caught',
      number: 4,
      name: 'CAUGHT',
      oneLine: 'She caught you. Don\'t flinch. Smile.',
      objective: 'Hold half a beat past comfort. One mouth corner. Slow.',
      story: [
        'You were looking at her across the room.',
        'She just turned. Eyes met yours.',
      ],
      demo: [
        'Don\'t flinch.',
        'Hold — half a beat past comfortable.',
        'Now one corner of your mouth pulls up.',
        'Not both. One.',
        'Like you were going to look at her anyway.',
      ],
      instruct: [
        'She caught you. Hold. Begin.',
      ],
      // CAUGHT is by definition a brief beat — she catches you, you
      // hold past comfortable (~2-3s past the catch instant) and the
      // smile arrives. 3s captures the whole micro-arc.
      drillSeconds: 3,
      targetBlinks: 1,
      weights: {
        GazeDimension.eyeStability: 0.40,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.30,
      },
      isRhythmLesson: false,
      correction: [
        'You snapped away — you apologised with your whole face.',
        'Never apologise for looking. Hold. Smile. Again.',
      ],
    ),

    // ── LESSON 5 — THE SILENT HOLD ──────────────────────────────────
    GazeLesson(
      id: 'silent_hold',
      number: 5,
      name: 'THE SILENT HOLD',
      oneLine: 'Lock. Say nothing. Let it press into her.',
      objective: 'Hold the look through silence. Don\'t fill the gap.',
      story: [
        'You\'re sitting across from her.',
        'The conversation just died. Neither of you spoke.',
      ],
      demo: [
        'Don\'t fill the silence.',
        'Lock her eye. Soft, not hard.',
        'Mouth closed. Not pinched.',
        'Throat soft. Breathe slow through your nose.',
        'Let the gap get heavy.',
        'Twenty-five seconds.',
        'She breaks first. Every time.',
      ],
      instruct: [
        'Lock. Hold. Begin.',
      ],
      drillSeconds: 25,
      targetBlinks: 6,
      weights: {
        GazeDimension.eyeStability: 0.45,
        GazeDimension.blinkControl: 0.15,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.30,
        GazeDimension.smileControl: 0.10,
      },
      isRhythmLesson: false,
      correction: [
        'You cracked first — said something to make the silence stop.',
        'Let her be the one who can\'t take it. Again.',
      ],
    ),

    // ── LESSON 6 — THE SLOW BLINK ───────────────────────────────────
    GazeLesson(
      id: 'slow_blink',
      number: 6,
      name: 'THE SLOW BLINK',
      oneLine: 'Eyelids fall slow, open slow. Like waking from a nap.',
      objective: 'Long lazy blinks. No flutter. No twitch.',
      story: [
        'She\'s across the room. Looking at you.',
        'You\'re going to blink — slow. Twice.',
      ],
      demo: [
        'Find her eye.',
        'Hold.',
        'Now let the top lid fall.',
        'Slow. Like a curtain.',
        'One beat closed.',
        'Open. Just as slow.',
        'Lock her again.',
        'Blink again. Same speed.',
        'Slower you blink, more dangerous you read.',
      ],
      instruct: [
        'Lock. Slow blink. Begin.',
      ],
      // 6s = lock + two slow blinks with the lock held between. Long
      // enough to practise the cadence, short enough not to be a
      // stare-off.
      drillSeconds: 6,
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
        'Slow them on purpose until the calm becomes real. Again.',
      ],
    ),

    // ── LESSON 7 — THE TRIANGLE ─────────────────────────────────────
    GazeLesson(
      id: 'the_triangle',
      number: 7,
      name: 'THE TRIANGLE',
      oneLine: 'Left eye. Right eye. Mouth. Back up. Slow.',
      objective: 'Travel slow eye → eye → mouth → eye. No flicks.',
      story: [
        'She\'s leaning in. You can smell her perfume.',
        'This is the journey.',
      ],
      demo: [
        'Her left eye. One beat.',
        'Now her mouth. Slow.',
        'Two beats on her lips — like you\'re thinking about them.',
        'Now her right eye. One beat.',
        'Back to the left. Smooth like water.',
        'She felt every inch of that.',
      ],
      instruct: [
        'Left eye. Mouth. Right eye. Begin.',
      ],
      // Sophie Rose Lloyd 17M-view canonical timing: left eye ~1s →
      // lips ~2s → right eye ~1s. Plus a half-beat re-entry. 5s is
      // the budget for one clean triangle.
      drillSeconds: 5,
      targetBlinks: 1,
      weights: {
        GazeDimension.eyeStability: 0.30,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.30,
        GazeDimension.tension:      0.25,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You flicked down too fast — it read as a tic, not intent.',
        'Half the speed. Let her feel the journey. Again.',
      ],
    ),

    // ── LESSON 8 — THE RETURN ───────────────────────────────────────
    GazeLesson(
      id: 'the_return',
      number: 8,
      name: 'THE RETURN',
      oneLine: 'Drift away calm. Return slower than you left.',
      objective: 'Lock. Drift. Come back slower than you went.',
      story: [
        'She\'s across the bar. You held her eye for a beat.',
        'Now you\'re going to drift away. And come back.',
      ],
      demo: [
        'Lock her eye.',
        'Hold.',
        'Now drift away. Calm.',
        'Like you noticed something at the bar.',
        'Two seconds. Gone.',
        'Now come back — slower than you left.',
        'Don\'t snap. Drift.',
        'Like you keep arriving at her, deciding to.',
      ],
      instruct: [
        'Lock. Drift. Return slower. Begin.',
      ],
      drillSeconds: 20,
      targetBlinks: 5,
      weights: {
        GazeDimension.eyeStability: 0.30,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.35,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'Your return was a snap — like you got caught and rushed back.',
        'Return is always slower than exit. Again.',
      ],
    ),

    // ── LESSON 9 — THE ENTRANCE ─────────────────────────────────────
    GazeLesson(
      id: 'the_entrance',
      number: 9,
      name: 'THE ENTRANCE',
      oneLine: 'Find her across the room. Hold past comfort. You break.',
      objective: 'Find. Hold one beat too long. Break first — slow.',
      story: [
        'You walked in. Loud crowd.',
        'She\'s across the room. She hasn\'t seen you yet.',
      ],
      demo: [
        'Find her.',
        'Lock her eye from distance.',
        'Hold.',
        'One beat past comfortable.',
        'She felt you see her.',
        'Now YOU break first.',
        'Slow — to the side.',
        'Not down. Not panic. Your timing.',
      ],
      instruct: [
        'Find her. Hold past comfort. Break first. Begin.',
      ],
      // ENTRANCE is a cross-room initiation — Moore 1985\'s ≤3s
      // glance is the documented signal. 4s gives a half-beat past
      // comfortable before you break first.
      drillSeconds: 4,
      targetBlinks: 1,
      weights: {
        GazeDimension.eyeStability: 0.40,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.15,
        GazeDimension.tension:      0.30,
        GazeDimension.smileControl: 0.05,
      },
      isRhythmLesson: true,
      correction: [
        'You let her break first — you handed her control before you crossed the room.',
        'You break. Your beat. Again.',
      ],
    ),

    // ── LESSON 10 — THE LISTENING GAZE ──────────────────────────────
    GazeLesson(
      id: 'listening_gaze',
      number: 10,
      name: 'THE LISTENING GAZE',
      oneLine: 'Hold her eyes while SHE talks. Almost no one does.',
      objective: 'Hold the gaze while she speaks. Don\'t drift.',
      story: [
        'She\'s telling you something real.',
        'About her week. Her family. Something that matters.',
      ],
      demo: [
        'Lock her left eye. Soft.',
        'Brow neutral.',
        'Tiny nod when she hits a key word.',
        'Slow blink every few breaths.',
        'Don\'t drift to her hair. Her drink. Your phone.',
        'Stay. Twenty-five seconds.',
        'Be the only man who didn\'t look away.',
      ],
      instruct: [
        'She\'s talking. Lock soft. Stay. Begin.',
      ],
      drillSeconds: 25,
      targetBlinks: 7,
      weights: {
        GazeDimension.eyeStability: 0.45,
        GazeDimension.blinkControl: 0.10,
        GazeDimension.rhythm:       0.00,
        GazeDimension.tension:      0.20,
        GazeDimension.smileControl: 0.25,
      },
      isRhythmLesson: false,
      correction: [
        'Your eyes wandered the moment it was her turn — she noticed.',
        'Stay locked while she speaks. Outclass every man she\'s met. Again.',
      ],
    ),

    // ── SOCIALS 1 — THE REEL ────────────────────────────────────────
    GazeLesson(
      id: 'the_reel',
      number: 11,
      name: 'THE REEL',
      oneLine: 'Five moves on camera. Soft. Smoulder. Drop. Return. Smile.',
      objective: 'Hit every move as I call it. Slow between beats.',
      story: [
        'Phone at eye level. The lens is her.',
        'Five moves on camera. This is the one that goes viral.',
      ],
      demo: [
        'Lock the lens. Soft.',
        'Drop the brow. Dead.',
        'Top lid down. Smoulder.',
        'Hold heavy.',
        'Now drop slow — to the lens, like to her lips.',
        'Climb back. Smooth.',
        'Drift to the side. Calm.',
        'Come back slower.',
        'Tilt your head — a millimetre.',
        'Half a smile. One corner.',
        'Now break.',
      ],
      instruct: [
        'Lens. I call. You move. Begin.',
      ],
      sequenceCues: [
        'Lock the lens.',
        'Soft eyes. Smoulder.',
        'Drop — slow — to the mouth.',
        'Climb back to the eyes.',
        'Drift away — slow, to the side.',
        'Drift back — slower than you left.',
        'Now. Half a smile. One corner.',
      ],
      drillSeconds: 24,
      targetBlinks: 7,
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

    // ── SOCIALS 2 — THE SLOW BURN ───────────────────────────────────
    GazeLesson(
      id: 'the_slow_burn_reel',
      number: 12,
      name: 'THE SLOW BURN',
      oneLine: 'Heavier than the reel. The look that already decided.',
      objective: 'Hold the heat. Hit each move slow as I call it.',
      story: [
        'Same lens. Heavier.',
        'This is the look that says you already decided.',
      ],
      demo: [
        'Lens at lid level.',
        'Brow dead. Top lid half-down.',
        'Breathe slow through your nose.',
        'Hold heavy.',
        'Now drop. Slow.',
        'To the lens, like to her lips.',
        'Drag it back to her eyes.',
        'Head tilt. Barely.',
        'Look away — like it was your choice.',
        'Back to the lens. Slow.',
        'Half-smile. One corner.',
        'Break.',
      ],
      instruct: [
        'Lens. Heavy. I call. Begin.',
      ],
      sequenceCues: [
        'Find the lens. Hold it heavy.',
        'Top lid down a hair.',
        'Drop — slow — to the mouth.',
        'Drag it back to the eyes.',
        'Head tilt — barely.',
        'Look away like it was your choice.',
        'Back. Slow half-smile.',
      ],
      drillSeconds: 28,
      targetBlinks: 7,
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
