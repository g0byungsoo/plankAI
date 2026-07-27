# app v7 — build record

Running log of shipped phases against `00_THESIS.md`. Every entry
records WHY, not just what. QA args at the end.

## Phase 1 — THE CARE PLAN (2026-07-27)

The Home inversion (thesis §1) + the composer (thesis §4) + the
quick accessibility/feel floors that rode along.

### The composer

- **`CarePlanEngine`** (new, `Program/`, pure, 17 tests): the day
  recomposed from state. PrescriptionEngineV2 still supplies the
  beat vocabulary and schedule floor; the engine decides WHICH
  beats render, in what role, with what reason, at what volume:
  - `tone`: gentle after a tender evening / a <6h night / 4+ days
    away — gentle days compose to ONE move, zero invitations, by
    rule (care is sometimes fewer asks).
  - `lead` promotions by clinical priority: sustained rapid loss →
    protein-first snap ("losing fast. protein first protects
    muscle"); yesterday ≥25g under the protein floor (only when
    yesterday had 2+ logged plates — absence is not deficit) →
    the deficit clause. Provenance law: no live field, no clause.
  - `supporting` (ringed, counted): the weigh-in on its cadence/
    stale day. `offered` (quiet, never counted): the scheduled
    workout (v6.4 founder law — workouts are invitations unless
    they lead), breath, and the method only on a calm day.
  - Steps is never a move; the lesson is never required (thesis
    §5); ≤3 actionable moves always.
- **Receipt arithmetic follows the plan**: `completedBeatCount` +
  the evening "N of M done" + the silk day-complete moment all
  count `carePlan.actionableBeats` — a gentle day's receipt
  matches its smaller plan. `DayModel.isOptional` adds lesson +
  steps (past-day standings read the same generous definition;
  nobody loses a kept day).
- **The feeling loop closes** (thesis §3): the evening chip is
  read back — `DailyBriefEngine.Context.yesterdayFeeling` +
  a tender clause at cascade 2.5 ("yesterday read tender. today
  asks for one small thing, nothing else ♥"), and the care plan
  runs gentle in parallel so the line and the day agree.

### The surface

- **Scroll order**: masthead → position line → THE UNDERSTANDING →
  the plan → receipts → noticed → evening. The seven-dot day rail
  DELETED (`JKDayRail`, −171 lines — its dots were unreadable:
  kept day or merely passed?); one legible line replaced it
  ("finding steady · week 2 of 20 ›", opens the journey).
- **THE UNDERSTANDING**: `JKCoachLine` grew `second` + `mechanism`
  — the reading speaks in full at 22pt serif as the page's
  reason, not a teaser above a task list.
- **Ring policy**: rings only on plan moves (lead + supporting).
  The overnight fast returned to the noticed band as an
  OBSERVATION — founder's plain name kept, the ≥12h completion
  ring deleted (four panel experts independently: a ring at 12h
  is a target in UI grammar; 00_RESEARCH §4 rule 1 wins
  mechanically). Steps became "6,420 steps · counted for you."
- **The noticed band** (was SIGNALS): "noticed for you · nothing
  to log" — fast observation, night, steps, season, moves. The
  cycle-connect offer moved OUT of the band to the day's foot
  (a permission ask is growth, not received care) as
  `TodayCycleAsk`, still one-time + self-retiring.
- **Material demotion begins** (thesis §6): sticker tiles left
  the daily rows (line marks carry them); the one-thing card's
  glossy seal now lands ON completion — the reward, not the
  furniture. `HowItWorksBlock` deleted (a Home that leads with
  the reading and a ≤3-move plan teaches its own contract).
- **Tracker grammar deleted**: the kcal budget bar died on Home
  (JKKcalLine sentence carries the same numbers); "~600 left" →
  "room for ~600" (permission frame, same fact).

### Floors that rode along

- `cocoaTertiary` 0.48 → 0.66 opacity (~4.5:1 on cream — the
  whole tracked-caps wayfinding tier was at 2.74:1, WCAG fail for
  a 35+ on-medication audience). Guarded by `TokensContrastTests`
  so no future restraint pass can ship below the floor.
- THE LANDED line rose → `jeweledRose` (16pt rose at `accent` was
  3.53:1).
- The landed-moment haptic collision fixed: `Haptics.success()`
  left `JKSilkSweep` (the visual modifier never owns feel; the
  crafted `arcComplete` swell is finally unmasked).
- The masthead camera — the hero action — meets 44pt via
  `tappableArea()`.
- Sheet law (thesis §9): no conditional content inside sheet
  closures — the night sheet (shipped BLANK when sleep data was
  nil at presentation; panel screenshot 09) now renders a fallback
  page; the window sheet moved into the band beside it.

### Founder-decision reversals encoded (authorized by the v7 brief)

- v6.4 checkable-list → care-plan grammar (the brief: "should not
  feel like productivity software").
- v6.4 fast-row ring → observation (name survives).
- Sticker row tiles → earned moments only (sticker IDENTITY
  survives, relocated to completion).

### Debts (tracked, deliberate)

- `--uitest-land-plate` still points at the old flow (unverified
  this pass); walker legs not yet re-recorded for the new Home.
- `JKKcalBar` survives in chat card + becoming until the Phase-4
  chart-grammar sweep.
- The archetype masthead note ("a protein day ♡") kept pending
  the Phase-2/4 masthead look.
- Evening rows list only plan moves — an old day's completed
  method/steps checks still count toward past standings but no
  longer render rows (correct per thesis; noting the behavior
  change).

## QA args (Phase 1)

Unchanged: `--uitest-inapp-qa --uitest-pro-access
--uitest-seed-program --uitest-force-signals --uitest-force-day|
--uitest-force-evening --uitest-today-bottom`.
Moved: `--uitest-open-window-sheet` + `--uitest-open-night-sheet`
now live on the noticed band (same behavior).
