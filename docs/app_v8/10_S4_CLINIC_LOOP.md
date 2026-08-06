# app v8 — S4: THE FIRST REAL CLINIC LOOP (plan + law, 2026-07-29)

One legitimate clinic actor connects to one consenting patient,
reads her canonical record, assigns care, and that exact care
becomes her lived daily plan — provenance preserved, consent
explicit, isolation server-enforced, access reversible. Built
VERTICALLY: one clinic · one clinician · one patient · one packet
· one protocol · one care-team regimen · one reconciliation · one
correction · one revocation · one live proof. This document is
written before code; it records intent, constraints, and
invariants — not just outcomes.

Companion evidence: three research lanes ran 2026-07-29 (clinic
workflow reality; PGHD/consent/correction law; Supabase authz +
audit patterns). Key citations inline as [lane-note]; the standing
v8 docs (00/03/04/07/09) remain law.

## 0. The wedge, restated

A small physician-led obesity clinic managing GLP-1 patients.
The clinic's real calendar is the titration calendar (dose steps
~q4wk); review happens at VISIT PREP, not in an ambient feed
(portal messages +153% 2020-25; alert-based review is the
specialty-society-endorsed pattern — HRS 2023) [lane 1]. The
dashboard therefore optimizes one moment: a <2-minute pre-visit
read of a 28-day record, plus the assignment act. No population
dashboards, no risk scores, no streams.

## 1. Core platform law (restated as S4 invariants)

- The clinician AUTHORS care (protocol, regimen, schedule,
  status, follow-up). The patient LIVES care (accept, consent,
  mark, report, request correction, revoke). Jeni ORGANIZES and
  renders care.
- ONE canonical record system. Clinic access is a set of grants
  over the SAME rows the consumer app writes — never a parallel
  chart.
- The patient can never mutate a care-team regimen's name /
  strength / schedule (server-enforced now, not just client
  guards). The clinician can never rewrite patient-entered
  observations or relabel provenance.
- Access ≠ treatment. Revocation kills future access server-side;
  it never silently discontinues medication or rewrites history
  [45 CFR 164.508(b)(5): revocation is prospective-only — lane 2].
- Nothing sensitive on lock screens or in analytics. No
  medication names, strengths, weights, or symptom words leave
  the record system.
- Not an EHR, not e-prescribing: we record the care plan the
  clinic tells the patient; the prescription lives in their
  EHR/pharmacy. UI copy never says prescribe / order / Rx /
  "monitored in real time" [lane 1].

## 2. Object model (additive migration `20260730_s4_clinic_loop.sql`)

New tables (all `to authenticated`, `(select auth.uid())`
wrapping, indexed on every policy column):

```
organizations        id uuid pk, name, slug unique, created_at
org_members          (org_id, user_id) pk, role owner|clinician|staff,
                     status active|disabled, display_name,
                     credential_label?, created_at
patient_invitations  id uuid pk, org_id, created_by, code_hash (peppered
                     sha256; raw code NEVER stored), patient_label
                     (clinic's own name for the patient), status
                     pending|accepted|cancelled, expires_at,
                     accepted_by?, accepted_at?, created_at
care_relationships   id uuid pk, org_id, patient_id, status
                     active|revoked|ended, patient_label,
                     invitation_id, established_at, ended_at?,
                     follow_up_on date?, reviewed_at?,
                     unique active (org_id, patient_id) [partial]
protocol_assignments id uuid pk, org_id, patient_id, protocol_id →
                     protocols, status active|replaced, assigned_by,
                     assigned_at, replaced_at?
correction_requests  id uuid pk, org_id, patient_id, regimen_plan_id,
                     category name|strength|schedule|not_taking|other,
                     note? (≤200 chars, sensitive — never in analytics
                     or generic logs), status open|accepted|dismissed,
                     resolution_note? (≤200), resolved_by?, created_at,
                     resolved_at?
care_audit_events    id bigint identity pk, occurred_at, org_id?,
                     actor_id, actor_role patient|owner|clinician|staff|
                     system, action (invitation.created, invitation.
                     accepted, relationship.activated, consent.granted,
                     consent.revoked, packet.viewed, chart.opened,
                     series.viewed, protocol.assigned, protocol.replaced,
                     regimen.assigned, regimen.updated, regimen.ended,
                     reconciliation.confirmed, correction.requested,
                     correction.resolved, relationship.review_set …),
                     patient_id?, target_kind?, target_id?, outcome,
                     meta jsonb (ids/kinds/counts ONLY — never values,
                     names, symptoms, weights)
visit_packets        id text pk ("<userId>-<orgId>"), user_id, org_id,
                     payload jsonb (the canonical VisitPacket projection,
                     serialized BY the patient app — S3 logic is never
                     reimplemented server-side), window_start, window_end,
                     generated_at, app_version
invitation_attempts  (user_id, attempted_at) — rate-limit ledger
```

