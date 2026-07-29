# app v8 — THE DECISION LOG (living, 2026-07-28)

Format per entry: **decision** · evidence · tradeoffs · status.
Sections: standing decisions → postponed → needs-founder. Entries
land as research resolves them; nothing ships un-logged.

## Standing decisions

**D1 — Pull the v7 phase-5 platform seam forward to now.**
CareProtocol config + typed ObservationStore + BrandVoice stop
being "last phase" and become the foundation this pass builds on.
· Evidence: v7 thesis §4 already designed the seam; the founder
brief makes it the company direction. · Tradeoff: phase 3 (first-
move letters) and phase 4 (material/feel sweep) queue behind it.
· Status: adopted.

**D2 — Additive-only data evolution.** New tables/columns/records
only; defaults safe; no destructive migration; every record
tenant-friendly (stable ids, provenance fields, nullable org
seam); zero clinic UI exposure. · Evidence: medical-grade spec
principle 1; live TestFlight users on v1.1.2. · Status: adopted.

**D3 — The consumer is the default tenant.** One protocol
vocabulary serves both futures; the consumer experience is the
default protocol instance, never a fork. A clinic later authors a
protocol; the app renders it through the same engine. · Status:
adopted.

**D4 — The checklist grammar is kept; its content becomes
protocol.** Founder-locked form (sticker rows, check-off, day
rail, tools rail, rings) persists; rows re-anchor from app
features to care actions per research. · Status: adopted; item
taxonomy awaits 01_RESEARCH.

**D5 — Language completes the clinical-calm trajectory.** Plain
comprehension-first verbs (log / record / track / scan), zero
diet-culture or influencer residue, warmth in tone not poetry —
inside the editorial composition laws and lowercase voice.
· Evidence: founder register steers 2026-07-17 →; health-literacy
lane lands in 01_RESEARCH. · Status: adopted; audit pending.

**D6 — Protocol shape (research-resolved).** The item VOCABULARY
grows (medication, hydration, waist later); the daily ask count
does NOT — ≤3 actionable moves stands, medication + one keystone
are the non-negotiables on dose days, everything else is offered.
Morning-anchored; intensity tapers across program phases (DPP
pattern). · Evidence: 01_RESEARCH §B5 (2-3 habit start, burden
kills adherence in our exact demographic), §B8.1. The founder
brief's 9-item example ships as vocabulary, never as a
simultaneous checklist. · Status: adopted.

**D7 — Supplements: never co-equal, never the default spine.**
No supplements-first onboarding default; one optional collapsed
"supports" line; protein is the foregrounded evidence-backed
support (1.2-2.0 g/kg advisory; >22% of GLP-1 users deficient
within 12mo). Copy stays structure/function-safe. · Evidence:
§B3. · Status: adopted.

