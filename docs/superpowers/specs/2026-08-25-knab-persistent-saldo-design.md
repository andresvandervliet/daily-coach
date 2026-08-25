# Knab Enveloppen — Doorlopend Saldo & Stortingen-logboek

**Datum**: 2026-08-25
**Status**: Goedgekeurd

## Samenvatting

Knab-enveloppen (`gestort`, `knab_tx`) leven vandaag in de maand-gebonden `finance`-tabel, dus bij elke nieuwe maand resetten budget én uitgaven naar nul. De gebruiker wil dat niet: het saldo (positief of negatief) moet gewoon doorlopen, en elke maand vult hij het aan met een nieuwe storting vanuit zijn salaris — ongeacht of het huidige saldo positief of negatief is.

## Scope

Alleen de Knab-enveloppen en hun geld-tracking. Vaste lasten, Schulden en ANWB-betalingsregeling zijn al onafhankelijk hiervan en blijven ongewijzigd.

## Data model

### Huidig (maand-gebonden, in `finance`-tabel)

```js
// _db.fin.knab
{ id:1, naam:'Boodschappen · 3881', doel:'Boodschappen', gestort:260.35 }

// _db.fin.knab_tx (reset elke maand)
{ id:171..., knabId:1, bedrag:16.92, omschrijving:'action', datum:'2026-08-25' }
```

### Nieuw (persistent, in `_db.settings.profiel`)

```js
// _db.settings.profiel.knab — envelope-vorm, GEEN gestort-veld meer
{ id:1, naam:'Boodschappen · 3881', doel:'Boodschappen' }

// _db.settings.profiel.knab_tx — uitgaven, ongewijzigde vorm, nu persistent (all-time)
{ id:171..., knabId:1, bedrag:16.92, omschrijving:'action', datum:'2026-08-25' }

// _db.settings.profiel.knab_stortingen — NIEUW, spiegelbeeld van knab_tx
{ id:172..., knabId:1, bedrag:260.35, datum:'2026-08-25' }
```

`gestort` is niet langer een opgeslagen veld — het wordt berekend:

```js
function calcKnabGestort(knabId)   { return getKnabStortingen().filter(s => s.knabId === knabId).reduce((s,t) => s + t.bedrag, 0); }
function calcKnabUitgegeven(knabId) { return getKnabTx().filter(t => t.knabId === knabId).reduce((s,t) => s + t.bedrag, 0); } // laat mk-parameter vallen, is nu all-time
```

Saldo per envelop = `calcKnabGestort(id) - calcKnabUitgegeven(id)`.

## Getters/setters (vervangen `_saveFinance()` door `_saveSettings()`-pad)

- `getFinKnab()` → `_db.settings.profiel?.knab || FIN_DEFAULT_KNAB` (was: `_db.fin.knab`)
- `saveFinKnab(list)` → schrijft naar `_db.settings.profiel`, roept `_saveSettings()`
- `getKnabTx()` → `_db.settings.profiel?.knab_tx || []` — **signatuur wijzigt**: geen `mk`-parameter meer (was maand-gebonden, wordt all-time)
- `saveKnabTx(list)` → schrijft naar `_db.settings.profiel`, roept `_saveSettings()`
- `getKnabStortingen()` / `saveKnabStortingen(list)` — nieuw, zelfde patroon als knab_tx

`FIN_DEFAULT_KNAB` verliest het `gestort`-veld (envelope-vorm wordt `{id, naam, doel}`).

## Gedrag

### Nieuwe actie: "+ Storting" per envelop

Bedrag invoeren → `addKnabStorting(knabId, bedrag)`:
1. Push `{id, knabId, bedrag, datum: localDateStr()}` naar `knab_stortingen`
2. `Hoofdrekening -= bedrag`
3. Herbouw Knab-kaart + dashboard

### "Bewerken" (bestaand envelop met doel)

Alleen nog `naam`/`doel` corrigeren. Geen budget-invoerveld meer — budget is afgeleid, niet handmatig te zetten via deze knop.

### "Instellen" (envelop zonder doel, eerste keer)

Blijft één stap: doel + eerste bedrag invullen. Intern: `doel` opslaan via `saveFinKnab`, en het bedrag (indien > 0) via dezelfde route als "+ Storting" (push naar `knab_stortingen`, trek van Hoofdrekening af) — geen apart `gestort`-veld zetten.

### Maandtijdlijn (`buildFinTimeline`)

Huidig: itereert `knab.forEach(k => k.gestort > 0 → toon events)` — toont het volledige cumulatieve bedrag alsof het vandaag is gestort. **Fout zodra saldo doorloopt.**

Nieuw: itereer `getKnabStortingen().filter(s => s.datum.startsWith(finMaandKey()))` en toon één event per storting die deze maand daadwerkelijk heeft plaatsgevonden, met het echte bedrag en de echte datum van die storting (niet per se dag 24 — gebruik `new Date(s.datum).getDate()`).

### Reset-knop (`resetFinancien`)

Verwijder de regels `_db.fin.knab = ...` en `_db.fin.knab_tx = []` — Knab-data leeft niet meer in `_db.fin`, dus deze knop raakt het sowieso niet meer aan. Pas de bevestigingstekst aan: "Alle betaald-statussen worden op nul gezet. Vaste lasten, Knab-saldo, Schulden en Hoofdrekening blijven intact."

## Migratie (eenmalig, bij eerste load na deploy)

In `loadAllData()`: als `_db.settings.profiel.knab` nog niet bestaat, seed de persistente opslag vanuit de **huidige** maand se `_db.fin`-data (het "vanaf nu"-startpunt):

```js
if (!_db.settings.profiel?.knab) {
  const huidigeKnab = finRes.data?.knab || FIN_DEFAULT_KNAB;
  const huidigeTx   = finRes.data?.knab_tx || [];
  const stortingen  = huidigeKnab
    .filter(k => k.gestort > 0)
    .map(k => ({ id: Date.now() + k.id, knabId: k.id, bedrag: k.gestort, datum: localDateStr() }));
  _db.settings.profiel = {
    ...(_db.settings.profiel || {}),
    knab: huidigeKnab.map(({gestort, ...rest}) => rest),
    knab_tx: huidigeTx,
    knab_stortingen: stortingen
  };
  _saveSettings();
}
```

Dit is eenmalig — zodra `profiel.knab` bestaat, slaat deze stap zichzelf over.

## Niet in scope

- Geen reconstructie van maanden vóór vandaag — het doorlopende saldo begint bij wat er nú al staat
- Geen archivering/limiet op `knab_tx`/`knab_stortingen` — onbeperkte geschiedenis, past bij een persoonlijke app op deze schaal
