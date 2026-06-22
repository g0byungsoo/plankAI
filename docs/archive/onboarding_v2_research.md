# JeniFit onboarding v2 — research + audit synthesis

> Produced 2026-05-31 during the v2 onboarding redesign discovery phase.
> Two parallel research agents: (1) strategic synthesis on Gen-Z women WL
> psychology + competitor onboarding patterns + credible-WL-program data
> fields + conversion UX patterns; (2) audit of every current onboarding
> screen tagging kill/keep/consolidate/missing. This doc is the canonical
> reference both agents produced — strategic proposal lives separately.

---

## Section 1 — Gen-Z women & paid weight-loss apps: psychology synthesis

**What this cohort actually believes about weight loss in 2025–2026.** The dominant fact about Gen-Z women's relationship with WL in 2026 is *cognitive dissonance*. Survey data shows 56% of Gen-Z believes the rise of GLP-1s has *negatively* impacted self-image — yet 30% of Gen-Z women intend to use GLP-1s themselves, vs. 20% of men ([StudyFinds, 2025](https://studyfinds.org/gen-z-ozempic/); [News-Medical, 2025](https://www.news-medical.net/news/20250424/Whate28099s-behind-Gen-Ze28099s-skepticism-about-Ozempic-and-Wegovy.aspx)). They were raised on body-positivity messaging and now live inside a cultural backlash against it ([Irish Times, 2026](https://www.irishtimes.com/life-style/people/2026/01/17/how-the-rise-of-ozempic-is-reversing-the-progress-on-body-positivity/)). The result is a posture I'll call **"results without the receipts."** They want weight loss; they refuse to be seen wanting it the way their mothers wanted it.

