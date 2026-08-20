# THE BORING WEIGHT-LOSS APP — a product audit

**Status: BUILT 2026-08-14.** Not an era. A product audit against one
standard, taken from the brief:

> Remove every sentence containing INSIGHT · PATTERN · JOURNEY ·
> TRANSFORMATION · BECOMING · PERSONALIZED · AI · SMART · COACHING.
> **Would the remaining product still be worth paying for?**

`32` froze the release candidate and `33` asked whether Jeni is a good
daily tool. This session asked whether the boring half — the tools, not
the intelligence — is *complete*: can she log, know, correct, and keep
everything the product implies she owns.

Nothing in the frozen candidate moved. No change to the calorie formula,
the protein formula, the merge contract, plan selection, the restore
path, payment, paywall, auth, `AppPhase`, `Info.plist`, entitlements,
migrations, the analytics contract, or any HealthKit type.

---

## THE PRODUCT THESIS

**Yes — and it was failing on one thing, in four places.**

Strip the intelligence words and what is left is: log food by sentence or
photo in two taps · a plan whose every input is visible and editable in
one screen · a protein floor with a cited band · a calorie remainder ·
a weight trend that refuses to speak before it can · a shot log with a
site and a date · a clinician PDF. That is a product, and most of it is
better than the references.

What it was failing at is not a feature. It is a tense.

> **JENI WAS A WRITE-ONLY RECORD IN THE PAST TENSE.**
>
> Every write path in the product stamps today and refuses to look back.
> Food: `let loggedAt = Date()` at persist, and again at relog. Weight:
> update today's row, else insert a new one at `.now`. Side effects:
> `dayKey: TodayStateService.dayKey()` as a default argument on both the
> record and the remove. Dose corrections: the open slot only. Deleting
> a plate was the single exception in the whole product.

That is not an edge case. It is the ordinary week:

- she logs dinner at 12:10am and it lands on **tomorrow**, taking
  700 kcal off the day it fed, permanently;
- she remembers lunch the next morning and there is **nowhere to put
  it**;
- she steps on the scale with shoes on, notices the next day, and the
  number is **stuck in her trend forever** — and while it is the
  freshest row it is the numerator of her calorie target and her protein
  floor;
- she records nausea on the wrong day and **cannot move it**.

Three sessions in a row named "logging food to a past day" as the
largest remaining boring gap and deferred it as a write-path change on a
frozen candidate. The weight half had never been named at all.

**Two of the four are closed in this build, at the smallest honest
size.** Two are named with the exact failure, the recommended behaviour
and the blast radius.

---

## THE BORING FEATURE INVENTORY

Every customer-facing capability, walked in the running app or traced to
its call sites. VERDICT is one of KEEP · FIX · SIMPLIFY · REMOVE · DEFER.

Legend: **W**orks · **A**ccurate · **E**ditable · **S**ynced ·
**J**eni-aware · **D**esign-consistent. `~` = partly. `—` = n/a.

### FOOD

| feature | user job | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|---|
| photo logging | log a plate in front of her | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | KEEP |
| words logging (the front door) | log by sentence | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | KEEP |
| label photo | read a printed panel | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP (EF gate) |
| barcode | packaged food | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| again (relog) | repeat a meal, 2 taps | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| quick add | a number she already knows | ✓ | ✓ | ✓ | ✓ | ✓ | ~ | KEEP |
| kcal · protein · carbs · fat | the plate | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | KEEP |
| fiber · sugar · sodium | the rest | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | KEEP |
| micronutrients | — | — | — | — | — | — | — | REFUSED on evidence (`26`) |
| portion / servings (`PlateShare`) | how much of it she ate | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| fix with words | correct the model | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| delete a plate | remove it | ✓ | ✓ | ✓ | ✓ | — | ✓ | KEEP |
| **re-date a plate** | put it on the day she ate it | **✓ NEW** | ✓ | ✓ | ✓ | ~ | ✓ | **BUILT** |
| log directly to a past day | — | ✗ | — | — | — | — | — | DEFER — re-dating covers it in two steps |
| THE BOOK | the record | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| meal buckets | "what did I eat for lunch" | ✗ | — | — | — | — | — | DEFER (schema) |
| food text search | — | ✗ | — | — | — | — | — | DON'T BUILD (`33`) |

### WEIGHT

| feature | user job | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|---|
| weigh-in ritual | today's number | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| chat `log_weight` | say it instead | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| Apple Health import | passive | ✓ | ✓ | ~ | ✓ | ✓ | — | KEEP |
| **the list of weigh-ins** | see them | **✓ NEW** | ✓ | ✓ | ✓ | ✓ | ✓ | **BUILT** |
| **correct one weigh-in** | fix a typo from any day | **✓ NEW** | ✓ | ✓ | ✓ | — | ✓ | **BUILT** |
| **remove one weigh-in** | take it out | **✓ NEW** | ✓ | ✓ | ✓ | — | ✓ | **BUILT** |
| current weight | what do I weigh | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| start weight | where did I start | ✓ | ✓ | ✗ by design | ✓ | ✓ | ✓ | KEEP |
| goal weight | where am I going | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| trend (EMA) | am I actually losing | ✓ | ✓ | — | ✓ | ✓ | ✓ | KEEP |
| `WeightJourney` | start · now · to go | ✓ | ✓ | — | ✓ | ✓ | ✓ | KEEP |
| units lb/kg | her unit | ✓ | ✓ | ✓ | device-level | ~ | ✓ | KEEP |
| BMI | — | shown only in the body tile's estimate ladder | | | | | | KEEP |

### PROGRAM

| feature | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|
| plan create (onramp → setup) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| program day (`day N`) | ✓ | ✓ | — | ✓ | ✓ | ✓ | KEEP |
| calorie target | ✓ | ✓ | via inputs | ✓ | ✓ | ✓ | KEEP |
| protein target | ✓ | ✓ | via weight | ✓ | ✓ | ✓ | KEEP |
| step target | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| pace / horizon | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| goal date | ✓ | ✓ | derived | ✓ | ✓ | ✓ | KEEP |
| maintenance | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| `your numbers` (7 inputs) | ✓ | ✓ | ✓ | ✓ | **✓ NEW** | ✓ | KEEP |
| program repair (merge + heal) | ✓ | ✓ | — | ✓ | — | — | KEEP |
| weekly read | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| `EditProfileView` ("your pace", edits `workoutLevel`) | ✓ | ~ | ✓ | ✓ | ✗ | LEGACY | **REMOVE** |

### MOVEMENT · BODY

| feature | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|
| steps (HealthKit) | ✓ | ✓ | — | — | ✓ | ✓ | KEEP |
| step goal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| JENI MOVE (the record) | ✓ | ✓ | ✓ | — | ✓ | ✓ | KEEP |
| manual move entry | ✓ | ✓ | ~ | ✗ device-local | ✓ | ✓ | FIX (sync) |
| guided workout library | ✓ | — | — | ~ | ✗ | LEGACY | DEFER (retirement trigger exists) |
| breathwork | ✓ | — | — | ✓ | ✓ | ✓ | KEEP |
| Body Scan | ✓ | words-only | ✓ | opt-in | ✓ | ✓ | KEEP, demoted |

### MEDICATION (GLP-1)

| feature | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|
| regimen setup + version chains | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| dose day / next dose | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| mark a dose (taken/skipped/late) | ✓ | ✓ | same-day + open slot | ✓ | ✓ | ✓ | KEEP |
| injection site + rotation | ✓ | ✓ | at mark time | ✓ | ✓ | ✓ | KEEP |
| `the doses` (the shot log) | ✓ | ✓ | **✗ read-only** | ✓ | ✓ | ✓ | **FIX — named** |
| side effects + severity | ✓ | ✓ | **today only** | ✓ | ✓ | ✓ | **FIX — named** |
| side-effect history | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | FIX — named |
| reminders | ✓ | ✓ | ✓ | ✓ | — | ✓ | KEEP |
| VisitPacket (clinician PDF) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | KEEP |
| medication-level curve | — | — | — | — | — | — | REFUSED, four times |

### SUPPLEMENTS

| feature | verdict |
|---|---|
| `RegimenService.supplementPlans` | **REMOVE — dead code.** Zero call sites anywhere in the app. `RegimenPlanRecord.kind` accepts `"supplement"` and nothing ever writes one. **There is no supplement feature in Jeni.** The brief asked for "everything actually live"; the honest answer is nothing. |

### JENI

