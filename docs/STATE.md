# JeniFit — Canonical State

Last updated: 2026-06-25 (v1.1.2, build 22)

This is the source-of-truth doc. Read it first. Anything earlier in
`docs/archive/` documented a research pass or pivot that informed shipped
work and is preserved for history, not for guidance. When this doc and
an archived doc disagree, this doc wins.

---

## 1. Who the app is for

JeniFit is a women's weight-loss iOS app. Primary audience is TikTok-acquired
women 22-35, weight-loss-motivated, anti-femvertising. The brand voice is
post-Ozempic vocabulary (satiety, food noise, permission, fits, tomorrow
resets), lowercase casual, italic-Fraunces punch words on a soft cream
canvas. No diet-culture verbs (no crush / shred / burn / earn / deficit).
No "AI" word in user-facing copy.

The product converges on a GLP-1-era posture (see section 3). It serves the
generic-WL audience first; cohort routing layers acknowledgment on top.

---

## 2. What ships today

### Auth + sync
Anonymous-first Supabase auth, Apple + email upgrade, sign-in recovery,
delete-account + forgot-password (anti-enumeration). All entity reads
filter via `@Query userId` to enforce cross-account isolation. Sign-out
sweeps user-scoped `@AppStorage` keys and cancels retention notifications.
Profile, session_logs, day_progress, weight_logs, session_ratings sync via
typed Codable upserts. UUID case normalized at hydrate boundaries.

### Payment
RevenueCat with `customerInfoStream` observation. `PaymentService`
re-configures on `auth.currentUser` changes so a sign-in/out doesn't
strand the prior user's entitlement. Three-tier paywall (annual +
quarterly + weekly) with 3-day trial on annual + quarterly, none on
weekly. `restore()` flow respects existing paid users (no re-onboarding).
Day-5 anti-refund push gated on trial-active status. Paywall pricing
reads RevenueCat's localized `storeProduct.localizedPriceString` per
Apple Guideline 3.1.2(a) — no hard-coded prices.

### Onboarding
Onboarding v4.5 her75 register, ~53 screens. Cohort routing via
`onboarding_glp1_status` AppStorage key (`no` / `considering` / `past` /
`current` / `prefer_not_say`). Custom weight-loss plan duration derived
per-user from `ProgramGoalCalculator` — three cohort modifiers
encoded (GLP-1 / perimenopause floor at 0.3%/wk, short-sleep penalty per
Nedeltcheva 2010, Wing-and-Phelan default at 0.5%/wk). Live date math on
the pace screen ("around august 14") recomputes per pace.

### Program / Plan tab
Today screen with archetype pill (7 archetypes; tap-to-explain sheet),
day strip with week-ahead archetype letters, long-press → MarkAsDoneSheet
override (row body tap = enters module; state indicator is render-only).
ACSM-grade weight-loss pacing. Rest weeks + restrictive override +
strength-day copy variants. Engine: `ProgramGoalCalculator`,
`ProgramDayPrescription`, `PlanView`.

### JeniMethod (CBT-style lessons)
Manifest-driven curriculum, 42 topic-matched Grok hero photos, CBT-spine
lesson reader (`LessonReaderView`), `LessonPracticeView`, archetype-aware
pillar affinity (lessons bias toward the user's program archetype).
Sharing: lesson quote share card as luxury magazine pull-quote (organic
acquisition lever). See `PlankApp/Views/DietEducation/`.

### Snap Food (food rail)
Camera capture → vision pipeline (GPT-5 base + Claude Opus 4.7
confidence-gated fallback) → 3-slide result carousel:
1. Dense slide with tap-edit (`IngredientEditSheet`), total weight,
   cuisine tag, confidence hint, archetype-aware comparative insight.
2. Food-log share card (handwritten Pinterest register, no text
   shadows).
3. Satiety + aesthetic close.

Food journal swipe-to-delete, photo timeline, weight chart cross-view
refresh via `NotificationCenter` (avoids stale state when navigating
between Becoming and the food rail). QuickAdd has dynamic chip
suggestions (recents + cuisine). See `Packages/PlankFood/`.

### Becoming dashboard
Today's energy tile, protein gauge, weight trend canvas (EMA line +
raw weigh-in headline, 7-day delta vs prior-week's raw — never
day-over-day to avoid scale anxiety), plate timeline with [+] →
snap-food camera, food journal swipe-to-delete. Cohort-aware identity
word + insight lines. Interactivity layer added Phase 4 (insight swipe
cycle, plate swipe-left). See `PlankApp/Views/Analytics/AnalyticsView.swift`.

### Breathwork
`BreathworkHomeCard` + bento tile + science-honest primer. Cites
Balban (Stanford), Epel (Yale), Meerman (BMJ), Sato (Senobi). Cortisol
mechanism, NOT fat-burn claim. Lives in `PlankApp/Views/Welcome/` and
the home rail.

