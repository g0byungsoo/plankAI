## Project status (2026-06-25)

JeniFit ships as v1.1.2 (build 22). The Xcode project name + Bundle ID
intentionally stay legacy (`plankAI` / `com.bk.plankAI`) — renaming forces
a re-onboarding for every TestFlight tester and a re-submission through
App Review. v1.2+ handles the project + Bundle + SKU rename together.

**Authoritative state doc: `/docs/STATE.md`.** Read it first. Anything
in `/docs/archive/` documented a research pass or pivot that fed shipped
work but is preserved for history, not for guidance.

### Auth + sync
- Anonymous-first Supabase auth, Apple + email upgrade, sign-in
  recovery, delete-account + forgot-password (anti-enumeration).
- All entity reads filter via `@Query userId` for cross-account
  isolation. Sign-out sweeps user-scoped `@AppStorage` + cancels
  retention notifications.
- Profile, session_logs, day_progress, weight_logs, session_ratings
  sync via typed Codable upserts; UUID case normalized at hydrate
  boundaries.
- Files: `PlankApp/Auth/`, `PlankApp/Sync/`,
  `Packages/PlankSync/Sources/PlankSync/`.

### Payment (RevenueCat)
- `customerInfoStream` observation. `PaymentService` re-configures on
  `auth.currentUser` changes so sign-in/out doesn't strand prior
  user's entitlement.
- Three-tier paywall: annual + quarterly + weekly. 3-day trial on
  annual + quarterly, none on weekly. Tier-matched downsell sheets on
  cancellation intent.
- Paywall reads RevenueCat's localized `storeProduct.localizedPriceString`
  per Apple Guideline 3.1.2(a). No hard-coded prices.
- `restore()` flow respects existing paid users (no re-onboarding).
- Day-5 anti-refund push gated on trial-active status.
- Files: `PlankApp/Payment/`, `PlankApp/Views/Paywall/`.

### Onboarding
- v4.5 her75 register, ~53 screens. JeniHeroSerif on hero headlines.
- Cohort routing via `onboarding_glp1_status` AppStorage key (`no` /
  `considering` / `past` / `current` / `prefer_not_say`).
- Custom weight-loss plan duration derived per-user from
  `ProgramGoalCalculator`. Three cohort modifiers encoded: GLP-1 /
  perimenopause floor (0.3%/wk), short-sleep penalty per Nedeltcheva
  2010, Wing-and-Phelan default (0.5%/wk).
- Live date math on the pace screen recomputes per pace.
- Files: `PlankApp/Views/Onboarding/`.

### Program / Plan tab
- Today screen with archetype pill (7 archetypes; tap-to-explain
  sheet), day strip with week-ahead archetype letters.
- Row body tap → enters module. State indicator is render-only.
  Long-press → MarkAsDoneSheet override.
- Reset weeks + restrictive override + strength-day copy variants.
- ACSM-grade weight-loss pacing.
- Files: `PlankApp/Views/Plan/`, `PlankApp/Program/`.

### JeniMethod (CBT-style lessons)
- Manifest-driven curriculum, 42 topic-matched Grok hero photos,
  CBT-spine lesson reader.
- Archetype-aware pillar affinity — lessons bias toward the user's
  program archetype.
- Lesson quote share card as luxury magazine pull-quote (organic
  acquisition lever).
- Files: `PlankApp/Views/DietEducation/`,
  `PlankApp/Views/DietEducation/Reader/`.

### Snap Food (food rail)
- Camera → vision pipeline (GPT-5 base + Claude Opus 4.7
  confidence-gated fallback + Gemini 2.5 Flash food-or-not pre-filter).
- 3-slide result carousel: dense tap-edit slide + food-log share card
  (handwritten Pinterest register) + satiety + aesthetic close.
- `IngredientEditSheet` behind pencil tap (original-portion tick +
  reset + confidence hint).
- Food journal swipe-to-delete + photo timeline.
- QuickAdd: dynamic chip suggestions (recents + cuisine).
- Cross-view refresh via `NotificationCenter` for weight chart +
  food journal.
- Files: `Packages/PlankFood/`,
  `PlankApp/Views/Analytics/` (food log surfaces).

### Becoming dashboard
- Today's energy tile, protein gauge, weight trend canvas (EMA line +
  raw weigh-in headline, 7-day delta vs prior-week's raw).
- Plate timeline with [+] → snap-food camera, food journal
  swipe-to-delete.
- Cohort-aware identity word + insight lines.
- Interactivity: insight swipe cycle, plate swipe-left.
- Files: `PlankApp/Views/Analytics/AnalyticsView.swift`,
  `PlankApp/Views/Analytics/LogWeightSheet.swift`,
  `PlankApp/Views/Analytics/LastNightSleepCard.swift`.

