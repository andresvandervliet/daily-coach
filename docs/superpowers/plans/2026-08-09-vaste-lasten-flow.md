# Vaste Lasten Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add payment date tracking to vaste lasten, count Knab deposits as expenses, and build a chronological month timeline — all in the existing single-file Daily Coach app.

**Architecture:** Three features layered on the existing Financiën tab. Feature 1 changes the betaald data model from array to object-with-dates. Feature 2 adds a Knab stortingen line to the dashboard. Feature 3 adds a new timeline section between dashboard and Knab enveloppen, built from existing data sources.

**Tech Stack:** Vanilla HTML/CSS/JS, localStorage, single-file app (`index.html`)

## Global Constraints

- Single file: all HTML, CSS, and JS lives in `index.html`
- localStorage keys use `lc_` prefix
- No frameworks, no build step
- Dark theme only (CSS vars: `--gold`, `--surface-2`, `--text`, `--text-muted`, `--danger`, `--success`)
- Mobile-first (375px iPhone), must work on tablet (768px) and desktop (1280px)
- Helper functions: `finFmt(n)` formats currency, `esc(s)` escapes HTML, `localDateStr(date)` returns `YYYY-MM-DD`, `finMaandKey()` returns `YYYY-MM`
- Deploy: `git push` to master triggers Netlify deploy

---

### Task 1: Betaaldatum data model + migratie

**Files:**
- Modify: `index.html:1040-1048` (getFinBetaald, saveFinBetaald, isVasteBetaald, toggleVasteBetaald)
- Modify: `index.html:1089-1098` (calcBetaaldTotaal, calcOnbetaaldTotaal)
- Modify: `index.html:1114` (betaaldN count in buildFinDashboard)
- Modify: `index.html:1520-1531` (finAutoMarkeer)

**Interfaces:**
- Produces:
  - `getFinBetaald() → object` — returns `{ "id": "YYYY-MM-DD" | null, ... }` instead of `[id, ...]`
  - `saveFinBetaald(obj) → void` — saves object to localStorage
  - `isVasteBetaald(id) → boolean` — checks if key exists in object
  - `getBetaaldDatum(id) → string|null` — returns the payment date for an id
  - `toggleVasteBetaald(id) → void` — sets today's date or removes key
  - `calcBetaaldTotaal() → number` — unchanged signature, uses object keys
  - `calcOnbetaaldTotaal() → number` — unchanged signature, uses object keys

- [ ] **Step 1: Replace getFinBetaald and saveFinBetaald with object-based storage + migration**

Replace lines 1040-1041 in `index.html`:

```javascript
function getFinBetaald() {
  try {
    const raw = JSON.parse(localStorage.getItem('lc_fin_betaald_' + finMaandKey()) || '{}');
    if (Array.isArray(raw)) {
      const obj = {};
      raw.forEach(id => { obj[id] = null; });
      saveFinBetaald(obj);
      return obj;
    }
    return raw;
  } catch { return {}; }
}
function saveFinBetaald(obj) { localStorage.setItem('lc_fin_betaald_' + finMaandKey(), JSON.stringify(obj)); }
```

- [ ] **Step 2: Replace isVasteBetaald + add getBetaaldDatum**

Replace line 1042 in `index.html`:

```javascript
function isVasteBetaald(id) { return getFinBetaald().hasOwnProperty(String(id)); }
function getBetaaldDatum(id) { return getFinBetaald()[String(id)] || null; }
```

- [ ] **Step 3: Replace toggleVasteBetaald to store date**

Replace lines 1043-1049 in `index.html`:

```javascript
function toggleVasteBetaald(id) {
  const obj = getFinBetaald();
  const key = String(id);
  if (obj.hasOwnProperty(key)) delete obj[key];
  else obj[key] = localDateStr();
  saveFinBetaald(obj);
  buildFinVaste(); buildFinDashboard();
}
```

- [ ] **Step 4: Update calcBetaaldTotaal and calcOnbetaaldTotaal**

Replace lines 1089-1098 in `index.html`:

```javascript
function calcBetaaldTotaal() {
  const vaste = getFinVaste();
  const betaald = getFinBetaald();
  return vaste.filter(v => betaald.hasOwnProperty(String(v.id))).reduce((s,v) => s + v.bedrag, 0);
}
function calcOnbetaaldTotaal() {
  const vaste = getFinVaste();
  const betaald = getFinBetaald();
  return vaste.filter(v => !betaald.hasOwnProperty(String(v.id))).reduce((s,v) => s + v.bedrag, 0);
}
```

