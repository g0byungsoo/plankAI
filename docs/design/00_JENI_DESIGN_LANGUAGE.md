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
field, dark ink, one accent. It should read like a well-set book, not
a dashboard. If a screen could be printed and still make sense, the
hierarchy is right.

**1.2 — Type carries hierarchy.** Not boxes, not colour, not
dividers. Size, weight, and air do the work. A screen with five card
borders is a screen that has given up on typography.

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

**1.8 — Calm over clever.** No confetti on a Tuesday. Celebration is
rationed so it still means something (§4.7).

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

Eight tokens. There is no ninth.

| token | value | meaning |
|---|---|---|
| `Palette.bgPrimary` | `#FDFDFC` | paper — **the only page background** |
| `Palette.bgElevated` | `#FFFFFF` | a surface lifted off the paper |
| `Palette.bgInverse` | `#2A1F1E` | ink — declaration surfaces, selected states |
| `Palette.textPrimary` | `#18100F` | ink type |
| `Palette.textSecondary` | `#5A4340` | supporting type |
| `Palette.textInverse` | `#FCFAF7` | type on ink |
| `Palette.accent` | `#C4677A` | rose — ONE accent, used sparingly |
| `Palette.accentSubtle` | `#F5D5D8` | rose at rest (bands, fills) |

Plus the cocoa opacity scale for hairlines and tertiary type:
`cocoaSecondary` (74%), `cocoaTertiary` (62%), `hairlineCocoa` (10%).

**The one-colour law.** Rose is an accent, not a palette. A screen
with three tints is broken. State is expressed with ink weight and
air, not with a colour system. **No semantic red for "over budget"**
— see §11.4.

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

1. **In-tree morph** — a tile becomes its detail page. Nothing is
   destroyed; it grows. **Do not use matched geometry inside a
   `LazyVGrid`** (proven twice): interpolate an explicit rect from
   the tapped tile's reported frame, and carry the page's HEAD by
   laying it out at its FINAL width and applying the surface's own
   growth ratio as a `scaleEffect(anchor: .topLeading)`. At the start
   of the flight the hero renders at the tile's own value size, in
   the tile's position — the tile's words become the page's headline,
   with zero reflow. Content below the head waits for the landing (a
   `Canvas` drawn into a resizing rect flickers).
2. **In-place crossfade** — the surface changes colour/content under
   stable chrome (`V8Tempo.surfaceFlip`). Used for paper ↔ ink.
3. **Staged arrival** — new content builds in on `jeniArrive`.
4. **Full-screen moment** — `JeniMoment` for declarations (§6.4).
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

### 4.7 Celebration is rationed

At most ONE celebratory burst per flow, at a genuine peak. The set
lives in `EffectAnimation` (Lottie, bundled at
`PlankApp/Resources/animations/`) and is played through
`LottieEffectView`, which returns `Color.clear` under Reduce Motion.

| moment | effect |
|---|---|
| the plan seal (end of onboarding) | `.confettiSoft` |
| the first promise sealed | `.fireworks` |
| a quiet personal win | `.smokePuff` |

Preload before the beat: `EffectAnimation.fireworks.preload()`.

---

## 5. Interaction philosophy

**5.1 — Every tap is acknowledged within 100ms.** Press states are
physical: `JeniPressable` (scale 0.98 + slight dim) for cards,
`JeniRowPressStyle` (dim only) for rows. Never a highlight rectangle.

**5.2 — One primary action per screen.** At most one ink pill
visible. Secondary actions are quiet text links, never a second pill.

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

---

## 6. Component system

**The rule: compose from these. If you need something new, add it
HERE, do not invent it locally.**

### 6.1 Surfaces
| component | use |
|---|---|
| `JeniPage` | the paper shell — gutters, top air, owns the arrival flag |
| `JeniSurface` | **v14 material — contrast, not glow**: white fill, a DRAWN 0.5pt hairline edge (7% ink), ONE contact shadow (3%, r6, y2). The neumorphic top-highlight and diffuse glow died — edges separate, halos blur. This pair IS the elevation (deliberate §12.4 amendment) |
| `JeniCard` | thin alias over `JeniSurface` at 20pt |
| `jeniSheet` | bottom sheet — paper, 28pt radius, grabber, exactly one primary action |

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
| **`JeniMoment`** | **a full-screen declaration that types itself** — the house grammar for any moment that deserves the whole screen; v12: optional hero-numeral register (one massive counted fact under the eyebrow) |
| `JeniTypedLines` | the typewriter, standalone |
| `JeniChart` | the ONE chart engine (Canvas). SwiftUI Charts is banned. v12 marks: monotone-cubic smooth lines 2.2pt, 10% wash, bars ≤24pt rounded-top/square-base on a grounding hairline, `emphasizeLast` for faces, 8pt surface-ringed end dot; re-traces when its data changes |
| `JeniCountingNumeral` | any number that matters; morphs to a changed value, arms on first visibility |

