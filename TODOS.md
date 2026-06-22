# TODOS

Last updated: 2026-06-21 (v1.1.1, build 21)

Refreshed punch list. The exhaustive pre-TestFlight checklist + JeniFit
Method Phase 8 unblock playbook + Phase 4/5/6 image swap items that
filled previous versions have all shipped — they live in the git
history if needed. The list below is what's actually open as of
v1.1.1, organized by horizon.

For broader strategy + open feature ideas see
`docs/jenifit_v2_strategy_2026_06_13.md` and
`docs/feature_gap_synthesis_2026_06_16.md`.

---

## Open now (post-v1.1.1, small)

### Snap Food manual retry + photo cache
**What:** Add a user-facing "try again" button on the snap-food
result screen when the vision pipeline times out or returns
low-confidence. Cache the captured photo so retry doesn't require
re-shooting.
**Why:** Vision-retry-on-timeout was wired (task #6) but if both
attempts fail, the user has no recovery path beyond reshooting.
**Status:** Deferred from the v1.1.1 audit (task #9). Small, ~half
day. Files: `Packages/PlankFood/`.

### Coach imageset @1x decision
**What:** Three coach imagesets (`coach-jeni`, `coach-kira`,
`coach-matson`) ship a `@1x` slot pointing to a real photo while
`@3x` is the flat-vector illustration shown elsewhere. Modern iPhones
use `@3x`; old iPads use `@1x` (different image). Likely leftover
from design exploration.
**Why:** Drop the `@1x` to save ~1.1MB and ensure all devices show
the illustration.
**Status:** Pending intent confirmation. One-line decision.

### Position-block ordering visual validation
**What:** Runtime visual validation that workout sessions render the
position-block order (standing → quadruped → plank → prone →
sideLying → supine → seated) the engine produces.
**Why:** XCTest target covers parameter grid + edge cases; visual
ordering is the one thing that only shows up at runtime.
**Status:** Highest-EV item from the engine work. Manual device QA.

### ElevenLabs voice clip generation
**What:** Run `Scripts/generate_voice_clips.sh` against ElevenLabs to
materialize 384 prep_short + 384 prep_full + 6 switch_sides clips.
**Why:** Voice cascade in code is wired; fallback to legacy
`intro_<id>` works for the 24 clips that exist today. Materializing
the full set completes the rules §7 voice window-aware cascade.
**Status:** Founder-handled (API credential). Cascade ships either
way.

---

## v1.2 candidates (deferred + actionable)

### Bundle ID + Xcode project rename
**What:** Rename `com.bk.plankAI` → `app.jenifit.ios` (or final value)
and `plankAI.xcodeproj` → `JeniFit.xcodeproj`.
**Why:** Bundle ID changes require App Store Connect transfer
(~5 business days) or shipping a new app at the new Bundle ID with a
redirect from the legacy app. Xcode project rename forces every dev
to re-clone or rewrite xcuserdata.
**Status:** Pair with the SKU rename below. Coordinate so users only
re-onboard once.

### Subscription SKU rename
**What:** RevenueCat product identifiers carry legacy
`absmaxxing_*` names. Rename to `jenifit_*` (or final SKU naming).
**Why:** Renaming SKUs on a live ASC listing requires creating new
products, dual-listing both for a transition window, migrating
existing subscribers via RC's product-rename flow. Safer post-launch
than mid-v1.0.
**Status:** v1.2 pair with Bundle ID + Xcode rename. Coordinate
with `.storekit` file rename + asset catalog cleanup.

### Trial-end notification identifier rename
**What:** `TrialEndNotificationService.identifier` is hardcoded to
`"absmaxxing.trial.ending.reminder"`. Rename to
`"jenifit.trial.ending.reminder"`.
**Migration:** On first launch under the renamed identifier, call
`removePendingNotificationRequests(withIdentifiers: ["absmaxxing.trial.ending.reminder"])`
once before scheduling under the new ID. Without that, existing
users get either a duplicate or an orphaned scheduled notification.
**Status:** Pair with the SKU + Bundle rename so namespace cutover
happens once.

### Cross-device trial-end notification scheduling
**What:** Trial-end reminder schedules per-device via
`UNUserNotificationCenter`. Users who start a trial on iPhone but
only check iPad won't see the 24h reminder on iPad.
**Why:** Local notifications don't sync across the user's device
set. Server-side schedule (Supabase Edge Function + APNs push, keyed
on `auth.uid()` + RC webhook trial expiration) reaches every device.
**Status:** Per-device coverage is sufficient for v1.x; most users
start the trial on the device they primarily use. v1.2 follow-up if
analytics flag the gap.

### OnboardingData weight fields → optional
**What:** `OnboardingData.currentWeightKg` and `goalWeightKg` are
non-optional `Double` with defaults `65` / `60`. Every user who
didn't touch the weight sliders ships with `65 / 60` indistinguishable
from a user who actually weighs 65kg.
**Fix:** Change to `Double?`. Slider screens use a "tap to set"
affordance (initially blank, populates on first interaction).
Supabase columns already nullable.
**Why:** Analytical cohorts that derive insights from weight can't
filter out untouched-default rows.
**Status:** Surface when analytics work requires clean cohorts.

### EditProfileView legacy-user fallback
**What:** `EditProfileView` reads/writes `bodyFocus`. Legacy users
with empty `bodyFocus` AppStorage see no preselected option.
**Fix:** One-shot inference — if `bodyFocus.isEmpty` and `userGoal`
is set, derive a best-guess `bodyFocus` and write it back.
**Status:** Pre-rebrand testers were too small a cohort to matter;
revisit if user reports surface.

### RevenueCat anonymous → authenticated identity merging
**What:** Use RC's identity linking so anonymous-period entitlement
state merges with the authenticated user on sign-in.
**Why:** Today, an anon user who somehow purchases (rare — paywall
is post-onboarding which follows sign-in path) leaves an orphan RC
customer record that doesn't carry forward.
**Status:** Defense-in-depth for an edge case structurally unlikely
in our flow. v1.2 follow-up.

### Anonymous → authenticated data preservation (validation)
**What:** Untested code path. If users report data loss after
signing in following an anonymous-only period, add migration
UPDATE statements in AuthService upgrade methods.
**Why:** Supabase docs claim automatic preservation; should never
need to run. Defer until real reports surface.
**Status:** Validation only. Defer.

---

## v2 strategy items

Sourced from `docs/jenifit_v2_strategy_2026_06_13.md` +
`docs/feature_gap_synthesis_2026_06_16.md`. Read those for full
context. Items below are the highest-leverage ones the strategy
docs converged on.

### Sprint A — trial-conversion (next 30 days, ~8 dev days)
- In-trial Day-1/2/3 notification + reframe sequence (most copy
  shipped per the notification spec; sequence timing tunable).
- US-only 3-vs-7-day trial A/B (RC dashboard, no code).
- Three CPP variants (Apple Custom Product Pages — no code, ASA
  setup).
- `$34.99 / $47.99 / $59.99` annual price-anchor test (RC
  dashboard).
**Expected lift:** +15-35% relative trial-to-paid, US closing
30-50% of the gap to PH/SG/UK.

### Convergent stack (Phase 1, weeks 1-3)
The 11 features that serve 2 or 3 cohorts at once. Ranked at
`docs/feature_gap_synthesis_2026_06_16.md`. Highlights:
- **Cohort onboarding question** — already shipped; the
  `onboarding_glp1_status` key feeds `Glp1Cohort`.
- **Food noise / hunger-return tracker** (4-5 days) — net new
  field. Trivial schema add.
- **Adaptive protein floor** (1-2 days) — food rail tracks; goal
  is generic 100g today.
- **Pre-eat permission card** (3-4 days) — pre-eat mode ships;
  needs Home promotion + Jeni voice + 3 response variants.
- **Daily Plate Score** (5-7 days) — scrapbook polaroid layer
  exists; daily-collapse missing.
- **Weekly recalibration / regain-risk card** (5-7 days) — engine
  exists in `ProgramGoalCalculator` + EMA; surface is gap.
- **Cohort-aware Jeni voice + lesson sequence** (5-7 days) — 42
  Grok photos shipped; need cohort routing.
- **Silent-week re-engagement** (2 days) — `CancellationWinbackSheet`
  exists; silent-week detector net new.
- **Sleep-as-leading-indicator card** (2-3 days) — `SleepService`
  + `LastNightSleepCard` in current diff.
- **Citation footer on research-backed claims** (2 days) —
  breathwork + Becoming already cite; CBT lessons need it.

### Cohort-specific (Phase 2-3)
- **12-week Keep-It-Off curriculum** (post-GLP-1 wedge) — JeniMethod
  infra exists; need curated 12-week sequence.
- **"We're not Calibrate" non-Rx trust strip** (paywall + settings)
  — 1 day.
- **30-day "first month off" milestone** — earned-moment scatter
  pattern shipped, new trigger.
- On-GLP-1 specific stack (injection ritual + nausea management +
  dose-aware behavior) — 12 features, Phase 3 (weeks 6-10).

### Strategic bets (12-month)
- **Sister-cohort SKU** — 10x LTV bet per v2 strategy.
- **Calorie scanner accuracy as moat via user-correction flywheel**
  — every correction makes the next scan better for everyone.

### Compliance + safety floor
- **Onboarding injury screen** — P0 release blocker before any
  v1.1.x lesson copy adjusts pacing for med-risk cohorts.

---

## Process notes (sticky)

### Payment Phase E — scheme StoreKit Configuration (per-dev)
**What:** In Xcode: Product → Scheme → Edit Scheme → Run → Options
→ StoreKit Configuration → select `absmaxxing.storekit`.
**Why:** Without this, running from Xcode hits the live App Store
sandbox (requires real sandbox tester accounts). With it, purchases
simulate locally via the `.storekit` file.
**Status:** One-time per dev. Manual because scheme is per-developer
(xcuserdata).

### Voice clip orphans (~3-5MB)
**What:** 63 base names with no code reference in
`PlankApp/Resources/VoiceClips/`. Audit details preserved at
`docs/archive/voice_clip_orphans_2026_06_01.md`.
**Status:** Not actioned. Per-file savings too small to justify
false-positive risk. Bundle with next ElevenLabs re-recording run
OR with an On-Demand Resources migration (see
`docs/odr_migration_plan.md`).
