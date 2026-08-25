# Knab Persistent Saldo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Knab-envelop-saldo's stoppen met maandelijks resetten naar nul. Budget wordt afgeleid uit een nieuw `knab_stortingen`-logboek (spiegelbeeld van het bestaande `knab_tx`-uitgavenlogboek), beide persistent in `settings.profiel` in plaats van de maand-gebonden `finance`-tabel. Een nieuwe "+ Storting"-knop trekt het bedrag direct van Hoofdrekening af.

**Architecture:** `knab` (envelope-shape, nu zonder `gestort`) en `knab_tx` verhuizen van `_db.fin.*` (maand-gebonden) naar `_db.settings.profiel.*` (persistent) — zelfde patroon als eerder toegepast op Hoofdrekening/Schulden/ANWB-regeling. Een nieuw `knab_stortingen`-logboek volgt exact het patroon van het bestaande `knab_tx`. "Budget" en "Saldo" per envelop worden voortaan berekend door de logboeken op te tellen, niet meer opgeslagen als los veld. Eenmalige migratie zet de huidige, actieve maandcijfers om naar de nieuwe persistente vorm.

**Tech Stack:** Vanilla HTML/CSS/JS, single-file app (`index.html`), Supabase-backed `settings.profiel` (via `_saveSettings()`)

## Global Constraints

- Single file: alle HTML, CSS en JS leeft in `index.html`
- Geen frameworks, geen build-stap, geen testrunner — verificatie is een `node -e` syntax-check plus een handmatige browser-doorloop
- Dark theme only (CSS vars: `--gold`, `--surface-2`, `--text`, `--text-muted`, `--danger`, `--success`)
- Bestaande helpers: `finFmt(n)` formatteert bedragen, `esc(s)` escaped HTML, `localDateStr(date?)` geeft `YYYY-MM-DD` (vandaag als geen argument), `finMaandKey()` geeft `YYYY-MM` van vandaag, `getHoofdrekeningSaldo()`/`saveHoofdrekeningSaldo(n)`, `showToast(msg)`
- Scope: alleen Knab-enveloppen. Vaste lasten, Schulden, ANWB-betalingsregeling blijven ongewijzigd — zie `docs/superpowers/specs/2026-08-25-knab-persistent-saldo-design.md`
- Geen reconstructie van maanden vóór vandaag — doorlopend saldo begint bij het huidige, actieve bedrag ("vanaf nu")
- Deploy: `git push` naar master triggert Netlify deploy (niet automatisch pushen — wacht op akkoord)

---

### Task 1: Persistent Knab-data, stortingen-logboek, UI en migratie

**Files:**
- Modify: `index.html:1568-1574` (`FIN_DEFAULT_KNAB`)
- Modify: `index.html:1180-1188` (`_saveFinance` — `knab`/`knab_tx` niet meer meesturen)
- Modify: `index.html:1600-1620` (`getFinKnab`, `saveFinKnab`, `getKnabTx`, `saveKnabTx`, `addKnabTx`, `deleteKnabTx`, `calcKnabUitgegeven`)
- Modify: `index.html:1665-1677` (`calcKnabBespaard`, `calcKnabStortingen` — verwijderen)
- Modify: `index.html:1697-1746` (`buildFinDashboard` — "Knab stortingen"-regel verwijderen)
- Modify: `index.html:1809-1932` (`buildFinKnab`, `submitKnabTx`, `removeKnabTx`, `knabTxSummary`, `saveKnabSetup`, `editKnabCard`, `saveEditKnab`)
- Modify: `index.html:2137-2145` (`buildSnapshot` — verwijderen, dode code)
- Modify: `index.html:2152-2162` (`resetFinancien`)
- Modify: `index.html:2200-2220` (`buildFinTimeline`)
- Modify: `index.html:1102-1116` (`loadAllData` — migratie toevoegen)

