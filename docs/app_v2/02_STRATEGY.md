# 02 — Product strategy: from trackers to a coaching relationship

## The problem v2 solves

PostHog (2026-06-21): funnel is healthy through the paywall (~87%
onboarding completion, ~14% paywall conversion) and then **retention
collapses** — W1 23.5% → W2 7.5%, 13.5% ever start a workout, food
~3%, weight logging near zero. The paywall sells a personal program;
the app delivers self-serve trackers. Churn is the gap between the
promise and the product.

Onboarding v5 raised the promise further: it shows a device demo of
a daily plan, a snap camera that says "fits today," and a steps ring,
and closes on a signed commitment at a chosen hour. v2's job is that
the first real Today screen — and every one after it — looks and
feels like the thing she was shown before she paid.

## Thesis

**One coach, one plan, one thread.** Every surface is authored by the
same two systems: the program engine (what today asks of her) and
Jeni (how it's said). The user-felt statement we are building toward:

> "Jeni knows my plan, my food, my weight trend, my routine, and
> what I'm struggling with today."

Three design consequences:

1. **Today is a ritual, not a dashboard.** It has a morning shape
   (brief + plan), a midday shape (live plate/protein state), and an
   evening shape (close the day, tomorrow preview). It is authored —
   3-5 beats chosen for *this* day — never a static checklist.
2. **Jeni is a presence, not a feature.** Her line opens the day on
   Today; her note lands on every snap; her brief seeds the chat; the
   chat closes the loop on anything the tiles can't say. Same voice
   contract everywhere (the CoachNote voice rules, revived).
3. **Everything chains.** Finishing a lesson offers the breath row;
   snapping dinner updates the protein arc on Today; a weigh-in
   redraws the trend and, when warranted, changes tomorrow's plan.
   No module is a dead-end.

## The three audiences, one engine

Cohort routing stays convergence-not-pivot (glp1_strategy doc), but
v2 finally makes the cohorts *feel* different in the daily loop, not
just in noun phrases:

- **General WL (TikTok-acquired, 22-35).** The default program:
  protein-forward days, movement days, rest days, lessons on the
  diet-brain arc, pace floors from her profile. Emotional register:
  becoming, softness-as-strength.
- **On GLP-1 (current).** Protein floor elevated (1.6 g/kg lean-mass
  frame, SCIENCE.md §1) and made the visible hero of her day; small
  frequent plates honored (appetite-rhythm key); hydration/fiber
  nudges (Phase 3.3 lines already exist); muscle-preservation lesson
  affinity (P2/P5); movement rows framed as lean-mass insurance.
  Never: dose talk, brand names, discontinuation advice.
- **Post-GLP-1 (past).** `program_mode` maintenance or gentle-loss;
  weekly rhythm emphasis (consistency beats intensity); regain-watch
  framing on the trend (window vs threshold, never alarm); P6
  keep-it-off curriculum affinity; appetite-return acknowledgment in
  briefs. The promise: "the version of you that keeps it."

## The daily loop (the retention machine)

Morning: open → Jeni's brief line (personal, provenance-backed) →
today's 3-5 beats visible in one screen-height.
Meals: snap → verdict + jeni note → protein/kcal arcs move on Today.
Any time: ask Jeni (chat) — she can open snap, log weight, adjust
reminder, explain the trend, rescue a bad day.
Evening: close-the-day beat → one-tap reflection → tomorrow preview
("tomorrow is a movement day — 15 minutes, that's all").

Weekly: Sunday recap (existing) + weigh-in cadence + week-ahead
letters on the strip. Monthly: reset weeks (already in the engine)
finally *felt* — lighter plan, permission framing.

## Retention model post-hard-paywall

- **D0**: post-purchase first-run = meet Jeni (real first chat
  message, not a video) + "first two things" (breathe 60s now, snap
  tonight at her promise hour). The demo meal she scanned in
  onboarding is cited back (onb_v5_snap_demo_meal — key exists).
- **D1**: promise push at her hour → deep-link into snap. Kept
  promise → the kept-promise card (exists) + Jeni acknowledges in
  the brief.
- **D2-D7**: the plan varies day-to-day (new engine) so opening is
  novel; lesson cadence per tier; first weigh-in prompted gently on
  day 3-4, framed as "starting your trend line," not judgment.
- **W2+**: trend line becomes the hero as data accrues; milestone
  moments; Jeni surfaces plateaus with science instead of silence
  (the #1 churn moment in WL apps is the first stall — SCIENCE.md
  §3/§4 gives the water-weight + adaptation script).
- **Bad-day recovery** is a first-class flow: "i blew it today" is a
  chat chip; the answer is the anti-shame reset + tomorrow's plan
  pre-softened. Rigid-restraint relapse is the mechanism we're
  counter-programming (Westenhoefer flexible-restraint evidence).

## Why chat is the moat

Cal AI has the camera. MyFitnessPal has the database. Nobody in the
women's WL category has a coach that actually reads her data and
speaks a consistent, emotionally intelligent register. The context
engine (05_CHAT) is the differentiator: Jeni's answers cite her real
plan, real plates, real trend — never generic. Every chat answer is
also a retention surface: it ends with the next smallest action,
linked.

## Principles (hard rules for every v2 surface)

1. Provenance: no number without a source field; no fabricated
   personalization (the v4.5 loader lesson).
2. Anti-shame: trend > number; no red food states; "tomorrow resets";
   under-target safety net for restriction/GLP-1 cohorts.
3. Compliance: Apple 5.2.1 (no drug brands), FTC (no equivalence),
   FDA (no "GLP-1 alternative"), no numeric WL claims; Jeni is not
   medical care and says so when it matters.
4. One voice: the CoachNote contract (lowercase, punch-word italics,
   ♥ terminal, concrete nouns, 2-sentence bias) governs Jeni in
   chat, briefs, notes, notifications, and empty states.
5. Quiet luxury: whitespace and hairlines over cards; one hero per
   screen; density earns its place or dies.
