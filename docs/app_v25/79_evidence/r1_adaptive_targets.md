# R1 — Adaptive Energy Expenditure / Dynamic Calorie Targets

Research sweep, 2026-09-04. Decides whether Jeni builds an adaptive-expenditure system.
Method: web research over MacroFactor's published algorithm articles and help center, competitor
documentation, third-party reviews and complaint aggregations, and the energy-balance literature.
**Evidence limit, stated up front:** direct Reddit access was blocked on every channel tried
(reddit.com, old.reddit, reddit JSON, pullpush.io, DDG/Bing site-search, r.jina.ai). Thread-level
user sentiment below comes from secondary sources that aggregate or characterize Reddit/App Store
sentiment, plus MacroFactor's own help articles — which are themselves a map of what confuses users
(a help article exists for every recurring panic). Where a quote is verbatim it is marked.

---

## 1. How MacroFactor actually works (the reference implementation)

MacroFactor (Stronger By Science; Nuckols/Trexler) is the category-defining implementation and the
only one with a substantial published paper trail.

### 1.1 The core identity

Everything rests on one deterministic equation, stated in their own help center as:

> "Calories out = Calories in − Change in stored energy."
> — [How Should I Interpret Changes to my Energy Expenditure?](https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure)

Expenditure is **back-calculated**: log 1,800 kcal/day while trend weight falls ~0.3 kg/week
(≈300 kcal/day of stored energy) → implied TDEE ≈ 2,100. It is explicitly framed as
**back-looking**: "your expenditure is a back-looking value, informed by your previous ~3 weeks of
weight and nutrition data"
([Energy Balance Widget](https://help.macrofactorapp.com/en/articles/224-interpreting-the-energy-balance-widget)).
No wearable calories, no activity multipliers after calibration — the scale and the food log are
the only inputs the core loop trusts. A 2025 "expenditure modifiers" update added **step counts**
as a third, progressively-weighted signal (see 1.4).

### 1.2 Trend weight (the denominator of everything)

- A weighted moving average "that places greater emphasis on more recent weigh-ins," over a
  "pretty long time scale" ([Weight Trend](https://help.macrofactorapp.com/en/articles/21-weight-trend),
  [Algorithms & Core Philosophy](https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/)).
- Missing days are **linearly interpolated** between real weigh-ins (Mon 151 / Wed 150 → Tue 150.5).
- Behavior rule of thumb from their own description: a 1–3 day excursion that returns to baseline
  barely moves the trend; a deviation persisting into days 4–5, especially accelerating, is treated
  as real.
- Stated data floor: daily weighing is ideal; **"at least three times per week"** for good results;
  the algorithm is "resilient to gaps."
- During loss the trend sits above the scale weight (back-looking average) — they teach this
  explicitly so users don't read the lag as error.

### 1.3 The expenditure algorithm (v3, 2024) and its published numbers

From [An In-Depth Look at MacroFactor's New V3 Expenditure Algorithm](https://macrofactor.com/expenditure-v3/):

- **Stability vs responsiveness:** v3 cut day-to-day expenditure jitter ~35% vs v2 while detecting
  true trend changes 3–5 days *earlier*. (They treat these as the two axes of the whole problem.)
- **Water-weight defense:** v3 specifically dampens false expenditure signals from carb/sodium
  water shifts, creatine loading, **menstrual-cycle retention**, and post-stall "whoosh" drops.
  v2 would spike expenditure upward after a whoosh; v3 largely doesn't.
- **Missing-data tolerance:** v2 needed ~80–85% nutrition-logging completeness; v3 "performs
  adequately" with up to ~50% of days missing (~3× more tolerant). Expenditure **updates pause
  only when >3 days of logging are missing within a 7-day window**. Un-logged days are internally
  estimated to ~15–20% accuracy. **Partial logging (logging some meals of a day) remains the
  poison** — a whole missing day is recoverable, a half-logged day silently biases the math.
- **The 3,500-rule bug:** v1/v2 assumed asymmetric energy densities for gain vs loss and
  accumulated a 0–130 kcal/day overestimation for people whose weight oscillates; v3 fixed it.
- Claimed ~10% overall accuracy improvement vs v2 (weekly prediction errors ~15% smaller).

**Calibration:** initial expenditure is a demographic formula + activity estimate, explicitly
framed as provisional; the learned estimate takes over after **~3–4 weeks of consistent logging**
(their help center; SBS's deep-dive claims convergence "in about 20 days" even from a badly wrong
prior). Users can also **backfill 3–4 weeks of history** to skip the wait, or **manually override**
the starting value
([What Should I Do if My Initial Expenditure Seems Too High or Low?](https://help.macrofactorapp.com/en/articles/206-what-should-i-do-if-my-initial-expenditure-or-recommended-energy-intake-seems-too-high-or-too-low)).

**Validated accuracy** ([How Accurate is MacroFactor's Expenditure Algorithm?](https://macrofactor.com/algorithm-accuracy/),
n=748 users over 100 days, predictive-validity method — predicted vs actual weight change, not
doubly-labeled water):

- After calibration: typical expenditure error **60–240 kcal/day (median ~135)** vs formula-based
  **155–590 (median ~335)**. ≈4.4% of TDEE median error; ~84% of users under 10% error.
- Beat static formulas in **94.1% of individual cases**.
- Caveat in their own analysis: users with "consistent partial logging" were **excluded**, and
  accuracy "degrades significantly when logging drops below 90% completeness." The headline
  numbers describe disciplined loggers.

### 1.4 Expenditure modifiers (Oct 2025)

From [An Examination of MacroFactor's Expenditure Modifiers](https://macrofactor.com/expenditure-modifiers/):

- **Step-informed updates:** phone step counts join weight+nutrition as a progressive signal
  (never a daily 1:1 adjustment) — ~2–3% responsiveness gain.
- **Predictive goal adjustment:** switching loss→gain proactively nudges expenditure **up ~6% over
  two weeks** (anticipating the glycogen/food-mass regain and the metabolic response), instead of
  waiting for the data to force it.
- Net: ~6–8% short-term accuracy gain; ~20% cumulative 100-day gain (median 100-day weight-change
  prediction error ~3.5 lb → ~2.5 lb).

### 1.5 Cadence: expenditure moves daily, targets move weekly, and only with consent

This split is the load-bearing design decision:

- The **expenditure number** updates continuously (daily) and is displayed as information.
- **Targets change only at a weekly check-in** the user initiates, structured as five "coaching
  modules" ([Introduction to Check-Ins](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules)):
  **Partial Logging** (flags suspiciously light days and asks), **Weigh-In** (asks for a fresh
  weight before recommending), **Fasting** (asks whether unlogged days were actually fasted —
  i.e., it *asks* rather than guesses the difference between "didn't eat" and "didn't log"),
  **Logging Break**, then **Program Update** (the new targets).
- **"You do have the option to decline a Check-In … this will prevent any caloric recommendations
  to be applied to your program."** Targets are proposed, never silently mutated. Three program
  styles scale the autonomy: **Coached** (app adjusts everything weekly), **Collaborative** (app
  adjusts the weekly calorie budget, user owns day-to-day macro shape), **Manual** (no adjustments)
  ([Program Styles](https://help.macrofactorapp.com/en/articles/91-program-styles)).
- Target math: recommended intake = learned expenditure − deficit implied by the user's chosen
  rate, with **guardrails** — updates "hedge their bets," spreading corrections over weeks; a
  behind-schedule user is never assigned a faster rate to "catch up"; each week is self-contained;
  fat intake has a physiological floor below which cuts come from carbs
  ([How Does MacroFactor Make Adjustments](https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal)).
- Escape hatch: expenditure can be switched from **dynamic to static** entirely
  ([help 64](https://help.macrofactorapp.com/en/articles/64-how-to-change-your-expenditure-estimate-from-dynamic-to-static)).

### 1.6 Presentation and register

- Philosophy: "recommendations are informative, not punitive"; nothing turns red; no makeup sets,
  no shame ([Algorithms & Core Philosophy](https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/)).
- The **Energy Balance widget** shows intake vs targets and intake vs expenditure over the past
  month and is candid about epistemics: the expenditure view "tells you the size of the energy
  deficit or surplus you would have been *expected* to be in" from prior data — expected, not
  known ([help 224](https://help.macrofactorapp.com/en/articles/224-interpreting-the-energy-balance-widget)).
- A large education corpus pre-answers every panic: "Why isn't my expenditure increasing now that
  I exercise?" is answered with opportunity cost, movement economy, and behavioral compensation,
  closing with "You don't really need to overthink any of this … [the change] will show up on the
  scale and MacroFactor will be able to identify that change"
  ([help 256](https://help.macrofactorapp.com/en/articles/256-i-ve-started-exercising-more-why-isn-t-my-expenditure-increasing)).
  The product's answer to algorithm anxiety is **teaching, in the app's own voice, at the moment
  of the question** — not more dashboard.

---

## 2. Other implementations

**Carbon Diet Coach** (Layne Norton) — weekly check-in asks *adherence + weight + subjective*
questions; the algorithm holds/raises/cuts targets **only if the user adhered**; if not, "the app
will not change anything and simply tell the user to be more adherent"
([FeastGood comparison](https://feastgood.com/macrofactor-vs-carbon-diet-coach/),
[caleye side-by-side](https://caleye.fit/blog/carbon-vs-macrofactor-2026/)). It does not model
expenditure from the data — it runs a coach's decision tree. The comparison literature's framing:
"Carbon is built to feel like working with a coach, MacroFactor like a scientific instrument."
MacroFactor's differentiator is that it "adjusts targets based on what the user proves they are
capable of" — a non-adherent week still teaches it something; Carbon's teaches nothing.

**RP Diet Coach** — adjustments embedded in a periodized mesocycle framework (training-relative
meal timing etc.), sport-science rules rather than data-derived expenditure; does not expose
uncertainty or reasoning ([caleye](https://caleye.fit/blog/macrofactor-vs-rp-diet-which-wins/)).

**Avatar Nutrition** (largely historical now) — early rule-based weekly macro adjustments from
weigh-ins with a published FAQ about the rules ([FeastGood](https://feastgood.com/avatar-nutrition-vs-rp-diet/)).

**The spreadsheet lineage** (nSuns/adaptive-TDEE sheets, now productized by many small tools):
TDEE = mean intake − (weekly Δweight × 3,500/7); modern versions smooth weight with an EMA, fit a
trend over the **most recent ~21 days**, and use **~7,700 kcal/kg**
([Zolt](https://www.zolthealth.com/adaptive-tdee), [GymGeek](https://gymgeek.com/calculators/adaptive-tdee-calculator/)).
Standard guidance: 2–4 weeks minimum, 4–6 weeks for a stable read, morning weigh-ins under
constant conditions.

**2025–2026 field:** Fitia ships an "adaptive algorithm" + AI coach; Noom added GLP-1 programs and
AI coaching; Cal AI (photo-first) was acquired by MyFitnessPal — photo logging is commoditizing
while **nobody has displaced MacroFactor on the expenditure engine itself**
([TNW roundup](https://thenextweb.com/news/nnovative-calorie-tracking-apps-2026),
[Fitia](https://fitia.app/learn/article/best-macrofactor-alternatives-2026/)). The GLP-1-specific
tracker wave (Shotsy, MeAgain, GlucoPal, etc.) tracks doses and protein but none of them run
adaptive expenditure. **The intersection — adaptive expenditure built *for* the medicated
customer — is empty.**

---

## 3. User trust and failure modes

### What users love (why it's a retention moat)

- **It answers the scariest question with their own data.** The algorithm is described by
  communities as feeling "honest — it does not pretend to know your metabolism better than your
  own data" ([nutrola Reddit-sentiment roundup](https://nutrola.app/en/blog/what-do-reddit-users-say-about-macrofactor-2026),
  [best-nutrition-apps review](https://best-nutrition-apps.com/reviews/macrofactor/)).
- **It converts weight anxiety into trend calm.** Verbatim user review (via
  [best-nutrition-apps](https://best-nutrition-apps.com/reviews/macrofactor/)): *"The adaptive TDEE
  and weight trend features have helped calm a lot of my anxieties about short term plateaus and
  small upward spikes in weight, and allowed me to maintain a smaller calorie deficit that's far
  less draining while still trending downward."* This is the moat in one sentence: the adaptive
  read lets people run **gentler** deficits with confidence.
- **Non-judgment compounds it:** no red numbers, no streaks, misses absorbed not lectured — cited
  repeatedly as why people who abandoned MFP stayed here.
- **The weekly ritual itself retains:** the check-in gives the logging a payoff cadence; data in →
  understanding back.
- Structural note: a subscription-only tracker holding ~4.8★ across ~19.5k App Store ratings in a
  category whose free incumbent (MFP) collapsed to ~1.5★ trust.

### Where adaptive systems confuse or frighten users (each has a help article because it recurs)

1. **"My expenditure dropped and I don't know why."** The single most common panic. Three true
   causes (metabolic adaptation, lighter body, algorithm correcting an earlier overestimate) are
   indistinguishable *to the user* without explanation; the felt experience is "the app cut my
   food as punishment." MacroFactor's whole
   [interpretation article](https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure)
   exists to reframe this: 50–150 kcal moves in the first weeks are calibration, not metabolism.
2. **The under-logging death spiral (worst failure mode).** Systematic under-reporting (research:
   12–16% in non-dieters, **20–30% in active dieters**) reads as a lower TDEE → lower targets →
   user under-logs against the lower target too → apparent maintenance at a supposed deficit →
   "the app says I burn 1,600 and I'm still not losing" → trust death
   ([caleye accuracy analysis](https://caleye.fit/blog/macrofactor-tdee-tracking-accuracy/)).
   The system is *self-consistent* under biased data — it converges confidently on a wrong number.
   Note the mirror image: because targets derive from *logged* intake, a consistent under-logger
   still loses weight on the assigned targets (the bias cancels) — but only if the bias is
   *stable*. Bias that varies week to week (weekends, restaurants, shame-skipping) is what wanders.
3. **Jagged weigh-in data → wandering targets.** "The algorithm receives jagged weight data, its
   expenditure estimate becomes noisy, and the macro recommendations it produces start to wander
   … users see calorie targets jump week to week and lose confidence in the plan"
   ([nutrola failure-modes piece](https://nutrola.app/en/blog/macrofactor-not-working-for-weight-loss-heres-why)).
   Weekly target volatility is experienced as the *plan* being unreliable, not the data.
4. **Water-weight distortions.** Pre-v3, a post-plateau "whoosh" spiked expenditure (then it
   corrected back down = double confusion); persistent retention (new creatine, high-sodium era,
   menstrual cycle) biases expenditure for up to ~2 weeks, admitted at "<10%" error in their own
   docs. v3 spent most of its engineering budget on exactly this class.
5. **"I exercise more and nothing changed."** The energy-balance method only credits exercise that
   shows up in the weight/intake data; compensation eats most of it. Users read the non-move as
   the algorithm being broken ([help 256](https://help.macrofactorapp.com/en/articles/256-i-ve-started-exercising-more-why-isn-t-my-expenditure-increasing)).
6. **Cold-start mistrust.** The first 2–3 weeks run on a formula that may be off by hundreds of
   kcal; users who judge the product in week 1 judge the *formula*, not the system. MacroFactor
   mitigates with backfill and manual override ([help 206](https://help.macrofactorapp.com/en/articles/206-what-should-i-do-if-my-initial-expenditure-or-recommended-energy-intake-seems-too-high-or-too-low)).
7. **A "phantom deficit" arithmetic example** worth keeping: "A 200-calorie daily undercount over
   a month erases more than 6,000 calories of apparent deficit — nearly two pounds of fat on paper
   that never existed" ([nutrola](https://nutrola.app/en/blog/macrofactor-not-working-for-weight-loss-heres-why)).

---

## 4. GLP-1 complications

No implementation studied has a GLP-1 mode; MacroFactor has none as of this sweep (its 2025
"expenditure modifiers" release notes contain nothing medication-specific —
[Oct 2025 update](https://macrofactor.com/mm-oct-2025/)). What the mechanics predict, cross-checked
against the GLP-1 tracking literature:

- **Intake data is biased in a new way.** GLP-1 users genuinely eat little AND log erratically
  (nausea days, skipped meals, "didn't eat, didn't open the app"). The energy-balance method
  cannot tell "ate 900 kcal" from "logged 900 of 1,400 kcal" — and on GLP-1s the *plausibility
  check a coach would apply* ("nobody maintains on 1,100") is void, because the user may truly
  be eating 1,100. **Under-logging detection heuristics calibrated on non-medicated populations
  break here.**
- **The fasted/unlogged distinction becomes the load-bearing question.** MacroFactor's Fasting
  check-in module (asking "were these unlogged days actually fasted?") is the single most
  GLP-1-relevant mechanism in the field — for this cohort "I just didn't eat" is a *common true
  answer*, and assuming un-logged = unknown (population-typical intake) massively overestimates
  intake → overestimates expenditure → overestimates the allowed target.
- **Dose changes move both sides of the equation at once.** A titration step shifts intake within
  days and weight-rate within 1–2 weeks; any 2–4-week window straddling a dose change is reading a
  mixture of two regimes. Rapid loss phases also shift body composition of the loss (more lean
  mass at risk when protein is low —
  [Macros Inc GLP-1 guide](https://macrosinc.net/blog/glp-1-medication-guide/),
  [PMC micronutrient review](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12693348/)), which
  changes the kcal/kg energy density the back-calculation assumes.
- **GI side effects add water/GI-content noise** (vomiting, constipation — a documented Jeni
  method note domain already) on top of the usual sodium/glycogen noise.
- **What the cohort actually needs from targets differs.** The GLP-1 tracking literature is
  unanimous that the *protein floor*, not the calorie ceiling, is the number that matters
  ([IIFYM GLP-1 macros](https://iifym.com/blog/glp-1-diet-peptide-macros-semaglutide/),
  [Curex app roundup](https://getcurex.com/glp1-blog/top-apps-to-track-macronutrient-breakdown)).
  An adaptive system for this cohort is most honest as an adaptive *expenditure read* (am I
  under-fueled? is the loss rate safe?) rather than an adaptive *restriction target* —
  a countdown that adapts downward for someone already under-eating is clinically backwards.
  (This matches Jeni's existing p53/p57 law: medicated days count up and never say "over.")
- Direct r/macrofactor GLP-1 thread quotes were not retrievable this sweep (access blocked);
  treat the above as mechanism-derived + secondary-source-corroborated, and name a follow-up
  read if thread access becomes available.

---

## 5. The math: minimum viable honest version

**The identity:** over a window, `TDEE ≈ mean(logged intake) − Δ(trend weight) × ρ / days`, with
ρ the energy density of tissue change.

- **ρ is not a constant.** The 3,500 kcal/lb (7,700 kcal/kg) rule is a static approximation Hall's
  Lancet 2011 work discredited for *forecasting* ([Hall et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC3880593/),
  [IJO "Why is the 3500 kcal rule wrong?"](https://www.nature.com/articles/ijo2013112)): fat ≈
  9,400 kcal/kg, lean ≈ 1,800; the blend depends on composition of the loss. For *short-window
  back-calculation* 7,700/kg is a serviceable convention — the spreadsheet lineage and (evidently)
  MacroFactor use it — but v1/v2's asymmetric-ρ assumption produced their 0–130 kcal/day
  systematic bias, so: **one symmetric ρ, stated as an approximation.**
- **Window:** 14 days minimum, ~21 days standard (MacroFactor: "previous ~3 weeks"; spreadsheets:
  21-day trend fit), recency-weighted rather than boxcar.
- **Trend weight:** EMA-family smoothing; τ ≈ 9–10 days matches both MacroFactor's observed
  ~3-week memory and Jeni's existing `WeightWeekReadEngine` (τ = 9.5d). Interpolate gaps linearly;
  reject unit-error outliers (Jeni already does).
- **Sufficiency floors (converged from all credible sources):**
  - weigh-ins ≥3/week over the window, and coverage across it (not 3 in the last 3 days);
  - nutrition-logging: MacroFactor's *pause* rule — **stop updating when >3 of the trailing 7 days
    are unlogged** — is the honest floor; their *accuracy* claims require ≥90% completeness;
  - a **whole missing day is recoverable, a partially-logged day is not** — flag/exclude days
    whose logged total is implausibly below the person's own distribution (MacroFactor's Partial
    Logging module asks; it does not guess);
  - never grade the two-sided read on one-sided data.
- **Calibration:** 14–21 days before speaking a learned number at all; before that, either silence
  or the formula estimate explicitly labeled provisional.
- **Honest error bars:** best case (disciplined logger, daily weigher, post-calibration) is
  ±5–10% of TDEE (median ~135 kcal/day in MacroFactor's n=748 validation). A minimum version
  should speak in **rounded bands (~±150–200 kcal)**, never a 4-digit point estimate, and widen or
  go silent as data thins. Water-weight regime changes can bias the read <10% for up to ~2 weeks
  even in the best implementation.
- **Update cadence:** compute continuously if you like, but **change targets at most weekly, with
  bounded step size** (MacroFactor "hedges its bets" across weeks; never a catch-up rate; floors
  on intake). Expenditure display ≠ target mutation.

---

## 6. Presentation patterns (how the best express "your target changed")

1. **Propose at a ritual, never silently mutate.** MacroFactor: targets move only inside a weekly
   check-in the user opens and can decline entirely. Carbon: every change arrives with a stated
   reason. Nobody credible hot-swaps the number under the user mid-week.
2. **Separate the fact from the instruction.** Expenditure is a *reading* shown continuously with
   provenance ("from your last ~3 weeks of logging and weigh-ins"); the target is a *proposal*
   derived from it. Collapsing them is what makes drops feel like punishment.
3. **Say the cause in the same breath as the change.** The three-cause taxonomy (adaptation /
   lighter body / correcting my earlier estimate) is the difference between "the app cut my food"
   and "your body needs a bit less than it did in July."
4. **Epistemic honesty as copy, not as a dashboard.** "Expected to be in," "an early read,"
   "back-looking," "still filling in" — hedges live in sentences, not confidence-interval charts.
5. **Ask, don't infer, at ambiguity.** The Fasting module's "were these days actually fasted?" is
   the pattern: when the record is ambiguous the product asks one question rather than guessing.
6. **Offer the off-ramp.** Dynamic→static toggle, decline-this-check-in, manual style. Trust in
   an adaptive system partly comes from being allowed to turn it off.

---

## 7. What this means for Jeni

### Should Jeni build one?

**Yes — but as an adaptive *read*, not an adaptive *restriction engine*, and only at the fidelity
Jeni's record can honestly support.** The moat evidence is real: the adaptive read is *the* cited
reason MacroFactor retains data-driven users, and it directly answers the two questions Jeni's
GLP-1 customer actually has — "is this rate okay?" and "am I eating enough to protect what I'm
keeping?" — with her own data. And the intersection (adaptive expenditure × GLP-1) is unoccupied.

Jeni already owns most of the parts: one canonical trend fold (`WeightWeekReadEngine.trendSeries`,
EMA τ9.5d, sufficiency ladder), absence-honest intake records (unmeasured ≠ 0, p70/p71),
day-completeness knowledge, dose-era arithmetic (`RegimenEras`), a consented weekly ritual (the
weekly read), and standing laws that happen to be exactly the trust findings above (never a grade,
observed never projected, silence over guessing, propose at arrival).

### Recommended minimum honest version

1. **One pure engine** (`ExpenditureRead` or similar): windowed back-calculation over the trend
   fold + logged intake, 21-day recency-weighted window, ρ = 7,700 kcal/kg stated as approximate,
   **band output only** (e.g., "about 1,900 to 2,100 kcal a day"), nil under any failed gate.
2. **Gates (silence over guessing):** ≥14 days history · weigh-ins ≥3/wk across the window ·
   ≤3 unlogged days per trailing 7 · window does not straddle a dose change younger than ~2 weeks
   (the titration floor p74 already uses) · numeric-suppression cohort ⇒ never renders ·
   partially-logged days excluded by the person's own intake distribution, with one *question*
   (the Fasting-module pattern: "you didn't log tuesday — did you eat that day?") rather than an
   inference.
3. **Seat and cadence:** the read lives in Becoming's one-fold story ("your body is using about
   2,000 kcal a day, from your last three weeks"), updates its display continuously, but touches
   *targets* only through the weekly read's existing offer grammar — proposed, explained with its
   cause, declinable, bounded step size, never a catch-up rate. TargetsService keeps one authority.
4. **GLP-1 shape:** for medicated/suppressed customers the read powers *floor-protection and
   under-fueling honesty* ("your body used ~1,950 a day; your plates carried ~1,150 — protein
   first"), never a tighter ceiling; the count-up law stands. An expenditure *drop* on this cohort
   is often the medication working — say that, never "your metabolism slowed."
5. **Explicitly refused:** point-estimate TDEE numerals · daily target mutation · wearable-calorie
   inputs · projections/goal dates from the read (p74 refusal stands) · any grade on the gap
   between intake and expenditure.

### Failure modes to design against (named)

- **The under-logging death spiral** — biased intake converges on a confidently wrong low number;
  design: completeness gates + the ask-don't-infer question + never tightening targets from a
  low-confidence read.
- **Expenditure-drop panic** — every displayed drop must carry its cause in the sentence.
- **Wandering-target whiplash** — weekly-only, bounded, declinable proposals; the read may move,
  the plan moves slowly.
- **Water-weight regime bias** (new creatine, cycle phase, sodium era, post-stall whoosh) —
  ≤2-week distortions; the band + slow target coupling absorb it; menses-aware stand-downs Jeni
  already has apply.
- **Dose-change straddle** — a window crossing a dose change reads a mixture; hold the read
  ("early to read at this dose"), reuse the era vocabulary.
- **Cold-start judgment** — never show a learned band before the gates pass; the provisional
  period speaks the plan's existing numbers, labeled as the plan's.
- **The GLP-1 inversion** — an adaptive system that ratchets an already-under-eating customer's
  target downward is the one version of this feature that must never ship.

### Key sources

- https://macrofactor.com/expenditure-v3/ · https://macrofactor.com/algorithm-accuracy/ ·
  https://macrofactor.com/expenditure-modifiers/ · https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/
- help.macrofactorapp.com articles 21 (weight trend), 26 (interpreting expenditure changes),
  91 (program styles), 206 (initial expenditure), 222 (adjustments), 224 (energy balance widget),
  247 (check-ins), 252 (program update), 256 (exercise vs expenditure), 64 (dynamic→static)
- https://caleye.fit/blog/macrofactor-tdee-tracking-accuracy/ ·
  https://nutrola.app/en/blog/macrofactor-not-working-for-weight-loss-heres-why ·
  https://nutrola.app/en/blog/what-do-reddit-users-say-about-macrofactor-2026 ·
  https://best-nutrition-apps.com/reviews/macrofactor/
- https://feastgood.com/macrofactor-vs-carbon-diet-coach/ · https://caleye.fit/blog/carbon-vs-macrofactor-2026/ ·
  https://caleye.fit/blog/macrofactor-vs-rp-diet-which-wins/
- https://www.zolthealth.com/adaptive-tdee · https://gymgeek.com/calculators/adaptive-tdee-calculator/
- Hall et al., Lancet 2011 — https://pmc.ncbi.nlm.nih.gov/articles/PMC3880593/ ·
  https://www.nature.com/articles/ijo2013112
- GLP-1 nutrition: https://iifym.com/blog/glp-1-diet-peptide-macros-semaglutide/ ·
  https://macrosinc.net/blog/glp-1-medication-guide/ · https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12693348/
