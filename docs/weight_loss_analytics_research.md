# Weight-Loss Analytics — Research-backed Design

Source-of-truth for the weight-tracking + analytics surface in JeniFit.
Updated 2026-05-07.

The decisions below are grounded in peer-reviewed obesity / behavior-change
literature, with priority on the National Weight Control Registry (NWCR)
findings, ACSM position stands, and recent meta-analyses. Update this doc
before changing the metrics on `AnalyticsView`, the data model, or the
sync surface.

## 1. Metrics to surface (ranked by evidence)

| # | Metric                       | Cadence  | Predicts                                    | Note                                     |
| - | ---------------------------- | -------- | ------------------------------------------- | ---------------------------------------- |
| 1 | Weight trend (7-day EMA)     | weekly   | 12-mo loss outcome (2× sustained loss)      | NEVER spot value as headline             |
| 2 | Self-monitoring streak       | daily    | strongest single predictor (d ≈ 0.6-0.8)    | identity-framed; never punitive on miss  |
| 3 | Weekly MVPA minutes          | weekly   | maintenance specifically (ACSM 250 min/wk)  | bar against 250 target                   |
| 4 | % progress to goal           | weekly   | motivation when goal is realistic (≤10%)    | cap at 10% bodyweight; reset on milestone|
| 5 | Waist circumference          | monthly  | visceral fat / mortality independent of BMI | paired with weight, never replacing      |
| 6 | Progress photos (opt-in)     | monthly  | adherence boost during stalls               | local-only, side-by-side compare         |
| 7 | Body fat % (de-emphasized)   | —        | little — BIA scale ±4-8% error (DXA)        | hide by default; only as 30-day MA       |

**Skip entirely:** kcal burned (wearable error 27-93%), spot weight, BMI
category labels, hip/thigh/arm measurements (high friction, low marginal
signal over waist).

## 2. Presentation rules

1. **Trend > spot.** Default chart is a 7-day exponentially-weighted
   moving average. Spot weight only as a faded dot under the line.
   (Helander 2014 *JMIR*, n=40k Withings users — trend users 2× more
   likely to sustain loss.)
2. **Identity > outcome on the dashboard.** "You trained 4 days this
   week" beats "You lost 0.3 kg" for 12-mo adherence
   (Carraça 2018 *Obesity Reviews*). Reserve loss-framed copy for the
   monthly summary, not the daily home.
3. **Weekly grain for body, daily for behavior.** Pre-menopausal women
   have 0.5-1.5 kg cyclic weight variation (Bhutani 2017 *Obesity*).
   Daily weight as headline = false-signal generator.
4. **Stalls require pre-written reframes, not silence.** 91% of NWCR
   maintainers experienced ≥ 1 multi-week plateau (Thomas 2014).
   When 14-day trend is flat or up < 0.5 kg, surface a copy variant
   like "Plateau weeks predict maintainers — your body is adjusting."
   Unaddressed plateaus drive 30%+ of dropouts in the first 90 days
   (Linde 2004).
5. **ED-safe defaults for women.** Per AED 2021 clinical guidance:
   hide BF%, hide kcal-burned, hide BMI category labels by default;
   never show daily weight delta as the primary number; never use
   red/loss-color for weight up. Provide a one-tap **hide-weight mode**
   (Linardon 2021 *Int J Eat Disord*: opt-out reduced ED-symptom
   escalation in app users by ~22%).
6. **Cadence:** daily nudge for behavior, weekly for body, monthly for
   measurements/photos. Daily body-metric feedback shows no benefit and
   raises anxiety scores (Patel 2015 *Annals of Internal Medicine*).

## 3. Behavior-change priorities (ranked by 12-mo effect size)

1. Self-monitoring frequency, any modality (Burke 2011 meta, d ≈ 0.6-0.8)
2. MVPA ≥ 200 min/week (NWCR maintainers ≈ 60 min/day, 2,600 kcal/wk)
3. Process / identity goals over outcome goals
   (process-goal cohort 68% retention vs outcome-goal 41% at 12 mo)
