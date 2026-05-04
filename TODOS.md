# TODOS

## Status (2026-05-04)

**Shipped:**
- ✅ Auth + sync (cross-account isolation, profile hydration, typed upserts)
- ✅ Auth UX — Phases A–F (delete account, forgot password, polished sign-up,
  polished sign-in, error copy unification, loading state polish)
- ✅ JeniFit rebrand — Phases 1–13 (design tokens, components, onboarding rewrite,
  prediction + loading carousel + plan reveal, home redesign, paywall redesign,
  settings sweep, Sarah → Jeni asset rename, anti-AI sweep, preset rename, URL +
  email sweep, dead-code cleanup)

**Pre-TestFlight blockers** (Ben handles, not Claude Code):
- ⏳ Privacy policy + Terms hosted on jenifit.app (HSTS-preload domain, TLS mandatory)
- ⏳ App icon design / commission (1024×1024 + all device variants)
- ⏳ App Store screenshots (5–10 captures from simulator at 6.7" + 6.5" + 5.5")
- ⏳ App Store description (~4,000 chars, JeniFit voice)
- ⏳ App Store keywords (100 chars, ASO-tuned)
- ⏳ App Store Connect: banking + tax + paid agreement verification
- ⏳ Yearly subscription submitted with the v1.0 binary (Apple requires the first
  sub to be submitted with the app version)
- ⏳ DebugAuthView removed (it's `#if DEBUG` so doesn't ship in release builds, but
  worth confirming the conditional is intact + removing the menu entry in
  HomeView's overflow)
- ⏳ Version bump to 1.0.0 (currently dev/preview build numbering)

**Pending — non-blocking:**
- ⏳ Payment Phase F — schedule local trial-end notification 24h before yearly renews
- ⏳ Payment Phase G — Restore Purchases in Settings (paywall already has restore;
  Settings entry is the redundant secondary surface)
- ⏳ Phase G smoke test on physical device with real Apple Sandbox account (the
  CLI smoke test in Phase 13 was code-level grep verification, not runtime)
- ⏳ Camera permission flow (see entry below)
- ⏳ v1.1 anonymous → authenticated upgrade data preservation (see entry below)

## Payment Phase E — scheme StoreKit Configuration setup
**What:** In Xcode: Product → Scheme → Edit Scheme → Run → Options tab → StoreKit Configuration → select `absmaxxing.storekit`. Manual step because scheme is per-developer (xcuserdata) and shouldn't be force-overwritten by automation.
**Why:** Without this, running from Xcode hits the live App Store sandbox (requires real sandbox tester accounts). With it, purchases simulate locally via the .storekit file — Debug → StoreKit → Manage Transactions for trial expiry / refund / cancel testing.
**Status:** One-time per dev. Each dev does this on their own machine.


## Camera Permission Flow
**What:** Three-state camera permission request flow (notDetermined → pre-permission screen, denied → Settings redirect, restricted → dead-end screen).  
**Why:** The app literally doesn't work without camera access. A raw system dialog gets denied more often than a pre-permission screen with context.  
**Lives in:** PlankApp/ (onboarding + session pre-flight)  
**Depends on:** Nothing (can be built independently)  
**Estimated:** 30–45 min  

### Spec
- `.notDetermined`: Full-screen "Your AI Coach Needs to See You" with illustration. CTA triggers `AVCaptureDevice.requestAccess(for: .video)`. Never show system dialog without pre-permission screen first.
- `.denied`: "Camera access is turned off" with "Open Settings" CTA → `UIApplication.openSettingsURLString`. Secondary "Why do I need this?" expandable.
- `.restricted`: Unskippable "Camera access is restricted on this device." No primary CTA. Secondary "Contact support" link.
- **Placement:** End of onboarding, after quiz + personalized plan, before paywall. Recheck on every session launch.
- **Analytics events:** `camera_permission_requested`, `camera_permission_granted`, `camera_permission_denied`, `camera_permission_settings_opened`

## v1.1 — Cross-device trial-end notification scheduling
**What:** Trial-end reminder is currently scheduled per-device via UNUserNotificationCenter. Users who start a trial on iPhone and only check iPad won't see the 24h reminder on iPad.
**Why:** Local notifications don't sync across the user's device set. v1.1 fix: schedule via Supabase Edge Function + APNs push, keyed on the user's auth.uid() and the trial expiration date from RC's webhook. Server-side schedule means every device the user signs into receives the reminder.
**Status:** v1.1 follow-up. Per-device coverage is sufficient for v1 — most users start the trial on the device they primarily use.

## v1.1 — RevenueCat anonymous → authenticated identity merging
**What:** Investigate using RevenueCat's identity linking so anonymous-period entitlement state merges with the authenticated user on sign-in. Today, an anon user who somehow purchases (rare — paywall is post-onboarding which itself follows sign-in path most of the time) leaves an orphan RC customer record that doesn't carry forward when they later sign in.
**Why:** Defense-in-depth for an edge case that's structurally unlikely in our flow but possible if onboarding paths change. Phase B's logIn already aliases anon → named for the same Supabase uid (sign-up upgrade case); this v1.1 item is the broader case.
**Status:** Not blocking. v1.1 follow-up.

## v1.1 — RevenueCat dashboard sandbox attribution gap
**What:** Sandbox/.storekit purchases don't appear in the RevenueCat dashboard's Customers tab. RC tracks customers via real receipt validation, which the local StoreKit Configuration File doesn't supply.
**Why:** Informational only. Resolves naturally once we test on a real device with a sandbox tester account or once production receipts start flowing post-launch. No code change needed.
**Status:** Not actionable until TestFlight sandbox testing or production launch.

## v1.1 — Anonymous → authenticated upgrade data preservation
**What:** Untested code path. If users report data loss after signing in following an anonymous-only period, fix by adding migration UPDATE statements in AuthService upgrade methods.
**Why:** Supabase docs claim automatic preservation, so this should never need to run. Defer until real reports surface.
**Status:** Not blocking. v1.1 follow-up.

## Pre-launch — Publish Terms + Privacy pages
**What:** Make `https://jenifit.app/terms` and `https://jenifit.app/privacy` resolve to real pages before App Store submission. (Phase 7 paywall + SignUpView legal text both link to these URLs and open them in SFSafariViewController.)
**Why:** Right now they're placeholders — App Review will reject if the links 404 or 500. The `.app` TLD is on the [HSTS preload list](https://hstspreload.org/?domain=app), so browsers refuse plain HTTP — hosting must serve TLS by default (Cloudflare / Vercel / Netlify all give this for free; bare-metal hosting must wire up Let's Encrypt + auto-redirect 80 → 443).
**Status:** Blocking App Store submission. Not blocking dev. Domain swap from `absmaxxing.com` → `jenifit.app` happened with the rebrand; the pages still need to be authored + published.

## Phase 5 — Loading carousel placeholder numbers
**What:** Three rotating frames in `loadingCarouselScreen` (case 180) ship with placeholder strings that need real-data swaps once we have them.
**Why:** Numbers must be defensible if surfaced as proof. Anything fabricated reads as marketing puffery and risks App Review (Guideline 3.1.1 / 5.2.5) and FTC scrutiny on weight-loss claims.
**Status:** Update post-launch as real data lands. All three are tagged with `// TODO(post-launch)` inline comments in OnboardingView.swift.

- **Frame 1:** `"1,000+ early-access members"` → swap with real auth user count once the analytics pipeline reports stable numbers (~30 days post-launch).
- **Frame 2:** `"100+ hours of plank coaching"` → swap with real cumulative session-hour total from `session_logs` aggregate. Pull from a Supabase materialized view refreshed daily.
- **Frame 3:** `"5.0 ★ early reviews"` → swap to real App Store rating + review count via App Store Connect API. Don't surface until ≥30 reviews exist; under that threshold the rating distribution is too noisy and a single 1-star drop reads as a regression.

## Phase 6 — Editorial photography for home workout card hero
**What:** Replace the EditorialPlaceholder hero (180pt, "EDITORIAL · WORKOUT COVER" label) at the top of `jenifitWorkoutCard` (HomeView.swift) with real workout photography that rotates per workout preset. Each `WorkoutPreset` should map to a hero image — same goal/preset shows the same image, so the home feels personal across days.
**Why:** v1.0 ships with the diagonal-stripe placeholder so the home screen scans intentional. Real photography is the single biggest jump from "designed nicely" to "premium feels real."
**Spec:** Same shoot guidance as the Phase 5 entry below (4:5, cream/beige bg, soft natural lighting, aspirational-feminine, no body-shame coding). 4–6 hero shots covering the four `WorkoutGoal` cases (`strength` / `definition` / `sculpting` / `fullCore`) with at least one variant per goal.
**Status:** Ben commissioning. v1.1 swap target. Photo selection by `workout.goal` (or `workout.id` for finer control) — wire up the asset map at swap time.

## Phase 5 — Editorial photography for reshape + welcome
**What:** Replace the headline-only reshape transition (case 160) and the editorial placeholder on the Welcome screen with real photography. Goal: 3 photos for the reshape moment OR 1 hero photo (TBD), plus 1 hero photo for Welcome.
**Why:** v1.0 ships clean without imagery to avoid the "stock photo" or "fake silhouettes" smell. Real, brand-aligned photography is the right v1.1 lift — it's the visual anchor the dusty-rose / Fraunces / cocoa palette is currently asking for.
**Spec:**
- Aspect: 4:5 portrait
- Background: cream / beige / soft neutral (matches `Palette.bgPrimary`)
- Lighting: soft natural, no high-contrast shadows
- Subject: aspirational-feminine, not body-shame-coded, not aesthetic-influencer-coded
- Format: PNG export, 2x + 3x asset variants for `@2x` / `@3x` slots
**Status:** Ben commissioning. v1.1 swap target — no placeholder logic in code, just clean ship without the imagery for v1.0.

## v1.1 — Multi-day program system (real [N Days] semantics)
**What:** Today every `WorkoutPreset` is a single ~5–10 min session — `pool[routineCount % pool.count]` cycles through them daily. Phase 11 originally tried to use "[N Days] · X" naming as JustFit-style program prefixes, but the framing didn't fit the data (the prefix implied a 21- or 30-day journey that the schema doesn't model). Phase 11 polish stripped the prefix; this entry tracks the v1.1 real-program lift.
**Spec:**
- New `Program` schema: `id`, `name`, `lengthDays`, `goal`, `defaultDifficulty`, `description`, `dayPlan: [ProgramDay]`. Each `ProgramDay` references a `WorkoutPreset` (or generates a session inline) plus a day-specific note / progression marker.
- New `ProgramEnrollment` (per-user) tracking: `programId`, `startedAt`, `currentDay`, `completedDays`, `skippedDays`, `progressionUnlocked`.
- Home rotates by `programDay` instead of `routineCount` modulo. Plan reveal carries program copy ("28 days, 12 sessions, your slow build"). Paywall keeps the app-level "30 days" arc.
- Library expands beyond the existing 20 sessions — at minimum 4–6 program-length curricula (Become Her, Glow Up, Pilates Princess, Body Reset, Lazy Girl, Trip Prep) each with 14–30 unique sessions, progressive difficulty, and named rest days.
**Why:** Sets the foundation for streaks-by-program, plan personalization that updates weekly, and the marketing surface ("by day 14 you'll …") that the audit's commitment-escalation pattern leans on. Single-session presets can't carry that arc.
**Status:** v1.1 work. Not blocking v1.0; the current session-cycle pool ships as-is. Estimated 2–3 weeks once the library content is authored — schema + scheduler + UI is the smaller piece.

