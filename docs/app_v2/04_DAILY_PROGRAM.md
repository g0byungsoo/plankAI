# 04 — The daily program model (prescription engine v2)

## Intent

Make the archetypes real. Today, every day prescribes the same six
rows and the archetype reorders one. v2 makes the archetype *select*
the beats, sets their parameters from the tier profile, and gives the
day a shape. The engine stays pure and deterministic (same inputs →
same day), cached per-day like v1.

## Day composition

`PrescriptionEngineV2.compose(day:profile:cohort:context)` returns an
ordered `[ProgramDayPrescription]` of **3-5 beats** (never 6+):

| Archetype | Beats (ordered) |
|---|---|
| protein | snapMeal (protein hero) · lesson? · workout? · steps |
| movement | workout (hero) · snapMeal · steps · lesson? |
| balanced | lesson (hero) · snapMeal · steps · breath? |
| rest | breath (hero) · lesson? · steps · snapMeal (quiet) |

Rules that finally consume the dormant engine capability:

- **Workout days = `IntensityProfile.sessionsPerWeek`** (3/4/5), not
  daily. Placement: movement day always; protein days fill the
  remainder (soft: Mon/Tue/Fri pattern derived from rotation index).
  Rest day never carries a workout.
- **Lesson cadence = `IntensityProfile.lessonCadence`** (twiceWeek /
  daily / dailyPlusEvening), scheduled by CBTCurriculumScheduler as
  today; on non-lesson days the beat is absent (not "locked").
- **Weigh-in is a cadence, not a row-of-rows**: default Mon + Thu
  morning (2×/wk — self-weighing evidence supports ≥ weekly for
  outcome, SCIENCE.md §3; twice weekly balances signal vs scale
  anxiety for this brand). GLP-1 current: weekly (their loss is
  pharmacological; daily noise is anti-therapeutic). Post-GLP-1
  maintenance: weekly Sunday "trend check" framing. Restriction-risk
  cohort (`onb_restrictive_food` — bridge fixed in 06): weekly, and
  the row copy drops numbers entirely. Surfaced as a compact morning
  beat only on its days; skippable without penalty.
- **Breath** is the rest-day hero and appears on stress-flagged
  profiles (stress key) as an evening beat elsewhere; style rotates
  calming/windDown by time of day.
- **Steps** beat is always present (the everyday anchor) but renders
  as the live ring row, auto-completing — never a chore checkbox.

## Cohort day-shaping (the felt difference)

- **GLP-1 current**: protein beat is always the hero and carries the
  target ("aim near {N}g — lean-mass first"); appetite-rhythm key
  chooses snap copy ("small plates count double" for grazing rhythm);
  hydration line joins the evening close; workout rows framed
  "strength keeps the loss lean" (SCIENCE.md §1).
- **GLP-1 past (maintenance/gentle)**: week frame over day frame —
  the strip shows the week's rhythm; weigh-in Sunday; briefs speak
  to consistency ("the week held"); P6 lessons pinned earlier by the
  scheduler (affinity weight, not reorder).
- **Considering**: general program + agency framing in briefs.
- **Peri/short-sleep**: already in pace floors; v2 adds brief lines
  citing their own sleep answer (provenance) on relevant days.

## Targets: one source of truth

New `TargetsService` (@MainActor, pure functions over stored fields):

- `calorieTarget(for date)` — Mifflin-St Jeor TDEE (existing
  calculator) − pace deficit from the ACTIVE plan tier, recomputed
  against **latest logged weight** (not onboarding weight forever),
  floored at max(1200, BMR), suppressed (nil) for safety-gated /
  maintenance-mode users exactly like the reveal's rules.
- `proteinTarget()` — single formula everywhere: 1.6 g/kg for GLP-1
  current (clamp 90-140), 1.2 g/kg default (clamp 70-130), computed
  on latest weight. SnapResult, Becoming, Today, Chat all read this.
  (Resolves defect #1; the g/kg citation ships in SCIENCE.md §1.)
- `stepsGoal()` — from IntensityProfile (6000/7500/9000).
- Everything exposed to chat context and the brief engine.

## The brief engine (Jeni's line of the day)

`DailyBriefEngine.brief(for date)` — deterministic, provenance-only,
seeded by (dayOfYear, state) so it's stable within a day. Priority
cascade picks ONE thread:

1. kept-promise acknowledgment (day 1-2)
2. weigh-in day framing / trend movement worth naming (EMA delta)
3. plateau/rapid-loss care lines (wires RapidLossTripwire at last)
4. archetype intro ("a protein day — one strong plate at a time")
5. streak-of-showing-up / comeback ("back after two days — that's
   the skill")
6. cohort default lines

Output: `(line, italic:[String], chatSeed:String?)` — the line renders
on Today; tapping it opens jeni with the seed expanded. The engine is
shared with notifications (09) so push copy and in-app copy never
diverge.

## Evening close

After 18:00, Today's tail swaps to the close beat: plates-of-the-day
strip + one-line day receipt ("protein landed at 84g · you moved ·
one lesson") + one-tap feeling (three quiet words, stored to
`day_reflections` — new, small) + tomorrow whisper ("tomorrow is a
rest day. nothing heavy ♥"). Skippable forever; never a guilt state.

## Adaptivity (v2 scope, honest)

In-scope now: targets recompute on weight change; weigh-in cadence by
cohort; brief cascade reacts to trend; rapid-loss tripwire wired to a
care line + protein reframe. Out of scope (documented for v2.1):
auto-tier adjustment, deload weeks from performance, food-noise
score. Nothing in copy promises what isn't live (compliance rule).
