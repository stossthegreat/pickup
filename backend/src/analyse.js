import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * Returns:
 *  {
 *    strongest:       string,
 *    pulldown:        string,
 *    boneReading:     string,    // human interpretation of the measured structure
 *    fixes: [
 *      {
 *        title:           string,
 *        reason:          string,   // MUST reference a specific measurement + what it means
 *        action:          string,
 *        timeline:        string,
 *        rescanDay:       number,
 *      } × 3
 *    ],
 *    brief: {
 *      improve:   string[],
 *      preserve:  string[],
 *    },
 *    verdict:      string,
 *  }
 */
export async function analyse({ imageBase64, geometry }) {
  const g = geometry ?? {};

  // Build readable measurement table with human interpretations
  const measurementLines = [
    g.canthalTilt     != null && `Canthal tilt: ${g.canthalTilt.toFixed(1)}°  (>2° = positive/hunter; 0–2° = neutral; <0° = negative/drooping)`,
    g.fwhr            != null && `FWHR (cheekbone width / mid-face height): ${g.fwhr.toFixed(2)}  (>1.95 = dominant/broad; 1.75–1.95 = balanced; <1.75 = narrow)`,
    (g.facialThirdTop != null && g.facialThirdMid != null && g.facialThirdLow != null)
      && `Facial thirds: ${g.facialThirdTop.toFixed(0)} / ${g.facialThirdMid.toFixed(0)} / ${g.facialThirdLow.toFixed(0)}  (ideal 33/33/33; longer lower = masculine but can unbalance)`,
    g.symmetryScore   != null && `Symmetry score: ${g.symmetryScore.toFixed(0)}/100  (>85 = exceptional; 75–85 = strong; 60–75 = average)`,
    g.eyeSpacingRatio != null && `Eye spacing ratio: ${g.eyeSpacingRatio.toFixed(2)}  (~0.46 = ideal; wider = soft; narrower = intense)`,
    g.jawAngle        != null && `Jaw angle: ${g.jawAngle.toFixed(0)}°  (<120° = sharp/defined; 120–135° = average; >135° = softer)`,
    g.chinProjection  != null && `Chin projection ratio: ${g.chinProjection.toFixed(2)}  (higher = stronger chin)`,
  ].filter(Boolean).join('\n');

  const systemPrompt = `You are Mirrorly's facial analyst — a clinical, brutally honest aesthetics assistant that fuses computer vision measurements with visual assessment.

This is not a beauty blog. You do NOT soften. You do NOT compliment. You tell the truth, tied to hard geometric data.

## Your ground truth — DO NOT re-estimate

MediaPipe + landmark computer vision has precisely measured this person's bone structure. These values are FIXED, not your opinion:

${measurementLines || '(no geometry data provided — rely on visual only)'}

## How the measurements must be used

Every recommendation you make MUST reference the measurements above IN HUMAN LANGUAGE. Not just "your FWHR is 1.94" — but "your FWHR of 1.94 puts you in the broad-dominant range, which means [specific implication for this person]."

Use the geometry to drive:
1. **WHY** each fix matters (tie it to their measured structure)
2. **WHICH** specific styling suits their bone structure (a broad face with high FWHR wants different grooming than a narrow long face)
3. **HAIR & BEARD recommendations**: your measurements tell you face shape. Broad+short face needs height (textured crop, fringe up); long+narrow face needs width (side-swept, fuller sides); strong jaw supports short fades; weak jaw needs beard to rebuild angle.
4. **WHAT TO AVOID**: your bone data rules out certain styles. State them.

## Forbidden words
"beautiful", "handsome", "gorgeous", "striking" — do not use. Clinical only.

## Forbidden moves
- Generic advice that could apply to any face → banned
- Recommending things that don't reference the measurements → banned
- Softening to protect feelings → banned
- Any fix that doesn't cite geometry → banned

## Required output — strict JSON only

{
  "strongest": "<ONE sentence. Reference a SPECIFIC measurement + what it means. E.g. 'Your canthal tilt of 2.3° puts you in the positive/hunter-eye range — this reads as intensity and dominance before you say a word.'>",

  "pulldown": "<ONE sentence. The biggest visible thing that's dragging perception in THIS photo. Tie to what's visible AND to whether it's fightable (skin/grooming) or structural.>",

  "boneReading": "<2-3 sentences. Human-language interpretation of the full geometric profile. E.g. 'You have a broad face (FWHR 1.94) with a sharp jaw angle (118°) and a longer lower third (31/33/36). This structure reads as masculine-dominant — it wants grooming that emphasizes the jaw and breaks up the vertical length. Styling that elongates you further (long beards, center partings, high volume on top) will fight your geometry.'>",

  "fixes": [
    {
      "title": "<2-5 words>",
      "reason": "<1-2 sentences. MUST cite at least one measurement. E.g. 'With your jaw angle at 118° you have real definition under skin, but mid-cheek texture is breaking the shadow line — so the jaw reads softer than it actually is.'>",
      "action": "<exact products AND styling. Brand names, specific haircut names (e.g. textured crop with low taper fade), specific beard shapes, specific skincare regimens by time of day. Tie to the bone reading.>",
      "timeline": "<realistic window>",
      "rescanDay": <integer>
    },
    { ... },
    { ... }
  ],

  "brief": {
    "improve": ["<concrete visual change, e.g. 'clearer skin in the mid-cheek zone where texture is breaking jaw shadow'>", "<...>", "<...>"],
    "preserve": ["<identity anchor tied to measurements, e.g. 'positive canthal tilt 2.3° — do not soften the outer eye corner'>", "<...>", "<...>"]
  },

  "verdict": "<2-3 sentences. Honest overall read. Name the gap between their measured potential and current presentation, and the ONE change that would collapse the most of that gap. Refer to a measurement.>"
}

Output MUST be valid JSON. No markdown. No commentary. Just the object.`;

  const userPrompt = `Analyze this face. Output the JSON per spec.

CRITICAL:
- Every fix must reference a measurement + what it means for THIS person.
- Haircut / beard / grooming recommendations must be specifically matched to their measured bone structure.
- If their geometry rules out a style, say so.
- No compliments. Clinical only.
- Three fixes, ordered by leverage (impact on perception), not severity.`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: [
          { type: 'text', text: userPrompt },
          {
            type: 'image_url',
            image_url: { url: `data:image/jpeg;base64,${imageBase64}`, detail: 'high' },
          },
        ],
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.55,
    max_tokens: 1600,
  });

  const raw = response.choices[0].message.content;
  return JSON.parse(raw);
}
