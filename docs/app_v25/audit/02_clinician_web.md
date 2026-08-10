# v25 audit 02 — the clinician web surfaces

Audited 2026-08-10. Read-only pass. Scope: `/Users/bko/jeni-health-web`
plus the two related web properties discovered during the audit.

## 0. The headline correction

**`/Users/bko/jeni-health-web` is not a clinician tool.** It is the
Jeni Health **B2B marketing site** — prose pages that sell the
between-visit platform to clinic owners and investors. It has no auth,
no dashboard, no patient data, and no Supabase client library; its only
backend call is a waitlist form.

The **actual clinician product** lives inside the plankAI repo at
`/Users/bko/plankAI/clinic/` — the **Jeni Care dashboard** (v8 S4/S5,
extended v9-P6). A third property, `/Users/bko/plankAI/site/`, is the
retired S5 pilot one-pager. All three are audited below; the dashboard
gets the deepest treatment since that is what v25 needs understood.

| property | what it is | last touched | deployed? |
|---|---|---|---|
| `jeni-health-web` (own repo) | B2B marketing site, 9 pages + waitlist | 2026-08-06 (39 commits: Jul 31 birth, Aug 5–6 rework) | **No.** Built for Vercel but no Vercel project exists on the founder's only team; local-only |
| `plankAI/clinic/` | Jeni Care clinician dashboard (Vite SPA) | 2026-08-04 (v9-P6) | Dev-only; `dist/` built Jul 29, no Vercel link; pilot build founder-gated |
| `plankAI/site/` | S5 pilot request one-pager (static) | 2026-07-30 | Was deployed access-gated as Vercel project `site`; that project **no longer exists** on the team — link is stale |

(The team's live Vercel projects: `jenifit-web` — the consumer site — plus
unrelated properties. Neither clinician-adjacent site is live today.)

---

## 1. jeni-health-web — the marketing site

### Stack
- **Next.js (latest, App Router, React 19, TypeScript)**, Tailwind CSS 3.4,
  `cacheComponents: true`, Turbopack. No component library — hand-built
  primitives in `components/site/`. Fonts: DM Sans (UI) + Playfair Display
  (display) via `next/font` — the app's own paper+ink register, adapted.
- Born from the Vercel "Next.js + Supabase starter" (README is still the
  stock starter README) but the Supabase scaffolding was stripped:
  **no `@supabase/supabase-js` dependency at all**. Deploy target is
  Vercel (`VERCEL_PROJECT_PRODUCTION_URL` drives metadataBase/robots/
  sitemap) — but it is not deployed.
- `docs/design/DESIGN-SYSTEM.md` in-repo is the site's own design law
  ("the website is part of the product"); two dated design docs record
  the Jul 31 art direction and the Aug 5 morphing-frame port.

### Git recency and workstreams
39 commits total: **Jul 31** — initial build (illustrated hero, painterly
art, investor-grade B2B rework). **Aug 5–6** — the big pass: "the stage"
(one scroll-coupled morphing photo frame carrying the whole landing
document, 11 desktop keyframes), statistics corrected against primary
sources, the platform/patients/privacy pages, per-page OG share cards
generated from the design system, FAQ additions, 404-as-site-index,
cross-reference links. Untouched since Aug 6.

