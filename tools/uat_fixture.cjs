// Disposable local test data only. Never point this at the application database.
const { createRequire } = require('node:module');
const path = require('node:path');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const backend = path.resolve(process.argv[2] || '../ispeak_backend');
const requireBackend = createRequire(path.join(backend, 'package.json'));
const mongoose = requireBackend('mongoose');
const jwt = requireBackend('jsonwebtoken');
const User = requireBackend('./models/User');
const Session = requireBackend('./models/SpeechSession');

async function main() {
  const uri = process.env.UAT_MONGO_URI;
  if (!/^mongodb:\/\/127\.0\.0\.1:\d+\/ispeak_uat_[a-z0-9_]+$/.test(uri || '')) {
    throw new Error('UAT_MONGO_URI must select an isolated localhost ispeak_uat_* database');
  }
  if (!process.env.JWT_SECRET || !process.env.UAT_TOKENS_FILE || !process.env.UAT_API_URL) throw new Error('Missing UAT configuration');
  await mongoose.connect(uri);
  await Session.createIndexes();
  const stamp = Date.now();
  const users = await User.insertMany(Array.from({length:100}, (_,i)=>({
    firstName:'Benchmark',lastName:String(i),username:`bench-${stamp}-${i}`,
    email:`bench-${stamp}-${i}@example.test`,password:'unusable-test-only-password',
  })));
  const tokens = users.map(user=>jwt.sign({userId:user._id.toString()},process.env.JWT_SECRET,{
    issuer:'ispeak-api',audience:'ispeak-clients',algorithm:'HS256',expiresIn:'2h',
  }));
  fs.writeFileSync(process.env.UAT_TOKENS_FILE,JSON.stringify(tokens));
  const history = await Session.insertMany(Array.from({length:45},(_,i)=>({
    userId:users[0]._id,createdAt:new Date(1700000000000 + Math.floor(i/3)*1000),
    language:i%2 ? 'English':'Taglish',status:'Completed',overallScore:i,
    transcription:'Long saved session text. '.repeat(500),wordTimestamps:[{word:'speech',start:0,end:1}],
  })));
  const headers={Authorization:`Bearer ${tokens[0]}`};
  const url=process.env.UAT_API_URL;
  const request=async endpoint=>{const r=await fetch(url+endpoint,{headers});assert.equal(r.status,200);return {response:r,body:await r.json()};};
  let cursor='',ids=[];
  do {
    const page=await request(`/sessions/${users[0]._id}?limit=20${cursor ? '&before='+cursor:''}`);
    assert.ok(page.body.length<=20);assert.equal(page.response.headers.get('x-total-count'),'45');
    assert.ok(page.body.every(row=>row.audioPath===undefined));
    ids.push(...page.body.map(row=>row._id));cursor=page.response.headers.get('x-next-cursor');
  } while(cursor);
  assert.equal(ids.length,45);assert.equal(new Set(ids).size,45);
  const full=await request(`/stats/${users[0]._id}`);
  const compact=await request(`/stats/${users[0]._id}?view=compact`);
  const summary=await request(`/stats/${users[0]._id}?view=summary`);
  assert.deepEqual(compact.body.overallStats,full.body.overallStats);
  assert.deepEqual(summary.body.overallStats,full.body.overallStats);
  assert.equal(compact.body.sessions.length,45);assert.equal(summary.body.sessions.length,0);
  assert.ok(compact.body.sessions.every(row=>row.transcription===undefined && row.wordTimestamps===undefined));
  const explain=await Session.find({userId:users[0]._id}).sort({createdAt:-1}).limit(20).explain('executionStats');
  assert.match(JSON.stringify(explain.queryPlanner.winningPlan),/userId_1_createdAt_-1/);
  const evidence={history_pages:3,history_sessions:ids.length,full_stats_bytes:Buffer.byteLength(JSON.stringify(full.body)),
    compact_stats_bytes:Buffer.byteLength(JSON.stringify(compact.body)),summary_stats_bytes:Buffer.byteLength(JSON.stringify(summary.body)),
    index:await Session.collection.indexes(),query_documents_examined:explain.executionStats.totalDocsExamined};
  console.log(JSON.stringify(evidence,null,2));
  // Synthetic database rows test pagination/payload correctness only, never inference throughput.
  await Session.deleteMany({_id:{$in:history.map(row=>row._id)}});
  await mongoose.disconnect();
}
main().catch(async error=>{console.error(error);await mongoose.disconnect();process.exitCode=1;});
