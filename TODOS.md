# TODOS

## Status (2026-04-30)

**Shipped:**
- ✅ Auth + sync (cross-account isolation, profile hydration, typed upserts)
- ✅ Auth UX — Phases A–F (delete account, forgot password, polished sign-up,
  polished sign-in, error copy unification, loading state polish)

**Pending:**
- ⏳ Payment Phase F — schedule local trial-end notification 24h before yearly renews
- ⏳ Payment Phase G — Restore Purchases in Settings + DebugAuthView removal
- ⏳ App Store assets (icon, screenshots, copy)
- ⏳ Privacy policy + Terms hosting on absmaxxing.com (see entry below)
- ⏳ TestFlight prep — Phase G smoke test on physical device with real Apple Sandbox account
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

