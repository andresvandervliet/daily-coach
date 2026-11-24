# Inloggen met wachtwoord + Face ID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inloggen met e-mail + wachtwoord (Face ID/sleutelhanger-autofill) als hoofdroute, magic link als reserve, en een eenmalige kaart om een wachtwoord in te stellen.

**Architecture:** Alles in `index.html` (vanilla JS, geen build). Pure hulpfuncties staan tussen de markers `// ── LOGIN-HULP-START` en `// ── LOGIN-HULP-EIND` zodat `verify-login.cjs` ze via `vm` kan testen, zoals de bestaande `verify-*.cjs`. Supabase Auth: `signInWithPassword`, `signInWithOtp`, `updateUser`.

**Tech Stack:** Static PWA, Supabase JS v2, Node `vm` + `assert` voor verificatie.

**Spec:** `docs/superpowers/specs/2026-11-24-inloggen-wachtwoord-design.md`

## Global Constraints

- Alle tekst in het Nederlands.
- Wachtwoord minimaal 8 tekens.
- Opslag alleen `settings.profiel.wachtwoordIngesteld` (JSONB); het wachtwoord zelf nergens opslaan.
- Kaart niet tonen voor rol `behandelaar`.
- Invoervelden 16px (geen iOS-zoom), knoppen min. 44px hoog.
- Bestaande `verify-*.cjs` moeten blijven slagen.

---

### Task 1: Loginscherm met wachtwoord, codestap eruit

**Files:**
- Modify: `index.html` — login-markup (`#loginScreen`), login-CSS (`.login-code*`-regels), AUTH-JS (`handleLogin`, codestap-functies, `showLogin`)
- Create: `verify-login.cjs`

**Interfaces:**
- Produces: `loginFoutTekst(error, soort)` → string (`soort`: `'wachtwoord' | 'link'`); `handlePasswordLogin()`; `handleLogin()` (magic link, ongewijzigde naam).

- [ ] **Step 1: Test schrijven** — `verify-login.cjs`:

```js
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync('index.html', 'utf8');
const a = html.indexOf('// ── LOGIN-HULP-START'), b = html.indexOf('// ── LOGIN-HULP-EIND');
assert(a > 0 && b > a, 'LOGIN-HULP-markers ontbreken');
const c = vm.createContext({});
vm.runInContext(html.slice(a, b), c);
const t = (e, s) => vm.runInContext(`loginFoutTekst(${JSON.stringify(e)}, '${s}')`, c);
assert.equal(t({ status: 400, message: 'Invalid login credentials' }, 'wachtwoord'), 'E-mail of wachtwoord klopt niet.');
assert.match(t({ status: 429, message: 'rate limit' }, 'wachtwoord'), /Te veel pogingen/);
assert.match(t({ status: 429, message: 'Email rate limit exceeded' }, 'link'), /te veel inloglinks/i);
assert.match(t({ status: 500, message: 'x' }, 'link'), /kon niet worden verstuurd/);
assert.match(html, /autocomplete="current-password"/);
assert.match(html, /autocomplete="username"/);
assert.doesNotMatch(html, /loginCodeStap|dc_login_code/, 'codestap moet weg zijn');
for (const [, src] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) if (src.trim()) new vm.Script(src);
console.log('PASS: login-foutteksten, wachtwoordvelden, codestap verwijderd. Geen netwerk.');
```

- [ ] **Step 2:** `node verify-login.cjs` → FAIL ("LOGIN-HULP-markers ontbreken").

- [ ] **Step 3: Markup** — vervang alles binnen `<form id="loginForm" …>` door:

```html
<form id="loginForm" novalidate onsubmit="event.preventDefault(); handlePasswordLogin()" style="(bestaande style ongewijzigd)">
  <h1 style="font-size:24px;font-weight:300;color:var(--text);margin-bottom:8px">Daily Coach</h1>
  <p id="loginSub" style="color:var(--text-muted);font-size:13px;margin-bottom:32px">Log in om verder te gaan</p>
  (bestaand #loginNotice-blok ongewijzigd)
  <input type="email" id="loginEmail" class="plain-input login-veld" placeholder="E-mailadres" aria-label="E-mailadres" autocomplete="username" inputmode="email" autocapitalize="off" spellcheck="false" required>
  <input type="password" id="loginPassword" class="plain-input login-veld" placeholder="Wachtwoord" aria-label="Wachtwoord" autocomplete="current-password" enterkeyhint="go">
  <button type="submit" id="loginBtn" style="(bestaande style)">Inloggen</button>
  <button type="button" id="loginLinkBtn" class="login-link" onclick="handleLogin()">Inloggen met e-maillink</button>
  <div id="loginMsg" aria-live="polite" style="(bestaande style)"></div>
</form>
```

