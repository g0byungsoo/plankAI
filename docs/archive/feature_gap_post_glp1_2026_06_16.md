# Feature-gap roadmap — post-GLP-1 cohort
**Date:** 2026-06-16
**Audience:** women 28-45, 0-12mo off semaglutide/tirzepatide
**Cohort size:** ~4-8M US trailing-12mo; 47-65% drug discontinuation per JAMA Jan 2026
**Goal:** make JeniFit credibly the maintenance app for the off-ramp moment

## TL;DR — the gap is structural, not feature-count

The competitive set splits into two camps, both of which **fail the post-GLP-1 cohort by design**:

1. **GLP-1 tracker apps** (MeAgain, Shotsy, GLPeak, Lina, Velto, Glapp, Dosy, Weightly, GLP-1.com) — built around the injection ritual. MeAgain itself explicitly **does not offer any maintenance-mode functionality** (shotsyapp.com/alternatives/meagain). When the syringe goes away, the app loses its anchor. The 4-8M off-ramp cohort is **invisible to these apps' product roadmaps** because their core surface area (dose tracker, side-effect log, injection-site rotation) becomes irrelevant.
2. **Telehealth + app bundles** (WeightWatchers Med+, Calibrate, Found, Joi, Sequence, Plenity, Virta, Omada) — structurally unbundlable from the drug. Their LTV math requires the user staying on the drug or staying on a $200-300/mo coaching subscription. Calibrate has an active BBB complaint trail about off-ramp policy ("told 1 year, taken off at 6 months, no maintenance dose offered"). WeightWatchers Med+ explicitly markets the combined-with-drug 54% lift, which is the wrong story for off-ramp users.

The wedge: **only Omada has shipped clinical evidence of post-discontinuation maintenance** (0.8% avg weight change at 12mo, n=816) — and Omada is B2B-employer-only. There is **no $4-8/mo consumer iOS app positioned for this cohort**. That's the whitespace.

JeniFit's existing surface (vision-AI food, plank-rotation engine, Jeni coach voice, CBT lessons, breathwork, weight EMA, anti-shame copy, anti-diet voice) is already ~60% of the maintenance product. The other 40% is mostly **cohort recognition, mechanism stack, and trust signal** — not net-new platforms.

---

## Maintenance core — the 12-week "Keep-It-Off" curriculum

### 1. Weekly regain-risk card (the single-screen "what's drifting")
- **Why this cohort needs it:** the deepest psychological pain isn't regaining weight — it's the *fear* of regain combined with not knowing it's happening until the scale moves. By the time the scale moves, drift has been building for 3-6 weeks. Surfacing leading indicators (protein, sleep, fiber, weight EMA slope, hunger return) **before** scale movement is what Omada's wraparound coaching does, mediated by a human; JeniFit can ship it as a one-card surface.
- **Priority:** P0
- **Effort:** 5-7 days (1 new card on Becoming tab; pulls 4 signals JeniFit already has + adds hunger rating + sleep import)
- **Is JeniFit close?:** partial — weight EMA, protein (via food rail), steps exist; sleep is shipped in `SleepService.swift` per current diff; need a single composite "drift score" view that contextualizes them
- **Citation:** Lancet 2026 meta-analysis: regain begins at weeks 4-8 after discontinuation, scale lags by ~6 weeks; MeAgain reviewers explicitly cite missing maintenance tooling.
- **Regulatory note:** frame as "your weekly pattern" not "regain prediction"; never use Ozempic/Wegovy/Zepbound brand names on the card (Apple 5.2.1)

