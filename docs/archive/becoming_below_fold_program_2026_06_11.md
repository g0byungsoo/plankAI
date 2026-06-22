# Becoming Below-the-Fold: Round 3 Brief — What Fills the Cream, and When
**Author:** Weight-loss program design expert (behavioral science, post-GLP-1 landscape)
**Date:** 2026-06-11 · Builds on round-1 program brief + round-2 cohort brief + locked v1.1 plan.
**Live state reviewed:** IMG_6339.PNG, founder device, day 3 of 84. One weigh-in, 3 scan-days, 0 checklist days.

---

## §0 URGENT FIRST: the trend card is currently an attrition machine (fix before any new module)

What the live card says on day 3: **"up 5.7 lb"** in hero italic serif, "149.0 today · 143.3 at start."

Three compounding failures:

1. **It's a cross-instrument delta.** "143.3 at start" is the onboarding self-report; "149.0 today" is a scale. Women under-report self-reported weight by 1-3 kg systematically (Connor Gorber et al. 2007, systematic review). Much of that 5.7 lb is measurement artifact, not mass. **Rule: never compute a delta across the self-report → scale boundary. Baseline = first in-app or HealthKit weigh-in, full stop.** The onboarding number seeds the goal engine only.
2. **n=2 points is not a trend.** Normal day-to-day fluctuation is 1-2 kg from water, glycogen, sodium, cycle phase (White et al. 2011). The Helander 2014 EMA we cite as the safety layer needs coverage; with two points it IS the noise. Rendering a hero delta here is data-provenance violation by spirit: the number is real, the claim ("your trend") is fabricated.
3. **A gain headline at peak attrition.** Weeks 1-4 are the dropout cliff (Eysenbach 2005). Perceived early failure triggers the abstinence-violation spiral that precedes quitting (Marlatt & Gordon 1985), and unrealistic early expectations meeting a "+5.7" verdict is the textbook dropout sequence (Dalle Grave et al. 2005). The kind caption underneath does not undo a 40pt "up."

### Evidence-correct render ladder for the trend artifact

| State | Gate | Hero renders | Delta renders |
|---|---|---|---|
| **Calibration** | <3 scale weigh-ins OR <7 days span | Words only: "your line is calibrating." Dots plotted small, no connecting line, no delta anywhere. Expectation pre-load as the caption: "early numbers wander 2-3 lb day to day. water, not weight. your trend starts at week two." | Never |
| **First trend** | ≥3 weigh-ins across ≥7 days | EMA line draws. Hero = direction words ("settling," "drifting down, gently," "holding") | Words only; numeric delta lives in depth sheet |
| **Full artifact** | ≥14 days coverage | Current design (language delta + small numerals) | Yes, language-first, vs EMA not vs single day |

Up-weeks after the gate: words-first plus a physiology line, never "up X lb" as hero (Ogden & Whyman 1997 mood-decrement evidence; round-1 §4.4 library). The locked plan's adherence-variant swap (<2 weigh-ins in 14d) is necessary but insufficient. She HAS 2 points, so the swap didn't fire. Add the delta-suppression gate above. **This single fix outranks everything below.**

### "0 of 7" verdict: demoralizing, and on this screen, false

Two problems. (a) Zero-state framing: Koo & Fishbach 2012 (small-area hypothesis) show early-stage motivation comes from attending to accumulated progress; a fraction whose numerator is 0 carries no motivational content, only deficit. (b) **It's not even true to her week.** She scanned plates on 3 of 3 days. If "this week" counts only completed checklist days while her dominant engagement act (camera, 47% paid adoption, round-2 §1) counts for nothing, the tab is misrepresenting her own evidence. Fix: the week count uses the engaged-day definition (ANY completed row, scan, lesson, or movement = a filled dot), matching the derived engagement-day logic. Her screen should read "3 of 7." And when the true count is 0 (first Monday, fresh week), suppress the fraction entirely: dot row alone, today's dot ringed, optional words ("week one begins"). A fraction earns its render at count ≥1.

