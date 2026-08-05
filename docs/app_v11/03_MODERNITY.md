# v11.5 — THE MODERNITY PASS (2026-08-05)

The founder's third brief of the cycle. The architecture, hierarchy and
engineering of v11 stand. The FEEL graduates: **from printed page to
living surface.** "Minimal + premium. Think Apple Health, Lovi, Gentler
Streak, Linear — not magazine, not PDF."

This document amends `00_REBIRTH.md` (which remains the law). Where
they conflict, this pass wins.

## Amendments to the laws

- **L5 amended — depth without chrome.** The flat white card grows a
  MATERIAL: `JeniSurface` — elevated fill, 24pt continuous radius, an
  ultra-soft diffuse shadow (≤6% ink, large radius) and a hairline top
  highlight. Depth you feel, not shadows you see. Still no borders.
- **L3 tempered — quiet glyphs return.** "Almost no icons" was read as
  "no icons"; modern-native needs a FEW, small and secondary (15pt,
  cocoaSecondary), never carrying meaning alone.
- **L12 extended — interaction is choreography.** Springs replace
  ease-out curves for anything the finger touches. Selection MORPHS
  (matched geometry), cards press (scale ~0.985 spring), checks draw
  themselves, content responds to selection with connected motion.
- **The check circle returns** (the founder points at Lovi): a card's
  circle is the quick-mark tap; the card body enters the module; the
  long-press override sheet stays. (Supersedes the v7-era "indicator
  render-only" law — the founder's v10 circle/hold steer already had.)

## The work

**HOME** (IA unchanged):
1. The calendar strip becomes a first-class component: week paging by
   swipe, tappable days, the selection disc MORPHS between days
   (matched geometry + tick), and the content below RESPONDS — FOOD
   and TODAY re-key to the selected day (past days read as the record:
   what landed, what kept; future days decline politely). "back to
   today" appears when away.
2. TODAY rows → soft cards (JeniSurface): the lead keeps its serif
   headline inside the card; every task card carries a JeniCheck
   circle (quick-mark w/ drawn check + land haptic), card tap enters,
   hold overrides.
3. TOOLS rebuilt from scratch: a quiet grid of soft compact cards,
   word-first with a quiet glyph.

**BECOMING** (must become the most beautiful screen):
1. Every card → JeniSurface; the hero chart grows.
2. **The expansion**: tapping a tile morphs it in-tree into the full
   chart page (matched geometry inside one ZStack — iOS 17-true), scrim
   fades, content arrives staged, drag-down collapses it. The
   fullScreenCover detail dies.
3. Three tiles join: CALORIES (7-day bars), BODY FAT (the provenance
   ladder — measured else Deurenberg band; never from a photo, the
   caveat always rides), WAIST (BandProfile words across her record —
   never a number, L3/L7 hold).

**THE LOOP** runs after each surface, as law §11 demands.

## Register note

The serif stays for hero numerals and reads — it is the brand. What
changes is the GROUND: surfaces feel touchable, selections feel
physical, and nothing on screen is inert paper anymore.

---

# THE EVIDENCE (M4, 2026-08-05)

Commits: `8684635` law · `34b2ece` M2 Home · `9558825` M3 Becoming ·
this one (axis + close-out).

## What the film and the walkers caught

**M2 — Home**
1. **The pill wrapped the dateline.** "back to today" placed beside the
   dateline pushed "DAY 12" onto a second line and left the gear
   floating. Frame 438 caught it mid-selection. The pill moved into
   the recap's own header, where it belongs to the state that
   summoned it.
2. **The morph is real.** Frame 438 holds the ink disc between
   Tuesday and Wednesday while the recap cross-fades beneath — one
   connected motion, not two animations.
3. **Numerals still count through the re-key.** Frame 440 catches
   "8**6**0" mid-roll on the return to today: the strip's selection
   feeds the same counting numeral, so switching days animates the
   number rather than swapping it.

**M3 — Becoming**
4. **The expansion works in-tree.** Frame 860 holds the morphed page
   over the ghosted grid — matched geometry inside one ZStack, no
   `fullScreenCover`, no iOS 18 zoom API.
5. **A leg had been lying by omission.** The old detail page's "done"
   carried a descriptive a11y label ("done. closes weight"), so
   `buttons["done"]` matched nothing — and the leg's optional
   `if done.exists` silently skipped the assertion, every run.
   Hardening the leg (assert every close) exposed it instantly.
   `becoming.tile.done` is now the stable identifier.
6. **The axis lied.** The hero chart claimed "4 weeks ago" over a
   record 11 days old, leaving the left half of the card empty — it
   read as a rendering bug. The window now scopes to the record
   (first weigh-in → today, minimum a week) and the label sizes with
   it: "2 weeks ago → today". Dead space gone, honesty gained.

## The gates

- Units **537/538** (the 1 = the documented V6Funnel full-suite flake
  family, member varies per run, solo-green).
- **All 7 SurfaceInventory legs green, run solo**, including the new
  `testStripSelectionAndRecap` and the hardened
  `testBecomingSummaryAndReSigning`.
- **SE floor** walked on Home + Becoming under the new material: the
  cards, the check circles, and the strip hold at 375pt.
- **XXXL** walked on both surfaces.

## Deferred, honestly

- The **week-paging TabView** carries a page-dot indicator suppressed
  via `.never`; a custom paging container would remove the UIKit
  scroll physics entirely. Current feel is native and correct — not
  worth the rewrite yet.
- **Sheets** (weigh-in, steps, regimen, plate detail) still wear the
  v11 flat treatment; they present over the modern surfaces without
  clashing, but their own material pass is a T-next candidate.
- **The evening close** keeps its ledger hairlines (a receipt is a
  table). Its re-skin remains open.
- `--uitest-seed-scans` still seeds figure-era records, so BODY
  PROGRESS reads as solid ink in demos.

---

# S1 — THE BODY SCAN (2026-08-05, commit 7637497)

The founder's original brief spent more words on the scan than on any
other surface. v11/v11.5 had not touched it; v10.4's structure was
right (a live window inside a drawn figure) but the execution was not.

## What the film showed

- **The figure taught nothing.** At 0.18 opacity on a 1.1pt line it
  read as a ghost placeholder, not an illustration. Now 0.30 at rest
  / 0.52 recognized at 1.6pt: a drawing you can actually follow.
- **The phone was missing.** The brief asks the illustration to show
  how to position *the phone and the waist*. `PhoneInHand` adds a
  small ink phone at her hip, tilted as a hand holds it toward a
  mirror. The pose is now unmistakable, and still wordless (L3).
- **Recognition was invisible.** `ApertureBrackets` hover outside the
  window and converge onto its corners when a person is found — the
  universal lock-on grammar, in paper and ink.
- **Stillness had no expression.** The aperture's rounded rect is now
  trimmed to `gate.progress`, so holding still *draws the frame
  closed*. The promise "hold still. it takes itself." made visible.
- **Three stages were objects adrift.** LANDED and RECORD centered a
  plate between two `Spacer()`s, leaving ~600pt of dead air — the
  engineer-designed tell. Both are pages now: eyebrow → headline that
  states where the record stands → plate → action.

## The result page, completed

The brief's list, now all present: body progress (the two plates + what
changed) · **this week** (the scale's floor-gated delta, "not yet"
when the trend hasn't earned a number) · **confidence** (BandProfile's
own judgment: clear / soft) · estimated body fat with its provenance
and caveat · **today, from here** (the day's composed lead, so the scan
returns her to the plan rather than ending on a number).

