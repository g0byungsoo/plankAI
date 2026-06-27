# JeniFit Paywall — UX Research Brief

**Date**: 2026-06-06
**Author**: senior UX research, on commission for founder
**Status**: opinionated brief, evidence-grounded, ready for design pass on v1.0.7

---

## TL;DR — Executive Recommendation

**Keep the two-step pattern. Collapse step 2 to a one-screen vertical stack. Move BecomingProjectionCard out of the paywall entirely. Kill the weekly tier from the surface and stack 2 plans vertically (yearly default, quarterly secondary). Hold the sticker scatter at 0.20 opacity max with one decoration max above the CTA. For the US gap, lead step 1's headline with an anti-Cal-AI permission frame, not a weight-loss promise.**

The founder's no-scroll instinct is correct, but the reason it's correct is not aesthetic — it's that the BecomingProjectionCard is doing duplicate identity-prime work that already happened on the plan-reveal screen, and a 280pt prediction module on a monetization screen is *competing with the CTA for attention*, not helping it. Once you remove that card and drop weekly from the surface, step 2 fits comfortably on iPhone 13 mini at ~640pt with breathing room. The 2-step pattern itself is the highest-leverage thing about the current design and the conversion evidence is overwhelming that it should stay (Claim, Riz, and similar 2-step "commitment → tier" paywalls have shown 20–40% lift on trial starts vs. single-screen pricing-first paywalls — funnelfox, Adapty 2026). What needs to change is what lives on step 2, not whether step 2 exists.

---

## Q1 — Two-step (D78) vs. one-screen collapse

### Recommendation: keep 2-step. Do not collapse.

The 2026 conversion evidence is consistent across Adapty, RevenueCat, and the Superwall case-study library: multi-step paywalls that separate **commitment from tier selection** out-convert single-screen "pricing-first" paywalls by **20–40% on trial starts** ([funnelfox 2026](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/), corroborated by [Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)). The mechanism is well-understood:

