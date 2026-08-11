# Pattern-Weighted Question Rotation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** De Daily Coach app transformeren van statische vraag-rotatie naar patroon-gewogen vraag-selectie met escalerende check-in diepte.

**Architecture:** Alles in `index.html` (single-file PWA). INTENTIONS en JOURNAL_PROMPTS worden objecten met tags. Nieuw `berekenPatroonGewichten()` functie analyseert `_db.days`. Check-in vragen escaleren op basis van de laatste 3 dagen. Geen schema-wijzigingen.

**Tech Stack:** Vanilla JS, Supabase (bestaand), geen nieuwe dependencies.

## Global Constraints

- Geen externe API-calls of AI-services
- Geen nieuwe Supabase tabellen of kolommen
- Alle logica draait client-side in de browser
- Bestaande `saveToday()` / `loadToday()` flow blijft intact
- `_db.days` structuur wordt uitgebreid met `_shown` veld, niet gewijzigd

---

### Task 1: INTENTIONS array omzetten naar objecten met tags

**Files:**
- Modify: `index.html:839-882` (INTENTIONS array)
- Modify: `index.html:1959` (intentie-selectie in `init()`)

**Interfaces:**
- Produces: `INTENTIONS` array van `{ t: string, tags: string[] }` objecten

- [ ] **Step 1: Vervang de INTENTIONS array**

Vervang de string-array (regel 839-882) door objecten. Elke intentie krijgt een `t` property (de tekst) en een `tags` array. Tags zijn uit de set: `pleasen`, `grenzen`, `humor`, `verdoving`, `eigenwaarde`, `verbinding`, `mannelijkheid`, `relatie`.

