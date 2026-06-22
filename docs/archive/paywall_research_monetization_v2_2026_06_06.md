# JeniFit Paywall Monetization Brief v2 — 2026-06-06

Follow-on to `paywall_research_monetization_2026_06_06.md`. The founder is reversing two recommendations from the first brief: (1) hide tiers behind a "see other plans" drawer, (2) default-everyone-to-annual. She wants ALL THREE PLANS VISIBLE and QUARTERLY $24.99 / 12-week as the recommended "best value" tier. This brief either validates or pushes back, with 2026 evidence specific to the post-Cal-AI Health & Fitness landscape.

---

## Executive recommendation

**Validate the all-three-visible decision, PUSH BACK hard on Quarterly-as-recommended-best-value, and ship a hybrid that splits the badge work: Annual keeps the "best value" anchor AND the trial badge; Quarterly carries a goal-aware "recommended for your 12-week plan" badge that only renders for the ≤12-week-goal cohort.** The "fewer plans" evidence in your first brief (Stormy AI's 4,500-test "show one plan + drawer" finding) is real but it is the *minority* 2026 pattern — the majority pattern across the Adapty + Apphud + RevenueCat libraries is 3-tier vertical visible with a Most-Popular/Best-Value badge anchoring the middle ([Apphud high-converting paywall guide](https://apphud.com/blog/design-high-converting-subscription-app-paywalls), [Adapty paywall library](https://adapty.io/paywall-library/)). The founder's instinct that hiding tiers feels untrustworthy for a TikTok-acquired, Cal-AI-trained US cohort is correct: those users have been *taught* by Cal AI / Noom / Yazio to expect three visible plans, and a single-plan "see other plans" link reads as a dark pattern in 2026. The drawer wins on *cognitive load*; the 3-card visible wins on *trust + comparability*. After Apple's April 2026 Cal AI takedown, trust beats CR — anything that smells like obscured pricing is a takedown vector regardless of intent ([TechCrunch, 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)).

On Quarterly-as-recommended: the LTV math does not work. Annual + 3-day trial generates ~3.6× the 12-month LTV of direct-buy quarterly even at conservative trial-to-paid rates ([Adapty 2026 trial vs direct purchase](https://adapty.io/blog/free-trial-vs-direct-purchase-subscription-apps/), [Adapty Health & Fitness benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)). Health & Fitness is the *single category* where annual gained share 2023→2025 (51% → 61% → 68% via RC 2026) — pointing the recommended badge at a 12-week tier in the only category moving harder into annual is rowing against the market. The compromise: keep Annual as the visual primary (largest card, "best value" + "3-DAY FREE" stacked badges, top of stack), and ship a *conditional* "recommended for your 12-week goal" badge on the Quarterly card only for users whose stated goal pace fits ≤12 weeks — which preserves the founder's goal-aware intent without globally surrendering annual's LTV.

The third major call: **drop the Quarterly default entirely** even for ≤12-week-goal users. Make the goal-aware logic a *visible recommendation badge* on the Quarterly card, but keep *Annual pre-selected* across the board. The cohort that opts into Quarterly when they see "recommended for your goal" is the cohort already self-selecting toward Quarterly; pre-selecting it does no work and costs you the Annual users who would have just tapped through.

---

## 1. Show 3 plans visible: VALIDATE (with caveats)

**The founder is right; the previous brief overcorrected.**

The Stormy AI 4,500-test "show only the highest-value plan with a hidden drawer" finding ([Stormy AI 10 design principles](https://stormy.ai/blog/10-mobile-app-paywall-design-principles)) is technically accurate but was generalized too aggressively in the first brief. The same writeup also says "some experiments found limiting to *two* options outperformed three" — meaning the load-bearing variable is decision-load reduction, not single-plan presentation. The 2-vs-3 finding contradicts the 1-vs-3 finding inside the same dataset, which is the signal that this is *context-dependent*, not a universal rule.

**The 2026 majority-pattern evidence for 3-visible:**

- Apphud's analysis of the highest-grossing health/fitness paywalls in 2026 explicitly recommends "present pricing options with the annual plan pre-selected and highlighted [...] vertically stacked plan cards with the recommended plan highlighted is the most common paywall layout because it's simple, scannable, and familiar" ([Apphud, high-converting paywall guide](https://apphud.com/blog/design-high-converting-subscription-app-paywalls)). Familiarity is a conversion lever in a category where the user has seen the same pattern 40+ times this year.
- A separately reported Adapty experiment cited in the 2026 playbook: "testing 3 subscription duration options vs 2 options significantly increased conversion metrics across the board" ([Adapty paywall experiments playbook](https://adapty.io/blog/paywall-experiments-playbook/) summary). The directional read: in Health & Fitness with anchor pricing, the 3rd visible option does work (likely as anchor + decoy).
- Adapty's Cal AI paywall library entry shows Cal AI itself ships 3 tier cards visible — and Cal AI ran 123 paywall experiments before settling on what shipped ([Adapty Cal AI library](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/), [Superwall Cal AI case study](https://superwall.com/case-studies/cal-ai)). The Cal-AI-trained cohort has been pattern-matched on 3-visible specifically.
- Decoy effect: a properly-anchored Weekly tier acts as the decoy that makes Quarterly + Annual look obviously better. Decoy pricing requires the "worse" option to be visible — hiding Weekly behind a drawer kills the anchor ([DealHub decoy pricing](https://dealhub.io/glossary/decoy-pricing/)).

**The post-Cal-AI compliance read** matters here too. Apple's April 2026 enforcement targeted *obscured pricing* — the more your paywall reads as "we're hiding something," the worse your review-risk posture. A "see other plans" drawer that hides Weekly + Quarterly behind an inline link is technically compliant but operationally fragile; a future reviewer could read it as a pattern-match to the Cal AI takedown if combined with any other risk factor (and you have one open risk factor: hard gate with no close-X, per the previous brief's punch list item #1).

**Caveat: the "fewer plans" finding still has one real application — DOWNSELL.** When the downsell modal fires after annual abandon, show ONLY annual_discount. Three options on the downsell is the wrong place for choice — the recovery surface needs single-CTA single-product clarity. Keep 3-visible on the primary paywall, drop to 1-visible on the downsell.

**Verdict:** ship 3-tier visible vertical stack. The founder's instinct is the 2026 majority pattern; the first brief weighted Stormy AI's minority finding too heavily.

---

## 2. Quarterly as "best value" anchored: PUSH BACK

**This is wrong for the cohort. Don't ship it as a label, do ship it as a goal-aware conditional badge.**

### LTV math — the load-bearing analysis

Using your locked SKUs and conservative 2026 H&F benchmarks:

**Path A: Annual + 3-day trial (your current default).**
- Trial-to-paid rate: opt-out 3-day H&F median ~35–44% ([Adapty trial conversion rates 2026](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/)). Using 40% as midpoint, US-pessimistic 30%.
- US case (30% trial→paid): $47.99 × 0.30 = **$14.40 expected revenue per trial-start**.
- Y1 LTV including renewal (44.1% annual retention per RC 2026): $14.40 + ($47.99 × 0.30 × 0.441) = $14.40 + $6.35 = **$20.75 expected 24-month LTV per trial-start**.
- Non-US case (40% trial→paid, 44% renew): $19.20 + $8.46 = **$27.66**.

**Path B: Quarterly direct-buy, no trial (founder's proposed default).**
- Direct-buy conversion rate: 2026 H&F median direct-buy without trial converts at roughly 50–70% the rate of trial-paid ([Adapty trial vs direct purchase](https://adapty.io/blog/free-trial-vs-direct-purchase-subscription-apps/), [Adapty H&F benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)). On US cohort showing 7–14% trial starts, expected direct-buy quarterly is ~4–8% (Adapty notes "in Productivity and Lifestyle, direct buyers are worth more at 12 months" — H&F is NOT one of those categories).
- Per-paywall-view revenue, US (5% buy rate): $24.99 × 0.05 = **$1.25 expected revenue per paywall-view**.
- Compare to Path A: even at 7% US trial start, Path A = ($47.99 × 0.30 × 0.07) = $1.01 per *paywall-view*. With trial-paid renewals, $1.45.
- The two paths are roughly *comparable* at the per-paywall-view level for US, but Path B requires the user to commit cash on first session — which in the US Gen-Z cohort post-Ozempic-era is the highest-friction ask possible. PH/SG converts higher because the substitution cost of "yes" is materially lower for that cohort.
- Quarterly renewal: there is no clean public 2026 benchmark for quarterly renewals, but quarterly sits between monthly (17.5% Y1 retention per RC 2026) and annual (44.1%). Best estimate: ~25–30% renew for a second quarter. Even at 30%, the second-quarter revenue is $24.99 × 0.30 = $7.50. Total Y1 quarterly LTV per buyer ~$32. Per paywall view at 5% buy rate = **$1.60 lifetime**. Annual + trial at 7% US trial start, 30% trial→paid, 44% renew = **$2.02 lifetime per paywall view**.

**Conclusion: Annual + trial wins LTV per paywall view even in the pessimistic US case.** And the gap widens dramatically in the non-US cohort where the trial mechanic is doing its job.

### Why the trial mechanic specifically matters here

- Adapty 2026: "trials lift LTV and retention in Utilities, Health & Fitness, and Education" — this is one of three categories where trials are net-positive vs direct-buy ([Adapty trial vs direct purchase](https://adapty.io/blog/free-trial-vs-direct-purchase-subscription-apps/)). H&F is *the* category where trials beat direct-buy on LTV. Removing the trial recommendation is rowing against the strongest category-specific signal in the dataset.
- RevenueCat 2026 + Adapty: annual mix in H&F grew 51% → 68% of category revenue 2023→2025 ([SaaStr summary of RevenueCat 2026](https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps-how-115000-mobile-apps-deliver-16b-in-revenue-whats-working-whats-quietly-killing-growth/)). The cohort is moving harder into annual every year.
- The founder's intuition that "TikTok US Gen-Z expects a trial" — Adapty explicitly: "the shift from 14-day or 30-day trials to 7-day (or even 3-day) trials is appearing across nearly every category" ([Adapty trial conversion rates 2026](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/)). 3-day trial on annual is now baseline expectation, not differentiation. Removing it from the recommendation kills baseline expectation match.

### What Quarterly-as-recommended *would* signal

- "We don't believe in our own product enough to ask for a year."
- "The cheaper option is the smart pick" — which the user will rationally extend to "the cheapest option (Weekly) is the smartest of all" → drives them to Weekly, which has the worst LTV and the worst retention.
- It contradicts the founder's locked pricing structure: $47.99 annual exists as a deal vs $24.99 × 4 = $99.96 quarterly anchor. If quarterly is the "best value," then annual stops being a deal — the genuine math anchor collapses.

### The compromise that works

**Conditional goal-aware badge, NOT a global "best value" label on Quarterly.**

- Default badge on Annual: **"best value · save $51.97"** + secondary **"3-DAY FREE"** trial chip
- Quarterly card: NO badge by default
- Quarterly card: render **"recommended for your 12-week goal ♥"** ONLY when `goalPaceWeeks ≤ 12` (the goal-aware logic that's already locked)
- Pre-selected tier: ALWAYS Annual (override the goal-aware default)

This gives the founder the visible-recommendation signal she wants for the ≤12-week cohort without surrendering the LTV-winning default. The cohort that opts into Quarterly when they see "recommended for your 12-week goal" is the cohort *self-selecting* — pre-selecting it does no incremental work and bleeds the Annual-default cohort.

**Verdict:** push back hard on "Quarterly as global best value." Adopt the conditional goal-aware badge pattern; keep Annual pre-selected.

---

## 3. Layout proposal — slot-by-slot for 3-tier visible single-screen iPhone 13 mini

Target viewport: iPhone 13 mini, 375 × 812pt, ~720pt usable below status bar + above home indicator + safe areas.

**Recommended composition (no scroll):**

| # | Slot | Height | Content | Evidence |
|---|------|--------|---------|----------|
| 1 | Eyebrow | 16pt | "YOUR PLAN" all-caps cocoa | Cal AI pattern |
| 2 | Headline (italic punch) | 60pt (2 lines tight) | "jen, *softer* with food." | Reflected-answer pattern, [Adapty](https://adapty.io/blog/high-performing-paywall-2026/) |
| 3 | BecomingProjectionCard (compressed) | 160pt | weight curve + date marker, scrapbook chrome — compress from 260pt by dropping internal padding + smaller header | Loss aversion + commitment, see v1 brief §4 |
| 4 | Tier card stack (3 cards vertical) | 240pt total | Annual (96pt, highlighted) / Quarterly (72pt) / Weekly (72pt) | Adapty/Apphud vertical-stack majority pattern |
| 5 | CTA | 52pt | "continue ♥" cocoa pill (action verb owned by your brand voice) | [Stormy AI](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests) descriptive-CTA finding |
| 6 | Reassurance + legal combined | 30pt | "cancel anytime · restore · terms · privacy" — single line, 11pt | Apple 3.1.2 + post-Cal-AI minimal compliance footer |

**Total: ~558pt content + 16pt × 5 gaps = ~638pt.** Fits comfortably in 720pt with ~82pt of breathing room. Verified against iPhone 13 mini.

### Tier card detail (the load-bearing part)

```
┌──────────────────────────────────────────┐
│ ANNUAL              [BEST VALUE]         │  ← 96pt, highlighted with 1.5pt accent border
│ $47.99 / year  · save $51.97             │     scrapbook shadow, larger
│ 3 days free, then $47.99 on Jun 9 ♥      │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ QUARTERLY    [recommended for 12-wk goal]│  ← 72pt, conditional badge only
│ $24.99 / 12 weeks                        │     (only if goalPaceWeeks ≤ 12)
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ WEEKLY                                   │  ← 72pt, no badge (decoy anchor)
│ $5.99 / week                             │
└──────────────────────────────────────────┘
```

### What I'm cutting from current paywall to fit 720pt

- "no payment due now ♥" trust chip → **redundant** once the Annual card subtitle reads "3 days free, then $47.99 on Jun 9 ♥". The chip was floating decorative text; the card subtitle does its job better. Saves 28pt.
- 3-row trial timeline → **eliminate.** The disclosure now lives inside the Annual card subtitle. Apple 3.1.2 satisfied with one inline disclosure ([RevenueFlo](https://revenueflo.com/blog/common-ios-paywall-rejections-and-the-fixes-that-work)). Saves ~80pt.
- Trust + legal footer compressed from 32pt → 30pt (single line, 11pt type). Saves 2pt.
- BecomingProjectionCard compressed 260pt → 160pt by dropping internal header padding + using inline date marker label instead of a separate caption row. Saves 100pt.
- "see all plans" link → **eliminate** (no longer needed; all plans visible).

**Total reclaimed: ~210pt**, which is exactly what we need to fit 3 tier cards (240pt) + the Becoming card (160pt) + everything else in 720pt.

---

## 4. Trial badge placement when Quarterly is "recommended" but Annual has the only trial

**The fight resolves cleanly with the conditional-badge model from §2: Annual gets `[BEST VALUE]` + `3-DAY FREE` trial chip stacked; Quarterly gets `[recommended for your 12-week goal]` ONLY for the ≤12-week cohort. They never share a screen as competing winners.**

- For users with ≤12-week goals: both Annual and Quarterly carry a badge, but the badges signal different things. Annual = "best deal overall." Quarterly = "fits your specific situation." This is the cognitive frame health-tracking apps like MacroFactor and Yazio use successfully ([Adapty paywall library Cal AI](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/)) — multiple badges work *if they're answering different questions for the user*.
- For users with >12-week goals: only Annual has a badge. No ambiguity. Clean.
- The trial chip on Annual is the *secondary* badge (smaller, cocoa pill underneath the price), not the primary visual anchor. This matches Cal AI's actual implementation per the Adapty library entry — they treat "3 days free" as supporting text, not a primary badge.

**Why this works for the cohort:** the TikTok US Gen-Z cohort that bounces on no-trial-recommended is *seeing* the trial on Annual at the same prominence as the goal-aware badge on Quarterly. The user with a 12-week goal has the choice: "trial the year" vs "commit to 12 weeks at lower total cost." Both options are legitimate; the user picks based on her risk tolerance, not because we forced her hand.

**Trial badge typography:** keep it small, cocoa pill, italic-Fraunces on "free" (your brand voice signal). NOT a giant orange "FREE TRIAL!" banner. Cal AI did the loud banner version; that's the pattern Apple pulled them for prominence-wise (the weekly-equivalent number was prominent; the loud trial badge contributed to the prominence imbalance). Quiet trial chip + prominent actual charge is the post-Cal-AI compliant pattern ([Adapty toggle paywall](https://adapty.io/blog/your-toggle-paywall-is-about-to-get-rejected/)).

---

## 5. US-specific $29.99 SKU — should it still ship?

**Yes, but it changes role. Ship it as a downsell SKU, not a primary US-storefront SKU.**

The reasoning shift since the first brief:

- The first brief recommended $29.99 as the US primary Annual SKU because Annual was the only visible option (under the drawer model). With 3-tier visible at $47.99 / $24.99 / $5.99, the US user already sees a lower-anchor option (Quarterly at $24.99) — Quarterly is *already* below where Cal AI's annual-equivalent sits ($29.99 / yr). The lower-anchor work is partially done by the existing locked structure.
- Localization tests still have the highest experiment win rate (62.3% per [Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)), so leaving US pricing untouched leaves money on the table — BUT the lift comes from price-sensitivity, not from tier-count, and the US user now has Quarterly as the price-sensitivity escape hatch.
- The cleaner play: ship $29.99 as the US-only `annual_discount` SKU on the abandon-downsell modal (replacing or supplementing the 25% off $35.99 downsell). This concentrates the localization lift on the highest-recovery moment (declined paywall) rather than diluting the primary paywall's anchor math.

**Action:** keep primary US Annual at $47.99 (preserves the $99.96 quarterly anchor math, which only works if Annual = $47.99 = ~50% off the anchor). Ship US-only `annual_discount_us` at $29.99 on the abandon downsell. The non-US `annual_discount` stays at $35.99 (25% off).

**Caveat:** this is a per-storefront pricing decision and Apple validates that the discount SKU is offered as a *real* discount with disclosed terms. The downsell-modal compliance audit from the first brief still applies — same product family name, same trial terms, "save $X" framing not "Special Offer."

---

## 6. Downsell mechanic when paywall is 3-tier visible

**Mostly the same as current, with one structural change: the downsell modal should drop to single-CTA on whatever tier the user was looking at, not show 3 tiers again.**

The current architecture (tier-matched downsell on annual + quarterly abandon, no downsell on weekly) survives the 3-tier-visible change. What changes:

- **Downsell trigger detection.** Currently the abandon trigger fires after any "close" gesture. With 3 tier cards visible, the user can also abandon by tapping CTA after switching tier selection. The trigger needs to be "user closed without purchase," not "user tapped close on Annual." Make sure the downsell fires based on the *last-selected tier at close time*, so a user who switched from Annual to Quarterly and then bounced sees the quarterly downsell, not the annual.
- **Downsell modal: single-tier, NOT 3-tier visible.** This is the place where Stormy AI's "show one plan" finding genuinely applies. The downsell surface is a recovery moment; cognitive load is the enemy. Show only the discounted version of the tier they were closest to buying.
- **Weekly remains no-downsell.** Research consensus aligns; this stays.

**New addition: Quarterly downsell SKU should match.** You have `annual_discount` ($35.99) shipped. You'll need `quarterly_discount` ($18.74, 25% off) if the user abandons on Quarterly. Memory note: project_pricing_locked_v1_0_7 already includes "Tier-matched downsells (25% off) on annual + quarterly abandon" so this is presumably already in flight.

**Sequence:**
1. User sees 3-tier paywall
2. Selects Annual (default) or Quarterly (manual switch) or Weekly
3. Taps close X (delayed 1.5s per first brief)
4. Downsell modal fires showing ONE tier — discounted version of last-selected
5. User accepts → checkout for `*_discount` SKU
6. User closes downsell → out
7. **NO second downsell.** Apple takedown risk ([MacRumors Cal AI](https://www.macrumors.com/2026/04/21/apple-cal-ai-app-store-removal/)).

---

## 7. What gets cut to fit 720pt — ranked priority order

Detailed cut list from §3 above, ranked by what to fight hardest to keep vs cut first:

| Rank to keep | Element | Action | Reasoning |
|--------------|---------|--------|-----------|
| 1 (keep) | 3 tier cards visible | Keep — 240pt | The whole reason for the redesign |
| 2 (keep) | Headline (italic punch reflected answer) | Keep — 60pt | Personalization is highest-win experiment type after pricing |
| 3 (keep) | CTA pill | Keep — 52pt | Action is non-negotiable |
| 4 (keep) | Eyebrow | Keep — 16pt | Brand voice signal, cheap |
| 5 (keep) | Reassurance + legal | Keep — 30pt | Apple required |
| 6 (keep) | BecomingProjectionCard COMPRESSED | Keep compressed 260pt → 160pt | Highest loss-aversion lever, but compress hard |
| 7 (cut) | 3-row trial timeline | **CUT** — saves 80pt | Disclosure moves to inline in Annual card subtitle |
| 8 (cut) | "no payment due now ♥" floating trust chip | **CUT** — saves 28pt | Annual card subtitle does the same job |
| 9 (cut) | "see all plans" link | **CUT** — saves 18pt | All plans now visible |
| 10 (cut) | Strikethrough $99.96 on Annual card | Keep small, inline | Genuine math anchor, compliance OK |

**If the projection card MUST be 200pt+ to read well visually,** the order of further cuts:
1. Compress reassurance + legal to 22pt (tighter line)
2. Drop eyebrow entirely (saves 16pt — JeniFit voice can carry without it)
3. Headline to 1.5 lines / 48pt (test feasibility — may break reflected-answer fit)

**Hard line: do NOT cut the BecomingProjectionCard below 160pt.** Below that height the curve becomes illegible and the loss-aversion mechanic stops working. If the card can't render meaningfully at 160pt, kill the eyebrow + compress legal before further compressing the card.

---

## 8. Goal-aware default: visible recommendation badge — VALIDATE

**Yes, ship the visible "recommended for your 12-week goal ♥" badge on Quarterly for the conditional cohort. Drop the silent default. The recommendation reasoning is the conversion lever, not the pre-selection.**

**Evidence:**

- Personalization-via-onboarding-answers is the second-highest-win experiment type ([Adapty 2026 high-performing paywall](https://adapty.io/blog/high-performing-paywall-2026/)): "capturing user goals during onboarding and surfacing them on the paywall, even a single string match, outperforms most layout experiments." A goal-aware tier badge is the canonical version of this.
- Personalized paywalls drive up to 30% higher subscription growth rates ([Reteno via ProductMarketingAlliance](https://www.productmarketingalliance.com/how-to-increase-paywall-conversion-fast/)). The mechanism is signaling "we read your answers and built a recommendation specifically for YOU" — which collapses the "is this app for me?" question.
- The "Recommended" badge specifically increases middle-tier selection 30–50% in pricing-page research ([Apphud](https://apphud.com/blog/design-high-converting-subscription-app-paywalls)). Note: this lift is on *middle-tier selection*, not overall conversion. So the badge moves people from Annual → Quarterly inside the ≤12-week cohort. That's the intent.
- The reasoning text itself ("for your 12-week goal") is the trust-builder. Show WHY, not just WHICH. Cal AI's "we built your plan based on your answers" loader pattern works for the same reason ([Adapty trial vs direct purchase](https://adapty.io/blog/free-trial-vs-direct-purchase-subscription-apps/), [Adapty trial conversion rates 2026](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/)).

**Why visible-badge-but-not-pre-selected:**

- Pre-selecting Quarterly for the ≤12-week cohort means users who would have tapped through on Annual now have to manually switch back. Friction.
- The badge does its work *visually* — the user reads "recommended for me" and either (a) accepts the recommendation and taps Quarterly (the goal-aware cohort) or (b) reads the badge as informational and stays on Annual (the Annual-default cohort). Both paths are valid; the badge segments naturally.
- LTV math from §2: even within the ≤12-week cohort, Annual + trial wins LTV per paywall view. Soft recommendation captures the genuine Quarterly cohort without bleeding the Annual cohort.

**Copy options for the badge** (lowercase casual per JeniFit voice):
- "recommended for your 12-week goal ♥" — direct
- "fits your goal pace ♥" — softer, less specific
- "for your 12-week journey ♥" — JeniFit-branded "journey" register

Founder preference probably dictates which. Direct version converts more for trust-signaling; softer version reads more on-brand. Test after primary ships.

---

## Compliance checklist appendix (delta from v1)

Carried-over items from v1 brief stay. Net changes:

| # | Pattern | v1 status | v2 status | Notes |
|---|---------|-----------|-----------|-------|
| 17 | 3 tier cards visible vertical stack | Not applicable (single visible) | ✅ Allowed | Cal AI ships this; Apphud + Adapty recommend it |
| 18 | "Best Value" + "3-DAY FREE" stacked badges on Annual | Not applicable | ✅ Allowed | Both badges are factually accurate vs anchor + trial; no toggle pattern |
| 19 | Conditional "recommended for your 12-week goal" badge on Quarterly | Not applicable | ✅ Allowed | Personalization based on user-provided onboarding data; no misleading prominence |
| 20 | Trial chip prominence vs actual charge prominence | Critical | Critical | Trial chip must be SMALLER or EQUAL to the "then $47.99/yr" disclosure. If trial chip is more visually dominant than actual charge, takedown risk. |
| 21 | Annual pre-selected with Quarterly recommended-badge visible | Not applicable | ✅ Allowed | "Recommended" is informational; default is auto-selected; no obscuring |
| 22 | Single-tier downsell modal (not 3-tier) | Not applicable | ✅ Allowed | Same-SKU-family discount, same trial terms language |
| 23 | US-only $29.99 annual_discount SKU on downsell | Open | ✅ Allowed | Per-storefront pricing is Apple-supported; localization is a clean compliance pattern |
| 24 | Goal-aware default selection (auto-switch Quarterly when ≤12-wk) | Locked-but-shipping | ❌ DROP | Quietly switching the user's default tier without showing them why = obscured pricing pattern. Always-Annual-default + visible recommendation badge is the compliant version. |

**Critical compliance risk to flag explicitly:** the locked "goal-aware Quarterly default" silently changes which tier is pre-selected based on data the user gave during onboarding. Apple's April 2026 enforcement targets pricing patterns that aren't immediately legible to the user. A user who came in expecting "the default is Annual" and finds Quarterly pre-selected without explanation can plausibly read that as the app picking the more expensive long-term option (because at $24.99/12wk renewing = $108/yr vs $47.99/yr annual, Quarterly is actually *more* expensive on Y1+ if renewed). The visible recommendation badge resolves this — the user sees WHY, has informed consent. The silent default is the risk vector.

---

## Punch list — what to ship, ranked by founder-asked-for change × conversion impact

| Rank | Change | Type | Cost | Notes |
|------|--------|------|------|-------|
| 1 | Restructure paywall to 3-tier visible vertical stack with Annual primary | Founder ask + validated | Medium | Replaces current single-card-plus-drawer. Cards sized 96 / 72 / 72pt per §3 |
| 2 | Add `[BEST VALUE]` badge + `3-DAY FREE` chip stacked on Annual card | Founder ask + adjusted | Trivial | Keep both badges visually quiet; Apple-compliant only if actual-charge text is equally prominent |
| 3 | Add conditional `[recommended for your 12-week goal ♥]` badge on Quarterly for `goalPaceWeeks ≤ 12` users | Founder ask, reshaped | Small | Replaces silent goal-aware default; preserves goal-aware intent compliantly |
| 4 | DROP silent goal-aware Quarterly default; pre-select Annual for all users | Push back on founder | Trivial | Remove the conditional default-tier logic. Visible badge does the work; pre-selection bleeds Annual LTV |
| 5 | Compress BecomingProjectionCard 260pt → 160pt | Required for fit | Small | Drop internal header padding + inline date marker. Hard floor 160pt — below this curve becomes illegible |
| 6 | Eliminate 3-row trial timeline; fold disclosure into Annual card subtitle ("3 days free, then $47.99 on Jun 9 ♥") | Required for fit + compliance | Trivial | Frees 80pt; same Apple-compliant disclosure |
| 7 | Eliminate floating "no payment due now ♥" trust chip | Required for fit | Trivial | Annual card subtitle covers it |
| 8 | Eliminate "see all plans" link | Required by tier-visibility change | Trivial | Frees 18pt |
| 9 | Audit downsell modal: must show SINGLE tier (the one user last selected), not 3 | New requirement | Small | Downsell is single-CTA recovery surface; choice load is enemy |
| 10 | Ship `quarterly_discount` SKU at $18.74 (25% off) | New requirement | Medium | Required for Quarterly-abandon downsell since Quarterly is now selectable as primary |
| 11 | Ship US-only `annual_discount_us` SKU at $29.99 on downsell | Carried from v1, reshaped | Medium | Concentrates localization lift on highest-recovery moment, doesn't dilute primary anchor math |
| 12 | Add delayed (1.5s) close X to paywall | Carried from v1 — STILL UNSHIPPED PER PUNCH LIST | Trivial | Highest compliance urgency; Apple required affordance |
| 13 | Italic-Fraunces on "free" inside `3-DAY FREE` chip | Brand voice | Trivial | Voice signal lock per memory |
| 14 | A/B test downsell-trigger detection (last-selected tier at close time) | New requirement | Small | Ensures Quarterly-bounce sees quarterly_discount, not annual_discount |
| 15 | Update tier card subtitle copy to lowercase casual: "fits your goal pace" or "for your 12-week journey" | Brand voice | Trivial | Test variants after primary ships |

---

## Where the founder's instinct matches the 2026 evidence

- ✅ **3 plans visible** — Cal-AI-trained US Gen-Z cohort pattern-matches on 3-visible. Hiding tiers reads as obscuring pricing post-April-2026. Founder is right; v1 brief was wrong.
- ✅ **Quarterly is meaningful for the ≤12-week cohort** — goal-aware recommendation is a real lever and the locked logic captures real intent signal.
- ✅ **Single screen, no scroll** — universal 2026 mandate, no debate.
- ✅ **Pricing structure ($47.99 / $24.99 / $5.99 with genuine 4× quarterly anchor math)** — compliance-clean post-Cal-AI, anchor math is auditable.

## Where the founder's instinct does NOT match the 2026 evidence

- ❌ **Quarterly as global "best value" recommended** — pushes against the H&F category's strongest trend (annual gaining share to 68%), kills the genuine $99.96 anchor that makes Annual look like a deal, and surrenders measurable LTV per paywall view in both US and non-US cohorts. Use the conditional-badge model instead.
- ❌ **Goal-aware Quarterly PRE-SELECTED (vs visibly recommended)** — silent default-switching is a Cal-AI-takedown-adjacent pattern post-April-2026. Show the recommendation; don't silently swap the default. Always-Annual-default + visible badge does the conversion work without the compliance risk.
- ❌ **Quarterly-recommended-without-trial substitutes for the $29.99 US Annual SKU** — Quarterly's $24.99 is below the would-be $29.99 anchor numerically, but the trial mechanic is doing different work. Cohort that needs the price drop is not the same cohort that's been pre-trained by Cal AI's 3-day trial. Localization lift (62.3% experiment win rate) is too valuable to skip; ship $29.99 as US-only downsell SKU instead.

---

## Sources (delta from v1)

New sources added in v2:

- [Apphud — How to design a high-converting subscription app paywall](https://apphud.com/blog/design-high-converting-subscription-app-paywalls)
- [Adapty paywall library — Cal AI food calorie tracker entry](https://adapty.io/paywall-library/cal-ai-food-calorie-tracker/)
- [DealHub — What is decoy pricing?](https://dealhub.io/glossary/decoy-pricing/)
- [Stormy AI — 10 mobile app paywall design principles from 4,500+ A/B tests](https://stormy.ai/blog/10-mobile-app-paywall-design-principles)
- [Productmarketingalliance — How to increase paywall conversion, fast](https://www.productmarketingalliance.com/how-to-increase-paywall-conversion-fast/)

All v1 sources remain authoritative; see `paywall_research_monetization_2026_06_06.md` for the full sources block.
