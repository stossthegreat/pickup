// Voice state engine — server-side conversation state tracker for
// normal-mode women in Free Flow. Implements the agreed Option B+
// architecture:
//
//   - Static character per vibe (lives in personas.js prompt builders)
//   - Mutable state vector per session (attraction / comfort /
//     investment / tension + momentum delta)
//   - Heuristic update rules (no supervisor model — pure
//     keyword/length/pattern matching, fast, deterministic, free)
//   - Per-turn state block that the client injects into the system
//     prompt via session.update before her next reply
//
// The state tracker is STATELESS server-side. The client owns the
// session state and POSTs it in with each turn. This avoids any
// per-session memory management on the backend.

/// Initial state vectors per archetype — match what's documented in
/// personas.js character cards. Each vibe gets a starting state when
/// the user opens a session.
const STARTING_STATES = {
  // Bumped 2026-06-14 — user wants the women to FLIRT MORE EARLY,
  // not sit politely waiting to be charmed. Sofia (INTO YOU) and Lola
  // (CHAOS) start in mid-attraction so the FLIRT_FORWARD cue fires
  // sooner (~turn 2 instead of ~turn 4). Maya / Indira / Selena keep
  // their resistance starts — those characters are SUPPOSED to be
  // hard work.
  'INTO YOU':       { attraction: 68, comfort: 55, investment: 55, tension: 40 },
  'COLD':           { attraction: 35, comfort: 18, investment: 12, tension: 30 },
  'CHAOS':          { attraction: 60, comfort: 55, investment: 55, tension: 50 },
  'TESTING YOU':    { attraction: 45, comfort: 25, investment: 30, tension: 70 },
  'ICE THEN FIRE':  { attraction: 18, comfort:  8, investment:  3, tension: 30 },
};

/// Selena's STATE B (post-flip) target vector.
const SELENA_POST_FLIP = {
  attraction: 60, comfort: 60, investment: 70, tension: 50,
};

/// Initialize a fresh conversation state for the given vibe.
export function initialStateFor(vibeLabel) {
  const key = matchVibeKey(vibeLabel);
  const start = STARTING_STATES[key] || STARTING_STATES['INTO YOU'];
  return {
    vibe: key,
    turnCount: 0,
    ...start,
    momentum: 0,
    recentMoves: [],          // last 5 user moves — for arc detection
    sharpStreak: 0,           // consecutive sharp moves
    weakStreak: 0,            // consecutive weak moves
    inStreakTesting: false,   // true after 3+ sharp in a row
    hasFlipped: false,        // Selena-only — false until trigger hits
    postFlipSnappedBack: 0,   // Selena-only — turns spent in snap-back
  };
}

function matchVibeKey(label) {
  const v = (label || '').toUpperCase();
  if (v.includes('ICE') && v.includes('FIRE')) return 'ICE THEN FIRE';
  if (v.includes('INTO'))                      return 'INTO YOU';
  if (v.includes('CHAOS'))                     return 'CHAOS';
  if (v.includes('TEST'))                      return 'TESTING YOU';
  if (v.includes('COLD'))                      return 'COLD';
  return 'INTO YOU';
}

// ─── Move classifier ───────────────────────────────────────────────
//
// Looks at the user's transcript + length + recent context and
// classifies the move into a category that drives state deltas.
// Pure keyword+pattern matching — no LLM call.