On the founder's phrase "clearly labeled as AI estimate": the honest
label is the provenance ladder, and it is stronger. The number never
comes from the photograph (L7) — it is either measured by her scale
("measured · apple health") or computed from height, weight and age
("estimated · never from a photo"). That says exactly where it came
from, and never says "AI" (voice law).

## Also this pass: the em-dash sweep (commit 78a0a22)

Opening the consent screen surfaced "hold still — it takes itself."
The v11 voice law bans em-dashes between words, but BodyScan, the
exercise bank and a dozen engines predate the law and had never been
swept. **299 user-facing strings fixed**, chosen per case: clause
joins became full stops, compact label joins took the interpunct, and
9 paired parentheticals became commas. Two gaps the suite caught: the
first regex skipped interpolated strings entirely, and four tests
pinned the old literals.

## Still open on the scan

- CONSENT's two choice cards are still pre-material (flat).
- `--uitest-seed-scans` seeds figure-era records, so demo plates read
  as solid ink blocks rather than waist bands.
- **N — the Lovi scan chooser** (tab-bar centre action → blurred sheet
  offering BODY and PLATE) remains the next cycle.

---

# N — THE SCAN CHOOSER (2026-08-05)

The founder pointed at Lovi's "Make a New Scan": the page blurs away,
two large cards rise, a round close sits beneath. Built in Jeni's
paper-and-ink vocabulary.

