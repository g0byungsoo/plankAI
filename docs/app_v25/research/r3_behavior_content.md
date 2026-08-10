# R3 — BEHAVIOR CHANGE + EDUCATIONAL CONTENT IN WEIGHT APPS (2025-2026)

Research subagent report, 2026-08-10. Domain: does lesson-library content earn engagement,
what formats do, what science is worth encoding, GLP-1-era adaptations, and whether Jeni
should have a lesson library at all. Evidence labels: **PROVEN** (RCT/meta-analysis),
**PROMISING** (consistent observational/pilot), **CLAIMED** (vendor data, unverified),
**CONVENTION** (industry habit, no outcome evidence), **GIMMICK** (engagement theater).

---

## 1. DO LESSON LIBRARIES GET USED? (No. Here is the evidence chain.)

### Noom's own data is the strongest indictment of Noom's own format
Noom's retrospective of 11,252 paying users (JMIR 2021) measured 7 engagement types
against weight outcomes. Articles read — the CBT curriculum, Noom's namesake feature —
was among the WEAKEST predictors:

- Meal logging: adjusted R² 0.16-0.20 (strongest at every timepoint)
- Weigh-ins: adjusted R² 0.10-0.17
- **Articles read: adjusted R² 0.05-0.06**
- Coach messages: adjusted R² 0.01-0.03
- Even the HIGH-weight-loss group read only ~1.2 articles per WEEK at weeks 17-32
  (Noom assigns several per day → real curriculum completion is single-digit %).
- Engagement declined over time on 6 of 7 measures.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8663454/

**PROVEN (against lessons): in the flagship lesson-library product, doing (logging,
weighing) predicts outcomes 2-4x more strongly than reading.** Noom's PR line that
"articles read correlates with weight loss" is technically true and practically the
weakest correlation in their own table.

### Noom's efficacy evidence is modest even when lessons are consumed
Largest-ever Noom RCT (n=427, Obesity Science & Practice 2026): 16-week program,
-4.05% body weight at 68 weeks vs +1.46% control; 41% achieved ≥5% loss vs 19.5%.
Real but modest — roughly half of what structured clinical behavioral programs (DPP:
~-7% at 1yr) deliver, and an order below GLP-1 pharmacotherapy (~15-21%).
https://www.globenewswire.com/news-release/2026/06/04/3306707/0/en/Noom-Members-Kept-Losing-Weight-a-Full-Year-After-the-Program-Ended-Largest-Ever-Noom-Randomized-Clinical-Trial-Shows.html
Noom's "CBT-based" branding is itself contested: app content is CBT-inspired psycho-
education, not clinical CBT; coach credentials are proprietary, not licensed.
https://medium.com/@Edward19/noom-in-2026-an-evidence-based-guide-to-what-it-actually-does-and-doesnt-do-9b8a7c69d110
**Label: Noom "psychology" = CLAIMED, drifting toward CONVENTION.**

### 2025-2026 user sentiment on daily lessons
Consistent across independent 2026 reviews: lessons feel fresh ~2-3 weeks, then
"repetitive," "busywork," "a treadmill designed to justify continued billing";
boredom with lessons is a named churn driver.
https://www.saasweep.com/blog/noom-review · https://millennialhawk.com/noom-review/
https://www.amyfoodjournal.com/blog/noom-review
Noom's 2025-2026 pivot is telling: growth now comes from Noom Med / GLP-1Rx
(compounded semaglutide + tracking), and their flagship engagement metric became APP
OPENS, not lessons completed (Engagement Report, Feb 2026: top-quartile users lost
25.2% more, stayed on medication 2.2x longer — engagement defined as app opens).
https://finance.yahoo.com/news/noom-engagement-report-data-shows-130000752.html
**The company that owns "daily lessons" quietly stopped selling them.**

### Why lessons die (the mechanism)
1. **Law of Attrition (Eysenbach 2005, still the canonical cite): eHealth attrition
   routinely exceeds 50%; most users of multi-session programs complete a fraction
   of intended content.** One 4-month weight app study: 83% attrition. PROVEN.
   https://www.jmir.org/2005/1/e11/ · https://pmc.ncbi.nlm.nih.gov/articles/PMC12093073/
2. Lessons are pull-based homework competing with push-based life; they lack a
   trigger tied to a real moment (the food is already eaten by lesson time).
3. Finite curricula exhaust: repetition is structurally guaranteed by month 2-3.
4. Generic content can't survive contact with a specific person's week; the same
   lesson is right for someone, wrong for you, today.
