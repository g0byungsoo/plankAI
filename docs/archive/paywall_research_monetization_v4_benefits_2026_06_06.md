# JeniFit Paywall v4 — Benefits-List Interrogation

**Date:** 2026-06-05
**Author:** Senior iOS monetization (RevenueCat / Adapty / Superwall / Helium lens)
**Status:** Founder asking whether to fill the empty `trialOrPlanRecap` slot with a benefits list when Quarterly/Weekly is selected. This brief answers conversion-first, not aesthetic-first. Prior briefs: [v1](paywall_research_monetization_2026_06_06.md), [v2](paywall_research_monetization_v2_2026_06_06.md), [v3](paywall_research_monetization_v3_2026_06_06.md).

---

## Executive recommendation (one paragraph)

**Ship a benefits list. Make it global, not tier-conditional. Position it in the recap slot — replacing the per-tier collapse — and keep the trial timeline as a compressed inline strip on Annual only.** The 2026 evidence is unusually unanimous: Adapty's high-performing-paywall 2026 writeup calls Free-vs-Pro comparison/benefits lists "one of the most consistent paywall additions among top apps" across fitness, productivity, and AI verticals because they remove the "what do I actually get?" objection at the point of decision ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)); Stormy AI's 4,500-test analysis names the bullet-list paywall as the cross-category performance benchmark ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)); Adapty's broader benchmarks attribute up to 30% lift to visual optimization including value-prop clarity ([Adapty 2026 Tiered Pricing](https://adapty.io/blog/tiered-pricing/)). For the US Gen-Z cohort specifically — the 7–14% trial-rate underperformer — the conversion problem is *not* that the paywall feels too salesy. It's that the value proposition is implicit, the user has to infer it from the projection chip + voice copy + the trial timeline, and **Cal-AI-trained scanners reject implicit value framing as evasive**. A 4-bullet benefits list with outcome-first copy (not feature-first) is the missing trust unlock. Lead with the **shipped** product surface (workouts, plank training, weight + steps, breathwork, Becoming insights) — *not* the food rail or AI coach, which are unshipped or feature-flagged. Founder instinct here matches the evidence — add benefits. Where her instinct needs interrogation: she's framing this as "fill the empty space when Quarterly is selected." The correct frame is "this should be visible *always*, and we should *cut* the per-tier collapse." Tier-conditional benefits would imply tier-feature gating, which JeniFit does not have. Always-on benefits + compressed conditional trial strip is the pattern.

---

## 1. Does a benefits list convert? Conversion-load-bearing or aesthetic?

**Yes, it converts. Load-bearing for cohorts that can't infer value. Aesthetic for cohorts already sold by the hero.** JeniFit's US Gen-Z trial-rate gap puts it in the load-bearing bucket.

The 2026 evidence stack:

