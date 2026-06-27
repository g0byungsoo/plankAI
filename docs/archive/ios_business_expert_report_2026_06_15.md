# JeniFit Path to $100k MRR — iOS Subscription Business Analysis

*2026-06-15. Senior iOS monetization expert review, grounded in current code (1.0.9), 7-day PostHog data, RC 2026 H&F benchmarks, and the locked strategy at `docs/jenifit_v2_strategy_2026_06_13.md`. Bullet-dense over prose.*

---

## TL;DR — read this if nothing else

- Current run-rate: ~$1,100 / 7d ≈ **$4,700 MRR** at this acquisition mix. $100k / mo is **~21–22x**.
- This is **not one problem**, it is the **multiplication of three correctable problems**: (1) tier mix is shipping in the wrong direction (quarterly no-trial outselling annual-trial 4:1 = LTV destruction), (2) D1 retention 12% is half the H&F baseline, so paywall conversion is misleadingly good — we are stuffing leaky buckets with $1 TikTok traffic, (3) install base is below the floor needed for the math to close even at a perfect funnel.
- **One realistic decomposition to $100k/mo** (no single hero metric): ~4× install volume + ~1.6× ARPU (annual-default + price ladder) + ~1.5× retention (Sprint A nudges + plateau intervention + winback). 4 × 1.6 × 1.5 = **9.6x**. To clear 22x you also need either (a) the sister-cohort SKU at 10x LTV on the top decile (Sprint D-E, evidence-thin but founder-aligned), or (b) annual-renewal-economics compounding past month 12 (high-confidence, just takes time).
- **Don't ship the v2 price ladder ($54.99 → $79.99 → $99.99) yet.** First fix the tier-mix structural defect (quarterly is the default for "goalSolvableInTwelveWeeks" users, has no trial, and is winning by misalignment not by preference). Run a 21-day annual-default A/B + a US-only $59.99 anchor test before touching the ladder.
- **3-day trial: stay put. A/B 7-day US-only inside 30 days.** The evidence is genuinely mixed and the test cost is one ASC + RC config day.
- **Highest-confidence 30-day move:** drop weekly from primary paywall, force annual default everywhere, ship the Sprint A in-trial notification + reframe sequence. Expected combined lift: +25–60% blended ARPU on the same paywall views.

---

## A. The $100k/month math

### A1. Backing into the subscriber count

Three credible ARPU scenarios from the same code shipping today:

| Scenario | Blended monthly ARPU | Paying subs needed for $100k/mo |
|---|---|---|
| **Status quo mix** (29 Q / 7 Y / 7 W / 1 Yd in 7d → ~$8.25 monthly-equivalent per active paying sub) | ~$8.25 | **~12,100** |
| **Annual-default mix** (Q drops to 25%, Y becomes 60%, W 15%) | ~$5.60 | **~17,900** |
| **v2 ladder $59.99 + better mix** | ~$7.30 | **~13,700** |

Why does annual-default *lower* monthly ARPU? Because quarterly bills $24.99 every 3 months → $8.33/mo, vs annual $47.99/yr → $4.00/mo. Quarterly is currently shipping at a *higher monthly run-rate* than annual. **This is the structural defect we discuss in A4 and B2.** Higher monthly ARPU ≠ higher LTV — the quarterly cohort churns faster and has no trial absorbing intent, so trial → paid conversion is the wrong way around.

### A2. Working backwards through the funnel (one realistic chain)

Target: $100k/mo. One chain that closes the math:

```
Monthly installs:        40,000        (currently ~1,200/wk → ~5,200/mo)
Onboarding completion:   88%   → 35,200 onboarded
Paywall view:            ~100% → 35,200
Paywall → trial/buy:     8%    → 2,816 new paying or trialing/mo
Trial → paid:            40%   → if 35% of 2,816 are trial-eligible (annual), ~990 trial-paid + 1,830 no-trial-paid = 2,820 conv-equiv
D90 paying retention:    ~30%
Blended ARPU/mo:         ~$6.50
Active paying subs at steady state: ~15,400
MRR:                     ~$100,000
```

What has to be true on each axis:

- **Installs ~40k/mo** — current ~5–6k/mo. Requires **~7x install growth**, almost entirely TikTok creator-driven, plus paid UA breakeven on Cal AI displaced budget.
- **Paywall → trial/buy 8%** — currently ~12.5% on the headline "TikTok→paid" cohort, but RC blended H&F is ~6–8%. **The headline number is misleading: 12.5% across very low denominator. As volume grows, expect regression to 6–8%.**
- **Trial → paid 40%** — RC 2026 H&F median 25.5% for 3-day, 45% for 5-9-day. 40% is achievable but requires the trial-day-2 modal + reframe screen + price-anchor lift. We have NONE of these shipped.
- **D90 retention 30%** — H&F median ~16% on annual; achievable with Sprint C plateau intervention + DPP nudges + the curriculum being a real retention loop (75% lesson completion already proven).
- **Blended ARPU $6.50/mo** — annual-led mix at $47.99 + 25% quarterly + 5% weekly + ladder lift in M6+.

### A3. Smallest realistic axis to move

Ranked by leverage × confidence × dev-days:

1. **Tier-mix correction** (FREE / 1 dev-day). Code change in `PaywallView.swift:534` — flip `goalSolvableInTwelveWeeks` default from quarterly → annual. Expected ARPU/LTV lift +25-40%. (See B2.)
2. **In-trial Day 1/2/3 sequence** (4 dev days, see strategy Pillar 5). Expected trial→paid lift +5-12%.
3. **US 7-day trial A/B** (1 dev day). If US wins on 7-day, +20-50% on US base — and US is the install-volume opportunity.
4. **Annual price anchor $59.99 US-only** (1 dev day). H&F high-anchor 4.5× LTV per Adapty. Even at 50% conversion drag, math wins.
5. **Install volume via TikTok creator engine** (Sprint hard-to-time). Single highest-leverage axis but slowest to move. **Without this, the $100k floor is impossible** — even at perfect funnel, current 5–6k installs/mo caps MRR at ~$30-40k.

**This is an install-volume problem masquerading as a conversion problem.** Paywall conversion at 12.5% is already top-decile. The reason it looks so good is the denominator is tiny — TikTok converts at this rate for everybody at this volume; the regression-to-mean kicks in at 50k+/mo. The math says **install volume is the dominant axis; ARPU + retention are the multipliers that determine whether $100k MRR is profitable or burns cash.**

### A4. The quarterly-outsells-annual problem in plain numbers

From the 7-day data:

- 29 quarterly @ $24.99 / 3mo = $724.71 collected, ~$8.33/mo run-rate per sub × 29 = $241.51/mo
- 7 yearly @ $47.99 / yr = $335.93 collected, ~$4.00/mo run-rate × 7 = $28.00/mo
- 7 weekly @ $5.99 / wk = $41.93 collected, ~$25.96/mo run-rate × 7 = $181.71/mo
- 1 yearly_discount = ~$3.00/mo

Total monthly-equivalent run-rate: **~$454/mo on $1,100 of 7-day collected revenue.** The collected revenue is misleadingly high because quarterly bills upfront. The actual *MRR contribution* — the recurring base that will refill next month — is much smaller.

At the locked grandfather ladder, **every quarterly customer is a future annual customer who was caught at the wrong door.** The quarterly tier exists to match goal-horizon language ("12-week becoming") but in current mix it cannibalizes annual at 4:1.

---

## B. Pricing posture for the next 90 days

### B1. Ship the v2 ladder ($54.99 → $79.99 → $99.99)?

**No — not in the next 60 days.** Reasons:

- **Per `project_pricing_locked_v1_0_7.md`**, the ladder is **gated on shipped surface area**: v1.5 = longer workouts + JeniMethod expansion ($54.99), v2 = food rail + Jeni AI agent ($79.99), v3 = body scan ($99.99). Today's v1.0.9 ships ~v1.0 surface. Lifting price to v1.5 anchor without v1.5 surface is the Cal AI move that Apple pulled them for in April 2026 (deceptive value perception).
- Brand integrity per `feedback_clean_luxury_aesthetic.md`: clean-luxury positioning compounds when price moves *with* substance. Decoupling them trains discounting expectation.
- The bigger near-term lever is **converting the existing $47.99 anchor better**, not raising it. The PostHog data shows 12.5% TikTok → paid at $47.99; there is no evidence the price is the floor on conversion.

