# THE PORTION AND THE SOURCE — the food system, re-measured

**Status: BUILT 2026-08-12.** Not an era. A depth pass over the food
rail treated as a product inside the product.

No migration. Zero diff against the reviewed release (`1710180`) in
Payment, Paywall, Auth, Sync, `supabase/migrations`, `AppPhase`,
entitlements, RevenueCat, medication authority, HealthKit read types,
`Info.plist`, `pbxproj`, or the analytics vocabulary frozen in
`24_MEASUREMENT_CONTRACT.md`. 1.2.0 (30) is in review; this is for the
next build. **The Edge Function change is written, type-checked and NOT
DEPLOYED.**

---

## 1 · THE SEAM

The brief named the Nutrition Facts pipeline as the likely biggest gap
and gave permission to disagree. I disagree, and the reason is the
brief's own sentence:

> *"A mathematically precise nutrient number attached to the wrong
> serving assumption is still wrong."*

That is the defect, and it is everywhere:

> **The pipeline knows the SIZE OF THE THING. It never learns how much
> of it she ate — and every surface presents the result as if it did.**

A missing vitamin D is a **gap**. A whole 12-inch pizza filed as one
meal is a **wrong number wearing a confident ring**. Filmed, before any
change:

> `96 g` protein, **`of 90 g today`**, floor met, bar full.
> `2200` kcal. Verdict: *"a little over today."*

Every one of those is a claim about a dish for eight.

---

## 2 · WHAT I FOUND, MEASURED BY READING THE RUNNING CODE

| # | a layer knows | and does not say it | proof |
|---|---|---|---|
| ① | the EF computes `servings_in_dish` + `is_shareable`; its own worked example C says *"the app lets the user say they ate 2 slices"* | **zero readers.** Threaded through 8 copy constructors, dropped at every render site | grep: writes only |
| ② | the ladder is a hard-coded `1/¾/½/¼`, clamped `min(f, 1.0)` | one slice of an 8-serving pizza was **unreachable**; two servings unloggable | `SnapResultMath:162` |
| ③ | `BarcodeRead` prices exactly ONE serving and notes so | `confidence: 1.0` — the most confident object in the app, on a pure portion assumption | `BarcodeRead:99-113` |
| ④ | there is **no label branch in the EF at all** | the hint rides `text` into a prompt saying "estimate for the WHOLE visible food"; `servings_per_container` is not in the schema | `index.ts:271` vs `FoodVisionService:111` |
| ⑤ | `EntryMethod.isPrintedTruth` is written as law | **zero production call sites** (1 definition, 1 test) | grep |
| ⑥ | `PlateDetailSheet.provenanceLine` has correct per-door copy (E8.1) | `ResultDetailCopy.provenance` — **the surface she sees first** — returned `"estimated from the photo · ranges, not exact"` with no branch | `ResultDetailCopy:298` |
| ⑦ | the DTO carries sodium, sugar, `itemsDetail`, `corrections`, the door | `read_food_day` returned `title/at/kcal/protein` **only** | `JeniReadTools:115` |
| ⑧ | `applyPriors` is documented as running for "photo + describe" | **one call site: photo** — and the doc is the defect, not the code. See §12 | `FoodCaptureDispatcher:140` |

**⑥ is the sharpest.** E8.1 was *named* for killing "your typed plate
was read from your photo." It fixed the detail sheet and left the
identical lie standing one surface upstream, on the screen where the
decision is actually made. The correct vocabulary existed, in this repo,
in this domain, written one era earlier, as a private static on the
wrong type.

**⑦ is the same shape as last session's finding, one layer over.** The
last pass restored her corrections to the DTO for the plate page. The
coach still could not see them. *"was my lunch high in sodium?"* and
*"what did i correct yesterday?"* were unanswerable **from a record
holding the answer.**

### Three things I expected and found wrong

**① The label door is not "missing four micronutrients". It does not
know it is reading a label.** There is no branch. The model gets a
food-estimation prompt plus a contradictory hint, and no field anywhere
can carry servings-per-container. The micros are the small half.

**② Adding a nutrient field is not the compatible move; removing a
copy-constructor is.** `SnapRefineMerge.withId` was a 25-parameter
re-init and silently dropped `micros` — the **fourth** time in this
package a hand-written init with defaulted parameters lost a field the
compiler could not see was missing (`reattributeEntries` did it three
times). Fixed as a class: `items`, `id` and `nutritionSource` are `var`,
and every "copy but change one thing" site is a mutation now.

**③ The `--food-debug-success` fixture was already shareable.** Its
jeyuk item carries `servingsInDish: 2, isShareable: true`. Two eras
reviewed that surface with the share fields sitting in the fixture,
unread.

