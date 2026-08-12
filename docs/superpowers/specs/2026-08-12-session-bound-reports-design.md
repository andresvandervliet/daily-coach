# Session-Bound Reports — Design Spec

**Doel:** Weekreflecties en rapporten koppelen aan therapiesessies in plaats van weeknummers, met automatische afsluiting en een archief van eerdere sessie-rapporten.

**Scope:** Weekreflectie-opslag, rapport-generatie, rapport-archief, sessie-levenscyclus, migratie van bestaande data. Geen wijzigingen aan dagelijkse check-ins, patroonweging, of het rapport-formaat zelf.

---

## 1. Datamodel

### Nieuwe structuur: `_db.sessions_data`

```js
_db.sessions_data["2026-08-10"] = {
  // Weekreflectie (verhuist van _db.weeks)
  wq1: "Ik heb mezelf verlaten toen...",
  wq2: "...",
  wq3: "...",
  wq4: "...",
  wq5: "...",

  // Sessie-voorbereiding (verhuist van _db.preps)
  prep: { thema: "...", doel: "...", achtergrond: "..." },

  // Rapport snapshot (HTML string, gegenereerd bij afsluiten)
  snapshot: "<div class='rapport-section'>...",
  snapshot_date: "2026-08-12T14:30:00.000Z",

  // Status
  status: "afgesloten"  // "actief" | "afgesloten"
}
```

### Supabase

Nieuwe tabel `session_reports`:

| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `id` | uuid | PK, default gen_random_uuid() |
| `user_id` | uuid | FK naar auth.users |
| `session_date` | text | Sessiedatum als YYYY-MM-DD |
| `data` | jsonb | Volledige sessions_data object |
| `updated_at` | timestamptz | Laatste wijziging |

RLS: `user_id = auth.uid()` op alle operaties.

Unique constraint op `(user_id, session_date)` — upsert bij opslaan.

### Wat verdwijnt

- `_db.weeks` — wordt niet meer gebruikt na migratie (data verhuist naar `sessions_data`)
- `_db.preps` — wordt niet meer gebruikt na migratie (data verhuist naar `sessions_data`)
- `_db.settings.prev_appointment` — wordt afgeleid uit sessiedatums
- `_db.settings.next_appointment` — wordt afgeleid uit sessiedatums

### Wat NIET verandert

- `_db.days` — dagelijkse check-ins, scores, journaal
- `_db.therapy` — therapiesessie-logs (onderwerpen, inzichten, doelen, acties)
- `THERAPY_SESSIONS` constant — bron van sessiedatums
- Het rapport zelf (secties, opbouw, profiel, patroonsamenvatting)

---

## 2. Sessie-levenscyclus

### Actieve sessie bepalen

```
functie getActieveSessie():
  alleSessies = THERAPY_SESSIONS + handmatig toegevoegde sessies
  sorteer op datum

  // Zoek de eerstvolgende sessie die nog niet is afgesloten
  voor elke sessie in alleSessies:
    sessieData = _db.sessions_data[sessie.date]
    als sessieData niet bestaat OF sessieData.status !== "afgesloten":
      return sessie

  return null  // geen actieve sessie
```

### Afsluiten

Trigger: handmatig via "Sessie afsluiten" knop, of automatisch wanneer de sessiedatum in het verleden ligt en de gebruiker de app opent.

Stappen bij afsluiten:
1. Genereer het volledige rapport (zelfde `buildRapport('sessie')` logica)
2. Sla de gegenereerde HTML op als `snapshot` in `sessions_data[datum]`
3. Sla `snapshot_date` op (ISO timestamp)
4. Zet `status` op `"afgesloten"`
5. Sync naar Supabase (upsert in `session_reports`)
6. Maak de weekreflectie-velden in de UI leeg (de volgende sessie is nu actief)

### Automatische afsluiting

Bij `init()`:
- Check of de actieve sessiedatum in het verleden ligt (`sessie.date < vandaag`)
- Zo ja: toon een banner bovenaan de pagina:
  ```
  "Je sessie van [datum] is geweest. Wil je het rapport afsluiten?"
  [Afsluiten]  [Later]
  ```
- "Afsluiten" voert de afsluit-stappen uit
- "Later" verbergt de banner voor vandaag (sla op in `_db.settings.dismiss_close_banner = vandaag`)

---

## 3. Rapport-periodes

### Huidige logica (blijft grotendeels)

Het rapport toont dagelijkse check-ins voor de periode `prev_sessiedatum` tot `actieve_sessiedatum - 1 dag`.

### Nieuwe afleiding

```
functie getTherapiePeriode():
  actief = getActieveSessie()
  als actief is null: return { prev: startdatum, endDate: vandaag, next: null }

  // Zoek de voorgaande afgesloten sessie
  alleSessies = alle sessiedatums, gesorteerd
  actieveIndex = index van actief in alleSessies
  als actieveIndex > 0:
    prev = parseDate(alleSessies[actieveIndex - 1].date)
  anders:
    prev = getStartDate()

  next = parseDate(actief.date)
  endDate = next - 1 dag

  return { prev, endDate, next }
```

Dit vervangt de huidige `prev_appointment` / `next_appointment` logica.

---

## 4. UI-wijzigingen

