# v11 REBIRTH — Implementation Plan (the design pass)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> (inline — chosen deliberately: a design pass accumulates visual judgment
> across screens; fresh subagents would re-learn the eye every task).
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute `docs/app_v11/00_REBIRTH.md` — the editorial kit, the chart
engine, Home from zero, Becoming chart-driven, the docs cleanup — as a DESIGN
PASS, with THE LOOP (§11) run after every surface.

**Architecture:** Promotion, not invention. The onboarding register in
`Tokens.swift` becomes a seven-primitive in-app kit + a motion layer; a single
Canvas chart engine replaces SwiftUI Charts; Home and Becoming are rebuilt as
thin renderers over untouched engines (`CarePlanEngine`, `TargetsService`,
`BodyScanStore`, food/sleep/steps services). Old visual vocabulary is deleted
in the same change that replaces it.

**Tech Stack:** SwiftUI (iOS 26 SDK), Canvas + TimelineView-free self-driven
phases, CoreHaptics via existing `Haptics` enum, XCTest, `simctl` +
`ffmpeg` for THE LOOP. No new dependencies.

## Global Constraints

- **The law:** `docs/app_v11/00_REBIRTH.md` L1–L13. Read it before any task.
- **Design pass mandate:** THE LOOP after every surface; exit = cannot find
  another obvious issue. Per-screen gate: would Apple ship this?
- **Voice law:** lowercase casual; italic punch via `ItalicAccentText` only
  (never `*markers*`); zero hearts; no em-dashes between words; never "AI" in
  user copy; "sugar intake" never "sweetness"; verbs: add / mark / weigh in.
- **Tokens:** `Palette.bgPrimary` is the ONLY background; ink `#2A1F1E`;
  8 locked tokens. No new colors.
- **Anti-shame (L10):** no red bars, no "over budget", room-remaining framing.
- **Provenance (L8):** every number traces to a collected field. Data floors
  render honest empty states, never fake trends.
- **Program duration:** never hardcode 75 — read `plan.totalDays`.
- **Rows:** tap enters module; state indicator render-only; long-press = the
  override (MarkAsDoneSheet pattern). No checkbox-circle grammar.
- **Canvas animation:** self-driven phase advanced in `.task`. NEVER
  `withAnimation`-over-`@State` inside `Canvas` (freezes under pushes).
- **Builds:** ONE `xcodebuild` per commit-batch. Verify edits compiled via
  `touch` + compile-count when incremental builds act stale.
- **Sim:** dedicated `QA-iPhone16` UDID `259952D4-444F-4EFE-864A-F3DD5FBA5D22`.
  Screenshot in the SAME turn as any SwiftUI change.
- **UI legs:** run solo, never chained after the unit suite (parallel-clone
  teardown drops presses).
- **Commits:** per-feature commits; screenshots/Resources never committed;
  pbxproj last within a batch.

### THE LOOP — exact commands

```bash
# record (start before driving the flow, ~20–40s per walk)
xcrun simctl io 259952D4-444F-4EFE-864A-F3DD5FBA5D22 recordVideo \
  --codec h264 /tmp/claude-501/-Users-bko-plankAI/*/scratchpad/walk.mp4 &
REC=$!
# ... drive the flow (launch args / taps via XCUITest leg or by hand) ...
kill -INT $REC && wait $REC

# dump frames at 10fps for neighbour comparison
ffmpeg -i walk.mp4 -vf fps=10 frames/%04d.png

# stills at the three floors
xcrun simctl status_bar <UDID> override --time "9:41"
xcrun simctl io <UDID> screenshot shot-default.png
```

Inspect frames with Read (multiple per message), compare neighbours around
every transition. Hunt list + AI-tells per §11 of the law. Fix. Re-record.

---

## Task 0: Docs cleanup + CLAUDE.md collapse

The confusion-kill. Do it first so every later context load is clean.

