import Replicate from 'replicate';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Generate a realistic preview of the same person with a specific style change.
 * Uses Flux Kontext Max for identity preservation + measurement anchoring.
 *
 * Args:
 *   imageBase64 — original photo
 *   styleRequest — user's request, e.g. "short skin fade", "full beard", "clean shave"
 *   category — one of: haircut | beard | hair_color | glasses | facial_hair | weight
 *   geometry — measured geometry for anchor preservation
 *
 * Returns: { url, prompt, styleRequest, category }
 */
export async function tryOn({ imageBase64, styleRequest, category, geometry }) {
  if (!styleRequest || typeof styleRequest !== 'string') {
    throw new Error('styleRequest required');
  }

  const geometryAnchors = buildGeometryAnchors(geometry);
  const prompt = buildPrompt({ styleRequest, category, geometryAnchors });

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'jpg',
    safety_tolerance: 2,
    prompt_upsampling: false,
  };

  const output = await replicate.run(MODEL, { input });
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt, styleRequest, category };
}

function buildGeometryAnchors(geometry) {
  if (!geometry) return [];
  return [
    geometry.canthalTilt   != null ? `canthal tilt ${geometry.canthalTilt.toFixed(1)}°`     : null,
    geometry.fwhr          != null ? `FWHR ${geometry.fwhr.toFixed(2)}`                      : null,
    geometry.eyeSpacingRatio != null ? `eye spacing ratio ${geometry.eyeSpacingRatio.toFixed(2)}` : null,
    geometry.jawAngle      != null ? `jaw angle ${geometry.jawAngle.toFixed(0)}°`            : null,
    (geometry.facialThirdTop != null)
      ? `facial thirds ${geometry.facialThirdTop.toFixed(0)}/${geometry.facialThirdMid.toFixed(0)}/${geometry.facialThirdLow.toFixed(0)}`
      : null,
  ].filter(Boolean);
}

function buildPrompt({ styleRequest, category, geometryAnchors }) {
  const categoryGuidance = {
    haircut: 'Change ONLY the hairstyle. Preserve scalp/hairline shape. Keep the person\'s hair color unless explicitly changed. New cut must look like a real salon cut that this person would actually get.',
    beard: 'Change ONLY the facial hair. Beard must grow from the natural facial-hair regions of THIS person. Density should match realistic beard growth for their apparent age and skin tone.',
    facial_hair: 'Change ONLY the facial hair as specified. Keep hairline and head hair identical.',
    hair_color: 'Change ONLY the hair color. Style, length, and cut must remain identical.',
    glasses: 'Add or change only the eyewear. Do not alter face shape, eye shape, or any other feature.',
    weight: 'Show a subtle, realistic change in face fat distribution as described. Preserve bone structure exactly. No bigger than 5-8% change.',
  };

  const guidance = categoryGuidance[category] ?? 'Change only the requested feature. Preserve everything else about the face.';

  const geoBlock = geometryAnchors.length
    ? `\nMEASURED BONE STRUCTURE — preserve exactly:\n${geometryAnchors.map(g => `- ${g}`).join('\n')}\n`
    : '';

  return `Edit this photo to show the SAME person with this single change: "${styleRequest}".

${guidance}
${geoBlock}
HARD CONSTRAINTS — preserve exactly:
- Bone structure, eye shape, nose shape, lip proportions, chin, jawline geometry
- Ethnicity, apparent age, skin tone
- All other styling not named in the request
- Pose, angle, expression, lighting, background

FORBIDDEN:
- Plastic or over-smoothed skin
- Changing facial bone structure
- Changing eye shape or size
- Younger-looking or older-looking transformation
- "Model face" beautification
- Stylization, painterly effects, or HDR look

STYLE: photorealistic portrait photography. Natural, believable, like a real salon/barber result. Same person, one change.

The result MUST make the viewer say "that's the same person, just with [${styleRequest}]". If the face reads as different, the edit has failed.`;
}
