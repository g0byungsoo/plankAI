# PASS 54 — THE JENI METHOD

**Built 2026-08-19, on feat/app-v2, after pass 53 (THE ANSWERING RECORD).
Nothing archived, uploaded or submitted. `CURRENT_PROJECT_VERSION` stays 33
(the standing convention: the bump belongs to the archive that supersedes,
as 51 did for 32→33 — passes 52 and 53 changed product code under the same
convention).**

The brief's question: *if Jeni knows what is actually happening to her, what
is the most useful thing Jeni can say or do next?* The answer this pass
built: the Method is now the interpretation layer over the record — twenty
notes, each triggered by HER data, each carrying a machine-checked evidence
tier, each with a follow-up the weekly read now reports back — and the
84-lesson course it replaced is finally *gone*, not merely unreachable.

The rest of this record answers the brief's 34 questions in order.

---

## 1. What was the old Jeni Method?

Three strata, two of them dead weight:

- **The 84-day CBT curriculum** — `manifest_v1.json` (401,845 B), 42
  `jm_hero_*` imagesets (17.6 MB), `Reader/` (18 files including 3 Metal
  shaders), `RepEngine`, `CBTCurriculumService/Scheduler/Types`,
  `LessonManifest`, `LessonAnchor`. Day-indexed lessons on a base whose
  median payer lives 2.0 active days — lessons 3–84 unreachable by
  construction. E8.1 (2026-08-11) replaced its *delivery* with MethodNotes
  but left every file bundled. Pass 37 removed its launch-time decode;
  pass 48 measured its assets; nobody deleted it.
- **The 14-lesson DietEducation corpus** (94,490 B of Swift:
  `JeniMethodRitual(+View)`, `JeniMethodReReadView`, `JeniMethodContent`,
  `JeniMethodAnalytics`, `JeniMethodSafetyLine`) — `go(.jeniMethod)` has had
  zero callers since pass 34 recorded it; the only mounts were DEBUG doors.