The "soft girl" wellness movement and the 60-Day Soft Challenge codify this: "transform gently, reshape your identity, actually sustainable, nervous system focused" ([TikTok #60DaySoftChallenge](https://www.tiktok.com/discover/60-day-soft-challenge)). The frame is identity transformation, not weight subtraction. Diet culture researchers have noted that wellness-coded language is now functioning as "diet culture 3.0" — restrictive practices laundered through self-care vocabulary ([SonderMind, 2025](https://www.sondermind.com/resources/articles-and-content/body-image/)). The app that wins is the one that gives them the *outcome* of WL programs while using the *language* of identity programs.

**What makes them pay vs. stay free on TikTok.** 44% of regularly exercising Gen-Z already pay for fitness apps; 65%+ use wellness apps and trackers ([Intenza, 2025](https://www.intenzafitness.com/fitness-industry/top-5-gen-z-fitness-industry-trends-what-gym-owners-need-to-know-2025/)). Paid subscription is not a barrier for this cohort — *commodity* subscription is. The decision to pay is not "this content is better than TikTok content," it's **"this one is for me, specifically, and I am the kind of person who pays for her own becoming."** Paying is itself the identity transaction. Accenture's 2025 framework lists "social currency" — how shareable a purchase is — as one of five top Gen-Z purchase metrics ([GWI](https://www.gwi.com/blog/gen-z-spending-habits)).

Credibility signals that justify the purchase: peer-reviewed citations (ZOE's PREDICT studies playbook — [ZOE Learn](https://zoe.com/learn/zoe-2-0-science-made-simple)), founder-led intimacy, a number the user generates herself in the onboarding (her own plank time, her own projected curve), and concrete time-to-outcome language. The reveal needs to *land on her data*, not generic claims.

**What kills conversion for this cohort.** Five tripwires, ranked by destructive force in 2026:
1. **Bro-fitness labor verbs** ("crush", "burn", "torch", "shred", "annihilate"). These read as masculine, performative, 2018-coded.
2. **Fake-AI personas** ("Meet Aria, your AI coach!"). Post-ChatGPT, AI personas read as cheap. JeniFit's brand-locked anti-AI-language stance is correct.
3. **Before/after grids on opening screens.** TikTok itself has been moderating #SkinnyTok content, and Gen-Z self-reports active aversion to before/after framing while paradoxically engaging with it ([SonderMind](https://www.sondermind.com/resources/articles-and-content/body-image/)).
4. **Scale shame & BMI-as-verdict copy.** BMI is acceptable as *information* (AHA banding, contextualized); it is not acceptable as *judgment*.
5. **Generic "what's your goal" → carousel of stock generic answers.** TikTok-acquired users are pattern-matched to recognize template funnels in the first 3 screens and will close-tab.

**TikTok-acquired funnel behavior.** This is a high-intent, low-patience cohort. They were one tap from a creator video to your App Store page — they expect *creator-level intimacy* (specific, personal, with-you-in-the-room voice) and *concrete data* (numbers, not vibes), and they will tolerate a long flow *only if every screen earns the next*. The Noom 113-screen / 10–15 min flow works because **every screen returns value or commitment** — never both off ([Growth Waves, 2026](https://growthwaves.substack.com/p/the-113-screen-onboarding-that-doesnt); [RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)). Patience here is conditional, not generous.

**Identity-purchase psychology — what creates "this is built for me."** Three concrete mechanics:
- **Self-generated artifacts.** The user produces a number (baseline plank), a silhouette pick, a barrier statement. The app then mirrors these back. The artifact *is* the bond.
- **Naming the contradiction.** "You've tried before. It didn't last. That wasn't a you problem — it was a fit problem." Cohort-specific empathy beats generic empathy.
- **Concrete time-bound projection grounded in her inputs.** Noom's chart that updates as she answers is the canonical example ([The Behavioral Scientist](https://www.thebehavioralscientist.com/articles/noom-product-critique-onboarding)).

---

## Section 2 — Competitive onboarding audit

**Noom (~113 screens, 10–15 min).** Categories: demographics, biometrics, lifestyle, eating patterns, psychology (CBT-leaning), historical attempts, identity. Signature personalization moment: the **dynamic projected-weight curve that updates as she answers** — and the "building your plan" loading screens with per-section progress bars ([RevenueCat teardown](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)). Data investment pattern: soft questions first (goal, why now), biometrics in the *middle* once she's already invested. Conversion patterns to steal: sensitive questions are framed *on the same screen* with the reason ("hormones affect how we metabolize food — that's why we ask"); positive reinforcement messages after vulnerable disclosures (weight, conditions); pricing reveal only after sunk-cost investment. Boomer-coded risk: occasional CBT-jargon screens that read clinical. ([The Behavioral Scientist](https://www.thebehavioralscientist.com/articles/noom-product-critique-onboarding))

**Simple (~5–8 min, much shorter than Noom).** Categories: goals, eating window, lifestyle, fasting comfort. Signature moment: the *adjustable* fasting schedule recommendation — explicitly tunable, which the behavior-design literature notes reduces early dropout ([Autonomous.ai review](https://www.autonomous.ai/ourblog/simple-app-review-for-weight-loss-and-intermittent-fasting)). Smart pattern: conservative, sustainability-coded framing (12–16h windows, not 20h hero numbers). Worth stealing: **the "what we recommend, with knobs" pattern** — gives the user a number AND agency.

**Cal AI (heavily A/B tested, conversion-machine).** Cal AI's stated principle: "by adding questions that did not impact functionality but increased user engagement, we improved conversion." They moved **sign-in to the end** to reduce early friction, and ran 123 paywall experiments across 46 trigger points to lift trial-to-paid 31% ([Superwall case study](https://superwall.com/case-studies/cal-ai); [getlatka](https://getlatka.com/blog/how-cal-ai-achieved-35-million-revenue-in-just-one-year/)). Pattern to steal: **investment-only questions** that exist to deepen commitment, not to inform the plan; **camera-permission ask integrated with a teaser of the food-photo demo** is their identity-anchor moment.

**BetterMe (~26 questions, "marathon designed to make you feel seen").** Categories: demographics, goals, lifestyle, body focus, eating, health conditions. Signature moment: **demographic-matched social-proof trust screens** ("Over 500,000 women in their 30s have already tried BetterMe") ([App Fuel teardown](https://theappfuel.com/examples/bettermefitness_onboarding); [Heyflow](https://heyflow.com/blog/5-weight-loss-funnel-examples/)). Data investment pattern: short-question / short-answer cadence keeps the long flow tolerable. Hard quiz-to-paywall — 100% value gated. Cohort risk: occasional "lose 10lb in 30 days" copy that reads aggressive for the JeniFit aesthetic.

**Lasta (Gen-Z-leaning, women-focused).** Signature moment: **tappable body silhouette for target zones** — the user physically touches her body on the model, which is a strong identity-as-data move ([ScreensDesign](https://screensdesign.com/showcase/lasta-healthy-weight-loss)). 28-day plan framing taps Gen-Z's preference for *finite, sustainable* challenges over open-ended programs. Worth stealing: interactive (tap/draw/slide) inputs as commitment devices.

**ZOE.** Categories: extremely science-heavy — gut/microbiome leaning, blood-sugar leaning. Signature moment: **citations to peer-reviewed papers (Lancet, Nature Medicine) baked into onboarding screens** as the credibility purchase ([ZOE 2.0](https://zoe.com/learn/zoe-2-0-science-made-simple); [Oxford Scientist](https://oxsci.org/the-promises-of-personalised-nutrition/)). Worth stealing: **inline citation chips** to license the brand as evidence-based without breaking the tone.

**Lose It / MyFitnessPal.** Light onboarding (~5 questions), classic biometrics-and-go. Both prioritize logging-velocity over identity-formation ([Calorie Tracker Buddy](https://calorietrackerbuddy.com/blog/lose-it-vs-myfitnesspal-complete-2026-comparison/)). They are the **wrong** model for JeniFit — they sell a *tool*, JeniFit sells a *becoming*. Note as a counter-example.

---

## Section 3 — Data fields a credible "actual WL program" collects

Marked **MUST** (credibility-load-bearing) or **NICE** (depth + future-feature priming).

**Biometric basics** (already collected): sex, age, height, current weight, goal weight — **MUST**.

**Energy expenditure inputs:**
- Activity level (collected) — **MUST**.
- Body-composition signal (frame size, muscle-mass self-perception, or recent strength training history) — **NICE**, primes future body-scan rail; improves TDEE accuracy beyond Harris-Benedict.
- Step-count baseline (now collectible via HealthKit per the steps rail) — **MUST** as TDEE input, plus identity anchor.

**Eating patterns (currently blank, the biggest credibility gap):**
- Typical meals/day + eating window — **MUST**. Both inform calorie distribution and prime IF/fasting framing later.
- Late-night eating frequency — **MUST**. Top predictor of WL stall.
- Emotional eating frequency / trigger — **MUST**. CBT/Noom's core wedge.
- Restrictive history (have you done keto/IF/1200-cal/etc.) — **MUST**. Determines whether you can credibly say "this won't be another diet."
- Kitchen access + cooking frequency — **NICE**, primes future calorie tracking ("we'll meet you where you eat" framing).

**Sleep & stress** (entirely uncollected, evidence-load-bearing):
- Sleep duration band — **MUST**. <6h doubles WL failure rate ([NHANES analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC4861065/); [LIFE study](https://pmc.ncbi.nlm.nih.gov/articles/PMC3136584/)).
- Perceived stress level (1-item single-question proxy for PSS-4) — **MUST**.
- Sleep quality (1-item PSQI proxy) — **NICE**.

**Hormonal signals:**
- Menstrual cycle awareness / regularity / tracking — **NICE-bordering-MUST** for this cohort; cycle-syncing is a 2026 mainstream wellness conversation ([Cycle Diet review](https://domental.com/blog/cycle-diet-app-review-the-best-weight-loss-app-for-women-in-2026); [FitrWoman](https://apps.apple.com/us/app/fitrwoman/id1189050449)).
- GLP-1 use (current/considering/no) — **MUST** in 2026. Post-Ozempic-aware brand cannot pretend this user doesn't exist. Allows non-judgmental segmentation.
- Postpartum / breastfeeding / perimenopause flag (single skip-friendly question) — **NICE**, huge for the 28–35 segment.

**Behavior-change readiness (Prochaska Stages of Change):**
- Previous WL attempts: how many, what derailed — **MUST**. ([Frontiers review](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.00511/full))
- Readiness stage proxy ("how soon do you want to start changing?") — **NICE**, lets the plan calibrate intensity.
- Identification of one previous "what worked" — **MUST**. Self-efficacy anchor; the user surfaces her own evidence.

**Social/environmental:**
- Household composition (alone / partner / kids / roommates) — **NICE**. Predicts schedule chaos and food environment.
- Schedule volatility / travel frequency — **NICE**, plan-adaptation input.

**Identity & food-relationship:**
- "Food is fuel" vs "food is comfort" vs "food is love" lean — **MUST**. Determines whether messaging tilts mechanical or affective.
- Weight-as-self-worth attachment (single dial, not interrogation) — **NICE**, calibrates anti-shame messaging dose.

**Forward-looking primers for calorie tracking + body scan (without naming the features):**
- Kitchen access + cooking → primes food-photo rail later ("we'll figure out what you actually eat, with you").
- Silhouette current → silhouette goal (already collected) → primes body-scan ("we'll see the shape change, not just the number").
- "What does the version of you you're becoming look like?" — open-text or silhouette → seeds future before/after replacement (private body-scan view rather than public grid).

---

## Section 4 — UX patterns that drive WL onboarding conversion

**The plan-reveal moment.** Lands when: (a) numbers come from *her* inputs, (b) there's a projection curve with a specific date, (c) it's wrapped in research citation (a single inline reference, not a wall of text), and (d) there's a tonal release — an affirmation, not a "PURCHASE NOW." Falls flat when: numbers are obviously generic, the curve is the same shape every user gets, or it leads directly into a hard paywall without a breath. Noom's chart-that-updates is the gold standard ([RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)).

**Commitment-device questions.** These are questions where *the act of answering* is the commitment — the answer doesn't drive the algorithm, it drives her sense of having opted in. Noom's "what would you sacrifice" is the canonical example. For JeniFit: "what does she look like 3 months from now" (open-ended), "what's one thing you'll stop saying to yourself," "what does today-you owe future-you." These have to feel like journaling, not interrogation. Cal AI explicitly states they add questions that don't change the product but increase commitment ([Superwall](https://superwall.com/case-studies/cal-ai)).

**The fake-loading personalization theater.** Works when: (a) segments are labeled and check off in sequence — "analyzing eating patterns ✓, calibrating to your cycle ✓, projecting your curve ✓" — so the loading *narrates the personalization*, and (b) the user has already answered enough that she believes there's something to compute. Backfires for TikTok-acquired users when: (a) it's a single 30-second blob with no progress segments, (b) it follows too few questions to be plausible, or (c) it's longer than ~12–15 seconds without visible motion. Keep it segmented and capped ~10–15s.

**Asking biometrics — placement.** The proven pattern: **soft questions first** (goal, motivation, name), **identity questions next** (silhouette, body focus, barriers), **biometrics in the middle** (height, weight, age — after she's already invested 6–10 screens), **vulnerability last** (cycle, GLP-1, emotional eating — when she trusts the container). Asking weight on screen 2 of 60 is a common funnel killer.

**Trust anchors without breaking lowercase voice.** Inline citation chips ("WHO 2020", "stanford 2023", "lancet 2022") rendered small and lowercased; founder voice screens with a single Fraunces-italic sentence; the occasional "we built this because" interstitial. Ban: stock white-coat photos, "AI-powered" claims, fake doctor endorsements. ZOE makes citations work via volume and consistency; JeniFit makes them work via *restraint* — one chip per screen, max.

**Negative-space patterns.** Slow down with affirmations after vulnerable inputs (weight, GLP-1, emotional eating), and after identity inputs (silhouette pick, "the version of you you're becoming"). Chain rapid-fire screens for low-stakes inputs (yes/no relatability cards). The rhythm should breathe — heavy → light → heavy → light, never 12 heavy screens in a row.

**Paywall priming.** The reveal sequence that converts on this cohort: **(1)** projection card with her data + a date, **(2)** plan summary in 3–4 bullets including the sensitive-but-respected inputs (so she sees her vulnerability was *used*, not ignored), **(3)** a 3-row trial timeline (already in JeniFit's 2026 paywall principles), **(4)** soft CTA "continue", **(5)** anti-shame terminal line. Never lead with the price. ([Growth Waves](https://growthwaves.substack.com/p/the-113-screen-onboarding-that-doesnt))

**What NOT to do:**
- "Crush", "burn", "torch", "shred", "smash" — any labor/violence verb.
- AI-persona names ("Meet Aria!").
- Before/after image grids.
- BMI-as-verdict screens (BMI as banded info, with anti-shame caption, is fine — JeniFit already does this).
- Quiz-show celebration sounds / excessive confetti — saccharine, reads childish.
- Scale-shame copy ("your weight is unhealthy") — informational framing only.
- Generic "what's your goal" with 6 stock options — replace with at least one user-generated artifact early.

---

## Section 5 — Audit of current v1 onboarding (kill/keep/consolidate/missing)

### Executive summary

**Counts.** Of 28 actual question screens audited: **12 KEEP** (load-bearing for WorkoutGenerator, Becoming-tab analytics, paywall headline, notification scheduling, or analytics weight chart), **8 CONSOLIDATE** (duplicate signal already captured by an earlier question), **8 WEAK** (collected but no downstream consumer — pure decoration or self-described "sunk-cost lift"), plus **10 MISSING** rows added below.

**Three most surprising redundancies.**

1. **Q1 "what are we becoming"** and **Q110 "tap where you want to feel it"** are asking the same thing twice — `goal` (loseWeight / fullBody / toneCore / growGlutes / slimLegs) overlaps almost perfectly with `bodyFocus` (flatBelly / tonedArms / roundButt / slimLegs / fullBody). PlankAIApp explicitly notes `focusArea` is the "legacy lossy mapping" and `bodyFocus` is "the truthful answer" — yet both still ship, and PaywallView reads `bodyFocus.first` while the engine pipeline reads `focusArea`.

2. **Q2 "honestly, how's it going"** (experience) and **Q8 activity level slider** and **Q238 "outside of workouts how much do you move"** all overlap heavily — the third is session-scope only and never read again, but Q2 + Q8 are both fed into WorkoutGenerator's startingTier where they could plausibly collapse to one calibrated question.

3. **Q237 (eatingContext), Q238 (dailyActivityLevel), Q239 (bodyPhotoReadiness), Q235 (monthSignals), Q236 (priorWorkouts)** are all explicitly tagged in the source as `// Session-scope ONLY — NOT persisted, NOT consumed by WorkoutGenerator. The sole purpose in v1.0.7 is (a) sunk-cost lift and (b) plan-reveal echo personalization`. **Five questions exist purely to make the user feel heard but persist no signal.** The most credible WL program will want one or two of these (eating, sleep) really persisted, not five fake ones.

**Single most valuable MISSING field. Sleep duration & quality.** Cortisol regulation is the load-bearing mechanism in JeniFit's breathwork module and the scientific honesty of the WL positioning. JeniFit already cites Balban (Stanford), Epel (Yale), Meerman (BMJ) for cortisol — but doesn't actually ask the user the variable that drives those mechanisms most. A 5-second sleep question would feed: paywall headline ("your body fights weight loss when it's underslept"), notification copy (morning vs. evening calibration when sleep is short), Becoming-tab cortisol education, and post-purchase rail logic when sleep tracking ships.

### Audit table

| Case # | Title (short) | What it asks | State field(s) written | Downstream usage | Tag |
|---|---|---|---|---|---|
| 0 | Welcome | n/a — video hero + CTA | none | UI only | KEEP |
| 1 | Becoming goal | "what are we becoming?" loseWeight/fullBody/toneCore/growGlutes/slimLegs | `goal` → `UserDefaults("userMotivation")` | PaywallView headline copy fallback; `UserRecord.onboardingGoal` (stored but no reader); CoachIntro copy | CONSOLIDATE (overlaps Q110 bodyFocus — and bodyFocus is "the truthful answer" per source) |
| 100 | Attribution | "how did you hear about jenifit?" tiktok/ig/friend/etc | `acquisitionSource` | `UserRecord.onboardingAcquisitionSource` → Supabase. Source code says "this is the ONE signal we have for which creator/post is converting" | KEEP (only attribution signal for $0 CAC org TikTok funnel) |
| 110 | Body focus (multi) | "tap where you want to feel it" flatBelly/tonedArms/roundButt/slimLegs/fullBody | `bodyFocus` Set | **WorkoutGenerator.Input.bodyFocus** (load-bearing — drives every workout); `@AppStorage("bodyFocus")` → PaywallView headline + ProfileHub + EditProfile | KEEP (most load-bearing question in the flow) |
| 111 | Real reason | "what's the real reason — be honest" getShaped/lookBetter/summer/confidence/selfLove | `motivation` | `UserRecord.onboardingMotivation` → AnalyticsView reads it for one copy switch (line 618); otherwise unused | WEAK (drives one line of analytics copy; could derive from Q1) |
| 2 | Training honesty | "honestly, how's it going right now?" never/gaveUp/sometimes/regular | `experience` | **WorkoutGenerator.startingTier** input (load-bearing); inline feedback copy | KEEP |
| 236 | What's worked before | "what's worked before — and what hasn't?" homeWorkouts/gym/classes/running/nothingStuck | `priorWorkouts` Set | **None.** Source: "Net-new question, also @State only — no DB change" | WEAK (session-scope sunk-cost lift only) |
| 8 | Activity level | 5-position slider sedentary→athlete | `activityLevel` + `activityLevelIndex` | **WorkoutGenerator.startingTier** input; goal date math in handleOnboardingComplete (±14 days for athlete/sedentary) | KEEP |
| 120 | Where will you train | home/gym/outdoor/either | `workoutLocation` | `UserRecord.onboardingWorkoutLocation` — **no reader anywhere**; coach voice copy at line 3669 references it but lookup is dead path | WEAK (persisted, never read by feature code) |
| 121 | Workout style (multi) | hiit/pilates/strength/yoga/dance/walking | `workoutStyle` Set | `UserRecord.onboardingWorkoutStyle` — **no reader anywhere** | WEAK (persisted, never read) |
| 25 | Session length | 5/10/15/20 minutes | `sessionLength` | **WorkoutGenerator.lengthMinutes** (load-bearing) via mapping; `@AppStorage("sessionLengthPref")` → EditProfile | KEEP |
| 17 | Commitment days | 3/5/7 days | `commitmentDays` | `@AppStorage("commitmentDays")`; `UserRecord.onboardingCommitmentDaysPerWeek`; consumed by streak goal & home subtitle | KEEP |
| 130 | Gender | female/male/nonbinary/private | `gender` | `UserRecord.onboardingGender` — **no reader anywhere** in feature code (despite "we adjust your plan based on this" copy) | WEAK (the sub-copy is a lie — nothing adjusts) |
| 7 | Age | wheel picker (years → ageRange bucket) | `ageYears` + `ageRange` | **WorkoutGenerator.startingTier** input (under18 / 55plus penalties); `@AppStorage("ageRange")` | KEEP |
| 131 | Height | slider cm/in | `heightCm` | Used **only** for the live BMI annotation on case 132 (in-screen ephemeral). `UserRecord.onboardingHeightCm` stored but never read by feature code | CONSOLIDATE (collected to render a card the user sees once; if BMI card stays, keep; otherwise kill) |
| 132 | Current weight | horizontal ruler kg/lb | `currentWeightKg` | **WeightLogRecord seed** (load-bearing — kicks off entire weight trend chart); paywall hero math; AnalyticsView weight chart; goal-pace math | KEEP |
| 133 | Goal weight | horizontal ruler kg/lb (band-visualized) | `goalWeightKg` | AnalyticsView WeightTrendChart goal line; paywall headline math; projection chart | KEEP |
| 134 | Body type current | 6-position visual slider Cut→Soft | `bodyTypeCurrent` | `UserRecord.onboardingBodyTypeCurrent` — **no reader anywhere** | WEAK (collected for emotional wedge / case 135 anchoring; never used post-onboarding) |
| 135 | Body type goal | 6-position visual slider (clamped to current) | `bodyTypeDesired` | `UserRecord.onboardingBodyTypeDesired` — **no reader anywhere** | WEAK (same as 134 — pure onboarding theater) |
| 140 | Identity feeling | powerful/calm/light/strong/radiant | `identityFeeling` | `@AppStorage("identityFeeling")` → JenisNoteCard copy personalization; AnalyticsView identity hero | KEEP |
| 235 | Month signals (multi) | "anything we should know about this month?" lowEnergy/cramps/sleepOff/greatDay/noneNow | `monthSignals` Set | **None.** Source: "Bundle E net-new optional context. NOT load-bearing… persisted to UserDefaults only, no schema change" | WEAK (session-scope only; the cycle data is the right idea but isn't actually wired) |
| 237 | Eating context (multi) | "what does eating feel like for most days?" | `eatingContext` Set | **None.** Source: "Session-scope ONLY — NOT persisted, NOT a Supabase column, NOT consumed" | WEAK (explicitly sunk-cost lift — replace with a real persisted eating question) |
| 238 | Daily activity (vision) | "outside of workouts, how much do you move?" | `dailyActivityLevel` | **None.** Same "session-scope only" tag | CONSOLIDATE (asks the same thing as Q8 in different words; both should not ship) |
| 239 | Photo readiness | "how do you feel about photos of yourself right now?" avoid/working_on/okay/like_them | `bodyPhotoReadiness` | **None.** Session-scope only | WEAK (sensitive ask with no payoff — drop or actually use to gate body-photo features) |
| 141 | Reward | "what's the reward when you hit the goal?" clothes/trip/photos/personal/treat | `rewardChoice` | `UserRecord.onboardingRewardChoice` — **no reader anywhere** | WEAK (Noom-pattern reciprocity beat; great UX moment but never referenced post-onboarding) |
| 150 | Barrier 1 (yes/no) | "Workout apps make me feel further from my body, not closer" | `relatability1` Bool | derives into `barriers` Set → **AnalyticsView Barrier-Resolved Card** (the only real reader) | CONSOLIDATE (collapse 3 yes/no screens into 1 multi-select; same downstream signal) |
| 151 | Barrier 2 (yes/no) | "I have no idea which workouts are right for me" | `relatability2` Bool | same — derived barrier | CONSOLIDATE |
| 152 | Barrier 3 (yes/no) | "I quit when something feels too hard or boring" | `relatability3` Bool | same — derived barrier | CONSOLIDATE |
| 3 | Plank baseline | "how long can you hold a plank?" under15/15-30/30-60/60+/notSure | `baseline` → baselineHoldSeconds | **WorkoutGenerator.startingTier** input (load-bearing); `@AppStorage("userBaselineSeconds")`; Becoming-tab Mastery Curve | KEEP |
| 11 | Notification time | morning/afternoon/evening/whenever | `plankTime` | **NotificationPermission.scheduleDailyReminder** (load-bearing — schedules canonical `daily_reminder`); `@AppStorage("plankTime")` | KEEP |
| 18 | Name input | text field | `name` | `UserRecord.name`; `@AppStorage("userName")`; everywhere | KEEP |
| 19 | Coach selector | encouraging/balanced/keepItReal | `voicePreference` | **VoiceCascade**, JenisNoteCard, paywall, settings, every voice cue (load-bearing) | KEEP |
| 5 | Legacy barriers (multi) | "What usually stops you?" boring/dontKnow/motivation/time/injury | `barriers` Set | `UserRecord.onboardingBarriers` → **AnalyticsView Barrier-Resolved Card** (genuine downstream reader, only one); `@AppStorage("userBarriers")` | KEEP — verify in flowOrder. Source comment marks 4/5/6/9/10/12-16 as "Legacy showcase screens (kept for Phase 5 reuse, not in flow)". If Q5 is unreachable, Q150-152 are the only barrier producers. |
| — | Educational interstitials | cases 200, 201, 202, 203, 204, 205 (section dividers); 206 (recap); 230, 231, 232, 233, 234 (anti-shame, body-primer, 5-min, cycle, plateau); 142 (comparison), 145 (video demo), 160 (reshape), 161 (first prediction), 170 (re-prediction), 180 (loading carousel), 181 (final prediction), 21 (plan reveal), 22 (personal stat), 23 (camera setup), 26 (sign-in), 215 (review prompt), 240 (brand promises), 250 (method preview), 260 (tier ladder), 270 (habit window quiz). Legacy unused: 4, 6, 9, 10, 12, 13, 14, 15, 16, 20. | none — all UI-only, no field writes | UI / engagement / commit-escalation only | KEEP as a group (reveal + commit-escalation is doing the conversion work; worth a separate compression audit later) |

### Missing — credible WL program rows to add

| Title | What it asks | Proposed downstream value |
|---|---|---|
| **Sleep duration** | "how much sleep do you typically get?" <5 / 5-6 / 6-7 / 7-8 / 8+ hrs | Cortisol-honest WL framing in paywall + Becoming tab; notification timing (morning workout warning if <6h); future Apple Health sleep rail |
| **Stress level** | "what's stress like for you right now?" low / manageable / heavy / overwhelmed | Calibrate breathwork primer prominence; gate intensity recommendations; cortisol education target |
| **Eating window / cadence** | "what does a typical eating day look like?" 1 meal / 2 meals / 3 meals / grazing — and "when do you stop eating?" | Replaces session-scope Q237 with a persisted version; foundational for the food rail |
| **Hunger pattern** | "when do cravings hit hardest?" morning / afternoon / late night / steady | Calibrate notification timing; food rail content sequencing |
| **GLP-1 / medication status** | "are you currently on any weight-related medication?" yes / no / considering / prefer not to say | Massive 2026 segment (Ozempic). Different progress framing, different paywall copy, anti-shame disclosure baseline. |
| **Hormonal stage** | "what stage are you in?" cycling regularly / perimenopause / postmenopause / pregnant/postpartum / prefer not to say | The 22-35 women target audience straddles two hormonal contexts; calibrates expectations + Becoming tab projections |
| **Previous WL attempts** | "how many serious attempts in the last 3 years?" 0 / 1-2 / 3-5 / lost count | Plateau frame + expectations + paywall reciprocity ("we've been there") |
| **Household / cooking** | "who cooks at home?" me / partner / mix / mostly eat out / family meals | Future food rail content scope; realistic expectations |
| **Schedule type** | "what does your week look like?" 9-5 office / shift work / remote / student / caregiver / variable | Calibrate workout scheduling, notification time, session length recommendation |
| **Motion baseline (Apple Health)** | "can we read your step count?" (paired ask, not text Q) | Already shipping per project_steps_feature; surface the ask in onboarding instead of after first-run, so the 7,500 anchor calibrates from day 0 |

---

## Founder's read (research agent)

The single biggest lever in the redesign is closing the **credibility-as-actual-WL-program** gap — JeniFit currently asks for identity, body focus, and silhouette but does not ask the questions a credible WL program *must* ask (sleep, stress, eating patterns, emotional eating, previous-attempt history, cycle, GLP-1). The cohort knows the difference. Without those fields, the projection card and plan reveal are reading as identity theater on a fitness app; with them, the same reveal becomes "she actually built a program for me." Add 8–12 of the **MUST** fields above, place biometrics mid-flow rather than front-loaded, layer in one self-generated artifact (silhouette tap, baseline plank, or open-text "becoming" line) before each commitment moment, and gate the paywall behind a Noom-style segmented loading + projection reveal — and the upstream-of-paywall leak you've already diagnosed becomes a tractable, measurable conversion lift rather than a vibes problem. The brand voice constraints (lowercase, italic Fraunces, no labor verbs, anti-AI-language) are not a tax on this strategy — they are the *moat* that lets credibility-grade data collection feel like soft-girl self-care instead of clinical interrogation, which is the unique position no other app in the audit holds.

---

## Sources

- [RevenueCat — Inside Noom's Web-to-App Onboarding Funnel](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)
- [The Behavioral Scientist — Noom Product Critique: Onboarding](https://www.thebehavioralscientist.com/articles/noom-product-critique-onboarding)
- [Growth Waves — The 113-screen onboarding that doesn't feel long](https://growthwaves.substack.com/p/the-113-screen-onboarding-that-doesnt)
- [Superwall — How Cal AI scaled paywall experimentation](https://superwall.com/case-studies/cal-ai)
- [getlatka — How Cal AI Achieved $35M Revenue in One Year](https://getlatka.com/blog/how-cal-ai-achieved-35-million-revenue-in-just-one-year/)
- [App Fuel — BetterMe Fitness Onboarding teardown](https://theappfuel.com/examples/bettermefitness_onboarding)
- [Heyflow — 5 High-Converting Weight Loss App Funnel Examples](https://heyflow.com/blog/5-weight-loss-funnel-examples/)
- [ScreensDesign — Lasta: Healthy Weight Loss](https://screensdesign.com/showcase/lasta-healthy-weight-loss)
- [ZOE Learn — ZOE 2.0: Simpler Personalized Nutrition](https://zoe.com/learn/zoe-2-0-science-made-simple)
- [The Oxford Scientist — The promises of personalised nutrition: ZOE](https://oxsci.org/the-promises-of-personalised-nutrition/)
- [Autonomous.ai — Simple App Review](https://www.autonomous.ai/ourblog/simple-app-review-for-weight-loss-and-intermittent-fasting)
- [Calorie Tracker Buddy — Lose It vs MyFitnessPal 2026](https://calorietrackerbuddy.com/blog/lose-it-vs-myfitnesspal-complete-2026-comparison/)
- [News-Medical — Gen Z skepticism about Ozempic](https://www.news-medical.net/news/20250424/Whate28099s-behind-Gen-Ze28099s-skepticism-about-Ozempic-and-Wegovy.aspx)
- [StudyFinds — 37% of Gen Z going straight to Ozempic](https://studyfinds.org/gen-z-ozempic/)
- [Irish Times — Ozempic reversing body positivity progress](https://www.irishtimes.com/life-style/people/2026/01/17/how-the-rise-of-ozempic-is-reversing-the-progress-on-body-positivity/)
- [SonderMind — From SkinnyTok to Ozempic: Body Image](https://www.sondermind.com/resources/articles-and-content/body-image/)
- [TikTok — 60 Day Soft Challenge](https://www.tiktok.com/discover/60-day-soft-challenge)
- [Intenza — Top 5 Gen Z Fitness Trends 2025](https://www.intenzafitness.com/fitness-industry/top-5-gen-z-fitness-industry-trends-what-gym-owners-need-to-know-2025/)
- [GWI — Gen Z Spending Habits 2025](https://www.gwi.com/blog/gen-z-spending-habits)
- [PMC — Sleep Quality and Weight Loss in Women](https://pmc.ncbi.nlm.nih.gov/articles/PMC4861065/)
- [PMC — Sleep, stress, depression in LIFE weight loss study](https://pmc.ncbi.nlm.nih.gov/articles/PMC3136584/)
- [Frontiers in Psychology — Assessing motivation/readiness for weight management](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.00511/full)
- [domental — Cycle Diet App Review 2026](https://domental.com/blog/cycle-diet-app-review-the-best-weight-loss-app-for-women-in-2026)
