---
name: Daily Coach
description: Calm, native-feeling dark PWA for one person's daily emotional check-ins, therapy prep, and finance tracking.
colors:
  black: "#0A0A0A"
  surface: "#111111"
  surface-2: "#1A1A1A"
  surface-3: "#242424"
  text: "#F0EDE8"
  text-muted: "#9A9590"
  divider: "#2A2520"
  gold: "#C9A84C"
  gold-light: "#E2C97E"
  input-bg: "#1C1C1E"
  success: "#27AE60"
  danger: "#C0392B"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "clamp(24px, 6vw, 30px)"
    fontWeight: 300
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  value:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 300
    letterSpacing: "-0.01em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    letterSpacing: "0.12em"
rounded:
  sm: "10px"
  md: "14px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.black}"
    rounded: "14px"
    padding: "17px"
  button-primary-active:
    backgroundColor: "{colors.gold-light}"
    textColor: "{colors.black}"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.sm}"
    padding: "14px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "22px"
  input:
    backgroundColor: "{colors.surface-2}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    padding: "14px 16px"
---

# Design System: Daily Coach

## Overview

**Creative North Star: "Daily Coach"**

No invented metaphor — the system is named for exactly what it is. This is a private, single-user tool used once or twice a day, styled to feel like a well-made first-party iOS app rather than a "wellness product." Near-black surfaces layered in steps, a single warm-gold accent used sparingly for what matters most (the current phase, the current answer, the primary action), and two quiet functional signal colors — never alarming, never celebratory — for the concrete yes/no and financial +/- states the app actually tracks.

Explicitly rejected: gamified habit-tracker energy — no streaks, badges, confetti, or progress-bar dopamine hits. This is a therapy-adjacent tool, not a game.

**Key Characteristics:**
- Near-black base (`#0A0A0A`) layered in three surface steps, never a flat gray
- Gold is the only decorative accent; success/danger exist purely as quiet functional signals, not decoration
- Flat by default; shadows appear only as feedback on an active press, never at rest
- iOS-native interaction language throughout: segmented controls, safe-area insets, backdrop-blur nav, scale-down press feedback
- System font stack, not a custom typeface — reinforces the "feels native, not branded" goal

## Colors

A near-monochrome dark palette with exactly one decorative accent and two purely functional signal colors.

### Primary
- **Aged Gold** (`#C9A84C`, brightening to `#E2C97E` on press/emphasis): The only decorative accent — the current phase indicator, active tab state, primary button, section labels that matter, day badge. Used consistently, never competing with itself for attention within one view.

### Neutral
- **Black** (`#0A0A0A`): Base page background.
- **Surface** (`#111111`): Standard card background — the default "something is grouped here" signal.
- **Surface Two** (`#1A1A1A`): Input fields, toggle/segmented-control tracks — one step up from Surface, marks "you can interact with this."
- **Surface Three** (`#242424`): Card borders, pressed-state backgrounds inside segmented controls — the lightest neutral step, used sparingly.
- **Divider** (`#2A2520`, CSS var `--text-dim` in code despite the name): Hairline borders and section dividers only. Never applied to actual text — the variable name is a legacy mismatch worth knowing about, not a license to use it for type.
- **Text** (`#F0EDE8`): Primary reading text.
- **Text Muted** (`#9A9590`): Labels, secondary content, placeholders.

### Functional (non-decorative)
- **Quiet Green** (`#27AE60`): "Done," "yes," income, positive financial movement. Used as text/icon color only — never a background badge, never celebratory.
- **Muted Red** (`#C0392B`): "No," a concerning tracker answer, an expense, a destructive action. Same restraint as green — a signal, not an alarm.

### Named Rules
**The One Accent Rule.** Gold is the only color used decoratively. Green and red exist solely to report a concrete state the data already contains (done/not done, income/expense) — never introduce them as UI decoration or a third accent.

**The Tinted Emphasis Rule.** A card that needs to feel more important than a standard `card` doesn't get a brighter neutral — it gets a near-black gradient tinted toward its accent color instead (e.g. the finance dashboard and goal banners use `linear-gradient(135deg, #0E0C06, #080600)` with a low-opacity gold border, not a lighter gray). Depth and importance are communicated through color temperature, not lightness.

## Typography

**Font:** System font stack (`-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif`) — deliberate, not a fallback. Reinforces the "feels like a native app, not a designed product" goal.

**Character:** Light weights (300) at display/value sizes read as calm and unhurried; regular weight (400) carries actual reading content; a wide-tracked uppercase micro-label (500, 11px, 0.12em) marks every section and field without shouting.

### Hierarchy
- **Display** (300, `clamp(24px, 6vw, 30px)`, tracking `-0.02em`): The header greeting only (`Goedemorgen.` etc).
- **Value** (300, 20px, tracking `-0.01em`): The single most important piece of content in a card — the day's intention, an alert title, an empty-state title.
- **Body / Question** (400, 15-17px, line-height 1.5-1.7): Check-in questions, prompts, reading content.
- **Secondary** (400, 13-14px, `text-muted`): Supporting text, previews, sublabels.
- **Label** (500, 9-11px, tracking `0.1-0.14em`, uppercase, `text-muted` or `gold`): Every section title and field label. Gold when it's marking something time-relevant (a date, the current phase); muted otherwise.

