# E7 — SAY IT: the decision

2026-08-11 · branch `feat/app-v2` · rides RC 1.2.0 (30) · no migration,
no EF deploy, **no paywall change**. Written BEFORE the build, per the
founder's instruction.

Locked founder decisions this era obeys without reopening:
the hard paywall stays (`e5.firstPlate.enabled` = false, untouched);
pricing / tiers / downsells / entitlement / paywall sequencing
untouched; nothing functional moves before the wall.

---

## 1 · WHAT THE DATA ACTUALLY SAYS

E6 established the honest limit: production cannot discriminate between
in-app features (~2 payers/day, version-fragmented instrumentation,
105 of 160 `main_tab_appeared` users never purchased on a hard-gated
app). Nothing has changed. So this era does **not** claim a data
mandate for its shape. It uses only the numbers that survived E6's
audit, plus the product's own written law.

What survived, and what it forces:

| number | source | what it forces |
|---|---|---|
| payer median **2.0 active days**; 12% at day 28 | `18_E5_EVIDENCE`, n=151 | anything that pays out on day N+1 reaches a minority |
| the scan funnel **completes ~100% once started, 3.4% ever start** | `14_E4_DECISION` | the defect is the DOOR, not the flow |
| day-0 food loggers return **76% vs 17%** | `14_E4_DECISION` | one record on day 0 is the highest-value single act |
| 82% of onboarded users have exactly **one** active day | `11_E3_DECISION` | week-scale mechanics serve a tail |

And one thing that is not a metric but is stronger evidence than any of
them — `00_THE_SYSTEM` §7.6, the literature review the whole plan rests
on:

> **GLP-1 has exactly two proven content pillars: protein 1.2–2.0 g/kg
> and resistance 2–3×/wk (lean mass = 25–40% of drug-induced loss).**

§9 turns that into law: **"protein floor + fiber lead the glance layer;
kcal quiet."**

## 2 · WHAT I WALKED, AND THE THREE THINGS I FOUND

Twelve surfaces walked at HEAD in the simulator with a populated payer
account. Three findings, all verified in a capture, all the same
defect wearing three costumes.

**2.1 The only wide door to the record is a camera — and the cheap
door is hidden behind it.**

The centre tab opens `ScanChooser`, whose question is *"what are we
looking at?"* — a camera question. It offers two cards (a meal photo, a
body photo) plus a relog pill. `QuickAddView` — type a sentence, get a
reading — **already exists, already works, and is reachable only from
inside the camera screen**, behind a small "snap instead" link. The
plumbing to open it directly (`AppRouter.foodDescribe(text:)` →
`CaptureFlowView(.quickAdd)`) was built in E3 for chat and is used by
nothing else. So the product's cheapest path to a record is buried
under its most expensive one, and 3.4% ever start.

**2.2 The reading answers with a spreadsheet led by the quiet number.**

`SnapResultView`'s hero block is a 2×2 grid whose top-left cell —
largest numeral, only ring — is **calories**, with "37% of today".
Protein is top-right, smaller, with a bar. `QuickAddView` says *"jeni'll
figure out the calories."* Home's hero carousel opens on `.calories`
and reaches `.protein` only on a swipe. Three surfaces, one law, all
three inverted.

For a payer eating 1,100 kcal on a drug that suppresses appetite, the
calorie number is the one fact she does not need and the product's own
research says to keep quiet. Protein is the fact that decides whether
the weight she loses is fat or muscle.

**2.3 Nothing answers back in the moment.**

"add it" dismisses the sheet and returns her to Home. Every intelligence
this branch has built pays out later: E4's morning read on day N+1,
E6's desk line when she next opens the chat tab. A user whose median
life is 2.0 days is being paid in a currency she will not be there to
spend.

## 3 · WHAT I EXPECTED TO MATTER AND DIDN'T

- **"The desk's dead space is the biggest UX problem."** It is real
  (~500pt, captured) and it is cosmetic. The desk is a surface she has
  to go to; the capture moment is one she is already in. Fixing the
  desk's emptiness would have been polishing the wrong end of the loop.
- **"MeAgain's medication-level curve is the thing to answer."** It is
  their best object and Jeni must not build it: v24 §11 already refused
  PK curves on provenance grounds, and `00_THE_SYSTEM` §9 lists "never:
  PK curves" under MEDICATION. Refused again, on purpose.
- **"The chooser needs better art."** E5 already fixed the art. The
  chooser's problem is its *question*.
- **"Steps / Method / breathwork are the design debt to clear."** They
  are debt (§7) but they are a list, not a loop. The brief says not to
  blindly fix the previous report's list.

## 4 · THE ERA: **SAY IT**

> **Putting something into the record must cost one sentence, and the
> record must answer in the same breath — about the thing that
> matters.**

Words in, words out. The camera and the spreadsheet are the machine's
preferred formats, not hers.

Three moves, one loop:

**B1 · THE DOOR IS WORDS.** The capture surface stops asking a camera
question. A focused field is the first and largest thing; the camera,
the relog and the body scan become quiet peers under it. Two
geometries instead of four. This is a **simplification** — it un-buries
a surface that already exists and deletes the "snap instead"
inversion. Zero new destinations.

