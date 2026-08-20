# THE ONE RECORD

**Status: BUILT 2026-08-14.** Not an era, not a feature pass, not a
redesign. One question, asked of the whole product:

> **DOES JENI ACTUALLY HAVE ONE RECORD OF THE PERSON?**

The invariant this session is measured against, verbatim from the brief:

> If the customer told Jeni something once, every legitimate surface
> should either know the same fact or explicitly say why it cannot.
> If the fact belongs to her account, changing devices should not
> silently change it. If the fact changes, every dependent number
> should change with it.

Nothing in the frozen candidate moved. No change to the calorie formula,
the protein formula, the merge contract, plan selection, the restore
path, the safety rules, payment, paywall, auth, `AppPhase`,
`Info.plist`, entitlements, migrations, the analytics contract, or any
HealthKit type. **No migration written. No Edge Function deployed. No
production SQL executed. No production data read or mutated.**
`CURRENT_PROJECT_VERSION` untouched.

---

## 0 · THE ANSWER FIRST

**Almost. The arithmetic has one authority and the record does not
— in four places, and three of them are one shape.**

`29`–`36` proved that every daily NUMBER resolves through one function.
This pass asked the harder question: does every FACT resolve through one
authority. Four answers came back no:

| # | the fact | the two authorities | who sees the difference |
|---|---|---|---|
| 1 | **her current weight** | `PlanSummary.currentKg` (every screen) vs the raw weigh-in row (the coach) | a woman who told the consult her weight and has not opened the scale: `your numbers` says `124 lb`, jeni has **no weight at all** — while publishing `to_go_kg` measured from it |
| 2 | **her pace** | `IntensityTier` → a word, mapped in **three view files**; the coach got the **raw storage value** | every screen says `steady`, jeni says `medium` |
| 3 | **a day** | `today`/`yesterday` in `your weigh-ins` and `the symptoms`; `aug 14` in `the doses` — **two of those lists are in one frame** | anyone looking at the regimen home |
| 4 | **her injection site** | on the record since v24, on the dose sheet, on every `the doses` row — **in no payload the coach ever receives** | a GLP-1 payer asking *"where did I inject last time?"* |

And one thing that is not a divergence but a **deletion hole**, which is
the P0:

> **Three user-owned families were added to the store after the
> 2026-08-08 sweep and never added to it.** `JeniMemoryRecord`,
> `ProgramFactRecord` and `WeeklyReadRecord` survived *"delete my
> account"* on disk and in every device backup taken afterwards. The
> sharpest is the first: it is **free text the customer typed and asked
> her coach to keep**, listed in Settings under *"what jeni remembers"*
> with a per-row forget, so it reads to her as the most personal thing
> the product holds.

All five are fixed. Everything else this pass found is named, sized and
left alone.

---

## 1 · THE FACT GRAPH

Traced to real writers and readers. Nothing here is inferred from a
comment; where a previous record was wrong, the correction is marked
**[CORR]**.

Legend — **L** local store · **S** server table · **H** hydrate reader ·
**R** canonical resolver · **E** edit surface · **D** delete surface ·
**O** survives sign-out · **N** survives a new phone.

### IDENTITY / PROFILE

| fact | first writer | all writers | L | S | H | canonical resolver | UI readers | jeni | E | D | O | N | conflict | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sex | consult (`OV5Store`) | + `BodyFactsStore.setSex` | `@AppStorage onboardingGender` + `onb_v5_gender` | `users.onboarding_gender` | ✓ `restoreBodyDefaults` | `TargetsService.profileInputs` | your numbers · plan · Home (via kcal) | `inputs.sex_term` | ✓ | — | swept → restored | ✓ | row-level LWW | **SAFE** |
| exact age | consult | `BodyFactsStore.setAgeYears` | `onb_v5_age_years` | **none** | — | `TargetsService.knownAge` | your numbers | `inputs.age` | ✓ | — | **swept, lost** | **✗** | — | **DEGRADED, DISCLOSED** §5 |
| age band | consult | + the editor + hydrate | `onboardingAgeRange` · `ageRange` | `users.onboarding_age_range` | ✓ | `ageBandOnFile` | via age | ✓ | ✓ | — | ✓ | ✓ | LWW | SAFE |
| height | consult | `BodyFactsStore.setHeightCm` | `onboardingHeightCm` | `users.onboarding_height_cm` | ✓ | `profileInputs` | your numbers | `inputs.height_cm` | ✓ | — | ✓ | ✓ | LWW | SAFE |
| height unit | consult | your numbers | `heightUnit` | **none, by design** | — | `HeightUnit.current` | everywhere | — | ✓ | — | **not swept** | device-level | — | BY DESIGN (`31` §18 G) |
| weight unit | consult | your numbers · weigh-in | `weightUnit` | **none, by design** | — | `WeightUnit.current` | everywhere | ~ | ✓ | — | not swept | device-level | — | BY DESIGN |
| activity | consult | `BodyFactsStore.setActivityBaseline` | `onb_v4_movement_baseline` + `activityLevel` | `users.onboarding_activity_level` (**alias only**) | ✓ + `mirrorActivityAlias` | `TargetsService.activityKey` | your numbers | `inputs.activity` | ✓ | — | alias survives | alias | LWW | **DEGRADED, STATED** (`30` §4) |
| outcome / `came_for` | consult | — | `onb_v5_outcome` | none | — | — | **none** | `profile.came_for` | ✗ | — | **swept** | ✗ | — | texture; lost, harmless |

### PROGRAM

| fact | writers | L | S | R | UI | jeni | E | O | N | verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| current weight | consult · `WeightLogWriter` · chat `log_weight` · HealthKit import | `WeightLogRecord` + `onboardingCurrentWeightKg` | `weight_logs` + `users` | **`TargetsService.resolvedWeightKg`** | Home · your numbers · ledger | ✓ **(fixed §8)** | ✓ any row | ✓ | ✓ | **SAFE** |
| start weight | `ProgramSetupSubflow.commit` | `plan.currentWeightKg` | `program_plans` | plan | plan screen | `weight.start_kg` | ✗ by design | ✓ | ✓ | SAFE |
| goal weight | consult · `GoalWeightStore` | `onboardingGoalWeightKg` + `plan.goalWeightKg` | both | `PlanSummary` | your numbers · Settings · plan | `weight.goal_kg` | ✓ | ✓ | ✓ | SAFE |
| goal direction | consult · `GoalWeightStore.setDirection` | `onboarding_goal_direction` | **column exists, ZERO writers** | `CohortStore` | implied | via basis | ✓ | **swept, lost** | **✗ → the app asks** | HANDLED (`35` §5.3) |
| pace | onramp · `GoalWeightStore.setPaceTier` | `onboardingPickedTier` + `plan.intensityTier` | `program_plans` | plan | Home · your numbers · setup | **`inputs.pace` (fixed §9)** | ✓ | ✓ | ✓ | **SAFE** |
| program mode | safety gate · `OV5Flow` · `GoalWeightStore` | `program_mode` | **column exists, ZERO writers** | `CohortStore` | via basis | `program_mode` | ~ | **swept, lost** | **✗ → the app asks** | HANDLED |
| start date | `ProgramService.startProgram` | `plan.startDate` | `program_plans.started_at` | `activePlan` (earliest) | Home `day N` | `plan.day` | ✗ identity | ✓ | ✓ | SAFE |
| goal date · total days | `ProgramGoalCalculator` via `GoalWeightStore` | plan | ✓ | plan | pace row | `weeks_at_her_pace` (recomputed live) | derived | ✓ | ✓ | SAFE |
| safety pace cap | safety gate | `safety_pace_cap` | **none** | `resolvedSafetyCap` | via basis | via basis | ✗ | **swept** | **partial** (`under18`+`bmi_low` re-derived) | NAMED (`35`) |
| numeric suppression | safety gate | `safety_numeric_suppression` | **none** | `CohortStore` | 15 sites | flags | ✗ | **swept** | **✗** | **NAMED, CONTAINED** (`35` §5.4) |

### FOOD

One store (`FoodLogPersister`, a JSONL), one chokepoint (`persist`), one
accumulator. Re-verified this session: **there is no second sum.**

| fact | writers | L | S | E | D | backdate | jeni | verdict |
|---|---|---|---|---|---|---|---|---|
| the record | 6 doors → `persist` | JSONL | `food_logs` | ✓ | ✓ | — | `today.plates` · `read_food_day` | SAFE |
| logged day | `persist` · `relog` · **`setLoggedDay`** | `loggedAt` | `logged_at` | ✓ 14 d | — | ✓ (`34`) | ✓ | SAFE |
| kcal · protein · carbs · fat · fiber | pipeline | ✓ | dedicated columns | ✓ | ✓ | ✓ | ✓ | SAFE |
| sugar | pipeline | ✓ | `sugar_g` | ✓ | ✓ | ✓ | ✓ | SAFE |
| sodium · sat fat | pipeline | ✓ | **`payload` jsonb** | ✓ | ✓ | ✓ | sodium ✓, sat fat silent | SAFE |
| quantity / servings | `PlateShare` | in the item | via items | ✓ | — | — | — | SAFE |
| source (the door) | dispatcher | ✓ | `food_logs.source` | — | — | — | `plates[].how` | SAFE |
| image | capture | local + bucket | private bucket | — | ✓ with the entry | ✓ travels | never | SAFE |
| corrections | fix-with-words | ✓ | `payload` | ✓ | ✓ | ✓ | `your_corrections` | SAFE |
| repeat relationship | `relog` | new id, `source = again` | ✓ | ✓ | ✓ | ✓ | ✓ | SAFE |

### WEIGHT · GLP-1 · OTHER · JENI

