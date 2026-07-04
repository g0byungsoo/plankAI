# 32 — Privacy manifest (v1.1.3 submission compliance)

Date: 2026-07-04. Narrow compliance fix, no product/behavior change.

## What was added

1. `PlankApp/PrivacyInfo.xcprivacy` (first-party app manifest, in the
   app target's Copy Bundle Resources). Declares the app's only
   first-party required-reason API:
   - **UserDefaults** (`NSPrivacyAccessedAPICategoryUserDefaults`),
     reason **CA92.1** — "access info from the same app." @AppStorage
     + UserDefaults.standard across 74 files store this user's own
     preferences / app state (onboarding answers, cohort flags, unit,
     per-day notes). Not tracking, not third-party.
   - Audited 2026-07-04: NO first-party use of file-timestamp,
     system-boot-time, disk-space, or active-keyboard required-reason
     APIs. Bundled SDKs (PostHog, RevenueCat, Lottie, swift-crypto,
     supabase-swift) ship their own manifests for their own usage.
   - This resolves ITMS-91053 (missing required-reason declaration).

2. `Info.plist` → `ITSAppUsesNonExemptEncryption = false`. The app
   uses only standard HTTPS/TLS + platform crypto (exempt). Stops
   App Store Connect asking the encryption question every submit.

## PENDING founder confirmation (NOT added — must match ASC answers)

The manifest intentionally omits `NSPrivacyTracking`,
`NSPrivacyTrackingDomains`, and `NSPrivacyCollectedDataTypes` because
they must match your App Store Connect privacy nutrition label, which
is authoritative and which the code can't reveal. Suggested values:

### NSPrivacyTracking — AMBIGUOUS, needs your call
- Code evidence: PostHog is configured as **first-party product
  analytics** — no IDFA, no ad SDK, no session replay, no cross-app
  linking (`PostHogAppConfig`: sessionReplay off, screenViews off).
  By itself that is **NOT "tracking"** in Apple's sense → `false`.
- BUT the app calls `ATTrackingManager.requestTrackingAuthorization`
  (onboarding attribution, "how you found us").
- **Decision rule:** what does your ASC "Data used to track you"
  section say?
  - If **nothing is used to track you** → leave `NSPrivacyTracking`
    absent (defaults false). Manifest is complete as shipped.
  - If **attribution data IS "used to track you"** → set
    `NSPrivacyTracking = true` and add
    `NSPrivacyTrackingDomains = [us.i.posthog.com]`.

### NSPrivacyCollectedDataTypes — optional in manifest; ASC is authoritative
Reconcile these code-derived collections with your ASC nutrition
label (do not under-declare):
- Product interaction / analytics + crash data — PostHog (linked to
  the anon user id; for analytics + app functionality).
- Purchase history — RevenueCat (app functionality).
- Health & fitness — steps/sleep stay on-device (HealthKit), BUT
  **weight import syncs weigh-ins to the JeniFit account** (Supabase)
  per the Health usage string, so weight IS collected off-device.
- User content — food photos (sent to the vision service), reflection
  notes, plate titles.
- Identifiers — anonymous user id.

Once you confirm the ASC answers, I can finalize the tracking +
collected-data keys in the manifest to match. Until then the
required-reason fix stands on its own and unblocks the upload.