Extended tables:

```
consent_grants   + lookback_days int?    (28 | 0; null = legacy row)
regimen_plans    patient policies TIGHTENED server-side:
                   update/delete only where authority='self';
                   insert only with authority='self' AND org_id IS NULL
                   AND source_protocol_id IS NULL
                 (clinician writes exist ONLY through definer RPCs)
protocols        read-all policy REPLACED: org_id IS NULL (public
                 defaults) OR is_org_member(org_id) OR an active
                 assignment for auth.uid() — tenant configs stop being
                 world-readable; consumer default stays public
consent_grants   patient direct insert/update policies constrained to
                 org_id IS NULL rows (the S3 dormant preference);
                 org-scoped grants/revocations ONLY via audited RPCs
```

## 3. Authorization law

- Helpers in unexposed schema `private`, SECURITY DEFINER,
  `set search_path = ''`, EXECUTE revoked from public/anon in the
  same transaction [Supabase perf + definer guidance — lane 3]:
  `is_active_member(org)`, `has_org_role(org, roles[])`,
  `has_consent(patient, org, scope)` (requires ACTIVE relationship
  AND active grant — live lookup, never JWT claims, so revocation
  and disablement are instant), `consent_window_start(patient,
  org)` (established_at − lookback_days), `log_care_event(…)`.
- Patients keep direct RLS CRUD on their OWN rows (self-access is
  not a disclosure). EVERY clinician read of patient data goes
  through a definer RPC that checks role + relationship + scope,
  writes an audit event, and returns an explicit projection —
  Postgres has no SELECT triggers, so the RPC chokepoint is the
  only honest way to audit reads [lane 3]. There are NO direct
  clinician SELECT policies on patient charts.
- RPC surface (all definer, all audited):
  patient-side: `preview_care_invitation(code)`,
  `accept_care_invitation(code, lookback_days, scopes[])`,
  `revoke_org_consent(org, scope?)` (null = all),
  `submit_correction_request(…)`, `confirm_regimen_reconciliation(…)`
  clinic-side: `create_organization(name)` (non-anonymous accounts
  only), `add_org_member(…)`/`set_member_status(…)` (owner),
  `create_patient_invitation(label)`, `cancel_patient_invitation(id)`,
  `list_patients()`, `open_patient_chart(patient)`,
  `get_visit_packet(patient)`, `get_patient_series(patient)`
  (kind-whitelisted observations: doseTaken · sitCheck · hydration
  + weights; NEVER journalNote / feeling / tonightPlan / daySealed;
  window-clamped by lookback), `assign_protocol(patient, protocol)`,
  `assign_care_regimen(…)`, `update_care_regimen(…)`,
  `end_care_regimen(…)`, `resolve_correction(…)`,
  `set_patient_review(patient, follow_up_on?, reviewed?)`.
- F1 masking: clinicians NEVER see a self regimen's displayName.
  `open_patient_chart` returns for the self plan only
  {exists, anchor_weekday, started_at} — schedule facts, never her
  words. Enforced by the explicit projection (no policy on the
  base table can leak it).
- Role gates: regimen + protocol + correction resolution + review
  status = clinician|owner ONLY. Staff = invitations, roster,
  packet/chart read. (Founder gate "staff creating regimens"
  is therefore never crossed; AMA order-entry guidance and CA MA
  scope law back the conservative split [lane 1].)
- Audit is append-only: API roles get INSERT/UPDATE/DELETE revoked;
  inserts happen only inside `private.log_care_event`; an
  UPDATE/DELETE-raising trigger is the belt. Patient sees her own
  audit rows (accounting-of-disclosures for free); org members see
  their org's [FHIR AuditEvent / ASTM E2147 shape — lane 3].

## 4. Invitation law

