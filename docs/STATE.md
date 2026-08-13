# Jeni — Canonical State

## §0.-18 — THE PORTION AND THE SOURCE (2026-08-12) — CURRENT

The food rail re-measured as a product inside the product.
`docs/app_v25/27_THE_PORTION_AND_THE_SOURCE.md` is the record. No
migration, zero diff against the reviewed release in Payment/Paywall/
Auth/Sync/migrations/`AppPhase`/`Info.plist`/`pbxproj`, zero HealthKit
read-type change, zero analytics vocabulary change.

**THE SEAM: the pipeline knows the SIZE OF THE THING and never learns
how much of it she ate.** Filmed before any change: a whole 12-inch
pizza read `96 g` protein `of 90 g today`, floor met, bar full, 2,200
kcal, verdict "a little over today". The brief's own sentence names the
defect: a precise nutrient attached to the wrong serving assumption is
still wrong. Vitamin D is a GAP; this is a WRONG NUMBER with a
confident ring on it.

**Eight measured instances.** The EF has computed `servings_in_dish` +
`is_shareable` since 2026-06-23 — its worked example says "the app lets
the user say they ate 2 slices" — and they had **zero readers**, passed
through 8 copy constructors and dropped at every render site. The
ladder was hard-coded `1/¾/½/¼` clamped `min(f, 1.0)`, so one slice of
an 8-serving pizza was unreachable and two servings unloggable.
`BarcodeRead` prices ONE serving at `confidence: 1.0`. **There is no
label branch in the EF at all** — the hint rides `text` into a prompt
saying "estimate for the WHOLE visible food". `EntryMethod
.isPrintedTruth` was written as law with **zero production call
sites**. And `ResultDetailCopy.provenance` — the FIRST surface she sees
— returned "estimated from the photo · ranges, not exact" with no door
branch: **the exact lie E8.1 was named for killing, still standing one
surface upstream of where E8.1 killed it.**

**SHIPPED:** `PlateShare` (pure engine, no stored field) — the ladder
comes from the DISH; the common plate is untouched because the trigger
is the model's own `is_shareable`; the number is never changed
silently, the plate just SAYS what it is of; packaged food counts UP,
with `servings_per_container` derived free from Open Food Facts data
the barcode door already parsed · `NutritionSource.labelDeclared` (the
missing epistemic state) stamped at the dispatcher chokepoint ·
`EntryMethod.provenanceLine` moved to the type that owns the doors, so
a door cannot ship without a sentence · **Jeni's `read_food_day` now
returns items, sodium, sugar, carbs, fat, the door, and HER OWN
CORRECTION WORDS** (zero EF deploy — the allowlist gates tool names) ·
the copy-constructor bug class killed (`withId` dropped `micros`, the
4th time a defaulted-parameter init lost a field).

**THE CONSENT SCREEN, founder-steered twice:** kept (5.1.2(i) requires
it) but rebuilt as a FIRST-RUN PRIMER — three teachings lifted from
failure modes the vision model names in its own prompt, then the
disclosure, then accept. It said everything twice before; two of three
bullets restated the sentence above them.

**FRAME REVIEW CAUGHT:** the consent card painted **every glyph twice**
(`.shadow` applies per primitive without `compositingGroup`; hard copy
3pt down-right, stable across seconds) · the share note sat below the
fold, arriving after every number it qualified · at AX5 the dish title
and stepper truncated each other ("pepp / ero…" beside "1,08…") · the
chip row could not wrap.

**1009/1009 app + 187/187 package** (was 154; +33). Release compiles.
Doors: `--uitest-open-camera` · `--food-debug-shared`.

**FOUNDER GATE — THE EF IS WRITTEN AND NOT DEPLOYED:**
`supabase functions deploy food-vision --no-verify-jwt`. Adds a real
label branch + serving semantics (`serving_size_text`,
`servings_per_container`) + the four FDA micros. Compatible BOTH ways
(old client → new EF sniffs the shipped text hint; new client → old EF
ignores `read_mode`, all fields Optional). Strict mode verified
programmatically; `deno check` shows the identical 12 pre-existing
errors as HEAD.

**A CORRECTION MADE WITHIN THE SESSION:** this record first called the
words door's missing prior "the biggest remaining seam" and named
restoring it the top next step. **Wrong.** `applyPriors` having one
call site is deliberate; the DOC COMMENT saying "photo + describe" was
the defect, and I trusted it over the engine's own law — the exact
failure four straight sessions have recorded, committed while writing a
document about it. `PlatePriors` keys on the dish TITLE and applies a
UNIFORM SCALE: on a photo the portion came from the MODEL, so a prior
corrects its sizing; through the words door the portion came from HER,
and **"half a turkey sandwich" normalizes to the same key as the whole
one she corrected last week** — scaling her half UP to a whole, past a
±3× clamp that cannot see a 2× error. *A prior must never overrule a
portion the user stated herself.* Both phrases are from the brief's own
words-door list. Shipped instead: the argument replacing the stale
comment, plus `PlatePriorsWordsDoorTests` (5 tests; one asserts the
engine really would double it), so the next reader has to delete an
argument rather than an omission.

**NEXT: deploy the EF** (founder gate, one command, client already
wired). Then **the Food Book** — the brief's question about what a
collection of meals BECOMES, which this pass did not reach.

## §0.-17 — WHAT THE RECORD KEEPS (2026-08-12) — CURRENT

The last 10%: a depth pass over the layers the product reaches when a
user goes further in. Not an era, no E-number.
`docs/app_v25/26_WHAT_THE_RECORD_KEEPS.md` is the record. **No
migration** (none needed — the bytes were already on disk), no
paywall/pricing/entitlement/`AppPhase`/auth/RevenueCat/Supabase change,
**zero HealthKit read-type or purpose-string change**, zero new
analytics events.

- **THE DEEPEST SEAM, and it is one seam wearing five costumes:** a
  layer knows something and does not say it, or says something it does
  not know. The detail screens are mostly fine; what breaks going deeper
  is that **knowledge stops travelling between layers.**
- **HER OWN CORRECTIONS WERE WRITE-ONLY.** E4 shipped "corrections
  PERSIST" — every fix-with-words sentence goes to the JSONL and rides
  `food_logs.payload` to the cloud and back, and **`FoodLogEntry`, the
  DTO every food surface reads through, had no field for them.** The
  only reader reduced them to a `Bool`. So she says "it was a large, not
  a medium", jeni rescales and files it, and tomorrow the plate says
  "read from your photo · ranges, not exact" with no trace she touched
  it. Now: `corrections` + `wasCorrected` on the DTO, a **YOUR NUMBERS**
  tier on the plate page (her sentences, block-quoted, in the
  transcript's own DMSans + `jeweledRose` — serif italic was MY error,
  caught by the chat's recorded founder ruling), `relog` carries them so
  the prior survives the cheapest door, and `reattributeEntries` carries
  them (that call site has now dropped a newly-added field **three
  times**). **No migration.**
- **MICRONUTRIENTS: REFUSED, ON EVIDENCE.** The brief's first named debt
  was `PlateDetailSheet` cannot show them. Measured, the provenance map
  says: **one source (USDA FDC), reached only for items the model
  flagged low-confidence (<0.5) or could not price.** `llm_direct` (the
  DEFAULT since v1.0.7) publishes none; nor does OpenFoodFacts (the
  barcode door), `canonical_pantry`, the label door (the EF schema never
  asks) or a typed meal. So they are present *precisely where the plate
  deserves least confidence* — persisting them would freeze a partial,
  inverted-reliability figure into the record forever and make the
  poorest plates read as the richest. **NOT persisted.** What WAS wrong
  is the live panel: `namedMicros` summed whatever micros existed and
  labelled it the PLATE's, so a four-item plate with one USDA-grounded
  item printed that one item's potassium as the plate's. Now gated on
  the whole plate being grounded (`CapturedItem.publishesMicros`).
  **The QA harness hid it** — `mockItems` hand-attaches micros to
  `.llmDirect` items "so the panel renders the way it does over a real
  lookup", which it cannot; two eras reviewed fiction. Also fixed:
  `PlatePriors.scale` dropped micros (the record getting poorer for
  being corrected) and `microAmount` rendered `1400` where the plate
  sheet renders `2,300 dv`.
- **MOVE. "The dashed divider" DOES NOT EXIST** — it is the week's
  rhythm drawing seven below-half days as 6×1.5 capsules, and seven
  dashes above a label IS a dashed rule (three circles now; a row of
  circles cannot become a line). **The zero was real:** `0 of 2` in 44pt
  serif under an eyebrow reading "what your body did". **A count is a
  hero only when there is something to count** — at zero the reading is
  a sentence (`MoveEnergy.strengthHeadline`), and the numeral arrives
  with the first session. Strength STAYS the headline. Also:
  "twice a week" was said **twice**, three inches apart (de-duped);
  **`steps 0 · from health` was an absence in a sensor's clothes** —
  HealthKit returns "no samples" and "zero" identically, so
  `resolvedStepsToday` returns nil and the existing "nothing has come
  through from health today." speaks; the last **rose primary button** in
  the product went ink (E9's own §3 fix, missed on a surface it was
  editing); an **underlined inline text link** became a hairline capsule;
  `MoveRecord.isEmpty` — written, tested, and never referenced by a view
  — finally gates the empty rhythm block; and **provenance did not
  scale** (`.system(size: 10)` on the one label the design law says must
  always be readable).
- **THE MOVE DETENT — founder, mid-session:** *"make this either 3/4
  screen or almost full screen as user having to scroll on this half pop
  up screen is not a good ux design."* Move sat on `tallFixed` (a single
  fixed `.fraction(0.68)`) while `JKSheetChrome` hides the grabber: a
  sheet that opened already scrolled, with no second detent and no way
  to expand. At AX5 **exactly five items fit**. Now `.large`, like every
  other sheet carrying a record. `tallFixed` is for a camera or canvas
  underneath; Move has neither. The dose and side-effect sheets were
  walked at `.tall` and are fine — **Move was the one wrong token pick**,
  and `JeniSheetHeight`'s doc now says so.
- **THE DESK'S PROOF EXPIRED EVERY MIDNIGHT.** E6 replaced the tagline
  with proof and scoped it to TODAY — the window most likely to be empty
  when somebody opens the app. A payer with a 12-day record opening at
  9am read "your coach, day to day.", the same sentence as someone who
  has never logged. Two rungs added below today's: yesterday, then the
  record's depth; the claim only when there is genuinely nothing; a
  single day is not depth; the gap still outranks all of it. **And the
  starter logic was INVERTED** — "what did i eat yesterday?" was offered
  exactly when today was empty, never checking that yesterday held
  anything, three lines under a comment claiming "a starter never walks
  someone into 'i don't have that'". **The ~40% void is ~23% measured,
  and the void was never the defect.**
- **THE SHARED PRIMITIVE.** `JKSheetChrome`'s eyebrow and title carried
  no `fixedSize(vertical:)`, so in a VStack whose `content()` is a
  flexible ScrollView the header reported a compressible ideal height and
  lost: a dish name cut to "grilled chicken…" **with two thirds of the
  sheet empty below it — a layout that hides content to make room for
  nothing.** Reproduced with an 80-char title; **not an XXXL issue** —
  any size truncates once a title needs three lines. `fixedSize` +
  `lineLimit(4)`, no `minimumScaleFactor`, and every other sheet is
  untouched because a fitting title's ideal height does not change.
- **Verified: 1009/1009 app · 154/154 package** (+14 tests, all laws not
  pixels; one rewritten, not deleted). A product bug was found by a test
  expectation and fixed in the product (`microAmount`). New DEBUG doors:
  `--uitest-plate-corrected` · `--uitest-food-yesterday-only` (the
  "today empty but history exists" state had no door — the state the desk
  was silently wrong in for an era).
- **NEXT BUILD'S HIGHEST-VALUE FOOD WORK, named not smuggled:** extend
  the food-vision schema to read the **four FDA-mandated label
  micronutrients** (vitamin D · calcium · iron · potassium are printed by
  law on every panel the label door photographs). It needs an EF deploy
  (founder gate) and 1.2.0 (30) is in review.

## §0.-16 — APP v25 E9: THE COHERENCE PASS (2026-08-12)

A product + design sweep. **No migration, no paywall/pricing/
entitlement/`AppPhase`/auth change, no analytics redefinition.**
`docs/app_v25/25_E9_THE_COHERENCE.md` is the record. Two commits
(`ab66126` · `ce075e1`).

- **THE THESIS, from walking the running app (17 surfaces captured
  before anything changed):** nutrition is the only domain that never
  became an INSTRUMENT. Everything else has a shape — weight a
  trajectory, movement a count against guidance, the day a checklist.
  Nutrition had one ring and, everywhere else, rows of equal-weight
  numbers. That single gap produces most of what reads as "dashboard"
  and "dense without hierarchy". The principle chosen: **two nutrients
  earn a shape, everything else earns a place.**
- **FOUR THINGS THE RECORD HAD WRONG**, all found by re-opening the
  product rather than trusting a prior era: ① E6's "the three food
  entrances ALREADY converge on one reading" is **false** —
  `PlateDetailSheet` is a fourth, oldest reading, and it still led with
  `340 calories` against the product's own §9 law that E7 and E8 each
  fixed elsewhere. ② **Hydration already shipped, and shipped wrong**
  (below). ③ The garish plates in THE BOOK were the **QA seeder**, not
  the product — `FoodBookQASeeder` ran 0.32-0.55 saturation over the
  full hue wheel, so two eras of design review of the book and chooser
  were conducted against banned colours. ④ "`--uitest-open-method`
  presents but does not render" is a **misreading**: the engine was
  returning silence, correctly, because the QA record earns no note.
- **HOME'S FOOD BAND: the five-face carousel is GONE.** Measured, its
  four trailing faces each duplicated something the lead face's own
  tiers already carried (`calories`→the strip's kcal cell,
  `plate`→carbs+fat, `chemistry`→fiber/sugar/sodium, `week`→Becoming).
  One composed instrument on three tiers replaces it — THE FLOOR
  (protein's ring) → THE DAY (energy as ONE shape; kcal stated once
  beside the split) → THE REST (fiber · sugar · sodium, aligned).
  **~280pt instead of ~750**, the to-do list is above the fold again,
  every number the E8 founder steer asked to keep at rest is still at
  rest, and the shear bug class (four fixes across three eras) is gone
  by construction. Five weekly log scans per render went with it.
- **THE PLATE READING, protein-first**, in the same three tiers, drawn
  by the same object (`PlateEnergySplit`, promoted to the kit).
- **`JeniRing`, the phase fix:** the gradient carried `angle: -90` AND
  the shape carried `.rotationEffect(-90)`, so the ramp sat a quarter
  turn behind its own arc — at a met floor the dark end butted the
  light start at 9 o'clock as a hard seam. Frame-caught on Home's
  protein hero. Fixes the app's most-used instrument everywhere.
- **HYDRATION: the number left, the reason stayed.** It already
  shipped — `jenifit.default`, the org-null CONSUMER protocol,
  hardcoded `hydrationMlDuringTitration: 1_800` and rendered "about
  1,800 ml across the day" during titration. The citation is ASMBS
  **post-bariatric-surgery** guidance (wrong population), and no
  credible body prescribes a personal fluid volume (IOM/NASEM and EFSA
  publish population references for TOTAL water including food; the
  2025 ACLM/ASN/OMA/TOS advisory counsels on dehydration and
  deliberately gives no target). Fluid RESTRICTION is standard care in
  heart failure, advanced CKD and hyponatremia. The field is `Int?`,
  **nil on the consumer default**; a care team may set one and it
  renders attributed. **NOT built: a water tracker** (near-null
  weight-loss evidence for this cohort, and it spends an ask on a
  2.0-day median) and **the HealthKit `dietaryWater` read** (deferred,
  not rejected — it needs a new read type in the purpose string that
  shipped one build ago, and 1.2.0 (30) is in review).
- **METHOD: 13 notes → 15**, both firing on her own record, both
  forbidden a volume by test. `fluidsOnAQueasyDay` (nausea/loose
  stomach within 2 days — the symptoms every GLP-1 label names as the
  route to volume depletion) sits directly under "she came back";
  `constipationWithLowFiber` requires HER fiber to be low, because
  telling someone eating 35 g to eat more fiber is how a note stops
  being believed. E8.1's architecture was re-read against fresh
  evidence and NOT re-litigated. B2B needed zero changes.
- **XXXL CAUGHT FOUR BREAKS** (two mine, two pre-existing): the
  greeting stranded its own comma (an HStack of two Texts wrapping
  independently → one concatenated Text); the day tier and split legend
  truncated (both stack from XXXL up); **the tools grid truncated every
  title** (one column from XXXL up). iPhone SE clean.
- **Coherence, each one violation of a law already written:** Move's
  week reading was a whole sentence in italic serif (§12.13);
  breathwork answered "which is selected?" two ways on ONE screen
  (ink vs white capsule); the Method note's primary action was a blush
  pill where rose is the DATA hue and ink keeps words (§3).
- **A correction to my own mid-pass claim, on the record:** 437
  `.font(.custom(_:size:))` calls without `relativeTo:` are **not**
  Dynamic Type bugs. `Font.custom(_:size:)` scales; `.custom(_:
  fixedSize:)` and `.system(size:)` do not. No sweep is warranted.
- **Tooling correction:** E8.1 recorded the sim argument as
  `content-size`; on this runtime it is `content_size` and the hyphen
  form errors out.
- **Verified: 1002/1002 app (+3) · 140/140 package** (run from
  `Packages/PlankFood`; the app scheme cannot host that target) ·
  12fps frame review of the Home arrival (ring traces, numeral counts,
  split lands, band height stable from first paint) · XXXL + SE
  captures for every redesigned surface.
- **Release risk: none identified.** Zero migrations, zero paywall
  diff, analytics additive only (two new VALUES of the existing
  `trigger` property = a new row in contract Q6, not a redefinition).

## §0.-15 — RELEASE PROOF (2026-08-12)

Not an era. The session after the ship: prove the distributed binary
IS the product eight eras built, push it to Apple, freeze how the
answer will be read. **Zero product code changed — deliberately.**

- **Re-measured first:** tree clean · `feat/app-v2` == `main` ==
  `origin/main` @ `8e396dd` · 14/14 migrations local=remote ·
  `jeni-chat` + `food-vision` ACTIVE · 1.2.0 (30) on app AND widget.
