# JeniFit — Canonical State

Last updated: 2026-07-27 (app v7 phases 1-2 on `feat/app-v2`)

## -5. App v7 — THE CARE PLAN (2026-07-27)

**Doc set: `docs/app_v7/` (00_THESIS · 01_BUILD · panel/). Read
00_THESIS.md first — it is the redesign law, synthesized from an
11-expert independent critique panel + a behavior-change
literature lane (all critiques preserved in `panel/`).**

The founder's first-principles redesign brief: stop feeling like a
calorie/habit tracker; feel like a companion quietly taking care
of her. Phases 1-2 shipped:

- **CarePlanEngine** (`Program/CarePlanEngine.swift`, 17 tests):
  the day composed from STATE, not slot tables — gentle tone
  (tender evening / short night / days away → ONE move by rule),
  clinical lead promotions (rapid-loss protein guard, yesterday's
  protein deficit), weigh-in as the only ringed supporting move,
  workouts/breath/method as invitations. Receipt arithmetic +
  the silk moment follow the plan. The evening feeling chip is
  read back next morning (brief 2.5 + gentle tone in parallel).
- **Home inverted**: position line (day rail DELETED) → THE
  UNDERSTANDING (the reading in full, 22pt serif, the page's
  reason) → the plan (ring policy: rings only on moves) →
  "noticed for you" receipts (overnight fast returned as an
  OBSERVATION — founder's name kept, ≥12h ring deleted; steps
  "counted for you") → evening close. Sticker tiles left daily
  rows (the seal lands ON completion); kcal budget bar died
  ("room for ~600" permission frame); HowItWorksBlock deleted;
  cycle ask moved out of received care.
- **becoming inverted**: the serial pager retired. Landing =
  JENI'S READ OF YOUR WEEK (CoachSummary promoted from pager page
  ~11) + HER SIGNALS hairline index (one-line reads from the same
  generators as the pages) → NavigationStack pushes into the
  untouched story pages (roman folio, AX-safe scroll).
  `--uitest-becoming-page N` now pushes.
- **One thread**: Home's "from jeni" opens the live jeni thread.
  **A11y floors as law**: cocoaTertiary 0.68 (AA on cream,
  `TokensContrastTests`-guarded), VoiceOver "mark as done"
  actions, hearts stripped from spoken labels, 44pt camera, the
  night-sheet blank state fixed (sheet law: no conditional
  closures). Landed-moment haptic collision fixed.
- **JeniMethod verdict (hybrid, literature-cited)**: the daily
  required row died; content atomizes into trigger-matched
  delivery (phase 5); the pull-only shelf + share card survive.
- 309/309 unit tests green.

**Held for next phases** (thesis §11): first-move letters (2-3
unprompted/week, event-triggered, JeniNoteView reserved as the
arrival moment) + comeback tiers + celebration ladder (phase 3);
chart-grammar port + type-ladder sweep + heart budget +
JeniHaptics semantic layer + light-only declaration (phase 4);
ObservationStore + CareProtocol + BrandVoice split + shot-day
anchor + post-medication arc + method atoms + visit-prep card
(phase 5 — the invisible white-label seam).

## -4. App v6 — THE SIGNALS (2026-07-17)

**Doc set: `docs/app_v6/` (00_RESEARCH · 01_BUILD). Read
00_RESEARCH.md first — its safety framing rules are ENGINE LAW,
not copy guidance.**

The passive layer: retention research says passive monitoring
sustains engagement where active logging decays, so v6 turns the
streams the app already holds (plate timestamps, HealthKit
steps/sleep, weigh-ins) into felt understanding with ZERO new input.

- **Engine** (`Program/Signals.swift`, 22 tests): `KitchenSignal`
  (live overnight-window phase machine over QuietHours' math; praise
  saturates at 14h, 16h+ speaks care; the on-medication chapter gets
  the fuel-frame inversion — "first plate landed", never hour
  arithmetic), `SleepSignal` (forgiveness bands), `MealMoves`
  (post-meal walking receipts, Buffey floor), `WeekRhythm`
  (weigh-day cadence + first-plate median), `Sweetness` (time-of-day
  shares + direction, hard floors). All food-derived signals ride
  `QuietHours.mayNarrate`.
- **Home**: the SIGNALS band after the food band — THE WINDOW
  (JKWindowHorizon: the night as a horizon diagram, jkDawn-lit,
  breathing ember when live; tap → WindowSheet w/ 24h ring +
  7-night band + cited mechanism), NIGHT (crescent row; tap →
  NightSheet w/ stage-banded JKSleepDial over a jkNightSky
  starfield + 7-night bars), AFTER-MEAL MOVES (receipt line,
  absence never renders). First-day teaching whisper. The old
  moon caption line is superseded and deleted.
