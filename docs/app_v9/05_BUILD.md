# app v9 — 05 THE BUILD RECORD

## Phase P6 — THE BETWEEN-VISIT SERIES (SHIPPED 2026-08-04)

Commit `41a5757`. W10's substrate half closes.

- **The substrate:** `care_weekly_summaries` (migration
  `20260804090000_p6_weekly_summaries.sql` — **FOUNDER APPLIES**,
  dev now + pilot when provisioned): insert-only history, one row
  per patient × org × ISO week; the current week upserts, prior
  weeks are policy-immutable (no delete for ANYONE). Patient-
  computed, deterministic, offline-valid, no AI (the v8 law). RLS:
  patient writes only under active packet consent; clinicians are
  RPC-only (`care_get_weekly_summaries`: member + consent +
  lookback clamp + `summary.viewed` audit, 26-week cap).
- **Consent posture (D6-honest):** the series rides the EXISTING
  visit_packet_view scope at the packet's exact cadence — it
  publishes only when her app runs; nothing watches in real time.
  The between-visit framing joins D6's counsel review; the true
  dropout-risk flag stays out until that lands.
- **iOS:** `CareWeekSummary` (pure compose + gather — unrecorded is
  never skipped, taken never exceeds scheduled, monday-anchored
  week keys; 6 tests) + `WeeklySummaryPublisher` riding `onLaunch`,
  graceful against an un-migrated server.
