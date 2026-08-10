# R2 — FOOD LOGGING + AI FOOD RECOGNITION (2025–2026)

Research date: 2026-08-10. Scope: photo-AI accuracy, multi-signal pipelines,
nutrition DBs, logging fatigue, actionable metrics, downstream value,
ED-safe design, monetization. Apps studied: MyFitnessPal, Lose It,
MacroFactor, Cronometer, Cal AI, Yazio, Lifesum, Simple, Fastic,
SnapCalorie, Foodvisor, January AI, Ate/AteMate, MyNetDiary, Noom/WW GLP-1.

Claim labels: **PROVEN** (peer-reviewed / replicated), **PROMISING**
(one good study or strong convergent evidence), **CLAIMED** (vendor or
unverifiable), **CONVENTION** (industry practice, no evidence),
**GIMMICK** (theater).

**Credibility warning that is itself a finding:** the food-app content web
is saturated with SEO "benchmark" sites (nutrola.app, nutriscan.app,
ai-food-tracker.com, caloriescanai.com, fitia.app…) publishing fake-precise
numbers ("PlateLens ±1.2% MAPE", "MFP 71.2% ID") that no lab could produce.
Every rival app runs a content farm reviewing its competitors. Numbers below
are tiered; SEO-only numbers are marked. Do not let Jeni marketing ever join
this genre — it is instantly recognizable and it is burning category trust.

---

## 1. PHOTO-AI ACCURACY — THE HONEST STATE OF THE ART

### Published evaluations (the ceiling is lower than the demos)
- **PROVEN — Frontier VLMs miss by ~35–40% on energy.** 2025 controlled
  study (52 standardized foods, 3 portion sizes, weighed ground truth):
  GPT-4o / Claude 3.5 Sonnet / Gemini 1.5 Pro → MAPE ~36–37% for weight,
  ~36% for energy; macro errors 42–110%; **protein error >60% on all
  models**; accuracy degrades as portions grow; occasional total
  misidentification. Correlations r = 0.58–0.81 → decent *relative/trend*
  accuracy, poor *absolute* accuracy.
  https://www.sciencedirect.com/science/article/pii/S2475299125030185 ·
  https://biolayne.com/reps/issue-44/can-we-use-ai-to-accurately-track-calories-with-a-picture/
- **PROVEN — Consumer photo apps systematically UNDER-count.** Controlled
  meal testing presented at NUTRITION 2026 (4 popular photo apps incl.
  Cal AI): calories + fat underestimated by ~one-third — roughly
  **−250 to −345 kcal and −30 g fat per meal**.
  https://www.medicaldaily.com/ai-calorie-tracking-apps-underestimate-calories-fat-nih-study-2026-476487
- **PROVEN — Recognition ≫ portioning.** 2025 RCT of an image-recognition
  meal app: 86% of dishes correctly identified, but portion-size estimation
  reliable in only ~39% of dishes tested. Recognition is a solved-ish
  problem; **portion volume is the open problem**.
  https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1501946/full
- **PROVEN — Systematic review agrees:** AI image assessment error varies
  wildly with food complexity, lighting, dataset diversity; user-correction
  ability is a primary determinant of real accuracy.
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10836267/
- Context anchors: nutrition labels are legally allowed ±20%; humans
  logging manually run ~40–50%+ error. AI at ~35% is *competitive with
  humans*, not with truth.

### Failure modes (recurring across every source)
1. **Hidden energy:** cooking oil, butter, dressings, sugar in sauces —
   invisible to any camera. Single largest undercount driver.
