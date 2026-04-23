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
