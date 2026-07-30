# Jeni Care — data retention & termination (2026-07-29)

The rule that governs every ending: **separate access from
treatment, and never destroy medically-relevant history just because
access ended.** Six distinct states, deliberately not collapsed.

## The six states (they are independent)

| state | what changed | what is preserved |
|---|---|---|
| **access termination** (member removed/disabled) | one clinic user can no longer see this clinic's data | everything; the clinic itself is unaffected |
| **consent revocation** (patient turns off a scope) | clinic loses that scope's access going forward; published packet copy removed | observations, provenance, audit, assigned plan's clinical status |
| **relationship termination** (patient disconnects, or clinic ends it) | clinic access off entirely; grants revoked; packet copy removed | patient's records + any assigned plan (still hers); audit chain |
| **organization suspension** | the whole org is frozen (no member reads/writes) | all data; reversible by the operator |
| **pilot expiration** | relationships ended per PILOT_MODEL; export offered | records, audit, clinical history retained per below |
| **account deletion** | user-owned rows cascade-deleted | audit rows survive as pseudonymous (bare uuid) for the disclosure record |

Revocation and termination are **prospective and access-only**. They
never silently discontinue a medication plan or rewrite history — the
app states this plainly, and treatment questions route to the clinic.

## What is retained, and why

- **Care-team assignments & regimen history:** retained (end, never
  delete). A medication plan the clinic assigned is medically relevant
  history; ending access does not end the plan.
- **Patient observations & weigh-ins:** hers, retained under her
  account; survive sign-out and access changes.
- **Audit trail (`care_audit_events`):** append-only, retained; it is
  the accounting-of-disclosures record and cannot be edited or deleted
  through any API (trigger-enforced). Deliberately has no FKs so rows
  outlive deleted accounts as pseudonymous entries.
- **Correction chain:** append-only; disputed items are resolved, never
  deleted.
- **Visit packets:** the clinic's *copy* is removed on revocation/
  termination (Apple stop-sharing precedent); the patient's own packet
  regenerates from her records on demand — it was always a projection.

## Data export

On a clinic's or patient's request, the operator assembles an export
scoped to the patient's `user_id` (RUNBOOK.md §G): observations,
weigh-ins, regimen plans, visit packets, correction requests, and her
audit rows. Format: JSON (machine-readable) for the pilot; a
clinician-readable PDF is the patient's existing in-app packet share.

## Deletion

- **Account deletion** cascades user-owned rows via FK
  `on delete cascade`; audit survives pseudonymously.
- **Deleting medically-relevant history a clinic may be obligated to
  retain is a founder + counsel decision** (11_S5 founder gate), never
  a routine operation. The default is retain.

## Founder / counsel gates

- Final retention periods for clinical + audit records → counsel
  (state medical-record retention law varies; the product default is
  "retain, do not auto-purge").
- The BAA governs return/destruction of PHI at pilot termination →
  counsel (LEGAL_DRAFTS/PILOT_AGREEMENT.md §return/deletion).
- Changing retention of clinical or audit records, or deleting
  historical care-team records, is an explicit founder gate.