### 2. Hunger-return scale (the "is the noise back?" daily check)
- **Why this cohort needs it:** food noise returning is the single most-cited subjective symptom post-discontinuation (PEAK Wellness, Ruby Oak, Ubie Health, Berry Street); it returns weeks before measurable weight regain. A 0-10 daily "food noise" rating becomes the leading-indicator JeniFit has and nobody else does.
- **Priority:** P0
- **Effort:** 2-3 days (1 daily prompt + 1 trend chart on Becoming)
- **Is JeniFit close?:** no — net new field, but trivial schema (single int per day in `weight_logs`-style table)
- **Citation:** PEAK Wellness clinical writeup on emotional eating resurgence post-GLP-1; Ubie Health on dopamine-spike return; Northwell on food noise reduction mechanism
- **Regulatory note:** call it "food noise" (now post-Ozempic vocabulary normalized per memory) not "appetite suppression loss"

### 3. Adaptive protein target (DRI bumped for lean-mass-at-risk cohort)
- **Why this cohort needs it:** up to 25-40% of GLP-1 weight loss came from lean mass (Health Review Network, Parallel Health); preserving residual muscle through 1.2-2.0 g/kg/day protein is **the** consensus clinical recommendation across David Protein, Mayo Clinic, Teladoc, and Clinical Nutrition Center Denver. MeAgain tracks protein but uses a generic target. JeniFit can compute a cohort-specific dynamic target.
- **Priority:** P0
- **Effort:** 2 days (extend `ProgramGoalCalculator` with `proteinTargetGramsPerDay` derived from weight kg × multiplier; multiplier driven by cohort flag from onboarding)
- **Is JeniFit close?:** partial — food rail tracks protein, but goal is generic 100g default. Need cohort-aware target + a "you hit it" / "you missed it" daily badge on Today's Plate.
- **Citation:** Stage 1 medrxiv registered report on resistance training + protein preserving lean mass on GLP-1; 1.2 g/kg/day floor confirmed across 6+ secondary sources
- **Regulatory note:** present as "your body's protein needs" not "for ex-GLP-1 users"; the cohort onboarding does the targeting silently

### 4. Resistance-day quota (2x/week minimum, surface as a tile)
- **Why this cohort needs it:** resistance training is the single non-pharmacological intervention with the strongest evidence for lean-mass preservation post-discontinuation (MyFitnessPal 2026 protocol, Mayo Clinic); 2 sessions/week is the floor. JeniFit's plank engine is a position-block engine, **not** progressive overload resistance. The cohort needs either (a) a new "strength" rail that wraps existing plank progressions as resistance, or (b) a HealthKit-imported strength-workout counter.
- **Priority:** P0
- **Effort:** 3-5 days (Option B is cheaper — HealthKit `HKWorkoutActivityType.functionalStrengthTraining` + `.traditionalStrengthTraining` counter, plus a "2 strength sessions logged this week" tile on Becoming)
- **Is JeniFit close?:** partial — plank engine exists but isn't framed as resistance; HealthKit workout types not yet imported
- **Citation:** MyFitnessPal 2026 protocol; Mayo Clinic education module
- **Regulatory note:** none. "Strength training" is generic.

### 5. The 12-week structured curriculum (named, dated, finishable)
- **Why this cohort needs it:** Diabetes Prevention Program (the most-replicated weight-maintenance evidence base) explicitly structures into 16 sessions over 6 months then monthly maintenance (ADA Standards of Care 2026 §8). Open-ended apps under-perform finite ones for this cohort because the off-ramp moment is itself a transition — they want a defined "I'm in this for 12 weeks" container, not a forever-app.
- **Priority:** P0
- **Effort:** 4-5 days (extend `ProgramPlanRecord` with a `cohortVariant: postGLP1` flag; remix the JeniMethod lesson manifest into a 12-week sequence; the lesson reader + tappable pages already shipped per `LessonReaderView.swift` + `LessonPracticeView.swift`)
- **Is JeniFit close?:** yes — JeniMethod CBT lesson infrastructure exists; need a curated 12-week sequence + week-numbered hero on PlanView
- **Citation:** DPP weekly cadence + maintenance dosing schedule; per-memory `project_program_pivot_v1_1` already accepts custom program duration
- **Regulatory note:** "Keep-It-Off" or "Maintenance Method" naming is fine; avoid "post-GLP-1 protocol" externally (FDA Feb 2026 warning letter risk)

