# What makes digital behavior-change content genuinely interactive (and does it work?)

Research pass: 2026-07-06. For the app v4 method rebuild.
Context: the JeniFit Method today is passive CBT-style reading (99% reach, 19% completion).
Question: what does evidence + the best 2025-2026 shipping products say about interactive
practice vs didactic reading, and which atomic interactions fit a 20-60s daily practice?

Evidence labels used throughout:
- **[strong]** — RCT(s) or meta-analysis
- **[moderate]** — large observational, secondary analysis, single small RCT, systematic review without meta
- **[weak]** — pilot, exploratory, cross-sectional
- **[product-fact]** — verified description of a shipping product (no outcome claim)
- **[first-party]** — company's own number; treat as marketing until independently replicated

Nothing below is an invented citation. Where I could not verify something, it says so.

---

## LANE 1 — Evidence

### 1.1 Does "doing" beat "reading" in digital CBT? Yes — with one big nuance

**The single best anchor: Chien et al., JAMA Network Open, July 2020** (N=54,604 users of
SilverCloud's Space from Depression and Anxiety iCBT; ML latent-class analysis of 14-week
engagement; full text read for this report). **[moderate — huge N, observational]**
- 5 engagement subtypes. Clinical improvement was **not proportional to time spent**.
- Class 3 ("high engagers with rapid disengagement," 25.5% of users) had the **largest PHQ-9
  improvement (−6.65)** despite spending *less* time than classes 4/5. Their signature: early
  use of the **active CBT tools** — Understanding Feelings, Spotting Thoughts, Challenging
  Thoughts, Boosting Behaviour (OR 1.31, p<.001) — i.e., they did the exercises fast and left.
- Class 4 (good outcomes, d=−0.61 vs low engagers) was *more* likely to use introspective
  quizzes (Core Beliefs Quiz OR 1.93; "What's Your Lens?" OR 1.28) and **less likely to use
  the reading-heavy psychoeducation sections** ("Depression: Myths and Facts" OR 0.44;
  "Anxiety: Myths and Facts" OR 0.40).
- Class 1 (low engagers, worst outcomes: 39.5% reliable improvement vs 66.9% for the top
  class) gravitated to **mood monitoring and worry content** and avoided the doing-tools
  (Activity Scheduling OR 0.57).
- Authors' conclusion: "effective engagement may not be determined merely by absolute
  engagement with the program, but also by what particular sections or elements a patient
  engages with" — the active treatment ingredients.
- Read-across for JeniFit: reach ≠ method. Users who *answer/challenge/schedule* improve;
  users who *read and monitor* don't. This is the founder's verdict, quantified at N=54k.

**Guided vs unguided iCBT — Karyotaki et al., JAMA Psychiatry 2021** (IPD network
meta-analysis, 39 trials, 9,751 participants). **[strong]** Guided beats unguided for
moderate-to-severe depression; for **mild/subthreshold symptoms unguided works about as
well**. Read-across: JeniFit's non-clinical audience does not need a human in the loop for
the method to work — good news for a self-serve interactive method.

**Engagement→outcome link: systematic review + meta (PMC8599127, 2021).** Greater
engagement with digital mental-health interventions is significantly associated with better
outcomes across correlational and between-group designs. **[moderate — association, not
causation]**

**The nuance — gamification is not the lever: Valentine et al., npj Digital Medicine, 2025**
(meta-analysis of 92 mental-health app RCTs, 16,728 participants). Apps beat controls
overall (g = 0.43), but **no significant association between the number/type of persuasive
design principles and either efficacy or engagement**. **[strong]** Read-across: adding XP,
badges, streak mechanics does not itself buy outcomes or retention. What the user *practices*
matters; the points don't.

**Answering beats rereading (education literature): Adesope et al., Review of Educational
Research 2017** — meta of 217 studies on retrieval practice: **g = 0.61** vs restudying/
rereading; a single embedded practice test g ≈ 0.70; mixed question formats strongest.
**[strong, education domain — the mechanism Imprint productized]**

### 1.2 Implementation intentions (if-then planning) digitized — what FORM works

- Canonical anchor: Gollwitzer & Sheeran's 2006 meta (94 studies, d ≈ 0.65 on goal
  attainment) is the lineage everything cites. **[strong, pre-2020 canonical]**
