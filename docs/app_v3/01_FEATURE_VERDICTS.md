# app v3 — feature verdicts

Date: 2026-07-05. Verdict per feature: KEEP / TRANSFORM / DEMOTE /
REMOVE / NEW, with the reasoning and the concrete v3 direction.
Data anchors: PostHog 21d (1,467 active, ~90 purchasers, 44% D1 →
10% D7 paid retention; food 10.5 plates/logger; lessons 99% reach /
19% completion; workouts 26% ever-complete; breath 69% complete).

---

## The daily program (beats engine) — TRANSFORM (the core change)

Problem: deterministic engine is good; its RENDER is homework (4
parallel cards + check circles + locks + N-of-M). Direction: keep
PrescriptionEngineV2's composition; re-express as:
1. THE READING (grown brief: 2-4 sentences, provenance-only),
2. THE ONE THING (engine-picked single hero card),
3. THE RHYTHM (remaining beats as hairline rows, strike-on-done,
   no at-rest circles),
4. the band (kept), 5. THE RECEIPT (evening flip, kept + elevated).
Reset weeks become compositional (fewer/softer beats), not copy.
Day strip: locks die → dimmed numerals; past dots show standing.
NEW: "on a break" state (sick / period / travel / a hard week) —
one tap in settings or via jeni; pauses the rhythm, the strip
expectations, and all pings; return is a warm "welcome back" with
automatic repair, never a catch-up. Score grammar: KEPT DAYS
(lifetime, never resets) + weekly rhythm with 2 built-in rest days.
Production: re-wire recordShownUpDay / markSessionCompleted /
refreshDailyAnchor into the new surface (safety map).

## Snap food — KEEP (signature), extend gently

The engagement engine. Untouched: camera → carousel → note → share,
≤3 interactions, Metal sweep, editing math. Add:
- day-level answer on Today band: "close enough" state language on
  the protein arc/kcal sentence (exists partially; sharpen copy).
- on-medication chapter: optional "how did it sit?" one-tap chip on
  a logged plate (fine/heavy/queasy), device-local, patterns
  surfaced by the reading when N≥ a floor. NEVER medical advice.
- under-target safety net (on-GLP-1/restrictive): if the day runs
  very low by evening, the receipt asks "did you eat enough?" —
  adequacy posture, never celebration of less.

## Jeni chat — TRANSFORM the surface, keep the engine

Engine (SSE EF, caps, tools, safety) is right. Surface today is an
empty room. Direction: the jeni tab opens as her coach's desk:
- the reading as letterhead (same engine as Today; one voice),
- HER FILE: the v5 dossier grown into a living card (chapter, pace,
  protein floor, band when keeping, promise hour) — receipt
  grammar, tappable rows → the right ritual/settings,
- state-aware chips (kept; sharpen provenance),
- the conversation (letter register, kept).
Chat stays device-local this pass (no cross-device promise).
Rule kept: mutating tools confirm; no new tools unless they mutate
real state or navigate.

## JeniFit Method — TRANSFORM (read → practice)

Widest reach, weakest completion. Direction: THE REP — a 20-40s
interactive decision practice as the Method's daily presence
(scenario → 2-3 answer doors → warm mechanism line → "kept"), fed
by the 84-slot manifest (each slot: one rep + the reader page set
as depth). Reader is premium — KEEP as "go deeper." Practice kinds
(timedPause/guidedBreath/implementationIntention) fold into rep
grammar. Consolidate: ONE lesson resolver (today three), ONE
completion store (today two), legacy JeniMethodRitualView fallback
REMOVED after rep ships. Content: rep lines for doc-22's 10 samples
ship now; full 84-slot authoring stays founder-present (flagged,
scalable path documented).

## Workouts — DEMOTE (deliberately, safely)

26% ever-complete; the audience moves outside the app or not at
all. Direction: workouts render ONLY on their scheduled days (tier
cadence kept), never as guilt; the 5-minute floor becomes the
DEFAULT offer on low days ("make it 5" stays one tap); "i moved
today" (outside the app) is a first-class one-tap mark (long-press
override exists; add explicit door in the row). Framing: strength
kept, muscle held — never calories burned. PRECONDITION (production
safety): redefine shown-up/day-standing so any meaningful action
counts BEFORE de-emphasizing workouts, or briefs/wins/walls read
"0 kept" for lesson-and-snap users. In-session experience: KEEP
(voice system + player are strong).

## Breathwork — KEEP as the reset (v2.4 reframe holds)

69% completion; the craving-brake reframe is right. Direction:
60-second default dose everywhere; one-tap reachable from the
reading (stress days), chat craving routes, post-lapse receipts,
and the rep grammar ("the sideways door"). No new surface; the
session core is already excellent (motion doc verdict). It is the
matched micro-move of our rule-based JITAI.

## Weight — TRANSFORM display philosophy; keep the ritual

JKWeightRitual (ruler) is right. Direction: capture daily-capable,
narrate weekly. The EMA line is the only hero; raw numbers move to
secondary registers everywhere (Becoming's 163.6 lb hero dies; the
line + weekly delta lead). Losing chapter: cadence beats (Mon/Thu)
stay. Keeping chapter: THE BAND — three zones around settle weight
(steady ±3 lb / drifting 3-5 / reset 5+), zone crossings open
actions (steady-week plan / reset arc / a conversation), never
alerts alone (null-trial lesson), never red. A broken weighing
pattern (not just the number) is named gently as the earliest
signal. "Gentler cadence" mode kept for sensitive users; numeric
suppression flows respected everywhere.