| feature | W | A | E | S | J | D | verdict |
|---|---|---|---|---|---|---|---|
| chat | ✓ | ✓ | — | ✗ device-local | — | ✓ | KEEP |
| envelope (the record, one object) | ✓ | ✓ | — | ✓ | — | — | KEEP |
| 8 read tools | ✓ | ✓ | — | ✓ | — | — | KEEP |
| 5 write/propose acts | ✓ | ✓ | ✓ | ✓ | — | ✓ | KEEP |
| 7 navigation acts | ✓ | — | — | — | — | ✓ | KEEP |
| memory (`what jeni remembers`) | ✓ | ✓ | ✓ | **✗ device-local** | — | ✓ | **FIX — named** |
| **`targets.inputs` + `doors`** | **✓ NEW** | ✓ | — | — | — | — | **BUILT** |

### BECOMING · METHOD · SETTINGS

| feature | verdict |
|---|---|
| Becoming tiles + scope bar | KEEP |
| week read / re-signing | KEEP |
| THE BOOK door · **`your weigh-ins` door (new)** · visit packet · check-in | KEEP |
| CONSISTENCY card ("3 days in a row") | a streak by another name — **P2, unchanged** (`33`) |
| `MethodEngine` — 15 rule-based notes | **KEEP. This is the Jeni Method.** |
| `MethodToldView` — what jeni told you | KEEP |
| 14-lesson `LessonID` corpus (`JeniMethodReReadView`) | **REMOVE — unreachable.** `go(.jeniMethod)` has zero call sites; the route exists in `ProfileHubView`'s switch with no row that reaches it. |
| 84-day CBT manifest (`LessonManifest` · `LessonReaderView`) | **DEFER — unreachable in production**, bundled and warmed at launch. Its only non-debug reader is `RepEngine`, which has **zero call sites**. |
| Settings: your plan · goal weight · your numbers · my pace · coach · reminders · your medication · your care team · on a break · apple health · food · account · feedback · what jeni remembers · what jeni told you | KEEP |
| `EditProfileView` | REMOVE (above) |

---

## WHAT ACTUALLY WORKS

Walked, not assumed. These are load-bearing and correct:

- **One food accumulator.** Every reader in the app goes through
  `FoodLogPersister` — Home, THE BOOK, the plate page, Becoming's tiles,
  the weekly read, the visit packet, `NutrientWeekSeries`, `Signals`,
  `QuietHours`, `MethodInputBuilder`, `CareWeekSummary` and all four
  Jeni read tools. There is no second sum anywhere. The two *unscoped*
  legacy readers (`todayMacros()`, `todayKcalTotal()`) have **one**
  remaining call site between them, and it is a `userId.isEmpty`
  preview/test fallback inside `SnapResultView`.
- **One target resolver.** `TargetsService` is the only path to a daily
  calorie target for a customer; `CalorieTargetCalculator.dailyTarget`
  has exactly two call sites and the second is the pre-purchase quote,
  named as a different concept. Pinned across 25 states by
  `OneTargetEverywhereTests` and 11 golden fixtures by
  `CalorieGoldenMatrixTests`.
- **One weight ladder.** `resolvedWeightKg` — latest weigh-in › her own
  stored answer › the plan's start weight, last.
- **The refusals.** No fact, no number. `calorieTarget` returns nil
  rather than falling back to TDEE; `missingEnergyInput` names which
  fact; Home's empty denominator is a door onto it.
- **The recovery contract** (`31`): pull before push, merge on
  `pendingUpsert`, adopt-never-resurrect. Held by 7 + 12 tests.
- **The plate is honest about its own footing.** `EntryMethod
  .provenanceLine` per door; label reads say so; corrections read back
  as YOUR NUMBERS.
- **Failure is bounded.** `withScanDeadline` makes "scanning forever"
  structurally impossible — it races two unstructured tasks rather than
  using a task group, which would hang at cleanup on a parked
  continuation.

---

## WHAT ONLY TECHNICALLY EXISTS

| thing | the truth |
|---|---|
| **supplements** | `RegimenService.supplementPlans` — zero call sites. No writer, no reader, no screen. |
| **the 14-lesson Method corpus** | `JeniMethodReReadView` is wired into `ProfileHubView`'s route switch and **no row navigates to it**. |
| **the 84-day CBT curriculum** | reachable in production only via `RepEngine`, which has zero call sites. Still bundled; still warmed on every launch (`CBTCurriculumService.shared.manifest()`). |
| **`EditProfileView`** | a screen titled "your pace" that edits exactly one value (`workoutLevel`), superseded by both `my pace` and `your numbers`. |
| **the dose ledger's rows** | listed since `33`, and not tappable: a wrong site or status on a past slot has no repair. |
| **side-effect history** | recorded, charted, exported to the clinician — and `SideEffectSheet.load()` filters to `dayKey == today`, so only today can be seen or changed. |
| **Jeni memory** | written, listed, forgettable — and `JeniMemoryRecord` has no upsert and no hydrate. A new phone starts the coach's memory at zero. |
| **manual move entries** | `MoveManualStore` is UserDefaults-backed and device-local. |

---

## FOOD

Six doors — photo · label · words · again · quick-add · barcode — all
landing on `FoodLogPersister.persist`, one `FoodLogEntry` shape. Verified
as the single chokepoint in `26`/`27` and again here; no new door was
added, so no new invariant could break.

**The seam this session found is the date, not the numbers.**

```swift
// FoodLogPersister.persist
hydrateIfNeeded()
let loggedAt = Date()          // ← the only date a plate can ever have
```

`relog` does the same. So the day a meal is filed under is the day it was
*logged*, and the two diverge constantly: after midnight, the next
morning, on a plane, at a restaurant with no signal.

**BUILT: `FoodLogPersister.setLoggedDay(id:to:)`** and a `the day` row on
the plate page that opens the last fourteen days.

What it preserves: the id (so the photograph, keyed on it, travels with
the plate, and the cloud row is an UPDATE not a duplicate) · the clock
time (she ate at 9:40pm whichever day we file it under) · every nutrient,
item, correction and door. What it refuses: **a future day** — a plate
cannot have been eaten tomorrow, and a forward-dated entry would silently
subtract itself from today and reappear from nowhere.

Fourteen days, because that is the window in which a person can actually
remember a meal, and an unbounded date picker on a record is an
invitation to invent history.

**Not re-written to Apple Health.** `FoodHealthKitWriter` can only add a
sample, so a second write would double-count the energy in Health while
the first sample still sat on the old day. Named rather than half-done.

**Verified across the paths the brief lists** (packaged · restaurant ·
homemade · multi-item · drink · snack · visible and ambiguous quantities ·
model uncertainty · partial serving · repeated breakfast): the numbers a
plate carries do not change when it moves, and the day totals follow it
exactly — pinned by `testTheDayTotalsFollowThePlate`.

---

## CALORIE LEDGER

**One question, one answer, three numbers, and they agree by
construction.**

| number | source of truth | derivation | writer | sync | edit | readers |
|---|---|---|---|---|---|---|
| **consumed** | `FoodLogPersister` JSONL | Σ kcal of entries where `loggedAt >= startOfDay` | the six food doors | `food_logs` | plate page (fix · remove · **re-date**) | Home · THE BOOK · plate · Becoming · weekly read · Jeni · visit packet |
| **target** | `TargetsService.current().kcal` | `clamp(MifflinStJeor × activity − pace deficit, max(1200, BMR), 3500)` | derived only | via its six inputs | `your numbers` (7 rows) | Home · plan · Jeni |
| **remaining** | `HomeSections.energyReferenceLine` | target − consumed, stated once | — | — | — | Home only |

Three deliberate refusals hold:

1. **The remainder exists in exactly one place.** Jeni computes it from
   `kcal` and `food_today` rather than receiving a copy — shipping a
   second subtraction is how two numbers start to disagree (`33`).
2. **Maintenance gets no remainder.** An expenditure estimate is not a
   budget she was handed.
3. **No target ⇒ no number**, and the empty denominator is a door onto
   the missing fact.

There is **no widget** and no second surface. `JenifitWidgets` contains
only the scan Live Activity — it never states a calorie number.

Cross-surface agreement is not asserted here by inspection; it is pinned
by `OneTargetEverywhereTests` (25 states × 3 surfaces) and
`CalorieGoldenMatrixTests` (11 fixtures, ~23 exact integers).

---

## NUTRITION LEDGER

Jeni promises, in order: **protein** (a personal floor with a cited
band) → **energy** (one shape) → **fiber · sugar · sodium** (a place,
with `dv` marked as a general daily value and explicitly not her target)
→ carbs/fat as the day's split, no denominator.

Every one of them sums the same `FoodLogPersister` rows. `TodayMacros`
is one struct produced by one walk of the store. The plate page, THE
BOOK's ledger, Home's band, Becoming's tiles and `read_food_day` all
read it.

