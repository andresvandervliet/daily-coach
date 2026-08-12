# Session-Bound Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Weekreflecties en rapporten koppelen aan therapiesessies met archief en automatische afsluiting.

**Architecture:** Alle sessie-data (reflecties, prep, rapport-snapshots) wordt opgeslagen in `_db.sessions_data[sessiedatum]`. De levenscyclus wordt bepaald door de sessie-status (actief/afgesloten). Het rapport-tab krijgt een archief-modus om snapshots van eerdere sessies te bekijken.

**Tech Stack:** Vanilla JS (single-file PWA index.html), Supabase (PostgreSQL + RLS), bestaande `_db` cache + fire-and-forget sync.

## Global Constraints

- Single-file PWA: alle wijzigingen in `index.html`
- Supabase project `psdtqbulxfyarowtjgex` (EU region)
- Bestaande sync-patronen volgen: `_db` cache → fire-and-forget upsert
- Geen externe dependencies toevoegen
- Alle UI in het Nederlands
- iOS segmented control styling voor knoppen (bestaand patroon)

---

### Task 1: Datamodel en Supabase tabel

**Files:**
- Modify: `index.html:1076-1086` (_db object)
- Modify: `index.html:1088-1119` (loadAllData)
- Supabase: nieuwe tabel `session_reports`

**Interfaces:**
- Produces: `_db.sessions_data` object, `_saveSessionReport(sessionDate)` functie, `session_reports` Supabase tabel

- [ ] **Step 1: Maak de Supabase tabel**

Open het Supabase dashboard (project `psdtqbulxfyarowtjgex`) en voer deze SQL uit:

```sql
CREATE TABLE session_reports (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  session_date text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, session_date)
);

ALTER TABLE session_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own session reports"
  ON session_reports FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session reports"
  ON session_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own session reports"
  ON session_reports FOR UPDATE
  USING (auth.uid() = user_id);
```

- [ ] **Step 2: Voeg `sessions_data` toe aan het `_db` object**

In `index.html`, wijzig het `_db` object op regel 1076:

```js
const _db = {
  days: {},
  weeks: {},
  sessions: [],
  sessions_data: {},
  goals: { active_goals: [], active_actions: [] },
  therapy: [],
  fin: {},
  finHistory: [],
  settings: {},
  preps: {}
};
```

- [ ] **Step 3: Laad session_reports in `loadAllData()`**

Voeg een extra query toe aan de `Promise.all` in `loadAllData()` (regel 1090). Voeg na regel 1098 toe:

```js
sb.from('session_reports').select('session_date,data').eq('user_id', currentUser.id),
```

Update de destructuring op regel 1102 — voeg `sessionReportsRes` toe:

```js
const [finRes, allFinRes, settingsRes, goalsRes, sessionsRes, therapyRes, daysRes, weeksRes, sessionReportsRes] = results;
```

Voeg na regel 1118 (`(weeksRes.data || ...) `) toe:

```js
(sessionReportsRes.data || []).forEach(r => { _db.sessions_data[r.session_date] = r.data; });
```

- [ ] **Step 4: Maak de `_saveSessionReport()` functie**

Voeg toe na de `_saveSettings()` functie (na regel 1145):

```js
function _saveSessionReport(sessionDate) {
  sb.from('session_reports').upsert({
    user_id: currentUser.id,
    session_date: sessionDate,
    data: _db.sessions_data[sessionDate],
    updated_at: new Date().toISOString()
  }, { onConflict: 'user_id,session_date' }).then(r => { if(r.error) console.error('session_report save:', r.error); });
}
```

- [ ] **Step 5: Test**