## Layout

Single-column, mobile-only, capped at `680px` max-width (in practice always narrower — this is a phone app). No sidebar, no multi-column — content is a scroll of stacked cards under a fixed header, with a fixed bottom tab bar (`bottom-nav`) replacing traditional page navigation entirely: this is a tab-switching single-page app, not a routed multi-page site. Safe-area insets (`env(safe-area-inset-top/bottom)`) are respected on both the header and the bottom nav — this app is designed to be installed and used full-screen on an iPhone, not viewed in a browser tab.

## Elevation & Depth

Flat at rest. The only `box-shadow` usage in the entire system is a direct response to an active/pressed state on segmented controls (`.score-btn.active`, `.toggle-btn.active-*`) — a small, soft shadow that appears only while that option is selected. Everything else conveys depth through the surface-layering scale (black → surface → surface-2 → surface-3) and, for emphasis cards, the tinted-gradient pattern described above.

### Named Rules
**The Press-Only Shadow Rule.** A shadow is never decorative and never present at rest. It exists only to confirm "this option is currently selected," on segmented controls specifically.

## Shapes

Two radius steps plus full-round for anything circular or pill-shaped: `14px` for standard cards and the primary save button (the "this is a contained unit" radius), `10px` for secondary cards, inputs, and small interactive chips, and full-round (`9999px`) for the day badge, toast, goal tags, and week-dots. Borders are always hairline (1px), almost always the `surface-3` or `divider` neutral rather than a colored border, except on tinted emphasis cards where a low-opacity gold border reinforces the accent tint.

## Components

### Buttons
- **Primary (`save-btn`):** Full-width, `14px` radius, solid gold background, black text, 17px/600 weight, `54px` minimum height (iOS touch target). Press feedback: background shifts to `gold-light`, scales to 0.97, opacity dips slightly.
- **Outline (`btn-outline`):** Full-width, transparent background, muted hairline border, muted text. Press feedback: border and text both shift to gold. Used for secondary actions.
- **Small (`btn-small`):** Compact, `surface-3` background, used inline (e.g. next to a list item).
- **Danger (`btn-danger`):** Transparent, muted-opacity red text/border at rest, full opacity red on press — deliberately quiet until touched, never a loud red button.

### Segmented Controls (signature component)
- **Toggle row** (yes/no/n.v.t.) and **score row** (numeric scale): both share the same pattern — a `surface-2` track holding borderless segments; the active segment gets a `surface-3` background, a soft press-shadow, and a semantic text color (green for yes, red for no, gold for n.v.t./neutral). This is the app's most-used interactive pattern and should be reused for any new multi-choice input rather than inventing a new control.

### Cards
- **Standard (`card`):** `surface` background, `surface-3` hairline border, `14px` radius, `22px` padding.
- **Emphasis (`card-gold`, `card-alert`, `fin-dashboard`, goal/session banners):** Tinted-gradient background per the Tinted Emphasis Rule above, low-opacity gold border.
- **Shadow:** None on any card variant — see Elevation & Depth.

### Inputs / Fields
- **Style:** `surface-2` background, `surface-3` hairline border, `10px` radius, gold border on focus — no glow, no ring.
- **Labels:** Uppercase micro-labels sit above the field, matching the form-group pattern used throughout (finance forms, tracker toelichting fields, session notes).

### Navigation
- **Bottom tab bar:** Fixed, `rgba(10,10,10,0.85)` with `blur(24px) saturate(180%)` — frosted glass over scrolled content, not a shadow. Active tab is gold; inactive is muted. Horizontally scrollable on narrow screens (finance tab pushed the nav past comfortable fit) rather than shrinking icons further.

### Toast
- Floating pill, frosted-glass background matching the nav, positioned above the bottom nav respecting safe-area. Used for lightweight save confirmations — not for errors or anything requiring action.

## Do's and Don'ts

### Do:
- **Do** keep gold exclusive to decoration/identity and green/red exclusive to reporting real data state — never blur the two roles.
- **Do** build new emphasis surfaces with the tinted-gradient pattern (near-black + accent hue), never a flat lighter gray, when something needs to stand out.
- **Do** reuse the toggle-row/score-row segmented-control pattern for any new multi-choice input.
- **Do** respect safe-area insets on any new fixed-position element (header, nav, toast, banners).
- **Do** keep shadows exclusive to active/pressed segmented-control states — nowhere else.

### Don't:
- **Don't** add streaks, badges, confetti, gamification, or celebratory UI of any kind — this is a therapy-adjacent tool, not a habit-tracking game.
- **Don't** add a third decorative accent color; the palette is deliberately gold-only plus two functional signals.
- **Don't** use a custom typeface — the system font stack is intentional, reinforcing the native-app feel.
- **Don't** fabricate testimonials, ratings, or social proof of any kind — this is a private single-user tool with no audience to prove itself to.
