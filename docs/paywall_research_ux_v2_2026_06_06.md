# JeniFit Paywall — UX Research Brief v2 (3-tier visible + quarterly anchor)

**Date**: 2026-06-05
**Author**: senior UX research, on commission for founder (Han)
**Status**: opinionated reversal review of `a8d5fa3`. Pre-design pass.
**Builds on**: `docs/paywall_research_ux_2026_06_06.md` (v1) + `docs/paywall_research_monetization_2026_06_06.md`

---

## TL;DR — Executive Recommendation

**Partial validate, partial push back.** Show 3 plans visible — but go **vertical-stack, not horizontal**, with **Quarterly center-anchored** as the "most loved" pick using the center-stage effect ([Kent Hendricks](https://kenthendricks.com/center-stage-effect/), [coglode](https://www.coglode.com/research/centre-stage-effect)). Demote BecomingProjectionCard from full hero (~260pt) to a 110pt micro-projection chip — it still loss-aversion-primes without eating half the viewport. Keep the 3-DAY FREE badge on Annual (top card) and add a "no trial · cancel anytime" microline on the Quarterly card so the user reads both correctly. Kill the 3-row trial timeline (88pt → 0pt; the trial line lives inside the Annual card now). Headline pivots from "softer with food" (food-rail framing, not v1.0.7-correct yet) to a goal-permission line, with the goal-aware logic continuing to pre-select Quarterly for ≤12wk goals — but every user sees all three cards regardless. The horizontal-3-card layout the prior brief warned against was correct to warn against (vertical converts 30% better on mobile per [theswiftk.it 2026](https://theswiftk.it.com/blog/swiftui-paywall-design-best-practices)); the founder's instinct to show all three is also correct (3-tier converts 1.4× better than 2-tier per [Kent Hendricks summary](https://kenthendricks.com/center-stage-effect/) of SaaS pricing data). The way to honor both is vertical-stack with Quarterly in the middle, anchored, with the projection card downsized — not horizontal-3-across with the projection cut.

Net: the founder's product instinct (quarterly is right for our cohort) is well-supported by the goal-horizon math + the decoy-effect literature. The execution risk is the 3-cards-horizontal layout pattern, not the 3-tier-visible decision itself.

---

## Q1 — 3 visible plans: validate or push back?

### Verdict: **Validate the decision, push back on the implementation.**

The "show all three" instinct is correct. The "horizontal-3-across" execution that ships in many AI/fitness apps is wrong for our viewport and our cohort.

**Evidence for showing all three:**

- **3-tier converts ~1.4× the rate of 2-tier pages**, while 4+ tiers convert worse — the center-stage effect pulls buyers toward the middle when the layout is clean ([Kent Hendricks center-stage summary](https://kenthendricks.com/center-stage-effect/), [DigitalApplied 2026](https://www.digitalapplied.com/blog/subscription-pricing-page-psychology-decision-framework-2026)). My v1 brief's "hide weekly behind a drawer" recommendation was correct *if* you can't fit three cleanly; it leaves measurable conversion on the table if you can.
- **The decoy / center-stage mechanism requires three visible options to fire.** With only two visible (yearly + quarterly), the user evaluates them head-to-head on price; with three (yearly + quarterly + weekly), the weekly card's bad-deal economics make quarterly read as "fair value, smart pick" instead of "expensive vs. yearly." This is exactly the Nebula pattern that Adapty calls out — "weekly with trial / 3-month at full price (no trial) / annual with trial. The 3-month option exists to make the annual plan look like the obvious value choice and is not intended to sell" ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)). The founder is proposing to *invert* that decoy — make Quarterly the choice and use Weekly + Annual as the flanking anchors. That inversion has the same mechanical basis (see Q2).
- **2026 fitness genre normal is 3-tier visible.** Cal AI's iterated paywall surface shows all three (weekly / yearly / lifetime) per [Adapty paywall library](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/) and [screensdesign Cal AI](https://screensdesign.com/showcase/cal-ai-calorie-tracker). MacroFactor uses three with "Most Popular" on the 12-month ([Superwall 5 patterns](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/)). My v1 claim that "vertical-stack with weekly hidden" was canonical was overstated — the canonical pattern is "vertical-stack with all three visible and one anchored."

**Where my v1 brief was wrong:** I called out 17/20 Superwall library examples using vertical stacks (true) and conflated that with "2-tier surface is the modal pattern" (overreached). The modal pattern in **fitness specifically** is 3-tier vertical with one anchored, not 2-tier vertical with the third behind a link. The "hide monthly behind link" guidance from Apphud is real but it's an Apphud-favored test that applies cleanly to **utility/productivity apps** where every tier is functionally identical. For our cohort, where the price differential carries a *commitment signal* (quarterly = "I'm taking this seriously" vs. weekly = "I'm hedging"), surfacing all three lets the user self-select the commitment level she's actually ready for. This matters more for Gen-Z post-Ozempic cohorts who have been burned by hard-paywall apps and are reading the *plan offering* as a trust signal ("they didn't try to corral me into one tier").

**Push back on horizontal 3-across (which I correctly warned against in v1):**

- **Vertical stacks convert ~30% better than horizontal on mobile**, per [theswiftk.it 2026](https://theswiftk.it.com/blog/swiftui-paywall-design-best-practices) (citing >68% of pricing page visits from mobile in 2026). Horizontal-3-card forces a left-to-right scan at equal weight, suppressing the anchored tier and over-rewarding the cheapest.
- **Cal AI's horizontal-3 was an iteration outcome**, not a load-bearing pattern. Cal AI tested 160+ unique paywall designs across 424 variants ([Superwall Cal AI case study](https://superwall.com/case-studies/cal-ai)); 3-card horizontal won *for them* with their specific copy, anchor savings, and lifetime tier. The pattern is post-hoc traceable to *their* funnel, not transferable as default.
- **iPhone 13 mini math kills horizontal anyway** — at 720pt usable, 3-cards-horizontal needs ~140–160pt height per card to display tier name + price + savings + trial line + selection chrome. That eats 160pt that vertical stacks can express in 3 × 60–80pt rows (~210pt total but each row is fully legible).

---

## Q2 — Quarterly as "best value" recommended: validate or push back?

### Verdict: **Validate. With a caveat that this is a deliberate LTV-for-conversion trade and you should be eyes-open on it.**

The founder's instinct to anchor Quarterly is unconventional in the fitness genre (where Annual is the orthodox anchor) and unconventionally *right* for this specific cohort. Three independent lines of evidence converge.

**1. Goal-horizon math favors Quarterly for half the cohort.**

The product-level goal-aware logic already pre-selects Quarterly for ≤12wk goals. Onboarding v2 captures the goal horizon explicitly. For a user whose stated goal is 8–12 weeks (modal for TikTok-acquired Gen-Z weight-loss cohorts per the v1 brief's audience reference), Annual is **6× her stated horizon**. Anchoring Annual visually for that user reads as "this app doesn't believe my timeline." Quarterly anchored reads as "this app sized the commit to my actual goal." That's a trust lift that compounds with the post-Ozempic permission frame the brand voice is already using.

**2. Center-stage effect favors the middle tier mechanically.**

The center-stage research is unambiguous: consumers default-pick the middle option from a 3-option set both because of an a-priori belief that the middle is the "popular / safe" choice and because it serves as a herd-following social cue ([Kent Hendricks](https://kenthendricks.com/center-stage-effect/), [coglode](https://www.coglode.com/research/centre-stage-effect)). Anchoring the middle option ("Most Loved" / "best for your goal") *enhances* the effect; the middle option is a default winner unless you actively fight it. Annual being in the middle is the orthodox setup (e.g., Nebula's decoy) — but if Quarterly is the middle, Quarterly inherits the center-stage advantage. That is exactly the mechanic the founder is implicitly leveraging.

**3. Lower-anchor LTV trade is conscious and defensible.**

You will leave money on the table on the high-LTV cohort that would have bought Annual. That is real. But [Adapty 2026 H&F benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) data shows annual subscribers retain at 2.5× the rate of monthlies at 12 months (44.1% vs. 17.5%) — and Quarterly sits at ~28–33% retention at 12 months (interpolated; Quarterly is under-reported in the public data). The LTV-per-paying-user gap is closer to ~1.5× Annual vs. Quarterly, not 6× the price ratio would suggest. If anchoring Quarterly lifts paid conversion **20–30%** (which is the typical center-stage anchoring lift band per [DigitalApplied 2026](https://www.digitalapplied.com/blog/subscription-pricing-page-psychology-decision-framework-2026)), the math works out positive on net revenue even at lower per-user LTV — *especially* given the US underconversion gap documented in v1.

**Why anchor Quarterly and not Annual for this specific cohort:**

- US Gen-Z post-Ozempic cohort is showing the lowest trial-start rate in your funnel (7–14% vs. 33–100% elsewhere — per project memory). The dominant hypothesis there is anchor-rejection: Annual reads as "this is going to be another Cal-AI trap, I'm not signing up for a year of nothing."
- Quarterly anchor positions the commit at "I can survive 12 weeks of effort" — exactly the time-horizon every weight-loss research artifact (8–12wk minimum for behavior change per the v1 brief) points to. The plan-length now *matches the goal-length*, which is a coherence signal the cohort has never seen.
- Annual remains visible as the upsell for the 30% of users who self-select longer commitment. Quarterly is the default; Annual is for the believers.

**The caveat: anchored-tier-without-trial is a real friction**, addressed in Q5.

**Push back is light**, not strong: the founder's product instinct here is well-supported. The risk is execution (visual treatment of Annual's trial badge vs. Quarterly's anchor — see Q5), not the strategic call.

### Sources
- [Kent Hendricks — Center stage effect](https://kenthendricks.com/center-stage-effect/) — "three-tier pages convert at roughly 1.4× the rate of two-tier pages"
- [Coglode — Centre-Stage Effect](https://www.coglode.com/research/centre-stage-effect)
- [DigitalApplied 2026 — Pricing Page Psychology](https://www.digitalapplied.com/blog/subscription-pricing-page-psychology-decision-framework-2026)
- [Adapty 2026 H&F benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)

---

## Q3 — Layout proposal (slot-by-slot, pt-explicit)

### Recommended composition: **Layout B-modified — 3-tier vertical with micro-projection chip.**

Total viewport: ~720pt usable on iPhone 13 mini (after 50pt top safe area + 34pt bottom safe area off the nominal 812).

```
┌──────────────────────────────────────────────────┐  iPhone 13 mini, ~720pt usable
│                                                  │
│  topBar (Restore link top-right)         44pt   │
│  ──────────────────────────────────────────────  │
│  HERO eyebrow ("your plan ♥")            18pt   │
│  HERO headline (italic punch, 2 lines)   72pt   │  ← "jen, sized for *your* timeline ♥"
│  ──────────────────────────────────────────────  │
│  MicroProjectionChip                    110pt   │  ← demoted from 260pt; see below
│    "goal by ~Sep 4 · gentle pace"
│    [tiny curve sparkline + date marker]
│  ──────────────────────────────────────────────  │
│  spacer                                  10pt   │
│  PRICING STACK VERTICAL (3 plans)       258pt   │  ← see card breakdown
│    Yearly card (top, 3-DAY FREE badge)  ~76pt
│    spacer                                 8pt
│    Quarterly card (MIDDLE, "most loved") ~90pt   ← visually dominant
│    spacer                                 8pt
│    Weekly card (bottom, low-emphasis)   ~68pt
│  ──────────────────────────────────────────────  │
│  spacer                                   8pt   │
│  trustMicroline                          24pt   │  ← "your data stays yours ♥"
│  CTA "continue ♥" (cocoa pill)           56pt   │
│  legalFooterCompact (Terms · Privacy)    24pt   │
│  ──────────────────────────────────────────────  │
│  TOTAL                                  ~624pt  │  ✅ fits 720pt with ~96pt slack
└──────────────────────────────────────────────────┘
```

### Per-card breakdown (vertical stack)

```
┌────────────────────────────────────────────┐  Yearly — 76pt
│  3-DAY FREE  [pill, top-right]              │  ← trial badge lives HERE
│  Yearly                                     │
│  $47.99/yr  ·  ~$4/mo                       │
│  3 days free, then $47.99/yr · save 52%     │
└────────────────────────────────────────────┘
                  ↕ 8pt
╔════════════════════════════════════════════╗  Quarterly — 90pt  ★ anchored
║  ⭐ MOST LOVED — sized to your goal         ║  ← cocoa accent badge top
║  Quarterly                                  ║  ← stronger border (1.5pt cocoa)
║  $24.99 / 12 wk  ·  ~$2.08/wk                ║
║  no trial · cancel anytime                  ║  ← see Q5
╚════════════════════════════════════════════╝
                  ↕ 8pt
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  Weekly — 68pt  (low-emphasis)
   Weekly
   $5.99 / wk  ·  $311 if you stay all year
   no trial · cancel anytime
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

### Why this geometry

- **Quarterly card is 90pt vs Yearly's 76pt vs Weekly's 68pt** — visual gravity through size, not just badge. The center card is ~18% taller than the flanking cards, which is the threshold where users perceive intentional emphasis without it reading as "this app is shilling" ([learningloop center-stage play](https://learningloop.io/plays/psychology/centre-stage-effect)).
- **Quarterly border at 1.5pt cocoa**, others at 1pt warm-tan — same chrome family, weighted hierarchy.
- **Weekly card uses a dashed border**, lowest visual confidence. Reads as "available if you need it" not "consider this." This is the inverted-Nebula-decoy: Weekly's bad-deal economics ($311 vs $47.99 across the year) make Quarterly read as the smart pick.
- **MicroProjectionChip @ 110pt** keeps the loss-aversion lever from v1 monetization brief without consuming half the viewport. A 110pt chip can show: a tiny sparkline (~60pt wide × 30pt tall), an italic-Fraunces date ("by ~Sep 4 ♥"), a one-line caption ("gentle pace · your timeline"). The full BecomingProjectionCard does its richer job on the plan-reveal screen; the chip is the paywall reminder echo.
- **No 3-row trial timeline.** The trial line is baked into the Yearly card subtitle ("3 days free, then $47.99/yr · save 52%"). This is Apple-2026 compliant after the Cal-AI crackdown ([TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)) — explicit disclosure of charge sequence inline, no toggle, no separate decorative timeline. Saves 88pt.

### Why NOT horizontal 3-across (Layout A)

Per Q1, vertical stacks convert ~30% better than horizontal on mobile, and at 720pt usable the math forces each horizontal card to ~120pt × ~115pt, which doesn't fit Quarterly's emphasis treatment (badge + larger size + thicker border + 2-line subtitle) without truncation. Horizontal-3-across also fights the JeniFit brand chrome (scrapbook 24pt corners + 1.5pt accent borders + hard-offset shadow) — the cards become postage-stamp-sized and the chrome reads as fussy noise.

### Why NOT keep BecomingProjectionCard at full hero (Layout B)

The 260pt projection card + 258pt pricing stack + 56pt CTA + 44pt topBar + 24pt legal + 24pt trustline + 72pt headline + 18pt eyebrow + spacers ≈ 800pt. Overflows on iPhone 13 mini by ~80pt. You'd have to cut either the headline or the trustline or compress the cards below 60pt, and all three of those costs are higher than the cost of downsizing the projection to a 110pt chip. The chip retains 80% of the loss-aversion lever (date + curve + caption) at 42% of the height.

### Why NOT Layout C (kill trial timeline + lift trust line — already done in B-modified)

The 3-row trial timeline is already proposed cut here. The trust microline is already lifted to one line above the CTA. Layout C's specific cuts are subsumed.

### Why NOT Layout D (premium Quarterly + smaller flanking cards)

The asymmetric "one big card + two small flanking cards" pattern is a productivity-app convention (Notion, Linear) that reads as feature-tier comparison (different functionality per tier). For our case where every tier unlocks the same product, asymmetric sizing reads as confusing — "what does Quarterly *do* that the others don't?" Symmetric base sizing with a 14pt height bump on the center card hits the center-stage signal without inviting the "different features?" misread.

---

## Q4 — Quarterly winner visual treatment without nuking Annual

### Recommendation: **Hierarchy through three levers — size, border, badge label — not color or scale-shock.**

The risk is real: if Quarterly is visually overwhelming, Annual looks like a trap (which devalues the higher-LTV tier and pushes the 30% of users who want long commit into "neither feels right" territory). The fix is restrained emphasis.

### Three levers, no more

1. **Size differential**: Quarterly 90pt, Yearly 76pt, Weekly 68pt. The 14pt delta between Quarterly and Yearly is perceptible but not aggressive. (At ~18% larger, the user reads "this is the recommendation" without "this is the only choice.")

2. **Border weight**: Quarterly 1.5pt cocoa (matches the CTA pill color — closes the visual loop), Yearly 1pt warm-tan (brand secondary), Weekly dashed 1pt warm-tan (lowest confidence). Border weight is more legible than fill differences at small scale.

3. **Badge labels**, all reading as descriptors not as orders:
   - Quarterly: **"⭐ MOST LOVED — sized to your goal"** (top-pill, cocoa fill, cream text)
   - Yearly: **"3-DAY FREE"** (top-pill, smaller, warm-tan fill, cocoa text)
   - Weekly: no badge

The Quarterly badge is wider and uses italic-Fraunces — JeniFit's punch-word treatment makes "sized to your goal" the emotional line. The Yearly badge is utility-only ("3-DAY FREE") — useful, factual, doesn't compete emotionally.

### What NOT to do

- **Don't dim Yearly.** Reducing opacity / muting color on Annual makes it look broken. Keep it at full chrome, just smaller.
- **Don't strikethrough Yearly pricing.** Strikethrough is for "compare-to-RRP" not "compare-to-other-tiers." Misreads as "this plan was discontinued."
- **Don't add a "best for power users" qualifier to Yearly.** Power-user framing is alienating for the cohort. Yearly's badge is just the 3-day-free.
- **Don't use green or red anywhere.** Green = MyFitnessPal trial trap, red = bad-on-mobile + diet-shame association.

### Selection state

When the user taps Quarterly (default for ≤12wk goals; tappable for everyone): cocoa interior fill at ~8% opacity + a 24pt checkmark in the top-right pill area. Untapped tiers stay clean. Single selection state, never multi-card glow.

### Sources
- [Coglode Centre-Stage Effect](https://www.coglode.com/research/centre-stage-effect) — emphasis enhances effect, but unactivated middle still wins by default
- [Learning Loop center-stage play](https://learningloop.io/plays/psychology/centre-stage-effect) — visual + label compound the herd-following cue

---

## Q5 — The trial badge problem (Annual has trial, Quarterly is recommended)

### Recommendation: **Badge stays on Annual. Quarterly card carries a "no trial · cancel anytime" microline at the same y-position. Both signals read as honest, not as "Quarterly is worse."**

This is the load-bearing visual tension in the entire layout, and the path through is **transparency, not hierarchy combat.**

### The mechanic

- Yearly's "3-DAY FREE" badge tells the user: this is the lowest-friction entry.
- Quarterly's "no trial · cancel anytime" line tells the user: this is the honest commit, no manipulation.

These two signals fire at different psychological registers. The trial badge says "easy to start"; the no-trial line says "easy to leave." Both reduce friction — one upstream, one downstream. The Gen-Z post-Ozempic cohort has been trained that trials are traps (Cal-AI takedown, MyFitnessPal paywall expansion). For them, "no trial · cancel anytime" reads as **anti-Cal-AI honesty** — a positive signal, not a negative one.

### The Annual trade

The user who would have taken Annual-with-trial because the trial is the no-risk entry will: (a) sometimes upgrade to Annual after starting Quarterly (this is a retention surface play, not a paywall play); (b) sometimes choose Annual anyway because the trial badge nudges them. Both are fine outcomes. The cohort that *wouldn't* have started without a trial is exactly the cohort that center-stage will pull toward Quarterly anyway — because the trial badge on a side-flanking card looks like a feature, not a reason to overrule the middle anchor.

### Microcopy

- Quarterly subtitle: **"$24.99 / 12 wk · ~$2.08/wk · no trial · cancel anytime"** — the "cancel anytime" beats the trial nudge for the cynical cohort, per [Adapty 2026 audit guidance](https://adapty.io/blog/high-performing-paywall-2026/) (reassurance microline as conversion lever).
- Yearly subtitle: **"3 days free, then $47.99/yr · save 52%"** — the "save 52%" carries the value claim, the trial-line carries the friction-removal claim. Both belong in one subtitle, no separate decorative timeline.
- Weekly subtitle: **"$5.99/wk · $311 if you stay all year"** — the "$311 if you stay all year" is the decoy honesty — it makes weekly read as expensive at the same moment quarterly is reading as fair. ([Adapty's Nebula decoy](https://adapty.io/blog/high-performing-paywall-2026/) used 3-month-no-trial as the anti-sell; we use weekly-with-annualized-cost as the anti-sell.)

### Apple-compliance check (post-Cal-AI April 2026)

Quoting [TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/): Apple cited Cal AI because "the paywall displayed the weekly calculated pricing more prominently than the actual amount the user would be billed. It also included a toggle for a free trial that obscured information about the subscription's automatic renewal."

This layout is compliant because:
- The actual billing amount is the largest text in each card ($47.99/yr, $24.99/12wk, $5.99/wk).
- The weekly-equivalent text is smaller, follows the actual price, and includes the annualized total ("$311 if you stay all year") for the weekly tier so the user can't mistake $5.99 for the real cost.
- No toggle. Trial is on a single tier and the disclosure ("3 days free, then $47.99/yr") is inline, not behind a control.
- The "no trial · cancel anytime" line on Quarterly is an explicit no-trial disclosure, not an obscured one.

---

## Q6 — What gets cut to fit

### Rank order of what to sacrifice (sacrifice from the top down if you go over 720pt)

1. **Full 3-row trial timeline (88pt)** — already cut in the proposed layout. The trial line lives in the Yearly card subtitle. This is the highest-confidence cut.
2. **BecomingProjectionCard at full 260pt hero size** — demote to a 110pt MicroProjectionChip. The full card stays on the plan-reveal screen. This recovers 150pt for the 3-tier stack. (Per v1 brief's Q3 — projection's strongest dopamine is on first-render at plan-reveal, not second-render on paywall.)
3. **"see other plans" sheet** — no longer needed; all three are visible. Recovers 24pt for the link row + any associated sheet code.
4. **Eyebrow + headline meta line** — if needed, drop the eyebrow ("your plan ♥") and let the headline carry the identity prime alone. Recovers 18pt.
5. **trustMicroline** — keep at 24pt. This is the privacy-trust signal for the US cohort (per v1 Q8) and removing it costs more than the 24pt it occupies. **Do not cut.**
6. **Sticker decoration** — already at one, ≤0.20 opacity, top-right edge only per v1 brief. **Already minimized; do not cut further.**

### What you cannot cut

- **CTA at 56pt** — the cocoa pill is the conversion surface.
- **Legal footer at 24pt** — Apple-required (Terms / Privacy / Restore link can collapse into top-right but Terms + Privacy must be on-screen).
- **trustMicroline at 24pt** — see above.

### If you overflow despite all cuts

- Compress per-card spacing from 8pt to 6pt (saves 4pt across the 3-card stack).
- Compress the inter-section spacers (hero ↔ chip, chip ↔ stack, stack ↔ trustline) from 10pt to 8pt (saves 6pt across 3 transitions).
- These are the last-resort moves; if you need both, you're 10pt over and something fundamental is wrong (most likely the headline is 3 lines instead of 2).

---

## Q7 — Permission headline: still right, or shift?

### Recommendation: **Shift the framing. Quarterly-anchored requires a goal-timeline headline, not a food-permission headline.**

Current shipped headline (`a8d5fa3`): **"jen, *softer* with food."**

This headline was written for the food-rail paywall thesis (v1.0.7 future state — food + scan + steps). It is **brand-correct** (italic Fraunces punch on *softer*, lowercase, post-Ozempic vocabulary) but **product-misaligned for the current v1.0.6/v1.0.7 surface** which is still primarily a workout + steps + breathwork program (food rail still in planning per project memory).

### Proposed shift

When Quarterly is the anchor, the paywall thesis is **"the plan length matches your goal length."** That demands a timeline-permission headline, not a food-permission headline.

Candidates (italic Fraunces on the punch word, lowercase, hearts allowed):

1. **"jen, sized for *your* timeline ♥"** — direct, matches the Quarterly-anchor logic, italic-punch on "your" (which is the personalization tell).
2. **"jen, *3 months* fits ♥"** — ultra-concise, italic-punch on "3 months" (matches Quarterly's commit length).
3. **"jen, this one *fits* — gentle pace, no shame ♥"** — broader permission frame, italic-punch on "fits," works across goal-horizon defaults.

**My pick: option 1** — "jen, sized for *your* timeline ♥" — because it explicitly maps to the goal-aware logic the founder has already locked, and "your" is the personalization signal that justifies the Quarterly preselect when the user inspects it. It also generalizes cleanly when the goal-aware logic preselects Annual (>12wk goal) — "your timeline" still reads correctly.

### Why NOT keep "softer with food"

- Food rail isn't shipping with v1.0.7 (per [project_food_rail_v3_locked](memory:project_food_rail_v3_locked) timeline — Phase 1 in planning, not in 1.0.7). Promising "softer with food" on a paywall when the food module isn't behind it risks Apple-claim review on "feature not delivered in subscription." See v1 brief's Apple-claim risk warning.
- The food-permission frame is a **2026 H2 paywall headline** for when the food rail ships, not a current-surface headline.
- The shipped headline made sense if the founder's mental model was "v1.0.7 = food paywall" — but the actual ship is "v1.0.7 = workout + steps + trial-week notifications + pricing-locked paywall," with food rail still in plan. The headline should match the SKU.

### Subhead / supporting copy (optional)

If you want a single-line subhead under the headline (~18pt), use: **"gentle pace · ~$2.08/wk · cancel anytime ♥"** — folds the Quarterly economics into the headline-adjacent space so the price-confident user can read the deal without scanning to the card. Skip the subhead if you want maximum headline emphasis; the 18pt save can go to MicroProjectionChip breathing room.

---

## Punch list — what to ship next

| # | change | confidence | effort | est. impact |
|---|---|---|---|---|
| 1 | **3 plans visible, vertical stack, Quarterly center-anchored at ~90pt** | HIGH | M (refactor PricingDrawer → PricingStackVertical3) | center-stage effect anchors Quarterly without nuking Annual |
| 2 | **Demote BecomingProjectionCard to MicroProjectionChip (110pt)** | HIGH | S (new compact component, reuse projection logic) | reclaims 150pt for 3-tier stack |
| 3 | **Quarterly badge "⭐ MOST LOVED — sized to your goal" + 1.5pt cocoa border + 14pt height bump** | HIGH | S (badge component + border weight) | the visual anchor for center-stage |
| 4 | **Yearly retains "3-DAY FREE" pill + trial line inline in subtitle** | HIGH | XS (existing styling, drop separate timeline) | preserves trial path for cohort that wants it |
| 5 | **Weekly subtitle includes "$311 if you stay all year"** as the decoy honesty signal | MED-HIGH | XS | makes Weekly read as expensive at the moment Quarterly reads as fair |
| 6 | **Cut full 3-row trial timeline (88pt → 0pt)** | HIGH | XS (delete) | recovers viewport; trial line lives in card subtitle |
| 7 | **Cut "see other plans" sheet** | HIGH | XS (delete sheet + link) | no longer needed; all visible |
| 8 | **Headline shift to "jen, sized for *your* timeline ♥"** | HIGH | XS (string swap) | aligns with Quarterly-anchor logic + current SKU |
| 9 | **trustMicroline stays at 24pt above CTA** | HIGH | XS (no change) | privacy signal for US cohort, do not cut |
| 10 | **Quarterly "no trial · cancel anytime" microline at same y-position as Yearly's trial badge** | HIGH | XS | resolves trial-vs-recommended visual tension via honesty signal |
| 11 | **Apple compliance: actual billing amount largest text in each card; weekly tier shows annualized cost** | HIGH | XS (typography hierarchy check) | passes post-Cal-AI 2026 review |
| 12 | **Selection state: cocoa fill @8% opacity + 24pt checkmark on tapped card; goal-aware preselect** | HIGH | S (state logic already exists from goal-aware flag) | preserves nudge without railroading |

These 12 items map to a single design pass and a single ship. No A/B experiment required for v1.0.7 launch; the layout decisions are confidence-grounded in 2026 evidence. The locale-aware US-variant experiments from v1 brief (items 5–10 in v1's punch list) still apply as follow-on tests after this layout ships.

---

## What the founder should know before signing off

1. **You are leaving annual-LTV money on the table on purpose.** The user who would have taken Annual-with-trial may now take Quarterly. The math is positive on net revenue **only if** the conversion lift from center-stage Quarterly is ≥18%. Watch the per-user-LTV vs paid-conversion-rate trade in PostHog for the first 30 days post-ship; if Quarterly's mix doesn't lift paid conversion by ≥18%, the LTV trade is net-negative and you should test moving the anchor back to Annual.
2. **You should expect more cancellations during the 7-day window than you saw with Annual-only-trial**, because the cohort that would have churned silently at end-of-trial is now visible on the Quarterly cancel-anytime line. This is a feature, not a bug — those users were going to cancel either way; visible churn is more honest and produces less app-store rage.
3. **The horizontal-3-across layout you may be tempted toward (Cal AI / MacroFactor screenshot mental model) is the wrong execution.** Vertical stack is the right execution. The "3 plans visible" instinct is correct; the layout execution from the apps you've been looking at is misleading for our viewport and our chrome.
4. **The MicroProjectionChip is a compromise.** If you want the full BecomingProjectionCard hero back, you have to cut Weekly from the surface (revert toward the v1 brief's "hide weekly behind a link") to recover the height. That's defensible if you decide the 3-tier center-stage advantage is smaller than the projection card's loss-aversion advantage in your data. I don't think it is, but it's a real tension and you should know you're choosing.

---

## Sources

- [Kent Hendricks — The center stage effect](https://kenthendricks.com/center-stage-effect/) — 3-tier converts 1.4× 2-tier; center-stage default-wins
- [Coglode — Centre-Stage Effect](https://www.coglode.com/research/centre-stage-effect)
- [Learning Loop — Centre Stage Effect play](https://learningloop.io/plays/psychology/centre-stage-effect)
- [DigitalApplied 2026 — Pricing Page Psychology](https://www.digitalapplied.com/blog/subscription-pricing-page-psychology-decision-framework-2026) — 20–30% anchoring lift band
- [Adapty 2026 — High-performing paywall](https://adapty.io/blog/high-performing-paywall-2026/) — Nebula decoy pattern, annual-only-trial guidance, reassurance microline lever
- [Adapty 2026 — Tiered Pricing Strategies](https://adapty.io/blog/tiered-pricing/) — decoy effect, center-stage emphasis, 80%+ of fitness trials are 7+ days
- [Adapty Health & Fitness benchmarks 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) — 60.6% revenue from annual in H&F (2025)
- [theswiftk.it 2026 — SwiftUI paywall best practices](https://theswiftk.it.com/blog/swiftui-paywall-design-best-practices) — vertical stacks convert ~30% better than horizontal on mobile; 68%+ of pricing visits are mobile
- [Superwall — 5 paywall patterns of million-dollar apps](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/) — MacroFactor "Most Popular" on 12-month
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai) — 123 experiments, 3× MRR
- [Superwall — 20 iOS paywalls in production](https://superwall.com/blog/20-ios-paywalls-in-production/) — 17/20 vertical
- [Adapty paywall library — Cal AI](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/)
- [screensdesign — Cal AI breakdown](https://screensdesign.com/showcase/cal-ai-calorie-tracker)
- [TechCrunch — Apple's Cal AI crackdown 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/) — billing-prominence + toggle rejection
- [RevenueCat — R.I.P. toggle paywall](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)
- [Apphud — Best performing paywalls](https://apphud.com/blog/best-performing-paywallls)
- [Stormy AI — Optimizing paywall Superwall 2026](https://stormy.ai/blog/optimizing-paywall-superwall-revenue-increase-2026)
- v1 brief: `docs/paywall_research_ux_2026_06_06.md`
- monetization brief: `docs/paywall_research_monetization_2026_06_06.md`
