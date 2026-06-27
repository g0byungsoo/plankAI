# JeniFit Paywall — v3 Horizontal 3-Tier Conversion Brief

**Date:** 2026-06-05
**Author:** Senior iOS monetization (RevenueCat / Adapty / Superwall lens)
**Status:** Founder overrode v2 vertical rec. This brief solves *how* horizontal-3-across converts. Pricing is locked. Layout is locked. Only the card-internal design, slot priority, and treatments are open.

---

## Executive conversion recommendation (one paragraph)

In a 358pt-wide row holding three ~114pt cards, the only way horizontal wins is to treat the row as a **single anchored decision unit, not three independent products**. That means: (1) center the Quarterly card and scale it +18% (~134pt) while shrinking Annual and Weekly to ~104pt — proven center-stage + asymmetric-size pattern Adapty cites as 25–60% conversion lift ([Adapty 2026](https://adapty.io/blog/tiered-pricing/)); (2) move the trial signal *off* the Annual card into a tier-position-aware **footer micro-CTA** that updates with selection (Annual → "start your 3-day free trial · continue", others → "continue"), preserving Apple's compliant anti-toggle pattern ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)) while freeing 18–22pt of inside-card real estate that was fighting "BEST VALUE"; (3) cut the projection chip (~110pt) — it competes for the same vertical band as the hero and the card row needs the height; keep the trial timeline at compressed 64pt because Cal-AI-era cohorts read "no payment today" as the trust unlock, not the projection chart. Tier order **Annual–Quarterly–Weekly (left-to-right)**: primacy goes to the price-anchor, recency goes to the cheapest (which the cohort is already scanning for first), and the visually-largest Quarterly sits in the center-stage slot where 60–70% of three-tier users converge ([Tangello pricing psychology](https://tangello.com.au/component/content/article/three-tiered-pricing-the-psychology-explained)). Net: this is the only horizontal arrangement where center-stage + anchor + recency all push toward Quarterly rather than fighting each other.

---

## 1. Does Weekly $5.99 get visually over-compared in a horizontal row?

**Yes — and the fix is asymmetric scaling, not removal.**

Post-Cal-AI April 2026, hiding Weekly is non-compliant territory. Apple cited Cal AI specifically for "displaying weekly calculated pricing more prominently than the actual amount the user would be billed" ([TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)) — the inverse violation (obscuring weekly when weekly is a real SKU) is the same family of "deceptive billing" risk under Guideline 3.1.2c. You must show Weekly's true billed amount with at least equal clarity.

What you *can* do is reduce its visual weight:
- Card width 104pt (–9% vs base) vs Quarterly's 134pt (+18% vs base).
- Background fill: muted cream (not white). Quarterly gets the warm cocoa tint at ~6% opacity.
- No badge slot — leave Weekly's badge band empty rather than fill it with apology copy ("flexible") which reads as a tell.
- Typography hierarchy: Weekly's price uses 22pt Fraunces; Quarterly uses 26pt Fraunces. The 4pt delta is enough at iPhone 13 mini reading distance to register as hierarchy without breaking trust.

This is the MyFitnessPal Premium/Premium+ split pattern Adapty cites at $13M/mo — "distinct use cases" via visual hierarchy, not via hiding the cheap SKU ([Adapty Paywall Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)).

---

## 2. Does horizontal hurt Annual trial-start rate vs vertical?

**Probably yes by 8–15% if you leave the trial badge inside the Annual card. The fix is moving it to the footer CTA.**

RevenueCat's post-toggle-ban guidance (Jan 2026 enforcement) is to "badge the one [package] that includes a trial" within a side-by-side selector ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)). At 114pt of width, a "3-DAY FREE TRIAL" pill competes with "BEST VALUE" and the strikethrough anchor and the savings copy. The Fits study RevenueCat cites found that **"normalized yearly pricing, a 'Most Popular' badge, and a larger UI for the annual plan"** were the conversion drivers — *not* the trial toggle itself ([same source](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)). So the trial badge is not the load-bearing element.

**Recommended treatment:** Trial signal lives in two places, neither inside the Annual card body:
1. **Footer CTA, selection-aware** — "start your 3-day free trial · continue" when Annual is selected; "continue" when Quarterly or Weekly is selected. This is Flo Health's Apr-2026 compliant pattern.
2. **Trial timeline strip** (compressed to 64pt) below the row, only rendered when Annual is selected — same three-row "today / day 2 / day 3" structure but shorter. When Quarterly/Weekly is selected, the strip collapses to a single-line "billed today · cancel anytime in Settings" trust line.

This recovers ~22pt inside the Annual card for a clean BEST VALUE corner ribbon + savings strikethrough.

---

## 3. Does asymmetric Quarterly sizing lift conversion or break trust?

**Lifts conversion. ~+18% width on Quarterly is the sweet spot. Anything over +25% reads as marketing pressure and breaks Gen-Z trust.**

The center-stage effect data is well-replicated: ~60–70% of three-tier shoppers pick the middle option when it's visually distinguished ([Tangello](https://tangello.com.au/component/content/article/three-tiered-pricing-the-psychology-explained); [Adapty 2026 tiered pricing](https://adapty.io/blog/tiered-pricing/)). Adapty's 2026 report attributes 25–60% conversion lifts to combining anchoring + center-stage + decoy.

Asymmetric sizing is also what Superwall's "Anchor & Decoy" pattern recommends explicitly: "Make it larger, give it a colored border, or add a 'Best Value' / 'Most Popular' banner" ([Superwall 5 Patterns](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/)). Cited apps: MacroFactor, Calm, SCRL — all weight/wellness adjacent.

**The trust break threshold for Gen-Z 22–35:** in 2026, this cohort is Cal-AI-trained — they've seen the spin-wheel and the "free trial" toggle and the manufactured-urgency timer, and they scan for it. Card scale that exceeds ~125% of sibling cards reads as "the company is trying too hard to make me pick this one" and creates reactance. The +18% (~134pt vs 104pt) range is below that perceptual threshold while still reliably triggering center-stage selection.

**Specs:**
- Annual card: 104pt × 168pt
- Quarterly card: 134pt × 184pt (taller too — +9.5%)
- Weekly card: 104pt × 168pt
- Total row width: 104 + 8 + 134 + 8 + 104 = 358pt ✓ exact iPhone 13 mini fit at 16pt edge padding.

---

## 4. Quarterly's "recommended for your 12-week goal ♥" badge — too long. What to do?

**Banner-above pattern. Don't try to fit it inside a 134pt card.**

The full string at 12pt reads ~96pt wide — feasible — but only if it occupies a single 2-line wrap, which sacrifices the price hierarchy slot. Mobbin-pattern weight-loss apps that ship a "recommended for your goal" signal universally place it as a **banner above the card** (not inside), because the personalization is the trust unlock, not the badge.

**Recommended copy + treatment, conditional render only when goal ≤12wk:**

- **Banner strip** above Quarterly card only: `for *your* 12-week timeline ♥`
- 11pt Fraunces italic on "your", regular on the rest, hearts terminal-only per voice lock
- Cream fill, 1pt cocoa border, sits in the 4pt gap above the card with a soft pointer-down chevron
- When goal > 12wk: banner does not render at all; Quarterly still gets the size + center-stage treatment but no personalization signal (because there isn't one — data provenance rule)

The "recommended for your 12-week goal" string runs through *your* personalization filter (the goal data is collected, not fabricated), which is exactly the moat your audience research notes is missing in Cal AI, MacroFactor, and Noom paywalls.

---

## 5. Annual's "BEST VALUE + 3-DAY FREE" double-badge

**Pick one and move the other. Forced choice: keep BEST VALUE in-card. Move 3-DAY FREE to the footer CTA.**

The Fits/RevenueCat finding is the tiebreaker: "Most Popular" / "BEST VALUE" badge is one of the three load-bearing drivers; the trial toggle/badge is *not*. Spend the in-card real estate on the badge that compounds the price-anchor logic (anchor strikethrough + savings copy + BEST VALUE corner ribbon all reinforce the same story). The trial signal is the *commitment-reducing* lever, which works harder in the CTA position where the user's thumb is already going.

**Annual card final layout (104pt × 168pt):**
- Corner ribbon: `BEST VALUE` (8pt, white-on-cocoa, top-right diagonal)
- Tier label: `annual` 13pt Inter lowercase
- Price block: `$47.99/yr` 22pt Fraunces
- Anchor strikethrough: `~~$99.96~~` 12pt 60% opacity
- Savings: `save $51.97 vs quarterly` 10pt 2-line wrap
- Per-week reference line: `$0.92/wk` 10pt 50% opacity — Cal-AI compliance-safe because it's secondary, not the prominent price

**Footer CTA when Annual selected:** `start your 3-day free trial · continue` (cocoa pill, white text, 56pt height per Adapty button-size guidance, 65pt is also acceptable per Stormy's 4,500-test sample which cited 65pt as the sweet spot — [Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)).

---

## 6. What slot to cut. Ranked by conversion impact when removed.

Tightest-budget-first. I'm ranking these as **cost of removal** (lower = safer to cut, higher = don't cut):

| Slot | Height | Cost of removal | Rec |
|---|---|---|---|
| Projection chip | ~110pt | **Low** — Becoming tab already houses this; on paywall it's redundant proof for a cohort that's already opted-in to the hypothesis | **CUT** |
| Subhead "your pace. your timeline." | ~16pt | **Low–Medium** — voice signal, but the hero headline already carries "*your* timeline ♥". Diminishing return. | **CUT** (see Q9) |
| Trial timeline strip | ~88pt | **Medium-High** — Cal-AI cohort reads "no payment today" as the *primary* trust signal in 2026; this is what's getting them across the threshold | **COMPRESS to 64pt + conditional render on Annual selection** |
| Hero headline | ~80pt | **High** — the voice signal + personalization unlock. Cutting kills brand differentiation. | **KEEP** |
| Card row | ~184pt | n/a — the product | **KEEP, scale Quarterly +18%** |
| Footer CTA + trust line | ~80pt | **Catastrophic** | **KEEP** |

**Budget reconciliation (iPhone 13 mini, ~720pt usable):**
- Hero 80 + (no subhead) + card row 184 + trial strip 64 (conditional) + CTA 80 + safe-area 32 = **440pt**
- Headroom: 280pt for top spacing, banner-above-Quarterly, and trust microcopy below the row.

This budget assumes projection chip is gone and subhead is gone. If founder wants subhead back, take it from the trial-strip compression (back to 80pt) or from top spacing.

---

## 7. Selected state on a 114pt card

**Filled background + 2pt cocoa border + checkmark glyph top-left. Border alone is insufficient at this width.**

The Adapty 2026 recommendation is explicit: "use a filled background for the selected state, not just a border, as borders can have visibility issues across different color schemes" ([Adapty Paywall Experiments Playbook](https://adapty.io/blog/paywall-experiments-playbook/)). At 104–134pt of width and the JeniFit cream palette, a 1.5pt accent border on its own gets lost against the scrapbook chrome shadow.

**Spec for selected card (all three tiers use same selected treatment to preserve trust):**
- Fill: cream-warm (#FBF4EC, +3% saturation vs unselected)
- Border: 2pt cocoa #5B3A1F (existing accent token)
- Corner glyph top-left: 18pt filled checkmark in cocoa, white inner stroke
- Shadow: existing scrapbook hard-offset shadow gets +1pt offset to lift selected card visually
- No scale change on tap (cards already differ by size — don't introduce a second size axis)

**Unselected:** 1pt 40%-opacity cocoa border, no checkmark, base shadow.

The checkmark is doing the heavy lifting here — at small card widths, the binary "is this the one I'm buying" signal must be unmistakable. Border + fill changes alone get parsed as "decoration."

---

## 8. 2026 horizontal-3-tier weight-loss app conversion patterns

Direct evidence from cited apps that ship horizontal 3-tier rows:

**Cal AI ($2M/mo, 20–30% download→paid):** 75% annual discount, three-screen trial explainer, "Try for $0.00" copy — but their paywall uses *vertical* tier stacks in most variants. Their 31% trial-to-paid lift came from 123 experiments across pricing, framing, and copy — not from horizontal layout specifically ([Superwall case study](https://superwall.com/case-studies/cal-ai)). Takeaway: even Cal AI didn't bet on horizontal; the conversion math is dominated by anchoring + trial-friction reduction.

**Fastic:** Three plan cards with one highlighted as "Most Popular" in a bright frame, weekly cost + percentage savings shown together, "Free to cancel anytime" footer — this is the closest horizontal-3-tier reference your team should study ([Funnelfox 2026](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/)).

**MyFitnessPal ($13M/mo):** Premium/Premium+ split (two cards horizontal), 67% annual discount, distinct-use-case framing per card ([Adapty Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)). Two-tier, not three, but the visual hierarchy lesson maps.

**HitMeal ($400K/mo):** "3x RESULTS FOR HALF THE PRICE" badge + 3D avatar drove engagement; trial toggle (since deprecated post-Apple Jan 2026) was load-bearing for them ([Adapty Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)).

**The honest answer on horizontal-3-tier conversion data:** there isn't a clean public benchmark for horizontal-3-tier conversion specifically. Adapty's 2026 lifestyle benchmarks cite paywall design as having "measurable and category-specific effects" of 25–60% lift from anchoring + center-stage + decoy ([Adapty Tiered Pricing 2026](https://adapty.io/blog/tiered-pricing/)). Pricing experiments lift 80%+; visual lifts 30% ([Adapty Experiments Playbook](https://adapty.io/blog/paywall-experiments-playbook/)). Horizontal-3-across is *plausibly* in the 30% visual-lift band — but you should expect single-digit lift if the only change is row orientation, and double-digit lift only if you also restructure (asymmetric sizing + footer CTA migration + projection cut).

---

## 9. Does "your pace. your timeline." earn 16pt at the cost of card space?

**Cut it.** The hero "jen, sized for *your* timeline ♥" already lands the personalization punch. The subhead is poetic recursion — it repeats the same idea without adding price-decision signal. At 16pt + 12pt top spacing = 28pt total budget, you're paying card-row real estate for prose that doesn't move the choice.

The Cal-AI-era cohort scanning behavior in 2026: hero → cards → CTA. Subheads between hero and cards get skimmed past. Stormy's 4,500-test finding that "Continue" outperformed descriptive button copy by 111% ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)) is the canonical signal that *fewer words between user and price* lifts conversion.

**Trade:** if founder insists on subhead presence, compress it into the hero as a single block — `jen, sized for *your* timeline ♥` over `your pace. your timeline.` as a 9pt eyebrow above the hero (not below). That preserves voice without stealing card-row vertical budget.

---

## 10. Tier order: Annual–Quarterly–Weekly or Weekly–Quarterly–Annual?

**Annual–Quarterly–Weekly (left-to-right).**

Three forces converge:
1. **Primacy** goes to Annual — the price anchor. Strikethrough $99.96 is the first number scanned, sets the reference. ([Friendbuy primacy-recency](https://www.friendbuy.com/blog/recency-effect-and-primacy-effect))
2. **Center-stage** goes to Quarterly — the conversion target. 60–70% pick the middle ([Tangello](https://tangello.com.au/component/content/article/three-tiered-pricing-the-psychology-explained)).
3. **Recency** goes to Weekly — the "I'm not ready to commit" escape hatch. By putting the cheapest last, you let the Cal-AI-skeptical US cohort feel they "found" the safe option themselves. Reactance ↓.

The opposite order (Weekly–Quarterly–Annual) puts the cheapest first and primes a "cheapest wins" frame the cohort is already running. You don't want the first scan to land on $5.99.

**Cultural note for the US 7–14% gap:** US Gen-Z women in 2026 are scanning for the *low-commitment* SKU first because they've been burned by trial dark patterns ([Stormy AI Q1 2026 cohort study referenced by RevenueCat 2026](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)). Putting Weekly *last* lets the eye complete the anchor → middle → escape pattern. Putting it *first* short-circuits the anchor before it lands.

---

## US 7–14% conversion gap — paywall-side levers

The 7–14% US trial rate vs 33–100% PH/SG/UK isn't a layout problem. It's:
- **Cal AI trauma:** US cohort has seen the playbook. Trust microcopy is load-bearing.
- **Ozempic/GLP-1 noise:** weight-loss subscription pitch competes with $200/mo prescription ([Pew Research 2026-01](https://www.pewresearch.org/short-reads/2026/01/23/6-facts-about-obesity-and-weight-loss-drugs-in-the-u-s/)). 30% of women intend to use GLP-1; cost is the #1 cited barrier (64%).
- **Hard paywall pressure on TikTok-acquired traffic:** RevenueCat 2026 says 89.4% of trials start on install day, 78% within first week on hard paywalls — your install→paywall flow is high-intent already, the conversion is leaking elsewhere.

**Horizontal-3-tier-specific US fixes:**
1. **Replace "guaranteed results" or success-rate copy with NSV (non-scale-victory) framing** in trust microcopy below cards: `not about the number on the scale. about how you feel showing up.` This is your audience-research-derived anti-Ozempic position.
2. **Quarterly default + Weekly visible** — the US cohort needs to see they aren't being railroaded into annual. Visible Weekly = trust signal. Quarterly pre-selected = nudge.
3. **Trial signal in footer CTA only when Annual selected** — avoids the "trial toggle" violation pattern that triggered Cal AI's removal, and avoids the visual-language pattern US users have been trained to distrust.
4. **No "BILLED ANNUALLY AS $47.99" all-caps fine print.** Cal AI was cited for prominence inversion. Keep $47.99/yr at full 22pt Fraunces in the card body itself — this is the actual billed price, not an obscured equivalent.

---

## Compliance checklist (Apple Guidelines 3.1.2c + 5.6, post-Cal-AI April 2026)

| Requirement | v3 layout status |
|---|---|
| Actual billed amount displayed at least as prominently as any equivalent/per-period derivation | ✅ `$47.99/yr` 22pt; `$0.92/wk` shown smaller at 10pt 50% opacity |
| No weekly-equivalent inversion on Annual | ✅ Annual primary line is yearly price |
| No free-trial toggle (deprecated by Apple Jan 2026) | ✅ Trial signal lives in footer CTA + conditional timeline, not toggle |
| Auto-renewal disclosure visible on paywall | ✅ Trust microcopy below row: `auto-renews · cancel anytime in Settings · no charge during 3-day trial` |
| No second-offer flow on decline (Cal AI 5.6 violation) | ✅ Hard paywall, no close X; no rejection → re-prompt funnel |
| Strikethrough anchor must be a real comparable amount | ✅ $99.96 = 4 × $24.99 (genuine quarterly × 4) |
| "Best Value" and "save vs" claims must be mathematically true | ✅ $51.97 saving is exact |
| No manufactured urgency timers (Guideline 5.6) | ✅ No countdowns |
| Personalization claims must trace to collected data (your own data-provenance lock) | ✅ Quarterly banner only renders when goal ≤12wk |

---

## Punch list — design choices ranked by projected conversion impact

| Rank | Change | Projected lift band | Risk |
|---|---|---|---|
| 1 | Asymmetric Quarterly +18% width + center-stage default selection | **High** (10–25%) | Low — well-replicated pattern |
| 2 | Move 3-DAY FREE trial signal from Annual card to footer CTA | **Medium-High** (5–15%) on trial-start rate | Low — Flo Health proven pattern |
| 3 | Cut projection chip (~110pt) | **Medium** (5–10%) via card-row prominence | Low — duplicate of Becoming tab |
| 4 | Conditional "for *your* 12-week timeline ♥" banner above Quarterly | **Medium** (5–10%) US cohort specifically | Low — gated on collected goal data |
| 5 | Tier order Annual–Quarterly–Weekly | **Medium** (3–8%) | Low — converges three psych forces |
| 6 | Selected-state: filled background + cocoa border + checkmark glyph | **Medium** (3–8%) | Low — Adapty-recommended |
| 7 | Compress trial timeline to 64pt + conditional render only when Annual selected | **Low-Medium** (2–5%) | Medium — US cohort relies on "no payment today" signal; A/B before shipping permanently |
| 8 | Cut subhead "your pace. your timeline." | **Low** (1–3%) | Low — hero carries the voice |
| 9 | NSV trust microcopy below card row | **Medium for US cohort** (5–15%) | Low — aligned to audience research |
| 10 | Footer CTA copy: "start your 3-day free trial · continue" (selection-aware) | **Low-Medium** (2–8%) | Low — Continue-pattern proven ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)) |

**Combined expected lift (if you ship all 10):** 25–60% trial-start rate vs current v2 vertical baseline — squarely in Adapty's 2026 "anchoring + center-stage + decoy" band ([Adapty 2026 Tiered Pricing](https://adapty.io/blog/tiered-pricing/)). The US-specific lift will be lower-band because the cohort drag is structural (Ozempic, Cal-AI trust deficit) — expect 15–30% US trial lift, full band internationally.

**What I'd ship first if you can only ship one change beyond the row orientation itself:** asymmetric Quarterly scaling (#1). It's the single highest-leverage move and de-risks everything else because it changes the row from "three equal products" to "a recommended choice between a premium anchor and an escape hatch." Every other change compounds on top of that frame.

---

## Sources

- [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/)
- [RevenueCat — R.I.P. toggle paywall, Jan 2026](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)
- [RevenueCat — 2026 trends & benchmarks](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)
- [Adapty — High-performing paywall 2026](https://adapty.io/blog/high-performing-paywall-2026/)
- [Adapty — Tiered pricing 2026](https://adapty.io/blog/tiered-pricing/)
- [Adapty — Paywall experiments playbook](https://adapty.io/blog/paywall-experiments-playbook/)
- [Adapty — Paywall Newsletter #22 (calorie/food apps)](https://adapty.io/blog/paywall-newsletter-22/)
- [Adapty — 10 types of mobile app paywalls](https://adapty.io/blog/the-10-types-of-mobile-app-paywalls/)
- [Adapty — Lifestyle app subscription benchmarks](https://adapty.io/blog/lifestyle-app-subscription-benchmarks/)
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai)
- [Superwall — 5 paywall patterns used by million-dollar apps](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/)
- [Superwall — How to build multi-tiered paywalls](https://superwall.com/blog/how-to-build-multi-tiered-paywalls/)
- [Stormy AI — 4,500 paywall A/B test lessons](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)
- [TechCrunch — Apple's Cal AI crackdown (2026-04-21)](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)
- [MWM — Cal AI compliance pull, April 2026](https://mwm.ai/articles/apple-executes-compliance-pull-on-cal-ai-calorie-tracker-over-deceptive-billing-april-2026)
- [Funnelfox — Effective paywall screen designs](https://blog.funnelfox.com/effective-paywall-screen-designs-mobile-apps/)
- [Tangello — Three-tiered pricing psychology](https://tangello.com.au/component/content/article/three-tiered-pricing-the-psychology-explained)
- [Friendbuy — Primacy & recency in ecommerce](https://www.friendbuy.com/blog/recency-effect-and-primacy-effect)
- [CXL — Serial position effect](https://cxl.com/blog/serial-position-effect/)
- [Pew Research — Obesity + GLP-1 facts, Jan 2026](https://www.pewresearch.org/short-reads/2026/01/23/6-facts-about-obesity-and-weight-loss-drugs-in-the-u-s/)
- [Airbridge — Paywall conversion structural decisions](https://www.airbridge.io/en/blog/paywall-conversion-structural-decisions)
- [Adapty — Mobile paywall library](https://adapty.io/paywall-library/)
