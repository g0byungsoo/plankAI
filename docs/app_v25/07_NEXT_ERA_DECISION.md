# THE NEXT ERA — investigation + decision (post-E1)

2026-08-10 · branch feat/app-v2 · E1 closed at `ce9827d` (709/709).
Method: canonical docs read → repository inspected → QA sim walked →
**first-party PostHog data queried** → primary sources re-checked →
roadmap challenged → one era chosen.

`00_THE_SYSTEM.md` §15 proposed E2→E3→E4→E5→E6→E7. This document
treats that order as a hypothesis and reports where the evidence
confirms it, where it refutes it, and what changes.

**Verdict in one line: the roadmap's ORDER survives, its SCOPE does
not, and the reason is a number nobody had looked at — the median
paying customer opens Jeni on two days.**

---

## 1 · WHAT THE PRODUCT ACTUALLY IS RIGHT NOW (inspected, not assumed)

### 1.1 E1's spine is real, and its best room is empty

The weekly read is the strongest surface in the product. Walked on the
QA sim (`--uitest-force-read-day`, seeded week + weekly injectable) it
composes exactly as `06_E1_EVIDENCE.md` records: anchor label "after
the dose", one-clause hero, a three-signal band, floor-gated
observations, one teaching line, ONE offer, consent.

What it reads (`WeeklyReadComposer.Inputs`, assembled in
`JourneyModel.readModel`) is the whole list:

| input | source | present |
|---|---|---|
| steps this week + trailing | `StepsService.dailyCounts28` | yes |
| plate days / plate count | `ProgramWeekSlice` | count only |
| protein days met | `ProgramWeekSlice` | count only |
| doses resolved / expected | `DoseEventRecord` | count only |
| **weight / trend / EMA** | — | **absent** |
| **medication era, cycle day, symptoms** | — | **absent** |
| **sleep, fiber, kcal, patterns** | — | **absent** |

The read is titled "your **dose week**, read." and contains no dose
content beyond an optional "n of m dose slots resolved" line. A
weight-loss app's weekly ritual never mentions weight.

Of the eight `ProgramFactKind`s, exactly **one** (`stepGoal`) is
derived adaptively from measured behaviour. The other seven are the
v4 knobs, versioned. E1 built the memory correctly and gave it almost
nothing to remember.

### 1.2 Food (v23) is excellent and amnesiac

Walked: the reading page (`--uitest-plate-detail`) is genuinely good —
counted numeral, macro ledger, "of today's protein 24 of 123g", "share
of today's calories · about a quarter", "log it again · a fresh entry,
today", provenance line "logged from your words · ranges, not exact".

Under it, nothing learns:

- **Corrections evaporate.** `FoodLogPersister.Entry` has no
  corrected-flag, no original-vs-final diff, no dish key. The
  "corrections-as-moat" insert has a `TODO: W3-T5 follow-up` in
  `FoodCorrectionSheet.swift:173` dated ~2026-06 and never landed.
- **That sheet is unreachable.** `FoodCorrectionSheet` is presented
  only by `CaptureFlowView`, which nothing presents —
  `PlankAIApp.swift:1445` presents `PhotoCaptureView` directly. Two of
  its three affordances ("search →", "describe it instead →") are
  non-interactive `HStack`s. Dead code that survived the v23 S11 sweep.
- **The model's own uncertainty is discarded.** The EF returns
  `needs_second_photo` + `second_photo_hint`; `FoodVisionService`
  decodes both; **no shipping surface reads either** (only tests).
  The one signal that would tell us when to ask a question is already
  on the wire and thrown away.
- **No priors reach the model.** `buildSystemPrompt` receives
  `cuisine_profile` + `dietary_profile` from onboarding and nothing
  else. Her own corrected history never informs the next estimate.
- **"again" is a string match.** `recentMeals` dedupes on
  `title.lowercased()`; `relog` copies the row verbatim. No dish
  identity, no portion prior.
