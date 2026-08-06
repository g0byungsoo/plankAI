# v11 REBIRTH — THE EVIDENCE (T5, 2026-08-05)

THE LOOP's record: what was recorded, what the frames showed, what was
fixed because of them, what was deleted, and what the gates said.
Session artifacts live in the session scratchpad (`t1/`–`t5/`); the
durable record is this file plus the per-task commit messages.

## 1. What shipped (one commit per task)

| task | commit | net lines |
|---|---|---|
| T0 docs cleanup | `c5d266e` | −60,163 (275 files) |
| T1 kit + motion | `07a18ee` | +kit |
| T2 JeniChart | `fb001a4` | +engine, 17 model tests |
| T3 HOME from zero | `1da2a1b` | −1,019 |
| T4 BECOMING chart-driven | `90a3db8` | −4,742 |
| T5 loop + evidence | (this commit) | legs evolved |

Roughly **6,000 lines of superseded product code died** in T3+T4 alone;
the entire journal era (cover, chapters, page-turn, story pager, day
rail, bento vocabulary on becoming) no longer compiles into the app.

## 2. What the frames caught (the loop's yield)

Every item below was found by recording the simulator, dumping frames
at 20fps, and reading neighbours — not by code review.

1. **The skeleton beat** (T1): unindexed section headers rendered
   instantly and floated on empty paper while content arrived. Became
   kit law: THE ARRIVAL UNIT IS THE SECTION.
2. **Numerals count on film** (T1): frame 050 of the first arrival run
   caught a digit mid-roll with motion blur — L12's "numbers count"
   is not a claim, it is a frame.
3. **Histogram slabs** (T2): bars rendered ~68pt wide; the simpleness
   form is a thin comb. Bars are now 3–10pt capsules centered in
   their slots.
4. **The forked pen** (T2): gapped segments drew in parallel; the
   draw now hands off left→right, each segment owning its phase share.
5. **The missing "now"** (T2): the ink line ended nowhere; a 3.5pt
   terminal dot fades in as the draw completes.
6. **Below-the-fold gallery** (T2): ink-pixel histograms (PIL,
   `sum(hist[:120])`) proved the charts never entered the recording;
   the gallery reordered so its newest primitives are visible.
7. **An em-dash in shipped v9 engine copy** (T4): the muscle-loss
   preservation line carried " — " onto the new hero card. Voice law
   now holds in `WeeklyBodyReview`.
8. **Scatter-dot weigh-ins** (T4): the honest-gaps law made sparse
   weigh-ins render as disconnected dots. `bridgeGaps` (weigh-in
   mode) connects real measurements at their true x — daily series
   keep the gap law. Pinned by a model test.
9. **The zoom lied** (T4): a 2.6 lb decline filled 85% of canvas
   height. Weight charts now carry 0.45 y-padding so gentle reads
   gentle.
10. **The black voids** (T4): stacked max-frames let `scaledToFit`
    overflow its cap; silhouettes rendered 149pt tall. One fixed
    frame = 96pt. (A first "fix" was mis-verified as failed — pixel
    arithmetic on the frame dumps settled it.)
11. **Spark aliasing** (T4): the 1pt EMA context line aliased into
    stray dots inside 30pt tile sparks; sparks now draw ink only.
12. **The seed-contamination false alarm** (T4): a violent zigzag in
    the weight line was walker-session residue (the chat leg logs
    weights). A clean-slate reinstall proved the geometry innocent —
    recorded here because the loop must also clear the innocent.

## 3. What the walkers caught (interaction truth)

1. **The swallowed ribbon** (T3): a parent-level `JKTapWithLongPress`
   ate the week ribbon's tap AND the settings hold. Gestures moved to
   the date line only.
2. **The override law violation** (T3): my long-press quick-toggle
   bypassed MarkAsDoneSheet. Restored everywhere (lead included).
3. **THE LATENT v10 DATA BUG** (T3): marking a dose through
   MarkAsDoneSheet never wrote the `doseTaken` observation — only the
   quick-tap path did. The dual-write now lives in
   `TodayModuleState.mark()`, the chokepoint every path crosses.
4. **The tap-after-hold race** (T5): a completed long-press ALSO fired
   the Button's tap — the override sheet raced the module cover.
   JeniRow + the lead now carry the JKTapWithLongPress latch.

## 4. The gates

- **Unit suite**: 538 tests, 537 green. The 1 failure is the
  documented pre-existing V6Funnel full-suite flake family (a
  different member each run; `AppPhaseTests` 10/10 solo-green this
  session). +24 new tests since v10 (17 chart model, 6 aggregator,
  plus the bridge test).
- **UI legs, run solo**: `testWalkEveryReachableSurface` green (11
  surfaces) · `testBecomingSummaryAndReSigning` green (compare stage
  asserted via `record.compare`; tile drill-in snapped) ·
  `testHomeRowGesturesAndPastDay` green (the override contract) ·
  `testStatesLedger` / `testRestDayBreath` / `testLivedDay` /
  `testLessonRepChip` green.
- **Floors**: XXXL on the gallery, Home, Becoming (wraps, no clips);
  iPhone SE on Home + Becoming — the 3-second answer fits above the
  SE fold, and SE's sparse store rendered the BELOW-FLOOR states in
  the wild ("logging · 2 of 3 days"; the preservation read speaking
  its standing).
- **The L13 seam**: the launch recording shows loader (serif
  affirmation on paper) → Home (serif lead on paper) as one product;
  onboarding and the app now share one button (JeniPrimaryButton
  wraps JFContinueButton), one paper, one register.

## 5. Deviations + deferred (honest ledger)

- **Tile → page expansion**: the law asks for matched-geometry
  (L12); deployment floor is iOS 17 (no zoom transition API), and a
  hand-rolled matched-geometry across fullScreenCover is a
  frame-perfect project of its own. Detail pages open as covers with
  the arrival choreography. Revisit when the floor reaches 18.
- **Deferred kills with live consumers** (their supersession events
  haven't happened): `JKMasthead` + `JKQuietSeam` (chat), the bento
  family (`StepsBentoTile`/`BreathworkBentoTile`/`FoodWeekBentoTile`/
  `LastNightSleepCard` — debug harnesses + breath flow),
  `ScrapbookCard` (legacy onboarding), `JKGallery` (old kit gallery),
  `JKBreathField`/`JKSilkSweep` (live), `JKReadingDay`'s remaining
  atoms. Owners: the chat pass and the S/N cycles.
- **The evening close** kept its ledger hairlines (a receipt is a
  table; L2's spirit is anti-chrome, not anti-tabular). Its full
  editorial re-skin is a T-next candidate.
- **Movement connect door**: the below-floor tile names the path in
  words; a JeniPrimaryButton connect flow inside the detail page is
  the right next move.
- **`--uitest-seed-scans` seeds figure-era records**, so BODY
  PROGRESS demos read as solid ink blocks; real waist-band records
  render as wide plates. Consider a waist-era seed for demos.

## 6. What the founder should walk

1. Home, morning and evening (`--uitest-force-day` / `-evening`).
2. Becoming: the hero read → sodium tile → its page (the scale-noise
   answer is the product's smartest sentence).
3. The compare (BODY PROGRESS → compare across your record).
4. A long-press on any TODAY row — the override sheet.
5. The launch: loader → Home. The seam is the L13 test.
