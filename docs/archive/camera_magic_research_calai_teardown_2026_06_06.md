# Cal AI Camera Teardown — and the JeniFit Magical Translation

**Author**: research agent (camera-magic track)
**Date**: 2026-06-06
**Sources**: see inline + endnote
**Related**: `docs/camera_magic_research_calorie_ai_2026_06_06.md`, `docs/food_rail_plan.md`, `docs/food_rail_sprint_v1_0_7.md`, `[[project-food-rail-v3-locked]]`

---

## Executive teardown (1 paragraph)

Cal AI's camera is a *labor-illusion* product, not a vision product. The actual photo→nutrition call resolves in 2–3s (TechCrunch, fuelnutrition.app review), but the perceived value comes from a deliberately *staged* sequence: a clean viewfinder with a single white shutter, mode tabs ("Scan Food / Barcode / Food Label") at the bottom, a multi-step analyzing animation that surfaces volume + ingredient + portion reasoning ("operational transparency," per Buell & Norton 2011), and a result card that lists every detected ingredient as an editable row — so even when the model is wrong, the *labor* feels real. This works for Cal AI's TikTok-trained dieter audience because it mirrors the MyFitnessPal mental model (line-item ingredients = trustworthy) while feeling AI-modern. It is **wrong for JeniFit** in three specific ways: (1) the register is clinical-AR (bounding boxes, scanlines, gym-coded sans labels) and our cohort is post-Ozempic anti-femvertising; (2) the 8-ish processing steps are a brain tax that reads as "the app is judging you" once you're already in food-noise; (3) Cal AI was pulled by Apple in April 2026 for deceptive billing UI built on top of this perceived-precision frame — the whole "look how hard we worked" energy is what makes the eventual paywall feel transactional. JeniFit's leapfrog move is to **keep the labor illusion's *perceived precision* but swap its register from clinical to coquette**: italic-Fraunces punch words bloom from where Cal AI puts bounding boxes; the 8 steps collapse to 3 warm verbs (already shipped); the "fix results" button becomes a permission-framed "*tell me more*" sticker; the result card leads with a feeling-word (`*satisfying*` ♥) before any number. Cal AI optimized for the screenshot. We optimize for the way she feels reaching for her phone the second time.

---

## 1. Pre-snap camera experience

### Cal AI

Sources triangulate to this:

- A full-bleed live viewfinder with **no real-time bounding box overlay** on food. Cal AI does NOT do live "we see pasta" labels before the user taps — this is the most common misconception. The detection runs server-side after capture, not on-device pre-capture. (fuelnutrition.app review confirms the 2–3s post-tap window; SnapCalorie, not Cal AI, is the one with depth-sensor live overlays on Pro iPhones — `apps.apple.com/us/app/snapcalorie-ai-calorie-counter/id1574239307`.)
- A **bottom segmented tab control** with three modes: `Scan Food | Barcode | Food Label`. Switching between them re-styles the viewfinder reticle (corner brackets for barcode, full frame for food). [screensdesign.com/showcase/cal-ai-calorie-tracker]
- A **single large white circular shutter** in the lower third, with secondary shortcut icons: gallery picker, flash toggle, manual text entry, recent meals. (Kaloria — a Cal AI clone — documents this layout faithfully at `kaloria.ai/help/camera-scanner/`, including the "tap the large white circular button at the bottom center" wording and the meal-type auto-pick by time of day.)
- A **framing hint** ("Make sure Cal AI can see every ingredient when using the scan feature to ensure you can track your calories with 90% accuracy") was added later as a static do/don't card on first run — Janno's X teardown (`x.com/heyzitlac/status/1923152549647089786`) notes Cal AI's *old* static hint card was replaced by a **3-step animated walkthrough** showing proper angle, lighting, full-plate framing.

ASCII:

```
Cal AI pre-snap
┌──────────────────────────┐
│  [×]               [⚡]  │  ← close, flash
│                          │
│                          │
│     (live viewfinder      │
│      no overlay, no box) │
│                          │
│                          │
│        ╭───╮              │
│        │ ⚪ │              │  ← single white shutter
│        ╰───╯              │
│   [Scan Food][BC][Label] │  ← segmented tabs
└──────────────────────────┘
```

### JeniFit translation

