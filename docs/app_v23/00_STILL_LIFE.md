# APP v23 — THE STILL LIFE

**Status: THE ERA'S LAW. 2026-08-07.** The founder's brief: forget
today's food module — scanner, result, journal, animations, layouts —
and design the entire food experience again from zero. Architecture
follows design. The quality bar: placed beside the new module, the
old one must feel obsolete within three seconds. References (Cal AI
class marketing frames) demonstrate interaction quality, camera
ergonomics and information density — principles extracted, nothing
copied.

`docs/design/00_JENI_DESIGN_LANGUAGE.md` remains the design law.
`docs/app_v22/00_ONE_HAND.md` remains the propagation law; its §8
BOUND pass (THE IMMERSION) ships inside this era. E2 (honest
theater) and E4-b (precision instruments) carry forward unamended.

---

## 1. The idea — one material story

Every calorie app treats a meal as a database row that briefly had a
photo. Jeni treats it the other way: **the photograph is the thing;
the numbers are its reading.** A still life — food composed, kept,
and understood on paper.

The experience is one continuous material narrative:

| beat | material | what happens |
|---|---|---|
| the window | **glass** — the live world, full-bleed | she composes the plate in THE DIAL |
| the understanding | **light on the photograph** | the dial closes; real items land as chips |
| the reading | **paper rises** | the page composes itself under the photograph |
| the filing | **the card** | the reading compresses into a journal card |
| the book | **paper** | her days, plates leading, read like a magazine |

The camera is the ONLY non-paper surface in the product — earned,
because it is a window, not a page. Everything after capture lives
on paper. The transition between the two materials (paper rising
under the frozen photograph) is the signature beat of the era.

Register: the camera and the reading are INSTRUMENTS (visual-first,
§1.1b); the book leans editorial (it is her record). Jeni's note
stays serif — the one voice.

---

## 2. THE DIAL — the identity element