**Recommendation:** ship v1.5 ($54.99 ladder bump) when **JeniMethod 84-lesson curriculum** is live (Sprint B, Day 60). Stage v2 ($79.99) when food rail + correction flywheel ships (Sprint D, Day ~180). v3 ($99.99) waits for sister-cohort SKU and body scan. **Do not ship a ladder bump in the absence of surface.**

**Exception (US-only A/B, run inside 30 days):** test $59.99 yearly anchor for net-new US installs only, via separate RC offering. If conversion drag is <40% and LTV-uplift > drag (math: $59.99 × 0.60 retained > $47.99 × 1.0 retained), promote and keep. Cost: ~1 dev day + 2 weeks data.

### B2. The quarterly SKU dilemma

The 4:1 revenue-mix-vs-annual signal is **NOT a price preference**. It's a **default-selection artifact** of:

- `PaywallView.swift:534` — `goalSolvableInTwelveWeeks` auto-selects quarterly. Most onboarding users with a weight goal that fits ACSM 12-week pace land here.
- `paywallBenefits` slot shows symmetric weight on all tiers (no price-anchor pull).
- Quarterly has **no trial** (per `project_trial_downsell_locked.md` — annual-only trial). User who lands defaulted on quarterly and is ready to buy is more likely to convert immediately than the user who lands on annual + sees a 3-day trial timeline (which adds friction even though it should reduce risk).

**Risk if quarterly stays as the goal-aware default:**

1. **LTV compression.** Quarterly LTV at 25% renewal × 4 quarters = 1.56 quarters × $24.99 = $39 LTV. Annual LTV at 25% annual renewal = 1.25 years × $47.99 = $60 LTV. **Quarterly default is destroying ~$21/sub in LTV** even at identical retention rates. RC 2026 actually shows annual renewal *outperforms* quarterly renewal in H&F (~25% vs ~22% Y1), so the gap widens.
2. **Trial-funnel cannibalization.** Every quarterly-default user is a user who never saw the annual trial offer. Per RC 2026 and Adapty 2026, trial-starts convert at 25-45% to paid annual; non-trial purchases convert at ~100% but at lower LTV. We are giving up the trial mechanism entirely on goal-fit users.
3. **Apple "one intro per group" lock.** Quarterly bought today permanently locks the user out of the annual trial. They can never enter that funnel.

**Recommendation 30-day:**

- Flip default in `PaywallView.swift:534` from quarterly → annual for goal-solvable users. **Quarterly stays on the tier row, just not pre-selected.** Goal-horizon language voice signal stays intact ("12-week becoming") because the tier IS visible.
- Add a 4-hour code change: surface quarterly **with trial** by structuring the offering so quarterly trial doesn't lock annual trial. This is technically possible via Apple's subscription groups if quarterly and annual sit in *different* groups (cost: small RC + ASC reconfig). Without this, quarterly-with-trial is impossible.
- Run a 14-day A/B: annual-default vs quarterly-default. Measure blended ARPU AND retention AND trial-→-paid. Decide on Day 14.

### B3. The 3-day annual trial

Evidence on trial-length conversion is genuinely thin in public sources. RC 2026 H&F: 25.5% 3-day vs 45% 5-9-day, but the gap is confounded by cohort selection (apps that ship 7-day trials have different audiences than 3-day).

**Recommendation:**

- **Stay at 3-day for the global default.** Per `feedback_founder_pricing_intuition.md`, founder's 3-day call has been right; Cal AI used 3-day with the closest cohort fit.
- **Run a US-only 7-day trial A/B inside 21 days.** Configure as a separate RC offering, segment via Apple region or RC custom attribute. Measure: trial-start rate × trial→paid rate. The two numbers move in opposite directions for trial length (longer trial = more starts, lower conversion); winner is the product.
- **If 7-day wins on US blended ARPU**, ship globally with US-first rollout. **If it doesn't move**, the answer is the in-trial sequence, not the trial length.

### B4. 30 / 60 / 90-day tier architecture

