# SHIP THE BORING TRUTH — the release-candidate pass

**Status: CANDIDATE FROZEN 2026-08-14.** No new work. This session asked
one question and stopped when it was answered:

> **CAN THIS BRANCH SHIP TO EVERY EXISTING JENI CUSTOMER — as a real App
> Store update, replacing the installed build, over old local state?**

Three sessions (`29`, `30`, `31`) changed program truth, recovery, sync,
calorie inputs, plan selection and self-repair. Everything below is
verification of what those sessions did, plus **exactly one line of
product code** written here, and the reason it earned its place.

---

## RELEASE DECISION

**SAFE TO SUBMIT: YES**, with one mechanical prerequisite the founder
controls (§BUILD NUMBER).

Everything in the stop condition is true: Autym passes, the dirty-local
inverse passes, all ten upgrade fixtures pass, history is preserved,
Home == Plan == Jeni, the paywall regression passes, the live V8 walker
passes, the sign-out round trip's only drift is the documented one,
offline failures are non-destructive, multi-plan selection is
deterministic, Release builds and is strings-clean, and no P0 or P1
remains.

---

## THE TWO CODE CHANGES THIS SESSION EARNED

**P1 · a medical claim that I made reachable.**
`HardTierGate.lockReason` said, for the GLP-1 cohort:

> "we hid Hard while you're on a GLP-1. **your metabolism is already
> running lower.** Soft or Medium pairs better."

That is a specific physiological claim about HER body, which the app has
not measured. It had **never rendered** — `ProgramSetupSubflow.parsedAge`
read an age vocabulary nothing writes, so `HardTierGate` locked on the
nil-age branch for every user and `lockReason` always fell through to its
generic last line. `31` fixed the age. **Fixing the gate made this line
live for the first time**, and my pace editor surfaces it too. Copy that
becomes reachable in the same change is that change's responsibility.

> "we hid Hard while you're on a GLP-1. **the lean-mass guidance favours
> a slower glide while you're losing.** Soft or Medium pairs better."

Attributed guidance, not a diagnosis. Nothing else in the product voice
moved.

**P1 · a fifth name for three tiers, and it was mine.**
Watching the live walker cross the consult's pace screen showed it
labelling the tiers **`soft / steady / focused`**. The app already had
three more vocabularies for the same three values —
`ProgramSetupSubflow` says `soft / medium / hard`, `HomeView.tierWord`
says `gentle / steady / strong` — and `JKPlanNumbersSheet`, written last
session, had invented **`gentle / steady / quick`**. A repair screen that
names her pace differently from the screen that set it is the exact
defect class this whole line of work exists to close.

**Three of those four vocabularies shipped and were left alone** — a
release candidate is not a naming pass. The fifth word was one this
session's own new surface introduced, so `quick` became `strong`, which
is what Home already shows her. Two string literals, no logic. The
pre-existing four-way split is recorded as P2.

---

## 1 · THE UPGRADE MATRIX

`plankAITests/UpgradeBoundaryTests.swift` — 12 tests. Every fixture is
seeded in the shape the **production build** left it, then the next
build's launch reconciliation runs over it in `AppSync.onLaunch`'s order:
**PULL → MERGE → HEAL** (the push comes after).

**The single largest upgrade risk is absent by construction:** no
`@Model` definition has changed since the reviewed release `1710180`.
`Models.swift` has a zero diff and no file declaring a `@Model` moved, so
there is no SwiftData store migration on update. Verified by diffing
every file in the repo that declares a `@Model`.