## The shape

- `JKTab` gains `.scan` — an ACTION, never a destination. Selecting it
  remembers the tab she was on, springs the bar straight back, ticks,
  and raises the chooser. (The MFP/Lovi centre-action grammar, done on
  a native `TabView` rather than a hand-rolled bar.)
- `ScanChooser` is presented IN-TREE from `MainShell`'s ZStack, never
  as a sheet — so the `.ultraThinMaterial` blurs the LIVE screen she
  came from and the arrival choreography is ours.
- Two doors, each a `JeniSurface`: **your body** (the waist, week to
  week) and **a plate** (counted from one photo). Their art is DRAWN
  in the same ink vocabulary as the instrument, so the chooser belongs
  to what it opens: the body door is the instrument in miniature (the
  figure clipped to its aperture); the plate door is a rimmed plate
  with three quiet marks.
- Choosing routes through `AppRouter` (`.bodyScan` is new) to Home,
  which owns the module covers. A 0.28s beat lets the chooser leave
  before a full-screen cover takes the window.

## What the frames caught

1. **The body art showed shoulders, not the waist** — the figure sat
   0.42h too low in its window. Now 0.27h: the band is the subject.
2. **The two arts weren't siblings** — a rounded-rect field beside a
   bare circle. The plate now sits in the same field.
3. **The scrim washed the page white.** Paper-over-blur on a cream app
   left the cards without separation; a breath of INK (0.12) over the
   material restores it while keeping the world warm.

## Gates

`testScanChooserDoors` green (both doors render, close returns to the
page, and the scan item re-opens rather than navigates) · the surface
walk and strip legs green with the fourth bar item · units 537/538.

---

# THE CHAT DESK (2026-08-05)

The founder's Lovi reference: the mark, a greeting, "start a chat"
bubbles, then history — and Jeni chat rebuilt to that structure.

## The shape

The chat tab now has two states, and the split is honest: **the desk**
when she has not spoken yet, **the conversation** the moment she has.

- **The desk**: the hand-drawn j on a soft disc → `hi. i'm jeni.` →
  one quiet line → START A CHAT → the disclaimer as a footnote to the
  openers.
- **The openers** are Lovi's speech bubbles: a real `BubbleShape` with
  a tail, laid out by a `FlowLayout` so each sizes to its own words and
  wraps onto real lines. The old horizontal rail hid the third opener
  off-screen; nothing hides now. Each carries an ink send-disc, ticks
  on tap.
- **The conversation** keeps the two-voice transcript (serif jeni,
  rose-italic her) and gains a lighter header: the mark, her name, the
  day. `JKMasthead` is retired from this surface.

## Two honest departures from the reference

1. **No "New Chat" button.** Lovi threads conversations; Jeni keeps ONE
   continuous transcript with day seams. A new-chat button would imply
   a thread she could throw away, and there is none (L8).
2. **History is her real days.** Where Lovi lists past conversations,
   the desk offers `what you've talked about` — the actual days from
   her transcript, each shown by the line she opened it with, tapping
   to ask it again. Nothing invented; when there are no past days the
   section simply does not render.

## What the frames caught

1. **The desk never appeared.** `entries.isEmpty` was the wrong test —
   the session seeds jeni's opening line, so the transcript branch
   always won. The honest signal is *she hasn't spoken yet*
   (`!entries.contains { $0.kind == .user }`).
2. **The openers rendered twice** — the desk's bubbles, then the
   composer's old chip rail repeating them word for word. The composer
   now yields its rail whenever the desk is showing.
3. **A wall of centred serif.** Jeni's stored greeting is a paragraph;
   centred and full it read as a run-on sentence. Two attempts to trim
   it (first line, then one sentence) both fought the data. The right
   answer was to delete it: the desk greets and offers, and her reading
   is one tap away in the conversation where it belongs.
