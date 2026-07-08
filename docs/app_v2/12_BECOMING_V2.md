# 12 — Becoming v2.1: the insight layer

Date: 2026-07-03 (second pass, same branch). Founder verdict on the
first pass: "Becoming still does not feel meaningfully rethought."
Correct — curating an 11-tile stack to 6 tiles is still a stack.
v2.1 rebuilds the surface around a different question: not "what data
do we have" but **"what does she need to understand this week?"**

## The reframe

Becoming = where she becomes smarter about her own body. Three jobs,
strictly ordered:

1. **UNDERSTAND** — the trend told as a coach's sentence with a
   mechanism, over the kept trend canvas. "the line eased down about
   500g this week." + "protein landed 5 of 7 days. that's the
   mechanism, not magic." Never a chart with a caption.
2. **LEARN** — the Method as a journey (her act, her next lesson, an
   act-progress hairline), not a lesson shelf.
3. **BELIEVE** — wins receipts: shown-up count, plates seen. Identity
   evidence in the receipt grammar.

Between 1 and 2 sit at most TWO ranked pattern insights
(`InsightEngine` cascade over `WeekState` 14-day aggregates):
protein consistency · begin-again catches (flexible-restraint
science, SCIENCE.md §5) · step patterns · GLP-1 low-appetite protein
rhythm · maintenance band-holding · showing-up fallback. Every card
ends in an ask-jeni seed — an insight is a conversation starter, not
a verdict. Provenance discipline is absolute: no data → no card;
empty states invite ("your trend line starts with two mornings"),
never fabricate.

## What the usage data said (2026-07-03 pull, 21 days)

- Food is the engagement engine: 5 of the top 6 day-2+ events are
  food; loggers average 10.5 plates. → the week receipt + protein
  insights lead the pattern layer.
- Lessons reach ~99% of purchasers (89/90 viewed) — the widest-reach
  surface in the app — but completion events fire for only 19%.
  → the Method earns the journey card placement; reader-length audit
  is a follow-up.
- Workouts: 59% try, 26% ever complete one. → workouts stay OUT of
  Becoming entirely; they live as Today beats (3-5×/wk by tier) and
  the celebration was rebuilt (emoji hero → typographic "kept.").
- Paid retention 44% D1 → 10% D7 is the fire. Becoming's job in that
  arc: give the week a *meaning* her tiles never had, so week two
  has a reason to open.
- Rage-clicks concentrate on sheets/modals (621 clicks / 222 users)
  → v2's sheet-soup reduction validated; screen-attribution wiring
  is a follow-up.

## What was removed vs v1

The 11-module stack (energy tile, protein tile, macro row, plate
timeline, moved strip, deeds counter, lighter days, NSV echo, insight
line, sleep card, depth link) does not port. Today owns live daily
state; the journal owns plates; the depth sheet (via legacy) holds
the long tail until the sweep. AnalyticsView survives behind
`--legacy-becoming` for founder comparison, then dies.

## Verified

Sim (seeded day-12 account with weight series): trend story computes
the real EMA delta and renders with the ask-jeni affordance; canvas
mounts beneath with the −2.2 lb week delta; method journey resolves
act one's day-12 lesson; week strip stays honest with no food data
("the week is young"). QA gotcha fixed en route: cloud hydration
(LWW) was resetting the seeded backdate — the seed now pushes its
backdate (pendingUpsert) and tolerates hydrated stray logs.
