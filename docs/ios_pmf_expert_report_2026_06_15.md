# JeniFit PMF Diagnosis & Product Roadmap to $100k/mo MRR

*2026-06-14. Senior iOS product / PMF audit, grounded in the v1.0.9 codebase, 7-day PostHog data, and the v2 strategy doc. Written to be read once and acted on — opinionated, not hedged.*

---

## A. PMF diagnosis right now

### A.1 What JeniFit's actual wedge is in 2026

Not "another fitness app." Not "Cal AI but coquette." Not even "diet-first weight-loss program" — that's the *category*, not the *wedge*.

**The wedge is:** *the only app a woman 22-35 can open without feeling addressed by either the 2010s diet-culture machine OR the GLP-1 calorie-math optimizer.* The unit is a **trusted register** — vocabulary + visual restraint + permission-frame copy — that the cohort has spent a year migrating toward (post-SkinnyTok deplatforming, post-Cal AI billing scandal, post-Maintenance Phase). Every other app sounds like a coach yelling or a spreadsheet judging. JeniFit sounds like a friend who happens to know nutrition.

The strategy doc names it correctly: *the behavioral version of what GLP-1s do to food noise.* That's the **outcome promise**. The wedge underneath that promise is **brand-register-as-product** — the only register the cohort lets through their filter. **The defensibility is the brand, not the features.** Cal AI can copy the calorie scanner in a sprint; they cannot retrofit lowercase casual / italic-Fraunces / hearts-as-punctuation / "tomorrow resets" voice without their existing user base revolting.

This frame matters because it changes what's load-bearing. The italic-punch headline at `PlanView:608-617` first-run hint is not decoration — it's the wedge. The "your jeni knows" mental model is not a feature — it's the wedge. **The food rail is the *retention surface*; the voice is the *acquisition + activation surface*.**

### A.2 Where the current product CONTRADICTS its own positioning

Six specific contradictions, ranked by damage:

**Contradiction #1 — Home is still architected for a workout app.** `/Users/bko/plankAI/PlankApp/Views/Plan/PlanView.swift:756-767` composes the daily checklist as: `lesson → snap → move → steps → weigh-in/breath`. That's already lesson-first in order, but **the row weights are equal** — there's no visual hierarchy that says "the lesson + the snap are the day; everything else is optional." A user who opens PlanView sees 5 rows of equivalent rectangles. Workout completion is 11% precisely because the row before it (snap meal) and the row after it (steps) carry equal visual gravity. The five-row checklist is design-democracy in a feature where the cohort needs **opinionation**.

**Contradiction #2 — The "diet-first" pivot is in the docs but not yet in the UI.** Looking at `PlanRow.swift`, the snap-meal row gets a calorie subtitle but the move row gets a tier badge + minute label + "round 2" affordance. The move row is *more visually decorated* than the snap row. The food rail is the most engaged feature (11/12 captures completed, 92% — the highest signal in the funnel) and it's currently dressed down to look equal to the workout. Either the workout row needs to be visually quieted, or the snap-meal row needs to be promoted to a hero tile (~2x height, real photo of last logged meal, today's running total as the big number).

**Contradiction #3 — There is no Home for un-enrolled users.** `HomeView.swift` was retired — the legacy file is now a 35-line `StatCard` orphan. MainTabView routes program-enrolled users to PlanView and un-enrolled users to ProgramOnrampView. That's defensible, but it means **the moment of "I haven't decided to commit yet" lives entirely in the onramp surface, which carries different design weight than a real Home.** Look at the comment at `PlanView.swift:106` — the team had to add a `planFirstRunHintSeen` hint *inside the program-era home* because new users land on raw checklists with zero context. That's a Day-1 leak pattern visible in code. **D1 retention 12% is, in part, this:** the first-open experience for a fresh trial is a checklist she didn't earn yet.

**Contradiction #4 — Weight logging is in the checklist as a Sunday-only row.** `PlanView.swift:761-763`: `weighIn` shows only on `weekday == 1` (Sunday). On all other days, breathwork takes that slot. The strategy doc identifies weight logging as a critical leak (near-zero, vs 60-80% Day-1 in WL apps). The product is **structurally suppressing** the data primitive that powers Becoming's trend math, BMI banding, plateau intervention, and 6 of 8 Becoming modules. There is no daily ambient nudge for weight. The Sunday slot is also competing with breathwork (which clears 75%, so it's a real opportunity cost). This is a **6-line fix** with outsized PMF implications.

