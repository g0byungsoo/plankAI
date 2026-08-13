# E9 — THE COHERENCE PASS: the record

**Status: IN PROGRESS (2026-08-12).** A product + design sweep, not a
feature era. The mandate: make the product that eight eras built feel
like ONE designer made it — more coherent, more useful, more premium,
faster to understand — without adding a pile of features and without
redesigning what is already excellent.

The build 1.2.0 (30) is in App Store review. Nothing in this pass
touches the paywall, pricing, entitlements, `AppPhase`, auth,
migrations, or the analytics vocabulary frozen in
`24_MEASUREMENT_CONTRACT.md`.

---

## 1 · THE THESIS (written before any code)

Formed from: STATE.md §0.-13 … §0.-15, the design law, the E8.1
Method record, two commissioned research reviews (behavioral
intervention evidence; hydration evidence), 62 MeAgain reference
frames, and a walk of the running app with 17 captured surfaces.

### What the walk actually found

The product is in much better shape than a "redesign everything"
brief assumes. Onboarding, the morning letter, the evening close, the
dose sheet, Becoming and the Method note are all at or near the bar.
The incoherence is concentrated, and it has ONE shape:

> **Nutrition is the only domain in the app that never became an
> instrument.** Every other domain has a shape — weight has a
> trajectory, movement has a count against a guidance figure, the day
> has a checklist, the week has marks. Nutrition has ONE ring (protein,
> on Home) and everywhere else it is *rows of equal-weight numbers*.

That single defect produces most of what reads as "dashboard", "dense
without hierarchy" and "spreadsheet" in this product:

1. **`PlateDetailSheet` leads with CALORIES.** The product's own law
   (`00_THE_SYSTEM` §9 — "protein floor + fiber lead; kcal quiet") was
   fixed in the post-scan reading by E7 and on Home by E8. **The plate
   sheet was missed by both**, and it is the most reachable food detail
   in the app (Home's food row, the book, the plate chips all land
   here). E6 recorded that "the three food entrances ALREADY converge
   on one reading" — **that was wrong**. There is a fourth reading, and
   it is the oldest one.
2. **Five macros rendered as five identical rows.** Protein, carbs,
   fat, fiber, sugar at the same size, same weight, same colour, each
   on its own hairline. Nothing is loud, so nothing is legible at a
   glance. The plate sheet also drops the vitamins and minerals E7
   spent an era carrying through the pipeline.
3. **Home's food band spends ~750pt to say ~280pt of things.** The
   hero carousel's five faces are mutually redundant: `calories`
   duplicates the strip's kcal cell, `plate` duplicates carbs+fat,
   `chemistry` duplicates fiber/sugar/sodium, `week` duplicates
   Becoming's week scope. Only `protein` says something the others
   cannot — which is why E8 made it lead and why the other four are a
   swipe nobody takes.

### The principle chosen for this pass

> **Two nutrients earn a shape. Everything else earns a place.**

Protein leads with a ring because it is the one food number with a
collected, personal floor and the one the evidence says protects lean
mass. The day's energy gets exactly one shape — the split — because
the macros are ONE relationship, not three metrics (v18.1's law,
applied to food). Fiber, sugar and sodium keep their numbers and lose
their volume. Micronutrients appear only where they exist and never
compete.

This is the same law the design language already states; the pass
applies it to the one domain that never received it.

---

## 2 · WHAT THE INVESTIGATION FOUND THAT THE RECORD HAD WRONG

Four things. Recorded first because the pattern — *previous era
reports are not evidence* — is the most reusable thing in this file.

**① `PlateDetailSheet` is a FOURTH food reading, and the oldest.**
`19_E6_DECISION_AND_RECORD.md` states that "the three food entrances
ALREADY converge on one reading". They do not. The sheet Home's food
row, the book and the plate chips all open is a separate v5.1 surface
that E7 and E8 both missed while fixing the calories-first inversion
everywhere else. It still led with `340 calories` in 44pt serif on the
day this pass began.

