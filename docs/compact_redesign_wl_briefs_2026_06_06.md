# Compact one-snapshot redesign — Cal AI + Noom-2024 + Lasta briefs

**Date:** 2026-06-06 (founder feedback round 5)
**Trigger:** Founder reviewed the just-shipped Home + Becoming and pushed back HARD on three things at once:
> "the overall feeling is i feel like jenifit theme is gone from the design. and the UI is still too busy with so many things. ... for becoming screen, i was expecting to have some compacted design with one snapshot ... i don't like scrolling ... with cute jenifit design."
> "for home screen ... as a user point of view, i don't know what do do instinctly (as focus is everywhere) ... food card is too mundane with white color ... i don't even know what 4 of 14 days mean."

3 WL category designers (Cal AI / Noom-2024 / Lasta) spawned in parallel.

---

## Cross-brief unanimous verdict

### Becoming — ONE snapshot, kill below-fold
All 3 agree: **kill barrierCard, plankCard, recentSessions, BMI, WHO ring, plank Mastery** above the fold. Move to a single "more depth ↗" link OR delete entirely. Becoming is a portrait, not a research paper.

Snapshot composition (very close convergence):
1. **Weight hero** ~200-240pt — Fraunces 72-88pt digit + delta line + sparkline
2. **Pace / projection line** — single sentence ("on pace for *september* ♥" / "5.0 lb lighter than 3 weeks ago")
3. **2-3 stat tiles** (plank PR, streak/shown-up, optional WHO movement)
4. **Identity line** pulled from Q140/Q111 ("the woman who *shows up*")
5. **"more depth ↗"** link to secondary detail surface

### Home — "+12 more" + "feeling it differently" + "day 4 of 14" all DIE
All 3 agree: **kill the 14-dot strip** ("counter pretending to be a story" — Lasta; "diet-culture progress theater" — Noom). Confuses users by conflating lesson arc with session count.

All 3 agree: **"+12 more" and "feeling it differently" disappear into the start flow** — moved to a pre-session sheet, not Home chrome. Home is where you commit, not where you edit.

### Home — JeniMethod lesson should be hero
All 3 agree (with conviction): **JeniMethod lesson IS the hero**, not workout. The 75% lesson completion vs 23% workout completion is the loudest signal. Workout becomes a peer tile.

### Pink + cute reinjection — same rule
All 3 agree:
- **Cute is atmospheric, not operational** (Cal AI)
- **Pink is a moment, not a surface** (Noom)
- **Cute on the dream, restraint on the work** (Lasta)
- Stickers cluster at card CORNERS with slight rotation (-8° to -12°), never centered
- Pink lives on: ONE hero card backdrop, the +direction arrows, the heart ♥ punctuation
- Pink stays OUT of: workout chrome, weight numerals, settings/menu, error states, navigation

---

## Where they diverged (real forks)

