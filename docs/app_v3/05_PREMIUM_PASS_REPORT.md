# app v3 — premium pass report

Date: 2026-07-05 (same session as the v3 rebuild; the founder asked
for a focused aesthetic push beyond it).

## What still looked weak before (the brutal list)

1. Jeni was TYPE, not a presence — the reading sat as a status line
   on cream; nothing said "someone wrote this for you."
2. The reading block and the one-thing card were two similar cream
   cards stacked — no focal anchor; the screen had no single object
   your eye lands on.
3. Rhythm rows carried utility-app residue: leading SF glyphs, a
   cold trailing "0" on steps before HealthKit wakes.
4. The masthead ignored the keeping chapter (said "a rest day" when
   the story is the band).
5. The jeni tab masthead was flat ("your coach"), and QA after
   18:00 local couldn't capture the day layout at all (the evening
   flip was wall-clock with no escape).

## What was upgraded

### THE NOTE FROM JENI (Jeni's presence, evolved)
The reading became a morning LETTER — a paper-grade note card:
"JENI" + hairline + the weekday as an italic dateline; the reading
in serif with line one leading at 24 and the second sentence
following at 18 in the secondary ink; the mechanism as a quiet
caption; the closing line carries "REPLY ↗" on the left and her
SIGNATURE — "jeni ♥" in italic Fraunces — on the right. The whole
note is the reply affordance (tap → the chat continues the same
letter; the chat already seeds the identical reading, so Jeni is ONE
person across the app: she writes every morning, the jeni tab is
where you write back). Idle: only the breathing shadow — measured in
the frame audit at ~0.004% pixel amplitude, alive without busyness.

### THE COCOA ONE THING (the anchor)
The ask inverted to the screen's single dark object: cream serif on
cocoa, the italic punch word tinted accent-subtle, deeper warm
shadow. Done: the card exhales into a cream kept-receipt row (struck
title + accent heart) — the dark anchor literally leaves the screen
when the ask is met. Permission days stay cream: dark MEANS an ask
exists. The screen's hierarchy is now a ladder — note (voice) →
cocoa (ask) → hairline rows (rhythm) → band (state).

### The editorial recede
- Rhythm rows are glyphless — title · note · state, text-set like a
  menu (ItalicAccentText gained an optional italicColor ink for the
  cocoa card; every existing call site unchanged).
- Steps at 0 shows no numeral (the note carries the row).
- The keeping masthead speaks the band ("inside your band ♥" / "a
  steadying week" / "a reset week, held") instead of the day
  archetype.
- The jeni tab masthead gains the dateline ("your coach · sunday").

## Motion / interaction evidence

- premium_cold_open.mp4 → 59 frames @4fps → pixel-diff curve:
  loader two-beat (2.17M → 509k → 1.45M → 563k) → decay → rest →
  the Today swap (1.38M) → entrance cascade → and a steady ~1.9k/300
  alternation = the note's breathing shadow (the ONE designed idle).
- f_017 mid-entrance frame: masthead landed, the note ghosting in at
  ~30%, the cocoa anchor waiting below — the stagger caught
  mid-flight and composed even as a still.
- SE: the note (comeback thread, both sentences, signature) renders
  without clipping; the cocoa card holds below the fold.
- Full unit suite + all six walker legs re-run on the final build
  (results in the session log; the day-dependent legs now pass
  `--uitest-force-day` so QA is deterministic past 18:00 local — the
  evening flip cost this session a confused hour and will never
  cost another).

## What deliberately did NOT change

Snap carousel, breath session core, trend canvas internals, the
reader interior, tab bar, walls/paywall — previously verified
excellent; restraint is the luxury. No engine, payment, gating,
schema, or EF changes (the safety report stands unamended).

## Honest remaining gaps (beyond HONEST_GAPS.md)

- The rep doors kept their plain-pill form (correct but not yet
  special); the chosen-door moment could earn a signature motion.
- Becoming's inter-block spacing wants one metronome pass.
- The band section of Today ("today so far") kept its structure;
  its header + arc typography could join the note's register in a
  future pass.
- ~~The evening receipt's "N of M beats" arithmetic~~ — closed in
  this pass: the plan row now speaks the standing grammar ("kept ♥" /
  "some of it landed"), the same vocabulary as the strip dots and
  the day review.