**② Hydration already shipped, and shipped wrong.** The brief asked
whether hydration deserves to become part of the record. It already
was: `CarePlanEngine` offers a `.water(ml:)` row during the titration
window, and `jenifit.default` — the org-null **consumer** protocol —
hardcoded `hydrationMlDuringTitration: 1_800`. See §4.

**③ The QA seeder, not the surfaces, was the ugliest thing on screen.**
`FoodBookQASeeder.stillLife(hue:)` renders stand-in "photographs" at
0.32–0.55 saturation across the FULL hue wheel, so THE BOOK and the
scan chooser filmed as full-bleed emerald, violet and teal on a paper
page. Two eras of design review of those surfaces were conducted
against colours the product bans outright. I nearly filed this as a
product defect before checking where the pixels came from.

**④ `--uitest-open-method` "presents but does not render" is a
misreading**, carried in STATE.md §0.-14 as open debt. The engine was
returning silence, correctly, because the standard QA record earns no
note. Nothing was broken. `--uitest-seed-queasy` now gives the record
something to say so the surface can be walked in situ.

And one correction to a claim **I** made mid-pass, kept here because
the next session would otherwise repeat it: I counted 437
`.font(.custom(_:size:))` calls without `relativeTo:` and started to
call them Dynamic Type bugs. **They are not.** `Font.custom(_:size:)`
scales; `.custom(_:fixedSize:)` and `.system(size:)` do not, which is
what the design law's note is about. Proved on the plate sheet, whose
26pt title renders far larger than 26pt at XXXL with no `relativeTo:`
anywhere. No 437-site sweep is warranted, and the `relativeTo:`
additions in `MoveSheet` improve PROPORTION, not scaling.

---

## 3 · NUTRITION — before → after

### Home's food band

| | before | after |
|---|---|---|
| structure | 5-face pager + dots | one composed instrument, 3 tiers |
| height | ~750pt | ~280pt |
| what's above the fold | the band, and nothing else | the band + the day's to-do list |
| kcal | in a ring on face 1, again in the strip's cell | stated once, beside the split it explains |
| carbs · fat | face 3 (split), again as strip cells | the split's legend, once |
| fiber · sugar · sodium | face 4, again as strip cells | one aligned three-column row |
| the week | face 5 | Becoming, which is where over-time lives |
| per-render work | 5 × `FoodLogPersister.allEntries` week scans | none |

The four trailing faces each duplicated something the lead face's own
tiers already carried, which is why E8 promoted protein to lead and why
nothing deep-links into any of them. **A pager whose pages repeat each
other is not density; it is the same information charged four times.**

The shear class of bug came from the same place. A face carrying a hero
AND a full ledger cannot share one stage with a face carrying a
sparkline, so the stage's height was re-tuned in E8 (252 → 286 → 322),
re-tuned again in E8.1, and finally made self-measuring in E8.2 — four
fixes for one structural mistake. Removing the stage removes the bug by
construction.

**What did NOT change:** which numbers get a denominator, and why.
kcal is hers; fiber and sodium quote the published FDA Daily Value
(21 CFR 101.9) marked `dv`; carbs and fat get none; TOTAL sugar gets
none deliberately, because the FDA limit is on ADDED sugars. Every
number the founder's E8 steer asked to keep visible at rest is still
visible at rest.

### The plate reading

`340 calories` → `24 g protein / of 123 g today`. Five equal-weight
receipt rows (protein · carbs · fat · fiber · sugar, one size, one
hairline each) → the same three tiers as Home, drawn by the same
object. `PlateEnergySplit` was promoted out of Home into the kit for
exactly that reason: **two surfaces drawing one relationship must draw
it with one object**, or they drift the way these two had.

Calories are not deleted. A plate's energy is a real fact; it just
stops being the headline, and states itself once on the tier that
explains it.

### `JeniRing`, the phase fix

The gradient carried `angle: -90` and the shape carried
`.rotationEffect(-90)`, so the colour ramp sat a quarter turn behind
the arc it was colouring. Arcs began mid-ramp, and at a met floor the
ramp's dark end butted its light start at 9 o'clock as a hard tonal
seam — frame-caught by cropping Home's protein hero at 123 of 90 g. A
complete ring is now drawn as a Circle rather than a full trim closing
a round cap on itself. This is the app's most-used instrument, so the
fix lands everywhere at once.

