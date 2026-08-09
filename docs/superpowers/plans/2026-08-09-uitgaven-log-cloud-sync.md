# Uitgaven Log + Cloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Voeg 5 features toe aan de Daily Coach app: transactielog per Knab envelop, cloud sync via Supabase, sync-indicator, auto-save, en maandtotalen.

**Architecture:** Alle features worden gebouwd in het bestaande single-file `index.html` (statische HTML/CSS/JS). Cloud sync gebruikt een Netlify Function (`netlify/functions/sync.js`) die data opslaat in Supabase PostgreSQL. De frontend communiceert via fetch calls naar `/.netlify/functions/sync`.

**Tech Stack:** Vanilla JS, localStorage, Netlify Functions (Node.js), Supabase PostgreSQL (free tier)

## Global Constraints

- Geen frameworks, geen build tools — alles in `index.html` of losse `.js` bestanden voor Netlify Functions
- Alle localStorage keys beginnen met `lc_`
- CSS gebruikt bestaande variabelen: `--gold`, `--surface`, `--surface-2`, `--surface-3`, `--text`, `--text-muted`, `--danger`, `--success`, `--radius`, `--radius-sm`
- Deploy via Netlify (automatisch bij git push naar master)
- Private repo, single-user app — SYNC_KEY mag hardcoded
- Service Worker is network-first (`sw.js`, cache `daily-coach-v3`)
- App start op 24 augustus 2026

---

### Task 1: Transactielog data-laag + saldo-berekening

**Files:**
- Modify: `index.html:985-1009` (Knab data functies)
- Modify: `index.html:1037-1047` (`calcKnabBespaard`)

**Interfaces:**
- Consumes: `finMaandKey()` (bestaand, geeft `"2026-08"` formaat), `getFinKnab()` (bestaand, array van `{id, naam, doel, gestort}`)
- Produces:
  - `getKnabTx(maandKey?)` → `[{id, knabId, bedrag, omschrijving, datum}]`
  - `addKnabTx(knabId, bedrag, omschrijving)` → void (slaat op + triggert sync)
  - `deleteKnabTx(txId)` → void
  - `calcKnabUitgegeven(knabId, maandKey?)` → number
  - `calcKnabSaldo(knabId)` → number (= gestort - uitgegeven)

- [ ] **Step 1: Voeg transactie data-functies toe**

Voeg deze functies toe in `index.html` na regel 1009 (`setKnabSaldo`), vóór `function finMaandKey()`:

```javascript
function getKnabTx(mk) {
  mk = mk || finMaandKey();
  try { return JSON.parse(localStorage.getItem('lc_fin_knab_tx_' + mk) || '[]'); } catch { return []; }
}
function saveKnabTx(list, mk) {
  mk = mk || finMaandKey();
  localStorage.setItem('lc_fin_knab_tx_' + mk, JSON.stringify(list));
}
function addKnabTx(knabId, bedrag, omschrijving) {
  const list = getKnabTx();
  list.push({ id: Date.now(), knabId, bedrag, omschrijving: omschrijving || '', datum: localDateStr() });
  saveKnabTx(list);
}
function deleteKnabTx(txId) {
  saveKnabTx(getKnabTx().filter(t => t.id !== txId));
}
function calcKnabUitgegeven(knabId, mk) {
  return getKnabTx(mk).filter(t => t.knabId === knabId).reduce((s, t) => s + t.bedrag, 0);
}
```

- [ ] **Step 2: Update `calcKnabBespaard` om transacties te gebruiken**

Vervang de bestaande `calcKnabBespaard` functie (regel 1037-1047) met:

```javascript
function calcKnabBespaard() {
  const knab = getFinKnab();
  let totaal = 0;
  knab.forEach(k => {
    if (k.doel && k.gestort > 0) {
      totaal += k.gestort - calcKnabUitgegeven(k.id);
    }
  });
  return totaal;
}
```