5. Completion is performable — you can "do the lesson" without doing the behavior
   (see Duolingo, §5). Curriculum progress is a vanity metric.

**Verdict on the question: lesson-library content is read briefly, early, by a
minority, and its marginal contribution to outcomes is the smallest of any core
feature it ships beside. PROVEN.**

---

## 2. FORMATS THAT DO EARN ATTENTION (evidence per format)

| Format | Evidence | Label |
|---|---|---|
| **Contextual/just-in-time (JITAI)** | Scoping review of 35 JITAI weight studies: engagement↔outcomes consistent, but NO fully-powered effective weight-loss JITAI yet; pilot: 68% of triggered messages viewed, viewing → hitting that day's goal. AGILE factorial RCT (n=608) underway. | PROMISING (delivery), not yet PROVEN (weight) https://pubmed.ncbi.nlm.nih.gov/41447266/ · https://www.sciencedirect.com/science/article/abs/pii/S1551714425000023 |
| **Cards at the moment of action** (tip attached to a log/reading) | No isolated RCTs; it is the JITAI hypothesis embodied + the only format that survives in wearables (Oura/WHOOP §5). Vendor survey: 56-60% say insight cards changed understanding/action. | PROMISING |
| **Weekly review ritual** | Factorial pilot: weekly facilitated group −5.3% vs −3.1% without. Bigger: PRE-SCRIPTED modular weekly feedback BEAT counselor-crafted feedback (−5.3% vs −3.1%) — well-designed templated reflection outperforms bespoke human prose. Expert Delphi (2025) converging on weekly cadence for reflective feedback; per-meal feedback dulls sensitivity. | PROVEN (weekly feedback helps; templated ≥ human) https://pmc.ncbi.nlm.nih.gov/articles/PMC9358748/ · https://onlinelibrary.wiley.com/doi/10.1002/osp4.70104 |
| **Coach/SMS messages** | Meta-analyses: small-to-moderate weight effects vs control; tailored > generic; effect decays with duration. In Noom's own data coach messages were the weakest predictor (R² 0.01-0.03). | PROVEN-small https://pubmed.ncbi.nlm.nih.gov/32043809/ · https://pmc.ncbi.nlm.nih.gov/articles/PMC11562155/ |
| **Interactive check-ins** (1-tap state capture that adapts the day) | Core of effective JITAI protocols (lapse-risk EMA); micro-randomized trials running. Engagement high when burden is 1 tap, dies when it's a survey. | PROMISING https://pmc.ncbi.nlm.nih.gov/articles/PMC8691411/ |
| **Micro-learning (<60s)** | Education literature: improves short-term knowledge retention + satisfaction (RCT in medication adherence, 2025); explicit gap: little evidence of long-term behavior change. Fine as a delivery skin, not a strategy. | PROMISING (knowledge), CLAIMED (behavior) https://www.nature.com/articles/s41598-025-29769-7 |
| **Audio** | Headspace model works for meditation because audio IS the behavior. For weight content, no comparative evidence; adds production cost, breaks skimmability. | CONVENTION |
| **Video courses** | WW ships strength-training videos (utility video = demonstration, good); talking-head lesson video has no engagement evidence over text and the highest production+consumption cost. | CONVENTION (lesson video), reasonable for exercise demos |
| **Streaks/XP on learning** | Duolingo case (§5): engagement metrics up, learning decoupled; streak-preservation gaming. In a weight app this manufactures anxiety in exactly the population sensitive to shame. | GIMMICK |

**The pattern: formats win when the content arrives attached to a datum the user just
generated (a log, a weigh-in, a dose, a week ending) — and lose when they ask for an
appointment with a curriculum.**

---

## 3. THE ACTUAL SCIENCE WORTH ENCODING

Ranked by evidence strength × encodability into product surfaces (not lessons).

1. **Self-monitoring is the intervention.** The single most robust finding in the
   entire field: consistent logging/weighing predicts loss and maintenance across
   every review. Everything else is scaffolding to keep monitoring alive. PROVEN.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC6861632/