**Contradiction #5 — The "AI" word is purged from copy, but the product is still hiding its AI under a rug.** Cal AI made calorie-photo-counting a *brand promise* in the App Store icon + first screen. JeniFit's food rail (`CaptureFlowView.swift`) is genuinely magical — Polaroid hero, develop-in animation, sticker scatter — but the App Store screenshots, the paywall, and the trial-end nudge sequences don't lead with photo→plate. **The most engaged feature is the most under-marketed feature.** This isn't a contradiction of the brand voice (no need to say "AI" — just say "snap a plate"); it's a contradiction of the *product surface* that the data says wins.

**Contradiction #6 — The lesson reader exists in two parallel implementations.** `JeniMethodRitualView` is what `PlanView.swift:213` routes lesson taps to today, but the new `LessonReaderView.swift` + `CBTCurriculumService` + `LessonManifest` + `LessonAnchor` system has been built (the untracked files in git status confirm this is mid-migration). Until the migration completes, the in-flight surface is the *old* 14-lesson `LessonID` system — meaning the production product is still capped at 14 lessons of content while the engineering work for 84 is sitting cold. **The cognitive-endpoint moat the strategy doc identifies is gated on this migration shipping.** Every day this sits untracked is a day of strategic delay.

### A.3 What 12% D1 retention is telling you

It is **not a PMF problem in the binary sense.** A pure PMF disaster would be 0% paywall conversion or 1% activation on the food rail. JeniFit has 12.5% paywall conversion (above the 13.7% H-and-F median when corrected for the TikTok cohort skew) and 92% food-rail completion when it's offered. The economics work *for the users who get to the food rail*. So this is not "the product doesn't fit anyone."

It is **a three-part Day-1 hook problem** layered on top of a **wrong-promise install** problem. Decomposed:

1. **The install promise** (TikTok ad → App Store screenshot → onboarding hero) is currently misaligned with the product reality. 92% of TikTok #FoodNoise content promotes GLP-1RAs, meaning the cohort lands on the App Store page with *the GLP-1 frame in their head*. Onboarding then asks 50+ questions, much of it about workouts (`OnboardingView.swift:691-825` — `jfQuestion` and `jfMulti` screens cover body focus, session length, movement baseline). The promise drifts. **First Day-1 leak: ~30% of installs decide in the first 90 seconds this isn't the GLP-1-adjacent product they hoped for.**

2. **The Day-1 ritual asks too much before showing the magic.** The most engaged feature (food scan) is row 2 of 5 on PlanView, not the first thing she does. The first thing she does is open a lesson — which is good for retention but doesn't deliver the *visceral magical moment* a Cal AI install gives in the first 60 seconds (camera → result). **Second Day-1 leak: ~30% of installs don't get to the "wow, it knows my dinner" moment in Session 1.**

3. **Weight is not captured at onboarding completion, so Day-2 Becoming is empty.** Per the strategy doc Day 0-7 sequence and your own memory `[[project-trial-week-notifications]]`, "first weight logged at onboarding completion" is load-bearing. Inspecting the code, the AppStorage key `userBaselineSeconds` is plank-baseline, not weight-baseline. Weight is collected somewhere in onboarding but the Becoming tab on Day 1 has nothing to draw a trend through — making the entire data-led story flat for the first 7 days. **Third Day-1 leak: she returns Day 1, opens Becoming, sees thin data, no progress story, doesn't return Day 2.**

**This is not a PMF problem. This is a Day-1 *narrative* problem.** PMF exists at the conversion data (12.5% paywall conversion, 92% food capture). The narrative scaffold that gets her from install to that PMF moment is broken in three structural places. All three are fixable in Sprint A.

---

## B. The cultural-shift translation — what "GLP-1 / food-noise" register means for the product

### B.1 The cultural shift in one paragraph

The cohort has been told for 18 months — by every TikTok creator they follow, every ad they see, every "I lost 35lb on Ozempic without trying" testimonial — that weight management *should feel automatic, quiet, and internal*. The promise of the GLP-1 era is **subtraction of food noise**, not addition of willpower. The 2010s diet-culture vocabulary (crush, shred, burn, deficit, willpower, earn) is now culturally toxic: it markets the *opposite* of what the cohort is looking for. The cohort is buying *quietude.* Apps that scream are losing apps. Apps that whisper are winning apps.

This is also why MFP's "progress over perfection" 2025 pivot worked: they removed the panopticon vocabulary while keeping the tracking. The cohort wants to track, but doesn't want to be tracked-at.