---

## Identity + cohort recognition — why the cohort feels seen

### 6. Cohort-flagged onboarding question + downstream voice swap
- **Why this cohort needs it:** the cohort is **hyper-aware** of being a cohort — Reddit threads, Peter Attia podcasts, and WaPo + CNN regain coverage have made them self-identify before they download anything. No competitor's onboarding asks "did you stop a weight-loss medication?" without commercializing it. Asking the question itself is a credibility signal.
- **Priority:** P0
- **Effort:** 1 day (one new onboarding screen + `onb_v4_glp1_history` AppStorage key per memory `project_onboarding_v2_fields` pattern; copy switches on 3-4 Becoming + paywall surfaces)
- **Is JeniFit close?:** partial — onboarding v4.5 shipped, cohort segmentation in Phase 1 plan but not yet for GLP-1 history specifically. Memory already notes GLP-1 field was added in v2 keys — confirm wiring.
- **Citation:** Reddit r/Zepbound + r/Mounjaro thread density on "what now" suggests cohort self-identification is the norm; MeAgain reviews show users explicitly sorting apps by "is this for me"
- **Regulatory note:** use phrasing like "recently stopped a weight-loss medication" — generic, not brand-named. Apple 5.2.1 risk vanishes when no brand appears in user-visible UI.

### 7. The "before the noise comes back" mid-funnel screen on paywall
- **Why this cohort needs it:** anti-shame, cohort-aware paywall copy. Per memory `feedback_paywall_2026`, JeniFit's paywall avoids fabricated stats. The cohort responds to **acknowledgment of the fear** more than to weight-loss claims — and "behavioral skills before the food noise comes back" is FTC-safe (no numeric claim, no drug claim, no comparison to Rx outcomes).
- **Priority:** P1
- **Effort:** 1 day (paywall variant for `onb_v4_glp1_history == "recently_stopped"` cohort; reuse existing PaywallView slot architecture)
- **Is JeniFit close?:** partial — PaywallView is segmented by bodyFocus per memory; extending segmentation to cohort is straightforward
- **Citation:** memory `feedback_us_paywall_conversion_gap` (US paywall is the worst converter; cohort-aware variant is a leverage point)
- **Regulatory note:** never imply JeniFit replaces or substitutes for the medication. The promise is **behavioral skills**, not a drug alternative.

### 8. Identity hero on Becoming tab, cohort-language version
- **Why this cohort needs it:** existing identity hero pulls from Q140 + Q111. Cohort variant: "you did the hard part. now you're the woman who keeps it." Per memory `project_v2_strategy` the wedge is "behavioral version of GLP-1 food-noise suppression" — this is where that lives visually.
- **Priority:** P1
- **Effort:** 1 day (existing `IdentityHero` view + 1 conditional copy block)
- **Is JeniFit close?:** yes — pattern shipped, just need cohort string variant
- **Citation:** memory `feedback_voice_signals` (italic punch words on identity copy)
- **Regulatory note:** none.

---

## Mechanism stack — protein, sleep, satiety, resistance

### 9. Sleep-as-leading-indicator card (already in progress per diff)
- **Why this cohort needs it:** post-discontinuation hunger is partially mediated by sleep deprivation (Berry Street dietitian guide, Healthline); the cohort needs 7-9 hours and most don't get it. SleepService.swift exists in the diff — this is the cheapest "we noticed something the scale didn't" moment.
- **Priority:** P1
- **Effort:** 2-3 days (LastNightSleepCard.swift already created per diff; needs binding to a 7-day rolling avg + flag when <6.5h trailing 7d)
- **Is JeniFit close?:** yes — code in flight per current diff (`PlankApp/Health/SleepService.swift`, `PlankApp/Views/Analytics/LastNightSleepCard.swift`)
- **Citation:** Healthline 7-9h sleep is the GLP-1 off-ramp consensus; Berry Street dietitian guide
- **Regulatory note:** none.

