# JeniFit v1.1 — The 75-day Soft Program

**Date:** 2026-06-09
**Author:** PM + 3 UX + 3 Swift agent fleet
**Status:** Plan locked pending founder decisions on open questions

---

## Headline

A 5-phase additive pivot that ships the Her75 daily checklist + BetterMe 2x3 progress grid + ACSM-floored goal-date sub-flow **on top of every existing engine**, behind feature flags, with zero impact to v1.0.9 users.

## Positioning sentence

> **the weight-loss program built around you — gently.**

(italic Fraunces on *built around you* + *gently*)

- App Store subtitle: **"custom" not "75 days"** — emphasize personalization, not challenge duration. (Founder decision 2026-06-09; rejects the Her75 challenge-as-product framing in favor of BetterMe-style custom-program-as-product.)
- 75-day structure stays **inside the app** as the default program length, but never leads the marketing surface.
- Final subtitle copy locked separately (see Founder decisions log below).

---

## Core insight from the team

**JeniFit already owns the engine, the audience, and 8 of the 10 program rails Her75 + BetterMe charge for.** The missing piece is a thin `ProgramPlan` layer that:
1. Turns existing modules into a goal-date-bounded day plan
2. Injects an intensity dial (Soft/Medium/Hard) driven by an ACSM-floored goal-date slider
3. Renders a Her75-style **5-row daily checklist** on Home with a Becoming **Day 1..Day N** grid

Everything else is parameter wiring. WorkoutGenerator, food rail, plank, breathwork, steps, lessons, weight — all plug in unchanged.

---

## The daily checklist (5 rows, 3 auto + 2 self-check)

| # | Row | Source | Tap → |
|---|---|---|---|
| 1 | Today's lesson | JeniMethod, intensity-cadenced (Soft 2x/wk, Medium daily, Hard daily+evening) | JeniMethodLessonView |
| 2 | Snap a meal | First FoodScanRecord of the day | FoodCameraView |
| 3 | Move for X min | WorkoutGenerator output (Soft 8-15, Medium 20-30, Hard 35-45) | SessionPreView |
| 4 | Hit step goal | HealthKit auto-complete (Soft 6k / Medium 7.5k / Hard 9k) | StepsDetailView |
| 5 | Log weight (Sun + 7-day-stale) **or** Breathwork 1 min | Adaptive | LogWeightSheet / BreathworkSession |

5-row ceiling = Locke & Latham research on decision fatigue. Numbers in italic Fraunces (1-5) on alternating pastel sticky-notes (mint/butter/rose/olive).

---

## Goal-date math (ACSM-floored, never free-form)

```swift
weeks_minimum = (current_kg - target_kg) / (current_kg * 0.01)   // 1%/wk ceiling
weeks_maximum = (current_kg - target_kg) / (current_kg * 0.005)  // 0.5%/wk floor
```

