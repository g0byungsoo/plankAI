# THE SAFETY ANSWER MUST SURVIVE THE ACCOUNT

**Status: BUILT 2026-08-14.** Not a feature pass, not a design pass, not
a cleanup pass. One correctness question, taken from the production
reconciliation that closed the previous session:

> **A user can answer something that makes Jeni refuse to put her in a
> calorie deficit, sign out and back in, and the meaning of that answer
> disappears.**

It is true. It is release-blocking on the next build and not on the one
customers are running, because the fix that repaired Autym (`29` §4
rule 3 — *"fall back to her own onboarding numbers"*) is what converts
this population's accidental TDEE into a real deficit. **The change that
made the branch reachable owns the branch.**

The invariant this session encodes:

> **AN ACCOUNT TRANSITION MAY FORGET THE DEVICE.
> IT MAY NEVER FORGET A SAFETY DECISION.**
>
> Any user answer that changes what Jeni prescribes, suppresses,
> calculates or allows must either survive account restore losslessly,
> or the app must ask again before using the missing fact.

No migration. No Edge Function deploy. No production SQL executed. No
production row read or written. **12 files, zero of them under
`Packages/`, zero protected paths moved.**

---

## 1 · THE SAFETY STATE MACHINE, RECONSTRUCTED

### 1.1 Where the decision is made

`SafetyGatePresentation` (`OnboardingRevealView.swift:375`) is a **live
beat of the v8 consult** — `s_safetyGate`, immediately after the
medication beat (`V8Beats.swift:108`), mounted by
`V8SafetyGateMoment`. Every user who finishes the consult passes through
it. It runs the pregnancy screen and the SCOFF eating-pattern screen,
calls the pure `ProgramGoalCalculator.safetyAssessment`, and writes its
verdict to five `@AppStorage` keys in `route()`:

| reason | mode | `safety_pace_cap` | `safety_numeric_suppression` | `program_mode` |
|---|---|---|---|---|
| `under18` | blocked | **0.0025** | false | `blocked` |
| `med_hypo` (insulin / sulfonylurea) | clinicianFirst | **0.0025** | false | `clinicianFirst` |
| `ed_screen` (SCOFF ≥ 2) | recovery | **0** | **true** | `recovery` |
| `pregnant` | maintenance | **0** | **true** | `maintenance` |
| `breastfeeding` · `ttc` | maintenance | **0.0025** | false | `maintenance` |
| `bmi_low` (BMI < 18.5) | maintenance | **0** | false | `maintenance` |
| `bmi_healthy` · `ok` | loss | **−1** (sentinel) | false | `loss` |

A **zero** cap does not clamp a rate — it collapses the plan.
`ProgramSetupSubflow.safetyAdjustedGoalWeightKg` is
`safetyPaceCap == 0 ? startWeightKg : safeGoalWeightKg`, so the built
plan carries `goal == start`. **That row is the only shadow the decision
casts on the server**, and it is ambiguous with the 2026-08-13
fabrication (`29` §2①). A **positive** cap leaves a real loss goal and
stretches the window instead, so the plan's own geometry carries the
clamp.

### 1.2 The table

For each fact: where it is asked, where it is written, its local and
server representations, whether the sign-out sweep takes it, whether
anything puts it back, whether it can be losslessly derived, who reads
it, and what happens when it is gone.

**BEFORE THIS SESSION.** `→` marks what this session changed.

