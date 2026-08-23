# Rapport Huiswerk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the printed therapy report's date range, drop a redundant summary row, and add a homework ("huiswerk") field per logged session with three fixed reflection questions that appear both on the Sessie tab and in the printed report.

**Architecture:** Single-file vanilla JS PWA (`index.html`, no build step, no framework). All state lives in the in-memory `_db` object, synced to Supabase tables. This plan touches one file only: `index.html`. No new tables — homework text and answers ride along on the existing `coach_sessions.data` JSONB blob, which currently is insert-only; this plan adds row-id tracking so it can also be updated.

**Tech Stack:** Vanilla JS (ES6+), Supabase JS client (`sb`), no test framework — verification is manual, in-browser, via the DevTools console.

## Global Constraints

- One file to edit: `C:\Users\MrBla\Documents\daily-coach\index.html`. Do not create new files.
- Follow the codebase's existing conventions exactly: inline `onclick`/`oninput` HTML attributes for dynamically-rendered elements (not `addEventListener`), `esc()` for HTML-escaping text that becomes innerHTML, template-literal string building for dynamic sections (see `loadSessieList()`, `buildRapport()` as reference patterns).
- No AI/LLM integration. The three reflection questions are fixed, hardcoded text — never content-generated.
- No new Supabase tables or columns. Everything rides on the existing `coach_sessions.data` JSONB column.
- Design source of truth: `docs/superpowers/specs/2026-08-23-rapport-huiswerk-design.md`. One deliberate refinement made during planning (documented in Task 5): the report/card key off `getSessions()[0]` (the most recently *logged* session) rather than `prev` from `getTherapiePeriode()` (a *scheduled* date) — simpler and doesn't depend on the log entry's date exactly matching the schedule.

---

## Task 1: Fix the therapy-period date range bug