### Routes
| route | renders |
|---|---|
| `/` | Nav + **the Stage** (pinned scroll film: door → dose photo → clip → arch → portal → close) + `Lower` (labeled beats: The first evening / The first bad week / Silence / An exception / Dose day / What it is / Who we're building with / The part nobody sells you) + **Waitlist** close + footer |
| `/platform` | "Your protocol, running every day" — programme mechanics, what the software decides vs never decides, the four things it is not |
| `/clinics` | "What changes in your practice" — the morning list pitch, what the clinic sends, what Jeni will not do |
| `/patients` | "What lands on your patient's phone" — written for the clinician co-signing the programme |
| `/evidence` | GLP-1 persistence literature, 5 primary sources cited with n and caveats; honestly states no RCT evidence that between-visit support raises persistence |
| `/faq` | Clinic-owner questions (staff replacement, liability, EHR, cost, engagement, protocol ownership, company stage) with FAQ schema |
| `/security` | Clinical accountability, data location, what gets signed, explicit "we never say HIPAA compliant" |
| `/privacy` | Site collects one email; claims verified against the running page (no cookies, no third-party requests, write-only Supabase path) |
| `/about` | The delivery-problem thesis |
| `/og-card/[slug]` | Noindex render target for share cards (`npm run og` screenshots it) |
| `/api/waitlist` | POST-only waitlist endpoint (below) |
| 404 | The site index, each page's question listed |
| `robots.ts` / `sitemap.ts` | Standard, `/api/` disallowed |

### Data access — one write path
`app/api/waitlist/route.ts` POSTs to the Supabase RPC
**`care_submit_pilot_request`** via raw `fetch` (no SDK) — **the same
dev Supabase project as the iOS app** (`mtecqvykyeueumdynatd.supabase.co`,
same publishable key, hardcoded fallbacks in the route; local `.env`
carries only a Resend key and a Grok Imagine key, so the fallbacks are
live). Entries land in `pilot_requests` tagged `p_workflow: "waitlist"`
— beside the pilot site's requests. The table is RLS-locked, anon has
no select; the RPC is bounded (rate cap + dedupe in SQL). A Resend email
notifies the founder per signup (defaults to the founder's gmail via
`onboarding@resend.dev` until a domain is verified). Honeypot +
min-dwell + per-instance rate limit on the route.

### Maturity — honest read
**Polished pre-launch marketing site, not yet public.** Copy quality is
unusually high (primary-source citations, verified privacy claims,
compliance-aware: no HIPAA claim, no brand drug names). Loose ends:
stock starter README; no custom domain wired (`jenihealth.com` named
only in the design doc); Resend not domain-verified so notifications
only reach the owner address; waitlist writes into the *dev* database;
no analytics by deliberate choice (the privacy page makes it a promise).
**It describes a product materially ahead of what is built** — see §4.

---

## 2. plankAI/clinic — the Jeni Care dashboard (the real clinician surface)

### Stack
Vite 5 + React 18 + TypeScript + `@supabase/supabase-js`. No router
(in-memory `View` state: roster | patient | org), no CSS framework
(one `styles.css`, paper+ink), ~1,900 lines of source. Vitest +
Playwright (`e2e/loop.spec.ts` clinic-loop walk, `e2e/capture.spec.ts`
regenerates the pilot site's leak-checked screenshots). Build-time
environment identity: built-for env must match the server-declared env
(`care_environment` RPC) or the app refuses to operate; non-dev builds
fail if pointed at the dev project; `min_dashboard_build` staleness
nudge. Same dev Supabase project as the iOS app (shared database —
that IS the integration).

### Auth + tenancy model
- **Email + password Supabase auth** (self-serve signup, email confirm,
  password reset/recovery flow). No SSO, no MFA.
- An account alone sees nothing. **Tenancy = `organizations` +
  `org_members`** (role: `owner` | `clinician` | `staff`, plus
  `clinical_authority` boolean, `credential_label`, `status`
  active/disabled). Multi-org membership supported (org switcher).
- **S5 role law:** assigning care requires `clinician`, or `owner` with
  `clinical_authority` explicitly set. Staff invite and read, never
  assign. Client mirrors the rule only to decide what to offer;
  **every privileged action is a SECURITY DEFINER RPC** enforcing
  role + relationship + consent scope server-side. Publishable key +
  RLS is the browser boundary; no service key anywhere.
- Org creation is open in development, **gated by a founder-issued
  provision code** in pilot/staging (`org_creation_mode = restricted`).
  Suspended orgs render as "unavailable" without detail. `is_demo`
  orgs wear a badge.
- No verification that a signer-up is actually a clinician beyond the
  clinic's own owner adding them — the model delegates personnel
  control to the clinic and says so in copy.

### Data access (complete inventory)
RPCs called: `care_environment`, `care_log_client_event` (structurally
redacted ops telemetry), `care_list_patients`, `care_open_patient_chart`,
`care_get_visit_packet`, `care_get_weekly_summaries`,
`care_get_patient_series`, `care_create_invitation`,
`care_cancel_invitation`, `care_create_org`, `care_add_member`,
`care_set_member_role`, `care_set_member_status`, `care_assign_regimen`,
`care_update_regimen`, `care_assign_protocol`, `care_resolve_correction`,
`care_set_patient_review`, `care_end_relationship`.
Direct RLS table reads: `org_members` (+`organizations` join),
`patient_invitations`, `care_audit_events`, `protocols`.

### What a clinician can SEE and DO, screen by screen
- **SignIn / NewPassword** — sign in, sign up, reset; environment
  boundary line ("not an emergency monitoring service") on the door.
- **OrgGate** — first-run org creation: name, "I'm a clinician"
  checkbox (the explicit clinical-authority act), pilot setup code.
- **Roster** — every connected patient: clinic-chosen label (never the
  patient's name), record-updated date, follow-up date if set, open
  corrections count, `needs_attention` "worth a look" token,
  active vs access-ended sections. First-run shows a 4-step welcome.
  No search, no filters, no pagination — a flat list.
- **PatientDetail** — the chart: connection dates + consent lookback
  window; **consent scope tokens** (visit packet / daily records /
  assign care — the patient's choices, absent scopes render as honest
  empties); open **corrections first** ("needs your decision" — accept
  → prefilled regimen update that also resolves, or dismiss with a
  patient-visible reason); **assigned care** panel (protocol + active
  care-team regimen, or the patient's self-reported weekly rhythm as a
  hint); **THE VISIT PACKET** — the patient-published 4-week summary
  rendered verbatim, never recomputed (medication taken/skipped/
  unrecorded, weight first·latest·trend, symptom words with timing,
  protein floor days, movement, her noted questions, explicit
  "not recorded" gaps) with a staleness word; **week by week** — one
  summary row per week (v9-P6); **weight series** — last 8 weigh-ins
  as a list (no chart); correction history; **audit trail** (last 8
  events, humanized, same rows the patient sees); mark-as-reviewed;
  end-connection (access-only, nothing deleted). Standing disclaimer:
  not a prescription, not real-time monitoring.
- **AssignRegimenSheet** — name (free text), **mg only** (0–50,
  refuses units/mL per the FDA compounded-dosing alert), single weekly
  anchor day, start date, optional 140-char patient-visible
  instruction. **DO:** assign/update a weekly medication plan.
- **AssignProtocolSheet** — pick from `protocols` (org-scoped or the
  null-org "standard Jeni plan"); read-only titles+versions, no
  protocol authoring or editing anywhere.
- **OrgScreen** — patient invitations (label → one-time code revealed
  once, expiry, cancel); team management (owner adds by email of an
  existing account, sets role/credential/clinical authority; manage =
  change role, disable/restore immediately, last-owner guarded
  server-side).
- **HelpSheet** — support contact + environment.

### Maturity — honest read
**A real, working, security-serious pilot prototype — not yet a pilot.**
The permission architecture (RPC-only, consent scopes, env identity,
audit, structurally redacted telemetry) is genuinely ahead of typical
seed-stage health dashboards, and the honesty vocabulary carries
through. But: dev environment only, live-proven with founder-seeded
data (S4 "first real clinic loop" per docs); no deployed pilot build;
no BAA (docs are explicit: never say HIPAA compliant); visuals are
functional lists — no charts; roster won't scale past dozens; the v8
pilot gates in `docs/app_v8/11_S5_PILOT_READY.md` (pilot Supabase
project, domain, support mailbox, key rotation) remain open. Untouched
since v9-P6 (Aug 4) — five product eras ago.

---

## 3. Relationship to the iOS app's care platform

**What connects TODAY (all on the shared dev Supabase project):**
- **Invitation loop:** dashboard mints one-time code → patient redeems
  in-app (`CareConnectionService`: `care_preview_invitation`,
  `care_accept_invitation`) and picks consent scopes → appears on the
  roster. QA door `--uitest-care-connect-code` exercises it.
- **The packet + weekly summaries:** iOS `VisitPacketPublisher` and
  `WeeklySummaryPublisher` compute on-device and upsert; the dashboard
  renders them verbatim (provenance law preserved end-to-end).
- **Care-team regimen loop:** clinic assigns via `care_assign_regimen`;
  iOS `CareReconciliation` surfaces it as `needsConfirmation`, patient
  confirms (`care_confirm_reconciliation`) — the care plan takes lead
  in the day composer — or flags it (`care_submit_correction`) and the
  correction lands back on the dashboard for accept/dismiss.
  `CareReconciliation` writes v24 `RegimenPlanRecord`s, so the loop
  survived the v24 rebuild (587/587 green).
- **Consent revocation** (`care_revoke_consent`) and clinic-side end
  are both honored; audit events flow to both sides.
- **The waitlist/pilot funnel:** both marketing surfaces write
  `pilot_requests` rows via the same anon RPC.

**What is aspirational (marketing site says it, nothing implements it):**
the morning list, silence detection and follow-up, the weekly
five-question check-in, clinic-authored message scripts/escalation
rules ("what must reach a person now"), protocol authoring, EHR
anything, cost/pricing. The site also implies patient outreach the
consumer app does not perform on a clinic's behalf.

**Structural note for v25:** the clinic dashboard is pre-v24 — it knows
one weekly injectable (mg, single anchor day) while the consumer side
now runs the v24 medication platform (catalog of 9 products, oral
dailies, version chains, dose events, rotation, patterns). The clinic
loop reads none of that richness; `care_get_patient_series`
observations exist but only weights are rendered.

## 4. GAPS — what a real GLP-1/obesity clinic workflow would need that is absent

Named only, not designed. Ordered roughly by how soon a pilot clinic
would hit them.

1. **No deployed clinician surface at all** — dashboard dev-only,
   pilot env unprovisioned, pilot site's Vercel project gone,
   marketing site undeployed with no domain.
2. **No triage/worklist** — the promised "one short list each morning"
   does not exist; the roster is a flat unranked list with a single
   `needs_attention` flag; no cross-patient queue of what needs action.
3. **No silence/disengagement detection or any outreach** — nothing
   notices a patient who stopped logging; no clinic→patient messaging
   channel of any kind (and no scheduled check-in instrument).
4. **Titration is unsupported** — one weekly mg + anchor day; no dose
   ladder/schedule of escalation, no oral or daily regimens clinic-side
   (v24 consumer catalog has them), no reason-coded pause/restart.
5. **No clinical review instruments** — no weight/adherence charts, no
   side-effect trend view, no visit notes, no follow-up date setting in
   the UI, no packet export/print for the EHR encounter.
6. **No compliance rail for real patients** — no BAA, no pilot legal
   pack in product, no clinician identity verification beyond
   self-attestation, no MFA/SSO, no session policies.
7. **No protocol lifecycle** — protocols are pick-only rows; no
   authoring, versioning UI, or the clinic-written escalation rules
   the platform page sells.
8. **No practice operations** — no scheduling, no billing/RPM-CPT
   capture (the revenue story a US clinic buys), no EHR integration,
   no e-prescribing linkage (deliberately out of scope, but the
   boundary is currently prose, not product).
9. **No population view** — no cohort analytics, no per-clinic
   outcomes, no export.
10. **Scale plumbing** — no search/filter/pagination, list-only
    rendering, single-file screens; fine for 10 patients, not 200.

## 5. Files
- Marketing site: `/Users/bko/jeni-health-web/app/*` ·
  `components/site/*` · `app/api/waitlist/route.ts` ·
  `docs/design/DESIGN-SYSTEM.md`
- Dashboard: `/Users/bko/plankAI/clinic/src/*` (App, supabase, env,
  types, screens/{SignIn,OrgGate,Roster,PatientDetail,PacketView,
  AssignSheets,OrgScreen,HelpSheet})
- Pilot one-pager: `/Users/bko/plankAI/site/`
- iOS counterpart: `/Users/bko/plankAI/PlankApp/Care/*` ·
  `PlankApp/Program/{ConsentService,VisitPacket}.swift`
- Server law: `/Users/bko/plankAI/supabase/migrations/20260730090000_s5_pilot_ready.sql` ·
  `docs/app_v8/{10_S4_CLINIC_LOOP,11_S5_PILOT_READY}.md`
