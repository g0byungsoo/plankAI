# Food Journal Engineering Plan — 2026-06-11

Source inputs: `docs/ref_fable_calorie_app_article_2026_06_11.md` ("Morsel") + 5 screenshots,
current stack (`FoodLogPersister`, `FoodPhotoStore`, `FoodLogTimelineView`, `CaptureFlowView`,
`AnalyticsView.becomingStack` / `BecomingDashboard.PlateFilmstrip`). Research only; no code changed.

## 0. What the Morsel article actually teaches us

**Adopt:**
- **The aesthetics self-verification loop** (the core lesson): drive the simulator, record video,
  dump frames, pixel-diff consecutive frames to catch pops/hitches. Recipe for this repo in §4.
- **Image-centric timeline**: days as sections (eyebrow date + day name + right-aligned total),
  meals as floating photos at varying sizes, whitespace not card chrome. Maps cleanly onto our
  cream canvas + thin-marks luxury direction; our burnt-orange accent slot is `FoodTheme.accent`.
- **Meal detail grammar**: photo hero → name/portion → big cal numeral → "% OF THE DAY · 20:01"
  context line → macro slider-bars with right-aligned grams → quiet pill actions (New Photo / Remove).
- **Transition craft as a feature**: "tiles flow smoothly between card and grid views" — §2.3.

**Reject / not this phase:**
- **Nano Banana studio image generation + Metal shaders**: we have REAL plate photos
  (`FoodPhotoStore`), and Direction-A guardrails kill AI-generated imagery. Real photos ARE the moat.
- **The chat agent** (personality, memory, tool calling, token streaming, prompt caching): not now.
  But note the bolt-on seam: Morsel's day page IS a thread. Our day-detail screen (§2.2) should be
  a `ScrollView` of entry rows with a slot model, so a future coach-message row type can interleave
  with meal rows without re-architecting. `FoodLogPersister.allEntries` + day aggregates become the
  coach agent's read tools later. Design for it, build none of it.
- **USDA DB**: already shipped (`Pipeline/USDAClient.swift`).

## 1. Storage hardening

**Constraint verified** (FoodLogPersister.swift header + PlankAIApp.swift:376-382): registering the
PlankFood-package `@Model` types in the app's `.modelContainer(for:)` hung launch on iOS 17
(main thread blocked, survives reinstall; suspect cross-package @Model registration). The @Model
classes (`FoodLogRecord`, `FoodLogItemRecord`, `FoodLogSchemaV1`) still exist, unregistered.
Current store: in-memory array mirrored to UserDefaults JSON (`jenifit.foodlog.v1`), **14-day TTL
prune on every write** — a journal cannot live on this (history is the product).

**Options:**
- (a) UserDefaults JSON forever: wrong. Unbounded growth in the defaults plist (whole plist
  rewrites on every change; multi-MB defaults are a known perf cliff), and the 14d TTL is the store's
  size discipline — removing it removes the discipline.
- (b) Register the @Models in the main container: the hang was never root-caused; a blind retry
  bets launch stability on it. Worth a 30-min spike on iOS 17.0/17.6 sims (register only
  `FoodLogRecord`, no relationship, then add `FoodLogItemRecord`) — but don't make the journal
  hostage to that investigation.
- (c) **Files-on-disk JSONL — recommended.** Application Support `FoodLog/entries.jsonl`,
  one JSON `Entry` per line, append-on-persist (O(1) writes vs the current full-array rewrite),
  excluded from iCloud backup decision NOT taken here (journal data is precious → do NOT exclude;
  photos stay excluded). Same `Codable Entry` struct, same in-memory hydrate-once read model,
  identical public API — zero call-site changes in CaptureFlowView/HomeFoodCard/tiles.

**Migration path (cannot lose logs):**
1. First read: if `entries.jsonl` missing and `jenifit.foodlog.v1` exists → decode UD blob,
   write all entries to JSONL, fsync, verify re-read count matches, only then mark
   `jenifit.foodlog.migrated.v1 = true`. Keep the UD blob for one release as a recovery copy.
