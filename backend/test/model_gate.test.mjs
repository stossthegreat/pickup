// THE MODEL GATE — the full realtime model must be unreachable outside
// creator mode. Not "rarely used": unreachable.
//
// It leaked twice. Lucien had a carve-out returning the full model for
// every user, and a public debug endpoint hardcoded its own copy of the
// model name and minted full-model keys to anyone who asked. This test
// lifts the live gate out of the route and proves no input value opens
// it but boolean `true`, and that creator minting is itself capped.
//
//   node test/model_gate.test.mjs    (from backend/)

import fs from 'fs';
const src = fs.readFileSync(new URL('../src/routes/realtime.js', import.meta.url),'utf8');
// lift the two gate functions + their constants out verbatim
const pick = src.match(/const OPENAI_REALTIME_MODEL[\s\S]*?function pickRealtimeModel\([\s\S]*?\n}/)[0];
const thr  = src.match(/const CREATOR_MAX_PER_HOUR[\s\S]*?function creatorMintAllowed\([\s\S]*?\n}/)[0];
const mod = `${pick}\n${thr}\nexport { pickRealtimeModel, creatorMintAllowed, OPENAI_REALTIME_MODEL, OPENAI_REALTIME_MINI_MODEL, CREATOR_MAX_PER_HOUR };`;
fs.writeFileSync(new URL('./_gate.generated.mjs', import.meta.url), mod);
const g = await import(new URL('./_gate.generated.mjs', import.meta.url));

let fail = 0;
const eq = (a,b,label)=>{ if(a!==b){fail++;console.log('FAIL',label,a,'!=',b);} else console.log('pass',label,'→',a); };

// model gate
eq(g.pickRealtimeModel({creator:false}), 'gpt-realtime-mini', 'normal woman');
eq(g.pickRealtimeModel({creator:undefined}), 'gpt-realtime-mini', 'no flag');
eq(g.pickRealtimeModel({creator:'true'}), 'gpt-realtime-mini', "string 'true' is NOT the boolean — route coerces first");
eq(g.pickRealtimeModel({creator:true}), 'gpt-realtime', 'creator');
eq(g.pickRealtimeModel({}), 'gpt-realtime-mini', 'empty opts');

// no other arg can reach full
for (const junk of [{creator:0},{creator:''},{creator:null},{creator:'yes'},{creator:'1'},{creator:1},{creator:{}},{creator:[]},{creator:'true'},{creator:'TRUE'}]) {
  if (g.pickRealtimeModel(junk) === 'gpt-realtime') {
    fail++; console.log('FAIL leak via', JSON.stringify(junk));
  }
}
console.log('pass  no falsy/junk value reaches full model');

// creator throttle
const req = { headers:{'x-client-id':'a'.repeat(32)}, ip:'1.2.3.4' };
let allowed = 0;
for (let i=0;i<g.CREATOR_MAX_PER_HOUR+15;i++) if (g.creatorMintAllowed(req)) allowed++;
eq(allowed, g.CREATOR_MAX_PER_HOUR, `creator throttle caps at ${g.CREATOR_MAX_PER_HOUR}/hr`);
// a second install is unaffected
const req2 = { headers:{'x-client-id':'b'.repeat(32)}, ip:'1.2.3.4' };
eq(g.creatorMintAllowed(req2), true, 'second install has its own creator budget');

console.log(fail ? `\n${fail} FAILURE(S)` : '\nALL PASS — full model unreachable outside creator, and capped inside it');
process.exit(fail?1:0);