---

## 4 · HYDRATION — what it became, and why

**The answer: hydration is a REASON in this product, not a metric —
and the number that was already shipping had to go.**

### What was there

`RegimenPolicy.hydrationMlDuringTitration` was a non-optional `Int`
defaulting to **1,800** on the CONSUMER protocol, rendering "about
1,800 ml across the day" to every unaffiliated GLP-1 user in the
titration window. Two things were wrong with it:

1. **The citation names the wrong population.** The code cites ASMBS's
   ≥1,800 cc/d, which is post-bariatric-surgery nutrition guidance.
   This cohort is not that cohort.
2. **No credible body prescribes a personal fluid volume.** IOM/NASEM
   adequate intakes (3.7 L men / 2.7 L women) are population
   references for TOTAL water *including food*, explicitly not
   requirements; EFSA is the same. The 2025 multi-society advisory
   (ACLM + ASN + OMA + TOS, *Am J Clin Nutr*) tells clinicians to
   counsel GLP-1 patients on preventing dehydration and deliberately
   gives no target.

And a real subset must not be told to drink more at all: fluid
restriction is standard care in heart failure, advanced CKD and
hyponatremia/SIADH, none of which are rare in a metabolically ill
population. **Jeni cannot know which reader is which.** This is the
`EnergyLedger.bmrFemale` defect in a new domain — a constant standing
in for a clinical judgment.

### Why the reason survives without the number — the evidence

- **KNOWN (label text).** Every drug in this class carries the same
  warning. Wegovy's PI: postmarketing acute kidney injury, "the
  majority of the reported events occurred in patients who had
  experienced nausea, vomiting, or diarrhea, leading to volume
  depletion"; Zepbound, Ozempic and Mounjaro carry parallel language.
  The patient-facing Medication Guides say plainly that it is
  important to drink fluids to reduce the chance of dehydration.
  **No label states an amount.**
- **SUPPORTED.** GLP-1s blunt thirst itself — dulaglutide cut fluid
  intake ~490 ml/day vs placebo with lower thirst perception
  (Winzeler et al, *J Endocrine Soc* 2021, special population) — and
  they shrink the meals fluid usually arrives with. The one signal a
  person would normally trust is the signal the drug is quieting.
- **SUPPORTED.** Constipation runs ~24% on semaglutide vs ~11% placebo
  (pooled STEP 1-3); first-line management is fluid + fiber + movement.
- **SUPPORTED-NULL, and this is why hydration is not a tracker.** The
  weight-loss case is close to empty for this audience: ~−0.33 kg in a
  2024 meta-analysis of 8 RCTs, with the pre-meal-water mechanism
  weakest in exactly this age band (Van Walleghen 2007 found the
  effect in older adults and not in 21–35s) — and the drug already
  does the appetite suppression water was supposed to approximate.

### What shipped

