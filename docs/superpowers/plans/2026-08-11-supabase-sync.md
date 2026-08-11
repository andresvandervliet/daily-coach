# Supabase Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace localStorage with Supabase for cross-device sync, add magic link auth, and role-based access for behandelaar.

**Architecture:** Online-first single-page PWA. Supabase JS client inline in index.html. All existing data functions rewritten to async Supabase queries. Login screen gates app access. RLS enforces role-based data visibility.

**Tech Stack:** Supabase (Auth, Database, RLS), vanilla JS (async/await), existing HTML/CSS unchanged.

## Global Constraints

- Alles blijft in index.html (geen build tools, geen npm)
- Supabase JS library wordt inline opgenomen via een bundled copy (geen CDN, want CSP/SW)
- Supabase anon key is veilig publiek dankzij RLS
- Bestaande UI render-functies behouden hun naam
- Owner e-mail: andresvandervliet@gmail.com
- Geen offline-mode, geen conflict-handling

---

### Task 1: Supabase project opzetten en database schema aanmaken

**Files:**
- Create: `supabase-schema.sql` (SQL referentie, wordt handmatig uitgevoerd in Supabase dashboard)

**Interfaces:**
- Produces: Supabase project URL, anon key, en 8 tabellen met RLS policies

- [ ] **Step 1: Supabase project aanmaken**

Ga naar https://supabase.com/dashboard en maak een nieuw project:
- Name: `daily-coach`
- Region: `eu-west-1` (Frankfurt)
- Noteer de **Project URL** en **anon public key** uit Settings → API

- [ ] **Step 2: SQL schema schrijven**

Maak `supabase-schema.sql` met alle tabellen en RLS policies:

```sql
-- Tabellen aanmaken

create table daily_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  date date not null,
  data jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

create table weekly_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  week_number int not null,
  data jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, week_number)
);

create table therapy_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  data jsonb not null default '[]',
  updated_at timestamptz default now()
);

create table coach_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  date date not null,
  data jsonb not null default '{}',
  created_at timestamptz default now()
);

create table goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  active_goals jsonb not null default '[]',
  active_actions jsonb not null default '[]',
  updated_at timestamptz default now()
);

create table finance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  month_key text not null,
  vaste jsonb not null default '[]',
  knab jsonb not null default '[]',
  knab_tx jsonb not null default '[]',
  betaald jsonb not null default '{}',
  salaris numeric default 0,
  salaris_ontvangen boolean default false,
  salaris_datum date,
  history jsonb not null default '[]',
  updated_at timestamptz default now(),
  unique(user_id, month_key)
);

create table settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  profiel jsonb default '[]',
  start_date date,
  prev_appointment date,
  next_appointment date,
  updated_at timestamptz default now()
);

create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  owner_id uuid references auth.users(id) not null,
  role text not null check (role in ('owner', 'behandelaar')),
  created_at timestamptz default now(),
  unique(user_id, owner_id)
);

-- updated_at trigger
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_daily_entries_updated before update on daily_entries for each row execute function update_updated_at();
create trigger trg_weekly_entries_updated before update on weekly_entries for each row execute function update_updated_at();
create trigger trg_therapy_sessions_updated before update on therapy_sessions for each row execute function update_updated_at();
create trigger trg_goals_updated before update on goals for each row execute function update_updated_at();
create trigger trg_finance_updated before update on finance for each row execute function update_updated_at();
create trigger trg_settings_updated before update on settings for each row execute function update_updated_at();

-- RLS inschakelen
alter table daily_entries enable row level security;
alter table weekly_entries enable row level security;
alter table therapy_sessions enable row level security;
alter table coach_sessions enable row level security;
alter table goals enable row level security;
alter table finance enable row level security;
alter table settings enable row level security;
alter table user_roles enable row level security;

-- Owner policies: eigen data lezen/schrijven
create policy "owner_select" on daily_entries for select using (user_id = auth.uid());
create policy "owner_insert" on daily_entries for insert with check (user_id = auth.uid());
create policy "owner_update" on daily_entries for update using (user_id = auth.uid());
create policy "owner_delete" on daily_entries for delete using (user_id = auth.uid());

create policy "owner_select" on weekly_entries for select using (user_id = auth.uid());
create policy "owner_insert" on weekly_entries for insert with check (user_id = auth.uid());
create policy "owner_update" on weekly_entries for update using (user_id = auth.uid());
create policy "owner_delete" on weekly_entries for delete using (user_id = auth.uid());

create policy "owner_select" on therapy_sessions for select using (user_id = auth.uid());
create policy "owner_insert" on therapy_sessions for insert with check (user_id = auth.uid());
create policy "owner_update" on therapy_sessions for update using (user_id = auth.uid());
create policy "owner_delete" on therapy_sessions for delete using (user_id = auth.uid());

create policy "owner_select" on coach_sessions for select using (user_id = auth.uid());
create policy "owner_insert" on coach_sessions for insert with check (user_id = auth.uid());
create policy "owner_update" on coach_sessions for update using (user_id = auth.uid());
create policy "owner_delete" on coach_sessions for delete using (user_id = auth.uid());

create policy "owner_select" on goals for select using (user_id = auth.uid());
create policy "owner_insert" on goals for insert with check (user_id = auth.uid());
create policy "owner_update" on goals for update using (user_id = auth.uid());
create policy "owner_delete" on goals for delete using (user_id = auth.uid());

create policy "owner_select" on finance for select using (user_id = auth.uid());
create policy "owner_insert" on finance for insert with check (user_id = auth.uid());
create policy "owner_update" on finance for update using (user_id = auth.uid());
create policy "owner_delete" on finance for delete using (user_id = auth.uid());

create policy "owner_select" on settings for select using (user_id = auth.uid());
create policy "owner_insert" on settings for insert with check (user_id = auth.uid());
create policy "owner_update" on settings for update using (user_id = auth.uid());
create policy "owner_delete" on settings for delete using (user_id = auth.uid());

create policy "owner_select" on user_roles for select using (owner_id = auth.uid() or user_id = auth.uid());
create policy "owner_insert" on user_roles for insert with check (owner_id = auth.uid());
create policy "owner_delete" on user_roles for delete using (owner_id = auth.uid());

-- Behandelaar policies: alleen lezen op mentale tabellen
create policy "behandelaar_select" on daily_entries for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = daily_entries.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on weekly_entries for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = weekly_entries.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on therapy_sessions for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = therapy_sessions.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on coach_sessions for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = coach_sessions.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on goals for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = goals.user_id and user_roles.role = 'behandelaar')
);
```

