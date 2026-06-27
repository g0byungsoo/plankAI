# Cal AI Onboarding — Weight-Loss Program Expert Brief

**Date:** 2026-06-05 · **Lens:** WL program domain expert, behavioral-science + Gen-Z women cohort psychology. Question-content + program-psychology — NOT visual design, pricing, or cultural fit (sibling agents cover those).

**Reference set:** 43 Cal AI onboarding screenshots (`calai1.PNG`–`calai43.PNG`). JeniFit's current `v2FlowOrder` at `/Users/bko/plankAI/PlankApp/Views/Onboarding/OnboardingView.swift:1475`.

**Bottom line:** Cal AI's question set is shorter than JeniFit's (~30 functional question screens vs JeniFit's 58) and ruthlessly engineered for a **single use case** (calorie-counter calibration). JeniFit needs FOUR things Cal AI does extremely well — the **Slow / Recommended / Fast pace selector**, the **investment "have you tried" question**, the **commitment "do you work with a coach" pattern**, and the **"this is used to calibrate your custom plan" subtitle on every biometric** — and should REJECT four things — Cal AI's **fake-modal notification prime, premium-feature tease (rollover/burned calories), the "lose twice as much" claim**, and the **fabricated "$15 of bills" testimonial pattern**. JeniFit also has the opposite problem: 58 screens means it can cut ~12 cases without losing program quality. The pace selector alone is probably the single highest-leverage question-level addition.

---

## 1. Full question inventory (43 screens)

| # | Screen | Question / Heading | Data captured | Downstream use |
|---|---|---|---|---|
| 1 | calai1 | "Calorie tracking made easy" — hero | none (CTA) | Sets category frame as calorie-counting |
| 2 | calai2 | "Choose your Gender" (Male/Female/Other) | gender | BMR (Mifflin-St Jeor) + plan calibration |
| 3 | calai3 | "How many workouts do you do per week?" (0-2 / 3-5 / 6+) | activity tier | TDEE multiplier + plan calibration |
| 4 | calai4 | "Cal AI creates long-term results" — 80% maintain claim, weight curve vs traditional diet | none (social proof) | Loss-aversion prime before goal Q |
| 5 | calai5 | "Where did you hear about us?" (FB/TV/TikTok/Friend/AppStore/YT) | attribution | Marketing attribution; no UX impact |
| 6 | calai6 | "Have you tried other calorie tracking apps?" (Yes/No) | investment | NONE — pure commitment activation |
| 7 | calai7 | (between desired wt + pace) "Losing 5.3kg is a realistic target. It's not hard at all! 90% of users say change is obvious" | none (reframe) | Lowers perceived difficulty → unlocks pace selection |
| 8 | calai8 | "How fast do you want to reach your goal?" (Slow 0.3kg/wk) | pace selection | Daily calorie target + ETA |
| 9 | calai9 | "Do you currently work with a personal coach or nutritionist?" (Yes/No) | premium-substitute signal | Justifies $30/yr vs $200/mo coach |
| 10 | calai10 | "What is your goal?" (Lose / Maintain / Gain) | goal direction | Calorie target direction |
| 11 | calai11 | "What is your desired weight?" — ruler picker | target weight | Delta = kg-to-lose for screen 7 reframe |
| 12 | calai12 | (Same as calai7 — actual position is post-desired-weight) | — | — |
| 13 | calai13 | (= calai9) Coach/nutritionist | — | — |
| 14 | calai14 | "What would you like to accomplish?" (Eat healthier / Boost energy / Stay motivated / Feel better about body) | identity outcome | Notification tone + paywall sub-copy |
| 15 | calai15 | (= calai17 / pace at Slow) | — | — |
| 16 | calai16 | (= calai14) | — | — |
| 17 | calai17 | Pace = Slow (0.3 kg/wk, 4 months, 2,130 cal) | — | — |
| 18 | calai18 | Pace = Recommended (0.7 kg/wk, 2 months, 1,689 cal) | — | — |
| 19 | calai19 | Pace = Fast (1.4 kg/wk, 25 days, 918 cal, warning) | — | — |
| 20 | calai20 | "What's stopping you from reaching your goals?" (consistency / unhealthy eating / support / busy / meal inspiration) | barrier | Notification copy + paywall subhead |
| 21 | calai21 | "Do you follow a specific diet?" (Classic / Pescatarian / Vegetarian / Vegan) | diet pattern | Recipe rec, macro split |
| 22 | calai22 | "What would you like to accomplish?" (duplicate) | — | — |
| 23 | calai23 | "You have great potential to crush your goal" — weight transition curve 3/7/30d | none (projection) | Psychology of compounding |
| 24 | calai24 | "Thank you for trusting us — Now let's personalize Cal AI for you…" | none (transition) | Reciprocity beat |
| 25 | calai25 | "Connect to Apple Health" (Continue / Skip) | HK permission | TDEE refinement, passive activity |
| 26 | calai26 | "Add calories burned back to your daily goal?" (No / Yes) | preference (premium-tease) | Setting + Pro upsell |
| 27 | calai27 | "Rollover extra calories to the next day?" — yesterday/today card visual (No / Yes) | preference (premium-tease) | Setting + Pro upsell |
| 28 | calai28 | "Lose twice as much weight with Cal AI vs on your own" — 20% vs 2X bar chart | none (claim) | Conversion frame ("makes it easy and holds you accountable") |
| 29 | calai29 | "Join over 10 million people like you" — 4.8★, in-app rating sheet auto-fires | rating prompt | App Store rating capture |
| 30 | calai30 | "Join over 10 million" — Jake + Benny testimonials, 4.8★, 250K ratings, 10M users | none (social proof) | Pre-paywall trust |
| 31 | calai31 | "Be reminded to log meals" — fake iOS notification prompt | notif permission | Habit-loop engineering |
| 32 | calai32 | Real iOS notification permission system sheet | — | — |
| 33 | calai33 | (Same as calai20 — barriers screen post-trust transition) | — | — |
| 34 | calai34 | ATT prompt + "21% — We're setting everything up for you" loading | tracking + theater | Personalization theater |
| 35 | calai35 | "67% — Estimating your metabolic age…" + checklist (Calories, Carbs, Protein, Fats, Health Score) | loading frame | Theater |
| 36 | calai36 | "91% — Finalizing results…" + 4 checks | loading frame | Theater |
| 37 | calai37 | "97% — Finalizing results…" + 5 checks | loading frame | Theater |
| 38 | calai38 | "Congratulations your custom plan is ready! You should lose 5.3 kg by May 18" + daily ring (Calories/Carbs/Protein/Fats) | reveal | Plan reveal |
| 39 | calai39 | "Health Score 7/10 + How to reach your goals" + "Plan based on the following sources, among other peer-reviewed medical" | reveal pt.2 | Credibility purchase |
| 40 | calai40 | "Save your progress" — Sign in with Apple / Google / Email — sign-in is AT THE END | auth | Auth deferral pattern |
| 41 | calai41 | "Enter referral code (optional)" — Skip available | referral | Growth loop |
| 42 | calai42 | "We want you to try CalAI for free" — soft paywall (Try Now / $29.99/yr) | — | Paywall A |
| 43 | calai43 | "Start your 3-day FREE trial to continue" — Today/Reminder timeline, Monthly $9.99 vs Yearly $29.99 | — | Paywall B (closing) |

Note: several screens recur (calai9/13 coach, calai14/16/22 accomplish, calai20/33 barriers). This is QA capture variance, not a Cal AI design pattern — they're not asking twice.

## 2. The 4 question types Cal AI uses

**Calibration questions** — gender (calai2), workouts/week (calai3), height/weight (calai6/8), DOB (calai9), goal (calai10), desired weight (calai11), pace (calai17–19), diet (calai21). **Every single one carries the subhead "This will be used to calibrate your custom plan."** This subhead is doing more conversion work than any single component on the screen — it converts a "why are they asking?" friction beat into a sunk-cost reciprocity beat. Cohort fit: high. JeniFit equivalent: partial — `WeAskBecauseRow` (cases 154/155/156/157/159/162/163/164) is the equivalent and is actually richer (cites NHANES, BMJ, Epel Yale, Bandura). The cohort prefers JeniFit's anchored citations over Cal AI's generic "calibrate" because credibility purchase is higher.

**Investment questions** — "Have you tried other calorie tracking apps?" (calai6). The answer doesn't change a single byte of output. The act of answering creates Cialdini commitment-consistency: she's now positioned herself as "someone who has been looking for the right calorie app." Cohort fit: very high — TikTok-acquired cohort is in the middle of an active app evaluation. JeniFit equivalent: **none currently.** This is a single-screen, S-effort win.

**Commitment questions** — pace selector (calai17/18/19), commitment confidence (would be JeniFit's case 165). Bandura self-efficacy mechanism: she's not being told what pace, she's choosing it, which raises the perceived probability of follow-through. Cohort fit: very high. JeniFit equivalent: case 165 (the commit-confidence Q), partial.

**Acknowledgment questions** — barriers (calai20/33). Mechanism: barrier validation per Rhodes & de Bruijn 2013 — when the user names the barrier, the program can "claim" to address it without making a fabricated promise. Cohort fit: high. JeniFit equivalent: case 153 (consolidated barriers multi-select) — already adopted.

The 4-type taxonomy matters because **every onboarding question should do ONE of these jobs**. If a question doesn't calibrate, invest, commit, or acknowledge, it's bloat. Apply this to JeniFit's 58 screens (section 13).

## 3. The math of the projection

Cal AI assembles the projection across **four screens in a deliberate sequence**:

- **calai4 "Cal AI creates long-term results"** — 80% maintain claim with a "traditional diet" comparison curve. Loss-aversion frame. Lands BEFORE the goal Q (calai10).
- **calai7 "Losing 5.3 kg is a realistic target. It's not hard at all!"** — 90% claim. Lands AFTER desired-weight input. Reframes effort downward right before the pace selector.
- **calai23 "You have great potential to crush your goal"** — 3-day / 7-day / 30-day weight transition curve. Visualizes the delayed-onset pattern. Lands AFTER trust transition (calai24).
- **calai28 "Lose twice as much weight with Cal AI vs on your own"** — 20% vs 2X bar chart. Pre-paywall comparison frame.

**Psychological architecture:** prime loss (4) → input goal → reduce perceived effort (7) → choose pace (8/17/18/19) → visualize delayed-loss curve to immunize against Day-3 churn (23) → comparison purchase (28).

**Evidence-backed vs marketing:**
- 80% maintain (calai4): UNGROUNDED. The actual WL maintenance literature is brutal — Wing & Phelan 2005 reports ~20% long-term maintenance of 10% loss for ≥1 year. 80% would be a 4× claim above the cohort baseline and almost certainly does not hold up in Cal AI's own cohort data.
- 90% obvious change (calai7): UNGROUNDED. No methodology disclosed.
- 2X vs on your own (calai28): UNGROUNDED. The closest defensible claim is Burke et al. 2011 self-monitoring meta-analysis (logging predicts modestly better outcomes), but "2X" is editorial.
- Delayed-loss curve (calai23): DIRECTIONALLY TRUE. Loss frequently lags by 1-3 weeks (NEAT/glycogen). Cal AI honestly hand-waves the mechanism.
- 5.3 kg ETA = "May 18" (calai38): MATH-VALID assuming a constant ~0.7 kg/wk pace from current weight delta.

**Apple/FTC navigation:** Cal AI uses "users say" framing on the social claims (calai7) — that's testimonial/preference framing, not outcome claim. They show "Plan based on … peer-reviewed medical" without listing the actual citations (calai39) — credibility purchase without an FTC-actionable assertion. The 80% / 2X / 90% numbers are positioned as "Cal AI's historical data" or unattributed, which puts them in marketing-puffery gray zone. They are taking risk that Apple has so far tolerated; JeniFit should not copy the unattributed numbers — JeniFit's data-provenance lock would be violated. JeniFit's `WeAskBecauseRow` citation pattern is the cleaner play.

**JeniFit's projection today (case 161 `firstPredictionScreen` + case 170 `rePredictionScreen` + case 21 `planRevealScreen`):** a weight curve + program plan. **Add WITHOUT making unbackable claims:**
1. **Delayed-onset visual** like calai23 — JeniFit's existing curve smoothed with a "weeks 1-2: scale moves slowly; weeks 3-4: real loss" annotation. Source: NEAT/glycogen literature (cite Pontzer 2026 review).
2. **WHO maintenance frame** — JeniFit's case 234 `educationalPlateauScreen` already runs this beat; tie it explicitly to the projection.
3. **Drop any "X% of users" claim** — JeniFit doesn't have N>250 paid users yet. Substitute "your sleep + stress + cycle stage put you in a cohort where…" — programmatic, not fabricated.

## 4. Pace selector (calai17 / calai18 / calai19) — the genius move

Cal AI gives a 3-position slider — Slow (0.3 kg/wk, 4 months, sloth, 2,130 cal), Recommended (0.7 kg/wk, 2 months, hamster, 1,689 cal), Fast (1.4 kg/wk, 25 days, panther, 918 cal). **Each position updates THREE things in real time:** weight/wk number, ETA, daily calorie target. Fast position adds a warning: "Fast loss can cause fatigue or loose skin."

**Why it's brilliant:**
1. **Self-efficacy (Bandura 1997):** the user chooses pace, not the algorithm. Locus of control transfers to her. Drives adherence post-trial.
2. **Anchoring + framing:** Recommended is pre-selected and visually centered. Slow and Fast are flanked. This is Sunsteinian default-design — most users land on Recommended, but the OPTION matters more than the path.
3. **Warning as commitment device:** the Fast warning operationalizes informed consent. If she picks Fast, she's accepted the risk. If she steps back to Recommended, she's chosen the safer path with full awareness. Both routes produce commitment.
4. **Calorie target reveal as commitment device:** seeing "918 cal" at Fast position is sobering. Most users self-de-escalate to Recommended. The product implicitly nudges toward sustainable pace.
5. **The animals do real psychological work:** sloth/hamster/panther turn pace into an identity choice (which animal am I?) — much stickier than "0.3 / 0.7 / 1.4."

**Should JeniFit adopt? YES — highest-leverage question-level addition in this brief.**

**Adapt to JeniFit's 12-week becoming frame:**
- 3 positions: **gentle / steady / focused** (rejecting "Slow/Fast" connotations + sloth/panther — too 2018 diet-culture; cohort vocabulary lock).
- gentle = ~0.25 kg/wk, 16-20 wks → "your becoming, no force"
- steady = ~0.5 kg/wk, 12 wks (anchor) → "your *becoming*, the program pace"
- focused = ~0.8 kg/wk, 8 wks → "your *becoming*, fastest sustainable" + warning "moves quickly; protein floor + sleep matter more"
- NO calorie number on screen (food rail is v1.0.7, hasn't shipped yet; revealing calorie target on this screen tips into Cal-AI-coded mental model that the cohort is resisting).
- DO show: weeks-to-goal + a 1-line reframe per position.
- Sticker animation: bow → flower3D → sparkleGlossy (in-brand sticker pack, not animal cartoons).

**Slot:** between case 161 (`firstPredictionScreen`) and case 170 (`rePredictionScreen`). The pace choice becomes an input to the re-prediction so the curve updates.

## 5. The "have you tried" question (calai10/6) — sunk-cost activation

**Why ask:** the answer doesn't gate anything. The asking does three jobs:
1. **Frames the category:** by asking, Cal AI implicitly says "you've been shopping for this; we know the alternatives; we're not naive."
2. **Activates loss aversion on prior apps:** Yes-answerers now hold a sunk cost on prior attempts (MFP, Lose It!, Noom). Cal AI inherits "the one that finally works" frame for free.
3. **Identity signal:** No-answerers segment as first-timers; Yes-answerers as veterans. Either way, they've self-categorized.

**Cohort fit:** very high. The TikTok-acquired Gen-Z cohort has likely tried 2-4 wellness apps already (see `feedback_onboarding_v2_research.md` — 65% pay for wellness apps).

**Should JeniFit adopt? YES — Single-screen, S-effort, high-cohort-fit.**

**JeniFit variant:** "have you tried other weight-loss apps?" — yes/no. **Better variant for JeniFit's diet-first positioning:** "have you tried calorie counting before?" — yes / a little / never. The 3-option variant lets Jeni's voice differ later: "we counted too, then realized snapping is easier ♥" vs "let's not start with rules." Routes back together — no path gates.

**Slot:** post-case 100 (attribution), pre-case 162 (food relationship). Lives in Act 1 right before the food wedge — the priming arc is "where she came from → category context → first food Q."

## 6. The "coach/nutritionist" question (calai9/13) — premium-substitute framing

**Why ask:** Cal AI positions itself as premium-substitute. Yes-answerers get implicit validation ("you already invested in this category"), No-answerers get a subtle frame for the paywall: "Cal AI = your coach for $30/yr vs $200/mo." Either path lifts paywall psychology.

**Cohort fit:** medium-high. JeniFit's cohort skews younger / less affluent than Cal AI's — fewer have paid coaches. But the question still works: the *absence* of a coach is normative; the question signals JeniFit treats coaching as the gold standard. The Jeni-voice + JeniMethod curriculum is the legitimate substitute.

**Should JeniFit adopt? YES, with variant.**

**JeniFit variant:** "are you working with anyone on this right now?" — options: a coach / a nutritionist / a therapist / a doctor / no one yet. Multi-select. **The "therapist" option matters** — 70%+ of Gen-Z women prioritize mental health (per `feedback-weightloss-ux-principles`); surfacing it signals JeniFit's mental-health awareness. The "doctor" option opens the medical-context conversation (relevant for GLP-1 in case 164).

**Slot:** in Act 4, between case 164 (GLP-1) and case 142 (comparison). Lands as the final cohort signal before the JeniFit-vs-generic comparison frame.

## 7. The barriers question (calai20/33) — anti-Noom approach

Cal AI gives 5 single-select options (consistency / unhealthy eating / support / busy / meal inspiration). Noom gives 12-15 multi-select with more emotional content (emotional eating, stress, body image, etc.). Cal AI's brevity is on-brand for its single-feature positioning.

**Multi-select vs single-select tradeoff:**
- Single-select forces a primary barrier → enables targeted messaging downstream.
- Multi-select captures more signal but dilutes the "address THE thing" reframe.

**JeniFit's current case 153** is multi-select with 3 options ("apps make me feel worse / i don't know what's right / i quit when it gets hard"). This is **too workout-coded** for a diet-first pivot. The current Q probes workout-app pain — but post-pivot, the barrier set must include food-domain failure modes.

**JeniFit's recommended barrier inventory (single-select, 5-6 options):**
- "i lose consistency by week 2"
- "food noise won't quit"
- "i quit when it gets hard"
- "eating out wrecks me"
- "i don't trust my body cues yet"
- "i've been here before, didn't last"

Hybrid model: ask single-select PRIMARY barrier (drives downstream tone), then multi-select on "anything else that's true?" Two screens, ~1.5 hits of friction. Probably worth it; this drives the most material downstream messaging tone of any single question.

## 8. The "specific diet" question (calai21) — calibration depth

Cal AI asks Classic / Pescatarian / Vegetarian / Vegan. This is **shallow** for what it could do — no mention of keto, low-carb, intermittent fasting, GLP-1, food sensitivities, allergens. Cal AI is making a deliberate scope tradeoff: depth-of-calibration vs cohort-fit-with-young-mainstream.

**Per `project_food_rail_v2_locked` (D17, D22):** JeniFit moved dietary pattern + exclusions to Food Settings. **Should it come back to onboarding?**

**Argument for in-onboarding:** dietary pattern unlocks the food-first positioning — "the program adapts to how you actually eat" lands harder if the user has just stated her pattern. The first food log post-onboarding can match her stated pattern.

**Argument for in-settings:** dietary patterns shift; locking on Day 0 creates re-edit friction. The cohort hates being labeled. The post-Ozempic vocabulary is "fits, has room, permission" — NOT "I am pescatarian." Identity-pinned diet labels are 2010s-coded.

**Recommendation:** keep in Food Settings (the user is right). BUT add a single soft-frame onboarding question: "how do you eat, mostly?" with options that are PATTERN, not LABEL: "everything's fair game / mostly plants / no red meat / vegan / following a plan (GLP-1, low-carb, etc.)." Routes to the same data field. The pattern-not-label framing satisfies the food-first positioning without the identity lock-in.

**Slot:** Act 1 food wedge, between case 162 (food relationship) and case 166 (pre-eat permission).

## 9. The premium-feature tease (calai41 / calai39 — actually calai26 + calai27)

Cal AI's "Rollover extra calories?" and "Add calories burned back?" are presented as preference questions. They're actually **Pro features.** When the user answers Yes, she's effectively pre-purchased into a Pro feature she doesn't yet know is Pro. The pre-paywall expectation is built; the paywall converts higher when she sees those settings will be locked.

**Honest framing:** brilliant lever; this is one of the highest-converting paywall priming techniques in 2025-2026 calorie-app teardowns (Cal AI's 123-experiment paywall iteration confirms it).

**Manipulative framing:** the user doesn't know she's setting up a Pro tease; the question reads as preference. There's also a concrete harm — "rollover calories" can be ED-adjacent for restriction-prone users (saving 200 cal to "spend" tomorrow is a textbook food-rules pattern). The post-Ozempic / anti-shame cohort is allergic to this.

**JeniFit's Honesty Doctrine + anti-shame locks:** REJECT this pattern. Specifically:
- "Rollover" tracks toward food-rules mental model → violates anti-shame lock.
- Hidden Pro-feature gating → violates Honesty Doctrine.

**But — there IS a clean JeniFit adaptation:** ask only PREFERENCES that are clearly non-shame, non-gating:
- "want a check-in note from Jeni in the evening?" (preference) — drives the 8:30pm Plate Review notification (a free feature, but the asking creates the habit-loop pre-commitment per `pivot_research_habit_retention` §10).
- "want me to remember your luteal week?" — opens the cycle-aware messaging consent, IS a free feature, IS identity-positive.

Both questions activate the same conversion mechanism (pre-commit to feature-engagement) without the shame mechanics or hidden gating.

**Slot:** post-case 21 (`planRevealScreen`), pre-case 215 (review prompt).

## 10. The "what would you like to accomplish" question (calai14 / calai16 / calai22) — late-funnel identity beat

Cal AI's options: Eat healthier / Boost energy / Stay motivated / Feel better about body. This is a **soft identity question** that runs alongside the calibration battery. Position: late-mid funnel, after the goal/desired-weight beats but before the hard biometric battery.

**Why it works:** the cohort doesn't actually want calorie tracking; they want the OUTCOMES. By asking this, Cal AI lets the user state the outcome in her own (low-stakes, identity-positive) language, which becomes the throughline for paywall copy ("[outcome] is closer than it feels").

**JeniFit's case 140 (`identityFeeling`):** Powerful / Calm / Light / Strong / Radiant. **Compare:**

| | Cal AI (14) | JeniFit (140) |
|---|---|---|
| **Frame** | Outcome (what you do) | Identity (who you become) |
| **Slot** | Late-mid | Mid Act 4 |
| **Voice** | Bro-fitness adjacent ("Stay motivated and consistent") | Soft-girl wellness ("Calm") |
| **Downstream use** | Paywall sub-copy | Becoming tab + paywall + JenisNote |

JeniFit's 140 is **better** for the cohort — identity-forward vs outcome-forward, post-Ozempic-vocabulary clean.

**Should JeniFit add Cal AI's variant?** No — 140 already does the job better. BUT: JeniFit could ADD an outcome question 2-3 screens after 140, specifically for paywall headline variation: "if this program works, what shows up first?" options like "i sleep through the night / my clothes sit different / i stop counting / i look forward to mornings / i'm in my photos again." This is *outcome*-identity (Cal AI's Q) refracted through JeniFit's voice. Paywall headline variant pulls from this field.

**Slot:** new case post-141 (reward), pre-142 (comparison). Or absorbed into 141 as a 2-stage question.

## 11. Question order analysis

Cal AI's order:

```
1. welcome
2-3. gender, workouts/wk          ← soft calibration
4. long-term-results curve         ← LOSS prime
5. attribution
6. tried-apps?                     ← INVESTMENT
7-8. (in actual flow: goal, pace placeholder)
9. coach/nutritionist?             ← COMMITMENT
10. goal
11. desired weight
12. (reframe "not hard at all")    ← EFFORT-DOWN
13-14. accomplish + (...)
15-19. pace selector battery       ← AGENCY + COMMITMENT
20. barriers                       ← ACKNOWLEDGMENT
21. diet pattern                   ← CALIBRATION
22-23. (accomplish/projection)
24. thank you for trusting us      ← RECIPROCITY
25. Apple Health connect
26-27. burned-cal + rollover       ← PREMIUM TEASE
28. 2X claim                       ← COMPARISON
29-30. social proof + review prompt ← CREDIBILITY
31-32. notif prime                 ← HABIT-LOOP COMMIT
33. barriers (repeat)
34-37. ATT + loading theater       ← PERSONALIZATION THEATER
38-39. plan reveal                 ← VALUE DELIVERY
40. sign in                        ← AUTH DEFERRAL
41. referral                       ← GROWTH LOOP
42-43. soft → hard paywall         ← MONETIZATION
```

**Segments:**
- Data-gathering: 2-3, 9-11, 20-21
- Commitment-building: 6, 9, 15-19, 26-27
- Reframe: 4, 7, 23, 28
- Reciprocity: 24
- Habit-engineering: 25, 31-32
- Theater: 34-37
- Value delivery: 38-39
- Monetization: 42-43

**Key insight:** Cal AI puts COMMITMENT questions BEFORE the heavy data battery (coach Q at 9, pace at 15-19), and CREDIBILITY moments AFTER reciprocity (social proof at 29-30 comes after "thank you for trusting us" at 24). JeniFit's `v2FlowOrder` mostly mirrors this with the new D67 commitment confidence at 165 (well-placed pre-145 video demo). The remaining gap is the PACE SELECTOR commitment — JeniFit's flow doesn't have an equivalent.

## 12. JeniFit's question gap analysis — what Cal AI asks that JeniFit doesn't

| # | Cal AI Q | Should JeniFit add? | Slot | New AppStorage field | Downstream consumer |
|---|---|---|---|---|---|
| 1 | "Have you tried other calorie/WL apps?" | YES | post-100, pre-162 | `onboardingPriorApps` (none/some/many) | Paywall variant, Jeni's intro note |
| 2 | "Do you work with a coach/nutritionist/etc.?" | YES, multi-select with therapist+doctor | post-164, pre-142 | `onboardingCurrentSupport` (multi) | Paywall positioning, doctor-coordination beat in JeniMethod |
| 3 | Pace selector (Slow / Recommended / Fast) | YES — highest leverage | between 161 and 170 | `onboardingPaceChoice` (gentle/steady/focused) | re-prediction, daily target, paywall headline |
| 4 | "What would you like to accomplish?" (outcome) | YES — adapted | post-141, pre-142 | `onboardingFirstWin` | Paywall headline variant, Jeni's first note |
| 5 | "Do you follow a specific diet?" (pattern) | YES, soft-pattern variant | post-162, pre-166 | `onboardingEatingPattern` | Food rail content matching |
| 6 | Burned-cal / rollover (DROP) | NO — anti-shame violation | — | — | — |
| 7 | "Connect to Apple Health" | partial — JeniFit already has steps via HK in v1.0.6 | post-21 | n/a | passive activity, sleep, weight imports |
| 8 | Notification prime | already exists; refine timing | n/a | n/a | morning anchor, evening Plate Review |
| 9 | Referral code | YES — growth loop | post-21 | `onboardingReferralCode` | Attribution + creator credit |
| 10 | "Thank you for trusting us" reciprocity beat | YES | between Act 3 + Act 4 | n/a (presentation only) | Sets tone for vulnerability Qs |
| 11 | Real-time projection curve update as Qs answered (Noom pattern) | YES — implicit in pace selector | 161/170 | n/a | Self-efficacy compound |
| 12 | "Estimating your metabolic age" loading copy | partial — JeniFit has carousel loading (180); add sub-labels | 180 | n/a | Theater richness |
| 13 | "Lose 2X with X" comparison frame | NO — unsubstantiable; JeniFit has 142 (own comparison) | — | — | — |
| 14 | "Health Score 7/10" | NO — gamified score is shame-prone | — | — | — |
| 15 | In-app rating prompt mid-onboarding | NO — premature; JeniFit's 215 post-reveal placement is better | — | — | — |

**Top 5 to add: 3 (pace), 1 (tried-apps), 2 (current support), 4 (first win), 10 (reciprocity beat).**

## 13. JeniFit's redundant/cuttable questions

JeniFit's `v2FlowOrder` has 58 entries. Cal AI has ~30 functional question screens. Bloat targets — apply the 4-type taxonomy from §2; if a screen doesn't calibrate, invest, commit, or acknowledge, it's cuttable.

| Case | Function | Cut/Keep | Reasoning |
|---|---|---|---|
| 200/201/202/203/204/205 | Section dividers | KEEP 200, CUT 4 of 5 | Cal AI uses 1 transition (calai24); JeniFit uses 6. Excess scaffolding. |
| 230/231/232/233/234 | Educational anti-shame, body primer, 5-min, cycle, plateau | KEEP 233 + 234; CUT 230, 231, 232 | The pre-content educational screens are slow; cycle (233) + plateau (234) are load-bearing. Anti-shame (230), body primer (231), 5-min (232) are voice-soaking — bundle into Jeni's micro-line per-Q via `confirmation` strings (cheaper). |
| 235 | Month signals multi | CUT or MERGE into 163 (hormonal stage) | Overlap with hormonal-stage Q. |
| 236 + 237 | "What's worked before" + parallel multi | CUT 237 — overlaps 159 (`priorWin`) | |
| 238 + 239 | Sub-Qs (jfQuestion + jfQuestion) | INSPECT — likely cuttable. The flow has 235/237/238/239 in close succession; pick the 1-2 strongest. |
| 110 + 111 | Body focus + real reason | KEEP 110, CUT 111 | The "real reason" Q is identity-forward (good) but redundant with case 140 (`identityFeeling`). Consolidate. |
| 130/131/132/133 | Biometric pickers (height, weight, body type, etc.) | KEEP all — Cal AI does the same; calibration set |
| 134 + 135 | Two body-type screens | CUT 1 (likely 135) | Two consecutive body-shape selectors is friction; one carries the identity-as-data move per Lasta pattern. |
| 142 | Comparison frame | KEEP — JeniFit's "vs generic" beat |
| 145 | Video demo | KEEP — sole product proof in onboarding |
| 150/151/152 | Yes/No relatability triple | already replaced by consolidated 153 — drop the triple from any A/B variant |
| 250 | JeniMethod preview | KEEP |
| 260 | Tier ladder | KEEP — Cal AI doesn't do this; differentiator |
| 270 | Habit window quiz | KEEP — directly feeds notification scheduling |
| 240 | Brand promises | CUT — verbal "brand promises" reads as 2018 startup; the comparison (142) + plan reveal (21) carry the brand. |

**Net cuttable:** 12 screens (5 dividers + 230 + 231 + 232 + 237 + 240 + 111 + 135 + 235 merge). Brings flow from 58 to ~46. Add the 5 Cal-AI-adopted questions → back to ~51. Net: **7 fewer screens, 5 better questions, materially higher leverage per screen.**

## 14. Concrete recommendations — top 15, rank-ordered by expected impact

| # | Change | JeniFit case | Cal AI ref | Brand voice preserved | Effort |
|---|---|---|---|---|---|
| 1 | **Add pace selector — gentle/steady/focused** with weeks-to-goal + 1-line reframe per position; no calorie number | NEW between 161 + 170 | calai17-19 | YES (sticker palette, soft-girl labels, post-Ozempic vocab) | M |
| 2 | **Add "have you tried other WL/calorie apps?"** 3-option (yes / a little / never); routes feed Jeni's intro note variant | NEW post-100 pre-162 | calai6 | YES | S |
| 3 | **Cut bloat: section dividers 201/202/203/204/205** — keep 200 only; consolidate Jeni-voice transition lines into adjacent Q `confirmation` strings | flowOrder cleanup | calai24 (1 transition) | YES | S |
| 4 | **Add "current support" multi-select** (coach/nutritionist/therapist/doctor/no one yet); Act 4 right before comparison | NEW post-164 pre-142 | calai9/13 | YES, with therapist + doctor expansion | S |
| 5 | **Cut 111 (real reason)** — overlap with 140 identityFeeling; consolidate into 140 confirmation or 141 reward | 111 cut | n/a | YES | S |
| 6 | **Drop "X% of users" / "80% maintain" / "2X" claims** anywhere they appear; replace with citation-anchored `WeAskBecauseRow` (Pontzer 2026 review, BMJ 2024, etc.) | 142/234 audit | calai4/7/28 (REJECT) | YES — data-provenance lock | S |
| 7 | **Add diet PATTERN (not label) Q** in Act 1 food wedge — "how do you eat, mostly?" | NEW post-162 pre-166 | calai21 | YES — pattern-not-label framing | S |
| 8 | **Convert case 153 to single-select PRIMARY barrier** + multi-select "anything else" follow-up; expand option set to food-domain failure modes | 153 redesign | calai20/33 | YES | M |
| 9 | **Add "first win"** identity-outcome Q post-141 — "if this works, what shows up first?" — drives paywall headline variant | NEW post-141 | calai14 (refracted) | YES — JeniFit voice on options | S |
| 10 | **Add reciprocity beat** between Act 3 + Act 4 — "thank you for trusting us — now we calibrate" — sets tone for vulnerability Qs (154/155/163/164) | NEW post-Act-3 | calai24 | YES | S |
| 11 | **Add referral code** screen — `onboardingReferralCode` + creator-credit attribution | NEW post-21 | calai41 | YES | S |
| 12 | **Cut educational screens 230, 231, 232** — consolidate beats into Jeni `confirmation` lines on adjacent Qs | flowOrder cleanup | calai (none — they don't do this) | YES | M |
| 13 | **Cut 235 (month signals) OR merge into 163** (hormonal stage) — overlapping data | 235 cut | n/a | YES | S |
| 14 | **Cut 240 (brand promises)** — reads as 2018 startup; brand carries via 142 + 21 + Jeni voice | 240 cut | n/a | YES | S |
| 15 | **Reject the rollover / burned-cal preference teases** (calai26/27) — anti-shame violation; replace with the cycle-aware + evening-Jeni-note pre-commits that do the same conversion job cleanly | n/a (rejection) | calai26/27 (REJECT) | YES | S |

**Cumulative effect:** 6 fewer cases (~10% flow shorter), 5 new high-leverage Qs, 0 brand-voice violations, 0 Honesty-Doctrine violations. Specifically: pace selector + tried-apps + current-support + first-win + reciprocity beat are the 5 Cal-AI patterns that compound JeniFit's existing depth (sleep, stress, food relationship, GLP-1, hormonal) into a credibility moat Cal AI structurally cannot match — Cal AI cannot ask hormonal stage without exposing their thin program; JeniFit can pair it with pace, support, and prior-app context.

---

## Standalone TL;DR

Cal AI runs a 30-screen flow that is question-engineered, not just designed. The four moves that compound — **calibration framing on every biometric, investment-only "have you tried" / coach Qs, pace selector with real-time calorie + ETA + warning copy, and reciprocity beat before vulnerability** — are the patterns JeniFit should adopt. The four moves to reject — **unsubstantiable % claims, rollover / burned-cal premium teases, mid-onboarding rating prompt, fake-modal notification prime** — violate JeniFit's Honesty Doctrine and anti-shame locks. JeniFit's question depth (sleep, stress, food relationship, GLP-1, hormonal) is already a moat Cal AI can't match; the gap is the COMMITMENT layer, which the pace selector closes. Net: cut 7-12 cases, add 5, ship a richer flow at materially fewer screens.
