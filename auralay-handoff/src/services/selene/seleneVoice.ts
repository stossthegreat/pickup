import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const VOICE = process.env.SELENE_VOICE || 'coral';
const MODEL = process.env.SELENE_TTS_MODEL || 'gpt-4o-mini-tts';

const SELENE_VOICE_INSTRUCTIONS = `Speak as a 27-year-old woman with a low, slow, deliberate, intimate voice. Second circle — talk TO one person, not AT a room. Drop the last word of every sentence a third lower. Never uptalk. Pauses are real. Breath is audible but not effortful. You're not performing. You're present.`;

export async function synthesizeSelene(text: string): Promise<Buffer> {
  const res = await openai.audio.speech.create({
    model: MODEL,
    voice: VOICE as any,
    input: text,
    instructions: SELENE_VOICE_INSTRUCTIONS,
    response_format: 'mp3',
  });
  const arrayBuf = await res.arrayBuffer();
  return Buffer.from(arrayBuf);
}