- **`SnapRefine.fixWords` re-estimates the whole plate.** It serializes
  every item back to the LLM and asks for "the FULL corrected plate."
  See §3.1 — the primary literature says this is the pattern that makes
  the other items worse.
- **THE BOOK still has no door.** `--uitest-open-food-journal` no-ops
  (gap-map T2, still open). Walked with seeded data it degrades to
  identical rows reading "the day's plates · 1:00 pm · 1,620 kcal" —
  the design bets everything on photographs.
- The vision EF defaults to `gpt-4o`, a latency-driven choice recorded
  2026-06-08. Two model generations stale.

### 1.3 Medication (v24) is a platform with no interpretation

Present and solid: `RegimenPlanRecord` version chains,
`DoseEventRecord`, `MedicationCatalog` (9 products; compound · route ·
cadence · doseLadder · isCompounded · emptyStomach),
`MedicationScheduleEngine` (`nextDoseDate`, `lateWindowEnd`,
`openLateSlot`, `missedSlotDays`), `SideEffectLog` (9 symptoms × 3
severities, including `appetiteGone` / `appetiteBack`),
`MedicationPatternEngine` (floor-gated, timing-never-causality, already
accepts `proteinByDay`).

Absent: cycle-day framing, food noise as a graded vital, missed-dose
label facts (the catalog has **no** late-window or minimum-gap field),
the underreported symptom set, maintenance, era interpretation in the
read. Walk-confirmed: Becoming shows **"your medication · 1 mg" under
"NOT ENOUGH TO READ YET"** with an active prescribed regimen (G6's
polish item, still live).

### 1.4 Today never learned anything

Walked at forced hour 15 with a seeded week: the food ask is "add a
meal · protein still anchors the day". The move support is the static
ghost "move · 10 min · steady". No walking action, correctly — E1's
consent-true rollout means no `stepGoal` fact, no walk beat.

---

## 2 · WHAT THE DATA SAYS (PostHog, project 437953, test users excluded)

This is the part that was missing from `02_AUDIT.md` and
`03_GAP_MAP.md`: both reasoned from code and pixels. Neither asked
what users do.

### 2.1 The headline

Paying customers whose **first purchase was ≥60 days ago** (n = 73, so
right-censoring is removed):

| measure | value |
|---|---|
| **median distinct active days, lifetime** | **2.0** |
| mean active days | 4.2 |
| reached 7 active days | 10 / 73 (14%) |
| reached 14 active days | 6 / 73 (8%) |
| reached 30 active days | **1 / 73 (1.4%)** |
| logged food on ≥2 days | 8 / 73 (11%) |
| mean days on which food was logged | 0.79 |

All 172 purchasers (200-day window): 38% ever logged a meal, 32% ever
logged a weight, 12% ever sent a chat message.

### 2.2 Food logging does not decay — it never starts

Of the **82 people who have ever saved a food log** (2026-06-06 →
2026-08-10):

| distinct logging days | people |
|---|---|
| 1 | **38 (46%)** |
| 2–3 | 22 (27%) |
| 4–9 | 15 (18%) |
| 12–15 | 4 |
| 27–31 | **3** |

r2's category benchmark — "median engagement with Lose It: 29 days" —
describes a world Jeni has three users in. Jeni's median food-logging
life is **one day**. The failure is meal 1 → meal 2, not week 4.

Lifetime totals, all versions: 917 food logs · 418 quick-adds ·
**130 corrections opened · 50 corrections saved · 11 applied**.

### 2.3 The whole record is thin, not just food

`weight_logged` 187 events / 72 people. `weekly_review_signed` 39
events / **18 people, ever**. `food_satiety_marked` 11 / 3 (dead).
`steps_connected` 205 people, of whom 113 authorized and 13 denied —
and that event fires only from the in-app connect tile, **not** from
the onboarding HealthKit sheet (`OV5ScreensClose.requestHealthKit`,
`V8Structured.requestHealthKit`), whose outcome is recorded nowhere.
**Actual passive-signal coverage is unmeasurable today.**

