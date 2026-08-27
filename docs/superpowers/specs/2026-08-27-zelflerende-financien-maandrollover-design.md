# Zelflerende Financiën — Maandrollover, Geleerde Betaaldata & Knab-saldo Doorrol

**Datum**: 2026-08-27
**Status**: Goedgekeurd

## Samenvatting

De Financiën-tab begint nu elke maand vanaf nul: hardcoded `FIN_DEFAULT_VASTE` /
`FIN_DEFAULT_KNAB`, niks wordt meegenomen, niks wordt geleerd. Dit ontwerp maakt
het systeem doorlopend en zelflerend, met vier samenhangende veranderingen:

1. **Doorlopende vaste-lasten-lijst** — de lijst rolt door van maand tot maand;
   alleen de betaald-status reset.
2. **Betaald-status blijft staan binnen de maand** — geen wijziging nodig,
   bevestigd als vereiste.
3. **Zelflerende betaaldata** — de app leert per vaste last de echte betaaldag uit
   je historie (gemiddelde van de laatste 3 maanden) en gebruikt die voor de
   tijdlijn en voorspellingen.
4. **Knab-saldo doorrol** — bij "Salaris gestort" rolt het eindsaldo (+/−) van elke
   envelop door naar de nieuwe maand als aparte regel "Vorig saldo".