### Rapport-tab: drie knoppen

```html
[Huidig rapport]  [Archief]  [Volledig overzicht]
```

- **Huidig rapport** (`buildRapport('sessie')`): live gegenereerd voor actieve sessie, identiek aan nu
- **Archief** (`buildRapport('archief')`): lijst van afgesloten sessies met snapshots
- **Volledig overzicht** (`buildRapport('volledig')`): alle dagen, identiek aan nu

### Archief-weergave

Wanneer `mode === 'archief'`:
- Toon lijst van alle sessiedatums in `_db.sessions_data` waar `status === "afgesloten"`, nieuwste bovenaan
- Per sessie: kaart met datum, locatie (uit THERAPY_SESSIONS), snapshot-datum
- Klik op kaart → inject `snapshot` HTML in `rapportBody`
- "Kopieer tekst" en "Afdrukken" werken op de getoonde snapshot

### Week-tab

- Boven de reflectievragen: label "Reflectie voor sessie van [datum]"
- De velden laden/opslaan van/naar `_db.sessions_data[actieveSessie.date].wq1..wq5`
- Als er geen actieve sessie is: toon melding "Voeg een afspraak toe om reflecties in te vullen"

### Sessie-tab (voorbereiding)

- De sessie-prep velden laden/opslaan van/naar `_db.sessions_data[actieveSessie.date].prep`
- Bestaande flow blijft identiek, alleen de opslag-locatie verandert

### Archief-tab (therapieafspraken)

- De handmatige "vorige/volgende afspraak" date-inputs verdwijnen
- In plaats daarvan: de sessie-levenscyclus bepaalt automatisch de periodes
- De geplande sessies beheren (toevoegen/verwijderen) blijft

### Afsluiten-banner

Wanneer de actieve sessie in het verleden ligt, toon bovenaan de scroll-area:

```html
<div class="close-session-banner">
  Je sessie van [datum] is geweest.
  <button onclick="sluitSessieAf()">Rapport afsluiten</button>
  <button onclick="dismissBanner()">Later</button>
</div>
```

Styling: subtiele gouden rand, zelfde stijl als de sessie-prep-banner.

---

## 5. Migratie

### Eenmalig bij app-load

```
functie migrateSessieBound():
  als _db.sessions_data al entries heeft: return  // al gemigreerd

  // 1. Weekreflecties migreren
  voor elke weekNr in _db.weeks:
    weekData = _db.weeks[weekNr]
    als weekData geen wq1..wq5 heeft: skip

    // Zoek de dichtstbijzijnde sessiedatum bij deze week
    weekStartDag = (weekNr - 1) * 7 + 1
    weekStartDate = startDatum + weekStartDag dagen
    dichtstbijzijnde = zoek sessie met datum dichtst bij weekStartDate

    als dichtstbijzijnde:
      _db.sessions_data[dichtstbijzijnde.date] = {
        wq1: weekData.wq1, wq2: weekData.wq2, ..., wq5: weekData.wq5,
        status: (dichtstbijzijnde.date < vandaag) ? "afgesloten" : "actief"
      }

  // 2. Sessie-voorbereiding migreren
  voor elke key in _db.preps:
    sessieDate = key.replace('prep_', '')
    als _db.sessions_data[sessieDate] niet bestaat:
      _db.sessions_data[sessieDate] = {}
    _db.sessions_data[sessieDate].prep = _db.preps[key]

  // 3. Geen snapshot voor historische sessies
  // Snapshots worden alleen gegenereerd bij toekomstige afsluitingen.
  // Gemigreerde sessies hebben status "afgesloten" maar geen snapshot —
  // dat is acceptabel, de reflectiedata is het belangrijkste.

  // 4. _db.sessions_data initialiseren bij _db setup
  // Voeg `sessions_data: {}` toe aan het _db object naast days, weeks, etc.

  // 5. Sync naar Supabase
  voor elke entry: upsert naar session_reports
```

### Fallback

Als de migratie geen weekdata kan koppelen aan een sessie (bijv. geen sessies gepland in die periode), wordt de data gekoppeld aan de eerste beschikbare sessie.

---

## 6. Supabase sync

### Laden bij init

```js
const sessionsRes = await sb.from('session_reports')
  .select('session_date, data')
  .eq('user_id', uid);

(sessionsRes.data || []).forEach(r => {
  _db.sessions_data[r.session_date] = r.data;
});
```

### Opslaan

Bij `saveWeek()` en `sluitSessieAf()`:

```js
await sb.from('session_reports').upsert({
  user_id: uid,
  session_date: actieveSessie.date,
  data: _db.sessions_data[actieveSessie.date],
  updated_at: new Date().toISOString()
});
```

Zelfde fire-and-forget patroon als de rest van de app.

---

## 7. Niet in scope

- Geen wijzigingen aan het rapport-formaat (secties, profiel, patroonsamenvatting)
- Geen wijzigingen aan dagelijkse check-ins of patroonweging
- Geen export naar PDF (bestaande print-functie blijft)
- Geen vergelijking tussen sessie-rapporten (toekomstige iteratie)
- Geen notificaties/reminders voor afsluiten
- Geen wijzigingen aan therapiesessie-logs (onderwerpen, inzichten)