### Food card chrome
- **Cal AI**: pageIvory base + 40% radial wash of accent rose top-right (gradient avoids pastel-baby). Cherries 32pt bottom-right at 40% opacity, clipped (reads as backdrop pattern). Whole-card tap, no numerals visible until logged ("avoids the 0 cal shame").
- **Noom**: pageIvory base, NOT pink fill. Card carries warmth via (1) 1.5pt accent-rose gradient stroke, (2) cherries 32pt top-right -12° rotation, (3) calorie number in a soft-pink 18% tint rounded container with 0.5pt cocoa hairline. "A pink rectangle is Flo. A cherry-stickered ivory card with a tinted number well is JeniFit."
- **Lasta**: **accentSubtle solid fill** (#F5D5D8), 28pt radius. Cherries 56pt top-right -12° + sparkleGlossy 14pt bottom-left. Italic-Fraunces "*what you ate*" 14pt jeweledRose eyebrow. **Solid jeweledRose CTA pill** "+ add ↗" (not outline — "pink + outline reads weak").

→ All 3 agree on cherries-sticker placement and italic-Fraunces eyebrow. They disagree on **fill** (gradient wash vs ivory + accent stroke vs solid pink fill) and **CTA color** (cocoa pill vs jeweledRose pill).

### Hero on Home — Lesson vs Workout
- **Cal AI**: workout pill is THE hero (single biggest CTA), JeniMethod card stays but compressed to 130pt half-width-feeling letterbox. Founder's 23% workout completion is "we buried the CTA" problem, not a misalignment.
- **Noom**: workout hero — 23% completion = surface problem not strategy. Move "+12 more" + "feeling it differently" into pre-session sheet. JeniMethod gets a swipeable lesson card secondary.
- **Lasta**: **JeniMethod lesson IS the hero**. 75% completion data settles it. Workout becomes a half-width tile with accentSubtle fill.

→ **2 of 3 (Cal AI + Noom) vote workout hero**, **1 vote (Lasta) lesson hero**. **BUT** previous founder confirmation (round 4) already established lesson as hero via the iOS UX brief. Need founder to reconfirm given this new vote.

### Becoming weight digit — italic or upright?
- **Cal AI**: Fraunces 88pt **NOT italic** (the founder's locked direction; reaffirms)
- **Noom**: Fraunces 72pt cocoa (doesn't specify italic — implied upright per voice lock)
- **Lasta**: Fraunces Light 72pt cocoa-100 (upright)

→ All 3 align with the voice lock — numerals never italic. Already correct.

---

## Recommended synthesis (path of least regret)

**Becoming snapshot — Noom-leaning hybrid:**
1. Hero band 220pt: weight Fraunces 72pt + "lb · *today*" eyebrow + italic-Fraunces "*5.0 lb lighter* since you started" + **bowSatin 32pt top-right -8° rotation**
2. Trend ribbon 120pt: wide EMA sparkline cocoa-72, no axis, accent-rose 12% fill underneath
3. Pace pill ~70pt: accentSubtle fill, "on pace for *september* ♥" sparkleGlossy 14pt left-anchored
4. Identity line ~90pt: italic-Fraunces "the woman who *shows up*" pulled from Q140/Q111
5. Two stat tiles: plank PR + streak. cherries + heartGlossy
6. "more depth ↗" link to detail surface (barrier card, plank mastery, recent sessions live there)

**Home compact — convergence:**
1. Greeting strip 56pt: "morning, *jeni* ♥" italic on name. Hamburger → thin 3-dot menu.
2. **Hero ritual card 260pt** — pageIvory, 28pt radius. JeniMethod OR workout (founder pick). Italic eyebrow + DM Sans headline + cocoa "begin →" pill + flower3D 36pt top-right -8° overlap.
3. Two half-width tiles 140pt each: workout (accentSubtle if lesson is hero) + weight (cream + cocoa-12 hairline)
4. **Food card 160pt** — pink + sticker + jeweledRose CTA pill (pick chrome direction)
5. Today strip 88pt: steps · breath single row, cocoa numerals
6. **No 14-dot WeekProgressStrip.** **No "+12 more". No "feeling it differently".** Move both to a pre-workout sheet.

---

## Open decisions for founder

1. **Home hero** — JeniMethod lesson (Lasta + earlier founder pick) OR workout card (Cal AI + Noom)?
2. **Food card chrome** — gradient wash (Cal AI) / ivory + accent stroke + tinted number well (Noom) / solid accentSubtle pink fill (Lasta)?
3. **Food CTA pill color** — cocoa outline (matches new pill tier) OR solid jeweledRose pink (Lasta)?
4. **Becoming "more depth" sheet** — build now (detail surface for barriers / plank / sessions) OR delete those modules entirely?
5. **WeekProgressStrip** — kill entirely (all 3 agree) OR keep simplified (e.g., just "you've shown up *4 days* this week ♥" as a one-line caption)?