- [ ] **Step 3: SQL uitvoeren in Supabase**

Open Supabase Dashboard → SQL Editor → plak de inhoud van `supabase-schema.sql` → Run.

- [ ] **Step 4: Auth configureren**

In Supabase Dashboard → Authentication → Settings:
- Site URL: `https://merry-kelpie-eec436.netlify.app`
- Redirect URLs: `https://merry-kelpie-eec436.netlify.app`
- Disable email confirmations (we use magic link, niet sign-up)

- [ ] **Step 5: Commit**

```bash
git add supabase-schema.sql
git commit -m "feat: Supabase database schema met RLS policies"
```

---

### Task 2: Supabase client + login-scherm toevoegen aan index.html

**Files:**
- Modify: `index.html` — voeg Supabase client library, login HTML, en auth logica toe

**Interfaces:**
- Consumes: Supabase project URL en anon key uit Task 1
- Produces: `window.supabase` client, `getCurrentUser()`, `getUserRole()`, `showLogin()`, `handleLogin()`, `handleLogout()`

- [ ] **Step 1: Supabase JS client downloaden en inline opnemen**

Download `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js` en sla de content op als inline `<script>` blok in index.html, vóór de bestaande `<script>`.

- [ ] **Step 2: Supabase client initialiseren**

Voeg toe direct na het inline Supabase script:

```javascript
const SUPABASE_URL = 'https://<project-id>.supabase.co';
const SUPABASE_KEY = '<anon-key>';
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

let currentUser = null;
let currentRole = 'owner';

async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

async function getUserRole(userId) {
  const { data } = await supabase.from('user_roles').select('role').eq('user_id', userId).maybeSingle();
  return data?.role || 'owner';
}
```

- [ ] **Step 3: Login-scherm HTML toevoegen**

Voeg toe vóór de bestaande `<div id="app">`:

```html
<div id="loginScreen" style="display:none;position:fixed;inset:0;background:var(--black);z-index:9999;display:flex;align-items:center;justify-content:center">
  <div style="text-align:center;max-width:320px;padding:20px">
    <h1 style="font-size:24px;font-weight:300;color:var(--text);margin-bottom:8px">Daily Coach</h1>
    <p style="color:var(--text-muted);font-size:13px;margin-bottom:32px">Log in met je e-mailadres</p>
    <input type="email" id="loginEmail" placeholder="E-mailadres" style="width:100%;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);padding:14px 16px;border-radius:var(--radius-sm);font-size:15px;outline:none;margin-bottom:12px;box-sizing:border-box;font-family:inherit">
    <button id="loginBtn" onclick="handleLogin()" style="width:100%;padding:14px;background:var(--gold);color:var(--black);border:none;border-radius:var(--radius-sm);font-size:15px;font-weight:600;cursor:pointer;font-family:inherit">Inloggen</button>
    <div id="loginMsg" style="margin-top:16px;font-size:13px;color:var(--text-muted)"></div>
  </div>
</div>
```

- [ ] **Step 4: Auth functies implementeren**

```javascript
async function handleLogin() {
  const email = document.getElementById('loginEmail').value.trim();
  if (!email) { document.getElementById('loginMsg').textContent = 'Vul je e-mail in'; return; }
  document.getElementById('loginBtn').disabled = true;
  document.getElementById('loginMsg').textContent = 'Link wordt verstuurd...';
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: window.location.origin + window.location.pathname }
  });
  if (error) {
    document.getElementById('loginMsg').textContent = 'Fout: ' + error.message;
    document.getElementById('loginBtn').disabled = false;
  } else {
    document.getElementById('loginMsg').innerHTML = 'Check je inbox voor de magic link!<br><span style="font-size:11px;color:var(--text-muted)">Ook in je spam</span>';
  }
}

async function handleLogout() {
  await supabase.auth.signOut();
  window.location.reload();
}

function showLogin() {
  document.getElementById('loginScreen').style.display = 'flex';
  document.getElementById('app').style.display = 'none';
}

function showApp() {
  document.getElementById('loginScreen').style.display = 'none';
  document.getElementById('app').style.display = '';
}
```

- [ ] **Step 5: Auth check bij app start**

Wijzig de bestaande `init()` functie: voeg aan het begin een auth check toe die `showLogin()` aanroept als er geen sessie is, of `showApp()` + doorgaat als er wel een sessie is.

```javascript
async function initAuth() {
  const user = await getCurrentUser();
  if (!user) { showLogin(); return; }
  currentUser = user;
  currentRole = await getUserRole(user.id);
  applyRoleFilter();
  showApp();
  init();
}

function applyRoleFilter() {
  if (currentRole === 'behandelaar') {
    document.querySelectorAll('[data-role="owner"]').forEach(el => el.style.display = 'none');
  }
}

// Verwijder directe init() aanroep onderaan, vervang door:
initAuth();

// Luister naar auth state changes (magic link redirect)
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN' && session) { window.location.reload(); }
});
```

- [ ] **Step 6: Financiën tab markeren als owner-only**

Voeg `data-role="owner"` toe aan de Financiën nav-item in de bottom bar.

- [ ] **Step 7: Uitloggen knop toevoegen**

Voeg een uitloggen knop toe onderaan de Financiën-tab (of in een zichtbare plek):

```html
<button onclick="handleLogout()" style="width:100%;margin-top:20px;padding:12px;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text-muted);border-radius:var(--radius-sm);font-size:13px;cursor:pointer;font-family:inherit">Uitloggen</button>
```

- [ ] **Step 8: Testen**

Open de app → login-scherm verschijnt → vul e-mail in → magic link ontvangen → klik → app verschijnt. Verifieer dat de auth flow werkt zonder de data-laag aan te raken (data komt nog steeds uit localStorage).

- [ ] **Step 9: Commit**

```bash
git add index.html
git commit -m "feat: Supabase auth met magic link login-scherm"
```

---

### Task 3: Data-laag herschrijven — mentale data (daily, weekly, sessions, goals)

