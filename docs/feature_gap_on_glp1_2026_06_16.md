# Feature-gap roadmap — on-GLP-1 cohort
**Date:** 2026-06-16
**Audience:** women currently injecting semaglutide/tirzepatide (~15-19M US, RAND Aug 2025)
**Phase:** Round-2 Phase 3 (weeks 6-10)
**Goal:** make JeniFit a credible cohort companion to avoid install→48h churn on Day-2 reviews

## Executive summary

The on-GLP-1 cohort is the most valuable behavior-change audience available to JeniFit in 2026: ~15-19M US women currently injecting, already pay $300-1500/mo for the drug, fragment workflow across 3-5 apps, and have install-day expectations set by a mature competitive set. The market has consolidated around two patterns:

1. **Pure trackers** (Shotsy, Glapp, Peachy Progress, Pep) — injection logging, site rotation, side-effect log, weight trend. Floor is now sophisticated: visual body map for site rotation, 15+ symptom severity ratings, dose-level estimation curves.
2. **All-in-one companions** (MeAgain, Lina, MyNetDiary GLP-1 Companion, Embla, Noom GLP-1) — tracker + food + protein + AI coach + community. MeAgain leads with 400K users + 4.8 stars + Capy AI companion.

**The white space:** every competitor either has a clinical/utilitarian register (Shotsy, MyNetDiary) or stapled-on AI chat (Pep PepBot, MeAgain Capy). None speak the cohort's actual psychological language — shame-aware, GLP-1-fluent, Gen-Z-coded, brand-warm. None integrate the off-ramp identity arc (Embla owns enterprise; no consumer app has shipped this). None preserve muscle through resistance programming (Noom has "Muscle Defense" gated behind the $279+/mo Rx bundle).

**JeniFit's wedge:** cohort-segmented onboarding routes on-GLP-1 women into a Jeni voice that already knows muscle loss + nausea + dose cadence + identity rebuild. Existing CBT lessons + Becoming tab + photo-vision food rail + step tracking + breathwork are 70% of the all-in-one stack. Remaining 30% (injection tracker, side-effect log, dose-aware nutrition flip, protein floor, off-ramp module) shippable in 4-5 weeks if scoped right.

**Apple constraint that shapes everything:** drug brand names cannot appear in App Store metadata or app name (5.2.1 trademark/IP). They CAN appear in user-entered medication fields, in lesson body copy where pharmacologically necessary, and as user-selected references in onboarding. Use "GLP-1," "your medication," "weekly shot" in chrome; let users type/select brand inside the app.

---

## Group 1: Injection-tracker lite (the floor)

### 1. Weekly dose log + injection-day reminder
- **Why this cohort needs it:** Missed-dose anxiety is the #1 anxiety topic in r/Zepbound/r/Mounjaro. The 4-day rule (Mounjaro) vs 5-day rule (Ozempic/Wegovy) is non-trivial. "Thousands of people on GLP-1 medications struggle with anxiety about missed doses or accidental double-dosing." (pharmacyplanet.com)
- **Priority:** P0
- **Effort:** 2 days. Single SwiftData entity `InjectionLog { date, medication, dose_mg, site, notes }`, weekly UNUserNotification anchor.
- **Is JeniFit close?:** No — greenfield. Existing notification infrastructure (`RetentionNotifications`) is reusable for cadence.
- **Citation:** Shotsy review + Healthline/Pharmacy Planet missed-dose guidance + r/Zepbound threads.
- **Regulatory note:** Frame as "self-tracking journal," never dose advisor. Show 4-day/5-day window as user-selectable in onboarding (not algorithmic). No "you can take it now" prompts — only "log when you took it."

### 2. Injection-site rotation map
- **Why this cohort needs it:** Site rotation prevents lipohypertrophy + injection-site reactions. Every serious competitor now ships this. Peachy Progress, MeAgain, Pep, GLP-1 Tracker all use a visual body diagram with color-coded last-used indicators. Text-dropdown rotation is no longer the floor.
- **Priority:** P0
- **Effort:** 3-4 days. SF Symbols body silhouette + 8 tappable site zones + last-used timestamp + "suggest next site" rule.
- **Is JeniFit close?:** No — greenfield component.
- **Citation:** Pep app description + Peachy Progress feature list.
- **Regulatory note:** None — site rotation is patient-administered.