- [ ] **Step 3: Verwijder oude saldo-check functies**

Verwijder de volgende functies die niet meer nodig zijn (het handmatige saldo-invoer model verdwijnt):

```javascript
// VERWIJDER deze 4 functies:
function getFinKnabSaldo() { ... }
function saveFinKnabSaldo(obj) { ... }
function getKnabSaldo(id) { ... }
function setKnabSaldo(id, val) { ... }
```

- [ ] **Step 4: Test handmatig**

Open de app in de browser. De Financiën tab moet nog laden zonder errors. De Knab kaarten tonen nu `Saldo: NaN` — dat is verwacht en wordt gefixed in Task 2.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: transactielog data-laag voor Knab enveloppen"
```

---

### Task 2: Knab envelop UI — transactie-invoer + lijst

**Files:**
- Modify: `index.html:1190-1277` (Knab UI functies: `buildFinKnab`, `updateKnabSaldo`, `editKnabCard`, `saveEditKnab`)
- Modify: `index.html` CSS sectie (nieuwe styles voor transactie-UI)

**Interfaces:**
- Consumes: `getKnabTx()`, `addKnabTx(knabId, bedrag, omschrijving)`, `deleteKnabTx(txId)`, `calcKnabUitgegeven(knabId)`, `getFinKnab()`, `esc()`, `finFmt()`, `showToast()`
- Produces: Bijgewerkte `buildFinKnab()` die transactie-gebaseerd saldo toont + inline formulier + transactielijst

- [ ] **Step 1: Voeg CSS toe voor transactie-UI**

Voeg toe aan de `<style>` sectie, na de bestaande envelope styles:

```css
.knab-tx-form { display:flex; gap:6px; margin-top:10px; }
.knab-tx-form input { flex:1; background:var(--surface-2); border:1px solid var(--surface-3); color:var(--text); padding:8px 10px; border-radius:8px; font-size:13px; outline:none; font-family:inherit; box-sizing:border-box; }
.knab-tx-form input:focus { border-color:var(--gold); }
.knab-tx-list { margin-top:10px; }
.knab-tx-item { display:flex; align-items:center; justify-content:space-between; padding:7px 0; border-bottom:1px solid var(--surface-3); font-size:12px; }
.knab-tx-item:last-child { border-bottom:none; }
.knab-tx-date { color:var(--text-muted); min-width:50px; }
.knab-tx-desc { flex:1; margin:0 8px; color:var(--text); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.knab-tx-amount { color:var(--danger); white-space:nowrap; }
.knab-tx-del { background:none; border:none; color:var(--text-muted); font-size:16px; cursor:pointer; padding:2px 6px; }
.knab-tx-del:hover { color:var(--danger); }
.knab-summary { margin-top:8px; font-size:11px; color:var(--text-muted); display:flex; gap:12px; }
```

- [ ] **Step 2: Herschrijf `buildFinKnab` voor transactie-model**

Vervang de volledige `buildFinKnab` functie met:

```javascript
function buildFinKnab() {
  const el = document.getElementById('finKnab'); if(!el) return;
  const knab = getFinKnab();
  const txAll = getKnabTx();
  el.innerHTML = knab.map(k => {
    const hasGoal = k.doel && k.doel.trim() !== '';
    const uitgeg = calcKnabUitgegeven(k.id);
    const saldo = k.gestort - uitgeg;
    const pct = k.gestort > 0 ? Math.min(100, Math.round((uitgeg / k.gestort) * 100)) : 0;
    const barClr = pct >= 90 ? 'var(--danger)' : pct >= 70 ? '#E2A020' : 'var(--success)';
    const txList = txAll.filter(t => t.knabId === k.id);
    return `<div class="envelope-card${hasGoal?' active':''}" id="knab-card-${k.id}">
      <div class="envelope-name">${esc(k.naam)}</div>
      ${hasGoal ? `
        <div class="envelope-goal">${esc(k.doel)}</div>
        <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--text-muted);margin-bottom:4px">
          <span>Budget: ${finFmt(k.gestort)}</span>
          <span>Uitgeg: ${finFmt(uitgeg)}</span>
        </div>
        <div class="envelope-bar-track"><div class="envelope-bar-fill" style="width:${pct}%;background:${barClr}"></div></div>
        <div class="envelope-amounts" style="margin-top:6px">
          <span class="${saldo>0?'envelope-over':'envelope-leeg'}">Saldo: ${finFmt(saldo)}</span>
        </div>
        <div class="knab-tx-form">
          <input type="number" id="knab_tx_bedrag_${k.id}" placeholder="€" step="0.01" min="0" style="flex:0.7">
          <input type="text" id="knab_tx_desc_${k.id}" placeholder="Omschrijving" style="flex:1">
          <button class="btn-small" style="padding:7px 11px;font-size:12px;flex-shrink:0" onclick="submitKnabTx(${k.id})">+</button>
        </div>
        ${txList.length ? `<div class="knab-tx-list">${txList.sort((a,b) => b.id - a.id).map(t => `
          <div class="knab-tx-item">
            <span class="knab-tx-date">${t.datum.slice(5)}</span>
            <span class="knab-tx-desc">${esc(t.omschrijving) || '—'}</span>
            <span class="knab-tx-amount">- ${finFmt(t.bedrag)}</span>
            <button class="knab-tx-del" onclick="removeKnabTx(${t.id})" title="Verwijderen">&#215;</button>
          </div>`).join('')}</div>` : ''}
        <button class="fin-edit-btn" style="width:100%;margin-top:8px;font-size:11px" onclick="editKnabCard(${k.id})">Bewerken</button>
      ` : `
        <div class="envelope-goal" style="color:var(--text-muted);font-style:italic;font-size:12px">Niet ingesteld</div>
        <input type="text" id="knab_doel_${k.id}" placeholder="Doel (bijv. Benzine)" style="width:100%;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);padding:8px 10px;border-radius:8px;font-size:13px;outline:none;margin-bottom:7px;box-sizing:border-box;font-family:inherit">
        <input type="number" id="knab_gestort_${k.id}" placeholder="Budget € / mnd" style="width:100%;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);padding:8px 10px;border-radius:8px;font-size:13px;outline:none;margin-bottom:8px;box-sizing:border-box;font-family:inherit">
        <button class="save-btn" style="width:100%;margin-top:0;padding:9px" onclick="saveKnabSetup(${k.id})">Instellen</button>
      `}
    </div>`;
  }).join('');
}
```

- [ ] **Step 3: Voeg `submitKnabTx` en `removeKnabTx` toe**

Voeg toe na de `buildFinKnab` functie:

```javascript
function submitKnabTx(knabId) {
  const bedragEl = document.getElementById('knab_tx_bedrag_' + knabId);
  const descEl = document.getElementById('knab_tx_desc_' + knabId);
  const bedrag = parseFloat(bedragEl?.value);
  if (isNaN(bedrag) || bedrag <= 0) { showToast('Voer een bedrag in'); return; }
  addKnabTx(knabId, bedrag, descEl?.value?.trim() || '');
  buildFinKnab();
  buildFinDashboard();
  showToast('Uitgave toegevoegd');
}

