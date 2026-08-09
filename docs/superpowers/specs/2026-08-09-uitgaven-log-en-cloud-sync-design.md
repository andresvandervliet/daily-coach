# Uitgaven Log per Knab Envelop + Cloud Sync

**Datum**: 2026-08-09
**Status**: Goedgekeurd

## Samenvatting

Twee onafhankelijke features voor de Daily Coach Financiën tab:

1. **Uitgaven loggen** — individuele uitgaven (bijv. McDonald's) per Knab envelop bijhouden
2. **Cloud sync** — localStorage automatisch synchroniseren tussen iPhone en PC via Supabase

## Feature 1: Uitgaven Log per Knab Envelop

### Gebruikersflow

1. Gebruiker opent Financiën tab op iPhone
2. Bij elke Knab envelop (bijv. "Uit eten") staat een **"+ Uitgave"** knop
3. Tik erop → invulvelden verschijnen: **bedrag** (verplicht), **omschrijving** (optioneel)
4. Datum wordt automatisch vandaag
5. Saldo wordt direct verlaagd
6. Onder de kaart verschijnt een lijstje van uitgaven deze maand
7. Elke uitgave kan verwijderd worden (swipe of X-knop)

### Data model

Opslag per maand in localStorage:

- **Key**: `lc_fin_knab_tx_2026-08`
- **Value**: array van transactie-objecten

```json
[
  { "id": 1723190400000, "knabId": 4, "bedrag": 12.50, "omschrijving": "McDonald's", "datum": "2026-08-09" },
  { "id": 1723276800000, "knabId": 4, "bedrag": 8.90, "omschrijving": "McDonald's", "datum": "2026-08-12" }
]
```

### Saldo berekening

Het huidige saldo-check model (handmatig saldo invoeren) wordt vervangen:

- **Oud**: gebruiker opent Knab app, leest saldo af, typt het in
- **Nieuw**: saldo = `gestort - som(uitgaven deze maand)`

De handmatige saldo-invoer verdwijnt. Uitgaven loggen IS het saldo bijhouden.

### UI aanpassingen

- Knab envelop kaart krijgt een **"+ Uitgave"** knop
- Inline formulier: bedrag + omschrijving + bevestig-knop
- Transactielijst onder de kaart: datum, omschrijving, bedrag, verwijder-knop
- Saldo, uitgegeven, en voortgangsbalk worden berekend uit transacties

## Feature 2: Cloud Sync

### Architectuur

```
iPhone/PC browser
    ↕ fetch (GET/POST)
Netlify Function (/.netlify/functions/sync)
    ↕ supabase-js client
Supabase PostgreSQL (free tier)
```

### Netlify Function: `sync`

Eén serverless function met twee endpoints:

- **GET** `/.netlify/functions/sync` — haalt alle opgeslagen data op
- **POST** `/.netlify/functions/sync` — slaat data op (volledige localStorage snapshot)

### Supabase tabel

Eén tabel `sync_data`:

| kolom | type | beschrijving |
|-------|------|-------------|
| key | text (PK) | localStorage key (bijv. `lc_fin_vaste`) |
| value | text | JSON string van de waarde |
| updated_at | timestamptz | laatste wijziging |

Elke `lc_*` key wordt als aparte rij opgeslagen zodat merge per key kan.

### Beveiliging

- Netlify environment variable: `SYNC_KEY` (willekeurige string)
- Elke request stuurt `Authorization: Bearer <SYNC_KEY>` header
- Function weigert requests zonder geldige key met 401
- Geen gebruikersaccounts, geen login — single-user app

### Sync gedrag

**Bij app openen (init)**:
1. Fetch GET met SYNC_KEY
2. Per key: vergelijk `updated_at` van server vs lokale `lc_meta_updated_<key>`
3. Nieuwste wint per key
4. Update lokale localStorage met server-data waar server nieuwer is

**Bij opslaan (saveToday, saveWeek, financiën wijzigingen)**:
1. Sla op in localStorage (bestaand gedrag)
2. Zet `lc_meta_updated_<key>` op `Date.now()`
3. POST gewijzigde keys naar server

**Offline**:
- App werkt normaal met localStorage
- Bij volgende online-moment synct automatisch bij app openen

### Sync key opslag in de app

De SYNC_KEY moet in de app beschikbaar zijn. Opties:
- Hardcoded in de HTML (acceptabel voor single-user, private repo)
- Of: gebruiker vult eenmalig de key in via Archief tab, opgeslagen in localStorage

Gekozen: **hardcoded** — simpelst, en de repo is private.

### Benodigde setup

1. Supabase project aanmaken (free tier)
2. Tabel `sync_data` aanmaken
3. Supabase URL + anon key als Netlify env vars
4. `SYNC_KEY` als Netlify env var
5. Netlify Functions directory configureren
6. `netlify/functions/sync.js` schrijven

## Scope

- Feature 1 (uitgaven log) is puur frontend — kan direct gebouwd worden
- Feature 2 (cloud sync) vereist Supabase setup + Netlify Functions — apart implementeren
- Volgorde: eerst feature 1, dan feature 2

## Feature 3: Sync-indicator

Een klein statuslabel onderaan de app (boven de bottom nav) dat toont:
- "Gesynct" met groen bolletje — data is up-to-date
- "Synchroniseren..." — sync is bezig
- "Offline" met grijs bolletje — geen internet, werkt lokaal
- "Sync mislukt" met rood bolletje — fout, probeer later opnieuw

Wordt automatisch bijgewerkt na elke sync-actie. Verdwijnt na 3 seconden, verschijnt alleen bij statuswijziging.

## Feature 4: Auto-save

Alle tekstvelden (journaal, check-in vragen, weekreflectie, toelichting) slaan automatisch op na 2 seconden niet-typen (debounce). De "Dag opslaan" knop blijft bestaan voor expliciet opslaan + toast-bevestiging, maar data gaat niet meer verloren als de gebruiker vergeet te klikken.

Bij auto-save wordt ook een sync naar de server getriggerd (als online).

## Feature 5: Maandtotaal per envelop

Onder elke Knab envelop kaart verschijnt een samenvatting:
- Aantal transacties deze maand (bijv. "4x")
- Totaalbedrag uitgegeven (bijv. "€38,40")
- Meest voorkomende omschrijving (bijv. "McDonald's")

Dit geeft direct inzicht in uitgavenpatronen zonder dat de gebruiker hoeft te rekenen.

## Niet in scope

- Multi-user support
- Realtime sync (WebSocket) — poll bij app openen is genoeg
- Encryptie van data — single-user, private repo, HTTPS is voldoende
