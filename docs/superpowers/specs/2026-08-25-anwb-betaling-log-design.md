# ANWB Betalingsregeling — Hoofdrekening-koppeling & Betaal-geschiedenis

**Datum**: 2026-08-25
**Status**: Goedgekeurd

## Samenvatting

De Betalingsregeling ANWB Energie-sectie (4 termijnen) mist twee dingen die vaste lasten en Knab-enveloppen al wel hebben:

1. Een afgevinkte termijn trekt het bedrag niet af van de Hoofdrekening.
2. Er is geen geschiedenis zichtbaar van welke termijnen al betaald zijn en wanneer.

## Scope

Alleen de ANWB-termijnen. ICS/Klarna (in de Schulden-sectie) blijven een handmatig aan te passen bedrag zonder eigen betaal-geschiedenis of Hoofdrekening-koppeling — expliciet buiten scope voor nu.

## Data model

Huidig termijn-object (`FIN_DEFAULT_ANWB_REGELING`, opgeslagen in `_db.settings.profiel.anwbRegeling`):

```js
{ id:1, bedrag:105, datum:'2026-08-25', betaald:false }
```

Nieuw veld toegevoegd:

```js
{ id:1, bedrag:105, datum:'2026-08-25', betaald:true, betaaldOp:'2026-08-25' }
```

`betaaldOp` is de datum (YYYY-MM-DD) waarop de gebruiker de termijn heeft afgevinkt — hiermee is in welke maand een termijn is afgeschreven altijd terug te zien, zonder een apart logboek nodig te hebben (er zijn nooit meer dan 4 termijnen, dus een losse transactie-array zoals bij Knab is hier overkill).

## Gedrag

### Termijn afvinken (`toggleAnwbBetaald`)

1. `betaald = true`, `betaaldOp = localDateStr()` (vandaag)
2. `Hoofdrekening -= termijn.bedrag`
3. Termijn verdwijnt uit de "open" lijst (bestaand gedrag blijft)
4. Termijn verschijnt in de nieuwe "Betaald"-lijst

### Termijn terugzetten naar onbetaald

1. `betaald = false`, `betaaldOp = null`
2. `Hoofdrekening += termijn.bedrag`
3. Termijn verschijnt weer in de "open" lijst
4. Termijn verdwijnt uit de "Betaald"-lijst

Dit vereist een nieuwe UI-actie om een betaalde termijn weer te kunnen uitvinken (bestaat nu nog niet — betaalde termijnen worden puur gefilterd en zijn niet meer aanklikbaar).

## UI

Onder de bestaande open-termijnen-lijst (of onder "Alle termijnen betaald") komt een compacte sectie:

```
Betaald
25 aug 2026 · € 105,00   [uitvink-knop]
```

Stijl consistent met bestaande `fin-list-item` / `fin-betaald-datum` klassen — geen nieuwe CSS nodig.

## Geraakte functies

- `toggleAnwbBetaald(id)` — uitbreiden met Hoofdrekening-aftrek, `betaaldOp` zetten, en toggle-richting (nu alleen `betaald=true`, moet bidirectioneel worden)
- `buildFinAnwbRegeling()` — render ook de "Betaald"-lijst met een uitvink-knop per item
- `FIN_DEFAULT_ANWB_REGELING` — geen wijziging nodig (nieuwe velden zijn optioneel/afwezig totdat een termijn wordt afgevinkt)

## Niet in scope

- ICS/Klarna-schulden krijgen geen eigen betaal-geschiedenis of Hoofdrekening-koppeling
- Geen apart logboek/transactie-array — de datum leeft op het termijn-object zelf