function removeKnabTx(txId) {
  deleteKnabTx(txId);
  buildFinKnab();
  buildFinDashboard();
  showToast('Uitgave verwijderd');
}
```

- [ ] **Step 4: Verwijder oude `updateKnabSaldo` functie**

Verwijder de `updateKnabSaldo` functie (regel 1231-1239) — deze is niet meer nodig.

- [ ] **Step 5: Test in browser**

Open de Financiën tab. Controleer:
1. Knab kaarten tonen "Budget" en "Saldo" (berekend uit transacties, niet handmatig)
2. "+ Uitgave" formulier verschijnt met bedrag + omschrijving velden
3. Een uitgave toevoegen verlaagt het saldo direct
4. Transactielijst toont datum, omschrijving, bedrag
5. X-knop verwijdert een transactie en herstelt het saldo
6. Dashboard past mee aan

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: Knab envelop transactie-invoer en -lijst"
```

---

### Task 3: Maandtotaal per envelop

**Files:**
- Modify: `index.html` — `buildFinKnab` functie (summary toevoegen)

**Interfaces:**
- Consumes: `getKnabTx()`, `calcKnabUitgegeven()`, `finFmt()`
- Produces: Visuele samenvatting onder elke Knab kaart (count, totaal, meest voorkomende omschrijving)

