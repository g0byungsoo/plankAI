# 59 · THE HOME DESIGN PASS

**feat/app-v2 · 2026-08-25 · after 58.** The founder's brief: take
Home to the level of a top-tier human iOS design team — premium,
minimal, warm, editorial, calm, tactile, unmistakably intentional.
"This is my day," not "this is my health dashboard." Prior visual
decisions explicitly NOT settled; record correctness explicitly
preserved. Two references studied as files: the day-1 plan mock (the
FEELING — whitespace, imagery, tactile completion, visual confidence)
and a Cal AI redesign (the HIERARCHY — remainder-first, recently-eaten
as objects, one hero).

## 1 · what the references actually taught

**Reference 1** (the day-plan mock): the page has one figure-ground
rhythm — identity (an italic-serif "day 1"), progress, then the day as
a SHORT stack of big soft objects with real imagery and a dark stamp
check. Nothing else. Its warmth is photography in rounded seats; its
confidence is scale and restraint.

**Cal AI** (research agent, current 2026 product + teardowns): the
hero is the REMAINDER ("1,464 Calories left") because the user's real
question is "can I eat this" and she does not want to subtract;
secondary metrics live behind a swipe (progressive disclosure);
recently-eaten is photo-led cards; the empty state is a full wallet,
never a blank; the day always names one next verb. Its most-quoted
failure is trust (corrections that don't propagate) — which Jeni's
record architecture already solves.

**ADA-caliber "today" screens** (Gentler Streak et al): lead with an
interpreted state, not a scoreboard; absence is never failure;
personal = built from her own record, not tile density.

## 2 · what was wrong with the shipped Home (by looking, not prose)

Filmed the live p58 Home first (`59_evidence/before_home.png`):

1. **The band was a chart, not a state.** A 116pt thick-stroked berry
   ring parked in the page's left corner, the interpreted state ("17 g
   to the floor") demoted to a caption floating in its leftover space,
   then a spreadsheet row (`the day  1,660 of 1,596 kcal`) and a
   debug-ish chemistry line.
2. **Her record was invisible.** No plate appeared anywhere on Home at
   rest — the product's central act, reduced to arithmetic.
3. **Three chip species in one list** (blush fill, dashed wireframe,
   ink disc); dashed read as a placeholder, not an invitation.
4. **The dose standing floated** — two bare text lines between two
   strong shapes.
5. **The tools grid was the noisiest block for the quietest job**:
   uneven tiles, a hole in the grid, wrapping statuses, three
   instrument species (a jagged EKG-like sparkline among them).
6. **The masthead's "day 12" pink capsule** read as furniture bolted
   onto an editorial greeting.

## 3 · the exploration (decided by looking, the p58 §8 method widened)

`--debug-home-redesign [-2|-3]` mounts the harness (committed,
`59_evidence/harness_concepts.png`): the food block four materially
different ways (shipped control · THE RECEIPT, words lead with a
thread gauge · THE INSTRUMENT, compact ring · THE PLATE LEDGER,
record leads), the rows old vs grown, the dose line vs a clinical
object, the capsule vs a set dateline. Looking decided: words beat
the lonely ring; the grown rows beat the small ones; the bordered
clinical object beats the floating pair; the dateline beats the
capsule. THE RECEIPT shipped first — then the founder steered.

## 4 · the founder's steers, taken mid-pass (three, in order)

1. **"The big pie chart is the default nutrition view (with
   carousels); to-do list stays; calorie/protein/macro info
   compacted."** The ring returned as THE DIAL — what was wrong was
   never the ring but its scale, stroke, and corner. The steer's own
   reference (our steps dial) showed the fix: big, centered, serif
   numeral inside, italic caption below.
2. **Screenshot steer** — the steps-dial reference confirmed the
   composition grammar.
3. **"Cal AI's 'left' UX is right; thicker smaller donut; too many
   texts — visualize minimally, keep the big chart the main
   visualization."** The remainder moved INSIDE the dial; the words
   under it compressed to ONE stat; the chemistry left face 1
   entirely.

## 5 · what shipped

**THE MASTHEAD.** The greeting keeps its two-tone serif; beneath it
the program position is SET as a dateline — `DAY 12` in tracked
Fraunces caps · a 22pt hairline rule · the week's own word in the
serif italic (`the floor first`). Same doors as the old chip (tap =
letter, hold = settings, same spoken label). Chrome typography: caps
at XXXL like the strip beneath (AX5 frame-caught truncation,
`59_evidence/after_se_ax5_dateline.png` is the fix).

**THE DOSE OBJECT.** The standing is a hairline-bordered row in the
clinical register — ink seat, SF glyph (`cross.vial` / `pills`), no
rose, no celebration — anchored instead of floating. Same taps, same
identifiers, same VoiceOver.

**THE DIAL (HomeNutritionSummary v3).** A three-face carousel; the
faces exist only when the record earns them, and each answer lives in
exactly one place (E9's redundancy argument, honored by
construction):

- **face 1 · THE DAY** — a 156pt, 15pt-stroke centered ring (the rose
  ramp, dusty→berry; whole berry at met). The lead metric follows the
  §9 law: protein iff a floor exists, else calories. INSIDE the ring:
  what is LEFT (`58 · g to the floor`, counting down as plates land
  via `JeniCountingNumeral`); at met, the strip's own drawn check +
  `floor met` (`59_evidence/after_home_floor_met.png`). Below: ONE
  stat — the kcal remainder in serif (`556 kcal left`) over its
  provenance pair (`1,040 of 1,596 kcal`). The remainder word comes
  from the pinned `energyRemainderWord` — count-up cohorts past
  target render the plain pair with no word, maintenance renders
  `· holding`, and only collected targets ever speak "left" (no
  invented denominators — sugar/carbs/fat have none, so they get
  none).