| fact | L | S | E | D | O | N | jeni | verdict |
|---|---|---|---|---|---|---|---|---|
| every `WeightLogRecord` (day · number · source) | ✓ | `weight_logs` | ✓ any day | ✓ any day | ✓ | ✓ | trend only — **[CORR] §10** | SAFE |
| medication status (insulin) | `onboarding_medication_status` | **column exists, ZERO writers** | ✗ | — | swept | **✗** | — | NAMED (`35`) |
| regimen + version chains | `RegimenPlanRecord` | `regimen_plans` | ✓ | chain | ✓ | ✓ | `medication{}` | SAFE |
| dose · schedule · dose event | ✓ | `dose_events` | ✓ (`36`) | ✓ | ✓ | ✓ | `read_dose_history` | SAFE |
| **injection site** | `DoseEventRecord.site` | ✓ | at mark time | — | ✓ | ✓ | **✗ → ✓ (fixed §11)** | **WAS BROKEN** |
| skipped / late state | ✓ | ✓ | ✓ (`36`) | ✓ | ✓ | ✓ | `recent_slots` | SAFE |
| side effect · severity · day | `ObservationRecord` | `observations` | ✓ 14 d (`36`) | ✓ + server (`36`) | ✓ | ✓ | `read_symptoms` | SAFE |
| steps | HealthKit | — | — | — | Apple's | Apple's | `read_activity` | n/a |
| **manual movement** | `UserDefaults move.manual.v1` | **none** | ✓ | ✓ | ✓ | **✗** | **✗** | **LOST** §7 |
| body scans | `BodyScanRecord` | opt-in bucket | ✓ | ✓ | ✓ | **✗ by default** | count only | BY DESIGN, unstated |
| reminders / notification prefs | `@AppStorage` | `users.onboarding_notification_*` | ✓ | — | ✓ | ✓ | `set_reminder_hour` | SAFE |
| **visit-packet consent** | `ConsentGrantRecord` | `consent_grants` | ✓ | revoke | ✓ | — | **✗ NO HYDRATE** | **[CORR] §6** |
| **jeni memory** | `JeniMemoryRecord` | **none** | ✓ | ✓ | ✓ | **✗** | `remembered` | **LOST** §6 |
| **chat transcript** | `ChatMessageRecord` | `coach_messages` **zero writers** | — | account delete | ✓ | **✗** | — | **LOST** §6 |
| tools jeni can invoke | `JeniToolCatalog` | server allowlist | — | — | — | — | 8 reads · 12 acts | §10 |
| **program facts** | `ProgramFactRecord` | `program_facts` | via chat/read | **✗ → ✓ §12** | ✓ | ✓ | `program_facts` | fixed |
| **weekly reads** | `WeeklyReadRecord` | `weekly_reads` | — | **✗ → ✓ §12** | ✓ | ✓ | `week{}` | fixed |
| supplements | — | — | — | — | — | — | — | **NO FEATURE** (re-verified: `supplementPlans` still zero call sites) |

---

## 2 · THE DEPENDENCY GRAPH

Traced persisted fact → resolver → output, not function to function.

```
CALORIE TARGET  TargetsService.calorieTarget
  ← resolvedWeightKg   ( latest WeightLogRecord › onboardingCurrentWeightKg › plan.currentWeightKg )
  ← profileInputs.heightCm            ( onboardingHeightCm )
  ← profileInputs.sex                 ( onboardingGender )
  ← profileInputs.age                 ( onb_v5_age_years › representativeAge(band) )
  ← profileInputs.activityKey         ( onb_v4_movement_baseline › activityLevel )
  ← energyBasis
       ← resolvedSafetyCap  ( safety_pace_cap › derived under18/bmi_low )
       ← CohortStore.isMaintenanceMode ( program_mode · onboarding_goal_direction )
       ← plan (start, goal, totalDays) AND planAgreesWithHer(onboardingGoalWeightKg)
       ← onboardingImpliedRate  ( her own numbers + onboardingPickedTier )
  ← CareProtocol.maxPlanRatePctPerWeek        (clinician ceiling)

PROTEIN TARGET  TargetsService.proteinTargetG
  ← resolvedWeightKg
  ← CohortStore.isGLP1Current     ( onboarding_glp1_status )   ← intentional
  ← CareProtocol.protein band + WeeklyReview.proteinAdjust

GOAL HORIZON  PlanSummary.horizonWeeks  (recomputed live)
  ← resolvedWeightKg · storedGoal · onboardingPickedTier
  ← ProgramGoalCalculator floors ( GLP-1 · perimenopause · sleep · trend )

PROGRESS  WeightJourney       ← plan.currentWeightKg (start) · resolvedWeightKg · storedGoal
TODAY NUTRITION              ← FoodLogPersister.allEntries filtered by day key. One sum.
JENI CONTEXT  CoachContextAssembler
  ← TodayStateService.snapshot ( the same object Home renders )
  ← PlanSummary                ( the same object the plan screen renders )
  ← the same read tools the surfaces' engines expose
```

### IF THIS INPUT CHANGES, WHICH OUTPUTS MUST CHANGE?

Pinned by `OneRecordTests` §5 as **propagation**, not implementation:

| edit | must move | pinned by |
|---|---|---|
| height | BMI floor → goal clamp → horizon → kcal → Home == Plan == Jeni | `testEditingHeightMovesEveryDependentSurfaceTogether` |
| sex | BMR constant → kcal on all three, **and jeni's `sex_term`** | `testEditingTheSexTermMovesEveryDependentSurfaceTogether` (delta pinned at **229**) |
| goal | distance → horizon → rate → kcal, **plan id and start date unmoved** | `testEditingTheGoalMovesTheDistanceOnEverySurface` |
| weight | kcal + protein floor + distance + trend | `RecordRepairTests` (`34`) |
| pace | horizon + rate + **the word jeni uses** | §9 + `RepairSurfaceTests` |
| a plate's day | that day's totals and the old day's | `testOnePlateCarriesTheSameSevenNumbersThroughEveryRepair` |

**Nothing caches a snapshot.** `TodayStateService` is stateless by
contract (*"no caching layer to go stale"*) and `CoachContextAssembler`
assembles per turn, so propagation is structural rather than a refresh
someone has to remember to call. **No legitimate dependent surface was
found stale** after the four fixes below.

**The one honest asymmetry, stated:** a *weight* change moves the live
horizon (`PlanSummary.horizonWeeks`, recomputed) but not the stored
`plan.totalDays` / `plan.goalDate`, which only a goal or pace edit
recomputes. That is deliberate — the plan keeps the window she committed
to — and it is invisible because **`plan.goalDate` is rendered on no
post-purchase surface.** Checked, not assumed.

---

## 3 · THE ONE-FACT GAUNTLET

Persona: 5'3" · 124 lb · goal 110 · female · 34 · medium · non-GLP-1,
and the GLP-1 variant. Each editable program-critical input taken
through fresh install → edit → Home → plan → Becoming → your numbers →
jeni envelope → sign out → sign in → clean-store restore.

| input | edit surface | survives sign-out | survives a clean store | degradation |
|---|---|---|---|---|
| WEIGHT | weigh-in · your weigh-ins · your numbers · chat | ✓ exact | ✓ exact | none |
| GOAL | goal ritual · Settings · your numbers · plan | ✓ exact | ✓ exact | none |
| HEIGHT | your numbers | ✓ exact | ✓ exact | none |
| SEX | your numbers | ✓ exact | ✓ exact | none |
| AGE | your numbers | **band** | **band** | **≤5 yr / ≤35 kcal, ≤14 yr at `55plus`; screen says `about N · approximate`** |
| ACTIVITY | your numbers | alias | alias | **0 kcal** (round-trip law, `30` §4); ambiguity stated on the row |
| PACE | your numbers · plan | ✓ exact | ✓ exact | none |
| MEDICATION STATUS | regimen home | ✓ (regimen chain) | ✓ | the *insulin* intake key is lost; its cap is named not derived (`35`) |

**Semantically identical in six of eight; the two exceptions are the
already-quantified age band and the already-stated activity alias.** No
new degradation was found, and none is hidden under the word "estimate":
both say so on the row that shows them.

---

## 4 · THE THREE 7/10 BOUNDARIES, INVESTIGATED

### 4A · JENI MEMORY — investigated in full, and NOT built

`JeniMemoryRecord`: `id · userId · topic · note · basis · createdAt ·
supersededAt`. Every field, classified:

| field | who writes it | when | user-authored? | expectation | sensitive? |
|---|---|---|---|---|---|
| `note` | **the user, through a confirm card** | only via the `remember` act | **yes, verbatim** | durable — Settings offers a per-row *forget* | **the most sensitive free text the product holds** |
| `topic` | the model, from a closed set of 5 | same | no | durable | no |
| `basis` | `told` \| `confirmed` — no third value exists on purpose | same | — | durable | no |
| `supersededAt` | the store, on a near-duplicate | write time | no | **conversational bookkeeping** | no |
| `createdAt` | the store | write time | no | durable | no |

**The four classes are not the same thing, and the contract must not
treat them as one:**

- **ACCOUNT FACT** — nothing in this store. Doses, diagnoses, symptoms,
  weights and body descriptions are refused **at the door** by
  `MemoryGuard`'s 40-marker ban list, so the table can never become a
  clinical record.
- **USER PREFERENCE** — the whole of it. *"doesn't eat before 11am"*,
  *"stop telling me to weigh in"*. This is what should sync.
- **CONVERSATIONAL MEMORY** — the transcript, §4B. Not this store.
- **EPHEMERAL INFERENCE** — **none.** There is no `basis: "inferred"`,
  by design. That is what makes the store safe to sync at all.

