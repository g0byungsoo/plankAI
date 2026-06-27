# Becoming dashboard restructure — implementation plan
2026-06-10 · synthesized from 5 expert briefs (3 round-1 + 2 round-2) + founder calibration

Founder decisions locked 2026-06-10:
1. Build the one-snapshot dashboard (round-2 dashboard brief §5 wireframe).
2. HealthKit body-mass import ships in phase 1.
3. Wax-seal sticker allowed: ONE sticker, corner-anchored, ±8°, share cards only.
4. Reference register = Cal AI Progress tab (alive: embedded actions, one chart
   centerpiece, talks to her), NOT BetterMe (static stat sheet). JeniFit version
   swaps content per anti-shame locks.
5. Input-burden rule: never lead with input-dependent data (weight = 3.2% of WAU).
   Food leads via protein-first framing; daily calories stay weekly-smoothed, one
   tap deep.

## The surface (one viewport, no scroll for the core read)

Zone map per round-2 §5: folio masthead (day count in words, "of her N",
date range, identity line) → this-week row (serif count + 7-dot week row) →
THE artifact card (EMA trend + language delta + embedded `log weight` quiet
action; swaps to adherence artifact when weight data stale/absent — the
DEFAULT state today) → stat pair (steps | plates, hairline column rule) →
plate filmstrip (her own scan photos, collapses when empty) → insight line
(one sentence, provenance-gated rotation). Below the fold: weekly recap card
(blooms Sundays), plank mastery curve, lesson shelf, cohort care-lines.

Atom registers + budgets: round-2 dashboard brief §4 (11 atoms). Typographic
contract: serif numerals ONLY ≥20pt, max 3/viewport; DM Sans tabular for all
dense rows. 0 rings. Color budget: accent (bars/today ring) + cocoa (lines/
dots) + sage (goal-hit language only).

## Kill list (5-expert consensus)
- becomingTodayBalanceCard (daily gained-vs-spent kcal) — descendant is a
  weekly-smoothed line inside the recap/depth only.
- becomingWHORing — citation survives in a JeniMethod lesson.
- Streak strip — merges into the week dot-row + folio.
- BMI stays dead. No red, no heatmaps, no streak-loss, no single forecast date.

## Phases

**P1 — the snapshot surface** (AnalyticsView restructure)
- BecomingFolio (reads plan.totalDays — NEVER hardcode 75; day count in words)
- WeekDotRow + this-week count (program_day_checks)
- ArtifactCard: trend variant (EMA sparkline, naked, 2 print captions,
  language delta, eye toggle, quiet `log weight` action) + adherence variant
  (default when <2 weigh-ins in 14d); same chrome so page shape never changes
- StatPair (steps today/week | plates: macro micro-bars + "protein led" line)
- PlateFilmstrip (food log photos, 4-up, collapses entirely when empty)
- InsightLine v1: 3 honest-from-week-1 sentences (prior-attempts mirror,
  movement-timing, trend-vs-pace when data exists), provenance-gated
- Depth sheets: rewire existing moreDepth content under the new rows
- Kill list applied in the same pass (dead-code rule)

**P2 — HealthKit body-mass import**
- HKQuantityType bodyMass read (plumbing exists from steps), import into
  WeightLogRecord with one-per-day dedupe (update-in-place policy holds),
  source-tagged, kg canonical. Settings toggle next to steps permission.
- Trend artifact flips to weight variant automatically as coverage arrives.

**P3 — share + recap**
- Day-card 9:16 artifact (her75 day-one DNA): folio tap + recap page 3.
  Trend line defaults OFF on share, adherence + steps ON. ONE wax-seal
  sticker, corner, ±8°.
- Sunday recap full-screen takeover (line-cascade headline, numbered serif
  receipts, day-card close). Push Sunday 5-6pm, replaces a generic slot,
  skipped on zero-activity weeks.

**P4 — context layers (later)**
- HK sleep + cycle read-only, consumed ONLY as one-line trend explanations
  ("luteal week, water weight is normal"). On-device only, no server sync of
  cycle fields, no prediction, no cycle dashboard. Gated on P2 coverage.
- Cohort variants: GLP-1 protein promotion + sensitive under-eating flag;
  perimenopause slower-pace legitimization; restriction-history numbers-free
  rendering (round-1 program brief §5).

## Checkpoints
- 30-day food-data re-pull before locking protein-hero render gates
  (week-1 novelty caveat, round-2 cohort brief §1).
- Build + device screenshots + founder QA between phases (locked phasing
  pattern).
