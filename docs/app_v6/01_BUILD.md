# app v6 — THE SIGNALS (build record, 2026-07-17)

The passive layer shipped. Research base: `00_RESEARCH.md` (read it
first — the safety rules there are law and are ENCODED IN THE ENGINE,
not just copy). Zero new input anywhere: every signal derives from
plate timestamps, HealthKit steps/sleep, and weigh-ins the app
already holds.

## What shipped

### Engine — `PlankApp/Program/Signals.swift` (+ 22 unit tests)
- `KitchenSignal` — the overnight window as a live phase machine:
  `.overnight` (no plate yet today; counting since last plate) →
  `.settled` (first plate landed; the window is a fact) → `.evening`
  (20:00+, 90+ quiet minutes). All phases live inside QuietHours'
  8–20h sanity band. `tone(forHours:)` is the safety clamp: warm ONLY
  at 12–14h, neutral outside, `.care` at 16h+ (never praise). 7-night
  `weekStory` with median close + spread (small-hours closes fold
  past 24h so night-shift patterns don't wreck the median).
- `SleepSignal` — bands (<6 short / 6–7 light / ≥7 full) + the
  forgiveness captions; `durationWord` ("6h 12m").
- `MealMoves` — post-meal movement receipts: a plate credits the NEXT
  full clock hour, ≥250 steps ≈ Buffey's 2–5 min walking floor, one
  credit per bucket, incomplete hours never claim.
- `WeekRhythm` — weigh-day cadence over 14 days (+ flags for the dot
  figure) and the median first-plate time over 7 days (≥4 plate-days).
- `Sweetness` — 7-day sugar story: time-of-day shares + week-over-week
  direction. Floors: ≥3 sugar-days this week; direction needs ≥3 in
  BOTH weeks. Plate `sugar` is device-local since v1.1.5; older plates
  read 0 and stay silent.
- Cohort gates ride `QuietHours.mayNarrate` (restrictive-risk +
  numeric-suppressed hard-off) exactly as before.

### Home (Today) — `PlankApp/Views/Today/TodaySignals.swift`
The SIGNALS band, after the food band:
- **THE WINDOW** — serif-italic headline ("the kitchen is closed" /
  "last night's window" / "the kitchen closed for the night") over
  `JKWindowHorizon`: the night drawn as a horizon arc (dusk foot →
  dawn foot, times at the feet, hours numeral under the apex). It is
  deliberately a DIAGRAM, not a gauge — nothing fills toward a
  target, so it cannot be read as fasting progress. Live states wear
  a breathing ember at the "now" foot. Tap → `WindowSheet` (24h ring
  + the 7-night band + cited mechanism).
- **NIGHT** — crescent + "7h 41m last night" + the appetite-context
  caption. Tap → `NightSheet` (`JKSleepDial`: stage-banded dome over
  a starfield atmosphere, bed/wake bounds; the last-7-nights bars;
  Tasali mechanism + citation).
- **AFTER-MEAL MOVES** — a receipt line ("you moved after lunch ♥")
  that only exists when detected. Nothing renders on absence.
- **On-medication inversion** — the window module NEVER does hour
  arithmetic for the on-medication chapter: they get the fuel frame
  ("first plate landed at 9:15 · early fuel keeps your strength ♥",
  or a gentle waiting line after 10:00). No count-up to gamify delay.
- First-day whisper: "noticed from your plate times and your phone.
  nothing to log ♥" (renders only on the day she first meets the band).
- The old moon caption line in TodayStateBand is superseded and
  removed (`QuietHours.overnightLine` deleted with it).

### Becoming — three new story pages + one upgraded
Order: line · food · plates · **sweetness** · **window** (upgraded) ·
**sleep** · movement · **rhythm** · plan · band · reflection.
- **sweetness** — "sweet things eased this week." / "sweetness lands
  in your evenings." + `JKSweetMoments` (three soft mounds; dominant
  moment warmer). Caption: "nothing is forbidden here ♥".
- **window** (upgraded) — `JKWindowWeekBand`: 7 nights as falling
  dusk→dawn capsules over midnight/6am seams; headline picks the
  strongest true pattern (close-time consistency → median close;
  else average length; 16h+ average speaks care, never achievement).
  Single-night fallback keeps the v5 ring.
- **sleep** — "you slept about 6h 52m a night." + `JKSleepBars`
  (7h reference seam; missing nights are dots). Caption is the
  forgiveness frame, never bedtime homework.
- **rhythm** — "your weigh-in rhythm is steady." + `JKCadenceDots`
  (14-day dot rhythm, no streak numerals) + "first plate usually
  near 9:15am". Caption cites consistency-beats-intensity.
- Visuals re-arm per swipe (armed/disarm house pattern, reduce-motion
  resolves to the finished frame).

### Components + Metal — `DesignSystem/Kit/JKSignalVisuals.swift`,
`DesignSystem/Kit/SignalShaders.metal`
- `HorizonArcGeometry` + `JKWindowHorizon`, `JKCrescent`,
  `JKSleepDial`, `JKWindowWeekBand`, `JKSleepBars`, `JKCadenceDots`,
  `JKSweetMoments`. Palette tokens only; `Motion.easedFinal` fills;
  every figure is one accessibility element with a spoken sentence.
