# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static PWA — plain HTML/CSS/JS in a single `index.html` (no build step, no framework), installable as a standalone app (`manifest.json`, `sw.js` service worker), with Supabase as the backend (`supabase-schema.sql`). Deployed and installed on the user's own phone (iOS-style safe-area insets, `apple-mobile-web-app` meta tags) — this is web platform per Impeccable's rules (mobile web, not a native wrapper), but is deliberately styled to feel native to iOS.

## Users

A single primary user: Pablo, using this daily as a personal emotional-growth and self-care tool. His therapist/coach also sees content from it, but only via printed/exported reports (the "rapport" tab) — they never log into the app itself.

## Product Purpose

A private daily coaching tool structured around: a daily check-in (`tab-today`), a weekly reflection (`tab-week`), therapy session preparation (`tab-sessie`), a finance tracker (`tab-fin`), a history/archive (`tab-archive`), and a printable progress report (`tab-rapport`) meant to be shared with or reviewed alongside a therapist. Automated email reminders (PowerShell scripts) nudge the relevant check-in at the right time (monthly finance review, Sunday evening weekly reflection, therapy session prep two days ahead).

## Positioning

Not a generic habit tracker or journaling app — it's built around Pablo's specific therapy/coaching rhythm (linked to real session dates and a real therapist relationship) and combines emotional, financial, and goal tracking into one private space designed to be looked at daily, not occasionally.

## Operating Context

- No CMS, no backend framework — data lives in Supabase (`daily_entries`, `weekly_entries`, `therapy_sessions`, `coach_sessions`, `goals`, `finance`, `settings`, `user_roles` tables).
- Installed as a standalone PWA on the phone home screen — not typically viewed in a browser chrome/tab.
- Reminder emails are sent via separate PowerShell scripts (`*-reminder.ps1`) run on a schedule, not from within the app itself.
- The "rapport" tab has dedicated print styles (`@media print`) — it's meant to be physically printed or exported as a PDF to bring to or share with a therapy session.

## Capabilities and Constraints

- Everything ships as one `index.html` — no bundler, no component framework. Design/implementation work should stay consistent with that (inline `<style>`, vanilla JS `switchTab()`-style view switching).
- Content and copy are in Dutch throughout (`lang="nl"`).
- **Security note (flagged during setup, not yet fixed):** the four `*-reminder.ps1` scripts hardcode a Gmail app password in plaintext, and at least one is already committed to the project's GitHub repo (`andresvandervliet/daily-coach`). This is a known, disclosed issue — out of scope for design work, but any future work touching those scripts should not perpetuate the pattern.

## Evidence on Hand

None applicable — this is a private single-user tool, not a product with external testimonials, marketing claims, or case studies. Never add any.

## Product Principles

- Private and personal first: every design decision serves Pablo's own daily use, not a general audience — no onboarding funnel, no marketing surface, no multi-tenant assumptions.
- Calm, low-friction daily ritual: the app should be fast to open and log into once, not something that demands attention or gamifies engagement.
- Therapy-aware: the report/export surface is a real artifact used in real therapy sessions — treat its clarity and printability as seriously as the in-app UI.
- Native-feeling on iOS without being native: honor safe areas, standalone display, and iOS interaction conventions since that's how it's actually used (installed on the home screen).

## Accessibility & Inclusion

No specific accessibility requirement has been established beyond the app being used solely by Pablo on his own device.