**Should it sync? Yes, and the smallest durable contract is `active`
notes only.** `supersededAt` rows are local bookkeeping that stops the
set drifting; shipping them to a server means shipping a history of what
she *used to* say about herself, which nobody asked for. **The minimum
contract is: id · userId · topic · note · basis · createdAt.**

Should it expire? **No.** A preference with a TTL is a coach who forgets
on a schedule, which is the defect the store was built to close.

Deletable? Already, per row and in bulk — and **as of this build the
device sweep honours it** (§12).

**Migration proposal — WRITTEN, NOT APPLIED, FOUNDER APPROVAL REQUESTED:**

```sql
-- NOT APPLIED. Additive. Mirrors weight_logs exactly.
create table if not exists public.jeni_memories (
  id          text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  topic       text not null check (topic in
                ('food','movement','schedule','coaching','life')),
  note        text not null check (char_length(note) between 4 and 140),
  basis       text not null default 'told' check (basis in ('told','confirmed')),
  created_at  timestamptz not null default now()
);
create index if not exists jeni_memories_user_idx
  on public.jeni_memories (user_id, created_at desc);
alter table public.jeni_memories enable row level security;
create policy "jeni_memories_select_own" on public.jeni_memories
  for select to authenticated using (user_id = (select auth.uid()));
create policy "jeni_memories_insert_own" on public.jeni_memories
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "jeni_memories_update_own" on public.jeni_memories
  for update to authenticated using (user_id = (select auth.uid()))
                              with check (user_id = (select auth.uid()));
create policy "jeni_memories_delete_own" on public.jeni_memories
  for delete to authenticated using (user_id = (select auth.uid()));
grant select, insert, update, delete on public.jeni_memories to authenticated;
```

- **Backward compatibility:** additive. A table no client references is
  inert. **The currently-shipping 1.2.0 (30) client is unaffected in
  every respect** — it neither reads nor writes this table and its
  `users` upsert is untouched.
- **Rollback:** `drop table public.jeni_memories cascade;` — no other
  object references it, and no client depends on it until the client
  ships.
- **Deployment ordering:** migration → *(old client: no change at all)*
  → new client adds upsert + insert-only hydrate + a real delete on
  *forget*. **This ordering is mandatory and it is not about cost:** a
  client that writes a table which does not exist gets a PostgREST 404
  per note, and a client that adds a column to the `users` upsert before
  its migration lands gets a **400 on the whole row**, breaking profile
  sync for every user (`31` §21). This table is separate from `users`
  precisely so the failure mode is bounded to the memory feature.
- **Account deletion:** covered by the `on delete cascade`, and the
  device half is fixed in this build (§12).
- **Can stale memory become dangerous?** The guard makes it impossible
  for it to be clinical. The residual risk is a *stale preference*
  ("stop asking me to weigh in") outliving its context, which is exactly
  what the per-row forget is for. That risk exists today, on device.

> **FOUNDER GATE: apply the migration above, then the client ships in
> the build after. Nothing is prepared here, because a client that needs
> an unapplied table is a loaded gun.**

### 4B · CHAT TRANSCRIPT — recommendation: **LOCAL ONLY**

