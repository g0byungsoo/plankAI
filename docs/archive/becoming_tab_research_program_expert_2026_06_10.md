# Becoming Tab Research Brief — Program-Era Progress + Identity Surface
**Author:** Weight-loss program design expert (behavioral science + clinical weight management, post-GLP-1 landscape)
**Date:** 2026-06-10
**Scope:** What the Becoming tab should own now that Home owns "what to do today" (v1.1 program checklist). Cohort: TikTok-acquired beginner women 22-35, weight-loss motivated, anti-shame register. Hard constraint: zero new input burden, every number traces to a collected field.

---

## 1. What the evidence says sustains weight loss + retention once she's ON a program

**Self-monitoring works, but only when frictionless and feedback-rich.** Consistent self-monitoring is the single strongest behavioral predictor of weight-loss success (Burke, Wang & Sevick 2011 systematic review). The Kaiser study found food-record keepers lost roughly twice the weight of non-keepers (Hollis et al. 2008). But Michie et al. (2009) meta-regression is the key nuance: self-monitoring alone is weak; **self-monitoring PAIRED with at least one other self-regulation technique (feedback on performance, goal review) roughly doubles effect size.** JeniFit already collects the data on Home. Becoming's entire job is the missing half of that pair: feedback, interpretation, goal review. A tab that re-displays raw inputs adds nothing; a tab that closes the loop is the intervention.

**Trend beats daily number, especially for women.** Repeated exposure to the raw scale number produces measurable mood and self-esteem decrements in women even when weight is stable (Ogden & Whyman 1997; Mercurio & Rima 2011). Daily fluctuation of 1-2 kg from water, glycogen, sodium and cycle phase is normal (luteal-phase water retention is well documented; White et al. 2011). Self-weighing frequency predicts loss (Zheng et al. 2015 systematic review; Steinberg et al. 2015) BUT the benefit comes from the trend signal, not the daily verdict, and in young women daily-number fixation associates with weight concern and disordered patterns (Pacanowski, Linde & Neumark-Sztainer 2015 review; Romano et al. 2018). The EMA trend (Helander 2014, already computed) is therefore not a chart choice. It is the clinical safety layer.

**Early-weeks feedback determines whether she stays.** Digital health's "law of attrition" (Eysenbach 2005): the steepest dropout is weeks 1-4, exactly when weight signal is noisiest. Early engagement and early (even small) measured progress predict 12-month outcomes (Nackers, Ross & Perri 2010; Unick et al. 2014 on early adherence as the dominant predictor). The retention-critical design problem is giving her **honest evidence of progress before the scale can statistically provide it** (see §4).

**Adaptive content retains; static dashboards die.** Tailored feedback outperforms generic in meta-analysis (Krebs, Prochaska & Rossi 2010; Noar, Benac & Harris 2007). The in-house finding matches: lessons + breathwork at 75%+ completion vs workouts at 23%. She shows up for things that tell her something, not things that test her.

**Autonomous motivation + identity beat pressure.** Self-determination theory trials show autonomous (identity-congruent, "I am someone who") motivation predicts 3-year weight maintenance; controlled motivation (guilt, external pressure) predicts rebound (Teixeira et al. 2012; Silva et al. 2011 PESO trial). Habit formation runs a median ~66 days (Lally et al. 2010), which is essentially the program length. Becoming should narrate identity-from-evidence: "you are becoming someone who walks daily" backed by her own data, never floating affirmation (data-provenance rule agrees).

**NSVs carry adherence through scale plateaus.** Energy, sleep, stamina, clothes fit and consistency are the victories women report sustaining them when weight stalls (qualitative maintenance literature: Epiphaniou & Ogden 2010; "successful loser" registry behaviors, Wing & Phelan 2005). Plateaus are physiologically guaranteed (adaptive thermogenesis; Hall et al. 2011 model), so a tab with only scale-derived modules is a tab that goes silent exactly when she needs it.