```js
const INTENTIONS = [
  { t: 'Vandaag spreek ik minstens een grens uit, hoe klein ook.', tags: ['grenzen'] },
  { t: 'Ik zit in het ongemak zonder het weg te lachen.', tags: ['humor', 'mannelijkheid'] },
  { t: 'Mijn behoeften zijn net zo geldig als die van een ander.', tags: ['eigenwaarde', 'pleasen'] },
  { t: 'Ik investeer vandaag tijd in iets van mezelf.', tags: ['eigenwaarde'] },
  { t: 'Als ik me disrespectful behandeld voel, zeg ik het.', tags: ['grenzen', 'mannelijkheid'] },
  { t: 'Zorgzaamheid begint bij mezelf.', tags: ['pleasen', 'eigenwaarde'] },
  { t: 'Ik hoef niets te bewijzen om hier te mogen zijn.', tags: ['eigenwaarde'] },
  { t: 'Ik observeer mezelf vandaag zonder oordeel.', tags: ['eigenwaarde'] },
  { t: 'Nabijheid is niet gevaarlijk. Ik oefen vandaag in aanwezig zijn.', tags: ['verbinding', 'relatie'] },
  { t: 'Ik kies voor eerlijkheid boven comfort.', tags: ['grenzen', 'humor'] },
  { t: 'Ik investeer alleen waar het wederzijds is.', tags: ['pleasen', 'relatie'] },
  { t: 'Emotionele kracht betekent niet alles alleen dragen.', tags: ['mannelijkheid', 'verbinding'] },
  { t: 'Vandaag leg ik humor neer en zeg ik wat ik werkelijk voel.', tags: ['humor'] },
  { t: 'Ik ben loyaal aan mezelf, eerst.', tags: ['pleasen', 'eigenwaarde'] },
  { t: 'Mijn autonomie verdwijnt niet als ik kwetsbaar ben.', tags: ['mannelijkheid', 'verbinding'] },
  { t: 'Ik kies vandaag een actie die mijn eigen groei dient.', tags: ['eigenwaarde'] },
  { t: 'Vertrouwen wordt opgebouwd met kleine, eerlijke momenten.', tags: ['verbinding', 'relatie'] },
  { t: 'Ik verlaat mezelf niet als eerste.', tags: ['pleasen'] },
  { t: 'De beste versie van mij is zacht en direct.', tags: ['mannelijkheid', 'grenzen'] },
  { t: 'Vandaag observeer ik wanneer ik wil krimpen en kies ik anders.', tags: ['pleasen', 'eigenwaarde'] },
  { t: 'Ik ben niet verantwoordelijk voor de emotionele stabiliteit van een ander.', tags: ['pleasen', 'grenzen'] },
  { t: 'Grenzen zijn geen muren. Ze zijn eerlijkheid.', tags: ['grenzen'] },
  { t: 'Ik spreek wat ik denk, kalm, direct, respectvol.', tags: ['grenzen', 'mannelijkheid'] },
  { t: 'Mijn aanwezigheid heeft waarde, ook zonder iets te geven.', tags: ['eigenwaarde', 'pleasen'] },
  { t: 'Vandaag vraag ik iemand iets over mezelf en laat ik het toe.', tags: ['verbinding', 'humor'] },
  { t: 'Ik laat iemand dichterbij dan gewoonlijk. Een stap.', tags: ['verbinding', 'relatie'] },
  { t: 'Als het ongemakkelijk voelt, is het waarschijnlijk het juiste.', tags: ['mannelijkheid'] },
  { t: 'Succes van mezelf is net zo belangrijk als steun aan een ander.', tags: ['eigenwaarde', 'pleasen'] },
  { t: 'Ik heb recht op mijn eigen richting.', tags: ['eigenwaarde'] },
  { t: 'Vandaag eindig ik de dag trots op een eerlijk moment.', tags: ['grenzen', 'humor'] },
  { t: 'Vandaag kies ik één concrete actie. Geen vijf plannen, één stap.', tags: ['eigenwaarde'] },
  { t: 'Ik hoef niet alles te willen. Vandaag doe ik één ding goed.', tags: ['eigenwaarde'] },
  { t: 'Wat ik uittel kost ook energie. Vandaag benoem ik wat er echt achter zit.', tags: ['verdoving', 'eigenwaarde'] },
  { t: 'Ik kan van mijn biologische moeder houden zonder haar vragen te beantwoorden.', tags: ['grenzen', 'relatie'] },
  { t: 'Mijn kinderen verdienen de warmte die ik zelf heb gemist. Vandaag geef ik dat bewust.', tags: ['verbinding'] },
  { t: 'Een echte vriendschap met een man begint met aanwezig zijn. Vandaag maak ik daar ruimte voor.', tags: ['verbinding', 'mannelijkheid'] },
  { t: 'Mijn lichaam heeft rust nodig. Slaap is geen luxe, het is onderhoud.', tags: ['verdoving'] },
  { t: 'Ik ben niet verantwoordelijk voor de reactie op mijn grens, alleen voor het uitspreken ervan.', tags: ['grenzen'] },
  { t: 'Twee werelden dragen is zwaar. Ik hoef ze niet te combineren, alleen te erkennen.', tags: ['eigenwaarde'] },
  { t: 'Ik ben anders dan mijn adoptieouders. Dat is geen verwijt, het is wie ik ben.', tags: ['eigenwaarde'] },
  { t: 'Ja zeggen terwijl ik nee bedoel kost mij meer dan de ander ooit ziet. Vandaag let ik op dat moment.', tags: ['pleasen', 'grenzen'] },
  { t: 'Ik hoef niet aardig te zijn om geaccepteerd te worden. Ik mag gewoon zijn.', tags: ['pleasen', 'eigenwaarde'] }
];
```

- [ ] **Step 2: Update de intentie-weergave in init()**

Regel 1959 gebruikt `INTENTIONS[(day-1) % INTENTIONS.length]` als string. Na de omzetting moet dit `.t` refereren. Dit wordt in Task 4 vervangen door de gewogen selectie, maar voor nu moet het niet breken:

```js
// Regel 1959: tijdelijke fix zodat de app niet breekt
document.getElementById('dailyIntention').textContent = INTENTIONS[(day-1) % INTENTIONS.length].t;
```

- [ ] **Step 3: Test dat de app laadt zonder errors**

