# Vaste Lasten Flow — Betaaldatum, Knab Stortingen & Maandtijdlijn

**Datum**: 2026-08-09
**Status**: Goedgekeurd

## Samenvatting

Drie verbeteringen aan de Financiën tab:

1. **Betaaldatum** bij elke vaste last (niet alleen een vinkje)
2. **Knab stortingen** meetellen als uitgave van de hoofdrekening
3. **Maandtijdlijn** — chronologisch overzicht van de hele maand

## Feature 1: Betaaldatum bij vaste lasten

### Huidig data model

```
lc_fin_betaald_2026-08 = [1, 3, 7]
```

Array van IDs — geen datum informatie.

### Nieuw data model

```json
lc_fin_betaald_2026-08 = { "1": "2026-08-01", "3": "2026-08-05", "7": "2026-08-09" }
```

Object met ID als key en betaaldatum (YYYY-MM-DD string) als value.

### Migratie

Bij eerste load: als de opgeslagen waarde een array is (oud formaat), migreer naar object met `null` als datum voor elk ID. Eenmalig, automatisch.

### UI

- Checkmark toggle blijft ongewijzigd
- Handmatig markeren → slaat vandaag als datum op
- Auto-markeer op afschrijfdag → slaat die dag als datum op
- Onbetaald maken → verwijdert de key uit het object
- Onder elke betaalde vaste last verschijnt: "Betaald op 5 aug" (of "Betaald" als datum `null`)

### Geraakte functies

- `getFinBetaald()` → retourneert nu een object i.p.v. array
- `saveFinBetaald()` → slaat object op
- `isVasteBetaald(id)` → checkt of key bestaat in object
- `toggleVasteBetaald(id)` → set datum of verwijder key
- `finAutoMarkeer()` → set afschrijfdag als datum
- `buildFinVaste()` → toont datum onder elke betaalde item

## Feature 2: Knab stortingen als hoofdrekening-uitgave

### Logica

Elke Knab envelop met `gestort > 0` telt als een uitgave van de hoofdrekening, mits salaris als ontvangen is gemarkeerd.

### Dashboard berekening

- **Al van rekening** = betaalde vaste lasten + Knab stortingen (als salaris ontvangen)
- **Komt nog** = onbetaalde vaste lasten
- **Nu vrij te besteden** = salaris - al van rekening
- **Echt restant** = salaris - alles (betaald + onbetaald + variabel + Knab stortingen)

### UI

Extra regel in het dashboard:

```
Al van rekening (10/20)      - € 1.293,67
Knab stortingen              - € 470,00
```

### Geraakte functies

- `buildFinDashboard()` → extra regel voor Knab stortingen, aangepaste berekeningen
- `calcKnabStortingen()` → nieuw: som van alle `gestort` bedragen van actieve enveloppen

## Feature 3: Maandtijdlijn

### Plek

Nieuwe sectie in de Financiën tab, direct onder het dashboard en vóór de Knab enveloppen.

### Inhoud

Chronologische lijst van events:

```
24 aug   ✓  Salaris ontvangen              + € 3.700,00
24 aug   ✓  → Knab Benzine                 - € 120,00
24 aug   ✓  → Knab Boodschappen            - € 300,00
24 aug   ✓  → Knab Kleding                 - € 50,00
25 aug   ✓  Hypotheek — Rabobank           - € 472,00
27 aug   ✓  Energie & Stroom — ANWB        - € 162,00
 1 sep   ○  Zorgverzekering                - € 142,00
 1 sep   ○  Internet — KPN                 - € 54,99
```

### Regels

- Groene checkmark (✓) = betaald, getoond op de betaaldatum
- Open cirkel (○) = nog niet betaald, getoond op de verwachte afschrijfdag
- Salaris verschijnt op de salarisdag (als ontvangen gemarkeerd)
- Knab stortingen verschijnen op de salarisdag met "→" prefix (alleen als salaris ontvangen)
- Vaste lasten zonder afschrijfdag (`dag: null`) staan onderaan als "Datum onbekend"
- Alleen de huidige maand

### Data

Geen nieuwe opslag. Tijdlijn wordt realtime opgebouwd uit:
- Salaris ontvangen status
- Betaaldatums vaste lasten (feature 1)
- Knab gestort bedragen (bestaand)
- Vaste lasten met afschrijfdag (bestaand)

### Geraakte functies

- `buildFinTimeline()` → nieuw: bouwt de tijdlijn HTML
- `buildFinancieel()` → roept `buildFinTimeline()` aan

## Scope

- Feature 1 kan onafhankelijk gebouwd worden (data model wijziging + migratie)
- Feature 2 hangt niet af van feature 1
- Feature 3 hangt af van feature 1 (betaaldatums nodig voor de tijdlijn)
- Volgorde: feature 1 → feature 2 → feature 3

## Niet in scope

- Meerdere maanden tegelijk tonen
- Automatisch afschrijfdagen detecteren
- Notificaties bij aankomende afschrijvingen