| # | fixture | result |
|---|---|---|
| A | coherent legacy customer | **byte-identical kcal**, same plan id, same start date, all history, `hasCompletedOnboarding` intact, row NOT dirtied by the act of updating |
| B | Autym: server 110 / local stale 124 | goal resolves 110, `totalDays` 119, start date unmoved, deficit basis, history intact, adopted row not queued back |
| C | fabricated goal, profile goal NULL | **no number**, `missingEnergyInput == .goal`, start weight not collapsed, NULL server value deletes nothing |
| D | corrected server body facts over old local mirrors | height 150 → 160.02 and sex → male both reach `@AppStorage` |
| E | rich paying user (4 weigh-ins, regimen, 3 doses, 2 observations, day check) | **every row survives**; freshest weigh-in still outranks stored weights; start weight still the start weight |
| F | maintenance customer | still holding, real number, never reported as a missing input |
| G | kilograms customer | unit untouched by the merge; `6.4 kg to go` |
| H | already at goal | maintenance number, not silence |
| I | pending local edit at the moment of update | 115 lb survives the update, horizon 84 days survives, still queued |
| J | no valid active plan | **no plan minted by launching**, history intact, her own numbers still produce a target |
| — | offline launch | nothing changes, push stays queued, nothing minted |
| — | **all fixtures, launched twice** | no history lost, **no duplicate plan**, onboarding never restarts |

**No first-launch destruction, itemised:** subscription and auth are
untouched code (zero diff, §DIFF MAP); food history is untouched code and
untouched by the launch path; weight / medication / dose / observation /
day-check history asserted row-for-row in E and in the all-fixtures
sweep; program start date, start weight, current weight, goal and units
asserted per fixture; `hasCompletedOnboarding` asserted in every fixture;
`AppPhase` has a zero diff so no paywall can reappear for an entitled
customer; no plan is minted except by `startProgram`, which only a user
action calls.

**PULL → MERGE → PUSH ordering does not regress legitimate offline
edits** — that is fixture I and the symmetry test in §2.

---

## 2 · AUTYM IS A PERMANENT RELEASE GATE

`plankAITests/AutymRecoveryTests.swift` — 7 tests, run from the final
candidate, **all passing**. The fixture is unchanged and unweakened:

```
SERVER  goal 110 · 119 days
DEVICE  goal 124 · 210 days · same plan id · same start date
```

→ resolved goal **110** · basis `.deficit(0.00664/wk)` · same
`startDate` · same plan id · exactly one plan row · weigh-in still on
file · `pendingUpsert == false` so the stale 124 cannot upload · Home
draws the number without a reinstall or a sign-out.

**Proved RED before GREEN** in `31`: with the merge stubbed and the
mirror reverted to absent-only, this suite produced **13 failures**.

### THE DIRTY-LOCAL CONFLICT TEST (the symmetry)

`testALegitimateOfflineEditWinsAndThenReachesTheServer`:

```
SERVER  goal 110  (older, already synced)
DEVICE  goal 115  (her edit, pendingUpsert = true)
LAUNCH  → 115 survives the pull, the horizon 84 survives, the screen
          shows 115, both flags still queued
PUSH    → the payload carries 115 / 84 — the eventual truth on both sides
RE-PULL → reaches a FIXED POINT: a second identical pull changes nothing,
          so the merge can never churn or re-push
```

`testTheSameSymmetryHoldsForThePaceTier` proves the guard is **per
record, not per field**: a dirty row keeps its `intensityTier`; once
clean, the same row adopts. That is the whole rule, both directions:

> **clean local → the server may repair · dirty local → her edit wins**

One honest note the test records: the FIRST merge may normalise
`goalDate`, because the column is a Postgres `date` and a locally
computed goal date carrying a time component snaps to UTC midnight. It is
a one-time normalisation that settles immediately, which is why the
fixed-point assertion is the one that matters.

---

## 3 · SIGN-OUT → SIGN-IN ROUND TRIP

`CalorieGoldenMatrixTests.testAfterSignOutAndSignInTheOnlyDriftIsTheAgeBand`
performs the real sweep (`clearOnboardingUserDefaults`'s identity-scoped
body keys) and the real restore (`restoreBodyDefaults` +
`mirrorActivityAlias`), then compares.

