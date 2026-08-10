# E2 — THE MEDICATED YEAR · execution brief

2026-08-10 · the era after E1 THE SPINE. Decision + evidence:
`07_NEXT_ERA_DECISION.md`. Law: `00_THE_SYSTEM.md` (§2 authority, §7
adaptive program, §9 MEDICATION, §13 safety). Standing canon:
`audit/00_canon.md` §1.

This is a **mandate, not a spec**. It states the problem, the
contract, and the bar. Screen design, engine shape, file layout and
sequencing are the implementing session's to invent.

---

## WHY THIS ERA

E1 built a program with memory, a weekly ritual, consent, and one
notification brain. It reads three numbers: steps, days-logged,
protein-floor-days. Its ritual is anchored to dose day and titled
"your **dose week**, read" — and says nothing about the dose.

Meanwhile the measured product has a median paying customer with **two
distinct active days, lifetime**, and a median food-logging life of
**one day**. Depth investments that require accumulated behaviour have
no population to accumulate from.

The medication cycle is the one thing in a GLP-1 user's life that
recurs whether or not the app is good. It is physical, weekly,
health-consequential, and already ritualised in the culture ("shot
day"). E1 anchored to it. This era gives it something to say — on the
first dose, from data Jeni holds the moment onboarding ends.

It is also the most differentiated ground available. The category's
most-loved artifact — the estimated medication-level curve — fails
pharmacology review (time-to-peak varies 8–72 h). Our provenance law
already forbids it. The honest substitute is unclaimed.

---

## THE USER PROBLEM

She is on a weekly injectable. She knows the week has a shape and
nobody has ever named it for her. So she reads it as her own failure.

- Day 6, the hunger comes back and the food noise returns. She thinks
  the medication has stopped working, or that she has.
- Her dose is late by a day and she panics and googles it at 11pm.
  The rules are drug-specific and no app tells her at the moment she
  needs them.
- Her hair is shedding, her period moved, she is cold all the time,
  her mood shifted after the last increase. None of it is on the
  side-effect list, so she assumes it is unrelated and says nothing —
  including to her prescriber.
- She does not want to complain, because she is losing weight.

Every one of these is a moment where Jeni can be the only app that
speaks, and every one of them arrives on a schedule Jeni already knows.

---

## THE BEHAVIOR LOOP

**dose → the week has a name → she marks what she feels → the record
speaks back → next dose arrives already understood.**

- **Dose day** — the day leads with the dose (shipped). The cycle is
  named going forward, not just backward.
- **Mid-cycle** — the day quietly reflects where in the cycle she is.
  No new asks; composition, not tasks.
- **Late cycle** — the return of appetite and food noise is *predicted
  and normalised* before she feels it, not explained after.
- **The read** — the week resolves: what the cycle did, what the
  record shows across cycles, one teaching, one offer.
- **Cycle 3 onward** — the pattern engine has floors met and starts
  speaking in her own history rather than in general truths.

The compounding horizon is three weeks. That is the only horizon a
two-active-day median can reach.

---

## THE SYSTEM CONTRACT

1. **Nothing here is advice.** Label facts are facts, attributed, and
   always routed: her prescriber decides. Patterns state timing, never
   causality. Observed-never-prescribed holds everywhere.
2. **Nothing new self-applies.** Any program change still passes
   through consent (the read's one offer) or prescription (announced
   via reconciliation). The adaptation consent law is not relaxed for
   medication.
3. **Zero leakage.** A non-medicated user and a daily-medication user
   must never see injection vocabulary or cycle framing. E1's anchor
   ladder established the pattern; extend it, do not fork it.
4. **New medication = one catalog entry.** Whatever late-dose and
   cycle facts you add ride `MedicationCatalog`, versioned, so a new
   product is data, not code. This is v24's law; keep it true.
5. **The cap holds.** Today's ≤3 meaningful asks and the notification
   brain's <5/week budget are not renegotiated by this era. Medication
   already outranks; it does not get more volume.
6. **Uncertainty renders.** Cycle framing is a tendency, not a
   prediction. "often" and "many people" are the register; her own
   record outranks the general claim the moment floors are met.
7. **Analytics stay categorical.** Never a dose, a product name, a
   site, a weight, or symptom free text.

---

## WHAT MUST BECOME TRUE

Written as outcomes, not screens.

1. **The week has a name from the first dose.** A medicated user knows
   where she is in her cycle without opening a chart, and the app said
   it before she felt it.
2. **A late dose meets facts, not silence.** At the late face, the
   correct per-product label rule is stated plainly and routed to her
   prescriber. No computed catch-up, ever.
3. **Food noise is a first-class thing she can say**, graded, tied to
   dose timing, and it becomes the honest substitute for the curve:
   "food noise has come back around day 5 in each of your last three
   cycles." Floor-gated. This is the era's signature observation.
4. **The symptoms she actually has are sayable** — fatigue, hair,
   menstrual changes, temperature, mood — chips and severities, not
   sliders. Mood routes to crisis resources first, clinician second.
5. **The read grows up.** "Your dose week" contains the dose. And the
   weekly ritual of a weight-loss app contains **weight** — trend,
   band language, provenance-honest, absent when the record is silent.
   This is the single biggest hole in the shipped spine.
6. **Becoming stops lying about the medication tile.** An active
   regimen with a history never reads "not enough to read yet".
7. **The system can finally see itself in production.** The E1 and v24
   event families fire for real users, verified in PostHog, including
   **cohort identity as a categorical property** (medicated or not,
   route, cadence). Today we cannot state what share of Jeni's users
   are medicated. After this era we can.
8. **A real user's dose day has been observed.** Not a green test —
   an observed event from a device that is not ours.

---

## WHAT WE KEEP

Everything in v24, untouched at the seam: regimen version chains and
the `applySelfRegimen` chokepoint · `DoseEventRecord`'s deterministic
per-slot ids · the schedule engine's wall-clock DST-safe behaviour and
weekly late window · the rotation that suggests and never insists ·
THE DOSE SHEET's anatomy · the actionable reminder category
(taken / in an hour / log later, never named) · the authority split on
regimen faces and the correction door · the era RECORD.

From E1: `ProgramFactStore` as the only write path for facts · the
anchor ladder · the offer set and its cooldowns · the notification
brain's budget, exempt lane and auto-silence · consent as the only way
a recommendation becomes real.

---

## WHAT WE CHANGE

- **The catalog gains label knowledge** (late window, minimum gap,
  per-product line). It currently has none.
- **The schedule engine gains the cycle** — where she is between
  doses, expressed as position, not as concentration.
- **The symptom vocabulary widens** and gains the underreported set.
- **The pattern engine gains food noise** as an input alongside the
  symptom days and protein it already accepts.
- **`WeeklyReadComposer` gains a medication movement and a weight
  signal**, and its teaching set gains cycle-aware lines.
- **Today's composition becomes cycle-aware** — the same beats,
  reasoned differently late in the cycle. New copy, not new rows.
- **Analytics move from designed to firing.**

---

## WHAT WE KILL

- The becoming tile's over-strict "not enough to read yet" floor for
  an active regimen.
- Any remaining medication copy that implies a schedule Jeni chose
  rather than carried.
- Dead food-module orphans in the area we touch, per standing law:
  `FoodCorrectionSheet` and `CaptureFlowView` are unreachable
  (`PlankAIApp` presents `PhotoCaptureView` directly) and two of that
  sheet's three affordances are non-interactive. They read as shipped
  features and are not. Sweep them.
- **A live defect, fixed with this era, not deferred to E4:**
  `SnapRefine.fixWords` sends the entire plate back to the model and
  asks for "the FULL corrected plate." Primary evidence
  (§3.1 of the decision doc) shows exactly this pattern degrades items
  the correction never mentioned. One correction must not silently
  move the calories of a dish she did not touch.

---

## WHAT WE DELIBERATELY DO NOT BUILD

- **The PK / medication-level curve.** Category-loved, pseudo-
  quantitative, provenance-illegal. The cycle frame captures the value
  without the fiction. This is the era's defining refusal.
- **Any dosing math**: catch-up schedules, calculators, microdose or
  dose-stretching presets, unit↔mg conversions, compounded-vial tools.
- **The maintenance era.** Deferred, not cancelled — Jeni has no
  at-goal users yet and the chains will still be ready when it does.
- **The dose-era annotated weight curve.** The read carries the same
  facts at lower cost; revisit as a chart pass later.
- **Clinic UI.** E6 owns the queue, the one-pager and the knobs. This
  era produces their inputs and stops.
- **A new tab, a new destination, a new score, a mascot, a streak.**
- **Any claim of equivalence between medications**, or a drug brand
  name in marketing, notifications or analytics.

---

## HOW IT CONNECTS TO E1

E1 is the reason this era is small. Everything lands through spine
that already exists:

| E1 primitive | what E2 puts through it |
|---|---|
| the anchor ladder | already dose-anchored; now the content matches the anchor |
| `WeeklyReadComposer` | the medication movement + the weight signal |
| the offer set + cooldowns | cycle-aware offers stay inside the closed safe set |
| `ProgramFactStore` | any new fact is a versioned, authority-carrying chain — no loose keys |
| the notification brain | cycle-timed sends are candidates, arbitrated like everything else; medication keeps its exempt lane and gains no volume |
| telemetry families | finally fire, in production |

If a piece of E2 cannot be expressed through an E1 primitive, that is
a signal the piece is wrong — not that the spine needs a bypass.

---

## HOW B2C EXPERIENCES IT

She never sees a feature launch. Her Tuesday gets a name. On Sunday
her app says the thing she was about to blame herself for is the
shape of the week. When her dose runs late, the app is calm and
specific and points at her prescriber. By her third cycle it stops
talking about people in general and starts talking about her.

The non-medicated user sees **none of the cycle work** — and gets the
read that finally mentions her weight. That asymmetry is deliberate
and is this era's chief cost; see the risk section.

---

## HOW B2B EXPERIENCES IT

The clinic patient gets the identical experience with clinician intent
layered in: prescribed regimen renders verbatim and read-only, the
correction door stands, HOLD/SLOW states are carried honestly if
present, and the cycle framing describes her clinician's plan rather
than Jeni's.

Everything this era captures — resolved doses, era transitions, the
symptom timeline including the underreported set, food noise — is a
**consent-scoped input to E6's queue and one-pager**. Build the record
so E6 reads it; build no clinician surface. Three of E6's four queue
signals become computable because of this era.

---

## HOW JENI CHAT PARTICIPATES

Chat explains this system; it never becomes a second one. The
medication envelope already carries product, route, cadence, dose day,
day-after-dose, recent symptoms. It should grow to carry the cycle
position and the era, so "why am I so hungry today" is answered from
her record ("you're day 6 of 7") rather than from general knowledge.

Redlines unchanged and absolute: never a dose recommendation, never a
diagnosis, never a catch-up schedule. Label facts plus "your
prescriber decides what's right for you." Crisis and ED routing stay
local and fixed. AI-identity disclosure applies.

---

## HOW THE WEEKLY READ PARTICIPATES

The read is where this era resolves, and the era's success is
inseparable from the read getting better. It should be able to say, in
her voice and inside its existing grammar:

- what the cycle did this week
- what her weight trend is doing, honestly, with provenance and no
  debt language on a down week
- one floor-gated observation across cycles when the record earns it
- one teaching that explains what she just read
- ONE offer, from the closed safe set, consented

Grammar, cap, cooldowns and anti-shame register are unchanged. The
read gets richer, never longer.

---

## HOW TODAY PARTICIPATES

Today changes reason, not shape. The ≤3 cap holds; the dose still
leads on dose days; supports still ride outside the cap. What changes
is that the same beats are chosen and phrased with the cycle in mind —
a late-cycle day composes differently from a day-2 day, and a hard day
still composes down to the dose alone.

No new row types. No cycle widget. If Today grows a fourth ask, the
era is wrong.

---

## WHAT DATA COMPOUNDS

- **The era chain × the symptom timeline** — every cycle makes the
  pattern engine's floors more reachable and its observations more
  specific. This is Jeni's only longitudinal asset that a competitor
  cannot buy.
- **The food-noise series against dose timing** — the honest
  substitute for the curve, and the single most-cited "aha" in the
  category. It gets better on a three-week clock.
- **Adherence texture** — not a score; the shape of how doses get
  resolved, which is exactly what a prescriber cannot see between
  visits.
- **Cohort identity** — the first time Jeni can segment its own
  population, which changes every prioritisation after this one.

---

## WHAT SUCCESS LOOKS LIKE

Measured in production, on real users, or it did not happen. Baselines
where we have them; where we do not, this era establishes them.

**Must establish (we are blind today):**
- share of active users who are medicated, by route and cadence
- dose resolution rate: % of scheduled slots resolved any way, week 1
  and week 4
- weekly read: eligible → surfaced → opened → offer answered
- the ur-metric, tracked against a real baseline: **median distinct
  active days per paying customer (today: 2.0)**

**Targets:**
- ≥60% of medicated actives resolve their first four doses
- ≥30% of medicated actives log food noise at least once by cycle 3
- late-dose label card viewed → dose resolved within 48h, measured
- notification opt-out rate flat while medication actioned-rate rises
- zero un-consented program-fact changes, in tests **and** telemetry

**And the gate that outranks all of them:** a real user, not on our
payroll, marks a dose on a build containing this era.

---

## WHAT CAN GO DANGEROUSLY WRONG

1. **A label fact is wrong, or reads as advice.** This is the era's
   only genuine safety surface. Per-product facts must be
   snapshot-tested against the source labelling, versioned, remotely
   correctable, and phrased as facts plus routing. If a line could be
   read as "take it now", it is wrong. When in doubt, say less and
   route sooner.
2. **The cycle frame becomes a prediction.** "You will be hungry
   Thursday" is a claim Jeni cannot make; "appetite often returns
   about now" is one she can. Drift here recreates the PK curve in
   prose — the exact thing this era refuses.
3. **GLP-1 vocabulary leaks** to a non-medicated or daily-medication
   user. E1 proved this can be held; it must be pinned again for every
   new surface.
4. **The medicated share turns out to be small.** We are choosing an
   era for a cohort we cannot currently size. **Kill/redirect trigger:
   instrument cohort identity FIRST, in the first days of the era. If
   the medicated share of active users is materially smaller than the
   cohort strategy assumes, stop and re-scope toward the read + weight
   + telemetry spine work, which serves everyone.** This is the honest
   hedge and it costs almost nothing.
5. **Notification creep.** Cycle awareness makes it tempting to add
   sends. The budget is hard and medication already outranks. More
   volume is how this era becomes an uninstall driver.
6. **Symptom capture becomes surveillance.** More symptoms must not
   mean more asking. Chips at the moments that already exist; never a
   daily questionnaire.
7. **Mood handled as a symptom.** It routes to crisis resources first,
   always, before anything else happens with it.
8. **The era ships into a repository, not a phone.** `feat/app-v2` is
   448 commits ahead of `main` and contains four unreleased eras. If
   E2 ends as the fifth, its success section is unmeasurable and the
   next decision is as blind as this one was. The founder gates —
   migrations `20260809090000` and `20260810090000`, the `jeni-chat`
   and `food-vision` deploys, key rotation, device walks, the App
   Store — are the highest-leverage work in the project and are not
   work this session can do. Plan the era so it lands *with* that
   release.

---

## FOR THE IMPLEMENTING SESSION

Read `07_NEXT_ERA_DECISION.md` first — especially §2 (what users
actually do) and §3.1 (where the existing research record is wrong).
Then `00_THE_SYSTEM.md` §9 MEDICATION, `05_E1_SPINE.md` for the
primitives, and `docs/app_v24/00_REGIMEN.md` for the laws you must not
break.

Then decide how to build it. The engines are pure and testable, the
chokepoints exist, and the surfaces are already the right shape. The
hard part of this era is not architecture — it is voice, honesty, and
knowing what to leave out.