Open de app in de browser. Controleer dat:
- De intentie van de dag correct getoond wordt (tekst, niet `[object Object]`)
- Geen console errors

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "refactor: INTENTIONS array naar objecten met patroon-tags"
```

---

### Task 2: JOURNAL_PROMPTS array omzetten naar objecten met tags

**Files:**
- Modify: `index.html:884-927` (JOURNAL_PROMPTS array)
- Modify: `index.html:1960` (prompt-selectie in `init()`)

**Interfaces:**
- Produces: `JOURNAL_PROMPTS` array van `{ t: string, tags: string[] }` objecten

- [ ] **Step 1: Vervang de JOURNAL_PROMPTS array**

```js
const JOURNAL_PROMPTS = [
  { t: 'Beschrijf een moment deze week waarbij je jezelf klein maakte voor de comfort van een ander. Wat was je werkelijke gevoel?', tags: ['pleasen'] },
  { t: 'Wie in je leven vraagt het meeste van je? Wat geef je terug en ontvang jij ook?', tags: ['pleasen', 'relatie'] },
  { t: 'Wat zou je zeggen als je wist dat de ander niet boos zou worden?', tags: ['grenzen', 'pleasen'] },
  { t: 'Schrijf over een moment waarbij je humor gebruikte terwijl je eigenlijk verdrietig of boos was.', tags: ['humor'] },
  { t: 'Stel je voor dat je over 5 jaar terugkijkt. Welk patroon van nu zou je het meest spijten?', tags: ['eigenwaarde', 'verdoving'] },
  { t: 'Wanneer heb jij voor het laatste iets gedaan puur voor jouw eigen groei?', tags: ['eigenwaarde'] },
  { t: 'Beschrijf je ideale versie van jezelf in een relatie. Waar verschilt die van wie je nu bent?', tags: ['relatie'] },
  { t: 'Schrijf een brief aan je twaalfjarige zelf. Wat wil je hem vertellen over erbij horen?', tags: ['eigenwaarde', 'verbinding'] },
  { t: 'Wat is het eerste dat je doet als iemand je teleurstelt? Is dat wat je zou willen doen?', tags: ['grenzen', 'pleasen'] },
  { t: 'Noem drie dingen die jij wil, niet voor een ander, niet voor bewijs. Alleen voor jou.', tags: ['eigenwaarde'] },
  { t: 'Wanneer voelde jij je voor het laatste echt gezien door iemand? Wat maakte dat anders?', tags: ['verbinding'] },
  { t: 'Wat is de angst achter jouw stilte als je een grens niet uitspreekt?', tags: ['grenzen', 'pleasen'] },
  { t: 'Beschrijf een situatie waarbij je je terugtrok. Wat had je willen zeggen?', tags: ['verbinding', 'grenzen'] },
  { t: 'Welke ambitie heb jij steeds opgeschoven? Wat is het werkelijke obstakel?', tags: ['eigenwaarde', 'verdoving'] },
  { t: 'Schrijf over een moment waarbij je trots was op jezelf, niet op wat je deed voor een ander.', tags: ['eigenwaarde'] },
  { t: 'Als je volledig zou slagen, wat verandert er dan? Wat verdwijnt er?', tags: ['eigenwaarde'] },
  { t: 'Beschrijf je ideale vriendschap. Hoe ver ben je daar nu van af?', tags: ['verbinding', 'mannelijkheid'] },
  { t: 'Welk verhaal vertel je jezelf over waarom je stilstaat? Wat klopt er misschien niet?', tags: ['verdoving', 'eigenwaarde'] },
  { t: 'Wanneer heb jij voor het laatste iemand verteld dat je je gekwetst voelde, direct, in het moment?', tags: ['humor', 'grenzen'] },
  { t: 'Wat zou het betekenen voor jou als je echt ertoe deed, zonder iets te bewijzen?', tags: ['eigenwaarde'] },
  { t: 'Schrijf over een relatie waarbij je meer gaf dan je ontving. Hoe lang duurde het voordat je het erkende?', tags: ['pleasen', 'relatie'] },
  { t: 'Wat doet de gedachte aan volledige kwetsbaarheid met je? Schrijf het zo eerlijk als je kunt.', tags: ['mannelijkheid', 'humor'] },
  { t: 'Beschrijf een moment waarbij je je eigen intuïtie negeerde. Wat vertelde die intuïtie je?', tags: ['grenzen'] },
  { t: 'Wie zou verbaasd zijn als je je werkelijke mening gaf? Wat houdt je tegen?', tags: ['grenzen', 'pleasen'] },
  { t: 'Schrijf over iets wat je al lang wil maar steeds uitstelt. Wat is de eerste, kleinste stap?', tags: ['verdoving', 'eigenwaarde'] },
  { t: 'Als zorg voor anderen energie kost: hoeveel energie hou jij over voor jezelf? Is dat duurzaam?', tags: ['pleasen'] },
  { t: 'Wat betekent assertief zijn voor jou? Waar associeer je het mee?', tags: ['grenzen', 'mannelijkheid'] },
  { t: 'Beschrijf een moment waarbij je je echt vrij voelde. Wat was er anders?', tags: ['eigenwaarde'] },
  { t: 'Welke leugen vertel je jezelf het vaakst? Schrijf hem op en weerleg hem.', tags: ['verdoving', 'eigenwaarde'] },
  { t: 'Schrijf een brief aan de man die je wilt zijn. Wat vraagt hij van de man die je nu bent?', tags: ['mannelijkheid'] },
  { t: 'Wat heb je vandaag uitgesteld? Schrijf de echte reden op, niet de officiële.', tags: ['verdoving'] },
  { t: 'Je hebt dromen: motorrijbewijs, parachutespringen, alleen op vakantie. Kies er één. Wat is letterlijk de eerste stap die je deze week kunt zetten?', tags: ['eigenwaarde'] },
  { t: 'Schrijf over je biologische moeder. Wat voel je als je aan haar denkt? Wat wil jij, los van wat zij van je wil?', tags: ['relatie', 'grenzen'] },
  { t: 'Wat betekent het voor jou om twee werelden te dragen: Nederland en Colombia? Wanneer voelt dat het zwaarst?', tags: ['eigenwaarde'] },
  { t: 'Hoe ben jij als vader vergeleken met hoe je bent opgevoed? Wat doe je al anders dan je adoptieouders?', tags: ['verbinding'] },
  { t: 'Wanneer heb jij voor het laatste iets gedaan met een man, puur als vriend? Niet als partner, niet als collega. Wat mist er in die vriendschappen?', tags: ['verbinding', 'mannelijkheid'] },
  { t: 'Je weet wat je nodig hebt: sporten, slaap, tijd voor jezelf. Hoe vaak lukt dat echt? Wat staat het in de weg?', tags: ['verdoving'] },
  { t: 'Beschrijf een moment waarbij je te laat je grens aangaf. Wanneer wist je het eigenlijk al? Wat hield je tegen?', tags: ['grenzen', 'pleasen'] },
  { t: 'Je wilt te veel tegelijk. Schrijf alles op wat je wilt. Streep dan alles door behalve één. Hoe voelt dat?', tags: ['eigenwaarde'] },
  { t: 'Je adoptieouders houden van je maar kunnen het niet goed laten zien. Wat heb je als kind het meest gemist? Wat heb je inmiddels geaccepteerd?', tags: ['verbinding', 'relatie'] },
  { t: 'Wanneer heb jij vandaag ja gezegd terwijl je nee bedoelde? Wat was de angst achter dat ja?', tags: ['pleasen', 'grenzen'] },
  { t: 'Voor wie doe jij dingen die je eigenlijk niet wilt doen? Wat denk je dat er gebeurt als je nee zegt?', tags: ['pleasen', 'grenzen'] }
];
```

- [ ] **Step 2: Update de prompt-weergave in init()**

```js
// Regel 1960: tijdelijke fix
document.getElementById('journalPrompt').textContent = JOURNAL_PROMPTS[(day-1) % JOURNAL_PROMPTS.length].t;
```

- [ ] **Step 3: Test dat de app laadt zonder errors**

Open de app in de browser. Controleer dat:
- De journalprompt correct getoond wordt (tekst, niet `[object Object]`)
- Geen console errors

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "refactor: JOURNAL_PROMPTS array naar objecten met patroon-tags"
```