## v1.1 — Subscription SKU rename
**What:** RevenueCat product identifiers `absmaxxing_weekly` and `absmaxxing_yearly` (in `PlankApp/Config/RevenueCatConfig.swift`) ship under their legacy names for v1.0. v1.1 should rename to `jenifit_weekly` / `jenifit_yearly` (or whatever final SKU naming lands), submitted alongside a new app version.
**Why:** Renaming SKUs on a live App Store Connect listing requires creating new products, dual-listing with both old and new for a transition window, and migrating existing subscriptions via RevenueCat's product-rename flow. Doing it post-launch with real subscribers is the safer path than trying to land it in v1.0.
**Status:** v1.1. Coordinate with the Bundle ID + Xcode project rename below — they'll likely ship together.

## v1.1 — Bundle ID + Xcode project rename
**What:** Bundle identifier `com.bk.plankAI` and Xcode project name `plankAI.xcodeproj` stay legacy for v1.0. v1.1 should rename to JeniFit-aligned values (e.g., `app.jenifit.ios` and `JeniFit.xcodeproj`).
**Why:** Bundle ID changes require either App Store Connect transfer (Apple-mediated, ~5 business days) or shipping a new app at the new Bundle ID with a redirect from the legacy app. Xcode project rename forces every dev to re-clone or rewrite their xcuserdata. Better to do once with the SKU rename + Phase 9 voice clip carryover so users only re-onboard once.
**Status:** v1.1. Coordinate with SKU rename + `.storekit` file rename + asset catalog cleanup.

