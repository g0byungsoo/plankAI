# JeniFit App v2 — the in-app rebuild

Date: 2026-07-03. Branch: `feat/app-v2`.

This doc set covers the ground-up rebuild of the in-app experience —
everything after the hard paywall. Onboarding v5 (2026-07-02) set the
bar: premium, editorial, emotionally intelligent, conversion-focused.
The app behind it was still v1.1-era: two tabs, a static checklist,
an over-dense dashboard, and modules that don't talk to each other.
v2 makes the app cash the promise the onboarding sells.

## The one-sentence thesis

JeniFit stops being a collection of trackers and becomes a **daily
coaching relationship**: one plan, one coach (Jeni), one thread through
food, movement, mindset, and weight — authored per-woman by the
program engine and voiced by Jeni everywhere.

## Reading order

| Doc | What it decides |
|---|---|
| `01_AUDIT.md` | What exists today, what's broken, what's world-class |
| `02_STRATEGY.md` | Product thesis, audiences, the daily loop, retention model |
| `03_IA.md` | Tabs, surfaces, navigation, settings |
| `04_DAILY_PROGRAM.md` | Prescription engine v2, day shapes, targets, cohorts |
| `05_CHAT.md` | JeniFit Chat: client, edge function, context, tools, safety |
| `06_DATA_SUPABASE.md` | Schema changes, sync fixes, canonical cohort store |
| `07_GATING.md` | AppPhase machine, offline policy, expired wall |
| `08_MIGRATION.md` | Existing-paid-user upgrade moment |
| `09_NOTIFICATIONS.md` | Orchestrator, categories, caps, cohort copy |
| `10_DESIGN_SYSTEM.md` | JeniKit: the onboarding→in-app translation |
| `11_IMPLEMENTATION.md` | Build phases, file plan, verification loop |
| `SCIENCE.md` | Citation-backed evidence base for coach + program claims |

## Non-negotiables carried into every doc

- 8 locked color tokens; cream `bgPrimary` is the only background.
- JeniHeroSerif / Fraunces / DMSans ladder; italic punch words only.
- Lowercase casual; ♥ (U+2665 + FE0E) terminal only; no em-dashes;
  no "AI" in user copy; no diet-culture verbs.
- Data provenance: every number traces to a collected field.
- Anti-shame: trend > number, no red states for food, tomorrow resets.
- Compliance floors: no drug brand names, no drug-equivalence claims,
  no first-party numeric weight-loss claims, ED-safe routing.
- Sticker scatter only on earned moments (welcome / plan reveal /
  graduation — migration welcome counts as a welcome).
- Every number/copy promise must be cashable in-app within 3 sessions.