```
JeniFit pre-snap (proposed)
┌──────────────────────────┐
│  [×]                ♥    │  ← close, gentle terminal heart on flash
│                          │
│     ✿ (sticker drift,    │  ← coquette y2k sticker scatter
│        periphery only)   │     periphery, not on food
│     (live viewfinder)    │
│                          │
│   *show me* your plate ♥ │  ← italic-Fraunces punch word, lowercase
│                          │
│        ╭─────╮            │
│        │tap to│           │  ← cocoa pill, NOT a white circle
│        │ scan │           │     (matches our cocoa CTA system)
│        ╰─────╯            │
│   ──  food  •  barcode ── │  ← thin marks, no segmented chrome
└──────────────────────────┘
```

**The leapfrog**: Cal AI's tab strip is gym-coded ("Food / Barcode / Label"). JeniFit's is a thin two-mark dot row — barcode hidden behind "**•**" because our cohort doesn't scan packages, they eat plates. The shutter is a **cocoa pill labeled `tap to scan`**, not a generic camera circle. The pre-snap subhead is a single italic-Fraunces invitation (`*show me* your plate ♥`), which serves as both framing hint and brand signature. **No live bounding box** (we don't have it either) but the absence reads as restraint, not lack.

---

## 2. Snap → result transition

### Cal AI

Cal AI's analyzing screen is the bridge — and the conversion lever. Reviews describe it as **2–3 seconds total** (fuelnutrition.app) with a staged multi-step text reveal over the photo (now dimmed/blurred). Sources don't agree on the exact step count, but the consensus pattern is:

- The captured photo stays on screen, **dimmed with a dark overlay**
- A **scanning-line sweep** (top→bottom, then bottom→top) passes over the image — the classic AR-coded vertical line
- **Streaming text rows** appear with checkmarks as each "step" completes: detect items → estimate portions → look up nutrition → calculate macros → finalize
- Sometimes a **pulsing rectangle** appears around the detected food area (post-detection, not pre-)
- Result card slides up from the bottom as a sheet

This is straight Buell & Norton (2011) "labor illusion" UX. The Harvard Business School study showed users actually *prefer* services that demonstrate effort, even when results are identical to instant ones. Cal AI's clone universe (Kaloria, Cal Scanner AI, CalCam, Calorify) all replicate the staged-steps pattern, strongly suggesting it's load-bearing for the category.

### JeniFit's current state (for comparison)

Already partially there: 3 streaming text rows with italic-Fraunces punch words —
`*looking* at your plate` → `*matching* ingredients` → `*estimating* portions`,
over a central rose bloom (3-ring soft pink, breathing 0.92→1.08), 1.5–3s.

### The leapfrog (proposed delta)

Cal AI shows the **photo** during analyzing. JeniFit currently shows a **rose bloom** that *replaces* the photo. **Switch to Cal AI's pattern: keep the photo, dim it, layer the bloom over it.**

Why: showing her dimmed photo with the bloom rising from her actual plate is the magical-translation move. She watches *her food* become recognized, not a generic loader. This is the single highest-impact change in the whole flow.

```
Current JeniFit                Proposed JeniFit
┌────────────────┐             ┌────────────────┐
│                │             │  (her photo,   │
│   🌸 (rose      │             │   dimmed 60%)  │
│      bloom)    │             │                │
│                │             │      🌸          │  ← bloom anchored over
│                │             │  *looking*…    │     detected food
│ *looking*…     │             │                │
│                │             │                │
└────────────────┘             └────────────────┘
```

And: **sequence the bloom**. Frame 1 the bloom is at the plate center. Frame 2 (when `matching ingredients` fires) the bloom *splits* into 2–3 mini-blooms that drift to the detected items. Frame 3 (when `estimating portions` fires) the mini-blooms *settle* and a faint italic-Fraunces tag appears next to each: `*pasta* ♥`, `*basil* ♥`, `*olive oil* ♥`. This is the JeniFit answer to Cal AI's bounding box — we don't draw a rectangle around the food, we drop a flower-3D sticker that *says its name in our voice*.

---

## 3. The streaming copy (the famous Cal AI "8 steps")

### Cal AI

