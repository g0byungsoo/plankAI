# R5 — THE CLINICIAN SIDE: GLP-1/obesity care workflows, RPM, and clinician-tuned AI (2025-2026)

Researched 2026-08-10 for app v25 (clinician dashboard + prescribed-program design).
Labels: **PROVEN** (multiple independent/peer-reviewed sources) · **PROMISING** (good but thin/single-source)
· **CLAIMED** (vendor/marketing assertion) · **CONVENTION** (established practice, not evidence-tested)
· **GIMMICK** (exists to demo well, no clinical value shown).

---

## 1. What an obesity-medicine clinic actually looks like

**Who does what** (CONVENTION, converging sources):
- **MD/DO or NP/PA** — prescribes, makes every titration decision, owns red-flag response. In cash-pay
  and telehealth clinics the prescriber is very often an NP.
- **RD/dietitian** — nutrition counseling, GI-side-effect diet strategy, protein floors; increasingly the
  highest-touch role in GLP-1 care (joint ACLM/ASN/OMA/TOS advisory on nutritional priorities during GLP-1
  therapy, 2025: https://www.sciencedirect.com/science/article/pii/S2667368125000257).
- **MA/front desk** — vitals, weigh-in, refill queue, prior-auths, inventory (compounded/vial clinics).
- **Pharmacist (larger systems)** — screening, PAs, initial teaching, monthly telemed titration
  follow-ups "to ensure patients are quickly titrated up... and tolerating medications"
  (https://www.tactionsoft.com/blog/glp-1-virtual-clinic/).
- A 2-person cash-pay clinic = prescriber + MA. Everything a platform asks of them competes with
  revenue-generating visits.

**Visit cadence** (CONVENTION): labels force a rhythm — dose escalation no faster than every 4 weeks —
so titration-phase patients are seen or touched roughly **monthly for the first 4-6 months**, then every
2-3 months at maintenance. ADA 2026 standards: start low, titrate gradually "with close monitoring of
efficacy, tolerability, and safety through structured follow-up"
(https://reference.medscape.com/cc2/p10/standards-care-overweight-obesity-ada-guidelines-2026a1000cjs);
AACE 2025 algorithm same shape (https://www.guidelinecentral.com/insights/dec-2025-aace-obesityabcd-guideline-spotlight/).

**What a GLP-1 follow-up visit contains** (CONVENTION): weigh-in + trend vs last visit; GI side-effect
review; diet check (protein, fluids, smaller meals); adherence/missed doses; titration decision + new Rx;
occasionally labs. Special beats: hold ~1 week before colonoscopy; tirzepatide reduces oral-contraceptive
efficacy during escalation; stop 2 months before conception; aspiration risk higher during escalation
(https://home.hippoed.com/blog/how-to-prescribe-glp-1s-for-weight-loss-hippo-education).

**Between-visit blindness is real and clinicians know it** (PROVEN): trials had weight checks every 2-3
weeks; real clinics see patients monthly at best and rely on patient recall. Primary-care reality is a
20-minute appointment with obesity documented at 27.5% vs 83% for hypertension
(https://consultqd.clevelandclinic.org/fitting-obesity-counseling-into-the-20-minute-appointment,
https://pmc.ncbi.nlm.nih.gov/articles/PMC5855427/). The 2025 OMA/ACOFP joint perspective pushes structured
follow-up precisely because nothing structured exists between visits
(https://www.sciencedirect.com/science/article/pii/S2667368125000166).

---

## 2. Between-visit data clinicians ACT on — and what patients hide

### Actionable (each maps to a decision)
1. **Missed-dose gaps** (PROVEN, from labels): Wegovy — ≥2 weeks missed → contact prescriber; re-titration
   may be needed. Zepbound — FDA PI says consider restarting at 2.5 mg after ≥4 missed weekly doses
   (https://healthrx.com/wegovy/missed-dose-protocol, https://zepbound.lilly.com/hcp/dosage). A dose-gap
   signal is the single most decision-mapped adherence datum in this entire domain: it changes the next
   prescription.
2. **Weight velocity outliers** (CONVENTION — vendor protocol, clinically grounded): Prevounce's GLP-1 RPM
   protocol flags >2 lb/wk loss during titration (slow the titration), >3 lb/wk at maintenance (gallstone,
   lean-mass, nutrition risk), >5 lb/wk GAIN (non-adherence, fluid retention/CHF), and <5% loss at ~6-12
   weeks (non-response → adjust therapy)
   (https://blog.prevounce.com/optimizing-glp-1-therapy-through-remote-weight-monitoring).
3. **Side-effect trajectory around dose changes** (PROVEN): GI events cluster in the 2-4 weeks after each
   escalation and usually fade; a symptom that persists or worsens outside that window is what changes the
   plan (https://www.mdpi.com/2673-4168/5/4/90, https://www.dovepress.com/gastrointestinal-adverse-effects-of-glp-1-and-dual-glp-1gip-receptor-a-peer-reviewed-fulltext-article-DMSO).
4. **Red-flag symptoms** (§4) — immediate escalation, not queue.
5. **Measurement adherence itself** (PROMISING): <80% weigh-in compliance correlates with medication
   non-adherence — a disengagement early-warning (Prevounce, above).

### Noise (do not surface)
Individual meals, daily calorie totals, step counts, day-to-day scale wobble, streaks. No source in this
research names any of these as titration inputs. Trend lines summarize them; raw feeds are inbox spam.

### Under-reporting reality (PROMISING — one large 2026 commissioned survey + peer-reviewed convergence)
- **41% of GLP-1 users "suffer in silence, self-adjust, or consider quitting"; 11% quietly change how they
  take the medication without telling their provider; 30% don't believe their doctor would take symptoms
  seriously** (Oshi Health survey, July 2026: https://oshihealth.com/newsroom/press-releases/new-survey-digestive-side-effects-cause-41-of-glp-1-users-to-suffer-in-silence-self-adjust-or-consider-quitting/).
- Physician-vs-patient discontinuation-reason surveys show systematic perception gaps
  (https://pubmed.ncbi.nlm.nih.gov/29033597/).
- Cost-driven dose-stretching (taking weekly doses every 10-14 days) happens and is rarely volunteered
  (https://home.hippoed.com/blog/how-to-prescribe-glp-1s-for-weight-loss-hippo-education).
- **52% discontinue semaglutide within 1 year** (18% by 3 mo, 31% by 6 mo) — many stop-and-restart without
  clinic involvement (https://www.medscape.com/viewarticle/real-world-study-finds-over-50-stop-glp-1s-within-1-year-2025a1000obm,
  https://www.usnews.com/news/health-news/articles/2026-06-15/many-patients-stop-and-restart-glp-1-meds-study-finds).
- Under-reported categories: GI severity (normalized as "part of it"), self-adjusted dosing, psychiatric
  symptoms (discontinuers disproportionately started psychiatric meds after semaglutide initiation —
  https://www.drugtopics.com/view/patients-with-obesity-showed-high-discontinuation-low-reinitiation-of-glp-1-ras),
  and stopping altogether.

**The product truth: the clinic's biggest data gap is not a missing chart — it's that the patient's actual
dosing behavior and symptom burden are invisible until they churn.**

---

## 3. Titration decisions in practice

**Label default** (PROVEN): 4-week minimum per step; semaglutide 0.25→2.4 mg (6 steps); tirzepatide
2.5→15 mg (6 steps).

**Real-world deviation is the norm** (PROVEN):
- Academic obesity clinic (2025, Wiley DOM): only **22.9% reached semaglutide 2.4 mg**; 28.3% reached
  tirzepatide 15 mg; median unique prescriptions 3 (label targets 6); median persistence 10.7 months;
  discontinuation 14%/24%/50% at 3/6/12 months vs 7-11% in trials; GI issues = top ER-visit reason
  (https://pmc.ncbi.nlm.nih.gov/articles/PMC12515774/).
- Call-center cohort: 52.9% of semaglutide vs 77.6% of tirzepatide courses reached max dose
  (https://www.mdpi.com/2673-4168/5/4/90).

**What drives up / hold / down** (CONVENTION, converging clinical sources):
- **UP**: 4+ weeks at current dose, tolerable side effects, weight response below goal, patient consent,
  drug coverage/supply available.
- **HOLD** (most common deviation): active GI symptoms, >2 lb/wk loss during titration, "response is good
  enough at this dose" (treat-to-target — the AACE 2025 algorithm frames dose as means, not destination),
  cost/coverage (intermediate tirzepatide doses may lose coverage past 4 weeks), upcoming
  surgery/colonoscopy, intercurrent illness/dehydration, patient anxiety about escalation.
- **DOWN / pause**: intolerance at the new step (drop back to last tolerated dose, retry in 4 weeks),
  rapid loss, red flags, pregnancy planning, drug holiday.
- Titration speed is explicitly individualized: "some people benefit from slower titration schedules"
  (https://jumpstartmd.com/hub/glp1-weight-loss/dosing-titration).

**Implication: a titration PLAN is not a static schedule — it is a decision loop with a 4-week clock whose
inputs are tolerance + velocity + adherence.** Any "prescribed program" model must represent hold/slow
states as first-class, not as deviations.

---

## 4. Escalation red flags worth SURFACING (never diagnosing)

From labeling and clinical guidance. App language stays "contact your clinic now / seek urgent care" +
clinician queue item; the app never names a suspected diagnosis to the patient.

| Signal (patient-reportable) | Why it matters | Urgency |
|---|---|---|
| Severe persistent abdominal pain, may radiate to back, ± vomiting/fever | Pancreatitis; drug stopped, usually never restarted | Immediate (urgent care + clinic) |
| Right-upper-quadrant pain after meals, jaundice, dark urine | Gallbladder disease; risk ↑ with rapid weight loss | Same-day clinic contact |
| Vomiting/diarrhea preventing fluid intake | Dehydration → acute kidney injury (labeled risk) | Same-day; urgent if unable to keep fluids |
| Shakiness/sweating/confusion in patients also on insulin or sulfonylurea | Hypoglycemia — the labeled interaction case | Same-day; med-list-conditional flag |
| Sudden vision loss or rapid visual deterioration | NAION — EMA added to semaglutide labels June 2025 as very rare (~1/10,000); stop drug if confirmed; FDA has not acted yet | Immediate |
| New/worsening depression, suicidal thoughts | FDA/EMA 2024-25 reviews found no causal link, but AOM-class labeling still advises monitoring; state law (CA) expects crisis detection in AI chat | Immediate crisis routing + clinician notify |
| Missed doses ≥2 wks (sema) / ≥4 wks (tirz) | Re-titration decision required before next injection | Queue (before next dose) |
| Persistent vomiting near planned surgery/anesthesia | Aspiration risk; peri-operative hold guidance | Queue |

Sources: https://www.drugs.com/medical-answers/6-wegovy-side-effects-you-aware-3573374/,
https://www.goodrx.com/classes/glp-1-agonists/glp-1-side-effects,
https://www.tctmd.com/news/eye-condition-very-rare-side-effect-semaglutide-ema-says,
https://www.who.int/news/item/27-06-2025-27-06-2025-semaglutide-medicines-naion,
https://therxindex.com/guides/glp-1-long-term-side-effects/ (suicidality + thyroid "substantially
de-risked 2025-26"), labels via https://zepbound.lilly.com/hcp/dosage.
Red-flag content must be **catalog-driven and updatable** — NAION appeared mid-2025; the next signal will
appear mid-lifecycle too.

---

## 5. RPM billing 2025-2026: codes, economics, and the cash-pay catch

**The code set (PROVEN — CMS PFS; dollar figures are national averages, locality-adjusted)**
(https://www.thoroughcare.net/blog/remote-patient-monitoring-billing-rules,
https://blog.prevounce.com/quick-guide-remote-patient-monitoring-rpm-cpt-codes-to-know):

| Code | What | Requirement | ~2026 rate |
|---|---|---|---|
| 99453 | Setup/education | once per device | $21.71 |
| 99454 | Device supply + transmission | **≥16 days / 30** | $52.11 |
| **99445 (NEW 1/1/2026)** | Device supply, short duration | **2-15 days / 30** (mutually exclusive w/ 99454) | ~$52 per source above; verify locality |
| 99457 | Care mgmt, first 20 min/mo | interactive contact | $51.77 |
| 99458 | Each addl 20 min | add-on | $41.42 |
| **99470 (NEW)** | Care mgmt, 10-19 min/mo | light-touch month | $26.05 |

- **Device rule (PROVEN, the tripwire)**: data must come from an **FDA-defined medical device that
  automatically and digitally transmits**. "Manual patient entry is not permitted for billing." A phone
  app with hand-logged weights is NOT an RPM device; a cellular scale is.
- 2026 PFS direction: continued expansion of remote-care flexibility
  (https://www.ruralhealth.us/blogs/2025/08/what-medicare%E2%80%99s-2026-proposed-rule-signals-for-remote-care).
- **Is GLP-1 RPM actually reimbursed?** PROMISING-to-CLAIMED. Medicare pays RPM for chronic conditions and
  obesity qualifies; vendors (Prevounce, Withings Health Solutions, Rimidi, RPMLogix) actively sell
  weight-RPM programs for GLP-1 panels (https://www.withings.com/us/en/health-solutions/supporting-glp-1,
  https://rimidi.com/patient-populations/weight-management,
  https://rpmlogix.com/rpm-ccm-glp-1-therapy-for-medicare-patients/); trade press names obesity/GLP-1 as
  RPM's 2025-26 growth story (https://www.healthcareitnews.com/news/remote-patient-monitoring-will-boost-chf-and-glp-1-care-2025,
  https://www.medicaleconomics.com/view/rpm-in-2026-focusing-on-obesity-and-effects-of-glp-1-drugs). No
  independent published evidence yet of GLP-1-adherence RPM improving outcomes.
- **Economics (CLAIMED, convergent vendor math)**: full stack ≈ $120-160/patient/month; break-even at
  25-35 enrolled; 1 clinical monitor per 150-250 patients; net margins 30-50%
  (https://ccnhealth.com/articles/blog/rpm-revenue-guide, https://www.healtharc.io/blogs/remote-patient-monitoring-roi-in-2026-costs-benefits-is-it-worth-it/).
- **The cash-pay catch**: Jeni's pilot clinics are cash-pay. RPM codes bill insurance — a pure cash-pay
  clinic has no payer to bill, and its GLP-1 patients skew commercial/self-pay, not Medicare. RPM revenue
  is a HYBRID-clinic story and a future B2B talking point, **not the pilot value prop**. The pilot value
  prop is §2: persistence (52% year-one churn is the clinic's own revenue leak) and safety coverage.

---

## 6. RPM platforms + the alert-fatigue evidence

**Platform landscape** (CLAIMED, vendor-tier sources): 100Plus (free-device revenue-share model; user
reviews cite device quality/support complaints — https://www.softwareadvice.com/home-health/100plus-profile/),
Athelas (AI-prioritized alerts; critiqued for offshore support and automation-first compliance —
https://www.1bioshealth.com/blog/remote-patient-monitoring-companies), Optimize Health, HealthSnap,
Cadence, Accuhealth, Tenovi/Impilo as device-logistics infrastructure
(https://www.candihealth.com/top-remote-patient-monitoring-companies-in-2025/). Omada/Virta clinician
side: coach + specialist "in lockstep" over visualized member data; physician connected as needed — a
tiered attention model, not a physician dashboard
(https://resourcecenter.omadahealth.com/all-conditions/how-virtual-first-care-works-for-coaches-and-care-teams).

**Alert fatigue (PROVEN)**:
- 74-99% of physiological monitor alarms are non-actionable
  (https://array.aami.org/doi/full/10.2345/0899-8205-46.4.268).
- JAMIA systematic review: fatigue is reduced by interaction design + tailoring alerts to clinical role
  (https://academic.oup.com/jamia/article/26/10/1141/5519579).
- Realist review of RPM: slow alert response and low clinician adherence can make RPM WORSE than nothing
  (https://pmc.ncbi.nlm.nih.gov/articles/PMC8388293/).
- VA cardiac-device study of alert-based (exception) monitoring: clinicians endorse it as the future (83%)
  but fear loss-to-follow-up without scheduled touchpoints; patients fear being unseen
  (https://pmc.ncbi.nlm.nih.gov/articles/PMC11990655/).

**Design response that's winning (PROMISING → CONVENTION among 2026 builders)**: exception-based review —
"show the 12 patients needing attention today, not all 400 enrolled"; risk-ranked worklists; configurable
thresholds; role-tailored views; every queue item carries its recommended next action
(https://corpsoft.io/2026/03/31/remote-patient-monitoring-software/). This exactly matches the founder's
"what deserves the clinician's attention" brief.

---

## 7. Patient-reported outcomes: cadence and completion reality

- Oncology ePRO (best-studied model): weekly symptom check-ins with nurse-triage alerts improved symptoms
  and reduced ER/hospital visits (PROVEN — https://pubmed.ncbi.nlm.nih.gov/35661856/,
  https://www.pcori.org/implementation-evidence/putting-evidence-work/health-systems-implementation-initiative/monitoring-electronic-patient-reported-outcomes-during-cancer-treatment).
- Completion reality (PROVEN): ~64% of weekly assessments completed, decaying 72%→52% over 10 weeks;
  PRO-CTCAE ~75% of timepoints (https://ascopubs.org/doi/10.1200/CCI.21.00063,
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8202059/). Plan for decay; don't build features that require
  90% compliance.
- Validated GI instrument: GSRS — 15 items, 5 subscales (pain, reflux, indigestion, constipation,
  diarrhea), weekly, validated (https://pmc.ncbi.nlm.nih.gov/articles/PMC10432906/). 15 items is too many
  for a consumer app; a 3-5 item subset (nausea/vomiting severity, bowel change, fluid intake, "worst
  symptom this week") covers the actionable space — label as GSRS-informed, not GSRS.
- Sustainable cadence for GLP-1 (synthesis, PROMISING): **weekly micro-check-in (≤4 taps) during titration
  and for 2-3 weeks after any dose change; monthly at stable maintenance; event-triggered otherwise.**
  Only ask what routes to an action (§2). Jeni already captures dose events and symptoms passively — the
  PRO is a thin confirmation layer, not a survey program.

---

## 8. What a 2-person cash-pay clinic can actually run

- Purpose-built cash-pay/med-spa platforms: Pabau, PatientNow, Heally, DocVilla, Tebra — packages,
  memberships, recurring card billing, telehealth, intake forms, photos, inventory
  (https://pabau.com/blog/top-7-weight-loss-clinic-software-in-the-us-2026-guide,
  https://www.patientnow.com/weight-loss/, https://heally.tech/solutions/weight-loss-clinics).
- "68% of medical weight loss practices run on software never built for GLP-1 workflows... duct-taping
  with spreadsheets and manual texts" (CLAIMED — Pabau marketing, but directionally consistent:
  https://pabau.com/blog/emr-for-weight-loss-clinic/). VC agrees: VITL raised $7.5M (March 2026) to fix
  cash-pay GLP-1 clinic prescribing (https://techcrunch.com/2026/03/25/riding-the-glp-1-boom-vitl-lands-7-5m-to-overhaul-cash-pay-clinic-prescribing/).
- Weight-loss clinics: cash-pay, >50% margins, GLP-1s the top revenue line — persistence IS the business
  model (https://pabau.com/blog/how-weight-loss-clinics-make-money/).
- **Async messaging is the hidden cost** (PROVEN): portal messages doubled 2020-2025 (+153% surge);
  top-quartile message volume → 6.4x odds of high exhaustion; messages ADD to visits rather than replace
  them (https://www.techtarget.com/patientengagement/news/366645152/153-surge-in-patient-portal-messaging-imperils-provider-workloads,
  https://kevinmd.com/2026/04/how-patient-portal-message-volume-drives-physician-burnout.html,
  https://www.ama-assn.org/practice-management/digital-health/phone-calls-stable-patient-portal-messages-keep-piling).
  E-visit billing for messages exists (98970-72) but risks patient satisfaction
  (https://www.mgma.com/mgma-stat/ensuring-accurate-coding-and-billing-for-patient-portal-messages-as-e-visits).
- Operating floor for the pilot dashboard: **<10 minutes/day, zero mandatory free-text inbox, weekly
  digest + urgent-only interrupts, one-page pre-visit summary, CSV/PDF export.** No clinic will adopt a
  second EHR.

---

## 9. Clinician-configurable patient-facing AI: precedents + the regulatory line

**Precedents (all partial)**:
- **Hippocratic AI** — closest precedent to "clinician tunes the patient-facing agent": constellation
  safety architecture + an "app store" where clinicians author/validate/share AI scripts for defined
  care tasks, each safety-tested before release; advisory councils of physicians/nurses (CLAIMED —
  https://hippocraticai.com/polaris/, https://research.contrary.com/company/hippocratic-ai). Pattern:
  **clinicians pick and parameterize vetted programs; they do not free-text the model.**
- Telehealth GLP-1 operators run human-in-the-loop: protocols + async physician review; transcripts
  reviewed by licensed clinicians (https://arxiv.org/pdf/2603.08448 — feasibility study pattern;
  https://meto.co/blog/glp-1-telehealth-provider-comparison).
- RPM platforms already ship per-patient threshold configuration — the mundane, proven form of
  "clinician-configurable" (§6).
- Omada/Virta: configuration lives in care-team playbooks, not software knobs exposed to clinicians.

**FDA line (PROVEN, current as of Jan 2026)**
(https://www.arnoldporter.com/en/perspectives/advisories/2026/01/fda-cuts-red-tape-on-clinical-decision-support-software,
https://hooperlundy.com/fdas-new-digital-health-guidance-signal-shift-for-wellness-devices-and-cds/):
- Jan 2026 reissued CDS guidance is **HCP-facing only**. The four §520(o) non-device criteria include
  "supports or provides recommendations **to healthcare professionals**" + independent-review basis.
  A clinician dashboard that surfaces trends/flags with transparent reasoning fits non-device CDS.
  New enforcement discretion even covers single-recommendation HCP tools and risk scores — but NOT
  time-critical event prediction or image/signal analysis.
- **Patient-facing recommendation software has NO CDS exemption.** Its shelter is the (Jan-2026-expanded)
  general wellness policy — weight management is a recognized general wellness category; the reissue
  newly tolerates validated physiological estimates, ranges/trends, and out-of-range notifications.
- The becoming-a-device tripwires: computing/adjusting drug doses, diagnosis claims, treating disease,
  black-box outputs. An app that CARRIES the clinician's titration plan and REPEATS label rules verbatim
  is on defensible ground; an app that DECIDES doses is a device.
- If ever going the device route, FDA now expects Predetermined Change Control Plans for AI functions
  (https://censinet.com/perspectives/ai-policy-playbook-essential-guardrails-healthcare-innovation).

**State AI laws now in force (PROVEN — https://www.hklaw.com/en/insights/publications/2026/05/states-continue-efforts-to-regulate-ai-in-healthcare)**:
- Illinois (eff. 8/1/25): AI may not represent itself as a licensed provider; AI-therapy restrictions.
- California (eff. 1/1/26): AI-identity disclosure to users, crisis detection, minor safeguards.
- Texas (eff. 1/1/26): clinician-oversight disclosure. AMA pressing Congress for chatbot guardrails
  (https://www.medicaleconomics.com/view/ama-presses-congress-for-guardrails-on-ai-chatbots).

**Verdict on "clinician tunes the coach"**: structured controls = PROMISING with real precedent
(threshold knobs, program/protocol pickers, vetted script selection, emphasis toggles, message
templates). Free-text prompt editing of a patient-facing model by clinicians = GIMMICK with liability
attached: no shipping precedent found, unbounded output, and it converts the clinic into an unreviewed
model deployer.

---

## IMPLICATIONS FOR JENI (ranked)

1. **Build an attention queue, not a dashboard.** Exception-based review is both the founder's instinct
   and the evidence's answer to alert fatigue (74-99% non-actionable alarms; role-tailored design).
   The clinician surface = a short ranked queue where every item is (patient, signal, recommended next
   action, one-tap resolution). Target: reviewable in <10 min/day; weekly digest for everything else.
2. **Surface exactly four between-visit signals**: (a) dose-gap ≥14d sema / approaching 28d tirz —
   "re-titration decision needed before next injection"; (b) weight-velocity outliers (>2 lb/wk during
   titration, >3 lb/wk maintenance, >5 lb/wk gain); (c) persistent/worsening symptoms outside the 2-4-week
   post-escalation window; (d) red-flag reports (§4 table — immediate, not queued). Everything else is
   digest material. Jeni's v24 DoseEventRecord + symptom log already produce (a), (c), (d) natively.
3. **Sell the under-reporting wedge.** 41% suffer in silence; 11% self-adjust secretly; 52% churn by
   month 12 — and churn is the cash-pay clinic's own revenue leak. Jeni's pitch to clinics is "see the
   dosing behavior and symptom burden you currently can't," framed as persistence + safety, NOT as RPM
   billing revenue (cash-pay clinics can't bill RPM; manually-logged app data isn't billable anyway).
4. **Titration plans as version chains fit perfectly — add HOLD/SLOW as first-class states.** Real-world
   titration is slower than label (23% reach max semaglutide dose); the prescribed program model must
   express "hold at 5 mg, reassess in 4 weeks" without treating it as deviation. The 4-week clock is the
   natural review cadence object.
5. **Micro-PRO, titration-windowed**: ≤4 taps, weekly during titration + 2-3 weeks post-dose-change,
   monthly at maintenance, GSRS-informed items only where an answer routes to an action. Design for
   completion decay (72%→52% over 10 weeks is the benchmark, not failure).
6. **Clinician configuration = structured knobs only**: titration-plan picker (label-default / slow /
   custom steps), per-patient threshold overrides, coach emphasis toggles (protein, hydration, dose-day
   support), vetted message/education templates, escalation routing preferences. The authority hierarchy
   (CLINICIAN PRESCRIBED > JENI RECOMMENDED > USER PREFERRED) has precedent in Hippocratic's
   pick-and-parameterize model and RPM threshold config.
7. **Escalation language law**: the app says "contact your clinic now / seek urgent care" and files the
   queue item; it never names a suspected diagnosis. Mood signals route to crisis resources first (CA
   law) then clinician notification. Red-flag catalog must be remotely updatable (NAION arrived mid-2025).
8. **Reduce the inbox, never add to it.** No default free-text patient→clinician chat. Structured
   check-ins → digest; urgent-only interrupts. Message volume is the #1 burnout driver in async care;
   a platform that adds inbox is dead on arrival at a 2-person clinic.
9. **Pre-visit one-pager as the flagship artifact**: interval weight curve, dose ledger (with gaps),
   symptom timeline, flags raised/resolved — printable/PDF, fits the 20-minute visit. This, not a live
   dashboard, is what the visit actually consumes.
10. **RPM-compatibility later, via partnership**: if hybrid clinics want RPM revenue, integrate an
    FDA-cleared cellular scale (Withings Health Solutions pattern) and let the clinic's RPM vendor bill;
    Jeni's role is the intelligence + documentation layer (99457 time logs), never the "device."

### DO-NOT-BUILD
- **In-app dose calculation or autonomous titration advice to the patient** — device territory + the one
  liability that kills a pilot. Carry the clinician's plan; repeat label rules verbatim; route decisions.
- **Free-text clinician editing of the coach's prompt/persona** — no shipping precedent, unbounded
  output, converts clinic into model deployer. Structured toggles only.
- **AI messages that appear to come from the clinician** (IL/TX impersonation + disclosure laws). Always
  label the sender; "— jeni" never signs as the clinic.
- **Predictive "pancreatitis risk" style alerts** — time-critical event prediction is explicitly outside
  FDA's enforcement discretion; surface reported symptoms, don't predict emergencies.
- **A second EHR** (notes, scheduling, billing, inventory) — Pabau/PatientNow/VITL own that; Jeni is the
  between-visit layer that exports into whatever the clinic runs.
- **Real-time continuous alert streams / per-event notifications to clinicians** — the alert-fatigue
  literature's central failure mode.
- **RPM billing claims in marketing** — Jeni with manual logging cannot satisfy the device rule; do not
  imply reimbursable RPM.

### Regulatory tripwires (standing list)
1. Patient-facing recommendations have **no CDS exemption** — stay inside general wellness framing; the
   clinician dashboard should be built to the four §520(o) criteria (transparent basis, HCP-directed).
2. FDA general wellness + CDS guidances reissued Jan 2026 — re-check before any claim change; guidance
   moved twice in one month (Jan 6 → Jan 29, 2026).
3. State AI laws: AI identity disclosure (CA), no licensed-provider impersonation (IL), clinician-oversight
   disclosure (TX) — all already in force; more states following (Manatt/H&K trackers).
4. RPM device rule: billing requires FDA-defined device + automatic transmission; manual entry never bills.
5. No BAA yet (standing project law): no PHI-handling claims, never "HIPAA compliant" in any clinic
   material; pilot stays internal-dev-alpha with test data.
6. Never adjust a prescription in-app; prescription authority stays with the clinician (practice-of-
   medicine line) — the authority hierarchy must be enforced in code, not just copy.
7. Existing project compliance floors still bind the clinician surface: no drug brand names in consumer
   marketing, no equivalence/numeric weight-loss claims (docs/glp1_strategy_2026_06_16.md).
8. Red-flag/safety content must be versioned + remotely updatable — label changes (NAION June 2025) arrive
   between releases.
