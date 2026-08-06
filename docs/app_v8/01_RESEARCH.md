# app v8 — RESEARCH SYNTHESIS (2026-07-28, citations inline)

Four lanes, run as independent web-research agents on 2026-07-28,
synthesized here with judgment. Claims carry source + year;
[live] = verified this session, [mem] = pre-cutoff memory.
Companion: `02_COMPETITORS.md` (teardowns). Implication threads
resolve in `03_ARCHITECTURE.md` + `04_DECISIONS.md`.

---

## A. How clinics actually work (and what that demands of us)

### A1. Operations
- Obesity/GLP-1 practice cadence: weekly-biweekly first month →
  q2-4wk through active loss → monthly in maintenance; lifestyle
  counseling delegated to NP/RD; the REAL calendar is the
  titration calendar (dose steps q4wk to max tolerated), with
  side-effect triage happening asynchronously between steps (GWU
  STOP guide 2022; OMA Obesity Algorithm 2026) [live].
- Intake per OMA 2026: weight history, neuropsych/social factors,
  secondary causes, complications, anthropometrics beyond BMI
  (waist, WHtR), nutrition/activity/sleep assessment [live].
- Panels: primary care 2-3k patients; concierge 300-600 (MDVIP
  caps ~600, $2.4-5k/yr) [live].
- **Staff time sinks, quantified:** weight-loss GLP-1 prior auths
  take 13.5 min tech time each at a 48% approval rate (vs 6.4
  min / 90% for diabetes GLP-1s) and consume ~¼ of pharmacy PA
  resources (UC Davis, JMCP 2026) [live]. Portal messages rose
  0.99 → 2.5 per patient-year 2020-25 (+150%) while visits rose
  17% — messaging adds work, GLP-1 practices skew high (JAMA via
  Healthcare Dive 2026; MGMA 2024) [live]. Obesity-program
  attrition 10-80% by setting; 68.5% dropout at 12mo in one
  multidisciplinary program (Eat Weight Disord 2020; PMC 2022)
  [live] — retention tooling is WHY engagement software is bought.
- Longevity "protocol" concretely = lab panel (100+ biomarkers,
  1-2x/yr; Function $365/yr, Superpower $199/yr) → scored
  interpretation → supplement/rx + lifestyle stack with due dates
  → retest trigger → async care team ≤1 business day; the named
  market weakness is follow-through BETWEEN retests (Function/
  Superpower/Biograph primary pages 2026; Will Ventures 2025)
  [live] — which is exactly a daily-companion's job.

### A2. The software market clinics buy
- SMB metabolic/wellness practices buy all-in-ones (Healthie /
  Practice Better class): intake forms + scheduling + telehealth
  + superbills + food journal + branded patient app [live].
- Churn drivers: 77-80% switch over functionality gaps, 44%
  unresponsive vendors; patients complaining about the app is a
  named switch trigger; migration pain is the incumbent's only
  moat (Black Book/Tebra 2024-25; G2/Capterra Healthie reviews
  2024-26) [live].

### A3. Clinician trust
- Stated bar: RCTs. Behavioral bar: ease + experience + patient
  fit + a credible evidence artifact + clean privacy story (JMIR
  2021-22) [live].
- **Alert fatigue is a first-order constraint** with its own
  2025-26 literature; the trusted contract is ranked deduplicated
  EXCEPTIONS with context and a per-clinic alert budget — never
  raw streams (JMIR 2025 alert-reduction framework) [live].
