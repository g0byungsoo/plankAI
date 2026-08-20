# PASS 53 — THE ANSWERING RECORD

**feat/app-v2 · built 2026-08-18 · the pass after THE RECORD MUST NOT
LIE (51) and THE FIRST DAY (52).** Their thesis was defensive: the
record must not become less true. This pass is the offensive half:
**the record should answer back** — record once → correct once → Jeni
remembers → the product changes → she can see why.

---

## COMPACT TRUTH BLOCK

| claim | proof |
|---|---|
| app unit suite | **1446 passed · 0 failed · 2 skipped** (the standing env-gated `SpineLiveSyncTests` pair) · total 1448 · xcresult `Test-plankAI-2026.08.18_18-35-41` |
| delta vs baseline | 1398 → 1448 = **+50**, reconciled exactly: `AnsweringRegimenTests` 28 · `AnsweringMovementWeightTests` 10 · `AnsweringMethodTests` 10 · `BodyStateServiceTests` +1 · `DailyUtilityTests` +1 |
| PlankFood | **239/239** (225 → 239; +14 = `AnsweringFoodTests`) · xcresult-verified |
| PlankSync | **29/29** (unchanged — the new wire fields ride existing shapes; see §5) |
| civil-date law | `DayKeyVocabularyTests` **3/3 under `-testLanguage ar -testRegion SA`** (fresh xcresult 18:38) — this pass's new dayKey call sites hold under the hostile locale |
| Release | **BUILD SUCCEEDED, 0 errors** |
| files touched | **61**, enumerated by `find -newer` against a pass-start marker (§16) |
| protected paths | Payment · Paywall · Auth · AppPhase · Info.plist · entitlements · widgets · Edge Functions: **EMPTY** |
| @Model | **TOUCHED, DELIBERATELY** — additive optional fields only; lightweight migration **proven by opening the pass-52 store with the new binary** (§4) |
| migration | **ONE, WRITTEN NOT APPLIED**: `supabase/migrations/20260818090000_v25_p53_regimen_interval_tenure.sql` (§15, founder gate) |
| production mutations | no SQL, no deploy, no customer rows; **+1 anonymous bootstrap account** on the film sim (the §45-documented mechanism, observed again; ledger in §17) |
| P0 | **0** |

**The trap fired again and was caught again:** the final PlankFood run
reported only `** TEST SUCCEEDED **` because the background pipe kept
just the tail — the `Executed N` line was gone. Every final count in
this record was re-read from the **xcresult bundle**, not the pipe.
A second instance: the first ar_SA invocation died on
`'plankAI.xcodeproj' does not exist` (stale cwd) and the grep filter
ate the error — caught because **no new xcresult existed**; re-run from
the repo root, 3/3.

---

## 0 · OPERATING LAW COMPLIANCE

- Baseline pinned before any change: 1398 app (2 skipped) · 225 food ·
  29 sync, logs retained.
- Every changed surface was **filmed BEFORE** (6-shot before/ set) and
  after; the census was built from **source, not docs**; every
  behavioral defect carries a RED artifact or an honest "no seam"
  note (§14).
- Two **[CORR]** entries on prior passes (§13). Migrations
  distinguished WRITTEN vs APPLIED throughout. No pass-39–52 law was
  weakened; the deletion ledger, handoff, provenance, and pass-51
  truth laws are untouched by construction (their files are absent
  from the 61).

## 1 · THE CENSUS — WHAT THE RECORD COULD NOT ANSWER

Built from source: every record family, every writer, every reader.
The pattern that fell out is one defect in four costumes — **a fact
she gave once that the product could not give back**:

1. **FOOD** — the same latte typed every morning was priced fresh by
   the model every time; her corrections lived in the JSONL and
   `payload` but the words door never consulted them; a barcode she
   had already fixed re-fetched the raw OFF row; `PlateDetailSheet`
   showed "your numbers" only for worded corrections, so a portion
   edit was invisible the next day.
2. **REGIMEN** — the vocabulary was weekly · daily · as-needed.
   **No interval** (micro-dosing spreads are real: the 2025 Scripps
   cohort documents q2wk–q6wk), **no split week** (Mon+Thu), **no
   backfill** (a shot taken before Jeni existed could never be
   recorded), **no per-event dose** (the event inherited the plan's
   mg even when she took a different amount), and a late mark stamped
   `.now` as the taken time — **the record lied about WHEN**.
