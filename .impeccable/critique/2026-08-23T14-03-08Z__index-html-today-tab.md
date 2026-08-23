---
target: index.html today tab
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 2
timestamp: 2026-08-23T14-03-08Z
slug: index-html-today-tab
---
Method: dual-agent (A: design-review sub-agent · B: detector-evidence sub-agent)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2/4 | Save toast fires unconditionally before the Supabase write resolves — a failed save shows "✓ Opgeslagen" anyway |
| 2 | Match Between System & Real World | 4/4 | Solid — authentic, specific Dutch therapeutic language throughout |
| 3 | User Control and Freedom | 3/4 | Good exits on the session banner; no undo once a tracker/journal field autosaves over a previous value |
| 4 | Consistency and Standards | 2/4 | Close-session banner renders 32px narrower than cards below it (318px vs 350px); today-tab textareas skip the `form-label` pattern used correctly elsewhere in the app |
| 5 | Error Prevention | 3/4 | Score/toggle inputs are button-constrained, low mis-entry risk |
| 6 | Recognition Rather Than Recall | 2/4 | Zero headings inside the tab; live detector independently confirmed 8 functional-text instances below an 11px floor (day-badge label 9px, goals-banner label 10px, all 6 bottom-nav labels 10px) rendered on this exact tab |
| 7 | Flexibility and Efficiency of Use | 1/4 | One fixed linear path, no shortcuts, no way to skip a question |
| 8 | Aesthetic and Minimalist Design | 3/4 | Clean and restrained; docked for banner-stacking/misalignment noise at the top |
| 9 | Error Recovery | 1/4 | No error path exists for the one failure mode that matters most (failed remote save) |
| 10 | Help and Documentation | 2/4 | Nice one-time empty-state message; nothing explains the escalating-question mechanic |
| **Total** | | **23/40** | **Acceptable — real, fixable gaps, not a redesign** |

## Design Specificity Verdict

**LLM assessment**: The content layer is genuinely, unmistakably authored for one specific person — the intention/prompt library references real biographical material (adoption, biological mother, raising kids differently than he was raised, "two worlds" Nederland/Colombia), and the check-in questions escalate based on a real pattern-detection mechanism reading the user's own last 3-7 days of data. No generic journaling template produces that. The interaction shell is closer to well-executed generic-good-design (segmented controls, cards, one gold accent) — which is *correct* per DESIGN.md's "feels native, not branded" goal. The one real specificity failure: a streak counter (fire/lightning/sparkle emoji, 7/3/1-day tiers) renders in the header on every visit with history — directly contradicting DESIGN.md's explicit "no streaks, badges, confetti" rule. The product's own governing document and its shipped code disagree with each other on this one point.

**Deterministic scan**: The bundled CLI detector ran in degraded mode (missing HTML/CSS parser dependencies — a tool-environment limitation, not a project issue) and returned 157 advisory findings via regex matching alone: 87 font-size, 47 color, 23 border-radius values outside the DESIGN.md token scale. ~104 of these live in the shared `<style>` block that also styles the today tab; 0 are inline styles directly inside the today tab's own markup. Several — particularly the `@media print` report-styling colors (`#999`, `#fff`, `#B89040`, `#ddd`) — are almost certainly false positives (a printed PDF legitimately uses a different, print-safe palette than the on-screen dark theme). Treat the 157 count as an upper-bound backlog signal for a future `/impeccable polish` pass, not confirmed drift.

Separately, the **browser-injected live detector ran cleanly (not degraded)** and found 9 concrete anti-patterns, 8 of which render directly on the today tab: the 9-10px functional-text instances above, all independently re-measured for contrast (5.86:1–8.46:1 — all comfortably pass WCAG AA; this is a type-scale violation, not a contrast problem).

## Overall Impression

The bones are good and the product-specific mechanic (adaptive question escalation) is genuinely well-built — this isn't a case of generic design needing a personality transplant. What's actually wrong is more mundane and more fixable: a save confirmation that can lie, one UI element (the streak bar) that contradicts the product's own written design principle, and a placeholder color that's nearly invisible on exactly the field where the user elaborates on their hardest tracker answers. None of these require rethinking the product — they're bugs in service of a good idea, not evidence the idea is wrong.

## What's Working

- **The adaptive escalation logic** (question intensity scaling with detected 7-day patterns) is a real, bespoke mechanic no template produces — this is the single strongest piece of product-specific design in the app.
- **The mantra closer** after the save button is a deliberate peak-end device, ending the session calmly rather than on the heaviest tracker question.
- **Color restraint holds up under measurement**: gold-on-black and muted-text-on-black both verified well above WCAG AA (8.7:1 and 6.7:1), and the alert/prep banners stay warm-gold rather than reaching for red — the "no alarm colors" rule is honored even under pressure.

## Priority Issues

**[P0] The save confirmation can lie.**
Why it matters: the toast fires "✓ Dag opgeslagen" immediately and unconditionally; the actual Supabase write is only checked in a `.then()` that logs failures to the console — nothing reaches the UI. For a private daily entry about real therapy work, believing something is saved when it silently wasn't is the single worst failure mode this specific product can have.
Fix: gate the toast on the resolved promise; on failure, show a persistent (not auto-dismissing) "niet opgeslagen — probeer opnieuw" state and retry.
Suggested command: `/impeccable harden`