- **Becoming**: pages now line · food · plates · sweetness ·
  window (7-night falling-band figure) · sleep · movement ·
  rhythm · plan · band · reflection. Visuals re-arm per swipe.
- **The word "fasting" never renders.** Windows are observed,
  never prescribed; no timers, no targets, no streaks.
- QA: `--uitest-force-signal <phase>` / `--uitest-force-night` /
  `--uitest-force-signals` / `--uitest-open-window-sheet` /
  `--uitest-open-night-sheet`. Sim gotcha recorded in 01_BUILD.md
  (parallel jelly-skin agent session on the shared booted sim;
  zsh launch args must be arrays).

## -3. App v5 — the experience pass (2026-07-07)

**Doc set: `docs/app_v5/` (00_DIRECTION · 01_REPORT). Read
00_DIRECTION.md first (§6 = the re-steer). Supersedes v4's LANGUAGE
layer AND becoming's vertical-ledger layout; v4's engines (arc /
weeks / weekly review mechanics / receipts law) stand.**

Part 2 (the re-steer, same day): **becoming is a horizontal insight
story** (JKStoryPage pager: weight figure → food arc + chemistry
row → movement rhythm → this-week + her-weeks timeline → band
(keeping) → from-jeni letter; visuals re-arm per arrival), **Home
carries THE DAY RAIL** (seven tappable day cells, today as a filled
date pill, past days open receipts — the calendar-strip answer),
plan history lives one level in (JourneyTimelineView), calories
stay Home's lead food sentence, and carbs/fat/fiber surfaced from
long-stored fields (vitamins/minerals need an EF change — fenced).
Chart craft: rebuilt protein arc (gradient sweep, tip head, target
notch), under-glow trend stroke, chromeless story figures; the
canvas scrub retired on story pages (it ate the pager's swipes —
frame-audited).

The organizing principle: **one program, spoken plainly, shown
beautifully.** v4's private language retired across every surface
("the plate story" → "today's plates"; "the re-signing" → "your
weekly review"; "the trend fed 3 times" → "weighed in 3 times";
"the bend, named" → "the plateau week"). Trust floors added: the
reading teaches the ritual on day one and may not speak trend
language until 3+ weigh-ins span 5+ days; the trend story speaks
her display unit; the trend line no longer wears an unrelated
insight's caption. Becoming's header is ONE object (ordinal + phase
+ ribbon + intent; midpoint countdown in the eyebrow; leadLine
retired). Week cards mark today's dot and close with the week's
EMA delta in neutral ink. Jeni's transcript groups as dated letters
with no-repeat seeding and always-relevant starter chips. The
breath bloom holds the stage (360pt field, deeper rose). Evening
chips answer a visible question; day receipts speak plain lines and
today "is still being written." Tab arrivals settle with a 4pt
rise. 194/194 tests; SE + Dynamic Type XXL verified; evidence in
`docs/app_v5/evidence/` (gitignored).

## -2. App v4 — the program rebuild (2026-07-06/07)

**Doc set: `docs/app_v4/` (00_THESIS · 01_PROGRAM · 02_JOURNEY ·
03_FEATURES · 04_BUILD_PLAN · 05_REPORT · research/). Read
00_THESIS.md first; 05_REPORT.md carries the evidence map + honest
gaps. Supersedes docs/app_v3 where they disagree (the v3 day model
survives; the journey dimension is new).**

The root fix: the program now exists as an object. `ProgramArc`
(named phases per chapter: losing = finding steady → the early read
→ the build → the bend → the last stretch → the hold; on-medication
= arriving → rolling practice blocks; keeping = the settle → kept),
`WeekIntent` (named weeks, deterministic, zone-aware, pick-aware),
and **THE RE-SIGNING** (`WeeklyReview`): at her week's boundary jeni
reads the week back and proposes ≤1 consented change from a closed
safe set, applied through knobs the engines already read (protein
adjust inside the advisory clamp, sessions bend, weigh softening,
intent picks). Records are device-local JSONL; "plan."/"review."
prefixes ride the sign-out sweep.

