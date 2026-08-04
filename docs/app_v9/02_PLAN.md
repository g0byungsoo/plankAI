# app v9 — 02 THE EVOLUTION PLAN

**Status: PROPOSED. Gaps cited as W1-W10 (`01_AUDIT.md`), laws as
L1-L6 (`00_MISSION.md`), decisions as D1-D10 (`03_DECISIONS.md`).**

## 1. Approaches considered

- **A — v9-on-top.** Build a Body tab + new engines beside the
  existing five stores. Fastest first ship; worsens the exact
  fragmentation the audit found (W7, W9: five stores, two
  one-thing engines, another stratified era).
- **B — consolidate the body spine, then build on it
  (RECOMMENDED).** Introduce one `BodyStateService` aggregate over
  the existing stores (no store is rewritten; consumers keep their
  APIs), then land Body Vision, the explanation layer, and the
  Daily Focus on that spine. Slightly slower to first ship; every
  later phase gets cheaper; the fragmentation debt is paid exactly
  where the vision needs it — and nowhere else (YAGNI: the
  consolidation is limited strictly to the body-state read path).
- **C — big-bang recenter.** Redesign Home/tabs around Body Vision
  immediately. Violates the brief's non-negotiables and the locked
  Home steer. Rejected.

Plan = **B**, executed with A's additive discipline: every phase is
a separate shippable increment behind the FoodFlags-style rollout
stack, each independently revertible (L2).

## 2. The phases

Sizes are relative (S/M/L). Order is the dependency order; P3/P4
can interleave after P2. Every phase ends with the house
verification ritual (§6) and a docs/05-style shipped record.

### P0 — Honest foundations (M)

Fix what v9 would otherwise build on top of. No new user-visible
surfaces except repaired passive weight.

- **Passive weight, actually passive (W3).** Wire
  `BodyMassImportService.importIfEnabled` into the launch bootstrap
  + an HK observer; make the onboarding bodyMass grant set the
  import flag so the grant stops being wasted; keep manual-wins-day
  law. Exit: a scale weigh-in written to Apple Health appears in
  her trend on next launch with zero taps, proven on-sim with a
  seeded HK store.
- **Background delivery (W4).** `enableBackgroundDelivery` +
  observers for bodyMass and steps (workouts join in this pass);
  add the background-delivery entitlement. Data lands without an
  open (L5).
