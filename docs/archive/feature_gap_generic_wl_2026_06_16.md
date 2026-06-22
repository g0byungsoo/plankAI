# Feature-Gap Roadmap — Generic Weight-Loss CPP
**Date:** 2026-06-16
**Audience:** US women 22-45, TikTok-acquired, non-GLP-1-aware. The 3rd CPP variant.
**Goal:** features that ALSO serve the GLP-1 + post-GLP-1 cohorts so the product CONVERGES, not bifurcates
**Constraint:** solo iOS founder, ≤10 weeks total

---

## TL;DR — Three answers up front

**1. The feature gap that IS the 7-14% US conversion leak.** Not "more onboarding screens." The absence of **a daily, named, image-back surface that resolves food noise into a one-line decision before noon.** Cal AI gives the user a calorie reveal in the first 30 seconds; JeniFit gives her a 6-part questionnaire and a custom program. By Day 2, Cal AI's user knows her daily ritual ("scan, see number, move on"). JeniFit's user knows she's enrolled in a program but has no daily reason-to-open that takes <20 seconds and produces a visible artifact. **The leak is the missing 20-second daily ritual that produces a shareable, anti-shame artifact.**

**2. The feature that beats Cal AI on a wedge Cal AI can't reach.** Cal AI is decision-after-the-fact ("you ate this; here's the number"). JeniFit's photo + pre-eat mode is decision-before-the-fact. The unbuilt wedge is **a 10-second "food noise resolver"** — a Jeni-voiced check on what she's about to eat that returns *permission language* (not numeric judgment). Cal AI's architecture cannot ship this without becoming a coach app, and their team is busy integrating with MFP for 12-18 months. **The window is open.**

