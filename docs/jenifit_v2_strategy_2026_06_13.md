# JeniFit v2 Strategy — From Launch to Category Definition

*Synthesis of 5 parallel expert lanes, 2026-06-13. Audience: founder + future eng team. Reads top-to-bottom in ~25 minutes. Section anchors for skimming.*

---

## TL;DR

JeniFit's v1.0.9 ships a credible, well-designed weight-loss program for women 22-35, but the early signal — 3-6% paywall→trial vs Health-and-Fitness median ~13.7%, 23% workout completion vs 75% lesson completion, US converting 7-14% while PH/SG/UK hit 33-100% — says the same thing the audience research lane says: **the product is positioned as a workout app while the audience clicked an ad for a diet-first weight-loss program.** The 30-day work is closing that gap. The 90-day work is shipping the cognitive-behavioral curriculum (84 days, CBT-spine) that turns a tracker into a brain-rewiring program. The 12-month work is shipping the sister-cohort SKU that gives JeniFit Noom-class retention without Noom-class coach economics.

**The strategic wedge in one sentence:** JeniFit becomes *the behavioral version of what GLP-1s do to food noise* — the credible non-prescription protocol for women 22-35 whose food brain is the disease and the scale is the symptom.

**The five non-negotiables of v2:**

1. **Positioning pivots from workout-first to diet-first.** Already in flight per v1.1; the strategy below completes it.
2. **The CBT 84-day curriculum becomes the hero of the product**, not a side rail. Workout becomes one of five daily ritual rows; food + lesson lead.
3. **Calorie scanner accuracy becomes the moat through user-correction flywheel**, not raw model swapping. Every correction makes the next scan better for everyone.
4. **Safety-floor injury screen at onboarding** is a P0 release blocker for v1.1.x. We will hurt someone otherwise.
5. **No "AI" word, no chatbot, no streaks, no shame.** The brand voice rules from v1 hold and become the moat in their own right.

**The single highest-leverage 30-day ship:** the in-trial Day-1/2/3 notification + reframe sequence, combined with the US-only 3-vs-7-day trial A/B, three CPP variants, and a $34.99/$47.99/$59.99 price-anchor test. Expected lift: +15-35% relative trial-to-paid, with US closing 30-50% of the gap to PH/SG/UK. Total dev time: ~6-8 working days.

---

## Part 1 — Honest current state

### The good

- **Engine architecture is research-grade.** Workout-session rules doc enforces position-block ordering (vestibular adaptation), L/R balanced pairing, exercise-aware rest mini-factors, and difficulty caps per tier. Most consumer competitors hardcode 15s rest blocks. JeniFit doesn't.
- **`ProgramGoalCalculator` already encodes three cohort modifiers** (GLP-1/perimenopause floor at 0.3%/wk, short-sleep penalty per Nedeltcheva 2010, Wing-and-Phelan default at 0.5%/wk). More nuanced than Cal AI or BetterMe expose.
- **Food vision pipeline is built right.** Strict JSON Schema, cohort catalog of chain items (Chipotle, Sweetgreen, Crumbl), USDA grounding fallback, structured outputs, telemetry budget caps. The architecture supports the v2 flywheel without rewrites.
- **Data sync is solid** (all 8 record types store+retrieve+isolate per the 2026-06-12 audit). The program plan and checklist state sync, so a reinstall fully recovers an enrolled user.
- **Brand voice and design system are uncopyable** in a 6-month sprint. Her75 editorial register (Bodoni/Playfair-class serif + italic-fraunces punch), lowercase casual, hearts as terminal punctuation, no-AI lexicon, post-Ozempic vocabulary — competitors' design systems are too far gone to retrofit this taste.

### The leaks

| Surface | Current | Median | Gap |
|---|---|---|---|
| Onboarding completion | 88% | 75-85% | Above median |
| Paywall → trial start | 3-6% | 13.7% H-and-F | **Below median by 2-4x** |
| Trial → paid | unknown (early signal) | 25.5% (3-day), 45% (5-9 day) | TBD |
| Workout completion | 23% | n/a | Cohort doesn't want workouts as hero |
| Lesson completion | 75% | 25% (self-help median) | **Best-in-class.** Lessons want to be the hero. |
| Weight logging | near-zero | 60-80% on Day 1 in WL apps | **Critical leak.** Day 0 weight is load-bearing for trend math. |
| D90 retention | unknown | 5.1% H-and-F US iOS | category baseline is rough |
| US trial-start | 7-14% | regional median | half of APAC |
| US paid conversion | very low | category n/a | the gap to close |

### The category context

- **Cal AI was pulled from the App Store in April 2026** over deceptive Stripe billing. Cal AI sold to MFP. MFP sold to Francisco Partners. The consolidation tier is busy integrating, not innovating, for the next 12-18 months. **This is a window.**
- **GLP-1 vocabulary mainstreamed** (food noise, satiety, permission, fits, tomorrow resets). The cohort moved with the language; the apps haven't caught up.
- **Anti-diet pushback has hit but not flipped the market.** MFP's 2025 "progress over perfection" pivot is the proof that the cohort wants tracking *without* the panopticon — but they still want tracking.
- **Noom's wedge is human coaches** (43.6% D30 retention; the only WL app in the 40%+ club). JeniFit cannot match coach economics, but can match coach *effect* via a sister-cohort SKU and DPP-style scheduled text nudges. See Pillar 4.
- **Honest pricing is now a feature.** Cal AI's cancel-flow hostility + billing complaints created reputational headroom for an app that bills cleanly.

---

## Part 2 — The strategic frame

### North star

The single number JeniFit optimizes for in v2: **D365 paying retention × cohort completion rate × NPS.** This is the only metric that combines (a) does she stay, (b) does she finish, (c) does she tell people. A WL app that wins one of three loses; winning all three is the category.

### Short-term goal (90 days)

- Lift paywall → trial start from 3-6% to **12-15%** (matching the H-and-F median).
- Lift D7 activation rate (≥4 logs + ≥1 weight) to **60%** of trial starters.
- Bring US paid-conversion within 30% of the PH/SG/UK band.
- Ship the 28-day curriculum (Weeks 1-4) live in the product by Day 60.
- Ship injury-screening floor by Day 60. (P0 safety release blocker.)

### Long-term goal (24 months)

JeniFit owns the women-22-35-weight-loss App Store category along three dimensions Noom, MFP, Cal AI, and BetterMe cannot collectively match:

1. **The cognitive-endpoint moat.** A JeniFit graduate believes specific things about her food brain that no tracker user does. The curriculum is the only place this belief is built. Section detail in Pillar 2.
2. **The correction-flywheel moat.** Every food scan correction becomes both a personalized prior for the user and an aggregate prior for everyone. The third pad thai scan is the user's pad thai, not a model's guess. Cal AI's architecture can't ship this without a rebuild.
3. **The sister-cohort moat.** Voice-only, women-only, opt-in cohorts of 6-12 going through the same custom program. Builds Noom-class accountability at 1:50 moderator economics. Section detail in Pillar 4.