| value | before | after | class |
|---|---|---|---|
| current weight | 56.245 kg | 56.245 kg | EXPECTED |
| start weight (plan) | 56.245 kg | 56.245 kg | EXPECTED |
| goal weight | 49.895 kg | 49.895 kg | EXPECTED |
| height | 160.02 cm | 160.02 cm | EXPECTED |
| sex | female | female | EXPECTED |
| activity | `walks` (raw) | `walks` (alias) | EXPECTED — the round-trip law, `30` §4 |
| weight/height unit | lb / ft-in | lb / ft-in | EXPECTED (device-level, never swept) |
| pace tier | medium | medium | EXPECTED |
| program start / id | unchanged | unchanged | EXPECTED |
| weight, food, dose history | unchanged | unchanged | EXPECTED |
| subscription entitlement | RevenueCat `customerInfoStream` | unchanged | EXPECTED (zero diff) |
| **exact age** | **34** | **29** | **LOSSY-BUT-DOCUMENTED** |
| daily target | **1282** | **1317** | DERIVED from the above |

**The age is called out, not hidden.** `onb_v5_age_years` is swept by the
`onb_v5_` prefix and `users` carries only `onboarding_age_range`, so 34
returns as the band's representative 29: **+25 kcal of BMR, +35 kcal on
the target**. The test asserts the delta is exactly 35, so if a SECOND
lossy input ever appears the assertion breaks and the record is known to
be wrong. On screen the app says `about 29 · approximate` and offers a
one-tap correction (`31` §5). **BUG: none.**

---

## 4 · THE CALORIE GOLDEN MATRIX

`plankAITests/CalorieGoldenMatrixTests.swift` — 11 tests. **The formula
is frozen this session; not one constant moved.** Every number below was
derived by hand from the frozen formula *before* it was written down, and
each is now a release fixture: a future formula change must come here and
change them on purpose.

Anchor body: **124 lb = 56.2452 kg · 160.02 cm · 34 · female**
BMR = 562.452 + 1000.125 − 170 − 161 = **1231.577**
rate = ((56.2452 − 49.8952)/56.2452)/17 wk = **0.0066411/wk** →
deficit **410.9 kcal/day**

| persona | derivation | **target** |
|---|---|---|
| autym-like loss (walks) | round(1231.577×1.375)=1693 − 411 | **1282** |
| sedentary loss | 1478 − 411 = 1067 → **floor is her own BMR** | **1232** |
| moderate loss | 1909 − 411 | **1498** |
| athlete loss | 2124 − 411 | **1713** |
| male loss | BMR 1397.577 → 1922 − 411 | **1511** |
| female loss | anchor | **1282** |
| unspecified sex | conservative (female) constants | **1282** |
| GLP-1 current | medication is not in the arithmetic | **1282** |
| non-GLP-1 | — | **1282** |
| kg customer | units are presentation only | **1282** |
| maintenance chosen | rate 0 → TDEE | **1693** |
| at goal (108 lb) | BMR 1159.0 → 1594, rate 0 | **1594** |
| soft tier (23 wk) | 1693 − 304 | **1389** |
| medium tier (17 wk) | 1693 − 411 | **1282** |
| hard tier (15 wk) | 1693 − 461 = 1232 → **BMR floor binds** | **1232** |
| after sign-out/in (age 29) | BMR 1256.577 → 1728 − 411 | **1317** |
| after goal edit → 115 lb | horizon 17 wk → 11 wk, rate held | **1285** |
| after weight edit → 118 lb | BMR 1204.4 → 1656 − 391 | **1265** |
| after activity → barely / very_active | — | **1232 / 1713** |
| after sex edit → male | 166 BMR × 1.375 | **1511** |
| after pace edit → soft | — | **1389** |
| after age edit → 44 | 50 BMR kcal | **1214** |
| after server repair | Autym, priced | **1282** |
| missing goal · missing height · missing weight | — | **NO TARGET** |

For every valid state **HOME == PLAN == JENI**, to the integer. For every
invalid state all three are nil — **not zero, not a maintenance fallback,
not a fabricated value** — and `missingEnergyInput` names the fact.

**Two things the golden matrix taught me, and both are recorded in the
test file because I got them wrong first:**

1. **Sedentary does not reach 1200.** The floor is `max(1200, BMR)`, and
   her BMR is 1232 — so the floor that binds is her own metabolic rate,
   which is `29` §3's stated design, not a clamp bug. Hard tier lands on
   the same floor.