**Files:**
- Delete: `docs/app_v2/ app_v3/ app_v4/ app_v5/ app_v6/ app_v7/ app_v10/`
- Delete: `docs/archive/` (entire), `docs/onboarding_v5/`, `docs/onboarding_v6/`
- Delete: `docs/retention_v1_1_2/`, `docs/snap_food_fix/`
- Delete from `docs/app_v9/`: everything EXCEPT `00_MISSION.md`, `04_DESIGN.md`
- Delete: `docs/superpowers/specs/*`, `docs/superpowers/plans/*` (shipped)
- Delete loose one-offs: `exercise_balance_audit.md`,
  `feature_gap_synthesis_2026_06_16.md`,
  `jenifit_positioning_panel_2026_06_15.md`,
  `jenifit_v2_strategy_2026_06_13.md`, `medical_grade_*.md` (3),
  `positioning_research_r2_final_2026_06_16.md`
- Inspect then decide: `odr_migration_plan.md` (delete if stale)
- Keep: `app_v8/ app_v11/ jeni_release/ onboarding_v7/ STATE.md THEME.md
  her75_typeface_spec* itgirl_illustration* glp1_strategy* notification_*
  workout_session_rules.md content_engine_plan.md privacy/terms/ASO files`
- Modify: `CLAUDE.md` — the project-status cascade (9 eras) collapses to:
  v11 current-era block (law pointer + design-pass mandate, ~10 lines) + a
  SHIPPED HISTORY table (one line per era: name, date, pointer to docs or
  git). The live-system sections (Auth, Payment, Onboarding, Program,
  JeniMethod, Snap Food, Breathwork, Steps, Launch, Notifications, GLP-1,
  Design system, Compliance, Open items, Skill routing) SURVIVE — they
  document the running system, not history. The Becoming section line
  updates to point at v11.
- Modify: `docs/STATE.md` — prepend the v11 era header pointing at
  `app_v11/00_REBIRTH.md`; mark v10 sections historical.

**Steps:**
- [ ] `git rm -r` the deletion list above (recoverable from git forever)
- [ ] Read `odr_migration_plan.md`; delete if it describes shipped/abandoned work
- [ ] Rewrite `CLAUDE.md` status block per above (Read full file first)
- [ ] Prepend v11 block to `docs/STATE.md`
- [ ] Commit: `docs(v11): the great docs cleanup — 9 eras collapse to one law`

---

## Task 1: The kit (F) + the motion layer

**Files:**
- Create: `PlankApp/DesignSystem/Kit/JeniKit.swift` (page, section header,
  headline, row, primary button, sheet modifier, card)
- Create: `PlankApp/DesignSystem/Kit/JeniMotion.swift` (motion tokens,
  `.jeniArrive`, counting numeral, haptic grammar)
- Modify: `PlankApp/DesignSystem/Tokens.swift` — add to `Space`:
  `gutter 24 / blockGap 20 / sectionGap 44 / heroGap 56`
- Modify: `PlankApp/App/DebugPreviewRoutes.swift` — add
  `--uitest-open-kit-gallery` rendering every primitive + a motion demo
