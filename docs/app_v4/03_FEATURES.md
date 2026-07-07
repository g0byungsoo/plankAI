# app v4 — feature contracts (entry → interaction → completion)

Date: 2026-07-06. Per-feature verdict AND the rebuilt journey. A
feature ships when its whole journey matches this contract on video,
not when its entry card looks new. Evidence tags cite
`docs/app_v4/research/*` and the v3 verified base.

Legend: REBUILD (journey torn down + rebuilt) · GROW (right bones,
new organs) · KEEP (earned) · DEMOTE · DELETE.

---

## 1. Food — snap / plates / protein / day answer — GROW+REBUILD

Jobs: log with near-zero effort (kept, snap carousel is the
signature); answer "how am I doing today?" without shame; make the
week's pattern legible; feed protein adequacy (the on-med hero).

- **THE PLATE STORY (rebuild of "today so far")**: one module, one
  visual grammar. Plates filmstrip leads (the photos ARE the story);
  under it the protein arc (single hero gauge — the twin ghost
  rings die; steps moves out to its own quiet row) + the kcal
  sentence with the DAY ANSWER in permission grammar: "dinner has
  room, about 600" / on-med low-day inversion: "your body still
  needs fuel today" (under-eating net [strong]) / suppressed
  cohorts: adequacy words only. Numbers trace to TargetsService.
- **Day-level coherence bug**: snapMeal completion writes become
  userId-scoped (the `todayKcalTotal()` seam dies); a beat can
  never contradict the band again. Unit-pinned.
- **Her plates (rebuild of the v1 journal interior)**: the
  holiday-plate empty state, pink FAB, and "scan or jot" dialect
  die. Food history lives in the journey (week pages + day
  receipts) plus one "her plates" archive page in the same receipt
  grammar: day-grouped photo rows, protein-day marks, quiet-hours
  memory line. Relog ("again") kept. Swipe-delete kept.
- Per-plate sit-check chip (on-med) stays on the carousel's note
  slide; day-level sit-check stays in the evening close.
- Snap capture/result: KEEP (founder-approved carousel; Metal sweep;
  edit math). Only seam: result → plate story updates live.

## 2. Weight — ritual / trend / band — GROW

Jobs: 30-second capture; trend literacy without scale anxiety;
maintenance zones that open actions.

- Ritual (ruler + haptic detents) KEEP.
- **One story law**: headline sentence, delta badge, and canvas all
  read the SAME window (EMA-7 vs prior EMA-7). The "−2.2 lb this
  week" raw badge dies; raw weigh-ins stay as dots + tap-in detail.
  Monday-bump pre-explanation copy joins the reading the morning
  after a weekend (fluctuation peaks Monday [strong]).