By month 24: $150-220 blended ARPU (from $48 today), 18-22% D90 retention (from category 5%), top-decile Net Sentiment in App Store reviews.

---

## Part 3 — The product thesis (the wedge)

The audience-research lane named it: **the behavioral version of what GLP-1s do to food noise.**

The cohort split that matters: half the audience is on or considering a GLP-1 (food noise quieted by pharmacology, weight loss happening, lean mass loss the new anxiety); the other half cannot afford or refuse to take one and wants the *outcome* (food noise suppression, satiety, fewer ruminating thoughts). Both halves are buying the same emotional product: *I want my brain to stop screaming at me about food.* The pharmacological answer is the shot. The behavioral answer is JeniFit.

This positions us where every competitor is blocked:

- **MFP / Cal AI / Yazio / Lifesum** are locked to calorie math. Can't claim cognitive endpoint.
- **Noom** has the curriculum but the budget structure forces human coaches; can't drop into sister-cohort economics, can't ship the food-vision moat, won't change the brand voice to match the Gen-Z post-Ozempic cohort.
- **BetterMe / Simple** have onboarding firepower but no cognitive depth, no curriculum that endures past month 1.
- **MacroFactor** owns the adaptive-TDEE math nerd; male-coded register, will not pivot.
- **Cysterhood** owns PCOS-specific but is too niche to cover the cohort.

Three structural moats that compound, in priority order:

1. **The CBT curriculum** (Pillar 2). 84 days, cognitive-endpoint outcome, brand-voice authored, cohort-routed.
2. **The correction flywheel** (Pillar 1). User-specific food embedding store + repeat-meal cache + aggregate cohort priors.
3. **The sister cohort** (Pillar 4). The Noom-class accountability layer at SaaS economics.

Everything else in v2 is in service of these three.

---

## Part 4 — The five pillars

### Pillar 1 — The diet-first program (the daily product surface)

This is the top product priority. The Today tab's five-row ritual reorders: **lesson → food → movement → steps → breath.** Food gains the largest visual real estate. Lesson keeps its place at the top as the cognitive opener of the day.

#### 1.1 Calorie scanner v2 (3 sprints, see roadmap)

**Sprint A — Model + schema + grounding (10 days).** Per the AI lane:

- Flip `food-vision` from GPT-4o to **GPT-5 high-detail** as primary. Cost moves from ~$0.004 to ~$0.018 per scan; per-user-per-month cost moves from $0.28 to ~$0.81. Against $47.99 annual at the heaviest user, gross margin still 58%. Founder rule applies: engineering ambition over cost when AI cost is rounding error vs subscription revenue.
- Add **Claude Opus 4.7 disagreement-only fallback** when GPT-5 returns `confidence < 0.55` OR `plate_type == "mixed"` OR `needs_second_photo == true`. ~15% of scans. Blended cost ~$0.021/scan.
- Add three fields to `FOOD_VISION_SCHEMA.properties.items.properties`:
  - `portion_reasoning` (chain-of-thought-in-schema forces reasoning verbalization — 30% portion-MAPE cut per PMC literature)
  - `hidden_ingredients[]` (named array with kcal_low/high per item — forces dressing/oil/sauce/butter enumeration, the salad-undercount problem)
  - `reference_objects_detected[]` (enum: hand, fork, plate_10in, plate_8in, bowl, credit_card, iphone, none — drives the first-photo guidance "show your hand in frame for ±10% better accuracy")
- Extend the system prompt with **portion-grounding rules + hidden-ingredient enumeration + cooking-method kcal modifier** (fried +120-180, sautéed +50-100, baked/grilled +0-30).
- USDA calibration threshold 0.5 → 0.6 (more second opinions; USDA is free).
- Result-card surface: "hidden: dressing ~150 kcal" tappable chip so users can edit/remove.

**Expected lift:** MAPE 36% → ~22% on PMC-class plates; per-scan cost $0.004 → $0.021. Files to touch: `supabase/functions/food-vision/index.ts`, `Packages/PlankFood/Sources/PlankFood/Capture/CapturedFood.swift`.

**Sprint B — The correction flywheel (12 days). The moat.**

The mechanic Cal AI cannot ship without a rebuild:

```
food_corrections (
  id, user_id, scan_id,
  item_name_canonical text,           -- "pad thai" not "Pad Thai w/ chicken"
  item_embedding vector(1536),        -- pgvector
  cuisine_hint, llm_kcal, user_kcal,
  llm_portion_g, user_portion_g, delta_kcal,
  hidden_ingredient_adds jsonb,
  hidden_ingredient_removes jsonb
);

user_food_profile (
  user_id pk,
  habitual_portion_multiplier numeric,  -- 0.7 = GLP-1/restriction cohort
  habitual_hidden_oil_kcal int,
  cuisine_correction_priors jsonb,
  pantry_repeat_items jsonb             -- top-50 repeat-meal embeddings
);
```

Three new edge-function behaviors:

1. **pgvector NN lookup before LLM call.** If similarity > 0.85 against user's own correction history → inject "based on past corrections, this user logs pad thai at ~620 kcal" into the system prompt.
2. **Repeat-meal cache.** Similarity > 0.92 → skip LLM, return user's last-kept value with "you've logged this before, same numbers?" affirm tap. Zero LLM cost. <300ms latency. This is the killer UX moment.
3. **Aggregate cohort priors.** Nightly `canonical_corrections` materialized view: for each `(item_name_canonical, cuisine_hint)` with ≥50 corrections, compute median user-kept kcal. Auto-extends the system-prompt cohort catalog from 80 hand-coded items to 800+ within 6 months of v2 launch with zero analyst work.

UX surface: extend result-card "correct me ♥" pill into an inline editor; saving fires the correction row. New Becoming-tab module "your jeni knows" — top-10 repeat meals with the user's personalized kcal.

**Sprint C — Multi-modal capture (8 days).**

- **Barcode scanner: ship.** AVFoundation `AVMetadataObjectTypeEAN13Code` + OpenFoodFacts REST GET. Free, 3M+ products, no auth. Fallback to USDA FDC. Highest evidence-x-demand intersection of the founder's full feature list.
- **Voice quick-log: ship.** Whisper-3 streaming → existing `scanText` path. Zero new backend. AppIntents donation for "log food with jeni" Shortcut. Killer for driving + post-meal couch logging.
- **Supplements: ship.** DSLD (NIH Dietary Supplement Label Database) seed → Supabase `supplement_pantry` table. ~140K products. Gold-standard for supplements. Critical for the GLP-1 cohort logging Athletic Greens, protein powder, magnesium.
- **HealthKit dietary write-back: ship.** Symmetric — every food entry logs to HK. Locks in cohort, costs nothing.
- **Restaurant menu OCR: SKIP for v2.** Hard problem; existing `imOutTonight` rule-based covers it honestly.
- **Receipt scanning: SKIP.** Grocery receipts don't tell you what was eaten.

