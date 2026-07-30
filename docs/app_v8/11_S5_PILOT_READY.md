# app v8 — S5: PILOT-READY JENI CARE (plan + law, 2026-07-29)

S4 proved the technical clinic loop. S5 turns that internal
development alpha into a product a legitimate obesity-clinic
operator can encounter, understand, evaluate, and pilot — without
the product feeling like a prototype or claiming more than it is.
This document is written before code; it records the reconstructed
state, the decisions, and the law of the pass. Companion evidence:
three research lanes ran 2026-07-29 (name-risk; pilot/BAA
operations; clinician-product presentation), synthesized in §4-§6.

## 0. Reconstructed state (verified this session, before any change)

- Branch `feat/app-v2`, clean tree, HEAD `9bbf464` (S4 shipped
  record). All of `docs/app_v8/00-10` + `docs/STATE.md` read.
- **Suites, run live before touching anything:** iOS **396/396**
  units on the QA sim; clinic Playwright E2E **1/1** (real
  dashboard → live RPCs → server-side verify); S4 security probe
  **61/61** with `--skip-expiry` (the 62nd, invitation expiry, was
  proven in the S4 session). `supabase migration list` confirms
  `20260729180000_s4_clinic_loop` applied to the linked project.
- **The environment fact that shapes S5:** there is ONE Supabase
  project (`mtecqvykyeueumdynatd`, "absmaxxing") and it is
  simultaneously the shipping consumer app's backend AND the S4
  clinic alpha's backend. The dashboard (`clinic/src/supabase.ts`),
  the Playwright fixture, and the security probe all hard-code its
  URL + publishable key. There is no staging project (the org's
  second project is an unrelated app), no env parameterization, no
  environment identity anywhere.
- **Dashboard state:** five screens, branded lowercase
  "jenifit care", solid clinical-editorial register, light+dark,
  keyboard-focus visible. Gaps against pilot readiness: org
  creation is open self-serve to any email account; no member
  removal / role-change UI (server RPCs exist); no password reset;
  no environment identity; no support door; no first-run guidance;
  no error reporting of any kind (by design, zero analytics).
- **Role law state:** `owner|clinician|staff` on `org_members`;
  staff correctly cannot author care (S4-4), but **owner
  automatically has clinical assignment authority** — S5 role law
  requires clinical authority to be explicit, not implied by
  administrative role.
- **iOS patient side:** care surfaces already speak "your care
  team" / "your clinic" (no product-name leakage); connection /
  consent / reconciliation / correction / revocation sheets shipped
  and tested; `--uitest-care-*` QA doors live.
- **Public surface:** none. No clinician website exists.

## 1. Brand law (the naming decision)

Hierarchy, fixed:

```
Jeni Health                    — the company / platform umbrella
└── Jeni Care                  — the clinician platform
    └── Jeni                   — the patient experience
```

