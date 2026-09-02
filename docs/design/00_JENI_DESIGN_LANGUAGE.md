# THE JENI DESIGN LANGUAGE

**Status: CANONICAL. Established 2026-08-06.**

This is the single source of truth for how Jeni looks, moves, speaks
and feels. It was extracted from the v8 onboarding — THE CONSULT —
which the founder named the visual benchmark for the entire product.

**Precedence.** Where any older document disagrees with this one, this
one wins:

| document | status after this doc |
|---|---|
| `docs/app_v9/04_DESIGN.md` | superseded on visual form; its ADA floor survives (§10) |
| `docs/app_v11/00_REBIRTH.md` §3-§4 | superseded on form; its LAWS L1-L13 survive, restated here |
| `docs/app_v11/03_MODERNITY.md` | folded in — its material + spring amendments are law here |
| `docs/onboarding_v8/00_DIRECTION.md` | the reference implementation of this language |
| `docs/jeni_release/00_JENI_RELEASE.md` | still law for the MARK and the one-colour rule |
| `docs/THEME.md`, `her75_typeface_spec` | historical; typography law now lives here |

**How to use this document.** Read §1-§3 before designing anything.
Read §12 (never-do) before shipping anything. If you are about to
invent a component, a duration, or a phrase, the answer is probably
already here — use it. Consistency beats novelty in every case where
this document has already decided.

---

## 1. Design philosophy

Jeni is a body-transformation product for people who have been failed
by diet apps. The interface has to earn trust in the first ten
seconds and keep it for eighty-four days. Everything below serves
that.

**1.1 — Ink on paper.** The product is a written thing. A warm paper
field, dark ink, one accent. If a screen could be printed and still
make sense, the hierarchy is right.

**1.1b — TWO INSTRUMENTS, ONE HAND (v21 — docs/app_v21).** The
founder's redesign split the product's registers for good:

- **The APP SURFACES (Home, Becoming, tools, details) are
  INSTRUMENTS.** They communicate visually first — numbers, rings,
  bars, shapes — words second. *The page must still make sense if
  every paragraph disappears.* "Like a well-set book" no longer
  applies here; a dashboard that reads like a book is a document.
- **The CONSULT and the MOMENTS (onboarding, evening close,
  declarations) stay EDITORIAL.** Typed serif, negative leading,
  the letter register — that is where Jeni speaks in sentences.

The voice is one voice; the surfaces differ the way a clinician's
chart differs from her letter.

**1.2 — Type carries hierarchy.** Not boxes, not colour, not
dividers. Size, weight, and air do the work. A screen with five card
borders is a screen that has given up on typography.

**1.2b — Shape carries MEANING (v18).** Hierarchy is typography's
job; *understanding* is shape's. **If the text disappeared, the page
should still communicate.** Every metric that matters gets a visual
identity — a ring for a fraction, a bar for a floor, a week of marks
for a metric with no target, dots for days. Squint at any dashboard
screen: if it says nothing, it is a document, not an instrument.

The honesty constraint that makes this hard, and the rule that
resolves it: a metric with **no collected target may not wear a
progress bar** (D2 — the denominator would be invented), but it may
always wear **its own history** or **its share of a whole**, because
both are only what she logged.

**N shapes must be N questions (v18.1).** The first attempt gave all
five target-less nutrients their own 7-mark spark: 35 marks in one
band, and the founder read it as noise. The macros were never five
trends — they are ONE relationship. `JeniMacroSplit` draws the day's
energy split as a single segmented bar. When a band feels busy, do
not delete information: ask whether the shapes are one relationship
drawn many times. Home's food band now carries exactly four shapes —
ring (position in the window), window bar (the day's fill), protein's
floor bar (the one metric with a target), split (what the day was
made of). `JeniSparkRow` survives for a single metric's own week.

**1.3 — One idea per screen.** Every screen has a single job and a
single primary action. If you cannot say what a screen is for in one
sentence, split it.

**1.4 — The interface speaks, then waits.** Jeni says her piece, then
gives you something to do. Never both at once, never a wall of
controls with a paragraph above it.

**1.5 — Nothing appears; everything arrives.** Content enters on
choreography — staged, ordered, physical. A view that pops into
existence is a bug (§4).

**1.6 — Every number traces to a collected field.** No fabricated
data, no decorative statistics, no invented progress. If a number is
on screen, a real field produced it, and we can say which one.

**1.7 — Remove beats add.** The best version of most screens has
fewer elements than the current one. When in doubt, delete.

**1.8 — Calm over clever, and joy is real.** Celebration exists —
a completed healthy act can burst, in Jeni's own paper (p64, founder
decision) — and it is RATIONED so it still means something: once per
moment per day, proportional to the fact, never for restriction
(§4.7). Sophistication is never an excuse for weak feedback; a check
checks, a completion completes, a success feels successful.

---

## 2. Typography hierarchy

Three families. Nothing else, ever.

| family | role |
|---|---|
| **JeniHeroSerif** (Regular / Italic) | Jeni's VOICE — headlines, questions, statements, hero numerals |
| **DM Sans** (Regular / Medium / SemiBold) | the SYSTEM — labels, body copy, buttons, meta, captions |
| **Fraunces 72pt** (SemiBold / SemiBoldItalic) | ORNAMENT — eyebrows, small tracked caps, teach punches |

The rule of thumb: **if Jeni is saying it, it's serif. If the app is
labelling it, it's DM Sans.**

### 2.1 The ladder

Use the token, never a raw `.font(.system(...))`. All live in
`PlankApp/DesignSystem/Tokens.swift` unless noted.

| register | token | size | use |
|---|---|---|---|
| display | `Typo.display` | 56 | the rarest hero (launch, graduation) |
| numeral hero | `Typo.numeralHero` | 64 | the one number a screen is about |
| hero headline | `Typo.displayHero` / `heroHeadline` | 38 | ceremony beats — the seal, the oath |
| page question | `Typo.questionHero` | 34 | a screen's question or title |
| **conversation** | `V8Type.message` | **30** | **Jeni speaking — the consult register** |
| section title | `Typo.sectionTitle` | 26 | a band's leading line |
| reading | `Typo.reading` | 24 | long-form serif body |
| numeral stat | `Typo.numeralStat` | 22 | secondary figures |
| heading | `Typo.heading` | 20 | DM Sans block heads |
| body | `Typo.body` | 16 | DM Sans paragraphs |
| caption | `Typo.caption` / `V8Type.caption` | 13 / 14 | meta under a line |
| eyebrow | `Typo.editorialEyebrow` | 11 | tracked caps section labels |

### 2.2 Negative leading is mandatory on serif

Large serif at default leading looks loose and amateur. Every hero
register carries a paired line gap — use it:

```
questionHero  → .lineSpacing(Typo.questionHeroLineGap)   // −17
displayHero   → .lineSpacing(Typo.displayHeroLineGap)    // −19
V8Type.message→ .lineSpacing(V8Type.messageLineGap)      // −9
```

### 2.3 The italic punch

One to three words per line, never a whole clause, composed —
**never** `*markers*`, never `.italic()` on the whole string.

```swift
// RIGHT
JeniHeadline("that's the day, casey.", italic: ["casey."])
ItalicAccentText("before the plan, one promise.", italic: ["promise"],
                 baseFont: Typo.heroHeadline, italicFont: Typo.heroHeadlineItalic)

// WRONG — the punch is the whole sentence, so there is no punch
JeniHeadline("that's the day, casey.", italic: ["that's the day, casey."])
```

### 2.4 Alignment

Body and conversation are **leading**. Only ceremony beats centre (the
seal, the hold). When you centre, pass it explicitly —
`V8LineText(..., alignment: .center)` — because the primitive's own
frame defaults to leading and will win an argument with its parent.

---

## 3. Colour

