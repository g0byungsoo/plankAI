# E2 — THE MEDICATED YEAR · architecture + decisions (living doc)

2026-08-10 · execution era. Mandate: `08_E2_BRIEF.md`. Decision record:
`07_NEXT_ERA_DECISION.md`. Law: `00_THE_SYSTEM.md` §2/§7/§9/§13; v24
law `docs/app_v24/00_REGIMEN.md` binds every medication seam. Evidence
lands in `10_E2_EVIDENCE.md`. This doc records what is BUILT and WHY —
including where implementation reality overruled the brief.

## 0 · reconnaissance corrections to the brief (recorded)

Five parallel code maps + a sim walk before any code. Where the brief
(and the decision doc) disagree with the repository, the repository
wins and the delta is recorded here:

1. **`CaptureFlowView` is LIVE, not dead.** It is the production
   describe/no-photo capture path (`TodayModuleHost.swift:111`, four
   Today entry points). The brief's sweep claim inverted the truth:
   `PlankAIApp.swift:1445` is a `--debug-snap-camera` harness, not the
   production presenter. What IS dead: `FoodCorrectionSheet`, orphaned
   *inside* CaptureFlowView by a never-set `@State editingItem`
   (4 references, 3 of them nil-writes), plus its private
   `PortionStepper` and the `scanCorrectionOpened` event. The sweep
   (P10) takes exactly that set and corrects the four doc files that
   recorded the wrong mechanism.
2. **The late-dose path already has a face and an engine — nothing
   connects them.** `MedicationScheduleEngine.openLateSlot` /
   `lateWindowEnd` have zero production callers; every DoseSheet
   presenter hardcodes today's dayKey; the late face at
   `DoseSheet.swift:126-131` is dead markup. E2's "late dose meets
   facts" is therefore a WIRING era, not new architecture: compute the
   open late slot, route the sheet to it, put label facts on it.
3. **The weekly read's dose line can never render for a weekly
   injector**: the composer's dose observation gates on
   `dosesExpected >= 2` and weekly users pass `dosesExpected == 1`.
   The one dose fact the read carries is unreachable for the only
   cohort whose read is dose-anchored.
4. **Weight math exists and is good** — `WeightEMA` (7-day EMA,
   60-day window), `BodyStateService.weightRead` (trust floor: ≥3
   logs spanning ≥5 days), band words, source provenance. The read's
   weight absence is an integration gap, not missing science. Also
   found: a DUPLICATE inline EMA in `BecomingTiles.swift:452-465`
   (consolidate), `weighSoften` structurally unable to fire
   (`priorWeighs` hardcoded nil both branches,
   `JourneyModel.swift:386-389`), and the Becoming weight tile not
   gated by numeric suppression (every other weight surface gates).
5. **The evening dose ask fires all seven evenings for a weekly
   injector** (`HomeEvening.swift:161-199` keys on chapter only,
   never `isDoseDay`), and its "no" deliberately bypasses the
   chokepoint (v24 law: an answer, not a skip) — but on a real dose
   day that leaves the slot unresolved-invisible. E2 scopes the ask
   to open slots.
6. **`RegimenService.dayInMedicationWeek` exists with zero callers**
   — v8 left the cycle-position seam waiting. It is anchor-derived;
   E2's cycle is event-derived first (her actual last taken dose),
   anchor-derived as fallback.
7. **Symptom severity cannot be re-recorded in place** —
   `ObservationStore`'s custom-id upsert drops `valueNum`
   (`ObservationStore.swift:115-121`). Must fix before food noise
   rides the same path.
8. **v24 symptoms never reach the visit packet** —
   `VisitPacket.symptomSection` still reads `.sitCheck` with the
   3-word v8 vocabulary. E2's "structured longitudinal evidence for
   E6" starts by pointing the packet at the real record.
9. **Analytics ground truth**: the five E1 read/fact/notif events ARE
   live; `dose_marked`, `dose_reminder_action`, `regimen_changed`,
   `side_effect_logged`, `walk_action_shown`, `walk_goal_hit` are
   constants with zero call sites; `notif_silenced` can never fire
   (recordIgnored has no production caller — E1 named debt, stands);
   NO cohort person property exists (no `$set` anywhere in release);
   the onboarding HealthKit outcome is thrown away in
   `V8Structured.swift:274`; no payload-hygiene test exists.
