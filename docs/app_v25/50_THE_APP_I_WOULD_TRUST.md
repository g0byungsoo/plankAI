# 50 — THE APP I WOULD TRUST

**feat/app-v2 · 2026-08-18 · RESEARCH + PRODUCT AUDIT. Zero product code
changed.** Build 32 stays prepared exactly as `48` left it. The only
tree changes this pass: `plankAIUITests/Pass50AuditUITests.swift` (five
instrumented audit walks, always-pass, screenshot/tree dumpers) and its
`pbxproj` registration — audit tooling, deliberately kept for pass 51.
Product defects found this pass are **documented with file:line, not
fixed**, because any source change would invalidate `48`'s "safe to
archive as 32" claim; they are the P0 list below.

**Evidence base.** ~4,100 current App Store reviews read across 23 apps
(via Apple's RSS endpoints, 2026-08-18), partial-but-real Reddit
harvests (r/Zepbound, r/Mounjaro, r/Ozempic, r/WegovyWeightLoss,
r/loseit), 40+ peer-reviewed citations, five read-only code audits with
file:line, three simulator screenshot tours (33 + 15 + 22 surfaces),
five instrumented UI walks on the build-32 binary, two 60fps films with
frame-level analysis, an SE pass and an AX5 pass. The nine research
extracts and the 17 cited screenshots are preserved in
`docs/app_v25/50_evidence/` (reports/ + shots/, uncommitted); the two
films (86 MB) and the raw review JSON remain in the session scratchpad
(`…/41f69602…/scratchpad/films/`, `…/reviews/`). QA runs used the QA
sims' existing anonymous accounts (no erases → no new production
accounts; `46`'s reaper covers the seeds).

---

## 1 · EXECUTIVE VERDICT

**If Jeni went to 100 ordinary paying customers tomorrow, these five
things are most likely to make them quit, mistrust it, or keep another
app beside it — in order:**

**① The first ten minutes after paying.** Purchase → forging reveal →
coach intro → breathwork primer → onramp intro → three setup pages →
Home is **12–13 screens before the first possible food log**
(`PostPurchaseFlowView.swift:10-140`, `ProgramSetupSubflow.swift:106-108`),
and the first log then runs a gauntlet: a camera-permission dialog, a
consent primer written entirely in photo copy, and a three-question
food form — **measured live: a typed first meal ("greek yogurt with
honey and a banana") hit `count it`, was shown "how jeni *reads* a
plate… what happens to the photo", then "before your *first* plate"
questions, and finally landed in the CAMERA with her sentence hidden
behind "or write it"** (filmed, `films/words.mp4`; gate-exit confirmed
at `CaptureFlowView.swift:87-130`). Industry data says 55% of
cancellations happen on day 0 and action-in-minute-one is the strongest
activation lever; this flow spends that minute on interstitials.
Nothing after the gates teaches Becoming or the jeni tab at all.

**② Records that revert or drift.** A weigh-in **typed over a
same-day Apple Health row is silently overwritten back** on the next
launch/observer import — `WeightLogWriter.persist` updates the row in
place without relabeling `source`
(`ChatToolRouter.swift:272-276` × `BodyMassImportService.swift:184-243`).
The program day **shifts ±1 on reinstall/new phone for every non-UTC
user** (`start_date` is rendered UTC-date-only, reparsed as UTC
midnight, re-anchored local — `SyncService.swift:1750,1859,2567-2572` ×
`ProgramScheduleCalculator.swift:85`). Cross-device food/dose **edits
never propagate** (insert-only merges). This is precisely the failure
class the market punishes hardest: Withings users' language shifts from
"my scale" to "my data is ruined"; Shotsy's 2026 record bugs ("July
shots redated to June") are its loudest new 1★s.

**③ The record doesn't remember her usuals well enough.** Six
recency-only recents (`FoodLogPersister.swift:921-934`), no favorites,
no saved meals, no copy-yesterday; only SPOKEN corrections feed the
priors flywheel (stepper/editor fixes write no correction —
`SnapRefine.swift:80` is the sole writer); a known-but-wrong barcode has
zero defense (`confidence: 1.0`, `BarcodeRead.swift:129-164`). The #1
cross-market job — "verify once, trusted forever; re-log life in two
seconds" — is half-met. The Glow failure quote ("I've had to start
logging it in MyFitnessPal first so I can correct it") is the exact
scenario Jeni must never produce.

**④ The GLP-1 schedule model can't hold real regimens.** Every 5 days,
every 10 days, twice-weekly, doctor-ordered split doses, per-event
strength, and pre-Jeni history are **not representable** — the engine
has exactly two live cadence arms and everything else goes silent, no
dose day, no reminder, no ledger growth
(`MedicationScheduleEngine.swift:183-191`, `Models.swift:686-690`,
`DoseEventStore.swift:19-21`). The clinician packet calls a daily
regimen "your weekly medication" and computes 0 scheduled doses for
daily users (`VisitPacket.swift:189,196-204`). The split/microdose
population is loud, growing, and currently displaced (Lilly's official
app is collapsing in public); the market leader is investing in exactly
this gap.

**⑤ The retention loop is dark and the edges are unpolished.** No
notification permission is ever requested on the shipping path (the
consult stores a preference word; the dialog lives only in Settings →
`NotificationSettingsView.swift:250`), so the notification brain stands
down for effectively all v8 payers. Meanwhile the visible edge-quality
defects — content ghosting under the floating tab bar on Home/Becoming
(3 independent shots), "your medicatio n" breaking mid-word at AX5,
the empty-state Move sheet at ~60% void — are exactly the class of
"visual glitches and awkward layout" that feeds an "AI slop" read of an
otherwise distinctive design.

**What is NOT on this list, on the evidence:** the core arithmetic
(one weight ladder, golden matrix), the wall, sync-at-rest, deletion
integrity, the medication record's daily surfaces, the words door as a
concept, the design language itself. Those hold.

---

## 2 · COMPETITIVE REVIEW RESEARCH

Full per-product detail with dated verbatim quotes in the research
extracts; this is the decision-grade summary. ~4,100 reviews read
2026-08-18; star averages in the GLP-1 category are actively gamed
(pre-use rating prompts at Pep AI/PeptidePal), so written reviews and
Reddit word-of-mouth were weighted over stars throughout.

| Competitor | Repeated praise | Repeated complaint | The underlying job | Jeni should learn | Jeni should NOT copy |
|---|---|---|---|---|---|
| **Shotsy** (4.84★/29.7k) | Injection-site memory ("'I'll remember where I injected' is a lie I tell myself"); estimated-medication-level chart (62 mentions, #1 pay reason); loss-per-dose/per-site charts (Reddit screenshot currency); free PDF export; human support | 2026 paywall creep (free features moved to Shotsy+); record bugs ("July shots redated to June", "stuck at 24 shots taken", weight attributed to wrong dose on split schedules); notes write-only; manual-only food (54 asks; "I still use MFP") | The authoritative record of the medication era, provable to self and doctor | Site memory as a map; attribution charts from her own record; export free forever | PK curves rendered as 4-decimal pharmacology (expert: "fun only, scientifically inaccurate"); paywalling anything retroactively |
| **MeAgain** (4.79★/29.1k) | Protein/fiber/water-FIRST dashboard ("the protein and the fiber are running the show"; "grow your numbers" vs WW countdown trauma); capybara-pet retention; shot-day ritual checklist; pill fasting timer | Aug-2026 redesign backlash ("losing the shot countdown… feels like a generic calorie tracker. It can trigger disordered eating"); DB inaccuracy (tuna 16g vs can's 20g; corrections don't stick); login/data-loss cycle; hidden pricing; selling meds burned trust | The daily GLP-1 behavior coach: eat enough while the drug kills appetite | Count-UP floors as the lead instruments; the shot countdown as home-screen anchor | Server-side UI flips of the daily ritual screen; touching the ritual = instant 1★ wave; selling the drug |
| **Lilly Health** (official; 70/150 recent = 1★) | (when working) free, label-accurate, savings-card adjacency | v3.0 wiped data ("my year of weight loss and medication tracking"); wrong arithmetic ("321.8−263.0 reported as 53.1"); no injection sites; no export; reminders fire on the OLD day after a shot-day change | A logbook that must simply not lie or lose | Displaced users are shopping RIGHT NOW and name what they want: working food log, sites, export, correct math | Regulatory footers covering the weight chart; ads for the drug she already takes |
| **MyFitnessPal** (2.35M; recent window 77×1★ vs 32×5★) | Database breadth incl. restaurants; recipe builder; years of personal history | Aug-2026 redesign broke per-meal grams (now %); barcode still paywalled (weekly 1★s since 2022); wrong "verified" entries; ads mid-logging; confetti ("I'm tracking calories, not ringing in the new year") | See the whole day at a glance; per-meal grams; re-log yesterday in seconds; never lose a decade of history | 10–20-year users are actively defecting; their stated wants are Jeni's existing laws | Feature repossession; monetizing the cheapest gesture; AI-branded features (1★s for the word alone) |
| **Lose It!** (4.77★/772k) | Fastest re-log in class (My Foods/meals/copy); scan→verify-once→trusted-forever loop; human support | 2026: barcode+macros moved behind premium (MFP's fatal move, repeated beat-for-beat); GLP-1 drug ads shown to LIFETIME members; perf decay on its own history; discouraging weight math (graph vs all-time low) | Verify once, then trust forever | The verify-once loop; warmth in tone | Ads to payers; retroactive paywalls; shame-shaped graphs |
| **Cronometer** (4.77★/96k) | Curated-database accuracy as identity ("I rarely need to correct anything!"); free barcode as THE switch trigger; label-submission → curation loop | Full-screen unskippable video ads AT the logging moment ("the only way to get into my diary is airplane mode"); whole foods buried under branded results; no offline | The number must be right and traceable; unknown food must have a path into truth | The label→curation anti-dead-end; accuracy as brand | Interrupting the logging corridor for revenue |
| **MacroFactor** (4.84★/21k, cleanest sentiment) | Expenditure from her own weigh-in trend; adherence-neutral ("no guilt… it keeps giving valid targets"); gram-first entry; editable DB entries; AI describe accepted at ~80-90% | DB quality (#1: raw-rice-as-cooked); paywall-after-onboarding; **targets spiral too low for women ("5'7 150lb female → 1234 kcal… my hair started falling out")**; **menstrual-cycle blindness — luteal water retention read as fat gain → cuts calories exactly when adherence is hardest ("clearly built for men not women")** | Trust the TARGET, computed from my own body | Adherence-neutrality; transparent energy model; editable truth. **Cycle-awareness is the single clearest unclaimed women-specific gap in the entire dataset** | Zero-floor adaptive targets; setup-before-first-log |
| **FoodNoms** (4.74★/7.5k) | "Forget it's not a first-party app"; the label scanner ("the only tracker that can actually read a nutrition label"); privacy-as-product; calorie RANGES not hard budgets | DB breadth ceiling; free→paid reclassification backlash; a month of broken scanning "got me out of the habit — the habit is the product"; uneditable AI scans → cancellations; false "you didn't log yesterday" notification | Feel native, feel private, my data portable | Ranges as honesty; label door as signature; trial-end reminders as trust | Reclassifying free features; breaking the habit loop even briefly |
| **Cal AI** (4.80★/357k; 76 of 193 written 2025+ = 1★) | One-gesture speed ("This is the new way. It's Magic"); streak-driven GLP-1 users (140-day logging streak) | Quiz-then-ambush paywall (25+); entitlement rot while PAID (20+, robot support); legible absurdities (apple = 360 kcal/14g protein); **corrections don't stick** ("fix this" renamed but didn't reprice; custom servings silently revert); $0.99 streak ransom; 682-kcal recommendation to a 145-lb woman; 3.2M-record breach via open Firebase | Make logging cost one gesture; give a number I can obey | Speed bar = sub-10s gesture→reading; that the correction moat is OPEN — nobody closed the loop | Everything else: data-before-wall, streak ransoms, judgment ("a very poor choice"), fake precision, hunger-nag notifications |
| **SnapCalorie** | Cleanest trust profile of the AI apps: LiDAR portions + USDA grounding + generous free tier + photo-with-note/voice + "one high-quality result rather than 101 variations"; dietitian-recommended; provider email reports | Web-sourced items uneditable; flags unanswered; premium nags | "I want to believe the number" | AI identifies + verified DB prices + honest totals wins trust; context-with-photo | — |
| **Glow (Endo Health)** | AI-coach accountability ("I can confide without feeling judged") | Food logging broken and **"it doesn't learn from it. I've had to start logging in MyFitnessPal first so I can correct it in the Glow app"**; the AI can talk but not act ("the chat bot said it can't change my actual plan"); user can't edit either | A confidant that can also DO | Jeni's tool loop (read/remember/propose) is the moat Glow lacks — an AI that can act on the record | Coach-only apps with broken records; aggressive shake-only meal plans |
| **Happy Scale** (4.89★/57.7k) | Trend smoothing as emotional technology ("Before this app, every fluctuation felt like failure"; "I would DREAD stepping on the scale… now EXCITED"); milestones splitting 30 lb into six wins; self-correcting predictions; gains quarantined to the chart | Monetization shift on an existing record (sync/history/notes went paid → 1★ storm); lb↔kg flips on its own; data loss on device upgrade; two-weigh-ins/day unsupported; goal arrival "anticlimactic" | Make the daily number safe so the daily ritual survives | Milestones + prophecy-from-her-own-data; never scold; **record continuity is sacred — never re-charge for it** | Subscriptionizing yesterday's free record |
| **Noom** (4.70★/870k) | Lessons valued while novel ("feels like they're reading your mind") | Lesson fatigue ("an annoyance when you just want to log"); unskippable celebration blocking the weigh-in ("You now must sit through a countdown"); med-funnel ads ("caused me to cancel"); coach decay (canned, 24-48h) | The log is the daily job; the lesson is a sidecar | Education must never stand between her and the record; Noom vacated the no-drug-sales trust position — hold it | 52-week curricula; forced gamification; selling GLP-1s through the coach voice |
| **WW (GLP-1 mode)** | Protein/veg/water floors officially replace Points for GLP-1 users | Feb-2026 redesign split log from totals ("I'm trying to lose weight, not solve a brain teaser"); Med+ bolted on; barcode drift | A century-brand's own data says floors-not-points for this cohort | The floors thesis is now industry consensus — Jeni already leads here | Points nostalgia; bolt-on clinic UX |
| **GlucoPal / Glapp / clones** | GlucoPal: custom intervals PRAISED ("shots every few days instead of weekly"); Glapp: supply/click-count arithmetic, trial-cohort benchmark ("the ONLY reason I'm still using") | Glapp: blurred users' OWN history behind a new paywall → instant trust collapse; local-only storage = data loss; clones: can't log <1 serving, same dish = 3 different scans | Interval flexibility; supply math; "am I normal?" against a reference population | Custom intervals are a shopping criterion; benchmark-against-trials is loved | Holding her history hostage; local-only framed as privacy |

**Cross-market synthesis — the ten jobs a 2026 food/GLP-1 record must
nail** (each traced to 3+ independent sources): ① re-log life in two
seconds and never break the repeat path (people eat the same ~20 foods;
the app is a memory, not a search engine) ② the number must be right
with visible provenance (every user workaround is a resignation) ③
kill serving-size arithmetic — her stated portion always wins (the
GLP-1 "half-portion problem" hides protein adequacy) ④ barcode free
forever; unknown barcode is never a dead end ⑤ corrections are sacred
writes: reprice now, survive relog/sync/reinstall, inform the next scan
⑥ never repossess a free feature ⑦ the gesture→reading corridor is
protected (no ads, no confetti, no upsell) ⑧ adherence-neutral,
gram-visible, judgment-free ⑨ a transparent energy model that respects
the actual body — **cycle-awareness is unclaimed by every major
tracker** ⑩ infrastructure integrity: 2-way sync, offline, perf at
years of history, free export.

---

## 3 · CORE RELIABILITY MATRIX

Scored 0–10 against the DISCOVER/ENTER/EDIT/DELETE/UNDO/HISTORY/REPEAT/
CUSTOMIZE/SYNC/RESTORE/OFFLINE/TIMEZONE/UNITS/A11Y/SE/LARGE-TYPE/JENI/
CLINICIAN/FAILURE-STATE rubric. Nothing above 8 without direct
simulator/code proof; every deduction is a named defect in §4.

| Domain | Score | Basis (proof) | What holds it back (the §4 defects) |
|---|---|---|---|
| **FOOD** | **7.0** | One stamping chokepoint + one provenance vocabulary (`FoodCaptureDispatcher.swift:102-106`); 3-tap repeat WITH corrections carried (walked live); printed truth never hedged; ladder counts up for packages; delete + tombstones + resurrection sweep proven in `38`; 14-day re-dating; THE BOOK protein-first (shot) | First-run gauntlet swallows a words entry (filmed); 6 recency-only recents, no favorites/meals; only spoken corrections feed priors; micros drop on edit; NULL source hydrates as "photo"; no per-entry timezone; wrong-known barcode undefended; food-photos bucket absent while consent copy promises photo survival |
| **WEIGHT** | **7.0** | One resolution ladder for all arithmetic (`TargetsService.swift:98-108`); the ledger lists/corrects/removes any day with provenance + day-law times (shot); tombstones by row AND day; import rules manual-wins/update-in-place/insert-unless-tombstone (`BodyMassImportService.swift:177-191`); ruler + type-it-instead (walked) | `persist` doesn't relabel source → typed-over-Health silently reverted (P1); two EMA engines over two row sets can disagree; VisitPacket includes the onboarding row all consumer reads exclude and picks latest-of-day vs the engine's earliest; tz-travel can resurrect a cleared day; `?? 65` kg ruler seed |
| **GLP-1** | **7.0** | Dose sheet with site memory + note + skip reasons (shot); the doses ledger with titration history + tap-any-row-to-fix (shot); symptoms 14 kinds × 3 severities × 14-day back + synced delete; version chains supersede-never-mutate; wall-clock DST-safe engine; care-team authority + refusals; "only you see this" privacy lines | Weekly-or-daily only — N-day/twice-weekly/split/per-event-mg unrepresentable and SILENT; no medication start date (months-in user reads as day-one); no backfill; takenAt not editable (late log skews cycle anchor); packet says "weekly" for daily + counts 0; dayKey POSIX pin missing in one producer |
| **PROGRAM** | **6.5** | Exactly one user-facing day formula, all surfaces derive (`ProgramScheduleCalculator.swift:83-114` + audit sweep); at-goal maintenance semantics work (`EnergyBasis` arrival, `· holding`); onramp gate closed by live-plan @Query | Reinstall/new-device ±1 day for non-UTC users (P1); graduation designed-but-unmounted — "day 120 of 119" renders forever, `phase="completed"` has zero writers vs three doc contracts; EngagementDayCalculator's stale "source of truth" header + second `programDay` column semantics |
| **APPLE HEALTH** | **6.5** | Import decision function is best-in-class (pure, tombstone-aware, manual-wins); purpose strings cover every requested type; ONE opt-in write (dietary energy, `wasUserEntered`, no retro-delete); steps/weight observers + background delivery | Resting HR requested on the consult sheet with an on-screen promise and rendered NOWHERE; menstrualFlow requested but `CycleService.bootstrap()` has zero callers — the season can never speak; HRV/leanBodyMass consumed but not on the main sheet; sleep's own ask unreachable; ~11 serial HK queries every cold start; no anchored queries |
| **MOVEMENT** | **6.0** | 3-tap manual entry (walked); measured-or-absent energy law (matches the compensatory-eating evidence exactly); yoga negative control pinned; "add what health missed" framing; never calories-earned | Manual sessions invisible to every engine (the Method can scold a user who recorded strength); double-counts watch+hand same session; entries can never be listed or deleted (`MoveManualStore.delete` zero callers); strength never reaches the coach; empty-state sheet ~60% void at `.large` |
| **BODY** | **7.0** | Words-never-numbers enforced in the engine; 3% noise floor; fuller-never-scolded; fixed-window era gate; local-first + EXIF-stripped + backup-off-default + disable-deletes-cloud; consent copy matches implementation (rare); ~1s capture (code + shot) | Becoming's waist tile skips the era gate the flow enforces; clothing never taught/controlled; week-over-week change sensitivity unvalidated (industry-wide); "confidence" word is a branch flag; stale RPC-purge comment |
| **JENI (coach)** | **6.5** | Reads the real record via the same engines (8 read tools); refuses prescriptions/memory of doses; desk proof line works with data ("4 plates and 123 g of protein, on file" — shot); corrections reach her (`your_corrections`) | Desk ~50% void with data; strength/manual movement invisible to her; memory device-local (listed as durable in Settings); `read_weight_trend` can disagree with Becoming's drawn line (two smoothers); cadence word would misreport an as-needed plan |

**Program-day single-answer verdict:** within one installed device,
YES — one formula, all surfaces. Across devices/reinstalls, NO until
the UTC round-trip is fixed. **One-weight-story verdict:** the
arithmetic has one ladder (proven); the DISPLAY layer still has two
smoothers and inconsistent onboarding-row filtering — one story to a
customer, potentially two sentences at the margin.

---

## 4 · THE BORING CORE — exact defects, by domain

Every item cites working-tree file:line; none are fixed this pass (see
header). ★ = new finding of this pass (not in any prior record).

**FOOD**
- ★ **F1 (P1)** First-ever log gauntlet: consent primer + food
  questions stack in front of the first record; both gates exit to the
  CAMERA even for a words entry; her typed sentence survives only as a
  hidden prefill (`CaptureFlowView.swift:87-99,116-130`; filmed).
  Consent copy is photo-only ("what happens to the photo") over a typed
  sentence; it also says small copies live "in your private cloud
  space so it survives a new phone" while `food-photos` deliberately
  does not exist (`FoodPhotoSyncService.swift:51-83`) — a promise the
  pipeline cannot currently keep.
- ★ **F2 (P1)** Micros drop on ANY edit: `PlateEditSession`'s three
  copy helpers re-init `CapturedItem` without `micros:`
  (`SnapResultMath.swift:293-391`) → a stepped item on a grounded plate
  yields a silent PARTIAL micros sum — the exact defect `namedMicros`
  exists to prevent (`SnapResultView.swift:903-930`). Fifth instance of
  the defaulted-init field-drop family.
- ★ **F3 (P2)** Hydrate decodes NULL `source` as `"photo"`
  (`SyncService.swift:2320`) — invented attribution on read; the
  write-side law says absent→`unknown` (`CapturedFood.swift:430-438`).
- ★ **F4 (P2)** Correction provenance is spoken-only: stepper/editor
  fixes fire analytics but write no `corrections`
  (`SnapRefine.swift:80` sole writer) → a hand-corrected dish never
  becomes a prior and relogs as `corrected:false`.
- **F5 (P2)** Repeat memory = 6 recency-deduped titles
  (`FoodLogPersister.swift:921-934`); a 7th dish evicts breakfast; the
  book fallback is 5+ taps.
- ★ **F6 (P2)** No per-entry timezone: day attribution derived at read
  time everywhere (`FoodLogPersister.swift:610-868`) — travel silently
  re-attributes past days on every reader.
- **F7 (P3)** Known-but-wrong barcode: OFF data lands at
  `confidence: 1.0` with no drift check (`BarcodeRead.swift:129-164`).
- ★ **F8 (P3)** Stale TTL doc comment ("14d") on a lifetime store
  (`FoodLogPersister.swift:874`); food-row upsert has no retry queue
  (launch diff is the net — acceptable, but name it).

**WEIGHT**
- ★ **W1 (P1)** `WeightLogWriter.persist` updates today's row in place
  without relabeling `source` → a Health-sourced row keeps
  `"healthkit"` and the next import overwrites her typed number
  (`ChatToolRouter.swift:272-276`; importer update rule
  `BodyMassImportService.swift:236-243`). The one-line law already
  exists on the correction path (`WeightLedger.swift:228`).
- ★ **W2 (P2)** Two trend engines: `WeightTrendChart.computeEMA` (α=2/8,
  includes onboarding rows) vs `WeightWeekReadEngine` (τ=9.5d, excludes
  them) — Becoming's line and jeni's spoken direction can disagree
  (`WeightEMA.swift:22-67` vs `WeightWeekRead.swift:55-135`).
- ★ **W3 (P2)** VisitPacket weight includes the onboarding self-report
  all eight consumer reads exclude, and reduces a multi-row day to
  LATEST while the engine's law is earliest-of-day
  (`VisitPacket.swift:233-273`).
- ★ **W4 (P3)** Timezone travel: weightday tombstones + import buckets
  are both local-tz-at-call-time → a cleared day can resurrect across a
  tz change; one physical weigh-in can duplicate onto a neighbor day.
- ★ **W5 (P3)** `TodayModuleHost.swift:287` seeds the ruler at
  `?? 65` kg, bypassing the ladder's onboarding rung pre-hydrate.
- ★ **W6 (nit)** Unsorted `existingByDay` makes manual-wins
  order-dependent when a day holds two rows; three different kg
  plausibility ranges across writers; stale "thirty-day" comments (code
  is 90).

**GLP-1**
- **G1 (P1, strategic)** No N-day interval, no multi-anchor week, no
  split dose, no per-event mg, no therapy start date, no history
  backfill (`Models.swift:686-690,806-872`;
  `MedicationScheduleEngine.swift:126,183-191`;
  `RegimenService.swift:170-186`). Failure mode is total silence.
- ★ **G2 (P2)** `VisitPacket.swift:189` renders "your weekly
  medication" for daily regimens; adherence loop counts 0 scheduled for
  daily cadence (`:196-204`).
- ★ **G3 (P3)** `TodayStateService.dayKey` (`:172-177`) lacks the
  POSIX-locale pin its sibling producers carry — slot ids could diverge
  on non-Latin-numeral locales.
- ★ **G4 (P3)** A late LOG stamps `takenAt` at tap time and it is never
  editable → the cycle anchor can sit a day off the true injection
  (`DoseSheet.swift:493-510`).
- **G5 (P3)** Symptom free-text notes never sync and are listed
  nowhere (`SyncService.swift:846-867`); dose-event hydrate is
  insert-only so cross-device edits don't propagate (`:1708-1719`).

**PROGRAM**
- ★ **P1 (P1)** `start_date` UTC round-trip shifts the program day ±1
  on reinstall/handoff for non-UTC users
  (`SyncService.swift:1750,1859,2567-2572`).
- ★ **P2 (P2)** Graduation dead end: `ChapterCompleteView` has no mount
  site; `phase="completed"` has zero writers against three doc
  contracts; Home can read "day 120 of 119" forever
  (`ProgramService.swift:147-185`, `HomeView.swift:645`).
- **P3 (P3)** `EngagementDayCalculator`'s header still claims
  single-source-of-truth; `DayProgressRecord.programDay` carries a
  second semantic (`EngagementDayCalculator.swift:5-7,77-82`).

**APPLE HEALTH**
- ★ **H1 (P2)** Resting heart rate: requested on the LIVE consult sheet
  with on-screen copy "the recovery signal", read, rendered nowhere
  (`V8Structured.swift:178,279`; `VitalsService.swift:123-131,206-220`
  zero consumers). Render it or stop asking.
- ★ **H2 (P2)** menstrualFlow requested while `CycleService.bootstrap()`
  has ZERO callers → `periodStarts` permanently empty; the brief/coach
  season can never speak (`TodayStateService.swift:468`,
  `CoachContextAssembler.swift:95`). Wire it or unrequest it — and
  note the cycle is the market's #1 unclaimed women-specific need.
- ★ **H3 (P3)** HRV + leanBodyMass consumed but absent from the consult
  sheet; sleep's only dedicated ask is DEBUG-unreachable; ~11 serial HK
  queries per cold start, no anchored queries anywhere.

**MOVEMENT** — ★ M1 (P2) manual sessions invisible to every engine
(Method note 11 can scold a strength-recorder;
`MethodInputBuilder.swift:139`); ★ M2 (P3) `MoveManualStore.delete`
zero callers, no list UI — a recorded session can never be viewed or
removed; M3 (P3) watch+hand double-count (sum at
`MoveRecord.swift:106`).

**METHOD / EDUCATION** — ★ E1 (P2) the falsification loop is dormant:
`MethodLedger.settleFollowUps` has zero callers; `method_follow_up`
never fires (`MethodLedger.swift:118-172`). ★ E2 (P3) note 14's
documented adequacy-net QUIET is not enforced
(`MethodEngine.swift:272-277`); catalog header says "Thirteen notes"
(15).

**RETENTION** — ★ R1 (P1) no notification permission ask exists on the
shipping path; the consult stores a preference word; every scheduler
stands down unauthorized (`NotificationOrchestrator.swift:51`,
`NotificationSettingsView.swift:250` the only ask).

**DESIGN EDGES** (see §14) — ★ D1 tab-bar content ghosting (3 shots);
★ D2 "your medicatio n" AX5 mid-word break; ★ D3 first-log gauntlet
copy mismatch; D4 desk void with data; D5 Move empty-state void; ★ D6
ruler tick label rendered "1675" (needs a zoomed verification pass —
flagged, not proven).

---

## 5 · THE FIRST 10 MINUTES

**What exists today (walked on the build-32 binary):** purchase →
forging reveal (8s) → coach intro → breathwork primer (skippable) →
onramp intro (no skip) → goal-date reveal → intensity pick →
commitment → Home. 12–13 screens; no notification permission moment;
no introduction of Becoming or the jeni tab; the first log then pays
the F1 gauntlet. The one great screen in this path is the onramp gate
itself — "your plan is here. / 159 lb → 143 lb / EACH DAY: protein 85 g
your floor · food ~1,546 kcal an estimate · movement 7,500 steps
offered never owed" — which is exactly the "restate what she bought in
her numbers" bridge the activation evidence demands. The empty states
already teach ("2 more weigh-ins and your trend line starts.").

**The evidence bar** (full extract in research): tours fail (7-step
completion 16%); action-steps correlate with activation (+123%); aha
≤5 min ≈ +40% 30-day retention; 55% of cancellations are day-0; the
canonical post-paywall failure is "I still don't know what the app
actually looks like" (RevenueCat's Noom teardown); Whoop's gray-score
calibration contract and Headspace's answered-first-session are the
positive patterns; corrections must be taught AT the first result
(Cal AI's unsticky corrections teach users to stop correcting).

**The design (pass 52's brief, not built now):**

1. **Keep** forging + coach intro, but the coach intro's one beat ends
   in a HANDOFF SENTENCE: "say your last meal and i'll count it — a
   sentence is enough." The first real action is armed before Home is
   ever seen.
2. **The first record in minute one.** Land on Home with the words
   field ALREADY focused (one-time state), her plan's floor as the
   standing line. She types a sentence; the reading answers with
   protein-first numbers and the plate answer sentence. The camera is
   offered, never required, for log #1.
3. **Consent moves inside the first estimate, door-aware.** One screen,
   copy matched to the door she used ("your words go to the vision
   service to be counted" vs the photo copy), the photo teachings
   deferred to the first CAMERA use. The "before your first plate"
   questions move to AFTER the first reading, framed as an offer
   ("want jeni to read your plates better? three soft questions"),
   never between her and record #1. Her sentence always survives.
4. **Teach the fix at the first reading.** The first result carries a
   one-time affordance line under the numbers: "off? fix it with words
   — your correction is remembered." That single sentence converts the
   correction moat into a first-session lesson.
5. **The day-one contract.** After the first record files, one card
   states what pays out tomorrow: "come back in the morning — the
   morning read is built from what you gave me today." (The
   DailyBriefEngine already pays this out; it is currently never
   promised.) THIS is the notification permission moment: "want the
   morning read as a quiet note?" → the system ask, contextual,
   pre-qualified. For GLP-1 users, the shot reminder is the second
   contextual ask. R1 closes as a product moment, not a dialog at
   launch.
6. **Becoming and jeni get one line each, in place** — the tab's first
   visit shows its own one-sentence empty-state teaching (Becoming
   already has this; jeni's desk gets "ask me anything about your
   record — i can read it"). No tour, no tooltips, no checklist before
   value. An endowed 3-item "your first week" checklist MAY live on
   Home after day 1 (log once ✓ pre-checked · weigh once · see your
   week) — after value, never before.

**Measured target:** purchase → first filed record in **under 3
minutes and ≤6 screens** (today: 12–13 screens plus the gauntlet);
first correction taught in session 1; notification grant ≥60% via the
contract moment (vs ~0% today on the v8 path).

---

## 6 · FOOD — the ideal record architecture

**What the audit proves already excellent (leave alone):** one
dispatcher chokepoint stamping one `EntryMethod` vocabulary; provenance
lines owned by the door type; printed truth never hedged; PlateShare
counting UP for packages; her stated portion outranking priors (the
words-door exclusion is load-bearing and correct); scope-guarded
fix-with-words; the 3-tap again path carrying corrections; tombstoned
deletes surviving hydrate; the reading's protected corridor (no ads, no
confetti — the market's #7 job, already law).

**The architecture gap, named precisely:** Jeni has world-class
provenance at CAPTURE and loses half of it at PERSIST and REPEAT.
Per-item `NutritionSource` dies at persist (only the door survives);
manual edits are invisible (F4); the personal food graph is 6 recents.
The market's verdict is unambiguous: the moat is **"verify once,
trusted forever" + "corrections are sacred writes."**

**The target model (pass 51/53 material):**

1. **Provenance survives persist.** `itemsDetail` gains
   `nutritionSource` per item and an `edited` flag; the plate detail
   can then say "estimated · you adjusted the portion" honestly
   forever. Fixes F3's class at the root (absent → `unknown`, never
   `photo`).
2. **Every deliberate edit is a correction.** Stepper/editor/fraction
   commits write a structured correction ("portion → 2 servings",
   "kcal → 410") into the same `corrections` channel the spoken fix
   uses — reprice now, persist, inform the next scan. One rule:
   anything she changed on purpose is remembered on purpose. (Spoken
   corrections stay the only PRIOR source for portion-scaling; edits
   feed identity/values only — preserving the words-door law.)
3. **HER USUALS — the personal food graph.** Promote the 6-recent rail
   to a small owned model: `usuals` = title-keyed entries with her
   corrected numbers, provenance, and a use-count; ranked
   frequency-then-recency; pinnable; 2 taps from the chooser; carried
   by the existing payload jsonb (no schema). "Again" becomes "again ·
   your usuals." The GLP-1 cohort eats repetitively — this is the
   second week's front door.
4. **Unknown/wrong barcode never dead-ends.** Unknown already
   auto-morphs to label (excellent — keep). Wrong-known gets the
   MacroFactor edit loop: "not what the package says? fix it — yours
   wins here on out" writing a barcode-keyed usual. An
   impossible-entry check (|kcal − Atwater(macros)| > 25%) flags any
   door's result with "these numbers disagree with each other — worth
   a look" (the physics clamp already computes this; it just never
   speaks).
5. **Time becomes a fact.** `loggedAt` gains a stored `tzOffset` (or
   dayKey stamped at persist); day attribution stops being re-derived
   per reader (F6). The 14-day re-dating law stands.
6. **Micros honesty:** F2's three copy helpers carry `micros:` through
   (the PlatePriors sibling already documents the reason).
7. **The photo pipeline's promise matches reality:** either the
   `food-photos` bucket ships behind the corrected purge (the `44`
   ordering), or the consent copy stops promising cloud photo
   survival. Never promise what the queue quietly retries.

**Interaction model (photo → barcode → label → words → correction →
repeat)** stays exactly the current door set — the doors are right.
The measured bar: any door ≤10s gesture-to-reading (words round-trip
was blocked by gates in this audit, not by the pipeline — re-measure in
51); repeat ≤3 taps (proven today); correction ≤2 gestures from the
reading (proven); the same breakfast tomorrow = 2 taps via usuals.

---

## 7 · GLP-1 — the minimum complete record

**Today's model is excellent for the 7-day mainstream and structurally
silent for everyone else (G1).** The evidence says the everyone-else is
large, vocal, and shopping: split-dosing on doctor's orders, every-5/
10-day intervals, microdosing with custom mg, compound users thinking
in units, pill users with fasting windows, and "started eight months
ago" adopters whose tenure the model cannot hold.

**REQUIRED (the minimum complete record):**
- Products + custom dose (exists) · site memory (exists) · taken/
  skipped/late with reasons (exists) · past-row correction (exists) ·
  symptoms with severity + day + delete (exists) · era chain with
  reasons (exists) · pause/stop/restart (exists).
- **Interval as data, not vocabulary**: `intervalDays` (1, 3.5→ twice
  weekly as two anchors, 5, 7, 10, 14) + optional second anchor. Every
  7-day assumption in §2's inventory (`CyclePosition length`, late
  window, read anchor, `dosesExpected`) reads the interval instead of
  the constant. The cycle read generalizes to day-N-of-M.
- **`treatmentStartedAt`** — one nullable fact, editable, backfillable
  ("started before jeni? when, roughly?" month precision), powering
  tenure ("month 4"), the packet, and honest era language. RegimenPlan
  `startedAt` stays "when jeni learned."
- **Per-event mg override** (nullable; defaults to the version's
  strength) — makes split dosing and one-off half-doses representable
  without breaking the deterministic id (slot id gains an optional
  `-b` suffix ONLY when a second same-day event exists).
**DEFAULT (on, invisible until relevant):** late/missed derivation;
cycle intelligence; foodNoiseReturn; VisitPacket. **OPTIONAL:** units⇄mg
translator for compound users (display-layer only); supply counting
(pens on hand ↔ next refill — Glapp's loved arithmetic; a P3).
**CUSTOM (explicitly never):** PK concentration curves (the expert
record calls them fun-only; Jeni's honesty position is HER OWN pattern
— `foodNoiseReturn` is already the honest version of what PK charts
pretend to do); medication advice of any kind; concentration-timed
injection coaching.

Packet fixes ride along: cadence word from the actual rule, scheduled
counts from the interval, severity stays out (G2).

---

## 8 · WEIGHT + APPLE HEALTH — one source of truth

**The design is already one-ladder-for-arithmetic (proven), and the
remaining work is four seams, not a redesign:**

1. **W1** — `persist` adopts the correction path's one-line law:
   updating today's row relabels `source` per
   `WeightLedger.sourceAfterCorrection` (manual wins its day at the
   daily chokepoint too). This closes the typed-then-reverted loop —
   the single worst trust defect found this pass.
2. **One smoother.** `WeightWeekReadEngine` (τ-aware, onboarding-
   excluding, unit-error-rejecting) becomes the only trend authority;
   `WeightTrendChart.computeEMA` reads from it or dies. Becoming's
   line, jeni's sentence, the notification band, and InsightEngine then
   cannot disagree. VisitPacket adopts the same series (earliest-of-day,
   no onboarding row) — W3.
3. **Day identity.** Weigh-in dayKeys stamp at write with the writer's
   tz (as dose/symptom already do); the weightday tombstone matches on
   that stored key — closes W4's resurrection.
4. **Import edge cases** (documented, low-sev): sort `existingByDay`
   deterministically; drop the unused `calendar` param or honor it;
   unify the three kg plausibility ranges into one constant; fix the
   two stale "thirty-day" comments; seed the ruler from the ladder,
   never `?? 65`.

**Edge-case census discovered (for `51`'s tests):** same-day
manual+Health (single device: prevented; two devices: possible —
ledger renders honestly); two Health sources same day (importer takes
latest sample per day — scale-vs-phone conflicts collapse correctly);
DST fall-back day (engine uses `bySettingHour` — safe); travel west
across midnight (program day rolls back; self-consistent); reinstall
(±1 day, P1 above); `"apple_health"` source documented but never
written (delete from the doc contract).

**HealthKit posture:** request only what renders. Render resting HR
(one line in the weekly body review: "recovery held its baseline") or
remove it from the consult sheet; wire `CycleService.bootstrap()`
behind an opt-in (see §12 — the cycle is also the market's #1 unclaimed
women's need) or stop requesting menstrualFlow; move HRV/leanBodyMass
onto the consult sheet or accept they're union-sheet-only and say so in
the moment. Batch the launch probes behind one task group; adopt
anchored queries for steps/weight (11 serial cold-start queries today).

---

## 9 · MOVEMENT — keep, simplified; manual becomes visible

**Verdict: KEEP auto-import as the record, KEEP the 2-field manual door
as the fallback, and stop hiding manual entries from the brain.**
Evidence: passive activity monitoring is the only self-monitoring whose
adherence doesn't decay (93.6% stable vs food's decline); exercise
self-monitoring has the weakest outcome evidence of the three
behaviors (one study in the foundational review) — movement is context
the app READS, not a demanded logging behavior; device calorie error is
27–93% and compensation eats half the predicted deficit, so
"calories earned" stays banned (current law, evidence-aligned);
resistance training is the one GLP-1-specific exercise claim with
2024-25 systematic-review support, and its honest unit is
sessions-per-week against a 2–3 floor — exactly Home's current tile.

The changes that pay rent: **manual sessions count everywhere**
(BodyState.movement merges `MoveManualStore` so the Method, weekly
body review, Becoming tile, and the coach see them — M1; a user who
recorded strength must never be told "nothing is asking your muscles
to stay"); **a session can be seen and removed** (list + delete —
M2; the record's own laws demand it); dedup stays framing-only ("add
what health missed") — acceptable with visible provenance. The
128-animation workout library: no action this pass; its recorded
retirement trigger (`workout_start` vs `move_activity_recorded`) is
the right instrument — read it after 60 days of production data and
delete or keep on the number.

---

## 10 · WATER — DON'T BUILD (the tracker); keep the symptom-scoped notes

**Evidence:** pooled RCTs of premeal water in overweight/obese adults:
−0.33 kg, NOT significant; the mechanism demonstrably fails in young
adults (works in 55–75s); 8×8 has no scientific basis (IOM: thirst
suffices; total water includes food); user demand inside weight apps
reads as obligation ("There is absolutely no reason to log your
water"); water reminders would spend the hard ≤5/week notification
budget on the weakest-evidence behavior in the product. GLP-1-specific
hydration relevance is REAL but symptom-scoped (label AKI warning via
GI fluid loss; sips/fluids-before-fiber guidance) — which is exactly
what already ships: the titration `.water` beat with no number
("sips through the day, not all at once"), care-team ml rendered
attributed, and Method notes 14/15. **The current state is the
evidence-correct product.** Two nits to fold into 51: enforce note
14's documented adequacy-net QUIET (E2), and either write
`ObservationKind.hydration` from the queasy-day action or stop naming
"hydration" in the care consent copy.

---

## 11 · BODY SNAP — verdict: **KEEP** (it already is the honest
product), plus one evidence-backed addition; never a number

Choosing from KEEP / REBUILD / REPURPOSE / REMOVE: **KEEP.**

**A. Capture reliable?** Yes — MirrorGate fires on ~1s of steadiness,
thumb-as-shutter, fixed window; the ZOZOFIT complaint class ("stand 6
feet away… 40 minutes") does not apply. **B. Comparison reliable?**
Structurally yes (fixed window, ink-vs-ink, 3% noise floor, era gate) —
with two real holes: clothing is never taught, and Becoming's tile
skips the era gate the flow enforces. **C. Scientifically meaningful?**
As WORDS over weeks, yes; as numbers, no — and it never emits one.
Photo-BF% validation is company-authored with ±5-point individual
limits and week-over-week change inside instrument noise; Jeni's
refusal is the correct read of the literature. **D/E. Implies vs
measures:** copy matches the math (rare in this market); "your waist"
is a soft over-claim for a fixed mid-frame window. **F. Behavior
change?** NOT PROVEN anywhere in the literature (progress-photo
adherence claims trace to trainer marketing); body-checking harm IS
proven, concentrated in at-risk young women — Jeni's demographic — and
the dose is FREQUENCY, so the weekly cap is the load-bearing safety
feature, not the copy. **G. Clinician?** No (and none of the provider
platforms surface photos). **H. Privacy cost justified?** Yes as
built: local-first, EXIF-stripped, backup off, disable-deletes-cloud.
**I. Simpler ritual more honest?** The shipped silhouette ritual IS
the simpler honest thing. **J. Waist more useful?** YES — and this is
the addition: **an optional self-taped waist trend.** Waist
circumference is the one guideline-anointed non-scale body metric
(IAS/ICCR: a "vital sign", reductions a "critically important
treatment target"), a formal endpoint in SELECT/SURMOUNT, self-measured
within 1–3 cm (ICC 0.97), answers the exact plateau moment users praise
body scans for ("loses inches, not scale weight"), needs no ML and no
photos. A `waist` observation + ledger + Becoming line ("your waist,
week to week — from your tape") beside the scan.

Repairs riding along: the tile's era gate (Becoming must refuse the
comparison the flow refuses); one clothing sentence in the capture
teaching ("same clothes, or none — fabric moves the read"); leave
cadence weekly.

---

## 12 · JENI METHOD — the replacement already exists; scale it and
delete the corpus

The founder's hypothesis ("the right idea at the right moment") is
**already shipped in embryo**: `MethodNote` — 15 state-triggered,
cooldown-governed, authority-aware, silence-first cards, one per day,
each with a trigger from her record, one idea, one action, and an
attributed evidence line (verified on screen: "3 of your last 5 logged
days came in under 90 g" + "2025 lean-mass guidance for glp-1 therapy:
1.2 to 1.6 g/kg"). The JITAI literature (Koh 2025, verified: 35
studies; education is only 14% of what working JITAIs deliver; effects
ride prompts+feedback tied to own data) supports exactly this form —
honestly: **no head-to-head JITAI-vs-curriculum trial exists**; the
decisive argument is reach (an 84-lesson curriculum against a median
2-active-day payer delivers ~2% of itself; the note system delivers on
the day the trigger is true).

**What to build (pass 53):**
1. **The evidence spine**: add `evidenceTier` (S/RP/W — W never ships),
   required `attribution` for RP, and machine-checked `neverClaim`
   lists to the card model; enforce in tests like the banned-word
   sweeps.
2. **Wire the falsification loop** — `settleFollowUps` at launch +
   `method_follow_up` events (E1). A JITAI that never settles its
   pre-registered outcomes is a vibe, not an instrument.
3. **Scale 15 → ~30 cards from the ranked trigger table** (research
   extract): water-weight after a salty logged dinner (S, daily-class);
   protein-why (shipped); logging-gap consistency (S-assoc);
   strength-for-lean-mass NEJM (S); dose-day GI eating (RP,
   attributed); fiber+fluid ramp; eat-enough-when-appetite-is-gone
   (RP, suppressed under the safety gate); plateau truth (S — "drift,
   not a stalled metabolism"); cycle water-retention (S/RP — REQUIRES
   §8's CycleService wiring, opt-in); trend-not-day for rising
   scale-check frequency; steps-vs-her-own-usual; sleep-intake RCT
   (data-gated); habit 10-weeks; stopping-language → regain data +
   clinician conversation (hard neverClaim wall).
4. **Delete the corpus** (§20): the 84-lesson manifest, RepEngine/
   RepView, JeniMethodReReadView, jm_hero assets — production-
   unreachable today; the founder's 30.25 MB sweep from `48` subsumes
   most of it.
Excluded on evidence, permanently: metabolism-boosting foods, water
targets, cortisol-fat narratives, detox framing, "21 days".

---

## 13 · B2B READINESS — what today's record could already tell a
clinician

**The frame (from guidelines + provider-platform research):** an AOM
follow-up decides four things — titrate/hold/switch, manage
tolerability, protect nutrition + lean mass, escalate red flags.
Cadence is monthly→quarterly; the summary's unit is THE INTERVAL,
never the day. Clinicians' own words: "more clicks are cumbersome";
noise is punished, thresholds are wanted.

**Jeni's record already holds ranks 1–3 and 5–9 of the clinically
useful list with NO new collection:** dose ledger with dates/status/
sites (rank 2 — `DoseEventRecord` is exactly the x-axis clinicians
titrate against); weight trajectory computable as %/week with
provenance (rank 1 — flag against the published bands: adequate
≥0.5%/wk, excessive >1.5 kg/wk); GI symptom burden with severity,
days-affected, and post-dose clustering (rank 3 — VisitPacket's
timing-not-causation law is already correct); protein floor
days-met-of-days-logged (rank 5 — the floor exists; report adherence
to it, never calorie tables); strength sessions/week vs the 2–3 floor
(rank 7); appetite/food-noise in her own words (rank 8 —
`foodNoiseReturn` is precisely this); injection-site rotation
exception (rank 9).

**What it cannot responsibly say (and must not):** daily calories
(self-report under-reports 17–38% — actively misleading for
titration); step streams; mood charts (event-flag only); estimated
medication levels; any composite score or triage word. Red-flag
symptoms are surfaced RAW with routing language, never interpreted —
and "none recorded" is itself information.

**Gaps before a clinician sees anything:** G2's cadence lie ("your
weekly medication" on a daily plan), W3's onboarding-row inclusion and
latest-vs-earliest day pick, tenure (no `treatmentStartedAt` — a
packet cannot yet say "month 4"), and the interval model for
adherence counting. Consent stays the existing visit-packet scope; the
compliance-coercion trust landmine from the research (insurance-
mandated tracking is HATED) means the summary must always read as
HER document she chooses to hand over — never telemetry.

---

## 14 · DESIGN AUDIT

Method: 70 screenshots across three tours (iPhone 16, SE 3rd-gen, AX5
type), five instrumented walks, and two 60fps films with frame
extraction (`films/tabs.mp4`, `films/words.mp4`). Verdict first: **this
product does not look like AI slop.** The type system (serif numerals,
one background, ink-on-paper), the instrument composition, and the
copy discipline are distinctive and consistently executed; the
Becoming entrance cascade was checked frame-by-frame at 60fps — a
staggered fade/draw over ~1.5s with zero pops, zero post-arrival
reflow. The "slop" perception risk lives in a small set of EDGE
defects, all fixable without redesign.

**Defects (ranked):**
1. **Content ghosts under the floating tab bar** — Home ("TO…" of
   TOOLS clipped; body-scan row half-occluded), Becoming (sodium row
   cut mid-glyph, ledger text visible THROUGH the translucent pill).
   Three independent shots. The scroll content needs a bottom
   safe-inset + a paper fade above the bar (the launch already has
   this pattern under the status bar).
2. **AX5 title break** — "your medicatio / n" wraps mid-word on the
   regimen home. Needs a layout that lets the serif title wrap on the
   word or scale down. (Home, chooser, weigh-ins, dose sheet all
   survive AX5 cleanly — this is the one break found.)
3. **The first-log gauntlet reads wrong** (§5): photo-consent copy over
   a typed sentence; two interstitials before record #1; the sentence
   lands hidden in the camera. This is a sequencing defect that
   PRESENTS as a design defect.
4. **The desk's dead middle** — with data, the jeni tab is ~50% void
   between the starters and the composer (measured on seeded shots).
   One quiet element earns the space: the last exchange's closing
   line, or the day's one number ("today: 61 g of 85"). Not more
   starters.
5. **Move sheet empty state at `.large`** — ~60% void under two rows.
   Either `.medium` detent when empty, or let the week strip render
   its empty circles as structure.
6. **Ruler tick label "1675"** on the weigh-in ruler (165–168 lb
   window) — one frame shows a major tick labeled without its decimal
   point. Flagged NOT PROVEN (single frame, small size); verify at
   full-res in 51 before filing.
7. Minor: the "again" chip in the chooser clips its third suggestion
   off-screen (horizontal scroll affordance is fine; the cut looks
   accidental at 393pt); seeded QA plates render abstract blobs that
   make THE BOOK look like a mockup in QA reviews (QA-only, not
   customer-visible).

**What passed inspection (name it so nobody "fixes" it):** the wall
(chart → tiers → one-page plan summary reads clean, honest renewal
copy); the onramp gate (the plan restated in her numbers with the
EACH-DAY ledger — the best screen in the post-purchase path); the
chooser (record-made-of-doors with the standing protein line); the
dose sheet + regimen home + doses ledger (calm, factual, private);
your weigh-ins (day-law times, provenance words, the footer stating
what the freshest number does); the symptom sheet ("nothing here
grades you"); Becoming with data (the 2×2 instrument tiles + rows);
SE — everything audited fits at 375pt with the same one bar-collision
defect; the app-launch zoom (cream sheet, no white flash, filmed).

**Sheets vs destinations (the founder's question):** the audit
supports promoting exactly TWO children to full-screen destinations —
THE BOOK (it is "the food record", a place she lives, currently an X-ed
sheet) and the weigh-ins ledger when entered from Becoming's "your
record" (same reasoning). Everything else audited (dose sheet, symptom
sheet, again sheet, plan numbers, goal ritual) is correctly a sheet: a
single decision made over the page she was on. Full-screen-by-default
would cost more than it buys; the two record rooms are the exception
because they are rooms, not decisions.

---

## 15 · SIMPLICITY AUDIT — remove, hide, stop asking

- **STOP ASKING: resting heart rate** on the consult sheet (promised
  "the recovery signal", rendered nowhere) — or render one line.
  Every unrendered permission is trust spent for nothing.
- **STOP ASKING (or wire): menstrualFlow** — currently requested with
  zero readers reachable.
- **STOP ASKING TWICE: the food questions** — "before your first
  plate" duplicates consult territory (cuisine mix exists in
  onboarding vocabulary); if kept, it moves behind the first reading
  as an offer (§5).
- **HIDE: the guided-session door** for users with zero workout_start
  events after week 1 (its own retirement trigger will decide its
  existence; until then it need not sit on the Move sheet for
  everyone).
- **REMOVE (code, founder-gated sweep — §20):** the unreachable
  education/onboarding residue. It costs 30+ MB, three false doc
  contracts, and audit time every pass.
- **STOP SAYING: "hydration"** in the care consent copy until
  something writes it; **"survives a new phone"** in the camera
  purpose string until the bucket exists; **"single source of truth"**
  in `EngagementDayCalculator`'s header.
- **DON'T ADD (asked-for but refused on evidence):** a water tracker
  (§10); streaks/badges/points (the market's own data: streak ransoms
  and forced celebration generate 1★s; MacroFactor's quiet streak is
  the ceiling of acceptable); a social feed (ED vector at Lose It,
  ad-swamp at MFP); mood/hunger daily questionnaires (clinician noise,
  user fatigue); a PK concentration chart (§7); photo body-fat
  numbers (§11); a recipe discovery library; medication-purchase
  funnels of any kind (Noom/MeAgain burned exactly this trust — being
  the app that does NOT sell the drug is a moat).
- **KEEP SMALL:** the manual movement door (2 fields is right);
  symptom vocabulary (14 words is right; the ask for bowel-movement
  logging is already served by "backed up" — give it a severity, not
  a new system).

---

## 16 · TOP 25 COMPETITOR PAINS (frequency × severity × fit for Jeni)

1. Corrections that don't stick / AI re-guesses known foods (Cal AI,
   Glow, MeAgain, Foodvisor) — the open moat; Jeni is closest.
2. Wrong database entries wearing "verified" checkmarks (MFP, Lose It,
   MacroFactor) — provenance + verify-once is the answer.
3. Data loss / failed restore on new phone or update (Lilly, MeAgain,
   GlucoPal, Pep AI, DreamMe, Happy Scale) — durable account sync is
   table stakes; "local-only" reads as data loss.
4. Retroactive paywalls on the user's own history (Glapp blur-out,
   Shotsy creep, Lose It barcode, MFP barcode, Happy Scale sync) — the
   single fastest loyalist→evangelist-against converter.
5. Serving-size arithmetic / can't log a fraction (MFP decimals,
   SnapCal <1 serving, GLP-1 half-portions) — PlateShare already
   leads; finish with usuals.
6. Redesigns that break the daily ritual (MFP Aug-26, MeAgain Aug-26,
   WW Feb-26, Lilly v3) — change the ritual screen last, slowest.
7. Ads/upsell inside the logging corridor (Cronometer video ads, MFP,
   Lose It Ozempic ads to lifetime members).
8. Paywall-after-data-entry / hidden pricing (Cal AI, MeAgain,
   Glowise, MacroFactor) — Jeni's wall is pre-product; keep it honest.
9. Wrong derived math destroying record authority (Lilly's 53.1 vs
   58.8; Lose It home-screen totals) — Jeni's golden matrix protects
   this; extend to the packet (G2/W3).
10. Custom dose schedules unloggable (Shotsy split-dose, PeptidePal
    intervals) — §7.
11. Entitlement rot: paid users locked out with robot support (Cal AI,
    Glow, MFP).
12. Per-meal grams hidden or percent-ified (MFP) — Jeni renders grams;
    never regress.
13. No injection-site memory (Lilly) / site data loved (Shotsy) —
    Jeni ships it; keep it visible.
14. Targets that spiral below safety for women (MacroFactor 1,234
    kcal; Cal AI 682) — Jeni's floors + safety gate are the
    counter-position; never let an adaptive engine undercut them.
15. Menstrual-cycle blindness in energy interpretation (MacroFactor,
    everyone) — unclaimed; Jeni half-plumbed (H2).
16. Judgment/grading of foods ("very poor choice", red days,
    F-grades) — Jeni's report-never-grade law is the answer; hold it.
17. Streak ransoms and forced celebration in front of the record
    (Cal AI $0.99 restore, Noom seeds, Foodvisor 5 screens).
18. Notifications that nag hunger or shame gaps (Cal AI, FoodNoms
    false "you didn't log") — the ≤5/week budget + never-scold law is
    correct; it just needs permission to exist (R1).
19. No export / export paywalled (Lilly, Glapp) — exports serve PA
    renewals and doctor visits; keep free forever.
20. Sick-day logging has no graceful degrade (r/Ozempic: "most
    sources seem designed for perfect meal prep days") — the words
    door + symptom pills are the degrade path; make them the sick-day
    default.
21. Maintenance/off-ramp users orphaned (Shotsy maintenance mode is
    NEW; WW regain diary "like a failure") — arrival semantics exist;
    graduation is unmounted (P2).
22. Two-source weight chaos (Withings duplicates/wrong-person) — day
    rules + tombstones exist; W1 closes the last loop.
23. Slow search / perf decay on own history (Lose It, Cronometer) —
    JSONL + indexes fine today; watch at years-of-history scale.
24. Barcode regional gaps → dead ends (FoodNoms, Cronometer 7-Eleven)
    — label door + words door cover; never dead-end.
25. AI-branded features resented per se (MFP "Remove AI", BitePal
    anti-AI toggle) — Jeni's never-say-AI law is validated; hold it.

## 17 · TOP 10 DELIGHTS COMPETITORS EARN (worth matching in Jeni's voice)

1. Happy Scale's trend line as permission to weigh daily ("takes away
   the feeling of my day being derailed") — Jeni has the engine;
   §19-P2 gives it the morning sentence.
2. Happy Scale's milestones: six 5-lb wins instead of one 30-lb
   mountain, each celebrated once, gains quarantined to the chart.
3. Shotsy's site-memory map ("no more guessing") — shipped; keep
   loud.
4. Shotsy's loss-per-dose chart — the community's screenshot currency;
   Jeni's era ledger + weight series can draw it honestly.
5. MacroFactor's adherence-neutral targets ("no guilt, no guesswork…
   keeps giving valid targets") — Jeni's register already matches;
   never add red.
6. Cal AI's one-gesture speed ("This is the new way. It's Magic") —
   the words door IS this; unblock it from the gauntlet.
7. SnapCalorie's photo-with-note ("you can put in context for the
   picture") — dispatcher supports text+photo; surface it as "add a
   word to the photo".
8. FoodNoms' label scanner as signature ("the only tracker that can
   actually read a nutrition label") — Jeni's label door + EF
   label-hint are close; the §27 EF deploy finishes it.
9. MeAgain's shot-day ritual checklist ("shot sandwiched with protein
   helped my nausea") — CarePlanEngine already leads dose days; one
   prep line on dose morning completes the ritual.
10. Glapp's trial-benchmark ("compare my progress against study
    participants — the ONLY reason I'm still using it") — Jeni can
    render STEP/SURMOUNT loss bands as context ("trials saw 10–15% by
    month 6") with attribution and zero promise — powerful for "am I
    normal?", compliance-checked copy required.

---

## 18 · THE WHITESPACE

Why should Jeni exist when MyFitnessPal + Shotsy + Apple Health
already do? Because that stack is the disease: three apps, none
talking, each holding a third of her story, and the community's own
words name the wound — "I'm logging my specs onto all three apps. Am I
just setting myself up for confusion?"; "What I want is to consolidate
all these data into one app"; "Most apps feel like generic weight-loss
trackers with a 'medication' field slapped on… None of them actually
help you understand your patterns over time." The incumbents cannot
close this: MFP is monetizing gestures and shedding twenty-year users;
Shotsy is a shot ledger that will never hold food; Noom converted its
coach into a drug funnel; Lilly's own app loses the record it exists
to keep; and none of them will adopt corrections-that-stick,
provenance-on-every-number, or cycle-aware interpretation, because
their engagement models monetize exactly the noise Jeni deletes. **The
position Jeni should own: THE RECORD THAT ANSWERS — the one place the
whole journey (plates, weight, doses, feelings, program) is recorded
in seconds, corrected once, remembered forever, explained back in her
own numbers, and — with her consent — translated faithfully for her
clinician.** Everything in this pass reduces to that sentence: the
whitespace is not a feature, it is a standard of record-keeping that
competitors would have to rebuild their businesses to match.

---

## 19 · ROADMAP

**P0 — TRUST (the record must not lie): pass 51.**
Each: problem → evidence → smallest fix → NOT build → risk → proof.
1. **W1 typed-over-Health reversion** → audit §4 → relabel source at
   the persist chokepoint (one line + the existing law) → not a sync
   rewrite → low risk → RED test: type over a Health day, run import,
   number holds.
2. **P1 program-day round trip** → audit §4 → serialize `start_date`
   as a LOCAL calendar date (or re-anchor via stored tz) with a
   migration-free read fallback → do NOT touch plan identity/merge →
   medium (touches hydrate) → fixture: SF-minted plan hydrated in
   Tokyo reads the same day 3×.
3. **F2 micros-on-edit + F3 NULL→"photo"** → food audit → carry
   `micros:` in three copy helpers; decode absent source as `unknown`
   → don't persist micros (unchanged law) → low → existing
   PlankFoodTests pattern, RED first.
4. **R1 the notification moment** → walk + code audit → the day-one
   contract ask (§5.5) wiring the EXISTING orchestrator; nothing new
   scheduled → do NOT blanket-ask at launch → low → grant-rate event +
   morning-read delivery count.
5. **G2/W3 packet honesty** → audits → cadence word from the rule;
   scheduled-count from cadence; weight series = engine series minus
   onboarding row, earliest-of-day → don't redesign the packet → low →
   packet fixture tests.
6. **D1 tab-bar occlusion + D2 AX5 title + F1's smallest cut** (the
   consent primer copy becomes door-aware and the typed sentence
   survives the gate — the full resequencing is pass 52) → shots →
   bottom inset + fade; wrap-or-scale the title; carry prefill through
   the gate exit → don't rebuild the gates yet → low → re-shoot the
   three frames + AX5 sweep.
7. **Food-photos honesty** → F1/F8 → EITHER ship bucket behind the
   corrected purge (the `44` ordering, founder-gated) OR trim the
   purpose-string promise → never create the bucket before the purge →
   founder decision recorded either way.

**P1 — FRICTION (the record costs seconds): pass 51/52.**
– HER USUALS (§6.3: frequency-ranked, pinnable, corrections-carrying;
  2-tap repeat) — evidence: repeat loop is the #1 market job. NOT a
  recipe system.
– Every-edit-is-a-correction (§6.2) + impossible-entry line (§6.4).
– Wrong-known-barcode verify-once loop (§6.4).
– Interval model + treatmentStartedAt + per-event mg (§7) — unlocks
  the displaced population; NOT concurrent multi-med stacks (v2).
– First-10-minutes resequencing (§5) — pass 52's core.
– Manual movement visibility + list/delete (§9).
**P2 — UNDERSTANDING (the record explains): pass 53.**
– Education cards scale-out on the evidence spine + settleFollowUps
  wiring (§12).
– Cycle plumbing (H2) + the cycle water-retention card — opt-in, the
  market's clearest unclaimed women-specific need.
– One smoother (W2) + the morning trend sentence (Happy Scale's job:
  "the line is down 0.4 this week; today's number is just weather").
– Jeni sees strength + manual movement (M1's envelope half).
**P3 — DELIGHT (the record rewards):**
– Milestones in the Becoming voice (six small arrivals; gains never
  invade); loss-per-dose attribution view from her own eras; trial
  reference bands (compliance-reviewed); export polish (the one-pager
  IS the export).
**P4 — B2B (the record travels):**
– The interval summary one-pager (§13 spec) behind the existing
  visit-packet consent; then the `47`-sequenced isolation contract and
  `care_weekly_summaries` FK remain the platform prerequisites (per
  `46`); tenure + interval model are its data dependencies (§7).

**Explicit sequencing law carried from the audits:** client before
migration (three passes proved it); nothing in P0 requires schema; the
interval model (P1) is the first item that touches `@Model` files —
it gets its own RED→GREEN store-migration proof when it lands.

---

## 20 · DELETE LIST

Founder-gated sweep, sized by `48` at 30.25 MB of the 76 MB catalog,
plus this pass's additions — all verified production-unreachable in
the working tree:
- Legacy v4.5 `OnboardingView` (9,645 lines) + its 18 exclusive assets
  + `bodytype-0…5` (≈30.25 MB total, `48`'s measurement).
- The 84-lesson CBT corpus: `manifest_v1.json` (402 KB) + `RepEngine`/
  `RepView` (zero call sites) + 42 `jm_hero_*` imagesets (17 MB) —
  after removing the two DEBUG doors that mount them.
- `JeniMethodReReadView` + `go(.jeniMethod)` (zero callers).
- `EditProfileView` (superseded by `your numbers`; `36`'s finding).
- `StepsBentoTile`, `StepsService.hourlyBreakdown`, `EnergyLedger
  .spentKcal/isLighterDay`, `stepsGoalHit`/`stepsViewedHome` events,
  `healthKitStepsRequested` flag (write-only).
- `FoodCapture.quickAdd` (.notImplemented) + `.imOutTonight` arm (no
  callers; keep the stored-value decoder).
- `supplementPlans` resolver (no feature), `ObservationKind.hydration`
  (no writers — or wire it), `"apple_health"` from the source-vocab
  doc comment.
- Server side (already named in prior passes, restated for the list):
  `public.coach_messages` (no client), `users.program_status/
  program_intensity_tier/program_goal_date` (zero writers/readers,
  false contracts) — deprecate then drop, founder-gated.
- The workout library (128 Lotties, 7.3 MB): NOT deleted — its
  recorded retirement trigger decides after production data; the
  delete list notes it as the next candidate with a number attached.
- Comment-truth sweep (free): the four stale comments named in §4
  (RPC-purge claim, 30-day importer, 14d TTL, "single source of
  truth", "Thirteen notes").

---

## 21 · NEXT THREE PASSES

**PASS 51 — THE RECORD MUST NOT LIE (boring core).** Scope: §19-P0
items 1–7 + the P1 friction items that are pure client record-work
(usuals, edit-as-correction, impossible-entry line, barcode
verify-once, manual-movement visibility). RED→GREEN per fix; the
golden matrix + upgrade fixtures re-run; re-shoot the three defect
frames; no schema, no deploy. Exit: every §4 P1/P2 in FOOD/WEIGHT/
PROGRAM/RETENTION closed or explicitly deferred with a reason.

**PASS 52 — THE FIRST DAY (activation).** Scope: §5 end-to-end —
coach-intro handoff sentence, first-record-in-minute-one, door-aware
consent inside the first estimate, questions moved behind the first
reading, fix-taught-at-first-result, the day-one contract +
notification moment, one-line tab introductions, purchase→record ≤6
screens. Instrumented by the activation events named in §5; the
reviewer-journey walker extended to walk the new path. No paywall
changes, no consult changes above the wall.

**PASS 53 — THE ANSWERING RECORD (intelligence).** Scope: §12's
education spine (evidence tiers + settled follow-ups + ~15 new cards),
§7's interval/tenure model (the one @Model change, with its own
store-migration proof), cycle plumbing + the cycle card (opt-in), one
smoother + the morning trend sentence, jeni's envelope gains strength/
manual movement + usuals. Exit: the JITAI loop measures itself
(settled follow-ups reporting), and a split-dose/5-day user can hold
her real regimen in the record.

— end of pass 50 —