### 6.4b The glance layer (v12 — docs/app_v12/00_CRAFT.md)
| component | use |
|---|---|
| `JeniRing` | the drawn arc gauge (kcal fraction); traces on arrival, morphs on change; never a colour code |
| `JeniMetricBar` | label · value · 3pt landing bar; NO fill without a collected denominator |
| `JeniWeekDots` | the week dot row — filled days draw their check; empty days are quiet rings, never marks |
| `JeniScopeBar` | the time-scope selector (today…all); the ink capsule morphs between words; content re-keys, never reloads |
| `JeniInsightPager` / `JeniInsightCard` | the editorial insight carousel: eyebrow → hero numeral → one drawn figure → one serif sentence; every card floor-gated |

**The visibility gate.** Glance pieces, `JeniChart` and
`JeniCountingNumeral` arm on `arrived AND first-visible` — a
below-fold chart draws when she reaches it, never invisibly at load.
| `V8Figure` / `V8FigureView` | drawn evidence (curves, bars, dot rows) |
| `V8Glyph` / `V8GlyphView` | drawn pictograms for image-led choices |
| `JeniMark` | the official j mark — one colour, never redrawn |

### 6.5 When to use `JeniMoment`

Use it for anything the product *declares*: the evening close, a
milestone, a weekly read, a scan result summary, a care-team message
worth stopping for. **Do not** wedge a declaration into a scrolling
surface as a giant headline — that is what Home used to do and it is
explicitly dead (§12.9).

```swift
JeniMoment(
    eyebrow: "closing the day",
    lines: [V8Line("that's the day, casey.", italic: ["casey."]),
            V8Line("tomorrow: a movement day.", italic: ["a movement day."])],
    cta: "goodnight",
    onDismiss: { ... }
) {
    // whatever the moment needs from the user, arriving after the lines
}
```

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

### 7.3 Screen anatomy — HOME (binding)

Home always reads, at every hour of the day:

```
greeting                     — human line, name in lighter ink
calendar strip               — week paging, disc morphs, content re-keys
dateline                     — where you are in the program
FOOD                         — calories + macros, the day's window
TODAY / STILL TODAY          — the list of things to do, check circles
TOOLS                        — the grid of everything you can do now
[evening] close the day      — invitation into JeniMoment
```

Nutrition, the list, and the tools are **never** removed, replaced or
swapped out by a state. States change their CONTENT, not Home's
anatomy.

---

## 8. Haptic philosophy

Following Apple's HIG: haptics **confirm what already happened
visually**. They are never the main event and never fire for
something the user did not cause.

### 8.1 The grammar — three words

`JeniHaptic` in `JeniMotion.swift`:

| word | feel | when |
|---|---|---|
| `tick()` | light | selection, detent, a staggered item landing, a word arriving |
| `land()` | soft | a completed action, an acknowledgment, a sentence ending |
| `swell()` | medium | ONE hero moment per flow — the seal |

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
| plate logged / scan complete | `land` |
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
   XXXL; long content scrolls.
3. **Reduce Motion**: typing becomes whole lines, bursts become
   nothing, ambience holds still, transitions become 200ms fades.
   Never remove information — only motion.
4. **Contrast**: 4.5:1 for body, 3:1 for large type. The state colours
   in `Tokens.swift` are already corrected — use them, don't invent.
5. **Tap targets ≥ 44pt**, including drawn marks (wrap a 26pt glyph
   in a 44pt frame).
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
7. **Never a raw font size or a magic spacing number.** Token or
   nothing.
8. **Never an alert for something the interface can say.**
9. **Never a takeover headline inside a scrolling surface.**
   Declarations get `JeniMoment`.
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
| v15 THE TASTE PASS | 2026-08-07 | **elevation means actionability** (§6.1) — Home's nutrition left its card and became the page's true hero, leaving ONE card in the top half; rhythm composed via `topAir` (§7.2); the task list rebuilt in one voice (serif 20pt, size not family carries hierarchy; check optically baseline-aligned; offered rows keep the spine); the tile→page morph carries its HEAD at matched scale (§4.4) and lands full-bleed sheet-like; macro columns forced equal, labels tracked-caps, values 15pt |

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