- **HealthKit truth pass (W5, D5).** Requested scope == rendered
  scope == usage-string story: drop VO2max/RR/BP from the request
  set (HRV's fate is D5 — keep only if P3 renders it); rewrite both
  health usage strings (Jeni brand, honest scope — copy is D10);
  cover body capture honestly in the camera string when P1 lands.
- **New passive reads (W6).** Workouts (incl. strength-type
  detection), active energy, walking distance; waist circumference
  read-if-present. Each lands with its rendered surface in P2/P3 —
  requests are made at the moment a surface needs them, never as a
  wall (L5).
- **`BodyStateService` (W7).** A `@MainActor` enum service (house
  law: enum services, not class singletons — iOS 26.2 sim deinit
  gotcha) composing one typed read: weight EMA + floors (existing
  math), HK composition when present, movement week, and later
  scans. `TodaySnapshot` and Becoming consume it; no store
  rewritten; consumer APIs stable.
- Exit criteria: passive weight proven; entitlement + strings
  aligned; BodyStateService unit-tested (target ~15 tests);
  407-suite stays green.

### P1 — Body Vision: the capture (L)

The signature experience: she stands in front of the camera; the
app guides her into a consistent pose and framing; seconds, not
minutes. **No numbers, ever, from the photo (L3).**

- **`BodyScanRecord`** @Model via the 6-step sync seam: userId,
  capturedAt, dayKey, poseQuality, framing metadata, localPhotoId,
  renderMode (photo|silhouette), backedUp flag. Registered,
  swept on sign-out, re-keyed on merge, additive migration —
  privacy plumbing in the same commit (L4).
- **`BodyScanPhotoStore`** cloned from FoodPhotoStore at scan
  fidelity (long-edge ~1600px, JPEG ~q0.8, EXIF-stripped,
  excluded-from-backup dir), plus a **silhouette derivative**
  rendered on-device via `VNGeneratePersonSegmentationRequest` —
  ink figure on paper, the one-colour identity law made literal.
  Cloud backup = new private `body-scans` bucket mirroring the
  food-photos RLS pattern, **opt-in, default OFF** (D3), its own
  pending queue + re-key path; scan record carries a photoState so
  the two-path integrity risk the audit flagged is reconciled
  explicitly. Delete-account purges the bucket; retention rides a
  `food-photo-cleanup`-shaped cron when backup is on.
- **The guided camera** — hybrid of the two existing halves: the
  food camera's still+freeze+continuation core + the orphaned pose
  stack's live `VNDetectHumanBodyPose` (front camera). Guidance =
  a ghost overlay of her last scan's silhouette + framing coach
  lines ("step back a touch") + a quality gate (joints visible,
  distance band, device upright) + 3-2-1 auto-shutter when
  aligned + freeze. First run: a consent sheet in the clinical
  register (where photos live, what never happens to them, her
  choice of photo vs silhouette). Fully offline. Pose processing
  at capture-time only — no continuous background Vision.
- **The ritual.** Weekly, on her chosen day, composed by
  CarePlanEngine as an **offered invitation — never debt** (the
  shot-day anchor pattern, reused). Notification only under the
  existing consent gates (D9).
- **Salvage + retire.** The pose stack moves into the new capture
  module; the orphaned `PlankApp/Camera/CameraManager.swift` dies
  per dead-code law.
- Exit: capture → record → gallery-visible scan proven on-sim
  (walker leg + recorded frame review of the guidance motion);
  privacy sweep test (sign-out leaves nothing); zero regressions.

### P2 — Body Vision: the transformation surfaces (L)

"Am I changing?" gets its home (W1, W2).

- **The body timeline** — week-grouped, museum-hung (the plate
  gallery stack reused: cover art → strip → gallery), oldest-to-
  newest draw-on. Her scan (photo or silhouette, her standing
  choice) can become the Becoming cover — the cover hero finally
  becomes *her*, not her plate (her opt-in, D2).
- **The compare moment** — two aligned scans, crossfade + slider;
  alignment normalization (scale/translate from pose anchors) is
  internal-only mechanics, never a surfaced number (L3).
- **Change language with floors** — qualitative, gated on pose-
  match quality + ≥4 weeks + established trend agreement;
  uncertainty stated ("four weeks in — the line and the mirror
  agree"). When floors aren't met, the surface says what it needs,
  the WeightAnalytics way.
- **Home stays checklist-law** (the 2026-07-27 locked steer) with
  ONE proposed whisper: the trend word joins `TodayStateBand`'s
  existing ledger line (render-only, no new chrome) — **only if D1
  unlocks it**; otherwise body progress lives entirely in
  Becoming.
- **The introduction** — existing users meet Body Vision through
  the migration-moment pattern (one-time, stamped); new users meet
  it post-purchase, day 2-3 (onboarding v7 is freshly locked and
  untouched — D8).
- Exit: timeline + compare frame-reviewed; the three questions
  table (`01_AUDIT.md` §6) gains a real left-column answer;
  W1→W2 retention instrumented (§7).

### P3 — Why am I changing? (M)

The explanation layer (W8, W9): one weekly read led by the
outcome, explained by mechanisms — rule-based, provenance-gated,
no LLM in the loop.

- **The weekly body review.** WeeklyReview and CoachSummary stop
  being parallel engines (W9): one weekly read leads with the body
  outcome (trend + scan cadence + composition-if-present via
  BodyStateService) and explains it from the week's inputs
  (protein-days-met, movement incl. strength sessions, sleep
  bands, medication adherence from dose observations, sugar
  timing) with the existing floors. The re-signing consent grammar
  is unchanged — still at most ONE proposed adjustment.
- **Muscle preservation, honestly.** A qualitative preserving/
  at-risk read from protein adequacy × strength-movement presence ×
  loss rate vs the 1%/wk guard (+ HK lean mass with provenance
  when her scale writes it). Wycherley-style citation chip.
  Never a number from a photo (L3).
- **Mechanism lines grow up, anti-blame intact.** BodyLine's
  juxtaposition law widens: a rising week may now speak *pattern*
  mechanisms with floors (late-window eating, sodium-heavy days
  once P5 lands) — timing-never-causality, never a single food,
  never on a day surface, only in the weekly read.
- **Chat knows.** CoachContextAssembler gains the BodyStateService
  read so jeni's letters can reference the real trend story.
- Exit: engine unit-tested against fixture weeks (target ~25
  tests); a recorded weekly-review walk; every sentence traceable
  to a collected field (provenance audit).

### P4 — What should I do next? — the Daily Focus (S-M)

- CarePlanEngine's promotion ladder (today: protein-only) gains
  the body-outcome axis from BodyStateService: scan-day, plateau-
  pattern, muscle-at-risk, recovery (short-sleep) — still ONE
  lead, still gentle-day law, still never debt (W9).
- The lead row gets the hero treatment on Home (visual promotion
  of the existing row — D1 scope); supporting/offered demote
  visually. The weekly read (P3) sets the week's theme; the daily
  lead serves it — one narrative spine, two cadences.
- Exit: promotion ladder unit-tested; founder frame-review of the
  Home change (D1).

### P5 — Food Vision: the explanation upgrade (M)

Food stops being parallel numbers and starts explaining (W8).

- **Kill the sodium dead-end**: finish the dormant
  `nutrition-lookup` EF (USDA/OFF server cache), populate + persist
  sodium/sat-fat additively (JSONL fields + additive cloud
  columns); the NutrientGrid "—" cells go live or go away.
- **Sync the story data**: sugar + per-ingredient detail join
  `food_logs` additively so the weekly read isn't blind (privacy
  review first — it's nutrition data, same class as existing
  macros).
- **Insight-first result**: the result card leads with the
  interpreted line and day-fit; the raw grid stays one tap deep
  (anti-shame floors untouched). "This supports your protein
  floor" lines connect plate → muscle-preservation story (L3
  language).
