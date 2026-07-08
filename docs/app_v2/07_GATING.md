# 07 — Subscription gating plan (AppPhase machine)

## Intent

Replace the cover-over-content model with a route-level phase machine
so unpaid/expired users never have main-app content mounted, expired
users get a designed state instead of the acquisition paywall, and
the offline policy is explicit instead of accidental.

## The machine

`AppPhaseController` (@MainActor @Observable) derives ONE phase from
(auth, payment, storage flags) — pure function, unit-testable:

```
booting      auth not ready || entitlement not ready || splash hold
onboarding   !hasCompletedOnboarding
wall(.fresh)     completed && never-entitled
wall(.expired)   completed && was-entitled && !entitled
migration    entitled && !hasSeenAppV2 && hasLegacyFootprint
firstRun     entitled && !hasSeenAppV2 && !hasLegacyFootprint…
             (folded into post-purchase flow; see 08)
main         entitled
```

`RootView` v2 switches on the phase — exactly one branch mounted,
`JFPageTransition.softDissolve` between phases. The paywall is a
destination, not a cover; downsell/winback stay sheets on it.

- `wasEverEntitled` — new persisted bool, set true on any active emit
  (backfilled true if cached lastKnownEntitlement was true). Drives
  the `.expired` wall variant: "welcome back" framing, restore
  first-class, reactivation CTA, her plan preserved ("day 23 is
  waiting"). No forced re-onboarding ever.
- Purchase success on either wall → phase recomputes → migration or
  main. `presentPostPurchaseFlowIfEligible` logic moves into the
  phase controller (fresh purchase → firstRun flag).

## Offline policy (fixes fail-open #6, keeps paid users unharmed)

`entitlementVerifiedAt` — persisted timestamp, stamped on every
customerInfoStream emit AND on successful safety-timeout refresh.
Policy at boot when the stream can't confirm:

- cached entitled + verified within **72h** → main (grace).
- cached entitled + stale >72h + offline → main **with a quiet
  re-verify banner state**, retry loop; if a definitive "not
  entitled" ever arrives → wall(.expired). (A hard lockout on stale
  cache would punish airplane-mode paid users — RC's own SDK cache
  is authoritative-ish; 72h bounds the abuse window instead of
  pretending it's zero.)
- cached entitled + ONLINE refresh says expired → wall(.expired)
  immediately (this is the actual hole today — the forced refresh
  result now feeds the phase, not just the flag).
- auth-transition suppression stays, but suppression holds the
  PREVIOUS phase rather than unmounting the wall (no flash, no leak).

## Defense in depth

- `MainShell.task` re-asserts: if phase != .main → it renders
  nothing (belt and suspenders against any future binding refactor).
- Chat EF + food EF already JWT-gate server-side; jeni-chat adds a
  `sub.day_since_purchase` sanity field but access control remains
  the JWT (entitlement enforcement server-side is out of scope and
  RevenueCat-webhook-shaped; documented as v2.1 hardening).
- `FoodFlags` switches to `effectiveHasProAccess` (QA consistency).
- `main_tab_appeared` analytics fires only in .main (fixes funnel
  inflation).

## QA matrix (verified in phase 10)

fresh install → onboarding → wall(.fresh) → purchase → first-run →
main · relaunch paid → splash → main (no wall flash) · expired
online → wall(.expired) · expired offline <72h→ main-grace ·
sign-out/in → no cover flash (suppression) · `--uitest-pro-access`
walker paths still work (DEBUG).
