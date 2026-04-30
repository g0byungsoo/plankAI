# TODOS

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

## Strip diagnostic logging before TestFlight
**What:** Remove the `print(...)` lines added during item 1–3 sync debugging.
**Why:** Logs were instrumented to localize the upsert/hydrate/UUID-case bugs. They're noisy in the simulator console and ship Apple-relayed metadata (auth uids, full names) into device logs. Production should be silent on the happy path.
**Lives in:**
- `Packages/PlankSync/Sources/PlankSync/SyncService.swift` — `hydrateUser`, `upsertSessionLog`, `upsertDayProgress`, `upsertUser`
- `PlankApp/Sync/AppSync.swift` — `syncUserDefaultsFromUserRecord`, `upsertUser`, `hydrateAndSync`
- `PlankApp/PlankAIApp.swift` — `handleOnboardingComplete`, `upsertLocalUserRecord`
**Keep:** `FAILED:` paths in catch blocks (low signal-to-noise but useful when it breaks). Strip everything else.
**Estimated:** 10 min
