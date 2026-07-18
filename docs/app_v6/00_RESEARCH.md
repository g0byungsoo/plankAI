# app v6 — passive signals research (2026-07-17)

Founder brief: the app must deliver more value with zero added input.
Women in this cohort don't want to read much or log things; they want
the app to *notice* things for them. Home gains passive modules
computed from data the phone already collects; becoming gains insight
story pages that make the journey feel understood. Everything must be
scientific, weight-loss-relevant, and retention-positive.

This doc is the evidence base + the module decisions it justifies.
Design grammar follows `docs/app_v5/00_DIRECTION.md` (one insight per
screen, plain words, data as objects). Safety framing rules at §4 are
NON-NEGOTIABLE and encoded in `SignalsEngine`, not just copy.

---

## 1. The retention thesis (why passive)

- Passive self-monitoring sustains engagement where active logging
  decays: calorie tracking has measurably lower sustained engagement
  than passive sensing (wearables) in behavioral weight-loss programs
  ([JMIR mHealth 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10394603/)).
- High weight-related information avoidance predicts faster
  disengagement from dietary self-monitoring — shame-adjacent surfaces
  actively drive churn. Anti-shame framing is a retention mechanic,
  not just brand voice (same study).
- App engagement itself predicts weight loss in blended-care
  interventions at scale ([JMIR 2024](https://www.jmir.org/2024/1/e45469)) —
  and passively collected data "reduces the burden of data collection"
  while adding information value.
- The 2025 Spark factorial RCT is testing exactly which self-monitoring
  streams are the active ingredients (diet / steps / weight)
  ([protocol](https://www.researchprotocols.org/2025/1/e75629)) — the
  field is converging on fewer required inputs, more derived insight.

**Implication:** every new module below consumes only existing streams
(plate timestamps + macros, HealthKit steps/sleep, weigh-ins). Zero new
input. The app's job: turn her existing exhaust into felt understanding.

## 2. The verified science per signal

### S1 — the overnight window (from plate timestamps)
- TRE meta-analyses (RCTs, 2023-2025): time-restricted eating produces
  modest but real weight effects (−1.3 to −1.9 kg vs control; 16:8
  significant in women-specific pooling)
  ([PMC10630127](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10630127/),
  [PMC12479299](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12479299/),
  [Frontiers 2025](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1631477/full)).
- Late eating is mechanistically bad independent of calories: in a
  controlled crossover RCT, eating the same food ~4h later doubled odds
  of hunger, shifted ghrelin:leptin, cut waking energy expenditure ~5%
  (~59 kcal/day), and shifted adipose gene expression toward storage
  ([Vujović 2022, Cell Metabolism](https://www.cell.com/cell-metabolism/fulltext/S1550-4131(22)00397-7)).
- Chrononutrition reviews: earlier eating windows associate with better
  lipids, insulin sensitivity, body fat
  ([Nutrients 2025](https://www.mdpi.com/2072-6643/17/13/2135)).

**Derivable today:** last plate timestamp (yesterday) → first plate
timestamp (today) = the overnight window. Live state: hours since last
plate ("the kitchen closed at 8:41"). No new input.

### S2 — night (HealthKit sleep × appetite)
- RCT: extending sleep from <6.5h by ~1.2h/night cut ad-lib energy
  intake by ~270 kcal/day with no expenditure change — negative energy
  balance from sleep alone
  ([Tasali 2022, JAMA Internal Medicine](https://jamanetwork.com/journals/jamainternalmedicine/fullarticle/2788694)).
- Short sleep raises ghrelin / lowers leptin (Nedeltcheva 2010 — already
  encoded in `ProgramGoalCalculator`'s short-sleep pace floor).

**Derivable today:** HealthKit sleep duration last night. The killer
framing is *forgiveness*: "short night · hunger may speak louder today"
reframes a hungry day as physiology, not failure. Anti-shame = retention.

### S3 — after-meal moves (plate timestamps × HealthKit steps)
- Meta-analysis: interrupting sitting with 2-5 min of light walking
  after meals significantly improves postprandial glucose and insulin
  vs sitting or standing
  ([Buffey 2022, Sports Medicine](https://pubmed.ncbi.nlm.nih.gov/36715875/);
  coverage: [CNN](https://www.cnn.com/2022/09/02/health/walking-blood-sugar-study-wellness)).
- Post-meal glycemic flattening reduces the insulin/crash/craving cycle
  — directly relevant to the food-noise wedge.

**Derivable today:** steps landing in the 90 minutes after a logged
plate (HealthKit hourly buckets × plate timestamps). Purely
celebratory receipts — never guilt for absence.

### S4 — rhythm (weigh-in cadence + meal regularity)
- Systematic reviews: regular self-weighing associates with greater
  loss + maintenance, and consistency beats raw frequency; no adverse
  psychological effects in interventions
  ([Zheng 2015, Obesity](https://onlinelibrary.wiley.com/doi/full/10.1002/oby.20946),
  [maintenance RCT data](https://pubmed.ncbi.nlm.nih.gov/32437055/),
  [10k smart-scale cohort](https://pmc.ncbi.nlm.nih.gov/articles/PMC8277333/)).
- Irregular meal timing associates with metabolic syndrome and higher
  BMI; regular earlier meals improve markers
  ([Proc Nutr Soc](https://pubmed.ncbi.nlm.nih.gov/27327128/)).

**Derivable today:** weigh-in day coverage + plate-time consistency.
Becoming analysis, spoken as consistency praise, never a lapsed streak.

### S5 — sweetness (sugar — field confirmed: plate-level `sugar` since v1.1.5)
- Free sugars intake is a determinant of body weight (WHO-commissioned
  review, [Te Morenga 2012 BMJ](https://sugar.ca/sugars-consumption-guidelines/dietary-guidelines-on-sugars));
  WHO: <10% energy from free sugars
  ([WHO guideline](https://www.who.int/news/item/04-03-2015-who-calls-on-countries-to-reduce-sugars-intake-among-adults-and-children)).
- Provenance confirmed in recon: `FoodLogPersister.Entry.sugar`
  (plate-level, device-local, ships since v1.1.5; older plates read 0
  and stay silent — the engine floors handle this). Observation
  framing only — when sweetness lands in her day — never good/bad
  labels.

### S6 — her season (cycle-phase appetite context; round 2)
- Meta-analysis (15 datasets, 330 women): energy intake runs ~168
  kcal/day higher in the luteal phase vs follicular
  ([Nutrition Reviews 2024](https://academic.oup.com/nutritionreviews/article/83/3/e866/7713894));
  resting metabolic rate also rises ~100-300 kcal/day
  ([narrative review](https://academic.oup.com/nutritionreviews/article/81/7/869/6823870)).
  Individual variation is wide (some 2025 work finds consistency
  across phases) — so the register is "normal, planned for," never
  a number she owes.
- **Derivable:** HealthKit menstrual-flow samples → period starts →
  phase. Safety laws: observation only, no cycle predictions, no
  fertility vocabulary, perimenopausal identities gated off.

### S7 — protein pacing (round 2)
- Leidy RCTs: a ~35g-protein breakfast raises satiety, cuts evening
  snacking (especially high-fat) and craving-related brain activity
  in young women
  ([AJCN 2013](https://pubmed.ncbi.nlm.nih.gov/23446906/),
  [Nutrition Journal 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4334852/)).
- **Derivable:** per-plate protein × timestamps → morning/afternoon/
  evening shares. Observation framing; never a meal plan.

## 3. What we deliberately do NOT build

- No hydration module (no data stream; would require input).
- No calorie-burn / "fat-burn" claims anywhere (compliance floor).
- No streaks, no fasting timers with targets, no countdowns to "goal
  fast" (§4).
- No CGM-style glucose claims — after-meal moves speaks about movement,
  never claims her glucose numbers (we don't have them).
- No menstrual-cycle module in this pass (HealthKit permission +
  sensitivity review needed; candidate for later).

## 4. Safety framing rules (encoded in SignalsEngine)

Fasting features are an eating-disorder vector for this exact
demographic: fasting is one of the strongest prospective predictors of
binge-eating onset in young women
([AAFP/PMC review](https://pmc.ncbi.nlm.nih.gov/articles/PMC10589984/)),
and clinical guidance for GLP-1 users warns against combining appetite
suppression with restrictive windows (muscle loss; providers recommend
conservative 12:12-14:10, never 16:8+)
([PMC12730251](https://pmc.ncbi.nlm.nih.gov/articles/PMC12730251/)).

Rules, enforced in engine logic (not just copy review):

1. **Observed, never prescribed.** The window is a thing that happened
   ("13h of overnight rest"), never a target to hit or extend. No
   "extend your fast" prompt exists anywhere.
2. **The word "fasting" never renders.** Vocabulary: "the window",
   "overnight rest", "the kitchen closed". (Post-Ozempic vocabulary
   rule + ED-trigger avoidance.)
3. **Praise saturates at 14h.** Windows of 12-14h get warm
   acknowledgment. Longer windows get NEUTRAL ink — never bonus praise.
4. **Care line at 16h+.** Repeated 16h+ windows or a 20h+ single window
   → gentle nourishment line, and for GLP-1-current users the module
   inverts entirely: their hero fact is "first plate by ~10am" +
   protein adequacy (their clinical risk is under-fueling, not
   overeating).
5. **Restriction cohorts** (existing under-target safety net /
   BreakState): window module renders quiet neutral facts only, no
   praise dimension at all.
6. **Absence never renders.** No plates logged → no window claim
   (data floor: both edges must exist). One plate → live state only.
7. **Sleep module never prescribes bedtime.** It explains today,
   it doesn't assign homework.

## 5. The build decision

**Home (Today) — passive signal modules, in the existing day-rail
structure (structure unchanged per founder):**
- THE WINDOW — the hero passive module (founder's named example): a
  drawn overnight arc (dusk → dawn), live "kitchen closed" state at
  night, this-morning's window fact by day. Tap → detail sheet with
  the 24h dial + last-7-nights mini rhythm.
- NIGHT — quiet row, renders only when HealthKit sleep exists:
  duration + the forgiveness/appetite line.
- AFTER-MEAL MOVES — receipt-register row, renders only on detection:
  "you moved after lunch ♥".

**Becoming — new story pages (JKStoryPage grammar, visuals re-arm
per swipe):**
- "the window" — the week of overnight windows as a stacked dial /
  night-band figure + one insight sentence + the late-drift fact.
- "nights" — sleep durations × next-day plate energy from HER data
  (correlation spoken plainly, only past the data floor).
- "rhythm" — weigh-in cadence + plate-time regularity as a
  consistency story (Zheng: consistency > frequency).
- "sweetness" — ONLY if sugar grams exist in the model.

**Engine:** `SignalsEngine` (PlankApp/Program/) — pure, deterministic,
unit-tested; cohort clamps built in; all modules read through it.

## 6. Sources

- TRE meta-analyses: [PMC10630127](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10630127/) · [PMC12479299](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12479299/) · [Frontiers 2025](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1631477/full) · [PMC12888743](https://pmc.ncbi.nlm.nih.gov/articles/PMC12888743/)
- Late eating: [Vujović 2022 Cell Metabolism](https://www.cell.com/cell-metabolism/fulltext/S1550-4131(22)00397-7) · [PMC10184753](https://pmc.ncbi.nlm.nih.gov/articles/PMC10184753/)
- Sleep: [Tasali 2022 JAMA IM](https://jamanetwork.com/journals/jamainternalmedicine/fullarticle/2788694) · [PMC8822469](https://pmc.ncbi.nlm.nih.gov/articles/PMC8822469/)
- Post-meal movement: [Buffey 2022 Sports Med](https://pubmed.ncbi.nlm.nih.gov/36715875/) · [PMC8912639](https://pmc.ncbi.nlm.nih.gov/articles/PMC8912639/)
- Self-weighing: [Zheng 2015](https://onlinelibrary.wiley.com/doi/full/10.1002/oby.20946) · [PubMed 32437055](https://pubmed.ncbi.nlm.nih.gov/32437055/) · [PMC8277333](https://pmc.ncbi.nlm.nih.gov/articles/PMC8277333/)
- Meal regularity: [PubMed 27327128](https://pubmed.ncbi.nlm.nih.gov/27327128/) · [PMC11280377](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11280377/)
- Sugar: [WHO free sugars guideline](https://www.who.int/news/item/04-03-2015-who-calls-on-countries-to-reduce-sugars-intake-among-adults-and-children) · Te Morenga 2012 BMJ
- Retention: [JMIR mHealth 2023 engagement patterns](https://pmc.ncbi.nlm.nih.gov/articles/PMC10394603/) · [JMIR 2024 app engagement](https://www.jmir.org/2024/1/e45469) · [Spark 2025 protocol](https://www.researchprotocols.org/2025/1/e75629)
- Safety: [IF + disordered eating](https://pmc.ncbi.nlm.nih.gov/articles/PMC10589984/) · [GLP-1 + IF caution](https://pmc.ncbi.nlm.nih.gov/articles/PMC12730251/)
