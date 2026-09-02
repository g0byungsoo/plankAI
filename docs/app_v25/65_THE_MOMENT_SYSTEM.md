# 65 — THE MOMENT SYSTEM

**feat/app-v2 · built 2026-09-01/02, after 64.** The founder's
correction of p64, three parts: ① the manual step/walking completion
STILL did not visibly complete (the actual product is the authority,
not the record); ② celebration was interpreted too locally — a
meaningful commit (especially a meal) earns a DISTINCT full-page
moment (COMMIT → CELEBRATION → CONTINUE → HOME), one reusable module,
not particles over the answer sheet; ③ Jeni-initiated surfaces must
speak the onboarding grammar everywhere — one thought at a time, never
a questionnaire dump. Plus: affordance fundamentals, AX, and the
standing boundary (no restriction/streak/weight-number celebration).

Method: git state recorded (`1c225b7`, clean, synced), the p61–64
records + law read, every defect REPRODUCED on the QA sim before
design, RED→GREEN throughout, every flow filmed E2E through the
walker arm, coherent commits per correction.

---

## 1. HER WORD COMPLETES THE WALK (the founder's bug, two real halves)

Reproduced exactly: quick-mark and the mark sheet both wrote
`steps → complete`, the record persisted, synced, and counted
("2 of 2") — and the row rendered its open circle forever.

- **Half one — BeatCompletion's steps branch read ONLY the live
  count.** p64's "one testable authority" was true for water and
  false for steps: the branch returned `isDone: fraction >= 1`
  unconditionally, so her explicit mark changed nothing on screen
  while the burst and haptic fired over the unchanged row (worse
  than silence — celebration attached to a visible no-op).
- **Half two — the marked ask VANISHED mid-session.** The walking
  ask is recomposed from live gates every snapshot; when an async
  HealthKit workout landed (the sim's stale 24-min workout, on
  film), the absorb gate flipped and the completed row — WITH its
  "2 of 2" — left the day. Completion is a fact about the day, not
  a candidate for recomposition.

**FIX:** BeatCompletion — measured crossing stays the strongest fact
(render-only, un-unmarkable); her mark completes the ACTION below the
goal (`isAuto: false`); a stale `autoCompleted` record never fakes a
crossing the sensors don't show. `stepsRowTitle` speaks the same
authority: measured done states the count ("9,214 steps"), her word
states the act ("walked" — never a numeral the sensor did not
measure), open keeps the ask. CarePlanEngine gains `walkMarkedDone`
(threaded from `checkStates["steps"] == "complete"` — "complete" is
writable only from the ask's own controls, so a passive auto-crossing
can never lift the offered receipt into the owed list): a COMPLETED
ask keeps its seat when any gate flips; the gentle day still outranks
it. One long-press owner at last (`TodayModules.longPress` had zero
callers while the row re-implemented it; the `isProgressRow` guard
died with manual completability). RED 2/7 + 2/5 (refusal controls
passed); filmed mark → walked ✓ → relaunch → persists; unmark
honestly re-obeys the gates.

