# TODOS

## Status (2026-04-30)

**Shipped:**
- ✅ Auth + sync (cross-account isolation, profile hydration, typed upserts)
- ✅ Auth UX — Phases A–F (delete account, forgot password, polished sign-up,
  polished sign-in, error copy unification, loading state polish)

**Pending:**
- ⏳ RevenueCat payment integration — next Claude Code session
- ⏳ App Store assets (icon, screenshots, copy)
- ⏳ Privacy policy + Terms hosting on absmaxxing.com (see entry below)
- ⏳ TestFlight prep — DebugAuthView removal, Phase G smoke test on physical device
- ⏳ Camera permission flow (see entry below)
- ⏳ v1.1 anonymous → authenticated upgrade data preservation (see entry below)


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

## v1.1 — Anonymous → authenticated upgrade data preservation
**What:** Untested code path. If users report data loss after signing in following an anonymous-only period, fix by adding migration UPDATE statements in AuthService upgrade methods.
**Why:** Supabase docs claim automatic preservation, so this should never need to run. Defer until real reports surface.
**Status:** Not blocking. v1.1 follow-up.

## Pre-launch — Publish Terms + Privacy pages
**What:** Make `https://absmaxxing.com/terms` and `https://absmaxxing.com/privacy` resolve to real pages before App Store submission.
**Why:** SignUpView's legal text links to those URLs and opens them in SFSafariViewController. Right now they're placeholders — App Review will reject if the links 404 or 500.
**Status:** Blocking App Store submission. Not blocking dev.
