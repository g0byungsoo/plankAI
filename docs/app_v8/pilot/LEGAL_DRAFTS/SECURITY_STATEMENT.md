# Jeni Care — security & privacy statement — WORKING DRAFT (counsel required)

> **DRAFT.** Wording verified against the actual implementation as of
> S5; counsel reviews before it is shared with a clinic or published.
> Every claim below is true today; nothing is aspirational-stated-as-
> present.

## What is true today

- **Scoped, patient-granted consent.** A patient chooses separately
  whether a clinic may see her visit-prep record, her daily entries,
  and whether it may assign care — and how far back (4 weeks or from
  today). Nothing is shared by default; she can revoke any of it
  immediately.
- **Server-enforced, audited access.** Clinician access to patient
  data runs only through audited server functions under row-level
  security. There is no direct database access from the browser and no
  service-role key in any client. Every disclosure (record opened,
  packet viewed, series viewed) is written to an append-only audit
  trail the clinic and the patient can both see.
- **Isolation.** Each clinic sees only its own consenting patients;
  cross-organization access is denied at the database. This is verified
  by a repeatable security probe (60+ live checks).
- **No sensitive data in analytics or logs.** Medication names,
  strengths, weights, symptoms, notes, and questions never leave the
  record system. Operational logs carry only ids, codes, and counts,
  enforced structurally.
- **No AI in the clinical loop.** The visit-prep record is a
  deterministic projection of what the patient recorded — nothing is
  inferred, scored, or generated.
- **Access ≠ treatment.** Turning off access never discontinues a plan
  or deletes history.

## What we do not claim

We do not claim to be "HIPAA compliant" — there is no such
certification. We sign Business Associate Agreements and align our
practices to the HIPAA Security Rule. Before a clinic uses Jeni Care
with real patient data, we complete a BAA, a security-rule posture
review, and a breach-response process together.

## For your security review

We can provide current documentation and status through an appropriate
security review — contact [security contact]. We are a development-stage
product; we will tell you plainly where we are, not where we hope to be.

## Boundary

Jeni Care is not an emergency or monitoring service and does not
provide medical advice. Urgent concerns go through your clinic's usual
channels or emergency services.