| token | value | meaning |
|---|---|---|
| `Palette.bgPrimary` | `#F5F3EF` | paper — **the only page background** (v20: stepped down from #FDFDFC so white cards separate by FILL, see §6.1) |
| `Palette.bgElevated` | `#FFFFFF` | a surface lifted off the paper |
| `Palette.bgInverse` | `#2A1F1E` | ink — declaration surfaces, selected states |
| `Palette.textPrimary` | `#18100F` | ink type |
| `Palette.textSecondary` | `#5A4340` | supporting type |
| `Palette.textInverse` | `#FCFAF7` | type on ink |
| `Palette.accent` | `#C4677A` | dusty rose — the DATA fill (v21) |
| `Palette.accentSubtle` | `#F5D5D8` | blush wash — chip seats, tracks |
| `Palette.roseBlush` | `#E7B3BE` | the ramp's rest: receded marks |
| `Palette.roseBerry` | `#9E4A5F` | the ramp's emphasis: now/today |

Plus the cocoa opacity scale for hairlines and tertiary type:
`cocoaSecondary` (74%), `cocoaTertiary` (62%), `hairlineCocoa` (10%).

**THE ROSE RAMP (v21 — docs/app_v21 §4).** Rose stopped being an
accent and became the DATA hue: everything DRAWN fills from the
ramp; ink keeps words, numerals and selection. The teachable line:

- **Quantities fill rose** — rings, day bars, week bars, sparks,
  split segments. Rest = blush · fill = dusty · now = berry.
- **Trajectories draw ink** — the weight line and its kin; the wash
  beneath warms to blush, the now-dot lands berry.
- **Selection is ink** — the strip's disc, the scope capsule,
  checks. Choosing is a statement, not a datum.

**The one-colour law survives** because the ramp is one COLOUR at
three depths — hue never varies. Depth means *emphasis* (now vs
rest), never *judgment* (good vs bad): anti-shame holds by
construction. The bans stand: no red, no green, no colour-coded
state, no colour carrying meaning alone (§10.8), and rose never
carries small text. THE CLINICAL REGISTER is exempt — medication
surfaces stay unadorned ink (v8 law).

---

## 4. Motion philosophy

Motion is not decoration; it is how the product explains itself.
Three jobs only: **show causality** (this came from that), **show
hierarchy** (this matters more), **show continuity** (you are still in
the same place).

### 4.1 The vocabulary — use these, do not invent

`PlankApp/DesignSystem/Kit/JeniMotion.swift`:

| token | curve | use |
|---|---|---|
| `JeniMotion.arrive` | spring 0.42 / 0.88 | the standard entry (v13: shorter, confident) |
| `JeniMotion.settle` | spring 0.40 / 0.88 | sheets, releases, physical landings |
| `JeniMotion.morph` | spring 0.36 / 0.84 | selection changes, matched geometry |
| `JeniMotion.press` | spring 0.3 / 0.7 | the press acknowledgment |
| `JeniMotion.draw` | timing 0.30/0.8/0.30/1.0 over 0.72s | chart trace-in (v13: inevitable, not performed) |
| `JeniMotion.stagger` | 0.055s | seconds between siblings (one breath, not a parade) |
| `JeniMotion.rise` | 6pt | how far an arriving element travels |
| `JeniMotion.commitDwell` | 0.45s | commit → dismissal beat (p62) |
| `JeniMotion.receiptDwell` | 1.5s | a written receipt's read time (p62) |
| `JeniActs.beat` | 0.55s | between ACTS on a speech arrival (p63, below) |
| `JeniActs.actionPause` | +0.30s | the extra absorb breath BEFORE the final act — the action arrives as its own event (p66) |

**TWO ARRIVAL GRAMMARS (p63).** Assembly and speech are different
jobs and carry different clocks:

- **ASSEMBLY** — `jeniArrive(index:)` at 0.055s. A page builds as one
  breath. Ordinary navigation; never slower than this.
- **SPEECH** — `jeniAct(_:current:)` + `JeniActs.run` at 0.55s. A
  surface where JENI is saying something (a moment cover, a read's
  tail, a clinical statement): one idea arrives, then the next, then
  the action. Use ONLY on surfaces Jeni initiated; never on repeat
  navigation. The primitive carries the laws: a tap anywhere lands
  the remaining acts (§5.7), an act that has not arrived cannot be
  hit (an invisible door is not a door), Reduce Motion arrives whole,
  and the schedule dies with the view.

  **p66 — speech is TACTILE, the way the consult is.** Each THOUGHT
  lands with the grammar's `tick` (the consult acknowledges every
  word against the thumb; a block of meaning gets one soft
  acknowledgment). The FINAL act is the decision by the grammar's
  own law ("the way out arrives last"), so it waits one extra
  absorb breath (`actionPause`) and arrives silent — its motion says
  "your turn". Tap-to-land stays silent: skipping a performance
  should not applaud it. `FoodActs` mirrors both constants and both
  behaviors; the mirror is pinned from both sides
  (`JeniActsGrammarTests` + `FoodActsTests`).

Speech surfaces today: the evening close (statement · receipt ·
asks), the weekly read's tail (receipt · THE OFFER · doors), the
method note (claim · argument · action), reconcile (claim · facts ·
decision). The letter keeps its own line cascade (the protected
rhythm) plus the same tap-to-land.

**A delayed `withAnimation` flips the VALUE instantly** and only
delays the paint — gating anything behaviorally (hit-testing, doors)
on that value ships an invisible-but-tappable control. Schedule the
flip itself, or use `jeniAct` (which gates hit-testing for you).

`PlankApp/Views/OnboardingV8/V8Motion.swift` (the conversation):

| token | value | use |
|---|---|---|
| `V8Tempo.perChar` | 0.034s | typing clock |
| `V8Tempo.commaPause` | +0.16s | a comma breathes |
| `V8Tempo.sentencePause` | +0.32s | a full stop lands |
| `V8Tempo.interLine` | 0.42s | between sentences |
| `V8Tempo.surfaceFlip` | 0.55s | paper ↔ ink crossfade |
| `V8Tempo.advance` | spring 0.55 / 0.90 | the transcript's move |
| `V8Tempo.cascadeStagger` | 0.36s | line-by-line declarations |

**Springs for anything a finger touches. Curves for anything that
draws.** That is the whole rule.

### 4.2 One arrival per screen

A screen owns ONE `arrived` flag, flipped once in `.task`, and
children join by index:

```swift
@State private var arrived = false
...
someView.jeniArrive(arrived, index: 0)
otherView.jeniArrive(arrived, index: 1)
...
.task { try? await Task.sleep(nanoseconds: 60_000_000); arrived = true }
```

Never give each element its own animation trigger. That is confetti,
not choreography.

### 4.3 Charts draw, numbers count, bars land

- Line charts trace left→right on `JeniMotion.draw`.
- Bars land one at a time on a stagger, each with a `JeniHaptic.tick()`.
- Hero numerals count to their value — `JeniCountingNumeral`, never a
  plain `Text` that snaps to its number.
- A re-keyed value **animates to** the new number; it never swaps.

### 4.4 Transitions preserve context

Ranked best to worst. Reach for the top of this list first.

1. **In-tree morph INTO a detented sheet** (v19) — a tile becomes its
   detail page. Nothing is destroyed; it grows, and then it behaves
   like a sheet.
   - **Do not use matched geometry inside a `LazyVGrid`** (proven
     twice): interpolate an explicit rect from the tapped tile's
     reported frame, and carry the page's HEAD by laying it out at
     its FINAL width and applying the surface's own growth ratio as a
     `scaleEffect(anchor: .topLeading)`. At the start of the flight
     the hero renders at the tile's own value size, in the tile's
     position — the tile's words become the page's headline, with
     zero reflow. Content below the head waits for the landing (a
     `Canvas` drawn into a resizing rect flickers).
   - **A native `.sheet` is the wrong trade here**: it buys detents
     for free and costs the shared element, which is the thing that
     makes the page feel connected.
   - **The physics are not optional.** Two rest heights, the drag
     following the finger 1:1, rubber-band resistance past the top
     (~0.22 of the overrun), and a release that settles by VELOCITY
     rather than position alone. A tick per detent crossing, a land
     on dismissal.
   - **Scope the drag to the grabber**, not the whole sheet — that is
     what keeps the ScrollView beneath scrollable without a gesture
     fight.
