# JeniFit Paywall — UX Research Brief v3 (horizontal-3-across, the working version)

**Date**: 2026-06-05
**Author**: senior UX research, on commission for founder (Han)
**Status**: founder overruled v2 vertical recommendation. v3 is the *how-to*, not a relitigation.
**Builds on**: [v1](paywall_research_ux_2026_06_06.md), [v2](paywall_research_ux_v2_2026_06_06.md). Locks the v2 strategy (3-tier visible, Quarterly winner, goal-aware default, real strikethrough anchor, split-badge mechanism). Re-opens only the layout question.

---

## TL;DR — Executive layout recommendation

**Three horizontal cards, but NOT three equal cards.** Ship a **"hero-middle"** composition: Quarterly is **15pt taller** (~150pt) than the two flankers (~135pt), occupies **~130pt of width** vs. **~110pt** for Annual + Weekly, sits on **cream-tinted fill** with the cocoa **2pt border**, and carries the conditional `recommended ♥` badge as a **floating ribbon** that sits 8pt above the card top, breaking the row's silhouette. Annual flanks left with a **shorter cocoa border (1pt)**, the BEST VALUE tag as a **corner-pill on the top-trailing edge** (not a full banner — banners eat ~20pt of card height we don't have), and the **3-DAY FREE microline replaces the savings subtitle inside the card body**. Weekly flanks right with **no border, no badge, no fill** — pure text-only card on a 1pt dotted divider so it visually de-emphasizes without disappearing (decoy mechanics need it to be readable, not attractive). The **strikethrough anchor on Annual moves out of the card and into a single line above the row** ("usually $99.96 / $51.97 off ♥") — this saves ~24pt of card height that all three cards need, and converts the strikethrough from "small grey number under a big number" (always weak on narrow cards) to a row-level anchor the eye reads *before* it picks a card. The **BecomingProjectionChip is cut** from this screen — re-home it to the post-onboarding plan-reveal moment where the projection actually has narrative weight, not as a paywall garnish. The **hero subhead is cut**; the headline alone carries the voice signal. The **trial timeline survives but compresses to a single 36pt strip** ("today free · day 2 reminder · day 3 $47.99 ♥") below the row, only when Annual is selected. Net composition: 44 + 64 (hero) + 24 (row-anchor) + 150 (tier row) + 36 (conditional trial) + 56 (CTA) + 32 (footer) = **~406pt**, leaving **~314pt of headroom** on iPhone 13 mini — enough for the cream sticker scatter to live in the breathing room without scroll risk.

