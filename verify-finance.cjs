const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('index.html', 'utf8');
assert.match(html, /Eenmalige uitgaven/, 'One-time purchase section must remain available');
assert.match(html, /eenmalige_uitgaven/, 'One-time purchases must persist in finance rows');
assert.match(html, /function berekenGeleerdeDagen/, 'Learned payment dates must remain available');
for (const [, source] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (source.trim()) new vm.Script(source);
}
const start = html.indexOf('function toggleVasteBetaald(id)');
const end = html.indexOf('\nfunction getFinSalaris()', start);
assert(start > 0 && end > start);
const paid = {};
let balance = 1000;
let timelineUpdates = 0;
const context = vm.createContext({
  getFinBetaald: () => paid,
  getFinVaste: () => [{id: 1, bedrag: 62}],
  getHoofdrekeningSaldo: () => balance,
  saveHoofdrekeningSaldo: value => { balance = value; },
  saveFinBetaald: () => {}, localDateStr: () => '2026-09-05',
  buildFinVaste: () => {}, buildFinDashboard: () => {},
  buildFinTimeline: () => { timelineUpdates++; },
});
vm.runInContext(html.slice(start, end), context);
const availableBefore = balance - 62;
vm.runInContext('toggleVasteBetaald(1)', context);
assert.equal(balance, 938);
assert.equal(paid['1'], '2026-09-05');
assert.equal(balance, availableBefore, 'Paid bill must not be subtracted twice');
vm.runInContext('toggleVasteBetaald(1)', context);
assert.equal(balance, 1000);
assert.equal(paid['1'], undefined);
assert.equal(timelineUpdates, 2);
console.log('PASS: inline JavaScript syntax, payment balance, undo toggle, timeline refresh. No network requests or production writes.');
