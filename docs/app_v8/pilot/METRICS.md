# Jeni Care — pilot measurement plan (2026-07-29)

Measure the value and the feasibility of the workflow, without ever
sending clinical content into general analytics. The pilot exists to
make a **decision** (continue / stop / change), not to celebrate
engagement. Norms + instruments are from the 2026-07-29 research lane
(11_S5 §5).

## Principles

- Feasibility first (does the loop run without hand-holding?), value
  second (does it save time / build trust?), engagement last (and
  never as the headline).
- Sensitive values never leave the record system. Operational counts
  come from `care_audit_events` (ids/actions/counts) and `ops_events`
  (single tokens) — both health-value-free by construction.
- A small pilot cannot make a clinical-outcomes claim. We do not try.

## Clinic-side measures (from the audit trail + operator observation)

| measure | source | why it matters |
|---|---|---|
| time from invite to connection | audit `invitation.created` → `relationship.activated` | onboarding friction |
| invitation acceptance rate | invitations created vs accepted | patient willingness |
| packet-open-before-visit rate | `packet.viewed` timing vs the clinic's visit calendar | is the pre-visit read actually happening |
| median packet-review time | operator-timed during check-ins (no server timer needed at this scale) | the <2-minute claim, tested |
| assignment completion rate | `protocol.assigned` / `regimen.assigned` per reviewed patient | does review lead to action |
| unresolved correction count | open `correction_requests` age | is the correction loop closing |
| clinician return frequency | distinct `chart.opened` days per clinician | habit formation |
| patients reviewed per session | `chart.opened` clustering | throughput |
| support incidents | the intake log (RUNBOOK.md §H) | operational burden |
| failed authorization attempts | audit denials + `invitation_attempts` | security signal |
| consent revocation rate | `consent.revoked` events | trust signal |

## Patient-side measures (privacy-safe)

connection completion · consent completion · assigned-plan hydration
(care-team regimen becomes the dose-day lead) · reconciliation
completion (the FR2 confirm) · scheduled dose opportunities recorded ·
packet availability · correction-request use · retention within the
pilot window. All derivable from the existing chart + audit, none
requiring new health-valued analytics.

## Qualitative measures (the ones that decide it)

Asked at the weekly check-in, scored yes/no + a note:
- The clinician says the packet **saved time**.
- The clinician felt **more prepared** for the visit.
- The clinician **trusted the provenance** (self-reported vs assigned).
- The patient **understood which plan came from the clinic**.
- The correction workflow **prevented a misleading record** at least once.
- The clinic **would keep using** Jeni Care after the pilot.

## Instruments

- **SUS** (System Usability Scale, 10 items) at week 4 and week 12.
  Benchmark: 68 = average; digital-health apps average ≈ 76.6;
  clinician-rated EHRs average ≈ 45.9 — a beatable incumbent bar.
- **NPS** as a single secondary question ("how likely are you to
  recommend Jeni Care to a colleague?").
- **Time baseline** for the value claim: PCPs spend ≈ 16 min of EHR
  time per encounter (chart review ~⅓ of it) and ≈ 2.9 min of
  pre-visit EHR review — so "packet review under 3 minutes" is a
  defensible, pre-registered headline to test against.

## Weekly pilot review template (15 minutes, recurring)

```
Week __ of 12 · clinic: __________ · date: ______

NUMBERS (from the runbook queries)
  patients connected / invited: __ / __
  charts opened this week (distinct days): __
  assignments made: __    corrections opened / resolved: __ / __
  support incidents: __   auth denials / throttle hits: __

THE SIX QUALITATIVE CHECKS (Y/N + one line)
  packet saved time?           ___  ______________________________
  felt more prepared?          ___  ______________________________
  trusted provenance?          ___  ______________________________
  patient understood the plan? ___  ______________________________
  correction caught an error?  ___  ______________________________
  would continue?              ___  ______________________________

ONE THING TO FIX THIS WEEK: _______________________________________
DECISION SIGNAL (continue / change / stop): _______________________
```

## Interview guide (non-leading; run at weeks 1, 4, 12)

Open, not yes/no; never sell inside the question.
1. Walk me through how you handle a GLP-1 follow-up today, start to end.
2. Before a follow-up, what do you wish you already knew about the patient?
3. How much time goes to reconstructing what happened since the last visit?
4. When you opened a patient's record here, what did you look at first? What did you ignore?
5. Was anything in it you didn't trust? Why?
6. Who on your staff would actually use this, and for what?
7. Tell me about a time an assignment changed between visits — how did the patient find out?
8. Have you ever had a medication record that was wrong? What happened?
9. What would have to be true for you to keep using this after the pilot?
10. Who decides whether your clinic adopts a tool like this? What evidence do they need?
11. If this saved you real time, what would that be worth to the clinic?

Record answers verbatim where possible; do not paraphrase into
confirmation. The goal is to learn, including learning that we're wrong.

## Instrumentation to build only if justified

A small operational report (the runbook queries wrapped as a saved
SQL view) is worth it if the founder runs the weekly review often; a
full pilot dashboard is **not** justified for one clinic. Keep sensitive
values out of any report — counts and states only.
