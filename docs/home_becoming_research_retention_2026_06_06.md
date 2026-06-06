# Home + Becoming retention research — v1.0.7

*Senior retention review · iOS Gen-Z women WL category · 2026-06-06*

---

## Executive recommendation (1 paragraph)

JeniFit's instincts are *mostly* right but mis-prioritized. The single biggest 2026 retention lever for Gen-Z women WL is **time-to-value collapse on the daily input**, not magical UI — photo-scan beats manual logging because users averaging <30s per meal log retain at 78% at 6 months vs 23% for users averaging >2 min ([NutriScan, 2026](https://nutriscan.app/blog/posts/myfitnesspal-vs-lose-it-2026-which-app-is-faster-d4cb63c7c2)). That is the lever. But the founder's hypothesis #3 ("calories matter most for daily action") is the dangerous one — the 2026 Gen-Z cohort is *actively burnt out* on calorie primacy (Cal AI's $50M ARR is a peak-of-hype acquisition signal, not durable retention — MyFitnessPal acquired them precisely because food-scan-as-feature is now commodity ([TechCrunch, 2026](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/))). The retention winners in this cohort will treat **food scan as table-stakes input** and compete on the **weekly meaning-making layer** (Becoming) plus the **identity/affirmation daily loop** (Home coach note). For v1.0.7, the three retention bets that compound are: (1) shrink food-scan tap-to-result to <5s end-to-end and make it the Home hero action — this is the daily loop, (2) ship a **Sunday-night "your week" ritual** on Becoming that's shareable and screenshot-worthy (the Spotify-Wrapped pattern, miniaturized weekly), (3) cut total push cadence in week-1 from 5 surfaces to 3 anchors and replace any "you haven't logged" framing with **identity-from-her-own-data** ("you breathed 4 times this week ♥"). Streaks: keep, but make them **soft-recoverable** and **never the primary metric on Home**.

---

## 1) 2026 WL retention benchmarks — where the bar is