| question | answer |
|---|---|
| Is it a medical-ish record? | **No, and it must not become one.** Every clinical fact has a provenance-stamped home; the transcript is the conversation *around* them. `VisitPacket` reads observations, not chat. |
| Merely convenience? | Largely yes: scrollback. |
| Does Jeni depend on it? | **No.** `ChatSession` sends a bounded recent window; the envelope is rebuilt from the record every turn. The compounding half is `JeniMemoryRecord`, deliberately extracted so the coach improves **without** the transcript. |
| Does losing it change recommendations? | **No.** Proven by construction: nothing in `CoachContextAssembler` reads `ChatMessageRecord`. |
| Privacy risk on restore? | **Yes, and it is asymmetric.** The transcript is the one place clinical language legitimately appears (`ChatSafety`'s crisis and ED routing sit on top of it). Syncing turns a device-scoped conversation into a server-stored one, and a shared or handed-down phone re-materialises it on any sign-in. |
| Does account deletion remove it? | Locally yes (2026-08-08). Server-side there is nothing to remove: `public.coach_messages` exists with RLS and grants and **zero client references** (`35` §9). |

**RECOMMENDATION: LOCAL ONLY, and delete `public.coach_messages`.** A
table with policies and no writer is a false contract that reads, to
anyone auditing the schema, as "we store your conversations". Nothing is
lost that the customer can name, and the one durable thing she *can*
name — what she asked Jeni to remember — is §4A. **Not built.** Per the
brief's own rule: the answer is not unambiguously SYNC.

### 4C · MANUAL MOVEMENT — classified honestly: **decorative history**

`MoveManualStore` — UserDefaults `move.manual.v1`, ≤400 entries, each a
kind + minutes + an estimate stamped at record time.

Traced every consumer:

| does it affect | answer |
|---|---|
| calories | **No.** There is no exercise compensation anywhere in the product, deliberately (`29` §3). |
| steps | No. `MovementService` reads HealthKit. |
| the program | No. No beat, no fact, no target. |
| the weekly review | No. Not an input to `WeeklyReadComposer`. |
| Jeni | **No.** `read_activity` reads `StepsService` only; the envelope carries no manual entry. |
| anything customer-facing | **Two things, both records of itself**: the Move tile's subtitle (`2 strength sessions in`) and `MoveSheet`'s own list. |

**So it is not a correctness defect.** It is a user-owned list she typed
and can delete, whose only derived consumer is a count of itself. On a
new phone it starts empty and the tile reads `what your body did`.
**Classification: LOST HISTORY, P2.** Recorded as a choice, not an
oversight.

---

## 5 · EXACT AGE — the minimum durable contract

The drift is real and unchanged: exact 34 → band `25to34` → representative
29 → **+35 kcal**, and up to **±14 years / ~70 kcal** in the unbounded
`55plus` band.

**What should the server store?**

| option | cost | privacy | ages correctly | verdict |
|---|---|---|---|---|
| `date_of_birth` | 1 column | **the most identifying of the three**; a DOB is a standard identity attribute and is not needed | ✓ | **REFUSE — more personal data than the product needs** |
| `birth_year` | 1 int | low; a year is coarse | ✓ automatically | **strong second** |
| `onboarding_age_years` | 1 int | lowest — it is exactly what she typed and nothing more | **✗ goes stale by one year each birthday** | **RECOMMENDED** |

**Recommendation: `users.onboarding_age_years integer`.** The staleness
objection is real and it is smaller than it looks: 5 kcal/yr against a
number the UI already labels an estimate, and the app already asks her
to confirm the row. **Storing a birth year to save 5 kcal a year means
storing an identity attribute for a rounding error** — the wrong trade
for a product whose standing law is *never collect more than the fact
you need*. If the founder prefers self-ageing, `birth_year` is the
choice; both are one additive column and the client change is identical.

- **Backward compatibility:** additive, nullable. Old clients ignore it.
- **The 2,941 existing users:** the column is NULL and every one of them
  keeps today's exact behaviour (the band). No backfill is possible and
  none should be attempted — inventing a year from a band is the
  fabrication class this whole line of work exists to remove.
- **Old client + new server: safe** (a column it never selects).
  **New client + old server: 400 ON THE WHOLE `users` ROW**, because the
  upsert sends every field. This is the ordering hazard, not a cost
  argument.

> **SEQUENCE: migration → verify applied → the client adds
> `onboarding_age_years` to `SupabaseUserUpsert`, the row decoder and
> `restoreBodyDefaults`. DO NOT APPLY. Not prepared here.**

**And the cheaper half, already available:** `users.program_mode`,
`users.goal_direction` and `users.medication_status` **already exist**
(migration 2026-07-03) with zero writers. If the founder's read-only
check returns three rows, that is a **client-only change with no
migration**, and it removes most of `35` §5.3's ask and makes the
`med_hypo` cap lossless. It is strictly higher value than the age.

---

## 6 · SEX AND ACTIVITY — the full lifecycle, proven

**SEX.** consult (`OV5Store` → `onboardingGender` + `onb_v5_gender`) →
`handleOnboardingComplete` → `UserRecord.onboardingGender` →
`SupabaseUserUpsert.onboarding_gender` → `users` → sign-out sweeps both
keys → sign-in `hydrateUser` → `restoreBodyDefaults` (clean-record
guard) → `@AppStorage` → `profileInputs` → BMR.

- **One vocabulary end to end**: `female · male · nonbinary · private`.
  `BodyFactsStore.setSex` **refuses anything else at the door** rather
  than silently storing it.
- **No default.** `profileInputs` maps an unrecognised or absent value to
  `.unspecified`, which runs the *conservative* constants and **says so
  on the row** — an assumption shown as an assumption.
- Editing on device B mirrors to `UserRecord`, sets `pendingUpsert`, and
  pushes; device A adopts on its next daily `refreshProgramTruth`
  because its own row is clean.
- Pinned: `testEditingTheSexTermMovesEveryDependentSurfaceTogether` —
  the delta is **229 kcal** and jeni's `sex_term` moves with it.

**ACTIVITY.** Same chain, with one honest lossy step: the raw answer
(`onb_v4_movement_baseline`) is swept and `UserRecord` carries only the
alias. **The round-trip law holds** — `activityFactor(raw) ==
activityFactor(alias)` for all four answers — so **0 kcal moves**. The
one unrecoverable case is a pre-2026-08-14 account whose only surviving
value is the collapsed `moderate`, and the row states what the math is
using and names the other answer it could have been.

**[CORR] One consent fact does NOT complete its lifecycle.**
`consent_grants` has an **upsert and no hydrate** — there is no
`hydrateConsentGrants` anywhere. `34`'s sync table lists consent grants
as **EXACT**; they are not. On a new device `ConsentService.activeGrant`
returns nil while the server row still says granted, so the
visit-packet toggle reads **off**, `WeeklySummaryPublisher` stops
publishing, and — the part that matters — **`revoke()` no-ops, because
it needs a local active grant to revoke.** She cannot withdraw, from a
new phone, a consent the server still honours. Fail-safe for new
sharing, wrong for withdrawal. **Population: clinic-pilot patients
only.** Named, not fixed: the fix is a new hydrate + DTO inside
`Packages/PlankSync`, a protected path, for a pilot cohort on a frozen
candidate. **P1 for the care platform, P2 for the consumer product.**

---

## 7 · NUTRITION — SHIPPING vs BRANCH, PROVEN NOT ASSUMED

Four distinct things, and `36` conflated two of them.

| | SHIPPING CLIENT (1.2.0 / 30 = `1710180`) | BRANCH CLIENT |
|---|---|---|
| decoder | 7 nutrients, all Optional | **+ 8 label fields decoded** |
| `read_mode` | not sent | **sent** (`"label"`) |
| `PlateShare` | **absent** | present |
| micros used | USDA only, gated by `publishesMicros` | **identical** |

| | SHIPPING EDGE FUNCTION | BRANCH EDGE FUNCTION |
|---|---|---|
| label branch | **none** — the hint rides `text` into the plate prompt | `buildLabelPrompt()`, transcription |
| serving semantics | none in the schema | `serving_size_text`, `servings_per_container` |
| FDA micros | none | `added_sugars_g`, `vitamin_d_mcg`, `calcium_mg`, `iron_mg`, `potassium_mg` |
| `is_nutrition_label` | none | present |

### **[CORR] The four FDA micros would NOT reach a customer if the EF were deployed today.**

`36` scores NUTRITION ACCURACY 7 with the reason *"the four FDA label
micros are written into the EF and not deployed, so a photographed
nutrition panel still returns less than it prints"* — which reads as
*deploy and it is closed*. **It is not.** `VisionResponse.Item` decodes
all five micro fields, and `FoodVisionService.map()` **uses exactly one
of the eight new fields** (`servings_per_container`, as a fallback for
`servingsInDish`). `CapturedItem` has no field for a model-declared
micronutrient; `micros` is `CalorieMathService.Micronutrients`, filled
only from USDA. **The micros are decoded and dropped on the floor.**

So deploying the EF changes exactly two things for the branch client:
the label prompt becomes deterministic transcription, and a packaged
food's serving count reaches `PlateShare`'s ladder. **Both are real and
both are worth having. Neither is a micronutrient.** Closing NUTRITION
ACCURACY needs the EF deploy **and** a client change that carries the
declared micros into `CapturedItem` and past `publishesMicros`. Named,
sized, not built.

### Per nutrient, end to end

| nutrient | prod EF returns | prod persists | branch reads | manual edit keeps | repeat keeps | day move keeps | delete removes | Home totals | THE BOOK | jeni |
|---|---|---|---|---|---|---|---|---|---|---|
| calories | ✓ | `kcal_total` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| protein | ✓ | `protein_g` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| carbs | ✓ | `carbs_g` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| fat | ✓ | `fat_g` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| fiber | ✓ | `fiber_g` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| sugar | ✓ | `sugar_g` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| sodium | ✓ | **`payload` jsonb** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### ONE PLATE, SEVEN NUTRIENTS — pinned

`testOnePlateCarriesTheSameSevenNumbersThroughEveryRepair`: one
deterministic plate (640 · 42 · 55 · 22 · 9 · 12 · 880) → persisted →
read back through **`read_food_day`** → re-dated to another day → read
again → repeated. **The seven integers are identical at every step**,
the old day is empty rather than duplicated, and the repeat carries the
corrected numbers rather than a fresh guess. **No recalculation drift.
No unit drift. No second estimate over a correction.**

---

## 8 · THE DEPLOYMENT COMPATIBILITY MATRIX

Every behaviour difference in `supabase/functions/food-vision/index.ts`
(+124 / −3 vs `1710180`), classified:

| change | class |
|---|---|
| `buildLabelPrompt()` — the panel is transcribed, not estimated | **P0 correctness** — today the plate prompt says *"kcal is your MIDPOINT for the WHOLE visible food"* while the hint says *"per serving"*, and nothing records which the model chose |
| `servings_per_container` + `serving_size_text` | **P1 utility** — makes `PlateShare` exact on packaged food |
| `is_nutrition_label` | P1 — lets the app know it photographed a sandwich |
| four FDA micros + `added_sugars_g` | **DEAD ON ARRIVAL until a client change** (§7) |
| `read_mode` accepted | P2 — the explicit form of a signal that already works |

|  | **OLD EF** | **NEW EF** |
|---|---|---|
| **OLD CLIENT** (1.2.0 / 30, live) | **SAFE** — today | **SAFE BUT DEGRADED.** Build 30's label door *does* send `"this photograph is a nutrition facts label…"`, so the new EF takes the label branch for it. A 4-serving package then returns ONE SERVING deterministically, and build 30 has **no `PlateShare` stepper and no `servings_per_container` reader** — so it undercounts, silently, with only fix-with-words to repair it. Under the old EF the same shot was *indeterminate*. |
| **NEW CLIENT** (this branch) | **SAFE** — every new field is Optional and decodes nil; `read_mode` is ignored | **SAFE and better** — deterministic per-serving transcription, and `servings_per_container` → `servingsInDish` → the share ladder |

**Three cells safe, one degraded. The required order is therefore:
CLIENT FIRST, EF SECOND** — the reverse of the assumption this deploy
has been sitting under. Ship the branch (which has `PlateShare`), let it
reach the installed base, then deploy. **DO NOT DEPLOY.** Nothing was
deployed.

---

## 9 · JENI IS NOT ALLOWED TO HAVE A PARALLEL TRUTH

Audited `CoachContextAssembler` and all 8 read tools + 12 acts for an
independent ladder.

| fact | UI resolver | jeni's resolver | verdict |
|---|---|---|---|
| calorie target | `TargetsService.current` | the same object | ✓ structural |
| protein | `TargetsService.proteinTargetG` | the same | ✓ |
| goal | `PlanSummary` | the same (`35`) | ✓ |
| missing input | `TargetsService.missingEnergyInput` | the same (`35`) | ✓ |
| program day / plan | `TodayStateService.snapshot` | the same | ✓ |
| food totals | `FoodLogPersister` | the same | ✓ |
| dose / last shot / next shot | `MedicationScheduleEngine` | the same | ✓ |
| symptoms | `SideEffectLog` | the same | ✓ |
| **current weight** | `PlanSummary.currentKg` | **`snapshot.latestWeightKg` — A SECOND LADDER** | **FIXED** |
| **pace** | `IntensityTier` → a word, in **three view files** | **the raw stored value** | **FIXED, one authority** |
| **a day word** | `WeightLedger` · `SymptomLedger` | `DoseLedger` — a third copy, one rule short | **FIXED** |
| **injection site** | `SiteRotationAdvisor` · `DoseLedger` | **no payload at all** | **FIXED** |

**Every duplicated resolver found was small, and every one was removed.**
The pace word had **three** authorities that agreed only because someone
kept editing all three; `36` corrected a fourth vocabulary by editing one
of them, which is a fix with a half-life.

---

## 10 · JENI AS A COMMAND LINE — the closed matrix

**U**nderstands · **R**eads the correct fact · **A**nswers ·
**O**pens the door · **M**utates · **S**afe · **D**eploy needed.

| the sentence | U | R | A | O | M | S | D |
|---|---|---|---|---|---|---|---|
| "what did I eat yesterday?" | ✓ | ✓ `read_food_day` | ✓ | ✗ | — | — | — |
| "how much protein do I have left?" | ✓ | ✓ envelope | ✓ computed once | — | — | — | — |
| **"what was my weight last Tuesday?"** | ✓ | **✗ [CORR]** | **partly** | ✗ | — | — | — |
| "show my weigh-ins" | ✓ | ✓ | ✓ names the door | **✗** | — | — | **yes, a new NAME** |
| "show my meals" | ✓ | ✓ | ✓ names the door | **✗** | — | — | **yes, a new NAME** |
| "why is my target 1,282?" | ✓ | ✓ `targets.inputs` | ✓ | ✓ `doors.your_numbers` | — | — | — |
| "change my goal to 115" | ✓ | ✓ | ✓ explains | ✓ names the door | **✗** | — | **yes, a new NAME** |
| "I weigh 121.4 today" | ✓ | ✓ | ✓ | — | ✓ `log_weight` | ✓ card | — |
| "that weight was wrong" | ✓ | ✓ | ✓ | ✓ `doors.weigh_ins` | ✗ | — | a new NAME |
| **"I forgot dinner yesterday"** | ✓ | ✓ | ✓ | ✓ | **✗ lands on TODAY** | — | **NO — see below** |
| "when was my last shot?" | ✓ | ✓ | ✓ | ✓ `open_dose_sheet` | — | — | — |
| "what dose was I on two weeks ago?" | ✓ | ✓ eras | ✓ | ✓ | — | — | — |
| **"where did I inject last?"** | ✓ | **✗ → ✓ FIXED** | **✓ now** | ✓ | — | — | **no** |
| "I felt nauseous Tuesday" | ✓ | ✓ | ✓ | ✗ | ✗ deliberate | — | a new NAME |
| "that symptom was actually Wednesday" | ✓ | ✓ | ✓ | ✗ | ✗ deliberate | — | a new NAME |

### **[CORR] Two rows the previous records got wrong**

1. **"where did I inject last time?"** — `33` and `34` both mark this
   answered by `read_dose_history`. The tool returned the compound, the
   route, the eras and a **status tally**; the site appeared in no
   payload. **Fixed this session** (§11), payload-only, zero deploy.
2. **"a past weigh-in — READ ✓"** (`36` §6). `read_weight_trend` returns
   the smoothed trend, the direction, the count and the latest value —
   **never an individual row**. `your weigh-ins` lists them on screen and
   no tool reads them, so *"what did I weigh last Tuesday"* is answerable
   only as a trend. Named, not built: it wants a day argument and a
   decision about how far back a coach should quote a single number.

### **THE FINDING THAT CHANGES WHAT IS BUILDABLE**

The jeni-chat allowlist gates **names**. Read `sanitizeTools`: it checks
the name against `ALLOWED_TOOL_NAMES`, checks that `description` is a
string ≤1200 chars and that `parameters` is an object — **and then
forwards both verbatim.** So **a new PARAMETER on an existing tool, and
a rewritten description, need no deploy.** Four records have carried
"new tool = deploy" (true) without ever stating the corollary.

That makes *"I forgot dinner yesterday"* a **one-step, no-deploy**
change: `log_food_text` gains `days_ago`. It is **not built**, because it
is a new way to CREATE a back-dated food row on a frozen candidate, and
three sessions have deliberately deferred that write path. **Named with
its new cost, which is lower than anyone thought.**

**No conversational magic was added.** The shape stays: answer → the
exact door → the existing editor. Jeni still never marks a dose, never
edits a symptom, and never writes a weight without a card.

---

## 11 · ONE VOCABULARY

| WE CALL IT | NOT | state |
|---|---|---|
| weight · weigh-in | — | one word each |
| **your weigh-ins** | the weight log · weight history | one name |
| goal weight | target weight · goal | one name (Settings row states the number) |
| **pace** — `gentle · steady · strong` | `soft/medium/hard` (storage) · `quick` | **ONE AUTHORITY as of this build.** The consult's `focused` stays: pre-purchase funnel, out of scope, one word in one place, stated |
| plan | program | both used; `plan` is the customer noun, `program` names the day count (`day 27`). Distinct concepts, kept |
| calorie target · calories left | budget · allowance | one |
| protein target / floor | — | one |
| **your plates** (THE BOOK) | food journal · food log · diary | **ONE NAME as of this build.** `keep with my journal` in Settings › food was the last holdout |
| meal · plate | — | `plate` is the record's noun, `meal` the conversational one; no concept split |
| **the doses** · **dose changes** | the record | split into two headings by `33` |
| shot · dose | — | `dose` is the record's noun; `shot` only where she says it. A pill is never a shot |
| medication · regimen | — | `medication` is the customer noun; `regimen` names the version chain |
| **the symptoms** · side effect | — | `side effect` is the thing, `the symptoms` is the list |
| history · record | — | `your record` is the Becoming section; each list names itself |
| Jeni Method | the lessons · the curriculum | one — and it is the 15 rule-based notes |

**Two remaining splits, both recorded as choices rather than fixed:**

1. **`your plates` / `your weigh-ins` vs `the doses` / `the symptoms`** —
   four peer record lists, two naming conventions. It is `33`'s and
   `36`'s deliberate placement (the shot log belongs beside the plan it
   documents, and `the X` reads correctly inside the regimen home where
   `your X` reads correctly inside `your record`). Renaming shipped copy
   on taste is not this session's call.