### B.2 Product surfaces that should exist but don't yet

**Five missing surfaces, in priority order:**

**1. The Day-1 magical-moment surface.** Currently nonexistent. Cal AI's install flow → camera → first scan happens inside 90 seconds. JeniFit's install flow → onboarding (50+ screens) → paywall → Home → checklist row 2 → camera → first scan can take 6+ minutes. **Build:** an "snap your last meal now" beat at the end of onboarding, *before* the paywall. She lands on a camera screen with copy "show jeni what today looked like — 8 seconds." That single capture becomes her first Becoming data point AND the implicit demonstration of the product's wedge. *No additional surfaces needed — re-route the existing CaptureFlowView into the onboarding completion arc.*

**2. The "food noise" ambient surface.** Currently nowhere in the product. The vocabulary appears in onboarding question copy and lesson titles, but there is no *recurring surface* where the cohort sees JeniFit naming the actual psychological phenomenon they're paying to suppress. **Build:** a Becoming module — "your food noise today" — that surfaces patterns from her logs (which meals she hesitated on, where her "fits" copy landed, which evening cravings repeated). This is the surface that the *correction flywheel* eventually populates. Ship the surface first, even with sparse data, so the framework exists.

**3. The "tomorrow resets" daily fresh-start surface.** PlanView's checklist resets at midnight implicitly, but the cohort never sees the *reset moment* named. **Build:** a 9pm-or-onAppear-after-midnight beat: "tomorrow's a new page, *friend*. ♥" with a soft fade-in of tomorrow's lesson preview. Frames the day as discrete, kills the streak-anxiety pattern preemptively, embodies the post-Ozempic "you don't have to be perfect, you have to come back" frame.

**4. The "satiety check-in" surface.** This is the cohort's actual mental loop ("am I hungry or just looking for noise to suppress?") — and no app currently has a clean read on this. **Build:** a 2-tap satiety-pulse pill on the food capture result card. Before "log it," she answers "was this *hungry* or *meh*?" — two pills, one tap. Builds the dataset for the cognitive-endpoint claim, costs nothing in dev time, and embeds the vocabulary into the daily loop. **This is the non-obvious move that competitors will not ship in 18 months because none of them are working with the post-Ozempic vocabulary at the daily-loop layer.**

**5. The "anonymous sister cohort" surface (already in strategy doc Pillar 4.4).** Validate via Q3 beta as planned. The cultural shift makes this *required* eventually — the cohort treats privacy + anonymity + women-only as table stakes, not premium. Skip the public leaderboard mistake competitors are still making.

### B.3 Surfaces secretly in the old "labor culture" register

Eight surfaces to retire or reframe. File paths cited.

**1. `PlanRow.swift` — the workout row's "tier" badge.** "Soft / medium / hard" tier vocabulary is borderline-labor language. "Hard" tier is locked-but-visible per `[[project-program-pivot-v1-1]]` — but visibility of "hard" as a future state is *aspirational labor*, not aspirational quietude. **Reframe:** "this week's session," not tier badge. Move the difficulty to a quiet 1-line subtitle, not a chrome element.

**2. `PostSessionView` (`Views/PostSession/`) — quality score + hold time + streak.** The post-session screen historically shows StatCards with hold time + streak. This is the most labor-coded surface in the app. The hold-time card is the artifact of the legacy plank-app era. **Reframe:** remove the streak (per anti-priority in strategy doc), keep hold time as "today's plank time" *only if* it appears in a Becoming card, not as a session post-screen badge.

**3. `OnboardingView.swift` workout-question chain (cases 691-825 + body focus + session length).** ~6 screens of onboarding ask about workouts before the diet-first frame is fully established. **Reframe:** move workout questions to *after* the food-relationship + GLP-1 status questions. The first 8 questions should establish she's a food-noise cohort, not a workout cohort. The data will populate `WorkoutGenerator.Input` either way — order is design choice, not engineering constraint.

**4. The paywall headline personalization** (`PaywallView.swift:47-92`). Personalizes off `bodyFocus` (a workout-app variable). **Reframe:** personalize off food-relationship + GLP-1 status + prior-attempts. "Three diets that didn't work. *one* approach that does. ♥" is in-register; "Stronger core in 30 days" is out-of-register.

**5. The "weighIn" prescription** (`PlanView.swift:761`). The word "weigh-in" itself is on your own banned list (`feedback_post_ozempic_vocabulary`). **Reframe:** "today's number" or "trend update" — and unhide it from Sunday-only.