- **`hydrationMlDuringTitration: Int?`, nil on the consumer default.**
  A care team may still set one; it renders **attributed** ("your care
  team's aim"). Jeni never sets one for herself. Validation accepts
  nil and range-checks a clinic's value.
- The offered row keeps the instruction the medication guides actually
  give: *"sips through the day, not all at once."*
- **Two Method notes** carry the teaching, both firing on her own
  record — see §5.
- **What we never claim:** that water burns fat or drives weight loss;
  "8 glasses" or 2 L as a rule; that drinking prevents kidney injury;
  or any volume as appropriate for *her*.

### Deliberately NOT built, with reasons

- **A water tracker** (ring, goal, streak, daily ask). The evidence for
  the metric is near-null for this cohort, self-reported water is
  unverifiable, and it spends an ask on a base whose median payer lives
  2.0 active days — the exact "seven asks, one payout" failure the
  E8.2 close review just corrected.
- **Reading `HKQuantityTypeIdentifier.dietaryWater` from HealthKit.**
  Considered and deferred, not rejected: it is genuinely useful for
  someone already tracking water elsewhere, and it is the right shape
  (measured or absent, the Move pattern). But it needs a new read type
  in the authorization set and the purpose string that was fixed and
  shipped one build ago, while 1.2.0 (30) sits in review. **Additive
  compatibility beat completeness.** This is the first thing to build
  if hydration is revisited.

---

## 5 · JENI METHOD — before → after

**E8.1's rebuild was right and this pass did not re-litigate it.** The
research commissioned for this era independently confirms its central
claim: across 57 meta-analyses of digital NCD interventions, the
effective techniques are goal setting, feedback, self-monitoring,
prompts/cues and credible source — "information about health
consequences" is not among them (*Ann Behav Med* 2023). Koh 2025's
5-of-35 finding was not an outlier.

What was missing was the content the evidence ranks highest and the
record can actually fire: **GLP-1 side-effect self-management timed to
the state that produces it.** The 2025 multi-society advisory, the 2025
Mayo review and Wharton 2022 all put behavioural GI management first
(smaller meals, stop at fullness, fluids, fiber for constipation), and
Jeni already holds both signals — `CyclePosition` and the side-effect
logger.

Two notes, taking the catalog from 13 to 15:

| trigger | fires on | teaching | action |
|---|---|---|---|
| `fluidsOnAQueasyDay` | nausea or loose stomach logged within 2 days | eating and drinking happen together; these drugs quiet thirst as well as appetite; sips through the day | ask jeni what to eat today |
| `constipationWithLowFiber` | constipation logged within 3 days **and** her own mean fiber < 18 g/day | fluid and fiber work together; either alone does much less; it usually settles | add something with fiber |

**Priority:** `fluidsOnAQueasyDay` sits directly under "she came back"
— above the frightened-morning note and every pattern. It is the only
trigger in the list whose subject is a named safety mechanism rather
than a behaviour, and it is true for a day or two at most.

**The QUIET rules are the content.** `constipationWithLowFiber`
requires HER fiber to be the low half of the pair: telling someone
already eating 35 g of fiber to eat more fiber is how a note stops
being believed. And both notes are forbidden a volume — two tests
assert that no millilitre, ounce, cup or "glasses" can appear in either
note's rendered line, `because`, evidence, action label or suppressed
form.

**B2B is unchanged and needed no changes.** A clinic note for the same
trigger overrides; a clinic fluid instruction is a program fact that
outranks and silences the default; attribution is a word plus a drawn
mark, never colour. That the two new notes required zero B2B work is
the authority model doing its job.

---

## 6 · WHAT XXXL CAUGHT

Four breaks, all the same shape — *a row that fits at 17pt is not a
layout, it is a coincidence.* Two were mine, two were pre-existing.

| surface | at XXXL | fix |
|---|---|---|
| Home's greeting *(pre-existing)* | `afternoonmaya.` over a lone `,` — an HStack of two Texts wrapping independently | one concatenated Text: two faces, one run, wraps as a phrase |
| the day tier *(new)* | `the day  1,66 of 1,47…` | stacks from XXXL up |
| the split legend *(new)* | `· p… 2… · c… 3… · f… 11 g` | stacks from XXXL up |
| the tools grid *(pre-existing)* | every title truncated; statuses broke mid-word (`logg / ed t…`) | one column from XXXL up; the tile's word may wrap to two lines |

Verified after: Home, the plate reading and the tools grid read
complete at XXXL with nothing clipped; iPhone SE (375pt) renders the
three-column chemistry row and the legend with no truncation.

**A tooling note for the next session, because the record currently
says the opposite.** E8.1 recorded the simulator argument as
`content-size` (hyphen). On this runtime it is `content_size`
(underscore) and the hyphen form errors out. Both spellings appear in
the eras' notes; run `xcrun simctl ui <udid> content_size` with no
value to have the runtime tell you.

---

## 7 · THE COHERENCE FIXES

Each is one violation of a law already written, found by looking at
the running app:

- **MoveSheet's week reading** was a whole sentence in italic serif —
  §12.13 twice over: italic is the 1-3 word punch, never a clause, and
  a sentence inside an instrument panel is a caption (§6.1), not an
  editorial line.
- **Breathwork answered "which is selected?" two ways on ONE screen** —
  the occasion chips in ink, the duration chips with a white capsule.
  Selection is ink (§3, §5.4).
- **The Method note's primary action was a blush pill.** Rose is the
  DATA hue — everything drawn fills from it, ink keeps words and
  selection — so a rose button is a quantity you can press. Ink now,
  like every other primary action in the product.
- **The QA seeder's palette** (see §2③).

---

## 8 · WHAT MEAGAIN TAUGHT, AND WHAT WAS REFUSED

62 frames read, not grepped.

**Taken (as principles, not pixels):**
- **Two or three nutrients get a shape; everything else is demoted into
  one small group.** Its Log Meal screen gives fiber a bar and protein
  a ring, then collapses calories/carbs/fat into a three-line "Other"
  block. That is the same instinct as Jeni's own §9 law, executed —
  and it is the single idea that shaped this pass's nutrition tiers.
- **Logging affordances should be one gesture from anywhere**, and the
  quick-add remembers common amounts.
- **A compact status band beats a dashboard grid** for one-glance
  comprehension.

**Refused, explicitly:**
- Its identity, mascot, palette and illustration style. Nothing here
  looks like it.
- Its water UI — a big glass vessel with a plus button and a `95 oz`
  goal. Jeni ships the opposite conclusion, on evidence (§4).
- Its onboarding claims (`3X More Effectively`, `82% of new GLP-1
  users…`, fabricated review cards). Jeni's compliance floors forbid
  first-party numeric outcome claims, and §1.6 forbids a number
  without a collected field behind it.
- Its medication-level pharmacokinetic curve. v24 §11 already rejected
  a PK curve on purpose; nothing here reopens it.

---

## 9 · WHAT WAS DELIBERATELY LEFT ALONE

- **The paywall, pricing, entitlements, `AppPhase`, RevenueCat, auth,
  Supabase authority, migrations.** Zero diff. `e5.firstPlate.enabled`
  still false. No migration was needed or written.
- **The evening close, the morning letter, the dose sheet, Becoming,
  onboarding.** Walked and inspected; they are at the bar. The close's
  ledger + one-hero-sentence and the letter's typeset flow are the two
  best surfaces in the product and were not touched.
- **The book's photo-led day spreads** (v23's design). Once the seed
  stopped shouting, the layout reads correctly.
