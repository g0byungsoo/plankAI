# Becoming Tab Research, Round 2: What She Actually Wants to See (by input burden)
**Author:** consumer-insight researcher, Gen-Z/young-millennial women + wellness apps
**Date:** 2026-06-10 · Builds on the three round-1 briefs; does not repeat them.
**The founder's challenge:** "weight tracker requires user's inputs. do you think there are other things you can put? like calorie tracking + nutrient tracker." Maximal value, minimal input.

---

## §1 Input-burden ranking of every JeniFit data stream (PostHog reality, project 437953)

Pulled live 2026-06-11. WAU = 341 (Application Opened, 7d). Food rail shipped in 1.0.8 (~June 6), so food numbers are week-1 and paid-gated; flagged accordingly.

| Tier | Stream | Input act | Real 7d engagement | Read |
|---|---|---|---|---|
| 0 · passive | **Steps** | none (HealthKit) | steps_viewed_home: 285 users / 764 views = **84% of WAU** see it | The strongest surface in the app is the one she never feeds. |
| 0 · passive | **Program day / engagement day** | none (derived) | implicit in every open | Identity data at zero cost. |
| 1 · one tap | **Lessons (JeniMethod)** | tap + read | diet_education_lesson_viewed: 286 users / 449 views = **84% of WAU** | She shows up for interpretation, ~1.6 lessons per user per week. |
| 1 · one photo | **Food scans** | point camera | **9 of 19 eligible paid users on 1.0.8+ scanned in week one (47% adoption)**; 126 scans + 71 saved logs across those 9 = **~14 scans/user**; top users: 41 scans in a day, 33 in 2 days | When capture is a photo, intensity is an order of magnitude above any typed stream. Quick-add (13) and "i'm out" (15) paths also used. Food scanners averaged **1.83 active days/7 vs 1.12** for non-scanning paid users (tiny N, directional). |
| 1 · timed tap | **Breathwork** | tap + 5 min | 22 completers / 7d; 70% start→complete | Small but completes. |
| 2 · effortful | **Workouts** | 10-30 min of body | 29 completers / 7d (8.5% of WAU); 126 starters vs 42 completers / 30d = **33% user completion** | Confirms launch finding. Effort-priced streams are minority streams. |
| 2 · effortful | **Plank check-in** | hold + log | 63 starters / 30d | Same shape. |
| 3 · typed number | **Weight** | type a scale number | **11 users / 7d = 3.2% of WAU**; 27 logs / 30d; even loggers average ~1.3 logs/wk | Near-zero, confirmed again. |
| 3 · typed | **Session feedback** | tap rating | 38 users / 30d | Optional, stays optional. |

Two findings that reframe round 1:

1. **The burden axis isn't time, it's self-verdict.** A 20-minute workout (tier 2) outperforms a 5-second weight entry (tier 3). Typing your own scale number is an act of self-judgment; photographing a plate externalizes the data. The cohort's revealed preference: **camera ≫ tap ≫ timer ≫ typed number about my body.**
2. **Food users and weight users are different people.** Overlap between 30-day food scanners (9) and weight loggers (16) is **3 users**. Photo logging is not feeding the scale habit; it's replacing it. A Becoming hero keyed to weight_logs renders stale or empty for ~97% of weekly actives. The founder's instinct is correct against our own data.

Caveat: food N is 9 users in week one of a paid-only feature; novelty inflates intensity. Re-pull at 30 days before treating 14 scans/user as steady state. The 47% adoption and the tier ordering are robust regardless.

---

## §2 The calorie/nutrient hero verdict

**Direct answer: yes, food data should lead the tab. No, not as a daily calorie ring. Lead with protein-first + weekly pattern framing.** The locked anti-shame doctrine survives the test; the round-1 module ORDER does not.

