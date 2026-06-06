# Home + Becoming + Food-Camera UX: Behavioral Research Brief

**Date:** 2026-06-06
**Author:** Behavioral science review for JeniFit v1.0.7
**Audience:** Founder; Gen-Z women 22-35, TikTok-acquired, post-Ozempic / post-Cal-AI
**Method:** Peer-reviewed (PubMed, JMIR, Cambridge, Wiley, PMC), market research (Pew, BusinessOfApps, GWI), and 2024-2026 behavioral writeups. No fabricated stats.

---

## Executive behavioral recommendation (read this first)

The founder is **directionally right on two of three hypotheses, but materially wrong on the framing of one — and the third is half-right in a way that, uncorrected, will spike disordered-eating risk in this exact cohort**. Specifically:

- **Hypothesis 1 — "magical photo-to-value experience is the lever":** VALIDATED, but reframe the *source* of magic. Speed + aesthetic + identity reinforcement is the lever, not the camera per se. The camera is the most legible delivery mechanism; the magic is reducing the *naming* cost of food, not the *typing* cost.
- **Hypothesis 2 — "weight tracking is low-usage because Gen-Z is lazy with input":** WRONG FRAME. They are not lazy; they are **avoidant + protective**. The scale is psychologically loaded after 24 months of GLP-1 discourse + TikTok body-image trauma. Input friction is downstream of emotional friction. Reducing taps will not solve it; reframing the act will.
- **Hypothesis 3 — "for weight-loss programs, calories matter most":** HALF-RIGHT, DANGEROUSLY APPLIED. Calorie *math* is the underlying engine. Calorie *as the hero number on Home* is the single highest-risk choice you can ship in 2026 for this specific cohort. Show the rail. Bury the number. Let the trend be the hero.

**Top three things to ship from this brief:**

1. **Trend-as-hero, calorie-as-detail.** Home shows a smoothed EMA trend ring + a "today's pattern" tile. The calorie number lives one tap deep, never on Home. (Evidence: Linardon, Tylka, et al. 2025; Pacanowski 2024; post-Ozempic body image research, Virta 2025.)
2. **Photo-camera is the on-ramp, not the destination.** The behavioral payoff is reducing the *self-criticism* cost of naming food ("I ate a donut") — not the typing cost. Design the result card as a non-judgmental reflection, not a verdict. (Evidence: BJPsych Open 2024 qualitative; Linardon ScienceDirect 2022; Stanford BMAP application research.)
3. **Identity-framed copy, no streaks, ≤4 trial-week notifications.** Identity language outperforms goal language for adherence by a meaningful margin (Zhu et al. 2025 meta-analysis; Rhodes 2025 12-week RCT). Streak mechanics carry a 2024-26 backlash among Gen-Z women that overrides the Duolingo retention lift. Notification budget for trial week should sit at 3-4 max, all identity-affirming, none scale-threatening. (Evidence: BusinessOfApps 2025; HBR 2025; Mobiloud Push Notification stats 2025.)

The rest of this document is the deep dive supporting these recommendations and answering all 8 of the founder's questions in order.

---

## 1. Cognitive load tolerance of Gen-Z women in 2026 WL apps — lazy, or protective?

**Founder's hypothesis:** "Gen-Z women have short focus spans + are lazy with input."

**Verdict: WRONG FRAME — they are protective, not lazy.** This distinction has direct UX consequences.

The "lazy + short attention" frame is the default tech-industry read on Gen-Z, but the peer-reviewed evidence in weight-loss-app contexts tells a different story:

- A 2025 systematic review in *Eating Behaviors* (Linardon et al., PMC12547374) concluded that **fitness and diet tracker use is correlated with disordered eating**, but the directionality remains unresolved. What is *not* in dispute: weight-loss tracking is *psychologically loaded labor*, not just cognitive labor.
- The 2025 *DIGITAL HEALTH* secondary analysis of a 12-month RCT (Oliveira et al., Sage 2025) found mobile weight self-monitoring adherence *declined predictably* across all cohorts — not because users were lazy, but because each weigh-in carried emotional weight. Drop-off correlated with negative-affect days, not low-effort days.
- *JMIR mHealth* 2025 reports MyFitnessPal self-monitoring fell from 5.4 days/week at week 4 to 1.4 days/week at week 12 in a behavioral weight-loss study — and qualitative pull-outs cite "I didn't want to see what I'd done" as the dominant abandonment reason, not "this is too much typing."
- The PMC11764542 (2025) study on social-support overload in fitness apps included a now-widely-cited participant quote: *"I hate being constantly asked to think about how I feel."* Cognitive load includes the cost of *re-encountering the body* the app forces you to think about.

**What this means for JeniFit:** the founder's intuition that "less input = more usage" is correct in *direction* but wrong in *cause*. The friction Gen-Z women avoid is **affective**, not motoric. A 3-tap weight log will fail for the same reason a 1-tap weight log fails: it makes them confront the scale. The intervention that actually works is **reframing the act** (passive trend, EMA smoothing, no daily number on Home, optional weigh-in framed as "checking in with where you are this week" not "logging weight").

The corollary is also true: Gen-Z women will tolerate *significantly* more input than the lazy-frame predicts when the input feels identity-aligned and aesthetically rewarding. Cal AI's success in this cohort is not "low friction" — it's "the input is a camera roll, which they already use 90 times a day." See Question 3.

---

## 2. The "magical experience" psychological mechanism for Gen-Z women

**Question:** Variable reward? Effortless reveal? Aesthetic delight? Speed? Identity reinforcement?

**Answer: it is a stack, in this order — speed > aesthetic delight > identity reinforcement > variable reward.** The Hooked Model (Eyal) and the Fogg Behavior Model (B = M × A × P) are both still load-bearing in 2024-26 application writeups, but the *weighting* has shifted.

The 2024-26 evidence:

- **Speed is the gatekeeper.** The Fogg Behavior Model in current AI-experience design writeups (Roy 2025, Medium) emphasizes that **Ability** (specifically time-to-result) has overtaken **Motivation** as the dominant lever in Gen-Z mobile UX. If a "magical" interaction takes >3 seconds, the magic decays into impatience. Cal AI's ~2-second scan-to-result is the threshold.
- **Aesthetic delight is the affective payoff.** Designlab's *Designing for Gen Z* 2025 brief and Fullstory's *UX Trends 2025* both identify "micro-interactions and themed illustrations that celebrate progress" as the dominant differentiator for Gen-Z app retention. JeniFit's coquette sticker + scrapbook chrome is structurally correct.
- **Identity reinforcement is the moat.** The 2025 Zhu et al. meta-analysis (*Applied Psychology: Health and Well-Being*, Wiley 2025) and the 12-week within-person identity study (PMC12109062, 2025) both demonstrate that identity-consistent feedback ("you are a person who shows up for yourself") drives higher behavioral maintenance than outcome-consistent feedback ("you burned 200 calories"). The JeniFit "becoming" frame is research-aligned.
- **Variable reward is real but ranked lower for this cohort.** Eyal's Hooked Model still works — uncertainty drives dopamine — but the 2024-26 Duolingo backlash (HerCampus 2025; Fast Company 2025) is a cautionary tale: when variable reward becomes coercive (streak threats, owl guilt), Gen-Z women specifically flip from engagement to revulsion. They detect manipulation faster than older cohorts and punish it with TikTok mockery.

**What this means for JeniFit:**
1. Optimize the camera result-card time-to-reveal to <2.5s. Above that, the magic dies.
2. Use the existing coquette sticker system on the result card. Do not strip it. Premium-restraint is a *typography* principle, not a *visual density* principle for this brand (per locked memory).
3. The result card should reinforce identity ("**becoming** the version of you who notices what fits ♥") not outcome ("420 calories — on track").
4. Avoid manipulation-coded mechanics: no anxiety-inducing notifications, no streak threats, no countdown timers framed as urgency.

---