10. **The daily-cadence dose row makes Today's actionable count 4**
    (inserted after the `prefix()` cap) — this is v24 LAW ("a rhythm
    rides as first support outside the cap"), not a defect. Recorded
    so nobody "fixes" it.

## 1 · the shape of the era

Everything lands through E1/v24 chokepoints; no new stores, one new
pure engine, zero new tabs/destinations.

- **B1 TELEMETRY + COHORT IDENTITY (first, the kill/redirect
  trigger)** — categorical person properties (`glp1_cohort`,
  `medicated`, `med_route`, `med_cadence`, authority) set at launch +
  regimen change; the six dead v24/E1 event constants wired at their
  chokepoints (MedicationLog, MedicationReminders.handleAction,
  applySelfRegimen, SideEffectLog, walk beat surfaces); onboarding
  HealthKit outcome recorded; a payload-hygiene unit test (event →
  allowlisted keys, categorical values) so the law is a test, not a
  convention.
- **B2 THE CYCLE (pure)** — `MedicationCycle` in the schedule engine
  family: weekly-anchor regimens only, position derived from her last
  taken dose (fallback: schedule anchor), `day N of 7` + band
  (`landing` 1-2 · `steady` 3-5 · `waning` 6-7 · `open` past-window),
  tendency register authored per band ("appetite often returns about
  now"), nil by construction for daily/non-medicated (zero leakage,
  test-pinned).
- **B3 LABEL FACTS (catalog data, versioned)** — `MedicationLabelFacts`
  on `MedicationProduct`: missed-dose window, past-window action,
  interruption rule, day-change minimum gap, each as structured fields
  + one authored fact line, snapshot-tested per product against the
  FDA label (source + revision date pinned in the test). Compounded
  products carry nil → the honest line ("compounded medications don't
  carry standard labeling — your prescriber's instructions rule").
  Late face = facts + "your prescriber decides what's right for you."
  Never a computed catch-up, never "take it now".
- **B4 THE LATE WIRING** — `openLateSlot` reaches Today (the dose row
  points at the open slot when one exists), the DoseSheet late face
  becomes reachable, and the late face carries B3's facts card.
- **B5 FOOD NOISE + THE UNDERREPORTED SET** — `SideEffectSymptom`
  gains `foodNoise` (graded by the existing 3 severities, its own
  words) + `hairShedding`, `menstrualChange`, `feelingCold`,
  `lowMood`; mood routes to crisis resources FIRST (the existing
  ChatSafety local response pattern, rendered before anything else
  happens with the chip). Capture rides existing moments only: the
  side-effect sheet (now also reachable from the dose sheet's taken
  face — the natural end-of-cycle moment) — never a questionnaire,
  never a slider. ObservationStore custom-id upsert fixed to carry
  severity.
- **B6 PATTERNS ACROSS CYCLES** — `MedicationPatternEngine` gains the
  food-noise series against dose timing: per-cycle onset detection,
  ≥3 cycles floor, "food noise has come back around day 5 in each of
  your last three cycles" — the era's signature observation, timing-
  never-causality, her-record-outranks-the-general-claim.
- **B7 WEIGHT INTELLIGENCE** — one pure `WeightWeekRead` over the
  existing EMA/trust-floor math: window trend vs noise floor, band
  word, data-sufficiency state, provenance; absent when the record is
  silent. Consolidates the duplicate EMA; fixes the weighSoften
  plumbing; gates the weight tile under suppression.
- **B8 THE READ GROWS UP** — composer inputs gain `cycle`,
  `weight`, and an honest medication movement (dose resolved/late/
  open + era change); the weekly-injector dose line becomes reachable;
  teaching set gains cycle-aware lines; grammar/caps/cooldowns
  unchanged. Richer, never longer.
- **B9 TODAY REASONS WITH THE CYCLE** — `CarePlanEngine.Input` gains
  `dayInDoseWeek`/`daysSinceDoseChange`; BrandVoice's dose/meal/walk
  reasons become cycle-aware where honest; the evening ask scopes to
  open slots. No new rows, cap untouched.
- **B10 CHAT ONE-JENI** — medication{} gains `cycle_day`/`cycle_len`;
  envelope gains a compact `week{}` from the LIVE WeeklyReadRecord;
  EF prompt gains the cycle rule + label-fact redline (founder
  deploys); becoming tile floor softened (an active regimen never
  reads "not enough to read yet"); visit packet reads the real
  symptom timeline.
- **B11 THE FOOD DEFECT + SWEEP** — `SnapRefine.fixWords` scoped so a
  correction can only move items it names (deterministic application;
  unmentioned items keep their exact prior nutrition + identity +
  edits); FoodCorrectionSheet/PortionStepper swept; docs corrected.
- **B12 THE LOOP + RC** — films, frames, adversarial battery, XXXL;
  founder-gate audit; release-candidate prep so the era lands WITH
  the release, not behind it.

## 2 · decisions (running ledger)

| # | decision | why | declined |
|---|---|---|---|
| E2-D1 | cycle position is EVENT-derived (last taken dose), anchor as fallback | the honest physiological clock is her actual injection, not the plan; label day-change rules move the anchor legitimately | anchor-only (dayInMedicationWeek's dormant shape) |
| E2-D2 | past-window position renders as the OPEN slot state, never "day 8 of 7" | a cycle that keeps counting past its window fabricates a rhythm that didn't happen | modular arithmetic forever |
| E2-D3 | label facts are structured catalog data + ONE authored line each, snapshot-tested against the label | versioned, per-product, correctable; a new med stays one entry | prose strings scattered in views |
| E2-D4 | food noise = a symptom kind with the existing 3 severities, its own vocabulary | one store, one sheet, one deterministic-id discipline; no new diary | a 0-10 slider (MeAgain's intake-form register) |
| E2-D5 | mood chip routes to crisis resources FIRST, in-surface, before recording | the brief's §risk 7; ChatSafety's fixed-local-response pattern is the precedent | treating mood as just another chip |
| E2-D6 | the read's weight signal joins the signals band; weight observations floor-gated by the EMA trust floor | the band is "what happened"; weight is a what-happened fact; observations stay ≤2 | a weight hero (would dominate every week) |
| E2-D7 | evening ask scopes to open dose slots | seven-evening asking for a weekly event is noise; v24's "no stays an answer" law preserved on real dose days | removing the evening ask (kills the v8 pre-fill) |
| E2-D8 | fixWords becomes scoped-deterministic: model answers ONLY for named items, client merges | SnappyMeal ablation (decision doc §3.1): full-plate re-estimation degrades unmentioned items | prompt-engineering the full-plate ask |
| E2-D9 | daily-cadence outside-the-cap stands | v24 law, deliberate | "fixing" it to 3 |
| E2-D10 | cohort identity = person properties via $set, categorical only | the kill/redirect trigger; PostHog-filterable | event-only properties (unfilterable) |

## 3 · build log (as shipped)

(appended per phase as work lands)