2. **Mixed/layered dishes:** stir-fry, curry, burrito, casserole → 30–50%+
   error (https://whatthefood.io/blog/ai-calorie-estimation-accuracy-explained).
3. **Portion volume without depth cues** (bowl depth, density, occlusion).
4. **Label/serving confusion:** reads per-100g as per-serving.
5. **Beverages & alcohol** (opaque cups), **restaurant portions** (larger
   than DB defaults).
6. Larger portions → larger error (LLM study above).

### Who is credible vs theatrical
- **SnapCalorie — most credible lineage.** Founded by ex-Google Lens
  people; built on **Nutrition5k** (CVPR 2021, 5k weighed real dishes,
  https://arxiv.org/pdf/2103.03375); uses iPhone depth sensor for volume.
  Claims ~15–16% mean kcal error / "2× nutritionist accuracy" — plausible
  direction (best monocular-depth papers hit ~14.7% PMAE kcal on
  Nutrition5k: https://arxiv.org/pdf/2310.11702) but self-reported →
  **CLAIMED, plausible**. Now "free forever" core (https://www.snapcalorie.com/).
- **MacroFactor — most honest posture.** AI photo/describe grounds output
  in **lab-analyzed DB entries, not raw LLM numbers**, decomposes into
  editable ingredients, explicitly says "AI can make mistakes, review
  before logging." https://macrofactor.com/ai-food-logging/
- **Cal AI — the theatrical pole.** 15M downloads, ~$30–50M ARR, sold to
  MyFitnessPal (Mar 2026: https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/).
  Its growth = TikTok + hard paywall, not accuracy. Independent tests: fine
  on plain single foods, 30–50% off on mixed meals, systematic undercount
  (NUTRITION 2026 above). **Apple removed it (Apr 2026) for deceptive
  billing / manipulative paywall** (weekly price displayed over real bill,
  post-decline re-offer): https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/.
  Plus a 3.2M-user data breach (Mar 2026). The "Cal AI critique discourse"
  is now the reference case that **photo-AI magic without correction UX is
  GIMMICK**.
- **MFP Meal Scan:** powered by **Passio SDK** (https://www.passio.ai/case-studies/myfitnesspal),
  Premium-only, real-time DB-match approach; MFP itself tells users to scan
  complex meals ingredient-by-ingredient
  (https://support.myfitnesspal.com/hc/en-us/articles/360045761612-Meal-Scan-FAQ).
- **Foodvisor:** decade-old French CV company; strongest on European
  dishes, weaker on US chains / pan-Asian; mid-tier accuracy per reviews
  (https://www.garagegymreviews.com/foodvisor-review) — **CONVENTION**.
- **Fastic "92% photo accuracy," PlateLens "±1.2%"** — unverifiable /
  impossible → **GIMMICK**.

### Bottom line for accuracy positioning
**PROVEN:** absolute calorie truth from a photo is not available to anyone
in 2026. What is available: honest ingredient recognition (~85%+), a
defensible ±30% energy band, good *relative* trends, and error mostly
recoverable through **one user touch** (portion nudge / "there's oil in
this"). Credibility comes from the correction loop, not the claim.

---

## 2. MULTI-SIGNAL ACCURACY — THE STRONGEST KNOWN PIPELINE

No single signal wins; the best systems converge signals:

- **Vision → verified-DB grounding** (MacroFactor, MFP/Passio): recognize
  candidates, then bind numbers to lab-analyzed database entries instead of
  letting the LLM invent nutrition. Kills hallucinated macros, keeps
  ingredient-level editability. **PROMISING→PROVEN pattern.**
- **Depth/volume signal** (SnapCalorie): LiDAR/stereo depth halves portion
  error vs monocular in the literature (DPF-Nutrition 14.7% PMAE kcal).
  **PROMISING**, iPhone-Pro-only in practice.
- **Barcode + label OCR beat vision whenever packaging exists.** Barcode =
  near-exact (label ±20% by law). Label-photo text-hint (Jeni v23 already)
  is the same trick MFP shipped as "Photo Upload" in 2026.
- **Clarifying questions + memory — the standout academic result.**
  **SnappyMeal** (arXiv, Nov 2025, longitudinal deployment): multimodal
  input + **targeted clarifying questions** + retrieval over the user's
  prior logs. Findings: clarifying felt collaborative not burdensome;
  memory cut redundant entry; accuracy beat single-modality baselines;
  "automation + user agency" was the satisfaction driver.
  https://arxiv.org/pdf/2511.03907 — **PROMISING, directly actionable.**
- **User-history priors:** people repeat meals heavily (see §4); yesterday's
  corrected plate is the best prior for today's photo. Corrections-as-moat.
- **Personal response data** (January AI): 32M-food DB + predicted glucose
  response without a CGM; TIME Best Inventions 2025
  (https://time.com/collections/best-inventions-2025/7318362/january-ai/).
  Impressive, but predictions are unverifiable to the user → trust rests on
  brand science. **CLAIMED** for consumer value.

**Canonical best pipeline (2026):**
photo/describe/voice → vision candidates → **match to curated DB entries**
→ portion via depth-or-context + user history → **≤1 clarifying question
when confidence is low** ("was there dressing?") → editable ingredient list
→ log → store correction as a prior. Every piece has evidence; nobody ships
all of it yet. MacroFactor is closest on grounding; SnappyMeal proves the
question+memory layer; SnapCalorie owns depth.

---

## 3. BARCODE + NUTRITION DATABASES — COVERAGE, QUALITY, LICENSING

| Source | Size / coverage | Quality | License / cost |
|---|---|---|---|
| **USDA FoodData Central** | 300K+ branded & foundation foods, US; monthly branded updates | Gold standard (lab/Foundation), branded = label data | **CC0 public domain, free**, 1,000 req/hr API key (https://fdc.nal.usda.gov/) |
| **Open Food Facts** | **4M+ products, 150 countries** (https://world.openfoodfacts.org/discover) | Crowdsourced, variable; strong EU, thinner US branded | **ODbL: attribution + SHARE-ALIKE** — derivative databases must be published open (https://world.openfoodfacts.org/terms-of-use) |
| **Nutritionix** | 1.9M+ items, strong US restaurant/branded | Dietitian-verified, NLP endpoint | Commercial; enterprise ~$1,850/mo (https://about.greenchoicenow.com/nutrition-data-api-comparison) |
| **FatSecret Platform** | 1.9M items, 56 countries, restaurant chains | Well-curated barcode DB | Free dev tier; Premier = MSA + volume pricing (https://platform.fatsecret.com/) |
| **NCCDB** (Cronometer's) | ~19K foods, deep micronutrients | Research-grade | Licensed, expensive |

- **PROVEN — crowdsourced DB entries are dirty:** comparative tests find
  MFP's 14M+ crowdsourced entries frequently 20–30% off vs USDA reference;
  Cronometer's curated NCCDB/USDA stance is its entire brand
  (https://neura.health/insight/cronometer-vs-myfitnesspal-which-is-better).
- **⚠️ ODbL trap for Jeni:** OFF is fine to *query live and display with
  attribution* (current v23 behavior). But **importing OFF rows into a
  proprietary food table, or enriching/merging them with Jeni's own data,
  creates a derivative database that must be open-licensed**. Keep OFF
  at-runtime, attributed, unmerged; cache only transiently.
- Best free stack for a US-first app: **USDA FDC (CC0) as canonical +
  OFF for barcode long-tail + vision-EF for plates + label OCR** — exactly
  Jeni's current shape; the missing tier is US restaurant chains
  (Nutritionix/FatSecret's paid moat).

---

## 4. LOGGING FATIGUE — WHY PEOPLE QUIT, WHAT EXTENDS LOGGING LIFE

### The abandonment curve (the real enemy)
- **PROVEN:** 50–70% of food-diary starters quit within the first month;
  ~20–30% still logging at 3 months. Median engagement with Lose It in a
  467K-user analysis: **29 days** (subgroups 3.5→172 days; the engaged
  subgroups were distinguished by *customization*, not willpower).
  https://pmc.ncbi.nlm.nih.gov/articles/PMC5526821/
- **PROVEN:** in trials, consistent tracking collapses ~68% (wk 1) → ~21%
  (wk 12); fewer than half of participants still track by week 10.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/
- **PROVEN:** adherence predicts outcome better than diet composition:
  tracking **≥2 eating occasions/day** is the best adherence marker
  (https://www.sciencedirect.com/science/article/abs/pii/S2212267219302655);
  early (8-week) adherence explains ~half of 6-month weight-loss variance.
- **PROMISING:** >15 min/day logging → ~2.1× more likely to abandon by
  month 3 (reported in adherence literature roundups). Time-cost is causal
  fuel for churn → every tap matters.

### Photo vs text — the uncomfortable evidence
- **PROVEN (pre-AI, still load-bearing):** Yale/JCR field study: people
  *predict* photo logging is easier, but photo-loggers were **less
  consistent, quit more, and were unhappier** than text-loggers — because
  **"you cannot go back in time with a camera."** Photo-first fails
  precisely at retrospective logging (forgot to shoot, ate half before
  remembering).
  https://insights.som.yale.edu/insights/when-counting-calories-words-are-more-valuable-than-pictures
- **CLAIMED (vendor, directionally opposite):** Lose It internal data on
  AI voice+photo loggers: 3.5× faster entry, 2× foods logged, "6% more
  weight loss" — promotional, self-selected.
  https://markets.financialcontent.com/clarkebroadcasting.mymotherlode/article/accwirecq-2025-4-22-lose-it-finds-ai-powered-logging-boosts-weight-loss-success-and-greater-nutritional-mindfulness
- Synthesis: photo is the best *capture* when food is in front of you; the
  apps that survive give equal-rank **retro paths** (describe-in-words,
  photo-library import, one-line day reconstruction). Photo-ONLY is a trap.

### Design choices with evidence they extend logging life
1. **PROVEN — repeat meals / meal memory.** 2026 analysis of food logs
   (112 adults, behavioral program): high dietary repetition → **5.9% vs
   4.3% body-weight loss**; mechanism = decision-fatigue reduction.
   https://neurosciencenews.com/routine-eating-weight-loss-30391/
   Combined with FLSI: re-log of a saved meal = 6 taps in MacroFactor.
   "Log it again" is the single highest-leverage logging feature.
2. **PROVEN — speed/friction.** MacroFactor's Food Logging Speed Index:
   24 discrete actions across 4 tasks vs 31–37 for MyNetDiary/LoseIt/MFP/
   Cronometer; barcode 5 taps. Friction compounds daily.
   https://macrofactor.com/fastest-food-logger-2025/
3. **PROVEN — app > paper/website** for sustained logging (JMIR RCT).
   https://www.jmir.org/2013/4/e32/
4. **PROMISING — partial logging legitimacy.** Since ≥2 occasions/day is
   the adherence marker, "log *something*, not everything" is the
   scientifically correct bar; apps that treat a 1-meal day as success
   (not a broken day) align with the evidence.
5. **PROMISING — streak-repair over streak-pressure.** Duolingo: 7-day
   streak holders retain 2.4×; **Streak Freeze cut churn ~21% among users
   about to break** — the retention power is in *forgiveness mechanics*,
   not the streak itself.
   https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/
   In diet apps, streak-shame collides with ED evidence (§7) → import the
   repair, not the fire emoji.
6. **CONVENTION — defaults/favorites/recent-first lists** (every surviving
   tracker). Boring, mandatory.

---

## 5. WHICH METRICS USERS ACTUALLY ACT ON

- **Calories + protein are the action pair.** Calories set the envelope;
  protein is the only macro with a daily behavioral response ("eat protein
  first"). MacroFactor's whole culture, Noom's GLP-1 "Muscle Defense,"
  WW's GLP-1 program (protein+fiber) all converge here.
  https://www.noom.com/med/glp1-companion/ ·
  https://www.weightwatchers.com/us/how-it-works/glp-1-program
- **GLP-1 users specifically (Jeni's cohort):**
  - **Protein floor 80–120 g/day (~1.2–1.6 g/kg)** — 15–40% of GLP-1
    weight loss is lean mass; protecting muscle is the #1 stated nutrition
    job (**PROVEN** need, echoed by Noom/WW/MyNetDiary/MeAgain/Shotsy).
  - **Fiber ~25–35 g/day** — constipation is a top-3 GLP-1 side effect;
    fiber tracking has a direct symptom payoff (**PROMISING**).
  - **Hydration** — suppressed appetite suppresses drinking; dehydration
    amplifies nausea/fatigue/constipation (**PROMISING**).
    https://shotsyapp.com/why-glp-1-users-need-a-new-kind-of-health-tracking-app/
  - **Tiny portions break standard servings** — GLP-1 plates are ⅓-size;
    portion UIs anchored on "1 serving" misfit; photo + fractions matter.
- **Dashboard clutter (evidence of non-use):** sodium, sat-fat, sugar
  breakdowns, micronutrient grids — Cronometer owns the micro-audit niche
  precisely because mainstream users won't look at 84 nutrients. Simple's
  answer (one food score blending protein/fiber/sugar) teaches without
  arithmetic — **PROMISING** for score-haters but scores contradict Jeni's
  v23 "no scores" law; the *selection* insight (protein/fiber/sugar are the
  three that matter) still transfers.
- **Fasting-vocabulary metrics** (Yazio/Fastic/Simple windows) — banned in
  Jeni's register anyway; no evidence GLP-1 users want them.

---

## 6. DOWNSTREAM VALUE — TURNING THE JOURNAL INTO SOMETHING

- **MacroFactor's expenditure engine is the category's best lesson.**
  Intake + weight → continuously-solved TDEE → weekly target adjustments
  that are **adherence-neutral** ("the coach doesn't care *that* you went
  over; the data already includes it"). Users pay $71.99/yr with **no free
  tier** primarily for this loop — the journal literally powers the
  product. https://www.strongerbyscience.com/macrofactor-algorithms-philosophy/
  **PROVEN as a retention/monetization architecture.**
- **Lose It "Insights/Patterns":** pattern mining pushed as notifications
  ("you eat 40% of calories after 8pm"). Users cite it positively in
  reviews; no public engagement data — **CONVENTION/PROMISING**.
- **January AI:** food log → per-food glucose forecasts. Award-winning,
  but the value is unverifiable without a CGM — **CLAIMED**.
- **Ate/AteMate (anti-metric pole):** photo journal + reflective prompts
  ("how did this make you feel"), paths not calories. Small but fiercely
  loyal ED-adjacent audience — **PROMISING for tone**, not for scale.
- **Weekly reads:** every incumbent ships a weekly report; none publish
  open rates. The honest read: **daily-glance value is proven (glance =
  today's protein/cals), weekly narrative value is plausible but
  unproven** — keep it cheap.
- Correlation engines ("X seems to follow Y") exist in Shotsy/MeAgain for
  GLP-1 side effects; Jeni v24's timing-never-causality patterns engine is
  already the compliant version of this.

---

## 7. ANTI-OBSESSION / ED-SAFE DESIGN — EVIDENCE + PATTERNS

- **PROVEN — harm signal is real:** 2025 Flinders review (38 studies):
  diet/fitness-app users show elevated disordered-eating symptoms vs
  non-users (correlational; self-selection likely but consistent).
  https://news.flinders.edu.au/blog/2025/02/22/fitness-apps-fuelling-disordered-eating/
- **PROVEN — the harmful *design elements* are specific:** qualitative
  ED-patient work (BJPsych Open): number fixation, **red/green feedback**,
  target-miss warnings, streaks/competition, "achievement vs failure"
  emotional swings. https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
- **PROVEN — motive moderates harm:** tracking for weight/shape reasons →
  more symptomatology than health-motivated tracking.
  https://www.sciencedirect.com/science/article/abs/pii/S1471015321000957
- Working patterns in the market:
  - **Adherence-neutral coaching** (MacroFactor: "no warnings, no red
    numbers, no shaming" is on the App Store listing) — **PROVEN
    retention-compatible**; their users are the most loyal in the category.
  - **Weekly-envelope view after a heavy day** (Lose It weekly budget) —
    reframes without absolution theater.
  - **No-number modes** (Ate, See How You Eat: photo-only journaling) —
    niche but real.
  - **No red bars / no over-target alarms** — Jeni already law (anti-shame
    food UX; under-target-net).
  - **Repeat-meal normalization** — repetition evidence (§4) doubles as
    anti-obsession: fewer decisions, less scanning-everything behavior.
- **GIMMICK to avoid:** "guilt-free day passes," cheat-day mechanics,
  purity scores, body-goal streaks.

---

## 8. WHAT USERS PAY FOR — PRICE POINTS + CONVERSION

Benchmarks (RevenueCat State of Subscription Apps 2025, health&fitness):
median trial→paid **39.9%** (top decile 68.3%); median annual price
**$29.65** (~3.8× monthly $7.73); ~68% of volume on annual; median
60-day revenue per install $0.63; only ~5% of H&F apps ever reach $10K
total revenue. https://www.revenuecat.com/state-of-subscription-apps-2025

Price ladder 2025–26 (annual): Cal AI ~$29.99 (dynamic, 3-day hard trial)
· Lose It $39.99 · Yazio ~$47.90 · Lifesum $49.99 · Cronometer Gold
~$49.99 · Simple ~$50 · MacroFactor **$71.99 no free tier** · MFP $79.99
(Premium+ $99.99).

What the market proves converts:
- **PROVEN — hard-paywall AI-photo hook converts at volume:** Cal AI rode
  onboarding-quiz → dynamic price → 3-day trial to ~$30M+ ARR and 3×
  monthly-revenue growth via aggressive paywall experimentation
  (https://superwall.com/case-studies/cal-ai) — **but** the same playbook
  produced an Apple removal for deceptive billing and a brand now owned by
  MFP for its user base, not its tech. Conversion tactic proven; brand
  cost proven too.
- **PROVEN — don't paywall table stakes:** MFP's 2022 barcode paywall
  ($19.99/mo) remains the category's canonical churn/backlash event;
  competitors still advertise "free barcode" against it.
  https://www.digitaltrends.com/phones/myfitnesspal-barcode-scanning-not-free-premium-subscription/
- **PROVEN — algorithm-as-product supports premium-only:** MacroFactor's
  no-free-tier works because the adaptive coaching loop (not logging) is
  the product. People pay for *the system reading their data*, not for
  the diary.
- **CONVENTION:** AI photo scanning is now a paywall feature everywhere
  (MFP Premium, Yazio PRO, Lose It Premium, Foodvisor) — it is an
  acquisition hook, not a retention moat; retention still comes from the
  loop (§6).

---

## IMPLICATIONS FOR JENI (RANKED)

1. **Ship the correction loop, not an accuracy claim.** State of the art
   is ±30%+ on mixed plates; under-counting is systematic. THE READING
   should make the one-touch fix (portion nudge, "cooked in oil?"
   ingredient add) feel like part of the craft, and Jeni should *never*
   print an accuracy % or a false-precision calorie (no decimals). Trust
   is the differentiator Cal AI burned.
2. **Add ONE low-confidence clarifying question to the vision EF.**
   SnappyMeal is the strongest recent evidence: a single targeted question
   ("dressing on that salad?") + user-history memory beats silent
   guessing, and users experience it as collaboration. Cap at one; never
   interrogate. (Jeni's chat envelope + EF already have the seams.)
3. **Make "again" a first-class citizen — meal memory as the accuracy
   engine.** Repetition is evidence-backed (5.9% vs 4.3% weight loss) and
   is also the best portion prior: yesterday's corrected plate should
   pre-fill today's similar photo. Target ≤6 taps for a repeat log (FLSI
   bar). This is the cheapest accuracy *and* retention win on the list.
4. **Legitimize partial + retro logging.** The camera cannot go back in
   time (Yale/JCR) — photo-first must be backed by equal-rank describe-
   in-words ("chicken salad, big") and end-of-day reconstruction. Treat a
   1–2-entry day as a *kept* day (≥2 occasions/day is the clinical
   adherence bar), never a broken one. THE BOOK should absorb sparse days
   without visual punishment.
5. **Surface the GLP-1 action pair: protein floor + fiber.** Calories
   present but quiet; protein-vs-floor is the daily behavioral lever
   (80–120 g; already Jeni's floor bar), fiber earns its place through the
   constipation payoff, hydration rides with the dose-day support cadence.
   Sodium/sat-fat/micros stay off the glance layer — doors, not dashboard.
6. **Design for day 29.** Median logging life is ~a month. Plan the
   décrescendo: after week 3–4, offer lighter modes (photo-only days,
   protein-only days) instead of silence, and build the re-entry ritual
   after a gap — no streaks, no guilt, "the book has room" (Duolingo's
   *repair* mechanic, stripped of the streak).
7. **Keep the journal powering something visible.** MacroFactor proves
   people pay for a system that *reads* their log (expenditure loop).
   Jeni's equivalent spine: plates → protein floor + patterns
   (timing-never-causality) + weekly read in THE BOOK. Keep weekly
   narrative cheap (unproven engagement); keep the daily glance rich.
8. **DB strategy: stay USDA-canonical + OFF-at-runtime.** USDA FDC (CC0)
   as the numbers backbone; OFF for barcode long-tail **queried live with
   attribution — never imported/merged into Jeni's tables (ODbL
   share-alike would open-license the derivative)**. The paid gap is US
   restaurant chains — defer; a "restaurant meal, estimated generously"
   honesty state beats licensing Nutritionix at $1,850/mo.
9. **Pricing posture is already right.** Keep-wall + annual anchor sits in
   the proven band ($30–80); photo AI is the hook, the reading/regimen
   loop is the retention story. Never copy Cal AI's weekly-price
   prominence or post-decline re-offers — that exact pattern got an app
   removed in 2026.

### DO NOT BUILD
- **A proprietary food database** (scraping/merging OFF or crowdsourcing
  entries) — licensing contamination + MFP's dirty-DB reputation shows
  crowdsourcing degrades trust.
- **Accuracy-% marketing or a "benchmarks" content farm** — the SEO
  benchmark-spam genre is recognizable and radioactive.
- **Streak mechanics with loss pressure** (fire emoji, "don't break it") —
  ED evidence is specific about this harm; import only repair/forgiveness.
- **Red/green day judgments, over-target alarms, purity/food scores** —
  harmful per ED literature and contrary to v23 "no scores" law.
- **A micronutrient dashboard** — Cronometer owns the niche; clutter for
  Jeni's cohort.
- **Glucose prediction** — January AI's moat, unverifiable value, violates
  Jeni's provenance law (never a number that can't be traced).
- **Depth-sensor volume estimation as a launch bet** — real but Pro-device
  gated and marginal vs the correction loop; revisit if Apple ships food
  volume APIs.
- **Photo-ONLY logging identity** — the Yale result stands as a warning;
  Jeni is photo-*led*, never photo-only.
- **Fabricated outcome stats** ("users lose X%") — compliance floor +
  provenance law already forbid; the Lose It "6% more weight loss" genre
  is what not to publish.