## 3. Photo-scan vs manual log — is it just convenience, or is there a deeper mechanism?

**Verdict: there is a deeper mechanism, and it is the load-bearing reason the founder's hypothesis 1 is right.**

The convenience story is the obvious one and it is partially true (Cal AI's growth proves users prefer it). But the peer-reviewed and qualitative work suggests three deeper mechanisms that the camera unlocks and a typed entry does not:

1. **Reduced verbal-naming cost.** The BJPsych Open 2024 qualitative study (*Effects of diet and fitness apps on eating disorder behaviours*, Cambridge Core) reports that *typing* a food name is a recurring trigger point for self-criticism among women with weight-loss motivation. The act of writing "donut" creates an explicit moral category in working memory. A photo bypasses the naming step — the user sees a result without having to *label themselves as the kind of person who ate that*. This is a meaningful affective offload.
2. **Plausible deniability of precision.** Calorie-tracking apps trigger the rigidity associated with calorie counting (Levinson et al., ScienceDirect 2022; PMC9109125 RCT 2022). Photo-scan results inherently feel less precise ("the AI estimated this"), which gives the user *psychological permission* to treat the number as approximate. This is protective. Manual entry feels exact; exactness feeds the all-or-nothing thinking that drives disordered eating.
3. **Camera ritual aligns with native behavior.** Gen-Z women take ~90 photos/day on average (GWI 2025-equivalent figures, see Designlab). The camera-as-input slots into existing behavior; manual entry creates new behavior. BJ Fogg's Tiny Habits prescription is: *anchor a new habit to an existing one*. The camera does that automatically.

**What this means for JeniFit:**
- The founder's photo-to-value bet is the correct lever, BUT the result-card design must lean into the *non-judgmental reflection* frame, not the *verdict* frame. Show macro composition aesthetically (e.g., a soft visual breakdown), not a stark calorie verdict.
- Never make the user *type* a food name as the primary path. The "edit / correct" path should be available but secondary; making correction the default would re-introduce the naming cost the camera was supposed to remove.
- Lean into approximation language. "~420 cal, mostly carbs + a little fat" outperforms "420 cal — 38g C / 12g F / 8g P" for this cohort. Specificity feeds rigidity (per Levinson 2022).

---

## 4. Post-Ozempic body-image psychology in 2026 — is "calorie" the trigger word?

**Verdict: the word itself is not banned, but its prominence is the biggest UX-level lever you have against disordered-eating spillover, and the cohort has shifted under you.**

The 2024-26 evidence has been moving fast and converging:

- **News-Medical April 2025:** 73.6% of Gen-Z respondents are aware of Ozempic/Wegovy; 48.8% know it's used for weight loss. Awareness density is total.
- **Virta Health 2025 ("No-zempic?")** 72% of Gen-Z respondents agree that GLP-1 prominence has *negatively* affected the body-positivity movement. This cohort has *named* the cultural shift and is suspicious of any product that smells like it's chasing the GLP-1 thinness aesthetic.
- **2025 *Body Image* journal study** (cited in News-Medical): users *most interested* in GLP-1s reported **higher body shame, more frequent body monitoring, greater weight concerns**. Your most-acquirable users are also your most-fragile users.
- **PMC12909219 (2026) — "Calorie tracking and energy balance: links to body image-related factors and functional impairment"** explicitly links calorie-tracking visibility to *drive for thinness* in fitness-oriented samples (n > 5,900, majority women). Not correlation-with-eating-disorders generically — *specific* drive-for-thinness amplification.
- **2025 *Beyond Weight Loss* paper (PMC12694361)** on GLP-1s and eating-disorder psychosocial processes flags that the GLP-1 cultural moment has *re-medicalized* weight in a way that primes users to treat any calorie number as a clinical verdict, not a soft estimate.

**What this means for JeniFit:**
- Do **not** ban the word "calorie." Trying to invent a euphemism (à la "energy units") reads as condescending to this cohort. They know the word.
- **Do** reduce the prominence of the number. The Home ring should be the smoothed trend, not "1,640 / 1,800 cal today." The calorie number can live on the food card and in the day-detail view, never as the Home hero.
- **Do** add an under-target safety net (per locked memory). Showing "you're under target — that's fine for today ♥" when calories are low protects the restriction/GLP-1 cohort. Cal-AI does not do this. It's a white-space gap (per locked calorie-competitor-landscape memory).
- **Do not** show daily calorie deltas as red. The Hot Garbage red bar that MyFitnessPal still uses is exactly the visual grammar Gen-Z women cite as ED-triggering in qualitative work.

---

## 5. Calorie-as-hero vs trend-as-hero — which drives engagement without disordered-eating spillover?

**Verdict: trend-as-hero is the only defensible choice for this cohort. Calorie-as-hero is a known disordered-eating accelerator with this exact demographic.**

This is the most evidence-saturated of the founder's questions, and the answer is unambiguous:

- **Helander et al. (PLOS ONE 2014, still the canonical study)** demonstrated that **daily self-weighing combined with a smoothed trend view** produces both better adherence AND less day-to-day emotional volatility than daily weighing with raw-number display. The smoothing *is* the intervention.
- **Pacanowski et al. 2024** (cited via Stronger by Science 2025 review) reinforces: daily weighing without smoothing is associated with elevated disordered-eating risk among women with weight-loss motivation; daily weighing with trend smoothing is *protective*.
- The **2025 systematic review** (Linardon et al., PMC12547374) and the **BJPsych Open 2024 qualitative study** both conclude that the **visual hierarchy of the tracking surface** is the single largest moderator between "supportive monitoring" and "disordered monitoring." Hero numbers prime rigidity; hero trends prime patience.
- The **eating-disorder recovery clinical community in 2024-26** (Duke Department of Psychiatry "The Trouble with Tracking" 2024; ScienceDirect Levinson 2022 follow-up work) is broadly consistent: when raw daily numbers are demoted and trends are promoted, monitoring adherence stays similar but ED-symptom escalation drops measurably.

**What this means for JeniFit:**
- Home ring = **smoothed EMA weight trend** with a clear "this is a trend, not today's number" caption. Already implemented per locked architecture; keep it.
- Becoming tab = **weight trend EMA card + goal pace projection** as primary modules. Already research-aligned per project status doc.
- Add a *passive* weight log option: if the user opens the app, we can ask once/week ("how are you feeling about where you are this week? ♥") instead of pushing for a numeric entry. This converts the act from logging to checking-in. (See Question 1.)
- For calories: show the daily target only in the food-detail view, never on Home. The pre-eat mode result card can show "this fits" / "this is a stretch" framings instead of a hard number when the cohort flag indicates ED-risk.

---

## 6. Notification psychology — Gen-Z women trial-week notification tolerance

**Verdict: 3-4 notifications/week is the ceiling for this cohort. JeniFit's "~5 in trial week" is at the edge. Cut to 3-4, and re-language all of them away from scale/streak/guilt frames.**

The 2025 numbers are clear:

- **BusinessOfApps 2025 Push Notification Statistics:** opt-in rates fell to **38% in 2025** (from 40-43% in 2023). Fatigue is measurable and trending negative.
- **Mobiloud Push Notification Stats 2025:** when users receive **3-6 push notifications, 40% disable app notifications**. One weekly push pushes 10% to disable. The breakage point sits squarely in JeniFit's current trial-week budget.
- **BusinessOfApps 2025:** retention is **~3x higher** when users get *any* notifications in their first 90 days vs none. So the answer is not "zero." The answer is **few, identity-affirming, and timed to natural moments**.
- **Gen-Z specifically:** age 18-24 spends 112.6 hr/month on mobile apps (sqmagazine 2025). They are notification-saturated, not notification-deprived. Marginal cost of one more push is higher in 2026 than it was in 2023.

**Copy guidance (synthesized with locked notification-voice memory):**

| Day | Send | Don't send |
|---|---|---|
| Day 0 (anchor) | "you're in. small first step today ♥" | "ready to crush week 1?" |
| Day 2 (engagement) | "your **becoming** is showing up. peek at today?" | "don't break your streak!" |
| Day 4 (gentle progress) | "this week's trend is starting to shape ♥" | "you logged 1,840 cal today — under target!" |
| Day 6 (identity reinforcement) | "the version of you a week ago would be proud" | "weigh in to see results!" |

**Cap rule:** 4 notifications across trial week, all identity-affirming, no scale numbers, no streak threats, no calorie-specific framing. The locked memory `[project_trial_week_notifications]` already captures this direction (Day 0 anchor + Day 2 engagement + first-week affirmation pause). Stay there.

---

## 7. Streak psychology for Gen-Z weight-loss — YES or NO?

**Verdict: NO classic streaks. YES soft continuity. The 2024-26 evidence is one of the clearest reversals in consumer-app behavioral design.**

- **The Duolingo backlash is real and named.** HerCampus UCLA 2025 ("Deserting Duolingo: How Duolingo Fumbled Gen Z"): "the owl that once was a beloved meme is now seen as one of Gen Z's enemies." Fast Company 2025 documented users *gaming the system to mock the streak* rather than honor it. HBR podcast 2025 with Duolingo's CEO acknowledged the brand-perception cost.
- **The mechanic still drives retention** (3x daily return when streak is active, per Duolingo case studies) — but for *Duolingo*, where the stakes are "learning Spanish." For *weight loss* in a cohort with elevated ED risk and active body-image trauma, the same mechanic becomes a guilt amplifier.
- **The clinical concern:** locked memory + Levinson 2022 + Linardon 2025 systematic review consistently flag that all-or-nothing thinking is the highest-risk cognitive pattern for disordered eating. A streak counter *is* a UI manifestation of all-or-nothing thinking — by definition, missing a day breaks it.
- **The Gen-Z brand cost:** this cohort has explicit anti-manipulation literacy. They will identify a streak mechanic as a dark pattern and post about it. Per locked target-audience memory: anti-femvertising, brand sensitivity is high.

**What to ship instead:**
- **Soft continuity language.** "you've been showing up 3 of the last 5 days ♥" — frames consistency as positive without making a missed day feel like a failure.
- **No counter that resets to 0.** A rolling 7-day "showed-up days" pill is fine. A streak that breaks is not.
- **No streak-loss notifications, ever.** Even soft ones. The asymmetric loss aversion lights up the same affective circuit as scale-shame.

---

## 8. Identity reinforcement — "becoming" as a verbal motif vs goal language

**Verdict: identity language is research-validated and increasingly well-evidenced. JeniFit's "becoming" frame is the single most defensible brand choice for behavior-change adherence in this cohort.**

The 2024-26 evidence on identity vs goal language for behavior change has consolidated rapidly:

- **Zhu et al. 2025 meta-analysis** (*Applied Psychology: Health and Well-Being*, Wiley 2025; doi 10.1111/aphw.70017): three-level meta-analysis of habit + identity in health behaviors found that **behavior-congruent identity** sustains behaviors when habits alone are insufficient. The two constructs are separable, but identity is the *maintenance* lever specifically.
- **Rhodes 2025** (*Applied Psychology: Health and Well-Being*, Wiley 2025; doi 10.1111/aphw.70009): 12-week longitudinal study on parents with young children — identity formation precedes and predicts sustained physical activity, not the other way around. Identity language *creates* the behavior; goal language tracks it.
- **PMC12109062 (May 2025):** "The Influence of Identity Within-Person and Between Behaviours: A 12-Week Repeated Measures Study" found identity-consistent feedback drove within-person behavioral consistency above and beyond baseline motivation.
- **Goal language has a documented attrition cost:** the PMC9931249 observational study on digital weight programs found psychologically distanced *goal* language correlated with more weight loss and *less attrition* than immediate goal language. This nuance matters: identity-framed "I am becoming someone who shows up" is psychologically distanced; outcome-framed "I need to lose 12 lb by August" is immediate. The brand voice happens to land on the higher-adherence side.

**Copy patterns to use:**

| Identity language (ship this) | Goal language (avoid) |
|---|---|
| "becoming the version of you who notices what fits ♥" | "5 lb to go — keep pushing" |
| "you're the kind of person who shows up for yourself" | "log your weight to hit your target" |
| "today's small thing is part of who you're becoming ♥" | "don't break your streak — log now" |
| "your becoming is showing up in your trend ♥" | "you're 78% to your goal" |

The italic-Fraunces punch-word system already operationalizes this — *becoming*, *today*, *shows up* are all identity verbs, not outcome nouns. Keep all three.

**One nuance to watch:** the BJPsych Open 2024 qualitative work flagged that *forced* identity language ("you are a strong woman!") feels patronizing to this cohort. The current JeniFit register — lowercase casual, identity-as-process, hearts as terminal punctuation — is the safer pattern. Stay descriptive ("you're becoming"), not prescriptive ("you are").

---

## Closing: the three-bullet shipping recommendation

1. **Home hero = smoothed weight trend ring + identity caption.** Never a daily calorie number. Calorie target lives in food-detail view only. Add an under-target safety-net message to protect the restriction / GLP-1 cohort. *Evidence: Helander 2014, Pacanowski 2024, Linardon 2025, Virta 2025.*
2. **Photo-camera = primary food on-ramp; result card = non-judgmental reflection.** Approximate language ("~420 cal, mostly carbs + a little fat"), aesthetic composition view, no red/green verdict. Never force food-naming as the default. *Evidence: Levinson 2022, BJPsych Open 2024, BJ Fogg behavior model.*
3. **No streaks, ≤4 trial-week notifications, all identity-framed.** Soft continuity pill replaces streak counter. Notification copy uses *becoming*, *showing up*, *the version of you*, never scale numbers or streak threats. *Evidence: Zhu et al. 2025 meta-analysis, Rhodes 2025 RCT, BusinessOfApps 2025 push fatigue stats, HBR 2025 Duolingo case.*

The founder's instincts on the camera as a lever are sound. The instincts on Gen-Z laziness are misdiagnosed — the cohort is protective, not lazy, and treating them as lazy will produce UX that lowers friction without addressing avoidance. The instincts on calories are the most dangerous: the calorie *engine* must run, but the calorie *number* must not be the visual hero in 2026 for this cohort. Ship trend-as-hero, camera-as-onramp, identity-as-voice, and JeniFit will be on the right side of the 2024-26 cultural shift instead of trailing it.

---

## Sources

**Peer-reviewed:**
- Linardon J. et al. (2025) "Associations Between the Use of Fitness and Diet Tracking Technology and Disordered Eating Behaviour: A Systematic Review." PMC12547374. https://pmc.ncbi.nlm.nih.gov/articles/PMC12547374/
- Calorie tracking and energy balance (2026). PMC12909219. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12909219/
- Beyond Weight Loss: GLP-1 Usage and Appetite Regulation… (2025). PMC12694361. https://pmc.ncbi.nlm.nih.gov/articles/PMC12694361/
- Effects of diet and fitness apps on eating disorder behaviours: qualitative study. *BJPsych Open*, Cambridge Core. https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
- Levinson C. et al. "Using an app to count calories: motives, perceptions, and connections to thinness- and muscularity-oriented disordered eating." ScienceDirect. https://www.sciencedirect.com/science/article/abs/pii/S1471015321000957
- West J. et al. (2022) "Introducing Dietary Self-Monitoring to Undergraduate Women via a Calorie Counting App…" PMC9109125. https://pmc.ncbi.nlm.nih.gov/articles/PMC9109125/
- Oliveira RSC. et al. (2025) "Mobile weight self-monitoring adherence and eating behavior changes: A secondary analysis of a 12-month RCT." Sage / DIGITAL HEALTH 2025. https://doi.org/10.1177/20552076251395530
- Zhu et al. (2025) "The relationship between habit and identity in health behaviors: A systematic review and three-level meta-analysis." *Applied Psychology: Health and Well-Being*, Wiley. https://iaap-journals.onlinelibrary.wiley.com/doi/abs/10.1111/aphw.70017
- Rhodes R. (2025) "Changes in identity and habit formation during 3 months of sport and physical activity participation among parents with young children." *Applied Psychology: Health and Well-Being*. https://iaap-journals.onlinelibrary.wiley.com/doi/10.1111/aphw.70009
- "The Influence of Identity Within-Person and Between Behaviours: A 12-Week Repeated Measures Study." PMC12109062 (May 2025). https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12109062/
- "Goal language is associated with attrition and weight loss on a digital program." PMC9931249. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9931249/
- "When I Receive Too Much Social Support: The Effect of Social Support Overload…" PMC11764542. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11764542/
- "Are Breaks in Daily Self-Weighing Associated with Weight Gain?" PLOS ONE (Helander). https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0113164
- "Hybrid Health IT and Telehealth Behavioral Weight Loss…" JMIR mHealth and uHealth 2025. https://mhealth.jmir.org/2025/1/e58722
- "Calorie-Counting Apps for Monitoring and Managing Calorie Intake in Adults Living With Weight-Related Chronic Diseases: Decade-Long Scoping Review (2013-2024)." JMIR mHealth 2026. https://mhealth.jmir.org/2026/1/e64139

**Market / behavioral writeups (2024-2026):**
- BJ Fogg, "Learn the Fogg Behavior Model." https://www.bjfogg.com/learn
- Roy K. (2025) "Designing with Intention: Applying BJ Fogg's Behavioral Model in AI Experiences." Bootcamp / Medium. https://medium.com/design-bootcamp/designing-with-intention-applying-bj-foggs-behavioral-model-in-ai-experiences-05ea6dca3069
- News-Medical (Apr 2025) "What's behind Gen Z's skepticism about Ozempic and Wegovy." https://www.news-medical.net/news/20250424/Whate28099s-behind-Gen-Ze28099s-skepticism-about-Ozempic-and-Wegovy.aspx
- Virta Health (2025) "No-zempic? 64% of Americans Agree Popularity of Weight Loss Drugs is Bad for Body Positivity." https://www.virtahealth.com/blog/americans-agree-popularity-of-weight-loss-drugs-is-bad-for-body-positivity
- BusinessOfApps (2025) Push Notifications Statistics. https://www.businessofapps.com/marketplace/push-notifications/research/push-notifications-statistics/
- Mobiloud (2025) "50+ Push Notification Statistics for 2025." https://www.mobiloud.com/blog/push-notification-statistics
- HerCampus UCLA (2025) "Deserting Duolingo: How Duolingo Fumbled Gen Z." https://www.hercampus.com/school/ucla/deserting-duolingo-how-duolingo-fumbled-gen-z/
- Fast Company (2025) "Here's how to restore your long-dead Duolingo streak." https://www.fastcompany.com/91551760/heres-how-to-restore-your-long-dead-duolingo-streak
- HBR (Apr 2025) "How Duolingo Aims to Diversify Beyond Language Learning." https://hbr.org/podcast/2025/04/how-duolingo-aims-to-diversify-beyond-language-learning
- Designlab "Designing for Gen Z." https://designlab.com/blog/designing-for-gen-z
- Fullstory "UX Trends 2025." https://www.fullstory.com/blog/ui-ux-trends/
- Sqmagazine "Mobile App Growth Statistics 2025." https://sqmagazine.co.uk/mobile-app-growth-statistics/
- Medscape (2025) "GLP-1s May Quiet 'Food Noise' and Alter Taste." https://www.medscape.com/viewarticle/glp-1s-may-quiet-food-noise-and-alter-taste-2025a1000os0
- Duke Department of Psychiatry "The Trouble with Tracking." https://psychiatry.duke.edu/blog/trouble-tracking
- Stronger by Science "Diet Tracking and Disordered Eating: Which Comes First?" https://www.strongerbyscience.com/diet-tracking/
