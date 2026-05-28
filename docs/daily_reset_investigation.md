# Daily Reset — Investigation Report

**Status:** Read-only inspection. No code modified. No schema changes proposed.
**Date:** 2026-05-24
**Goal:** Map what already exists in the JeniFit codebase so a personalized
post-purchase "Daily Reset" module (Learn → Do → Complete → Preview) can be
designed against current data, persistence, and integration points — without
touching RevenueCat structure, the Supabase schema, or the existing
onboarding/paywall contract.

All claims below are sourced from agent-led code reads of the listed files.
File and line numbers should be verified by spot-check before any
implementation begins; line numbers can drift as files are edited.

---

## 1. Stack & Architecture

| Layer | Technology | Where it lives |
|---|---|---|
| App shell | Native SwiftUI (iOS), Swift 5/6 | `PlankApp/PlankAIApp.swift` |
| Local persistence | SwiftData `@Model` + UserDefaults / `@AppStorage` | `Packages/PlankSync/Sources/PlankSync/Models.swift`, plus inline `@AppStorage` in views |
| Cloud sync | Supabase (PostgREST + Auth + RLS) via `supabase-swift` SPM | `Packages/PlankSync/Sources/PlankSync/SyncService.swift`, `PlankApp/Sync/AppSync.swift` |
| Auth | Supabase anonymous → Apple/email upgrade | `PlankApp/Auth/AuthService.swift`, `AppleSignInService.swift` |
| IAP / entitlements | RevenueCat (`Purchases` SDK) | `PlankApp/Payment/PaymentService.swift` |
| Analytics | In-house `Analytics` facade → `PostHogSink` | `PlankApp/Analytics/AnalyticsManager.swift`, `PostHogSink.swift` |
| Notifications | UNUserNotificationCenter; one-shot trial-end scheduler | `PlankApp/Notifications/TrialEndNotificationService.swift` |
| Engine / workout | Local Swift packages | `Packages/PlankEngine`, `PlankVoice`, `PlankSync` |

**Project layout (relevant slices):**
```
PlankApp/
  PlankAIApp.swift           ← App + RootView (entry, route gating, paywall cover)
  Auth/                      ← AuthService, AppleSignInService
  Payment/                   ← PaymentService (RevenueCat wrapper)
  Sync/                      ← AppSync (bridges AuthService + SyncService + SwiftData)
  Analytics/                 ← AnalyticsManager + PostHogSink
  Notifications/             ← TrialEndNotificationService
  Views/
    Welcome/                 ← AffirmationScreen, AffirmationLoaderScreen, PremiumWelcomeScreen
    Onboarding/              ← OnboardingView (5.4k LOC, the whole question set), SignIn, SignUp, ForgotPassword
    Paywall/                 ← PaywallView, DownsellPaywallView
    Root/                    ← MainTabView
    Home/Settings/Browse/Routine/Session/PostSession/Analytics/Share/Common
  Workout/                   ← ExerciseBankData (static content pattern), generator, rules
  Resources/                 ← Music, VoiceClips, lottie, animations, Fonts, exercises.json
Packages/
  PlankSync/                 ← Models (SwiftData @Models), SyncService (Supabase upserts/queries)
  PlankEngine/               ← Pose + state machine + tests
  PlankVoice/                ← AudioQueue, LineLibrary, VoiceProvider
scripts/
  schema.sql                 ← Canonical Supabase schema (matches Models.swift)
  rls_policies.sql           ← RLS per table
```

---

## 2. Onboarding Flow (step-by-step)

### 2.1 Entry and route gating

`PlankAIApp.RootView` (`PlankApp/PlankAIApp.swift:207-425`) is a single switch
on a handful of pieces of state:

| Order | State checked | Action |
|---|---|---|
| 1 | `@AppStorage("hasCompletedOnboarding")` (line 177) | If false → show pre-onboarding chrome |
| 1a | `UserDefaults("hasSeenAffirmation")` | If unseen → `AffirmationScreen` (line 377) |
| 1b | else if `!auth.isReady` | `AffirmationLoaderScreen` (line 386) |
| 1c | else | `OnboardingView` (line 391) |
| 2 | `auth.isReady && payment.isEntitlementReady` (line 271) | If both ready → `MainTabView` + paywall cover; else → `AffirmationLoaderScreen` (line 370) |
| 3 | `.fullScreenCover(isPresented: .constant(!payment.effectiveHasProAccess && !payment.isInAuthTransition))` (line 274) | Hard paywall — covers `MainTabView` until entitlement flips true |
| 4 | `.onChange(of: payment.effectiveHasProAccess)` (line 342) | On false→true, sets `justSubscribed = true` |
| 5 | `.fullScreenCover(isPresented: $justSubscribed)` (line 357) | Shows `PremiumWelcomeScreen` for ~2.5s, then auto-dismisses to `MainTabView` |

**The user cannot skip the post-onboarding paywall.** Tapping X or "not right
now" presents a downsell sheet (`PaywallView.onDismiss` /
`onPurchaseCancelled` callbacks, lines 298-302); dismissing the downsell sheet
returns control to the paywall cover, which stays up until purchase or
restore succeeds.

### 2.2 Onboarding question set (the actual switch)

`PlankApp/Views/Onboarding/OnboardingView.swift` is one giant `switch` over a
case number (`@State screen: Int`). The flow array is at lines 737-758.
Section dividers (200-205) are interleaved between the 6 parts. The full
in-order step list as reported by the agent:

| Step | Case | Section | Prompt | Input | Persists to (OnboardingData field) |
|---:|---:|---|---|---|---|
| 0 | 0 | Intro | Marketing hero | — | — |
| 1 | 200 | Divider | "Your story" | — | — |
| 2 | 1 | Part 1 | Goal (lose weight / full body / tone core / grow glutes / slim legs) | single-select | `goal` |
| 3 | 110 | Part 1 | Body focus (flat belly / arms / butt / legs / full body) | multi-select | `bodyFocus: [String]` |
| 4 | 111 | Part 1 | "Why now?" (get shaped / look better / summer / confidence / self-love) | single-select | `motivation` |
| 5 | 201 | Divider | "How you move now" | — | — |
| 6 | 2 | Part 2 | Training cadence today (never / tried failed / sometimes / regularly) | single-select | `experience` |
| 7 | 8 | Part 2 | Activity level (5-pos slider: sedentary → athlete) | slider 0-4 | `activityLevel` |
| 8 | 120 | Part 2 | Location (home / gym / outdoor / either) | single-select | `workoutLocation` |
| 9 | 121 | Part 2 | Workout styles (hiit / pilates / strength / yoga / dance / walking) | multi-select | `workoutStyle: [String]` |
| 10 | 25 | Part 2 | Session length (5 / 10 / 15 / 20 min) | single-select | `sessionLengthMinutes` |
| 11 | 17 | Part 2 | Days/week (3 / 5 / 7) | single-select | `commitmentDaysPerWeek` |
| 12 | 202 | Divider | "About you" | — | — |
| 13 | 130 | Part 3 | Gender (female / male / non-binary / prefer not to say) | single-select | `gender` |
| 14 | 7 | Part 3 | Age (13-80 wheel) | wheel Int | `ageRange` (bucketed) |
| 15 | 131 | Part 3 | Height (cm/inch ruler) | ruler | `heightCm` (Double) |
| 16 | 132 | Part 3 | Current weight (kg/lb slider) | slider | `currentWeightKg` |
| 17 | 133 | Part 3 | Goal weight (kg/lb slider, seeded to current) | slider | `goalWeightKg` |
| 18 | 134 | Part 3 | Current body type (0-5 slider, 3=Average) | slider | `bodyTypeCurrent` |
| 19 | 135 | Part 3 | Desired body type (capped at current) | slider | `bodyTypeDesired` |
| 20 | 160 | Reshape | Transition | — | — |
| 21 | 161 | Prediction | First weight-curve preview | — | — |
| 22 | 203 | Divider | "How you want to feel" | — | — |
| 23 | 140 | Part 4 | Identity feeling (powerful / calm / light / strong / radiant) | single-select | `identityFeeling` |
| 24 | 141 | Part 4 | Reward at goal (clothes / trip / photos / personal day / treat) | single-select | `rewardChoice` |
| 25 | 142 | Part 4 | Comparison screen | — | — |
| 26 | 170 | Prediction | Re-prediction recap | — | — |
| 27 | 204 | Divider | "What stops you" | — | — |
| 28 | 150 | Part 5 | "Workout apps make me feel further from my body." | yes/no | `relatability1: Bool` |
| 29 | 151 | Part 5 | "I have no idea which workouts are right for me." | yes/no | `relatability2: Bool` |
| 30 | 152 | Part 5 | "I quit when something feels too hard or boring." | yes/no | `relatability3: Bool` |
| 31 | 205 | Divider | "Ready to start" | — | — |
| 32 | 3 | Part 6 | Plank baseline (<15s / 15-30 / 30-60 / 60+ / not sure) | single-select | `baselineHoldSeconds` (10/20/45/60/15) |
| 33 | 11 | Part 6 | Reminder time (7am / 1pm / 7pm / 9am random) | single-select | `plankTime` |
| 34 | 18 | Part 6 | Name (free text) | text | `name` |
| 35 | 19 | Part 6 | Coach (Jeni / Kira / Sam) | single-select | `voicePreference` |
| 36 | 180 | Loading | Prediction carousel | — | — |
| 37 | 181 | Prediction | Final prediction (calendar + curve) | — | — |
| 38 | 21 | Reveal | Plan reveal | — | — |
| 39 | 215 | Review | Soft prefilter for App Store review | yes → SKStore | `onboardingReviewPromptShown` (@AppStorage) |
| 40 | 26 | Recovery | Sign-in to recover existing account | — | skips to step 22 if non-anonymous |
| 41 | 22 | Analytics | Plan summary | — | — |
| 42 | 23 | Final | Notification permission + daily time | yes/no | `notificationsEnabled`, `notificationTime` |

**Skippability:** Most question screens require a selection to enable the
Continue button. There are no "prefer not to say" affordances on
biometric/identity steps except gender (case 130). Phase 3 sliders (height,
weight, body type) ship with defaults (170 cm, 65 kg current / 60 kg goal,
3/3 body type), so a user who taps Continue without touching the slider
"answers" with the default — see §3 reliability notes.

### 2.3 OnboardingData struct (defined at OnboardingView.swift:5417-5443)

```swift
struct OnboardingData {
    // Legacy fields (required, no defaults)
    let goal: String
    let experience: String
    let baselineHoldSeconds: Int
    let barriers: [String]        // legacy; derived from relatability1/2/3
    let ageRange: String
    let activityLevel: String
    let focusArea: String         // legacy; derived from bodyFocus.first
    let plankTime: String
    let commitmentDaysPerWeek: Int
    let sessionLengthMinutes: Int
    let notificationsEnabled: Bool
    let notificationTime: Date?
    let name: String
    let voicePreference: String

    // Phase 4 additions (var; have defaults)
    var bodyFocus: [String] = []
    var motivation: String = ""
    var workoutLocation: String = ""
    var workoutStyle: [String] = []
    var gender: String = ""
    var heightCm: Double = 170
    var currentWeightKg: Double = 65
    var goalWeightKg: Double = 60
    var bodyTypeCurrent: Int = 3
    var bodyTypeDesired: Int = 3
    var identityFeeling: String = ""
    var rewardChoice: String = ""
    var relatability1: Bool = false
    var relatability2: Bool = false
    var relatability3: Bool = false
}
```

