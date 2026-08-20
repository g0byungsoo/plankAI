# THE CUSTOMER MUST NEVER NEED SUPPORT

**Status: BUILT 2026-08-14.** Not an era, not a feature pass. The third
and last of the boring-truth sessions: `29` fixed the paths that LOSE the
goal weight, `30` audited whether the facts underneath can be trusted,
and this one asks the only question that matters once both are true —

> **CAN A PAYING CUSTOMER GET HER ACCOUNT INTO A STATE THAT JENI CANNOT
> EXPLAIN AND SHE CANNOT REPAIR HERSELF?**

The answer was yes, in a way neither previous pass could see, because
both were reading the CLIENT. The customer's own report contains the
finding: *the database was repaired and her phone kept showing the old
number.* That is not a bug in a screen. **It is the recovery contract
failing**, and it means the support desk had no working lever at all.

No migration. **Zero diff against the reviewed release (`1710180`) in
Payment, Paywall, Auth, `AppPhase.swift`, `Info.plist`, entitlements.**
Zero HealthKit change. Zero analytics change — no event added, renamed or
redefined. `e5.firstPlate.enabled` still false. The Edge Function is
untouched — still written, still not deployed.

**Two protected paths moved and both are documented in §17:**
`Packages/PlankSync` (+119 / the merge contract, which cannot live
anywhere else) and `PlankApp/Health/EnergyLedger.swift` (a de-duplication).

**1139/1139 app** (was 1103; **+36**) · **9/9 PlankSync** (was 6) ·
**192/192 PlankFood** — every one with `** TEST SUCCEEDED **` and a
process exit of 0, read together, per §14.

---

## 1 · THE AUTYM TEST

### The state, reconstructed