#### 1.2 Daily ritual reshuffle

The Today tab keeps five rows but rebalances visual weight:

1. **Today's lesson** (the cognitive opener — the 84-day curriculum hero)
2. **Snap a plate** (largest tile, photo-first, the daily anchor)
3. **Move** (smaller tile, optional escalation surface)
4. **Steps** (passive auto-anchor at 7,500)
5. **Breathe** (1-min Brewer/Stanford-trial breath)

Workout-first identity exits. Food + lesson lead.

---

### Pillar 2 — The CBT curriculum (the 84-day brain)

The curriculum lane delivered a production-ready spec. The summary:

#### 2.1 Thesis

> Weight loss in the post-Ozempic TikTok-trained 22-35 cohort fails because the user's relationship to food is a trauma response to a decade of comparison content, not a math problem. JeniFit treats food noise, the all-or-nothing trap, and identity-as-dieter as the *primary disease* and the deficit as a *secondary side-effect* of resolving them.

Borrows Beck's cognitive-restructuring spine, ACT's values-and-defusion middle, Brewer's habit-loop mindful-eating skill, Lally's 66-day automaticity math for the dosage, Tribole's reject-the-diet-mentality for the anti-shame voice. Packaged like Headspace's Pack architecture (one daily ritual, <2 min, illustrated, optional voice), written in the brand register.

#### 2.2 The 12-week spine

| Act | Weeks | Theme |
|---|---|---|
| I | 1-3 | Deconstruct the diet brain (meet your food brain → all-or-nothing → comparison cost) |
| II | 4-6 | Build the skills (eat like you mean it → move because it feels good → sleep+stress, the other half) |
| III | 7-9 | Rewire identity (who am I becoming → emotional eating named → the hard middle) |
| IV | 10-12 | Maintain for life (the maintenance brain → food beyond food → graduation) |