4. **A minHeight that did nothing.** Two passes tried to pin the
   disclaimer to the foot; both fought the scroll geometry for no gain.
   Removed the plumbing rather than leaving dead parameters behind —
   the block in the upper two-thirds with the composer anchoring the
   bottom is the reference's own proportion.

## Gates

The surface walk (which drives the chat tab end to end: chips →
stream → tool card) green · units 537/538 · build clean.

## The bubbles return (founder: "chat bubbles are better")

A mission-2 pass had typeset both voices bare on the cream and left
`ChatBubbleShape` — a real tailed, iMessage-grade bubble — orphaned in
the file. The founder's steer brought it back, as MATERIAL rather than
iOS chrome:

- **jeni** speaks from a soft white surface with the kit's diffuse
  depth; **her words** answer from a blush fill that still carries her
  rose italic. Two voices, two materials, one tail per run.
- Inside a bubble the text reads **leading**: trailing alignment is a
  margin-note grammar and a bubble is not a margin.
- **The tool card** was the last flat thing in a thread made of soft
  bubbles — a drawn hairline frame that read as another app's
  component. It is material now, at 22pt.
- **The glossy sticker tiles retired** from the plan rows and the card
  header. They belonged to the it-girl era and clashed inside an ink
  thread; a quiet glyph carries the row and the words do the work (L3).
  The header's tinted disc went with them — the title is the header.
- **`her file`, collapsed, is a label** — the bordered pill around a
  lone word read as a broken empty component. The surface appears only
  when there is something inside it to hold.


## The typography fix, and the build pipeline that hid it

The founder: *"the fonts in chat bubbles look ugly, it needs to be more
body font."* `JeniProse`'s own comment claimed DMSans, but `composed()`
set **JeniHeroSerif at 17.5** — a reading face set as a message, which
is exactly why the bubbles read as a book. The transcript now speaks in
DMSans-Regular 16.5 (jeni's prose, her words, the composer field), with
`*asterisk*` spans rendering as the house Fraunces italic punch. Her
voice is carried by the rose and the blush bubble, not the slant.

**The fix took five captures to see, and the reason is worth writing
down.** Xcode 16+ builds this app as a **58 KB stub** (`plankAI`) plus a
**149 MB `plankAI.debug.dylib`** that holds all the actual code. Two
things follow, and both cost time here:

1. `strings plankAI.app/plankAI | grep <symbol>` finds NOTHING — not
   even symbols you know are present. It is the stub. **Grep
   `plankAI.debug.dylib`.** A "0 occurrences" result from the stub is
   not evidence of a stale build; it is evidence of grepping a loader.
2. `xcodebuild -quiet build` can report success without relinking.
   **Check that `plankAI.app`'s mtime advanced before installing**, or
   you will install the previous bundle over and over and conclude the
   source is wrong when it is not.

The honest sequence: source correct → four captures showing the old
face → a stub-vs-dylib check that appeared to confirm staleness but was
itself measuring the wrong file → mtime comparison → forced relink →
verified. The commit that shipped the fix says verification was
incomplete; it is complete now, and this is the record.

## The heart guard, made categorical

A red heart reached a live reply on camera. The guard was an enumerated
list (2764, 1F495, 1F497, 1F49E) and every heart outside it sailed
through. It is categorical now: 22 heart scalars plus their trailing
variation and ZWJ selectors, so `❤️‍🔥` leaves nothing behind.
`JeniChatVoiceTests` pins the RULE rather than the list — and its first
run caught a bug in the fix itself: it tested the last OUTPUT scalar,
but the heart was already dropped by then, so the variation selector
orphaned as a stray glyph. Fixed by tracking the previous SOURCE scalar.

---

# HOME, LEARNED FROM THE TWO REFERENCES (2026-08-05)

The founder set MyFitnessPal and Lovi side by side and asked Home to
learn from both in detail. What each actually teaches, and what Jeni
took:

**From both: the page opens on an ATMOSPHERE, not a flat field.** MFP
lays a pale blue wash behind its header; Lovi a warm peach-to-blue
glow. Neither is decoration — it gives the page depth before a single
element is read. Jeni's version is `jeniAtmosphere`, a Metal shader:
two bloom centres drifting on slow mutually-prime orbits (so it never
visibly loops) over a band that dissolves downward, lifting the paper
toward warm white with a whisper of rose where the blooms overlap. It
runs at ~30fps from a self-driven `.task` phase (the v10.1 Canvas law)
and holds still under Reduce Motion — the depth is the point, the
drift is the flourish. First tuning at 0.07 was invisible on cream;
0.34/0.30 is where depth appears and colour still does not.

**From Lovi: the human greeting.** "Afternoon, Sunshine" with the name
in a lighter tint. Jeni now opens on `afternoon, maya.` — the hour
decides the word, her own name takes the softer ink and the italic, so
the two read as one breath. It replaced a datestamp, which is the
difference between a product that greets you and one that logs you.

**From MFP: the strip carries STATE, not just dates.** MFP marks today
with a check inside a filled disc. Jeni's strip now draws her record:
a kept day wears a closed ring, today wears a quiet one, and on the
selected day a drawn check REPLACES the numeral — the check is the
number's meaning. Backed by `ProgramService.keptDayStarts` (derived
from `completedAt`, no new storage) so a ring only ever means she
actually kept something (L8, L10 — the week is orientation, never a
report card).

