# Workout Engine — Research-backed Design

Source-of-truth for the design decisions inside `WorkoutGenerator` and the
preset library. Updated 2026-05-06.

The decisions below are grounded in peer-reviewed exercise-physiology and
behavior-change literature; revise this file before changing any of the
constants in `WorkoutGenerator.swift`, `BodyFocus.swift`, or
`SessionStructure.swift`.

## 1. Body focus → muscle group mapping

| bodyFocus  | Primary areas                        | Secondary areas                              |
| ---------- | ------------------------------------ | -------------------------------------------- |
| flatBelly  | abs, obliques                        | lowerBack, glutes, hipFlexors                |
| tonedArms  | upperBody                            | abs, lowerBack                               |
| roundButt  | glutes                               | hamstrings, lowerBack, quads                 |
| slimLegs   | quads, hamstrings, calves            | glutes, abs                                  |
| fullBody   | fullBody, glutes, upperBody, abs     | lowerBack, hamstrings                        |

Generator selection: 70% of main slots from primary, 30% from secondary —
keeps the user feeling targeted while distributing volume for symmetry.

**Why each row:**

- **flatBelly** isn't only abs. Visible flatness is a function of (a) low
  subcutaneous fat over the abdomen and (b) tone + erect posture. Anterior
  pelvic tilt pushes the belly forward, so we balance abs work with glute and
  lowerBack work that pulls the pelvis to neutral.
- **tonedArms** = hypertrophy of biceps/triceps/deltoids; core stabilizes the
  pressing patterns.
- **roundButt** primary glute max — hip thrust EMG hierarchy (Contreras 2015).
  Hamstrings co-contribute on hinge patterns.
- **slimLegs** = lower-body work + glute medius for the upper-thigh-to-hip
  shelf. Abs included for postural alignment that elongates the leg line.
- **fullBody** prioritizes compound movements (high MET, large EPOC) plus
  glutes/upperBody/abs to ensure every major chain is hit.

**Spot reduction is a myth.** Localized abdominal training does not reduce
abdominal subcutaneous fat preferentially over a control group (Vispute 2011;
Ramirez-Campillo 2013). The honest user-facing framing is: train the muscle
for tone; fat loss happens body-wide via expenditure + diet (ACSM 2009/2019
position).

## 2. Session length grid

The minimum effective bout that produces a fitness/body-comp adaptation
signal is **7 minutes**, done at least 5x/week. Below that, the session is
useful as a streak/habit anchor but is sub-threshold for actual training
adaptations.

| Length | Audience                  | Delivers                                  |
| ------ | ------------------------- | ----------------------------------------- |
| 5 min  | streak day, deload, travel| ~25 min/wk if daily — sub-threshold alone |
| 7 min  | beginner, time-poor       | minimum effective dose at 5x/wk = 35 min  |
| 10 min | core daily user           | 50 min/wk                                  |
| 15 min | intermediate              | hits WHO 75 min vigorous in 5 sessions    |
| 30 min | committed                 | hits WHO 150 min moderate in 5 sessions   |
| 45 min | advanced / long-day       | dose-response ceiling near 250-300 min/wk |

**Sources:** Jakicic 1995 (multiple short bouts ≥ single long bouts for
adherence + outcomes in overweight women); WHO 2020 PA Guidelines
(removed the prior ≥10-min bout minimum); Wewege 2017 + Viana 2019 BJSM
(short HIIT meets or beats long MICT for fat loss); Murphy 2019 BJSM
(body-comp dose-response plateau ~300 min/wk).

## 3. Session structure: warmup / main / cooldown

**Warmup is dynamic only.** Static stretching >60s pre-workout reduces
force output ~5% and provides no injury-prevention benefit (Behm 2016
systematic review, Fradkin 2010 meta-analysis).

**Cooldown is static stretching**, 30s hold per muscle (Page 2012 IJSPT —
30s optimal for ROM in healthy populations; 45-60s only for older/stiffer).

Warmup time = ~15% of total session, floor 60s, cap 4min.

| Session | Warmup time | Warmup moves (~30s ea) | Cooldown time | Cooldown stretches (~30s ea) |
| ------- | ----------- | ---------------------- | ------------- | ---------------------------- |
| 5 min   | 60s         | 2                      | 30s           | 1                            |
| 7 min   | 60s         | 2                      | 45s           | 1-2                          |
| 10 min  | 90s         | 3                      | 60s           | 2                            |
| 15 min  | 120s        | 4                      | 90s           | 3                            |
| 30 min  | 210s        | 6                      | 180s          | 6                            |
| 45 min  | 240s        | 6                      | 240s          | 8                            |

Warmup pulls from the bank where `type == .mobility` AND difficulty ≤ 2.
Cooldown pulls from the bank where `type == .mobility` AND `pace == .hold`
(static-style stretches: childs pose, quad stretch, hamstring stretch, etc).

