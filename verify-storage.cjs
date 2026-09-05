const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const start=html.indexOf('let financeSaveQueue = Promise.resolve();');
const end=html.indexOf('function _saveGoals()',start);
function setup(outcomes){
 const notices=[]; const payloads=[];
 const c=vm.createContext({currentUser:{id:'test-user'},_db:{fin:{salaris:100,vaste:[],knab:[],knab_tx:[],betaald:{}}},
  finMaandKey:()=> '2026-08',
  sb:{from:()=>({upsert:async payload=>{payloads.push(payload);const next=outcomes.shift();if(next==='throw')throw Error('offline');return {error:next==='error'?{}:null};}})},
 });
 vm.runInContext(html.slice(start,end),c);
 c.financeSaveNotice=(message,retry)=>notices.push({message,retry});
 return {c,notices,payloads};
}
(async()=>{
 let t=setup(['ok','ok']);
 const first=vm.runInContext('_saveFinance()',t.c);
 t.c._db.fin.salaris=200;
 const second=vm.runInContext('_saveFinance()',t.c);
 assert.deepEqual(await Promise.all([first,second]),[true,true]);
 assert.deepEqual(t.payloads.map(p=>p.salaris),[100,200]);
 t=setup(['error','ok']);
 assert.equal(await vm.runInContext('_saveFinance()',t.c),false);
 assert.equal(typeof t.notices.at(-1).retry,'function');
 assert.equal(await t.notices.at(-1).retry(),true);
 t=setup(['throw']);assert.equal(await vm.runInContext('_saveFinance()',t.c),false);
 t=setup([]);t.c.currentUser=null;
 assert.equal(await vm.runInContext('_saveFinance()',t.c),false);assert.equal(t.payloads.length,0);
 console.log('PASS: ordered snapshots, visible save failure, retry, network exception, signed-out guard. Mock database only.');
})().catch(e=>{console.error(e);process.exitCode=1;});
