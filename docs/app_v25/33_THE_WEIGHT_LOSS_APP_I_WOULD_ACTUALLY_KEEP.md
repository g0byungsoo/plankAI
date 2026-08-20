# THE WEIGHT-LOSS APP I WOULD ACTUALLY KEEP

**Status: BUILT 2026-08-13.** Not a correctness pass. `32` froze the
release candidate and nothing here reopens it: no change to the calorie
formula, the protein formula, the merge contract, plan selection, the
restore path, payment, paywall, auth, `AppPhase`, `Info.plist`,
entitlements, migrations or the measurement contract.

This session asked one question instead:

> **IF JENI WERE ON MY PHONE TODAY, WOULD IT BE ONE OF THE BEST DAILY
> TOOLS I COULD USE TO LOSE WEIGHT — with and without a GLP-1?**

---

## PRODUCT VERDICT

**Close, and it was failing on two boring things, one per persona.**

Jeni's hard parts are done and they are better than the references. The
food door is a sentence (`what did you eat?` over a field, with today's
protein standing under it) — nobody else has a cheaper way in. The plan
is coherent end to end after `29`–`32`, and every input to it is now
visible and repairable in one sheet, which neither Lose It nor MeAgain
offers. `DoseStanding` answers *when is my next shot and did I take the
last one* on Home in one line that draws **nothing** for a non-medicated
user.

What was missing was not sophistication. It was subtraction and it was a
list.

1. **The app computed her position and never stated her remainder.**
   Home read `1,660 of 1,460 kcal` and stopped. The one decision a
   calorie-based weight-loss user makes five times a day — *can I eat
   this?* — required her to do the arithmetic. The product already owns
   this exact grammar one tier up: `PlateAnswerEngine` closes every
   protein sentence with *"18 g to go"*, and the evening close is built
   on the same gap. **Energy — the number the plan is priced on — was
   the one place the product declined to finish the sentence.** And it
   is a broken promise, not just an omission: the consult's own device
   demo (`V8Device`, face 1) draws this exact ring and captions it, in
   italic serif, **"what's left today"**.

2. **The day's food record could not be read as a record.** THE BOOK
   stated four totals per day and then showed photographs — one plate
   card is ~55% of the screen — while typed meals were exiled to a
   second, differently-shaped list at the BOTTOM of the spread. So *"what
   did I eat"* and *"which one do I fix"* cost two and a half screens of
   scrolling per day, in the surface whose entire job is answering them.

3. **For the GLP-1 persona: `DoseEventRecord` has stored a day, a status
   and a site for every mark since v24, and no screen had ever listed
   them.** "the record" in the regimen home showed the ERA chain (the
   versions of her plan), which answers *did my dose change* — the rarer
   of the two questions — and hid *did I log my shot / when was the last
   one / which site*. Jeni could answer all three in chat
   (`JeniReadTools.doseHistory`) and could not show them. That is
   `26_WHAT_THE_RECORD_KEEPS`'s write-only defect class, in the domain
   the category exists for.

All three are now closed, in **four product changes and one deletion**.

---

## THE TWO JENIS