**6. `JeniMethodTodayCard.swift` (referenced via `Camera/`) — the legacy "today's lesson" card.** The whole `JeniMethod*` naming is internally consistent but **publicly contradicts the strategy doc's framing.** The user-visible name should never reference a "method" (labor framing — "follow my method"). **Reframe:** "today's reading" or "today's note" in user-visible copy, "JeniMethod" stays internal for the LessonID enum + filenames.

**7. Streak-related state.** Per anti-priority list, daily streak is dead. Audit for residual streak surfaces. The `RetentionNotifications.recordShownUpDay` path (`PlanView.swift:1028`) is a "shown up day" counter — verify this isn't surfaced as streak language anywhere. The internal counter is fine; the UI label is the risk.

**8. `BuildingPlanLoadingView` + onboarding "analyzing" %.** The animated % progress reads as labor-aesthetic ("computing your plan") even though the brand wants quietude. **Reframe:** silent serif text fade-ins of identity statements ("food noise is real. you're not making it up.") instead of % progress. Keep the bridge screen; change its register.

### B.4 What "automatic, quiet, internal" implies for the daily loop

**Home screen:** today's note (lesson preview, 1 sentence) → snap a plate (the daily anchor, photo-first, biggest tile) → everything else collapsed below the fold or hidden behind tap. Workout becomes a card that *appears* on workout days, not a row that exists every day. Steps becomes ambient (number in a pill, not a row). Breathwork becomes a contextual offer ("looks like a hard day — *breathe* for 60s?") not a row. **The checklist as architecture must die in v2.** The mental model of "5 daily tasks" is itself labor-coded. The replacement is "today's *one thing* + ambient context."

**Daily loop:** open → see today's note (1 tap → read, 1 min) → snap dinner (1 tap → capture, 8 sec) → close. That's the whole loop. Workout is an *occasional* surface. Steps is *passive*. Weight is *Tuesday-and-Friday ritual*, surfaced contextually.

**Push notifications:** never "you missed your workout." Always anchored to her data + the vocabulary: "your tuesday — *fits*. ♥" "the plate you logged yesterday was protein-leading." "tomorrow's reading is about the all-or-nothing trap. wanted you to know." **The notification IS the product surface for the user who didn't open the app that day.** The strategy doc has the right framework here (4.1 Day-1-7 sequence) — ship it.

**First 48h:** install → onboarding → first-snap-before-paywall → paywall → in-app modal at trial start ("log your first food. 8 seconds.") → first lesson at T+2h push → weight prompt at Day 1 10am → Day 1 6pm dinner snap → Day 2 "almost done" modal. Five touchpoints, all conditional on her own data, all in-voice.

### B.5 Cal AI / Noom / MyFitnessPal — what JeniFit can and can't win

**Cannot win:**
- **Cal AI's calorie-photo-counting speed/accuracy.** Cal AI has 4 years and $10M+ in AI infra investment. JeniFit can close to 80% of the accuracy gap (via the correction flywheel, GPT-5 + Claude fallback, USDA grounding) but cannot win on raw scan speed. Don't try.
- **MyFitnessPal's food database.** 14M items. Game's over. Use OpenFoodFacts + USDA + lean into the *correction flywheel* (her food, not their database) as the wedge.
- **Noom's clinical credentialing + coach human relationship.** Cannot match coach economics. Don't try.

**Genuinely defensible:**
- **The brand register.** None of them can copy it; their existing brand affect prevents it. Cal AI's UI is utility-coded. Noom's UI is clinical. MFP's is utilitarian. **JeniFit is the only one in the category that reads as a magazine.** Defensible until at least 2028.
- **The post-Ozempic vocabulary stack.** No competitor has shipped "food noise" / "tomorrow resets" / "permission" / "fits" as a *coherent product language* — they have it in marketing copy, never in the daily loop. JeniFit can.
- **The cognitive-endpoint claim** (per Pillar 2.7 in strategy doc). Noom *could* claim this but never has. JeniFit can if the curriculum ships.
- **The sister-cohort SKU** (per Pillar 4.4). Strategy doc is right: trust required to make voice-only women-only cohorts safe is brand-specific. The aesthetic carries the trust.

---

## C. The product roadmap to $100k/month MRR

Current: $4,400/mo. Target: $100k/mo. That's a **22.7x lift.** Decomposed:

- If ARPU stays $48 blended: needs ~26,000 active paying subs. Currently ~92 paying (assuming $4,400 / $48 ÷ ~1 = ~91). That's a **285x sub count lift** at current ARPU. Implausible in 12 months on TikTok organic alone.
- More realistic split: **5x sub count + 4.5x ARPU = 22.5x.** Sub count via conversion lift + retention lift; ARPU via higher anchor + Premium tier + sister-cohort SKU.

So the strategy doc's math is right and the path is **conversion + ARPU**, not "buy more installs." Three honest sub-targets:

| Lever | Current | 12-mo target | Driver |
|---|---|---|---|
| Paywall → trial | 6% blended | 14% | Sprint A |
| Trial → paid | ~25% (early) | 35% | trial-end reframe + price anchor |
| D90 retention | ~5% | 15% | curriculum + nudges + plateau intervention |
| Blended ARPU | $48 | $180-220 | Sprint D Premium + sister-cohort SKU |

### C.1 Sequenced 30/60/90 changes

**30 days — Sprint A: TRIAL CONVERSION + DAY-1 NARRATIVE**

The strategy doc has Sprint A (trial-conversion) right; add the **Day-1 narrative fixes** I diagnosed in §A.3. Sequence:

1. **(P0, 2 days dev) First-snap-before-paywall.** Inject CaptureFlowView at end of onboarding, before the paywall. **WHY:** closes the 90-second-magic gap, primes her with one data point so Day 2 Becoming has something to show. **HOW:** new onboarding screen at end of `OnboardingView.swift` flow → present `CaptureFlowView(...)` → on dismiss, route to paywall. The food log is the first row in her account. **MEASURE:** D1 retention (target +6-10pp), paywall → trial conversion (target +3-5pp).

2. **(P0, 1 day) Daily weight prompt.** Remove the Sunday-gate at `PlanView.swift:761`. Surface weight as a contextual prompt on PlanView when no log exists today (small inline card above the checklist on alternating days, not a row). **WHY:** unlocks Becoming's trend math, the strategy doc Day 0-7 sequence, the plateau intervention. **HOW:** add `hasLoggedWeightToday` check + conditional inline pill. **MEASURE:** weight-log rate (target 40%+ Week 1), Becoming engagement.

3. **(P0, 4 hours) Day-0/1/2/3 notification sequence.** Per strategy doc 4.1. **MEASURE:** trial → paid lift, D7 retention.

4. **(P0, 2 days) Day-2 "almost done" modal + Day-3 trial-end emotional reframe.** Per strategy doc 5.1. **MEASURE:** trial → paid, late-cancel rate.

5. **(P1, 1 day) US-only price anchor A/B + 7-day trial A/B.** Per strategy doc 5.2. **MEASURE:** US paid-conversion gap.

6. **(P1, 4 hours) Drop weekly SKU from primary paywall.** Keep as winback. **MEASURE:** annual share, ARPU.

7. **(P1, 2-3 days) Cancellation-intent winback.** Per strategy doc. **MEASURE:** churn-save rate.

8. **(P2 — non-obvious) Satiety check-in pill on capture result card.** 2 tap "hungry" or "meh" choice before "log it." **WHY:** builds the dataset for the cognitive-endpoint claim, embeds vocabulary, costs 4 hours of dev. **HOW:** add a `SatietyState: hungry/meh` field to `CapturedFood` + 2-pill row above primary CTA on `ResultCard`. **MEASURE:** capture completion rate (verify no drop), data accumulation for Becoming "your food noise" module in Sprint D.

**Net dev: ~10-12 days serial, 7-8 days parallelized.**

**60 days — Sprint B: CURRICULUM (parallel) + HOME RESHAPE**

The strategy doc's Sprint B is right (curriculum), but I'd add a **second concurrent track** — the Home reshape can't wait until after curriculum, because the curriculum hero needs a home to land in.

1. **(P0, parallel track) Curriculum authorship.** Per strategy doc Sprint B. **Ship the existing manifest-driven LessonReaderView migration first** (untracked files in git status). This is gating cognitive-endpoint claims by virtue of the lesson cap.
2. **(P0, 5 days) Home reshape from checklist to hero+ambient.** Promote snap-meal to hero tile (2x height, polaroid of last meal, today's running protein/kcal as the big number). Demote workout to a card that appears 3x/week (not daily row). Make steps an ambient pill. Make breathwork contextual. Keep lesson as the first row but make it visually quieter than the food hero — the lesson is the *opener*, the food is the *anchor*. **HOW:** restructure `PlanView.checklistCard` from uniform `PlanRow` ForEach to a 3-zone layout (today's reading at top, food hero in middle, ambient pills below). **MEASURE:** food-rail engagement (target 60%+ Day 1), workout-row engagement (verify no drop because users actively wanting workouts will still find them).
3. **(P1, 3 days) Plateau intervention surface (Day 21).** Per strategy doc 4.2. **MEASURE:** D21-28 churn delta.
4. **(P1, 2 days) Voice-only sister-cohort beta invite to top-D30 retained.** Per strategy doc 4.4 validation path. **MEASURE:** WTP survey, retention multiplier.