### Steps
First HealthKit-backed rail. 7,500-step anchor (not 10k). Pulse on home
+ bento depth pattern is the model for future health rails. See
`PlankApp/Health/`.

### Launch screen
Pure pink `LaunchBackground` (`#EFB9CF`), status bar hidden, no image.
Loader (`AffirmationLoaderScreen`) is cream with jeni·fit wordmark
fading in at 60ms + her75 affirmation rising in at 340ms (7-line
dayOfYear rotation: "you are becoming her" / "soft is strong" / "your
timeline is yours" / "begin again, anytime" / "small choices stack" /
"kindness is the strategy" / "she is already in you").

### Notifications
Trial-window: day 0 anchor + day 2 engagement + trial-end T-24h. Daily
reminder via `NotificationPermission.scheduleDailyReminder` (canonical
id `daily_reminder`, voice-adaptive body, surgical pending-removal so
trial-end isn't nuked). Cohort-aware variants (general WL / on-GLP-1 /
post-GLP-1 / considering) per the spec at
`docs/notification_system_spec_2026_06_16.md` +
`docs/notification_per_cohort_preview_v2_2026_06_16.md`. Day-5
anti-refund push is gated on trial-active so it doesn't fire on
cancelled trials.

---

## 3. GLP-1 cohort strategy — convergence, not pivot

`docs/glp1_strategy_2026_06_16.md` is the authoritative reference.
Read it before any feature work that touches cohort routing or copy.

Operating principle: build for the existing generic-WL audience first,
but layer cohort routing on every change so a GLP-1-cohort user gets
the right identity acknowledgment without the engine forking.

The four cohorts (`Glp1Cohort` enum in
`PlankApp/Notifications/RetentionNotifications.swift`):

| Onboarding answer | `Glp1Cohort` | Identity |
|---|---|---|
| `"current"` | `.onGlp1` | woman on a GLP-1 now |
| `"past"` | `.postGlp1` | woman off a GLP-1 in 0-12mo window |
| `"considering"` | `.considering` | weighed the shot, didn't start |
| `"none"` / `"prefer_not_say"` / empty | `.generalWL` | safe default |

The cohort routing pattern: **cohort signal lives in the noun phrase /
identity acknowledgment, NOT in feature promises.** Bodies reference
only features that ship today (lessons, breath cards, Becoming, food
rail). Until protein floor / food-noise tracker / keep-it-off
curriculum / etc. exist, copy never names them. Every promise must be
cashable in-app within 3 sessions.

Compliance floors (non-negotiable):
- No drug brand names on app-controlled surfaces (Apple 5.2.1).
- No drug-equivalence claims (FTC NextMed $150K precedent).
- No "GLP-1 alternative" / "natural Ozempic" framing (FDA Feb 2026
  warning letters).
- No first-party numeric weight-loss claims.

Companion flag helpers live alongside `Glp1Cohort`: `isShortSleeper`,
`isGLP1User`, `isPerimenopausal` — every cohort-aware engine reads
through these, not raw option strings.

---

## 4. Design system

### Source files
- `PlankApp/DesignSystem/Tokens.swift` — palette, typography, spacing,
  motion, radii. **THE** source of truth for visual tokens.
- `docs/THEME.md` — narrative reference for the same tokens (use this
  to onboard a new agent on the brand, not to look up exact values).
- `docs/itgirl_illustration_system_2026_06_12.md` — illustration
  pipeline + placement grammar.
- `docs/her75_typeface_spec_2026_06_10.md` — JeniHeroSerif identification
  + opto adjustments.