**GLP-1 era.** Roughly half of GLP-1 starters discontinue within 12 months (Gleason et al. 2024 claims analysis) and two-thirds of lost weight returns within a year of stopping without behavioral scaffolding (Wilding et al. 2022, STEP 1 extension). Lean-mass loss is 25-40% of total loss in the trials (Wilding et al. 2021), making protein intake and resistance movement the two highest-value behaviors for this sub-cohort. Behavioral support alongside pharmacotherapy improves outcomes (Wadden et al. 2020). The app's job for GLP-1 users: protect muscle, build the habits that outlive the prescription, never moralize the medication.

**Perimenopause.** The menopause transition accelerates fat gain and lean-mass loss independent of chronological aging (Greendale et al. 2019, SWAN), sleep disruption is near-universal (Kravitz et al. 2008, SWAN), and realistic pace is slower. Short sleep itself halves the fat fraction of weight lost (Nedeltcheva et al. 2010, already wired into the goal engine). For this cohort the tab must legitimize a slower trend line as physiology, not failure.

---

## 2. Ranked module list (highest value per zero added input)

All read-only over data already flowing. Ordered by adherence value to THIS cohort.

| # | Module | What it shows | Why it helps (evidence) | Data it reads | Anti-shame rule |
|---|---|---|---|---|---|
| 1 | **Trend Verdict Hero** | EMA trend line + one plain-language coach sentence answering "is it working?" that changes weekly ("your trend is drifting down, right on your pace" / "flat weeks happen, your eating week was steady, hold") | Trend > daily number (Pacanowski 2015; Ogden & Whyman 1997); feedback paired with monitoring doubles effect (Michie 2009); adaptive content = retention (Krebs 2010) | weight_logs EMA, plan pace band, program day | Daily number demoted to footnote; never red; flat/up weeks get physiology explanation, never "off track" |
| 2 | **Pace Band Chart** (transform of forecast line) | Her EMA plotted inside the ACSM 0.5-1%/wk corridor her own plan derived, from start weight to goal date | Goal review against a realistic standard is the self-regulation technique that pairs with monitoring (Michie 2009; Carver & Scheier 1982 control theory); corridor framing absorbs noise that a single forecast date cannot | plan start/goal/pace, weight_logs EMA | Band, never a single line she can "fall off"; below-band reads "faster than planned, make sure you're eating enough" (counter-restriction safety net) |
| 3 | **Showed-Up Ledger** (process-goal hero) | Days-engaged count + which checklist modules she actually completes (her real pattern: lessons 75%, steps auto, workouts 23%) framed as "your program, your shape" | Process goals outperform outcome goals for adherence when outcomes are noisy (Carver & Scheier; small-wins progress principle, Amabile & Kramer 2011); consistency of monitoring predicts loss (Burke 2011) | program_day_checks states, derived engagement day | Counts what she DID; skipped rows simply don't appear; no completion percentage shaming, no empty-day callouts |
| 4 | **Weekly Recap Card** (Sunday ritual) | One auto-written weekly chapter: trend delta, days shown up, protein pattern, steps avg, one NSV line | Weekly cadence matches signal-to-noise of weight data; peak-end framing of the week (Kahneman et al. 1993); this is the "new info each visit" retention lever | all sources, 7-day windows | Worst week still gets a true sentence ("you came back Thursday, that's the skill"); fresh-start frame (Dai, Milkman & Riis 2014) |
| 5 | **Protein Pattern Tile** | 7-day rolling protein average vs a personalized anchor (g/kg from her weight), shown as words + soft bar | Protein is the highest-leverage dietary lever for satiety + lean-mass retention (Leidy et al. 2015); load-bearing for GLP-1 lean-mass risk (Wilding 2021) and post-Ozempic "protein-priority" vocabulary the cohort already speaks | food_logs macros, weight_logs | Protein is the ONLY macro elevated to a tile; calories stay weekly-smoothed footnote; under-anchor copy is invitational ("your meals are light on protein, an easy add tomorrow") |
| 6 | **Eating Rhythm Tile** | Her actual first-meal to last-meal window + meal count pattern this week vs her stated eating window from onboarding | Eating-window regularity associates with weight outcomes (Gill & Panda 2015); uses her own onboarding answer, making onboarding data visibly pay off (tailoring effect, Noar 2007) | food_logs timestamps, onboarding eating window/cadence | Descriptive only ("your meals landed 9am-8pm this week"), never compliance-scored; no fasting framing |
| 7 | **NSV Wins Tile** (keep, sharpen) | Auto-detected wins from collected data: longest plank PR, steps streak, lesson chapters finished, post-session feel trending up | NSVs sustain adherence through plateaus (Epiphaniou & Ogden 2010); session-rating "feel" trend is a legitimate affect outcome (exercise-affect adherence link, Rhodes & Kates 2015) | session_ratings, plank benchmarks, steps, lessons | Only true detected events; never "almost" wins; no body-comparison language |
| 8 | **Barrier Counter** (keep) | "You said evenings are hard. You've moved on 9 evenings anyway." | Counter-evidence against the stated barrier builds self-efficacy, the strongest psychological predictor of maintenance (Bandura 1997; Annesi 2011; Rhodes & de Bruijn 2013) | onboarding barrier, session timestamps | Only fires on accumulating evidence; silent otherwise |
| 9 | **Program Chapter Map** (the 2x3 grid, reframed) | Day 1..N grid as chapters/weeks completed, dot = engaged, not perfect | Visualizing accumulated progress predicts goal persistence (goal-gradient; Kivetz, Urminsky & Zheng 2006); the her75 artifact the cohort screenshots | program day, day checks | Engaged-day dot for ANY completed row, never all-5-or-nothing; missed days render neutral paper, no red/grey shame cells, no "broken" language |
| 10 | **Sleep Context Line** (Phase 3, when HK sleep lands) | "Short-sleep weeks slow the trend. This was one. Your flat week has a reason." | Sleep restriction halves fat loss fraction (Nedeltcheva 2010); attribution to physiology protects against self-blame quitting | HK sleep, weight EMA | Explanation, never prescription pressure; one line, not a sleep dashboard |
| 11 | **Body Measurements Tile** (Phase 2) | Waist/hip trend when she opts in, surfaced when scale is flat | Waist circumference responds when scale stalls (Ross et al. 2020 consensus, waist as vital sign); gives a second honest progress channel | body_measurements | Opt-in, cm trend only, no "ideal" targets |
| 12 | **Becoming Statement** (identity caption, keep small) | One quiet line tying identity to evidence ("3 weeks of showing up. you're becoming her.") | Identity-congruent autonomous motivation predicts maintenance (Teixeira 2012; Silva 2011); identity attached to evidence drives adherence, floating identity is decoration (prior expert consensus, round 10) | Q140 + engagement data | Caption-sized, never a hero; only renders with ≥1 week of evidence behind it |