**Interfaces:**
- Consumes: `localDateStr(date?) → string`, `finFmt(n) → string`, `esc(s) → string`, `finMaandKey() → string`, `getHoofdrekeningSaldo()/saveHoofdrekeningSaldo(n)`, `showToast(msg)`, `_saveSettings() → void` (bestaand, schrijft `_db.settings.profiel` naar Supabase)
- Produces:
  - `getFinKnab() → array` van `{id, naam, doel}` (geen `gestort` meer)
  - `saveFinKnab(list) → void`
  - `getKnabTx() → array` van `{id, knabId, bedrag, omschrijving, datum}` — **signatuur wijzigt: geen `mk`-parameter meer**
  - `saveKnabTx(list) → void` — **signatuur wijzigt: geen `mk`-parameter meer**
  - `addKnabTx(knabId, bedrag, omschrijving) → void` (ongewijzigd)
  - `deleteKnabTx(txId) → void` (ongewijzigd)
  - `calcKnabUitgegeven(knabId) → number` — **signatuur wijzigt: geen `mk`-parameter meer**
  - `getKnabStortingen() → array` van `{id, knabId, bedrag, datum}` — nieuw
  - `saveKnabStortingen(list) → void` — nieuw
  - `calcKnabGestort(knabId) → number` — nieuw
  - `addKnabStorting(knabId, bedrag) → void` — nieuw, trekt ook van Hoofdrekening af
  - `submitKnabStorting(knabId) → void` — nieuw, leest het "+Storting"-invoerveld en roept `addKnabStorting`

- [ ] **Step 1: `FIN_DEFAULT_KNAB` — `gestort`-veld weghalen**

Vervang regels 1568-1574 in `index.html`:

```javascript
const FIN_DEFAULT_KNAB = [
  { id:1, naam:'Benzine · 4373',          doel:'Benzine' },
  { id:2, naam:'Boodschappen · 3881',     doel:'Boodschappen' },
  { id:3, naam:'Kleding · 8100',          doel:'Kleding' },
  { id:4, naam:'Uit eten · 9439',         doel:'Uit eten' },
  { id:5, naam:'AI Abonnementen · 2648',  doel:'AI Abonnementen' },
];
```

- [ ] **Step 1b: `_saveFinance` — `knab`/`knab_tx` niet meer meesturen**

`_db.fin.knab`/`_db.fin.knab_tx` worden na deze migratie niet meer bijgewerkt (die data leeft voortaan in `_db.settings.profiel`), dus zouden hier alleen nog de verouderde snapshot van bij het inladen van de pagina wegschrijven naar nieuwe `finance`-rijen. Vervang regels 1180-1188 in `index.html`:

```javascript
function _saveFinance() {
  const f = _db.fin;
  sb.from('finance').upsert({
    user_id: currentUser.id, month_key: finMaandKey(),
    vaste: f.vaste, betaald: f.betaald,
    salaris: f.salaris, salaris_ontvangen: f.salaris_ontvangen,
    salaris_datum: f.salaris_datum, history: f.history || []
  }, { onConflict: 'user_id,month_key' }).then(r => { if(r.error) console.error('fin save:', r.error); });
}
```

- [ ] **Step 2: Data-laag — knab, knab_tx en nieuw knab_stortingen persistent maken**

Vervang regels 1600-1620 in `index.html` (van `function getFinKnab()` t/m het einde van `calcKnabUitgegeven`):

```javascript
function getFinKnab()      { return _db.settings.profiel?.knab || FIN_DEFAULT_KNAB; }
function saveFinKnab(l)    { _db.settings.profiel = { ...(_db.settings.profiel||{}), knab: l }; _saveSettings(); }

function getKnabTx() {
  return _db.settings.profiel?.knab_tx || [];
}
function saveKnabTx(list) {
  _db.settings.profiel = { ...(_db.settings.profiel||{}), knab_tx: list };
  _saveSettings();
}
function addKnabTx(knabId, bedrag, omschrijving) {
  const list = getKnabTx();
  list.push({ id: Date.now(), knabId, bedrag, omschrijving: omschrijving || '', datum: localDateStr() });
  saveKnabTx(list);
}
function deleteKnabTx(txId) {
  saveKnabTx(getKnabTx().filter(t => t.id !== txId));
}
function calcKnabUitgegeven(knabId) {
  return getKnabTx().filter(t => t.knabId === knabId).reduce((s, t) => s + t.bedrag, 0);
}

function getKnabStortingen() {
  return _db.settings.profiel?.knab_stortingen || [];
}
function saveKnabStortingen(list) {
  _db.settings.profiel = { ...(_db.settings.profiel||{}), knab_stortingen: list };
  _saveSettings();
}
function calcKnabGestort(knabId) {
  return getKnabStortingen().filter(s => s.knabId === knabId).reduce((s, t) => s + t.bedrag, 0);
}
function addKnabStorting(knabId, bedrag) {
  const list = getKnabStortingen();
  list.push({ id: Date.now(), knabId, bedrag, datum: localDateStr() });
  saveKnabStortingen(list);
  saveHoofdrekeningSaldo(getHoofdrekeningSaldo() - bedrag);
}
```

