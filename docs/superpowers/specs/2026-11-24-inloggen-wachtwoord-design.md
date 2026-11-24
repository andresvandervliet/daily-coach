# Inloggen met wachtwoord + Face ID — ontwerp

Datum: 2026-11-24 · Status: goedgekeurd

## Probleem

Inloggen loopt nu volledig via e-mail (magic link). Dat geeft drie terugkerende problemen:

- Een link werkt één keer en verloopt snel (`otp_expired`).
- Supabase verstuurt via de ingebouwde mailserver maar enkele mails per uur → "te veel inloglinks aangevraagd".
- Op iPhone opent de link in Safari, niet in de geïnstalleerde app (aparte opslag), dus je bent daarna niet ingelogd in de app.

Een code in de mail lost dit niet op: dezelfde maillimiet, en het template is niet aan te passen zonder eigen SMTP.

## Doel

Snel en betrouwbaar inloggen op iPhone (home-screen-app én Safari) en desktop, zonder afhankelijkheid van e-mail bij normaal gebruik.

Succes = na eenmalige instelling: tik op het wachtwoordveld → Face ID / opgeslagen wachtwoord → binnen. Geen mail, geen verlopen links, geen maillimiet.

## Ontwerp

### 1. Loginscherm

- Velden: e-mailadres (`autocomplete="username"`, `type="email"`) en wachtwoord (`autocomplete="current-password"`, `type="password"`), in één `<form>` zodat iCloud-sleutelhanger en Chrome het als inlogformulier herkennen en opgeslagen gegevens voorstellen.
- Eén primaire knop **Inloggen** → `sb.auth.signInWithPassword({ email, password })`. Succes → pagina herladen (bestaand `onAuthStateChange`-gedrag).
- Secundaire link **"Inloggen met e-maillink"** → de bestaande magic-link-flow (ook de route voor "wachtwoord vergeten" en de eerste keer).
- Foutmeldingen (Nederlands, met herstelstap):
  - Ongeldige inloggegevens → "E-mail of wachtwoord klopt niet." met de e-maillink ernaast.
  - Rate limit (429) → "Te veel pogingen. Wacht even en probeer het opnieuw."
  - Netwerkfout → "Geen verbinding. Controleer je internet en probeer opnieuw."
- Laatst gebruikte e-mailadres blijft vooringevuld (bestaand `dc_login_email`).
- De bestaande verlopen-link-melding blijft werken; de knop daarin wordt "Inloggen" en de melding verwijst naar inloggen met wachtwoord of een nieuwe link.

### 2. Eenmalig wachtwoord instellen

- Na inloggen: als `settings.profiel.wachtwoordIngesteld` niet `true` is, verschijnt bovenaan de app een kaart **"Sneller inloggen? Stel een wachtwoord in."** met een knop die een klein formulier opent.
- Formulier: verborgen e-mailveld (`autocomplete="username"`, gevuld met het account-e-mailadres) + nieuw wachtwoord (`autocomplete="new-password"`, minimaal 8 tekens) → `sb.auth.updateUser({ password })`. Het username-veld zorgt dat iOS/Chrome aanbieden het wachtwoord bij het juiste account te bewaren.
- Succes → `profiel.wachtwoordIngesteld = true` opslaan, kaart verdwijnt, toast "Wachtwoord ingesteld — voortaan log je in met Face ID".
- Fout (te zwak/te kort, sessie verlopen, netwerk) → melding in het formulier, niets opgeslagen.
- Wijzigen kan later via **Financiën → Beheer** (knop "Wachtwoord wijzigen" naast Uitloggen), zelfde formulier.
- De kaart verschijnt niet voor de rol `behandelaar`.

### 3. Ingelogd blijven

Supabase bewaart de sessie standaard (`persistSession`) en ververst tokens automatisch. Controleren dat de client niet met afwijkende opties wordt aangemaakt en dat niets onbedoeld `signOut` aanroept. Geen extra code als dit klopt.

### 4. Wat verdwijnt

- De codestap (codeveld, "Nieuwe code sturen", `dc_login_code`) uit PR #18. Na het versturen van een link toont het scherm weer de eenvoudige melding "Check je inbox…".
- PR #19 (tekst bij de codestap) wordt gesloten zonder merge.

### 5. Supabase-instelling

In het dashboard (Authentication → Sign In / Providers → Email) controleren dat inloggen met wachtwoord aanstaat. Alleen wijzigen na akkoord van de gebruiker. Geen SMTP of templatewijziging nodig.

## Opslag

Alleen `settings.profiel.wachtwoordIngesteld` (JSONB) — geen schemawijziging. Het wachtwoord zelf beheert Supabase Auth; de app slaat het nergens op.

## Testen

- Bestaande `verify-*.cjs` blijven slagen.
- Browser, lokaal, met nagebootste `sb.auth` (geen netwerk, geen productie): inloggen gelukt, verkeerd wachtwoord, 429, netwerkfout, e-maillink-route, wachtwoord instellen (succes + te kort), kaart verdwijnt na instellen, kaart verborgen voor behandelaar, mobiel 375px en desktop.
- Na livegang: gebruiker stelt eenmalig wachtwoord in via een laatste e-maillink en logt daarna in op iPhone-app en desktop met het opgeslagen wachtwoord.

## Buiten scope

Passkeys (Supabase BETA), eigen SMTP, Google-login, twee-factor.