### Breathwork
- `BreathworkHomeCard` + bento tile + science-honest primer (Balban
  Stanford, Epel Yale, Meerman BMJ, Sato Senobi — cortisol
  mechanism, NOT fat-burn claim).
- Files: `PlankApp/Views/Home/BreathworkHomeCard.swift`,
  `PlankApp/Views/Welcome/BreathworkSessionView.swift`,
  `PlankApp/Views/Welcome/BreathLibraryView.swift`.

### Steps (HealthKit)
- First HealthKit-backed rail. 7,500-step anchor (not 10k).
- Pulse on home + bento depth pattern is the model for future health
  rails.
- Files: `PlankApp/Health/`.

### Launch + loader
- Pure pink `LaunchBackground` (`#EFB9CF`), status bar hidden, no
  image.
- `AffirmationLoaderScreen` cream with jeni·fit wordmark fading in at
  60ms + her75 affirmation rising in at 340ms.
- 7-line dayOfYear rotation: "you are becoming her" / "soft is strong"
  / "your timeline is yours" / "begin again, anytime" / "small choices
  stack" / "kindness is the strategy" / "she is already in you".
- Files: `PlankApp/Views/Welcome/AffirmationLoaderScreen.swift`,
  `PlankApp/PlankAIApp.swift`.

### Notifications
- Trial-window: day 0 anchor + day 2 engagement + trial-end T-24h.
- Daily reminder via `NotificationPermission.scheduleDailyReminder`
  (canonical id `daily_reminder`, voice-adaptive body, surgical
  pending-removal so trial-end isn't nuked).
- Cohort-aware variants (general WL / on-GLP-1 / post-GLP-1 /
  considering) per `docs/notification_system_spec_2026_06_16.md` +
  `docs/notification_per_cohort_preview_v2_2026_06_16.md`.
- Day-5 anti-refund push gated on trial-active so it doesn't fire on
  cancelled trials.
- Files: `PlankApp/Notifications/`.

### GLP-1 cohort strategy
- Convergence-not-pivot. See `docs/glp1_strategy_2026_06_16.md`.
- `Glp1Cohort` enum + helper flags (`isShortSleeper`, `isGLP1User`,
  `isPerimenopausal`) in
  `PlankApp/Notifications/RetentionNotifications.swift`.
- Cohort signal lives in the noun phrase / identity acknowledgment;
  bodies reference only shipping features (lessons, breath cards,
  Becoming, food rail).
- Compliance floors: no drug brand names on app-controlled surfaces
  (Apple 5.2.1), no drug-equivalence claims (FTC NextMed precedent),
  no "GLP-1 alternative" framing (FDA Feb 2026 warning letters), no
  first-party numeric weight-loss claims.

### Design system
- `PlankApp/DesignSystem/Tokens.swift` is the source of truth (palette,
  typography, spacing, motion, radii).
- 8 locked color tokens. `bgPrimary` cream is the ONLY background.
- JeniHeroSerif (Playfair Display 650/620i renamed under OFL) on hero
  headlines. Fraunces on wordmark + punch words. DMSans on body.
- Voice signals: italic-Fraunces on punch word, hearts as terminal
  punctuation only, lowercase casual, NO em-dashes between words, NO
  "AI" word in user copy.
- Sticker scatter on the 3 earned moments only (welcome / plan reveal
  / graduation).
- See `docs/THEME.md` for narrative reference,
  `docs/itgirl_illustration_system_2026_06_12.md` for illustration
  pipeline, `docs/her75_typeface_spec_2026_06_10.md` for the
  JeniHeroSerif spec.

### Compliance + metadata
- `MARKETING_VERSION = 1.1.2`, `CURRENT_PROJECT_VERSION = 22`.
- `LSApplicationCategoryType = public.app-category.healthcare-fitness`.
- Privacy policy + terms hosted at `jenifit.app/privacy` +
  `jenifit.app/terms`. Drafts at `docs/privacy_policy.md` +
  `docs/terms_of_service.md`.
- App Store metadata at `docs/app_store_metadata.md`. Screenshot spec
  at `docs/APP_STORE_SCREENSHOTS.md`.

### Open items
- See `TODOS.md` for current punch list.
- Snap Food manual retry button + photo cache deferred.
- v1.2+ Bundle ID + Xcode project rename when ready to absorb
  re-onboard cost.
- ElevenLabs voice clip generation pass (cascade wired, legacy
  fallback works).

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
