# AGENT EXTRACT — HealthKit inventory (ae2c1269)

AUTH SHEETS: v8 onboarding s_healthKit beat requests READ: steps, bodyMass, bodyFat%, activeEnergy, distance, restingHR, workouts, sleep (NOT HRV, NOT leanBodyMass, NOT menstrualFlow) (V8Structured:276-287). Union sheets (StepsService:176-182 via MoveSheet/Settings) add HRV, leanMass, menstrualFlow. SleepService's own sheet UNREACHABLE in production (DEBUG harness only). VitalsService/CycleService.requestAccess: ZERO callers.

DEAD/DECORATIVE:
- **restingHeartRate: requested on the LIVE consult sheet with on-screen copy "the recovery signal", read as 7d/30d means, ZERO consumers — VitalsTrend engine has zero call sites.** Contradicts VitalsService's own L5 header.
- **menstrualFlow: requested on union sheets but CycleService.bootstrap()/refresh() have ZERO callers → periodStarts permanently [] → season can NEVER speak in brief/coach for anyone.** JKSeasonBand/Mark unhosted. (= the cycle-awareness opportunity is half-plumbed and unplugged.)
- Dead riding live: hourlyBreakdown, StepsBentoTile, stepsGoalHit/stepsViewedHome events, healthKitStepsRequested flag read by nothing, LastNightSleepCard (denied-copy UI) DEBUG-only, EnergyLedger.spentKcal/isLighterDay.
- HRV + leanBodyMass consumed (weekly body review recovery line, lean line) but NOT on the onboarding sheet → behave as unrequested for most users.

WEIGHT IMPORT (BodyMassImportService): 90-day window (TWO doc comments still say 30 — stale), per-calendar-day latest sample, 20-400kg clamp, decision: existing manual → skip; existing healthkit → update-in-place >0.01kg; none → insert UNLESS day-tombstone (clearedWeightDayId "<uid>-weightday-<day>"); fresh uuid on insert; manual-wins; correction flips source to manual → next import skips. Observer + .immediate background delivery, every-launch full re-import.

STEPS: 7,500 anchor (Jayedi note); goal ladder fact→tier→7500; adaptive clamp 2,500-8,000. Denied is INFERRED post-ask from zero data. Granted-but-quiet phone stays .notDetermined and starts NO observer until data or tap.

SLEEP: read 36h + 7 nights; consumers: brief slept_h, CarePlanEngine short-night tone softening (the one actuator), Becoming tile (3-night floor), weekly review. Stage bands computed, rendered only in DEBUG card. Denied invisible (no connect CTA in production).

WORKOUTS: 7-day sample read; strength = traditional+functional ONLY (yoga negative control pinned by test); ≥10 min any workout absorbs walking action. ENERGY LAW: HK measured or ABSENT; only typed sessions get MET estimate (×3.5×kg/200), rounded to 5; no weight → no estimate; manual never written to HK (laundering refusal).

WRITES: ONE production write — dietaryEnergyConsumed, opt-in toggle off-by-default, kcal+timestamp+wasUserEntered only; re-dated plates NOT re-written (double-count refusal); toggle-off never retro-deletes. DEBUG-only seed writes compiled out.

PURPOSE STRINGS: share string covers every requested type ✓ (gap is honesty-of-promise: RHR named but never rendered; cycle named but can never flow). Update string exact ✓.

LAUNCH COST: ~11 HK queries serially in launch task (steps 28d collection, sleep 36h, vitals up to 6, movement 3, bodyMass 90d + N upserts); auth states not persisted → every cold start re-probes. Observers: bodyMass .immediate, steps .hourly.
NO anchored queries anywhere (full window re-reads). No source filtering (HK statistics dedupe relied on).
Widget: zero HealthKit.