Headline samples (italic-fraunces punch as it'll render in `ItalicAccentText`):

- Day 14: *catch* and reframe (the what-the-hell effect, Polivy and Herman 1985)
- Day 21: *you weren't hungry. you were sad.* (emotion regulation through eating, Brewer)
- Day 42: *this is where the other apps lose you. we don't.* (the plateau lesson, Wing and Phelan NWCR)
- Day 70: *you are not the girl with the* problem. *you are the girl* solving *it.* (identity, Clear/Wood)

#### 2.3 Lesson architecture

Every lesson is **<500 words, <2 min, 4 pages**, 7 structural elements:

1. **Hook** (1 line — italic-punch headline, 5-9 words, earns the tap)
2. **Story** (~80 words — concrete, second-person, names a specific scene)
3. **Concept** (~90 words — CBT idea in plain English, names the technique once)
4. **Evidence** (one source, lowercase, no academic decoration)
5. **Micro-skill** (~60 words — one observable behavior today, ≤60 seconds)
6. **Prompt** (optional reflection question, logs to Becoming tab)
7. **Close** (~30 words — identity callback, previews tomorrow, 1-tap handoff)

#### 2.4 Cohort routing

Onboarding v4.5 already collects 14 cohort flags. Routing rules: **never quote numbers, never change safety language, branch headline/example, not core concept.** Three overrides max per lesson. Examples:

- GLP-1: Day 3 "food noise" leads with post-drug maintenance frame; Day 67 holidays adds under-eating note.
- Prior attempts ≥3: Days 1-2 lean harder on restart-fatigue; Day 14 frames experience as *asset*.
- Restrictive food relationship: Day 22 abundance plate gets "you're likely under-eating" note; Day 24 under-eating tax becomes mandatory.
- Roast voice preference: overridden to balanced for all 84 lessons (v1 §4.3 extension).

#### 2.5 Multi-modal layer

- **Voice note (45-90s)** opt-in tap on emotional-eating lessons (D21, D50-56), self-compassion lessons (D46, D48), graduation (D84). Jeni for identity, Kira for accountability, Sam for stoic-restraint. Cloned real voice actors via ElevenLabs; **never** "AI synthesis" in copy.
- **Breath ritual (30s circle)** on D39 box breathing, D44 inner-critic defusion, D60 bad-body-image day.
- **Workout handoff** on D5 walk-after-eat → 10-min timer; D29 movement = good → today's plan.
- **Journaling prompt** on D45 origin story, D48 letter to 14yo, D70 identity sentence, D80 future self. Logged entries become Week 12 re-read material.
- **"This was about you" data-tie** on D4 (her own EMA weight trend), D63 (her own session count + program day), D78 (her actual days-since-enrolled). Nothing fabricated.
- **Animation (3 only):** D8 dichotomous on/off switch, D50 habit-loop spiral, D78 66-day automaticity curve. Paper-craft style.
- **Scrapbook artifact** on D84 — generated PDF of her 12-week journey, ShareLink-able. The keepsake is the retention loop.

#### 2.6 Engagement mechanics

Goal: **75% of paying users complete ≥50 lessons in 12 weeks** (vs ~25% self-help median).

1. **Forward-only cadence, no catch-up debt.** Skip → next lesson waits. **No "you missed day 14" shame screen, ever.**
2. **The home tile IS the lesson** — not a button to the lesson. 1-tap open.
3. **Coach check-in after 3 days absent** — local notification, personalized by stated barrier ("day 14 is waiting — it's about the all-or-nothing trap, the one you texted your friend about"). 1/week cap.
4. **Re-read on rough days** — Becoming tab surfaces "today felt heavy. re-read this" when last weight log was up + last session was skipped + days since last lesson > 2. Routes to D9/D46/D60. 1/week.
5. **"This was about you" data-tie** — minimum 12 of 84 lessons surface her own collected data.
6. **Graduation artifact** — PDF + share, identity sentence + lesson prompts + session count.

What we do NOT do: streak-loss notifications, "your friends are ahead of you" comparison, "you're falling behind" guilt copy. All three are documented retention killers in the post-Ozempic WL cohort.

#### 2.7 The cognitive endpoint

> A JeniFit graduate believes things a BMI-app user does not. She believes her food brain was *trained*, not *broken*, and that training is reversible. She believes a slip is one slip, not a day, not a week, not an identity. She believes hunger is information and emotion is information. She believes she is *someone who eats well* (present-tense, holds under stress) not *someone who is trying to eat well* (collapses every weekend). She believes maintenance is the curriculum. She does not need a Monday.

This is the marketing claim if we can prove it via the 12-week outcome metric: *JeniFit users who completed ≥50 lessons were Xx more likely to maintain weight at month 6 than users who only completed workouts.* Noom has never published this. It is the wedge against every BMI app.

#### 2.8 Files to extend

Existing skeleton supports this without architectural change:

- `PlankApp/Views/DietEducation/JeniMethodContent.swift` — extend `LessonID` from 14 → 84, add cohort override blocks to `JeniMethodContent.resolve(lesson:user:)`.
- `PlankApp/Views/DietEducation/JeniMethodRitual.swift` — `LessonPage` + `LessonScript` model absorbs the 4-page architecture as-is.
- `PlankApp/Views/DietEducation/JeniMethodState.swift` — extend cap from 5 → 84.
- `PlankApp/Views/DietEducation/JeniMethodAnalytics.swift` — lesson_id range extends cleanly through existing 5-event taxonomy.

---

### Pillar 3 — Workout safety + effectiveness (do no harm, win on adaptation)

The PT lane's headline: **we will hurt someone without a pre-participation injury screen.** The 22-35 TikTok-acquired cohort has documented prevalence of postpartum-within-24-months (~25-30%), recurrent LBP (~80% adult women lifetime), undiagnosed hypermobility/EDS (~10-20%), prior knee injury (~15%). Serving a tier-1 user a high plank with hip-sag tendency is reportable harm.

#### 3.1 Injury-screening framework (P0 safety floor)

Insert 9-question screen in onboarding (after bodyFocus, before plan reveal). Each Q rendered as her75 question pill with empathy copy ("we ask because the plan changes if you say yes"). Skipping = "prefer not to say" = conservative defaults.

| # | Trigger | Cohort flag | Engine modification |
|---|---|---|---|
| 1 | Low-back pain last 3 months? | `lbpRecent` | Swap crunches/sit-ups/v-ups/hollow-body → McGill Big 3 (bird dog, dead bug, side plank knee-down, curl-up). Cap spinal flexion to 0/session. Add diaphragmatic-breathing warmup. |
| 2 | Had a baby last 12 months? | `postpartumRecent` | Block full plank, side plank, crunch, jump squats, burpees, mountain climbers. Allow 360° breathing, heel slides, glute bridge, modified side plank knee-down, bird dog. Add coning-check primer. |
| 3 | Pelvic-floor symptoms (leaking, heaviness, urgency)? | `pelvicFloorSymptoms` | Block all impact (jumps, jacks). Block sub-parallel squats. Add Kegel + reverse-Kegel warmup. Surface "talk to a pelvic PT" Becoming card once. |
| 4 | Joints injured last year? (multi: knee/shoulder/wrist/ankle/hip) | `injury_<joint>` | Per-joint substitution table (knee → no jump variants, sub box step-ups; shoulder → no high plank/push-ups, sub forearm plank; wrist → fists or forearms only; etc). |
| 5 | Joints feel "loopy" (bend further than others)? | `hypermobilitySuspected` | If yes → inline 4-of-9 Beighton screen. ≥3 → hypermobility profile: **remove all static stretches**, isometric only on stretching slots, add proprioceptive work. No yoga-style cooldowns. |
| 6 | Currently pregnant? | `pregnant` | Hard exit from current engine. "We don't program for pregnancy yet — here's prenatal yoga we trust" card. |
| 7 | Currently on GLP-1? | `glp1Current` | Already wired in `ProgramGoalCalculator`. ADD: minimum 2 RT sessions/wk forced; surface protein floor 1.2 g/kg in Becoming; suppress HIIT (hypoglycemia + nausea risk). |
| 8 | PCOS / hypothyroidism / perimenopause? (multi) | `pcos`, `hypothyroid`, `perimenopausal` | PCOS: bias RT over cardio (insulin sensitivity, Diabetes Care 2018). Hypothyroid: slow ramp + soft default. Perimenopause: already wired. |
| 9 | Sharp / radiating / numb pain right now? | `redFlag` | Block all programming. Medical-disclaimer screen + "see a clinician first." Do not nag, do not auto-unlock. |

#### 3.2 Workout engine v2 scientific upgrades

Concrete additions to `WorkoutGenerator.Input` and `ProgramGoalCalculator.Inputs`:

1. **`InjuryProfile: Set<ExerciseFilter>`** — load-bearing filter set from §3.1 flags. `ExerciseBank` gains `contraindications: Set<Cohort>` (squat_jump: [.knee, .pelvicFloor, .postpartum]).
2. **Resistance-frequency floor by cohort.** Extend `IntensityProfile.minResistanceSessionsPerWeek`. GLP-1 override → min 2 regardless of soft/medium/hard (lean preservation). Perimenopausal override → min 3 (sarcopenia + bone density).
3. **Progressive overload mechanism.** Replace flat `difficulty(from: tier)` with `progressiveDifficulty(tier, programWeek, recentRPE)`. Three levers: duration +5s every 2 wks within grid, reps when applicable, variation (squat → goblet → tempo → pulse). Periodize in 4-week blocks: weeks 1-3 accumulation, week 4 deload (-20% volume).
4. **Cycle-aware autoregulation, NOT prescription.** Optional `cycleSymptomCheckin: SymptomLoad?` (0-3) at session start. High load (cramps + low sleep + low mood) → tier-1 with notation "today is softer because you said you needed it." **Do not ship a luteal/follicular prescriptive engine — the meta-analysis evidence does not support it and the cohort fact-checks on TikTok.**
5. **48-hour same-muscle rule.** Read last 72h `SessionLogRecord`; apply `recentLoad` filter. Yesterday hit glutes → today biases upper or core. Invisible to user, saves them from DOMS-driven dropout.
6. **Aerobic minutes accumulator.** Derived from session category × duration. PlanView surfaces thin tracker. If <100 min by Friday, Saturday's prescription auto-flips to brisk-walk cardio.
7. **Protein cohort signaling.** `ProgramGoalCalculator.proteinFloorGPerKg(_:)`: 1.0 default, 1.2 for GLP-1, 1.4 for perimenopausal, 1.6 for hard + GLP-1 stack. Surface in Becoming, not as a calorie target.

#### 3.3 Plank coach v2: DEFER

This is the place to adjudicate the cross-lane tension. The PT lane recommends bringing the plank coach back, expanded to plank + glute bridge + squat. The audience+science lane says skip it because (a) no published evidence linking on-device form-check to weight outcomes, (b) it re-cements JeniFit as a *plank app* at the exact moment v1.1 is pivoting to a diet-first weight-loss program.

**Verdict:** the audience lane wins on strategic positioning grounds. **Defer plank coach v2 to v3+.** The PT lane's underlying recommendations on safety + effectiveness all ship (Sprint C); plank coach as a marquee feature does not, because category positioning trumps feature richness when re-positioning the brand. If by month 12 user demand validates a return, ship it then.

This is also why we resist the founder's request to bring it back: the feature is good, the timing is wrong. The 12-month window is to plant the "diet-first weight-loss program" flag deeply; the plank app brand is a 2024 artifact we are deliberately leaving behind.

#### 3.4 Weight-loss effectiveness — the honest physiology

What actually moves the scale + body composition for women in caloric deficit, ranked by evidence strength:

1. **Caloric deficit > everything else.** Hall 2012 (Lancet). Exercise delivers ~3,500-5,000 net kcal/wk at the upper end of 150-250 min/wk — about 0.5-1 lb/wk if diet holds. **JeniFit's food rail is doing more for weight loss than the workout rail.** Position the docs accordingly.
2. **Resistance training preserves lean mass during deficit.** 2024-25 meta-analyses: concurrent (RT + aerobic) beats either alone for fat loss + lean preservation. **In GLP-1 users, lean loss jumps to 25-40% of total weight without RT** (STEP-1, SURMOUNT-1). This is the most evidence-backed claim JeniFit can make.
3. **NEAT is the silent driver.** Levine 2005. Sedentary vs active difference = 300-1000 kcal/day. Steps rail (already shipped, anchored at 7,500 per Lee 2019 JAMA) is doing real work.
4. **EPOC is real but small.** 2024 meta-analyses: HIIT EPOC ~6-15% of session kcal. **Do not lean on EPOC in marketing copy.** The cohort fact-checks. HIIT is time-efficient and improves VO2max; not metabolically magic.
5. **Post-workout nutrition adherence link.** Wing-and-Phelan NWCR: workout-day diet adherence ~12% higher than rest-day. The workout's biggest WL contribution may be gating the rest of the day's eating decisions. Exploit timing.

---

### Pillar 4 — The retention engine (DPP nudges + sister cohort)

The retention lane's frame: H-and-F D90 retention ceiling is ~5% absent (a) external accountability, (b) a device hook, or (c) an early visible result. JeniFit has none of (b). It needs (a) at SaaS economics and (c) by Day 7.

#### 4.1 Day 0-7 activation sequence

The goal: by D7 she has an identity ("I'm doing JeniFit"), 4+ logs, and a result moment.

| When | What |
|---|---|
| Day 0 install | First weight logged at onboarding completion (load-bearing for trend math). Trial-start → in-app modal: "log your first food. takes 8 seconds." T+2h push: "your jeni plan is live." |
| Day 1, 10am local | Weight-trend trigger: "log your weight today and tomorrow's becoming starts moving." |
| Day 1, 6pm local | "What did dinner look like? log a photo." |
| Day 2 morning | The **"almost done" reward moment** — single screen pulling from her collected data ("you're showing up. women like you stay for 47+ days"). Adapty/Superwall +8-15% trial-to-paid. |
| Day 2, mid-day | Coach-shaped in-app note (Jeni voice), conditional on logs: "two logs in. your protein is leading. keep it loose." |
| Day 3, 7am | Trial-end emotional reframe screen (Apple-compliant 24h notice in JeniFit voice): "your trial completes at 9am. your plan continues." |
| Day 4 | "Plateau immunity" pre-loaded message: "your weight may bounce today. that's water. your trend is what counts." |
| Day 5 | Breathwork prompt (cortisol mechanism). First earned scatter sticker if ≥3 logs (extends the locked sticker-scatter milestone rule from welcome/plan-reveal/graduation). |
| Day 6 | "Ate out today?" prompt → photo → "this fits your week." Removes biggest US WL-app churn driver. |
| Day 7 result moment | Auto-generated weekly recap: weight trend bend (even if -0.2 lb), top-protein meal, plank PR vs baseline, barrier resolved. Shareable wax-seal artifact. Push 8am: "your first week of becoming." |

D7 activation threshold (Annesi 2011 self-efficacy curves): **1 weight × 2 + 5 food + 3 workout/plank logs.**

#### 4.2 Days 8-90 habit architecture

- **Days 8-14 Consolidation.** Notifications drop to 4/week. New surface "your tendencies" — adaptive insight pulled from her 7 days. **Weekly streak, not daily** (Strava model — 2.4x lower break rate).
- **Days 15-21 Identity reinforcement.** "What's different than 14 days ago?" Free-text journaling. Becoming tab adds *Words* module (past 2 weeks of reflections visible). Identity ratchet.
- **Days 21-28 PLATEAU WINDOW intervention.** 70% of WL users churn here. Pre-emptive Day 21 in-app letter from Jeni: "your scale may stall this week. that's biology. here's what's actually happening." Hormonal + water + lean mass explainer, 90 seconds. New module unlocks: "non-scale victories" — clothes fit, sleep, plank time, mood. Voluntary "want to adjust your pace?" check-in.
- **Days 28-60 Community lurk surface.** Read-only "becoming feed" — anonymized real users' weight-trend bends + reflections, opt-in to share. Curated 5/day. **No comments, no leaderboard.** TikTok-policy-aligned, anti-shame. Estimated retention lift +8-15% D60.
- **Days 60-90 Outcome verification.** Day 75 (custom program complete moment per `ProgramScheduleCalculator`): graduation screen + mid-program report card + shareable. Users past their custom duration get "Round 2" or "Maintain" branch.

#### 4.3 The DPP coach-text engine (replaces "AI chat with Jeni")

The audience lane's verdict on the founder's AI-chat request: **do not ship a chatbot.** Build **scheduled coach nudges** built on the user's own data, in the DPP text-message playbook. Evidence: DPP achieved 38.5% vs 21.5% ≥3% weight loss with daily texts — the largest effect size in the demand-vs-evidence matrix.

Why not the chatbot:

- Free-form LLM conversation about food = eating-disorder safety landmine.
- "AI coach" branding violates the no-AI voice rule and post-ChatGPT no longer carries a halo for Gen-Z women.
- Higher-effect alternative exists.

What ships instead: a scheduled-nudge engine that fires 3 weekly proactive messages + 1 triggered "noticed you missed two days" check-in, all in the user's voice preference (Jeni / Kira / Sam), all personalized via her own data (her stated barrier, her protein-leading meal, her plank PR, her trend bend). Capped at 5/wk per the locked notification ceiling.

Future option: when ED-safety guardrails mature (2027+), revisit free-form chat as a v3 surface.

#### 4.4 The sister cohort (the 10x LTV bet)

The retention lane's headline long-term bet. Detailed in Pillar 5 monetization (Sprint E).

#### 4.5 Anti-priority: no public leaderboards, no comments, no streak-loss

Three documented retention killers in the post-Ozempic WL cohort. None ships.

---

### Pillar 5 — Trial conversion + monetization (the short-term win)

#### 5.1 The 30-day trial-conversion sprint (the highest-leverage ship)

Total dev time ~6-8 days. Expected lift: +15-35% relative trial-to-paid.

| Tactic | Dev time | Expected lift |
|---|---|---|
| Day-0/1/2/3 in-trial notification + reframe sequence | 4 hours | +5-12% trial→paid |
| Day 2 "almost done" value-visualization modal | 2 days | +8-15% trial→paid |
| Day 3 trial-end emotional reframe screen | 1 day | reduces late-cancel 40-60% of mass |
| US-only 3 vs 7-day trial A/B | 1 day | TBD; expected +20-50% on US base if 7-day wins |
| US-only price anchor A/B ($34.99 / $47.99 / $59.99) | 1 day | TBD; H-and-F high-anchor = 4.5x LTV per Adapty |
| 3 US CPPs (food-first, weight-trend-first, plank-PR-first) | 4 hours each | +15-30% per Apptweak |
| Cancellation-intent winback flow (detect → present winback paywall on next open) | 2-3 days | saves 10-34% of churners (Churnkey average) |
| Drop weekly SKU from primary paywall, keep as winback-only | 4 hours | annual share lift (H-and-F annual = 60.6% revenue share, growing) |

Founder decisions needed: trial length test go/no-go, price anchor range, CPP creative direction (alignment with TikTok ad creative is the wedge).

#### 5.2 US conversion gap diagnostic

Five hypotheses, ranked by probability:

1. **H1 (most likely): US cohort is "Cal AI-trained."** Expects calorie-photo-counting on paywall; sees workout + Becoming + plank-PR. Wrong promise, right install. → **Geo-routed CPPs.**
2. **H2:** $47.99 anchor is mid-tier limbo (too high to be cheap, too low to be premium). → **US price anchor A/B.**
3. **H3:** 3-day trial is hostile in US specifically; Cal AI trained the cohort to expect 3-day, but Cal AI has 31% optimized trial-to-paid + 61 paywall experiments to back it up; JeniFit doesn't. → **US 7-day trial test.**
4. **H4:** Trust-signal gap (no reviews in US specifically). → **CPP screenshot 1 = social proof.**
5. **H5:** Onboarding question set leaks "just curious" intent. → **"Your plan is rendering" promise-rendering screen at Q30.**

Tests to run in 21 days; layered, independent attribution via RC + Apple analytics.

#### 5.3 LTV expansion SKU ladder

| Month | New SKU | Rationale | Expected LTV impact |
|---|---|---|---|
| M0 | Annual $47.99 / Q $24.99 / Weekly $5.99 (current) | Baseline | $62 |
| M2 | Annual $59.99 US-only test | H-and-F high-anchor 4.5x LTV per Adapty | +$15 ARPU on winners |
| M3 | Friend referral "give 1 month, get 1 month" | Adapty H-and-F: referrals 6-12% of new trials at <1/10 paid CAC | +12% trial volume |
| M4 | Gift subscription $59 annual gift | Q4 wedge; Calm/Headspace pattern; Apple supports gift IAP | +3-5% Q4 revenue |
| M6 | Family Plan $79.99/yr up to 5 seats | Strava model | +$8 ARPU blended |
| M9 | Lifetime $249 in winback flow only | Calm pattern; pricing at 5x annual; sent to churn-risk + Q4 traffic | 8-12% of churn-back |
| M12 | Premium tier $89.99/yr: async coach DM + custom meal plan | Wedge above Noom $209, below human-coach $400+ | +25-40% blended ARPU on the 15-25% who upgrade |
| M18 | JeniFit Method content tier (in-app course library) | Reuses lesson engagement (75% vs 23% workouts) | +$5-10 ARPU |

#### 5.4 The sister-cohort SKU — the 10x LTV bet

**The bet:** $79-99/quarter paid invite cohort where 6-12 women going through the same custom program enter a closed voice-and-photo (no text) micro-group, gated by program day. Same JeniFit app + a cohort layer. Voice-react (not chat) to each other's milestones. Shared anonymized trend curve.

**Why it 10x's LTV:**

- ARPU $48 → cohort SKU $316 ARPU on 20-30% upgraders (Calm Premium-tier conversion analog). Blended LTV $62 → $180-220 within 18 months.
- Noom retention 43.6% D30 *because of* coaches + community. Paid social cohorts retain 2.3-3.8x longer than solo (Crossfit / AA / Peloton group literature). JeniFit retention ceiling lifts from ~5% D90 to 15-22%.
- Unit economics: 1 moderator per ~50 cohorts on async voice vs Noom's 1:5 coach ratio. Cost ~$2-4/cohort-user-month vs Noom's $40+ for coaches. Premium price covers 10x over.

**Why nobody else will ship this in 18 months:**

- Cal AI has no behavioral surface to host it.
- Noom won't reduce coach ratio (it's their moat).
- BetterMe + Simple too late on community taste.
- MFP busy integrating Cal AI.
- The brand-trust required to make voice-only women-only cohorts feel safe is *brand-specific*. JeniFit's voice + Becoming + wax-seal aesthetic is the only one in market that earns the invite-only women's group registration.