| | SERVER (after the desk's repair) | HER DEVICE |
|---|---|---|
| `users.onboarding_goal_weight_kg` | **110 lb** | 124 lb |
| `program_plans.goal_weight_kg` | **110 lb** | 124 lb |
| `program_plans.current_weight_kg` | 124 lb | 124 lb |
| `program_plans.total_days` | **119** | 210 |
| `program_plans.start_date` | 26 days ago | 26 days ago |
| plan id | the same row | the same row |

`goal == start` is not a weight-loss plan. Every energy path read it as
maintenance, which is `29`'s finding. The desk fixed the row. Nothing
happened.

### Why nothing happened — THREE walls, and each one alone is fatal

**Wall 1 — the pull never ran.** `AppSync.shouldHydrateOnLaunch` returns
true only when some synced family is locally EMPTY:

```swift
guard isAnySyncedFamilyEmpty(...) else { return false }
```

A settled payer has sessions, day progress, weigh-ins, a plan, day
checks, a reflection and a food entry. **None of her families are
empty**, so the launch hydrate never fired — for exactly the people who
have been paying longest. The only routes left were sign-out → sign-in
and reinstall. Neither is a thing support can ask a paying customer to
do, and neither is a thing she would think of.

**Wall 2 — the merge was insert-only.** Even when a hydrate DID run,
`applyHydratedProgramPlans` skipped a plan whose id it already had:

```swift
if let variants = localsById[normalizedId] {
    …
    continue   // "data fields stay untouched (insert-only semantics)"
}
```

Insert-only is the right rule for append-only history: a weigh-in, a
session, a dose event — the past does not change. **A program plan is not
history.** It is a mutable statement about her body, and the one place a
human on the support side can reach.

**Wall 3 — the mirror was absent-only.** `hydrateUser` DOES copy every
`users` column into the local record. `restoreBodyDefaults` then wrote it
into `@AppStorage` only when the key was **missing**:

```swift
guard let value, value > 0, defaults.object(forKey: key) == nil else { return }
```

So the corrected goal landed in the local database and stopped there.
Every surface reads the `@AppStorage` key. **The repair travelled 95% of
the way and died one assignment short of the screen.**

### The merge rule, and why the existing schema is enough

`program_plans` carries **no trustworthy `updated_at`** — the upsert has
never written one (`SupabaseProgramPlanUpsert` has no such field) and the
hydrate has never read one. There is no timestamp to arbitrate with, and
inventing one would be inventing a fact.

It does not need one. **`pendingUpsert` already carries exactly the
required information**, because it is set by every local mutation and
cleared *only* inside the success branch of `upsertProgramPlan`:

- `pendingUpsert == true` — this device holds a write the server has not
  heard. **The device is the newer author. Keep local.**
- `pendingUpsert == false` — every local write has been acknowledged. If
  the server row now disagrees, something newer than this device said so:
  support, or another device. **Adopt the server's facts.**

This is **not** "server always wins". A user who edits her goal on a
plane keeps her edit, and the retry makes the server agree
(`testAnUnsentLocalEditIsNeverOverwrittenByTheServer`).

Two refusals stand alongside it:

- **A nil server value is never adopted.** A legacy row whose
  `goal_weight_kg` is NULL must not delete a goal the device holds —
  that is the same "lose the goal" defect arriving from the other
  direction (`testAnAbsentServerValueNeverDeletesALocalFact`).
- **Adoption is a READ.** The merged row is left `pendingUpsert == false`.
  Pushing back a row you have just adopted is a write loop at best and a
  resurrection at worst.

### The three fixes, in the order they run

1. **`AppSync.refreshProgramTruth`** — two selects, `users` and
   `program_plans`, once per user per day, only after onboarding is
   complete. Deliberately not the full hydrate: sessions, checks,
   reflections and the food journal are append-only history and do not
   need re-reading to answer *"what is my plan"*.
2. **`ProgramPlanMerge.apply`** — the field-by-field contract in §2.
3. **`restoreBodyDefaults`** — merged under the same clean-record guard,
   plus `mirrorActivityAlias`.

**The refresh runs FIRST in `onLaunch`, before `retryPendingUpserts`.**
The old order pushed before it pulled, so a stale-but-dirty row could
overwrite the server before the device ever read the repair.

**Two things the refresh deliberately does NOT do**, because running a
sign-in-shaped pass daily is not the same as running it at sign-in:

- It does not call `syncUserDefaultsFromUserRecord`, which rewrites
  eighteen `@AppStorage` keys — name, focus area, plank time,
  notification preference, commitment days. Only the body facts and the
  activity alias are mirrored. A daily overwrite of a notification
  preference would be a new bug wearing this fix's clothes.
- `hydrateUser` copies every `users` column into the local record, so it
  was worth checking whether a more frequent hydrate could revert live
  progress. **It cannot:** `currentDay`, `coreScore`, `streakCurrent`,
  `streakLongest` and `lastSessionDate` have **zero writers anywhere in
  the app** — they are inert v1 columns, and the day count has been
  derived (`EngagementDayCalculator`) since
  [[project_engagement_day]]. Checked rather than assumed.

### Filmed

`--uitest-persona-autym` → `--uitest-persona-autym-repaired`, on Home,
same launch pair, same account:

| | before | after |
|---|---|---|
| the day | `860 · kcal · add a goal weight` | `860 of **1,599** kcal` |
| protein | `62 of 70 g` | `62 of 70 g` (unchanged) |
| header | `day 27` | `day 27` (unchanged) |

**The repaired door does not write the answer.** It builds a real
`ProgramPlanHydrateRow` and runs the production
`SyncService.applyHydratedProgramPlans` + `AppSync.restoreBodyDefaults`
— the same two functions a hydrate calls. What is filmed is the merge,
not a fixture agreeing with itself.

1,599 checks by hand: BMR `10(56.245) + 6.25(160.02) − 5(21) − 161 =
1296.6` → ×1.55 (the restored `moderate` alias) = 2010 → rate
`((56.245−49.895)/56.245)/17 = 0.00664/wk` → deficit 411 → **1,599**.

### The regression test

`plankAITests/AutymRecoveryTests.swift`,
`testServerRepairReachesCustomerWithoutResettingHerProgram`. The file
opens with the paragraph explaining why it may not be deleted.

**Proven RED before GREEN.** With `ProgramPlanMerge.apply` stubbed to
`return false` and `restoreBodyDefaults` reverted to absent-only — i.e.
the exact pre-session behaviour — the suite produced **13 failures**,
including `energyBasis == .unknown`, `goalWeightKg` stuck at 56.245 kg
(124 lb) and `totalDays` stuck at 210. Restored: **5/5, TEST SUCCEEDED.**

Asserted, in the test's own words:

- resolved goal `== 110 lb`, **and** it reaches the `@AppStorage` key —
  not just the local `UserRecord`
- `124 lb → 110 lb`, `"14 lb to go"`
- **plan id unchanged · `startDate` unchanged · exactly one plan row**
- `totalDays == 119` (the horizon travels with the goal, or the rate
  stays wrong)
- the plan's start weight is still 124 lb — goal and current never
  collapse into each other again
- the weigh-in that was on file is still on file

---

## 2 · THE AUTHORITY MODEL

Every program-critical field, classified, with the merge behaviour that
follows from the class.

### `ProgramPlanRecord` (`ProgramPlanMerge`)

| field | class | on a CLEAN local row | on a DIRTY one |
|---|---|---|---|
| `id`, `userId` | IMMUTABLE IDENTITY | case-normalised only | — |
| `startDate` | IMMUTABLE IDENTITY (the day anchor) | **kept local** | kept |
| `createdAt` | IMMUTABLE IDENTITY | kept local | kept |
| `goalWeightKg` | SERVER-REPAIRABLE USER FACT | adopted | kept |
| `currentWeightKg` (start weight) | SERVER-REPAIRABLE USER FACT | adopted | kept |
| `intensityTier` (pace) | SERVER-REPAIRABLE USER FACT | adopted | kept |
| `totalDays`, `goalDate` | DERIVED | adopted | kept |
| `phase`, `archivedAt`, `completedAt` | LIFECYCLE | adopted | kept |
| `parentPlanId` | plan chain | adopted | kept |

`startDate` is immutable **on purpose**. It is what `programDay` derives
from; moving it moves what day she is on, and this codebase already
carries the incident that costs (`AppSync:520` — a re-enroll minting
`startDate = .now`). A row reached by id IS the same enrollment, so its
start date is not in dispute; if the two ever disagree, the day she has
been living in wins.

### The other classes

- **LOCAL UNSYNCED PREFERENCE** — `weightUnit`, `heightUnit`. Device
  level by design (`30` §9): a phone displays in the unit the person
  holding it picked. Not swept, not synced, not merged.
- **APPEND-ONLY HISTORY** — `weight_logs`, `session_logs`,
  `program_day_checks`, `observations`, `dose_events`, the food JSONL.
  **Insert-only stays insert-only.** Nothing in this pass touches them.
- **VERSIONED CLINICAL FACT** — `regimen_plans` (append-only version
  chains, `applySelfRegimen` chokepoint), `program_facts` (authority
  chain: prescribed › preferred › recommended › defaulted), `MethodNote
  .authority`, `CareProtocol`. **Untouched.** A consumer editor cannot
  reach any of them, and `CareProtocol`'s protein band and pace ceiling
  still clamp everything the new writers produce.

---

## 3 · THE SUPPORT REPAIR MATRIX

Four questions per fact: can she SEE what Jeni believes · can she CHANGE
it · does the change survive sign-out → sign-in · can a stale copy
resurrect afterwards.

| fact | she sees it | she edits it | survives sign-out | can resurrect | server-repairable | reaches an installed phone |
|---|---|---|---|---|---|---|
| current weight | Home, your numbers | weigh-in ritual | yes (`users` + `weight_logs`) | no | yes (weight_logs) | yes (hydrate) |
| start weight | plan screen | **no** — deliberate | yes (plan row) | no | yes | **yes (new)** |
| goal weight | your numbers · Settings · plan | goal ritual | yes | no | yes | **yes (new)** |
| height | your numbers | ruler | yes | no | yes | **yes (new)** |
| weight unit | every weight | your numbers / weigh-in | yes (device level) | n/a | no (device only) | n/a |
| height unit | your numbers | your numbers | yes (device level) | n/a | no | n/a |
| **sex (BMR term)** | **your numbers (new)** | **new** | yes (`users`) | no | yes | **yes (new)** |
| **age** | **your numbers (new)** | **new** | **band only — stated** | no | band only | yes |
| activity | your numbers | your numbers | yes (alias) | no | alias only | **yes (new)** |
| direction (lose/hold) | plan screen wording | implied by the goal | yes | no | via goal | yes |
| **pace tier** | **your numbers (new)** | **new** | yes (plan + preference) | no | yes | **yes (new)** |
| program start | Home `day N` | no — identity | yes | no | yes, and NOT merged (§2) | no, by design |
| program duration | plan / pace row | pace editor | yes | no | yes | **yes (new)** |
| calorie target | Home, plan, jeni | derived only | derived | no | via its inputs | via its inputs |
| protein target | Home | derived only | derived | no | via weight | yes |
| step target | Home | program facts | yes | no | yes | yes |
| medication plan | regimen home | dose sheet | yes | no | yes (version chain) | yes |
| dose day | Home, regimen | regimen editor | yes | no | yes | yes |
| care-team constraints | care surfaces | **no, correctly** | yes | no | clinician only | yes |

**Start weight is deliberately not user-editable.** It is what "since you
started" is measured from; letting a user rewrite it silently rewrites
every historical statement the app has made. It is server-repairable, and
now the repair reaches her.

---

## 4 · THE ENERGY INPUTS

`target = clamp(TDEE − deficit, floor: max(1200, BMR), ceiling: 3500)`,
`TDEE = MifflinStJeor(weight, height, age, sex) × activityFactor`.
**Six inputs. Two of them had no repair path at all, and two of those
screens print a promise the product could not keep.**

| input | kcal at stake | asked where | repairable before | now |
|---|---|---|---|---|
| weight | the whole equation | consult + weigh-in | yes | yes |
| height | target VANISHES below 100 cm | consult | `30` | yes |
| activity | **647 kcal** end to end | consult | `30` | yes |
| **sex** | **166 kcal of BMR ×1.375 = 228** | consult | **NO** | **built** |
| **age** | 5 kcal/yr; ≤ ~35 restored | consult | **NO** | **built (with disclosure)** |
| goal | decides the deficit | consult | `29` | yes |
| **pace** | decides the horizon, so the deficit | onramp | **NO** | **built** |

### The two broken promises

The consult's sex beat acknowledges, verbatim:

> "we'll use the more conservative equation. **you can change this
> anytime.**"

The onramp's pace screen says, verbatim:

> "pick the rhythm. **you can change it later.**"

**There was no anytime and no later.** Nothing in the app could change
`onboardingGender` or `onboardingPickedTier` after onboarding. Two
sentences the product printed and could not honour, about two of the six
inputs to the number it charges for.

### Sex — `BodyFactsStore.setSex`

An energy-equation term, presented as one. The editor offers the
consult's own four answers and states which equation each runs
(`10w + 6.25h − 5a − 161` vs `+ 5`); non-binary and prefer-not-to-say
say plainly that the conservative equation runs and gives the lower
target — **App Review §18: an assumption is shown as an assumption, not
as neutral arithmetic.** An unrecognised key is refused at the door
rather than silently becoming the conservative equation. Pinned:
`testCorrectingTheSexTermMovesTheTargetAndNothingElse` asserts the delta
IS `166 × 1.375` and that the plan id, start date, start weight, goal
and horizon are all untouched.

### Pace — `GoalWeightStore.setPaceTier`

It lives in `GoalWeightStore` and not in a store of its own **because it
recomputes `plan.totalDays` and `plan.goalDate`**, and a second writer of
those two fields is precisely the drift this line of work exists to stop.

Changing pace changes the HORIZON, never the history: same plan id, same
start date, same start weight, same goal, same logs, same medication. The
safety cap and the care protocol clamp the result exactly as they clamp
it at build time, because it is the same `ProgramGoalCalculator` call.
**Hard keeps its `HardTierGate` lock** — an editor that could unlock Hard
where the picker locks it would be a safety gate with a back door
(`testThePaceEditorCannotUnlockHardWhereThePickerLocksIt`).

---

## 5 · AGE — RE-EXAMINED FROM THE RECOVERY STANDARD, AND STILL NO MIGRATION

`30` §4 refused a `users` column for the exact age on a cost argument
(≤35 kcal). The founder was right to make me re-derive it from the
customer-recovery standard instead. Here is the real reasoning.

**The law:** *signing out and back in must not SILENTLY change the
meaning of a user answer.* The operative word is **silently**.

**Measured first.** Exact age is asked once (`onb_v5_age_years`), swept
by the `onb_v5_` prefix, and `users` carries only
`onboarding_age_range`. Worst case is not 35 kcal — the `55plus` band is
**unbounded**, so a 72-year-old comes back as 58: 14 years, ~70 kcal.

**The four options, and what actually decides it:**

- **A. Persist the exact age server-side.** It is a one-line additive
  migration. **It cannot ride this build**, and not for taste: the client
  would send `onboarding_age_years` in the `users` upsert, and until the
  migration is applied PostgREST **rejects the whole row with a 400**.
  Profile sync would break for every user on the app until the migration
  landed. A client change that is only safe *after* a deploy cannot ship
  in a build that is meant to be safe on its own. If the founder wants A,
  the order is: migration first, client in the build after. Nothing is
  prepared here, because a migration file sitting undeployed next to a
  client that needs it is a loaded gun.
- **B. Make the band canonical everywhere.** Refused: it would move the
  number for users who are currently CORRECT (a 34-year-old would become
  29, +25 kcal) to fix a state some of them are not in.
- **C. Keep the behaviour, make the assumption visible and editable.**
  **Chosen.** The row states the age the math is using, marks it
  `approximate` **exactly when it came from a band**
  (`TargetsService.ageIsApproximate`), says why in one sentence, and
  corrects in one tap.
- **D. Something smaller.** There is one, and it was a real defect:
  `profileInputs` read the band from `"ageRange"` only, while the consult
  writes `"onboardingAgeRange"`. A user holding one and not the other got
  the **32-year-old cohort default** instead of her own band. Both keys
  are read now (`TargetsService.ageBandOnFile`), and `BodyFactsStore`
  writes both.

**The law is satisfied by C**: after a sign-out the app does not quietly
use a different age, it SAYS `about 29 · approximate` and offers the
repair. Filmed.

---

## 6 · PACE — MISSING UI, NOT INTENTIONAL IMMUTABILITY

Traced: `onboardingPickedTier` → `ProgramSetupSubflow` → `plan
.intensityTier` → `ProgramGoalCalculator.weeks(for:)` →
`plan.totalDays`/`goalDate` → `energyBasis`'s rate. Caps:
`HardTierGate`, `safety_pace_cap`, `CareProtocol.maxPlanRatePctPerWeek`,
`ProgramGoalCalculator`'s ACSM floors.

Nothing in that chain says immutable. The screen that sets it says the
opposite in writing. **Built.**

**And a safety gate that could not read its own input.**
`ProgramSetupSubflow.parsedAge` switched on `"18-24"` / `"25-34"` /
`"55+"` — **a vocabulary nothing in the app writes.** `OV5Store` writes
`"18to24"` / `"25to34"` / `"55plus"`; the legacy flow wrote `"18_24"`. So
`parsedAge` returned nil for every user, `HardTierGate`'s
`guard let age = inputs.age, age < 40` locked Hard for everyone, and
`lockReason` fell through to its generic last line — **the gate told her
we hid Hard and could not say why, because it did not know her age.**

Stuck-closed is safe and still a lie on screen. It reads
`TargetsService.knownAge()` now — which returns **nil when the age is
genuinely unknown**, so the gate's missing-signal-locks-Hard contract is
preserved exactly, while the arithmetic keeps its documented 32-year-old
fallback. This is the third dead vocabulary found in that one file in two
sessions (`onboardingActivityLevel`, then `onboardingCurrentWeightKg = 65`,
now `parsedAge`).

---

## 7 · ONE SCREEN — `JKPlanNumbersSheet`

Not a new dashboard: the existing repair door, completed. Four rows
became seven — **every user-owned input to the calorie equation, and
nothing else.**

> **what your plan is built on.**
> weight today · **124 lb**
> height · **5'3"**
> goal weight · **110 lb**
> how you move · **walks here and there**
> calorie equation · **female**
> age · **34**
> pace · **steady**
>
> *your daily food target is built from these. change one and it
> recomputes.*

Its honesty rules, all filmed:

- missing → **`not set`**, and the closing line names what is missing:
  *"your daily food target needs a goal weight. we won't guess it."*
- restored-coarse → **`about 29`** with *"approximate — signing back in
  brings your age range home, not the year."*
- unrecoverable → the ambiguous activity row (`30` §9) still states what
  the math is using and names the other answer it could have been
- suppressed cohort → the goal row carries no numeral
- clinician-constrained → nothing here is; `CareProtocol` carries
  thresholds and caps, never destinations, so there is no illegal
  override to offer

**No duplicate writers.** Every row hands off to the existing owner:
`WeightLogWriter`, `GoalWeightStore`, `BodyFactsStore`, and pace to
`GoalWeightStore` because it owns the horizon.

---

## 8 · ONE DERIVED TARGET, EVERYWHERE

`plankAITests/OneTargetEverywhereTests.swift` is a table over **25
states**, each asserted three ways — `TargetsService.current().kcal`
(Home) == `PlanSummary.energyKcal` (plan) == the `targets.kcal` the chat
envelope publishes (jeni) — plus the honesty pair: no target ⇒
`missingEnergyInput` NAMES the fact, and no surface draws a number.

States covered: loss/complete · maintenance · missing goal · missing
height · missing weight · GLP-1 current · non-GLP-1 · sedentary · walks ·
moderate · athlete · male · female · unspecified · lb · kg · fresh
install · restored-after-sign-in (band age + collapsed alias) · goal
edited · weight changed · height changed · activity changed · pace
changed · server-repaired legacy plan · plan disagreeing with her goal ·
goal reached · **the fabrication signature**.

**Every customer-facing daily calorie target resolves through
`TargetsService`.** Searched: `CalorieTargetCalculator.dailyTarget` has
exactly two call sites — `TargetsService.calorieTarget`, and
`OnboardingRevealView.estimatedCalorieTarget`, which is a legitimately
different concept (the pre-purchase quote, before a plan record exists)
and is named as one.

**And the two were not running the same arithmetic.**
`EnergyLedger.ageMidpoint` was a SECOND copy of `representativeAge` that
disagreed in two places: `55plus` → 60 vs 58, and the no-band default →
30 vs 32. An over-55 user was quoted a number at the reveal that the
product would then decline to reproduce. It delegates now.

### Two findings the table produced that no reading would have

1. **She reaches her goal and the app forgets she has one.** With the
   goal met, the plan branch cannot fire and `onboardingImpliedRate`
   requires `start > goal`, so `energyBasis` returned `.unknown` — she
   lost her daily number **and** was shown *"add a goal weight"*,
   pointing at the exact fact she had already given us. Tapping it and
   re-entering the same number changed nothing. **A state the app could
   not explain and she could not repair.**
2. **The fix, written naively, resurrected the original bug.** `goal >=
   current ⇒ maintenance` also matches `goal == current == start` — the
   signature of `29` §2①'s fabrication — so a user whose goal the APP
   invented would have been handed her maintenance estimate as a daily
   target. The matrix caught it inside one run. Arrival now requires that
   the goal was a **real loss destination when it was set** (strictly
   below the weight she started from). `29`'s law survives intact:
   *holding is an instruction or an arrival, never a fallback.*

**Home says which one it is drawing:** `of 1,693 kcal · holding`. When
she reaches her goal the target jumps by the whole deficit, and a number
changing for no stated reason is a support email.

**The backward-compatibility pin holds.** The coherent persona still gets
**1,282**, asserted against Mifflin-St Jeor inlined in the test.

---

## 9 · THE PLAN MUST NEVER DISAGREE WITH THE PERSON

Adversarial combinations, each with one coherent answer or an explicit
repair state:

| state | `resolvedWeightKg` | `PlanSummary` | `energyBasis` | sync may upload | Home | jeni |
|---|---|---|---|---|---|---|
| UserRecord 124 · log 121 · plan start 124 | **121** (the log) | 121 → 110 | deficit | nothing | 121 | 121 |
| stored goal 110 · plan goal 124 | her weight | **110** | plan ignored, her answer used | nothing | agrees | agrees |
| no stored goal · plan goal 143 (above her) | her weight | **goalMissing** | unknown | nothing | door | `goal_on_file: false` |
| no stored height · local height 160 | — | uses local 160 | deficit | nothing | agrees | agrees |
| server 110 · local plan 124 | her weight | **110** | deficit @ 119d | **110** | agrees | agrees |
| maintenance chosen · loss-shaped old plan | her weight | **holding** | maintenance (rule 1 outranks the plan) | nothing | `· holding` | `kcal_basis: maintenance` |
| loss direction · maintenance-shaped plan | her weight | losing | falls to her own numbers | nothing | agrees | agrees |
| completed old plan + active new plan | her weight | the active one | its rate | nothing | agrees | agrees |
| two live plans | her weight | **earliest start** | its rate | the heal's archive only | agrees | agrees |
| archived parent + active child | her weight | the child | its rate | nothing | agrees | agrees |
| pendingUpsert stale plan | her weight | local | local | **local (hers)** | agrees | agrees |

"Never silently pick whichever record happens to be easiest" is now
structural: `resolvedWeightKg` is one function, `energyBasis` is one
resolution order, and `activePlan` is one rule (§10).

---

## 10 · THE MULTIPLE-PLAN RULE

The production repair assumed exactly one live plan. **Two readers
disagreed about which one that is:**

```
ProgramService.activePlan     sortBy createdAt DESC, fetchLimit 1
AppSync.reconcileLivePlans    keep the EARLIEST startDate
```

So between the moment an account acquires a second live plan and the next
hydrate, the app rendered **the plan the heal was about to archive** —
the interim one minted at a forced re-enroll with `startDate = today`,
which is what resets a user to day 1.

Worse: `createdAt` was not the enrollment moment on a hydrated row. The
initialiser stamps `.now` and the hydrate never read `started_at` back
(the column the upsert has always written), so **after a reinstall that
sort was ordering plans by the order of a `for` loop.**

**One rule now, both call sites: earliest `startDate`, `createdAt`
breaking a same-day tie** — and hydrated rows carry their real
`started_at`. For the overwhelmingly common one-live-plan account the
answer is identical; for a corrupted one the app picks the genuine
journey AND the same row the heal will keep. `archivedAt != nil` also
excludes a plan now, matching `reconcileLivePlans` and
`hasActivePlan` — so a support-side archive that sets only `archived_at`
is honoured.

Deterministic selection for `0 · 1 · 2 live · active+maintenance ·
active+archived · active+completed · parent/child` is pinned by
`plankAITests/PlanIdentityTests.swift` (9 tests), including: **corruption
is archived, never deleted, never replaced by a third plan**, and the
keeper is never re-pushed.

---

## 11 · THE MISSING-DATA RULE

Unchanged and reaffirmed: **no fact, no number.** `calorieTarget` returns
nil rather than falling back to TDEE; `missingEnergyInput` names which
fact; Home's empty denominator is a door onto that exact fact; the plan
screen asks; jeni publishes `kcal_missing` and `goal_on_file: false`
instead of improvising. What this pass adds is that *"we hold nothing"*
and *"we hold something coarse"* are now different sentences (§5).

---

## 12 · THE SYNC CONFLICT RULE

1. A record with an unsent local write is never overwritten, in either
   direction (plan or profile).
2. A clean local record is server truth; if the server disagrees, adopt.
3. An absent server value is never adopted over a present local one.
4. Identity (`id`, `userId`, `startDate`, `createdAt`) is never merged.
5. History is insert-only, always.
6. **Pull before push.** `refreshProgramTruth` runs before
   `retryPendingUpserts` on every launch.
7. Adoption does not set `pendingUpsert`.

### Outbound resurrection — reproduced, then proven gone

`upsertProgramPlan` sends the WHOLE row, so a local copy that stayed
stale would push 124 back over the repaired 110 the moment anything
marked it dirty. Every `ProgramPlanRecord` dirty-writer was audited:
`GoalWeightStore` (writes the field itself — correct),
`setPaceTier` (same), `ProgramService.startProgram`'s archive,
`reconcileLivePlans`' archive, `applyReattribution`'s re-key, and two
DEBUG seeders.

`testRepairedGoalIsNotResurrectedByTheNextOutboundSync` proves three
things: adoption queues no push; whatever dirties the row next carries
**110 / 119**; and the counterfactual — the same row left un-merged still
carries 124, so the test cannot silently stop testing anything.

**The residual window, named:** support repairs while the app is in the
foreground, and she dirties the plan (re-enroll / graduation) before the
next launch. That push would carry the stale row. It is one app session
wide, it requires her to re-enroll in that window, and closing it
properly needs per-field dirty tracking — a schema change. **Named, not
smuggled.**

---

## 13 · THE STATE CENSUS — READ ONLY, NOT EXECUTED

Paste into the Supabase SQL editor. It reads two tables and mutates
nothing. **Caveat:** `is_test_user` is a PostHog person property, not a
`users` column, so this counts the whole base including internal
accounts; subtract known internal ids before acting.

```sql
-- READ ONLY. Classifies every onboarded account. No writes.
with live as (
  select user_id, count(*) as live_count
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  group by user_id
),
chosen as (
  -- the SAME rule the client uses: earliest start_date wins
  select distinct on (user_id)
         user_id, id as plan_id, goal_weight_kg, current_weight_kg,
         total_days, phase, start_date
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  order by user_id, start_date asc, started_at asc
),
base as (
  select u.id                             as user_id,
         u.onboarding_goal_weight_kg      as profile_goal,
         u.onboarding_current_weight_kg   as profile_weight,
         u.onboarding_height_cm           as profile_height,
         coalesce(l.live_count, 0)        as live_count,
         c.plan_id, c.goal_weight_kg      as plan_goal,
         c.current_weight_kg              as plan_start,
         c.total_days, c.phase
  from public.users u
  left join live   l on l.user_id = u.id
  left join chosen c on c.user_id = u.id
),
totals as (
  select count(*)                                as onboarded,
         count(*) filter (where live_count > 0)  as with_live_plan
  from base
)
select cat.category, cat.n as count,
       round(100.0 * cat.n / nullif(cat.denom, 0), 2) as pct_of_population,
       cat.population
from totals t,
lateral (values
  ('onboarded accounts',
   t.onboarded, t.onboarded, 'all'),
  ('with a live plan',
   t.with_live_plan, t.onboarded, 'all'),
  ('NO live plan despite onboarding',
   (select count(*) from base where live_count = 0), t.onboarded, 'all'),
  ('MULTIPLE live plans',
   (select count(*) from base where live_count > 1), t.onboarded, 'all'),
  ('plan goal IS NULL',
   (select count(*) from base where live_count > 0 and plan_goal is null),
   t.with_live_plan, 'with live plan'),
  ('plan goal == plan start (THE FABRICATION)',
   (select count(*) from base where plan_goal is not null
      and plan_start is not null and abs(plan_goal - plan_start) < 0.05),
   t.with_live_plan, 'with live plan'),
  ('plan goal > plan start (aims above her)',
   (select count(*) from base where plan_goal is not null
      and plan_start is not null and plan_goal > plan_start + 0.05),
   t.with_live_plan, 'with live plan'),
  ('COHERENT loss plan (goal < start, >= 7 days)',
   (select count(*) from base where plan_goal is not null
      and plan_start is not null and plan_start > plan_goal + 0.05
      and total_days >= 7),
   t.with_live_plan, 'with live plan'),
  ('plan duration invalid (< 7 days)',
   (select count(*) from base where live_count > 0 and total_days < 7),
   t.with_live_plan, 'with live plan'),
  ('profile goal missing',
   (select count(*) from base where coalesce(profile_goal, 0) <= 30),
   t.onboarded, 'all'),
  ('profile goal DISAGREES with plan goal (> 0.5 kg)',
   (select count(*) from base where profile_goal is not null
      and plan_goal is not null and abs(profile_goal - plan_goal) > 0.5),
   t.with_live_plan, 'with live plan'),
  ('profile height missing',
   (select count(*) from base where coalesce(profile_height, 0) <= 100),
   t.onboarded, 'all'),
  ('profile current weight missing',
   (select count(*) from base where coalesce(profile_weight, 0) <= 30),
   t.onboarded, 'all'),
  ('maintenance-SHAPED plan for a loss-shaped profile',
   (select count(*) from base
     where plan_goal is not null and plan_start is not null
       and abs(plan_goal - plan_start) < 0.05
       and profile_goal is not null and profile_weight is not null
       and profile_weight > profile_goal + 0.05),
   t.with_live_plan, 'with live plan'),
  ('archived_at set while phase still live',
   (select count(*) from public.program_plans
     where archived_at is not null
       and phase in ('active','maintenance','recomp','pause')),
   t.onboarded, 'all')
) as cat(category, n, denom, population)
order by 2 desc;
```

**Diagnostic follow-up, ids only, no emails**, run only after the census
shows a population worth acting on:

```sql
-- READ ONLY. Ids for the two classes a client-side repair reaches.
select p.user_id, p.id as plan_id, p.goal_weight_kg, p.current_weight_kg,
       p.total_days, p.start_date,
       u.onboarding_goal_weight_kg as profile_goal
from public.program_plans p
join public.users u on u.id = p.user_id
where p.phase in ('active','maintenance','recomp','pause')
  and p.archived_at is null
  and p.goal_weight_kg is not null
  and p.current_weight_kg is not null
  and (
        abs(p.goal_weight_kg - p.current_weight_kg) < 0.05      -- fabricated
     or (u.onboarding_goal_weight_kg is not null                -- disagreeing
         and abs(u.onboarding_goal_weight_kg - p.goal_weight_kg) > 0.5)
  )
order by p.start_date desc;
```

**Why this matters more than it did yesterday:** before this build a
row-level repair could not reach an installed phone. It can now. The
census sizes the repair, and the repair now works.

---

## 14 · THE EXACT FORMULA — CONFIRMED UNCHANGED

```
BMR    = 10·kg + 6.25·cm − 5·age − 161      (female / unspecified)
       = 10·kg + 6.25·cm − 5·age + 5        (male)
TDEE   = BMR × {1.2 · 1.375 · 1.55 · 1.725}
deficit/day = (rate%/wk × kg) × 7700 / 7
target = clamp(TDEE − deficit, floor: max(1200, BMR), ceiling: 3500)
```

**Not one constant changed this session.** No exercise compensation, no
HealthKit addition, no medication term. `CalorieTargetCalculator` has a
zero diff. What changed is **which inputs reach it** (age band under
either key; the pre-purchase quote's age) and **when it is allowed to
publish** (arrival is maintenance; a fabricated goal is not).

---

## 15 · THE EXACT USER-FACING ASSUMPTIONS

Every place the app uses something she did not give us, in her words, on
screen:

1. *"we run the more conservative equation — the lower target"* — sex,
   for non-binary / prefer-not-to-say.
2. *"approximate — signing back in brings your age range home, not the
   year. tap to set it exactly."* — age from a band.
3. *"this is what your target is using. it could also have been 'walks
   here and there' — tap to say which."* — the unrecoverable legacy alias.
4. *"of 1,693 kcal · holding"* — the number is a maintenance estimate.
5. *"your daily food target needs a goal weight. we won't guess it."*
6. *"dv is a general daily value, not your target"* — pre-existing.
7. *"an estimate"* on the plan screen's food row — pre-existing.

No new medical claim, no diagnosis, no guaranteed loss, no clinically
exact expenditure, no drug dosing advice, no photo-derived measurement.

---

## 16 · ACCESSIBILITY

Re-walked at AX5 (`content_size accessibility-extra-extra-extra-large`)
and on the SE.

- `124 lb` · `5'3"` · `110 lb` · `1,599` · `1,693` · `about 29` — **no
  numeral wraps or truncates at any size.** The `124` → `12`/`4` law and
  the `12…` weigh-in law both hold on the new rows.
- The seven rows scroll; the `done` capsule stays pinned with its
  hairline; every editor's CTA is reachable.
- The maintenance reference (`of 1,693 kcal · holding`) has no
  `lineLimit` and takes `fixedSize(vertical:)`, and Home's kcal cell
  stacks at accessibility sizes — so the word that carries the meaning
  wraps rather than truncating, which is the same fix `30` §12 made for
  `kcal · add a goal weight`.
- VoiceOver distinguishes the three weights by their row labels —
  `"weight today, 124 lb"`, `"goal weight, 110 lb"` — and the plan screen
  states the start weight in its pair. None of them announces a bare
  "weight".

---

## 17 · PROOF, AND THE PROTECTED-PATH DIFF

| suite | count | verdict | exit |
|---|---|---|---|
| `plankAITests` | **1139** (was 1103, **+36**) | `** TEST SUCCEEDED **` | 0 |
| `PlankSyncTests` | **9** (was 6, **+3**) | `** TEST SUCCEEDED **` | 0 |
| `PlankFoodTests` | **192** (unchanged) | `** TEST SUCCEEDED **` | 0 |

Read together, per `30` §11's lesson: `Executed N with 0 failures` is not
a pass signal on its own. Every run above was checked for the final
verdict line AND the expected count AND a zero process exit, from a
single non-concurrent `xcodebuild`. Release configuration compiles.

**Protected paths vs the reviewed release `1710180`, uncommitted work
only (everything else was committed and documented in `26`–`30`):**

| path | this session |
|---|---|
| `PlankApp/Payment` | **empty** |
| `PlankApp/Views/Paywall` | **empty** |
| `PlankApp/Auth` | **empty** |
| `PlankApp/App/AppPhase.swift` | **empty** |
| `PlankApp/Info.plist` | **empty** |
| `plankAI.entitlements` | **empty** |
| `supabase/` | **empty** — no migration written, none needed |
| `PlankApp/Analytics` | **empty** |
| `Packages/PlankSync` | **+119 src / +85 test** — §1, the merge |
| `PlankApp/Health/EnergyLedger.swift` | **+23 / −12** — §8, one age map |

**`Packages/PlankSync` moved and it could not have been avoided.** The
insert-only rule IS the defect; it lives in `applyHydratedProgramPlans`,
and there is no other place to fix it. The change is additive
(`ProgramPlanMerge`, a new file), the DTO gained one optional decoded
field (`started_at`, a column the upsert has always written), and two
symbols became `public` so the app's own regression suite can drive the
real merge instead of a copy of it.

**No Edge Function deploy. No migration. No production SQL executed. No
production data mutated.** The standing founder gate is unchanged:
`supabase functions deploy food-vision --no-verify-jwt`.

---

## 18 · THE SUPPORT TICKET GAUNTLET

| # | the email | can she fix it herself | exact taps | server-repairable | reaches her phone | can it resurrect |
|---|---|---|---|---|---|---|
| A | "my goal says 124 but I entered 110" | **yes** | Settings → your numbers → goal weight → ruler → save | yes | **yes (new)** | no |
| B | "my calories went up after I signed back in" | **yes** | your numbers → how you move (and/or age) | yes | yes | no |
| C | "I entered the wrong sex" | **yes (new)** | your numbers → calorie equation → pick → done | yes | yes | no |
| D | "wrong activity level" | yes | your numbers → how you move | yes (alias) | yes | no |
| E | "I chose the wrong pace" | **yes (new)** | your numbers → pace → pick → done | yes | **yes (new)** | no |
| F | "my starting weight changed when I weighed in" | n/a — it did not | plan screen states start; weigh-in never writes it | yes | yes | no |
| G | "I switched to kg and some screens show lb" | yes | your numbers → weight/height → unit toggle | no (device-level, by design) | n/a | no |
| H | "my plan disappeared after I signed in" | **partly** | relaunch: the heal + the refresh run on launch now | yes | **yes (new)** | no |
| I | "my goal is right on one screen and wrong on another" | n/a — cannot happen | one resolver, pinned by §8 | — | — | — |
| J | **"you fixed my account but my phone still shows the old number"** | **yes, without doing anything** | next launch (≤ once/day refresh); no sign-out | yes | **yes — THE FIX** | no |

**B is worth its own line.** It was three separate defects across two
sessions: the activity alias round-trip (`30` §4, 215–431 kcal), the age
band (§5 here), and `EnergyLedger`'s second age table (§8). All three
moved the number without her touching anything.

**G's honest limit:** the unit is device-level on purpose, so a second
device does not inherit the first one's preference. Two phones can show
two units. That is a choice, stated.

**H's honest limit:** if her plan row is genuinely gone from the server,
nothing on the phone can bring it back. The heal covers the far more
common case — a duplicate plan out-ranking the real one.

---

## 19 · WHAT CHANGED

1. **The recovery contract.** `refreshProgramTruth` (reach) +
   `ProgramPlanMerge` (merge) + `restoreBodyDefaults` (mirror), pull
   before push.
2. **`ProgramService.activePlan`** — one rule for which plan she is
   living in, matching the heal, with `createdAt` restored from
   `started_at` on hydrate.
3. **The sex term is editable**, and says which equation it runs.
4. **The age is stated, marked approximate when it is**, and editable;
   the band is read under either key.
5. **The pace is editable**, and keeps the Hard lock.
6. **`HardTierGate` can read an age** for the first time.
7. **Arrival is maintenance**, and the fabrication signature still is not.
8. **Home says `· holding`** when the number is a maintenance estimate.
9. **`EnergyLedger.ageMidpoint` delegates** — the reveal and the app run
   the same age.
10. Two DEBUG doors: `--uitest-persona-autym[-repaired]`; three new
    focus keys on `--debug-plan-numbers-focus` (`sex` · `age` · `pace`).

## 20 · WHAT WAS ALREADY RIGHT

- `hydrateUser` copies every `users` column and correctly refuses a
  record with a pending local edit. The pull was fine; the mirror was not.
- `upsertProgramPlan` clears `pendingUpsert` only inside its success
  branch — which is the entire reason the merge rule has a trustworthy
  signal to stand on.
- `GoalWeightStore` mutates the plan in place, never touches the start
  weight, clamps to BMI 18.5, records the direction explicitly.
- `reconcileLivePlans` archives rather than deletes, and pushes the heal.
- `applyReattribution`'s fresh-id invariant.
- Numeric suppression, the `safety_pace_cap == -1` sentinel, the GLP-1
  pace floor and protein band, `CareProtocol`'s clamps, and the fact that
  **no clinician-authored goal weight exists anywhere in the product** —
  so no consumer editor can override a care team.
- The energy formula, the protein formula, the unit round-trip.

## 21 · WHAT I REFUSED TO CHANGE

- **A `users.onboarding_age_years` column** (§5). Not on cost — on
  ordering: the client change is unsafe until the migration is applied,
  so it cannot ride a build that must be safe on its own.
- **Making the merge general.** Only `program_plans` and the `users` body
  facts merge. History stays insert-only.
- **`startDate`.** Server-editable in principle, never merged in
  practice; the day she has been living in wins.
- **Editable start weight.** It is what every "since you started"
  sentence is measured from.
- **The deficit branch when a plan still describes a real loss** — `30`
  §17's call, not reopened.
- Water, widgets, streaks, health scores, Body Scan placement, Home's
  design, onboarding's design, any new analytics event, any paywall /
  pricing / auth change.

## 22 · WHAT STILL CANNOT BE SELF-REPAIRED

- **The start weight.** Deliberate; support-repairable, and the repair
  now lands.
- **The exact age after a sign-out.** Coarse to ±5 years (±14 in the
  unbounded `55plus` band). Stated, editable, not lossless.
- **A plan row genuinely deleted server-side.** Nothing on the device can
  restore it.
- **The residual resurrection window** (§12): support repairs while she
  is in the app AND she re-enrolls before the next launch.
- **Two devices, two weight units** (§18 G).
- **`onboardingActivityLevel`** is still in the sign-out sweep list with
  zero writers — harmless, and the sweep list is still the wrong place to
  learn what is written.
- **Nothing here can be falsified against a payer.** The measurement
  contract's first clean read still gates every product decision; §13's
  census does not need it.

---

## 23 · THE FIVE ANSWERS

**1. If Autym installs this build without deleting her account, what
exactly happens to her 124-lb stale local plan?**

Launch → `AppSync.onLaunch` → `refreshProgramTruth` (first, before
anything can dirty a row; she has completed onboarding and today's stamp
is unset) → two selects: `users` and `program_plans` →
`hydrateUser` sees her local `UserRecord` clean and copies the repaired
`onboarding_goal_weight_kg = 110` in → `hydrateProgramPlans` →
`applyHydratedProgramPlans` finds her plan id already local, so
`ProgramPlanMerge.apply` runs → the row is clean, so it adopts
`goalWeightKg 124 → 110`, `totalDays 210 → 119`, `goalDate`, and leaves
`id`, `startDate`, `createdAt` and the 124 lb start weight alone →
`restoreBodyDefaults` mirrors 110 into `@AppStorage` →
`mirrorActivityAlias` → `reconcileLivePlans` (she has one; no-op) →
`retryPendingUpserts` runs afterwards and has nothing of hers to send.

Home draws `of 1,599 kcal` under `day 27`. The plan screen reads
`124 lb → 110 lb · 14 lb to go`. Jeni's envelope carries the same
integer with `kcal_basis: deficit`. **No new program, no reset day count,
no lost history.** Filmed, both frames.

**2. Can Autym's phone ever write 124 back over the repaired 110 after
this build? — NO.**

Proven three ways: adoption leaves `pendingUpsert == false`, so nothing
is queued; the pull runs before the push on every launch, so a stale
dirty row cannot get out first; and after the merge the local row EQUALS
the server row, so any later whole-row upsert sends 110 / 119
(`testRepairedGoalIsNotResurrectedByTheNextOutboundSync`, including the
counterfactual that the same row left un-merged still carries 124). The
one residual window is named in §12 and requires her to re-enroll inside
a single app session during which support repairs her row.

**3. The single remaining program fact most likely to produce a refund
request:** **the age after a sign-out.** Not because 25–70 kcal is large,
but because it is the last input that changes her number **while she is
doing nothing**, and "my calories changed and nobody told me" is the
sentence that produced this whole line of work. It is now stated and
correctable, which converts it from a silent change into a visible
approximation — but it is the only one left that still moves on its own.

**4. How many existing users are affected: not known, and not guessed.**
§13 is the read-only census. `plan goal == plan start` sizes the
fabrication population exactly; `profile goal DISAGREES with plan goal`
sizes the population this build's merge repairs on its own. Both were
uncountable before, because no query had been written for them and no
client could have acted on the answer.

**5. If you ship tonight, the worst plausible boring failure left:**
a user with a `users` row whose `onboarding_goal_weight_kg` is NULL and a
plan whose goal the app fabricated. The merge cannot repair her — there
is nothing on the server to repair her WITH — so she sees no target and
`kcal · add a goal weight`. That is honest, one tap from fixed, and
strictly better than the maintenance number she is being shown today.
**But it is a paying customer opening the app to a missing number she did
not ask to lose**, and until §13 is run we do not know how many she is.

---

**SAFE FOR NEXT BUILD: YES.**

Not because the suite is green. Because the gauntlet in §18 is
survivable: every one of the ten emails now has either an exact sequence
of taps she can perform herself, or a server-side repair that provably
reaches her phone — and the one email that had neither, J, is the one
this session was written to answer.
