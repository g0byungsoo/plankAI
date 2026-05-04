## Project status (2026-05-04)

The product ships as **JeniFit** for v1.0. The Xcode project name + Bundle ID
intentionally stay legacy (`plankAI` / `com.bk.plankAI`) — renaming those forces
a re-onboarding for every TestFlight tester and a re-submission run through
App Review. v1.1 handles the project + Bundle + SKU rename together.

JeniFit rebrand (Phases 1–13) shipped end-to-end. Brand strings, asset names,
voice clip filenames, AI language, paywall copy, preset names, settings copy,
and onboarding question content all migrated. Code-level smoke test passes
(zero `AI` / `absmaxxing` / `Sarah` / `plankAI` matches in user-facing Swift
strings; remaining matches are intentional internal identifiers tracked in
TODOS.md for the v1.1 SKU + Bundle rename).

- **Auth + sync**: functional end-to-end. Anonymous-first Supabase auth, Apple + email
  upgrade, sign-in recovery. Profile + session_logs + day_progress sync via typed
  Codable upserts; cross-account isolation enforced via @Query userId filters in
  HomeView/AnalyticsView; UUID case normalized at hydrate boundaries. Verified on
  device with two distinct Apple IDs (test 1/2/3 in commit 2d9c34c).
- **Auth UX (Phases A-F)**: shipped. Delete Account flow (Apple guideline 5.1.1(v),
  Supabase RPC + cascade), Forgot Password (anti-enumeration), polished sign-up +
  sign-in screens (Apple required button, dusty rose accent, password requirements
  checklist, mode toggle, in-app SFSafariViewController for Terms/Privacy), unified
  friendly error copy, PulsingDots loading, ShakeEffect on submission errors.
- **Payment (RevenueCat)**: SDK initialized (Phase A), customerInfoStream
  observation + auth-state sync (Phase B), polished paywall with personalized
  headline + dynamic pricing from offerings (Phases C+D), session entitlement
  gates wired in HomeView (Phase E). Phase 7 redesigned the paywall under the
  JeniFit brand: "Become her in 30 days." italic-accent headline keyed off
  bodyFocus, accent-rose CTA, savings-% hierarchy split out of the subtitle.
  StoreKit Configuration File at `PlankApp/Resources/absmaxxing.storekit`
  handles sandbox testing — file name stays legacy to avoid scheme-config
  reset for every dev (rename in v1.1 with SKU + Bundle rename). Set the
  scheme's StoreKit Configuration option to it (Product → Scheme → Edit
  Scheme → Run → Options → StoreKit Configuration). For TestFlight/production,
  leave scheme set to None — purchases use the real App Store.
- **Onboarding**: Phase 4 rewrote the question set into 6 parts with section
  dividers + confirmation badges. Phase 5 added the prediction + loading
  carousel + plan reveal redesign. Phases 6 / 7 / 8 redid the home screen,
  paywall, and settings/auth surfaces. Phase 9 renamed the trainer system
  end-to-end (Sarah → Jeni, including 93 voice clip files + asset catalog).
  Phase 13 removed the dead in-flow paywall (case 24); the post-onboarding
  paywall lives outside the flow on RootView's fullScreenCover.
- **Open items**: TestFlight prep — see TODOS.md "Pre-TestFlight blockers"
  section for the full list (Privacy/Terms hosting on jenifit.app, App Store
  assets + description + keywords, banking + tax in App Store Connect,
  DebugAuthView removal, version bump, app icon).

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