- **The living part**: `MethodEngine` + `MethodCatalog` — at pass 53's close,
  17 notes (E8.1's 13 + E9's 2 + p53's 2), a JITAI reading her record,
  returning at most one note a day or silence.

## 2. What was wrong with it?

Eleven defects, all verified first-hand before fixing, all RED→GREEN where a
test could exist (13 failures across 76 in the first RED run;
`red_method.xcresult` retained):

- **M1 (P1)** — `lateInDoseWeek` fired for interval (every-N-day) users
  *mid-cycle*: the input builder mapped any non-daily regimen to "weekly"
  and the engine hardcoded days `5...7`. A q10d user heard "day 6 of your
  dose week. often the hungry end of it" on day 6 of 10 — false twice —
  and heard nothing on days 8–10, the true waning end. Pass 53 built
  `CyclePosition` for exactly this and the Method never consulted it.
  **Fixed: the gate is `CyclePosition.band == .waning`** (edge =
  ⌈2·length/7⌉, the engine's own arithmetic), the copy speaks
  `cycle_word` ("your dose week" / "your 10-day rhythm"), and the weekly
  window moved from the Method-local 5–7 to the engine band's 6–7 — one
  authority, one vocabulary. twiceWeekly returns no cycle → the note is
  silent for splits by construction.
- **M2 (P2)** — four notes made external claims in their `because` lines
  while tiered `.arithmetic` with `evidence: nil` (the 7,700-kcal constant
  ×2, a PK trough claim, "second most common side effect"). Fixed:
  re-tiered, evidence lines added, and a **claim-marker sweep test** now
  fails any `because` that names external science without a non-arithmetic
  tier and an evidence line.
- **M4 (P2)** — the follow-up loop was invisible to her:
  `settleFollowUps` fed analytics only. Fixed in the weekly read (§17
  below).
- **M5** — no test that `priority` covers every trigger (an unlisted
  trigger silently never fires). Pinned: priority == all cases exactly once,
  full order asserted.
- **M6 (P2)** — a care-team note didn't pin the day (`shownTodayNoteId`
  filtered `!fromCareTeam`), so Jeni could speak twice. Fixed: the clinic
  pins the day.
- **M7 (P2)** — `HomeView.methodStatus()` read `entries.last` of a
  newest-first list: the tile showed the *oldest* note forever after day 2.
  Fixed (`MethodLedger.latestEntry()` = `.first`), with the inverted comment
  corrected.
- **M8 (P1, cross-account)** — `method.ledger.v1` was in NO sign-out sweep:
  the next account on the phone inherited the told-list (trigger names are
  health-state descriptors) and the cooldowns. Fixed: the key joined
  `AppSync`'s sweep — the §38 lesson, again, in a family added after the
  sweep was written.
- **M9 (P2)** — the protein pattern window included *today*, so a
  half-logged morning counted as an under-floor day. Fixed: offset 0
  excluded (the morning-gap builder already did this deliberately).
- **M10** — the version fields were inert: every note said `v1` across two
  passes of rewrites. Fixed with a **content-fingerprint tripwire**
  (FNV-1a over the note's copy): rewriting a note without bumping its
  version now fails a test. All notes rewritten this pass carry `v2`;
  catalog `version = 2`.
- **M3 (P3)** — the catalog header claimed "Thirteen notes" over seventeen.
  Header is count-free now (the count lives in the tier-table test).
- Dead inputs `plateCountToday`/`emaKg` removed; `evidence_tier` now rides
  `method_note_shown` (AnalyticsHygiene vocabulary extended: `s`/`rp`/`a`).

## 3. What did competitors teach us?

Six products read through their own users' negative reviews (agent-run
census; killer quotes verified):

- **Noom** — "yes, I know this. Yup, yup, yup", "canned responses":
  a curriculum is wallpaper by week two. The refusal of a lesson library is
  a review-derived law, not taste.
- **Omada** — "daily rhetorical questions instead of actual analysis":
  engagement theater. The Method must *analyze* or shut up.
- **MyFitnessPal** — "streak resets erased months of effort": no streaks,
  and the missed-day copy carries Lally et al. (a single missed day costs
  no automaticity) as its evidence line.
- **MacroFactor** — the ceiling for honest arithmetic, and still generic:
  its scale-jump answer absorbs the jump into a smoother rather than
  *attributing* it from her own record. The unclaimed whitespace this pass
  took: salty-dinner attribution, menses-onset attribution, N-of-1 pattern
  counts, silence as a feature.
- **Shotsy** — medication curves without a record behind them.
- **LLM coaches generally** — sycophancy: they celebrate under-eating by
  construction. Jeni's count-up grammar for on-medication days (p53) and
  the adequacy net stand against exactly this; the Method never
  congratulates a deficit.

Corrections logged while researching: WW's clinic arm did NOT shut down
(Chapter 11 → emerged private); Cal AI was acquired by MFP — both had been
misstated in earlier internal notes.

## 4. What does current evidence support?

The research ledger (four agent sweeps, primary sources opened; the tier
each claim ships under):

- **Protein 1.2–1.6 g/kg on GLP-1** — 2025 Joint Advisory (Mozaffarian et
  al., *Obesity* 2025, ACLM+ASN+OMA+TOS) + the 2025 Delphi consensus
  (1.2–1.5). STRONG. Lean-mass fractions: STEP-1 ~40%, SURMOUNT-1 ~26% —
  the product's "25–39%" range claim keeps both trials named.
- **Resistance training under caloric restriction** — STRONG generally;
  GLP-1-specific evidence is thinner (S-LiTE, NEJM 2021 liraglutide):
  the note stays, tiered honestly.
- **Constipation on semaglutide** — pooled STEP 1–3 (Wharton, *Diabetes
  Obes Metab* 2022): 24.2% vs 11% placebo, transient, escalation-clustered.
  Note 15's evidence line now says exactly this. STRONG.
- **Late-in-cycle appetite** — NO published day-pattern exists; it is
  PK-derivable only (label trough). The note now hedges ("often, not
  usually"), tier REASONABLE PRACTICE, evidence = the label's own PK.
- **Plateaus** — metabolic adaptation at a stall is small (~40–90 kcal/d;
  Hall model; Martins 2020) and does not predict regain; the dominant cause
  is quiet intake drift. The old copy said "your body's adjusting" — the
  adaptation myth — in two places. Both rewritten. STRONG (for the
  *refutation*).
- **On-drug plateau timing** — semaglutide nadir ~week 60, tirzepatide
  ~48–72: the tenure teaching ("about a year in, the trials' own curves
  flatten. holding here is the medicine's shape, not a stall") fires only
  at ≥10 months' stated tenure. STRONG, attributed.
- **Menses-onset water** — White 2011 + Kanellakis 2023: ~0.3–0.5 kg,
  first days of flow, resolves. STRONG. (The cycle machinery itself is
  p53's, with its irregularity stand-downs untouched.)
- **Salt-loading water** — 1–2.5 kg overnight is water arithmetic, not fat
  (a 1.6 lb overnight jump would require ~5,600 kcal above maintenance —
  the note does that arithmetic instead of citing a myth). Hedged "often".
- **Discontinuation** — STEP-1 extension: ~2/3 of lost weight regained at
  one year off; SURMOUNT-4 +14%; real-world cohorts softer. The new
  `medication_ended_v1` note is support-shaped and record-keeping-shaped —
  it NEVER speaks a regain prediction at her (§18's boundary).
- **Weekends** — Racette (+0.06 kg per weekend day), Orsama (Sun/Mon
  peaks): weekday compensation separates losers from gainers, so the weekly
  read *attributes* ("weekends ran about N kcal above your weekdays, and
  the weekdays held") and never scolds.
- **Self-monitoring** — consistency beats completeness (≥3 days/wk;
  Hollis 2× loss). The Method's logging-density gates encode this.
- **Notifications** — HeartSteps: habituation −2%/day → null by day 28;
  Drink Less: content sophistication adds nothing; evening step prompts
  *decreased* steps. This graded §13's deletions.
- **MI register** — adds nothing over equal-intensity contact
  (Michalopoulou 2022): voice stays plain, no motivational-interviewing
  theater.

## 5. What did you deliberately reject?

- **84 AI lessons to replace 84 static ones** — forbidden by the brief and
  by Noom's own reviews.
- **A water tracker / personal fluid volume** — again (third time, newly
  re-verified): the 2025 Delphi does state ≥2 L/day, but fluid restriction
  is standard of care in HF/CKD/hyponatremia and the app cannot see those
  diagnoses. The asymmetry rule stands: menses-onset and queasy-day water
  *copy* only; a care team's ml aim renders attributed. Considered, cited,
  refused.
- **A sleep note** — the day composer already reads sleep
  (`gentleShortNight` + the short-sleep clause); a Method note would be a
  second voice on one signal. The catalog's exclusion reason is TRUE and
  now documented rather than assumed.
- **Dose-day gentle-eating note** — overlaps CarePlanEngine's dose-day lead
  and the titration beats; would double-speak.
- **A "seventh time" ordinal** — `ordinalWord` returns nil past "sixth";
  the pattern note *drops to the base note* rather than inventing a word
  (a small honesty: the record counts, the copy never overcounts).
- **Micronutrient interpretation** — vitamin D/ferritin drift on GLP-1 is
  real in the literature, but the product refuses micros interpretation
  without grounded data (the p26 law). Documented only.
- **Predicting regain at the user** — the ended-medication note keeps the
  trials in its *evidence line* (clinician-facing vocabulary), never in the
  sentence spoken at her.
- **A notification for the Method** — a note waits on its surfaces; it
  never pushes.

## 6. What content was removed?

**~48.4 MB of corpus, deleted with unreachability proven first** (call-site
sweep before deletion; the lesson *beat* verified alive after):

- `Reader/` — 18 files including 3 `.metal` shaders
- `RepEngine`, `CBTCurriculumService`, `CBTCurriculumScheduler`,
  `CBTCurriculumTypes`, `LessonManifest`, `LessonAnchor`
- `Resources/manifest_v1.json` (401,845 B)
- 42 `jm_hero_*` imagesets (~17.6 MB)
- `JeniMethodRitual`, `JeniMethodRitualView`, `JeniMethodReReadView`,
  `JeniMethodContent`, `JeniMethodAnalytics`, `JeniMethodSafetyLine`,
  `LessonPracticeView`
- `RecapNotificationService.swift` (zero callers)
- `JeniMethodRitualSafetyTests.swift` (13 tests that tested deleted content)
- ProfileHubView's dead `.jeniMethod` arm, DebugAuthView's rows,
  `PillarId.archetypeAffinity`, `CohortStore.curriculumFlags()` (a dead
  bridge), the `--uitest-jeni-lesson`/`--uitest-cbt-lesson`/
  `--debug-lesson-close` QA doors and their hosts. pbxproj −132 lines.

**Preserved on purpose**: `JeniMethodState` (slimmed — `markEnrolled` is
live at TodayModules:201), `JeniMethodFeatureFlag` (WallView),
`RitualMusicPlayer` (BreathworkSessionView uses it),
`IntensityProfile.LessonCadence` (PrescriptionEngineV2 reads it).

Also deleted: the notification families in §18, and InsightEngine's dead
card corpus (~25 strings that no surface consumed).

## 7. What remains static?

The **catalog** — twenty notes, hand-written, version-pinned,
fingerprint-tripwired. Copy is static by design: a static sentence can be
audited, banned-word-swept, tiered and diffed; a generated one cannot. The
safety boundary (§25) is enforceable *because* the corpus is enumerable.

## 8. What became record-driven?

Everything that decides whether a note speaks:

- **Triggers** read `MethodEngine.Input`, built solely from her record:
  weigh-ins (canonical fold), plates (sodium/protein by day), regimen
  (cycle day/length via `CyclePosition`, ended-days-ago), cycle season,
  strength (HealthKit AND hand-recorded), logging density, the adequacy
  net, suppression state, her display unit.
- **The follow-up loop closes visibly**: `settleFollowUps` →
  `.methodFollowUp` → the weekly read reports "2 of 3 notes jeni left this
  week were followed by the move they named."
- **The told-list** (`MethodLedger`) is what the tile status, the
  `methodTold` sheet, and Jeni's `method_told` envelope key all read — and
  it is swept at sign-out now (M8).

## 9. What inputs can trigger Method?

Weight bumps against a flat/falling established trend · prior-day sodium ·
menses onset (p53's cycle machinery, with its stand-downs) · dose-cycle
waning band (weekly and every-N) · a deliberately ended self regimen (≤28
days) · protein-below-floor patterns over logged days (excluding today) ·
morning protein gap from her own shortfall · flat weeks (dense logging
only) · strength absence (stood down by EITHER province of strength) ·
constipation + low fiber · queasy-day fluids · the N-of-1 salty-pattern
count (≥3 recorded co-occurrences).

## 10. What inputs are forbidden from triggering Method?

- **Anything the record doesn't hold**: pregnancy/ED/insulin holds are
  never inferred (the p35 law) — suppression consumes them, nothing
  generates from them.
- **Doses she didn't state**: the Method never proposes, times, or sizes a
  dose; `medication_ended_v1`'s chatSeed explicitly forbids Jeni the
  restart/medication-decision lane.
- **Body photographs**: no Method input reads a scan (§20 below).
- **A single unusual day**: one loud Saturday is a *shape* in the weekly
  read, never a trigger (History E).
- **An unfillable pattern**: fewer than 3 recorded instances → the pattern
  note cannot render (the {nth} token goes unfilled and the note drops).
- **Sleep** (composer's domain), **steps** (the walking action's domain),
  **mood severity** (988-first, E2's law).

## 11. How does evidence tiering work?

`EvidenceTier` has three cases — `.strong`, `.reasonablePractice`,
`.arithmetic` — and **"weak" is deliberately not a case**: an unevidenced
note is untypeable, therefore unshippable (p53's construction, now with
teeth). New this pass:

- **The tier table test** pins all 20 notes' tiers explicitly.
- **The claim-marker sweep** fails any `because` line that names external
  science (kcal constants, "most common", "the medicine", trial language)
  while tiered `.arithmetic` or missing an evidence line.
- **The fingerprint tripwire** (FNV-1a) forces a version bump on any copy
  change, so a tier and its sentence can never silently drift apart.
- **`evidence_tier` ships on `method_note_shown`** (values `s`/`rp`/`a`),
  so the founder can read which tiers actually land.

## 12. How does personalization distinguish population evidence from her own pattern?

The **{nth} token mechanism**: `salty_dinner_pattern_v1` says "that's the
{nth} time your record has paired salt with a next-morning bump" — the
input builder counts her actual sodium→bump co-occurrences (60 days,
canonical weigh series); below 3, the token is unfillable and the engine
*drops to the population note* ("salt often holds water for a day").
Population claims carry literature tiers; the personal sentence carries her
count. The same shape as E2's `foodNoiseReturn` (≥3 cycles), generalized.
Adversarial pin: the same jump with 2 prior instances speaks the base note;
with 3, the pattern note; the counter test walks the boundary.

## 13. How does Jeni express uncertainty?

- The trend has a **sufficiency ladder** (insufficient → provisional →
  established): provisional reads say "an early read."; insufficient says
  "a few more weigh-ins and your trend line starts." — and NO surface
  speaks a weekly delta without an established band (InsightEngine, the
  chat trend card, and the envelope all gated this pass; the envelope
  carries `no_trend_note` so the model knows *why* the field is absent).
- Tenure is "by her account" in the packet and now
  `treatment_months_basis` in the envelope (J2).
- History M (near-empty record) produces **nothing at all** — pinned by
  test. "I don't know yet" is rendered as honest emptiness plus the
  ladder's own forming words, never as a hedge-decorated guess.

## 14. What are the NOW / WEEK / CHAPTER layers?

No new screens — the three layers live on surfaces that already exist:

- **NOW** — the Method note (Today cover + Home method tile status), one
  per day, silence most days.
- **WEEK** — the weekly read (§17) + the Becoming week review: attribution,
  follow-through, "nothing needs a reset."
- **CHAPTER** — tenure: `treatment_months` ("month 4 of treatment, by her
  account"), the ≥10-month plateau teaching, program chapters in Becoming's
  journey. The chapter layer needed exactly one new sentence (the tenure
  teaching), not a surface.

## 15. How is GLP-1 Method different?

Wellness-side only, on the p53 regimen machinery: the waning-band appetite
note (cycle-length-aware), the constipation note (STEP-pooled evidence),
dose-cycle vocabulary in the weekly read teaching, the adequacy net
(under-eating flagged, never celebrated — count-up grammar preserved), the
tenure plateau teaching, and the ended-medication note. **No dosing advice,
no titration opinions, no missed-dose windows** (those are label facts and
MedicationCatalog's, per-molecule, from E2) — escalation language routes to
"a conversation for your prescriber," in exactly those clinical-boundary
words.

## 16. How is ordinary weight loss first-class?

Every non-medication note fires identically without a regimen; the plateau,
salty, menses, protein, strength and weekend machinery never consult
medication state. History D (non-GLP-1, low protein after strength) earns
the *same* protein teaching History C's adequacy-net silence withholds —
pinned by adversarial tests. The weekly read's non-medicated leg re-pinned:
it leaks no dose vocabulary and closes with the same "nothing needs a
reset."

## 17. What does the weekly read now do?

The §9 target — "WHAT ACTUALLY MATTERED THIS WEEK" — landed as five
additions to `WeeklyReadComposer` (35/35 green; films at standard/SE/AX5):

- **Follow-through** — "2 of 3 notes jeni left this week were followed by
  the move they named." (M4: the loop is visible to HER now.)
- **Weekend attribution** — "the week's shape: weekends ran about 400 kcal
  above your weekdays, and the weekdays held." Gated: never under numeric
  suppression, never for restrictive-risk profiles, ≥2 weekend + ≥3 weekday
  logged days, ≥150 kcal delta, rounded to 50 — a shape, never a verdict.
- **Protein delta vs prior week** — upward only ("· up from 2 last week");
  a downward week is simply this week's count, unscolded.
- **Strength held** — "strength held: 2 sessions. the part that decides
  what the loss is made of."
- **The close** — "nothing needs a reset." when plates exist and the trend
  isn't drifting: the anti-what-the-hell sentence, from the same
  literature that built the count-up grammar.
- Teachings: the waning-band dose-rhythm line (interval-aware) and the
  ≥10-month tenure plateau line, offer-first precedence untouched.

## 18. How are notification collisions prevented?

The census found the arbiter three-quarters inert: 4 admit sites, 13+
bypass paths, both daily repeaters ungated (N1); the master toggle left
five families alive and `reschedule()` re-armed them against OS auth only
(N2); the ledger self-saturated so the budget vetoed exactly the kindest
push (N3). Worst realistic day: 8 deliveries, 4 in the same minute.
RED→GREEN (3 failures first):

- **One chokepoint** — `NotificationGate.schedule(request, category:)`;
  a `#filePath` source-sweep test asserts every `center.add(` in the app
  lives in the gate, the medication path, or a DEBUG allowlist. A new
  bypass now fails a test at the *source* level.
- **Two classes, one law** — CONSENTED CADENCE (medication, morning read,
  weekly read) is exempt-not-stamped; every INTERRUPTION is budgeted ≤5/wk
  through the brain. Re-arming ≠ re-stamping, so the ledger no longer
  saturates itself (N3).
- **Deleted under the presumption of deletion**: the `affirmation_drop_*`
  family (motivational filler — "you're becoming someone who glows"),
  `daily_reminder` (stale workout-era copy, nagged non-enrolled users
  forever; a cancel-only stub sweeps old installs), the `milestone_*` push
  family, the first-log nudge, and `RecapNotificationService` (dead).
  Each fails the brief's WHY NOW? test.
- **Converted**: `evening_plate_review` daily-repeats → a one-shot re-armed
  daily and **cancelled the moment a plate lands** (the lapse_support
  pattern) — it can no longer fire about a day she already logged.
- **The master toggle means off**: the sweep is `NotificationCensus
  .allNonMedicationIds` and `reschedule()` checks `notificationsEnabled`.
  `NotificationCensus.retiredIds` sweeps the deleted families from
  existing installs.

## 19. What happened to THE BOOK proposal?

Investigated, and it corrected the proposal's own framing: **[CORR on
pass 50 §14] THE BOOK and the weigh-in ledger already open as
fullScreenCovers** — the "promote them out of sheets" framing was wrong; no
navigation change was needed or made (no dashboard soup). What was actually
missing was the tap: **the Home nutrition instrument now opens THE BOOK**
(`HomeView.onOpenFood → AppRouter.shared.open(.plates)` — one line, the
same route the `jenifit://plates` deep link and the QA door already use),
with the a11y hint "opens the book, your food record." Both ends filmed
(instrument on Home; THE BOOK open via the route); the tap itself is stated
not walked — the sim cannot synthesize the gesture, and the handler is one
audited line. THE BOOK already reads as the longitudinal record (day
ledger above photos since p33); it did not need to become a fifth
dashboard to answer §14.

## 20. What happened to Body Snap / waist?

Re-opened with evidence, verdict unchanged: **KEEP as-is, no redesign, no
build.** There is still no validation for estimating body-fat percentage
from consumer photos in this population — the refusal is absolute per the
brief. `BandProfile` (words, never numbers, 3% noise floor) remains the
honest ceiling for photographic observation. The waist-trend option
(pass 50's "introduce simply") stays a **founder decision**: a manual waist
measurement is cheap and evidence-adjacent (WC is a real clinical marker),
but the wire shape rides `ObservationKind` where the server holds a CHECK
constraint — a client-only add would 400 on sync, the §31 ordering hazard.
Design note written, nothing built.

## 21. What happened to water?

Refused again, now with the strongest counter-evidence named: the 2025
GLP-1 Delphi does recommend ≥2 L/day fluid — and the refusal survives it,
because the app cannot see heart failure, CKD or hyponatremia, where fluid
is *restricted*, and a wrong number is a clinical instruction while a
missing number is not. The asymmetry law stands: menses-onset copy
(White 2011), queasy-day fluids copy, care-team ml attributed. The
p50 §15 `ObservationKind.hydration` writer question is unchanged.

## 22. What visual defects were found?

Two, both frame-caught, both RED→GREEN on film:

- **The Method bump notes spoke kg to lb users** — "up 0.7 kg" to a woman
  whose every other surface says pounds. Fixed at the engine
  (`Input.weightUnitIsLb` + `weightDelta`), pinned by
  `testTheBumpSpeaksHerUnit`, refilmed in lb.
- **The weekly read clipped BOTH edges at AX5** — the dateline's two
  `fixedSize` runs exceeded any phone's width, the over-wide column
  centered in `JKScreenChrome`'s ZStack, and every row on the page clipped
  symmetrically (the p52 mechanism, on a new surface). Fixed three ways,
  each filmed: the dateline stacks at ≥accessibility1 (the p52 name-rule
  precedent), the signals band stacks to rows at ≥accessibility1, and the
  page gained the **min-height ScrollView law** (p52's letter fix) — when
  content fits, the composition is unchanged (doors still pinned by the
  Spacer, proven on film at standard size); long type scrolls.

## 23. What did frame-level inspection catch?

Beyond §22: the SE film showed the decline door ("not this week") sat
**below the fold at DEFAULT type size** — the read had NO scroll container,
so on the smallest phone the decline exit was unreachable-by-construction
all along; the scroll fix was needed for SE at medium, not only AX5.
The film harness itself re-fired the recorded §12.1 trap in new clothes: an
unquoted `$2` in zsh passed a mangled single argument, the app launched
*real* and filmed the PAYWALL — caught by checking `ps -o args=` against
the intended launch, arguments now passed explicitly. A new DEBUG film door
(`--debug-read-scroll-bottom`, ScrollViewReader) exists because the sim
still refuses synthesized drags. Reduce Motion: the read's entrance keeps
its law (`onAppearWork` settles the tail immediately under RM); the
cascade and dial are kit primitives that own their RM branches — stated,
not refilmed, since no motion law changed this pass.

## 24. What did adversarial histories expose?

`MethodAdversarialTests` — 9 tests, all green, each a differentiation the
brief demanded:

- **A vs B** — the same +1.6 lb overnight: explained against a flat
  established trend (salty note), **no reassurance** against a 3-week
  rising trend (silence — reassurance would be a lie).
- **C vs D** — GLP-1 low-intake day: the adequacy net silences the protein
  teaching for C; D (non-GLP-1, same plates) earns it.
- **E** — one loud Saturday, trend falling: no note; the weekly read
  attributes the shape.
- **F vs G** — 21 flat days: sparse logging → NOT called a plateau; dense
  logging → the honest flat-stretch note (whose rewritten `because` says
  drift, not adaptation).
- **J** — hand-recorded strength stands the resistance note down (both
  provinces count — p53's movement law, now pinned adversarially).
- **M** — a near-empty record produces **nothing at all**.

H (repeated corrected breakfasts) is p53's FoodUsuals, already pinned
there; I (late shot re-anchoring a q10d regimen) is M1's interval-band
suite in `MethodSpineTests` (the re-anchored chain moves the band); K/L
(cycle plausible vs unreliable) are the menses tests plus p53's
irregularity stand-downs (spread >10d → silence), which this pass consumed
rather than rebuilt.

## 25. What safety boundaries are machine-enforced?

- "weak" evidence is **untypeable** (`EvidenceTier` has no such case).
- External claims require a tier + evidence line (the marker sweep).
- Copy drift requires a version bump (the fingerprint tripwire).
- Banned-word sweeps on symptom/status vocabulary (standing since p36,
  re-run green), plus the new PlankFood voice sweep (no "blunts cravings",
  no "extends fullness by hours", no em-dash claims).
- The ended-medication chatSeed **forbids** Jeni the restart/medication
  lane in the seed itself.
- Suppression strips evidence lines (`ResolvedMethodNote.evidenceLine` is
  nil under numeric suppression — a citation with numbers in it is a
  numeral).
- The packet's three registers stay distinct and now travel: "by her
  account" (patient reports), "computed from her weigh-ins" (record
  suggests — the K4 caption, app + PDF), recorded rows plain; the
  disclaimer line ("a personal record, not a diagnosis or medical advice")
  finally ships IN the payload (K1) instead of only on the screen.
- The Method never notifies; the notification chokepoint is source-swept.

## 26. What dead code/content/assets were removed?

§6's corpus (~48.4 MB), the four notification families + one dead service,
InsightEngine's dead card corpus, dead Method inputs, the dead
`curriculumFlags()` bridge, `PillarId.archetypeAffinity`, two stale
comments naming a deleted `PlanView.swift`. Every deletion preceded by a
call-site proof; the post-deletion suite dropped by exactly the 13 deleted
tests (1488 → 1475 total, reconciled to the test).

## 27. What was intentionally left alone?

- **The v4.5 `OnboardingView`** (9,645 lines + 30.25 MB of assets) —
  DEBUG-only, founder-gated since pass 48, and not the Method's to delete.
- **`TrialEndNotificationService`** — its caller is commented out inside
  `PaymentService` (a protected path); the service is gated and
  sweep-clean, the dead caller named not touched.
- **`day1_morning`** — consent-gated activation push, kept (gated).
- **Signals.BodyLine, CoachSummary.seasonNote ("matters double"),
  WeightAnalytics.subtitle** — dead interpretive strings, proven
  unreachable, NAMED for the next cleanup rather than deleted this pass
  (they sit in files this pass otherwise didn't need to touch).
- **`startProgram`'s unguarded write, the E-14 threshold divergence
  (brief 1%/wk vs CarePlan's protocol constant), `recordIgnored`**
  (delivered-not-engaged detection needs signals the client doesn't hold —
  auto-silence stays latent, stated) — all documented.
- **The EF prompt's ungoverned fields** (season/band_zone/method_now) —
  the client half shipped (in-band `season_note`); the EF block is a
  founder-gated deploy, as every EF change has been.
- **The GLP-1 anchor rung's always-protein copy**
  (`ProgramDayArchetype.archetype` pins `.protein` for medicated users) —
  defensible on the evidence but named as a monotony risk.

## 28. Tests before / RED / after.

- **Baselines re-measured, not inherited**: app 1446/0/2 (1448 total) ·
  PlankFood 239 · PlankSync 29.
- **RED proven per phase, artifacts retained**: Method core 13 failures
  of 76 (`red_method.xcresult`) · food voice 26 failures · notifications 3
  failures (`red_notif.xcresult`) — honest-BEFORE stubs, with the standing
  lesson re-observed: refusal-shaped tests cannot go red against a stub
  that refuses everything, and the controls that "failed to fail" are
  named in each suite.
- **Final, all from xcresult, never a piped tail**:
  **app 1483 passed · 0 failed · 2 skipped (1485 total; +37 vs baseline
  reconciled EXACTLY: +40 phases A–F, −13 deleted ritual tests,
  +9 adversarial, +1 unit pin — identity-level diff against the
  post-deletion bundle shows precisely those ten additions)** ·
  **PlankFood 242/242** (+3 = `ResultDetailVoiceTests`) ·
  **PlankSync 29/29** · **DayKeyVocabularyTests 3/3 under
  `-testLanguage ar -testRegion SA`** · **Release configuration BUILD
  SUCCEEDED, 0 errors.**
- The mid-pass full suite (1486/0/2) proved zero regressions before the
  corpus deletion; the post-deletion run (1473/0/2) proved the deletion
  cost exactly its own tests.

## 29. Production mutations.

**None sought; no SQL executed; no production reads made.** No deploys, no
Edge Function changes, no storage changes. Sim launches this pass reused
the standing QA simulator identities (no `simctl erase` was run, so the
per-keychain anonymous-bootstrap mechanism recorded in §45/§46 had no
fresh keychain to mint against; QA-SE and QA-iPhone16 both carried
identities from prior passes). Films and walks wrote only under those
standing QA accounts through shipped paths.

## 30. Migrations written/applied.

**None written, none applied this pass.** Pass 53's
`20260818090000` (5 additive columns) remains WRITTEN NOT APPLIED — the
founder gate stands exactly as recorded there, and nothing this pass added
depends on it.

## 31. P0/P1 remaining.

**P0: 0.** **P1: 0 new.** The pass's own P1s (M1, M8, N1, N2, N3) are
closed RED→GREEN. Standing founder-gated items (the p53 migration, EF
deploys) are gates, not defects.

## 32. What still requires another app?

Nothing in the Method's loop. The clinician-side *reading* of the packet
remains the web/PDF surface it already was; a clinician dashboard was
explicitly out of scope and none was built. Apple Health remains the only
external dependency for its two provinces (steps, workouts), both already
integrated.

## 33. What requires founder decision?

1. **Apply pass 53's migration** with/before the next build (unchanged).
2. **The EF envelope block** (season/band_zone/method_now) — deploy-gated;
   the client half is live and in-band.
3. **The waist-trend observation** — design note ready; blocked on the
   `ObservationKind` server CHECK ordering (§20).
4. **The v4.5 OnboardingView sweep** — 30.25 MB, measured since pass 48.
5. **The archive-time version bump** (33 → 34) whenever the next archive
   is cut — the standing convention, not this pass's to make.

## 34. Is it safe for Pass 55?

**YES.** Every suite green from xcresult; Release builds; protected paths
(Payment · Paywall · Auth · AppPhase · Info.plist · entitlements · widgets
· BodyScan · `supabase/` · Edge Functions) EMPTY this pass; all three
`@Model` files zero-diff (no store migration exists to fail); 55 source
files touched (enumerated by `find -newer` against the pass marker), plus
the corpus deletions and pbxproj references; RED artifacts retained.

---

## The closing law

**IF JENI HAS NOTHING USEFUL TO SAY, SHE SAYS NOTHING.**

**IF SHE SPEAKS, I SHOULD BE ABLE TO ASK: WHY DID YOU TELL ME THIS TODAY?**

**AND THE PRODUCT SHOULD HAVE AN ANSWER.**

It does, mechanically: every spoken note carries its trigger (her data),
its tier (typed), its evidence line (swept), its version (fingerprinted),
its cooldown (ledgered), and its follow-up (reported back in her weekly
read). Silence is the default return value, and the tests pin that the
quiet days stay quiet.