Front-desk-real: the clinic hands the patient a short code.
8 chars Crockford Base32 (no I/L/O/U), 40 bits from
`gen_random_bytes`, displayed `XXXX-XXXX` [≥20-bit NIST floor +
throttling — lane 3]. Stored ONLY as peppered SHA-256 (pepper in
Vault; leaked table ⇒ useless hashes). 72h expiry. Single-use
under `FOR UPDATE` row lock. Attempt cap: 5 failures / 15 min per
caller (+ ~20/day), enforced inside the RPC; failures are generic
("that code didn't work") — no oracle for which part failed.
`preview_care_invitation` shows the patient WHO is asking (org
name, her clinic-entered label, expiry) BEFORE any grant. No
fuzzy identity matching, no email auto-connect, no silent account
transformation. Cancellation: clinic cancels a pending invitation;
accepted ones are inert (single-use).

## 5. Consent law

Scopes are separate grants (SMART-style thinking, internal
enforcement) [lane 2/3]:

- `visit_packet_view` — the clinic may open her published packet.
- `observation_view` — the clinic may open underlying series
  (dose marks, sit-checks, hydration, weigh-ins) within lookback.
- `care_assignment` — the clinic may assign/update protocol +
  care-team regimen and resolve corrections.
- (future scopes — messaging etc. — remain UNGRANTED and unnamed
  in UI.)

The accept screen carries the 164.508 elements in plain language
[lane 2]: WHO (clinic name), WHAT (each scope as a labeled toggle
she can flip off before confirming), the LOOKBACK chooser
("the last 4 weeks" default | "from today only" — stricter than
the Apple category-wide norm, stated as a trust line), DURATION
("until you disconnect"), REVOCATION (one obvious place, takes
effect immediately, forward-looking), and the mandatory
NOT-MONITORED sentence: her clinic reviews at visits — nothing
here is watched in real time; urgent concerns go to the clinic by
phone or to emergency services [ONC PGHD Practical Guide 2018 —
lane 2]. Consent rows are versioned by append (grant row +
revoked_at; re-grant = new row). Nothing is active by default;
the S3 dormant `visit_packet_sharing` preference stays what it
was and gates nothing new.

The packet the clinic sees is the one SHE publishes: the patient
app serializes its canonical S3 `VisitPacket` (now Codable) into
`visit_packets` whenever scopes+relationship are active (launch +
packet-view), window clamped to her lookback choice. S3's
projection logic remains the single implementation; the empty /
sparse states ship as-is (packet function survives limited
history — §9 of the brief).

## 6. Assignment law

**Protocol** — the S2 resolver is the mechanism (a clinic IS a
different `protocols` row). S4 adds the missing indirection:
`protocol_assignments` names which row a patient resolves.
Patient-side `CareProtocolStore.hydrate()` resolves: active
assignment → that protocol row → decode → `isClinicallySane`
whole-or-reject → apply + last-good cache; else `jenifit.default`.
Malformed/unsafe payloads change NOTHING (S2 gate untouched);
the failed update is visible in the store's cache state. No
freeform protocol composer: the dashboard ASSIGNS approved
existing rows (alpha: the org's seeded protocol + the public
default), showing version + published_at + the patient-facing
elements read-only. Replacement = new assignment row, old one
`replaced` (auditable).

**Care-team regimen** — the smallest unambiguous record
[Joint Commission EP4 floor + Apple/MyChart grammar + FDA 2024
mg-confusion alert — lane 1]:

- patient-facing medication name (assigned; renders where she
  reads it, never in notifications)
- dose per administration in **mg only** (`strength_value` +
  `strength_unit='mg'`; the alpha REFUSES units/mL — the
  documented 5-20× overdose mechanism lives in that conversion)