- Band (keeping): y-domain extends to always include the band
  (HONEST_GAPS #8 fix); zone crossings keep opening named weeks
  (01_PROGRAM). Losing/on-med: the canvas gains the phase ribbon
  tick marks (arc context) instead of a band.
- First-weigh + single-weigh states speak ("the line starts with
  two points — one more weigh-in and it lives").

## 3. Steps — KEEP+GROW (the honest ambient rail)

Jobs: value with zero effort; never a grade.

- Rhythm row + auto-complete KEEP; goal source stays single.
- The steps sheet regrows on the research catalog [STEPS_VALUE]:
  lead = this-week-vs-her-usual trend sentence (Apple baseline math,
  Gentler Streak register); day-vs-typical-weekday note; the gentle
  floor fact for low days ("benefit starts far lower than 10k —
  that number was marketing"); post-meal walk as the one suggested
  action (feeling-framed, not glucose-framed). The 7-day dot-band
  stays (rhythm, not magnitude bars). No streaks, no buzz
  celebrations, no timing prescriptions (evidence-null).
- Measurement honesty line in the sheet footer ("your phone
  undercounts when it stays in your bag — the trend still tells
  the truth").
- GLP-1 copy: steps NEVER sold as muscle preservation; strength +
  protein own that sentence (research correction [strong]).

## 4. Jeni Chat — KEEP+THREAD

Jobs: the voice you can talk back to; the program's memory.

- Letter register, her-file card, tools, caps, crisis routing: KEEP.
- CoachContext gains the arc (phase, week name, week receipts,
  last re-signing) so "why is this week like this?" answers itself.
- The re-signing's "talk it through" door seeds chat with the week
  receipt. The journey's day receipts link "ask jeni about this day."
- No engine/EF changes beyond additive context fields (client-side
  assembly; server contract untouched).

## 5. The Method — REBUILD (reading → practice)

Jobs: a sub-60-second daily skill DO; depth on tap; a visible skills
arc. Evidence: active tools beat reading [strong]; tiny daily DO
beats curriculum [strong]; if-then plans work menu-picked
[moderate-strong]; placement is the feature (buried tools = null)
[strong].

- **THE REP stays the daily unit** (right grammar) and grows:
  chosen-door moment keeps its fill+check+haptic; after the door,
  ONE self-referential micro-line ("which is you tonight?") when the
  scenario supports it — never a comprehension quiz.
- **THE TONIGHT PLAN**: a 15-second chip-assembled if-then plan
  (evidence-defensible [Armitage]): "tonight, if the kitchen calls
  → [ride the wave / tea first / plate it properly / early night]".
  One tap to keep; it renders on tomorrow's reading ("last night's
  plan held?") — the loop closes with a receipt, not a grade.
  Placement: offered by the rep on craving-lane days and by the
  evening close — in the flow, never a buried toolkit.
- **THE READER, Imprint-ized**: same manifest, same premium spreads,
  but paced as one-idea tap-through cards with micro-choices
  embedded in the narrative (self-referential, Ahead-style). The
  page indicator becomes progress-through-ideas. Reading length
  target ~2 minutes holds.
- **THE URGE TOOL**: the 60-second wave (breath brake) gains the
  before/after feeling dial (two taps total) — generates honest
  receipts ("the wave passed: 7 → 4") [single-arm evidence, framed
  as her own data, never a claim].
- **THE SKILLS ARC**: the journey's method layer shows acts (already
  named in the manifest) as chapters with kept-reps memory.
- Legacy JeniMethodRitual v1.1 reader + its QA cover: DELETE.

## 6. Breathwork — REBUILD (the session core)

Jobs: a genuinely premium 60s-5min downshift; the JITAI brake.
(Occasions, protocols, receipt, hand-back lines: KEEP — they're
right. The breathing minute itself is the rebuild.)

- **THE FIELD (visual)**: the static PNG dies. A generative bloom —
  layered soft-edged petal orbits drawn in TimelineView+Canvas
  (Metal shader only if Canvas can't hold 60fps on SE) — breathing
  in brand palette: cream field, rose/blush petals, cocoa center.
  Organic: petals lead/lag the scale by phase offsets so the bloom
  feels alive, not scaled.
- **BREATH-SHAPED MOTION**: asymmetric curves (inhale = gathering
  ease-in-out ~0.9 power; exhale = long settling decay; hold =
  stillness with micro-drift). Symmetric easeInOut dies.
- **CONTINUOUS HAPTICS**: CoreHaptics pattern player with intensity
  /sharpness CURVES tracking the breath phase (swell on inhale,
  long fade on exhale, silence on hold) — the discrete Timer ticks
  die. Fallback to the current pulse pattern on devices without
  CoreHaptics; reduce-motion = off.
- **NO NUMERALS mid-breath**: the countdown dies. Cycle progress =
  a ring of dots that fill per breath (glanceable, not a clock).
  Phase words stay (they're the cue vocabulary) but soften.
- **AUDIO**: the lo-fi bed stays; phase-transition breath cues
  (soft chime/breath sound) added as an option if asset quality
  allows; voice bookends keep their cascade slots.
- Entry (occasions) + completion (receipt) keep v3 designs; the
  session is presented full-bleed (no sheet chrome).

## 7. Workouts — DEMOTE holds; completion REBUILD

- Scheduled days only, 5-minute floor, "moved elsewhere" honored:
  KEEP.
- **PostRoutineView dies**: the v1 celebration (two stat pills,
  5-star row + feel chips, scatter) is replaced by the kept-receipt
  grammar: "kept." + one line (duration · what it was) + ONE feeling
  chip row (the existing intensity signal, 3 chips) + tomorrow
  whisper. Sticker scatter leaves (not an earned-3 moment). Rating
  stars die app-wide with it.
- In-session player keeps its v3 quiet-mark controls.

## 8. Becoming → THE JOURNEY — REBUILD

The whole contract lives in 02_JOURNEY.md. Legacy AnalyticsView,
BecomingDashboard, BecomingV2Atoms, `--legacy-becoming`: DELETE.

## 9. Today — GROW (the five answers, one viewport)

- what now → THE ONE THING (kept).
- how am I doing → THE PLATE STORY + quiet rows (rebuilt, above).
- what did jeni notice → the reading (kept; arc-aware lines added).
- easiest useful action → the reading's thread or snap (kept).
- **how does today connect → THE WEEK RIBBON (new)**: seven
  standing dots + "week two · finding steady", one line under the
  masthead, tap → the journey. The day-pill dead-end sheet dies.
- Evening close: KEEP (+ tonight-plan door). The 18:00 flip renders
  the receipt ABOVE the still-open one-thing (kept), but the
  "closing the day" block never hides an unfinished hero ask —
  order: receipt → still-open rows → journal line.
- Object count law holds: masthead · ribbon · reading · one thing ·
  rhythm · plate story. Nothing else.

## 10. Notifications — KEEP+SPEAK THE ARC

- Orchestrator, JITAI pings, caps, 4-site id protocol: KEEP.
- Anchor bodies gain week-intent lines (deterministic, precomputable
  — the constraint that killed reading-bodied rungs doesn't apply
  to week intents fixed on Monday). Sunday anchor becomes the
  re-signing knock ("your week's receipt is ready").
- Nothing new fires; no cadence changes.

## 11. Settings / supporting — KEEP (+ hygiene)

- ProfileHub register is fine. Gains: "your plan" row (arc position
  + re-signing history door) replacing the pace sheet's orphan
  status; break row stays.
- DELETE list (dead-code rule, same pass): HerDaysSheet,
  ProgramDayPeekSheet (replaced by future-shape card),
  FoodLogTimelineView v1 interior, PostRoutineView, legacy Becoming
  trio, JeniMethodRitual pair, Views/Plan legacy atoms not consumed
  by v4 (PlanRow, HomeArchetypeAtoms, ProgramLockSheet,
  PlanViewMicroCaption), `--legacy-today`/`--legacy-becoming`
  flags, and the jenifit:// registration gap (CFBundleURLTypes
  added so external opens work).

## 12. Cross-cutting premium bar

- ONE completion grammar app-wide: the kept-receipt (strike / "kept."
  / quiet heart) — workout, breath, rep, week all speak it.
- ONE symbol system: existing marks + three new drawn marks (phase
  tick, re-signing seal, week dot triad) — no new SF-symbol chrome
  on program surfaces.
- Haptics: the existing vocabulary + the breath curve engine + the
  re-signing's consent thunk (soft-medium pair). No spam: every
  haptic maps to a state change she caused.
- Motion: existing tokens; two new named gestures only — the ribbon
  draw-in (journey) and the breath field. Reduce-motion paths on
  every new animation site.
- Typography: no new faces; the arc uses the existing ladder
  (serif names, tracked-caps eyebrows, DMSans data).
- SE (375pt) is a first-class layout target for every new surface;
  Dynamic Type XL must not clip the ribbon, week cards, or breath
  field text.
