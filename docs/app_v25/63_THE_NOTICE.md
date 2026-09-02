# 63 — THE NOTICE

**feat/app-v2 · built 2026-09-01, after 62.** The founder's brief:
not a redesign — the product should get better at RESPONDING to the
person using it. When she does something meaningful, Jeni
acknowledges it; when Jeni wants her to act, the action is
unmistakable; when Jeni has something to say, it arrives with enough
rhythm to be absorbed; and touching Jeni feels intentional
everywhere. Scope self-discovered, examples treated as hypotheses.

Method: git state recorded first (`158549a`, clean, synced), the
recent records + the design law read, then the app WALKED on the QA
sim (all four tabs · the letter · the close · the weight ritual ·
dose/move/side-effect sheets · the chooser · a stated plate filed)
BEFORE any design; four parallel audits (director integration ·
commit-moment feedback · affordance/press/hit-targets · arrival
choreography); behavioral research fresh (below); every visual claim
filmed; every consequential rule RED→GREEN.

---

## 1. THE RESEARCH THAT MATTERED

- **Fogg (Tiny Habits / operant conditioning):** the acknowledgment
  must land WITHIN SECONDS, riding the action — emotion wires the
  habit, not repetition. Delayed rewards don't build the same
  wiring. → Everything here fires at the commit, on the action's own
  surface; nothing is deferred to a popup.
- **Habituation:** celebration replayed daily is wallpaper by
  lunchtime; reserving it for meaningful moments is what keeps it
  meaningful. The Duolingo criticism corpus (streak anxiety, guilt
  triggers) is the anti-model. → tiers, latches, and NO streaks.
- **Gentler Streak (Apple Design Award 2024):** the compassion
  register wins in health — a congratulatory SENTENCE as a moment of
  pride, not confetti. → the receipt is written, not burst.
- **BJPsych Open 2017 + the 2026 AP reporting on gamified nutrition
  apps:** users describe "an unhealthy competition with themselves…
  to eat less and less"; green/red state and under-budget rewards
  feed the spiral. → the NEVER-CELEBRATED list below; the one crest
  is an eat-ENOUGH target (the protein floor) on purpose.

The product's own laws already agreed (§1.8 calm over clever, §11.4
anti-shame, the GLP-1 count-up silence); this pass gave them the
missing half: acknowledgment engineering.

## 2. THE NOTICE GRAMMAR (design law §4.7, rewritten)

Three tiers, decided by what the moment IS:

- **THE SETTLE** (existing, unchanged): state transition + tick/land.
- **THE RECEIPT** (`JeniReceiptBeat`, new kit primitive): a committed
  FACT answered in words at the action's own site — phase swap → one
  serif line + an honest sub-line → `record()` → `receiptDwell` →
  the surface excuses itself. Extracted verbatim from the weight
  ritual (the reference receipt since p53).
- **THE CREST** (new, ≤1/day by construction): the protein floor
  CROSSING. `JeniHaptic.crest()` — a composed CoreHaptics phrase
  (touch · landing · warm bloom) in the ONE existing engine
  (`ActivationHaptics`) — rides the plate answer's own "floor
  covered." words; the dial's check DRAWS at the return.

**Explicitly NOT celebrated (binding, in the law):** eating less ·
calories left/under · weight numbers/milestones · streaks
(PresenceLedger stays coach-context only) · anything a suppressed
cohort isn't shown · dose marking (clinical register acknowledges,
never celebrates). **Stock confetti refused in-app** — the Lottie
set stays onboarding-only; in-app, the OBJECT celebrates (a stroke
draws, a receipt is written).

## 3. WHAT SHIPPED, MOMENT BY MOMENT