- weekly anchor day (ISO; the field every engine reads)
- effective/start date (defines the titration week)
- optional one-line instruction (≤140 chars, e.g. "evening,
  thigh or abdomen ok")
- assigning actor + org + timestamps (provenance)
- status via `started_at`/`ended_at` (end, never delete)

Explicitly NOT modeled: route/form, refills, pharmacy, sig codes,
titration futures (each step = a new confirmed update),
interaction checking, PRN logic. One titration step per confirmed
state; version history = audit trail. Writes stamp
`authority='care_team'`, `org_id`, `source_protocol_id?`; the
existing FR1 client guards become server law (patient RLS cannot
touch these rows).

## 7. Reconciliation law (FR2, now mechanics)

State machine per patient (derived, not stored):
`none` (no active care-team plan) → `needs_confirmation` (active
care-team plan; no reconciliation acknowledgment for its id) →
`reconciled`.

On first render of `needs_confirmation` (Today, once per launch,
deferrable): one calm sheet in the clinical register —
"from your care team": the assigned line (name · X mg weekly ·
<day>s), "your earlier records stay in your chart", "future
check-ins follow this plan", and two acts: **looks right**
(ends the active SELF plan if one exists — history + observations
intact under its id; writes a `careEvent` observation
`regimen_reconciliation {action: confirmed, careTeamPlanId,
priorSelfPlanId?}`; audited server-side) and **something's off**
(opens the correction sheet; the care-team plan still composes —
a disputed plan is a flagged plan, not a deleted one; the
reconciliation stays pending-with-flag until the clinic
resolves). Anchor-day agreement/difference is stated plainly
("this matches the rhythm you recorded" / "check-ins follow
<day>s now"). Never: silent overwrite, deletion, relabeling,
double-active ambiguity (the active plan resolver prefers
care_team when both exist — deterministic), or re-entry of
history. No database or merge vocabulary. No medication advice.

Future dose marks join the care-team regimen id the moment it is
the active plan (the existing `regimenId` stamping needs zero
change — provenance follows the resolver; unit-tested).

## 8. Correction law (164.526-shaped [lane 2])

Patient (from the regimen sheet, care-team plans only):
categories `name looks wrong` / `strength looks wrong` /
`schedule looks wrong` / `this isn't the medication I'm taking` /
`something else` + optional ≤200-char note (stored as sensitive
clinical content on the request row ONLY; excluded from
analytics, generic logs, and audit meta; labeled non-urgent with
the not-monitored line restated). A request never mutates the
regimen. Clinician: accept → updates the regimen through the
normal audited update path + closes the request; dismiss →
requires a brief plain-language reason. Patient sees the outcome
state in the regimen sheet ("resolved by your care team · jul 30"
/ the dismissal reason). Chain is append-only; nothing disputed
is deleted. Staff may VIEW requests; only clinicians resolve.

## 9. Revocation law

One obvious place (the care-team surface in settings). Revoke =
`revoke_org_consent` → all (or one) scope rows get `revoked_at`;
audited. Effects, immediately and server-side: every clinic RPC
denies (live `has_consent` check); no new packet publishes; no
clinic write lands. Preserved: audit history, her observations,
care-team provenance on historical rows, the assigned regimen's
CLINICAL status (still her plan — the app states "your clinic's
access is off — your plan is unchanged; treatment questions go
to your clinic directly"). The relationship row flips `revoked`
when she disconnects entirely (scope-revoke vs disconnect are the
same surface, two depths). Re-connection later = a fresh
invitation (no zombie access).

## 10. Patient-side rendering law

- No clinic version of Home. The care-team regimen composes
  through the EXISTING runtime (dose-day lead, evening ask,
  packet medication section — all already read the active plan).
- The regimen sheet grows a care-team FACE: assigned name ·
  "X mg weekly" · anchor day · "recorded by your care team ·
  <date>" · instruction line · "something look wrong?" door.
  No weekday menu, no remove, no editing. Clinical register:
  ink, hairlines, no hearts/stickers/rose/celebration.
- The settings door "your care team" (program section, beside
  "your medication"): disconnected = "connect with a code";
  connected = clinic name, scope summary, lookback line, revoke.
- `CareProtocol.supports` renders for the FIRST time when a
  clinic-assigned protocol carries items: at most ONE attributed
  observational line on Today ("your care team's plan includes
  …", tap → the clinician's note). Never a pill-check row (FR8).
- In-app update state only (no push): a changed care-team
  assignment surfaces as a quiet "your care plan was updated ·
  review" line that opens the sheet. Notification payloads never
  gain medication content (nothing new scheduled at all in S4).
- Org-null consumers: every S4 surface gates on a live
  relationship; the only always-visible addition is the settings
  door row (mid-journey connects are unsignaled, same logic as
  the medication door). Home/onboarding/packet untouched
  otherwise; 381 existing tests must stay green unmodified.

## 11. The clinician surface (alpha)

Smallest production-capable choice that fits the stack: a static
web app (Vite + React + TypeScript) in `clinic/`, talking
DIRECTLY to the existing Supabase project with `@supabase/
supabase-js` under the publishable key + RLS (the sanctioned
browser pattern [lane 3]); every privileged action is one of the
§3 RPCs. No server of our own, no service-role key anywhere
client-side, strict CSP meta, zero third-party UI kit, zero
analytics. Deployable as static files later; runs on
`vite dev/preview` for the alpha.

Screens (exactly five): sign-in → patients (roster) → patient
detail (relationship + consent + packet + regimen + corrections +
recent audit) → assign (protocol pick / regimen form as focused
sheets) → org (members, invitations). Design law per the brief
§22: calm, work-oriented, editorial hierarchy, provenance-aware;
serifs only at the masthead; tabular numerals for data; hairline
rules over cards; no gradients, no badges-as-decoration, no
celebration language; empty states written like a colleague, not
a mascot. The register is jeni's clinical layer at desktop
density — recognizably the same product family, unmistakably a
work tool.

## 12. Security matrix (probed live, scripted)

`scripts/s4_security_probe.py` runs the §20 matrix against the
dev project as real principals (anon key only): wrong-org reads,
guessed patient ids, expired/replayed/cancelled codes, attempt
throttling, no-consent and partial-scope denials, disabled
member, patient forging care_team rows / consent rows / audit
rows, packet access without packet scope, assignment without
assignment scope, self-name leak through every clinic-facing
RPC, cross-tenant joins, org-null behavior, append-only audit.
The probe is repeatable evidence, not a one-off.

## 13. Test law

New iOS units: reconciliation state machine + confirm/flag
actions + self-plan end; dose-mark regimen join with dual active
plans; care-team hydrate apply (server-authoritative updates,
ended plans land); packet publisher gating (scopes + lookback
clamp + payload shape); protocol resolution via assignment +
fallback; regimen sheet face selection; care-team connection
cache sign-out sweep. Dashboard: Playwright E2E for the five
screens against dev data + unit tests for pure helpers. SQL: the
live probe (§12). The 381 existing tests run untouched; UI legs
solo per house law.

## 14. Phases

- **A — identity**: migration (schema §2 + helpers + RPCs core:
  org/member/invitation/accept/consent) → push → probe part 1
  (isolation, invitation lifecycle, consent round-trip).
- **B — read**: visit_packets + publisher (iOS) + roster/detail/
  packet RPCs → dashboard sign-in/roster/detail/packet → probe
  part 2 (scopes) → audit events verified.
- **C — assign**: protocol_assignments + regimen RPCs + org
  protocol seed → dashboard assign surfaces → iOS hydration
  (assignment-aware CareProtocolStore + server-authoritative
  care_team regimen apply + supports line + update state) →
  invalid-payload fallback proof.
- **D — reconcile**: the FR2 sheet + state machine + self-plan
  retirement + dose-join tests.
- **E — correct + revoke**: correction RPCs + sheet + dashboard
  queue → revocation surface + server denial proof → full live
  E2E (§26's 20 points) → security matrix complete.

Each phase builds green before the next; commits per phase;
docs update at decision boundaries.

## 15. Explicitly not in S4 (named seams)

e-prescribing/pharmacy anything; billing/minutes ledger (audit
rows are shaped to grow one); staff drafts-pending-signature
(AMA-legal, deferred for state variance); FormTemplate intake
(Stage B); clinic BrandVoice re-voicing (founder gate); push
notifications; messaging of any kind; multi-clinic per patient
(schema allows, product defers); packet history/versions beyond
current; protocol composer; population analytics; exception
rules beyond the packet's own generated flags; @supabase/ssr
cookie sessions for the dashboard (documented upgrade);
organization self-serve onboarding (org creation stays an
internal act).

## 16. Honest boundary (docs + founder)

JeniFit is a consumer app and not a HIPAA covered entity; this
clinic loop is a development alpha for internal/test use with
consented test data only — no BAA is in place, so no real clinic
may use it for patient care yet. We never claim "HIPAA
compliant" (there is no such certification; the FTC has fined
the claim itself [SkyMed 2021 — lane 2]). Before ANY external
clinic: BAA template + security-rule posture + breach process +
this audit trail reviewed. The FTC Health Breach Notification
Rule applies to the consumer side TODAY — no health data leaves
the record system for ads/analytics, ever.

Founder gates deliberately NOT crossed: lookback stays at the
conservative chooser; staff never author regimens; revocation
never auto-discontinues care; no medication names in any
notification; JeniVoice only; internal alpha only; no free-text
messaging (bounded correction note only, stored as sensitive);
no compliance claims; no new data processors; assignment is
care-plan recording, never prescribing.
