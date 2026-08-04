# app v9 — 05 THE BUILD RECORD

## Phase P0 — HONEST FOUNDATIONS (SHIPPED 2026-08-03)

Commits `9fc6223 → 13ca0c7 → 041e794 → c1eb213 → 3c8b036 → 5239479`
on `feat/app-v2`. Implementation plan:
`docs/superpowers/plans/2026-08-03-p0-honest-foundations.md`.

### Shipped

- **BodyStateService (W7)** — `PlankApp/Program/BodyStateService
  .swift`: ONE typed read (`BodyState.Weight/Composition/Movement`)
  over weight logs + HK composition + movement. Pure core; every
  floor is the shipped floor (trend = 3+ logs spanning 5+ days;
  stall/rate = WeightAnalytics); composition carries provenance
  ("apple health", L3); empty sections are nil. `TodayStateService`
  delegates its weight derivations (equivalence pinned; `emaDelta7d`
  canonical copy moved, forward kept). 13 unit tests.
- **Passive weight repaired (W3)** — `importIfEnabled` joined the
  launch bootstrap (`PlankAIApp.swift`, after the vitals probe);
  onboarding's bodyMass grant now sets the import flag
  (`OV5ScreensClose.requestHealthKit`) so the grant stops being
  wasted; manual-wins-day law untouched.
- **Background delivery (W4)** — bodyMass observer + `.immediate`
  delivery (`BodyMassImportService.startObservingIfEnabled`); steps
  observer honors the delivery completion contract + `.hourly`
  delivery; `com.apple.developer.healthkit.background-delivery`
  entitlement added. **Founder note at next archive: the App ID
  needs the HealthKit Background Delivery capability (Xcode
  auto-manages on the next device build).**
- **HealthKit truth pass (W5, D5)** — VitalsService dropped HRV /
  VO2max / respiratory rate / blood pressure (read-but-never-
  rendered; HRV returns WITH P3's surface). readTypes = resting HR +
  bodyFat% + lean mass. **Discovery beyond the audit: the cycle
  season surface shipped with NO requester anywhere** —
  `CycleService.requestAccess` had zero callers, so menstrualFlow
  could never be granted; the cycle read type now rides the
  steps/sleep connect sheets (`CycleService.readTypes`).
- **Honest strings (D10 drafts — voice review below)** — all four
  Info.plist strings rewritten: Jeni brand (four "JeniFit"
  stragglers dead), camera string dropped the dead plank-form
  clause, health string names the real scope.
- **MovementService (W6)** — silent-probe service (workouts w/
  strength detection, today's active energy + distance) mirroring
  the VitalsService shape; the authorization ask ships with P3's
  rendered surface (L5). Feeds `BodyState.movement`. Waist
  deliberately deferred to its surface (P2/P3).
- **Proof leg** — `plankAIUITests/PassiveWeightProofUITests`: seeds
  two HK samples, relaunches silent, asserts Becoming reads a DOWN
  trend (the seeded lone starting weigh-in can only read steady, so
  "down about 2 lb this week." proves the import). Permanent QA
  asset. QA door: `--debug-hk-write-weight <kg>` (DEBUG).

### Verified

- **421/421 units** (was 407; +13 BodyStateService, +2 Movement,
  −1 re-counted suite composition) — three full-suite runs.
- **On-sim exit-criterion proof**: erased install → HK grant (the
  only taps) → silent relaunch → becoming's landing read speaks
  "down about 2 lb this week." from imported samples; import log
  confirms "imported 2 row(s) from Apple Health". Screenshots in
  the session record.
- **Walker legs solo**: `testWalkV5ToPaywall` (the onboarding v7
  walk — exercises the changed HK screen) + `testWalkCoreInAppFlows`
  both green.
- **Flake diagnosed, not mine**: under full-suite load,
  `V6FunnelTests` intermittently crashes at `OV5Store
  .__deallocating_deinit` → the documented iOS 26.2 sim
  MainActor-class-deinit malloc abort
  (reference_mainactor_class_deinit_crash). Passes solo every run
  and passed under load on the final tree. A fix belongs to an
  OV5Store-shaped change, not P0.

### Design evidence block (L7)

- **Removed, not added**: five never-rendered sensitive reads; the
  dead plank-form camera clause; four brand stragglers. P0's user-
  visible surface is words + an it-just-works moment — no new
  chrome anywhere.
- The proof screenshots show the becoming landing carrying the
  imported trend in the serif hero register — the first time the
  app answers "am I changing?" without her typing a number.

### D10 — the string drafts (founder voice review)

- **Camera**: "Jeni uses your camera to scan your meals. One photo
  per scan goes to our private vision service for calorie and
  protein estimates — never used to train models. A small copy
  stays on your phone for your own food diary."
- **Health read**: "Jeni reads a few quiet signals from Apple
  Health — steps, sleep, weigh-ins, resting heart rate, cycle
  timing, and body composition when your scale saves it — so your
  trend fills in without you typing a thing. These signals shape
  only your own plan and jeni's notes to you. Imported weigh-ins
  sync to your private Jeni account; nothing is sold, and nothing
  is shared unless you explicitly choose to share it."
- **Health write**: unchanged except the brand word.
- **Photos add**: unchanged except the brand word.
