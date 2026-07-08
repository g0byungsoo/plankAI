# app v3 — the product thesis

Date: 2026-07-05. Branch `feat/app-v2` (continuing as v3.0).
Inputs: docs/app_v2/* (the v2 rebuild + its 33-doc trail),
docs/app_v2/SCIENCE.md (verified), research/GLP1_RESEARCH_2026_07_05.md
(verified, 3-vote adversarial), research/UX_PATTERNS_2026_07_05.md,
PostHog 21-day pull (14_V21_NOTES), code-reality + production-safety
agent maps (WORKING_NOTES.md), and my own simulator audit of the
current build.

This document supersedes 16_PRODUCT_THESIS.md where they disagree.

---

## 1. The diagnosis (why v2 still feels like a toolbox)

v2 fixed the plumbing: one snapshot, one targets service, one voice
contract, three coherent tabs. But the DAY MODEL survived from v1:
the day is a list of tasks the user owes the app. Four parallel
cards, empty check circles, padlocked future days, "0 of 4 this
week." The app's first message every morning is, structurally,
"here is your homework." Every strong surface (the brief line, the
reader, the snap carousel) hangs off that spine, so the whole app
inherits the checklist feeling.

The founder's insight names the fix: these users do not want to DO
an app. They will accept value that arrives on its own — steps that
count themselves, a photo that becomes a plate, a line that reads
their week, one small move. The product they'd keep is one that
UNDERSTANDS them daily for near-zero effort, not one that grades
their effort.

The evidence agrees with the insight:
- Paid retention 44% D1 → 10% D7 with a checklist Today.
- The passive/ambient surfaces perform (food = the engagement
  engine at 10.5 plates/logger; breath completes 69%); the
  obligation surfaces underperform (workouts 26% ever-complete;
  lesson completion events 19% against 99% reach).
- The winning consumer-health loop of this era (Oura, Whoop,
  Apple's Trends/Highlights) is: passive data in → one authored
  reading out → optional action. The user's job is to glance and
  feel understood, not to complete.

## 2. What JeniFit becomes

**A daily weight-care companion for women: one program with three
chapters — losing, on-medication, keeping — where every open starts
with Jeni's reading of her actual day, and asks for at most one
small thing.**

The felt contract, in her words:

> "It knows what's going on with me. It tells me the one thing that
> matters today. It never makes me feel behind. And it's the only
> app that didn't disappear when my medication chapter changed."

Three tenses stay: **today** (what's true now + the one move),
**jeni** (the voice you can talk back to), **becoming** (what it's
adding up to). The tabs were never the problem; the content model
was.

## 3. The three product inversions

### 3.1 Prescription-first → reading-first
Today stops opening with tasks. It opens with THE READING: 2-4
authored sentences from the (deterministic, provenance-only) brief
engine grown up — what's true about her body and week, what today
is, whether she's okay. Below it, THE ONE THING: a single
engine-chosen move for today. Below that, the rest of the day's
shape as quiet hairline rows — present, tappable, strike-on-done,
but never rendered as debt (no empty circles at rest, no locks, no
N-of-M). The state band (protein arc, steps, kcal sentence, plates)
stays — it is already ambient. After 18:00 the day flips to THE
RECEIPT (standing word + what landed + one-tap feeling + tomorrow
whisper).

Completion mechanics stay her75 (strike, tick cascade, silk) —
completion remains a FEELING; it stops being an OBLIGATION grammar.

Every open answers the founder's seven questions in one viewport:
what's happening (reading + band), what matters (reading), the one
easy thing (the one thing), am I okay (reading tone + standing
model), what Jeni noticed (reading), how it connects (reading
mechanism lines), how to not obsess (trend/band language, caps,
quiet).

### 3.2 One audience with noun-phrases → three chapters with
### different mechanics
Cohort routing stops being copy-deep and becomes structural. Same
engine, three chapter configurations:

**losing** (general WL, default) — the reading-first day above;
protein-forward; pace floors unchanged.

**on-medication** (`onboarding_glp1_status == current`) — the
chapter the shot doesn't handle:
- Protein floor is the day's hero number, framed as adequacy
  ("enough to feel strong"), 1.6 g/kg frame per the advisory.
- The UNDER-eating safety net: on low-intake days the app's posture
  inverts — "did you eat enough today?" — never a celebration of
  eating less. (White space: every competitor celebrates deficits.)
- "How did it sit?" — an optional one-tap symptom note on a snapped
  plate (nausea/fine/heavy), device-local pattern surfacing. The
  MyNetDiary insight, in our voice, next to the meal.
- An optional appetite self-note ("where's your appetite today?").
  We NEVER assert an injection-week cycle (refuted in verification);
  if her own logs show a pattern, the reading reflects HER data.
- Movement framed exclusively as keeping strength while she
  changes; lessons biased to the muscle-math and quiet-revealed
  lanes ("what you do with the quiet").

**keeping** (post-GLP-1 + program graduates; `program_mode ==
maintenance`) — the franchise bet. ~65% of non-diabetes GLP-1 users
stop within a year; nobody serves them at consumer price. The
mechanics (all RCT-anchored, see research file):
- THE BAND: a three-zone ribbon on the EMA trend around her settle
  weight — steady (~±3 lb) / drifting (3-5) / reset (5+) — the STOP
  Regain architecture, SNAP-validated in women 18-35, renamed into
  our register (never red, never alarm).
- Zone crossings OPEN ACTIONS, never just alerts (the null-trial
  lesson): drifting → a named steady-week plan + a Jeni
  conversation; reset → a supported multi-week reset arc. Intervene
  at ~1-2 kg of drift, before the documented ~4 kg procrastination
  point.
- Scoring flips to consistency: "kept weeks" (weighing pattern,
  3-plate logging floor, movement rhythm) — not streaks, not
  cumulative counts. A broken weighing PATTERN is itself the
  earliest drift signal (never scolded, gently named).
- Graduation is a designed moment (6-week settling phase → earned
  status kept via a monthly status weigh-in inside the band).
- Entry asks her, explicitly: "hold here, or keep going?" — because
  post-GLP-1 women often don't self-identify as maintainers.
- Contact intensifies for the first months after stopping (the
  inverse of classic tapering), speaking the consensus truth:
  regain pressure is physiology, not failure.

### 3.3 Lessons-to-read → practice-to-do (the Method becomes reps)
99% reach / 19% completion is an interest signal wrapped in a
format problem. The Method's daily presence becomes THE REP: a
20-40 second interactive moment — a real decision scenario in her
life ("9pm. the kitchen is calling. what's the move?"), tap an
answer, get a warm mechanism line back, optionally go deeper into
the (already premium) reader. Grammar: implementation intentions
(d=0.65), urge-surfing, flexible restraint, self-compassion — CBT
translated to practice, not psycho-education. The 84-slot manifest
becomes the rep source; the reader survives as depth ("the whole
idea, 2 minutes").

## 4. The unification mechanism (what makes it ONE program)

1. **One day-standing model.** Every day resolves to kept / partial
   / quiet (threshold: any meaningful action counts — snap, rep,
   move, weigh, breath, steps-crossed). The SAME standing renders
   in the strip dots, the past-day review, the evening receipt, the
   weekly story, and Becoming's wins. ("Shown up" is redefined
   accordingly — today it secretly counts only workouts.) The score
   grammar is KEPT DAYS: a lifetime count that never resets, plus a
   weekly rhythm with two built-in rest days (reserves as planned
   progress) and automatic repair on return — never a streak, never
   a chain (broken-streak display alone suppresses re-engagement;
   Silverman & Barasch 2023; reserves beat hard goals, Sharif & Shu).
2. **One authored-voice pipeline.** The brief engine grows into
   TheReading (morning) / TheReceipt (evening) / TheWeek (Sunday) /
   push bodies — one deterministic engine, four renders, so the
   push, the tab, and the chat never disagree.
3. **One next action.** The engine picks the day's single hero
   move; everything else is rhythm.
4. **Chat is the reading, continued.** The jeni tab opens with the
   same reading as its letterhead plus her living file (the v5
   dossier grown into the app) — never an empty room.
5. **One design dialect.** The v5 onboarding language (serif
   editorial + receipt/dossier cards + hairline rules + tracked-caps
   labels + tick rulers + trust micro-copy) becomes the app's whole
   interior. The checkbox-card dialect dies.

## 5. Feature verdicts (summary — full table in 01_FEATURE_VERDICTS)

- **Snap food**: signature, protect; add day-level "close enough"
  answer + on-GLP-1 "how did it sit?" chip. Keep ≤3 interactions.
- **Jeni chat**: the connective tissue; reading-headed surface +
  file card; tools stay; caps stay.
- **Daily program engine**: keep the spine (deterministic beats),
  re-express as reading + one thing + rhythm; reset weeks become
  real (lighter composition, not just copy).
- **Weight**: ritual stays (ruler); display philosophy = capture
  daily-capable, narrate weekly (EMA); keeping-chapter gets the
  band. Raw-number heroes die.
- **Steps**: the ambient win; unify the goal source (currently 3);
  celebrate crossings quietly.
- **Workouts**: demoted to scheduled days + 5-minute floor
  first-class + "moved elsewhere" honored; framed as strength-
  keeping. Never daily, never guilt.
- **Breathwork**: the reset — the JITAI's matched micro-move;
  60-second default; reachable in one tap from craving/stress
  contexts. Doorways speak real moments (v2.4 kept).
- **Method**: reps (new) + reader (kept as depth) + journey (kept).
- **Becoming**: the story — trend + band hero, week narrative,
  weekly receipt artifact, wins, method journey. Raw-number
  de-heroed.
- **Analytics graveyard**: nothing renders that doesn't change what
  she does next.
- **Notifications**: the orchestrator finally built to read the
  same voice pipeline; ONE daily anchor at her hour (asked at peak
  motivation — the end of her first completed ritual, not settings);
  lapse-support ping lives in weeks 0-6 only (the JITAI durability
  window); zone crossing, comeback, weekly story; hard caps; quiet
  by default. Bodies always carry news about HER.
- **Day-0 first paid session**: promoted to a first-class surface —
  55% of trial cancellations happen day 0; the first minutes after
  purchase are paywall-grade design (meet the reading, first two
  things, anchor ask at the first kept moment).
- **"On a break"**: a first-class pause state (sick / period /
  travel / a hard week) that suspends the day rhythm and all pings
  without judgment — converts "I fell off" (exit) into "I paused"
  (return path). The cheapest churn defuser in the research.
- **Past days**: every past day is a receipt (review sheet shipped
  2026-07-05 → grows into the archive). Future days: warm peek, no
  locks.

## 6. Scientific + product assumptions we are betting on

1. Reading-first daily narrative retains where checklists churn
   (Oura/Whoop pattern; our own passive-surface engagement data).
2. The STOP Regain zone architecture transfers from behavioral-loss
   maintenance to post-GLP-1 keeping (honest caveat: drug-cessation
   regain is faster; thresholds may trip sooner — we say "watch
   sooner," never claim clinical validation).
3. Micro-reps beat lessons for daily behavior practice (Duolingo
   pattern + implementation-intention evidence; our 19% completion
   is the counterfactual).
4. Protein-adequacy framing (floors) serves all three chapters
   without triggering restriction spirals (advisory-backed; safety
   gate + numeric suppression stay).
5. One authored voice across surfaces compounds trust more than
   feature volume (the commoditized-checklist finding: Noom made
   the feature bundle free; voice/loop is the moat).
6. The weekly authored receipt + consent-based re-prescription is
   the D7 artifact (automated weekly feedback matched human
   coaching at 3 months, Tate 2006; MacroFactor's check-in is the
   live product proof) — day 7 gets a scheduled reason to exist.
7. Day 0 decides the subscription (55% of trial cancellations are
   day-0; engagement quartile ≈ renewal destiny, Noom first-party).

## 7. What we will NOT do (risk fences)

- No injection-day/appetite-cycle assertions (verification refuted;
  user-discovered patterns only).
- No medication instructions of any kind (dose/timing/titration/
  side-effect management) — FDA general-wellness posture; symptom
  chip is a private note, not advice.
- No mandatory tracking, no engagement gates, no compliance
  framing (NPR-documented harm pattern; Omada backlash).
- No streak-loss mechanics, leagues, or guilt loops (Westenhoefer;
  brand DNA).
- No first-party numeric weight-loss claims; no drug brand names on
  app surfaces; no "GLP-1 alternative" framing.
- No new tabs; no nav restructure beyond content.
- No schema-breaking changes: SwiftData additive-nullable only; food
  models stay out of the container; notification ids follow the
  4-site change protocol; the three Today hooks (shown-up, session,
  anchor refresh) are re-wired, never dropped.
- No paywall/pricing/gating changes (AppPhase machine + RevenueCat
  flow untouched; founder-approved paywall design stands).
- No server/EF contract changes beyond additive prompt guidance;
  caps untouched; keys stay server-side.
- No auto-tier adaptation from performance data yet (v3.1; needs
  data volume we don't have).
- Full Method content re-authoring (84 slots) stays founder-present
  work; we ship the rep mechanic + the doc-22 sample set + a
  scalable content path.

## 8. What it should feel like

Like a note from someone who was already thinking about you before
you opened the door. Cream, serif, one hero per screen, hairlines
over cards, receipts over dashboards, the ruler over keypads, the
strike over the checkmark. Motion is few and meaningful (entrance
cascade, strike, silk, bloom). Nothing blinks, nothing counts down,
nothing is locked, nothing is red. The app never asks twice, never
grades, and always ends a moment with either quiet or one small
door.

## 9. Success metrics

- Paid D7 retention 10% → 25%+ (the fire this aims at); D30 ≥ 15%.
- Day-0: first-session ritual completion (first kept moment within
  the purchase session) ≥ 70%.
- Reading-open rate (D2+ users who see the reading daily) ≥ 60%.
- One-thing completion ≥ 40% of open days (vs ~26% workout-era).
- Snap ≥3 plates/wk retention cohort growth; anchor-notification
  opt-in at the post-ritual ask ≥ 35% (Calm saw 40%).
- Keeping chapter: weigh-pattern consistency (≥4 wk with 5+
  weigh-days) and zone-crossing action-taken rate ≥ 50%.
- Rep completion ≥ 2× lesson completion events within 30 days.
- Instrument weekly engagement quartiles in PostHog (the leading
  renewal indicator) and score every ship on retention, not
  conversion.