### 3. Side-effect severity log (15+ symptoms)
- **Why this cohort needs it:** Users explicitly bring screenshots to provider visits. Lina exports PDF reports. MeAgain: "side-effect tracker where users log nausea, constipation, reflux, fatigue, and custom symptoms, tracking their timing, severity, and notes for healthcare provider discussions."
- **Priority:** P0
- **Effort:** 3 days. 15-20 symptom catalog. 1-5 severity. Free-text note. Link to nearest InjectionLog. Export-to-share text dump.
- **Is JeniFit close?:** Partial — `SessionRatings` schema in Supabase has the shape; clone for symptoms.
- **Citation:** Lina + MeAgain + MyNetDiary GLP-1 Companion.
- **Regulatory note:** Frame as journaling. No symptom→intervention mapping.

### 4. Dose-history timeline view
- **Why this cohort needs it:** Titration is core mental model — users obsessively scrub "when did I bump to 5mg, and did the nausea improve?" Shotsy + MeAgain ship a vertical timeline.
- **Priority:** P1
- **Effort:** 1-2 days. Vertical SwiftUI list of InjectionLog grouped by month, dose-change annotations.
- **Is JeniFit close?:** No, but trivial once #1 ships.
- **Citation:** Shotsy + MeAgain core feature.

---

## Group 2: Side-effect management

### 5. Nausea-rescue protocol (in-the-moment, not retrospective)
- **Why this cohort needs it:** Symptom logs are post-hoc. Actual pain is "I'm nauseous RIGHT NOW, what do I do?" No competitor surfaces an in-the-moment rescue flow. Ginger 250mg 4x/day is evidence-based.
- **Priority:** P1 (no competitor has it; high differentiation)
- **Effort:** 2-3 days. New "feeling rough?" surface from Home or Jeni. 4-step protocol: rate it, sip water/ginger, try one of 5 safe foods, 5-min breath. Ties to existing breathwork + lesson reader.
- **Is JeniFit close?:** Yes — breathwork + Jeni voice + LessonReaderView are 80% of chrome.
- **Citation:** diatribe.org "7 Tips for Navigating Nausea on a GLP-1" + Cleveland Clinic GLP-1 Diet.
- **Regulatory note:** Frame as "comfort tips" — "things other people on a GLP-1 have tried," not "this will stop nausea."

### 6. Hair-shedding tracker + protein-correlation surface
- **Why this cohort needs it:** Hair loss is #2 anxiety topic after nausea. Telogen effluvium peaks ~3 months after weight loss begins. "Adding 100+ grams of protein in their diet helped slow down hair shedding." No competitor surfaces this connection.
- **Priority:** P1
- **Effort:** 1 day. Feature "hair shedding" in symptom catalog; when logged 3+ times in 14 days, surface a JeniMethod lesson on protein-hair + check daily protein hits floor.
- **Is JeniFit close?:** Partial — lessons + symptom log exist; need cohort-specific lesson + trigger rule.
- **Citation:** AOL "My hair came out in clumps" + Healthline ozempic hair loss research.

### 7. GI-pattern recognition (food-symptom correlation)
- **Why this cohort needs it:** MyNetDiary GLP-1 Companion: "enhanced Day Events tracker logs digestive symptoms... helping users spot which foods or timing patterns trigger discomfort."
- **Priority:** P2 (MyNetDiary already has it; not green-field win)
- **Effort:** 4-5 days. Food-log + symptom-log timestamp join; count-based correlation surface.
- **Is JeniFit close?:** Partial — food rail captures meals; symptom log captures symptoms.
- **Citation:** MyNetDiary PR + Cleveland Clinic.

---

## Group 3: Nausea-aware nutrition