---

### Task 3: Weging-algoritme en vraag-selectie

**Files:**
- Modify: `index.html` — nieuw blok JS invoegen na de PHASES constante (na regel ~933)

**Interfaces:**
- Consumes: `_db.days` object (bestaand), `INTENTIONS[].tags`, `JOURNAL_PROMPTS[].tags`
- Produces: `berekenPatroonGewichten()` → `{ pleasen: number, grenzen: number, ... }`, `kiesGewogenVraag(pool, gewichten)` → `{ t: string, tags: string[], _idx: number }`

- [ ] **Step 1: Schrijf de `berekenPatroonGewichten` functie**

Voeg in na de PHASES constante (~regel 933):

```js
function berekenPatroonGewichten() {
  const TAGS = ['pleasen','grenzen','humor','verdoving','eigenwaarde','verbinding','mannelijkheid','relatie'];
  const gew = {};
  TAGS.forEach(t => gew[t] = 0);

  const keys = Object.keys(_db.days).sort().slice(-7);
  if (keys.length < 2) return null;

  const streak = {};
  TAGS.forEach(t => streak[t] = 0);

  keys.forEach(k => {
    const d = _db.days[k];
    const q1 = parseInt(d.q1) || 0, q2 = parseInt(d.q2) || 0, q3 = parseInt(d.q3) || 0;
    const t1 = parseInt(d.t1) || 0, t2 = parseInt(d.t2) || 0, t4 = parseInt(d.t4) || 0;

    if (q1 && q1 <= 2) { gew.pleasen++; gew.eigenwaarde++; }
    if (q2 && q2 <= 2) { gew.humor++; gew.verbinding++; }
    if (q3 && q3 <= 2) { gew.grenzen++; gew.pleasen++; }
    if (t1 && t1 <= 2) { gew.eigenwaarde++; }
    if (t2 && t2 <= 2) { gew.verbinding++; }
    if (t4 && t4 >= 3) { gew.verdoving++; }
  });

  // Consecutieve versterking
  TAGS.forEach(tag => {
    let run = 0, maxRun = 0;
    keys.forEach(k => {
      const d = _db.days[k];
      const q1 = parseInt(d.q1)||0, q2 = parseInt(d.q2)||0, q3 = parseInt(d.q3)||0;
      const t1 = parseInt(d.t1)||0, t2 = parseInt(d.t2)||0, t4 = parseInt(d.t4)||0;
      let hit = false;
      if (tag === 'pleasen')    hit = (q1 && q1<=2) || (q3 && q3<=2);
      if (tag === 'grenzen')    hit = (q3 && q3<=2);
      if (tag === 'humor')      hit = (q2 && q2<=2);
      if (tag === 'verdoving')  hit = (t4 && t4>=3);
      if (tag === 'eigenwaarde')hit = (q1 && q1<=2) || (t1 && t1<=2);
      if (tag === 'verbinding') hit = (q2 && q2<=2) || (t2 && t2<=2);
      run = hit ? run + 1 : 0;
      maxRun = Math.max(maxRun, run);
    });
    if (maxRun >= 3) gew[tag] *= 2;
  });

  gew.mannelijkheid = Math.max(gew.mannelijkheid, 1);
  gew.relatie = Math.max(gew.relatie, 1);

  return gew;
}
```

