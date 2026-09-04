# R4 — Design benchmark: the current state of excellent iOS interaction design (2025–2026)

Research date: 2026-09-04. Web-sourced; every claim carries its URL. Written for pass 79
against the pass-76/78 baseline (JeniMotion, JeniHaptic, JeniActs, JeniScene, JeniBurst,
the arrival grammar, the RM-whole law).

---

## 1. Apple Design Awards 2025–2026: what wins for interaction and delight

Categories are Delight and Fun · Innovation · Interaction · Inclusivity · Social Impact ·
Visuals and Graphics; one app + one game each.
- 2025 list: https://developer.apple.com/design/awards/2025/ ·
  https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/
- 2026 list: https://developer.apple.com/design/awards/ ·
  https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/

### The apps closest to Jeni's category, and what Apple rewarded

**The Outsiders: Athlete Tracker (Gentler Stories, 2026 Interaction finalist)** — the team
behind Gentler Streak. Rewarded for a *Training Readiness Score* as "beautiful data
visualization" placing training load beside sleep quality and resting heart rate — i.e. a
composed instrument that answers one question, not a dashboard. Gentler Streak's own
catalogued micro-interactions (60fps.design: https://60fps.design/apps/gentler-streak) are
exactly Jeni-shaped: activity-recap intro/outro sequences, a heart-beat pulse during
summaries, progressive "steps fill" with a pulse at the crossing, sliders whose button
color answers the drag, graph draw-ins. The pattern: **each metric gets one drawn moment;
recaps are staged sequences (acts), not dumps.**

**Tide Guide (2026 winner, Visuals and Graphics; also Interaction finalist)** — a data-dense
utility that won on: Liquid Glass integrated with "extra polish to data presentation,"
"custom animations tied to the aquatic theme," and a "palette designed to match the color
of the sky throughout the day." Lesson: **thematic, domain-derived motion** (water moves
like water) beats generic motion; the environment's state renders in the chrome.

**Moonlitt: Moon Phase Tracker (2026 winner, Interaction)** — SwiftUI-built, cited for
"best-in-class Liquid Glass integration" and easy onboarding. In 2026 Apple's Interaction
award explicitly rewards *native-material fluency*, not novelty.

**(Not Boring) Camera (2026 Visuals finalist)** — "giant buttons and haptic scroll wheels
make it fun to dial in focal points." The haptic-detented wheel (tick per stop, like a
physical camera dial) is the single most-cited haptic pattern in the 2026 cohort.

**grug (2026 winner, Delight and Fun)** — a daily-wisdom app that won on *subtraction*:
hand-drawn design down to a scribbled status bar, "no login, no cloud syncing, nothing
extraneous." A one-idea-per-day app with a total identity won Delight. Jeni's paper+ink
identity is the same bet.

**CapWords (2025 winner, Delight and Fun)** — "with the snap of a camera and a fun
animation," objects become interactive stickers; "each flash card transition is
accompanied by a real-world sound." Lesson: **the commit moment carries the delight**, and
cross-modal pairing (motion + sound/haptic on the same beat) is what reads as craft.

**Denim (2025 Delight finalist)** — "smooth scroll transitions and elegant text and mesh
gradients… a joy to play with, thanks to custom haptics, intelligent cropping, and cool
depth effects." Custom haptics named as a *reason for the award*.

**Mela (2025 Interaction finalist)** — recipe steps "subtly dimmed and highlighted at the
proper time"; timers in the Dynamic Island. Attention choreography (dim what's done,
light what's next) is award-grade interaction, no motion required.

**iA Writer (2025 Interaction finalist)** — swipe right = library, swipe left = preview.
Spatially consistent gestures as the whole interaction story.

**Opal (2025 Social Impact finalist)** — "fun touches like haptics when unlocking 'gems'";
even in a restraint-positioned wellness app, Apple calls out *earned-moment* haptics.

**Vocabulary (2025 Visuals finalist)** — "charming, consistent illustrations that create a
clean visual style and rhythm… use of haptics is a nice touch." Consistency of
illustration + rationed haptics.

**PowerWash Simulator (2026 Delight finalist, game)** — "specific haptic feedback for each
hose nozzle": per-tool haptic identity, the game-side version of a semantic haptic
vocabulary.