---

## 3 · WHAT SHIPPED

### `PlateShare` — the portion is part of the number

One pure engine, no new stored field, no migration.

- **The common plate is untouched.** The trigger is the model's own
  `is_shareable` on the item carrying the calories; the prompt sets
  `servings_in_dish=1, is_shareable=false` for "a normal single plate
  (the common case)". A bowl of oatmeal keeps the ladder it always had.
  **Logging does not become a questionnaire; the question appears only
  where the answer moves the record by multiples.**
- **The number is never changed silently.** A shared dish still defaults
  to "all of it". Defaulting to 1/N would be guessing in the other
  direction. What changed is that the plate SAYS what its numbers
  describe, and offers rungs that can express the answer.
- **The ladder comes from the dish.** 8 slices → `all of it · about half
  · 2 slices · 1 slice`. A 4-serving platter → `all of it · 2 servings ·
  1 serving` (the serving label wins a collision with "half" because it
  is the more precise instrument).
- **Packaged food counts UP.** `min(f, 1.0)` was right for a photograph
  and wrong for a package. A barcode read now offers `3 · 2 · 1 serving
  · half`, and stops where the package does.
- **The package's size came free.** Open Food Facts already carries
  `product_quantity` and `serving_quantity`; `servings_per_container` is
  derived from data the barcode door has parsed since v23. Reuses
  `servingsInDish` rather than adding a field: its meaning is "how many
  servings the whole thing is", and for a package the whole thing is the
  package. nil unless the arithmetic is sane — OFF is community-edited,
  and a mis-keyed quantity must produce **no claim rather than a wrong
  one**.

### The source is part of the number

- `NutritionSource.labelDeclared` — the one epistemic state the enum was
  missing. Every other case is somebody ESTIMATING or a database being
  CONSULTED; a US panel is neither, because 21 CFR 101.9 obliges the
  manufacturer to declare it. Stamped at the dispatcher, the one
  chokepoint that still knows which door was used.
- `EntryMethod.provenanceLine` moved down to the type that owns the
  doors. Both surfaces read it; a door cannot ship without a sentence.
- **Printed truth skips the hedges.** Both remaining branches in
  `ResultDetailCopy` describe a model judging a photograph — a kcal range
  it invented, or a confidence it assigned itself. Neither may speak for
  a transcription. `isPrintedTruth` has its first caller.

### Jeni can read the record she has

`read_food_day` now returns, per plate: what was IN it, carbs, fat,
sodium, sugar and fiber **where the plate carries them**, the door as a
sentence, and **her own correction words**. A missing key means never
measured — handing a model a `0` it reads as "no sodium" is the
estimate-dressed-as-measurement defect in a JSON payload. Numeric
suppression still removes all of it. **Zero EF deploy**: the allowlist
gates tool NAMES, and this enriches an existing tool's return payload.

---

## 3b · A CORRECTION TO THIS DOCUMENT — §12 BELOW

The first version of this record called ⑧ "the biggest remaining
knowledge seam" and named restoring it the highest-leverage work
available. **That was wrong, and I verified it by building the test
rather than the feature.** §12 has the argument. The seam was a stale
doc comment, and I was the reader it misled.

## 4 · THE CONSENT SCREEN — deleted as a wall, kept as a gate

Founder, mid-session: *"this old screen probably needs a major
redesign"*, then the better question — *"is that screen fundamentally
needed? looking at meagain screens, they have a lot of visual 'how to'
instructions for first time users."*

**It cannot be deleted.** App Review 5.1.2(i) requires explicit consent
before user data reaches a third party, and a photo of someone's dinner
going to OpenAI is exactly that. Removing it is a review risk on a build
already rejected once.

**But it was doing one job with a whole screen.** A first-time user
meets THREE walls before her first photo — this sheet, the food
onboarding questions, then the OS camera prompt — and this one taught
her nothing.

It is a first-run primer now: **what actually makes a reading accurate**,
then the disclosure, then the affirmative accept. Same number of walls;
one of them is now the only place the food rail ever teaches.

**The three teachings are not generic tips.** Each is lifted from a
failure mode the vision model names in its own system prompt: cropped
food is a `needs_second_photo` trigger; *"if NO usable reference is in
frame, widen portion_grams_low/high and lower confidence"*; and depth is
how it sizes a bowl (*"a heap ≈ 0.5 × its peak height"*), which a
straight-down shot hides. Following them measurably narrows the range
she gets back — the rare onboarding screen that improves the product's
own accuracy, not just her comprehension.