- **Menu-picked ≈ self-authored.** Armitage's randomized trial on alcohol (PubMed 19751080,
  2009): experimenter-provided if-then plans were **as effective as self-generated ones**;
  merely *choosing* a provided plan worked as well as writing one out. **[moderate]** A
  strand of later work finds guided formation beats fully free-form. Implication: a
  **pick-from-menu plan builder with 1-2 personalization slots** is evidence-defensible and
  much lower friction than a blank text box.
- **In a weight-management app specifically: JMIR mHealth 2025 (e65260; N=200, 2×2×4
  experiment, data collected late 2023).** Forming if-then plans did **not** beat simple tips
  on 2-week strategy adherence overall (71% vs 72%, ns) — but **helped users with poor
  planning skills** (moderation p=.04). Also: **brief info ≥ detailed info** (74% vs 69%
  adherence, d=0.24, ns trend favoring brief). **[moderate]** Read-across: if-then builders
  are a targeting tool, not magic; and longer didactic content buys nothing.
- Imagery-reinforced implementation intentions increased physical-activity habit strength
  and behavior in a 2025 trial (PMC11920387) — pairing the if-then plan with a 10-20s
  **mental simulation of doing it** strengthens the effect. **[moderate]**
- Substance-use if-then meta (PubMed 32622228, 2020): small but reliable effects. **[strong,
  small effect]**

### 1.3 Urge surfing / craving tools digitized — what's newer than Mason 2018

- The flagship is still **Eat Right Now (Brewer): Mason et al., J Behav Med 2018** — 28-day
  app intervention, N=104 overweight/obese; **40% reduction in craving-related eating**,
  36% reduction in eating in response to negative emotions; delivered as short videos +
  in-the-moment exercises (~10 min/day). **[moderate — single-arm/small comparative; widely
  cited]** I found **no larger 2023-2026 RCT of ERN** in this pass — the 2018 paper is still
  what the product cites in 2026. Honest gap.
- **Imaginal retraining RCT (Moritz et al., 2019, PMC6883071):** a 2-3 minute mental
  exercise (imagine the craved food, then imaginally "throw it away" with a motor gesture)
  reduced high-calorie food craving in overweight/obese women vs control. **[moderate —
  single RCT, self-guided, very short exercise]** Notable because the *entire intervention*
  is a sub-3-minute interactive rep.
- **Cautionary null — BupaQuit pilot RCT (2021, N=425 smokers):** adding craving-management
  tools (distraction games, relaxation audio, tips) to a cessation app did **not** improve
  4-week quit rates (13.5% vs 15.7%, p=.58). Key detail: **only 23.1% of the intervention
  arm ever opened a craving aid.** **[moderate null]** Lesson: in-the-moment tools fail by
  *placement*, not concept — if the tool isn't reachable at the craving moment (lock screen,
  one tap, push-triggered), it doesn't exist.
- **Sunnyside "efficacy study" (Alcohol: Clinical & Experimental Research, Aug 2024):**
  analysis of 46,000 moderate-heavy drinkers using its SMS plan/track/coach loop; **33%
  average reduction in drinks over 12 weeks**. **[weak-moderate — company-linked,
  observational, no control; but peer-reviewed venue]**

### 1.4 Behavioral rehearsal / simulated decision practice — does it transfer?

- **Food go/no-go training** (tap for healthy, withhold for trigger foods): 2024 meta
  (Appetite; PubMed 38309625; 32 studies): reduces food consumption/choice **g = −0.21**
  overall, **g = −0.31** for single-session go/no-go. **[strong, small effect]** Short-term
  weight effects exist in some trials; a 2021-2023 imaging RCT found **no weight or caloric
  change at 12 weeks** despite neural changes. **[moderate]** Read-across: reflex-training
  games are real but small and fade — a garnish, not a method.
- **BCT umbrella review (2023, PMC10498822):** "behavior practice/rehearsal" ranks among the
  most promising behavior-change techniques in digital interventions for alcohol misuse.
  **[moderate]**
