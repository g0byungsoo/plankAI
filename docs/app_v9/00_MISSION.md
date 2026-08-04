# app v9 — THE BODY OS

**Status: APPROVED (2026-08-03, founder: "recommendations stand" —
D1-D10 resolved at their recommended defaults; "proceed with P0").
This doc set is law. Same day the founder added one more
constitution: `04_DESIGN.md` — DESIGN 100× (design quality is now
the bottleneck; L7).**

Reading order: this file → `01_AUDIT.md` (the verified fact base) →
`02_PLAN.md` (the evolution plan) → `03_DECISIONS.md` (the resolved
founder ledger) → `04_DESIGN.md` (the design constitution) →
`05_BUILD.md` (the shipped record, phase by phase).

---

## 1. The founder's brief (2026-08-03), distilled

Jeni evolves from a calorie tracker into a **Body Transformation
Operating System**. Not the app with the most features — the app
people happily use for years because it genuinely helps them
transform their body. The emotional reason she opens Jeni becomes:

> **"I can actually see myself changing."**

The product hierarchy inverts:

```
                 BODY PROGRESS  (the center)
                       ↑ explained by
   food · movement · sleep · medication · behavior
```

Food, movement, sleep, and medication are no longer parallel
features — they exist to explain why the body is changing. Coaching
exists to continue the transformation.

**Non-negotiables (verbatim intent):** do not rewrite; do not
replace working systems; favor extension over replacement; minimize
regressions and migration risk; existing users must feel evolution,
not a new app. Optimize for long-term adherence, beautiful native
experience, scientific credibility, minimal manual input, delight,
simplicity, trust, motivation, retention. When choosing between a
new feature and a dramatically better experience, choose the better
experience.

**Named workstreams:** Body Vision (the signature experience),
Passive Health (Apple Health maximally, passive over manual), Food
Vision (camera-first, insight-first), the Behavior Engine (ONE
daily focus), B2C polish, B2B extension (obesity clinics, GLP-1
patients — extend, never a separate app), extraordinary design
(Apple Design Award bar), continuous self-verification on the
simulator.

## 2. The three questions law (L1)

Every surface must answer at least one of:

1. **Am I changing?**
2. **Why am I changing?**
3. **What should I do next?**

A surface that answers none is a demotion candidate — recorded in
the ledger (`03_DECISIONS.md` D-items), never silently cut. The
audit maps today's surfaces against the three questions
(`01_AUDIT.md` §6).

## 3. The v9 laws

- **L2 — EVOLUTION LAW.** Additive SwiftData models, additive
  idempotent migrations, new modules as new enum cases in the
  existing hosts. No schema rewrites, no route-machine changes, no
  renames out from under her. Existing users meet each new surface
  through the shipped migration-moment pattern (one-time,
  provenance-true, stamped). Every phase lands behind the existing
  flag stack (entitlement gate → PostHog rollout flag) and is
  independently shippable + revertible.
- **L3 — HONESTY LAW** (extends the data-provenance rule). **No
  number is ever derived from a photo.** Pixel-derived
  measurements (waist, weight, body-fat) are pseudo-precision; the
  scan's job is visual evidence, not measurement. Body-composition
  numbers render only from real sources (HealthKit lean mass /
  body-fat % written by her scale), always with provenance.
  Change language is qualitative, floor-gated, and states its
  uncertainty ("early signal — two weeks of data"). Correlation
  language stays observational ("likely", "may", timing-never-
  causality); a rising trend is never blamed on a single food.
- **L4 — BODY PRIVACY LAW.** Scans are captured and processed
  **on-device** (Vision framework), stored local-first; cloud
  backup is a separate explicit opt-in, default OFF. Scans never
  appear in analytics or logs, never leave for any AI service, and
  never reach a clinician in v9 (no consent scope exists for them
  — deliberately). Silhouette mode is a first-class equal citizen,
  not a fallback. Sweep lists, delete-account purge, and re-key
  paths ship in the same commit as the store — never after.
- **L5 — PASSIVE LAW.** Never ask her to type what iOS already
  knows. Every read the app requests must have a rendered surface
  (requesting sensitive data we don't show is a trust breach — the
  audit found five such reads). Background delivery lands data
  without an app open. Each new manual ask must displace an old
  one.
- **L6 — REGISTER.** Body surfaces speak the clinical-calm voice
  (the Jeni release voice law): clear, calm, confident, precise —
  Apple Health, not Instagram wellness. Anti-shame floors hold
  everywhere: trend-as-hero, no red states, no before/after shame
  grammar, "your record" framing, her control over what she sees.

## 4. What this is not

- Not a rebuild: the AppPhase machine, three tabs, onboarding v7,
  the keep wall, auth/sync, chat, the clinic loop, and the design
  tokens all stand (`02_PLAN.md` §5 lists the untouched set).
- Not a measurement product: no tape-measure theater, no invented
  precision (L3).
- Not surveillance: passive means the phone works for her, not
  that the app watches her (L4; B2B monitoring posture is
  founder+counsel-gated, D6).