I could not find a verbatim list of Cal AI's processing copy in any public source (screensdesign, mobbin, the screenshot teardowns, the Behance gallery all stop short of transcribing it). The "8 steps" framing in the founder's prompt is plausible folklore but unverified in public material. What IS verifiable from the clone universe + reviews:

- The steps map to engineering reality: **detection → segmentation → portion/volume estimate → ingredient lookup → macro calculation → finalize**. That's 5–6 logical steps; Cal AI may pad to 7–8 for labor illusion.
- The voice is **operational-engineering register**: "Detecting items," "Estimating volume," "Calculating macros," "Finalizing." Sans-serif, sentence case, technical verbs. Same family as ChatGPT's "thinking…" / Perplexity's "Searching for…" pattern.
- Each step **checkmarks** as it completes. This is the Buell & Norton operational-transparency tell — checkmarks are the social proof that work happened.

### Why this works for Cal AI's audience

Their cohort came from MyFitnessPal. MFP's whole conversion story is "log every ingredient." Cal AI replaces *typing* the ingredients with *watching* the app identify them — but it has to **demonstrate the identification labor** or the user thinks the app cheated. The 7–8 steps ARE the trust ritual.

### Why this would fail for JeniFit

Three reasons:

1. **Brain tax during food noise.** Our cohort opens the camera mid-decision ("should I eat this?"). 8 streaming verbs is a cognitive load *they don't have*. The longer the loader, the more the food-noise voice (research: GLP-1 cohort + restriction history) edits the upcoming number before it arrives.
2. **Clinical register collides with brand voice locks.** "Detecting → Segmenting → Calculating" is the voice of an engineer scoring her plate. Our brand is the voice of a *friend* describing it. The two cannot coexist on the same screen.
3. **More steps = more deceptive-billing energy.** Apple pulled Cal AI in April 2026 (MacRumors, TechCrunch, 9to5Mac) specifically for stacking perceived-precision UI on top of trial-toggle ambiguity. Long labor sequences set up the "well, the AI worked so hard, of COURSE this costs $30/yr" frame. JeniFit's pricing locked at $47.99 annual ([[project-pricing-locked-v1-0-7]]) cannot lean on labor illusion the way Cal AI did — we have to earn the price by being *better company*, not by performing effort.

### The leapfrog

**Stay at 3 steps. Keep the italic-Fraunces lowercase pattern. Add a fourth ONLY if needed for slow networks** (timeout >2.5s):

- `*looking* at your plate` (0–600ms)
- `*matching* ingredients` (600–1400ms)
- `*estimating* portions` (1400–2200ms)
- *if needed*: `*almost there* ♥` (2200ms+, only fires on slow network)

The italic-Fraunces makes one word per row do the work that Cal AI does with two technical sentences. The lowercase + heart on the slow-network line is the brand's apology mechanism — Cal AI has no equivalent.

---

## 4. Result card surface

### Cal AI

The result is a **bottom sheet** that rises over the dimmed photo. Top of card shows total calories prominently. Below: macros (P/C/F bars or grams). Below that: **a list of detected ingredients as editable rows** — each with name, estimated weight in grams, ability to tap-edit. (Confirmed by fuelnutrition.app, eesel.ai, trygaya.com, aumiqx.com.) Quick portion buttons (1/2, 3/4, 1x, 1.25x, 1.5x, 2x) scale the whole meal up/down. A **"Fix Results"** button opens a free-text describe field for re-analysis: "Actually 2 chicken breasts, not 1." (Confirmed by multiple sources.)

A meal that the model cannot identify renders the ingredient section as **"Ingredients hidden"** (trygaya.com) — a quiet fail-soft that does not say "we don't know."

ASCII:

```
Cal AI result card
┌──────────────────────────┐
│  (dimmed photo)          │
│  ┌──────────────────────┐│
│  │  ← back        ⓘ ︙  ││
│  │                      ││
│  │     742 cal           ││  ← hero number
│  │  P 38g  C 88g  F 22g ││
│  │                      ││
│  │  Pasta         180g  ││  ← editable ingredient rows
│  │  Tomato sauce  120g  ││
│  │  Parmesan       15g  ││
│  │                      ││
│  │  [1/2][3/4][1x]…     ││  ← portion scale buttons
│  │                      ││
│  │  [Fix Results]       ││
│  │  [Add to Lunch] ────►││
│  └──────────────────────┘│
└──────────────────────────┘
```