**Micronutrients remain refused on evidence** (`26`): one source (USDA
FDC), reached only for items the model could not price, so they exist
precisely where the plate deserves least confidence. The four
FDA-mandated label micros are written into the food-vision EF and remain
behind the standing deploy gate.

`satFat` is captured, persisted and synced and is rendered on no
customer surface. That is honest silence, not a gap.

---

## WEIGHT

**This is where the audit landed.**

`WeightLogRecord` has stored a day and a number since v1. Five engines
read it. The freshest row outranks every stored weight, so it is the
numerator of **both** the calorie target and the protein floor. And no
screen had ever listed the rows.

Becoming draws a LINE. A line is the right hero and the wrong record:
you cannot read a date off it, you cannot tell a scale-with-shoes-on
from a real morning, and **you cannot touch it**. Every other record in
the product had a list you could open and repair — plates in THE BOOK,
doses in `the doses` (since `33`), symptoms as chips. The one number the
plan is priced on had a chart.

The consequence was not cosmetic. `WeightLogWriter.persist` updates the
latest row **only when that row is today's**, otherwise it inserts a new
one at `.now`. So:

- a mistyped weigh-in noticed the same day: fixable;
- a mistyped weigh-in noticed tomorrow: **permanent**, in the trend
  forever, and moving her two daily targets for as long as it stays
  freshest;
- a weigh-in she wants gone: **no delete existed anywhere in the
  product**, not in any screen and not in chat.

### BUILT — `your weigh-ins`

A dated list, newest first, reachable from **becoming › your record**,
one row under `your plates`. Its laws, all filmed:

- every stored row is listed, including two on one day — **a row you
  cannot see is a row you cannot remove**;
- **a day word must identify exactly one row**: when a day carries more
  than one, each states its time (`yesterday · 8:02pm`), and only then;
- the change is **the difference of the two numbers on screen**
  (`165.3` over `164.9` reads `0.4 lb down`), never a smoothed value —
  the trend is `WeightEMA`'s job and the story is `WeightJourney`'s;
- **a gain is set in exactly the same words and typography as a loss**;
  there is no red, no arrow glyph, no verdict;
- provenance only when it is not hers: `from health` · `at sign-up`;
- no streak, no cadence count, no "you haven't weighed in since
  Tuesday", no rate.

Tapping a row opens the **same ruler she uses every morning**, seeded at
that row's own number, titled with that row's day, with a quiet
`remove this weigh-in` under the CTA pair.

- **A correction is the same weigh-in** — same id, same day, same user.
- **A correction to a Health row becomes hers** (`source = "manual"`).
  Not a relabel: `BodyMassImportService` re-imports the last thirty days
  on launch and overwrites any row still marked `healthkit`, so a typed
  correction that kept the source would be silently reverted by the next
  sync. Its own rule — *"manual rows always win their day"* — is the fix.
- **Removal reaches the server.** `applyHydratedWeightLogs` is
  insert-only by id, so a row deleted only on the device is re-inserted
  by the next pull. `SyncService.deleteWeightLog` is the missing half;
  the `weight_logs_delete_own` RLS policy and the DELETE grant have both
  shipped since `scripts/schema.sql`, so **no migration**.
- **Removing a Health row is stated honestly**: Apple Health still holds
  the sample and a later sync can bring it back. Cheaper than a
  tombstone column, and true.
- **Nothing in the repair touches the plan** — not the id, not the start
  date, not the start weight. Removing the freshest row falls down the
  existing ladder; removing them all falls to her own onboarding number;
  with nothing at all the target is silent and `missingEnergyInput`
  names `weight`.

The five questions the brief asks of this domain now answer without
interpretation:

| question | where |
|---|---|
| what do I weigh now | Home · your numbers · the ledger's top row |
| where did I start | the plan screen · `WeightJourney` |
| where am I going | goal weight, everywhere |
| how much have I lost | `WeightJourney` |
| how far is left | `to_go_kg`, plan screen + Jeni |
| what is the trend | Becoming's line, gated on `trendEstablished` |
| when did I last weigh in | Home's tile — **and now the exact date** |

---

## PROGRAM

**What a Jeni weight-loss program is, in concrete nouns and numbers:**

> a current weight · a start weight · a goal weight · a pace tier
> (soft/medium/hard, ACSM-floored) · a daily calorie target · a daily
> protein floor in g/kg · a daily step target · a start date · a total
> day count and a goal date · three to five daily actions · a weekly
> read that may change one fact.

Everything else the surfaces say is presentation of those twelve values.

Walked as a state machine — CREATE · VIEW · USE · EDIT INPUT ·
RECALCULATE · PROGRESS · MISS DAYS · RETURN · REACH GOAL · CHANGE GOAL ·
MAINTAIN · SIGN OUT · SIGN IN · CHANGE DEVICE — every transition is
already pinned by `29`–`32`'s suites and re-run green here. A goal edit
mutates the plan in place; a pace edit moves the horizon and not the
history; arrival is maintenance and says so; corruption is archived,
never deleted, never replaced by a third plan.

### §8 — DOES EACH ASK EARN ITS PLACE?

| the ask | behaviour it changes | number it moves | decision it helps |
|---|---|---|---|
| add a meal | the record | consumed, protein, remaining | *can I eat this?* |
| weigh in | measurement | current weight → target, floor, trend | *is this working?* |
| steps | movement | steps vs goal | *do I need a walk?* |
| mark the dose (GLP-1) | adherence | the cycle position | *did I take it?* |
| the method note | one specific action | — | *what do I do about this?* |
| breathwork | craving/impulsivity (RCT-cited) | — | *I want to eat and I'm not hungry* |
| a guided workout | — | — | **flag** — the library predates the program and has a measurable retirement trigger |
| the evening close | the record + tomorrow's reason | — | *how did today go?* |

The program is already small: `TODAY` renders **1–4 rows**. The one ask
that does not clear the bar is the guided workout, and its retirement
trigger already exists. **Nothing was added to the checklist this
session.**

---

## MOVEMENT

Steps from HealthKit against a goal that is a program fact with an
authority chain. `JENI MOVE` is the record: strength leads (lean mass is
25–39% of the loss), **energy is measured or absent** — the only
estimate is MET-based from her own entry, labelled, and never written
back to HealthKit. `resolvedStepsToday` returns nil rather than 0 when
Health has no samples, because "no samples" and "zero" are different
facts.

**One gap:** `MoveManualStore` is UserDefaults-backed and device-local, so
a manually recorded session does not follow her to a new phone. Small,
named, not fixed.

---

## BODY

Body Scan: guided rear-camera capture, `WaistCrop` + `BandProfile`
produce **words, never a number from a photograph**, local-first with
cloud backup **off by default**. Reachable from Becoming › `new
check-in` and a Home tile.

Evidence unchanged: 8 users / 90 days against food 82 and weight 72 — and
those 8 kept 56 scans. The 2024-25 self-monitoring RCT corpus covers
diet, activity and weight only; there is no evidence base for
photographic body tracking as an intervention. **Keeps its place for the
eight. Its Home tile is still the next line to cut** and was left alone
for the third session running, because a placement call with no new
evidence is not an audit finding.

**Sync caveat, stated:** with backup off (the default), body scans are
device-local. A new phone starts empty. That is the privacy posture
working as designed, and it should be said on the surface — it is not.

---

## NORMAL WEIGHT LOSS

`open → read the remainder → log by sentence or photo → the plate
answers → weigh in → the week reads back → fix what was wrong`

The last verb is new. Before this build the loop had no repair step for
anything except a plate she noticed the same day.

## GLP-1

`open → the standing line → mark it (site pre-picked, last site and the
reason stated) → log how it's sitting → the log lists every shot → the
packet goes to the visit`

Complete, with two named holes: the shot log is **read-only**, and side
effects are **today-only**.

## SUPPLEMENTS

Nothing is live. `RegimenService.supplementPlans` has zero call sites.
**Recommendation: delete the function and the `"supplement"` branch**, or
build the feature deliberately. A capability that exists only in a query
predicate is not a capability. Not deleted here — it is a cleanup, and
this session's rule was to change product behaviour only where a
customer is currently stuck.

---

## JENI CHAT

The envelope already carries: cohort · chapter · plan (day, total, tier,
phase, week intent, last re-signing) · weight (current, start, goal,
`to_go_kg`, `weeks_at_her_pace`, `goal_on_file`, EMA delta, last
weigh-in) · targets (kcal, `kcal_basis`, `kcal_missing`, protein, steps)
· today (steps, kcal, protein, the last six plates) · her evening notes ·
profile texture incl. `came_for` · medication (compound, route, cadence,
dose, cycle position, open slot, recent symptoms) · the weekly read ·
what she asked to be remembered · program facts **with their authority**
· what the Method has told her · what it would say now · the week behind
her.