**B2 · PROTEIN LEADS.** The reading, the describe screen and Home's
carousel are re-ordered to obey `00_THE_SYSTEM` §9. Protein takes the
lead instrument with the day's floor as its denominator; calories,
carbs and fat become one quiet row. No new data, no new engine — a
hierarchy inversion and a deletion (the kcal ring goes).

**B3 · THE ANSWER.** On "add it", the reading's grid **morphs into one
true sentence** in the same real estate, then files. Composed by a new
pure engine over the same `TodayStateService` / `TargetsService` inputs
every other surface reads. Never a verdict, never a percentage, never a
reprimand, and never invented: no weight on file → no floor → no
denominator.

Riding along, because the loop touches them or because they are
one-line standing violations: the steps detail's off-palette gradient
ring, and the food rail's calorie-first copy.

## 5 · THE HYPOTHESIS, AND HOW IT DIES

**Hypothesis.** The binding constraint on a payer's first days is not
what Jeni knows — E1–E6 gave her plenty — but the **cost of the first
record and the latency of the first answer**. If a record costs one
typed sentence and returns one true sentence about protein
immediately, then the share of payers who put anything in on day 0
rises, and it rises because the door got cheap, not because the app got
louder.

**Falsification — any one of these kills it.**

1. **The door was never the problem.** Post-merge, `food_log_created`
   within 24h of `purchase_completed` does not rise above the current
   day-0 rate, *and* the words path takes a minority of new entries.
   If the cheap door ships and is not used, the 3.4% was about
   motivation, not friction, and E7's premise is wrong.
2. **The words path cannot carry the weight.** If describe-path
   readings are corrected (`FoodCorrectionSheet`) at a materially
   higher rate than photo readings, then words buy speed with accuracy
   and the trade is bad — the trust vacuum (`r1` §9) is the one asset
   the product cannot spend.
3. **The answer reads as a verdict.** If any composed sentence renders
   praise, blame, a percentage, a grade, or a number the user never
   gave us, the engine has broken the honesty law and must be pulled,
   not tuned. Pinned as a unit assertion, not a hope.
4. **Protein-first makes the reading unreadable.** If, in the
   simulator at XXXL type and in the zero-target state, the re-ordered
   reading loses the plate's identity or renders a bare "0 g", the
   inversion is wrong and calories return to the lead.

**Explicitly NOT claimed:** that this moves retention. A 2.0-day median
will not be moved by one era, and the instrumentation cannot currently
prove it either way (§1). The claim is about the first record and the
first answer, which are observable.

## 6 · WHAT MEAGAIN TAUGHT, AND WHAT IS REFUSED

Studied: 62 screenshots, full onboarding → paywall → Overview → Dose →
logging sheets → membership.

**Taken as principle (never as pixels):**
- One universal capture affordance. Their `+` opens *every* record type
  from any tab. Jeni already owns that position (the centre tab); it
  was spending it on a camera. That is the whole of B1.
- Log sheets share one grammar — date row, the object, one primary
  button; editing swaps to `Done` + a destructive verb. Jeni's sheets
  are individually good and collectively unrelated.
- The instrument *is* the input (water = a glass that fills, weight = a
  ruler you drag). Jeni's weight ritual already does this and is the
  best log sheet in the app; it is the model, not MeAgain's.
- Every number carries its denominator inline and dimmed ("87g /160g").
  Adopted for the protein lead.

**Refused, deliberately:** the capybara and its streak flame; the
community poll feed on Home; fabricated proof ("82% of new GLP-1 users
reported better outcomes", "3× more effectively", stock-photo
testimonials); drug brand names as UI furniture; the membership
credit-card and its feature-comparison table; the PK curve; grey cards
inside grey cards; purple gradients.

## 7 · UNISEX AUDIT — MEASURED, NOT ASSERTED

E6 reported the Method's gendered copy anecdotally. Measured now, by
walking the corpus rather than grepping the UI:

- **`manifest_v1.json`, 84 lessons / 336 pages: 62 lessons (74%) carry
  female-coded language.** 63 page headlines and 69 page bodies. The
  signature form of Act III is literally *"a woman who [chose] her 20"*
  — an identity line the reader is invited to inhabit.
- 7 further strings in `voicePlaybook`, 5 in `acts` — the *authoring
  rules* are gendered, so any new lesson inherits the defect.

This is the largest unisex debt in the product and it is **not fixable
inside this era**: rewriting 74% of a therapeutic corpus is an era of
its own, and the Method's fate (dispersal vs retirement) is still an
open roadmap question that should decide the voice before the rewrite.
Sized here so it can be scheduled instead of re-discovered.

Preserved on purpose (the founder's carve-out for scientifically
meaningful sex-specificity): study populations stated as such —
`BreathworkProtocols`' "n=40 women", the 2016 image-feed review's
"young women", Alleva & Tylka's sample.

Fixed in this era: the food rail's own copy, which the loop touches.

## 8 · WHAT THIS ERA WILL NOT TOUCH

The paywall and everything behind it. `PaywallView`, pricing, tiers,
bands, downsells, exit intent, entitlement, `AppPhase` ordering,
`e5.firstPlate.enabled`. The E5 experiment stays implemented, stays
off, stays whole.

Movement / the workout asset library (roadmap E3's kill, deferred
again — it is not in this loop). The Method reader and breathwork
imagery (§7). The desk's dead space (§3).
