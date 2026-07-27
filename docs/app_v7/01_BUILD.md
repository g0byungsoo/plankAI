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

## Phase 2 — BECOMING INVERTED (2026-07-27)

The 12-14-page serial pager retired (thesis §2). becoming is now
overview → drill-in on a NavigationStack:

- **Landing**: masthead → **JENI'S READ OF YOUR WEEK** (the
  CoachSummary synthesis, promoted from pager page ~11 to first:
  headline + why + season note + "talk it through" chat door;
  silent under its own 2-story data floor) → **HER SIGNALS**, a
  vertical hairline index — every live signal as kicker + its
  current one-line read (the SAME generators the full pages use,
  so index and page never disagree) + chevron.
- **Drill-in**: each row PUSHES the existing full-bleed story page
  (untouched builders) wrapped in a ScrollView (accessibility
  sizes finally have somewhere to go), closed by the roman folio
  ("iii · of xii", the romanOrnament token's intended use). System
  back button + back-swipe — platform muscle memory instead of
  9-11 sequential swipes with a haptic each.
- **Motion**: `isArmed` is now simply true — a push arrival is a
  first viewing; the per-swipe re-arm theater died with the pager.
  The page-swipe haptic died with it (navigation goes quiet).
- `.summary` left the page set (the landing carries it);
  `JKPageDots` no longer renders here; `--uitest-becoming-page N`
  now pushes the Nth story card.

WHY: the pager taxed every visit (5pt ~1.3:1 dots, no random
access, fixed canvases that crushed AX sizes) and hid the app's
best artifact at its far end. Three panel experts converged on
exactly this rebuild (hig-ada transformative, interaction high,
product-strategy high).

## v7.1-3 — the founder-feedback rounds (same day)

Three live founder calls, encoded:

1. **"i loved the carousel"** → the becoming drill-in is the
   full-bleed swipeable carousel again (entered from the index at
   the tapped story, roman folio live, page-swipe haptic back).
   The index stays as the map; the access fixes hold.
2. **"home 100x more minimal, modern, premium"** → THE QUIET
   HOME: whispered date masthead (day pill + archetype chip
   dead), TYPE-FIRST ask (cocoa slab → short cocoa rule + 27pt
   serif + reason; completion strikes the line and lands the
   seal), both section-seam headers dead (the numbers stand as a
   quiet receipt column), cycle ask at the foot.
3. **"copy the onboarding screens; instantly see the list + the
   program"** → the program line is the masthead's second tracked
   eyebrow (day 12 · week 2 of 20 · finding steady ›, full-width,
   opens the journey); plan moves render in the signed
   OV5SelectRow grammar (26pt leading radio, 19pt label, the
   cross-off strike, decided fade) — and the radio is an honest
   one-tap kept toggle firing ActivationHaptics.crossOff (the
   onboarding's felt vocabulary finally on the daily loop; tap
   again undoes; long-press keeps MarkAsDoneSheet; named a11y
   action).

4. **"too many things above the list — status/messages become
   one-time full screens"** → THE LETTER: the day's reading
   presents ONCE per day as the full-screen JeniNoteView moment
   (letterhead · cascade · reply → chat · keep it ♥) on the
   day's first open (`letter.presentedDayKey`; quiet on breaks;
   `--uitest-letter` forces it, plain QA args suppress it so
   walkers stay deterministic). Home keeps a one-line FROM JENI
   whisper (tap to re-read); the ask + list land in the top
   third. The v7 one-thread law still holds — the letter's reply
   door opens the jeni thread.

309/309 tests after each round. Founder-direction memory:
`feedback_v7_home_becoming_direction`.

## Phase 3 (first slice) — the letter's memory (2026-07-27)

- **Comeback tiers** replace the flat ≥2-day template: 2-3 days
  light ("weekends happen"); 4-13 days cites the watched fact
  (gap steps daily average — provenance: 3+ real days or silence);
  14+ softens to one-plate re-entry (matching the care plan's
  gentle tone at 4+ days).
- **THE NAMED WIN** (celebration ladder tier 2): the first
  established down-week on record is named once — day-keyed
  (`wins.firstDownWeek.dayKey`) so the letter holds all day, then
  retires forever. Priority: care outranks celebration (tender
  mornings stay gentle); comeback outranks both.
- **The weigh-eve pre-frame** on the evening close: "the scale
  tomorrow reads the week, not tonight ♥" on scheduled scale
  eves (cadence math, not stale fallbacks; numerics-suppressed
  cohorts excluded).
- `DailyBriefLetterTests` — the cascade's first test coverage
  (7 tables). Orphans swept: JKOneThingCard (−162), JKDayRail
  (earlier, −171).
- Debt noted: `wins.firstDownWeek.dayKey` should join the
  sign-out sweep list with the other user-scoped keys.

Still open in phase 3: the truly-unprompted letters (tender
evening → same-evening letter + jeni-tab badge; plateau-break),
the celebration ladder's earned-moment tier, tonight-plan
follow-through question.

## QA args (Phase 1)

Unchanged: `--uitest-inapp-qa --uitest-pro-access
--uitest-seed-program --uitest-force-signals --uitest-force-day|
--uitest-force-evening --uitest-today-bottom`.
Moved: `--uitest-open-window-sheet` + `--uitest-open-night-sheet`
now live on the noticed band (same behavior).
