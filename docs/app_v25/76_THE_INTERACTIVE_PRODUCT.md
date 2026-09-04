# PASS 76 — THE INTERACTIVE PRODUCT

**feat/app-v2 · built 2026-09-03, after 75, same session.** The
founder's brief: walk the whole shipped product and raise interaction
quality — game-quality response, not gamification; simpler, faster,
quieter. Continue p75's discovery that the craft exists and the
choreography hides it.

## 1 · Method

Cross-product walker-arm drives with recordVideo running, scrubbed at
10–30fps; a11y frame dumps as the measuring tool; a paint probe when
frames and code disagreed. Surfaces walked: Home (p75 state), the scan
chooser and both its doors, the stated-plate loop end to end, THE BOOK
→ plate page → repair sheet, Becoming (arrival, all five lenses, tile
faces, the weight page), the dose ceremony, the weigh-in ritual, jeni
chat (chip → send → response), rapid-cycle stress (tabs ×6, chooser
open/close, BOOK open/close, scroll), SE and AX5.

## 2 · What was found and fixed

① **The words door exposed the stage** (the pass's first find, filmed
at 30fps): `closeChooser` dismissed the chooser overlay, waited a
deliberate 0.28s, THEN presented the capture cover — Home stood fully
visible between her typed sentence and its reading, twice per food
log. The chooser is an in-tree overlay, not a UIKit presentation, so
nothing ever conflicted: cover destinations (.snap, .foodDescribe) now
present immediately OVER the standing chooser and the chooser leaves
silently underneath. Sheet destinations (the again rail) keep the
visible hand-off — a sheet never owns the stage. Refilmed: the cover
stands ~240ms after send with the reading assembling inside it; the
camera door cuts clean to its dark surface (evidence 01–03, 21).

② **BECOMING WAS BLANK — a p75 regression, caught and bisected.**
[CORR p75] The inset-derived masthead scrim queried UIApplication's
key window during body evaluation; with that call in the tree the
becoming tab rendered NOTHING — every element present in the a11y
dump, zero pixels on screen, buttons hittable and invisible (the p63
opacity-0 class at page scale). Bisected by substituting a constant
(page renders) vs the UIKit read (blank). The scrim now reads
GeometryReader's own safeAreaInsets — same law, no UIKit in a view
body. p75's lesson recorded: a KIT-level change demands films of
every consumer; p75 filmed only Home (evidence 04–06).

③ **Becoming's arrival: never behind an await, and armed at the
visit.** The arrival flip sat AFTER `await SleepService.nightHistory()`
— a HealthKit stall left the whole page invisible; and the flip ran at
app launch (the tab tree mounts behind today), so becoming's one
choreography always played to a covered stage — the p75 conductor
class, second instance. The flip now arms at the first actual visit,
before any await; sleep data lands into the settled page. Filmed: the
page composes at the tab switch — bars rise, the hero chart traces
(evidence 07).

④ **The weight page's dead paper, paint-probed.** ~80pt of void stood
between the pinned range chips and the hero numeral, and the era
ledger + the whole-distance door parked under the floating tab bar.
Three hypotheses died on measured frames (safe-area content inset ×2,
flight geometry) before a paint probe named the culprit: JeniScopeBar
— a ScrollView, greedy for whatever height its host proposes — was
swallowing the header's slack. The bar now pins its own measured chip
height (the E8.2 measured-stage pattern, kit-level, every type size);
the weight page's numeral moved y 229 → 157 and the ledger cleared
the bar. Verified QA16 standard, SE standard, becoming AX5
(evidence 09–11, 16–18).

## 3 · Walked and left alone (the honest half)

- **Lens changes** (becoming + weight page): fast content swap, chip
  ink-morph, bars redraw with life, no flash. Good (evidence 08).
- **The dose ceremony**: label morphs to "taken", dwell, dismissal,
  and p75's standing compresses to its quiet done-line — one film
  shows the whole loop (evidence 12).
- **Chat**: bubble inserts instantly, honest typing dots, composer
  flips to a stop-state while streaming, response carries live record
  data. No AI theater. Left alone (evidence 13).
- **The correction loop**: BOOK → plate → "fix this plate" — portion
  chips as direct manipulation, "keep the fix" disabled until a
  change exists, "leave it as it was" always present (evidence 14).
- **The weigh-in ritual**: composed; ruler drag is a device check
  (synthesized drags can't exercise it) (evidence 15).
- **Rapid-cycle stress**: tabs ×6, chooser open/close, BOOK
  open/close, scrolls — a luminance scan over the whole film found
  zero flash-level discontinuities outside the launch fade.
- **The plate-landing morph, the entrance, the strip trace**: p75's
  work, re-observed incidentally in many of this pass's films, holds.

## 4 · Chased and exonerated

- **The dose standing "dead tap"**: two walker runs showed a tap on
  the standing row doing nothing at +7s after launch. Instrumented
  present()/dismiss() with os_log and re-ran: present() fired and the
  sheet stood — the earlier failures were the walker racing variable
  launch time (its cached hit point predates the entrance), not a
  product defect (evidence 19).
- **The weight page "won't scroll"**: the walker's slow swipe dwells
  >0.18s and reads as the chart's hold-then-scrub (p74's own law); a
  human flick passes to the scroll. Named for the device walk.
- **The p75 hydration flash** (receipt "8 meals" → "6 meals" mid
  entrance): the QA seeder rewriting the store after Home's first
  snapshot — QA-door artifact, not a customer path.

## 5 · Tried and rejected

- `.fixedSize(horizontal: false, vertical: true)` on JeniScopeBar —
  inert against ScrollView height greed (measured, frame-identical).
- Removing the expanded layer's `.ignoresSafeArea()` — moved the whole
  sheet down 59pt and left the void untouched; reverted. The void was
  never a safe-area artifact.
- A host-side `typeSize.isAccessibilitySize ? nil : 48` cap — fixed
  standard sizes, reopened the void at AX; replaced by the kit's
  measured pin.

## 6 · Proof

- **App unit suite: 1690 tests · 2 skipped · 0 failed** — the exact
  p75 baseline. No new pins: this pass's changes are presentation
  timing and geometry with no new pure rules; measured a11y frames
  and before/after films are the proof (all retained in
  `76_evidence/`, 21 items).
- **PlankFood 319/319.** **Release BUILD SUCCEEDED.**
- Production: no migration, no schema, no SQL, no deploy, no
  customer-row mutation. Chat/EF calls were the shipping read paths
  on the standing QA account.

## 7 · Named, not done

- Device checks: ruler drag feel, chart hold-then-scrub, sheet
  physics (rubber-band + flick), haptic timing against visual
  commits, ProMotion behavior of the flight/expansion.
- The whole-distance ink scene re-film (its door needs the weight-page
  host; the scene itself is p74-verified and untouched).
- SE-AX5 walk INTO the weight page (becoming AX5 verified; the
  whole-story tap misses at AX5 under the walker).
- The repair sheet rests taller than its resting content (room is
  pre-reserved for the inline editor) — judged defensible, left.
- The X on the weight page rides the chips' row at SE — borderline,
  left; worth one look on hardware.
- p70–p75 standing lists.
