# app v5.1 — the founder-feedback build (2026-07-07, shipped)

This file began as the previous session's spec (its shell died
after `bc0be70`; items were specified, not built). This session
built them. It is now the record: what shipped, the evidence, and
the honest gaps. Commits `8e4d22a..676b11d` on `feat/app-v2`.

## What shipped (per-feature commits)

### 0. QA seed made deterministic — `8e4d22a`
The seed harness raced auth on cold launches (blank Today on some
runs, wasted the prior session's verification hours). Bootstrap now
polls auth ≤12s with a retry, and writes ground-truth markers to
`$CONT/tmp/qaseed.trace` (task-start / bootstrap-done / seed-blocks
/ seed-done) so a blank screen is diagnosable in one file read.

### 0b. Liquid Glass navigation — `4679c70` (mid-session founder ask)
"i like liquid apple navigation more." The custom JKTabBar died;
MainShell now uses native `TabView` + `.tabItem` (sparkles / bubble
/ book.closed, cocoa tint) with `.tabBarMinimizeBehavior(.onScrollDown)`
behind `#available(iOS 26)`. The becoming pager's 92pt legacy dot
padding shrank to `Space.sm` (native bar supplies the safe area) —
this also fixed the WEIGHT-eyebrow/header collision. JKGallery lost
its JKTabBar row; the glitchy custom-bar transition is gone by
construction.

### 1. First-use teaching — `ab775f6`
As specified: dismissible "how this works" block on Today, days 1–2
only, `howItWorks.dismissed` AppStorage (swept on sign-out), three
JKReceiptRows in the existing grammar (snap a plate / the cocoa
card / becoming), "got it" quiet pill. No tour cover built.

### 2. Snap result speaks the whole answer — `8965f7d`
The result hero now carries a chemistry line (carbs · fat · fiber,
zeros silent) and a day line with provenance
(`FoodModule.dayContextProvider` → TargetsService + today's log):
"room for about N in your day after this" / "this lands today right
around your target" / "a little over today · tomorrow resets"
(over-target is words, never red). Four filler jeni-note templates
replaced with fact-bearing ones. Slide 2's kcal target now reads
the canonical provider, not the package-local AppStorage the app
never wrote. Suppressed cohorts: kcal stays silent (existing law).

### 3. The plate opens — `fd18fb0`
`PlateDetailSheet` (new file): tap any plate on Today's rail or
becoming's plates page. Photo card when one exists; kcal serif hero
(suppressed → protein sentence); chemistry receipt rows; IN TODAY
section ("of today's protein" 24 of 62g · "share of today's
calories" in words, never percents · "the day so far" in the snap
result's exact vocabulary); per-item ledger; honesty footnote
(photo-read vs words-read); "off? remove this plate" →
confirmation → delete. QA: `--uitest-plate-detail`.

### 4. The gentle five — `f8a6c21`
The founder's "workouts rethought around short lazy sessions."
The shrink door ("running on empty?") now opens a real mode, not a
shorter version of the same ask:

- Engine: `gentle` input → `SessionStructure.gentle` (5/7/10 min),
  pool capped at impact==low + difficulty≤2 + MET≤5, tier pinned 1,
  2 unique mains × 2 rounds (Pamela Reif convention), rest floor
  10s, names "The Gentle Five/Seven/Ten".
- Completion: the kept bar drops to 50% (standard 70%) — halfway
  already counts. Both completion sites pass `isGentle`.
- Preview: receipt says "2, twice through" (counts what she must
  learn, not every slot — the tip and the receipt may never
  disagree); jeni's line "two moves, twice through, no jumps.
  halfway already counts ♥"; the gentle door hides when the session
  already is one.
- `GentleWorkoutTests`: 7 invariants pinned (pool / structure /
  rest / size / identity / completion / standard-path-untouched).
- QA: `--uitest-gentle-preview`.

### 5. The stream catches light — `676b11d`
JeniProse's `isLive` shimmer: a slow sheen travels through the
glyphs (the text masks a 45%-width accent-at-0.4 gradient band),
2.4s wall-clock period via TimelineView (token re-renders never
restart it), band parks off-frame between passes, 30fps cap, dead
the frame the stream ends, absent under reduce-motion. No box, no
skeleton. The tail dot stays — it says where, the shimmer says
alive. QA: `--uitest-mock-chat --uitest-chat-shimmer` pins a
mid-stream entry for the camera.

## Verification (this session, correct build confirmed via
BUILT_PRODUCTS_DIR — see the sim-build-verify memory)

- Unit suite: **TEST SUCCEEDED**, GentleWorkoutTests 7/7 among them.
- `DesignWalkUITests/testMotionTour`: **passed (50s)** against the
  native tab bar + teaching block.
- Screenshots on device 389A9030 (iPhone, iOS 26.2): teaching block,
  plate detail (seeded + suppressed), snap result day line at three
  thresholds, gentle preview (two captures, receipt/tip coherent),
  shimmer at three phases (distinct MD5s; sheen visibly masked to
  the live message's glyphs only), becoming story pages 0–4.
- Six-item founder list from part 2: all verified live. Note the
  story pager is FIVE pages for a losing-chapter user (band joins
  at keeping; window joins when its data is real) — five dots on
  day 12 is design, not regression.

## Honest gaps

- Plate detail's photo-present path is code-only verified (seed
  plates carry no photos; the 216pt photo card renders from
  FoodPhotoStore when one exists). Snap a real plate on device to
  see it.
- SE-size (small-device) spot checks not done for the new surfaces.
- Movement story page in sim is the honest no-data state (dash
  placeholders + connect door) — HealthKit is empty in the QA sim.
- EF deploys still pending founder credential: `jeni-chat` (live
  streaming; shimmer verified on the mock transport) and
  `food-vision` (photo+text context).
- The 2am QA clock caveat on the overnight window stands
  (01_REPORT §8); daytime force-window evidence: f9_window.png.

## Standing founder mandates (carry forward)

Pixel/frame audits on every visual change; bolder-not-busier
charts; every word meaningful; anti-shame + locked palette +
provenance are constitution-level and override spectacle.
