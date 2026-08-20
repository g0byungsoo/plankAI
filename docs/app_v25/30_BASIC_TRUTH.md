# BASIC TRUTH — an end-to-end audit of the facts the program is built on

**Status: BUILT 2026-08-14.** Not an era. The second half of the
2026-08-13 stop-and-check: that pass fixed the paths that LOSE the goal
weight. This one asked whether a user can trust the facts underneath —
end to end, from what she tells Jeni to what comes back after she signs
in again.

No migration. **Zero diff against the reviewed release (`1710180`) in
Payment, Paywall, Auth, `Packages/PlankSync`, `supabase/`,
`AppPhase.swift`, `Info.plist`, entitlements.** Zero HealthKit change.
Zero analytics change — no event added, renamed or redefined; the
measurement contract is untouched. `e5.firstPlate.enabled` still false.
The Edge Function is untouched — still written, still not deployed.

16 files modified, 3 added. **1103/1103 app** (was 1076; **+27**) ·
**192/192 package** (see §11 — they were runnable all along).

---

## 1 · THE BAR, AND WHERE IT BROKE

> WHAT SHE TELLS JENI = WHAT JENI STORES = WHAT JENI COMPUTES =
> WHAT JENI SHOWS = WHAT JENI USES TOMORROW = WHAT RETURNS AFTER
> SIGN-IN = WHAT SHE CAN REPAIR HERSELF.

Walked against the regression persona — **5'3" · 124 lb · goal 110 lb ·
female · "walks here and there"** — the chain broke in four places, and
three of them were visible on screen before a line of code changed.

| | fresh install | after sign-out → sign-in |
|---|---|---|
| the plan screen said | **about 1,282 kcal** | **about 1,537 kcal** |
| Home said | **of 1,419 kcal** | **of 1,690 kcal** |

**Four numbers, one body, one afternoon.** Every one of them was
labelled "your daily food target". The customer's sentence — *"it has me
in a caloric surplus"* — is what the top-right cell feels like.

---

## 2 · THE FRAME THE LAST PASS BELIEVED IT HAD KILLED

`29_THE_APP_MUST_BE_RIGHT` §4 records a frame review catching the new
plan screen rendering `124 lb → 143.3 lb` for a persona who said 110,
and the fix: *"her answer decides now."*

**It is still live.** Filmed on the shipping build, `--uitest-persona-
customer --uitest-persona-nogoal`:

> **124** lb → **143.3** lb · *your goal*
> you reached your goal
> food — about **1,281 kcal**, an estimate

A goal 19 lb ABOVE her body. The words "you reached your goal". And a
1,281 kcal **deficit** target. Three statements that contradict each
other, on the first screen a payer sees, all built on a destination that
appears on no screen she has ever seen.

The fix landed on the branch where she HAS a stored goal. Two lines let
it back in when she has none:

```swift
// TargetsService.planAgreesWithHer
let stored = d.double(forKey: "onboardingGoalWeightKg")
guard stored > 30 else { return true }        // ← nothing to disagree with

// PlanSummary
guard let plan, let g = plan.goalWeightKg, g > 30,
      let s = plan.currentWeightKg, s > g else { return nil }
```

`return true` means "the plan may speak for her". And the coherence
check compares the plan's goal against **the plan's own start weight**,
which can be years stale — 75 kg here, against her real 56 kg. So
"75 → 65" was adopted as a 56 kg woman's goal, and passed the guard
because 75 > 65.

**The rule now:** a plan's goal may stand in place of her answer only
while it is a destination for **the body in front of us**. `goal <
currentWeight`, or the goal is missing and the screen asks. Nothing
changes for anyone who has a stored goal — the narrowest possible cut,
and it lands exactly on the broken population.