### JeniFit translation

The Cal AI card is **calorie-first, ingredient-list-second**. For our cohort this is exactly backward: it instantiates "the number" as the unit of trust before she's had a chance to *feel* the meal. The post-Ozempic anti-shame frame ([[feedback-food-ux-antishame]]) makes that opening number the most dangerous pixel in the app.

Our card should lead with a **feeling-word**, then the meal name, then the energy, then ingredients. The number is fourth on the page, not first.

```
JeniFit result card (proposed)
┌──────────────────────────┐
│  (her photo, full color, │
│   undimmed — celebration │
│   not interrogation)     │
│  ┌──────────────────────┐│
│  │                       ││
│  │  this looks            ││
│  │  *satisfying* ♥       ││  ← italic-Fraunces feeling word
│  │                       ││
│  │  pasta + tomato        ││
│  │  ~742 cal • fits ♥    ││  ← '~' signals uncertainty in
│  │                       ││     language (not %), 'fits' is
│  │  what's on the plate:  ││     the post-Ozempic permission
│  │   • pasta              ││     vocabulary
│  │   • tomato sauce       ││
│  │   • parmesan           ││
│  │                       ││
│  │  ╭───────────╮         ││
│  │  │ log meal  │         ││  ← cocoa pill
│  │  ╰───────────╯         ││
│  │  tell me more ♥        ││  ← inline link, replaces "Fix Results"
│  │                       ││
│  └──────────────────────┘│
└──────────────────────────┘
```

Specifically translated moves:

| Cal AI | JeniFit |
|---|---|
| Hero number (742 cal) | Feeling word (`*satisfying* ♥`), then meal name, then `~cal • fits ♥` |
| "P 38g C 88g F 22g" | Hidden behind a tap. Macros are second-screen depth, not hero. |
| Editable ingredient rows w/ grams | `what's on the plate:` bulleted, no grams. Tap a bullet to refine. |
| Portion scale buttons (1/2, 3/4, 1x…) | A single thumb-drag pill: "this much" → "more like this". No fractions. |
| "Fix Results" button (chrome) | `tell me more ♥` inline text link, lowercase, framed as conversation not correction |
| Calorie-first orientation | Feeling-first → meal name → fits → ingredients → number is paragraph 3 |

The "fits ♥" tag is the key conversion move and the most defensible against Cal AI: it answers the only question our cohort actually came to ask (*can I eat this?*) with a one-word permission, then lets her drill into numbers if she wants. Cal AI cannot ship this because their audience demands the number be the answer.

---

## 5. Failure / retry UX

### Cal AI

