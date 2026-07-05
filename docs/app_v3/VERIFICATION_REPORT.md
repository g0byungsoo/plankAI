# app v3 — verification report

Date: 2026-07-05. Build: feat/app-v2 @ v1.1.4 (24), iPhone 16e sim
(iOS 18-era runtime) + QA-SE (small screen). Evidence lives in the
session scratchpad ledgers (paths below) and this doc's claims are
only what was actually observed.

## Unit tests

- FULL suite: **152 tests, 0 failures** (plankAITests, one run,
  post-all-changes). Includes AppPhase gating table (10), cross-
  account scoping (3), program pacing, goal floors, plus the new
  AppV3SpineTests (9: chapter table, standing thresholds,
  one-thing/rhythm partition across 3 tiers × 28 days, rest-day
  breath ask, presence once-per-day, break ranges, band zone table,
  crossing-once semantics, kept-week rule).

## Walker legs (XCUITest, fresh-booted sim)

- testHomeRowGesturesAndPastDay — PASSED (31s): past-day strip cell →
  review sheet → dismiss; long-press → mark-as-done foremost; tap
  after long-press enters the module (tap-swallow verified on the
  new rhythm rows).
- testWalkEveryReachableSurface — PASSED (156s, 20-shot ledger):
  Today top/band, steps sheet, mark-as-done, THE REP (method row),
  workout brief, snap entry, settings hub + 5 sub-screens, jeni
  empty/streaming/answer/tool-card, becoming top/journey/wins, food
  journal.
- **Full six-leg suite: ALL PASSED on one fresh boot** —
  testWalkEveryReachableSurface 154s · testStatesLedger 48s (wall
  fresh/expired + migration on this build) · testRestDayBreath 101s
  (the breath one-thing card end-to-end incl. the full session) ·
  testHomeRowGesturesAndPastDay 34s · testLivedDay 20s ·
  testLessonRepChip 36s (the NEW rep journey: door → response →
  "the whole idea" → reader → in-reader chip). The final ledger
  includes 94_rep_scenario → 95_rep_door_response (door chosen,
  mechanism line, NEXT chain, kept chip) → 96_reader_close_via_rep →
  97_lesson_rep_kept, and 90_wall_fresh (paywall intact, correct
  products) + workout completion.

## Gating flows

- Fresh wall: ledger shot 90_wall_fresh — founder-approved paywall
  renders (maya headline, projection, 3 tiers, $49.99 primary).
- Expired wall + migration: exercised by the states leg on this
  build (AppPhase machine untouched; its 10-case table green).
- Post-purchase first-run: unmodified this pass (deliberate; see
  PRODUCTION_SAFETY §5).

## Layout

- iPhone 16e: day 12 (protein), day 14 (rest), evening, break,
  keeping-reset reading, on-medication evening — all captured and
  reviewed at 1x (no clipping, no ellipsis, scrim fixes the
  status-bar collision).
- iPhone SE (QA-SE): today + evening captured — the reading wraps
  cleanly (two sentences + ♥ text-presentation), strip fits 7 cells,
  one-thing card intact, receipt + chips fit. Bonus: the SE run
  organically exercised the COMEBACK thread (2-day gap detection).
- Dynamic Type XL: relativeTo metrics wired on all new text; an
  explicit XL walkthrough is listed in HONEST_GAPS §16.

## Motion (recording → ffmpeg frames → pixel-diff)

- Cold open (SE, 13s recording, 4fps frames + 188×406 grayscale
  diff-sums): launch pink → loader cascade (wordmark first,
  affirmation rising at the +340ms beat — caught mid-rise at
  f_009, settled by f_012; July 5's rotation line "begin again,
  anytime." correct) → Today entrance burst → ease-out decay
  (141k → 18k) → **four consecutive zero-diff frames** (the screen
  truly rests — no idle churn, honoring the banned-motion list) →
  the state-band visibility awakening as the final wave.
- Strike/tick cascade + silk: mechanics unchanged from their
  frame-verified v2.7/v2.1 implementations (provenance: same
  components; silk re-anchored below the TextField this pass —
  see the yellow-field fix below).

## Defects found BY this verification (and fixed)

1. **The yellow journal field**: EveningClose's TextField rendered
   as iOS's uncomposable-view placeholder (yellow + prohibition
   glyph) because the jkSilk Metal layerEffect sat above it after
   the phase-2 restructure. Fixed (silk scoped to card+rows);
   before/after sim-verified.
2. **"today's today's lesson"** double possessive in MarkAsDoneSheet
   (pre-existing; visible in walker shot 03). Fixed.
3. **White-heart ♡ U+2661** in the safety check-in intro
   (pre-existing). Fixed to ♥ U+FE0E.
4. Coach-mark clipping + status-bar caption collision (pre-existing,
   captured in the audit): resolved structurally (mark removed with
   the design that made it unnecessary; masthead scrim added).

## Release config

- No new build settings, schemes, or Info.plist changes.
- All `--uitest-*` seeds remain #if DEBUG (unchanged); session QA
  used NSArgumentDomain defaults (launch-args only, unreachable on
  user devices).
- No new dependencies, no new network endpoints, no secrets (diff
  swept).

## Not verified this session (honest)

See HONEST_GAPS §Verification debt: onboarding→purchase E2E rewalk
(untouched code, last green 2026-07-03), Dynamic Type XL
walkthrough, continuous end-to-end recordings for snap/weight
(stills + walker-green; same archive status as v2.9), live-EF chat
turn (device-local mock verified; EF untouched and previously
live-verified in v3.0 doc 31).