### Cross-industry baseline (2026)
- **D1**: 25–26%
- **D7**: 11–13%
- **D30**: 5–7%
- *Source*: [Phiture, 2026](https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/); [Unstar, 2026](https://unstar.app/blog/app-retention-benchmarks-2026)

### Health & Fitness category (2026)
- **D1**: ~20–27%
- **D7**: ~7–8.5%
- **D30**: ~3.5–4%
- Health & Fitness is **the worst-retaining major subscription category at D7/D30** — Adjust describes it as "heartbreak territory" because motivation decays predictably ([Adjust, 2026](https://www.adjust.com/blog/what-makes-a-good-retention-rate/); [Business of Apps, 2026](https://www.businessofapps.com/data/health-fitness-app-benchmarks/); [RetentionCheck, 2026](https://retentioncheck.com/churn-benchmarks/fitness-apps))
- Monthly churn averages **9.2%** (annualized 68.4%) ([RetentionCheck, 2026](https://retentioncheck.com/churn-benchmarks/fitness-apps))

### Subscription-side (RevenueCat State of Subscription Apps 2026)
- Health & Fitness median **trial-to-paid: 6.9%** — solid vs. cross-category
- Annual plan mix: 68% (heavily annual-skewed) — JeniFit's annual focus is correct
- Median RLTV: **$35.64**
- Annual renewal rate: **25%** (mid-table) — a *quarter* of annual subscribers renew
- *Source*: [RevenueCat, 2026](https://www.revenuecat.com/state-of-subscription-apps/); [RevenueCat blog, 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)

### Trial mechanics (Adapty 2026)
- Install-to-trial global median **11.2%** (NA: 14.5%)
- **86.1% of trial conversions land on Day 0** — JeniFit's hard paywall + Day 0 anchor push is structurally correct
- Secondary peak: Days 4–7 — Day 2 engagement push is well-timed for the second peak
- *Source*: [Adapty Health & Fitness Subscription Benchmarks 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)

### Where competitors sit
- **Cal AI**: $50M+ ARR in 18 months; 15M downloads; acquired by MFP March 2026 — viral acquisition curve, but acquisition itself suggests retention plateau was reachable (founders + MFP saw distribution-on-distribution as the play, not standalone) ([TechCrunch, 2026](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/))
- **MFP**: 40–49% 90-day dropout (lit review); chronic week-6 churn from accumulated friction (slow searches, paywalls, ads) ([HumanFuelGuide, 2026](https://humanfuelguide.com/en/articles/tools/best-apps-for-weight-loss-2026))
- **Noom**: 86.7% 68-week retention *in clinical-trial conditions* (June 2026 RCT) — but that's RCT structure, not consumer-app baseline; consumer GLP-1 companion shows 43.6% D30 engagement, 77.8% returning by Week 4 ([Noom press, 2026](https://www.globenewswire.com/news-release/2026/06/04/3306707/0/en/Noom-Members-Kept-Losing-Weight-a-Full-Year-After-the-Program-Ended-Largest-Ever-Noom-Randomized-Clinical-Trial-Shows.html); [Noom GLP-1, 2026](https://www.noom.com/blog/weight-management/2025-was-the-breakout-year-for-nooms-glp1-companion/))
- **MacroFactor**: adherence-neutral weekly check-in is the wedge — "the algorithms don't function any worse if you deviate from your macro targets" — this is the **post-shame retention pattern** to copy in spirit ([MacroFactor Review 2026](https://best-diet-apps.com/reviews/macrofactor/))

### JeniFit's launch baseline (from MEMORY: project_launch_v106b11_findings)
- Onboarding completion **88%**: strong vs. ~50–60% category median
- Workout completion **23%**: significant — workouts may not be the daily hero for this cohort
- Lesson + breathwork **>75% completion**: the engagement-day signal
- Trial conversion **US 7–14% vs PH/SG/UK 33–100%**: US cohort is the post-Ozempic/Cal AI-burnt market

**Founder hypothesis check**:
- *"Magical photo is the retention lever"* — **PARTIALLY TRUE**. Photo speed is the lever, not photo magic. Validation: the <30s/meal → 78% 6-month retention vs 23% data is the most retention-load-bearing benchmark in this report. But "magical" is the wrong frame — the operative variable is **input friction collapse**, not delight. Build for speed and forgivability, not for "wow."
- *"Weight feature underused because of friction"* — **TRUE BUT MIS-FRAMED**. Yes, input friction matters. But for Gen-Z women in 2026, *weight-as-primary-metric is itself the friction* (psychologically). The fix is not "make weight log faster" — it's "demote weight to a passive HealthKit-pulled trend and make food-scan + steps + breath the active inputs." More on this in §8.
- *"Calories matter most for daily action"* — **FALSE for this cohort**. Calories matter as a *table-stakes input*, not as the daily emotional payoff. The 2026 Gen-Z WL cohort is in active rebellion against calorie primacy ("done with toxic calorie counting that feels more like punishment" — [Welling, 2026](https://www.welling.ai/articles/welling-vs-myfitnesspal-2026)). Calories drive Day 1 hook; **identity + trend + ritual drive D7–D90**.

---

## 2) Is the "magical photo" experience really the retention lever?

**Short answer**: speed is the lever. Magic is the marketing.

### What the data says
- **<30s/meal logging → 78% 6-month retention**; **>2 min/meal → 23% retention** ([NutriScan/Welling, 2026](https://www.welling.ai/articles/welling-vs-myfitnesspal-2026)). This is the single most load-bearing retention statistic in the category.
- **Cal AI's wedge was the "three-second photo" promise**, not accuracy. "Good enough accuracy of an automated system is preferable to the tediousness of a manual one" ([NutriScan, 2026](https://nutriscan.app/blog/posts/myfitnesspal-vs-lose-it-2026-which-app-is-faster-d4cb63c7c2)).
- AI logging saves ~90% of time vs manual; manual entry is 12% more accurate — **users prefer speed over accuracy at this delta**.
- MFP acquired Cal AI specifically because **photo-AI calorie recognition is becoming Premium-tier table stakes** ([Fitt Insider, 2026](https://insider.fitt.co/myfitnesspal-acquires-rival-food-tracker-cal-ai/)).

### What this means for JeniFit
- **Build the daily loop around the camera**, not around the manual weight log. Camera → result < 5s end-to-end is the bar.
- **Don't make the user predict intent before output** (you already locked this in [project_food_rail_v3_locked]). One unified result card. Correct.
- **The "magical" framing is dangerous because it sets a delight expectation the model will miss.** Cal AI's accuracy is widely mocked in TikTok comments. JeniFit's brand voice is "honest + warm" — frame the camera as *"jeni's notebook"* not *"AI magic"* (consistent with your AI-language ban).
- **Corrections-as-moat** (from MEMORY [feedback_food_vision_models]) is the right long-term play — and it's also a retention loop: every correction makes the next meal faster, which compounds the 78% retention curve.

### Pushback on hypothesis #1
The retention lever isn't *the magic of the photo*. It's the **abolition of the typing tax**. Gen-Z's attention budget for any non-entertainment app is ~7 seconds per surface (digital-fatigue research: [NCH Stats, 2026](https://nchstats.com/digital-fatigue-crisis-gen-z/)). The camera wins because it fits in 7s. A "magical" result card that takes 12s to animate, even if delightful, fails the cohort's attention budget. **Bias toward instant + boring over delayed + delightful.**

---

## 3) Notification cadence at v1.0.7 — is JeniFit overdoing it?

### Current JeniFit notification surface (Week 1)
1. Day 0 anchor
2. Day 2 engagement push
3. Day 3 first-log nudge
4. Daily reminder (workout/practice)
5. Evening 8:30pm plate review push

That's **5 surfaces in Week 1, with at least 2 firing daily by Day 4**.

### What 2026 research says
- **1 weekly push → 10% disable**; **3–6 pushes → 40% disable**; >20 pushes → only 5% disable (the desensitized cohort) ([WiserNotify, 2026](https://wisernotify.com/blog/push-notification-stats/))
- iOS push opt-in is **43.9%** (vs 91.1% Android) — JeniFit can't afford to push more iOS users to opt out
- Tailored health messages increase 24-hour engagement by only **3.9%** (microrandomized trial) — *the lift per push is small*
- Notification fatigue "builds quietly" and shows up only after engagement has already dropped ([Appbot, 2026](https://appbot.co/blog/app-push-notifications-2026-best-practices/))
- Health & fitness open rate is **2.80%** — below average — meaning a push gets through to <3 of every 100 users on a given day

### Recommendation: cut to 3 surfaces in Week 1, recover the dropped surfaces as in-app moments

**Keep**:
1. **Day 0 anchor** — structurally correct; aligns with 86.1% Day-0 trial conversion peak
2. **Evening 8:30pm plate review** — anchored to natural daily ritual; tied to the food rail hero feature
3. **Day 2 engagement push** — second-peak trial timing

**Cut or in-app only**:
- Day 3 first-log nudge — replace with in-app cocoa-coach-note on Day 3 Home ("noticed you haven't tried the camera yet — wanna give it a shot? ♥")
- Daily reminder — too generic for this cadence-aware cohort; replace with **silent live-activity-style streak rendering on Home** (visible on app open, not a push)

**Cadence ceiling for v1.0.7**: 3 pushes/week after Week 1; never 2 in a 24-hour window; never a push framed as "you haven't logged" (which the cohort reads as guilt-tripping).

**Voice**: keep [feedback_notification_voice] — identity + her own data. Avoid: scale references, "back to it", "don't break", "you missed."

---

## 4) Streaks for Gen-Z WL — yes or no, and what variant

### 2026 verdict: **soft streaks, secondary placement, never the hero**

### What the data says
- Duolingo's 2024–25 streak mechanics are now widely reported as causing "streak preservation" behavior — users gaming for the shortest task possible, *learning less* in pursuit of the streak ([Decision Lab, 2026](https://thedecisionlab.com/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification); [Medium/Sam Liberty, 2026](https://medium.com/design-bootcamp/why-gamification-fails-new-findings-for-2026-fff0d186722f))
- Developers are explicitly *removing* streaks from mental wellness apps ("SecondStep rejected streaks" — [Dev Journal, 2026](https://earezki.com/ai-news/2026-05-14-i-almost-added-streaks-to-my-app-then-i-remembered-what-duolingo-did-to-me/))
- "In high-friction domains like mental health, enforcing daily commitments can create metric-induced guilt, transforming a supportive tool into a source of stress" ([Decision Lab, 2026](https://thedecisionlab.com/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification))
- Duolingo on **deceptive.design** for "overly pushy reminders" — exactly the pattern JeniFit's brand voice forbids

### But streaks aren't dead
- Mobile games still use streaks effectively as engagement engines
- Gen-Z still responds to **progress visualization** — the form matters more than presence
- Duolingo's response was to **bring back lost streaks** — a recovery mechanic, not abandonment ([Contentgrip, 2026](https://www.contentgrip.com/duolingo-streak-revival-campaign/))

### Recommendation for JeniFit
**Yes-streaks, with three constraints:**

1. **Soft-recoverable**: any missed day can be recovered by logging within 48h. No "broken streak" framing. Frame: "your week is still on ♥" not "8-day streak."
2. **Week-shaped, not day-shaped**: show as "4 of 7 this week" not "Day 8." Calendar-week rhythm matches the Gen-Z women cohort's relationship with structure (less daily-perfection-pressure; matches their stated values of "regulation, recovery, sustainable" per [Runway, 2026](https://www.runwaylive.com/gen-z-women-redefine-wellness-in-2026.html)).
3. **Streak lives in Becoming, not Home**. Home's daily hero is the food camera + cocoa note. The streak is a *progress dashboard element*, not a daily threat.

**Anti-pattern**: any push or in-app banner that uses "don't break your streak" copy. This is the Duolingo dark pattern the cohort is migrating away from. Per [feedback_post_ozempic_vocabulary]: banned alongside "crush, shred, burn, earn, deficit."

---

## 5) Variable rewards / surprise loops for Gen-Z women WL retention

### What's working in 2026 for this cohort

**Behavior-triggered rewards** are "the newest twist in mobile engagement" — platforms watch for drop-off signals and "quietly hand out rewards" ([Enable3, 2026](https://enable3.io/blog/loyalty-programs-trends)). The uncertainty itself is the engagement model.

### Specific 2026 patterns that retain Gen-Z women

1. **"Jeni noticed you" surprise notes**. Coach-style observational copy generated from her own data, fired at irregular intervals — *not* on a daily schedule. Example: "noticed you've been breathing before bed all week ♥ that's the thing." This is the *coach moment* pattern, anti-formulaic.
2. **Sticker-collect with semantic meaning**. Not a points-grind: stickers unlock for *qualitative milestones* (first week of three logs, first time choosing pre-eat mode, first weekend with no skip). Sticker-collect aligns with the [feedback_design_theme] coquette y2k aesthetic *and* matches Gen-Z's affinity for "fairness, inclusivity, memorable experiences" ([Advantage Club, 2026](https://www.advantageclub.ai/blog/gen-z-loyalty-programs)).
3. **Weekly variable surface (the "Sunday card")**. Not the same recap every week — rotates: "your week in food", "your week in movement", "your week in moments", "what changed". Variability across weeks beats variability within a day. See §7.
4. **Daily lesson as variable reward**. JeniMethod's >75% completion (from launch findings) is the most retention-load-bearing engagement signal you already have. **The daily lesson IS the variable reward.** Treat it that way: surface it as the day's "open me" envelope on Home, not buried.

### Don't do
- **Spin-the-wheel / random discount mechanics** — read as predatory in this cohort
- **Push-based "surprise"** — defeats the surprise (push is announced; surprise should be discovered on app open)
- **Leaderboards / social comparison** — explicitly toxic to a cohort that explicitly migrated from MFP/Noom partly to escape social-comparison shame

---

## 6) Home daily-loop design — what should Home do every morning?

### Principle
The home screen should be a daily wellness command center, not a policy dashboard ([Pragmatic Coders, 2026](https://www.pragmaticcoders.com/blog/gen-z-healthcare-app)). For Gen-Z women WL specifically: **front-load value, delay asks, show progress immediately** ([Snoopr, 2026](https://www.snoopr.co/blog/mobile-app-retention-benchmarks-2026-what-good-looks-like-for-fitness-ecommerce-gaming-and-more)).

### Current JeniFit Home
1. cocoa coach note
2. food card (kcal today + weekly avg)
3. JeniMethod card (today's lesson)
4. steps + breath compact
5. workout card

### Retention-graded review

| Slot | Current | Retention grade | Reason |
|---|---|---|---|
| 1 | cocoa coach note | A | Identity-from-data, brand-aligned, low-friction, daily varying. Keep as-is. |
| 2 | food card (kcal) | C+ | Calorie number at top of Home is the Cal-AI/MFP pattern the 2026 cohort is leaving. Replace with **camera CTA + today's plate timeline + weekly trend pill** (not daily kcal). |
| 3 | JeniMethod card | A | 75%+ completion. *This may be your second-highest retention asset after the camera.* Consider promoting to slot 2. |
| 4 | steps + breath | B+ | Healthkit-passive content is high-retention because zero friction. Could be combined with food into a **3-ring TodayHealthStrip** when food ships passive-enough (per [project_home_architecture]). |
| 5 | workout card | C | 23% completion suggests this cohort is not workout-led. Demote to "today's movement" slot or behind a small "more" link. |

### Recommended Home order for v1.0.7

1. **cocoa coach note** (identity hook — daily variation)
2. **JeniMethod card** (variable reward — opens the daily lesson — 75% completion engagement signal)
3. **camera-first food hero** (NOT a kcal card — a tappable "what did you eat today? ♥" surface with the plate timeline below)
4. **3-ring strip (food + steps + breath)** — weekly trend, not daily numbers
5. workout — collapsed under "more today" or moved to a session tab entry point

### Why this order maps to 2026 retention research
- **Slot 1 = emotional resonance before utility** (Pragmatic Coders 2026, Runway 2026 on Gen-Z women wellness)
- **Slot 2 = variable reward, ritual envelope** (the day's lesson is the surprise; you already have proof of this from 75%+ completion)
- **Slot 3 = the daily input loop** (the camera = the high-retention behavior per the <30s rule)
- **Slot 4 = passive HealthKit data** (the part the user doesn't have to *do*; visible momentum without friction)
- Bottom = workout, the lowest-completion content

### Daily varying elements on Home (the "tomorrow pull")
The single best 2026 pattern for "what brings her back tomorrow?" is **delta-visible-on-open**. The screen looks subtly different than yesterday because:
- the cocoa coach note varies (already shipped)
- the lesson card shows tomorrow's title teaser
- the 3-ring fills relative to her own moving baseline
- *new*: a soft "yesterday's plate" recap pill if she logged anything — this is the "i remember you" moment

---

## 7) Becoming weekly-loop design — what role does it play in retention?

### Principle
Becoming should be **a Sunday-night ritual + a screenshot-shareable surface + a coach summary** — the Spotify-Wrapped pattern, miniaturized weekly.

### 2026 evidence
- Spotify Wrapped pulled **200M users in 24h** in 2025 (19% more than 2024) and **500M shares** — the year-recap pattern is the single most viral retention mechanic in subscription apps ([Wikipedia/Spotify Wrapped](https://en.wikipedia.org/wiki/Spotify_Wrapped))
- Spotify expanded into **weekly listening stats** Nov 2025 — confirming the recap pattern works at *higher cadence than annual* ([TechCrunch, 2026](https://techcrunch.com/2026/05/12/spotify-launches-a-wrapped-style-recap-of-your-entire-listening-history/))
- Strava's Year-in-Sport moved **behind subscription paywall** in 2025–26 — confirms the recap is a willingness-to-pay surface, not just a retention surface ([Strava support, 2026](https://support.strava.com/hc/en-us/articles/22067973274509-Your-Year-in-Sport))
- Apple Watch weekly summaries are explicitly named in 2026 retention research as the mechanic that "anchors the app to the device the user already wears" — i.e., they're the secondary-week retention loop ([Snoopr, 2026](https://www.snoopr.co/blog/mobile-app-retention-benchmarks-2026-what-good-looks-like-for-fitness-ecommerce-gaming-and-more))
- Gen-Z women wellness specifically: "social wellness gatherings, group rituals, and shared experiences underscore a community-focused ethos" — they want surfaces that *invite sharing* ([Runway, 2026](https://www.runwaylive.com/gen-z-women-redefine-wellness-in-2026.html))

### Current Becoming review

| Chapter | Current | Retention role | Verdict |
|---|---|---|---|
| 1. your week ♥ | weight trend + coach insight | Strong — coach insight is the meaning-making | Keep, but **promote to a Sunday-explicit ritual surface** when day == Sunday |
| 2. what you ate | 7-day food bars | Required v1.0.7 surface | Keep; add **shareable card** affordance |
| 3. how you moved | steps + breath + sessions | Good identity reinforcement | Keep |
| 4. what's changing | barriers + plank mastery | Identity-from-stated-Q | Keep, this is the differentiator vs Cal AI |
| 5. what's worked | NSV wins | Anti-shame, retention-hardening | Keep; **add a "share with jeni" or screenshot affordance** |

### Recommendation: ship the Sunday Card

For v1.0.7, layer a **Sunday surfacing** on top of the existing 5 chapters:
- On Sunday (or any day after >= 5 logged days that week), surface a **"your week ♥" card at the top of Becoming**.
- It's a single screen, ~ 6 stat tiles, one coach line, one shareable composition (square format, JeniFit chrome, italic-Fraunces punch word).
- **Designed to be screenshotted** to TikTok/IG — this is the cohort's organic acquisition channel and you already know it ([feedback_design_theme], [project_target_audience]).
- The composition should vary week to week (different stat tiles surface based on what's interesting this week — variable reward).

### Becoming as a "today's report" vs. "look at how far you've come"
**Both, but weighted toward the latter for retention.** The "today's report" job is already done by Home (slot 4, the rings). Becoming's retention job is **"see yourself become someone over weeks"** — that's the deeper identity hook the cohort responds to ([Runway, 2026](https://www.runwaylive.com/gen-z-women-redefine-wellness-in-2026.html)) and what gives the app weeks-long meaning even if she misses days. This is also the moat vs Cal AI: Cal AI is a *meter*, JeniFit is a *story she's becoming*.

---

## 8) Anti-retention patterns to AVOID

### Beyond your locked bans (red bars, scale-shame, AI language, deficit copy, deceptive billing)

**1. The "you failed" semantic in any form**
Including soft forms: "you missed a day", "back to it", "don't break your streak", "complete today's goal", "you're behind." The cohort reads all of these as guilt. Replace with: "this week is still on ♥", "ready when you are", "your plate when you want to."

**2. Calorie number as Home hero**
The single biggest UX inheritance from MFP/Cal AI that the 2026 cohort is leaving. Even if the food rail is calorie-counting, the **home daily surface is not the kcal number** — it's the camera CTA + plate timeline + weekly trend.

**3. Manual weight input as a Home action**
Per [feedback_data_provenance] you already pull HealthKit. Don't make manual weight log a Home button — it makes the user confront a number. Demote to: HealthKit-passive trend display in Becoming, with manual entry as an *advanced setting* discoverable but not surfaced.

**Counter to hypothesis #2**: the founder's instinct that "input friction is hurting weight feature retention" is correct in mechanism but wrong in remedy. The remedy is *less weight input surface*, not faster weight input. The retention winner is **passive trend + occasional check-in**, not faster manual entry. Helander 2014 (already cited in your weight features) supports this — **daily weigh-in adherence beats accuracy of any single weigh-in**, and adherence comes from *not making it a chore*.

**4. Daily push that implies obligation**
Health & fitness opens are 2.80% — pushes mostly don't even get seen, but they *do* get felt by the few who see them. A "you haven't logged" push to a Gen-Z woman who skipped a day is **a churn event, not a re-engagement event**. The 3-push/week ceiling protects this.

**5. Onboarding-leftover language that survives into v1.0.7 product copy**
The 2026 cohort had a 30-question onboarding flow at peak. They are tired. Audit Home + Becoming for any onboarding-style question-as-microcopy patterns ("how was your sleep?" surveys, "rate your mood" sliders). Replace with passive observation ("noticed you slept later this week").

**6. Workout-led identity framing**
Given 23% completion, leading the home daily loop with workout content is misaligned with cohort intent. Workouts can be on Home but not as the hero slot. *This is one of the few places the founder's existing architecture pulls against retention*; the v1.0.7 redesign is the chance to demote workouts and promote camera + lessons.

**7. "Premium magic" rugs**
Cal AI's accuracy memes on TikTok are a warning. If JeniFit's photo-scan accuracy is below ~80% on common Gen-Z foods, the *brand-trust* loss exceeds the *speed gain* per the cohort's already-burnt attention. Decision: bias toward "Jeni's first guess + easy correction" framing over "AI knows." The correction flow IS the retention surface — every correction makes the next meal log faster (Cal AI's wedge) and your data improves (Cal AI's hidden moat per [feedback_food_vision_models]).

**8. Vanity onboarding metrics that don't recur**
Your 88% onboarding completion is great, but completed onboarding without a Day-1 camera action is a forecast for D7 churn. Tie the post-paywall first session to **camera-first** (her first food photo within first 24h), not workout-first.

---

## Top 3 retention bets for v1.0.7 Home + Becoming

1. **Camera as the daily Home hero, kcal number demoted.** The <30s/meal → 78% 6-month retention finding is the most load-bearing benchmark in this report. Demote calorie number from Home; promote camera CTA + plate timeline + weekly trend. Cuts dependency on the kcal-as-daily-payoff pattern this cohort is migrating away from. Reorder Home: cocoa note → JeniMethod card → camera → 3-ring strip → workout (collapsed).

2. **Ship the Sunday card on Becoming** — a screenshot-shareable, weekly-varying "your week ♥" composition that pulls her back on Sunday evening and gives her a TikTok-ready artifact. This is the Spotify-Wrapped pattern miniaturized; it's also the retention surface that compounds across weeks even when daily adherence is uneven. Design for screenshot first, in-app browsing second.

3. **Cut Week-1 push surface from 5 to 3, with zero "you missed" framing.** Keep Day 0 anchor + Day 2 engagement + Evening 8:30pm plate review. Move Day 3 first-log nudge and the daily reminder into in-app surfaces (Home cocoa note + silent live-activity). 3–6 weekly pushes drive 40% opt-out for this cohort; iOS opt-in is already only 43.9%. Every saved push is a retention preservation.

**On streaks**: keep them, but make them week-shaped (4 of 7), soft-recoverable (no broken-streak framing), placed in Becoming not Home. Never use "don't break your streak" copy anywhere — that is the Duolingo pattern the cohort is actively migrating away from.

**On the founder's 3 hypotheses**:
- #1 magical photo → **partially right**: speed is the lever, magic is the wrong frame. Build for instant + boring over delayed + delightful.
- #2 weight input friction → **wrong remedy**: the answer is *less* manual weight surface, not faster. Passive HealthKit trend + occasional log.
- #3 calories matter most for daily action → **wrong for this cohort**: calories drive Day-1 hook (table stakes); identity + trend + ritual drive D7–D90 retention. Don't put the kcal number at the top of Home.