**Net dev: ~15 days serial, ~10 days parallelized + curriculum authorship in parallel.**

**90 days — Sprint C: SAFETY FLOOR + RETENTION ENGINE + CORRECTION FLYWHEEL START**

1. **(P0 — strategy doc names this a release blocker) Injury-screen onboarding floor.** Per strategy doc 3.1. Real reportable-harm risk + GLP-1 cohort RT-floor enforcement. **MEASURE:** onboarding completion (target neutral; mitigations: render as her75 pills + prefer-not-to-say defaults).
2. **(P0, 7 days) DPP scheduled-nudge engine.** Per strategy doc 4.3. The chatbot replacement. **MEASURE:** notification opt-out rate (target <8%), D30 retention.
3. **(P1, 10-12 days) Correction-flywheel schema + repeat-meal cache.** Start the moat. **MEASURE:** scan-correction rate, cache-hit latency.
4. **(P2, 3 days) Becoming food-journal "your jeni knows" module.** Surface top-10 repeat meals with personalized kcal. Visualizes the correction flywheel for the user. **MEASURE:** Becoming engagement.

**Net dev: ~25 days serial, ~18 parallelized.**

### C.2 Top 3 must-ships

1. **First-snap-before-paywall.** Closes Day-1 narrative gap, primes Becoming, demonstrates the wedge inside onboarding. ~2 days dev, projected +6-10pp D1.
2. **Curriculum migration to manifest + ship Weeks 1-4.** Unlocks the cognitive-endpoint moat. Ships 28 lessons by Day 45. The cap is the bottleneck on the only structural moat besides correction flywheel.
3. **Home reshape from democratic checklist to opinionated hero+ambient.** Makes the most-engaged feature (food rail) the visual anchor. Demotes workout from hero-by-default to occasional-card. ~5 days dev.

### C.3 The top thing to STOP doing

**Stop treating the workout rail as the default daily action.** It is 11% completion. Every product decision that defends the workout's visual real estate is *defending a 2024 plank-app artifact at the cost of the 2026 diet-first program*. The workout rail stays in the product (parity per strategy doc 8.6) but stops claiming the default surface. The strategy doc names this as Pillar 1.2 ("Workout-first identity exits") and Pillar 3.3 ("defer plank coach v2") — but the *currently shipping checklist* in PlanView still treats workouts as a daily row equal to food. Ship the Home reshape (above) to actually execute the Pillar 1 decision.

### C.4 The non-obvious PMF move

**Ship "satiety check-in" as a 2-tap pill on the capture result card *immediately* in Sprint A.** Total dev: 4 hours. Total UI footprint: one row of two pills above the existing "log it" CTA.

Why this is non-obvious:
- It doesn't appear in the v2 strategy doc.
- It looks like a small data-collection feature, not a wedge.
- The founder's instinct will be to wait for the Becoming "your food noise" module to ship first.

Why it's high-leverage:
- It introduces the **only product language no competitor has** at the *daily loop layer* (not just marketing).
- It builds the dataset for the cognitive-endpoint claim *before* the curriculum ships.
- It embeds permission-frame thinking in the user's habit (every time she captures a meal, she's prompted to ask "was I hungry"). That is **the literal behavioral intervention** the strategy doc names as the wedge.
- It's the surface that makes the eventual "your food noise today" Becoming module possible — without it, you have no input data for that module.
- It costs nothing if it fails (just remove the row).

**This is the kind of move that is small in code, large in product-meaning.** Ship in Sprint A.

---

## D. The single most defensible product moat

**The Cognitive-Endpoint Vocabulary Loop.**

A single feature defined as: every interaction the user has with JeniFit, from capture to lesson to Becoming, names a *specific psychological state* in her own vocabulary, logs her answer, and surfaces patterns back to her over time. The endpoint is **a user who has been re-trained to think about food in the post-Ozempic vocabulary** — and JeniFit owns the dataset that proves she's been re-trained.

