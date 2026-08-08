# APP v22 — ONE HAND

**Status: THE ERA'S LAW. 2026-08-07.** The founder's brief: Home and
Becoming are close enough — stop redesigning them. Propagate their
language across the ENTIRE product until it reads as one obsessive
designer's work: every screen, sheet, empty state, celebration and
settings page. The design is no longer the goal; the experience is.

v21 (`docs/app_v21/00_INSTRUMENT.md`) remains the visual law. This
document adds the PROPAGATION rules and the per-surface plan.

---

## 1. The consistency gate (every screen, before it ships)

1. Does this feel like Jeni — same paper, same rose, same serif
   numerals, same drawn strokes?
2. Would someone know this belongs to the same app as Home?
3. Does it reuse an existing component? A new component needs a
   reason an existing one cannot give.
4. Is any text replaceable by a shape the stores can honestly draw?
5. Would an Apple Design Award jury find a seam?

## 2. THE MODULE CONTRACT (B2C + B2B, one system)

Every capability is a MODULE — a mini-product, not a feature. A
module ships these faces, all in the one language:

| face | grammar |
|---|---|
| Home preview | a `JeniTaskRow` (owed/offered) and/or `JeniToolTile` with a live instrument |
| expanded | full-screen cover or detented sheet (the v19 physics) |
| detail | staged reveal: eyebrow → numeral → shape → words → provenance |
| history | rose charts + honest floors ("not enough to read yet") |
| empty | one sentence + the door; never a dead end |
| loading | drawn intelligence (never a spinner) |
| error | absorbed by the surface, retry in place (§5.6) |
| celebration | rationed per §4.7; one swell max |
| weekly read | an insight card (R6 grammar) when floors are met |

**Composition, not forks.** The UI never knows who authored a task:
`CarePlanEngine` composes for B2C; care-team assignments enter
through the same beats (v8 S4 authority model). A clinician-enabled
module = the same module, present; disabled = absent. The registry
of what is present comes from the protocol/care layer, never from
per-brand view code. The clinical register (unadorned ink) applies
to MEDICATION surfaces wherever they appear.

## 3. The propagation map (state → target)

| surface | today | v22 move |
|---|---|---|
| FoodTheme | pre-v20 palette, drifted | lockstep sync + rose ramp tokens (one fix recolors the package) |
| food scanner | poetic captions ("your moment"), glare-bar sweep | THE UNDERSTANDING: plain captions, rose rotating border, result chips land ON the photo before the sheet rises (honest — chips are the real result) |
| food result | serif heroes, no shapes, chips+ledger | keep the bones; add protein floor bar + the split; berry accents; photo stays the hero; paper corrected |
| food journal / plate detail | v11-era list | token sweep + rose sparks; photos lead |
| body scan capture | v11 language, sound | motion pass only (§4): arrival indices, rose where quantities appear; the clinical calm stays |
| body result / compare | strong bones | staged reveal indices + rose accents; never a number from a photo (unchanged law) |
| moments (close, weekly, milestones) | JeniMoment, compliant | audit accents + haptics only |
| chat | letter register | spacing/composer audit per §7 |
| settings + sub-pages | migrated v18-era | sweep: tokens, rows, chips; permissions pages speak plainly |
| the method | static 2-page lessons | THE RETHINK (§4 below) |
| paywall | exempt (standing directive) | untouched |

## 4. THE METHOD — the rethink

The founder: "Today it provides very little value. Do NOT polish
it. Question whether it deserves to exist."

**Verdict: the CONTENT deserves to exist; the FORMAT does not.**
Lessons-as-articles are a magazine's habit. What behavior change
actually uses: one idea, at the moment it applies, with one thing
to do about it — and the engines already know the moment (the
plan's beats, the day's state, the chapter).

**The new shape — ONE IDEA, ONE ACT:**
- A method moment is a CARD, not a page: eyebrow (the mechanism's
  name) → one serif claim → one drawn figure when the claim has a
  shape → ONE action row ("try it at your next plate" → opens the
  relevant module) → the citation whisper. 20 seconds, not 2 min.
- Delivery is trigger-matched, not scheduled: the idea rides the
  day that needs it (protein day → the protein-floor idea; dose day
  → the post-medication idea). The v7 "atomize into
  trigger-matched delivery" verdict, finally executed.
- History = "what jeni has taught you" — a quiet shelf of kept
  cards (pull, never push).
- B2B: `CareProtocol.supports`-style seam — a clinician can supply
  the card set; the surface is identical.

v22 ships the RE-SKIN + the card grammar on the existing curriculum
(CBT manifest stays the source); the trigger engine follows in its
own pass (engine work, founder-gated).

## 5. Decision ledger (v22)