Modules 1-4 are the spine. 5-9 are the depth that makes weekly visits worth it. 10-12 are context layers.

---

## 3. Current Becoming modules: keep / kill / transform verdicts

Current main stack (AnalyticsView.swift): streak strip → today's balance kcal card → WHO 150-min ring → weight trend hero + identity caption → more-depth sheet (barrier card, plank card, food week bento, NSV tile, recent sessions).

- **Today's Balance card (gained vs spent kcal) → TRANSFORM to weekly, demote.** A daily intake-vs-expenditure equation is the single most diet-culture artifact left in the app. Daily energy-balance display is exactly the calorie-overlay pattern linked to shame and ED-behavior escalation in this cohort (Simpson & Mazzeo 2017; Levinson et al. 2017 on MyFitnessPal use in ED populations), and daily expenditure estimates are too imprecise to honestly net against intake (wearable/MET EE error routinely 20%+; Shcherbina et al. 2017). It also now competes with Home, which owns "today." Replace with the weekly Protein Pattern + Eating Rhythm tiles and fold a smoothed weekly energy view into the depth sheet. This also answers open question 10: keep kcal-burned suppressed as a hero; time/sessions stays the movement metric.
- **WHO 150-min ring → TRANSFORM into the Showed-Up Ledger.** The WHO target is a population guideline external to her program; the program pivot makes her plan the standard. Generic targets underperform tailored ones (Krebs 2010). Keep the WHO citation inside the explainer sheet as credibility, kill it as the visual anchor.
- **BMI card → CONFIRM KILL** (already removed round 10; correct call: poor individual-level validity and bias, and it can only ever deliver a category verdict, which is shame UI).
- **Streak strip → TRANSFORM.** Keep visible consistency, but per §6 never frame as loss-threatened. "Days shown up" cumulative count is psychometrically safer than an unbroken-chain streak (fresh-start literature, Dai 2014). Merge into the Showed-Up Ledger.
- **Weight trend hero + identity caption → KEEP, promote to Trend Verdict Hero** (module 1) by adding the weekly coach sentence and the pace band (module 2). This is the strongest thing on the tab today.
- **Barrier card, plank card, NSV tile, recent sessions (depth sheet) → KEEP.** Barrier card and NSV earn promotion per §2 ranking. Recent sessions stays depth.
- **Forecast line (goal ETA) → TRANSFORM into pace band.** A single predicted date is a promise the noise will break; a corridor is honest (and matches the ACSM credibility chip the onboarding sub-flow already shows).