**Risk:** requires 1 community lead + 1 part-time moderation in Q3, ~$15K/month opex.

**Validation path:** Q3 ship Beta cohorts to top-100 D30-retained users by invite. Measure retention + WTP. Survey: if WTP >$60/quarter on 40%+ → ship in Q4.

---

## Part 5 — Anti-priorities (what NOT to build)

Each of these has a real founder, internal, or community pull. None ships in v2. Honest reasons:

1. **Plank coach v2.** No evidence link to weight outcomes. Re-cements plank-app positioning at exactly the moment we're pivoting to diet-first program. Defer to v3+ pending demand validation.
2. **Water tracking as its own rail.** 8-RCT meta: -0.33 kg, not significant. Only "works" by displacing soda — Gen-Z cohort largely already doesn't drink soda. Build a single ambient pill on Today; do not build a water surface.
3. **CGM integration for non-diabetics.** Mass General-led 8-wk study: 3.1 kg vs 2.3 kg, NS. Active harm risk for DE-adjacent slice. Skip entirely.
4. **AI chatbot with Jeni.** ED safety landmine + no-AI brand voice + DPP scheduled nudges have higher effect size. Replace with §4.3 nudge engine.
5. **Generic multivitamin reminders.** Wellness aesthetic, not behavior change. Replace with 4 evidence-anchored screening moments only: iron (deficiency anemia menstruating women), vitamin D, magnesium (sleep + GLP-1), creatine (RT women). Build "talk to your doctor" referral pattern, no supplement store.
6. **Daily streak system.** Documented retention killer in post-Ozempic cohort. Weekly cadence only (Strava model).
7. **Public leaderboards, forums, comments.** TikTok-policy-aligned, anti-shame. Becoming feed (read-only, opt-in, no comments) instead.
8. **Restaurant menu OCR.** Hard problem; existing `imOutTonight` rule-based covers it honestly with range copy.
9. **Receipt scanning.** Grocery receipts don't tell you what was eaten.
10. **Luteal/follicular prescriptive engine.** Evidence doesn't support it; cohort sniffs out the BS. Cycle *autoregulation* (offer easier session on bad-symptom days) yes; cycle *prescription* no.
11. **BMI-based exercise prescription.** Programs in shame.
12. **VO2max estimation without HR data.** Junk numbers in Becoming erode trust.
13. **Burpees / box jumps / squat-jumps in any tier.** No version of this audience benefits; injury rates are stupid.
14. **Wearable HR integration (Apple Watch).** Fragments cohort, low signal-to-eng ratio.
15. **"AI" branding language anywhere.** Locked voice rule.
16. **Before/after photos / weight-loss imagery.** TikTok-policy + post-Ozempic moderation; brand voice locked.
17. **"Lose 30 lbs in 30 days"-class outcome claims.** Locked voice rule; legal risk.