Main work pulls from focus-areas (per Section 1) and applies the constraint
solver: no consecutive same primary area, alternate hold ↔ rep, intensity
curve peaks at 30-50% of session, recent-session penalty for variety.

## 4. Rest intervals between exercises (and the prep phase)

Work:rest ratios for bodyweight circuit training, from the HIIT-prescription
literature (Buchheit & Laursen 2013; Tabata 1996; Edwards 2014; Foster 2015):

- **Tabata** — 20s work / 10s rest = 2:1 work:rest, max VO2 in 4 min
- **Billat 30:30** — 30s / 30s = 1:1, beginner-friendly endurance
- **Bodyweight HIIT** — 30s / 15s for fitter users, 30s / 30s for beginners
- General HPRC guidance: as fitness improves, progress from 1:3 → 1:1 → 3:1

In an at-home bodyweight context with mostly tier 1-2 users, the
recommended grid for **30s active work** is:

| Tier   | Reps (rest sec) | Holds (rest sec) | Work:rest ratio |
| ------ | --------------- | ---------------- | --------------- |
| 1 (beg)  | 18              | 15               | ~1:0.6          |
| 2 (int)  | 12              | 10               | ~1:0.4          |
| 3 (adv)  | 9               | 7                | ~1:0.3          |

Holds get shorter rest because isometric work produces less muscle damage
and faster recovery (no eccentric load). Warmup and cooldown transitions
use a fixed minimum 3s — just enough to read the next move's name.

**Combined prep phase.** The session player runs a single `prep` phase
between exercises that doubles as rest **and** preview. The upcoming
exercise's Lottie + name are visible during prep. This is a UX choice
(research doesn't constrain what happens during rest, only the ratio) and
it eliminates 4s of redundant "preview" countdown after every rest. The
first slot of every session gets a fixed 4s prep ("get ready" countdown).

Sources for this section:
- Buchheit & Laursen 2013, Sports Medicine: <https://pubmed.ncbi.nlm.nih.gov/23539308/>
- Tabata et al. 1996, MSSE: <https://pubmed.ncbi.nlm.nih.gov/8897392/>
- HPRC, work:rest progression: <https://www.hprc-online.org/physical-fitness/training-performance/optimize-your-workouts-proper-workrest-ratios>

## 5. Engine UX surface

Keep `bodyFocus` as the **primary** user input (multi-select). Demote
`WorkoutGoal` to internal preset categorization — no UI surface.

**Sources:** Self-determination theory predicts perceived autonomy is the
single strongest correlate of long-term exercise adherence
(Teixeira 2012 IJBNPA meta-review). Personalized fitness apps drive
significantly higher 60-day retention than generic programs
(Romeo 2019 JMIR). Choice overload research (Iyengar 2000, Scheibehenne
2010 meta) finds 6+ visible options reduce decision-completion; sweet
spot is 3-5.

Practical rule: never show the user the full goal × focus × length × tier
matrix. Onboarding picks bodyFocus + length; difficulty is inferred.

## Sources

- ACSM 2009/2019 position on weight loss: <https://journals.lww.com/acsm-msse/Fulltext/2009/02000/Appropriate_Physical_Activity_Intervention.26.aspx>
- Vispute 2011 — abdominal exercise on fat: <https://pubmed.ncbi.nlm.nih.gov/21804427/>
- Ramirez-Campillo 2013 — localized fat loss: <https://pubmed.ncbi.nlm.nih.gov/23222084/>
- Contreras 2015 — hip thrust EMG: <https://pubmed.ncbi.nlm.nih.gov/25627548/>
- WHO 2020 Physical Activity Guidelines: <https://www.who.int/publications/i/item/9789240015128>
- Jakicic 1995 — short vs long bouts: <https://pubmed.ncbi.nlm.nih.gov/7657964/>
- Murphy 2019 BJSM — dose-response: <https://bjsm.bmj.com/content/53/16/1043>
- Wewege 2017 — HIIT vs MICT meta: <https://pubmed.ncbi.nlm.nih.gov/28401638/>
- Viana 2019 BJSM — HIIT body comp: <https://bjsm.bmj.com/content/53/10/655>
- Behm 2016 — acute stretching effects: <https://pubmed.ncbi.nlm.nih.gov/26642915/>
- Fradkin 2010 — warmup performance meta: <https://pubmed.ncbi.nlm.nih.gov/19996770/>
- Page 2012 IJSPT — stretching: <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3273886/>
- Van Hooren & Peake 2018 — cooldown review: <https://pubmed.ncbi.nlm.nih.gov/29663142/>
- Teixeira 2012 — exercise + self-determination: <https://ijbnpa.biomedcentral.com/articles/10.1186/1479-5868-9-78>
- Romeo 2019 — fitness app personalization: <https://www.jmir.org/2019/3/e12053>
- McEwan 2016 — goal-setting meta: <https://pubmed.ncbi.nlm.nih.gov/26644172/>
- Scheibehenne 2010 — choice overload meta: <https://academic.oup.com/jcr/article-abstract/37/3/409/1796105>