- [ ] **Step 1: Voeg `knabTxSummary` helper toe**

Voeg toe na `removeKnabTx`:

```javascript
function knabTxSummary(knabId) {
  const txList = getKnabTx().filter(t => t.knabId === knabId);
  if (!txList.length) return '';
  const totaal = txList.reduce((s, t) => s + t.bedrag, 0);
  const counts = {};
  txList.forEach(t => { const d = t.omschrijving || '—'; counts[d] = (counts[d]||0) + 1; });
  const topDesc = Object.entries(counts).sort((a,b) => b[1] - a[1])[0][0];
  return `<div class="knab-summary"><span>${txList.length}x</span><span>${finFmt(totaal)}</span><span>${esc(topDesc)}</span></div>`;
}
```

- [ ] **Step 2: Voeg summary toe in `buildFinKnab`**

In de `buildFinKnab` functie, voeg na de transactielijst (`knab-tx-list`) en vóór de "Bewerken" knop:

```javascript
        ${knabTxSummary(k.id)}
```

De regel wordt dus:
```javascript
        ${txList.length ? `<div class="knab-tx-list">...</div>` : ''}
        ${knabTxSummary(k.id)}
        <button class="fin-edit-btn" ...>Bewerken</button>
```

- [ ] **Step 3: Test in browser**

Voeg 3+ transacties toe aan een envelop. Controleer:
- "3x" — "€38,40" — "McDonald's" verschijnt onder de lijst
- Bij 0 transacties verschijnt geen summary

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: maandtotaal samenvatting per Knab envelop"
```

---

### Task 4: Auto-save met debounce

**Files:**
- Modify: `index.html` — nieuwe `autoSave` module + koppeling aan tekstvelden

**Interfaces:**
- Consumes: `saveToday()`, `saveWeek()` (bestaand), alle textarea/input IDs: `journalAnswer`, `q1`, `q2`, `q3`, `t1-toelichting`..`t4-toelichting`, `tq0`, `tq1`, `wq1`..`wq5`
- Produces: `setupAutoSave()` — aangeroepen vanuit `init()`

- [ ] **Step 1: Voeg autoSave functie toe**

Voeg toe vóór de `init()` functie:

```javascript
let _autoSaveTimer = null;
function setupAutoSave() {
  const todayFields = ['journalAnswer','q1','q2','q3','t1-toelichting','t2-toelichting','t3-toelichting','t4-toelichting','tq0','tq1'];
  const weekFields = ['wq1','wq2','wq3','wq4','wq5'];
  function debounce(fn) {
    clearTimeout(_autoSaveTimer);
    _autoSaveTimer = setTimeout(fn, 2000);
  }
  todayFields.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('input', () => debounce(saveToday));
  });
  weekFields.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('input', () => debounce(saveWeek));
  });
}
```

- [ ] **Step 2: Roep `setupAutoSave` aan in `init()`**

Voeg toe in de `init()` functie, na `renderTherapySessions();`:

```javascript
  setupAutoSave();
```

- [ ] **Step 3: Test in browser**

1. Open Vandaag-tab, typ iets in het journaalveld
2. Wacht 2 seconden — toast "✓ Dag opgeslagen" verschijnt automatisch
3. Herlaad de pagina — tekst is bewaard
4. Ga naar Week-tab, typ iets — auto-save na 2 sec

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: auto-save met 2s debounce voor alle tekstvelden"
```