There is **zero medication telemetry** (v24 shipped none, as
`00_THE_SYSTEM.md` §4 already admitted) and **zero cohort telemetry** —
`Glp1Cohort` drives branching throughout the app and never reaches
analytics. We cannot currently state what share of Jeni's users are
medicated. That is a decision-relevant unknown created by our own
instrumentation gap.

Stated goals (n = 2,417): loseWeight 1,752 · fullBody 490 · toneCore 75
· growGlutes 68 · slimLegs 54.

### 2.4 The number that reframes everything

**Nothing built since 2026-08-07 has ever been in a user's hands.**

Live population by build, last 45 days: 1.1.3 (355) · 1.1.6 (317) ·
1.1.2 (308) · 1.1.5 (296) · 1.1.4 (180). 1.2.0 has 90 (mostly
TestFlight), 1.1.7 has **9** (all today), 1.3.0 has 6.

`feat/app-v2` is **448 commits ahead of `main`**. v21 THE INSTRUMENT,
v22 ONE HAND, v23 THE STILL LIFE, v24 THE REGIMEN and v25 E1 THE SPINE
are all inside those 448 commits. Every food number in §2.2 was
produced by the module v23 deleted. Every conclusion about medication
is unmeasured because v24 has never run for a user.

Only 38 people have ever completed onboarding v8.

**We are choosing the sixth consecutive unreleased era.** That is the
single largest risk to whatever we choose, and it is the reason the
chosen era below carries a shipping obligation rather than a test count.

---

## 3 · RESEARCH: WHERE THE EXISTING RECORD IS WRONG

`research/r1`–`r6` are strong and same-day fresh; I did not re-run
them wholesale. I re-checked the load-bearing citations. One is
materially misreported, and it is the one E4 rests on.

### 3.1 SnappyMeal does NOT support the clarifying question

`r2 §2` records: *"clarifying felt collaborative not burdensome; …
accuracy beat single-modality baselines — PROMISING, directly
actionable"*, and `r2` implication #2 makes "add ONE low-confidence
clarifying question to the vision EF" the second-ranked action.

The paper (Bakar et al., UW, arXiv 2511.03907) says the opposite:

> "Contrary to expectations, we observed no conclusive evidence that
> the follow-up questions directly improved nutrition estimation. …
> the model may be second-guessing itself; generating a question,
> receiving an imperfect or ambiguous answer from the user, and then
> allowing that conflicting information to degrade the final
> estimation rather than refine it."

Ablation, calories MAE (n = 100), lower is better:

| model | MAE | vs vanilla |
|---|---|---|
| vanilla | 148.88 | — |
| **RAG + receipt** | **123.96** | **−17%** |
| RAG | 145.45 | −2% |
| follow-up | 161.82 | **+9% worse** |
| RAG + follow-up | 168.87 | **+13% worse** |
| RAG + receipt + follow-up | 153.00 | **+23% worse than RAG+receipt** |

Their Table 5 shows a correct user answer ("three strips of bacon")
*raising* calorie MAE from 101 to 173 because the model re-reasoned the
whole plate around it. The longitudinal arm is **n = 6** university
students over 3 weeks, self-report means 3.67–4.33 on 5-point scales.

**What survives: retrieval-grounded estimation from known-nutrition
neighbours + explicit external data (receipts).** What does not: the
clarifying question as an accuracy mechanism, and — critically —
**letting a model re-estimate a whole plate after receiving a
correction**, which is exactly what `SnapRefine.fixWords` ships today.

Search also re-confirms r2's credibility warning: the 2026 "benchmark"
pages now claim PlateLens ±1.2% MAPE and Welling ±1.3% "against bomb
calorimetry". Both are physically implausible and both are the SEO
genre r2 flagged. Treat as **GIMMICK**; never cite, never imitate.

### 3.2 What the record gets right and should keep driving

- **PROVEN** — a weekly ritual that ends in a plan change is the
  strongest retained mechanic in consumer health (r6 §8; MacroFactor,
  WHOOP WPA, Oura). E1 built it.