- **face 2 · THE PLATES** — the day's eaten record as a 2×2 gallery
  (`59_evidence/after_plates_face.png`): photographs where they
  exist; a typed plate seats the dish's own initial in serif italic
  (her latte is "l", never a repeated button); `4 plates, counted.`
  in the caption grammar. The page's only photography, and it is
  hers.
- **face 3 · THE NUMBERS** — the rest facts as a set table (label
  left, serif amount right, hairlines; same pinned order and
  drop-when-unmeasured law) — Cal AI's own progressive-disclosure
  pattern (`59_evidence/after_numbers_face.png`).

Page dots render only when a second face exists. The stage takes the
day face's measured height via an invisible twin (E8.2's law — a
page-style TabView never sizes to its pages). Accessibility sizes
keep a words-and-thread receipt (a ring cannot hold its numeral at
AX — §10.2, filmed twice; `JeniFloorThread` is the AX shape: a 3pt
rose-ramp thread with the floor tick at 82%, so landing past it stays
visible). Suppression keeps the words-only face — and may keep the
plates, because photographs are not numerals
(`59_evidence/after_suppressed.png`). The fresh day is a full wallet:
the empty blush dial, `140 · g to the floor`, nothing zeroed
(`59_evidence/after_fresh_day.png`).

**THE DAY OBJECTS (JeniTaskRow).** 52pt identity seats (radius
follows size — 13 was drawn for 40pt), 16.5pt reading-weight titles,
the 26pt ink stamp; done compresses to a 28pt receipt that carries
the plate's own photograph. The offered seat is a SOLID hairline now
— the dash read as wireframe, not invitation (harness-decided).

**THE TOOLS INDEX.** The tile grid became five hairline rows — a bare
doodle, the word, the state right-aligned (stacking at AX). The live
instruments went where their facts now live: the plates into face 2,
the weight distance into its own status words, the steps into the
plan row. `JeniToolTile` deleted with its job (dead-code law).

## 6 · rejected on the way

- **The receipt as the default face** (words lead, no ring) — built,
  filmed, superseded by the founder's dial steer; it SURVIVES as the
  accessibility layout, which is why the AX branch reads as a design
  rather than a fallback.
- **The compact-ring concept (C)** — the 58pt ring double-stated its
  own numeral; redundancy by construction.
- **The plate ledger leading face 1** — the interpretation is the
  answer; the record is the evidence; evidence second.
- **A remainder for carbs/fat/fiber/sugar/sodium** — no collected
  target, no denominator, no "left" (D2: a bar with an invented
  target is a lying chart). The founder's "sugar left" ask is served
  the honest way: the numbers face states amounts.
- **Dashed invitation seats, the pink day capsule, the tile grid** —
  all replaced above.

## 7 · interaction + motion notes

- The dial traces in on the elastic spring (JeniRing's grammar), and
  MORPHS on a landed plate: the inside numeral counts down and the
  kcal stat digit-morphs (`.numericText`), filmed via
  `--uitest-land-plate` (frame montage in the working set; addition,
  never a reset).
- Face swipes are scrolling — no haptic (the strip's law). Quick-mark
  keeps `land()`, plate landings keep `swell()`, the dose sheet keeps
  `record()` — §8 vocabulary untouched.
- The strip walk (D13 directional recap) re-filmed green over the new
  masthead.
- New film door: `--uitest-band-face N` (synthesized drags cannot
  swipe this sim's pagers — the recorded limitation).

## 8 · laws verified standing

Protein leads iff a floor exists (`HomeHierarchyTests`); the energy
sentence's remainder word, count-up silence, `· holding`, and
no-dangling-separator (`DailyUtilityTests`); the rest line's order,
drops and NBSP joins (`HomeRestLineTests`); the widget's shared
grammar (`WidgetSnapshotTests`); the auto-present arbiter
(`HomeAutoPresentTests`). All green at every checkpoint. Home's
anatomy order (greeting → strip → dose → FOOD → TODAY → TOOLS →
evening row) unchanged; presentation chokepoint untouched (no new
presenters); `@Model` zero-diff; no migration; no production
mutation; NOT archived, NOT uploaded, NOT submitted.

## 9 · evidence

`59_evidence/`: before_home · after_home_midday ·
after_home_floor_met · after_plates_face · after_numbers_face ·
after_fresh_day · after_suppressed · after_se_ax5_dateline ·
after_tools_index · harness_concepts · final_sidebyside (Jeni
between both references). Films (working set): land-plate morph,
strip walk, launch crossfade.

## 10 · the final test, answered

Against both references (`final_sidebyside.png`): the dial holds the
page the way the reference's cards hold theirs; today is readable in
one pass (day · shot · floor · kcal · plan · next act); food is part
of today (her plates one swipe away, her last plate riding the done
row); personal without clutter (her name, her week's word, her
initials on her typed plates); premium without decoration (one shape,
serif, hairlines, paper). The reference's warmth is stock
photography; Jeni's is her own record — the more honest answer, and
the one that compounds.

**Named, not done:** the bottom paper fade under the floating tab bar
is weaker than the top scrim (pre-existing chrome, most visible on
SE); the past-day recap card still wears the older card grammar; the
QA seeder's violet plate hue still shouts louder than anything the
product would draw (the p25 stand-in law, again).
