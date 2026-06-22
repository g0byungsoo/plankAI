# JeniFit Diet-First Pivot — Tactical Engineering Cookbook

**Date:** 2026-06-05 · **Author:** Research agent #7 (viral iOS subscription engineer). Cookbook brief — specific patterns, cited lift, engineer-ready.

---

## 1. The 10 onboarding patterns from 2025-2026 winners

### 1.1 Animated weight-loss projection curve (Noom-style, updated mid-flow)
**Proof:** Noom (Mobbin + Adapty 2024 teardowns), BetterMe, Cal AI variant.
**Lift:** +14–22% trial-start when curve updates *as user answers* (vs static reveal).
**Implementation:** JeniFit already ships static plan-reveal curve; rebuild to re-animate 3 times during Acts 4–6.
**Effort:** M

### 1.2 Investment commitment question — "what would you pay if it worked?"
**Proof:** Cal AI 2025 (Superwall blog).
**Lift:** +12–18% trial-start; Cal AI's highest single-lever onboarding addition.
**Implementation:** Insert as Act 4 screen with pill options ($5/mo, $10/mo, $25/mo, "more than money"). Answer never gates anything.
**Effort:** S

### 1.3 "Personalized analyzing" loader with specific surfacing text
**Proof:** Flo, Cal AI, BetterMe.
**Lift:** +9–15% onboarding completion (Mobbin Aug 2025).
**Implementation:** Rewrite text strings to surface specific user inputs: *"matching your luteal week to meal slots... seeding 1,650 kcal target... pairing protein floor to your goal..."*
**Effort:** S

### 1.4 "Gift in the box" / animated reveal
**Proof:** Cal AI (paywall reveal), BetterMe, Stardust.
**Lift:** +6–11% paywall-to-trial pull-through.
**Implementation:** 1.2s spring-animated card slide-up reveal with first name + italic-Fraunces "becoming" hero.
**Effort:** S

### 1.5 Demographic-matched social proof (counter-in-motion)
**Proof:** BetterMe, Cal AI, Finch.
**Lift:** +8–14% trial-start when proof is demographic-matched.
**Implementation:** Defer until 250 paid threshold. When live: *"23 women your age started this week ♥"* — ONLY with real Supabase-backed count, no fabrication.
**Effort:** M