**Concrete spec for designer + 1 engineer in a week:**

The loop has 4 touchpoints:

1. **Capture-time satiety pill** (4h). On `ResultCard`, before "log it," 2 pills: "hungry ♥" / "meh." Saved to `CapturedFood.satietyState`. Already part of Sprint A above.

2. **Capture-time "fits" verdict pill** (4h). On `ResultCard`, after kcal range computed but before "log it," show "this *fits* today ♥" with one-tap accept. If she taps it, the log gets a `userVerdict: .fits` flag. **This is the explicit moment where the user practices the permission-frame voice.** Already exists conceptually in the strategy doc copy ("this is around N — fits") — promote it to a *tracked event* not just copy.

3. **End-of-day journal one-liner** (1 day). At ~9pm local, push: "one word for today's food brain? *quiet · loud · hungry · numb · easy.*" 5 pills, 1 tap, logged to a `DailyFoodBrainState` record. The vocabulary builds the cohort's own taxonomy of food-noise states.

4. **Becoming "your food noise" weekly summary** (3 days). A new module pulling from the above 3 data sources, showing patterns — "your *quiet* days had ~28g more protein," "evenings ran *loud* this week, mornings ran *easy*." **This is the moment the user sees herself in the brand's vocabulary, with real data. This is the cognitive-endpoint instrument.**

Total dev: ~5-6 days for engineer 1 + ~3 days design work + lesson-content tie-ins.

Why no competitor will ship this in 18 months:
- Cal AI's brand voice prohibits "your food brain ran *loud*" copy.
- Noom would frame it clinically ("emotional eating episodes detected").
- MFP cannot retrofit the vocabulary; it'd alienate their 200M-strong installed base.
- The *meaning* of the words ("loud" / "quiet" / "fits" / "easy") is set by JeniFit's accumulated voice work. A new entrant would have to do 12 months of brand work to land them.

**This is the moat.** Sprint A ships pieces 1+2. Sprint B ships piece 3. Sprint C ships piece 4. By Day 90, JeniFit owns the only daily-loop instantiation of the post-Ozempic vocabulary in the App Store category — and the dataset that supports the marketing claim *"women who used JeniFit for 12 weeks reported food-noise reduction of N% (measured against their own Day-1 baseline)."* That is the wedge stated as a data claim, and it is unblockable by anyone in the category.

---

## E. Risks to flag

### E.1 Product moves that would BREAK the brand voice if shipped wrong

1. **Streak system, leaderboards, comments.** Anti-priorities in strategy doc. Easy to slip in under "engagement" framing. The brand dies the moment any of these ship.
2. **"AI" word reintroduction.** Even in legal disclosures. Use "vision models from [provider]" per the memory rule. The first user-facing "AI" string and the cohort's trust evaporates.
3. **Before/after photography in the App Store or in-app.** Locked. TikTok-policy + post-Ozempic moderation + brand voice all forbid. If anyone proposes adding a "transformation gallery" or "before photo," kill on sight.
4. **A chatbot UX framed as "talk to Jeni."** Even if it's actually scheduled nudges underneath. The frame is the problem, not the implementation. Strategy doc 4.3 is right: scheduled nudges, not chat.
5. **Calorie math precision claims.** "Within 5%!" type marketing language. The brand sits in the permission-frame space; precision claims violate that space and invite the Cal AI litigation precedent.
6. **Streak-loss notifications, "you missed N days," guilt-cascade copy.** Documented retention killer. Easy for an inexperienced PM to add as "re-engagement."
7. **CGM / wearable integration before the brand has scale.** Fragments cohort. Pulls focus from the cognitive-endpoint moat. Strategy doc names these as anti-priorities.

### E.2 Anti-femvertising vs commercial viability tension

The tension is real but manageable. Here's where it bites:

**Where it bites:**
- **Paywall persuasion copy.** The cohort allergy to "transform your body" is real, but the cohort still buys outcomes. The bridge is the post-Ozempic vocabulary: "*quieter* mornings, *easier* dinners, *fits.*" Quiet outcomes, not loud transformations.
- **Push notifications.** Anything that smells like comparison or scarcity gets opted-out instantly. Use the user's own data anchors only.
- **App Store screenshots.** The 6 screenshots are the cohort's first product-truth moment. The font has to be Bodoni/Playfair-class serif, the copy lowercase casual, the imagery editorial cutout (per `feedback_visual_richness_over_restraint`). Screenshots designed by a generic mobile-marketing agency will tank conversion. **This is where JeniFit will be tempted to compromise the most for measurable lift.** Don't.
- **Onboarding question copy.** Every "what's your goal weight?" question must be in-register. The drift to "how much do you want to lose?" — a labor-coded framing — would tank brand trust at scale.