---

## Part 6 — Phased roadmap

### Sprint A (Days 1-30) — TRIAL CONVERSION SPRINT

**The single most important sprint of the next 12 months.** Every input has independent attribution; the team learns what's driving the gap inside 21 days and can compound.

- [ ] Day-0/1/2/3 in-trial notification + reframe sequence (4h)
- [ ] Day 2 "almost done" value-visualization modal (2d)
- [ ] Day 3 trial-end emotional reframe screen (1d)
- [ ] US-only 3 vs 7-day trial A/B in ASC + RC (1d)
- [ ] US-only price anchor A/B in ASC + RC (1d)
- [ ] 3 US CPPs in ASC (food-first, trend-first, plank-PR-first) (1d copy + 2d screenshots)
- [ ] Cancellation-intent detection + winback flow (2-3d)
- [ ] Drop weekly SKU from primary paywall (4h)
- [ ] Calorie scanner v2 model + schema upgrade (10d — runs in parallel)

**Net dev time:** ~12 days serial, ~8 days parallelized.

### Sprint B (Days 31-60) — CURRICULUM SPRINT

The cognitive-endpoint moat ships. The 5 canonical lessons (D1, D7, D21, D42, D70) come straight from the curriculum-lane output; 79 more to author.

- [ ] Extend `JeniMethodContent.LessonID` from 14 → 84
- [ ] Author 28 lessons (Weeks 1-4) by Day 45 → live in product
- [ ] Author 28 lessons (Weeks 5-8) by Day 60 → staged
- [ ] Cohort routing implementation in `JeniMethodContent.resolve(lesson:user:)`
- [ ] 45 voice notes (Jeni / Kira / Sam) ElevenLabs from real voice actors
- [ ] Multi-modal layer (breath ritual integration, journaling prompt logging, "this was about you" data-tie)
- [ ] Graduation artifact PDF generator (ShareLink)
- [ ] Engagement analytics (per-lesson completion, prompt-fill rate, re-read invocations, cohort drop-off)