2. **the consult's `focused` vs the product's `strong`** — funnel, P2
   since `32`.

**The customer never has to learn the codebase's history.** `soft`,
`medium`, `hard`, `walks`, `regular_ish`, `athlete`, `25to34` and
`weeklyAnchor` are storage and appear on no surface — now pinned by
`testNoStoredTierValueIsEverACustomerFacingWord`.

---

## 12 · DEAD PRODUCT WEIGHT — verified, and one removal

All four claims re-verified **from call sites**, not inherited:

| claim | verdict |
|---|---|
| 14-lesson `LessonID` corpus unreachable | **TRUE.** `JeniMethodReReadView` is wired into `ProfileHubView`'s route switch (`:493`) and **no row navigates to `.jeniMethod`**. Its other reader is `DebugAuthView`. |
| 84-day CBT manifest unreachable, parsed every launch | **TRUE, and the launch cost was real.** Its only production reader is `RepEngine`; the two hosts that present `LessonReaderView` (`CBTQACoverHost`, `DebugAuthView`) are inside `#if DEBUG`. |
| `RepEngine` zero call sites | **TRUE.** Two comment mentions, no code. |
| the 15 live notes are the Method | **TRUE.** `open_lesson` → `AppRouter.open(.lesson)` → `HomeView.openMethodDoor()` → `MethodEngine`. **It does not reach the corpus.** |

**Before deleting anything, proven no reference exists from:** a deep
link (`AppRouter.open(_ raw:)` has no lesson-corpus route), a
notification (`NotificationOrchestrator`'s ids are the ladder, JITAI and
re-signing knock), a Jeni tool (`open_lesson` routes to the notes), a
widget (`JenifitWidgets` contains only the scan Live Activity), a test,
a migration, or an old persisted identifier
(`jenimethod.last_lesson_completed_id` is read by `ProfileHubView` and
`DebugAuthView` for a count, not to resolve content).

**REMOVED — the dead runtime work, and only that:**

```swift
// PlankAIApp.init — deleted
Task.detached(priority: .background) {
    _ = CBTCurriculumService.shared.manifest()   // 442 KB of JSON
}
```

Every customer paid a background JSON decode **on every launch, in
Release**, to warm a cache nothing reads. The service still memoises on
first access, so the day a reader is wired up it costs exactly what it
costs. **No content deleted, no file moved, no bundle change.** The
corpora themselves are a cleanup pass with its own build, and the
evidence is now written down three times.

**Also fixed here, and it is the P0 of this session:**
`clearLocalUserData` gained `JeniMemoryRecord`, `ProgramFactRecord` and
`WeeklyReadRecord`. §16.

---

## 13 · ONE DESIGN SYSTEM

Grammar extracted from the anchors (onboarding · Home · Becoming ·
camera) and the three record screens. **Anchors not touched.**

| element | the grammar |
|---|---|
| PAGE TITLE | lowercase serif masthead, left, no `navigationTitle` |
| SECTION TITLE | lowercase DMSans eyebrow above a hairline |
| BODY / CAPTION | DMSans; caption is tertiary grey, never colour-coded |
| NUMBER | serif, `lineLimit(1)`, **never wraps at any size** |
| UNIT | beside the numeral, stacks below it from `xxxLarge` |
| ROW | label over value from `xxxLarge`; no card around a list |
| DIVIDER | hairline, `Palette.divider`; never a system separator |
| PRIMARY CTA | one ink capsule, pinned with its hairline |
| SECONDARY CTA | bare text, no border |
| DESTRUCTIVE CTA | quiet text **below** the CTA pair, never beside it |
| EMPTY STATE | one or two sentences: what it is · what lands here |
| EDITOR | a page swap inside the sheet, never a sheet inside a sheet |
| HISTORY PAGE | masthead · `xmark` · dated rows newest first · footnote |
| DAY PICKER | expands in place, 14 days, never forward |
| FULL-SCREEN DETAIL | `fullScreenCover` or `.large` |
| SMALL SHEET | `JeniSheetHeight.brief` / `.tall`, one question |

Mechanical sweep re-run: **zero `Form`, zero `List`, zero
`navigationTitle`** outside the anchors. The detent inventory (`36` §9)
re-checked and unchanged: **no content-heavy screen opens at half
height.** Close controls agree — the two record pages both use `xmark`,
every editor closes with `done`.

**Two consistency fixes, both real, neither a redesign:**

1. **`the doses` and `the symptoms` sit in one frame and spoke two day
   grammars.** A shot marked this morning read `aug 14` while the list
   directly beneath it read `today` for a symptom logged at the same
   moment. `DoseLedger` was the first of the three ledgers written and
   never got the `today`/`yesterday` branch its siblings have — nor the
   time-zone line, which `34` found in `WeightLedger` and `36` wrote into
   `SymptomLedger` on the way in. **Both rules now hold in all three.**
   (Production impact of the zone half is nil today, because
   `Calendar.current.timeZone == TimeZone.current`; its value is that the
   rule is now true by construction and testable. Stated rather than
   dressed up.)
2. **`keep with my journal` → `keep with my plates`** — the last
   customer-facing string calling the food record by a name no other
   surface uses, on a **privacy** setting, where reading it as a
   different record is the worst place to be confused.

**No third fix was made.** Nothing else met the bar, and the brief says
a finding may remain a finding.

---

## 14 · ACCOUNT TRANSFER — the real test

DEVICE 1 (30 days of food, weight, a goal edit, height, activity, pace,
dose events, a dose change, sites, symptoms, units, memory, chat, manual
move) → sync → sign out. DEVICE 2, clean store → sign in → hydrate.
Traced through all fifteen hydrate families and re-measured against this
build.