**Consequence: the dateline stopped repeating itself.** With a greeting
above and a date strip beside it, "wednesday, august 5 · day 12" was
the page saying the same thing three times. It now carries only what
neither says: `day 12 of 140 · finding steady · week 2 of 20`.

## Plain words (founder)

*"'add the next plate' can be confusing to users."* Correct — "plate"
is our internal word. The asks now say MEAL: `add your next meal`,
`add your first meal`, `add what you last ate`, `add a small meal,
protein first`, and the tool reads `snap a meal`. Swept through the
empty states, the rep engine, the method ritual and the scan chooser
so one vocabulary reaches her everywhere.

## Gates

Strip, walk and chooser legs green · units 540/541 (documented flake) ·
bundle freshness verified before each capture (see the debug-dylib
note above).

---

# BECOMING — THE RIBBED PASS (2026-08-05)

The founder: *"line charts are not working — not pretty, too many on
the initial screen, laggy and scattered."* All three were true, and
they were one problem: eleven tiles each rendered a live `JeniChart`,
so arriving on Becoming started eleven animated Canvas engines.

**What the references teach.** Both screens share a texture neither
states outright: bars built from many fine strokes rather than solid
fills, and rounded PILL columns instead of hairlines. The ribbed form
reads as an instrument — a printed scale, a ruler's teeth — and it
holds detail at sizes where a solid capsule reads as a blob.

**`JeniRibbon`** is Jeni's version, and it replaces the tile-face
charts: one light Canvas per tile instead of a chart engine each. Its
teeth taper toward the ends so the ribbon reads as a machined object,
and it lights left-to-right on arrival. Every tile now carries an
honest measure: nutrients against the week's strongest day, calories
against her window, sleep against 8 hours, steps against the goal,
weight as its position between the window's lightest and heaviest
readings.

**`JeniPillBars`** takes the detail pages — the reference's rounded
columns with the current one filled and labelled, ghost columns for
days with no data (visibly empty, never a zero).

**Where the reference was NOT followed, and why.** Reference A draws
weight as bars. Bars imply a zero baseline; weight has none, so a
weight bar chart either lies about magnitude or (scaled to its own
range) renders seven near-identical columns. Weight keeps the LINE —
but the line got what it was missing: a soft area beneath it and a
haloed "now" mark, so it reads as designed rather than sketched. The
first capture showed that halo sliced in half at the canvas edge; its
centre is clamped inside the bounds now.

**Contrast (founder: "more contrast, like chanel").** Paper #FCFAF7 →
#FDFDFC, ink #2A1F1E → #18100F, secondary and the cocoa family moved
in lockstep. The faintest warmth stays so a clinician's app never
turns clinical-cold. `TokensContrastTests` still passes — every ratio
rose.

## Gates

Units 540/541 (documented flake) · the becoming leg green · captures
taken against a verified-fresh bundle.

## Still open on Becoming

- **Every module clickable.** The tiles and BODY PROGRESS open; the
  hero BODY card and the care rows do not yet drill in. That is the
  next cycle's first job.
- The reference's period selector ("1 months ⌄") on the hero, and its
  icon discs on stat cards, are not adopted yet.
