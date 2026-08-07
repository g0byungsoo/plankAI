# APP v21 — THE INSTRUMENT

**Status: THE ERA'S LAW. 2026-08-07. The founder's product-redesign
brief, executed.** This document amends
`docs/design/00_JENI_DESIGN_LANGUAGE.md` — where the two disagree,
this one wins on the in-app surfaces (Home, Becoming, details,
tools). The onboarding remains the consult and is untouched.

---

## 1. The brief, distilled

The founder stopped the refinement line (v13-v20) and ordered a
redesign: *"This is NOT another refinement pass. The app must
communicate visually first. Words second. Numbers first. Charts
first. Shapes first. The page should still make sense if every
paragraph disappeared."*

The product identity: the most premium weight-loss companion built
for women. Beautiful · alive · personal · optimistic · scientific ·
native · expensive · minimal · delightful, never childish. The
design itself becomes a competitive advantage.

What is KEPT by explicit instruction: Home's four-block anatomy
(calendar strip → nutrition dashboard → today's checklist → tools),
and nothing else on Home. Urgency is a full-screen interruption,
never an inserted card.

## 2. The diagnosis (why v20 wasn't it)

Eight refinement eras kept making the typography better and the
page quieter, and the founder's critique survived all eight: *too
much typography, too much empty paper, too editorial, not enough
application.* The baseline frames (01_EVIDENCE.md) show why:

- **The shapes are timid.** The calorie ring is 40pt in the corner;
  the bars are 3pt hairlines; the macro split is a 5pt whisper. The
  squint test technically passes and emotionally fails — the
  instruments read as footnotes to the type.
- **The page is colorless.** Every mark is ink. Ink-on-cream reads
  as a beautifully set BOOK — and a book is exactly what the founder
  said this is not. The founder's own loved demos (the steps ring,
  the day-1 checklist) are rose-forward.
- **The cards are containers, not objects.** Nothing invites the
  finger. Rows are typeset lines; tools are labeled boxes; nothing
  visibly wants to be touched.

The three fixes that ARE this era: **colour returns as the data
language** (one hue, three depths — §4), **scale returns to the
shapes** (heroes, not footnotes — §5), and **life returns to the
surfaces** (physics, morphs, counting, drawing — §8). Same honest
bones: every number still traces to a collected field.

## 3. The reference teardown (why they work — principles, not copies)

| reference | what actually works | the principle we take |
|---|---|---|
| old jeni demo — steps ring | one huge two-tone rose ring, serif numeral inside, week bars beneath in the same hue | ONE metric owns the screen; the numeral lives INSIDE its shape; one hue at two depths says "done vs left" without a legend |
| old jeni demo — day 1 checklist | fat rounded rows, photo/symbol chip left, check disc right, 2-3 words | a task is an OBJECT with a face, not a sentence; the chip gives the eye a handle before a word is read |
| Cal AI home | numbers first (2583 huge), a card per macro with its own tiny ring, calendar strip bare | per-metric cards with per-metric shapes scan in under 2s; density through repetition of ONE card grammar |
| MyFitnessPal home | calories card → macros card → diary; progress bars everywhere | the IA is right (we already keep it); bars-with-targets is the fastest read there is — but colour-per-macro is noise we refuse |
| Lovi home | soft ~28pt rounded rows, leading state disc, day chips, one accent | rows at ~64pt with real corner radius read as touchable product; friendliness comes from geometry, not emoji |
| activity dashboard concept | 2-col mosaic, monochrome + one accent, every card = label + number + mini-viz | the card grammar: LABEL · VALUE · SHAPE. Mixed card sizes make a dashboard read as composed, not tabular |
| Apple Fitness / Health | rings as identity; charts draw; detail sheets stage in | motion is the brand; a chart that draws itself is felt as alive; detail = headline → number → chart → words |

**Do-not-copy line.** No flame streaks, no blue links, no gradient
skies, no mascots, no colour-per-nutrient, no rainbow charts. Jeni's
version of "visual" is: serif numerals, drawn shapes, one rose.

## 4. THE ROSE RAMP — colour becomes the data language

The palette's six words (founder): cream white · deep black · warm
white · dusty rose · soft blush pink · muted berry. They were
already half-installed. What changes: **rose stops being an accent
and becomes the DATA hue.** Ink keeps words, numerals and selection;
rose carries everything DRAWN.

| token | value | role |
|---|---|---|
| `Palette.roseBerry` | `#9E4A5F` | emphasis: today's bar, the ring's arriving end, the now-dot |
| `Palette.accent` (dusty rose) | `#C4677A` | the fill: ring arcs, landed bars, spark marks |
| `Palette.roseBlush` | `#E7B3BE` | the rest: receded week bars, secondary marks |
| `Palette.accentSubtle` (blush wash) | `#F5D5D8` | seats and chips: icon chips at rest, ring tracks ride accent at 14% |

**The one-colour law survives** because this is one COLOUR at three
depths — hue never varies, so a screen still reads as ink + paper +
one rose. The bans survive intact: no red, no green, no
colour-coded state, no colour carrying meaning alone (§10.8). Depth
on the ramp means *emphasis* (now vs rest), never *judgment* (good
vs bad) — anti-shame holds by construction.