- **PROVEN** — a loop that depends on daily willpower decays whatever
  its content quality (Headspace D30 ≈ 4.7% despite 50+ efficacy
  studies). The loop must ride something that recurs by itself.
- **PROVEN lived pattern** — the GLP-1 week: day 1–2 peak, day 3–5
  sweet spot, day 6–7 hunger and food noise return (r1 §4).
- **PROVEN tension** — the category's most-loved artifact (the
  medication-level curve) is pseudo-quantitative; time-to-peak varies
  8–72 h. Our provenance law already forbids it.
- **GAP, still open Aug 2026** — no major app encodes missed/late-dose
  label rules at log time; Shotsy alone has a Maintenance Mode;
  nobody tracks the underreported symptom set (hair, menstrual,
  temperature, mood) that the 400k-post UPenn analysis surfaced.

---

## 4 · SCORING

Criteria weighted for Jeni's *actual* situation: a rebuilt-but-
unreleased product, a median paying customer with two active days, B2B
gates (BAA, counsel, insurance) not yet cleared, and no telemetry on
anything built in the last four eras.

| criterion | weight | why this weight |
|---|---|---|
| retention / return | **×3** | the measured business failure |
| leverage from E1 | ×3 | eras must compound, not accumulate |
| works at current scale | **×3** | *new* — mechanics that need volume we don't have are not shippable value |
| differentiation | ×2 | trust-burned category rewards it |
| B2C value | ×2 | B2C is the live business |
| data that compounds | ×2 | "difficult to replace" |
| one-system feel | ×2 | founder's standing law |
| frequency | ×2 | mechanism of retention |
| user value | ×2 | |
| clinical defensibility | ×1.5 | floor to clear, not a prize |
| acquisition | ×1 | conversion is fine; the leak is after |
| B2B value | ×1 | E6 is where B2B lands; gates pace it |
| implementation risk | ×1 | both candidates are tractable |

Scores 1–5.

| | **E2 medicated year** | **E4 plate's memory** | E3 movement | E5 dispersal | E6 queue |
|---|---|---|---|---|---|
| retention (×3) | 4 | 4 | 2 | 2 | 1 |
| E1 leverage (×3) | **5** | 3 | 3 | 4 | 3 |
| works at current scale (×3) | **5** | **1** | 3 | 3 | 2 |
| differentiation (×2) | **5** | 3 | 3 | 3 | 5 |
| B2C (×2) | 4 | 5 | 3 | 4 | 1 |
| compounding data (×2) | 4 | 5 | 2 | 2 | 3 |
| one system (×2) | 5 | 4 | 3 | 4 | 3 |
| frequency (×2) | 3 | **5** | 3 | 3 | 2 |
| user value (×2) | 5 | 5 | 4 | 3 | 4 |
| clinical (×1.5) | **5** | 4 | 4 | 4 | 3 |
| acquisition (×1) | 2 | **5** | 2 | 2 | 1 |
| B2B (×1) | 5 | 3 | 3 | 4 | 5 |
| impl. risk (×1, 5=low) | 4 | 3 | 3 | 3 | 2 |
| **weighted total** | **114.5** | **97.0** | 74.5 | 80.0 | 62.5 |

The decisive row is the new one. **Every E4 mechanic requires
accumulated per-user behaviour that does not exist**: corrections-as-
priors (50 saved corrections lifetime, against the original design's
own 50,000 target), the day-29 décrescendo (median logging life: 1
day), repeat-share ≥25% (needs a repeat population), "correction rate
observed then DECLINING per dish" (needs dishes). Its four stated
success metrics in `00_THE_SYSTEM.md` §15 are all currently
unmeasurable.

**Every E2 core mechanic works on the first dose**, from the schedule
and the catalog — data Jeni holds the moment she says "Wegovy,
Tuesdays." Its compounding horizon is three cycles (three weeks); E4's
is three months. At a median of two active days, only the three-week
horizon is reachable.

---

## 5 · THE DECISION

### Next era: **E2 — THE MEDICATED YEAR**, re-cut.

The roadmap's *order* stands. Its *scope* changes, for reasons the
original scoring could not see:

**Added to E2** (because the evidence demands it):
1. **The dose enters the read, and so does weight.** The read is E1's
   defining loop and its emptiest room. This is not polish; it is the
   difference between a ritual and a step counter.
2. **Production telemetry, verified live.** E1 coded the event
   families; none has ever fired for a user. Nothing else in this
   roadmap is decidable until they do. Includes **cohort identity as a
   categorical property**, so "how many of our users are medicated" is
   answerable for the first time.
3. **A shipping obligation.** The era is not done at 709 → N green
   tests. It is done when a real user's dose day is observed.

**Removed from E2** (deferred, not cancelled):
- **The maintenance era.** Jeni has no at-goal users; the seeded
  program walks at day 12. Build it when the first cohort arrives at
  goal — the chains are ready and will still be ready.
- **The dose-era annotated weight curve.** A chart pass; lower value
  than the read integration that carries the same facts.
- **Switch / travel beats.** Real (CVS-Zepbound whiplash is
  documented) but low frequency. Rider if cheap, cut if not.

**Explicitly NOT in E2** (standing): PK curves, dosing math, microdose
or stretching presets, compounded-vial calculators, clinic UI, mascots,
new tabs.

### Roadmap change: **E4 moves behind a measurement gate, and is re-cut when it runs.**

E4 stays the era after next, but may not start until v23's food module
has a **measured baseline in production** (logs per activated user,
meal-2 rate, correction rate). When it runs, the SnappyMeal evidence
re-cuts it:

- **IN:** retrieval-grounded priors over her own corrected history
  (the ablation's only winner), corrections persisted as first-class
  records with a stable dish key, "again" as a real repeat, retro and
  partial legitimacy.
- **DEMOTED to a measured experiment:** the ONE clarifying question.
  It has negative primary evidence. If built, gate it on
  `needs_second_photo` (already on the wire) and apply the answer
  **deterministically** — never by asking the model to re-estimate the
  plate.
- **FIX FIRST, as a defect:** `SnapRefine.fixWords` currently does the
  thing the paper shows degrades unrelated items. One correction should
  not be able to move the calories of a dish it never mentioned.

### The elephant, named plainly

448 unmerged commits containing four complete eras. The best era in the
world does not help a user on 1.1.6. **The founder gates
(`20260809090000` + `20260810090000` migrations, `jeni-chat` and
`food-vision` deploys, ElevenLabs key rotation, device walks, App
Store) are now the highest-leverage work in the project, and they are
not work a Fable session can do.** E2 is scoped so that it lands *with*
that release rather than behind another one.

---

## 6 · DECISION LEDGER

| # | decision | why | declined |
|---|---|---|---|
| N1 | E2 next | works at zero accumulated data; rides the only cadence that recurs without willpower; fills E1's emptiest room | E4 first (its whole thesis needs volume we don't have) |
| N2 | the read gains the dose AND weight | "your dose week" with no dose, in a weight-loss app with no weight, is the loudest hole in the shipped spine | leaving the read to a later polish pass |
| N3 | production telemetry is IN scope, not a rider | four eras are unmeasured; no further prioritisation is honest without it | another era of green tests |
| N4 | maintenance era deferred out of E2 | no at-goal users exist; the chains keep | shipping it for a population of zero |
| N5 | E4 gated on a v23 baseline | we replaced the food module three days ago and have never seen it run | optimising an unobserved rebuild |
| N6 | clarifying question demoted to experiment | primary source shows it degrades estimates (§3.1) | shipping it as designed on a misread citation |
| N7 | `SnapRefine` full-plate re-estimation treated as a defect | same source; a correction must not move unmentioned items | leaving it until E4 |
| N8 | cohort identity instrumented | the GLP-1 cohort strategy is unmeasured; E2's own audience is unknown | continuing to guess |
| N9 | dead food code swept with the era it touches | `FoodCorrectionSheet` + `CaptureFlowView` are unreachable; the v23 S11 sweep missed them | leaving orphans that read as shipped features |
