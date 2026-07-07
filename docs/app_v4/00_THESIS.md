# app v4 — the program rebuild (thesis)

Date: 2026-07-06. Branch `feat/app-v2`. Founder brief: "Start fresh.
Do not assume the previous app v3 redesign is complete... a real
product and design rebuild... JeniFit should feel like a custom
weight loss / weight management program for women, not a generic
tracker and not a bundle of tools."

Inputs: my own simulator walkthrough of build 24 + the full surface
inventory (36 captures), the code-reality map, docs/app_v3/* and its
verified research, and four fresh verified research passes in
`docs/app_v4/research/` (PROGRAM_STRUCTURE · JOURNEY_UX ·
INTERACTIVE_METHOD · BREATHWORK_BAR · STEPS_VALUE).

This document supersedes `docs/app_v3/00_THESIS.md` where they
disagree. It does not revert v3; it names what v3 got right, what it
missed, and what v4 builds.

---

## 1. The honest diagnosis

v3's day model is right and stays: reading-first, one thing, rhythm
rows, no debt grammar, kept days, break state, chapters, the band.
The components are genuinely good (the cocoa one-thing card, the
strike, the note cascade, the snap carousel, the chat letter).

But walking the real build as a user, the founder's complaints all
reproduce, and they share one root:

**The program does not exist as an object.** PrescriptionEngineV2
stamps a 7-slot weekly rotation across `totalDays` (the seeded QA
user gets 140 undifferentiated days). There are no phases, no named
weeks, no weekly learning loop, no visible adaptation. `programWeek()`
is division. The app cannot show her the plan because there is no
plan to show — only day math. That is why "when I open it, I don't
know how today connects to the bigger plan" is true even though
Today itself is calm and clear.

Everything else the founder flagged is downstream or adjacent:

- **Plan-over-time**: the strip was exiled to a sheet behind an
  unlabeled day pill (v3 "minimal correction"). The sheet holds a
  7-cell strip + a hint line + half a screen of air. Past-day
  receipts show a standing word + a plates line. No weight, no
  steps, no jeni memory, no week story. Undiscoverable AND thin.
- **Food**: the "today so far" band contradicts itself on one
  viewport (a "KEPT — snap your first plate" strike directly above
  "0 of 90g protein · your first plate starts the day's story") —
  root-caused to `FoodLogPersister.todayKcalTotal()` not being
  userId-scoped while the band reads scoped entries. And the food
  journal interior is a v1 surface: holiday-styled stock plate
  photo, floating pink FAB, "tap the + to scan or jot" — a different
  app hiding inside this one. No surface answers "am I on track
  today?" or "what's my week look like?".
- **Method**: the rep (scenario + doors) is the right grammar with
  16 authored moments; the reader is still a read. Fresh research
  (INTERACTIVE_METHOD) quantifies the founder's instinct: active
  CBT tools beat psychoeducation reading (66.9% vs 39.5% reliable
  improvement classes, N=54k); a tiny daily DO beats curriculum;
  self-monitoring alone loses to every skill arm.
- **Breathwork**: the session visual is a static PNG scaling
  0.45→1.05 with symmetric easeInOut, a 1Hz countdown numeral
  inside the bloom, and discrete timer-based haptic ticks. The v3
  ledger called it "frame-verified excellent"; the founder is right
  that it isn't. Premium breath apps run organic visuals,
  breath-shaped curves, continuous haptics, and never make you read
  a clock mid-breath.
- **Becoming**: four disconnected modules (one insight line, one
  "you showed up" row, a flat chart whose headline and badge measure
  different windows, a method card). The ONLY place the arc exists
  is its eyebrow ("WEEK TWO · DAY 12 OF 140").
- **Workout completion**: still the v1 celebration — two stat pills,
  a 5-star row AND a feeling-chip row, sticker scatter on a
  non-earned moment. The de-aging pass only reached the in-session
  controls.
- **Cohesion**: chapters exist structurally but a losing-chapter
  user never sees her chapter; three voice engines write copy that
  never references a shared arc; the tabs don't thread.

v3's ledger marked nearly everything DEEP. The lesson for v4: a
verdict table is not a rebuild. This pass ships journeys, not
verdicts, and the evidence is recordings, not adjectives.

## 2. What JeniFit becomes

**One weight-care program with a visible spine.** Three chapters
(losing / on-medication / keeping), each structured as named phases
made of named weeks, each week living one Monday-to-Sunday cycle:

- **Monday** opens a fresh page: the week has a name and one
  sentence of intent in jeni's voice ("week two · finding steady —
  we're building the noticing muscle before we push anything").
- **Every day** stays v3's reading-first ritual — reading, one
  thing, rhythm, band — now threaded to the arc ("day 12 · week
  two" is one tap from the whole journey).
- **Sunday** closes with THE RE-SIGNING: jeni reads the week back
  from her real data, proposes at most one adjustment with the
  reason attached ("you cleared 90g of protein 5 of 7 days —
  I'm easing your floor to 95g. keep it?"), and she consents,
  adjusts, or declines without penalty. The plan visibly learns
  or visibly holds steady — both are signal.

And one place where time is visible: **becoming rebuilt as THE
JOURNEY** — a vertical ledger chaptered by named weeks; solid past
receipts, today distinct, dotted future shape; the trend line and
band riding the top; every past day a tappable memory (standing,
plates, weigh-ins, steps, jeni's line that morning); adaptation
moments signed and kept. Scroll up = her past. Nothing renders
absence; quiet days compress, breaks hold her place.

The felt contract:

> "I'm inside a real program. It has a shape, I can see where I am
> in it, I can read any day of my past, and I watch it learn me
> week by week. It asks for one small thing a day and never makes
> me feel behind."

## 3. The three moves (and what they are not)

1. **THE SPINE** — a ProgramArc model (phases per chapter), named
   week intents, and the Sunday re-signing. Deterministic,
   provenance-only, additive; the goal math and pace floors are
   untouched (they feed the paywall contract).
2. **THE JOURNEY** — becoming torn down to its trend canvas and
   rebuilt as the week-chaptered ledger + archive. The her-days
   sheet dies; Today's masthead gains a whisper-weight week ribbon
   (seven standing dots + the week's name, one line of typography,
   not 70pt of calendar chrome) that opens the journey. This is the
   calendar-strip answer: not the old strip back, a place the strip
   never managed to be.
3. **THE INTERIORS** — every feature journey rebuilt to the
   onboarding bar or deliberately demoted (04_FEATURES.md is the
   per-feature contract): breath becomes a real session (organic
   field, breath-shaped motion, continuous haptics, no numerals);
   the method becomes practice-first (the rep daily, micro-choices
   inside the reader, a 15-second tonight-plan builder); food gets
   one coherent day story and loses its v1 journal interior; the
   workout completion joins the register; weight loses its
   dual-window contradiction.

Not in scope, deliberately: no new tabs; no onboarding/paywall
changes; no schema, EF, RevenueCat, or notification-id-protocol
violations; no auto-adaptation beyond the consented weekly proposal;
no content farm (rep/lesson content ships at current authored count
+ the new grammar; the 84-slot pass stays founder-present work).

## 4. Why this wins (evidence, tagged)

- Programs with structure outperform tracking: DPP's 16-session arc
  is the canonical curriculum [strong]; ≥12 sessions in year 1 is
  the USPSTF effectiveness bar [strong]; automated weekly tailored
  feedback matched human coaching at 3 months (Tate 2006) [strong]
  — the license for the re-signing ritual.
- Stability-first weeks 1-2: teaching maintenance skills BEFORE
  loss cut regain in women (Kiernan 2013, N=267) [strong].
- The week 3-4 early-response gate: <2% loss at week 3-4 predicts
  5.6× failure at 1 year; "early rescue" is a published frame
  (Unick) [strong] — v4 names it a plan-v2 moment, never a verdict.
- The plateau is adherence decay, not metabolism (Hall) [strong] —
  so "the bend" is a schedulable support phase.
- Week units mint Monday fresh starts (Dai/Milkman: 25.6% vs 7.2%
  from relabeling alone) and abolish the mid-program swamp
  (Bonezzi) [strong]; midpoint framing switches from "days kept"
  to "days to go" (Koo & Fishbach) [strong].
- Adaptation builds trust only as a named, reasoned, consented
  moment (MacroFactor anatomy; Runna; Garmin's "why" retrofit)
  [product-fact synthesis]; perceived personalization is the active
  ingredient and one-line explanations protect trust exactly when
  outcomes disappoint (Li 2016; Kizilcec 2016) [moderate].
- Past-as-receipts, never absence marks (Cordeiro; Eikey — rendered
  absence is a clinical risk in this cohort) [strong]; presence
  counting beats streaks (Silverman & Barasch) [strong].
- Active practice beats reading (Chien 2020 N=54k; retrieval
  practice g=0.61; RESiLIENT 2025: behavioral activation wins,
  self-monitoring-alone loses) [strong]; if-then plans work
  menu-picked (Armitage) [moderate-strong] — the 15s chip builder
  is defensible.
- The rest of the v3 evidence base (zones, JITAI windows, kept
  days, protein floors, under-eating net) stands unchanged.

## 5. Success standard (the founder's failure list, inverted)

The app passes when: opening it answers now/today/noticed/easiest/
arc in one viewport; the journey surface makes any past day worth
tapping; the method is something she DOES in under a minute;
food answers "how am I doing today?" at a glance without shame;
breath feels like a session from a dedicated breath app; becoming
reads like her story, not a dashboard; every interior speaks one
dialect; and flows hold up on video and on an SE screen.
