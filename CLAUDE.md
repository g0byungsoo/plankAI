## Project status (2026-08-03)

**APP v9 — THE BODY OS (2026-08-03, feat/app-v2). P0-P4 SHIPPED.**
**P4**: promotion ladder + body axis (preservation-at-risk daily
echo; plateau-as-support reason); leadIsPromoted → dose-dot on the
lead's reason (D1 b; med/gentle unadorned). 474 units.
**P3**: WeeklyBodyReview unifies the landing read (outcome →
floor-gated mechanisms → preservation ladder w/ wycherley chip →
CoachSummary move untouched); HRV back WITH its recovery line (D5
closed); L5 "connect workouts" door; chat body facts. 468 units.
**P2**: becoming BODY PAGE + YOUR RECORD (one-drag compare, anchor-
aligned, numbers never surfaced), BodyChangeRead floors, D2 cover
opt-in, D1 trend whisper in the evening ledger, once-ever intro,
BodyScanStore.didChange; QA --uitest-seed-scans/--uitest-force-body-
intro/--uitest-reset-body-scan; 446 units.
**P1 = BODY VISION**: PlankApp/BodyScan/ guided capture (live pose
coaching, auto-shutter, ink-on-paper silhouettes on-device,
silhouette-first D2, consent once, local-only records, L4 plumbing);
weekly OFFERED invitation (ProgramDayPrescription.bodyScan,
Sunday→anchor weekday, never debt/markable); D3 opt-in backup
(default OFF, off=cloud removed, founder applies
scripts/body_scans_storage.sql) + settings doors. 437/437; proof
legs + walkers green. Founder gates: bucket SQL, device walk (sim
has no camera), D10 copy review. QA: --uitest-open-body-scan ·
--uitest-scan-allow-manual · --uitest-force-scan-day.
The founder's brief: Jeni evolves into a Body Transformation OS —
body progress is the center, explained by food/movement/sleep/
medication; Body Vision (guided on-device scans, silhouette-first,
never a number from a photo) is the signature. **`docs/app_v9/` is
the law**: 00_MISSION laws L1-L7 (three-questions / evolution /
honesty / body-privacy / passive / register / DESIGN 100× in
04_DESIGN — design quality is the bottleneck, ADA bar, remove>add,
unforgettable interaction > new feature); 01_AUDIT W1-W10;
02_PLAN P0-P7; 03_DECISIONS RESOLVED at recommended defaults.
**P0 shipped (05_BUILD)**: BodyStateService aggregate (TodaySnapshot
delegates), passive weight repaired (dead importIfEnabled wired +
observers + background delivery + entitlement; onboarding grant
honored), HealthKit truth pass (5 dead reads dropped; cycle read
finally has a requester via steps/sleep sheets; 4 permission strings
rewritten — D10 drafts await founder voice review), MovementService
probe (auth ships with P3's surface), PassiveWeightProofUITests.
421/421 units; proof + onboarding v7 + core-in-app legs green solo.
Next: P1 Body Vision capture (D2 silhouette-first + D3 backup-off
locked). V6Funnel full-suite flake = documented OV5Store deinit sim
abort, pre-existing, solo-green.

**ONBOARDING v7 — THE CLINICAL GRADE PASS (2026-08-03, feat/app-v2).**
The founder's second brief (not a redesign): persuasive, clinically
credible, conversion-focused, with REAL conditionality.
**`docs/onboarding_v7/00_DIRECTION.md` is the law** (four laws:
persona / consequence / evidence / register; ledger D1-D12; shipped
record). Shipped: `OV5Persona` (her/male/neutral from the live gender
answer — male skips hormonal + pregnancy, male ruler seeds, her-
register lines gate on explicit female, identity photo grid → 
typography cards for non-her); question law (priorWin CUT dead, its
slot = the proteinRule teach w/ wycherley 2012 chip; appetiteReturn/
supports/nsv wired into loader + dataMirror + dossier + wall; day-2
consent finally gates the first-days pushes); evidence law (zero
hearts incl. the safety gate, SCOFF instrument byline morgan 1999
bmj, computed answer count, fda-benchmark·dpp tag, hayashi 2023
food-noise chip); reveal "your next {N} weeks, plotted" + outcome-
echo sub; wall end-state row ("built to be outgrown") + BEYOND THE
SCALE row (structure untouched). `onboarding_version: v7`. Verified:
407/407 units; walker legs green END-TO-END per cohort × persona
(incl. the male "ben" walk, zero MISSING); SE + RM legs; recorded
frame review. Walker infra: TEST_RUNNER_GENDER legs, exact-match
gender taps, StoreKit review-sheet dismissal (iOS 26.2 sim does NOT
suppress it).

**ONBOARDING v6 — THE CONVERSION EVOLUTION (2026-08-02, feat/app-v2).**
The v5 onboarding + keep wall evolved for conversion + clinical
credibility — architecture untouched, register moved warm-specific
(number + unit + basis, named real sources), reveal rebuilt
curve-first with four product-true tiles, first week = the real
Day-1 mock, the wall gained below-fold earned-trust bands (plan
summary / why-it-works / included / the jeni rules) + a DORMANT
real-proof band (founder fills verbatim ASC reviews — never
fabricate), ornaments → dose-dot/seal, scroll-gated chrome scrim.
**`docs/onboarding_v6/00_DIRECTION.md` is the law** (design laws,
founder ledger F1-F8, shipped record). Verified: units green, v5
walker green per cohort, KeepWall 3/3 on an erased sim, SE/XXL/RM
clean. QA doors: `--uitest-skip-payment` · `--debug-paywall-bands` ·
`--debug-first-week`.

**THE JENI RELEASE — 1.2.0 (27), branch feat/app-v2.** JeniFit became
**Jeni** under the OFFICIAL identity (docs/jeni_release/identity/ —
the hand-drawn j mark; lockup = mark + "Jeni" in DM Sans; one-colour
law ink↔ceramic, never rose; ONE canonical `JeniMark`/`JeniWordmark`),
CFBundleDisplayName = Jeni, every
user-visible copy line swept; identifiers deliberately unchanged
(bundle id, jenifit:// scheme, jenifit.app URLs/support email, RC
product ids, jenifit.default). Palette matured pink-first → warm
paper + ink (bgPrimary #FCFAF7, ink #2A1F1E, bgElevated white,
launch == bgPrimary — one continuous surface; accent rose + stickers
unchanged; FoodTheme mirrored; contrast floors improve).
`JKBorderBeam` = a signature design-language element (placement law
in its header: earned/premium surfaces only, never medication, one
region per screen, ≤0.5 peak; placed on the paywall's chosen plan +
program-ready CTA). Craft fixes: paywall tier truncations dead,
yearly renewal line carries its year. **VOICE PASS (founder
re-steer, same release): hearts RETIRED app-wide** (zero in
shipping copy; chat normalizer strips streamed heart emoji); cheer
clauses cut; rose ornaments → dose-dot / ink JeniMark seal;
affirmations = product truths; lowercase + italic punch + verb law
stay; letter signs "— jeni". Voice law = feedback_voice_signals
memory (updated). App icon = official matte-ceramic j tiles (light/dark/tinted),
springboard-verified; site favicon = the same mark.
`docs/jeni_release/00_JENI_RELEASE.md` = the release law + record.
Verified: 396/396 units; onboarding v5 walker + core-in-app +
settings walker legs green; live RC pricing renders; launch
continuity by pixel; beam motion by frame-diff.

The Xcode project name + Bundle ID intentionally stay legacy
(`plankAI` / `com.bk.plankAI`) — renaming forces a re-onboarding for
every TestFlight tester and a re-submission through App Review. A
later release handles the project + Bundle + SKU rename together
(founder-gated); the App Store PRODUCT-PAGE rename to "Jeni" is ASC
metadata at 1.2.0 submission (founder act).

**Authoritative state doc: `/docs/STATE.md`.** Read it first. Anything
in `/docs/archive/` documented a research pass or pivot that fed shipped
work but is preserved for history, not for guidance.

### App v8 (2026-07-28, branch feat/app-v2) — THE CARE PLATFORM
Founder product evolution: consumer → coach → patient → clinic
WITHOUT rebuild. **docs/app_v8/ is current law** (00_MISSION first;
04_DECISIONS = decision/postponed/needs-founder ledger; STATE.md
§-8 = shipped record). Research-first: 4 cited web lanes + 2 code
audits (01_RESEARCH/02_COMPETITORS).

**S5 SHIPPED (2026-07-30) — PILOT-READY JENI CARE.**
`docs/app_v8/11_S5_PILOT_READY.md` is law; 04_DECISIONS S5-11..S5-19;
05_BUILD phase 11; ops set in `docs/app_v8/pilot/`. The brand is
**Jeni Health › Jeni Care (clinician) › Jeni (patient)** — clinician
surfaces rebranded Jeni Care, patient stays "your care team"; internal
ids (bundle, `jenifit.default`, `care_*` RPCs, `clinic/`) stay stable;
name-risk scan found no obvious blocker (counsel gate before paid
marketing / App Store rename). Additive migration
`20260730090000_s5_pilot_ready.sql` — **founder applies to a fresh
PILOT project, never the consumer-prod dev DB** (`scripts/
care_env_provision.md`): explicit `clinical_authority` (owners aren't
auto-clinical, staff never), org suspension, `is_demo`, mode-gated org
creation + single-use provisioning codes, member-role/end-relationship
admin + last-owner guards, `care_environment` identity, structurally-
redacted `ops_events` + anon-bounded `pilot_requests` (both API-
unreadable). Dashboard: Jeni Care rebrand + environment guards (build
refuses dev-ref / missing support mailbox; boot hard-stops on env
mismatch) + clinic administration + password reset + first-run + help/
boundary sheet. New static **Jeni Care website** (`site/`, Vercel,
build Ready, access-gated + noindex): between-visit-horizon hero, the
5-step loop, real+recreated product evidence, trust/boundary, bounded
pilot-request form. Resettable fictional demo tenant
(`scripts/care_demo.py`). Ops: model/runbook/vendors+BAA/retention/
metrics/founder-demo/legal-drafts. 396/396 iOS (unchanged); extended
probe 97/97 (+expiry) + 22/22 pilot-readiness proof against a full
local stack; Playwright E2E; axe WCAG 2.1 AA 0 violations. **Still
internal dev alpha, test data only, NO BAA — never "HIPAA compliant";
no AI in the clinic loop.** Founder gates: pilot project + BAA chain +
counsel legal + insurance + risk analysis + public site + trademark.

**S4 SHIPPED (2026-07-29) — THE FIRST REAL CLINIC LOOP.**
`docs/app_v8/10_S4_CLINIC_LOOP.md` is law; 04_DECISIONS S4-1..S4-10;
05_BUILD phase 10. A clinic actor connects to one consenting patient,
reads her S3 packet, assigns care → it becomes her lived daily plan.
Additive migration `20260729180000_s4_clinic_loop.sql` (orgs/members/
invitations/relationships/consent-scopes+lookback/protocol_assignments/
correction_requests/append-only audit/visit_packets) — **founder must
apply** (applied live on dev this session). Clinician patient-data
access is SECURITY DEFINER RPC-only (audit chokepoint; no direct
clinician policies; F1 name-masking is a server projection; the FR1
client guards became server law). `clinic/` = a static Vite+React
Supabase-direct dashboard (publishable key + RLS, NO service-role,
strict CSP), five screens. Patient side renders care-team assignments
through the EXISTING runtime + the FR2 reconciliation moment (confirm
retires the self plan, history intact) + a read-only care-team regimen
face + correction door (45 CFR 164.526 shape, never mutates) + the
connection/consent sheets (3 scopes + 4-week/today lookback +
not-monitored line) + a "your care team" settings door. Revocation is
prospective + access-only (access ≠ treatment). 396/396 units + a
62-check live security probe + Playwright E2E + a live on-sim 20/20
end-to-end loop. **Internal dev alpha, test data only, NO BAA — never
say "HIPAA compliant"; a real clinic pilot gates on BAA + security
posture + breach process.** QA: `--uitest-care-connect-code` etc.

Earlier v8 shipped: `CareProtocol`
(every clinical constant injectable; .default == shipped behavior)
+ `BrandVoice` split (JeniVoice byte-pinned); `ObservationStore`
(typed chart: feeling/sit/dose/note/tonight + backfill; survives
sign-out) + `RegimenPlanRecord` (shot-day anchor, org seam);
medication first-class (dose day leads via CarePlanEngine, gentle
dose day = the dose alone, hydration invitation in titration
window, RegimenSheet, evening shot-day ask, sit-check + "backed
up" + post-med chapter); the verb law (food asks say **add**,
dose says **mark**, weight says **weigh in**; overnight-fast
nouns, sugar intake). Migration
`20260728_app_v8_care_platform_foundation.sql` NEEDS founder
apply (graceful 404 local-first until). Consumer = the org-null
tenant; nothing clinic-shaped renders. 347/347 tests. QA:
`--uitest-seed-regimen` + `--uitest-open-gap 0` (stale sim gap
composes gentle — by design); QA launches wipe the seeded chart.
Onboarding untouched (Stage A recommendation in 06_ONBOARDING,
founder-gated).

### Mission 3 + founder steers (2026-07-27/28) — CURRENT HOME
Home = THE CHECKLIST (founder live-steer): dateline → restored
JKDayRail (navigable week strip, past days open receipts) →
sticker-badged checklist rows (founder-locked stickerAsset
mapping; check-off via circle/hold, tap enters module) → HER
TOOLS rail → JK METRIC RINGS (calories/protein/steps + resting
heart; word-ledger dead). Clinical layer per
docs/app_v7/04_CLINICAL_CHECKLIST.md: dose-day + sit-check
evening asks (on-medication), VitalsService passive reads.
Becoming = cover art from her plate photos, museum-hung spreads,
page-reactive running head, trailing-edge fore-edge, JKPageTurn.
Chat = two voices (serif letter + rose marginalia, bare-hairline
composer). docs/app_v7/03_EDITORIAL.md is the editorial law;
STATE.md §-7 wins over older v7 text. 326/326 tests; run UI legs
solo (unit-suite chaining drops presses).

### App v7 (2026-07-27, branch feat/app-v2) — THE CARE PLAN
First-principles redesign toward "an AI companion quietly taking
care of her" (founder brief; 11-expert panel + method literature
lane synthesized in `docs/app_v7/00_THESIS.md` — READ IT FIRST,
it is redesign law; 01_BUILD.md = shipped record). Phases 1-2:
`CarePlanEngine` (day composed from state: gentle tone, clinical
lead promotions, ring policy — rings only on moves; receipts
follow the plan; 17 tests), Home inverted (position line replaced
the day rail; the reading leads in full; "noticed for you"
receipts — overnight fast is an observation again, ring deleted;
kcal bar → "room for ~600"), becoming inverted (pager retired;
jeni's read lands first + HER SIGNALS index → NavigationStack
pushes, roman folio), one-thread law, a11y floors as tested law
(cocoaTertiary AA + TokensContrastTests, VoiceOver mark-as-done,
stripped hearts). JeniMethod verdict: hybrid — daily row dead,
trigger-matched atoms next, shelf survives. Phases 3-5 specced in
thesis §11. 309/309 tests.

