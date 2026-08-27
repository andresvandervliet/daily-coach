# Zelflerende Financiën — Maandrollover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Maak de Financiën-tab doorlopend en zelflerend: de vaste-lasten-lijst rolt door van maand tot maand, de app leert echte betaaldata uit de historie, en Knab-envelop-saldi (+/−) rollen door bij "Salaris gestort".

**Architecture:** Vier lagen bovenop de bestaande Financiën-tab in `index.html`. Feature 1 verandert de seed van een nieuwe maand: in plaats van hardcoded defaults wordt de vorige maandrij gekopieerd. Feature 3 leidt bij het laden per vaste last een "geleerde betaaldag" af uit alle `betaald`-objecten en gebruikt die in de tijdlijn + een UI-hint. Feature 4 berekent bij "Ontvangen ✓" het eindsaldo van elke envelop van de vorige maand en zet dat als `vorigSaldo` op de huidige maand; de envelop-weergave toont "Vorig saldo" en "Beschikbaar". Geen SQL-migratie: `vaste` en `knab` zijn `jsonb`.

**Tech Stack:** Vanilla HTML/CSS/JS, Supabase (`sb` client), single-file app (`index.html`). Geen build, geen test-runner — verificatie is handmatig in de browser + console-checks.

## Global Constraints

- Single file: alle HTML, CSS en JS in `index.html`
- Geen frameworks, geen build-step
- Dark theme only (CSS vars: `--gold`, `--surface-2`, `--surface-3`, `--text`, `--text-muted`, `--danger`, `--success`)
- Mobile-first (375px iPhone), moet werken op tablet (768px) en desktop (1280px)
- Helpers: `finFmt(n)` formatteert valuta (`€ 1.234,56`), `esc(s)` escapet HTML, `localDateStr(date)` → `YYYY-MM-DD`, `finMaandKey()` → `YYYY-MM`
- Data: `finance`-tabel heeft één rij per `user_id + month_key`. `_saveFinance()` upsert de kolommen `vaste, knab, knab_tx, betaald, salaris, salaris_ontvangen, salaris_datum, history`. `vaste`/`knab`/`knab_tx` zijn `jsonb` — nieuwe object-velden vereisen geen migratie.
- `_db.fin` = de huidige maand in geheugen; `_db.finHistory` = afgeleide lijst van álle vorige maanden (oplopend gesorteerd op `month_key`), elk item heeft `._raw` (de ruwe rij met `knab`, `knab_tx`, `betaald`, `salaris`).
- Deploy: `git push` naar master triggert Netlify-deploy (`https://merry-kelpie-eec436.netlify.app`)
- Bedragen moeten kloppend blijven: "Al van rekening", "Komt nog deze maand", "Echt restant", "Hoofdrekening / na alle lasten", Maandtijdlijn, Vaste lasten. De dashboardregel "Knab stortingen" blijft de som van `k.gestort` (nieuw geld van de hoofdrekening), NOOIT `beschikbaar`.

---

### Task 1: Doorlopende vaste-lasten-lijst — seed nieuwe maand vanuit vorige maand

**Files:**
- Modify: `index.html` — voeg `seedNieuweMaand()` toe direct boven `async function loadAllData()` (nu regel ~1107)
- Modify: `index.html` — in `loadAllData()`, de regel `_db.fin = finRes.data || { ... }` (nu regel ~1123)

**Interfaces:**
- Consumes: `FIN_DEFAULT_VASTE`, `FIN_DEFAULT_KNAB` (bestaande consts), `allFinRes.data` (array vorige maandrijen, oplopend op `month_key`, kolommen `month_key,salaris,vaste,knab,knab_tx,betaald,salaris_ontvangen`)
- Produces: `seedNieuweMaand(prevRow) → object` — bouwt een vers `_db.fin`-object. `prevRow` is de ruwe vorige-maandrij of `undefined`. Elke Knab-envelop in het resultaat heeft `gestort: 0` en `vorigSaldo: null`.

- [ ] **Step 1: Voeg `seedNieuweMaand` toe**

Voeg toe direct vóór `async function loadAllData() {` in `index.html`:

```javascript
function seedNieuweMaand(prev) {
  if (!prev) {
    return {
      vaste: FIN_DEFAULT_VASTE.map(v => ({ ...v })),
      knab: FIN_DEFAULT_KNAB.map(k => ({ ...k, gestort: 0, vorigSaldo: null })),
      knab_tx: [], betaald: {},
      salaris: 3700, salaris_ontvangen: false, salaris_datum: null, history: []
    };
  }
  return {
    vaste: (prev.vaste && prev.vaste.length ? prev.vaste : FIN_DEFAULT_VASTE).map(v => ({ ...v })),
    knab: (prev.knab && prev.knab.length ? prev.knab : FIN_DEFAULT_KNAB).map(k => ({ ...k, gestort: 0, vorigSaldo: null })),
    knab_tx: [], betaald: {},
    salaris: prev.salaris || 3700,
    salaris_ontvangen: false, salaris_datum: null, history: []
  };
}
```

- [ ] **Step 2: Gebruik `seedNieuweMaand` in `loadAllData`**

In `loadAllData()`, vervang de regel:

```javascript
  _db.fin = finRes.data || { vaste: FIN_DEFAULT_VASTE, knab: FIN_DEFAULT_KNAB, knab_tx: [], betaald: {}, salaris: 3700, salaris_ontvangen: false, salaris_datum: null, history: [] };
```

door:

```javascript
  _db.fin = finRes.data || seedNieuweMaand((allFinRes.data || []).slice(-1)[0]);
```

- [ ] **Step 3: Verifieer in de browser dat de huidige maand niks kapotmaakt**

Open de app → Financiën. De maand van vandaag heeft al een `finance`-rij, dus `finRes.data` is gevuld en `seedNieuweMaand` wordt niet gebruikt. Controleer:
1. Vaste lasten, Knab-enveloppen, dashboard, tijdlijn — alles rendert zoals voorheen
2. Geen console-errors

- [ ] **Step 4: Verifieer de seed-logica via de console**

In de browser-console:

```javascript
seedNieuweMaand((window._db?.finHistory || []).slice(-1)[0]?._raw)
```