---

## 4. The adherence-feedback loop: "is it working?" at week 2 with noisy data

This is where programs are won. At 0.5-0.75%/wk a 75 kg woman has lost 0.75-1.1 kg by day 14, while normal daily fluctuation is 1-2 kg (water/glycogen/cycle; White 2011). The scale literally cannot yet confirm the program is working, and weeks 1-4 are peak attrition (Eysenbach 2005). What she must see:

1. **The trend, never the day.** EMA with the daily dots faded to near-invisible. The hero sentence interprets: "two weeks in, your trend line just started bending. this is exactly what week 2 looks like."
2. **Expectation pre-loading.** The pace band shows from day 1 that the corridor is shallow early. When her dot sits inside the band, the tab says so explicitly. Accurate expectations are protective: unrealistic loss expectations predict dropout (Dalle Grave et al. 2005).
3. **Process evidence as the primary week-1-3 answer.** Until the scale has signal, "is it working?" is answered by behavior: days shown up, meals snapped, steps. Early self-monitoring adherence is the best available predictor of her 6-month outcome (Unick 2014; Burke 2011), so showing it IS showing her honest leading-indicator evidence, not a consolation prize. Copy should say that: "the women who do what you did this week are the ones whose trend bends by week 4."
4. **Physiology explanations for flat/up readings.** A one-line library keyed to detected conditions (logged late-cycle if cycle data ever lands; short sleep via HK; high-sodium day is NOT inferable, so never claim it). Attribution to physiology instead of self prevents the abstinence-violation spiral that follows perceived failure (Marlatt & Gordon 1985 relapse model).
5. **A safety valve when the trend runs fast.** Below-band reads as a gentle eat-more flag, not a win to amplify (counter-restriction; protects GLP-1 + restriction-history users).

The loop cadence: daily glance = Home checklist. Becoming earns a 2-3x/week visit by changing its verdict sentence and a Sunday visit for the recap. That is the adaptive-content retention lever (Krebs 2010) running on zero new input.

---

## 5. Cohort-specific module variants (all from existing onboarding fields)

**GLP-1 users (onboarding GLP-1 status = yes):**
- Protein Pattern tile promoted to position 2 (lean-mass protection; Wilding 2021).
- Trend verdict expects faster pace without celebrating speed; below-band eat-more flag is MORE sensitive (appetite suppression makes under-eating the default failure mode).
- Movement framing: resistance/strength minutes called out specifically (muscle retention), not generic activity.
- Recap includes a "habits that outlive the prescription" line occasionally: discontinuation runs ~50% in year 1 (Gleason 2024) and regain follows without behavioral scaffolding (Wilding 2022). Never name the drug in shame-adjacent copy; "food noise" vocabulary is native here.