Eight read tools and twelve acts. Against the brief's fifteen questions:

| question | answered | how |
|---|---|---|
| what did I eat today | ✓ | envelope `today.plates` |
| how many calories do I have left | ✓ | `kcal` − `food_today`, computed once |
| how much protein do I have left | ✓ | same |
| what was my weight last week | ✓ | `read_weight_trend` |
| log my weight as 121.4 | ✓ | `log_weight`, confirm card |
| **change my goal to 115** | **✗** | no act exists |
| what is my calorie target | ✓ | envelope |
| **why is it 1,282** | **✓ NEW** | `targets.inputs` |
| what did I have for breakfast yesterday | ✓ | `read_food_day` |
| when is my next shot | ✓ | envelope |
| did I log my shot | ✓ | `today_marked` |
| where did I inject last time | ✓ | `read_dose_history` |
| what side effects did I log | ✓ | `read_symptoms` |
| **show me my food log** | **partly NEW** | no navigation act; the envelope now names the door |
| **how do I change my goal** | **✓ NEW** | `doors.goal_weight` |
| what should I do today | ✓ | `show_today_plan` |

### BUILT — `targets.inputs` and `doors`

`31` §7 built the screen that answers *why is my target this* and *where
do I change it*. **The coach could not see it or name it.** So the
product had two front desks: the screen offered the repair and the coach
explained the number away.

The envelope now carries the target's own inputs — height, age (marked
`age_is_approximate` exactly when it came from a band), the sex term, how
she moves (`activity_is_ambiguous` when the legacy alias is
unrecoverable), the pace tier — plus a `repair_note`, and a `doors` block
naming where each record lives in her own words: `your_numbers` ·
`goal_weight` · `food_record` · `weigh_ins` · `medication`.

**Zero Edge Function deploy.** The allowlist gates tool NAMES, not
payloads (`27`). Adding `open_food_book` or a goal-weight act would be a
new tool name and therefore a founder-gated deploy — **named, not
smuggled**. What the payload can do today is let her DIRECT instead of
navigate, and that half is free.

---

## CHAT ↔ UI SYMMETRY

| fact | UI → chat | chat → UI | after sign-out/in |
|---|---|---|---|
| weight | ✓ same launch (`TodayStateService.snapshot` per turn) | ✓ `log_weight` → `WeightLogWriter.persist`, the same chokepoint | ✓ |
| **a corrected weigh-in** | **✓ NEW** — same writer, same resolver | n/a (no chat act) | ✓ |
| goal | ✓ via `PlanSummary` | ✗ no act | ✓ |
| food | ✓ | ✓ `log_food_text` → the same persister | ✓ |
| **a re-dated plate** | **✓ NEW** — `read_food_day` reads the moved row | n/a | ✓ |
| program facts | ✓ | ✓ `propose_program_fact` → `ProgramFactStore` | ✓ |
| dose | ✓ | opens the sheet; never marks for her, on purpose | ✓ |
| side effect | ✓ | no act, on purpose | ✓ |
| memory | ✓ | ✓ `remember` | **✗ device-local** |

**No parallel product.** The envelope resolves through `PlanSummary` —
the same object the screens are made of — so Home == Plan == Jeni is
structural, not coincidental. The one asymmetry is Jeni's own memory,
below.

---

## SYNC / DEVICE RESTORE

DEVICE A → sign out → DEVICE B → sign in. Traced through
`SyncService`'s fifteen families and the launch hydrate.

| data family | created on A | server has it | restored on B | UI reads it | Jeni reads it | verdict |
|---|---|---|---|---|---|---|
| profile / body facts | ✓ | `users` | ✓ | ✓ | ✓ | **EXACT** (age → band, documented) |
| program plan | ✓ | `program_plans` | ✓ merge | ✓ | ✓ | EXACT |
| weight logs | ✓ | `weight_logs` | ✓ | ✓ | ✓ | EXACT |
| **weight deletions** | ✓ NEW | ✓ NEW | ✓ | ✓ | ✓ | EXACT online; **lost if offline** |
| food entries + nutrition | ✓ | `food_logs` | ✓ | ✓ | ✓ | EXACT |
| **a plate's day** | ✓ NEW | `logged_at` | ✓ | ✓ | ✓ | EXACT |
| per-item detail + corrections | ✓ | `payload` jsonb | ✓ | ✓ | ✓ | EXACT |
| meal photos | ✓ | private bucket | ✓ | ✓ | — | EXACT (opt-out honoured) |
| day checks / progress | ✓ | ✓ | ✓ | ✓ | ✓ | EXACT |
| day reflections | ✓ | ✓ | ✓ | ✓ | ✓ | EXACT |
| observations (side effects) | ✓ | `observations` | ✓ | ✓ | ✓ | EXACT |
| regimen version chains | ✓ | `regimen_plans` | ✓ | ✓ | ✓ | EXACT |
| dose events | ✓ | `dose_events` | ✓ | ✓ | ✓ | EXACT |
| program facts | ✓ | ✓ | ✓ | ✓ | ✓ | EXACT |
| weekly reads | ✓ | ✓ | ✓ | ✓ | ✓ | EXACT |
| session logs / ratings | ✓ | ✓ | ✓ | ✓ | — | EXACT |
| consent grants | ✓ | ✓ | ✓ | ✓ | — | EXACT |
| steps / sleep / vitals | HealthKit | — | HealthKit | ✓ | ✓ | n/a — Apple's |
| **body scans** | ✓ | only if backup ON (default OFF) | ~ | ✓ | ✓ | **DEVICE-SPECIFIC, by design, unstated** |
| **manual move entries** | ✓ | ✗ | ✗ | ✓ | ✓ | **LOST** |
| **Jeni memory** | ✓ | ✗ | ✗ | ✓ | ✓ | **LOST** |
| **chat transcript** | ✓ | ✗ | ✗ | ✓ | — | **LOST** |
| weight/height unit | ✓ | ✗ | device-level | ✓ | — | by design, stated (`31` §18 G) |

**Three things a reasonable customer expects to follow her account and
does not: Jeni's memory, her chat history, and manually recorded
movement.** The memory one is the sharpest — it is listed in Settings
under *"what jeni remembers"* with a per-row forget, which reads as a
durable record of things she told her coach. It is a `@Model` with no
upsert and no hydrate.

*"No one noticed yet" is not a sync policy.* Recommended behaviour: sync
`JeniMemoryRecord` on the established pattern (a `jeni_memories` table,
insert-only by id, `pendingUpsert`-guarded). **Blast radius: a migration
plus a new sync family — the exact ordering hazard `31` §21 refused for
the age column** (the client 400s until the migration lands). It cannot
ride a build that must be safe on its own. **Founder decision: migration
first, client in the build after.**

---

## EDITABILITY

Where do I fix it?

| fact | where | past days? |
|---|---|---|
| food — the numbers | plate page → fix with words | ✓ any day |
| food — remove it | plate page → remove this plate | ✓ any day |
| **food — the day** | **plate page → the day → last 14 days** | **✓ NEW** |
| **weight — the number** | **becoming › your weigh-ins → tap a row** | **✓ NEW (any day)** |
| **weight — remove it** | **the same row → remove this weigh-in** | **✓ NEW (any day)** |
| goal weight | settings › goal weight, or your numbers | — |
| height · sex · age · activity · pace | settings › your numbers | — |
| start weight | not user-editable, deliberate; server-repairable | — |
| units | your numbers, or the weigh-in's own toggle | — |
| medication plan | regimen home (four editable facts) | version chain |
| dose — mark / unmark | dose sheet | **today + the open late slot only** |
| **dose — a past row** | **nowhere** | **✗** |
| injection site | at mark time | ✗ afterwards |
| side effect | side-effect sheet | **today only** |
| notifications | settings › reminders | — |
| account / delete | settings › account | — |

**Two remaining holes, both in the GLP-1 half, both named not built:**

1. **The dose ledger is read-only.** `MedicationLog.resolve` already
   takes a `slotDayKey` and already handles `.unmark`, so the machinery
   exists — what is missing is a tap target on the row and a decision
   about how far back a dose may be re-marked. Recommended behaviour:
   tapping a row opens the dose sheet for that slot, with the same
   site/status/skip-reason vocabulary. Blast radius: `RegimenSheet` +
   `DoseSheet` (a slot parameter it mostly has). **Not built: it is a
   clinical-record write path, and this session had already spent its
   write-path budget on the two families that reach every user.**
