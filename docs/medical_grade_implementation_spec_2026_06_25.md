# JeniFit — Medical-Grade Implementation Spec (additive, no-infra)

**Date:** 2026-06-25
**Source:** 3-MD audit synthesis (obesity medicine / GLP-1 endocrinology / OB-GYN) → see `[[project-medical-grade-roadmap]]`.
**Scope:** every clinically additive feature we can ship **without** changing data infrastructure or disrupting current customers.

### In scope
Additive clinical features, screens, program-engine logic, new AppStorage/UserRecord fields, education content, analytics instrumentation.

### Out of scope (deferred per founder — parallel non-engineering tracks)
HIPAA/BAA, FHIR/EHR interoperability, data-infra migration · clinical governance org (Medical Director, advisory board) · RWE/IRB study · FDA SaMD legal opinion. These are *required before any external "medical-grade" claim or partnership* but are not app builds; flagged at the end.

---

## 0. Guiding principles (apply to every feature)

1. **Additive + backward-compatible.** New `@AppStorage` keys and new *optional* `UserRecord` columns only; default-safe; old columns untouched. No destructive migration. (Matches the established `onb_v4_*`-new-keys pattern.)
2. **Never disrupt an existing customer.** New users get the gated flow at onboarding. Existing users (already enrolled) get a **one-time, non-blocking** safety check-in; on a positive flag we *soften* their experience (offer maintenance, surface resources), we never retroactively yank a program. Floors only ever *raise* (strictly safer).
3. **Stay wellness-side of the SaMD line.** Everything here is *educate / track / behavioral*. Never diagnose, treat, recommend or adjust a dose, or interpret labs. Screens are framed "for your safety," not as a diagnosis. Symptom logs route to "talk to your prescriber," never "you're fine." Titration content is patient education, never a dose recommendation.
4. **On-brand.** lowercase, anti-shame, hearts as terminal punctuation only, no em-dash, no "AI" word, no drug brand names, no first-party numeric weight-loss claims. A kind safety screen is the most caring thing a weight app can show a 24-year-old.
5. **Feature-flag every phase** (existing AppStorage flag pattern) so rollout is staged and reversible.

---

## Phase 1 — Safety floor (ships first; the unanimous #1)

### 1.1 Safety Screen module

**What.** A short, kind screening sequence that runs before the goal-weight picker and *gates program generation*. New users: inserted as onboarding cases after biometrics + cohort, before the goal-weight question. Existing users: a one-time `SafetyCheckIn` card (§1.4).