- `~/.claude/projects/-Users-bko-plankAI/memory/feedback_locked_color_tokens.md`
  — locked-tokens rule (the user's auto-memory).

### Locked palette
Only the 8 canonical tokens defined in `Tokens.swift`. The cream
`bgPrimary` is the ONLY background on every surface. `programBgPrimary`,
`programEraBg`, `programCard` are aliases — do NOT introduce new
backgrounds.

### Typography
- **JeniHeroSerif** (Playfair Display 650/620i renamed under OFL) for
  hero headlines + paywall hero + plan-reveal hero. Roman/italic only
  (no Light). LineGap −0.505×size. Intra-word italic flourish on the
  punch word.
- **Fraunces** for wordmark + paywall headline punch + onboarding
  questionHero. Italic accent on 1-3 words per line.
- **DMSans** for body copy + UI chrome + captions.

### Voice signals (in-app copy)
- Italic-Fraunces on the punch word only (`*becoming*`, `*today*`,
  `*shows up*`). NOT `*italic*` markdown syntax — use `ItalicAccentText`
  composition.
- Hearts (♥) as terminal punctuation ONLY.
- Lowercase casual throughout.
- No em-dashes between words. Glyph "—" as no-data placeholder is OK.
- No brand-coined verbs.
- Pill labels 2-4 words. Subheads 5-7 words. Concrete > abstract.

### Motion
8 tokens in `Tokens.swift`: `entrance` / `entranceSoft` / `exit` /
`crossFade` / `tap` / `gentleSpring` / `stagger` / `breathing`. Five
additional her75 transitions: `pageExit` / `pageEntrance` / `pageGap` /
`bloom` / `chipPulse` / `cascadeTight`. All animation sites must reduce-
motion gate.

### Sticker scatter rule
Sticker scatter renders ONLY on the 3 earned moments: welcome / plan
reveal / graduation. Questions, bridges, teach, dashboards, settings
stay scatter-free.

### Real-photo guardrails (Direction A)
Hybrid editorial real-photo hero + coquette sticker accent. Three
non-negotiable guardrails: real photo ≥40% canvas + stickers ≤10% + ≤2
per screen + NO licensed stock ever. AI 3D stickers are permanently
dead. Coquette ID stays via photographed-real-objects.

---

## 5. Where to look for things

| Doc | What it covers |
|---|---|
| `docs/STATE.md` | This file. Start here. |
| `docs/glp1_strategy_2026_06_16.md` | GLP-1 cohort strategy + routing rules. |
| `docs/notification_system_spec_2026_06_16.md` | Notification system architecture + per-cohort copy. |
| `docs/notification_per_cohort_preview_v2_2026_06_16.md` | Founder-reviewed copy preview, v2 supersedes v1. |
| `docs/feature_gap_synthesis_2026_06_16.md` | Convergent vs cohort-specific feature roadmap. |
| `docs/positioning_research_r2_final_2026_06_16.md` | R2 positioning deliverable (R1 archived). |
| `docs/jenifit_v2_strategy_2026_06_13.md` | v2 strategy synthesis (5 expert lanes). |
| `docs/jenifit_positioning_panel_2026_06_15.md` | 5-expert positioning panel. |
| `docs/workout_session_rules.md` | Workout engine source of truth. |
| `docs/THEME.md` | Visual system reference (companion to `Tokens.swift`). |
| `docs/her75_typeface_spec_2026_06_10.md` | JeniHeroSerif spec. |
| `docs/itgirl_illustration_system_2026_06_12.md` | Illustration register + Grok pipeline. |
| `docs/privacy_policy.md` + `docs/terms_of_service.md` | Hosted at jenifit.app/privacy + /terms. |
| `docs/app_store_metadata.md` + `docs/APP_STORE_SCREENSHOTS.md` | ASC metadata drafts. |
| `docs/content_engine_plan.md` | AI-persona TikTok+IG content pipeline. |
| `docs/odr_migration_plan.md` | On-Demand Resources migration future plan. |
| `docs/exercise_balance_audit.md` | Workout L/R balance reference. |

---

## 6. What NOT to look for

Things that USED to be canon and are now in `docs/archive/`. Don't
treat these as guidance:

- **Pivot research from 2026-06-05** (`pivot_research_*`) — the
  workout→diet-first pivot exploration. Resolved into v2 strategy.
- **CalAI research bundle** (`calai_research_*`,
  `calai_teardown_*`) — informed the food rail + onboarding. Patterns
  are now embedded in shipped code.
- **BetterMe research bundle** (`betterme_*`) — informed v1.1 program
  pivot (75-day → custom). Already shipped.
- **Round 1 positioning** (`positioning_research_final_2026_06_16.md`)
  — superseded by R2. The R1 "Quiet" wedge was rejected in favor of
  cohort-led conviction.
- **Round 1 notification preview** (`notification_per_cohort_preview_2026_06_16.md`)
  — v2 collapsed it to ONE trial-end reminder + no spam. Use v2.
- **v1.0.7 / v1.0.9 plan docs** — shipped. Reference only for
  historical "why did we build it this way" questions.
- **Onboarding v2 / v3 / v4 docs** — superseded by v4.5
  (`onboarding_v4_5_conversion_spec_2026_06_11.md`, also archived
  because v4.5 itself shipped).
- **Earlier paywall research v1-v4** — shipped paywall is the result.
- **Earlier Home / Becoming redesign briefs** — shipped. The current
  Home / Becoming code wins over any spec doc.
- **`DESIGN.md` (root-level)** is from 2026-04-22 and is pre-rebrand.
  See section 4 for current design system. Treat the root `DESIGN.md`
  as a pointer; the real source is `Tokens.swift` + `THEME.md` +
  the locked-tokens memory.
- **The earlier `pivot_research_*` and `product_direction_2026.md`
  docs** are the road we didn't take. Useful for context, not for
  current decisions.

---

## 7. Open items at a glance

See `TODOS.md` for the full punch list. Top-of-mind:
- Snap Food manual retry button + photo cache (task #9 deferred)
- v1.2 candidates per the v2 strategy doc (Sprint A trial-conversion
  work, sister-cohort SKU thinking)
- Bundle ID + Xcode project rename (`com.bk.plankAI` →
  `app.jenifit.ios`) when ready to absorb the re-onboard cost
- ElevenLabs voice clip generation pass (cascade in code is wired;
  legacy fallback works)