3. **MOVEMENT** — `MoveManualStore` sessions reached Home's strength
   tile and NOTHING else: not Becoming, not `WeeklyBodyReview`, not
   `VisitPacket`, not Jeni's `read_activity`, not Method's
   preservation input. No list, no delete — write-only, the pass-34
   shape in a fifth domain.
4. **WEIGHT** — [CORR-1] pass 51's "one weight story" was incomplete:
   `DailyBriefEngine`, `WeightJourney`, `WeeklyReview` and the packet
   still consumed the fast EMA while the seven §51 surfaces spoke the
   canonical fold. Closed (§6).

## 2 · FOOD MEMORY — VERIFY ONCE, TRUSTED FOREVER

**`FoodUsuals`** (`Packages/PlankFood/Sources/PlankFood/Pipeline/FoodUsuals.swift`),
a pure fold over her own entries — frequency-then-recency groups keyed
by `PlatePriors.normalize` (the ONE title authority), representative =
latest **verified** entry else latest:

- **The words door answers from her record first.** Typing "oat milk
  latte" when a verified usual exists logs HER latte — her portions,
  her corrections, her numbers — stamped `source: .again` (the honest
  door word; the model was not consulted). The result banner says
  **"your usual · logged 12 times · with your fixes"** with two exits:
  *count it fresh* (the model) and *use the package* (the barcode).
- **Match is exact-normalized only.** "half a turkey sandwich" never
  matches the "turkey sandwich" usual — the pass-27 law (*a prior must
  never overrule a portion the user stated*) extended to memory:
  **a qualifier is a statement, not a fuzzy match**.
- **Barcode verify-once.** A verified entry carrying `barcode-<code>`
  is re-served on re-scan in place of the raw OFF row; unverified
  history never is.
- **Every edit is a correction.** `PlateEditSession.derivedEditNotes`
  diffs the session against the arriving plate — removed items, added
  items, "×2 the scan", "your numbers" — and `editNotes` persist in
  `payload` (zero migration), travel relog/merge/emits, and render in
  the plate's YOUR NUMBERS tier next to her worded corrections.
  `wasVerified` = corrections **or** edits, so a portion fix now
  counts as verification.
- **Usuals and PlatePriors never stack** — a usual arrives with
  `priorApplied` nil by construction; the prior corrects the MODEL's
  sizing and a usual never came from the model.
- `RecentMealsSheet` ranks by the same fold; verified rows carry
  "· your numbers". `foodScanCompleted` gains `from_usual`
  (AnalyticsHygiene vocabulary extended deliberately — the DEBUG
  tripwire fired first, which is the mechanism working).

RED: the words door priced a stubbed usual fresh (the BEFORE state);
`AnsweringFoodTests` (14) pin match law, qualifier refusal, verified
representative, barcode re-serve, edit-note derivation, carry-through.

## 3 · THE GLP-1 REGIMEN — THE PLAN AND THE EVENT

**Model** (`Models.swift`, additive optionals): `RegimenPlanRecord` +=
`secondAnchorWeekday` · `intervalDays` · `anchorDayKey` ·
`treatmentStartedOn`; `DoseEventRecord` += `doseLabel`. **Plan and
event are now separate facts**: the plan says the rhythm and the
intended dose; the event says what she actually did, when, at what
amount.

**Engine** (`MedicationScheduleEngine`): a `Cadence` authority
(weekly · twiceWeekly · everyN · daily · asNeeded) with ONE
`cadenceWord()` every surface and every envelope speaks.
**The interval chain is event-anchored**: dues re-anchor on resolved
slots (taken → takenDay+N, skipped → slotDay+N, unresolved → the grid
walks), `anchor = max(effective, due)` so a late shot pushes the next
one — which is how people actually take these drugs. Late window for
intervals = +N days; `cyclePosition` scales its bands proportionally
(`edge = ceil(2·length/7)`, preserving the shipped 7-day 1-2/3-5/6-7);
twice-weekly gets the **min of both anchors** for next-dose.

