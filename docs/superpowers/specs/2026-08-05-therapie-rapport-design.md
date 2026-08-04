# Ontwerp: Slim therapierapport

**Datum:** 2026-08-05  
**Status:** Goedgekeurd

## Probleem

Na 100+ dagen dagboek wordt het rapport honderden pagina's. De psycholoog heeft alleen de meest recente periode nodig — niet alles.

## Oplossing

Rapport filtert automatisch op therapieperiode: van vorige afspraak tot dag vóór volgende sessie.

---

## Periode-logica

| Situatie | Rapport toont |
|---|---|
| Volgende sessie bekend | Vorige afspraak → dag vóór volgende sessie |
| Geen volgende sessie | Vorige afspraak → vandaag |
| Alle sessies voorbij | Laatste sessie → vandaag |

**Opslag in localStorage:**
- `lc_prev_appointment` — standaard `"2026-07-14"` (laatste afspraak vóór app)
- `lc_next_appointment` — optioneel, overschrijft automatische sessiedatum

---

## Rapport-structuur (voor psycholoog)

### 1. Header
```
Sessie 1 · 10 augustus 2026 · 10:00 · Vaart Z.Z.
Periode: 14 juli – 9 augustus 2026
Dag 2 van 365 — Gegenereerd op woensdag 5 augustus 2026
```

### 2. Sessievoorbereiding
- Wat wil ik bereiken in deze sessie?
- Achtergrond die helpt

### 3. Samenvatting (compact)
- Per tracker: percentage gezond gedrag in de periode
- Dagen ingevuld: X van Y dagen

### 4. Dagentries volledig
- Alle ingevulde dagen in de periode, chronologisch
- Per dag: datum, tracker-pills, alle journaalantwoorden

---

## Wijzigingen in de app

### Sessie tab
- Nieuw veld: **Tijd** (tijdpicker, bijv. 10:00)
- Nieuw veld: **Locatie** (keuzelijst: Vaart Z.Z. / Molenstraat / Anders)
- Tijd + locatie verschijnen in rapport-header

### Archief tab
- Nieuw: **"Vorige afspraak"** datumveld (standaard 2026-07-14, aanpasbaar)
- Nieuw: **"Volgende afspraak"** datumveld (optioneel, overschrijft app-sessiedatum)

### Rapport tab
- Nieuw: knop **"Rapport voor volgende sessie"** — toont gefilterde periode
- Bestaand: knop **"Volledig overzicht"** blijft beschikbaar voor persoonlijk gebruik

---

## Wat NIET verandert
- Dagelijkse invulflow
- Weekreflectie
- Export/import JSON
- Bestaande THERAPY_SESSIONS array (wordt gebruikt als fallback voor volgende sessiedatum)
