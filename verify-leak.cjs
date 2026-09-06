// Verifies the bank-balance reconciliation ("niet verklaard"): the gap between
// the app's running balance and the real bank balance, the per-period
// correction log, and that "gelijktrekken" syncs the balance and records the
// gap tagged with the current financial period. Offline, mock db only.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const html = fs.readFileSync('index.html', 'utf8');
const start = html.indexOf('function getEchtBanksaldo()');
const end = html.indexOf('function getFinKnab()', start);
assert.ok(start > 0 && end > start, 'leak helpers not found');
const src = html.slice(start, end);

function ctx({ profiel, appSaldo = 0, maand = '2026-09', today = '2026-09-06' }) {
  const db = { settings: { profiel } };
  let saved = 0;
  const c = vm.createContext({
    _db: db,
    getHoofdrekeningSaldo: () => appSaldo,
    finMaandKey: () => maand,
    localDateStr: () => today,
    finFmt: n => '€ ' + Number(n).toFixed(2),
    showToast: () => {},
    confirm: () => true,
    _saveSettings: () => { saved++; },
    buildFinDashboard: () => {},
  });
  vm.runInContext(src, c);
  return { db, c, get saved() { return saved; } };
}

// 1. No real balance entered -> no gap.
{
  const t = ctx({ profiel: {}, appSaldo: 579 });
  assert.equal(vm.runInContext('getNietVerklaard()', t.c), null);
}

// 2. App 579, real 548.60 -> unexplained 30.40.
{
  const t = ctx({ profiel: { echtBanksaldo: 548.60 }, appSaldo: 579 });
  assert.equal(vm.runInContext('getNietVerklaard()', t.c), 30.40);
}

// 3. Gelijktrekken: app-balance becomes the real balance, gap is logged for
//    the current period.
{
  const t = ctx({ profiel: { echtBanksaldo: 548.60, echtBanksaldoDatum: '2026-09-01' }, appSaldo: 579, maand: '2026-09' });
  vm.runInContext('trekBanksaldoGelijk()', t.c);
  const p = t.db.settings.profiel;
  assert.equal(p.hoofdrekeningSaldo, 548.60, 'app balance synced to real');
  assert.equal(p.hoofdrekeningCorrecties.length, 1, 'one correction logged');
  assert.equal(p.hoofdrekeningCorrecties[0].bedrag, 30.40);
  assert.equal(p.hoofdrekeningCorrecties[0].periode, '2026-09');
  assert.ok(t.saved >= 1);
}

// 4. Corrections are counted per financial period only.
{
  const t = ctx({
    profiel: { echtBanksaldo: 100, hoofdrekeningCorrecties: [
      { datum: '2026-08-10', bedrag: 12, periode: '2026-08' },
      { datum: '2026-09-02', bedrag: 8, periode: '2026-09' },
      { datum: '2026-09-04', bedrag: 5, periode: '2026-09' },
    ] },
    appSaldo: 100, maand: '2026-09',
  });
  assert.equal(vm.runInContext('getCorrectiesDezePeriode()', t.c), 13, 'only this period counts');
}

// 5. A near-zero gap does not create a correction.
{
  const t = ctx({ profiel: { echtBanksaldo: 200.001 }, appSaldo: 200, maand: '2026-09' });
  vm.runInContext('trekBanksaldoGelijk()', t.c);
  assert.equal(t.db.settings.profiel.hoofdrekeningCorrecties, undefined, 'no correction for a rounding-size gap');
}

console.log('PASS: unexplained-gap calculation, per-period correction log, and balance sync. Mock db only.');
