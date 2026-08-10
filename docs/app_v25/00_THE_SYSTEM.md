# APP v25 — THE SYSTEM (the master product plan)

2026-08-10 · branch feat/app-v2 · status: CANONICAL for the eras that
follow. `BRIEF.md` is the founder's directive; this document is its
executed answer. Ground truth in `audit/00..03`; category + science in
`research/r1..r6` (every claim there carries its source URL; this
document cites the files and names only the strongest sources inline).
`02_AUDIT.md` holds the per-system verdicts this plan builds on.
Where this document is silent, the standing canon rules
(`audit/00_canon.md` §1: the invariant laws).

---

## 1. PRODUCT THESIS

**Jeni is one adaptive weight-loss system.** It answers one question
better every week she uses it:

> "what should i do today to lose weight safely and sustainably?"

Food, weight, medication, steps, sleep, activity, adherence, symptoms,
behavior, progress, and clinician instructions are SIGNALS. They feed
ONE program. They do not become dashboards.

- **Today** is where the program becomes action — never more than
  three meaningful asks, composed, not listed.
- **Jeni** is where the program becomes understanding — on demand,
  grounded in her record, never invented.
- **Becoming** is where the program becomes evidence — scopes, eras,
  and the weekly ritual where the program earns the right to change.
- **The clinician dashboard** is where care becomes configurable —
  exceptions and decisions, not charts.

**The unit of the product is the week.** The evidence is unanimous:
every mechanic that provably works is a weekly ritual with a plan
adjustment at the end (r6 §8, r3 §2), adaptive goals recalibrate off
recent history (r4 §2), titration runs on a 4-week clock (r5 §1), and
the medication itself is weekly. Jeni's week has a physiological
anchor no competitor has: **dose day**. Days are for acting; the week
is for adapting.

**What Jeni is NOT:**
- not ten trackers in a coat — a signal that creates no action or
  understanding does not get a surface
- not a chatbot bolted onto a tracker — Jeni speaks from her record or
  not at all
- not a content library — teaching happens at the moment it applies
- not a fitness app — movement exists to protect the loss, not to
  compete with Nike
- not an EHR, not a prescriber, not a diagnostic device — Jeni carries
  the clinician's plan and repeats label facts; it never decides doses
- not two apps — the clinic patient gets the same Jeni with different
  authority, never a different product
- not an engagement machine — no streak chains, no guilt, no phantom
  urgency; the goal is useful repeated behavior, not opens

---

## 2. USER MODES + THE AUTHORITY HIERARCHY

Two modes, one app, one Jeni. **Mode is state, not build**: a
clinic-connected patient is a consumer account with a live care
relationship (care entitlement · consent scopes · assigned protocol).
Everything below composes through existing chokepoints; nothing forks
(module contract, v22).

### The hierarchy

Three authorities can shape the program:

1. **CLINICIAN PRESCRIBED** — regimens, targets, program templates,
   check-in cadence. Authored server-side only (S4 law: iOS writes
   `authority=self` alone; RPC-only; audited). The patient cannot edit
   a prescribed fact — she can flag it (the 164.526-shaped correction
   door, shipped).
