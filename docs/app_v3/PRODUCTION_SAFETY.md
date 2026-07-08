# app v3 — production safety report

Date: 2026-07-05. Scope: every change on feat/app-v2 from commit
2d22da7 (past-day review) through this report. Verified against the
founder's 14 constraints; evidence per item. The full invariant map
(file:line) lives in WORKING_NOTES.md §production.

## The 14 constraints

1. **Unpaid users cannot bypass the paywall.** UNTOUCHED + verified.
   AppPhaseMachine.derive is the sole gate and was not modified;
   AppPhaseTests (10 cases) green in every phase commit. All gates
   read `effectiveHasProAccess` (DEBUG-only overrides compiled out of
   Release); MainShell's independent second check untouched. No new
   gate was added anywhere in v3 code.
2. **Returning paid users don't see the paywall.** UNTOUCHED.
   Cold-start entitlement seed + auth-transition hold + readiness
   gate unmodified. Payment/ has zero v3 diffs.
3. **Expired users hit a hard wall.** UNTOUCHED; states walker leg
   captures wall(.fresh) + wall(.expired) on the final build.
4. **Legacy paid upgrade moment.** UNTOUCHED. MigrationMomentView +
   the two appV2SeenAt stamp sites (MigrationMomentView.complete,
   MainShell.onAppear) unmodified.
5. **New-user first-run.** Audited, deliberately unmodified (80%
   follow the rail per PostHog). Day-0 findings documented in
   research; anchor-ask experiment listed in HONEST_GAPS.
6. **Onboarding data wired.** DATA_CONTRACT untouched. v3 reads
   cohort keys ONLY through CohortStore; two sites that still read
   the zero-writer `CohortFlags.fromAppStorage()` were FIXED to
   CohortStore (cohort lesson variants had silently resolved on
   defaults — a correctness improvement, not a contract change).
7. **Supabase data correct.** NO schema, RLS, sync-path, or EF
   changes. All new v3 state (presence marker, break ranges, sit
   notes, band settle/zone) is deliberately DEVICE-LOCAL
   UserDefaults; each new key family was added to the sign-out sweep
   (AppSync scopedPrefixes: presence. / break. / day.sit. / band.)
   in the same commits that introduced them. CrossAccountScopingTests
   green in the full suite (152/152).
8. **jeni-chat caps + safety.** EF untouched (caps, key custody,
   model env, telemetry). CoachContext gains additive fields
   (chapter / band_zone / kept_days / on_break) INSIDE the existing
   data-not-instructions fencing; no prompt or contract change; no
   redeploy required for correctness (fields are context, not
   instructions). Crisis/ED client pre-filter untouched.
9. **Food vision functional.** Packages/PlankFood untouched this
   pass. The founder's pending `supabase functions deploy
   food-vision` item is unchanged.
10. **Notifications useful + safe.** Ids unchanged (no 4-site
    protocol churn). New GUARDS only: BreakState silences the anchor
    ladder, winback, evening review, and Sunday recap — all fail
    toward silence, never toward spam. `refreshDailyAnchor` remains
    wired from TodayView.refresh() (verified in the rebuilt file).
    Trial-window + day-5 anti-refund logic untouched. Presence
    milestones self-heal marks passed milestones done so the count
    migration can never fire a surprise celebration push.
11. **No cross-user leakage.** Every new identity-scoped key swept
    on sign-out (item 7). No new SwiftData reads without userId
    predicates (v3 added no new fetches outside PresenceLedger's
    migration, which filters by userId).
12. **No mock/test flags in release.** No new DEBUG bypasses. QA
    state used in this session (`-safety_checkin_seen`,
    `-program_mode`, `-band.settleWeightKg`, `-break.activeSince`)
    rides the NSArgumentDomain — launch-argument-only, unreachable
    for end users on device, same class as the pre-existing
    `--onboarding-v4` arg. `--uitest-*` seeds remain #if DEBUG.
13. **No bundled secrets.** No new keys, endpoints, or config.
    Swept the diff for sk-/service_role/API keys: none.
14. **Existing users not broken.**
    - SwiftData: ZERO model changes (no new @Model, no renamed
      fields) — every v3 primitive is UserDefaults. Lightweight
      migration surface untouched.
    - Presence self-heal: one-time, flag-guarded, derives the count
      UP from real records (a lesson-only user's "shown up" count
      can only rise), marks passed milestones done.
    - The beats ENGINE composition is unchanged (same beats, same
      cadences); v3 re-expressed the RENDER. Long-press override,
      strike mechanics, module covers, completion writes all flow
      through the same ProgramService/markChecklistItem paths.
    - PrescriptionEngineV2 API extended (oneThing/rhythm computed
      properties) without altering compose() output — engine
      unit tests green.
    - Legacy escapes (`--onboarding-v4`) untouched.

## Founder deploy dependencies (unchanged from 13_DEPLOY_SAFETY)

- `supabase functions deploy jeni-chat` + the 20260703 migration SQL
  (chat caps count real traffic once applied).
- `supabase functions deploy food-vision` (photo+text context).
- RevenueCat offering `default` with jenifit_yearly_v2 /
  jenifit_weekly_v2 / jenifit_quarterly; entitlement `pro`.

## Residual risks (honest)

- The presence self-heal runs at first snapshot after update; on
  very large food journals it walks all entries once (bounded by
  JSONL size; O(entries) string ops). Acceptable; noted.
- BreakState.begin removes pending notification requests directly;
  if a future id joins the uninvited set it must be added there
  (single site, commented).
- The band's evidence base is behavioral-loss maintenance, not
  post-drug RCTs; copy never claims clinical validation (fence in
  BandModel header + thesis §7).
