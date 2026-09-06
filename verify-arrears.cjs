// Verifies the carried-over "achterstallige betalingen" flow: each unpaid post
// stays individually payable, paying one deducts it from the main account, and
// clearing the last one removes the arrears record. Offline, mock DOM/db only.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const html = fs.readFileSync('index.html', 'utf8');
const start = html.indexOf('function getFinAchterstand()');
const end = html.indexOf('function dismissAchterstandBanner()', start);
assert.ok(start > 0 && end > start, 'arrears helpers not found in index.html');
const src = html.slice(start, end);

function context(profiel) {
  const db = { settings: { profiel } };
  let saved = 0, rebuilt = 0;
  const ctx = vm.createContext({
    _db: db,
    document: { getElementById: () => null },
    getHoofdrekeningSaldo: () => db.settings.profiel.hoofdrekeningSaldo,
    _saveSettings: () => { saved++; },
    buildFinAchterstallig: () => { rebuilt++; },
    buildFinAchterstandBanner: () => {},
    buildFinDashboard: () => {},
    showToast: () => {},
    confirm: () => true,
    finFmt: n => '€ ' + Number(n).toFixed(2),
    maandLabel: k => String(k),
    esc: s => String(s),
  });
  vm.runInContext(src, ctx);
  return { db, ctx, get saved() { return saved; }, get rebuilt() { return rebuilt; } };
}

// 1. Legacy { bedrag, aantal } yields no payable posts.
{
  const t = context({ finAchterstand: { bron: '2026-07', bedrag: 90, aantal: 2 } });
  assert.equal(vm.runInContext('getFinAchterstandPosten().length', t.ctx), 0, 'legacy format must expose no posts');
}

// 2. Paying one of two posts: it is removed, its amount leaves the main account, settings persisted.
{
  const posten = [
    { id: 'a1', naam: 'Internet', bedrag: 62, bron: '2026-08' },
    { id: 'a2', naam: 'NS', bedrag: 6, bron: '2026-08' },
  ];
  const t = context({ hoofdrekeningSaldo: 1000, finAchterstand: { bron: '2026-08', posten } });
  vm.runInContext("betaalAchterstalligePost('a1')", t.ctx);
  const na = t.db.settings.profiel.finAchterstand;
  assert.equal(na.posten.length, 1, 'one post should remain');
  assert.equal(na.posten[0].id, 'a2', 'the unpaid post should remain');
  assert.equal(t.db.settings.profiel.hoofdrekeningSaldo, 938, 'main account reduced by 62');
  assert.ok(t.saved >= 1, 'settings must be saved');
}

// 3. Paying the last post clears the arrears record entirely.
{
  const t = context({ hoofdrekeningSaldo: 500, finAchterstand: { bron: '2026-08', posten: [{ id: 'x', naam: 'Gym', bedrag: 28, bron: '2026-08' }] } });
  vm.runInContext("betaalAchterstalligePost('x')", t.ctx);
  assert.equal(t.db.settings.profiel.finAchterstand, null, 'arrears cleared when empty');
  assert.equal(t.db.settings.profiel.hoofdrekeningSaldo, 472, 'main account reduced by 28');
}

// 4. Unknown id is a safe no-op.
{
  const t = context({ hoofdrekeningSaldo: 100, finAchterstand: { bron: '2026-08', posten: [{ id: 'y', naam: 'A', bedrag: 10, bron: '2026-08' }] } });
  vm.runInContext("betaalAchterstalligePost('nope')", t.ctx);
  assert.equal(t.db.settings.profiel.finAchterstand.posten.length, 1, 'nothing removed for unknown id');
  assert.equal(t.db.settings.profiel.hoofdrekeningSaldo, 100, 'balance untouched');
}

console.log('PASS: arrears posts stay individually payable, deduct from the main account, and clear when empty. Mock db only.');
