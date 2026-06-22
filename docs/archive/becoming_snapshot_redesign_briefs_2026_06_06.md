# Becoming snapshot redesign — 3 luxury fitness designer briefs

**Date:** 2026-06-06 (second-round after first synthesis shipped)
**Trigger:** Founder reviewed the just-shipped minimal-functional Becoming and pushed back:
> "becoming screen is still too busy with all the list of logs and there's no snapshot feeling of showing everything in one snap in the screen."

**Goal:** Compress Becoming from a 9-section vertical magazine into a one-viewport snapshot dashboard. Minimalistic luxury fitness designer POVs (Equinox+, Apple Fitness, Whoop/Oura) consulted in parallel.

---

## Cross-brief unanimous verdict

**Kill on Becoming above the fold:**
- All 5 chapter spreads (roman numeral eyebrow + italic title + pull caption + 36pt sticker + hairline = ~80pt × 5 = 400pt of pure pacing chrome)
- The page hero "you're / *becoming* steady." in its current 40pt form (becomes a 13pt status line or one-line subhead)
- Activity calendar (it's navigation, not metric — drill-in only)
- Legacy barrier/plank/recent-sessions modules at the bottom (v0 dump)

**Compress / migrate:**
- Steps + Breath + Workout sessions → ONE combined movement signal (3 rings, or a dot strip, or a single composite tile)
- Food chapter → one quiet tile (food isn't yet the hero rail — coming with v1.0.7+)
- Barriers + NSV wins + plank mastery curve → drill-in detail surfaces, not first-viewport tiles

**Editorial register survives only:**
- ONE italic punch word per scroll position (the "becoming *steady*" line, the status word at top-right, the closing weekly caption)
- Below the fold = curiosity-tapped surface where chapter spreads CAN belong

---

## Brief 1 — Equinox+ / Peloton luxury fitness (Cartier-frame POV)

**First viewport (600pt) — 5 tiles, no chapter spreads, no 40pt hero header:**

1. **Status bar (28pt)** — `tuesday · week 6 ♥` left + `↗ steady` italic Fraunces 13pt jeweledRose right. The Cartier frame — she glances top-right and knows her state before reading a single number.
2. **Weight + trend tile (full-width, 168pt)** — left half: `142.3` Fraunces Light 64pt cocoa-100 tabular + unit + delta. Right half: jeweledRose sparkline, 28 days, target dotted line.
3. **2-up secondary (132pt each)** — Streak tile (count + day-of-week dot strip) | Plank PR tile (time + mini mastery arc).
4. **Today rings strip (full-width, 96pt)** — 3 concentric rings (steps · breath · session) with numerals + italic line `today's *moved*` on the right.
5. **Coach voice line (88pt)** — one sentence DM Sans 15pt cocoa-72, italic punch on verb. No avatar, no card, no chapter cover.

**Equinox+ specific move:** the contextual top-right state word (`↗ steady` / `↗ losing` / `→ holding` / `↘ regaining`) — concierge tell, computed from the 28-day EMA slope. *She opens the app, glances top-right, knows her state before reading a number.*

---

## Brief 2 — Apple Fitness+ (full-bleed stacked discipline)

**First viewport (600pt) — 5 elements, full-bleed stacked, no card chrome, only 0.5pt cocoa-12 hairlines between:**

1. **Identity strip (44pt)** — "you're *becoming* steady." DM Sans 18pt, italic Fraunces on punch word. The ONE editorial gesture above fold.
2. **Weight hero (180pt full-bleed)** — left third: 64pt Fraunces Light digit + DM Sans 13pt delta. Right two-thirds: 60pt jeweledRose sparkline 30d with single dot on today.
3. **3 rings (140pt full-bleed)** — Movement (steps vs 7,500), Nourishment (plate kcal vs target), Practice (workout + breath + lesson; any one closes). 96pt rings centered left, 3-line legend right.
4. **Streak + PR row (44pt)** — two equal columns split by 0.5pt cocoa-12 hairline. Left: "14 day streak ♥". Right: "plank PR 1:42."
5. **This week mini-bar (100pt)** — 7 vertical bars M-T-W-T-F-S-S. Today jeweledRose, prior cocoa-72, missed cocoa-12. Caption "5 of 7 days, *steady*."

**Total: ~508pt + 44pt safe area = clean fit.**

**Below the fold = the curious tap:** weight detail (90-day chart, BMI band, goal pace projection), activity calendar, barrier-resolved card, plank mastery curve, recent sessions list, NSV wins, identity prose. **The chapter spreads weren't wrong, they were misplaced.** They belong below the fold as section headers where a user who scrolled has signaled curiosity and earned the magazine treatment.

**Apple's line:** above fold answers "how am I doing today and this week?" in one glance. Below answers "tell me the story."

---

## Brief 3 — Whoop / Oura (one primary score POV)

**The ONE primary score: "the becoming index."** 0-100, top of screen, Fraunces Light 72pt cocoa-100. 14-day rolling composite of *showing up* (workouts + breath + steps days) × *trend direction* (EMA weight slope vs goal pace).

**Why this beats alternatives:**
- Weight delta = Noom 2018; loses on bad scale/GLP-1/hormonal days
- Streak = post-Duolingo-streak-anxiety bait; cohort burnt out
- Plank PR = vanity capability, not weight-loss outcome
- Cumulative days = no signal about this week vs last

**The becoming index** answers ONE question in 1.5s: *"am I actually becoming the version of me I came here for?"* Blends behavior (her control) with trend (what she came for), so a bad scale day doesn't tank if she showed up, and a great scale week without effort climbs slower than an earned one. *Defensible as JeniFit-native — Cal AI/MFP/Noom literally cannot show this because they don't have her identity work or her plank curve.*

**4 contributing tiles (2×2 grid below the score, 120pt tall each):**
- **trend** — weight EMA delta + 14d sparkline
- **rhythm** — days shown up this week + 7-dot strip (streak-replacement showing cadence not unbroken chain)
- **strength** — plank PR + 6-week mini-curve
- **fuel** — 7-day kcal-avg if logged, else "tap to log"

Tap any tile → drill-in sheet with the long-form chapter content. **That's where the chapters survive.**

**The Oura signature move:** tap the 72pt primary index number itself → tiles slide down 80pt and a horizontal stacked bar appears showing the 4 contributors' weight in today's score (rhythm 38 · trend 22 · strength 18 · fuel 12). Each segment shaded as the tile's accent. *She sees WHY her index is what it is, mathematically, in one glance.* No modal, no nav push — the screen reorganizes around the question she just asked.

---

## Recommended synthesis

**Equinox+ + Apple hybrid (most pragmatic + brand-aligned):**
1. **Status strip** — date + state word jeweledRose top-right ("↗ steady")
2. **Weight hero** — full-bleed, 64pt Fraunces Light digit + jeweledRose sparkline (this is already shipped — needs full-bleed placement + state-word context)
3. **2-up secondary tiles** — streak count | plank PR
4. **Today movement strip** — 3 rings OR 1 composite tile (steps · breath · session) with italic caption
5. **Coach voice line** — one sentence, no card chrome

**Below the fold:** food tile + activity calendar + barrier card + plank curve + NSV rotator + recent sessions (drill-in surfaces, can keep editorial register here).

**Defer the Whoop "becoming index"** — creative but introduces a new derived metric requiring its own brief + math definition + onboarding explainer. Worth a separate phase.

---

## Open decisions for founder

1. **Primary score** — keep weight as the hero (Equinox+ / Apple), OR build the Whoop "becoming index" as a new composite metric in a separate phase?
2. **Apple rings vs Equinox+ rings strip vs 1-composite tile** — three flavors of movement summary, three implementation costs
3. **Status word top-right** — adopt Equinox+'s concierge tell ("↗ steady")? Voice-locked phrasing needs new vocabulary work
4. **Chapter spreads** — kill entirely OR survive below the fold as section dividers for the curious tap?
5. **Activity calendar** — drill-in only? Or keep below-fold inline?
