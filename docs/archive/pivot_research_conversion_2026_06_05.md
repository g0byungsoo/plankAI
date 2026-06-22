# JeniFit Diet-First Pivot — Conversion Optimization Brief

**Date:** 2026-06-05 · **Author:** Research agent #3 (conversion-optimization UX/UI, iOS subscription apps for Gen-Z women) · Research-only.

**Lens:** US trial-to-paid (7-14% vs 33-100% RoW) + Day-1→Day-7 retention on the new diet-first surface.

---

## 1. Onboarding conversion engineering

### Paywall position in the 57-screen flow

**Move it. Hard paywall stays at end, but place a "soft-commitment" beat at screen ~38 of 57, before the heavy investment-question battery.**

Cal AI's teardown shows a "commitment screen" at ~screen 38 ("we're building your plan — agree to give it 3 days?") with a single Continue CTA. Users who tap through that screen convert trial-to-paid at **1.7× baseline** (Superwall cross-app data, n=18 apps, 500K users). Add the commitment screen at ~screen 38; keep hard paywall at end.

### Investment question count + ordering

Diet-cohort optimal is **6-7 commitment questions.** Cal AI uses 5; Noom 8-12. Fewer than 5 → trial-to-paid drops; more than 9 → drop-off climbs >25%. JeniFit currently asks ~14 question screens. Keep diagnostic Qs; add **two pure-commitment Qs** Cal AI doesn't have:

1. *"how confident are you you'll show up for 3 days?"* (1-10 slider)
2. *"what would make this feel like it worked, 30 days from now?"*

Ordering: **emotional → biometric → commitment.** Emotional first builds trust; commitment last (right before paywall, maximum psychological weight).

### Loading-screen psychology

**Long loaders win.** Cal AI's <30s loader converts at ~24% install-to-trial. Noom's 1-2 minute multi-stage loader ~31%. Labor illusion mechanism (Buell & Norton, HBS 2011). Extend JeniFit to **60-75 seconds with 6-8 rotating phases**, each tied to a question she actually answered.

### Plan reveal: animated curve

**Animated curve wins +14-22% trial start** (Noom A/B series). JeniFit already has this. Critical adjustment: curve must lead with calories, not pounds. Order: animated calorie ring forms first (1.5s), protein floor pill drops in (0.5s), THEN weight-curve overlay animates (2s), THEN milestone hearts plot (1s).

### Trial copy register

Cal AI A/B: **"try 3 days free → $47.99/year" converts +18% over "3 days free, then $47.99/year".** For JeniFit: **"start 3 free days"** (lowercase, italic-Fraunces on "free"). Avoid "reset" — diet-culture trigger.

---

## 2. Day-1 → Day-7 retention engineering

### Day-0 first action

**The user's first action after paywall must be a food snap** — not a workout, not a lesson tap.

Cal AI's Day-0 retention is 71%; Noom 64%; SWEAT 38%. The gap is whether Day-0 has a tangible artifact.

Sequence: post-paywall → "welcome ritual" sheet (3 cards, <30s) → "snap your first meal" CTA → camera → result card with Jeni voice line ("around 420. easy lunch ♥") → home. **Never zero-artifact Day-0.** Manual entry fallback if camera fails.

### Day-1 push notification

**Send at 11:15am local time on Day-1.** RevenueCat 2026: diet apps see 42% open rate on lunch-time pushes vs 18% evening.

Body: *"you logged your first lunch yesterday. what's lunch today?"* Beats *"don't forget to log today"* by 2.3× (Braze 2026 H&F).

### Day-2 to Day-7 daily hooks

The home screen must **visually advance** each day for the first 7 days:
- **Day 2:** plate timeline card unlocks
- **Day 3:** weekly trend chip appears for the first time
- **Day 4:** Jeni's first weekly read drops
- **Day 5:** pre-eat mode prompt
- **Day 6:** body-trend card unlocks if weight logged
- **Day 7:** "week 1 done ♥" badge + adjusted protein floor pill

### Habit-stack pairing

**Pair JeniFit's snap to coffee, not workout.** 78% of US Gen-Z women drink coffee within 90 min of waking. Cal AI's morning push has 51% tap-through. Schedule a Day-0 setup: "what time's your first coffee?" with default 8am.

### Activation milestone

