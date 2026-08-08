# v23 THE STILL LIFE — THE LOOP's record (first pass, 2026-08-07)

Method per the design law §15: build → install on `QA-iPhone16` →
drive with film doors → record → dump frames (2fps) → inspect →
fix → repeat. Every fix below was CAUGHT ON A FRAME, not imagined.

## The films

- `scan_theater.mp4` — mock plate full-bleed → THE DIAL's trace
  draws from 12 o'clock while the base hairline recedes → the
  circle closes → two REAL chips land with their kcal (jeyuk
  bokkeum 1,400 · steamed rice 234) → paper rises with THE READING.
  One unbroken scene; zero geometry change at the freeze.
- `book_walk.mp4` — the book walks its own spreads (synthesized
  drags can't scroll this sim runtime — the v12 lesson; the
  `--uitest-walk-book` door drives).

## Frame-caught and fixed this pass

1. **The protein floor bar missing on film** — the camera debug
   harness wired no `proteinTargetProvider`/`dayContextProvider`,
   so films showed the card without its floor. The harness now
   carries the reading's real grammar (110g floor · 1,900 target ·
   620 eaten) — the bar, the adequacy word and the gain-frame day
   line all render as in the app.
2. **`1902mg` sodium** — the ledger's sodium value now carries its
   thousands separator ("1,902mg").
3. **The orphaned square** — a day with exactly TWO photographs
   left the second as a lone half-width square (accidental, not
   editorial). A lone companion now runs WIDE (2.6:1) as the
   spread's counterweight to the hero.

## Verified on film