### App v6 (2026-07-17, branch feat/app-v2) — THE SIGNALS
The passive layer: zero-input weight-loss signals computed from
streams the app already holds. `Signals.swift` engine (KitchenSignal
live overnight-window phases w/ 12-14h warm clamp + 16h care line +
on-medication fuel-frame inversion; SleepSignal forgiveness bands;
MealMoves post-meal receipts; WeekRhythm cadence; Sweetness
time-of-day story w/ floors) + 22 unit tests. Home gains the SIGNALS
band (JKWindowHorizon dawn-shader arc + night row + move receipts +
Window/Night detail sheets); becoming gains sweetness / sleep /
rhythm pages + the upgraded 7-night window band. New Metal: `jkDawn`,
`jkNightSky`. SleepService.nightHistory. Round 2 (same day): THE LANDED
moment (food-log celebration on the band: silk sweep + rose serif
line + haptic swell), CycleSignal/CycleService (her-season
cycle-phase appetite context; no predictions, perimenopausal gated
off), ProteinPacing page; JKMomentMounds generalized; 242 unit
tests. **Read `docs/app_v6/00_RESEARCH.md` first (safety rules are
engine law); 01_BUILD.md = shipped record + QA args.** Fasting
vocabulary never renders; observed-never-prescribed is enforced in
code.

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
the fenced EF). Part 3 — v5.1 founder-feedback build: native
Liquid Glass TabView (custom JKTabBar deleted), first-use teaching
block (Today days 1-2), PlateDetailSheet (tap any plate →
chemistry + in-today shares in words), snap-result day line w/
provenance (`FoodModule.dayContextProvider`), THE GENTLE FIVE
(gentle generator mode: low-impact pool, 2 moves x 2 rounds, 50%
kept bar, GentleWorkoutTests), JeniProse streaming shimmer.
**Read `docs/app_v5/00_DIRECTION.md` first (§6 = re-steer);
01_REPORT.md §8 = part-2 evidence + gaps; 02_NEXT.md = v5.1
shipped record.** Supersedes v4's language layer and becoming's
ledger layout; v4 engines stand.

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
- THE KEEP WALL (no-trial, pay-upfront, 2026-07-07): yearly (badged +
  pre-selected) + quarterly + weekly, billed-today everywhere,
  per-week equivalents subordinate. v6 (2026-08-02) added the
  below-fold earned-trust bands + dormant real-proof slot
  (docs/onboarding_v6). Tier-matched downsell sheets on
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
