# app v3 — design language + interaction notes

Date: 2026-07-05. The rule: onboarding v5 is the seed dialect; the
app interior speaks it everywhere. Tokens.swift stays the source of
truth (8 locked colors, cream-only background). This doc adds NO new
colors and ONE new type step; everything else is composition.

## The dialect (from v5, now interior-wide)

- Serif editorial headline + italic punch word; ONE hero per screen.
- Receipt/dossier grammar for data: tracked-caps label column,
  hairline rules, serif-italic value column ("maya file" card).
- Trust micro-copy where we ask for anything ("never shown back as
  a grade").
- The tick ruler is the input instrument for numbers.
- Cocoa pill = the single primary action; quiet text = the escape.
- Hairlines over cards; a filled container is EARNED (one per
  screen: the one thing / the ritual card / the artifact).
- Stickers only on earned moments (welcome / plan reveal /
  graduation). Plan rows lose their pastel thumb stickers; warmth
  concentrates in the hero.
- Hearts: ♥ + U+FE0E only, terminal only. (Fix the legacy ♡ in the
  safety check-in intro; verify FE0E renders text-presentation on
  every font it rides.)

## Today — the reading (anatomy, top to bottom)

1. MASTHEAD (JKMasthead, kept): day pill · chapter note · date
   eyebrow · camera + menu marks. Scroll: masthead content fades
   under the status bar with a cream gradient scrim (fixes the
   caption/clock collision).
2. THE READING — the hero. 2-4 sentences, serif `Typo.reading` (24pt,
   line gap tight, relativeTo .title3), italic punch per voice
   rules; optional mechanism line beneath in DMSans caption
   (cocoaSecondary). "ask jeni ↗" affordance (kept). Entrance:
   line one settles first, remainder rises +340ms (the loader's
   timing signature). The reading NEVER exceeds 4 sentences and
   never scrolls its own box.
3. THE ONE THING — the screen's only filled container (bgElevated,
   Radius.lg, Space.lg padding). Eyebrow "THE ONE THING" (tracked
   caps 11) · serif title 22 ("snap lunch, protein first") · one
   provenance sub-line (why today, from real fields). Whole card =
   button (JKPress). Done: title strikes at pen speed, card exhales
   to a one-line receipt row (0.55s, scale 0.985 + crossfade), silk
   may ride the moment. If the engine has no ask (rest day), the
   card reads as permission ("nothing owed today. a walk if you
   want it ♥") with no button affordance.
4. THE RHYTHM — remaining beats as hairline rows (JKBeatRow
   restyled): quiet SF glyph (tertiary) · title · right-aligned
   state word ("after dinner" / live "4,210" for steps / strike
   when done). NO at-rest circles, NO thumb stickers, NO counts.
   Tap enters module; long-press override kept (tap-swallow fix
   kept); strike + tick cascade kept.
5. TODAY SO FAR (band, kept): protein arc hero + steps ring + kcal
   sentence + plates strip. Copy gains "close enough" state words.
   Under-target evening safety net (on-medication/restrictive):
   the kcal sentence flips posture ("a light day. protein first at
   dinner?" — adequacy, never praise for less).
6. EVENING (≥18:00): THE RECEIPT leads (standing word hero:
   "kept." / "some of it landed." / "a quiet day." in serif),
   receipt rows (protein · moved · the plan), one-tap feeling
   (kept), tomorrow whisper (kept). The one thing, if undone,
   softens to a rhythm row ("still open, no pressure").

DAY STRIP: numerals only. Past days carry a 3pt standing dot
(filled=kept, half=partial, hollow=quiet). Today = cocoa pill.
Future ≤+7 = plain numerals + archetype letter; beyond +7 = 40%
opacity numerals, NO padlock glyph. Tap: past→review (day receipt),
future→peek (kept), far→quiet "not written yet" line in the peek
chrome instead of a lock sheet.

ON A BREAK: when paused, the masthead chapter note reads "on a
break · your place is kept", the one thing renders as permission
("nothing owed. come back when you're ready ♥"), rhythm rows hide,
the strip dims its expectations (no hollow dots accrue), and all
pings sleep. Return = warm reading ("welcome back. the plan kept
your place.") + automatic repair; never a catch-up list.

ONE-WORD CHECK-IN: three quiet word-chips inside the reading's
tail or the evening receipt ("how's the food noise today?" —
quiet / some / loud; chapter-flavored). Optional forever, no badge,
no history guilt. Answer = soft haptic + the chip settles into a
receipt row.

## Jeni — the coach's desk

1. Masthead kept ("jeni · your coach").
2. LETTERHEAD: today's reading (same engine, rendered smaller,
   serif 20) — the tab never opens empty.
3. HER FILE (collapsible receipt card, the v5 dossier alive):
   CHAPTER (losing / on medication / keeping) · THE PACE · PROTEIN
   FLOOR · THE BAND (keeping only) · PROMISE HOUR. Rows tappable →
   the right ritual or settings screen. Collapses to a hairline
   "her file ↗" row once a conversation exists today.
4. Chips (kept, provenance-gated) · conversation (letter register,
   kept) · composer (kept; tab bar yields to keyboard, kept).

## Becoming — the story

Masthead · trend story (kept) · CANVAS + THE BAND (keeping chapter:
three tinted horizontal zones behind the EMA line — accentSubtle
tints only, labeled "steady / drifting / reset week" in tracked
caps; zones NEVER color the number, only the field) · week story ·
Sunday receipt (kept artifact) · insights (max 2, kept) · method
journey (kept) · wins (reads the NEW standing model). The raw
weight numeral demotes to a receipt row ("this morning · 163.6").
One fact renders once per viewport.

## The rep (method practice) — new surface

Full-screen cover (module family), instant-in. Anatomy: eyebrow
(act · day N) · scenario (serif 28, the hook: "9pm. the kitchen is
calling.") · 2-3 answer doors as tall pill options speaking the
OV5 cross-off grammar (tap = strike + haptic + chosen door fills) ·
the mechanism line rises (+0.35s, DMSans, warm, cites her data when
real) · "kept" chip (rep chip grammar, kept from v2.7) · quiet door
"the whole idea →" (opens the reader at the slot). Close returns to
Today with the method row striking on screen (chain grammar kept).
No score, no wrong answers: every door gets a mechanism line; the
"skill" door gets the warmest one.

## Rituals + sheets

- Weight: JKWeightRitual kept (ruler, 0.7 detent, count-aware kept
  beat). Keeping chapter adds the band whisper on save ("inside
  your band. steady ♥") — provenance from the zone math. Trend
  copy pre-explains physiology (Monday bump ≈ salt + weekend, the
  ~0.35% intra-week swing) so no uptick ever lands unexplained.
- Day review: 0.42 detent (shipped). Gains her feeling word when
  one was logged that evening.
- Steps: 0.7 detent sheet kept; goal reads TargetsService (fix the
  hardcoded 7500s).
- All sheets: JKSheetChrome, no grabber, cream, serif title.
- Covers reserved for immersions (workout / breath / lesson / rep /
  snap). Sheets for actions. Never a sheet inside a sheet.

## Motion (few, meaningful; all reduce-motion gated)

Kept: jkBeat1/2 entrance · strike + tick cascade · silk day-sweep ·
breath bloom · trend draw-in · dealt-plate stagger · count-ups on
visibility. New: reading two-beat settle (60/340ms) · one-thing
exhale-to-receipt (0.55s) · rep door strike (OV5 reuse) · band zone
draw (0.8s ease, once). Banned: spinners on main surfaces, badge
pulses, red anything, countdowns, parallax.

## Haptics (one source per gesture — the v5 double-fire lesson)

light = tap-in · soft = strike/save · medium = rep door choice ·
success pattern = day-kept silk + graduation only. Never two
haptics for one gesture; JKBeatRow owns the row's haptic, modules
stay silent on entry.

## States

- Loading: cream + content fades in when ready (deterministic
  reading renders instantly — it needs no network). Chat streams
  via JKStreamText. Snap keeps its Metal sweep.
- Empty: JKEmptyState grammar — invite, never fabricate ("your
  band draws after your first steady week").
- Error: quiet capsule + one retry line, never red (chat pattern is
  canon).
- Offline: reading + program fully local (works offline by
  design); chat queues ("she'll answer when you're back"); snap
  falls to describe-mode with the existing failure card.

## Type + layout

- ONE new token: `Typo.reading` 24pt serif (+`readingItalic`),
  relativeTo .title3. Everything else uses the existing ladder.
- All new text uses relativeTo metrics; Dynamic Type XL verified on
  Today / jeni / rep; clipping contract floors (0.78-0.85
  minimumScaleFactor) extend to the one-thing title + rhythm rows.
- iPhone SE: reading wraps free (fixedSize vertical), one-thing
  card has no fixed height, band already verified; rep doors stack
  with Space.optionGap.
- Safe areas: masthead scrim under status bar; tab bar yields to
  keyboard (kept); bottom Spacer 96 kept for tab clearance.

## Accessibility

- VoiceOver: reading = one element + "ask jeni" action; rows
  announce "title, state" ("move, after dinner"; "done" when
  struck); band zones announced by NAME never color; rep doors are
  buttons with the full sentence as label.
- Contrast: tracked-caps captions stay ≥11pt cocoaSecondary (not
  tertiary) when informational; hairlines stay decorative.
- Reduce motion: every new animation site gates (strike still
  swaps state instantly; reading appears whole).

## Copy floors (unchanged, enforced on every new string)

lowercase casual · italic punch 1-3 words · ♥︎ terminal only · no
em-dashes between words · no "AI" · no diet-culture verbs · pill
labels 2-4 words · subheads 5-7 · every number traces to a field ·
"about/near" on estimates, never 1g precision.