**Files:**
- Modify: `index.html` — herschrijf data-functies voor daily_entries, weekly_entries, therapy_sessions, coach_sessions, goals

**Interfaces:**
- Consumes: `window.supabase`, `currentUser` uit Task 2
- Produces: async versies van `loadToday()`, `saveToday()`, `loadWeek()`, `saveWeek()`, `getSessions()`, `getActiveGoals()`, `getActiveActions()`, therapy session CRUD

- [ ] **Step 1: Daily entries herschrijven**

Vervang de localStorage-gebaseerde `loadToday()` en `saveToday()`:

```javascript
async function loadToday() {
  const { data } = await supabase
    .from('daily_entries')
    .select('data')
    .eq('user_id', currentUser.id)
    .eq('date', localDateStr())
    .maybeSingle();
  if (data) {
    const d = data.data;
    // Bestaande veld-vul logica blijft identiek, maar leest uit d in plaats van localStorage
    if (d.journal) document.getElementById('journalInput').value = d.journal;
    if (d.checkIn) document.getElementById('checkInInput').value = d.checkIn;
    // ... rest van bestaande loadToday velden
  }
}

async function saveToday() {
  const todayData = {
    journal: document.getElementById('journalInput')?.value || '',
    checkIn: document.getElementById('checkInInput')?.value || '',
    // ... rest van bestaande saveToday velden
    day: getDayNumber(),
    date: localDateStr()
  };
  await supabase.from('daily_entries').upsert({
    user_id: currentUser.id,
    date: localDateStr(),
    data: todayData
  }, { onConflict: 'user_id,date' });
}
```

- [ ] **Step 2: Weekly entries herschrijven**

Vervang `loadWeek()` en `saveWeek()` op dezelfde manier:

```javascript
async function loadWeek() {
  const weekNum = Math.floor((getDayNumber() - 1) / 7 + 1);
  const { data } = await supabase
    .from('weekly_entries')
    .select('data')
    .eq('user_id', currentUser.id)
    .eq('week_number', weekNum)
    .maybeSingle();
  if (data) {
    const d = data.data;
    // Bestaande veld-vul logica
  }
}

async function saveWeek() {
  const weekNum = Math.floor((getDayNumber() - 1) / 7 + 1);
  const weekData = { /* bestaande velden */ };
  await supabase.from('weekly_entries').upsert({
    user_id: currentUser.id,
    week_number: weekNum,
    data: weekData
  }, { onConflict: 'user_id,week_number' });
}
```

- [ ] **Step 3: Sessions en goals herschrijven**

```javascript
async function getSessions() {
  const { data } = await supabase
    .from('coach_sessions')
    .select('data, date')
    .eq('user_id', currentUser.id)
    .order('date', { ascending: false });
  return (data || []).map(r => r.data);
}

async function getActiveGoals() {
  const { data } = await supabase
    .from('goals')
    .select('active_goals')
    .eq('user_id', currentUser.id)
    .maybeSingle();
  return data?.active_goals || [];
}

async function getActiveActions() {
  const { data } = await supabase
    .from('goals')
    .select('active_actions')
    .eq('user_id', currentUser.id)
    .maybeSingle();
  return data?.active_actions || [];
}
```

- [ ] **Step 4: Therapy sessions herschrijven**

```javascript
async function loadTherapySessions() {
  const { data } = await supabase
    .from('therapy_sessions')
    .select('data')
    .eq('user_id', currentUser.id)
    .maybeSingle();
  THERAPY_SESSIONS = data?.data || [];
}

async function saveTherapySessions() {
  await supabase.from('therapy_sessions').upsert({
    user_id: currentUser.id,
    data: THERAPY_SESSIONS
  }, { onConflict: 'user_id' });
}
```

- [ ] **Step 5: Alle render-functies die deze data gebruiken async maken**

Alle `build*` en `load*` functies die de bovenstaande data-functies aanroepen moeten `async` worden en `await` gebruiken. Specifiek: `loadToday`, `saveToday`, `loadWeek`, `saveWeek`, `loadSessieList`, `saveSessie`, `loadArchive`, `buildRapport`, `renderTherapySessions`, `loadActiveGoals`, `loadTherapyQuestions`.

- [ ] **Step 6: Testen**