2. **A goal edit barely moves the number, and that is correct.** The
   PACE tier owns the rate; `GoalWeightStore` recomputes the horizon
   through the same window calculator, so 110 → 115 lb takes the plan
   from 17 weeks to 11 and leaves the daily target within 3 kcal. I
   expected a ~170 kcal jump; had I got one, the pace tier would not have
   been governing anything.

---

## 5 · THE MULTI-PLAN MATRIX

`plankAITests/PlanIdentityTests.swift` — 9 tests, run from the candidate.

| state | selection |
|---|---|
| 0 live | nil |
| 1 live | it |
| completed only | nil — history is not the plan she is living in |
| **2 live (real + interim)** | **earliest `startDate`**, never the interim one that resets her to day 1 |
| active + maintenance | the live one |
| active + archived (`archived_at` set, phase still live) | the un-archived one |
| parent completed + child active | the child |

**One rule, both call sites.** `ProgramService.activePlan` and
`AppSync.reconcileLivePlans` now agree (earliest `startDate`, `createdAt`
breaking a same-day tie), and hydrated rows carry their real `started_at`
so plan order after a reinstall is no longer the order of a `for` loop.
Irreducible corruption is **archived, never deleted, never replaced by a
third plan**, and the keeper is never re-pushed. No fetch-order roulette;
no hydration-time-`createdAt` roulette.

---

## 6 · THE OFFLINE / RELAUNCH MATRIX

| scenario | behaviour | destructive? |
|---|---|---|
| cold launch online | pull → merge → heal → push | no |
| **cold launch offline** | the fetch throws and is caught; `applyHydratedProgramPlans` is never reached; the app renders local state | no — proven by `testOfflineLaunchChangesNothingAndKeepsThePushQueued` |
| warm relaunch | day stamp suppresses a second refresh | no |
| network failure during pull | caught per-table; local state stands | no |
| network failure during push | `pendingUpsert` stays true, retried next launch — and the pull now runs FIRST, so the stale row cannot land before the repair is read | no |
| pull succeeds / push fails | adoption does not dirty the row, so there is nothing to push | no |
| pull fails / local pending edit exists | hydrate skips dirty rows by rule; the push retries | no |
| any of the above, twice | idempotent — no duplicate plan, no lost history | no |

**KNOWN LIMITATION, classified P2, documented not fixed:**
`refreshProgramTruth` writes its day stamp *before* awaiting the network,
so a launch that happens to be offline consumes that day's refresh and a
pending server repair arrives on the next calendar day instead. It
delays a repair path that **previously did not exist at all**; it cannot
lose data, misstate a program or resurrect corruption. Under this
session's freeze rule that is not P0 or P1, and every additional line is
release risk.

---

## 7 · THE PAYWALL / 5.6 REJECTION REGRESSION

**Zero diff** across all six protected paths since the reviewed release:
`PlankApp/Payment`, `PlankApp/Views/Paywall`, `PlankApp/Auth`,
`PlankApp/App/AppPhase.swift`, `PlankApp/Info.plist`,
`plankAI.entitlements`. Behaviour is therefore verified by running the
existing implementation, not by modifying it.

`plankAIUITests/WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds`
— **passed (10.4 s), `** TEST SUCCEEDED **`.** It walks the exact
rejected sequence: subscription screen → X → the one-time alternative →
dismiss → subscription screen → X → a non-purchase screen, repeated, on
both the fresh state and the returning state where the offer-seen flags
are already consumed (`WallExitIntent`'s one-offer-then-stand-down, which
is the 5.6 fix riding this build). No unresponsive X, no purchase loop,
no chained offers, no hidden dismissal, no gesture trap.

---

## 8 · THE FRESH CUSTOMER WALK

`plankAIUITests/OnboardingV5WalkerUITests/testWalkV8ToPaywall` — the
**live** V8 consult, no DEBUG shortcut, welcome → 31 beats → reveal →
hard paywall, with real RevenueCat prices on the wall.

**Run three times, and all three are reported:**

| run | duration | result |
|---|---|---|
| 1 | 311.5 s | **passed** |
| 2 | 811.0 s | **FAILED** — `waitForExistence(timeout: 15)` on the oath's `hold to promise` |
| 3 (solo, fresh boot) | 311.2 s | **passed**, exit 0, `** TEST SUCCEEDED **` |