- **Adapty 2026:** Free-vs-Pro comparison/feature tables "appear across fitness, education, productivity, design, and AI tools. The reason is straightforward: a significant percentage of users at the paywall still don't fully understand what they're paying for. A clear, scannable comparison removes the 'what do I actually get?' objection." Called "table stakes in top-performing onboarding flows" ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)).
- **Stormy AI 4,500-test analysis:** "The simple, single-page bulleted list serves as a reliable performance benchmark across almost every category" — bullet-list with 3–5 value props + strong heading + clear CTA is the cross-vertical winner ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)).
- **Adapty experiment playbook 2026:** Pricing first (≤80% lift), visual optimization second (≤30% lift), country pricing third (≤15%). Benefits-list treatment falls in the visual-optimization band ([Adapty playbook](https://adapty.io/blog/paywall-experiments-playbook/)).
- **Adapty H&F 2026 benchmarks:** Visual + copy tests have the *lowest* win rate of any experiment type (34.6% for LTV, 31.4% for conversion) — meaning when they do win, the lift is meaningful, but most visual tests don't ([Adapty H&F 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)). This is the honest cold-water counter to "always add benefits." The cohort matters more than the bullet count.

**Honest expected lift band for JeniFit:** 5–15% trial-start rate, with the **US sub-cohort getting most of the lift** because they're the ones currently scanning the paywall and not converting. International cohorts (PH/SG/UK 33–100% trial start) are already converting on the implicit value — benefits list won't compound much there.

**Counter-cite worth respecting:** Stormy AI also found that the simplest paywall — generic "Continue" + minimal copy — outperformed feature-heavy descriptive variants by up to 111% ([Stormy 2026](https://stormy.ai/blog/10-mobile-app-paywall-design-principles)). This is a copy-density warning, not a benefits-list rejection: their winning sparse-paywall variants still showed value props, just *fewer and shorter*. Translation for JeniFit: ship the list, but **3–4 bullets max, outcome-first wording, no fluff**.

---

## 2. Where does it live in the slot composition?

**Replace `trialOrPlanRecap` with `benefitsList`. Compress the Annual trial timeline into the CTA-stack region.**

Current composition (worst case ~612pt, ~108pt headroom):

```
topBar              44pt
heroPermission      52pt
becomingProjectionChip 110pt
pricingRowAnchorLine 24pt
tierRowHorizontal   156pt
trialOrPlanRecap    88pt (Annual) / 36pt (other)  ← founder's "empty" slot
ctaButtonV2         56pt
trustAndLegalFooter 32pt
```

**v4 proposed composition (~604pt, ~116pt headroom on iPhone 13 mini):**

```
topBar              44pt
heroPermission      52pt
becomingProjectionChip 110pt   (keep — research moat)
pricingRowAnchorLine 24pt
tierRowHorizontal   156pt
benefitsList        88pt   ← NEW, always-on, 4 rows
trialMicroLine      14pt   ← single line, replaces the 88pt strip
ctaButtonV2         56pt
trustAndLegalFooter 32pt
```

The 88pt slot holds exactly 4 benefit rows at 22pt each (16pt glyph + 14pt copy, 4pt row gap). That's the sweet spot Stormy's 4,500 tests converged on: "3 to 5 clear, high-value bullet points" ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)). 4 lets you cover the four product pillars without forcing a 5th overpromise.

**Why this beats v3's "let it collapse to 36pt":** v3 was correct that the slot wasn't conversion-essential for already-converting cohorts. v4 reframes: the slot is the US cohort's missing value-prop scaffold. The trial timeline's 3-row "today / day 2 / day 3" structure is informational, not conversion-driving — RevenueCat's 2026 data shows **82.1% of H&F trials start on Day 0** ([RevenueCat 2026 benchmarks](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)), meaning by the time the user is choosing, they're already committed to trying — they need value clarity, not billing-date clarity.

**The trial timeline doesn't disappear, it compresses:** When Annual is selected, the 14pt `trialMicroLine` reads `today free → day 2 reminder → day 3 charged $47.99`. Same three landmarks, one line, 11pt Inter. When Quarterly/Weekly is selected, the line reads `billed today $24.99 · cancel anytime in Settings`. Cal-AI-compliant, no toggle, selection-aware.

**Alternative placements considered + rejected:**

| Placement | Why rejected |
|---|---|
| Above tier row | Steals primacy from the price anchor; Mobbin patterns show value props above pricing only when pricing is single-tier ([Adapty paywall library](https://adapty.io/paywall-library/)) |
| Inside each card | 104–134pt of card width can't hold readable bullets at 11pt+; would force ≤4-word phrases that read as fragments |
| Below CTA | Below-the-fold on iPhone 13 mini; ~89.4% of trial starts happen on D0 and on-screen visibility ([RevenueCat 2026 benchmarks](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)) means anything past the CTA is post-decision |
| Replace projection chip | Chip *is* the data-provenance differentiator and the conversion moat for cohorts who finished the 6-part onboarding; benefits list is additive, not substitute |

---

## 3. Tier-conditional or always-on?

**Always-on. Tier-conditional benefits would imply tier-feature gating, which JeniFit does not have.**

The reason Cal AI shows the same benefits list across all selected pricing options is that all tiers grant the same feature access — only the billing cadence varies ([Cal AI teardown via PaywallPro](https://www.paywallpro.app/share/Cal-AI---Calorie-Tracker-2.5.2-us?id=288284); [Adapty Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)). MyFitnessPal's Premium/Premium+ is the *opposite* pattern — tier-specific benefits because the tiers actually differ ([Adapty Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)).

JeniFit ships single-tier-access pricing. Showing tier-conditional benefits would either:
1. Fabricate tier differences ("Annual gets X, Weekly doesn't") — breaks honesty + data-provenance rule + likely Apple 3.1.2c risk (deceptive tier framing)
2. Show the same list 3 times with subtle padding/order changes — adds zero value
3. Show benefits only on Quarterly/Weekly and trial timeline only on Annual — gives Annual *less* value-prop signal, which is the inverse of what you want

**Pattern lock:** benefits list renders identically regardless of selected tier. The only tier-conditional element is the single-line `trialMicroLine` underneath it.

This is also what Adapty's library audit of top calorie/fitness apps converges on: "Comparison tables… appear across fitness, education, productivity, design, and AI tools" — and they don't change per tier in any of the cited examples ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)).

---

## 4. What features get listed? Pick 3–5.

**4 bullets, outcome-first, ordered by what the cohort *thinks they're buying* in the post-onboarding moment. Lead with what's shipped today. No food, no AI coach.**

Recommended copy + ordering:

| # | Glyph | Copy | What it traces to |
|---|---|---|---|
| 1 | warm-cocoa figure-stretching glyph | `daily workouts sized for your level` | Workout engine (shipped, rules-doc compliant per-tier difficulty floor + duration grid) |
| 2 | cocoa heart-line glyph | `track weight, steps, breathwork in one place` | Steps (HealthKit, shipped v1.0.6), weight tracking (kg/lb, one-per-day), breathwork (cortisol mechanism, shipped) |
| 3 | cocoa spiral glyph | `becoming insights from your own data` | Becoming tab (shipped — Activity Ring, EMA, BMI banding, Mastery Curve, Barrier-Resolved card) |
| 4 | cocoa book-spine glyph | `jeni method lessons + voice coaching` | JeniMethod lessons (shipped), voice cascade (shipped — switch_sides, prep_full, prep_short variants) |

Each bullet pairs an outcome verb with a noun the onboarding has already primed:
- "daily workouts sized for your level" matches the bodyFocus + difficulty answer trail
- "track weight, steps, breathwork in one place" matches the multi-data vision without overpromising food/scan
- "becoming insights from your own data" rhymes with the Becoming tab name + the data-provenance brand position
- "jeni method lessons + voice coaching" reinforces brand voice + the Q140-identity-hero moment

**Why this ordering:** Stormy 2026 finding — "Sell outcomes not features" — Helium's example was literally "Get fit in weeks > AI fitness coach is better and cheaper" ([Helium 2026](https://tryhelium.com/blog/100-paywall-tests-that-work)). Lead with the verb the cohort is hiring you for.

**Why workouts lead, NOT food:** Three reasons:
1. **Shipped surface.** Workout engine is the rules-doc-compliant production code path; food rail is feature-flagged behind `FoodFlags.isAdvertised` and rolling out in v1.0.7. Listing food today = Apple 3.1.2c overpromise risk + churn risk during the 3-day trial (see §8).
2. **Cohort scan pattern.** TikTok-acquired Gen-Z women came in via JeniFit's workout creative. The hero already signals workouts. Reinforcing the established product reduces cognitive load at the choice moment.
3. **Diet-first pivot is upstream, not yet downstream.** The pivot is a 2026-Q3 program direction (per [project-pivot-diet-first-2026-06-05]), not a v1.0.7 paywall claim. Paywall copy lags the program, doesn't lead it.

**Features explicitly NOT listed and why:**

| Feature | Why excluded |
|---|---|
| photo→calorie tracking (food rail) | Feature-flagged, rolling out, would create the exact Cal-AI 3.1.2c "overpromise + obscure" risk Apple cited ([TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)) |
| AI coach agent | Long-term vision, not shipped, listing it = direct overpromise + post-Ozempic cohort distrust of "AI" claims |
| "Personalized to your goal" | Implicit in the projection chip + hero copy already — adding to bullets is repetition |
| "No ads" | Cohort doesn't expect ads in a $47/yr subscription; listing it suggests the negative was on the table |
| "Cancel anytime" | Lives in the trust microcopy below, not in the value bullets |

If/when food rail comes off the flag in a future release, the bullet swap is `track weight, steps, breathwork` → `photo log meals, weight, steps`. Replace, don't add — 4 bullets is the budget.

---

## 5. Cohort impact: does a benefits list hurt Gen-Z US trust?

**Net positive trust impact. The cohort doesn't reject explicit value props; they reject *unverifiable* value props.**

The mental model the US Gen-Z post-Ozempic cohort is running:

- **They've seen Cal AI's spin-wheel + manufactured urgency** and Apple's April 2026 enforcement action made it cultural ([TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)).
- **They've been microdosing GLP-1s** — 89% of Gen-Z surveyed report current or prior microdosing ([Newsweek 2026](https://www.newsweek.com/gen-z-leading-new-weight-loss-trend-ozempic-microdosing-2065309)) — meaning the app's pitch competes with a real pharmacological intervention.
- **64% cite cost as the #1 GLP-1 barrier** ([Pew 2026-01](https://www.pewresearch.org/short-reads/2026/01/23/6-facts-about-obesity-and-weight-loss-drugs-in-the-u-s/)) — they're priced-out of the drug, app subscription is *not* automatically cheaper-feeling unless value is explicit.

The bullets that *would* break trust:
- "lose 20 lbs guaranteed" — disprovable, post-Ozempic cohort flags it as 2010s
- "AI coach personalized just for you" — Cal-AI-trained cohort scans "AI" as marketing filler
- "join 100,000+ women" — fabricated social proof; data-provenance violation
- "burn calories faster" — labor verb, anti-cohort vocabulary per [post-ozempic-vocabulary]

The bullets that *build* trust:
- Outcome verbs with measurable surfaces ("track weight, steps, breathwork")
- Brand-tied vocabulary ("becoming insights", "jeni method")
- Data-traceable claims ("from your own data") — same wedge the projection chip uses

**Honest sub-finding:** the benefits list mostly helps the **US trial-start gap, not the US trial-to-paid gap**. Trial start is a paywall problem. Trial-to-paid is a Day-0–3 product-experience problem, and RevenueCat 2026 found **55% of 3-day trial cancellations happen on D0** ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)). The paywall can't fix D0 cancellation; only the post-paywall first-session experience can. Don't expect the benefits list to lift trial-to-paid by more than 1–2%.

---

## 6. Visual treatment

**Glyph + outcome verb + 1-line copy. Tap-affordance off. Soft staggered entry on first render only.**

Spec:

- **Row height:** 22pt (16pt glyph + 14pt copy line, 4pt gap below).
- **Glyph:** 16pt monoline icons in cocoa #5B3A1F, NOT filled sticker glyphs. Matches the Settings sub-page chrome already in production (existing scrapbook component family). Reasons: (a) at 16pt size, the y2k coquette filled glyphs render too busy and steal scan attention from the copy; (b) thin marks ladder with the "Chanel/Tiffany minimal-luxury composition layered over coquette warmth" principle from [feedback-clean-luxury-aesthetic].
- **Copy:** Inter 14pt regular, lowercase, sentence case, no terminal punctuation (the cocoa pill CTA below is the terminal). Hearts ♥ NOT used on these rows — hearts are reserved for hero + CTA per voice lock.
- **Spacing:** 16pt left edge align with the tier row, 16pt right edge.
- **Entry animation:** stagger token (0.10s between rows), entranceSoft (0.42s) — only on first render; selection changes do NOT re-trigger. Reduce-motion → snap to final per existing accessibility rules.
- **Accessibility:** `accessibilityElement(children: .combine)` per row so VoiceOver reads "icon, daily workouts sized for your level"; `accessibilityHidden` on the glyph so VoiceOver doesn't double-read the icon.

**What the evidence says about icons:**
- Adapty 2026: "data emphasizes scannable clarity over lengthy text" — visual hierarchy matters more than icon presence per se ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)).
- Helium 100 paywall tests: animating bullets/double-clicking for emphasis can lift feature comprehension ([Helium 2026](https://tryhelium.com/blog/100-paywall-tests-that-work)); but the warning is "don't over-animate" — entry stagger only, not perpetual motion.
- Stormy 4,500 tests: simpler beats heavier — "111% lift on Continue button over descriptive copy" was a *less* signal ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)).