- [ ] **Step 4: CSS** — verwijder alle `.login-code*`, `#loginCodeStap`-regels en `@keyframes loginCodeSchud`; voeg toe:

```css
.login-veld { width: 100%; box-sizing: border-box; background: var(--surface-2); border: 1px solid var(--surface-3); color: var(--text); padding: 14px 16px; border-radius: var(--radius-sm); font-size: 16px; outline: none; margin-bottom: 10px; font-family: inherit; transition: border-color 150ms var(--ease-out); }
.login-veld:focus { border-color: var(--gold); }
#loginBtn { margin-top: 2px; }
.login-link { display: inline-block; margin-top: 10px; background: none; border: none; padding: 10px 4px; min-height: 44px; color: var(--gold-light); font: inherit; font-size: 13px; cursor: pointer; }
.login-link:disabled { color: var(--text-muted); cursor: default; }
.login-link:focus-visible { outline: 2px solid var(--gold-light); outline-offset: 3px; }
```

- [ ] **Step 5: JS** — vlak na `// ─── AUTH ───` de hulpfunctie tussen markers:

```js
// ── LOGIN-HULP-START (getest door verify-login.cjs; puur, geen DOM)
function loginFoutTekst(error, soort) {
  const tekst = String((error && error.message) || '') + ' ' + String((error && error.code) || '');
  if (error && (error.status === 429 || /rate limit|too many/i.test(tekst))) {
    return soort === 'link'
      ? 'Er zijn te veel inloglinks aangevraagd. Log in met je wachtwoord, of wacht even en gebruik de laatst ontvangen mail.'
      : 'Te veel pogingen. Wacht even en probeer het opnieuw.';
  }
  if (soort === 'wachtwoord' && /invalid login credentials|invalid_credentials/i.test(tekst)) return 'E-mail of wachtwoord klopt niet.';
  if (soort === 'wachtwoord' && /email not confirmed/i.test(tekst)) return 'Je e-mailadres is nog niet bevestigd. Log in met de e-maillink.';
  return soort === 'link'
    ? 'De inloglink kon niet worden verstuurd. Controleer je verbinding en probeer later opnieuw.'
    : 'Inloggen lukte niet. Controleer je verbinding en probeer opnieuw.';
}
// ── LOGIN-HULP-EIND
```

Daarna `handlePasswordLogin` en de vereenvoudigde `handleLogin`:

```js
async function handlePasswordLogin() {
  const emailEl = document.getElementById('loginEmail');
  const pwEl = document.getElementById('loginPassword');
  const btn = document.getElementById('loginBtn');
  const email = emailEl.value.trim(), password = pwEl.value;
  if (!email || !emailEl.checkValidity()) { setLoginMsg('Vul een geldig e-mailadres in'); emailEl.focus(); return; }
  if (!password) { setLoginMsg('Vul je wachtwoord in, of log in met de e-maillink.'); pwEl.focus(); return; }
  if (btn.disabled) return;
  btn.disabled = true; btn.textContent = 'Inloggen…';
  document.getElementById('loginMsg').textContent = '';
  try { localStorage.setItem('dc_login_email', email); } catch {}
  try {
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) {
      setLoginMsg(loginFoutTekst(error, 'wachtwoord'));
      pwEl.select();
      btn.disabled = false; btn.textContent = 'Inloggen';
      return;
    }
    btn.textContent = 'Ingelogd';
    window.location.reload();
  } catch {
    setLoginMsg('Geen verbinding. Controleer je internet en probeer opnieuw.');
    btn.disabled = false; btn.textContent = 'Inloggen';
  }
}

async function handleLogin() {
  const emailEl = document.getElementById('loginEmail');
  const btn = document.getElementById('loginLinkBtn');
  const email = emailEl.value.trim();
  if (!email || !emailEl.checkValidity()) { setLoginMsg('Vul eerst je e-mailadres in.'); emailEl.focus(); return; }
  if (btn.disabled) return;
  btn.disabled = true; btn.textContent = 'Link versturen…';
  try { localStorage.setItem('dc_login_email', email); } catch {}
  try {
    const { error } = await sb.auth.signInWithOtp({ email, options: { emailRedirectTo: window.location.origin + window.location.pathname } });
    if (error) { setLoginMsg(loginFoutTekst(error, 'link')); btn.disabled = false; btn.textContent = 'Inloggen met e-maillink'; return; }
    document.getElementById('loginNotice').hidden = true;
    btn.textContent = 'Link verstuurd';
    setLoginMsg('', 'Check je inbox voor de inloglink.<br><span style="font-size:11px;color:var(--text-muted)">Open alleen de nieuwste mail · kijk ook in je spam</span>');
  } catch {
    setLoginMsg('Geen verbinding. Controleer je internet en probeer opnieuw.');
    btn.disabled = false; btn.textContent = 'Inloggen met e-maillink';
  }
}
```