---

### Task 5: Netlify Function + Supabase sync backend

**Files:**
- Create: `netlify/functions/sync.js`
- Create: `netlify.toml`

**Interfaces:**
- Consumes: Supabase REST API via `@supabase/supabase-js`
- Produces:
  - `GET /.netlify/functions/sync` → `{ data: [{key, value, updated_at}] }`
  - `POST /.netlify/functions/sync` → `{ ok: true }` (body: `{items: [{key, value, updated_at}]}`)
  - Auth: `Authorization: Bearer <SYNC_KEY>` header vereist

**Benodigde env vars (Netlify dashboard):**
- `SUPABASE_URL` — bijv. `https://xxxxx.supabase.co`
- `SUPABASE_ANON_KEY` — Supabase anon/public key
- `SYNC_KEY` — willekeurige string voor auth

- [ ] **Step 1: Maak `netlify.toml`**

```toml
[build]
  functions = "netlify/functions"
  publish = "."
```

- [ ] **Step 2: Installeer supabase-js**

```bash
cd C:\Users\apz20\Documents\life-coach
npm init -y
npm install @supabase/supabase-js
```

- [ ] **Step 3: Schrijf `netlify/functions/sync.js`**

```javascript
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

exports.handler = async (event) => {
  const authHeader = event.headers.authorization || '';
  if (authHeader !== 'Bearer ' + process.env.SYNC_KEY) {
    return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
  }

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }

  if (event.httpMethod === 'GET') {
    const { data, error } = await supabase
      .from('sync_data')
      .select('key, value, updated_at');
    if (error) return { statusCode: 500, headers, body: JSON.stringify({ error: error.message }) };
    return { statusCode: 200, headers, body: JSON.stringify({ data }) };
  }

  if (event.httpMethod === 'POST') {
    const { items } = JSON.parse(event.body);
    if (!Array.isArray(items)) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'items array required' }) };
    }
    for (const item of items) {
      const { error } = await supabase
        .from('sync_data')
        .upsert({ key: item.key, value: item.value, updated_at: item.updated_at }, { onConflict: 'key' });
      if (error) return { statusCode: 500, headers, body: JSON.stringify({ error: error.message }) };
    }
    return { statusCode: 200, headers, body: JSON.stringify({ ok: true }) };
  }

  return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method not allowed' }) };
};
```

- [ ] **Step 4: Maak Supabase tabel aan**

In het Supabase dashboard (SQL Editor), voer uit:

```sql
CREATE TABLE sync_data (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE sync_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all via service role" ON sync_data
  FOR ALL USING (true) WITH CHECK (true);
```

- [ ] **Step 5: Configureer Netlify env vars**

In Netlify dashboard → Site settings → Environment variables:
- `SUPABASE_URL` = `https://xxxxx.supabase.co` (van Supabase project settings)
- `SUPABASE_ANON_KEY` = de anon key uit Supabase
- `SYNC_KEY` = genereer een willekeurige string (bijv. `openssl rand -hex 32`)

- [ ] **Step 6: Test lokaal met Netlify CLI (optioneel)**

```bash
npx netlify-cli dev
```

Test met curl:
```bash
curl -H "Authorization: Bearer <SYNC_KEY>" http://localhost:8888/.netlify/functions/sync
```

- [ ] **Step 7: Commit**

```bash
git add netlify.toml netlify/functions/sync.js package.json package-lock.json
git commit -m "feat: Netlify Function voor cloud sync met Supabase"
```

---

### Task 6: Frontend sync engine + sync-indicator

**Files:**
- Modify: `index.html` — sync module toevoegen (JS + CSS + HTML indicator element)
- Modify: `index.html:2494` — `init()` uitbreiden met sync-on-load

