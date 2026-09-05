const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const start=html.indexOf('let maandwisselBezig = false;');
const end=html.indexOf('function buildFinAchterstandBanner()',start);
async function scenario(open,results){
 const old={salaris:3000,knab:[],betaald:{}};
 const db={fin:old,activeMaandKey:'2026-08',finHistory:[],settings:{}};
 let saves=0,report=0;
 const c=vm.createContext({_db:db,getFinVaste:()=>open?[{id:1}]:[],isVasteBetaald:()=>false,
  showToast:()=>{},financeSaveNotice:()=>{},_saveFinance:async()=>results[saves++],
  seedNieuweMaand:()=>({knab:[]}),volgendeMaandKey:()=> '2026-09',localDateStr:()=> '2026-09-05',
  berekenKnabDoorrol:()=>{},berekenGeleerdeDagen:()=>({}),finHistoryItem:r=>({_raw:r}),
  _saveSettings:()=>{},maandLabel:k=>k,buildFinancieel:()=>{},toonMaandOverzicht:()=>report++});
 vm.runInContext(html.slice(start,end),c);
 await vm.runInContext('voerMaandwisselUit(4000,null)',c);
 assert.equal(old.salaris,3000,'Historical salary must remain unchanged');
 return {db,saves,report};
}
(async()=>{
 let r=await scenario(true,[]); assert.equal(r.saves,0);assert.equal(r.db.activeMaandKey,'2026-08');
 r=await scenario(false,[false]);assert.equal(r.saves,1);assert.equal(r.report,0);
 r=await scenario(false,[true,false]);assert.equal(r.db.activeMaandKey,'2026-08');assert.equal(r.db.finHistory.length,0);
 r=await scenario(false,[true,true]);assert.equal(r.db.activeMaandKey,'2026-09');assert.equal(r.db.fin.salaris,4000);assert.equal(r.report,1);
 console.log('PASS: unpaid closure blocked, old-save failure, new-save failure, salary preservation, successful rollover. Offline mocks only.');
})().catch(e=>{console.error(e);process.exitCode=1;});