Run 2 is environmental, and the evidence is in its own log rather than in
an assumption: it took **2.6× longer than either passing run**, and
xcodebuild reported `mkstemp: No such file or directory` while trying to
write the result bundle. A 15-second wait on a machine that slow drops a
1.9-second synthesized long-press — which is the flake family this repo
already documents (*"UI legs run SOLO; rerun legs solo before
diagnosing"*). The oath screen lives in `OnboardingRevealView.swift`,
which has a **zero diff** across `29`–`32`, so there is no candidate
regression. Re-run solo on a fresh boot it returns to exactly 311 s.

**I am reporting the failure rather than only the two passes**, because
a release gate that quietly retries until green is not a gate.

**A verification failure worth recording.** My first invocation named
`plankAIUITests/OnboardingWalkthroughUITests/testWalkV8ToPaywall` and
xcodebuild answered:

```
Executed 0 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

The walker lives in `OnboardingV5WalkerUITests`, not
`OnboardingWalkthroughUITests`. **A green verdict over a zero count is
the §16 trap in its purest form** — and it is the second time in three
sessions this repo has produced `TEST SUCCEEDED` next to a count that
proves nothing ran. Expected count is now checked on every command in
this document.

---

## 9 · ACCESSIBILITY + SMALL DEVICE

Re-walked the changed truth surfaces at AX5
(`simctl ui <dev> content_size accessibility-extra-extra-extra-large`)
and on the SE.

- **No numeral wraps or truncates at any size**, on any surface changed
  by `29`–`32`: `124` · `110` · `1,282` · `1,693` · `1,599` · `5'3"` ·
  `160 cm` · `about 29` · `17 weeks`. The `124` → `12`/`4` law and the
  weigh-in `12…` law both hold.
- `your numbers` scrolls its seven rows at AX5; the `done` capsule stays
  pinned with its hairline; every editor's CTA is reachable; every close
  control is reachable.
- The pace editor's refusal footnote and Home's `· holding` both carry
  `fixedSize(vertical:)` and no `lineLimit`, so they wrap rather than
  truncate — the word that carries the meaning is never the one cut.

---

## 10 · THE PRODUCTION CENSUS

**`docs/app_v25/census.sql`** — reviewed and re-verified this session:

- **READ ONLY.** `with` / `select` / `union all` / `values` only. No
  `insert`, `update`, `delete`, `create`, `alter`, `grant` anywhere.
- **No emails.** The main query returns no identifiers at all. The
  optional diagnostic returns account UUIDs only, and is commented out.
- **Active-plan definition is byte-identical to the client's**:
  `phase in ('active','maintenance','recomp','pause')` and
  `archived_at is null`, `distinct on (user_id) … order by start_date asc,
  started_at asc`.
- **Denominators are explicit** — each row states whether its percentage
  is of all onboarded accounts or of accounts with a live plan.
- **Caveat stated, not hidden:** `is_test_user` is a PostHog person
  property, not a `users` column, so internal accounts are included.

**Not executed.** Fifteen classified states, including the two that
decide whether a bulk repair is warranted: `goal == start (THE
FABRICATION)` and `profile / plan goal DISAGREE`.

Per §6 of the brief, no bulk-repair infrastructure has been built. The
decision framework stands: 0 → nothing; tiny → self-repair and the
support path already shipped; meaningful → evaluate one-time client
reconciliation; large → a repair may be release-blocking.

---

## 11 · THE CUMULATIVE DIFF MAP

What the NEXT BUILD changes relative to what customers have installed
**today** (production `1.2.0 (30)`, archived from `1710180`).

| domain | files | behaviour | risk | proof |
|---|---|---|---|---|
| **PROGRAM TRUTH** | `TargetsService` `PlanSummary` `GoalWeightStore` `BodyFactsStore` `ProgramService` `CalorieTargetCalculator` `IntensityProfile` `ProgramGoalCalculator` `CareProtocol` `WeightJourney` `DoseStanding` `Method/*` | `EnergyBasis`; one weight ladder; her answer outranks a disagreeing plan; arrival is maintenance; one plan-selection rule; one age resolver | **medium — this is the point of the release** | golden matrix (11) · `OneTargetEverywhere` (6) · `BasicTruth` · `PlanIdentity` (9) |
| **SYNC / RECOVERY** | `AppSync` `PlankSync/SyncService` `ProgramPlanMerge` | truth refresh; plan merge; body-fact mirror; pull-before-push | **medium** | `AutymRecovery` (7) · `UpgradeBoundary` (12) · `HydrationNormalization` (9) |
| **SETTINGS / SELF-REPAIR** | `JKPlanNumbersSheet` `JKGoalRitual` `ProfileHubView` | seven editable inputs where there were none | low — additive surfaces | `RepairSurface` (14) · films |
| **HOME / PLAN PRESENTATION** | `HomeView` `HomeSections` `ProgramIntroFullScreenCover` `ProgramSetupSubflow` `TodayModuleHost` `PlateDetailSheet` `MoveSheet` `JKWeightRitual` `MethodNoteView` `BecomingSummaryView` | protein leads; empty denominator is a door; `· holding`; the plan states her numbers | low | films at AX5 + SE |
| **JENI CONTEXT** | `CoachContextAssembler` `JeniChatView` `JeniReadTools` `JeniToolCatalog` `JeniDeskAwareness` | envelope resolves through `PlanSummary`; `kcal_basis`, `goal_on_file`, `kcal_missing` | low — **zero EF deploy**, the allowlist gates tool NAMES | `JeniTools` · parity matrix |
| **FOOD** | `Packages/PlankFood/*` (18 files) | portion truth, provenance, micronutrient honesty — all from `26`/`27`, already reviewed | low | 192/192 |
| **MEDICATION** | `DoseStanding` + `MedicationQASeeder` | one dose sentence, shared by Home and the plan screen | low | `MedicationPlatform` · `DoseStanding` |
| **HEALTHKIT** | `MoveRecord` `EnergyLedger` | **no new read type, no purpose-string change** | low | `Info.plist` zero diff; grep for `HKQuantityType` in the diff is empty |
| **ANALYTICS** | `AnalyticsHygiene` (+6 lines, allowlist) | **no event added, renamed or redefined** | none | grep of the diff |
| **PAYMENT** | — | — | **none** | **zero diff** |
| **AUTH** | — | — | **none** | **zero diff** |
| **B2B / CARE** | `CareProtocol` only | clamps unchanged; no clinician authority invented | none | `CareLoop` · `CareProtocol` |
| **SUPABASE** | `functions/food-vision/index.ts` | **written, NOT deployed** — founder gate | none in this build | `migrations/` zero diff |
| **BUILD CONFIG** | `project.pbxproj` | file references only | none | §BUILD NUMBER |

**Zero diff, verified individually:** `PlankApp/Payment` ·
`PlankApp/Views/Paywall` · `PlankApp/Auth` · `PlankApp/App/AppPhase.swift`
· `PlankApp/Info.plist` · `plankAI.entitlements` · `JenifitWidgets` ·
`supabase/migrations` · `PlankApp/Notifications` · `PlankApp/Care` ·
`PlankApp/BodyScan` · `PlankApp/Workout`.

**And no `@Model` anywhere in the repo changed** — the store schema
customers are carrying is the store schema this build opens.

---

## 12 · NOTHING WAS DELETED FOR LOOKING OLD

Deliberately retained, because installed customers still carry them:

- `onboardingActivityLevel` in the sign-out sweep list — zero writers,
  harmless, and removing it changes a sweep an installed device performs.
- The legacy activity aliases (`sedentary` · `light` · `lightly_active` ·
  `moderately_active` · `active` · `athlete`) and the collapsed
  `moderate` — a pre-2026-08-14 account's only surviving value.
- The legacy age-band vocabularies (`18-24` · `18_24` · `55+`) in
  `EnergyLedger.ageMidpoint`.
- Old plan rows with NULL `goal_weight_kg`, NULL `current_weight_kg`, or
  `archived_at` set while the phase still reads live.
- `onb_v5_unit_lb` / `onb_v5_unit_ftin` alongside `weightUnit` /
  `heightUnit`.
- The 84-lesson Method corpus, the workout library, Body Scan.

**An ugly compatibility shim is preferable to corrupting an old payer.**

---

## 13 · TEST PROOF

Every command run serially. No concurrent `xcodebuild`. All verdicts
below were re-run through `scratchpad/run.sh`, which captures
**xcodebuild's own `$?`** — see the correction beneath the table.

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `xcodebuild test … -only-testing:plankAITests` | 1164 | **1164** | **0** | `** TEST SUCCEEDED **` |
| `xcodebuild test -scheme PlankSync …` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `xcodebuild test -scheme PlankFood …` | 192 | **192** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** | **0** | `** TEST SUCCEEDED **` |
| `… OnboardingV5WalkerUITests/testWalkV8ToPaywall` | 1 | **1** (311.5 s) | **0** | `** TEST SUCCEEDED **` |
| `xcodebuild build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

App suite is **+25** over `31` (1139 → 1164): `UpgradeBoundaryTests` 12 ·
`CalorieGoldenMatrixTests` 11 · 2 new symmetry tests in
`AutymRecoveryTests`.

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.**

### THE VERDICT-CAPTURE CORRECTION — my own harness was lying

Every command in `29`, `30`, `31` and the first pass of this session
ended with:

```
… | grep -E "…" | tail -6; echo "EXIT=${PIPESTATUS[0]}"
```

**`PIPESTATUS` is a bash array. This shell is zsh**, where the variable
is `$pipestatus` and is 1-indexed — so `${PIPESTATUS[0]}` expanded to the
empty string and **every `EXIT=` line I printed was blank**, which is
exactly what the terminal output shows in hindsight. I was reading the
count and the verdict line and inferring the exit status from a variable
that never held one.

Nothing was wrong with the results — every suite re-run through a
correct capture returns `exit_status=0` — but the discipline in §16 of
the brief is about not accepting a signal you have not actually read,
and for four sessions I had been printing a placeholder. The runner now
executes `xcodebuild` unpiped, captures `$?` directly, and only then
greps the log:

```zsh
xcodebuild "$@" > "$LOG" 2>&1
STATUS=$?
```

Two verdict-hygiene defects found in one session — this and the
`Executed 0 tests / TEST SUCCEEDED` in §8 — and neither was in the
product.

---

## 14 · RELEASE BUILD PROOF

- **Release configuration compiles** (`-configuration Release`,
  `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) —
  `** BUILD SUCCEEDED **`.