**Interfaces:**
- Consumes: Netlify Function `/.netlify/functions/sync` (GET/POST), alle `lc_*` localStorage keys
- Produces:
  - `syncPull()` → haalt server data op, merged naar localStorage (nieuwste wint per key)
  - `syncPush(keys)` → stuurt gewijzigde keys naar server
  - `syncAll()` → push alle `lc_*` keys
  - `showSyncStatus(status)` → toont indicator ('synced'|'syncing'|'offline'|'error')

- [ ] **Step 1: Voeg sync-indicator HTML toe**

Voeg toe vóór `<!-- BOTTOM NAV -->` (regel 755):

```html
<div class="sync-indicator" id="syncIndicator"></div>
```

- [ ] **Step 2: Voeg CSS toe voor sync-indicator**

Voeg toe aan de `<style>` sectie:

```css
.sync-indicator { position:fixed; bottom:calc(56px + var(--safe-b) + 6px); left:50%; transform:translateX(-50%); background:var(--surface-2); border:1px solid var(--surface-3); border-radius:20px; padding:4px 14px; font-size:11px; color:var(--text-muted); display:flex; align-items:center; gap:6px; z-index:99; opacity:0; transition:opacity 0.3s; pointer-events:none; }
.sync-indicator.show { opacity:1; }
.sync-dot { width:6px; height:6px; border-radius:50%; }
.sync-dot.green { background:var(--success); }
.sync-dot.grey { background:var(--text-muted); }
.sync-dot.red { background:var(--danger); }
.sync-dot.orange { background:#E2A020; }
```

- [ ] **Step 3: Voeg sync engine toe in JS**

Voeg toe vóór `setupAutoSave`:

```javascript
const SYNC_KEY = 'REPLACE_WITH_YOUR_SYNC_KEY';
const SYNC_URL = '/.netlify/functions/sync';
let _syncTimer = null;

function showSyncStatus(status) {
  const el = document.getElementById('syncIndicator');
  if (!el) return;
  const map = {
    synced:  { dot:'green',  text:'Gesynct' },
    syncing: { dot:'orange', text:'Synchroniseren...' },
    offline: { dot:'grey',   text:'Offline' },
    error:   { dot:'red',    text:'Sync mislukt' }
  };
  const s = map[status] || map.offline;
  el.innerHTML = `<span class="sync-dot ${s.dot}"></span>${s.text}`;
  el.classList.add('show');
  clearTimeout(_syncTimer);
  if (status !== 'syncing') {
    _syncTimer = setTimeout(() => el.classList.remove('show'), 3000);
  }
}

async function syncPull() {
  if (!navigator.onLine) { showSyncStatus('offline'); return; }
  showSyncStatus('syncing');
  try {
    const res = await fetch(SYNC_URL, { headers: { 'Authorization': 'Bearer ' + SYNC_KEY } });
    if (!res.ok) throw new Error(res.status);
    const { data } = await res.json();
    if (!data) { showSyncStatus('synced'); return; }
    data.forEach(row => {
      const localUpdated = localStorage.getItem('lc_meta_updated_' + row.key);
      const serverTime = new Date(row.updated_at).getTime();
      if (!localUpdated || serverTime > parseInt(localUpdated)) {
        localStorage.setItem(row.key, row.value);
        localStorage.setItem('lc_meta_updated_' + row.key, String(serverTime));
      }
    });
    showSyncStatus('synced');
  } catch {
    showSyncStatus('error');
  }
}

async function syncPush(keys) {
  if (!navigator.onLine) { showSyncStatus('offline'); return; }
  showSyncStatus('syncing');
  const now = new Date().toISOString();
  const nowMs = String(Date.now());
  const items = keys.map(k => {
    localStorage.setItem('lc_meta_updated_' + k, nowMs);
    return { key: k, value: localStorage.getItem(k) || '', updated_at: now };
  });
  try {
    const res = await fetch(SYNC_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + SYNC_KEY },
      body: JSON.stringify({ items })
    });
    if (!res.ok) throw new Error(res.status);
    showSyncStatus('synced');
  } catch {
    showSyncStatus('error');
  }
}

function syncAll() {
  const keys = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k.startsWith('lc_') && !k.startsWith('lc_meta_updated_')) keys.push(k);
  }
  if (keys.length) syncPush(keys);
}
```