- [ ] **Step 2: Schrijf de `kiesGewogenVraag` functie**

Voeg direct daarna in:

```js
function kiesGewogenVraag(pool, gewichten) {
  const scored = pool.map((item, idx) => {
    const s = item.tags.reduce((sum, tag) => sum + (gewichten[tag] || 0), 0);
    return { ...item, _idx: idx, _score: Math.max(s, 1) };
  });
  const totaal = scored.reduce((s, v) => s + v._score, 0);
  let r = Math.random() * totaal, lopend = 0;
  for (const v of scored) {
    lopend += v._score;
    if (lopend >= r) return v;
  }
  return scored[scored.length - 1];
}
```

- [ ] **Step 3: Test de functies in de browser console**

Open de app, open devtools console, en voer uit:

```js
console.log(berekenPatroonGewichten());
console.log(kiesGewogenVraag(INTENTIONS, berekenPatroonGewichten() || {}));
```

Verwacht: een object met tag-gewichten, en een intentie-object met `_idx` en `_score`.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: berekenPatroonGewichten en kiesGewogenVraag functies"
```

---

### Task 4: Escalerende check-in vragen

**Files:**
- Modify: `index.html` — nieuw blok JS invoegen na de functies uit Task 3
- Modify: `index.html:504-513` — check-in HTML (dynamisch maken)

**Interfaces:**
- Consumes: `_db.days` object
- Produces: `CHECK_IN_ESCALATIE` constante, `bepaalCheckInNiveaus()` → `[0|1|2, 0|1|2, 0|1|2]`

- [ ] **Step 1: Voeg de CHECK_IN_ESCALATIE constante toe**

```js
const CHECK_IN_ESCALATIE = [
  [
    'Heb ik mezelf vandaag verlaten om een ander te behagen?',
    'Wat heb ik vandaag weggegeven dat ik eigenlijk voor mezelf wilde houden?',
    'Ik zeg dat het goed gaat. Waar zit de persoon die ik probeer te overtuigen — in de spiegel of tegenover me?'
  ],
  [
    'Was er een moment waarbij ik humor gebruikte om een echt gevoel te vermijden?',
    'Welk gevoel zat er onder de grap die ik maakte?',
    'Als humor mijn schild is — tegen wie verdedig ik me eigenlijk? De ander, of mezelf?'
  ],
  [
    'Was er een grens die ik had moeten uitspreken maar niet heb uitgesproken?',
    'Welke grens ken ik wel, maar voer ik niet uit — en wat kost me dat?',
    'Ik zeg dat ik grenzen stel. Noem de laatste keer dat iemand boos op me werd omdat ik nee zei.'
  ]
];
```

- [ ] **Step 2: Schrijf de `bepaalCheckInNiveaus` functie**

```js
function bepaalCheckInNiveaus() {
  const keys = Object.keys(_db.days).sort();
  const laatste3 = keys.slice(-3);
  if (laatste3.length < 3) return [0, 0, 0];

  const gisteren = keys[keys.length - 1];
  const gisterenData = _db.days[gisteren];

  return [0, 1, 2].map(qi => {
    // Reset na confronterende vraag
    if (gisterenData._shown && gisterenData._shown.q_levels && gisterenData._shown.q_levels[qi] === 2) return 0;

    const field = 'q' + (qi + 1);
    const scores = laatste3.map(k => parseInt(_db.days[k][field]) || 0);

    if (scores.every(s => s >= 3)) return 1;
    if (scores.every(s => s > 0 && s <= 2)) return 2;
    return 0;
  });
}
```

- [ ] **Step 3: Maak de check-in vragen dynamisch in de HTML**

Vervang de hardcoded vragen in de HTML (regels 503-514). De `<div class="checkin-question">` teksten worden nu via JS gezet. Vervang:

```html
<div class="section">
  <div class="section-title">Dagelijkse check-in</div>
  <div class="card">
    <div class="checkin-question" id="cq1"></div>
    <textarea id="q1" placeholder="Eerlijk antwoord..." rows="3"></textarea>
  </div>
  <div class="card">
    <div class="checkin-question" id="cq2"></div>
    <textarea id="q2" placeholder="Eerlijk antwoord..." rows="3"></textarea>
  </div>
  <div class="card">
    <div class="checkin-question" id="cq3"></div>
    <textarea id="q3" placeholder="Eerlijk antwoord..." rows="3"></textarea>
  </div>
  <div id="therapyQuestionsContainer"></div>