---

## §1 Journey phases (render clock for everything below)

- **P-A Settling** · days 1-7 · attrition peak begins; scale has zero signal; she has process data only.
- **P-B Proving** · days 8-21 · the "is it working?" war (round-1 §4); trend barely emerging; this is where retention is won or lost (Unick et al. 2014; Nackers, Ross & Perri 2010).
- **P-C The middle** · days 22-56 · plateaus arrive on schedule (adaptive thermogenesis, Hall et al. 2011); NSVs must carry weeks the scale won't.
- **P-D Becoming her** · days 57-84 · habit consolidation window (~66-day median, Lally et al. 2010); identity + maintenance framing.

Design law for the empty cream: **do not fill it at day 3.** A below-fold that grows as her evidence accumulates is itself the product ("the tab that fills in is the artifact"). Day-3 below-fold = three rows max. Whitespace is the clean-luxury brand, not a bug.

---

## §2 Ranked below-fold modules with gates

**1. Evidence Ledger ("what bends the line") — the P-A/P-B hero. Renders from day 1.**
Process evidence as the primary early answer to "is it working?": scan-days, steps average, lessons read, movement minutes, each as a quiet receipt row. Early self-monitoring adherence is the best available predictor of her 6-month outcome (Burke, Wang & Sevick 2011; Unick 2014), so this is honest leading-indicator evidence, not consolation. One closing line does the expectation work: "the women who do what you did this week are the ones whose trend bends by week four." At day 3 it has real content (3 scan-days, steps) while the checklist is empty. This is the module that carries the round-1 §4 week-2 load. Demotes below the chapter map after day ~28.

**2. Next-Milestone line — renders from day 1.** "4 days to week one, complete." Zero input, goal-gradient acceleration near subgoals (Kivetz, Urminsky & Zheng 2006). One line, not a card. Promoted from round-2 §3 item 7; perfect day-3 content for exactly this empty space.

