# app v8 — S3: THE VISIT-PREP PACKET (plan + schema, 2026-07-29)

The patient-side artifact the clinic research named the single
highest-leverage clinic feature (01_RESEARCH §A7.3: the PA
evidence dossier is "her file", payer-shaped) and the v7 clinic
panel spec'd (visit-prep: 4-week summary + "two things worth
mentioning"). Law: the system observes and organizes; it never
diagnoses. Every statement traces to a record. The packet is a
PROJECTION over existing stores — never a second data system.

## 1. Decisions (rationale one line each)

- **Window: the rolling last 28 days**, rendered explicitly
  ("jul 1 – jul 29"). The app holds no visit date (inventing one
  is banned); 28 days matches the between-visit cadence research
  (monthly prescriber visits) and observation density. A visit-
  date field is a future refinement, not S3.
- **Entry point: ONE — becoming's index** gains a quiet "for
  your next visit" row (becoming is the record's home; Home
  stays a care plan, not a dashboard; the regimen sheet gets no
  second door).
- **Transport: in-app review + user-triggered share-sheet PDF.**
  The evidenced winning pattern (clinician-ready export,
  patient-controlled); nothing auto-sends, ever. PDF via
  ImageRenderer of a dedicated print view: date range on page 1,
  patient-entered vs summarized marked, no stickers, no internal
  ids, printable, VoiceOver-labeled in-app equivalent.
- **F1 RESOLVED (per founder rule in this brief):** self-managed
  regimen renders as **"your weekly medication"** (+ "self-
  reported" provenance caption where it matters); care-team
  regimen renders its actual assigned name/strength/schedule
  when present. Self-reported never looks verified.
- **Questions are records:** ObservationKind `visitQuestion`
  (append kind, UUID ids) — generated ones insert with payload
  `{"origin":"generated","rule":<id>}`, hers with
  `{"origin":"her"}`; both editable/removable pre-share; edits
  update valueText, removal deletes.
- **ConsentGrant (minimum durable):** `ConsentGrantRecord` —
  id, userId, scope ("visit_packet_sharing"), purpose,
  grantedAt, revokedAt?, orgId? (nil until a real clinic),
  append-per-event (grant + revoke rows = the audit trail).
  Inactive by default; UI = one quiet consent line in the packet
  + a small grant/revoke sheet; NOTHING is delivered anywhere in
  S3 — the share sheet is a user act on a file, not a connected
  transport (consent gates FUTURE connected sharing only, and
  revocation blocks it).
- **AI generation: none.** The packet is deterministic; valid
  offline; sparse-safe by construction.

## 2. The projection model

```
VisitPacket (Codable, Equatable)
  window: {start, end, label}
  regimen: {present, authorityLabel ("self-reported"|"care team"),
            displayLine (F1 rule), anchorWeekdayWord?,
            scheduledCount, takenCount, skippedCount,
            unrecordedCount}?            // medication section
  weight: {entryCount, firstKg?, latestKg?, directionWord
           ("easing"|"steady"|"climbing" from EMA when
           established), sufficiency}?
  symptoms: [{word, count, daysSinceDoseNote?}]   // sit-check
           aggregates; timing note ONLY when ≥2 records fall
           0-2 days post a marked dose — worded as timing
  nutrition: {proteinDaysMet, loggedDays, targetG}?  // protein
           consistency only; no calorie dump
  movement: {movedDays, stepsAvg?}?     // only when ≥7 observed
           days
  questions: [{id, text, origin}]       // editable records
  gaps: [String]                        // honest missing-info
  disclaimerLine (one sentence, restrained)
```

## 3. Sufficiency rules (tested law)

- Medication section: renders only when a regimen was ACTIVE in
  the window. Scheduled = anchor-weekday occurrences within the
  active overlap; taken = doseTaken "yes" on those days; skipped
  = "no"; unrecorded = remainder. Counts always spoken plainly
  ("marked on 3 of 4 scheduled days").
- Weight: <3 entries → the section renders counts only ("logged
  twice this period") + a sparse line; direction word requires
  the existing trend floor (≥3 entries spanning ≥5 days).
- Symptoms: any recorded sit-check renders; the timing note
  needs ≥2 qualifying records; NO causal wording ever.
- Nutrition: requires ≥5 logged days in window; protein-days
  line only ("protein reached the floor on 9 of 16 logged
  days").
- Movement: requires ≥7 days of step data; consistency wording.
- Dedup: day-singular kinds are already unique-by-day (store
  law); dose counts consider the LAST record per day; weight
  uses one-per-day latest.
- Empty packet: renders the window + "not much recorded this
  period" + what recording would add — never fabricated content.

## 4. Discussion-point rules (bounded, deterministic)

R1 unrecorded/skipped ≥ 2 scheduled doses → "you may want to
mention how the weekly rhythm is fitting."
R2 sitCheck queasy|heavy|backed up ≥ 3 in window → "worth
discussing how meals have been sitting."
R3 weight entries < 3 → "ask what weigh-in rhythm would help
between visits."
R4 timing pattern (≥2 symptom records 0-2 days post-dose) →
"your records show [word] tends to land near dose days — worth
mentioning the timing."
R5 a journalNote containing her flagged concern is NOT parsed
(no NLP) — instead the packet offers one blank "add your own
question" row.
Phrasing law: ask/discuss/records-show; never should-change/
caused/means. All removable.

## 5. Safety + privacy

Existing safety surfaces stay canonical (no new triage; the
packet never carries urgent care). One-line footer: "a personal
record, not a diagnosis or medical advice." Analytics: only
packet_opened / packet_generated_sections_count /
export_initiated / export_completed / question_edited — never
values, names, symptoms. All queries userId-scoped; sign-out
leaves records under their owner (store law).

## 6. Phases

P1 this doc → P2 engine + unit matrix → P3 ConsentGrantRecord +
migration + tests → P4 UI + questions + PDF share → P5 sim
states + suite → P6 docs/STATE. Reconciliation moment: already
spec'd (FR2) — S3 adds NOTHING beyond the consent seam it needs;
documented, not built.