**The honest case FOR visible calorie/macro numbers (steelman):**
- Cal AI: 5M+ downloads in 8 months, claimed 30%+ retention, 4.8★ on 300k+ App Store reviews, acquired by MyFitnessPal in March 2026 ([TechCrunch](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/), [CNBC](https://www.cnbc.com/2025/09/06/cal-ai-how-a-teenage-ceo-built-a-fast-growing-calorie-tracking-app.html)). Daily ring and all.
- But read WHY the 5-star reviews land: *"helps me keep track of my food **without overthinking everything** and gives me a **visual of my portions** plus it's **so aesthetic** 💓"* ([FeastGood review roundup](https://feastgood.com/cal-ai-review/)). The praised job is **food-noise reduction + visual journal + aesthetics**, i.e. effortless capture. The ring is the scoreboard Cal AI bolted on, not the moat. Our own data agrees: JeniFit users scan 14x/week without a hero ring anywhere.
- Who churns there: rage clusters on streak-loss bugs, false-confidence estimates, and billing ([Google Play reviews](https://play.google.com/store/apps/details?id=com.viraldevelopment.calai), [Trustpilot](https://www.trustpilot.com/review/calorieai.io)). The shame-adjacent churn shows up category-wide: 2025 reporting found calorie-app users describing shame at logging "unhealthy" foods, irritation at warnings, "apps that scream in red text when they eat a slice of pizza" ([US News, Oct 2025](https://www.usnews.com/news/health-news/articles/2025-10-24/fitness-apps-undermine-motivation-for-some-users-experts-say), [diet-app evolution piece](https://vocal.media/education/from-calories-to-wellness-the-powerful-evolution-of-diet-apps-in-2025)). The 2025 WIEIAD/ED-escalation literature already in our memory stands unrefuted.

**The case for a different macro to lead:**
- Protein has displaced calories as the number this cohort tracks voluntarily: 78% of consumers attend to protein, MORE than track calories ([Numerator 2025](https://www.numerator.com/resources/blog/protein-trends/)); the women-led TikTok protein wave is the defining 2025 nutrition trend ([HerCampus](https://www.hercampus.com/school/ucsb/the-tiktok-protein-craze-is-it-healthy-or-just-another-damaging-diet-fad/)); 27% of women believe they under-eat protein.
- The entire 2026 GLP-1 app generation (Shotsy, Glapp, MeAgain) tracks **protein, fiber, water, food noise, satiety**, not calorie verdicts ([Fitness Drum 2026 roundup](https://fitnessdrum.com/best-glp-1-apps/), [Regimen](https://helloregimen.com/blog/best-glp1-tracker-apps-2026)).
- Noom's 5-star vocabulary is guilt-removal, not calorie precision: "no food is off limits," "removed the guilt" ([ConsumerAffairs](https://www.consumeraffairs.com/health/noom.html), [Trustpilot](https://www.trustpilot.com/review/noom.com)). The 1-star vocabulary across MFP/legacy apps is "red," "warning," "judged," "obsessive."
- Psychometrically, protein is the only macro where the desirable direction is UP. An under-target protein bar invites an add ("an easy add tomorrow"); an over-target calorie bar delivers a verdict. Same chart, opposite shame valence. This is why protein can be a hero and calories cannot.

**Verdict in one line for the founder:** you're right that food + nutrients beat the weight chart for the top of the tab, because that's where her actual data is; but copy Cal AI's camera, not Cal AI's ring. Hero = **protein pattern this week** (words + soft bar, from scans she already takes), supported by eating rhythm and the plate filmstrip. Daily calories stay a tap-deep, weekly-smoothed footnote exactly as locked. Becoming's food layer is the **interpretation** of her scans, which is the half Cal AI never built and the half our 84%-lesson-engagement cohort demonstrably wants.

---

## §3 The 8-second snapshot: what a 25-year-old on a program actually wants to see

Ranked. Items 1-5 fit one viewport; 6-7 are conditional lines, not modules.

1. **Where am I in my program** · "day 19 of her 84" + one pace sentence. Zero input, identity-first, the her75 artifact. (Folio, unchanged from round 1.)
2. **Protein this week** · "protein's been showing up: 71g average on scan days" vs her g/kg anchor, soft bar, never red. From photos she already takes. The number she's primed by TikTok to care about.
3. **Did I show up** · "4 of 7 days this week" cumulative, gain-framed. From taps already happening.
4. **Steps pulse** · weekly average + direction word. Already her most-viewed surface (84% of WAU).
5. **One sentence about her trend** · IF weight data exists (typed or HealthKit-imported): "trending down, gently. right on your pace." IF NOT (the 97% case today): the adherence-trend sentence takes the slot ("three weeks of showing up. that's the pattern that bends the line."). The slot never renders empty or nags for a weigh-in.
6. **A context line when one is true** · luteal/sleep explanation (see §4), or the prior-attempts mirror ("past attempts lasted about 2 weeks. you're on day 23.").
7. **Next milestone** · "2 days to week three." Goal-gradient, zero input.

What did NOT make the 8 seconds: daily calorie total, any chart with axes, BMI, kcal burned, streak-at-risk, anything requiring her to have typed a number that day.

---

## §4 Cycle-context verdict: BUILD, but LATER (Phase 3, bundled with sleep), one line only

- **Value is real and exactly on-target.** Luteal/menstrual fluid retention is 0.5-2.3 kg for most cycling women, peaking around day one of flow, almost entirely extracellular water ([Clue](https://helloclue.com/articles/diet-and-exercise/do-you-gain-weight-on-your-period-here-s-what-to-know), [Medical News Today](https://www.medicalnewstoday.com/articles/327326), [Wikipedia: premenstrual water retention](https://en.wikipedia.org/wiki/Premenstrual_water_retention)). That is bigger than two full weeks of her planned loss. "luteal week. water weight is normal, the line knows" is the single most protective sentence a weight-trend surface can say to this cohort, and the round-1 program brief explicitly wished for it (§4.4, "if cycle data ever lands").
- **It feels zero-input** because HealthKit cycle data is usually already there: Apple Watch temperature-based estimates auto-populate, and Flo/Clue sync writes. Read-only HKCategoryType menstrualFlow + cycle estimates; we never ask her to log a period in JeniFit.
- **Why later, not next:** (a) it's a multiplier on the weight-trend stream, which is currently 3% of WAU; HealthKit body-mass import (see §6) must land first or the line has nothing to contextualize; (b) coverage is conditional (no watch + no period app = no data; the line silently never renders); (c) post-Dobbs sensitivity demands on-device-only interpretation, no server sync of cycle fields, no prediction, no fertility framing. One read-only permission, one context line, never a cycle dashboard, never "cycle syncing" programming (that's Cycle Diet/28's lane and a scope trap).
- **Scope sentence for the roadmap:** Phase 3 = HealthKit sleep + cycle, both consumed ONLY as trend-explanation lines on Becoming. Build/skip review after body-mass import moves weight coverage.

---

## §5 What she screenshots (the share artifacts that actually circulate)

Pattern across platforms: she shares **identity artifacts with a date on them**, never charts.

1. **The dated day-card / checklist** · her75's "day one" card and filled checklists are the genre-defining 2026 share; the entire surface is designed backwards from the IG story (round-1 designer brief; [75 Soft Fem](https://apps.apple.com/us/app/75-soft-challenge-tracker-fem/id6740633846)).
2. **Closed rings / completed-workout cards** · Apple Watch ring shares remain the default story post; an ecosystem of apps exists purely to re-skin them prettier ([Fitness Story](https://apps.apple.com/us/app/fitness-story/id6748090363), FIT Shot). Lesson: completion states get shared, in-progress states don't.
3. **Wrapped-style recaps** · Oura weekly/monthly reports and the "Fitness Wrapped" genre (round-1 brief sources). Weekly recap card = correct Phase 4 bet.
4. **Aesthetic plates** · Cal AI's "it's so aesthetic 💓" review is about the plate visual; WIEIAD shows food-photo grids are already a share genre (we de-shame it by exporting the filmstrip without numbers). JeniFit's 9:16 food share (v1.0.9) is positioned exactly here.
5. **"That girl" planner dashboards** · the Notion/Etsy that-girl dashboard economy ([Notion marketplace](https://www.notion.com/templates/that-girl-aesthetic-dashboard), [Etsy](https://www.etsy.com/listing/1808217421/2025-notion-template-life-planner-that)) shows the aesthetic she screenshots: cream, serif, paper-planner, lowercase. JeniFit's folio + scrapbook chrome is already in-genre; lean in.

Not shared, ever: weight charts, calorie totals, BMI, anything with her actual mass on it. The day-card share (round-1 designer §3b) should default the trend line OFF and adherence + steps ON.

---

## §6 Changes to the round-1 module list

**PROMOTE**
- **Protein Pattern tile: #5 → the food-hero slot (position 2, right after the folio).** Justified by §1 (food is the high-intensity stream), §2 (protein is the cohort's chosen number), and GLP-1 cohort load-bearing. Words + soft bar, scan-days only, never a daily verdict.
- **Plate filmstrip (designer's zone 4): from "nice texture" → first-class module.** It IS the engagement stream and the share artifact. Collapses when empty.
- **Eating Rhythm tile: holds at top-5** but render-gate at ≥4 scan-days/wk (app-expert's gate stands; 9 current users already clear it).

**DEMOTE / RE-PLUMB**
- **Trend Verdict Hero (round-1 #1) → conditional artifact slot.** Keep the zone-2 chrome, but the default render for the 97% without weight data is the adherence/protein artifact, with the trend swapping IN when data exists. Round 1 had the swap backwards (weight default, adherence fallback).
- **Pace Band Chart → depth sheet** until weight coverage improves. A corridor with 1.3 points/week in it is a promise we can't draw honestly.

**ADD**
- **HealthKit body-mass import = the highest-leverage build in this entire research round.** Smart scales (Withings/Eufy/Renpho) and other apps write body mass; importing converts the dead tier-3 stream into tier-0 for some users and removes the typed-number shame act for everyone else. The app-expert suggested it in passing; the PostHog data makes it P1.
- **Cycle context line** (Phase 3, per §4). **Sleep context line** stays Phase 3 as planned.
- **30-day food-data re-pull** as a checkpoint task: confirm scan intensity past novelty before locking the protein hero's render gates.

**REAFFIRM (tested, not just inherited)**
- No daily calorie ring on Becoming; weekly-smoothed kcal stays a footnote. The founder's challenge was the right question, and the answer is "food leads, calories don't."
- Showed-Up Ledger, Weekly Recap heartbeat, prior-attempts mirror, kill-list (red anything, heatmaps, streak-loss, single forecast date, leaderboards) all stand.

**One-line synthesis:** her data lives in her camera roll and her pocket, not on her scale. Build the tab on photos + steps + taps she already gives us, let protein be the number that leads, import the scale instead of asking for it, and save the cycle line for the day the trend has something to explain.

---

## Source index
PostHog project 437953, queries run 2026-06-11 (events 30d/7d windows, version cohorts on 1.0.8+).
[TechCrunch: MFP acquires Cal AI](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/) · [CNBC Cal AI](https://www.cnbc.com/2025/09/06/cal-ai-how-a-teenage-ceo-built-a-fast-growing-calorie-tracking-app.html) · [FeastGood Cal AI review](https://feastgood.com/cal-ai-review/) · [Cal AI Google Play reviews](https://play.google.com/store/apps/details?id=com.viraldevelopment.calai) · [Trustpilot](https://www.trustpilot.com/review/calorieai.io) · [US News: fitness apps undermine motivation](https://www.usnews.com/news/health-news/articles/2025-10-24/fitness-apps-undermine-motivation-for-some-users-experts-say) · [Diet apps in 2025](https://vocal.media/education/from-calories-to-wellness-the-powerful-evolution-of-diet-apps-in-2025) · [Numerator protein trends](https://www.numerator.com/resources/blog/protein-trends/) · [HerCampus protein craze](https://www.hercampus.com/school/ucsb/the-tiktok-protein-craze-is-it-healthy-or-just-another-damaging-diet-fad/) · [Fitness Drum GLP-1 apps 2026](https://fitnessdrum.com/best-glp-1-apps/) · [Regimen GLP-1 trackers](https://helloregimen.com/blog/best-glp1-tracker-apps-2026) · [Noom ConsumerAffairs](https://www.consumeraffairs.com/health/noom.html) · [Noom Trustpilot](https://www.trustpilot.com/review/noom.com) · [Clue: period weight](https://helloclue.com/articles/diet-and-exercise/do-you-gain-weight-on-your-period-here-s-what-to-know) · [MNT: period weight gain](https://www.medicalnewstoday.com/articles/327326) · [Premenstrual water retention](https://en.wikipedia.org/wiki/Premenstrual_water_retention) · [Fitness Story share app](https://apps.apple.com/us/app/fitness-story/id6748090363) · [75 Soft Fem](https://apps.apple.com/us/app/75-soft-challenge-tracker-fem/id6740633846) · [That-girl Notion dashboard](https://www.notion.com/templates/that-girl-aesthetic-dashboard) · [Etsy that-girl planner](https://www.etsy.com/listing/1808217421/2025-notion-template-life-planner-that) · [NSV overview, Healthline](https://www.healthline.com/health/non-scale-victories) · [App engagement predicts loss, JMIR/PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11193074/)