- Clinician website + dashboard wordmark: **Jeni Care** (set in the
  product's editorial lowercase as `jeni care`), with the umbrella
  line "by Jeni Health" where a company signature is appropriate
  (site footer, sign-in footer, legal lines). Never "JeniFit Care",
  never "JeniFit Clinic".
- Patient-facing surfaces keep saying **Jeni** / **your care
  team**; they name "Jeni Care" only where identifying the
  connected service is necessary (nowhere today — verified).
- One name per surface; the three-level hierarchy is never recited
  in product copy.

### 1.1 Name-risk scan (research lane, 2026-07-29 — NOT clearance)

Recorded in §4 below after the lane completed. Verdict: no obvious
blocking conflict found for "Jeni Care" as a US digital-health
clinician product; phonetic neighbors (esp. Jenny Craig in the
weight category) and the crowded "care" suffix mean counsel must
run a real knockout + USPTO search before any paid marketing or
App Store rename. This session uses Jeni Care as the working
public name per the brief.

### 1.2 Visible-name migration map

| Layer | Today | S5 action |
|---|---|---|
| Clinician dashboard wordmark/title/copy | jenifit care | **rename now** → jeni care |
| Clinician website | (new) | **born as** Jeni Care |
| Patient app display name / App Store | JeniFit | **unchanged** (rename = founder + re-onboarding cost; existing v1.2+ plan stands) |
| Patient in-app care copy | "your care team", "the jenifit app" (1 dashboard string) | patient app untouched; dashboard string → "the Jeni app" phrasing kept product-neutral ("their app") |
| Bundle id / Xcode project | com.bk.plankAI / plankAI | **unchanged** (stable internal; founder-gated rename plan already exists) |
| Supabase project/tables/RPCs (`care_*`, `jenifit.default` protocol id) | jenifit-flavored ids | **unchanged** (stable internal identifiers; renaming live keys/ids is risk without benefit; `jenifit.default` documented as an internal id, not a brand surface) |
| Repo dir `clinic/` | clinic | **unchanged** (internal) |
| Legal entity / domains (jenifit.app) | founder-owned | **founder action** (domain for Jeni Care site; entity naming; trademark counsel) |

## 2. The pilot wedge (unchanged, restated)

Small physician-led obesity clinic · GLP-1 follow-up · patients
already under the clinic's care · between-visit adherence +
observations · visit prep · protocol/regimen communication ·
correction + reconciliation. The working product claim:

> **Jeni Care shows your clinic what happened between visits —
> and carries the plan you assign back into the patient's daily
> app.**

Explicitly not: an EHR, e-prescribing, RPM billing infrastructure,
monitoring, diagnosis, autonomous care.

## 3. The pilot model (configurable defaults, founder-adjustable)

One clinic · one designated owner · up to **5** clinic users ·
up to **20** invited patients · **12 weeks** · no fees · no
automated prescribing · no payment/insurance · no emergency
monitoring · no guarantee of clinician review · approved workflow
only. (Numbers live in the pilot handbook + agreement draft as
parameters, not in product copy.) Responsibilities, support
boundary, escalation, start/end, termination, export/return, and
feedback cadence are specified in `docs/app_v8/pilot/PILOT_MODEL.md`.

## 4. Name-risk findings (lane synthesis — NOT clearance)

A search-engine + aggregator scan (2026-07-29; USPTO/Justia blocked
automated queries, so "no exact mark" is indicative only):

- **"Jeni Care"** — no exact-string US company/mark surfaced; the
  domains jenicare.com/.health are unregistered. Two adjacencies to
  flag for counsel: **JENCARE** (live registered mark, ChenMed senior
  medical centers, class 44 — one letter off, medical services) and
  **jenni.care** (an active US digital-health patient AI companion —
  phonetically identical). Neither is a knockout; together they make
  Jeni Care the riskier of the two names.
- **"Jeni Health"** — no exact-string company/mark; domain free.
  Exposure is phonetic, mainly via **"Jenny Health"** (a Jenny-Craig-
  orbit weight-coaching app).
- **Phonetic neighbor (the real risk):** spoken, "Jeni" = "Jenny," and
  **Jenny Craig** (Wellful) is an active weight-loss brand now
  marketing GLP-1 companion products — the exact consumer category.
  The B2B clinician channel mutes this for Jeni Care; the closest
  approach is the consumer patient app named "Jeni" in weight care.
- **Patient app "Jeni":** a live App Store app named exactly "Jeni"
  sits in Medical (a medication reminder) — Apple's name-uniqueness
  will likely force a "Jeni: …" suffix.

**Verdict:** no obvious blocking conflict for **Jeni Care** as a US
digital-health clinician product → proceed with it as the working
public name per the brief. **Founder gate before paid public
marketing or an App Store rename:** counsel runs a full USPTO knockout
(word + phonetic, classes 9/42/44), state + common-law search, and a
specific Jenny Craig (Wellful) portfolio review. Documented, not
cleared. (No blocking conflict was found, so this session did not stop
— but the site ships behind the founder's access gate until counsel
clears it.)

## 5. Pilot research synthesis (lane)

The operational reality S5 is built against (full detail + citations
in `pilot/VENDORS.md`, `pilot/METRICS.md`):

- **BAA trigger:** Jeni Health becomes a business associate at the
  first real patient (not the first dollar); a written BAA with the
  clinic AND every PHI subprocessor is then mandatory. → S5 keeps
  real data off the dev project entirely and gates the pilot on the
  BAA chain.
- **The short critical path:** the only processor that would hold PHI
  in the clinic loop is **Supabase** (BAA on Team plan $599/mo or
  Enterprise + HIPAA add-on ~$350/mo; project marked High Compliance;
  PITR + SSL + network restrictions + connection logging). No AI
  provider touches the loop (the packet is deterministic); the
  dashboard/site carry no PHI (browser → Supabase direct). So the BAA
  chain is Supabase + the clinic — small and clearable.
- **Minimum credible posture (1 clinic):** MFA on every admin surface,
  encryption in transit + at rest, RPC-only audited access (shipped),
  append-only audit + weekly review, PITR + one tested restore, an
  asset/data-flow map (VENDORS.md), access termination ≤24h, a named
  security official, and a dated risk analysis (HHS SRA Tool / NIST
  800-66r2). PHI-scrubbed telemetry until any error/email vendor has a
  BAA (S5's ops_events is structurally PHI-free).
- **What clinics ask for before a pilot:** a BAA, a short security
  one-pager or SOC 2 (no clinic-specific HECVAT exists), cyber + tech
  E&O (~$1M/$2M floor), and a bounded no-fee agreement with a
  conversion path. → `pilot/LEGAL_DRAFTS/` + the founder gate checklist.
- **Never say "HIPAA compliant"** (FTC/SkyMed treats the claim itself
  as deceptive); the consumer-side FTC Health Breach Notification Rule
  already applies today.
- **Measurement to convert:** feasibility + time-saved + trust, not
  engagement; SUS (68 avg; health-app ~76.6; EHR ~45.9) + NPS; the
  "<3-min packet review" claim is defensible against the ~2.9-min
  pre-visit EHR-review baseline.

## 6. Clinician-product presentation synthesis (lane)

From current credible clinician sites (Elation, Canvas, Healthie,
Alnu, Abridge, Virta, Omada, Prevounce, knownwell, SimplePractice):

- **IA that recurs:** workflow-specific hero → trust strip → problem
  framing → product-by-workflow (real screenshots) → who-we-serve →
  named-clinician proof / outcome numbers → security band → restated
  CTA. Jeni Care's site follows this, minus fabricated proof (no fake
  logos, testimonials, or outcomes — the honest gap at pilot stage).
- **Concrete heroes win** ("Primary care is hard enough. Your EHR
  shouldn't be." — Elation; "Remote care management done right" —
  Prevounce). Grandiose AI heroes only survive with heavy proof. →
  Jeni Care's hero is a workflow claim ("know what happened between
  visits"), not transformation.
- **No-BAA security wording, verbatim best practice (Alnu):**
  "Administrative, physical, and technical safeguards aligned with
  HIPAA," and a security page that states outright it "does not make
  certification claims" and shares status "through an appropriate
  security review." → Jeni Care's SECURITY_STATEMENT.md and site
  section adopt exactly this posture.
- **CTA norm for pilot stage:** conversation verbs ("Book a demo,"
  "Contact us," a named "Early Access"), never fake scarcity. → "Request
  a clinic pilot" + "pilot availability is limited."
- **Anti-patterns avoided:** "military-grade encryption," zero-
  screenshot product pages, fake urgency, dated proof under a modern
  claim, unverifiable absolutes ("all HIPAA standards").
- **Premium feel = restraint + evidence density**, not decoration. →
  the editorial serif + one plum accent + real captures, no gradients/
  orbs/stock, is the deliberate divergence from generic AI-SaaS.

## 7. Environment architecture (the S5 law)

Named environments, each with an identity the SERVER declares
(`private.config['environment']`) and clients verify:

| env | Supabase project | data | who |
|---|---|---|---|
| `development` | mtecqvykyeueumdynatd (today's only project; ALSO consumer prod — see honesty note) | synthetic/test only for clinic tables | engineers, QA sims, probe, E2E |
| `staging` / `pilot` | **a separate Supabase project — founder must create** (billing decision; provisioning runbook ships this pass) | fictional until BAA+gates, then pilot clinic data | founder demos; the pilot clinic |
| consumer production | mtecqvykyeueumdynatd | real consumer users (org-null) | the shipping app |

Honesty note: the consumer app's production database IS the
current development playground for clinic tables. That was
acceptable for S4's org-scoped, RLS-probed alpha; it is NOT
acceptable for a real clinic pilot. The pilot gate therefore
includes: create the pilot project, apply the migration chain,
set `environment='pilot'`, set `org_creation_mode='restricted'`,
rotate in its own keys, deploy a pilot-labeled dashboard build.

Mechanics shipped this pass:

- `care_environment()` RPC → `{environment}`; dashboard fetches at
  boot. Badge law: `development` and `staging` wear a quiet
  masthead token; `pilot`/`production` wear none (no dev artifacts
  in the visible pilot product).
- Dashboard config via `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`
  / `VITE_CARE_ENV` (`clinic/.env.development` committed for dev;
  `.env.pilot.example` documented). Build-time guard: a non-dev
  `VITE_CARE_ENV` pointing at the dev project ref FAILS the build;
  boot-time guard: server-declared env ≠ built-for env renders a
  hard misconfiguration banner.
- Probe + Playwright read `CARE_SUPABASE_URL`/`CARE_SUPABASE_ANON_KEY`
  env vars (dev defaults preserved).
- `scripts/care_env_provision.md`: the exact founder runbook to
  stand up staging/pilot.

## 8. Role law (S5-2)

Clinical assignment authority becomes explicit:
`org_members.clinical_authority boolean` — true automatically for
`role='clinician'`; **owners get it only if marked as clinicians**
(org creation asks; owners can set it per member); staff can never
hold it. All seven clinical gates (`assign/update/end regimen`,
`assign protocol`, `author org protocol`, `resolve correction`,
`set review`) move from `role in (owner, clinician)` to
`private.has_clinical_authority(org)`. Backward compatibility:
existing owner rows are grandfathered `true` in the migration
(documented; the alpha's owners acted as physician-owners), then
the S5 rule holds for every new membership.

## 9. Clinic administration (S5 minimum)

Dashboard "clinic" screen grows: member remove/disable +
re-activate, role + clinical-authority change (owner-only; the
last active owner is protected), invitation cancel (existed),
support + security contact lines, org identity + environment.
Password reset ships on sign-in (`resetPasswordForEmail` with an
env-correct redirect + in-app new-password screen). Org creation
leaves self-serve: `org_creation_mode` config gates it —
`restricted` (staging/pilot: requires a founder-issued
provisioning code) vs `open` (dev only, keeps probe/E2E
self-fixturing). NOT built: SSO, SCIM, departments, billing,
seats, custom permissions (named seams).

## 10. Demo mode

`organizations.is_demo` flag + `scripts/care_demo_seed.py` /
`care_demo_reset.py` (operator-local, service-role from env, NEVER
in clients; refuses non-demo orgs by flag + slug prefix; refuses
unknown project refs). Deterministic fictional clinic ("Sage
Metabolic Health" — fictional, no real-clinic name collision in a
quick search) + fictional demo patient with a plausible packet.
The founder demo drives the REAL dashboard + REAL iOS sim
(`--uitest-care-connect-code`). No public reset endpoint; audit
rows accumulate honestly (append-only survives demos).

## 11. Observability + redaction law

- `care_log_client_event(p_kind, p_detail)` — definer RPC, kind
  whitelist (auth/roster/packet/assignment/correction/hydration
  failure classes), detail keys whitelisted to
  `{code, rpc, status, trace_id, build}` with length caps; free
  text REJECTED at the server (the redaction policy is structural,
  not best-effort). Rate-limited per caller. Table `ops_events`
  readable by no API role (operator reads via Studio/SQL).
- Server-side RPC failures: Supabase Postgres logs (runbook
  section shows the exact log queries for `care_%` errors).
- Probe asserts: free-text detail rejected; sensitive keys
  rejected; events land; no health values representable.
- Sensitive words never leave the record system: medication
  names/strengths/weights/symptoms/notes are structurally absent
  from ops_events, audit meta (S4 law), analytics (none exist).

## 12. Pilot request flow (website → founder)

`pilot_requests` table + `care_submit_pilot_request` RPC (granted
to anon; strict field validation; honeypot + minimum-fill-time
params; global hourly cap — proportionate at this scale). The
form collects business facts only (name, professional email,
clinic, role, GLP-1 volume band, current workflow, pain,
contact preference) and states plainly that submission creates no
clinical relationship and must contain no patient information.
Founder reads via the ops runbook (SQL/Studio); no analytics, no
third-party form vendor (no new data processor).

## 13. Website (information architecture + design law)

`site/` — static, hand-authored, self-contained (system font
stack + one hosted serif via @font-face if licensable, else
system serif; zero external requests except the Supabase RPC for
the form). IA: hero (the between-visit problem, concrete) → how
it works (the loop in 5 acts with REAL product captures) → the
patient experience → the visit-prep record → assignment + the
patient's reconciliation → consent/provenance/trust → what Jeni
Care does not do → pilot invitation + form → security & privacy
posture (honest, no HIPAA claim) → footer (by Jeni Health).
Design: premium editorial (the dashboard's paper/ink/hairline
family, more expressive scale), no gradients-orbs-stock-photos,
real captures leak-checked by script. Deployed to Vercel (no
custom domain this pass — founder attaches one).

## 14. Verification law (gates before "shipped")

Everything in the S5 brief §28-§29: extended probe (role law,
suspension, restricted org creation, demo isolation, ops
redaction, pilot-request abuse), all prior suites green unchanged,
dashboard + website a11y passes, frame-level design pass separate
from functional QA, and the 22-point live pilot-like proof with
direct DB inspection. Recorded in §Evidence at the end of this doc.

## 15. Founder actions (accumulating list — nothing here is done silently)

1. **Create the staging/pilot Supabase project** (billing: a paid
   org may bill ~$10/mo per extra project; the org currently holds
   2 active projects). Runbook: `scripts/care_env_provision.md`.
2. Trademark/name counsel for Jeni Care / Jeni Health before paid
   public marketing (see §4 findings; Jenny Craig proximity).
3. BAA chain before ANY real patient data in the pilot: Supabase
   plan with BAA + signed BAA; hosting (website carries no PHI —
   confirm posture); no other processors exist today (verified
   inventory in `pilot/VENDORS.md`).
4. Legal review: pilot agreement draft, privacy policy delta,
   clinic-facing terms, patient notice language
   (`pilot/LEGAL_DRAFTS/` — all marked DRAFT, counsel-required).
5. Domain + email for Jeni Care (site is deployed on a Vercel URL
   until then; pilot-request notifications are runbook-checked, an
   email provider is a new-vendor decision).
6. Decide pilot parameters (clinic count/users/patients/weeks are
   drafted as 1/5/20/12).
7. App Store product rename (existing v1.2+ plan) — untouched.

## 16. Explicitly not in S5 (named seams, per brief §33)

e-prescribing/pharmacy/PA/claims/billing; RPM/CCM tooling;
scheduling; video; messaging; labs; refills; dosing/titration
recommendations; interaction checking; diagnosis; EHR; SSO/SCIM;
multi-department; population scoring; AI notes; automated
outreach; white-label builder; consumer redesign; legal
certification; outcome claims.

## 17. Evidence (this pass)

- **iOS units:** 396/396 (TEST SUCCEEDED, 0 failures) — unchanged by
  S5 (iOS calls only patient RPCs; none changed signature).
- **S5 server law:** proven against a **full local Supabase stack**
  running the complete schema + migration chain (the same Postgres +
  PostgREST + Auth + RLS the pilot will use). This IS the pilot-like
  environment (fictional data, real stack) the brief §29 asks for —
  real clinic data must never use the dev project, so applying S5 to a
  fresh pilot project is the founder step (`scripts/care_env_provision.md`),
  not a push to the consumer-prod dev DB.
- **Security probe (`scripts/s4_security_probe.py`, env-parameterized):**
  97/97 with `--skip-expiry`; a full run adds the ~5-min invitation-
  expiry check (99 total). Covers all S4 guarantees + the S5 additions
  (explicit clinical authority, non-clinical-owner denial, last-owner
  guards, staff-clinical-coercion, org suspension freeze, restricted-
  mode + single-use provisioning codes, clinic-side relationship end,
  ops-event structural redaction drop, pilot-request honeypot/fill-time/
  unreadability, environment RPC).
- **22-point pilot-readiness proof (`scripts/s5_pilot_proof.py`):**
  22/22 — the complete loop (pilot request → provision → authorize →
  staff-denied → invite → consent → packet → assign → reconcile →
  observe → series → correct → resolve → revoke → denial → audit chain
  → redaction → demo reset → org-null control) with direct DB
  inspection.
- **Dashboard E2E (Playwright):** green against both the dev project
  (S4 baseline, reconstruction) and the local S5 stack.
- **Accessibility:** axe-core WCAG 2.1 AA = **0 violations** on the
  site (light) and the dashboard (sign-in / roster / patient detail),
  after fixing muted-tone contrast and the resolved-correction opacity
  anti-pattern. Site responsive to 390px with no horizontal overflow;
  reduced-motion respected.
- **Demo mode:** seed → assign+correction → reset → clean status,
  proven on the local stack; reset refuses non-demo orgs.
- **Website:** deployed to Vercel (project `site`, build **Ready**);
  form proven end-to-end (row lands; honeypot/too-fast silently drop;
  anon cannot read `pilot_requests` or `ops_events`). Behind the
  team's Vercel Authentication until the founder exposes it publicly
  (a documented gate; `noindex` set).
- **Frame/design pass (separate from functional QA):** dashboard
  light+dark, focus ring visible, no dev artifacts on captures (chrome
  hidden), no clipping/overflow; site hero + loop + record + pilot in
  both themes + mobile reviewed.

## 18. Known limitations (honest)

- S5 server law is not yet applied to the live dev project (`supabase
  db push` is a founder step; and the environment law says pilot data
  belongs on a fresh project, not the consumer-prod dev DB).
- No staging/pilot Supabase project exists yet (founder gate: billing
  + BAA). The deployed site's form points at the dev project until then.
- No BAA, no counsel-finalized legal docs, no cyber insurance, no
  completed risk analysis — all founder/counsel gates in `pilot/`.
- The website is deployed but access-gated; making it public is a
  founder toggle.
- Product evidence screenshots are of the real dashboard on fictional
  data; the site also carries a faithful HTML recreation of the packet
  as the responsive/a11y equivalent.

## 19. Shipped

S5 is recorded in `05_BUILD.md` phase 11 and `STATE.md §-8`; decisions
S5-11..S5-19 appended to `04_DECISIONS.md`. Founder actions accumulate
in §15 above and across `pilot/`.
