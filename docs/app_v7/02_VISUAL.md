# app v7 — THE VISUAL CONSTITUTION (mission 2, 2026-07-27)

Founder brief: "The current UI feels like a well-designed
productivity app. I want an editorial luxury product." The
onboarding is the signed register; every surface rises to it.
Synthesized from a fresh 9-persona visual-only panel + an
editorial-principles research lane (all artifacts in
`panel_visual/`). Visual law only — the care-plan product law
(00_THESIS.md) stands beneath it.

## 1. The register laws (measured from the onboarding beats)

1. **One tracked-caps eyebrow per screen.** 12-13pt, ~+0.15em,
   the ONLY caps event. (The app ran 3-11; Home stacked three
   before its hero.)
2. **One serif act per screen.** 44-56pt JeniHeroSerif, two lines
   max, exactly one italic punch word. Nothing else within 3x of
   its size.
3. **The number is the image — or a whisper.** One didone
   monument per screen where data is the point (64-90pt serif +
   italic unit beside it); every other numeral lives in the
   ledger register (19-26pt). **The 28-40pt middle register is
   banned** — it is where "productivity app" lives.
4. **Zero containers.** No cards, no bubbles, no tails, no
   shadows-on-white, no chips-as-chrome, no radio circles, no
   banners. Structure is 0.5pt hairlines at ~12% cocoa and
   placement. (22 onboarding beats contain not one filled
   container.)
5. **One affordance per screen.** One cocoa pill, or ghost text.
   **Chevrons are dead app-wide.** The line itself is the door.
6. **Composed cream, 40-70%.** Emptiness is placed around the
   act (optical center or the upper third), never left over at
   the foot.
7. **Never truncate.** A serif sentence renders whole or not at
   all ("this is day 12, n…" is a register violation, not a
   layout compromise).
8. **Ledger grammar for facts.** Whisper label left, serif value
   right, hairline between rows — the receipt the onboarding
   taught twice before day one.
9. **Rose appears once per screenful, as meaning** (a punch
   word, a seal, an endpoint dot) — never as decoration.
10. **One improvisation over a strict grid.** One shared 24pt
    left margin everywhere; right-alignment reserved for ledger
    values; the single italic word is the allowed life.

## 2. The rooms (different rooms, same house)

- **home = THE CEREMONY.** A daily broadsheet: one eyebrow
  (`MONDAY, JULY 27 · DAY 12`), the day's ask as the 52pt act,
  the calorie monument (860 at 64pt serif + italic trail), the
  kept lines, one quiet ledger foot. The letter is reached
  through the date's seal — never previewed truncated.
- **becoming = THE ISSUE.** A cover, not an index: masthead +
  week eyebrow, jeni's read as the 44-48pt cover line, contents
  as bare serif lines (no chevrons, no "tap to open" — the lines
  are the doors), then the flip. Inside: full-bleed spreads,
  stat tables dissolved into chart-anchored ledgers.
- **letter = THE CORRESPONDENCE.** The truest room already.
  Block at optical center, the dateline untouched, ONE act
  (reply); keeping becomes the seal — the ✦ at the sign-off
  fills and files the letter.
- **chat = THE INTERVIEW.** The bubble grammar dies: jeni
  typeset flush-left on cream in the letter's own voice; her
  turns right-aligned in rose ink (at most an 8% wash, tailless);
  the trend arrives as a naked line drawing with an italic
  caption. The input pill is the only chrome.
- **food = THE STILL LIFE.** The snap-demo beat is the signed
  standard: full-bleed photograph owning the top half, one
  numeral monument, the ingredient ledger, one verdict line.

## 3. THE KEPT LINE (the signature interaction)

The checklist is JeniFit's signature. No circles, no boxes, no
strikes, no "still open" captions.

- **At rest:** an intention is a bare lowercase serif line —
  26pt JeniHeroSerif at ~55% cocoa ink — resting on a 0.5pt
  hairline, terminated by a hollow ✦ (16pt, ~30% cocoa). The
  reason whispers beneath in 13pt. An unkept line is UNSIGNED,
  not undone.
- **Keeping (the signing):** press-and-hold ~450ms — the
  hold-to-build gesture onboarding already taught, with
  `ActivationHaptics.holdRamp` rising under the thumb. The ink
  deepens 55→100%; the hairline redraws itself left-to-right in
  rose; at the rule's end the ✦ fills and blooms 1.0→1.25→1.0
  with `crossOff` landing at the bloom's apex; a 13pt italic
  "kept" settles beneath the mark; the line eases to 55% and
  rests. Never struck through, never checked — **countersigned**.
  (A short tap still opens the module — the row-tap law holds.)
- **Day complete (the colophon):** when the last line signs, the
  seals lift off their lines with a 60ms stagger and merge into
  a single filled ✦ beside the date eyebrow; one silk shimmer
  crosses the dateline; one warm swell. The date carries its
  seal for the rest of the day — the day is countersigned.
- **Why inevitable:** the ✦ already names "today" in the tab bar
  and signs jeni's accents; onboarding already taught that acts
  end in signing (her-file signature, hold-to-build). The one
  interaction only JeniFit could own — built from a glyph, a
  hairline, rose, and one haptic.

## 4. THE FORE-EDGE (becoming's pagination)

The roman folio is dead. Position is felt as remaining paper —
the leaves of a held magazine: a centered rail of 0.5-1pt
hairline ticks above the tab bar, one per page (~14pt wide, 6pt
gaps). Read leaves at 40% cocoa, unread at 15%; the current leaf
rose, slightly taller, sliding with a ~200ms ease as she flips.
No numerals anywhere.

## 5. The deletions (unanimous, 9/9)

Home: the second caps band; the truncated FROM JENI teaser; the
cycle banner (relocates to the profile hub); the steps chevron +
"counted for you" sub-line; the hamburger softens to a bare
glyph. Everywhere: every chevron; every radio circle; every
white container. becoming: "tap to open"; the roman folio; the
STARTED/NOW/GOAL tile row (→ ledger); folio_v6's duplicated caps
row. chat: bubble fills, tails, the trend card's border. evening:
the chip clouds reduce to one question per beat (progressive
disclosure).

## 6. Build order (mission 2)

- **V1a — the ceremony:** Home register rebuild + THE KEPT LINE
  + the letter's seal.
- **V1b — the issue:** becoming cover + contents + fore-edge +
  stat-table dissolution.
- **V1c — the interview:** chat bubble-ectomy.
- **V1d — the sweep:** evening sequencing, food still-life
  audit, remaining middle-register numerals, furniture
  standardization (the dateline spec identical on every room).

Frame-verify each phase against the onboarding beats; the stop
condition is the founder's: one design team, one vision.