| Horizon | Annual | Quarterly | Weekly | Notes |
|---|---|---|---|---|
| **30d (today + tier-mix fix)** | $47.99 / 3-day trial / **default** | $24.99 / **visible but not default** | $5.99 / **drop from primary paywall, winback-only** | Strategy doc Pillar 5.1 + tier-mix correction |
| **60d (post-Sprint A data)** | US-A/B $59.99 + 7-day trial | $24.99 stays | Weekly stays winback-only | Layered tests, decide by Day 60 |
| **90d (post-Sprint B curriculum)** | $54.99 / 3-day trial (v1.5 ladder bump) | $29.99 (sympathetic raise) | Winback-only $5.99 | Sprint B ships curriculum, ladder bump *earned* by surface |

Locked grandfather ladder per pricing-memory remains intact — every existing customer stays at original price forever.

---

## C. The 22× math: where each multiplier comes from

Ranked: highest-leverage × highest-confidence first. Honest about which are speculative.

### C1. Install volume — **~4x** (the dominant axis)

- **Move:** TikTok creator engine, paid UA on Cal-AI-displaced budget, CPP localization (food-first / trend-first / plank-first variants).
- **Quantification:** current ~5–6k/mo; target 20–25k/mo by month 6, 40k+/mo by month 12. Cal AI was doing ~150k installs/wk pre-pull (Sensor Tower); even 5% of displaced budget moving to JeniFit is 7-8k/wk additional.
- **Evidence strength:** HIGH on direction, MEDIUM on magnitude. The 4x is achievable but requires creator-led acquisition the team hasn't proven at scale yet.
- **Risk:** TikTok algorithm volatility, post-SkinnyTok moderation tightening, paid UA breakeven hard to confirm at low retention.

### C2. ARPU correction via annual-default — **~1.5–1.8x** (highest-confidence single move)

- **Move:** Flip `PaywallView.swift:534` default to annual; drop weekly from primary; surface quarterly as alt-not-default.
- **Quantification:** Current mix yields ~$8.25/mo blended on confused tiers. Annual-default mix yields ~$5.60/mo nominal but LTV-equivalent of $9-12/mo because annual cohort retains 6-12 months vs quarterly 1.5 quarters. The MRR ratio at steady state is 1.5–1.8x.
- **Evidence strength:** HIGH. Code-change + RC dashboard reconfig.
- **Caveat:** the change *lowers* this month's collected cash (quarterly is upfront 3-month). It raises LTV starting month 4.

### C3. Retention via DPP nudge engine + plateau intervention — **~1.4–1.5x**

- **Move:** Strategy doc Pillar 4 — DPP scheduled coach-text engine (NOT a chatbot), Day 21 plateau letter, weekly streak only.
- **Quantification:** DPP RCT showed 38.5% vs 21.5% ≥3% weight loss with daily text. Retention proxy in WL apps: +50-80% D60. Conservative 1.4x.
- **Evidence strength:** HIGH on mechanism (DPP RCT); MEDIUM on JeniFit transferability.

### C4. Trial-to-paid lift via in-trial Day 1/2/3 sequence — **~1.15–1.35x trial**

- **Move:** Strategy doc Pillar 5.1 — Day 2 "almost done" reward modal, Day 3 emotional reframe, in-app notifications.
- **Quantification:** Adapty/Superwall H&F: +8-15% trial-to-paid on the modal alone, +30% on the reframe screen, +5-12% on the notification sequence. Compounded: +15-35%.
- **Evidence strength:** MEDIUM-HIGH (Adapty data, Superwall case studies cited in strategy doc).

### C5. Sister-cohort SKU $79-99/quarter — **+0.5-1.0x ARPU on top-decile** (the 10x LTV bet)

- **Move:** Strategy doc Pillar 4.4 — voice-only women-only opt-in micro-cohorts, gated by program day.
- **Quantification:** 20% upgrader rate × $316 ARPU vs $48 baseline = blended LTV $62 → $180-220 within 18 months. Founder's locked memory `project_v2_strategy` calls this the 10x bet.
- **Evidence strength:** LOW-MEDIUM on JeniFit specifically. HIGH on community-as-retention literature (Crossfit / Peloton / AA 2.3-3.8x retention multiplier). **Validate via 12-day beta to top-100 D30-retained users; decide on Day 90 of beta.**
- **Speculative — do NOT count on this for the 22x base case. It's the swing variable.**

