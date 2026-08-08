# Jeni v1.3.0 (28) — Launch Readiness Report

**Date:** 2026-08-08 · **Branch:** feat/app-v2 · **Product:** the v23
STILL LIFE build (v11→v23 line) · **Last shipped:** 1.2.0 (27),
2026-07-30.

**Recommendation: READY FOR TESTFLIGHT immediately. READY FOR APP
STORE after the founder-gate ledger (§4) — the app binary is sound;
what stood between this build and a submission was the compliance
paper layer and a set of durability/attribution defects, all fixed
in this pass (§3). The remaining gates are physically outside the
repo (ASC, dashboards, live site, sandbox devices).**

Audit shape: 8 parallel domain audits (crash statics, app-wide
security, auth lifecycle, data+sync+migration, RevenueCat, analytics,
App Store review, notifications+retention) + a diff-scoped security
review of all 56 unpushed commits + full test/Release-compile baseline
+ a 12-leg erased-sim runtime walkthrough. Everything below is
file:line-verified, not sampled.

---

## 1. Category verdicts

| Category | Before fixes | After fixes |
|---|---|---|
| Update safety (1.2.0 → this build) | **PASS** | PASS — SwiftData diff purely additive (one new entity); food JSONL decode-tolerant; lossless migration |
| Crash risk (static) | **PASS** | PASS — zero fatalError / try! / as! in first-party code; the one release-active crash line (SIWA nonce precondition) now falls back |
| Runtime QA (12 legs, erased sim) | **PASS** | PASS — camera primer, v8 onboarding walk, keep-wall trio (incl. pricing-fail + XXL), zero-data, core flows, every-surface, settings, body-scan proof, passive-weight proof, home anatomy |
| Security (diff, 56 commits) | **PASS** | PASS — no exploitable findings |
| Security (app-wide) | WARNING | PASS w/ 1 founder gate — safety_* sweep + photo-retention control + analytics de-prop fixed; **ElevenLabs key rotation = founder** |
| Authentication + account lifecycle | WARNING | PASS — offline sign-out fail-open, needsReauth persisted, deletion completeness (device + cloud), SIWA double-tap guard |
| Data integrity + sync | WARNING | PASS — care-chart retry sweeps, every-launch food push reconcile, sodium/sat-fat merge regression, profile hydrate guard |
| Subscriptions / RevenueCat | PASS w/ warnings | PASS — silent expired-wall restore now speaks; "30% off" literal corrected; RC re-key runs before hydrate; Ask-to-Buy classified everywhere |
| Analytics integrity | **FAIL** (2 critical) | PASS — phantom purchase_completed suppressed; onboarding_version=v8; PostHog reset at identity boundary; correction/mode/book/becoming signals restored |
| Notifications + retention | WARNING | PASS w/ 2 founder decisions — Day-1 promise delivery restored; opt-out cancels everything; saved hour honored; midnight rollover observed |
| App Store review + compliance | **FAIL** (3 critical) | PASS w/ founder gates — required-reason API removed; manifest declares tracking; policy + metadata rewritten in-repo; deploy/upload = founder |
| Accessibility | WARNING | WARNING — prior-era floors walked + keep-wall XXL leg green; **v23 food surfaces' XXXL floors remain the known queued gap** (see §5) |
| Performance | PASS (observational) | PASS — no regressions observed across legs/films; deep profiling deferred to device |

## 2. What the audits confirmed clean (no action needed)

- 1.2.0 users update **losslessly**: model diff vs the shipped release
  is one new entity (BodyScanRecord); JSONL entries from 1.2.0 decode
  and render in THE BOOK.
- Zero `fatalError`/`try!`/`as!` in first-party shipping code; all
  destructive/entitlement QA doors `#if DEBUG`-gated; timers/observers
  torn down; 0 operational prints in Release.
- Sessions live in the Keychain only; full ATS; no http endpoints; no
  cert overrides; no secrets in the shipped binary (public keys only).
- Body scans are genuinely local-first (upload guarded by the opt-in,
  default OFF; disable deletes cloud copies; EXIF stripped by
  re-render).
- RevenueCat: production `appl_` key; single entitlement source of
  truth; offerings-failure paths honest with retry; `.storekit` file
  wired to no scheme; no hardcoded prices in Release paths; billed-
  today + renewal wording + terms/privacy on the wall.