- **Single-session interventions (Schleider lineage):** digital SSIs are the purest test of
  "one interactive exercise, no course." Youth meta (eClinicalMedicine 2025; 15 RCTs):
  small effect on depressive symptoms, g = −0.12. Crowdsourced **megastudy** (Nature Human
  Behaviour, 2026; N=7,505 US adults, 12 digital SSIs): nearly all improved outcomes
  immediately post-completion (**d ≤ 0.37**), but **only two still moved depression at
  4-week follow-up (d = 0.14-0.15)**. **[strong]** Read-across: brief interactive exercises
  reliably create *immediate* state shifts; durability requires *repetition* — i.e., a daily
  rep structure, which is exactly JeniFit's frame.
- Direct evidence that *simulated* decision practice transfers to real eating decisions is
  thin; the go/no-go literature is the closest quantified case. I could not verify any 2024-26
  RCT of narrative "scenario practice" for eating behavior. Honest gap.

### 1.5 Self-monitoring reactivity + reflective prompts — does answering beat reading?

- **Digital dietary/activity self-monitoring supports weight loss:** Berry et al., Obesity
  Reviews 2021 systematic review + meta — digital self-monitoring associated with
  significant weight loss vs controls across trials; adherence declines steeply over time,
  and **detailed logging is perceived as burdensome** (simplified-logging pilots show
  comparable engagement). **[strong for the technique; moderate for the "keep it tiny" corollary]**
- **Question-behavior / mere-measurement effect:** Rodrigues et al. 2015 meta of 33 RCTs:
  asking about a behavior changes it, **SMD = 0.09** — real but small. **[strong, small]**
  Newer: mere-measurement meta of patient-reported outcomes (Quality of Life Research,
  2025): overall **RR 1.17** for behavior/perception change from being asked. **[strong,
  small]** Read-across: a daily answered question is a *floor* intervention — cheap, real,
  small; it needs to be the carrier of something stronger, not the whole method.
- RESiLIENT (below) also shows **self-monitoring alone was the control condition and was
  beaten by every skill arm** — answering a tracker is not the method either.

### 1.6 Cognitive restructuring digitized — the surprising ranking

- **RESiLIENT RCT (Furukawa group; Nature Medicine 2025; 50-week follow-up in BJPsych
  2026): the most important trial for "which CBT skill should an app teach."** Master
  protocol, **N=3,280 adults with subthreshold depression**, 4 factorial trials, 9 arms vs
  self-check control, all delivered via a smartphone CBT app. Result: **behavioral
  activation + assertion training had the greatest effect; behavioral insomnia therapy
  strong; cognitive restructuring effective but not top**. Skills prevented depression onset
  and reduced burden at 50 weeks. **[strong]**
  Read-across: an interactive method for JeniFit should be built around **doing-skills
  (tiny behavioral experiments, saying the hard thing, sleep behavior)** with cognitive
  reframing as one tool among several — not a reading course *about* thoughts.
- **Digitized thought records: practitioner review (the Cognitive Behaviour Therapist, Aug
  2022):** 15 cognitive-restructuring apps reviewed; **zero had direct efficacy studies**;
  best-practice design = sequential guided prompts, worked examples, and **emotion-intensity
  ratings before and after** the exercise (only 40% of apps close the loop by evaluating
  outcome). **[moderate]** The before/after emotion rating is the one element that both
  makes the exercise measurable and shows the user "it worked."
- AI-assisted thought records (T5 LLM flagging poorly-formed automatic thoughts, Cognitive
  Therapy and Research 2023): exploratory only. **[weak]** By 2026 the live version of this
  idea is conversational: JeniFit's chat can *be* the low-effort thought record.
- **Conversational delivery evidence:** Woebot's WB001 RCT (postpartum depression, reported
  2023-2025): Woebot + TAU beat TAU on PHQ-9; working alliance with the agent formed within
  ~5 days at levels comparable to outpatient CBT (retrospective analysis). **[moderate]**
  Read-across: choice-button + short-typed conversational CBT is a validated interactive
  form factor — and JeniFit already ships a chat surface.

### 1.7 Evidence synthesis — the interaction ladder

Ordered by what the evidence supports for a daily-practice method:

1. **Do a tiny real-world behavior and log it** (behavioral activation; RESiLIENT; Berry
   meta) — strongest outcome trail.
2. **Answer/choose inside content** (retrieval practice g=0.61; Chien quiz-affinity classes;
   SSI immediate d≤0.37) — turns reading into encoding; carries completion.
3. **Form an if-then plan by picking + personalizing** (Gollwitzer d≈0.65; Armitage
   menu=self-authored; helps poor planners most) — 15-second interaction, durable technique.