### C6. Geo-tier PPP pricing for emerging markets — **+5-10% global revenue**

- **Move:** Per the deferred-to-v1.0.8 item in pricing memory — PH/CO/MX/BR/IN/TR/EG/ID/VN/TH at ~40% of US ladder.
- **Quantification:** 25% of paywall views currently see US prices at 1.7-3% local median monthly income. PPP pricing typically lifts conversion 2-4x in target markets at ~50% gross margin. Blended: +5-10% global.
- **Evidence strength:** HIGH on direction (RC 2026 PPP data); LOW on JeniFit-specific magnitude.
- **Dev cost:** ~1 day RC geo-config.

**Combined math (conservative, no sister-cohort):**

4.0 (installs) × 1.6 (ARPU correction) × 1.4 (retention) × 1.2 (trial-to-paid) × 1.07 (PPP) = **~14.5x**

To clear 22x: need either (a) install volume hitting 5x not 4x, or (b) sister-cohort SKU executing on the top decile, or (c) annual-renewal economics compounding past month 18 (high-confidence given annual cohort retention).

---

## D. Risks

### D1. Push too hard on price

- **What breaks:** US install-to-trial collapses. Cal-AI-trained cohort fact-checks against MFP free tier + screenshot-shares paywall complaints on TikTok. Brand "clean-luxury" undermined if price isn't backed by surface.
- **Mitigation:** Tie every ladder bump to a shipped feature. Run all price tests US-only with separate offerings — no global irreversible moves.

### D2. Quarterly cannibalizes annual permanently

- **What breaks:** if quarterly stays default and converts at 4:1, the user base becomes structurally lower-LTV. Apple's "one intro per group" rule makes this irreversible per user — every quarterly buyer is permanently disqualified from the annual trial.
- **Mitigation:** Flip the default inside 14 days. Annual trial users who decline can be offered quarterly on later open. Quarterly-as-default is the soft-default trap.
- **Code-level finding:** This is a single-line change at `PaywallView.swift:534-536`. The risk of leaving it as-is for another week is material.

### D3. Apple App Review (Guideline 5.6 + 3.1.2)

- **Cal AI was pulled April 2026** for: (a) "$0.92/wk · billed $47.99/yr" weekly-equivalent display on annual card (now removed from JeniFit per `yearlyPerWeekText` at PaywallView.swift:377-398 — verified compliant), (b) cancel-flow hostility, (c) the "decline first offer → second discounted subscription" downsell pattern.
- **JeniFit compliance status:**
  - ✓ Weekly-equivalent display removed (now "save vs quarterly" framing).
  - ✓ Downsell unwired (`PlankAIApp.swift:649-664` confirms `onPurchaseCancelled` fires analytics only, no discount paywall).
  - ✓ Trial timeline is 3-row explicit ("today / day 2 / day 3").
  - ✓ Charge date literal (`chargeDateText`).
  - **Watch:** if the v2 ladder ships without surface backing, Guideline 5.6 (consumer trust) risk re-opens. Don't decouple price from surface.

### D4. App Store policy on post-Ozempic positioning

- **Cohort positioning risk:** "behavioral version of GLP-1 food-noise suppression" is the locked strategic wedge. Apple has not yet flagged behavioral-equivalent-of-pharmacology claims, but the line is thin.
- **Mitigation:** Voice rules (no AI, no labor verbs, anti-shame, permission frame) already insulate. Keep marketing copy *adjacent* to GLP-1 (food noise, satiety) not *claiming equivalence to* GLP-1. Brand voice as legal moat.
- **TikTok policy adjacent risk:** SkinnyTok deplatformed June 2025. Direct-restriction creator content is UA-unsafe. The audience research lane already flagged this — keep TikTok ads in identity-becoming register, not before/after / restriction register.

### D5. The retention assumption is load-bearing

- **What breaks:** If D90 retention can't reach 30% (vs H&F 16% baseline), the LTV math collapses. The strategy assumes the CBT curriculum + plateau intervention deliver this lift.
- **Mitigation:** Sprint C ships safety + retention. Measure D30 retention as early-warning by Sprint B-end (Day 60). If <22% D30, escalate before counting on D90 30%.