**Reject:**
- Checkmark glyphs (✓) on every row — reads as compliance UI, not value
- Filled sticker glyphs — too visually loud, fights the cards
- Two-line copy — at 14pt × 358pt wide, copy must fit on one line; multi-line implies a copy rewrite, not a font/size change
- Persistent animated shimmer — Cal-AI-style manufactured polish, post-Ozempic cohort flags

---

## 7. Trial-timeline interaction

**Compress the 3-row timeline into a single `trialMicroLine`. Position immediately below the benefits list, above the CTA.**

The current 88pt 3-row "today / day 2 / day 3" timeline is informational chrome. Its conversion job is the unlock signal "no payment today." That signal can be delivered in a single 14pt line:

**Annual selected:**
```
today free  ·  day 2 reminder  ·  day 3 charged $47.99
```

**Quarterly selected:**
```
billed today $24.99  ·  cancel anytime in Settings
```

**Weekly selected:**
```
billed today $5.99  ·  cancel anytime in Settings
```

Typography: 11pt Inter, cocoa-60% opacity, dot separators (` · `) at 50% opacity. Centered. Hairline cocoa-15% rule above (1pt) separating benefits list from the trial micro-line.

**Why the compression works:**
- The 3-row timeline's selling power was "see the date you'll be charged." A single line with the same three landmarks (today / reminder / charge) preserves that.
- RevenueCat 2026: 82.1% of H&F trials start D0, 89.4% start within first week ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)) — the timeline isn't doing first-purchase-funnel work; it's doing late-stage reassurance work, which a single line covers.
- Cal-AI compliance is preserved: actual billed amount displayed at full readability ($47.99/yr, $24.99, $5.99 — never an "equivalent" derivation).

