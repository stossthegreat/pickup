import Replicate from 'replicate';
import crypto from 'node:crypto';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

// PRO beats MAX on chained edits. BFL's own testing + community benchmarks:
// Pro accumulates less identity drift across sequential passes, which is
// exactly what we do here. Max is better for single-shot fidelity; we're
// not doing single-shot anymore.
const MODEL = 'black-forest-labs/flux-kontext-pro';

/**
 * Generate the Maximized Twin as a CHAINED edit per BFL's own i2i guide.
 *
 *   docs.bfl.ai/guides/prompting_guide_kontext_i2i
 *
 * Key finding from BFL's docs (verbatim):
 *   "Complex transformations often require multiple steps. Break dramatic
 *    changes into sequential edits for better control. Make one change
 *    at a time."
 *
 * Our previous single-call approach (prompt asking for skin + eyes + hair
 * + lighting at once) is exactly what BFL warns against. The model reliably
 * lands only 1–2 instructions per call and silently drops the rest — that's
 * the "hero shows only one of three changes" bug users reported.
 *
 * The fix is a 2-pass chain:
 *   Pass 1  — SKIN + EYES  (the "rested / clear" pass; covers the two most
 *             visually adjacent changes in one pass — BFL allows 2 related
 *             changes in a single call, just not 3+ unrelated ones)
 *   Pass 2  — HAIR + GROOMING  (takes pass 1's output as input; applies the
 *             hair/brow tidy. Feeding the previous output preserves all the
 *             gains from pass 1 because Kontext treats the new image as
 *             the reference.)
 *
 * 2 calls, ~$0.16 total, ~8–12s total. vs 1 call that missed edits half
 * the time.
 *
 * Deterministic seed on each pass so the same input photo always produces
 * the same chain.
 */
export async function maximize({ imageBase64 }) {
  // Pass 1 — skin + eyes. Positive phrasing only (BFL: no negative prompts).
  const pass1Prompt = `The person in this photo. Refine the skin to look healthy, clear, and even-toned with natural pores still visible; refine the under-eyes to look rested and bright.

Keep the exact same facial features, bone structure, face shape, jawline, nose shape, eye shape and colour, eyebrows, hairline, hair, skin tone, ethnicity, same age, and overall identity completely identical to the original. Soft natural daylight. Preserve the original pose, camera angle, framing, expression, and background. Only change the skin and under-eye areas as described above.`;

  const pass1Seed = deterministicSeed(imageBase64, 'pass1');
  const pass1Url  = await runKontext({
    imageDataUri: `data:image/jpeg;base64,${imageBase64}`,
    prompt:       pass1Prompt,
    seed:         pass1Seed,
  });

  // Pass 2 — hair + brows. Feeds pass 1's URL as the reference so the
  // skin/eye gains are preserved and only hair/brows are adjusted on top.
  const pass2Prompt = `The person in this photo. Tidy the hair on the head so it sits neatly in the same style with natural shine; tidy the eyebrows so they are clean and well-shaped.

Keep the exact same facial features, bone structure, face shape, jawline, nose shape, eye shape and colour, skin tone, ethnicity, same age, and overall identity completely identical to the reference. Preserve the original pose, camera angle, framing, expression, and background. Natural skin texture with visible pores. Only change the hair on the head and the eyebrow grooming — leave everything else pixel-identical.`;

  const pass2Seed = deterministicSeed(imageBase64, 'pass2');
  const pass2Url  = await runKontext({
    imageDataUri: pass1Url,   // CHAIN: previous output becomes next input
    prompt:       pass2Prompt,
    seed:         pass2Seed,
  });

  return {
    url:           pass2Url,
    prompt:        `pass1: ${pass1Prompt}\n\npass2: ${pass2Prompt}`,
    intermediateUrl: pass1Url,
    seeds:         [pass1Seed, pass2Seed],
  };
}

async function runKontext({ imageDataUri, prompt, seed }) {
  const input = {
    prompt,
    input_image:      imageDataUri,
    aspect_ratio:     'match_input_image',
    output_format:    'png',   // BFL: png preserves skin detail, jpg compresses
    output_quality:   95,
    safety_tolerance: 2,
    prompt_upsampling: false,  // BFL: true silently rewrites prompt + injects drift
    seed,
  };
  const output = await replicate.run(MODEL, { input });
  return typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));
}

/**
 * Stable 32-bit unsigned seed from image bytes + a pass label. Same photo
 * always produces the same chain; different passes use different seeds
 * so Flux explores a different local basin for each edit type.
 */
function deterministicSeed(imageBase64, label) {
  const hash = crypto.createHash('md5')
    .update(imageBase64)
    .update('::')
    .update(label)
    .digest();
  return hash.readUInt32BE(0) % 2147483647;
}