### 8. Injection-day eating mode
- **Why this cohort needs it:** Reddit threads consistently show injection-day eating is different: smaller portions, blander foods, protein-forward, less fat. Cyclical pattern documented: "on my sixth day and on the 7th day to my next dose my candy thoughts are already coming back." No competitor flips a per-day mode based on dose cadence.
- **Priority:** P1 (high differentiation; ties existing food rail to injection log)
- **Effort:** 3 days. When InjectionLog within last 24hr, food rail Home flips to "injection day plate" register. Jeni voice on injection day softens: "today's about getting fluids and small bites."
- **Is JeniFit close?:** Yes. Food rail v3 has the surface; just needs conditional mode.
- **Citation:** TrimRX "What to Eat Before Zepbound Injection" + Cleveland Clinic + r/Zepbound.
- **Regulatory note:** "Eating tips on injection day," not "this prevents nausea."

### 9. Protein floor (1.2-1.6 g/kg)
- **Why this cohort needs it:** "Clinical trials show individuals using GLP-1 medications lose 25-40% of total weight loss as lean mass" (Cell Reports Medicine 2026). "Protein floor of 1.2g/kg regardless of stated fitness goals" (Protein Pal). MeAgain + Pep + MyNetDiary all surface protein as primary nutrient.
- **Priority:** P0
- **Effort:** 1 day. Cohort flag elevates protein from #3 macro to #1 on food rail Home + Becoming. Recalculate goal from `weight_kg * 1.2`.
- **Is JeniFit close?:** Yes — food rail captures protein; just need elevation + goal-floor recalc.
- **Citation:** Cell Reports Medicine 2026 + Protein Pal + David Protein.

### 10. Hydration anchor
- **Why this cohort needs it:** Constipation + dehydration common on GLP-1. Pep, MeAgain, Lina all ship hydration. Users describe "I forget to drink because I'm not thirsty anymore."
- **Priority:** P1
- **Effort:** 1 day. HealthKit water log + daily target (default 80oz). Add to Home health strip alongside steps.
- **Is JeniFit close?:** Partial — steps + breathwork in Home health pattern; add water as 3rd ring.

---

## Group 4: Muscle preservation

### 11. Resistance-training program for GLP-1 users (not just plank)
- **Why this cohort needs it:** Plank-rotation alone is insufficient for GLP-1 cohort. Cell Reports Medicine 2026 + David Protein point to **resistance training plus protein** as the only evidenced intervention. Noom's GLP-1 Companion ships "Muscle Defense" for this.
- **Priority:** P1 (differentiator vs Shotsy/MeAgain — neither prescribes resistance)
- **Effort:** 4-5 days. Add 3 bodyweight resistance routines (push, pull, lower) to workout engine — squat / glute bridge / wall pushup / hinge / row variants. ~15 new exercises + 2-day/week resistance template.
- **Is JeniFit close?:** Partial — workout engine + voice cascade exist. Need new exercise entries + cohort-specific template.
- **Citation:** Cell Reports Medicine 2026 + ADA press + Noom Muscle Defense.

### 12. Body-composition trend (lean vs fat, optional)
- **Why this cohort needs it:** Weight alone misleading — 25-40% of GLP-1 weight loss can be lean mass. Users with Withings/Renpho/Eufy scales already have body-fat % in HealthKit.
- **Priority:** P2 (only ~25-30% of cohort owns smart scale)
- **Effort:** 1-2 days. Read `HKQuantityTypeIdentifierLeanBodyMass` + `BodyFatPercentage`; plot in Becoming.
- **Is JeniFit close?:** Yes — HealthKit infrastructure exists for steps + body mass; extend.

---

## Group 5: Identity + cohort recognition (the JeniFit moat)

### 13. Cohort-specific Jeni voice + lesson sequence
- **Why this cohort needs it:** Shotsy is utilitarian; MeAgain's Capy is generic-cute; Pep's PepBot is generic AI; Lina exports PDFs but has no real voice. NONE speak as if they know what GLP-1 month-2 fatigue feels like, what taste change feels like, what shedding feels like. The voice gap is the moat.
- **Priority:** P0
- **Effort:** 5-7 days (writing-heavy). 8-12 new JeniMethod lessons on GLP-1-specific topics: "what taste change means," "the sulfur burps thing," "shedding doesn't mean you're broken," "the food noise will come back on day 6 — that's not failure," "month-4 plateau is the medication, not you," "muscle is the body you're keeping."
- **Is JeniFit close?:** Yes — JeniMethod lesson reader + manifest + Grok hero photo pipeline (42 photos shipped) all exist. Need cohort-tagged lessons + routing rule.
- **Citation:** `project_jenifit_vision.md` + `feedback_post_ozempic_vocabulary.md` + existing JeniMethod architecture.
- **Regulatory note:** Stay on patient-experience side; no clinical recommendations.

