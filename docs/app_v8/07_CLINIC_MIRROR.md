# app v8 — THE CLINIC MIRROR (founder principle, 2026-07-29)

The founder's law: imagine the clinician dashboard BEFORE any
patient surface. The clinician authors care; the patient performs
care; the app visualizes care. This doc is the standing mirror —
every patient surface mapped to the clinician configuration it
will one day render from, with the honest audit of what renders
from configuration TODAY vs what carries a documented seam.
Companion evidence: 01_RESEARCH §A (exceptions-not-streams, the
billing atoms), 02_COMPETITORS §A6 (the minimum clinic surface:
roster → intake → protocol editor → between-visit inbox →
pre-visit summary → branding).

## 1. The ladder, mirrored

| Clinician authors (future) | Patient performs (today) | Object | Status |
|---|---|---|---|
| **Protocol** — thresholds, cadences, ask caps, tone rules, titration window | the composed day (≤3 moves + invitations) | `CareProtocol` (+ `protocols`/`protocol_items` rows, seeded) | **config-driven** (engines injected; S2 = served hydration) |
| **Medication** — regimen, schedule, titration, refills | mark doses, report symptoms | `RegimenPlan` (authority self\|care_team, guards, rxnorm/strength seams) | **authority shipped**; clinician writes arrive server-side (S3/S4) |
| **Supports** — clinic-configured adjuncts (fiber, vitamin D, magnesium-for-regularity, meal-replacement programs) | protein number (already tracked); later ONE attributed observational line — never pill-check rows | `CareProtocol.supports` [SupportItem] (authored data; consumer default = empty) | **seam shipped** (FR8: policy-object-only, rendered S3) |
| **Movement** — sessions/week, minutes ramp, step goals | move / walk rows, offered invitations | `IntensityProfile` tables + workout slots | **static, documented S2 config candidates** (product tiers, not per-clinic judgment yet) |
| **Nutrition** — protein policy, kcal posture | plates, protein arc, "room for ~" | `TargetsService` ← CareProtocol protein policy | **config-driven** (kcal = population math by design) |
| **Monitoring** — weigh cadence, passive rails, ask schedule | weigh-in row, vitals/sleep/steps passive, evening asks | cadence in CareProtocol ✓; `VitalsService` rails always-on | cadence **config-driven**; rail selection = S2 candidate |
| **Goals** — pace, milestones | the plan she holds, 5-7% milestone frame | `ProgramPlanRecord` + pace floors in config | **config-driven floors**; goal authored at enrollment |
| **Adherence** — what counts, how it rolls up | check-off; the day seals | `ProgramDayCheckRecord` + `doseTaken` observations (regimen-stamped) | **stream shipped**; rollups = S3 |
| **Observations** — what's collected, sync policy | evening words, journal, sit-check | `ObservationStore` (typed, provenance, regimen join key) | **shipped** |
| **Exceptions** — rules, severities, alert budget | (never patient-facing as alarms — care lines only) | `careEvent` observation kind (severity/disposition payload) | **substrate shipped**; rules + queue = S3 |

## 2. The render rule (audit)

"Today's patient UI should naturally render from tomorrow's
clinician configuration. Do not hardcode future clinical logic
into the patient UI."

- **Renders from config today:** dose-day composition + lead
  policy, hydration offer + ml aim, titration window, tone
  thresholds, promotion thresholds, ask caps, weigh cadence,
  protein policy, band zones, pace clamps. Voice renders through
  `BrandVoice` (a tenant's words, never a rule fork).
- **Static with a documented seam (S2):** beat-existence slot
  tables + archetype rotations (`PrescriptionEngineV2` /
  `ProgramDayArchetype`), lesson cadence tiers, step-goal tiers,
  checklist vocabulary (Swift enum → `protocol_items` rows), the
  passive-rail set. These are product-tier definitions today;
  they become per-protocol data the day a clinic needs them.
- **Deliberately NOT clinician-shaped:** the second act
  (reflect/prepare/recover/celebrate — composition law), the
  tools rail (founder-locked grammar; a future protocol MAY
  curate its doors, S2 candidate), the editorial register
  (BrandVoice covers words; bones are the product).
- **Patient-owned forever:** her journal line, feeling words,
  her display name for a medication, her data-sharing moments.

## 3. The clinician's monitor side (S3 spec anchors)

What the dashboard reads is already being written: the
between-visit inbox subscribes to `careEvent` (ranked, deduped,
per-clinic alert budget — never raw streams, 01_RESEARCH §A3);
adherence rollups derive from check records + dose observations
(data-days per 30-day window = the billing atom, §A5); the
pre-visit summary assembles from `ProgramWeekSlice` + the chart;
minutes-ledger primitives attach to future care-team actions.
Nothing patient-facing changes when these arrive — that is the
test the mirror exists to keep true.

Dashboard-research anchors (2026-07-29 lane, cited in FR7/FR8):
the convergent configure-vocabulary (protocol · population ·
regimen · monitoring parameter + threshold · cadence · ask/PRO ·
content assignment · escalation rule · goal · supports policy —
validated against Alnu/Healthie/Prevounce/Canvas/Elation) maps
onto our objects with SUPPORTS as the one noun we lacked (now a
CareProtocol seam). The monitor spine: roster with status tokens
(Alnu Active/Review/Inactive), the exception queue, adherence
rollups, the pre-visit summary, time/billing capture. **The alert
budget is a law, not a feature**: RPM programs document clinician
tune-out in 2-3 weeks and ~70% ignored alerts; personalized
baselines cut false alerts 60-80% — every future threshold a
clinician authors defaults conservative and tunes DOWN
(VitalsTrend's her-baseline-only design is already this).
Canvas's trigger → compute → recommendation-card pattern affirms
CarePlanEngine's shape: the day IS a render of authored effects.
The liability posture to adopt verbatim at S3: configured
engagement and information sharing — qualified professionals
retain responsibility for clinical interpretation and decisions.

## 4. Care, not a feature (the §4 lens, reviewed)

The medication experience already composes INTO the day (the
dose-day lead), never as a destination: no medication tab, no
tools-rail door, no becoming spread, no share surface. Her one
"place" for it is the row's own sheet (schedule + remove +
privacy) and a quiet settings door — the bridge affordance, kept
because medication starts mid-journey. Verdict: "I am completing
today's care" is the shipped structure; the remaining risk is
future surfaces treating medication as a module — this doc is
the standing check against that.