- Permission strings honest and complete (camera, HealthKit read+
  write, photo add-only, ATT); `ITSAppUsesNonExemptEncryption=false`;
  account deletion in ~3 steps with a server-side cascade RPC;
  anonymous-first (Review needs no credentials).
- Claims hygiene: zero "HIPAA", zero drug brand names, zero numeric
  weight-loss promises, zero "AI" in user copy, breathwork stays
  cortisol-mechanism.
- Notification hygiene: stable ids, surgical removals, no
  accumulation, timezone/DST-consistent day math, voice-law-clean
  copy.
- The 2026-07-25 auth fail-open fix is intact with zero regression.

## 3. The prioritized defect list (all fixed this pass)

### Critical

| # | Defect | Fix |
|---|---|---|
| C1 | `ProcessInfo.systemUptime` (v23 barcode throttle) is an undeclared required-reason API — ITMS-91053 upload rejection; manifest explicitly claimed non-use | Swapped to `Date.timeIntervalSinceReferenceDate` (not on Apple's list); manifest comment re-audited |
| C2 | Live privacy policy denies IDFA/TikTok/PostHog while the binary prompts ATT and ships both SDKs; Anthropic photo processing undisclosed | `docs/privacy_policy.md` rewritten truthfully (TikTok+ATT, PostHog, OpenAI+Anthropic, HealthKit, GLP-1 answers, retention control); **deploy = founder gate** |
| C3 | App Store metadata still sells the v1.0 plank product with a free trial (app is pay-upfront); reviewer notes describe a retired camera | v1.3.0 metadata + what's-new + reviewer notes drafted in `docs/app_store_metadata.md`; **upload = founder gate** |
| C4 | `purchase_completed` fired on restores, silent recovery syncs, and re-sign-ins — every reinstalled payer minted a phantom purchase | Suppression seam in PaymentService (in-flight flags + 30s window opened by restore/recovery/auth-change + all 4 view restore sites) |
| C5 | Canonical funnel stamped `onboarding_version: "v7"` while v8 is the live flow — the v7→v8 before/after unreadable | Stamp corrected to v8 |
| C6 | Live ElevenLabs API key in git history (committed, untracked later, never rotated; current `.env` still uses it) | **FOUNDER: rotate the key before any push/publication** — nothing in the shipped app references it |

### High

| # | Defect | Fix |
|---|---|---|
| H1 | Version still 1.2.0 (27) — upload refused | 1.3.0 (28), app + widget, Debug + Release |
| H2 | No `NSPrivacyTracking`/domains in the manifest while ATT + TikTok ship | Declared true + both TikTok domains; **ASC label re-answer = founder gate** |
| H3 | The entire `safety_*` family (pregnancy status, SCOFF ED screen, pace cap, numeric suppression) never swept — survived sign-out AND account deletion; next account inherited caps or skipped screening | `safety_` prefix + `program_mode` + `onb_v8_code_path` + conversion one-shots added to the sweep |
| H4 | Offline sign-out half-completed: local session destroyed pre-POST, sweep already run, no re-bootstrap — cross-account bleed chain | signOut fails open (mirrors bootstrap); local transition always completes |
| H5 | Delete-account left body-scan photos in cloud storage forever (RPC purged only food-photos; client purge was fire-and-forget racing session teardown) | `body-scans` added to the RPC + orphan reaper (**founder re-applies both scripts**); client purge now awaited pre-RPC |
| H6 | Delete-account left 5 SwiftData families on device (chat transcript, weight history, plans, checks, consents) | All five wiped in `clearLocalUserData` |
| H7 | Observations / regimen plans / consent grants had NO retry — an offline dose mark or medication plan stayed device-only forever | Three sweeps added to `retryPendingUpserts()` |
| H8 | Food-log rows had no durable retry for engaged users; anonymous users never reconciled (photos had a queue, rows didn't) | Every-launch push-only reconcile (id-select + set diff), anon included |
| H9 | Sign-in merge zeroed plate-level sodium + sat-fat (regression in the exact function whose comment memorializes the bug family) | Both fields carried through `reattributeEntries` |
| H10 | Fresh installs got ZERO Day-1 push: the promise sealed before the permission beat (never scheduled) and its stamp suppressed the fallback | Promise back-fills from the permission grant; promise id added to `cancelAll` |
| H11 | Master notifications toggle OFF left up to ~9 already-scheduled pushes firing over 7 days | Toggle-off removes ladder + knock + jitai ids |
| H12 | No `PostHogSDK.reset()` at identity boundaries — post-sign-out events (including another account's purchases) attributed to the old person | `Analytics.resetIdentity()` in the shared sweep |
| H13 | v23 went analytics-dark: corrections, label vs photo mode, barcode failure paths, first-scan activation via barcode, THE BOOK, Becoming | Correction event at the reading's commit seam; `mode` on scan started/completed; barcode fallback + first-scan calls; `food_book_opened` + `becoming_opened` |
| H14 | The expired wall's restore — the churned payer's primary CTA — swallowed both outcomes silently | Full alert pattern (no-sub found / failed), restore funnel events |

### Medium (fixed)

Photo-retention control was dead — default "discard after analysis"
while every photo persisted + uploaded (broken promise inside a
section titled "privacy"; camera string amended, control honored,
default "keep", unbackable 30-day tier retired) · RevenueCat re-key
ran AFTER the full cloud hydrate (purchase-orphan window + slow wall
flip; now first) · "30% off" literal vs computed 27% · Ask-to-Buy
classified as failure on the upgrade surface (+ that surface fired no
purchase events at all) · `purchase_completed` placement hardcoded
"onboarding_final" for every surface (now surface-accurate) ·
saved reminder hour silently discarded by the ladder (now honored) ·
Settings notification preview showed retired v1 copy (now renders the
real body builder) · evening review deep-linked to the CAPTURE CAMERA
(now the book/becoming) · app open across midnight showed yesterday
until touched (day-change observer added) · profile hydrate could
clobber a pending local edit (guard added, mirroring session logs) ·
deletion could report failure after the RPC succeeded (no rethrow) ·
`needsReauth` was in-memory only (persisted) · SIWA double-tap hung
the flow (continuation guard) + nonce precondition crash line
(CSPRNG fallback) · 5 ungated launch-arg doors incl. retired
onboarding flows (gated; ~5,700 lines out of Release reachability) ·
raw step counts + 0.1-precision TBWL% rode identified analytics
(bucketed/banded) · analytics coalesce data races (moved on-queue) ·
3 calendar force-unwraps · hearts + "JeniFit" in the consent sheet ·
terms/privacy links missing on the purchase-capable smaller-step
sheet · ladder greeting broke the lowercase voice law.

### Deferred (post-RC, documented rationale)

- Offline food-log DELETE has no tombstone — a plate deleted offline
  can resurrect on a later gated hydrate. Bounded: the gated hydrate
  rarely runs (empty-family + daily gate), and the new push reconcile
  cannot resurrect. Fix shape: pending-delete queue mirroring
  FoodPhotoSyncService's. Do before the next release.
- Anonymous→anonymous re-key on an SDK-initiated session wipe strands
  local data invisibly (rare rotation race). The merge machinery
  exists; wiring it into the recovery path deserves unhurried design —
  this is the app's most incident-prone seam (2026-07-25).
- `ModelContainer` creation failure is unhandled (crash-loop if it
  ever fails) + no versioned schema snapshot. Safe today (additive
  diff); snapshot a `VersionedSchema` baseline next cycle.
- 5-per-week notification ceiling is not enforced by construction
  (~10-17/wk possible for an enrolled+authorized user who stops
  opening the app) — **founder decision**: retire the spec law or give
  the ladder + evening review a shared budget.
- v8's unchecked-by-default signature row turns the first-days push
  family off for non-checking users — **founder confirm** this consent
  posture (it retires the v1.1.2 D1 lever in practice).
- Dead code an era behind: `RecapNotificationService` (no callers),
  first-log nudge (commented out), trial-notification family (no
  trial exists), ~25 dead analytics enum cases, `WallView`'s unused
  `onRestore` parameter. Delete in the next hygiene pass.
- RC splash safety-timeout awaits before flipping ready (cache-less
  install on a black-hole network can hold splash to the HTTP
  timeout); 72h stale-entitlement banner computed but unrendered.
- `jeni_chat_opened` fires per tab-visit (documented semantics).
- TikTok SDK initializes before ATT resolution (industry-standard;
  SDK gates IDFA on ATT internally). Optional: defer bootstrap.

## 4. Founder-gate ledger (ordered; the release path)

1. **Rotate the ElevenLabs API key** (C6) — before any push of this
   branch anywhere.
2. **Deploy the rewritten privacy policy** (+ refresh terms dates/
   prices with counsel) to jenifit.app — before submission (C2).
3. **Apply the two updated SQL scripts** to prod:
   `scripts/delete_user_account.sql` (body-scans purge) +
   `scripts/cleanup_orphaned_anon_users.sql`.
4. **Supabase state check**: `food-vision` EF deployed at/after commit
   `1afc7f5` (else plate sodium/sat-fat ride only the USDA/OFF sweep);
   apply migration `20260804090000_p6_weekly_summaries.sql`; confirm
   observations/regimen migrations are applied (they compound H7 if
   not); confirm the jenifit.app password-reset landing page exists
   (email-user recovery has no in-app completion path).
5. **RevenueCat dashboard**: current offering contains
   `jenifit_yearly_v2` + `jenifit_quarterly` + `jenifit_weekly_v2`,
   `discount` offering contains `jenifit_yearly_discount`; restore
   behavior = "Transfer to new App User ID"; decide the "money-back
   guarantee" honoring process (or soften that paywall line).
6. **PostHog**: add the founder + wife person-ids to Internal & test
   accounts (TestFlight builds are Release — client marks nothing);
   note dashboards anchored on `journey_*` / `food_im_out_*` /
   satiety events flatline by design after this update.
7. **ASC mechanics**: paste the v1.3.0 metadata + reviewer notes;
   re-answer the privacy nutrition label (tracking = YES via TikTok;
   health & fitness linked to identity); recapture screenshots from
   v23 UI (6.9" + 6.7" — the old spec is three redesigns stale);
   attach the three subscription IAPs to the submission; agreements/
   tax/banking current; re-run the age-rating questionnaire.
8. **Sandbox device legs** (03_RELEASE §11 + this audit): purchase
   each tier; Ask-to-Buy pending → approve; restore ×3 surfaces
   (fresh wall / expired wall — verify the new alert — / settings);
   delete+reinstall identity recovery; two-device entitlement; lapse
   mid-session; airplane-mode cold launch (paid: enters on cache ≤3s;
   unpaid: wall + retry).
9. **Device walks** (queued from v23): barcode/label against real
   packages + the live feed; XXXL floors on dial/reading/book; breath
   haptics.
10. **TikTok Events Manager**: watch for TestFlight-sandbox Purchase
    pollution + anomalous injected events (the SDK's embedded app
    secret is the accepted integration pattern; monitor, rotate if
    abused).

## 5. Verification record

- Baseline (pre-fix): app units 557/557 · PlankFood 106/106 ·
  Release-config device compile clean (first proof this era) · 12/12
  UI legs green on an erased sim.
- Post-fix: app units **557/557** · PlankFood **106/106** ·
  Release-config device compile **clean** · affected legs re-run
  solo: camera primer, **v8 onboarding walk**, keep-wall recovery,
  core in-app flows, settings walk, home anatomy — **all green**.
  (One chain run failed the v8 walk before the re-run: the chain had
  skipped the sim erase, violating the documented "erase
  stale-entitlement sims first" walker law — sim posture, not code;
  green on the erased sim. Lesson re-recorded.)
- Fixes landed as six thematic commits (ffbd030 → 90c9303), tree
  clean.
- Films/visual: v23 evidence films frame-reviewed in-era; keep-wall
  Dynamic Type XXL leg green post-fix; AX-XXXL captures of the
  program onramp and Becoming's landing clean post-fix (no
  truncation/overlap). The dial/reading/book at XXXL remain
  device-gated (§4.9 — v23's own queued deferral; the surfaces need
  camera/tap navigation a sim script can't drive).

## 6. Session security review (skill output)

The 56-commit branch diff was security-reviewed per the project's
security-review process: **no findings met the reporting bar.** The
one candidate (unencoded barcode payload → OpenFoodFacts URL) is
path-only on a hardcoded HTTPS host, defensively parsed, and never
reaches a filesystem path (photos key by fresh UUID).