### 14. Sister-cohort community (GLP-1 women only)
- **Why this cohort needs it:** Reddit is where this cohort currently lives — but Reddit lacks brand container. MeAgain App Store review explicitly requested community forum. No on-iOS competitor has shipped a cohort-walled community.
- **Priority:** P2 (high engagement but moderation cost; defer to v1.2 unless founder accepts moderation burden)
- **Effort:** 2-3 weeks (moderation is the real cost, not the build).
- **Is JeniFit close?:** Partial — Supabase auth + day_progress + session_logs exist. Community is greenfield product + moderation surface.

---

## Group 6: Off-ramp planning (the bridge no consumer app has shipped)

### 15. Off-ramp readiness + tapering education
- **Why this cohort needs it:** "Those who tapered off GLP-1s under medical guidance were eight times more likely to continue losing weight after stopping (56%), compared to the 7% who quit abruptly." (Virta Health survey 2025). Embla has the only validated approach but it's enterprise-only. No consumer GLP-1 app has shipped an off-ramp module.
- **Priority:** P1 (differentiator + ties on-GLP-1 user to post-GLP-1 program for 12+ month retention)
- **Effort:** 3-4 days. 4-lesson off-ramp module ("am I ready?" / "what's the safe taper" / "habits that hold the loss" / "what to do when food noise comes back"). Cohort-flag gated.
- **Is JeniFit close?:** Yes — JeniMethod lesson architecture aligns. Need 4 lessons + routing trigger.
- **Citation:** Virta Health press release + Embla Embrace product page + Healthline tapering.
- **Regulatory note:** Critical — frame as "questions to bring to your provider," never as taper protocol. Add "talk to your provider about timing" gate before unlocking module content.

---

## Group 7: Retention + ritual

### 16. Dose-cadence-aware notification register
- **Why this cohort needs it:** Reddit shows users want different messaging on day-0 (injection day), day-2-4 (peak effect), day-5-7 (effect fading, food noise returning). User's psychological state is cyclical-weekly, not daily. No competitor has shipped weekly-cadence-aware notification voice.
- **Priority:** P1
- **Effort:** 2 days. Extend existing `NotificationTimeBucket` + `RetentionNotifications` to read InjectionLog and select copy from cohort-specific bucket.
- **Is JeniFit close?:** Yes — notification scheduling already unified; trial-week notifications already cadence-aware.

---

## Top 3 P0 features required for Day-2-review survival

1. **#1 Weekly dose log + injection-day reminder** — non-negotiable. Every GLP-1 app has this; users open the app expecting it within the first 30 seconds.
2. **#2 Injection-site rotation map** — visual body diagram is now the table-stakes signal. Text dropdown is not enough.
3. **#9 Protein floor (1.2 g/kg)** — without elevating protein as primary macro, food rail looks like a generic calorie tracker.

## Top 3 P1 features that beat Shotsy + MeAgain on differentiation

1. **#13 Cohort-specific Jeni voice + 8-12 GLP-1 lessons** — Shotsy has no voice. MeAgain's Capy is cute but generic. JeniFit's existing brand voice is uniquely suited.
2. **#8 Injection-day eating mode** — first app to flip the food rail register based on dose cadence.
3. **#15 Off-ramp readiness module** — Embla is the only validated off-ramp in market and it's enterprise-only. Consumer space is open.

---

## Phase 3 sequence (weeks 6-10)

**Week 6 — P0 floor, ship together as v1.1:**
- Day 1-2: #1 Weekly dose log + reminder
- Day 3-4: #2 Site rotation map
- Day 5: #3 Side-effect log (extend SessionRatings schema)
- Day 6-7: #9 Protein floor flip + cohort-flag routing

**Week 7 — Differentiation:**
- Day 1-3: #13 Cohort-specific Jeni lessons (writing-heavy)
- Day 4-5: #8 Injection-day eating mode
- Day 6-7: #16 Dose-cadence notification register