- Clinicians (and CMS) discount patient-keyed numbers;
  device-transmitted passive data is the credibility floor;
  self-report is legitimate exactly where devices can't see:
  symptoms, adherence, mood (= RTM's domain) [live]. Passive
  wins operationally: 93% scale retention at 12mo (Withings
  2025, named-clinic data) [live].
- **FDA moved in our favor on 2026-01-06**: updated General
  Wellness + CDS guidances — non-device CDS explicitly
  contemplates AI drafting a single recommendation for
  practitioner review (transparency expectations: inputs, logic,
  automation-bias mitigation) (Faegre Drinker / Arnold & Porter
  Jan 2026) [live]. The lanes: consumer = general wellness
  (observed-never-prescribed already codifies it); clinic = AI
  drafts, clinician signs. Never auto-adjust medication.

### A4. Patient trust
- ~90% want human oversight of medical AI; embedded-in-provider
  AI earns ~3x the trust of a public chatbot; visible
  escalate-to-human paths demanded (Salesforce/U-Mich 2025-26)
  [live]. Supervision must be a visible UI state when true —
  never faked.
- Consumer apps are FTC-land: GoodRx ($1.5M, first HBNR action)
  + BetterHelp ($7.8M) for sharing health data with ad platforms
  [live]. First clinic contract makes us a HIPAA business
  associate overnight [mem, settled].
- **GLP-1 status is psych-grade sensitive**: 69% of users
  unlikely to admit taking one (US survey Jun 2026); ~2 in 3
  hide treatment from friends/family (UK n>3k) [live].
  Medication data: segregated, out of notification payloads and
  share surfaces by default, never touched by analytics SDKs.

### A5. The billing machine (shapes the schema directly)
- CY2026 PFS rewrite (eff. 2026-01-01): new CPT 99445 (RPM
  device supply, 2-15 data-days/30) + 99470 (first 10-19 min
  management); RTM mirrors 98984-86/98979. The 16-day rule is no
  longer a hard floor, but **days-of-transmitted-data per
  30-day window remains the billing atom** (Nixon Law / Noridian
  MAC 2026) [live].
- Stable core: 99453 setup · 99454 16+ days · 99457/99458
  management minutes w/ interactive communication. **RPM
  requires device-transmitted physiologic data — patient-keyed
  values do NOT qualify**; RTM covers self-reported adherence/
  symptoms; CCM stacks (obesity + hypertension qualifies) [live].
- A clinic must produce per patient-month: qualifying data-day
  counts, a minutes ledger by staff member, interactive-comm
  timestamps, consent records, device provenance. **That audit
  bundle IS the clinic product surface.**
- DPP/MDPP template: 16 weekly + monthly maintenance sessions,
  fidelity-tracked attendance, ~$26/session + $149 bonus at 5%
  weight loss (CMS CY2025-26) [live] — payers pay for a LEDGER
  (attendance + verified weight), not an app.

### A6. DTx lessons (who died, who survived, why)
- **Pear** (bankrupt 2023): FDA authorization + 40 studies, died
  on reimbursement — no payment rails for "prescription app"
  (Stanford GSB case 2024) [live]. → Never bet on the app itself
  being reimbursed; ride RPM/RTM/CCM + SaaS workflow value +
  retention economics.
- **Omada** (IPO 2025, $260M rev +53%, profitable Q4'25):
  employer/payer channel, engagement-gated PMPM + outcome
  components; GLP-1 companion track then AOM prescribing;
  "84% maintained loss after discontinuation" is its published
  flag [live]. → GLP-1 *companionship* (before/during/after) is
  the durable framing.
- **Virta**: outcomes contracts as moat (fees at risk vs
  metrics; 2025 guarantee: 0% YoY GLP-1 utilization growth)
  [live]. → Guarantee a metric the CFO already tracks.
- **Noom Med**: $100M run-rate in 4 months bolting Rx onto a
  consumer brand; now compounding-risk-exposed, price-laddering
  ($99 pill tier) [live]. → Prescription = acquisition hook;
  behavioral layer = the retention asset.

### A7. Implications adopted into architecture (→ 03/04)
1. Reading provenance becomes a schema primitive: source class +
   transmission type (device / HealthKit-relay / patient-keyed) +
   data-day rollup computability.
2. MedicationPlan models the titration calendar (dose step,
   step date, side-effect events, refill horizon), brand names
   structurally stored, never on app-authored surfaces.
3. The PA evidence packet (dated weight history, BMI trajectory,
   program participation, dose/side-effect timeline) is the
   highest-leverage clinic artifact — and it is "her file,"
   payer-shaped. Visit-prep card = its consumer face.
4. Exceptions-not-streams: CareEvents with severity + provenance
   + disposition are the future triage substrate.
5. Minutes-ledger readiness on future care-team actions.
6. Outcomes rollups (% at ≥5% loss, engagement days, data-days,
   6/12mo retention) computed from the consumer app onward.
7. Quiet BAA-readiness: access logging, deletion paths, field
   inventory; no analytics on health fields, ads-never covenant.
8. Longevity config = labs entity + protocol stack objects on
   the same care-plan schema; our daily layer answers their
   named follow-through gap.

---

## B. Adherence + engagement science (the protocol's evidence)

### B1. GLP-1 persistence reality
- 1-year discontinuation 64.8% without T2D (Truveta/JAMA Netw
  Open 2025, n=125k) [live]; 58% stop before 12 weeks, >30% in
  the first 4 weeks (BCBSA/BHI 2024) [live]; 8% persistent at 3
  years (Prime Therapeutics 2025) [live].
- BUT 1-yr persistence nearly doubled 33% → 63% for 2021 → Q1'24
  initiators (Prime) [live] — support quality moves this number.
- Why they stop: GI side effects dominate early (64.4% nausea;
  events cluster at dose escalation); cost dominates late (OOP
  ≥$150 sharply raises quit); "met my goal / didn't know it's
  maintenance" is a named quit reason (Cleveland Clinic 2025)
  [live].
- **The strongest known persistence lever: contact frequency.**
  ≥5 provider visits → 49x more likely on-therapy at 120 days;
  ≥11 visits → 8x at 365 (BHI 2024) [live]. Each 1% weight lost
  ≈ 3% lower discontinuation odds (Truveta). → The app's role:
  the high-frequency-contact surrogate between visits — also the
  clinic-facing wedge.

### B2. What actually moves adherence
- Reminders work but small + decaying: electronic reminders
  d=0.29; SMS SMD 0.36; apps d=0.40; habituation sets in ~3
  months [live]. Anchoring beats alerting: implementation
  intentions d≈0.59-0.65 (Gollwitzer & Sheeran) [live]; the
  strongest trial components are habit-linking + adherence
  feedback + self-monitoring, not reminders (2015 meta) [live].
- Weekly beats daily on persistence (bisphosphonate analog:
  60.9% vs 20.8% at 5yr) but carries the week-slip failure mode
  → **the fixed shot-day ritual is the anchor** (field consensus;
  missed-dose rule: >2 days from next dose → take, else skip)
  [live]. A "shot day" subculture already exists — own the
  ritual, don't cede it.
- Notification design: personalize timing (weekend late-morning
  is a measured high-receptivity window, +8.7-11.8%), cap
  volume, gain-framed calm copy (loss-framing measurably raises
  anxiety and doesn't outperform) [live].

### B3. Supplements (the default question, answered)
- Prevalence: 66.1% of US women use supplements (NHANES 2024);
  women 20-39 = 46%, 40-59 = 60% [live]. Typical stacks: multi,
  vitamin D, magnesium, fiber, iron, protein, prenatal.
- GLP-1-adjacent rationale is real: >22% of GLP-1 initiators
  develop ≥1 nutritional deficiency within 12mo (vit D 13.6%,
  B-vitamins, iron) (2026) [live]; 2025 four-society advisory:
  protein 1.2-2.0 g/kg/d, often needing supplementation [live].
- Adherence: supplements are the highest-forget, lowest-
  consequence class (forgetfulness ≈45% barrier) [live].
- **Verdict: supplements-first consumer default = NO.** Piling
  low-consequence checkboxes onto the protocol raises treatment
  burden and harms the high-value (medication) adherence. One
  optional collapsed "supports" line; protein is the
  evidence-backed hero (already ours). Copy stays
  structure/function-claim-safe (FDA S/F + FTC substantiation)
  [live].

### B4. Why patients abandon plans + apps
- Health-app D30 retention ≈ 3-8%; category leaders 25%+ (Sensor
  Tower 2025) [live]. Early engagement (weeks 1-2) predicts
  long-term adherence + loss [live].
- **Manual food logging is the highest-decay behavior in the
  space**: 5.4 days/wk (wks 1-4) → 1.4 (wks 5-12) → ~0 after
  (JMIR 2026, MyFitnessPal cohort) [live]. Never the daily
  obligation; passive-first sustains (v6 law confirmed).
- Clinical dropout: the top long-term predictor is **unrealistic
  expectations → dissatisfaction → quit** (PMC 2021) [live];
  treatment burden itself kills adherence and correlates with
  YOUNGER age + low self-efficacy — our exact demographic (2015)
  [live]. DPP-validated goals: 5-7% body weight [live].

### B5. Protocol/checklist design evidence
- Habit automaticity: median ~66 days (18-254); missing one day
  does not break formation; routine-anchoring accelerates;
  morning anchors formed faster in at least one dataset (Lally;
  Fournier 2024) [live].
- **Ask count: start 2-3 habits, cap the daily protocol at
  3-5 asks** — medication + one keystone as the spine, the rest
  offered-if-capacity [live]. Simpler interfaces out-complete
  feature-rich ones [live].
- SDT: autonomy support helps at 6+18mo; **controlling support
  actively harms weight outcomes** [live]. The protocol must
  read as offered structure with rationale + choice — never a
  compliance scorecard. (The engine's `because` clause law and
  ring policy are this, codified.)
- Streaks: intact streaks lift engagement but broken ones
  trigger what-the-hell abandonment; **forgiveness mechanics
  (grace, never zero-reset) attenuate**; Duolingo's leniency
  RAISED DAU [live]. (PresenceLedger's never-resets design
  confirmed correct.)

### B6. Women's-health specifics
- PCOS: metformin (daily) + GLP-1 (weekly) stacking is common —
  two cadences in one regimen; 2025 RCT: semaglutide+metformin
  beats metformin alone on weight/waist/IR/cycle regularity
  [live]. Fertility intent must branch the protocol (GLP-1
  contraindicated in pregnancy — safety gate already holds this).
- Perimenopause: ~38% sleep disruption; body-comp shift is
  invisible to the scale → scale-weight is the wrong hero;
  walking is the named primary activity (79%); resistance
  training counters muscle loss [live].
- DPP structure: 16 weekly → monthly maintenance taper; each
  extra session ≈ +0.3% loss (dose-response) [live] → cadence
  TAPERS by design; intensity is front-loaded.

### B7. Language evidence
- AHRQ Universal Precautions (2024): assume limited health
  literacy for everyone; 4th-6th grade; **anxiety itself
  degrades comprehension** — calm is a comprehension tool [live].
- Gain-framed > loss-framed for prevention; loss-framing raises
  anxiety [live]. Apple Health register: quietly factual,
  non-judgmental, imperative verbs [mem].
- No RCT on "scan a meal" vs "snap your plate" vs "log
  breakfast" exists [live-confirmed absent]. UX-writing law:
  concrete verbs, ONE verb per action app-wide. Synthesis
  lands in 04_DECISIONS (verb table).

### B8. Implications adopted (→ 03/04)
1. Protocol cap: 3-5 asks/day; medication + one keystone
   non-negotiable; rest offered. (The founder's 9-item example
   shape is contradicted by burden evidence — the ITEMS exist in
   the vocabulary, composition selects few per day.)
2. Shot-day as a named weekly ritual (anchor + fixed day/time),
   qualitatively different from any ping; titration-week
   side-effect coaching weeks 1-8 (the #1 early-quit window).
3. Supplements: one optional collapsed line, never co-equal
   rows; protein foregrounded as the evidence-backed support.
4. Reminder posture: few, personalized-time, gain-framed;
   invest in anchoring + read-back feedback loops over volume.
5. Forgiveness mechanics everywhere; expectations set at 5-7%
   in onboarding; maintenance-medication teaching at goal/
   plateau moments.
6. Food logging stays passive-first + invitation-grade; the
   scale is demoted from hero for peri cohort (body-comp/NSV
   framing).
7. Morning-anchored protocol; intensity tapers over program
   phases (DPP pattern) — phases belong in the program object.

---

*(§C language verb table resolves in 04_DECISIONS. Teardowns:
`02_COMPETITORS.md`.)*