- [ ] **Step 3: `calcKnabBespaard` en `calcKnabStortingen` verwijderen (dode/kapotte code)**

Deze twee functies rekenen met het oude `k.gestort`-veld dat nu niet meer bestaat. `calcKnabBespaard` wordt alleen aangeroepen vanuit `buildSnapshot` (zelf ongebruikt, wordt in Step 9 verwijderd). `calcKnabStortingen` wordt alleen gebruikt voor de "Knab stortingen"-regel in het dashboard (wordt in Step 4 verwijderd, want overlapt nu met de al live bijgehouden Hoofdrekening).

Vervang regels 1665-1677 in `index.html`:

```javascript
function calcVasteTotaal()    { return getFinVaste().reduce((s,v) => s + v.bedrag, 0); }
```

(Dit is de regel die er al vóór `calcKnabBespaard` stond — laat die staan, verwijder alleen de twee functies erna tot aan de `// FORMAT`-comment.)

- [ ] **Step 4: `buildFinDashboard` — "Knab stortingen"-regel weghalen**

Vervang in `index.html` (rond regel 1697-1746):

```javascript
function buildFinDashboard() {
  const el = document.getElementById('finDashboard'); if(!el) return;
  const salaris    = getFinSalaris();
  const alBetaald  = calcBetaaldTotaal();
  const komtNog    = calcOnbetaaldTotaal();
  const dec        = new Date().getMonth() === 11;
  const inkomen    = dec ? salaris * 2 : salaris;

  const echtRest   = getHoofdrekeningSaldo() - komtNog;
  const positief   = echtRest >= 0;

  const vaste      = getFinVaste();
  const betaaldN   = Object.keys(getFinBetaald()).filter(id => vaste.some(v => String(v.id)===id)).length;

  const today        = new Date();
  const salDatum     = getFinSalarisDatum();
  let pct = 0, cyclusDag = 0, cyclusLen = 30;
  if (salDatum) {
    const start = new Date(salDatum); start.setHours(0,0,0,0);
    const now = new Date(); now.setHours(0,0,0,0);
    cyclusDag = Math.floor((now - start) / 86400000);
    cyclusLen = 30;
    pct = Math.min(100, Math.round((cyclusDag / cyclusLen) * 100));
  }

  const maandNaam = today.toLocaleDateString('nl-NL',{month:'long',year:'numeric'});
  const lbl = document.getElementById('finMaandLabel');
  if(lbl) lbl.textContent = maandNaam.charAt(0).toUpperCase() + maandNaam.slice(1);

  el.innerHTML = `
    <div class="fin-dashboard">
      <div class="fin-row">
        <span class="fin-row-label">Netto salaris</span>
        <span class="fin-row-amount fin-positive">+ ${finFmt(salaris)}</span>
      </div>
      ${dec ? `<div class="fin-row"><span class="fin-row-label">13e maand</span><span class="fin-row-amount fin-positive">+ ${finFmt(salaris)}</span></div>` : ''}
      <div class="fin-row">
        <span class="fin-row-label">Al van rekening (${betaaldN}/${vaste.length})</span>
        <span class="fin-row-amount" style="color:var(--danger)">- ${finFmt(alBetaald)}</span>
      </div>
      <div class="fin-row">
        <span class="fin-row-label">Komt nog deze maand</span>
        <span class="fin-row-amount" style="color:#E2A020">- ${finFmt(komtNog)}</span>
      </div>
    </div>
    <div class="fin-dash-card" style="margin-bottom:10px">
      <div class="fin-dash-card-label">Echt restant</div>
      <div class="fin-dash-card-amount ${positief?'fin-positive':'fin-negative'}">${positief?'+':'−'} ${finFmt(Math.abs(echtRest))}</div>
      <div class="fin-dash-card-sub">Na alle lasten</div>