- [ ] **Step 5: Update betaaldN count in buildFinDashboard**

Replace line 1114 in `index.html`:

```javascript
  const betaaldN   = Object.keys(getFinBetaald()).filter(id => vaste.some(v => String(v.id)===id)).length;
```

- [ ] **Step 6: Update finAutoMarkeer to store afschrijfdag as date**

Replace lines 1520-1531 in `index.html`:

```javascript
function finAutoMarkeer() {
  const today  = new Date();
  const dag    = today.getDate();
  const vaste  = getFinVaste();
  const betaald = getFinBetaald();
  let changed = false;
  vaste.forEach(v => {
    const key = String(v.id);
    if (v.dag && dag >= v.dag && !betaald.hasOwnProperty(key)) {
      betaald[key] = localDateStr(new Date(today.getFullYear(), today.getMonth(), v.dag));
      changed = true;
    }
  });
  if (changed) saveFinBetaald(betaald);
}
```

- [ ] **Step 7: Test in browser**

Open the app, navigate to Financiën tab. Verify:
1. Existing betaald items (if any) still show as betaald after migration
2. Toggle a vaste last to betaald → verify it stores
3. Toggle it back to onbetaald → verify it removes
4. Dashboard numbers are unchanged
5. Check localStorage key `lc_fin_betaald_2026-08` — should be an object, not an array

- [ ] **Step 8: Commit**

```bash
git add index.html
git commit -m "feat: betaaldatum data model — array naar object met datums + migratie"
```

---

### Task 2: Betaaldatum UI — toon datum in vaste lasten lijst

**Files:**
- Modify: `index.html:1331-1351` (buildFinVaste)
- Modify: `index.html` CSS section (add `.fin-betaald-datum` style)

**Interfaces:**
- Consumes: `getBetaaldDatum(id) → string|null` from Task 1
- Produces: visual date display under each paid vaste last

- [ ] **Step 1: Add CSS for betaaldatum label**

Add after the existing `.fin-betaald-btn` styles in the CSS section:

```css
.fin-betaald-datum { font-size:10px; color:var(--success); margin-top:2px; }
```

- [ ] **Step 2: Update buildFinVaste to show betaaldatum**

Replace lines 1340-1351 in `index.html`:

```javascript
  el.innerHTML = list.map(v => {
    const done = isVasteBetaald(v.id);
    const datum = getBetaaldDatum(v.id);
    const datumTxt = done ? (datum ? 'Betaald op ' + new Date(datum+'T00:00:00').toLocaleDateString('nl-NL',{day:'numeric',month:'short'}) : 'Betaald') : '';
    return `<div class="fin-list-item${done?' betaald':''}" id="fin-vaste-${v.id}">
      <button class="fin-betaald-btn${done?' done':''}" onclick="toggleVasteBetaald(${v.id})" title="${done?'Markeer als onbetaald':'Markeer als betaald'}">${done?'&#10003;':'&#9675;'}</button>
      <div class="fin-item-info">
        <div class="fin-item-naam">${esc(v.naam)}</div>
        ${datumTxt ? `<div class="fin-betaald-datum">${datumTxt}</div>` : ''}
      </div>
      <div class="fin-item-amount">${finFmt(v.bedrag)}</div>
      <div class="fin-item-actions">
        <button class="fin-edit-btn" onclick="inlineEditVaste(${v.id})">&#9998;</button>
        <button class="fin-delete-btn" onclick="deleteVaste(${v.id})">&#215;</button>
      </div>
    </div>`;
  }).join('');
```

- [ ] **Step 3: Test in browser**