| FACT | ASKED WHERE | WRITTEN WHERE | LOCAL | SERVER | SWEPT? | RESTORED? | DERIVABLE LOSSLESSLY? | READERS | IF MISSING | VERDICT |
|---|---|---|---|---|---|---|---|---|---|---|
| `safety_pace_cap` | consult · safety gate | `SafetyGatePresentation.route` | `@AppStorage` Double | **none** | **YES** (`safety_` prefix) | **NO** | **partly** — `under18` from the age band, `bmi_low` from height + weight; `pregnant`/`ed_screen`/`med_hypo` **never** | `TargetsService.energyBasis` · `GoalWeightStore.repairActivePlan` · `.setPaceTier` · `ProgramSetupSubflow` | zero deficit becomes a **deficit**; every recomputation loses its clamp | **UNSAFE** → §5 |
| `safety_numeric_suppression` | consult · safety gate | same | `@AppStorage` Bool | **none** | **YES** | **NO** | **NO** — true for `ed_screen` + `pregnant` only, and `bmi_low` shares their plan shape | `CohortStore.isNumericSuppressed` → `TargetsService.current` · `PlanSummary` · `PlateAnswerEngine` · `EveningCloseEngine` · `InsightEngine` · `WeeklyReview` · `QuietHours` · `MethodInputBuilder` · chat (15 sites) | every numeral returns | **UNSAFE — NOT FIXED.** Contained, named, §5.4 |
| `program_mode` | consult (every branch) | `route` · `OV5Flow.applyGoalDirection` · `GoalWeightStore` | `@AppStorage` String | `users.program_mode` **exists, zero writers** | **YES** (by name) | **NO** | **NO** | `CohortStore.isMaintenanceMode` → `energyBasis` rule 1 · coach envelope | a hold becomes a loss | **UNSAFE** → §5.3 |
| `onboarding_goal_direction` | consult · goal direction beat | `OV5Flow` · `GoalWeightStore` | `@AppStorage` String | `users.goal_direction` **exists, zero writers** | **YES** (by name) | **NO** | **NO** | same | same | **UNSAFE** → §5.3 |
| `safety_pregnancy_status` | consult · `SafetyPregnancyView` | `handlePregnancy` | `@AppStorage` String | **none** | **YES** | **NO** | **NO, and must never be inferred** | the gate only | the gate's input is gone; **never re-derived** | **UNSAFE by design; refuse, never guess** |
| `safety_scoff_yes` / `_core` | consult · `SCOFFScreenView` | `handleScoff` | `@AppStorage` Int | **none** | **YES** | **NO** | **NO, and must never be inferred** | the gate only | same | same |
| `safety_screen_completed` | consult | `route` | `@AppStorage` Bool | **none** | **YES** | **NO** | no | `PaywallView` · `OV5Flow` step count · `SafetyCheckInView` | a legacy re-prompt gate; `SafetyCheckInView` has **zero production call sites** | inert |
| `onboarding_medication_status` (insulin) | consult · medication beat | `OV5Store` | `@AppStorage` String | `users.medication_status` **exists, zero writers** | **YES** | **NO** | **NO** | the gate · `CohortStore.medicationStatusKey` | `med_hypo` cannot be re-derived | **UNSAFE — contained by §5.3, not restored** |
| `onboarding_glp1_status` | consult | `OV5Store` | `@AppStorage` String | **`users.onboarding_glp1_status` — written and hydrated since 2026-06-23** | **YES** | **NO** → **YES** | **YES** | protein floor 1.6 g/kg · `ProgramGoalCalculator` 0.3%/wk floor · `HardTierGate` · cohort · notifications · wall | protein floor drops to 1.2 g/kg; the gentlest glide speeds from 0.3 to 0.5%/wk | **WAS UNSAFE → FIXED §5.2** |
| `onboarding_glp1_phase` | consult | `OV5Store` | String | **`users.onboarding_glp1_phase`** | YES | NO → **YES** | YES | early-titration pace floor | same class | **WAS UNSAFE → FIXED** |
| `onboardingHormonalStage` | consult | `OV5Store` | String | **`users.onboarding_hormonal_stage`** | YES | NO → **YES** | YES | `isPerimenopausal` → 0.3%/wk floor · `HardTierGate` · `isPostpartum` | the peri pace floor and Hard lock lift | **WAS UNSAFE → FIXED** |
| `onboardingSleepHours` | consult | `OV5Store` | String | **`users.onboarding_sleep_hours`** | YES | NO → **YES** | YES | `isShortSleeper` → 0.4%/wk floor | the sleep floor lifts | **WAS UNSAFE → FIXED** |
| `onboarding_weight_trend` | consult | `OV5Store` | String | **`users.onboarding_weight_trend`** | YES | NO → **YES** | YES | `isRegainRisk` → 0.4%/wk floor | the regain floor lifts | **WAS UNSAFE → FIXED** |
| `onboardingStressLevel` | consult | `OV5Store` | String | **`users.onboarding_stress_level`** | YES | NO → **YES** | YES | cohort texture · method | texture only | **WAS DEGRADED → FIXED** |
| `onboardingFoodRelationship` | consult | `OV5Store` | String | **`users.onboarding_food_relationship`** | YES | NO → **YES** | YES | `CohortStore.isRestrictiveRisk` → `QuietHours` gate | a restriction-risk gate silently opens | **WAS UNSAFE → FIXED** |
| `onboardingAgeRange` / `ageRange` | consult | `OV5Store` / restore | String | **`users.onboarding_age_range`** | YES | **YES** (as `ageRange`) | YES | BMR · `HardTierGate` · **`under18` gate** | — | SAFE |
| `onb_v5_age_years` (exact) | consult | `OV5Store` | Int | **none** | YES (`onb_v5_` prefix) | NO | band only, ±5 yr (±14 at `55plus`) | BMR | ≤ 35 kcal, **stated on screen as `about N · approximate`** | KNOWN, DISCLOSED (`31` §5) |
| height · current weight · goal weight · sex | consult | `OV5Store` | Double/String | `users.onboarding_*` | YES | **YES** (`restoreBodyDefaults`, `29` §9 + `31` §1) | YES | everything | — | SAFE |
| `CareProtocol` (clinician pace ceiling + protein band) | clinician | server row | **none — resolved per hydrate** | `care_protocols` + assignment | n/a | **YES, every hydrate** (`CareProtocolStore.hydrate`) | n/a | `clampRate` ceiling · protein band | falls to the bundled default, which is the safer of the two | SAFE |
| `plan.goalWeightKg == plan.currentWeightKg` | derived at build | `ProgramSetupSubflow.commit` | `ProgramPlanRecord` | **`program_plans`** | no (SwiftData survives) | **YES** (merge, `31`) | — | `energyBasis` rule 2 | — | SAFE, **but ambiguous** — §6 |

### 1.3 One key or a class?

**A class, and the `safety_` prefix does not contain it.** Six of the
seventeen rows above are cohort keys with no `safety_` prefix, whose loss
moves a *pace floor* or a *protein floor* — the same kind of harm, one
vocabulary over. The prefix was never the boundary; **"does this answer
change what Jeni prescribes"** is.

The one-line summary of the whole table:

> **The server carries every fact the arithmetic needs and none of the
> facts the SAFETY GATE produced.** Seven of the cohort inputs were on
> `users` all along and the client simply never read them back. The
> gate's five outputs have no column at all.

---

## 2 · THE FAILURE, PROVEN RED

`plankAITests/SafetyRestoreTests.swift`, 21 tests. The sweep is
`AppSync.shared.clearOnboardingUserDefaults()` itself — **not a list of
keys copied into a fixture**, which is how a sweep test stops testing the
sweep. The restore is what `hydrateUser` →
`syncUserDefaultsFromUserRecord` performs.

**With the three new cores stubbed to their pre-session behaviour:**

```
Executed 21 tests, with 17 failures (0 unexpected)
** TEST FAILED **     exit 65
```

The reachable path, exactly, for the pregnancy persona (5'3" · 124 lb ·
stored goal 110 lb · gate: `pregnant`):

| | before | after sign-out → sign-in |
|---|---|---|
| `program_mode` | `maintenance` | **absent** |
| `safety_pace_cap` | `0` | **absent** (a missing key reads `0.0`; the guard is `> 0`, so the clamp is nil) |
| `safety_numeric_suppression` | `true` | **false** |
| `energyBasis` | `.maintenance` | **`.deficit(0.00664/wk)`** |
| `TargetsService.current().kcal` | **nil** (suppressed) | **1,317 kcal** |

Every rung of the resolution order fails open: rule 1 has nothing left to
read, rule 2 cannot fire on a `goal == start` plan, arrival needs her to
have reached a goal she has not reached — and rule 3, added on
2026-08-13, re-derives a rate from **the loss goal she gave the consult
BEFORE the gate ran** and publishes a deficit.

**Per persona, RED:**

| persona | reachable? | before | after (pre-fix) |
|---|---|---|---|
| A · ordinary loss | yes | 1,282 kcal deficit | 1,317 kcal deficit — **correct, the documented age drift** |
| B · intentional maintenance | yes | `.maintenance` | **`.deficit`** — `program_mode` is swept |
| C · pregnancy hold | yes, live beat | `.maintenance`, no numerals | **`.deficit`, numerals back** |
| D · eating-pattern hold | yes, live beat | `.maintenance`, no numerals | **`.deficit`, numerals back** |
| E · BMI < 18.5 | yes, live beat | `.maintenance` | **`.deficit`** |
| F · GLP-1 pace cap | yes | protein 90 g · 0.3%/wk floor | **protein 70 g · 0.5%/wk floor** |
| G · clinician protocol | yes | ceiling + band from the server | **unchanged — resolved per hydrate** |

