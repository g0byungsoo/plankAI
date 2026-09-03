# Pass 74 — research synthesis (written before the hierarchy was decided)

Three sweeps ran in parallel (weight-loss tracker landscape · GLP-1
trackers + communities · Apple/third-party chart detail patterns).
Sources: App Store review feeds pulled raw (MacroFactor, Happy Scale,
Shotsy, Cal AI, MyFitnessPal, Cronometer, Noom, BetterMe, Lose It),
product-owned forums, clinical literature (STEP-1, SURMOUNT-1,
GoodRx/Cleveland Clinic titration guidance), HIG + WWDC22 chart
guidance, MacroFactor/Happy Scale/Copilot/Whoop product docs.
"Glow" was identified as "Glow: Weight Loss AI for Women" (thin
progress surface by design; its one sharp review: users split trust —
AI coaching kept there, the RECORD moved to MyFitnessPal).

## The ranked jobs of a progress screen (evidence-weighted)

1. **"Is the number moving in the right direction, net of noise?"**
   Trend weight, unambiguously, is what long-tenure users actually
   use. Happy Scale's reviews carry unprompted 7–10-year daily-use
   testimony for a single-purpose trend app: the screen answers the
   anxious daily question ("did today wreck it?") with "no — look at
   the line." Reassurance-on-demand, not new information.
2. **"How fast, over THIS period?"** Rate wanted everywhere,
   under-satisfied even in Happy Scale. Failure mode (Cronometer,
   verbatim forum thread): a summary delta number its own chart
   contradicted — "the graphs are a much better indicator… than the
   weight change indicator." Law: a spoken number must derive from
   the drawn fold.
3. **GLP-1: "what happened at each dose?"** Weight response
   segmented by dose period is Shotsy's most-praised read ("the
   graph showing my weight loss alongside the dosage I'm on is
   incredibly motivating"). Clinical floors for honesty: ~4 weeks at
   a dose before ANY response read; 8–12 weeks at a stable dose
   before plateau language (SURMOUNT-1 median time-to-plateau is
   24–36 weeks; premature judgment is the dominant real-world
   failure — ~1 in 3 quit within a month, before an effective dose).
4. **"Is the last week making me misread the longer trend?"** The
   flat-week-inside-a-moving-month reassurance, everywhere in the
   trend-app communities.

## Distrusted / noise (all evidence classes)

- **Scores, grades, streak counters** — Cal AI's health score is
  directly contradicted by its own numbers in reviews; streak-break
  framing is named demotivating; Noom's gamified rewards read as
  friction. → Becoming's consistency card is exactly this class.
- **Generic insight copy that restates the data** (MyFitnessPal's
  "Focus areas… Logging is online!").
- **A summary number disagreeing with its own chart** (Cronometer).
- **Unprompted visual chrome changes on a trust surface**
  (Happy Scale recolor backlash) — keep the visual DNA.
- **Projections/goal dates**: appetite real, but they break trust
  the moment they move without visible reason → observed rate only,
  never a projected date. (Also compliance: no numeric promises.)
- **PK/medication-level curves**: real demand, but modeled, not
  measured — v24's standing refusal holds.
- **Cross-user comparison** ("your curve vs others on your dose") —
  against standing law; refuse.

## Chart/detail patterns adopted

- Apple Health detail anatomy: header numeral → range control →
  chart → highlights → about. Range control owns the header's
  semantics.
- MacroFactor's dual-line grammar: TREND dominant, raw subordinate
  (Jeni drew the opposite — raw in full ink, trend as hairline).
- Touch-and-hold-then-drag scrub (Apple Health) — an immediate drag
  stays a scroll.
- Event markers: thin hairline + label, never a filled glyph on the
  line; detail on demand (already Jeni's p58 grammar — confirmed
  against category precedent).
- Scrub readout speaks WHEN + how much (date · value).

## Classifications driving the hierarchy

COMMON NEED: trend-first weight story · period delta + observed rate
· distance since start · calories/protein basics · honest waiting
states.
GLP-1 NEED: per-era weight response (trend-derived) · weeks-at-dose
with a 4-week honesty gate · dose seams on the weight chart ·
symptom timing (already served by ledgers/VisitPacket).
NICE ANALYTIC: chemistry deltas (sodium/fiber) — keep, floor-gated.
NOVELTY (refused): PK curve · cross-user curves · projected dates.
NOISE (removed): the consistency streak card · duplicate weight tile
· "0 of N" grade-shaped sentences.