1. **Step 1 reduces trial anxiety** before the user is asked to evaluate price. The brain processes "is this risk-free?" and "do I trust this?" in a different decision stack than "yearly or quarterly?". Bundling them on one screen forces simultaneous cognition and the cheap option wins by default (loss aversion + decision fatigue).
2. **Step 2 capitalizes on commitment consistency** — once the user has tapped "continue" on step 1, Cialdini-class commitment-consistency makes them ~2× more likely to complete the purchase even at a higher tier. This is the same mechanism that makes Cal AI's 43-screen onboarding work.
3. **The "trial timeline" pattern (today → day 2 reminder → day 3 charge)** is now the genre standard for Health & Fitness — Cal AI, Omo, Lasta, Simple, MacroFactor, Welling AI all use it ([screensdesign 2026](https://screensdesign.com/showcase/omo-healthy-weight-loss-app)). Removing it costs trial trust; keeping it on step 1 lets you keep step 2 lean.

**Counterargument considered**: Apphud and Qonversion both note that ~50% of top-grossing apps ship 1-screen paywalls and that "multiple-tap flow may cause drop-off." This is true for *productivity* and *utility* apps where there is no identity transformation to sell. For weight-loss apps, where the entire funnel is selling a future self, the commitment-then-tier split is the dominant pattern and the conversion data supports it.

**What the founder's instinct is actually picking up**: not that 2-step is wrong, but that *step 2 is bloated*. That's a step-2 problem, not a step-count problem. See Q2.

### Sources
- [funnelfox — multi-step paywalls (2026)](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/) — 20–40% trial-start lift on multi-step vs. single-screen, citing Claim and Riz.
- [Adapty State of In-App Subscriptions 2026](https://adapty.io/state-of-in-app-subscriptions-report/) — onboarding paywalls with trials are the highest-converting placement at 1.78% install-to-paid.
- [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) — Health & Fitness leads at 2.9% D35 download-to-paid, 37.7% median trial-to-paid.

---

## Q2 — Optimal 1-screen composition for step 2

### The problem with the current step 2 (~840pt)

Current bloat:
| slot | current ht | conversion job |
|---|---|---|
| topBar (Restore) | 44pt | compliance + trust |
| heroCompactV2 | ~110pt | identity prime (duplicate of step 1) |
| reflectedAnswerCaption | ~44pt | personalization echo |
| pricingRowHorizontal (3 across) | ~132pt | tier selection |
| trialOrPlanRecap | ~88pt | trial reassurance (duplicate of step 1) |
| trustMicroline | ~24pt | privacy trust |
| **BecomingProjectionCard** | **~280pt** | **identity prime / loss aversion** |
| ctaButtonV2 | ~56pt | conversion |
| legalFooterCompact | ~24pt | compliance |
| inter-slot spacing (~10pt × 8) | ~80pt | breathing room |
| **total** | **~882pt** | overflows on iPhone 13 mini |

The hero is duplicated from step 1. The trial recap is duplicated from step 1. The projection card is duplicated from the plan-reveal screen. Three of the four hero-class slots are saying things the user already heard. That's not richness, that's noise — and on a monetization screen, every duplicated module steals attention from the CTA.

### Recommended step 2 — one screen, ~640pt total

| slot | ht | rationale |
|---|---|---|
| topBar with "Restore" | 44pt | Apple-required, minimal styling, top-right |
| heroCompactTight (eyebrow + headline only, no meta line) | ~70pt | identity anchor — strip to "pick your *becoming* plan" or "your plan ♥" — meta line lives on step 1 |
| reflectedAnswerCaption | ~36pt | one line: "based on your goal — gentle pace fits in ~14 weeks" — tighten to single line |
| **pricingStackVertical (2 plans)** | **~190pt** | **see Q5** — yearly card 110pt with badge + trial line, quarterly 80pt secondary |
| trialTimelineMicro (3 dots on a horizontal line, ~40pt) | 40pt | replace the 88pt 3-row card with a horizontal mini-timeline since the full version lived on step 1 |
| trustMicroline | ~24pt | "your data stays yours · no ads ♥" |
| spacer + sticker decoration (single, low-opacity, top-right edge) | ~36pt | brand signal, single element |
| ctaButtonV2 "continue ♥" | 56pt | cocoa pill, the only CTA |
| seeOtherPlansLink (text-only, ~24pt, mid-grey) | 24pt | weekly + monthly hidden behind sheet |
| legalFooterCompact | 24pt | compliance |
| inter-slot spacing (8pt × 8) | 64pt | tight but not crammed |
| **total** | **~608pt** | **fits iPhone 13 mini (~720pt) with ~110pt slack for safe area + tab bar** |

**Why this works**:
- The CTA + first plan card both fit above 380pt — phone-fold "above the fold" on every device JeniFit supports.
- We keep one identity prime (the eyebrow + headline) and let the *pricing card itself* carry the rest of the value — that's what high-performing Adapty paywall library examples do (the price card has the trial messaging baked into it, not a separate 88pt card).
- The mini trial timeline is enough trust signal because the full timeline already ran on step 1. This is the commitment-architecture payoff: step 1 takes the trust load so step 2 can be lean.
- "see other plans" link is a transparency signal that satisfies Apple's "all plans available" expectation without giving the weekly tier visual real estate it doesn't deserve. ([Apphud 2026](https://apphud.com/blog/best-performing-paywallls) explicitly cites this hide-monthly-behind-link pattern as a conversion lever — improved yearly subscriptions by showing only yearly by default.)

### Sources
- [Adapty paywall library](https://adapty.io/paywall-library/) — concrete evidence that high-performing vertical pricing stacks anchor under ~600pt.
- [Apphud — best performing paywalls](https://apphud.com/blog/best-performing-paywallls) — the "see all plans" hide-monthly pattern as conversion lever.
- [Adapty 2026 high-performing paywall](https://adapty.io/blog/high-performing-paywall-2026/) — audit checklist explicitly includes "does the paywall fit on a single screen without scrolling?" as best practice.

---

## Q3 — BecomingProjectionCard — move it off the paywall

### Recommendation: remove from paywall entirely. Keep on plan-reveal screen.

This is the single biggest layout-cost change in the brief. **A 280pt module on the paywall is non-negotiably the largest non-CTA slot, and it is doing identity-prime work that already ran on the preceding plan-reveal screen.**

The research on identity-prime and projection charts in weight-loss onboarding is consistent: the projection is most powerful when it's the **first time the user sees their personalized outcome bound to a date**. That is exactly what the plan-reveal screen does. Showing it again on the paywall:

1. **Halves the dopamine spike** — repeated exposure to the same projection within 60 seconds shows familiar-novelty decay (well-documented in advertising research; the "Omo dynamic projection" works precisely because each onboarding answer *changes* the projection, not because it's repeated).
2. **Steals viewport from the CTA** — 280pt on a 720pt screen is 39% of usable height. That space pays better as breathing room around the CTA than as a redundant module.
3. **Risks Apple-compliance flagging** — if the projection chart on the paywall implies a specific weight-loss outcome paired with a price, Apple's 2026 health-claim review (post-Cal-AI crackdown, [TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)) is now actively flagging paywall designs that conflate guaranteed outcomes with subscription pricing. The plan-reveal screen is a safer surface because it's not a payment surface.

**What about loss aversion?** The argument for keeping it is "the user has to imagine giving up their future self if they don't subscribe." This is a real psychological lever — but it's already operating from the plan-reveal screen sitting in working memory ~30 seconds earlier. The lift from a *second* projection is small and the cost (40% of viewport, scroll-forcing) is large. Move the lever to step 1's hero copy instead: "your *weight-loss story* starts today" already does identity-prime work; reinforce that line, don't re-render the chart.

**If you must keep something projection-shaped on the paywall**: replace with a single-line "gentle pace · goal by [month]" caption inside the yearly plan card (or as the reflectedAnswerCaption). That's a 0pt-cost echo of the projection without re-rendering the chart.

### Sources
- [TechCrunch — Apple's Cal AI crackdown 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/) — Apple is now actively flagging paywall patterns that mislead, including outcome-paired pricing displays.
- [screensdesign — Omo teardown](https://screensdesign.com/showcase/omo-healthy-weight-loss-app) — dynamic projection works *during* onboarding because each answer changes it; static repeat on paywall is identity-prime decay.

---

## Q4 — Rank-ordered slot impact

For TikTok-acquired Gen-Z women, 22–35, post-Ozempic + Cal-AI-trained, on the JeniFit paywall:

| rank | slot | conversion impact | keep? |
|---|---|---|---|
| 1 | **Yearly plan card with 3-day trial badge + anchored savings** | HIGH — this is the *only* slot that exists to convert. | KEEP |
| 2 | **CTA pill "continue ♥"** | HIGH — cocoa-near-black, 56pt tall, single CTA, no competition | KEEP |
| 3 | **Trial timeline (full on step 1, mini on step 2)** | HIGH — addresses the #1 cancellation anxiety in 2026 Gen-Z data (55% of 3-day-trial cancels happen Day 0, per RevenueCat 2026 — pre-charge anxiety is the dominant decision). | KEEP (split across steps) |
| 4 | **Hero headline (italic-Fraunces punch word)** | MEDIUM-HIGH — identity prime, brand signal, also the "I trust this app" tell | KEEP (compact) |
| 5 | **reflectedAnswerCaption** | MEDIUM — personalization signal; the difference between feeling generic and feeling seen | KEEP (one line, not two) |
| 6 | **trustMicroline "data stays yours"** | MEDIUM — for Gen-Z women specifically, privacy concern is the #1 AI-app friction at 55% ([Glofox 2026](https://www.glofox.com/blog/ai-in-fitness-statistics/)). Keep as a single thin line. | KEEP |
| 7 | **Quarterly plan card (secondary)** | MEDIUM — gives the goal-aware default somewhere to live; absent of it, the goal-aware-default logic doesn't have a UI to express. | KEEP |
| 8 | **Restore link (top-right, tertiary styling)** | LOW-MEDIUM — Apple-required, near-zero conversion contribution but compliance-blocking if missing | KEEP (compliance) |
| 9 | **Legal footer** | LOW | KEEP (compliance) |
| 10 | **Sticker decoration (single, low opacity, edge)** | LOW-POSITIVE — earns its keep on a coquette brand if held to ONE element at ≤0.20 opacity | KEEP (singular, restrained) |
| 11 | **"see other plans" link** | LOW-POSITIVE — gives the weekly tier somewhere to exist without competing with yearly | KEEP (low-emphasis) |
| 12 | **BecomingProjectionCard** | NEGATIVE on paywall (positive on plan-reveal) — duplicate identity-prime, viewport-stealer, Apple-risk | **CUT** |
| 13 | **Step-2 hero meta line** ("5 min/day · gentle pace · 3-day commit") | LOW (duplicate of step 1) | **CUT from step 2** (keep on step 1) |
| 14 | **Full 3-row trial timeline on step 2** (already ran on step 1) | LOW (duplicate) | **CUT from step 2** (replace with 40pt micro-timeline OR bake into yearly card) |
| 15 | **Weekly plan card (3rd surface tier)** | NEUTRAL-NEGATIVE — decision-fatigue, cheapest-anchor downshift risk; better as link | **CUT from surface, behind "see other plans"** |

### Benchmarks behind the ranking
- RevenueCat 2026: ≤4-day trials cancel 25.5% trial-to-paid vs. 17–32 day trials at 42.5%. Day 0 is decisive — paywall must address pre-charge anxiety.
- Adapty 2026: Health & Fitness apps win most often on **localized pricing tests (62.3% LTV win rate)** — pricing presentation > visual design for conversion lift.
- Health & Fitness category: **60% of paywalls use 2-tier**, only 20% use 1-tier, 20% use 3+ ([RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/)). 2-tier surface is the modal pattern.
- Glofox 2026: only 33% of Gen-Z trust AI fitness apps; privacy at 55% is the top concern. The trustMicroline punches above its 24pt weight for this cohort.

---

## Q5 — Visual hierarchy on the tier row

### Recommendation: kill the 3-across horizontal row. Stack 2 plans vertically. Move weekly behind "see other plans."

The 3-across horizontal pattern fights the brand and the genre. Specifically:

1. **Mobbin + Adapty 2026 paywall library shows vertical-stack dominance** for weight-loss apps. The horizontal-3-across row is a productivity/utility pattern (Notion, Bear, Things — where features differ between tiers). For weight-loss, where every tier unlocks the same product and the only differences are *commitment + price*, vertical stacks are universal — Omo (3-stack vertical), Lasta (3-stack vertical), Cal AI (vertical), MacroFactor (vertical), Yazio (vertical), Simple (vertical) all use vertical. Horizontal-3-across is, in this category, *off-genre* (Superwall's [20 iOS paywalls](https://superwall.com/blog/20-ios-paywalls-in-production/) — 17 of 20 use vertical, none of the health/fitness examples use horizontal-3-across).
2. **3-across at 132pt is the worst of both worlds** — it's too short to give the yearly card the visual gravity it needs (the badge + strikethrough + trial line + popular pill don't have room to breathe at ~110pt × ~110pt) and it forces the weekly tier into equal real-estate with the most valuable tier. The user's eye scans left-to-right at equal weight; you've given the cheapest option the same weight as the most valuable, and Gen-Z post-Ozempic cohorts ([RevenueCat US/Asia gap](https://www.revenuecat.com/state-of-subscription-apps/)) default-pick the cheapest when given equal-weight options.
3. **Killing weekly from the surface is the highest-leverage pricing-presentation change available.** [Apphud 2026](https://apphud.com/blog/design-high-converting-subscription-app-paywalls) and the [RevenueCat guide](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps/) both cite the same pattern: "hiding the monthly plan behind a 'View all plans' link, showing only the yearly plan by default" measurably improves yearly subscriptions. For JeniFit's specific case where weekly is the abandon-floor tier (no downsell, no trial), surfacing it on the paywall actively suppresses yearly + quarterly conversion. Put it behind "see other plans."

### Recommended vertical stack

```
┌─────────────────────────────────────────┐  ~110pt
│  ⭐ MOST POPULAR                         │
│  Yearly                                  │
│  $47.99/yr  ~~$99.96~~  save 52%        │
│  3 days free, then $47.99/yr            │  ← trial line lives IN the card
│  (selected by default if goal > 12wk)   │
└─────────────────────────────────────────┘
                ↕ 12pt
┌─────────────────────────────────────────┐  ~76pt
│  Quarterly                               │
│  $24.99 / 12 wk  ·  $0.30/day            │
│  (selected by default if goal ≤ 12wk)   │
└─────────────────────────────────────────┘
```

Yearly: 1.5pt cocoa border (matches brand chrome) + cream bg, 24pt corners.
Quarterly: 1pt warm-tan border (lower contrast), cream bg, 24pt corners.
Weekly: not on surface. Sub-link below the secondary card: "see other plans" (text-only, mid-grey, 13pt Fraunces-italic, tappable to a half-sheet).

### Goal-aware default surface

The goal-aware default (yearly when goal > 12wk, quarterly otherwise) should be expressed via a single line of **selection chrome** — checkmark inside the selected card, no chrome on the unselected — not via reordering or visual prominence. This way the user sees both options regardless of default and the goal-aware logic is a nudge, not a railroad.

### Sources
- [Superwall — 20 iOS paywalls in production](https://superwall.com/blog/20-ios-paywalls-in-production/) — 17/20 use vertical stack; the horizontal-3-across pattern is rare and over-indexed to productivity apps.
- [Apphud — high-converting paywalls](https://apphud.com/blog/design-high-converting-subscription-app-paywalls) — the "hide monthly behind link" pattern as conversion lever.
- [screensdesign — Lasta + Omo](https://screensdesign.com/showcase/lasta-healthy-weight-loss) — both use vertical 3-stacks with the most-popular highlighted (SAVE 59% / SAVE 75%) — JeniFit's 52% savings copy already aligns with the genre.
- [RevenueCat 2026 plan structure data](https://www.revenuecat.com/state-of-subscription-apps/) — Health & Fitness has the lowest single-tier adoption (20%) and highest 2-tier adoption (60%) of any category. 2-tier surface is the modal pattern.

---

## Q6 — Restore link placement

### Recommendation: top-right of step 2 only. Text-only, 13pt, mid-grey, 44pt hit target. Not on step 1.

Apple requires Restore Purchases on **any paywall** ([Adapty 2026 review guidelines](https://adapty.io/blog/how-to-design-paywall-to-pass-review-for-app-store/)). The placement convention is settled: **top-right corner of the paywall screen**, text-only, low-emphasis, but clearly tappable (44pt hit target per HIG).

**Critical**: it does *not* need to live on both step 1 and step 2. Step 1 in the D78 commitment-architecture pattern isn't a purchase surface (no plans presented, no SKU buyable from that screen) — it's a commitment-priming surface. Apple's expectation is that Restore lives "where users can purchase new subscriptions" ([Apphud 2026](https://apphud.com/blog/restoring-purchases)). Step 2 is that surface. Step 1 having a Restore link is overkill and adds top-bar noise.

If you keep it on both for symmetry, that's fine — it's a minor cost. But if you want to cut something from step 1, this is a safe cut.

**Styling**:
- 13pt Fraunces (matches "see other plans" treatment), color `textTertiary` or `textSecondary`
- Top-right corner, 16pt safe-area inset
- 44pt tappable area (HIG)
- No icon, no chrome, no border
- One subtle helper line in the half-sheet that opens, not on the paywall: "use this if you reinstalled or switched devices."

### Sources
- [Adapty 2026 App Store Review Guidelines checklist](https://adapty.io/blog/how-to-design-paywall-to-pass-review-for-app-store/) — Restore Purchases is mandatory on any paywall.
- [Apphud — restoring purchases](https://apphud.com/blog/restoring-purchases) — placement convention: below or alongside subscribe button; top-right is the dominant 2026 pattern.

---

## Q7 — Brand decoration on the paywall

### Recommendation: hold to one sticker, ≤0.20 opacity, top-right edge only. Cut the other three.

This is the call where the founder's coquette-brand instinct genuinely conflicts with the conversion-screen orthodoxy, and both are partially right.

**The orthodox view (Adapty 2026, Apphud, Qonversion)**: "Ask yourself: does this visual help someone say yes or just take up space?" Decoration on a monetization screen that doesn't carry trust, social-proof, or product information is conversion-neutral at best and conversion-negative at worst (eye-tracking studies consistently show decorative elements pull fixation off CTAs).

**The JeniFit-specific view**: the brand voice signal is part of what makes a Gen-Z TikTok-acquired audience trust the app. Cal AI's paywall is sterile and aggressively monetization-focused; that sterility is part of why the US Gen-Z cohort is now post-Cal-AI cynical (see Q8). For JeniFit, a *single, restrained* coquette signal is differentiation — but four stickers at 0.35 opacity is too much; it competes with hierarchy and reads as "we don't take this screen seriously."

**Calibration**:
- **Single sticker, top-right of the heroCompact area** (one of: flower 3D, iridescent bow, hearts lineart — pick the one that reads cleanest at small size)
- **0.18–0.22 opacity** (currently 0.35 is too loud)
- **Never near the CTA** (CTA gets a 60pt isolation zone — nothing inside it)
- **Never near pricing cards** (pricing reads as expensive if it's surrounded by craft chrome — the "clean luxury" feedback in your memory file applies here)
- **The cocoa pill IS the brand signal** — its color and the italic-Fraunces punch word are doing 80% of the brand work without any sticker

The other three edge stickers should be cut from the paywall. They earn their keep on Home, Becoming, and post-session celebration screens, but not on monetization.

### Sources
- [Adapty 2026 iOS paywall guide](https://adapty.io/blog/how-to-design-ios-paywall/) — "does this visual help someone say yes or just take up space?"
- Your project memory [feedback_clean_luxury_aesthetic.md](memory:feedback_clean_luxury_aesthetic) — "prefer the clean option even over a slightly more discoverable busier one" applies most strongly on monetization surfaces.

---

## Q8 — Recovering the US underconversion gap

The US trials-at-7-14% vs PH/SG/UK at 33-100% gap is real and category-wide, not a JeniFit-specific defect. The 2026 evidence:

- **RevenueCat 2026**: North America runs 2.56% D35 download-to-paid and 34.2% trial-to-paid; IN/SEA runs 1.37% / 15.2% — wait, that's the opposite direction for trial-to-paid. The pattern in *your* data (US underperforms PH/SG/UK on **trial start rate**, not trial-to-paid) is consistent with what Adapty calls "the localized-pricing wedge" — the US is the most price-saturated market on Health & Fitness paywalls (4.4× pricing spread cross-region per [Adapty 2026 H&F report](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)).
- **Glofox 2026 trust data**: only 33% of US Gen-Z fully trust AI fitness apps; 55% cite privacy concerns. PH/SG/UK Gen-Z are markedly more AI-app-trusting (varies by source but 10–25 points higher).
- **MyFitnessPal April-2026 paywall expansion + Cal-AI acquisition + Apple's April-2026 Cal-AI crackdown** ([TechCrunch](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)) all hit the US market in the same 6-week window in spring 2026. US Gen-Z has been **conditioned to expect manipulation** on weight-loss-app paywalls in a way other markets haven't yet been.

### What the paywall can do

**1. Lead step 1's headline with permission, not promise.** Currently: "jen, your *weight-loss story* starts today." This reads as a Cal-AI-class outcome promise to US Gen-Z. For a US-locale variant, test: "jen, you don't have to *earn* this one ♥" or "jen, this one *fits* — no streaks, no shame ♥". The post-Ozempic permission frame is the only paywall headline pattern that US Gen-Z hasn't been conditioned to dismiss.

**2. Move the trustMicroline up.** On the US variant, promote "your data stays yours · no ads ever" from the 24pt thin line at the bottom of step 2 to a 28pt chip immediately under the hero on step 1. This is the explicit anti-MyFitnessPal-data-sale signal that addresses the #1 Glofox 2026 concern (55% privacy).

**3. Anti-Cal-AI positioning, soft.** Don't name-drop. But the language "no calorie shame · no good/bad foods · no streak-loss threats" on step 2 as a 3-row "what's different here" micro-strip (replacing the trial-recap card on the US variant) maps directly to the three things US Gen-Z has been burned by. Estimated ht: 60pt for 3 thin rows.

**4. Pricing presentation, not pricing change.** Adapty's strongest 2026 finding: localized-pricing experiments win at 62.3% LTV-win rate. For the US specifically, **a smaller anchor savings number with a more honest framing outperforms a louder savings claim** when the cohort is Cal-AI-trained. Test "less than $1/wk" framing → wait, that's the Cal-AI compliance trap you already locked against. Better: "fair price for what you're committing to · cancel anytime ♥" as a sub-caption under the yearly card on the US variant.

**5. Closing offer (post-paywall abandon, NOT on the paywall surface).** Per [Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/), 24-hour post-paywall offers convert 12–20% of abandons without devaluing the primary CTA. You already have tier-matched downsells locked for annual + quarterly. The US-specific opportunity is to lead the downsell with "we know you've been burned before — here's $X off" — explicit acknowledgement of the cynicism floor.

**6. Don't drop pricing on the US.** The temptation is to test lower-anchor pricing for the US given the gap. Adapty 2026 H&F data is unambiguous: **high-priced apps earn 4.5× the LTV of low-priced apps in Health & Fitness**. Dropping the US anchor would catch more trials but compound the LTV problem. The right lever is permission framing + privacy signal + closing offer, not anchor reduction.

### Sources
- [TechCrunch — Apple's Cal AI crackdown 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)
- [Glofox — AI in Fitness Statistics 2026](https://www.glofox.com/blog/ai-in-fitness-statistics/) — 33% Gen-Z trust, 55% privacy concern
- [Adapty Health & Fitness 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) — 4.5× LTV for high-priced, 62.3% LTV win rate on localized-pricing tests
- [TechCrunch — MyFitnessPal acquires Cal AI 2026-03-02](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/)
- [The Nutrition Magazine — MyFitnessPal paywall changes](https://thenutritionmagazine.com/articles/myfitnesspal-paywall-changes-explained/) — April 2026 paywall expansion fueled US cynicism

---

## What to ship next (ranked by impact)

| # | change | est. lift | effort | confidence |
|---|---|---|---|---|
| 1 | **Remove BecomingProjectionCard from step 2** (keep on plan-reveal) | reclaims 280pt + reduces Apple-claim risk | XS (delete + verify spacing) | HIGH |
| 2 | **Vertical-stack pricing, 2 tiers on surface, weekly behind link** | 10–20% lift on yearly mix (Apphud "hide monthly" pattern) | S (refactor PricingRowHorizontal → PricingStackVertical + add sheet) | HIGH |
| 3 | **Compact step 2 to fit ~640pt no-scroll on iPhone 13 mini** | removes scroll affordance, sharpens CTA prominence | S (slot reductions per Q2 table) | HIGH |
| 4 | **Reduce sticker scatter to 1 element, ≤0.20 opacity, top-right only** | conversion-neutral to small-positive, brand-aligned | XS (asset opacity + remove 3 stickers) | MED |
| 5 | **Move trustMicroline up to step 1 hero area as a US-variant chip** | addresses 55% privacy concern for US cohort | S (string + layout) | MED-HIGH for US, MED globally |
| 6 | **Replace step 2's full trial-recap card with a 40pt mini-timeline OR bake trial line into yearly card** | reclaims ~50pt, lets yearly card carry trial trust | S | MED-HIGH |
| 7 | **Restore link: text-only top-right step 2, 13pt mid-grey, 44pt hit target** | compliance + minor noise reduction | XS | HIGH (compliance) |
| 8 | **US-only step 1 headline variant: permission framing** (RevenueCat audience filter or Superwall locale rule) | speculative 5–15% on US trial start | M (variant infra + copy + A/B) | MED, needs test |
| 9 | **US-only "what's different here" 3-row strip on step 2** (anti-Cal-AI positioning, no name-drop) | speculative 3–8% on US trial-to-paid | M (locale gate + new component) | MED, needs test |
| 10 | **Closing offer (post-abandon, 24h, tier-matched, lead with "you've been burned" copy) — US variant** | 12–20% recovery of abandons (Adapty 2026) | M (already half-built per downsell SKU work) | HIGH on mechanism, MED on copy |

The first 4 items are the no-regret pass — they validate the founder's no-scroll instinct, reduce viewport bloat, and align with both 2026 conversion evidence and the brand voice. They can ship in v1.0.7 without an A/B. Items 5–10 are sequenced as locale-aware experiments that should flag-gate via Superwall or the existing RevenueCat offering layer.

---

## Sources

- [Adapty — State of In-App Subscriptions 2026](https://adapty.io/state-of-in-app-subscriptions-report/)
- [Adapty — High-performing paywall 2026](https://adapty.io/blog/high-performing-paywall-2026/)
- [Adapty — Health & Fitness app subscription benchmarks 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)
- [Adapty — Paywall library](https://adapty.io/paywall-library/)
- [Adapty — iOS paywall design guide](https://adapty.io/blog/how-to-design-ios-paywall/)
- [Adapty — App Store Review Guidelines 2026](https://adapty.io/blog/how-to-design-paywall-to-pass-review-for-app-store/)
- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/)
- [RevenueCat — Guide to mobile paywalls](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps/)
- [RevenueCat — 5 overlooked paywall improvements](https://www.revenuecat.com/blog/growth/paywall-conversion-boosters/)
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai)
- [Superwall — 20 iOS paywalls in production](https://superwall.com/blog/20-ios-paywalls-in-production/)
- [Apphud — Best performing paywalls](https://apphud.com/blog/best-performing-paywallls)
- [Apphud — How to design a high-converting subscription paywall](https://apphud.com/blog/design-high-converting-subscription-app-paywalls)
- [Apphud — Restoring purchases](https://apphud.com/blog/restoring-purchases)
- [Qonversion — Anatomy of paywall](https://qonversion.io/blog/how-to-design-paywall-that-converts)
- [funnelfox — Effective paywall screen designs](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/)
- [Airbridge — Paywall conversion structural decisions](https://www.airbridge.io/en/blog/paywall-conversion-structural-decisions)
- [Stormy AI — 0.5% to 8% paywall guide](https://stormy.ai/blog/app-paywall-onboarding-optimization-guide)
- [screensdesign — Omo teardown](https://screensdesign.com/showcase/omo-healthy-weight-loss-app)
- [screensdesign — Lasta teardown](https://screensdesign.com/showcase/lasta-healthy-weight-loss)
- [TechCrunch — Apple's Cal AI crackdown 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)
- [TechCrunch — MyFitnessPal acquires Cal AI 2026-03-02](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/)
- [The Nutrition Magazine — MyFitnessPal paywall changes](https://thenutritionmagazine.com/articles/myfitnesspal-paywall-changes-explained/)
- [Glofox — AI in Fitness Statistics 2026](https://www.glofox.com/blog/ai-in-fitness-statistics/)