### 2.4 Handoff at completion

When the user lands on the final step and confirms, `OnboardingView.finish()`
(~line 4832) runs this sequence:

1. `Analytics.track(.onboardingComplete)` with `user_goal`, `body_focus_count`, `coach`.
2. If `notificationsEnabled`, request UN permission + schedule daily reminder.
3. Derive legacy `focusArea` (from `bodyFocus.first`) and `barriers` (from `relatability1/2/3`).
4. Construct `OnboardingData` (line ~4865) and call `onComplete(data)`.
5. `RootView.handleOnboardingComplete(_:)` (`PlankAIApp.swift:427-495`):
   - Writes ~18 `@AppStorage` mirror keys (lines 428-459).
   - `upsertLocalUserRecord(userId:data:)` (line 465) → SwiftData `UserRecord`.
   - Fire-and-forget `AppSync.shared.upsertUser(record)` (line 470) → Supabase.
   - If `currentWeightKg > 0`, seeds first `WeightLogRecord` with `source = "onboarding"` and pushes via `AppSync.upsertWeightLog` (lines 472-488).
   - `@AppStorage("hasCompletedOnboarding") = true` (line 494) — flips the route gate.

The user then drops into RootView's `MainTabView` branch, which **immediately
presents the paywall fullScreenCover** (PlankAIApp.swift:274). The cover is
the next thing the user sees.

---

## 3. User Data Inventory

### 3.1 UserRecord (SwiftData `@Model` in `Packages/PlankSync/Sources/PlankSync/Models.swift`)

The Swift model maps 1:1 with the Supabase `public.users` table (see
`scripts/schema.sql`). Column naming converts camelCase ↔ snake_case in
`SyncService.upsertUser` (lines ~140-160).

| Property | Type | Default | How populated | Reliability at trial-purchase |
|---|---|---|---|---|
| `id` | String | (assigned) | Supabase `auth.uid()` | **100%** |
| `name` | String | `""` | Onboarding step 34 | **100%** (required Continue gate) |
| `startDate` | Date | `.now` | Auto on creation | **100%** |
| `currentDay` | Int | 1 | Derived from DayProgressRecord | 100% (defaults to 1) |
| `coreScore` | Double | 0 | Derived from sessions | **0%** at trial-purchase (no sessions yet) |
| `lastSessionDate` | Date? | nil | First session | **0%** at trial-purchase |
| `streakCurrent` / `streakLongest` | Int | 0 | StreakCalculator | **0%** at trial-purchase |
| `programPhase` | String | `"foundations"` | Default | 100% |
| `onboardingGoal` | String? | nil | Step 2 | **100%** |
| `onboardingExperience` | String? | nil | Step 6 | **100%** |
| `onboardingBaselineHoldSeconds` | Int? | nil | Step 32 | ~95% (skipped if `experience == "neverTried"`) |
| `onboardingBarriers` | [String]? | nil | Derived from relatability1/2/3 | 100% (often `[]`, never nil after Phase 4) |
| `onboardingAgeRange` | String? | nil | Step 14 (bucketed) | **100%** |
| `onboardingActivityLevel` | String? | nil | Step 7 | **100%** |
| `onboardingCommitmentDaysPerWeek` | Int? | nil | Step 11 | **100%** |
| `onboardingNotificationEnabled` | Bool | false | Step 42 | **100%** |
| `onboardingNotificationTime` | Date? | nil | Step 42 if enabled | ~70% (only when notifications opt-in) |
| `onboardingVoicePreference` | String? | nil | Step 35 | **100%** (default `"encouraging"`) |
| `onboardingFocusArea` | String? | nil | Derived from `bodyFocus.first` | 100% |
| `onboardingPlankTime` | String? | nil | Step 33 | **100%** |
| `onboardingSessionLengthPref` | Int? | nil | Step 10 | **100%** |
| `onboardingBodyFocus` | [String] | `[]` | Step 3 (multi) | **100%** (may be `[]`) |
| `onboardingCurrentWeightKg` | Double? | nil | Step 16 (slider, default 65) | ⚠️ **100% present but possibly default 65** — see §3.5 |
| `onboardingGoalWeightKg` | Double? | nil | Step 17 (slider, default 60) | ⚠️ **100% present but possibly default 60** |
| `onboardingMotivation` | String | `""` | Step 4 | **100%** (empty string if untouched, but step is required to advance) |
| `onboardingWorkoutLocation` | String | `""` | Step 8 | **100%** |
| `onboardingWorkoutStyle` | [String] | `[]` | Step 9 (multi) | **100%** |
| `onboardingGender` | String | `""` | Step 13 | ~95% (has "prefer not to say") |
| `onboardingHeightCm` | Double? | nil | Step 15 (default 170) | ⚠️ same default-vs-real caveat |
| `onboardingBodyTypeCurrent` | Int? | nil | Step 18 (default 3) | ⚠️ default 3 |
| `onboardingBodyTypeDesired` | Int? | nil | Step 19 (auto-seeded to current) | ⚠️ default = current |
| `onboardingIdentityFeeling` | String | `""` | Step 23 | **100%** |
| `onboardingRewardChoice` | String | `""` | Step 24 | **100%** |
| `onboardingRelatability1/2/3` | Bool? | nil | Steps 28-30 | **100% answered**, but `false` and `nil` are conflated on the wire (see §3.5) |
| `pendingUpsert` | Bool | false | Sync retry flag | n/a |