Log in → check dat dagelijkse check-in opslaat en terugleest → check week → check sessie opslaan → check archief.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: mentale data via Supabase (daily, weekly, sessions, goals)"
```

---

### Task 4: Data-laag herschrijven — financiële data en settings

**Files:**
- Modify: `index.html` — herschrijf financiële data-functies en settings

**Interfaces:**
- Consumes: `window.supabase`, `currentUser` uit Task 2
- Produces: async versies van alle `getFinVaste()`, `saveFinVaste()`, `getFinKnab()`, `saveFinKnab()`, `getFinBetaald()`, `saveFinBetaald()`, `getFinSalaris()`, `saveFinSalaris()`, en settings functies

- [ ] **Step 1: Finance data-functies herschrijven**

Alle financiële data wordt per maand opgeslagen in één rij in de `finance` tabel:

```javascript
async function getFinanceMonth(mk) {
  mk = mk || finMaandKey();
  const { data } = await supabase
    .from('finance')
    .select('*')
    .eq('user_id', currentUser.id)
    .eq('month_key', mk)
    .maybeSingle();
  return data || { vaste: FIN_DEFAULT_VASTE, knab: FIN_DEFAULT_KNAB, knab_tx: [], betaald: {}, salaris: 3700, salaris_ontvangen: false, salaris_datum: null, history: [] };
}

async function saveFinanceMonth(fields, mk) {
  mk = mk || finMaandKey();
  await supabase.from('finance').upsert({
    user_id: currentUser.id,
    month_key: mk,
    ...fields
  }, { onConflict: 'user_id,month_key' });
}
```

Vervolgens worden de individuele get/save functies wrappers:

```javascript
async function getFinVaste() { return (await getFinanceMonth()).vaste; }
async function saveFinVaste(l) { await saveFinanceMonth({ vaste: l }); }
async function getFinKnab() { return (await getFinanceMonth()).knab; }
async function saveFinKnab(l) { await saveFinanceMonth({ knab: l }); }
async function getKnabTx(mk) { return (await getFinanceMonth(mk)).knab_tx; }
async function saveKnabTx(list, mk) { await saveFinanceMonth({ knab_tx: list }, mk); }
async function getFinBetaald() { return (await getFinanceMonth()).betaald; }
async function saveFinBetaald(obj) { await saveFinanceMonth({ betaald: obj }); }
async function getFinSalaris() { return (await getFinanceMonth()).salaris || 3700; }
async function saveFinSalaris(n) { await saveFinanceMonth({ salaris: n }); }
async function getFinSalarisOntvangen() { return (await getFinanceMonth()).salaris_ontvangen; }
async function setFinSalarisOntvangen() { await saveFinanceMonth({ salaris_ontvangen: true, salaris_datum: localDateStr() }); }
async function getFinSalarisDatum() { return (await getFinanceMonth()).salaris_datum; }
```

- [ ] **Step 2: Settings functies herschrijven**

```javascript
async function getSettings() {
  const { data } = await supabase
    .from('settings')
    .select('*')
    .eq('user_id', currentUser.id)
    .maybeSingle();
  return data || { profiel: [], start_date: null, prev_appointment: null, next_appointment: null };
}

async function saveSettings(fields) {
  await supabase.from('settings').upsert({
    user_id: currentUser.id,
    ...fields
  }, { onConflict: 'user_id' });
}

async function getStartDate() {
  const s = await getSettings();
  return s.start_date || localDateStr();
}
```

- [ ] **Step 3: Alle financiële render-functies async maken**

`buildFinDashboard`, `buildFinVaste`, `buildFinKnab`, `buildFinTimeline`, `buildFinSpaarBadge`, `buildFinHistorie`, `buildFinPaydayBanner`, `buildFinRokenBadge`, `finAutoMarkeer`, en alle calc-functies die data ophalen.

- [ ] **Step 4: Performance: cache per render-cyclus**

Om te voorkomen dat `getFinanceMonth()` 10+ keer per render wordt aangeroepen:

```javascript
let _finCache = null;
let _finCacheKey = null;