### 10. Fiber target alongside protein (the satiety pair)
- **Why this cohort needs it:** high-fiber foods naturally stimulate endogenous GLP-1 release — this is the **one** behavioral mechanism with shared pathway to the drug, and so it's the highest-credibility carry-over story to tell the cohort. MeAgain tracks fiber but doesn't connect it to the "endogenous GLP-1" mechanism narrative.
- **Priority:** P1
- **Effort:** 2 days (add `fiberTargetGramsPerDay` to ProgramGoalCalculator; surface as a sibling pill to protein on Today's Plate)
- **Is JeniFit close?:** partial — food rail computes fiber per item; target + dedicated surface missing
- **Citation:** Healthline: fiber stimulates endogenous GLP-1 release; Ruby Oak Nutrition on satiety pair
- **Regulatory note:** **CAREFUL** — phrase as "fiber + protein helps you feel full" not "fiber is a natural GLP-1." The latter is structure-function-claim territory and could attract FTC scrutiny.

### 11. The "what your scale doesn't say" body-composition tile (weight EMA × lean-mass risk)
- **Why this cohort needs it:** up to 40% of GLP-1 weight loss is lean mass (Parallel Health); the cohort is afraid of muscle loss specifically. WeightWatchers shipped an AI Body Scanner for this; JeniFit can ship a lighter version: surface "your weight is stable AND your protein + resistance adherence is high → your lean mass is likely preserved" without claiming a measurement.
- **Priority:** P1
- **Effort:** 3 days (composite tile on Becoming that reads weight EMA slope + protein adherence + strength session count over rolling 4 weeks; outputs 1 of 3 narrative states)
- **Is JeniFit close?:** partial — all 3 inputs exist in different surfaces; need composite logic + 1 new tile
- **Citation:** WW AI Body Scanner launch (hitconsultant.net Dec 2025) shows the cohort wants a non-scale signal
- **Regulatory note:** never claim a body-composition *measurement*. Narrative framing: "based on your protein + strength habits, you're likely preserving lean mass." Inference, not measurement.

---

## Retention + ritual — daily/weekly loop

### 12. Weekly check-in ritual (Sunday "this week in your maintenance" recap)
- **Why this cohort needs it:** DPP evidence supports weekly check-ins as the highest-adherence cadence for maintenance phase; MeAgain's daily push is too frequent for an off-ramp user (the cohort already moved on from daily injection rituals). A **weekly** ritual matches their new identity: I'm a person who weighs in on Sunday, not a person who injects on Wednesday.
- **Priority:** P1
- **Effort:** 3 days (1 scheduled notification + 1 Sunday-only Becoming hero state recapping protein avg, sleep avg, weight EMA slope, hunger rating trend, JeniMethod lesson done)
- **Is JeniFit close?:** partial — notification system shipped (per memory `project_trial_week_notifications`); weekly cadence not yet templated. `NotificationTimeBucket.swift` exists in current diff suggests this is in-flight.
- **Citation:** DPP attendance + weight loss study; ADA Standards of Care 2026 §8: monthly contact + weekly self-monitoring
- **Regulatory note:** none.

### 13. Re-engagement when the cohort goes quiet (the silent week intervention)
- **Why this cohort needs it:** the leading indicator of regain isn't a high hunger rating — it's the user **stopping logging entirely**. Per memory `project_launch_v106b11_findings`, JeniFit already sees 23% workout completion; for this cohort, food logging silence is the canary. Per the diff, `CancellationWinbackSheet.swift` already exists — extend the pattern.
- **Priority:** P1
- **Effort:** 2 days (silent-week detector + 1 gentle re-entry notification: "it's been 6 days. no pressure. just say hi.")
- **Is JeniFit close?:** partial — winback sheet exists for cancellation; silent-week detector + notification template are net-new
- **Citation:** Berry Street: disengagement, not weight, is the regain canary
- **Regulatory note:** none. Critical: re-entry copy must not shame ("we miss you" not "you're falling behind") per memory `feedback_notification_voice`.

### 14. The 30-day "first month off" milestone (one-time, earned)
- **Why this cohort needs it:** per memory `feedback_scatter_milestone_rule`, JeniFit reserves sticker scatter for 3 earned moments. The off-ramp cohort needs a fourth: 30 days off the drug (self-reported during onboarding + counted by app). This is a peer-app whitespace — no competitor celebrates the *milestone* of being off it.
- **Priority:** P2
- **Effort:** 1 day (date-math + 1 milestone screen, reuses sticker-scatter component)
- **Is JeniFit close?:** yes — earned-moment scatter pattern shipped, just need 1 new trigger
- **Citation:** memory `feedback_scatter_milestone_rule` + cohort literature on milestone-marking
- **Regulatory note:** date is self-reported in onboarding; never auto-detect from prescription data (JeniFit has none).

---

## Trust + clinical credibility — citations, disclaimers, the non-Rx anti-claim

### 15. "Why we're not Calibrate" trust strip on paywall + settings
- **Why this cohort needs it:** the cohort is **burned** by telehealth + app bundles. Calibrate's BBB trail, Found's $200/mo, Sequence's drug-coupling — they've paid for this once and the pricing was 5-10x JeniFit's. Single trust strip: "no prescriptions. no telehealth. no monthly call. just the daily habits — supported by Stanford breathwork, ACSM exercise guidelines, Mayo Clinic protein evidence."
- **Priority:** P0
- **Effort:** 1 day (1 paywall trust strip + 1 settings "what we are / what we aren't" expandable)
- **Is JeniFit close?:** no — net new copy, but easy
- **Citation:** competitive Calibrate / Found / WW pricing + complaint volume
- **Regulatory note:** **safest possible positioning** — explicitly disclaim drug substitution. This is exactly the FTC + FDA Feb 2026 zone where JeniFit can confidently say "we are not, never were, never will be."

### 16. The visible citation footer on every research-backed claim
- **Why this cohort needs it:** Peter Attia's audience reads citations. JeniMethod lessons + breathwork primer should each footer their source (e.g., "Stanford Balban et al. 2023" already shipped per memory; extend pattern). The cohort filters apps by perceived rigor.
- **Priority:** P2
- **Effort:** 2 days across surfaces (footer component + audit of existing claims for source)
- **Is JeniFit close?:** partial — breathwork module already cites Balban + Epel + Meerman + Sato per memory; Becoming modules cite (McGill, Biering-Sørensen, Helander, ACSM, AHA); CBT lessons need similar discipline
- **Citation:** memory `project_breathwork_module` + memory `project_v2_strategy` (sister-cohort credibility bet)
- **Regulatory note:** every citation must be accurate; cite primary sources not blog summaries.

---

## Top 3 P0 features to ship in weeks 1-3 (to make positioning credible)

1. **Cohort onboarding question + downstream voice swap (#6)** — 1 day. Without this, every other feature lands on the wrong user. Ship this first.
2. **Hunger-return scale + weekly regain-risk card (#1, #2)** — 7-10 days combined. This is the **leading indicator** product no competitor has. Drop the daily hunger rating into the existing morning ritual; surface it in a weekly card that pulls protein + sleep + weight EMA together. After this ships, JeniFit is the only consumer iOS app with a "what's drifting before the scale moves" surface.
3. **Adaptive protein target + resistance-day quota (#3, #4)** — 5-7 days combined. These are the two non-negotiable mechanism-stack pieces; without them, the cohort dismisses the app on day 3. Both reuse existing infrastructure (food rail, HealthKit) and cost very little.

Total estimated effort weeks 1-3: ~3 weeks for one founder.

## Top 3 P1 differentiators no competitor has

1. **"Food noise" returning as a tracked metric (#2 + #11)** — MeAgain tracks injections; WeightWatchers tracks Points; nobody tracks the subjective return of the noise. This is the cohort's lingua franca per PEAK Wellness + Ruby Oak. JeniFit's anti-diet, no-AI-language voice is uniquely positioned to surface it without shame.
2. **The non-Rx trust strip (#15)** — the cohort has just stopped paying $300-1500/mo to a telehealth company and is suspicious of all of them. Being publicly, structurally **not** in that business is a moat the telehealth-bundled apps cannot copy without dismantling their LTV model.
3. **The 12-week finite curriculum (#5)** — DPP-shaped, named, finishable. Per memory `project_program_pivot_v1_1`, JeniFit already pivoted to custom programs; cohort variant is a content swap, not an architecture change. MeAgain and the trackers are forever-apps (or forever until you stop the drug); the cohort wants a **completable** chapter for the off-ramp transition.

---

## Honoring the constraints (recap)

- **Solo iOS, ≤10 weeks:** the P0 + P1 list above maps to ~5-6 weeks of solo work, leaving runway for polish + QA + paywall variant testing.
- **No Rx / no telehealth / no clinical staff:** the framing is **behavioral skills + measurable habits + research citations**. Every feature above is a measurement or a behavioral nudge — not a clinical intervention.
- **Apple 5.2.1 — no brand names:** every user-visible string uses "weight-loss medication" / "recently stopped" / "the medication" — never Ozempic, Wegovy, Mounjaro, Zepbound, semaglutide, tirzepatide. The cohort onboarding question is the only place the topic surfaces, and even there it's brand-agnostic.
- **No FDA Feb 2026 warning territory:** never use "GLP-1 alternative," "natural GLP-1," "alternative to the shot," or any comparative claim. The fiber-as-endogenous-GLP-1 mechanism story is **dropped** at the user-facing surface; it remains an internal product justification only.
- **No FTC NextMed-style numeric claims:** zero first-party weight-loss numbers anywhere — paywall, App Store screenshots, in-app copy. The narrative is "you did the hard part — keep the rhythm" not "lose X lbs."
- **Existing stack (Supabase + RevenueCat + HealthKit):** every feature above lands on existing tables (extend `weight_logs` schema for hunger rating, food rail already in Supabase per memory `project_release_readiness_2026_06_12`, HealthKit strength-workout type is supported already). No new third-party SDK needed.

---

## What the diff already does

The current uncommitted diff shows that of the 16 features above, 4 are already in flight — strong signal the direction is right:
- `PlankApp/Health/SleepService.swift` (feature #9, sleep card)
- `PlankApp/Views/Analytics/LastNightSleepCard.swift` (feature #9, surface)
- `PlankApp/Views/Paywall/CancellationWinbackSheet.swift` (feature #13, re-engagement pattern)
- `PlankApp/Notifications/NotificationTimeBucket.swift` + `RetentionNotifications.swift` (feature #12, weekly check-in infrastructure)

The proposal is to **explicitly cohort-frame** what's already being built and add the 3 highest-leverage net-new pieces (cohort onboarding question, hunger-return scale, adaptive protein target).

---

## Sources

- [MeAgain App Store listing](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534)
- [Shotsy vs MeAgain — explicit "no maintenance mode"](https://shotsyapp.com/alternatives/meagain/)
- [Omada Health post-discontinuation 12mo maintenance data](https://investors.omadahealth.com/news-releases/news-release-details/new-omada-health-analysis-shows-long-term-weight-maintenance)
- [Lancet eClinicalMedicine 2026 meta-analysis on metabolic rebound](https://www.thelancet.com/journals/eclinm/article/PIIS2589-5370(25)00614-5/fulltext)
- [Healthline: managing hunger after stopping](https://www.healthline.com/health-news/manage-extreme-hunger-stopping-ozempic)
- [Berry Street: post-Ozempic dietitian guide](https://www.berrystreet.co/blog/life-after-ozempic-a-dietitian-s-guide-to-appetite-metabolism)
- [Ruby Oak Nutrition: food noise + binge eating + GLP-1](https://rubyoaknutrition.com/food-noise-binge-eating-glp1/)
- [PEAK Wellness: emotional eating on GLP-1 medications](https://peakwellnessva.com/blog/emotional-eating-glp1/)
- [Ubie Health: food noise + dopamine reward path](https://ubiehealth.com/doctors-note/glp-1-food-noise-secret-brain-reward-rewire-path-71e10)
- [MyFitnessPal: resistance training for muscle preservation on GLP-1](https://blog.myfitnesspal.com/glp-1-resistance-training-muscle-mass/)
- [David Protein: protein on GLP-1](https://davidprotein.com/blogs/the-column/protein-glp1-medications-muscle-preservation)
- [Mayo Clinic: GLP-1 medications and muscle loss](https://store.mayoclinic.com/education/glp-1-medications-and-muscle-loss-what-to-know-about-nutrition-and-supplements/)
- [Teladoc: 4 tips for preventing muscle loss on GLP-1](https://www.teladochealth.com/library/article/glp-1-medication-and-muscle-loss-4-tips-for-preventing-muscle-loss)
- [Health Review Network: GLP-1 muscle loss data](https://healthreviewnetwork.com/weight-loss/glp-1-muscle-loss/)
- [Parallel Health: longevity vs aging skin/hair/bone on GLP-1](https://www.parallelhealth.io/blogs/parallelogram/glp1-longevity-or-aging-skin-hair-bone)
- [Reverse Health app review (women 40+, peri-positioned)](https://www.innerbody.com/reverse-health-reviews)
- [WeightWatchers Med+ + AI Body Scanner 2026 launch](https://hitconsultant.net/2025/12/17/weight-watchers-launches-new-glp-1-program-and-ai-app-features/)
- [Calibrate BBB complaints — off-ramp policy](https://www.bbb.org/us/ny/new-york/profile/weight-loss/calibrate-health-inc-0121-87146034)
- [Calibrate reviews — off-ramp gaps](https://www.reviews.io/company-reviews/store/join-calibrate)
- [Joi Women's Wellness review](https://glp1remedy.com/joi-wellness-weight-loss-semaglutide-review/)
- [Virta Health unified GLP-1 platform 2026](https://www.businesswire.com/news/home/20260610934355/en/Virta-Health-Introduces-Unified-GLP-1-Access-Platform-for-Employers)
- [Omada GLP-1 Flex Care 2026](https://www.omadahealth.com/resource-center/omada-health-announces-glp-1-flex-care-giving-employers-a-new-flexible-path-to-support-obesity-care)
- [FTC final order vs NextMed: $150K, deceptive GLP-1 program advertising](https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-approves-final-order-against-telehealth-provider-nextmed-over-charges-it-used-deceptive)
- [FDA February 2026 warning letters to 30 telehealth firms](https://www.fda.gov/news-events/press-announcements/fda-warns-30-telehealth-companies-against-illegal-marketing-compounded-glp-1s)
- [ADA Standards of Care 2026 §8 — obesity weight management](https://diabetesjournals.org/care/article/49/Supplement_1/S166/163915/8-Obesity-and-Weight-Management-for-the-Prevention)
- [DPP attendance + weight loss adherence study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10713771/)
- [Northwell: How GLP-1s quiet food noise](https://thewell.northwell.edu/obesity/ozempic-glp1-food-noise)
- [Fortune: Reverse Health app review 2026](https://fortune.com/article/reverse-health-review/)