2. **In-place crossfade** — the surface changes colour/content under
   stable chrome (`V8Tempo.surfaceFlip`). Used for paper ↔ ink.
3. **Staged arrival** — new content builds in on `jeniArrive`.
4. **Full-screen moment** — `JeniMomentView` for declarations (§6.4).
5. Push / sheet — only for genuinely new places.

**Banned:** the default SwiftUI slide, `.transition(.slide)`, and any
navigation push used purely to change content.

### 4.5 Continuous state, not replaced state

When the calendar strip changes days, the disc **morphs** between
days and the content beneath **re-keys and re-counts**. It does not
blink. Same for tab changes, filter changes, unit changes.

### 4.6 Ambient life

Surfaces are never perfectly dead. `JeniAtmosphere` (paper) and
`V8Blooms` (ink) drift on slow mutually-prime orbits so they never
visibly loop.

**Canvas law:** a continuously-redrawn layer must self-drive its
phase from a `.task` loop. Driving a `Canvas` with `withAnimation`
over `@State` freezes it under navigation. This has bitten us twice.

```swift
.task {
    guard !reduceMotion else { return }
    while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 33_000_000)
        t += 0.033
    }
}
```

### 4.7 Celebration — THE DELIGHT GRAMMAR (rewritten p64)

> Founder decision, p64, superseding p63's restraint: **Jeni carries
> a real visual celebration layer.** p63's "no confetti in-app /
> celebration is mostly receipts" was too restrictive and is no
> longer law. What SURVIVES from p63 is the discipline: calm,
> proportionality, no streak pressure, action-local feedback, one
> haptic grammar, and the never-celebrated list.

Jeni acknowledges effort in FOUR tiers, and the tier is decided by
what the moment IS, never by which surface got built most recently:

1. **THE SETTLE** — a state transition + a `tick`/`land` haptic.
   Chips, checks, selections. No copy. (The default; most taps.)
2. **THE SPARK** (p64) — a completed useful behavior: a
   `JeniBurst(.spark)` of paper flecks FROM the control she touched
   + `JeniHaptic.spark()` (pop · short shimmer) + the fact stated
   where words already live (a row's done note, the answer's lead).
   Water marked done, the day's first plate ("today's first
   plate."), the week's strength ask met ("that's twice this
   week."). **Once per moment per day via `CelebrationLedger`** —
   undo/redo answers with the settle; the words repeat with the
   fact, the burst never does.
3. **THE RECEIPT** — a committed FACT answered in words at the site
   of the action: phase swap → one serif line + an honest sub-line
   (`JeniReceiptBeat`) → `JeniHaptic.record()` → `receiptDwell` →
   the surface excuses itself. The weight ritual is the reference;
   the move record and the evening close's goodnight ("that's the
   day, maya.") speak it. A receipt states facts already on hand —
   never praise, never a verdict (the PlateAnswerEngine refusals).
   A receipt may CARRY a spark's burst when the fact it states is a
   spark moment (the ask-met move record); the close stays calm.
4. **THE CREST / THE MOMENT** — the peaks, and they own a PAGE
   (p65's `JeniMomentView`: COMMIT → CELEBRATION → CONTINUE → HOME;
   record first, ceremony only after a true save). The protein
   floor CROSSING (at most once per day BY CONSTRUCTION): crest
   haptic + the word-anchored pop riding "floor covered" **+ a
   medium full-page SHOWER (p66)**, and the dial's check DRAWS at
   the return (witnessed live only; a cold launch rests complete —
   §8.3, an appearance is a passive event). First plate EVER (once
   per lifetime): "your record starts here." + the pop + **the full
   shower — the biggest celebration the product makes.**

**THE BURST LAWS (`JeniBurst`, the ONE particle engine — two
registers since p66):**
- **the POP** originates from the thing celebrated — never
  screen-edge rain. **THE SHOWER (p66, `.shower`)** is the sanctioned
  exception for the moment PAGE only: a full-page volley of the same
  torn paper, launched from the bottom corners, rising past the
  words and flutter-falling at terminal velocity — the recognizable
  confetti moment in Jeni's own material. Crest earns a medium
  shower (78 flecks), moment the full one (130); spark NEVER
  (frequency law by construction, pinned in
  `JeniBurstShowerTests`).
- torn-paper flecks in the rose ramp + ink accents; 3 hues, never
  rainbow (chosen on film against light-rays and petal-dots — p64)
- proportional tiers by construction (spark ~18 flecks/0.9s · crest
  ~32/1.1s · moment ~46/1.4s, two waves); never blocks input; zero
  cost at rest; deterministic per play
- **automatic facts celebrate quietly**: a HealthKit-crossed step
  goal witnessed live draws its check + flecks with NO haptic (a
  passive event never vibrates); arriving with it already crossed
  rests complete. Explicit acts get the full composed event.
- **Reduce Motion renders no particles** — the state change, the
  words and the haptic still carry the whole meaning (never remove
  information, only motion).
- eligibility is DOMAIN LOGIC (`CelebrationLedger` /
  `PlateCelebration.claim`), never an `if` scattered in a view; a
  celebration corresponds to a meaningful committed event, not a
  SwiftUI render. One celebration per commit — the biggest fact
  wins (moment > crest > spark).
- latch keys live under `celebration.` and join the §38 sweep.

**What is NEVER celebrated (binding, unchanged):** eating less ·
calories "left" or "under" · weight numbers or milestones · streaks
(PresenceLedger stays a coach-context fact; no surface counts days
at the user) · anything a suppressed cohort is not shown · dose
marking (the clinical register acknowledges, never celebrates) ·
weigh-ins keep the receipt WITHOUT a burst (the ritual is additive
but flecks beside a weight numeral would read as celebrating the
number). Celebrating restriction is the documented harm class
(BJPsych Open 2017; the category's gamified-restriction spiral) —
every celebrated moment is something she ADDED: a plate, water,
movement, protein. The evening close stays a calm receipt — the
day's end never competes with confetti.

**The Lottie set** (`EffectAnimation` via `LottieEffectView`,
Reduce Motion → `Color.clear`) remains the ONBOARDING's register
(plan seal `.confettiSoft`, first promise `.fireworks`; preload
with `EffectAnimation.fireworks.preload()`). In-app celebration is
`JeniBurst` — the app's own hand, not a stock asset — and the
object still celebrates alongside it (the stroke draws, the row
compresses, the receipt is written). **p66 evidence:** all six
bundled effect Lotties were filmed ON the real moment page and
lost — candy-magenta against the rose ramp, 0.6-2s comps, action
filling a fraction of the frame (films in
`docs/app_v25/66_evidence/`). Recognizable celebration language is
sanctioned; stock ASSETS for it are not, because color truth,
scale, determinism and honest Reduce Motion all live in the native
engine.

---

## 5. Interaction philosophy

**5.1 — Every tap is acknowledged within 100ms.** Press states are
physical: `JeniPressable` (scale 0.98 + slight dim) for cards and
objects — `JKPress` is its second name (p63 unified the two
dialects) and `FoodPress` its package mirror — `JeniRowPressStyle`
(dim only) for rows. Never a highlight rectangle, and **never
`.buttonStyle(.plain)` on a shipping control**: `.plain` is
press-DEAD, and 37 of the food rail's 37 buttons shipped that way
before p63. A control that does not answer the finger is the audit's
first find, every time.

**5.2 — One primary action per screen, and ONE object plays it.**
At most one ink pill visible, and it is `JFContinueButton` — the
standing CTA (56pt centered upright-sans capsule, the her75
register, `padded: false` when embedded). p66 retired the last
hand-rolled twins (the method note's serif-in-capsule, the letter's
short 'reply'). The full hierarchy:
- **PRIMARY** — the standing CTA. When a screen has one obvious next
  step it is BIG, bottom-anchored in the thumb zone on its own paper
  fade (Move is the reference after p66; the onboarding always was).
- **SECONDARY** — a hairline capsule (the chip grammar) or the CTA's
  built-in `secondaryLabel` slot. Never a second pill.
- **QUIET** — a text row at the 44pt floor ("not now", "no thanks").
Visible size, hit region and visual prominence are three separate
decisions (§10.5): an important action must LOOK important, not
merely carry a hidden 44pt hit box.

**THE STICKY ANATOMY (founder law, p66):** the big primary action is
STICKY at the screen's bottom edge (safeAreaInset on its own paper
fade — never scrolled away with content), and the exit (X or back)
is STICKY at the top. Only the content scrolls between them. The
method note and the move record sheet are the references; a short
page keeps its optical-center float BETWEEN the pinned bands.