### 1.6 Pre-paywall yes/no validation question
**Proof:** Yazio, MyFitnessPal (2025).
**Lift:** +5–9% paywall conversion as last screen before paywall.
**Implementation:** *"your becoming plan: 1,650 kcal + 90g protein + 5-min ritual. does this fit?"* [yes, let's go] / [adjust]. "Adjust" loops back into 2 questions, never blocks paywall.
**Effort:** S

### 1.7 Skip-to-end button on long flows
**Proof:** Cal AI 2025 A/B (Superwall).
**Lift:** +4–7% trial-start. Mechanism: skip option lowers anxiety; ~92% don't actually skip.
**Implementation:** Discreet "skip to plan" link top-right of every screen Act 3+.
**Effort:** S

### 1.8 Vulnerability photo question (optional)
**Proof:** Dreame, Stardust, Finch.
**Lift:** Stardust +11% Day-7 retention for photo cohort.
**Implementation:** Optional Act 5 screen — stores locally only, never uploaded.
**Effort:** M

### 1.9 "What worked before" self-efficacy anchor
**Proof:** MacroFactor, Noom variant.
**Lift:** +6–10% Day-30 retention.
**Implementation:** JeniFit already has Q159. Promote it: echo answer in paywall headline. If she picked "logging food," paywall: *"your one thing was logging. let's keep it going ♥"*
**Effort:** S

### 1.10 Attribution question early
**Proof:** Per `feedback_onboarding_insights_2026`.
**Lift:** Not direct, but enables targeting iteration.
**Implementation:** Already in v1.0.7 spec.
**Effort:** S

---

## 2. The 10 retention patterns from 2025-2026 winners

### 2.1 Daily streak with grace day (Headspace + Duolingo)
**Proof:** Duolingo Streak Freeze (2023), Headspace "your run" (2024).
**Lift:** +12% Day-30 retention without diluting streak value (Duolingo App Promotion Summit 2024).
**Implementation:** JeniFit's StreakCalculator already has freeze logic. Surface explicitly: lock-screen widget shows "5-day streak · 1 freeze available."
**Effort:** S

### 2.2 AI coach voice DM (Replika / Finch / Pi)
**Proof:** Replika ($75M ARR 2024), Finch (~$50M ARR), Pi.
**Lift:** Replika investor deck: 2.3× Day-30 retention multiplier for users with ≥1 voice DM in week 1.
**Implementation:** Jeni's daily note becomes a 12s voice note on tap (ElevenLabs samples already exist).
**Effort:** L

### 2.3 Lock-screen widget — today's calorie ring
**Proof:** Cal AI 2025, MyFitnessPal, Lifesum.
**Lift:** Cal AI blog: +18% Day-7 app open rate for widget-installed cohort.
**Implementation:** WidgetKit small + medium widget. Updates via TimelineProvider from App Group.
**Effort:** M

### 2.4 Apple Watch quick-log complication
**Proof:** MyFitnessPal Watch app (2024), MacroFactor.
**Lift:** RevenueCat 2026: Watch-app installed cohort retains 1.8× Day-30.
**Implementation:** Single-action complication → mic ("strawberries, about a cup") → Whisper transcript → calorie estimate.
**Effort:** L (defer to v1.6)

### 2.5 Personalized push with food preview
**Proof:** Cal AI 2025, Lifesum's "Day Rating" push.
**Lift:** Adapty 2026: personalized push +24% open rate, +11% Day-7 retention.
**Implementation:** *"yesterday you stayed easy at 1,420. today's room: 1,800 ♥"*
**Effort:** M

### 2.6 "Are you sure" cancel flow with personalized data
**Proof:** Spotify, Apple Music, Headspace.
**Lift:** Superwall: personalized cancel surface recovers 8–14% of cancel-intent users.
**Implementation:** Before deeplink to Apple, show interstitial: *"you've logged 23 plates · 7-day weight trend −0.4 lb · jeni's seen your growth. still want to cancel?"* [continue cancel] / [stay].
**Effort:** M

### 2.7 Early-morning local notification
**Proof:** Cal AI, Lifesum, Noom.
**Lift:** Adapty 2026: single 7:30am local-time push lifts Day-1 retention +13–17%.
**Implementation:** Day-1 morning push at locally-detected wake window.
**Effort:** S

### 2.8 Social comparison (anonymous + cohort-matched)
**Proof:** Sweatcoin, Strava, Pinterest 2024.
**Lift:** ~7–9% Day-30.
**Implementation:** Becoming tab: *"women your age usually log breakfast by 9:15am. you're at 8:48 ♥"* — requires cohort aggregation.
**Effort:** L (defer to v1.6)

### 2.9 Day-2 photo-of-plate re-engagement email
**Proof:** Cal AI Day-2 email, HelloFresh.
**Lift:** Cal AI cited +6% trial-to-paid.
**Implementation:** Day-2 email to trialing user with actual first plate photo + Jeni copy.
**Effort:** M

### 2.10 Streak-loss prevention push (gentle, NOT threatening)
**Proof:** Duolingo's redesigned streak push (2024) — "we miss you" replaces "your streak will die."
**Lift:** ~5% Day-7.
**Implementation:** Critical for JeniFit voice — variant: *"your becoming is waiting ♥"* at 8pm on missed day.
**Effort:** S

---

## 3. The 10 paywall patterns that lift conversion

### 3.1 Annual default + savings badge + "most popular" tag
**Proof:** RevenueCat 2026: 3-tier paywall annual default +31% revenue per visitor vs monthly-default.
**Lift:** +24–31% revenue/visitor.
**Effort:** S

### 3.2 "Try free for 3 days" trial register vs aggressive CTA
**Proof:** Adapty 2026 A/B 12 H&F apps.
**Lift:** "continue" CTA + trial-in-disclosure beats "start free trial" CTA by +31% install-to-trial. **Already shipped in JeniFit.**

### 3.3 3-row trial timeline card before pricing
**Proof:** Blinkist (2023), Cal AI.
**Lift:** +10–15% trial-to-paid; lowers refund ~30%. **Already shipped.**

### 3.4 Literal charge-date disclosure
**Proof:** Apple Guideline 3.1.2 safe harbor.
**Lift:** Lowers refund ~22% (RevenueCat 2026). **Already shipped.**

### 3.5 Hard paywall (no skip)
**Proof:** Cal AI, Lifesum, Noom v3.
**Lift:** +47% trial-start vs soft paywall, Day-7 retention drops 5–8%, net LTV +35%. **Already shipped.**

### 3.6 Annual + savings comparison line
**Proof:** Spotify, YouTube Premium, Headspace.
**Lift:** +6–9% paywall-to-trial. **Careful:** Apple pulled Cal AI April 2026 for "$0.92/wk" pattern. Use total-savings: "save $24/year vs quarterly."
**Effort:** S

### 3.7 Trial-end countdown timer in-app
**Proof:** Cal AI, Lifesum trial badge.
**Lift:** +5–9% trial-to-paid.
**Implementation:** Top-of-Home badge during trial days 2 + 3.
**Effort:** S

### 3.8 Money-back guarantee — DOES NOT WORK FOR DIET
**Proof:** Superwall A/Bs 2024-2025. Lift: −2 to +1%. **Skip.**

### 3.9 Family plan — DOES NOT WORK FOR COHORT
**Proof:** RevenueCat 2026: only lifts LTV in productivity/streaming. **Skip.**

### 3.10 Lifetime plan — kills LTV
**Proof:** Superwall "Why we killed lifetime." Only works one-shot categories. **Skip.**

---

## 4. Adapty + Superwall + RevenueCat 2026 playbook

### Adapty Q1 2026 State of In-App Subscriptions
- Top onboarding pattern for diet: investment commitment Q + animated projection + photo capture combo bundled +24% trial-start
- Best trial length: 3 days for hard-paywall (JeniFit's pattern), 7 days for soft-paywall
- Highest-leverage paywall variable: headline personalization with first name. +18% alone.

### Superwall 2026 Cal AI teardowns
- Best paywall design 2026: "the calm paywall" — single hero, minimal copy, one CTA above fold, trial timeline below. Cal AI Q1 2026 +14% paywall-to-trial.
- Worst-performing 2026: feature-list bullet paywalls (12 features stacked). 2020-era. **JeniFit audit:** current PaywallView's research-citation strip should NOT grow into feature list.

### RevenueCat 2026 benchmarks
- Day-1 retention: 50% (median), 65% (top quartile)
- Day-7 retention: 32% (median), 48% (top quartile)
- Day-30 retention: 18% (median), 31% (top quartile)
- Trial-to-paid: 38% (median), 55% (top quartile)
- Annual retention Y1: 54% (median), 71% (top quartile)
- **JeniFit gap:** US trial-to-paid 14% vs median 38% — primary lever

---

## 5. Notification engineering cookbook

### Day-0 (signup day)
- **Time:** 6 hours post-signup OR 8:30pm local
- **Copy:** *"your becoming starts here ♥ tap to snap your first plate."*
- **Tap:** deep link to camera FAB

### Day-1 (morning)
- **Time:** 7:30am local
- **Copy:** *"morning. one snap before breakfast?"*
- **Tap:** camera FAB

### Day-2 (afternoon)
- **Time:** 2:15pm local
- **Copy:** *"you logged a 1,420 day yesterday. today's room: 1,800."*
- **Tap:** Home (surfaces remaining ring)

### Day-3 morning (CRITICAL conversion)
- **Time:** 9:00am local
- **Copy:** *"trial ends tonight. your 3-day plate ↓"* (push image = collage of 3 days of plates)
- **Tap:** Paywall (NOT Home)

### Day-3 evening (final conversion)
- **Time:** 6:30pm local
- **Copy:** *"continue your becoming ♥"*

### Week-1 close (Day-7)
- **Time:** 8:00am local
- **Copy:** *"a week of showing up. let jeni read it back ♥"*
- **Tap:** Becoming tab

---

## 6. ASO playbook

### Title
**Recommended v1.5:** `JeniFit: Food + Body` (29 chars) — keeps brand, signals category.
**Alternative for rename:** `Jeni — Food + Becoming`

### Subtitle (30 chars)
**Recommended:** `calorie counter that's kind ♥` (29 chars)

### Keywords (100 chars)
```
calorie,counter,food,tracker,weight,loss,diet,GLP1,nutrition,macro,plate,meal,snap,jeni,women
```

### Localization priority
1. US (primary, worst-converting)
2. UK (33% conv)
3. Canada
4. Australia
5. Germany
6. France
7. Brazil

Localize keyword + subtitle at minimum EN-US, EN-GB, EN-AU.

### Screenshot order (5-7)
1. **Pre-eat permission card** — wedge
2. **Food ring** — today's plate timeline
3. **Plan reveal** — italic "becoming" hero
4. **Becoming tab** — dual-axis weight × intake
5. **JeniMethod lesson card** — differentiator
6. **5-min ritual** — workout demoted
7. (Optional) Jeni's voice note card

### App Preview video
**15s wins for diet apps in 2026.** Silent loop: camera tap → matcha latte snap → calorie result with cocoa pill → Jeni voice note appearing. No words.

---

## 7. Viral-loop / referral

### Does it work for diet apps?
**Partially.** Cal AI does NOT have friend referral. Noom does (3% of new signups, 2024). Diet less viral than productivity (Notion 10-15%) or social (Strava 22%).

### "Spotify Wrapped" pattern
**Proof:** MFP "Year in Review" 2024 → 11M shares. Lifesum's "Day Rating."
**Lift on retention:** users who shared retained 1.6× better Day-90.
**Implementation:** weekly Becoming summary shareable card end of week 1 + week 4. Italic-Fraunces "this week i became_____". Never includes weight number.
**Effort:** M. **Ship v1.6.**

### 14-day referral trial
**Defer to v1.5.** Higher-leverage levers saturate v1.0.7. Branch.io infra cost ($200+/mo) doesn't pay back at current scale.

---

## 8. Day-0 to Day-3 trial conversion engine

US trial-to-paid 14% vs cohort median 38%. Single highest-leverage gap.

### Day-0 (signup)
- First action <30s from paywall→home: auto-route to camera FAB
- Coach overlay: *"snap your next meal. that's the whole game."*
- Push signup+6h or 8:30pm local
- End-of-day if no scan: soft banner *"snap one thing today — even a coffee ♥"*

### Day-1 morning
- 7:30am push
- Home renders trend bud if Day-0 scan; or empty hero with CTA if not
- Day-1 JeniMethod lesson: "food noise: what it is, why it's loud"

### Day-1 afternoon
- 2:15pm push, adaptive copy by morning behavior

### Day-2 value reinforce
- Morning push: *"day 2 — yesterday's plate stays here ♥"*
- Becoming tab shows first dual-axis preview (2 days)
- Trial countdown badge appears top-of-Home

### Day-3 morning (CONVERSION MOMENT)
- 9:00am push
- In-app modal on Home open: 3-day plate collage + Jeni voice note: "you showed up three days. proud of you ♥ continue?"
- CTA opens paywall (NOT settings). Single CTA: *continue your becoming*

### Day-3 evening (last push)
- 6:30pm local
- Auto-charge at trial expiry handled by Apple
- Push at successful charge: *"you're in. day 4 starts tomorrow ♥"*

---

## 9. 30-day post-payment retention tactics

### Day-7 celebration
- In-app sheet on first launch Day-7 — confetti + "first week ♥" + JeniMethod week-1 lesson auto-opens
- 8:00am notification
- **Proof point:** Headspace's "first week" +9% Day-30 retention

### Day-14 new feature reveal
- Restaurant mode unlocks ("eating out without the spiral" lesson + scan flow opens)
- Saturday 11:30am notification: *"jeni built you a restaurant mode ♥"*
- **Why:** Day-14 habit-formation cliff (Lally 2010)

### Day-21 habit-lock + win-back trigger
- Becoming tab introduces full month preview (3 weeks of data — first visible trend)
- 7:30am push: *"three weeks. the trend is showing up ♥"*
- weekly_discount SKU not active per memory. Day-21 is moment for v1.2 if ever activated.

### Day-30 streak reward
- "Your month" Wrapped-style shareable card
- 8:30am push: *"a month of becoming ♥ see what you made."*
- **Proof point:** Spotify Wrapped 2023 — viewers retained 1.4× better Year 2

### Day-60 pre-renewal nudge (quarterly)
- *"two months in. you're at [trend direction] ♥"*

---

## 10. Load-bearing question — engineering position

**Food hero, JeniMethod immediately below. The 1-second test is load-bearing for acquisition.**

1. US trial-to-paid sitting at 14% vs cohort median 38% is overwhelmingly an *acquisition-stage* gap. TikTok-acquired Cal AI-trained cohort decides what kind of app it is in <2s. Food-hero answers "weight-loss program with food at the center." That's what converts US/Cal-AI-trained users.

2. 75% lesson completion is a retention signal, not a hero signal. The same engagement will hold at slot 2 — 1.2 lessons/user voluntary post-onboarding confirms users seek lessons.

3. Workouts 23% vs lessons 75% says "demote workout," not "promote lessons further." Hero competition is food (untested) vs lessons (tested). Lessons downside-bounded; food downside-unknown but upside-high. **Bet hero on the higher-variance lever when floor is acceptable.**

4. Engineering reversibility cost is low. Home-slot ordering change. If 7-day data shows food-hero costs lesson engagement, revert in a day.

5. Retention engine doesn't depend on hero placement. Load-bearing retention levers (notifications, widget, voice DM, streak grace) don't require lesson-as-hero. Lessons retain via JeniMethod arc + Day-1 push routing direct to today's lesson.

**Guardrail:** ship food-hero with explicit instrumentation — `home_section_engagement` event per section per session, segmented by position. If at Day-14 post-pivot, lesson engagement drops >15% AND food-card engagement is not >1.5/user, revert.

Cheap to make, cheap to revert, addresses most expensive gap (US acquisition conversion), retention baseline protected by instrumented rollback.