- When the model can't identify the food, ingredient section renders as **"Ingredients hidden"** — a soft hide, not an apology (trygaya.com).
- When the model goes catastrophic ("27 million calories on a candy bar") users report **retaking the photo usually fixes it** — Cal AI does not detect or warn on absurd outputs.
- The **describe / "Fix Results" path** is the failure escape hatch: free-text "actually 2 chicken breasts, not 1" → re-analysis.
- No "couldn't see food" banner is documented. Cal AI prefers to return a wrong answer than to admit blindness, which is consistent with their conversion strategy (you don't get to charge $30/yr for "we don't know").

### JeniFit translation

Cal AI's failure UX is **dishonest by omission** — a deliberate trust trade-off. JeniFit's brand voice locks ([[feedback-data-provenance]]: every number must trace to a collected field; we never fabricate) make that trade-off unavailable to us. **We must build a more honest failure UX, AND make it warm enough that the honesty doesn't read as failure.**

Three states:

1. **Low confidence (model returned but uncertain)**:
   ```
   hmm — i'm not *quite* sure ♥
   could be ~600–900 cal
   want to tell me more?
   ```
   - `~600–900` is a **range**, not a guess. Cal AI never shows ranges.
   - "want to tell me more?" is the same inline link as the happy-path correction. Failure and refinement share UI.

2. **No food detected** (camera saw a hand / table / nothing):
   ```
   i couldn't *see* a plate ♥
   want to try again?
   [retake] [describe instead]
   ```
   - Two cocoa pills, equal weight. Retake is not the only path.

3. **Network failure**:
   ```
   the wifi's *being shy* ♥
   try again in a sec
   [retry]
   ```
   - "shy" is the brand-voice mechanism. Cal AI says "Try again." We blame the wifi gently.

All three failure states route through the same **describe-instead** path, which is the lowest-friction path Cal AI offers but they bury it. We promote it to first-class.

---

## 6. What Cal AI gets RIGHT (translate, don't copy)

1. **Labor illusion → perceived precision.** The 2–3s staged analyzing animation makes the eventual number feel earned. Buell & Norton 2011 is real. **Translate as**: keep the 3-step animation, but stage it over her actual dimmed photo with mini-blooms drifting to detected items.

2. **Editable result rows.** Every Cal AI clone copied this for a reason: editability turns model error into user agency. **Translate as**: `tell me more ♥` inline link + tap-to-refine bullet rows (no grams), permission framing.

3. **Single-purpose camera screen.** Cal AI's viewfinder is uncluttered — one shutter, three mode tabs, that's it. **Translate as**: cocoa pill shutter, two thin marks for food/barcode (not three tabs — drop the food-label OCR mode for v1, it's not our cohort's job), no other chrome.

4. **The shareable TikTok moment.** Cal AI went viral because "point camera → number" is a 15-second video. **Translate as**: our shareable moment is the *bloom-drift-to-detected-items* animation, not the number. We design for the screenshot of `*satisfying* ♥`, not the screenshot of 742 cal.

5. **Bottom-sheet result card.** Better than a full-screen push — preserves spatial context that the result came from the photo. **Translate as**: keep the sheet pattern, but undim the photo when it slides up (celebration, not interrogation).

6. **Quick portion buttons.** 1/2, 3/4, 1x, 1.25x, 1.5x, 2x is the right *behavioral idea* — let her scale without typing — but the *fractions* are diet-culture math. **Translate as**: thumb-drag pill "this much ←→ more like this," no numbers.

---

## 7. What Cal AI gets WRONG (for our cohort)

1. **Clinical-AR register.** Bounding boxes, scanlines, "Detecting items." This is the voice of MFP-but-with-a-camera. Our cohort fled MFP because of the red bars and the math. Importing the visual language imports the trauma.

2. **Calorie-first card hierarchy.** The hero number is the most dangerous pixel for restriction-prone and GLP-1 cohorts ([[feedback-food-ux-antishame]]). Leading with it instantiates "the number" as the unit of meaning before the meal is even named.

3. **Macros as bars/grams up front.** "P 38g C 88g F 22g" is gym-bro vocabulary. Our cohort doesn't track macros — they track *how today went*. Macros belong on a depth screen, not the result hero.

4. **Brain-tax labor sequences.** 7–8 steps over a dimmed photo, during a food-noise moment, is a long time to wait for permission. Each step extends the window during which her inner critic edits the number before it arrives.

5. **Dishonest failure UX.** "Ingredients hidden" without a "we couldn't see it" admission breaks the brand's data-provenance rule and trains the user to distrust the result silently. The 27-million-calorie outliers tell us their system has no sanity check.

6. **The deceptive-billing kinship.** Apple pulled Cal AI specifically for stacking perceived-precision UI on top of opaque billing (MacRumors, TechCrunch, 9to5Mac, all 2026-04-21). The labor illusion + obscured trial toggle + dual-flow re-prompt was a coherent system. We cannot lean on labor illusion the same way without inheriting the same gravity toward deceptive-billing patterns. Our pricing already locks at $47.99/yr with hard paywall — we have to earn that with relationship, not theater.

7. **No mode for "i'm about to eat" vs "i'm eating."** [[project-food-rail-v2-locked]] D54 already collapsed the pre-eat/eat toggle into Jeni copy, but the underlying insight is that Cal AI has only one mental model (after-the-fact logging) and our cohort lives in two (deciding + recording). The pre-eat use case is invisible to Cal AI and is our wedge.

8. **No relationship continuity between scans.** Cal AI users report "Corrections do not persist between scans" (fuelnutrition.app). Telling the app "actually 2 chicken breasts" once doesn't teach it. This is the corrections-as-moat opportunity ([[feedback-food-vision-models]]) — every "tell me more ♥" we accept makes the next scan smarter for *her*, and we should say so.

---

## 8. The magical translation table (Cal AI → JeniFit)

| Cal AI UX move | JeniFit translation | Brand-voice rationale |
|---|---|---|
| Live viewfinder, no overlay, white shutter circle | Live viewfinder, sticker scatter periphery, cocoa pill shutter labeled `tap to scan`, italic-Fraunces subhead `*show me* your plate ♥` | Single voice signature; pill matches our CTA system; periphery stickers = coquette without violating restraint |
| Bottom segmented control `Scan Food / Barcode / Food Label` | Two thin dot marks `food • barcode` (food-label OCR dropped for v1) | Reduce chrome; our cohort eats plates, not packages; thin marks are the luxury-restraint register |
| Bounding box drawn around detected food | Flower-3D mini-bloom sticker drifts to detected item, italic-Fraunces tag `*pasta* ♥` appears next to it | Rectangles are AR-coded clinical; blooms+tags are coquette+conversational. Same precision signal, opposite register. |
| Vertical scanline sweep over dimmed photo | Photo dimmed 60% with single rose bloom rising from plate center, then *splitting* into mini-blooms that drift to detected items | Same labor illusion, biological/organic motion instead of mechanical sweep. Bloom anchored to her real food, not a generic loader. |
| 7–8 streaming engineering steps with checkmarks | 3 italic-Fraunces verbs: `*looking*`, `*matching*`, `*estimating*`. Optional 4th `*almost there* ♥` only on slow network | Brain-tax budget; lowercase casual punch-word voice; checkmarks replaced by the bloom landing on each ingredient |
| Result card slides up, hero = "742 cal" | Result card slides up, hero = `*satisfying* ♥`, then `pasta + tomato`, then `~742 cal • fits ♥`, then ingredients, then everything else | Feeling-first card hierarchy; uncertainty in language (~) not percentages; "fits" is post-Ozempic permission vocabulary |
| Macros up front (P/C/F grams) | Macros behind a tap on the cal pill (`~742 cal • fits ♥` tappable) → bento depth screen | Macros are gym-bro register; depth is opt-in for the user who actually wants them |
| Quick portion buttons (1/2, 3/4, 1x, 1.25x, 1.5x, 2x) | Thumb-drag pill: `this much ←→ more like this` with the bloom on the plate scaling visually as she drags | No fractions = no diet-culture math; visual scaling is more honest than numeric scaling |
| `Fix Results` button (chrome rectangle) | `tell me more ♥` inline text link below the cocoa CTA | Conversation register, not correction register; same path serves happy-path refinement and failure recovery |
| "Ingredients hidden" silent fail | `hmm — i'm not *quite* sure ♥ could be ~600–900 cal` with range + describe path | Data-provenance honesty + uncertainty-in-language. We never silently hide. |
| No corrections persistence across scans | Every `tell me more ♥` accepted, stored against her plate-vocabulary, and reflected next time with `i remembered ♥` (1-shot) | Corrections-as-moat ([[feedback-food-vision-models]]). The fact that Cal AI can't do this is our durable wedge. |
| `[Add to Lunch]` final CTA | `log meal` cocoa pill (no meal-type pre-pick — derived from time of day silently like Kaloria does, but never displayed as chrome) | Reduce decision count; our cohort doesn't want to be asked "is this lunch?" mid-food-noise |
| Onboarding card "Make sure Cal AI can see every ingredient when using the scan feature to ensure you can track your calories with 90% accuracy" | First-scan only: `tip: hold it like *this* ♥` with a 1-second loop of a hand tilting the phone to 45° over a plate. No accuracy number. | "90% accuracy" is the wrong claim for our brand (sets up litigation against the result). Show the gesture, don't promise the precision. |

---

## Implementation priority for v1.0.7 food rail

If we can only ship ONE change before the v1.0.7 cut, it's the **dimmed-photo + bloom-drift-to-detected-items** transition (Question 2). It's the single highest-leverage move because:

- It converts our existing loader (rose bloom replacing photo) into Cal AI's labor-illusion register WITHOUT importing their clinical voice
- It's the moment that becomes the TikTok screenshot (research shows Cal AI's virality was the camera moment, not the result)
- It anchors the perceived value to *her* plate, which makes the eventual number feel earned rather than imposed
- It costs ~1 day of Lottie/SwiftUI work (bloom split → drift → tag) and zero backend changes