**Week 8 — Muscle + comfort:**
- Day 1-2: #5 Nausea-rescue protocol
- Day 3: #6 Hair-shedding correlation trigger
- Day 4-5: #10 Hydration anchor + Home strip
- Day 6-7: #11 Resistance routines (3 new templates)

**Week 9 — Off-ramp + polish:**
- Day 1-3: #15 Off-ramp module (4 lessons + provider gate)
- Day 4: #12 Lean body mass HealthKit sync
- Day 5: #4 Dose-history timeline
- Day 6-7: QA + cohort-onboarding question wiring

**Week 10 — Deferred / v1.2:**
- #7 GI-pattern correlation (slip to v1.2 OK)
- #14 Sister-cohort community (defer unless founder commits to moderation)

---

## Apple guideline notes (binding constraints)

- **5.2.1 IP/trademark:** cannot use Ozempic, Wegovy, Mounjaro, Zepbound in app name, subtitle, keywords, screenshots, or marketing copy. Use "GLP-1," "weekly shot," "your medication." Brand names OK inside the app when entered/selected by user.
- **1.4.1 medical device:** app must not present as a medical device. "Self-tracking journal," "comfort tips," "patterns other users have noticed" — never prescriptive.
- **HealthKit** fully available for hydration, lean mass, body fat %, protein.
- **No telehealth, no Rx, no clinical staff** — all guidance patient-experience-shaped.

---

## Sources

- [Shotsy App Review 2026 — Metabolic Health Today](https://www.glp1muscleloss.com/articles/shotsy-review/)
- [6 Best GLP-1 Tracking Apps Compared 2026 — LearnMuscles](https://learnmuscles.com/blog/2025/11/27/6-best-glp-1-tracking-apps-compared-which-app-actually-works-in-2026/)
- [MeAgain Ranked #1 GLP-1 Tracking App for 2026 — OpenPR](https://www.openpr.com/news/4305825/meagain-ranked-the-1-glp-1-tracking-app-for-2026)
- [Lina All-In-One GLP-1 App](https://findlina.com/)
- [Pep GLP-1 Tracker](https://pepglp1.com/)
- [Peachy Progress](https://apps.apple.com/us/app/-/id6757675502)
- [Embla Embrace](https://www.joinembla.com/us/embrace)
- [MyNetDiary GLP-1 Companion launch](https://www.prnewswire.com/news-releases/mynetdiary-launches-glp-1-companion-for-ozempic-wegovy-and-mounjaro-users-302761158.html)
- [Noom GLP-1 Review 2026](https://www.nutritionnc.com/glp-1/reviews/noom/)
- [Virta Health Off-Ramp Survey 2025](https://www.businesswire.com/news/home/20250611310088/en/Virta-Health-Survey-Reveals-Secret-to-Lasting-Weight-Loss-After-GLP-1s-Users-Who-Follow-a-Guided-Off-ramp-are-8x-More-Likely-to-Continue-Losing-Weight)
- [Cell Reports Medicine 2026 — Muscle Loss on GLP-1](https://www.cell.com/cell-reports-medicine/fulltext/S2666-3791(26)00082-0)
- [TrimRX — What to Eat Before Zepbound Injection](https://trimrx.com/blog/what-to-eat-before-your-zepbound-injection-a-comprehensive-guide/)
- [diatribe.org — Navigating Nausea on a GLP-1](https://diatribe.org/diet-and-nutrition/7-tips-navigating-nausea-glp-1-medicine)
- [Cleveland Clinic GLP-1 Diet](https://my.clevelandclinic.org/watch/glp-1-diet)
- [Mounjaro Missed Dose — Pharmacy Planet](https://www.pharmacyplanet.com/blog/post/what-to-do-if-you-miss-your-mounjaro-dose-step-by-step-recovery-guide)
- [Mochi Health — When to Titrate Up](https://joinmochi.com/blog/when-to-titrate-up-on-your-glp-1-dose-signs-you-re-ready-for-the-next-step)
- [Hair Loss on GLP-1 — AOL](https://aol.com/hair-came-clumps-weight-loss-205432978.html)