2. **Side effects are today-only** by default argument, in `load()`,
   `record` and `remove` alike. Recommended behaviour: the sheet takes a
   day, and the regimen home's symptom history rows open it on their
   own day. Blast radius: `SideEffectSheet` + one call site.

---

## ERROR STATES

Tested against the brief's list.

| failure | behaviour | honest? |
|---|---|---|
| camera fails | frozen shot kept, explicit `try again` reusing the same photo | ✓ |
| no food in frame | a named banner, back to the live camera | ✓ |
| food AI fails | *"couldn't read your plate just now. try again?"* — never a fabricated plate | ✓ |
| words door fails | *"couldn't read that just now. try rephrasing?"* | ✓ |
| scan hangs | `withScanDeadline` guarantees resumption; two unstructured tasks raced, not a task group | ✓ |
| barcode not found | falls to the photo path | ✓ |
| barcode network blink | *"the connection blinked · hold the code steady"* | ✓ |
| nutrition incomplete | a missing nutrient renders **nothing**; 0 is never printed as a measurement | ✓ |
| HealthKit unavailable | *"nothing has come through from health today."* — an absence is not a zero | ✓ |
| sync unavailable | the pull throws and is caught per table; local state renders; the push stays queued | ✓ |
| Jeni unavailable | *"jeni couldn't answer just now. try again in a moment."* + a retry that deletes the failed turn rather than stacking | ✓ |
| photo upload fails | the entry is kept; the photo re-tries on the next hydrate sweep | ✓ |
| medication data incomplete | routing always closes; a compounded product gets no-label truth | ✓ |
| **a weigh-in removed offline** | **the local row goes; the server delete is lost and the row returns on the next hydrate** | **NAMED — matches `deleteFoodLog`/`deleteDoseEvent`; closing it properly needs a tombstone** |

No fabricated answers, no endless spinners, no silent taps, no
destructive retries.

---

## EMPTY STATES

| tool | at zero | verdict |
|---|---|---|
| Home food band | protein leads with the floor; kcal has no denominator and **is a door** onto the missing fact | ✓ |
| THE BOOK | *"nothing kept yet. every meal you add lands here, with the photo you took."* | ✓ |
| **your weigh-ins** | *"nothing on file yet. every weigh-in lands here with its date, and you can fix or remove any of them."* — **filmed** | ✓ NEW |
| your numbers | seven `not set` rows and *"your daily food target needs a weight, your height and a goal weight. we won't guess it."* — **filmed** | ✓ |
| weight trend | *"your trend needs a few more weigh-ins."* | ✓ |
| Move | a sentence, not a `0 of 2` hero (`26`) | ✓ |
| medication | the Settings door exists for everyone and announces nothing | ✓ |
| side effects | the chip cloud at rest | ✓ |
| Jeni desk | the claim only when there is genuinely nothing | ✓ |
| Becoming tiles | below-floor tiles fold into `N reads` rather than rendering empty | ✓ |

Each answers *what is this · why use it · what do I do*, in one or two
sentences. No inspirational essays.

---

## DESIGN SYSTEM AUDIT

Anchors: onboarding · Home · Becoming · camera snap. **Not redesigned.**

Mechanical sweep of every non-anchor customer surface (43 files):
**zero** `Form`, **zero** `List`, **zero** `navigationTitle`, **zero**
system colour tokens outside `SettingsChrome`'s four. Every surface
builds from `Palette` / `Typo` / `Space` and the JeniKit primitives; the
food package uses its own `FoodTheme`, which came home in v22.

- **JENI**: Home · Becoming · THE BOOK · scan chooser · plate detail ·
  your numbers · goal ritual · MOVE · dose sheet · side effects ·
  regimen home · weekly read · VisitPacket · ProfileHub · **your
  weigh-ins (new)**.
- **LEGACY JENI**: `EditProfileView`; the 14-lesson Method corpus and
  the CBT reader (both unreachable).
- **GENERIC SWIFTUI**: none reached.
- **FOREIGN PRODUCT**: none.

**The two additions invented no vocabulary.** `your weigh-ins` borrows
`FoodJournalView`'s masthead, the regimen home's row grammar and the
morning ruler; the plate's day picker borrows the side-effect sheet's
expand-in-place panel. One new law was written and it is a subtraction:
**a day word must identify exactly one row**, so the time appears only
when a day carries more than one weigh-in.

### AX5 + SE

Re-walked at `content_size accessibility-extra-extra-extra-large` and on
the SE.

- **No numeral wraps or truncates at any size** on either new surface:
  `163.6 lb` · `164.2 lb` · `166.2 lb` · `610 kcal` · `34 g`.
- The ledger rows stack day-over-value-over-change from `xxxLarge`, the
  same rule `HomeNutritionSummary.stacksForType` has used since E9 and
  `33` applied to the regimen home.
- The whole record plus its footnote fits one SE screen.
- VoiceOver reads a row as one sentence — *"yesterday · 8:02pm, 164.2 lb,
  1.4 lb down, from health"* — and carries the disambiguating time.

---

## SHEET VS DESTINATION AUDIT

`33` classified every presentation and promoted the one real offender
(the regimen home, 0.68 → `.large`). Re-checked, unchanged, plus:

| surface | class | presentation | verdict |
|---|---|---|---|
| **your weigh-ins** | **DESTINATION** — a whole record plus an editor | `fullScreenCover` | correct by construction |
| the plate's day picker | **QUICK ACTION** inside a destination | expands in place | correct — a sheet inside a sheet is the pattern `JKWeightRitual` retired |

No sheet was mechanically converted. The information architecture
decided both.

---

## LOSE IT CAPABILITY MATRIX

Read from 78 frames (`~/Pictures/screenshots/loseit`), including the Log
tab, the Goals tab and the food edit, inspected directly this session.

| capability | Lose It | Jeni | verdict |
|---|---|---|---|
| calories remaining | `1,687 Under`, the whole product | `· 736 left` (`33`) | level |
| **the date is a global control** | `‹ Thu, Aug 13 ›` on every tab | strip selects a day on Home, read-only | **PRINCIPLE COPIED, not the pager** — see below |
| **log to a past day** | one tap | **✗ → the plate's day is now correctable** | **PRINCIPLE COPIED** |
| protein | a row among macros | the lead, a ring, a personal floor, a cited band | JENI BETTER |
| photo logging | a door among many | the product | JENI BETTER |
| words logging | ✗ | the front door | JENI BETTER |
| barcode | ✓ | ✓ | parity |
| food text search | huge DB | ✗ | DON'T BUILD (`33`) |
| meal buckets + per-meal suggestion | ✓ | ✗ | USEFUL, NOT FOR JENI (schema + a second mental model) |
| recent / repeat | ✓ | again rail, on the door | JENI BETTER |
| the day's food as a list | the Log tab IS it | THE BOOK's ledger (`33`) | level |
| edit an entry | inline Edit/Delete | fix words · relog · remove · **re-date** | JENI BETTER |
| change serving | ✓ | `PlateShare`, servings of the DISH | JENI BETTER |
| weight logging + history + trend | ✓ | ✓ | level |
| **weight history as a list** | ✓ | **✗ → BUILT** | **PRINCIPLE COPIED** |
| **edit / delete a weigh-in** | ✓ | **✗ → BUILT** | **PRINCIPLE COPIED** |
| goal + pace editing | ✓ | ✓, with the BMI-18.5 clamp stated | parity+ |
| every input to the target, visible | ✗ | `your numbers`, 7 rows | JENI BETTER |
| water | logged + a target | refused, four times | deliberate |
| exercise adds calories back | ✓ | **✗ deliberate** — no exercise compensation, ever | JENI BETTER |
| reports / export | premium | VisitPacket PDF | JENI BETTER |
| streaks · badges · challenges | ✓ | ✗ | NOT WORTH COPYING |
| **blurred premium teasers over her own data** | Dashboard AND Goals | ✗ | **NOT WORTH COPYING** — it makes her own record feel rented |

**Why the principle and not the pager.** Making the date a global
control is an IA change to two of the four surfaces the founder has
named as the product's strongest expression. The customer expectation
underneath it is *"I can put a thing on the day it happened, and I can
fix the day I put it on"* — and that is now true for the two records
that matter, from inside the record itself. If the census or real usage
later says re-dating is being reached often, the pager is the honest
next step. **Named, not smuggled.**

## MEAGAIN CAPABILITY MATRIX

62 frames. Unchanged from `33` except one line:

| capability | MeAgain | Jeni |
|---|---|---|
| dose history list | "Show All Dose Logs" | ✓ since `33` |
| **edit a past dose log** | ✓ | **✗ — the ledger is read-only** |
| side effects | 6 sliders 0–10 | 14 chips × 3 severities, incl. the four under-reported ones |
| **log a side effect for a past day** | ✓ | **✗ — today only** |
| medication-level curve | ✓ + a modal admitting it ignores individual variation | refused | 
| protein / fiber / water trio | ✓ | protein + fiber; water refused |

## SHOTSY CAPABILITY MATRIX

26 frames. Its whole proposition is three facts — *next shot · next site
· progress* — and Jeni answers all three. The one thing it does that
Jeni does not is let a user **correct a past shot log**. Same gap as
MeAgain, named above.

---

## THE JENI METHOD TODAY

Three systems carry the name. Only one is alive.

1. **`MethodEngine` + `MethodCatalog` — 15 rule-based JITAI notes.**
   Evidence-led (Koh et al 2025, JMIR 27:e76625: of 35 JITAI weight
   studies, educational information was used in 5; prompts 33, feedback
   24; 68.6% rule-based). Each note has WHO/WHEN/WHY/AFTER/QUIET and a
   required action. **Silence is a return value; there is no fallback.**
   A clinician's note is the same type with `authority = .careTeam`.
   Reached from Home's `the method` tile and the lesson beat.
2. **`MethodLedger` + `MethodToldView`** — what she has already been
   told, so Jeni does not re-teach it. Live, in Settings.
3. **The 14-lesson `LessonID` corpus and the 84-day CBT manifest** —
   **unreachable in production.** `go(.jeniMethod)` has zero call sites;
   `RepEngine`, the manifest's only production reader, has zero call
   sites. Still bundled, still warmed at launch.

## THE JENI METHOD I WOULD KEEP

**Exactly (1) and (2), and they already are the whole method.** Derived
from what the product actually does rather than from a slogan:

> **TRACK WHAT MATTERS · HIT THE FEW TARGETS THAT MATTER · ADJUST FROM
> REAL DATA · KEEP GOING.**

is close, and it is not quite right for this product, because it
describes a user's job rather than the app's promise. What Jeni's tools
actually implement is:

> **PUT IT ON THE RECORD. HIT THE PROTEIN FLOOR. LET THE TREND SPEAK,
> NOT THE DAY. CHANGE ONE THING A WEEK. FIX WHAT'S WRONG.**

Every verb maps to exactly one excellent tool: the six food doors · the
protein ring with its cited band · `WeightEMA` + `WeightJourney` refusing
to speak below `trendEstablished` · the weekly read's one offer · and —
as of this build — the two repair surfaces. **The fifth verb had no tool
until today, which is why it was missing from every previous statement of
the method.**

## CONTENT I WOULD DELETE

1. The 14-lesson `LessonID` corpus and its re-read index — unreachable.
2. The 84-day CBT manifest, reader and illustrations — unreachable in
   production, and it is bundle weight on every install.
3. `RepEngine` — zero call sites.
4. `EditProfileView` — a screen titled "your pace" that edits
   `workoutLevel`.
5. `RegimenService.supplementPlans` — a query for a feature that does not
   exist.
6. `SafetyCheckInView`'s fabricated 65 kg body (`30` §6), still there.
7. `EnergyLedger.spentKcal` / `isLighterDay` — dead since E8.1.
8. `StepsBentoTile` — zero call sites, and the last surface in the repo
   carrying "every step counts".
9. The legacy v4.5 `OnboardingView` — DEBUG-only, and the last surface in
   the repo carrying Title-Case encouragement.

**None deleted this session.** Every one is unreachable or inert, so none
of them is currently costing a customer anything, and `32` §12's rule
stands: *an ugly compatibility shim is preferable to corrupting an old
payer.* They are a cleanup pass with its own build, and the list is now
written down with its evidence.

## CONTENT I WOULD REWRITE

Read every important customer-facing string on the surfaces this audit
reached, then swept the whole source for the brief's own archetypes.
**Zero wellness-filler strings are reachable in production.** The
measured result, so the claim can be checked rather than believed:

| pattern | files | reachable? |
|---|---|---|
| "part of your journey" · "best version of yourself" · "listen to your body" · "small choices add up" · "you've got this" · "crushing it" · "keep it up" · "way to go" | **0** | — |
| `"amazing"` | 2 | one is inside `PlateAnswerEngine`'s **banned-word list**; the other is a quote in the legacy `OnboardingView`, which mounts only under `--onboarding-v4` in a DEBUG build |
| `"proud of you"` | 1 | a comment recording that the cue was **dropped** |
| `"every step counts"` | 1 | `StepsBentoTile`, which has **zero call sites** — dead code |

Four prior sessions removed that register and it has not grown back.

What is left is two small things, both flagged not fixed:

- **the four-way pace vocabulary** (consult `soft/steady/focused` · setup
  `soft/medium/hard` · Home and `your numbers` `gentle/steady/strong`).
  P2 since `32`; a release candidate is not a naming pass.
- **the CONSISTENCY card** ("3 days in a row") — a streak by another
  name, predating this line of work.

## FEATURES I WOULD REMOVE

`EditProfileView` · the unreachable Method corpora · `RepEngine` ·
`supplementPlans` · `SafetyCheckInView`. All inert; all listed with
evidence above.

## FEATURES I WOULD FIX

1. **The dose ledger is read-only** — a wrong site or status on a past
   slot has no repair (P1 for a GLP-1 payer).
2. **Side effects are today-only** (P1 for a GLP-1 payer).
3. **Jeni's memory does not sync** (P1, needs a migration first).
4. **Manual move entries do not sync** (P2).
5. **Body-scan device-locality is unstated** on the surface (P2).
6. **A weigh-in deleted offline returns** (P2, matches the two existing
   deletes; a tombstone is the real fix).

## BORING CAPABILITIES ACTUALLY MISSING

1. Logging food **directly** to a past day (two steps today: log, then
   re-date).
2. Correcting a past dose log.
3. Logging or correcting a past side effect.
4. Meal labels, so *"what did I eat for lunch"* is answered by name
   rather than by time.
5. A home-screen widget.
6. Chat history and coach memory on a new phone.

---

## ONE-WEEK NORMAL LOOP

Seeded and rendered on the live build. Every day: the target is on Home
with the remainder · food logs by sentence, photo or `again` · the plate
answers in protein · the weigh-in is optional and the trend refuses to
speak before it can · **a mistake made on Monday can be fixed on
Friday.**

At the end of the week: weight history is correct and now **legible** ·
food history is correct and each plate carries the day it fed · the
program is unchanged unless the weekly read changed one fact · Jeni's
envelope resolves through the same objects · nothing disappeared,
nothing duplicated (idempotent launch reconcile, `32` §1), nothing
contradicts.

## ONE-WEEK GLP-1 LOOP

The same, plus: the standing line answers *when is my next shot / did I
take the last one* on Home in one line that draws **zero pixels** for a
non-medicated user · the mark pre-picks the site and states the last one
and why · `the doses` lists every shot at the dose she was on that week ·
side effects go on the record and into the packet.

**Two repairs are still missing from this loop and only this loop**: a
past dose row and a past symptom.

---

## BEFORE / AFTER

| surface | before | after |
|---|---|---|
| becoming › your record | new check-in · your plates · visit packet | + **your weigh-ins — every number, with its date** |
| the weight record | a line on a chart | **a dated list, each row correctable and removable** |
| a mistyped weigh-in from yesterday | permanent | **two taps** |
| the plate page | fix words · relog · remove | + **the day → the last 14 days** |
| a dinner logged at 12:10am | on tomorrow, forever | **moved to yesterday, with its numbers** |
| the coach on "why is my target 1,282?" | the name of an equation | **her height, age, sex term, movement and pace — and where to change them** |
| the coach on "show me my food log" | nothing | **"becoming › your plates"** |

Frames (scratchpad, iPhone 16 unless noted):

| frame | what |
|---|---|
| `60_weighins.png` | the ledger, 7 rows, two on one day |
| `63_weighin_editor.png` | the editor — `today's number`, `update it`, `remove this weigh-in` |
| `64_weighins_empty.png` | the empty state |
| `61_plate_day.png` | the plate's day picker, open |
| `70_weighins_ax5.png` · `72_weighin_editor_ax5.png` · `71_plateday_ax5.png` | AX5 |
| `80_weighins_se.png` · `81_plateday_se.png` | SE |
| `40_home.png` · `02_book.png` · `31_numbers.png` · `05_weighin.png` · `03_settings.png` | the unchanged anchors, for comparison |