Second priority: **result card hierarchy flip** (Question 4 / table row 5). Feeling-word hero instead of number hero. This is a 30-minute copy + view-model change but its conversion impact is comparable.

Third priority: **`tell me more ♥` + corrections persistence** (Question 8 / table row 11). Builds the durable wedge against Cal AI that compounds with usage.

Everything else (cocoa-pill shutter, dot-mark mode strip, thumb-drag portion pill) is polish that should ship but can ship in v1.0.8.

---

## Sources

- [Cal AI App Store listing](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616) — Apple
- [Cal AI marketing site](https://www.calai.app/) — official
- [ScreensDesign Cal AI UI Breakdown](https://screensdesign.com/showcase/cal-ai-calorie-tracker)
- [Cal AI review — fuelnutrition.app](https://fuelnutrition.app/reviews/cal-ai-review) — confirms 2–3s scan window, "Corrections do not persist between scans", 3-scan free tier
- [Cal AI review — trygaya.com](https://www.trygaya.com/review/cal-ai-review) — "Ingredients hidden" failure state, Reddit r/loseit reports of undercounting
- [Cal AI review — aumiqx.com](https://aumiqx.com/ai-tools/cal-ai-app-review-nutrition-tracker-2026/) — fork/plate as size reference, depth cues, geometric volume estimate
- [Cal AI review — eesel.ai](https://www.eesel.ai/blog/cal-ai)
- [TechCrunch — Apple's Cal AI crackdown, 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/) — deceptive billing UI, trial toggle, dual-flow re-prompt
- [MacRumors — Apple Pulled Cal AI for Deceptive Billing Design](https://www.macrumors.com/2026/04/21/apple-cal-ai-app-store-removal/)
- [9to5Mac — Popular calorie tracker briefly pulled](https://9to5mac.com/2026/04/21/popular-calorie-tracker-briefly-pulled-from-app-store-over-iap-and-billing-violations/)
- [Janno's X teardown — Cal AI scan guide redesign](https://x.com/heyzitlac/status/1923152549647089786) — old static do/don't card → new 3-step animated walkthrough
- [Kaloria camera scanner help docs](https://kaloria.ai/help/camera-scanner/) — Cal AI clone, documents the shutter/tabs/refine pattern faithfully
- [Mobbin Cal AI iOS flow (403 to bot, but referenced)](https://mobbin.com/explore/flows/579da5dd-453a-4e7c-9c11-d20708a4db82)
- [Buell & Norton 2011 — "The Labor Illusion: How Operational Transparency Increases Perceived Value"](https://www.hbs.edu/ris/Publication%20Files/Norton_Michael_The%20labor%20illusion%20How%20operational_f4269b70-3732-4fc4-8113-72d0c47533e0.pdf) — HBS canonical paper
- [SnapCalorie App Store](https://apps.apple.com/us/app/snapcalorie-ai-calorie-counter/id1574239307) — the actual depth-sensor live-overlay app (NOT Cal AI), useful as a contrast point
- [Cal AI TikTok scan demo](https://www.tiktok.com/@calai.app/video/7482853151062854958) — "Make sure Cal AI can see every ingredient … 90% accuracy" official framing

## Caveats

- I could not verify the exact verbatim "8 steps" copy in any public source. The 7–8 step structure is consistent with Cal AI's clone universe and the Buell & Norton playbook, but treat the specific number as folklore until we get a hands-on screen recording. The argument in §3 does not depend on the exact count — it depends on the *register* and the *brain tax*, both of which are well-evidenced.
- Mobbin's Cal AI iOS flow page (a primary canonical source for screen-by-screen captures) returned 403 to the bot. A founder-side login + screen capture would unlock the highest-resolution evidence for §1, §2, §4. Recommend grabbing this before ship.
- The depth-sensor framing on Cal AI's marketing page ("your phone's depth sensor calculates food volume") is contradicted by some technical write-ups that say only iPhone Pro models have LiDAR exposed to this kind of API, and SnapCalorie (not Cal AI) is the one explicitly leveraging it. Cal AI may be marketing-overclaiming the depth piece. Worth a real-device confirmation pass before we claim parity or differentiation here.
