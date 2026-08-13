# THE APP MUST BE RIGHT — a correctness, parity and first-use audit

**Status: BUILT 2026-08-13.** Not an era. A stop-and-check triggered by
a paying customer's support message, which turned out to be two
symptoms of one defect that had been in the product for a long time.

No migration. **Zero diff against the reviewed release (`1710180`) in
Payment, Paywall, Auth, `Packages/PlankSync`, `supabase/migrations`,
`AppPhase`, `Info.plist`, entitlements.** Zero HealthKit read-type
change. Zero new analytics events. `e5.firstPlate.enabled` still false.
The Edge Function is untouched — still written, still not deployed.

**One protected path moved and it is documented in §9:**
`PlankApp/Sync/AppSync.swift`, +31 lines, additive only.

12 files modified, 3 added (+5 test files), 1073 app tests (was 1035).

---

## 1 · THE CUSTOMER MESSAGE

> "I've been using the JeniFit app and wanted the goal weight to be set
> at 110. However, the goal is set at 124, my current weight. I am also
> gaining tons of weight after 2 weeks with this app because it has me
> in a caloric surplus for my height (5'3")."

Her causal claim is not established and this document does not assert
it. Two weeks of scale movement has many explanations and Jeni cannot
distinguish them.

**But her two observations are one bug, and it is ours.**

Every code path that loses the goal weight ALSO silently converts the
plan to maintenance, because they run through the same line:

```swift
static func planImpliedRate(...) -> Double {
    guard !CohortStore.isMaintenanceMode else { return 0 }
    guard let plan,
          let start = plan.currentWeightKg, start > 30,
          let goal  = plan.goalWeightKg,  goal  > 30,
          start > goal,
          plan.totalDays >= 7
    else { return 0 }        // ← FOUR DIFFERENT FACTS, ONE RETURN VALUE
    …
}
```

`0` means "no deficit", and `dailyTarget(lossRatePctPerWeek: 0)` is
exactly TDEE. So **"she chose maintenance", "her plan has not been
built yet", "her plan is corrupt" and "she has no goal on file" all
resolved to the same thing: a maintenance energy target, published as
her daily target, with nothing anywhere saying so.**

For a 5'3" 124 lb woman the app's own arithmetic makes that **1,707
kcal** at the default light activity factor. If her real expenditure
sits nearer sedentary (1,490), that number is a surplus. The app was
not lying about the arithmetic. It was lying about **what the number
meant.**

---

## 2 · CAN 110 BECOME 124? YES — FOUR WAYS

Traced end to end through the live flow (`OnboardingV8Flow` → `OV5Store`
→ `handleOnboardingComplete` → `ProgramOnrampView` → `ProgramSetupSubflow`
→ `TargetsService`), not by grepping `goalWeightKg`.

**① The fabrication.** `OV5Store.assembleData()`:

```swift
data.goalWeightKg = goalWeightKg > 0 ? goalWeightKg : currentWeightKg
```

An absent goal was **published as the current weight** and written to
`onboardingGoalWeightKg`. That is her exact sentence — *"the goal is
set at 124, my current weight"* — produced by the app, and it reads
downstream as a deliberate "maintain where I am".

**② The invented floor.** `ProgramSetupSubflow.safeGoalWeightKg`:

```swift
max(goalWeightKg, ProgramGoalCalculator.weightForBMI(18.5, heightCm:))
```

With `goalWeightKg == 0` this is not a clamp, it is an **invention**:
the plan is built targeting BMI 18.5 — the lowest healthy weight for
her height, 104 lb at 5'3" — a number she never saw and never chose.

**③ The default that belongs to nobody.** Two views declared
`@AppStorage("onboardingGoalWeightKg") private var goalWeightKg: Double = 60`.
60 kg = 132 lb. Any user whose key was missing got a stranger's goal.

**④ THE RESTORE HOLE — the one that reaches real users hardest.**
`AppSync.clearOnboardingUserDefaults()` correctly sweeps
`onboardingHeightCm`, `onboardingCurrentWeightKg`,
`onboardingGoalWeightKg` and `onboardingGender` on sign-out / account
switch / delete: they are identity-scoped body data and leaking them to
the next account on a shared device would be worse.

`syncUserDefaultsFromUserRecord` then restores **fifteen** keys after
hydrate — name, motivation, age band, activity, barriers, focus area,
plank time, session length, body focus, notification prefs, enrollment
flags — and **not those four**, though `UserRecord` carries all four
and syncs them to Supabase.

So the returning payer — new phone, restore purchase, or just
sign-out/sign-in — came back with `heightCm = 0`. `calorieTarget`
guards on `heightCm > 100` and returns nil, so **her energy number
simply vanished**, and her goal fell to the 60 kg default. The server
had known all of it the whole time.

---

## 3 · THE CALORIE TARGET — EXACTLY HOW IT WORKS

Unchanged, and correct: **Mifflin-St Jeor BMR × an activity factor,
minus a pace-implied deficit, clamped.**

```
BMR    = 10·kg + 6.25·cm − 5·age − 161   (female / unspecified)
TDEE   = BMR × {1.2 sedentary · 1.375 light · 1.55 moderate · 1.725 active}
deficit/day = (rate%/wk × kg) × 7700 / 7          (Hall 2012 ramp)
target = clamp(TDEE − deficit, floor: max(1200, BMR), ceiling: 3500)
```

Inputs, and where each comes from: weight = latest `WeightLogRecord`
(not the onboarding snapshot — the v2 fix); height/age/sex/activity =
`TargetsService.profileInputs()`; rate = the plan's own implied
`(start − goal) / start / weeks`.

**There is no activity double-count, no exercise compensation, no
HealthKit addition and no medication adjustment.** Steps and workouts
never raise the target. The floor never becomes the target — it is
`max(1200, BMR)`, and it binds only when a chosen pace would push
below BMR (as it does for this persona at anything steeper than about
0.4%/wk). The 7700 kcal/kg constant is a documented ramp
approximation, and the reveal frames the output as a starting plan.

**The formula was never the bug. The SEMANTICS of the output were.**

---

## 4 · WHAT SHIPPED

### `TargetsService.EnergyBasis` — three states that used to be one

```swift
enum EnergyBasis {
    case deficit(ratePctPerWeek: Double)   // a real loss plan
    case maintenance                        // she or a safety rule asked
    case unknown                            // we do not know → NO number
}
```

Resolution order, most-authoritative first:

1. **Maintenance was asked for** — her own goal direction, a persisted
   maintenance program mode, or `safety_pace_cap == 0` (pregnancy /
   ED screen / BMI < 18.5). Clinical instruction outranks a loss goal
   still sitting in storage.
2. **The plan she holds**, when it describes a real loss **and agrees
   with her stated goal**.
3. **Her own onboarding numbers**, through the SAME
   `ProgramGoalCalculator` and the SAME picked tier the pre-purchase
   reveal already showed her. Not an invented target — the one she was
   quoted before she paid. This matters because the post-purchase
   onramp is two taps she may not have taken, and food logging does
   not wait for it.
4. **Unknown → `calorieTarget` returns nil.** No goal, no maintenance
   choice, no number. Silence is the honest output.

**THE NUMBER SHE SEES IS THE NUMBER THE MATH USES.** A plan record can
carry a goal she never chose (hydrated from an older era of the
account). It used to win silently — the app computed a deficit toward a
destination that appeared on no screen. **Frame review caught this
live**: the new plan screen rendered `124 lb → 143.3 lb` for a persona
who had said 110. Her answer decides now; the plan keeps authority over
the horizon only while it aims at the same place.

### `PlanSummary` — "what is my plan?" as one answerable object

Pure, tested, and the same object the edit surface writes back into, so
"what is my plan" and "change my plan" cannot drift apart. Its laws are
refusals: it never invents a goal, never states a distance it cannot
compute, says "holding" only when holding was chosen, and under numeric
suppression carries **no numerals at all** (and never asks a suppressed
cohort for a goal weight).

### THE POST-PURCHASE SCREEN — before → after

Before, after ~45 questions and ~$50:

> **your program is ready.**
> we used what you told us in onboarding to build your plan.
> each day → a ritual of 3 to 5 beats · food → paced, never a strict
> diet · movement → matched to your energy · the method → a 2-minute
> read

Four promises identical for every human alive. **Not one of her
numbers.**

After:

> **your plan is here.**
> **124** lb  →  **110** lb
> 14 lb to go · about 17 weeks at your pace        [change my goal]
>
> EACH DAY
> protein → 90 g, your floor
> food → about 1,282 kcal, an estimate
> movement → 7,500 steps, offered never owed
> medication → sunday's shot is still open
> the method → a 2-minute read, most days

The medication row uses the same `DoseStanding` engine Home does — one
sentence, whichever screen asks — and keeps the same discretion (the
product is never named; a pill is never called a shot). **For a
non-medicated user it draws nothing.**

**When the goal is the one thing missing, the screen ASKS**:

> one number is missing: *where you'd like to land*. it sets your pace
> and your daily food target.   [ set my goal weight ]

and the food row reads *"set your goal and this arrives"* instead of
quoting a maintenance number at a weight-loss user.

### `JKGoalRitual` + `GoalWeightStore` — the missing floor

Until today **no surface in the app could show or change the goal
weight.** `EditProfileView` is titled "your pace." and edits exactly
one value: `workoutLevel`. A user who mis-set her goal in onboarding
had one repair available: delete her account.

The editor is the same instrument as the weigh-in and the same one
onboarding taught her on day zero — the tick ruler with haptic detents,
in whole display units (a goal weight in tenths is false precision
about an intention). It states the live distance and horizon, and below
BMI 18.5 it says where it will aim her instead.

`GoalWeightStore` is the one writer, because the goal lives in three
places: the stored answer, the plan record the target derives from, and
the `UserRecord` that survives a sign-out. What it refuses:

- **It never restarts her program.** The active plan is mutated in
  place; `startDate` and the plan id are untouched. Minting a fresh
  plan resets the day count — the documented incident at `AppSync:520`.
- **It never touches the start weight.**
- **It never quietly accepts an unhealthy goal** — it clamps to BMI
  18.5 and returns `wasClampedToHealthyFloor` so the surface can say so.
- It records the direction **explicitly** (`lose` / `maintain`), so no
  downstream reader has to guess what "goal equals current" means.

Reachable from Settings → **goal weight · 110 lb** (the row states the
number, so she can confirm we still hold it without opening anything;
"not set" is the honest empty), and from the plan screen.

### The unit she chose is the unit she sees

Onboarding's rulers persist her lb/kg answer to `onb_v5_unit_lb`. The
entire app reads `weightUnit`, **which onboarding never wrote.** It
defaulted to "lb". A user who typed kilograms on the ruler met pounds on
every screen afterwards — the weigh-in, Becoming, Home's tile, the
journey read, the visit packet — with no setting anywhere to change it.
One line; three tests.

---

## 5 · WHAT FRAME REVIEW CAUGHT

1. **`124` rendered as `12` over `4`** on the new plan screen at AX5 —
   the row could not fit and SwiftUI wrapped *inside the numeral*. A
   weight-loss app showing a broken weight is the worst frame in the
   product. The pair stacks at accessibility sizes now, and no numeral
   may wrap at any size.
2. **The daily weigh-in truncated the weight to `12…` at AX5** —
   pre-existing, on the second most-used action in the product (72
   users / 193 events / 90 days), and it had **no film door**, so its
   AX5 behaviour had never been looked at. `--debug-weigh-in` added;
   the readout shrinks to fit and never hides a digit.
3. **The goal ritual lost its title under the status bar and its CTA
   off the bottom at AX5.** Everything above the instrument scrolls
   now; the ruler stays outside the ScrollView so its drag is never
   contested, and the CTA is always reachable.
4. **The plan and the stored goal disagreeing** (§4) — invisible in
   code, obvious in a frame.

---

## 6 · WHAT I REFUSED TO BUILD

**A water tracker — refused again, on new grounds.** E9 refused it
because no credible body prescribes a personal fluid volume. That still
holds and 2026 sources confirm it by disagreeing with each other: 2-3 L,
91-125 oz, 80-100 oz — three numbers from three *commercial* sources
(GoodRx, Ro, Fella, PlexusDx), not one guideline body. **What has
changed is the mechanism, and it is real:** GLP-1 receptor activation
suppresses thirst cues while slowing gastric emptying, and GI symptoms
are the cohort's top side effect — so dehydration is a genuine,
cohort-specific risk, and MeAgain sells "protein, fiber and water goals"
as a trio. The honest shape is therefore **a log with no target**, read
from and written to HealthKit `dietaryWater` rather than invented as a
second source of truth. That needs a new HealthKit read type in a
purpose string — an `Info.plist` change, a protected path, with a build
in review. **Named, not smuggled.**

**Body Scan — DEMOTE FURTHER, do not delete.** 90 days, current build:
`diet_education_lesson_viewed` 464 users · `workout_start` 203 ·
`breathwork_session_started` 149 · `food_log_saved` 82 ·
`weight_logged` 72 · `regimen_changed` 50 · `jeni_chat_message_sent` 36
· `becoming_opened` 20 · **`body_scan_kept` 8** · `dose_marked` 3.
And the literature gives it nothing to stand on: the 2024-25
self-monitoring RCT corpus (SMARTER, Spark) covers **diet, activity and
weight** — there is no evidence base for photographic body tracking as
an intervention. But 8 users kept **56** scans: the people who use it,
use it weekly. It also does not manufacture false precision — it
produces WORDS via `BandProfile`, never a number from a photo, local
first, backup off by default. **So: it keeps its place for the eight
and must stop consuming first-run attention.** The previous session
already demoted its chooser door; the remaining Home tile is the next
thing to cut, and it is one line.

**The estimated medication-level curve** (§28 §2), **a home-screen
widget**, **Food Book depth**, a migration, an analytics event, a
paywall/pricing change, a streak, a health score.

---

## 7 · WHAT I EXPECTED TO BE BROKEN AND WAS NOT

- **The energy formula.** Mifflin-St Jeor, one activity factor applied
  once, no exercise compensation, no HealthKit addition, no double
  count. It is the standard and it is implemented correctly.
- **The protein formula.** One source of truth, cohort-aware,
  band-clamped so a small body is never pushed above the cited
  advisory range.
- **Unit round-trips.** lb → kg → lb is exact across 90-320 lb.
- **`ProgramSetupSubflow` being unreachable.** It is reachable — via
  `ProgramOnrampView`, which is the post-purchase screen itself.
  `ProgramIntroFullScreenCover` having no call sites is a *file name*
  that no longer matches its contents.
- **The safety gate.** `safety_pace_cap` defaults to `-1`, not `0`, so
  the zero-deficit branch cannot fire by accident.

---

## 8 · PROOF

- **1073/1073 app** (was 1035; **+38**). Release configuration compiles.
- Protected paths verified **empty** against `1710180`: Payment,
  Paywall, Auth, `Packages/PlankSync`, `supabase/migrations`,
  `AppPhase.swift`, `Info.plist`, entitlements. `supabase/` untouched
  this session.
- Filmed: the post-purchase plan before → after · the no-goal ask on a
  clean small device · the goal ritual · Settings' goal row · Home for
  the persona · AX5 on all three changed surfaces, before and after.
- New DEBUG doors: `--uitest-persona-customer` (5'3" · 124 lb · goal
  110 lb) · `--uitest-persona-nogoal` · `--uitest-persona-home` ·
  `--debug-goal-ritual` · `--debug-weigh-in`.

**The backward-compatibility pin matters most.** Every existing user
holding a real plan whose goal matches her stored answer gets the
byte-identical number she got before — asserted against the
pre-change arithmetic, inlined in the test. The only users whose
number changes are the ones who were being shown a **wrong** number.

---

## 9 · THE PROTECTED PATH THAT MOVED

`PlankApp/Sync/AppSync.swift`, **+31 insertions, 0 deletions.** One new
static function and one call site.

The restore hole (§2④) IS in Sync — the bug cannot be fixed anywhere
else, and its effect is that a returning payer loses her energy target
entirely. `restoreBodyDefaults(from:into:)` is:

- **additive only** — nothing existing was edited;
- **absent-only** — it never overwrites a value the device already
  holds, because a local write is the newer fact (she may have changed
  her goal offline);
- **pure over (record, defaults)** — no container, no network, four
  tests including "an empty record writes nothing";
- **no schema, auth or transport change of any kind.**

---

## 10 · STILL BELOW THE BAR

- **An existing user already in the broken state loses her Home kcal
  denominator** and is not pointed at the repair. That is strictly
  better than a wrong number, and Settings → goal weight fixes it, but
  Home should say so. The fix is to make the empty denominator a door.
- **`ProgramSetupSubflow` has ZERO analytics** — the screen that builds
  every user's plan is completely unmeasured. `$screen: ProgramOnramp`
  is the only signal, and it cannot distinguish "committed" from
  "bounced".
- **`onb_consent_personalize`, `onb_v5_supports`,
  `onboardingEatingCadence` and `onboarding_appetite_return` have no
  readers outside onboarding.** Four questions that change nothing.
- **The Body Scan Home tile** (§6).
- **PlankFood's 187 package tests could not be executed** — the
  `PlankFood` scheme in this checkout has no test action configured.
  `Packages/` has a **zero diff** this session, so they are unaffected
  by construction, but that is an argument, not a run.

**SAFE FOR NEXT BUILD: YES.**