Open de app in de browser. Open DevTools console. Verifieer:
- `_db.sessions_data` is een leeg object `{}`
- Geen errors in de console bij laden
- De rest van de app werkt normaal (check-in, weekreflectie, rapport)

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: sessions_data datamodel en Supabase tabel voor sessie-gebonden rapporten"
```

---

### Task 2: Sessie-levenscyclus — `getActieveSessie()` en `getTherapiePeriode()` herschrijven

**Files:**
- Modify: `index.html:1336-1352` (getTherapiePeriode)
- Nieuwe functie: `getActieveSessie()`

**Interfaces:**
- Consumes: `_db.sessions_data` (Task 1), `getTherapySessions()` (bestaand, regel 2145)
- Produces: `getActieveSessie()` → `{ date, time, location } | null`, herziene `getTherapiePeriode()` → `{ prev: Date, endDate: Date, next: Date|null }`

- [ ] **Step 1: Voeg `getActieveSessie()` toe**

Voeg toe direct boven `getTherapiePeriode()` (vóór regel 1336):

```js
function getActieveSessie() {
  const alleSessies = getTherapySessions();
  for (const s of alleSessies) {
    const sd = _db.sessions_data[s.date];
    if (!sd || sd.status !== 'afgesloten') return s;
  }
  return null;
}
```

- [ ] **Step 2: Herschrijf `getTherapiePeriode()`**

Vervang de bestaande `getTherapiePeriode()` (regels 1336-1352):

```js
function getTherapiePeriode() {
  const actief = getActieveSessie();
  if (!actief) {
    const start = getStartDate();
    const end = new Date(); end.setHours(23,59,59,999);
    return { prev: start, endDate: end, next: null };
  }
  const alleSessies = getTherapySessions();
  const idx = alleSessies.findIndex(s => s.date === actief.date);
  let prev;
  if (idx > 0) {
    prev = parseDate(alleSessies[idx - 1].date);
  } else {
    prev = getStartDate();
  }
  const next = parseDate(actief.date);
  const endDate = new Date(next.getTime() - 86400000);
  endDate.setHours(23,59,59,999);
  return { prev, endDate, next };
}
```

- [ ] **Step 3: Test**

Open de app. Verifieer:
- Het rapport-tab toont nog steeds "Rapport voor psycholoog" met de juiste periode
- De periode klopt: van de vorige sessiedatum tot één dag vóór de volgende
- Check in DevTools: `getActieveSessie()` retourneert de eerstvolgende sessie
- Check: `getTherapiePeriode()` retourneert logische datums

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: getActieveSessie() en herziene getTherapiePeriode() op basis van sessie-status"
```

---

### Task 3: Weekreflectie koppelen aan actieve sessie

**Files:**
- Modify: `index.html:612-632` (week-tab HTML)
- Modify: `index.html:2693-2712` (saveWeek, loadWeek)

**Interfaces:**
- Consumes: `getActieveSessie()` (Task 2), `_db.sessions_data` (Task 1), `_saveSessionReport()` (Task 1)
- Produces: herziene `saveWeek()` en `loadWeek()` die lezen/schrijven naar `_db.sessions_data[actieveSessie.date]`

- [ ] **Step 1: Voeg een sessie-label toe boven de reflectievragen**

In het week-tab HTML (regel 618), voeg een `<div>` toe vóór de "Reflectievragen deze week" tekst:

```html
<div id="weekSessieLabel" style="font-size:12px;color:var(--text-muted);margin-bottom:12px"></div>
```

De volledige `card-week` div wordt:

```html
<div class="card-week">
  <div id="weekSessieLabel" style="font-size:12px;color:var(--text-muted);margin-bottom:12px"></div>
  <div style="font-size:13px;font-weight:500;color:var(--gold);margin-bottom:18px;letter-spacing:.05em">Reflectievragen deze week</div>
```

- [ ] **Step 2: Herschrijf `saveWeek()`**

Vervang de bestaande `saveWeek()` functie (regels 2693-2704):