- **Binary inspected**, `Release-iphoneos/plankAI.app/plankAI`:

| string | count |
|---|---|
| `--uitest` | **0** |
| `--debug` | **0** |
| `persona-autym` | **0** |
| `debug-plan-numbers` | **0** |

No debug routes, no test persona arguments, no support backdoors, no
hidden repair UI. Every door added by `29`–`32` sits inside `#if DEBUG`,
verified by line-range inspection of the `#if DEBUG` … `#endif` region as
well as by `strings`.

- **No production SQL executed. No production data mutated. No Edge
  Function deployed. No migration written or applied.**

### BUILD NUMBER — the one mechanical prerequisite

`MARKETING_VERSION = 1.2.0`, `CURRENT_PROJECT_VERSION = 30`.
**Unchanged, deliberately — I was instructed not to bump it.**

Flagging it because it blocks the upload, not the code: **build 30 was
already accepted by App Store Connect on 2026-08-12** (`STATE.md` §0.-15,
"a duplicate would have been refused"). This branch's binary is
materially different. ASC will refuse a second upload under `1.2.0 (30)`.
**Set `CURRENT_PROJECT_VERSION = 31` at archive time.** Nothing else
about the release depends on it.

---

## 15 · KNOWN LIMITATIONS

Carried forward, all previously named, none release-blocking:

1. **Exact age degrades to the band on sign-out** (±5 years, ±14 in the
   unbounded `55plus` band; 35 kcal for the anchor persona). Stated on
   screen as `about N · approximate`, correctable in one tap. A lossless
   fix needs a `users` column, and that client change 400s until the
   migration is applied — so it cannot ride a build that must be safe on
   its own (`31` §5).
2. **An offline launch consumes the day's truth refresh** (§6). P2.
3. **The residual resurrection window**: support repairs while she is in
   the app AND she re-enrolls before the next launch (`31` §12).
4. **Start weight is not user-editable** — deliberate; server-repairable,
   and the repair now lands.
5. **A plan row genuinely deleted server-side** cannot be restored by the
   device.
6. **Two devices can show two weight units** — the unit is device-level
   on purpose.
7. **`money-back guarantee` on the paywall** — a commercial claim on a
   protected path with a zero diff, shipped in the reviewed and approved
   build. Noted, not touched.
8. **Nothing here can be falsified against a payer** until the
   measurement contract's first clean read.

## 16 · ISSUE LEDGER

**P0: none.**

**P1: two, both found and fixed** — the GLP-1 metabolism claim this line
of work made reachable, and the fifth tier vocabulary this line of work
introduced. Both are defects in what these four sessions shipped, not
pre-existing debt I went looking for.