### 3.2 Other SwiftData models (not directly relevant but worth knowing)

| Model | Purpose | Sync? |
|---|---|---|
| `SessionLogRecord` | Append-only per-session record (routine + plank benchmark) | Yes → `public.session_logs` |
| `DayProgressRecord` | One row per `(user_id, program_day)`; derived state | Yes → `public.day_progress` |
| `WeightLogRecord` | Append-only weight history (one-per-day enforced client-side) | Yes → `public.weight_logs` |
| `SessionRatingRecord` | 1-5 star post-session rating + tags | **No** server upsert today |
| `ExerciseCalibrationRecord` | Per-exercise difficulty calibration | **No** server upsert today |

### 3.3 What's local-only vs. synced

Every `UserRecord` field syncs to Supabase via `SyncService.upsertUser` (the
upsert builds `SupabaseUserUpsert` at SyncService.swift ~lines 657-700). No
`UserRecord` field is local-only. No Supabase `public.users` column is
present that the Swift model doesn't write.

There is **no `public.users` row created server-side automatically**. The
trigger is commented out in `scripts/schema.sql:251-267`. The app explicitly
upserts on onboarding completion; without it, `auth.users` exists but
`public.users` is empty until the first onboarding finish.

### 3.4 `@AppStorage` mirror keys (read-fast in views)

`AppSync.syncUserDefaultsFromUserRecord` (`PlankApp/Sync/AppSync.swift:180-227`)
mirrors a subset of UserRecord fields into UserDefaults so views can render
without a SwiftData fetch. Daily Reset can read these directly. Full list in §5.

### 3.5 Gotchas to carry into the feature design

These are non-obvious behaviors that will bite if not respected. Source: the
deep-read of `SyncService.swift` + `AppSync.swift` + `Models.swift`.

1. **UUID case mismatch.** `auth.uid()` returns lowercase; Swift's
   `UUID.uuidString` returns uppercase. Hydration code uses the passed
   `userId` (uppercase) when building local SwiftData keys, not the lowercase
   value coming back from PostgREST (AppSync.swift ~lines 269-282,
   SyncService.swift ~lines 362-376). Any new code that filters
   `userId == someValue` must match the case used at write time, or
   `@Query` will silently return zero rows.

2. **`relatability_1/2/3` conflates `false` with "not answered."** The
   `OnboardingData` fields are non-optional `Bool` (default `false`). The
   `UserRecord` fields are `Bool?`. `SyncService.upsertUser` only sends
   `true` to Supabase; `false` becomes `nil` on the wire. So "user clicked
   No" and "user never saw the question" are indistinguishable in Supabase.
   For Daily Reset personalization, treat `true` as a high-signal opt-in and
   ignore `nil`/`false`.

3. **Sliders pre-fill with defaults.** Height (170 cm), current weight (65
   kg), goal weight (60 kg), body type (3=Average) all advance with their
   default if the user taps Continue without dragging. There's no way to
   tell "I am 170 cm" from "I didn't change the slider." For Daily Reset,
   either (a) use these fields *only when paired with a corroborating
   non-default signal* (e.g. weight delta > 0), or (b) flag any
   "I-haven't-actually-answered" inference clearly in the copy.

4. **Empty strings → `nil` on the wire.** `motivation`, `workoutLocation`,
   `workoutStyle`, `gender`, `identityFeeling`, `rewardChoice` are written as
   `""` locally and converted to `nil` if empty in `SyncService.upsertUser`
   (~lines 147-155). Same caveat: a legacy/cross-device pull will see `nil`
   for an unanswered Phase 4 field but `""` immediately post-onboarding.
   Treat empty/nil interchangeably in personalization logic.

5. **`onboarding_body_focus` is `text[]`, not a single value.** Multi-select.
   The existing paywall personalization uses `bodyFocus.first` as a single
   "primary focus" lookup (see `AppSync.swift` ~line 224). Daily Reset should
   probably do the same — or branch on `contains("flatBelly")` etc.

6. **`onboarding_barriers` is also `text[]`.** Currently derived from
   `relatability1/2/3` at onboarding completion. Default is `[]`, not `nil`.

7. **`pendingUpsert` retry semantics.** `SyncService` sets `pendingUpsert =
   true` before any write and clears it on success (~lines 86-94). On launch,
   `AppSync.onLaunch` calls `retryPendingUpserts` (line 60). Daily Reset
   should not need to write to `UserRecord` (it has no new fields) — but if
   it ever does, follow this pattern.

---

## 4. Integration Points

### 4.1 Purchase signal — where Daily Reset hooks in

`PaymentService` exposes the entitlement state needed; the recommended hook
point is in `RootView`, not inside `PaymentService` itself.

**`PaymentService` public surface** (`PlankApp/Payment/PaymentService.swift`):

| Property/Func | Line | Notes |
|---|---:|---|
| `isConfigured: Bool` | 35 | Configure-once guard |
| `hasProAccess: Bool` | 43 | Drives paywall gate; flips on `customerInfoStream` emit |
| `isEntitlementReady: Bool` | 52 | First emit OR 3s safety timeout |
| `isInAuthTransition: Bool` | 60 | 1s suppression window during auth sync |
| `effectiveHasProAccess: Bool` | 75 | `hasProAccess` + DEBUG `debugForcePaywall` override |
| `configure(appUserID:)` | 124 | Spawns `startCustomerInfoStream()` |
| `restorePurchases() -> Bool` | 263 | Returns true iff entitlement now active |
| `handleAuthChange(newUserID:)` | 268 | Sync RC appUserID on auth change |