```js
function saveWeek() {
  const actief = getActieveSessie();
  if (!actief) { showToast('Geen actieve sessie'); return; }
  const sd = actief.date;
  if (!_db.sessions_data[sd]) _db.sessions_data[sd] = {};
  _db.sessions_data[sd].wq1 = document.getElementById('wq1').value;
  _db.sessions_data[sd].wq2 = document.getElementById('wq2').value;
  _db.sessions_data[sd].wq3 = document.getElementById('wq3').value;
  _db.sessions_data[sd].wq4 = document.getElementById('wq4').value;
  _db.sessions_data[sd].wq5 = document.getElementById('wq5').value;
  if (!_db.sessions_data[sd].status) _db.sessions_data[sd].status = 'actief';
  _saveSessionReport(sd);
  showToast('✓ Reflectie opgeslagen');
}
```

- [ ] **Step 3: Herschrijf `loadWeek()`**

Vervang de bestaande `loadWeek()` functie (regels 2707-2711):

```js
function loadWeek() {
  const actief = getActieveSessie();
  const label = document.getElementById('weekSessieLabel');
  if (!actief) {
    if (label) label.textContent = 'Geen actieve sessie — voeg een afspraak toe om reflecties in te vullen';
    ['wq1','wq2','wq3','wq4','wq5'].forEach(k => { const el = document.getElementById(k); if(el) { el.value=''; el.disabled=true; } });
    return;
  }
  if (label) label.textContent = 'Reflectie voor sessie van ' + sessionDateLabel(actief);
  const data = _db.sessions_data[actief.date] || {};
  ['wq1','wq2','wq3','wq4','wq5'].forEach(k => {
    const el = document.getElementById(k);
    if(el) { el.value = data[k] || ''; el.disabled = false; }
  });
}
```

- [ ] **Step 4: Test**

