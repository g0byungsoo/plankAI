# v25 E1 THE SPINE — mechanics map (recon, 2026-08-10)

Read-only audit of the exact mechanics for adding: a synced SwiftData
model + table (`program_facts`), a second (`weekly_reads`), analytics
events, and new Swift files. Every claim cites file:line on feat/app-v2
@ e3bb8f4.

## 1 · New-file mechanics — pbxproj EDITS ARE REQUIRED (app + tests)

`plankAI.xcodeproj/project.pbxproj:6` — `objectVersion = 77`, but the
project contains **zero** `PBXFileSystemSynchronizedRootGroup` sections
(grep count 0). Everything is classic `PBXGroup` + explicit file
references. Creating a file on disk does NOT add it to any target.

A v24 file (MedicationCatalog.swift) needed exactly **4 entries**:

1. PBXBuildFile — pbxproj:1296
   `DA2409000000000000000A01 /* MedicationCatalog.swift in Sources */ = {isa = PBXBuildFile; fileRef = DA2409000000000000000A02 …};`
2. PBXFileReference — pbxproj:2830
   `…A02 = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = MedicationCatalog.swift; sourceTree = "<group>"; };`
3. Group child — pbxproj:3140 (inside the Program PBXGroup, ~3100-3160)
4. Sources build phase — pbxproj:6588 (app target `Sources`)

ID convention: hand-minted 24-char unique strings. v24 used the
`DA2409…` prefix with sequential pairs (odd suffix = PBXBuildFile,
even = PBXFileReference: A01/A02, A07/A08…). IDs need not be strict
hex — the project already contains `RL0003RL0003…`, `HP0001…`
(pbxproj:3130-3131); uniqueness is the only real rule. Pick a fresh
prefix per era (e.g. `DA2510…` for v25) and never collide.

**Test target (plankAITests): same 4-entry pattern.** RegimenTests.swift:
PBXBuildFile pbxproj:1319, PBXFileReference:2853, group child:3308
(group `5747CE84C1A2E80AF85C6FB0 /* plankAITests */`, PBXGroup at
pbxproj:3271-3327), test Sources phase:6741.

**Packages (PlankSync / PlankFood / PlankEngine / PlankVoice): NO
pbxproj edit ever.** They are `XCLocalSwiftPackageReference`s
(pbxproj:7159-7166, refs listed :5194-5200); SPM globs
`Sources/<Target>/**` automatically. PlankFood links as a product
dependency only (pbxproj:606, :3084, :5144). Gotcha (v23 memory):
PlankFoodTests are NOT in the app scheme — they run via the package
scheme only.

**Bottom line**: new `.swift` in `PlankApp/Program/` → 4 pbxproj
entries (app target). New test in `plankAITests/` → 4 entries (test
target). New file in `Packages/PlankSync/Sources/PlankSync/` → zero
pbxproj work. Commit-hygiene law: pbxproj edits land LAST in the batch.

## 2 · SwiftData model pattern

### Model shape (PlankSync package — Packages/PlankSync/Sources/PlankSync/Models.swift)

`RegimenPlanRecord` — Models.swift:674-789. The house shape:

- `@Model public final class` in the PlankSync package (public, since
  the app imports it).
- `@Attribute(.unique) public var id: String` (Models.swift:676) —
  String ids, client-minted (`UUID().uuidString` default, :750).
- `public var userId: String` (:678) — every entity is userId-scoped;
  all app reads filter on it (cross-account isolation law).
- Plain `String` enums-as-strings with the vocabulary documented in
  doc comments (`kind`, `scheduleRule`, `endReason` — :681-743).
- Bookkeeping trio: `createdAt`, `updatedAt`, `pendingUpsert: Bool`
  (:745-747); init sets `pendingUpsert = true` (:787) — the write IS
  the outbox enqueue.
- Optionals for every additive column (lightweight migration safe).

`DoseEventRecord` — Models.swift:806-872. Adds the deterministic-id
pattern: id = `"\(userId.lowercased())-dose-\(dayKey)"` minted in
DoseEventStore.swift:20, so every surface converges on one row.
`regimenPlanId` (:812) stamps version provenance.

### App container registration — PlankApp/PlankAIApp.swift:526-571