This composition (1) uses height + width + fill *together* to win the center, instead of relying on a single signal that gets lost at 114pt; (2) treats the strikethrough as a row-wide anchor because narrow cards make the strikethrough invisible at any reasonable type size; (3) demotes Weekly's chrome rather than its readability so the decoy effect still fires; (4) keeps the conditional badge as a floating element so it can break the row's silhouette without taking width inside the card. The pattern is borrowed from Fastic + KetoCycle + MyNetDiary 2026 paywalls ([Funnelfox teardown 2026](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/), [Adapty paywall library 2026](https://adapty.io/paywall-library/)) and aligns with [Adapty's iOS Paywall Design Guide 2026](https://adapty.io/blog/how-to-design-ios-paywall/) recommendation to "make the recommended plan visually dominant" via multiple compounding signals when single signals can't carry the weight.

---

## The geometry, locked first

iPhone 13 mini is the binding constraint. Everything else is derived from this.

```
device:         390pt wide × 812pt tall
safe area:      50pt top + 34pt bottom
usable:         390pt × 728pt
horizontal pad: 16pt + 16pt
content width:  358pt
```

**Three equal cards** with 8pt gaps would each be **(358 − 16) / 3 = 114pt**. That's the v2 problem — Annual can't fit BEST VALUE + 3-DAY FREE + price + strikethrough + savings line in 114pt without two of those elements becoming sub-9pt type or wrapping.

**Hero-middle math** — using the **golden-ish 1.18× ratio** that human eyes read as "winner, not weird":

```
Quarterly winner:  ~130pt wide  (358 − 16 − 110 − 110 − 8 = doesn't math)

let me redo:
Quarterly:  130pt
Annual:     104pt
Weekly:     104pt
gaps:       2 × 8pt = 16pt
total:      130 + 104 + 104 + 16 = 354pt   ← fits 358pt with 4pt slack ✓
```

Quarterly is **1.25× the width** of either flanker. That's enough to read as "this one is bigger" without screaming. The 8pt gap is preserved. The cards are anchored to the row baseline (bottom-aligned), so Quarterly's extra 15pt of height pushes its **top edge above** the flankers — that vertical lift is doing real work, see Q1 + Q3.

---

## Q1 — Specific card layout for each tier (top-to-bottom stacks, pt-explicit)

### Annual (104pt × 135pt) — left flanker, "responsible believer" choice

```
┌──────────────────────────────┐  104pt wide
│                       [BEST] │  4pt top inset + corner pill (10pt h)
│                              │
│  yearly                      │  14pt Inter Medium #2B1F1A, 12pt top
│                              │
│  $47.99                      │  22pt Fraunces Semibold, 4pt below
│                              │
│  3-day free trial ♥          │  11pt Inter Medium #7B5959, 6pt below
│                              │
│  $4.00/mo                    │  10pt Inter Regular #7B5959, 4pt below
│                              │
│                          [○] │  selector dot, bottom-trailing
└──────────────────────────────┘
height: 135pt
```

**What survived:** title, price, trial line, monthly-equivalent ($4.00/mo — this is **Cal-AI-compliance-safe** because it's the *legitimate billed-month divisor* of an annual, not a misleading per-week display [TechCrunch 2026](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)), BEST VALUE badge (as corner pill), selector dot.

**What got cut:**
- `$99.96` strikethrough → moved to row-level anchor line above the row (see Q4).
- `save $51.97 vs quarterly` → moved to row-level anchor line above the row.
- "3-DAY FREE" full-caps banner → replaced by lowercase "3-day free trial ♥" inside body (matches voice locks, frees the top of the card for the corner pill).

The corner pill (10pt height, 30pt wide, Fraunces 9pt all-caps "BEST") is a much smaller commitment than the previous full-width banner. It's enough to read but doesn't compete with Quarterly's floating ribbon for visual mass.

### Quarterly (130pt × 150pt) — center winner

```
       ┌─────────────────────┐
       │ recommended for ♥  │  floating ribbon, sits −8pt above card top
       │   your 12-wk goal   │  shows ONLY when goalSolvableInTwelveWeeks
       └─────────────────────┘     ↓ 8pt
┌────────────────────────────────┐  130pt wide, cream fill #FAF3EC
│                                │
│  quarterly                     │  15pt Inter Medium, 14pt top
│                                │
│  $24.99                        │  28pt Fraunces Semibold, 6pt below
│                                │
│  12 weeks of becoming ♥        │  12pt italic Fraunces #5C4036, 8pt below
│                                │     ← voice-signal italic accent
│  $2.08/wk                      │  11pt Inter Regular #7B5959, 6pt below
│                                │
│                          [●]   │  selector dot, filled cocoa
└────────────────────────────────┘
height: 150pt
border: 2pt cocoa #5C4036
fill:   cream #FAF3EC (1pt darker than page #FBF6EF)
shadow: 0 2pt 0 #5C4036 (scrapbook hard offset)
```

**What's working:**
- **Width (1.25× flankers), height (1.11× flankers), fill (cream tint), border (2pt vs 1pt), and floating ribbon** are five compounding signals. Single-signal "winner" treatments fail at 114pt — multi-signal layered treatment is the only thing that survives. [Adapty 2026 design guide](https://adapty.io/blog/how-to-design-ios-paywall/) explicitly recommends "make the recommended plan visually dominant" via stacked treatments.
- **The 12pt italic Fraunces line** "12 weeks of becoming ♥" is the **voice-signal carrier** for this card. It does the work the cut subhead used to do, locally to the recommended tier. Pulls the brand voice onto the card that matters most.
- **$2.08/wk** is **NOT** a Cal-AI-compliance issue on Quarterly — quarterly billed as a single $24.99 charge legitimately divides to ~$2.08/wk, and weekly display is fine when the actual billing period contains real weeks (Apple's rejection language targets *annual-displayed-as-weekly*, not quarterly).
- **The floating ribbon** sits **outside** the card (negative 8pt margin), so the badge text "recommended for your 12-week goal ♥" has **130pt of width + the 8pt above-card vertical room** to breathe. This is the ONLY badge placement that fits the full conditional badge text without wrapping inside the card body. See Q2 + Q7.
- **When the user does NOT have a ≤12wk solvable goal**, the ribbon hides cleanly: the card stays in place (height: 150pt unchanged), Quarterly still wins on width + fill + border + selector — the ribbon was the *fifth* signal, not load-bearing alone. Quarterly remains the center-stage default in either condition.

### Weekly (104pt × 135pt) — right flanker, decoy

```
┌ . . . . . . . . . . . . . . ┐  104pt wide, 1pt dashed border #C8B5A6
.                              .  (decoy — present, not attractive)
.  weekly                      .  14pt Inter Medium, 12pt top
.                              .
.  $5.99                       .  22pt Fraunces Semibold, 4pt below
.                              .
.  flexible week ♥             .  11pt Inter Regular #7B5959, 6pt below
.                              .
.  $5.99/wk                    .  10pt Inter Regular #7B5959, 4pt below
.                              .
.                          [○] .  selector dot
└ . . . . . . . . . . . . . . ┘
height: 135pt
border: 1pt dashed cocoa-tan (not solid)
fill:   none (page background shows through)
shadow: none
```

**What's working:**
- **Dashed border + no fill + no shadow** demotes weekly visually without hiding it. The user can still tap it; it just doesn't feel like the answer. This is the **decoy execution** that [Adapty 2026 (Nebula pattern)](https://adapty.io/blog/high-performing-paywall-2026/) describes — the third tier exists to anchor the center, not to sell.
- "flexible week ♥" is the **voice equivalent** of "no commitment" / "month-to-month" — keeps the brand register, names the value (flexibility) instead of the lack (no trial).
- **No badge** as locked. The visual silence is the signal.

---

## Q2 — Badge placement strategy (the three badges, three placements)

The three badges have three different jobs. They should sit in three different places. Treating them as a uniform "badge slot" loses the hierarchy.

### BEST VALUE (Annual) — corner pill, top-trailing

- **Where:** 4pt inset from top-trailing corner of the Annual card.
- **Size:** 30pt wide × 10pt tall, 4pt corner radius, cocoa fill #5C4036, cream text #FBF6EF.
- **Type:** Fraunces 9pt all-caps "BEST" — not "BEST VALUE," because "BEST" alone reads as the same noun in 9pt + 30pt, and "VALUE" is implicit in a pricing context.
- **Why not banner:** A full-width "BEST VALUE" banner across the top of Annual eats ~20pt of card height we don't have. It also visually equates with Quarterly's floating ribbon and dilutes the hierarchy.
- **Reference:** Peak app's verified-style badge on the top-trailing side of the selected plan — explicitly noted in [Adapty 2026 design guide](https://adapty.io/blog/how-to-design-ios-paywall/) as a working pattern.

### 3-DAY FREE (Annual) — inline body line, NOT a badge

- **Where:** Inside the Annual card body, between price and monthly-equivalent.
- **Treatment:** lowercase Inter Medium 11pt "3-day free trial ♥" in textSecondary #7B5959, with the ♥ as terminal punctuation per voice locks.
- **Why demoted from badge to body:** Two badges on one card is dilution — the eye picks one and ignores the other. The free-trial line is more important as **trust signal text** ("you'll see this is real before you pay") than as a screaming visual. The screaming visual is already done by Annual carrying the BEST corner pill; the trial line is the *reason* the card is BEST.
- **Trial detail surfaces again at row-anchor + at trial timeline** when Annual is selected — so the user reads "free trial" three times on the screen (card body, row anchor implication, trial timeline strip). Triple-redundancy is the right level for the trial mechanic.

### recommended for your 12-week goal ♥ (Quarterly, conditional) — floating ribbon above card

- **Where:** Negative 8pt margin above Quarterly's card top edge. Sits in the row's negative space, doesn't consume card height.
- **Size:** ~130pt wide × 22pt tall, 8pt corner radius, cream-cocoa #F5E6D3 fill, cocoa #5C4036 text.
- **Type:** Inter Regular 10pt "recommended for ♥" first line, then "your 12-week goal" second line — **two lines** at 10pt × 1.2 line-height fits in 22pt with 2pt padding.
- **Shape:** Slightly tucked at the bottom-center with a 4pt notch pointing down into the card (scrapbook tape vibe — aligns with the coquette aesthetic, not a generic pill).
- **Conditional:** Renders only when `goalSolvableInTwelveWeeks == true`. When hidden, the row's vertical rhythm is unaffected (card heights are fixed; ribbon lives in the 8pt negative space above the row).
- **Why above-card, not in-card:** The full badge text is 33 characters. At Inter 10pt inside a 130pt-wide card body, it wraps to 2 lines and eats 28pt of card body before the title even renders. Above-card lets it use the full width of the card + extends into the row gap without anyone noticing.

```
                  ┌─────────────────────────┐
                  │ recommended for       ♥ │   ← floating ribbon
                  │ your 12-week goal       │     above the card,
                  └────────────┬┬───────────┘     2 lines @ 10pt
                               vv                  ← 4pt downward notch
        ┌─────────┐  ┌─────────────────────────┐  ┌─────────┐
        │ Annual  │  │      Quarterly          │  │ Weekly  │
        │ [BEST]  │  │                         │  │         │
        │ $47.99  │  │      $24.99             │  │ $5.99   │
        │  ...    │  │       ...               │  │  ...    │
        └─────────┘  └─────────────────────────┘  └─────────┘
```

---

## Q3 — Visual emphasis to make Quarterly win

Single-signal "winner" treatments fail at 114pt width. The card is too narrow for "subtle but clear" — you have to layer signals until the hierarchy is unmissable, then stop just before it tips into gaudy. **Five compounding signals** is the band.

| Signal | Quarterly | Annual | Weekly |
|---|---|---|---|
| Width | 130pt (1.25×) | 104pt | 104pt |
| Height | 150pt (1.11×) | 135pt | 135pt |
| Fill | cream #FAF3EC | none | none |
| Border | 2pt solid cocoa | 1pt solid cocoa-tan | 1pt dashed cocoa-tan |
| Shadow | 0 2pt 0 cocoa (hard offset, scrapbook) | none | none |
| Above-card badge | floating ribbon (conditional) | none | none |
| In-card badge | none | corner pill "BEST" | none |
| Selector default | filled cocoa dot | open dot | open dot |
| Voice italic | "12 weeks of becoming ♥" | none | none |

The vertical lift (Quarterly's top edge sits 15pt above the flankers because cards are baseline-aligned) is the most important *non-color* signal — eye-tracking studies on horizontal pricing rows consistently show the eye lands on whichever card "breaks the row's silhouette" first ([Funnelfox 2026](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/) Fastic teardown — "bright frame and elevated treatment, no confusion about the recommended choice").

The cream fill is **1 step darker** than the page background (#FAF3EC vs #FBF6EF), not the 4-5 steps that would scream "selected/highlighted." On a cream-on-cream scrapbook page, even a 1-step tint reads as "this one is held differently." Brand-consistent with the coquette aesthetic — no neon, no gradient, no glow.

**Center-stage effect mechanics:** the locked decision of "Quarterly is the recommended" comes from v2's analysis (goal-horizon match + center-stage effect + LTV trade). v3 is the rendering. Visual mass needs to match the strategic claim — if Quarterly is "recommended" but looks identical to the flankers, the recommendation feels hollow. Five layered signals make it feel earned.

---

## Q4 — What to cut to make 114pt cards work

**Cut #1 (load-bearing): BecomingProjectionChip from this screen.** Re-home it to the post-onboarding plan-reveal moment where the projection has narrative weight. The 110pt chip is a paywall garnish here — it's hard to read at compact height, it duplicates work the goal-aware pre-selection already does (the math is *inside* the Quarterly card now via "12 weeks of becoming ♥"), and it crowds out the row's breathing room. Saving 110pt + 16pt of vertical padding = **126pt recovered**, more than enough to grow Quarterly to 150pt height.

**Cut #2 (clean): hero subhead "your pace. your timeline."** The headline alone carries the voice signal. The subhead was useful when there was no other italic-Fraunces voice mark on the screen — now that "12 weeks of becoming ♥" lives on the Quarterly card, the voice signal carries from there. Saves **~26pt** + reduces redundancy. The headline stays at 64pt height, anchored solo.

**Cut #3 (move, not delete): strikethrough $99.96 + "save $51.97 vs quarterly" from Annual card → single row-anchor line above the row.**

```
                                                  usually $99.96  ·  $51.97 off ♥
                                                  ──────────────────────────────  ← 24pt row-anchor
        ┌─────────┐  ┌─────────────────────────┐  ┌─────────┐
        │ Annual  │  │      Quarterly          │  │ Weekly  │
        ...
```

Strikethrough at 10–11pt inside a 104pt-wide card is *visible* but it's not doing the **anchoring work** strikethrough is supposed to do — the eye reads price first, strikethrough second, savings third, and the comparison happens after the user has already mentally priced the card. Moving the strikethrough + savings to a row-level anchor above all three cards means the user reads "usually $99.96, $51.97 off" *first*, *then* scans the row. This is the **price-anchor-before-options** pattern from [Adapty 2026 H&F benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) — anchor the savings story at the row, let the cards carry the actual prices clean.

The row-anchor line uses italic Fraunces 12pt for "usually $99.96" with the strikethrough struck through Annual's eventual price, then Inter Medium 12pt for "$51.97 off ♥". One line, 24pt tall including 8pt bottom padding. Cocoa #5C4036.

**Cut #4 (compress): trial timeline strip — 88pt → 36pt single line.** Today's full 3-row stacked timeline ("today free / day 2 reminder / day 3 $47.99 ♥") compresses to a single horizontal pill: `[today free]──[day 2 reminder]──[day 3 $47.99 ♥]`, 36pt tall, only renders when Annual is selected. When Quarterly or Weekly is selected, this slot collapses to 0pt and the CTA snaps up.

**Total saved by cuts:** 126 + 26 + (24 net of moving strikethrough into a 24pt line, so 0 saved here but improved comprehension) + (88 − 36 = 52, conditional) = **~200pt of recovered viewport** on the Annual-selected state, **~250pt on Quarterly-selected**.

---

## Q5 — Selected state on narrow cards

The current 1.5pt cocoa border doesn't work as the selected-state mechanism when Quarterly is *already* on a 2pt cocoa border by default. We need a different visual move for "selected."

### Recommended selected-state stack:

1. **Selector dot fills** (open #C8B5A6 1pt ring → filled cocoa #5C4036 solid 6pt dot, 10pt outer ring). This is the primary "I picked you" signal — universal across the three cards.
2. **Card border thickens by 0.5pt across the board.** Annual: 1pt → 1.5pt. Quarterly: 2pt → 2.5pt. Weekly: 1pt dashed → 1.5pt dashed. The relative hierarchy stays intact; the *change* is the selection cue.
3. **Card fill nudges 1 step warmer.** Annual selected: gets a cream fill #FAF3EC (the same as Quarterly's default — converges only on selection). Quarterly selected: stays at #FAF3EC (already filled). Weekly selected: gets a 50%-opacity cream fill (so the dashed border still reads, but the card no longer feels like a hollow option).
4. **Soft scale: 1.0 → 1.02** with 0.16s `Tokens.tap` spring. Subtle, brand-aligned, doesn't break the layout math (1.02 × 130pt = 132.6pt — well within the 4pt slack the row math allows).

### Tap target: the whole card is the tap target.

At 104pt × 135pt the smallest tap target (Annual or Weekly) is ~**14,040 pt²**, vs. Apple HIG 44 × 44 = 1,936 pt². You're at **7× minimum**, so the entire card is comfortably tappable. Don't put a separate "select" button inside — that's a Cal-AI-rejection-pattern (confusing the user about what action does what — [TechCrunch 2026](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)).

```swift
.contentShape(Rectangle())
.onTapGesture {
    withAnimation(Tokens.tap) {
        selectedTier = tier
    }
}
.scaleEffect(selectedTier == tier ? 1.02 : 1.0)
```

---

## Q6 — Tap target sizing

Apple HIG minimum is 44 × 44pt. WCAG AAA is 44 × 44pt CSS. Both cleared by 7× on Annual/Weekly (104 × 135pt = ~7.2× the minimum area) and 10× on Quarterly (130 × 150pt = ~10×).

**Selector dot is decorative-only** — not an independent tap target. Hit-testing routes through the card's `.contentShape(Rectangle())` so the user can tap anywhere on the card. This is the only HIG-compliant pattern here: separate hit-targets inside narrow cards always end in mis-taps and the App Store reviewer flags it.

**The floating ribbon is NOT tappable.** It's visual chrome only. Tapping the ribbon should fall through to Quarterly's card tap. Use `.allowsHitTesting(false)` on the ribbon overlay.

**The corner pill BEST is NOT tappable.** Same treatment — `.allowsHitTesting(false)`.

---

## Q7 — Quarterly badge text options

The locked text "recommended for your 12-week goal ♥" is 35 characters with the heart. At Inter 10pt, that's ~140pt of single-line width — wider than the 130pt card. **Two lines is the answer**, but only when the badge lives above the card. If we tried to put a 2-line badge *inside* the card, we'd eat 28pt of card body — and the card body has 4 vertical slots (title / price / italic line / per-period). One of them dies.

### Recommended placement: floating ribbon above card, 2 lines, 10pt Inter.

```
recommended for       ♥
your 12-week goal
```

The heart sits **at the end of line 1**, terminal-punctuation style per voice locks ([feedback_voice_signals.md](../../.claude/memory/feedback_voice_signals.md)). Line 2 is the goal phrase. Reads naturally; doesn't break the cadence; honors the lock.

### Fallback if floating ribbon is rejected: shorten badge text

Voice-preserving options, ranked by closeness to the lock:

1. **"recommended ♥ · 12-week match"** (single line, 27 char, fits 110pt at 10pt)
2. **"matches your 12 weeks ♥"** (single line, 22 char, fits 100pt at 10pt)
3. **"for your 12 weeks ♥"** (single line, 18 char, fits 90pt at 10pt — most compressed)
4. **"♥ recommended"** + caption below row ("matches your 12-week goal") (badge minimal, caption row-level)

Of these, **(2) "matches your 12 weeks ♥"** is the strongest single-line fallback. Drops "recommended" (the visual treatment IS the recommendation) and "goal" (implicit in fitness paywall context), keeps the **goal-horizon coherence** that's doing the strategic work. Voice-locked, lowercase, terminal heart.

**Strong recommendation: ship the floating-ribbon 2-line treatment.** The fallback exists but it's a worse design — the 2-line ribbon is what makes the recommendation feel personal ("we built this to fit *your* timeline"), and that's the entire pitch.

---

## Q8 — 2026 reference apps (horizontal-3-tier, weight-loss/wellness)

The horizontal-3-across pattern is genre-canonical in 2026 fitness/wellness. Specific examples I can ground claims in:

### Cal AI (food calorie tracker) — the most-iterated reference

- **Layout:** 3 tiers visible (weekly / yearly / lifetime in current ship, per [Adapty paywall library](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/)). Yearly is the visual winner via fill + savings callout.
- **Iteration scale:** [Superwall case study](https://superwall.com/case-studies/cal-ai) — 123 experiments across 46 trigger points, 31% lift in trial-to-paid conversion, 3× monthly revenue in 10 months. The current shipping layout is the survivor of 61 onboarding-paywall experiments.
- **What we borrow:** the multi-signal winner treatment (fill + savings line + selector). The 3-tier-visible pattern is genre-canonical, not Cal-AI-novel.
- **What we do NOT borrow:** the misleading weekly-equivalent display on annual (per [Apple's April 2026 rejection](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)). Our Annual shows **$4.00/mo** (legitimate monthly divisor of annual), not "$0.92/wk" (the rejection pattern).
- **What we improve:** Cal AI's "best value" badge sits inside the card body and eats vertical space. Our corner-pill + floating-ribbon split avoids this.

### Fastic + KetoCycle (weight loss) — winner-treatment reference

- **Layout:** 3-card horizontal with the recommended tier highlighted via "bright frame" and elevated treatment, per [Funnelfox 2026 teardown](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/).
- **What we borrow:** the multi-signal "no confusion about the recommended choice" approach. Fastic uses fill + border + savings percentage + size lift. We match the pattern, swap the savings-percentage signal for our row-anchor strikethrough (because Apple's April 2026 enforcement makes per-card weekly displays risky).

### MyNetDiary GLP-1 Companion (wellness) — trust-signal reference

- **Layout:** 3-tier with annual dominant, monthly + quarterly flanking, per [Funnelfox 2026](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/). FREE TRIAL badge reframed as a reward, not a friction.
- **What we borrow:** the "trial as reward" reframing. Our Annual card's lowercase "3-day free trial ♥" inside the body (not as a screaming badge) matches the voice register MyNetDiary uses for the GLP-1 cohort — the cohort overlap with us is meaningful (post-Ozempic Gen-Z women are MyNetDiary's GLP-1 Companion target too).

### MacroFactor — "Most Popular" anchoring reference

- **Layout:** 3-tier vertical with "Most Popular" on the 12-month plan, per [Superwall's 5 paywall patterns](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/).
- **What we borrow:** the anchoring-as-the-only-signal-needed for the recommended tier. They're vertical, we're horizontal — but the "Most Popular" → "matches your 12 weeks ♥" voice translation is the same mechanic.

### Sunflower (period/wellness) — trial reminder lift reference

- **Layout:** unknown layout (not in public teardowns), but the [Superwall case study](https://superwall.com/blog/17-revenue-boost-with-transaction-abandon-paywalls-a-case-study/) shows **46% trial-conversion lift** from adding trial reminders. Our trial timeline strip (when Annual is selected) is doing exactly this work.

---

## What ships, slot by slot

```
┌────────────────────────────────────────────────────────────────┐
│ [restore]                                                  44pt │  topBar
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│     jen, sized for *your* timeline ♥                       64pt │  headline only
│                                              (subhead CUT)      │   (italic on "your")
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│              usually $99.96 · $51.97 off ♥                 24pt │  row-anchor
│                                                                 │   (Fraunces 12pt)
├────────────────────────────────────────────────────────────────┤
│              ┌──────────────────────────┐                       │
│              │ recommended for      ♥   │   floating ribbon     │
│              │ your 12-week goal        │   (conditional)       │
│              └──────────────┬───────────┘                       │
│ ┌───────┐    ┌──────────────v─────────────┐    ┌───────┐   158pt│  tier row
│ │ANN    │    │      QUARTERLY              │    │WEEK   │       │  (150pt cards +
│ │104×135│    │      130×150                │    │104×135│       │   8pt ribbon)
│ │ [BEST]│    │                             │    │       │       │
│ │$47.99 │    │      $24.99                 │    │$5.99  │       │
│ │3-day  │    │   12 weeks of *becoming* ♥  │    │flexi  │       │
│ │free ♥ │    │      $2.08/wk               │    │$5.99  │       │
│ │$4.00mo│    │                       [●]   │    │ /wk   │       │
│ │  [○]  │    │                             │    │  [○]  │       │
│ └───────┘    └─────────────────────────────┘    └───────┘       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ [today free]──[day 2 reminder]──[day 3 $47.99 ♥]           36pt │  trial strip
│                                                                 │   (only when Annual)
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│             ┌──────────────────────────┐                        │
│             │       continue           │                   56pt │  CTA (cocoa pill)
│             └──────────────────────────┘                        │
├────────────────────────────────────────────────────────────────┤
│   data stays yours · terms · privacy                       32pt │  footer
└────────────────────────────────────────────────────────────────┘

Total composition:
  44 (topBar)
+ 64 (headline)
+ 24 (row-anchor)
+ 158 (tier row, incl. 8pt floating ribbon overhang)
+ 36 (trial strip, when Annual)
+ 56 (CTA)
+ 32 (footer)
= 414pt content + 16pt vertical inter-slot rhythm × 6 = ~430pt
Plus 50 + 34pt safe areas = 514pt
Headroom on iPhone 13 mini (728pt usable): ~214pt
  ← enough for sticker scatter + breathing room, no scroll risk
```

---

## What was relitigated (none) and what was reopened (layout only)

**Untouched from v2:** 3 tiers visible, Quarterly winner, goal-aware default, real $99.96 strikethrough, $51.97 savings copy, split-badge mechanism, brand voice locks, Cal-AI-compliance discipline, headline "jen, sized for *your* timeline ♥," trial timeline existence + "no payment due now ♥" copy when Annual selected.

**Reopened and re-decided:**
- Layout direction: vertical → **horizontal** ✓ (founder overrule).
- Card content density: Annual carries 4 lines + corner pill; Quarterly carries 4 lines + floating ribbon; Weekly carries 4 lines, no chrome.
- Card visual treatment: hero-middle composition (1.25× width + 1.11× height + cream fill + 2pt border on Quarterly; corner pill on Annual; dashed-border-no-fill on Weekly).
- Aspect ratio: tall narrow (~0.87 width/height ratio on flankers, ~0.87 on Quarterly — same proportion, different scale, so visual mass differs without aspect-ratio dissonance).
- Badge placements: corner pill (Annual BEST) + body-line (Annual 3-day free) + floating ribbon (Quarterly recommended) + nothing (Weekly).
- BecomingProjectionChip: **cut from this screen**, re-home to plan-reveal moment.
- Hero subhead: **cut**.
- Trial timeline: **compressed 88pt → 36pt single line**, conditional on Annual.
- Strikethrough: **moved out of card to row-anchor line above the row**.
- Selected state: thicker border + warmer fill + filled dot + 1.02 scale.
- Card row spacing: 8pt gaps (locked by math).

---

## Build order recommendation

1. **Geometry first.** Wire up the 104 / 130 / 104 widths with 8pt gaps and confirm on iPhone 13 mini sim that the row fits 358pt content width with 4pt slack. If you can't get the widths right, the rest of the brief doesn't matter.
2. **Card content stacks next.** Annual / Quarterly / Weekly with the exact 4-line content from Q1. No badges yet, no fills, no borders — just text. Confirm legibility at the listed font sizes; this is where the brief breaks if it breaks.
3. **Visual hierarchy.** Add the fill + border + height-lift to Quarterly. Should immediately read as "winner" before any badges are added.
4. **Badges.** Annual corner pill, Quarterly floating ribbon. Test the conditional ribbon's hide/show with `goalSolvableInTwelveWeeks` toggle.
5. **Row-anchor strikethrough line.** Move the $99.96 + $51.97 off out of Annual's card body.
6. **Selected state.** Border thickening + fill nudge + selector dot fill + 1.02 scale. Tap targets confirmed via accessibility inspector.
7. **Cut the projection chip + hero subhead.** Confirm headline alone carries voice.
8. **Compress trial strip.** 88pt → 36pt single line, conditional on Annual.
9. **Polish: sticker scatter** in the recovered viewport headroom. The breathing room is the brand register.

If anything in step 2 or 3 doesn't read right at 104pt, fall back to the **Q7 fallback badge text** before falling back to layout changes — voice text is the cheaper compromise than layout math.

---

## Sources

- [Adapty — iOS Paywall Design Guide 2026](https://adapty.io/blog/how-to-design-ios-paywall/) — multi-signal recommended-plan dominance, badge placement options, in-card vs. above-card patterns
- [Adapty — High-performing paywall 2026](https://adapty.io/blog/high-performing-paywall-2026/) — Nebula decoy pattern, plan-structure-before-visuals testing order, 636% LTV gap on structural decisions
- [Adapty paywall library — Cal AI](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/) — 3-tier horizontal canonical reference
- [Funnelfox 2026 — Paywall teardowns](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/) — Fastic + KetoCycle + MyNetDiary horizontal-3-card winner-treatment patterns
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai) — 123 experiments, 31% trial-to-paid lift, 3× monthly revenue
- [Superwall — 17% revenue boost via transaction-abandon paywalls](https://superwall.com/blog/17-revenue-boost-with-transaction-abandon-paywalls-a-case-study/) — Sunflower 46% trial conversion lift via reminders (our trial timeline strip works on this evidence)
- [Superwall — Multi-tier paywalls](https://superwall.com/blog/how-to-build-multi-tiered-paywalls/) — multi-tier composition primitives
- [Apphud — High-converting paywall design](https://apphud.com/blog/design-high-converting-subscription-app-paywalls) — "make the recommended plan visually dominant" + badge taxonomy
- [TechCrunch — Apple's Cal AI crackdown April 2026](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/) — Cal-AI-compliance discipline for per-period display rules
- [Mobbin paywall library](https://mobbin.com/explore/mobile/screens/subscription-paywall) — visual reference for horizontal-card patterns across genres
- [Adapty paywall library](https://adapty.io/paywall-library/) — visual reference for fitness/wellness paywalls
- v1 + v2 internal: [paywall_research_ux_2026_06_06.md](paywall_research_ux_2026_06_06.md) + [paywall_research_ux_v2_2026_06_06.md](paywall_research_ux_v2_2026_06_06.md) — strategy decisions inherited, not re-litigated