**A fixture correction worth recording.** Three film attempts in this
session showed the paywall or the welcome screen instead of the surface
named, and each time the cause was the fixture, not the product: (a)
`--uitest-persona-home` is nested *inside* the `--uitest-persona-customer`
block, so alone it is a no-op; (b) `--uitest-seed-program` overwrites the
persona's body facts with maya's 75/65/165/29, so the two doors are
contradictory; (c) after a `simctl erase` the anonymous session does not
persist, so `AppSync` sees an account switch and correctly sweeps the
onboarding keys — which lands the *next* launch on the consult. Every one
of them is `30` §12.1's law again: **a film door that cannot reach the
surface it names is a fixture that lies about what was inspected.** The
new doors mount their own harnesses and seed their own rows for exactly
this reason.

---

## RED → GREEN

Both features proved RED by reverting the core to the pre-session
behaviour, then restored.

**Food — `setLoggedDay` stubbed to `return false`** (a plate's day cannot
move):

```
Executed 15 tests, with 9 failures (0 unexpected)
** TEST FAILED **
```

Five of the eight new tests failed: `testAPlateMovesToTheDaySheAteIt` ·
`testMovingAPlateKeepsItsIdenityAndEveryNumber` ·
`testTheClockTimeSurvivesTheMove` ·
`testAMovedPlateIsQueuedForTheServerWithItsNewDay` ·
`testTheDayTotalsFollowThePlate`. **The other three passed, and that is
the point**: they assert REFUSALS (a future day, its own day, an absent
id), and a stub that refuses everything satisfies a refusal test. A
refusal test cannot tell "refused for the right reason" from "cannot do
anything at all", which is exactly why the other five exist.