2. Corrupt-line tolerance: JSONL decodes line-by-line; a bad line is skipped, not a wiped store
   (strictly better than today's all-or-nothing blob decode).
3. **Drop the 14-day TTL for entries.** Entries are ~200 bytes; 3 logs/day × 1 year ≈ 220KB. Text
   is not the size problem; photos are (~40KB each ≈ 44MB/year).
4. Future SwiftData move: the JSONL reader is the migration source; `FoodLogSchemaV1` stays parked.

**Retention/compaction seam (mechanism only — policy owned by the parallel expert):**
```swift
public struct FoodLogRetentionPolicy: Sendable {
    public var photoRetentionDays: Int?      // nil = keep forever
    public var entryDetailRetentionDays: Int? // beyond: collapse to day aggregate
}
public static func compact(policy: FoodLogRetentionPolicy)  // FoodLogPersister
static func prune(olderThan: Date)                          // FoodPhotoStore
static func pruneOrphans(validIds: Set<String>)             // FoodPhotoStore
```
`compact` runs detached on `scenePhase == .background`, never on launch. Aggregation writes a
`DayAggregate` line (date, kcal, macros, count) and drops the per-entry lines + photos past the
horizon. Compaction rewrites JSONL to a temp file + atomic rename.

## 2. The journal surface

### 2.1 View architecture
```
FoodJournalView (replaces FoodLogTimelineView internals, keeps init signature)
 ├─ JournalDaySection model: [(dayStart, dayLabel, kcalTotal, [EntryVM])]  // extend DayGroup
 ├─ ScrollView + LazyVStack(pinnedViews: [.sectionHeaders]) — day eyebrow pins like Morsel
 ├─ EntryTile: photo thumb (when FoodPhotoStore.hasPhoto) else current icon bubble
 │   sizes: hero (first/largest-kcal entry of day, ~full-width 4:3) + standard (72-96pt) —
 │   Morsel's grid screenshot, simplified per its own steering prompt ("alternating is cheesy")
 ├─ MealDetailView: photo hero, title, kcal numeral, "N% of the day · 2:14pm",
 │   macro bars (P/C/F, right-aligned grams), pills: new photo / remove
 └─ floating + button (unchanged contract: onAddTapped → parent dismiss-then-camera chain)
```
Voice locks apply: lowercase, italic-Fraunces punch word only, no daily-target shame framing
(keep the quiet right-aligned day kcal; do NOT copy Morsel's "300 of 2,000" hero — trend-as-hero
memory rule), no red, no meal-slot taxonomy (existing anti-MFP comment stands).

### 2.2 Day detail
Phase 1: the day section IS the day detail (one continuous scroll, like Morsel's timeline).
A separate day page only earns existence when the energy-ledger module (§3) or coach thread
needs a mount point — build `JournalDayView` then, not now.

### 2.3 Transitions (the Morsel showcase)
- **`navigationTransition(.zoom)` is iOS 18+** — our deployment target is 17.0/17.6
  (pbxproj + Package.swift `.iOS(.v17)`), so it can only ship behind `if #available(iOS 18, *)`.
  Use it as the *enhancement* tier for tile → MealDetail when we move the journal into a
  `NavigationStack` — free, system-quality, interruptible.
- **iOS 17 base tier — same-hierarchy zoom, not cross-presentation matchedGeometry.**
  `matchedGeometryEffect` does NOT match across `fullScreenCover`/`sheet`/NavigationStack push
  boundaries (separate presentation layers; it silently degrades to a fade + pop). The robust
  pattern: keep tile grid and meal detail in ONE ZStack hierarchy inside the journal screen —
  `@Namespace` + `matchedGeometryEffect(id: entry.id, in: ns)` on the photo, detail rendered as
  an overlay when `selectedEntry != nil`, animated with `Motion.gentleSpring`. Scrim fades in
  behind; drag-down to dismiss reverses it. This is exactly "tiles flow between card and grid".
  Gotchas to verify in the §4 loop: identical `.clipShape` corner radii on both endpoints
  (mismatch = corner pop), `.zIndex` pinned during removal, match the *image* not the container.
- **Becoming teaser → journal**: `PlateFilmstrip` lives in the Becoming tab; the journal presents
  as `fullScreenCover` from HomeView today. Cross-cover hero zoom is the fragile case — don't
  fight it in phase 1: ship cover with `.presentationBackground(Palette.bgPrimary)` (already the
  pattern) + a 0.35s scale-up of the journal content from 0.96 (reads as a zoom, costs nothing).
  Phase 3 option: present the journal as an in-hierarchy ZStack overlay on AnalyticsView so the
  filmstrip thumb genuinely flies into the journal grid via matchedGeometry — gate behind the
  frame-diff loop proving no hitch.

### 2.4 Image pipeline performance (100s of photos)
- **Decode off main**: never `FoodPhotoStore.photo(entryId:)` (sync `Data(contentsOf:)` + full
  decode) inside `body` — PlateFilmstrip already does this and should migrate too.
- Add `FoodPhotoCache`: `NSCache<NSString, UIImage>` (totalCostLimit ~64MB) fronted by an async
  loader. Decode via ImageIO downsampling (`CGImageSourceCreateThumbnailAtIndex` with
  `kCGImageSourceThumbnailMaxPixelSize` = tile size × scale) so the cached bitmap is cell-sized,
  then `image.preparingForDisplay()`. SwiftUI side: tiles hold `@State image` + `.task(id:)`.
- Source files are already ≤480px JPEG ~40KB (FoodPhotoStore cap) — the ceiling is decode count,
  not bytes. LazyVStack + cache makes scroll cost O(visible).
- MealDetail wants better than 480px long-term: bump `maxDimension` to 1024 for NEW saves
  (storage ~120KB/photo) and keep rendering old 480s scaledToFill — forward-only, no migration.

## 3. Energy math plumbing

The Mifflin-St Jeor / steps / session-kcal chain deleted in `1b09d3e` (it was a *shame-surface
UI verdict*, not bad math) gets resurrected as a service — UI policy stays with the parallel expert.

**`PlankApp/Services/EnergyLedgerService.swift`** (main target: needs UserRecord, StepsService,
SessionLogRecord, and calls into PlankFood):
```swift
@MainActor final class EnergyLedgerService: ObservableObject {
    struct Profile { let heightCm: Double?; let weightKg: Double?; let ageYears: Int }
    struct SpentBreakdown { let bmr, stepsKcal, sessionKcal: Double; var total: Double }
    struct DayLedger { let date: Date; let gained: Double; let spent: SpentBreakdown
                       let classification: DayClassification }
    enum DayClassification { case noData, onTrack, gentleOver, underFueled }  // names = expert's
    struct ClassificationPolicy { let bufferKcal: Double; let minLogsGate: Int
                                  let underFuelFloor: Double }                 // expert-injected
    func ledger(for date: Date) -> DayLedger
    func recentLedgers(days: Int) -> [DayLedger]
}
```
Formulas (verbatim from the deleted code, now with citations in doc comments):
- BMR (female, exclusive cohort): `10*w + 6.25*h − 5*age − 161`; age from
  `onboardingAgeRange` midpoint map (21/29/39/49/60, default 30); guards `h > 50`, `w > 20`.
- Steps: `StepsService.shared.todayCount × 0.04` (today only — HealthKit historical query needed
  for past-day ledgers; add `StepsService.count(on:)` or classify past days BMR+sessions only,
  flagged `stepsUnavailable`).
- Sessions: today's `SessionLogRecord.totalDuration` minutes × 5 kcal/min.
- Gained: `FoodLogPersister` day aggregate (extend `last7DaysKcal` to `kcal(on day:)`).

**Compute strategy: lazy + memo.** Math is trivially cheap over an in-memory store; no disk
cache. Memo `[DayKey: DayLedger]`, invalidated by `FoodLogPersister.changeNotifier` (entry
delete can mutate a past day) and StepsService updates; closed past days otherwise stable.
Classification of low-confidence days must run *through the gates* (e.g. `minLogsGate` — one
logged coffee must not classify the day) — mechanism here, thresholds the expert's.

## 4. The aesthetics verification loop (runnable recipe)

One-time setup: `brew install idb-companion && pipx install fb-idb` (ffmpeg/ffprobe/python3+PIL
already present; idb is NOT installed yet). `xcrun simctl` cannot synthesize touches; idb can.

```bash
# 1. Boot (sims available: iPhone 17 Pro, 17 Pro Max, Air, 17, 16e — runtime iOS 26.2)
xcrun simctl boot "iPhone 17 Pro" ; open -a Simulator
# 2. Build + install + launch (scheme: plankAI, bundle: com.bk.plankAI)
xcodebuild -project /Users/bko/plankAI/plankAI.xcodeproj -scheme plankAI -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/jfbuild build
xcrun simctl install booted /tmp/jfbuild/Build/Products/Debug-iphonesimulator/plankAI.app
xcrun simctl launch booted com.bk.plankAI
# 3. Drive — find targets by accessibility, never guess pixels
idb ui describe-all --udid <UDID>          # dump AX tree → frames in points
idb ui tap <x> <y> --udid <UDID>           # taps; `idb ui swipe x1 y1 x2 y2 --duration 0.3`
# 4. Record the transition (start before the tap, SIGINT to stop)
xcrun simctl io booted recordVideo --codec h264 /tmp/journal.mov &   REC=$!
idb ui tap <tile-x> <tile-y> --udid <UDID> ; sleep 1.5 ; kill -INT $REC ; wait $REC
# 5. Dump frames + inspect timing
ffprobe -v error -select_streams v -show_entries stream=avg_frame_rate /tmp/journal.mov
mkdir -p /tmp/frames && ffmpeg -i /tmp/journal.mov -vsync 0 /tmp/frames/f_%04d.png
# 6. Pixel-diff consecutive frames (write once as Scripts/frame_diff.py):
#    PIL ImageChops.difference per pair → mean delta. Flag: spike (>3x neighbors mid-anim = POP),
#    zero-delta run mid-animation (= HITCH/dropped frames), and crop flags (--crop x,y,w,h) to
#    isolate the zooming tile region for corner-radius pops. Read flagged frames with the Read
#    tool (they're PNGs) to judge visually.
```
Known quirks for this repo:
- **Paywall gate**: home/journal are behind hard paywall. Temp-set
  `PaymentService.effectiveHasProAccess` DEBUG branch → `return true` and rebuild (RC stream
  overrides cached entitlement; simctl-tapping through purchase doesn't work). REVERT after.
- **HealthKit is empty on sim**: steps rail = 0; energy-ledger spent shows BMR-only. Fine for
  transition QA; don't chase the "missing" steps.
- **No food data on a fresh sim**: add a DEBUG-only seeder in FoodLogPersister
  (`ProcessInfo.processInfo.arguments.contains("-seedFoodLog")` → write ~10 entries across 4 days
  + copy bundled fixture JPEGs into FoodPhotoStore), launched via
  `xcrun simctl launch booted com.bk.plankAI -seedFoodLog`. Photos are the journal; seed them.
- `recordVideo` first 2-3 frames can be black/stale — diff script skips until first non-trivial
  frame. Sim doesn't emulate ProMotion; judge smoothness by inter-frame delta uniformity, not 120Hz.
- Stills for layout QA: `xcrun simctl io booted screenshot /tmp/s.png` then Read the PNG.
- LazyVStack swipe-actions no-op on iOS 26.2 (existing comment in FoodLogTimelineView) — keep
  long-press delete; verify the confirmationDialog doesn't fight the zoom gesture.

## 5. Phasing (smallest shippable first)

1. **P0 — storage** (no UI): JSONL store + UD migration + TTL removal + retention seam +
   `FoodPhotoCache` + photo prune hooks. Ship silently inside any release.
2. **P1 — photos in the log** (smallest visible slice): existing timeline rows render the
   FoodPhotoStore thumb (async, cached) in place of the icon bubble when present; pinned day
   headers. No new screens. This alone moves us most of the way to "her journal".
3. **P2 — meal detail**: tile tap → MealDetailView (photo hero, % of day, macro bars,
   remove / new photo). iOS 17 same-hierarchy overlay; run the §4 loop on it.
4. **P3 — the showcase**: image-centric day grid (hero + standard tiles) + matchedGeometry
   tile↔detail zoom + iOS 18 `.zoom` tier + Becoming filmstrip in-hierarchy zoom. Frame-diff
   QA is the acceptance gate, per the article.
5. **P4 — energy ledger module** (blocked on parallel expert's classification policy):
   EnergyLedgerService + whatever surface the policy permits.
6. **Later, explicitly out of scope**: coach/chat thread on the day page (bolt-on seam noted
   in §0), SwiftData migration (JSONL is the source when it happens), Supabase sync of food_logs.