---

## E. KPIs to watch weekly

The 7 numbers that tell you whether $100k MRR is on track:

1. **Weekly install volume** (target trajectory: 1,200 → 5,000 → 10,000 per week by month 6). PostHog `$set_once` first_seen.
2. **Trial-start rate** as % of paywall_view (target: 12-15% at scale). PostHog event `trial_start` / `paywall_view`. **Single most diagnostic number.**
3. **Trial → paid conversion** (target: 40%). RC dashboard or PostHog `purchase_completed` filtered to `is_trial=false` and `period_type=normal` divided by `trial_start`. **Don't confuse with paywall conversion.**
4. **Annual mix as % of new paid** (target: 60%+; today: 19%). RC dashboard `Active Subscriptions by Product`. **The structural defect indicator.**
5. **D30 paying retention** (target: 60% by Sprint C ship). RC dashboard cohort retention.
6. **D7 activation rate** (≥4 logs + ≥1 weight) (target: 60% of trial starters). PostHog cohort query.
7. **Blended ARPU per active sub per month** (target: $5.50 → $7.50 by month 6). Computed metric: total revenue / active_subs / month.

**Do not track:**
- "Total revenue" — masks the mix problem.
- "Paywall views" — vanity in absence of trial-start denominator.
- "Downloads from TikTok specifically" — attribution is broken in 2026, use total install volume + survey attribution.

---

## Code-level findings

Surprises grounded in current code (1.0.9, post-1.0.7 paywall rescue):

### F1. Goal-aware default still selects quarterly (`PaywallView.swift:534-536`)

```swift
if goalSolvableInTwelveWeeks && (quarterlyPackage != nil || debugMockPricing) {
    selectedPlan = .quarterly
}
```

- This is the single highest-leverage code change in the app today. Most onboarded users have ACSM-12-week-solvable goals → quarterly default → no trial → no annual entry → LTV compressed.
- Recommended diff: gate this behind a feature flag, default flag OFF, run A/B annual-default vs quarterly-default for 14 days.
- File: `/Users/bko/plankAI/PlankApp/Views/Paywall/PaywallView.swift:534`.

### F2. `default_plan` analytics is hardcoded to "annual" but actual default flips to quarterly (`PlankAIApp.swift:675`)

```swift
"default_plan": "annual",
```

- Fires on every `paywall_view` regardless of the goal-solvable flip above. PostHog tier-mix analysis is reading misleading data. Funnel queries that bucket by `default_plan` are inaccurate.
- Recommended: pass actual `selectedPlan.rawValue` after the `.task` flip resolves, or emit a separate event when the default selection settles.
- File: `/Users/bko/plankAI/PlankApp/PlankAIApp.swift:675`.

### F3. Weekly SKU still on primary paywall (`tierCardWeeklyCompact`)

- Strategy doc explicitly recommends dropping weekly from primary paywall, keeping as winback-only.
- Three reasons: (a) weekly's $5.99/wk = $25.96/mo run-rate is misleadingly high but churns at 54% (RC 2026); (b) weekly cannibalizes annual when present as a "try-it-first" psychological out; (c) reserving weekly for winback (post-cancel) recovers 10-34% of churners per Churnkey average.
- Code change: ~4 hours. Remove `tierCardWeeklyCompact` from `tierRowHorizontal`. Keep `RevenueCatConfig.ProductID.weekly` and `weeklyPackage` resolution intact — wire into a future `WinbackPaywallView` (M3 per strategy roadmap).
- File: `/Users/bko/plankAI/PlankApp/Views/Paywall/PaywallView.swift:678-682`.

### F4. Discount SKU constants are dead-code in 2026-06 (`RevenueCatConfig.swift:75-89`)

- `yearlyDiscount`, `quarterlyDiscount`, `weeklyDiscount` + `V2.yearlyDiscount` constants resolve but:
  - `onPurchaseCancelled` fires analytics only (`PlankAIApp.swift:649-664`), no downsell sheet.
  - `discountOfferingID` (`discount`) is referenced only by `DownsellPaywallView.swift` which is unwired.