**New data (all default-safe):**
| key | type | default | meaning |
|---|---|---|---|
| `safety_age_ok` | Bool | derived | from existing `onboardingAgeRange`; `under18` → not ok |
| `safety_scoff_score` | Int | -1 | 0–5; -1 = not taken |
| `safety_scoff_positive` | Bool | false | score ≥ 2 |
| `safety_pregnancy_status` | String | "" | none/pregnant/ttc/breastfeeding/prefer_not_say |
| `safety_dm_meds` | String | "" | none/metformin_only/insulin_or_su/other |
| `safety_recent_surgery` | Bool | false | bariatric/abdominal in last 3mo |
| `safety_consent_version` | String | "" | accepted consent version id |
| `safety_screen_date` | String | "" | yyyy-MM-dd of last screen (re-screen at 90d) |
| `program_mode` | String | "loss" | loss / maintenance / recovery (the gate's output) |

Store the *result*, not raw ED answers (privacy-light). All under the existing UserDefaults/AppStorage layer — no schema change.

**Components + logic (the gate produces `program_mode`):**

- **Age gate (≥18).** `onboardingAgeRange == "under18"` → block the loss program → supportive exit ("jenifit is built for 18+; here's how to find care that fits you"). `program_mode = blocked`.

- **BMI floor.** Use collected `UserRecord.heightCm` (already captured; make the height step explicit/confirmed so the 170 default can't slip through) + current weight. Enforce **inside `ProgramGoalCalculator`** (wire the dead `bmiClass` + the "target BMI too low" comment into a real gate):
  - current BMI < 18.5 → **no loss program**; `program_mode = maintenance` (nourish framing).
  - goal BMI < 18.5 → reject the goal, clamp the picker's lower bound to BMI 18.5.
  - current BMI 18.5–24.9 → soften to "maintenance / recomposition" framing + explicit confirm; the "hard" 1%/wk tier is hidden.
  - current BMI ≥ 25 → full loss program; reserve "hard" tier for ≥ 27.

- **SCOFF eating-disorder screen** (5 yes/no items, validated, ≥2 = positive):
  1. Do you make yourself **S**ick because you feel uncomfortably full?
  2. Do you worry you have lost **C**ontrol over how much you eat?
  3. Have you recently lost more than **O**ne stone (~6 kg) in 3 months?
  4. Do you believe yourself to be **F**at when others say you're thin?
  5. Would you say **F**ood dominates your life?

  Positive (≥2) → `program_mode = recovery`: suppress the goal-weight picker + all calorie/deficit surfaces + the loss program; route to a **non-numeric "gentle / nourish" path**; surface crisis resources (NEDA 1-800-931-2237, **988**, Crisis Text "NEDA" to 741741). Copy is care, not alarm: "we want to make sure this is good for you. some of what you shared tells us a gentler path is kinder right now ♥".

- **Pregnancy / lactation / TTC screen** (`safety_pregnancy_status`):
  - `pregnant` → **hard-disable** the deficit program; `program_mode = maintenance` (gestational-appropriate nourishment, no goal weight, no calorie deficit). "weight loss isn't the goal during pregnancy. we'll keep things steady and supportive."
  - `breastfeeding` → suppress aggressive deficit; raise intake floor +450–500 kcal (§1.3); gentlest pace.
  - `ttc` → soft note + slowest glide.

- **Contraindication screen** (education + caution, never a clearance):
  - `safety_dm_meds == insulin_or_su` → caution card "a calorie change while on this medication should be paced with your clinician" + avoid the aggressive deficit; do not block, but cap the rate.
  - `safety_recent_surgery` → caution + "your care team should pace this."
  - MTC/MEN2/pancreatitis history → one-line *education* only ("these are things your prescriber screens for"), never an in-app clearance.

- **Informed consent.** One screen: "this is an educational program to support healthy habits. it is not medical care and does not replace your clinician. if anything feels off, please reach out to a professional." Explicit acknowledge → store `safety_consent_version`.

**Integration points.** `ProgramGoalCalculator.compute` reads `program_mode` and returns maintenance/blocked windows for non-loss modes; `ProgramSetupSubflow` (goalDateReveal) renders the mode-appropriate path; the onboarding goal-weight case is skipped/clamped per mode. New onboarding cases follow the existing case-based pattern.

**Compliance.** Screens are "for your safety," not diagnostic. The recovery path makes *no* assessment beyond "a gentler path fits" + signposting to real help.

### 1.2 Energy-availability intake floor fix

**What.** `EnergyLedger.swift:91` rewards a "lighter day" down to `max(1200, BMR − (GLP1 ? 500 : 750))`. 1200 kcal is below the safe floor for active or lactating women, and the mark *rewards* it.

**Fix.** Replace the flat 1200 with a per-user **energy-availability floor**: estimate fat-free mass (Boer LBM formula from height/weight/sex — no DXA needed) and floor intake at **≥ 30 kcal/kg FFM**; never award `isLighterDay` below it. Breastfeeding → +450–500. RED-S flag (amenorrhea, §4) → higher floor. Also raise the program's *target-intake* floor (§2.1) to the same minimum.

**Backward-compat.** Pure floor raise → strictly safer for everyone, no disruption.

### 1.3 Honesty + escape hatches (Tier 0, days)

- **Copy walk-back.** Audit onboarding (esp. case ~164) and any surface that promises *unshipped* clinical features ("protein floor", "we adjust for GLP-1", "satiety-aware portions"). Rewrite to only-what-ships; re-enable each line as Phase 2/3 ships it. (FTC substantiation.)
- **Red-flag escape hatch** (reusable component). Surfaced wherever symptoms/distress can appear: severe/persistent abdominal pain · persistent vomiting or dehydration · ED relapse · thoughts of self-harm → "this isn't something to handle in an app. please contact your prescriber or seek care" + **988** + NEDA. Wire into every symptom log (§3.2) and the JeniMethod safety line.

### 1.4 Existing-customer rollout (non-blocking)

A one-time `SafetyCheckIn` card on next app open for users who already have a program: runs SCOFF + pregnancy + a BMI recheck. On a positive flag → **soften, don't lock**: offer the maintenance/recovery path, surface resources, hide aggressive calorie surfaces; the user can decline and continue (we log that we offered). Stored `safety_screen_date` so it shows once / re-offers at 90 days.

---

## Phase 2 — Adaptive clinical engine + muscle preservation

### 2.1 Use the data we already collect (TDEE)

`ProgramGoalCalculator` ignores `age`, activity, and height; sex is hardcoded. Wire **Mifflin-St Jeor** (height already available) × an **activity factor** from `onboardingActivityLevel` → an estimated TDEE → derive intake targets, the kcal floor (§1.2), and a sanity-cap on the picked rate (if "hard" implies sub-floor intake for this body size, silently cap the rate). Keep female default but make `sex` a real field. *No new data needed — this is wiring collected-but-dead inputs.*

### 2.2 Static → adaptive pacing

New `AdaptivePacingEngine` (additive; `ProgramGoalCalculator` stays as the enrollment **baseline / plan of record**). See the engine sketch in the prior session for the full design. Summary:
- Read the existing weight-log **EMA**; compute trend weight + velocity (Kalman upgrade later).
- Reproject goal date as a **range**, weekly / on each weigh-in; classify status (ahead / on-pace / easing-off / stalled), framed anti-shame.
- Store a new rolling `PacingState` — **do not** overwrite the stored `totalDays` (existing programs keep working; the live projection is a *new surface* on Becoming).
- **Rate-of-loss safety monitor:** trailing loss > ~1%/wk sustained **or** chronically low protein → *slow the target* + muscle-protection card. **Plateau** → diet-break/maintenance reframe, never a deficit crank.

**Backward-compat.** Existing users keep their baseline; the adaptive card is purely additive and reversible via flag.

### 2.3 Protein-as-hero + resistance Rx + lean-mass proxy (the flagship, data already exists)

- **Protein floor as the hero macro.** Target **1.2–1.6 g/kg of goal weight**; Snap Food already extracts protein — elevate it from a buried macro to the primary number with a daily-floor gauge. Mandatory hero for GLP-1 cohorts.
- **Resistance prescription.** A real 2–3×/wk progressive program (bands/bodyweight, progressive), distinct from plank/core. New program-engine content.
- **Lean-mass proxy.** Import HealthKit `leanBodyMass` when a smart scale writes it; otherwise a monthly waist-circumference manual entry + trend. New optional fields; purely additive.
- **Coupling to the engine (§2.2):** low trailing protein + active loss → engine slows target + escalates protein/resistance coaching. This is the sarcopenia guardrail and the strongest pharma hook.

---

## Phase 3 — GLP-1 clinical companion

### 3.1 Titration / dose capture + phase-aware expectations
New user-entered fields (compliant — user content, not app recommendation): `glp1_class {glp1 | dual_agonist | none | prefer_not_say}`, `glp1_dose_step`, `glp1_titration_start`. Map onto a published titration timeline; show **phase-aware education** (early = GI symptoms + modest loss, "the adjustment phase"; maintenance dose = peak loss + muscle focus). Never recommend a step ("your prescriber sets your dose").

### 3.2 GI-symptom-aware guidance
Lightweight symptom check (nausea / constipation / reflux / fatigue, 0–3). Drive *education-grade* nutrition tips: nausea → small, bland, protein-forward, ginger; constipation → fiber + hydration + magnesium awareness; reflux → smaller boluses, upright after eating. Every symptom log carries the §1.3 red-flag escape hatch and routes to "contact your prescriber," never reassurance.

### 3.3 Hydration / fiber / micronutrient nudges
Titration-window hydration + fiber targets; micronutrient awareness (protein, B12, iron, calcium/D) framed as "fueling well on less appetite," not deficiency management.

### 3.4 Post-GLP-1 maintenance / regain-prevention mode (HIGH strategic value)
**Fix the backward default:** `.postGlp1` currently resets to a 0.5%/wk *loss* program (`ProgramGoalCalculator` comment "past → default rate"). Change to:
- **maintenance band**, not loss (defend the weight + the muscle that survived: protein floor + resistance become *the* program);
- **early-regain detection** on the EMA (sustained upward inflection → gentle "the rhythm that keeps it" intervention, appetite-return-aware);
- a cohort-tagged **"keep-it-off" CBT sequence** (JeniMethod is perfect for this) + a weekly appetite / food-noise-return rating.
This is the underserved 4–8M-woman wedge and the consumer moat.

---

## Phase 4 — Women's-health substance

### 4.1 PCOS (wire the dead `onb_pcos` field; strongest women's differentiator)
Capture in onboarding (currently read for lesson-bias only): `pcos_status {diagnosed | suspected | no}`, `insulin_resistance_flag`, `pcos_meds`, `ttc_flag`. Logic: IR-aware framing (protein/fiber, glucose-stability lessons), realistic slower-loss reframing, the clinically meaningful **5–10% threshold** messaging, Rotterdam-criteria language for credibility, fertility/metformin/GLP-1 context.

### 4.2 Menstrual-cycle-phase awareness
`cycle_opt_in`, `last_period_start`, `avg_cycle_length`, or HealthKit `menstrualFlow` import. Compute follicular vs luteal; **reframe luteal water-weight + appetite as expected physiology** on the trend ("this is luteal, not lost progress"). Wires the existing hollow "cycle-aware" copy to a real model. (Comparators: Wild.AI, FitrWoman, Flo.)

### 4.3 Peri / menopause substance
`menopause_stage`, `hrt_status`. Protein + bone + HRT-aware framing; **fix the "postmenopause = default rate" under-service** — postmenopausal women need the protective (muscle/bone) framing even at a normal pace.

### 4.4 Thyroid / iron
`thyroid_condition {hypo | hyper | none}`, `on_thyroid_med`, iron/anemia symptom flags. Hypothyroid → reframe slower loss as expected (prevents over-restriction). Anemia flags → energy/fatigue education + "see your clinician," never "push harder."

### 4.5 Bone-health protection
Bake protein + resistance + calcium/Vit-D education into every women's loss program, scaled by age/menopause stage + RED-S risk.

---

## Phase 5 — Outcome measurement (cheap, no-infra; do early)

- Instrument **% total body weight loss at 12 / 26 / 52 weeks** and **% achieving ≥ 5% TBWL** (PostHog events only — no schema change). This is the substrate for the future evidence study and the partnership data story; it's nearly free and should ship early to start the flywheel.
- **PHQ-9** depression screen (additive; ≥10 → supportive routing; item-9 suicidality → crisis resources).
- An **appetite / food-noise PRO** rating scale (also feeds §3.4).

---

## Suggested build order (fastest defensible path)

1. **Phase 1** (Safety Screen new-users + floor fix + escape hatches) — table-stakes; unblocks everything; weeks.
2. **Phase 5** instrumentation in parallel — nearly free, starts the evidence flywheel.
3. **Phase 2.3 + 2.1** (protein-hero + TDEE wiring) — high value, data already exists.
4. **Phase 2.2** (adaptive engine + rate monitor).
5. **Phase 3.4 + 3.1** (post-GLP-1 maintenance fix + titration).
6. **Phase 4.1 + 4.2** (PCOS + cycle).
7. Remaining Phase 3/4 substance.

## Backward-compatibility checklist (every PR)
- [ ] New keys/fields default-safe; existing users unaffected on upgrade.
- [ ] No existing program retroactively invalidated; floors only raise.
- [ ] Behind a feature flag; reversible.
- [ ] Wellness-side of SaMD; no diagnose/treat/dose; no brand names / numeric claims / "AI".
- [ ] Screens framed "for your safety"; symptom logs route to a clinician.

## Deferred (parallel non-engineering tracks — required before any external "medical-grade" claim or partnership)
HIPAA/BAA + FHIR/EHR + data-infra · Medical Director + advisory board + clinical content review · RWE/IRB cohort study · FDA SaMD intended-use opinion. None block the builds above; all block the *claim*.