Alle bestaande dashboard-bedragen ("Al van rekening", "Komt nog deze maand", "Echt
restant", "Hoofdrekening / na alle lasten", Maandtijdlijn, Vaste lasten) moeten
kloppend en helder blijven door de maandwissel heen. Dat is de leidende eis.

## Datamodel

De `finance`-tabel heeft één rij per `user_id + month_key`. `vaste` en `knab` zijn
`jsonb`-arrays, dus nieuwe velden binnen de objecten vereisen **geen SQL-migratie**.

### Wijzigingen

| Veld | Nu | Nieuw |
|---|---|---|
| `knab[].vorigSaldo` | — | `number` (+/−) of `null`. Vastgezet bij "Salaris gestort". |

Er komt **geen** aparte idempotentie-vlag. De Knab-doorrol draait op het moment dat
`salaris_ontvangen` van `false` naar `true` gaat (zie Feature 4). Die boolean wordt
al gepersisteerd in de `finance`-tabel, dus de doorrol gebeurt automatisch precies
één keer per maand.

`betaald` blijft `{ "<id>": "YYYY-MM-DD" | null }` (ongewijzigd).
`vaste[]` structuur ongewijzigd (`{ id, naam, bedrag, dag }`).

Geleerde betaaldata worden **niet opgeslagen** — ze worden afgeleid bij het laden
uit de `betaald`-objecten van alle vorige maandrijen (zelfde patroon als
`_db.finHistory`).

## Feature 1: Doorlopende vaste-lasten-lijst

### Gedrag

Bij `loadAllData()`: als er nog geen `finance`-rij bestaat voor de huidige
`month_key`, wordt `_db.fin` niet meer geseed vanuit de hardcoded defaults maar
vanuit de **meest recente vorige maandrij**:

- `vaste` = diepe kopie van vorige maand `vaste`
- `knab` = diepe kopie van vorige maand `knab`, maar met `gestort: 0` en
  `vorigSaldo: null` per envelop (bedragen horen bij de nieuwe maand, saldo wordt
  pas bij "Salaris gestort" gezet — zie Feature 4)
- `knab_tx` = `[]`
- `betaald` = `{}`
- `salaris` = vorige maand `salaris` (laatst bekende bedrag als startwaarde)
- `salaris_ontvangen` = `false`, `salaris_datum` = `null`

Als er **geen enkele** vorige maandrij is (eerste gebruik ooit): val terug op
`FIN_DEFAULT_VASTE` / `FIN_DEFAULT_KNAB` zoals nu.

De vorige maandrijen worden al geladen in `loadAllData()` (query op
`month_key != mk`, met kolommen `month_key,salaris,vaste,knab,knab_tx,betaald,salaris_ontvangen`).
`vaste`, `knab` en `knab_tx` zitten er al in — geen extra kolommen nodig voor de seed.

### Gevolg voor het dashboard

Een verse maand: `betaald = {}` → "Al van rekening (0/N)" = € 0, "Komt nog deze
maand" = som van de hele lijst. Zodra je afvinkt schuift elk bedrag van "Komt nog"
naar "Al van rekening" en gaat het van de Hoofdrekening af — exact zoals het nu
binnen een maand al werkt via `toggleVasteBetaald()`.

### Historie blijft intact

Elke afgesloten maand houdt zijn eigen `vaste`-snapshot in zijn eigen rij. Het
maandoverzicht (`toonMaandOverzicht`) en `buildFinHistorie` blijven kloppen.

### Geraakte functies

- `loadAllData()` — nieuwe seed-logica bij ontbrekende maandrij
- Nieuw: `seedNieuweMaand(vorigeRij)` — bouwt het verse `_db.fin`-object

## Feature 2: Betaald-status blijft staan (bevestiging, geen code)

Werkt al: `betaald` wordt per maand opgeslagen in Supabase via `_saveFinance()`.
4 van 20 afgevinkt blijft 4 van 20 na herladen, inclusief de datums. Half
afgevinkt blijft half afgevinkt tot de gebruiker de rest doet. Expliciet
genoemd als vereiste; hier vastgelegd zodat een latere refactor het niet breekt.

## Feature 3: Zelflerende betaaldata

### Leren

Bij het laden: scan alle `finance`-rijen (huidige + vorige maanden). Voor elke
vaste last `id`, verzamel uit elke `betaald[id]` die een echte datum is (niet
`null`) de dag-van-de-maand (`new Date(datum).getDate()`).

`geleerdeDag[id]` = `Math.round(gemiddelde van de laatste 3 maanden)` waarin die
last is afgevinkt. Minder dan 2 datapunten → geen geleerde dag.

Opslag: afgeleid in het geheugen, bv. `_db.finGeleerdeDagen = { [id]: dag }`.
Geen tabelwijziging.

### Gebruik

`voorspeldeDag(v)` = `_db.finGeleerdeDagen[v.id] ?? v.dag`. Gebruik deze functie in
plaats van `v.dag` op deze plekken:

- `buildFinTimeline()` — sorteervolgorde en getoonde dag van nog-niet-betaalde
  vaste lasten
- eventuele toekomstige "afschrijving verwacht"-hints

De handmatig ingestelde `v.dag` blijft bestaan en bewerkbaar; hij is alleen niet
meer de enige bron voor voorspellingen.

### UI

In `buildFinVaste()`, onder elke vaste last die nog niet betaald is en waarvoor
een geleerde dag bestaat: een subtiele regel *"Meestal betaald rond de 3e"*
(hergebruik `.fin-betaald-datum` styling of een variant). Bij een betaalde last
blijft "Betaald op 5 sep" staan zoals nu.

### Geraakte functies

- `loadAllData()` of een nieuwe `berekenGeleerdeDagen()` aangeroepen na het laden
- Nieuw: `voorspeldeDag(v)`
- `buildFinTimeline()` — `v.dag` → `voorspeldeDag(v)`
- `buildFinVaste()` — geleerde-dag hint toevoegen

## Feature 4: Knab-saldo doorrol bij "Salaris gestort"

### Trigger

`markSalarisOntvangen()` (de "Ontvangen ✓"-knop). Roep `rolKnabSaldoDoor()` aan
**vóór** `setFinSalarisOntvangen()`, en alleen als `getFinSalarisOntvangen()` op dat
moment nog `false` is en er een vorige maandrij bestaat. Omdat
`salaris_ontvangen` daarna `true` is en gepersisteerd blijft, draait de doorrol
automatisch precies één keer per maand.

Voor elke envelop in `_db.fin.knab`, zoek de overeenkomende envelop in de vorige
maand op `doel` (naam). Bereken het **eindsaldo van de vorige maand**:

```
vorigEindsaldo = (vorigK.gestort || 0)
               + (vorigK.vorigSaldo || 0)
               - som(vorige maand knab_tx waar t.knabId === vorigK.id)
```

Zet dat als `k.vorigSaldo` op de envelop van de huidige maand. Daarna
`_saveFinance()`.

Idempotent via de `salaris_ontvangen`-transitie: zolang die `true` is, draait de
doorrol niet opnieuw. Alleen `resetFinancien()` (die zet de vlag terug én de
enveloppen naar defaults) leidt tot een nieuwe, correcte doorrol.

### Berekening per envelop (huidige maand)

```
beschikbaar = (k.gestort || 0) + (k.vorigSaldo || 0)
uitgegeven  = som(knab_tx van deze maand voor k.id)     // calcKnabUitgegeven, bestaand
saldo       = beschikbaar - uitgegeven
pct         = beschikbaar > 0 ? min(100, round(uitgegeven / beschikbaar * 100)) : 0
```

### UI in `buildFinKnab()`

```
Boodschappen · 3881
Nieuw budget        € 300,00
Vorig saldo         + € 40,00      (rood − € 20,00 bij tekort; regel verborgen als vorigSaldo null of 0)
─────────────────────────────
Beschikbaar         € 340,00
Uitgegeven          € 0,00
Saldo               € 340,00
```

Voortgangsbalk en "Saldo" rekenen vanaf **Beschikbaar**, niet vanaf kaal budget.

Vóór "Salaris gestort" (`vorigSaldo === null`): toon "Vorig saldo wordt berekend
zodra je salaris gestort is" in plaats van de Vorig-saldo-regel.

### Dashboard-consistentie (kritisch)

De regel **"Knab stortingen − € X"** op het dashboard blijft de som van
`k.gestort` (het nieuw gestorte bedrag), **niet** `beschikbaar`. Reden: het vorige
saldo stond al op de Knab-rekening, dat gaat niet nóg een keer van de
hoofdrekening af. Zo blijven "Al van rekening" en "Echt restant" exact kloppen.

`calcKnabStortingen()` blijft dus ongewijzigd. Alleen de envelop-weergave in
`buildFinKnab()` en de `saldo`/`pct`-berekening veranderen.

### Overschot blijft besteedbaar

Een positief vorig saldo (+€40) is gewoon beschikbaar om deze maand uit te geven
(zit in `beschikbaar`). Er wordt niks apart "vastgezet" als spaargeld. Een tekort
(−€20) verlaagt `beschikbaar` zodat je het deze maand inhaalt.

### Geraakte functies

- `markSalarisOntvangen()` — Knab-doorrol vastzetten (idempotent)
- Nieuw: `rolKnabSaldoDoor()` — de doorrol-berekening
- `buildFinKnab()` — Vorig saldo / Beschikbaar tonen, `saldo`/`pct` herrekenen
- `calcKnabUitgegeven()` — ongewijzigd
- `calcKnabStortingen()` — **ongewijzigd** (bewust)
- `_db.fin` seed (Feature 1) — `vorigSaldo: null` initialiseren

## Volgorde van implementatie

1. **Feature 1** (doorlopende lijst + seed) — fundament, de rest bouwt hierop
2. **Feature 3** (geleerde betaaldata) — leest historie, onafhankelijk van 4
3. **Feature 4** (Knab-doorrol) — heeft `vorigSaldo`-init uit Feature 1 nodig
4. **Feature 2** — alleen een regressietest / bevestiging

## Niet in scope

- Meerdere maanden tegelijk tonen
- Automatisch afschrijvingen detecteren uit banktransacties
- Push-/mailnotificaties bij aankomende afschrijvingen (de bestaande
  `finance-reminder.ps1` op de 22e blijft zoals hij is)
- Knab-overschot automatisch naar een spaardoel of de hoofdrekening boeken
- Wijzigen van de `VARIABELE_LASTEN`-flow