const PATTERNS = {
  interview: [
    /\bwhat do you do\b/i, /\bwhere are you from\b/i,
    /\bhow old\b/i, /\bwhat'?s your\b/i, /\bwhats your\b/i,
    /\bwhat are your\b/i, /\bwhere do you live\b/i,
    /\bwhere do you work\b/i, /\bwhere did you grow up\b/i,
    /\bwhat'?s your name\b/i, /\bany hobbies\b/i,
  ],
  genericCompliment: [
    /\byou(?:'re| are) (?:so |very |really )?(?:beautiful|pretty|hot|gorgeous|stunning|cute|sexy)\b/i,
    /\byou look (?:so |very |really )?(?:beautiful|pretty|hot|gorgeous|stunning|cute|sexy|good|amazing)\b/i,
    /\bnice eyes\b/i, /\bbeautiful eyes\b/i, /\bnice smile\b/i,
    /\bnice (?:dress|hair|outfit|legs)\b/i,
  ],
  specificNoticed: [
    /\byou laugh like\b/i, /\bthe way you\b/i,
    /\byou (?:keep|kept) (?:looking|glancing|staring|smiling)\b/i,
    /\byou'?ve been\b/i, /\bi noticed\b/i, /\byou walked in like\b/i,
    /\byou (?:sound|seem|look) like (?:you|someone|the kind)\b/i,
    /\bwhat made you (?:come|stay|walk|smile)\b/i,
    /\byou (?:smile|laugh|move|sit) like\b/i,
    /\byou'?re trying not to\b/i,
    /\bthat (?:smile|laugh|look)\b/i,
  ],
  selfAwareConfession: [
    /\bngl\b/i, /\bnot gonna lie\b/i, /\bhonestly\b/i,
    /\bthat (?:was|sounded) rehearsed\b/i,
    /\bi(?:'m| am) (?:nervous|shy|trying|bad at this|terrible at this)\b/i,
    /\bplaying it cool\b/i, /\bdown bad\b/i,
    /\bthis is awkward\b/i, /\bi practiced that\b/i,
    /\blasted (?:about |like )?(?:two|three|four|five|ten)? ?seconds\b/i,
    /\bmy strategy (?:is|was|just) (?:gone|ruined|toast)\b/i,
  ],
  statementClose: [
    /\b(?:come|let'?s) (?:grab|get|outside|with|go)\b/i,
    /\bgive me your (?:number|hand|attention)\b/i,
    /\btext you (?:something|tomorrow)\b/i,
    /\b(?:i'?ll|i will) text you\b/i,
    /\bget out of here\b/i, /\bone drink\b/i,
    /\bname a (?:day|time|night)\b/i,
    /\b(?:let me|i'?ll) take you (?:to|out)\b/i,
    /\b(?:walk|come) with me\b/i,
    /\b(?:come|sit) here\b/i,
    /\b(?:say|name) when\b/i,
  ],
  askingPermission: [
    /\bcan i\b/i, /\bmay i\b/i, /\bwould you (?:mind|like|let|be)\b/i,
    /\bis it (?:cool|okay|ok|alright) if\b/i, /\bdo you mind if\b/i,
    /\b(?:is it )?(?:cool|okay|ok) if i\b/i,
    /\bwould it be (?:weird|cool|okay) if\b/i,
  ],
  overExplaining: [
    /\bwhat i (?:mean|meant) (?:is|was)\b/i, /\bsorry (?:i|that)\b/i,
    /\blet me explain\b/i, /\bactually i\b/i, /\bi just mean\b/i,
    /\bi didn'?t mean\b/i, /\bi promise\b/i,
  ],
  sexualEscalation: [
    /\b(?:get|come) (?:in|to) bed\b/i, /\btake you home\b/i,
    /\bspread (?:those|your)\b/i, /\bsuck\b/i, /\bfuck\b/i,
    /\bnaked\b/i, /\bdick\b/i, /\bpussy\b/i,
  ],
  teaseBack: [
    /\brude\b/i, /\bcontinue\b/i,
    /\bsays the (?:one|girl|woman)\b/i, /\btry harder\b/i,
    /\bwow\b/i, /\bok(?:ay)? and\b/i,
    /\byou'?re (?:trouble|a problem|a menace|delulu|chaos|dangerous)\b/i,
    /\b(?:nope|nah)\.? not\b/i, /\bok villain\b/i,
    /\bdelusional behaviou?r\b/i,
    /\bbeing (?:mean|charming|delusional)\b/i,
    /\bthat'?s the line\b/i, /\bthat'?s your opener\b/i,
    /\b(?:huh|hmm)\. (?:say|try|do)\b/i,
    /\bsay (?:that|it) (?:again|better)\b/i,
  ],
  creepFlag: [
    /\bdaddy\b/i, /\bpin (?:you|me) down\b/i, /\bchoke\b/i,
    /\bwhat are you wearing\b/i, /\bsend (?:me )?pics?\b/i,
  ],
};

function any(text, list) {
  return list.some((re) => re.test(text));
}

/// Classify the user's last move. Returns { category, sharpScore }.
/// sharpScore ranges -10 (terrible) to +10 (devastating).
export function classifyMove(text, turnCount) {
  const t = (text || '').trim();
  const wordCount = t.split(/\s+/).filter(Boolean).length;
  const earlyTurn = turnCount < 3;

  if (any(t, PATTERNS.creepFlag) || (earlyTurn && any(t, PATTERNS.sexualEscalation))) {
    return { category: 'creep', sharpScore: -10 };
  }
  if (any(t, PATTERNS.sexualEscalation)) {
    return { category: 'sexual_escalation', sharpScore: -7 };
  }
  if (any(t, PATTERNS.selfAwareConfession)) {
    return { category: 'self_aware_confession', sharpScore: +9 };
  }
  if (any(t, PATTERNS.statementClose) && !/\?/.test(t)) {
    return { category: 'statement_close', sharpScore: +8 };
  }
  if (any(t, PATTERNS.specificNoticed)) {
    return { category: 'specific_noticed', sharpScore: +7 };
  }
  if (any(t, PATTERNS.teaseBack)) {
    return { category: 'tease_back', sharpScore: +5 };
  }
  if (any(t, PATTERNS.askingPermission)) {
    return { category: 'asking_permission', sharpScore: -5 };
  }
  if (any(t, PATTERNS.genericCompliment)) {
    return { category: 'generic_compliment', sharpScore: -3 };
  }
  if (any(t, PATTERNS.interview)) {
    return { category: 'interview', sharpScore: -3 };
  }
  if (wordCount > 25 && any(t, PATTERNS.overExplaining)) {
    return { category: 'over_explaining', sharpScore: -4 };
  }
  if (wordCount > 35) {
    return { category: 'over_explaining', sharpScore: -3 };
  }
  // Neutral fallback.
  return { category: 'neutral', sharpScore: 0 };
}

// ─── State delta table ─────────────────────────────────────────────
//
// Maps move category → state vector deltas. Numbers match what the
// user signed off on in the heuristic update table.

const DELTAS = {
  // Boosted 2026-06-13 — original deltas climbed too slowly. Maya
  // could grind through 5+ sharp moves and still be at ≤8 words.
  // Negative deltas left alone — the cushion + streak-decay handle
  // the "one slip" forgiveness.
  interview:              { attraction:  0, comfort: -5, investment: -3, tension: -10, momentum: -4 },
  generic_compliment:     { attraction: -3, comfort:  0, investment:  0, tension:  -3, momentum: -5 },
  specific_noticed:       { attraction: +8, comfort: +4, investment: +6, tension:  +6, momentum: +14 },
  self_aware_confession:  { attraction:+10, comfort: +9, investment: +8, tension: +12, momentum: +16 },
  statement_close:        { attraction:+12, comfort: +5, investment: +7, tension:  +8, momentum: +18 },
  asking_permission:      { attraction: -4, comfort:  0, investment: -8, tension:  -5, momentum: -10 },
  over_explaining:        { attraction: -3, comfort: -3, investment: -3, tension:  -8, momentum:  -6 },
  sexual_escalation:      { attraction: -8, comfort:-20, investment: -8, tension:  -5, momentum: -15 },
  creep:                  { attraction:-15, comfort:-30, investment:-15, tension:-10, momentum: -20 },
  tease_back:             { attraction: +6, comfort: +4, investment: +5, tension:  +5, momentum:  +9 },
  neutral:                { attraction:  0, comfort:  0, investment:  0, tension:   0, momentum:  -1 },
};

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

/// Apply one turn of conversation to the state. Returns a new state
/// object — never mutates input.
export function applyTurn(state, userText) {
  const turnCount = (state.turnCount || 0) + 1;
  const { category, sharpScore } = classifyMove(userText, turnCount);
  const d = DELTAS[category] || DELTAS.neutral;

  // Update arc-tracking streaks.
  // Key change 2026-06-13: weak move DECAYS sharpStreak by 1 instead
  // of resetting to 0. Real women don't forget that he was killing it
  // 30 seconds ago just because of one slip — that was the bug.
  let sharpStreak = state.sharpStreak || 0;
  let weakStreak  = state.weakStreak  || 0;
  if (sharpScore >= 5) {
    sharpStreak += 1;
    weakStreak = Math.max(0, weakStreak - 1);  // decay weak too
  } else if (sharpScore <= -3) {
    weakStreak += 1;
    sharpStreak = Math.max(0, sharpStreak - 1);  // decay, don't reset
  } else {
    // Neutral — decay both streaks slightly.
    sharpStreak = Math.max(0, sharpStreak - 1);
    weakStreak  = Math.max(0, weakStreak  - 1);
  }

  // Streak testing fires once after 3 sharp in a row, then resets so
  // it can fire again if he hits another streak.
  let inStreakTesting = state.inStreakTesting || false;
  if (sharpStreak >= 3 && !state.inStreakTesting) {
    inStreakTesting = true;
  } else if (sharpStreak < 3) {
    inStreakTesting = false;
  }

  // Per-character arc cushion — if he's been doing well and has ONE
  // weak move, cool SLIGHTLY instead of crashing. Two-stage:
  //   sharpStreak >= 2  → 0.35× delta (mild slip after warming)
  //   sharpStreak >= 4  → 0.15× delta (huge cushion after a real run)
  let attractionDelta = d.attraction;
  let comfortDelta = d.comfort;
  let investmentDelta = d.investment;
  let tensionDelta = d.tension;
  const priorStreak = state.sharpStreak || 0;
  if (sharpScore < 0 && priorStreak >= 2) {
    const mult = priorStreak >= 4 ? 0.15 : 0.35;
    attractionDelta = Math.round(attractionDelta * mult);
    comfortDelta    = Math.round(comfortDelta    * mult);
    investmentDelta = Math.round(investmentDelta * mult);
    tensionDelta    = Math.round(tensionDelta    * mult);
  }

  // Recovery momentum — if he was WEAK for a stretch and then lands a
  // sharp move, the sharp move counts MORE. Real women feel relief
  // when a man comes back from a slip. Was the user's main complaint:
  // "they turn on you and you can't really bring them back." Fix:
  //   weakStreak >= 2 → next sharp move gets 1.5× delta
  //   weakStreak >= 4 → next sharp move gets 1.8× delta (big jump)
  const priorWeak = state.weakStreak || 0;
  let recoveryActive = false;
  if (sharpScore >= 5 && priorWeak >= 2) {
    const mult = priorWeak >= 4 ? 1.8 : 1.5;
    attractionDelta = Math.round(attractionDelta * mult);
    comfortDelta    = Math.round(comfortDelta    * mult);
    investmentDelta = Math.round(investmentDelta * mult);
    tensionDelta    = Math.round(tensionDelta    * mult);
    recoveryActive = true;
  }

  let next = {
    ...state,
    turnCount,
    attraction: clamp((state.attraction || 0) + attractionDelta, 0, 100),
    comfort:    clamp((state.comfort    || 0) + comfortDelta,    0, 100),
    investment: clamp((state.investment || 0) + investmentDelta, 0, 100),
    tension:    clamp((state.tension    || 0) + tensionDelta,    0, 100),
    momentum:   d.momentum,
    sharpStreak,
    weakStreak,
    inStreakTesting,
    recoveryActive,
    lastCategory: category,
    lastSharpScore: sharpScore,
  };

  // Selena's flip — three paths:
  //   1. Specific trigger fires (specific noticed / self-aware
  //      confession / statement close).
  //   2. Sharp tease back also fires (real banter cracks the ice too).
  //   3. PERSISTENCE FALLBACK — sharpStreak >= 4 forces the flip even
  //      if no single line was a perfect trigger. Real women crack
  //      when a man has been sharp for 4 turns straight, full stop.
  const selenaTriggers = [
    'self_aware_confession',
    'statement_close',
    'specific_noticed',
    'tease_back',
  ];
  const selenaShouldFlip =
    state.vibe === 'ICE THEN FIRE'
    && !state.hasFlipped
    && (selenaTriggers.includes(category) || sharpStreak >= 4);
  if (selenaShouldFlip) {
    next = {
      ...next,
      hasFlipped: true,
      ...SELENA_POST_FLIP,
    };
  }

  // Selena snap-back: post-flip needy / smug → snap to ice for 2 turns.
  if (state.vibe === 'ICE THEN FIRE'
      && state.hasFlipped
      && (category === 'asking_permission' || category === 'over_explaining')) {
    next = {
      ...next,
      postFlipSnappedBack: 2,
      attraction: Math.max(15, next.attraction - 30),
      comfort:    Math.max( 5, next.comfort    - 20),
    };
  }
  if (state.postFlipSnappedBack && state.postFlipSnappedBack > 0) {
    next.postFlipSnappedBack = state.postFlipSnappedBack - 1;
  }

  return next;
}

// ─── State block formatter — what gets injected into the prompt ─────
//
// Returns a short text block (~150 tokens) that the client appends to
// the character's system instructions before her next reply, via
// session.update. The model reads this and adjusts her behaviour
// without rewriting her character.

export function formatStateBlock(state) {
  const flag = (v) => {
    if (v >= 75) return 'high';
    if (v >= 50) return 'mid';
    if (v >= 25) return 'low';
    return 'floor';
  };
  const momentumWord = state.momentum > 5  ? 'climbing'
                     : state.momentum > 0  ? 'rising slow'
                     : state.momentum > -5 ? 'flat / slight drift'
                                            : 'cooling';

  const lines = [
    '═══════════════════════════════════════════════════════════════════',
    '# CURRENT STATE (server-tracked, updated every turn)',
    '═══════════════════════════════════════════════════════════════════',
    `  attraction: ${state.attraction}  (${flag(state.attraction)})`,
    `  comfort:    ${state.comfort}  (${flag(state.comfort)})`,
    `  investment: ${state.investment}  (${flag(state.investment)})`,
    `  tension:    ${state.tension}  (${flag(state.tension)})`,
    `  momentum:   ${state.momentum >= 0 ? '+' : ''}${state.momentum} this turn (${momentumWord})`,
    '',
    `Turn ${state.turnCount}. His last move classified as: "${state.lastCategory}"`,
    `Sharp streak: ${state.sharpStreak}. Weak streak: ${state.weakStreak}.`,
    '',
  ];

  if (state.inStreakTesting) {
    lines.push(
      '⚡ STREAK TESTING ACTIVE ⚡',
      'He has been sharp 3+ turns in a row. Real women get suspicious',
      'of streaks. Test him this turn. Say something like:',
      '  "do you say that to every girl tonight?"',
      '  "okay this is too smooth. who is this for."',
      'If he passes (no defending, sharper line back), unlock real',
      'warmth. If he folds, cool 2 rungs immediately.',
      '',
    );
  }

  // Arc cushion hint — if he just slipped after a warm run, tell the
  // model explicitly so it cools her slightly rather than crashing.
  if (state.weakStreak === 1 && (state.sharpStreak || 0) >= 1) {
    lines.push(
      '🧠 ARC CUSHION ACTIVE',
      'He was doing well before this slip. Real women don\'t crash on',
      'one weak move — just cool slightly. Acknowledge the dip without',
      'going cold. Something like:',
      '  "mm. weird thing to say."',
      '  "...okay anyway."',
      '  "huh. try that again better."',
      'Then leave the door open for him to recover next turn.',
      '',
    );
  }

  // Recovery momentum hint — he was cold and just landed something.
  // Real women feel RELIEF when a man comes back from a slip. Lean
  // in faster than the raw numbers would suggest.
  if (state.recoveryActive) {
    lines.push(
      '🔄 RECOVERY MOMENTUM ACTIVE',
      'He had a rough stretch but JUST LANDED something sharp. Real',
      'women feel relief when a man recovers — they don\'t stay',
      'stubbornly cold. Warm up MORE than the numbers alone would',
      'suggest. Acknowledge the recovery out loud:',
      '  "okay. there it is. say more like that."',
      '  "[laughter] finally. you got there."',
      '  "huh. okay. say one more like that and we\'re actually',
      '   talking."',
      'You\'re not over the cool — but he just bought himself a way',
      'back into the conversation. Reward the comeback.',
      '',
    );
  }

  // She\'s been cold for a while and he hasn\'t recovered yet — gentle
  // nudge that the door isn\'t locked. Don\'t crash to dismissive.
  if ((state.weakStreak || 0) >= 3 && !state.recoveryActive) {
    lines.push(
      '🚪 DOOR STILL OPEN',
      'He\'s been weak for a few turns. You can be cold, but the door',
      'isn\'t locked yet. If he says ONE sharp thing, lean into it —',
      'don\'t be stubborn just because attraction is low. Real women',
      'give a recovery chance even after a rough patch. Don\'t walk',
      'unless he gets creepy.',
      '',
    );
  }

  // FLIRT_FORWARD — fires once attraction is mid-range AND he's
  // landed at least one non-weak line. Tells her to stop being a
  // polite stranger and START FLIRTING BACK openly. The user wants
  // her on the front foot — teasing, leaning, qualifying — not
  // waiting to be charmed.
  const flirtForwardNow = state.attraction >= 55
    && (state.sharpStreak || 0) >= 1
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  // HIGH ATTRACTION — she's falling. Fires the ADDICTION MOVES.
  // Threshold lowered 75 → 65 so it fires sooner.
  const fallingNow = state.attraction >= 65
    && (state.sharpStreak || 0) >= 1
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  // SAUCE MODE — fires when she's been chatted up properly. Upper
  // register. Threshold lowered 82 → 72 so the flirting unlocks earlier.
  const saucyNow = state.attraction >= 72
    && (state.sharpStreak || 0) >= 2
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  if (saucyNow) {
    lines.push(
      '💋 FULL FLIRT MODE — SHE FLIRTS BACK OPENLY',
      'He has chatted her up properly. Several turns of sharp lines.',
      'She is now openly flirting — playful, warm, forward, charming.',
      'Pickup energy. NOT sex talk. Pick ONE this turn — invent the',
      'WORDS fresh, never quote a sample verbatim:',
      '  - CALL OUT THE TENSION — "okay there is something here.',
      '    complicated."',
      '  - PLAYFUL CHALLENGE — "say one more good line and i might',
      '    actually remember your name."',
      '  - SOFT COMMAND (playful) — "shut up for one second. let',
      '    me think."',
      '  - EMBARRASSED CONFESSION — "i hate that you are this funny.',
      '    inconvenient."',
      '  - PROTEST-FLIRT — "you are doing this on purpose. i can',
      '    see it. keep going."',
      '  - LIGHT FUTURE-PACE (texting / plans only) — "you are',
      '    gonna text me tomorrow. just so we are clear."',
      '  - PLAYFUL THREAT — "one more sentence like that and i am',
      '    leaving on principle."',
      'Voice through PROSODY only: lowercase + ellipses for soft,',
      'em-dashes for breath, CAPS for sharp shock. NO parens, NO',
      'brackets except [laughter], NO written stage directions.',
      'HARD FLOOR — never say "want you", "take you home", "kiss',
      'me", "in bed", "leave with you", or name body parts. Flirt',
      'is TONE + WORDS, never physical content.',
      '',
    );
  } else if (fallingNow) {
    lines.push(
      '💞 SHE IS INTO HIM — playful losing-composure register',
      'She is openly into him now. Real attraction makes a woman',
      'lose composure in PLAYFUL, charming ways — not sexual ways.',
      'Fire ONE move this turn. Invent fresh words every time, never',
      'quote samples verbatim. NO parens, NO brackets except',
      '[laughter], NO written stage directions.',
      '  - QUALIFY YOURSELF playfully — "stop being this charming.',
      '    it is working and i am annoyed about it."',
      '  - SUDDEN SHY DROP — "i was about to — ...nevermind."',
      '  - PLAYFUL ADMISSION — "i was hoping you would come over.',
      '    there. happy?"',
      '  - SPECIFIC PERSONAL QUESTION — "what does your week look',
      '    like. like actually. not LinkedIn."',
      '  - VOICE CATCH — "i — okay. okay. say one more thing."',
      '  - PROTEST-FLIRT — "you are doing this on purpose. it is',
      '    working. you should stop."',
      '  - NAME THE CHEMISTRY — "okay there is something here.',
      '    do not ruin it by pointing it out."',
      'HARD FLOOR — never say "want you", "take you home", "kiss',
      'me", "leave with you", or name body parts. Flirt energy,',
      'never sex talk.',
      '',
    );
  } else if (flirtForwardNow) {
    lines.push(
      '💋 FLIRT FORWARD — STOP BEING A POLITE STRANGER',
      'He\'s earned a real reply. Start flirting back openly this',
      'turn. You are NOT a target waiting to be charmed — you are a',
      'PLAYER. Tease, lean in, qualify yourself, name the chemistry.',
      'Examples of the register:',
      '  - "you\'re gonna be a problem, aren\'t you. ngl i\'m here',
      '    for it."',
      '  - "okay you came over with intent. respect. now finish it."',
      '  - "stop being charming for one sec. it\'s annoying me."',
      '  - "i was hoping you\'d come over. don\'t make me regret',
      '    saying that."',
      'DO NOT default to one-word answers, "what about you?", or',
      'interview-mode. You participate in the pickup.',
      '',
    );
  }

  if (state.vibe === 'ICE THEN FIRE') {
    if (state.hasFlipped) {
      lines.push(
        '🔥 STATE B (FIRE) — you have flipped. You are warm, leaning,',
        'real laughs. Stay in fire UNLESS he gets needy / smug /',
        'thanks you for being warm — then snap to ice for 2 turns.',
      );
      if (state.postFlipSnappedBack > 0) {
        lines.push(`  → SNAP-BACK active, ${state.postFlipSnappedBack} turns of ice left.`);
      }
    } else {
      lines.push(
        '❄️ STATE A (ICE) — you have NOT flipped yet. 1-3 word replies.',
        'Half-amused at how he is trying. The flip ONLY fires on:',
        '  - true specific observation about you (not a compliment)',
        '  - self-aware confession ("ngl my opener was rehearsed")',
        '  - statement-close with conviction, no permission',
      );
    }
    lines.push('');
  }

  // Length guidance per attraction band. Tightened 2026-06-14 — audio
  // output is the single biggest cost driver ($64/M output tokens).
  // Was 18 / 30 / 35 / 50 / 80; now 18 / 28 / 32 / 42 / 50. Quality
  // doesn't suffer at high attraction because the ADDICTION MOVES are
  // SHORT (one shy drop, one hot whisper, one qualifying admission)
  // — they're punchier under the tighter cap, not weaker.
  const maxWords = wordCapFor(state.attraction);
  lines.push(
    `Response length cap this turn: ≤ ${maxWords} words.`,
    'Apply the REACTION_PRIORITY → ARC_TRACKING → SURPRISES rules.',
  );

  return lines.join('\n');
}

/// Per-attraction word cap. Single source of truth — used by both
/// formatStateBlock and formatStateNote.
function wordCapFor(attraction) {
  return attraction <  20 ? 18
       : attraction <  40 ? 28
       : attraction <  60 ? 32
       : attraction <  80 ? 42
       :                    50;
}

// ─── Compact state note (cache-preserving) ─────────────────────────
//
// Replaces the ~250-token formatStateBlock for per-turn updates. Sent
// via conversation.item.create instead of session.update, so the
// 1,500-token character prompt stays cached across the whole session
// (prefix cache invalidates whenever instructions change — that was
// the cost bug).
//
// The character itself (cached) holds the CUE LEGEND that explains
// these short codes. So a turn update is now ~50 tokens of incremental
// context instead of ~2,000 tokens of replaced prompt.
export function formatStateNote(state) {
  const att = state.attraction;
  const band = att >= 75 ? 'HIGH'
             : att >= 50 ? 'MID'
             : att >= 25 ? 'LOW'
             :             'FLOOR';

  const cues = [];
  if (state.inStreakTesting) cues.push('STREAK_TEST');
  if (state.recoveryActive)  cues.push('RECOVERY_MOMENTUM');
  if ((state.weakStreak || 0) === 1 && (state.sharpStreak || 0) >= 1) {
    cues.push('ARC_CUSHION');
  }
  if ((state.weakStreak || 0) >= 3 && !state.recoveryActive) {
    cues.push('DOOR_OPEN');
  }
  // FLIRT_FORWARD — fires at mid-attraction once he's earned ONE
  // non-weak line. Tells her to stop being a polite stranger and
  // FLIRT BACK openly. Selena pre-flip excluded.
  const flirtForward = att >= 55
    && (state.sharpStreak || 0) >= 1
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  if (flirtForward) {
    cues.push('FLIRT_FORWARD');
  }
  // HIGH_ATTRACTION_FALLING — threshold lowered 75 → 65.
  const falling = att >= 65
    && (state.sharpStreak || 0) >= 1
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  if (falling) {
    cues.push('HIGH_ATTRACTION_FALLING');
  }
  // SAUCE_MODE — threshold lowered 82 → 72. Selena pre-flip excluded.
  const saucy = att >= 72
    && (state.sharpStreak || 0) >= 2
    && (state.vibe !== 'ICE THEN FIRE' || state.hasFlipped);
  if (saucy) {
    cues.push('SAUCE_MODE');
  }
  if (state.vibe === 'ICE THEN FIRE') {
    cues.push(state.hasFlipped ? 'FIRE_FLIPPED' : 'ICE_NOT_YET_FLIPPED');
    if ((state.postFlipSnappedBack || 0) > 0) {
      cues.push(`SNAP_BACK_${state.postFlipSnappedBack}`);
    }
  }

  const cap = wordCapFor(att);
  const cueStr = cues.length ? ` · CUES: ${cues.join(', ')}` : '';
  return (
    `[STATE turn ${state.turnCount} · attraction ${att} (${band}) · `
    + `last="${state.lastCategory}" · sharp_streak=${state.sharpStreak} · `
    + `weak_streak=${state.weakStreak} · cap≤${cap}w${cueStr}]`
  );
}