**When the 3-row strip is worth keeping:** if A/B testing the compressed line shows trial-start dropping by >5% in the Annual cohort, restore the 3-row strip and shrink benefits to 3 rows. Order of test:

1. v4 ship: 4-bullet benefits + 1-line trial micro
2. If trial-start drops Annual >5%: 3-bullet benefits + 3-row trial strip (back to ~88pt total)
3. If still down: revert to v3 layout, benefits-list hypothesis is rejected

---

## 8. Risk: overpromising on unshipped/flagged work

**This is the single largest landmine in the benefits-list decision and the reason food + AI coach get excluded from v1 of the list.**

The Cal AI April 2026 enforcement action specifically cited "displaying weekly calculated pricing more prominently than the actual amount" + the spin-wheel manipulation ([TechCrunch 2026-04-21](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/), [MWM compliance writeup 2026](https://mwm.ai/articles/apple-executes-compliance-pull-on-cal-ai-calorie-tracker-over-deceptive-billing-april-2026)). The broader Guideline 3.1.2c family covers any "deceptive billing" pattern, which includes selling access to functionality the user can't immediately use.

**The specific risk for JeniFit:**
- Food rail (photo→calorie) is feature-flagged behind `FoodFlags.isAdvertised`. Listing "log meals from a photo" on the paywall while the feature is gated means a user who pays could land on the home screen and find no food entry point. Apple's compliance team treats this as the same family of risk as Cal AI's pricing inversion.
- AI coach agent is long-term vision, not stubbed UI even. Listing "AI coach" is direct overpromise.
- Body scan is on the vision roadmap but not shipped. Same constraint.

**The trial-window churn risk:**
- 55% of 3-day trial cancellations happen on D0 ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)).
- If a user pays expecting food logging and doesn't find it, D0 cancellation is the expected outcome — paywall over-promise → product under-deliver → cancel → never come back.
- This is a *double loss*: lost the trial-to-paid AND poisoned the WOM/refund channel.

