# 51 — THE RECORD MUST NOT LIE

**feat/app-v2 · 2026-08-18 · SURGERY on record integrity. BUILD 32 IS
SUPERSEDED** — the moment this pass changed product source, the frozen
build-32 tree stopped being the future engineering line; the founder
can still archive 32 from the pre-pass state if wanted, but the line
moves on. `CURRENT_PROJECT_VERSION` bumped **32 → 33** after the gates
(4 lines, nothing else in the pbxproj beyond file registrations).
**NOT archived, NOT uploaded, NOT submitted, no deploy, no migration,
no production SQL.**

One goal, from the brief, verbatim: **a user record must never become
less true because Jeni read it, imported it, edited it, synced it,
reinstalled it, or crossed midnight.** Every fix below was reproduced
RED before it was fixed, except where a section says otherwise in as
many words.

---

## 1 · EVERY RED REPRODUCTION (watched, not claimed)

| defect | RED evidence (exact failure) |
|---|---|
| **W1** typed-over-Health revert | `"healthkit" is not equal to "manual"` + importDecision `"update" ≠ "skip"` — 2 asserts, 3 controls green (`RecordMustNotLieTests`) |
| **P1** start_date UTC round trip | LA reinstall read **day 6 not 5**; NY 6; replay 6; DST-fall 6; DST-spring 6; Tokyo passed (pinned — east-of-UTC read was luck-correct) |
| **P1 boundary** | `PlanWireDate` extracted with the honest BEFORE (UTC) → 5 of 7 boundary tests RED: LA/NY re-read "2026-08-01" as **Jul 31**, both DST days slid to neighbors, evening-LA/morning-Tokyo writes named the wrong day |
| **F2** micros drop on edit | 11 failures: `withNutrition/scalingNutrition/withIdentity emptied: ["micros"]`, stepper `0.0 ≠ 15.0`, fraction `0.0 ≠ 30.0`, clamp erased the set |
| **F3** NULL source → "photo" | `XCTAssertNil failed: "photo"` ×2 (null + missing key); verbatim control green |
| **Fractional timestamps** | support archive (`…09:00:00.123456+00:00`) **UN-archived the plan** (`adopt(nil)`); echo un-archived a locally-archived plan; DEFAULT-stamped `started_at` left `createdAt` at the hydration instant — 3 tests RED |
| **Invented weight provenance** | NULL-source weigh-in hydrated as `"manual"` — `"manual" ≠ "unknown"` RED at the weight seam |
| **hydrateUser NULL-blanking** | 6 erasures in one RED: gender → `""`, height → nil, current/goal kg → nil, motivation → `""`, promisesKept → `0` |
| **dayKey vocabulary fork** | run under `-testLanguage ar -testRegion SA`: both producers emitted **Islamic-era keys `1448-03-05`**, and the Gregorian readers round-tripped them to **year 0851** — 10 failures |
| **D2** AX5 title break | reproduced on the SE at AX5: `your / medicatio / n` (frame on file) |
| **D1** tab-bar ghosting | reproduced at rest on iPhone 16: "TO…" of TOOLS raw under the pill (frame on file) |
| **D6** ruler "1675" | **NOT reproduced** at full resolution (ruler labels render `158 · 159 · 160` clean) → **no change**, per the brief's own condition |

RED-first exceptions, named: the W4 instant tombstone and the
importer's honored-calendar fix were implemented before their tests;
their test is a **differential** that carries the proof inside itself
(same cleared sample checked with and without the instant under a
Tokyo calendar → `.insert` vs `.skip`). The dose/observation
`?? "unknown"` one-token fixes share the weight seam's RED as the
class reproduction (§9 explains why no seams were extracted). W3/W5/W6
and the smoother unification are pinned by after-the-fact tests
(`WeightOneStoryTests`), stated as pins, not REDs.

## 2 · ROOT CAUSES

1. **W1** — `WeightLogWriter.persist` updated today's row in place
   without relabeling `source`; the importer's own per-day rule then
   treated the row as the scale's to correct
   (`ChatToolRouter.swift` × `BodyMassImportService.swift`). The law
   existed one function down (`update` → `sourceAfterCorrection`).