After: the plan screen asks (*"one number is missing: where you'd like
to land"*), the food row reads *"set your goal and this arrives"*, and
Home's denominator becomes a door.

---

## 3 · ONE LADDER FOR "HER WEIGHT"

Five readers resolve the weight the arithmetic runs on. Four agreed:

```
latestWeightKg ?? onboardingCurrentWeightKg
```
— `PlanSummary`, `proteinTargetLight`, `GoalWeightStore`,
`ProfileHubView`.

`TargetsService.current` — **the one Home renders** — put the plan's
start weight in the MIDDLE:

```swift
latestWeightKg ?? plan?.currentWeightKg ?? onboardingCurrentWeightKg
```

`plan.currentWeightKg` is her START weight, copied at enrollment. It is
a reasonable last resort and a terrible second opinion: start and
current are different facts, and a plan hydrated from an older era of
the account describes a body she may not have any more. That is the
137 kcal between the two columns of §1's table, and it also moved her
**protein floor** (computed from 75 kg, not 56 — `90 g` on screen where
`70 g` is the truth).

It is one function now — `TargetsService.resolvedWeightKg` — so there
cannot be two of it.

---

## 4 · SIGNING BACK IN MOVED HER TARGET BY 255 kcal

The 2026-08-13 restore fix put height, the two weights and the BMR sex
back. It did not fix the input with the **largest** effect on the
number, because nobody had measured which input that was.

`profileInputs` resolves activity as `onb_v4_movement_baseline ??
activityLevel`. The raw key is swept on sign-out (correctly — identity-
scoped body data) and `UserRecord` has no column for it, so only the
alias survives. `OV5Store.assembleData` writes that alias, and it was
lossy in two of four cases:

| her answer | factor | alias stored | factor after sign-in | drift |
|---|---|---|---|---|
| barely, honestly | 1.2 | `sedentary` | 1.2 | — |
| **walks here and there** | **1.375** | `moderate` | **1.55** | **+215 kcal** |
| regular-ish | 1.55 | `moderate` | 1.55 | — |
| **very active** | **1.725** | `athlete` | **1.375** | **−431 kcal** |

`"athlete"` **is not in `activityFactor`'s table at all** — a value this
app writes itself, falling through to the default. And `walks`
collapsing into `moderate` moves the target **upward**, toward a
surplus, which is the exact complaint.

Two changes, both provably inert elsewhere:

1. `activityFactor` maps `"athlete"` → 1.725. It is a mapping, not a
   default.
2. `assembleData` emits `"walks"` for `walks`. Verified identical for
   every other reader of that field — `WorkoutGenerator.startingTier`
   (unrecognised scores the same as `moderate`), `HardTierGate` via
   `mappedActivity` (both unlock), and the goal-date nudge (both fall to
   the default). Pinned by three tests.

**THE ROUND-TRIP LAW**, pinned for all four answers: `activityFactor(raw
answer) == activityFactor(alias written at completion)`. It is the only
guarantee that signing out cannot move her energy target.

**Filmed:** Home `1,690 → 1,317` kcal for the restored persona.

### The residue, measured and named

1,317, not 1,282. The remaining 35 kcal is **the age band**:
`onb_v5_age_years` (34) is swept by the `onb_v5_` prefix and
`UserRecord` carries only `onboarding_age_range`, so 34 comes back as
the band "25to34" and `representativeAge` returns 29. −5 years = +25
kcal of BMR.

There is no lossless fix without a `UserRecord` column, which is a
migration, which is a founder gate. **Refused, quantified, recorded:
≤5 years, ≤35 kcal on a number the UI labels an estimate — against
215–431 kcal for the activity defect it sat behind.**

---

## 5 · A SAFETY GATE THAT HAD NEVER FIRED

`ProgramSetupSubflow` — the screen that builds every user's plan —
declared:

```swift
@AppStorage("onboardingActivityLevel") private var activityLevel = ""
```

**`onboardingActivityLevel` has zero writers in the app.** It appears in
`clearOnboardingUserDefaults`'s sweep list, which is exactly what made
it look written. `handleOnboardingComplete` writes `activityLevel`; the
restore writes `activityLevel`; the consult writes
`onb_v4_movement_baseline`. Nobody has ever written this one.

So `mappedActivity` always returned `.light`, and the activity dimension
of `HardTierGate` — a documented safety gate with its own written lock
copy (*"week 1 of Hard is meant for someone already moving most days"*)
— had never once fired. **The fastest pace tier was offered to a
"barely, honestly" user on every device.**

It reads `TargetsService.activityKey()` now, and the mapping covers the
raw vocabulary the live consult actually stores. **This changes what a
sedentary user is offered**, which is the gate doing the job it was
written for.

---

## 6 · A 143 lb BODY, PERSISTED

`ProgramSetupSubflow` also declared:

```swift
@AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 65
```

65 kg = 143 lb. `commit()` wrote it into the plan record as her **start
weight**, where it becomes the numerator of the plan's implied rate and
the anchor of every "since you started" sentence. It is the same class
as the 60 kg goal the last pass removed **two properties down in the
same file**.

Default `0` now, and `commit()` **refuses** rather than inventing: it
resolves the weight through the same ladder as everything else, and with
no weight anywhere it opens the repair door instead of writing a plan.
An unbuilt plan is recoverable; a plan built on a stranger's weight is
not.

Two more views still declare `= 65` and both are **unreachable**:
`SafetyCheckInView` (one call site, `DebugPreviewRoutes`, DEBUG only —
dead code carrying a fabricated body into a clinical screen, and worth
deleting in a cleanup pass) and `OnboardingRevealView`, whose weight is
written live by the consult one beat earlier. Named, not fixed: neither
can escape into product truth, and the reveal is pre-purchase funnel.

---

## 7 · THE COACH WAS THE LAST SURFACE STILL BELIEVING THE PLAN

`CoachContextAssembler` read `snapshot.plan?.goalWeightKg`
unconditionally. So in the disagreement state the plan screen said 110
lb and **jeni said 143.3 lb** — the provenance lie surviving one surface
further out, which is the same shape `27_THE_PORTION_AND_THE_SOURCE`
was written about.

The envelope resolves through `PlanSummary` now — the same object the
screens are made of. And three of the eleven questions the audit brief
lists were unanswerable for want of one word each, so they ride too:

- `to_go_kg`, `weeks_at_her_pace` — *"how much do I have left"*, *"when
  should I reach my goal"*
- `kcal_basis: deficit | maintenance` — *"am I in maintenance"*, *"why
  is that my target"*. A maintenance estimate and a loss target are the
  same glyph and opposite instructions.
- `goal_on_file: false` + a note telling her the editor's location,
  instead of improvising a number
- `kcal_missing: weight | height | goal` when there is no target

**Zero Edge Function deploy.** The allowlist gates tool NAMES, not
payloads (established in `27`, §"Jeni now reads…").

---

## 8 · THE EMPTY DENOMINATOR IS A DOOR

`29` §10 named this and left it: *"an existing user already in the
broken state loses her Home kcal denominator and is not pointed at the
repair."* §2's fix makes that state REACHABLE, so it had to be closed in
the same pass.

`TargetsService.missingEnergyInput` is the honest inverse of
`calorieTarget`'s refusals — it says WHICH fact is absent, and returns
nil for maintenance, because a maintenance number is a real number and
not an absence. Home's reference becomes `kcal · add a goal weight`,
underlined, opening on that exact fact.

And the no-weight face of Home, `caloriesLead`, carried **two branches
that cannot execute**: it is reached only when the protein floor is
absent, which happens only when no weight is known, which is the same
condition that makes `targets.kcal` nil. So the remaining-kcal line and
the words *"weigh in to set a protein floor"* had never rendered — an
empty ring, a bare "kcal", and no way out. Unreachable copy that
promises the repair is worse than no copy: it makes the file read as if
the state were handled.

---

## 9 · REPAIRABILITY — `JKPlanNumbersSheet`

`GoalWeightStore` (2026-08-13) gave the goal weight a repair path.
Height and activity still had none, and they are not decorative:

- **height** is a hard input. `calorieTarget` returns nil below 100 cm,
  so an absent height does not skew her number, it DELETES it.
- **activity** spans factors 1.2 to 1.725, which for this persona
  (BMR 1,232) is **647 kcal** end to end — larger than any deficit the
  app would ever choose.

One sheet, four rows, each stating what we hold, with "not set" as the
honest empty. Editing happens in place (a page swap, never a sheet
inside a sheet). Reachable from Settings → **your numbers** and from
Home's denominator door, which lands on the missing fact directly —
"one tap into the exact missing fact", not a settings hunt.

`BodyFactsStore` is the one writer. It never touches her weights, never
restarts her program (a height change re-runs the goal through
`GoalWeightStore`, which mutates the plan in place — so a corrected
height cannot leave a goal under BMI 18.5 for the new height), and
writes **both** activity vocabularies, because writing one and not the
other is how §4 started.

**The ambiguous row.** A legacy account's only surviving activity value
may be `moderate`, which meant EITHER "walks here and there" OR
"regular-ish". That is genuinely unrecoverable, so the row states what
the math is using and names the other answer it could have been. **The
product asks; it does not guess.**

**The height unit joins the weight unit.** `onb_v5_unit_ftin` is swept
by the `onb_v5_` prefix and never restored, so a metric user's height
unit did not survive a sign-in either — the same defect the last pass
fixed for `weightUnit`, one unit over. Mirrored to a device-level
`heightUnit`.

**Numeric suppression.** The Settings goal row stated a weight numeral
and opened a ruler full of them for a cohort the safety gate has
instructed us to show none to. `PlanSummary` already refused to ask a
suppressed cohort for a goal weight; the row now agrees with it.

---

## 10 · UNITS

lb ↔ kg round-trips are exact across the range (pinned since
2026-08-13), and there is exactly ONE conversion constant in the
codebase (`2.20462`, `WeightUnit`) — no drift.

**But the onboarding acknowledgements hard-coded `lb`.** A user who
typed KILOGRAMS on the ruler was told *"13 lb. at a safe pace, that's
about 20 weeks"* one line after entering 56 → 50, and her file summary
and her close said pounds too. Three sites, one `store.deltaWords`.
The projection FIGURE keeps its own pound scale; the sentence speaks her
unit.

---

## 11 · PROOF

- **1103/1103 app** (was 1076; +27) · **192/192 package** · Release
  configuration compiles.
- Protected paths verified **empty** against `1710180`: Payment,
  Paywall, Auth, `Packages/PlankSync`, `supabase/`, `AppPhase.swift`,
  `Info.plist`, `plankAI.entitlements`, `JenifitWidgets/Info.plist`.
  The only `pbxproj` change is three new file references.
- **The backward-compatibility pin:** a user whose plan agrees with her
  stored goal gets the byte-identical number she got before — asserted
  against the Mifflin-St Jeor arithmetic inlined in the test, and pinned
  at the persona's measured **1,282**. The only users whose number moves
  are the ones who were being shown a wrong one.

**A CORRECTION TO THE RECORD.** `29` §10 says *"PlankFood's 187 package
tests could not be executed — the `PlankFood` scheme in this checkout
has no test action configured."* **Both halves are wrong.** The scheme
has a test action. `swift test` fails because the package imports
`UIKit` and SwiftPM builds for macOS by default — a platform mismatch,
not a missing configuration. From the package directory:

```
xcodebuild test -scheme PlankFood \
  -destination 'platform=iOS Simulator,id=<udid>'
```

**192/192, TEST SUCCEEDED.** They were runnable in both previous
sessions. An argument was recorded where a run was available.

**AND A FIXTURE THAT LIED — MINE.** The three write-path tests each did
`let store = OV5Store()`. `OV5Store` is `@Observable`, and the iOS 26.2
simulator aborts on an isolated class deinit — a family
`OV5Flow.swift:170` names by name and `V8ScriptTests` already dodges
with a static store. So the process died partway and the suite printed:

```
Executed 984 tests, with 0 failures (0 unexpected)
** TEST FAILED **
```

**119 tests never ran, and the line I was reading said zero failures.**
I first blamed two concurrent `xcodebuild` runs; that was wrong, and the
correction is the point: `Executed N with 0 failures` is not a pass
signal on its own — N and the final verdict have to be read together. A
fixture that crashes the runner while printing a green count is worse
than a failing one. One shared store now, with the reason in the file.

New DEBUG doors: `--uitest-persona-restored` (adversarial: the state a
sign-out → sign-in actually leaves) · `--uitest-persona-legacy-alias`
(the pre-2026-08-14 collapsed alias) · `--uitest-persona-maintain` ·
`--uitest-persona-kg` · `--debug-plan-numbers[-focus
weight|height|goal|activity]`.

---

## 12 · WHAT FRAME REVIEW CAUGHT

1. **`--uitest-persona-home` did not land on Home** — and had not, in
   the session that added it. Any account with a legacy program
   footprint derives `AppPhase.migration` first, so the door filmed the
   "jeni grew up" cover; `hasCompletedOnboarding` came from an async
   cloud hydrate, so on a slow network it filmed the CONSULT; and the
   once-ever Body Vision intro filmed itself. **A film door that cannot
   reach the surface it names is a fixture that lies about what was
   inspected.** It is deterministic in one launch now.
2. **At AX5 the new repair door truncated to `kcal · add a goal…`** —
   the word carrying the whole meaning was the one cut. The numeral
   keeps `lineLimit(1)` (the `124` → `12`/`4` law); the sentence beside
   it stacks and wraps.
3. **The repair sheet's CTA floated mid-page** over ~800pt of paper, and
   at AX5 the scrolling options ran straight into the capsule with no
   ground under it. Pinned, with a hairline, once, in one modifier.
4. **The ambiguous activity row said `regular-ish` beside "we lost the
   detail on this one"** — stating a specific answer and disowning it in
   the same breath.
5. **Checked and NOT changed:** the height editor's ~600pt of negative
   space above its ruler is identical to `JKGoalRitual`'s, which shipped
   and was founder-reviewed. It is the register for a ruler ritual — the
   instrument sits in thumb reach. Compared against the reference frame
   rather than assumed.

---

## 13 · PROGRAM SETUP MEASUREMENT — NOT NEEDED

`29` §10 named `ProgramSetupSubflow` having zero analytics as the
highest-leverage next move. **Investigated, and the answer is to add
nothing.**

**What exists.** `$screen: ProgramOnramp` (she saw it) and
`program_invite_tapped` (she entered setup). Nothing fires on commit, so
analytics alone cannot separate "committed" from "bounced".

**Why that does not matter.** The important question is not *did she see
the screen* — it is **did she leave with a coherent plan**, and that is
already answerable **deterministically, per user, from the product's own
synced record**, with no event and no contract change:

```sql
select
  count(*)                                                        as onboarded,
  count(p.id)                                                     as has_active_plan,
  count(*) filter (where p.id is null)                            as no_plan,
  count(*) filter (where coalesce(p.goal_weight_kg, 0) <= 30)     as plan_without_goal,
  count(*) filter (where p.goal_weight_kg >= p.current_weight_kg) as incoherent_plan,
  count(*) filter (where coalesce(u.onboarding_goal_weight_kg,0) <= 30) as no_stored_goal,
  count(*) filter (where coalesce(u.onboarding_height_cm,0) <= 100)     as no_height
from public.users u
left join public.program_plans p
  on p.user_id = u.id and p.phase = 'active';
```

This is **strictly better than an event** in three ways: it measures
VALIDITY rather than a screen view; it needs no instrumentation age, so
it works on the whole base today; and it can count **how many existing
users are in each broken state right now** — which no event could ever
answer retroactively. §2's defect population is countable this
afternoon.

**Founder read worth doing before the next build:** `incoherent_plan` +
`no_stored_goal` sizes exactly who §2's fix repairs.

**If a new event is ever justified**, the smallest additive contract is
ONE event at the commit chokepoint carrying whether the plan it wrote is
coherent — `program_plan_committed{has_goal, is_loss, tier}` — fired
once per plan, redefining nothing. **Proposed for a dated section of a
future contract revision, with founder sign-off. Not added.** The
contract's own §4 rule 1 forbids any era decision before n ≥ 100 payers
or 6 weeks, so an event added today could not be read before the state
query already answered the question.

---

## 14 · THE FIRST TEN MINUTES — three of the four "dead questions" are
## not questions

`29` §10: *"`onb_consent_personalize`, `onb_v5_supports`,
`onboardingEatingCadence` and `onboarding_appetite_return` have no
readers outside onboarding. Four questions that change nothing."*

Traced against `V8Script.next(after:)`, the live consult's actual chain:

| key | asked in v8? | verdict |
|---|---|---|
| `onb_consent_personalize` | **YES** — `V8SignatureMoment`, explicit opt-in, nothing pre-checked | **A consent we record and never read.** Founder call, §15. |
| `onb_v5_supports` | **NO** | Not a question. A dead FIELD; `BuildingPlanLoadingView` still reads it and always sees empty. |
| `onboardingEatingCadence` | **NO** | Same, plus it syncs to `users` as NULL for every v8 user. |
| `onboarding_appetite_return` | **NO** | Same. (Its only v8 mention is a stale `actIndex` switch listing thirteen beats that no longer exist.) |

So there is **nothing to cut from the consult** — the argument "these
four questions waste her time" was made against three questions nobody
is asked. What exists instead is three readers that silently degrade to
empty, which is cheaper and different. Dead-code cleanup, not an
onboarding change, and `BuildingPlanLoadingView` sits in the
pre-purchase reveal chain, so not in a truth pass.

The consult is **31 beats** (pinned by `V8ScriptTests`). Unchanged.

---

## 15 · WHAT I REFUSED TO BUILD, AND ONE FOUNDER CALL

- **A `UserRecord` column for the exact age** (§4's residue). It is a
  migration for ≤35 kcal on a labelled estimate. Named, quantified,
  refused.
- **`onb_consent_personalize`, resolved.** She is asked *"use my answers
  to personalize my plan"* as an explicit opt-in, and the app
  personalizes regardless. If she declines, we have recorded a consent
  and violated it. The two honest resolutions are (a) delete the row —
  it is not a choice, it is the product she just bought — or (b) gate
  something real on it, and nothing real can be gated without breaking
  the paid product. **(a) is my recommendation and it is not my call:**
  removing a line from a signed disclosure screen is a founder/legal
  decision, and this session does not touch the consent surface.
- **The Body Scan Home tile.** `29` §6 named it as the next thing to
  cut. Re-checked: it does not displace this session's repair, which
  lives inline in the food band above TOOLS. Evidence unchanged (8
  users/90d against food 82, weight 72). **Left alone** — a placement
  call with no new evidence is not a truth fix.
- A water tracker, a medication-level curve, a widget, Food Book depth,
  a migration, an analytics event, a paywall/pricing change, a streak, a
  health score, any new HealthKit type.

---

## 16 · WHAT I EXPECTED TO BE BROKEN AND WAS NOT

- **The energy formula.** Mifflin-St Jeor, one activity factor applied
  once, no exercise compensation, no HealthKit addition, no medication
  term. Recomputed by hand for the persona: BMR 1231.6 → TDEE 1693 →
  deficit 411 → **1,282**, matching the screen exactly.
- **The unit conversion.** One constant, one type, exact round trips.
- **`GoalWeightStore`.** It does what its header says: mutates the plan
  in place, never touches the start weight, clamps to BMI 18.5 and
  reports the clamp, records the direction explicitly. A goal edit
  touches no medication record, no dose event, no food history.
- **`WeightJourney`.** Reads her stored goal, guards `g < startKg`,
  refuses to speak below `trendEstablished`.
- **`ProgramGoalCalculator`** with a zero goal: it returns the
  maintenance window rather than "lose your entire body mass".
- **The safety gate's zero-cap sentinel.** `safety_pace_cap` defaults to
  `-1`, so the zero-deficit branch cannot fire by accident.
- **Medication does not touch the calorie arithmetic**, except where the
  product intends and documents it: the GLP-1 cohort gets a 0.3%/wk pace
  floor (`ProgramGoalCalculator`, cited) and 1.6 g/kg protein (the
  4-society advisory band). `calorieTarget` has no medication term.
- **B2B authority.** There is no clinician-authored goal weight anywhere
  in the product — `CareProtocol` carries thresholds and caps, not
  destinations — so the consumer editors cannot override a clinician.
  `CareProtocol`'s protein band and pace ceiling still clamp everything
  the new writers produce. `program_facts`, `MethodNote.authority` and
  `CareProtocol` are untouched.

---

## 17 · STILL BELOW THE BAR

- **The age band's 35 kcal** (§4). The only lossless fix is a schema
  change.
- **`onboardingActivityLevel`** is still in the sign-out sweep list with
  zero writers. Harmless now that nothing reads it, and the sweep list
  is the wrong place to learn what is written.
- **A goal she has already reached still produces a deficit target.**
  `energyBasis` keeps the plan's rate when the plan agrees with her
  answer, whether or not she has arrived. Arguably it should become
  maintenance; changing it moves the number for legitimate users, so it
  is named rather than done.
- **Three dead readers** (§14) and **`SafetyCheckInView`** (§6) — one
  cleanup pass, funnel-adjacent, deliberately not now.
- **The Body Scan Home tile** (§15).
- **Nothing here can be falsified against a payer.** The measurement
  contract's first clean read still gates every product decision — and
  §13's state query does not need it.

**SAFE FOR NEXT BUILD: YES.**