## Steps — KEEP (the ambient win), unify + quiet celebrate

The only beat that does itself; keep auto-complete + ring. Fix the
3-source goal split (TargetsService is the ONE source; WeekState +
TodayStepsSheet hardcode 7500 today). Crossing celebration stays
quiet (strike + a receipt word). No gamification.

## Becoming / analytics — TRANSFORM into the story (v2.1 direction,
## completed)

Keep: trend canvas (+ band in keeping), insight cards (max 2,
ask-jeni seeds), method journey, wins, Sunday receipt artifact.
Change: de-hero the raw number; one fact renders once (the −2.2 lb
triple-render dies); wins read the NEW standing model (not
workout-only). The Sunday receipt grows into THE CHECK-IN: receipt
(what the week held) + one consent-based re-prescription line
("this week taught your plan: protein target eases 5g. keep it?")
— the MacroFactor spine in Jeni's voice; declinable, explained,
never silent. Every snap thereby visibly teaches the plan. Trend
copy pre-explains physiology (intra-week ~0.35% swing, Monday
peak) so upticks arrive pre-defused.
Kill test kept: if a module doesn't change what she does next, it
doesn't render.

## Notifications — TRANSFORM (build the orchestrator, finally)

Spec exists (09). Direction: all bodies authored by the same voice
pipeline as the reading (push == in-app line, never diverges);
triggers: promise hour (D1), daily anchor (reading teaser), comeback
(2-day quiet, gentle), weekly story (Sunday), keeping-chapter zone
crossing + weigh-pattern break; PLUS the lapse-support ping (her
usual logging hour passed + evening → the reset tool or a one-tap
check-in) armed for weeks 0-6 ONLY (the JITAI durability window;
prompts have a ~4-week half-life). The anchor ask moves to the end
of her FIRST completed ritual (peak motivation; Calm: 40% adoption,
~3x retention). One milestone bloom in week 1 (the one streak-family
mechanic with a measured D7 lift, +1.7%). Caps hard (≤1/day
uninvited); "on a break" silences everything; every deep link
resolves through AppRouter queued-to-main (gating preserved).
Trial-window pushes untouched (pay-upfront era rules stand).

## Onboarding → app seam — TRANSFORM (Day 0 is the fire)

v5 stays. The post-purchase first-run is promoted to a first-class
surface: 55% of trial cancellations happen day 0, and early
engagement quartile ≈ renewal destiny. The first paid minutes:
meet the reading (her demo meal + promise hour cited back) → the
first two things (breathe 60s now · snap tonight) → her first kept
moment → THE ANCHOR ASK lands here (her hour, one line, one tap).
Migration moment (legacy users) kept; copy gains the chapter
question when cohort = past ("hold here, or keep going?").

## One-word check-in — NEW (small, optional, load-bearing)

A one-tap word check ("how's the food noise today?" — quiet / some
/ loud, chapter-flavored wording) offered inside the reading or the
evening receipt, never as a gate. ≤30 seconds lifetime cost. Feeds:
Jeni's memory (context envelope), the on-medication appetite
pattern (user-discovered, never asserted), and the lapse-ping
trigger (the EMA self-report the JITAI literature runs on). Skipped
forever = fine; it never nags.

## Past / future days — KEEP the new review, grow the archive

Past taps → review sheet (shipped 2026-07-05): becomes the DAY
RECEIPT archive (standing word + what landed +, later, her evening
feeling word). Future taps → warm peek ≤+7 (kept), lock glyphs die
(dimmed numerals beyond). The strip reads as a life, not a
scoreboard.

## Safety layer — KEEP, tighten glyphs + copy

Safety gate (SCOFF/pregnancy/BMI), numeric suppression, ED routing,
clinician handoffs: unchanged, load-bearing. Fix the ♡ U+2661 in
the legacy check-in intro; verify heart FE0E rendering app-wide.

## REMOVED / dies this pass

- Checkbox-circle at-rest grammar on plan rows (JKStateCircle only
  appears on strike/done, or is replaced by the strike entirely).
- Padlock glyphs on the day strip.
- Raw-number hero on Becoming.
- Legacy lesson fallback (JeniMethodRitualView) once reps ship.
- Dead beat cases (.plank/.water/.measurements) + the duplicate
  ProgramDayPrescription title metadata (one title system).
- The coach-mark ("tap a row...") — the one thing + rhythm design
  makes it unnecessary; kills its clipping bug with it.
- 54 legacy ♡ glyphs (mechanical sweep, with the content pass).

## Explicitly NOT this pass (documented, reasoned)

- Auto-tier adaptation / deload-from-performance (data volume).
- Cross-device chat sync (device-local stands; no UX promise made).
- Full 84-slot rep content (founder voice; mechanic + samples ship).
- Photo cache/manual retry on snap failure (existing deferred task,
  unchanged priority).
- Paywall/pricing experiments (Sprint A dashboard work, not code).
- HealthKit body-mass import (P1 candidate, separate risk review).
