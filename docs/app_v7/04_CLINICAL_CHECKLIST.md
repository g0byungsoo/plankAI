# app v7 — THE CLINICAL CHECKLIST (founder directive, 2026-07-27)

Founder: "research what weight loss/longevity clinics would need to
collect data from users, and add those features as checklist. if
it's passive and collects data, it's better." Researched against
2024-26 clinical practice (ASMBS 2025 pathway, STEP-trial
tolerability data, Prado 2024 muscle consensus, RPM vendor
protocols — Withings/Prevounce, telehealth programs — Calibrate,
longevity clinics — Function Health/Biograph) + the HealthKit
passive surface. Full sourcing inline below. This doc is the
roadmap for growing the Home checklist into the between-visit
data instrument a clinic would actually want (the quiet
white-label readiness thread from the v7 thesis).

## 1. The clinical core (obesity / GLP-1 medicine)

| # | Stream | Why (clinical) | Mode | Cadence |
|---|--------|----------------|------|---------|
| 1 | Body weight | Regular self-weighing (daily-weekly) associates with greater loss (Zheng meta-analysis 2015; Patel *Obesity* 2021); GLP-1 RPM protocols ask same-time weigh-ins (Prevounce 2024; Withings 2025) | have (manual, 5s) | weekly floor, her cadence |
| 2 | GI side effects (nausea/vomiting/constipation/diarrhea) | 74.2% of semaglutide patients had GI events vs 47.9% placebo (STEP 1); events cluster at dose escalation (Wharton, *Diab Obes Metab* 2022) — the #1 discontinuation driver clinics want caught early | 5s self-report | dose days + escalation weeks |
| 3 | Dose taken / dose level | Weekly injectable with titration; ~26% first-discontinuation by week 68 (STEP 1) — adherence is visit-one's question | 1 tap | weekly |
| 4 | Protein intake | 1.2-2.0 g/kg/d preserves lean mass during drug-induced loss (Prado, *Lancet Diab Endocrinol* 2024); ASMBS 2025 floors at 60 g/d | HAVE — derived from plate photos | daily |
| 5 | Hydration | Appetite suppression + vomiting → dehydration; ASMBS 2025 sets ≥1,800 cc/d; early-titration BP dips are dehydration-linked | 5s self-report | daily during escalation |
| 6 | Resistance training done | Strength + protein sharply cut lean-mass share of loss (Prado 2024) | HealthKit workout or 1 tap | 2-3×/wk |
| 7 | Resting heart rate | GLP-1 class effect: +1-4 bpm (UT Southwestern ABPM 2022); cheap safety trendline | PASSIVE HealthKit | daily |
| 8 | Blood pressure | Tirzepatide lowered SBP 3.6-6.1 mmHg dose-dependently (UTSW 2022); home trends beat clinic snapshots | cuff → HealthKit ingest | weekly-monthly |
| 9 | Steps / activity | Maintenance floor; standard RPM stream | HAVE (passive) | daily |
| 10 | Sleep | One of Calibrate's four program levers | HAVE (passive) | nightly |
| 11 | Waist circumference | Waist-to-height ratio outperforms BMI for cardiometabolic risk (*Lancet Reg Health Am* 2025) | tape, 10s | weekly-monthly |
| 12 | Appetite / mood check | Telehealth clinics run chat symptom check-ins; appetite return signals dose timing | HAVE (evening feeling) | weekly |

## 2. The longevity layer (iPhone/Watch-feasible)

- Cardio fitness (VO2max estimate) — passive on outdoor walks
  (Apple white paper 2021; 2025 validation study).
- HRV (nightly SDNN) + resting-HR trend — autonomic resilience
  markers (Biograph 2025). Passive.
- Body composition (fat vs lean) — Withings positions daily
  body-comp to catch GLP-1 muscle loss; smart-scale proxy for
  DEXA. Hardware, read via HealthKit.
- Walking speed / steadiness — functional-fitness proxy, passive
  iPhone gait metrics.
- Respiratory rate in sleep — passive Watch stream.
- Labs cadence — Function Health: 100+ baseline biomarkers, 60+
  retest at 3-6 months. The app's job: quarterly "labs due"
  reminder + storage only, never interpretation.

## 3. Mapping to JeniFit

**Already collected**: weight (manual), plates + macros incl.
protein (photo), steps (passive), sleep (passive), overnight-fast
window (derived), cycle phase (opt-in), evening feeling (1 tap),
sit-check for the on-medication chapter (fine/heavy/queasy — this
IS the GI side-effect check in plain words), breath sessions,
workouts.

**(a) New passive rails (zero input)**: resting HR, HRV, cardio
fitness, walking speed/steadiness, respiratory rate; plus
HealthKit INGEST of BP, body-fat %, lean mass, waist written by
any cuff/scale she already owns — completes the clinic packet
with no UI.

**(b) New 5-second checklist items**: generic "medication day"
mark (cohort-gated, no brand names); side-effect micro-check tied
to dose days (the sit-check, promoted); weekly waist tape (derive
WHtR from stored height); hydration tap during escalation weeks;
strength-session auto-credit from HealthKit workouts; quarterly
labs-due reminder.

**(c) Explicitly NOT adding**: drug brand names anywhere (Apple
5.2.1); CGM/glucose (hardware burden + diagnosis adjacency);
BP/symptom INTERPRETATION (trend display only, no alerts — no
diagnosis claims); mandatory daily weigh-ins (a 2024 RCT found
daily weighing increased negative-affect lability in young women
— weekly floor, trend-framed, her cadence); daily waist
(measurement noise + body-checking harm); manual calorie entry;
in-app lab interpretation.

## 4. Ship order (clinical value × low burden)

1. **Dose-day mark + tied side-effect micro-check** — two taps a
   week covering what GLP-1 clinics most lack between visits:
   adherence + the GI events that drive quitting.
2. **Passive vitals rail** (resting HR + HRV + cardio fitness +
   respiratory rate) — zero input, already in HealthKit; the
   GLP-1 heart-rate safety trend and the longevity layer in one
   read.
3. **Protein as first-class daily number** — SHIPPED (the foot
   ledger's protein row).
4. **Weekly waist → WHtR trend** — 10 seconds, beats BMI for
   risk, visible progress on plateau weeks when the scale stalls.
5. **HealthKit ingest of BP + body composition** from her own
   hardware — passive-if-owned, no device UX to build.

Sources: ASMBS RYGB pathway 2025 (soard.org); Wharton DOM 2022;
STEP 1 (wikijournalclub); GI epidemiology review 2025 (MDPI);
Zheng self-weighing meta-analysis (PMC4546162); Patel Obesity
2021; daily-weighing affect RCT 2024 (PMC11351998); UT
Southwestern tirzepatide ABPM 2022; Withings GLP-1 RPM; Prevounce
GLP-1 RPM protocol; Apple VO2max white paper + 2025 validation
(PMC12080799); WHtR Lancet Reg Health Am 2025; Function Health;
Biograph; Calibrate.