> **AMENDED — founder steer, pass 3.** The circle retired ("get rid
> of the circle line, make it similar to the Cal AI aim"): the aim
> is now FOUR CORNER BRACKETS (soft square for scan; the wide and
> tall rects keep the same bracket grammar), engineered, 3pt,
> round-capped, no ticks. THE IDENTITY MOTION SURVIVES UNCHANGED:
> the reading still closes the frame — the complete outline draws
> from 12 o'clock over the resting brackets, holds at 96%, and
> accelerates shut when the understanding lands. Everything below
> about the trace, the morph, the honesty note and Reduce Motion
> still binds; the circle-specific geometry does not.

The founder's requirement: a precise, clean, minimal, editorial
targeting frame — Apple Vision / Halide class, never a doodle — that
becomes part of Jeni's identity.

Every scanner app draws four corner brackets. Jeni draws **a plate**:

- **Geometry.** One hairline circle (1pt, paper-white 0.92), diameter
  ≈ 78% of screen width, centered at ~42% of screen height. Four
  2pt × 10pt radial ticks sit just outside the rim at N·E·S·W — an
  instrument face, minute-marks on a dial. Nothing inside the circle,
  ever. No crosshair, no grid, no reticle.
- **Why it is Jeni.** Home's hero is the ring with the counted
  numeral inside; the shutter is a ring; the plate is round. The dial
  closes the loop: she composes the meal in the ring, and the same
  ring on Home fills with what it became. The instrument grammar
  (§1.2b) extended to the lens.
- **The reading closes the circle.** On capture the circle's stroke
  redraws itself from 12 o'clock — `JeniMotion.draw` pacing, ~2.4s to
  ~96%, where it HOLDS with a quiet breath until the understanding
  lands, then accelerates closed with a `land()` haptic. Causality,
  not a spinner: the circle completes because the reading did.
  Honest: the hold at 96% is visible tension, never a fake loop.
- **Mode morphs.** The dial is ONE shape that morphs
  (`JeniMotion.morph`, a `tick()` per switch):
  - **scan** — the circle.
  - **barcode** — a wide hairline rounded-rect (~2.4:1), ticks at the
    corners' outside. Detection is LIVE (no shutter): the rect
    settles + `land()` the moment a barcode resolves.
  - **label** — a tall hairline rounded-rect (~3:4): "fit the panel."
- **Honesty note.** The dial is composition guidance, not a crop —
  the full frame is captured and sent, exactly like every camera
  app's brackets. Reduce Motion: no trace; the caption line alone
  carries the wait.
- The v22.3 corner brackets (`SnapJeniFrame`), the Metal sweep
  (`SnapShaders.metal` + `SnapSweepOverlay` + the prewarm contract)
  and the paper-surround camera layout all retire. One identity
  element instead of three systems.

---

## 3. The window — the camera, full-bleed

v22 §8's IMMERSION, executed: the feed fills the screen
edge-to-edge; the scene NEVER cuts from first open to the reading.

```
┌─────────────────────────────┐
│ ⓧ                           │  close — glass circle, top-left
│                             │
│          ╭──╮  ← tick       │
│        ╱      ╲             │
│       │  DIAL  │            │  the hairline plate, cy ≈ 0.42h
│        ╲      ╱             │
│          ╰──╯               │
│      add it before you eat  │  caption — plain, lowercase
│                             │
│      or write it            │  quiet text door → describe
│   ┌ scan · barcode · label ┐│  mode strip — one glass capsule
│  ┌──┐      ┌────┐      (☼) │  library well · SHUTTER · torch
│  └──┘      └────┘          │
└─────────────────────────────┘
```

- **Chrome floats on glass** (§13: ultraThinMaterial floor,
  availability-gated glass) — close, mode strip, library well,
  torch. Nothing owns a paper surface here.
- **The capture bar** (one coherent component, one-hand law):
  - **library well** (bottom-left, 44pt rounded-rect): her last
    plate's photo as the fill — a live instrument in the
    `JeniToolTile` sense; opens the photo picker. Empty state: quiet
    glass with a pictures glyph.
  - **THE SHUTTER** (center): the v22 ring grammar survives — 78pt
    rose ring, white disc, no rotation ever; press = 0.94 + flash
    bloom.
  - **torch** (bottom-right, 44pt glass circle): dark-restaurant
    reach. Disabled state at 0.4.
  - **mode strip** directly above: three words in one glass capsule
    — scan · barcode · label. Selected = paper-filled chip, ink
    text; unselected = quiet on glass. The dial morphs on switch.
- **Captions** are plain and lowercase (E3), white on the feed with
  a soft shadow, never a scrim band: idle = the founder's line "add
  it before you eat"; scanning = "reading your plate…" → "checking
  portions…" → 15s honesty line. Barcode idle = "center the
  barcode"; label idle = "fit the nutrition label".
- **"or write it"** — the single quiet text door above the strip;
  opens the describe sheet (QuickAdd). "again" LEAVES the camera:
  relog lives in the book and the plate page, where history actually
  is.
- **Zoom**: pinch only; the existing indicator pill.
- **Permission denied**: the existing paper placeholder page.
- Consent + first-scan onboarding sheets are unchanged in flow,
  re-skinned to current tokens.

---

## 4. The understanding

The beat map after the shutter (the scene never cuts):

1. **Freeze in place.** The frozen frame replaces the live feed
   full-bleed — zero geometry change (v22 §8's requirement). Flash
   bloom + shutter sound + the held medium impact, all existing.
2. **The circle closes** (§2) while captions rotate. The Live
   Activity rides along (engine untouched).
3. **The chips land.** The dial fades as the understanding replaces
   it: up to four REAL result items (E2 — never invented) land as
   paper chips clustered around the meal region, staggered 0.14s,
   spring (0.5 / 0.72), one rate-limited `tick()` each, each with
   the v22 discovery bloom (a single fading berry ring). Chip
   anatomy: white 0.94 capsule · item name DMSans-Medium 13 ink ·
   kcal DMSans-SemiBold 12 berry. **The anchor stems retire** — a
   stem claims pointing precision the EF does not provide; the
   cluster attaches to the meal, honestly.
4. **Paper rises.** The reading sheet (§5) rises to its peek detent
   with `JeniMotion.settle`; the photograph keeps the top of the
   screen, chips still on it. Glass → understanding → page, one
   unbroken scene.

Failure stays absorbed in-surface (§5.6): the gentle failure card
over the kept photo, the terminal sheet for caps — both re-skinned,
neither redesigned.

---

## 5. The reading — one page, two detents

The 3-slide carousel dies. One page in reading order, on a
two-detent sheet (peek ≈ 0.56h · full; the v19 physics — grabber
drag, velocity settle, detent tick). The photo stays the hero above;
at full detent it remains a visible band (~0.22h) — never fully
buried.

Reading order on the paper:

1. **The context line** — eyebrow register: `BREAKFAST · 9:41`.
2. **The name** — the plate's title, serif 26, lowercase, plain (a
   reading, not a punch).
3. **THE NUMERAL** — the counted kcal hero (existing CountUpNumber,
   54pt serif) + "calories" + the ± band (uncertainty is honesty) +
   the day line beneath (gain-frame: "room for 620 more today").
4. **PROTEIN** — the one nutrient with a collected floor: full-width
   card — grams numeral 22pt serif, the floor bar (berry at a met
   floor), the adequacy word. (v22.3's grammar, re-proportioned.)
5. **THE SPLIT** — one segmented bar: what the plate's energy was
   made of (berry protein · dusty carbs · blush fat). N shapes = N
   questions; the macros are one relationship.
6. **THE LEDGER** — carbs · fat · fiber · sugar · sodium as a
   hairline ledger (ledgers may rule lines): label left DMSans 13
   secondary, value right DMSans-SemiBold 15 ink. No bars — no
   collected denominator (D2). Uncollected fields stay silent.
7. **THE ITEMS** — the editable ledger: each item a row (name ·
   portion words · kcal) with the ± portion stepper; tap → the
   ingredient editor sheet; swipe = remove. Tapping a chip on the
   photograph flashes its row. Below: "add something" and "fix it
   with words" (the refine seam survives — it is a moat).
8. **THE FRACTION** — "all of it · about ¾ · about half · a few
   bites" (honest portions, kept).
9. **WHAT JENI NOTICED** — the note comes home to the page: eyebrow
   → two-to-three serif lines with the italic punch → the provenance
   whisper. Arrives at the full detent, staged.
10. **THE FOOTER** (docked): `retake` quiet text · **"add it"** — THE
    ink pill (the verb of the era; the idle caption taught it) ·
    `share` circle → the share composer sheet (renderer untouched).

**One grammar, every source (S3).** The same page renders a photo
result, a barcode product, a label reading, and a described meal —
without a photograph the hero band is paper and typography. The
`Result/` card subtree (SingleDishCard, MixedPlateCard, the atoms)
retires with it: one reading, not two result systems.

**No scores.** The reference's "health score 7/10" is Cal AI's
voice. Jeni does not grade food (anti-shame law); the reading states
what is, the floor bar shows the one honest target, the day line
gives room in gain-frame.

---

## 6. The filing

"add it" → `land()` → the page and photograph compress together
(scale to ~0.9, corner radius to card 22) and file downward off the
stage (0.32s) → dismiss. Home's existing plate-landing morph (the
numeral rolls forward) receives it. The evening close and weekly
engines are untouched.

---

## 7. The book — the journal as a magazine

`FoodJournalView`'s database list dies. The book:

- **Masthead**: "your plates" serif + one quiet count line ("214
  plates since june").
- **A day is a spread.** Serif date head ("thursday, august 7",
  20pt lowercase) + the day's ledger line stated once, never graded
  ("1,840 kcal · 96g protein"). Beneath, the day's plates as
  PHOTOGRAPHS:
  - 1 plate → one full-width photo card (4:3, caption bar: title
    serif 17 + kcal right).
  - 2 plates → two-across squares.
  - 3+ → the newest full-width, the rest two-across beneath.
  - photo-less meals (described · barcode) → a typographic menu
    row: serif title · kcal, on paper. Photos lead; type carries
    what has no photograph.
- **Rhythm**: `sectionGap` between days; a small-caps month seam
  (`JULY`) at month boundaries; lazy, newest first.
- **The weekly read as a seam.** Between weeks, when `FoodWeekRead`
  floors are met, its one-sentence band read sits as a quiet seam
  row ("protein led the week"). No card, no score — a reading
  between chapters.
- **A plate opens as the reading.** Tap → the same §5 page in
  read mode (photo hero band + the reading; edits = delete +
  "log it again"). `PlateDetailSheet`'s separate layout retires —
  the module's detail face and result face are ONE grammar.
- **"again" lives here**: context menu on any card + the row inside
  the plate page. The camera stays pure.
- Doors: Becoming's "your plates" row (unchanged) · Home's food
  surfaces (unchanged) · a floating "+" well in the book opens the
  camera.

---

## 8. The modes — barcode + label, honestly

- **Barcode** (new capability): `VNDetectBarcodesRequest` runs on
  frames the camera manager ALREADY captures (the video data output
  exists for the freeze frame). On resolve: `land()`, fetch
  OpenFoodFacts `product/{code}` (client gains the by-code call),
  map to `CapturedFood` (per-serving preferred, per-100g fallback —
  provenance tagged), rise straight into the reading. Not found →
  the caption absorbs it: "couldn't find this barcode · try the
  label" + the dial morphs to label mode. No invented nutrition,
  ever.
- **Label** (new capability): shutter capture routed to the EXISTING
  vision EF with a trusted-context line riding the `text` field
  ("this photograph is a nutrition facts panel — read it as
  printed"). Zero EF deploy; the schema already returns items.
  Serving-count edits ride the same stepper.
- **Scan** and **describe** ride the existing EF paths untouched.

---

## 9. The motion map

| transition | treatment |
|---|---|
| camera open | chrome arrives on `jeniArrive` indices over the live feed; the dial draws in once (0.6s), ticks settle |
| mode switch | the dial MORPHS (`JeniMotion.morph`) + `tick()`; captions crossfade |
| capture | freeze in place (zero geometry) + bloom; the circle closes (§2) |
| understanding | chips land staggered springs + blooms; dial fades |
| paper rises | `JeniMotion.settle` to peek detent |
| detents | v19 physics; `tick()` per crossing |
| chip → row | the row flashes blush once (0.6s fade) |
| edits | numerals COUNT to new values (never swap); bars morph |
| filing | compress + file downward (0.32s) + `land()` |
| book browse | day spreads arrive staggered on first visibility |
| card → reading | in-tree morph into the detented page (§4.4 rank 1); the photograph is the shared element |
| Reduce Motion | no trace, no blooms, whole fades; nothing lost but motion |

---

## 10. Decision ledger

| # | decision | why |
|---|---|---|
| S1 | THE DIAL replaces brackets + sweep + rose border lineage | one identity element; the ring is already Jeni's signature shape; E4-b precision holds |
| S2 | the reading closes the circle; hold at ~96% until the EF lands | causality over spinner; honest tension, no fake progress |
| S3 | ONE reading grammar for photo · barcode · label · described · journal detail | kills the second result system (~2,300 LOC); the module contract's faces converge |
| S4 | the carousel dies; jeni's note joins the page at full detent | one idea per screen was being spent on navigation, not content |
| S5 | chips lose their stems | a stem claims per-ingredient pointing the EF doesn't provide; E2 |
| S6 | "again" leaves the camera for the book; "or write it" is the camera's one text door | the camera is a window, not a menu; history lives where history is |
| S7 | barcode = live VN detect + OFF by-code; label = EF text-hint; zero EF deploy | real capability without fabrication; graceful barcode→label fallback |
| S8 | no health score, no grades, ledger over stat-card grid | anti-shame law; E4 stands — Cal AI's stat cards are its voice, not ours |
| S9 | the journal becomes THE BOOK (day spreads, photos lead, weekly seams) | the record is the product's memory; a database list wastes her photographs |
| S10 | PlankFoodTests joins the scheme; palette pins finally run | the v22 drift went unseen because the pins never ran |
| S11 | confirmed-dead code dies with the era (CohortCatalog, ResultInsights, bento/intro tiles, WeeklyShareCard line, MacroRow, WeeklyAvgBar, HerShareLabel, ImOut line, SwiftData trio) | forgetting the old module includes its orphans |

## 11. What survives (engines) / what dies (presentation)

**Survives untouched:** `FoodVisionService` + EF wire ·
`FoodCaptureDispatcher` enrich/calibration · `PlateEditSession`
(the coherence contract + its 15 pins) · `FoodLogPersister` JSONL +
payload ledger · `FoodPhotoStore`/`FoodPhotoSyncService` ·
`ScanDeadline` · `FoodCameraManager`'s continuation funnel (gains
a barcode tap on the existing video output) · Live Activity ·
analytics (gains mode events) · flags · consent flow · Home/
Becoming/evening/weekly integrations.

**Dies:** the paper-surround camera layout · `SnapJeniFrame` ·
`SnapSweepOverlay` + `SnapShaders.metal` · `ScanningOverlay` ·
the `SnapResultView` carousel · the `Result/` subtree ·
`PlateDetailSheet`'s bespoke layout · `FoodJournalView`'s list ·
the S11 dead-code inventory.

## 12. The QA plan

- Scheme: `PlankFoodTests` testable (S10) — 114 units join the run.
- New units: barcode→`CapturedFood` mapping · OFF product decode ·
  mode routing · book day-grouping.
- Doors: `--debug-snap-camera` (kept) · `--debug-plate-read`
  (mock reading page) · `--uitest-open-food-journal` (kept, now the
  book) · `--food-debug-success` family (kept).
- Films for THE LOOP: the window (idle + mode morphs) · capture →
  circle closes → chips → paper rises · the reading detents + an
  edit · the filing · the book scroll + card→reading morph.
- Legs: `testGrantCameraOnce` primer · surface inventory re-anchored
  to the book · walkers must stay green.