- [ ] **Step 4: Integreer sync in bestaande save-functies**

Voeg sync-triggers toe aan de save-functies. Wijzig `saveToday`:

Na `localStorage.setItem(getTodayKey(), JSON.stringify(data));` (regel 2189), voeg toe:
```javascript
  syncPush([getTodayKey()]);
```

Wijzig `saveWeek` — na `localStorage.setItem(getWeekKey(), JSON.stringify(data));` (regel 2217):
```javascript
  syncPush([getWeekKey()]);
```

Wijzig `addKnabTx` — na `saveKnabTx(list);`:
```javascript
  syncPush(['lc_fin_knab_tx_' + finMaandKey()]);
```

Wijzig `deleteKnabTx` — na `saveKnabTx(...)`:
```javascript
  syncPush(['lc_fin_knab_tx_' + finMaandKey()]);
```

Wijzig `saveSessie` — na de localStorage calls (regel 1867-1870):
```javascript
  syncPush(['lc_sessions', 'lc_active_goals', 'lc_active_actions']);
```

Wijzig `saveFinVaste` — voeg na de setItem:
```javascript
function saveFinVaste(l) { localStorage.setItem('lc_fin_vaste', JSON.stringify(l)); syncPush(['lc_fin_vaste']); }
```

Dezelfde pattern voor `saveFinVariabel`, `saveFinKnab`, `saveFinBetaald`, `saveFinSalaris`.

- [ ] **Step 5: Voeg syncPull toe aan init**

In `init()`, voeg toe na `setupAutoSave();`:

```javascript
  syncPull().then(() => {
    loadToday();
    loadWeek();
    if (document.getElementById('tab-fin').classList.contains('active')) buildFinancieel();
  });
```

- [ ] **Step 6: Update Service Worker**

In `sw.js`, bump de cache versie en voeg de sync URL toe als pass-through:

Wijzig `const CACHE = 'daily-coach-v3';` naar `const CACHE = 'daily-coach-v4';`

In de fetch handler, voeg toe vóór de `respondWith`:
```javascript
  if (e.request.url.includes('/.netlify/functions/')) return;
```

- [ ] **Step 7: Test**

1. Vervang `REPLACE_WITH_YOUR_SYNC_KEY` met de werkelijke key
2. Push naar Netlify
3. Open op iPhone — sync-indicator moet "Gesynct" tonen (groen, verdwijnt na 3s)
4. Voeg een journaalnotitie toe — "Gesynct" verschijnt na opslaan
5. Open op PC — data moet overeenkomen
6. Zet vliegtuigmodus aan — "Offline" indicator (grijs)

- [ ] **Step 8: Commit**

```bash
git add index.html sw.js
git commit -m "feat: cloud sync engine + sync-indicator"
```

---

## Implementatievolgorde

1. **Task 1** — Data-laag (geen UI-breaking changes)
2. **Task 2** — Knab UI (vervangt saldo-check model volledig)
3. **Task 3** — Maandtotaal (bouwt voort op Task 1+2)
4. **Task 4** — Auto-save (onafhankelijk, maar sync-aware in Task 6)
5. **Task 5** — Backend (vereist Supabase project setup)
6. **Task 6** — Frontend sync + indicator (koppelt alles samen)

## Supabase setup checklist

Voordat Task 5 gebouwd kan worden:
- [ ] Ga naar [supabase.com](https://supabase.com) en maak een gratis project aan
- [ ] Kopieer de Project URL en anon key uit Settings → API
- [ ] Voer de SQL uit (Task 5 Step 4)
- [ ] Stel de 3 env vars in op Netlify (Task 5 Step 5)