**D8 — The shot-day ritual.** RegimenPlan.anchorWeekday is the
transformative field (the panel's named move): a fixed, named
weekly ritual — qualitatively different from any ping — plus the
titration support window (weeks 1-8) driving hydration +
side-effect care. Missed-dose guidance stays out of app-authored
copy (no dosing advice — wall B5.8); the row simply re-offers.
· Evidence: §B1-B2 (weekly cadence week-slip; implementation
intentions d≈0.65; 30% quit in first 4 weeks). · Status: adopted;
lands with the regimen build.

**D9 — The verb law (language register).** ONE verb per action,
concrete, gain-framed, lowercase editorial: **add** (food — "add
breakfast", "add your plate"), **mark** (dose — "mark today's
dose"), **weigh in** (existing), **walk**. "Snap" survives only
as the camera's own gesture name, not as the ask; "log/track/
scan" retire from asks. Notifications: few, personalized-time,
gain-framed, content rotated. · Evidence: §B7 (AHRQ plain
language; anxiety degrades comprehension; verb consistency;
no-RCT-on-verbs confirmed — this is judgment on evidence).
· Status: adopted; sweep in the language pass.

**D10 — "After the medication" is a named product direction.**
The market's weakest beat with zero consumer competitors and
brutal physics (84% off drug by yr 2; +14% regain unsupported;
taper-support proof is B2B-only). The post-GLP-1 chapter + v7 §8
post-medication arc get pulled forward on the roadmap; the
protocol object must express a taper/maintenance phase from day
one. · Evidence: 02_COMPETITORS §B3.3. · Status: adopted
(architecture now; surface next pass).

**D11 — Trend-as-hero is retention mechanics, not just voice.**
Every 1% lost cuts discontinuation hazard ~3% (JAMA 2025) — the
trend-first anti-shame narrative is the mechanism that keeps
women in care. Reinforces existing law; cited for the record.

**D12 — Business posture notes (for the founder).** Never
compete on drug access (falling $149 floor; partners revoked
overnight); the clinic layer prices per-enrolled-patient/month
($10-25 PPPM opening — rare in category, aligned with clinic
RPM/CCM revenue); radical billing legibility as brand (the
category's top complaint genre is our trust moat); consented
outcome data is the clinic entry ticket. · Status: recorded for
founder strategy; no app change this pass.

**D13 — Sit-check widened one word, one cohort.** "backed up"
joins fine/heavy/queasy (constipation is the most persistent GLP-1
complaint and outlasts titration — it was unrepresentable in three
words), and the evening sit-check extends to the post-medication
chapter. One optional tap stays the whole cost; answers now land
in the chart. · Evidence: v7 clinic panel (problems §7, recs §8);
04_CLINICAL_CHECKLIST §1.2. · Status: shipped this pass.

## Founder refinements (2026-07-28, second brief)

Format per entry: previous decision · founder refinement ·
evidence · implementation · tradeoffs · open. Research: two lanes
(clinician med-assignment reality + FHIR authority; medication
visual-register teardown), cited inline.

**FR1 — Medication's source of truth is the clinician.**
· Previous: RegimenPlan self-created; org/protocol seams nullable
marked tenancy. · Refinement: the future clinic dashboard assigns
regimens; the patient app renders faithfully and only marks doses
/ reports symptoms / records observations — never silently
modifies clinician plans. · Evidence: FHIR MedicationRequest
(requester, reported[x]) + US Core collapse patient-reported meds
into ONE record shape with provenance fields, not parallel
systems; MyChart's pattern — patient corrections are REQUESTS,
never writes; Healthie renders e-prescribed and self-reported
side by side, provenance-labeled [live]. · Implementation:
`authority` field ("self" | "care_team"; iOS only ever writes
"self") + rxnorm/strength reconciliation seams on
RegimenPlanRecord + `regimen_plans` (additive migration
20260728_2); `RegimenService.isManagedByCareTeam` guards every
mutation (belt-and-braces: authority OR org/protocol seam);
dose-mark + sit-check observations stamp their regimen id (the
clinician-portal join key — adherence and symptoms triage in
different queues). Tested. · Tradeoffs: none user-visible today;
one enum now deletes the future migration. · Open: the
reconciliation moment ships with S3 (spec below).

**FR2 — The consumer bridge: hybrid, superseded by
reconciliation.** · Previous: medication appears via the
onboarding-identified cohort only. · Refinement question:
self-managed interim? hidden-unless-enabled? · Evidence: her
record is Statement-shaped (assertion), never Request-shaped
(order) — no refills/sig/prescriber on consumer records;
medication starts MID-journey (Omada's GLP-1 track exists because
of it; Virta actively deprescribes), so an entry gate alone is the
wrong lifecycle; every precedent that survived the self→provider
transition kept the patient's stream alive BESIDE the provider's
[live]. · Implementation: kept the cohort entry trigger + added
the quiet settings door ("your medication" row in the program
section, value = her shot day; opens the same RegimenSheet) —
visible to all because mid-journey starts are unsignaled.
· Reconciliation spec (S3, build-ready): one-screen confirm
("your care team has you on [regimen]. does this match?") —
confirm links her record via derivedFrom and retires it from
primary display (history intact); "not quite" files a structured
mismatch to the care team's queue. Never silent overwrite, never
deletion. · Tradeoffs: one more settings row for never-med users
(quiet, factual). · Open: none.

**FR3 — Daily Supports: the architecture stands.** · Previous:
D7 — supplements never co-equal; one collapsed supports line;
protein foregrounded. · Refinement question: does a no-medication
user need an editable supports experience to avoid an empty
medication tool? · Evidence + finding: NO EMPTY STATE EXISTS —
the medication row composes only on dose days of an existing
plan, and the sheet opens only from that row or the settings
door; a never-med user sees no medication surface at all. Building
a supports rail to fill a state she never sees would ADD the
burden the adherence evidence warns against (supplements =
highest-forget, lowest-consequence class; treatment burden drives
our demographic out). · Implementation: none (deliberate).
RegimenPlanRecord already models supplements for the day the
clinic configures them; the one consumer-side candidate — "what
do you already take?" asked ONCE at intake, feeding pull-only
records — is filed under Stage A onboarding for founder review,
not built. · Tradeoffs: no supports surface to demo; correctness
over surface area. · Open: whether Stage A includes the
supports-intake question.

**FR4 — The medication register: clinical, never cute (resolves
F2).** · Previous: F2 open (hearts/stickers on protocol
surfaces); medication row wore the shared pastel disc, dose voice
said "then it's kept," acks wore hearts. · Refinement: no hearts,
no reward language, no playful stickers, no celebration —
Apple-Health-grade restraint; everything non-medication stays
warm. · Evidence: NN/g tone study — on serious content the
playful variant rated LESS trustworthy (trust explained 52% of
desirability vs 8% for friendliness); Apple Medications' whole
reward is the record ("Taken · 8:04", three verbs, no streaks, no
praise); premium portals are warm in the service layer, verbatim
in the medication layer; streak/guilt mechanics import anxiety
and medication streaks punish clinically legitimate pauses;
split-register law: same bones, ornament SUBTRACTED (Apple Health
hosts Cycle Tracking soft + Medications plain in one grammar)
[live]. · Implementation: hairline-outline disc, ink diagram
glyph, no fill (the absence is the signal); dose voice → "your
dose day" (fact, no reward verb); post-mark note = the timestamp
("taken · 8:04 pm" — the record IS the reward); mark haptic →
the quietest deliberate tap (pen tick, not applause; crossOff
celebration reserved for warm rows); rose removed from every
medication surface (dose/sit words + RegimenSheet select by
ink-contrast, captions cocoa); sit acks lose hearts ("noted.
mild plates + fluids tomorrow"); privacy line once, in the sheet
("only you see this. never named in notifications.");
MarkAsDoneSheet medication line fixed + de-warmed ("tap below to
record today's dose."). Warm surfaces untouched: hydration,
feeling words, tonight plan, plates, the day-seal silk (the DAY's
moment, not the med's). · Tradeoffs: the dose verb stays "mark"
(D9's one-verb-per-action) over Apple's "log" — log belongs to
nothing in our vocabulary and food owns "add"; states adopt
taken/skipped grammar. · Open: none.

**FR5 — Every ringed row answers "why is this here today."**
· Previous: because-clauses on the lead, promotions, stale weigh,
hydration. · Refinement: Home's rows read as care reasons, not
feature doors. · Implementation: BrandVoice gains
`weighInCadence` ("the trend reads the week, not the day" /
keeping: "the weekly band check. 30 seconds") and
`keystoneProteinAnchor` ("protein still anchors the day" — the
demoted dose-day keystone names its purpose); offered rows
already carry "· if it fits today". · Tradeoffs: none; grammar
untouched. · Open: post-refinement copy review on-device.

**FR6 — Onboarding: direction confirmed, nothing changed.**
· Stage A stands (founder-gated). Compatibility note appended:
the shot-day beat writes authority="self" records that the FR2
reconciliation moment supersedes cleanly — the intake is already
shaped for the clinician future. Detailed names/doses stay OUT of
intake (research: her words + optional structured strength seams
are sufficient; a drug-database picker is a Request-shaped burden
the consumer app must never carry).

## Founder refinements (2026-07-29, third brief — think from the clinic first)

**FR7 — The clinic-first principle becomes a standing document.**
· Previous: the mirror lived implicitly across 03/04. · Refinement:
imagine the clinician dashboard BEFORE any patient surface; the
patient UI renders from clinician configuration, never hardcodes
future clinical logic. · Evidence: the configure-vocabulary
converges across Alnu/Healthie/Prevounce/Canvas/Elation (protocol
· population · regimen · threshold · cadence · ask · content ·
escalation · goal · supports); Alnu ships the render-from-config
patient companion in our exact category; Canvas's trigger →
compute → recommendation-card is CarePlanEngine's shape; the
alert budget is the survival law (2-3 week clinician tune-out,
~70% ignored alerts, personalized baselines cut false alerts
60-80%) [live]. · Implementation: `07_CLINIC_MIRROR.md` — the
ladder mapped to objects, the render-rule audit (config-driven /
static-with-seam / deliberately patient-owned), the monitor-side
S3 anchors (status-token roster, exception queue, the guardrail
sentence, alert-budget law). · Tradeoffs: none — documentation
that keeps the future honest. · Future: every new patient surface
adds its row to the mirror before it ships.

**FR8 — Supports: policy object, observational render, protein
stays the only tracked number (supersedes FR3's do-nothing with
a seam, not a surface).** · Previous: FR3 — nothing built (no
empty state exists). · Refinement question: "Supports," not
"Supplements" — the clinic-configured adjunct layer. · Evidence:
the four-society advisory operationalizes exactly this layer
(protein 1.2-1.6 g/kg / 80-120 g/d absolute + supplemental
protein endorsed; gradual fiber + magnesium titrated for
REGULARITY — not sleep, where evidence is borderline-
observational; proactive vitamin D/B12/MVI against documented
GLP-1-era deficiencies; meal replacements carry the strongest
RCTs, OPTIWIN 12.4% vs 6.0%, DROPLET −10.7 vs −3.1 kg — and are
therefore clinician-prescribed programs, never app-originated);
creatine+GLP-1 has NO RCT (narrative extrapolation only — a
clinician invitation, an indefensible app claim); pill-marking is
burden without outcome (MedISAFE-BP: +0.4 self-report, zero BP
effect); FTC applies the same substantiation standard to every
health claim regardless of wellness framing [live].
· Implementation: `CareProtocol.supports: [SupportItem]`
(authored data, kind + note; consumer default EMPTY — nothing
renders; seed updated). The S3 render: at most ONE attributed
observational line ("your care team's plan includes…"), tap for
the clinician's rationale, never a pill-check row. Protein is
deliberately excluded from the list: it is the one TRACKED
support and already lives in ProteinPolicy riding food-log data.
· Tradeoffs: no supports surface to demo (correct: for the
org-null tenant there is nothing true to render). · Future: the
dashboard's Supports authoring step writes these rows; the
consumer app never originates an adjunct claim.

**FR9 — Medication feels like care, not a feature (the §4 lens,
verified).** · Evidence + verdict: structurally achieved —
medication has no tab, no tools-rail door, no becoming spread,
no share surface; it composes into the day as the dose-day lead
or does not exist; its only "place" is the row's own sheet plus
the quiet settings bridge door (kept: medication starts
mid-journey). The clinic mirror (§4) is the standing check
against future module-shaped drift. · Implementation: none
required beyond the mirror. · Open: none.

**FR10 — Stage A shipped (2026-07-29).** F3's recommendation
executed as specced (08_STAGE_A): contract at arrival, verb law
through the intake, 5-7% educational milestone, shotDay (clinical
register, current-cohort only, skip first-class), supports
single-ask (intake fact; recommends nothing; renders nothing),
dormant typed clinic door, authority-guarded completion handoff.
The reveal↔runtime agreement holds by construction: the reveal
reads the same keys/cohort the served-protocol runtime composes
from, and the medication rail renders only from her actual
answer. Copy decision recorded: the supports question stays —
in-sequence testing read it as caring, not burdensome (one
screen, one skip). Founder-open: none new; F1 remains.

## Postponed (named, not dropped)

- S2 server-hydrated protocol/content; S3 care-team surfaces
  (visit-prep packet is the bridge candidate); S4 tenancy +
  BrandVoice re-voicing.
- HIPAA/BAA, FHIR/EHR interop, clinical governance org, SaMD
  legal opinion — required before any external "medical-grade"
  claim or clinic partnership; non-app tracks (medical-grade spec
  out-of-scope list stands).
- v7 phase 3 (first-move letters, comeback tiers, celebration
  ladder) + phase 4 (chart grammar port, heart budget, JeniHaptics
  semantic layer) — queued behind the platform foundation.

## Needs founder

- **F1:** whether her own entered medication name may render on
  her private surfaces (display-only; never notifications, never
  app-authored) — compliance-reviewed recommendation to follow in
  04 after research lands.
- **F2:** RESOLVED by the 2026-07-28 refinement brief → FR4:
  medication surfaces are clinical (no hearts, no stickers, no
  celebration); every non-medication surface keeps its warmth.
- **F3:** onboarding evolution — RESOLVED into a recommendation:
  Stage A reframe over the v5 machine (contract sentence,
  expectation anchor, shot-day beat + regimen handoff,
  supplements single-ask, verb-law sweep), full design +
  staging in `06_ONBOARDING.md`. v5 is founder-reviewed law, so
  Stage A awaits the founder's go; no onboarding code changed
  this pass.
- (open — entries append as decisions surface them)