4. **In-the-moment urge tool** (ERN 40% craving-eating reduction; imaginal retraining) —
   works *if reachable at the moment* (BupaQuit null when buried).
5. **Before/after feeling rating around any exercise** (CR-app review best practice;
   mere-measurement RR 1.17) — small effect, but generates the "it worked" receipt.
6. **Reflex mini-games (go/no-go)** — real but small and fading (g≈−0.2); optional garnish.
7. **Passive psychoeducation** — the users who favor it improve least (Chien class 1);
   detailed info no better than brief (JMIR 2025).
8. **Gamification chrome (XP, badges, points)** — no association with efficacy or
   engagement at meta level (Valentine 2025). Style, not substance.

---

## LANE 2 — Product teardowns (2025-2026 state)

Format per product: **atomic interaction** (what the user actually does), session length,
how completion feels, premium-vs-childish notes. All **[product-fact]** unless labeled.

### 2.1 Imprint — the bar for "reading that feels active" (deep dive)

Google Play **App of the Year 2023** (confirmed via Google's Best-of-2023 announcement and
Imprint's own post). The reference grammar for interactive reading:

- **Atomic interaction: the tap.** A lesson is a stack of full-screen illustrated cards;
  each tap advances one *beat* — a sentence or two plus a purpose-built animated diagram
  that assembles as you arrive. The user controls pacing; nothing autoplays past them.
- **The second atom: embedded micro-checks.** Every few cards the lesson asks a question
  *inside the narrative* — tap one of 2-3 choices ("More"/"Less", predict-the-outcome,
  which-of-these), get instant visual right/wrong feedback, then the story continues.
  ScreensDesign's teardown: "knowledge checks are embedded directly within the lesson flow,
  feeling like a natural part of the learning process," not a quiz section at the end.
  This is retrieval practice (§1.1) productized.
- **Session length:** a chapter ≈ **2 minutes**; courses are stacks of chapters.
- **Completion feel:** progress bar per chapter, XP + streaks + milestone celebrations at
  the course level (per multiple 2025 reviews); cards **auto-save to a personal collection**
  ("frictionless saving") so finishing leaves an artifact.
- **Why it reads premium, not childish:** (a) bespoke editorial illustration per card — the
  visuals *are* the explanation, not decoration; (b) micro-checks are low-stakes, 2-option,
  in-voice — never "QUIZ TIME"; (c) typography-first cards with one idea each; (d) motion is
  functional (diagrams assemble to explain), not confetti. Monetization: ~25-step
  personalization onboarding → soft paywall, ~$87-125/yr.
- Known criticism (from a Headway-authored comparison — competitor bias flagged): shallow
  depth per topic, billing complaints, weak audio.

### 2.2 Ahead — micro-drills for emotions ("Duolingo for EQ")

Apple Design Award **finalist 2024** (confirmed via ADA finalist list); self-positioned on
Wefunder as "the Duolingo for emotional intelligence." **[first-party positioning]**
- **Atomic interaction:** 5-minute daily "session" = tap-through science bits + **interactive
  reflections** (tap-choice self-assessments about your own patterns, e.g. how you react
  when criticized) + "fun, short activities" applying the technique; builds a personal
  toolkit; badges; AI chat for pattern insight.
- The signature move: it constantly turns teaching into **"which of these is you?"** taps —
  self-referential choice instead of comprehension quiz. That keeps micro-checks
  adult-feeling: you're never graded on knowledge, you're describing yourself.
- Courses target one emotion (anger, procrastination, heartbreak). Completion = streak +
  journey progress.

### 2.3 Duolingo — the mechanical reference for session shape

- Lesson = **3-5 min**, ~10-15 micro-exercises, one interaction each (tap word tiles into
  order, pick the pair, type/speak short answers), persistent progress bar, per-answer
  haptic/sound feedback, end-of-lesson celebration + XP.
- Key 2023-2025 lesson from their own blog: they tried **shorter lessons and it hurt their
  "time spent learning well" metric** — there is a floor beneath which sessions stop
  teaching. Read-across: 20-60s works for *practice reps*, but a teaching beat probably
  needs the 2-min Imprint shape.
- What makes it feel childish (and fine for languages, wrong for JeniFit): mascot begging,
  guilt notifications, leaderboards. The *exercise loop* is the part worth stealing, not
  the chrome. (Valentine 2025 meta says the chrome isn't the active ingredient anyway.)

### 2.4 Noom — 2025 microhabits rebuild

- Sept 2025 (GlobeNewswire press release): free tier rebuilt around **"microhabits"** —
  tiny daily actions (healthy snack, step goal) with **"microwins"** celebrations, streaks,
  and real-world rewards (gift cards); Rebel Wilson named "Chief Wellness Ambassador"
  championing microhabits + microdose GLP-1s. Oct 2025: AI Face Scan + "Future Me" face
  aging/health visualization added free. **[first-party press]**
- The famous daily psychology lessons (10-min reading courses) remain in paid — but the
  strategic weight visibly moved from *curriculum* to *tiny logged actions + instant
  celebration*. Noom itself retreated from reading-as-the-product.

### 2.5 Reframe — alcohol (the cautionary twin)

- Core = **120-day neuroscience course, one short daily reading** + drink log + toolkit
  (craving "games," breathing, EFT tapping) + Zoom check-ins. ~$99.99/yr.
  **[first-party]** claim: "91% of users report reduced alcohol use within 3 months."
- Structurally this is JeniFit's current method (daily reading + tools on the side) — and
  its App Store reviews echo the same complaint pattern (reading fatigue mid-program).
  Useful as the anti-model: curriculum-first, practice-second.

### 2.6 Sunnyside — plan → check-in → coach, over SMS

- **Atomic interaction: the emoji reply.** Sunday = pre-commit a weekly drink plan; daily =
  a text asks how it's going; user replies with an emoji (on-track) or a word (need help →
  human coach). Weekly report converts adherence into sleep/calories/money saved.
- Evidence: §1.3 — 33% reduction over 12 weeks, N=46k, observational, company-linked.
- Read-across: the **lowest-friction daily interactive loop in the space** — one glance +
  one tap-equivalent, no app-open required. Completion feels like keeping a promise, not
  finishing a lesson.

### 2.7 QUITTR — gen-Z compulsion mechanics

- Streak counter as identity ("day 47"), **daily pledge tap**, panic button for urge
  moments (breathing/motivation/distraction, one tap from home), AI chat, community,
  content blocking. Launched Aug 2024; **[first-party]** claims: ~2M downloads, "41%
  one-year abstinence, 3x industry average" (founder statements to press, unverified).
- Read-across: for urges, **the button placement is the feature** (cf. BupaQuit null §1.3).
  The rest is streak psychology tuned for young men — high-shame register, opposite of
  JeniFit's voice.

### 2.8 I Am Sober — the pledge/review sandwich

- **Atomic interaction: two taps a day.** Morning: renew your pledge (your own typed "why"
  is replayed to you). Evening: did you keep it? + mood + difficulty rating. Milestones +
  community in between.
- The morning-intention / evening-review sandwich is the cleanest shipped embodiment of
  question-behavior + review-loop evidence (§1.5), and it maps 1:1 onto a "one thing"
  daily structure.

### 2.9 Finch — care-for-other framing

- **Atomic interaction: complete a tiny self-care task → your pet grows.** Generous free
  tier; ~$30M ARR estimate (Sparrow Apps analysis, 2025) **[third-party estimate]**.
- Why it retains: responsibility for a creature reframes self-discipline as care;
  first-person shame is bypassed. The *mechanic* (your action visibly feeds something that
  accumulates) transfers; the kawaii pet register does not fit JeniFit's editorial luxury
  brand.

### 2.10 Atoms (James Clear) — the ceremonial log

- Launched Feb 2024. One habit at a time; setup = habit + time + location + **identity**
  ("the type of person I want to be"); ~$120/yr.
- **Atomic interaction: press-and-hold the atom to log — it swells under your finger with
  haptics until it "takes."** Reviewers single this out as the moment that makes logging
  feel like a vote for an identity instead of a checkbox.
- Direct kinship with JeniFit's hold-to-build signature move — evidence that a **physical,
  duration-based commit gesture** reads premium.

### 2.11 Fabulous — ritual bundling + celebration

- Duke behavioral-econ lab origin (Ariely). "Journeys" release habits **sequentially**
  (one keystone habit, then stack); letters/ceremony framing; celebratory animations on
  completion; streaks without punishment framing.
- Read-across: *sequenced unlock* (you can't binge the curriculum) is a defensible pacing
  mechanic; its skeuomorphic-whimsy register has aged toward childish.

### 2.12 Stoic — prompted journaling as the whole product

- Morning prep (intention prompts) + evening reflection (review prompts), mood check,
  templates; typing-first. Works for a self-selected journaling audience; typing burden is
  exactly what JeniFit's data (weight-logging ~zero) argues against as a *required* atom.

### 2.13 How We Feel — the precision check-in

- Free (Silbermann/Brackett; Yale mood-meter lineage; App Store Cultural Impact award 2022).
- **Atomic interaction: two axes → one word.** Pick quadrant (energy × pleasantness), then
  narrow 144 emotion words to *the* word; tag context; optionally get a matched 1-2 min
  strategy video.
- The lesson: a check-in can *itself* teach (emotional granularity) when the input widget
  encodes the theory. The input is the curriculum. Premium through restraint — no mascot,
  no points, gorgeous type.

### 2.14 Headway (brief)

- 15-min book summaries, audio+text, spaced-repetition flashcards, challenges/streaks.
  Volume play; interactivity is bolted on (flashcards after reading) rather than inside the
  reading — useful contrast to Imprint, where the interaction *is* the reading.

### 2.15 Cross-cutting: what separates premium-interactive from quiz-like/childish

1. **Self-referential > comprehension.** Ahead/How We Feel ask "which is you?" — Duolingo-
   style "which is correct?" reads like school. Adults accept being asked about themselves.
2. **Embedded > sectioned.** Micro-checks inside the narrative (Imprint) vs "QUIZ" chapter
   (childish).
3. **2-3 options, low-stakes, in-voice.** No score, no red X shame; a wrong pick gets a
   warm one-line reframe.
4. **The interaction carries the theory** (mood-meter axes; hold-to-commit; if-then slots).
   If the widget could be replaced by "tap next" with no meaning lost, it's fake
   interactivity.
5. **Completion leaves an artifact** (saved card, her-file entry, a plan she authored) —
   not just +10 XP. Valentine 2025: points don't drive outcomes anyway.
6. **Celebration is earned and rare** (JeniFit already knows this — scatter on 3 moments).
   Per-tap confetti is the fastest route to childish.

---

## RANKED TAKEAWAYS FOR JENIFIT

Ranking = evidence strength × fit for a 20-60s daily practice × brand fit (warm, lowercase,
anti-shame, editorial-luxury, women 22-35, weight-care w/ GLP-1 cohorts).

### The ranked mechanics

**1. Imprint-ize the reading: tap-beat cards with an embedded self-referential micro-choice
every 3-5 beats.**
Evidence: retrieval practice g=0.61 [strong]; Chien — quiz-engagers improve, myth-and-facts
readers don't [moderate]; Imprint = proven premium form [product-fact].
Fit: converts the existing 99%-reach reading surface with no new surface. The 19%
completion problem is a grammar problem: one idea per card, her thumb sets the pace, and
every few cards she answers *about herself* ("when this happens to you, it's usually…"),
never a comprehension quiz. 2-min ceiling per lesson.

**2. The daily rep = one tiny DO, not one tiny READ (behavioral activation first).**
Evidence: RESiLIENT N=3,280 — behavioral activation (+assertion) beat cognitive skills;
self-monitoring control lost to every skill arm [strong]; Noom's 2025 pivot to microhabits
[product-fact].
Fit: THE ONE THING already exists — make the method *assign* the day's 20-60s behavioral
rep (protein-first bite, sit-check, say-the-need) and make the lesson the 3-line "why"
behind it, not vice versa. The v3 REP structure is the right chassis; this is its
evidence mandate.

**3. If-then plan builder: pick a trigger, pick a response, one personalization slot.**
Evidence: Gollwitzer lineage d≈0.65 [strong]; menu-picked = self-written (Armitage)
[moderate]; strongest for poor planners [moderate]; +10s imagery rehearsal strengthens it
[moderate].
Fit: 15-second atom. "if 3pm snack pull → then protein first" assembled from chips in her
voice, then one breath visualizing it. Saved to her-file; tomorrow's check-in asks if it
fired. This is the single highest evidence-per-second interaction available.

**4. Before/after feeling dial around every practice.**
Evidence: CR-app review best practice (only 40% of apps close the loop) [moderate];
mere-measurement RR 1.17 [strong, small]; SSI immediate d≤0.37 shows state shifts are
real and feelable [strong].
Fit: a 2-tap dial (JeniFit already has tick-ruler language) sandwiching the rep. It
generates the receipt — "craving 7 → 4" — which becomes provable product value and
anti-shame proof that *she* did something, without any number being fabricated.

**5. Urge-moment tool: 60-90s urge-surf / imaginal-retraining player, one tap from
anywhere.**
Evidence: ERN −40% craving-related eating [moderate]; imaginal retraining RCT [moderate];
BupaQuit null when buried (23% ever found the tools) [moderate null — placement is the
feature].
Fit: this is the GLP-1-era wedge ("food noise" language already in the brand). Ship it as
a first-class button (today + lock-screen/widget), not a library item. Voice-guided, eyes
closed, hand on chest — premium register, zero typing.

**6. Morning pledge / evening kept-it sandwich on the ONE THING.**
Evidence: question-behavior effect SMD 0.09 [strong, small]; I Am Sober's shipped loop
[product-fact]; matches v3's journal-mornings.
Fit: two taps/day, and it makes the presence ledger mean something ("kept days" = pledges
kept, never streak-shame).

**7. Scenario rehearsal: "it's 9pm and the kitchen is calling" forced-choice branching.**
Evidence: rehearsal among most-promising BCTs [moderate]; SSI evidence for immediate shift
[strong]; direct transfer evidence for eating decisions thin [honest gap].
Fit: 30-45s, 2-3 taps, jeni narrates the consequence of each branch warmly. High brand fit
(her-file fiction register); ship as a weekly "practice" rep, not daily, until it earns
data.

**8. Hold-to-commit as the universal completion gesture.**
Evidence: none clinical — pure completion-feel [product-fact: Atoms' most-loved moment].
Fit: JeniFit already owns hold-to-build from onboarding; reusing it as the method's "rep
done" gesture makes completion physical and on-brand. Cheap, distinctive.

Explicitly deprioritized: food go/no-go reflex games (g≈−0.2, fades, arcade register
clashes) — revisit only as an optional "brain training" extra; free-text thought records
(zero direct efficacy evidence, typing burden — route reframes through jeni chat instead);
XP/points/leaderboards (meta-null, brand-hostile).

### Anti-patterns (each observed in the wild, each violates evidence or brand)

- **The pop quiz.** Right/wrong comprehension checks with scores = school. Micro-choices
  must be about *her*, low-stakes, warmly corrected.
- **The buried toolkit.** A craving tool 3 taps deep is a null result (BupaQuit). If it's
  not one tap from the moment, don't ship it.
- **The XP economy.** Points, gems, leagues: no efficacy signal (Valentine 2025), reads
  teenage. Artifacts (saved cards, her-file entries, kept-day marks) instead of currency.
- **The mascot guilt-trip.** Duolingo/Finch registers work via cute-shame or dependency;
  both collide with anti-shame luxury. The pet mechanic's essence (your action feeds
  something that visibly accumulates) can live in the presence ledger instead.
- **The 10-minute lesson.** Detailed info ≠ better adherence (JMIR 2025); Noom retreated
  from it. 2-minute ceiling, one idea per card.
- **Fake interactivity.** Tap-next with no choice, sliders that record nothing, "reflect on
  this" with no capture. If the widget doesn't encode the technique or produce an artifact,
  it's reading with extra steps.
- **Streak terror.** Day-counters that reset punish the exact lapse moments the method
  exists for (and JeniFit's PresenceLedger already made this call — keep it).
- **Confetti per tap.** Celebration inflation reads childish; JeniFit's 3-earned-moments
  rule already encodes the fix.

### The one-line synthesis

The evidence says the method should feel like **doing one tiny thing and being asked one
true question about yourself every day** — reading is the connective tissue, tap-paced and
2 minutes max; the rep, the if-then plan, the urge button, and the before/after dial are
the muscle.

---

## Source list (accessed 2026-07-06)

Evidence:
- Chien et al., JAMA Network Open 2020;3(7):e2010791 — engagement subtypes in iCBT, N=54,604. https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2768347 (full PDF read)
- Valentine et al., npj Digital Medicine 2025 — persuasive design meta, 92 RCTs. https://www.nature.com/articles/s41746-025-01567-5 (PMC12041226)
- Karyotaki et al., JAMA Psychiatry 2021 — guided vs unguided iCBT IPD network meta.
- Furukawa et al., RESiLIENT trial, Nature Medicine 2025. https://www.nature.com/articles/s41591-025-03639-1 ; 50-week follow-up, BJPsych 2026 (PubMed 42219973)
- Adesope et al., Rev Educ Res 2017 — retrieval practice meta, g=0.61.
- Gollwitzer & Sheeran 2006 — implementation intentions meta (canonical).
- Armitage 2009, PubMed 19751080 — provided vs self-generated if-then plans (alcohol).
- JMIR mHealth 2025;13:e65260 — info length × implementation intentions in a weight app (PMC12334108).
- Imagery + implementation intentions 2025 — PMC11920387.
- Substance-use II meta 2020 — PubMed 32622228.
- Mason et al., J Behav Med 2018 — Eat Right Now, craving-related eating −40%.
- Moritz et al. 2019 — imaginal retraining RCT, PMC6883071.
- BupaQuit pilot RCT 2021 — PMC8637712 (craving tools null; 23.1% tool uptake).
- Sunnyside efficacy study, Alcohol Clin Exp Res, Aug 2024 — company blog: https://www.sunnyside.co/blog/sunnyside-efficacy-study/ [first-party framing]
- Go/no-go + stop-signal food training meta, Appetite 2024 — PubMed 38309625.
- Go/no-go imaging pilot/RCT — PMC10074770 (no 12-week weight change).
- BCT umbrella review 2023 — PMC10498822 (practice/rehearsal promising).
- Digital SSI megastudy, Nature Human Behaviour 2026 — s41562-026-02415-6 (N=7,505).
- Youth digital SSI meta, eClinicalMedicine 2025 — PMC12615334 (g=−0.12).
- Berry et al., Obesity Reviews 2021 — digital self-monitoring meta (obr.13306).
- Rodrigues et al. 2015 — question-behavior effect meta, SMD 0.09 (PubMed 25133835).
- Mere-measurement of PROs meta, Qual Life Res 2025 — PMC12064450 (RR 1.17).
- Digitized thought records review, the Cognitive Behaviour Therapist, Aug 2022 (Cambridge).
- AI thought records (T5), Cogn Ther Res 2023 — 10.1007/s10608-023-10411-7 [exploratory].
- Woebot WB001 postpartum RCT + alliance analyses — via 2023-2025 reviews (tandfonline 2023; JMIR narrative review 2025) [moderate].
- Engagement→outcomes review 2021 — PMC8599127.

Products:
- Imprint: imprintapp.com; ScreensDesign teardown (screensdesign.com/showcase/imprint-learn-visually); Google Play Best of 2023 (blog.google); Headway comparison [competitor bias flagged].
- Ahead: App Store id1570430177; Wefunder "Duolingo for emotional intelligence" [first-party]; ADA 2024 finalist (developer.apple.com/design/awards/2024).
- Duolingo: blog.duolingo.com (method, time-spent-learning-well); UX teardowns (Medium).
- Noom: GlobeNewswire 2025-09-18 (microhabits free tier, Rebel Wilson) [first-party]; noom.com support docs.
- Reframe: joinreframeapp.com [first-party]; Healthline + ChoosingTherapy 2025 reviews.
- Sunnyside: sunnyside.co product pages [first-party]; ChoosingTherapy review.
- QUITTR: quittrapp.com [first-party]; Dazed Digital + The Week coverage (downloads/abstinence = founder claims).
- I Am Sober: iamsober.com; ChoosingTherapy 2025 review; mindtools.io expert review.
- Finch: finchcare.com; Sparrow Apps ARR analysis 2025 [third-party estimate]; UX teardowns.
- Atoms: atoms.jamesclear.com; Entrepreneur/YourStory 2024 reviews; Dear Builders product review.
- Fabulous: thefabulous.co [first-party]; behavior-design case studies (Medium, Designli).
- Stoic: getstoic.com; App Store id1312926037; Product Hunt reviews.
- How We Feel: howwefeel.org via App Store id1562706384; Yale School of Medicine article; marcbrackett.com.
- Headway: makeheadway.com [first-party].
