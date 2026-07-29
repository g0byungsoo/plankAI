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

## B. Consumer + hybrid weight-care programs

### B1. The market frame (three shocks, 18 months)
1. **Compounding endgame**: FDA resolved the semaglutide shortage
   Feb 2025; 150+ warning letters through Jun 2026; Apr 2026
   proposal strikes GLP-1s from the 503B bulks list. The gray
   market is being killed by enforcement [live].
2. **Pharma-direct price collapse**: Wegovy pill $149/mo (Jan
   2026), Zepbound vials $299-449, orforglipron approved Apr
   2026 from $149. Drug access is a commodity with a falling
   floor — never compete on it [live].
3. **Persistence crisis quantified**: 84.4% off drug by year two;
   SURMOUNT-4 withdrawal arm regained +14.0%. **Margin is
   migrating from the drug to the care around it** [live].

### B2. Fates (verified live)
- **Ro**: ~$370M Body revenue; insurance-ops moat (PA concierge);
  app 4.8★ but a thin shipment-tracker loop ("suuuper clunky…
  canned message responses"); NO maintenance product.
- **Hims**: $2.35B revenue but Q1'26 net loss $92M after the
  compounded-Wegovy debacle → FDA probe → Novo suit → Mar 2026
  settlement; bought Juniper/Eucalyptus for up to $1.15B —
  paid a billion for a WOMEN'S PROGRAM IDENTITY, not drug access.
- **Noom**: coach layers gutted by layoffs; month 3-4 curriculum
  cliff; still selling compounded "microdoses" (Jul 2026); made
  its GLP-1 Companion FREE (Jun 2026) — tracking UX is now
  commoditized; best maintenance POSITIONING ("meds to lose,
  Noom to keep it off").
- **WeightWatchers**: Chapter 11 → emerged Jun 2025; behavioral
  base melting -26% YoY while Med+ grows; menopause program
  (Sept 2025) = first real women's-health move in category.
- **Found**: insurance-first pivot; 14-med portfolio routed by
  "MetabolicPrint" — churn absorbed by re-routing meds, a unique
  mechanic; coach thinness ("Great job hydrating!").
- **Calibrate**: THE cautionary tale — prepaid year + results
  guarantee + undeliverable meds = refund time bomb → Madryn
  took control 2023; now ~90% enterprise, first profitability
  Feb 2026. Ironically holds the best consumer taper data (92%
  of taperers held ≥10% loss at 6mo).
- **Fella/Delilah**: no iOS app at all; Lilly v. Aios complaint
  quotes founder titration-triage via Reddit DMs; Delilah = a
  pricing skin on a men's platform.
- **Fridays**: $99 era over; BBB F; "96.8% success" = DELIVERY
  performance. The mill diaspora (Fella/Fridays/compounder
  customers) faces forced transitions with zero care attached.
- Secondary: **Omada** (OmadaSpark AI between human touches;
  63.2% maintained 1yr post-GLP-1), **Virta** (the off-ramp IS
  the product; "guided taper = 8x"), **Mochi** ($79 flat, best
  consumer economics, compounding-exposed), **Voy UK** ("Joy"
  AI coach under named clinicians w/ explicit escalation — the
  live example of our clinic-layer architecture), **Embla**
  (16.7% loss on ~66% less semaglutide via treat-to-target —
  peer-reviewed), **knownwell** ($25M CVS round for anti-shame
  CLINICAL care), **Nourish** ($1.75B "AI-native metabolic
  clinic"), **Function/Superpower** (labs collapse in price;
  the explanation layer is the product) [all live].

### B3. What NO ONE does well (verified against all 8 primaries)
1. A beautiful composed daily care experience (the category's
   daily surface is a chore, a portal, or a shipment tracker).
2. Medication + behavior on ONE surface (dose-tracking gets
   bolted on; nobody shapes the day around the dose).
3. **The maintenance off-ramp** — the market's weakest beat;
   every productized off-ramp is B2B; NO consumer app sells
   "after the medication."
4. Women-specific care in-product (cycle/perimenopause-aware).
5. Passive data as care (nobody converts passively-held signals
   into the feeling of being watched over).
6. The feeling of being cared for between visits (US consumer
   slot empty; OmadaSpark/Voy-Joy are enterprise/UK).

### B4. Retention mechanics that demonstrably work
- **Visible progress**: every 1% lost cuts discontinuation
  hazard 3.1-3.3% (JAMA 2025) — trend-as-hero is a clinically
  validated retention mechanic, not just voice.
- Named human + scheduled ritual; refill-gated cadence;
  community (the one moat GLP-1s didn't erode); med-portfolio
  re-routing; insurance capture.
- What fails: streaks alone; curricula that exhaust; prepaid
  years; thinned coach layers; memberships that feel like
  shipping fees.

### B5. The compliance heat map (the walls, with precedents)
No GLP-1-alternative/equivalence framing (FDA Feb 2026 letters);
never imply FDA evaluation; no drug brand names on app surfaces
(Apple 5.2.1 + ~130 pharma suits); no first-party numeric loss
claims (NextMed $150K FTC); no fake/curated reviews; total price
transparency; easy cancel + explicit auto-renew consent (Noom
$56M); **no dosing guidance/calculators/facilitation** (Apple
1.4.2/1.4.3 — "personalized dosing" is the exact attacked
theory); no permanence promises; measurement claims need
methodology. Our existing floors map 1:1 — load-bearing, not
stylistic.

### B6. Pricing norms
Care-without-med: $12-25/mo consumer economics. Care-around-med:
$74-199/mo accepted band, meds separate. Failure mode: $149 that
feels like a shipping fee. Success: flat legible pricing; value
visible weekly.

### B7. Structural opportunities adopted (→ 04_DECISIONS)
Own the composed daily care surface · compose the day around the
dose (never dosing advice) · build "after the medication" as a
named consumer product (zero competitors, brutal physics) · the
women's metabolic-context layer (CycleSignal is ahead of the
market) · passive signals as the care voice · the AI-under-
named-humans pattern as the clinic license · radical billing
legibility as brand · muscle preservation for women (advisory
now standard-of-care) · consented outcome data as the clinic
entry ticket · catch the mill diaspora · never compete on drug
access.
