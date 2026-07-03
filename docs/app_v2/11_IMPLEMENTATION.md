# 11 — Implementation plan

## Phasing (each phase = compiling commit batch, one build per batch)

**P0 — services + fixes (foundation, no UI)**
CohortStore + CBT bridge fix · TargetsService · TodayStateService ·
PrescriptionEngineV2 · DailyBriefEngine · rating write fix ·
tripwire wiring · dietary resolver · users columns + sync additions ·
ChatMessageRecord/DayReflectionRecord + migrations file.

**P1 — JeniKit**
Kit components + jkBeat port + JKTabBar + chrome. Gallery debug
harness (`--debug-jenikit`) for screenshot iteration.

**P2 — shell + gating**
AppPhaseController (+unit tests) · RootView v2 switch ·
wall(.expired) variant · MainShell + router + deep links ·
entitlementVerifiedAt plumbing · FoodFlags effective fix.

**P3 — Today**
TodayView (masthead/brief/strip/beats/state band/evening close) ·
module chain lines · onramp v2. PlanView retires from the tab (kept
compiling until sweep).

**P4 — Chat**
jeni-chat EF · ChatTransport/Session/ContextAssembler/ToolRouter ·
JeniChatView + transcript + composer + action cards · daily brief
seeding · safety pre-filter · coach_messages sync.

**P5 — migration + first-run**
MigrationMomentView · PostPurchaseFlow v2 beats · coach marks.

**P6 — becoming + journal reskin**
BecomingView curation (5 modules, reuse atoms) · plate catalog
journal · settings mark on becoming · module frame reskins
(pre/post-workout chrome, breath receipt, lesson chrome touchups
only — internals untouched).

**P7 — notifications**
Orchestrator + catalog + delegate + deep-link queue + caps.

**P8 — sweep + verify**
Dead code removal (old tab bar, home cards, legacy session trio,
premium welcome, ledger rows) · doc updates (STATE/CLAUDE) · full
sim matrix (07 QA table) · walker updates · screenshot audit loop ·
performance pass (no hitches on 60fps scroll).

## File plan (new, ~55 files)

DesignSystem/Kit/ (17 per 10_DESIGN) · App/ (AppPhaseController,
AppRouter, MainShell, WallView additions) · Views/Today/ (TodayView,
TodayMasthead, TodayBeatsList, TodayStateBand, EveningClose,
OnrampV2) · Chat/ (JeniChatView, ChatTranscript, ChatComposer,
ChatSession, ChatTransport, CoachContextAssembler, ChatToolRouter,
ChatActionCards, ChatSafety) · Program/ (CohortStore,
TargetsService, TodayStateService, PrescriptionEngineV2,
DailyBriefEngine) · Views/Migration/ (MigrationMomentView) ·
Notifications/ (NotificationOrchestrator, NotificationCatalog,
NotificationDelegate) · Views/Food/ (PlateCatalogView) ·
supabase/functions/jeni-chat/index.ts · migrations SQL ·
unit tests (phase machine, engine, targets, brief).

## Verification loop (P8 but continuous)

- `xcodebuild -project plankAI.xcodeproj -scheme plankAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` once per batch (touch edited files first per the stale-compile gotcha).
- Sim walkthroughs via simctl + screenshots each phase; crop/zoom
  pixel passes on Today/Chat/Becoming.
- Flows: fresh→onboard→wall→purchase(mock `--uitest-pro-access`)→
  first-run→main · relaunch-paid · expired (debugForcePaywall) ·
  migration (seed legacy footprint) · chat streaming against
  deployed EF (or `--debug-chat-mock` transport when offline).
- Unit tests: AppPhase derivation table · prescription day table
  (cohort × archetype × tier) · targets math · brief cascade.

## Risks + mitigations

- **pbxproj churn** → scripts/add_swift_file.rb per batch, pbxproj
  committed last (commit-hygiene memory).
- **EF deploy needs founder credential** → chat ships with
  `ChatTransport` behind a protocol + `MockChatTransport` so the
  full UI is verifiable offline; the EF is deploy-ready
  (`supabase functions deploy jeni-chat`).
- **Sim RC entitlement** → DEBUG walker args (existing pattern).
- **Scope creep in P6** → reskin composes EXISTING atoms; only the
  journal grid is net-new UI.
- **PlanView regression risk** → v1 PlanView stays compiling +
  reachable via `--legacy-today` until founder sign-off, then swept
  (mirrors the onboarding v4→v5 pattern).