- **ARCHIVED → EXPORTED → UPLOADED.** Release archive (dev-signed,
  Organizer-visible under 2026-08-12) → distribution export signed by
  the team's **Cloud Managed Apple Distribution** identity through the
  already-signed-in Xcode account (no new local certs, nothing
  revoked) → **UPLOAD ACCEPTED 2026-08-12 00:12 PT** ("Upload
  succeeded", exit 0). A duplicate build number would have been
  rejected at validation → **build 30 did not previously exist in
  ASC.** UPLOAD ACCEPTED ≠ processing complete ≠ TestFlight
  available; ASC-side state is unverifiable from this machine (no ASC
  API key; browser extension disconnected) — founder confirms in ASC.
- **THE RELEASE BINARY, PROVEN CLEAN:** `strings` on the archived
  product: **0 `--uitest`, 0 `--debug`, 0 demo-backend**; production
  Supabase + PostHog hosts only. Source-level scanner: 0 ungated
  `ProcessInfo` doors across app + packages + widget. One
  `precondition` in the whole codebase and it lives in a comment;
  hygiene asserts compile out of Release. `FoodFlags` is vestigial
  (gates one settings row; the paywall variant reader has NO callers
  — no remote flag can touch the wall).
- **RELEASE SIM WALK (no QA doors exist, so the walk is real):**
  over-install boots to THE WALL fully resolved — live localized
  prices on all three tiers, billed-today, renews-date, restore,
  sign-in, X — inheriting the prior install's state; fresh install:
  launch is one continuous cream surface (no grey flash), onboarding
  s1 clean in both card variants, XXXL wraps with zero truncation.
  Landscape has shipped since the external-display era (~1.0.x,
  18 releases) — field-proven, left alone.
- **ANALYTICS TRUST, RE-AUDITED:** `bootstrapAnalytics` runs
  synchronously in `App.init` — setup → sinks → `register` completes
  before posthog-ios's notification-driven lifecycle captures can
  fire (no launch race). Both direct-SDK capture sites
  (`AppSideNutritionLookup`, `FoodCaptureDispatcher` calibration)
  inherit super-props; the widget imports no analytics. **Trust
  boundary: `environment='production'` ∧ `is_test_user` unset ∧
  `app_version='1.2.0 (30)'`+. `24_MEASUREMENT_CONTRACT.md` is the
  frozen contract** — 10 questions with cohort/N/D/min-n/falsifiers,
  binding reading discipline (no era decision before n≥100 payers or
  6 weeks; counts beside every percentage), and the accepted gaps
  (corrections carry no `entry_method`; UTC day boundaries).
- **THE 5.6 REJECTION FIX RIDES THIS BUILD:** `WallExitIntent` is
  total (an Action case for every state, no no-op exists), one offer
  per install then `.standDown`; `WallExitIntentTests` pin the table.
  Review notes should name it.
- **App Review audit:** purpose strings name all 11 read types +
  the write (E8.2's fix verified in the plist); privacy + terms URLs
  return 200; restore (wall + account) · delete account (5.1.1(v)) ·
  manage-subscription link present; prices render via
  `localizedPriceString` only. **The one real finding:
  `docs/app_store_metadata.md` is a v1.0.0 draft describing the
  RETIRED fitness product (plank form-check, three voices, 128-move
  library). If the LIVE listing still resembles it, App Review 2.3
  metadata-accuracy is a genuine risk for a build whose product is
  food + GLP-1 + medication.** Live listing is outside the repo —
  founder verifies in ASC.
- **REFUSED:** all product code changes · adding `entry_method` to
  the correction event post-upload (next build's one-liner) ·
  landscape "fixes" · any new mechanism.
- **Founder actions (complete list):** ① ASC: watch 1.2.0 (30)
  through processing → TestFlight ② on the TestFlight install, one
  PostHog Live event reads `environment: testflight` ③ the ~12-min
  device acceptance test (session report; supersedes prior walk
  lists) ④ read the LIVE App Store listing against the current
  product before submitting ⑤ create/attach 1.2.0 in ASC + submit
  with a review note naming the 5.6 fix.

## §0.-14 — THE SHIP (2026-08-11)

Not an era. The convergence session E8.2 called for: re-measure,
close, walk, polish, ship. **No new subsystem was built and no new
retention theory added — deliberately.** Four commits
(`bcb5944` · `d8572a3` · `f63715c` · `b9f62f5`).

- **RE-MEASURED, and the founder list shrank to almost nothing.**
  Three E8.2 "founder gates" were ALREADY CLOSED when checked:
  migration `20260811120000` is applied (14/14 local=remote, verified
  via `supabase migration list`) · `jeni-chat` deployed byte-identical
  · `food-vision` deployed same-day (differs by one comment word).
  Local `main` was 5 commits behind the branch (E8's reconciliation
  aged) — re-reconciled and PUSHED this session; `origin/main` and
  `origin/feat/app-v2` now carry the full line. Remaining founder
  work is exactly: archive/upload 1.2.0 (30) + two device checks.
- **ANALYTICS ENVIRONMENT, AUDITED against the StoreKit confusion.**
  `BuildChannel` classifies the DISTRIBUTION channel by receipt
  filename (`sandboxReceipt` → testflight), never the StoreKit
  purchase environment; no-receipt release = production
  (conservative). Stamped per-event in `track()` AND as super-props
  at bootstrap before any event; `is_test_user` feeds PostHog's
  native internal filter; the one direct-SDK capture site
  (nutrition lookup) inherits via super-props. Residue: confirm one
  TestFlight event reads `environment: testflight` after upload.
- **HEALTHKIT, CLOSED HONESTLY.** All 11 read types have a shipped
  ask (onboarding 8-type union one-for-one with its on-screen list;
  StepsService unions vitals+cycle+movement; per-surface connect rows
  via `statusForAuthorizationRequest`). **The purpose string still
  described the pre-E8.2 set** — the sentence Apple shows at consent
  omitted workouts/distance/active energy; fixed. Sim re-proof green
  (`MoveHealthProofUITests`: real store, write-then-silent-read).
  Device residue (Apple opacity, not laziness): third-party
  read-grant coverage shows only as data presence + watch
  attribution wording.
- **THE INSTRUMENTATION GAP: the close reported nothing.** The
  release's central hypothesis (evening close → intention → morning
  read-back) fired ZERO events. Now: `evening_close_shown
  {protein_met, has_intention}` · `evening_intention_set` ·
  `has_intention` on `morning_read_shown` carried by
  `Brief.carriesIntention` — TRUE only when the read-back sentence
  actually rendered (a displaced intention reports false; the pin
  proves the honest branch). All categorical; hygiene-registered.
- **THE WALK (26 states, all frame-read)**: onboarding → paywall →
  Home ×4 → letter → close ×3 → chooser (seeded + EMPTY) → describe
  → reading → plate sheet → book → again → desk → dose ×2 (self +
  b2b) → regimen → side effects → move ×2 → method note → clinic
  plan arrival → breathwork → becoming ×2 → settings → XXXL ×3.
  B2B held: "assigned by your care team. you record what you took."
- **WALK-CAUGHT, FIXED, RE-FILMED (7)**: the hero carousel now
  MEASURES its faces (322 was the third sheared constant; the dv
  footnote was the third victim — a hidden same-width copy takes the
  tallest natural height and the constant survives only as
  first-frame fallback) · the strip drops to ONE column at XXXL
  ("kcal 1,6… of 1,4…" truncated both numbers one size before the
  accessibility switch) · THE PAPER FADE at the tabRoot seam (Home +
  Becoming scrolled text raw into the status-bar clock) · the method
  note floats at optical centre like the letter (was top-anchored
  over a 45% void) · 18 letter heroes ended bare before a second
  sentence in the same typeset flow — run-ons, now sentences · ONE
  GRAM GRAMMAR ("76 g") across plate sheet/book/again/reading/share
  cards/brief (the strip/close/desk canon wins) · the describe
  door's evergreen chips stopped contradicting the product (two
  sugary coffee orders → protein-forward defaults).
- **REFUSED**: any new era/subsystem · paywall changes (empty diff
  again; `e5.firstPlate.enabled` still false) · pricing ·
  reclassifying analytics history · `EnergyLedger` dead-code removal
  (recorded product decision) · the medication-discontinuation note
  (signal doesn't exist).
- **Verified: 999/999 app (+1) · 140/140 package ·
  MoveHealthProof 1/1 · SayItWalk 4/4 solo · Release archive
  compiles unsigned.** Fix-verification frames for all seven fixes.
- **Founder actions (complete list)**: ① Xcode archive 1.2.0 (30) →
  upload → TestFlight ② on the TestFlight install: one event in
  PostHog reads `environment: testflight` ③ device walk: Move rows
  from a real watch (attribution wording) + the words path once on
  hardware. Then ship review.
- **Open debt (unchanged unless noted)**: letter QA door
  (`--uitest-letter`) respects the once-a-day stamp so re-films need
  `defaults delete com.bk.plankAI letter.presentedDayKey` (found
  this session) · intention accepted-state unfilmed (engine-pinned;
  now also production-measured via the two events) ·
  `--uitest-open-method` render gap · the bundled 84-lesson corpus ·
  pre-E8 analytics contamination is permanent.

## §0.-13 — APP v25 E8.2: THE BLOCKER, THE DOORS, THE CLOSE (2026-08-11)

Three commits (`b1ab184` · `8d92e02` · `d1c0f1d`). Discovery-first
session; the founder steered the close mid-session.

- **MOVE AGAINST REAL HEALTHKIT — the blocker hid a production defect.**
  `MovementService.requestAccess()` had ZERO callers: no shipped sheet
  ever asked for workouts or distance, so the strength count, workout
  minutes, distance, the Method's `losingWithoutResistanceWork` trigger
  and E1's walk-absorb were structurally nil on every real device. The
  ask now ships with every sheet (V8 onboarding list+request one-for-one
  · StepsService's union · Move's own connect row via
  `statusForAuthorizationRequest` for pre-E8.2 grants). **And "the
  simulator cannot supply HealthKit data" was half wrong** — the STORE
  is real: `--debug-hk-write-move` (idempotent, deletes own samples)
  seeds watch-shaped samples and `MoveHealthProofUITests` relaunches
  SILENT through the untouched read path: strength = 2 with yoga
  refused, 312 kcal as a SUM of split samples, 3.4 km, 24 min, all
  `from health`. **Walk-caught: the first real populated day
  CENTER-CLIPPED the sheet's own header** (JKSheetChrome is a plain
  VStack in a fixed detent; the harness only ever seeded steps) — the
  record scrolls under a pinned header now. Device residue is only:
  read-grant coverage for third-party data + watch source attribution.
- **HOME COHERENCE**: the "move" TILE opens the movement RECORD (E8.1
  built it with no persistent door while the tile opened the old
  workout flow under the same word); the workout beat is **"a short
  session"** and keeps doors (beat row + inside Move) so the library's
  retirement trigger stays fair · the method tile stopped advertising
  the retired 84-lesson manifest (`lessonTitle` DELETED) and stopped
  flash-dismissing on silent days — it resolves the engine BEFORE
  presenting and lands on `what jeni has told you` (new sheet
  `.methodTold`) · **the food beat self-heals**: E4's "one chokepoint"
  was a no-replay Combine subscription (first-plate flow, cross-device
  sync, and covered writes never marked the beat) —
  `autoCompleteFoodIfPlated` reconciles from the record at refresh.
- **THE EVENING CLOSE, REDESIGNED** (founder steer mid-session: pills
  too big, prose ugly, education valueless — a full evidence pass
  agreed). New anatomy, nothing else renders: eyebrow + "day 12"
  WITHOUT its denominator → ONE hero sentence (the protein close +
  door on gap nights; "protein landed. the day is on file." met;
  education tail DEAD) → the record as a LEDGER (plates · protein ·
  plan · weigh-in, right-aligned) → a DRAFTED one-tap tomorrow
  intention on gap nights ("tomorrow at breakfast: 30 g of protein,
  before anything else." — implementation intentions d≈0.33-0.65, the
  strongest lever this screen can hold) **which reads back in the
  morning brief** (`Context.morningIntention`; an intention that never
  resurfaces is theater) → an anchor only when tomorrow truly holds
  something (weekly dose day > adopted scale morning) → the feeling
  row one size down (kept: the morning read pays "proud" back) → the
  care asks → goodnight. **The trend row left the night** (evening
  weight framing carries a measured affective-lability risk in this
  cohort; mornings/weekly own it). Evidence file: the research
  synthesis lives in the d1c0f1d commit message + EveningCloseEngine
  headers (SMARTER null, Koh 2025 5/35, Forman 2017 evening lapses,
  Gollwitzer & Sheeran 2006, Snijders 2015 pre-sleep MPS, 2025 GLP-1
  advisory).
- **Dead code**: BrowseWorkoutsView · StepsPulseTile · TodayStepsSheet
  · BreathworkBentoTile · `--debug-steps-detail` deleted (zero refs).
  ExternalSessionView was recorded dead and is NOT (scene-delegate
  wired in Info.plist) — restored, kept.
- **Backend re-measured**: FOUR of E8.1's five "unapplied" migrations
  were already applied remotely; only `20260811120000` remains (the
  push is permission-gated → founder). Branch: 153 ahead of
  origin/main, 0 behind, still clean fast-forward.
- **Verified: 998/998 app** (+26 rewritten close pins, +2 read-back,
  +8 Move-adjacent across suites, zero regressions) ·
  MoveHealthProofUITests green · filmed: Move real-rows + XXXL, close
  gap/met/XXXL, Home coherence frame. My own new test fell into E8's
  recorded `contains("0 g")` trap on "3**0 g**" — word-bounded now.
- **New doors**: `--debug-hk-write-move` · `--uitest-open-move` ·
  `--uitest-move-offer-connect`.
- **Open debt**: intention accepted-state + morning cover unfilmed
  (once-per-day gates; engine-pinned instead) · the close's XXXL
  eyebrow wraps inelegantly (legible, not clipped) · E8.1's remaining
  debt otherwise unchanged.

## §0.-12 — APP v25 E8.1: THE LEGACY SURFACES (2026-08-11)

**`docs/app_v25/23_E8_1_THE_LEGACY_SURFACES.md` is the record.** Two
jobs: close E8's two named ship-blockers, then bring the three surfaces
still built for an older product into this one. Paywall untouched (empty
diff over all six paths); `e5.firstPlate.enabled` still defaults false.

- **THE FOOD SOURCE CONTRACT.** `CaptureSource` is DELETED; `EntryMethod`
  is the one vocabulary in the row, the event and the plate. Migration
  `20260811120000` widens the CHECK by definition-scan rather than by
  name (`food_logs` predates this folder, so a name-only drop would
  silently add a second contradictory constraint). **No shipped value was
  renamed** — `restaurant_estimate`/`quick_add` keep their spelling; four
  legacy values pass through untranslated because `text` LOOKS like
  `words` and mapping it would invent a fact. **Tested through the real
  chain**: 14 migrations applied clean and replayed clean 3× against a
  scratch Postgres 17 seeded from `scripts/schema.sql`; 12 vocabulary
  values accepted, 4 out-of-vocabulary refused, historical rows intact.
  The lie was costing more than analytics: **PlateDetailSheet told a user
  her TYPED plate was "read from your photo"**; the "dining out" title
  branch was dead (tested `.imOut`, which nothing writes); relog
  inherited a photo it deliberately did not keep; **and the chooser's
  again door fired NO `food_log_saved` at all, so every food funnel has
  been undercounting the cheapest door in the product.**
- **THE PROTEIN CLOSE, FILMED.** `--uitest-protein-gap N` works BACKWARDS
  from the floor (clears today, reads the same `TargetsService`, seeds
  `floor − N`), so the branch is exact for any weight or formula. All
  four filmed and inspected. **E8 listed two hour sources; there were
  three** — `HomeView.greeting` read the wall clock, so `--uitest-force-
  hour 10` produced "evening, maya." over a morning composer in one
  frame. `AppClock` is the one hour; five in-app sites converged,
  notifications deliberately not.
- **METHOD — FROM A CURRICULUM TO A JITAI.** 84 day-indexed lessons could
  only ever deliver lessons 1-2 on a base whose payer median is 2.0
  active days (measured: 464 lesson openers in 90d, 23.5% of them payers,
  1.66 days each, 39 lifetime completions). Architecture is
  evidence-led: **Koh et al 2025 (JMIR 27:e76625), 35 JITAI weight
  studies — educational information was used in 5 of them; prompts in 33
  and feedback in 24; 68.6% rule-based.** Nahum-Shani's six elements
  implemented literally. **13 notes**, each with WHO/WHEN/WHY/AFTER/QUIET
  and a required next action; the rejected domains are recorded with
  reasons. **`RepEngine` already held ten good interventions keyed to
  `canonicalDay`** — the Method already had the content, it was firing it
  on a calendar instead of on her life. **Silence is a return value and
  there is no fallback.** B2B: a clinician's note IS `MethodNote` with
  `authority = .careTeam`; override/add/suppress/expire/end rules built
  and tested; a clinic that authors nothing changes nothing; attribution
  is a word plus a drawn mark, never colour. One Jeni via `method_told` +
  `method_now` in the envelope (zero EF deploy). Browse = `what jeni has
  told you`, her own notes, never a shelf.
- **BREATHWORK SURVIVES**, for a specific reason: prolonged-exhale
  breathing lowered food craving and impulsivity in a trial in people
  with obesity (Complementary Medicine Research 2024;31(4):376). **The
  female-presenting photograph is deleted** — it made the surface
  women-only, made it read as a meditation app, and collided with the
  duration row and the CTA. The cortisol-holds-onto-fat chain is gone;
  the void is filled with her own record. The glossy heart retired.
- **MOVE.** `MovementService` has read four HealthKit signals all along
  and dropped every one before a screen (same shape as E7's
  micronutrients). Strength is the headline — the one judgement Move
  makes — because lean mass is 25-39% of the loss on these drugs and the
  guidance pairs protein with loading twice weekly. **Energy is measured
  or absent**; the only estimate comes from an activity she entered, is
  MET-based at conservative midpoints, rounded to 5 kcal, needs her
  weight, and is labelled. Never written back to HealthKit. **The
  workout library is NOT retired** and now has a measurable retirement
  trigger instead of a date. Fixed: `EnergyLedger.bmrFemale` hardcoded
  the female constant under "the cohort is exclusively women" — a unisex
  defect in ARITHMETIC (~166 kcal/day for a male user), and dead.
- **THE RESTING NUTRITION STRIP, REDESIGNED** (founder: *"functional but
  not aesthetic, modern, minimalistic"*). Diagnosis was typographic, and
  every value and denominator decision is unchanged: each cell rendered
  ONE uniform serif string, so `"420 of 2,300 mg"` read as a single
  enormous number and **sodium was the loudest thing on the screen** —
  an inversion of the product's own hierarchy. A cell is PARTS now
  (quantity in serif, unit and reference demoted), values right-align
  down one edge, hairlines between rows, and the two `dv` rows get full
  width because they carry more content. `faceHeight` 252 → 322.
- **Verified: 997/997 app (+55) · 140/140 package (+7)**, zero
  regressions. **Walk-caught, and tests could not have**: the third hour
  source · the breathwork photograph and the void behind it · Move with
  no horizontal padding · Move rendering "3 of 2" (denominator law) · a
  hardcoded "two" contradicting a count of three · the Method cover
  racing the snapshot load · once-ever notes filmable exactly once per
  simulator · Move's caption truncating at XXXL · the strip shearing its
  third row twice. **And a check I nearly claimed without doing**: the
  first XXXL pass used `simctl ui content-size`; the option is
  `content_size`, the command failed silently, and those frames were at
  default size.
- **Open debt**: Move's real HealthKit rows are unverified (the simulator
  supplies none) · the medication-discontinuation note is the
  highest-value content in the domain and is unwritten because the signal
  does not exist · `--uitest-open-method` presents the cover but the note
  does not render while `--debug-method-note` does · `EnergyLedger
  .spentKcal`/`isLighterDay` are dead · the old 84-lesson corpus is
  unreachable but still bundled · pre-E8 analytics can never be
  de-contaminated.

## §0.-11 — APP v25 E8: THE MERGE (2026-08-11) — CURRENT

**`docs/app_v25/22_E8_MERGE_AND_LEDGER.md` is the reconstructed state,
the release ledger and the record.** Convergence, not a feature era.
Paywall untouched (empty diff over all six paywall/payment/entitlement
paths); `e5.firstPlate.enabled` still defaults false.

- **THE BRANCH STATE, MEASURED.** The "475 commits" carried in every
  prior doc was wrong, and so was the ref that produced it: local `main`
  was a **stale pointer 343 commits behind `origin/main`**. Against
  `origin/main` the real figure is **149 commits, 427 files, and a clean
  FAST-FORWARD** — conflicts are structurally impossible. Local `main`
  is reconciled; the push is a founder gate.
- **TWO FOUNDER GATES WERE ALREADY CLOSED.** E3-E7 each recorded "deploy
  jeni-chat and food-vision, the prompts still say gen-z women in
  production". Downloaded the deployed bundles: `jeni-chat` is
  **byte-identical** to local; `food-vision` differs by **one code
  comment**. Real when E3 wrote it, stale by E4, never re-measured.
- **TWO MIGRATIONS WERE NEVER IN THE GATE LIST.** Four are unapplied,
  not two: `20260804090000` (p6) and `20260811090000` (care RPCs) join
  v24's and E1's. Order is lexicographic = dependency order.
- **WHY PRODUCTION COULD NOT ANSWER ANYTHING** (E6 called it a fact of
  nature; it was three defects): **TestFlight compiles as RELEASE**, so
  every internal tester sat inside every production funnel wearing a
  customer's clothes — `BuildChannel` now resolves debug/testflight/
  production at runtime from the receipt · **E7's falsification
  condition was unmeasurable** because one shared decoder stamps
  `source: photo` for a photograph, a nutrition label AND a typed
  sentence, so `EntryMethod` now carries the truth on `food_log_saved` ·
  **the words path fired nothing at all**, so every scan funnel excluded
  the door E7 built. History cannot be reclassified and no attempt was
  made.
- **HOME: PROTEIN LEADS.** The carousel opened on calories and reached
  protein on a swipe — the product's own §9 law, still inverted on its
  most-seen surface. Now a pure tested function; calories lead only when
  no floor is on file. E7 deferred this citing deep-links into the
  carousel; **nothing deep-links into it** (checked). Founder steers
  taken: the floor bar became a **ring**, a **resting nutrition strip**
  (kcal + macros + fiber/sugar/sodium) shows without paging, **steps
  always stand** in the to-do list as an offered row (excluded from
  `actionableBeats`, so it can never become debt), and denominators
  appear **only where the product genuinely has one** — kcal is hers,
  fiber/sodium quote the FDA Daily Value marked `dv`, carbs/fat get
  none, and **sugar deliberately gets none** because the FDA limit is on
  *added* sugars while this figure is *total*.
- **THE EVENING CLOSE, TWICE.** First pass: "that's the day, maya." /
  "tomorrow: a balanced day." became her record + tomorrow's reason via
  `EveningCloseEngine`, and every tappable word became a rose chip.
  Second pass, after an expert review the founder asked for: the screen
  **made seven asks and paid out once, always on day N+1**, on a base
  whose median payer lives 2.0 days. **THE PROTEIN CLOSE** now takes the
  second slot when a gap is open ("there is still time tonight. 18 g
  would close it…") with a door into E7's describe path — the only line
  on the screen that can change TODAY, and the clearest case in the
  product for a number a GLP-1 user cannot feel. `sitAck` moved off
  "tomorrow". Recommended-but-NOT-done (settled decisions, founder's
  call): cutting the day-number hero and the nightly trend row.
- **UNISEX**: the first 48 hours are **already clean** (swept: only
  comments, demo seeds, and a legitimate `case "female"` physiology
  branch). The EF prompts are fixed AND deployed. Fixed here: the
  `voicePlaybook` authoring rules whose north star was "the smartest
  **girlfriend** you've ever had" — every future lesson inherited it;
  lesson content byte-identical, verified. The 64/84 corpus figure
  conflates **22** reader-assumed-female (must fix) · **39**
  third-person (later) · **3** study populations (**preserve**).
- **Verified**: **942/942 app (+52) · 133/133 package (+8)**, zero
  regressions. Walked in four states. **Walk-caught**: the protein face
  left ~120pt of void on a new payer the moment it led, and the
  nutrition strip sheared its second row. **My own tests lied twice** —
  the exact E7 §5.4 trap, a `contains("0 g")` firing on "4**0 g**".
- **Open debt**: `food_logs.source` still lies in the synced record
  (analytics is correct; the record needs a CHECK check + migration) ·
  pre-E8 analytics can never be de-contaminated · two hour sources
  (`isEvening` vs `hourOfDay`) · the Method corpus' 22 lessons · the
  protein-close gap branches are test-pinned but unfilmed (no QA seed
  makes an under-floor day).

## §0.-10 — APP v25 E6: THE DESK (2026-08-11)

**`docs/app_v25/19_E6_DECISION_AND_RECORD.md` is both the why and the
record.** Follows the founder steer of the same date: E5 ships OFF (the
hard-paywall funnel owns production), and the redesign continues.

- **THE DATA STOPPED.** With the paywall staying, the addressable
  population is payers: ~2/day, median 2.0 active days. An attempt to
  let day-0 actions pick the era FAILED and the failure is recorded:
  breathwork is a scripted step of `PostPurchaseFlowView`, not a chosen
  action, and 105 of 160 `main_tab_appeared` users never purchased on a
  hard-gated app (internal/TestFlight builds). **Production data cannot
  currently discriminate between in-app features.** The binding
  constraint is quality.
- **THREE THINGS I EXPECTED AND FOUND WRONG** (all caught before
  building): the food reading is NOT a spreadsheet (I had screenshotted
  `--uitest-plate-detail`, the Home sheet, not `SnapResultView`); the
  three food entrances ALREADY converge on one reading in
  `PhotoCaptureView`; the describe header's ♥ is a SANCTIONED brand
  mark per `JKMarks`, not a violation.
- **THE DESK**: the chat's resting line changes from a claim to a
  proof, same real estate. `"your coach, day to day."` →
  `"4 plates and 123 g of protein, on file."` `JeniDeskAwareness` is a
  pure engine over the SAME `TodayStateService.snapshot` the starters
  read — nothing on file falls back to the claim (never invented
  proof), a plate with no macro detail never renders "0 g", a gap is
  stated warmly and pinned against ten reprimand words across 2..60
  days, today's record outranks the gap, and the E4 G9 care gate
  survives. No new buttons, no card, nothing dumped into a message.
- **E5 RECONFIGURED**: `e5.firstPlate.enabled`, default **false** — an
  explicit ENABLE, not a `disabled` kill switch, because a disabled-key
  fails OPEN (a wiped UserDefaults or a restored backup would ship the
  experiment). Production order unchanged: onboarding → hard paywall →
  purchase/entitlement → jeni. Both states verified in the sim.
- **Verified**: **869/869 app + 125/125 package**, zero regressions;
  E5 walker 4/4. New doors: `--uitest-wipe-chat` (the desk's resting
  state was unfilmable — the QA account carries a conversation).
- **Below the bar, observed and NOT fixed** (19_E6 §6): the steps
  detail's orange gradient ring (off-palette) · the Method reader's
  female-only photography and its `"she's being good today"` lesson
  line, plus breathwork's imagery (unisex debt inside an 84-lesson
  corpus and an asset library — the Method's fate should decide the
  copy pass) · the reading leads with kcal where the product's law says
  protein leads · the desk's dead space and its generic starter
  fallback.

## §0.-9 — APP v25 E5: THE FIRST PLATE (2026-08-11) — BUILT, SHIPS OFF

**`docs/app_v25/17_E5_DECISION.md` is why this era and not the
roadmap's next number; `18_E5_EVIDENCE.md` is the loop's record.**
Jeni does one real thing for a person BEFORE she asks for money. No
migration, no EF deploy, no price change; RC stays 1.2.0 (30).

- **THE FINDING that reframes four eras**: every prior era asked why
  people don't come back. This one asked who ever arrives. Measured
  per app version (`main_tab_appeared` did not exist before 1.1.3, so
  a version-blind cut had to be discarded): **1.1.6 — 236 onboarded,
  18 saw the main app (7.6%), 20 purchased. 1.1.5 — 200 / 21 (10.5%)
  / 18. 1.1.4 — 103 / 6 (5.8%) / 6.** Essentially everyone who gets
  in is a purchaser. `paywall_view` 2,436 users → `purchase_completed`
  172 = 7.1%: **the wall is the most-seen surface Jeni has.** Payers
  who paid ≥30d ago (n=151): median **2.0** active days, 12% still
  active at day 28. E1-E4's adaptive intelligence currently serves
  ~20 people per release. `AppPhase.swift:84` is the gate in code;
  the master plan already banned "paywalling the record"
  (00_THE_SYSTEM §12) and already cited a competitor's paywalled log
  as the trust vacuum's opening (r1 §9). The product did the
  forbidden thing.
- **B1 THE PROOF PHASE**: `AppPhase.proof` between `.onboarding` and
  `.wall`, mounting the REAL `CaptureFlowView` (5.1.2(i) consent
  included), the REAL vision EF, the REAL `FoodLogPersister` —
  ONE plate, then the wall. The plate persists under her real user
  id, so paying later opens a record that already has it. `derive`
  stays pure; the table pins the closed exclusion set (resolved ·
  ever-entitled · legacy footprint · entitled · flag off · boot set ·
  auth-transition hold).
- **B2 WHAT IT MEANS**: `FirstPlateReadingEngine` (pure, 12-case
  honesty table) — protein leads, kcal only when protein cannot, NO
  floor without a weight on file, coarse words never percentages, no
  verdict, no em-dash. The floor is `TargetsService.proteinTargetG`,
  the same formula five surfaces render.
- **B3 THE WALL, EARNED**: `WallReason.afterProof` follows
  ExpiredWelcomeView's two-state precedent, so **PaywallView is not
  touched**. Price, tiers, bands, downsell ladder, exit-intent chain
  and stand-down all unchanged. It opens with her plate's photograph
  and three receipt rows.
- **B4 THE SCAN CHOOSER, REBUILT** (the founder's direct ask): nested
  grey tiles gone, four geometries down to two, bottom-anchored in
  the thumb zone, ink-over-blur so the page behind stays legible,
  meal door FIRST. **The doors are made of her record** — the meal
  door wears her last photographed plate, the again door names the
  dish. The body door stays drawn (L4).
- **B5 FOUND BY LOOKING**: the food-AI consent sheet named
  **Anthropic** as a recipient of her photo when no edge function or
  package references it (food-vision is OpenAI/gpt-5) — corrected;
  `--uitest-force-first-plate` overrode the outcome GETTER so the
  walker's decline leg passed while sitting on the invite — rewired
  and the assertion strengthened; an empty capture now gets ONE retry
  (a dropped network looks identical to a decline on a first run);
  `--uitest-wipe-food` now suppresses the cloud pull too (E4-named
  debt, half paid down).
- **Verified**: **857/857 app + 125/125 package** (+27, zero
  regressions); `FirstPlateWalkUITests` 4/4 solo. Doors:
  `--uitest-force-first-plate` · `--uitest-first-plate-done` ·
  `--uitest-first-plate-noweight` · `--uitest-wipe-food`.
- **Founder gates**: standing set + **the business call** — this
  changes the ORDER of the ask, not the model, and ships behind
  `FirstPlateState.isEnabled` (`e5.firstPlate.disabled` restores the
  exact pre-E5 gate in one line) · device walk on real hardware ·
  post-merge read of `first_plate_*` against the 5.8-10.5% band.
- **Retracted in-document**: 17_E5 §5.4's first draft claimed the
  program-intro screen promises movement and the method where the
  product delivers neither. Checked in the sim: **both render as
  Today beats.** An audit ledger describes intent, not the running
  product. Corrected in place rather than quietly edited.
- **Named debt**: the ~128 `woman-doing-X` workout animations
  (reached: `workout_start` 203 users/90d) are 100% female-presenting
  — reported, NOT fixed, because the fix is roadmap E3's library kill
  · QA seeders pin `gender = female` for physiology determinism, so
  the team never sees a male/unspecified user in a frame · the
  chooser's empty *again* row is code-verified but unfilmed.

## §0.-8 — APP v25 E4: DAY TWO (2026-08-11)

**`docs/app_v25/14_E4_DECISION.md` is why this era (the founder's
day-one-utility brief + fresh PostHog + two full code maps);
`15_E4_DAY_TWO.md` the law; `16_E4_EVIDENCE.md` the loop's record.**
Everything a person gives Jeni on day N returns as visible
understanding on day N+1 — food first, no engagement tricks. No
migration; RC stays 1.2.0 (30).

- **THE EVIDENCE**: day-0 food loggers return later at **76.2% vs
  16.6%** for everyone else (42 vs 2,266 onboarded); the scan funnel
  completes 100% once started but only 3.4% ever start; 46% of food
  loggers logged exactly ONE day; a day-1 user who logged 2 meals +
  a weight woke up to exactly one acknowledgment (a berry ring on a
  calendar cell). Two Explore maps confirmed: corrections
  evaporated, the finished relog rail was dead code, the vision EF
  got zero user context, the anchor ladder permanently starved
  winback + milestone_3. **The gap map's "THE BOOK has no door" was
  wrong** — the door exists; the QA arg was tab-gated.
- **B1 THE MORNING READ**: `DailyBriefEngine` gains the typed
  `YesterdayReceipt` (plates·protein·kcal·weigh-in·kept·feeling;
  provenance-first: receipt sums from plate 1, promotion keeps its
  ≥2 gate, onboarding seed never counts, suppression strips numbers,
  absence builds nothing) + the week-one DAY TWO clause that reads
  yesterday back and self-retires. L1 closed (kept-promise reads
  yesterday), L2 ("proud" read back after four eras write-only), L5
  (first weigh-in → "your line is forming"). De-dup law: prose and
  ledger never say the same numbers twice (frame-caught). Every
  clause carries a stable id; `morning_read_shown{clause,
  has_receipt}` at auto-present.
- **B2 THE PLATE'S MEMORY**: fix-with-words sentences PERSIST
  (entry JSONL + payload jsonb, zero migration, survives reinstall);
  `PlatePriors` (pure, 12 pins) — corrected dishes only, exact
  normalized-title match, latest wins, uniform revertible scale,
  ±15% agreement band, 3× absurdity refusal, PHOTO ONLY (barcode/
  label = printed truth; .text carries the corrections themselves);
  the reading shows "your numbers · you fixed this dish before" +
  one-tap "use the scan"; a new correction dissolves the prior.
  **AGAIN ships**: the chooser's quiet third door → RecentMealsSheet
  (out of its debug harness), ≤3 taps cold to a kept log. The
  cuisine-profile threading bug dies (onboarding's answer finally
  reaches photo/label/refine).
- **B3 ONE CHOKEPOINT + ROUTES**: any plate today marks the food
  beat (camera, book, again rail, jeni's log_food_text — J1);
  becoming consumes its own routes (.trend/.weeklyRead were
  swallowed by Today); `jenifit://plates` opens THE BOOK and the
  evening push lands on it; the past-day recap shows the WHOLE day
  (photos + macros + "weighed in · closed proud").
- **B4 THE BRAIN UNSTARVED**: ladder 7→3 rungs (5 stamped ids had
  saturated the 5/wk budget FOREVER); the morning rung carries
  yesterday's record ("2 plates and 76g protein, on file") via a
  state-guarded rebuild; vetoed milestones retry 2 days;
  lapse_support's dead branch fixed (week 1 = lapse support, week
  2+ = evening review).
- **B5 DESIGN (as touched)**: the letter's receipt row; becoming's
  new-user 13-row "not enough to read yet" wall compresses to one
  sentence + a "what's coming" disclosure; the desk subtitle is
  care-gated ("your coach, day to day" for consumers — G9); MeAgain
  studied (62 frames): imported repeat-capture ubiquity, next-thing-
  as-fact, the reveal moment; refused streaks/mascot/PK-curve/
  sliders.
- **Verified**: **830/830 app + 125/125 package** (+21/+12, zero
  regressions); the DAY-TWO LOOP walked by machine (`testDayTwoLoop`
  green): again sheet → one tap → the food beat marks WITHOUT the
  camera → the ring re-counts → the book opens through its route.
  The day-2 letter filmed ("your file started. 5 plates yesterday…"),
  frame-caught de-dup fixed and pinned. 4 frame-caught fixes.
- **Doors**: `--uitest-open-again-sheet` · `--uitest-seed-week`
  (launch door now) · `--uitest-open-food-journal` (any tab) ·
  `--uitest-seed-day N` pairs with all of them.
- **Founder gates** (16_E4 §4): standing E3 set unchanged (jeni-chat
  + food-vision deploys, migrations, rotation, archive, **the
  merge**) · E4.1 = the ONE clarifying question bundled INTO the
  food-vision deploy · device walk (relog on hardware, morning push
  on a lock screen, correction → next-day prior) · post-release
  reads of morning_read_shown/has_receipt · food_relog_used ·
  food_prior_applied.
- **Named debt**: QA cloud pollution (the deterministic QA account
  accumulates seeds; survives simctl erase via hydrate — needs a
  wipe door; becoming's compressed zero state is code-verified,
  film-blocked by it) · priors are exact-title only (deliberate) ·
  beyond-XXXL app-wide debt unchanged.

## §0.-7 — APP v25 E3: ONE JENI (2026-08-11)

**`docs/app_v25/11_E3_DECISION.md` is why this era and not the
roadmap's movement era; `12_E3_ONE_JENI.md` is the law;
`13_E3_EVIDENCE.md` the loop's record + the founder-gate audit.**
The coach can read her own record, remember what she is told, and
change the plan in words — through the same chokepoints and the same
authority law the surfaces use. No migration; RC stays 1.2.0 (30).

- **THE DECISION**: PostHog re-queried — **82% of everyone who
  finishes onboarding has exactly ONE active day; 28 of 2,237 have
  ever reached a second week.** Every mechanic five eras shipped
  needs a week or three cycles to speak. Movement (roadmap E3) is a
  week-3 feature for a population that never reaches week 2, so it
  moves behind. Bloom (arXiv 2510.05449, RCT N=54) is the primary
  evidence: the LLM arm spent **5.6× longer in the app**, its three
  mechanisms were tool access to the user's own data, writing the
  structured plan, and memory — and its design lesson is that
  participants named *plans and notifications, not chat*. Recorded
  as promising, not proven (no outcome difference at 4 weeks).
- **B0 THE VOICE, CORRECTED**: the 08-10 unisex sweep moved 30 client
  files and missed the two SERVER prompts that generate most of
  Jeni's language — `jeni-chat` ("a program **for women**") and
  `food-vision` ("serving **gen-z women**", twice, the second over
  its recognition priors). Both rewritten; the chat prompt gains a
  WHO YOU ARE TALKING TO block; the food cohort list broadens past
  matcha-and-crumbl. Plus the **AI-identity disclosure** the CA/IL/TX
  statutes require and §8 promised: *"jeni is a digital coach. not a
  person, not your clinician."* on the desk and in settings,
  replacing a line that carried a banned em-dash and disclosed
  nothing. `Lazy Girl Routine` → `Bare Minimum Routine`.
- **B1 THE TOOL LOOP**: `ChatSession` ran a non-confirming tool and
  then STOPPED, so a read's result could never reach the model —
  which is why all seven shipped tools ACT. Reads now execute,
  continue the turn, and stream into the SAME bubble (≤2 rounds).
  The wire carries `tool_results` plural WITH real arguments. **The
  tool surface moved to the client** (`JeniToolCatalog`), allowlisted
  server-side: the last `jeni-chat` deploy a tool addition ever needs.
- **B2 JENI READS** (`JeniReadTools`): food day/week · weight trend ·
  dose history + cycle · symptoms · patterns · activity · program
  facts + authority. Every read renders from the SAME engine the
  surfaces render from (E2's `WeightWeekReadEngine`, v24's pattern
  engine assembled as the Becoming tile assembles it, E1's
  `ProgramFactStore`), so chat and UI cannot disagree. **Honest
  emptiness**: `have:false` + a reason; an unlogged day is "not
  logged", never zero. Suppression and the never-brand line hold.
- **B3 JENI REMEMBERS** (`JeniMemoryRecord` + `MemoryGuard` +
  `JeniMemoryStore`): the compounding half — what the person SAID
  about themselves. Written ONLY through a card showing the exact
  words; `MemoryGuard` refuses doses/brands/diagnoses/symptoms/body
  judgements/ED language at the door; near-duplicates supersede;
  6 per topic; **`what jeni remembers` in settings** with `forget`
  per row. A memory a person cannot audit is a profile.
- **B4 THE PLAN, NEGOTIABLE IN WORDS** (`JeniActTools`):
  `propose_program_fact` through `ProgramFactStore` — chat writes
  `preferred` and nothing else; **a prescribed head REFUSES**, routes
  to the correction door, and leaves no row underneath it; the
  STORED (clamped) value is what gets acknowledged. Closed set:
  stepGoal · weighCadence · loggingMode · notificationPosture ·
  walkTiming. `proteinAdjust`/`movesAdjust` excluded by law.
  `log_food_text` opens the real describe path (jeni never authors a
  plate); `open_dose_sheet` routes and never marks.
- **B5 THE ENVELOPE** (zero-deploy value): `remembered{}` ·
  `program_facts[]` with authority (E1 built the ladder and chat
  could not see it) · `food_week{}`.
- **Verified**: **809/809** (+26, zero regressions) · **THE
  COMPOUNDING LOOP FILMED**: "can you make my step goal 6000?" →
  card → yes → relaunch → Today composes "6,000 steps · 2,100 steps
  left". And the frame that matters most: "am i actually losing?" →
  "reading your trend" → *"not enough weigh-ins to call a direction
  yet"* — the provenance law surviving into conversation. 6
  frame-caught fixes. XXXL floor on the new page.
- **Doors**: `--uitest-chat-read <food-day|food-week|weight|dose|
  program|activity>` · `--uitest-chat-propose <steps|remember>` ·
  `--uitest-chat-auto-confirm` · `--debug-jeni-memory` ·
  `--uitest-seed-memory`.
- **Founder gates** (13_E3 §4): **deploy `jeni-chat`** (unisex +
  identity + reads + client tools) · **deploy `food-vision`** (its
  prompt still says "gen-z women" in production until then) · the
  standing v24/E1 migrations, key rotation, 1.2.0 (30) archive, and
  **the `feat/app-v2` → `main` merge** · device walk · post-release
  read of `jeni_read_tool_called` + its `had_data` rate.

## §0.-6 — APP v25 E2: THE MEDICATED YEAR (2026-08-10)

**`docs/app_v25/08_E2_BRIEF.md` is the mandate; `09_E2_MEDICATED_
YEAR.md` the architecture (with 10 recon corrections to the brief);
`10_E2_EVIDENCE.md` the loop's record + the founder-gate audit.**
The medication platform became CONTEXT for the one adaptive system;
RC bumped to 1.2.0 (30); the era ships WITH the feat/app-v2→main
release or its success section is unmeasurable.

- **B1 THE KILL/REDIRECT TRIGGER**: cohort identity as categorical
  PostHog person properties (`glp1_cohort`/`medicated`/`med_route`/
  `med_cadence`/`med_authority`, fingerprint-deduped $set via
  `CohortIdentity`); the analytics-dark v24 medication subsystem
  wired at its chokepoints (dose_marked, dose_reminder_action,
  regimen_changed incl. care arrival, side_effect_logged,
  walk_action_shown/hit, healthkit_requested at onboarding);
  `AnalyticsHygiene` = the allowlist law as a DEBUG-asserted
  mechanism. Post-release, "what share of actives is medicated" is
  finally readable — the E2.1 go/no-go number.
- **B2 THE CYCLE**: `MedicationScheduleEngine.CyclePosition` —
  event-anchored to her last actual injection (takenDayKey; late
  takes anchor the real cycle), schedule fallback on the seam day,
  day ALWAYS 1..7 (an unresolved past slot returns nil — the open
  slot outranks the rhythm), bands landing/steady/waning, nil for
  daily/as-needed/non-med by construction.
- **B3 LABEL FACTS**: `MedicationLabelFacts` on the catalog — 7
  products verified VERBATIM against 2025/26 FDA PIs with per-label
  frames (wegovy/trulicity = next-dose-distance 48h/72h; ozempic
  120h window; mounjaro/zepbound 96h; saxenda/rybelsus dailySkip;
  interruption rules exist ONLY on wegovy/saxenda — pinned
  negatives), compounded = nil by construction → the no-label
  truth; `lateFactLines` = rule + record-gated interruption (≥2
  consecutive unresolved) + attribution + "your prescriber decides
  what's right for you." always last. Never a computed catch-up.
- **B4 THE LATE DOOR**: openLateSlot finally wired — the dose row
  returns mid-cycle as first support ("friday's dose is still
  open"), DoseSheet's late face carries the label card, and tap /
  quick-mark / evening-"yes" all resolve THE SLOT through one
  chokepoint derivation (`TodayModules.currentDoseSlotKey`).
- **B5 SYMPTOMS**: vocabulary +5 (food_noise · hair_shedding ·
  menstrual_change · feeling_cold · low_mood); mood leads with 988/
  findahelpline support BEFORE recording (never blocked); the
  logger reaches the dose sheet's taken face ("how it's sitting");
  ObservationStore custom-id upsert finally carries severity +
  syncs; expanded chips scroll into view.
- **B6 THE SIGNATURE**: `foodNoiseReturn` — "food noise has come
  back around day 5 in each of your last three cycles." Trailing
  ≥3-cycle run, ≤2-day onset cluster, onset ≥ day 3, silence over
  weak claims. The honest substitute for the category's PK curve.
- **B7 WEIGHT INTELLIGENCE**: `WeightWeekReadEngine` — time-aware
  EMA (τ 9.5d, no fabricated interpolation), gap-bounded ±1.6%
  innovation clamp, lb/kg unit-error rejection, ±0.25%BM/wk band
  (0.2kg floor), sufficiency insufficient→provisional→established→
  stale (bands withheld, never extrapolated). Suppression honored;
  the Becoming weight tile's suppression gap fixed; weighSoften's
  dead plumbing noted in 09_E2.
- **B8 THE READ GROWS UP**: composer gains doseWeek/cycleDay/
  eraChangedRecently/weight — the weekly slot's own story leads
  observations (on-day/late/skipped/open/missed, anti-shame; the
  exp≥2 gate that silenced every weekly injector corrected), the
  weight band joins the signals ("−1.2 lb · the weight trend · an
  early read"), teachings gain waning-cycle → era-change → plateau
  under offer-first precedence. Grammar caps unchanged.
- **B9 TODAY**: "your dose day. the week starts here"; late-cycle
  meal lead reason ("appetite often stirs about now. protein holds
  the line"); evening ask scoped to open-dose evenings (pure-pinned;
  pre-regimen window preserved); Becoming med tile never reads "not
  enough to read yet" with an active regimen.
- **B10 ONE JENI**: medication{} gains cycle_day/len/basis +
  open_dose_slot; envelope gains week{} (live WeeklyReadRecord
  compact); EF prompt gains the cycle rule (shape-not-prediction,
  schedule-basis hedging, label routing) + week reflection —
  founder deploys. VisitPacket's symptom section reads the real
  v24 timeline (underreported set + food noise reach the visit).
- **B11 FOOD DEFECT + SWEEP**: `SnapRefineMerge` — fix-with-words
  applied deterministically (note-token mention detection;
  unmentioned drift DISCARDED — the SnappyMeal ablation defense;
  hallucinated additions dropped; 1:1 named renames in place;
  nothing silently deleted; global notes wholesale); fixPrompt
  echo/omit contract + fiber anchoring; FoodCorrectionSheet +
  PortionStepper + dead mount swept; decision docs annotated
  (CaptureFlowView is LIVE — the recorded mechanism was wrong).
- **Verified**: 783/783 app + 113/113 package (+74/+7, zero
  regressions); films frame-inspected; 5 frame-caught fixes; XXXL
  standing floors hold (a11y-sizes overflow = pre-existing named
  debt). NO new migration; zero PlankSync changes.
- **Doors**: `--uitest-seed-medication late` ·
  `--uitest-open-side-effects` · `--uitest-expand-mood` (+ the
  dose-sheet door now waits for identity and opens the late face
  when one is open).
- **Founder gates** (10_E2 §5): v24+E1 migrations in order ·
  jeni-chat deploy · ElevenLabs rotation · archive/TestFlight
  1.2.0 (30) · **merge feat/app-v2 → main** · device walk + voice
  pass on the new lines · post-release PostHog verification and the
  medicated-share read (the E2.1 kill/redirect number).

## §0.-5 — APP v25 E1: THE SPINE (2026-08-10)

**`docs/app_v25/00_THE_SYSTEM.md` is the era's law (the master
product plan; 05_E1_SPINE.md the build architecture; 06_E1_EVIDENCE
.md the loop's record).** The adaptive spine: ONE program with
memory, authority, and consent.

- **PROGRAM MEMORY**: `ProgramFactRecord` (synced `program_facts`) —
  append-only chains per (kind, authority); 8 closed kinds; render
  precedence prescribed › preferred › recommended › defaulted; a
  recommendation exists only ACCEPTED; iOS never authors prescribed
  (chokepoint + RLS); ending a prescription RESUMES her preference
  (no-silent-overwrite, structural). `ProgramFactStore` = the one
  writer (same-day coalesce, supersede-never-mutate, resolved-head
  write-through to the v4 knobs, once-ever bootstrap w/ cross-device
  guard). TargetsService steps read facts-first.
- **THE WEEKLY READ**: the v4 re-signing EVOLVED (ReSigningView +
  WeeklyReview stand): anchor ladder preference › dose-day-morning-
  after › enrollment (zero GLP-1 leakage — daily/no-med users keep
  the v4 rhythm); WeeklyReadComposer (one-clause hero, ≤3 signals vs
  her own trailing avg, ≤2 floor-gated anti-shame observations, one
  teaching line); WeeklyReadOffers (v4 rules LEAD by delegation +
  step-goal recalc + sparse-week logging lighten; 14-day decline
  cooldowns); consent lands in program memory; `WeeklyReadRecord`
  (synced `weekly_reads`, deterministic per-window ids).
- **ADAPTIVE MOVEMENT**: AdaptiveStepsEngine (60th percentile of her
  own recorded days, ≥5 or nil, ±15%/recalc, relief structural, ONE
  clamp law 2,500-8,000·round-50) → THE WALKING ACTION composes as a
  capped support ("6,200 steps · 2,100 steps left · about 20
  minutes") ONLY when a consented goal fact exists; post-meal window
  lifts the afternoon gate; HealthKit workouts ≥10 min absorb it;
  auto-complete fixed to the RESOLVED goal. StepsService grew a
  28-day daily cache.
- **THE NOTIFICATION BRAIN**: a VETO arbiter (never a scheduler) —
  hard ≤5/wk budget (quieter fact halves it; same-id replaces free),
  medication exempt from budget/silence/holdouts (the v24 carve-out
  now explicit law), the read priority-exempt-but-logged, 6-ignore
  auto-silence w/ engagement reset, stable FNV 10% MRT holdouts;
  wired at the anchor ladder, winback, milestones, and the knock
  (now dose-anchored + read-registered).
- **TELEMETRY**: the spine's lifecycle events (weekly_read_shown/
  decision, program_fact_changed, notif_candidate/delivered/
  silenced, dose/walk families registered) — categorical only.
- **Verified**: **709/709 units** (587 → +122, zero regressions at
  every gate); the critical loop FILMED end-to-end (read → consent →
  fact → relaunch → Today changed → survives again); adversarial
  battery (no-data, sparse, decline, overrides, non-med, daily-med,
  authority, collisions, XXXL) — 06_E1_EVIDENCE §2. Six frame-caught
  fixes.
- **Doors**: `--uitest-force-read-day` · `--uitest-walk-read` ·
  `--uitest-walk-read-decline` · `--uitest-read-prefer-steps` ·
  `--uitest-force-hour N` · `--uitest-steps-today N`.
- **Founder gates**: apply `20260810090000_v25_e1_program_spine.sql`
  (stacks after the open v24 migration) · device walk (read in hand,
  lock-screen knock, timezone) · voice pass on the 12 teaching lines
  + offer copy.
- **Named debt**: read XCUI leg · v4 JSONL journey-record retirement
  · delivered-but-unread ignore capture (needs a service extension)
  · sim-keychain QA determinism (erase for true-fresh walks).

## §0.-4 — APP v24: THE REGIMEN (2026-08-09)

**`docs/app_v24/00_REGIMEN.md` is the era's law; `01_EVIDENCE.md`
is THE LOOP's record.** The founder's brief: study MeAgain +
Shotsy deeply (72 frames read end-to-end), copy nothing, and
rebuild the medication experience so it belongs inside Jeni —
Today. Jeni. Becoming. — quietly, never dominating. Shipped in one
pass (7c2b605 → the loop commits):

- **THE PLATFORM** (never overwrite history): MedicationCatalog
  (9 products, label-strength ladders as picker FACTS; compounded
  first-class; a future medication = one entry) →
  `RegimenPlanRecord` evolved additively into APPEND-ONLY VERSION
  CHAINS (`applySelfRegimen` chokepoint: supersede-never-mutate,
  same-day coalescing, reminder toggles never version, schedule
  changes inherit the titration clock, care-team guard) →
  `DoseEventRecord` (new synced model; deterministic per-slot ids
  so checklist / sheet / evening / notification actions CONVERGE;
  late logs honest — slot vs takenAt; missed derives lazily and
  reverses) → symptoms as chart observations.
- **The engines** (pure, tested): MedicationScheduleEngine (wall
  clock; `bySettingHour` — the DST fold caught by test before it
  shipped; weekly late window = until the next dose),
  SiteRotationAdvisor (mirror-first, suggests never insists),
  MedicationPatternEngine (≥3 floors, timing-never-causality: the
  after-dose-change read — "queasiness picked up after the dose
  changed" — after-dose clusters, protein day-after dip),
  MedicationReminders (the app's FIRST actionable category: taken /
  in an hour / log later; no lock-screen skip; wall-clock triggers
  travel-safe by construction; survives breaks; never names the
  medication — the v8 privacy line holds verbatim).
- **THE DOSE SHEET**: facts as the eyebrow (ozempic · 0.5 mg),
  serif title by route ("today's shot" / "today's pill"), six site
  cells with the rotation PRE-SELECTED (visible = honest), note,
  one ink mark (pen-tick; the timestamp reward), "not today" skip
  reasons, the late-slot face ("log it late, or let it go"), the
  oral face (label rhythm line, zero injection vocabulary).
- **Today**: weekly shots LEAD dose days (v8 law); daily cadences
  ride as the first supporting row OUTSIDE the cap (a rhythm never
  dominates — gentle days still compose to the dose alone); row
  nouns per route; skipped compresses with "not today"; evening
  "yes" flows the chokepoint, "no" stays an answer.
- **THE CONSULT**: four beats for the CURRENT cohort, consumer door
  (shots/pills → which one → dose chips → weekday → reminder hour;
  every beat has an out; V8Input.weekday finally claimed); the
  clinic door skips ALL of it (her clinician's plan arrives at
  connect). MedicationOnboardingBridge: all-skips build NOTHING (the
  evening shot-day ask keeps its job). `onb_med_*` in both sweeps.
- **THE REGIMEN home** (settings "your medication"): facts as
  doors, THE RECORD (era rows off the chain), pause/stop with
  reasons, the later-enable wizard, side-effect logger door
  ("how it's sitting" — gentle words, three severities, tap to
  record/clear, no sliders ever).
- **Becoming**: the medication tile (compact, never a lead, absent
  without a regimen): dose value, tally strip (taken = bar,
  unresolved = gap), adherence read, pattern observations, THE
  DOSE ERAS ledger (weight per dose era, her unit, numeric-
  suppression honored). Chat envelope gains medication{} (compound
  never brand, dose-day/day-after flags, recent symptoms) + the EF
  timing-empathy rule (founder deploys).
- **Verified**: **587/587 units** (was 557; +30 platform/pattern/
  bridge tests); consult walker leg (GLP-1 current) green on an
  erased sim end-to-end through the new beats; frames verified:
  dose sheet (injectable + oral + XXXL floors hold), regimen home
  with the era record, becoming with the tile, the mark-ceremony
  film (crossfade artifact frame-caught + fixed).
- **Doors**: `--uitest-seed-medication injectable|oral|b2b|history`
  · `--uitest-open-dose-sheet` · `--uitest-walk-medication`.
- **Founder gates**: apply `20260809090000_v24_medication_platform
  .sql` (dose_events + regimen columns; sync defers local-first
  until then) · deploy jeni-chat EF · device walk (notification
  actions on the lock screen, a real timezone crossing).
- **Deliberate tradeoffs** (law §11): no PK "medication level"
  curve (fails data-provenance; the dose-era read answers "is it
  working" from HER data) · no site photo · no lock-screen skip ·
  era LEDGER over annotated curve in v1 · considering-cohort
  config deferred (nothing exists to configure; settings door is
  the path) · widgets queued as their own era.

## §0.-3 — APP v23: THE STILL LIFE (2026-08-07)

**`docs/app_v23/00_STILL_LIFE.md` is the era's law; `01_EVIDENCE.md`
is THE LOOP's record.** The founder's brief: forget the food module
— design it again from zero; architecture follows design. Shipped in
one pass (commits bbae8a1 → the evidence commit):

- **One material story**: glass (THE WINDOW) → understanding (chips
  on the photograph) → paper (THE READING rises) → the book. The
  camera is the product's only non-paper surface, deliberately.
- **THE DIAL** (`SnapDial`): the identity targeting frame — a
  hairline plate with four cardinal ticks; ONE morphing shape
  (scan circle · barcode wide · label tall) whose path starts at
  12 o'clock so **the reading closes the circle** (draws to 96%,
  holds honestly, accelerates shut when the understanding lands;
  one deliberate beat before the page). Replaced the brackets, the
  Metal sweep and the prewarm contract. The v22-bound IMMERSION
  shipped inside it: full-bleed feed, glass chrome, zero-geometry
  freeze, statusbar-hidden.
- **The modes**: barcode reads LIVE on the existing video output
  (VNDetectBarcodes, food symbologies) → OpenFoodFacts by code →
  the same reading (per-serving first, per-100g fallback, sodium
  g→mg, nil over fabrication — 5 mapper pins); unknown code hands
  her to the label in-surface. Label rides the existing EF with a
  trusted-context line on the `text` field — ZERO deploy. The
  library well wears her last plate; "or write it" is the camera's
  one text door; "again" moved to the book.
- **THE READING**: the 3-slide carousel died. One page in reading
  order — context line · serif name · counted kcal + ± band ·
  protein floor card · the split · THE LEDGER (five hairline rows;
  the stat-card grid was Cal AI's voice) · editable items ·
  fraction · WHAT JENI NOTICED in-page · **"add it"**. One grammar
  for photo/barcode/label/described — the `Result/` subtree
  (~2,300 LOC) and the polaroid hero family retired; the panel
  went token paper. No scores, ever.
- **THE BOOK**: the journal reborn — day SPREADS (serif date +
  once-stated ledger line), photographs lead (hero 4:3 → wide
  2.6:1 counterweight → two-across grid), photo-less meals as a
  hairline typographic menu, month seams, the current week's
  FoodWeekRead leading when floors are met, "log it again" on
  cards + the plate page.
- **The sweep**: ~1,100 LOC of confirmed-dead code (CohortCatalog,
  ResultInsights, bento/intro tiles, WeeklyShareCard line,
  SwiftData trio…), the ImOut VIEW line, the failure card's last
  hearts, the stateGood alias on the result. `persist()` dropped
  its ignored ModelContext.
- **Verified**: app units **557/557**; package **106/106 via the
  package scheme** — the FoodTheme palette pins EXECUTED for the
  first time ever (S10; the app-scheme test plan rejects package
  testables on this xcodebuild — package scheme is the mechanism).
  Films frame-reviewed: scan theater (trace → close → chips →
  rise), the book walk. Frame-caught fixes: harness providers
  (floor bar on film), sodium thousands separator, the orphaned
  square → wide counterweight.
- **Doors added**: `--food-debug-mode barcode|label` ·
  `--uitest-seed-week` (photogenic book seed, `FoodBookQASeeder`) ·
  `--uitest-walk-book`. `--debug-result-note`, satiety/handwritten-
  result preview routes retired.
- **Queued** (01_EVIDENCE §deferrals): chip→row flash · plate page
  as the reading in read mode · the filing choreography · device
  walk for barcode/label + the live feed · XXXL floors on the
  three surfaces · carousel leg re-anchor · dial radius/tick tune
  on device.

## §0.-2 — APP v22: ONE HAND, first pass (2026-08-07)

**`docs/app_v22/00_ONE_HAND.md` is the era's law** (the consistency
gate, THE MODULE CONTRACT — B2C/B2B by composition, never UI forks —
the propagation map, THE METHOD rethink design). The founder's
brief: Home/Becoming are frozen as the source of truth; propagate
the language across every remaining surface until one hand made it.

First pass shipped THE FOOD EXPERIENCE end-to-end: FoodTheme had
drifted a full era (pre-v20 paper, pre-v11.5 ink — its pin tests
never ran: PlankFoodTests isn't in the scheme) and came home with
the rose ramp; the scanner speaks plainly ("reading your plate…",
sweep halved, "add it before you eat" idle line); THE UNDERSTANDING
— recognized items land on the photograph as chips with real
calories (SnapUnderstandingChips, honest-theater law E2); the
result hero gained the protein floor bar + the plate split;
sage/amber retired into one-hue aliases; the last heart died.
`testGrantCameraOnce` primer joined QA (this sim runtime ignores
`simctl privacy grant camera`). Queued in the law §3/§6: body
motion pass · moments/chat/settings sweeps · METHOD card slice ·
journal sweep · B2B registry surfacing.

## §0.-1 — APP v21: THE INSTRUMENT (2026-08-07)

**`docs/app_v21/00_INSTRUMENT.md` is the era's law; `01_EVIDENCE.md`
is THE LOOP's record.** The founder stopped the refinement line
(v13-v20, recorded in the design law's migration log §16) and
ordered a product redesign: *communicate visually first — numbers,
rings, bars, shapes; words second; the page must still make sense
if every paragraph disappeared.* Executed in one pass:

- **§1.1b TWO INSTRUMENTS**: app surfaces are instruments
  (visual-first); the consult + moments stay editorial.
- **THE ROSE RAMP** (law §3): rose became the DATA hue — one hue,
  three depths (blush rest · dusty fill · berry now). Quantities
  fill rose; trajectories draw ink with blush wash + berry now-dot;
  selection stays ink. Anti-shame by construction; the clinical
  register stays unadorned ink. Tokens: `roseBlush #E7B3BE` ·
  `roseBerry #9E4A5F`; radii card 22 / row 18 / chip 13;
  `JeniMotion.elastic`.
- **HOME**: one-line header (greeting · "day 12" chip = the
  letter's door · gear; stacks at accessibility sizes); THE HERO
  CAROUSEL — five self-naming morphing faces (the 176pt ring with
  the counted numeral inside · protein vs its floor · the plate's
  split · chemistry weeks · the week's bars, today berry), page
  detent ticks, rose dots; the checklist became `JeniTaskRow`
  OBJECTS (blush identity chips, berry symbols, the food row
  carries the day's real plate photo, clinical rows ink, completion
  pulses + compresses); TOOLS two-across `JeniToolTile` with live
  instruments (last plate's photo · weigh-in micro-spark · steps
  mini-ring); the evening close is a list row (four blocks means
  four).
- **BECOMING**: one-line masthead; the body card leads with the
  weight NUMERAL over a 56pt trajectory; the scope bar is its own
  header ("your numbers" died); tile values 20pt serif over rose
  charts; the detail sheet's reveal staged in five breaths inside
  the untouched v19 physics; dead `BecomingDetailPage` deleted.
- **Verified**: units **557/557**; anatomy + zero-data + gallery
  legs solo green (the anatomy leg re-anchored to v21 truths and
  landed on Home via `--uitest-seed-program` — it had drifted onto
  an intro screen); films: carousel morph, tile→sheet, scope
  re-count, plate landing 860→1,100, launch arrival; XXXL floors
  fixed on Home (ring→bar face, stacked header, clamped strip,
  2-line rows) — Becoming needed nothing.
- **Doors**: `--uitest-walk-carousel` joined the film doors.
- **Gotchas paid**: the stale TEST BUNDLE lies (identical durations
  + frozen line numbers → rm the runner, build-for-testing, watch
  the Compiling line); iOS launch snapshots impersonate the old
  build on slow cold starts (a "stale" screenshot after install may
  be the previous session's snapshot — wait longer).

## §0.0 — APP v12: THE CRAFT PASS (2026-08-07)

**`docs/app_v12/00_CRAFT.md` is the pass's law; `01_EVIDENCE.md` is
THE LOOP's record.** The founder's brief: architecture untouched;
the existing product inherits the onboarding's quality bar. Shipped
in one pass (commits f59274b → 855fdf2):

- **The glance layer** (`DesignSystem/Kit/JeniGlance.swift`):
  JeniRing · JeniMetricBar · JeniWeekDots · JeniScopeBar ·
  JeniInsightPager, plus THE VISIBILITY GATE (glance pieces,
  JeniChart, JeniCountingNumeral arm on arrived AND first-visible).
- **The chart craft** (founder mid-pass steer): JeniChart matured —
  monotone-cubic lines 2.2pt + 10% wash, bars ≤24pt rounded-top /
  square-base on a grounding hairline, emphasizeLast faces, 8pt
  surface-ringed end dot, re-trace on data change. No library;
  SwiftUI Charts stays banned. JeniRibbon + JeniPillBars deleted.
- **HOME**: the nutrition CENTERPIECE (counting numeral + ring +
  macro bars + fiber·sugar·sodium whisper; a landed plate MORPHS
  everything forward — rolling digits on film); living greeting
  sub-line (kept run → trend → silence); TODAY count chip; tools as
  destinations with state lines; directional recap; tactile strip.
- **BECOMING**: time scopes (today…all) through the scoped
  aggregator (honest bucketing; waiting rows count what the scope
  counts); tile faces carry real mini charts; the weekly insight
  carousel (R6 grammar, floor-gated); detail pages gain the
  comparison ledger + WHAT THE PLAN DOES (observed-never-prescribed)
  + provenance; care-connected patients read YOUR CARE first (C8).
- **Moments**: JeniMoment hero-numeral register; the evening close
  opens "12 · of 140 days" at 96pt, counted, then types.
- **Tooling**: synthesized XCUI drags cannot scroll this sim runtime
  (probe-proven) → self-driving tour/film doors
  (--debug-gallery-tour · --uitest-walk-strip · --uitest-walk-scope
  · --uitest-open-tile <kind> · --uitest-mark-lead ·
  --uitest-land-plate seeds a real plate · --uitest-care-mode).
- **Verified**: full unit suite green; anatomy + gallery + zero-data
  legs solo green; XXXL floors hold on both surfaces; every
  frame-caught fix recorded in 01_EVIDENCE.md.

## §0.1 — THE DESIGN LAW (2026-08-06)

`docs/design/00_JENI_DESIGN_LANGUAGE.md` is canonical for all visual,
motion, interaction, haptic and copy decisions across the app. The v8
onboarding is the reference implementation; every other surface
migrates toward it. Note §13: Liquid Glass is iOS 26+ while this app
targets iOS 17 — adoption is availability-gated with
`.ultraThinMaterial` as the floor until the founder decides whether to
raise the target.

## §0 — ONBOARDING v8: THE CONSULT (2026-08-06, live)

The onboarding is a continuous conversation — ink-on-paper serif
typewriter, transcript dim-ladder, in-place paper↔ink chapter flips,
drawn evidence (rebound curve, noise wave, muscle bar, half-dots,
her projection), and THE DOOR: clinic patients enter a clinician
code (validated via care_accept_invitation; retry in-conversation)
and walk a clinical intake with zero conversion beats; weight-loss
users skip in one tap. `docs/onboarding_v8/00_DIRECTION.md` is the
law (register: plain, everyday, clinic-safe). OV5Store contract +
v4.5 completion pipeline byte-identical; `onboarding_version: v8`;
v5 behind `--onboarding-v5`. Code: `PlankApp/Views/OnboardingV8/`.
QA: walker legs `testWalkV8ToPaywall` / `testWalkV8ClinicToPaywall`
(class OnboardingV5WalkerUITests) + `--uitest-clinic-code-accept`.

Last updated: 2026-08-05 (app v11 REBIRTH begun on `feat/app-v2`)

## -16. APP v11 REBIRTH + v11.5 MODERNITY (2026-08-05) — CURRENT

**`docs/app_v11/00_REBIRTH.md` is THE LAW** (L1-L13; supersedes all
of app_v10 — those docs are deleted, recoverable from git — and
v9 04_DESIGN on visual form). `01_PLAN.md` = the plan;
**`02_EVIDENCE.md` = THE LOOP's shipped record** (12 frame-caught
fixes, 4 walker-caught interaction bugs incl. a latent v10 data bug,
the gates, the honest deferrals). The founder's brief: the current
app disappears; architecture and business logic stay; the experience
is reborn in the onboarding's design language, executed as a DESIGN
PASS (THE LOOP after every surface; "would Apple ship this?" per
screen). Commits: c5d266e docs cleanup · 07a18ee kit+motion ·
fb001a4 JeniChart · 1da2a1b HOME · 90a3db8 BECOMING · T5 legs+evidence.
Suite 537/538 (documented V6Funnel flake family); all UI legs solo
green; XXXL + SE floors walked; ~6,000 lines of journal-era product
code deleted.

**v11.5 THE MODERNITY PASS** (`03_MODERNITY.md` amends the law;
its evidence section is the loop's record): printed page → living
surface. Kit v2 — JeniSurface (soft diffuse depth, no visible
shadow), JeniCheck (the drawn check), JeniPressable, springs for
everything touched. HOME: the calendar strip is a first-class
selector (week paging, matched-geometry disc morph, the page re-keys
to the selected day with a recap for past days); TODAY rows are soft
cards with quick-mark checks; TOOLS is a word-first grid. BECOMING:
tiles MORPH in-tree into their pages (matched geometry in one ZStack,
drag-down collapse); 11 tiles now — calories, waist (BandProfile
words, never a number) and body fat (the provenance ladder) joined;
the weight axis scopes to the record. Commits 8684635 · 34b2ece ·
9558825 · 9ced524 · 2323b9e. All 7 UI legs solo green.

NEXT CYCLES: S (body scan instrument + result page) · N (Lovi scan
chooser) · chat pass (JKMasthead et al.) · sheet material pass ·
evening close re-skin.

Shape: the editorial kit (7 primitives + motion layer) → JeniChart
(one Canvas engine; SwiftUI Charts removed) → HOME from zero (MFP
information architecture: calendar strip → nutrition → TODAY →
TOOLS; body progress NOT on Home) → BECOMING chart-driven (Apple
Fitness Summary IA in paper+ink: hero body read → 8 provenance-
backed tiles — weight, protein, fiber, sugar intake, sodium, sleep,
steps, movement → BODY PROGRESS with the compare scrub). Docs
cleanup shipped with T0 (eras v2-v7, v10, archive/, onboarding
v5-v6 deleted; CLAUDE.md collapsed). Sections -15 and below are
HISTORY — read them as records, not guidance.

## -15. APP v10.2/10.3 — THE RELAUNCH: THE WAIST RECORD (2026-08-04) — HISTORY

**v10.3 correction (founder):** the mirror is for FRAMING, the
REAR camera for CAPTURE — session defaults `.back`, no mirroring
(her mirror already flips her), no switch; the distance word
("a step back"/"a touch closer") speaks when her live band's
thickness drifts >±25-30% from last week's (thickness = the
distance proxy, never a number). De-chrome: cabinet rings dead
(bare marks), checks 22pt/18%, gear receded, contents chevrons
dead. 3/3 proof legs · walker 1/1 · 505/506 units.

**`docs/app_v10/02_RELAUNCH.md` was the law** (deleted in v11 T0; git history) (the founder's third
same-day brief; the concrete directive: capture ONLY the abdomen/
waist — consistency over completeness). Shipped in one pass:
`WaistCrop` (pure, 10 tests; joints → band on the shoulder→hip
axis; ±33% horizontal window; personless default; a keep never
breaks) · `fire()` stores ONLY the crop (L4 up) · additive
`BodyScanRecord.region` ("waist"; absent = figure era; both
coexist, L2) · THE BAND replaces the ghost (V12: dual-tone
hairlines seeded from her last band) · the wide plate everywhere
(heroes/thumbs follow each plate's aspect; ink frameless on the
page — V13; photos keep the mat; dashed empty plate at zero
scans) · seeds + pose script in the waist era. Verified: WaistCrop
10/10 + MirrorGate 8/8 · 3/3 scan proof legs on the final tree ·
band guide + developed plate + both heroes frame-verified · reel
v3. **Founder gates:** the in-hand mirror walk (band placement,
±33% window, field visibility over a real bathroom) · V11-V13 ·
D10 waist lines.

## -14. APP v10.1 — THE REINVENTION (2026-08-04) — HISTORY

**`docs/app_v10/01_REINVENTION.md` was the law** (deleted in v11 T0; git history) (the founder's
second brief: keep the architecture, reinvent the experience — the
Body Transformation Journal). Supersedes 00_DIRECTION §4 where they
conflict. Three moves, all shipped + verified:

**M — THE MIRROR CHECK-IN (33bfff5).** Capture joined the ritual
she already has: bathroom · mirror · front camera · phone in hand ·
five seconds. `MirrorGate` (pure, 8 tests): person + ~1s stillness
fires; her thumb always fires. Mirror-legible symmetric signals
(border inks with steadiness, ring fills, paper flash); countdown/
ghost/pose-gate retired from the flow (V8/V10 — old gate math kept
under tests pending sign-off). THE DEVELOP unchanged. The guided
leg proves the no-tap stillness path.

**H — THE FRONT PAGE (ae646a5).** The ink figure stands ON the
page (no card; photos keep the mat), the change line is the
headline, THE DAY follows in pure typography (all row/act discs
died; the check is the only mark); editorial scroll with the lead
above the fold.

**J — THE JOURNAL + THE JOURNEY SCRUB (d45c24c + close-out).** The
carousel/fore-edge/page-turn retired (V9): becoming = cover spread
(content-sized) → HER RECORD (matted plates) → THE CHAPTERS
(editorial contents pushing the shipped pages; masthead inside the
stack; --uitest-becoming-page pushes). The compare = one drag
across ALL scans, a haptic detent per scan, serif date beneath,
release settles on a scan. Fixed en route: the trend trace-in
(withAnimation over @State inside Canvas froze under a push — now
self-driven, the JKSilkSweep lesson) + chapter arming (reads the
push path, not appear/disappear).

**Verified:** 496/496 units once, 495/496 twice (the documented
flake solo-green ×4) · 3 scan proof legs green per phase · core +
every-surface walkers · recordings frame-reviewed (ritual, develop,
journey settle, chapter draw-in) · XXXL floors · reel v2.
**Founder gates:** the in-hand mirror walk at a real mirror ·
V8-V10 review (then the pending deletions) · D10 drafts
(01_REINVENTION §6).

## -13. APP v10 — THE MIRROR PASS (2026-08-04)

**`docs/app_v10/00_DIRECTION.md` was the law** (deleted in v11 T0; git history) (the founder's
same-day brief after v9 closed: the architecture is done, the FEEL
is not — three seconds after open the app must say "body
transformation"; Home's information-hierarchy lock + D1's narrow
grant explicitly superseded; §8 = V1-V7 founder review ledger; §9 =
shipped record + D10 drafts). Engines untouched; view layers
rebuilt.

**Phase A (ea8c456) — THE MIRROR OPENS HOME.** First viewport: her
matted figure + the change line (one spine with WeeklyBodyReview),
the day's asks, four quiet ink doors, numbers as ONE receipt line
(`DayLedgerLine`; heart keeps its L5 surface). Removed: day rail
row (caption keeps `today.weekRibbon` + the becoming door;
JKDayRail compiled-unused pending V1), pastel sticker discs + tools
(clinical ink rings; stickers = celebration language only), metric
rings (JKMetricStrip deleted). `TodayMirror`/`BodyMat`/`BodyFigure`
(one drawn figure: zero-scan ghost + human seed scans). TodayView
joins BodyScanStore.didChange.

**Phase B (9360c5c) — BECOMING OPENS ON HER.** The landing = THE
RECORD COVER when scans exist (`bodyScan.landingFigure` default ON;
record-sheet door = the opt-out, old cover + body page return); the
record sheet gains its standing line; THE COMPARE gains physics
(mid-cross tick, settle-to-pole spring, stage speaks its pole —
`record.compare`, asserted; the assertion exposed that the v9 leg's
drag had never engaged). Fore-edge at honest weights.

**Phase C (782f86d) — THE CHAMBER.** Capture in a matted aperture
on paper (words in ink below the glass; black scrim dead); THE
ARMING FRAME renders Arming.progress (dead accessor since P1); THE
DEVELOP — the photograph becomes ink through the mat on silhouette
keeps (~1.2s wash + settle haptic; RM = finished print). QA:
`--uitest-scan-simulate-pose` + `testGuidedCaptureSimulatedPose`
walk the guided feel on the sim. Fixed: the reset door's async
prefs re-wipe racing a leg's consent tap (records-only now). XXXL:
consent/landing scroll as overflow.

**Verified across the pass:** full unit suite green per phase
(488/488 once, 487/488 twice with the documented OV5Store flake
solo-green) · all three scan proof legs green together · core
walker + every-surface walker solo · recorded frame review of the
mirror states, the landing, the compare settle (thumb-trace), the
chamber + develop · XXXL floors on every touched surface.
**Founder gates:** the device walk re-run (chamber/arming/develop
feel) · V1-V7 review · JKDayRail deletion on V1 sign-off · D10
drafts (00_DIRECTION §9).

## -12. APP v9 — THE BODY OS, P0-P7 COMPLETE (2026-08-03/04)

**P7 SHIPPED (4710589): THE PROGRAM CLOSES.** DebugPreviewRoutes
decomposition (380 lines out of PlankAIApp.body, behavior-identical,
route parity framed); XXXL truncation fixes on the v9 surfaces
(consent title/cards/eyebrows wrap); the v9 reel recorded (capture →
record → becoming → timeline → compare, proof legs green on camera).
488/488; walkers green. **The founder gate ledger lives in 05_BUILD
§THE v9 PROGRAM (9 items: bucket SQL · food-vision deploy ·
summaries migration · live probe/Playwright/demo · THE DEVICE WALK ·
D10 copy · dose-dot review · HK BG capability at archive · D6
counsel).**

**P6 SHIPPED (41a5757):** care_weekly_summaries (insert-only weekly
history; patient-computed, no AI; RLS patient-writes-under-packet-
consent; clinician RPC-only w/ audit + lookback; **founder applies
20260804090000**); CareWeekSummary + WeeklySummaryPublisher (onLaunch,
packet cadence, graceful un-migrated); dashboard week-by-week panel +
weight series via care_get_patient_series (the idle S4 RPC consumed)
+ the staleness word; probe +9 checks STAGED (live run = founder/
local-stack gate); D6 posture held (risk flag out until counsel).
487 iOS units; tsc clean.

**P5b SHIPPED (4c53de7, 2026-08-04): P5 COMPLETE.** The voice-law
heart sweep reached the food package (48 glyphs / 17 files — U+2665
renders as the RED emoji heart; caught on a live frame); the jeni
note gains the muscle-keeping line (P4 vocabulary). Honest
correction: the insight-first card ALREADY shipped (v1.0.7 "show
macros" disclosure) — the audit's UI half was stale. 482/482; card
frame-verified; core walker green.

**P5a SHIPPED (1afc7f5):** the food story pipeline — sodium/sat-fat
through EF schema (founder deploys) → capture → JSONL → cloud; the
per-ingredient ledger + story data ride the EXISTING payload jsonb
(zero-migration route: unknown columns would reject upserts;
reinstall now restores the ledger); FoodWeekRead bands (protein-led/
late-heavy/steady; ≥4 logged days; never a number/food/score) lead
the becoming food page. 481 units; walkers green. Held: P5b
insight-first result card + frame review.

**P4 SHIPPED (1792482):** the promotion ladder gains the body axis
(rapid-loss → preservation-at-risk (the P3 ladder's daily echo) →
yesterday's deficit; plateau week reaches the lead's reason as
support — never a push/override/dose-day); `Plan.leadIsPromoted` →
the dose-dot beside a promoted lead's reason (D1 grant b; AA-safe;
medication + gentle unadorned by law). One spine two cadences: the
weekly read and daily lead share the preservation ladder. 474/474
(+6); walkers green. Founder frame-review of the dot invited.

**P3 SHIPPED (5f91894):** `WeeklyBodyReview` — the becoming landing
read unified (outcome → ≤3 floor-gated mechanism observations →
muscle-preservation ladder (protein × movement × 1%/wk; wycherley
chip; lean w/ provenance) → CoachSummary's move untouched); rising
weeks pattern-only, mirror clause only behind full body-page floors;
HRV back WITH its rendered recovery line (D5 closed; string
updated); the L5-honest "connect workouts" door; chat envelope gains
body facts. 468/468 (+22); walkers + proof legs green; landing
frame verified.

**P2 SHIPPED (eba4586):** becoming's BODY PAGE (matted scan +
BodyChangeRead floor-gated line; climbing weeks never blame the
mirror) → YOUR RECORD sheet: THE COMPARE (one-drag then↔now
crossfade, anchor-aligned via stored pose-gate figure bounds,
clamped, never surfaced — L3) + week groups + the D2 cover opt-in
(silhouette face). D1's whisper: "trend · easing" in the evening
receipt ledger. The once-ever intro (migration-moment law, day 2+,
stamped-on-present). BodyScanStore.didChange (scan → becoming
recomposes live). Analytics: body_scan_kept / body_vision_intro
(counts/choices only). QA: --uitest-seed-scans (drawn narrowing ink
figures) · --uitest-force-body-intro · --uitest-reset-body-scan.
446 units (+10 BodyChangeRead); walkers + both proof legs green;
frames reviewed.

**P1 BODY VISION SHIPPED (05_BUILD §P1, commits 46deb98→898b6c7):**
`PlankApp/BodyScan/` — guided front-camera capture (live
VNDetectHumanBodyPose coaching, ghost overlay, 3·2·1 auto-shutter,
manual fallback), on-device ink-on-paper silhouettes
(VNGeneratePersonSegmentation; silhouette-first per D2, photo
opt-in), one-time consent in the clinical register, her record
(local-only BodyScanRecord + photo store, EXIF-free, L4 plumbing
same-commit); the weekly OFFERED invitation via
`ProgramDayPrescription.bodyScan` + CarePlanEngine (Sunday
first-offer → her anchor weekday, never debt, gentle days drop it,
never markable); the D3 opt-in backup (`BodyScanSyncService`,
default OFF, off = cloud copies removed, dayKey-in-path restore;
**founder applies `scripts/body_scans_storage.sql`**) + settings
doors. The orphaned plank camera was salvaged in and deleted.
Verified: 437/437 · BodyScanProofUITests (consent→capture→keep→
persist, erased sim) · onboarding + core walker legs solo · scan-day
Home frame. Founder gates: bucket SQL · device walk for live pose
coaching (sim has no camera) · D10 copy review. QA doors:
`--uitest-open-body-scan` · `--uitest-scan-allow-manual` ·
`--uitest-force-scan-day`.

**`docs/app_v9/` is the law: 00_MISSION (laws L1-L7; APPROVED, D1-D10
at recommended defaults) · 01_AUDIT (anchored fact base W1-W10) ·
02_PLAN (phases P0-P7) · 03_DECISIONS (resolved ledger) · 04_DESIGN
(DESIGN 100× constitution — design quality is the bottleneck, ADA
bar, remove>add, unforgettable-interaction > new feature) ·
05_BUILD (shipped record).** The founder's Body OS brief: body
progress becomes the center ("I can actually see myself changing"),
explained by food/movement/sleep/medication; Body Vision guided
scans are the signature (P1-P2, on-device, silhouette-first, NO
number ever derived from a photo); extension, never rewrite.

**P0 SHIPPED (05_BUILD):** `BodyStateService` one typed body read
(TodayStateService delegates, equivalence pinned) · passive weight
REPAIRED (importIfEnabled was dead code — now launch-wired +
bodyMass/steps observers + background delivery + entitlement;
onboarding's bodyMass grant honored) · HealthKit truth pass
(VitalsService dropped 5 never-rendered reads; the cycle read
finally HAS a requester — it rides the steps/sleep sheets; all four
permission strings rewritten Jeni-brand + honest, D10 drafts await
founder voice review in 05_BUILD) · MovementService silent probe
(strength/energy/distance; auth ships with P3's surface) ·
PassiveWeightProofUITests (HK sample → zero-tap import → becoming
reads "down about 2 lb this week."). Verified: 421/421 units ·
proof leg green on an erased sim · onboarding v7 + core-in-app
walker legs solo green · the V6Funnel full-suite flake = the
documented OV5Store deinit / iOS 26.2 sim abort (solo-green,
pre-existing). Founder note: next device archive picks up the
background-delivery capability on the App ID.

## -11. ONBOARDING v7 — THE CLINICAL GRADE PASS (2026-08-03)

**`docs/onboarding_v7/` is the law: 00_DIRECTION (four v7 laws +
decision ledger D1-D12 + shipped record) · 01_RESEARCH (four new
evidence lanes over v6's digest) · 02_AUDIT + audit/ (the fact base:
beat inventory with the 22-site female-specific map; verified
data-flow with PLAN/EXP/DEAD verdicts per question) ·
03_COPY_DECISIONS (every rewrite with its law).** The founder's
second same-day brief: NOT a redesign — make the funnel persuasive,
clinically credible, conversion-focused; gender must actually matter;
kill questions that change nothing; scientific-confident voice
without losing warmth.

Shipped (P0-P5, commits 7aa733d → f6064e3 → 6177040): **THE PERSONA
MACHINE** — `OV5Persona` (her/male/neutral) resolved live from the
gender answer; the male path skips the hormonal beat AND the safety
gate's pregnancy screen (SCOFF runs for everyone); male ruler seeds
178cm/88kg (untouched-only); act eyebrows neutral pre-persona,
act V splits "almost hers/yours"; her-register lines ("women who…",
"her file", "sign her in", the wall's "her," axis, "other women")
render ONLY for explicit female; identity beat keeps its five keys —
photo grid for her, typography cards otherwise. **QUESTION LAW** —
priorWin CUT (dead answer); its slot teaches the protein floor to
the cohorts muscleMath doesn't cover (wycherley 2012, ajcn —
verified); appetiteReturn + supports + nsv WIRED (loader lines,
dataMirror row, dossier BEYOND THE SCALE + ALREADY TAKING rows,
wall band-1 row); the signature's day-2 consent finally gates the
day-1/first-days push family (explicit false suppresses; missing
key keeps shipped default). **EVIDENCE LAW** — zero hearts anywhere
(9 removed from the safety gate); the SCOFF names its instrument on
screen (morgan 1999, bmj); "fifty-two answers" → live computed
count (35 general / 37 current, arithmetic-verified); "most
chosen." → "the middle of the safe band."; the 5-7% milestone cites
fda benchmark · dpp; foodNoise cites food-cue reactivity · hayashi
2023 in all three variants; terminal headlines state their
adjustment (the "gentle it is." family died). **REVEAL + WALL** —
"your becoming, plotted" → "your next {N} weeks, plotted"
(computed); the sub is the outcome ECHO (five falsifiable variants
of her Act-I answer); "pick your pace."; the wall gains the
end-state row ("built to be outgrown… then shifts to keeping",
computed weeks — the Hinge move, product-true) + BEYOND THE SCALE
in band 1; weekly tier sub "a smaller first step"; fold, pricing,
and honesty mechanics untouched. `onboarding_version: v7` (same
events/once-guards — before/after reads directly in PostHog).

Verified on the final tree: **407/407 units** (was 396; +router/
persona/funnel tests, one test re-pinned to the version constant) ·
walker legs green end-to-end, zero MISSING: generalWL female +
**generalWL MALE as "ben"** (the founder's 08-01 walk, answered: no
pregnancy ask, no hormonal beat, typography identity, "your file",
no "her," axis) + GLP-1 current (recorded) · past-cohort + SE-class
+ Reduce Motion legs green (SE: the known transition-race MISSING,
resynced by design; RM renders complete) · 306s recording
frame-reviewed (commitment seal, nudge payload, projection draw-on
with stable computed headline, wall chart draw-on — no pops/seams) ·
SE fold holds (three tiers + band eyebrow above the docked close) ·
protein floor renders cohort-correct across walks (90g at 1.2 g/kg
generalWL vs 125g at 1.6 GLP-1-current). Walker infrastructure
hardened: exact-match gender taps ("male" CONTAINS-matches
"female"), StoreKit review-sheet dismissal (NOT suppressed on the
iOS 26.2 sim; stalls fresh installs), GENDER=female|male|nonbinary|
private legs, the male leg walks as ben. **KeepWall 3/3 on an
erased sim** (recovery ladder · pricing-fail · Dynamic Type XXL)
with the v7 wall copy.

## -10. ONBOARDING v6 — THE CONVERSION EVOLUTION (2026-08-02)

**`docs/onboarding_v6/` is the law: 00_DIRECTION (five design laws +
founder ledger F1-F8 + shipped record §10) · 01_AUDIT (the founder's
62-frame device walk mapped) · 02_RESEARCH (three evidence lanes).**
The founder's brief: evolve — never replace — the v5 onboarding +
keep wall so the funnel reads "a legitimate, medically grounded
program," converting dramatically better. No architecture changes:
the OV5 machine, acts, interaction language, and data contract are
untouched; the register moved warm-generic → warm-specific (number +
unit + basis; conditional mood; named real sources), the peaks got
the craft, every promise sells the CURRENT product.

Shipped (8 commits, a26ab6a→30086cf): P0 brand/heart stragglers
(rating gate = ink JeniMark bloom + "enjoying jeni"; nudge banner =
"Jeni" + the official j icon; SCOFF's heart cut; welcome's dead
italic + heart accent fixed) · P1 register pass (Mifflin-St Jeor
named on the gender ask, the care part's published-standard line,
sleep/stress engine-coupled acks on the new `OV5SelectList
.advanceDelay` — startedOver/weightTrend migrated too, killing a
back-nav strand) · P2 teach figures (food-noise settling wave;
muscle-composition bar; credibility bridge = identity + three
methodology rows) · P3 reveal rebuilt curve-first (four TRUE tiles —
the plank-era grid sold a dead product; protein floor now rides
TargetsService.proteinTargetG; the sub speaks her computed weeks;
loader completion = the JeniMark seal moment; pace rows translate
%/wk into her unit under slope glyphs) · P4 first week = the real
Day-1 checklist mock (JFDeviceDemoFrame lockedScene) · P5 the wall:
fold unchanged + EARNED-TRUST BANDS below (her plan on one page /
why this works, third-party-sourced / what's included, shipping
surfaces only / the jeni rules + seal "— jeni") + a DORMANT
real-proof band (renders only when the founder supplies verbatim
ASC reviews + rating), bow + flowers → the dose-dot, scroll-gated
chrome scrim · P6 sweep fixes (resting scrim hid the SE headline;
muscle-bar clip; stale keep-wall test labels).

Verified on the final tree: full unit suite green · v5 walker
generalWL + GLP-1 current green · KeepWallUITests 3/3 on an erased
sim (full recovery ladder incl. reclaim row · pricing-fail · XXL) ·
projection draw-on frame-verified · SE rest/scrolled + XXXL + Reduce
Motion captured clean. QA doors added: `--uitest-skip-payment`
(keeps RevenueCat unconfigured so StoreKit's account sheet never
rides a capture; a stuck sheet is a PERSISTENT SpringBoard layer —
reboot the sim; NOTE it also holds the app pre-wall, capture-only) ·
`--debug-paywall-bands` (auto-scroll the wall) · `--debug-first-week`.

**THE RELEASE PASS (same day, founder-directed):
`docs/onboarding_v6/03_RELEASE.md` is the release decision document
and the measurement contract.** Canonical production funnel under
`onboarding_version: v6` (V6Funnel in AnalyticsManager: install →
onboarding_started → care_safety_completed → personalization_
completed → plan_reveal_viewed → paywall_viewed → plan_selected →
purchase_started → completed/cancelled/failed/pending →
restore_*; once-guards + approved metadata block; ATT context/
prompt/result instrumented — F3 testable later), emitted ALONGSIDE
legacy events; purchase_completed keeps its ONE edge-triggered
stream fire site (cached-entitlement init preserves the edge across
cold launches). Truthful purchase resolution: pending ≠ failure
(Ask-to-Buy message + purchase_pending), network drops never claim
"nothing was charged", the smaller-step silent no-package tap now
speaks + reports. Latent analytics-sink race fixed (mutations
serialize onto the send queue). F2 real-proof = founder-editable
`PaywallRealProof` block (verbatim-only law, disappears cleanly);
F8 = dormant `ClinicalReviewRecord` (scoped "content reviewed for
clinical accuracy by …", renders nothing until a real reviewer).
Research digest re-audited (evidence classes + the no-forecast
rule; Cal AI = removed AND reinstated). Experiment decisions: F3
ATT stays mid-loader; F4 no trial this release — next experiment =
hard wall vs 7-day trial on yearly, judged by revenue/install +
retained paid subs at ≥45d, only after 03_RELEASE §8 gates mature.
Founder DEVICE gates: sandbox purchase/pending/restore legs
(03_RELEASE §11).

## -9. THE JENI RELEASE — 1.2.0 (27), 2026-07-30

**`docs/jeni_release/00_JENI_RELEASE.md` is the release law +
record.** The execution release: no redesign — brand, palette
maturation, one signature element, craftsmanship fixes. JeniFit
became **Jeni** under the OFFICIAL identity
(`docs/jeni_release/identity/Design.pdf` — the hand-drawn j mark,
"the distance is the idea"; lockup = mark + Title-case "Jeni" in DM
Sans; one-colour law ink↔ceramic, never rose; ONE canonical
`JeniMark`/`JeniWordmark`),
CFBundleDisplayName = Jeni, all user-visible copy swept; identifiers
unchanged (bundle id, jenifit:// scheme, jenifit.app URLs + support
mail, RC product ids, jenifit.default). Palette matured pink-first →
**warm paper + ink** (bgPrimary #FCFAF7 · ink #2A1F1E · bgElevated
white · launch == bgPrimary, one continuous surface; rose accent +
stickers + typography/motion untouched; FoodTheme mirrored + pins;
AA floors improve). **`JKBorderBeam`** joined the design system
(placement law in its header — earned/premium only, never
medication, one region/screen, ≤0.5 peak; placed: paywall's chosen
plan + program-ready CTA). Craft: paywall tier truncations fixed
(verified on live RC pricing), yearly renewal line carries its year.
**THE VOICE PASS (same release, founder re-steer):** clear · calm ·
confident · precise — Apple Health, not Instagram wellness. Hearts
retired app-wide (zero in shipping copy; chat normalizer strips
heart emoji from streamed replies); cheer clauses cut ("you've got
this", "i'll be right here", "keep going"-with-heart); rose ornament
slots → the dose-dot or ink JeniMark seal; affirmations speak
product truths ("the trend matters. the day doesn't."); lowercase +
italic punch words + verb law + anti-shame framing stay; letter
signs "— jeni". feedback_voice_signals memory updated (hearts law
superseded).
App icon = the official matte-ceramic j tiles (light/dark/tinted),
verified on the springboard as "Jeni"; the clinician site favicon
carries the same mark. Verified: 396/396 units ×2; onboarding v5 walker +
core-in-app + settings legs green (solo, house law); launch
continuity by pixel; beam travel by frame-diff; S4 reconciliation
renders in the clinical register, beam-free. Founder at submission:
ASC product-page rename to "Jeni" + new screenshots.

## -8. App v8 — THE CARE PLATFORM (2026-07-28) — LIVE SYSTEM (clinic loop on dev; docs/app_v8 still law)

**Doc set: `docs/app_v8/` (00_MISSION · 01_RESEARCH ·
02_COMPETITORS · 03_ARCHITECTURE · 04_DECISIONS · 05_BUILD ·
06_ONBOARDING). Read 00_MISSION first — the founder's product
evolution: consumer app → coach → patient → clinic WITHOUT
rebuild; every record tenant-friendly, nothing clinic-shaped
rendered. 04_DECISIONS carries the decision/postponed/needs-
founder ledger; where v8 docs and older law disagree, v8 wins;
where v8 is silent, §-7 stands.**

Research-first per the brief: four cited web lanes (clinic
operations + CY2026 RPM billing atoms + Jan-2026 FDA lanes;
adherence science — ≤3-5 ask cap, contact-frequency as THE
persistence lever, supplements-never-co-equal, shot-day ritual;
B2B teardowns — Healthie's time-spine/clinical-spine split is the
category gap CarePlanEngine closes, org-null-tenant object model;
consumer teardowns — nobody composes a day, "after the
medication" has zero consumer products, trend-as-hero is
peer-reviewed retention) + two codebase audits. Shipped:

- **CareProtocol + BrandVoice (the platform seam):** every
  clinical constant in one injectable Codable config (`.default`
  == shipped behavior, equivalence-tested); rules/voice split in
  CarePlanEngine (JeniVoice byte-pinned). One deliberate fix:
  GLP-1 small-body protein floor caps at the advisory band.
- **ObservationStore + RegimenPlan (the chart):** typed
  userId-scoped observations (feeling/sit/dose/note/tonight/
  hydration/care events; deterministic per-day ids; "queasy 3 of
  last 7" computable; one-time legacy backfill; survive sign-out
  like weight logs) + regimen plans (shot-day anchor, org seam).
  Additive migration `20260728_app_v8_care_platform_foundation.sql`
  (observations/regimen_plans own-row + protocols/protocol_items
  read-all, seeded with the serialized default) — **founder must
  apply it; until then sync 404s gracefully local-first.**
  Defects fixed: `day.dose.` joined the sign-out sweep; the dose
  mark is read back (checklist ↔ evening ask agree).
- **Medication first-class:** dose days compose the day —
  medication leads ("mark today's dose", quiet pills mark, no
  sticker), the keystone demotes to supporting, a GENTLE dose
  day is the dose alone, hydration leads invitations during the
  8-week titration window (teacup sticker revived). Row tap =
  HER REGIMEN sheet (weekday menu + remove + privacy line); the
  mark stays on the circle (deliberate). Evening: dose "yes"
  marks the row; the one-time shot-day ask collects the anchor;
  sit-check gains **"backed up"** + reaches the post-medication
  chapter; all answers dual-write (legacy key + observation);
  morning reads go store-first.
- **Verified:** 347/347 units (CareProtocol 13 · ObservationStore
  7 · Regimen 8 new); sim reel: standard dose day / gentle dose
  day / evening receipt (1-of-3). QA doors: `--uitest-seed-regimen`
  (dose day today + titration live) · `--uitest-open-gap 0` for
  standard tone (a stale sim gap composes gentle — that's the
  law working) · QA launches wipe the seeded user's chart for
  determinism.
- **Founder refinement (same day, second brief — 04_DECISIONS
  FR1-6):** the clinician is medication's future source of truth —
  RegimenPlan `authority` (self|care_team; iOS writes self ONLY) +
  rxnorm/strength reconciliation seams (migration 20260728_2) +
  `isManagedByCareTeam` mutation guards; dose/sit observations
  stamp their regimen id. THE CLINICAL REGISTER (resolves F2): no
  hearts / stickers / celebration / rose on any medication
  surface — outline disc + ink glyph, "your dose day," the
  timestamp as the only reward ("taken · 8:04 pm"), pen-tick
  haptic, heartless sit acks, privacy line once in the sheet;
  every non-medication surface stays warm (same bones, ornament
  subtracted). Bridge: settings door "your medication" (value =
  her shot day); supports deliberately NOT built (no empty state
  exists — reasoning in FR3). Cadence weigh + demoted keystone
  now speak their reasons (FR5).
- **Third brief (2026-07-29, FR7-9): think from the clinic
  first.** `07_CLINIC_MIRROR.md` is the standing law — every
  patient surface maps to the clinician configuration it will
  render from (configure-vocabulary validated against live
  platforms; alert-budget law: thresholds default conservative,
  tune DOWN). `CareProtocol.supports` [SupportItem] = the
  clinician-authored adjunct seam (consumer default EMPTY —
  nothing renders; S3 = one attributed observational line, never
  pill-check rows; protein stays the only tracked support).
  Care-not-feature verified: medication composes into the day or
  doesn't exist.
- **S2 SHIPPED (2026-07-29, migrations applied by founder):** the
  protocol is SERVED — `CareProtocolStore` (enum service) fetches
  `protocols.id=jenifit.default` every launch → clinical sanity
  gate (whole-or-reject; bundled default + last-good cache as the
  permanent floor) → engines compose from `CareProtocolStore
  .current`. Tolerant decode for additive fields. Verified live
  on-sim (served cache lands; regimen pendingUpsert round-trips).
  A clinic = a different row through the same resolver — the
  white-label mechanism is live mechanics now. Gotcha recorded:
  isolated-CLASS deinit aborts on the iOS 26.2 sim runtime →
  app-target singletons stay enum services. 362/362 tests.
- **STAGE A SHIPPED (2026-07-29):** onboarding reframed over the
  untouched v5 machine — the care-plan contract at arrival, verb
  law through the intake, the 5-7% educational milestone on the
  projection, the `shotDay` beat (current cohort only; the flow's
  ONE clinical screen; skip first-class) + `supports` single-ask
  (intake fact; recommends nothing; renders nothing), dormant
  typed `OnboardingContext` clinic seam, authority-guarded
  completion handoff (care_team-untouchable; skip/no-med = no
  medication state). The reveal speaks "your first week of care"
  with the plain medication-rhythm rail from HER answer. Rider: 8
  canonical mirror keys joined the sign-out sweep. First OV5
  router unit tests (10); 370/370; walker legs green per cohort
  (TEST_RUNNER_GLP1_COHORT; erase stale-entitlement sims first;
  the walker now dismisses SpringBoard nags). 08_STAGE_A.md =
  the plan; 05_BUILD phase 8 = the shipped record.
- **S3 SHIPPED (2026-07-29): the visit-prep packet.** A
  deterministic 28-day projection over the chart (no AI, offline-
  valid, every line traceable): adherence w/ unrecorded-is-not-
  skipped honesty, trend-floor weight, timing-never-causality
  symptoms, protein consistency, bounded editable questions,
  honest gaps. **F1 resolved**: self-reported = "your weekly
  medication" (leak-tested); care_team = assigned facts.
  ConsentGrant seam (explicit/scoped/revocable/audited, inactive
  default; migration 20260729 — **founder must apply**; nothing
  delivered anywhere). One entry: becoming's "for your next
  visit" page → the clinical-register sheet + share-as-pdf.
  381/381; on-sim verified line-by-line. Doors:
  `--uitest-open-visit-packet`. 09_S3_PACKET.md = law; 05_BUILD
  phase 9 = record.
- **S4 SHIPPED (2026-07-29): the first real clinic loop.** A
  legitimate clinic actor connects to one consenting patient, reads
  her canonical S3 packet, assigns care, and that exact care becomes
  her lived daily plan — provenance preserved, consent explicit,
  isolation server-enforced, access reversible. **10_S4_CLINIC_LOOP
  .md = law; decisions S4-1..S4-10 in 04; 05_BUILD phase 10 =
  record.** Additive migration `20260729180000_s4_clinic_loop.sql`
  (orgs · members [owner/clinician/staff] · invitations [peppered
  hash, single-use, 72h, throttled] · relationships · consent scopes
  [visit_packet_view/observation_view/care_assignment] + lookback ·
  protocol_assignments · correction_requests · append-only
  care_audit_events · visit_packets) — **founder must apply**
  (applied live this session on the dev project). Clinician touches
  of patient data are SECURITY DEFINER RPC-only (the disclosure-audit
  chokepoint); patient charts have no direct clinician policies; F1
  masking is a server projection; the FR1 client guards became server
  law. A `clinic/` static web dashboard (Supabase-direct, publishable
  key + RLS, no service-role) is the five-screen clinician surface.
  The patient side renders care-team assignments through the EXISTING
  runtime (dose-day lead), the FR2 reconciliation moment (confirm
  retires the self plan, history intact; future dose marks join the
  care-team id), a read-only care-team regimen face + correction
  door (164.526-shaped, never mutates), the connection+consent
  sheets (three scopes + lookback chooser + not-monitored line), and
  a "your care team" settings door. **Revocation is prospective +
  access-only** (access ≠ treatment). Verified: 62-check live
  security probe · Playwright E2E · 15 iOS units (396/396) · a live
  on-sim 20/20 end-to-end loop against the dev DB with direct DB
  inspection · frame + a11y (XXXL Dynamic Type) audit. **Internal
  dev alpha, test data only, NO BAA — never "HIPAA compliant"; a real
  clinic pilot gates on BAA + security posture + breach process.**
  QA doors: `--uitest-care-connect-code` etc. (05_BUILD phase 10).
- **S5 SHIPPED (2026-07-30): PILOT-READY JENI CARE.** The S4 internal
  alpha became a product one real obesity clinic can encounter,
  understand, evaluate, and pilot. **11_S5_PILOT_READY.md = law;
  decisions S5-11..S5-19 in 04; 05_BUILD phase 11 = record; the
  operations set lives in `docs/app_v8/pilot/`.** The brand is now
  **Jeni Health › Jeni Care (the clinician platform) › Jeni (the
  patient)** — clinician surfaces rebranded Jeni Care, patient still
  "your care team"; internal ids (bundle, `jenifit.default`, `care_*`
  RPCs, `clinic/`) stay stable; a name-risk scan found no obvious
  blocker (counsel gate before paid marketing / App Store rename).
  Additive migration `20260730090000_s5_pilot_ready.sql` (**founder
  applies to a fresh pilot project — NOT the consumer-prod dev DB**):
  explicit `clinical_authority` (owners aren't auto-clinical; staff
  never), `organizations.status` suspension, `is_demo` tenancy,
  mode-gated org creation + single-use provisioning codes,
  member-role/end-relationship admin (+ last-owner guards),
  `care_environment` identity, structurally-redacted `ops_events` +
  anon-bounded `pilot_requests` (both API-unreadable), service-role-
  only operator RPCs. The **dashboard** rebranded + gained environment
  guards (per-env build, dev-ref + support-mailbox build guards, boot
  mismatch hard-stop, quiet dev/staging badge), clinic administration,
  password reset, first-run orientation, a help/boundary sheet, and
  redacted ops reporting. A static **Jeni Care website** (`site/`,
  deployed to Vercel, build Ready, behind the founder's access gate,
  noindex) — the between-visit-horizon hero, the 5-step loop, real +
  recreated product evidence, the trust/boundary sections, and a
  bounded pilot-request form. A resettable fictional **demo tenant**
  (`scripts/care_demo.py`). The **pilot operations set** (model,
  runbook, vendor/BAA inventory + founder checklist, retention,
  metrics + interview guide, founder demo package, counsel-required
  legal drafts). **Verified:** iOS 396/396 (unchanged); the extended
  security probe 97/97 (+expiry) and a 22/22 pilot-readiness proof
  against a full local Supabase stack running the complete migration
  chain (the pilot-like environment — real data must never use the dev
  project); Playwright E2E; axe WCAG 2.1 AA 0 violations (site +
  dashboard). **Still internal dev alpha, test data only, NO BAA —
  never "HIPAA compliant"; no AI in the clinic loop; no health data in
  analytics/logs.** Founder gates before any real clinic (11_S5 §15):
  pilot Supabase project, BAA chain, counsel-finalized legal, cyber
  insurance, risk analysis, public site exposure, trademark clearance.
- **Onboarding (superseded by Stage A above):** the v5 machine
  itself remains founder-reviewed law —
  `06_ONBOARDING.md`: Stage A reframe recommendation (intake
  framing, 5-7% expectation anchor, shot-day beat, supplements
  single-ask) + the dormant clinic-door architecture.
- **Held (04_DECISIONS):** supplements UI line; dose-day brief
  softening; sit↔shot-week correlation lines; v7 phases 3-4.
  S4-deferred (named in 10_S4 §15/§29): e-prescribing/pharmacy,
  billing minutes ledger, staff drafts-pending-signature,
  FormTemplate intake, clinic BrandVoice, push, messaging,
  multi-clinic-per-patient, protocol composer, population analytics,
  cookie sessions, org self-serve. HIPAA/BAA + FHIR interop + SaMD
  opinion remain the non-app gate before any external clinic pilot.

## -7. Mission 3 + THE FOUNDER STEERS (2026-07-27/28)

**`docs/app_v7/03_EDITORIAL.md` is the editorial constitution
(third fresh panel); `04_CLINICAL_CHECKLIST.md` is the clinical
data roadmap. Where anything below disagrees with older sections,
THIS section wins.**

Mission 3 (editorial composition) shipped, then the founder
live-steered Home four times in one evening; both lines landed:

- **HOME = THE CHECKLIST** (founder: "colorful icons… users just
  follow and check off"). Dateline eyebrow (tap = letter,
  long-press = settings; masthead chrome dead) → **JKDayRail
  restored** (navigable week strip; past days open JourneyWeekPage
  receipts) → ChecklistRow list wearing the founder-locked
  STICKER badges (BeatDisc: peach snap · heart-lock weigh ·
  balloon-dog move · candy method · breath-ring breath, SF
  fallback) with real check-off (tap circle / hold row; tap
  enters module; offered rows quiet, never counted) → HER TOOLS
  rail (weigh/method/breathe/move sticker doors) → **JK METRIC
  RINGS** (calories/protein/steps rings + resting-heart frame —
  the word-ledger, fast/night/steps rows, and the forming band
  all died; "no ring without a target" holds). The second act
  (reflect/prepare/recover/celebrate) wears the same rows —
  the day never empties. KeptLine/vow monument retired.
- **THE CLINICAL CHECKLIST** (founder: collect what clinics need,
  passive first): dose-day mark + sit-check in the on-medication
  evening (generic wording, Apple 5.2.1-safe); VitalsService
  (resting HR 7d/30d baseline, HRV, VO2max, respiratory rate —
  silent bootstrap, read types ride the steps/sleep consent
  sheets); VitalsTrend tested (±2 steady / 3+ easing/climbing vs
  HER baseline only). Ship order + not-doing lines in 04.
- **THE CLOSING RECEIPT** (evening): 52pt two-line owner,
  FootLedgerRow ledger, bare-serif word asks (feeling / dose /
  sit — chosen word inks rose), tonight-plan as hairline menu,
  journal on a bare rule that inks rose under focus.
- **BECOMING = THE ISSUE WITH ART**: cover wears her latest plate
  photo of the week full-bleed (type-poster fallback); spreads
  museum-hung (figure first, 33pt caption-headline beneath); ONE
  caps line lives in the fixed running head and turns with the
  page; wordmark tap = cover, long-press = settings (hamburger
  dead); fore-edge ticks on the trailing screen edge; JKPageTurn
  (subtle parallax + 5° lift). NightSheet/WindowSheet deleted
  (stories live on becoming's pages).
- **CHAT = TWO VOICES**: jeni in the 17.5pt serif letter voice on
  a narrowed measure; her replies as rose italic marginalia;
  day breaks = small-caps seams between short rules (JKQuietSeam
  app-wide); composer = bare hairline + rose ✦ send. Panel bugs
  dead: demo-exchange duplication (fire-time guard + QA-store
  heal) and the masthead bleed (scrim law).
- **Verified**: 326/326 units; ceremony + journey + motion-tour
  walkers green (run UI legs SOLO — chaining after the parallel
  unit suite drops presses); E4 frame reel confirms letter
  cascade, seam-free tab dissolves, cover fade, no-reflow Home.
- **QA doors**: --uitest-open-gap N · --uitest-cohort · --uitest-
  seal-day/unseal-day · --uitest-start-tab takes the TAB NAME.
- **Founder-open**: tab-bar treatment; letter oldstyle date; 96pt
  post-log calorie hero; passive rails beyond resting heart
  (HRV/VO2max surfaces).

## -6. Mission 2 — VISUAL UNIFICATION (2026-07-27, same day)

**`docs/app_v7/02_VISUAL.md` is the VISUAL CONSTITUTION** (fresh
9-persona visual-only panel judged against the onboarding's 22
beats; artifacts in `panel_visual/`). The founder's brief: the app
read as a well-designed productivity tool; the target is editorial
luxury, the onboarding is the signed register, the checklist is
the signature to reinvent (never remove), becoming diverges from
Home, the roman folio is dead. Shipped: **THE CEREMONY** (Home —
THE KEPT LINE: hold-to-countersign with jeni's ✦ seal + commit
haptic; the dateline eyebrow carries the day's seal and opens the
letter; the 60pt calorie monument; ledger observations),
**THE ISSUE** (becoming — 38pt cover line, chevron-free contents,
THE FORE-EDGE leaves), **THE INTERVIEW** (chat — bubbles dead,
typeset on cream, rose-ink replies, hairline card frames), and
the sweep (evening sequenced one-ask-per-beat, serif headers,
merged figure rows). Machine-verified: surface walk + the
sign/unsign/tap ceremony leg green; 316/316 units per phase.
Tail: food still-life audit, chat her-file/action cards, full
side-by-side frame recordings.

## -5. App v7 — THE CARE PLAN (2026-07-27)

**Doc set: `docs/app_v7/` (00_THESIS · 01_BUILD · panel/). Read
00_THESIS.md first — it is the redesign law, synthesized from an
11-expert independent critique panel + a behavior-change
literature lane (all critiques preserved in `panel/`).**

The founder's first-principles redesign brief: stop feeling like a
calorie/habit tracker; feel like a companion quietly taking care
of her. Phases 1-2 shipped:

- **CarePlanEngine** (`Program/CarePlanEngine.swift`, 17 tests):
  the day composed from STATE, not slot tables — gentle tone
  (tender evening / short night / days away → ONE move by rule),
  clinical lead promotions (rapid-loss protein guard, yesterday's
  protein deficit), weigh-in as the only ringed supporting move,
  workouts/breath/method as invitations. Receipt arithmetic +
  the silk moment follow the plan. The evening feeling chip is
  read back next morning (brief 2.5 + gentle tone in parallel).
- **Home inverted**: position line (day rail DELETED) → THE
  UNDERSTANDING (the reading in full, 22pt serif, the page's
  reason) → the plan (ring policy: rings only on moves) →
  "noticed for you" receipts (overnight fast returned as an
  OBSERVATION — founder's name kept, ≥12h ring deleted; steps
  "counted for you") → evening close. Sticker tiles left daily
  rows (the seal lands ON completion); kcal budget bar died
  ("room for ~600" permission frame); HowItWorksBlock deleted;
  cycle ask moved out of received care.
- **becoming inverted**: the serial pager retired. Landing =
  JENI'S READ OF YOUR WEEK (CoachSummary promoted from pager page
  ~11) + HER SIGNALS hairline index (one-line reads from the same
  generators as the pages) → NavigationStack pushes into the
  untouched story pages (roman folio, AX-safe scroll).
  `--uitest-becoming-page N` now pushes.
- **One thread**: Home's "from jeni" opens the live jeni thread.
  **A11y floors as law**: cocoaTertiary 0.68 (AA on cream,
  `TokensContrastTests`-guarded), VoiceOver "mark as done"
  actions, hearts stripped from spoken labels, 44pt camera, the
  night-sheet blank state fixed (sheet law: no conditional
  closures). Landed-moment haptic collision fixed.
- **JeniMethod verdict (hybrid, literature-cited)**: the daily
  required row died; content atomizes into trigger-matched
  delivery (phase 5); the pull-only shelf + share card survive.
- 309/309 unit tests green.

**Held for next phases** (thesis §11): first-move letters (2-3
unprompted/week, event-triggered, JeniNoteView reserved as the
arrival moment) + comeback tiers + celebration ladder (phase 3);
chart-grammar port + type-ladder sweep + heart budget +
JeniHaptics semantic layer + light-only declaration (phase 4);
ObservationStore + CareProtocol + BrandVoice split + shot-day
anchor + post-medication arc + method atoms + visit-prep card
(phase 5 — the invisible white-label seam).

## -4. App v6 — THE SIGNALS (2026-07-17)

**Doc set: `docs/app_v6/` (00_RESEARCH · 01_BUILD). Read
00_RESEARCH.md first — its safety framing rules are ENGINE LAW,
not copy guidance.**

The passive layer: retention research says passive monitoring
sustains engagement where active logging decays, so v6 turns the
streams the app already holds (plate timestamps, HealthKit
steps/sleep, weigh-ins) into felt understanding with ZERO new input.

- **Engine** (`Program/Signals.swift`, 22 tests): `KitchenSignal`
  (live overnight-window phase machine over QuietHours' math; praise
  saturates at 14h, 16h+ speaks care; the on-medication chapter gets
  the fuel-frame inversion — "first plate landed", never hour
  arithmetic), `SleepSignal` (forgiveness bands), `MealMoves`
  (post-meal walking receipts, Buffey floor), `WeekRhythm`
  (weigh-day cadence + first-plate median), `Sweetness` (time-of-day
  shares + direction, hard floors). All food-derived signals ride
  `QuietHours.mayNarrate`.
- **Home**: the SIGNALS band after the food band — THE WINDOW
  (JKWindowHorizon: the night as a horizon diagram, jkDawn-lit,
  breathing ember when live; tap → WindowSheet w/ 24h ring +
  7-night band + cited mechanism), NIGHT (crescent row; tap →
  NightSheet w/ stage-banded JKSleepDial over a jkNightSky
  starfield + 7-night bars), AFTER-MEAL MOVES (receipt line,
  absence never renders). First-day teaching whisper. The old
  moon caption line is superseded and deleted.
- **Becoming**: pages now line · food · plates · sweetness ·
  window (7-night falling-band figure) · sleep · movement ·
  rhythm · plan · band · reflection. Visuals re-arm per swipe.
- **The word "fasting" never renders.** Windows are observed,
  never prescribed; no timers, no targets, no streaks.
- QA: `--uitest-force-signal <phase>` / `--uitest-force-night` /
  `--uitest-force-signals` / `--uitest-open-window-sheet` /
  `--uitest-open-night-sheet`. Sim gotcha recorded in 01_BUILD.md
  (parallel jelly-skin agent session on the shared booted sim;
  zsh launch args must be arrays).

## -3. App v5 — the experience pass (2026-07-07)

**Doc set: `docs/app_v5/` (00_DIRECTION · 01_REPORT). Read
00_DIRECTION.md first (§6 = the re-steer). Supersedes v4's LANGUAGE
layer AND becoming's vertical-ledger layout; v4's engines (arc /
weeks / weekly review mechanics / receipts law) stand.**

Part 2 (the re-steer, same day): **becoming is a horizontal insight
story** (JKStoryPage pager: weight figure → food arc + chemistry
row → movement rhythm → this-week + her-weeks timeline → band
(keeping) → from-jeni letter; visuals re-arm per arrival), **Home
carries THE DAY RAIL** (seven tappable day cells, today as a filled
date pill, past days open receipts — the calendar-strip answer),
plan history lives one level in (JourneyTimelineView), calories
stay Home's lead food sentence, and carbs/fat/fiber surfaced from
long-stored fields (vitamins/minerals need an EF change — fenced).
Chart craft: rebuilt protein arc (gradient sweep, tip head, target
notch), under-glow trend stroke, chromeless story figures; the
canvas scrub retired on story pages (it ate the pager's swipes —
frame-audited).

The organizing principle: **one program, spoken plainly, shown
beautifully.** v4's private language retired across every surface
("the plate story" → "today's plates"; "the re-signing" → "your
weekly review"; "the trend fed 3 times" → "weighed in 3 times";
"the bend, named" → "the plateau week"). Trust floors added: the
reading teaches the ritual on day one and may not speak trend
language until 3+ weigh-ins span 5+ days; the trend story speaks
her display unit; the trend line no longer wears an unrelated
insight's caption. Becoming's header is ONE object (ordinal + phase
+ ribbon + intent; midpoint countdown in the eyebrow; leadLine
retired). Week cards mark today's dot and close with the week's
EMA delta in neutral ink. Jeni's transcript groups as dated letters
with no-repeat seeding and always-relevant starter chips. The
breath bloom holds the stage (360pt field, deeper rose). Evening
chips answer a visible question; day receipts speak plain lines and
today "is still being written." Tab arrivals settle with a 4pt
rise. 194/194 tests; SE + Dynamic Type XXL verified; evidence in
`docs/app_v5/evidence/` (gitignored).

## -2. App v4 — the program rebuild (2026-07-06/07)

**Doc set: `docs/app_v4/` (00_THESIS · 01_PROGRAM · 02_JOURNEY ·
03_FEATURES · 04_BUILD_PLAN · 05_REPORT · research/). Read
00_THESIS.md first; 05_REPORT.md carries the evidence map + honest
gaps. Supersedes docs/app_v3 where they disagree (the v3 day model
survives; the journey dimension is new).**

The root fix: the program now exists as an object. `ProgramArc`
(named phases per chapter: losing = finding steady → the early read
→ the build → the bend → the last stretch → the hold; on-medication
= arriving → rolling practice blocks; keeping = the settle → kept),
`WeekIntent` (named weeks, deterministic, zone-aware, pick-aware),
and **THE RE-SIGNING** (`WeeklyReview`): at her week's boundary jeni
reads the week back and proposes ≤1 consented change from a closed
safe set, applied through knobs the engines already read (protein
adjust inside the advisory clamp, sessions bend, weigh softening,
intent picks). Records are device-local JSONL; "plan."/"review."
prefixes ride the sign-out sweep.

**THE JOURNEY**: becoming rebuilt as the plan-over-time surface —
arc ribbon + phase header, one-story trend (EMA direction word;
raw-vs-EMA badge contradiction dead; band always fits the domain),
THIS WEEK card, week-chaptered ledger (standing dots in tense ink,
week stories, signed adaptation stamps, quiet seams — absence never
renders), week pages → read-only day receipts, dotted future shape,
her-plates archive (v1 journal interior deleted). Today gains the
WEEK RIBBON (7 dots + week name → journey; the her-days sheet
family is deleted), THE PLATE STORY (filmstrip + one protein gauge
+ "room for about 600" day answer; steps ring dead), evening
ends on her journal line, and THE TONIGHT PLAN (if-then chips whose
plan the next morning's reading names back).

Interiors: breath rebuilt (JKBreathField generative bloom on a
zero-velocity sinusoidal BreathClock + BreathHaptics continuous
CoreHaptics envelopes + no numerals; BreathCircle deleted); workout
completion = the kept receipt (stars died app-wide; effort-feel
signal kept); the wave dial (craving-occasion before/after). Chat
context carries phase/week/intent/last-re-signing. Anchor rungs
announce named weeks; the re-signing knock (id `resigning_knock`,
4-site protocol) lands at week close. `jenifit://` finally
registered (CFBundleURLTypes). Legacy sweep: −6.4k lines (Becoming
dashboard family, Plan atoms, FoodLogTimelineView).

Bugs killed: unscoped `todayKcalTotal` cross-account seam (snap
beat vs band contradiction); the re-signing auto-offering from the
HIDDEN becoming tree over Today (all tabs stay mounted — offers now
gate on the visible tab); cover-identity blanking; the SE dateline
wrap. Production fences held: zero schema/EF/payment/gating
changes. 195/195 units; 7/7 walker legs (new journey/re-signing leg
+ direct-open QA hooks: `--uitest-open-week N --uitest-open-day D`,
`--uitest-keep-reviews`, `--uitest-becoming-bottom`). Evidence:
`docs/app_v4/evidence/` (gitignored, on disk).

## -1. App v3 — the reading-first rebuild (2026-07-05)

**Doc set: `docs/app_v3/` (thesis · verdicts · design language ·
build plan · verified research · safety report · honest gaps). Read
00_THESIS.md before touching the day model.** The founder's brief:
lowest possible effort, highest possible feeling of being understood;
GLP-1 + post-GLP-1 as first-class audiences.

The core inversion: prescription-first → READING-FIRST. Today opens
with jeni's reading (grown DailyBriefEngine: line + second sentence +
mechanism, deterministic + provenance-only), THE ONE THING (single
engine-chosen ask as the screen's only filled card), THE RHYTHM
(hairline rows — no at-rest circles, no counts), the band, and an
evening receipt that leads after 18:00. Padlocks died; the strip
wears standing dots (DayStanding: kept/partial/quiet — ONE vocabulary
across strip/review/receipts/wins).

Three chapters (`Chapter` in DayModel.swift, derived in CohortStore):
losing / on-medication / keeping. On-medication: protein floor as
adequacy hero, evening "did you eat enough?" net, "how did today
sit?" one-tap (HER pattern reflected back — never an asserted
medication cycle; that claim was refuted in verification research).
Keeping: BandModel (STOP Regain zones on the EMA: steady / drifting
~1.4kg / reset ~2.3kg over settle), reading threads that OPEN actions
(the null-trial law), ritual band whisper, canvas band field,
kept-weeks scoring.

The method became THE REP (RepView + RepEngine): scenario + doors +
warm mechanism lines, reader one tap deeper; MethodResolver killed
the three divergent lesson resolvers (two read zero-writer cohort
keys). PresenceLedger redefined "shown up" (was workouts-only) to
any meaningful action, lifetime count, never resets, self-healing.
BreakState = "on a break" (pauses rhythm + all uninvited pushes;
ProfileHub row). Jeni tab opens with HER FILE (the v5 dossier alive)
+ the full reading; CoachContext gains chapter/band_zone/kept_days/
on_break. Becoming: band field + raw numeral de-heroed.

Production: zero schema/EF/payment/gating changes (see
docs/app_v3/PRODUCTION_SAFETY.md). 152 unit tests green. Remaining:
docs/app_v3/HONEST_GAPS.md (notably: notification orchestrator
phase 7 designed-not-built; rep content beyond the 16 authored;
weekly consent check-in).

## 0. App v2 — the in-app rebuild (2026-07-03, feat/app-v2)

The in-app experience was rebuilt to cash the onboarding v5 promise.
Doc set: `docs/app_v2/` (00-11 + SCIENCE.md). What changed:

- **Gating**: route-level `AppPhase` machine (`PlankApp/App/`) —
  booting / onboarding / wall(.fresh|.expired) / migration / main.
  Exactly one phase mounts; unpaid/expired users never have main
  content in the hierarchy. Expired payers get `ExpiredWelcomeView`
  ("still here. still yours."). Auth transitions hold the last
  stable phase. Table-tested (`AppPhaseTests`, 10 cases).
- **IA**: three tabs — today / jeni / becoming — over the custom
  `JKTabBar` (serif-italic active label + matched-geometry dot).
  Camera FAB retired; snap lives in Today's masthead + beats +
  plate strips + a jeni tool. Settings reachable from BOTH tabs.
- **Today** (`PlankApp/Views/Today/`): the daily ritual — Fraunces
  day pill masthead, jeni's brief line (DailyBriefEngine cascade,
  provenance-only), the day strip, 3-5 engine-composed beats
  (PrescriptionEngineV2: workouts follow sessionsPerWeek, lessons
  follow tier cadence arc-completely, weigh-in is a cohort cadence
  with stale fallback, breath heroes rest days), today-so-far band
  (protein arc hero + steps ring + kcal sentence + plates strip),
  evening close after 18:00. Cross-off completion everywhere.
  PlanView reachable via `--legacy-today` until founder sign-off.
- **Jeni chat** (`PlankApp/Chat/` + `supabase/functions/jeni-chat`):
  SSE-streamed coach over an OpenAI EF (JENI_CHAT_MODEL env, key
  server-side, per-user + budget caps, telemetry ledger). Client
  assembles a provenance-only CoachContext per turn; crisis/ED
  language routes to fixed care responses locally; seven
  client-executed tools with confirm cards for mutations. The
  letter-register UI (no bubbles). Local-first transcript
  (ChatMessageRecord). Deploy: `supabase functions deploy jeni-chat`
  + run `supabase/migrations/20260703_app_v2_chat_and_cohort_columns.sql`.
- **One source of truth for numbers**: `TargetsService` (protein
  1.6 g/kg GLP-1-current / 1.2 default; calorie target recomputes on
  latest weight via the plan's implied rate) — snap result, Becoming,
  Today, chat all read it. `CohortStore` is the ONE reader of cohort
  keys and fixes the dead CBT bridge (CohortFlags read six
  zero-writer keys pre-v2). Session ratings finally persist
  (userId + pendingUpsert added). Dietary settings edits finally
  reach food-vision (`DietaryProfileResolver`).
- **Becoming**: curated under six modules (macro bar cut, moved
  strip + deeds into the depth sheet); journal rows are photo-forward
  catalog cards (protein-only at rest; p·c·f lives in detail).
- **Migration**: `MigrationMomentView` (one-time, provenance
  receipts) for entitled legacy-footprint users; `appV2SeenAt`
  stamps on first main mount.
- **Notifications**: `NotificationDelegate` — taps deep-link through
  AppRouter (`jenifit://` grammar), queued until .main so expired
  users land on the wall. Full orchestrator consolidation is spec'd
  (`docs/app_v2/09_NOTIFICATIONS.md`) but not yet built.
- **QA args**: `--uitest-seed-program`, `--uitest-start-tab <tab>`,
  `--uitest-mock-chat`, `--uitest-chat-demo`,
  `--uitest-force-migration`, `--uitest-today-bottom`,
  `--debug-jenikit` (component gallery).

**v2.1 pass (same day):** Becoming REBUILT as the insight layer
(`Views/Becoming/BecomingView.swift` + `Program/InsightEngine.swift`
— trend-as-coach-story, ranked pattern insights with ask-jeni seeds,
method journey, wins receipts; `docs/app_v2/12_BECOMING_V2.md`).
Day-complete silk sweep (`jkSilk` Metal shader, frame-diff verified).
Workout celebration de-emoji'd (typographic "kept."). Onramp speaks
receipt grammar. Deploy-safety audit GO/GO with pre-deploy fixes
(telemetry FK, budget-sum RPC, 502 leak) — founder checklist at
`docs/app_v2/13_DEPLOY_SAFETY.md`; usage data + feature-by-feature
status + sweep list at `14_V21_NOTES.md`.

Founder actions pending: run the migration SQL then deploy jeni-chat
(exact checklist in `docs/app_v2/13_DEPLOY_SAFETY.md` — verified
safe for the live app in any order vs the release), device pass,
then the legacy sweep (`--legacy-today` / `--legacy-becoming` /
v4.5 escapes; list in `14_V21_NOTES.md`).

This is the source-of-truth doc. Read it first. Anything earlier in
`docs/archive/` (deleted in v11 T0; git history) documented research that informed shipped
work and is preserved for history, not for guidance. When this doc and
an archived doc disagree, this doc wins.

---

## 1. Who the app is for

JeniFit is a women's weight-loss iOS app. Primary audience is TikTok-acquired
women 22-35, weight-loss-motivated, anti-femvertising. The brand voice is
post-Ozempic vocabulary (satiety, food noise, permission, fits, tomorrow
resets), lowercase casual, italic-Fraunces punch words on a soft cream
canvas. No diet-culture verbs (no crush / shred / burn / earn / deficit).
No "AI" word in user-facing copy.

The product converges on a GLP-1-era posture (see section 3). It serves the
generic-WL audience first; cohort routing layers acknowledgment on top.

---

## 2. What ships today

### Auth + sync
Anonymous-first Supabase auth, Apple + email upgrade, sign-in recovery,
delete-account + forgot-password (anti-enumeration). All entity reads
filter via `@Query userId` to enforce cross-account isolation. Sign-out
sweeps user-scoped `@AppStorage` keys and cancels retention notifications.
Profile, session_logs, day_progress, weight_logs, session_ratings sync via
typed Codable upserts. UUID case normalized at hydrate boundaries.

### Payment
RevenueCat with `customerInfoStream` observation. `PaymentService`
re-configures on `auth.currentUser` changes so a sign-in/out doesn't
strand the prior user's entitlement. The KEEP WALL (2026-07-07
no-trial rebuild; doc rot naming a "3-day trial" corrected
2026-08-02): three tiers — the year (badged + pre-selected) · the
quarter · one week — pay-upfront, billed-today on the row + CTA,
per-week equivalents subordinate (3.1.2c), tier-matched downsell
sheets on cancellation intent + the reclaim row. `restore()` flow
respects existing paid users (no re-onboarding). Paywall pricing
reads RevenueCat's localized `storeProduct.localizedPriceString` per
Apple Guideline 3.1.2(a) — no hard-coded prices.

### Onboarding
**v5 ground-up rebuild (2026-07-02)** — `PlankApp/Views/OnboardingV5/`,
typed step state machine (no Int cases), ~46 beats in 5 acts with
GLP-1 cohort branches. Docs: `docs/onboarding_v5/` (INTENT / PANEL /
STRATEGY / FLOW / DATA_CONTRACT / SHIPPED — read SHIPPED.md first).

Interaction language: cross-off strikethrough single-selects with
auto-advance; her75 tick rulers (haptic detents, digit-roll serif pill,
rose delta band, live weeks math); rapid-fire fear statements with
strike-the-fear; act-end receipts that mirror her answers back; snap
demo mid-food-wedge (real Metal `snapSweep` over 3 staged plates, the
flow's single luminance inversion, honest "one of ours" framing);
her-file dossier + signature (consent + disclaimer in one beat) +
hold-to-build close.

Structure: GLP-1 status asked at the top of Act II as a path-fact —
current (phase + appetite rhythm + muscle-math teach), past (stop
window + appetite return + regain-truth teach, maintain-kept surfaced
first), considering (agency teach). Safety gate (SCOFF/pregnancy/BMI/
meds) relocated into "the care part" at the end of the numbers act —
still pre-paywall, no longer at peak anticipation. Name in Act I so the
dossier, loader, projection, and wall are addressed to her.

Reveal (shared with legacy, `skipsPreamble` for v5): receipt-tape
loader (cites LIVE keys only — the v4.5 dead-field narration bug is
fixed), pace picker, projection with causal receipt rows ("because you
X → we Y", rendered only when the engine modifier fired), first week
(cohort-routed rails), fear-resolution beat (replaced the pre-wall
rating ask; rating is post-purchase only), commitment ritual (merged
time anchor writes day1PromiseTimeISO + plankTime; demo pre-leads
"snap your first real meal"), nudge ask (banner payload = her promise
at her time + trial-reminder promise row).

Cohort pace floors unchanged (`ProgramGoalCalculator`): GLP-1 /
perimenopause 0.3%/wk, short-sleep penalty, regain-risk notch; new
`onboarding_glp1_stop_window` / `onboarding_appetite_return` /
`onb_v5_appetite_rhythm` keys feed loader + reveal copy. Data contract
preserved byte-for-byte (`docs/onboarding_v5/DATA_CONTRACT.md`).

Legacy v4.5 (`OnboardingView.swift`) stays reachable via
`--onboarding-v4` during burn-in; sweep scheduled after founder
device sign-off. QA: `OnboardingV5WalkerUITests` walks welcome→paywall
with a screenshot per beat (`TEST_RUNNER_GLP1_COHORT` for branches).

### Program / Plan tab
Today screen with archetype pill (7 archetypes; tap-to-explain sheet),
day strip with week-ahead archetype letters, long-press → MarkAsDoneSheet
override (row body tap = enters module; state indicator is render-only).
ACSM-grade weight-loss pacing. Rest weeks + restrictive override +
strength-day copy variants. Engine: `ProgramGoalCalculator`,
`ProgramDayPrescription`, `PlanView`.

### JeniMethod (CBT-style lessons)
Manifest-driven curriculum, 42 topic-matched Grok hero photos, CBT-spine
lesson reader (`LessonReaderView`), `LessonPracticeView`, archetype-aware
pillar affinity (lessons bias toward the user's program archetype).
Sharing: lesson quote share card as luxury magazine pull-quote (organic
acquisition lever). See `PlankApp/Views/DietEducation/`.

### Snap Food (food rail)
v1.2 rebuild (2026-07-01). Three input modes behind one toolbar:
**snap** (camera) / **describe** (text → same estimate pipeline) /
**again** (`RecentMealsSheet` one-tap relog).

Camera capture → vision EF (single OpenAI model via
`FOOD_VISION_MODEL` env; the app-side USDA calibration sweep guards
low-confidence items) → **result stage: 3-slide carousel over the
full-bleed photo** (2026-07-02, founder call — the v1.1.2 swipe
vocabulary restored in the v1.2 panel design; the photo never moves,
the slides carousel over it, white dots ride the top):

- slide 1 "the plate" — two-detent editorial panel: count-up kcal
  hero + protein co-hero, "ate about half" fraction chips,
  always-visible ingredient ledger with inline portion steppers,
  tap-through `IngredientEditorSheet` with coherent macro↔kcal math
  (`PlateEditSession` in `SnapResultMath.swift`, unit-tested),
  inline "fix it with words" + "+ add something" composer
  (`SnapRefine` through the EF text path — live against the
  deployed backend).
- slide 2 "a note from jeni" — the anti-shame note
  (`ResultDetailCopy`) on its own panel slide, native sparkle
  accent.
- slide 3 "share" — the on-photo composer (`SnapShareSlide` font
  rail; preview IS the exported PNG) slides in full-bleed over the
  same steady plate.

Scanning is a Metal pass (`snapSweep`: diagonal warm band + grain,
`SnapShaders.metal` in the SPM package). Result-land plays the
retinted Sparkling lottie burst (`FoodResultExplosion`; rose body +
light-pink rim per locked palette — replaced the heart + star pair).

Per-item nutrition detail persists with every entry (device-local
JSONL, backwards-compatible); journal detail shows the ledger +
"again" relog. Photo-scan capture notes + photo-grounded corrections
activate on the next `supabase functions deploy food-vision` (the EF
folds `text` into image requests as trusted context).

Food journal long-press delete, photo timeline, matched-geometry
meal detail. QuickAdd (describe) has dynamic chip suggestions
(recents + cuisine). See `Packages/PlankFood/`.

### Becoming dashboard
Today's energy tile, protein gauge, weight trend canvas (EMA line +
raw weigh-in headline, 7-day delta vs prior-week's raw — never
day-over-day to avoid scale anxiety), plate timeline with [+] →
snap-food camera, food journal swipe-to-delete. Cohort-aware identity
word + insight lines. Interactivity layer added Phase 4 (insight swipe
cycle, plate swipe-left). See `PlankApp/Views/Analytics/AnalyticsView.swift`.

### Breathwork
`BreathworkHomeCard` + bento tile + science-honest primer. Cites
Balban (Stanford), Epel (Yale), Meerman (BMJ), Sato (Senobi). Cortisol
mechanism, NOT fat-burn claim. Lives in `PlankApp/Views/Welcome/` and
the home rail.

### Steps
First HealthKit-backed rail. 7,500-step anchor (not 10k). Pulse on home
+ bento depth pattern is the model for future health rails. See
`PlankApp/Health/`.

### Launch screen
Pure pink `LaunchBackground` (`#EFB9CF`), status bar hidden, no image.
Loader (`AffirmationLoaderScreen`) is cream with jeni·fit wordmark
fading in at 60ms + her75 affirmation rising in at 340ms (7-line
dayOfYear rotation: "you are becoming her" / "soft is strong" / "your
timeline is yours" / "begin again, anytime" / "small choices stack" /
"kindness is the strategy" / "she is already in you").

### Notifications
Trial-window: day 0 anchor + day 2 engagement + trial-end T-24h. Daily
reminder via `NotificationPermission.scheduleDailyReminder` (canonical
id `daily_reminder`, voice-adaptive body, surgical pending-removal so
trial-end isn't nuked). Cohort-aware variants (general WL / on-GLP-1 /
post-GLP-1 / considering) per the spec at
`docs/notification_system_spec_2026_06_16.md` +
`docs/notification_per_cohort_preview_v2_2026_06_16.md`. Day-5
anti-refund push is gated on trial-active so it doesn't fire on
cancelled trials.

---

## 3. GLP-1 cohort strategy — convergence, not pivot

`docs/glp1_strategy_2026_06_16.md` is the authoritative reference.
Read it before any feature work that touches cohort routing or copy.

Operating principle: build for the existing generic-WL audience first,
but layer cohort routing on every change so a GLP-1-cohort user gets
the right identity acknowledgment without the engine forking.

The four cohorts (`Glp1Cohort` enum in
`PlankApp/Notifications/RetentionNotifications.swift`):

| Onboarding answer | `Glp1Cohort` | Identity |
|---|---|---|
| `"current"` | `.onGlp1` | woman on a GLP-1 now |
| `"past"` | `.postGlp1` | woman off a GLP-1 in 0-12mo window |
| `"considering"` | `.considering` | weighed the shot, didn't start |
| `"none"` / `"prefer_not_say"` / empty | `.generalWL` | safe default |

The cohort routing pattern: **cohort signal lives in the noun phrase /
identity acknowledgment, NOT in feature promises.** Bodies reference
only features that ship today (lessons, breath cards, Becoming, food
rail). Until protein floor / food-noise tracker / keep-it-off
curriculum / etc. exist, copy never names them. Every promise must be
cashable in-app within 3 sessions.

Compliance floors (non-negotiable):
- No drug brand names on app-controlled surfaces (Apple 5.2.1).
- No drug-equivalence claims (FTC NextMed $150K precedent).
- No "GLP-1 alternative" / "natural Ozempic" framing (FDA Feb 2026
  warning letters).
- No first-party numeric weight-loss claims.

Companion flag helpers live alongside `Glp1Cohort`: `isShortSleeper`,
`isGLP1User`, `isPerimenopausal` — every cohort-aware engine reads
through these, not raw option strings.

---

## 4. Design system

### Source files
- `PlankApp/DesignSystem/Tokens.swift` — palette, typography, spacing,
  motion, radii. **THE** source of truth for visual tokens.
- `docs/THEME.md` — narrative reference for the same tokens (use this
  to onboard a new agent on the brand, not to look up exact values).
- `docs/itgirl_illustration_system_2026_06_12.md` — illustration
  pipeline + placement grammar.
- `docs/her75_typeface_spec_2026_06_10.md` — JeniHeroSerif identification
  + opto adjustments.
- `~/.claude/projects/-Users-bko-plankAI/memory/feedback_locked_color_tokens.md`
  — locked-tokens rule (the user's auto-memory).

### Locked palette
Only the 8 canonical tokens defined in `Tokens.swift`. The cream
`bgPrimary` is the ONLY background on every surface. `programBgPrimary`,
`programEraBg`, `programCard` are aliases — do NOT introduce new
backgrounds.

### Typography
- **JeniHeroSerif** (Playfair Display 650/620i renamed under OFL) for
  hero headlines + paywall hero + plan-reveal hero. Roman/italic only
  (no Light). LineGap −0.505×size. Intra-word italic flourish on the
  punch word.
- **Fraunces** for wordmark + paywall headline punch + onboarding
  questionHero. Italic accent on 1-3 words per line.
- **DMSans** for body copy + UI chrome + captions.

### Voice signals (in-app copy)
- Italic-Fraunces on the punch word only (`*becoming*`, `*today*`,
  `*shows up*`). NOT `*italic*` markdown syntax — use `ItalicAccentText`
  composition.
- Hearts (♥) as terminal punctuation ONLY.
- Lowercase casual throughout.
- No em-dashes between words. Glyph "—" as no-data placeholder is OK.
- No brand-coined verbs.
- Pill labels 2-4 words. Subheads 5-7 words. Concrete > abstract.

### Motion
8 tokens in `Tokens.swift`: `entrance` / `entranceSoft` / `exit` /
`crossFade` / `tap` / `gentleSpring` / `stagger` / `breathing`. Five
additional her75 transitions: `pageExit` / `pageEntrance` / `pageGap` /
`bloom` / `chipPulse` / `cascadeTight`. All animation sites must reduce-
motion gate.

### Sticker scatter rule
Sticker scatter renders ONLY on the 3 earned moments: welcome / plan
reveal / graduation. Questions, bridges, teach, dashboards, settings
stay scatter-free.

### Real-photo guardrails (Direction A)
Hybrid editorial real-photo hero + coquette sticker accent. Three
non-negotiable guardrails: real photo ≥40% canvas + stickers ≤10% + ≤2
per screen + NO licensed stock ever. AI 3D stickers are permanently
dead. Coquette ID stays via photographed-real-objects.

---

## 5. Where to look for things

| Doc | What it covers |
|---|---|
| `docs/STATE.md` | This file. Start here. |
| `docs/glp1_strategy_2026_06_16.md` | GLP-1 cohort strategy + routing rules. |
| `docs/notification_system_spec_2026_06_16.md` | Notification system architecture + per-cohort copy. |
| `docs/notification_per_cohort_preview_v2_2026_06_16.md` | Founder-reviewed copy preview, v2 supersedes v1. |
| `docs/feature_gap_synthesis_2026_06_16.md` | Convergent vs cohort-specific feature roadmap. |
| `docs/positioning_research_r2_final_2026_06_16.md` | R2 positioning deliverable (R1 archived). |
| `docs/jenifit_v2_strategy_2026_06_13.md` | v2 strategy synthesis (5 expert lanes). |
| `docs/jenifit_positioning_panel_2026_06_15.md` | 5-expert positioning panel. |
| `docs/workout_session_rules.md` | Workout engine source of truth. |
| `docs/THEME.md` | Visual system reference (companion to `Tokens.swift`). |
| `docs/her75_typeface_spec_2026_06_10.md` | JeniHeroSerif spec. |
| `docs/itgirl_illustration_system_2026_06_12.md` | Illustration register + Grok pipeline. |
| `docs/privacy_policy.md` + `docs/terms_of_service.md` | Hosted at jenifit.app/privacy + /terms. |
| `docs/app_store_metadata.md` + `docs/APP_STORE_SCREENSHOTS.md` | ASC metadata drafts. |
| `docs/content_engine_plan.md` | AI-persona TikTok+IG content pipeline. |
| `docs/odr_migration_plan.md` | On-Demand Resources migration future plan. |
| `docs/exercise_balance_audit.md` | Workout L/R balance reference. |

---

## 6. What NOT to look for

Things that USED to be canon, later moved to `docs/archive/`, now deleted entirely (v11 T0; git history). Don’t
treat these as guidance:

- **Pivot research from 2026-06-05** (`pivot_research_*`) — the
  workout→diet-first pivot exploration. Resolved into v2 strategy.
- **CalAI research bundle** (`calai_research_*`,
  `calai_teardown_*`) — informed the food rail + onboarding. Patterns
  are now embedded in shipped code.
- **BetterMe research bundle** (`betterme_*`) — informed v1.1 program
  pivot (75-day → custom). Already shipped.
- **Round 1 positioning** (`positioning_research_final_2026_06_16.md`)
  — superseded by R2. The R1 "Quiet" wedge was rejected in favor of
  cohort-led conviction.
- **Round 1 notification preview** (`notification_per_cohort_preview_2026_06_16.md`)
  — v2 collapsed it to ONE trial-end reminder + no spam. Use v2.
- **v1.0.7 / v1.0.9 plan docs** — shipped. Reference only for
  historical "why did we build it this way" questions.
- **Onboarding v2 / v3 / v4 docs** — superseded by v4.5
  (`onboarding_v4_5_conversion_spec_2026_06_11.md`, also archived
  because v4.5 itself shipped).
- **Earlier paywall research v1-v4** — shipped paywall is the result.
- **Earlier Home / Becoming redesign briefs** — shipped. The current
  Home / Becoming code wins over any spec doc.
- **`DESIGN.md` (root-level)** is from 2026-04-22 and is pre-rebrand.
  See section 4 for current design system. Treat the root `DESIGN.md`
  as a pointer; the real source is `Tokens.swift` + `THEME.md` +
  the locked-tokens memory.
- **The earlier `pivot_research_*` and `product_direction_2026.md`
  docs** are the road we didn't take. Useful for context, not for
  current decisions.

---

## 7. Open items at a glance

See `TODOS.md` for the full punch list. Top-of-mind:
- Snap Food manual retry button + photo cache (task #9 deferred)
- v1.2 candidates per the v2 strategy doc (Sprint A trial-conversion
  work, sister-cohort SKU thinking)
- Bundle ID + Xcode project rename (`com.bk.plankAI` →
  `app.jenifit.ios`) when ready to absorb the re-onboard cost
- ElevenLabs voice clip generation pass (cascade in code is wired;
  legacy fallback works)