### Synthesis
Across both years the Interaction/Delight rubric is: (1) one clear idea; (2) motion and
haptics attached to *moments of meaning* (commit, crossing, reveal) not decoration;
(3) domain-derived motion themes; (4) system fluency (Liquid Glass, SwiftUI, Dynamic Type,
VoiceOver) treated as table stakes; (5) restraint as a positive trait ("properly minimal
UI," "nothing extraneous"). No winner is rewarded for animation quantity.

---

## 2. Motion grammar and iOS 26 conventions

### Liquid Glass: where it stands, where glass belongs
- Apple's own guidance ("Adopting Liquid Glass",
  https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass and
  "Meet Liquid Glass," https://developer.apple.com/videos/play/wwdc2025/219/): **glass is
  the navigation/controls layer floating above content; never put glass in the content
  layer, never glass-on-glass.** Content stays opaque and primary; controls recede.
- Adoption reality (early–mid 2026): iOS 26 user adoption is historically low —
  ~45% per https://www.geeky-gadgets.com/apple-liquid-glass-adoption-rate/ (Gruber
  disputes "bizarrely low" framing: https://daringfireball.net/2026/01/ios_26_adoption_rate_is_not_bizarrely_low),
  and third-party developer adoption is uneven
  (https://apple.gadgethacks.com/news/apple-liquid-glass-developer-gallery-explained-adoption-gaps-and-wins/).
  NN/g documents measurable usability regressions in stock iOS 26 (crowded tab bars,
  translucent controls over noisy backgrounds) — cited in
  https://www.techradar.com/phones/ios/ios-26-adoption-on-iphones-is-staggeringly-low-here-are-3-reasons-why.
- But the winners' circle shows the *converse*: Moonlitt and Tide Guide won partly on glass
  fluency, and Apple has signaled the compatibility opt-out disappears in the next major
  release (https://medium.com/@expertappdevs/liquid-glass-2026-apples-new-design-language-6a709e49ca8b).
- **Reading for a paper+ink app**: Jeni's standing refusal of glass *as a theme* remains
  market-valid for content surfaces; the pressure point is only system chrome (tab bar,
  toolbars, sheets), where fighting the system material (p66's reverted paper tab bar) costs
  more than accepting it. Apple's own law — glass = navigation layer only — is compatible
  with paper-everywhere content.

### Hero/continuity transitions
- **iOS 18+ `navigationTransition(.zoom)` + `matchedTransitionSource`** is now the
  system-blessed hero transition (Photos-style): three lines, works across
  NavigationStack pushes *and* sheet/cover presentations where `matchedGeometryEffect`
  never could, and — critically — it is **gesture-interruptible and dismissible by drag
  for free** (the system owns the interaction).
  - https://peterfriese.dev/blog/2024/hero-animation
  - https://www.createwithswift.com/using-the-zoom-navigation-transition-in-swiftui/
  - https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-zoom-animations-between-views
- **`matchedGeometryEffect`** remains the tool for **in-tree morphs** (a tile becoming a
  detail *within one screen's hierarchy*, segmented-control thumbs, the chip→page morph)
  where no presentation boundary is crossed. Known trade-offs: it cannot cross
  NavigationStack pushes; misuse causes text scaling artifacts; you own interruption
  yourself. https://yenovi.com/blog/matched-transitions-in-swiftui
- Convention in top apps: **card → detail keeps the card's geometry alive** (the photo/
  chart is the shared element; text crossfades around it). Neva and SILT were both praised
  for *camera* continuity (zoom in through tight spaces, zoom out for scale) — continuity
  of a single lens rather than cuts (https://developer.apple.com/design/awards/).

### Sheet vs full-screen conventions
- Community + Apple convention is stable: **sheet = non-blocking subtask** (forms, share,
  a quick edit; swipe-to-dismiss preserved), **fullScreenCover = mode change / required
  act** (onboarding, paywall, a ceremony, media).
  - https://appmakers.dev/swiftui-modal-navigation-sheet-fullscreencover-popover/
  - https://sarunw.com/posts/swiftui-bottom-sheet/
- Detents: `.medium` ≈ half screen, `.large` = full; a sheet should **open at the height
  its job needs** (Jeni's §6.1 law independently matches the platform's direction);
  `presentationDetents` + visible grabber is the expected affordance
  (https://nilcoalescing.com/blog/ResizableSheetInSwiftUI/, WWDC21 "Customize and resize
  sheets": https://developer.apple.com/videos/play/wwdc2021/10063/).

---

## 3. Haptic design best practices

### Apple HIG ("Playing haptics", https://developer.apple.com/design/human-interface-guidelines/playing-haptics) + WWDC21 "Practice audio haptic design" (https://developer.apple.com/videos/play/wwdc2021/10278/)
Three named principles:
1. **Causality** — it must be obvious *what caused* the haptic; feedback with no visible
   cause reads as a bug or spam.
2. **Harmony** — haptic, visual, and audio must agree in size/weight/timing: a small light
   element gets a sharp light tap, a big heavy commit gets a deep transient. Play the
   haptic **on the same frame as the visual state change**, never before/after.
3. **Utility / restraint** — use haptics to give *new* information; overuse desensitizes
   and drives users to disable them system-wide.

### Semantic vocabulary (the consensus across HIG + practitioners)
- `.selection` — scrubbing/ticking through options (pickers, rulers, wheels). Light, dry,
  repeatable.
- `.impact(light/medium/heavy | soft/rigid)` — a physical collision: a card docking, a
  drag crossing a boundary, an element snapping into place.
- `.success / .warning / .error` (notification family) — a *judged outcome*, used once at
  the end of a flow, not per-tap.
- Custom CoreHaptics — reserved for **signature moments** ("sonic-branding for touch"):
  a composed phrase with intensity/sharpness envelopes.
  - https://medium.com/@mi9nxi/haptic-feedback-in-ios-a-comprehensive-guide-6c491a5f22cb
  - https://blog.eidinger.info/haptics-on-apple-platforms

### Premium vs gimmicky (practitioner consensus)
- "Good haptics are felt, not noticed; bad ones are the first thing a user turns off."
  Restraint + consistent meaning + system-convention adherence is what reads premium
  (https://vp0.com/blogs/haptic-feedback-ui-design-guidelines-ios,
  https://medium.com/@chandra.welim/haptic-feedback-the-secret-to-apps-that-feel-premium-7463fdc1ccca).
- Users rate identical hardware as *more premium* with well-timed haptics; badly timed or
  repetitive buzzing reverses the effect (https://swmansion.com/blog/haptic-feedback-explained-what-it-is-and-what-it-does-for-your-app-and-business/).
- **Whitespace**: deliberate haptic silence between events makes the played ones land —
  the same rationing law Jeni applies to celebration.
- What the 2025–26 award apps do: haptic *detents* on continuous controls ((Not Boring)
  Camera's scroll wheels), haptics at *earned* unlocks (Opal's gems), per-object haptic
  identity (PowerWash nozzles) — always mapped to a physical metaphor.

### API layering (2025–26 state)
- **SwiftUI `.sensoryFeedback(_:trigger:)`** (iOS 17+) is now the default for view-local
  semantic feedback — declarative, fires on value change, covers
  `.selection/.impact/.success/.warning/.error/.increase/.decrease/.alignment`
  (https://bleepingswift.com/blog/sensory-feedback-haptics-swiftui).
- **UIFeedbackGenerator** survives for imperative call-sites and `prepare()` latency
  control (pre-warm before a known moment).
- **CoreHaptics (`CHHapticEngine`)** for composed phrases (transient + continuous events,
  parameter curves), synced to animation keyframes by scheduling relative times
  (https://medium.com/@dhavaljasoliya8/unlock-the-power-of-core-haptics-in-swiftui-a91d7c40efbb).
- The premium pattern: **one app-level haptic engine with a named semantic API**
  (selection/commit/success/celebration) so meaning stays one-to-one across the product —
  exactly Jeni's `JeniHaptic` (record/crest/spark) architecture; the market has converged
  on what p58–p64 already built.

---

## 4. SwiftUI motion implementation: state of the art

### Springs — the one animation model
- WWDC23 "Animate with springs" (https://developer.apple.com/videos/play/wwdc2023/10158/):
  springs are parameterized by **(duration, bounce)** where duration is *perceptual* (how
  long it feels) not settling time; bounce 0 = critically damped. Presets:
  `.smooth` (bounce 0), `.snappy` (~0.15), `.bouncy` (~0.3), all overridable:
  `.snappy(duration: 0.25)`, `.spring(duration: 0.5, bounce: 0.2)`.
- Practitioner values that "feel native" in 2025–26
  (https://medium.com/@amosgyamfi/swiftui-spring-animation-cheat-sheet-for-developers-1411fd80eda4,
  https://nilcoalescing.com/blog/AnimationTimingInSwiftUI/,
  https://dev.to/__be2942592/swiftui-animation-guide-from-basic-to-advanced-in-2026-131b):
  - Micro-interactions (press, toggle, chip select): `.snappy(duration: 0.2–0.3)`.
  - Surface/state transitions: `.smooth(duration: 0.3–0.4)` — no overshoot on anything
    carrying text or numbers.
  - Playful/celebratory only: `.bouncy(duration: 0.4–0.6)`; bounce > 0.3 reads cartoon.
  - Interactive/gesture-driven: short-response springs (SwiftUI's `.interactiveSpring` ≈
    response 0.15, damping 0.86) so the element tracks the finger.
  - The default `.spring()` (response 0.55 / damping 0.75) is the platform's own "medium"
    reference — motion slower than this must justify itself.
- **Everything is a spring now.** Duration+ease curves survive only for crossfades and
  color; movement uses springs because springs are *interruptible and velocity-preserving*
  by construction (WWDC18 "Designing Fluid Interfaces",
  https://developer.apple.com/videos/play/wwdc2018/803/).

### The tool ladder (use the lowest rung that works)
1. `withAnimation` / `.animation(_:value:)` with a spring — 90% of cases.
2. **`.contentTransition(.numericText(value:))`** — the standard for changing numbers
   (dials, counters, prices): per-digit rolling, direction-aware via `value:` (or
   `countsDown:`), wrap the mutation in `withAnimation`, use monospaced digits so columns
   hold (https://www.createwithswift.com/animating-numeric-text-in-swiftui-with-the-content-transition-modifier/,
   https://sarunw.com/posts/animating-number-changes-in-swiftui/,
   https://swiftcrafted.dev/article/swiftui-contenttransition-ios-26-text-numeric-symbol).
   Companion: `.contentTransition(.symbolEffect(.replace))` for SF Symbol state swaps.
3. **`.scrollTransition`** (iOS 17+) — per-item effects keyed to scroll position
   (fade/scale/parallax at the container edges); `.interactive` phase blending is the
   default and the right one (https://www.appcoda.com/swiftui-scroll-view-transition/,
   https://swiftcrafted.dev/article/swiftui-scrollview-ios-26-scrollposition-scrolltransition-scrolltargetbehavior).
   Top apps use it *subtly*: opacity 0.85→1 + scale 0.97→1 at edges, never carousel-flip.
4. **`PhaseAnimator`** — discrete looping/one-shot phase sequences where all properties
   move together (attention pulses, celebration beats)
   (https://swiftui-lab.com/swiftui-animations-part7/).
5. **`KeyframeAnimator`** — independent per-property timeline tracks ("mini After
   Effects"): choreographed one-shots like a shake-with-settle, a multi-part reveal
   (https://bleepingswift.com/blog/swiftui-animations-guide,
   https://medium.com/appcoda-tutorials/using-keyframeanimator-in-swiftui-to-create-advanced-animations-e33e240a435e).
6. **Transaction control** — `transaction { $0.animation = nil }` /
   `.transaction(value:)` to fence which subtrees animate; the professional tell is that
   *unrelated content never wiggles* when one value changes.
7. Canvas/TimelineView with closed-form physics for particle work (Jeni's JeniBurst is
   already this pattern; deterministic, zero-idle).

### Hero transitions in practice
- Cross-presentation hero: `navigationTransition(.zoom(sourceID:in:))` +
  `.matchedTransitionSource(id:in:)` (iOS 18+). Known sharp edge: large-title/toolbar
  animation glitches on some stacks (https://developer.apple.com/forums/thread/774573) —
  film it per-surface.
- In-tree morph: `matchedGeometryEffect` with a single `@Namespace`, properties animated
  by one spring; keep text out of the matched pair (match the *container*, crossfade the
  text) to avoid glyph stretching.

---

## 5. "Feels like a prototype" vs "feels finished"

The canonical texts: WWDC18 **Designing Fluid Interfaces**
(https://developer.apple.com/videos/play/wwdc2018/803/; Nathan Gitter's implementation
notes: https://medium.com/@nathangitter/building-fluid-interfaces-ios-swift-9732bb934bf5),
Emil Kowalski's **Great Animations** (https://emilkowal.ski/ui/great-animations) and
animations.dev, Rauno Freiberg's **Invisible Details of Interaction Design**
(https://rauno.me/craft/interaction-design).

What separates finished from prototype, distilled:
1. **Instant response, then motion.** Something changes on the same frame as the touch
   (highlight, scale-down) even if the real work takes time. Latency at the *start* is the
   prototype tell.
2. **Interruptibility everywhere.** Every animation can be grabbed, redirected, reversed
   mid-flight; a fluid interface is "an extension of your mind." Springs give this for
   free; fixed-duration curves and un-cancellable choreography are the prototype tell.
   (Jeni's tap-to-land on JeniActs is this law applied to speech.)
3. **Velocity matching.** A gesture-released element continues at the finger's velocity
   into its spring (project momentum, pick the nearest rest point); a hard-cut from drag
   to canned animation is a discontinuity users feel instantly.
4. **One motion voice.** Same spring family, same durations for same-sized changes, same
   transition per navigation class, across every screen. "Buttons slightly different
   sizes, spacing that changes unpredictably" is the #1 amateur signature
   (https://dev.to/fan-song/indie-developers-guide-build-beautiful-mobile-apps-without-a-designer-1dfk).
5. **Origin-aware motion.** Things animate *from where they were caused* (menu from its
   button, detail from its card, burst from the tapped control) — spatial consistency is
   most of what "premium" means in Rauno's catalogue.
6. **Fast.** UI motion under ~300ms, ease-out/spring; 180ms feels more competent than
   400ms. Slow motion reads as the app being slow (Emil).
7. **Knowing when not to animate.** Frequent, repeated actions (the 30th plate log) get
   quieter treatment than the first; Raycast's near-zero animation is cited as taste.
   Restraint is a feature, not a gap.
8. **Nothing moves that didn't change.** Layout jitter in unrelated views during a state
   change (missing transaction fencing, unstable identities) is the most common SwiftUI
   prototype tell.

---

## 6. Reduce Motion: what the best apps substitute

- System behavior: with Reduce Motion (+ "Prefer Cross-Fade Transitions"), UIKit swaps
  slide/zoom for **dissolve/cross-fade** — the meaning ("content changed") survives, the
  displacement goes (https://support.apple.com/en-us/HT202655,
  https://ios.gadgethacks.com/how-to/set-cross-fade-animations-ios-13-for-smoother-lateral-transitions-menus-apps-0200100/).
- App-side best practice (https://tanaschita.com/ios-accessibility-reduced-motion/,
  https://medium.com/@amosgyamfi/reduce-motion-how-to-make-your-ios-app-animations-accessible-and-inclusive-92b9de1304fb):
  - Read `@Environment(\.accessibilityReduceMotion)`.
  - **Substitute, don't delete**: replace offset/scale/rotation transitions with
    `.opacity`; replace count-ups and draws with the final state arriving whole; keep
    color/opacity state changes (they carry meaning without motion).
  - Kill autonomous/ambient motion entirely (parallax, drift, loops, particles).
  - Never gate *information* on motion: anything a trace or count-up communicates must
    exist as a static end state. (PCalc's dissolve substitution is the cited exemplar.)
  - Haptics are NOT motion — keep them under RM; they often matter more there.
- This is exactly Jeni's standing "RM arrives whole — state, not motion; zero particles,
  meaning intact" law; the market's best practice and the house law already agree.

---

## What this means for Jeni

A concrete adoption checklist. Items marked ✓ are places the market confirms an existing
Jeni law (keep and extend); ● are gaps worth building; ○ are watch-items.

1. ● **Hero continuity for the record's photos** — adopt
   `navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource` for
   photo-led doors: BOOK day-spread photo → plate page, Home receipt chip → plate page,
   Becoming tile → detail (where those are covers today). It buys system-owned
   interruptible drag-to-dismiss for free, which no hand-rolled cover can match. Film the
   toolbar/large-title edge cases per surface (known glitch class). Keep
   `matchedGeometryEffect` only for in-tree morphs (lens chips, tile→sheet within one
   tree), and never match text — match containers, crossfade words.

2. ● **`.contentTransition(.numericText(value:))` on every standing numeral** — the dial's
   remainder, kcal left, weight numbers on lens change, era ledger deltas. Pair with
   `.monospacedDigit()` and wrap mutations in `withAnimation(.snappy(duration: 0.25))`.
   Direction matters: pass the value so decreasing protein-to-go rolls *down* — the
   number's motion should agree with the meaning of the change. Under RM: swap to plain
   replacement (numericText still implies motion).

3. ✓/● **Codify the spring tokens** in JeniMotion as the one vocabulary, with named seats:
   `press = .snappy(0.22)`, `surface = .smooth(0.35)`, `celebrate = .bouncy(0.5)`,
   `track = .interactiveSpring` (gesture-following only). Audit for any remaining
   `easeInOut` on *moving* elements (curves stay legal for crossfades/color only). Bounce
   > 0.3 only inside the celebration tier — this is the market's cartoon line.

4. ● **Velocity matching on hand-offs** — wherever a drag releases into an animation
   (weight ruler, scrub, sheet-adjacent drags, any future swipe-dismiss), seed the spring
   with the gesture's release velocity (`spring(response:dampingFraction:)` +
   initial velocity via `Transaction`/gesture predicted end). The WWDC18 law: never
   hard-cut from finger to canned motion. This is the single cheapest "finished" upgrade
   the walker can't measure but thumbs feel.

5. ✓ **Haptic causality + harmony audit** — the HIG's three laws (obvious cause, matched
   weight, same-frame timing) as a one-pass audit over JeniHaptic call sites: every haptic
   must co-fire with a visible change of matching size (record() with the receipt, crest
   with the draw). Anything firing without a visual twin gets one or loses the haptic.
   Keep the vocabulary closed: selection / record / crest / spark and nothing ad hoc.

6. ● **Haptic detents on continuous controls** — the (Not Boring) Camera pattern: the
   weight ruler and any scrubber should tick `.selection` per stop (via
   `.sensoryFeedback(.selection, trigger: rulerValue)`), with `UIFeedbackGenerator
   .prepare()` pre-warm on drag-start for zero-latency first tick. Whitespace law: no
   detent ticks within ~80ms of each other at flick speed — coalesce.

7. ✓ **Glass stays out of the content layer** — Apple's own Liquid Glass law (glass =
   floating navigation layer only) means paper-everywhere content is *compliant*, not
   contrarian. Accept system glass on the tab pill/toolbars (already the law after p66's
   revert); do not reintroduce custom chrome to fight it. Watch-item ○: the opt-out dies
   at iOS 27 — verify every surface under the system material before that archive.

8. ✓/● **Sheet grammar** — the market's convention (sheet = subtask with grabber +
   swipe-dismiss; cover = mode/ceremony) matches §6.1. The one addition: ensure every
   sheet's *appearance* animation is interruptible (no scheduled work that breaks if the
   user drags it down during arrival — the fluid-interfaces rule applied to Jeni's settle
   beats).

9. ✓ **Attention choreography over motion** — Mela's "dim what's done, light what's next"
   won Interaction with zero fireworks; Jeni's acts/receipt grammar is the same family.
   Extend it: on multi-row surfaces after a commit, prefer an ink/opacity re-weighting of
   rows (0.45 done / 1.0 next) over any additional motion.

10. ● **`.scrollTransition` at the edges of long lists** — a whisper: opacity 0.9→1.0
    and scale 0.98→1.0 with `.interactive` on THE BOOK's spreads and Becoming rows.
    Below the threshold of "animation," above the threshold of "alive." Gate on RM
    (substitute nothing — edge fades read fine static).

11. ✓ **Reduce Motion = the substitution law, not the deletion law** — crossfade for every
    displacement, final-state for every draw/count, ambient motion to zero, haptics kept.
    The house RM-whole law is already the market's best practice; keep pinning it per new
    surface (AX5 + RM films together).

12. ✓/● **Rate the moment, ration the delight** — every ADA delight citation ties the
    effect to an *earned, infrequent* moment (unlock, first success, crossing). Jeni's
    tier law (spark/crest/moment, once-latches) matches; the extension worth taking is
    **cross-modal pairing on the biggest tier only**: CapWords pairs motion + real-world
    sound; Jeni's equivalent is motion + composed CoreHaptics phrase (crest) — never add
    sound, but ensure the crest haptic's envelope matches the drawn check's timing
    keyframe-for-keyframe (schedule CHHaptic events at the animation's keyframe offsets).

13. ● **Interruptibility sweep as a test class** — the prototype/finished line item most
    verifiable on film: mid-flight taps during every arrival (acts, covers, celebration,
    lens morphs) must land or fast-forward, never queue or dead-zone. Jeni has this law on
    speech surfaces (tap-to-land); extend the walker to assert it on *every* choreographed
    surface (tap at +100ms of each arrival; assert the target responds).

### The one-paragraph verdict
The 2025–26 market has converged on Jeni's existing philosophy — restraint, earned
moments, semantic haptics, RM-honesty, system fluency — so the remaining distance is not
philosophical but mechanical: system zoom transitions for photo continuity, numericText on
the numerals, velocity-seeded springs at gesture hand-offs, haptic detents on the ruler,
and an interruptibility guarantee on every choreographed arrival. Those five are the gap
between "designed" and "finished" as the awards jury currently scores it.