**Where it does NOT bite (commercially viable in-register):**
- Hard paywall after onboarding. (Locked.) The brand voice doesn't require a soft paywall.
- 3-day trial → annual conversion. Brand voice and trial structure are independent.
- $59-89 ARPU. The brand voice supports premium pricing; quietude reads as premium.
- Sister-cohort SKU at $79-99/quarter. Premium-priced women-only voice cohorts are *more* in-brand than a generic $9.99/mo. Premium pricing IS the brand at scale.

**The rule for adjudication:** when a commercial choice has a voice-compliant version and a voice-violating version with measurably higher lift, ship the voice-compliant. The brand IS the moat; lift that comes from breaking it borrows from future LTV.

### E.3 The Cal AI moat risk — can JeniFit close the food-rail gap fast enough?

**Yes, with one caveat.** Cal AI was pulled from the App Store in April 2026 (per strategy doc Part 1.3) and sold to MFP, who sold to Francisco Partners. **The category-leader incumbent is in a 12-18 month integration freeze.** This is the structural window that makes the v2 strategy possible. If Cal AI relaunches or MFP integrates faster, this changes.

**JeniFit's food-rail trajectory:**
- **Today** (v1.0.9): solid pipeline (GPT-4o, USDA fallback, structured outputs, cohort catalog). 36% MAPE per strategy doc.
- **Sprint A end** (Day 30): GPT-5 + Claude Opus 4.7 fallback, hidden-ingredient enumeration, reference-object detection. ~22% MAPE.
- **Sprint D end** (Day 180): correction flywheel + repeat-meal cache + pgvector NN. **Per-user-personalized MAPE approaches 10-15%** on her repeat meals. Cold-start MAPE stays ~22%, but cold-start is a smaller and smaller fraction of her usage.

**The Cal AI gap:**
- Cal AI's MAPE on raw scans is ~25% per published benchmarks (PMC head-to-head 2026). JeniFit's Sprint D state is comparable on cold-start, **better on repeat meals** (the bulk of usage after Week 4).
- Cal AI's scan speed is ~3s p50. JeniFit currently runs ~5s p50; with repeat-meal cache, cache-hits drop to <300ms. **JeniFit's experience can be *faster* than Cal AI's for the user's actual diet, because most users eat 8-12 distinct meals on repeat.** This is the killer architectural insight.

**Risk if Cal AI relaunches in <12 months:**
- The "Cal AI is dead" framing in marketing dies. JeniFit's wedge against Cal AI shifts from "the working alternative" to "the brand alternative." Less commercial leverage, but the brand-register wedge is still defensible.

**Mitigation:** ship the correction flywheel by Day 180 regardless of Cal AI's status. The moat is "JeniFit knows YOUR pad thai," and that's true whether Cal AI exists or not.

---

## F. The one-paragraph summary

JeniFit's PMF problem is not a product-fit problem; it's a **Day-1 narrative + visual-hierarchy problem** layered on a strong brand-register foundation. The food rail is the engaged feature; the workout rail is the under-engaged inherited feature; the curriculum is the cognitive-endpoint moat that is *built but not yet shipped* because the lesson cap is still 14 and the manifest migration is in flight. The 30-day move is Sprint A trial-conversion plus a **first-snap-before-paywall** + **daily weight prompt** to close the Day-1 narrative gap. The 60-day move is **Home reshape from democratic checklist to opinionated hero+ambient** plus the curriculum migration to ship Weeks 1-4. The 90-day move is the **injury-screen safety floor** plus the **DPP nudge engine** plus the **correction flywheel start**. The non-obvious move that compounds everything is the **satiety / fits / food-brain vocabulary loop** — 4 surfaces, 5-6 dev days total, the only daily-loop instantiation of the post-Ozempic vocabulary in the category. The risk floor is brand-voice integrity; every commercial choice has a voice-compliant version and the team must always pick it. The window is Cal AI's 12-18 month integration freeze; ship the correction flywheel inside that window and the moat compounds for years.

The path to $100k/mo MRR is **5x sub count + 4.5x ARPU**, executed via the v2 strategy doc's 5 sprints, with the §C additions above. Sprint A is the only thing on the board right now; everything else waits its turn.