async function getFinanceMonth(mk) {
  mk = mk || finMaandKey();
  if (_finCacheKey === mk && _finCache) return _finCache;
  const { data } = await supabase.from('finance').select('*').eq('user_id', currentUser.id).eq('month_key', mk).maybeSingle();
  _finCache = data || { vaste: FIN_DEFAULT_VASTE, knab: FIN_DEFAULT_KNAB, knab_tx: [], betaald: {}, salaris: 3700, salaris_ontvangen: false, salaris_datum: null, history: [] };
  _finCacheKey = mk;
  return _finCache;
}

function invalidateFinCache() { _finCache = null; _finCacheKey = null; }
```

Elke save-functie roept `invalidateFinCache()` aan na het schrijven.

- [ ] **Step 5: Testen**

Log in → Financiën tab → wijzig salaris → verifieer dat het opslaat → check Knab transactie → check vaste lasten afvinken.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: financiële data en settings via Supabase"
```

---

### Task 5: Migratie localStorage → Supabase

**Files:**
- Modify: `index.html` — migratie-functie en UI

**Interfaces:**
- Consumes: `window.supabase`, `currentUser`, alle Supabase data-functies uit Task 3 en 4
- Produces: `migrateToSupabase()` functie, migratie-banner UI

- [ ] **Step 1: Migratie-functie schrijven**

```javascript
async function migrateToSupabase() {
  if (localStorage.getItem('lc_migrated')) return false;
  const hasLocalData = Object.keys(localStorage).some(k => k.startsWith('lc_') && k !== 'lc_migrated');
  if (!hasLocalData) return false;

  // Daily entries
  const dayKeys = Object.keys(localStorage).filter(k => k.startsWith('lc_day_'));
  for (const key of dayKeys) {
    const date = key.replace('lc_day_', '');
    const data = JSON.parse(localStorage.getItem(key));
    await supabase.from('daily_entries').upsert({
      user_id: currentUser.id, date, data
    }, { onConflict: 'user_id,date' });
  }

  // Weekly entries
  const weekKeys = Object.keys(localStorage).filter(k => k.startsWith('lc_week_'));
  for (const key of weekKeys) {
    const weekNum = parseInt(key.replace('lc_week_', ''));
    const data = JSON.parse(localStorage.getItem(key));
    await supabase.from('weekly_entries').upsert({
      user_id: currentUser.id, week_number: weekNum, data
    }, { onConflict: 'user_id,week_number' });
  }

  // Therapy sessions
  const therapy = localStorage.getItem('lc_therapy_sessions');
  if (therapy) {
    await supabase.from('therapy_sessions').upsert({
      user_id: currentUser.id, data: JSON.parse(therapy)
    }, { onConflict: 'user_id' });
  }

  // Coach sessions
  const sessions = localStorage.getItem('lc_sessions');
  if (sessions) {
    const arr = JSON.parse(sessions);
    for (const s of arr) {
      await supabase.from('coach_sessions').insert({
        user_id: currentUser.id, date: s.date || localDateStr(), data: s
      });
    }
  }

  // Goals
  const goals = localStorage.getItem('lc_active_goals');
  const actions = localStorage.getItem('lc_active_actions');
  if (goals || actions) {
    await supabase.from('goals').upsert({
      user_id: currentUser.id,
      active_goals: goals ? JSON.parse(goals) : [],
      active_actions: actions ? JSON.parse(actions) : []
    }, { onConflict: 'user_id' });
  }

  // Finance — per maand
  const finKeys = Object.keys(localStorage).filter(k => k.startsWith('lc_fin_'));
  const months = new Set();
  finKeys.forEach(k => {
    const m = k.match(/lc_fin_(?:betaald|sal|sal_ontvangen|sal_datum|knab_tx)_(\d{4}-\d{2})/);
    if (m) months.add(m[1]);
  });
  if (months.size === 0) months.add(finMaandKey());
  for (const mk of months) {
    const vaste = localStorage.getItem('lc_fin_vaste');
    const knab = localStorage.getItem('lc_fin_knab');
    const knabTx = localStorage.getItem('lc_fin_knab_tx_' + mk);
    const betaald = localStorage.getItem('lc_fin_betaald_' + mk);
    const sal = localStorage.getItem('lc_fin_sal_' + mk);
    const salOnt = localStorage.getItem('lc_fin_sal_ontvangen_' + mk);
    const salDat = localStorage.getItem('lc_fin_sal_datum_' + mk);
    await supabase.from('finance').upsert({
      user_id: currentUser.id,
      month_key: mk,
      vaste: vaste ? JSON.parse(vaste) : FIN_DEFAULT_VASTE,
      knab: knab ? JSON.parse(knab) : FIN_DEFAULT_KNAB,
      knab_tx: knabTx ? JSON.parse(knabTx) : [],
      betaald: betaald ? JSON.parse(betaald) : {},
      salaris: sal ? parseFloat(sal) : 3700,
      salaris_ontvangen: salOnt === '1',
      salaris_datum: salDat || null,
      history: []
    }, { onConflict: 'user_id,month_key' });
  }

  // Settings
  const profiel = localStorage.getItem('lc_profiel');
  const start = localStorage.getItem('lc_start');
  const prevApp = localStorage.getItem('lc_prev_appointment');
  const nextApp = localStorage.getItem('lc_next_appointment');
  await supabase.from('settings').upsert({
    user_id: currentUser.id,
    profiel: profiel ? JSON.parse(profiel) : [],
    start_date: start || localDateStr(),
    prev_appointment: prevApp || null,
    next_appointment: nextApp || null
  }, { onConflict: 'user_id' });

  // User role: owner
  await supabase.from('user_roles').upsert({
    user_id: currentUser.id,
    owner_id: currentUser.id,
    role: 'owner'
  }, { onConflict: 'user_id,owner_id' });

  // Markeer als gemigreerd, verwijder oude data
  localStorage.setItem('lc_migrated', 'true');
  Object.keys(localStorage).filter(k => k.startsWith('lc_') && k !== 'lc_migrated').forEach(k => localStorage.removeItem(k));

  return true;
}
```

