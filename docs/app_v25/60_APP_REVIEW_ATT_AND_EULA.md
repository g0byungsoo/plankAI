# 60 — APP REVIEW: THE ATT PROMPT AND THE EULA LINE

**2026-08-28 · feat/app-v2 · answers the rejection of 1.1.7 (35),
submission b7b6a6d4-914a-44d0-b391-58d18db9aeef (iPhone 17 Pro Max on
iOS 26.6.1 · iPad Air 11-inch (M4) on iPadOS 26.6).**

Two guidelines, one code fix and one metadata fix:

- **2.1 Information Needed** — "unable to locate the App Tracking
  Transparency permission request."
- **3.1.2(c)** — "metadata does not include a functional link to the
  Terms of Use (EULA)."

---

## 1. Root cause of the ATT rejection (evidence, not speculation)

The app declares tracking (ASC label + `PlankApp/PrivacyInfo.xcprivacy`
`NSPrivacyTracking = true`, TikTok domains listed) and ships the TikTok
Business SDK 1.6.1. Apple therefore expects to SEE the prompt. It could
not, because:

1. **The only `requestTrackingAuthorization` call in the binary lived
   at 30% of the plan-building loader**
   (`BuildingPlanLoadingView.swift`, fired from `runChoreography()`),
   which is reachable ONLY by:
   - completing the ENTIRE v8 consult (minutes of interaction), and
   - passing the safety gate on the `.loss` path — `.maintenance`
     (pregnant/BF/ttc/low-BMI), `.recovery`, `.blocked` and
     `.clinicianFirst` park on dead-end terminals that never reach the
     reveal, and
   - being a true first-run: returning, expired, and restored users
     land on `.wall`/`.main`, which requested ATT **nowhere**.
   A reviewer who abandoned the consult, answered a safety question
   conservatively, or launched into a restored state never met the
   prompt. TikTok SDK 1.6.1 never auto-presents ATT
   (`TikTokConfig.h`: "SDK won't actively call ATT dialog"), so there
   was no other path to a dialog.

2. **TikTok initialized before ATT on every launch** —
   `PlankAIApp.init()` ran `bootstrapTikTok()` unconditionally
   (detached task, milliseconds after launch) with Install + Launch +
   2DRetention + Purchase auto-tracking enabled. Tracking-capable
   collection ahead of the prompt is exactly what 5.1.2 forbids and
   what makes a "we can't find the prompt" rejection stick.
   (Mitigating but not exculpatory: because the tracking domains are
   declared in the privacy manifest, iOS itself fails pre-authorization
   connections to `analytics.tiktok.com` / `business-api.tiktok.com` —
   the SDK still initialized and collected pre-consent.)

3. **Simulators hid the defect**: the sim's "Allow Apps to Request to
   Track" default leaves the request resolving instantly without a
   dialog, so no film pass or walker ever saw the prompt either way.

## 2. The fix — ATTService, one source of truth

New `PlankApp/Analytics/ATTService.swift`:

- **`ATTFlow`** — a pure value-type decision core (the iOS 26.2 sim
  aborts on @MainActor class deinit, so no class):
  `.notDetermined` → request exactly once per launch; any resolved
  status → never; tracking SDKs may start only after resolution, once;
  a request RESULT of `.notDetermined` (iOS declined to present — app
  not active) re-arms the request for the next scene activation, while
  a real answer is never re-asked.
- **`ATTAuthorizing`** protocol seam over `ATTrackingManager` so the
  logic is testable (`SystemATTAuthorizer` in production).
- **`ATTService`** (@MainActor enum facade) — owns the prompt, the
  analytics events (`att_prompt_shown` / `att_result`, `context:`
  "launch" or "building_loader"), and the TikTok start gate.

Wiring:

- **`RootView` (PlankAIApp.swift)** — `.task(id: attRequestGate)`
  where `attRequestGate = scenePhase == .active && currentPhase !=
  .booting`. The prompt fires at the FIRST SETTLED SURFACE of any
  launch — onboarding arrival, proof, wall, migration, or main — after
  one fixed 0.6s settle beat (never mid-cross-fade, never over the
  affirmation loader, never while inactive). Deliberately NOT
  `AppPhaseMachine.isStable` (that excludes `.wall` for phase-hold
  reasons); an expired payer parked on the wall must still meet the
  prompt.
- **`PlankAIApp.init()`** — `ATTService.configure(startTrackingSDKs:)`
  replaces the unconditional TikTok bootstrap. Already-resolved status
  (every launch after the answer) → TikTok starts immediately, same
  timing as before. Unresolved → TikTok starts the moment the prompt
  resolves. SKAdNetwork support stays enabled (SKAN needs no ATT; the
  SDK registers it at init, a few seconds later on first run only).
