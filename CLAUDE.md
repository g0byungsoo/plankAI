## Project status (2026-08-12)

**THE PORTION AND THE SOURCE (feat/app-v2). BUILT 2026-08-12.**
`docs/app_v25/27_THE_PORTION_AND_THE_SOURCE.md` is the record. The food
rail re-measured as a product inside the product. **No migration**, zero
diff against the reviewed release in Payment/Paywall/Auth/Sync/
migrations/`AppPhase`/`Info.plist`/`pbxproj`, zero HealthKit read-type
change, zero analytics vocabulary change. **THE SEAM: the pipeline knows
the SIZE OF THE THING and never learns how much of it she ate — and
every surface presents the result as if it did.** Filmed before any
change: a whole 12-inch pizza read `96 g` protein `of 90 g today`, floor
MET with a full bar, 2,200 kcal, verdict "a little over today". The
brief's lead hypothesis was micronutrients; I disagreed on its own
sentence — *a precise nutrient attached to the wrong serving assumption
is still wrong.* Vitamin D is a GAP; this is a WRONG NUMBER with a
confident ring on it. **Eight instances:** the EF has computed
`servings_in_dish` + `is_shareable` since 2026-06-23 (its worked example
says *"the app lets the user say they ate 2 slices"*) and they had
**ZERO READERS**, threaded through 8 copy constructors and dropped at
every render site · the ladder was hard-coded `1/¾/½/¼` clamped
`min(f, 1.0)`, so one slice of an 8-serving pizza was UNREACHABLE ·
`BarcodeRead` prices ONE serving at `confidence: 1.0` · **there is no
label branch in the EF at all** (the hint rides `text` into a prompt
saying "estimate for the WHOLE visible food"; `servings_per_container`
is not in the schema) · `EntryMethod.isPrintedTruth` is written as law
with **zero production call sites** · **`ResultDetailCopy.provenance`,
the FIRST surface she sees, returned "estimated from the photo" with no
door branch — the exact lie E8.1 was named for killing, one surface
upstream of where E8.1 killed it** · `read_food_day` returned
title/at/kcal/protein only, so *"was my lunch high in sodium?"* and
*"what did i correct yesterday?"* were unanswerable **from a record
holding the answer** · `applyPriors` has ONE call site (photo), so E7's
front door has no memory. **SHIPPED:** `PlateShare` — the ladder comes
from the DISH, the common plate is untouched (trigger is the model's own
`is_shareable`), the number is never changed silently (the plate just
SAYS what it is of), packaged food counts UP with
`servings_per_container` derived FREE from Open Food Facts data the
barcode door already parsed · `NutritionSource.labelDeclared` stamped at
the dispatcher chokepoint · `EntryMethod.provenanceLine` moved to the
type that owns the doors so a door cannot ship without a sentence ·
**Jeni now reads items, sodium, sugar, carbs, fat, the door and HER OWN
CORRECTION WORDS** (zero EF deploy — the allowlist gates tool NAMES, not
payloads) · the copy-constructor bug class killed (`withId` dropped
`micros` — 4th time a defaulted-parameter init lost a field).
**THE CONSENT SCREEN** (founder steered twice: *"needs a major
redesign"*, then *"is that screen fundamentally needed?"*): kept —
5.1.2(i) requires consent before a photo reaches a third party — but
rebuilt as a **FIRST-RUN PRIMER**, three teachings lifted from failure
modes the vision model names in its OWN prompt, then the disclosure,
then accept. It said everything twice before. **FRAME REVIEW CAUGHT:**
the consent card painted **every glyph twice** (`.shadow` applies per
primitive without `compositingGroup`) · the share note sat below the
fold, arriving after every number it qualified · at AX5 the dish title
and stepper truncated each other · the chip row could not wrap.
**1009/1009 app + 187/187 package** (+33). Release compiles. Doors:
`--uitest-open-camera` · `--food-debug-shared`. **FOUNDER GATE — THE EF
IS WRITTEN AND NOT DEPLOYED:** `supabase functions deploy food-vision
--no-verify-jwt` adds the label branch + serving semantics + the four
FDA micros; compatible BOTH ways, strict mode verified programmatically,
`deno check` shows the identical 12 pre-existing errors as HEAD.
**NEXT: deploy the EF, then give the WORDS DOOR its memory.**

**WHAT THE RECORD KEEPS — THE LAST 10% (feat/app-v2). BUILT 2026-08-12.**
`docs/app_v25/26_WHAT_THE_RECORD_KEEPS.md` is the record. Not an era, no
E-number: a depth pass over the layers reached by going further in.
**No migration** (none needed), no paywall/pricing/entitlement/`AppPhase`
/auth/RevenueCat/Supabase diff, **zero HealthKit read-type or purpose-
string change**, zero new analytics events. **THE SEAM, one shape in five
costumes: a layer knows something and does not say it, or says something
it does not know.** ① **HER CORRECTIONS WERE WRITE-ONLY** — E4's
fix-with-words sentences ride the JSONL AND `food_logs.payload` and
`FoodLogEntry` had no field for them, so the plate said "read from your
photo · ranges, not exact" the morning after she fixed it. Now
`corrections`/`wasCorrected` + a **YOUR NUMBERS** tier (her words, in the
transcript's DMSans + `jeweledRose` — serif italic was my error, caught
by the chat's recorded founder ruling), `relog` + `reattributeEntries`
carry them (that call site has dropped a new field **3 times**).
② **MICRONUTRIENTS REFUSED ON EVIDENCE** — one source (USDA FDC), reached
only for items the model flagged <0.5 confidence or couldn't price;
`llm_direct` (the default), OpenFoodFacts, `canonical_pantry` and the
label door publish NONE, so micros exist *precisely where the plate
deserves least confidence*. NOT persisted. The live panel was the bug:
`namedMicros` summed partial coverage and labelled it the PLATE's → now
gated on the whole plate being grounded (`publishesMicros`). **The QA
harness hid it** (`mockItems` attaches micros to `.llmDirect`, which is
impossible). ③ **MOVE** — the "dashed divider" **does not exist** (it is
seven below-half rhythm dashes; circles now); `0 of 2` in 44pt under
"what your body did" → **a count is a hero only when there is something
to count**; "twice a week" was said twice; **`steps 0 · from health` was
an absence in a sensor's clothes**; the last rose primary button went
ink; an underlined text link → hairline capsule; `MoveRecord.isEmpty`
finally reached a screen; provenance didn't scale. ④ **THE DETENT**
(founder mid-session: "3/4 or almost full screen") — Move sat on
`tallFixed` 0.68 with the grabber hidden, so it opened already scrolled
with no way to expand; **five items fit at AX5**. Now `.large`. Dose +
side-effect sheets walked at `.tall` and fine — Move was the one wrong
pick. ⑤ **THE DESK'S PROOF EXPIRED EVERY MIDNIGHT** (E6 scoped proof to
TODAY, the window most likely empty at open) → yesterday + record-depth
rungs; and the "what did i eat yesterday?" starter was **inverted**. The
void is ~23%, not 40%, and was never the defect. ⑥ **`JKSheetChrome`**
header text had no `fixedSize(vertical:)` → lost the height competition
to a flexible ScrollView and cut a dish name with two thirds of the sheet
empty below it. Not an XXXL issue. **1009/1009 app + 154/154 package**
(+14 tests). Doors: `--uitest-plate-corrected` ·
`--uitest-food-yesterday-only`. **Next build's best food work, named not
smuggled: the food-vision schema should read the four FDA-mandated label
micros (vitamin D · calcium · iron · potassium) — needs an EF deploy.**

**APP v25 E9 — THE COHERENCE PASS (feat/app-v2). BUILT 2026-08-12.**
`docs/app_v25/25_E9_THE_COHERENCE.md` is the record. A product +
design sweep on top of the release build; **no migration, no paywall/
pricing/entitlement/AppPhase/auth change, analytics additive only.**
The thesis, from walking the running app first: **nutrition was the
only domain that never became an INSTRUMENT** — everything else has a
shape, nutrition had one ring and rows of equal-weight numbers
everywhere else. Principle: **two nutrients earn a shape, everything
else earns a place.** FOUR THINGS THE RECORD HAD WRONG: E6's "the
three food entrances converge on one reading" is FALSE
(`PlateDetailSheet` is a fourth, oldest reading, still leading with
`340 calories` against the product's own §9 law) · **hydration already
shipped and shipped wrong** · the garish plates in THE BOOK were the
**QA seeder** (0.32-0.55 saturation over the full hue wheel — two eras
reviewed those surfaces against banned colours) · "`--uitest-open-
method` presents but does not render" was the engine correctly
returning SILENCE. **HOME: the five-face carousel is GONE** (its four
trailing faces each duplicated the lead face's own tiers) → one
composed instrument: THE FLOOR (protein's ring) → THE DAY (energy as
ONE shape, kcal stated once) → THE REST (fiber · sugar · sodium,
aligned). ~280pt not ~750; the to-do list is above the fold; the shear
bug class is gone by construction. **THE PLATE READING is protein-
first** in the same tiers via the same kit object. **`JeniRing` phase
fix** (gradient `angle: -90` AND shape `.rotationEffect(-90)` → the
ramp sat a quarter turn behind its own arc; hard seam at a met floor).
**HYDRATION: the number left, the reason stayed** — `jenifit.default`
(the CONSUMER protocol) hardcoded 1,800 ml from ASMBS *post-bariatric*
guidance; no credible body prescribes a personal fluid volume and
restriction is standard in HF/CKD/hyponatremia → `Int?`, nil by
default, a care team's aim renders attributed. **NOT built:** a water
tracker (near-null evidence for this cohort) or the HealthKit
`dietaryWater` read (deferred — needs a new type in a purpose string
that shipped one build ago). **METHOD 13 → 15 notes**
(`fluidsOnAQueasyDay` · `constipationWithLowFiber`), both on her own
record, both forbidden a volume by test; E8.1's architecture re-read
and NOT re-litigated; B2B unchanged. **XXXL caught four breaks** (the
greeting stranded its comma; the day tier + legend truncated; the
tools grid truncated every title) — all fixed, SE clean.
**1002/1002 app + 140/140 package.** Correction for future sessions:
437 `.font(.custom(_:size:))` calls without `relativeTo:` are NOT
Dynamic Type bugs (`.custom(_:size:)` scales); and the sim argument is
`content_size`, not E8.1's recorded `content-size`.

**RELEASE PROOF (2026-08-12). 1.2.0 (30) UPLOADED TO APP STORE CONNECT.**
STATE.md §0.-15 is the record. Zero product code changed. Archive →
Cloud-Managed-Distribution export → **UPLOAD ACCEPTED 00:12 PT**
(build 30 was new to ASC — a duplicate would have been refused).
Release binary proven clean by `strings`: 0 `--uitest` / 0 `--debug`
/ 0 demo-backend; prod Supabase + PostHog only. Release sim walk:
wall resolves live prices + restore + X; no launch flash; XXXL wraps.
Analytics trust boundary frozen in
**`docs/app_v25/24_MEASUREMENT_CONTRACT.md`** (binding): production
data = `environment='production'` ∧ no `is_test_user` ∧
`app_version ≥ '1.2.0 (30)'`; 10 questions, min-n gates, no era
decision before n≥100 payers or 6 weeks. The 5.6 fix
(`WallExitIntent`, total, one-offer-then-stand-down) rides this
build. **Founder residue: ASC processing→TestFlight watch · one
TestFlight event reads `environment: testflight` · ~12-min device
acceptance test · verify the LIVE listing against the current product
(repo metadata doc is a v1.0.0 fitness draft — real 2.3 risk) ·
create/attach 1.2.0 + submit with 5.6-fix review note. NEXT SESSION:
WAIT FOR DATA — no E9 without the contract's first clean read.**

**THE SHIP (feat/app-v2 → origin/main). PUSHED 2026-08-11.**
STATE.md §0.-14 is the record. The convergence session: no new era, no
new retention theory. Re-measured: **three E8.2 founder gates were
already closed** (14/14 migrations applied remote; jeni-chat deployed
byte-identical; food-vision deployed same day) — stale-gate lesson
again. Closed: the HealthKit purpose string finally names
workouts/distance/active energy (the ask shipped in E8.2, the consent
sentence didn't) · the evening close was UNMEASURED (zero events on the
release's central loop) → `evening_close_shown` + `evening_intention_set`
+ `has_intention` on the morning read, carried by the RENDER not the
stored key · BuildChannel audited clean against the StoreKit-environment
confusion (receipt FILENAME = distribution channel; purchases never
consulted). Walked 26 states; 7 walk-caught fixes, all re-filmed: the
hero carousel MEASURES its faces now (the fixed height had sheared
three different rows across three eras) · one-column strip at XXXL ·
the paper fade under the status bar · method note at optical centre ·
18 letter run-ons → sentences · one gram grammar ("76 g") across all
food surfaces · protein-forward evergreen chips. B2B walked: "assigned
by your care team. you record what you took." **999/999 app + 140/140
package + MoveHealthProof + SayItWalk 4/4 solo; unsigned Release
archive compiles.** Hard paywall untouched; `e5.firstPlate.enabled`
still false. **Founder residue (all of it): archive/upload 1.2.0 (30)
· confirm `environment: testflight` on one TestFlight event · device
walk (Move rows from a real watch + the words path once).**

**APP v25 E8.1 — THE LEGACY SURFACES (feat/app-v2). BUILT 2026-08-11.**
`docs/app_v25/23_E8_1_THE_LEGACY_SURFACES.md` is the record. Two jobs:
close E8's two named ship-blockers, then bring Method, Breathwork and
Workout into the current product. **The hard paywall stays** (empty diff
over all six paywall/payment/entitlement paths; `e5.firstPlate.enabled`
still false). **FOOD SOURCE**: `CaptureSource` DELETED, `EntryMethod` is
the one vocabulary in the row + the event + the plate; migration
`20260811120000` widens the CHECK by definition-scan not by name (a
name-only drop would silently add a second contradictory constraint);
**no shipped value renamed**; tested through the real chain — 14
migrations clean and replayed 3× on a scratch Postgres 17, 12 values
accepted, 4 refused, history intact. The lie cost more than analytics:
**PlateDetailSheet told a user her TYPED plate was "read from your
photo"**, the "dining out" title branch was dead, relog inherited a photo
it never kept, and **the chooser's again door fired NO `food_log_saved`**
so every food funnel undercounted the cheapest door. **PROTEIN CLOSE
FILMED** via `--uitest-protein-gap N`, which works BACKWARDS from the
floor so the branch is exact for any formula; E8 named two hour sources,
**there were three** (`HomeView.greeting` read the wall clock) →
`AppClock`. **METHOD: a curriculum became a JITAI.** 84 day-indexed
lessons could only ever deliver lessons 1-2 to a 2.0-day median payer
(464 openers/90d, 23.5% payers, 1.66 days each, 39 lifetime completions).
Evidence-led: **Koh et al 2025 (JMIR 27:e76625), 35 JITAI weight studies
— educational information used in 5; prompts 33, feedback 24; 68.6%
rule-based.** 13 notes, each with WHO/WHEN/WHY/AFTER/QUIET + a required
action; rejected domains recorded with reasons; **`RepEngine` already
held ten good interventions keyed to `canonicalDay`** — the content
existed, it fired on a calendar. **Silence is a return value; no
fallback.** B2B: a clinician's note IS `MethodNote` with
`authority = .careTeam`; override/add/suppress/expire/end built + tested;
attribution is a word plus a drawn mark, never colour. One Jeni via
`method_told`/`method_now` in the envelope (zero deploy). **BREATHWORK
survives** on the craving/impulsivity RCT (Complementary Medicine
Research 2024;31(4):376); the **female-presenting photograph deleted**,
the cortisol-holds-fat chain gone, the glossy heart retired. **MOVE**:
`MovementService` read four HealthKit signals and dropped all four;
strength is the headline (lean mass = 25-39% of the loss); **energy is
measured or absent**, the only estimate is MET-based from her own entry,
labelled, never written back to HealthKit; the workout library is NOT
retired but now has a measurable retirement trigger; `EnergyLedger
.bmrFemale` hardcoded the female constant under "the cohort is
exclusively women" — a unisex defect in ARITHMETIC, and dead. **THE
RESTING NUTRITION STRIP REDESIGNED** (founder: functional but not
minimal): each cell was ONE serif string so "420 of 2,300 mg" made
**sodium the loudest thing on the screen**; a cell is PARTS now, values
right-align down one edge, `dv` rows get full width. **997/997 app +
140/140 package.** Walk-caught: three hour sources, the photograph and
its void, Move unpadded, "3 of 2", a hardcoded "two", the cover racing
the snapshot, once-ever notes filmable once per sim, XXXL truncation, the
strip shearing twice — and an XXXL check I nearly claimed without doing
(`content-size` vs `content_size`). **Founder gates**: `supabase db push`
(**FIVE** migrations now) · `git merge --ff-only` + push · archive/
TestFlight 1.2.0 (30) · **confirm `environment: testflight`** · device
walk of the words path AND Move against real HealthKit. **Open debt**:
Move's HealthKit rows unverified on device · the
medication-discontinuation note is the highest-value content in the
domain and unwritten because the signal does not exist ·
`--uitest-open-method` presents but does not render (`--debug-method-note`
does) · `EnergyLedger.spentKcal`/`isLighterDay` dead · the old 84-lesson
corpus unreachable but bundled.

**APP v25 E8 — THE MERGE (feat/app-v2). BUILT 2026-08-11.**
`docs/app_v25/22_E8_MERGE_AND_LEDGER.md` is the reconstructed state +
the release ledger. Convergence, not a feature era. **The hard paywall
stays** (empty diff over all six paywall/payment/entitlement paths;
`e5.firstPlate.enabled` still false). **THE BRANCH STATE, MEASURED:**
"475 commits" was wrong and so was the ref — local `main` was a stale
pointer **343 commits behind origin/main**. Real figure vs origin/main:
**149 commits, 427 files, clean FAST-FORWARD** (conflicts structurally
impossible). Local main reconciled; the push is a founder gate.
**TWO GATES WERE ALREADY CLOSED** — `jeni-chat` deployed is
byte-identical to local, `food-vision` differs by one code comment;
E3-E7 each re-recorded a gate nobody re-measured. **TWO MIGRATIONS WERE
NEVER LISTED** — four unapplied, not two (`20260804090000` p6 +
`20260811090000` care RPCs join v24's and E1's; lexicographic =
dependency order). **WHY PRODUCTION COULD NOT ANSWER ANYTHING** (E6
called it a fact of nature; it was three defects): TestFlight compiles
as RELEASE so every internal tester sat inside every production funnel
→ `BuildChannel` resolves debug/testflight/production at runtime from
the receipt · E7's own falsification test was unmeasurable because ONE
shared decoder stamps `source: photo` for a photograph, a nutrition
label AND a typed sentence → `EntryMethod` on `food_log_saved` · the
words path fired NOTHING, so every scan funnel excluded E7's own door.
History cannot be reclassified; no attempt made. **HOME: PROTEIN
LEADS** (the §9 law was still inverted on the most-seen surface; E7
deferred it citing carousel deep-links — nothing deep-links into it).
Founder steers: floor bar → **ring** · **resting nutrition strip**
(kcal + macros + fiber/sugar/sodium, no paging) · **steps always stand**
in the to-do list as an offered row (excluded from `actionableBeats`,
never debt) · denominators **only where one genuinely exists** — kcal is
hers, fiber/sodium quote the FDA DV marked `dv`, carbs/fat none, and
**sugar deliberately none** (the FDA limit is on *added* sugars; this is
*total*). **THE EVENING CLOSE, TWICE**: "that's the day, maya." became
her record + tomorrow's reason (`EveningCloseEngine`), every tappable
word became a rose chip; then an expert review the founder asked for
found the screen **made seven asks and paid out once, always on day
N+1** on a base whose median payer lives 2.0 days → **THE PROTEIN
CLOSE** ("there is still time tonight. 18 g would close it…") with a
door into E7's describe path, the only line that can change TODAY and
the clearest case for a number a GLP-1 user cannot feel; `sitAck` moved
off "tomorrow". NOT done (settled decisions, founder's call): cutting
the day-number hero + the nightly trend row. **UNISEX**: the first 48
hours are already clean; fixed the `voicePlaybook` whose north star was
"the smartest **girlfriend** you've ever had" (lesson content
byte-identical, verified); the 64/84 figure conflates **22**
reader-assumed-female · **39** third-person · **3** study populations
(preserve). **942/942 app + 133/133 package.** Walk-caught: the protein
face left ~120pt of void once it led; the strip sheared its second row.
My own tests lied twice — the exact E7 §5.4 trap. **Founder gates**:
`supabase db push` (4 migrations, in order) · `git merge --ff-only` +
push · archive/TestFlight 1.2.0 (30) · device walk of the words path ·
**confirm TestFlight now stamps `environment: testflight`** (if it does
not, every cohort read is still contaminated). **Open debt**:
`food_logs.source` still lies in the synced record · pre-E8 analytics
can never be de-contaminated · the Method corpus' 22 lessons · the
protein-close gap branches are test-pinned but unfilmed.

**APP v25 E7 — SAY IT (feat/app-v2). BUILT 2026-08-11.**
`docs/app_v25/20_E7_DECISION.md` is the why + the hypothesis (written
before the build); `21_E7_EVIDENCE.md` the record. Founder decisions
obeyed: **the hard paywall stays** (`e5.firstPlate.enabled` false,
paywall/pricing/tiers/downsells/entitlement/AppPhase **untouched** —
verified by an empty diff), and the redesign continues.
**The era: putting something into the record must cost one sentence,
and the record must answer in the same breath.** One defect wearing
three costumes, all found by walking: the only wide door to the record
was a CAMERA (the cheap words path already existed, buried behind a
"snap instead" link inside the lens; 3.4% ever start a scan) · the
reading led with CALORIES against the product's own law
(`00_THE_SYSTEM` §9 "protein floor + fiber lead; kcal quiet", from
§7.6's finding that protein 1.2-2.0 g/kg is one of exactly two proven
GLP-1 pillars) · and nothing answered back at the moment a record
landed, on a branch where every intelligence pays out on day N+1 and
the payer median is 2.0 active days.
THE DOOR IS WORDS (`ScanChooser` asks "what did you eat?" over a field
with today's protein under it; E5's two big doors survive at full size
— the founder compared a pill-based cut and kept E5's; `Route
.foodDescribe(spoken:)` sends her own return key straight to the
estimate, jeni's prefill still waits) → PROTEIN LEADS (full width, the
floor as denominator; the kcal ring DELETED) → THE ANSWER
(`PlateAnswerEngine`, pure, 10-case honesty table over the SAME
`TodayStateService`/`TargetsService` inputs; the grid MORPHS into one
sentence then files; no floor on file → no denominator, ever).
**Founder steers taken mid-build**: side-effect rows → pill cloud ·
`JeniSheetHeight` token (`.medium` was HALF a screen) across 15 call
sites · a donut replacing three bars + the split bar · fiber/sugar/
sodium visible at rest · **vitamins + minerals, which `USDAClient` had
parsed since v1.0.9 and `CalorieMathService.compute` silently dropped**
(carried through now; zero means UNKNOWN and renders nothing).
**890/890 app + 125/125 package + 4/4 walk.** New doors:
`--uitest-file-plate`. Also fixed: the steps ring's **Metal shader**
(peach-gold at 30fps, off-palette, reported twice and never fixed) and
`--uitest-wipe-food`, which never worked — **not** "QA cloud pollution"
as E4/E6 both recorded, but `--uitest-seed-program` re-seeding after
the wipe in the same launch. **Below the bar**: the Method corpus
(measured: **62 of 84 lessons carry female-coded language** — an era
of its own) · Method/breathwork photography · the workout library ·
**Home's hero carousel still opens on calories** (the same law, still
inverted on the most-seen surface — fix this first) · the desk's dead
space. **Next era per §12: THE MERGE** — seven eras are stacked on an
unmerged branch and none of them, including E7, can be falsified until
they meet a payer.

**APP v25 E6 — THE DESK (feat/app-v2). BUILT 2026-08-11.**
`docs/app_v25/19_E6_DECISION_AND_RECORD.md` is the why + the record.
Founder steer of the same date: **E5 THE FIRST PLATE SHIPS OFF** —
the hard-paywall funnel is under an active production test and
proof-before-paywall is a separate experiment. Production order is
unchanged (onboarding → hard paywall → purchase/entitlement → jeni);
the flag is now an explicit ENABLE (`e5.firstPlate.enabled`, default
false) because a `disabled` key fails OPEN. Both states verified.
**THE DATA STOPPED**: with the paywall staying, the addressable
population is payers (~2/day, median 2.0 active days), and an attempt
to let day-0 actions pick the era FAILED — breathwork is a scripted
step of `PostPurchaseFlowView`, and 105 of 160 `main_tab_appeared`
users never purchased on a hard-gated app (internal builds). Production
data cannot currently discriminate between in-app features; the binding
constraint is quality. **Three things I expected and found wrong** (all
caught before building): the food reading is NOT a spreadsheet
(`--uitest-plate-detail` opens the Home sheet, not `SnapResultView`);
the three food entrances ALREADY converge on one reading; the describe
header's ♥ is a SANCTIONED brand mark per `JKMarks`. **THE DESK**: the
chat's resting line goes from claim to proof in the same real estate
("your coach, day to day." → "4 plates and 123 g of protein, on
file.") via `JeniDeskAwareness`, a pure engine over the SAME
`TodayStateService.snapshot` the starters read; empty falls back to the
claim, "0 g" never renders, a gap is stated warmly and pinned against
ten reprimand words, the E4 G9 care gate survives. **869/869 app +
125/125 package.** New door: `--uitest-wipe-chat`. **Below the bar,
observed NOT fixed**: the steps detail's orange gradient ring
(off-palette) · the Method reader's female-only photography + its
"she's being good today" lesson line and breathwork's imagery (unisex
debt in an 84-lesson corpus + asset library) · the reading leads with
kcal where the law says protein leads.

**APP v25 E5 — THE FIRST PLATE (feat/app-v2). BUILT 2026-08-11; SHIPS
OFF behind `e5.firstPlate.enabled`.**
`docs/app_v25/17_E5_DECISION.md` is why this era REPLACED the roadmap's
dispersal era; `18_E5_EVIDENCE.md` the record. **The finding: every era
before this asked why people don't come back; this one asked who ever
arrives. Measured per app version — 1.1.6: 236 onboarded → 18 saw the
main app (7.6%) → 20 purchased; 1.1.5: 200 → 21 (10.5%) → 18; 1.1.4:
103 → 6 (5.8%) → 6. Essentially everyone who gets in is a purchaser.
`paywall_view` 2,436 users → 172 purchases (7.1%): the wall is the
most-seen surface Jeni has. Payers (n=151) have a median 2.0 active
days. E1-E4 currently serve ~20 people per release.** The gate is
`AppPhase.swift:84`; `00_THE_SYSTEM` §12 already BANNED "paywalling the
record" and r1 §9 already named a competitor's paywalled log as the
trust opening — the product was doing the forbidden thing. The era:
proof before the ask. THE PROOF PHASE (`AppPhase.proof` mounts the REAL
`CaptureFlowView` + real vision EF + real `FoodLogPersister`; ONE plate;
it persists so paying later opens a record that already has it; pure
`derive`, exclusion set pinned: resolved · ever-entitled · legacy
footprint · entitled · flag off) → WHAT IT MEANS (`FirstPlateReading
Engine`, pure, 12-case honesty table: protein leads, kcal only when
protein cannot, NO floor without a weight on file, coarse words never
percentages, no verdict; floor = `TargetsService.proteinTargetG`) → THE
WALL EARNED (`WallReason.afterProof` on ExpiredWelcomeView's two-state
precedent, so **PaywallView is untouched** — price/tiers/bands/downsell
/exit-intent all unchanged) → THE SCAN CHOOSER REBUILT (founder's direct
ask: nested tiles gone, four geometries → two, bottom-anchored,
ink-over-blur, meal door FIRST, **the doors are made of her record** —
her last photographed plate on the meal door, the dish named on the
again door; the body door stays drawn per L4). Found by looking, not
testing: the food-AI consent sheet named **Anthropic** as a recipient of
her photo when nothing in the repo calls it (corrected); a QA door
overrode the outcome getter so a walker leg passed while sitting on the
invite (rewired + assertion strengthened); an empty capture now gets ONE
retry. **857/857 app + 125/125 package; walker 4/4.** Doors:
--uitest-force-first-plate · --uitest-first-plate-done ·
--uitest-first-plate-noweight · --uitest-wipe-food. Founder gates: the
standing set + **the business call** (this changes the ORDER of the ask,
not the model; kill switch `e5.firstPlate.disabled` restores the exact
pre-E5 gate in one line) + device walk + post-merge read of
`first_plate_*`. Named debt: the ~128 `woman-doing-X` workout animations
are 100% female-presenting and ARE reached (203 users/90d) — reported,
not fixed, because the fix is roadmap E3's library kill.

**APP v25 E4 — DAY TWO (feat/app-v2). BUILT 2026-08-11; rides the
same RC 1.2.0 (30). NO migration.**
`docs/app_v25/14_E4_DECISION.md` is why (the founder's day-one
brief + fresh PostHog: **day-0 food loggers return at 76% vs 17%;
the scan funnel completes 100% once started but 3.4% ever start; a
day-1 user who logged 2 meals + a weight woke to ONE berry ring**);
`15_E4_DAY_TWO.md` the law; `16_E4_EVIDENCE.md` the record. The
era: everything given on day N returns as understanding on day N+1.
THE MORNING READ (`DailyBriefEngine.YesterdayReceipt` + the week-one
day-two clause; kept-promise finally reachable, "proud" read back,
first weigh-in acknowledged; prose/ledger de-dup law) → THE PLATE'S
MEMORY (corrections PERSIST via payload jsonb; `PlatePriors` pure
engine — corrected dishes only, exact-title, ±15% band, revertible,
PHOTO only; "your numbers" row + "use the scan"; AGAIN ships — the
chooser's third door → RecentMealsSheet, ≤3 taps; cuisine-profile
threading bug dead) → ONE CHOKEPOINT (any plate marks the beat —
camera/book/again/jeni) → ROUTES ARRIVE (becoming consumes its own;
jenifit://plates opens THE BOOK; recap shows the whole day) → THE
BRAIN UNSTARVED (ladder 7→3 — five ids had saturated the budget
forever; the morning rung carries yesterday's record; milestone
retry; lapse_support's dead branch fixed). Becoming's 13-row
zero-wall compresses to one sentence + disclosure; desk subtitle
care-gated. **830/830 app + 125/125 package; the DAY-TWO LOOP
machine-walked green (again → mark-without-camera → the book).**
Doors: --uitest-open-again-sheet · --uitest-seed-week (launch) ·
--uitest-open-food-journal (any tab). Founder gates: the standing
E3 set (deploys, migrations, archive, THE MERGE) + E4.1 (the ONE
clarifying question rides the food-vision deploy) + device walk.
Named debt: QA cloud pollution (deterministic QA account
accumulates seeds, survives erase; needs a wipe door). The gap
map's "THE BOOK has no door" was WRONG — door exists, QA arg was
tab-gated (corrected).

**APP v25 E3 — ONE JENI (feat/app-v2). BUILT 2026-08-11; rides the
same RC 1.2.0 (30). NO migration.**
`docs/app_v25/11_E3_DECISION.md` is why this era REPLACED the
roadmap's movement era; `12_E3_ONE_JENI.md` the law;
`13_E3_EVIDENCE.md` the loop's record + founder gates. **The decision
turned on one number: 82% of everyone who finishes onboarding has
exactly ONE active day (28 of 2,237 ever reach a second week), so
every mechanic five eras shipped speaks only to a tail that barely
exists.** Bloom (arXiv 2510.05449, RCT N=54) supplied the mechanism:
5.6× app time for an LLM with tool access to the user's own data,
write access to the structured plan, and memory — and its lesson that
users named *plans, not chat*. So: the coach can READ her record
(`JeniReadTools`, 8 lookups over the SAME engines the surfaces
render from; honest emptiness — an unlogged day is "not logged",
never zero; suppression + never-brand hold) → REMEMBER what she is
told (`JeniMemoryRecord` + `MemoryGuard` refusing doses/diagnoses/
symptoms/body judgements at the door; written only through a card;
`what jeni remembers` in settings with per-row forget) → CHANGE THE
PLAN IN WORDS (`propose_program_fact` through `ProgramFactStore`:
chat writes `preferred` only, a **prescribed head REFUSES** and
routes, the clamped value is what gets acknowledged) — all through
the same chokepoints as the weekly read. THE TOOL LOOP was the
structural fix: `ChatSession` used to run a tool and stop, so a
read's result could never reach the model. Tools now live
CLIENT-side (`JeniToolCatalog`, allowlisted server-side) — the last
jeni-chat deploy a tool addition needs. **The 08-10 unisex sweep
missed both EF prompts** ("a program for women", "serving gen-z
women"); rewritten, plus the CA/IL/TX identity line ("jeni is a
digital coach. not a person, not your clinician."). 809/809 (+26,
zero regressions); the compounding loop FILMED (a sentence in chat →
Today composes "6,000 steps"); 6 frame-caught fixes. Doors:
--uitest-chat-read · --uitest-chat-propose · --uitest-chat-auto-
confirm · --debug-jeni-memory · --uitest-seed-memory. Founder gates:
**deploy jeni-chat AND food-vision** (the prompt still says "gen-z
women" in production until then) + the standing migrations/merge.
Movement (old E3) and the workout-library kill are DEFERRED, not
cancelled; the method library is NOT killed (132 post-onboarding
openers make it the #2 activity — the audit's REMOVE line was about
the literature, not this corpus).

**APP v25 E2 — THE MEDICATED YEAR (feat/app-v2). BUILT 2026-08-10;
RC 1.2.0 (30) — lands WITH the main-merge release, not behind it.**
`docs/app_v25/08_E2_BRIEF.md` the mandate; `09_E2_MEDICATED_YEAR.md`
the architecture + 10 recon corrections; `10_E2_EVIDENCE.md` the
loop's record + founder gates. The medication platform became part
of the adaptive intelligence: COHORT IDENTITY as PostHog person
properties + the dark v24/E1 events wired + AnalyticsHygiene
allowlist-as-mechanism (the kill/redirect trigger: medicated share
readable post-release) → THE CYCLE (`CyclePosition`: event-anchored
day 1..7, open slot outranks the rhythm, zero daily/non-med leakage)
→ LABEL FACTS on `MedicationCatalog` (7 products verbatim vs
2025/26 FDA PIs, per-label frames, compounded = no-label truth,
routing always closes) → the late door WIRED (openLateSlot → Today
support row + DoseSheet late face + label card; tap/quick-mark/
evening-yes converge on THE SLOT) → food noise + underreported
symptoms (hair/menstrual/cold/mood; mood = 988 support FIRST;
severity re-record fixed) → `foodNoiseReturn` signature observation
(≥3 cycles, 2-day cluster) → WEIGHT INTELLIGENCE
(`WeightWeekReadEngine`: time-aware EMA τ9.5d, clamp, unit-error
rejection, ±0.25%BM/wk band, sufficiency ladder) → THE READ GROWS UP
(dose-week story + weight signal in the band + cycle/era/plateau
teachings under offer-first precedence; richer never longer) → Today
reasons with the cycle ("your dose day. the week starts here";
late-cycle appetite named; evening ask scoped to open-dose evenings)
→ chat one-jeni (cycle_day/basis + open_dose_slot + week{} envelope;
EF cycle rule — founder deploys) → VisitPacket reads the real
symptom timeline → `SnapRefineMerge` correction-scope guard (the
SnappyMeal ablation defense) + FoodCorrectionSheet swept. 783/783
app + 113/113 package (+74/+7, zero regressions); films
frame-inspected (5 frame-caught fixes). NO new migration. Doors:
--uitest-seed-medication late · --uitest-open-side-effects ·
--uitest-expand-mood. Founder gates (10_E2 §5): v24+E1 migrations ·
jeni-chat deploy · key rotation · archive/TestFlight 1.2.0(30) ·
merge feat/app-v2→main · device walk · post-release PostHog read of
the medicated share (kill/redirect).

**APP v25 — THE SYSTEM (feat/app-v2). E1 THE SPINE SHIPPED 2026-08-10.**
`docs/app_v25/00_THE_SYSTEM.md` is the MASTER PRODUCT PLAN (the law
for eras E1-E7); `05_E1_SPINE.md` the build architecture;
`06_E1_EVIDENCE.md` the loop's record. E1 shipped ONE PROGRAM WITH
MEMORY: program_facts authority chains (prescribed › preferred ›
recommended › defaulted; consent-gated recommendations; iOS never
writes prescribed; prescription end RESUMES preference) through
`ProgramFactStore` (the RegimenService law generalized; v4 knobs
write-through) → THE WEEKLY READ (ReSigningView/WeeklyReview
EVOLVED: anchor ladder preference › dose-day › enrollment, composer
signals vs her own usual, v4 rules lead the ONE offer, step-goal
recalc + logging lighten join, 14-day cooldowns) → THE WALKING
ACTION (AdaptiveStepsEngine 60th-percentile-of-own-days; composes
only with a consented goal; "2,100 steps left"; HK workouts absorb;
resolved-goal auto-complete) → THE NOTIFICATION BRAIN (veto arbiter:
≤5/wk hard budget, same-id replaces free, medication exempt from
everything, auto-silence + engagement reset, FNV holdouts) →
lifecycle telemetry (categorical only). 709/709 (+122, zero
regressions); the loop FILMED: read → "let's try it" → fact →
relaunch → Today "0 of 3" with the walk row → survives again.
Doors: --uitest-force-read-day · --uitest-walk-read(-decline) ·
--uitest-read-prefer-steps · --uitest-force-hour N ·
--uitest-steps-today N. Founder gates: apply 20260810090000
migration (stacks after v24's) · device walk · teaching-lines voice
pass. Next eras per 00_THE_SYSTEM §15: E2 THE MEDICATED YEAR → E3
KEEP WHAT YOU BUILT → E4 THE PLATE'S MEMORY → E5 THE DISPERSAL → E6
THE QUEUE → E7 THE GLANCE.

**APP v24 — THE REGIMEN (feat/app-v2). SHIPPED 2026-08-09.**
`docs/app_v24/00_REGIMEN.md` is the law; `01_EVIDENCE.md` the
loop's record. The medication experience rebuilt as a PLATFORM
(MeAgain + Shotsy studied, nothing copied): MedicationCatalog
(9 products; new med = one entry) → RegimenPlanRecord as
append-only VERSION CHAINS (`applySelfRegimen` chokepoint;
supersede never mutate) → DoseEventRecord (deterministic per-slot
ids; every surface converges) → symptoms on the chart. Engines:
schedule (wall clock, DST-safe, weekly late window), rotation
(suggests, never insists), patterns (timing-never-causality;
"picked up after the dose changed"), reminders (FIRST actionable
category: taken / in an hour / log later; never named; survives
breaks). THE DOSE SHEET (site cells pre-selected by rotation, ink
mark, skip reasons, late + oral faces); daily cadence rides as
support OUTSIDE the cap (never dominates); 4 consult beats for
current cohort (clinic door skips all); THE REGIMEN home (facts as
doors + THE RECORD eras + side-effect logger); becoming tile
(tally strip + DOSE ERAS ledger); chat envelope medication{}.
587/587 units; consult walker green. Doors:
--uitest-seed-medication <injectable|oral|b2b|history> ·
--uitest-open-dose-sheet · --uitest-walk-medication. Founder
gates: apply 20260809090000 migration · deploy jeni-chat EF ·
device walk. Tradeoffs (law §11): no PK curve, no site photo, no
lock-screen skip, era ledger over annotated curve.

**APP v23 — THE STILL LIFE (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v23/00_STILL_LIFE.md` is the law; `01_EVIDENCE.md` the
loop's record. The food experience reborn from zero: one material
story (glass → understanding → paper → book). THE DIAL (SnapDial —
morphing hairline plate, the reading closes the circle) replaced
brackets+sweep; full-bleed IMMERSION shipped; barcode (live VN +
OpenFoodFacts by code) + label (EF text-hint, zero deploy) modes;
THE READING is ONE page (carousel dead, Result/ subtree deleted,
"add it", no scores); THE BOOK (day spreads, photos lead, month
seams, week read, relog re-homed). PlankFoodTests run via the
package scheme (106/106 — palette pins finally execute); app
557/557. Doors: --food-debug-mode · --uitest-seed-week ·
--uitest-walk-book. Queued: chip→row flash, plate page = reading
read mode, filing beat, device walk, XXXL floors.

**APP v22 — ONE HAND, first pass (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v22/00_ONE_HAND.md` is the law: consistency gate, THE
MODULE CONTRACT (B2C/B2B by composition, never forks), propagation
map, THE METHOD rethink (ONE IDEA ONE ACT cards — design bound,
build queued). Shipped: THE FOOD EXPERIENCE — FoodTheme palette came
home (it had drifted a full era; PlankFoodTests isn't in the scheme,
so its pins never ran), plain scan captions + halved sweep + "add it
before you eat", SnapUnderstandingChips (real items land on the
photo — honest theater), protein floor bar + plate split on the
result, sage/amber retired, last heart died. testGrantCameraOnce
primer (sim ignores simctl camera grants). Queued: body motion pass,
moments/chat/settings sweeps, METHOD slice, journal sweep, B2B
registry surfacing.

**APP v21 — THE INSTRUMENT (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v21/00_INSTRUMENT.md` + `01_EVIDENCE.md`. The founder's
product redesign after the v13-v20 refinement line (those eras live
in the design law's migration log): the app surfaces communicate
VISUALLY first — the rose ramp became the data language (blush ·
dusty · berry; quantities fill rose, trajectories draw ink,
selection stays ink; clinical stays unadorned); Home = one-line
header + the five-face HERO CAROUSEL (ring with counted numeral
inside) + JeniTaskRow checklist objects (real plate photo chips) +
JeniToolTile destinations with live instruments + the close as a
row; Becoming = numeral-first body card, scope-bar-as-header, rose
tile faces, five-breath detail reveal. 557/557 units; anatomy +
zero-data + gallery legs solo green; XXXL floors walked. New door:
--uitest-walk-carousel. Gotchas: a stale TEST BUNDLE lies (rm the
runner + build-for-testing + watch Compiling); iOS launch snapshots
impersonate the old build after reinstall — wait past the cold
start before judging a capture.

**APP v12 — THE CRAFT PASS (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v12/00_CRAFT.md` + `01_EVIDENCE.md`. Architecture
untouched; presentation 100×: the glance layer
(JeniGlance: ring · metric bar · week dots · scope bar · insight
pager + the visibility gate), the chart-craft maturation in
JeniChart (smooth monotone lines, grounded bars, emphasized today;
JeniRibbon/JeniPillBars deleted), Home's nutrition centerpiece
(landed plates MORPH the numeral+ring forward), the living greeting,
tools-as-destinations, directional recap, Becoming's time scopes
(morph never reload) + real mini-chart faces + the weekly insight
carousel (R6 grammar) + deepened detail pages (ledger · WHAT THE
PLAN DOES · provenance), care-first Becoming for clinic patients,
and the evening close's 96pt hero numeral. Film doors:
--debug-gallery-tour · --uitest-walk-strip · --uitest-walk-scope ·
--uitest-open-tile · --uitest-mark-lead · --uitest-land-plate ·
--uitest-care-mode. Synthesized XCUI drags can't scroll the iOS 26.2
sim (probe-proven) — tours film what walkers cannot.

**APP v11 — THE REBIRTH + v11.5 MODERNITY (feat/app-v2). SHIPPED 2026-08-05.**
**`docs/app_v11/00_REBIRTH.md` is THE LAW** (L1-L13); `01_PLAN.md` is
the plan. The founder's brief: the current app disappears; the
architecture and business logic stay; the experience is reborn in the
onboarding's design language. Executed as a **DESIGN PASS** — THE LOOP
(drive the sim → record → dump frames → compare neighbours → fix →
repeat) after every surface; per-screen gate "would Apple ship this?".
**v11.5 THE MODERNITY PASS** (`docs/app_v11/03_MODERNITY.md`, amends
the law): printed page → living surface. JeniSurface (depth without
chrome), JeniCheck (drawn check), JeniPressable, springs everywhere;
the calendar strip is a first-class selector (week paging, disc morph,
the page re-keys to the selected day); TODAY/TOOLS are soft cards;
Becoming's tiles MORPH in-tree into their pages (11 tiles incl.
calories, waist, body fat).
Shape: the editorial kit (7 primitives + motion layer) → JeniChart (one
Canvas engine, SwiftUI Charts dead) → Home from zero (MFP information
architecture: calendar strip → nutrition → TODAY → TOOLS) → Becoming
chart-driven (Apple Fitness Summary IA in paper+ink; body progress
lives HERE, not on Home; 8 provenance-backed tiles incl. fiber, sugar
intake, sodium). Next cycles: S (body scan instrument + result page),
N (Lovi-style scan chooser).

### Standing law (survives every era)

- `docs/app_v9/00_MISSION.md` — L1-L7 product laws (three-questions,
  honesty, body-privacy, passive, register).
- `docs/app_v9/04_DESIGN.md` — the design constitution (ADA bar,
  remove>add), sharpened by v11 §1+§11.
- `docs/jeni_release/00_JENI_RELEASE.md` — brand identity: the
  hand-drawn j mark, one-colour law, paper+ink palette, voice pass
  (hearts retired, dose-dot ornaments, "— jeni").
- `docs/onboarding_v7/00_DIRECTION.md` — onboarding law (persona /
  consequence / evidence / register).
- `docs/app_v8/` — the care platform (Jeni Health › Jeni Care › Jeni);
  S1-S5 shipped; internal dev alpha, test data only, NO BAA — never
  say "HIPAA compliant".
- `docs/glp1_strategy_2026_06_16.md` — cohort strategy + compliance
  floors (no drug brand names, no equivalence claims, no numeric
  weight-loss claims).
- Body privacy: never a number from a photo; BF% via provenance ladder
  only (Health reading, else Deurenberg band); scans local-first,
  backup default OFF; fasting vocabulary never renders;
  observed-never-prescribed enforced in code.

### Shipped history (one line per era; full records in git history)

| era | date | what stands |
|---|---|---|
| v10-v10.4 mirror/relaunch/instrument | 2026-08-04 | WaistCrop + BandProfile laws (§9 of v11 law), rear-camera capture, BodyScan/ modules |
| v9 BODY OS P0-P7 | 2026-08-03/04 | BodyStateService, Body Vision capture, passive weight, care summaries; 488 units |
| onboarding v7 clinical pass | 2026-08-03 | OV5Persona, question/evidence law — live |
| onboarding v6 conversion | 2026-08-02 | keep-wall trust bands, dormant real-proof — live |
| THE JENI RELEASE 1.2.0 | 2026-07-30 | brand + palette + voice — standing law above |
| v8 CARE PLATFORM S1-S5 | 2026-07-28/30 | clinic loop live on dev; pilot founder-gated |
| v7 THE CARE PLAN | 2026-07-27 | CarePlanEngine — still the day composer |
| v6 THE SIGNALS | 2026-07-17 | Signals engine + safety rules — engine law |
| v5 and earlier | 2026-07 | engines survive; layouts long superseded |

The Xcode project name + Bundle ID intentionally stay legacy
(`plankAI` / `com.bk.plankAI`) — renaming forces re-onboarding for
every TestFlight tester; a later founder-gated release handles it.

**Authoritative state doc: `/docs/STATE.md`.** Read it first.

### Auth + sync
- Anonymous-first Supabase auth, Apple + email upgrade, sign-in
  recovery, delete-account + forgot-password (anti-enumeration).
- All entity reads filter via `@Query userId` for cross-account
  isolation. Sign-out sweeps user-scoped `@AppStorage` + cancels
  retention notifications.
- Profile, session_logs, day_progress, weight_logs, session_ratings
  sync via typed Codable upserts; UUID case normalized at hydrate
  boundaries.
- Files: `PlankApp/Auth/`, `PlankApp/Sync/`,
  `Packages/PlankSync/Sources/PlankSync/`.

### Payment (RevenueCat)
- `customerInfoStream` observation. `PaymentService` re-configures on
  `auth.currentUser` changes so sign-in/out doesn't strand prior
  user's entitlement.
- THE KEEP WALL (no-trial, pay-upfront): yearly (badged, pre-selected)
  + quarterly + weekly, billed-today everywhere; v6 earned-trust bands
  + dormant real-proof slot (founder fills verbatim ASC reviews —
  never fabricate). Tier-matched downsell sheets on cancellation
  intent.
- Paywall reads RevenueCat's localized `storeProduct.localizedPriceString`
  per Apple Guideline 3.1.2(a). No hard-coded prices.
- `restore()` respects existing paid users (no re-onboarding).
- Files: `PlankApp/Payment/`, `PlankApp/Views/Paywall/`.

### Onboarding
- v5 architecture (typed state machine, 5 acts, GLP-1 branches) + v6
  conversion evolution + v7 clinical grade pass. `onboarding_version:
  v7`. Read `docs/onboarding_v7/00_DIRECTION.md` before touching.
- QA: `OnboardingV5WalkerUITests` (TEST_RUNNER_GLP1_COHORT,
  TEST_RUNNER_GENDER); StoreKit review-sheet dismissal needed on iOS
  26.2 sim; `--uitest-skip-payment`.
- Files: `PlankApp/Views/OnboardingV5/`.

### Program / plan engines
- `CarePlanEngine` composes the day (gentle tone, clinical lead
  promotions, dose day leads); `ProgramDayPrescription` beats;
  `TargetsService` + `CohortStore` single sources of truth;
  ACSM-grade pacing floors in `ProgramGoalCalculator`; never hardcode
  75 — read `plan.totalDays`.
- Medication first-class: dose day, sit-check, RegimenSheet, verb law
  (add / mark / weigh in).
- Files: `PlankApp/Program/`, `PlankApp/Views/Plan/`.

### Body Vision (BodyScan/)
- Guided on-device scans; rear camera; THE WINDOW fixed-aperture
  capture; WaistCrop (pure, tested — EXIF-normalize before crop) +
  BandProfile (per-row width → words; 3% noise floor; fuller weeks
  never scolded); BodyScanStore local-first; D3 opt-in backup.
- QA: `--uitest-open-body-scan` · `--uitest-scan-allow-manual` ·
  `--uitest-force-scan-day` · `--uitest-scan-simulate-pose` ·
  `--uitest-seed-scans`.
- Files: `PlankApp/BodyScan/`.

### Chat
- Two voices (serif letter + rose marginalia), bare-hairline composer;
  streamed heart emoji stripped by normalizer; EF
  `supabase/functions/jeni-chat`.
- Files: `PlankApp/Chat/`.

### Snap Food (food rail)
- Snap / describe / again modes; camera → vision EF (env-selected
  model; USDA calibration) → 3-slide carousel result (plate panel ·
  jeni note · share composer); PlateEditSession coherent macro↔kcal
  math; sodium/sat-fat/sugar/fiber captured end-to-end; per-ingredient
  ledger rides `food_logs.payload` jsonb.
- Files: `Packages/PlankFood/`.

### Breathwork
- Science-honest primer (cortisol mechanism, NOT fat-burn claims).
- Files: `PlankApp/Views/Welcome/Breath*`.

### Steps + health rails
- HealthKit steps (7,500 anchor), sleep, passive weight (background
  delivery + observers), VitalsService, MovementService.
- Files: `PlankApp/Health/`.

### Launch + loader
- `LaunchBackground` == `bgPrimary` — one continuous surface, no grey
  flash; AffirmationLoaderScreen.
- Files: `PlankApp/Views/Welcome/AffirmationLoaderScreen.swift`,
  `PlankApp/PlankAIApp.swift`.

### Notifications
- Trial-window anchors + daily reminder (`daily_reminder`, surgical
  pending-removal); cohort-aware variants per
  `docs/notification_system_spec_2026_06_16.md`; day-2 consent gates
  first-days pushes (v7).
- Files: `PlankApp/Notifications/`.

### GLP-1 cohort strategy
- Convergence-not-pivot; `Glp1Cohort` enum; cohort signal in the noun
  phrase; bodies reference only shipping features. See
  `docs/glp1_strategy_2026_06_16.md` for the compliance floors.

### Design system
- **`docs/design/00_JENI_DESIGN_LANGUAGE.md` IS THE DESIGN LAW**
  (canonical, 2026-08-06). Philosophy, typography, motion,
  transitions, interaction, haptics, layout, spacing, components,
  animation rules, a11y, copywriting (B2C + B2B), never-do list, and
  good/bad examples. Read it before touching ANY surface. It
  supersedes older design docs where they conflict. The v8 onboarding
  (`docs/onboarding_v8/`) is its reference implementation.
- `PlankApp/DesignSystem/Tokens.swift` is the source of truth. Paper
  `#FCFAF7` + ink `#2A1F1E`; 8 locked tokens; `bgPrimary` is the ONLY
  background. JeniHeroSerif on heroes, Fraunces punch, DMSans body.
- v11 kit: `DesignSystem/Kit/JeniKit.swift` + `JeniMotion.swift` +
  `JeniChart*.swift` — the seven primitives + motion layer are the
  ONLY building blocks on v11 surfaces; default SwiftUI transitions
  banned there.
- Voice: lowercase casual; italic punch via `ItalicAccentText` (never
  `*markers*`); zero hearts; no em-dashes between words; never "AI"
  in user copy; "sugar intake" never "sweetness".
- `JKBorderBeam` placement law in its header (earned surfaces only).
- See `docs/THEME.md`, `docs/her75_typeface_spec_2026_06_10.md`,
  `docs/itgirl_illustration_system_2026_06_12.md`.

### Compliance + metadata
- `MARKETING_VERSION = 1.2.0`, healthcare-fitness category; privacy +
  terms at `jenifit.app`; App Store metadata in
  `docs/app_store_metadata.md`; screenshots spec in
  `docs/APP_STORE_SCREENSHOTS.md`; bundle-size plan in
  `docs/odr_migration_plan.md`.

### QA doors (most-used)
- Post-paywall: `--uitest-inapp-qa --uitest-pro-access`.
- Regimen: `--uitest-seed-regimen`, `--uitest-open-gap 0`.
- Care: `--uitest-care-connect-code`.
- Body: see Body Vision section above.
- Sim gotchas: UI legs run SOLO (unit-suite chaining drops presses);
  incremental builds can skip edits (`touch` + compile-count);
  dedicated QA sim `QA-iPhone16` UDID
  `259952D4-444F-4EFE-864A-F3DD5FBA5D22`; MainActor class deinit
  aborts on iOS 26.2 sim (use @MainActor enum services); Canvas
  animation must self-drive from `.task` phases.

### Open items
- See `TODOS.md`.
- v1.2+ Bundle ID + project rename (founder-gated).
- ElevenLabs voice clip generation pass.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