- **The weekly food-quality read**: qualitative bands (steady /
  protein-led / late-heavy), floor-gated, feeding P3 — explicitly
  NOT a score.
- Exit: EF deployed + contract-tested; result-card frame review;
  weekly read renders from synced data on a fresh install.

### P6 — B2B: the between-visit summary (M, founder+counsel-gated)

Extends Jeni Care with what clinicians actually asked the category
for (adherence, weekly summaries, dropout risk) without breaking
the consent posture (W10).

- **Longitudinal substrate**: additive `care_weekly_summaries`
  (insert-only, patient-side deterministic compute like the S3
  packet; no AI in the loop — law) OR packet history
  (insert-not-overwrite). Adherence/weight/engagement series per
  week, lookback-clamped.
- **Consume the idle seam**: the clinician patient view gains the
  trend panel via `care_get_patient_series` (finally consumed) +
  the weekly summary list.
- **Dropout risk, consent-honest**: ship the consent-compatible
  staleness line first ("last summary N weeks ago" — packet_meta
  already implies it). A true engagement-decay flag requires a new
  consent scope + reframed patient copy → **D6 (founder +
  counsel)**. Scans never appear in any clinic surface (L4).
- Exit: probe extended (security 97/97 + new checks), Playwright
  E2E, demo tenant updated; pilot docs amended.

### P7 — The design elevation pass (M)

The Apple-Design-Award sweep, screen by screen, with the existing
frame-review ritual: whitespace + photography share up (covers,
timeline), typography-ladder audit, transition/gesture audit
(recorded, frame-diffed), chrome reduction, Home density pass
(rings/signals/tools weight — within D1 scope). Opportunistic
eng-health: mechanical PlankAIApp.swift decomposition (no behavior
change). Exit: founder device walk + recorded reel.

## 3. What P0-P2 deliver together (the first visible v9)

Passive weight that just works → the guided scan → the timeline +
compare + cover. That is the brief's core loop ("I can actually
see myself changing") shipped in three increments, each guarded.

## 4. Migration + regression posture

- All schema changes additive + idempotent (house convention);
  zero rewrites of existing tables/models; food JSONL untouched
  except additive fields.
- Existing users: nothing moves or renames; new surfaces arrive
  via migration-moment; the locked Home changes only within
  whatever D1 grants.
- Rollout: debug override → entitlement → PostHog flag per
  surface; kill = flag off, no data loss (scans remain local).
- The funnel is guarded: onboarding v7 + keep wall untouched;
  V6Funnel events unchanged.

## 5. What deliberately does NOT change

Onboarding v7 machine + acts + data contract · the keep wall +
pricing + RevenueCat flow · AppPhase machine + three tabs · auth/
sync architecture + re-key law · chat + jeni-chat EF · the clinic
loop mechanics + consent model (except D6's gated addition) ·
design tokens, palette, identity, voice law, verb law · GLP-1
compliance floors · bundle id / project name / SKUs (deferred per
TODOS) · the 407-test suite stays green through every phase.

## 6. Verification law (every phase)

Full unit suite + new-engine tests · affected walker legs solo ·
recorded frame review for any new motion · a11y floors (contrast
tests, XXXL, VoiceOver labels) · erased-sim cold path for consent/
migration moments · performance frame-diff on capture + compare ·
privacy sweep test (sign-out/delete leaves nothing scan-shaped).
Implementation is TDD-first per house superpowers law.

## 7. Measurement (PostHog; no health values in events — v8 law)

`body_scan_first` / `body_scan_kept_weekly` (counts+flags only) ·
passive-weight share of weigh-ins · W1→W2 retention delta (the
known cliff) · becoming_open_rate · focus_follow_rate · funnel
conversion unchanged (guardrail metric) · B2B: summaries viewed
per clinician-week. Existing V6Funnel untouched.
