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
**What:** Make `https://absmaxxing.com/terms` and `https://absmaxxing.com/privacy` resolve to real pages before App Store submission.
**Why:** SignUpView's legal text links to those URLs and opens them in SFSafariViewController. Right now they're placeholders — App Review will reject if the links 404 or 500.
**Status:** Blocking App Store submission. Not blocking dev.