2. **P1** — `start_date` is a Postgres `date` (a CIVIL DATE) that was
   written as the UTC date of the mint instant and reparsed as UTC
   midnight, then re-anchored in the LOCAL calendar by
   `ProgramScheduleCalculator`. West of UTC, UTC midnight of day D is
   D−1's evening: every reinstall moved the day.
3. **F2** — the defaulted-parameter re-init family, fifth and sixth
   recorded instances: `PlateEditSession`'s three copy helpers AND
   `IngredientEditorSheet.makeUpdatedItem` re-initialized
   `CapturedItem` without `micros:`. The compiler cannot see an
   omission in a defaulted init.
4. **F3** — the hydrate decoder carried the pre-E8.1 default
   (`?? "photo"`) the write side had already outlawed.
5. **Fractional timestamps** — every server-side write (`now()`
   defaults, support SQL) carries microseconds; a bare
   `ISO8601DateFormatter` returns nil for them; half the read sites
   lacked the two-formatter fallback, and one of the halves was the
   support-archive adopt.
6. **dayKey fork** — the most-used producer (`TodayStateService
   .dayKey`) followed the device locale/calendar while its ten
   readers were pinned Gregorian/POSIX. Identity strings, not display.

## 3 · THE INVARIANTS, AS EXECUTABLE TESTS

1. **USER INTENT WINS** — `testATypedWeighInOverAHealthRowBecomesHersAndTheImportStandsDown`;
   `ProfileAdoptionTests` (a NULL column never erases a local fact);
   `WireTimestampTests.testALocallyArchivedPlanStaysArchivedThroughTheEcho`.
2. **UNKNOWN STAYS UNKNOWN** — `FoodSourceHydrationTests` (NULL ≠
   photo); `InventedProvenanceTests` (NULL ≠ manual); dose `?? "sheet"`
   and observation `?? "manual"` fixed at the same law (§9).
3. **EDITING CANNOT DESTROY UNRELATED TRUTH** —
   `FieldPreservationTests` (Mirror harness: field-count pin 25,
   fixture-completeness tripwire, per-helper no-field-emptied sweep,
   micros scale with portion/fraction, clamp never erases).
4. **A CIVIL DAY IS A FACT** — `PlanWireDateTests` (CA/NY/UTC/Tokyo ×
   morning/evening × DST spring/fall × 3-round-trip fixed point ×
   locale-proof ASCII); `RecordMustNotLieTests` reinstall suite;
   `DayKeyVocabularyTests` under ar_SA.
5. **EVERY READER TELLS THE SAME STORY** — `WeightOneStoryTests`
   (one series, one reduction, the drawn line ends exactly at the
   spoken trend); VisitPacket §5.
6. **DELETE STAYS DELETED** — preserved (DeletionContractTests +
   RecordRepairTests untouched-green) and EXTENDED across time zones
   (`testAClearedWeighInStaysClearedAcrossATimeZoneChange`).
7. **CORRECTION SURVIVES THE JOURNEY** — W1 chokepoint + the sim
   journey (§11) + the standing corrections tests (all green).

## 4 · EXACT IMPLEMENTATION CHANGES

