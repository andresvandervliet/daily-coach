# Pattern-Weighted Question Rotation — Design Spec

**Doel:** De Daily Coach app transformeren van statische vraag-rotatie naar een levend brein dat dagelijkse vragen selecteert op basis van herkende gedragspatronen in de laatste 7 dagen check-in data.

**Scope:** Alleen de dagelijkse check-in pagina (vandaag-tab). Geen weekreview, geen behandelaar-dashboard, geen AI-calls.

---

## 1. Patroon-tags

Elke intentie en journal prompt wordt getagd met een of meer tags uit deze vaste set:

| Tag | Patroon | Check-in link |
|-----|---------|---------------|
| `pleasen` | Meer geven, overbeschikbaar, grenzen versoepelen | q1 (zelfverlating) |
| `grenzen` | Grens niet uitspreken, niet uitvoeren | q3 (grens) |
| `humor` | Humor als schild, kwetsbaarheid vermijden | q2 (humor) |
| `verdoving` | Alcohol, productiviteit als verdoving, niet voelen | tracker t4 |
| `eigenwaarde` | Bewijsdrang, nodig willen zijn, externe bevestiging | tracker t1 |
| `verbinding` | Eenzaamheid, terugtrekken, isolatie | tracker t2 |
| `mannelijkheid` | Kwetsbaarheid, kracht, controle | — |
| `relatie` | Intensiteit vs stabiliteit, gekozen worden | — |

### Tagging-formaat

De bestaande `INTENTIONS` en `JOURNAL_PROMPTS` arrays worden uitgebreid van strings naar objecten:

```js
// Was:
const INTENTIONS = ["Als je merkt dat je harder gaat werken...", ...];

// Wordt:
const INTENTIONS = [
  { t: "Als je merkt dat je harder gaat werken om iemands aandacht te krijgen — stop.",
    tags: ["pleasen", "eigenwaarde"] },
  // ...
];
```

Elke intentie/prompt krijgt minimaal 1 tag, maximaal 3.

---

## 2. Weging-algoritme

### Signalen

| Databron | Signaal | Tags die gewicht krijgen |
|----------|---------|--------------------------|
| Check-in q1 (zelfverlating) score laag (≤ 2) | Pleasen actief | `pleasen`, `eigenwaarde` |
| Check-in q2 (humor als pantser) score laag (≤ 2) | Kwetsbaarheid vermeden | `humor`, `verbinding` |
| Check-in q3 (grens niet uitgesproken) score laag (≤ 2) | Grenzen niet bewaakt | `grenzen`, `pleasen` |
| Tracker t1 (eigen doelen) laag (≤ 2) | Bewijsdrang actief | `eigenwaarde` |
| Tracker t2 (behoeften uitgesproken) laag (≤ 2) | Terugtrekken | `verbinding` |
| Tracker t4 (terugtrekken/verdoving) hoog (≥ 3) | Verdoving actief | `verdoving` |
| 3+ opeenvolgende dagen zelfde signaal | Patroon versterkt | Dubbel gewicht op die tag |

### Berekening

```
functie berekenPatroonGewichten(days, vandaag):
  gewichten = { pleasen: 0, grenzen: 0, humor: 0, verdoving: 0, eigenwaarde: 0, verbinding: 0, mannelijkheid: 0, relatie: 0 }

  laatste7 = sorteer days op datum, pak laatste 7

  voor elke dag in laatste7:
    als dag.q1 ≤ 2: gewichten.pleasen += 1, gewichten.eigenwaarde += 1
    als dag.q2 ≤ 2: gewichten.humor += 1, gewichten.verbinding += 1
    als dag.q3 ≤ 2: gewichten.grenzen += 1, gewichten.pleasen += 1
    als dag.t1 ≤ 2: gewichten.eigenwaarde += 1
    als dag.t2 ≤ 2: gewichten.verbinding += 1
    als dag.t4 ≥ 3: gewichten.verdoving += 1

  // Consecutieve versterking
  voor elke tag:
    tel langste reeks opeenvolgende dagen met dat signaal
    als reeks ≥ 3: gewichten[tag] × 2

  // mannelijkheid en relatie krijgen basisgewicht 1 (altijd meedoen)
  gewichten.mannelijkheid = max(gewichten.mannelijkheid, 1)
  gewichten.relatie = max(gewichten.relatie, 1)

  return gewichten
```

### Vraag-selectie

