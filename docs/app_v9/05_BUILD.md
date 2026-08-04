# app v9 — 05 THE BUILD RECORD

## Phase P1 — BODY VISION: THE CAPTURE (SHIPPED 2026-08-03, batches A+B)

Commit `46deb98` on `feat/app-v2`. Plan:
`docs/superpowers/plans/2026-08-03-p1-body-vision-capture.md`.
Locked decisions honored: D2 silhouette-first (photo opt-in at
consent), D3 local-only (backup seam dormant, default off), D4 no
photo-derived numbers anywhere, L4 privacy plumbing in the same
commit.

### Shipped

- **`PlankApp/BodyScan/` (the module, 6 files):** `BodyScanRecord`
  (local-only @Model — metadata only, no pixel in the table;
  registered + swept + purged same-commit) · `BodyScanPhotoStore`
  (photo 1600px EXIF-free + ink-on-paper silhouette 1200px per scan;
  iCloud-excluded; rekey/delete/deleteAll; dormant `onPhotoPersisted`
  backup seam) · `BodyScanStore` (one scan per day; anchor weekday
  for the batch-B ritual; `bodyScan.` prefs prefix swept as a
  family) · `BodyScanAlignment` (pure pose gate: whole-figure
  requirement, height band 0.60-0.92, center band 0.38-0.62, 12
  consecutive aligned frames arm — 12 unit tests) ·
  `BodyCaptureSession` (front camera, live VNDetectHumanBodyPose at
  ~10fps, mirrored resume-once still capture, freeze frame —
  salvaged from the retired plank camera; the orphan
  `PlankApp/Camera/` is deleted per dead-code law) ·
  `BodySilhouetteRenderer` (on-device VNGeneratePersonSegmentation
  .accurate → ink #2A1F1E figure on paper #FCFAF7 — the one-colour
  identity law made literal; personless frames render plain paper,
  never an error).
- **The flow** (`BodyScanFlowView`, Cover `.bodyScan`): consent
  (once — "your record, private." + three truth lines + the
  silhouette/photo choice, silhouette pre-selected) → guided
  capture (full-bleed mirrored preview, her last silhouette as a
  12% ghost, ONE serif coaching line, countdown 3·2·1 with tick
  haptics when the pose gate arms, movement disarms, freeze +
  success haptic on fire, quiet "capture now" fallback after 8s) →
  landed (matted result, dateline, keep it / retake) → record
  (latest scan matted + "first scan · aug 3" / "N scans · began…"
  + prior strip). Fully offline; pose runs at capture only.
- **Truth:** the camera permission string now covers Body Vision
  honestly (D10 draft: "processed on your iPhone and never leave it
  unless you turn on backup").
- **QA doors:** `--uitest-open-body-scan` (present the module) ·
  `--uitest-scan-allow-manual` (DEBUG-only: instant manual door +
  fabricated paper still — the sim exposes NO camera device at all,
  so the real downstream pipeline still exercises).

### Verified

- **433/433 units** (+12 alignment) on the batch tree; final-gate
  run 432/433 with the one documented OV5Store-deinit flake
  (solo-green ×3 this session, pre-existing).
- **`BodyScanProofUITests` green on an erased sim:** consent →
  camera grant → manual capture → silhouette render → keep →
  record; cold relaunch persists the scan and never re-asks
  consent. Four screenshots in the session record.
- **Honest gap:** the sim cannot show a person — the live pose
  coaching, ghost alignment, and auto-shutter need the **founder
  device walk** (the BreathHaptics precedent). The QA door proves
  the flow; the device proves the feel.

### Design evidence block (L7)

- Subtraction first: no shutter button (the gate fires it), no
  chrome beyond one coaching line + one countdown numeral, no new
  Home surface (the module enters via cover; the checklist is
  untouched pending batch B's offered invitation).
- The record view frame: quiet close · matted scan on paper ·
  caption dateline · one ink capsule — verified by screenshot; the
  consent screenshot raced the cover presentation (the known sim
  stale-frame gotcha), UI hierarchy confirms the rendered copy.

### Batch B (SHIPPED same day, commits `0fcef28` + `898b6c7`)

- **The weekly invitation** — `ProgramDayPrescription.bodyScan`
  (sticker-free, clinical badge, NEVER markable: longPress guarded,
  itemKey never reaches program_day_checks) ·
  `BrandVoice.bodyScanInvitation` ("your record starts with one
  scan" / "scan day. same spot, same light") · CarePlanEngine
  composes it OFFERED after hydration's priority; gentle days drop
  it with every other invitation by construction ·
  TodayStateService: anchor = the weekday she actually scans,
  Sunday until a first scan exists, silent once today's scan is
  kept. QA door `--uitest-force-scan-day`; 4 engine tests; on-sim
  frame verified (ghost row, clinical figure glyph, repeat line).
- **The opt-in backup (D3)** — `BodyScanSyncService`: default OFF;
  enable queues every existing scan; **turning OFF removes the
  cloud copies** (for body photos, off means gone, not paused);
  path `{uid}/{dayKey}_{scanId}.jpg` so a reinstall rebuilds the
  local-only records from the folder listing (silhouettes re-render
  on-device; restored poseQuality = 0 = unknown to P2 floors);
  persistent retry queue + launch flush/restore; scans follow the
  account on sign-in merge (reattribution). Settings doors: "scan
  backup" + "delete all scans" (confirm dialogs; copy = D10
  drafts). **`scripts/body_scans_storage.sql` — FOUNDER APPLIES**
  (until then uploads queue quietly; local-first law holds).
- **Verified:** 437/437 units (+4 engine) · onboarding v7 walker +
  core-in-app legs solo green · BOTH proof legs green together on
  an erased install (scan consent→keep→persist + passive weight) ·
  the scan-day Home frame captured.
- **Founder gates carried:** apply the bucket SQL · the device walk
  for the live pose coaching (sim has no camera) · D10 copy review
  (camera string, consent sheet, invitation lines, settings
  dialogs — all drafted in this record + the P1-A block).

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