Persona G is the only one that was already right, and it is right for the
reason the whole session turns on: **it was never stored on the device as
a durable fact.**

---

## 3 · "STOP SWEEPING `safety_`" — TESTED AND REJECTED

The previous session's proposal was to stop sweeping the `safety_` family
when sign-in returns to the same user id. **It is not sufficient and it
is not safe, for three independent reasons.**

1. **It cannot reach the commonest transition.** A new phone and a
   reinstall never had the keys to keep.
   `testAFreshDeviceRestoresTheSameSafeProgram` fails under it by
   construction.
2. **The sweep runs at SIGN-OUT, before the next identity is known.**
   `clearLocalUserStateForSignOut` is called by `AccountView` *before*
   `AuthService.signOut`. Deferring it to sign-in leaves a screened
   user's pregnancy answer and SCOFF count sitting in
   `UserDefaults.standard` on a shared device for as long as nobody signs
   in — and delete-account calls the same sweep.
3. **It buys nothing the fix does not.** The facts it would preserve are
   the ones this session either restores from the server or refuses to
   act on.

**Cross-account isolation is unchanged and pinned.**
`testAccountBInheritsNoneOfAccountAsSafetyState` seeds account A as
pregnant + GLP-1-current, runs the real sweep, hydrates B's own record,
and asserts B inherits no pace cap, no suppression, no pregnancy status,
no SCOFF count, no program mode, no goal direction, no GLP-1 status and
no maintenance mode — and holds B's own body facts. It passes **before
and after** this session's change, which is the point: the repair is
built on top of the sweep, never instead of it.

**The two requirements coexist because the fix never stores a safety fact
on the device across an identity boundary.** It restores only what the
signed-in account's own server row carries, and where the server carries
nothing it refuses to act.

---

## 4 · THE SERVER CONTRACT

Every program-critical fact, classified.

**A · DEVICE PREFERENCE** — safe to stay local.
`weightUnit`, `heightUnit` (device-level on purpose, `31` §18 G).

**B · ACCOUNT FACT** — must survive another device.
height · current weight · start weight · goal weight · sex · age band ·
activity alias · pace tier · plan identity and geometry · every history
family. **All present and restored.** The one degradation is the exact
age → its band, ±5 years, ≤ 35 kcal, disclosed on screen.

**C · SAFETY FACT** — must survive OR be re-asked before the app
proceeds.
`safety_pace_cap` · `safety_numeric_suppression` ·
`safety_pregnancy_status` · SCOFF counts · `onboarding_medication_status`
· `program_mode` · `onboarding_goal_direction`. **None survives.** This
session makes the app refuse and ask rather than proceed (§5.3), restores
the two derivable caps from facts that do survive (§5.1), and names
suppression as the one that still needs persistence (§5.4).

**D · DERIVED FACT** — never persisted as a competing truth.
the calorie target · the protein floor · the remainder · `to_go_kg` ·
`weeks_at_her_pace`. All computed; `plan.totalDays` / `goalDate` are the
one derived pair that IS stored, with a single writer, by design.

**E · CLINICIAN FACT** — consumer UI must not silently override.
`CareProtocol` (pace ceiling, protein band) · `program_facts` authority
chain · `MethodNote.authority` · `regimen_plans` version chains.
**Unchanged, and structurally safe:** `CareProtocolStore.hydrate` re-reads
the assignment and the served row on every hydrate, so a clinician's
constraint is never a device fact that can be lost. There is still **no
clinician-authored goal weight anywhere in the product** (`30` §16), so
no consumer editor can override one.

### The question, answered

> **If this user destroys her phone today and signs into a brand-new
> iPhone tomorrow, can Jeni reconstruct every fact required to give the
> same safe program?**

**NO — and after this session the list of what cannot survive is exactly
four items, all in class C:**

1. `safety_numeric_suppression` — no column, not derivable, never
   inferred. **The calorie numeral is withheld anyway** (§5.3 refuses the
   basis), but weight numerals return.
2. `safety_pregnancy_status` and the SCOFF counts — the gate's *inputs*.
   Not needed once the *output* is handled, and never re-derived.
3. `onboarding_medication_status` — so a `med_hypo` 0.25%/wk cap cannot
   be re-derived. Her plan's own geometry still carries the clamp; a
   later goal or pace edit would not.
4. The exact age — ±5 years, disclosed, one tap to correct.

Everything else is exact.

---

## 5 · THE MINIMUM SAFE FIX

Chosen in the founder's preference order. **No schema change, no
migration, no DTO field, no transport change.**

### 5.1 Rung 1 — restore what the server already holds

**`AppSync.restoreCohortDefaults(from:into:)`**, a sibling of
`restoreBodyDefaults` under the same clean-record guard, mirroring the
seven cohort/clinical strings `UserRecord` has carried and synced since
2026-06-23: GLP-1 status and phase, hormonal stage, sleep hours, weight
trend, stress level, food relationship. Called from
`syncUserDefaultsFromUserRecord` and from `refreshProgramTruth`.

Two refusals, identical to `restoreBodyDefaults`': a record with an
unsent local edit is never mirrored; an absent server value never deletes
a local fact. Both pinned.

**`TargetsService.resolvedSafetyCap(currentWeightKg:_:)`** — the gate's
own output when the device holds it, else the derivable half of the
gate's own arithmetic:

* `under18` → 0.0025, from the age band, which survives;
* `bmi_low` → 0, from height and the freshest weight, which both survive.

`pregnant`, `ed_screen` and `med_hypo` are **never** derived — no proxy,
no heuristic. Pinned by
`testPregnancyAndTheEatingScreenAreNeverInferred`.

It can only ever ADD protection: it is consulted **solely** when the
stored answer is absent
(`testTheDerivedCapIsNeverConsultedWhileTheStoredAnswerIsOnFile`), so a
device that still holds the gate's verdict behaves exactly as it did
yesterday. `GoalWeightStore` resolves through the same function, so a
goal or pace edit after a sign-in can no longer recompute an under-18's
window with no cap.

**One honest difference, stated:** the derived `bmi_low` cap follows her
CURRENT weight, so it lifts if she climbs back above BMI 18.5. That is
the gate's own rule applied to the body in front of us, and it is the
conservative direction of the two.

### 5.2 Rung 1 — what that restores