```
functie kiesVraag(pool, gewichten):
  // Bereken score per vraag
  voor elke vraag in pool:
    vraag.score = som van gewichten[tag] voor elke tag in vraag.tags
    als vraag.score == 0: vraag.score = 1  // minimumkans

  // Gewogen random selectie
  totaal = som van alle scores
  random = Math.random() * totaal
  lopend = 0
  voor elke vraag in pool:
    lopend += vraag.score
    als lopend >= random: return vraag
```

### Eerste week (geen data)

Als er minder dan 2 dagen data zijn: puur random selectie zoals nu, geen weging.

---

## 3. Escalerende check-in vragen

### Diepteniveaus

Elke van de 3 vaste check-in vragen heeft 3 niveaus:

**Q1 — Zelfverlating:**

| Niveau | ID | Vraag |
|--------|----|-------|
| Basis | 0 | "Heb je jezelf vandaag verlaten om een ander te behagen?" |
| Dieper | 1 | "Wat heb je vandaag weggegeven dat je eigenlijk voor jezelf wilde houden?" |
| Confronterend | 2 | "Je zegt dat het goed gaat. Waar zit de persoon die je probeert te overtuigen — in de spiegel of tegenover je?" |

**Q2 — Humor als pantser:**

| Niveau | ID | Vraag |
|--------|----|-------|
| Basis | 0 | "Heb je humor gebruikt om iets echts te vermijden?" |
| Dieper | 1 | "Welk gevoel zat er onder de grap die je maakte?" |
| Confronterend | 2 | "Als humor je schild is — tegen wie verdedig je je eigenlijk? De ander, of jezelf?" |

**Q3 — Grens niet uitgesproken:**

| Niveau | ID | Vraag |
|--------|----|-------|
| Basis | 0 | "Is er een grens die je niet hebt uitgesproken?" |
| Dieper | 1 | "Welke grens ken je wel, maar voer je niet uit — en wat kost je dat?" |
| Confronterend | 2 | "Je zegt dat je grenzen stelt. Noem de laatste keer dat iemand boos op je werd omdat je 'nee' zei." |

### Escalatielogica

```
functie bepaalNiveau(qIndex, days):
  laatste3 = sorteer days op datum, pak laatste 3
  als laatste3.length < 3: return 0  // basis

  scores = laatste3.map(d => d["q" + qIndex])

  als alle scores ≥ 3: return 1  // dieper — beweert dat het slecht gaat maar verandert niks
  als alle scores ≤ 2: return 2  // confronterend — beweert dat het goed gaat, klopt dat?
  return 0  // wisselend — normale reflectie

  // Na een confronterende vraag (niveau 2): reset naar basis de volgende dag
  // Dit wordt afgehandeld door te checken of gisteren niveau 2 was:
  als gisteren._shown.q_levels[qIndex] == 2: return 0
```

---

## 4. Data-opslag

### Geen schema-wijzigingen

Alles past in bestaande structuren:

- **Tags**: hardcoded in JS arrays (geen database)
- **Gewichten**: berekend on-the-fly bij pageload (niet opgeslagen)
- **Getoonde vragen**: opgeslagen in bestaand `_db.days[datum]` object

### Opslagformaat

```js
_db.days["2026-08-11"] = {
  // Bestaande velden (q1, q2, q3, t1-t5, journal, etc.)
  _shown: {
    intention: 12,      // index in INTENTIONS array
    journal: 7,         // index in JOURNAL_PROMPTS array
    q_levels: [0, 1, 0] // escalatieniveau per check-in vraag
  }
}
```

### Sync

Het `_shown` object wordt meegestuurd in de bestaande `saveToday()` Supabase upsert. Geen extra API-calls. Synct automatisch tussen iPhone en desktop.

---

## 5. UI-impact

Minimaal. De gebruiker ziet geen verschil in layout — alleen dat de vragen relevanter aanvoelen.

- **Intentie van de dag**: wordt getoond zoals nu, maar gewogen geselecteerd
- **Journal prompt**: wordt getoond zoals nu, maar gewogen geselecteerd
- **Check-in vragen**: tekst verandert op basis van escalatieniveau
- **Geen nieuw UI-element**: geen weging-indicator, geen patroon-dashboard (bewust niet — de app moet voelen als een coach, niet als analytics)

---

## 6. Niet in scope (bewust)

- Geen AI-calls of externe API's
- Geen nieuwe Supabase tabellen of kolommen
- Geen weekreview-integratie
- Geen behandelaar-dashboard voor patronen
- Geen UI voor patroon-inzichten
- Geen offline-mode aanpassingen

Deze kunnen in toekomstige iteraties worden toegevoegd.