**Perimenopausal users (hormonal stage field):**
- Pace band built on the soft (0.5%/wk) corridor by default (already the engine default); trend verdict copy explicitly legitimizes the slower line as physiology (Greendale 2019), e.g. "your body is renegotiating. the trend counts double."
- Sleep context line (module 10) promoted when HK sleep ships (Kravitz 2008 prevalence).
- Body measurements tile surfaced earlier: body recomposition and redistribution mean the waist trend often moves when the scale doesn't.
- Strength + protein emphasis mirrors GLP-1 variant (sarcopenia risk in the transition).

**Restriction-history users (food relationship = strained / prior attempts = many):**
- Daily calorie numbers never surface anywhere on the tab, including depth sheet; weekly words-only ("your eating week was steady").
- Rigid-rule framing suppressed entirely: flexible restraint predicts success, rigid restraint predicts disinhibition and bingeing (Westenhoefer et al. 1999; Polivy & Herman 1985).
- Under-target safety net is loudest for this cohort; eating-rhythm tile drops any window comparison and stays purely descriptive.
- NSV + Showed-Up Ledger become the spine; scale modules render only on her weigh-in cadence, never prompt for more weighing (daily weighing carries disordered-eating association in young women; Pacanowski 2015; Romano 2018).

---

## 6. What NOT to build (engagement-bait that harms this cohort)

1. **Daily-calorie-as-hero.** The Cal AI pattern. Drives opens, erodes trust, and the shame-escalation evidence is direct (Simpson & Mazzeo 2017; Levinson 2017; 2025 WIEIAD literature). The engagement-vs-trust trade is JeniFit's stated wedge; do not let a dashboard re-litigate it.
2. **Streak-loss threats / unbroken-chain mechanics.** Loss-framed messaging underperforms for prevention behaviors (Gallagher & Updegraff 2012 meta-analysis), and a broken streak triggers the abstinence-violation effect that precedes quitting (Marlatt & Gordon 1985). Cumulative "days shown up" only; a missed day changes nothing she can see.
3. **Red zones, red bars, warning colors on any food or weight surface.** Locked anti-shame rule; color-coded verdicts are the moralizing layer the post-Ozempic cohort explicitly rejects.
4. **Calendar shame grids.** A month view where empty days render as failures is an anxiety surface (the Cal AI heatmap pattern). The Program Chapter Map renders missed days as neutral paper, full stop.
5. **A single forecast date as a promise.** "Goal by Aug 14" will be wrong week-to-week and teaches her the math is fake (the BetterMe free-date footgun, 1.6-star reviews). Corridor only.
6. **Daily weigh-in prompts or weigh-streak rewards.** One-per-day policy stays; the tab never asks for MORE weighing than her cadence (Pacanowski 2015).
7. **Leaderboards / social comparison.** Upward appearance comparison is a robust body-dissatisfaction driver in young women (Fardouly et al. 2015); this audience arrives from TikTok already saturated in it.
8. **Burned-calories-as-earnings ("you earned 320 kcal").** Exercise-as-payment framing is compensatory-eating psychology and 2010s diet culture; also numerically dishonest (EE estimate error, Shcherbina 2017).
9. **Body-scan/before-after photo modules on this tab.** Progress photos are Phase 4 share-card territory under user control; auto-surfaced comparisons are shame UI.
10. **An "AI insights" label on any of it.** The coach sentence is Jeni's voice. The word AI stays out per brand lock, and "insight" engines that fabricate causality ("you lose more on Tuesdays!") violate data provenance; every verdict sentence must be backed by a computable, citable rule.

---

## Summary for the build

Becoming = the answer surface. Home asks her to do five things; Becoming proves they're working, in her own data, on a weekly clock that matches the physiology. Spine: Trend Verdict Hero → Pace Band → Showed-Up Ledger → Weekly Recap. Depth: protein pattern, eating rhythm, NSVs, barrier counter, chapter map. Kill the daily energy-balance card, transform the WHO ring into program-relative consistency, keep the trend hero and grow it a voice. Every module above runs on data already flowing today (modules 10-11 wait for their Phase 2/3 sources). The retention war is won or lost in the week-2 "is it working?" answer, and the honest answer at week 2 is process + trend + expectation, never the day's number.