2. **Self-weighing**: effective only inside multi-component programs (+1.7 kg vs
   without); DAILY vs WEEKLY makes no outcome difference; no average psych harm — BUT
   an RCT in emerging-adult women (Jeni's demo) found daily weighing → greater
   negative affective lability vs control. Encode: weekly-anchored trend, daily
   optional, never scolded. PROVEN (weekly ≈ daily; component-not-standalone).
   https://ijbnpa.biomedcentral.com/articles/10.1186/s12966-015-0267-4 ·
   https://pmc.ncbi.nlm.nih.gov/articles/PMC11351998/
3. **Implementation intentions (Gollwitzer).** If-then plans: overall d≈0.65; healthy
   eating d 0.33-0.51; weaker for SUPPRESSING unhealthy eating (d 0.18-0.29). Encode
   as one-line plan prompts at moments ("if 3pm slump, then X"), never as a worksheet.
   PROVEN, with the asymmetry respected.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC9160833/
4. **Habit formation (Lally/Wood).** Automaticity median ~66 days (range 18-254);
   context-stable cues + immediate reward accelerate; missing one day doesn't reset.
   10 Top Tips RCT: habit-based advice beat usual care and automaticity MEDIATED the
   loss. Encode: anchor new behaviors to existing stable cues (dose day is a gift of
   a cue); track consistency-in-context, not streaks. PROVEN.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC5583960/
5. **Maintenance science (NWCR + regain predictors).** NWCR (10-yr cohort): ~75%
   weigh ≥weekly; DECLINE in self-weighing frequency precedes regain (4.0 kg vs 1.1 kg
   regain); dietary consistency, activity, breakfast. Registry is self-selected —
   treat as descriptive, not causal. Encode: monitoring-decay detection as an early-
   warning signal (the app notices quitting before she does). PROMISING-to-PROVEN.
   https://pubmed.ncbi.nlm.nih.gov/24355667/ · https://pubmed.ncbi.nlm.nih.gov/18198319/
6. **Self-efficacy via early small wins.** Early gain in tracking self-efficacy
   (first month) mediates later engagement + loss; autonomous motivation, flexible
   restraint, self-regulation skills are the replicated mediators. Encode: make the
   first weeks rig the experience for visible small wins; celebrate process not
   pounds. PROVEN (as mediator).
   https://pubmed.ncbi.nlm.nih.gov/39673768/ · https://pmc.ncbi.nlm.nih.gov/articles/PMC4408562/
7. **Plateau psychology / expectation setting.** Daily weight gain days → guilt,
   shame, lower confidence; dissatisfaction → goal disengagement. Expectation
   calibration and reframing (weight stability = the skill of maintenance rehearsed
   early) is the intervention; third-wave (ACT) skills improve maintenance mediators.
   Encode in the trend surface's language at detected plateaus. PROMISING.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC11026204/
8. **Emotional eating / cravings.** Urge surfing: reduces urge-driven BEHAVIOR, not
   urge frequency; evidence modest, imported from addiction. Delay/decentering
   tactics work as in-the-moment tools. Mindfulness-based interventions: consistent
   for binge/emotional eating reduction; weight effects MIXED/NULL; digital MBIs
   show no significant BMI change. Encode as a 60-second in-the-moment tool behind a
   craving door, not a course. PROMISING (behavior), CLAIMED (weight).
   https://positivepsychology.com/urge-surfing/ ·
   https://onlinelibrary.wiley.com/doi/10.1111/obr.13860 ·
   https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2026.1874656/full
9. **Environment design / choice architecture.** Direction consistent (visibility,
   position, plate size), effect sizes unquantified, mostly institutional settings;
   home-environment RCT evidence thin. Cheap to offer as occasional concrete tips;
   don't oversell. PROMISING-weak.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC10478061/
10. **Motivational interviewing, digitized.** Beat NO-treatment in 6/11 comparisons;
    beat an ACTIVE comparator in 1/7. Chatbot MI: safe, acceptable, efficacy unshown.
    MI's spirit (autonomy, reflective, no lecturing) should shape the COACH VOICE;
    MI as a technique module is not worth building. PROVEN-null vs active care.
    https://pmc.ncbi.nlm.nih.gov/articles/PMC12101826/
11. **Mental contrasting (WOOP)**: small-to-medium adjunct in meta-analysis; optional
    seasoning for goal moments. PROMISING.
    https://pmc.ncbi.nlm.nih.gov/articles/PMC8149892/

---

## 4. GLP-1-ERA ADAPTATIONS (what matters when appetite is suppressed)

The behavioral question inverts: not "how do I resist food" but "what must I do on
purpose now that hunger no longer runs the day."

- **Protein adequacy + resistance training = the two non-negotiables.** Lean mass is
  25-39% of GLP-1 weight loss in trials. RT 2-3x/wk cuts fat-free-mass loss 30-50%
  (2024 systematic review); protein 1.2-2.0 g/kg with per-meal distribution (~30g).
  2025 cohort combining both: 13% weight loss, only 3% muscle. PROVEN.
  https://www.acefitness.org/continuing-education/certified/june-2025/8892/glp-1s-and-lean-mass-what-the-research-shows/ ·
  https://www.nature.com/articles/s41366-025-01952-w
- **Re-learning satiety/interoception.** GLP-1 users report clearer hunger/fullness
  signals and less external-cue eating; clinicians converge on training interoceptive
  awareness DURING the medicated window so cues survive discontinuation. Mechanistic
  + qualitative, no RCT yet. PROMISING.
  https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2026.1870484/ ·
  https://pmc.ncbi.nlm.nih.gov/articles/PMC12694361/
- **"Food noise."** Now a validated construct (Food Noise Questionnaire, Nutrition &
  Diabetes 2025); GLP-1 + behavioral program reduced FNQ −4.05 vs −1.15 behavioral-
  only. Users' own language; framed as maladaptive prospection. Jeni already speaks
  it (post-Ozempic vocabulary law) — the science caught up to the vocabulary. PROVEN
  (construct + drug effect).
  https://www.nature.com/articles/s41387-025-00382-x · https://www.psypost.org/glp-1-medications-combined-with-lifestyle-changes-effectively-quiet-food-noise-new-research-suggests/
- **Fear of regain / the off-ramp.** Regain after stopping: ~2/3 of lost weight back
  within 1 year; projected baseline by ~1.5-1.8 yrs (meta-regression, eClinMed 2026).
  Sobering: behavioral support DURING treatment added 4.6 kg extra loss but did NOT
  slow post-discontinuation regain in the pooled analysis — generic behavioral
  support is not an off-ramp. Virta's structured deprescription (nutrition-therapy
  taper) claims 12.1% maintained at 1 yr post-GLP-1 (retrospective, selected
  population — CLAIMED); guided-taper survey: 8x more likely to keep losing
  (survey — CLAIMED). Maintenance-specific programs post-AOM are just entering
  trials (UAB pilot, NCT07535892). PROVEN (regain risk), CLAIMED (all off-ramp
  solutions).
  https://pmc.ncbi.nlm.nih.gov/articles/PMC13043475/ ·
  https://www.thelancet.com/journals/eclinm/article/PIIS2589-5370(26)00240-3/fulltext ·
  https://www.fiercehealthcare.com/payers/virta-health-champions-its-nutrition-therapy-effective-glp-1-ramp-heres-why