4. Consistent eating pattern + weekday/weekend consistency
5. **"Do-something" minimum-viable-session habit** — a 2-min session
   beats skipping; preserves chain (Wood & Neal 2007, Kwasnicka 2016).
   Aligns with our 5-min "streak day" length tier.
6. Social accountability (out of scope for solo-app v1)
7. High-frequency low-stakes feedback loop

## 4. Data model — what to add and why

### Add now (Phase 7a)

| Field / table                                      | Justification                                                |
| -------------------------------------------------- | ------------------------------------------------------------ |
| `weight_logs (id, user_id, weight_kg, logged_at, source)` | Without history, no trend chart — the load-bearing UI. Append-only. |

`source` is one of `onboarding | manual | healthkit | apple_health` — lets
us audit the input quality later.

The user's **starting weight** and **starting weight date** are already
captured as `users.onboarding_current_weight_kg` and `users.start_date`.
Reuse those, don't duplicate the columns.

### Add next (Phase 7b/7c)

- `waist_logs (user_id, waist_cm, logged_at)` — monthly only.
- `progress_photos (user_id, asset_id_local, captured_at)` — local-only
  reference; opt-in; never uploaded by default for privacy.
- HealthKit pull for weight (post-first-session prompt, not at signup —
  Apple WWDC 2022 sample shows ~30% prompt-fatigue drop-off when asked
  too early).
- `daily_checkins (mood_1_5, energy_1_5)` — small effect (d ≈ 0.2);
  cheap to add but defer if it adds friction.

### Skip permanently

- Body fat % field — BIA scale error (±4-8%) swamps real change.
- kcal burned as a stored analytic — wearable error ranges 27-93%
  (Shcherbina 2017 Stanford). Display only, don't persist.
- BMI as a stored field — derive on demand; never display category
  labels per ED-safe guidance.

## Sources

- Steinberg 2015 — daily self-weighing: <https://pubmed.ncbi.nlm.nih.gov/25683820/>
- Pacanowski & Levitsky 2015 — daily weighing: <https://www.hindawi.com/journals/jobe/2015/763680/>
- Burke 2011 — self-monitoring meta: <https://pubmed.ncbi.nlm.nih.gov/21185970/>
- Harvey 2019 — logging frequency: <https://onlinelibrary.wiley.com/doi/10.1002/oby.22382>
- Cerhan 2014 — waist & mortality: <https://www.mayoclinicproceedings.org/article/S0025-6196(13)01000-X/fulltext>
- ACSM 2019 — physical activity & weight: <https://journals.lww.com/acsm-msse/Fulltext/2009/02000/Appropriate_Physical_Activity_Intervention.26.aspx>
- Catenacci 2014 / Thomas 2014 — NWCR maintenance: <https://pubmed.ncbi.nlm.nih.gov/24355667/>
- Wing & Phelan 2005 — long-term maintenance: <https://academic.oup.com/ajcn/article/82/1/222S/4863393>
- Helander 2014 — trend-line weighing: <https://www.jmir.org/2014/4/e109/>
- Bhutani 2017 — weekly weight variation: <https://onlinelibrary.wiley.com/doi/10.1002/oby.21884>
- Linde 2004 — plateaus & dropout: <https://pubmed.ncbi.nlm.nih.gov/15292749/>
- Carraça 2018 — autonomous motivation in women: <https://onlinelibrary.wiley.com/doi/10.1111/obr.12676>
- Linardon 2021 — app use & ED symptoms: <https://onlinelibrary.wiley.com/doi/10.1002/eat.23398>
- Patel 2015 — feedback frequency: <https://www.acpjournals.org/doi/10.7326/M15-1635>
- Shcherbina 2017 — Stanford wearable accuracy: <https://www.mdpi.com/2075-4426/7/2/3>
- Wang 2015 — BIA validation: <https://pubmed.ncbi.nlm.nih.gov/25733208/>
- Kwasnicka 2016 — habit theory: <https://www.tandfonline.com/doi/full/10.1080/17437199.2016.1151372>
- AED 2021 — clinical guidance on weight-tracking apps: <https://www.aedweb.org/>