Verwijder: `LOGIN_CODE_GELDIG_MS`, `loginCodeBezig`, `opnieuwTimer`, `bewaardeCodeStap`, `toonCodeStap`, `startOpnieuwAftellen`, `loginCodeInvoer`, `verifieerLoginCode`, `stuurCodeOpnieuw`, `loginAnderAdres`.

In `showLogin`: vervang de `bewaard`-regels door `try { localStorage.removeItem('dc_login_code'); } catch {}`; zet de verlopen-link-tekst op "… Log hieronder in met je wachtwoord, of vraag een nieuwe link aan."; verwijder `loginBtn.textContent = 'Stuur nieuwe link'`; focus wachtwoordveld als e-mail gevuld is, anders e-mail.

- [ ] **Step 6:** `node verify-login.cjs` en alle `verify-*.cjs` → PASS.
- [ ] **Step 7: Commit** `feat: inloggen met wachtwoord, e-maillink als reserve`.

---

### Task 2: Wachtwoord-instelkaart + "Wachtwoord wijzigen" in Beheer

**Files:**
- Modify: `index.html` — container na `<div class="scroll-area">`, CSS, AUTH-JS, `initAuth`, knop in `#tab-fin`
- Modify: `verify-login.cjs`

**Interfaces:**
- Consumes: `currentUser`, `currentRole`, `_db.settings.profiel`, `_saveSettings()`, `showToast()`, `esc()`.
- Produces: `moetWachtwoordKaartTonen(profiel, rol)` → boolean; `wachtwoordProbleem(pw)` → string|null; `buildWachtwoordKaart(open)`; `slaWachtwoordOp()`; `sluitWachtwoordKaart()`; `openWachtwoordWijzigen()`.

- [ ] **Step 1: Test uitbreiden** (vóór de `console.log` in `verify-login.cjs`):

```js
const toon = (p, r) => vm.runInContext(`moetWachtwoordKaartTonen(${JSON.stringify(p)}, '${r}')`, c);
assert.equal(toon({}, 'owner'), true);
assert.equal(toon([], 'owner'), true);
assert.equal(toon({ wachtwoordIngesteld: true }, 'owner'), false);
assert.equal(toon({}, 'behandelaar'), false);
const pr = pw => vm.runInContext(`wachtwoordProbleem(${JSON.stringify(pw)})`, c);
assert.equal(pr('kort'), 'Kies minimaal 8 tekens.');
assert.equal(pr(''), 'Kies minimaal 8 tekens.');
assert.equal(pr('lang-genoeg-1'), null);
assert.match(html, /autocomplete="new-password"/);
```

- [ ] **Step 2:** `node verify-login.cjs` → FAIL (`moetWachtwoordKaartTonen is not defined`).

- [ ] **Step 3: Hulpfuncties** binnen de LOGIN-HULP-markers:

```js
function moetWachtwoordKaartTonen(profiel, rol) {
  return rol !== 'behandelaar' && !(profiel && profiel.wachtwoordIngesteld === true);
}
function wachtwoordProbleem(pw) {
  return !pw || String(pw).length < 8 ? 'Kies minimaal 8 tekens.' : null;
}
```

- [ ] **Step 4: Markup** — direct na `<div class="scroll-area">`: `<div id="wachtwoordKaart" hidden></div>`. In `#tab-fin`, vóór de Uitloggen-knop:

```html
<button onclick="openWachtwoordWijzigen()" style="width:100%;margin-top:12px;padding:12px;background:var(--surface-2);border:1px solid var(--surface-3);color:var(--text);border-radius:var(--radius-sm);font-size:13px;cursor:pointer;font-family:inherit">Wachtwoord wijzigen</button>
```

- [ ] **Step 5: CSS**:

```css
#wachtwoordKaart:not([hidden]) { animation: loginNoticeIn 240ms var(--ease-out) both; }
.ww-kaart { margin: 12px 0 4px; padding: 16px; border-radius: 18px; border: 1px solid rgba(212,184,120,.4); background: rgba(212,184,120,.07); }
.ww-kop { display: flex; justify-content: space-between; align-items: center; gap: 12px; font-size: 16px; color: var(--text); }
.ww-sluit { background: none; border: none; color: var(--text-muted); font-size: 22px; line-height: 1; min-width: 44px; min-height: 44px; cursor: pointer; margin: -10px -10px -10px 0; }
.ww-uitleg { font-size: 13px; line-height: 1.5; color: var(--text-muted); margin: 4px 0 12px; }
.ww-veld { width: 100%; box-sizing: border-box; background: var(--surface-2); border: 1px solid var(--surface-3); color: var(--text); padding: 13px 14px; border-radius: var(--radius-sm); font-size: 16px; outline: none; font-family: inherit; margin-bottom: 10px; }
.ww-veld:focus { border-color: var(--gold); }
.ww-knop { width: 100%; min-height: 48px; border: none; border-radius: var(--radius-sm); background: var(--gold); color: var(--black); font: inherit; font-size: 15px; font-weight: 600; cursor: pointer; transition: transform 160ms var(--ease-out), opacity 150ms ease; }
.ww-knop:active:not(:disabled) { transform: scale(.97); }
.ww-knop:disabled { opacity: .55; cursor: default; }
.ww-msg { margin-top: 8px; font-size: 13px; color: #eb9a95; min-height: 1px; }
.ww-verborgen { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; }
@media (prefers-reduced-motion: reduce) { #wachtwoordKaart:not([hidden]) { animation: loginNoticeFade 200ms ease both; } .ww-knop { transition: none; } }
```

Let op: `--ease-out` staat op `#loginForm`; definieer hem ook op `:root`-niveau voor de kaart: `#wachtwoordKaart { --ease-out: cubic-bezier(0.23, 1, 0.32, 1); }`.

- [ ] **Step 6: JS** (na `handleLogin`):