**Where ink, where rose (the teachable line):**
- **Quantities fill rose.** Rings, day bars, week bars, spark rows,
  split segments — anything that answers "how much".
- **Trajectories draw ink.** The weight line, any line whose story
  is direction. Its wash warms to blush; its now-dot lands berry.
- **Selection is ink.** The strip's disc, the scope capsule, checks.
  Choosing is a statement, not a datum.

## 5. The card language (Jeni's, nobody else's)

The v20 material stands (white fill on `#F5F3EF` paper, NO border,
one 4% contact shadow) — that surface simply gains a grammar:

```
┌──────────────────────────┐
│ LABEL (10pt caps, cocoa) │   one insight
│ 42 serif numeral + unit  │   one shape
│ [the shape, rose]        │   one door (the card IS the tap)
└──────────────────────────┘
```

- Radius 22 (cards) / 18 (rows) / 13 (chips), continuous corners.
- A card leads with its VALUE, never its label's font.
- Every card is pressable (`JeniPressable`) and opens its detail —
  which keeps v15's law true: elevation still means actionability,
  because in a dashboard every panel is a door.
- One shape per card. A second shape means a second card.
- A sentence inside a card is a 13pt caption, one line, optional.

## 6. HOME — the four blocks, rebuilt

**Header (chrome, not a block):** one line — greeting serif 21
("afternoon, *maya*.") · spacer · "day 12" chip (blush seat, ink
text; door to the letter) · settings glyph. The trend sub-line
leaves Home (it is Becoming's opening read). ~44pt where v20 spent
~110.

**6.1 The calendar strip** stays structurally; interaction matures:
selection disc morphs (kept), tick on select (kept), plus the
selected cell breathes a 1.06 pulse on landing, and paging keeps
its page (no snap-back surprise). Kept-day rings warm: berry ring
instead of ink 55%.

**6.2 The nutrition dashboard — THE HERO CAROUSEL.** The single
biggest change on Home. A paged, morphing carousel of hero cards,
~240pt tall, one insight per page:

1. **calories** — the demo's move, finally at demo scale: a 172pt
   ring (blush track, dusty→berry angular fill, rounded caps,
   elastic trace-in) with the counted serif numeral INSIDE ("860" ·
   "of 1,473"), and the remaining figure beside it. Tap → food.
2. **macros** — three horizontal bars: protein vs its floor (the
   only collected target — berry fill, tick at the floor), carbs
   and fat as grams with their share of the day's split (dusty /
   blush). Bars land staggered, values count.
3. **the chemistry** — fiber · sugar intake · sodium, each a row:
   label, counted value, its own 7-day blush spark. Only collected
   fields render; the page is absent until one exists.
4. **the week** — seven rounded bars (m→s, blush; today berry),
   average beneath. The demo's second card, grown up.

Mechanics: `.scrollTargetBehavior(.paging)`, off-center pages settle
at 0.94 scale / 0.85 opacity (`scrollTransition`), a tick per page
detent, custom dots (blush at rest, the current page a berry pill),
pages arm their shapes on first centering (visibility gate). The
safety gate (numericsSuppressed) collapses the carousel to the
words-only face — no numerals anywhere, unchanged behavior.

**6.3 The checklist — tasks become objects.** Rows at ~64pt in
white cards (radius 18), 7pt apart:

- **Leading: the identity chip.** 40pt rounded-square (13pt radius),
  blush seat, berry SF Symbol. The food row's chip carries the LAST
  PLATE'S PHOTO when one exists — real data as imagery, the only
  photography on Home. Offered rows keep a dashed seat on bare
  paper (the sunken law).
- **Middle:** title 15pt SemiBold/Medium + note 11.5pt (one line).
- **Trailing: the drawn check** (quick-mark; row tap opens the
  module; long-press = mark sheet — all three affordances kept).
- **Completion choreography:** the check draws, the chip pulses
  1→1.06→1, `land()`, then the row COMPRESSES to a 44pt receipt
  (chip 40→24, note fades, title dims) on `JeniMotion.settle`. The
  section count chip morphs. All done → one silk sweep (exists),
  once.
- The evening's "close the day" is a checklist row (moon chip,
  berry-tinted), not a separate surface — Home keeps four blocks.

