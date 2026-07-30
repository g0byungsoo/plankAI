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

## 4. Name-risk findings (lane synthesis)

*(filled after lane completion — see section below in this doc's
final form)*

## 5. Pilot research synthesis (lane)

*(filled after lane completion)*

## 6. Clinician-product presentation synthesis (lane)

*(filled after lane completion)*

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

---

*Sections §4-§6 (research syntheses), the decisions appendix, the
evidence record, and the shipped record land as the pass executes.*
