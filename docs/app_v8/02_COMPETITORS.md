# app v8 — COMPETITIVE TEARDOWNS (2026-07-28)

Two lanes: §A clinic-side B2B platforms, §B consumer/hybrid GLP-1
programs. All company-status claims verified live 2026-07-28.
Reverse-engineered for structure, not copied.

---

## A. Clinic-side platforms

### A1. Healthie (the reference incumbent)
- Active; $23M Series B (TCV, Oct 2024), ~$40M total; claims 25k+
  clinicians; two-headed market: solo/small wellness practices +
  digital-health startups embedding its API backend [live].
- Pricing: $19 → $149+/mo tiers + per-clinician $50; add-ons
  (eRx $40/clinician/mo, claims, payments 2.9%+30¢). Programs +
  API gated to upper tiers — engagement monetized as premium.
- **Object model (GraphQL, public):** User/Organization/Client;
  Appointment(+Type); CarePlan/EpisodeOfCare/Goal/Task/
  Recommendation; Note/Entry/Document; CustomModuleForm →
  FormAnswerGroup; Course → CourseMembership (drip content);
  Medication/Prescription/LabOrder; Conversation/Message;
  Tag/Webhook/ApiKey.
- **THE structural finding:** Programs (=Courses) have a time
  spine but are content-only; CarePlans have clinical content
  (goals/recommendations/journaling config, one active per
  client) but NO time spine, no phasing, no recurrence. **The
  incumbent cannot express "a phased protocol that adapts weekly
  and asks different things on dose days."** Clinics simulate
  with Course + static CarePlan + manual tasks. CarePlanEngine
  (day composed from state) is structurally ahead of the
  category's reference platform.
- Patient app: 4.2★ (734) reviewed like infrastructure ("every
  update introduces new bugs"; goals don't reset; HealthKit sync
  misses workouts). Churn shape: solo practitioners squeezed as
  the roadmap chases enterprise [live].

### A2. Alnu Health (the direct thesis competitor, inverted)
- Founded 2025, seed-stage; GLP-1 patient companion + clinician
  portal sold B2B to weight-management clinics [live; iOS build
  shipped days ago].
- Patient app: meal/injection/symptom/hydration logging,
  wearables, chat, badges — 4.6★ on **22 ratings** (no consumer
  pull). Their own marketing screenshot: 184 in cohort, **29 app
  users** (~16% adoption) — the category's self-portrait.
- Portal = the best available spec of what the weight-clinic
  buyer asks for: patient cohorts, medication types,
  app-engagement status, between-visit info + escalations,
  protocol-based follow-up, "clinic-specific protocols."
- **The mirror image of Jeni: they have the clinic wedge and a
  loveless patient app; we have the loved patient app and no
  clinic wedge.** The race is who crosses first.

### A3. PatientNow (ops-first cautionary tale)
- PE rollup (PSG); med-spa/aesthetics/weight-loss centers;
  $300-600/provider/mo + $2-5k implementation; AI direction =
  front-desk receptionist (Recura buy, Nov 2025) [live].
- Object model is revenue-cycle-first (photos, memberships,
  marketing automation); patient portal reviews grim. Lesson:
  wins on workflow lock-in despite ugly software — do NOT
  out-bundle ops; own the between-visit care layer they
  structurally lack. Clinics forgive broken portals, never
  broken billing → don't own billing until it can be excellent.

### A4. Tellescope (journey-first object model)
- Tiny (~$370k raised) but structurally instructive: HIPAA
  CRM/care-ops ON TOP of Healthie/Canvas/Elation/Athena.
  Customers include Fella Health [live].
- Object model: Users vs Endusers; Forms/FormResponses; Tickets;
  CareTeams; **Journeys** (triggers on patient activity/events/
  schedules, conditional branching, actions incl. webhooks);
  AI-forward primitives (AgentRecords w/ embeddings,
  AiConversations). Journey-as-first-class = marketing-automation
  grammar applied to care. Patient surface: white-label web
  portal — functional, not lovable.

### A5. Secondary set (one line each)
- **Practice Better**: loved by practitioners (G2 4.7), patient
  app 3.6★ — the best-loved wellness platform still ships a
  mediocre patient app [live].
- **Cerbo / Elation / Charm**: $121-349/provider/mo EHRs; thin
  patient portals; Elation's AI = provider-side scribe.
- **SimplePractice**: $29-99/mo; merely GOOD patient app is a
  celebrated segment-winning differentiator at the low end.
- **Canvas Medical**: headless developer-first EMR — a potential
  PARTNER for the clinic layer, not just a competitor [live].
- **Capable Health + Source Health: both DEAD** [live-verified
  domains]. Care-plan primitives as an API, owning neither the
  patient nor the clinic relationship = zero moat. Validates
  consumer-experience-first entry.
- **OpenLoop** (consolidating; bought Season Health 2026) and
  **Wheel** (pivoted to AI-first "Horizon" action layer) — infra
  players racing to sit UNDER consumer AI experiences [live].

### A6. Synthesis
1. **The convergent object model** (~12 concepts every survivor
   shares): person split (patient/staff + org + care team);
   **template/instance duality everywhere** (the deepest
   pattern); forms (template→response); program/journey
   (enrollment + steps + release rules); care plan; tasks/
   tickets; messaging; observations with source; documents;
   billing; tags/custom fields; webhooks.
2. **Universally weak**: patient-app quality (4.2 / 3.6 / glitchy
   / 22 ratings); patient-facing AI care companionship (nobody
   ships one — AI = scribes + receptionists + dev toolkits);
   passive-data-to-clinical-signal (empty quadrant; our Signals
   pattern is unmatched here); design (utilitarian SaaS chrome
   category-wide); between-visit retention tooling ("engagement"
   = reminders + marketing blasts).
3. **Minimum clinic-side surface to adopt us** (priority order):
   patient roster + enrollment states → intake forms
   (template/response/review) → **protocol editor** (phases +
   cadences + dose-day asks + thresholds — the object incumbents
   can't express) → between-visit inbox (the ONE screen a clinic
   staffs daily) → pre-visit summary + export (sit BESIDE the
   EHR; deep-link scheduling/billing, never own them yet) →
   branding knobs.
4. **Pricing norms**: $19-155/provider/mo practitioner SaaS;
   $244-349 specialty EHR; $300-600+implementation ops
   platforms. **Per-patient pricing is rare → opening: per
   enrolled patient/month ($10-25 PPPM)**, aligned with clinic
   RPM/CCM revenue and priced on the axis we win (patients who
   actually engage — vs the category's 16%).

### A7. Object model adopted (→ 03_ARCHITECTURE)
The teardown's convergent schema, unified with our engines:
Protocol carries BOTH spines (time + clinical) — phases with
entry rules; ProtocolItems with schedule rules (dayOffset /
weekday / trigger / doseDayOffset); Enrollment; ComposedDay
(CarePlanEngine output, persisted = receipts); Observation with
first-class source/provenance; Signal (severity powers the
future escalation feed); FormTemplate/Response; Thread/Message;
Escalation (dormant consumer-side — renders as the care line);
ConsentGrant (build BEFORE the first clinic — impossible to
retrofit); AuditEvent. **org_id nullable everywhere: the
consumer app is the org-null tenant; the clinic layer arrives by
filling fields, not migrating schemas.**

---

*(§B consumer/hybrid GLP-1 programs — lands as its lane
completes.)*