**Weight — `update` reverted to `persist` (today's row or a new one) and
`remove` to `return false`:**

```
Executed 24 tests, with 10 failures (0 unexpected)
** TEST FAILED **
```

Five tests failed: `testCorrectingAPastWeighInMovesThatRowAndNothingElse`
· `testRemovingTheFreshestWeighInFallsBackToThePreviousOne` ·
`testRemovingEveryWeighInFallsBackToHerOwnOnboardingNumber` ·
`testAWeighInCannotBeRepairedByAnotherAccount` ·
`testRepairingSomethingThatIsNotOnFileChangesNothing`.

**`testCorrectingTheFreshestWeighInMovesTheDailyTargets` did NOT fail,
and that is the defect boundary drawn exactly.** The old product could
already fix TODAY, so the stub moves the target too. What it could not do
is reach a PAST row or remove anything — and those are precisely the
tests that went red.

**One product bug was found by a test expectation and fixed in the
product**, not in the test: `WeightLedger.dayWord`'s `DateFormatter` did
not inherit the calendar's time zone, so a row the calendar had placed on
`aug 11` printed `aug 10` — the ledger disagreeing with itself about
which day it was listing. `DoseLedger`'s private parser already sets
`f.timeZone`; this one did not.

---

## TEST PROOF

Every command run serially, unpiped, `$?` captured directly (`32` §13's
correction — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/RecordRepairTests` | 25 | **25** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` | 1207 | **1207** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (12.6 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

App suite is **+25** over `33` (1182 → 1207), which is exactly
`RecordRepairTests` and nothing else — no existing test changed, and no
existing test needed to. PlankFood is **+8** (192 → 200), which is
exactly the re-dating block in `FoodLogPersisterTests`.

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.**

The 5.6 regression gate is included because it is the one that decides
whether the build may be submitted at all, and because this session
touched a `fullScreenCover` host (`BecomingSummaryView`) — the same
family of presentation the rejection was about. It walks the exact
rejected sequence and passes.

### Release build + binary hygiene

`-configuration Release`, `generic/platform=iOS`,
`CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`, exit 0.
Binary inspected: `Release-iphoneos/plankAI.app/plankAI`, 88.4 MB.

| string | count |
|---|---|
| `--uitest` | **0** |
| `--debug` | **0** |
| `--food-debug` | **0** |
| `persona-customer` | **0** |
| `debug-weigh-ins` | **0** |
| `debug-plate-day` | **0** |

Both new film doors and both new harnesses sit inside `#if DEBUG`. No
debug routes, no test personas, no support backdoors, no hidden repair
UI in the shipping binary.

**No migration written or applied. No Edge Function deployed. No
production SQL executed. No production data mutated.**
`CURRENT_PROJECT_VERSION` is still **30** — `32` §BUILD NUMBER's
prerequisite (set it to **31** at archive time, because build 30 is
already accepted by ASC) is unchanged and still the founder's.

---

## THIS SESSION DIFF

| file | change |
|---|---|
| **`Program/WeightLedger.swift`** | **new, pure** — the list, and what it refuses |
| **`Views/Today/WeighInLedgerSheet.swift`** | **new** — `your weigh-ins`, list + editor |
| `Chat/ChatToolRouter.swift` | `WeightLogWriter.update` · `.remove` · `.entries` |
| `Views/Today/JKWeightRitual.swift` | two optional params (`titleOverride`, the destructive line); nil keeps the daily copy byte-identical |
| `Views/Becoming/BecomingSummaryView.swift` | one `JeniRow` + one cover, suppression-gated |
| `Views/Today/PlateDetailSheet.swift` | `the day` — the 14-day picker |
| `Chat/CoachContextAssembler.swift` | `targets.inputs` · `targets.repair_note` · `doors` |
| `Sync/AppSync.swift` | `deleteWeightLog` wrapper |
| **`Packages/PlankSync/SyncService.swift`** | `deleteWeightLog` (+26, additive) |
| **`Packages/PlankFood/FoodLogPersister.swift`** | `setLoggedDay` (+~90, additive) |
| `App/DebugPreviewRoutes.swift` | two film doors + two harnesses, `#if DEBUG` |
| **`plankAITests/RecordRepairTests.swift`** | **new, 25 tests** |
| `Packages/PlankFood/Tests/…/FoodLogPersisterTests.swift` | +8 tests |
| `plankAI.xcodeproj` | three file references |

**Two protected paths moved and neither could be avoided.**
`Packages/PlankSync` gained `deleteWeightLog`, because a delete that the
insert-only hydrate undoes is worse than no delete — it is the same
argument `31` §17 made for `ProgramPlanMerge`. `Packages/PlankFood`
gained `setLoggedDay`, because the date lives in the persister and
nowhere else. Both are additive; no DTO field, no schema, no transport
change.

**Verified EMPTY vs the reviewed release `1710180`:**
`PlankApp/Payment` · `PlankApp/Views/Paywall` · `PlankApp/Auth` ·
`PlankApp/App/AppPhase.swift` · `PlankApp/Info.plist` ·
`plankAI.entitlements` · `PlankApp/Notifications` · `PlankApp/Care` ·
`PlankApp/BodyScan` · `PlankApp/Workout` · `JenifitWidgets` ·
`supabase/migrations`. `PlankApp/Analytics` carries only `31`'s recorded
+6 allowlist lines; **this session's diff to it is empty.**

**Only three files in the repository declare a `@Model`**
(`PlankSync/Models.swift`, `Chat/ChatModels.swift`, `Chat/JeniMemory.swift`)
and **all three have a zero diff against `1710180`** — re-verified here,
not inherited. `32` §1's "no SwiftData migration exists to fail" holds.

## CUMULATIVE DIFF

Unchanged from `32` §11 and `33`, plus this session's row:

| domain | behaviour | risk |
|---|---|---|
| **RECORD REPAIR (new)** | a weigh-in is listable, correctable and removable on any day; a plate's day is correctable within 14 days | **low — additive surfaces and one additive method per store; no existing write path changed** |
| JENI CONTEXT | + the target's inputs, a repair note, and the doors | none — payload only, zero EF deploy |

---

## P0

**None.**

## P1

1. **A past dose log cannot be corrected** — the ledger is read-only.
   GLP-1 only. Machinery exists (`MedicationLog.resolve(slotDayKey:)`).
2. **A side effect can only be logged or changed on the day it
   happened.** GLP-1 only.
3. **Jeni's memory does not follow the account.** Needs a migration
   first, then the client — the ordering hazard, not the cost, is the
   blocker.
4. **`onb_consent_personalize`** — a recorded consent the product does
   not honour. Founder/legal call, recommendation on file since `30`
   §15: delete the row.
5. **Run `docs/app_v25/census.sql`.** Still unrun, still the highest-value
   input to the plan.

## P2

- Manual move entries are device-local.
- Body-scan device-locality is not stated on the surface.
- A weigh-in deleted offline returns on the next hydrate (a tombstone
  is the real fix; it matches the two existing deletes).
- Logging food *directly* to a past day (two steps today).
- The four-way pace vocabulary (`32` §16).
- The CONSISTENCY streak card.
- Dead code with zero production call sites: `EditProfileView` ·
  `RepEngine` · `supplementPlans` · the 14-lesson corpus · the CBT
  manifest · `SafetyCheckInView` · `EnergyLedger.spentKcal` /
  `isLighterDay` · `StepsBentoTile` · the legacy v4.5 `OnboardingView`.
- Everything carried forward from `32` §15 and `33`: the age band's
  35 kcal, the offline day-stamp, the residual resurrection window,
  start weight not user-editable, two devices/two units,
  `money-back guarantee` on the paywall.

---

## SAFE FOR NEXT BUILD: YES

Not because the suites are green. Because the change is shaped so that
the only customers whose experience moves are the ones who were stuck:

- **Nothing existing writes differently.** `persist` still stamps
  `Date()`; `WeightLogWriter.persist` still updates today's row or
  inserts a new one. Two additive repair methods and one additive
  persister method were added beside them. A customer who never opens
  either new surface gets a byte-identical product.
- **No `@Model` changed**, so there is no SwiftData migration to fail.
- **No schema change.** `weight_logs` DELETE and its `delete_own` RLS
  policy have shipped since `scripts/schema.sql`; `food_logs.logged_at`
  is a column the upsert has always written.
- **Both new writes are idempotent and survive the merge contract.** A
  corrected weigh-in is an upsert on an id the insert-only hydrate
  already skips; a removed one is deleted on both sides; a re-dated
  plate is an UPDATE of `logged_at` that `mergeRemote` cannot resurrect
  because it skips ids it holds.
- **Six protected paths and every `@Model` file verified empty against
  `1710180`.**
- The Release binary is strings-clean and the 5.6 exit path is re-verified
  green.

---

# FINAL SCORECARD

Graded hard. For every score below 8, the single reason preventing an 8.

| domain | score | the single reason it is not an 8 |
|---|---|---|
| FOOD LOGGING | **9** | — |
| NUTRITION ACCURACY | **7** | the vision estimate is an estimate, and the four FDA label micros are written into the EF and **not deployed**, so a photographed nutrition panel still returns less than it prints |
| CALORIE ACCOUNTING | **9** | — |
| WEIGHT LOGGING | **8** | — (was 5 this morning: no list, no edit, no delete) |
| PROGRAM RELIABILITY | **9** | — |
| PROGRESS | **8** | — |
| EDITABILITY | **7** | a past dose log and a past side effect still cannot be corrected |
| SYNC / RESTORE | **7** | Jeni's memory, the chat transcript and manual move entries do not follow the account |
| NORMAL WEIGHT-LOSS UTILITY | **8** | — |
| GLP-1 UTILITY | **7** | the shot log and the symptom log are both read-only in the past — the two records a GLP-1 payer is most likely to get wrong in a busy week |
| JENI INTEGRATION | **7** | she can read everything and open five things; she cannot open the food record or change a goal, because both are new tool names behind a founder-gated deploy |
| DESIGN CONSISTENCY | **8** | — |
| SPEED | **8** | — |
| TRUST | **8** | — |

---

# THE FIFTEEN ANSWERS

**1 · IF JENI HAD NO AI INSIGHTS, WOULD IT STILL BE WORTH PAYING FOR?**

**YES.** Strip every insight and what remains is: a two-tap food door
that takes a sentence, a plan whose seven inputs are all visible and all
editable in one screen, a protein floor derived from her body with a
cited band, a calorie remainder, a weight record she can now read and
repair, and — for a GLP-1 user — a shot log and a clinician PDF. Nothing
in that list needs a model to be true, and the two references charge for
less. The intelligence is a multiplier on a real tool, not a substitute
for one.

**2 · CAN I TRUST EVERY IMPORTANT NUMBER IN JENI?**

**YES**, with the exceptions the product itself already states: the
calorie target is labelled an estimate and derives from a labelled BMR
equation; a restored age is marked `about N · approximate`; a vision
estimate says it is one; `dv` says it is a general daily value and not
her target; a nutrient the pipeline did not measure renders nothing
rather than 0. Every one of those is disclosed on the surface that shows
it. There is no number in the product that is confident and wrong.

**3 · CAN I LOG AND CORRECT FOOD WITHOUT FIGHTING THE APP?**

**YES.** Six doors, one chokepoint, and the plate can now be fixed with
her own words, re-portioned, removed, repeated — and, as of this build,
moved to the day she actually ate it.

**4 · CAN I USE JENI AS MY PRIMARY WEIGHT LOG?**

**YES**, and this morning the honest answer was no. A weight log you
cannot list and cannot correct is a chart, not a log.

**5 · CAN I USE JENI AS MY PRIMARY CALORIE / NUTRITION TRACKER?**

**YES**, for calories, protein, carbs, fat, fiber, sugar and sodium.
**NO** for micronutrients, and that is a refusal on evidence rather than
a gap.

**6 · CAN A NORMAL WEIGHT-LOSS USER USE JENI EVERY DAY WITHOUT ANOTHER
APP?**

**YES.** The exact missing boring capabilities, all small: logging food
*directly* to a past day (two steps today) · meal labels, so "what did I
eat for lunch" is answered by name rather than by time · a home-screen
widget.

**7 · CAN A GLP-1 USER USE JENI EVERY DAY WITHOUT ANOTHER APP?**

**YES, with two repairs missing.** Exactly: **she cannot correct a past
dose log** (wrong site, wrong status, marked by accident) and **she
cannot log or fix a side effect on any day but today.** Both are the same
write-only-in-the-past defect this session closed for food and weight,
and both are P1.

**8 · IF I CHANGE PHONES, DOES EVERYTHING I REASONABLY EXPECT TO OWN
FOLLOW ME?**

**NO — three exceptions.** Jeni's memory (listed in Settings as *"what
jeni remembers"*, which reads as durable, and is device-local) · the chat
transcript · manually recorded movement. Body scans are device-local by
default and that is the privacy posture, but the surface does not say so.
Everything else — profile, plan, weights, food with photos and
corrections, doses, symptoms, regimen chains, program facts, weekly
reads, consents — is exact.

**9 · DOES JENI CHAT UNDERSTAND THE SAME PRODUCT THE UI SHOWS?**

**YES.** The envelope resolves through `PlanSummary` — the same object
the screens are made of — and every food read goes through the same
persister. As of this build she can also explain *why* the target is the
number it is, and name where each record lives.

**10 · DOES EVERY MAJOR SURFACE FEEL LIKE THE SAME APP?**

**YES.** Worst offenders, in order: `EditProfileView` (legacy, and
superseded twice over) · the 84-day CBT reader and the 14-lesson corpus
(both unreachable, both still bundled) · `QuickAddView` and
`IngredientEditorSheet`, which sit inside the food package and use
`FoodTheme` rather than `Palette` — consistent in palette, slightly
older in register.

**11 · DOES EVERY PART OF THE JENI METHOD EARN SCREEN SPACE?**

**YES for what is reachable — because two thirds of it is not
reachable.** What should disappear: the 14-lesson `LessonID` corpus, the
84-day CBT manifest and reader, and `RepEngine`. All three have zero
production call sites; the manifest is still parsed on every launch. The
15 live notes each earn their place by construction — every one carries a
required action and a quiet condition, and **silence is a return value**,
so the Method cannot fill a screen just because a screen exists.

**12 · THE FIVE MOST BORING THINGS JENI STILL NEEDS TO GET RIGHT**

1. **Correcting a past dose log.**
2. **Logging and correcting a side effect on any day.**
3. **Jeni's memory following the account** (migration first, client
   after).
4. **Meal labels**, so the food record answers by name and not by clock.
5. **Deleting the dead corpora** — an app that ships a 84-lesson
   curriculum it cannot reach is carrying weight for nobody.

**13 · WHAT SHOULD WE NOT BUILD**

1. Food text search over a database — the words door is already cheaper.
2. A medication-level curve — a pharmacokinetic claim about her body.
3. A water target — refused four times; the mechanism is real, the number
   is not.
4. Streaks, badges, challenges, community, a health score.
5. Blurred premium teasers over her own data — Lose It does this on the
   Goals tab and it makes her record feel rented.

**14 · THE SINGLE HIGHEST-LEVERAGE NEXT MOVE**

> **RUN `docs/app_v25/census.sql` AND RETURN THE RESULT.**

Unchanged from `32`, and now overdue by two sessions. It is the only
input that changes the plan: it sizes the fabricated-goal population,
tells us whether a one-time reconciliation is worth its risk, and it is
the only thing standing between this line of work and a decision made
from evidence rather than from a support email.

**15 · SAFE FOR NEXT BUILD?**

**YES.**