**3. Program Chapter Map — phase-gated rendering (answer to Q1).**
At day 3, an 84-cell grid with 3 filled cells is to-go framing: it heroes the mountain, and large remaining distance demotivates at the start (Koo & Fishbach 2012). her75 ships the full grid, but that's a 75-hard challenge cohort self-selected for grit; our TikTok-acquired beginners at the attrition peak are the opposite population. Render rules:
- **P-A:** chapter strip only. "chapter one" as a 7-cell row; 3 of 7 filled reads alive (43%), not desolate (3.6%). Future weeks = a count in words ("eleven chapters follow"), not empty cells.
- **P-B:** completed chapters compact to filled rows; current chapter zoomed; show at most current + next; the full map stays folded.
- **P-C onward (≈ day 22+):** full 84-cell map unlocks as an earned reveal (one-time bloom moment, soft haptic). Now ≥2 filled rows exist and goal-gradient pulls forward. This is the share artifact (round-2 §5: dated identity artifacts circulate, charts don't).
- Always: engaged-day dot for ANY completed row; missed days = neutral paper, never grey/red, no "broken" language.

**4. Weekly Recap slot — placeholder blooms at day 7, then every Sunday (P3 build, already queued).**
The first recap IS the week-2 expectation pre-loader: trend-calibration honesty + process receipts + one true NSV line (peak-end framing, Kahneman et al. 1993; fresh-start cadence, Dai, Milkman & Riis 2014). Before the P3 takeover ships, a static "week one chapter closes sunday" teaser row may hold the slot from day ~5.

**5. NSV / Barrier / Prior-Attempts trio — sequenced, not stacked (answer to Q3).** All three earn the slot at different gates; never more than one visible at once (rotation by recency of qualifying evidence):
- **NSV tile** · gates on first detected true event (could fire day 2 on a plank PR). Becomes the PERMANENT P-C resident: plateaus are physiologically guaranteed and NSVs are what sustain women through them (Epiphaniou & Ogden 2010; Wing & Phelan 2005).
- **Barrier-Resolved counter** · gates on ≥3 counter-evidence instances against her stated barrier (realistically day 7-14). Self-efficacy via accumulated mastery evidence (Bandura 1997; Annesi 2011; Rhodes & de Bruijn 2013).
- **Prior-Attempts mirror** · gates at programDay > her typical prior-attempt duration (≈ day 15 for the modal "about 2 weeks" answer). "past attempts lasted about two weeks. you're on day 23." is the strongest single sentence in the system, but only once the comparison is WON. Before that it stays out of module form (a forward-framed version at day 3 reads as a threat). Fine as an occasional insight-line rotation only after day 10.

**6. Eating Rhythm tile — gate ≥4 scan-days/wk holds (round-2 §6).** P-B entry for active scanners. Descriptive only.

**7. Cohort care-lines (answer to Q5): surface footnote, never depth-buried.** A protective sentence she never sees protects nothing. One line max, in the insight-line rotation, gated on cohort flag AND a live condition: GLP-1 + protein under anchor → sensitive eat-enough flag (lean-mass loss 25-40% of total in trials, Wilding et al. 2021; discontinuation ~50% year one, Gleason et al. 2024); peri + flat week → slower-pace legitimization (Greendale et al. 2019); short-sleep week (P4) → Nedeltcheva 2010 line. The GLP-1 protein line can promote ahead of P4: both inputs already exist (onboarding flag + scans).

**8. Pace Band — stays in the depth sheet** until HK body-mass import moves weight coverage (reaffirming round-2 demotion). A corridor with 1.3 points/week in it is a promise we can't draw. Re-evaluate after P2.

### Below-fold by phase, assembled
- **Day 3 (today):** Evidence Ledger · Next-Milestone line · Chapter-one strip. Nothing else. Cream stays cream.
- **Day 14:** Ledger · Chapter strip (2 rows) · Recap slot · first of the NSV/Barrier/Mirror trio · rhythm tile if gated in.
- **Day 30:** Full chapter map (hero, shareable) · NSV permanent tile · Recap · Ledger demoted · care-line as warranted.
- **Day 70:** Chapter map nearly full · maintenance-identity recap framing ("habits that outlive the program") · prior-attempts mirror at maximum honesty · graduation tease (scatter stays reserved for the earned moment).

---

## §3 Depth sheet (answer to Q4 + what stays down)

- **Plank Mastery Curve: depth.** Minority stream (63 starters/30d); meaningful at ≥3 check-ins; surfaces above the fold only as an NSV line on a PR. Bandura mastery framing survives in the sheet.
- **Lesson shelf: not a module anywhere on Becoming.** Home owns "do"; duplicating a content shelf splits the IA. Lessons appear as evidence (a count row in the Ledger, a recap line). Kill the shelf from the locked plan's below-fold list.
- Also depth: pace band (until P2), numeric weight deltas, weekly-smoothed energy view, recent sessions, full barrier history.

## §4 What still must NOT fill the space
Round-1 §6 kill list stands untouched: no calendar shame grid (the chapter map's neutral-paper rule is the only legal grid), no streak-loss mechanics, no red, no single forecast date, no daily-calorie hero, no leaderboards, no auto body comparisons. An empty viewport is better than any of these.

## Summary for the founder
Fix the trend card TODAY (delta-suppression gate + never delta across self-report boundary + calibration copy); change "0 of 7" to engaged-day counting and suppress zero fractions. Then let the below-fold grow with her: Evidence Ledger + milestone line + chapter strip now; recap and the NSV/barrier/mirror sequence through week 3; the full 84-day map as a day-22 earned reveal that becomes the thing she screenshots. The share-worthy artifact isn't a chart. It's the accumulating dated map of a program she's visibly living.