| module | BOTH | WEIGHT-LOSS ONLY | GLP-1 ONLY |
|---|---|---|---|
| Home greeting · day chip · calendar strip | ✓ | | |
| `doseStandingRow` (Home's top line) | | | **✓ — nil by construction without a scheduled regimen** |
| protein ring · the day · fiber/sugar/sodium | ✓ | | |
| `today` checklist | ✓ | | (medication beat only) |
| tools (weigh in · breath · move · method) | ✓ | | |
| evening close | ✓ | | |
| scan chooser (words · photo · again · body) | ✓ | | |
| THE BOOK / your plates | ✓ | | |
| Becoming: week read · scopes · body | ✓ | | |
| Becoming: dose eras tile | | | ✓ |
| VisitPacket (clinician PDF) | ✓ | | (richer when medicated) |
| Settings → your medication | ✓ (door, valueless when unset) | | |
| Settings → your care team | ✓ | | |
| your numbers / goal weight / my pace | ✓ | | |
| jeni envelope `medication{}` | | | ✓ |
| protein floor 1.6 g/kg · 0.3%/wk pace floor | | | ✓ (cited, `ProgramGoalCalculator`) |

**Verified on the running app:** a non-GLP-1 account's Home has **zero
medication pixels**. The only medication surfaces she can see are two
quiet Settings rows, and they are deliberate — medication starts
mid-journey (the Omada lesson, recorded in `ProfileHubView`), so the door
exists for everyone and announces nothing.

**A GLP-1 account does not get "Lose It plus a shot reminder" either:**
the medication rhythm is the FIRST line on Home, above the ring, and the
regimen home is a full page with the plan, the shot log, the dose eras
and the side-effect door.

This part of the product was already right and this session did not touch
the split.

---

## CURRENT SURFACE MAP (customer-visible, post-onboarding)

Four tabs — `today` · `jeni` · `scan` (an action, hosts nothing) ·
`becoming`.

| surface | entry | purpose | writes | persona | presentation |
|---|---|---|---|---|---|
| Home | tab | the day | check states | both | page |
| dose standing row | Home top | next/last dose | — | GLP-1 | row → sheet |
| food band | Home | today's nutrition | — | both | page section |
| `today` checklist | Home | what's asked | day checks | both | page section |
| tools | Home | destinations | — | both | page section |
| evening close | Home row | the day's receipt | reflection | both | **fullScreenCover** |
| calendar strip → recap | Home | a past day | — | both | in-page |
| weigh-in ritual | tools/beat | weight | weight log | both | sheet `tallFixed` |
| JENI MOVE | tools/beat | movement record | manual move | both | **`.large`** |
| method note | tools/beat | one teaching | told-state | both | sheet |
| breath | tools | a session | session log | both | cover |
| dose sheet | standing/beat | mark a dose | dose event | GLP-1 | sheet `.tall` |
| side effects | regimen | symptoms + severity | observations | GLP-1 | sheet `.tall` |
| **regimen home** | Home row / Settings | plan · **doses** · eras | regimen versions | GLP-1 | **`.large` (was 0.68)** |
| scan chooser | scan tab | the food door | — | both | in-tree over blur |
| capture → reading | chooser | a plate | food log | both | cover |
| again rail | chooser | relog | food log | both | sheet `.tall` |
| plate detail | book / Home strip | fix · relog · remove | food log | both | `.large` |
| **THE BOOK** | becoming / `.plates` | the food record | — | both | `.large` |
| Becoming | tab | the week / the body | — | both | page |
| weekly read | becoming | the offer | program facts | both | page |
| VisitPacket | becoming | clinician PDF | consent | both | sheet `.tall` |
| jeni chat | tab | the coach | memory, facts | both | page |
| Settings hub | Home gear | everything else | — | both | `.large` |
| your numbers | Settings / Home door | the 7 inputs | body facts | both | sheet |
| goal ritual · pace | Settings | goal / horizon | plan | both | sheet |

---

## ONBOARDING → PRODUCT CONTRACT

The live consult is **31 beats** (`V8Script`, pinned). Every persisted
answer traced to its readers **outside** onboarding and outside
`handleOnboardingComplete` (which is a writer, not a consumer):

| answer | key | class | what it changes |
|---|---|---|---|
| door (clinic/consumer) | `onb_v8_door` | **G** (transient by design) | routing during the consult only |
| name | `onb_v5_name` | C | the greeting |
| **what you want to change most** | `onb_v5_outcome` | **G → C** | *was* the pre-purchase reveal only. **Now the coach envelope.** |
| history / prior attempts | `onboardingPriorAttempts` | C | `CohortStore` texture |
| food relationship | `onboardingFoodRelationship` | C | cohort + lesson pick |
| GLP-1 status | `onboarding_glp1_status` | **A B D** | protein band, pace floor, cohort, wall, plan |
| med route/product/dose/hour | `onb_med_*` | **D** | the regimen bridge builds version 1 |
| age | `onb_v5_age_years` / `onboardingAgeRange` | **A** | BMR term; `HardTierGate` |
| sex | `onboardingGender` | **A** | BMR constant |
| height | `onboardingHeightCm` | **A** | BMR; absent ⇒ no target at all |
| weight | `onboardingCurrentWeightKg` | **A** | everything |
| weight trend | `onboarding_weight_trend` | B | `ProgramGoalCalculator` |
| goal direction | `onboarding_goal_direction` | **A B** | maintenance vs deficit |
| goal weight | `onboardingGoalWeightKg` | **A B** | the deficit and the horizon |
| movement | `onb_v4_movement_baseline` | **A** | activity factor (1.2–1.725 = 647 kcal) |
| sleep | `onboardingSleepHours` | B | pacing floor |
| stress | `onboardingStressLevel` | C | cohort texture |
| medication (blood sugar) | `onboarding_medication_status` | **E** | safety cap |
| hormonal stage | `onboardingHormonalStage` | **B E** | safety cap, pacing |
| fears ×5 | `onb_fear_*` | C | wall copy; 3 of 5 reach the coach |
| attribution | `onb_v5_attribution` | F | analytics only |
| units | `onb_v5_unit_lb/ftin` → `weightUnit`/`heightUnit` | C | every weight and height on screen |
| **personalize consent** | `onb_consent_personalize` | **E, unresolved** | nothing. See below. |
| day-2 consent | `onb_consent_day2` | E | first-days pushes |

### UNUSED QUESTIONS

Three keys have zero readers anywhere in the product, and **two of them
are not questions** — `30` §14 established that `onb_v5_supports`,
`onboardingEatingCadence` and `onboarding_appetite_return` are dead
FIELDS the v8 consult never asks. Re-verified. Unchanged.

What this session found is the one that **is** asked:

**`onb_v5_outcome` — the consult's first substantive question.** Beat 4,
five options, the most personal thing she says:
*feel like myself again · quiet around food · steady energy · clothes
that fit right · keep off what i lost.*

Its only reader in the entire repository was
`OnboardingRevealView.swift:1274` — **the pre-purchase reveal**. The
moment she paid, the answer stopped existing. Home never knew, the plan
never knew, Becoming never knew, and the coach — the one surface whose
whole job is to know her — never knew.

**FIXED, not removed.** Removing a beat from the live consult is an
onboarding change and a funnel surface, both out of scope. The narrowest
honest earn is the coach envelope (`profile.came_for`), and it is a real
one rather than a token: *"what should I focus on this week?"* is one of
the questions this brief lists, and Jeni could previously answer it only
from metrics, with no idea what the person came for. **Zero Edge Function
deploy** — the allowlist gates tool NAMES, not payloads (`27`).

**Still unresolved and still a founder/legal call, restated from `30`
§15:** `onb_consent_personalize` asks *"use my answers to personalize my
plan"* as an explicit opt-in, and the app personalizes regardless. If she
declines we have recorded a consent and violated it. The two honest
resolutions are (a) delete the row — it is not a choice, it is the
product she just bought — or (b) gate something real on it, which cannot
be done without breaking the paid product. **(a) remains the
recommendation. Not this session's call; consent copy is untouched.**

---

## PERSONALIZATION COVERAGE MATRIX

Does the answer reach the surface? (● reaches · ○ does not · — n/a)

| answer | Home | Program | Jeni | Becoming | food | notifs | medication | weekly read | Settings shows it |
|---|---|---|---|---|---|---|---|---|---|
| weight | ● | ● | ● | ● | ● | ○ | — | ● | ● |
| height | ● | ● | ● | ○ | ● | ○ | — | ○ | ● |
| age | ● | ● | ○ | ○ | ● | ○ | — | ○ | ● |
| sex | ● | ● | ○ | ● | ● | ○ | — | ○ | ● |
| activity | ● | ● | ○ | ○ | ● | ○ | — | ● | ● |
| goal weight | ● | ● | ● | ● | ● | ○ | — | ● | ● |
| goal direction | ● | ● | ● | ● | ● | ○ | — | ● | ○ (implied) |
| pace | ● | ● | ● | ○ | ● | ○ | — | ● | ● |
| GLP-1 status | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| dose / rhythm / day | ● | ● | ● | ● | ○ | ● | ● | ● | ● |
| units | ● | ● | ○ | ● | ● | ○ | — | ● | ● |
| sleep / stress | ○ | ● | ● | ○ | ○ | ○ | — | ● | ○ |
| food relationship | ○ | ● | ● | ○ | ● | ○ | — | ● | ○ |
| fears | ○ | ○ | ● (3 of 5) | ○ | ○ | ○ | — | ○ | ○ |
| **came for** | ○ | ○ | **● (new)** | ○ | ○ | ○ | — | ○ | ○ |

Every **A/B/D** answer reaches its consumer, and every one of them is now
visible and editable in `your numbers` / `goal weight` / `my pace` (`31`
§7). The remaining ○s are texture, not math.

---

## LOSE IT CAPABILITY MATRIX

Inventoried from 77 frames (`~/Pictures/screenshots/loseit`), grouped:
onboarding (9368–9433), Dashboard, Log, Goals, food edit (9434–9444).

| capability | Lose It | Jeni | verdict |
|---|---|---|---|
| daily calorie budget | Budget/Food/Exercise/**Under** pill | the day's target | — |
| **calories remaining** | the whole product | **absent → BUILT** | **COPY THE PRINCIPLE** |
| protein | a row among macros | **the lead, with a ring and a floor** | **JENI ALREADY BETTER** |
| macros / fiber | rows | one split + legend + fiber/sugar/sodium | JENI BETTER (one shape) |
| photo logging | a door among many | **the product** | **JENI ALREADY BETTER** |
| words logging | ✗ | **the front door** | **JENI ALREADY BETTER** |
| barcode | ✓ | ✓ (live VN + OFF) | parity |
| **food text search** | ✓ (huge DB) | **✗** | **DON'T BUILD — see below** |
| manual/quick add | ✓ | ✓ (`QuickAddView`) | parity |
| edit an entry | inline Edit/Delete | plate sheet: fix words · relog · remove | parity |
| change serving | ✓ | **`PlateShare` — servings of the DISH** | JENI BETTER |
| meal buckets + per-meal suggestion | ✓ | ✗ (slot derived, analytics only) | **USEFUL BUT NOT FOR JENI** |
| recent / frequent / repeat | ✓ | **again rail, one tap, on the door** | JENI BETTER |
| saved meals / recipes | ✓ | ✗ | DON'T BUILD (again covers it) |
| **the day's food list** | the Log tab IS it | **buried → FIXED in THE BOOK** | **COPY THE PRINCIPLE** |
| food history | day pager | THE BOOK (spreads + month seams) | JENI BETTER |
| **persistent date pager** | on every tab | strip on Home only, read-only | **USEFUL BUT NOT FOR JENI** |
| **log to a past day** | ✓ | **✗** | **P1, NOT BUILT — see KNOWN LIMITATIONS** |
| weight logging + history + trend | ✓ | ✓ (EMA, unit-error rejection) | JENI BETTER |
| goal weight editing | ✓ | ✓ (`JKGoalRitual`, BMI-18.5 clamp stated) | parity+ |
| pace editing | plan | ✓ (`my pace`, keeps the Hard lock) | parity |
| **every input to the target, visible** | ✗ | **`your numbers`, 7 rows** | **JENI ALREADY BETTER** |
| activity / steps / Apple Health | ✓ | ✓ (measured or absent, never estimated back) | JENI BETTER |
| reports / export | premium | VisitPacket PDF | JENI BETTER (clinician-shaped) |
| streaks · badges · challenges · community | ✓ | consistency count only | **NOT WORTH COPYING** |
| blurred premium teasers on data screens | everywhere | ✗ | **NOT WORTH COPYING** |
| **GLP-1 "Low Appetite Nutrition Strategy"** | a targets preset (protein 139 g) | protein 1.6 g/kg + 0.3%/wk floor, cited | parity, better sourced |

### WHAT LOSE IT GETS RIGHT

1. **The budget is a subtraction, stated.** Not "you ate 1,660". The
   remaining number is the product. *Copied — the principle, not the red
   pill.*
2. **One tab is "the day", and everything you can record today is on
   it.** One place to put things in.
3. **Provenance on derived numbers** ("generated from log").
4. **Per-item inline edit/delete.** No hunting.
5. **The date is a global control.** Fixing yesterday is never a
   different flow.

### WHAT JENI ALREADY DOES BETTER

- **The door is a sentence.** Lose It's cheapest path is search-and-pick;
  Jeni's is "what did you eat?" and a return key.
- **Protein leads and has a personal floor.** Lose It has protein; it
  does not have a floor derived from her body with a cited band.
- **Nothing is invented.** No target ⇒ no number ⇒ a door onto the
  missing fact. Lose It will happily quote a default.
- **Every input to the number is visible and editable in one sheet.**
- **No red.** `200 over` is stated in the same tertiary grey as
  everything else on that line.

---

## GLP-1 CAPABILITY MATRIX

From `~/Pictures/screenshots/meagain` (62) and `shotsy` (26).

| capability | MeAgain | Shotsy | Jeni | verdict |
|---|---|---|---|---|
| medication setup | 5-row flat list | onboarding wizard | 4 doors + wizard | parity |
| brand / generic | **names brands** | **names brands** | catalog, never named in notifs/analytics | **NOT FOR JENI** (compliance floor) |
| injection vs oral | ✓ | ✓ | ✓ (route-aware copy) | parity |
| device type (pen/auto/vial) | ✗ | ✓ | ✗ | **NOT WORTH COPYING** (changes nothing) |
| dose + dose changes | ✓ | ✓ | **version chains, never overwritten** | JENI BETTER |
| shot day / cadence | ✓ | ✓ | ✓ (weekly anchor, DST-safe) | parity |
| reminders | ✓ | ✓ | ✓ (never names the product) | JENI BETTER |
| late / missed RECORDING | ✓ | ✓ | ✓ (late window; missed is lazy + reversible) | JENI BETTER |
| **dose history list** | "Show All Dose Logs" | "see every shot I've taken" | **✗ → BUILT** | **COPY THE PRINCIPLE** |
| injection site | ✓ + body map | ✓ | ✓ 6 cells, rotation pre-picks | parity |
| **last site stated** | ✓ | ✓ | ✓ *(already shipped — `SiteRotationAdvisor.line`)* | **JENI ALREADY BETTER** (states the reason too) |
| site rotation suggestion | ✓ | ✓ | ✓ (suggests, never insists) | parity |
| side effects + severity | 6 sliders 0–10 | onboarding only | **14 chips × 3 severities, incl. hair/period/cold/mood** | JENI BETTER |
| symptom → clinician | ✗ | ✗ | **VisitPacket PDF** | JENI BETTER |
| **medication-level curve** | ✓ + sourced modal | ✓ + FDA citation | **refused** | **USEFUL BUT NOT FOR JENI** |
| weight ↔ medication relationship | ✓ | ✓ | `MedicationPatternEngine` (floor-gated, timing-never-causality) | JENI BETTER |
| protein / fiber / water trio | ✓ | ✗ | protein + fiber; **water refused, twice, on evidence** | deliberate |
| progress photos | ✓ | ✗ | BodyScan (local-first, words never numbers) | JENI BETTER |
| next-dose countdown | ✓ ring "6d 20h" | "In 2 days" | `next dose · today, 6:00pm` + Home standing | parity |
| capybara mascot / "3× more effective" | ✓ | ✓ | ✗ | **NOT WORTH COPYING** |

### WHAT MEAGAIN GETS RIGHT

1. **One screen answers every medication question.** Last dose · next
   dose + countdown · site · side effects · today's log · settings ·
   *show all dose logs*. *Copied — the principle: the dose history must
   exist as a list.*
2. **Every log is one full page**: a date row, the instrument, one
   primary CTA, a destructive action below. Jeni's dose sheet already
   has this shape.
3. **A meal states what it does to the DAY at log time** (protein
   23.8/160, fiber 4.7/38). Jeni's `PlateAnswerEngine` already does this
   for protein.
4. **An estimate carries an (i) that opens a sourced disclaimer.** Good
   pattern; the estimate itself is still refused here.

### WHAT SHOTSY GETS RIGHT

1. **The whole value proposition is three facts**: *next shot · next site
   · progress*. That is the correct scope for GLP-1 utility.
2. **The pace question shows its consequence live** (goal date + weekly
   change as you drag).
3. *"I can see every shot I've taken and that is much more useful than
   guessing"* — the review they lead with is the feature Jeni had the
   data for and no screen for.

### WHAT JENI ALREADY DOES BETTER

- **Dose history is a version CHAIN, never an overwrite.** A dose change
  is a new era; the old one is still true about the weeks it covered. The
  new log renders each dose at **the dose she was actually on that
  week** — not today's dose printed over her history.
- **Discretion**: the product is never named in a notification or an
  analytics payload; a pill is never called a shot.
- **The side-effect vocabulary is the cohort's**, including the four
  under-reported ones (`hair shedding · period changed · cold all the
  time · mood low`), with 988 support surfaced first on mood.
- **A clinician-shaped export exists.**
- **The estimated medication-level curve is refused** — it is a
  pharmacokinetic claim about HER body from a population half-life.
  MeAgain's own modal admits it "does not account for individual
  variations in metabolism". Refused in `28`, re-examined here, refusal
  stands.

---

## NORMAL WEIGHT-LOSS CORE LOOP

`open → read the remainder → log by sentence or photo → the plate answers
→ weigh in → the week reads back`

The loop was complete except for the remainder. It is now:

> **the day · 1,660 · of 1,460 kcal · 200 over**

## GLP-1 CORE LOOP

`open → the standing line ("your shot is today") → mark it (site
pre-picked, last site + reason stated) → log how it's sitting → the log
lists every shot → the packet goes to the visit`

The loop was complete except for the list. It is now the `the doses`
section of the regimen home.

---

## FOOD LOGGING AUDIT

Paths: **photo · label photo · words · again · quick-add · barcode**.
Every path lands on the same `FoodLogPersister.persist` chokepoint and
the same `FoodLogEntry` shape (kcal · protein · carbs · fat · fiber ·
sugar · sodium · satFat · itemsDetail · corrections · source). This was
verified as the single chokepoint in `26`/`27` and re-verified here; no
new path was added, so no new invariant could break.

- **HOME TOTAL == BOOK TOTAL == DAILY SUMMARY** by construction: all
  three read `FoodLogPersister.allEntries(userId:)` filtered by day key.
  There is no second accumulator.
- **Delete** exists and is reachable (`PlateDetailSheet` →
  `deleteEntry`), and it removes the photograph with the entry.
- **Correction** persists to `food_logs.payload` and renders as YOUR
  NUMBERS on the plate (`26`).
- **`mealSlot` is derived at capture and used for analytics only** — it
  is not stored on the entry and not rendered. That is why meal buckets
  are not a small change, and why they are classified below.

**No food code changed this session.** `Packages/PlankFood` has a **zero
diff**.

---

## MEDICATION AUDIT

`DoseLedger` (new, pure) + the `the doses` section. Its refusals are the
design:

- no adherence rate, no streak, no percentage
- a skipped day reads `skipped`, never "you missed one"
- a closed empty slot reads `not recorded`
- `just_didnt` is an option the sheet offers so she can close the loop
  without explaining herself — **rendering it back as a reason would turn
  a shrug into a confession**, so it renders nothing
- an unrecognised reason is never invented
- a late take is stated as provenance (`2 days late`) and is **not
  muted** — a late dose is a dose
- an unknown status can only fall to `due`, never to a taken face that
  would claim a dose she did not record

Pinned by `testTheLedgerHasNoVocabularyForJudgement`, which sweeps every
status × every reason against a banned word list.

---

## JENI COACH AUDIT

The envelope already carries current/start/goal weight, `to_go_kg`,
`weeks_at_her_pace`, `kcal_basis`, `goal_on_file`, `kcal_missing`,
protein, food today, steps, program day, GLP-1 status, medication
compound/route/cadence/dose, dose-day flags, recent symptoms and the week
block (`30` §7, `31`). It resolves through `PlanSummary` — the same
object the screens are made of — so Home == Plan == Jeni is structural,
not coincidental (`OneTargetEverywhereTests`, 25 states).

**One field added: `profile.came_for`.** See UNUSED QUESTIONS.

Not added, deliberately: the remainder. Jeni computes it from `kcal` and
`food_today`, and shipping a second copy of a subtraction is how two
numbers start to disagree.

---

## BECOMING LOOP AUDIT

Walked, not changed. It uses food, weight, steps, adherence, medication
eras and side effects, and its week read is band-based and offer-first.
It passes the test the brief sets — *could she learn something here she
could not get from Home?* — because the scope bar (today/week/month/3
months/year/all) is a thing Home structurally cannot do.

**One honest note, recorded not fixed:** the CONSISTENCY card ("3 days in
a row") is a streak by another name. It predates this session, the brief
forbids adding gamification, and removing a shipped card on taste is not
this session's call. **P2.**

---

## MODAL / FULL-SCREEN AUDIT

`JeniSheetHeight.tall` is `[.fraction(0.68), .large]` — it opens at two
thirds and **is draggable**, which already answers most of the founder's
complaint (`26` §4 fixed Move). Every remaining presentation classified:

| surface | class | detent | action |
|---|---|---|---|
| **regimen home** | **DESTINATION** | 0.68 → **`.large`** | **CHANGED** (3 call sites) |
| plate detail · profile hub · THE BOOK · care connect · MOVE · reconciliation · visit-packet share | DESTINATION | `.large` | already correct |
| dose sheet | QUICK ACTION (site + note + one CTA) | `.tall` | keep |
| side effects | QUICK ACTION (chips + one CTA) | `.tall` | keep |
| mark-as-done · weigh-in ritual | QUICK ACTION | `.tall` / `tallFixed` | keep |
| again rail · method told · recent meals | list, expandable | `.tall` | keep — they drag to `.large` |
| goal ritual · pace · your numbers | instrument | `.tall` | keep (the ruler needs thumb reach) |

**The regimen home was the one real offender** and it was already cut off
at 0.68 *before* this session added a section to it: `not taking it right
now` and the privacy line sat below the fold on a fresh iPhone 16. It
carries four editable facts, the next-dose line, the side-effect door,
the dose log, the era chain and the stop/pause choices. That is a page.

**Proven after the change:** dismissal (grabber + `onDone`), scroll,
keyboard (the two `TextField` editors), safe area, SE, AX5.

---

## DESIGN CONSISTENCY AUDIT

Anchors: onboarding · Home · Becoming · camera snap. Classified against
their grammar (paper + ink, serif heroes, DMSans body, hairlines, one
ink pill, no card around a list):

- **JENI**: Home, Becoming, THE BOOK, scan chooser, plate detail, your
  numbers, goal ritual, MOVE, dose sheet, side effects, regimen home,
  weekly read, VisitPacket, ProfileHub.
- **LEGACY JENI**: `EditProfileView` (titled "your pace", edits exactly
  one value — superseded by `my pace` and `your numbers`), the 84-lesson
  Method corpus.
- **GENERIC SWIFTUI**: none reached in this walk.
- **FOREIGN PRODUCT**: none.

The app already reads as one product. **The one inconsistency this
session created, it fixed**: `JKPlanNumbersSheet` had invented a fifth
pace vocabulary (`32` §2 caught `quick`); nothing new was invented here —
the new dose log reuses the era rows' own grammar and the new remainder
reuses `31` §8's `· <word>` suffix.

### AX5, and a break I inherited by touching the file

Filming the regimen home at AX5 showed **pre-existing** wrapping *inside*
words: `medica/tion  ozem/pic`, `rhyth/m  weekly / . / thursd/ays`. That
is the `124` → `12`/`4` law happening to a medication name. It shipped in
v24 and had never been filmed at AX5.

It is this change's responsibility because this change promoted the sheet
to a full-page destination and added a section to it — **a full-screen
conversion must not hand back a bigger broken scroll** (brief §28). Every
label/value pair in the sheet (`door`, `factRow`, `eraRow`, the new dose
rows) now stacks from `xxxLarge` up, the same rule
`HomeNutritionSummary.stacksForType` has used since E9. The BOOK's new
ledger row carries the same rule.

---

## COPY REMOVED / FEATURES REMOVED / FEATURES ADDED

**REMOVED (code):**
- `menuRows` — THE BOOK's second, differently-shaped list for typed
  meals. Superseded by the day ledger, which is the same object carrying
  the whole day. **Net −1 list, −1 grammar.**
- `HomeTodayPlates` — written this session, mounted on Home, then
  **deleted on a founder steer** (below). Dead code does not ship.

**COPY CHANGED:** two words.
- `the record` → `dose changes` in the regimen home. Two lists under one
  heading called "the record" answered the rarer question and hid the
  common one.
- The day's reference gains `· N left` / `· N over` / `· right on it`.

**ADDED:**
1. **The remainder on Home's day tier** (`energyReferenceLine`, pure).
2. **`the doses`** — the shot-by-shot log (`DoseLedger`, pure).
3. **The day ledger in THE BOOK** — every plate, above the photographs.
4. **`profile.came_for`** in the coach envelope.

**A FOUNDER STEER, MID-BUILD, AND IT WAS RIGHT.**
The plate ledger was first built as `HomeTodayPlates` and mounted between
the food band and the checklist. The founder: *"what you ate in home
screen doesn't look good as it doesn't prioritise the to-do list of home
screen."* Correct, and it is `HomeView`'s own law two hundred lines
above the insertion — Home reads nutrition → **what's left** → tools. A
record is a look-back; the checklist is the only part of Home that asks
for something, and nothing may push it down the page. Moved below the
checklist; the founder then: *"don't move below the checklist. separate
it to the food log feature."* Also correct, and it produced a better
change than the one I proposed: instead of a fifth section on Home, the
food log's own surface stopped burying its record. **Home's diff is now
one string.**

---

## FEATURES DELIBERATELY NOT ADDED

Each failed at least one of FREQUENCY / WEIGHT-LOSS VALUE / FRICTION /
JENI ADVANTAGE / COMPLEXITY.

- **Food text search over a database.** Lose It's biggest surface area.
  It fails JENI ADVANTAGE: the words door already accepts *"greek yogurt
  and berries"* and returns a priced plate in one step, where search
  returns a list she has to disambiguate. Adding search would make the
  cheap door look like the slow one. **DON'T BUILD.**
- **Meal buckets (breakfast/lunch/dinner/snacks) with per-meal calorie
  suggestions.** Real utility in Lose It, and it fails COMPLEXITY here:
  the slot is derived at capture for analytics and is not on the entry,
  so this is a schema change plus a new mental model (four budgets
  instead of one) on a product whose law is that kcal stays quiet.
  **USEFUL BUT NOT FOR JENI.**
- **A persistent date pager on every tab.** The strip already selects a
  day on Home. Making it global is an IA change to a protected anchor
  for a job the strip does.
- **Logging to a past day.** This one is a genuine gap and it is
  **P1** — see KNOWN LIMITATIONS. Not built because every capture path
  stamps `Date()` at persist, and re-dating a write on a release
  candidate is a data change, not a UI change.
- **The estimated medication-level curve.** A pharmacokinetic claim about
  her body. Refused again.
- **A water target.** Refused three times now (E9, `29`, here). The
  mechanism is real (thirst-cue suppression); no guideline body
  prescribes a personal volume, and the honest shape needs HealthKit
  `dietaryWater` and an `Info.plist` purpose string.
- **Streaks, badges, challenges, community, a health score, a widget.**
- **Blurred premium teasers on data screens.** Lose It does this on the
  Goals tab; it makes her own record feel rented.

---

## BEFORE / AFTER FRAMES

| surface | before | after |
|---|---|---|
| Home · the day | `1,660  of 1,460 kcal` | `1,660  of 1,460 kcal · 200 over` |
| Home · everything else | — | **byte-identical** |
| THE BOOK · a day | date → totals → **photo card (55% of screen)** → grid → typed meals last | date → totals → **the ledger (4 plates, ruled, tappable)** → photos |
| regimen home | 4 doors · next dose · side-effect door · `the record` (eras) — cut off at 0.68 | full page · + **`the doses` (9 on file)** · `dose changes` |
| regimen home at AX5 | `medica/tion ozem/pic` · `weekly / . / thursd/ays` | label over value, no word wraps inside itself |

Frames (scratchpad, iPhone 16 unless noted):

| before | after |
|---|---|
| `03_home.png` | `61_home_after.png` (over: `· 200 over`) |
| — | `80_home_nogoal.png` (under, midday: **`860 of 1,596 kcal · 736 left`**) |
| `23_food_book.png` | `60_book_after.png` |
| `20_regimen.png` | `41_regimen_after.png` |
| `51_regimen_ax5.png` (AX5, broken) | `70_regimen_ax5.png` (AX5, fixed) |
| — | `71_book_ax5.png` (AX5) |
| — | `72_home_se.png` · `73_regimen_se.png` · `74_book_se.png` (SE) |

**Two states are pinned by test rather than filmed, and it is worth
saying which.** The maintenance face (`· holding`, no remainder) and the
no-target face (the repair door, no sentence) both need a persona that
lands on Home *without* a seeded program; every combination of the
existing doors that produces those states lands on the post-purchase
onramp instead, so the frames would have shown the wrong screen. Both
are held by `DailyUtilityTests` and by `OneTargetEverywhereTests`'s 25
states, and `31` §8 filmed `of 1,693 kcal · holding` on Home when it
shipped. **A film door that cannot reach the surface it names is a
fixture that lies about what was inspected** (`30` §12.1) — so this
says what was pinned instead of showing a screenshot of somewhere else.

---

## NORMAL WEEK PROOF / GLP-1 WEEK PROOF

**Method, stated so the numbers can be checked.** Both weeks were seeded
and rendered on the live build (`--uitest-persona-home
--uitest-seed-program --uitest-seed-week`, and `--uitest-seed-medication
history` for the GLP-1 week) and every surface below was filmed. The
transition counts are counted from the rendered IA and the router, not
from synthesized taps — the iOS 26.2 simulator cannot be driven by
`simctl` taps and this repo's own record says synthesized drags do not
scroll it. Lose It's counts are read off its frames the same way.

| task | Lose It | Jeni before | Jeni after |
|---|---|---|---|
| log a known meal, day 1 | search → pick → serving → meal → save (5+) | words → return (2) | unchanged |
| repeat yesterday's breakfast | Recent → pick → save (3) | chooser → `again · <dish>` (2) | unchanged |
| "how much can I still eat?" | read the pill (0) | **subtract in her head** | **read the line (0)** |
| "did I log lunch?" | Log tab (1) | becoming → book → scroll past a photo card (3+) | **becoming → book (1, first screen)** |
| fix lunch's calories | tap → Edit (2) | book → scroll → tap → fix (4+) | **book → tap → fix (3)** |
| "when is my next shot?" | — | Home line (0) | unchanged |
| "did I take last week's?" | — | **nowhere** | **regimen → the doses (1)** |
| "which site last time?" | — | dose sheet (1) | unchanged |

The overall advantage the brief asks for holds: **photo/words first +
repeat without work + a personal plan**, and the two places Lose It was
strictly faster are now level.

---

## ACCESSIBILITY

Re-walked at AX5 (`content_size accessibility-extra-extra-extra-large`)
and on the SE, on every changed surface.

- Home's day tier already stacks from `xxxLarge` (E9); the longer
  reference wraps rather than truncating (`fixedSize(vertical:)`, no
  `lineLimit`), and **the numeral keeps `lineLimit(1)`** — the `124` →
  `12`/`4` law holds.
- The regimen home's rows stack label-over-value; **no word wraps inside
  itself at any size**, which was not true before this session.
- THE BOOK's ledger row stacks title over `time · facts`.
- VoiceOver: the day tier announces `"1,660 kcal, of 1,460 kcal, 200
  over"`; each dose row announces `"aug 6, 0.5 mg · left thigh"`; each
  ledger row announces the dish, the time, the kcal and the grams, with
  the hint `"double-tap to open, fix or remove it"`.

---

## TEST COUNTS / EXIT STATUS / VERDICT

Every command run serially, unpiped, `$?` captured directly
(`32` §13's correction).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/DailyUtilityTests` | 18 | **18** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` | 1182 | **1182** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` | 192 | **192** | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

App suite is **+18** over `32` (1164 → 1182), which is exactly
`DailyUtilityTests` and nothing else — no existing test changed, and no
existing test needed to.

**`DailyUtilityTests` proven RED before GREEN.** With
`energyReferenceLine`'s maintenance branch stubbed to append a remainder
— the exact "helpful" change a future pass would make — the suite
produced **2 failures** naming both maintenance rows. Restored: 18/18.

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.**

---

## KNOWN LIMITATIONS

1. **She cannot log food to a past day.** Every capture path stamps
   `Date()` at persist. The strip selects a past day and the recap is
   read-only. This is the largest remaining boring gap and it is **P1**:
   it is a write-path change on a frozen candidate, and it needs a
   deliberate decision about whether a back-dated entry may move a day
   the evening close has already sealed.
2. **The dose log has no in-app share.** The VisitPacket covers the
   clinician case; a plain "copy my dose history" does not exist.
3. **Meal buckets do not exist**, so "what did I eat for lunch
   specifically" is answered by time, not by label.
4. **The CONSISTENCY streak card** in Becoming, recorded above.
5. Everything carried forward from `32` §15 is unchanged: the age band's
   35 kcal, the offline day-stamp, the residual resurrection window,
   start weight not user-editable, two devices/two units,
   `money-back guarantee` on the paywall.
6. **Nothing here can be falsified against a payer** until the
   measurement contract's first clean read. The census (`census.sql`) is
   still unrun and is still the highest-value next input.

### P0
None outstanding.

### P1
- Logging food to a past day.
- `onb_consent_personalize` — a recorded consent the product does not
  honour. Founder/legal call, recommendation on file.
- Run `docs/app_v25/census.sql`.

### P2
- The four-way pace vocabulary (`32` §16), unchanged.
- The CONSISTENCY streak card.
- `EditProfileView` — a legacy screen titled "your pace" that edits
  `workoutLevel` and is superseded twice over.
- Meal labels on the food entry (would need a schema field).
- Water via HealthKit `dietaryWater` (needs a purpose string).

---

## SAFE FOR NEXT BUILD: YES

**This session's file list, in full** — nine files, two of them new:

| file | change |
|---|---|
| `Views/Home/HomeSections.swift` | `energyReferenceLine` (+ `HomeTodayPlates` added then deleted) |
| `Views/Home/HomeView.swift` | one detent |
| `Views/Today/RegimenSheet.swift` | the dose log · one heading · AX5 stacking |
| `Views/Today/TodayModuleHost.swift` | one detent |
| `Views/Settings/ProfileHubView.swift` | one detent |
| `Views/Becoming/FoodJournalView.swift` | `menuRows` → `dayLedger`, promoted |
| `Chat/CoachContextAssembler.swift` | `profile.came_for` |
| **`Program/DoseLedger.swift`** | new, pure |
| **`plankAITests/DailyUtilityTests.swift`** | new, 18 tests |
| `plankAI.xcodeproj` | two file references |

**Verified empty vs the reviewed release `1710180`** (nothing this
session touched them, and nothing on the branch does either):
`PlankApp/Payment` · `PlankApp/Views/Paywall` · `PlankApp/Auth` ·
`PlankApp/App/AppPhase.swift` · `PlankApp/Info.plist` ·
`plankAI.entitlements` · `PlankApp/Notifications` · `PlankApp/Care` ·
`PlankApp/BodyScan` · `PlankApp/Workout` · `JenifitWidgets`.

`Packages/PlankFood`, `Packages/PlankSync`, `supabase/` and
`PlankApp/Analytics` carry only the `26`/`27`/`31` work already recorded
and reviewed — **this session's diff to all four is empty.**

**Only three files in the entire repository declare a `@Model`**
(`PlankSync/Models.swift`, `Chat/ChatModels.swift`, `Chat/JeniMemory.swift`)
and **all three have a zero diff against `1710180`**, so `32` §1's "no
SwiftData migration exists to fail" holds unchanged. Re-verified here
rather than inherited.

No migration, no Edge Function deploy, no analytics event added, renamed
or redefined, no new HealthKit type, no medical claim, no dosing advice.
Release binary re-checked: `--uitest` **0** · `--debug` **0** ·
`--food-debug` **0** · `persona-customer` **0**.
`CURRENT_PROJECT_VERSION` still 30 — `32` §BUILD NUMBER's prerequisite
(set it to 31 at archive time) is unchanged and still the founder's.

---

## THE TEN ANSWERS

**1. Without a GLP-1, why keep Jeni instead of Lose It?**
Because logging costs a sentence instead of a search, and the number that
comes back is built from a plan whose every input she can see and change
in one screen. Lose It gives you a database; Jeni gives you a coherent
plan and the cheapest possible way to feed it.

**2. On a GLP-1, why keep Jeni instead of MeAgain or Shotsy?**
Because those are medication trackers with nutrition bolted on, and the
nutrition is what actually moves the weight — Jeni is a real weight-loss
program that also holds the shot, the site, the side effects and the
visit packet. And it refuses to draw a pharmacokinetic curve of her
bloodstream from a population half-life.

**3. The single most important daily action in Jeni?**
Putting the day's food on the record — by sentence, photo or `again` —
because every other number on every other screen is derived from it.

**4. The most useless thing currently in the product?**
`EditProfileView` — a screen titled "your pace" that edits exactly one
value (`workoutLevel`), superseded by both `my pace` and `your numbers`.

**5. The biggest boring capability still missing?**
Logging food to a past day.

**6. What did you remove or simplify this session?**
`menuRows` (THE BOOK's second list for typed meals — folded into the one
day ledger); `HomeTodayPlates` (written, mounted, then deleted on the
founder's steer rather than left behind); the heading `the record`
splitting into two headings that each say what they are.

**7. What did you copy from Lose It?**
The principle that a calorie budget is a **subtraction, stated**, not a
position. And that the day's food must be readable as a list before it
is beautiful as a photograph.

**8. What did you copy from MeAgain / Shotsy?**
The principle that a GLP-1 user must be able to **see every shot she has
taken** — a plain, boring, dated list — and that it must sit in the same
place as the plan it belongs to.

**9. Does the app now feel like one product?**
**Yes.** Every surface reached in this walk was in the anchors' own
grammar, the two additions reuse vocabulary that already shipped (`31`
§8's `· <word>` suffix, v24's era rows), one list replaced two, and the
one inconsistency created during the build was caught by the founder and
removed rather than shipped.

**10. Should I ship these product changes?**
**Yes.** One string on Home, one section in a sheet that had a zero
render cost for non-medicated users, one list replacing two in THE BOOK,
one field in a payload that needs no deploy, and one AX5 fix on a screen
that was already broken. Nothing in the frozen candidate moved.
