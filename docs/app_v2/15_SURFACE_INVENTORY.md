# 15 — Surface coverage inventory (v2.2 → v2.6 RC)

**v2.6 RC update:** the ledger now also carries 91 (setup
commitment), 92 (Becoming Sunday receipt block), 93 (the weekly
receipt card artifact), and the ✕ rows are GONE — PlanView,
AnalyticsView, and their private deps were deleted this pass (see
21 §6); the only remaining flag-gated legacy is onboarding v4.5
(pre-existing separate gate). Every surface reachable in production
is v2.

**v2.3 update:** the ledger below is superseded by the CURRENT-RUN
ledger (16 → 18+ PNGs from one fresh run of all three walker legs;
see 16_V23_NOTES for the leg map). Deltas vs v2.2: main walk now
clears the capture cover (the blocker was the consent sheet — whose
walk also caught two real defects: emoji-fallback hearts + dismiss
vocabulary); NEW current-run coverage for wall fresh/expired,
migration, program setup p1, workout completion (harness), rest-day
today, breath intro/session/receipt, food journal + meal detail,
day peek. The 12-file legacy sweep landed (16_V23_NOTES §sweep) —
the ✕ rows below shrink to the two founder-comparison clusters +
onboarding v4.5. The three "embarrass us" items are FIXED (workout
voice, setup chrome, journal masthead).

Date: 2026-07-03. The founder's ask: "if a screen exists, prove you
looked at it." Evidence classes: **[W]** SurfaceInventoryUITests PNG
(`/tmp/jenifit_inventory/`, walker in-repo), **[S]** settings walker
(InAppQAUITests.testWalkSettingsScreens, green, shoots hub + 5
sub-screens), **[M]** manual sim shot from this session's scratchpad,
**[F]** ffmpeg frame-dump + PIL pixel-diff, **[C]** code-audited only
(honest: not eyeballed this pass).

Verdicts: ✦ redesigned (v2/v2.1/v2.2) · ◐ partial (new grammar over
kept internals) · ● already met the bar (kept deliberately) ·
✕ legacy, dies at sweep · ▽ deferred (reason given).

| Surface | Verdict | Evidence | Notes |
|---|---|---|---|
| Today (top / state band / evening close) | ✦ | [W]00,01 [M] | v2 ritual + silk sweep [F] |
| Day strip + future-day peek / lock | ✦/● | [W] strip in 00; peek [C] | peek/lock sheets met bar (panel-designed); v2.2 rewired their taps; past-day browse intentionally dropped |
| Steps detail sheet (3 HealthKit states) | ✦ new | [W]02 | notDetermined state verified; denied/authorized [C] |
| Mark-as-done sheet | ● | [W]03 | sticker anchor + on-token; verified |
| Lesson reader (CBT) | ● | [W]04 | already premium (paper canvas, shaders); reader-length audit open |
| Workout brief (PreRoutine) | ✦ | [W]05 | v2.2: stat cards + tip box → receipts + serif line. Legacy sentence-case workout DESCRIPTIONS = content follow-up |
| Workout player (RoutineSessionView) | ● | [C] + prior QA | 1,105-clip voice system; chrome consistent; untouched by design |
| Workout celebration (PostRoutine) | ✦ | [C] build-verified | v2.1 typographic hero; sim shot deferred (needs a completed session — walker can't safely run a 10-min workout) |
| Snap camera entry + consent | ◐ | [W]06 | v1.2 flow kept (world-class result carousel [M prior]); entry verified |
| Snap result carousel / edit / share | ● | [M prior sessions] | THE keeper surface |
| Food journal (rows + page) | ✦ rows / ◐ page | [C]+[M rows] | v2 catalog rows; page chrome rides package header — sweep-adjacent |
| Quick add / recent meals | ● | [C] | v1.2 register |
| Jeni chat (chips, streaming, prose, tool cards) | ✦ | [W]07-09* [M] | *this run died at capture-cover dismissal before jeni stops; prior-session shots cover streaming + tool card; mock + live transports |
| Chat failure states (404/429/offline) | ✦ | [C] copy-designed | EF-absent path exercised earlier via mock-off?; friendly lines verified in code + audit |
| Becoming (insight layer) | ✦ | [M v21_becoming_rich] | v2.1 rebuild |
| Method journey card | ✦ | [M] | in becoming shot |
| Wins / journal chain | ✦ | [C]+[M] | provenance-gated |
| Settings hub + my pace / coach / reminders / food / account / feedback | ● | [S] green | pre-v2 clean-luxury pass holds; reachable from BOTH tabs now |
| Delete account / debug auth | ● / n-a | [S]+[C] | |
| Onramp (pre-enrollment) | ✦ | [M p2 + build] | v2.2 receipt grammar |
| Program setup subflow | ▽ | [C] | 784-line enrollment flow, functional + safety-gated; full v2 reskin deferred (highest-risk × lowest-reach: most users enroll once) — next pass |
| Paywall (fresh wall) | ● | [M p2_wall_fresh] | founder-approved 2026-06-29 design, now a destination |
| Expired wall | ✦ new | [M p2_wall_expired] | reactivation state |
| Migration moment | ✦ new | [M p8_migration_v3] | single-beat; 3-beat on founder call |
| Post-purchase first-run | ◐ | [C] | forging/coach-intro/breath kept; PostHog shows it works (80% follow rail); rebuild deferred deliberately |
| Chapter complete (graduation) | ▽ | [C] | earned-moment surface, on-register per code; unreachable in walker (needs day > totalDays); next pass |
| Breathwork intro/session/receipt | ● | [C] + 69% completion data | flow performs; chrome consistent; "reset-tool" contextual reframe = designed into breath beats (stress days) not a new surface |
| Notifications (delegate, deep links) | ✦ | [C]+tests | queued-until-main verified by phase tests |
| JeniKit gallery | ✦ | [M jk_gallery_*] [F silk] | the kit itself |
| Legacy: PlanView / AnalyticsView / MainTabView / Home cards / plank session trio / PremiumWelcome / BreathLibrary / OnboardingView v4.5 | ✕ | flags only | ZERO reachable without debug flags (verified: TodayHost/BecomingHost/RootView switches); the kill list, founder-gated |

## Known walker gaps (honest)

The inventory walker currently dies dismissing the full-screen
capture cover (covers don't drag-dismiss; the camera consent CTA
labels need adding to closeSheet) — jeni/becoming stops after it are
covered by prior-session shots instead. Fix is mechanical; the
walker + PNG ledger are in-repo for every future pass.

## What would still embarrass us in an App Store screenshot

1. Workout preset DESCRIPTIONS (sentence-case, "Builds the muscles…")
   inside the redesigned brief — content strings, not chrome.
2. Program setup subflow typography (deferred above).
3. The journal page header (package-side, sweep-adjacent).
Everything else reachable speaks v2.