</div>
```

- [ ] **Step 4: Test in de browser**

Open de app. Controleer dat:
- De check-in vragen correct getoond worden (basis-niveau als er weinig data is)
- De textareas werken nog
- Geen console errors

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: escalerende check-in vragen met 3 diepteniveaus"
```

---

### Task 5: Integratie in init() en saveToday()

**Files:**
- Modify: `index.html:1935-1986` (`init()` functie)
- Modify: `index.html:2493-2513` (`saveToday()` functie)

**Interfaces:**
- Consumes: `berekenPatroonGewichten()`, `kiesGewogenVraag()`, `bepaalCheckInNiveaus()`, `CHECK_IN_ESCALATIE`
- Produces: `_todayShown` globale variabele met geselecteerde indices en niveaus

- [ ] **Step 1: Vervang de vraag-selectie in init()**

Vervang regels 1959-1960 en voeg check-in niveau-setting toe. Voeg ook een globale variabele toe voor de `_shown` data:

```js
// Na de fase-berekening in init(), vervang regels 1959-1960:
const gewichten = berekenPatroonGewichten();
let chosenIntention, chosenJournal;

if (gewichten) {
  chosenIntention = kiesGewogenVraag(INTENTIONS, gewichten);
  chosenJournal = kiesGewogenVraag(JOURNAL_PROMPTS, gewichten);
} else {
  const idx = (day - 1) % INTENTIONS.length;
  chosenIntention = { ...INTENTIONS[idx], _idx: idx };
  const jdx = (day - 1) % JOURNAL_PROMPTS.length;
  chosenJournal = { ...JOURNAL_PROMPTS[jdx], _idx: jdx };
}

document.getElementById('dailyIntention').textContent = chosenIntention.t;
document.getElementById('journalPrompt').textContent = chosenJournal.t;

// Check-in escalatie
const qLevels = bepaalCheckInNiveaus();
document.getElementById('cq1').textContent = CHECK_IN_ESCALATIE[0][qLevels[0]];
document.getElementById('cq2').textContent = CHECK_IN_ESCALATIE[1][qLevels[1]];
document.getElementById('cq3').textContent = CHECK_IN_ESCALATIE[2][qLevels[2]];

// Bewaar voor saveToday()
window._todayShown = {
  intention: chosenIntention._idx,
  journal: chosenJournal._idx,
  q_levels: qLevels
};
```