- THE WINDOW: dial idle (circle + 4 cardinal ticks + the founder's
  idle line), barcode morph (wide rect, resting shutter, "center
  the barcode"), label morph (tall panel, live shutter, "fit the
  nutrition label"), mode strip paper-chip selection, library well,
  torch, "or write it", statusbar-hidden immersion.
- THE READING at peek and full: context line · serif name + edit
  pencil · counted 1,635 + ±75 · protein card with floor bar +
  "hits *enough*" · the split · the hairline ledger (sugar intake,
  never sweetness) · "a little *over* today · tomorrow resets"
  (gain-frame, no red) · items with gloss + steppers · retake ·
  **add it** · share.
- THE BOOK: masthead ("your plates" · "27 plates since july") ·
  THIS WEEK read with italic punch ("a *protein-led* week at the
  table.") · day spreads (serif date + once-stated ledger line) ·
  hero 4:3 with caption bar · wide counterweight · two-across grid
  · typographic menu rows with hairlines · month coverage present
  in the seed (the 36-day-old plate).

## Sim-environmental notes (not defects)

- The live feed renders BLACK on this sim runtime (no camera
  hardware); the shutter reads dimmed because `camera.isRunning`
  never goes true. Mock-image paths (`--food-debug-autostart`)
  exercise the full-bleed frame; the live feed needs the device
  walk.
- `simctl privacy grant camera` is ignored on this runtime — the
  `testGrantCameraOnce` primer remains the door (v22 law).

## Verification ledger

- Package: **PlankFoodTests 106/106** via the package scheme
  (`cd Packages/PlankFood && xcodebuild test -scheme PlankFood …`)
  — the FoodTheme palette pins EXECUTED for the first time since
  they were written (S10; the app-scheme test-plan route rejects
  package testables on this xcodebuild — the package scheme is the
  house mechanism now). +5 BarcodeRead mapper pins (per-serving
  precedence, per-100g fallback, sodium g→mg, nil-over-fabrication,
  brand de-dup).
- App target: builds green through every batch.
- App unit suite (`plankAITests`): run recorded in the session
  (see final report).

## Honest deferrals (queued for the next pass)

- **Chip → row flash** (§5.7): tapping a chip on the photograph
  should flash its ledger row. Plumbing designed, not yet wired.
- **The plate page as THE READING in read mode** (§7): the book
  still opens `PlateDetailSheet` (v11.5 grammar — photo, hero,
  ledger, day contribution, delete; now + "log it again"). The
  full component unification is the module-contract detail face's
  next step.
- **The filing choreography** (§6): "add it" currently dismisses on
  the stage's cross-dissolve; the compress-and-file-downward beat
  is not yet drawn.
- **Barcode/label on device**: live VNDetectBarcodes + OFF fetch
  and the label EF hint are wired and unit-pinned but need the
  device walk (sim has no camera; OFF needs network).
- **The book's "+" well**: deferred deliberately — Home is one tab
  away and owns capture (ONE HAND: don't multiply entry points).
- Dial tick gap reads a touch wide on the barcode rect; radius 24
  → consider 16-20 with the founder's eye on device.
- XXXL Dynamic Type floors on the window/reading/book — unwalked
  this pass.
- `--debug-result-carousel` leg (`testSwipeAcrossCarouselSlides`)
  still references the dead carousel — re-anchor or retire with
  the next QA sweep.

## Pass 2 (same day) — the founder's second directive

Closed from the deferral ledger + the new asks:
- **THE PLATE STEPPER** — whole-meal serving adjustment on the
  reading's items header: `− 700g +`. Every item steps its own
  portion grid in one commit, so the coherence contract holds and
  every numeral above counts to follow. The plate's mass is the
  readout (no invented "servings" denominator).
- **THE FILING (§6)** — "add it" now compresses the whole stage
  (0.88 scale, files downward, 0.34s) before the persist +
  dismissal. Reduce Motion skips straight to the handoff.
- **CHIP → ROW** — the understanding chips are TOUCHABLE: a tap
  expands the reading and flashes the item's row blush once. The
  v22 anchor stems retired with it (S5, finally executed).
- **Chrome tune** (frame-caught pass 1): mode chips grew to 44pt
  targets; barcode radius 24→16, label 24→20; tick gap 7→5.
- **The sheet audit**: TerminalErrorSheet (Fraunces-era) and
  GalleryConfirmSheet (polaroid tilt, "scan this") re-skinned to
  the era — serif states it, one ink verb answers ("read it");
  the permission page finally says JENI and opens Settings with a
  paper pill (an action, not an instruction).
- Filmed: the stepper on the expanded reading (sodium now
  "1,902mg"), the gallery confirm. Package 106/106 after all of it.

Still open for the device walk: the filing beat + chip-tap feel in
hand, terminal sheet has no debug fault flag to film, permission
page can't be filmed (this runtime ignores privacy revokes), the
consent/onboarding/QuickAdd sheets remain on the audit list.

## Pass 3 — founder steer: the circle retires

"Get rid of the circle line, make it similar to the Cal AI aim."
Done: THE AIM is four engineered corner brackets (3pt, round caps,
soft square for scan; the wide/tall modes keep the same bracket
grammar; the cardinal ticks retired with the circle). The identity
MOTION survives untouched — the reading closes the FRAME: the
complete outline draws from 12 o'clock over the resting brackets,
holds at 96%, snaps shut when the understanding lands. §2 of the
law carries the amendment. Frame-verified: scan + barcode brackets,
the mid-trace, and the reading landing through the new path.

Loop note: the stale-product gotcha struck again — SnapDial
recompiled but the app linked an old PlankFood library (control
string absent from the debug dylib). The remedy that works: rm
DerivedData's PlankFood.build intermediates + PlankFood.o, rebuild,
verify the control string BEFORE filming.

## Pass 4 — founder steer: the reference processing interface

Three asks, closed:
- **The Lottie retired everywhere** — FoodResultExplosion left the
  capture flow, the onboarding snap demo, its preview harness and
  its debug route; the file and its pbxproj entries deleted. The
  reading's own choreography is the moment.
- **THE PROCESSING** (`SnapProcessingStage`) — the founder's
  reference interface in Jeni's hand: on capture the photograph
  COMPRESSES into a glowing rounded card over its own blurred self,
  the aim's brackets ride the card, one bright line sweeps the
  frame, and a staged checklist speaks the pipeline's real phases
  ("photo kept ✓ → reading what's on it → counting the nutrition →
  putting the page together") — mode-aware wording for barcode and
  label. The active row pulses the dose-dot (never a spinner); the
  FINAL step completes only when the understanding actually lands
  (truth-anchored); intermediate steps advance on conservative
  timers (the retired rotator's honesty class). The toolbar leaves
  the stage during a reading — only the close stays (reference
  behavior). Frame-caught + fixed: the un-blurred photo leaked
  below the safe area (stage now ignores safe areas); the halo
  bloomed as a cloud (tightened to hug the card).
- **The underscores** — `foodNameCleaned` strips snake_case at
  ingest (vision + barcode mapping) and defensively at every
  display site (title, rows, chips, journal), so history logged
  before the fix reads clean too.

Note: the onboarding snap demo still shows the bracket trace, not
the processing card — queued for a demo-alignment pass. Package
106/106 after the pass.

## Pass 5 — founder steers: the sweep completes, the reading goes chart-first

- **THE SWEEP, full-frame + vivid** — the line now runs INSIDE the
  card's own clip, edge to edge (the inset gap read incomplete),
  with a brighter core (2.5pt white, doubled bloom, plusLighter)
  and a soft haptic tap at each edge turn (~0.7/s, stops with the
  reading; Reduce Motion silent).
- **THE READING, chart-driven + few words** — the top half is now
  THE METRIC GRID: 2×2 instrument cells (serif counted numerals,
  caps labels, one shape each) — CALORIES with the day ring ("86%
  of today"; no target → no ring, D2), PROTEIN on its floor bar,
  CARBS and FAT with their share of the plate's energy (an honest
  denominator). The split closes the block; fiber · sugar intake ·
  sodium fold into one quiet three-column row. The meal tag + time
  lead as a chip; the plate stepper moved beside the title (the
  reference's serving position). CUT for the minimal register: the
  confidence word ("close enough"), the adequacy stamp ("hits
  enough" — the berry bar IS the signal), the "on your plate"
  header, and the day line's clauses ("N left today after this" /
  "right at your target today" / "a little over today"); the note's
  header shortened to JENI'S NOTE. Every functionality kept: edit,
  steppers, fraction, refine, share, note, day context. Package
  106/106 after the pass.

## Pass 6 — founder steers (device walk): the language, and the card

- **The evening card retired from Home** — "the day, kept. what's
  left is yours." (the v7-era secondAct card: celebrate row,
  reflect words, tonight plan, breath row). The evening close
  proper — the JeniMoment with the receipt, the feeling word and
  the tonight plan — is untouched and keeps its v21 invitation row;
  the breath stays reachable in TOOLS. The card was a redundant
  second door wearing retired poetry.
- **The note engine rewritten to the clinician register** —
  straightforward, helpful, insightful, number-anchored, mechanism
  over mood, across every branch of `ResultDetailCopy`: day-fit
  ("about a third of your day. plenty of room left."),
  considerations with real mechanisms ("sodium runs high here.
  extra water helps. a scale bump tomorrow would be water, not
  fat"), GLP-1 lines ("protein on a quiet appetite — that's what
  protects muscle while weight comes down"), protein/fat/variety
  notes ("protein at this level blunts later cravings", "fat slows
  digestion — steadier energy, longer fullness", "variety usually
  brings better fiber and micronutrients"), safety-net lines
  ("steady intake protects energy and muscle"), and provenance
  ("estimate: about N, within a range. edit anything that looks
  off"). The anti-shame floors hold: no judgment words, no
  earned-food grammar, gain-frame throughout. Package 106/106.