**[P1] The streak feature contradicts DESIGN.md's own explicit anti-gamification rule.**
Why it matters: DESIGN.md states "no streaks, badges, confetti… gamified habit-tracker energy" — yet a 🔥/⚡/✦ streak bar renders in the header on every visit with history. This imports exactly the dopamine/loss-aversion emotional register the product is supposed to avoid for someone doing therapy work, not habit-gaming.
Fix: remove it, or convert to a quiet non-numeric acknowledgment consistent with the stated rule.
Suggested command: `/impeccable quieter`

**[P1] The tracker elaboration placeholder is functionally invisible — and violates DESIGN.md's own naming warning.**
Why it matters: `.tracker-toelichting::placeholder` uses `--text-dim` (#2A2520) on a #1A1A1A background — measured contrast ~1.15:1 against a 4.5:1 requirement. DESIGN.md itself flags `--text-dim` as "never applied to actual text… not a license to use it for type," and this is exactly that misuse, on the field where the user elaborates on the day's most emotionally loaded tracker answer.
Fix: switch to `var(--text-muted)`, already used correctly on every other placeholder in this same tab.
Suggested command: `/impeccable harden`

**[P2] Eight instances of functional text render below an 11px legibility floor on this exact tab.**
Why it matters: confirmed live via the browser-injected detector (not just static scan) — the day-badge label (9px), the active-goals section label (10px), and all 6 bottom-nav tab labels (10px) are all below the type system's own floor. Contrast is fine on all of them (5.86:1–8.46:1); this is purely a type-scale violation, not a readability-via-contrast one, but it's persistent chrome visible on every single screen, not a one-off.
Fix: bring these up to the 11px label floor DESIGN.md already documents; check whether the nav's `min-width: 58px` constraint (added for the finance tab's extra items) is what's forcing the label size down and address the layout pressure at its source rather than shrinking type further.
Suggested command: `/impeccable typeset`

**[P2] Administrative banners can outrank the actual ritual, and one is visually misaligned.**
Why it matters: the close-session, session-prep, and active-goals banners can all render above "Intentie van de dag" in DOM order — on a day when several trigger at once, up to three task-nag cards precede the calm content this tab exists to deliver, working against the "calm, low-friction daily ritual" product principle. Separately, the close-session banner measures 318px wide against 350px for the cards below it — a real grid misalignment, not a visual-judgment call.
Fix: move admin banners below the core ritual (or collapse them by default), and align the banner's padding to match `.card`.
Suggested command: `/impeccable layout`

## Persona Red Flags

**Casey (distracted mobile user)**
- The false "saved" toast fires even on a dropped connection — she walks away believing her entry synced when it may not have (same root cause as the P0 above).
- Up to three admin banners can occupy the top of her screen before she reaches the check-in she opened the app for.
- The `.toggle-btn` group measures 101×44px — exactly at, not above, the 44px touch-target floor, with no margin for a thumb on a moving train.

**Sam (accessibility-dependent user)**
- No headings exist inside the tab at all — VoiceOver's heading-navigation, the standard way to jump between sections, finds nothing to jump to here.
- Score and toggle buttons ("2", "Ja", "Nee", "N.v.t.") carry no label tying them to their specific question; four tracker items in a row announce identically.
- The tracker elaboration field's only "label" is a placeholder — which per the P1 finding above is also nearly invisible even before it disappears on focus.

## Minor Observations

- The autosave toast re-fires on every 2-second pause while journaling continuously — for someone mid-sentence on a hard topic, a recurring checkmark could read as a small interruption to the writing flow; consider a longer debounce or a quieter, non-toast indicator.
- The "Dag opslaan" button is largely vestigial now that autosave persists the same data continuously — worth deciding deliberately whether it stays as a closing *ritual* gesture (defensible, and arguably strengthens the peak-end close) or gets reframed/renamed now that it's not functionally load-bearing.
- The 157-item CLI scan backlog (mostly literal colors/font-sizes/radii off the DESIGN.md token scale, largely outside the today tab itself) is worth a dedicated `/impeccable polish` pass at some point, but isn't urgent — it's advisory-severity and the scan ran in degraded mode, so treat the count as an upper bound.
- A hardcoded therapy-session fallback can surface a stale "your session was scheduled" banner even on an empty account, directly above the "Welkom, dag één" empty-state — worth checking against real (non-empty) account behavior.

## Questions to Consider

- If check-in questions escalate only after real patterns emerge, why does the interface itself never visually mark that shift — shouldn't a level-3 question look or feel different from a level-1 one?
- The streak counter and the escalating-difficulty check-in both adapt to history — one gamifies, one doesn't. What would it look like to let the already-non-gamified phase/day framing carry all of the "you're on a journey" weight, and drop the streak language entirely?
- Given the save button's job is now mostly ceremonial, what if it were reframed explicitly as a closing gesture ("Dag afsluiten") rather than implying a save action still needs to happen?