- Add files to pbxproj (follow existing DA17-style id pattern — see memory:
  pbxproj ids are hand-rolled hex, copy neighbouring entries' shape)

**Interfaces (produced — later tasks consume exactly these):**

```swift
// JeniMotion.swift
enum JeniMotion {
    static let arrive  = Animation.timingCurve(0.22, 0.9, 0.32, 1.0, duration: 0.45)
    static let draw    = Animation.timingCurve(0.30, 0.8, 0.30, 1.0, duration: 0.90)
    static let settle  = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let stagger: Double = 0.07   // seconds per index
    static let rise: CGFloat = 6        // arrival offset
}

extension View {
    /// The one arrival choreography. A screen owns ONE `arrived` flag,
    /// flips it in .task; children join the sequence by index.
    func jeniArrive(_ arrived: Bool, index: Int) -> some View
}

/// Serif numeral that counts to its value on arrival (L12).
struct JeniCountingNumeral: View {
    init(value: Double, unit: String? = nil, font: Font = Typo.numeralHero,
         arrived: Bool)
}

enum JeniHaptic {
    static func tick()  // detents, staggered bar landings → Haptics.tick()
    static func land()  // completion → Haptics.soft()
    static func swell() // hero moment, ≤1 per flow → Haptics.medium()
}
```

```swift
// JeniKit.swift
struct JeniPage<Content: View>: View {
    /// Paper shell: bgPrimary, 24pt gutters, serif page title + optional
    /// date line, generous top air. Owns the screen's `arrived` flag and
    /// passes it down via environment `\.jeniArrived`.
    init(title: String? = nil, subtitle: String? = nil,
         @ViewBuilder content: () -> Content)
}

struct JeniSectionHeader: View {          // THE only separator (L2)
    init(_ label: String)                 // 11pt DMSans-SemiBold, upper,
}                                         // tracking 1.6, cocoaTertiary

struct JeniHeadline: View {
    enum Register { case page /*34*/, hero /*38*/, band /*26*/ }
    init(_ base: String, italic: [String] = [], register: Register = .band)
}                                         // wraps ItalicAccentText

struct JeniRow: View {
    enum Trailing { case none, done, count(String), chevron }
    /// 60pt min, borderless, dividerless, iconless. Tap enters; trailing
    /// is render-only; optional long-press = the override.
    init(_ title: String, detail: String? = nil, trailing: Trailing = .none,
         action: @escaping () -> Void, onLongPress: (() -> Void)? = nil)
}

struct JeniPrimaryButton: View {          // the ONE ink pill (L4)
    init(_ title: String, action: @escaping () -> Void)
}

extension View {                          // sheet grammar
    func jeniSheet<C: View>(isPresented: Binding<Bool>,
                            @ViewBuilder content: @escaping () -> C) -> some View
}                                         // paper, 28pt radius, grabber,
                                          // detents [.medium,.large] default

struct JeniCard<Content: View>: View {    // the ONLY card (L5)
    init(@ViewBuilder content: () -> Content)
}                                         // white, r20, no stroke/shadow, p20
```

**Steps:**
- [ ] Write `JeniMotion.swift` + `JeniKit.swift` per the contracts above
- [ ] Add the `Space` additions to Tokens.swift
- [ ] Add the gallery route to DebugPreviewRoutes (all primitives, a row list,
      a card, the counting numeral firing on appear, arrive-stagger demo)
- [ ] pbxproj entries; ONE build; install; launch with
      `--uitest-open-kit-gallery`; screenshot default + XXXL
- [ ] LOOP mini-pass on the gallery (spacing rhythm, optical alignment,
      arrival choreography timing — record, dump frames, inspect the stagger)
- [ ] Commit: `feat(v11): the editorial kit + the motion layer`

---

## Task 2: JeniChart — the engine (C)

**Files:**
- Create: `PlankApp/DesignSystem/Kit/JeniChartModel.swift` (pure, tested)
- Create: `PlankApp/DesignSystem/Kit/JeniChart.swift` (Canvas renderer)
- Test:   `plankAITests/JeniChartModelTests.swift`
- Modify: DebugPreviewRoutes gallery — add all four forms with live demo data

**Interfaces (produced):**

```swift
struct JeniChartModel: Equatable {
    enum Form: Equatable { case line, band, bars, spark }
    struct Series: Equatable {
        enum Role { case ink, context }   // ink 1.4pt, context hairline 1.0pt
        let values: [Double?]             // nil = gap (honesty — no invented
        let role: Role                    // interpolation across gaps, L8)
    }
    init(form: Form, series: [Series], yPaddingFraction: Double = 0.12)

    func points(seriesIndex: Int, in size: CGSize) -> [[CGPoint]] // segments split on nil
    func barRects(in size: CGSize, gap: CGFloat) -> [CGRect?]     // nil-safe
    func detent(forX x: CGFloat, width: CGFloat) -> Int           // clamped index
    func revealCount(phase: Double, total: Int) -> Int            // staged bars
    var isEmpty: Bool
}

struct JeniChart: View {
    /// Draw-on self-drives from a phase advanced in .task (LAW).
    /// .bars: bars land staggered, JeniHaptic.tick() per landing.
    /// Scrub (line/bars, opt-in): drag → detent + tick + value label.
    init(model: JeniChartModel, height: CGFloat,
         endLabels: (String, String)? = nil, scrubbable: Bool = false)
}
```

**Steps (TDD — this is the pure core):**
- [ ] Write `JeniChartModelTests`: empty model flags `isEmpty`; flat series
      centers vertically (y padding); nil gaps split `points` into segments
      (never bridged); `detent` clamps at both edges; `revealCount` is
      monotonic in phase and hits `total` at 1.0; single-value series renders
      one point without NaN
- [ ] Run: `xcodebuild test -scheme plankAI -only-testing:plankAITests/JeniChartModelTests` → FAIL (type missing)
- [ ] Implement `JeniChartModel` → tests PASS
- [ ] Implement `JeniChart` renderer (Canvas; phase in `.task`; stagger via
      `revealCount` + `onChange` tick; scrub gesture)
- [ ] Gallery: four forms; build; screenshot; LOOP on the draw-on (dump
      frames of the bars landing — verify one-at-a-time, no pop, tick sync)
- [ ] Commit: `feat(v11): JeniChart — one hand-drawn engine, four forms`

---

## Task 3: Home from zero (H)

**Files:**
- Create: `PlankApp/Views/Home/HomeView.swift` (owner: composition + arrival)
- Create: `PlankApp/Views/Home/HomeCalendarStrip.swift`
- Create: `PlankApp/Views/Home/HomeNutritionSummary.swift`
- Create: `PlankApp/Views/Home/HomeSections.swift` (TODAY checklist + TOOLS +
  below-fold evening/receipts/reconciliation, re-dressed)
- Modify: `PlankApp/App/MainShell.swift:204` — `TodayHost` renders `HomeView()`
- Delete (same change): `PlankApp/Views/Today/TodayView.swift` after port;
  `JKDayRail`, `JKMasthead`, `JKArcRibbon`, `BeatDisc`, sticker badges,
  `StepsBentoTile`, `BreathworkBentoTile`, `ScrapbookCard` — grep each for
  remaining consumers first; delete orphans in the SAME commit (dead-code law)

**Interfaces:**
- Consumes: `JeniPage/Row/SectionHeader/CountingNumeral/JeniChart(.bars)`,
  `CarePlanEngine`'s composed day (beats → checklist rows), `TargetsService`
  (calorie/protein targets), `FoodModule.dayContextProvider` (day totals),
  existing module routing via `TodayModuleHost` (UNTOUCHED), existing evening
  ask + FR2 reconciliation state machines (ported verbatim, re-skinned)
- Produces: nothing downstream — Home is a leaf

**Port inventory (from TodayView.swift, keep-logic/kill-layout):**
routing + refresh (`:1291`), QA launch-arg doors (grep `uitest-` in file —
every door keeps working), evening block (`:1221`), reconciliation (`:1266`),
checklist model + MarkAsDoneSheet override (`:1457`), day-6 upgrade moment
(`:254`). The masthead/whisper/letter/act-line PRESENTATION dies; any letter
content that still matters surfaces as one quiet line below TOOLS.

**Steps:**
- [ ] Read TodayView fully; write the port map (what moves where — record it
      in the commit message body)
- [ ] Build HomeView per the law §6 layout (strip → numerals → macro bars →
      TODAY → TOOLS → below-fold), one arrival choreography
- [ ] Swap `TodayHost`; grep-verify + delete the kill list; ONE build
- [ ] Unit suite green; core-in-app UI leg SOLO green
- [ ] THE LOOP: record arrive / scroll / check-off / tool-tap / past-day walk
      at default + SE + XXXL; dump frames; hunt; fix; re-record until clean
- [ ] Gate: would Apple ship this? If probably not — redesign before commit
- [ ] Commit: `feat(v11): HOME — the operational page, from zero`

---

## Task 4: Becoming chart-driven (B)

**Files:**
- Create: `PlankApp/Views/Becoming/BecomingSummaryView.swift` (hero + grid)
- Create: `PlankApp/Views/Becoming/BecomingTiles.swift` (tile view + model)
- Create: `PlankApp/Views/Becoming/BecomingDetailPage.swift` (one template:
  big chart + the read in words + the mechanism line)
- Create: `PlankApp/Views/Becoming/BodyProgressSection.swift` (two plates +
  the relocated compare scrub + the scan door)
- Create: `PlankApp/Program/NutrientWeekSeries.swift` (pure aggregation)
- Test:   `plankAITests/NutrientWeekSeriesTests.swift`
- Modify: `MainShell.swift` `BecomingHost` → `BecomingSummaryView()`
- Delete (after port, same commit): `BecomingView.swift` (2,522),
  `BecomingStoryPages.swift`, `JourneyAtoms/Model/PlatesPage/WeekPage`,
  `WeightTrendChart.swift` (the last `import Charts` — engine replaced),
  page-turn wiring (grep `JKPageTurn`)
- Rehome, do NOT delete: `VisitPacketView`, `ReSigningView`,
  `WeeklyReceiptCard` — find their entry doors during port; they get
  JeniRow doors on the summary page (care features stay reachable)

**Interfaces:**

```swift
// NutrientWeekSeries.swift — pure, tested
struct NutrientWeekSeries: Equatable {
    struct Day: Equatable { let date: Date; let value: Double? } // nil = not logged
    let days: [Day]            // exactly 7, oldest first
    var loggedCount: Int
    var meetsFloor: Bool       // ≥3 logged days — below floor the tile
}                              // shows "logging · N of 3 days" (L8)

enum NutrientWeekAggregator {
    /// Sums per-day from food_logs payload entries; missing day = nil.
    static func week(for nutrient: Nutrient, entries: [FoodLogEntry],
                     endingOn: Date, calendar: Calendar) -> NutrientWeekSeries
    enum Nutrient { case protein, fiber, sugar, sodium, saturatedFat }
}
```

- Tile set (8): weight (weigh-in series + EMA context line — port the math
  from WeightTrendChart before deleting it), protein, fiber, sugar, sodium,
  sleep (`SleepService.nightHistory`), steps (HealthKit), movement (sessions).
- Hero: BODY card — `WeeklyBodyReview`/`BodyChangeRead` words +
  4-week weight `.line` drawing on appear. Data floors from BodyChangeRead
  respected — below floor the hero speaks the day-count truth, no fake trend.
- Sodium mechanism line (voice-law compliant, factual): "sodium holds water.
  the scale follows for a day or two." — the scale-noise answer.
- Tile → page: matched-geometry expansion (L12).
- Deep links: grep `jenifit://` for becoming routes; keep them resolving.

**Steps:**
- [ ] TDD `NutrientWeekSeriesTests`: 7-day shape; missing days nil (never 0);
      floor logic at 2/3 logged; sodium mg summed not averaged; timezone edge
      (entry at 23:40 lands on its local day)
- [ ] Implement aggregator → green
- [ ] Build summary + tiles + detail template + body progress; port compare
      scrub physics; wire doors (visit packet / re-signing / receipts)
- [ ] Swap `BecomingHost`; grep-kill list; ONE build; suite green; becoming
      UI leg solo green
- [ ] THE LOOP: arrive / tile stagger / drill-in expansion / scrub / body
      compare walks at three floors; frames; hunt; fix; repeat
- [ ] Gate: would this hold in a keynote? Fix until yes-or-honest
- [ ] Commit: `feat(v11): BECOMING — the chart-driven summary`

---

## Task 5: The full-pass LOOP + evidence + close-out

- [ ] End-to-end walk: onboarding exit → Home → Becoming → drill-ins → back.
      The L13 test: does leaving onboarding feel like the same product?
      Record it; inspect the seam frames specifically
- [ ] Full hunt-list sweep on every new surface; fix; re-record until the
      exit condition holds honestly
- [ ] Full unit suite; all UI proof legs solo
- [ ] Write `docs/app_v11/02_EVIDENCE.md`: what was recorded, what the frames
      showed, what was fixed, what was DELETED (files + line counts), stills
      at three floors per surface
- [ ] Update `docs/STATE.md` + CLAUDE.md current-era block to "shipped";
      update project memory
- [ ] Commit: `docs(v11): the evidence — THE LOOP's record`

---

## Self-review (done at write time)

- **Spec coverage:** §4 kit→T1 · §5 charts→T2 · §6 home→T3 · §7 becoming→T4 ·
  §8 docs→T0 · §11 loop→every task + T5 · §9 carried constraints→Global.
  Gap check: L13 continuity verified in T5's seam walk. ✓
- **Placeholders:** the visual-iteration steps intentionally specify gates,
  not final pixel values — that IS the method of a design pass; every code
  contract, path, and command is concrete. ✓
- **Type consistency:** `JeniChartModel.Form`, `JeniRow.Trailing`,
  `NutrientWeekSeries.Day` names match across tasks. ✓