2. **JENI RECOMMENDED** — every adaptive suggestion. A recommendation
   NEVER self-applies. It becomes real only through consent (the
   weekly read's one offer, or an explicit accept elsewhere).
3. **USER PREFERRED** — her explicit choices. They beat Jeni's
   recommendations always, and yield only to prescriptions.

**Render precedence: prescribed › preferred › recommended › default.**

**The no-silent-overwrite law**: any time a higher authority changes a
fact she lives with, the change is ANNOUNCED and reconciled in a named
moment — the FR2 reconciliation precedent (a care plan arriving retires
the self plan visibly, history intact). Jeni never quietly rewrites;
the clinician never silently appears inside her day; her preference is
never silently discarded — if a prescription overrides it, the
reconciliation moment says so.

### What differs by mode (the complete list)

| | consumer | clinic-connected |
|---|---|---|
| onboarding | the consult | THE DOOR: code → clinical intake, zero conversion beats |
| paywall | keep wall | bypassed by care entitlement |
| medication | self-authored chains | care_team chains, read-only + correction door |
| today | jeni-composed | same anatomy; prescribed leads promoted (C8/dose-day precedent) |
| becoming | standard order | YOUR CARE first; packet → live connection |
| weekly read | jeni's offer | prescribed facts framed as her clinician's plan; jeni offers only in unprescribed space |
| chat | standard redlines | + clinic emphasis toggles (§10); same jeni, same voice |
| data | hers alone | consented scopes only, lookback-bounded, revocable, audited |

A clinic patient with ZERO configuration has the complete consumer
program — excellent defaults are the product; configuration is the
exception (brief; r5 §6 confirms clinicians configure little).

---

## 3. RESEARCH (the record)

Six cited reports: `research/r1_glp1_companions.md` ·
`r2_food_logging.md` · `r3_behavior_content.md` ·
`r4_movement_sleep.md` · `r5_clinical_rpm.md` ·
`r6_retention_notifications.md`. Claims labeled PROVEN / PROMISING /
CLAIMED / CONVENTION / GIMMICK with URLs. The findings this plan
stands on:

1. **Self-monitoring IS the intervention** (r3, Noom's own 11k-user
   analysis: meal logging predicts outcomes ~3-4× better than article
   reading). Lesson libraries are evidence-dead; weekly review rituals
   with templated feedback are PROVEN (templated BEAT counselor-
   crafted in a factorial trial).
2. **Rituals, not content, retain** (r6): Oura's morning reveal,
   WHOOP's monday, MacroFactor's check-in that ends in new targets.
   Weight apps die of logging fatigue in days 1-14 — exactly our
   W1→W2 collapse — and tracking burnout at weeks 8-12.
3. **Adaptive goals are the domain's strongest behavioral mechanic**
   (r4, Adams 2017/CalFit): 60th percentile of her own last ~9 days
   beat static 10k by ~+1,000 steps/day, 58% vs 22% attainment. Goals
   must breathe DOWN. 10,000 is a 1965 pedometer slogan.
4. **The category's most-loved feature is pseudo-science** (r1): the
   estimated med-level curve fails pharmacology review (8-72h peak
   variance). Our provenance law already refused it; the honest
   substitute — cycle-day framing + food-noise-vs-dose-timing — is
   the category's best unclaimed idea.
5. **Photo AI is ±30% and portion volume is unsolved** (r2, NUTRITION
   2026: consumer apps undercount by ~⅓). The winning pipeline is
   vision → verified-DB grounding → history priors → ONE clarifying
   question → corrections stored as priors. Trust, not accuracy
   claims, is the differentiator (Cal AI was removed by Apple).
6. **GLP-1 has exactly two proven content pillars** (r3/r4): protein
   1.2-2.0 g/kg and resistance 2-3×/wk (lean mass = 25-40% of
   drug-induced loss; users' steps DROP after starting). Everything
   else is support.
7. **The clinic's problem is churn, not data** (r5): 50% discontinue
   by month 12; 41% suffer side effects in silence; 11% self-adjust
   doses secretly. Only FOUR between-visit signals map to clinician
   decisions; alert fatigue is proven (74-99% non-actionable);
   exception queues + a pre-visit one-pager are the evidence-backed
   design. RPM billing is a mirage for manual app data.
8. **Notification volume is a hard budget** (r6): >6/week = 3.4×
   uninstall risk; batching beats ad-hoc (RCT); medication reminder
   actions are the best-evidenced category (shipped in v24); JITAI
   receptivity-timing adds +15-40%; effects decay — instrument like
   an MRT.
9. **The trust vacuum is the opening** (r1/r2): Cal AI removed, Hims
   FTC-sued, Zealthy FTC/DOJ/FDA, MeAgain's paywalled log hated.
   Privacy-first, honest-register, record-stays-free is an open lane
   that happens to be Jeni's existing law.
10. **Regulatory lines are workable and close** (r5): HCP-facing
    dashboards fit the Jan-2026 CDS exemption if built to §520(o);
    patient-facing recommendations get NO exemption — general-wellness
    framing holds; state AI laws (IL/CA/TX, in force) require AI
    identity disclosure and ban clinician impersonation.

---

## 4. CURRENT PRODUCT AUDIT

`02_AUDIT.md` is the full ten-question audit. The ledger:

**KEEP** — onboarding v8 · cohort routing · Home/Today anatomy ·
medication v24 (additive gaps only) · weight · body scan · sleep
(quiet) · settings · paywall (exempt) · auth/sync.
**IMPROVE** — Today's composition (new beat types) · Jeni chat
(longitudinal tools) · food pipeline (corrections/memory/one question)
· steps (adaptive goal) · Becoming (gains the weekly read) · care
platform (queue + one-pager + knobs).
**REBUILD** — the method (library → trigger-tagged atoms + moment
tools) · notifications (five schedulers → one brain) · analytics
coverage (v24 shipped zero events).
**REMOVE** — the workout library (128 exercises/1,105 clips/Lottie;
strength floor replaces it) · trial machinery · PlankEngine ·
PlankVoice · StepsPulseTile · v4/v5 onboarding flows · skeleton EFs ·
orphaned analytics constants.
**DEMOTE** — breathwork (pillar → the craving/wind-down tool).

---

## 5. INFORMATION ARCHITECTURE

The four tabs stand. Nothing new earns a tab.

- **TODAY** — the calendar strip · the hero carousel · THE PROGRAM
  (lead + ≤2 supports; dose day leads on dose days; the walking action
  when the gap is within reach; the strength session on its 2 days;
  daily med cadence rides outside the cap) · tools (snap · weigh in ·
  body check-in · **right now** (the moment-tools shelf, replacing the
  method tile) · move) · the evening close. HOME'S LAW untouched.
- **JENI** — the letter + the conversation. Understanding on demand
  over her record (§8). Proactive content does NOT live here; the desk
  stays quiet.
- **SCAN** — the action door (plate / body). Never a destination.
- **BECOMING** — the body card · scope bar · tiles (12, incl.
  medication) · **THE WEEKLY READ** (the ritual; §7) · THE BOOK ·
  the record/eras · visit packet · re-signing. Evidence, always
  provenance-stamped.
- **SETTINGS** — account · notifications (per-category, understandable,
  the brain's controls) · your medication (THE REGIMEN home) · your
  care team · food · apple health · body vision · pace.
- **CLINICIAN DASHBOARD** (web) — the queue · roster · patient detail
  (trend, dose ledger, symptom timeline) · the one-pager · program
  assignment · audit. §11.

Placement rules (from the brief's "determine what belongs where"):
- an insight that requires no action → Becoming (or the weekly read)
- an insight that changes today → a Today composition change, silently
- an insight she should feel NOW, off-app → a notification (if the
  brain's budget admits it)
- a question → Jeni
- a decision → the weekly read (consumer) or the clinician (connected)

---

## 6. DATA ARCHITECTURE

**Existing spine (unchanged):** CohortStore (identity) ·
TargetsService (numeric truth) · CareProtocol (served clinical
constants) · RegimenService + DoseEventStore (medication chains) ·
ObservationStore (symptoms/feelings/doses) · FoodLogPersister (JSONL)
+ food_logs payload ledger · weight_logs + EMA/bands · HealthKit
services (steps/sleep/bodyMass/vitals) · 17-table typed sync ·
patterns engines (food week, medication).

**New, minimal:**
1. **`program_facts`** — the adaptive program's memory. Append-only
   chain per kind (`stepGoal` · `proteinFloor` · `kcalTarget` ·
   `strengthCadence` · `walkAfterMeal` · `weighCadence` ·
   `notificationPosture` …): value, **authority**
   (prescribed/recommended/preferred/default), **basis**
   (measured/stated/inferred/assigned), source (weekly_read / user /
   clinic / onboarding / migration), supersedes_id, accepted_at.
   The v24 supersede-never-mutate pattern, generalized. TargetsService
   and CarePlanEngine read the head of each chain; nothing else
   changes. Migration is additive; local-first until applied.
2. **`weekly_reads`** — one row per ritual: window, the facts shown
   (compact), the offer made, the answer (accepted/declined/ignored).
   The program's court record — why every change happened.
3. **Notification ledger** — local: per-category sent/opened/ignored
   counts feeding the brain's auto-silence; analytics mirrors counts
   only.
4. **Food correction priors** — corrections already land in the
   payload ledger; a small local index (dish-key → portion/ingredient
   priors) feeds the EF hint field. No new tables.

**Signal flow:** HealthKit + logs + doses + symptoms → stores →
pattern engines (floor-gated, timing-never-causality) → (a)
CarePlanEngine composes Today within its caps; (b) the weekly read
drafts ONE offer; (c) the notification brain arbitrates candidates
against the budget; (d) CoachContextAssembler serves compact,
provenance-stamped context to chat; (e) consented/prescribed changes
land in program_facts; (f) clinic-scoped projections feed the queue
and the one-pager (RPC-only, consent-bounded).

---

## 7. THE ADAPTIVE PROGRAM

Not a new engine. **The adaptive program = the existing chokepoints +
one new memory (program_facts) + one new ritual (the weekly read).**
Anything else would fork authority (canon tension 2).

**Inputs** — goal + cohort (stated) · weight trend/EMA (measured) ·
food record incl. protein/fiber + fractions (measured, sparse-honest)
· steps + recent percentiles (measured) · sleep timing/duration
(measured, phone-honest) · dose events + regimen era (measured) ·
symptoms (stated) · adherence textures (which asks get done/ignored —
measured) · patterns (inferred, ≥3 floor) · clinician instructions
(assigned) · preferences (stated).

**Rules:**
- **Daily composition** (CarePlanEngine, existing caps): the day
  reads program_facts heads + state; picks 1 lead + ≤2 supports.
  New beat types: the walking gap, post-meal walk, strength session,
  moment-relevant support. Gentle-day law stands (a hard day composes
  down to the dose alone). Prescribed beats lead by law.
- **Weekly adaptation** (THE WEEKLY READ): anchored the morning after
  dose day (her chosen morning when no regimen). Grammar: her week vs
  her own 3-week average → what the record shows (eras, patterns,
  floors met) → ONE teaching that explains it (§9 method) → **ONE
  offer** from the closed safe set (step-goal recalc · protein floor
  hold/adjust · strength cadence · weigh cadence · lighter-logging
  mode · notification posture · walk timing). Accept = a consented
  program_facts version. Decline = recorded, respected, re-offerable
  no sooner than 2 weeks. ≤1 change/week total (the v4 re-signing law,
  now the system's write-rate).
- **Immediate adaptation is composition, never mutation**: a short
  night composes an easier day; it never edits a target.
- **Relief is structural**: goals breathe down after hard weeks;
  1-2 effort-free days/week; a return after a gap gets a smaller day,
  not an apology ritual.

**Uncertainty** — every fact carries basis; inferred facts render
with hedge language and never drive offers alone (patterns corroborate
measured signals); missing data composes a smaller honest day, never a
guessed one; "unrecorded is not skipped" (S3 law) holds everywhere.

**Outputs** — the day's ≤3 · the week's one offer · notification
candidates (brain-arbitrated) · chat context · clinic projections.
Never a 14-item checklist; never a score.

**Overrides** — she can change any preferred fact in settings/pace
anytime (authority=preferred; Jeni stops recommending against it);
prescribed facts show the correction door; every override is a
first-class recorded answer, not deviance.

---

## 8. JENI INTELLIGENCE

The chat becomes the system's voice, not its brain. Foundations are
live (7 tools + confirm cards, provenance-only context, medication
envelope, crisis/ED local routing, server keys + budgets).

**Tools (add — read tools over the SAME stores the surfaces render):**
`read_food_week` (days logged, protein vs floor, fiber, fractions,
repeat dishes) · `read_weight_trend` (EMA, band words, era overlay) ·
`read_dose_history` (era chain, adherence texture, late/skip reasons)
· `read_patterns` (the engines' floor-gated observations) ·
`read_activity` (steps percentiles, walks, strength sessions) ·
`read_sleep` (timing/duration words) · `read_program` (current facts +
their authority + what changed when) · existing action tools. Answers
cite the record ("your last three fridays…"), state their basis, and
say "i don't have that" when the record is silent.

**Context envelope** — stays compact + provenance-stamped; grows
program{} (facts + authority) and week{} (the weekly read's compact)
blocks beside medication{}. Chat NEVER receives body-scan imagery
(L4), raw notes beyond scoped need, or anything analytics-forbidden.

**Safety** — the standing redlines (never dose advice, never
diagnosis, label facts + "your prescriber decides", crisis/ED fixed
local responses) + the founder's eight example questions become the
acceptance tests. AI-identity disclosure (CA/IL/TX, in force): a
plain line at first chat + settings ("jeni is a digital coach — not a
person, not your clinician"); counsel words at the compliance gate;
statute outranks the no-"AI"-in-copy style law where they collide.

**Proactivity** — Jeni's proactive voice lives in exactly three
places: the letter (exists, editorial), the weekly read (the ritual),
and the notification brain's ≤5/week (payload always her own data).
The chat tab never pushes; the desk stays quiet.

---

## 9. FEATURE STRATEGY

**FOOD (flagship)** — v23 stands. The era adds intelligence, not
surface: corrections-as-priors → ONE clarifying question in the EF →
meal memory ("again" as a ≤6-tap first-class repeat with corrected
priors) → partial/retro legitimacy (a 1-2 entry day is a KEPT day) →
the day-29 décrescendo (lighter modes offered, never silence) →
protein floor + fiber lead the glance layer; kcal quiet; sodium/micros
stay doors. Never: accuracy-% claims, scores, red/green, proprietary
DB, OFF imports (ODbL), photo-only identity. (r2; audit §5)

**MEDICATION** — v24 stands; additive only: cycle-day framing ("day 6
of 7 — appetite often returns about now") · food noise as a 0-10
vital tied to dose timing (the pattern engine's best new signal) ·
missed-dose LABEL FACTS at the late face (per-product, from the
catalog; facts + prescriber routing, never advice) · the maintenance
era (same chains; protein/strength/drift-watch support; regain
honesty) · the underreported-symptom vocabulary (fatigue, hair,
menstrual, temperature, mood — chips, 3 severities, no sliders) ·
switch/travel beats (era-why recorded; "your tuesday shot stays
tuesday") · HOLD/SLOW titration states + the 4-week clock (clinic).
Never: PK curves, dosing calculators, microdose presets. (r1/r5;
audit §6)

**MOVEMENT** — the library dies; the wedge is "keep what you built":
the adaptive walking action (60th-percentile goal, floor ~2,500 /
ceiling ~8,000, gap-framed, breathes down) · the post-meal walk
(food-log-triggered; glucose framing; uniquely ours) · the strength
floor for the medicated (2×/wk · 20-30 min · 4-6 movements · one hard
set · guided text; a small demo slice salvaged from the exercise
bank) · movement snacks as the zero-momentum fallback · external
workouts absorbed from HealthKit (auto-complete, never re-asked).
Never: NTC-lite, kcal-from-active-energy (28% device error +
provenance), GPS, cash-for-steps. (r4; audit §11)

**STEPS** — the 7,500 static anchor dies; the adaptive goal is the
program's first fully-adaptive fact. Consistency renders as "5 of 7"
tallies, never chains. (r4)

**SLEEP** — stays quiet: pattern input + ONE notable observed fact +
the bedtime-consistency evening anchor. Phone-only honesty: timing and
duration words, never stages, never scores. (r4 §9)

**THE METHOD → THE KNOWLEDGE ENGINE** — the library dies as a
destination. 40-80 atomic teachings (ONE IDEA ONE ACT — the v22 §4
design, finally built), trigger-tagged (event/era/pattern/question),
delivered through the food reading, dose sheet, patterns, weekly read,
and chat; era-aware sequencing off the regimen chains; the 84-lesson
corpus is salvage material. **THE MOMENT-TOOLS SHELF** (≤5,
"right now"): craving tool (breathwork's engine, urge-surf framing) ·
nausea playbook · eating-out card · plateau reframe · "food noise came
back" door. Never: completion %, content streaks/XP, lesson video, MI
sessions, psych quizzes. (r3; audit §9-10)

**BREATHWORK** — demoted into the shelf + the evening wind-down. The
engine and the honest primer survive; the pillar does not. (audit §10)

**NOTIFICATIONS → THE BRAIN** — one arbiter, hard <5/week budget,
why-now/why-her/why-open test per send, medication outranks all,
support batches into one predictable moment, per-user timing
heuristics, per-category auto-silence with a graceful card,
reminders-survive-breaks carve-out encoded, MRT-grade instrumentation
with holdouts. New admits: the weekly read, dose-day Live Activity
(experiment), milestones. Never: phantom pushes, guilt copy, marketing
in the medication category, data-free "we miss you". (r6; audit §14)

**WEIGHT/BODY** — weekly-anchored trend + passive import stand; daily
weighing stays opt-in (affective-lability evidence); body scan stays
quiet and private; monitoring-decay becomes a warm early-regain
signal. (r3/r4; audit §7-8)

**Discovered, worth naming** — the maintenance/off-ramp era is the
category's biggest unbuilt surface and Jeni's chains are born for it
(r1 §7); the trust lane (record free, honesty, privacy) is a strategy,
not a feature (r1/r2); widgets + one dose-day Live Activity are the
only iOS-surface bets that clear the evidence bar, as experiments
(r6 §6).

---

## 10. B2B CONTROL MODEL

**Prescribe** (server-authored, chains, announced via reconciliation):
medication regimen (+ HOLD/SLOW + 4-week review clock) · step/activity
target · program template (which beats exist, their cadence) ·
check-in cadence (micro-PRO ≤4 taps, titration-windowed) · weigh
cadence.

**Configure** (structured knobs ONLY — the Hippocratic
pick-and-parameterize precedent): per-patient queue thresholds ·
coach emphasis toggles (protein / hydration / dose-day support /
gentleness) · vetted education picks (which atoms are in rotation;
clinic resources as approved cards) · escalation routing (who, how,
hours) · notification posture within the patient's own budget.

**Observe** (consent-scoped, lookback-bounded, RPC-only, audited):
the four queue signals · adherence textures · weight trajectory ·
dose ledger + eras · symptom timeline (incl. the underreported set) ·
packet/one-pager · what-the-patient-flagged.

**NEVER**: free-text prompt editing of Jeni (liability; no precedent)
· patient chat transcripts (hers) · body scans (L4 — no consent scope
exists, deliberately) · silent program edits (announce or nothing) ·
messages signed as the clinic by AI (state law) · marketing to
patients · analytics beyond counts.

---

## 11. CLINICIAN DASHBOARD (minimum lovable clinical product)

Built to the §520(o) CDS-exemption criteria: HCP-facing, transparent
basis for every flag, never time-critical prediction.

1. **THE QUEUE** — the home screen. Exactly four signal classes
   (dose-gap ≥14d · weight-velocity outliers · persistent symptoms
   outside the post-escalation window · red flags, which interrupt).
   Each item: patient · signal · the record behind it · one-tap
   resolutions (reviewed / message template / adjust plan / schedule).
   Empty queue = the product working. <10 min/day is the design spec.
2. **ROSTER** — connection states, last-signal recency, silence
   detection (no data ≥N days is itself a queue candidate).
3. **PATIENT DETAIL** — weight trend (era-annotated) · dose ledger
   with gaps · symptom timeline · program facts + authority · flags
   history. No live vitals theater.
4. **THE ONE-PAGER** — the S3 packet grown up: interval summary,
   printable, the artifact a 20-minute visit actually consumes.
5. **PROGRAM ASSIGNMENT** — templates + the §10 knobs; HOLD/SLOW
   first-class; every assignment lands as a reconciliation moment on
   the patient side.
6. **WEEKLY DIGEST** — everything that didn't deserve the queue.
7. **AUDIT** — every disclosure logged (shipped S4 law).

NOT in v1: messaging/inbox (burnout evidence; structured check-ins +
digest instead) · population analytics · notes/scheduling/billing (not
an EHR) · RPM billing claims. Deploy gates unchanged: BAA · counsel ·
insurance · pilot project (S5 §15).

---

## 12. RETENTION LOOPS (the honest ones)

1. **SNAP → READING → NEXT ACTION** (daily): the plate becomes
   understanding becomes the afternoon's walk. Food is the daily
   heartbeat; repeat meals make it cheaper every week.
2. **DOSE → OBSERVE → PATTERN** (weekly): the mark, the symptom chips,
   the cycle-day frame; by week 3 the patterns speak. v24 built it;
   the food-noise vital completes it.
3. **WEEK → READ → ADAPT** (weekly, THE defining loop): dose-day-
   anchored review, her data, one teaching, one consented change. The
   program provably gets better BECAUSE she showed up — that is the
   compounding value the thesis demands.
4. **ASK → UNDERSTANDING → ACT** (on demand): longitudinal answers
   that end in a real action offer.
5. **CLINICIAN PLAN → LIVED DAY → EVIDENCE → VISIT** (monthly): the
   prescription becomes daily composition; the record becomes the
   one-pager; the visit gets shorter and better.
Anti-loops (named, banned): streak chains · guilt re-engagement ·
notification volume as growth · paywalling the record.

---

## 13. SAFETY / PRIVACY / MEDICAL BOUNDARIES

The consolidated floors (canon §4) bind every era. This plan adds:
- **The adaptation consent law**: no program fact changes without
  consent (weekly read) or prescription (announced). Silent self-
  tuning is a bug class, not a feature.
- **Label-facts framing** for missed-dose rules: per-product facts
  from the catalog, verbatim-shaped, always routed ("your prescriber
  decides what's right for you"). Never computed catch-up.
- **Red-flag catalog** versioned + remotely updatable (NAION arrived
  mid-2025 between releases); surface + route, never diagnose; mood →
  crisis resources first, clinician second.
- **AI identity disclosure** (CA/IL/TX): first-chat + settings line;
  counsel wording; never impersonate the clinic.
- **General-wellness framing** on every patient-facing recommendation
  (no CDS exemption exists for patients); the dashboard holds the
  §520(o) criteria; re-check both guidances before any claim change
  (they moved twice in Jan 2026).
- **Analytics hygiene** unchanged: counts/choices/categoricals only —
  never doses, names, sites, weights, symptom text. The new events
  (§14) are audited against this before shipping.
- Standing: no BAA → never "HIPAA compliant"; no drug brand names
  in marketing/notifications/analytics; no numeric first-party
  weight-loss claims; body privacy (L4) total; observed-never-
  prescribed everywhere the user didn't consent.

---

## 14. ANALYTICS (how we know it works)

Instrument BEFORE iterating (v24's zero-event lesson). All events
categorical; is_test_user excluded; internal testers excluded.

- **Medication** (the dark zone, first): regimen_created/superseded ·
  dose_marked {onTime|late|skipped} · reminder_action
  {taken|hour|later} · side_effect_logged {category, severity} ·
  regimen_paused/resumed · era_transition.
- **Program**: program_fact_changed {kind, authority, source} ·
  today_composed {leadKind, supportCount} · action_completed {kind,
  how: tap|auto} · walking_goal_hit · strength_session_done.
- **Weekly read**: shown · read_depth · offer_made {kind} ·
  offer_answered {accepted|declined} · read_to_action interval.
- **Notification brain**: per-category sent/opened/ignored/actioned ·
  budget_pressure · auto_silence_engaged · holdout assignment (MRT).
- **Food intelligence**: correction_made {field} · clarify_shown/
  answered · again_used · lighter_mode_offered/accepted ·
  logging_gap_reentry.
- **Clinic**: queue_item_created/resolved {signal, latency} ·
  one_pager_exported · assignment_made · reconciliation_answered.
- **North stars per system**: W1→W2 retention (the historic collapse)
  · logging half-life (target: push median past 29 days) · weekly-read
  open + accept rates · dose-adherence visibility (% doses resolved
  any way) · queue review time <10 min · notification opt-out rate
  vs volume.

---

## 15. ROADMAP (independent eras)

Scored prioritization first. Factors (1-5): user value · frequency ·
retention · WL relevance · B2C · B2B · differentiation · evidence ·
complexity (5 = cheap) · safety risk (5 = safe). Order = judgment over
the sum, dependencies respected.

| opportunity | val | freq | ret | WL | B2C | B2B | diff | evid | cheap | safe | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| adaptive spine + weekly read | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 3 | 4 | **E1** |
| notification brain | 4 | 5 | 5 | 3 | 4 | 3 | 3 | 5 | 3 | 5 | **E1** (same nervous system) |
| adaptive steps + walking action | 4 | 5 | 4 | 4 | 4 | 4 | 4 | 5 | 4 | 5 | **E1** (first adaptive fact) |
| medication gaps (cycle-day · food-noise · label facts · symptoms) | 5 | 4 | 4 | 4 | 5 | 5 | 5 | 4 | 4 | 4 | **E2** |
| maintenance era | 4 | 2 | 5 | 4 | 4 | 3 | 5 | 3 | 3 | 4 | **E2** (same chains) |
| strength floor + library kill | 4 | 3 | 3 | 5 | 4 | 4 | 4 | 5 | 3 | 5 | **E3** |
| food intelligence (corrections · memory · one question) | 5 | 5 | 4 | 4 | 5 | 3 | 4 | 4 | 3 | 5 | **E4** |
| jeni longitudinal tools | 4 | 4 | 4 | 3 | 5 | 4 | 4 | 3 | 3 | 4 | **E5** |
| method dispersal + moment tools | 3 | 3 | 3 | 3 | 4 | 4 | 3 | 4 | 3 | 5 | **E5** |
| clinic queue + one-pager + knobs | 4 | 3 | 3 | 3 | 1 | 5 | 5 | 4 | 3 | 3 | **E6** (founder gates pace it) |
| widgets + dose-day live activity | 3 | 4 | 3 | 2 | 3 | 2 | 2 | 3 | 4 | 5 | **E7** (experiments) |
| dead-weight sweep | 2 | – | – | – | 2 | 2 | – | 5 | 5 | 5 | riders on E1/E3/E5 |

### E1 — THE SPINE (the thesis made real)
- **Goal**: one adaptive program with authority + consent; the weekly
  ritual; one notification brain; the system can see itself.
- **User problem**: "what should i do today" answered by composition
  that learns weekly; W1→W2 collapse answered by the ritual.
- **Scope**: program_facts + weekly_reads (additive migration) ·
  CarePlanEngine reads fact heads · THE WEEKLY READ surface (evolving
  ReSigningView; dose-day anchor, 3-week-average grammar, one offer,
  closed safe set) · adaptive step goal + walking-gap action +
  HealthKit-workout absorption · notification brain consolidation
  (budget arbiter, timing heuristics, auto-silence, carve-outs,
  MRT holdouts) · analytics floor (§14 medication + program + read +
  brain events) · v4/v5 onboarding sweep rider.
- **Non-goals**: no new tabs · no clinic features · no food/EF changes
  · no method work · no strength content · no visual redesign of Home.
- **Dependencies**: v24 migration applied (founder gate) for synced
  dose anchors; none else.
- **Data**: program_facts · weekly_reads · notification ledger.
- **Tests**: fact-chain unit suite (supersede/consent/authority) ·
  composition goldens per cohort/mode · weekly-read walker leg + film
  · brain budget/carve-out table tests · analytics event audit.
- **Success**: weekly-read open ≥60% of active weeks, accept ≥30% of
  offers · W1→W2 retention +5pp vs pre-era cohort · notification
  opt-out flat while actioned-rate rises · zero un-consented fact
  changes (asserted in tests AND telemetry).

### E2 — THE MEDICATED YEAR (regimen depth)
- **Goal**: own the honest weekly cycle + the whole medication arc.
- **Scope**: cycle-day framing (Today + regimen home) · food-noise
  0-10 vital → pattern engine · missed-dose label facts on the late
  face (catalog-driven, versioned) · underreported-symptom vocabulary
  · switch/travel beats (era-why; wall-clock promise surfaced) ·
  maintenance era (goal-reached transition on the same chains,
  drift-watch, regain-honest register) · dose-era annotated weight
  curve (the queued chart pass).
- **Non-goals**: no PK anything · no dosing math · no clinic UI.
- **Dependencies**: E1 (the read carries cycle-day teaching; events).
- **Tests**: label-fact snapshot per product · pattern floors ·
  era-transition goldens · XXXL on new faces.
- **Success**: food-noise logging adopted by ≥30% of medicated ·
  late-dose panic path measured (label-fact card viewed → resolved) ·
  maintenance-era users retain ≥ consumer median.

### E3 — KEEP WHAT YOU BUILT (movement rebuilt)
- **Goal**: movement that protects the loss; the library dies.
- **Scope**: strength floor (2×/wk protocol, guided text + small demo
  slice, program-facts cadence, absent for non-consenting) · post-meal
  walk composition rule · movement snacks fallback · workout library
  removal (engine, clips, music, AirPlay scene; SessionLogRecord
  history preserved read-only) · breathwork demotion begins (wind-down
  in evening).
- **Non-goals**: no video production · no PT ambitions · no gym mode.
- **Dependencies**: E1 (facts + composition).
- **Tests**: composition goldens (dose-day + strength collision rules)
  · deletion leg (move tile never empty) · history render.
- **Success**: strength adoption ≥25% of medicated actives · movement
  action completion ≥ walking baseline · bundle size drop recorded ·
  zero "where did workouts go" support spikes (migration moment).

### E4 — THE PLATE'S MEMORY (food intelligence)
- **Goal**: the correction loop + memory make the reading trustworthy
  and cheap.
- **Scope**: corrections-as-priors index · EF gains history-hint +
  ONE clarifying question (server change, founder deploys) · "again"
  as ≤6-tap repeat with priors · partial/retro legitimacy in THE BOOK
  · day-29 décrescendo (lighter modes, re-entry grace) · fiber's
  quiet promotion where the regimen suggests it.
- **Non-goals**: no new DB · no accuracy marketing · no scores.
- **Dependencies**: E1 events; EF deploy is a founder gate.
- **Tests**: prior-application units · EF contract tests · book
  sparse-day goldens · repeat-flow walker ≤6 taps asserted.
- **Success**: logging half-life median >29 days · repeat share of
  logs ≥25% · correction rate observed then DECLINING per dish ·
  clarify answer rate ≥70%.

### E5 — THE DISPERSAL (knowledge engine + jeni's reads)
- **Goal**: teaching at the moment; understanding on demand.
- **Scope**: atom schema + trigger engine (ONE IDEA ONE ACT built at
  last) · corpus salvage into 40-80 atoms · delivery hooks (reading,
  dose sheet, patterns, weekly read, chat) · moment-tools shelf
  ("right now" tile; craving tool on the breath engine; nausea;
  eating-out; plateau; food-noise door) · method library retirement
  (archive → sweep) · jeni longitudinal read tools + program{}/week{}
  envelopes · AI-identity disclosure line.
- **Non-goals**: no lessons tab revival · no MI sessions · no video.
- **Dependencies**: E1 (weekly read as a delivery surface), E2
  (era-aware sequencing).
- **Tests**: trigger-match table tests · atom exhaustion rules ·
  chat tool contract tests (the founder's eight questions as
  acceptance) · shelf ≤2-tap leg.
- **Success**: atom view→act ≥15% · shelf weekly reach ≥10% of
  actives · chat sessions ending in an action offer ≥40% ·
  method-tile removal causes no retention dip (holdout).

### E6 — THE QUEUE (the clinician product)
- **Goal**: the minimum lovable clinical product (§11), deployed to
  the pilot environment when founder gates clear.
- **Scope**: queue (four signals; silence detection) · patient detail
  · one-pager v2 · program assignment with HOLD/SLOW + 4-week clock ·
  structured knobs · micro-PRO check-ins · weekly digest · dashboard
  §520(o) posture pass · deploy rail (pilot project, env guards).
- **Non-goals**: no inbox · no population analytics · no EHR features
  · no RPM claims.
- **Dependencies**: E1 facts/authority; E2 HOLD/SLOW; founder gates
  (BAA, counsel, insurance, pilot project) pace the REAL-clinic step —
  build against the demo tenant regardless.
- **Tests**: queue signal table tests (thresholds, windows) · consent
  boundary probe extension · assignment→reconciliation E2E ·
  Playwright walk.
- **Success**: demo-clinic review of a 20-patient day <10 min ·
  100% of queue items carry transparent basis · zero direct-table
  clinician reads (probe) · pilot clinic NPS on the one-pager.

### E7 — THE GLANCE (surface experiments)
- Widgets (today's state: next dose distance + protein/logging) ·
  dose-day Live Activity (site pre-selected, one "taken" action) —
  both as measured experiments with holdouts; kill if flat.
  Depends: E1 brain (so surfaces replace pushes, never add noise).

Riders on every era: dead-weight sweep for the area touched ·
walk/film verification (THE LOOP) · XXXL floors · doc-hygiene
(CLAUDE.md staleness noted in reality §DISCREPANCIES gets fixed as
areas are touched).

---

## THE DECISIONS (recorded, with the alternatives declined)

1. The adaptive program is composition + consent over existing
   chokepoints — DECLINED: a new "AdaptiveEngine" beside
   CarePlanEngine (forks authority; canon tension 2).
2. The weekly read anchors to dose day — DECLINED: sunday recap
   convention (arbitrary anchor; ours is physiological).
3. One offer per week from a closed set — DECLINED: continuous silent
   auto-tuning (violates observed-never-prescribed; MacroFactor-style
   silent recalc works for macros nerds, not this cohort's trust).
4. Cycle-day framing — DECLINED: the PK curve (category-loved,
   pseudo-quantitative, provenance-illegal).
5. The method dies as a destination — DECLINED: "better lessons"
   (the format, not the content quality, is what failed).
6. The workout library dies; a strength protocol replaces it —
   DECLINED: refreshing the library's cover (v22's queued rebuild is
   OBE — the evidence kills the form).
7. Movement = walking + strength floor + snacks — DECLINED: Pilates/
   mobility content lines (no wedge vs dedicated apps).
8. Notifications get one brain with a hard budget — DECLINED:
   per-feature scheduler autonomy (the current state; fatigue math
   forbids it).
9. Clinician tuning = structured knobs — DECLINED: free-text prompt
   editing (no precedent, unbounded liability).
10. The dashboard is a queue — DECLINED: mirror-the-app charts
    (alert-fatigue literature; "what deserves attention" is the spec).
11. No inbox in clinic v1 — DECLINED: patient↔clinician chat
    (burnout evidence; structured check-ins + digest instead).
12. Sleep stays a modifier — DECLINED: sleep tile empire/scores
    (orthosomnia + phone-honesty).
13. Record stays free at the wall's current shape — DECLINED:
    paywalling logging basics (the category's most-hated pattern).
14. Live Activity/widgets are experiments after the brain — DECLINED:
    shipping them first (they'd add noise before the budget exists).