**6.4 Tools — destinations with instruments.** 2-col grid of ~92pt
cards. Left: word + state line (kept, they're honest). Right: a
live mini-instrument, provenance-true per tool: snap → the last
plate's photo chip (else camera in a blush chip) · weigh in → a
7-point ink micro-sparkline · body check-in → figure glyph chip ·
the method → book chip + "day N" · breathe → two breathing blush
circles · move → a 34pt rose mini-ring at today's step fraction.

**6.5 What leaves Home** (the founder's "nothing else"): the trend
sub-line (→ Becoming), the directional recap card for past days
slims to the same card grammar, the chain-suggestion row renders in
checklist grammar inside TODAY, the second act rows join the
checklist section, `EveningJournalLine` dies (the close carries the
journal), and the greeting's second line dies. The break card and
care leads stay — they are states of the blocks, not extra blocks.

## 7. BECOMING — the life dashboard

The page answers "how am I becoming healthier?" with almost no
paragraphs. Order:

1. **Masthead:** "becoming" serif + date, tighter (32pt).
2. **The scope bar** rides directly under the masthead — it governs
   everything beneath (morph, never reload — kept).
3. **THE BODY CARD** (hero, full-width): weight numeral + delta
   line + the ink trajectory with blush wash and berry now-dot, on
   a card (the dashboard's one hero). Care-connected patients keep
   YOUR CARE first (C8 law).
4. **The insight carousel** (kept, R6 grammar) — restyled: figures
   go rose, the sentence stays the only prose on the page.
5. **THE GRID** (2-col, the mosaic): steps (mini-ring + average) ·
   calories (week bars) · protein (bars vs floor) · sleep (last
   night + 7 bars) · consistency (week dots, "5 of 7 counted").
   Every tile: LABEL · VALUE · SHAPE, rose marks, staggered
   arrival, morphs into its detail sheet (v19 physics kept).
6. **The rows** (metrics without a read yet, or secondary): sugar
   intake · fiber · sodium · movement · waist (words) · body fat
   (band) — the v18.3 row law survives; rows keep their number and
   a spark seat.
7. **Body progress + care doors** (kept).

## 8. Motion, haptics, delight — the budgets

Motion vocabulary unchanged (`JeniMotion`); what's new is WHERE:

- **The ring is elastic**: trace-in overshoots ~4% and settles
  (spring), because the hero shape carrying physics is the page's
  signature. Charts keep `draw` (curves draw, springs touch).
- **Carousel pages morph** (scale/opacity in scroll), never slide.
- **Rows compress** on completion (`settle`), lists reflow on the
  same spring, numbers always count (`JeniCountingNumeral` and
  `contentTransition(.numericText)`).
- **Haptic budget per gesture, one word each** (v14 law holds):
  page detent tick · day tick · scope tick · quick-mark land ·
  all-done swell (the day's one swell) · sheet detent tick. A chart
  drawing stays silent.
- **Delight, one per screen, physics-class:** Home = the elastic
  ring + the plate-landing morph (exists). Becoming = the scope
  morph re-drawing the mosaic. Details = the staged reveal. Strip =
  the disc morph + landing pulse. Nothing else; calm over clever.

**Reduce Motion:** rings and bars render at value, carousel pages
stop scaling, compression becomes a fade — information never
degrades.

## 9. Detail sheets — the staged reveal

Inside the v19 detented morph (mechanics untouched): eyebrow +
headline arrive first; the hero numeral counts; the chart draws on
its stage (rose grammar); the ledger and the read follow; stance +
provenance last. One `arrived` flag, indexed children, 0.055
stagger — the v14 editorial order becomes a felt sequence.

## 10. What does not move (the standing floors)

Provenance (§1.6) · anti-shame (§11.4) · the honesty constraint on
bars (no invented denominators — D2) · numerals suppressed under
the safety gate · body privacy (never a number from a photo) ·
observed-never-prescribed · the two registers (B2C/B2B) and
lowercase voice · the a11y floors (§10, incl. charts speak words) ·
the paywall exemption · SwiftUI Charts stays banned; the engine is
ours · XCUI/sim gotchas and doors; walkers + tours stay the proof.

## 11. Decision ledger

| # | decision | why |
|---|---|---|
| D1 | rose ramp = 3 depths of ONE hue; ink keeps words/selection | founder's palette; one-colour law survives; anti-shame by construction |
| D2 | quantities fill rose, trajectories draw ink | one teachable line; keeps the weight line's gravitas |
| D3 | carousel pages: calories · macros · chemistry · week — no "score" page | a score has no collected field; provenance law |
| D4 | no hydration page/row | no hydration store exists; the checklist's care beat is the only true hydration surface |
| D5 | numeral INSIDE the ring on the calories page | the founder-loved demo's signature; the shape and the number become one object |
| D6 | checklist chips: SF Symbol default, real plate photo on the food row | premium consistency + the only honest photography available |
| D7 | completion = compress-in-place, no reorder | celebration without disorientation; list order stays the plan's order |
| D8 | evening close = a checklist row | "nothing else" — four blocks means four |
| D9 | greeting compresses to one line; trend line moves to Becoming | the 2s answer belongs to the hero, not the header |
| D10 | selection stays ink everywhere | rose = data, ink = statement; the strip/scope keep Chanel authority |
| D11 | macro split depths: protein berry, carbs dusty, fat blush | emphasis follows clinical priority (the floor), not judgment |
| D12 | tools keep words + state lines, gain mini-instruments | v13's word law was right; the instrument adds life without replacing identity |

## 12. The gate (per screen, before it ships)

Would this appear on Mobbin? Would someone screenshot it? Would
Apple feature it? Does the page still communicate with every
paragraph deleted? If any answer is no — iterate. THE LOOP (§15 of
the design law) is the verification: film, dump frames, inspect
neighbours, fix, repeat.
