# ANWB Betaling Hoofdrekening-koppeling & Geschiedenis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user checks off an ANWB Energie betalingsregeling-termijn as paid, subtract its bedrag from the Hoofdrekening saldo and record the date it was paid; show a small "Betaald" history list under the Betalingsregeling card so paid termijnen aren't just silently dropped.

**Architecture:** One data field (`betaaldOp`) added to each termijn object in the existing `anwbRegeling` array. `toggleAnwbBetaald` becomes bidirectional (mark paid / undo) and syncs `Hoofdrekening` in both directions, mirroring the pattern already used for vaste lasten (`toggleVasteBetaald`) and Knab budgets (`saveKnabSetup`/`saveEditKnab`). `buildFinAnwbRegeling` renders two lists instead of one: open termijnen (unchanged) and a new compact paid-history list.

**Tech Stack:** Vanilla HTML/CSS/JS, single-file app (`index.html`), Supabase-backed `settings.profiel.anwbRegeling` (via `getAnwbRegeling()`/`saveAnwbRegeling()`)

## Global Constraints

- Single file: all HTML, CSS, and JS lives in `index.html`
- No frameworks, no build step, no test runner — verification is a `node -e` syntax check plus a manual browser walkthrough
- Dark theme only (CSS vars: `--gold`, `--surface-2`, `--text`, `--text-muted`, `--danger`, `--success`)
- Helper functions already in the file: `finFmt(n)` formats currency, `esc(s)` escapes HTML, `localDateStr(date)` returns `YYYY-MM-DD`, `getHoofdrekeningSaldo()`/`saveHoofdrekeningSaldo(n)` read/write the tracked balance, `getAnwbRegeling()`/`saveAnwbRegeling(list)` read/write the termijnen array, `showToast(msg)` shows a toast
- Scope: only the ANWB termijnen. ICS/Klarna schulden are explicitly out of scope (no payment history, no Hoofdrekening link) per `docs/superpowers/specs/2026-08-25-anwb-betaling-log-design.md`
- Deploy: `git push` to master triggers Netlify deploy

---

### Task 1: Bidirectional toggle + Hoofdrekening sync + Betaald-geschiedenis UI

**Files:**
- Modify: `index.html:2052-2077` (`buildFinAnwbRegeling`, `toggleAnwbBetaald`)

**Interfaces:**
- Consumes: `getAnwbRegeling() → array` of `{id, bedrag, datum, betaald, betaaldOp?}`, `saveAnwbRegeling(list) → void`, `getHoofdrekeningSaldo() → number`, `saveHoofdrekeningSaldo(n) → void`, `finFmt(n) → string`, `localDateStr() → string` (today, YYYY-MM-DD), `showToast(msg) → void`
- Produces: `toggleAnwbBetaald(id) → void` (now bidirectional — marks paid and subtracts from Hoofdrekening, or un-marks and adds back), `buildFinAnwbRegeling() → void` (renders both the open list and the new "Betaald" list)

- [ ] **Step 1: Replace `buildFinAnwbRegeling` and `toggleAnwbBetaald`**

Replace lines 2052-2077 in `index.html` with:

```javascript
function buildFinAnwbRegeling() {
  const el     = document.getElementById('finAnwbRegeling'); if(!el) return;
  const openEl = document.getElementById('anwbOpenTotaal');
  const alle   = getAnwbRegeling();
  const open   = alle.filter(t => !t.betaald);
  const betaald = alle.filter(t => t.betaald);
  if(openEl) openEl.textContent = open.length ? finFmt(open.reduce((s,t)=>s+t.bedrag,0)) + ' open' : 'Alles betaald ✓';

  const openHtml = open.length ? open.map(t => {
    const datumTxt = new Date(t.datum+'T00:00:00').toLocaleDateString('nl-NL',{day:'numeric',month:'long',year:'numeric'});
    return `<div class="fin-list-item" id="fin-anwb-${t.id}">
      <button class="fin-betaald-btn" onclick="toggleAnwbBetaald(${t.id})" title="Markeer als betaald">&#9675;</button>
      <div class="fin-item-info">
        <div class="fin-item-naam">Termijn</div>
        <div class="fin-betaald-datum">Uiterlijk ${datumTxt}</div>
      </div>
      <div class="fin-item-amount">${finFmt(t.bedrag)}</div>
    </div>`;
  }).join('') : '<div style="font-size:13px;color:var(--text-muted);padding:8px 0">Alle termijnen betaald.</div>';

  const betaaldHtml = betaald.length ? `
    <div style="font-size:10px;letter-spacing:0.12em;text-transform:uppercase;color:var(--text-muted);margin:14px 0 6px">Betaald</div>
    ${betaald.slice().sort((a,b) => (b.betaaldOp||'').localeCompare(a.betaaldOp||'')).map(t => {
      const datumTxt = t.betaaldOp ? new Date(t.betaaldOp+'T00:00:00').toLocaleDateString('nl-NL',{day:'numeric',month:'short',year:'numeric'}) : '';
      return `<div class="fin-list-item betaald" id="fin-anwb-${t.id}">
        <button class="fin-betaald-btn done" onclick="toggleAnwbBetaald(${t.id})" title="Terugzetten naar onbetaald">&#10003;</button>
        <div class="fin-item-info">
          <div class="fin-item-naam">Termijn</div>
          ${datumTxt ? `<div class="fin-betaald-datum">Betaald op ${datumTxt}</div>` : ''}
        </div>
        <div class="fin-item-amount">${finFmt(t.bedrag)}</div>
      </div>`;
    }).join('')}` : '';

  el.innerHTML = openHtml + betaaldHtml;
}

function toggleAnwbBetaald(id) {
  const list = getAnwbRegeling();
  const item = list.find(t => t.id === id);
  if (!item) return;
  if (item.betaald) {
    item.betaald = false;
    item.betaaldOp = null;
    saveHoofdrekeningSaldo(getHoofdrekeningSaldo() + item.bedrag);
    showToast('Termijn teruggezet naar onbetaald');
  } else {
    item.betaald = true;
    item.betaaldOp = localDateStr();
    saveHoofdrekeningSaldo(getHoofdrekeningSaldo() - item.bedrag);
    showToast('Termijn gemarkeerd als betaald');
  }
  saveAnwbRegeling(list);
  buildFinAnwbRegeling();
  buildFinDashboard();
}
```

- [ ] **Step 2: Syntax-check the inline script**

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

- [ ] **Step 3: Test in browser**

Open the app (logged in), navigate to Financiën tab, scroll to "Betalingsregeling — ANWB Energie". Verify:

1. Note the current Hoofdrekening value shown further down the dashboard.
2. Click the circle button on an open termijn to mark it paid. Verify:
   - It disappears from the open list (or the open list shows "Alle termijnen betaald." if that was the last one)
   - A new "Betaald" section appears below with that termijn, showing "Betaald op <today's date>"
   - The "open" total at the top of the card decreases by that termijn's bedrag (or shows "Alles betaald ✓" if none left)
   - Hoofdrekening (scroll down) decreased by exactly that termijn's bedrag
3. Click the checkmark button on the item now in the "Betaald" list. Verify:
   - It moves back to the open list, "Uiterlijk <datum>" shown again
   - Hoofdrekening increased back by the same bedrag (matches the value noted in step 1)
4. Refresh the page. Verify the paid/unpaid state and Hoofdrekening value both persisted correctly.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: sync ANWB termijn betaling with hoofdrekening + toon betaal-geschiedenis"
```

---

## Post-plan

- Push to `origin/master` when the user confirms (per established workflow in this project — commits are not auto-pushed).