QA doors that made it walkable: `--uitest-seed-walk-fact` (the
consented step goal through ProgramFactStore's own chokepoint — the
ask-row state p64 named unreachable; first attempt crashed on the
hygiene registry's closed `source` vocabulary, the p61 mechanism
catching its author again) and a `seedForQA` latch (live HK refreshes
overwrote the seeded count mid-film — a QA artifact wearing a product
bug's clothes).

## 2. DUPLICATE CHECK ROWS CRASHED EVERY LAUNCH (found live, fixed)

Mid-pass the app died and stayed dead: TWO rows for one (plan, day,
itemKey) — one minted locally (`pendingUpsert=1`), one arriving from
the insert-only hydrate under its own id (`pendingUpsert=0`) — and
`fetchCheckStates`'s `Dictionary(uniqueKeysWithValues:)` ASSERTED,
at every snapshot, permanently. Here the pair was walker-induced
(an out-of-band delete resurrected by the synced copy), but the
shape is any slot marked on two devices: both push their own UUID,
each hydrates the other's. `BeatCompletion.checkStates(from:)` is
the fold now — a resolved state outranks empty (her completion is
never re-opened by a stale duplicate), ties to the newest write,
duplicates can never assert. Proven on the exact store that
crash-looped. 4 pins.

## 3. THE MOMENT SYSTEM (one celebration language, many moments)

**The rhythm: COMMIT → CELEBRATION → CONTINUE → HOME.**

- **`JeniMomentView`** — THE one full-page surface (app-owned,
  ~140L): full-bleed paper, eyebrow ("on file." — persistence
  stated, because the moment exists only after the save) → serif
  headline with italic punch, **JeniBurst rising from BEHIND the
  words being celebrated** (origin law kept — never screen confetti
  from nowhere) → the record's fact → one large continue
  (JFContinueButton, the standing CTA). Speech arrival (JeniActs):
  headline, then fact, then the way out; a tap lands all; the CTA
  cannot be hit before it arrives. Haptic + burst are ONE event at
  mount, tier-mapped to the standing grammar (spark hand for spark;
  the crest hand for crest AND moment — rarity lives in the
  two-wave visual, not a new hand). A new moment is a payload
  (`PlateMoment`: occasion · eyebrow · headline · punch · fact ·
  tier · cta), never a new screen.
- **THE RECORD FIRST.** p64 celebrated at compose time and persisted
  1.35s later — a celebration could outrun a failed save (the exact
  p61 class). `SnapResultView` owns the whole commit loop now:
  persist AT the tap (`onLog: → Bool`), ceremony only after a true
  return; a false return re-opens the latch and the failure notice
  (moved in from the host, so a landed retry still gets its receipt
  or moment) offers the same tap through the same path. The photo
  path commits inline through the same reorder. The answer provider
  runs AFTER the persist — `Input.afterFiling` derives the
  before-view from the after-store, so the spoken numbers can never
  disagree with the dial.
- **`PlateMomentClaim`** — one moment per commit, the biggest fact
  wins: first plate EVER ("moment" tier, once per LIFETIME —
  `CelebrationLedger` gains the lifetime latch, so delete-all-relog
  repeats the sentence never the page) > floor CROSSING ("crest",
  once/day by construction) > first plate TODAY ("spark", day
  latch). The page's words are the engine's own answer re-seated
  (headline = the lead, fact = the rest — one sentence authority,
  splits pinned so a copy edit fails a test instead of drifting). A
  first plate that also crosses carries BOTH facts on one page —
  never stacked fireworks. Ordinary plates keep the in-place
  receipt + `record()` (p58's one commit hand, now injected as
  `FoodModule.recordHaptic`).
- **Hierarchy (by meaning and frequency):** water / steps / move
  ask-met keep their action-local sparks (state change + haptic +
  restrained burst — several times a day must stay light); the full
  page is reserved for committed MEAL moments (at most ~1/day by
  construction, rarer tiers rarer). The moment defers the
  three-questions offer to the next filed plate (one commit, one
  surface, one attention — pass 52's keep-your-turn mechanism
  reused).
- **Package seams:** `PlateAnswer.moment` + `FoodModule.momentView`
  + `recordHaptic` injected; the package never learns what earned a
  moment and owns no celebration visual. **p64's `burstOverlay` /
  `crestHaptic` / `sparkHaptic` seams and the in-sheet burst
  DELETED** — the founder's correction outranked the sunk cost.
- **NEVER a moment** (standing boundary, restated): eating less ·
  calories left · weight numbers · streaks · suppressed-cohort
  numerals · dose · the evening close.
- Doors: `--debug-moment-gallery` (+ `--uitest-moment N`).

Filmed E2E (walker arm, real engine, no mocks): stated plate →
**spark page** ("today's first plate. / 17 of 120 g of protein.") →
continue → Home current, no stale totals, no flash, no sheet stack;
**crest page** ("floor covered.") with the CTA caught mid-arrival —
ghosted, un-hittable; **first-ever moment page** with the two-wave
burst blooming from the headline as the reading dissolves beneath it;
ordinary plate keeps the receipt and Home's floor-met dial; AX5 wraps
clean; Reduce Motion arrives whole — zero particles, the page + words
+ haptic still say "this mattered."

## 4. JENI SPEAKS ONE THOUGHT AT A TIME (the acts reach every surface)

The founder's screenshot — the day-one notification card standing on
Home with statement + question + two buttons pre-rendered — was the
class, not the instance.

- **The day-one card speaks in acts:** statement with the card → the
  ask on its own beat → the answers last (un-arrived answers cannot
  be pressed — the invisible-door law). The walk starts when the
  card is LOOKED AT (iOS 18 `onScrollVisibilityChange` ≥50%; 17
  falls back to mount) — on a scrolling page a mount-time schedule
  finishes before she arrives. Tap lands all; RM whole.
- **`FoodActs`** — the package's speech grammar EXTRACTED from p64's
  private consent-sheet copy (two private copies of one law is how
  drift starts): same 0.55 beat, tap-to-land, un-arrived acts
  un-hittable and hidden from VoiceOver, schedule dies with the
  view. The consent sheet re-seated on it, behavior identical.
- **The three-questions offer** (the post-first-plate surface —
  Jeni asking, so it earns acts): invitation → one question per
  beat → the way out arrives LAST. The settings editor keeps its
  assembly arrival (she summoned an editor, not a speech — §4.1's
  two-grammar law). Filmed in five acts.
- Surfaces already on the grammar (p63) audited and left standing:
  the close, reconcile, the read's tail, the method note. The chain
  suggestion row is one sentence + chevron — already one thought.
- Doors: `--uitest-day-one-card` (the OS ask state is unreachable
  from outside) · `--uitest-fresh-food-offer` (the once-ever flag
  lives in the app CONTAINER plist; `simctl spawn defaults` writes
  the sim-global domain — the E8.1 once-ever-filmable lesson, third
  time, now written down).

## 5. AFFORDANCE FUNDAMENTALS

- The words door's SEND circle (ScanChooser, 34pt bare) and
  QuickAdd's camera/close chrome (36pt bare) — the commit and exit
  controls of the core food loop — gain the §10.5 pad→shape 44pt
  fold; visuals unchanged.
- The moment page's continue is the standing 54pt JFContinueButton;
  the day-one card's accept grew to 12pt vertical padding; "not
  now"/"no thanks" keep their 44pt floors.
- JeniTaskRow: an owed done row whose control stands down still
  draws its check (the branch was offered-only).

## 6. ACCESSIBILITY

- **Reduce Motion:** the moment page arrives whole, zero particles;
  meaning carried by the page, the words and the haptic (filmed —
  never "nothing happened"). All acts surfaces arrive whole.
- **AX5:** the moment page wraps at every size, CTA intact (filmed);
  Home keeps the p59 words-and-thread face.
- **VoiceOver:** un-arrived acts hidden; burst canvases
  `accessibilityHidden`; the moment page is one contained element
  group with the full sentence available.

## 7. VERIFIED

- **plankAITests: 1652 total · 2 skipped · 0 failed** (p64's 1632
  + exactly 20: 7 steps-completion/title + 4 duplicate-merge + 5
  walk-seat + 8 moment-claim replacing p64's 4 claim pins).
- **PlankFood: 289/289** (after the seam restructure and FoodActs).
- **Release BUILD SUCCEEDED.**
- RED honest: steps-completion 2/7 against the shipped code (5
  refusal controls passed) · walk-seat 2/5 · the duplicate-rows RED
  was the live crash itself (symbolized, store inspected, then
  proven GREEN by launching over the exact store that crash-looped).
- Filmed: RED walk-mark (row unchanged, "1 of 1") · GREEN
  mark/unmark/persist · spark page E2E · crest page (CTA
  mid-arrival) · first-ever two-wave · ordinary receipt + floor-met
  return · day-one card acts · offer acts ×5 · consent whole on the
  shared grammar · RM moment · AX5 moment + Home.

## 8. DECIDED AND REFUSED

- **The in-sheet burst deleted, not preserved** — p64's architecture
  lost to the product model, not to taste.
- **No moment for water/steps/move** — several-times-a-day acts stay
  action-local by frequency law; the page would be a toll by day 3
  (the research consensus: full-screen is for earned rarity).
- **The weigh-in still never bursts**, the close stays the calm
  terminus, dose stays clinical, streaks stay dead.
- **The moment claims at most one page per commit** — a first-ever
  crossing speaks both facts on one page rather than stacking.
- The `.plain` buttons on Paywall/Wall/V8 left alone (frozen
  payment surfaces; not this pass's flows).

## 9. NAMED, NOT DONE

- Breath/session completion moments (the session-complete beat still
  needs its own walk; PostRoutineView carries its own heritage).
- The `onScrollVisibilityChange` acts trigger for OTHER Home cards
  (the chain row is one thought; nothing else qualifies today).
- Physical-device validation: spark/crest texture under the burst,
  live HK crossing while Home is foreground (sim proves timing, not
  feel).
- The walking-ask film with a REAL HealthKit crossing (the sim's
  stale workout made the unmark leg exercise the absorb gate
  instead — correct behavior, unplanned film).
- A server-side unique key on `program_day_checks(plan, day,
  item_key)` would prevent duplicate rows at the source; the client
  merge stands alone safely (founder-gated migration).

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases; one mid-pass disk-full (containermanagerd
staging caches, 9.7 GB — cleared, environment not product).