- **`BuildingPlanLoadingView`** — its call now routes through
  `ATTService.requestIfNeeded(context: "building_loader")`; normally a
  no-op (already resolved at launch), kept as the secondary belt.
- **DEBUG-only automation suppression** — the prompt is skipped under
  the XCTest host or any `--uitest*`/`--debug*`/`--food-debug*`/
  `--onboarding*` launch argument so walkers never meet a system
  dialog. Compiled out of Release entirely.

Why it is deterministic on physical iPhone AND iPad: one code path
(the app is `TARGETED_DEVICE_FAMILY = 1`; iPad runs the identical
binary in compatibility mode), keyed to two SwiftUI-observed inputs
(scene active + phase settled), a fixed 0.6s beat rather than polling,
and a re-arm on the one documented silent-failure mode. Denial and
restriction gate nothing — ATT status is read only as an analytics
property (`AnalyticsManager.attStatusString`); no feature consults it.

## 3. TikTok initialization — before vs after

| | before (build 35) | after |
|---|---|---|
| When | `PlankAIApp.init()`, every launch, ms after tap | `ATTService` start gate |
| First run (notDetermined) | initialized pre-consent, auto-events firing | NOT initialized until the prompt resolves; then initialized (any answer) |
| Later runs (resolved) | initialized at init | initialized at init-time `configure()` — identical timing |
| Auto events (Install/Launch/Retention/Purchase) | pre-consent | post-resolution only |
| SKAdNetwork | SDK-owned, enabled | unchanged — enabled, registered at (now gated) init |
| ATT dialog by SDK | never (1.6.1 removed it) | never; ATTService owns the prompt |

## 4. Tests — plankAITests/ATTServiceTests.swift (12, all green)

.notDetermined requests exactly once · authorized/denied/restricted
never request · SDKs never start while notDetermined · SDKs start once
after resolution · returning user starts SDKs with no prompt · failed
presentation retries · a real answer is never re-asked · fresh-install
sequence (prompt → answer → SDK start, loader call no-ops) · denial
sequence (app unaffected, SDK still initializes) · restricted device
(no prompt, SDK initializes).

**PROOF: app 1577 · 2 skipped · 0 failed (p59's 1565 + exactly the 12
added) · Release BUILD SUCCEEDED.**

## 5. Physical-device QA checklist (iPhone AND iPad, before archive)

The simulator is NOT valid for this check — its tracking toggle makes
the request resolve silently. Use physical hardware.

A. Delete Jeni from the device (long-press → Remove App → Delete).
B. Settings → Privacy & Security → Tracking → **"Allow Apps to
   Request to Track" ON**. If Jeni appears in the list from a prior
   install, also do Settings → General → Transfer or Reset iPhone →
   Reset → **Reset Location & Privacy** (this clears a previously
   answered ATT state; note it resets other privacy answers too).
C. Install the new build (TestFlight or Xcode).
D. Start a screen recording (Control Center → record) BEFORE tapping
   the app icon.
E. Launch Jeni.
F. Watch the launch: cream affirmation loader (~2s) → the consult's
   first screen.