- Recommendation: leave on disk (per locked memory, file is dormant for future reactivation in v1.2). No action; just call out that the constants are inert. **Risk-free** but flagging for posterity.
- File: `/Users/bko/plankAI/PlankApp/Config/RevenueCatConfig.swift:75-89`.

### F5. V2 product ID indirection is partially wired (`RevenueCatConfig.swift:99-106` + `PaywallView.swift:242-245`)

- `yearlyPackage` and `weeklyPackage` accept both legacy (`absmaxxing_yearly`, `absmaxxing_weekly`) AND V2 IDs (`jenifit_yearly_v2`, `jenifit_weekly_v2`). Good defensive pattern.
- Quarterly is NEW (no legacy) and resolves only `jenifit_quarterly`. Confirmed.
- The V2 indirection means swapping from `absmaxxing_*` IDs in ASC requires only flipping which products are in the RC `default` offering — no code change. **This is well-designed for the v2 ladder migration when it ships.**
- File: `/Users/bko/plankAI/PlankApp/Views/Paywall/PaywallView.swift:242-265`.

### F6. The "save $51.97 vs quarterly" anchor copy is hardcoded (`PaywallView.swift:660`)

```swift
Text("save $51.97 ♥")
```

- Doesn't recompute when RC offering prices change. If you raise annual to $54.99 or $59.99 in an A/B, this row anchor lies.
- Recommended: derive from `yearlyPerWeekText` math at PaywallView.swift:377-398, which already computes `quarterlyAnnualized.subtracting(yearlyPrice)`.
- File: `/Users/bko/plankAI/PlankApp/Views/Paywall/PaywallView.swift:660`.

### F7. `paywall_view` fires per-render not per-presentation (`PlankAIApp.swift:666-679`)

- `.onAppear` on the cover's content can fire multiple times across app lifecycle re-renders (auth transitions, splash → paywall, etc.). PostHog `paywall_view` count may overstate; PaywallView's own `.task` capture via `Analytics.captureScreen("Paywall")` is the cleaner signal.
- Lower priority but affects funnel denominator. Worth a 1-day cleanup pass before scaling traffic.
- File: `/Users/bko/plankAI/PlankApp/PlankAIApp.swift:666`.

---

## What I'd do in the next 7 days

If I were running this, ordered:

1. **Today (15 min):** flip `PaywallView.swift:534` to annual-default. Ship as a small build. Watch PostHog `default_plan` (after also fixing F2) for 7 days.
2. **Day 1-3:** ship Day 1/2/3 in-trial notification + reframe sequence per strategy Pillar 5.1. 4 dev days; the highest-confidence multi-axis lift available.
3. **Day 2-3:** drop weekly from primary paywall (`tierCardWeeklyCompact` removed from `tierRowHorizontal`). Configure as winback-only in RC for the M3 winback flow.
4. **Day 4-5:** configure US-only A/B in RC offerings: separate offering with $59.99/yr + 7-day trial. Geo-target. Run 21 days.
5. **Day 6-7:** set up the 7 KPIs above in a single PostHog dashboard. Tag it `North-Star-Weekly`. Review every Friday.

That's the next 90 days of the strategy doc compressed into a week of pricing-side moves. The longer work (Sprint A in-trial, Sprint B curriculum, Sprint C retention, Sprint D differentiation) carries the multipliers that close the gap to $100k MRR.

---

*End of report. Confidence assessment: install volume axis (LOW confidence on magnitude, HIGH on direction), ARPU correction (HIGH), retention via curriculum + nudges (MEDIUM-HIGH), sister-cohort SKU (LOW-MEDIUM — load-bearing speculation). Sources synthesized: code reads at PaymentService.swift, PaywallView.swift, RevenueCatConfig.swift, PlankAIApp.swift; founder memories (pricing-locked, trial-downsell-locked, founder-pricing-intuition, v2-strategy); RC 2026 H&F benchmarks (verified); Adapty 2026 trial-conversion data (verified via strategy doc); Cal AI App Store pull April 2026 (verified). Where evidence is thin (trial-length specific conversion claims, sister-cohort transferability), I've called it out inline.*