Also fixed there: **it said everything twice** (two of three bullets
restated the sentence above them, so the one NEW fact sat third in a
list that had taught her to skim); an outlined card with a hard drop
shadow (v1 scrapbook chrome no current surface draws); rose checkmarks
that were decoration AND the wrong sign (a filled check reads "agreed"
where she has agreed to nothing); ~40% dead space; and three
`.system(size:)` faces. Every disclosure fact survives.

---

## 5 · WHAT FRAME REVIEW CAUGHT

Everything here was invisible in the code and obvious in a frame.

1. **The consent card was painting every glyph twice.** `.shadow`
   applies per drawn primitive unless the subtree is flattened; with
   `radius: 0` that is not a glow, it is a hard second copy 3pt down and
   right. Stable across seconds — not an animation mid-flight. It shipped
   on the one screen this file's header says must be exactly right.
   `.compositingGroup()` on the three food surfaces that draw it.
2. **The share note was below the fold.** Placed by the ladder, it
   arrived after every number it qualifies, in a detent that opens
   already scrolled. It sits under the dish name now: a subject before
   its predicate.
3. **At AX5 the dish title and the stepper truncated each other** —
   "pepp / ero…" beside "1,08…". Both were hiding content to preserve a
   horizontal layout that no longer fit. They stack at accessibility
   sizes.
4. **The share note was too long for AX5** and pushed the protein figure
   out of the opening detent. Shortened to the two facts it must carry.
5. **The chip row could not wrap.** The shipped row was a fixed HStack of
   `.fixedSize()` chips reading "¾ / half / bites"; the share rungs are
   words. A control that runs off the edge is a control she does not
   have. The onboarding sheet's flow layout was promoted rather than a
   second one written.
6. **The three primer marks were not on a shared optical grid**, and the
   angle mark read as an eye. Rows 1 and 3 are now the same plate drawn
   twice, circle and ellipse, so they teach the contrast between them by
   standing three lines apart.

**New QA doors, both DEBUG-only:**
- `--uitest-open-camera` — the chooser's meal door needed a TAP to reach
  the surface behind it and simctl cannot tap, so the reading could only
  be filmed by a full XCUI leg.
- `--food-debug-shared` — worked example C from the EF's own prompt,
  every value one the deployed schema emits for that photo. No door could
  reach this state before, which is part of why the share fields went
  four eras without a reader.

---

## 6 · WHAT I DELIBERATELY DID NOT DO

- **Persist micronutrients.** The previous pass's reasoning stands and
  this pass did not weaken it.
- **Flip `publishesMicros` for `.labelDeclared`.** A US panel prints all
  four, but the schema does not ASK yet, so we have not asked and do not
  know. "Asked, and there is none" is knowledge; "never asked" is not. It
  flips in the same change that lands the fields.
- **Add micronutrients to Home, the plate hero, or any daily read.**
- **Default a shared dish to 1/N.** Guessing in the other direction.
- **Merge the food-onboarding questions into the primer.** They feed the
  EF's cuisine and dietary priors; folding them in is a separate change
  with real behaviour risk.
- **Give the words door priors.** `SnapRefine` routes corrections
  through `.text`, and applying a prior to a correction response would
  make her old numbers outrank her new words. It needs a flag, not a
  blanket change. **Named, not smuggled.**
- **A water tracker, a nutrition dashboard, a streak, an analytics
  event, a migration.**

---

## 7 · THE EDGE FUNCTION — WRITTEN, NOT DEPLOYED

`supabase/functions/food-vision/index.ts`. **Founder gate.**

```
supabase functions deploy food-vision --no-verify-jwt
```

**What it adds:** a real label branch (`buildLabelPrompt`), plus
`serving_size_text`, `servings_per_container`, `added_sugars_g`,
`vitamin_d_mcg`, `calcium_mg`, `iron_mg`, `potassium_mg` per item and
`is_nutrition_label` at the top level.

**Serving semantics come first.** The brief asked whether tracing the
label revealed a more important omission than the four micros. It did:
nothing in the schema could carry a package's serving size or how many
servings it holds.

**Compatibility, both directions:**
- **Old client → new EF:** `isLabelRead` also sniffs the shipped
  client's text hint, which is the only signal 1.2.0 (30) has. Deployable
  BEFORE the next app release, not after it.
- **New client → old EF:** `read_mode` is destructured and ignored; every
  new response field is Optional in the Swift decoder, so a by-name
  decode supplies nil. **This build runs unchanged against the EF in
  production today** — proven by 187/187 with no network stub changes.