| # | decision | why |
|---|---|---|
| E1 | FoodTheme syncs to the v21 palette + rose ramp; pin tests updated | one drift was recoloring a whole package off-brand |
| E2 | scan theater = honest chips (real result items landing on the photo), never fake progressive detection | provenance law extends to THEATER: never simulate understanding we don't have |
| E3 | scan captions go plain ("reading your plate…") | poetry died in v13; the package missed the memo |
| E4 | the result keeps serif heroes over paper, gains rose shapes | the reference's stat-card grid is Cal AI's voice; ours is numerals + instruments |
| E5 | the method becomes ONE IDEA, ONE ACT cards | value per second; the format was the weakness, not the science |
| E6 | module contract written; composition stays in the protocol/care layer | B2B without UI forks |

---

## 6. The first pass — shipped record (2026-08-07)

**FOOD (the briefed centerpiece) — shipped and filmed:**
- The palette came home (E1): FoodTheme had drifted a full era.
- The scanner: plain captions, halved sweep, the wait line only
  when honest, the idle prompt is the founder's own line ("add it
  before you eat").
- THE UNDERSTANDING chips (E2) live on the result photo, shared
  with the harness; the hero gained the protein floor bar and the
  plate split; the last heart retired.
- Films: scan theater (before/after), result with chips + shapes.
- The camera-permission primer leg joined the QA kit
  (`testGrantCameraOnce` — this sim runtime ignores simctl grants).

**QUEUED next session (mapped in §3, unbuilt):** body scan motion
pass · moments/chat/settings sweeps · THE METHOD card slice (§4 is
the binding design) · food journal/plate-detail sweep · the B2B
composition registry surfacing. The mission is explicitly
multi-pass; this record is where the next session resumes.

---

## 7. The product-wide audit — pass 2 record (2026-08-07)

Instrument: `testWalkEveryReachableSurface` (passed, 123s) filmed
end-to-end + mechanical drift greps (stale hexes · hearts ·
vocabulary) across both targets.

**Fixed this pass:**
- THE JENI FRAME: the scanner's rose border retired (the ordinary-
  camera tell + a border-law violation); four DRAWN corner strokes
  in the doodle register claim the aperture and breathe during a
  scan (`SnapJeniCorners`); `RotatingScanBorder` deleted.
- THE DISCOVERY: understanding chips now bloom a single fading
  ring as each lands — discovered, not shown (restraint is the
  intelligence).
- The polaroid share hero's surviving rendered ♥ retired; its
  stray pink went brand rose.
- `HerShareLabel` chrome left the pre-v11.5 ink (#3D2A2A → ink).

**Reviewed and held:**
- `BodySilhouetteRenderer` keeps its #FCFAF7 print stock — scan
  records are records; re-inking new renders would split her
  record's stock mid-history.
- Settings ("maya's space" + sub-pages) passes the crop test:
  serif heads, rose toggles, quiet rows — an editorial surface by
  nature, coherent on film.
- The chat normalizer's heart tables and JKReadingDay's VoiceOver
  stripper are hygiene, not renders.

**Found and QUEUED (the next pass's top items):**
1. **The workout cover is another app** — her75-era pink script
   title, sticker ornaments, pale plan numerals, and a start pill
   that reads disabled. The audit's largest drift; rebuild on the
   module contract.
2. The method lesson sheet is ALREADY interactive (claim + two
   choice cards) but sparse — the ONE IDEA/ONE ACT card (§4) fills
   it: figure + action row + citation.
3. Body scan chamber/develop/result: motion indices + §4 audit
   (unwalked on film this pass).

---

## 8. Pass 3 — the scanner sharpened (founder notes, 2026-08-07)

Shipped and frame-verified:
- **Precision brackets** (note 2): the drawn-wobble corners retired
  for exact quarter-bend white brackets (Vision Pro / Halide
  class); the breathing survives — identity lives in motion and
  discovery now, not linework. E4-b: the founder's precision call
  OVERRODE the doodle frame — the doodle register stays for icons,
  never for instruments.
- **Magnetic chips** (note 3): the cluster rings the meal region
  with berry anchor stems pointing into the plate; positions clamp
  so no chip ever clips the glass. HONEST anchoring: we hold no
  per-ingredient coordinates, so chips attach to the MEAL — E2
  forbids inventing ingredient positions until the EF ships boxes.
- **The complete grammar** (note 5, overriding E4): the serif kcal
  stays the signature; protein leads a full-width card (floor bar +
  adequacy word); carbs · fat · fiber · sugar · sodium follow as
  soft white cards, three across; the split closes. Uncollected
  fields stay silent.

**BOUND, next pass (note 1 + 7 — too structural to rush unverified):
THE IMMERSION.** The capture becomes full-bleed and the scene never
cuts: (1) `cameraLayer` ignores safe areas, the paper surround and
below-frame toolbar retire; (2) chrome floats on glass over the
feed (close · flash · mode pills · shutter); (3) capture freezes
the same full-bleed frame in place — zero geometry change — then
chips land, then the sheet rises: one continuous scene, "I watched
it understand my meal." Verify every in-frame state on film
(gallery preview, failure card, zoom, share slide) before it ships.
