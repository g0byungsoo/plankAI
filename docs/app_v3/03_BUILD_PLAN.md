# app v3 — build plan

Date: 2026-07-05. One commit per phase (ONE xcodebuild per batch);
each phase leaves the app shippable. Production-safety obligations
from WORKING_NOTES.md are pinned inline. UI phases end with
same-session simulator screenshots; motion phases end with
recordings + frame dumps.

## Phase 1 — the spine (logic only, heavily tested)

1. `Chapter` (losing / onMedication / keeping) derived in
   CohortStore from glp1_status + program_mode. Table tests.
2. `DayStanding` (kept / partial / quiet) — one calculator, one
   threshold table (any meaningful action counts: snap / lesson or
   rep / workout / breath / weigh / steps-crossed). Consumed later
   by strip, review, receipt, week, wins. Table tests.
3. Shown-up redefinition: KEPT DAYS — lifetime presence count
   derived from real records (not the workout-only counter), never
   resets; weekly rhythm target with 2 built-in rest days;
   automatic repair on return. Keep `recordShownUpDay` API +
   milestone pushes working; self-heals existing users. Tests.
3b. "On a break" state: one flag + expiry, read by the engine
   (permission composition), the strip (no hollow-dot accrual), and
   every notification scheduler (all sleep). Identity-scoped key →
   AppSync sweep list, same commit. Tests.
4. Steps-goal single source: WeekState + TodayStepsSheet read
   TargetsService (kill hardcoded 7500s). Tests.
5. ReadingEngine: DailyBriefEngine grows to emit
   `Reading{sentences, italic, mechanism?, chatSeed, oneThingKey}`
   + `receipt(for:)` + `weekStory()`. Deterministic, provenance-
   only, chapter-aware. The SAME engine feeds Today, jeni
   letterhead, notifications, Sunday. Golden-file table tests per
   chapter × state.
6. One-thing selection: formalize hero split in PrescriptionEngineV2
   (`oneThing` + `rhythm`), rest-day = permission (no ask). Tests.

## Phase 2 — Today, reading-first (the feel change)

- Reading block (two-beat settle) replaces JKCoachLine hero use.
- ONE THING card (filled container, exhale-to-receipt on done).
- Rhythm rows: JKBeatRow restyle (quiet glyph, no at-rest circles,
  no thumb stickers, strike kept, long-press override kept).
- Strip: standing dots on past days, dimmed future numerals, locks
  and lock-sheet die (peek copy covers far-future).
- Evening: receipt leads after 18:00; one thing softens.
- Masthead status-bar scrim; coach mark removed.
- Band: "close enough" state words; under-target evening net
  (on-medication/restrictive chapters).
- PINNED: re-wire recordShownUpDay (new def) + markSessionCompleted
  + NotificationOrchestrator.refreshDailyAnchor into the new
  surface. Dead beat cases + duplicate title metadata die.
- Walker leg updates + screenshots (16e + SE) same session.

## Phase 3 — the rep (method becomes practice)

- Manifest `rep` schema (scenario, doors[2-3] each with mechanism
  line, keptLine, readerSlot) + content for the doc-22 ten.
- RepView cover: scenario serif, OV5 cross-off doors, mechanism
  rise, kept chip, "the whole idea →" reader door.
- ONE MethodResolver (kills the three divergent resolvers);
  completion writes ProgramDayCheckRecord only (JeniMethodState
  becomes read-legacy); legacy ritual fallback removed.
- Method beat → rep when rep exists, else reader.
- Tests: resolver table; rep routing; walker leg.

## Phase 4 — chapters (the strategic bet)

Keeping:
- BandModel (settle-weight derivation + explicit set; zones ±3 /
  3-5 / 5+ lb; crossing detection on EMA, not raw). Table tests.
- Canvas band field render (tint zones, tracked-caps labels).
- Zone-crossing actions: drifting → steady-week thread (reading +
  lighter composition + jeni seed); reset → supported multi-week
  arc flag + reading register. Never alert-only.
- Kept-weeks scoring; weigh-pattern-break named gently.
- Entry ask: "hold here, or keep going?" (migration + goal-reach +
  cohort=past onboarding echo). Graduation moment (earned scatter).
On-medication:
- Protein floor hero framing (band + reading); "how did it sit?"
  chip on plate detail (device-local, optional); appetite self-note
  (optional); patterns reflected only from HER logs (never asserted
  cycles).
Compliance pass on every new string (no dosing, no brands, no
numeric WL claims, adequacy framing).

## Phase 5 — the voice surfaces (jeni tab + day 0)

Jeni tab: letterhead reading · HER FILE receipt card (chapter/pace/
protein/band/promise rows → tappable) · collapse once conversed ·
chips kept. No transport/EF changes; caps untouched.
Day-0 first paid session (55% of trial cancellations are day 0):
meet the reading (demo meal + promise hour cited) → first two
things (breathe now · snap tonight) → first kept moment → THE
ANCHOR ASK (her hour, one tap; the Calm pattern). Reuses the
existing postPurchase.firstRunPending handshake (both ends kept).
One-word check-in chips land in the reading tail / receipt.

## Phase 6 — becoming, the story

Band overlay (keeping) · raw-number de-hero (receipt row) · wins →
DayStanding · one-fact-once pass · Sunday receipt elevation.

## Phase 7 — notifications orchestrator

Bodies from ReadingEngine (push == in-app line) · triggers: daily
anchor (reading teaser), promise hour (kept), comeback (kept),
Sunday story, keeping zone-crossing + weigh-pattern break, lapse-
support ping (weeks 0-6 only; her usual hour + evening; offers the
reset tool) · milestone bloom week 1 · anchor-ask surfaces at the
end of the first completed ritual · hard caps (≤1/day uninvited) ·
"on a break" sleeps everything · 4-site id-change protocol
respected · deep links queued-to-main (kept).

## Stretch (documented, not this pass unless time allows)

Home-screen widget (ritual state + kept days; new target + app
group — scope risk, high ambient value). HealthKit body-mass
import. Cross-device chat sync.

## Phase 8 — craft pass

Glyph sweep (♡→♥︎ incl. safety intro; FE0E render verification) ·
plate letter-tile fallback design · dynamic type XL + SE sweep ·
reduce-motion audit · VoiceOver labels (rows announce state; band
zones by name) · empty/error/offline states per design doc ·
clipping contract on new components.

## Phase 9 — verification + reports

- Full unit suite + all walker legs green on one fresh sim boot.
- Flows: fresh onboarding → paywall → paid Today · returning paid ·
  expired wall · migration moment · every module open/complete.
- Motion: recordings → ffmpeg frame dumps → pixel-diff reads for
  reading settle / one-thing exhale / rep doors / band draw / silk.
- Layout: iPhone SE + 16 Pro Max ledgers.
- Release config: DEBUG-gating audit, no mock flags, secrets sweep.
- Deliverables: VERIFICATION_REPORT.md · PRODUCTION_SAFETY.md
  (14 founder constraints, evidence per) · HONEST_GAPS.md.

## Standing rules

- SwiftData: additive-nullable only; food models stay out of the
  container; no @Model renames.
- New identity-scoped @AppStorage keys → AppSync
  clearOnboardingUserDefaults sweep list, same commit.
- Every gate reads effectiveHasProAccess; no new gates.
- appV2SeenAt stamping untouched; AppPhase machine untouched.
- EF contracts untouched (jeni-chat / food-vision); founder deploy
  checklist unchanged (13_DEPLOY_SAFETY).
- Voice floors on every string; provenance on every number.