Founder decision needed: lessons authored in-house vs ghostwriter contract. The 5 canonical samples from the curriculum lane suggest in-house authorship preserves voice; volume (79 to go) suggests a part-time RD writer + founder edit pass.

### Sprint C (Days 61-90) — SAFETY + RETENTION SPRINT

- [ ] Injury-screen onboarding (9 questions in her75 register) (5d)
- [ ] `ExerciseBank.contraindications` cohort tags, back-fill 128 exercises (5d)
- [ ] McGill Big 3 + LBP swap logic in `WorkoutGenerator` (2d)
- [ ] 48-hour same-muscle rule (2d)
- [ ] DPP scheduled coach-nudge engine (7d)
- [ ] Day 21 plateau intervention surface (3d)
- [ ] Becoming feed v0 (read-only, opt-in, anonymized trend bends) (5d)
- [ ] Weekly streak (replaces any daily streak surfaces) (2d)
- [ ] `validateContraindications(_:userCohort:)` DEBUG validator (1d)

### Sprint D (Days 91-180) — DIFFERENTIATION + MONETIZATION SPRINT

- [ ] Correction flywheel: `food_corrections` + `user_food_profile` schema, pgvector NN-lookup, repeat-meal cache (10d)
- [ ] `canonical_corrections` materialized view + auto-prompt extension (3d)
- [ ] Barcode scanner (AVFoundation + OpenFoodFacts + USDA fallback) (3d)
- [ ] Voice quick-log (Whisper-3 + AppIntents donation) (3d)
- [ ] DSLD supplement pantry seed (2d)
- [ ] HealthKit dietary cross-write (3d)
- [ ] Sister-cohort beta to top-100 D30-retained users (12d)
- [ ] Premium tier $89.99 SKU + content tiering (5d)
- [ ] Lessons Weeks 9-12 authored + cohort routing extended (15d)
- [ ] Aerobic minutes accumulator + progressive overload (5d)

### Sprint E (Days 181-365) — CATEGORY OWNERSHIP

- [ ] Sister-cohort GA (community lead + part-time moderation onboarded)
- [ ] Family Plan SKU
- [ ] Lifetime $249 in winback flow
- [ ] Round 2 / Maintain branching for graduates
- [ ] JeniFit Method content tier (in-app course library)
- [ ] Glute-bridge form coach (Vision pipeline, behind flag)
- [ ] Squat form coach (LiDAR-gated, internal QA, behind flag)
- [ ] Plank coach v2 (gated on user demand from Pillar 4 surveys)

---

## Part 7 — Metrics framework

### North star

D365 paying retention × cohort completion rate × NPS.

### Tier 1 (every sprint review)

- Paywall → trial-start %
- Trial-start → paid %
- D7 activation rate (≥4 logs + ≥1 weight + first lesson read)
- D30 retention
- D90 retention
- D7 lesson completion %
- US trial-start % vs APAC

### Tier 2 (monthly)

- Per-cohort lesson completion drop-off (GLP-1, prior-attempts ≥3, restrictive-food, postpartum, hypermobile)
- Correction-flywheel match rate (similarity >0.85 hits, >0.92 cache hits)
- ARPU by SKU
- Per-MAU AI cost
- US vs APAC conversion delta
- Notification fatigue rate (opt-out + ignored ratio)
- Becoming feed engagement (opt-in + skim time)

### Tier 3 (quarterly)

- **12-week WL outcome: ≥50 lessons cohort vs <25 lessons cohort** — this is the marketing-claim metric
- LTV by SKU
- NPS by cohort
- Re-subscription rate at end of trial / quarterly cycle
- Day 84 cognitive-endpoint qualitative ("what's one thing the app told you about yourself you didn't know?")

---