```

(De rest van de functie — vanaf de Hoofdrekening-invoerrij tot en met `buildFinPaydayBanner();\n}` — blijft ongewijzigd, alleen de `knabStort`-variabele en de bijbehorende `${knabStort > 0 ? ... }`-rij zijn hierboven weggehaald.)

- [ ] **Step 5: `buildFinKnab` — budget/saldo uit logboeken berekenen, "+ Storting"-knop toevoegen**

Vervang regels 1809-1854 in `index.html`:

```javascript
function buildFinKnab() {
  const el = document.getElementById('finKnab'); if(!el) return;
  const knab = getFinKnab();
  const txAll = getKnabTx();
  el.innerHTML = knab.map(k => {
    const hasGoal = k.doel && k.doel.trim() !== '';
    const gestort = calcKnabGestort(k.id);
    const uitgeg = calcKnabUitgegeven(k.id);
    const saldo = gestort - uitgeg;
    const pct = gestort > 0 ? Math.min(100, Math.round((uitgeg / gestort) * 100)) : 0;
    const barClr = pct >= 90 ? 'var(--danger)' : pct >= 70 ? '#E2A020' : 'var(--success)';
    const txList = txAll.filter(t => t.knabId === k.id);
    return `<div class="envelope-card${hasGoal?' active':''}" id="knab-card-${k.id}">
      <div class="envelope-name">${esc(knabDisplayNaam(k))}</div>
      ${hasGoal ? `
        <div class="envelope-goal">${esc(k.doel)}</div>
        <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--text-muted);margin-bottom:4px">
          <span>Budget: ${finFmt(gestort)}</span>
          <span>Uitgeg: ${finFmt(uitgeg)}</span>
        </div>
        <div class="envelope-bar-track"><div class="envelope-bar-fill" style="width:${pct}%;background:${barClr}"></div></div>
        <div class="envelope-amounts" style="margin-top:6px">
          <span class="${saldo>0?'envelope-over':'envelope-leeg'}">Saldo: ${finFmt(saldo)}</span>
        </div>
        <div class="knab-tx-form">
          <input type="number" id="knab_storting_bedrag_${k.id}" placeholder="€" step="0.01" min="0" style="flex:1">
          <button class="btn-small" style="padding:7px 11px;font-size:12px;flex-shrink:0" onclick="submitKnabStorting(${k.id})">+ Storting</button>
        </div>
        <div class="knab-tx-form">
          <input type="number" id="knab_tx_bedrag_${k.id}" placeholder="€" step="0.01" min="0" style="flex:0.7">
          <input type="text" id="knab_tx_desc_${k.id}" placeholder="Wat?" style="flex:1">
          <button class="btn-small" style="padding:7px 11px;font-size:12px;flex-shrink:0" onclick="submitKnabTx(${k.id})">+</button>
        </div>
        ${txList.length ? `<div class="knab-tx-list">${txList.slice().sort((a,b) => b.id - a.id).map(t => `
          <div class="knab-tx-item">
            <span class="knab-tx-date">${t.datum.slice(5)}</span>
            <span class="knab-tx-desc">${esc(t.omschrijving) || '—'}</span>
            <span class="knab-tx-amount">- ${finFmt(t.bedrag)}</span>
            <button class="knab-tx-del" onclick="removeKnabTx(${t.id})" title="Verwijderen">&#215;</button>
          </div>`).join('')}</div>` : ''}
        ${knabTxSummary(k.id)}
        <button class="fin-edit-btn" style="width:100%;margin-top:8px;font-size:11px" onclick="editKnabCard(${k.id})">Bewerken</button>
      ` : `
        <div class="envelope-goal" style="color:var(--text-muted);font-style:italic;font-size:12px">Niet ingesteld</div>
        <input type="text" id="knab_doel_${k.id}" class="plain-input" placeholder="Doel (bijv. Benzine)" style="width:100%;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);padding:8px 10px;border-radius:8px;font-size:13px;outline:none;margin-bottom:7px;box-sizing:border-box;font-family:inherit">
        <input type="number" id="knab_gestort_${k.id}" class="plain-input" placeholder="Eerste storting €" style="width:100%;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);padding:8px 10px;border-radius:8px;font-size:13px;outline:none;margin-bottom:8px;box-sizing:border-box;font-family:inherit">
        <button class="save-btn" style="width:100%;margin-top:0;padding:9px" onclick="saveKnabSetup(${k.id})">Instellen</button>
      `}
    </div>`;
  }).join('');
}

