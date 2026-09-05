const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('index.html', 'utf8');
const start = html.indexOf('let settingsSaveQueue = Promise.resolve();');
const end = html.indexOf('function _saveSessieUpdate(', start);
assert(start > 0 && end > start);
function setup(outcomes) {
  const notices = [], payloads = [];
  const c = vm.createContext({
    currentUser: {id:'test-owner'},
    _db: {settings:{profiel:{hoofdrekeningSaldo:100}}, preps:{}},
    financeSaveNotice:(message,retry,id)=>notices.push({message,retry,id}),
    sb:{from: table => {
      assert.equal(table,'settings');
      return {upsert:async payload=>{
        payloads.push(payload);
        const result=outcomes.shift();
        if(result==='throw')throw Error('offline');
        return {error:result==='error'?{}:null};
      }};
    }},
  });
  vm.runInContext(html.slice(start,end),c);
  return {c,notices,payloads};
}
(async()=>{
  let t=setup(['ok','ok']);
  const first=vm.runInContext('_saveSettings()',t.c);
  t.c._db.settings.profiel.hoofdrekeningSaldo=200;
  const second=vm.runInContext('_saveSettings()',t.c);
  assert.deepEqual(await Promise.all([first,second]),[true,true]);
  assert.deepEqual(t.payloads.map(p=>p.profiel.hoofdrekeningSaldo),[100,200]);
  assert(t.notices.every(n=>n.id==='settingsSaveNotice'));
  t=setup(['error','ok']);
  assert.equal(await vm.runInContext('_saveSettings()',t.c),false);
  assert.equal(await t.notices.at(-1).retry(),true);
  t=setup(['throw']);assert.equal(await vm.runInContext('_saveSettings()',t.c),false);
  t=setup([]);t.c.currentUser=null;
  assert.equal(await vm.runInContext('_saveSettings()',t.c),false);
  assert.equal(t.payloads.length,0);
  t=setup([]);
  const pending=vm.runInContext('_saveSettings()',t.c);
  t.c.currentUser={id:'another-user'};
  assert.equal(await pending,false);
  assert.equal(t.payloads.length,0);
  console.log('PASS: settings snapshot order, independent status, retry, network failure, signed-out and changed-user guards. Mock database only.');
})().catch(e=>{console.error(e);process.exitCode=1;});