Verwacht: een object met `betaald: {}`, `salaris_ontvangen: false`, `knab_tx: []`, en elke `knab`-envelop met `gestort: 0` en `vorigSaldo: null`. Als er geen vorige maand is, komt de defaults-tak terug (ook geldig). `vaste` moet dezelfde namen/bedragen hebben als de vorige maand (of `FIN_DEFAULT_VASTE`).

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: nieuwe maand seedt vanuit vorige maand i.p.v. hardcoded defaults"
```

---

### Task 2: Zelflerende betaaldata — afleiden + `voorspeldeDag`

**Files:**
- Modify: `index.html` — `const _db = { ... }` (nu regel ~1094): voeg `finGeleerdeDagen: {}` toe
- Modify: `index.html` — voeg `berekenGeleerdeDagen()` en `voorspeldeDag()` toe direct boven `function seedNieuweMaand(` (uit Task 1)
- Modify: `index.html` — in `loadAllData()`, na de `_db.finHistory = ...`-toewijzing (nu regel ~1124-1131)
- Modify: `index.html` — `buildFinTimeline()` (nu regel ~2314-2320), de `dag`-berekening voor vaste lasten

**Interfaces:**
- Consumes: `allFinRes.data` (vorige maandrijen met `month_key` + `betaald`), `_db.fin.betaald` (huidige maand), `finMaandKey()`
- Produces:
  - `berekenGeleerdeDagen(prevRows, huidigFin) → object` — `{ "<vasteId>": <dag 1-31>, ... }`, alleen ids met ≥2 betaaldatums in de laatste 3 maanden
  - `voorspeldeDag(v) → number|null` — `_db.finGeleerdeDagen[v.id] ?? v.dag ?? null`
  - `_db.finGeleerdeDagen` — gevuld bij elke `loadAllData()`

- [ ] **Step 1: Voeg `finGeleerdeDagen` toe aan `_db`**

In het `const _db = { ... }`-object, voeg een regel toe (bijv. na `finHistory: [],`):

```javascript
  finGeleerdeDagen: {},
```

- [ ] **Step 2: Voeg `berekenGeleerdeDagen` en `voorspeldeDag` toe**

Voeg toe direct vóór `function seedNieuweMaand(` in `index.html`:

```javascript
function berekenGeleerdeDagen(prevRows, huidigFin) {
  const rijen = (prevRows || []).slice();
  if (huidigFin && huidigFin.betaald) {
    rijen.push({ month_key: finMaandKey(), betaald: huidigFin.betaald });
  }
  const perId = {};
  rijen.forEach(f => {
    const b = f.betaald || {};
    Object.keys(b).forEach(id => {
      const datum = b[id];
      if (!datum) return;
      const dag = new Date(datum + 'T00:00:00').getDate();
      if (!dag) return;
      (perId[id] = perId[id] || []).push({ maand: f.month_key, dag });
    });
  });
  const result = {};
  Object.keys(perId).forEach(id => {
    const punten = perId[id]
      .sort((a, b) => (a.maand < b.maand ? -1 : a.maand > b.maand ? 1 : 0))
      .slice(-3);
    if (punten.length < 2) return;
    const gem = punten.reduce((s, p) => s + p.dag, 0) / punten.length;
    result[id] = Math.round(gem);
  });
  return result;
}

function voorspeldeDag(v) {
  const geleerd = _db.finGeleerdeDagen && _db.finGeleerdeDagen[String(v.id)];
  return geleerd || v.dag || null;
}
```

- [ ] **Step 3: Roep `berekenGeleerdeDagen` aan in `loadAllData`**

In `loadAllData()`, direct ná het blok `_db.finHistory = (allFinRes.data || []).map(f => ({ ... }));`, voeg toe:

```javascript
  _db.finGeleerdeDagen = berekenGeleerdeDagen(allFinRes.data || [], _db.fin);
```

- [ ] **Step 4: Gebruik `voorspeldeDag` in de tijdlijn**

In `buildFinTimeline()`, in de `vaste.forEach(v => { ... })`-lus, vervang:

```javascript
    const dag = isPaid && datum ? new Date(datum+'T00:00:00').getDate() : (v.dag || null);
```

door:

```javascript
    const dag = isPaid && datum ? new Date(datum+'T00:00:00').getDate() : voorspeldeDag(v);
```

- [ ] **Step 5: Verifieer via de console**

Open de app → Financiën. In de console:

```javascript
window._db.finGeleerdeDagen
```

Verwacht: een object (leeg `{}` als er <2 maanden historie zijn met betaaldatums — dat is correct). Als er wel genoeg historie is: keys zijn vaste-last-ids, values zijn dagen 1-31.

Test `voorspeldeDag` handmatig:

```javascript
voorspeldeDag({ id: 1, dag: 1 })   // → geleerde dag als die er is, anders 1
voorspeldeDag({ id: 999, dag: 15 }) // → 15 (geen historie voor id 999)
voorspeldeDag({ id: 999, dag: null }) // → null
```

- [ ] **Step 6: Verifieer de tijdlijn**

In de Maandtijdlijn: onbetaalde vaste lasten staan op hun `voorspeldeDag`. Zolang er geen geleerde dagen zijn, is dit identiek aan het oude gedrag (`v.dag`). Geen visuele regressie.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: leer betaaldag per vaste last uit historie (gemiddelde laatste 3 maanden)"
```

---

### Task 3: Zelflerende betaaldata — UI-hint "Meestal rond de Xe"

**Files:**
- Modify: `index.html` CSS — voeg `.fin-verwacht-datum` toe na `.fin-betaald-datum` (nu regel ~433)
- Modify: `index.html` — `buildFinVaste()`, de `list.map(v => { ... })`-body (nu regel ~2050-2059)

**Interfaces:**
- Consumes: `voorspeldeDag(v) → number|null` (Task 2), `_db.finGeleerdeDagen` (Task 2), `isVasteBetaald(id)`, `getBetaaldDatum(id)`
- Produces: onder elke NIET-betaalde vaste last met een geleerde dag een regel `Meestal rond de 3e`

- [ ] **Step 1: Voeg CSS toe**

Direct ná de regel `.fin-betaald-datum { font-size:10px; color:var(--success); margin-top:2px; }`:

```css
.fin-verwacht-datum { font-size:10px; color:var(--text-muted); margin-top:2px; }
```

- [ ] **Step 2: Toon de hint in `buildFinVaste`**

In `buildFinVaste()`, vervang dit blok:

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
```

door:

```javascript
  el.innerHTML = list.map(v => {
    const done = isVasteBetaald(v.id);
    const datum = getBetaaldDatum(v.id);
    const datumTxt = done ? (datum ? 'Betaald op ' + new Date(datum+'T00:00:00').toLocaleDateString('nl-NL',{day:'numeric',month:'short'}) : 'Betaald') : '';
    const geleerd = _db.finGeleerdeDagen && _db.finGeleerdeDagen[String(v.id)];
    const verwachtTxt = (!done && geleerd) ? 'Meestal rond de ' + geleerd + 'e' : '';
    return `<div class="fin-list-item${done?' betaald':''}" id="fin-vaste-${v.id}">
      <button class="fin-betaald-btn${done?' done':''}" onclick="toggleVasteBetaald(${v.id})" title="${done?'Markeer als onbetaald':'Markeer als betaald'}">${done?'&#10003;':'&#9675;'}</button>
      <div class="fin-item-info">
        <div class="fin-item-naam">${esc(v.naam)}</div>
        ${datumTxt ? `<div class="fin-betaald-datum">${datumTxt}</div>` : ''}
        ${verwachtTxt ? `<div class="fin-verwacht-datum">${verwachtTxt}</div>` : ''}
      </div>
```

De rest van de map-body (het `fin-item-amount`- en `fin-item-actions`-deel) blijft ongewijzigd.

- [ ] **Step 3: Verifieer in de browser**

1. Zonder geleerde dagen (nieuwe gebruiker / <2 maanden historie): geen extra regel — identiek aan nu
2. Forceer een hint via console om de weergave te checken:
   ```javascript
   window._db.finGeleerdeDagen = { "1": 3 }; buildFinVaste();
   ```
   → Onder de eerste vaste last (id 1) verschijnt "Meestal rond de 3e" in grijs, mits die last niet is afgevinkt
3. Vink die last af → de "Meestal rond de 3e"-regel verdwijnt, "Betaald op ..." verschijnt
4. Mobiel (375px): tekst past, geen overflow
5. Herstel: `location.reload()`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: toon geleerde betaaldag onder onbetaalde vaste lasten"
```

---

### Task 4: Knab-saldo doorrol — berekening bij "Salaris gestort"

**Files:**
- Modify: `index.html` — voeg `rolKnabSaldoDoor()` toe direct vóór `function markSalarisOntvangen(` (nu regel ~1805)
- Modify: `index.html` — `markSalarisOntvangen()` (nu regel ~1805-1814)

**Interfaces:**
- Consumes: `getFinHistory() → array` (elk item met `._raw.knab` en `._raw.knab_tx`), `_db.fin.knab` (envelop-objecten met `doel`), `getFinSalarisOntvangen() → boolean`, `_saveFinance()`, `setFinSalarisOntvangen()`, `buildFinDashboard()`, `buildFinKnab()`, `toonMaandOverzicht()`
- Produces: `rolKnabSaldoDoor() → void` — zet per envelop in `_db.fin.knab` het veld `vorigSaldo` (number) = eindsaldo vorige maand voor die `doel`; envelop zonder match krijgt `vorigSaldo: 0`. Persisteert via `_saveFinance()`.
- Idempotentie: `rolKnabSaldoDoor()` wordt in `markSalarisOntvangen()` alleen aangeroepen zolang `getFinSalarisOntvangen()` nog `false` is. Daarna staat `salaris_ontvangen` op `true` (gepersisteerd), dus het draait precies één keer per maand.

- [ ] **Step 1: Voeg `rolKnabSaldoDoor` toe**

Direct vóór `function markSalarisOntvangen(huidig) {`:

```javascript
function rolKnabSaldoDoor() {
  const prev = getFinHistory().slice(-1)[0];
  if (!prev || !prev._raw) return;
  const prevKnab = prev._raw.knab || [];
  const prevTx = prev._raw.knab_tx || [];
  (_db.fin.knab || []).forEach(k => {
    const vk = prevKnab.find(x => x.doel && k.doel && x.doel === k.doel);
    if (!vk) { k.vorigSaldo = 0; return; }
    const uitgeg = prevTx.filter(t => t.knabId === vk.id).reduce((s, t) => s + t.bedrag, 0);
    k.vorigSaldo = (vk.gestort || 0) + (vk.vorigSaldo || 0) - uitgeg;
  });
  _saveFinance();
}
```

- [ ] **Step 2: Wire in `markSalarisOntvangen`**

Vervang de hele functie:

```javascript
function markSalarisOntvangen(huidig) {
  const inp = document.getElementById('finSalarisInput');
  const werkelijk = inp ? parseFloat(inp.value) : huidig;
  if(!isNaN(werkelijk) && werkelijk > 0) saveFinSalaris(werkelijk);
  const vorigeMaand = getFinHistory().slice(-1)[0];
  setFinSalarisOntvangen();
  buildFinDashboard();
  showToast('Salaris geregistreerd ' + finFmt(werkelijk || huidig));
  if (vorigeMaand && vorigeMaand._raw) toonMaandOverzicht(vorigeMaand._raw);
}
```

door:

```javascript
function markSalarisOntvangen(huidig) {
  const inp = document.getElementById('finSalarisInput');
  const werkelijk = inp ? parseFloat(inp.value) : huidig;
  if(!isNaN(werkelijk) && werkelijk > 0) saveFinSalaris(werkelijk);
  const vorigeMaand = getFinHistory().slice(-1)[0];
  if (!getFinSalarisOntvangen()) rolKnabSaldoDoor();
  setFinSalarisOntvangen();
  buildFinDashboard();
  buildFinKnab();
  showToast('Salaris geregistreerd ' + finFmt(werkelijk || huidig));
  if (vorigeMaand && vorigeMaand._raw) toonMaandOverzicht(vorigeMaand._raw);
}
```

- [ ] **Step 3: Verifieer via de console (geen echte maandwissel nodig)**

Open de app → Financiën. Simuleer een vorige maand en roep de doorrol aan:

```javascript
// fake vorige maand: envelop "Boodschappen" had 300 budget, 260 uitgegeven → +40
window._db.finHistory.push({
  maand: '2000-01',
  _raw: {
    month_key: '2000-01',
    knab: [{ id: 2, doel: 'Boodschappen', gestort: 300, vorigSaldo: 0 }],
    knab_tx: [{ id: 1, knabId: 2, bedrag: 260 }]
  }
});
rolKnabSaldoDoor();
window._db.fin.knab.find(k => k.doel === 'Boodschappen').vorigSaldo;  // → 40
window._db.fin.knab.find(k => k.doel === 'Benzine').vorigSaldo;       // → 0 (geen match)
```

Herstel daarna met `location.reload()`.

- [ ] **Step 4: Verifieer idempotentie**

Na een reload, met `salaris_ontvangen` al `true` deze maand: klik nogmaals op de "Ontvangen ✓"-status (of roep `markSalarisOntvangen(getFinSalaris())` aan). `rolKnabSaldoDoor()` mag NIET opnieuw draaien omdat `getFinSalarisOntvangen()` `true` is. Controleer dat `vorigSaldo`-waarden onveranderd blijven.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: rol Knab-envelopsaldo door naar nieuwe maand bij salaris gestort"
```

---

### Task 5: Knab-saldo doorrol — envelop-weergave "Vorig saldo" + "Beschikbaar"

**Files:**
- Modify: `index.html` — `buildFinKnab()`, het `knab.map(k => { ... })`-blok tot en met de `envelope-amounts`-div (nu regel ~1874-1892)
- Modify: `index.html` — `calcKnabBespaard()` (nu regel ~1671-1680)
- Modify: `index.html` — `_db.finHistory = (allFinRes.data || []).map(...)`, de `knabBesp`-regel (nu regel ~1128)

**Interfaces:**
- Consumes: `k.vorigSaldo` (number of `undefined`/`null`) van elke envelop (Task 4), `calcKnabUitgegeven(k.id) → number`, `finFmt(n)`
- Produces: envelop-kaart toont "Vorig saldo" (alleen als het een getal ≠ 0 is), "Beschikbaar" = `gestort + vorigSaldo`, en `Saldo`/voortgangsbalk rekenen vanaf `Beschikbaar`. Vóór doorrol (`vorigSaldo` niet-numeriek): een grijze regel "Vorig saldo wordt berekend zodra je salaris gestort is".

- [ ] **Step 1: Herbouw de envelop-berekening + weergave in `buildFinKnab`**

In `buildFinKnab()`, vervang dit blok:

```javascript
  el.innerHTML = knab.map(k => {
    const hasGoal = k.doel && k.doel.trim() !== '';
    const uitgeg = calcKnabUitgegeven(k.id);
    const saldo = k.gestort - uitgeg;
    const pct = k.gestort > 0 ? Math.min(100, Math.round((uitgeg / k.gestort) * 100)) : 0;
    const barClr = pct >= 90 ? 'var(--danger)' : pct >= 70 ? '#E2A020' : 'var(--success)';
    const txList = txAll.filter(t => t.knabId === k.id);
    return `<div class="envelope-card${hasGoal?' active':''}" id="knab-card-${k.id}">
      <div class="envelope-name">${esc(knabDisplayNaam(k))}</div>
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
```

door:

```javascript
  el.innerHTML = knab.map(k => {
    const hasGoal = k.doel && k.doel.trim() !== '';
    const uitgeg = calcKnabUitgegeven(k.id);
    const vorigSaldo = (typeof k.vorigSaldo === 'number') ? k.vorigSaldo : null;
    const beschikbaar = (k.gestort || 0) + (vorigSaldo || 0);
    const saldo = beschikbaar - uitgeg;
    const pct = beschikbaar > 0 ? Math.min(100, Math.round((uitgeg / beschikbaar) * 100)) : 0;
    const barClr = pct >= 90 ? 'var(--danger)' : pct >= 70 ? '#E2A020' : 'var(--success)';
    const txList = txAll.filter(t => t.knabId === k.id);
    const vorigSaldoRow = vorigSaldo === null
      ? `<div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Vorig saldo wordt berekend zodra je salaris gestort is</div>`
      : (vorigSaldo !== 0
        ? `<div style="display:flex;justify-content:space-between;font-size:11px;margin-bottom:4px">
             <span style="color:var(--text-muted)">Vorig saldo</span>
             <span class="${vorigSaldo > 0 ? 'fin-positive' : 'fin-negative'}">${vorigSaldo > 0 ? '+ ' : '− '}${finFmt(vorigSaldo)}</span>
           </div>`
        : '');
    return `<div class="envelope-card${hasGoal?' active':''}" id="knab-card-${k.id}">
      <div class="envelope-name">${esc(knabDisplayNaam(k))}</div>
      ${hasGoal ? `
        <div class="envelope-goal">${esc(k.doel)}</div>
        <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--text-muted);margin-bottom:4px">
          <span>Budget: ${finFmt(k.gestort)}</span>
          <span>Uitgeg: ${finFmt(uitgeg)}</span>
        </div>
        ${vorigSaldoRow}
        <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--text);font-weight:600;margin-bottom:4px">
          <span>Beschikbaar</span>
          <span>${finFmt(beschikbaar)}</span>
        </div>
        <div class="envelope-bar-track"><div class="envelope-bar-fill" style="width:${pct}%;background:${barClr}"></div></div>
        <div class="envelope-amounts" style="margin-top:6px">
          <span class="${saldo>0?'envelope-over':'envelope-leeg'}">Saldo: ${finFmt(saldo)}</span>
        </div>
```

De rest van de map-body (het `knab-tx-form`-blok, `txList`, `knabTxSummary`, "Bewerken"-knop, en de `else`-tak voor niet-ingestelde enveloppen) blijft ongewijzigd.

- [ ] **Step 2: Laat `calcKnabBespaard` het doorgerolde saldo meenemen**

Vervang `calcKnabBespaard()`:

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

door:

```javascript
function calcKnabBespaard() {
  const knab = getFinKnab();
  let totaal = 0;
  knab.forEach(k => {
    const beschikbaar = (k.gestort || 0) + (typeof k.vorigSaldo === 'number' ? k.vorigSaldo : 0);
    if (k.doel && beschikbaar > 0) {
      totaal += beschikbaar - calcKnabUitgegeven(k.id);
    }
  });
  return totaal;
}
```

- [ ] **Step 3: Laat de historie-afleiding het doorgerolde saldo meenemen**

In `loadAllData()`, in het `_db.finHistory = (allFinRes.data || []).map(f => ({ ... }))`-blok, vervang de `knabBesp`-regel:

```javascript
    knabBesp: (f.knab || []).reduce((s,k) => s + Math.max(0, (k.gestort||0) - (f.knab_tx||[]).filter(t=>t.knabId===k.id).reduce((x,t)=>x+t.bedrag,0)), 0),
```

door:

```javascript
    knabBesp: (f.knab || []).reduce((s,k) => s + Math.max(0, (k.gestort||0) + (typeof k.vorigSaldo === 'number' ? k.vorigSaldo : 0) - (f.knab_tx||[]).filter(t=>t.knabId===k.id).reduce((x,t)=>x+t.bedrag,0)), 0),
```

- [ ] **Step 4: Verifieer dat het dashboard onveranderd blijft**

Open de app → Financiën. Controleer dat `calcKnabStortingen()` NIET is aangeraakt en nog steeds de som van `k.gestort` teruggeeft:

```javascript
calcKnabStortingen()  // som van alleen de gestorte bedragen, geen vorigSaldo
```

De dashboardregels "Knab stortingen", "Al van rekening", "Echt restant" moeten identiek zijn aan vóór deze taak (er is nog geen `vorigSaldo` gezet deze maand, of het is 0).

- [ ] **Step 5: Verifieer de envelop-weergave via de console**

```javascript
// geen doorrol gebeurd
window._db.fin.knab.forEach(k => k.vorigSaldo = undefined); buildFinKnab();
// → elke ingestelde envelop toont "Vorig saldo wordt berekend zodra je salaris gestort is"

// positief doorgerold saldo
const b = window._db.fin.knab.find(k => k.doel === 'Boodschappen');
if (b) { b.vorigSaldo = 40; buildFinKnab(); }
// → "Vorig saldo  + € 40,00" (groen), "Beschikbaar" = budget + 40, balk/saldo rekenen vanaf beschikbaar

// negatief
if (b) { b.vorigSaldo = -20; buildFinKnab(); }
// → "Vorig saldo  − € 20,00" (rood), "Beschikbaar" = budget − 20

// nul → geen Vorig-saldo-regel
if (b) { b.vorigSaldo = 0; buildFinKnab(); }
```

Herstel met `location.reload()`. Check mobiel (375px): de "Vorig saldo"- en "Beschikbaar"-regels passen zonder overflow.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: toon Vorig saldo + Beschikbaar per Knab-envelop"
```

---

### Task 6: Integratietest + deploy

**Files:**
- Geen wijzigingen — alleen testen + deployen

**Interfaces:**
- Consumes: alle features uit Task 1–5

- [ ] **Step 1: Volledige end-to-end simulatie in de browser-console**

Open de app → Financiën. Simuleer een complete maandwissel:

```javascript
// 1. Simuleer een afgesloten vorige maand met een over- en een tekort-envelop
window._db.finHistory.push({
  maand: '2000-01',
  _raw: {
    month_key: '2000-01',
    salaris: 3700,
    vaste: window._db.fin.vaste,
    knab: [
      { id: 2, doel: 'Boodschappen', gestort: 300, vorigSaldo: 0 },
      { id: 1, doel: 'Benzine', gestort: 150, vorigSaldo: 0 }
    ],
    knab_tx: [
      { id: 1, knabId: 2, bedrag: 260 },  // Boodschappen: +40 over
      { id: 2, knabId: 1, bedrag: 175 }   // Benzine: -25 tekort
    ],
    betaald: { "1": "2000-01-03", "2": "2000-01-02" }
  }
});

// 2. Zet deze maand terug op "salaris niet ontvangen" om de doorrol te triggeren
window._db.fin.salaris_ontvangen = false;
window._db.fin.knab.forEach(k => k.vorigSaldo = null);

// 3. Trigger
markSalarisOntvangen(getFinSalaris());

// 4. Controleer
window._db.fin.knab.find(k => k.doel === 'Boodschappen').vorigSaldo;  // → 40
window._db.fin.knab.find(k => k.doel === 'Benzine').vorigSaldo;       // → -25
```

Verwacht in de UI na stap 3:
1. De envelop "Boodschappen" toont "Vorig saldo + € 40,00" (groen) en een hogere "Beschikbaar"
2. De envelop "Benzine" toont "Vorig saldo − € 25,00" (rood) en een lagere "Beschikbaar"
3. Het maandoverzicht-popup van de "vorige maand" opent
4. De dashboardregel "Knab stortingen" is onveranderd (som van `k.gestort`, niet beschikbaar)
5. "Al van rekening", "Komt nog deze maand", "Echt restant" kloppen nog

- [ ] **Step 2: Verifieer de vier features samen**

1. **Doorlopende lijst**: `seedNieuweMaand(_db.finHistory.slice(-1)[0]._raw)` geeft de vaste-lasten-lijst van de vorige maand terug, met `betaald: {}` en `knab[].vorigSaldo: null`
2. **Betaald blijft staan**: vink 2 vaste lasten af, `location.reload()`, ze staan nog afgevinkt met datum
3. **Geleerde datum**: `_db.finGeleerdeDagen` is gevuld zodra ≥2 maanden betaaldatums bestaan; de tijdlijn en de "Meestal rond de Xe"-hint gebruiken die
4. **Knab-doorrol**: zie Step 1

- [ ] **Step 3: Responsive check**

- Mobiel 375px: geen horizontale overflow op envelop-kaarten, tijdlijn, vaste lasten
- Tablet 768px en desktop 1280px: layout blijft netjes, max-breedte gecentreerd

- [ ] **Step 4: `location.reload()` en bevestig een schone staat**

Geen console-errors. Alle geïnjecteerde test-data is weg na reload (het stond alleen in geheugen, niet in Supabase — tenzij je `markSalarisOntvangen` hebt aangeroepen; zie Step 5).

- [ ] **Step 5: Ruim test-neveneffecten op**

`markSalarisOntvangen()` in Step 1 heeft `_saveFinance()` aangeroepen en dus `vorigSaldo`-waarden + `salaris_ontvangen` naar Supabase geschreven voor de huidige maand. Als die waarden niet kloppen met de echte situatie:
- Zet `salaris_ontvangen` terug indien nodig: `window._db.fin.salaris_ontvangen = false;`
- Herbereken op basis van de echte vorige maand, of zet handmatig: `window._db.fin.knab.forEach(k => k.vorigSaldo = null); _saveFinance();`
- `location.reload()` en controleer de Financiën-tab

(Doe Step 1 bij voorkeur op een testaccount of accepteer dat je daarna de huidige-maand-waarden even rechtzet.)

- [ ] **Step 6: Deploy**

```bash
git push origin master
```

- [ ] **Step 7: Verifieer productie**

Open `https://merry-kelpie-eec436.netlify.app`, hard-refresh (Ctrl+Shift+R). Controleer dat de Financiën-tab laadt, de enveloppen "Beschikbaar" tonen, en er geen console-errors zijn.

---

## Self-Review

**Spec-dekking:**
- Feature 1 (doorlopende vaste-lasten-lijst) → Task 1 ✓
- Feature 2 (betaald-status blijft staan) → geen code nodig; geverifieerd in Task 6 Step 2.2 ✓
- Feature 3 (zelflerende betaaldata: leren + gebruik in tijdlijn) → Task 2 ✓; UI-hint → Task 3 ✓
- Feature 4 (Knab-doorrol bij "Salaris gestort") → Task 4 (berekening + trigger) ✓; envelop-weergave "Vorig saldo"/"Beschikbaar" → Task 5 ✓
- "geen aparte idempotentie-vlag, hangt aan `salaris_ontvangen`-transitie" → Task 4 Step 2 + Step 4 ✓
- "Knab stortingen-dashboardregel blijft som van `k.gestort`" → Task 5 Step 4 (expliciet geverifieerd, `calcKnabStortingen` niet aangeraakt) ✓
- "overschot blijft besteedbaar" → Task 5 Step 1 (`beschikbaar` bevat positief `vorigSaldo`) ✓
- Fallback naar `FIN_DEFAULT_*` bij eerste gebruik ooit → Task 1 Step 1 (`if (!prev)`-tak) ✓
- Geen SQL-migratie → bevestigd, alleen `jsonb`-velden ✓

**Placeholder-scan:** geen TBD/TODO/"handle edge cases". Alle code-stappen hebben volledige codeblokken.

**Type-consistentie:**
- `seedNieuweMaand(prev)` — gedefinieerd Task 1, gebruikt Task 1 Step 2 + Task 6
- `berekenGeleerdeDagen(prevRows, huidigFin)` — gedefinieerd Task 2, aangeroepen Task 2 Step 3
- `voorspeldeDag(v)` — gedefinieerd Task 2, gebruikt Task 2 Step 4 (tijdlijn); Task 3 gebruikt bewust `_db.finGeleerdeDagen[String(v.id)]` direct (heeft alleen de geleerde dag nodig, niet de `v.dag`-fallback)
- `rolKnabSaldoDoor()` — gedefinieerd Task 4, aangeroepen Task 4 Step 2
- `k.vorigSaldo` — gezet in Task 1 (`null`) + Task 4 (number/0); gelezen in Task 5 met `typeof k.vorigSaldo === 'number'`-guard (behandelt `null` én `undefined`)
- `_db.finGeleerdeDagen` — gedeclareerd Task 2 Step 1, gevuld Task 2 Step 3, gelezen Task 2/Task 3
- `calcKnabStortingen()` — bewust NIET gewijzigd (Global Constraints + Task 5 Step 4)