1. Mark a vaste last as betaald → should show "Betaald op 9 aug" underneath the name
2. Items that were migrated from old format (datum = null) → should show just "Betaald"
3. Unmark → datum text disappears
4. Check mobile (375px) — text should fit without overflow

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: betaaldatum tonen in vaste lasten lijst"
```

---

### Task 3: Knab stortingen als uitgave in dashboard

**Files:**
- Modify: `index.html` after line 1064 (add calcKnabStortingen function)
- Modify: `index.html:1100-1166` (buildFinDashboard — add Knab stortingen line + update berekeningen)

**Interfaces:**
- Consumes: `getFinKnab() → array`, `getFinSalarisOntvangen() → boolean`
- Produces: `calcKnabStortingen() → number` — sum of all `gestort` values from active envelopes

- [ ] **Step 1: Add calcKnabStortingen function**

Add after line 1072 (after `calcKnabBespaard` closing brace) in `index.html`:

```javascript
function calcKnabStortingen() {
  return getFinKnab().reduce((s, k) => s + (k.gestort || 0), 0);
}
```

- [ ] **Step 2: Update buildFinDashboard with Knab stortingen line + adjusted calculations**

Replace the buildFinDashboard function body (lines 1100-1166):

```javascript
function buildFinDashboard() {
  const el = document.getElementById('finDashboard'); if(!el) return;
  const salaris    = getFinSalaris();
  const alBetaald  = calcBetaaldTotaal();
  const komtNog    = calcOnbetaaldTotaal();
  const variabel   = calcVariabelTotaal();
  const knabStort  = getFinSalarisOntvangen() ? calcKnabStortingen() : 0;
  const dec        = new Date().getMonth() === 11;
  const inkomen    = dec ? salaris * 2 : salaris;

  const alVanRekening = alBetaald + knabStort;
  const nuVrij     = inkomen - alVanRekening;
  const echtRest   = inkomen - alVanRekening - komtNog - variabel;
  const positief   = echtRest >= 0;

  const vaste      = getFinVaste();
  const betaaldN   = Object.keys(getFinBetaald()).filter(id => vaste.some(v => String(v.id)===id)).length;

  const today        = new Date();
  const daysInMonth  = new Date(today.getFullYear(), today.getMonth()+1, 0).getDate();
  const pct          = Math.round((today.getDate() / daysInMonth) * 100);

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
      ${knabStort > 0 ? `<div class="fin-row">
        <span class="fin-row-label">Knab stortingen</span>
        <span class="fin-row-amount" style="color:var(--danger)">- ${finFmt(knabStort)}</span>
      </div>` : ''}
      <div class="fin-row">
        <span class="fin-row-label">Komt nog deze maand</span>
        <span class="fin-row-amount" style="color:#E2A020">- ${finFmt(komtNog)}</span>
      </div>
      <div class="fin-row">
        <span class="fin-row-label">Variabele uitgaven</span>
        <span class="fin-row-amount" style="color:var(--text-muted)">- ${finFmt(variabel)}</span>
      </div>
    </div>
    <div class="fin-dash-split">
      <div class="fin-dash-card fin-vrij-card">
        <div class="fin-dash-card-label">Nu vrij te besteden</div>
        <div class="fin-dash-card-amount" style="color:var(--gold)">${finFmt(nuVrij)}</div>
        <div class="fin-dash-card-sub">Op je rekening nu</div>
      </div>
      <div class="fin-dash-card">
        <div class="fin-dash-card-label">Echt restant</div>
        <div class="fin-dash-card-amount ${positief?'fin-positive':'fin-negative'}">${positief?'+':'−'} ${finFmt(Math.abs(echtRest))}</div>
        <div class="fin-dash-card-sub">Na alle lasten</div>
      </div>
    </div>
    <div class="fin-dashboard" style="padding:14px 18px">
      <div class="fin-month-bar-wrap" style="margin-top:0">
        <div class="fin-month-label">Maand dag ${today.getDate()} van ${daysInMonth} (${pct}%)</div>
        <div class="fin-month-track"><div class="fin-month-fill" style="width:${pct}%"></div></div>
      </div>
      <div class="fin-salaris-row" style="margin-top:10px;padding-top:10px">
        <span class="fin-salaris-label">Salaris:</span>
        <input class="fin-salaris-input" id="finSalarisInput" type="number" value="${salaris}" onchange="updateFinSalaris(this.value)">
        ${!getFinSalarisOntvangen() ? `<button class="btn-small" style="font-size:11px;padding:6px 12px" onclick="markSalarisOntvangen(${salaris})">Ontvangen ✓</button>` : '<span style="font-size:11px;color:var(--success)">Ontvangen ✓</span>'}
      </div>
    </div>`;

  buildFinRokenBadge();
  buildFinPaydayBanner();
}
```

- [ ] **Step 3: Update buildSnapshot to include knabStortingen in restant**

Replace the `restant` calculation in `buildSnapshot` (line 1557):

```javascript
    restant:   getFinSalaris() - calcBetaaldTotaal() - calcOnbetaaldTotaal() - calcVariabelTotaal() - (getFinSalarisOntvangen() ? calcKnabStortingen() : 0)
```

- [ ] **Step 4: Test in browser**

1. With salaris ontvangen + Knab enveloppen with `gestort > 0` → "Knab stortingen" line appears
2. Without salaris ontvangen → line is hidden
3. "Nu vrij te besteden" and "Echt restant" include Knab stortingen in calculation
4. With no Knab gestort → line does not appear

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: Knab stortingen als uitgave in dashboard"
```

---

### Task 4: Maandtijdlijn — HTML container + CSS

**Files:**
- Modify: `index.html:729-730` (add timeline div between spaar badge and Knab section)
- Modify: `index.html` CSS section (add timeline styles)

**Interfaces:**
- Produces: `<div id="finTimeline"></div>` HTML element, timeline CSS classes

- [ ] **Step 1: Add timeline container in HTML**

After line 729 (`<div id="finRokenBadge"></div>`) and before the closing `</div>` of that section, add:

```html
    <div id="finTimeline"></div>
```

So the section becomes:
```html
  <div class="section">
    <div class="section-title" id="finMaandLabel">Maandoverzicht</div>
    <div id="finPaydayBanner"></div>
    <div id="finDashboard"></div>
    <div id="finSpaarBadge"></div>
    <div id="finRokenBadge"></div>
    <div id="finTimeline"></div>
  </div>
```

- [ ] **Step 2: Add timeline CSS**

Add after the existing `.knab-summary` styles:

```css
.fin-timeline { margin-top:16px; }
.fin-timeline-title { font-size:12px; letter-spacing:0.08em; text-transform:uppercase; color:var(--gold); margin-bottom:12px; }
.fin-tl-item { display:flex; align-items:baseline; gap:8px; padding:8px 0; border-bottom:1px solid var(--surface-3); font-size:13px; }
.fin-tl-item:last-child { border-bottom:none; }
.fin-tl-date { min-width:42px; color:var(--text-muted); font-size:12px; text-align:right; flex-shrink:0; }
.fin-tl-icon { width:16px; text-align:center; flex-shrink:0; font-size:12px; }
.fin-tl-icon.done { color:var(--success); }
.fin-tl-icon.pending { color:var(--text-muted); }
.fin-tl-desc { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.fin-tl-desc.indent { padding-left:4px; color:var(--text-muted); }
.fin-tl-amount { white-space:nowrap; flex-shrink:0; }
.fin-tl-amount.income { color:var(--success); }
.fin-tl-amount.expense { color:var(--danger); }
.fin-tl-section { font-size:11px; color:var(--text-muted); padding:10px 0 4px; letter-spacing:0.05em; }
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: maandtijdlijn HTML container + CSS"
```

---

### Task 5: Maandtijdlijn — buildFinTimeline functie

**Files:**
- Modify: `index.html` JS section (add `buildFinTimeline` function before `buildFinancieel`)
- Modify: `index.html:1647` (add `buildFinTimeline()` call in `buildFinancieel`)

**Interfaces:**
- Consumes:
  - `getFinVaste() → array` with `{ id, naam, bedrag, dag }` items
  - `getFinBetaald() → object` with `{ "id": "YYYY-MM-DD" | null }` (from Task 1)
  - `getBetaaldDatum(id) → string|null` (from Task 1)
  - `getFinKnab() → array` with `{ id, naam, gestort }` items
  - `getFinSalaris() → number`
  - `getFinSalarisOntvangen() → boolean`
  - `finFmt(n) → string`, `esc(s) → string`
- Produces: `buildFinTimeline() → void` — renders the timeline into `#finTimeline`

- [ ] **Step 1: Add buildFinTimeline function**

Add before the `buildFinancieel` function (before line 1647):

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
  const jaar = today.getFullYear();
  const MAANDEN = ['jan','feb','mrt','apr','mei','jun','jul','aug','sep','okt','nov','dec'];

  const events = [];

  if (salOntvangen) {
    events.push({ dag: 24, done: true, desc: 'Salaris ontvangen', amount: salaris, type: 'income', sort: 0 });
    knab.forEach(k => {
      if (k.gestort > 0) {
        events.push({ dag: 24, done: true, desc: '→ Knab ' + k.naam, amount: k.gestort, type: 'expense', sort: 1, indent: true });
      }
    });
  }

  vaste.forEach(v => {
    const key = String(v.id);
    const isPaid = betaald.hasOwnProperty(key);
    const datum = isPaid ? betaald[key] : null;
    const dag = isPaid && datum ? new Date(datum+'T00:00:00').getDate() : (v.dag || null);
    events.push({ dag, done: isPaid, desc: v.naam, amount: v.bedrag, type: 'expense', sort: 2 });
  });

  const withDag = events.filter(e => e.dag !== null).sort((a,b) => a.dag - b.dag || a.sort - b.sort);
  const noDag = events.filter(e => e.dag === null);

  if (withDag.length === 0 && noDag.length === 0) { el.innerHTML = ''; return; }

  let html = '<div class="fin-timeline"><div class="fin-timeline-title">Maandtijdlijn</div>';

  withDag.forEach(e => {
    const dagStr = String(e.dag).padStart(2, ' ') + ' ' + MAANDEN[maandNr];
    const icon = e.done ? '<span class="fin-tl-icon done">&#10003;</span>' : '<span class="fin-tl-icon pending">&#9675;</span>';
    const sign = e.type === 'income' ? '+ ' : '- ';
    const cls = e.type === 'income' ? 'income' : 'expense';
    html += `<div class="fin-tl-item">
      <span class="fin-tl-date">${dagStr}</span>
      ${icon}
      <span class="fin-tl-desc${e.indent?' indent':''}">${esc(e.desc)}</span>
      <span class="fin-tl-amount ${cls}">${sign}${finFmt(e.amount)}</span>
    </div>`;
  });

  if (noDag.length > 0) {
    html += '<div class="fin-tl-section">Datum onbekend</div>';
    noDag.forEach(e => {
      const icon = e.done ? '<span class="fin-tl-icon done">&#10003;</span>' : '<span class="fin-tl-icon pending">&#9675;</span>';
      html += `<div class="fin-tl-item">
        <span class="fin-tl-date"></span>
        ${icon}
        <span class="fin-tl-desc">${esc(e.desc)}</span>
        <span class="fin-tl-amount expense">- ${finFmt(e.amount)}</span>
      </div>`;
    });
  }

  html += '</div>';
  el.innerHTML = html;
}
```

- [ ] **Step 2: Add buildFinTimeline call to buildFinancieel**

In the `buildFinancieel` function, add `buildFinTimeline();` after `buildFinDashboard();`:

```javascript
function buildFinancieel() {
  finAutoReset();
  finAutoMarkeer();
  finSaveMaandSnapshot();
  buildFinDashboard();
  buildFinTimeline();
  buildFinSpaarBadge();
  buildFinKnab();
  buildFinVaste();
  buildFinVariabel();
  buildFinHistorie();
}
```

- [ ] **Step 3: Test in browser**

1. With some vaste lasten with `dag` set → verify they appear sorted chronologically
2. With salaris ontvangen → verify salaris + Knab stortingen appear at dag 24
3. With vaste lasten without `dag` → verify they appear under "Datum onbekend"
4. Mark a vaste last as betaald → verify checkmark appears and date updates
5. Check mobile (375px) — no horizontal overflow, text truncates properly

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: maandtijdlijn — chronologisch overzicht van de maand"
```

---

### Task 6: Integration test + final deploy

**Files:**
- No file changes — test + deploy only

**Interfaces:**
- Consumes: All 3 features from Tasks 1-5

- [ ] **Step 1: Full integration test**

Open the app in browser and verify:

1. **Migration**: If old betaald data existed (array format), it's automatically migrated to object
2. **Betaaldatum**: Mark vaste last → shows "Betaald op X" with today's date
3. **Auto-markeer**: Vaste lasten with `dag <= today` are auto-marked with their afschrijfdag date
4. **Dashboard**: "Knab stortingen" line appears when salaris is received and envelopes have gestort > 0
5. **Dashboard math**: "Nu vrij te besteden" = salaris - betaalde vaste lasten - Knab stortingen
6. **Timeline**: Shows chronological events — salaris, Knab stortingen (indented), vaste lasten
7. **Timeline done/pending**: Paid items show ✓, unpaid show ○
8. **No dag items**: Show under "Datum onbekend" at the bottom
9. **Mobile 375px**: No overflow, all text readable, amounts aligned
10. **Tablet 768px**: Layout looks clean, no stretching issues
11. **Desktop 1280px**: Max-width 680px centered, looks good

- [ ] **Step 2: Push to production**

```bash
git push origin master
```

- [ ] **Step 3: Verify production**

Open `https://merry-kelpie-eec436.netlify.app`, force-refresh (Ctrl+Shift+R), verify all 3 features work on production.