| fact | EXPECTED | ACTUAL | LOSS | DEGRADATION | USER-VISIBLE EFFECT |
|---|---|---|---|---|---|
| height · weights · goal · sex | exact | exact | — | — | — |
| **age** | 34 | band → 29 | the year | **≤35 kcal** | `about 29 · approximate`, one tap to fix |
| activity | raw | alias | the raw word | **0 kcal** | the ambiguous row states both readings |
| GLP-1 · hormonal · sleep · trend · stress · food relationship | exact | exact | — | — | — (`35`) |
| safety pace cap | the gate's verdict | derived for `under18` + `bmi_low` | pregnancy · ED · insulin | **partial** | no deficit published either way |
| numeric suppression | true | **false** | all of it | **missing** | weight numerals return; **no calorie numeral either** |
| program mode / goal direction | on file | **absent** | both | **missing, handled** | one plain question |
| plan · units · pace | exact | exact | — | — | — |
| weigh-ins **+ deletions** | exact | exact | — | online only | a delete made offline returns |
| food + photos + corrections + a plate's day | exact | exact | — | — | — |
| day checks · reflections · weekly reads · sessions | exact | exact | — | — | — |
| regimen chains · dose events **+ site** | exact | exact | — | — | — |
| observations **+ the clear** | exact | exact | — | — | — (`36`) |
| **visit-packet consent** **[NEW]** | granted | **absent locally** | the local grant | **✗ BROKEN** | **the toggle reads off and she cannot revoke** |
| steps / sleep | HealthKit | HealthKit | — | — | Apple's |
| body scans | local, backup OFF | **empty** | all | by design | **unstated on the surface** |
| **jeni memory** | listed as durable | **empty** | all | **missing** | *"what jeni remembers"* starts at zero |
| **chat transcript** | on device | **empty** | all | missing | scrollback gone |
| **manual move entries** | on device | **empty** | all | missing | the Move tile drops to `what your body did` |

**The restored account answers the same boring questions** — what did I
eat · how much · what is my target · what did I weigh · when did I gain ·
what is my goal · how far am I · when was my shot · what dose · where did
I inject · did I skip · what symptoms — **all twelve.** The four losses
are the four named above, and three of them are things she typed to the
coach rather than facts about her body.

---

## 15 · TWO DEVICES

**The current contract, documented BEFORE any judgement of it.**

`upsertUser` and `upsertProgramPlan` send **the whole row**. `hydrateUser`
and `ProgramPlanMerge` skip a record whose `pendingUpsert` is true.
There is **no per-field dirty tracking and no trustworthy `updated_at`**
on either table.

> **THE CONTRACT: LAST WRITE TO REACH THE SERVER WINS, AT ROW
> GRANULARITY.** "Last" is not wall-clock. A goal edited offline three
> days ago beats one edited online five minutes ago, because the offline
> device pushes when it reconnects.

### The scenarios, run

| scenario | result |
|---|---|
| A offline edits goal · B logs a weight · A reconnects | **both survive.** The weigh-in is append-only and id-keyed; the plan row is A's. |
| A edits goal 115 offline · B edits goal 112 online · A reconnects | **115 wins**, and B adopts it on its next daily refresh because B's row is clean. Deterministic, and it is *whoever pushed last*, not *whoever decided last*. |
| A edits her goal · B edits her height, both online | **both survive** — different tables, and `users` merges on the clean-record guard. |
| **food edit vs food delete** | **THE DELETE LOSES.** See below. |
| weight edit vs weight delete | the server row goes and A is correct; **B keeps a ghost row locally forever** (`applyHydratedWeightLogs` is insert-only and nothing re-pushes it). |
| dose correction vs dose correction | deterministic ids per slot, so it is a plain last-write-wins on one row. No duplicate. |

### **[NEW] A PLATE DELETED ON ONE DEVICE COMES BACK, WITH NO OFFLINE INVOLVED**

`AppSync.pushLocalFoodEntriesMissingFromServer` runs on **every launch,
for every user**, and re-uploads any local entry whose id the server does
not hold. `FoodLogPersister.mergeRemote` is insert-only.

So: **A deletes a plate → the server row goes → B launches, sees its own
local copy missing from the server, and re-uploads it → A's next hydrate
pulls it back.** No offline step, no race window: it is the steady state.

