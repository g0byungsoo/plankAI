# app v8 — THE BUILD RECORD (running, 2026-07-28)

What shipped, commit by commit. QA evidence per phase; postponements
land in 04_DECISIONS, never silently.

## Phase 1 — the platform seam (SHIPPED)

- `CareProtocol` (`Program/CareProtocol.swift`): every clinical
  constant as one injectable Codable config; `.default` == shipped
  behavior; engines (`CarePlanEngine` / `TargetsService` /
  `PrescriptionEngineV2` / `BandModel`) take `careProtocol:`
  defaulting to `.default`. The one deliberate behavior change:
  the GLP-1 small-body protein floor now caps at the advisory-band
  value (50kg: 90g → 80g) — the panel's honesty fix, documented in
  04_DECISIONS.
- `BrandVoice` (`Program/BrandVoice.swift`): rules/voice split for
  CarePlanEngine's spoken reasons; `JeniVoice` = the shipped
  strings, byte-pinned by tests; an alternate voice rewords without
  touching a rule (tested).
- Tests: `CareProtocolTests` (13) — Codable round-trip, every seam
  injected, voice snapshot + alternate-voice proof, protein policy
  incl. small-body band compliance.

## Phase 2 — the chart + regimen records (SHIPPED)

- `ObservationRecord` + `RegimenPlanRecord` (PlankSync @Models,
  registered in the app container + the ONE shared test
  container). Observations: typed, userId-scoped, deterministic
  per-(kind, day) ids, `source` provenance; survive sign-out like
  weight logs; delete-account drops them.
- `ObservationStore` (`Program/ObservationStore.swift`): record /
  valueText / series / countMatching ("queasy 3 of the last 7" is
  now computable) / deleteSingular (same-day correction) /
  one-time legacy backfill (day.reflection · day.sit · day.dose ·
  day.note · plan.tonight histories become records) / deleteAll.
- Sync: `observations` + `regimen_plans` own-row tables +
  `protocols` / `protocol_items` read-all tables seeded with the
  serialized default (migration
  `20260728_app_v8_care_platform_foundation.sql`, additive only);
  upsert/hydrate pairs with the graceful-404 posture; hydrate
  ordering: reflections → observations → regimen → backfill.
- Defect fixes (audit-found): `day.dose.` joins the sign-out
  sweep (cross-account leak class); the dose mark is no longer
  write-only (read paths below).
- Tests: `ObservationStoreTests` (7) — upsert semantics, append
  kinds, scoping, aggregation window, backfill incl. the orphaned
  dose family + malformed-key skip + once-only flag, delete-all
  scoping.

## Phase 3 — medication first-class (SHIPPED pending QA reel)

- `RegimenService` (`Program/RegimenService.swift`): active-plan
  resolve, shot-day set/end, pure date math (ISO weekday, dose-day
  detection, `dayInMedicationWeek` 0-6, titration window vs
  CareProtocol.regimen).
- Composition: `CarePlanEngine.Input` gains `isDoseDay` +
  `titrationWindowActive` (resolved in `TodayStateService` from
  her regimen; absent plan = absent fields). Dose day: medication
  is the day's TOP LINE (config `doseDayLeads`), the prescription's
  keystone demotes to supporting[0] (med + one keystone = the
  non-negotiables), a GENTLE dose day composes to the dose alone.
  Titration window: hydration leads the invitations (never
  counted, `sticker_teacup` — the founder's own locked asset,
  revived) with the fluids-first reason.
- The row: `ProgramDayPrescription.medication` — quiet `pills`
  SF mark (no sticker exists in the locked set; clinical reads
  quieter), butter disc, "your medication · dose day — mark it
  when taken". Row tap opens HER REGIMEN (`RegimenSheet`: weekday
  hairline menu, remove path, privacy caption); the mark stays on
  the circle/hold — a dose is a deliberate tap, never a side
  effect of navigation. Check-off writes the check record + a
  `doseTaken` observation + the legacy key (evening pre-fill);
  retraction deletes the day's record.
- The evening close: dose "yes" marks the day's medication row
  kept; the ONE-TIME shot-day ask reveals after her first "yes"
  with no anchor (bare weekday words, two rows; re-offers on
  arrival while unanswered); "which day is your shot, usually?"
  → every engine reads it. The sit-check gains **"backed up"**
  (constipation was unrepresentable in three words — the most
  persistent GLP-1 complaint) and extends to the post-medication
  chapter; answers land as observations. Feeling / journal /
  tonight-plan writes dual-write (legacy key + observation);
  morning reads (`yesterdayFeeling`, `yesterdaySat`) go
  store-first with legacy fallback.
- Tests: `RegimenTests` (8) — ISO mapping, wrap math, titration
  boundaries, dose-day lead + demotion, gentle dose day,
  hydration invitation + caps, doseDayLeads config-off.

## Held in this phase (04_DECISIONS)

- Supplements UI: per D7 supplements are one collapsed optional
  line — lands with the language pass; RegimenPlanRecord already
  models them.
- Dose-day softening in the brief (day-1-2 fluid-first lines,
  day-5-7 hunger-return normalization) — the anchor now exists;
  the brief cascade is its own guarded pass.
- Sit-check ↔ medication-week correlation lines ("queasy has
  landed the two days after your shot") — needs 2+ weeks of
  observations; engine next pass.