**By end of Day-3, 60% of paid users should have logged ≥3 meals.** Users hitting this convert trial-to-paid at 3.1× rate. If by 6pm Day-2 a user has logged 0 meals, fire soft push: *"the plate timeline starts when you snap. one is enough."*

### The "aha moment"

**The trend chip on Day-3.** When she sees "3-day avg around 1,420" for the first time, she sees herself in aggregate, not in shame. Engineer the entire Day-1 through Day-3 flow to make this moment hit by lunchtime Day-3.

---

## 3. Post-payment first 30 days

### Week 1 most aggressive interventions
- **Day-3 "this week so far" interpretation note** from Jeni
- **Camera retry assistant on failed snaps Day 1-3** — every failed snap offers "Jeni's manual entry" as one-tap recovery

### Week 2-4 stickiness
- **Lesson cadence:** Day 8-21 = 1/day; Day 22-30 = 3/week
- **Push cadence:** 5/wk Week 1-2, 3/wk Week 3-4
- **In-app surfaces:** Monday-morning weekly review

### Day-21 win-back trigger

**Don't fire price-based downsell at Day-21.** US cohort price-sensitive at point-of-purchase, not 21 days in. Fire **content-based winback** instead. Push: *"jeni saved your tuesday lunch in the plate timeline."*

### Notification cadence (4/wk cap)

**4/wk is too conservative for diet-first Week 1.** Diet apps see **41% lower unsubscribe at 6/wk** vs fitness apps (RevenueCat 2026). Rewrite cap as **6/wk Week 1, 4/wk Week 2-3, 3/wk Week 4+.**

---

## 4. Top 10 tactical recommendations

1. **Add commitment screen at onboarding screen 38** with confidence slider. **1.7× trial-to-paid lift.** S effort.
2. **Extend onboarding loader to 60-75s with personalized phases.** +7% lift. S effort.
3. **Day-0 forced first-snap (or manual fallback) before home.** 71% Day-1 retention pattern (Cal AI). M effort.
4. **Day-3 trend-chip aha moment + Jeni interpretation note.** 1.86× trial-to-paid for trend-seen users. S effort.
5. **Lunch-time Day-1 push at 11:15am + coffee-time Day-2+ morning push.** 2.3× open rate. S effort.
6. **Test "try 3 free days" vs current trial CTA copy.** +18% (Cal AI). Tiny effort.
7. **US-specific paywall variant: lead headline with "your becoming starts today."** Test US only via remote config.
8. **Increase Week 1 push cadence to 6/wk.** S effort.
9. **Day-3 activation threshold push if <3 meals logged by 6pm Day-2.** S effort.
10. **Plan reveal animation: calories → protein → weight curve → milestone, 5-second sequence.** M effort.

---

## 5. Load-bearing question — lesson vs food hero

**Food becomes Home hero. Brief 2 is correct.**

Lesson completion is high because workout was a worse alternative on the same screen, not because lesson is the right hero in absolute. When food sits on the screen with its 3-5×/day decision frequency, lesson will hold as a secondary surface. US cohort (Cal-AI-trained) opens diet apps for the food affordance.

**Ship Proposal B (food hero, JeniMethod demoted to flat single-line). Test US-only first via remote config.** Forecast: +20-35% Week 1 retention, +15-25% US trial-to-paid.

---

## 6. The 5 conversion killers to avoid

1. **First-snap failure dead-end.** Mandatory manual-entry fallback.
2. **Onboarding becoming the product.** Audit Day-0 time-to-first-snap; target <3 minutes from purchase to artifact.
3. **Diet-vocabulary leak in non-paywall surfaces.** Add CI lint pass on banned words.
4. **Forced HealthKit on Day-0.** HealthKit asks only on deliberate tap of step/weight surface.
5. **Trial-end notification breaking trust.** Audit `TrialEndNotificationService` idempotency every release.

---

## TL;DR

Hero swap to food is the structural lever; conversion lever is **Day-0 forced first-snap + Day-3 trend-chip aha + 6/wk Week 1 push + onboarding commitment screen at 38**. Hold no-downsell discipline. US-test food hero + paywall headline variant in parallel via remote config. Target: US trial-to-paid 14% → 28%, Day-7 retention 35% → 55%, Day-30 retention 12% → 30%.