- [ ] **Step 2: Voeg _shown toe aan saveToday()**

In `saveToday()` (regel ~2497-2509), voeg `_shown` toe aan het data object:

```js
// Na de regel: day: getDayNumber(), ...tqData
// Voeg toe:
_shown: window._todayShown || {}
```

Het `data` object wordt dan:

```js
const data = {
  date:    new Date().toLocaleDateString('nl-NL',{weekday:'long',day:'numeric',month:'long'}),
  journal: document.getElementById('journalAnswer').value,
  q1: document.getElementById('q1').value,
  q2: document.getElementById('q2').value,
  q3: document.getElementById('q3').value,
  t1: trackerState.t1, t2: trackerState.t2, t3: trackerState.t3, t4: trackerState.t4,
  t1_toel: document.getElementById('t1-toelichting')?.value||'',
  t2_toel: document.getElementById('t2-toelichting')?.value||'',
  t3_toel: document.getElementById('t3-toelichting')?.value||'',
  t4_toel: document.getElementById('t4-toelichting')?.value||'',
  day: getDayNumber(), ...tqData,
  _shown: window._todayShown || {}
};
```

- [ ] **Step 3: Controleer dat loadToday() niet breekt**

`loadToday()` (regel ~2519) laadt `_db.days[getTodayKey()]` en zet velden. Het `_shown` veld wordt niet gelezen door loadToday — het wordt gewoon mee opgeslagen en genegeerd bij het laden. Geen wijziging nodig.

- [ ] **Step 4: Test de volledige flow in de browser**

1. Open de app
2. Controleer: intentie, journal prompt, en check-in vragen laden correct
3. Vul een check-in in en klik opslaan
4. Open devtools → console → `console.log(_db.days)` — controleer dat `_shown` aanwezig is
5. Verifieer dat de data correct naar Supabase gaat (Network tab, check de upsert payload)

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: patroon-gewogen vraag-selectie en _shown tracking in saveToday"
```

---

### Task 6: Archief en weekrapport compatibiliteit

**Files:**
- Modify: `index.html:2405-2415` (weekrapport CQ referenties)

**Interfaces:**
- Consumes: `CHECK_IN_ESCALATIE`, `_db.days[].q_levels`

- [ ] **Step 1: Controleer archief-weergave**

Het archief (regel ~2560-2564) toont `d.q1`, `d.q2`, `d.q3` als tekst-antwoorden. Dit zijn de gebruiker-ingevulde antwoorden, niet de vraagteksten. Die hoeven niet te veranderen.

- [ ] **Step 2: Controleer weekrapport**

Het weekrapport (regel ~2405-2415) heeft hardcoded labels:

```js
{ key:'q2', label:'Humor gebruikt om een echt gevoel te vermijden?' },
{ key:'q3', label:'Grens die ik had moeten uitspreken maar niet heb uitgesproken?' }
```

Deze labels zijn samenvattingen, niet de volledige vragen. Ze blijven werken ongeacht het escalatieniveau. Geen wijziging nodig.

- [ ] **Step 3: Test archief en weekrapport**

1. Open de app, ga naar het archief
2. Controleer dat bestaande entries correct getoond worden
3. Open weekrapport — controleer dat check-in data nog klopt

- [ ] **Step 4: Commit (alleen als er wijzigingen waren)**

Als alles werkt zonder wijzigingen: skip deze commit.

---

### Task 7: Eindtest en push

**Files:**
- Geen wijzigingen, alleen testen

- [ ] **Step 1: Volledige test op desktop**

1. Open de app in de browser
2. Check: intentie laadt (niet `[object Object]`)
3. Check: journal prompt laadt
4. Check: check-in vragen laden op correct niveau
5. Vul alles in, sla op
6. Herlaad de pagina — data is behouden
7. Ga naar archief — entries kloppen
8. Ga naar weekrapport — data klopt
9. Geen console errors

- [ ] **Step 2: Test met lege data**

1. Eerste keer gebruik (geen `_db.days` data)
2. Intentie en prompt moeten random gekozen worden (fallback)
3. Check-in vragen moeten op basis-niveau staan

- [ ] **Step 3: Push naar GitHub**

```bash
git push origin master
```

Netlify deployt automatisch.

- [ ] **Step 4: Test op de live URL**

Open `https://merry-kelpie-eec436.netlify.app` en herhaal de checks uit Step 1.