- **Identity shift.** Exercise identity gains during intervention predict maintenance
  6 months later; healthy-eater identity predicts behavior; qualitative maintenance
  literature repeatedly surfaces "shift in identity." The medication window (relief
  from food noise) is the identity-rebuilding window. PROMISING.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10885534/
- **Nausea/side-effect behavioral management** (small frequent meals, fluid timing,
  fiber pacing) is the #1 early-weeks content need and the #1 driver of
  discontinuation — support here IS retention. PROMISING (Omada mechanism data).

### Who does GLP-1-adapted behavioral content well
- **Omada GLP-1 Care Track** (150k+ members): side-effect navigation, dose-titration
  education, protein/muscle focus, off-ramp track. 84% persistence at 24 wks; +10
  engagements/wk → 54% higher persistence odds; 28% greater loss vs matched
  non-track. Company-published, real-world — strongest companion evidence base.
  CLAIMED-to-PROMISING. https://www.omadahealth.com/resource-center/omada-health-s-enhanced-glp-1-care-track-demonstrates-increased-medication-persistence-and-weight-loss-outcomes-at-12-and-24-weeks
- **WW GLP-1 Companion**: the cleanest CONTENT adaptation — protein target 1g/kg,
  fiber servings, strength videos, injection logging, Points demoted to optional.
  They rebuilt the program around the two proven pillars. CONVENTION-done-well.
  https://www.weightwatchers.com/us/blog/weight-loss-diet/points-glp-1-program-explained
- **Virta**: owns the off-ramp narrative with actual (retrospective) deprescription
  data. https://www.virtahealth.com/weight-loss-and-glp-1s
- **Calibrate**: 4-year real-world curve (16%→21%); coaching-attendance dose-response
  (all-session attendees lost 16% more). Curriculum = 4 pillars with weekly coach.
  CLAIMED. https://www.prnewswire.com/news-releases/calibrate-publishes-largest-real-world-four-year-analysis-of-glp-1-weight-loss-outcomes-when-paired-with-integrated-behavioral-support-302762645.html