G. **The system ATT dialog appears over the consult's first screen,
   ~0.6s after it lands** — title text from
   `NSUserTrackingUsageDescription` ("This lets us learn how you found
   us…").
H. Choose **Ask App Not to Track** (do one run this way, one with
   Allow).
I. Continue: answer a few consult beats — everything proceeds
   normally; denial gates nothing.
J. Background the app, foreground it — no second prompt. Force-quit,
   relaunch — no second prompt.
K. Repeat A–J on the iPad. Same flow, same placement (compatibility
   mode).
L. Denial run sanity: app remains fully usable through onboarding to
   the wall.

Where the prompt appears after the fix: **on every fresh install, over
the first onboarding screen, within about one second of it appearing —
before any consult interaction is required.** (On an update for an
existing user who was never asked, it appears over their first settled
screen — Home or the wall — on next launch.)

## 6. App Review Notes (copy-paste for ASC, after verifying the recording)

> APP TRACKING TRANSPARENCY
> The ATT permission request appears immediately on first launch: fresh
> install → launch → after the brief loading screen, the system ATT
> dialog is presented over the first onboarding screen, within about
> one second, before any interaction is required. No account, code, or
> specific onboarding path is needed to reach it, and the flow is
> identical on iPhone and iPad.
> The TikTok Business SDK (our only tracking SDK, used for ad
> attribution) does not initialize until the ATT request has been
> resolved, so no data that could be used for tracking is collected
> before the prompt. The user may Allow or Ask App Not to Track;
> declining does not restrict any functionality.
> A screen recording from a physical device (fresh install with
> Settings → Privacy & Security → Tracking → "Allow Apps to Request to
> Track" enabled) is attached, showing install → launch → ATT prompt →
> decline → normal app usage.
>
> ACCOUNT
> No sign-in is required to review the app: it creates an anonymous
> account automatically. Subscriptions unlock the main app; Restore
> Purchases and existing-subscriber sign-in are available on the plans
> screen.

Do not attach these notes until the physical-device recording exists
and shows exactly this.

## 7. The 3.1.2(c) EULA metadata fix (App Store Connect, founder)

Apple's requirement for auto-renewable subscriptions: a functional
Terms of Use (EULA) link in the App Description or the EULA field.
The app uses **Apple's Standard License Agreement** (no custom EULA in
ASC), so the correct link is Apple's standard EULA — verified live at:

`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
(title: "LICENSED APPLICATION END USER LICENSE AGREEMENT").

Add to the **bottom of the App Description**, replacing the current
`Terms of Use: jenifit.app/terms` line:

```
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Jeni Terms of Service: https://jenifit.app/terms
Privacy Policy: https://jenifit.app/privacy
```

- Keep `https://jenifit.app/privacy` in the Privacy Policy URL field
  (unchanged).
- Keep `https://jenifit.app/terms` as the service terms — it is a
  service agreement, not the license EULA; both may (and should)
  appear. The in-app paywall already links terms + privacy.
- Do NOT paste anything into the ASC custom-EULA field — doing so
  replaces Apple's Standard EULA and triggers legal review of the
  custom text.

## 8. Risk audit + prior-rejection verification (2026-08-28)

Verified in current code:
- **3.1.2(c) price prominence (prior rejection)** — PaywallView renders
  the billed-TODAY amount as the lead numeral on every tier row, from
  `storeProduct.localizedPriceString` only; per-week equivalents one
  step down; honest-terms renewal line docked. Stands.
- **5.6 (prior rejection)** — the dismissal law holds: WallExitIntent,
  SmallerStepSheet, DownsellPaywallView and the reclaim row are
  deleted; X stands the wall down; cancelling Apple's sheet returns to
  the same wall. Stands.
- **Privacy manifest** — `NSPrivacyTracking = true` + both TikTok
  domains; UserDefaults CA92.1. Matches the tracking declaration.
- **Purpose strings** — camera, Health read/write, photo-add, tracking
  all present and truthful in `PlankApp/Info.plist`.
- **Restore + existing-subscriber sign-in** — first-class on the wall;
  anti-enumeration account flows unchanged.
- **Account deletion** — in-app, shipped and contract-tested (p38–42).
- **AI disclosure** — "jeni is a digital coach. not a person, not your
  clinician." (E3); Method notes carry evidence tiers; the chat seed
  forbids the medication-change lane (p54).
- **iPad** — app is `TARGETED_DEVICE_FAMILY = 1`; iPad Air runs
  compatibility mode; ATT + paywall + onboarding are the same code
  path. `UIRequiredDeviceCapabilities` is arm64 only.

Named risks for the founder (ASC-side, not in this repo's control):
- **P1 — live App Description accuracy (2.3)**: the repo's
  `docs/app_store_metadata.md` is still the v1.0.0 plank-form-checker
  draft and says "We don't run advertising trackers", which is now
  false. The LIVE listing has evidently been rewritten since (it
  carries the terms/privacy lines), but verify the live description,
  What's New, and screenshots against the current product before
  resubmitting, and make sure no "no advertising trackers" claim
  survives anywhere in the live metadata.
- **P1 — App Privacy label**: with TikTok tracking declared, the label
  must show the tracked data types (Identifiers/Device ID, Purchase
  History if TikTok Purchase events are on) as "Data Used to Track
  You". Health data must NOT appear under tracking.
- **P2 — attach the recording**: Apple explicitly asked for a
  physical-device screen recording demonstrating the §5 checklist;
  reply to the rejection with it attached.

## 9. Files changed

- `PlankApp/Analytics/ATTService.swift` — NEW (coordinator + pure core
  + authorizer seam).
- `PlankApp/PlankAIApp.swift` — TikTok bootstrap gated through
  `ATTService.configure`; RootView `scenePhase` env + `attRequestGate`
  + launch-time `.task(id:)` request; stale ATT doc comment corrected.
- `PlankApp/Views/Onboarding/BuildingPlanLoadingView.swift` — loader
  request routes through ATTService.
- `plankAITests/ATTServiceTests.swift` — NEW (12 tests).
- `plankAI.xcodeproj/project.pbxproj` — the two file registrations.

No migration, no schema, no production mutation, no paywall/pricing/
entitlement logic touched, no @Model change, `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` untouched (1.1.7 (35) — bump at archive time
is the founder's step, as always).
