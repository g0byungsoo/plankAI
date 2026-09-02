# 64 — THE DELIGHT LAYER

**feat/app-v2 · built 2026-09-01, after 63.** The founder's brief:
a FOUNDER OVERRIDE of one p63 decision — Jeni SHOULD have a real
visual celebration layer. p63's "no confetti in-app / no
first-log-of-the-day / celebration is mostly receipts" was too
restrictive and is no longer law. Preserve p63's foundations (calm,
proportionality, no streaks, one presentation director, action-local
feedback, the haptic grammar, progressive arrival); build the simple
consumer fundamentals first; fix the completion bug the founder
personally observed ("I can check water / steps and apparently
NOTHING happens") BEFORE decorating it.

Method: git state recorded (`c262ec5`, clean, synced), the law +
p61-63 records read, the app walked on the QA sim before any design,
fresh research (below), the burst chosen from THREE filmed
contenders, every rule RED→GREEN, every moment filmed.

---

## 1. THE COMPLETION BUG — REAL, REPRODUCED, TWO HALVES

The founder's observation was exact, and it was **state changing but
never rendering**:

- **WATER**: the row is composed ONLY as an offered move
  (titration support). Tapping it opened MarkAsDoneSheet ("drank
  some water?" — a confirm sheet for an act with no stakes);
  confirming wrote `ProgramDayCheckRecord(itemKey: "water",
  state: .complete)` AND synced it — and the row rendered
  byte-identical, forever, because `offeredCard` never passed
  `isDone` and `JeniTaskRow` gated every done branch on
  `!offered`. **RED on film**: before/after frames of the marked
  water row, pixel-identical (`64_evidence/RED_water_marked_
  nothing_rendered.png`); the record persisted invisibly across
  relaunch.
- **STEPS**: the standing offered row could never complete. At
  9,214 of 7,500 it still read "7,500 steps · auto-tracked" — an
  invitation. `beatState` computed `isDone` from the live count and
  only `taskRow` consulted it; `autoCompleteStepsIfCrossed` wrote
  the record; the offered row read neither.
- Related finds while there: `TodayModules.longPress` (with its
  `isProgressRow` guard) has zero callers; the supporting steps row
  can be long-pressed into markAsDone despite the guard's intent
  (named, not chased); `ObservationStore.Kind.hydration` has zero
  producers.

**FIX (fundamentals first):**
- `BeatCompletion` — ONE testable authority for row state,
  extracted from HomeView's view body (the §36 lesson: a rule in a
  view body cannot be tested, which is why nobody noticed the
  offered rows never consulted it).
- `JeniTaskRow` honors `isDone` on offered rows: the same
  compressed-receipt grammar as owed rows; a tap-to-check offered
  row (water) may carry the check control; an auto-completing one
  (steps) renders a render-only drawn check — nothing to press,
  un-marking a measured crossing would fake data.
- Water is a ONE-TAP mark now (row or check, both toggle; the
  confirm-sheet detour died for it — the market law: never add taps
  to the core loop). Unmark = tap again.
- Steps retitles to the walked count when done ("9,214 steps ✓").
- The a11y label says "done"; VoiceOver order unchanged.

GREEN on film: the marked water row compresses to `water ✓`, "1 of
1" correctly does NOT count it (offered stays never-debt), state
survives relaunch; the steps row rests `9,214 steps ✓`.

## 2. THE RESEARCH THAT SHAPED THE HOW

Fresh sweep (full report in session): Apple Fitness (burst FROM the
ring, in the ring's own hue — origin + palette restraint), Waterllama
(diegetic per-log feedback, particles rationed to rarity), Duolingo
(rarity ladder; milestone-only fireworks), Robinhood (the cautionary
tale: celebration attached to a risk-asymmetric act reads as
manipulation — replaced with "moments of understanding"), (Not
Boring)'s checkbox (redundant channels: animation + haptic as ONE
event), MyFitnessPal 2025 (celebration must ride a COMMITTED fact),
Emil Kowalski (frequency rule; interruptible; transform/opacity
only), HIG (haptics causal + harmonious; don't animate frequent
events). Implementation: hand-rolled Canvas + TimelineView-class
particles beat Lottie/CAEmitter/SpriteKit for origin control,
theming, RM branching and zero dependency; Vortex/ConfettiSwiftUI
considered and refused (generic look, no need for a dependency to
draw 40 rectangles). GLP-1 boundary reconfirmed: celebrate only what
she ADDED.

## 3. JeniBurst — THE ONE PARTICLE ENGINE (bake-off, on film)

~230 lines, `DesignSystem/Kit/JeniBurst.swift`. Torn-paper flecks
(rounded rects that tumble) in the rose ramp + ~1-in-6 ink accents;
launch cone up-biased, closed-form physics (drag integral + gravity)
so the draw is pure in `t`; deterministic per play (seeded LCG);
`allowsHitTesting(false)`; the Canvas leaves the tree when the last
fleck dies (zero idle cost); Reduce Motion renders nothing.

**Three materially different styles were built and filmed against
each other** (`--debug-burst-gallery`): paper flecks · thin
light-rays · soft petal-dots. The film decided: rays read as cold
debris, petal-dots read as drifting bubbles; the fleck is the one
that reads as JOY in Jeni's own material. Losers deleted
(`64_evidence/burst_bakeoff_*`). First physics pass also
film-corrected: drag 3.1 killed the burst on the control before it
opened → 1.55 (terminal spread ≈ speed/drag), gravity 620→560,
launch lift ×1.3.

Tiers, proportional by construction: **spark** ~18 flecks/0.9s ·
**crest** ~32/1.1s · **moment** ~46/1.4s, two waves
(`64_evidence/burst_moment_tier_two_waves.png`).

`JeniHaptic.spark()` joins the grammar (pop · short shimmer) in the
ONE CoreHaptics engine — under the crest by construction (no soft
lead-in, lighter/shorter bloom); success-notification fallback.

## 4. ELIGIBILITY IS DOMAIN LOGIC (RED 14/19 → GREEN)

`CelebrationLedger` (pure over injected defaults): a celebration
corresponds to a MEANINGFUL EVENT, once per moment per civil day.
`PlateCelebration.claim` maps a composed answer to its burst in
priority order — **one celebration per commit, the biggest fact
wins**: first plate EVER ("moment", once/lifetime by derivation) >
floor CROSSING ("crest", once/day by construction) > first plate
TODAY ("spark", ledger-latched). Latch keys live under
`celebration.` and join the §38 sign-out sweep (A's spent spark must
not eat B's first one); `--uitest-wipe-celebrations` films door
(the E8.1 once-ever-filmable lesson, pre-learned this time... after
one quiet film proved the latch worked).

Adversarial pins: unmark→remark same day settles quietly ·
delete-every-plate-then-relog repeats the SENTENCE (a fact) never
the burst · moments latch independently · next day sparks again ·
crossing does not spend the first-plate spark · cold mounts never
celebrate (a burst plays only on a token change or an
answer-surface mount that composed one). RED honestly: 14 of 19
failed against stubs; the 5 passing were refusal-shaped controls.

## 5. THE MOMENTS, WIRED AND FILMED

- **Water marked** → spark: flecks from the check she tapped +
  `spark()` + the row compresses to its receipt. Filmed
  (unmark→remark walk; the first film was correctly QUIET because
  the ledger had latched — the idempotency proving itself before
  the celebration did).
- **Step goal** → automatic facts celebrate quietly: witnessed
  crossing draws the check + flecks with NO haptic (§8.3, passive
  events never vibrate); arriving already-crossed rests complete.
  An EXPLICIT quick-mark of the walking ask carries the spark's
  haptic (wired + ledger-tested; the ask-row state wasn't
  reachable in the QA seed — mechanism filmed on the other
  surfaces).
- **First plate of the day** → the answer LEADS with it: "today's
  first plate. 17 of 120 g of protein." (punch "first plate") +
  spark flecks over the sentence + `spark()`. Engine change
  RED→GREEN; suppressed cohorts keep the sentence numeral-free; a
  zero-protein plate never renders "0 g"; first-ever outranks.
  `platesOnFile` — plumbed in p61, never read — finally reads.
  Cross-product refusal sweep grown 400→800 combos. Filmed
  (`64_evidence/first_plate_of_day_spark.png`).
- **The floor crossing** → the crest FINALLY has its visual half:
  crest burst riding "floor covered." + the p63 crest haptic + the
  dial's check draw at the return, untouched. Filmed.
- **First plate EVER** → the MOMENT: "your record starts here." +
  two-wave burst + the crest's hand (once per lifetime — rarer
  than the daily peak by construction; p63 gave it words only).
  Filmed (`64_evidence/first_plate_ever_moment.png`).
- **The move record's ask met** ("that's twice this week.") →
  spark flecks over its own receipt; `record()` stays the hand's
  confirm (a fact entered the record — the visual carries the
  celebration).
- **Package seams** (FoodPress precedent): `PlateAnswer.burst`
  (additive, source-compatible), `FoodModule.sparkHaptic` +
  `burstOverlay` injected; the package never learns why a plate
  celebrated and owns no particle engine.

**Deliberately NOT celebrated** (the boundary, unchanged + extended):
eating less · calories left/under · weight numbers (the weigh-in
keeps its receipt WITHOUT a burst — flecks beside a weight numeral
would read as celebrating the number) · streaks · suppressed-cohort
numerals · dose marking · the evening close (stays the calm
terminus; the day's end never competes with confetti).

## 6. THE ARRIVAL GRAMMAR REACHES THE CONSENT PRIMER

The food-AI consent primer — the FIRST Jeni-initiated surface of the
food flow — landed as one dump (header + teachings + disclosure +
CTA in one frame). Now it speaks in three acts at the 0.55 beat:
claim ("how jeni counts a meal") → evidence (the disclosure rows) →
decision (accept / not now), via a package-local mirror of the
JeniActs laws (tap-anywhere lands all; an un-arrived accept cannot
be hit — comprehension before consent; Reduce Motion arrives whole;
the schedule dies with the view). Filmed arriving in exactly that
order (`64_evidence/consent_primer_three_acts.png`).

## 7. AFFORDANCE + CONTRAST FINDS (from the rendered product)

- **JeniCheck's open circle was a decoration weight on a control**:
  0.16 ink on bare paper all but vanished (frame-caught at the
  water row) → 0.28. The drawn state stays the loud half.
- **MarkAsDoneSheet** (still the long-press manual override): both
  CTAs were press-DEAD `.plain` — the exact class p63 killed
  elsewhere — with raw-generator haptics → JKPress + the grammar's
  `record()`/`land()`; "not yet" meets the 44pt floor.
- The water row's check gives the offered row its first honest
  affordance answer ("what happens if I touch this?" — mark water).

## 8. ACCESSIBILITY

- **Reduce Motion**: no particles anywhere; the state change, the
  words and the haptic carry the full meaning (filmed: RM water
  mark = drawn check + compressed row, zero flecks). JeniActs +
  consent acts arrive whole. Nothing removed but motion.
- **AX5**: rows wrap, the check control survives, done states
  legible (filmed; `simctl ui content_size` is the working door —
  the `-UIPreferredContentSizeCategoryName` launch-arg pair did
  nothing through the walker's `launch`).
- VoiceOver: offered+done announces "done"; burst canvases are
  `accessibilityHidden`; the consent disclosure stays one combined
  element per act.

## 9. ANALYTICS SEAM

`celebration_shown {tier: spark|crest|moment, moment: water_done|
steps_goal|first_plate_today|first_plate_ever|floor_crossing|
move_ask_met}` — hygiene-registered closed vocabularies; never a
food name, a number, or her words. Shipped as a measurable
hypothesis, no retention claim.

## 10. VERIFIED

- **plankAITests: 1632 total · 2 skipped · 0 failed** (p63's 1609 +
  exactly the 23 new: 19 ledger/completion/answer + 4 claim pins).
- **PlankFood: 289/289** (burst param source-compatible; consent
  acts compile clean). **Release BUILD SUCCEEDED.**
- RED→GREEN: 14/19 against stubs (5 refusal-shaped controls
  passed) · answer-engine pins moved onto honest fixtures
  (platesOnFile) with the two empty-day pins re-lawed to the
  first-plate lead, deliberately.
- Filmed: bake-off (3 styles × tiers) · RED water (pixel-identical
  after mark) · GREEN water (check + compress + persist across
  relaunch + quiet re-mark) · steps done · first-of-day spark ·
  crossing crest · first-ever moment (two waves + dial count-up at
  return) · consent acts in order · RM water · AX5 pair.
- A disk-full linker failure (errno=28) mid-pass was environment,
  not product; stale DerivedData clones cleared.

## 11. DECIDED AND REFUSED

- **Lottie for in-app celebration — investigated, refused**: the
  dependency is already paid (onboarding keeps its set), but baked
  JSON can't originate from a tapped control, can't theme from
  tokens, and reads stock. The house engine is ~230 lines with
  none of those costs. Hybrid kept: Lottie = onboarding's register,
  JeniBurst = the app's.
- **No new auto-present, still**: every celebration rides a surface
  she summoned or a commit she made; zero arbiter entries.
- **No streak surface, still.** First-of-day is a fact about today,
  not a chain.
- **Breath/session completions**: not wired this pass — the
  session-complete beat needs its own walk (named below).
- **The offered steps row at the screen-top edge** clips the
  burst's upward cone at one scroll position — positional, livable,
  noted.

## 12. NAMED, NOT DONE

- Breath / guided-session completion sparks (walk the session end
  first; PostRoutineView already carries its own celebration
  heritage).
- The walking-ask explicit-mark film (state needs a seed door with
  exactly one strength session this week).
- `TodayModules.longPress` dead code + the supporting steps row's
  long-press-vs-isProgressRow intent (pre-existing, one breath of
  cleanup).
- The four stagger constants beyond the two arrival grammars
  (p62's motion-vocabulary note stands).
- Physical-device validation: `spark()`/`crest()` feel and their
  sync with the burst frame (the sim proves timing, not texture);
  live HealthKit step-crossing while Home is foreground.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases (consent reset via the app-container plist,
the p63 method).
