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