```js
function buildWachtwoordKaart(open) {
  const el = document.getElementById('wachtwoordKaart'); if (!el) return;
  const prof = (_db.settings && _db.settings.profiel) || {};
  let later = false; try { later = sessionStorage.getItem('dc_ww_later') === '1'; } catch {}
  if (!open && (later || !moetWachtwoordKaartTonen(prof, currentRole))) { el.hidden = true; el.innerHTML = ''; return; }
  const wijzigen = prof.wachtwoordIngesteld === true;
  el.innerHTML = `
    <form class="ww-kaart" novalidate onsubmit="event.preventDefault(); slaWachtwoordOp()">
      <div class="ww-kop"><strong>${wijzigen ? 'Wachtwoord wijzigen' : 'Sneller inloggen?'}</strong>
        <button type="button" class="ww-sluit" aria-label="Sluiten" onclick="sluitWachtwoordKaart()">×</button></div>
      <p class="ww-uitleg">${wijzigen ? 'Kies een nieuw wachtwoord. Je iPhone of Chrome vraagt of hij het mag bewaren.'
        : 'Stel een wachtwoord in. Je iPhone en Chrome bewaren het, daarna log je in met Face ID — zonder e-mail.'}</p>
      <input class="ww-verborgen" type="email" name="username" autocomplete="username" value="${esc((currentUser && currentUser.email) || '')}" tabindex="-1" aria-hidden="true" readonly>
      <input class="ww-veld" type="password" id="wwNieuw" autocomplete="new-password" placeholder="Nieuw wachtwoord (min. 8 tekens)" aria-label="Nieuw wachtwoord" enterkeyhint="done">
      <button type="submit" id="wwOpslaan" class="ww-knop">Wachtwoord opslaan</button>
      <div id="wwMsg" class="ww-msg" aria-live="polite"></div>
    </form>`;
  el.hidden = false;
}

function sluitWachtwoordKaart() {
  try { sessionStorage.setItem('dc_ww_later', '1'); } catch {}
  const el = document.getElementById('wachtwoordKaart');
  if (el) { el.hidden = true; el.innerHTML = ''; }
}

function openWachtwoordWijzigen() {
  buildWachtwoordKaart(true);
  document.querySelector('.scroll-area')?.scrollTo({ top: 0, behavior: 'smooth' });
  window.scrollTo({ top: 0, behavior: 'smooth' });
  setTimeout(() => document.getElementById('wwNieuw')?.focus(), 300);
}

async function slaWachtwoordOp() {
  const inp = document.getElementById('wwNieuw'), btn = document.getElementById('wwOpslaan'), msg = document.getElementById('wwMsg');
  const probleem = wachtwoordProbleem(inp.value);
  if (probleem) { msg.textContent = probleem; inp.focus(); return; }
  if (btn.disabled) return;
  btn.disabled = true; btn.textContent = 'Opslaan…'; msg.textContent = '';
  try {
    const { error } = await sb.auth.updateUser({ password: inp.value });
    if (error) {
      const m = String(error.message || '');
      msg.textContent = /different|same/i.test(m) ? 'Dit is al je huidige wachtwoord.'
        : /weak|short|characters|pwned/i.test(m) ? 'Dit wachtwoord is te zwak. Kies een langer of minder voor de hand liggend wachtwoord.'
        : /session|jwt|reauth/i.test(m) ? 'Je sessie is verlopen. Log opnieuw in en probeer het nog eens.'
        : 'Opslaan lukte niet. Probeer het opnieuw.';
      btn.disabled = false; btn.textContent = 'Wachtwoord opslaan';
      return;
    }
    _db.settings.profiel = { ...(_db.settings.profiel || {}), wachtwoordIngesteld: true };
    _saveSettings();
    const el = document.getElementById('wachtwoordKaart'); el.hidden = true; el.innerHTML = '';
    showToast('Wachtwoord ingesteld — voortaan log je in met Face ID');
  } catch {
    msg.textContent = 'Geen verbinding. Controleer je internet en probeer opnieuw.';
    btn.disabled = false; btn.textContent = 'Wachtwoord opslaan';
  }
}
```

In `initAuth`, na `init();`: `buildWachtwoordKaart();`

- [ ] **Step 7:** alle `verify-*.cjs` → PASS.
- [ ] **Step 8: Commit** `feat: kaart om eenmalig een wachtwoord in te stellen + wijzigen in Beheer`.

---

### Task 3: Supabase-instelling, browsertest, PR

- [ ] **Step 1:** In Chrome: Supabase → Authentication → Sign In / Providers → Email. Controleer dat e-mail-inloggen aan staat en noteer de minimale wachtwoordlengte. Niets wijzigen zonder akkoord.
- [ ] **Step 2: Browsertest** lokaal (`preview_start daily-coach`), met nagebootste `sb.auth.signInWithPassword` / `signInWithOtp` / `updateUser` / `getUser` en `sb.from` (geen netwerk): goed wachtwoord → reload; fout wachtwoord → "E-mail of wachtwoord klopt niet."; 429; e-maillink-route; kaart verschijnt na inloggen, te kort wachtwoord, succes → kaart weg en `wachtwoordIngesteld: true` in settings-write; "Wachtwoord wijzigen" in Beheer opent kaart; behandelaar ziet geen kaart. Mobiel 375px + desktop.
- [ ] **Step 3:** Testgegevens uit localStorage/sessionStorage halen; PR openen; PR #19 sluiten zonder merge.