**UI stays one sheet.** The day editor gains one quiet layer —
**A DIFFERENT RHYTHM**: *twice a week* (anchor + second day pairs) and
*every few days* (a 2–90 stepper + "when's your next shot?" writing
the anchor). `RegimenSheet` speaks the rhythm truthfully ("every 10
days", "mondays + thursdays"). **The backfill**: "+ add a past shot" →
the last 14 unrecorded days as chips → each opens **the same
`DoseSheet` every slot uses** — no second editor exists.

**The late face tells the truth about WHEN**: "took it just now" ·
"yesterday" · "on saturday, forgot to log" — the chosen day at her
usual hour becomes `takenAt`, so a backfilled Saturday shot re-anchors
Saturday+N, not today+N. **The dose word**: "different amount this
time?" writes `doseLabel` on the EVENT (taken preserves-on-nil;
skipped/missed clear); the ledger row prefers the event's word over
the plan's. Reminders: weekly anchors get a second repeating trigger;
intervals get a **one-shot at the computed next dose**, re-armed on
launch/marks/mutations/time-change.

RED artifact retained (`red_regimen.log`): the stubbed BEFORE state —
**15 methods, 17 failures**; `AnsweringRegimenTests` (28) pin the
chain replay, re-anchoring, normalization (`SelfRegimenSpec
.normalized()` — choosing a rhythm CLEARS the other family's fields),
version-create carry, care-team refusal, label preservation, civil-day
parsing, and the guard rail.

## 4 · THE STORE MIGRATION — PROVEN, NOT ASSUMED

This is the first pass since `1710180` to touch a `@Model` file, so
the proof pass 32 said to check first was owed: **additive optionals
only, init-set nil** → lightweight migration. Proven on the film sim:
the new binary opened the pass-52 store and **Home, food, plans and
weigh-ins all read back** (films retained:
`migration_home_after.png`, `migration_regimen_after.png`). One scare
recorded honestly: the QA sim's regimen row "disappeared" after
install — root-caused to that sim's **anon-auth uid rotation** (the
repo's documented walker limitation), NOT the schema; a reseed under
the fresh uid read back clean (`migration_regimen_reseed.png`).

## 5 · THE WIRE — WRITTEN, DEFERRED GRACEFULLY

`SyncService` DTOs carry `second_anchor_weekday` · `interval_days` ·
`anchor_date` · `treatment_started_on` · `dose_label` both directions
(care-team hydrate adopts `treatment_started_on` present-only, the §51
`hydrateUser` law). The migration is **WRITTEN NOT APPLIED**
(`20260818090000_v25_p53_regimen_interval_tenure.sql` — five additive
columns + comments, including the `schedule_rule` vocabulary note).
**Pre-migration behavior, stated precisely:** synthesized Codable
encodes optionals via `encodeIfPresent`, so a customer who never sets
an interval/tenure/dose-word sends **no new keys and syncs exactly as
today**; one who does gets a PostgREST unknown-column refusal → the
upsert **fails-and-retries** (`pendingUpsert` stays true, the §45
structural reporter names it once/day), nothing is lost locally, and
the row lands on the first launch after the founder applies the
migration. No new PlankSync tests were added: the fields ride the
package's existing DTO shapes; the app-layer suites pin the
spec→record→facts carry. **A live server round-trip is NOT PROVEN and
cannot be until the migration is applied** — named, not claimed.

## 6 · WEIGHT — ONE FOLD, FINISHED

[CORR-1] on pass 51 (§1). `BodyStateService` now publishes
`canonicalTrendSeries` + `emaDelta7dKg` + `trendEstablished` from
`WeightWeekReadEngine`; `DailyBriefEngine`, `WeightJourney`
(`from(trend:)`), both `WeeklyReview` slice sites (earliest-of-day)
and `VisitPacket.weightDirectionWord` (easing · steady · climbing,
from the canonical band) all read it. The fast α=2/8 EMA survives
**ONLY** as the band-trigger's internal fold — its safety thresholds
are calibrated to it — which is the §51-documented exception, now with
exactly one consumer. `previousWeighInKg` excludes the sign-up
self-report and requires two real rows; Home's `recentWeighIns`
excludes onboarding. Re-pins: `BodyStateServiceTests` (+1),
`WeightJourneyTests` fixtures onto `TrendPoint` — deliberate re-pins
of deliberate changes, never weakened assertions.

## 7 · MOVEMENT — RECORDED ONCE, COUNTED EVERYWHERE

`MethodInputBuilder.strengthLast7` = HealthKit + `MoveManualStore`;
`preservationStrength(everRequested:healthKit:entered:)` returns nil
only when NO source exists. Becoming's movement tile counts both and
says its provenance honestly ("apple health + your entries" /
"recorded by you"); `WeeklyBodyReview` and `VisitPacket`
(`strengthSessions7`, publisher carries it) count both; Jeni's
`read_activity` answers `strength_sessions_7d` and
`strength_recorded_by_hand_7d`. **The list**: MoveSheet's "RECORDED BY
YOU" section in all three auth faces — kind · minutes · day word ·
remove. A hand-recorded session is now a first-class record row, not
a tally.

## 8 · TENURE — MONTH FOUR IS NOT DAY FOUR

`treatmentStartedOn` is a civil date at month resolution ("roughly is
fine"), editable from the regimen sheet's **"on it since"** door
(month + year wheels, "keep it" / "clear it"), care-team plans refuse
the edit, version-create carries it. `treatmentMonths(startedOn:)`
feeds Jeni (`treatment_months`) and the packet's
`tenureLine` — **"month 4 of treatment, by her account"** — always
attributed, never inferred from the Jeni day. The distinction the
product used to blur (program day 12, drug month 9) is now two facts
with two names.

## 9 · CYCLE — THE SMALLEST TRUE VERSION

Research verdict (§12): the one physiologic claim strong enough to
ship is **menses-onset water retention** (White 2011, the TriCalm
cohort's ~0.5–1 kg transient); luteal appetite shift is real but
inter-individually wild → hedged copy only; prediction/fertility
inference is out of scope by law. Found while wiring:
**`CycleService.bootstrap()` had zero callers** — the Info.plist
purpose string promised "cycle timing" for a service that never ran.
Wired at launch. `CycleSignal.read` gains the stand-downs the GLP-1
population requires (drug-induced irregularity is common): a spread
>10 days across plausible gaps → nil; ≥3 starts all-implausible →
nil; luteal claims need ≥1 plausible gap of HER OWN. Brief copy
corrected: menstrual = "the scale often runs high here, and it's
water"; luteal = "for many" + hedge. The consult-sheet question
(asking new users) is a **founder call, not built**.

## 10 · METHOD — THE EVIDENCE SPINE + THE LOOP CLOSES

`EvidenceTier` (strong · reasonablePractice · arithmetic) on every
note — **"weak" is deliberately not a case**, so an unevidenced note
is unshippable by construction; a machine check pairs every evidence
line with its tier. Two record-earned notes: **16
`morning_protein_gap_v1`** (≥3 missed-floor days with thin mornings →
"31 g by noon" from HER mean shortfall) and **17
`salty_dinner_scale_v1`** (yesterday ≥2,800 mg sodium + today's
weigh-in bump ≥0.4 kg + flat trend → "it's water, the trend didn't
move") — the §51 canonical fold is what lets a note say that.
**The falsification loop**: `MethodLedger.settleFollowUps` emits
`.methodFollowUp` (noteId · outcome) when the record answers a shown
note — the JITAI finally learns whether its own advice landed.
One-note-per-day stability via `shownTodayNoteId` re-render. Priority:
salty-scale before weightJumped (the explanation outranks the alarm),
morning-gap before the generic floor note.

## 11 · JENI KNOWS WHAT SHE KNOWS

`CoachContextAssembler` + `JeniReadTools`, one authority each:
`cadenceWord` (never a raw enum), `treatment_months`,
`day_after_dose`/`isDoseDay` computed **with events** (so an interval
user's "day after" is real), plates carry `how` (door word) +
`her_numbers`, movement carries both counts, `read_food_day` answers
`your_edits`, `read_weight_trend` returns `recent` rows (the §37
"what did I weigh last Tuesday" gap), memory notes are **dated**
("told 3 days ago") so stale statements read as stale.
`MethodClinicSource.current()` keeps the clinic bundle DEBUG-only.
Re-pins: `JeniToolsTests` verbatim→dated (26, count unchanged),
`MethodEngineTests` probe switch extended.

## 12 · RESEARCH LEDGER (inputs, not vibes)

- **Interval dosing is real usage**: 2025 Scripps micro-dosing cohort
  documents q2wk–q6wk spreads; forum evidence of q10d "slow ladders".
  → the 2–90 stepper, not a preset list.
- **Per-event amount belongs on the event**: pens deliver partial
  doses; compounded users draw syringes. → `doseLabel`, never a plan
  mutation.
- **The countdown trauma is documented**: WW-era "points left"
  grammars produce the what-the-hell effect (Polivy/Herman's
  disinhibition literature; MFP forum corpus). GLP-1 users skew
  UNDER-eating, where "N left" reads as an instruction. → the
  **count-up cohort grammar**: on-medication days state what happened
  and never say "over" (§14's SE film shows the over-budget day
  silent); weight-loss days keep the remainder.
- **Donut/pie for macro split: rejected on Cleveland–McGill** — angle
  judgment is the worst-ranked elementary perceptual task, and
  part-to-whole is not her question ("can I eat this?" is
  position-along-scale). Concentric activity rings rejected: their
  semantic is close-the-ring; energy must not be a goal-to-fill for
  this cohort. → the shipped instrument stays ring (protein floor,
  the one true fill-to-goal) + linear bar (the day) + quiet rest row.
- **Cycle**: §9's verdict and stand-downs.

## 13 · CORRECTIONS TO PRIOR PASSES

- **[CORR-1]** Pass 51 "ONE WEIGHT STORY" — four consumers
  (brief/journey/weekly-review/packet) were still on the fast fold.
  Closed; the trigger fold has exactly one consumer now.
- **[CORR-2]** `HomeEvening.tomorrowIsDoseDay` compared an **Apple
  weekday (1=Sun) to an ISO anchor (1=Mon)** — the evening prep line
  fired on the wrong evening for every anchor, and never for Sunday.
  Fixed via the engine's `isDoseDay`; no seam existed for a RED (the
  computation lived in a view body — the §36 lesson, again), so the
  proof is the extracted rule's tests + the film.

## 14 · THE DESIGN PASS — FILMED, TWO CAUGHT, ONE ENTRANCE

BEFORE set (6) + AFTER set (16) + AX5 set (5) + SE set (4) + a
recorded entrance. Verified frames: the interval/split/tenure/backfill
editors, the regimen overview ("on it since · add it, if you like"),
the late face's when-chips, Move's recorded list, Home in BOTH cohort
states — including **the SE film that caught the count-up grammar
live**: an over-budget day (2,010 of 1,473 kcal) with **no "over"**
for the on-medication chapter, protein "floor met · muscle kept fed".
**Frame-caught and fixed:**
1. The backfill layer's bare "which day?" could read as the
   side-effect logger's → **"a past shot · which day?"**.
2. **AX5 broke a word in half** — `JKEmptyState`'s serif line rendered
   "movemen / t" at accessibility sizes. First fix attempt
   (`minimumScaleFactor`) **did nothing and the refilm proved it** —
   with `fixedSize(vertical:)` wrapped text always "fits", so the
   floor never engages. Real fix: the decorative line caps at
   `accessibility2` (~1.5× resting) while the action button below
   scales fully — the §48 wraps-or-scales law, now in the kit where
   the whole class lives. RED film → GREEN film retained.
Entrance: ~50 fps effective capture, contact-sheet inspected — the
sheet rises with content pre-composed, no blank frame, no flash.
Reduce Motion: the new surfaces add only kit-primitive insertions
(`JeniMotion` gates RM internally); no parallax/large-motion added —
same class as shipped surfaces, no per-surface RM film taken (stated,
not claimed).

## 15 · FOUNDER GATES

1. **Apply `supabase/migrations/20260818090000_v25_p53_regimen_interval_tenure.sql`**
   with or before releasing this build (behavior until then: §5).
2. The consult-sheet cycle question (§9) — a product call.
3. The nutrition instrument's tap-through to THE BOOK (§19) — a
   proposal, not shipped.

## 16 · THE 61 FILES

Enumerated by `find -newer pass53_start_marker` (list in the session
record). Shape: 9 PlankFood sources + 1 test file · 2 PlankSync
sources · 24 app Program/Chat/Views sources · `AnalyticsHygiene` ·
`VisitPacketPublisher` · `MedicationReminders` · `PlankAIApp` (cycle
bootstrap) · `JKFoundation` (the kit fix) · 8 test files (3 new, 5
re-pinned) · 1 UI-test file · pbxproj (test registrations) · 1
migration. **Zero** under Payment/Paywall/Auth/AppPhase/BodyScan/
widgets/Edge Functions; Info.plist and entitlements untouched.

## 17 · PRODUCTION-MUTATION LEDGER

No production SQL, no deploy, no migration applied. The film sim
(iPhone 16e) minted **one anonymous bootstrap account** on first
launch — the §45-documented mechanism, observed again; its
walker-class seed rows ride the standing QA path; no credential
exists for it; left in place per §45's precedent (a hand DML on
`auth.users` is not this pass's to make). The QA sims used the
standing QA accounts through shipped paths only.

## 18 · NAMED, NOT FIXED

- The **live wire round-trip** for the five new columns (§5) — gated
  on the founder migration.
- The two `Pass53RecordUITests` walk legs **XCTSkip** on the QA sim's
  anon-auth identity race (the repo's recorded walker limitation);
  the behavior they walk is unit-pinned; the film door
  (`--uitest-regimen-page`) films every state they could not reach.
- Travel/timezone dose planning ("I land Tuesday, shot's Wednesday").
- Sets/reps strength programming — out of scope by the simplicity law.
- Pass 51 §18's standing items (server-authoritative hydrate branches,
  `day_progress` retry, `weekly_reads` NULL handling, insert-only
  cross-device stance) — inherited, not re-litigated, still owned.
- Pass-54 candidates: waist trend · M/W/F 3-anchor rhythms · THE BOOK
  as the instrument's tap destination · SleepService reconnect door ·
  restingHR/HRV consult-sheet asks.

## 19 · THE NUTRITION INSTRUMENT (founder mid-pass ask)

The ask was a donut. The research said no (§12), and the founder's
real asks — minimal, premium, cohort-aware, informational — are
delivered by recomposition, not new geometry: protein ring (the one
honest fill-to-goal) → the day as ONE stated number with the
reference quiet and the **cohort grammar** (weight-loss: "· 1,040
left" / "· 200 over"; on-medication: count-up, "over" impossible) →
macro bar with 2 px spacers and per-gram legend → fiber/sugar/sodium
with the dv disclaimer. Filmed on 16e + SE in both cohort states.
**Proposed, not shipped:** the instrument tapping through to THE BOOK
(today's spread) as its record destination — one navigation, zero new
surfaces; and any further geometry iteration is design-review work
with the founder, not a solo call.

## 20 · G1/G2 CLOSED

Pass 51 deferred G1/G2 to this pass: the rhythm the product could not
say. **Closed**: interval rhythms (G1) and split weeks (G2) are now
plan vocabulary, editable in one quiet layer, spoken truthfully by
every surface, envelope, reminder and packet line (§3).

## 21 · IF I PAID FOR JENI TODAY, WHAT WOULD I STILL NEED ANOTHER APP OR NOTE FOR?

**Closed by this pass** (each was a note-app entry yesterday): my real
dosing rhythm · the day I actually took a late shot · the amount I
actually took · shots from before Jeni · how long I've been on the
drug · my gym sessions · my usual breakfast's real numbers · why the
app said what it said (evidence tiers + dated memory + provenance).

**Still honest answers, on purpose:** a period tracker if she wants
prediction (Jeni only reads what she's told — the law) · a lifting
programmer (sets/reps) · a nutrition-database browser for
pre-purchase micronutrient lookups · lab results and clinician
documents · travel-week dose planning. Each is either out of scope by
law or named in §18 with an owner.

**P0: 0 · the record answers back. NOT ARCHIVED, NOT UPLOADED, NOT
SUBMITTED. SAFE FOR PASS 54: YES.**
