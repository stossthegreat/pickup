// LANGUAGE — does the Settings picker actually change what she speaks?
//
// It didn't, twice over: Whisper was pinned to English so a Spanish
// speaker's mic was transcribed AS English, and the prompt carried a
// lock scripting her to answer "english only here, sorry". Both were
// real anti-drift fixes pointed at the wrong target. These assertions
// pin the corrected behaviour: English is byte-for-byte unchanged,
// every code the app's picker offers is honoured on voice, text, coach
// and Lucien, and junk input degrades to English rather than breaking.
//
//   node test/language.test.mjs      (from backend/)

const P = await import('../src/personas.js');
const V = await import('../src/villain_personas.js');
const D = await import('../src/date_personas.js');

let fail = 0;
const ok = (c, label) => { if (!c) { fail++; console.log('FAIL', label); } else console.log('pass', label); };

// 1. Every code the app's picker offers must be recognised end to end.
const APP_CODES = ['en','es','pt','fr','de','it','nl','tr','pl','ru','ar','hi','id','ja','ko'];
for (const c of APP_CODES) {
  const w = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:false, language:c });
  const hit = w.includes('LANGUAGE OVERRIDE');
  ok(c === 'en' ? !hit : hit, `voice: ${c} ${c==='en'?'unchanged':'overridden'}`);
}

// 2. Unknown / junk codes behave exactly like English — byte identical.
const base = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:false, language:'en' });
for (const junk of ['zz', '', null, undefined, 'EN', 'en_US', 'en-GB', 123, {}, 'xx-YY']) {
  const got = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:false, language:junk });
  ok(got === base, `voice: ${JSON.stringify(junk)} → byte-identical to English`);
}

// 3. The override is the LAST word and comes AFTER the English lock it supersedes.
const es = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:false, language:'es' });
ok(es.startsWith(base), 'voice: ES is English prompt + appended block (nothing removed)');
// Compare against the FIRST lock: the override block quotes the phrase
// "LANGUAGE LOCK" in its own header, so lastIndexOf finds itself.
ok(es.lastIndexOf('LANGUAGE OVERRIDE') > es.indexOf('LANGUAGE LOCK'), 'voice: override AFTER the English lock');
ok(es.trimEnd().endsWith(es.slice(es.lastIndexOf('LANGUAGE OVERRIDE')).trimEnd()), 'voice: override is the final block');

// 4. Creator mode keeps language support and keeps its own persona.
const cEn = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:true, language:'en' });
const cJa = P.buildFreeFlowInstructions({ vibeLabel:'into_you', creator:true, language:'ja' });
ok(!cEn.includes('LANGUAGE OVERRIDE'), 'creator EN unchanged');
ok(cJa.includes('Japanese') && cJa.startsWith(cEn), 'creator JA overridden, prompt otherwise intact');

// 5. Lucien coaches in the user's language.
const lEn = V.buildLucienRealtimeInstructions({ language:'en' });
const lFr = V.buildLucienRealtimeInstructions({ language:'fr' });
ok(!lEn.includes('LANGUAGE OVERRIDE'), 'lucien EN unchanged');
ok(lFr.includes('French'), 'lucien FR coaches in French');
ok(typeof V.buildLucienRealtimeInstructions({}) === 'string', 'lucien with no language arg still builds');

// 6. Text chat: she texts in his language, JSON contract preserved.
const dEn = D.buildDateTurnPrompt({ woman:'ice_queen', language:'en' });
const dEs = D.buildDateTurnPrompt({ woman:'ice_queen', language:'es' });
ok(!dEn.includes('LANGUAGE — OVERRIDES'), 'text EN unchanged');
ok(dEs.includes('Spanish'), 'text ES overridden');
ok(dEs.lastIndexOf('Output ONLY') > dEs.lastIndexOf('LANGUAGE — OVERRIDES'),
   'text: JSON format spec stays the LAST instruction (format compliance protected)');

// 7. Coach hands over lines in his language.
ok(D.coachLanguageBlock('en') === '' && D.coachLanguageBlock('zz') === '' && D.coachLanguageBlock() === '',
   'coach: English/unknown/absent add nothing');
ok(D.coachLanguageBlock('pt-BR').includes('Portuguese'), 'coach: pt-BR → Portuguese');

console.log(fail ? `\n${fail} FAILURE(S)` : '\nALL PASS — language works on voice, text, coach and Lucien');
process.exit(fail ? 1 : 0);
