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
