# E1 THE SPINE — surface + service map (recon, 2026-08-10)

Read-only audit for: weekly-read surface (Becoming crown + Home knock),
walk/movement beats, adaptive steps goal, ReSigningView absorption.
All paths absolute from repo root `/Users/bko/plankAI`.

## 1. The beat system

**Vocabulary** — `PlankApp/Program/ProgramDayPrescription.swift:18`
```swift
public enum ProgramDayPrescription: Codable, Sendable, Equatable {
    case lesson(lessonId: String?)
    case snapMeal
    case workout(tier: IntensityTier, minutes: Int, bodyFocus: String?)
    case plank(targetSeconds: Int)
    case breath(minutes: Int, style: BreathStyle)
    case steps(goal: Int)
    case water(ml: Int)
    case weighIn
    case measurements
    case medication
    case bodyScan
}
```
`itemKey` (:87) is the persistence key and **MUST match the SQL CHECK
constraint** on `program_day_checks.item_key` (`lesson snap_meal move
plank breath steps water weigh_in measurements medication body_scan`).
A new beat case ⇒ a migration for the CHECK. `isProgressRow` (:181) =
steps+water; `isAutoCompleting` (:257).

**Scheduling** — `PlankApp/Program/PrescriptionEngineV2.swift:117`
appends `.steps(goal: profile.stepsDailyGoal)` on EVERY day.
`IntensityProfile.stepsDailyGoal` (`PlankApp/Program/IntensityProfile.swift:47`)
= 6000 soft (:92) / 7500 medium (:101) / 9000 hard (:110).

**Composition** — `PlankApp/Program/CarePlanEngine.swift:26`. Pure
`compose(Input) -> Plan`. `Input` (:33) carries dose/scan/plateau/
preservation flags. Output (:126):
```swift
struct Move { let beat: ProgramDayPrescription; var because: String?; var becauseItalic: [String] }
struct Plan { let tone: Tone; let lead: Move?; var leadIsPromoted: Bool
              let supporting: [Move]; let offered: [Move]; let closing: [CareAct] }
```
Law (:19): **steps are observations, never moves** — the composer
NEVER emits a `.steps` Move; steps live in tools + auto-complete only.
Supporting = demoted dose-day keystone + weighIn, capped at
`careProtocol.composition.maxSupportingMoves` (:267); the v24 daily
dose inserts at index 0 **outside the cap** (:273-275). Offered =
titration water → scan-day bodyScan → workout → breath → lesson,
capped `maxOfferedMoves` (:316). Gentle tone (:337): tender feeling /
short night / ≥ gentleReturnDays away ⇒ ONE move, no offers.
`closing` acts (:115): reflect / prepare / recover / celebrate.

**Routing** — `PlankApp/Views/Today/TodayModules.swift:133`
`TodayModuleState.open(beat:snapshot:)`:
lesson→cover .lesson · snapMeal→cover .captureFlow · workout→cover
.preRoutine (generated) · **steps→sheet .stepsDetail** · breath→cover
.breathSession · weighIn→sheet .logWeight · plank/water/measurements→
sheet .markAsDone · medication→sheet .doseSheet(slotDayKey:) ·
bodyScan→cover .bodyScan. Cover enum :18, Sheet enum :41. Host
modifier `.todayModuleHost` wired at HomeView:325-330.