- [ ] **Step 2: Migratie-banner UI**

Voeg toe aan `initAuth()` na succesvolle login:

```javascript
async function initAuth() {
  const user = await getCurrentUser();
  if (!user) { showLogin(); return; }
  currentUser = user;

  // Check migratie
  const migrated = await migrateToSupabase();
  if (migrated) { showToast('Data overgezet naar cloud'); }

  currentRole = await getUserRole(user.id);
  applyRoleFilter();
  showApp();
  init();
}
```

- [ ] **Step 3: Testen**

Test met bestaande localStorage data: login → migratie draait automatisch → verifieer dat alle data zichtbaar is in de app → verifieer dat localStorage is opgeruimd (behalve `lc_migrated`).

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: eenmalige localStorage → Supabase migratie"
```

---

### Task 6: Opruimen, testen, deployen

**Files:**
- Modify: `index.html` — verwijder dode localStorage code, oude migraties
- Modify: `sw.js` — cache invalideren voor nieuwe versie

**Interfaces:**
- Consumes: alles uit Tasks 1-5

- [ ] **Step 1: Dode code verwijderen**

Verwijder:
- `_finParse()` functie (niet meer nodig)
- `migrateKnabV2()` en `migrateProfiel()` (eenmalige migraties, nu in Supabase)
- `safeSave()` functie (localStorage wrapper, niet meer nodig)
- Alle directe `localStorage.setItem`/`getItem` aanroepen die zijn vervangen

- [ ] **Step 2: Import/export updaten**

Update `exportData()` en `importData()` om Supabase te gebruiken in plaats van localStorage.

- [ ] **Step 3: Service worker cache-bust**

Update de cache-naam in `sw.js` zodat de oude versie wordt vervangen:

```javascript
const CACHE_NAME = 'daily-coach-v3';
```

- [ ] **Step 4: End-to-end test**

1. Open op desktop → login → alle tabs werken
2. Open op mobiel (iPhone) → login met zelfde e-mail → zelfde data zichtbaar
3. Wijzig iets op iPhone → refresh desktop → wijziging zichtbaar
4. Verifieer dat Financiën werkt: salaris, vaste lasten, Knab transacties
5. Verifieer dat Rapport genereert met correcte data

- [ ] **Step 5: Deploy**

```bash
git add index.html sw.js
git commit -m "feat: opruimen localStorage code, SW cache-bust"
git push origin master
```

- [ ] **Step 6: Verifieer op Netlify**

Open `https://merry-kelpie-eec436.netlify.app` → login → verifieer dat alles werkt.