- **Noom Med**: scale + engagement report, but support content is thin relative to
  marketing; complaint pattern: prescribing speed, billing confusion.
- **Second Nature (UK)**: NHS-published BMJ pedigree for habit-based program; now
  meds+behavior; dietitian-led. https://www.secondnature.io/us/blog/new-nhs-weight-loss-research
- **Twin Health**: the far pole — no curriculum at all; sensor-driven personalized
  nudges + care team; NEJM Catalyst RCT; "safely deprescribing GLP-1s without
  rebound" claims. Education fully dissolved into data. CLAIMED-to-PROMISING.
  https://www.prnewswire.com/news-releases/twin-health-outperforms-traditional-care--legacy-digital-health-solutions-setting-new-standard-for-diabetes-and-weight-loss-302574280.html

**Nobody has nailed consumer-grade GLP-1 behavioral content without a human care team
attached. The white space is exactly Jeni's lane: data-triggered, era-aware teaching
with no homework and no coach payroll.**

---

## 5. TEACHING WITHOUT HOMEWORK-FEEL (what transfers)

- **Duolingo** — the cautionary tale. Streaks/XP/leagues drove DAU +36% YoY while
  community consensus and internal framing concede learning decoupled ("fun first,
  learn as a byproduct"); streak-preservation gaming (speed-run an easy lesson) is
  the norm. Transfers: DON'T import completion mechanics into a shame-sensitive
  domain. The engagement they bought with anxiety, a weight app pays for in churn.
  GIMMICK for this domain.
  https://theeconomyofmeaning.com/2025/08/25/a-critical-look-at-how-to-make-learning-as-addictive-as-social-media-a-ted-talk-about-duolingo/
- **Oura (Advisor + insight cards)** — the model that fits Jeni best. Teaching is a
  one-card consequence of YOUR last night's data; Advisor holds memory and explains
  metrics on demand. Tester survey: 60% understood metrics better, 56% acted.
  Education as annotation of lived data, zero curriculum. CLAIMED (their survey),
  but the pattern is the industry's revealed preference. https://ouraring.com/blog/oura-advisor/
- **WHOOP Coach** — LLM over your own historical data, with memory ("knows you
  travel"); teaching arrives as answers and anticipations, not modules. CONVENTION
  (no outcome data) but directionally identical to Oura.
- **Headspace** — the honest place for a library: tools organized by MOMENT (SOS
  3-minute singles for panic/craving/night) beside optional courses; push nudges
  +32% session completion (vendor). Transfers: a small shelf of in-the-moment TOOLS
  (not readings) earns its place; courses are optional depth, never the spine.
  https://trophy.so/blog/headspace-gamification-case-study
- **Simple (Avo)** — closest consumer analog: AI coach delivering contextual
  micro-guidance at logging moments (19M coaching messages/month; observational
  cohort: 42% achieved ≥5% at 1 yr). Lesson library demoted to answers-on-demand.
  CLAIMED. https://tech.eu/2025/10/02/simple-life-lands-35m-to-scale-its-ai-health-coach/
- **Second-order lesson from the weekly-feedback factorial (§2): well-designed
  TEMPLATED reflection beat bespoke counselor prose.** A deterministic weekly-review
  grammar (Jeni already has R6 insight grammar) is not a compromise — it's the
  better-performing arm. PROVEN.

**Transfer principle: the products that teach well all moved education from a PLACE
you go to a PROPERTY of the data you already made. The unit is one card, one moment,
one behavior; memory makes it cumulative; the library survives only as (a) moment-
tools and (b) reference depth behind doors.**

---

## 6. HONEST VERDICT

**Is a lesson library worth having for a GLP-1-era companion? As a spine — no.
As a shelf — barely, and only reborn as moment-tools + reference doors.**

- The engagement evidence (§1) is unambiguous: curricula decay in weeks; their
  outcome contribution is the smallest of any core feature; the market leader that
  invented the category has demoted it.
- BUT "no lessons" ≠ "no teaching." The science stack (§3) and the GLP-1 stack (§4)
  are real and must reach her — through surfaces: coach envelope, insight cards,
  weekly review, dose-day beats, plateau-triggered reframes, era transitions.
- The strongest version for a GLP-1 companion:
  1. **A knowledge engine, not a curriculum**: ~40-80 atomic teachings (one idea,
     one act, one line + optional "why" depth), each tagged with TRIGGERS (event,
     era, pattern, question) and exhausted-state rules. Delivery surfaces already
     exist in Jeni; no new tab.
  2. **The weekly review as the only ritual** — templated grammar, her data, one
     reflective question, one plan for next week (implementation-intention shaped).
  3. **Moment-tools shelf** (Headspace-SOS-shaped): craving/urge tool, nausea
     playbook, restaurant card, plateau reframe — reachable in ≤2 taps when the
     moment is happening, invisible otherwise.
  4. **Era-aware sequencing**: early-med weeks teach side-effect nav + protein floor;
     mid teaches strength + satiety re-learning + identity; taper/maintenance
     teaches monitoring-decay vigilance + regain honesty. The regimen version
     chains (v24) are the sequencer a curriculum never had.

---

## IMPLICATIONS FOR JENI (ranked)

1. **Kill the Method as a destination library.** The founder's instinct is the
   evidence's conclusion. Do not delete the CONTENT — decompose the salvageable
   ideas into atomic, trigger-tagged teachings. The library dies; the knowledge
   disperses into surfaces. (§1 PROVEN)
2. **Teach at data moments, through existing surfaces.** Attach one-line teachings
   to: the food reading (protein floor short of target → 30g-per-meal card), the
   dose sheet (dose day = strength-day anchor cue), the patterns engine ("picked up
   after the dose changed" already speaks timing — add one optional "what usually
   helps" line), the becoming tiles. Zero new IA. (§2 PROMISING, §5)
3. **Make the weekly review the single teaching ritual.** Jeni's weekly insight
   carousel is already the right grammar; upgrade it to a review-and-plan: what
   happened (her data) → one teaching that explains it → one if-then plan she taps
   to accept. Templated beat bespoke in trial. (§2 PROVEN)
4. **Build the GLP-1 era curriculum-as-triggers, not lessons**: side-effect
   playbooks in week 1-4 (retention = persistence), protein + resistance training
   as the two drumbeats (the ONLY two PROVEN GLP-1 content pillars), satiety
   re-learning mid-era, monitoring-vigilance + regain honesty at taper. Sequence off
   RegimenPlanRecord eras — the infrastructure v24 already shipped. (§4)
5. **Encode monitoring-decay as a signal.** NWCR + mediator lit: declining weigh-in/
   log frequency is the earliest regain predictor. Patterns engine should notice
   decay and respond with warmth, never scold (fits fuller-weeks-never-scolded law).
   (§3 PROMISING-PROVEN)
6. **A tiny moment-tools shelf (≤5 tools), Headspace-SOS-shaped**: 60-second craving
   tool (urge-surf/delay framing), nausea playbook, eating-out card, plateau
   reframe, "food noise came back" door. In-the-moment utility, not readings. (§3.8)
7. **Let the chat coach be the on-demand teacher** with MI SPIRIT (reflective,
   autonomy-honoring, never lecturing) — the coach envelope medication{} pattern
   extends to teaching context. Do not build MI "technique" flows. (§3.10 PROVEN-null)
8. **Expectation-setting at detected plateaus** — trend-surface language that
   pre-frames stalls as maintenance rehearsal; guilt after up-days is the
   disengagement mechanism, and Jeni's anti-shame laws already align. (§3.7)

### DO-NOT-BUILD
- **A lessons tab / curriculum with completion %** — the corpse the evidence buried. (§1)
- **Streaks, XP, leagues, or any completion mechanic on teaching content** —
  Duolingo's engagement-learning divergence + shame-sensitive audience. GIMMICK. (§5)
- **Talking-head lesson video / audio courses** — cost without engagement evidence;
  exercise-demo video is the one exception if strength content ships. (§2)
- **An MI chatbot module or "sessions"** — MI adds ~nothing over decent active
  support; keep only the voice. (§3.10)
- **Noom-style psychology quizzes / personality color typing** — marketing theater,
  no outcome evidence, off-register for Jeni. GIMMICK.
- **Mindful-eating as a weight-loss claim** — ship the craving tool, never claim
  weight effects (evidence mixed/null; honesty law + compliance floors). (§3.8)
- **Daily-weighing prompts for her cohort** — weekly-anchored trend instead; daily
  stays opt-in (affective-lability RCT in 20s women). (§3.2)
- **A generic "behavioral support" off-ramp promise** — pooled evidence shows
  generic support does NOT slow post-GLP-1 regain; if Jeni speaks to the off-ramp,
  it must be the structured-taper + monitoring-vigilance shape, with honest
  language about regain physiology. (§4 PROVEN)

*Written 2026-08-10 by research subagent R3. Sources inline; vendor data labeled.*
