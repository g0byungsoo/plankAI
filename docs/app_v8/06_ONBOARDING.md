# app v8 — ONBOARDING: FROM DOWNLOAD TO INTAKE (design, 2026-07-28)

Task: rethink onboarding from "I'm downloading a calorie tracker"
to "I'm beginning care," serving BOTH the consumer today and the
clinic patient tomorrow. v5 is founder-reviewed law (v7 §10 kept
it out of scope), so this doc designs and recommends; nothing
ships without the founder's call (04_DECISIONS F3 resolves here).

## 1. What v5 already is (assets to keep)

The typed state machine (~46 beats, 5 acts), the her75
interaction language (rulers, cross-offs, strike-the-fear,
act receipts), GLP-1 branches at the top of Act II, the safety
gate (SCOFF/pregnancy/BMI → program_mode), name-first
addressing, the her-file dossier + signature + hold-to-build,
the reveal's receipt-tape + causal projection. This is a
conversion machine with clinical bones — the OMA intake shape
(weight history, meds, sleep, stress, complications-adjacent
questions) is ~70% present already. A rebuild would burn a
tested funnel to rename it.

## 2. The reframe (what "beginning care" changes)

1. **The contract sentence moves up.** The first act promises a
   CARE PLAN, not a program: "jeni builds your care plan — food,
   movement, sleep, and the medication rhythm if you have one."
   Everything after reads as intake toward that plan.
2. **Medication becomes an intake fact with a plan attached.**
   glp1Status (current) gains ONE optional follow-up beat: "which
   day is your shot, usually?" → seeds RegimenPlanRecord at
   completion (the engines read it from day 1 — the dose-day
   lead renders on her FIRST morning). Supplements asked once,
   neutrally, one multi-select → the collapsed supports line
   (D7); never co-equal rows.
3. **Expectations become the anti-churn beat.** The projection
   anchors 5-7% as the clinically meaningful first milestone
   (the DPP-validated target) BEFORE the pace picker — the top
   long-term attrition predictor is unrealistic expectations
   (01_RESEARCH §B4). The curve can still show her goal; the
   milestone framing leads.
4. **The register completes.** Intake asks read clinical-calm
   (the D9 verb law + §B7 language evidence): plain verbs,
   gain-framed, zero quiz-show energy. The interaction assets
   (rulers, cross-offs) stay — they ARE the calm.
5. **The reveal names the protocol.** "your care plan" — the
   day's shape (the checklist she'll actually see) replaces
   abstract program language; the taper is named ("weeks 1-2
   are the heaviest asks; it eases as it holds" — DPP pattern).

## 3. The clinic door (architecture, dormant)

One machine, two entries:

- **Consumer (today):** the v5 flow exactly, reframed as above.
  Paywall unchanged.
- **Patient (S3/S4):** an enrollment code/link routes into the
  SAME machine with: org's protocol pre-selected (CareProtocol
  instance), intake beats extended/replaced by the org's
  FormTemplates, paywall SKIPPED (clinic-billed), consent beats
  carrying the org's BAA-backed language, and the reveal
  presenting the clinic's plan under its BrandVoice. The v5
  typed-machine architecture (acts as data, router as pure
  function) makes this an entry-config, not a fork — the S1
  records (protocols table, org_id seams) already give the
  door a frame.

Rule kept: nothing clinic-shaped renders today.

## 4. Staging recommendation (F3 → founder)

- **Stage A (recommended next release; ~days):** the reframe
  pass on EXISTING beats — contract sentence, expectation
  anchor at projection, shot-day follow-up beat (+ regimen
  handoff), supplements single-ask, verb-law copy sweep across
  intake asks. Zero structural risk; the funnel's tested
  mechanics untouched; QA = OnboardingV5Walker re-run + copy
  screenshots.
- **Stage B (with S3):** FormTemplate-backed intake beats + the
  enrollment-code door + org consent surfaces.
- **Stage C (only if metrics demand):** structural re-sequencing
  of acts. Not currently justified — v5's funnel converts and
  its shape already matches clinical intake.

**Recommendation: Stage A.** It cashes the brief's reframe at
consumer scale without betting the funnel, and every Stage A
change is a Stage B prerequisite anyway.

## 5. Explicitly not proposed

Collecting drug names or doses at intake (5.2.1 + stigma floor —
the shot DAY is the only medication fact the plan needs);
lengthening the flow (every added beat must displace a weaker
one); moving the safety gate (its "care part" placement is
correct and shipped); touching pace floors or the data contract.
