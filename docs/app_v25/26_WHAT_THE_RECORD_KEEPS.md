# WHAT THE RECORD KEEPS — the last 10%

**Status: BUILT 2026-08-12.** Not an era and not an E-number. A depth
pass over the layers the product reaches when a user goes further in.

No migration. Zero diff against the reviewed release in Payment,
Paywall, Auth, Sync, `AppPhase`, entitlements, RevenueCat, medication
authority, Supabase security, HealthKit read types, `Info.plist` or the
analytics vocabulary frozen in `24_MEASUREMENT_CONTRACT.md`.
1.2.0 (30) is in review; this is for the next build.

---

## 1 · THE DEEPEST SEAM I FOUND

The brief named five debts. Four were real, one was a misreading, and
all of them turned out to be instances of ONE thing:

> **A layer knows something and does not say it — or says something it
> does not know.**
>
> Not "the detail screen is uglier than the first screen". The detail
> screens are mostly fine. What breaks going deeper is that **knowledge
> stops travelling**: her own corrections are written to disk and to the
> cloud and read by nothing; a plate's vitamins are summed from one item
> and labelled as the plate's; Move holds a 44pt zero over the record it
> is hiding behind a fixed detent; the desk's proof of her whole record
> expires at midnight; a sheet header truncates a dish name to make room
> for nothing.

Each is a HANDOFF failure between a layer that has the fact and a layer
that renders it. That is why the fixes are small and why none of them is
a new feature.

---

## 2 · WHAT I INVESTIGATED, WHAT I EXPECTED, WHAT WAS WRONG

### The five named debts, verified

| the record said | what is actually true |
|---|---|
| `PlateDetailSheet` can't show micronutrients because `FoodLogEntry` never stored them | **True, and persisting them would be a mistake.** See §3. |
| Move leads with `0 of 2` and carries a dashed divider that exists nowhere else | The zero is real. **There is no dashed divider.** See §4. |
| The desk's empty state is ~40% dead space | Measured: **~23%** between the disclaimer and the composer. And the void is not the defect. See §5. |
| A long dish title truncates in `JKSheetChrome` at XXXL | **True, reproduced, and it is not about XXXL.** It is the primitive, at any size, once a title needs three lines. See §6. |
| Older secondary surfaces may now stand out more | Partly. Move did. The dose sheet, side-effect sheet and settings do not. See §8. |

### Three things I expected and found wrong

**① Micronutrients are not "richer before filing". They are almost never
there at all.** I expected a UI gap. I found a coverage gap so narrow it
inverts the brief's premise — and a live surface that lies. §3.

