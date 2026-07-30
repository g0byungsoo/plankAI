# Jeni Care — the pilot model (2026-07-29)

One controlled pilot, one clinic, bounded on every axis. These
parameters are the working defaults; the founder adjusts them before
signing. They live here (and in the agreement draft), **never in
product copy** — the app and site say "pilot availability is limited,"
not a number.

## The shape

| axis | default | why |
|---|---|---|
| clinics | 1 | learn depth before breadth; a single operator relationship |
| clinic users | ≤ 5 | owner + a small care team; enough to see the role split work |
| invited patients | ≤ 20 | enough signal, small enough to support by hand |
| duration | 12 weeks | ≥ 2 titration cycles (~q4wk) so between-visit value is testable |
| fees | none | this is a learning pilot, not a sale |
| data | fictional until every gate in VENDORS.md clears; then this clinic's real patients only | no real PHI touches the dev project, ever |

## What each party is responsible for

**The clinic**
- Designates one owner and authorizes only its own personnel.
- Invites only its own patients, with a clear verbal explanation.
- Retains all clinical judgment and decision-making. Jeni Care records
  the plan the clinic communicates; it never prescribes or advises.
- Uses existing clinical/emergency channels for anything urgent.
- Gives feedback on a weekly cadence (METRICS.md interview guide).

**Jeni Health**
- Provides the dashboard, the patient app connection, and support
  within the stated boundary (below).
- Keeps the pilot environment isolated, keys rotated, access logged.
- Does not access patient data except as needed to operate the pilot
  and only through the audited paths; never for analytics or ads.
- Notifies the clinic of any security incident affecting its data
  within the contractual window (≤ 60 days is the regulatory floor;
  we target faster — see RUNBOOK.md incident section).
- Never claims HIPAA compliance; completes the BAA + posture review
  before any real patient data.

**The patient**
- Chooses whether to connect and what to share; can revoke anytime.
- Records her own care in the Jeni app as she already does.
- Understands (from the consent screen) that nothing is monitored in
  real time and urgent concerns go to the clinic or emergency services.

## Support boundary

- Support is business-hours, best-effort, founder-operated, by email
  (the address in the dashboard help sheet and site).
- **Not** an emergency, monitoring, or clinical-advice channel — stated
  on every relevant surface.
- Correction requests are reviewed by the clinic at its cadence, not
  in real time; the app says so where a patient files one.
- Target response: routine support within 1 business day; a suspected
  security incident is handled immediately per the runbook.

## Boundaries (restated for the agreement)

No automated prescribing · no payment or insurance · no emergency or
real-time monitoring · no guarantee of clinician review of any given
entry · use limited to the approved between-visit workflow · no use
with populations or purposes outside the pilot scope.

## Start / end / termination

- **Start:** when the clinic owner has completed setup, at least one
  patient has connected, and the clinic has acknowledged the boundary
  (agreement + BAA signed for real-data pilots).
- **End:** at 12 weeks, or earlier by either party for convenience
  (target 45-day notice in the agreement; immediate for cause).
- **On end:** clinic access is turned off (relationships ended);
  patients keep their records and any assigned plan (access ≠
  treatment); a data export is provided on request; audit and
  clinical history are retained per RETENTION.md.

## Pilot success = a decision, not a vanity metric

The pilot answers one question: *does a real clinic complete the
between-visit loop without founder hand-holding, trust the record, and
want to continue?* The measures in METRICS.md serve that decision.
Engagement alone is explicitly **not** success.