- **Strict mode:** verified programmatically that every property is in
  `required` at both levels (31/31 item, 7/7 top). The 2026-06-08 Phase A
  trim broke exactly this invariant and caused a 100% scan failure rate.
- `deno check` reports the identical 12 pre-existing `supabase-js`
  generic errors as `HEAD`. **Zero new type errors.**

**The client is already wired**, so the deploy lights it up:
`servings_per_container → servingsInDish` makes the barcode/label ladder
exact with no new concept.

---

## 8 · B2C / B2B

No authority work needed, which is the authority model doing its job.
Nothing reads or writes `program_facts`; `CareProtocol` and
`MethodNote.authority` untouched. The richer record is care-relevant in
the right way: a clinician reading protein adequacy or a sodium pattern
now gets numbers whose PORTION is attributable, and `labelDeclared`
separates a manufacturer's declaration from a model's estimate — the
distinction a care team would need first. **No clinician surface was
built.**

---

## 9 · PROOF

- **1009/1009 app** · **187/187 package** (was 154; +33).
- Release configuration compiles.
- Protected paths verified empty against `1710180`: Payment, Paywall,
  Auth, Sync, migrations, `AppPhase`, `Info.plist`, `pbxproj`. Zero
  HealthKit read-type diff. Zero analytics vocabulary diff.
  `e5.firstPlate.enabled` still false.
- Every fixture is a shape production can produce. The pizza fixture is
  the EF's own worked example, value for value.
- Filmed: the shared reading before/after, at default and AX5; the
  two-item plate; the consent card ghosting before/after; the primer
  twice.

## 10 · WHAT STILL FEELS BELOW THE BAR

- **The Food Book is untouched.** The brief asked what a collection of
  meals BECOMES — why she opens it tomorrow, next week — and I did not
  answer it. The one part of the brief I did not reach.
- **`ItemDetail` still carries no per-item fiber or sugar.** Deliberately
  left: nothing renders `itemsDetail`'s fields as a per-item ledger
  today, so adding them would create exactly the write-only field this
  session spent its length criticising. Add the reader first.
- **Three walls before the first photo.** The primer earns its wall now;
  the onboarding questions still do not obviously earn theirs.
- **The on-photo chip truncates at AX5** (`pe… 2,200`). Decorative
  overlay; the sheet below carries the same information completely.
- **Two non-food surfaces still cast the per-glyph shadow**:
  `LastNightSleepCard.swift:57` and `LessonReaderView.swift:1215`. Same
  one-line fix, out of this session's scope. **Found, not fixed.**
- Nothing here can be falsified against a payer. The measurement
  contract's first clean read still gates every product decision.

**SAFE FOR NEXT BUILD: YES.**

## 11 · THE SINGLE HIGHEST-LEVERAGE THING NEXT

**Deploy the Edge Function.** One command, founder-gated, and it turns
the label door from an estimate into a transcription with serving
semantics. Everything on the client is already wired for it.

After that, **the Food Book** — the brief's question I did not answer.

## 12 · THE ONE I GOT WRONG, AND WHY IT STAYS WRONG

I reported that the words door had lost E4's flywheel and called fixing
it the highest-leverage work available. I had read this, on
`FoodCaptureDispatcher.userId`:

> *"photo + describe recognitions are checked against the user's own
> corrected record"*

The code checks photo only. I trusted the comment over the engine —
the exact failure this project has now recorded in four straight
sessions, and I did it while writing a document about it.

**The exclusion is deliberate, and it is right for a sharper reason
than it had written down.**

`PlatePriors` keys on the dish TITLE and applies a UNIFORM SCALE. On a
photograph that is exactly right: the portion came from the MODEL
sizing an image, so her prior corrects the model's sizing and the scale
means *"your usual bowl is bigger than it guessed."*

Through the words door the portion came from HER. **"half a turkey
sandwich"** normalizes to the same key as the whole one she corrected
last week, so a prior would scale her half UP to a whole — silently,
and past the ±3× clamp, which cannot see a 2× error. *"a few bites of
pizza"* is the same defect at 8×.

> **A prior must never overrule a portion the user stated herself.**

The words door is the one door where she states it. That the door E7
made the front door is the door this engine may not touch is not a gap
in the flywheel; **it is the flywheel refusing to overwrite its own
source.**

Both phrases above are from the brief's own list of realistic words-
door inputs, which is how the case was found.

**What shipped instead of the feature:** the stale comment replaced
with the argument, the law written out in `PlatePriors`, and
`PlatePriorsWordsDoorTests` — five tests, one of which asserts that the
engine really would double the half sandwich. The next reader who wants
to finish the flywheel has to delete an argument rather than an
omission.