**THE JOURNEY**: becoming rebuilt as the plan-over-time surface —
arc ribbon + phase header, one-story trend (EMA direction word;
raw-vs-EMA badge contradiction dead; band always fits the domain),
THIS WEEK card, week-chaptered ledger (standing dots in tense ink,
week stories, signed adaptation stamps, quiet seams — absence never
renders), week pages → read-only day receipts, dotted future shape,
her-plates archive (v1 journal interior deleted). Today gains the
WEEK RIBBON (7 dots + week name → journey; the her-days sheet
family is deleted), THE PLATE STORY (filmstrip + one protein gauge
+ "room for about 600" day answer; steps ring dead), evening
ends on her journal line, and THE TONIGHT PLAN (if-then chips whose
plan the next morning's reading names back).

Interiors: breath rebuilt (JKBreathField generative bloom on a
zero-velocity sinusoidal BreathClock + BreathHaptics continuous
CoreHaptics envelopes + no numerals; BreathCircle deleted); workout
completion = the kept receipt (stars died app-wide; effort-feel
signal kept); the wave dial (craving-occasion before/after). Chat
context carries phase/week/intent/last-re-signing. Anchor rungs
announce named weeks; the re-signing knock (id `resigning_knock`,
4-site protocol) lands at week close. `jenifit://` finally
registered (CFBundleURLTypes). Legacy sweep: −6.4k lines (Becoming
dashboard family, Plan atoms, FoodLogTimelineView).

Bugs killed: unscoped `todayKcalTotal` cross-account seam (snap
beat vs band contradiction); the re-signing auto-offering from the
HIDDEN becoming tree over Today (all tabs stay mounted — offers now
gate on the visible tab); cover-identity blanking; the SE dateline
wrap. Production fences held: zero schema/EF/payment/gating
changes. 195/195 units; 7/7 walker legs (new journey/re-signing leg
+ direct-open QA hooks: `--uitest-open-week N --uitest-open-day D`,
`--uitest-keep-reviews`, `--uitest-becoming-bottom`). Evidence:
`docs/app_v4/evidence/` (gitignored, on disk).

## -1. App v3 — the reading-first rebuild (2026-07-05)

**Doc set: `docs/app_v3/` (thesis · verdicts · design language ·
build plan · verified research · safety report · honest gaps). Read
00_THESIS.md before touching the day model.** The founder's brief:
lowest possible effort, highest possible feeling of being understood;
GLP-1 + post-GLP-1 as first-class audiences.

The core inversion: prescription-first → READING-FIRST. Today opens
with jeni's reading (grown DailyBriefEngine: line + second sentence +
mechanism, deterministic + provenance-only), THE ONE THING (single
engine-chosen ask as the screen's only filled card), THE RHYTHM
(hairline rows — no at-rest circles, no counts), the band, and an
evening receipt that leads after 18:00. Padlocks died; the strip
wears standing dots (DayStanding: kept/partial/quiet — ONE vocabulary
across strip/review/receipts/wins).

Three chapters (`Chapter` in DayModel.swift, derived in CohortStore):
losing / on-medication / keeping. On-medication: protein floor as
adequacy hero, evening "did you eat enough?" net, "how did today
sit?" one-tap (HER pattern reflected back — never an asserted
medication cycle; that claim was refuted in verification research).
Keeping: BandModel (STOP Regain zones on the EMA: steady / drifting
~1.4kg / reset ~2.3kg over settle), reading threads that OPEN actions
(the null-trial law), ritual band whisper, canvas band field,
kept-weeks scoring.

The method became THE REP (RepView + RepEngine): scenario + doors +
warm mechanism lines, reader one tap deeper; MethodResolver killed
the three divergent lesson resolvers (two read zero-writer cohort
keys). PresenceLedger redefined "shown up" (was workouts-only) to
any meaningful action, lifetime count, never resets, self-healing.
BreakState = "on a break" (pauses rhythm + all uninvited pushes;
ProfileHub row). Jeni tab opens with HER FILE (the v5 dossier alive)
+ the full reading; CoachContext gains chapter/band_zone/kept_days/
on_break. Becoming: band field + raw numeral de-heroed.

Production: zero schema/EF/payment/gating changes (see
docs/app_v3/PRODUCTION_SAFETY.md). 152 unit tests green. Remaining:
docs/app_v3/HONEST_GAPS.md (notably: notification orchestrator
phase 7 designed-not-built; rep content beyond the 16 authored;
weekly consent check-in).

## 0. App v2 — the in-app rebuild (2026-07-03, feat/app-v2)

The in-app experience was rebuilt to cash the onboarding v5 promise.
Doc set: `docs/app_v2/` (00-11 + SCIENCE.md). What changed:

- **Gating**: route-level `AppPhase` machine (`PlankApp/App/`) —
  booting / onboarding / wall(.fresh|.expired) / migration / main.
  Exactly one phase mounts; unpaid/expired users never have main
  content in the hierarchy. Expired payers get `ExpiredWelcomeView`
  ("still here. still yours."). Auth transitions hold the last
  stable phase. Table-tested (`AppPhaseTests`, 10 cases).