`.modelContainer(for: [ … ])` array form (NOT an explicit `Schema`),
**15 models**: UserRecord, SessionLogRecord, DayProgressRecord,
ExerciseRecord, ExerciseCalibrationRecord, SessionRatingRecord,
WeightLogRecord, ProgramPlanRecord, ProgramDayCheckRecord,
ChatMessageRecord, ObservationRecord, RegimenPlanRecord (:554),
DoseEventRecord (:559), BodyScanRecord, ConsentGrantRecord.
PlankSync-package models register cleanly (comment :547-552); the
PlankFood cross-package models HANG the launch and stay exiled
(comment :564-570) — new synced models belong in PlankSync.

### Test container — plankAITests/TestModelContainer.swift:1-27

ONE shared in-memory container for the whole test process:
`enum TestModelContainer { static let shared: ModelContainer = … }`
listing the same 15 models (:16-22), `isStoredInMemoryOnly: true`
(:23). Header law (:5-11): a SECOND in-memory container in the same
process hangs the main thread, and a subset schema crashes — every
SwiftData test uses THIS container, distinct userIds per test, never
its own container. **A new @Model must be added here in the same
commit as the app container list.**

Example use — plankAITests/MedicationPlatformTests.swift:396-399:
```swift
@MainActor
func testVersionChainNeverOverwritesHistory() throws {
    let context = TestModelContainer.shared.mainContext
    let userId = "v24-chain-\(UUID().uuidString)"
```
(`@MainActor` on SwiftData-touching tests; unique userId isolates.)
Alt shape: `ModelContext(TestModelContainer.shared)` for a scratch
context (BodyStateServiceTests.swift:109).

## 3 · Sync end-to-end (regimen_plans as the model)

All in Packages/PlankSync/Sources/PlankSync/SyncService.swift (2320
ln) + PlankApp/Sync/AppSync.swift (1533 ln).

### Upsert — SyncService.swift:1024-1095 `upsertRegimenPlan`

- Private `struct SupabaseRegimenPlanUpsert: Encodable` with
  snake_case field names 1:1 to columns (:1027-1052) — the column map
  IS this struct; no CodingKeys, no shared mapper.
- Dates → `ISO8601DateFormatter().string(from:)` (:1053, :1063-1064).
- `try await supabase.from("regimen_plans").upsert(payload).execute()`
  (:1078-1080).
- Success: hop to MainActor, re-fetch the row by id via
  `FetchDescriptor` + `#Predicate`, set `pendingUpsert = false`, save
  (:1081-1089).
- Failure (table missing / migration unapplied / offline): caught,
  DEBUG-print `"deferred (table not deployed yet?)"`, row keeps
  `pendingUpsert = true` (:1090-1094). **That's the whole 404-graceful
  contract — never throw to UI, the sweep retries.** v24 additive
  columns note (:1045-1047): unknown keys make PostgREST REJECT the
  upsert until the migration lands, so client + migration ship
  together and defer as a unit.

### Hydrate — SyncService.swift:1097-1205 `hydrateRegimenPlans` (@MainActor)

- Private `struct Row: Decodable` snake_case, nearly all Optional
  (:1099-1121) so an older server row never fails decode.
- `.select().eq("user_id", value: userId).execute().value` (:1123-1127).
- TWO ISO8601 formatters — plain + `.withFractionalSeconds` — and a
  `date(_:)` helper trying both (:1129-1134): Postgres timestamptz
  serializes fractional.
- Insert-if-missing keyed on id; **uuid case normalization** on
  existing rows (:1140-1144): if `existing.userId` differs only by
  case, rewrite it to the incoming id (Supabase lowercases, iOS
  uppercases UUIDs — the standing hydrate-boundary law).
- Authority split (:1145-1169): `care_team` rows are
  server-authoritative (fields overwritten on hydrate); `self` rows
  are client-owned (never clobbered). Hydrated rows get
  `pendingUpsert = false` (:1168, :1196).
- Errors swallowed with DEBUG print (:1200-1204).

### Outbox = `pendingUpsert` flag + `retryPendingUpserts()` sweep