function submitKnabStorting(knabId) {
  const bedragEl = document.getElementById('knab_storting_bedrag_' + knabId);
  const bedrag = parseFloat(bedragEl?.value);
  if (isNaN(bedrag) || bedrag <= 0) { showToast('Voer een bedrag in'); return; }
  addKnabStorting(knabId, bedrag);
  buildFinKnab();
  buildFinDashboard();
  showToast('Storting toegevoegd');
}
```

- [ ] **Step 6: `submitKnabTx` en `removeKnabTx` — aanroepen ongewijzigd, alleen dashboard-refresh checken**

Deze twee functies (regels ~1856-1872, na Step 5's vervanging verschoven) blijven inhoudelijk ongewijzigd — `getKnabTx()`/`addKnabTx()`/`deleteKnabTx()` hebben al hun `mk`-parameter laten vallen in Step 2, en deze functies riepen die al zonder `mk` aan. Geen code-wijziging nodig hier; alleen verifiëren tijdens Step 12 dat uitgaven nog steeds correct worden toegevoegd/verwijderd.

- [ ] **Step 7: `saveKnabSetup` — eerste bedrag wordt een storting, geen los `gestort`-veld**

Vervang de functie (rond regel 1884-1900 vóór Step 5's verschuivingen — zoek op `function saveKnabSetup`):

```javascript
function saveKnabSetup(id) {
  const doel    = document.getElementById('knab_doel_'    + id)?.value.trim();
  const gestort = parseFloat(document.getElementById('knab_gestort_' + id)?.value);
  if (!doel) { showToast('Voer een doel in'); return; }
  const knab = getFinKnab();
  const k = knab.find(k => k.id === id);
  if (k) k.doel = doel;
  saveFinKnab(knab);
  const bedrag = isNaN(gestort) ? 0 : gestort;
  if (bedrag > 0) addKnabStorting(id, bedrag);
  buildFinDashboard();
  buildFinKnab();
  showToast('Envelop ingesteld');
}
```

- [ ] **Step 8: `editKnabCard` en `saveEditKnab` — alleen nog doel/naam corrigeren, geen budget-veld**

Vervang de twee functies (zoek op `function editKnabCard`):

```javascript
function editKnabCard(id) {
  const knab = getFinKnab();
  const k    = knab.find(k => k.id === id);
  const el   = document.getElementById('knab-card-' + id);
  if (!k || !el) return;
  el.innerHTML = `
    <div class="envelope-name">${esc(knabDisplayNaam(k))}</div>
    <input type="text" id="edit_kdoel_${id}" class="plain-input" value="${esc(k.doel)}" placeholder="Doel" style="width:100%;background:var(--surface-2);border:1px solid var(--gold);color:var(--text);padding:8px 10px;border-radius:8px;font-size:13px;outline:none;margin-bottom:10px;box-sizing:border-box;font-family:inherit">
    <div style="display:flex;gap:6px">
      <button class="save-btn" style="flex:2;margin:0;padding:9px;font-size:12px" onclick="saveEditKnab(${id})">Opslaan</button>
      <button class="btn-outline" style="flex:1;padding:9px;font-size:12px" onclick="buildFinKnab()">&#215;</button>
    </div>`;
}

