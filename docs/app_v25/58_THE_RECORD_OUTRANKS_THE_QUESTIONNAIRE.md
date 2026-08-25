# 58 — THE RECORD OUTRANKS THE QUESTIONNAIRE

**Built 2026-08-25, on feat/app-v2, after 57. The founder's brief
re-opened five of p57's founder gates and asked for a fresh,
high-attention pass: product depth, design evolution, core records,
delight, retention. One finding unified the pass: wherever a stale
consult answer and the living record disagreed, the product believed
the questionnaire — and wherever the record had more to give (the
Home Screen, the weight trend, the hand, a reinstall), it wasn't
reaching. Nothing archived, uploaded or submitted.**

---

## 1. Starting state (recorded before any change)

HEAD `b50067e` == `origin/feat/app-v2` (p57's addendum commit), tree
clean, MARKETING_VERSION 1.1.7, CURRENT_PROJECT_VERSION 35 (4 sites).
Baselines re-measured, never inherited: **Release BUILD SUCCEEDED**
on the untouched tree before any product work; the p57 close counts
(app 1540/0/2 · PlankFood 253 · PlankSync 29) stood as the reference
for reconciliation at this pass's close (§26).

## 2. What was walked before any code

Three persona walks on the QA sim through the p57 walker-arm
(`DriveUITests`, which this pass made diagnosable — "missing" and
"unreadable" were one error message; and whose env delivery turned
out to require environment-form `TEST_RUNNER_` variables, not
command-line build settings): the ordinary week-rich persona (Home,
Becoming, chat), the GLP-1 persona (dose row, band, Becoming), and
the surface walk (dose sheet, scan chooser, jeni desk, weigh-ins).
Films retained under `/tmp/jeni_drive/out*` during the session; the
decisive frames are in `58_evidence/`.

## 3. THE DEFECT THE WALK FOUND — one screen, two cohorts

The GLP-1 persona's Home said **"your shot is today"** and
**"187 over"** in the same frame
(`58_evidence/before_glp1_home_over.png`). The count-up law (p53;
"one law on both surfaces" p57) consults `onboarding_glp1_status` —
the QUESTIONNAIRE — while the dose row consults the REGIMEN — the
RECORD. The regimen editor has never written the consult key; the
clinic door writes none deliberately; "past"/"considering" answerers
who start later never update it. So a person with an active
injectable regimen could be mis-cohorted across every consumer: the
count-up grammar, the protein-floor branch (default 85 g where the
lean-mass-first branch says 110 g at 70 kg), the chapter, the coach
envelope, the notification brain. PostHog's own CohortIdentity
already stamped her `medicated: true` from the regimen — the product
disagreed with its own analytics.

**Fixed, belt and braces (RED 5 failures of 8 against the shipped
paths, no stubs; the three passes were two controls and the
pinned-at-birth derivation table — `58_evidence/RED_medication_truth.log`):**

- **BELT** — `RegimenService.reconcileCohortStatus` at the same
  chokepoints that own regimen truth (applySelfRegimen ×3,
  endMedicationPlan, CareReconciliation.confirm, the Home refresh):
  an active plan makes the key "current"; ending the last plan ages
  a stated "current" to "past"; an answer the record neither
  confirms nor denies (none/considering/prefer_not_say with no
  history) is HER word and is never rewritten. The UserRecord mirror
  follows (pendingUpsert), so a reinstall restores the aged fact.
- **BRACES** — record-aware reads where a ModelContext exists:
  `Chapter.derive` gains `hasActiveMedicationRegimen`; the snapshot
  decides ONE chapter for the whole screen; the reading's count-up
  provider and both protein-floor resolvers thread
  `CohortStore.isOnMedication` (consult answer OR active regimen,
  self or care-team).

GREEN 8/8; 119 sibling tests green; the refilm shows the same
persona reading "1,660 of 1,473 kcal" with no "over" and a 120 g
floor (`58_evidence/after_glp1_home_countup.png`). Both surfaces of
one screen now agree about who she is.

## 4. THE TWO-PASS ERROR CORRECTED — came_for needed one line, not a column

p37 recorded the outcome answer ("what do you want to change most?")
as having no server column; p57 §40 ③ inherited that into a
founder-gated migration. **Both were wrong.** The answer has ridden
`users.onboarding_motivation` since the v5 assembler
(`data.motivation = outcome` → `record.onboardingMotivation` → the
upsert), and `hydrateUser` adopts it back present-only. The server
held her most personal answer the whole time; the client never
mirrored it back to `onb_v5_outcome`, which the coach envelope's
`came_for` reads. **The whole fix is one `merge` line in
`restoreCohortDefaults`** — RED 1/3 (the two refusal controls passed,
inherited from the merge closure; `58_evidence/RED_outcome_restore.log`),
GREEN 3/3, restore siblings 30/30. After a reinstall the coach again
speaks in the words she gave on day 0. **No migration. No founder
gate. The gate is closed by evidence, not by work.**

## 5. THE DOSE ERAS REACH THE TREND — and the era arithmetic had two lies

p57 §40 ② (dose-era badges, "timing-never-causality words ready")
opened. Mapping the implementation exposed that three surfaces
derived eras independently and all three counted a SCHEDULE-only
change as a dose change (schedule versions inherit `startedAt` by
RegimenService's own rule): the pattern engine could say **"picked up
after the dose changed" about a week the dose did not change**; the
chat envelope handed the model two "eras" at one strength sharing one
start date; the becoming ledger split one dose's span into two rows.

**`RegimenEras` is THE arithmetic now** (pure, lifted facts, the
DoseLedger house pattern): consecutive same-strength versions are ONE
era; only a real strength move opens one; a nil strength breaks the
run but never claims a change ("unknown is never a fact"); input
order is irrelevant (the chain orders itself). RED 1/6 at the real
envelope consumer (`era_count` 2 where the truth is 1 —
`58_evidence/RED_regimen_eras.log`); the engine table is new law,
pinned at birth, stated as such. All three consumers swapped;
87 sibling tests green.

**And the v24 prepared design finally shipped**: dose-era seams on
the 200 pt weight detail — a dotted hairline where the dose moved
(dotted so a seam can never be mistaken for the solid scrub rule),
labeled with the new dose's own word ("0.5 mg"), drawn UNDER the
ink, suppressed at the window edge (a change before the window draws
nothing), absent from the 26 pt face spark and the 56 pt hero,
gated upstream by numeric suppression (the tile doesn't render at
all), with VoiceOver speaking the seams in the same factual register
("the chart marks where the dose changed: 0.5 mg"). The
delta-per-era read stays on the medication ledger, deliberately —
the chart says WHEN, never WHAT IT DID. Filmed:
`58_evidence/dose_era_seam_weight_detail.png`.

## 6. THE RECORD REACHES THE HOME SCREEN — the widget (p57 gate ① opened)

**Decision: build.** Both GLP-1 competitors treat the widget as core
retention (Shotsy's widget deep-links straight to shot logging; MFP
and Lose It ship calorie-state widgets); p57's own r6 research
recommended exactly one small widget ("next dose distance + today's
protein/logging state", PROMISING-with-selection-caveat, honestly
stated); current Apple guidance supplies the truthful pattern
(app-driven reloads at record events, budget-exempt while
foreground; self-aging entries; `.privacySensitive`).

**What existed: nothing.** The extension held only the scan Live
Activity — no TimelineProvider, no App Group, no WidgetCenter call
in the repo. Greenfield, so the architecture was chosen for
truthfulness first:

- **One precomposed contract.** `JeniWidgetSnapshot` (dual-membered,
  the ScanActivityAttributes precedent) is written ONLY by the app
  (`WidgetBridge`, at the Home refresh where a fresh TodaySnapshot is
  already in hand — zero extra queries — plus the scene-background
  transition). The widget process holds no engine and can never
  disagree with Home.
- **The laws cross the boundary pinned.** The words the widget
  composes are pinned EQUAL to `HomeNutritionSummary`'s grammar
  input-for-input (the count-up cohort never reads "over" on the
  Home Screen; maintenance holds; zero is "right on it"); the
  civil-day question uses the app's own dayKey grammar, pinned equal;
  numeric suppression publishes NO numerals (the safety gate's law
  reaches the Home Screen); the dose line keeps DoseStanding's
  discretion — never a product name, never an amount, and a skipped
  day stays HER business (silence) — with `.privacySensitive` for
  Lock Screen redaction.
- **Entries speak only for their own civil day.** The timeline is
  [now, next-midnight]; the midnight entry renders the fresh-day
  state (eaten zeroed, targets standing, dose line silent), and a
  stale store read after midnight renders fresh-day too — yesterday's
  numbers are never presented as today's.
- **The sweep retires it.** `WidgetBridge.retire()` rides
  `clearOnboardingUserDefaults`: the next account on this phone can
  never glance the previous one's protein.
- Faces: systemSmall (protein ring + floor + dose line) and
  systemMedium (+ the day sentence); brand serif + DMSans embedded in
  the appex with `UIAppFonts`; paper+ink palette constants pinned to
  Tokens.swift by comment; deep link `jenifit://today`; App Group
  `group.com.bk.plankAI` on both targets.

`WidgetSnapshotTests` 8/8 (new law, pinned at birth). All seven
faces filmed through `--debug-widget-gallery` — the same view code at
widget geometry (`58_evidence/widget_gallery_*.png`); one film-caught
defect fixed (a round-cap phantom dot on the zero-day ring). The
built appex verified: fonts embedded, UIAppFonts declared, widget
symbols present. **Named for the founder:** Home-Screen placement
itself is a hardware/manual step, and the App Group must provision at
archive time (automatic signing normally creates it; verify at the
first archive).

## 7. ONE HAND FOR A RECORD LANDING — the haptic grammar's fourth word

The inventory (all ~330 call sites) found the three record-writing
commits speaking three signatures — dose mark = soft, weight save =
success, plate file = success — so the product's most consequential
daily commit had the WEAKEST hand. `JeniHaptic` gains `record()`
(notification success): a fact entering the record always feels the
same, and it is the strongest confirm the product makes. Routed: the
dose mark, the weight keep; the method-note action joins the grammar
at `land()`; the design law's §8 table amended (three words → four).
PlankFood's plate-file already speaks `.success` inline (the package
cannot see the type) — same signature by construction, pinned in the
grammar's comment. Deliberately NOT done: a 265-site mechanical
re-route of every `light`/`soft` — the drift that matters was
semantic, not spelling.

## 8. THE HOME NUTRITION VISUAL — re-decided by looking

The founder's split-donut question was answered with rendered
evidence, not inherited judgment: `--debug-band-contenders` mounts
the shipped band beside a REAL split donut (macro calorie-shares,
legend, centered kcal) and a REAL remainder-hero ring (Lose It's
strongest pattern) with one representative mid-day state
(`58_evidence/band_contenders_decision.png`). The film decides it:

- The donut's segments cannot be read as facts — you cannot recover
  "96 g" from an arc angle (Cleveland–McGill, the same reason p53
  rejected it); the legend does all the work and the shape becomes
  decoration; three adjacent rose tones read as one gradient blob.
  It answers "what was the shape of what I already ate" — the
  retrospective question — where the surface's job is "can I eat
  this".
- The remainder-hero is instantly legible and WRONG for this
  product: it leads with "187 over" as a hero numeral (the
  category's most-quoted shame pattern with the sign amputated), it
  demotes protein against the §9 law, and for the on-medication
  cohort the hero would have to be an absence.
- The shipped band answers three questions in reading order with a
  verb on every number. **A stands.**

Competitor research (79 Lose It/MFP/Lovi frames re-inspected this
pass) independently converged: "one shape, one sentence, one state
color — then stop" is what works; Lose It's own dashboard fails by
rendering calories in three shapes with an empty donut.

## 9. LIQUID GLASS — the refusal re-affirmed on fresh evidence

p57's stance re-examined rather than inherited, per the brief.
Current evidence (Aug 2026): NN/g's legibility critique stands;
Apple itself shipped the iOS 26.1 "Tinted" toggle under readability
pressure; the Apple Design Gallery's praised adoptions confine glass
to tab bars, toolbars and floating controls; Apple's own guidance
says custom glass is for "the most important functional elements"
and to REMOVE custom backgrounds rather than fight the material.
Jeni already takes the native tier (the system tab bar on iOS 26,
system sheets/grabbers/NavigationStack from p57). **Custom glass on
an opaque paper identity would work against both Apple's layering
model and the moat. Refused as a theme, again — now with this
pass's own sources.** No code change.

## 10. EXACT AGE — the gate held, the package written

`docs/app_v25/58_packages/AGE1_users_onboarding_age_years.sql`:
additive nullable integer, no CHECK (a server refusal would convert
one odd value into the p51 sync-loss loop — bounds live at the one
client writer), no backfill (inventing a year from a band is
fabrication), `date_of_birth` and `birth_year` refused per p37 §5.
The file lives in docs/, not supabase/migrations/, so no `db push`
can carry it by accident — because the ordering hazard is severe:
the client half would 400 the WHOLE users row for every new consult
completer until the column exists. Full client diff documented in
the file (verified seams). **STOPPED AT THE GATE, as instructed.**

## 11. Research performed

Six threads: the full Lose It/MFP/Lovi frame set re-inspected
against this pass's questions (84 images); Apple WidgetKit + Liquid
Glass current guidance (sourced, in-session); five parallel code
maps (the widget target, the Home band, the trend+eras chain, the
came_for/age persistence chain, the full haptics inventory); p57's
own research corpus re-read (r1/r6). **Honestly stated:** the
Shotsy/MeAgain screenshot re-inspection agent died on a session
limit mid-run and was not resumed — its two questions (widget
design, dose-on-trend) were answered from the v24 competitive record
(which had already studied Shotsy's dose-segmented curve frame by
frame) and the web sweep; the 93 GLP-1 frames themselves were fully
opened by p57 five days ago.

## 12. What was deliberately NOT built

Springboard automation to place the real widget on the sim Home
Screen (fragile jiggle-mode scripting; the debug gallery films the
same view code at widget geometry, and placement is a device step);
the 265-site haptic re-route; a Lock-Screen accessory family
(byproduct of a later pass once the Home-Screen widget earns its
keep on real devices); the in-place diary row expansion (Lose It's
best interaction — stays on the founder list; it competes with the
plate page's reading and deserves its own pass); the day-one
contract card's half-fade fix (p57 P2, still named); the Becoming
serif title's mid-word break at AX5 (pre-existing, named §14); the
activeEnergy weekly-read line (p57 gate ⑤ — untouched, still the
founder's); dose-era markers on ANY chart but the weight detail.

## 13. Interaction/motion changes

§7's haptic word; no motion law changed; the p53/p54 60 fps films
stand. The chart gained its first marker vocabulary (dotted seam +
quiet label), drawn under the ink, absent by default.

## 14. Accessibility

The seams speak: the weight detail's VoiceOver text appends "the
chart marks where the dose changed: …" in the same factual register.
The widget's faces carry composed `accessibilityLabel`s; the ring is
`accessibilityHidden` (the numeral speaks, the Home law). The AX5
walk re-confirmed the medication detail page clean at AX5; the
weight-detail seam at AX5 was NOT filmed (the tile is unreachable
through the walker at that size — two attempts recorded); the label
is clamp-guarded inside the canvas and scales with `numeralMeta`.
**Named, pre-existing, not this pass's regression:** Becoming's
serif title breaks mid-word ("beco/ming") at AX5.

## 15. Failure/recovery

Nothing new attacked at the network layer (p46/p55 stand; no
launch-path changes). The widget's failure class is staleness, and
it is closed by design: self-aging entries, fresh-day rendering,
`.atEnd` re-ask, retire-on-sweep.

## 16. Production mutations

**None.** No SQL executed, no deploys, no migrations applied, no sim
erases; the standing QA identities were reused for every walk. AGE1
is WRITTEN NOT APPLIED, in docs/, founder-gated.

## 17. The walker-arm improvements (QA tooling)

`DriveUITests` failures are now diagnosable (missing-from-env vs
unreadable-at-path, with the JENI* env keys listed); the session
learned and recorded the env-form invocation
(`TEST_RUNNER_JENI_DRIVE_SCRIPT=… xcodebuild test …`), which the
in-file comment now implies but p57 never wrote down.

## 18. Commits (this session, in order)

`260afe0` fix(cohort): the record outranks the questionnaire ·
`65314dc` fix(restore): came_for comes home — one line, not a
migration · `326aade` feat(trend): dose-era seams + one era
arithmetic · `265d082` feat(widget): the record reaches the Home
Screen · `6657b92` polish(haptics): one hand for a record landing ·
`32770c3` docs: AGE1 written not applied · `4be3493` docs: the band
re-decided by looking · then the shared-container hygiene fix and
this record (hashes in the addendum).

## 19–25. The §28 questions the sections above don't already answer

- **Is Food Snap / barcode / editing / correction memory
  trustworthy?** Unchanged from p53–p57's proofs; walked again at
  the chooser and desk level this pass; not re-attacked (their
  suites ride the full run in §26).
- **Does weight have one truth?** Yes — p55's convergence untouched;
  this pass added context (seams) to its detail without touching
  the fold.
- **Is HealthKit provenance correct / used?** Unchanged from p57 §14
  (nine of ten signals consumed; activeEnergy still the named gap,
  founder-gated).
- **Is program/treatment time coherent?** Yes, and more so: the era
  arithmetic no longer invents dose changes from schedule edits.
- **What onboarding facts are wasted?** One fewer than p57 believed:
  came_for was never wasted server-side — only unrestored. The
  exact-age drift remains, gated on AGE1.
- **What personalization survives reinstall?** All seven cohort keys
  (p35) + the outcome answer (this pass). The exact year still dies
  (AGE1).
- **What should Home answer?** "Where does today stand" — and it
  does, now with rendered proof that the alternatives answer worse
  questions.
- **Does a GLP-1 user feel like the same product?** More than
  before: one truth decides her cohort everywhere, her trend carries
  her treatment's timeline factually, and her Home Screen speaks her
  grammar.
- **Day 7 / 30 / 90 value?** The flywheel unchanged (usuals,
  corrections, reads) + the widget makes the return surface ambient;
  day 30 speaks day-0 words after any reinstall now.
- **What would I most regret showing 10,000 people?** Still the
  food photos' single-copy story (p55's stand, founder-gated
  storage). Within this pass's scope: nothing — every change removed
  a regret or stopped at a gate.
- **Would I use it 90 days? Why come back tomorrow?** Yes; because
  the morning read pays yesterday back, and now the Home Screen
  holds the day's standing without asking me to open anything.

## 26. Final counts (all read from Executed lines, re-read)

**App: Executed 1565 tests, 2 skipped, 0 failures** — reconciled
EXACTLY against a STATIC count of the baseline tree: `git grep
'func test'` at `b50067e` = 1540, at HEAD = 1565; the +25 are
precisely this pass's additions (8 MedicationTruth + 3
OutcomeRestore + 6 RegimenEras + 8 WidgetSnapshot), and all 25
executed (Test Case lines counted per class). **[CORR on p57 §37]:**
p57 wrote "1540 passed · 2 skipped (1542 total)", but the baseline
tree DECLARES 1540 test funcs total — the skipped pair was double-
counted; the true p57 close was 1538 passed of 1540. This pass's
arithmetic uses totals, statically verified.

The first full run failed 2 — **my own defect, the recorded p36
mistake repeated**: MedicationTruthTests left three seeded weigh-ins
in the process-shared container and ReattributionTests' unpredicated
count inherited them. Fixed in MY files (tracked-userId tearDown
cleanup in MedicationTruthTests + RegimenErasTests); the other test
was NOT weakened; re-run green.

**PlankFood 253/253** (iPhone 17 Pro Max sim) · **PlankSync 29/29**
(SE sim) · **DayKeyVocabularyTests 3/3 under `-testLanguage ar
-testRegion SA`** · **Release BUILD SUCCEEDED, 0 errors** — on the
final tree, after the last product commit. The p56 reviewer walks
were NOT re-run: no purchase, wall, or presentation surface changed
this pass (the diff's protected-path check: Payment · Paywall ·
Auth · AppPhase · app Info.plist · supabase/ · BodyScan all EMPTY;
the two entitlements files and the widget's Info.plist changed
deliberately and are named in §6).

## 27. Final verdict

```
FOOD SNAP:                unchanged (p53–p57 proofs stand; chooser walked)
BARCODE:                  unchanged (verify-once intact; not re-attacked)
NUTRITION DETAILS:        unchanged
FOOD EDITING:             unchanged
FOOD CORRECTIONS:         unchanged (usuals/verify-once/edit notes stand)
FOOD MEMORY:              unchanged
FOOD OFFLINE/RETRY:       unchanged (p46/p55 stand; no launch-path change)
WEIGHT:                   one truth (p55 fold untouched, re-proven by suite)
APPLE HEALTH:             unchanged from p57 §14 (activeEnergy still named)
MOVEMENT:                 unchanged (p55 stance on the undecomposed sum)
GLP-1 REGIMEN:            record now outranks the questionnaire (RED→GREEN)
CUSTOM INTERVAL:          truthful (p53 engine; era arithmetic corrected)
GLP-1 DOSE HISTORY:       truthful + one era arithmetic (2 latent lies dead)
PROGRAM/TREATMENT TIME:   coherent; schedule edits no longer mint dose eras
ONBOARDING PERSONALIZATION: came_for survives reinstall (1 line, no column);
                          exact age gated on AGE1 (written, not applied)
HOME:                     unchanged visually; cohort truth unified beneath it
HOME NUTRITION VISUAL:    the band stands — decided by rendered comparison
BECOMING:                 weight detail gains factual dose-era seams
LONGITUDINAL HISTORY:     the trend now carries the treatment timeline, factually
METHOD:                   pattern engine no longer lies about dose changes
CHAT:                     envelope eras honest (era_count = real dose eras)
PRESENTATION GRAMMAR:     untouched (p57 chokepoint holds; sweep test green)
GESTURES:                 untouched
HAPTICS:                  fourth word `record()`; three commits one hand;
                          design law §8 amended
MOTION:                   untouched (p53/p54 films stand)
LIQUID GLASS:             refused as a theme again, on fresh Aug-2026
                          evidence; native tier already adopted
WIDGET:                   BUILT — small+medium, truthful timeline, one
                          precomposed contract, laws pinned across the
                          process boundary; placement = device step
ACCESSIBILITY:            seams speak (VoiceOver); widget labels composed;
                          AX5: medication page filmed clean; weight-detail
                          seam not filmed at AX5 (walker can't reach —
                          stated); becoming title mid-word break at AX5
                          named (pre-existing)
FRAME-LEVEL POLISH:       widget zero-dot caught+fixed on film; seam filmed
ACCOUNT ISOLATION:        widget snapshot retired by the sign-out sweep
FAILURE RECOVERY:         widget staleness closed by design (self-aging)
B2B RECORD READINESS:     improved — era truth reaches the envelope/packet path
APP TESTS:                1565 total · 2 skipped · 0 failures (reconciled +25)
PLANKFOOD:                253/253
PLANKSYNC:                29/29
RELEASE BUILD:            BUILD SUCCEEDED (final tree)
PRODUCTION MUTATIONS:     NONE (no SQL, no deploys, no migrations applied)
MIGRATIONS APPLIED:       NONE (AGE1 written-not-applied, in docs/)
COMMITS:                  9 product/docs commits + this record (§18)
PUSHED:                   yes (addendum verifies)
LOCAL == REMOTE:          verified at the addendum
P0 REMAINING:             0
P1 REMAINING:             0 new (standing p57 P2/P3 list carries: movement
                          sum, HRV ask-sheet, hardware-return newline,
                          nested-Button dose row, day-one card half-fade,
                          p51 §18 server-authority items; + this pass's
                          named: becoming AX5 title break)
PHYSICAL DEVICE REQUIRED: widget Home-Screen placement + App Group
                          provisioning at first archive; the standing p55
                          §37 device checklist
FOUNDER ACTIONS:          ① apply AGE1 then the documented client diff;
                          ② archive-time: verify automatic signing creates
                          group.com.bk.plankAI; ③ the standing gates (EF
                          envelope deploy · food-photos storage ordering ·
                          device checklist); ④ p57 gates ⑤ (activeEnergy
                          line) and ⑥ (dv references) remain open
```

## 28. Is another autonomous product pass justified?

**No — with one earned exception.** The convergence criteria hold:
the correctness line held under fresh attack (and gained the cohort
truth), the experience line gained its two competitor-parity
surfaces (the widget, the era seams), and what remains is founder
decisions (AGE1, the standing gates), hardware (widget placement,
TestFlight), and real users. The exception: the first session AFTER
the founder applies AGE1 should ship the documented client diff —
that is an hour of wiring against a verified column, not a pass.

---

## 29. ADDENDUM — the verified git checkpoint

Written after the push; values read back from the remote.

```
SESSION COMMITS       260afe0 cohort truth · 65314dc came_for ·
                      326aade eras+seams · 265d082 widget ·
                      6657b92 haptics · 32770c3 AGE1 · 4be3493 band ·
                      31a0a58 test hygiene · 922b209 this record ·
                      <tip> this addendum
RECORD-COMMIT PUSH    b50067e..922b209   VERIFIED
                      git ls-remote origin refs/heads/feat/app-v2
                        → 922b209fd7fed24949440810864057f8f63cfa70
                      local == remote at the record commit
FINAL PUSH            the addendum commit, verified the same way in
                      the session log (a record cannot contain the
                      hash of the commit that contains it)
DIRTY TREE            none
AHEAD/BEHIND          0 / 0 after each push
```