**② The QA harness renders a state the pipeline cannot produce.**
`PlankAIApp.mockItems` hand-attaches micronutrients to `.llmDirect`
items with the comment *"so the panel renders in the harness the way it
does over a real lookup."* A real `.llmDirect` lookup returns none. Two
eras reviewed that panel against fiction. **A QA seed that improves on
reality is worse than no seed** — this is the third time in three eras
that a seeder, not the product, was the thing under review (E9 found the
book's palette; E7 found the flag-order wipe).

**③ `MoveRecord.isEmpty` was written for this exact problem and no view
ever referenced it.** Its own comment reads *"the honest empty state,
which is different from 'she did not move'"*. The insight was written
down, tested, and never connected to a screen.

### And one thing I got wrong mid-pass

I set her correction sentences in serif italic. The chat's own source
carries the founder's ruling verbatim: *"sans in the bubble. Serif
italic is a READING face — set as a message it read as a book, not a
conversation. Her voice is carried by the rose and the blush now, not by
the slant."* Her words now render in DMSans + `jeweledRose` on the plate
page, identical to the transcript. **The transcript caught it, not me** —
which is the argument for reading the surface that already solved a
problem before designing a second answer to it.

---

## 3 · FOOD KNOWLEDGE / PERSISTENCE — before → after

### The provenance map, measured by reading every path

| door | micronutrients at capture? | why |
|---|---|---|
| photo, confidence ≥ 0.5 | **no** | `llm_direct`; USDA never consulted — the DEFAULT since v1.0.7 |
| photo, confidence < 0.5 | yes, **that item only** | USDA calibration path |
| photo, kcal missing | yes, that item only | full USDA join (legacy fallback) |
| nutrition label | **no** | the food-vision schema returns no micros, and a legible panel is high-confidence so no join runs |
| typed words | **no** | same response shape |
| barcode | **no** | `OpenFoodFactsClient` parses none |
| pantry / quick add | **no** | `canonical_pantry` has no micro columns |
| restaurant estimate | **no** | rule-based arithmetic |
| again / relog | **no** | copies persisted fields |

**One source (USDA FDC), reached only for the items the model was least
sure about.** So E7's ten micronutrients are, in production, either
absent or attached precisely to the plates whose numbers deserve the
least confidence.

### THE DECISION: do NOT persist micronutrients

The brief asked which nutritional facts deserve persistence. Judged
against its own criteria:

- **coverage** — one database, and only on a low-confidence subset
- **source reliability** — *inverted*: present where the plate is least
  certain
- **user value** — a vitamin figure that appears on 1 plate in N and
  disappears on the next scan of the same dish teaches nothing
- **future usefulness / B2B** — a clinician reading a partial sum as a
  plate total is worse than reading nothing
- **storage compatibility** — additive and cheap, and irrelevant given
  the above

Persisting them would freeze a partial figure of inverted reliability
into the record permanently, and would make the poorest plates read as
the richest. **This is the "fixing it would make Jeni worse" case the
brief invited, so it was not fixed.**

### What WAS fixed: the panel was lying

`SnapResultView.namedMicros` summed `items.compactMap(\.micros)` and
labelled the result as what the plate carries. On a four-item plate
where one mystery item hit USDA, it printed **that one item's potassium
as the plate's**. Understating is still misrepresenting, and it is the
estimate-dressed-as-measurement defect the provenance law exists to
prevent. E7 wrote the right rule — *"a described meal that never touched
USDA has no panel at all"* — per ITEM, and enforced it per PLATE with a
`compactMap`, which silently accepts the mixed case.

- `CapturedItem.publishesMicros` — provenance-based, exhaustive over
  `NutritionSource`. A grounded item whose USDA record lists no vitamin C
  is still `true`: **"asked, and there is none" is knowledge; "never
  asked" is not.**
- The panel speaks only when the WHOLE plate is grounded. On the common
  production plate it now says nothing, which is what it always should
  have said.
- `PlatePriors.scale` dropped micros while keeping `nutritionSource`, so
  a grounded plate went silent the moment her own prior improved it —
  **the record getting poorer for having been corrected.** They scale
  with the portion now.
- `microAmount` interpolated raw `Int`, so a potassium reading over
  999 mg was the one four-digit number in the app that arrived as
  `1400` while the plate sheet three tiers up rendered `2,300 dv`. Same
  class as the ship pass's one gram grammar.

### THE REAL DECAY: her own sentences

E4 shipped "corrections PERSIST". **Only the write half shipped.** Every
fix-with-words line goes to the JSONL and rides `food_logs.payload` to
the cloud and back — and `FoodLogEntry`, the DTO every food surface reads
through, had no field for them. The only reader reduced them to a `Bool`.

So: she says *"it was a large, not a medium"*, jeni rescales the plate
and files it, and the next morning the plate says *"read from your photo
· ranges, not exact"* with no trace that she touched it. **The most
valuable bytes in a food record — the moment the user knew better than
the model — were the one thing the record could not read back.**

| | before | after |
|---|---|---|
| `FoodLogEntry.corrections` | absent | present + `wasCorrected` |
| the plate page | no trace | **YOUR NUMBERS** — her sentences, quoted |
| `relog` | dropped them | carries them; the prior survives the cheapest door |
| `reattributeEntries` (sign-in merge) | dropped them | carries them |
| migration | — | **none.** The bytes have been on disk since E4 |

`reattributeEntries` has now dropped a newly-added field **three times**
(sugar + itemsDetail 2026-07-25, sodium + satFat 2026-08-08, corrections
today). The shape of the bug is a hand-written init with defaulted
parameters: the compiler cannot see an omission. Every field is named
there on purpose now, and a test pins the whole shape.

### The nutrition detail, as an instrument

Prominence is earned, so **YOUR NUMBERS** sits below the plate and the
day, carries no number of its own, and appears only when it exists. It is
a block quote — one drawn stem, a mark and never a colour — because a
badge reading "corrected" would tell her a fact she already knows and
hide the only content that matters. And the footing is exact: a relog
copies the corrected numbers, so it says *"you fixed this dish before"*,
not *"this plate"*.

Tested against the brief's list: legacy records (nil), sparse records
(nil), an emptied list (not a correction), photo · words · barcode ·
label · relog, correction, sync round-trip, and the sign-in merge.

---

## 4 · MOVE — what it is now

### The dashed divider does not exist

There is no divider. The week's rhythm drew its below-half-goal days as
`Capsule(width: 6, height: 1.5)`, and **seven horizontal dashes sitting
directly above a section label is a dashed rule to every eye that meets
it.** A low-step week is completely ordinary in this cohort, so the state
is reachable rather than theoretical. Three states, three CIRCLES now —
the calendar strip's own vocabulary. A row of circles cannot become a
line.

Recording this because the "fix" the record implied would have restyled
a divider that was never there and left the actual defect standing.

### A count is a hero only when there is something to count

Move opened on `0 of 2` in 44pt serif under an eyebrow reading *"what
your body did"*. **The largest thing on the surface was a zero, and the
surface's title contradicted its content.**

Every other instrument here already refuses that: the protein hero drops
its denominator once met (E7 — `123 of 90 g` read as a typo),
`FirstPlateReadingEngine` renders no floor without a weight on file,
`PlateAnswerEngine` turns an ungroundable number into coarse words. The
same law, arriving late on the one surface with nothing to enlarge.

`MoveEnergy.strengthHeadline` → `.nothingYet("nothing heavy yet this
week.")` at zero; `.count(done:of:)` once a session exists, denominator
dropping when met. **Strength stays the headline** — the lean-mass
evidence is unchanged and it is the one call Move makes. What changed is
that a week which has not happened yet is stated in words.

### "twice a week" was said twice

The strength caption and `MoveEnergy.nextLine`'s zero branch both
delivered the guidance, three inches apart, on the state where it was
least welcome. The zero is the headline now and `nextLine` returns nil
there (E4's prose/ledger de-dup law). The caption also went from two
sentences to one clause — §6.1 asks for a caption inside an instrument
panel, and the teaching the second sentence carried is `nextLine`'s job
and the Method's.

### `steps 0 · from health` was an absence in a sensor's clothes

`StepsService.todayCount` is a non-optional `Int` that reads 0 both when
HealthKit returned no samples and when it returned samples summing to
zero. Those are not the same fact: no samples before 8am, or on a day her
phone sat on a desk, **is a measurement of where her phone was.** So at
7am Move printed `steps 0 · from health`.

`MoveRecord.resolvedStepsToday` returns nil there, and `todayBlock`'s
existing copy — *"nothing has come through from health today."* — was
already the right sentence. The record TYPE still distinguishes a
measured zero from unknown (that test stands); what changed is that this
app never claims one. **Data presence and authorization stay different
truths, and now so do absence and zero.**

### The rest

- **The detent.** Founder, mid-session: *"make this either 3/4 screen or
  almost full screen as user having to scroll on this half pop up screen
  is not a good ux design."* Move sat on `tallFixed` — a single fixed
  `.fraction(0.68)` — while `JKSheetChrome` hides the grabber. **A sheet
  that opened already scrolled, with no second detent and no affordance
  to expand.** At AX5 exactly five items fit and the whole record was
  below the fold. It is `.large` now, like every other sheet that
  carries a record. `tallFixed`'s doc says it is for a camera or canvas
  underneath; Move has neither. E8.2 reached for it to stop a header
  center-clipping, the ScrollView fixed that, and the fraction was never
  the part that had to stay.
- **The last rose button in the product.** E9 made exactly this fix on
  the Method note and missed Move, on a surface it was editing in the
  same pass. Rose is the DATA hue; ink keeps words and selection (§3), so
  a blush capsule under a label is a quantity you can press. Ink now,
  and one line: filming caught *"record something / health missed"*
  breaking inside the capsule into a 160pt slab.
- **An underlined inline text link** — web grammar, and the one thing
  left on the surface that read as the older app. A hairline capsule now,
  the secondary affordance the system already speaks.
- **Seven faint dots over a header is not information.** `weekHasShape`
  finally gives `MoveRecord.isEmpty`'s insight a screen.
- **Provenance did not scale.** `.system(size: 10)` on the provenance
  word and note — the genuine Dynamic Type defect E9's note describes,
  sitting on the one label the design law says must always be readable.
  At AX5 the numbers grew three times and their provenance stayed at
  10pt. Both are `.custom(_:size:relativeTo:)` now.

**What Move refuses, unchanged:** a second ring, a score, a goal to
close, energy estimated from steps, and any arithmetic between movement
and food. No Activity-ring lookalike: the rhythm is seven 5-6pt dots.

---

## 5 · THE JENI DESK — empty → aware

### The void is not the defect. The expiry is.

E6 replaced the desk's tagline with proof and **scoped the proof to
TODAY** — the one window most likely to be empty at the moment somebody
opens the app. So a payer with a twelve-day record, opening at 9am, read
*"your coach, day to day."*: **the same sentence as a person who has
never logged anything.** Every morning, the most capable thing about her
reset to a claim.

`JeniDeskAwareness` now has two more rungs below today's, in order:
yesterday (`"yesterday: 4 plates and 118 g of protein."`) then the
record's depth (`"your record has 12 days in it."`), and the claim only
when there is genuinely nothing. A single logged day is not depth, so it
waits for two. The gap line still outranks everything — a return after
days away is the most true thing about that moment. Protein still never
renders `0 g`. All four rungs are pinned exactly by table tests.

### The starter logic was inverted

```swift
if snap.plates.isEmpty, hour >= 12 { chips.append("what did i eat yesterday?") }
```

The one starter that asks the RECORD a question was offered exactly when
today was empty, **without ever checking that yesterday held anything** —
so it appeared on the emptiest records and vanished the moment there was
something to answer. The comment three lines above it claims *"a starter
never walks someone into 'i don't have that'"*. It now requires
yesterday to have a plate.

### What I did NOT do

Fill the void, add cards, add a feature menu, or add text to remove
whitespace. The measured gap is ~23%, the file records two earlier failed
attempts to re-anchor that geometry, and **the desk's problem was never
that it was quiet — it was that it was quiet about a record it had.**

---

## 6 · SHARED COMPONENT FIXES

`JKSheetChrome`'s header text carried no `fixedSize(vertical:)`. In its
VStack — where `content()` is a flexible ScrollView that absorbs
whatever is left — the header reported a compressible ideal height and
lost the height competition. Result: **a dish name cut to "grilled
chicken…" with two thirds of the sheet standing empty below it. A layout
that hides content in order to make room for nothing.**

Reproduced with an 80-character title: two lines and an ellipsis at AX5,
and it was never about XXXL — any size truncates once a title needs three
lines. `fixedSize` on the eyebrow and title says "give me my wrapped
height and take it from the scroll region"; a title that already fits is
unaffected, which is why the fix belongs in the primitive rather than in
one call site. `lineLimit(4)` is the backstop for a pathological name.

**No `.minimumScaleFactor(0.4)` anywhere.** Proven visually at AX5 (four
lines, was two) and at default (the full 80-char title with emoji, three
lines, complete, whole plate readable below it).

I deliberately did NOT restyle every sheet. The dose sheet and
side-effect sheet were walked at `.tall` and both fit their content with
their primary action visible and a working grabber — `.tall` is doing its
job. Move was the one wrong token pick, and `JeniSheetHeight`'s doc now
says so, so the next session does not reach for `tallFixed` to fix a
clipping header.

---

## 7 · ONE JENI AUDIT

- **Richer nutrition in the record → can jeni read it?** Corrections
  land on `FoodLogEntry`, which is what `JeniReadTools` and
  `priorObservations` already read through. One DTO, one source.
- **Move's new interpretation → does jeni use it?**
  `strengthHeadline`/`resolvedStepsToday` live on `MoveRecord`/
  `MoveEnergy`, the same types every Move consumer resolves from. The
  zero-is-absence rule is in the record, not in the view.
- **Uncertainty preserved?** Yes, and strengthened: the micro panel now
  refuses to state a plate total it cannot ground, and provenance words
  scale.
- **Care-team authority?** Untouched. Nothing in this pass reads or
  writes a program fact, and `CareProtocol` is unchanged.
- **Parallel truths?** The one I found, I fixed: her own words were
  about to render in two different typefaces on two surfaces.

## 8 · OTHER SECOND-TIER SURFACES — checked, mostly left alone

Walked: the dose sheet, the side-effect sheet, the plate page, the book,
the desk (empty · weigh-in only · today-empty-with-history · full), Move
across no-data / steps-only / strength-met, and the evening close.

**Observed, deliberately NOT changed:**
- The dose sheet's centered `not today` is also underlined. It is a
  different role from Move's inline link — a de-emphasized escape under a
  primary action, the standard iOS shape — on the surface with the most
  careful prior design work in the product. Changing it is churn on the
  medication path.
- The evening close leaves a large void below its chips in the seeded
  state. It is at the bar and the founder's recorded steer settled its
  shape; noted, not touched.
- Settings' SF-symbol rows (E9's call, still right).

## 9 · WHAT I REMOVED

The 44pt zero · one of two "twice a week" paragraphs · one sentence from
the strength caption · `steps 0 · from health` · seven dashes that read
as a rule · a rose primary button · an underlined text link · a rhythm
block with nothing in it · a plate-level micronutrient claim the
pipeline cannot support.

## 10 · WHAT I REFUSED TO BUILD

- **Micronutrient persistence** (§3) — the brief's first named debt.
- **A nutrition-facts table.** Twelve equal-weight metrics, a
  micronutrient grid, invented denominators.
- **A food-vision schema change** to extract the four FDA-mandated
  label micros (vitamin D · calcium · iron · potassium are printed on
  every US panel the label door photographs). This is the ONE real fix
  for micronutrient coverage and it is genuinely worth building — but it
  needs an Edge Function deploy, which is a founder gate, and 1.2.0 (30)
  is in review. **Named as the next build's work, not smuggled into
  this one.**
- **HealthKit expansion.** No new read type, no purpose-string change.
- Streaks, community, compensation mechanics, exercise-calories-cancel-
  food arithmetic, a paywall/pricing/onboarding change, a new analytics
  taxonomy, an Activity-ring lookalike.

## 11 · B2C / B2B AUTHORITY AUDIT

No change. Nothing here reads or writes `program_facts`, no clinician
surface moved, `CareProtocol` and `MethodNote.authority` are untouched,
and the care gate on the desk's fallback claim still fires. The
correction quote is attributed by a drawn stem and a word — never
colour — which is the same rule the care-team note follows. That two
knowledge-provenance features needed zero authority work is the
authority model doing its job.

## 12 · HEALTHKIT / PRIVACY AUDIT

- **Zero new read types**, zero authorization changes, no purpose-string
  edit, no `Info.plist` or entitlement diff.
- Move's permission states are unchanged; the connect row still fires
  only when iOS says the ask would surface something new.
- **Data presence ≠ authorization** is now enforced harder, not softer:
  an authorized-but-empty read renders as absence instead of as a
  measured zero.
- Nothing is written back to HealthKit. The only estimate in Move is
  still MET-based from her own entry, labelled, never saved.

## 13 · ACCESSIBILITY AUDIT

- **Dynamic Type:** Move and the plate page captured at AX5 and default.
  Move at `.large` reaches the whole strength tier plus TODAY where it
  previously showed five items; nothing clips or truncates; the
  one-clause caption pays off doubly at AX5.
- **A real fix, not a screenshot:** the provenance word and note used
  `.system(size: 10)`, which does not scale. Found by reading the AX5
  frame, not by grepping.
- **VoiceOver semantics** where information is nontrivial:
  `strengthHeadline` has a distinct label per state
  (`"no strength sessions on file this week"` vs `"2 strength sessions
  this week"`), the correction block is one element whose label carries
  the exact footing plus every sentence, and `move.strengthCount.N`
  identifiers still resolve at zero.
- **Differentiate Without Color:** the rhythm's three states differ by
  fill AND size (filled 6pt / hollow 6pt / faint 5pt), not hue. The
  correction block is marked by a stem, not by its rose. Provenance is a
  word.
- **Touch targets:** the connect capsule is 12/6 padded around a 13pt
  label inside a full-row `JKPress` button; the ink pill is 24/16.

## 14 · WHAT FRAME REVIEW CAUGHT

Everything in this list was invisible in the code and obvious in a frame.

1. The primary action wrapping to two lines inside its capsule.
2. Seven faint dots over an orphaned header saying nothing.
3. The underlined `connect` link, once the surface around it stopped
   looking old.
4. Provenance rendering at 10pt while its numbers tripled at AX5.
5. The header truncation, reproduced only after deliberately seeding a
   pathological title — the default seed's 17-character name wraps fine
   and hides the primitive's defect completely.
6. My own serif-italic correction quote, caught by opening the
   transcript that had already answered the question.

## 15 · FUNCTIONAL PROOF

- **1009/1009 app tests** · **154/154 package tests** (run from
  `Packages/PlankFood`; the app scheme cannot host that target).
- **+14 tests**, all pinning laws rather than pixels: the four awareness
  rungs and their order · one-day-is-not-depth · the gap still outranks
  depth · words-at-zero and count-after (0/1/2/3/entered) · a zero-step
  day resolves to unknown while a measured zero stays a measurement ·
  corrections survive into the DTO / are not claimed when empty / ride a
  relog so the prior survives / survive the sign-in merge · only USDA
  publishes micros · a mixed plate says nothing · a fully grounded plate
  still speaks · trace amounts are not named and no share ever renders ·
  a prior scales micros instead of dropping them.
- One test was **rewritten, not deleted**: the empty-week no-verdict law
  moved from `nextLine` to `strengthHeadline` and now also asserts the
  line is said exactly once.
- A product bug was found BY a test expectation and fixed in the
  product, not in the test (`microAmount`'s missing thousands
  separator).

## 16 · VISUAL / MOTION PROOF

Before/after captures of Move (no data · strength met · AX5), the plate
page (uncorrected · corrected · corrected at AX5 · pathological title at
AX5 and default), the desk (empty · weigh-in · with history), the dose
sheet and the side-effect sheet. Initial paint, sheet presentation and
async arrival inspected; no height jump, no shear, no reflow, and Move's
header stays pinned while the record scrolls.

New QA doors, both DEBUG-only:
- `--uitest-plate-corrected` — opens the plate she FIXED, the only way to
  film **YOUR NUMBERS**.
- `--uitest-food-yesterday-only` — seeds history and NOT today. "Today
  empty but history exists" is the state a returning payer most often
  opens in, and no door could produce it: the seeder always wrote today,
  and `--uitest-wipe-food` erases everything. It is the state the desk
  was silently wrong in for an era.

The seeded corrected plate carries two real correction sentences. E4 has
persisted these since it shipped and no seed ever carried one, which is
part of why nothing noticed the read path did not exist.

**Not filmed, and why:** the desk's yesterday and depth rungs. The QA
seeder always writes a same-day weigh-in, which correctly outranks them,
so the branch below is not reachable from a launch argument. Both are
pure-engine rungs pinned exactly by table tests, and adding a third door
to film a pure function is QA sprawl.

## 17 · MIGRATION / COMPATIBILITY IMPACT

**No migration. None was needed and none was written.**

- `corrections` has been in the JSONL and in `food_logs.payload` since
  E4. Only a read path was added.
- Legacy rows: `corrections` decodes to nil, `wasCorrected` is false, the
  tier does not render.
- Sparse rows, every entry method, relog, correction, sign-in re-key and
  the cloud round-trip are covered by tests.
- `publishesMicros` is a computed property over a field the pipeline
  already stamps. Nothing is stored differently.
- Old app versions reading the same rows are unaffected: no column added,
  no value renamed, no CHECK constraint touched.

## 18 · DIFF AGAINST THE REVIEWED RELEASE

Verified empty against `1710180` (the release-proof commit) for:
`PlankApp/Payment`, `PlankApp/Views/Paywall`, `PlankApp/Auth`,
`PlankApp/Sync`, `supabase/migrations`, `AppPhase.swift`. Plus, for this
session: zero HealthKit read-type diff, zero `Info.plist` /
entitlements / `pbxproj` diff, zero new analytics events.
`e5.firstPlate.enabled` still false. 17 files + 1 new test file.

**SAFE FOR NEXT BUILD: YES.**

## 19 · WHAT STILL FEELS BELOW THE BAR

- **The label door throws away the four micronutrients it photographed.**
  Vitamin D, calcium, iron and potassium are on every US Nutrition Facts
  panel by law, and the food-vision schema does not ask for them. This is
  the highest-value food-accuracy work available and it is one EF deploy
  away. §10.
- **`ItemDetail` carries no per-item fiber or sugar**, so the "on the
  plate" ledger can only show portion and kcal. Plate-level totals are
  correct; the per-item read is thinner than the data allowed.
- **`microAmount` and the rest-row grammar still live in two packages.**
  `SnapResultView`'s chemistry row and `PlateDetailSheet`'s rest row draw
  the same three nutrients with different code. E9 promoted
  `PlateEnergySplit` to the kit for exactly this reason; the fiber ·
  sugar · sodium row is the same argument, unmade.
- **Move's HealthKit rows are still unverified on a real device** (the
  standing debt — the simulator has no workouts, distance or active
  energy).
- **The evening close's lower void** (§8).
- Nothing in this pass could be falsified against a payer. The
  measurement contract's first clean read still gates every product
  decision here.
