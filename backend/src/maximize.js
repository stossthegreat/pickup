import Replicate from 'replicate';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

// Flux Kontext Max — identity-preserving edit model, highest quality tier
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Generate a maximized version of the input face using Flux Kontext.
 * Identity is anchored via explicit geometry + preserve list.
 * Improvements are scoped tightly (2–3 max) to avoid identity drift.
 *
 * Returns: { url: string, seed: number }
 */
export async function maximize({ imageBase64, brief, geometry }) {
  const improve  = (brief?.improve  ?? []).slice(0, 3);
  const preserve = brief?.preserve ?? [];

  const geometryAnchors = geometry
    ? [
        geometry.canthalTilt   != null ? `canthal tilt ${geometry.canthalTilt.toFixed(1)}°`     : null,
        geometry.fwhr          != null ? `facial width-to-height ratio ${geometry.fwhr.toFixed(2)}` : null,
        geometry.eyeSpacingRatio != null ? `eye spacing ratio ${geometry.eyeSpacingRatio.toFixed(2)}` : null,
        geometry.jawAngle      != null ? `jaw angle ${geometry.jawAngle.toFixed(0)}°`            : null,
        geometry.facialThirdTop != null
          ? `facial thirds ${geometry.facialThirdTop.toFixed(0)}/${geometry.facialThirdMid.toFixed(0)}/${geometry.facialThirdLow.toFixed(0)}`
          : null,
      ].filter(Boolean)
    : [];

  const prompt = buildPrompt({ geometryAnchors, improve, preserve });

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'jpg',
    safety_tolerance: 2,
    prompt_upsampling: false, // keep prompt exact — no rewriting
  };

  const output = await replicate.run(MODEL, { input });
  // Replicate returns a URL string or a FileOutput — normalize to URL
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt };
}

function buildPrompt({ geometryAnchors, improve, preserve }) {
  const preserveList = [
    'exact bone structure',
    'eye shape and size',
    'nose shape and width',
    'lip proportions',
    'face width and length',
    'ethnicity',
    'apparent age',
    'jawline shape',
    'brow position and shape',
    ...preserve,
  ];

  const improveList = improve.length > 0
    ? improve
    : [
        'skin clarity — reduce blemishes and uneven tone, keep natural texture',
        'under-eye brightness — subtle reduction of dark circles',
        'subtle lighting improvement for facial contrast',
      ];

  const geometryBlock = geometryAnchors.length > 0
    ? `\nGEOMETRY — preserve these measured values exactly:\n${geometryAnchors.map((g) => `- ${g}`).join('\n')}\n`
    : '';

  return `Edit this photo to show the SAME person at their best — a realistic, believable version of themselves. This must be a subtle improvement, not a transformation.
${geometryBlock}
PRESERVE — do not change:
${preserveList.map((p) => `- ${p}`).join('\n')}

IMPROVE — apply these changes only, subtly:
${improveList.map((i) => `- ${i}`).join('\n')}

STRICT RULES — avoid at all costs:
- No plastic or overly smooth skin (keep natural texture)
- No "beauty filter" look
- No change to facial bone structure
- No enlarging eyes, narrowing nose, or sharpening jaw structurally (only lighting/contrast may enhance existing structure)
- No change in apparent age, ethnicity, or identity
- No stylization, no painterly effects, no HDR look
- No symmetrical perfection — small natural asymmetries must remain
- No change of expression
- No change of pose or angle
- No background replacement beyond a clean neutralization

Style: photorealistic, natural lighting, high quality portrait photography. Same pose, same angle, same expression, same framing.

The result must make the viewer say "that is clearly the same person, just at their best." If the person would not recognize themselves, the edit has failed.`;
}