**Render** — HomeView `daySection` :556-597 (header "today"/"still
today" + `doneCount of totalCount`), `leadAsk` :618 (emphasized,
dose-dot when `leadIsPromoted`), `taskRow` :633-656 → `JeniTaskRow`,
`planRows` :728-746 (ringed = lead? + supporting, then offered).
`JeniTaskRow` — `PlankApp/DesignSystem/Kit/JeniGlance.swift:762`:
```swift
struct JeniTaskRow: View {
    enum Chip { case symbol(String); case doodle(String); case photo(UIImage) }
    let title: String; var note: String?; var chip: Chip
    var offered: Bool; var isDone: Bool; var emphasized: Bool
    var clinical: Bool; var showsDot: Bool
    let onOpen: () -> Void; var onQuickMark: (() -> Void)?; var onLongPress: (() -> Void)?
}
```
**Offered ghost style** (:891-894): bare paper (no bgElevated fill,
no shadow, no check), chip seat = dashed RoundedRectangle
`strokeBorder(Palette.textPrimary.opacity(0.14), StrokeStyle(lineWidth: 1.2,
dash: [3, 3]))`, title at `.opacity(0.72)`, glyph ink `.opacity(0.45)`.
Done rows compress to 44pt receipts (chip 40→24, note fades).
Chips: `beatChip` HomeView:693 (last plate photo for snapMeal, else
doodle :706-719 — `doodle-footprints` is steps', `doodle-shoe`
workout's; medication = bare SF, clinical register :722).

**Auto-complete (steps)** — HomeView:417-419
`.onChange(of: steps.todayCount) { _, count in autoCompleteStepsIfCrossed(count) }`
→ :1418-1434: finds `.steps(goal)` in `snapshot.day.beats`, requires
`count >= goal` && `checkStates["steps"] == "empty"`, then
`ProgramService.shared.markChecklistItem(prescription: .steps(goal:),
state: .autoCompleted, ...)` + refresh. Render-side, `beatState`
:1269-1277 derives steps done/progress LIVE from
`steps.todayCount / goal` (never from the check record) into
`JKBeatState(isDone:isAuto:progress:)` (`Kit/JKBeatRow.swift:16`).

**Persistence** — `TodayModuleState.mark` (TodayModules:316-344):
medication → `MedicationLog.resolve` chokepoint; everything else →
`ProgramService.shared.markChecklistItem` (ProgramDayCheckRecord:
userId+planId+programDay+itemKey+state) + `AppSync.shared.
upsertProgramDayCheck`. `markAuto` (:260) adds one-shot
`chainSuggestion`s. Day completion = `TodaySnapshot.completedBeatCount`
(TodayStateService:89-94) counted over `carePlan.actionableBeats` only.
Silk sweep on day-seal: HomeView:1387-1394 → `.jkSilkSweep(trigger:)`
(`Kit/JKSilkSweep.swift:11`, bump an Int to play).

## 2. StepsService

`PlankApp/Health/StepsService.swift` — `@MainActor @Observable final
class`, singleton `.shared`.
- **Goal storage**: `static let dailyGoal: Int = 7_500` (:57) — a
  hard constant, NOT user state. The per-day scheduled goal comes from
  `IntensityProfile.stepsDailyGoal` via the `.steps(goal:)` beat; and
  `TargetsService.stepsGoal(plan:)` (`Program/TargetsService.swift:186-192`,
  falls back 7,500) feeds `Targets.steps` (:37). Three sources today:
  StepsService.dailyGoal (tiles fallback), profile beat goal
  (checklist + move instrument HomeView:876-881), targets.steps
  (brief's yesterdayStepsHitGoal TodayStateService:293-297). An
  adaptive goal must converge these.
- API: `authStatus` (unavailable/notDetermined/authorized/denied :59),
  `todayCount` :68, `weeklyCounts` [7, oldest→newest] :71,
  `lastSyncedAt`, `weekTotal` :86, `todayProgress` :100,
  `seedForQA(weekly:today:)` :91 (DEBUG), `bootstrap()` :111 (silent
  probe at launch, PlankAIApp:2167), `requestAccess()` :147 (rides
  VitalsService.readTypes + CycleService.readTypes in ONE sheet
  :159-164; zero-data post-ask ⇒ `.denied` — v1.0.7 recovery law),
  `openAppleHealthURL` :208, `refresh()` :217
  (HKStatisticsCollectionQuery, 7 daily buckets), `hourlyBreakdown()`
  :268 (24 buckets), `startObserving()` :313 (HKObserverQuery +
  `enableBackgroundDelivery(.hourly)`).
- **No notification writes** — "notif" interplay is indirect: brief
  reads yesterday's goal-hit; gap-steps average feeds the letter
  (TodayStateService:228-233).
- **TodayStepsSheet** — `PlankApp/Views/Today/TodayStepsSheet.swift:12`
  `TodayStepsSheet(goal:)`: JKSheetChrome → authorized: `JKStepsRing`
  (128pt) + week consistency dots (filled ≥goal · ring ≥goal/2 · dash)
  + authored `frameLine` :117-136 ("benefits start near 4,000 steps");
  notDetermined: JKEmptyState connect CTA; denied: open-health door.
- **Becoming steps tile** — `Views/Becoming/BecomingTiles.swift:828-859`:
  reads `weeklyCounts`, needs ≥3 active days, value "avg a day", bars
  chart, mechanism "steps are the quiet half of the deficit". NOTE: it
  never compares against a goal.
- **Home move tool instrument** — HomeView:875-887: `JeniRing(fraction:
  todayCount / beatGoal, size: 38)` where beatGoal = today's
  `.steps(goal:)` associated value, fallback 7,500.

## 3. HealthKit workouts

**Only `PlankApp/Health/MovementService.swift` touches HKWorkout**
(grep-proven; no other HKWorkout/workoutType() references).
`@MainActor @Observable`, singleton, dormant-by-design (silent probe;
`requestAccess()` :78 is called only from a rendered surface's connect
door). Reads (:95-142): workouts trailing 7d → `strengthSessionsLast7`
(strength = traditional/functionalStrengthTraining only, pure
`strengthCount` :52); `activeEnergyTodayKcal`; `distanceTodayKm`
(nil < 0.1). `readTypes` :37. `everRequested` flag :72
(`movement.hkRequested` UserDefaults). 15-min refresh throttle :97.
Consumers: TodayStateService:401-402 (preservation input),
BecomingSummaryView:1145-1146 (weekly body review input),
BecomingTiles `movementTile()` :861, bootstrap PlankAIApp:2181.
**Nothing reads walking workouts today** — distanceWalkingRunning is
already granted+read, unconsumed by any beat.

## 4. ReSigningView — the consent pattern

`PlankApp/Views/Becoming/ReSigningView.swift:12`.
`ReSigningView(due: JourneyModel.DueReview, userId:, onSigned:
(String) -> Void, onClose:)` — full-screen cover, cream JKScreenChrome.
- Anatomy: dateline "your weekly review · week N" + quiet ✕ (:32-51)
  → `LineCascadeText` week read-back (:54-59, weekName + story) →
  `JKStandingDots` receipt (:63-74; kept/partial/quiet/paused/future
  dot grammar, rehomed here :300) → `proposalBlock` (:108) →
  doors (:196).
- Consent doors: "keep it" (double-thunk haptic :227-231) →
  `sign("kept")`; "not this week" → `sign("declined")` (stamp "kept
  as is", quiet exit); `.intentPick` renders option cards where **the
  options ARE the consent** (:131-141, tap → `sign("adjusted")`) with
  "i'll pick later" as decline.
- `sign(decision:)` (:258-293) writes, in order:
  1. `WeeklyReview.apply(proposal, forWeek:, chosenIntentKey:)`
     (`Program/WeeklyReview.swift:280-311`) — **UserDefaults knobs**:
     `plan.proteinAdjustG` (clamped ±10), `plan.sessionsAdjust`
     (−1…+1), `plan.weighSoftened` (Bool), `plan.intentPick.weekN`.
     Read downstream by TargetsService / PrescriptionEngineV2 / the
     intent resolver. **This is the pace-change mechanic**: adjustment
     knobs the engines already read, never a plan rewrite.
  2. `WeeklyReview.record(ReviewRecord(...))` (:269) — device-local
     JSONL at ApplicationSupport/WeeklyReviews/reviews.jsonl
     (:346-383); `ReviewRecord` :132 (id/userId/weekIndex/decidedAtISO/
     proposalKey/decision/stampLine/reasonLine/weekName).
  3. `NotificationOrchestrator.cancelReSigningKnock()` (:281).
  4. `Analytics.track(.weeklyReviewSigned, ["week","proposal",
     "decision"])` (:282; enum `Analytics/AnalyticsManager.swift:331`
     = `weekly_review_signed`).
  5. `signedStamp` morph → onSigned(stamp); declines auto-close.
- Due logic (pure): `WeeklyReview.dueWeekIndex` :165 — closing evening
  (day-in-week 7 from 17:00) through first 3 days of next week; never
  on break, never signed twice, ≥3 elapsed days. Proposals: closed set
  `ReviewProposal` :83 (holdSteady/proteinEase/proteinFirm/movesEase/
  weighSoften/intentPick) via `propose` :213 with provenance floors.
- Entry — `Views/Becoming/BecomingSummaryView.swift`: state :64-66,
  cover `.fullScreenCover(item: $presentedReview)` :327-334 (item-
  identity survives mid-present reload — walker-caught), care-section
  row "the week's receipt is ready" :1043-1048, auto-present once per
  due week only while becoming tab visible :1082-1094 (0.7s delay).
  Assembly: `JourneyModel.load` (`Views/Becoming/JourneyModel.swift:63`)
  → `DueReview` :42 (weekIndex/slice/proposal/weekName/story).
- Knock — `PlankApp/Notifications/NotificationOrchestrator.swift:114`
  `reSigningKnockId = "resigning_knock"`; scheduled from
  `refreshDailyAnchor` :103 at 19:00 on the week's closing day
  (:116-148, deeplink `jenifit://becoming`); 4-site id protocol:
  scheduler · BreakState sweep · sign-time cancel :151 · delegate
  deeplink map.

## 5. Becoming top region

`PlankApp/Views/Becoming/BecomingSummaryView.swift` body order:
- masthead "becoming" + date, :126-138 (arrive index 0)
- `heroCard` (BODY panel), :140-142 (index 1) — def :709-725; face
  :759+ (JeniSurface: BODY eyebrow → 34pt weight numeral →
  weekly-read caption → 56pt JeniChart → "read the whole week" door
  :822 which `expand`s `bodyTile` :731 through the detented sheet).
- careActive ⇒ `careSection` leads, :146-149 (index 2)
- insight carousel, :151-165 (index 2): `JeniSurface(radius:
  Radius.card, padding: 14) { JeniInsightPager(insights:, height: 132,
  tourAutoAdvance:) }`
- scope bar + tile grid, :167-178 (index 3, id "becoming.grid"):
  `JeniScopeBar(scope: $scope)` then `tileGrid`
- `bodyProgress`, :180-181 (index 4)
- !careActive ⇒ `careSection`, :183-186 (index 5)

A new crown section composes as another `.jeniArrive(arrived, index:)`
child in this VStack; indices below shift by one. State refresh in
`refresh()` :1058-1094; tiles via `BecomingTileBuilder.build`
(`BecomingTiles.swift:84`), insights via `BecomingInsightBuilder.build`
:899. `JeniInsight` (`Kit/JeniGlance.swift:560`): eyebrow · sentence ·
italic · `Figure` = weekDots([JeniWeekDots.Day]) / spark([Double?]) /
bars([Double?]) / none. `JeniInsightPager` :677: TabView page-style,
fixed height ×Dynamic-Type scale, tick per page, `JeniPageDots`.

## 6. Home knock spot

Header — HomeView:79-100: one line greeting (:505-524) + Spacer +
`dayChip` + `settingsGear`; AX sizes stack. `dayChip` :455-480 —
capsule "day N", tap = jeniNote cover, hold = profileHub via
`JKTapWithLongPress`; a11y id "jeni.line". `settingsGear` :482-494.

**One-time arrival covers (the pattern to reuse):**
- BodyVisionIntro — cover :343-355; gate `maybePresentBodyIntro`
  :1006-1024: `@AppStorage("bodyScan.introSeenAt")` stamped BEFORE
  present, requires enrolled + programDay ≥ 2 + `--uitest-inapp-qa`
  opt-out, 0.6s delay.
- PostPurchase — `PlankApp/App/MainShell.swift:164-176` cover; flag
  `postPurchasePendingKey = "postPurchase.firstRunPending"` (:21)
  consumed at :238-244 (read → clear → present in a no-animation
  transaction).
- `maybeOfferUpgradeMoment` :973-1004 — the once-per-install offer
  precedent: `@AppStorage("upgradeMoment.shownV1")` + preconditions
  (tab == .today, weekly product, programDay ≥ 6, no active cover) +
  async eligibility re-check before flipping the flag.
- Daily letter `maybePresentLetter` :1026-1049 — once-per-day via
  `@AppStorage("letter.presentedDayKey")` vs `TodayStateService.dayKey()`,
  0.7s delay, re-guards cover==nil && tab==.today at fire time.
Presentation-collision law: reconciliation defers to upgrade moment
(:1059-1062); a weekly-read knock must join this ladder.

## 7. Evening close

Trigger — HomeView.refresh() :1353-1360: `isEvening` (hour ≥ 18,
:1295-1305 + `--uitest-force-evening/day`) && enrolled &&
`eveningMomentDayKey != dayKey()` && !showing ⇒ 0.9s delayed
auto-present of `HomeEveningMoment` (cover :331-342; dismiss stamps
`@AppStorage("evening.moment.presentedDayKey")`). Every later visit:
the `eveningInvitation` row :602-613 ("close the day", moon doodle).
**A weekly read must not collide with the ≥18:00 auto-arrival window
or the letter's first-open moment.**
`PlankApp/Views/Home/HomeEvening.swift`: `HomeEveningMoment` :506 =
`JeniMoment(eyebrow: "closing the day", heroValue: programDay,
heroWord: "of N days", lines:, cta: "goodnight") { EveningClose(...) }`.
`EveningClose` :19 hosts the receipt ledger (FootLedgerRow :663),
feeling words (:318, writes via onReflect → HomeView.storeReflection
:1332: `day.reflection.<key>` + ObservationStore .feeling), dose/sit/
shot-day asks, tonight plan. ReSigning's dueWeekIndex window (closing
evening ≥17:00) overlaps this close — the re-signing already lives on
Becoming to avoid Home's evening stack.

## 8. JeniMoment / editorial motion kit

- `Kit/JeniMoment.swift` — `JeniTypedLines` :15 (consult typewriter:
  `[V8Line]`, per-word tick + sentence land, onComplete) and
  `JeniMoment<Content>` :100:
  `JeniMoment(eyebrow:, heroValue:, heroWord:, lines: [V8Line],
  cta:, onDismiss:) { content }` — paper + JeniAtmosphere, 96pt
  JeniCountingNumeral hero, typed lines, content arrives after,
  drag-down dismiss. THE arrival-moment shell.
- `Kit/JeniMotion.swift:99` — `JeniCountingNumeral(value:, unit:,
  font:, format:)`: counts on arrival, visibility-gated
  (`jeniArmOnVisible`), morphs on value change. Haptics `JeniHaptic`
  :164 (tick/land/swell).
- `Kit/JKSilkSweep.swift:11` — `.jkSilkSweep(trigger: Int)` one-shot
  day-complete sheen.
- Consult drawn evidence — `Views/OnboardingV8/V8Figures.swift:11`:
  `enum V8Figure { noiseWave, reboundCurve, muscleBar, halfDots,
  projection(deltaLb:weeks:) }` rendered by `V8FigureView` :24
  (private animated canvases beneath). `V8Line`/type clock in
  V8Beats/V8Motion.
- Charts — `Kit/JeniChartModel.swift:14`: forms line/band/bars/spark;
  `Series(values: [Double?], role: .ink|.context)`; `bridgeGaps` for
  sparse weigh-ins ONLY (L8). **Week-vs-3-week figure = one model,
  two series**: `JeniChartModel(form: .line, series: [.init(values:
  thisWeek, role: .ink), .init(values: threeWeekAvg, role: .context)])`
  → `JeniChart(model:, height:, filled:, emphasizeLast:,
  accessibilityText:)` (usage HomeView:850-856, hero :813-818).

## 9. Snapshot APIs for the read composer

`TodaySnapshot` (`Program/TodayStateService.swift:18-95`): kcalEaten /
proteinEatenG / carbs / fat / fiber / sugar (:35-44), `plates` :45,
steps :48, latestWeightKg / `emaDelta7dKg` / lastWeighInDaysAgo /
trendIsEstablished :51-55, `targets` (TargetsService.Targets: kcal?,
proteinG?, steps, numericsSuppressed) :58, brief :61, chapter /
isOnBreak / bandZone :70-74, programWeek / totalWeeks / arcPhase /
weekIntent :77-80, carePlan + checkStates + completedBeatCount.
Weight EMA source: `BodyStateService.current(userId:in:)` (:124-128) —
`.weight?.emaSeries / emaDelta7dKg / weeklyLossRate / isStalled /
trendEstablished`. Sleep: `SleepService.shared.lastNight` (hours =
asleepDuration/3600, :330) + `nightHistory()` (BecomingSummaryView:289).
Trailing-7 protein/logged days recomputed at :185-196.
**FoodWeekRead** (`Program/FoodWeekRead.swift:14`): pure
`compose(plates: [Plate(loggedAt:kcal:protein:)], proteinTargetG:) ->
Read?` — bands proteinLed/lateHeavy/steady, nil under 4 logged days;
consumer pattern FoodJournalView:155-163. Week facts:
`WeeklyReview.weekSlice` :419 + `weekStory` :317; whole-week ledger:
`JourneyModel.load` (§4). CohortStore (`Program/CohortStore.swift`):
chapter via `CohortStore.chapter`, glp1Cohort :97, isMaintenanceMode
:125, isRestrictiveRisk :135, isNumericSuppressed :143.

## 10. My pace / settings

`Views/Settings/ProfileHubView.swift:236` — row "my pace"
(slider.horizontal.3) → `go(.myPace)` → `EditProfileView` (:322).
`Views/Settings/EditProfileView.swift:13` — "your pace." page; ONE
live knob: `@AppStorage("workoutLevel")` ∈ {−1, 0, +1} (:17),
gentle/steady/a-little-more rows (:22-27); read by WorkoutGenerator
via TodayModules:240 (`workoutLevel + todaysEnergy` offset). Note:
distinct from ReSigning's `plan.sessionsAdjust` (weekly session count)
— pace-of-sessions vs difficulty-of-sessions.

## Gotchas for E1

- New beat case ⇒ `program_day_checks` SQL CHECK migration + itemKey.
- Steps beat is scheduled daily but never a Move; its check is written
  only by HomeView's auto-complete; TodayView is dead (HomeView is the
  spine).
- Three steps-goal sources must be converged for adaptivity (§2).
- bodyScan is never markable / never persisted (TodayModules:161-166).
- Weekly-review knobs are identity-scoped "plan."/"review." prefixes —
  they join the sign-out sweep; JSONL store is device-local.
- Auto-present ladders: Home (letter → upgrade → reconcile → body
  intro → evening) and Becoming (re-signing once per due week, tab-
  gated). A new knock must pick a rung, not stack.
