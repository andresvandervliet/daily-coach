# Supabase Sync — Design Spec

**Datum:** 2026-08-11
**Doel:** Daily Coach data synchroniseren tussen iPhone en desktop via Supabase, met rolgebaseerde toegang voor de behandelaar.

---

## 1. Aanpak

**Online-first**: Supabase is de enige databron. localStorage wordt volledig vervangen. Geen offline-mode, geen conflict-handling.

## 2. Authenticatie

- **Supabase Auth** met magic link (e-mail)
- Sessie blijft 30 dagen geldig
- Login-flow: e-mail invullen → magic link ontvangen → klikken → ingelogd

### Rollen

| Rol | E-mail | Toegang | Schrijven |
|-----|--------|---------|-----------|
| `owner` | andresvandervliet@gmail.com | Alles | Ja |
| `behandelaar` | Later in te stellen | Alleen mentale tabs | Nee |

Rollen worden opgeslagen in een `user_roles` tabel. Supabase Row Level Security (RLS) dwingt de toegang af op database-niveau.

### Behandelaar-restricties

**Mag zien:** daily_entries, weekly_entries, therapy_sessions, coach_sessions, goals
**Mag NIET zien:** finance, settings (incl. profiel)
**Toekomstige tabs:** standaard niet zichtbaar voor behandelaar, tenzij expliciet toegevoegd als mentale tab

In de app-code wordt de tab-balk gefilterd op basis van rol: behandelaar ziet geen Financiën-tab en geen toekomstige niet-mentale tabs.

## 3. Datamodel

Alle `lc_*` localStorage keys worden Supabase-tabellen:

### `daily_entries`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| date | date | Datum van de entry |
| data | jsonb | Volledige dagdata (check-in, journaal, tracker) |
| created_at | timestamptz | Aangemaakt |
| updated_at | timestamptz | Laatst gewijzigd |

### `weekly_entries`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| week_number | int | Weeknummer in programma |
| data | jsonb | Weekreflectie data |
| created_at | timestamptz | Aangemaakt |
| updated_at | timestamptz | Laatst gewijzigd |

### `therapy_sessions`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| data | jsonb | Array van therapiesessie-objecten |
| updated_at | timestamptz | Laatst gewijzigd |

### `coach_sessions`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| date | date | Sessiedatum |
| data | jsonb | Sessie-inhoud (onderwerpen, inzichten, doelen, acties) |
| created_at | timestamptz | Aangemaakt |

### `goals`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| active_goals | jsonb | Array van actieve doelen |
| active_actions | jsonb | Array van actieve acties |
| updated_at | timestamptz | Laatst gewijzigd |

### `finance`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| month_key | text | YYYY-MM |
| vaste | jsonb | Vaste lasten lijst |
| knab | jsonb | Knab enveloppen |
| knab_tx | jsonb | Knab transacties |
| betaald | jsonb | Betaald-status per vaste last |
| salaris | numeric | Salaris bedrag |
| salaris_ontvangen | boolean | Of salaris is ontvangen |
| salaris_datum | date | Datum salaris ontvangen |
| history | jsonb | Maandhistorie |
| updated_at | timestamptz | Laatst gewijzigd |

### `settings`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| profiel | jsonb | Psychologisch profiel |
| start_date | date | Startdatum programma |
| prev_appointment | date | Vorige afspraak |
| next_appointment | date | Volgende afspraak |
| updated_at | timestamptz | Laatst gewijzigd |

### `user_roles`
| Kolom | Type | Beschrijving |
|-------|------|-------------|
| id | uuid | PK |
| user_id | uuid | FK naar auth.users |
| owner_id | uuid | FK naar de owner wiens data gedeeld wordt |
| role | text | 'owner' of 'behandelaar' |
| created_at | timestamptz | Aangemaakt |

## 4. Row Level Security (RLS)

Elke tabel krijgt RLS-policies:

**Owner:**
- SELECT, INSERT, UPDATE, DELETE op eigen data (`user_id = auth.uid()`)

**Behandelaar (alleen mentale tabellen):**
- SELECT op `daily_entries`, `weekly_entries`, `therapy_sessions`, `coach_sessions`, `goals` waar `user_id` = gekoppelde `owner_id` uit `user_roles`
- Geen INSERT, UPDATE, DELETE

**Finance en settings:**
- Alleen owner, geen behandelaar-toegang

## 5. App-architectuur

### Supabase client
- Supabase JS library wordt inline opgenomen in index.html (geen CDN)
- Supabase URL en anon key worden als constanten in de code gezet (anon key is veilig publiek dankzij RLS)

### Data-laag herschrijving
Bestaande functies behouden hun naam maar worden async:
- `getFinVaste()` → `async getFinVaste()` die Supabase query doet
- `saveFinVaste(l)` → `async saveFinVaste(l)` die Supabase upsert doet
- Alle render-functies worden aangepast om await te gebruiken

### Login-scherm
- Nieuw scherm dat verschijnt als `supabase.auth.getUser()` geen sessie vindt
- Simpel: e-mail input + "Inloggen" knop
- Na magic link klik: redirect terug naar app, sessie wordt opgeslagen
- "Uitloggen" knop in de app (bijv. in een instellingen-menu)

### Tab-filtering
- Na inloggen: rol ophalen uit `user_roles`
- Als `behandelaar`: Financiën-tab verbergen via `display:none`
- Toekomstige niet-mentale tabs krijgen een `data-role="owner"` attribuut en worden automatisch verborgen voor behandelaar

## 6. Migratie

### Eenmalige localStorage → Supabase migratie

1. Gebruiker logt in met Supabase
2. App detecteert: localStorage heeft `lc_*` data EN Supabase-tabellen zijn leeg
3. "Data overzetten" knop verschijnt
4. Alle `lc_*` keys worden gelezen, getransformeerd, en naar Supabase geschreven
5. Na succesvolle migratie: `lc_migrated = true` in localStorage, rest wordt verwijderd
6. Bij mislukking: localStorage blijft intact, opnieuw proberen mogelijk

### Key-mapping

| localStorage key | → Supabase tabel |
|-----------------|------------------|
| `lc_day_YYYY-MM-DD` | `daily_entries` (date = YYYY-MM-DD) |
| `lc_week_N` | `weekly_entries` (week_number = N) |
| `lc_therapy_sessions` | `therapy_sessions` |
| `lc_sessions` | `coach_sessions` (1 rij per sessie) |
| `lc_active_goals` | `goals` |
| `lc_active_actions` | `goals` |
| `lc_fin_*` | `finance` (per month_key) |
| `lc_profiel` | `settings` |
| `lc_start` | `settings` |
| `lc_*_appointment` | `settings` |

## 7. Deployment

- Netlify deploy blijft identiek (statische files)
- Supabase project wordt apart aangemaakt (gratis tier is voldoende)
- Supabase URL + anon key worden in de code gezet
- Geen server-side code nodig
