# app v3 — the premium pass (design decisions)

Date: 2026-07-05. The founder's bar: one beautifully art-directed
product world; Jeni as a felt presence; nothing that reads as a nice
prototype or old screens in a new shell. Luxury means restraint —
fewer, better moments, every one intentional.

## The brutal audit (what still reads non-premium)

1. **Jeni has no body.** The reading is beautiful TYPE but it's a
   status line, not a presence. Nothing on Today says "someone wrote
   this for you this morning." (The founder's centerpiece ask.)
2. **Two cream cards stack and compete.** The reading block and the
   one-thing card carry similar visual weight; the screen has no
   single focal anchor.
3. **Rhythm rows still carry app residue**: leading SF glyphs
   (figure.walk, book) read utility-app; a steps row shows a cold
   trailing "0" before HealthKit wakes.
4. **The masthead is chrome, not voice**: generic SF camera +
   hamburger floating loose; the chapter note ignores the keeping
   chapter (says "a rest day" when the story is the band).
5. **Jeni tab opens with dead air** above the letter (bottom-anchored
   scroll) and a flat "jeni / YOUR COACH" masthead.
6. **The rep doors are plain pills** — correct, but the chosen-door
   moment could land with more grace.
7. **Becoming's section headers** are tracked-caps everywhere — the
   rhythm is right but spacing between blocks varies.

## The three moves

### A · THE NOTE FROM JENI (the presence)
The reading becomes a morning LETTER — a paper-grade note card:
tracked-caps "JENI" + hairline + the weekday in italic Fraunces as
the dateline; the reading in serif (line one leads at 24, the second
sentence follows at 18 in the secondary ink); the mechanism as a
quiet caption; and a SIGNATURE — "jeni ♥" in Fraunces italic,
bottom-right — with "reply ↗" bottom-left. The whole note is
tappable (reply = the chat continues the same letter). Enter: the
two-beat settle; idle: the breathing shadow, nothing else.
Rationale: the chat already speaks the letter register; extending it
to Today makes Jeni ONE person across the app — she writes every
morning; the jeni tab is where you write back.

### B · THE COCOA ONE THING (the anchor)
The one-thing card inverts to cocoa-primary — the screen's single
dark object, unmistakably the ask (cream serif on cocoa; the italic
punch word tinted accent-subtle; the strike draws in cream). Done:
the card exhales into a cream kept-receipt row, so the dark anchor
literally leaves the screen when the day's ask is met. Permission
days stay cream (dark = an ask exists; cream = nothing owed).
Hierarchy ladder becomes: note (voice) → cocoa card (ask) → hairline
rows (rhythm) → band (state). Exactly one dark anchor per screen.

### C · EDITORIAL ROWS + THE QUIET PASS (the recede)
Rhythm rows go glyphless — title · note · state, text only, like a
menu set in a good restaurant. Steps at 0 shows no numeral (the note
"counted for you" carries it). The masthead's keeping-chapter note
speaks the band ("inside your band ♥" / "a steadying week" / "a
reset week, held"). The jeni tab masthead gains the dateline
eyebrow; the strip and band keep their bones with spacing trued.

## What stays untouched on purpose
Snap carousel (the signature), breath session core, trend canvas
internals, reader interior, tab bar, walls/paywall, all engines.

## Evidence protocol
Every move: before/after stills + a recorded flow → frame dump →
pixel-diff read for the note settle, the cocoa exhale, and the rep
door. SE re-run for clipping. Full walker re-run before the report.