- `jkDawn` — the window arc's living light: a dawn wash whose warm
  center drifts along the arc + a breathing ember at the live tip
  (alpha-masked; time=0 under Reduce Motion = a still lit arc).
- `jkNightSky` — the sleep dial's whisper starfield (≤4% lift,
  deterministic hash twinkle).

### SleepService — `nightHistory(nights:)`
One HK query + the existing session segmenter run per morning
(anchored to each day's 18:00). Missing mornings just don't appear.

## QA args (all DEBUG-only)
- `--uitest-force-signal overnight|settled|evening` — deterministic
  Home window phase.
- `--uitest-force-night` — synthesized `LastNightSleep.sample()` +
  7-night history (sim has no HealthKit data).
- `--uitest-open-window-sheet` / `--uitest-open-night-sheet` — land
  inside the detail sheets without taps.
- `--uitest-force-signals` — seeds all four Becoming stories
  (window week / sweetness / rhythm / sleep) deterministically; the
  live HealthKit sleep read is skipped so it can't clobber the seed.
- Existing pattern preserved: `--uitest-becoming-page N` lands on a
  page (indices shift with cohort/data gating — count from the
  rendered dot rail).

## Verification (2026-07-17)
- 22 new unit tests green (SignalsTests) + full suite run.
- Simulator-verified with screenshots: Today band ×2 phases, both
  detail sheets, all four Becoming pages, SE width. Evidence shots
  in the session scratchpad (not committed, per evidence convention).
- NOTE for future sim QA: this machine sometimes runs a PARALLEL
  agent session driving `com.jellyskin.app` UI tests on the booted
  simulator — it steals foreground mid-screenshot and reads like a
  crash. Use a dedicated simulator (we used the "iPhone 17" device)
  and pass launch args as a zsh ARRAY (`"${BASE[@]}"` — an unquoted
  `$VAR` does NOT word-split in zsh and arrives as one garbage arg).

## Round 2 (same day) — the landed moment + her season + pacing

- **THE LANDED moment** — the founder-named gap: logging a plate had
  no celebration. Now, when the capture cover closes with a fresh
  plate (≤120s), the food band answers: `jkSilkSweep` light pass +
  "that plate landed ♥" rising in rose serif italic +
  `ActivationHaptics.arcComplete()` swell; the line breathes for
  ~3.4s and leaves the numbers to carry on. Inline, never a popup.
  QA: `--uitest-land-plate`. Frame-audited on video (60fps capture).
- **CycleSignal + CycleService** — the women-specific signal:
  cycle-phase appetite context from HealthKit menstrual flow
  (`.menstrualFlow` reads; `HKCategoryValueVaginalBleeding` behind
  an availability branch for the test target's floor; metadata
  cycle-starts honored, gap heuristic fills). Meta-analysis basis:
  ~168 kcal/day higher luteal intake WITH ~100-300 kcal higher
  resting burn — forgiveness on both sides of the ledger. LAWS:
  no predictions, no dates, no fertility words, perimenopausal
  gated off, Home speaks only when it helps (luteal/menstrual).
  Home: season row (JKSeasonMark ring) + a once-ever dismissable
  connect row (auto-retires on denial). Becoming: "your season"
  page with the unlabeled 4-segment JKSeasonBand + today-dot.
  QA: `--uitest-force-season luteal|menstrual|follicular`.
- **ProteinPacing** — "early enough?", not "enough?" (Leidy RCTs:
  35g mornings cut evening snacking). Becoming "protein pacing"
  page reusing the mounds in cocoa (`JKMomentMounds` — the
  generalized JKSweetMoments; sweetness keeps rose).
- Engine tests now 36 (cycle phase math, start derivation,
  staleness silence, pacing floors + flags).

## Round 5 (same day) — the frame-audit pass

- Journey videos recorded (launch→today, becoming arrival, sheet
  open) and audited via ffmpeg contact sheets. Launch choreography
  passed clean; the becoming pages exposed one composure flaw:
  stats/meaning lines popped at frame zero while figures drew.
- **jkStagedReveal** (shared modifier): every signal page now
  sequences figure → stat triplet (+0.55s) → body line (+0.8s),
  re-arming per swipe, Reduce-Motion instant. Verified frame-by-
  frame on video.
- **The dusk ember**: the evening window arc wears dusk light
  (rose → jeweledRose) instead of dawn blush; live ember unchanged.
- Founder decision recorded: NO TRIAL (03_CONVERSION.md §memo).

## Honest gaps / follow-ups
- The evening phase's visual is the live horizon (same as morning);
  a dedicated dusk variant (ember at the LEFT foot) is a candidate.
- Sugar provenance starts at v1.1.5 plates; the sweetness page stays
  silent for users whose week predates it (correct, by the floors).
- CoachContext does not yet carry window/sleep facts to jeni chat —
  small client-side add, deferred for scope.
- A lock-screen widget for the live window state is the obvious
  retention follow-up (JenifitWidgets target exists).
- MealMoves uses hourly buckets (conservative). Per-minute step
  queries would sharpen detection at slightly higher HK cost.
- The first-run-of-day lesson auto-present (pre-existing retention
  behavior) collided with the first two QA launches on a fresh sim;
  observed, not changed.
