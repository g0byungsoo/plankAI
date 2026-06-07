# Tool-first reset — WL design expert + Gen-Z cohort researcher

**Date:** 2026-06-06 (founder feedback round 7)
**Trigger:** Founder rejected the "becoming powerful" abstract identity hero. Quote:
> "it's emphasizing user's abstract goal (which is like 'powerful') but i don't think this helps users in any way. the goal of metrics page is to inform user how she's doing and how's she's approaching to the goal and how's she's utilizing this app."
> "right now, app needs to serve women who want to lose weight as a tool. once the app is proven to be useful by women, maybe we can later put some more respect component into the app."

2 expert briefs spawned: **WL iOS design expert** (MyFitnessPal / WW / Lose It / Lasta / Cal AI veteran) + **Gen-Z women WL behavioral researcher**.

---

## Cross-brief unanimous verdict

### Kill the identity hero
Both: "becoming powerful, day 47 ♥" dies on the default Becoming tab. Abstract identity affirmation belongs in 3 surfaces ONLY:
- Post-session celebration (already there)
- Milestone unlocks (5lb down, 30-day streak)
- Sunday weekly recap card

Default tab = concrete numbers.

### The 6-7 metrics that get tapped (consensus order)
1. **Weight delta / trend** ("down 3.2 lb since started" + EMA sparkline + 7/30/90 toggle) — when she has weight data
2. **Projection / ETA to goal** ("at this pace, Sept 12" + "5.4 lb to go · losing 0.6 lb/wk") — *the highest-leverage card for trial→paid*
3. **Weekly activity rollup** (workouts + steps + breathwork — count vs target)
4. **Streak / consistency** ("12 days showing up" or "logged 5 of 7 days")
5. **Last-week vs this-week comparison** — concrete deltas
6. **Plank PR + workout count** — JeniFit-specific receipt
7. **Lesson + breathwork progress** — utilizing-the-app rollup

### The PROJECTION card is the conversion-driver
Both briefs flagged this. Cal AI's projection has the highest dwell time on the stats screen; Lose It saw similar. The format both proposed:
- "at this pace, **Sept 12**" (italic-Fraunces on date)
- "5.4 lb to go · losing 0.6 lb/wk · 9 weeks"
- Stalled-pace fallback: "pace slowed — try logging food this week" (action, not shame)
- Over-1%/wk fallback: "aim for 0.5-1 lb/wk for sustainability"

### The low-weight-engagement problem (founder's PostHog observation)
~62% of opens have stale weight data (>4 days). When weight data is stale:
- **Auto-captured signals MUST carry the tab** — steps (HealthKit), workouts (session_logs), breathwork
- Weight becomes a *bonus* layer
- "You've logged X of last 30 days" honesty card with soft 1-tap log CTA

### Voice register shift — tool-first direct
**Locked → still avoid:** crush, shred, burn, earn, AI, BMI, before/after photos, identity hero on default
**UNLOCK for tool-first:** "deficit" (food rail context only), numerical before/after ("162.4 today · 168.6 at start · -6.2 lb")

Rewrite examples (the cohort prefers direct):
| Old (editorial) | New (tool-first direct) |
|---|---|
| "becoming powerful, day 47 ♥" | "-3.2 lb in 6 weeks. losing 0.5 lb/wk." |
| "no catching up needed ♥" | "logged 4 of 7 days this week." |
| "you've shown up 4 days this week" | "4 workouts, 2 breathwork, 6.2k avg steps." |
| "we noticed you haven't weighed in" | "last weigh-in: 9 days ago. log to update your trend." |
| "your becoming continues ♥" | "at this pace, you hit 145 lb by Sept 12." |

**Italic-Fraunces budget:** 1 punch word per Becoming open MAX (on trend card or projection date).
**Hearts:** 0-1 per Becoming open.
**Hearts move to:** milestone surfaces + Sunday recap only.

### The "Useful tool" definition (from behavioral research)
> "When she says 'tool not journal,' she means: **answers a question in under 2 seconds without me writing anything.**"

Useful tool = Cal AI photo→calorie, MacroFactor TDEE recalc, Apple Health auto-step.
Wellness journal = mood check-ins, identity affirmations, gratitude prompts.
The cohort tolerates ONE journal-y screen per week (Sunday recap), not a journal-y default tab.

---

## The 6-card Becoming layout (synthesis)

1. **Weight Trend Hero** (180pt full-width, scrapbook chrome) — Fraunces Light number + delta + 30-day sparkline + 7/30/90 segmented toggle. Empty state: tap-to-log CTA. When stale-data: step/workout trend takes this slot.
2. **Projection Card** (110pt left half, accentSubtle fill) — "at this pace, **Sept 12** / 5.4 lb to go · 0.6 lb/wk · 9 weeks." *The conversion-driver.*
3. **This Week Activity** (110pt right half, pageIvory) — three rows: workouts 3/4, steps 6.2k avg, breathwork 4 days.
4. **Streak Card** (80pt full-width thin) — "12 days showing up" + 7-pearl dot row.
5. **Plank PR + Lesson Progress** (90pt 2-up) — "1:48 best hold" / "8 of 14 lessons."
6. **More depth** link.

When stale weight data, **swap card 1** for step/workout-trend hero with same chrome treatment.

---

## Open decisions for founder

1. **Identity hero — kill entirely on default Becoming?** (vs move to Sunday recap surface only)
2. **Unlock "deficit"** in food rail context for tool-first feel?
3. **Build the Projection card** — needs ACSM-aligned pace math + goal date computation + stale-pace fallback messaging. Worth the lift.
4. **Weight trend hero swap** — when she has <2 weight logs, show a steps/workout trend card instead of an empty weight card?
5. **Voice register shift** — adopt the 5 rewrites and the "italic-Fraunces 1-per-tab + hearts 0-1-per-tab" budget across Becoming?

---

## Cited briefs (this round)

- WL iOS design expert (MFP / WW / Lose It / Lasta / Cal AI veteran)
- Gen-Z women WL behavioral researcher (200+ session recordings)