GLP-1 protein floor 1.6 g/kg · the 0.3%/wk cautious pace floor for GLP-1
and perimenopause · the 0.4%/wk short-sleep and regain floors ·
`HardTierGate`'s cohort locks · `QuietHours`' restriction-risk gate.
Zero schema.

### 5.3 Rung 3 — unknown is never permission

**THE DIRECTION RULE** (`TargetsService.planHoldsWithUnknownDirection`):

> When a live plan's goal is not below its start weight, **and** her
> profile is loss-shaped (a stored goal below her stored start weight),
> **and** neither `program_mode` nor `onboarding_goal_direction` is on
> file — the app does not know whether the hold is an instruction or an
> accident. It publishes **no deficit and no maintenance number**;
> `missingEnergyInput` is the new `.direction`; the repair states what
> the plan says and asks which it is.

Why this predicate and no other:

* **`program_mode` is written on every branch of the consult** — all five
  gate modes, the goal-direction beat, and every `GoalWeightStore` edit.
  It is swept by name and nothing restores it. **Its absence is a precise
  signal that this device has been through an account transition.** A
  woman still holding her own answer never reaches this branch, so
  nothing about an ordinary customer moves.
* **The loss-shaped-profile clause** keeps the ask off the population
  whose real missing fact is the goal. `AutymRecoveryTests` objected to
  the first, broader version of this rule and was right: her stored goal
  had been fabricated to equal her weight, so *"add a goal weight"* is
  the honest ask, not *"losing or holding?"*. **The tightened predicate
  is byte-identical to census row 13** ("maintenance-SHAPED plan for a
  loss-shaped profile"), so the production count and the client rule are
  the same rule.

`.unknown` rather than `.maintenance`, because the product's own law is
*no fact, no number* — and asserting "you are holding" is a claim we
cannot make either.

### 5.4 What is NOT fixed, and why

**`safety_numeric_suppression` cannot survive and must not be guessed.**
It is true for `ed_screen` and `pregnant` and false for `bmi_low`, and
all three produce the identical `goal == start` plan row. Suppressing
numerals for the wrong person would strip every number from an ordinary
payer's product. So: **the containment is that she is not handed a
calorie target either** (§5.3 refuses the basis), pinned by
`testASuppressedCohortIsNotHandedACalorieNumberAfterRestore`. Weight
numerals return. **The only lossless fix is persistence, and it is a
migration** — §5.5.

### 5.5 The migration this session did NOT write, and the ordering

`public.users` **already has** `program_mode`, `goal_direction` and
`medication_status` — added 2026-07-03 in a migration whose own header
says *"cohort columns that gate behavior must survive devices"* — and
**the client has never written or read one of them.** The upsert DTO
(`SupabaseUserUpsert`) has no such field.

That is rung 2 of the preference order and it is the right architecture.
It is **not** in this build, for one reason and it is not cost:

> The client cannot send a column it has not proven exists. If the
> 2026-07-03 migration is not applied on this project, adding those
> fields to the upsert makes PostgREST reject **the whole `users` row
> with a 400**, and profile sync breaks for every user on the app. This
> is `31` §21's ordering hazard exactly.

**Recommended sequence, for the founder:**

1. Verify, read-only:
   `select column_name from information_schema.columns where table_schema='public' and table_name='users' and column_name in ('program_mode','goal_direction','medication_status');`
   (Expect three rows if 2026-07-03 is applied.)
2. If three rows: the client change is **additive with no migration** —
   add the three to the upsert and the row decoder, mirror them in
   `restoreCohortDefaults`. That makes the direction and the `med_hypo`
   cap lossless and removes most of §5.3's ask.
3. `safety_numeric_suppression` needs a genuinely new column and is
   therefore migration-first, client-after — the same ordering as
   `users.onboarding_age_years` and `jeni_memories`.

**Nothing is prepared here, because a client that needs an unapplied
column is a loaded gun** (`31` §21).

---

## 6 · THE 13 `goal == start` PLANS — THE EXPLICIT RULE

Not repaired. Not inferred. The rule the client follows, in full:

> **`plan.goal == plan.start` AND the profile says loss AND the safety
> state is unavailable ⇒ HOLD, AND ASK.**
>
> No deficit is published. No maintenance number is published either,
> because "you are holding" is a claim the app cannot support. The
> screen states what the plan says, names the missing answer, and offers
> exactly two choices. **The only exit is her own answer.**

Derived from the product's existing semantics, not from a preference:

* `PlanSummary`'s standing law is *holding is an instruction or an
  arrival, never a fallback* (`29`). Publishing maintenance here would
  make it a fallback.
* `31` §11's law is *no fact, no number*. The missing fact is the
  direction, so the app names the direction — not the goal she already
  gave, which is the dead end `31` §8 found and named.
* `29`'s law is *the number she sees is the number the math uses*. With
  the basis unknown there is no number, so there is nothing to disagree
  with.

**The asymmetry that settles it:** asking a fabricated-goal user costs
one tap. Guessing wrong for a pregnant user costs her a deficit. The
database cannot tell them apart; the client must not pretend it can.

If she answers "hold steady", `GoalWeightStore.setDirection` writes the
two keys and **nothing else** — not the goal, not the plan, not the start
weight, not a day of history — so it stays reversible through the goal
ritual (`testAnsweringTheDirectionTouchesNothingButTheDirection`). If she
answers "aiming to lose", rule 3 prices her own stored goal, which is
what `29` built it for.

---

## 7 · THE 21 DISAGREEMENTS

**No production mutation. `docs/app_v25/reconcile_21.sql`** classifies
them, read-only, one labelled row per account plus a compact
`classification | users` aggregate at the bottom. It is wrapped in
`BEGIN READ ONLY` / `ROLLBACK`, contains **zero write-shaped keywords in
code or comments** (verified by grep, deliberately, so the founder's own
check comes back clean), and returns account UUIDs only in the first
query — no emails, no names, no auth metadata.

It carries one new column the previous session's version could not:
`client_will_ask`, the byte-identical evaluation of §5.3's predicate, so
the founder can see which of the 21 the next build will question rather
than price.

**Recommendation unchanged: ship the build, repair nothing.** Category B
must never be written to.

---

## 8 · THE "≤ 3" QUESTION, RE-DERIVED

**`docs/app_v25/no_target_census.sql`.** Read-only, counts only, no
identifiers.

**The previous session's query is now a strict UNDER-count**, and this is
the audit the founder asked for. It was:

```
plan_goal >= plan_start - 0.05
AND (profile_goal <= 30 OR profile_weight <= profile_goal + 0.01)
```

which reproduced the decision tree of that hour. §5.3 added a rule the
predicate excludes by construction (it requires the stored goal to be
*missing*, and the new rule requires it to be *present and loss-shaped*).
Re-derived from the candidate's own resolution order rather than carried
forward.

**SQL cannot produce one number here, and the file says so on its face:**

* **SERVER-PROVABLE LOWER BOUND** — accounts with no resolvable weight or
  no height. These are decided *before* the basis is consulted, so they
  hold under every possible local state. **Exact.**
* **SERVER-PROVABLE UPPER BOUND** — the lower bound plus every account
  whose basis *could* be unknown, broken out into "hold-vs-lose" and "no
  usable goal anywhere".
* **UNKNOWN DIMENSION** — `program_mode`, `onboarding_goal_direction`,
  `safety_pace_cap` and `safety_numeric_suppression` have no column and
  are swept on sign-out. The same server row yields a real number or no
  number depending on a fact the server has never been told. A fifth
  caveat is stated so it is not mistaken for a defect: a suppressed
  cohort is shown no calorie numeral **by design**, and that is not an
  account opening to a missing number.

**Not executed.**

---

## 9 · `users.program_status` / `program_intensity_tier` /
## `program_goal_date`

**Proven.** A repo-wide grep for all three column names and their camel
forms returns **exactly two kinds of hit and no code**:

* `scripts/schema.sql:593-600` — the column definitions, whose comment
  claims *"these columns are kept in sync by ProgramService.startProgram
  + transition"*;
* `ProgramService.swift:22-23` — a doc comment making the same claim.

**Zero writers. Zero readers. In the client, in the Edge Functions, and
in the migrations.** Every account in production reads `program_status =
'inactive'`, including the 120 with a live plan. The census the founder
ran is correct *because* it joined `program_plans` and ignored these.

**RECOMMENDATION: (C) EXPLICITLY DEPRECATE NOW, (A) DELETE IN A LATER
MIGRATION.** Not implemented this session — their existence cannot affect
the app, so touching them is out of scope by the session's own rule. The
deprecation that costs nothing and removes the lie is the **comment**:
both the schema comment and `ProgramService`'s header assert a contract
that has never existed, and anyone querying production for program state
through them gets a wrong answer with no warning. Implementing them as
mirrors is refused — a second denormalised copy of plan state is the
drift `31` §10 spent a session removing.

**A second false contract found the same way, recorded not fixed:**
`public.coach_messages` (migration 2026-07-03, with RLS and grants) has
**zero client references**. The chat transcript table exists and nothing
writes to it, which is why §10's matrix lists the transcript as LOST.

---

## 10 · THE BORING ACCOUNT-TRANSFER GAUNTLET

DEVICE A, a synthetic week, both personas → DEVICE B, same account, zero
local state. `34`'s table re-measured against this session's build, plus
the safety and cohort dimensions it did not cover.

| FACT | DEVICE A | DEVICE B | | CUSTOMER EFFECT | FIX |
|---|---|---|---|---|---|
| onboarding answers (body) | height · weights · goal · sex | same | **EXACT** | — | — |
| age | exact year | the band's midpoint | **DEGRADED** | ≤ 35 kcal, screen says `about N · approximate` | later, migration |
| activity | raw answer | the 3-value alias | **DEGRADED** | 0 kcal (round-trip law, `30` §4); ambiguity stated | — |
| **GLP-1 status / phase** | current · established | **same** | **EXACT (new)** | protein floor and pace floor preserved | **done** |
| **hormonal stage · sleep · weight trend · stress · food relationship** | set | **same** | **EXACT (new)** | pace floors and the restriction gate preserved | **done** |
| **safety pace cap** | `0` / `0.0025` | **derived for `under18` + `bmi_low`; ABSENT for pregnancy · eating-pattern · insulin** | **PARTIAL** | no deficit is published either way; a `med_hypo` recompute loses its clamp | **migration** |
| **numeric suppression** | true | **false** | **MISSING** | weight numerals return; the calorie numeral does not | **migration** |
| **program mode / goal direction** | on file | **absent → the app asks** | **MISSING, HANDLED** | one plain question, two taps | **migration** |
| program plan | id · start date · geometry | same | **EXACT** | — | — |
| current / start / goal weight | on file | same | **EXACT** | — | — |
| weigh-in history | every row | same | **EXACT** | — | — |
| food history + photos + corrections + **a re-dated plate** | every row | same | **EXACT** | — | — |
| calorie target · protein target | derived | derived from the same inputs | **EXACT** (modulo age) | — | — |
| units | lb / ft-in | device-level default | **BY DESIGN** | two phones can show two units | stated |
| pace tier | plan + preference | same | **EXACT** | — | — |
| medication regimen + dose history + side effects | version chains | same | **EXACT** | — | — |
| clinician protocol / assignment | server-resolved | same | **EXACT** | — | — |
| supplement data | **no feature exists** | — | n/a | `supplementPlans` has zero call sites | delete later |
| **Jeni memory** | listed in Settings as durable | **empty** | **MISSING** | *"what jeni remembers"* starts at zero | **migration first** |
| **chat transcript** | on device | **empty** | **MISSING** | the table exists; nothing writes it | later |
| **manual move entries** | UserDefaults | **empty** | **MISSING** | a recorded session does not follow her | later |
| body scans | local, backup OFF by default | empty unless opted in | **BY DESIGN, UNSTATED** | privacy posture working; the surface should say so | later |

**Worst remaining boring failure: Jeni's memory.** It is listed in
Settings under *"what jeni remembers"* with a per-row forget, which reads
as a durable record of things she told her coach, and it is a `@Model`
with no upsert and no hydrate. Re-verified this session by grep:
zero references to `JeniMemoryRecord` anywhere in `Packages/PlankSync` or
`PlankApp/Sync`.

---

## 11 · CHAT MUST NOT OUTRUN TRUTH

The envelope resolves through `PlanSummary` — the same object the screens
are made of — so Home == Plan == Jeni is structural
(`OneTargetEverywhereTests`, 25 states × 3 surfaces).

**One defect found and fixed, and it is exactly the shape §11 warns
about.** `CoachContextAssembler` passed `snapshot.latestWeightKg` — the
raw weigh-in row — into `missingEnergyInput`, while
`TodayStateService` passes `TargetsService.resolvedWeightKg` two lines
away in its own snapshot. So for any woman who has never opened the
scale, **jeni named `weight` as the missing fact while Home named the
real one.** A second truth ladder, one surface further out — the same
defect class as `30` §3. It resolves through the canonical resolver now.

Also fixed: `kcal_missing` was a ternary chain that fell through to
`"goal"` for anything it did not recognise, so `.direction` would have
had jeni tell a woman to set a goal weight she already has. It publishes
the enum's own name now, plus a `kcal_missing_note` that tells the model
in plain terms not to encourage a deficit and where the answer lives.

**Zero Edge Function deploy** — the allowlist gates tool NAMES, not
payloads (`27`).

Pinned: `testTheCoachIsNotToldToAskForAGoalWeightSheAlreadyGave` asserts
both the word and that jeni quotes no number the screens refuse to draw.

---

## 12 · ORDINARY USERS DID NOT MOVE

`testTheOrdinaryLossUserIsUntouchedByAnySafetyRepair`, on the golden
persona (5'3" · 124 lb · goal 110 lb · coherent):

| | before | after this session |
|---|---|---|
| target on the device | **1,282** | **1,282** |
| target after sign-out → sign-in | **1,317** | **1,317** |
| basis | `.deficit` | `.deficit` |
| the delta | the documented age band, 35 kcal | unchanged |

It passes **under the RED stub and under the shipped code**, which is
what makes it a control rather than a claim. The whole
`CalorieGoldenMatrixTests` fixture set (11 tests, ~23 exact integers —
maintenance 1,693 · at-goal 1,594 · GLP-1 1,282 · soft 1,389 · hard
1,232 · male 1,511 · after every edit) is green and unchanged, as are
`PlanIdentityTests` (plan id, startDate, canonical selection),
`UpgradeBoundaryTests` (12 fixtures) and `AutymRecoveryTests` (7).

**Nothing in this session changes arithmetic.** Not one constant moved.
What changed is *which inputs reach it* (seven cohort keys that were
being dropped) and *when it is allowed to publish* (never on an unknown
safety state).

---

## 13 · DESIGN AND COPY

Almost none, and no surface was redesigned.

The re-ask is a row and an editor page inside the **existing**
`JKPlanNumbersSheet`, using the **existing** `choiceEditor` composition
that sex and pace already share. It appears **only while the answer is
genuinely missing**, so the sheet stays seven rows for everyone else. No
new vocabulary, no new geometry, no new sheet.

> **this plan** · *not set*
> your plan is set to hold steady. we can't tell from this device whether
> that was your choice or a health reason we checked at sign-up — tap to
> say which.
>
> **is this plan losing, or holding?**
> your plan is set to hold steady — no calorie deficit. we can't tell
> from this device whether that was your choice or a health reason we
> checked at sign-up, and we won't guess. if a health reason set it,
> keep holding.
>
> **hold steady** — no deficit. this is what your plan says today.
> **aiming to lose** — we'll use the goal weight on file and give you a
> daily number.

Home's empty denominator becomes `kcal · losing or holding?` instead of
`kcal · add a goal weight`; the plan screen asks through the same
`missingPrompt` composition the missing-weight case already uses.

**No screening label is exposed.** Pregnancy, SCOFF and insulin are never
named — *"a health reason we checked at sign-up"* is true and
sufficient. Nothing says "we noticed something", "your journey",
"personalized insight", "let's recalibrate" or "your body has changed".
Nothing is pre-selected, because the honest state is that we do not know.

---

## 14 · TEST DISCIPLINE

Every command run **serially**, unpiped, `$?` captured directly
(`32` §13's correction — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/SafetyRestoreTests` | 21 | **21** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` | 1228 | **1228** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.6 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

App suite is **+21** over `34` (1207 → 1228), which is exactly
`SafetyRestoreTests` and nothing else — no existing test changed.

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.**

Coverage against the founder's list: same account (hold → out → in →
same hold) · different account (A's state reaches none of B) · fresh
device (empty store → restore) · ordinary loss (same target before and
after) · maintenance (same basis) · GLP-1 (same protein floor, same pace
floor) · numeric suppression (contained, and the limitation named) ·
unknown safety state (never silently a deficit) · dirty local edit
(server does not overwrite) · clean local (server may restore). Multiple
live plans is held by `PlanIdentityTests` (9) rather than duplicated
here.

### Two fixture errors of my own, caught and corrected

The first RED run produced 9 failures and **two of them were mine, not
the product's**: the persona seeded a band-age where the golden matrix
seeds an exact year (so the anchor read 1,317 before the round trip, not
1,282), and the capped plan's day count was typed into the fixture
instead of computed, which made the under-18 clamp assertion pass
trivially. Both were fixed by building the plan through
`ProgramGoalCalculator.compute` with the same cap `ProgramSetupSubflow`
passes. **A fixture that agrees with itself is not evidence.**

### The refusal-test lesson, again

Under the RED stub, 7 of the 21 tests **passed**. Three are genuine
controls (cross-account isolation, the untouched device, the ordinary
user). The other four —
`testAnsweringTheDirectionTouchesNothingButTheDirection`,
`testPregnancyAndTheEatingScreenAreNeverInferred`,
`testADirtyRecordNeverOverwritesTheCohortOnThisDevice`,
`testAnAbsentServerCohortValueNeverDeletesALocalFact` — assert
**refusals**, and a stub that does nothing satisfies a refusal test.
This is `34`'s recorded lesson verbatim: *a refusal test cannot tell
"refused for the right reason" from "cannot do anything at all"*, which
is why the other 14 exist.

---

## 15 · RELEASE / MIGRATION PROOF

**No `@Model` changed.** All three files in the repository that declare
one (`PlankSync/Models.swift`, `Chat/ChatModels.swift`,
`Chat/JeniMemory.swift`) have a **zero diff against `1710180`** —
re-verified here, not inherited. **There is no SwiftData store migration
to fail.**

**Protected paths vs the reviewed release `1710180`:**

| path | diff |
|---|---|
| `PlankApp/Payment` | **EMPTY** |
| `PlankApp/Views/Paywall` | **EMPTY** |
| `PlankApp/Auth` | **EMPTY** |
| `PlankApp/App/AppPhase.swift` | **EMPTY** |
| `PlankApp/Info.plist` | **EMPTY** |
| `plankAI.entitlements` | **EMPTY** |
| `PlankApp/Notifications` | **EMPTY** |
| `PlankApp/Care` | **EMPTY** |
| `PlankApp/BodyScan` | **EMPTY** |
| `PlankApp/Workout` | **EMPTY** |
| `JenifitWidgets` | **EMPTY** |
| `supabase/migrations` | **EMPTY** |
| `supabase/` | +124/−3 — `27`'s food-vision EF, written and NOT deployed. **This session: EMPTY.** |
| `PlankApp/Analytics` | +6 — `31`'s allowlist lines. **This session: EMPTY.** |
| `Packages/PlankSync` | `31`'s merge + `34`'s delete. **This session: EMPTY.** |
| `Packages/PlankFood` | `34`'s `setLoggedDay`. **This session: EMPTY.** |

**This session touched 12 files and none of them is under `Packages/`** —
measured by mtime against the session start, not asserted.

**Release binary**, `Release-iphoneos/plankAI.app/plankAI`, 89.6 MB,
123,135 strings:

| string | count |
|---|---|
| `--uitest` | **0** |
| `--debug` | **0** |
| `--food-debug` | **0** |
| `persona-customer` | **0** |
| `persona-autym` | **0** |
| `debug-plan-numbers` | **0** |
| `debug-weigh-ins` | **0** |
| `debug-safety-gate` | **0** |
| `losing or holding` | **6** — the repair copy IS in the shipping binary, not behind a door |

A note on method, because it nearly went the other way: the first
`strings` pass ran against an empty path and printed **eight zeros**. A
zero from a file that does not exist is the `Executed 0 tests / TEST
SUCCEEDED` trap wearing different clothes. The binary is located, its
size and total string count are stated, and only then are the counts
read.

**`CURRENT_PROJECT_VERSION` is still 30 and was not bumped** — the
archive-time bump to **31** (build 30 is already accepted by ASC) is
unchanged and remains the founder's step.

**No deployment of any kind. No production SQL executed. No production
data read or mutated.**

---

# 16 · THE DECISION

**1 · IS THE SAFETY RESTORE DEFECT REAL? — YES.**
The pre-paywall safety gate is a live beat of the v8 consult and writes
its verdict to five `@AppStorage` keys with no column on `public.users`.
`clearOnboardingUserDefaults` sweeps the whole `safety_` family by prefix
and `program_mode` / `onboarding_goal_direction` by name — correctly,
because on a shared device user A's clinical answers must never bend user
B's program — and **nothing has ever put any of them back**, on sign-in,
on reinstall, or on a new phone. Six cohort keys that move a pace floor
or a protein floor were being dropped the same way, and those the server
had carried since 2026-06-23. Proven RED: 21 tests, 17 failures, with the
three new cores stubbed to their pre-session behaviour.

**2 · CAN IT TURN A HOLD USER INTO A DEFICIT USER? — YES.**
Exact path: consult → pregnancy answer or SCOFF ≥ 2 → gate writes
`safety_pace_cap = 0`, `program_mode = maintenance`,
`safety_numeric_suppression = true` → purchase → onramp builds a plan
with `goal == start` → sign out / reinstall / new phone → the sweep takes
all three and the hydrate restores none → `isMaintenanceRequested` is
false, `safetyRateCap` reads a missing key as `0.0` and its `> 0` guard
returns nil, rule 2 cannot fire on a `goal == start` plan, arrival needs
a goal she has not reached — and **rule 3 re-derives a rate from the loss
goal she gave the consult before the gate ran.** Filmed in test:
`.maintenance` and no numeral becomes `.deficit(0.00664/wk)` and
**1,317 kcal**.

**3 · DOES IT BLOCK THE NEXT BUILD? — YES, IT DID. IT IS FIXED, AND THE
BUILD IS NOW SAFE.**
My call, not handed back. It blocks because the next build is the first
one that makes it *worse*: production hands these users TDEE by accident
(the old `planImpliedRate` returned 0 for a hold plan), and rule 3 turns
that accident into a real deficit. Shipping a weight-loss deficit to a
pregnant or eating-pattern-screened user is not a P2. It is fixed at the
smallest honest size, with no schema change, and the population it
touches is bounded by census row 13.

**4 · WHAT WAS THE MINIMUM FIX?**
`PlankApp/Sync/AppSync.swift` (`restoreCohortDefaults` + 2 call sites) ·
`PlankApp/Program/TargetsService.swift` (`resolvedSafetyCap`,
`derivedSafetyCap`, `planHoldsWithUnknownDirection`, `directionIsUnknown`,
`MissingEnergyInput.direction`) ·
`PlankApp/Program/GoalWeightStore.swift` (`setDirection`, and the cap
resolved through `TargetsService`) ·
`PlankApp/Program/PlanSummary.swift` (`.directionUnknown`) ·
`PlankApp/Chat/CoachContextAssembler.swift` (the canonical weight ladder,
`kcal_missing`) · four view files for the ask ·
`plankAITests/SafetyRestoreTests.swift`.

> **The invariant: a safety decision either survives the account, or the
> app refuses to use the fact and asks. Unknown is never permission.**

**5 · DOES CROSS-ACCOUNT ISOLATION STILL HOLD? — YES.**
`clearOnboardingUserDefaults` is untouched; the repair is built on top of
the sweep, never instead of it. The fix restores only what the
signed-in account's own hydrated `UserRecord` carries, and refuses to act
where the server carries nothing.
`testAccountBInheritsNoneOfAccountAsSafetyState` passes under the RED
stub and under the shipped code: B inherits no pace cap, no suppression,
no pregnancy status, no SCOFF count, no program mode, no goal direction
and no GLP-1 status.

**6 · DOES SAME-ACCOUNT RESTORE NOW HOLD? — YES, in the two shapes it
can.**
Losslessly for everything the server carries: GLP-1 status and phase,
hormonal stage, sleep, weight trend, stress, food relationship, and the
`under18` and `bmi_low` pace caps re-derived from the age band and from
height + weight. By refusal-and-ask for what it does not: pregnancy, the
eating-pattern screen and insulin produce **no deficit and no number**,
and one plain question. Pinned by 21 tests, 17 of which fail without the
fix.

**7 · DOES A FRESH DEVICE RESTORE THE SAME SAFE PROGRAM? — YES for the
program, NO for four named facts.**
Remaining degradation: `safety_numeric_suppression` cannot be rebuilt
(contained — no calorie numeral is published either, but weight numerals
return) · a `med_hypo` 0.25%/wk cap cannot be re-derived (her plan's own
geometry still carries it; a later goal or pace edit would not) · the
exact age is coarse to its band, ±5 years, stated on screen · Jeni's
memory, the chat transcript and manual move entries do not follow the
account at all.

**8 · HOW MANY PRODUCTION USERS ARE PROVABLY EXPOSED?**
**Not knowable server-side, and not guessed.** The gate's output has no
column, so the exposed population is invisible by construction — which is
the defect restated.
**Upper bound: 13** (census row 4, `goal == start` live plans), and
realistically **11** (row 13, the loss-shaped subset), of which some are
the 2026-08-13 fabrication rather than a safety hold. **Lower bound: 0**,
because exposure also requires a sign-out, a reinstall or a new device,
which the server does not record. `docs/app_v25/no_target_census.sql`
returns the bounds and names the unknown dimension rather than a figure.

**9 · WHAT HAPPENS TO THE 21 DISAGREEMENTS?**
Nothing in the database: `docs/app_v25/reconcile_21.sql` classifies them
read-only for the founder, the client already produces the right screen
for 18–21 of them with no write, and category B must never be written to
because a bulk repair would put a pregnant or screened user back on a
deficit.

**10 · WHAT HAPPENS TO THE 13 `goal == start` PLANS?**
No inference and no write: where the profile is loss-shaped and the
direction is unavailable the app publishes no deficit, states that the
plan is set to hold, and asks her which it is — the only exit is her own
answer.

**11 · WORST BORING ACCOUNT-TRANSFER FAILURE STILL LEFT**
**Jeni's memory does not follow the account.** It is listed in Settings
as *"what jeni remembers"* with a per-row forget, which reads as durable,
and it is a `@Model` with no upsert and no hydrate. Migration first,
client after.

**12 · SAFE FOR NEXT BUILD: YES.**

---

## WHAT I CHANGED

1. **`AppSync.restoreCohortDefaults`** — seven clinical/cohort keys the
   server has carried since 2026-06-23 and the client never read back.
2. **`TargetsService.resolvedSafetyCap` / `derivedSafetyCap`** — the
   gate's own arithmetic, re-run from the facts that survive, and only
   when the stored answer is gone.
3. **The direction rule** — a plan that holds, with a loss-shaped
   profile and no direction on file, publishes no deficit and no
   maintenance number.
4. **`MissingEnergyInput.direction`** and its door/subline copy, so the
   app names the fact that is actually missing instead of pointing at a
   goal she already gave.
5. **`GoalWeightStore.setDirection`** — two keys, nothing else.
6. **`PlanSummary.directionUnknown`** + the plan screen's ask.
7. **`GoalWeightStore`'s cap resolves through `TargetsService`**, so a
   goal or pace edit after a sign-in cannot recompute an uncapped window.
8. **The coach's weight ladder** — `CoachContextAssembler` had its own,
   and it named the wrong missing fact for anyone who had never weighed
   in.
9. **`docs/app_v25/reconcile_21.sql`** and
   **`docs/app_v25/no_target_census.sql`** — read-only, founder-executed,
   not run.

## WHAT I REFUSED

- **To infer pregnancy, ED risk, insulin use or a clinician instruction
  from anything.** No proxy, no heuristic, no "she looks like".
- **"Stop sweeping `safety_` on a same-account sign-in."** Tested against
  the fresh-device case and the sign-out ordering, and rejected — §3.
- **To repair a single production row**, to bulk-write the 21 or the 13,
  or to run one line of SQL against production.
- **To add the three `users` columns to the upsert** without proof the
  2026-07-03 migration is applied. That is the right architecture and it
  is the founder's ordering call — §5.5.
- **To write a migration**, deploy an Edge Function, add an analytics
  event, add a HealthKit type, touch Payment / Paywall / Auth /
  `AppPhase` / `Info.plist` / entitlements, or bump
  `CURRENT_PROJECT_VERSION`.
- **To guess numeric suppression from the plan shape.** It would strip
  every number from ordinary payers to protect a cohort it cannot
  identify.
- **To implement `users.program_status` as a mirror.** A second
  denormalised copy of plan state is the drift `31` §10 removed.
- To redesign anything, to weaken a gate to make a test pass, or to
  polish, rename or refactor anything not named above.

## WHAT REMAINS

**P0: none.**

**P1**
1. `safety_numeric_suppression`, `program_mode`, `goal_direction` and
   `medication_status` on `public.users` — three of the four columns
   already exist. Verify, then client-only. §5.5.
2. Jeni's memory does not follow the account (migration first).
3. A past dose log cannot be corrected; side effects are today-only
   (carried from `34`).
4. `onb_consent_personalize` — a recorded consent the product does not
   honour (founder/legal, on file since `30` §15).
5. Run `docs/app_v25/reconcile_21.sql` and
   `docs/app_v25/no_target_census.sql`.

**P2**
- `users.program_status` / `program_intensity_tier` / `program_goal_date`
  and `public.coach_messages` — false contracts; deprecate the comments,
  delete the columns in a later migration.
- `SafetyCheckInView` — the product's own post-enrolment re-screen, with
  zero production call sites and a fabricated 65 kg body (`30` §6).
- The chat transcript and manual move entries do not sync; body-scan
  device-locality is unstated on the surface.
- Everything carried from `32` §15 and `34`: the age band's 35 kcal, the
  offline day-stamp, the residual resurrection window, start weight not
  user-editable, two devices / two units, the four-way pace vocabulary,
  the CONSISTENCY card, the dead corpora.

## TEST PROOF

1228 app (+21) · 9 PlankSync · 200 PlankFood · 1 WallExit walker ·
Release `BUILD SUCCEEDED`. Every one with expected == actual, exit 0 and
`** TEST SUCCEEDED **`, read together. RED proven at 17 failures before
GREEN.

## PROTECTED-PATH DIFF

Twelve of the sixteen protected paths are **EMPTY vs `1710180`**; the
other four carry only `27`/`31`/`34`'s already-recorded work and **this
session's diff to all four is empty**. Zero files under `Packages/`
touched. All three `@Model` files zero-diff.

## MIGRATION STATUS

**None written, none applied, none needed.** No `@Model` changed, so no
SwiftData migration exists to fail. The one migration this work points at
is recommended with its ordering and deliberately not prepared.

## DEPLOYMENT STATUS

**Nothing deployed. No Edge Function. No production SQL executed. No
production data read or mutated.** `CURRENT_PROJECT_VERSION` still 30;
the archive-time bump to 31 stands.

---

**SAFE FOR NEXT BUILD: YES.**

Not because the suite is green. Because the sentence the session was
written to test is now true and pinned by a test that fails loudly if
anyone weakens it:

> **A customer who told Jeni "do not put me on a deficit" does not need
> to remember that Jeni forgot.**