**Files:**
- Modify: `index.html:1471-1477` (inside `getTherapiePeriode()`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `getTherapiePeriode()` still returns `{ prev, endDate, next }`, same shape, only `prev`'s value changes (now one day later when derived from a real session date).

- [ ] **Step 1: Locate and read the current function**

Open `index.html`, find `getTherapiePeriode()`. The relevant loop currently reads:

```js
  let prev = getStartDate();
  for (let i = idx - 1; i >= 0; i--) {
    const sd = _db.sessions_data[alleSessies[i].date];
    if (sd && sd.status === 'overgeslagen') continue;
    prev = parseDate(alleSessies[i].date);
    break;
  }
```

- [ ] **Step 2: Apply the fix**

Replace that block with:

```js
  let prev = getStartDate();
  for (let i = idx - 1; i >= 0; i--) {
    const sd = _db.sessions_data[alleSessies[i].date];
    if (sd && sd.status === 'overgeslagen') continue;
    prev = parseDate(alleSessies[i].date);
    prev.setDate(prev.getDate() + 1); // period starts the day AFTER the session, not on it
    break;
  }
```

Do not touch the `if (!actief) { ... }` branch above this loop — `prev` there comes from `getStartDate()` (program start), not a session date, and must stay unchanged.

- [ ] **Step 3: Verify in the browser console**

Serve the app locally (e.g. `npx http-server . -p 4174` from the project root) and open it. Bypass the login gate for testing (this only toggles local DOM visibility, it does not create a session or touch Supabase):

```js
document.getElementById('loginScreen').style.display = 'none';
document.getElementById('app').style.display = 'block';
```

Seed a fake schedule and call the function directly in the console:

```js
_db.therapy = [{ date: '2026-08-17' }, { date: '2026-08-27' }];
_db.sessions_data = {};
window.__origActief = getActieveSessie;
getActieveSessie = () => ({ date: '2026-08-27' });
const r = getTherapiePeriode();
[r.prev.toISOString().slice(0,10), r.endDate.toISOString().slice(0,10)];
```

Expected: `["2026-08-18", "2026-08-26"]` — the 17th itself is excluded, the 26th (day before the next session) is still the end.

Restore afterward: `getActieveSessie = window.__origActief;`

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "fix: exclude session day itself from therapie-periode range"
```

---

## Task 2: Remove the "Actieve doelen" row from the Overzicht section

**Files:**
- Modify: `index.html:2692-2698` (inside `buildRapport()`)

**Interfaces:**
- Consumes: nothing new.
- Produces: no change to any function signature; only the rendered HTML string changes.

- [ ] **Step 1: Locate the current block**

```js
  html += `<div class="rapport-section"><h3>Overzicht</h3>
    <div class="rapport-row"><span class="rapport-label">Dag in programma</span><span class="rapport-value">${day} van 365</span></div>
    <div class="rapport-row"><span class="rapport-label">Fase</span><span class="rapport-value">${document.getElementById('phaseName').textContent}</span></div>
    <div class="rapport-row"><span class="rapport-label">Therapiesessies gelogd</span><span class="rapport-value">${sessions.length}</span></div>
    <div class="rapport-row"><span class="rapport-label">Actieve doelen</span><span class="rapport-value">${goals.length}</span></div>
  </div>`;
```

- [ ] **Step 2: Remove the "Actieve doelen" row**

```js
  html += `<div class="rapport-section"><h3>Overzicht</h3>
    <div class="rapport-row"><span class="rapport-label">Dag in programma</span><span class="rapport-value">${day} van 365</span></div>
    <div class="rapport-row"><span class="rapport-label">Fase</span><span class="rapport-value">${document.getElementById('phaseName').textContent}</span></div>
    <div class="rapport-row"><span class="rapport-label">Therapiesessies gelogd</span><span class="rapport-value">${sessions.length}</span></div>
  </div>`;
```

Leave the separate `Actieve therapiedoelen & acties` section (a few lines below, starting `if (goals.length || actions.length)`) untouched — it is not part of this change.

- [ ] **Step 3: Verify**

In the console (with the login bypass from Task 1 still active):

```js
_db.days = {}; _db.goals = { active_goals: ['test doel'] };
buildRapport('sessie');
document.getElementById('rapportBody').innerHTML.includes('Actieve doelen');
```

Expected: `false`. Then confirm the detailed section still renders:

```js
document.getElementById('rapportBody').innerHTML.includes('Actieve therapiedoelen');
```

Expected: `true`.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "fix: remove redundant Actieve doelen row from rapport Overzicht"
```

---

## Task 3: Track the Supabase row id for logged sessions so they can be updated later

**Files:**
- Modify: `index.html:1115` (initial load mapping)
- Modify: `index.html:2504` (insert call in `saveSessie()`)
- Modify: `index.html` — add new function `_saveSessieUpdate` near the other `_save*` helpers (after `_saveSettings`, i.e. after line 1190)

**Interfaces:**
- Produces: `_saveSessieUpdate(sessie)` — takes a session object (as stored in `_db.sessions`, which may carry a `_rowId` property), strips `_rowId`, and upserts the rest back to its Supabase row. No return value; logs to console on error, matching every other `_save*` function's error-handling style in this file.
- Produces: every object in `_db.sessions` now carries a `_rowId` string (the Supabase UUID) once loaded from the database, or once a newly-created session's insert has round-tripped.
- Consumed by: Task 5's `onHuiswerkAntwoordInput`.

- [ ] **Step 1: Capture the row id on initial load**

Find:

```js
  _db.sessions = (sessionsRes.data || []).map(r => r.data);
```

Replace with:

```js
  _db.sessions = (sessionsRes.data || []).map(r => ({ ...r.data, _rowId: r.id }));
```

- [ ] **Step 2: Add the update helper**

Directly after `_saveSettings()` (which ends at line 1190 with a closing `}`), add:

```js
function _saveSessieUpdate(sessie) {
  if (!sessie._rowId) return;
  const { _rowId, ...clean } = sessie;
  sb.from('coach_sessions').update({ data: clean }).eq('id', _rowId).then(r => { if (r.error) console.error('sessie update:', r.error); });
}
```

- [ ] **Step 3: Capture the row id when a session is first inserted**

In `saveSessie()`, find:

```js
  sb.from('coach_sessions').insert({ user_id: currentUser.id, date: sessie.date || localDateStr(), data: sessie }).then(r => { if(r.error) console.error('sessie save:', r.error); });
```

Replace with:

```js
  sb.from('coach_sessions').insert({ user_id: currentUser.id, date: sessie.date || localDateStr(), data: sessie }).select().then(r => {
    if (r.error) { console.error('sessie save:', r.error); return; }
    if (r.data && r.data[0]) sessie._rowId = r.data[0].id;
  });
```

`sessie` here is the same object already pushed into `_db.sessions` via `_db.sessions.unshift(sessie)` a few lines above — mutating it in place after the insert resolves is correct and sufficient; no separate re-fetch is needed.

- [ ] **Step 4: Verify the helper in isolation**

Console (login bypass active, and note this step performs a REAL write against Supabase — only run it while genuinely logged in, not with the display-toggle bypass, since `currentUser`/`_rowId` must be real):

```js
const before = getSessions()[0];
console.log('has _rowId:', !!before._rowId);
before.huiswerk = 'test-verify-delete-me';
_saveSessieUpdate(before);
```

Reload the page for real (not the bypass — a genuine login) and confirm `getSessions()[0].huiswerk === 'test-verify-delete-me'`, then manually clear that test value the same way before moving on, so no test data is left behind.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: track Supabase row id for logged sessions to allow updates"
```

---

## Task 4: Add the "Huiswerk meegekregen" field to the session-logging form

**Files:**
- Modify: `index.html:680-683` (form markup inside `#tab-sessie`)
- Modify: `index.html:2490-2513` (`saveSessie()`)

**Interfaces:**
- Consumes: nothing new from other tasks.
- Produces: every newly-logged session object now has `huiswerk` (string), `hw_a1`, `hw_a2`, `hw_a3` (strings, empty at creation) — the fields Task 5 and Task 6 read.

- [ ] **Step 1: Add the form field**

Find, inside the `#tab-sessie` "Nieuwe sessie toevoegen" card:

```html
        <div class="form-group">
          <label class="form-label">Inzichten</label>
          <textarea id="sessieInzichten" placeholder="Wat heb je geleerd of erkend?" rows="3"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Doelen (actief in dagelijkse check-in)</label>
```

Insert a new field between them:

```html
        <div class="form-group">
          <label class="form-label">Inzichten</label>
          <textarea id="sessieInzichten" placeholder="Wat heb je geleerd of erkend?" rows="3"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Huiswerk meegekregen</label>
          <textarea id="sessieHuiswerk" placeholder="Wat heeft de psycholoog je meegegeven om te doen?" rows="3"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Doelen (actief in dagelijkse check-in)</label>
```

- [ ] **Step 2: Read and store the field in `saveSessie()`**

Find:

```js
function saveSessie() {
  const date      = document.getElementById('sessieDate').value;
  const tijd      = document.getElementById('sessieTime').value;
  const locatie   = document.getElementById('sessieLocatie').value;
  const onderwerp = document.getElementById('sessieOnderwerpen').value.trim();
  const inzichten = document.getElementById('sessieInzichten').value.trim();
  if (!date && !onderwerp) return;
  const sessie = {
    id:         Date.now(),
    date, tijd, locatie,
    dateLabel:  date ? parseDate(date).toLocaleDateString('nl-NL',{weekday:'long',day:'numeric',month:'long',year:'numeric'}) : 'Ongedateerd',
    onderwerpen: onderwerp, inzichten, doelen: [...newGoals], acties: [...newActions]
  };
```

Replace with:

```js
function saveSessie() {
  const date      = document.getElementById('sessieDate').value;
  const tijd      = document.getElementById('sessieTime').value;
  const locatie   = document.getElementById('sessieLocatie').value;
  const onderwerp = document.getElementById('sessieOnderwerpen').value.trim();
  const inzichten = document.getElementById('sessieInzichten').value.trim();
  const huiswerk  = document.getElementById('sessieHuiswerk').value.trim();
  if (!date && !onderwerp) return;
  const sessie = {
    id:         Date.now(),
    date, tijd, locatie,
    dateLabel:  date ? parseDate(date).toLocaleDateString('nl-NL',{weekday:'long',day:'numeric',month:'long',year:'numeric'}) : 'Ongedateerd',
    onderwerpen: onderwerp, inzichten, doelen: [...newGoals], acties: [...newActions],
    huiswerk, hw_a1: '', hw_a2: '', hw_a3: ''
  };
```

- [ ] **Step 3: Clear the field after saving**

Find:

```js
  document.getElementById('sessieOnderwerpen').value = '';
  document.getElementById('sessieInzichten').value   = '';
```

Replace with:

```js
  document.getElementById('sessieOnderwerpen').value = '';
  document.getElementById('sessieInzichten').value   = '';
  document.getElementById('sessieHuiswerk').value    = '';
```

- [ ] **Step 4: Verify**

Console (login bypass active):

```js
document.getElementById('sessieOnderwerpen').value = 'test';
document.getElementById('sessieHuiswerk').value = 'Vraag je ouders naar hun jeugd';
_db.sessions = []; newGoals = []; newActions = [];
saveSessie();
getSessions()[0].huiswerk === 'Vraag je ouders naar hun jeugd' && getSessions()[0].hw_a1 === '';
```

Expected: `true`. (This call does attempt a real Supabase insert since `saveSessie()` isn't stubbed — if not genuinely logged in it will log a console error from the failed insert, which is expected and harmless for this check; the assertion above only concerns local state.)

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: capture huiswerk text when logging a therapy session"
```

---

## Task 5: Huiswerk reflection card on the Sessie tab

**Files:**
- Modify: `index.html:703-705` (add new section markup between "Nieuwe sessie toevoegen" and "Actieve doelen en acties")
- Modify: `index.html` — add `HW_QUESTIONS` constant, `renderHuiswerkCard()`, `onHuiswerkAntwoordInput()`, `escText()` near `loadSessieList()` (after line 2530)
- Modify: `index.html` — call `renderHuiswerkCard()` from `saveSessie()` and from app init

**Interfaces:**
- Consumes: `_saveSessieUpdate(sessie)` from Task 3; `getSessions()` (existing); `esc()` (existing).
- Produces: `HW_QUESTIONS` — a module-level array `[{key, label}, ...]`, three entries, keys `hw_a1`/`hw_a2`/`hw_a3`. Task 6 reuses this exact constant (do not redefine it locally in `buildRapport()`).
- Produces: `renderHuiswerkCard()` — no args, no return value, reads `getSessions()[0]` and updates the DOM.
- Produces: `escText(s)` — like `esc()` but does not convert newlines to `<br>`; used for pre-filling `<textarea>` innerHTML so raw newlines survive as real newlines instead of literal `<br>` text.

- [ ] **Step 1: Add the section markup**

Find:

```html
        <button class="save-btn" onclick="saveSessie()">Sessie opslaan</button>
        <div class="saved-msg" id="sessieSavedMsg">Sessie opgeslagen</div>
      </div>
    </div>

    <div class="section" id="activeGoalsSection" style="display:none">
```

Insert a new section between the two:

```html
        <button class="save-btn" onclick="saveSessie()">Sessie opslaan</button>
        <div class="saved-msg" id="sessieSavedMsg">Sessie opgeslagen</div>
      </div>
    </div>

    <div class="section" id="huiswerkSection" style="display:none">
      <h2 class="section-title">Huiswerk</h2>
      <div class="card" id="huiswerkCard"></div>
    </div>

    <div class="section" id="activeGoalsSection" style="display:none">
```

- [ ] **Step 2: Add `escText`, `HW_QUESTIONS`, and the render/save functions**

Directly after `loadSessieList()` (which ends at line 2530 with `}`), add:

```js
function escText(s) {
  if (!s) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

const HW_QUESTIONS = [
  { key: 'hw_a1', label: 'Heb je dit kunnen doen?' },
  { key: 'hw_a2', label: 'Hoe voelde het?' },
  { key: 'hw_a3', label: 'Wat viel je op?' }
];

function renderHuiswerkCard() {
  const section = document.getElementById('huiswerkSection');
  const card = document.getElementById('huiswerkCard');
  const last = getSessions()[0];
  if (!last || !last.huiswerk) { section.style.display = 'none'; return; }
  section.style.display = 'block';
  card.innerHTML = `
    <div class="session-field-label" style="margin-bottom:6px">Opdracht</div>
    <div class="session-field-value" style="margin-bottom:16px">${esc(last.huiswerk)}</div>
    ${HW_QUESTIONS.map(q => `
      <div class="form-group">
        <label class="form-label">${q.label}</label>
        <textarea rows="2" oninput="onHuiswerkAntwoordInput('${q.key}', this.value)">${escText(last[q.key] || '')}</textarea>
      </div>
    `).join('')}
  `;
}

let _huiswerkSaveTimer = null;
function onHuiswerkAntwoordInput(key, value) {
  const last = getSessions()[0];
  if (!last) return;
  last[key] = value;
  clearTimeout(_huiswerkSaveTimer);
  _huiswerkSaveTimer = setTimeout(() => _saveSessieUpdate(last), 2000);
}
```

- [ ] **Step 3: Call `renderHuiswerkCard()` where the session list is loaded**

`loadSessieList()` is called in two places: once from `saveSessie()`, once from app `init()`. Find the `saveSessie()` call:

```js
  showToast('✓ Sessie opgeslagen');
  loadSessieList(); loadActiveGoals(); loadTherapyQuestions();
```

Replace with:

```js
  showToast('✓ Sessie opgeslagen');
  loadSessieList(); loadActiveGoals(); loadTherapyQuestions(); renderHuiswerkCard();
```

`loadSessieList()` is also called once during app `init()`, in this sequence:

```js
  loadSessieList();
  loadArchive();
  buildPrepBannerToday();
  buildWeekDots();
  checkEmptyState();
  buildWeekSummary();
```

Replace with:

```js
  loadSessieList();
  renderHuiswerkCard();
  loadArchive();
  buildPrepBannerToday();
  buildWeekDots();
  checkEmptyState();
  buildWeekSummary();
```

- [ ] **Step 4: Verify rendering**

Console (login bypass active):

```js
_db.sessions = [{ id: 1, date: '2026-08-17', dateLabel: '17 augustus 2026', huiswerk: 'Vraag je ouders naar hun jeugd', hw_a1: '', hw_a2: '', hw_a3: '' }];
renderHuiswerkCard();
document.getElementById('huiswerkSection').style.display;
```

Expected: `"block"`. Then:

```js
document.getElementById('huiswerkCard').innerHTML.includes('Vraag je ouders naar hun jeugd') &&
document.getElementById('huiswerkCard').querySelectorAll('textarea').length === 3;
```

Expected: `true`.

- [ ] **Step 5: Verify the empty case**

```js
_db.sessions = [{ id: 2, date: '2026-08-20', dateLabel: '20 augustus 2026', huiswerk: '' }];
renderHuiswerkCard();
document.getElementById('huiswerkSection').style.display;
```

Expected: `"none"`.

- [ ] **Step 6: Verify newline handling in `escText`**

```js
escText('regel een\nregel twee');
```

Expected: `"regel een\nregel twee"` (unchanged — real newline, not `<br>`), confirming a saved multi-line answer will redisplay correctly inside a `<textarea>` rather than showing literal `<br>` text.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: render huiswerk reflection card with autosaving answers on Sessie tab"
```

---

## Task 6: Huiswerk section in the printed rapport

**Files:**
- Modify: `index.html:2690-2692` (inside `buildRapport()`, between the "Niet-doorgegane sessies" block and the "Overzicht" section)

**Interfaces:**
- Consumes: `HW_QUESTIONS` (from Task 5 — do not redefine locally), `getSessions()`, `esc()`.
- Produces: no new exports; only changes the HTML `buildRapport()` writes into `#rapportBody`.

- [ ] **Step 1: Locate the insertion point**

Find the end of the "Niet-doorgegane sessies" block and the start of "Overzicht":

```js
      html += `</div>`;
    }
  }

  // ── 1. OVERZICHT ──────────────────────────────────────────
```

- [ ] **Step 2: Insert the new section**

```js
      html += `</div>`;
    }
  }

  // ── 0c. HUISWERK ───────────────────────────────────────────
  if (mode === 'sessie') {
    const lastSessie = getSessions()[0];
    if (lastSessie && lastSessie.huiswerk) {
      html += `<div class="rapport-section"><h3>Huiswerk</h3>
        <div class="rapport-note"><div class="rapport-note-label">Opdracht</div>${esc(lastSessie.huiswerk)}</div>`;
      HW_QUESTIONS.forEach(q => {
        if (lastSessie[q.key]) {
          html += `<div class="rapport-note"><div class="rapport-note-label">${q.label}</div>${esc(lastSessie[q.key])}</div>`;
        }
      });
      html += `</div>`;
    }
  }

  // ── 1. OVERZICHT ──────────────────────────────────────────
```

Note this deliberately keys off `getSessions()[0]` (the most recently *logged* session), not `prev` from `getTherapiePeriode()` — see the Global Constraints note on this refinement.

- [ ] **Step 3: Verify placement and content**

Console (login bypass active, building on Task 5 Step 4's seeded session with `hw_a1` filled in):

```js
_db.sessions = [{ id: 1, date: '2026-08-17', dateLabel: '17 augustus 2026', huiswerk: 'Vraag je ouders naar hun jeugd', hw_a1: 'Ja, gedaan', hw_a2: '', hw_a3: '' }];
_db.days = {};
buildRapport('sessie');
const body = document.getElementById('rapportBody').innerHTML;
const hwIndex = body.indexOf('Huiswerk');
const overzichtIndex = body.indexOf('Overzicht');
[hwIndex > -1, hwIndex < overzichtIndex, body.includes('Vraag je ouders naar hun jeugd'), body.includes('Ja, gedaan'), body.includes('Hoe voelde het?')];
```

Expected: `[true, true, true, true, false]` — the section exists, appears before Overzicht, shows the assignment and the one filled-in answer, and does *not* show the label for an unanswered question (`hw_a2`/`Hoe voelde het?` was left empty).

- [ ] **Step 4: Verify the section is absent with no homework**

```js
_db.sessions = [{ id: 2, date: '2026-08-20', dateLabel: '20 augustus 2026', huiswerk: '' }];
buildRapport('sessie');
document.getElementById('rapportBody').innerHTML.includes('<h3>Huiswerk</h3>');
```

Expected: `false`.

- [ ] **Step 5: Print-preview sanity check**

With the same seeded data from Step 3 still rendered, open the browser's print preview (`Ctrl+P` / `Cmd+P`) and confirm the Huiswerk section renders with the same visual style as the other `.rapport-section`/`.rapport-note` blocks (gold section heading, bordered note boxes) — no new CSS is needed since this reuses existing classes, but confirm visually since print stylesheets are easy to overlook a class on.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: show huiswerk section in printed rapport"
```

---

## Final check (after all six tasks)

- [ ] Re-read `getTherapiePeriode()`, `buildRapport()`, `saveSessie()`, and the new functions once more end-to-end to confirm nothing was left half-edited.
- [ ] With the login bypass, run through the full flow in one sequence: seed `_db.sessions = []`, fill and submit the "Nieuwe sessie toevoegen" form including "Huiswerk meegekregen", confirm the Huiswerk card appears on the Sessie tab, fill in one answer, confirm it autosaves into `getSessions()[0].hw_a1` after ~2s, then call `buildRapport('sessie')` and confirm the report shows the homework and that one answer.
- [ ] Log in for real once, on a real account, and confirm `_saveSessieUpdate` actually persists after a page reload (this is the one thing the display-toggle bypass cannot verify, since it never has a real `currentUser`).
