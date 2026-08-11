# E4 — DAY TWO (the morning after) · the law

2026-08-11 · branch feat/app-v2 · the decision and its evidence live
in `14_E4_DECISION.md`; the build record in `16_E4_EVIDENCE.md`. One
sentence: **everything a person gives Jeni on day N returns as
visible understanding on day N+1 — food first, no engagement
tricks.**

---

## §1 · THE MORNING READ

- `DailyBriefEngine` gains **`YesterdayReceipt`** — a typed ledger of
  yesterday (plates · protein · kcal · weigh-in · kept beats · her
  evening word), assembled provenance-first in `TodayStateService`:
  - the receipt sums from the FIRST plate (a receipt states what's on
    file); `CarePlanEngine`'s promotion gate keeps its ≥2-plate floor
    (a judgment needs more).
  - the onboarding weight seed is never a weigh-in.
  - numeric suppression strips the numbers, keeps the words.
  - an unlogged yesterday builds NO receipt (absence, never zero).
- **The DAY TWO clause** (`day_two` / `yesterday_read`): mornings 2-7
  read yesterday back at n=1 scale when nothing stronger claims the
  line (break > promise > comeback > tender all outrank). It
  self-retires after week 1 — the trend and week clauses own the line
  from there; the receipt row keeps riding.
- **De-dup law (frame-caught):** when the clause reads the plates
  back in prose, the ledger row keeps only what the prose didn't say.
- **L1 closed:** the kept-promise celebration reads yesterday's
  plates on the day-2 letter (it read TODAY's, on a letter that
  presents before breakfast — structurally unreachable since v7).
- **L2 closed:** "proud" seasons the second sentence when the clause
  left it empty; "okay" stays a quiet receipt word. Tender's claim on
  the whole day is unchanged.
- **L5 closed:** a first weigh-in earns *"your weight line is
  forming. a direction takes a few more mornings."* — honesty as the
  reward, never a fabricated direction.
- Every cascade clause carries a stable id; `morning_read_shown
  {clause, has_receipt}` fires once per day at auto-present.

## §2 · THE PLATE'S MEMORY

- **Corrections persist.** Every fix-with-words sentence rides
  `CapturedFood.appliedCorrections` → the entry (JSONL) → the
  `food_logs.payload` jsonb (zero migration) → back on hydrate. A
  reinstall keeps the flywheel.
- **`PlatePriors`** (pure, 12 pins): only corrected dishes build
  priors; exact normalized-title match (fuzzy matching invents
  memories); latest correction wins; application is a uniform,
  revertible scale of the model's plate to her accepted kcal; ±15%
  agreement band (the model gets to agree); 3× absurdity refusal
  (family-size vs slice is not the same plate); **photo scans only**
  — barcode and label are printed truth, and the `.text` pipeline
  carries her own words and every correction (priors there would
  fight the correction they came from).
- **Visible, revertible.** The reading shows *"your numbers · you
  fixed this dish before"* with one-tap *"use the scan"*. A silent
  override would be a silent override of her next correction. A new
  correction dissolves any applied prior.
- **AGAIN is first-class.** The scan chooser grows a quiet third door
  (*"or log a recent plate again"*, only once a plate exists);
  `RecentMealsSheet` ships out of its debug harness; ≤3 taps from
  cold open to a kept log. Relogs mark the beat like any plate.
- **The threading bug dies:** `cuisine_profile` finally reaches the
  photo path, the label path, and refine (it died at CaptureFlowView
  since v5; only quick-add ever heard the onboarding answer).

## §3 · ONE CHOKEPOINT FOR "A PLATE LANDED"

Any plate that lands today marks the food beat — the camera, the
book's relog, the again rail, and jeni's `log_food_text` all count
(`TodayModuleHost` listens to `FoodLogPersister.changeNotifier`;
guarded on count so a deletion that empties the day never marks).
Before this, only the capture flow's own dismiss marked (J1).

## §4 · ROUTES THAT ARRIVE

- Becoming consumes its own routes (`.trend` · `.weeklyRead` ·
  `.plates`). The always-mounted Today tab used to swallow them.
- `jenifit://plates` opens THE BOOK directly; the evening-review push
  finally lands on the surface it promises.
- The past-day recap shows the WHOLE day: plate photographs (up to
  three), kcal + macros, and the letter's receipt grammar for the
  rest ("weighed in · closed proud"). A day with a weigh-in but no
  plates no longer reads "nothing logged".

## §5 · THE BRAIN, UNSTARVED

- The anchor ladder is **3 rungs, not 7**. Five stamped ids saturated
  the 5/week budget permanently: `winback_lapse` and `milestone_3`
  were vetoed FOREVER for exactly the one-active-day cohort they
  exist for.
- **The morning rung is the read's knock**: when today left a record,
  tomorrow's push carries it (*"yesterday: 2 plates and 76g protein,
  on file"*) — same id, same budget, timely value from her own data.
  The once/day rebuild guard became a state guard so an evening
  plate refreshes the payload.
- A brain-vetoed milestone retries for two days, then retires (a
  stale cheer reads as a glitch).
- `lapse_support` can finally arm: its eligibility read a default-ON
  toggle for a push that skips week 1 — a dead branch since E1.
  Week 1 belongs to lapse support; week 2+ to the evening review
  (≤1 uninvited evening push, unchanged).

## §6 · THE DESIGN PASS (as touched)

- The letter's receipt row: eyebrow + hairline + one caption line,
  monospaced digits, the letter's own quiet register.
- Becoming's new-user zero state: the wall of thirteen "not enough
  to read yet" rows compresses to ONE honest sentence ("your reads
  open as the record grows") + a "what's coming" disclosure.
- The desk's subtitle is care-gated: consumers read "your coach, day
  to day" (G9 — "between visits" implied clinician visits they don't
  have).
- MeAgain's lessons imported without its costume (14_E4 §3): repeat
  capture ubiquity, next-thing-as-fact, the reveal moment. Its
  streaks, mascot, PK curve, and slider grids stay refused.

## §7 · EXPLICITLY OUT (unchanged from the decision)

No EF schema changes (the SnappyMeal clarify question is E4.1,
bundled into the already-gated food-vision deploy) · no streaks,
badges, urgency · no new tab or DB · movement deferred (E3 D9) ·
method untouched (E3 D8) · clinic UI untouched (E6).