**DEFERRED P2+, documented not fixed** — the offline day-stamp (§6); the
age band (§15.1); **the pre-existing four-way tier vocabulary** (consult
`soft/steady/focused` · setup `soft/medium/hard` · Home
`gentle/steady/strong`); `onboardingActivityLevel`'s dead sweep entry;
the three dead onboarding readers from `30` §14; `SafetyCheckInView`'s
fabricated body; the Body Scan Home tile;
`EnergyLedger.spentKcal`/`isLighterDay` dead code; the unreachable
84-lesson corpus; `money-back guarantee` on the paywall. **No polishing,
no naming cleanup, no abstraction cleanup and no speculative refactor was
performed on any of them.**

---

## THE FIVE DECISIONS

**1 · SAFE TO SUBMIT TO APP REVIEW: YES** — after
`CURRENT_PROJECT_VERSION = 31` at archive time. No new medical claim; the
one that existed is gone; every number is labelled an estimate; no new
HealthKit type; no purpose-string change; the 5.6 exit path re-verified
green.

**2 · SAFE FOR EXISTING PAYING CUSTOMERS TO UPDATE: YES.** No SwiftData
migration exists to fail. Ten upgrade fixtures inherit their state with
no history lost, no plan duplicated, no onboarding restarted, no paywall
re-shown, and a coherent customer sees the byte-identical number she saw
yesterday.

**3 · CAN THE AUTYM FAILURE RECUR: NO.** The invariant, exactly:

> On every launch, at most once per day, the device pulls `users` and
> `program_plans` **before it pushes anything**. A local row whose
> `pendingUpsert` is `false` has had every write it ever made
> acknowledged by the server, so a server row that now disagrees is
> newer, and its **user facts and derived horizon are adopted while its
> identity — `id`, `userId`, `startDate`, `createdAt` — is not**.
> Adoption leaves the row clean, so it is never pushed back. A row whose
> `pendingUpsert` is `true` is never touched, so her offline edit always
> wins and always reaches the server.

Held by `AutymRecoveryTests` (7) and `UpgradeBoundaryTests` (12), both of
which fail loudly if the merge is weakened.

**4 · WORST KNOWN CUSTOMER-FACING FAILURE STILL PRESENT:** a customer
whose `users.onboarding_goal_weight_kg` is NULL *and* whose plan goal was
fabricated by the old build opens the app to no calorie target and a
`kcal · add a goal weight` link — honest, one tap from fixed, and better
than the maintenance number she is shown today, but still a paying person
losing a number she did not ask to lose.

**5 · WHAT SHOULD I DO NEXT:**

> **RUN THE PRODUCTION CENSUS AND RETURN THE RESULT.**

`docs/app_v25/census.sql`, first query, paste and run. It is the only
input that changes the plan: it sizes decision 4's population, and it
decides whether this build ships as-is (self-repair is enough) or whether
a one-time reconciliation is worth its risk. Everything else is frozen
and green.
