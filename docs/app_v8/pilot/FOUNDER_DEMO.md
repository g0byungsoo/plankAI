# Jeni Care — founder demo package (2026-07-29)

Everything to sit with one obesity-clinic operator and be credible.
Not hype — a practicing clinician should recognize their own workflow
and never catch you overclaiming.

## The one-line problem & claim

> **Problem:** between a patient's visits, the record goes dark — and
> the first minutes of every follow-up go to reconstructing what
> happened.
>
> **Claim:** Jeni Care turns four weeks of a patient's own records into
> a two-minute visit-prep read, then carries the plan you assign back
> into her daily care. That is the whole product.

## The exact current product claim (what you may say)

- "It organizes what the patient recorded — adherence, weight, how
  meals sat, her questions — into one page you read before the visit."
- "When you assign a plan, it becomes the medication her daily app is
  built around, marked as from your clinic. She confirms it; if it's
  wrong she sends a correction that lands back to you."
- "Every line is labeled by where it came from. Nothing is inferred,
  scored, or diagnosed."
- "It's not an EHR and not e-prescribing — it sits beside them."

## Pre-demo (2 minutes)

```
python3 scripts/care_demo.py reset
python3 scripts/care_demo.py status     # confirm Jordan D. connected, packet fresh
```
Open the dashboard signed in as the demo clinician; have the iOS sim
ready with the Jeni app. (Environment badge is absent on pilot builds;
on a dev build it reads "development" — mention it's the dev copy.)

## The 3-minute version (the loop, live)

1. **The site** — hero: "know what happened between visits." One
   scroll to the between-visit horizon. (30s)
2. **The record** — open Jordan D. in the dashboard. Read the four
   weeks aloud: weight easing, 3 of 4 doses marked, queasy twice near a
   dose, one question. Point at the self-reported vs summarized tags. (60s)
3. **Assign** — assign semaglutide 0.5 mg, Wednesdays. Note mg-only,
   provenance stamped, "this is a record, not a prescription." (30s)
4. **The patient** — on the sim, show the plan arrive as her dose-day
   lead, the calm reconciliation confirm, and the "your care team"
   door with revoke. (45s)
5. **Trust** — one line: scoped consent, audited access, access ≠
   treatment, not monitored in real time. (15s)

## The 10-minute version (adds depth)

- Start on the **problem** (their world): titration calendar, the dark
  month, portal-message load. Ask them to describe their own follow-up
  first (interview Q1–3) before you show anything.
- The full loop above, slower, with the **correction round trip**:
  patient sends "I was moved to 1.0 mg," you resolve it by updating the
  plan; show the audit line appear.
- **Revocation**: patient turns off access on the sim; refresh the
  dashboard — access gone, but the assigned plan and her records
  remain. Say the sentence: "access is not treatment."
- **The boundary** slide/section: what it does not do (EHR,
  e-prescribing, monitoring, dosing advice).
- **Security posture**, honestly (SECURITY_STATEMENT.md): scoped
  consent, RPC-only audited access, no service key in the browser, no
  AI in the loop, no health data in analytics — and "we do not say
  HIPAA compliant; we sign a BAA and align to the Security Rule before
  any real patient."
- The **pilot ask** (below).

## The pilot ask

"I'd like to run a bounded pilot with your clinic: your patients, your
consent, twelve weeks, no fee, so we both learn whether this earns a
place in your follow-up. Before any real patient data, we sign a BAA
and do a security review together. Until then everything you've seen is
test data."

## Honest limitations (say these before they ask)

- Development-stage; no BAA in place yet — real data waits for it.
- The packet is as fresh as the patient's last app open (stated in the
  UI); not a live feed.
- One weekly-injectable medication plan at a time; mg only; no titration
  schedule modeling (each step is a new confirmed update).
- No EHR/pharmacy integration; you re-enter the plan you already
  prescribed.
- We have no clinic outcomes to show — that's what the pilot is for.

## Likely objections → evidence-based answers

| objection | answer |
|---|---|
| "Is this HIPAA compliant?" | "There's no such certification, and I won't claim it. We sign a BAA and align to the Security Rule; access is scoped, audited, and server-enforced. I can walk your security reviewer through it." |
| "Another inbox to staff?" | "No. There's no feed and no alerts. You open a patient before their visit; that's the only moment it asks for." |
| "Patients won't use it." | "They already use the daily app — this rides it. Connecting is one code and one consent screen; the plan you assign just appears in the app they already open." |
| "How do I trust patient-entered data?" | "You don't have to treat it as verified — every line is labeled self-reported vs summarized, and self-reported never looks otherwise." |
| "What if the record is wrong?" | "The patient can send a correction; it never changes the plan on its own, it comes to you to decide, and the whole chain is auditable." |
| "What does it cost?" | "The pilot is free. Pricing is what I want to learn with you — I have a hypothesis (per-enrolled-patient/month, aligned to your RPM/CCM revenue), not a number I'm defending." |
| "Who else uses it?" | "You'd be the first clinic pilot. I'd rather tell you that than show you a fake logo wall." |

## Pricing: questions to learn, not a number to defend

Ask, don't assert: what would saving 10 minutes a follow-up be worth?
Do you bill RPM/RTM/CCM today? Would per-enrolled-patient pricing fit
how you think about this? What's your budget authority? Record answers;
do not commit to a price in the room.

## Pilot success measures (what "yes" looks like)

The six qualitative checks in METRICS.md — packet saved time, felt more
prepared, trusted provenance, patient understood the plan, a correction
caught an error, would continue — plus the connection/assignment/
review-completion counts. Not engagement for its own sake.

## Backup

A recorded run of the 3-minute loop may be kept for a flaky-network
room, but **live functionality is the primary proof** — offer to let
them drive.