Open de app, ga naar het Week-tab:
- Verifieer dat het label "Reflectie voor sessie van [datum]" verschijnt
- Vul een reflectievraag in, klik "Week opslaan"
- Check in DevTools: `_db.sessions_data['2026-08-17']` bevat de wq1-wq5 velden
- Herlaad de pagina, check dat de data terugkomt

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: weekreflectie opslaan per actieve therapiesessie i.p.v. weeknummer"
```

---

### Task 4: Sessie-voorbereiding (prep) koppelen aan sessions_data

**Files:**
- Modify: `index.html:2177-2248` (buildSessiePrep, savePrep)

**Interfaces:**
- Consumes: `getActieveSessie()` (Task 2), `_db.sessions_data` (Task 1), `_saveSessionReport()` (Task 1)
- Produces: herziene `buildSessiePrep()` en `savePrep()` die lezen/schrijven naar `_db.sessions_data[sessie.date].prep`

- [ ] **Step 1: Wijzig `buildSessiePrep()` om prep uit sessions_data te lezen**

In `buildSessiePrep()`, vervang regel 2210:

```js
const saved = _db.preps[prepKey] || {};
```

door:

```js
const saved = (_db.sessions_data[next.date] && _db.sessions_data[next.date].prep) || _db.preps[prepKey] || {};
```

Dit leest eerst uit sessions_data, dan uit de oude preps als fallback.

- [ ] **Step 2: Wijzig `savePrep()` om naar sessions_data te schrijven**

Vervang de hele `savePrep()` functie (regels 2236-2248):

```js
function savePrep(dateStr) {
  const data = {
    thema:       document.getElementById('prepThema')?.value||'',
    doel:        document.getElementById('prepDoel')?.value||'',
    achtergrond: document.getElementById('prepAchtergrond')?.value||''
  };
  if (!_db.sessions_data[dateStr]) _db.sessions_data[dateStr] = {};
  _db.sessions_data[dateStr].prep = data;
  if (!_db.sessions_data[dateStr].status) _db.sessions_data[dateStr].status = 'actief';
  _saveSessionReport(dateStr);
  const msg = document.getElementById('prepSavedMsg');
  if (msg) { msg.classList.add('show'); setTimeout(()=>msg.classList.remove('show'), 2500); }
}
```

- [ ] **Step 3: Wijzig het rapport om prep uit sessions_data te lezen**

In `buildRapport()`, vervang de prep-sectie (regels 2610-2621). Verander:

```js
const nextSessiePrep = nextSession();
if (nextSessiePrep) {
  const prepK = 'prep_' + nextSessiePrep.date;
  const prep = _db.preps[prepK] || {};
```

naar:

```js
const nextSessiePrep = nextSession();
if (nextSessiePrep) {
  const prep = (_db.sessions_data[nextSessiePrep.date] && _db.sessions_data[nextSessiePrep.date].prep) || _db.preps['prep_' + nextSessiePrep.date] || {};
```

- [ ] **Step 4: Test**

- Ga naar Sessie-tab, vul voorbereiding in, klik "Voorbereiding opslaan"
- Check in DevTools: `_db.sessions_data['2026-08-17'].prep` bevat thema/doel/achtergrond
- Ga naar Rapport-tab: "Sessie voorbereiding" sectie toont de ingevoerde data
- Herlaad: data blijft behouden

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: sessie-voorbereiding opslaan in sessions_data i.p.v. preps"
```

---

### Task 5: Sessie afsluiten en rapport-snapshot

**Files:**
- Modify: `index.html` (nieuw: `sluitSessieAf()`, banner-HTML, banner-CSS)

**Interfaces:**
- Consumes: `getActieveSessie()` (Task 2), `buildRapport()` (bestaand), `_saveSessionReport()` (Task 1)
- Produces: `sluitSessieAf()` functie, `dismissCloseBanner()` functie, afsluiten-banner in HTML

- [ ] **Step 1: Voeg de banner-HTML toe**

Direct na de opening `<div class="scroll-area">` tag (rond regel 455), voeg toe:

```html
<div id="closeSessionBanner" style="display:none"></div>
```

- [ ] **Step 2: Voeg de banner-CSS toe**

Voeg toe bij de bestaande CSS (rond de `.card-alert` styles):

```css
.close-session-banner {
  background: #141000;
  border: 1px solid rgba(201,168,76,.3);
  border-radius: var(--radius-sm);
  padding: 16px 20px;
  margin: 0 16px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.close-session-banner span { font-size: 13px; color: var(--text); }
.close-session-banner button { font-size: 13px; padding: 8px 16px; border-radius: var(--radius-sm); border: none; cursor: pointer; font-family: inherit; }
.close-session-banner .btn-close { background: var(--gold); color: var(--black); font-weight: 600; }
.close-session-banner .btn-later { background: transparent; color: var(--text-muted); border: 1px solid var(--surface-3); }
```

- [ ] **Step 3: Implementeer `sluitSessieAf()`**

Voeg toe na de `_saveSessionReport()` functie:

```js
function sluitSessieAf() {
  const actief = getActieveSessie();
  if (!actief) return;
  const sd = actief.date;
  if (!_db.sessions_data[sd]) _db.sessions_data[sd] = {};

  // Genereer rapport-snapshot
  buildRapport('sessie');
  const snapshotHtml = document.getElementById('rapportBody').innerHTML;
  _db.sessions_data[sd].snapshot = snapshotHtml;
  _db.sessions_data[sd].snapshot_date = new Date().toISOString();
  _db.sessions_data[sd].status = 'afgesloten';

  _saveSessionReport(sd);
  document.getElementById('closeSessionBanner').style.display = 'none';
  showToast('✓ Sessie afgesloten en rapport gearchiveerd');

  // Herlaad week-tab en rapport met nieuwe actieve sessie
  loadWeek();
  buildRapport('sessie');
}

function dismissCloseBanner() {
  _db.settings.dismiss_close_banner = localDateStr();
  _saveSettings();
  document.getElementById('closeSessionBanner').style.display = 'none';
}
```

- [ ] **Step 4: Toon de banner in `init()`**

Zoek de `init()` functie (regel ~2070). Voeg aan het einde van `init()`, vlak voor de sluitende `}`, toe:

```js
// Check of actieve sessie in het verleden ligt
const actieveSessie = getActieveSessie();
if (actieveSessie && parseDate(actieveSessie.date) < new Date(new Date().setHours(0,0,0,0))) {
  if (_db.settings.dismiss_close_banner !== localDateStr()) {
    const banner = document.getElementById('closeSessionBanner');
    banner.style.display = 'block';
    banner.innerHTML = `<div class="close-session-banner">
      <span>Je sessie van ${sessionDateLabel(actieveSessie)} is geweest.</span>
      <div style="display:flex;gap:8px">
        <button class="btn-close" onclick="sluitSessieAf()">Rapport afsluiten</button>
        <button class="btn-later" onclick="dismissCloseBanner()">Later</button>
      </div>
    </div>`;
  }
}
```

- [ ] **Step 5: Test**

Om te testen zonder te wachten op een sessie:
- Verander tijdelijk de eerste THERAPY_SESSIONS datum naar een datum in het verleden (bijv. gisteren)
- Herlaad de app → banner verschijnt
- Klik "Rapport afsluiten" → toast verschijnt, banner verdwijnt
- Check in DevTools: `_db.sessions_data['...'].status === 'afgesloten'` en `snapshot` bevat HTML
- Test "Later" knop: banner verdwijnt, herlaad → banner verschijnt weer (tenzij zelfde dag)
- Zet THERAPY_SESSIONS terug naar origineel

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: sessie afsluiten met rapport-snapshot en automatische banner"
```

---

### Task 6: Rapport-archief weergave

**Files:**
- Modify: `index.html:709-726` (rapport-tab HTML)
- Modify: `index.html:2412-2638` (buildRapport)

**Interfaces:**
- Consumes: `_db.sessions_data` (Task 1), `getTherapySessions()` (bestaand), `sessionDateLabel()` (bestaand)
- Produces: `buildRapport('archief')` modus, `showArchiefSnapshot(sessionDate)` functie

- [ ] **Step 1: Voeg de derde knop toe in het rapport-tab**

Vervang de knoppen in het rapport-tab (regels 710-712):

```html
<div class="print-btn">
  <button class="save-btn" id="btnRapportSessie" onclick="buildRapport('sessie')">Huidig rapport</button>
  <button class="btn-outline" id="btnRapportArchief" onclick="buildRapport('archief')">Archief</button>
  <button class="btn-outline" id="btnRapportVolledig" onclick="buildRapport('volledig')">Volledig overzicht</button>
</div>
```

- [ ] **Step 2: Update de knop-highlighting in `buildRapport()`**

Vervang de knop-opacity code (regels 2416-2417):

```js
document.getElementById('btnRapportSessie').style.opacity   = mode==='sessie'   ? '1' : '0.5';
document.getElementById('btnRapportArchief').style.opacity   = mode==='archief'  ? '1' : '0.5';
document.getElementById('btnRapportVolledig').style.opacity = mode==='volledig' ? '1' : '0.5';
```

- [ ] **Step 3: Voeg archief-modus toe aan `buildRapport()`**

Direct na de knop-highlighting code, voeg een early return toe voor archief-modus:

```js
if (mode === 'archief') {
  buildRapportArchief();
  return;
}
```

- [ ] **Step 4: Implementeer `buildRapportArchief()`**

Voeg toe direct boven `buildRapport()`:

```js
function buildRapportArchief() {
  document.getElementById('rapportPeriodeLabel').textContent = 'Afgesloten sessie-rapporten';
  document.getElementById('rapportSubtitle').textContent = '';
  const entries = Object.entries(_db.sessions_data)
    .filter(([_, d]) => d.status === 'afgesloten')
    .sort((a, b) => b[0].localeCompare(a[0]));

  if (!entries.length) {
    document.getElementById('rapportBody').innerHTML =
      '<div style="text-align:center;padding:40px 20px;color:var(--text-muted);font-size:14px">Nog geen afgesloten sessies.</div>';
    return;
  }

  let html = '';
  entries.forEach(([dateStr, data]) => {
    const sessie = getTherapySessions().find(s => s.date === dateStr);
    const label = sessie ? sessionDateLabel(sessie) : dateStr;
    const loc = sessie ? sessie.location : '';
    const snapshotDate = data.snapshot_date
      ? new Date(data.snapshot_date).toLocaleDateString('nl-NL', { day:'numeric', month:'long', year:'numeric', hour:'2-digit', minute:'2-digit' })
      : '';
    html += `<div style="background:var(--surface);border:1px solid var(--surface-3);border-radius:var(--radius-sm);padding:16px 20px;margin-bottom:10px;cursor:pointer" onclick="showArchiefSnapshot('${esc(dateStr)}')">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-size:14px;color:var(--text);font-weight:500">${esc(label)}</div>
          ${loc ? `<div style="font-size:12px;color:var(--text-muted);margin-top:2px">${esc(loc)}</div>` : ''}
        </div>
        <div style="font-size:11px;color:var(--text-muted)">${data.snapshot ? 'Rapport beschikbaar' : 'Geen snapshot'}</div>
      </div>
      ${snapshotDate ? `<div style="font-size:11px;color:var(--text-dim);margin-top:6px">Afgesloten: ${snapshotDate}</div>` : ''}
    </div>`;
  });
  document.getElementById('rapportBody').innerHTML = html;
}

function showArchiefSnapshot(sessionDate) {
  const data = _db.sessions_data[sessionDate];
  if (!data || !data.snapshot) {
    document.getElementById('rapportBody').innerHTML =
      '<div style="text-align:center;padding:40px 20px;color:var(--text-muted);font-size:14px">Geen snapshot beschikbaar voor deze sessie.</div>';
    return;
  }
  const sessie = getTherapySessions().find(s => s.date === sessionDate);
  const label = sessie ? sessionDateLabel(sessie) : sessionDate;
  document.getElementById('rapportSubtitle').textContent = 'Gearchiveerd rapport: ' + label;
  document.getElementById('rapportPeriodeLabel').innerHTML =
    `<button class="btn-small" onclick="buildRapport('archief')" style="margin-right:8px">← Terug naar archief</button>`;
  document.getElementById('rapportBody').innerHTML = data.snapshot;
}
```

- [ ] **Step 5: Update de nav-knop default**

De nav-knop voor Rapport (regel 849) roept `buildRapport('sessie')` aan — dat blijft hetzelfde.

- [ ] **Step 6: Test**

- Sluit eerst een sessie af (Task 5) zodat er archief-data is
- Ga naar Rapport-tab → klik "Archief"
- Verifieer: lijst van afgesloten sessies verschijnt
- Klik op een sessie → snapshot HTML wordt getoond
- Klik "← Terug naar archief" → lijst verschijnt weer
- "Kopieer tekst" en "Afdrukken" werken op de getoonde snapshot

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: rapport-archief met snapshots van afgesloten sessies"
```

---

### Task 7: Migratie en opschoning

**Files:**
- Modify: `index.html` (migratiefunctie, opschoning afspraken-UI)

**Interfaces:**
- Consumes: `_db.weeks` (bestaand), `_db.preps` (bestaand), `_db.sessions_data` (Task 1), `getTherapySessions()` (bestaand), `_saveSessionReport()` (Task 1)
- Produces: `migrateSessieBound()` functie

- [ ] **Step 1: Implementeer de migratiefunctie**

Voeg toe na `loadAllData()`:

```js
function migrateSessieBound() {
  if (Object.keys(_db.sessions_data).length > 0) return;

  const alleSessies = getTherapySessions();
  const startDate = getStartDate();
  const today = new Date(); today.setHours(0,0,0,0);

  // 1. Weekreflecties migreren
  Object.entries(_db.weeks).forEach(([weekNr, weekData]) => {
    if (!weekData || !['wq1','wq2','wq3','wq4','wq5'].some(k => weekData[k])) return;
    const weekStartDag = (parseInt(weekNr) - 1) * 7;
    const weekStartDate = new Date(startDate.getTime() + weekStartDag * 86400000);

    let closest = alleSessies[0];
    let minDiff = Infinity;
    alleSessies.forEach(s => {
      const diff = Math.abs(parseDate(s.date).getTime() - weekStartDate.getTime());
      if (diff < minDiff) { minDiff = diff; closest = s; }
    });

    if (closest) {
      if (!_db.sessions_data[closest.date]) _db.sessions_data[closest.date] = {};
      ['wq1','wq2','wq3','wq4','wq5'].forEach(k => {
        if (weekData[k] && !_db.sessions_data[closest.date][k]) {
          _db.sessions_data[closest.date][k] = weekData[k];
        }
      });
      _db.sessions_data[closest.date].status = parseDate(closest.date) < today ? 'afgesloten' : 'actief';
    }
  });

  // 2. Sessie-voorbereiding migreren
  Object.entries(_db.preps).forEach(([key, prepData]) => {
    const sessieDate = key.replace('prep_', '');
    if (!sessieDate || !prepData) return;
    if (!_db.sessions_data[sessieDate]) _db.sessions_data[sessieDate] = {};
    if (!_db.sessions_data[sessieDate].prep) _db.sessions_data[sessieDate].prep = prepData;
    if (!_db.sessions_data[sessieDate].status) {
      _db.sessions_data[sessieDate].status = parseDate(sessieDate) < today ? 'afgesloten' : 'actief';
    }
  });

  // 3. Sync naar Supabase
  Object.keys(_db.sessions_data).forEach(sd => _saveSessionReport(sd));
}
```

- [ ] **Step 2: Roep de migratie aan na `loadAllData()`**

Zoek de plek waar `loadAllData()` wordt ge-awaited in de login/init flow. Voeg direct na de await toe:

```js
migrateSessieBound();
```

- [ ] **Step 3: Verwijder de vorige/volgende afspraak date-inputs**

In het archief-tab HTML (regels 740-751), vervang de twee date-input blokken en het appointmentStatus div door:

```html
<p style="font-size:13px;color:var(--text-muted);margin-bottom:16px;line-height:1.6">
  Sessieperiodes worden automatisch bepaald op basis van je geplande afspraken.
</p>
```

- [ ] **Step 4: Verwijder de `saveAppointments()`, `loadAppointments()`, en `updateAppointmentStatus()` functies**

Verwijder de functies op regels 2388-2408. Ze worden niet meer gebruikt.

Verwijder ook de aanroep `loadAppointments()` uit het nav-archief onclick (regel 853). Wijzig:

```html
<button class="nav-item" id="nav-archive" onclick="switchTab('archive',this);showStartDate();renderTherapySessions()">
```

(verwijder `loadAppointments();`)

- [ ] **Step 5: Update het weekreflectie-deel in `buildRapport()`**

De weekreflectie in het rapport (regels 2508-2527) leest nu uit `_db.weeks[getWeekKey()]`. Wijzig dit om uit sessions_data te lezen:

Vervang:

```js
const weekData = _db.weeks[getWeekKey()] || {};
```

door:

```js
const actief = getActieveSessie();
const weekData = actief ? (_db.sessions_data[actief.date] || {}) : {};
```

- [ ] **Step 6: Test**

- Wis `_db.sessions_data` in DevTools (`_db.sessions_data = {}`) en herlaad
- Verifieer: migratie draait, oude weekdata verschijnt onder een sessiedatum
- Verifieer: oude prep-data verschijnt onder de juiste sessiedatum
- Rapport-tab toont nog steeds de weekreflectie
- Archief-tab toont niet meer de date-inputs
- Alles blijft syncen naar Supabase

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: migratie van weeks/preps naar sessions_data en opschoning afspraken-UI"
```