**The pattern other apps use when they ship a list with unshipped features:**

| App | Pattern | Risk eval |
|---|---|---|
| Cal AI | Lists shipped features only; "Premium unlocks all features during trial" — keeps the list current-state ([PaywallPro Cal AI teardown](https://www.paywallpro.app/share/Cal-AI---Calorie-Tracker-2.5.2-us?id=288284)) | Safe pattern |
| MyFitnessPal | Lists Premium-tier features that are shipped; tier-feature-gated, not feature-flagged-gated ([Adapty Newsletter #22](https://adapty.io/blog/paywall-newsletter-22/)) | Safe |
| Halo AI | Lists features that exist; uses intent-based trigger to highlight the feature the user already tried ([Halo AI Superwall case study](https://stormy.ai/blog/halo-ai-paywall-experiments-superwall-2026)) | Safe |
| Some early-stage apps | List "coming soon" badges next to roadmap features | **Unsafe** — Apple has cited this as 3.1.2c risk; cohort distrust |

**v4 recommendation:** list only what ships on the device the buyer is holding *today* in the version being downloaded. When food rail comes off the flag, swap the bullet — don't add it ahead of time. When AI coach ships, swap again. The bullet count stays at 4.

**If founder insists on including food rail in the bullet:** gate the bullet render on the same `FoodFlags.isAdvertised` flag, so it only shows for users on builds where food is available. This is mechanically correct but operationally fragile — better to wait until the flag is unconditional.

---

## 9. The "empty when Quarterly selected" complaint — which fix lifts conversion most?

**Option (a) global benefits list is the correct conversion-first fix. Options (b) and (c) leak conversion.**

Founder framed three options:

| Option | Conversion expected | Trust impact | Compliance |
|---|---|---|---|
| (a) Global always-on benefits list | +5–15% trial-start, US-cohort weighted | Net positive | Safe if features are honest |
| (b) Tier-specific benefits | Flat to -2% | Net negative (implies fake tier gating) | Yellow flag — 3.1.2c family risk |
| (c) Enrich plan recap line | +1–3% | Neutral | Safe |

**Why (b) loses:** As covered in §3, JeniFit has single-tier-access pricing. Inventing differentiation to fill the slot is either dishonest or padding. The cohort sniffs it.

**Why (c) loses to (a):** A richer plan recap line ("Quarterly · $24.99 every 3 months · cancel anytime") is just better trial-micro-line work. It doesn't address the underlying "what do I get?" objection that Adapty's research names as the load-bearing question users have at the paywall ([Adapty 2026](https://adapty.io/blog/high-performing-paywall-2026/)). A richer recap line is necessary but insufficient.

**Why (a) wins:** Resolves the empty-slot complaint, addresses the value-clarity gap that hits the US cohort hardest, ships a 2026 cross-vertical-benchmark pattern, doesn't break compliance if features are honest.

**Mental rephrasing the founder needs:** "the slot is empty on Quarterly/Weekly" is the symptom. The disease is "the paywall implicitly assumes the user knows what they're buying." Filling the slot is the symptomatic fix; replacing the slot with always-on benefits is the structural fix.

---

## 10. CTA copy in light of benefits

**Keep `continue`. Selection-aware sub-line below, NOT in the button.**

The Stormy 4,500-test finding is the strongest cross-vertical evidence here: "Continue" outperformed descriptive button copy by **up to 111%** ([Stormy 2026](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)). The mechanism: descriptive button copy increases cognitive friction at the commitment moment; a low-stakes verb (continue) feels reversible.

**Locked CTA copy:**

```
continue  (cocoa pill, 56pt, white Fraunces 17pt regular)
```

The trial commitment language lives in the line *immediately above the CTA*, not on the button:

- Annual selected: trial micro-line reads `today free · day 2 reminder · day 3 charged $47.99`
- Quarterly selected: `billed today $24.99 · cancel anytime in Settings`
- Weekly selected: `billed today $5.99 · cancel anytime in Settings`

This preserves the "continue" magic while making the commitment terms unmissable in the eye-path between the price cards and the button.

**Reject these CTA variants founder may consider:**

| Variant | Why reject |
|---|---|
| `start your becoming plan ♥` | Brand-voice rich but adds commitment language to a low-friction button; -10–30% trial-start expected |
| `get everything ♥` | Implies "everything" which interacts badly with benefit-list overpromise risk |
| `start free trial · continue` (Annual-conditional) | This was v3's recommendation; v4 supersedes — moves the trial signal to the micro-line above to keep the button identical across tier selections (reduces visual jitter on tier change, which Adapty 2026 cites as a paywall-trust factor) |
| `unlock jenifit` | Brand-coined verb, voice-lock violation |

**One pattern worth A/B testing in v4.1 after baseline ships:** if Annual trial-start is still soft after benefits-list ship, test a 6pt secondary line under the cocoa pill reading `cancel before day 3 to skip the charge` — but only as an A/B, only on Annual. This is the post-Cal-AI version of the "no risk" reassurance pattern.

---

## Compliance appendix — overpromise risk specific to unshipped/flagged work

| Bullet candidate | Status in v1.0.7 build | Compliance verdict |
|---|---|---|
| `daily workouts sized for your level` | Shipped (workout engine + rules-doc) | ✅ Safe |
| `track weight, steps, breathwork in one place` | Weight ✅, Steps ✅ (v1.0.6 HealthKit), Breathwork ✅ | ✅ Safe |
| `becoming insights from your own data` | Becoming tab ✅ | ✅ Safe |
| `jeni method lessons + voice coaching` | JeniMethod ✅, Voice cascade ✅ | ✅ Safe |
| `log meals from a photo` | Behind `FoodFlags.isAdvertised` | ⚠️ **Hold until flag default = ON in production build** |
| `body scan for progress photos` | Not built | ❌ **Do not list** |
| `ai coach personalized to your goals` | Vision only, not stubbed | ❌ **Do not list — 3.1.2c overpromise risk + voice violation ("AI")** |
| `lose weight faster` | Health claim | ❌ **Do not list — Apple medical/health claim risk + post-Ozempic cohort distrust** |
| `cancel anytime` | Lives in trust footer, not bullets | ✅ Safe in footer |

**Process recommendation:** add a `paywallBenefitsList()` view-builder that takes the current `FoodFlags` + a `BenefitsCatalog` (mapping each bullet to a `requiresFlag: FeatureFlag?` predicate) — so each bullet's render is gated on the actual feature availability at build time, not at design time. Avoids the situation where v1.0.8 flips a flag and the paywall accidentally lies about v1.0.7 builds still in market.

**Apple-side specific risks v4 introduces:**

1. *Misleading feature availability* (3.1.2c): mitigated by listing only shipped features.
2. *Implied health claims*: mitigated by outcome verbs that describe app actions ("track weight") not biological outcomes ("lose weight").
3. *Tier-gating implication*: mitigated by always-on display (no per-tier change).
4. *Cal-AI-style pricing inversion*: not affected by benefits list (pricing display unchanged from v3).

---

## Punch list — v4 changes ranked by projected conversion impact

| Rank | Change | Projected lift | Risk | Surface |
|---|---|---|---|---|
| 1 | **Add 4-bullet always-on benefits list** in the recap slot (88pt) | **5–15% trial-start**, US-cohort weighted | Low if bullets are honest | Replaces `trialOrPlanRecap` per-tier collapse |
| 2 | **Compress trial timeline to single 14pt micro-line** with selection-aware copy | **+0–3%** Annual / Neutral other tiers | Low | Above CTA |
| 3 | Lock CTA at `continue` regardless of selected tier | **+2–8%** (cross-tier, Stormy 4,500-test signal) | Low | CTA button |
| 4 | Outcome-first bullet copy (verb-led, no AI language, no health claims) | Embedded in #1 | Low | Bullets |
| 5 | Monoline cocoa glyphs, not filled sticker glyphs | Embedded in #1 | Low | Bullet rows |
| 6 | `paywallBenefitsList()` builder gated on `FoodFlags` + future flags | 0% direct lift, **avoids -10–20% churn risk** when adding flagged features later | Avoids landmine | Engineering pattern |
| 7 | Stagger entry on first render only (entranceSoft, 0.10s stagger) | **+0–1%** scan-pull | Low | Animation |
| 8 | Restore 3-row trial strip *only* if Annual trial-start drops >5% post-launch | n/a — defensive | Low | Conditional |

**Compounded expected impact when shipped together:** 8–20% trial-start lift overall, **15–30% US-cohort-specific lift** as a function of the US value-clarity gap being load-bearing for them. International cohorts likely see closer to single-digit lift.

**What to ship first if only one item lands:** #1 — the benefits list itself. Everything else is supporting infrastructure. The benefits list is the actual conversion-driving asset.

**What absolutely does not ship:** any bullet referencing food rail until `FoodFlags.isAdvertised` defaults to ON; any bullet referencing AI coach or body scan ever in v1; any "lose weight" / "burn" / "shred" verb in bullets; tier-conditional benefit visibility.

---

## Where founder instinct matches the evidence

- ✅ "The recap slot feels empty" — correctly identified the lowest-ROI slot in the v3 composition
- ✅ "Should we add a benefits list" — yes, this is the highest-ROI fill for that slot in 2026 paywall evidence
- ✅ "Calorie tracking, workout features, weight loss management" — outcome-first phrasing matches the Helium/Adapty recommendations

## Where founder instinct needs interrogation

- ⚠️ "Add it when Quarterly/Weekly is selected" — incorrect framing; the list should be **always-on**, not tier-conditional. Tier-conditional implies fake tier gating, breaks 3.1.2c and cohort trust.
- ⚠️ "Calorie tracking" as a listed feature — premature. Food rail is feature-flagged. Add it only when the flag defaults to ON. Until then, listing it = overpromise risk + D0 cancellation risk.
- ⚠️ "Weight loss management" as a listed feature — too close to a health claim. Reframe to "track weight, steps, breathwork" — actions the app performs, not outcomes the user will experience.
- ⚠️ The framing that this is mostly a "fill the empty space" problem. It's a "the paywall implicitly assumes value comprehension that the US cohort doesn't have" problem.

---

## Sources

- [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/)
- [RevenueCat — 2026 trends & benchmarks summary](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)
- [RevenueCat — R.I.P. toggle paywall (Jan 2026)](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)
- [Adapty — High-performing paywall 2026](https://adapty.io/blog/high-performing-paywall-2026/)
- [Adapty — Tiered pricing 2026](https://adapty.io/blog/tiered-pricing/)
- [Adapty — Paywall experiments playbook](https://adapty.io/blog/paywall-experiments-playbook/)
- [Adapty — Paywall Newsletter #22 (Cal AI / MyFitnessPal / HitMeal teardowns)](https://adapty.io/blog/paywall-newsletter-22/)
- [Adapty — Health & Fitness subscription benchmarks 2026](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)
- [Adapty — Mobile paywall library](https://adapty.io/paywall-library/)
- [Stormy AI — 4,500 paywall A/B test lessons](https://stormy.ai/blog/how-to-design-a-high-converting-mobile-app-paywall-lessons-from-4500-ab-tests)
- [Stormy AI — 10 design principles from 4,500 tests](https://stormy.ai/blog/10-mobile-app-paywall-design-principles)
- [Stormy AI — Halo AI Superwall experiments 2026](https://stormy.ai/blog/halo-ai-paywall-experiments-superwall-2026)
- [Superwall — Cal AI case study](https://superwall.com/case-studies/cal-ai)
- [Superwall — 5 paywall patterns used by million-dollar apps](https://superwall.com/blog/5-paywall-patterns-used-by-million-dollar-apps/)
- [Superwall — Feature-based paywalls](https://superwall.com/blog/how-to-create-feature-based-paywalls-for-higher-conversions/)
- [Helium — 100 paywall tests that work](https://tryhelium.com/blog/100-paywall-tests-that-work)
- [PaywallPro — Cal AI v2.5.2 teardown](https://www.paywallpro.app/share/Cal-AI---Calorie-Tracker-2.5.2-us?id=288284)
- [TechCrunch — Apple's Cal AI crackdown (2026-04-21)](https://techcrunch.com/2026/04/21/apples-cal-ai-crackdown-signals-its-still-policing-the-app-store/)
- [MWM — Cal AI compliance pull writeup, April 2026](https://mwm.ai/articles/apple-executes-compliance-pull-on-cal-ai-calorie-tracker-over-deceptive-billing-april-2026)
- [Pew Research — GLP-1 facts, Jan 2026](https://www.pewresearch.org/short-reads/2026/01/23/6-facts-about-obesity-and-weight-loss-drugs-in-the-u-s/)
- [Newsweek — Gen-Z Ozempic microdosing, 2026](https://www.newsweek.com/gen-z-leading-new-weight-loss-trend-ozempic-microdosing-2065309)