- **The crossing** — `PlateAnswerEngine` marks `floorCrossed`
  (before < floor ≤ after; a suppressed cohort NEVER crosses — the
  haptic confirms what happened visually, §8, and they are shown no
  floor; a no-protein plate can't cross; restating an already-met
  floor is not a crossing). RED 9 → GREEN 30/30, cross-product grown
  to 400 combos, refusal sweeps intact. The package's confirm speaks
  the crest exactly there (`FoodModule.crestHaptic`, injected — the
  package owns no haptic grammar); every other file keeps the stock
  success, and the nil-provider path finally confirms AT ALL (it
  used to dismiss in silence).
- **The dial draws the crossing** — the met centre used to
  hard-swap in ("the product's highest-value event rendered like a
  cache hit"). Now `DialCheckDraw`: the check draws tip-to-tail on
  the chart curve + "floor met" breathes in, ONCE per day, only for
  a crossing this section witnessed live (the open-floor numeral
  rendered first) and only once no cover stands over Home
  (`PresentationGate.occupied()` — the child holds the stroke until
  the gate clears, so the draw plays at the RETURN from the capture
  cover, not under it). Cold launches rest complete — an appearance
  is a passive event (§8.3). The latch (`dial.floorDrawnDayKey`)
  stamps only when the draw actually played and joins the sign-out
  sweep (§38). **Filmed three failed ways first** (mount-time draws
  finish under the loader/cover — the film kept saying "arrived
  complete" until the gate-hold design), then the E2E: two stated
  plates → "that's 190 of 120 g, floor covered." → return → the
  stroke draws frame by frame.
- **First plate EVER** — `isFirstPlateEver` (a lifetime store fact)
  → "your record starts here." + the true numbers (never a zero;
  numerals suppressed → the sentence alone). The `platesOnFile`
  field p61 plumbed and never read stays for the day-count; the
  lifetime fact is its own input.
- **The move record's receipt** — "record it" used to fire the
  grammar's strongest haptic and dismiss ON THE SAME RUNLOOP.
  `MoveEnergy.receipt` (pure, RED 11 → GREEN 19/19): first heavy
  session ("one more is the whole ask."), the second ("that's twice
  this week" — the ask, met, stated as fact), further counts, and a
  non-strength session that is counted but NEVER graded against the
  ask (a generous receipt would retire Move's one judgement).
  `onSaved` runs with the write (the list behind is fresh even if
  she swipes mid-dwell); filmed — the sheet behind already reads
  "1 of 2 · you recorded this" while the receipt dwells.
- **The evening close's terminus** — goodnight used to close the
  cover like a cancel (generic medium haptic, nothing marked).
  Now: `EveningCloseEngine.goodnight(name:)` (RED 6 → GREEN 31/31)
  — "that's the day, maya." in the greeting's own transform (E8's
  heritage phrase), sub "on file. tomorrow's read builds from it."
  (the quiet-note card's own standing promise), the `arcComplete`
  BREATH (not `record` — closing the day files nothing new; it
  settles what the day holds), `receiptDwell`, then the cover
  excuses itself. **And Home notices:** the invitation row
  compresses to a "day closed" receipt (`JeniTaskRow` done state) —
  it used to keep saying "close the day" seconds after she closed
  it, the one place Home forgot she had just acted (frame-caught in
  the before-walk). Tapping the receipt revisits.
- **`evening_close_completed` + `arrival_skipped(surface)`** — the
  two seams (hygiene-registered, categorical only): the
  shown/completed funnel pair, and whether the speech rhythm gets
  tapped through (the §5.7 skip is the user's own vote on the
  cadence — future evidence, not a claimed win).

## 4. THE SPEECH ARRIVAL (design law §4.1, amended)

The audit's map: the product had TWO real arrival grammars —
assembly (`jeniArrive`, 0.055s) and the letter's line cascade
(0.42s/line) — and four Jeni-initiated surfaces using the wrong one
or none: the evening close landed nine indices in one 0.44s breath
(hero, receipt and three asks in one frame — filmed, byte-identical
at +1s and +3s); reconcile (the highest-priority self-presenting
surface in the app) had ZERO interior choreography and locked
dismissal; the weekly read's tail carried five editorial units on
one flag (THE OFFER arrived simultaneously with its own evidence);
the method note's argument landed 0.06s after its claim.

**`JeniActs`** (kit): named acts at a 0.55s beat. The primitive
carries the laws — tap-anywhere completes (§5.7), an act that has
not arrived cannot be hit, Reduce Motion arrives whole, the schedule
dies with the view. Applied: the close (statement · receipt · asks),
reconcile (claim · facts · decision — and its ink confirm gained the
press state it never had), the read's tail (receipt · THE OFFER ·
doors — filmed arriving in exactly that order), the method note
(claim · argument · action). Ordinary navigation untouched.

**The letter** (protected rhythm, p62): gains ONLY the tap-to-land
and two fixes — its doors were TAPPABLE AT OPACITY 0 through the
whole cascade, because a delayed `withAnimation` flips the VALUE
instantly and only delays the paint (the whole invisible-door class,
now named in the law); and `LineCascadeText`'s per-line timers used
to keep firing haptics after the view left (cancellation added, plus
the `completed` skip input). "keep it" meets the 44pt floor.

## 5. THE ACTION LANGUAGE (the founder's "is this clickable?")

- **One press language.** Five dialects existed (JKPress 93 sites ·
  JeniPressable 18 · Settings glow · strip 0.9 · trainer one-off) —
  and 139 `.buttonStyle(.plain)` controls with NO press state at
  all, including the food rail's entire surface (37/37 — "add it"
  included). Now: `JKPress` is a typealias of `JeniPressable` (the
  law's name, §5.1), `FoodPress` mirrors it across the package
  boundary (the FoodTheme mirror precedent), all 38 package
  `.plain`s replaced, `JeniCheck` compresses under the thumb (it
  was the one rigid control inside a pressable row), reconcile's
  ink capsule answers. Settings' glow + the strip's 0.9 disc stay
  (scoped, deliberate).
- **The letter's door.** The dateline — the product's most-loved
  surface's only entrance — was a 155×16pt strip of editorial
  typography with an invisible hold-for-settings and a VoiceOver
  hint as its only affordance. Now: a real Button (press state,
  light tick), a ~44pt hit fold (pad → contentShape → negative
  pad; the strip's discs keep their territory), an UNREAD DOT — a
  5pt berry mark after the week's word while today's letter waits,
  retired on reading — and **the hold-for-settings died** (the gear
  sits 44pt away, visible, doing the same thing; a hidden duplicate
  is drift, not depth). `JKTapWithLongPress` deleted (zero uses).
- **The tools index reads navigable.** Five rows rendered word ·
  right-aligned status — a stats table — while the dose row one
  block up carried a chevron: two grammars for one gesture. All
  five rows carry the 12pt chevron now (the dose row's own mark).
- **Hit targets** (HIG 44pt floor): the SAME 34×34 X copy-pasted on
  four sheets (becoming tile · journal · packet · ledger) →
  `tappableArea()`; the package's stepper (34×30), refine send
  (36) and cancel (30) → hit folds; profile hub X; "no thanks";
  the letter's "keep it"; DoseSheet's "not today" / "didn't,
  actually" (clinically consequential, caption-sized targets);
  MoveSheet's inline "remove". The law names the mechanism (§10.5).
- **The reading's corrections read as actions.** "off? fix it with
  words" and "+ add something" — the PRIMARY remedies for a wrong
  estimate — wore caption prose. Both wear hairline capsules now
  (the chip grammar: the one shape that always means "tap me"),
  filmed sitting under the share ladder as one coherent chip
  system. VisitPacket's edit/remove/save separated from their
  identical-ink label with the clinical family's own underline +
  press + targets. Chevron floors: "read the whole week" 9→12pt,
  chat's "your file" 8→11pt + full-width hit fold.
- **`JKProteinArc` deleted** (~175 lines): the v5 protein hero,
  gallery-only since p59, carrying a do-nothing tap bounce that
  taught "tappable" and betrayed it — and a dead `celebrated` latch
  that predated this pass's real one.

## 6. DECIDED AND REFUSED

- **No new auto-present.** Celebration NEVER presents itself: the
  crest rides the answer she summoned; the receipts ride commits
  she made; the dial holds its stroke until the gate is clear. Zero
  new entries in the arbiter; `PresentationGate` gained a READER,
  not an owner. (The director-integration audit sketched a fifth
  Candidate for a cover-level celebration — refused: nothing in the
  product earns a takeover that isn't already a moment.)
- **No confetti in-app; `.smokePuff` retired from the law's table**
  (it had zero call sites — the table promised a "quiet personal
  win" effect nobody built; the receipt IS that now).
- **No first-plate-OF-THE-DAY moment** — the answer is already
  day-aware; a daily "first!" is habituation fuel. First EVER only.
- **No streak surface** — PresenceLedger stays where p54 left it.
- **The dose sheet keeps its restraint** — the strongest haptic +
  one-word morph + commitDwell is already the clinical register's
  correct maximum; a receipt there would celebrate medication.
- **The weekly read's bespoke sign thunk kept** (soft+medium
  consent beat) — a distinct gesture for a distinct act; converging
  it into `record()` would flatten a deliberate distinction.
- **JeniActs carries no unit tests, deliberately** — the schedule
  is presentation (a loop of sleeps); its LAWS (hit-gating, skip,
  RM) are structural in the modifier and proven on film. The
  eligibility rules that matter (crossing, receipts, goodnight) are
  the pure, tested surface.

## 7. VERIFIED

- **plankAITests: 1609 total · 2 skipped · 0 failed** (p62's 1592 +
  9 answer-engine + 5 move-receipt + 3 goodnight, exact —
  reconciled by counting, not by memory: the first draft claimed 8
  and the suite said otherwise).
- **PlankFood: 289/289** (crest param source-compatible; no new
  package tests — the engine lives app-side).
- **PlankSync: 29/29.** **Release BUILD SUCCEEDED.**
- RED→GREEN: answer engine 9 failures → 0 · move receipt 11 → 0 ·
  goodnight 6 → 0 (each with refusal-shaped controls passing
  against the stub, as they should).
- Filmed: the two-plate crossing E2E (answer → crest words → return
  → the check draws frame-by-frame + "floor met" breathes in) · the
  close speaking in three acts (before: +1s and +3s byte-identical;
  after: statement → receipt → asks on film) · goodnight → "that's
  the day, maya." → dwell → the day-closed row · the read's tail
  (dots/signals → THE OFFER → doors, in order) · the read's
  tap-to-skip (caught working by accident — the walker's coordinate
  tap completed the acts) · the move receipt with the updated sheet
  behind it · the dateline dot + tools chevrons + correction
  capsules · SE standard + SE/AX5 (the dot, the words-and-thread
  receipt, the close).

## 8. NAMED, NOT DONE

- The stated plate's reading hides the composer triggers (its own
  face); whether corrections belong there too is a product question,
  not an affordance one.
- `JFContinueButton`'s secondary label sits under 44pt on some
  surfaces (the wall included — exempt territory); a global fix
  needs the wall legs re-baselined first.
- The four stagger constants beyond the two named grammars (the
  SnapResult grid's 0.07, the letter tail's 0.5/line) — p62's
  motion-vocabulary migration note stands.
- The offered rows (steps · a short session) still read quiet by
  design ("offered, never debt") — left; if evidence says they're
  missed, the seat treatment is the lever.
- The dial's crest plays only when the crossing round-trips through
  a cover dismissal in the same Home life; a crossing made while
  Home is FOREGROUND-VISIBLE (rare: repair/relog from a sheet that
  half-covers) draws on the next mount instead. Livable; noted.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