- **IA**: three tabs — today / jeni / becoming — over the custom
  `JKTabBar` (serif-italic active label + matched-geometry dot).
  Camera FAB retired; snap lives in Today's masthead + beats +
  plate strips + a jeni tool. Settings reachable from BOTH tabs.
- **Today** (`PlankApp/Views/Today/`): the daily ritual — Fraunces
  day pill masthead, jeni's brief line (DailyBriefEngine cascade,
  provenance-only), the day strip, 3-5 engine-composed beats
  (PrescriptionEngineV2: workouts follow sessionsPerWeek, lessons
  follow tier cadence arc-completely, weigh-in is a cohort cadence
  with stale fallback, breath heroes rest days), today-so-far band
  (protein arc hero + steps ring + kcal sentence + plates strip),
  evening close after 18:00. Cross-off completion everywhere.
  PlanView reachable via `--legacy-today` until founder sign-off.
- **Jeni chat** (`PlankApp/Chat/` + `supabase/functions/jeni-chat`):
  SSE-streamed coach over an OpenAI EF (JENI_CHAT_MODEL env, key
  server-side, per-user + budget caps, telemetry ledger). Client
  assembles a provenance-only CoachContext per turn; crisis/ED
  language routes to fixed care responses locally; seven
  client-executed tools with confirm cards for mutations. The
  letter-register UI (no bubbles). Local-first transcript
  (ChatMessageRecord). Deploy: `supabase functions deploy jeni-chat`
  + run `supabase/migrations/20260703_app_v2_chat_and_cohort_columns.sql`.