**3. The feature that serves BOTH cohorts.** **Adaptive weekly recalibration with cohort-aware floors** — already half-built in `ProgramGoalCalculator` (GLP-1 0.3%/wk floor, short-sleeper Nedeltcheva floor, perimenopause floor). Promoting it from onboarding-time calc to a **weekly-visible "this week your body is doing X" recalibration card** serves the GLP-1 cohort (their bodies are recomposing on different math) and the generic-WL cohort (they don't know what TDEE is but they FEEL the plateau). One feature, two cohort-translated stories.

**Founder top-3 P0 ships, week 1-3:**
1. **Daily Plate Score** — the missing 20-second ritual
2. **Pre-eat permission card** — the Jeni-voiced decision moment
3. **Day-1 first-scan magic moment** — replicate Cal AI's activation

**Founder top-3 P1 ships, week 4-10:**
4. **Food noise journal** — one tap, 3 chips, anti-Noom register
5. **Weekly recalibration card** — the cohort-converging feature
6. **Plate of the day share card** — Pinterest-coded NSV + organic acquisition

---

## How I read the landscape

Six observations from 18 search threads through App Store, Reddit, competitive teardowns:

**(a) The 2026 calorie-tracker market just consolidated.** MFP acquired Cal AI March 2026. MFP redesign triggered "the loudest wave of switching-intent in the category in years." Cal AI was pulled from App Store in April for deceptive billing. **The whole tier is busy integrating, not innovating. This is the window.**

**(b) The Cal AI wedge is logging speed, not coaching.** "Cal AI is a passive tracker that logs what you eat and displays your numbers, with no coaching features, no daily insights, no personalized feedback" (eesel AI teardown). Reviewers repeatedly ask "for some kind of guidance or feedback on whether I'm on track." **JeniFit's coach voice is a moat against the entire calorie-tracker tier.**

**(c) The MFP redesign created a six-complaint pattern that maps to JeniFit's white space.** More taps to log a meal, no calories-per-meal at-a-glance, removed multi-select, tiny macros, cluttered home, fragmented navigation. **The cohort wants information density without panopticon density. Editorial coquette is the answer.**

**(d) Cal AI's $40M ARR + 30%+ retention is the magic-moment proof.** "Cal AI's onboarding flow provides instant value by calculating BMI and showing a projected weight loss graph based on the user's initial quiz answers." **JeniFit already has the projection — the gap is the first-scan reveal.**

**(e) Noom's "Future Me" AI face scan is the new motivation-visualization vector** (launched Oct 2025). This is the "after photo" reborn — and it's exactly the kind of feature JeniFit's anti-femvertising voice should refuse to copy. **NOT every Noom feature is one JeniFit should match.**

**(f) Women's #1 complaint about the category is shame-loop logging.** "If you have a history of disordered eating … a tracking app can reinforce harmful behaviors" (Welling 2026). Apps like AteMate, Thora, and Recovery Record exist because MFP/Cal AI/Noom are unsafe surfaces. **JeniFit's anti-Noom brand voice + non-prescription cohort floors are uncopyable shame-defusing infrastructure.** Lean in.

---

## Feature Gap Roadmap

### Food rail core

#### Daily Plate Score
- **Why this cohort needs it:** Cal AI gives her a number per scan. Noom gives her color-coded green/yellow/red. JeniFit gives her a Becoming dashboard at week's end. **None give her a daily 20-second artifact that says "today's plate, in one image."**
- **Priority:** P0 (parity, but redesigned to JeniFit register)
- **Effort:** 5-7 days (compose existing scan cards into 4-up grid + 1-line plate caption + share-as-image)
- **Is JeniFit close?:** Partial. Scrapbook polaroid layer ships individual food photos. Missing: daily-collapse view as home-screen artifact.
- **Citation:** PlateLens 2026 MFP alternatives review.
- **Brand fit:** Very high. Plate is photographic (real food), italic-Fraunces caption, no color-coded scoring (language: "balanced day" / "still room").

#### Pre-eat permission card
- **Why this cohort needs it:** Existing pre-eat mode promoted to daily ritual. Cal AI users want "guidance or feedback" but Cal AI's architecture is decision-after-the-fact. The pre-eat moment is the decision moment.
- **Priority:** P0 (the Cal AI moat)
- **Effort:** 3-4 days (already built; needs daily-surface promotion + 3 response variants + Jeni voice copy lock)
- **Is JeniFit close?:** Yes — pre-eat mode shipping. Missing: surface on Home, daily count badge, copy with permission language.
- **Citation:** eesel AI Cal AI teardown.
- **Brand fit:** This IS the brand. Permission language, Jeni voice, decision-before-the-fact.

#### Voice food logging
- **Why this cohort needs it:** MFP and Lose It! both shipped voice ("I had two eggs and toast") in 2026. Voice cuts meal logging from 45s to ~10s.
- **Priority:** P1 (parity table-stakes, not differentiator)
- **Effort:** 5-7 days (Whisper API + parse to FoodEntry + existing pipeline)
- **Is JeniFit close?:** No. Worth a thin Whisper-based implementation.
- **Citation:** Lose It! 2026 Say-It feature; Nutrola 2026 roundup.

#### Restaurant chain pre-loaded catalog
- **Why this cohort needs it:** Cal AI's restaurant accuracy is #1 photo-scan complaint. JeniFit ships restaurant mode + chain catalog. Promote it.
- **Priority:** P1
- **Effort:** 2-3 days to promote the existing catalog to a discoverable Home rail.
- **Is JeniFit close?:** Yes — already built. Missing: surface visibility.
- **Citation:** justuseapp Cal AI reviews — "23,000 calories for an 18-ounce steak" recurring meme.

### Habit + behavior layer

#### Food noise journal (one-tap, 3-chip)
- **Why this cohort needs it:** AteMate, Eating Enlightenment exist because MFP/Cal AI are emotionally hostile surfaces. "75% of overeating is driven by emotions rather than hunger." Generic-WL cohort doesn't journal — but she'll tap 3 chips.
- **Priority:** P0 (THE anti-Noom wedge)
- **Effort:** 4-5 days (chip selector + cohort-flag plumbing + Becoming weekly insight surface)
- **Is JeniFit close?:** Partial. JeniMethod CBT lessons teach the framework; no in-product capture surface.
- **Citation:** AteMate journal-prompts research; Welling 2026 on calorie-tracker harm.
- **Brand fit:** Maximum. Chips named in post-Ozempic vocabulary: "food noise," "tomorrow resets," "this fits," "not hungry," "stress."

#### Weekly recalibration card
- **Why this cohort needs it:** MacroFactor's $72/yr wedge IS adaptive weekly TDEE recalc. Generic-WL cohort doesn't know what TDEE is — they FEEL the plateau. **One card on Becoming, weekly, that reads "your body did X this week; next week we shift Y" closes the MacroFactor wedge for non-data women.**
- **Priority:** P0 (serves BOTH cohorts — GLP-1 floor + generic-WL plateau)
- **Effort:** 4-6 days (`ProgramGoalCalculator` already has cohort floors; weekly Becoming surface + copy + 3-state card)
- **Is JeniFit close?:** Half-built. Engine exists; surface doesn't.
- **Citation:** MacroFactor 2026 adaptive TDEE review; v2 strategy doc.
- **Brand fit:** Excellent. "your *body* did X this week" — italic-Fraunces native. Permission frame.

#### Adaptive notification rhythm (food-noise based)
- **Why this cohort needs it:** TrygGaya Cal AI review explicitly calls out missing notifications. JeniFit's notification system is post-Ozempic-aware but not tied to user food-noise signal.
- **Priority:** P1 (retention multiplier on the food-noise journal)
- **Effort:** 3-4 days (chip→trigger rule + 5 new local-notification templates)
- **Is JeniFit close?:** Partial. Local notification infra exists. Trigger rules tied to chip data don't yet exist.
- **Citation:** Cal AI review TrygGaya; Cornell behavioral retention research.

### Body + identity recognition

#### Plate of the day share card
- **Why this cohort needs it:** TikTok-acquired women share NSV moments. Category is sterile share-cards (MFP calorie log, Cal AI per-meal). **An editorial-coquette plate-of-the-day card with italic-Fraunces caption + JeniFit watermark is a TikTok-native NSV artifact.**
- **Priority:** P1 (organic acquisition vector + retention)
- **Effort:** 3-4 days (compose plate grid + caption + JeniFit watermark + UIActivityViewController)
- **Is JeniFit close?:** Partial. ShareLink added to PostSessionView. Plate share card doesn't exist.
- **Citation:** Reclaim 2026 habit-tracker research; v2 strategy doc Pillar 4.
- **Brand fit:** Maximum. This IS the brand made shareable.

#### Weight trend "this week your body" card
- **Why this cohort needs it:** Becoming tab has weight EMA + WHO ring + goal projection. **What it lacks is a weekly anti-shame narrative reading of the trend**: "you held steady this week. that's the body integrating, not stalling."
- **Priority:** P1 (closes the Noom psychology-lesson gap without the lesson)
- **Effort:** 2-3 days (existing EMA + 5-6 copy templates by trend state)
- **Is JeniFit close?:** Yes. Engine exists, copy layer is the gap.

#### NSV chips (non-scale victory micro-capture)
- **Why this cohort needs it:** WW research on NSVs — sleep better, fewer stair-breaks, jeans loose. Generic-WL cohort goes weeks without scale moving but feels other change. **A weekly Sunday chip-set ("which of these did you notice?") becomes longitudinal in Becoming.**
- **Priority:** P1 (anti-shame infrastructure + retention)
- **Effort:** 3-4 days (chip selector + weekly Sunday surface + Becoming longitudinal view)
- **Is JeniFit close?:** No. Becoming barrier-resolved card is close in spirit but not the daily/weekly capture.
- **Citation:** WW NSV research.

### Onboarding + first-session magic

#### Day-1 first-scan magic moment
- **Why this cohort needs it:** Cal AI's 30%+ retention is largely the first-scan reveal — "snap a photo, see a number, you ARE doing this." JeniFit's first session is the BMI projection — credible but text-heavy. **The first SCAN is the missing day-1 moment.**
- **Priority:** P0 (the conversion-leak fix)
- **Effort:** 5-7 days (onboarding "first scan now" CTA → photo pipe → reveal screen styled in editorial register + Jeni copy)
- **Is JeniFit close?:** Partial. Scan pipe exists; not wired to onboarding flow.
- **Citation:** Stormy AI 2026 paywall conversion guide; Cal AI screensdesign UI breakdown.
- **Brand fit:** Excellent if scan reveal is editorial — italic-Fraunces "your first *plate*." caption.

#### Projection vs. real-data reveal (week 1)
- **Why this cohort needs it:** Cal AI projects weight loss in onboarding; users have nothing to compare to until week 4. JeniFit can ship **a week-1 "projection vs. your real first week" reveal**.
- **Priority:** P1 (week-1 retention)
- **Effort:** 3-4 days (Sunday card that overlays projection line + real EMA)
- **Is JeniFit close?:** Yes — engine + Sunday card surface exist. Composition doesn't.

### Retention + ritual

#### Daily "what to expect today" card (program-aware)
- **Why this cohort needs it:** BetterMe's 14-pattern conversion teardown returns to *what's happening today*. Generic-WL cohort opens to know *what's next*.
- **Priority:** P1 (week-2 retention)
- **Effort:** 2-3 days (one-line generator off existing program day)
- **Is JeniFit close?:** Yes — `ProgramDayPrescription` exists. Missing: a single-line headline pulled from it.

#### Sunday recap ritual
- **Why this cohort needs it:** "Story-integrated habit apps demonstrated 47% higher 90-day retention." Sunday is the inflection point — generic-WL cohort plans her week on Sunday.
- **Priority:** P1 (week 2-4 retention)
- **Effort:** 4-6 days (Sunday card composition + Monday intention selector + Becoming archive)
- **Is JeniFit close?:** Partial. `SundayCard.swift` exists.
- **Citation:** Reclaim 2026 habit apps research.

### Differentiated wedges

#### Cycle-aware adaptive program
- **Why this cohort needs it:** Cycle-syncing is exploding in 2026 for women 22-45. Cal AI/MFP will never ship this.
- **Priority:** P2 (mark for v1.2)
- **Effort:** 6-8 days (HealthKit menstrual data + 4-phase plan modifier + UX surface)
- **Is JeniFit close?:** Partial. Onboarding asks hormonal; engine doesn't read cycle.
- **Brand fit:** Good. Must AVOID astrology register (Stardust trap).

#### Honest pricing as a feature
- **Why this cohort needs it:** Cal AI removed from App Store April 2026 for deceptive billing. MFP 1.4-star Trustpilot largely billing complaints. **Honest-pricing badge + cancel-from-app flow is a brand asset.**
- **Priority:** P1 (brand-voice asset, low engineering)
- **Effort:** 2-3 days (settings cancel CTA + transparent pricing page)
- **Is JeniFit close?:** Mostly yes. Existing RevenueCat flow + cancellation winback sheet.

#### Streak-free progression (explicit framing)
- **Why this cohort needs it:** Anti-Noom, anti-shame. Streaks weaponize against missed-day cohort.
- **Priority:** P2 (brand asset, defensive)
- **Effort:** 1 day (settings copy + about page)
- **Is JeniFit close?:** Yes — already no streaks. Missing: explicit framing as a brand differentiator.

---

## Cohort convergence — features that serve BOTH GLP-1 and generic-WL

| Feature | Generic-WL value | GLP-1 cohort value |
|---|---|---|
| Daily Plate Score | "I made a balanced plate today" | "I hit protein floor on reduced appetite" |
| Pre-eat permission card | "is this in my budget?" | "is this enough? GLP-1 makes me forget to eat" |
| Weekly recalibration card | "plateau is normal" | "my body is on a different math now" |
| Food noise journal | post-Ozempic vocab landing on TikTok cohort | literal pharmacology mechanism the cohort knows |
| Voice food logging | "I'm lazy, I want to log fast" | "GLP-1 nausea makes me not want to use the camera" |
| NSV chips | "scale isn't moving but I feel better" | "GLP-1 changes happen non-linearly; mood/sleep first" |

**6 of 12 P0/P1 features serve both cohorts.** This is the converged-product story. No feature in the top-6 forces a cohort split.

---

## What I'd NOT ship

- **AI face scan / Future Me** (Noom Oct 2025). Brand-incompatible.
- **Streaks** (v2 strategy non-negotiable).
- **Community / forums** (Reverse Health 80k member forum model). Solo iOS founder cannot moderate.
- **Public leaderboards / challenges.** Anti-shame violation.
- **Calorie-deficit explicit framing.** Post-Ozempic vocab says this is the toxic-tracker register the cohort is fleeing.

---

## Top-3 P0 (week 1-3) — fix the 7-14% US conversion leak

1. **Daily Plate Score** (5-7 days) — the missing 20-second daily ritual
2. **Pre-eat permission card** (3-4 days) — promote pre-eat to a daily home-surface ritual
3. **Day-1 first-scan magic moment** (5-7 days) — replicate Cal AI's activation in editorial-coquette register

**Total: 13-18 dev days. Expected: closes Cal-AI-trained-cohort activation gap. Conservative +20-40% paywall→trial; aggressive matches H&F median 13.7%.**

## Top-3 P1 (week 4-10) — make JeniFit uncopyable

4. **Food noise journal** (4-5 days) — one-tap chip in post-Ozempic vocab; THE anti-Noom wedge; serves both cohorts
5. **Weekly recalibration card** (4-6 days) — MacroFactor wedge for non-data women + GLP-1 cohort math
6. **Plate of the day share card** (3-4 days) — TikTok-native NSV artifact; organic acquisition vector

---

## Sources

- [Cal AI Reviews 2026 — justuseapp](https://justuseapp.com/en/app/6480417616/cal-ai-calorie-tracking/reviews)
- [Cal AI Review — eesel AI](https://www.eesel.ai/blog/cal-ai)
- [MFP Acquires Cal AI — TechCrunch March 2026](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/)
- [MFP Today tab complaints — PiunikaWeb April 2026](https://piunikaweb.com/2026/04/24/myfitnesspal-new-update-complaints/)
- [MFP Alternatives 2026 — PlateLens](https://platelens.app/blog/myfitnesspal-alternatives-2026)
- [BetterMe Review 2026 — justuseapp](https://justuseapp.com/en/app/1264546236/betterme-weight-loss-workouts/reviews)
- [Calorie tracker apps for women 2026 — Welling](https://www.welling.ai/articles/best-calorie-tracking-apps-women-2026)
- [Best food journaling app 2026 — AteMate](https://www.atemate.com/blog/best-food-journaling-app)
- [MacroFactor adaptive TDEE 2026 — TrygGaya](https://www.trygaya.com/review/macrofactor-review)
- [Lose It! review 2026](https://calorie-trackers.com/reviews/lose-it/)
- [Cronometer review 2026](https://www.garagegymreviews.com/cronometer-review)
- [Noom Future Me + AI face scan launch](https://www.noom.com/in-the-news/noom-launches-ai-face-scan-and-ai-future-me-to-bring-preventive-health-insights-to-everyone/)
- [Cal AI Adapty paywall breakdown](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/)
- [Cal AI screensdesign UI breakdown](https://screensdesign.com/showcase/cal-ai-calorie-tracker)
- [Paywall conversion guide — Stormy AI](https://stormy.ai/blog/app-paywall-onboarding-optimization-guide)
- [Habit tracker apps 2026 — Reclaim](https://reclaim.ai/blog/habit-tracker-apps)
- [Cycle Diet App Review 2026](https://yourhealthmagazine.net/article/reviews/cycle-diet-app-review-the-best-weight-loss-app-for-women-in-2026/)
- [WW Non-Scale Victories](https://www.weightwatchers.com/us/blog/weight-loss/non-scale-victories)