## v1.1 — WorkoutGoal enum + library expansion
**What:** `WorkoutGoal` currently has 4 cases: `strength` / `definition` / `sculpting` / `fullCore`. The Phase 4 onboarding `bodyFocus` introduced 5 user-facing zones (flat belly / toned arms / round butt / slim legs / full body) but only `flatBelly` maps cleanly through (→ `definition`); everything else collapses to `fullCore`. Plus the workout library is core-only — no glute/leg presets.
**What's needed:** Expand `WorkoutGoal` (e.g., add `glutes`, `legs`, `arms` cases), author at least 3–4 presets per new case, update `focusAreaFromBodyFocus` to do real 1:1 mapping, and update `EditProfileView`'s `legacyUserGoal` mirror to match.
**Why:** Today the personalization promise on the paywall ("Build your round butt in 30 days") routes the user to a fullCore session. The honest fix is library expansion, not just rebranding the existing core sessions.
**Status:** v1.1. Library content authoring (~10–15 new presets) is the bulk of the work; the schema change is small. Likely paired with the multi-day program system above.

## v1.1 — Trial notification identifier rename + migration
**What:** `TrialEndNotificationService.identifier` is hardcoded to `"absmaxxing.trial.ending.reminder"`. v1.1 rename to `"jenifit.trial.ending.reminder"` (or whatever final namespace lands).
**Migration plan:** On first launch under the renamed identifier, the service should call `removePendingNotificationRequests(withIdentifiers: ["absmaxxing.trial.ending.reminder"])` once before scheduling under the new ID. Without that, existing users with a pending trial-end reminder under the legacy ID will get either a duplicate notification (both fire) or an orphaned scheduled notification that never gets cancelled if they later cancel their trial.
**Why:** Local notification IDs are stable per-device; renaming without migration is the worst of both worlds. The migration is a single line in `scheduleIfNeeded` plus a one-time `UserDefaults` flag so it doesn't run on every schedule call.
**Status:** v1.1. Pair with SKU + Bundle rename so the namespace cutover happens once.

## v1.1 — EditProfileView legacy-user fallback
**What:** Phase 8 switched `EditProfileView` to read/write `bodyFocus` (the new Phase 4 truth). Legacy users whose `bodyFocus` AppStorage is empty (onboarded before Phase 7's `bodyFocus` mirror landed) see no preselected option — picking any option re-establishes both fields, but the empty-state read is a small UX paper-cut.
**Fix:** Add a one-shot inference: if `bodyFocus.isEmpty` and `userGoal` is set, derive a best-guess `bodyFocus` value and write it back. Mapping: `definition → flatBelly`, `fullCore → fullBody`, `strength → fullBody`, `sculpting → roundButt` (closest aesthetic match).
**Why:** Pre-rebrand testers will see the empty state on first open of EditProfile post-update. Self-healing on first read avoids needing a manual data migration.
**Status:** v1.1. Not a launch blocker — TestFlight shipping under JeniFit is fresh enough that there are no pre-rebrand testers to inherit.