function saveEditKnab(id) {
  const doel    = document.getElementById('edit_kdoel_' + id)?.value.trim();
  const knab    = getFinKnab();
  const k       = knab.find(k => k.id === id);
  if (k) k.doel = doel || '';
  saveFinKnab(knab);
  buildFinKnab();
  showToast('Envelop bijgewerkt');
}
```

- [ ] **Step 9: `buildSnapshot` verwijderen (dode code, gebruikt niet-bestaand `gestort`-veld)**

Zoek `function buildSnapshot(mk) {` in `index.html` en verwijder de hele functie (van `// MAAND-SNAPSHOT opslaan voor historie` boven `finSaveMaandSnapshot` t/m de sluitende `}` van `buildSnapshot`), **behalve** `finSaveMaandSnapshot` en `getFinHistory` zelf — die blijven staan:

```javascript
// MAAND-SNAPSHOT opslaan voor historie
function finSaveMaandSnapshot() {
  // History is now computed from finance table rows at load time
}

function getFinHistory() {
  return _db.finHistory || [];
}
```

- [ ] **Step 10: `resetFinancien` — Knab niet meer resetten**

Vervang regels 2152-2162 in `index.html`:

```javascript
function resetFinancien() {
  if (!confirm('Weet je het zeker? Alle betaald-statussen worden op nul gezet. Vaste lasten, Knab-saldo, Schulden en Hoofdrekening blijven intact.')) return;
  _db.fin.betaald = {};
  _db.fin.salaris_ontvangen = false;
  _db.fin.salaris_datum = null;
  _saveFinance();
  showToast('✓ Financiën gereset');
  buildFinancieel();
}
```

- [ ] **Step 11: `buildFinTimeline` — Knab-events tonen op basis van dit-maand-stortingen**

Vervang regels 2200-2220 in `index.html` (t/m het einde van de `knab.forEach`-blok binnen `if (salOntvangen)`):

```javascript
function buildFinTimeline() {
  const el = document.getElementById('finTimeline'); if(!el) return;
  const salOntvangen = getFinSalarisOntvangen();
  const salaris = getFinSalaris();
  const vaste = getFinVaste();
  const knab = getFinKnab();
  const betaald = getFinBetaald();
  const today = new Date();
  const maandNr = today.getMonth();
  const MAANDEN = ['jan','feb','mrt','apr','mei','jun','jul','aug','sep','okt','nov','dec'];

  const events = [];

  if (salOntvangen) {
    events.push({ dag: 24, done: true, desc: 'Salaris ontvangen', amount: salaris, type: 'income', sort: 0 });
  }

  getKnabStortingen().filter(s => s.datum.startsWith(finMaandKey())).forEach(s => {
    const k = knab.find(kk => kk.id === s.knabId);
    const dag = new Date(s.datum+'T00:00:00').getDate();
    events.push({ dag, done: true, desc: '→ Knab ' + (k ? knabDisplayNaam(k) : ''), amount: s.bedrag, type: 'expense', sort: 1, indent: true });
  });

```

(De rest van de functie — vanaf `vaste.forEach(...)` — blijft ongewijzigd.)

- [ ] **Step 12: Migratie toevoegen in `loadAllData`**

Zoek in `index.html` de regel `_db.settings = settingsRes.data || { profiel: [], start_date: null, prev_appointment: null, next_appointment: null };` binnen `loadAllData()` (rond regel 1114) en voeg er direct ná toe:

```javascript
  if (!_db.settings.profiel?.knab) {
    const huidigeKnab = finRes.data?.knab || FIN_DEFAULT_KNAB;
    const huidigeTx   = finRes.data?.knab_tx || [];
    const stortingen  = huidigeKnab
      .filter(k => k.gestort > 0)
      .map(k => ({ id: Date.now() + k.id, knabId: k.id, bedrag: k.gestort, datum: localDateStr() }));
    _db.settings.profiel = {
      ...(_db.settings.profiel || {}),
      knab: huidigeKnab.map(({gestort, ...rest}) => rest),
      knab_tx: huidigeTx,
      knab_stortingen: stortingen
    };
    _saveSettings();
  }
```

- [ ] **Step 13: Syntax-check**

Run:

```bash
node -e "
const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const m = html.match(/<script>([\s\S]*?)<\/script>/);
try { new Function(m[1]); console.log('OK'); } catch (e) { console.log('SYNTAX ERROR:', e.message); }
"
```

Expected: `OK`

- [ ] **Step 14: Zoek-verificatie op verwijderde/hernoemde functies**

Run:

```bash
grep -n "calcKnabBespaard\|calcKnabStortingen\|buildSnapshot\|k\.gestort" index.html
```

Expected: geen matches (alle referenties naar het oude `gestort`-veld en de verwijderde functies zijn weg). Als er nog matches zijn, los ze op voordat je verder gaat.

- [ ] **Step 15: Test in browser**

Open de app (ingelogd), ga naar de Financiën-tab. Verifieer:

1. **Migratie:** de Knab-kaarten tonen bij eerste load dezelfde Budget/Uitgeg/Saldo-waarden als vóór de wijziging (bijv. Boodschappen: Budget €260,35, Uitgeg €39,67, Saldo €220,68).
2. **Storting toevoegen:** vul bij een envelop een bedrag in bij het nieuwe "+ Storting"-veld, klik de knop. Budget en Saldo gaan omhoog met dat bedrag; Hoofdrekening (verderop) gaat met hetzelfde bedrag omlaag.
3. **Uitgave toevoegen:** blijft werken zoals eerder (Saldo daalt, Hoofdrekening blijft ongewijzigd).
4. **Bewerken:** klik "Bewerken" op een envelop — er verschijnt alleen nog een naam/doel-veld, geen budget-invoer meer. Wijzig het doel, sla op — Budget/Saldo blijven ongewijzigd door deze actie.
5. **Nieuwe envelop instellen:** als er een envelop zonder doel is, vul doel + eerste bedrag in, klik "Instellen" — envelop krijgt het doel, Budget toont het ingevulde bedrag, Hoofdrekening daalt met dat bedrag.
6. **Maandtijdlijn:** toont een "→ Knab [naam]"-regel voor elke storting die vandaag is gedaan, met het werkelijke gestorte bedrag (niet het cumulatieve totaal).
7. **Reset-knop:** klik "Reset financiën", bevestig. Vaste-lasten-betaald-status gaat op nul, maar Knab-Budget/Saldo/Hoofdrekening blijven **ongewijzigd**.
8. **Ververs de pagina** na alle bovenstaande stappen — alle Knab-waarden (Budget, Uitgeg, Saldo) blijven precies zoals ze waren, ook al is dit een "nieuwe" pagina-load.

- [ ] **Step 16: Commit**

```bash
git add index.html
git commit -m "feat: maak Knab-saldo persistent met stortingen-logboek, i.p.v. maandelijkse reset"
```

---

## Post-plan

- Push naar `origin/master` pas na akkoord van de gebruiker (vast patroon in dit project — commits worden niet automatisch gepusht)

## Bekende beperking

"Maandhistorie" (`buildFinHistorie`) toont per afgesloten maand een "Maandrestant"-cijfer dat wordt berekend uit de `knab`/`knab_tx`-velden zoals die destijds in die maand's `finance`-rij stonden (regels ~1123-1124, `loadAllData`). Voor maanden ván vóór deze wijziging blijft dat correct (historische snapshot, wordt niet aangeraakt). Voor maanden ná deze wijziging bevatten nieuwe `finance`-rijen geen zinvolle `knab`-data meer (die velden worden niet meer geschreven, zie Step 1b), dus het "Maandrestant"-cijfer in Maandhistorie voor toekomstige maanden zal het Knab-aandeel niet meer correct meerekenen. Dit is een geaccepteerde beperking — Maandhistorie was al een klein, weinig gebruikt onderdeel (vergelijkbaar met de eerder verwijderde "Totaal bespaard"-kaart) en het echt oplossen vereist een nieuw soort maand-snapshot-mechanisme dat buiten de scope van deze wijziging valt.