- **Settings' SF-symbol rows.** Native, legible, and the design law's
  §12.6 exception already covers them. Changing them would be churn.
- **The bundled 84-lesson corpus.** Unreachable, and the founder's
  recorded decision is to keep it in the repo.
- **`MethodEngine`'s architecture, the 13 existing notes, and the
  silence law.** Re-reading the evidence confirmed them; two notes were
  added, nothing was rewritten.

---

## 10 · VERIFIED

- **1002/1002 app tests** (+3 this pass) · **140/140 package tests**
  (run from `Packages/PlankFood` — the app scheme cannot host that
  target).
- Frame review of the Home arrival at 12fps: the ring traces, the
  numeral counts, the split lands left-anchored, and **the band's
  height is stable from first paint** — no measure-then-jump, which is
  what the removed carousel's fallback height produced.
- XXXL and iPhone SE captures for every redesigned surface, before and
  after (§6).
- The two new Method notes filmed via `--debug-method-fluids` /
  `--debug-method-fiber`.

## 11 · REMAINING DEBT

- `PlateDetailSheet` cannot show micronutrients: `FoodLogEntry` never
  stored them, so only the fresh post-scan reading has them. Absent
  rather than invented, per §1.6 — but it means the same dish reads
  richer before it is filed than after.
- A long dish title truncates in `JKSheetChrome` at XXXL. Shared
  primitive, narrow case, left alone rather than risked.
- Move still leads with `0 of 2` and carries a dashed divider that
  exists nowhere else in the product.
- The desk's empty state remains ~40% void between the disclaimer and
  the composer.
- `--uitest-open-method` still needs `--uitest-seed-queasy` (or a
  record that earns a note) to render anything. That is correct
  behaviour, now documented as such.