Three snap-points on the slider, **never a free date picker** (BetterMe's footgun → 1.6★ reviews):
- **Soft** = max-weeks (0.5%/wk) — default for prior-attempts-many / GLP-1 / perimenopause cohorts
- **Medium** = midpoint (0.75%/wk, ~75 days for typical goals) — default for everyone else
- **Hard** = min-weeks (1.0%/wk) — gated on GLP-1=no + peri=no + age<40 + activity≥light

Show the math + an ACSM credibility chip ("this range is what doctors call sustainable, anything faster usually rebounds") — JeniFit earns through honest evidence, not Cal AI's fantasy dates.

---

## Phase plan (5 phases, all behind feature flags)

### Phase 1 — Minimum Viable Program (12 days)

**Goal:** smallest end-to-end program loop. Onboarding sub-flow + new PlanView checklist + Becoming 2x3 grid + Day-75 graduation sentinel.

**New files:**
- `PlankApp/Program/ProgramService.swift` (@Observable @MainActor singleton)
- `PlankApp/Program/ProgramGoalCalculator.swift` (Wing & Phelan band)
- `PlankApp/Program/ProgramScheduleCalculator.swift` (derived programDay, never stored)
- `PlankApp/Program/ProgramDayPrescription.swift` (Codable enum)
- `PlankApp/Views/Plan/PlanView.swift`
- `PlankApp/Views/Plan/DailyChecklistCard.swift`
- `PlankApp/Views/Plan/PlanRow.swift`
- `PlankApp/Views/Plan/ProgramStickyNote.swift`
- `PlankApp/Views/Onboarding/GoalDateRevealScreen.swift` (case 171)
- `PlankApp/Views/Onboarding/ProgramIntensityScreen.swift` (case 172)
- `PlankApp/Views/Onboarding/CommitmentSignatureScreen.swift` (case 173)
- `PlankApp/Views/Progress/ProgressGridView.swift`
- `PlankApp/Views/Progress/ProgressTile.swift`
- `PlankApp/Views/Progress/WeeklyRecapView.swift`
- `PlankApp/Views/Welcome/ChapterCompleteView.swift` (Day-75 sentinel)

**Engine changes:** ZERO. Every engine plugs in via ProgramDayPrescription adapter.

**Rollout:** `programEraEnabled` + `progressGridEnabled` AppStorage flags, both default **false**. Existing users see HomeView v1.0.9 + Becoming bento **unchanged**. Quiet "start your 75-day program →" card surfaces in Home for users with `program_start_date IS NULL` — opens the same 3-screen sub-flow.

**Risk to existing users:** **none — opt-in flag.**

---

### Phase 2 — Intensity progression + Workout polish + Body measurements (8 days)

**Goal:** make the program feel programmatic. Workout minutes/plank/steps/lessons ramp by week; SessionView gets BetterMe's dashed segment bar + ELAPSED/CAL columns + NEXT-UP card; body measurements ship as the 6th Becoming tile.

**New files:**
- `PlankApp/DesignSystem/DashedSegmentBar.swift`
- `PlankApp/Views/Session/NextUpCard.swift`
- `PlankApp/Health/EnergyExpenditureService.swift` (METs × kg, no HealthKit dep)
- `PlankApp/Views/Progress/BodyMeasurementsTile.swift`
- `PlankApp/Views/Progress/LogMeasurementsSheet.swift`

**Ramp rules:**
- Soft: wk1=7min / wk2=10 / wk3=15; plank +5s/wk capped at lastBenchmark+60s; steps +500/wk capped 10k; lesson 2x/wk
- Medium: 10/15/15→20; daily lesson
- Hard: 15/20/30; daily + Sunday evening recap

**SessionView additions render for ALL sessions** (display upgrade, no behavior change). The Day-N eyebrow only shows for program-enrolled users.

**Risk:** none — opt-in.

---

### Phase 3 — Water + Sleep + barrier-aware lessons + JeniMethod Days 22-75 (10 eng days + 15-20 founder copy days, parallel)

**Goal:** close the daily-checklist data gaps and make lessons feel hand-picked.

**New files:**
- `PlankApp/Health/HydrationService.swift` + `LogWaterSheet.swift`
- `PlankApp/Health/SleepService.swift` + `SleepTile.swift`
- `PlankApp/Views/DietEducation/LessonScheduler.swift` (barrier-tag intersection)
- `JeniMethodContent.swift` LessonID extended `.day22...day75` + `.maintenance`

**Sleep auth prompt fires only for program-enrolled users when they open Becoming with `sleepTileEnabled=true`** — existing non-program users never see it.

**Risk:** none — opt-in.

---

### Phase 4 — Make it Official: share rituals + social proof (8 days)

**Goal:** ship Her75's viral commitment surface.

**New files:**
- `PlankApp/Views/Plan/ProgramDayShareCard.swift` (9:16 export via existing DailyShareRenderer)
- `PlankApp/Views/Plan/MakeItOfficialView.swift` (fullScreenCover, fires once post-paywall)
- `PlankApp/Views/Plan/SocialProofPill.swift` (`+N joined ✓`)
- `PlankApp/Views/Progress/WeeklyRecapShareCard.swift`
- `PlankApp/Views/Plan/PhotoCaptureService.swift`

**Review prompt re-wired:** Day-75 graduation + first share = the two highest-intent anchors (replaces existing hybrid timing).

**Risk:** none — opt-in.

---

### Phase 5 — Post-goal LTV: Maintenance 30 + Recomp 60 + New Goal 75 + Soft Pause (6 days)

**Goal:** close the Day-75 cliff. All 4 tracks use the same ProgramPlan engine with different IntensityProfile + duration + phase.

**The 4 next-program tracks:**

| Track | Intensity | Days | Use case |
|---|---|---|---|
| **Maintenance 30** ⭐ default | `.soft` deficit→0 | 30 | Keep what you built. Lesson 4x/wk, weight 1x/wk. Copy: "becoming" → "staying" |
| **Recomp 60** | `.medium` + volume +30% | 60 | Hit weight goal, want body comp focus. Strength + cycle-syncing lessons |
| **New Goal 75** | user-picked | 75 | Under-shot. Fresh goal weight, carryforward of all data |
| **Soft Pause** | `.minimum` | 28 | Just walks + lessons. Subscription stays alive, low-touch |

**Defensive auto-spawn:** if user doesn't pick within 24h, **Soft Pause** auto-spawns (no churn cliff).

**Day-75 sentinel copy:** *"day 75. you became her."* italic on *became*. Body: *"30% of women who finish stop here. They regain within a year. Stay with us — pick what's next."*

**Risk:** none — unreachable until Day 75 of a Phase 1 enrollment.

---

## Design system updates (all additive to Tokens.swift)

| Token / Component | Change |
|---|---|
| `Palette.bgPrimary #FDF6F4` / `textPrimary #3D2A2A` / `jeweledRose` | **KEEP** — founder-locked brand DNA |
| `Palette.programCard` | ADD `#FFFFFF` — white card on pink scroll |
| `Palette.stickyMint / stickyButter / stickyRose / stickyOlive` | ADD `#C8E6CB / #FFE7A8 / #F4D1D1 / #D9DBA8` |
| `Radius.programCard` | ADD `20` (tighter than existing `Radius.lg=24`) |
| `Space.hero / Space.section` | ADD `80` / `64` (Her75 whitespace rhythm) |
| `Typo.programHeroDisplay` | ADD Fraunces72pt-Light **48pt** |
| `Typo.programHeroItalic` | ADD Fraunces72pt-SemiBoldItalic **48pt** |
| `Typo.stickyNumeral` | ADD Fraunces72pt-SemiBoldItalic **28pt** |
| `ProgramPaperShadow` ViewModifier | ADD shadow `rgba(0,0,0,0.04) y=4 blur=20` |
| Stickers on program surfaces | **REMOVE** from PlanView, ProgramHomeView, ProgressGridView, IntensityPickerView, paywallEdgeScatter |
| Stickers on celebration surfaces | **KEEP** on PostRoutine, SundayCard, JeniMethodLesson illustrations, JenisNote avatar |
| Italic Fraunces voice signal | **KEEP and AMPLIFY** on program surfaces (day *one*, *become* her, follow your *routine*) |
| MainTabView labels | Rename `workout`→`Today`, `log`→`Becoming` (Phase 1 minimal); 5-tab IA deferred to Phase 6 |

**The rule:** *Program surfaces = austere/her75 register. Celebration surfaces = JeniFit scrapbook. The brand contains both — we stop mixing them on the same screen.* Document at `docs/design_program_vs_celebration.md`.

---

## Data model diff (strictly additive)

### New tables

```sql
public.program_plans (
  id uuid PK,
  user_id uuid FK auth.users ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  goal_date date NOT NULL,
  current_weight_kg numeric(5,2),
  goal_weight_kg numeric(5,2),
  pace text CHECK (pace IN ('soft','medium','hard')),
  intensity int NOT NULL DEFAULT 0,
  total_days int NOT NULL,
  phase text NOT NULL DEFAULT 'active'
    CHECK (phase IN ('active','maintenance','recomp','pause','completed')),
  parent_plan_id uuid NULL REFERENCES public.program_plans(id),
  archived_at timestamptz NULL,
  completed_at timestamptz NULL
)

public.program_day_checks (
  id text PK,                   -- client UUID
  user_id uuid FK,
  program_plan_id uuid FK,
  program_day int NOT NULL,
  item_key text CHECK (item_key IN
    ('lesson','snap_meal','move','plank','breath','steps','water','weigh_in','measurements')),
  state text DEFAULT 'empty'
    CHECK (state IN ('empty','complete','skipped','autoCompleted')),
  completed_at timestamptz,
  payload jsonb,                -- caches resolved WorkoutPreset (Phase 2)
  UNIQUE (user_id, program_plan_id, program_day, item_key)
)

public.body_measurements (Phase 2)
  -- chest/waist/hips/thigh/arm cm

public.water_logs (Phase 2-3, table optional — AppStorage acceptable for v1)

public.program_day_photos (Phase 4 share)
```

### New columns (all NULL DEFAULT NULL on `public.users`)

- `program_intensity_tier` text `CHECK IN ('soft','medium','hard')`
- `program_goal_date` date
- `program_status` text DEFAULT `'inactive'`

Plus on `public.session_logs` (Phase 2):
- `program_plan_id` uuid NULL REFERENCES program_plans
- `program_day` int NULL

Plus on `public.jenimethod_lessons`:
- `barrier_tags` text[] NULL (Phase 3)
- `maintenance_eligible` boolean DEFAULT false (Phase 5)

### Migration safety

- **Every** change is `CREATE TABLE IF NOT EXISTS` or `ADD COLUMN IF NOT EXISTS`. Zero `ALTER` on existing columns, zero `NOT NULL` adds, zero `DROP`. Follows the 2026-05-04 11-column migration template line-for-line.
- RLS mirrors `weight_logs`: 4 own-row policies + GRANT to authenticated.
- "One active program per user" is **soft-enforced client-side** (not a partial unique index) so graduation can atomically write `completed` + new `active` row in any order.
- `day_progress.programDay` semantic split: legacy users continue on `EngagementDayCalculator`; program-enrolled users get `ProgramScheduleCalculator.programCalendarDay()`. Same column, last-write-wins — safe because legacy path stops writing once a program is active.
- WorkoutGenerator non-determinism: cache the resolved preset into `program_day_checks.payload` on first render of the day.

---

## Founder decisions log (2026-06-09)

| # | Question | Decision |
|---|---|---|
| 1 | Tab labels | **LOCKED:** minimal rename `Today` / `Becoming` for v1.1. Defer 5-tab BetterMe IA to Phase 6 pending retention data. |
| 2 | App Store positioning | **LOCKED:** drop "75 days" from subtitle; emphasize **custom weight-loss program**. 75-day structure stays inside app, never leads marketing. **Subtitle (28 chars):** *"your custom weight-loss plan"*. **Promotional text (~153 chars, editable post-ship):** *"a custom weight-loss plan built around your body, your day, your pace. lessons + meals + walks + workouts — one plan, every day, for as long as it takes."* |
| 3 | Hard-tier gate | **LOCKED:** visible-but-locked. Requires lock UX (padlock icon + "we hid Hard for safety. unlock in settings" sheet on tap). |
| 4 | Existing-user opt-in | **LOCKED:** full-screen cover. Reuse `PremiumWelcomeScreen` chrome pattern. Fires once per existing user on first launch post-v1.1 install, gated by `AppStorage hasSeenProgramIntro`. |

## Still open

5. **Day-75 graduation:** free emotional moment, OR bundled into Maintenance 30 auto-renew tap? **PM recommends free moment**, separate enrollment tap 24h later.

6. **75-day frame for goals that need 26-52 weeks:** sequential 75-day programs ("your goal needs ~2 of these"), OR custom duration beyond 75? **PM recommends sequential.**

7. **JeniMethod Days 22-75 content budget:** realistic for Phase 1 is Days 6-21 (~15 lessons); Days 22+ ship "new lessons every Sunday — re-read these" fallback. OK?

8. **"+N joined" social-proof pill:** seed with a launch-cohort number, or wait until 250+ real enrollments? App Review may flag static numbers. *(Less critical now that "custom" not "challenge" leads the marketing — defer to Phase 4.)*

9. **Sleep tile in Becoming 2x3:** add HealthKit sleep auth in Phase 1 (new permission for existing users), OR ship 5 tiles + 1 "add body measurements ↗" opt-in card and push Sleep to Phase 2? **SwiftEng2 recommends 5+1.**

10. **`kcal burned` surface in Becoming today-balance** (currently suppressed per Honesty Doctrine): re-enable for the program era, or keep suppressed and stick to time/sessions metric?

11. **Photo assets for IntensityPickerView** (12 lifestyle photos × tier): license Unsplash+ (~$200/mo), commission shoot (~$3-8k), or generate via Flux+LoRA per `project_content_engine`?

---

## What we explicitly defer

- **Outdoor-walk verification** (her75's "one outside" requirement — needs CoreLocation + outdoor heuristic, ~5 dev-days)
- **Progress-picture row** (her75 row 4 — needs secure storage + opt-in; ships in Phase 4 as the share-card photo source instead)
- **Social-proof real counter** until 250+ paid enrollments
- **"Coach" chat tab** (Phase 6 or later)
- **5-tab BetterMe IA** (Phase 6, pending retention data)

Counter to her75: **our food camera + workout engine are differentiators they don't have.** Net even.

---

## Sprint sequence summary

| Phase | Duration | Risk | Defaults |
|---|---|---|---|
| 1 — MVP Program | 12 days | none — opt-in flag | flags off |
| 2 — Intensity ramp + SessionView polish + measurements | 8 days | none — opt-in | rampEnabled default true for program users |
| 3 — Water + Sleep + lessons Days 22-75 | 10 days + founder copy | none — opt-in | waterRowEnabled true; sleep gated on HK auth |
| 4 — Share rituals + Day-1 ritual | 8 days | none — opt-in | shareRitualsEnabled true for program users |
| 5 — Post-goal Maintenance / Recomp / New Goal / Pause | 6 days | none — unreachable until Day 75 | postGoalEnabled true |

**Total: ~44 engineering days + parallel content authoring.** First user-visible value at end of Phase 1 (~2.5 weeks).

---

## Risks the team flagged

- **Hard-tier paternalism** if visible-but-locked reads exclusionary → fallback to inline nudge.
- **5-row daily checklist may feel too easy for Hard cohort** (3 auto-greens by 11am = "is that it?") → Hard tier optionally exposes evening-recap row 6.
- **Day-75 cliff sharpens retention curve** — if Maintenance-30 spawn doesn't convert >50%, we traded a fuzzy curve (current) for a sharp cliff. Mitigation: free Day-75 emotional moment + bundled next-program enrollment.
- **App Store re-categorization** to "weight-loss program" positioning may trigger 24-48h Apple review delay; have backup framing ("a 75-day movement + food coaching app").
- **JeniMethod Days 6-75 content debt** is a real retention risk — copy budget is real work, not just engineering.
- **Cohort recovery if user changes intensity mid-program:** lock "changes apply from tomorrow forward, no retroactive grid changes" to avoid grid re-coloring under her feet.

---

## Decision required before Phase 1 ships

Address open questions 1-3 + 7. Everything else can be answered as Phase 1 lands.