**5.3 — The answer commits itself.** Single-select advances on tap —
no "continue" after a choice. Only multi-select and rulers need a
commit button, and it docks at the bottom where thumbs are.

**5.4 — Selection is a morph, not a repaint.** Selected = ink fill +
paper text, animated on `JeniMotion.morph`.

**5.5 — Everything the user says gets echoed.** An answer that
produces no visible consequence is a dead question — cut it or wire
it (the consequence law).

**5.6 — Errors are absorbed by the conversation.** A bad clinician
code types a sentence and re-opens the field. Never an alert dialog
for anything the interface can say itself.

**5.7 — Tap-to-skip.** While Jeni is typing, a tap completes the
line. When she's done, a tap advances. Impatience is a valid input.

**5.8 — Destructive and irreversible actions get a hold**, not a
confirm dialog — `HoldToPromiseButton`.

**5.9 — THE ILLUSTRATION REGISTER (founder law, p66).** Screens
that need an illustration carry ONE big hand-drawn doodle
(`JeniDoodle`, the `doodle-*` template imagesets — the same set
Home's task chips already speak, at illustration scale ~140pt)
drifting on a slow Lissajous MOTION PATH (±7pt, a whisper of
rotation; Reduce Motion = still). Ink on paper — never a second
palette; decorative only — hidden from VoiceOver; at most one per
screen, and only where there is genuine air. Empty states are the
canonical site (`JKEmptyState(doodle:)`); a dense instrument panel
never earns one.

**5.10 — THE INTERRUPTION POLICY (p66).** A Jeni-initiated surface —
any cover, card, note or ask the user did not summon — must earn its
interruption by doing one of exactly these:
- reminding her of an action that matters TODAY and would otherwise
  be missed;
- surfacing an insight from HER record she would not notice herself;
- asking for a missing fact that unlocks something, in the value
  shape *we're missing X → here's why it matters → give it to me →
  now I can do Y* (the day-one card is the reference);
- preventing a mistake or resolving an ambiguity she is standing in.
Never conversational filler, never a surface that exists because we
built a system for it. One interruption per arrival (the
`HomeAutoPresent` arbiter), each once-per-day/once-ever by
construction, and every interruption must DISCHARGE its reason: a
letter read by hand counts as read (the p66 dateline fix — an
interruption whose reason is gone may not fire). Surfaces that speak
get the speech grammar; surfaces she summoned get assembly (§4.1).

---

## 6. Component system

**The rule: compose from these. If you need something new, add it
HERE, do not invent it locally.**

### 6.1 Surfaces
| component | use |
|---|---|
| `JeniSurface` | **v20 material — SEPARATION BY FILL**: pure white on the warm paper, **no border at all**, one soft contact shadow (4%, r10, y3) |
| `jeniSheet` | bottom sheet — paper, 28pt radius, grabber, exactly one primary action |

**NEVER DRAW A BORDER ON A CARD (v20).** Every premium reference —
Apple Health, Journal, Fitness, Wallet, Revolut, Monzo — separates a
card by **fill contrast** and draws no line. A hairline border on a
card is a 2010s web pattern (Bootstrap, Material 1) and it is the
single detail that makes a modern layout read as old.

If a card needs a border to be visible, **the palette is wrong, not
the card.** That was literally true here: paper `#FDFDFC` against
white `#FFFFFF` differed by 0.4%, so the border was a symptom. The
paper stepped down to `#F5F3EF` and every border was deleted.

Corollary: **darker-than-paper means SUNKEN.** A tinted fill on a
light page reads as disabled — never use one for something the user
may still act on (the "optional" task rows sit on bare paper instead).

**ONE MATERIAL PER SURFACE (v18.2).** The container rule below is
scoped per surface, and each surface must be internally consistent —
mixed materials on one screen are what read as "unfinished".

- **Home is a DAY.** Readings live on paper; only what she touches
  wears a surface (the rule below).
- **Becoming is a DASHBOARD.** Every module is a PANEL — the body
  read, the insight carousel, the metric tiles. A panel is what makes
  an instrument legible as a unit, and **a panel carries its own
  door** (its "read more" belongs inside it, never floating between
  two cards).

**TWO COLUMNS IS THE MAXIMUM, and the grid is not filled because it
exists (v18.3).** Three columns reads as complexity, not density.
Only metrics that answer the surface's question *at a glance* earn a
tile (`isPrimary` — weight · calories · protein · steps); every other
live metric is a ROW carrying the same number and the same shape at
~46pt instead of ~104. A row is not a demotion — it keeps its figure
and its chart; it just stops claiming a panel's worth of attention.

**An insight must say something the grid cannot**, and **a card never
leads with a zero.** The protein-days card was cut for restating the
protein tile and for reading "0 of 4 days" on a thin week.

Inside a panel, a sentence is a CAPTION (13pt DM Sans), not an
editorial line — the editorial register belongs to surfaces that say
one thing.

**ELEVATION MEANS ACTIONABILITY (v15 — the container law).**

> A reading lives on the paper. A surface is for what she touches.

Home's nutrition hero, Becoming's body read and the insight cards
are READINGS — they sit directly on the paper and let typography
carry them. The day's ask and the tool doors are things she touches,
so they wear `JeniSurface`. The result is one card in Home's top
half and one obvious hero per page. When you are tempted to box
something, ask whether a finger goes there; if not, it does not get
a surface.

### 6.2 Type + structure
| component | use |
|---|---|
| `JeniHeadline` | serif line with italic punch (`.page` 34 / `.hero` 38 / `.band` 26) |
| `ItalicAccentText` | the composition primitive underneath it |
| `JeniSectionHeader` | 11pt tracked caps — **the only separator in the app** |
| `V8LineText` | stable-layout typed line (paints unrevealed chars clear) |

### 6.3 Controls
| component | use |
|---|---|
| `JeniPrimaryButton` | THE ink pill (wraps `JFContinueButton`) |
| `JeniRow` | universal 60pt list row — words, no icons, render-only trailing |
| `JeniCheck` | the drawn check circle — quick-mark on cards |
| `JeniPressable` | the card press style |
| `HoldToPromiseButton` | hold-to-commit; announces its own label |
| `OV5Ruler` | the tick ruler for any biometric value |
| `V8OptionCard` / `V8QuizCard` | single-select cards (text / image-led) |

### 6.4 Moments + data
| component | use |
|---|---|
| **`JeniMomentView`** | **THE full-page celebration surface** (p65/p66): eyebrow → serif headline + the word-anchored pop (+ the shower on earned tiers) → fact → the standing CTA, on the speech grammar. A new moment is a payload (`PlateMoment`), never a new screen |
| `JeniChart` | the ONE chart engine (Canvas). SwiftUI Charts is banned. v12 marks: monotone-cubic smooth lines 2.2pt, 10% wash, bars ≤24pt rounded-top/square-base on a grounding hairline, `emphasizeLast` for faces, 8pt surface-ringed end dot; re-traces when its data changes |
| `JeniCountingNumeral` | any number that matters; morphs to a changed value, arms on first visibility |
| `JeniBurst` (p64) | the ONE particle engine — origin-anchored paper-fleck burst, three proportional tiers (spark/crest/moment), deterministic, non-blocking, zero at rest; Reduce Motion renders nothing (§4.7 carries its laws) |

### 6.4b The glance layer (v12 — docs/app_v12/00_CRAFT.md · v21 rose)
| component | use |
|---|---|
| `JeniRing` | the drawn arc gauge — blush track, dusty→berry arc whose far stop rides the drawn fraction; traces in on `JeniMotion.elastic` (~4% overshoot), morphs on change |
| `JeniMetricBar` | label · value · rose landing bar (berry at a met floor); NO fill without a collected denominator |
| `JeniSparkRow` | a metric's own seven days — blush week, berry today; marks read as BARS (cap 9pt), bound the row's width so it stays an instrument |
| `JeniWeekDots` | the week dot row — filled days are berry and draw their check; empty days are quiet rings, never marks |
| `JeniScopeBar` | the time-scope selector (today…all); the ink capsule morphs between words; content re-keys, never reloads |
| `JeniInsightPager` / `JeniInsightCard` | the insight carousel: eyebrow → hero numeral → one rose figure → one sentence; every card floor-gated |
| `JeniPageDots` (v21) | every pager's index: blush dots, the current page a berry pill |
| `JeniTaskRow` (v21, amended p64) | a task as an OBJECT: identity chip (blush seat · berry symbol · or the day's real photo) · words · drawn check; row opens, check quick-marks, long-press overrides; completion pulses the chip and COMPRESSES the row to a receipt — OFFERED rows included (p64: a marked water and a crossed step goal used to render byte-identical to their invitations; a fact that happened must render). Offered = hairline seat on bare paper, may carry the check when its whole job is a mark (water) or a render-only drawn check when it auto-completes (steps); `clinical` = ink, no rose |

**The visibility gate.** Glance pieces, `JeniChart` and
`JeniCountingNumeral` arm on `arrived AND first-visible` — a
below-fold chart draws when she reaches it, never invisibly at load.
| `V8Figure` / `V8FigureView` | drawn evidence (curves, bars, dot rows) |
| `V8Glyph` / `V8GlyphView` | drawn pictograms for image-led choices |
| `JeniMark` | the official j mark — one colour, never redrawn |

### 6.5 Moments (amended p62)

Anything the product *declares* — the evening close, a milestone, a
weekly read, a care-team message worth stopping for — takes the whole
screen as a `jeniCover` that MATERIALIZES (instant present; the
moment stages its own arrival — the letter's recorded pattern, p61's
one cover grammar). **Do not** wedge a declaration into a scrolling
surface as a giant headline — that is what Home used to do and it is
explicitly dead (§12.9).

> Historical note: a `JeniMoment` wrapper component shipped with v12
> and was deleted in p62 with **zero call sites** — every real moment
> (the close, the letter, the read) had grown its own staged interior
> instead. The LAW survives the component: full screen, materialize,
> eyebrow → serif lines → one action, silence around it. Build new
> moments from `jeniCover` + the kit primitives directly.

---

## 7. Layout + spacing system

### 7.1 The scale

`Space` in `Tokens.swift`. Use the token; never a magic number.

| token | pt | use |
|---|---|---|
| `xs` | 4 | hairline nudges |
| `sm` | 8 | inside a control |
| `md` | 16 | between related lines |
| `blockGap` | 20 | inside a surface / between blocks |
| `lg` / `gutter` | 24 | **the page gutter — every screen** |
| `hero` | 40 | top air above a title |
| `sectionGap` | 44 | between sections |
| `xl` | 48 | dramatic separation |
| `heroGap` | 56 | bottom air |
| `minTapTarget` | 44 | never smaller, ever |

**The dashboard budget (v17).** On Home and Becoming, measure before
you style. The costs that actually decide whether a screen informs:
a `JeniSectionHeader` is **50pt** (28 air + 14 type + 8), a task
CARD is **~120pt** where a row is **~48pt**, and a hero-scale
greeting with a sub-line is **~90pt** where a header is **~48pt**.
Three headers and one hero greeting were spending a third of the
screen on furniture. Rules that follow:
- **A band that names itself gets no section header** — put the
  label INSIDE the band at 10pt (the reference's card-label move).
- **One module, one question, one treatment.** TODAY is a checklist;
  the lead is the first row in SemiBold, not a card in another
  register. Two treatments for one question is the tell.
- **Measure the fold.** If the three questions ("how am I doing /
  what changed / what next") are not answered without scrolling, the
  composition is wrong — not the typography.

**Two scales, deliberately (v16).** The gaps above are EDITORIAL —
for surfaces that say one thing: the consult, a moment, a detail
story. A control center is a different instrument and composes on
the dashboard scale: `bandGap` (28) between bands, `bandRow` (12)
inside one, and `Typo.numeralDash` (44) for a lead figure that must
share its screen with six other numbers. **Home and Becoming use the
dashboard scale; everything else uses the editorial one.** Do not
unify them — the onboarding is the benchmark and must not be re-cut
to make a dashboard denser.

### 7.2 Rules

- **Rhythm is COMPOSED, not uniform (v15).** A page that separates
  every movement by the same 44pt reads as a list of equals. Score
  it: compress what belongs together (Home's greeting + strip +
  dateline are ONE block — all of them answer "where am I"), then
  spend the air where it matters (`topAir: Space.heroGap` before a
  hero and before a closing grid). `JeniSectionHeader(_:topAir:)` is
  the instrument.
- **Every full-screen surface carries `Space.gutter` horizontally.**
  The single most common bug in this codebase is a hero line with no
  gutter running off both edges. Check it every time.
- Whitespace is the divider. No horizontal rules between sections;
  only ledgers (receipts, tables of facts) may use hairlines.
- Optical over mechanical: a serif cap-height sits differently than a
  sans x-height. Trust the eye over the number, then bake the number.
- Content column stays left-aligned; only ceremony centres.
- Bottom-dock commit actions; never make a thumb reach up.
- Anything below the fold that matters must be reachable without
  hunting — if a leg has to scroll to find it, so does a person.

### 7.3 Screen anatomy — HOME (binding, amended p59)

Home always reads, at every hour of the day:

```
greeting                     — human line, name in lighter ink
dateline                     — DAY 12 · rule · the week's word (serif
                               italic); the letter's door; caps at XXXL
calendar strip               — week paging, disc morphs, content re-keys
[dose standing]              — the clinical object row (GLP-1 only)
FOOD · THE DIAL              — the 156pt remainder dial (protein iff a
                               floor exists, else calories) + THE
                               MINIS (sugar badge · fiber·dv gauge ·
                               kcal-left gauge, 52pt echoes of the
                               parent); carousel: plates face, numbers
                               face (carbs · fat · sodium) — each
                               face exists only when the record
                               earned it, each fact in ONE place. AX
                               sizes keep the words-and-thread
                               receipt; suppression keeps the
                               words-only face.
TODAY / STILL TODAY          — the day objects (52pt seats, ink stamp)
TOOLS                        — the hairline index (word · state)
[evening] close the day      — invitation into JeniMoment
```

Nutrition, the list, and the tools are **never** removed, replaced or
swapped out by a state. States change their CONTENT, not Home's
anatomy. Only collected targets may speak "left" or draw a gauge —
the protein floor and the kcal target; fiber may gauge against the
FDA dv ONLY with the dv named on its label; sugar (and anything else
without a denominator) gets a BADGE, never a gauge, never a
remainder.

---

## 8. Haptic philosophy

Following Apple's HIG: haptics **confirm what already happened
visually**. They are never the main event and never fire for
something the user did not cause.

### 8.1 The grammar — four words

`JeniHaptic` in `JeniMotion.swift`:

| word | feel | when |
|---|---|---|
| `tick()` | light | selection, detent, a staggered item landing, a word arriving |
| `land()` | soft | a completed action, an acknowledgment, a sentence ending |
| `record()` | success | a FACT entering the record — dose marked, weight kept, plate filed. The strongest confirm the product makes, and every record landing feels the same (p58) |
| `swell()` | medium | ONE hero moment per flow — the seal |
| `spark()` | CoreHaptics phrase (pop · short shimmer) | a SMALL celebration's tactile half (p64) — water marked, the day's first plate, the ask met. Ledger-latched once per moment per day; never a substitute for `record` when a fact enters the record |
| `crest()` | CoreHaptics phrase (touch · landing · warm bloom) | the day's ONE peak — the protein floor crossing, riding the plate answer's words. At most once a day by construction; a crest that fired twice a day would just be a loud `record` (p63). First plate EVER shares this hand (once per lifetime, p64) |

The richer CoreHaptics voice (`ActivationHaptics`) stays ONE engine:
`crest()` and `spark()` route through the grammar; the letter's seal
keeps `commit()` and the close's goodnight keeps `arcComplete()` (a
breath, not a thunk — closing the day files nothing new). New
patterns are design decisions added THERE, never a second engine.

### 8.2 Where each fires

| interaction | haptic |
|---|---|
| option / chip selected | `tick` |
| multi-select toggle | `tick` |
| ruler crossing a unit | `tick` (`land` on a major) |
| calendar day changed | `tick` |
| time-scope changed | `tick` |
| chart scrub detent | `tick` |
| carousel page detent | `tick` |
| typed word arriving | `tick`, rate-limited to ≥90ms |
| sentence completing | `land` |
| task checked off | `land` |
| a spark moment completing (water done, first plate today, ask met) | `land`/`record` for the act + `spark` riding it |
| a step goal crossing on its own, witnessed | NOTHING — the check draws, flecks fly, the hand stays quiet (§8.3: passive events never vibrate) |
| plate filed / dose marked / weight kept | `record` |
| hold sealed | `swell` |

**v14 amendments — one interaction, one response.** A chart DRAWING
is ambient and never vibrates (the per-bar tick died: a grid of
charts arming together was spam that read as lag). Paging a week on
the strip is SCROLLING — scrolling never vibrates; the tick belongs
to selecting a day. When several components could answer one
gesture, exactly one does.

### 8.3 Rules

- **Rate-limit.** Never more than ~11/second. The typewriter enforces
  a 90ms floor between ticks; anything looping must do the same.
- **Never haptic a passive event** — an arriving notification, a
  background sync, a screen simply appearing.
- **Reduce Motion silences decorative haptics** along with the motion
  they accompany.
- Haptics ride the action, not its completion callback — fire on the
  gesture, not after the network.

---

## 9. Animation rules (checklist)

Before shipping any animated surface:

1. Does anything **pop** into existence? → give it `jeniArrive`.
2. Does anything **disappear instantly**? → give it a fade or a
   dissolve.
3. Does a number **snap**? → `JeniCountingNumeral`.
4. Does a chart **appear drawn**? → make it draw.
5. Is a spring used for something that isn't touched, or a curve for
   something that is? → swap them.
6. Does the screen animate **more than one thing per beat**? →
   sequence them.
7. Under Reduce Motion, does everything still make sense? → whole-line
   fades, still ambience, no bursts.
8. Does a `Canvas` animation survive a navigation push? → self-drive
   from `.task`.
9. Does the transition **preserve context** (§4.4)?
10. Does anything animate on **launch** that should just be there?

---

## 10. Accessibility rules

**Non-negotiable. A screen that fails these is not done.**

1. **Every interactive element has a real label** — and the label is
   what it SAYS. (`HoldToPromiseButton` announced "seal your promise"
   on a button reading "hold to build it" for months. Do not repeat
   that class of bug.)
2. **Dynamic Type**: all fonts use `relativeTo:`. Nothing clips at
   XXXL; long content scrolls. **A fixed frame around scaling type is
   always a bug** (v19.1 — a pager's fixed 132pt height clipped its
   own eyebrow and last line at XXXL). If a container must have a
   height, drive it with `@ScaledMetric`; and pick `relativeTo:` for
   PROPORTION, not just fit — a hero on `.largeTitle` outgrows its
   card long before the body copy does.
3. **Reduce Motion**: typing becomes whole lines, bursts become
   nothing, ambience holds still, transitions become 200ms fades.
   Never remove information — only motion.
4. **Contrast**: 4.5:1 for body, 3:1 for large type. The state colours
   in `Tokens.swift` are already corrected — use them, don't invent.
5. **Tap targets ≥ 44pt**, including drawn marks (wrap a 26pt glyph
   in a 44pt frame). The mechanism is named: `tappableArea()`
   (`foodTappableArea()` in the package) when layout may grow, or
   the pad → `contentShape` → negative-pad fold when it may not
   (the p63 dateline). Visible chrome and hit region are different
   design problems — solve the region without inflating the glyph.
6. **VoiceOver order follows reading order.** Group decorative parts
   with `.accessibilityHidden(true)` — every chart, glyph, bloom and
   burst is decorative and needs a text equivalent nearby.
7. **Charts carry an `accessibilityText`** describing the trend in
   words.
8. **Never gate meaning on colour alone.**
9. Typed text posts its FULL string to VoiceOver immediately — the
   animation is visual only.
10. Add a **stable `accessibilityIdentifier`** to anything a QA leg
    will drive.

---

## 11. Copywriting rules

### 11.1 The two registers

**B2C — everyday people losing weight.** Straightforward, simple,
friendly, confident, lightly Gen-Z in energy, modern, succinct, human.
An intelligent coach talking normally.

> "noted. short sleep raises appetite, so the plan accounts for it."
> "3 to 5 tries isn't a willpower problem. you were missing a system."
> "16 lb. at a safe pace, that's about 13 weeks. an estimate, not a promise."

**B2B — clinics, physicians, dietitians.** Clear, direct, clinical,
professional, succinct, evidence-oriented. No marketing, no emotion,
no slang, no personality.

> "your clinician leads the medical side. i handle the everyday:
> food, movement, the numbers between visits."
> "this is the SCOFF screen, a five-question check developed for
> clinical practice (morgan 1999, bmj)."

Both registers share the mechanics below.

### 11.2 Mechanics

- **lowercase** for Jeni's voice. Tracked caps only for eyebrows.
- **Italic punch**: 1-3 words, composed (§2.3).
- **No em-dashes between words.** Full stop, comma, or interpunct (·).
- **Never the word "AI"** in user copy. Say what it does.
- **No hearts**, no emoji in product copy.
- **Direct verbs**: "sugar intake", never "sweetness". "add", "mark",
  "weigh in".
- **No controlling verbs**: never "must", "should", "need to".
- **Gain-frame**: "room left", never "over budget".
- **Sentences, not aphorisms.** If it sounds like a fortune cookie,
  rewrite it.

### 11.3 Evidence

Every claim carries number + unit + named source. The vetted set:
NEJM STEP-1 (lean mass) · JAMA 2025 (discontinuation) · Hayashi 2023
(food-cue reactivity) · Wycherley 2012 AJCN (protein) · ACSM
0.5-1%/wk (pace) · Morgan 1999 BMJ (SCOFF) · FDA/DPP (5-7%
benchmark). **Do not add to this list without a real citation.**

Hedges stay: "an estimate, not a promise" is a credibility asset.

### 11.4 Anti-shame

No red bars. No "over budget". No earned-food grammar ("you've earned
this"). No streak threats. Under-target is stated as room remaining.
A fuller week is never scolded.

### 11.5 Compliance floors

No drug brand names. No drug-equivalence claims. No first-party
numeric weight-loss claims. Never "HIPAA compliant" (internal dev
alpha, no BAA). Body fat never comes from a photograph.

---

## 12. Things we intentionally NEVER do

1. **Never a default SwiftUI transition** on a designed surface.
2. **Never a push to change content** in place.
3. **Never a second primary button** on a screen.
4. **Never a border + shadow + fill** on the same element. Pick depth
   OR line, and prefer depth (`JeniSurface`).
5. **Never a colour to carry state.** No red, no green, no traffic
   lights.
6. **Never stock photography or generic icon sets.** Illustrations are
   drawn in the stationery stroke register (`V8Glyph`, `JKMark`).
   *Amended v18:* SF Symbols allowed on the dashboard's task list and
   tool grid as a scoped exception.
   *Amended v21:* the exception largely retired — THE DOODLE SET
   (founder-supplied, `doodle-*` template assets in Assets.xcassets)
   IS the stationery stroke register, ready-made: single-weight
   hand-drawn strokes, tinted like symbols (berry on the blush seat;
   quiet ink when offered). Four glyphs were authored in-house to
   complete coverage (book · shoe · scale · footprints) — when the
   set lacks a glyph, AUTHOR it in the register; never mix icon
   voices inside one surface (film-caught: SF walk beside doodle
   cutlery read as two sets). Exceptions that stand: MEDICATION keeps
   its unadorned SF glyph (the clinical register is set apart on
   purpose), and symbols never carry meaning alone (§10.8).
7. **Never a raw font size or a magic spacing number.** Token or
   nothing.
8. **Never an alert for something the interface can say.**
9. **Never a takeover headline inside a scrolling surface.**
   Declarations get `JeniMomentView`.
10. **Never a number without provenance.**
11. **Never a question whose answer changes nothing.**
12. **Never haptics for passive events**, and never unrated bursts.
13. **Never `.italic()` on a whole sentence**, never `*markers*`.
14. **Never break the gutter.** No full-bleed text.
15. **Never leave an element unlabelled** for VoiceOver.

---

## 13. Liquid Glass — the honest position

The founder asked for aggressive adoption of Apple's Liquid Glass.
**Constraint: this app's deployment target is iOS 17.0.**
`.glassEffect()` and `GlassEffectContainer` are **iOS 26+**. They
cannot be adopted unconditionally without dropping iOS 17-25 users —
that is a founder-level business decision, not a design one.

**The rule until that decision is made:**

```swift
// Availability-gated, with the shipped material as the floor.
if #available(iOS 26.0, *) {
    content.glassEffect(.regular, in: .capsule)
} else {
    content.background(.ultraThinMaterial, in: .capsule)
}
```

**Where glass (or its material floor) is allowed** — chrome only:
- the floating tab bar and navigation surfaces
- bottom sheets and their grabbers
- floating controls that sit OVER content (the scan launcher, a
  back-to-today pill)
- toolbars and context menus
- transient overlays (the nudge banner)

**Where it is banned** — content:
- anything carrying data: nutrition, charts, receipts, task cards
- anything behind body text
- `JeniSurface` — the product's card material is opaque paper by
  design, and blur behind text degrades reading and contrast

Glass earns its place by improving *separation between chrome and
content*. Used on content it becomes noise, and it fails §10.4
contrast.

---

## 14. Examples — good and bad

### 14.1 A hero line

```swift
// GOOD — token, negative leading, composed punch, gutter, centred explicitly
V8LineText(
    line: V8Line("everything's here.", italic: ["everything's"]),
    font: Typo.displayHero, italicFont: Typo.displayHeroItalic,
    color: Palette.textPrimary, alignment: .center
)
.lineSpacing(Typo.displayHeroLineGap)
.padding(.horizontal, Space.gutter)

// BAD — raw size, default leading, whole-line italic, no gutter
Text("everything's here.")
    .font(.system(size: 38, design: .serif)).italic()
```
*(The bad version is what shipped and ran off both screen edges.)*

### 14.2 An arriving section

```swift
// GOOD — one page flag, indexed children
VStack {
    header.jeniArrive(arrived, index: 0)
    card.jeniArrive(arrived, index: 1)
    rows.jeniArrive(arrived, index: 2)
}
.task { try? await Task.sleep(nanoseconds: 60_000_000); arrived = true }

// BAD — three independent animations racing each other
header.onAppear { withAnimation { showHeader = true } }
card.onAppear   { withAnimation { showCard = true } }
```

### 14.3 A number

```swift
// GOOD
JeniCountingNumeral(value: Double(snapshot.kcalEaten), unit: "of 1,573 kcal")

// BAD — snaps, and invents a figure nothing produced
Text("\(Int.random(in: 900...1200)) kcal").font(.title)
```

### 14.4 A state change

```swift
// GOOD — the disc morphs, content re-keys and re-counts
withAnimation(JeniMotion.morph) { selectedDate = day }

// BAD — the page blinks
selectedDate = day
```

### 14.5 An error

```swift
// GOOD — the conversation absorbs it and re-opens the field
return .retry([V8Line("that code didn't land. double-check it with your clinic, or skip for now.")])

// BAD
showAlert = true   // "Error: invalid code"
```

### 14.6 An empty state (the Becoming case, 2026-08-06)

Becoming rendered ELEVEN identical square tiles. Five of them said
"logging · 0 of 3 days" in 20pt serif. That is three violations at
once: the uniform card grid (§15 hunt list), decoration carrying no
information (§1.7), and serif used for a system status rather than
Jeni's voice (§2).

```swift
// GOOD — metrics that READ keep the grid; the rest collapse into
// canonical rows that open the same page from the same morph.
let live    = tiles.filter(\.meetsFloor)
let waiting = tiles.filter { !$0.meetsFloor }
LazyVGrid(...) { ForEach(live) { BecomingTileView(tile: $0, ...) } }
JeniSectionHeader("not enough to read yet")
ForEach(waiting) { JeniRow($0.title.lowercased(), detail: $0.value,
                           trailing: .chevron, action: ...) }

// BAD — every metric gets a tile whether it has anything to say or not
LazyVGrid(...) { ForEach(tiles) { BecomingTileView(tile: $0, ...) } }
```

Note the header wording: the first attempt said "not reading yet",
but weight WAS showing 159.0 lb — it simply had no trend. The header
has to be true of every row beneath it (§1.6).

### 14.7 Copy

```
GOOD: "noted. short sleep raises appetite, so the plan accounts for it."
BAD:  "your body whispers its needs in the quiet hours — we listen."

GOOD: "16 lb. at a safe pace, that's about 13 weeks. an estimate, not a promise."
BAD:  "you'll lose 16 lb in 13 weeks!"

GOOD (B2B): "connected to demo clinic. they see what you choose to share."
BAD  (B2B): "yay! you're all linked up with your care squad 🎉"
```

---

## 15. The verification loop (how we know it's done)

Every design pass ends with THE LOOP, not with "it compiles":

```
build → install → DRIVE it (XCUI leg, not a preview) → record video
      → dump frames (ffmpeg) → inspect neighbours → find the flaw
      → fix → repeat
```

Exit condition: **you honestly cannot find another obvious issue** —
not "I did one pass".

Per screen, ask in order: *Would Apple ship this? Would it hold up in
a WWDC keynote? Would frame-by-frame inspection embarrass us?*

Hunt these by name: animation pops · layout jumps · shared-element
failures · timing inconsistencies · stutter · awkward easing ·
clipping · alignment drift · typography inconsistency · uniform card
grids · mechanically-even spacing where optical is needed ·
centred-everything · decoration carrying no information · gradient
soup.

**Tooling that exists — use it:**
- `--debug-v8-hold` · `--debug-v8-health` · `--debug-hold-promise` ·
  `--debug-v11-gallery` mount single surfaces in seconds.
- `--uitest-inapp-qa --uitest-pro-access` lands past the paywall;
  `--uitest-force-evening` / `--uitest-force-day` fix the hour.
- Legs: `testHomeAnatomyDayAndEvening`, `testV8CloseCelebrations`,
  `testWalkV8ToPaywall`, `testWalkV8ClinicToPaywall`.
- **XCUI trap:** tapping an element that exists but is below the fold
  coordinate-taps whatever is on screen there. Scroll until
  `isHittable`, then tap.
- **Sim trap:** legs that COMPLETE onboarding must start from an
  erased sim, or the previous run's state hydrates back mid-leg.

---

## 16. Migration log — surfaces brought onto the language

| surface | date | what changed |
|---|---|---|
| onboarding (v8 THE CONSULT) | 2026-08-06 | the reference implementation |
| Home | 2026-08-06 | anatomy fixed (nutrition + list + tools at every hour); the evening takeover became `JeniMoment` |
| Becoming | 2026-08-06 | uniform 11-tile grid → readings in the grid, everything else in `JeniRow`s; serif reserved for readings |
| Settings | 2026-08-06 | 54 raw `.system` calls → DM Sans + Dynamic Type; rose per-row icons → quiet ink glyphs; per-row hairlines removed |
| Home (v12 CRAFT) | 2026-08-07 | the nutrition CENTERPIECE (numeral+ring+macro bars+chemistry whisper; a landed plate MORPHS everything forward); living greeting sub-line; task count chip; tools as destinations with state lines; directional recap (D13); tactile strip |
| Becoming (v12 CRAFT) | 2026-08-07 | JeniScopeBar time scopes (morph, never reload); tile faces carry REAL mini charts (ribbons retired); the insight carousel (R6 grammar); detail pages: ledger + WHAT THE PLAN DOES + provenance; care-connected patients read YOUR CARE first |
| charts (v12 CRAFT) | 2026-08-07 | the mark maturation in `JeniChart` (see 6.4) — founder steer "charts look sketched"; no library, the craft is the drawing |
| evening close (v12) | 2026-08-07 | opens on the hero numeral ("12 · of 140 days", 96pt, counted) — the R6 grammar |
| v13 THE REDUCTION | 2026-08-07 | clarity is premium: the dateline left the caps register (headers alone wear caps); no track without a collected target; tool glyphs died (words + state lines); supporting/offered tasks are ROWS (the lead alone earns a card); Becoming's hero left its card (typography + chart on paper; a hero states, never apologizes); per-tile chevrons died; detail pages lost their three caps labels (sentences grouped by air, provenance last); poetry cut app-wide ("can speak", "a quiet page", weather metaphors); motion shortened (§4.1) |
| v14 CRAFT & TASTE | 2026-08-07 | the material matured (§6.1 — hairline edge + contact shadow, glow dead); detail pages rebuilt editorial (eyebrow → hero metric 44pt → chart on its own stage → read → ledger → stance → provenance; blocks arrive in sequence); the insight carousel went CHROMELESS (72pt numerals on paper; the section header died — one label, not two); grid charts arrive in reading order (0.12s stagger), never as a chorus; haptic amendments (§8); strip 52pt + the loosest joints tightened |
| v18 THE VISUAL LANGUAGE | 2026-08-07 | shape before words (§1.2b): `JeniSparkRow` gives every target-less metric its own seven days (a bar would invent a denominator; a week cannot lie); tasks became objects with SF Symbols, hairline containers and a settling completion; offered rows keep the spine with a dashed seat; tools lead with their symbol; the QA seed grew a real week so shape can be judged |
| v17 DASHBOARD ARCHITECTURE | 2026-08-07 | the dashboard budget (§7.2): the greeting became a header (171pt band → 110); the FOOD section header died (a band that names itself needs none); TODAY became ONE checklist — the lead is the first row, not a card in another register (~48pt rows vs a 120pt card); tools three across. Home's whole anatomy now sits above the fold |
| v16 THE CONTROL CENTER | 2026-08-07 | information density: the dashboard scale (§7.1) — Home's nutrition band 330pt → 190pt AND one number richer (44pt lead figure, context inline, one window measure, six nutrients on a uniform 3-col grid); task rows back to DM Sans 16 per the §2 role law (a task title is the system labelling work — v15's serif rows were the prettier violation); Becoming's tiles → THREE columns with short face values; the whole of Home's anatomy now sits above the fold |
| v15 THE TASTE PASS | 2026-08-07 | **elevation means actionability** (§6.1) — Home's nutrition left its card and became the page's true hero, leaving ONE card in the top half; rhythm composed via `topAir` (§7.2); the task list rebuilt in one voice (serif 20pt, size not family carries hierarchy; check optically baseline-aligned; offered rows keep the spine); the tile→page morph carries its HEAD at matched scale (§4.4) and lands full-bleed sheet-like; macro columns forced equal, labels tracked-caps, values 15pt |
| **v21 THE INSTRUMENT** | 2026-08-07 | **the redesign (docs/app_v21 is the era's law).** §1.1b two instruments; §3 THE ROSE RAMP (colour becomes the data language); Home: one-line header (greeting · day chip · gear), the nutrition band becomes a five-face morphing HERO CAROUSEL (ring at demo scale with the counted numeral inside · protein vs floor · the plate's split · chemistry weeks · the week's bars; a tick per detent; faces self-name — the outer band label died), the checklist becomes `JeniTaskRow` objects (real plate photo on the food row; clinical rows ink), tools go two-across `JeniToolTile` with live instruments, the evening close is a LIST ROW; Becoming: one-line masthead, the body card leads with the weight NUMERAL over a 56pt trajectory, the scope bar is its own header, tile values at 20pt serif, detail reveal staged in five breaths; kept-day rings berry; film-caught: sparse-dash sparks fixed by mark-cap 9 + bound widths, insight figures recede to blush |
| **p66 ONE PRODUCT, ONE SYSTEM** | 2026-09-02 | THE CELEBRATION: `JeniBurst.shower` (full-page paper volley; Lottie bake-off filmed and lost, plumbing deleted). THE SPEECH GRAMMAR v2: per-thought `tick` + `actionPause` before the action act, mirrored + pinned in `FoodActs`. MOVE rebuilt on the action anatomy (one standing CTA in the thumb zone). One primary object: method note + letter joined `JFContinueButton` (which gained `padded:` and Dynamic Type). Bottom chrome: the ramp finally covers the floating bar's gaps. Interruption policy §5.9 + the dateline read-by-hand stamp. Dead kit deleted (~900L: JKMasthead, JKBeatRow's view, JKPlateStrip, v2 JKGallery, JKChainLine, JKCoachMark, JKCoachLine, JKStepsRing, JeniPage, JeniCard, LuxuryPressFeedback, TrainerButtonStyle, 7 Typo + 6 Motion + 2 Palette + 3 Space dead tokens, BreathingShadow) |

### DO NOT MIGRATE — the paywall (founder directive, 2026-08-06)

**Leave `PlankApp/Views/Paywall/` alone.** It carries 59 raw
`.system` calls and they stay. This was attempted and reverted, with
measurements:

- Raw `.system(size:)` is FIXED — it ignores Dynamic Type. The wall's
  docked CTA and its side-by-side price rows are built around that.
- Migrating with `relativeTo:` made those 10-13pt labels scale at
  accessibility sizes and **cut the prices off entirely** at XXL
  (verified against a stashed baseline: the baseline clips mildly at
  the right edge; the migrated version loses "$47.99" and both tier
  prices).
- A family-only migration (no `relativeTo:`) still failed 2 of 3
  KeepWall legs.
- Founder directive after seeing the frames: *"xxl texts are too
  big.. dont change the paywall."*

The wall is the commercial surface and its legs are the regression
gate. If Dynamic Type support is ever wanted there, it is a
LAYOUT project — flexible price rows, a growing dock, and a fresh
XXL baseline — not a font sweep. Until then this surface is exempt
from §2 and §10.2, deliberately and on the record.

### Still to migrate (priority order)
2. **Chat** — the two-voice letter register mostly holds; audit
   spacing and the composer against §7.
3. **Food rail** (`Packages/PlankFood`) — the snap result carousel.
4. **Body scan** — S1 shipped in the v11 language; needs a §4 motion
   pass.
5. **Medication / supplements / history / clinician** — smaller
   surfaces, same treatment.
6. **B2B Home variant** — clinic patients should see medication,
   check-ins, care plan and clinician instructions first. Same
   language, different priority order. Not started.
7. **Copy sweep** — the register is set in onboarding; in-app strings
   still carry older poetic phrasing in places.

### The mechanical part is scriptable

Migrating a surface's typography is a regex pass, not a redesign:
`.font(.system(size: N, weight: .w))` → `.font(.custom("DMSans-<Face>",
size: N, relativeTo: <style>))`, skipping `design: .monospaced`. Faces
that ship: Light / Regular / Medium / SemiBold (there is no Bold —
`.bold` folds to SemiBold). This also FIXES Dynamic Type, because raw
`.system(size:)` does not scale.
