# Jeni Care — vendor & data-flow inventory + BAA readiness (2026-07-29)

Every processor that could touch clinic/patient data, why, and its
BAA status. This is the founder's pre-pilot checklist and the honest
basis for the site's security posture. Sources are the 2026-07-29
pilot-research lane (citations in 11_S5_PILOT_READY §5).

> **The trigger.** Jeni Health becomes a HIPAA *business associate*
> the moment it handles PHI for a clinic — the first real patient, not
> the first dollar. At that moment a written BAA with the clinic AND
> with every subprocessor that touches PHI is mandatory. Until then:
> fictional test data only.

## Data-flow inventory

| processor | role | receives (real-data pilot) | sensitive? | BAA path | pre-pilot action |
|---|---|---|---|---|---|
| **Supabase** (DB, Auth, PostgREST) | the record system | all clinic + patient data | **yes** | BAA on **Team plan ($599/mo) or Enterprise + HIPAA add-on (from ~$350/mo)**; mark project "High Compliance"; enable PITR, SSL enforcement, network restrictions, connection logging | **founder: request + sign the Supabase BAA; provision the HIPAA-eligible pilot project (care_env_provision.md)** |
| **Vercel** (dashboard + site static hosting) | serves static JS/HTML/CSS; **no PHI passes through it** (the browser talks to Supabase directly) | none (static assets only) | no | BAA self-serve to Pro teams if desired; not strictly required since no PHI transits | confirm no PHI in built assets (true by design); optional BAA for defense-in-depth |
| **the iOS app / App Store** | patient client | patient's own data (on device + to Supabase) | yes (patient-side) | consumer-side; FTC HBNR applies today | keep clinic data out of analytics/notifications (already enforced) |
| **PostHog** (consumer analytics) | consumer product analytics | **must never receive clinic/patient health values** | would be if misused | not a BAA vendor for our use | **verify no care/ops health payloads reach PostHog** (ops_events is server-only; no client analytics call carries health data) |
| **error reporting** | none wired today | — | — | Sentry offers a BAA on Business tier; scrub PHI until signed | if added: Business tier + BAA + PHI scrubbing BEFORE enabling |
| **email provider** | none wired today | — | — | AWS SES / Paubox sign BAAs; SES needs TLS enforced | **keep pilot notifications PHI-free** (invite codes are not PHI); a BAA'd provider only if PHI ever emailed |
| **OpenAI / Grok / Gemini / ElevenLabs** | consumer food-vision / content only | **not in the clinic loop at all** | — | — | confirm the clinic loop invokes no AI provider (true: the packet is deterministic, no AI) |
| **RevenueCat** | consumer payments | consumer entitlement only | no clinic data | — | out of the clinic loop (no pilot fees) |

## What is true today (the honest posture)

- The clinic loop uses **no AI provider** — the visit packet is a
  deterministic projection; nothing is inferred or generated.
- No clinic/patient health values reach any analytics or error tool:
  audit `meta` carries ids/counts only (S4 law), `ops_events` carries
  single-token fields only (S5 law, structurally enforced + probed),
  and no client analytics call in the loop carries health data.
- The dashboard and site hold **no service-role key**; clinician data
  access is audited-RPC-only under RLS.
- The one processor that holds PHI in a real pilot is **Supabase** —
  so the BAA chain is short: Supabase + the clinic. That is the
  pilot's critical path.

## Founder gate checklist (before ANY real patient data)

Requires **legal counsel**:
- [ ] BAA with the pilot clinic (Jeni Health as business associate).
- [ ] Pilot agreement (LEGAL_DRAFTS/PILOT_AGREEMENT.md — DRAFT).
- [ ] Patient notice / consent language review (the app's consent
      screen copy reviewed against the BAA).
- [ ] Consumer privacy-policy delta for the care platform.

Requires **infrastructure / vendor**:
- [ ] Supabase HIPAA-eligible pilot project + signed BAA + High
      Compliance config (PITR, SSL, network restrictions, logging).
- [ ] Any future error/email processor: BAA + PHI scrubbing first.

Requires **operations / paper**:
- [ ] Named security official (the founder, in writing).
- [ ] A completed, dated risk analysis (HHS SRA Tool, NIST SP 800-66r2).
- [ ] Written policies: sanction, contingency/backup (tested restore),
      incident-response (the runbook), access-management/termination.
- [ ] Cyber + tech E&O insurance — a $1M/$2M cyber + tech E&O floor is
      credible for a single-clinic pilot.
- [ ] A short security one-pager for the clinic's vendor review (no
      clinic-specific standard like HECVAT exists; a SOC 2 or a concise
      overview + signed BAA is the norm at this scale).

## Language law (public + product)

- Never "HIPAA compliant" (no such certification; the FTC has treated
  the claim itself as deceptive — SkyMed).
- Say: "built with scoped access, patient consent, and auditable
  clinical actions"; "we sign BAAs and align to the HIPAA Security
  Rule"; "pilot availability is limited."
- The FTC Health Breach Notification Rule applies to the **consumer
  side today** — no health data leaves the record system for
  ads/analytics, ever.

## Not adopted this pass (named)

No new data processor was introduced in S5. Any new processor that
would receive identifiers or health-related metadata is a **founder
gate** (11_S5 §15) and must clear the checklist above first.