**Inside the stream** (PaymentService.swift:155-177), there's already a
false → true diff that fires `Analytics.track(isTrial ? .trialStart :
.purchaseCompleted, ...)`. That same diff is the natural Daily Reset signal.

**Recommended hook (no PaymentService changes):**

Observe `payment.effectiveHasProAccess` in `RootView`. PlankAIApp.swift
already does this for `justSubscribed` at line 342 — Daily Reset just
piggybacks on the same `onChange`:

```swift
// Conceptual — DO NOT IMPLEMENT THIS ROUND
.onChange(of: payment.effectiveHasProAccess) { _, isPro in
    if isPro {
        justSubscribed = true             // existing
        showingDailyReset = true          // new
    }
}
.fullScreenCover(isPresented: $showingDailyReset) {
    DailyResetView(...)                   // new
}
```

Distinguishing "started trial today" vs. "already in trial" vs. "fully paid"
uses the existing pattern from `TrialEndNotificationService.swift` — read
`customerInfo.entitlements["pro"]?.periodType == .trial` and
`?.expirationDate`. Both are accessible from inside the customerInfoStream
callback; PaymentService.swift:214-218 is the precedent.

For cross-launch detection (user installed update mid-trial, never saw the
module), use the existing `UserDefaults("lastKnownEntitlementKey")` cache at
PaymentService.swift:27-30 — diff prior cached value against today's.

**Off-limits per project constraints:**
- `startCustomerInfoStream`, `reconcileTrialReminder`, `configure`,
  `handleAuthChange` — observe only, do not edit.
- PaywallView purchase/restore callbacks (lines 552-632).
- RevenueCat offerings/products/entitlements (dashboard-managed).
- `TrialEndNotificationService` (PaymentService owns it).

**Fair game:**
- Add `@State` flags in RootView.
- Add a new fullScreenCover binding.
- Read `customerInfo.entitlements[...].periodType / expirationDate` in a
  parent-spawned observation task (or just observe `payment.hasProAccess`
  transitions and call out to a small new helper).

### 4.2 Persistence options for Daily Reset state

Three places state can live; pick by lifetime:

| Need | Best fit | Precedent |
|---|---|---|
| Enrollment date + current day index | `UserRecord` with new field … **but this requires a schema change** — see Open Questions. Alternative: a new `@AppStorage` key cluster (see §6) | UserRecord onboarding fields; `@AppStorage("dailyRefreshDate")` in `HomeView.swift:26` |
| Per-day completion (which Learn/Do screens were completed) | UserDefaults key with date string, or a small new SwiftData `@Model` | `DayProgressRecord` is the closest existing pattern |
| Transient UI state (which screen of the day we're on) | `@State` in the view | n/a |
| "Has the user been shown the Daily Reset trigger this trial?" (idempotency) | `UserDefaults` bool, same shape as `TrialEndNotificationService` idempotency keys | `TrialEndNotificationService` schedule-once pattern |

**Strong recommendation:** keep Daily Reset state entirely in `UserDefaults`
/ `@AppStorage` for v1 to honor the no-schema-change constraint. The existing
24+ `@AppStorage` keys (full list in §5) show this is the canonical pattern
for "small per-user flags." If we later want cross-device continuity of
Daily Reset progress, that's the moment to add a `UserRecord` column.

### 4.3 Analytics API

`PlankApp/Analytics/AnalyticsManager.swift` (162 lines):

```swift
Analytics.track(.onboardingComplete, properties: [
    "user_goal": goal,
    "body_focus_count": bodyFocus.count,
])
```

- Event enum is the typed form; there's also a `String` overload for ad-hoc events.
- Properties auto-merge with `app_version`, `timestamp`, `environment`, `is_test_user`.
- Sinks: `ConsoleAnalyticsSink` in DEBUG, `PostHogSink` in release.
- Calls dispatch off the main thread; safe from any view.

**Existing call shape examples:**
- `OnboardingView.swift:1128` — `Analytics.track(.onboardingStart)`
- `HomeView.swift:1205` — `Analytics.track(.firstWorkoutStart, properties: [...])`
- `PaymentService.swift:165` — `Analytics.track(isTrial ? .trialStart : .purchaseCompleted, ...)`

Daily Reset events should be added to the `AnalyticsEvent` enum and use the
typed form (matches the codebase convention).

### 4.4 Paged-content scaffolds to reuse

Three existing patterns most relevant to a Learn → Do → Complete → Preview
flow:

1. **`AffirmationScreen.swift`** (Welcome/) — single-screen choreography with
   `@AppStorage` flag persistence, tap-to-skip, reduce-motion handling. Copy
   arrays at file scope. Great template for the "Complete" beat.
2. **`PremiumWelcomeScreen.swift`** (Welcome/) — multi-element timeline,
   delay-based animation, spring effects, 2.5s auto-advance,
   reduce-motion-aware. Template for "Preview tomorrow."
3. **`OnboardingView.swift`** — case-switch multi-screen routing, forward/back
   nav, Continue-gate pattern, Analytics at each step, section dividers.
   Template for the overall 4-screen container.

### 4.5 Static-content bundling pattern

JeniFit ships content three ways:

| Pattern | Example file | Best for |
|---|---|---|
| Swift literal in source | `PlankApp/Workout/ExerciseBankData.swift` (`static let all: [Exercise] = [...]`) | Small-medium typed content where compile-time safety helps |
| Swift literal at file scope | `AffirmationLoaderScreen.swift:34` (`private static let quotes: [(line, italics)]`) | Tiny lists tied to one view |
| JSON in bundle | `PlankApp/Resources/exercises.json` (~83 KB), loaded lazily via `Bundle.main` | Large structured data |

For Daily Reset's 5-7 days × N copy variants per personalization branch, the
`ExerciseBankData` Swift-literal pattern is the right choice: type-safe,
no parse cost, easy to A/B by swapping arrays.

---

## 5. UserDefaults / @AppStorage Inventory

Existing keys the Daily Reset module can read for personalization without a
SwiftData fetch. Source: agent grep across PlankApp/.

| Key | Mirrors UserRecord | Read in |
|---|---|---|
| `hasCompletedOnboarding` | (gate, not mirror) | PlankAIApp.swift:177 |
| `hasCompletedFirstSession` | (gate) | HomeView.swift:8 |
| `hasSeenAffirmation` | (gate) | AffirmationScreen.swift:41 |
| `userName` | `name` | PlankAIApp.swift:178 |
| `userGoal` | derived from `onboardingFocusArea` (note: NOT `onboardingGoal` — confusing) | PlankAIApp.swift:179 |
| `userExperience` | `onboardingExperience` | PlankAIApp.swift:180 |
| `voicePreference` | `onboardingVoicePreference` | PlankAIApp.swift:181 |
| `bodyFocus` | `onboardingBodyFocus.first` | EditProfileView.swift:13 |
| `userMotivation` | `onboardingGoal` (note: stored under `userMotivation` — confusing) | PlankAIApp.swift, mirror code |
| `sessionLengthPref` | `onboardingSessionLengthPref` | EditProfileView.swift:15 |
| `userBarriers` | `onboardingBarriers.joined(",")` | HomeView.swift:18 |
| `userBaselineSeconds` | `onboardingBaselineHoldSeconds` | HomeView.swift:19 |
| `ageRange` | `onboardingAgeRange` | HomeView.swift:20 |
| `activityLevel` | `onboardingActivityLevel` | HomeView.swift:21 |
| `dailyRefreshCount` / `dailyRefreshDate` | (transient daily counter) | HomeView.swift:25-26 |
| `weightUnit` | (user pref) | LogWeightSheet.swift:27 |
| `notificationsEnabled` | `onboardingNotificationEnabled` | NotificationSettingsView.swift:5 |
| `notificationHour` / `notificationMinute` | (decomposed from `notificationTime`) | NotificationSettingsView.swift:6-7 |
| `musicSource`, `voiceVolume`, `bgmVolume`, `prepBeepVolume` | (audio prefs) | RoutineSessionSheets.swift:37-39, 154 |
| `onboardingCurrentWeightKg` | `onboardingCurrentWeightKg` | AnalyticsView.swift:19 |
| `onboardingGoalWeightKg` | `onboardingGoalWeightKg` | AnalyticsView.swift:20 |
| `hideWeightStats` | (UI pref) | AnalyticsView.swift:26 |
| `onboardingReviewPromptShown` | (idempotency gate) | OnboardingView.swift:87 |
| `lastKnownEntitlementKey` | (PaymentService cache) | PaymentService.swift:27-30 |

> ⚠️ The `userGoal` / `userMotivation` key naming is **misleading.**
> `userGoal` actually mirrors `onboardingFocusArea` (anatomy), and
> `userMotivation` mirrors `onboardingGoal` (the "lose weight" answer).
> Personalization should read the SwiftData `UserRecord` directly to avoid
> being burned by these names; the @AppStorage mirror is for hot-path views
> only.

---

## 6. Personalization Proposal (available data only)

The constraint is "no new fields, no schema changes." With the §3 reliability
ratings in mind, here's a field-to-screen map for a 5-day Learn → Do →
Complete → Preview structure.

### 6.1 High-signal personalization fields

| Field | Cardinality | Signal quality | What it tells us |
|---|---|---|---|
| `onboardingGoal` | 5 enum values | **Strong** — required Q | What "win" the user defined |
| `onboardingBodyFocus` (multi) | 5 enum × multi | **Strong** | Where to bias copy + workout selection |
| `onboardingMotivation` ("why now") | 5 enum | **Strong** | Emotional framing |
| `onboardingIdentityFeeling` | 5 enum | **Strong** | Identity word for "becoming" copy |
| `onboardingRewardChoice` | 5 enum | **Strong** | Concrete callback for "Preview tomorrow" |
| `onboardingExperience` | 4 enum | **Strong** | Difficulty calibration for "Do" |
| `onboardingCommitmentDaysPerWeek` | 3/5/7 | **Strong** | Sets cadence expectations |
| `onboardingSessionLengthPref` | 5/10/15/20 | **Strong** | Sizes the "Do" action |
| `onboardingVoicePreference` | 3 enum | **Strong** | Tone selector for all copy |
| `onboardingWorkoutLocation` | 4 enum | **Strong** | "Do" picks home-vs-gym moves |
| `onboardingWorkoutStyle` (multi) | 6 enum × multi | **Strong** | Style bias for "Do" |
| `onboardingRelatability1/2/3` | 3 booleans | **Medium** — `true` only (see §3.5 gotcha) | Barrier-acknowledgment copy |
| `onboardingAgeRange` | 6 buckets | Medium | Light age framing (e.g., "in your 30s, recovery matters") |
| `onboardingActivityLevel` | 5 buckets | Medium | Difficulty pairing with experience |
| `onboardingCurrentWeightKg` − `onboardingGoalWeightKg` | Δ kg | **Conditional** — only when both are non-default | Realistic timeline + ACSM math on the "How long does this take" day |
| `onboardingHeightCm` + weights | BMI | Conditional | Health-framed copy (already done in Becoming tab) |
| `name` | string | n/a | First-person addressing |

### 6.2 Low-signal / avoid-as-primary fields

- `onboardingBodyTypeCurrent` / `Desired` — sliders default to 3/3; can't
  distinguish "I'm Average and want Average" from "didn't touch slider."
- `onboardingGender` — has "prefer not to say"; only use for inclusive copy
  when explicitly female/male, never as a personalization gate.
- `onboardingPlankTime` — already drives notification scheduling; tertiary
  signal for "let's check in at your usual time" copy.
- `coreScore`, `streakCurrent`, `lastSessionDate` — all 0/nil at the trial-
  purchase moment Daily Reset triggers. **Do not personalize on these.**

### 6.3 Per-day proposal (sketch only)

| Day | Theme (Learn) | Personalization angle | Driven by |
|---:|---|---|---|
| 1 | "Why this time is different" | Acknowledge the barrier(s) they admitted in Part 5 | `relatability1/2/3 == true` → tailored apology + reframe; fall back to universal copy if all nil |
| 2 | "Your real timeline" | Use weight delta + ACSM 0.5-1%/wk (existing precedent in `weight_loss_analytics_research.md`) to set a realistic 8-12-week framing; only if `currentWeight != 65` OR `goalWeight != 60` (proxy for "user actually set them"); else universal "results take ~8 weeks" copy | `onboardingCurrentWeightKg`, `onboardingGoalWeightKg`, `onboardingHeightCm` |
| 3 | "Where it shows up first" | Tie to body focus zones (flat belly → "lower abs tighten before scale moves"; tonedArms → "shoulder definition shows in 3 weeks") | `onboardingBodyFocus` (multi → pick first or top-2) |
| 4 | "Why your motivation is the design" | Recall the `motivation` ("summer", "self-love", "confidence") and reframe today's session as one step toward it | `onboardingMotivation` + `onboardingIdentityFeeling` |
| 5 | "Becoming who you said you wanted to be" | Identity-framed close; reward callback ("when you fit those jeans...") | `onboardingIdentityFeeling`, `onboardingRewardChoice` |

**Per-screen treatment within each day:**

- **Learn screen**: copy template indexed by `(day, primary_personalization_key)`.
  Voice tone applied last by `onboardingVoicePreference`. Length tuned to
  ~25-40 sec read.
- **Do screen**: short action sized to `min(onboardingSessionLengthPref, 5)`
  minutes for Day 1, scaling up across the week. Filter by
  `onboardingWorkoutLocation` (home/gym/outdoor) and prefer styles from
  `onboardingWorkoutStyle`. Hand off to existing `WorkoutGenerator` with
  Daily-Reset-specific length cap if possible — or pick statically curated
  micro-actions from a new `DailyResetContent` Swift literal. (Static is
  safer for v1 to avoid scope creep into the generator.)
- **Complete screen**: AffirmationScreen-style choreography with the user's
  `name` and identity word. Records completion in UserDefaults.
- **Preview screen**: PremiumWelcomeScreen-style mini-reveal of tomorrow's
  theme. Schedules a local notification 24h out (reuse
  `TrialEndNotificationService` patterns; do NOT collide with the existing
  `daily_reminder` ID — pick a new ID like `daily_reset_day_n`).

### 6.4 Where data is too sparse

- **Relatability barriers.** Because `false` and `nil` are wire-equivalent
  (§3.5 #2), the only safe inference is "user said true." If all three are
  `nil`/false, fall back to a universal "you've tried before, here's what
  changed" frame — don't assume the user has no barriers.
- **BMI / weight delta.** Don't compute these if `currentWeightKg == 65 &&
  goalWeightKg == 60` exactly (the default tuple). Even if non-default, treat
  with the same care the Becoming tab does (anti-shame caption).
- **Cross-device hydration timing.** A user who completes onboarding on
  device A and starts trial on device B may have a window where SwiftData
  hydration is mid-flight. Daily Reset should read from
  `AppSync.shared` / `UserRecord` after the existing
  `auth.isReady && payment.isEntitlementReady` gate has fired (same as
  paywall presentation).

---

## 7. Open Questions / Risks

### Things to confirm before implementation

1. **Trigger timing — pre- or post-celebration screen?** The current flow
   shows `PremiumWelcomeScreen` for ~2.5s after purchase, then lands on
   `MainTabView`. Does Daily Reset come *before* the celebration (replacing
   it) or *after* (chained fullScreenCover)? My read: chain it after, so the
   user's first feedback is still the existing celebration moment.
2. **Re-entry on app cold-launch during trial.** If a user starts trial,
   force-quits before completing Day 1, then relaunches the next morning, do
   they re-enter Daily Reset on launch or wait for Home? Recommendation:
   trigger via a HomeView card the next day(s), not a fullScreenCover.
   Fullscreen only on the immediate post-purchase moment.
3. **"Done with Daily Reset" terminal state.** Day 5 complete — what then?
   Just a normal Home? A graduation moment? A check-in cadence (weekly)?
4. **What counts as "Do completed"?** If the Do screen launches a workout,
   does the user need to finish it, or just see/start it? Affects how the
   completion analytic + Preview screen fire.
5. **Re-personalization on cross-device sign-in.** If a user signs in on a
   second device mid-Daily-Reset, do they continue where they left off? With
   `@AppStorage`-only state, the answer is no. To make it yes we'd need a
   schema change — which is out of scope for v1 per the constraints.

### Risks to the no-migration / no-paywall-change contract

| Risk | Likelihood | Mitigation |
|---|---|---|
| Inserting a third fullScreenCover competes with `justSubscribed` cover and the paywall cover | Medium | Order them: paywall → celebration → DailyReset, gating each on its own `@State` so transitions are deterministic. Verify against `isInAuthTransition` gating already in place at line 274. |
| Reading `customerInfo` from a new observer creates duplicate work | Low | Observe `payment.hasProAccess` instead; PaymentService already does the customerInfoStream read. |
| Notification scheduling for "tomorrow's Daily Reset" collides with `daily_reminder` | Medium | Use a distinct notification identifier prefix (`daily_reset_day_N`) and never touch the canonical `daily_reminder` ID. Mirror the surgical-removal pattern called out in CLAUDE.md. |
| Personalization branches blow up content surface area | High | Start with 1-2 branches per day (voice tone + one signal). Add more only if A/B data justifies. |
| Static content drift: copy reviewed for Day 1 doesn't match what ships when DailyResetContent is edited late | Medium | Co-locate copy with view in `DailyResetContent.swift`, ship for review in one PR. |
| `onboardingMotivation`/`rewardChoice`/`identityFeeling` may be empty for very old users (pre-Phase 4) | Low (CLAUDE.md says Phase 4 fully shipped) | Defensive default-copy branch per field; treat empty as "universal" copy. |
| Default-slider weight values (65/60/170) misread as "real" data | Medium | Skip weight/BMI personalization when values exactly equal the defaults. |
| Daily Reset adds 5 days of state to UserDefaults that no UI exposes for reset/clear | Low | Provide a debug toggle (matching `DebugAuthView` precedent) before TestFlight ships. |

### Things I did NOT verify in this pass

- Exact line numbers on PaywallView purchase callback (`onSubscribed` closure
  call site) — agent said line 589. Verify before wiring.
- The `OnboardingData` struct lives at lines 5417-5443 per agent read; the
  file is 5461 lines so this is plausible, but I did not open it myself.
- The actual `AnalyticsManager.swift` signature — agent reported
  `Analytics.track(_ event:, properties:)`. Double-check that the namespace
  is `Analytics` (facade) vs. `AnalyticsManager.shared` (manager).
- Whether RevenueCat exposes `customerInfo.entitlements["pro"]?.periodType`
  with the spelling agent reported (it's the public `EntitlementInfo` API,
  so should be fine, but verify the entitlement ID against
  `RevenueCatConfig.entitlementID`).

---

## 8. Recommended Implementation Plan (NOT for this round)

Sketch for the follow-up planning conversation, not action items now.

**Phase 0 — design lock (no code)**
- Pick the per-day theme list (5 days proposed in §6.3).
- Choose 1-2 personalization signals per day (avoid >2 branches per screen).
- Write copy variants per branch + a universal fallback for each.
- Decide: re-entry behavior (HomeView card vs. fullScreenCover), terminal
  state (graduation moment vs. silent return), "Do completed" definition.

**Phase 1 — content scaffold (one file)**
- New `PlankApp/Views/DailyReset/DailyResetContent.swift` modeled on
  `ExerciseBankData.swift`: typed `DailyResetDay` struct + array literal.
- Includes per-screen copy slots and a `personalize(for: UserRecord) -> ResolvedDay` helper.

**Phase 2 — view scaffolding (no integration yet)**
- New `DailyResetView.swift` containing the 4-screen case-switch
  (Learn/Do/Complete/Preview) modeled on OnboardingView's pattern.
- Per-screen choreography modeled on AffirmationScreen + PremiumWelcomeScreen.
- DEBUG-only entry point in `DebugAuthView` to launch it standalone for QA.

**Phase 3 — analytics**
- Add `dailyResetStarted`, `dailyResetDayViewed`, `dailyResetDayCompleted`,
  `dailyResetCompleted` to `AnalyticsEvent` enum; thread through view.

**Phase 4 — persistence**
- 3-5 new `@AppStorage` keys: `dailyResetEnrolledAt`, `dailyResetCurrentDay`,
  `dailyResetDaysCompletedMask` (Int bitmask 0-31 = 5 days), 1 idempotency
  flag per trial start.
- No SwiftData @Model added in v1.

**Phase 5 — trigger wiring**
- In `RootView`, add `@State showingDailyReset`. Extend the existing
  `.onChange(of: payment.effectiveHasProAccess)` at PlankAIApp.swift:342 to
  set the flag in addition to `justSubscribed`.
- Add `.fullScreenCover(isPresented: $showingDailyReset)` after the existing
  celebration cover. Coordinate ordering so celebration plays first.
- Read `customerInfo.entitlements["pro"]?.periodType == .trial` to bias copy
  toward "trial" vs. "subscribed" framing.

**Phase 6 — notifications**
- Schedule "tomorrow's day N" reminder via UNUserNotificationCenter using
  identifier prefix `daily_reset_day_N`. Do NOT touch `daily_reminder`.
- Surgical removal pattern: cancel only `daily_reset_*` identifiers if the
  user opts out, never blanket-removeAll.

**Phase 7 — QA**
- DEBUG launcher in DebugAuthView to step through each day independently.
- Reset button (DEBUG-only) to clear all `dailyReset*` keys.
- Test matrix: voice × (relatability mask × goal) — pick ~8 representative
  user profiles, verify copy resolves correctly.

**Phase 8 — A/B gating (optional)**
- If desired, gate Daily Reset behind a UserDefaults bool that PostHog can
  flip remotely; reuse `TrialEndNotificationService`'s idempotency pattern.

End of report.
