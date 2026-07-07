## Project status (2026-06-25)

JeniFit ships as v1.1.2 (build 22). The Xcode project name + Bundle ID
intentionally stay legacy (`plankAI` / `com.bk.plankAI`) — renaming forces
a re-onboarding for every TestFlight tester and a re-submission through
App Review. v1.2+ handles the project + Bundle + SKU rename together.

**Authoritative state doc: `/docs/STATE.md`.** Read it first. Anything
in `/docs/archive/` documented a research pass or pivot that fed shipped
work but is preserved for history, not for guidance.

### App v5 (2026-07-07, branch feat/app-v2)
Part 1 — the language/trust pass: private language retired app-wide
(today's plates / your weekly review / weighed in N times / the
plateau week), day-one teaching reading + trend-language data floor
(3+ weigh-ins over 5+ days), unit-aware trend story, jeni
transcript as dated letters + persistent starter chips, breath
bloom at 360pt presence, labeled evening questions, plain day
receipts. Part 2 — the re-steer: **becoming = a horizontal insight
story** (JKStoryPage pager: weight / food+chemistry / movement /
this-week / band / from-jeni; visuals re-arm per swipe), **Home =
THE DAY RAIL** (seven tappable day cells, today as a filled date
pill, past days open receipts), her-weeks timeline one level in,
rebuilt protein arc + under-glow trend figure, calories lead Home's
food sentence + carbs/fat/fiber surfaced (vitamins/minerals need
the fenced EF). **Read `docs/app_v5/00_DIRECTION.md` first (§6 =
re-steer); 01_REPORT.md §8 = part-2 evidence + gaps.** Supersedes
v4's language layer and becoming's ledger layout; v4 engines stand.

### App v4 (2026-07-07, branch feat/app-v2)
The program became an object: ProgramArc phases + WeekIntent named
weeks + THE RE-SIGNING (weekly consented adaptation, WeeklyReview);
becoming rebuilt as THE JOURNEY (arc ribbon, week-chaptered ledger,
day receipts, signed stamps, her-plates archive); Today gains the
week ribbon + plate story + tonight plan; breath rebuilt
(JKBreathField bloom + BreathHaptics continuous curves); workout
completion = kept receipt (stars dead app-wide); jenifit://
registered. **Read `docs/app_v4/00_THESIS.md` first; 05_REPORT.md =
evidence + honest gaps.** Supersedes app_v3 where they disagree.

### App v3 (2026-07-05, branch feat/app-v2)
Reading-first rebuild over v2: Today = jeni's reading + THE ONE
THING + rhythm rows (no checklist grammar, no padlocks); three
chapters (losing / on-medication / keeping) with real mechanics
(protein-adequacy nets, sit-check, BandModel STOP-Regain zones);
the method = THE REP (RepView/RepEngine); PresenceLedger (kept days,
any action, never resets); BreakState; her-file card in chat.
**Read `docs/app_v3/00_THESIS.md` first**; safety report + honest
gaps live beside it. Verified research: `docs/app_v3/research/`.

### App v2 (2026-07-03, branch feat/app-v2)
The in-app experience was rebuilt: route-level AppPhase gating
(`PlankApp/App/`), three tabs (today/jeni/becoming) over JKTabBar,
TodayView daily ritual (`Views/Today/`, PrescriptionEngineV2 beats),
JeniFit Chat (`PlankApp/Chat/` + `supabase/functions/jeni-chat`),
JeniKit component dialect (`DesignSystem/Kit/`), TargetsService +
CohortStore as single sources of truth, migration moment for legacy
users. Read `docs/app_v2/00_README.md` first before touching any of
it. PlanView survives behind `--legacy-today` until the founder
sign-off sweep. Chat EF needs `supabase functions deploy jeni-chat`
+ the 20260703 migration SQL (founder credential).

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
- **v5 rebuild (2026-07-02)**: typed state machine, 5 acts, ~46 beats,
  GLP-1 branches (current/past/considering) asked at the top of Act II.
  Read `docs/onboarding_v5/SHIPPED.md` before touching anything here.
- Interaction language: cross-off single-selects (auto-advance), tick
  rulers w/ haptic detents + delta band, strike-the-fear statements,
  act-end receipts, snap demo (real Metal sweep over staged plates),
  her-file dossier + signature + hold-to-build.
- Safety gate relocated to "the care part" (end of numbers act, still
  pre-paywall). Name collected in Act I (dossier/loader/projection/wall
  all addressed). Rating ask is post-purchase ONLY.
- Reveal: receipt-tape loader (live keys only), causal receipts on the
  projection, cohort-routed first-week rails, merged promise/nudge time
  anchor, trial-reminder promise row on the notification ask.
- Data contract identical to v4.5 (`docs/onboarding_v5/DATA_CONTRACT.md`);
  cohort pace floors unchanged in `ProgramGoalCalculator`.
- Legacy v4.5 reachable via `--onboarding-v4` until the sweep.
- QA: `OnboardingV5WalkerUITests` (screenshot per beat;
  `TEST_RUNNER_GLP1_COHORT=current|past` for branches).
- Files: `PlankApp/Views/OnboardingV5/` (+ legacy `PlankApp/Views/Onboarding/`).

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
- v1.2 rebuild (2026-07-01). Input modes: snap / describe / again
  (one-tap relog via `RecentMealsSheet`).
- Camera → vision EF (single OpenAI model, env-selected; app-side
  USDA calibration on low-confidence items) → result = 3-slide
  carousel over the full-bleed photo (2026-07-02): plate panel ·
  jeni note (sparkle accent) · on-photo share composer. Photo never
  moves; white dots on top; `SnapResultView` owns the slides.
- Editing (slide 1): fraction chips (ate about half), inline portion
  steppers, `IngredientEditorSheet` with coherent macro↔kcal math
  (`PlateEditSession`, unit-tested), "fix it with words" +
  "+ add something" via `SnapRefine` (EF text path — live today).
- Scanning = Metal `snapSweep` pass (SPM-compiled
  `SnapShaders.metal`); capture bloom; calm chrome (2pt border).
  Result-land = retinted Sparkling lottie burst
  (`FoodResultExplosion`; replaced heart + star).
- Share (slide 3) = on-photo composer (`SnapShareSlide` font rail);
  preview IS the exported PNG.
- Per-item detail persists per entry (device-local); journal detail
  ledger + relog. Photo+text context awaits
  `supabase functions deploy food-vision`.
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