- **Dashboard:** the "week by week" panel (the packet's facts
  vocabulary via `weekLine`; empty states explain accrual), the
  **weight-series panel via `care_get_patient_series`** — the idle
  S4 RPC finally consumed (observation_view scope) — and the
  consent-honest **staleness word** on the record label ("updated N
  days/weeks ago"). tsc clean.
- **Probe:** +9 checks staged in `s4_security_probe.py`
  (publish-under-consent · stranger/rival denied · RPC-only law ·
  append-only history · revocation on both sides). **The live probe
  run + Playwright + demo-tenant seeding are founder/local-stack
  gates** (the S5 precedent: real runs happen against the full
  local Supabase stack).
- **Verified here:** 487 iOS units (+6; flake solo-green) ·
  dashboard typecheck clean · migration + probe parse.

## Phase P5 batch B — THE VOICE + THE LINK (SHIPPED 2026-08-04) — P5 COMPLETE

Commit `4c53de7`.

- **The heart sweep reaches the food package:** 48 heart glyphs
  (U+2661 escapes + U+2665 suits — iOS renders the suit as the RED
  emoji heart, caught live on a scanning frame) swept from 17 files
  of shipping copy; punctuation repaired, ellipses restored. The
  Jeni-release voice law finally holds package-wide.
- **The muscle-keeping note line:** the jeni-note engine's general-
  cohort protein branch gains "…does the *muscle*-keeping work —
  protein first protects it." — the P4 promotion vocabulary, one
  voice across surfaces (the GLP-1 lines already spoke it).
- **Honest correction to the plan:** the insight-first result
  architecture ALREADY ships (v1.0.7 Phase A.4 — "show macros"
  collapsed by default, the feeling·fits interpreted line, the note
  slide). The audit's "raw grid leads" claim was stale; recorded,
  not rebuilt (L7: never redesign to look different).
- **Verified:** 482/482 · result card frame-verified heart-free
  ("close *enough*" · "hits *enough*" pill · compact macro line) ·
  core walker green.

Commit `1afc7f5`. W8's data half closes.

- **The sodium dead-end, closed end to end:** EF schema +
  `sodium_mg`/`saturated_fat_g` (**founder deploys food-vision**;
  the client decodes tolerantly until then and the USDA/OFF
  calibration sweep stays the interim source) → CapturedItem →
  JSONL Entry (plate sums + per-ingredient) → cloud.
- **The zero-migration sync route (deliberate deviation from the
  plan's "additive columns"):** the story data rides the EXISTING
  `food_logs.payload` jsonb — sodium, sat-fat, and the full
  per-ingredient ledger — because PostgREST rejects upserts naming
  unknown columns, and new columns would have broken food sync
  until a founder migration. Payload can graduate to real columns
  server-side later. **A reinstall now restores the per-ingredient
  ledger** (the audit's "richest data invisible to any server"
  gap).
- **`FoodWeekRead`** (8 tests): the weekly food-quality BANDS —
  protein-led (the win named first, anti-shame order) / late-heavy
  (≥40% of the week's kcal at 8pm+) / steady; nil under 4 logged
  days; NEVER a number, a food name, or a score. Renders as the
  becoming food page's headline when floors pass; the P3 mechanisms
  keep the atoms (no double-speak).
- **Verified:** 481 units (+8; flake solo-green) · both walkers.
- **Held for P5 batch B:** the insight-first result card (interpreted
  lines lead, the raw grid one tap deep, the plate→preservation
  link line) + its frame review — the food rail is founder-loved
  craft and deserves a fresh-eyed batch.
- **Founder gates:** deploy `supabase functions deploy food-vision`
  (activates model-direct sodium/sat-fat + sugar).

## Phase P4 — THE DAILY FOCUS (SHIPPED 2026-08-03)

Commit `1792482`. The third question's promotion (W9 closed).

- **The body-outcome axis:** the promotion ladder now runs rapid-
  loss tripwire → **preservation at-risk** (the P3 ladder's daily
  echo: a WEEK of fast loss with protein under, ≥4 logged days) →
  yesterday's deficit. The **plateau week** reaches the lead's
  REASON as support (never a push, never over a clinical promotion,
  never on dose days) — Linde 2004, the unaddressed plateau named
  early.
- **The mark (D1's second grant):** `Plan.leadIsPromoted` — a
  clinically-chosen lead wears the dose-dot beside its reason; text
  color unchanged (AA floor). Medication never wears ornament;
  gentle days stay unadorned. **Founder frame-review invited** (the
  D1 exit): the mark is a 4pt accent dot — say the word and it
  moves or dies.
- **One spine, two cadences:** the weekly read (P3) and the daily
  lead now share the same preservation ladder underneath — the
  week's theme and the day's ask can no longer disagree.
- **Verified:** 474/474 (+6 promotion tests: at-risk beats
  yesterday, tripwire beats at-risk, plateau never overrides,
  dose/gentle unadorned) · both walkers solo green.
- **Design evidence (L7):** the whole visual change is one 4pt dot.

## Phase P3 — WHY AM I CHANGING? (SHIPPED 2026-08-03)

Commit `5f91894`. The explanation layer (W8's read half + W9's
unification).

- **`WeeklyBodyReview`** (pure; 22 tests = the provenance audit):
  the becoming landing's read now runs outcome → mechanisms →
  preservation → the move. Outcome = the unit-aware trend line
  (scans lead when no trend exists). Mechanisms = ≤3 floor-gated
  observations: protein presence (≥4 logged days), strength/feet,
  short-night pattern (≥3 counted + ≥3 short), window drift (≥4
  nights <11h), sugar direction (weekly only, never a food), the
  dose rhythm (scheduled cohort only), recovery, the mirror clause
  (only behind the FULL body-page floors). Rising weeks stay
  pattern-only and never claim the mirror. CoachSummary composes
  the move untouched — the consent grammar of the re-signing never
  moved.
- **Muscle preservation, honestly:** protected / watch / at-risk /
  unknown from protein presence × movement (strength OR ≥5 active
  days) × the ACSM 1%/wk guard; wycherley 2012 · ajcn rides as
  inline evidence; lean mass joins with provenance ("your scale
  reads…"); unknown says what it needs. The cover renders state-
  tinted (rose for at-risk — never red).
- **HRV returned WITH its surface (D5 closed):** VitalsService reads
  7d + 30d SDNN again; `recoveryWord` speaks only against her own
  baseline (±7ms steady); the permission string names recovery.
- **The L5-honest movement ask:** "connect workouts — the muscle
  read needs them" lives on the surface that renders the data;
  `MovementService.everRequested` distinguishes ungranted from
  zero.
- **Chat knows:** the assembler's envelope gains `body`
  (scan_count, scan_span_weeks) + `trend_established` — facts only,
  never an image or photo-derived number.
- **Verified:** 468/468 units (+22, zero flakes on the gate run) ·
  onboarding + core walkers solo · both scan proof legs · landing
  frame verified live (outcome hero + "7 days on your feet" +
  connect door composing exactly under floors; move + preservation
  correctly absent below theirs). Incidental: the Health Access
  sheet frame confirmed the Jeni brand + write-string copy.
- **Design evidence (L7):** one narrative spine where two engines
  ran parallel; mechanisms are single quiet lines; the only new
  chrome is one underlined caption (the ask). Nothing decorated.

## Phase P2 — THE TRANSFORMATION SURFACES (SHIPPED 2026-08-03)

Commit `eba4586`. "Am I changing?" gains its home (W1/W2 close).

- **THE BODY PAGE** — second in becoming's carousel the moment a
  scan exists: her latest scan matted, the floor-gated change line
  as the headline, "open your record" door. `BodyChangeRead` (pure,
  10 tests): ≥2 scans + ≥28-day span + full-figure quality (≥0.5;
  restored scans = unknown = honest fail) + established-trend
  agreement → "N weeks in — the line and the mirror agree."; a
  climbing week NEVER blames the mirror; unmet floors say what they
  need.
- **YOUR RECORD (the timeline + THE COMPARE)** — the L7 interaction:
  then ↔ now on one drag (crossfade + rose scrub, date ends), the
  prior-picker with date chips, week-by-week groups, the cover
  opt-in door (D2 — the silhouette face always, her choice).
  Alignment: capture now stores the pose-gate's figure anchors
  (`figureTopY/BottomY/CenterX`, additive optionals); the internal
  transform scales/offsets "then" to coincide (clamped 0.8-1.25,
  NEVER surfaced — L3). Cover art: her silhouette replaces the
  plate when the door is on.
- **D1's granted whisper** — "trend · easing" joins the evening
  receipt ledger (established floor; suppressed cohorts never see
  it; `TodaySnapshot.trendIsEstablished` surfaced;
  `BodyStateService.trendWord` = the canvas thresholds).
- **The introduction** — once ever (migration-moment law): day 2+,
  pre-consent, stamped the moment it presents; "see it" opens the
  scan module; choices tracked (`body_vision_intro`). `body_scan_
  kept` counts land in PostHog (no body datum ever — v8 law).
- **Found + fixed en route:** a kept scan never told becoming to
  recompose (relaunch-only) — `BodyScanStore.didChange` notifier,
  the weightLogDidChange pattern.
- **QA doors:** `--uitest-seed-scans` (three drawn ink figures,
  narrowing weekly — REAL visual change on the camera-less sim) ·
  `--uitest-force-body-intro` · `--uitest-reset-body-scan` (prefs
  half synchronous in init — the consent race) ·
  `--uitest-start-tab` reused.
- **Verified:** 446 units green (+10; the OV5Store deinit flake solo-
  green again) · both walker legs solo · both proof legs together on
  an erased install (incl. the new becoming/timeline/compare leg
  with deterministic floor-line assert) · frames captured: body
  page, timeline, mid-scrub compare.
- **Design evidence (L7):** one gesture owns the compare; one rose
  accent (the scrub thumb + selection ring); the ink-figure-on-paper
  mat everywhere; no numbers anywhere on a body surface. Removed,
  not added: no compare buttons, no percent labels, no share chrome.

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