SyncService.swift:610-650 — `@MainActor public func
retryPendingUpserts()`: per model family, `FetchDescriptor` with
`#Predicate { $0.pendingUpsert == true }`, loop `await upsertX(...)`.
Regimen sweep :621-628, dose events :639-649 ("ride the same sweep
from day one — the 2026-08-08 audit lesson"). **A new synced model
MUST get its family block here or offline writes strand forever**
(comment :605-611 documents exactly that historical bug).

Call sites: AppSync.onLaunch → AppSync.swift:139; onAuthChanged →
:351. Write path: views call AppSync pass-throughs
(`AppSync.upsertRegimenPlan` AppSync.swift:1050, `upsertDoseEvent`
:1058) fire-and-forget; the record was already saved locally with
`pendingUpsert = true`, so a failed push is self-healing.

### Hydrate orchestration — AppSync.swift:396-454 `hydrateAndSync`

Ordered awaits, one per family; regimen :443, dose events :445, then
`ObservationStore.backfillLegacyIfNeeded` (:446). In-flight guard set
:398-405. New family = one `await service.hydrateX(userId:)` line
here + a pass-through under "Upsert pass-throughs" (:816).

## 4 · Migration SQL shape — supabase/migrations/20260809090000_v24_medication_platform.sql

Structure (75 lines, additive only, header law :1-7 "Founder applies;
until then the client defers gracefully"):

- **Additive columns** (:11-15): `alter table public.regimen_plans
  add column if not exists product_id text, …` (one statement, 4
  columns) + `comment on column` for each (:17-24).
- **New table** (:28-46): `create table if not exists
  public.dose_events` — `id text primary key` (client-minted
  deterministic string, NOT uuid), `user_id uuid not null references
  auth.users(id) on delete cascade`, `check` constraints inline for
  vocabularies (:34-40), `created_at/updated_at timestamptz not null
  default now()`.
- **Index** (:48-49): `(user_id, day_key desc)`.
- **RLS own-row pattern** (:51-68): `enable row level security` + 4
  policies (select/insert/update/delete) `to authenticated`, all
  `using ((select auth.uid()) = user_id)` (update also `with check`).
- **Grant** (:70): `grant select, insert, update, delete … to
  authenticated`.
- **Clinician seam** (:72-74): no direct clinician policies; portal
  access only via SECURITY DEFINER RPCs under consent (S4 chokepoint
  law) — copy this stance for program_facts/weekly_reads.

**UNAPPLIED migrations** (as documented):
- `20260809090000_v24_medication_platform.sql` — **NOT YET APPLIED**
  (founder gate: docs/app_v24/01_EVIDENCE.md:79-82;
  docs/app_v25/audit/01_app_reality.md:391-392).
- `20260804090000_p6_weekly_summaries.sql` — still on the founder
  checklist (docs/release_v1_1_7/00_LAUNCH_READINESS.md:173; STATE.md
  :462-464 "founder applies").
Earlier v8 chain (20260728…20260730) applied live per STATE.md; the
release checklist still says "confirm observations/regimen migrations
are applied" (00_LAUNCH_READINESS.md:174-175). v25 tables will sit
BEHIND two pending migrations — the deferral path is load-bearing.

## 5 · Analytics

### API — PlankApp/Analytics/AnalyticsManager.swift

- Events: `enum AnalyticsEvent: String` (:27), snake_case raw values
  (`"paywall_view"`), grouped by `── section ──` comments with
  why-this-exists doc blocks. New events = new cases here.
- Call shape: `Analytics.track(.eventName, properties: ["key": value])`
  — :412 `static func track(_ event: AnalyticsEvent, properties:
  [String: Any] = [:])`; free-form String overload :418 ("prefer the
  enum form"). Also `Analytics.trackException(error, context:)` :483
  and `Analytics.captureScreen(name)` :536.
- Wrapper guarantees (:418-451): stamps `app_version`, `timestamp`,
  `environment` (+ `is_test_user: true` in DEBUG, :430-435); 0.5s
  coalesce de-dupe keyed event+props on serial queue
  `ai.jenifit.analytics` (:405-446); never blocks UI, never crashes.
- Sinks: `protocol AnalyticsSink { send(event:properties:);
  sendScreen(name:) }` (:374-377); `Analytics.sinks` array (:393,
  ConsoleAnalyticsSink default); mutate ONLY via `addSink` (:467 —
  queue-serialized; direct append raced a crash).
- No property allowlist mechanism — discipline is by convention:
  properties are per-event snake_case scalars documented at the enum
  case (e.g. :68-70 `plan`, `time_on_paywall_ms`).

### PostHogSink — PlankApp/Analytics/PostHogSink.swift:29-46

`send` → `PostHogSDK.shared.capture(event, properties:)` untouched
pass-through (:30-35); `sendScreen` → `PostHogSDK.shared.screen(name)`
so $autocapture gets screen-tagged (:43-45); `Analytics.resetIdentity`
= `PostHogSDK.shared.reset()` at the sign-out identity boundary
(:24-26).

### Bootstrap + test-user exclusion — PlankApp/PlankAIApp.swift:276-408

`bootstrapAnalytics()`: PostHog setup (:282-308; DEBUG `flushAt = 1`
:300, crash autocapture :307), `Analytics.addSink(PostHogSink())`
(:312). DEBUG identity: `PostHogSDK.shared.identify("dev-\(vendorId)")`
+ super-properties `register(["is_test_user": true, …])` (:395-402),
paired with PostHog's "Internal & test accounts" filter on person
property `is_test_user` (:389-394). Release registers only
`environment: production` (:404-406) — TestFlight builds are Release,
so founder adds tester person-ids in PostHog manually
(00_LAUNCH_READINESS.md:180-182).

### Food-package bridge — Packages/PlankFood/…/Analytics/FoodAnalytics.swift

`public enum FoodAnalytics` (:18): nested `Event: String` enum whose
raw values MUST mirror the main-app enum (:19-22 law); closure sink
`register(_ handler:)` (:67), nil-safe drop before registration.
Wired at PlankAIApp.swift:319-327: `FoodAnalytics.register {
Analytics.track($0, properties: $1) }` (+ a first-log nudge cancel
hook). Same closure-seam pattern applies if a package ever needs v25
events.

### 3 representative call sites

- PlankApp/App/WallView.swift:127 —
  `Analytics.track(.paywallView, properties: [...])` (enum + props).
- PlankApp/Chat/ChatSession.swift:388 —
  `Analytics.track(.jeniChatToolCalled, properties: ["tool": call.name])`.
- PlankApp/App/WallView.swift:434 —
  `Analytics.track("wall_sign_in_tapped")` (free-form string).
- (package side) PlankApp/Views/Today/PlateDetailSheet.swift:116 —
  `FoodAnalytics.track(.logSaved, properties: [...])`.

### Medication floor (binding on E1)

v24 ships ZERO medication analytics: no medication/dose/regimen cases
in AnalyticsEvent, no `Analytics.track` in MedicationLog /
DoseEventStore / dose surfaces (grep-verified). Names, sites, notes
never reach notifications or analytics (Models.swift:660-663, :804 —
the stigma floor). v25 events touching program facts near medication
must carry structure ("dose_day": true at most), never substance.

## 6 · @MainActor enum service pattern (the house idiom)

The LAW, verbatim shape note — PlankApp/Program/CareProtocolStore.swift:15-24:

```swift
// Shape note: an enum service with @MainActor statics (the house
// idiom — TargetsService / RegimenService / ObservationStore),
// deliberately NOT a class: instance deinit of isolated classes
// routes through the concurrency runtime's deinit-on-executor
// back-deploy shim, which aborts in libmalloc on the current sim
// runtime (caught by the dealloc canary while this was a class).
// No instances → no deinit → the crash class is structurally gone.
@MainActor
enum CareProtocolStore {
    private(set) static var current: CareProtocol = .default
    private static let cacheKey = "careProtocol.served.v1"
```
State lives in `static var`s; entry points are `static func`s;
UserDefaults injected as a parameter for testability (:33, :46-48).

Second example — PlankApp/Program/MedicationLog.swift:21-41:
`@MainActor enum MedicationLog` — the chokepoint service: nested
vocab enums (`Resolution`, `Source: String`), one
`@discardableResult static func resolve(_:slotDayKey:source:userId:in
context: ModelContext) -> DoseEventRecord?`. Context is always passed
in, never owned. Third: `@MainActor enum DoseEventStore`
(DoseEventStore.swift:16-17). **Every new v25 service (FactsStore,
WeeklyReadEngine…) follows this: @MainActor enum, static state,
context-as-parameter, no instances.**

## The recipe (new synced model, distilled)

1. `@Model public final class ProgramFactRecord` in PlankSync
   Models.swift — unique String id, userId, optionals for evolvable
   fields, createdAt/updatedAt/pendingUpsert(=true in init).
2. Register in PlankAIApp.swift `.modelContainer` list (:526) AND
   TestModelContainer.swift (:16) — same commit.
3. SyncService: `upsertProgramFact` (snake_case Encodable, graceful
   catch, clear pendingUpsert on success) + `hydrateProgramFacts`
   (@MainActor, optional Row, dual ISO formatter, insert-if-missing,
   case-normalize) + a family block in `retryPendingUpserts` (:610).
4. AppSync: pass-through (:816 section) + one await in
   `hydrateAndSync` (:396).
5. Migration `2026….sql`: additive, own-row RLS ×4, grant, index,
   RPC-only clinician stance. Goes on the founder-gate ledger.
6. pbxproj: nothing for PlankSync files; 4 entries per new app-target
   file, 4 per new test file. Analytics: new AnalyticsEvent cases +
   `Analytics.track(.…)` — no infra work.