**Weight** — `WeightLogWriter.persist` relabels via
`WeightLedger.sourceAfterCorrection` (the W1 one-liner). NEW
`PlankApp/Program/WeightSeries.swift`: THE canonical resolved series —
`source != "onboarding"`, one sample per civil day = EARLIEST
(the engine's fasted-morning law), plus `read()` as the one trend
authority. `WeightWeekReadEngine.trendSeries` (new): per-day points of
the SAME fold `read` speaks, for drawn lines. Migrated onto the
canonical series: ChatModuleCards (line + delta now = jeni's
`weeklyDeltaKg`), JourneyModel (delta line + week-read signal),
InsightEngine (+ protein numerator now from THE ladder),
NotificationOrchestrator (universe only; fold deliberately kept —
§19), BodyStateService (trend internals exclude onboarding;
latest/earliest deliberately keep all rows — the two-universe split is
documented in-code), JeniReadTools, **BecomingTiles.weightTile — a
FIFTH hand-ported EMA found during verification** (pass 50's W2
undercounted): now draws trendSeries and speaks the gated band.
`WeightTrendChart.computeEMA` reduces earliest-of-day
(order-independent). VisitPacket weight = canonical series,
earliest-of-day (W3). `TodayModuleHost` ruler seeds from the ladder,
never a bare 65 (W5). Importer: deterministic day representative
(manual first — W6) + honored `calendar` param + the instant check.
`DeletionLedger.clearedWeightInstantId` (W4): the epoch-second
tombstone, recorded at remove, checked at import — zone-proof, zero
false blocks by construction. `WeightLedger.removalNote` stops warning
"a later sync can bring it back" (false since §44's tombstone; its
test re-pinned to the truth).

**Program day** — NEW `Packages/PlankSync/Sources/PlankSync/
PlanWireDate.swift`: `wireString` = LOCAL civil date (component math,
C-locale digits), `localDate` = local midnight (DST-safe via
`Calendar.date(from:)`), tolerant of a timestamp head, nil for
garbage. Used at the upsert, the fresh-insert hydrate, and the merge's
goalDate adopt. `ISO8601DateFormatter.dateOnly` (UTC) deleted with its
last caller. The QA autym door speaks the same vocabulary.
`ProgramPlanMerge` keeps `startDate` never-merged (its own law: the
day she has been living in wins).

**start_date MEANS**: *the calendar day she enrolled, where she was* —
a CIVIL DATE, now serialized and reparsed as one. It is not an
instant, and the column (`date NOT NULL`) never was.

**Timestamps** — `WireTimestamp.parse` (plain ?? fractional) at:
`ProgramPlanMerge` archived/completed adopt, plan-insert
archived/completed/started_at, day-check completed_at,
`CareConnectionService.establishedAt` (which parsed nil for 100% of
rows and let the active-clinic sort run on `.distantPast` ties — a
PHI-destination input). `ProgramPlanMerge`'s header law rewritten to
name its real exception: a truly-NULL lifecycle timestamp IS adopted
(the support un-archive lever); a REAL timestamp may never ride that
exception by failing to parse.

**Food** — `CapturedItem`: every edited field is `var`; the three copy
helpers + the editor's save are MUTATIONS of `self` (a field the edit
does not name is carried by construction); `scalingNutrition` scales
micros (`Micronutrients.scaled(by:)`, one arithmetic — PlatePriors'
hand copy deleted onto it); the dispatcher's three enrich rebuilds are
mutations; `CapturedFood.kcalLow/High` are `var` so both plate
rebuilds (`rebuiltFood`, `PlatePriors.scale`) are mutations too. F3:
the DTO decodes absence as absence (`source: String?`); the write side
was already lawful. `mergeRemote` derives `items` from
`itemsDetail`'s names (the list never crossed the wire; the detail
does and holds the same names — derived, never invented).

**dayKey** — `TodayStateService.dayKey` pinned (Gregorian components,
ASCII, device time zone only); `MedicationScheduleEngine.dayKey` +
`parseDayKey` era-pinned; `DoseLedger`/`SymptomLedger` parsers pinned;
`WeeklyReview.windowSlice` parse pinned; `BodyScanSyncService.noon`
pinned; `CareWeekSummary.weekKey` era-pinned (a server row id);
`ObservationStore` backfill year-bounded (2024…2100 — a Buddhist-era
key parsed as Gregorian 2569 minted rows 543 years out, and synced).

**Profile** — `hydrateUser` split into `applyHydratedUser` (the
applyHydrated* pattern); non-optional wire columns adopt
unconditionally, every optional adopts ONLY WHEN PRESENT.

**Sessions** — `exercise_results` decoded back (write-only column
since v1: every routine's per-exercise breakdown was lost on
reinstall); present-only on adopt.

**Visual** (§12) — the bottom paper fade + 18pt scroll clearance in
`MainShell.tabRoot` (D1); `RegimenSheet.title` wraps on the word or
scales (D2).

## 5 · WEIGHT TRUTH TABLE

