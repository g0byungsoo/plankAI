# v21 — THE LOOP's record

Every claim below is backed by a frame, a film, or a green leg run
on the QA sim (259952D4). Baselines and films live in the session
scratchpad; the fixes live in the commits.

## The baselines (why the era exists)

- v20 Home: informative, composed — and colorless. The ring was
  40pt ink in a corner; bars were 3pt hairlines; the checklist was
  typeset lines; tools were labeled boxes. A beautifully set REPORT.
- v20 Becoming (empty state): a white card with a serif sentence
  and five rows of "logging · 0 of 3 days" — a page of words.

## Round 1 — the carousel on film

Filmed via `--uitest-walk-carousel` (new door; synthesized drags
cannot scroll this sim). Verified: pages morph (0.94/0.75
off-center), the ring traces elastic with the counted numeral
inside, dots morph, protein numeral rolls mid-transition.

Frame-caught and fixed:
1. **Double label** — "TODAY'S FOOD" over each face's own name.
   The outer label died; the calories face gained its own (v17's
   header law).
2. **The protein face left its bottom half empty** — numeral 46,
   instrument-weight bar (7pt), THE WEEK given real height, air
   distributed.
3. **Chemistry sparks read as sparse dashes** at full width —
   compact 124pt trailing columns.
4. **JeniSparkRow marks** capped at 5pt read as dashes anywhere
   wide — cap raised to 9pt, call sites bound their width.
5. **Insight bar figures** at full dusty saturation shouted over
   their own headline — receded to blush with now in berry
   (`emphasizeLast`).

## Round 2 — the sheet, the scope, the landing

- **Tile → detented sheet**: filmed via `--uitest-open-tile weight
  --uitest-walk-sheet`. The tile grows out of its grid cell, label
  and value riding the surface; the chart draws only after landing;
  detents walk medium → full → medium. The staged reveal split into
  five breaths (headline → ledger → stance → provenance).
- **Scope morph**: filmed via `--uitest-walk-scope`. Week → month:
  the capsule slides, values re-count mid-frame ("1,6…", "9…"),
  sparks re-bucket. A morph, never a reload.
- **The plate landing**: filmed via `--uitest-land-plate`. The
  numeral rolls 860 → 1,100, "613 left" counts down to "373 left",
  the ring's arc advances. Addition, never a reset — at hero scale.
- **Launch arrival**: loader → header → strip → the ring tracing
  while its numeral counts. One choreography, indexed.

## The legs (all solo, fresh test bundle)

| leg | result |
|---|---|
| unit suite | **557/557** |
| `testHomeAnatomyDayAndEvening` | passed (66s) — four blocks at both hours; the close via both paths |
| `testZeroDataFirstRun` | passed (239s) |
| `V12CraftWalkUITests` (gallery ×2) | passed |

Two leg lessons paid for and recorded:
- **The stale test bundle lies**: three runs with identical 110.58s
  and frozen line numbers were a bundle that never rebuilt.
  `rm -rf` the runner + `build-for-testing` (watch the Compiling
  line) + `test-without-building`.
- **A leg must be where it thinks it is**: the anatomy leg was
  silently asserting against a program-intro screen after the
  enrollment chain's vocabulary drifted. It now lands on Home via
  `--uitest-seed-program` (the canonical door) and its anchors are
  v21-true ("kcal"/"numbers off" instead of the dead band label);
  the tools assert scrolls until found.

## The floors (XXXL)

Frame-caught at accessibility XXXL and fixed:
- The numeral block struck through the fixed 176pt ring → at
  accessibility sizes the calories face becomes numeral + words +
  an 8pt fraction bar (information kept, no fixed-frame fight);
  sub-accessibility sizes clamp the ring's inner text to its safe
  circle.
- The one-line header truncated the greeting to fragments → stacks
  at accessibility sizes; the greeting may wrap to two lines.
- The strip's fixed 32pt discs clipped scaled digits → the strip
  clamps at xxxLarge (calendar chrome, the Apple pattern).
- Task-row titles/notes gain a second line at accessibility sizes.
- Becoming needed nothing: the card grammar scales and wraps.

## Haptic + motion audit (law §8, v14 amendments)

New call sites this era: carousel page detent `tick` (one per
change, matches scope/strip/pager grammar) · `JeniToolTile` tap
`tick` (replaces `Haptics.light`). Everything else inherited:
quick-mark `land`, long-press `land`, sheet detent `tick`, dismissal
`tick`, landing `swell` (the day's one). Charts stay silent while
drawing. The completion pulse and ring overshoot ride
`JeniMotion.elastic`; Reduce Motion renders values directly, stops
page scaling, and turns compression into fades.

## Open, deliberately

- The floating tab bar picks up a soft rose refraction at its
  material edge when rose content scrolls beneath — the system
  material working as designed; watched, not fought.
- The strip's kept-day rings (berry) had no kept days in the QA
  seed to film against; the walker's mark path exercises the state.
- `film_strip.mov` recorded the D13 travel; the recap grammar was
  already proven in v12's evidence and was not re-judged this pass.

## Round 3 — the doodle set (founder-supplied)

The founder pointed at `~/Downloads/doodle icons` (451 hand-drawn
stroke icons). Style-judged on a contact sheet: single-weight,
wobbly, confident — the stationery stroke register as a ready-made
set, more law-native than the SF exception it replaces. Adopted:

- Imported as template SVG assets (`doodle-*`, vector-preserved,
  tinted at runtime): cutlery · camera · wind · night · ruler ·
  water · user (the bust, for body check-in).
- **Authored in the same register** where the set had no glyph:
  `doodle-book`, `doodle-shoe`, `doodle-scale`,
  `doodle-footprints` — stroke ~9/160, round caps, slight wobble;
  on-screen they read as the set's own.
- `JeniTaskRow.Chip` gained `.doodle(name)`; the tool tiles' chip
  instruments went doodle; the close-the-day row wears the moon.
- **Medication stays an unadorned SF glyph** (clinical register).
- Film-caught: offered rows still built SF chips — one list read as
  two icon sets. Offered rows now share `beatChip` (one voice per
  surface, now written into law §12.6).

License note for the founder: the folder ships no license file —
worth confirming the set's terms before an App Store build.
