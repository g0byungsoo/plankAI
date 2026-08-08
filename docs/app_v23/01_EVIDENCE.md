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