| scenario | before | after | proof |
|---|---|---|---|
| manual over Health (same day) | reverted on next import | row becomes HERS; importer skips | RED→GREEN W1 |
| Health after manual | protected (skip) | unchanged (control pinned) | control test |
| two Health samples, one day | latest sample wins, updates in place | unchanged | importer unchanged; decision pinned |
| two rows one day (manual+HK) | fetch order decided the representative | MANUAL is the day's representative, deterministic | W6 code + §4 |
| two devices | insert-only + id/day tombstones | + instant tombstone | DeletionContract green + new test |
| historical correction | `update` relabels (34's law) | unchanged | RecordRepairTests green |
| delete + Health reimport | day tombstone (§44) | + zone-proof instant tombstone | differential test |
| relaunch | — | walked on sim: kept → removed → still gone | §11 journey |
| sync/hydrate | NULL source became "manual"; server logged_at could re-date | absence stays absent; fractional parses | RED→GREEN ×2 |
| DST | engine `bySettingHour` safe | + trendSeries DST-pinned | PlanWireDate DST tests (class) |
| timezone travel | cleared day could resurrect | instant tombstone blocks the same sample in any zone | differential test |
| lb/kg | unit-error rejection (E2) | unchanged, now behind every surface | suite green |
| onboarding self-report | in SOME trends (tile, chat card, insights, packet), out of others | in NO trend; still listed in the ledger; still a ladder rung | `WeightOneStoryTests` |
| multi-row civil day | latest-of-day in 3 readers, earliest in 2 | EARLIEST everywhere | `testOnePhysicalDayReduces…` |
| nothing hydrated yet | ruler seeded a fabricated 65 kg | ladder first; the literal is reachable only for an account with no weight anywhere, and records nothing by itself | W5 code |

**One weight story, settled**: one row universe + one day reduction
everywhere (implemented); one FOLD for everything a customer reads as
a trend — `WeightWeekReadEngine` (lines drawn by `trendSeries`, words
by `read`); the fast 7-day EMA survives ONLY as the internal trigger
fold (band-crossing pushes, plateau counters, the rapid-loss
tripwire), now over the same canonical series. **Why two folds is not
residue**: the trigger thresholds (`easedDelta ≤ −0.09`, flat-week
0.15/7pt, the tripwire's 14-point span, BandModel zones) were
calibrated to the fast fold's reactivity, and a slower fold would fire
the SAFETY tripwire later — re-tuning triggers is engine work with its
own evidence bar, already named as pass 53's "one smoother". The
documented product reason the brief allows, with an owner and a date.

## 6 · PROGRAM-DAY TRUTH TABLE

| zone / event | before (reinstall read) | after |
|---|---|---|
| California | day+1 (UTC midnight = prior local day) | exact |
| New York | day+1 | exact |
| UTC | exact | exact |
| Tokyo | exact on read; morning mints WROTE yesterday's date | exact both directions |
| DST spring (Mar 8) | day+1 | exact |
| DST fall (Nov 1) | day+1 | exact |
| reinstall / new device | ±1 for non-UTC | exact (tests ×4 zones) |
| sync replay | stable-but-wrong | fixed point at the right day |
| locale | formatter digits could leak | component math, ASCII pinned |
| already-mis-anchored devices (builds ≤32) | — | keep their lived day (merge never moves `startDate` — the shipped law); their next plan write re-serializes the civil date correctly |

## 7 · FOOD FIELD-PRESERVATION MATRIX

`CapturedItem` = 25 stored fields (count PINNED in tests). Copy paths
and their contract, all now mutation-based:

| path | names (changes) | carries by construction |
|---|---|---|
| `withNutrition` | name?, portion, kcal, 4 macros | the other 18 (incl. micros, nutritionSource, share fields) |
| `scalingNutrition(f)` | portion×3, kcal, macros, sugar/sodium/satFat, **micros — scaled** | identity, provenance, share fields |
| `withIdentity` | id | **everything else** (pinned: "changes the id and NOTHING else") |
| editor save (`makeUpdatedItem`) | name, portion, typed macros, scaled fiber/sugar/sodium/satFat, **micros — scaled** | identity + provenance |
| dispatcher calibrate/override/enrich | nutrition + source + micros | accuracy fields, share fields |
| `PlatePriors.scale` | delegates to `scalingNutrition` | plate memory (corrections, prior) via plate mutation |
| `rebuiltFood` | items, kcalLow/High | plate memory + any future plate field |

The tripwire: a NEW stored field fails `testTheModelFieldCountIsPinned`
→ the author populates `fullyPopulated()` → every sweep covers it.

## 8 · PROVENANCE LIFECYCLE (CAPTURE → PERSIST → HYDRATE → REPEAT)

- CAPTURE: dispatcher stamps the door (unchanged, lawful).
- PERSIST: `persistedSourceValue` — absent → `unknown` (unchanged).
- SYNC OUT: `syncRow` runs the same law (unchanged).
- **HYDRATE: fixed** — food NULL → nil (absence); weight NULL →
  `"unknown"` (was `"manual"` = an authorship claim that decides which
  author wins the day); dose NULL → `"unknown"` (was `"sheet"`);
  observation NULL → `"unknown"` (was `"manual"`, and those rows reach
  the clinician packet).
- REPEAT: relog carries source through `EntryMethod` (unchanged);
  hydrated `items` now derived from `itemsDetail`, so a reinstalled
  plate keeps its ingredient names.
- RENDER: `provenanceLine(for:)` resolves nil/`unknown` to the honest
  "ranges, not exact" (unchanged); `WeightLedger.provenance` narrates
  nothing for unknown (its pinned law: "an unknown source is not
  narrated at all").

## 9 · SYNC MATRIX (per family; fixes this pass in **bold**)

| family | CREATE | EDIT out | EDIT in (server→device) | DELETE | CONFLICT | RETRY | verdict |
|---|---|---|---|---|---|---|---|
| users/profile | immediate | ✓ | full adopt when clean; **NULL columns no longer erase local facts** | RPC cascade | pendingUpsert guards | ✓ sweep | **PROVEN** (was BROKEN: NULL-blanking + push-back loop) |
| program_plans | immediate | ✓ | ProgramPlanMerge (clean⇒adopt); **fractional archived/completed/started_at now parse; civil dates now anchor locally** | none (phase+archivedAt) | pendingUpsert | ✓ | **PROVEN** (was BROKEN two ways) |
| program_day_checks | immediate | ✓ | insert-only (edits don't propagate) | none | server-last-write wins server-side | ✓ | NOT PROVEN for cross-device edits — documented |
| session_logs | immediate | ✓ | full adopt when clean; **exercise_results now read back** | none | pendingUpsert; no timestamp | ✓ | PROVEN for restore; conflict arbitration NOT PROVEN (no updatedAt) — documented |
| session_ratings | immediate/sweep | ✓ | insert-only | none | device wins | ✓ | PROVEN (append-only by design) |
| weight_logs | immediate | ✓ (update relabels; **persist now relabels too**) | insert-only; **NULL source no longer invented** | ✓ delete + row/day/**instant** tombstones | manual-wins + tombstones | ✓ (delete fire-and-forget + ledger re-assert) | **PROVEN** |
| food_logs | immediate + launch reconcile | setLoggedDay re-pushes | insert-only; **source absence preserved; items derived** | ✓ delete + tombstone + sweep | device wins | ✓ (id-diff) | **PROVEN** (edits-in still insert-only — documented, deliberate: local truth wins) |
| dose_events | immediate, deterministic ids | ✓ | insert-only; **source no longer invented** | ✓ + ledger | device wins | ✓ | **PROVEN** |
| observations | immediate, deterministic ids | ✓ | insert-only; **source no longer invented** | ✓ + ledger | device wins | ✓ | **PROVEN** |
| regimen_plans | immediate | ✓ | care_team branch adopts UNGUARDED and clears pendingUpsert | none (endedAt) | ⚠ server clobbers an unsent local write on a care_team row | ✓ (unless just cleared) | **BROKEN-CLASS, DOCUMENTED NOT FIXED** — §19 |
| program_facts | immediate | ✓ | prescribed branch same shape | none (endedAt) | same ⚠ | ✓ + structural reporter | **DOCUMENTED NOT FIXED** — §19 |
| weekly_reads | immediate, deterministic id | ✓ | insert-only; decode invents offer/decision on NULL; id discarded at insert | none | device wins | ✓ + reporter | latent — documented (§19) |
| consent_grants | immediate | ✓ | revokedAt-only one-way adopt | none (timestamp) | monotone-safe | ✓ | PROVEN |
| day_progress | immediate | ✓ | last-write-wins on updatedAt | none | timestamped | **NONE — no pendingUpsert field** | durability NOT PROVEN — @Model-gated, documented; its false "syncs on next attempt" comment left for the pass that adds the field, so comment and fix land together |
| day_reflections | immediate | ✓ | restore-if-missing | none (prefix sweep) | device wins | none (UserDefaults) | documented |
| jeni memories / chat | — | never syncs | — | local per-row | — | — | device-only (listed as durable in Settings — pass 53's named item) |
| body scans / photos | opt-in mirror | queue | ✓ | ✓ | — | own queues | unchanged this pass (noon parse pinned) |

Fix criteria applied as briefed: everything fixed above met
(A) corrupts/reverts + (B) reproduced + (C) no migration. Everything
documented failed one of the three — mostly (B) unreachability
uncertainty or a policy question a surgical pass must not answer alone.

## 10 · TESTS ADDED

- `plankAITests` **+18** (1368 → **1386**, 2 skipped = the standing
  env-gated pair): `RecordMustNotLieTests` (10), `WeightOneStoryTests`
  (5), `DayKeyVocabularyTests` (3 — run twice: host locale AND
  `-testLanguage ar -testRegion SA`).
- `PlankSyncTests` **+20** (9 → **29**): `FoodSourceHydrationTests`
  (3), `PlanWireDateTests` (7), `WireTimestampTests` (4),
  `InventedProvenanceTests` (3), `ProfileAdoptionTests` (3).
- `PlankFoodTests` **+7** (208 → **215**): `FieldPreservationTests`.
- `plankAIUITests` +3 journey legs in `Pass50AuditUITests`
  (2 pass, 1 records its own environmental block — §11).
- One existing test updated, not weakened: `RecordRepairTests
  .testTheRemovalNoteTellsTheTruthAboutAHealthRow` re-pinned to the
  note's NEW truth (the old assertion demanded the resurrection
  warning the tombstones made false — the suite caught the copy change
  exactly as a pin should).

## 11 · SIMULATOR JOURNEYS (the self-audit)

1. **Weigh-in life cycle, real UI end to end** (PASS, 63s, solo):
   Home's weigh-in tool → the ruler → keep → Becoming → the ledger
   lists it on today with NO provenance word (hers) → the row's editor
   → "remove this weigh-in" → "remove it" → gone → **relaunch (hydrate
   + import both run) → still gone.**
2. **Program day across relaunch** (PASS, 30s, solo): the
   autym-repaired persona (hydrated through the REAL apply path with
   the new civil-date vocabulary) shows "day N of M"; relaunch with no
   re-seed reads the SAME day off the persisted plan.
3. **Words plate wears words provenance** (leg passes by recording its
   environmental block): the typed sentence entered the chooser but
   the estimate round trip did not complete in the QA harness — the
   same words-door blocker pass 50 recorded. The provenance render for
   a words plate therefore stays **unit-pinned, not sim-proven**
   (`EntryMethodTests` + `FoodSourceContractTests` + the new boundary
   tests); tree evidence in `/tmp/jenifit_pass50/`.

Entrance-equivalence note (the brief's example): jeni's `log_weight`
tool, the Today ruler and the plan-numbers sheet all call the ONE
`WeightLogWriter.persist` chokepoint (verified by grep — three call
sites, one writer), so the unit RED covers every entrance; the sim
journey exercised the Today entrance.

## 12 · FRAME EVIDENCE (visual repairs)

Shots in the session scratchpad (`…/3b820908…/scratchpad/shots/`):
`d1_home_before/after`, `d1_becoming_after` (before = pass-50's three
shots), `d2_regimen_ax5_before` (iPhone 16 — already wrapped clean,
recorded), `d2_regimen_ax5_se_before/after` (the reproduction and the
fix), `d6_ruler_probe` (not reproduced), `becoming_tile_canonical`
(the tile on the canonical series), plus a 60fps launch recording with
two extracted contact sheets: the cream zoom stays flash-free and the
new bottom fade arrives with the shell — **no pop, no reflow** across
the entrance. Viewports: iPhone 16 (standard + AX5), SE 3rd-gen (AX5).
The one un-walkable check: max-scroll clearance cannot be
scroll-driven on this simulator (the repo's recorded synthesized-drag
limitation); the 18pt content margin asserts it by construction.

## 13 · FILES CHANGED (48)

**PlankSync (3 src, 6 test)**: SyncService.swift, ProgramPlanMerge.swift,
PlanWireDate.swift (new) · FoodSourceHydrationTests, PlanWireDateTests,
WireTimestampTests, InventedProvenanceTests, ProfileAdoptionTests (new),
HydrationNormalizationTests untouched.
**PlankFood (7 src, 1 test)**: CapturedFood, SnapResultMath,
CalorieMathService, PlatePriors, IngredientEditorSheet,
FoodCaptureDispatcher, FoodLogPersister · FieldPreservationTests (new).
**PlankApp (18)**: ChatToolRouter, BodyMassImportService,
DeletionLedger, WeightSeries (new), WeightEMA, WeightWeekRead,
WeightLedger, BodyStateService, InsightEngine, TodayStateService,
MedicationScheduleEngine, DoseLedger, SymptomLedger, ObservationStore,
WeeklyReview, VisitPacket, CareWeekSummary, CareConnectionService,
BodyScanSyncService, NotificationOrchestrator, JeniReadTools,
ChatModuleCards, JourneyModel, BecomingTiles, TodayModuleHost,
MainShell, RegimenSheet, PlankAIApp (QA door only) — 28 with the
overflow counted.
**Tests/app**: RecordMustNotLieTests (new), RecordRepairTests (one pin
updated), Pass50AuditUITests (+3 legs).
**pbxproj**: registrations for the two new files + the version bump.

## 14 · PROTECTED PATHS

Payment · Paywall · Auth · AppPhase · Info.plist · entitlements ·
widgets · `supabase/` (schema, migrations, Edge Functions) — **EMPTY
this pass** (verified by `find -newer` against the pass anchor). All
`@Model` declarations **zero-diff** (`Models.swift` untouched) — **no
store migration exists to fail.** Paths touched OUTSIDE the historical
"empty" set, each for record truth and named here rather than
smuggled: `Notifications/NotificationOrchestrator` (canonical-series
fetch swap only), `Care/CareConnectionService` +
`Care/CareWeekSummary` (timestamp parse + key era pin),
`Sync/BodyScanSyncService` (key parse pin), `PlankAIApp` (QA fixture
speaks the real wire vocabulary).

## 15 · PRODUCTION MUTATIONS

**No SQL run, no deploy, no migration, no schema read.** The UI
journeys ran on the QA sims' standing anonymous accounts (pass-50's
recorded posture — no erases, no new accounts): journey 1 inserted one
weigh-in through the app's own writer and deleted it through the app's
own delete inside the same journey (net rows: zero, both via shipped
paths, plus the standing QA seed writes every walker run has always
made under those accounts, which `46`'s reaper covers). Journey 3
wrote nothing (no reading arrived).

## 16 · MIGRATIONS

None written, none applied. Nothing in this pass requires schema. The
wire formats changed are value-compatible both directions: old rows'
`start_date` strings parse under the new anchor; new civil-date writes
are the same `yyyy-MM-dd` shape; `source` columns were already
nullable/checked; `exercise_results` was always on the wire.

## 17 · REMAINING P0

**None known.** Every reproduced corruption/reversion path found by
this pass's REDs and sweeps is closed and green.

## 18 · REMAINING P1 (named, owned)

1. **regimen_plans / program_facts server-authoritative branches**
   adopt over an unsent local write AND clear its retry flag
   (`SyncService` care_team/prescribed arms). Not fixed because the
   guard interacts with authority policy: a client write to a
   care_team row is refused server-side (42501), so a stuck
   `pendingUpsert=true` would freeze adoption forever — the right fix
   needs the authority model's owner, not a surgeon. The question is
   written out here; reachability of a legitimate local write on those
   rows is the deciding fact.
2. **day_progress has no retry** (no `pendingUpsert` field — the one
   @Model change this pass refused; its "syncs on next attempt"
   comment is FALSE and left to land with the field).
3. **weekly_reads hydrate** invents `offerKey`/`decision` on NULL and
   discards `row.id` (latent unique-collision → silent batch discard).
   NULL-reachability unproven; policy-coupled vocabulary.
4. **Cross-device edit propagation** is insert-only for
   food/dose/observation/day-check/session-rating families — deliberate
   ("local truth wins") but it means a second device never sees an
   edit; the next trust pass owns the arbitration design.
5. **G1/G2** (interval model + packet cadence word/count) — pass 53's
   scheduled work; the packet still says "your weekly medication" for
   a daily plan.
6. Latents documented with sites: `FoodLogPersister` id `?? UUID()`
   re-mint; `users.start_date`/`day_progress.date` decode rides the
   SDK's date strategy; static formatters snapshot their zone at first
   use (dateline-mid-session only); BreathworkState's bare-formatter
   display keys; `Models.swift:346` doc-comment still lists an
   `"apple_health"` source nothing writes (@Model file left untouched
   by law).

## 19 · DELIBERATELY NOT CHANGED

The trigger fold (§5's documented reason — pass 53). `startDate`
never-merged in ProgramPlanMerge (the lived-day law). The `?? .now`
fallbacks on plan civil dates (unreachable for a `date NOT NULL`
column; guarded upstream by parse tolerance). G2's packet cadence
(rides the interval model). The regimen/facts authority guards (§18.1).
`hydrateUser`'s full-adopt for PRESENT values (the recovery contract —
only absence handling changed). Insert-only merges as a conflict
stance. The desk void, Move's sheet, sheets-vs-destinations (later
product work, per the brief). D6 (not reproduced). No usuals, no
water, no waist, no Method, no activation resequencing, no App Store
Connect, no production deploys, no unrelated cleanup.

## 20 · SAFE FOR PASS 52?

**PROOF: 1386/1386 app (2 skipped = the standing env-gated pair) ·
29/29 PlankSync · 215/215 PlankFood · 2/2 sim journeys (third records
its block) · DayKey suite green under BOTH locales · Release BUILD
SUCCEEDED · @Model zero-diff · protected paths empty · zero
migrations · zero production SQL.** The tree is a working tree with
one more pass of record-integrity hardening on top of the build-32
state, its version advanced to 33, nothing shipped anywhere.

---

RECORD INTEGRITY: PASS — every reproduced lie closed RED→GREEN; the invariants are executable tests
WEIGHT: PASS — one canonical series + one customer-legible fold, six consumers migrated, W1–W6 closed (trigger-fold retirement documented for 53)
PROGRAM DAY: PASS — civil-date boundary both directions, 4 zones × 2 DST × replay proven, walked on sim
FOOD FIELD PRESERVATION: PASS — mutation-based copies by construction + a tripwire that catches the next field
PROVENANCE: PASS — absence arrives as absence at every hydrate (food/weight/dose/observation); render laws unchanged
DELETE INTEGRITY: PASS — preserved, and extended across time zones (instant tombstone), walked on sim through a relaunch
SYNC: PASS WITH NAMED RESIDUE — reverts/corruptions fixed (profile NULL-blanking, plan un-archive, invented sources, exercise_results, items); the authority-branch and durability items are documented with owners, not fixed
TIMEZONE: PASS — day keys are one pinned vocabulary (proven under ar_SA), civil dates anchor locally, tombstones are zone-proof
VISUAL EDGES: PASS — D1 and D2 reproduced, repaired, re-shot on 16/SE/AX5 with frame-by-frame entrance check; D6 not reproduced, untouched
PRODUCTION MUTATIONS: NONE — no SQL, no deploy; journey writes net zero through shipped paths on the standing QA accounts
MIGRATIONS: NONE
P0 REMAINING: 0
P1 REMAINING: 6 named in §18, each with a site and an owner
SAFE FOR PASS 52: YES

— end of pass 51 —