- **One source of truth for numbers**: `TargetsService` (protein
  1.6 g/kg GLP-1-current / 1.2 default; calorie target recomputes on
  latest weight via the plan's implied rate) — snap result, Becoming,
  Today, chat all read it. `CohortStore` is the ONE reader of cohort
  keys and fixes the dead CBT bridge (CohortFlags read six
  zero-writer keys pre-v2). Session ratings finally persist
  (userId + pendingUpsert added). Dietary settings edits finally
  reach food-vision (`DietaryProfileResolver`).
- **Becoming**: curated under six modules (macro bar cut, moved
  strip + deeds into the depth sheet); journal rows are photo-forward
  catalog cards (protein-only at rest; p·c·f lives in detail).
- **Migration**: `MigrationMomentView` (one-time, provenance
  receipts) for entitled legacy-footprint users; `appV2SeenAt`
  stamps on first main mount.
- **Notifications**: `NotificationDelegate` — taps deep-link through
  AppRouter (`jenifit://` grammar), queued until .main so expired
  users land on the wall. Full orchestrator consolidation is spec'd
  (`docs/app_v2/09_NOTIFICATIONS.md`) but not yet built.
- **QA args**: `--uitest-seed-program`, `--uitest-start-tab <tab>`,
  `--uitest-mock-chat`, `--uitest-chat-demo`,
  `--uitest-force-migration`, `--uitest-today-bottom`,
  `--debug-jenikit` (component gallery).

**v2.1 pass (same day):** Becoming REBUILT as the insight layer
(`Views/Becoming/BecomingView.swift` + `Program/InsightEngine.swift`
— trend-as-coach-story, ranked pattern insights with ask-jeni seeds,
method journey, wins receipts; `docs/app_v2/12_BECOMING_V2.md`).
Day-complete silk sweep (`jkSilk` Metal shader, frame-diff verified).
Workout celebration de-emoji'd (typographic "kept."). Onramp speaks
receipt grammar. Deploy-safety audit GO/GO with pre-deploy fixes
(telemetry FK, budget-sum RPC, 502 leak) — founder checklist at
`docs/app_v2/13_DEPLOY_SAFETY.md`; usage data + feature-by-feature
status + sweep list at `14_V21_NOTES.md`.

Founder actions pending: run the migration SQL then deploy jeni-chat
(exact checklist in `docs/app_v2/13_DEPLOY_SAFETY.md` — verified
safe for the live app in any order vs the release), device pass,
then the legacy sweep (`--legacy-today` / `--legacy-becoming` /
v4.5 escapes; list in `14_V21_NOTES.md`).

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
**v5 ground-up rebuild (2026-07-02)** — `PlankApp/Views/OnboardingV5/`,
typed step state machine (no Int cases), ~46 beats in 5 acts with
GLP-1 cohort branches. Docs: `docs/onboarding_v5/` (INTENT / PANEL /
STRATEGY / FLOW / DATA_CONTRACT / SHIPPED — read SHIPPED.md first).

Interaction language: cross-off strikethrough single-selects with
auto-advance; her75 tick rulers (haptic detents, digit-roll serif pill,
rose delta band, live weeks math); rapid-fire fear statements with
strike-the-fear; act-end receipts that mirror her answers back; snap
demo mid-food-wedge (real Metal `snapSweep` over 3 staged plates, the
flow's single luminance inversion, honest "one of ours" framing);
her-file dossier + signature (consent + disclaimer in one beat) +
hold-to-build close.

Structure: GLP-1 status asked at the top of Act II as a path-fact —
current (phase + appetite rhythm + muscle-math teach), past (stop
window + appetite return + regain-truth teach, maintain-kept surfaced
first), considering (agency teach). Safety gate (SCOFF/pregnancy/BMI/
meds) relocated into "the care part" at the end of the numbers act —
still pre-paywall, no longer at peak anticipation. Name in Act I so the
dossier, loader, projection, and wall are addressed to her.

Reveal (shared with legacy, `skipsPreamble` for v5): receipt-tape
loader (cites LIVE keys only — the v4.5 dead-field narration bug is
fixed), pace picker, projection with causal receipt rows ("because you
X → we Y", rendered only when the engine modifier fired), first week
(cohort-routed rails), fear-resolution beat (replaced the pre-wall
rating ask; rating is post-purchase only), commitment ritual (merged
time anchor writes day1PromiseTimeISO + plankTime; demo pre-leads
"snap your first real meal"), nudge ask (banner payload = her promise
at her time + trial-reminder promise row).

Cohort pace floors unchanged (`ProgramGoalCalculator`): GLP-1 /
perimenopause 0.3%/wk, short-sleep penalty, regain-risk notch; new
`onboarding_glp1_stop_window` / `onboarding_appetite_return` /
`onb_v5_appetite_rhythm` keys feed loader + reveal copy. Data contract
preserved byte-for-byte (`docs/onboarding_v5/DATA_CONTRACT.md`).

Legacy v4.5 (`OnboardingView.swift`) stays reachable via
`--onboarding-v4` during burn-in; sweep scheduled after founder
device sign-off. QA: `OnboardingV5WalkerUITests` walks welcome→paywall
with a screenshot per beat (`TEST_RUNNER_GLP1_COHORT` for branches).

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
v1.2 rebuild (2026-07-01). Three input modes behind one toolbar:
**snap** (camera) / **describe** (text → same estimate pipeline) /
**again** (`RecentMealsSheet` one-tap relog).

Camera capture → vision EF (single OpenAI model via
`FOOD_VISION_MODEL` env; the app-side USDA calibration sweep guards
low-confidence items) → **result stage: 3-slide carousel over the
full-bleed photo** (2026-07-02, founder call — the v1.1.2 swipe
vocabulary restored in the v1.2 panel design; the photo never moves,
the slides carousel over it, white dots ride the top):

- slide 1 "the plate" — two-detent editorial panel: count-up kcal
  hero + protein co-hero, "ate about half" fraction chips,
  always-visible ingredient ledger with inline portion steppers,
  tap-through `IngredientEditorSheet` with coherent macro↔kcal math
  (`PlateEditSession` in `SnapResultMath.swift`, unit-tested),
  inline "fix it with words" + "+ add something" composer
  (`SnapRefine` through the EF text path — live against the
  deployed backend).
- slide 2 "a note from jeni" — the anti-shame note
  (`ResultDetailCopy`) on its own panel slide, native sparkle
  accent.
- slide 3 "share" — the on-photo composer (`SnapShareSlide` font
  rail; preview IS the exported PNG) slides in full-bleed over the
  same steady plate.

Scanning is a Metal pass (`snapSweep`: diagonal warm band + grain,
`SnapShaders.metal` in the SPM package). Result-land plays the
retinted Sparkling lottie burst (`FoodResultExplosion`; rose body +
light-pink rim per locked palette — replaced the heart + star pair).

Per-item nutrition detail persists with every entry (device-local
JSONL, backwards-compatible); journal detail shows the ledger +
"again" relog. Photo-scan capture notes + photo-grounded corrections
activate on the next `supabase functions deploy food-vision` (the EF
folds `text` into image requests as trusted context).

Food journal long-press delete, photo timeline, matched-geometry
meal detail. QuickAdd (describe) has dynamic chip suggestions
(recents + cuisine). See `Packages/PlankFood/`.

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
