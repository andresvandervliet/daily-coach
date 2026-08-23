# Rapport-verbetering: huiswerk, datumrange-fix, Overzicht opschonen

## Doel

Het printbare rapport (`buildRapport()` in `index.html`) is wat Pablo aan zijn psycholoog laat zien. Drie problemen:

1. Huiswerk dat de psycholoog meegeeft (bijv. "vraag je ouders naar hun jeugd") staat nergens in de app of het rapport.
2. De datumrange voor Dagboek en Patroonsamenvatting telt de dag van de vorige sessie zelf mee als "dag tussen sessies" — dat klopt niet.
3. De Overzicht-sectie toont een "Actieve doelen"-rij die weg mag.

## Deel 1: Datumrange-fix

`getTherapiePeriode()` (regel 1462) bepaalt `prev` als de datum van de laatst niet-overgeslagen sessie, en filtert dagen met `d >= prev`. Dat sluit de sessiedag zelf ten onrechte in.

**Fix**: zodra `prev` uit een echte sessiedatum komt (niet uit `getStartDate()`), één dag optellen:

```js
prev = parseDate(alleSessies[i].date);
prev.setDate(prev.getDate() + 1);
break;
```

De `!actief`-branch (nog geen sessies gelogd) blijft ongewijzigd — daar is `prev` de programmastartdatum, geen sessiedag.

Dit fixt automatisch zowel de Dagboek-sectie (regel 2734) als de Patroonsamenvatting (regel 2794), want beide gebruiken dezelfde `dayKeys`.

## Deel 2: Overzicht opschonen

In `buildRapport()` (regel 2692-2698), de regel

```js
<div class="rapport-row"><span class="rapport-label">Actieve doelen</span>...</div>
```

verwijderen. De rest van de Overzicht-sectie (Dag in programma, Fase, Therapiesessies gelogd) blijft. De aparte, uitgebreidere sectie "Actieve therapiedoelen & acties" (regel 2700) blijft ongewijzigd — die toont de doelen/acties zelf, niet alleen een aantal, en is niet wat Pablo bedoelde.

## Deel 3: Huiswerk-systeem

### Data model

Elke gelogde sessie (`_db.sessions`, item met `onderwerpen`/`inzichten`/`doelen`/`acties`, geschreven rond regel 2495-2501) krijgt vier nieuwe velden:

```js
{
  ...bestaande velden,
  huiswerk: '',        // de opdracht zelf, vrije tekst
  hw_a1: '',            // antwoord op "Heb je dit kunnen doen?"
  hw_a2: '',            // antwoord op "Hoe voelde het?"
  hw_a3: ''             // antwoord op "Wat viel je op?"
}
```

Geen aparte tabel, geen vragen opslaan (die zijn vast/hardcoded in de UI en het rapport) — alleen de tekst en de drie antwoorden.

### UI: sessie loggen

Het bestaande sessie-log-formulier (rond regel 2495, waar `sessieInzichten` etc. staan) krijgt een extra tekstveld "Huiswerk meegekregen", opgeslagen als `huiswerk` op hetzelfde sessie-object.

### UI: huiswerk beantwoorden

Op het Sessie-tabblad: zodra de meest recente gelogde sessie een niet-lege `huiswerk`-tekst heeft, toont een nieuwe kaart "Huiswerk" met:
- de huiswerktekst zelf, read-only
- drie tekstvelden, elk met zijn vaste vraag als label:
  1. "Heb je dit kunnen doen?"
  2. "Hoe voelde het?"
  3. "Wat viel je op?"

Deze velden autosaven op dezelfde manier als de rest van de app (geen aparte opslaan-knop), consistent met het bestaande patroon (zie `saveTrackerToelichting` als voorbeeld). De kaart verdwijnt vanzelf zodra er een nieuwere sessie gelogd wordt met eigen huiswerk (dan toont hij dát huiswerk in plaats daarvan).

### Rapport

Nieuwe sectie **"Huiswerk"** in `buildRapport()` (mode `'sessie'`), geplaatst direct na "Niet-doorgegane sessies" en vóór "Overzicht" — vroeg in het rapport, zodat de behandelaar het meteen ziet. Toont:
- de huiswerktekst
- de drie vragen met hun antwoorden (alleen ingevulde vragen tonen, zelfde patroon als de rest van het rapport)

Sectie wordt getoond op basis van de meest recent gelogde sessie (dezelfde sessie die `prev` in `getTherapiePeriode()` levert) — niet gefilterd via `dayKeys`, want de huiswerk-sessie zelf valt na de Deel 1-fix buiten die datumrange, terwijl het huiswerk wél relevant is voor de huidige periode. Sectie blijft verborgen als die sessie geen `huiswerk`-tekst heeft.

## Niet in scope

- Geen AI/LLM-integratie — de drie vervolgvragen zijn vast, niet content-afhankelijk. Bewuste keuze: geen nieuwe backend-koppeling, geen kosten, consistent met de rest van de app (die werkt overal met vaste vragenbanken, geen AI).
- Geen wijziging aan de bestaande "acties"-doelen-tags-flow.
- Geen wijziging aan PSYCHOLOGISCH PROFIEL of de bestaande NIET-DOORGEGANE SESSIES-sectie — die functioneren al zoals bedoeld.

## Testen

Handmatig, in de browser (geen testframework in dit project):
1. Sessie loggen met huiswerktekst → kaart verschijnt op Sessie-tabblad met de 3 vragen.
2. Antwoorden invullen → autosave, blijft staan na herladen.
3. Rapport genereren (mode `sessie`) → Huiswerk-sectie toont tekst + antwoorden, op de juiste plek.
4. Datumrange: dag van de sessie zelf verdwijnt uit Dagboek/Patroonsamenvatting; dagen erna blijven staan.
5. Overzicht: "Actieve doelen"-rij weg, rest van de rij blijft.
6. Print-preview (`@media print`) controleren — nieuwe sectie moet zich netjes gedragen met de bestaande print-CSS (`.rapport-section`, `.rapport-note`).