## Part 8 — Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| GPT-5 latency kills UX | M | H | Two-phase mini+full result, Phase 1 = range not number, Phase 2 = narrow not change |
| Cal-AI-class billing/cancel litigation precedent | L | H | Trust premium, App Store reviewers see pricing/cancel clarity by Sprint A close |
| Sister-cohort moderation failure (creep, scale-shame, exclusion) | M | H | Voice-only, opt-in only, women-only, human moderation 1:50, escalation paths to Trust+Safety lead |
| Curriculum content velocity (84 lessons in 90 days) | H | M | Sprint B ships 28 + 28; remaining 28 lessons in Sprint D; cohort overrides cap at 3/lesson to bound surface |
| Injury-screen friction kills onboarding | M | M | Render as her75 question pills; "prefer not to say" defaults; A/B placement after bodyFocus vs before reveal |
| Workout-first audience churn from re-positioning | L | M | Keep workout rail at parity, just deprioritize from hero; existing workout-completion-rate band protected |
| US conversion gap persists past Sprint A | M | H | Layer 5 tests in parallel + iterate weekly; if no movement by Day 21, escalate to founder for trial-length policy decision |
| GLP-1 cohort flag self-reporting under-coverage | M | M | Re-prompt at Month 1 ("anything changed?"); detect proxy signals (rapid weight loss + low protein logging) |
| Correction-flywheel cold-start (no embeddings for first 30 days) | H | L | Aggregate cohort priors auto-extend system prompt; bootstrap from founder's hand-coded 80-item catalog |
| Voice-note licensing / actor turnover | L | M | Contractual evergreen rights up front; library of 45 clips per voice ranges; ElevenLabs cloned voice as backup |
| Apple policy change on trial length / paywall presentation | L | H | RC abstracts SKU layer; CPP-driven creative changes need no review |
| Curriculum triggers ED in vulnerable user | L | VH | Curriculum lane already specs ED-safety guardrails in Day 21+50 lessons; include "talk to a clinician" referral surface; suppress voice notes for users self-reporting ED history |

---

## Part 9 — The decisions that need founder input

These don't block Sprint A but block Sprint B-D scope:

1. **Trial length policy** — stick with 3-day or commit to A/B 7-day in US? (Recommendation: A/B, decide by Day 21.)
2. **Curriculum authorship model** — in-house (founder voice, slow) vs contracted RD writer + founder edit pass (Recommendation: contracted RD + edit; the 5 canonical samples are the voice anchor.)
3. **Plank coach timing** — confirm defer to v3+? (Recommendation: defer.)
4. **AI chat → scheduled nudges** — confirm pivot away from chatbot? (Recommendation: pivot. The DPP effect size is irreproducible by any chatbot architecture.)
5. **Sister-cohort beta in Q3** — green-light Beta to top-100 retained users? (Recommendation: green-light. Beta is 12d dev; the learning is 90 days; the upside is the 10x LTV bet.)
6. **Premium $89.99 tier** — include async coach DM, or stay editorial-only? (Recommendation: editorial-only at first; add coach DM in M12 once moderation patterns prove.)
7. **Sprint B authorship rhythm** — 28 lessons by Day 45 implies ~1 lesson/day from someone. That someone is who?
8. **Becoming feed moderation** — read-only with opt-in trend share is minimal-risk; do we want curated daily 5, or algorithmic feed? (Recommendation: curated by community lead 1-2h/day; algorithm is too risky for the cohort.)

---

## Closing — the wedge stated once more

Every pillar bends toward one frame: *the behavioral version of what GLP-1s do to food noise.*

The food rail becomes the user's own number. The workout rail becomes safer + GLP-1-aware + lean-preserving. The curriculum is the cognitive-behavioral protocol that retrains the food brain. The cohort becomes accountability without weight-shame. The retention engine ties them together with DPP-style scheduled coach nudges and an anti-streak weekly rhythm. And the long-term bet (sister-cohort SKU) is the moat that compounds: a community-meets-program of voice-only women-only cohorts that no funded-startup playbook can speedrun in 24 months because the trust required to make it safe is the brand's accumulated work, encoded in every italic-punch headline and every "tomorrow resets" notification copy of the last 12 months.

The next 30 days, the team ships exactly one sprint: trial conversion. It is the single highest-leverage thing on the board because (a) every input has independent attribution and learns in 21 days, (b) every win compounds against every future feature, and (c) it doesn't require any of the long-burn content or engineering work that follows. By Day 30 the team should know the answer to half the founder decisions above and have a data-grounded plan for the next 60 days.

By Day 180, JeniFit owns the diet-first weight-loss app positioning for women 22-35. By Day 365, the sister-cohort SKU is shipping and the cognitive-endpoint marketing claim ("women who completed ≥50 JeniFit lessons maintained their weight at month 6 at Xx the rate of users who only completed workouts") is the line every TikTok ad cites.

That's the program.

---

## Appendix A — Research transcripts referenced

Five parallel expert lanes contributed to this synthesis. Their raw outputs sit at:
- Workout safety + effectiveness review (PT + ACSM-PT lane)
- AI calorie engineering plan (ML + prompt + iOS lane)
- CBT curriculum design (clinical psych + RD + content lane)
- Audience + scientific-evidence research (behavioral nutrition + community ethnography lane)
- Retention + LTV + competitive intel (growth + subscription-economics lane)

Cross-lane tensions adjudicated in this document:
- **Plank coach return (PT lane = ship vs audience lane = skip)** → defer to v3+
- **AI chat (founder ask = ship vs audience lane = scheduled nudges)** → scheduled nudges
- **Water tracking (founder ask = build rail vs audience lane = ambient pill)** → ambient pill

## Appendix B — Source clusters

Workout / physiology: ACSM 2024 guidelines, McGill Big 3, STEP-1 + SURMOUNT-1 lean-loss data, Frontiers 2025 RT meta, Apple Vision iOS 26 docs, Lally UCL 2010 habit formation.

AI / vision: PMC head-to-head LLM food benchmarks 2026, OpenAI structured outputs spec, USDA FoodData Central API, OpenFoodFacts API, DSLD NIH supplement DB, Supabase Edge Functions cold-start 2026.

CBT / behavioral: Beck Diet Solution + Beck Institute, Look AHEAD trial, Brewer's Hunger Habit, Michie BCT taxonomy v1, Polivy and Herman 1985 (what-the-hell effect), Neff self-compassion, Hayes ACT, Tribole Intuitive Eating, NWCR Wing and Phelan.

Audience / market: TikTok content analysis on food noise (ResearchGate 2025), Burnt Toast / Maintenance Phase critique, MFP progress-not-perfection 2025 pivot, Cal AI App Store pull April 2026, MyNetDiary GLP-1 Companion 2026.

Retention / LTV: RevenueCat State of Subscription Apps 2026, Adapty H-and-F Benchmarks 2026, Apptweak CPP 2026 framework, DPP text-message RCT, HelpMeDoIt peer-support intervention, Annesi 2011 self-efficacy curves, Klasnja microrandomized notification trial.

Internal: `docs/workout_session_rules.md`, `Packages/PlankEngine/`, `PlankApp/Program/ProgramGoalCalculator.swift`, `PlankApp/Views/DietEducation/`, `supabase/functions/food-vision/index.ts`, `Packages/PlankFood/Sources/PlankFood/`, `scripts/schema.sql`, project memory `~/.claude/projects/-Users-bko-plankAI/memory/MEMORY.md`.