This is strictly worse than the limitation `34` recorded ("a record
deleted **offline** still returns"), and it was not previously named.

**Why it is named and not fixed:** device B cannot distinguish *"the
server never received this row"* from *"the server deleted this row"*
without a **tombstone**, and a tombstone is a schema change. A local
deleted-ids list would help only the device that did the deleting, which
is not the device causing the resurrection. **The architecture cannot
represent deletion today, and this document says so rather than hiding
it under last-write-wins.** P1 for a two-device customer, P3 by
population.

---

## 16 · PRIVACY / DELETION

| record | server cascade | explicit delete | orphan possible | local copy cleared |
|---|---|---|---|---|
| `users` | ✓ `auth.users` cascade | — | no | ✓ |
| `program_plans` | ✓ | — | no | ✓ |
| `weight_logs` | ✓ | ✓ `deleteWeightLog` | no | ✓ |
| `food_logs` + photos | ✓ + the RPC deletes the bucket objects | ✓ | no | ✓ (JSONL) |
| `dose_events` | ✓ | ✓ | no | ✓ (`ObservationStore.deleteAll`) |
| `regimen_plans` | ✓ | — | no | ✓ |
| `observations` | ✓ | ✓ (`36`) | no | ✓ |
| `program_facts` | ✓ | — | no | **✗ → ✓ FIXED** |
| `weekly_reads` | ✓ | — | no | **✗ → ✓ FIXED** |
| `consent_grants` | ✓ | — | no | ✓ |
| body data (`body-scans` bucket) | ✓ (pre-RPC + the RPC's own DELETE) | ✓ | no | ✓ |
| chat transcript | n/a — `coach_messages` has zero writers | — | n/a | ✓ |
| **jeni memory** | n/a today; the §4A proposal cascades | ✓ per row | n/a | **✗ → ✓ FIXED** |
| `food_vision_telemetry` · `jeni_chat_telemetry` | `on delete set null` | — | **no — deliberate anonymisation** | n/a |
| **`care_weekly_summaries`** | **NO FOREIGN KEY AT ALL** | **none — the RLS has no delete policy on purpose** | **YES** | n/a |

### **P0 PRIVACY DEBT, NAMED: `public.care_weekly_summaries` orphans**

```sql
create table if not exists public.care_weekly_summaries (
  id       text primary key,
  user_id  uuid not null,        -- ← no references, no cascade
  org_id   uuid not null,
  payload  jsonb not null,       -- ← a week of her record
  ...
);
```

Every other user-owned table in the schema carries `references
auth.users(id) on delete cascade`. This one does not, and its policy set
deliberately has **no delete policy** (*"history is append-only for
everyone at the policy layer"*). So a connected patient who deletes her
account leaves **her uuid and a jsonb payload of her week behind,
permanently, reachable by no credential and removable by no client.**
`care_audit_events.patient_id` is the same shape; an audit trail
arguably should outlive the row it audits, but it should be a stated
decision, not an omitted constraint.

**Population: clinic-pilot patients only** (the writer is
`WeeklySummaryPublisher.publishIfConnected`, gated on an active
consent). **This is a migration and it is founder-gated. Nothing was
changed. Nothing was executed.** Recommendation: add the FK with
`on delete cascade` (or, if the summaries must outlive the account for
clinical continuity, drop `user_id` to a pseudonymous key and say so in
the consent copy).

**And the local half, FIXED here:** three families the 2026-08-08 sweep
predates.

---

## 17 · WHAT WAS BUILT

**One P0 privacy fix (the brief's own exception), three correctness
fixes, two consistency fixes, one dead-runtime removal.**

### P0 · DELETE MEANS DELETE

`AppSync.clearLocalUserRecords` (extracted as a pure static over
`(userId, context)` so the sweep a test drives **is** the sweep the
product runs, never a list copied into a fixture) now also removes
`JeniMemoryRecord`, `ProgramFactRecord` and `WeeklyReadRecord`.

All three post-date the 2026-08-08 audit that closed this exact hole for
chat and weights. `JeniMemoryRecord` is the one that matters: free text
she typed, presented in Settings as hers with a per-row forget, surviving
the deletion she asked for on disk and in every device backup afterwards.
Server-side all three already cascade. **No schema, no server change.**

### FIX 1 · One weight ladder, and the coach is on it

`CoachContextAssembler` published `weight.current_kg` from
`snapshot.latestWeightKg` — the **raw weigh-in row**. For a woman who
told the consult what she weighs and has not opened the scale, the
envelope carried **no weight at all**, while `your numbers` rendered
`weight today · 124 lb` and Home priced her day from it.

Worse: `to_go_kg` two lines below **does** resolve through the ladder, so
the payload answered *"how far am I"* from a number it refused to state.

It reads `summary.currentKg` now — the object every screen is made of.
`35` fixed this exact ladder one field down (`missingEnergyInput`) and
left this one. **Every existing envelope test seeds a weigh-in first,
which is why four passes missed it**; the new tests deliberately do not.

### FIX 2 · One pace word, with one authority

`IntensityTier.paceWord`. The same three-case mapping lived in
`HomeView`, `JKPlanNumbersSheet` and `ProgramSetupSubflow`, and the coach
was handed the **raw** `medium`. Every screen said `steady`; jeni said
`medium`; the fact decides her deficit and her horizon.

Three copies collapse to one call each; the envelope publishes
`inputs.pace = "steady"` and no longer ships `pace_tier`. **Not one
stored value changed**, so nothing about an installed account moves.

### FIX 3 · The coach can say where she injected last

`read_dose_history` gains `last_site` (her words, via
`DoseLedger.siteWord`) and `last_site_day`. Taken doses only, absent when
there is none — an oral regimen must not acquire an injection site by
omission. The tool's description gains the question and one refusal
(*never tell them which site to use next*).

**Payload only. Zero Edge Function deploy** — and this session proved the
stronger form of that rule: `sanitizeTools` forwards `description` and
`parameters` verbatim, so only NAMES are gated.

### FIX 4 · One day grammar across the three record lists

`DoseLedger.dayWord` gains `today`/`yesterday` and
`f.timeZone = calendar.timeZone`. §13.

### FIX 5 · One name for the food record

`keep with my journal` → `keep with my plates`. §13.

### REMOVED · The launch-time CBT manifest decode

§12.

---

## 18 · RED → GREEN

`plankAITests/OneRecordTests.swift`, **17 tests.** Every one is a
customer promise.

With the four cores reverted to their pre-session behaviour:

```
Executed 15 tests, with 17 failures (0 unexpected)
** TEST FAILED **     exit 65
```

**8 of 15 red.** Then the two dose-site tests, proved separately (the
field did not exist, so they could not be part of the first RED):

```
Executed 17 tests, with 2 failures (0 unexpected)
** TEST FAILED **     exit 65
```

| test | RED |
|---|---|
| `testTheCoachStatesTheWeightTheScreensState` | ✗ `nil` vs `56.2` |
| `testTheCoachNeverPublishesADistanceWithoutTheWeightItMeasuredFrom` | ✗ |
| `testTheCoachIsToldThePaceWordTheScreensShow` | ✗ `nil` vs `steady`, and `pace_tier == "medium"` |
| `testTheThreeRecordListsSpeakOneDayGrammar` | ✗ `aug 14` vs `today`, `aug 13` vs `yesterday` |
| `testTheDoseDayWordInheritsTheCalendarTimeZone` | ✗ 4 assertions, incl. `aug 10` for `2026-08-11` |
| `testADoseRowSpeaksTheDayItDraws` | ✗ 2 assertions |
| `testDeletingTheAccountLeavesNoRecordOfHerOnThisDevice` | ✗ memory, facts, reads all survived |
| `testDeletingOneAccountLeavesTheOtherAccountUntouched` | ✗ |
| `testTheCoachCanSayWhereSheInjectedLast` | ✗ (second run) |
| **`testAnAbsentSiteIsSilentAndNeverInvented`** | **passed** |
| the four controls and the propagation pins | **passed** |

**The refusal-test lesson, for the fourth session running.**
`testAnAbsentSiteIsSilentAndNeverInvented` asserts that an absent site
does not appear, and **a stub that returns nothing satisfies it.** It
cannot tell *"refused for the right reason"* from *"cannot do anything at
all"*, which is exactly why the test beside it exists. `34`, `35` and
`36` each recorded this; it is now four for four.

### A test defect this session found in its own work

`testEditingTheSexTermMovesEveryDependentSurfaceTogether` first asserted
the delta was `166 × 1.375 = 228`. The product returned **229**, and the
product was right: `dailyTarget` rounds TDEE to a whole calorie **before**
the deficit comes off (1693 → 1922), and `CalorieGoldenMatrixTests`
already pins both ends of this persona at 1,282 and 1,511. **The
expectation was wrong, not the arithmetic** — the same trap
`OneTargetEverywhereTests` records in its own file, hit again by
skipping the intermediate rounding.

### And a defect the PRODUCT'S OWN GUARD found in mine

The full suite failed once, on `JeniToolsTests
.testEveryToolHasAWireFormWithASchema`:

```
read_dose_history's description carries an em-dash (voice law)
```

I had written an em-dash into the tool description. **A pre-existing
test caught new copy breaking a standing voice law** before it could
reach a prompt. Fixed in the copy, not in the test.

---

## 19 · PROOF

Every command run **serially**, unpiped, `$?` captured directly
(`32` §13 — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests` (baseline, before any edit) | 1242 | **1242** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests/OneRecordTests` | 17 | **17** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` | 1259 | **1259** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` (from the package dir) | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` (from the package dir) | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.9 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.** The baseline was **re-measured at the
start of this session rather than inherited**, and it matched `36`'s
1242. App suite **+17**, which is exactly `OneRecordTests` and nothing
else: **no existing test changed and none needed to.**

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **86 MB, 123,625 strings** —
size and total stated first, because *a zero from a file that does not
exist is the `Executed 0 tests` trap in different clothes* (`35`).

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `persona-customer` · `persona-autym` | **0 · 0** |
| `debug-weigh-ins` · `debug-plate-day` | **0 · 0** |
| `debug-regimen-record` · `debug-symptom-day` | **0 · 0** |
| `uitest-cbt-lesson` | **0** |
| `keep with my plates` | **1** — the new copy is in the shipping binary |
| `where they injected last` | **1** — the new tool description ships too |

*(A note on method: Swift stores literals of ≤15 UTF-8 bytes inline in
the `String` struct, so short new keys like `last_site` are invisible to
`strings` by construction. The two long literals above are the ones that
prove the change shipped; the short ones are proven by the test suite.)*

### Protected paths vs the reviewed release `1710180`

| path | diff |
|---|---|
| `PlankApp/Payment` · `Views/Paywall` · `Auth` | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** |
| `supabase/migrations` | **EMPTY** |
| `PlankApp/Analytics` | `31`'s +6 allowlist lines. **This session: EMPTY.** |
| `Packages/PlankSync` | `31` + `34` + `36`. **This session: EMPTY.** |
| `Packages/PlankFood` | `26`/`27`/`34`. **This session: EMPTY.** |
| `supabase/` | `27`'s food-vision EF, written and NOT deployed. **This session: EMPTY.** |

**Zero files under `Packages/`, `supabase/` or `PlankApp/Analytics` were
touched this session** — measured by mtime against the session boundary,
not asserted.

**All three files in the repository that declare a `@Model`**
(`PlankSync/Models.swift`, `Chat/ChatModels.swift`, `Chat/JeniMemory.swift`)
have a **zero diff against `1710180`**, re-derived this session with
`grep -rlE "^\s*@Model"` rather than inherited. **There is no SwiftData
store migration to fail.**

The `project.pbxproj` diff vs `1710180` contains **only file
references** — verified by filtering the diff for anything that is not a
`PBXBuildFile` / `PBXFileReference` line and getting an empty result.
`CURRENT_PROJECT_VERSION` is still **30** and `MARKETING_VERSION` still
**1.2.0**; the archive-time bump to **31** stands and is the founder's
step.

### This session's files — thirteen

`Sync/AppSync.swift` · `Chat/CoachContextAssembler.swift` ·
`Chat/JeniReadTools.swift` · `Chat/JeniToolCatalog.swift` ·
`Program/IntensityProfile.swift` · `Program/DoseLedger.swift` ·
`Views/Home/HomeView.swift` · `Views/Program/JKPlanNumbersSheet.swift` ·
`Views/Program/ProgramSetupSubflow.swift` ·
`Views/Settings/FoodSettingsView.swift` · `PlankAIApp.swift` ·
`plankAITests/OneRecordTests.swift` (new, 17) · `project.pbxproj` (one
file reference) · this document.

**No new DEBUG door was added.**

---

## 20 · THE TWENTY ANSWERS

**1 · DOES JENI NOW HAVE ONE RECORD OF THE CUSTOMER?**
**YES on this device, NO across devices.** Every fact she can see has one
authority, one resolver and one vocabulary, and the coach is on the same
ladders as the screens for the first time. Across an account transition
four things she reasonably owns still do not follow her: her coach's
memory, her transcript, her manual movement, and (for clinic patients)
her sharing consent.

**2 · WHAT FACT STILL HAS MORE THAN ONE AUTHORITY?**
**None that a customer can reach.** The four found this session are
fixed. What remains is one *derived* value with two computations, both
correct and only one of them rendered: the horizon (`plan.totalDays`,
stored, vs `PlanSummary.horizonWeeks`, live). `plan.goalDate` is drawn on
no post-purchase surface, so they cannot be seen to disagree.

**3 · WHAT USER-OWNED FACT STILL DOES NOT SURVIVE A NEW PHONE?**
Jeni's memory · the chat transcript · manual movement entries · the
visit-packet consent grant · body scans (by design, unstated) ·
`safety_numeric_suppression` and the pregnancy / eating-screen / insulin
inputs (by design — never inferred).

**4 · WHAT FACT DEGRADES ON RESTORE?**
Exactly two, both disclosed on the row that shows them: the **exact age**
(→ its band, ≤5 years, ≤35 kcal, ≤14 years at `55plus`) and the
**activity answer** (→ its alias, **0 kcal**, ambiguity stated). The
safety cap degrades to *partial* and is handled by refusing to publish a
number rather than by guessing.

**5 · CAN EDITING ONE BODY FACT LEAVE ANY SURFACE STALE?**
**No.** `TodayStateService` and `CoachContextAssembler` are stateless by
contract, and the three propagation tests assert Home == Plan == Jeni
*after* each edit, not merely that they share a function.

**6 · CAN JENI DISAGREE WITH HOME?**
**Not any more.** She could this morning, twice: about the customer's
current weight, and about the word for her pace.

**7 · CAN JENI DISAGREE WITH THE BOOK?**
**No.** One store, one chokepoint, one accumulator, and
`testOnePlateCarriesTheSameSevenNumbersThroughEveryRepair` pins the seven
integers from the record to the read tool through a re-date and a repeat.

**8 · CAN JENI DISAGREE WITH THE REGIMEN RECORD?**
**No** — and until this build she could not agree with it either about
the injection site, because the fact reached no payload.

**9 · CAN A CUSTOMER CORRECT EVERY REACHABLE RECORD?**
**Yes**, with two deliberate refusals: the **start weight** (every "since
you started" sentence is measured from it; server-repairable and the
repair lands) and **goal history** (the plan is the record). Food,
weight, dose, symptom and every program input are correctable on any day.

**10 · CAN TWO DEVICES SILENTLY DESTROY EACH OTHER'S LEGITIMATE WRITES?**
**Not a write — but they can silently undo a DELETE.** A plate deleted on
device A is re-uploaded by device B on its next launch and returns to A
(§15). No offline step is required. The contract is last-write-to-reach-
the-server-wins at row granularity, and deletion is not representable
without tombstones. **Named, not hidden.**

**11 · DOES ACCOUNT DELETION DELETE THE ONE RECORD?**
**On the device, yes as of this build** (three families added). **On the
server, no in one place:** `public.care_weekly_summaries` has no foreign
key and no delete policy, so a clinic patient's weekly payloads orphan
permanently. P0 privacy debt, migration-gated, named in §16.

**12 · IS THE NEW CLIENT SAFE AGAINST THE CURRENT PRODUCTION EDGE
FUNCTION? — YES.** Every added response field is Optional and decodes
nil; `read_mode` is destructured and ignored. It is running against that
EF right now.

**13 · IS THE CURRENT PRODUCTION CLIENT SAFE AGAINST THE PROPOSED EDGE
FUNCTION? — SAFE, BUT DEGRADED.** Build 30's label door sends the text
hint the new branch sniffs for, so it takes the label branch — and build
30 has no `PlateShare` and no `servings_per_container` reader, so a
multi-serving package reads as one serving with no way to scale. **Order
the deploy after the client, not before.**

**14 · WHAT MIGRATION WOULD YOU DO NEXT, IF ANY?**
In order: **(a)** verify the 2026-07-03 `users.program_mode` /
`goal_direction` / `medication_status` columns are applied — if they are,
the highest-value fix in the product is **client-only, no migration**;
**(b)** the `care_weekly_summaries` foreign key (P0 privacy);
**(c)** `jeni_memories` (§4A, drafted above); **(d)**
`users.onboarding_age_years`. **None written. None applied.**

**15 · WHAT DEPLOYMENT WOULD YOU DO NEXT, IF ANY?**
**None until the client ships.** Then `supabase functions deploy
food-vision --no-verify-jwt`, and only once a build carrying `PlateShare`
has reached the installed base. Deploying today makes the live product's
label reads deterministic **and lower**, with no repair affordance.

**16 · WHAT DEAD PRODUCT WEIGHT DID YOU REMOVE?**
The launch-time decode of the 442 KB CBT lesson manifest — background
work on **every Release launch** to warm a cache whose only production
reader has zero call sites. Verified unreachable from deep links,
notifications, Jeni tools, widgets, tests and migrations first. No
content deleted.

**17 · WHAT IS THE SINGLE BIGGEST ARCHITECTURAL LIE LEFT?**
**That deleting a record deletes it.** `deleteFoodLog`, `deleteWeightLog`,
`deleteDoseEvent` and `deleteObservation` all delete a row and record
nothing about the deletion, while two heals (`mergeRemote`,
`applyHydratedWeightLogs`, `pushLocalFoodEntriesMissingFromServer`) are
insert-only or push-back-only. The product presents deletion as final; the
architecture cannot represent it. Every other false contract this line of
work found — `program_status`, `coach_messages`, `supplementPlans` — is
inert. This one is reachable.

**18 · WHAT IS THE SINGLE BIGGEST CUSTOMER-FACING BORING FAILURE LEFT?**
**Jeni's memory does not follow the account.** It is the only thing in
the product that is presented as durable, is listed with a per-row
*forget*, and is not. Migration first, client after.

**19 · IF I BUY A NEW IPHONE TOMORROW, WHAT EXACTLY WILL I LOSE?**
Everything the coach was *told* rather than *shown*: the notes under
*"what jeni remembers"*, the conversation itself, and any workout you
typed into MOVE by hand. Your body scans, unless you turned backup on.
Your exact age becomes your age band (`about 29 · approximate`, one tap
to fix) and your movement answer becomes its category (no calorie
change). If you are with a clinic, the sharing toggle reads off and you
cannot switch it off from the new phone. **Everything else — every meal
with its photo, its numbers, its corrections and the day it landed on;
every weigh-in; your plan, its start date and its day count; your goal,
height, sex, pace and units; every shot with its site and its dose era;
every symptom — comes back exactly.**

**20 · SAFE FOR NEXT BUILD: YES.**

---

# SCORECARD

Graded hard. Anything below 9 states the exact remaining defect.

| domain | score | the exact defect |
|---|---|---|
| SOURCE-OF-TRUTH INTEGRITY | **10** | — |
| PROPAGATION | **10** | — |
| FOOD RECORD INTEGRITY | **9** | — |
| WEIGHT RECORD INTEGRITY | **9** | — |
| PROGRAM RECORD INTEGRITY | **9** | — |
| GLP-1 RECORD INTEGRITY | **9** | — |
| JENI TRUTH PARITY | **9** | — |
| SYNC | **8** | `consent_grants` has an upsert and no hydrate, so a clinic patient cannot revoke sharing from a second device |
| RESTORE | **7** | Jeni's memory, the chat transcript and manual movement do not follow the account; the memory one reads as durable in Settings and is not |
| TWO-DEVICE SAFETY | **6** | a plate deleted on one device is re-uploaded by the other on its next launch and returns to both; deletion is not representable without tombstones |
| ACCOUNT DELETION | **8** | the device is now complete; `public.care_weekly_summaries` has no foreign key, so a clinic patient's weekly payloads orphan on the server permanently |
| NUTRITION INTEGRITY | **7** | the four FDA label micros are decoded from the (undeployed) EF and **dropped in `map()`** — closing this needs a client change as well as the deploy |
| DESIGN CONSISTENCY | **9** | — |

---

# THE THREE LISTS

### SHIP WITH NEXT BUILD

1. **The deletion sweep** — `JeniMemoryRecord`, `ProgramFactRecord`,
   `WeeklyReadRecord`. P0 privacy, no schema.
2. **One weight ladder in the coach's envelope** — `summary.currentKg`.
3. **One pace word with one authority** — `IntensityTier.paceWord`, and
   the envelope stops shipping `medium`.
4. **`last_site` + `last_site_day`** on `read_dose_history`. Payload
   only, zero deploy.
5. **One day grammar** in `the doses` (`today`/`yesterday` + the time
   zone).
6. **`keep with my plates`** — one string, one name for the food record.
7. **The CBT manifest warm-up removed** from launch.

### REQUIRES MIGRATION / DEPLOYMENT (founder-gated, none prepared)

1. **VERIFY FIRST, COSTS NOTHING:** are `users.program_mode`,
   `goal_direction` and `medication_status` (2026-07-03) applied? Three
   rows means the highest-value remaining fix is **client-only**.
2. **`care_weekly_summaries` foreign key** — P0 privacy; customer-owned
   server data orphans on account deletion today.
3. **`jeni_memories`** — the table is drafted in §4A with its RLS,
   grants, rollback and ordering. Migration first, client after.
4. **`users.onboarding_age_years`** — one nullable int; removes the last
   input that moves her number while she does nothing.
5. **Deprecate then delete the false contracts:** `users.program_status` /
   `program_intensity_tier` / `program_goal_date` (zero writers, zero
   readers, and two comments claiming otherwise) and
   `public.coach_messages` (zero client references).
6. **`food-vision` EF — AFTER a client release, not before** (§8).
7. **Tombstones** — the only real fix for §15, and the only thing that
   makes "delete" mean delete across two devices.
8. **`hydrateConsentGrants`** — inside `Packages/PlankSync`; do it in the
   same build as (2).

### DO NOT BUILD

1. **Syncing the chat transcript.** Local only, and delete
   `coach_messages` (§4B).
2. **Syncing all of `JeniMemoryRecord`.** `supersededAt` rows are local
   bookkeeping; shipping them means storing a history of what she used to
   say about herself.
3. **`date_of_birth`.** More identifying than the product needs, to save
   5 kcal a year.
4. **A second CRUD system inside chat.** Answer → the exact door → the
   existing editor. Jeni still never marks a dose or edits a symptom.
5. **Backfilling an exact age from a band**, a `program_mode` from a plan
   shape, or numeric suppression from anything. Unknown is never
   permission.
6. **Mirroring plan state into `users.program_status`.** A second
   denormalised copy is the drift `31` spent a session removing.
7. **Renaming `the doses` / `the symptoms`** to match `your plates` /
   `your weigh-ins`. A deliberate placement, recorded as a choice.
8. Food text search · a medication-level curve · a water target ·
   streaks · badges · a health score · blurred premium teasers over her
   own data.

---

## SAFE FOR NEXT BUILD: YES

Not because the suites are green. Because the shape of the change is
that **only customers who were already being told two different things
see anything move**:

- **Nothing existing writes differently.** No store gained a write path.
  The deletion sweep only deletes more, and only for the account being
  deleted (pinned by a two-account control).
- **The arithmetic is untouched.** Not one constant moved; the golden
  matrix, `OneTargetEverywhere`, `AutymRecovery`, `UpgradeBoundary`,
  `PlanIdentity`, `SafetyRestore`, `RecordRepair` and `PastRecordRepair`
  are all green and all unchanged.
- **The stored pace vocabulary is untouched** — only the word she reads.
- **No `@Model` changed**, so no SwiftData migration exists to fail.
- **No schema change, no deploy, no production SQL, no production data
  read or mutated.**
- Twelve protected paths **EMPTY**, the other four untouched *this
  session*, the binary strings-clean, and the 5.6 exit path re-verified
  green.

> **There is one person, one record, and every part of Jeni is looking
> at it — on this phone. On the next phone, four things she told the
> coach do not make the trip, and this document says exactly which.**
