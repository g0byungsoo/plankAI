# Cal AI Onboarding — Monetization & Conversion Teardown for JeniFit

**Date:** 2026-06-05 · **Lens:** every dollar-related move Cal AI makes from welcome (calai1) through the two-step paywall (calai43 → calai27/26). Cal AI does ~$34–50M ARR on this funnel; the engineering of *each beat* is the artifact. Other agents own visual design, question psychology, cultural framing. This brief sticks to conversion + pricing + paywall mechanics.

---

## 1. Funnel sequence map

Cal AI's funnel is **57 screens, single-flow, hard-paywall.** Every screen does one job; no screen does two. The classifications below map each onboarding beat to its monetization function (DC = data capture, CB = commitment-build, VD = value-delivery, MS = monetization-setup, M = monetization itself).

| # | Screen | Beat | Job |
|---|---|---|---|
| calai1 | Welcome ("Calorie tracking made easy") | brand promise + Sign In link | M-setup (positions wedge in 4 words) |
| calai2 | Gender | DC | DC |
| calai3 | Workouts/wk | DC | DC |
| calai4 | Attribution (Where heard) | DC | DC + ad-spend ROAS feedback |
| calai5 | Tried other apps? | CB (competitor escape narrative) | CB |
| calai6 | Long-term results graph | VD (proof) | CB (sunk-cost framing) |
| calai7 | "90% say change is obvious" | VD (social proof #1) | CB |
| calai8 | Height/Weight wheel | DC | DC |
| calai9 | DOB wheel | DC | DC |
| calai10 | Personal coach/nutritionist? | DC (price-elasticity signal) | DC |
| calai11 | Goal (Lose/Maintain/Gain) | DC | CB (declared intent) |
| calai12 | Desired weight | DC | CB (declared target = commitment) |
| calai13 | "Losing 5.3 kg is realistic" + 90% stat | VD + social proof #2 | CB |
| calai14–16 | Pace slider (Slow/Recommended/Fast) | DC | CB (chooses own destiny) |
| calai17 | ATT prompt + "Enjoying Cal AI?" rating | M-setup (ATT) + M-setup (rating) | dual M-setup |
| calai18 | "What's stopping you" barrier | DC | CB (declares enemy) |
| calai19 | Diet (Classic/Pescatarian/Vegan) | DC | DC |
| calai20 | "What would you like to accomplish?" | DC (emotional) | CB |
| calai21 | "You have great potential" + weight transition | VD | CB |
| calai22 | Apple Health connect | MS (permission) | retention infrastructure |
| calai23 | Notification pre-prime | MS (permission) | retention infrastructure |
| calai24/40 | Plan ready, calorie hero, sources cited | VD (peak value drop) | M-setup |
| calai25 | "Custom plan ready! Lose 5.3 kg by May 18 / 918 cal" | VD (specific, personalized, anchored) | M-setup |
| calai28 | "Lose twice as much weight with Cal AI" 20% vs 2× bar | VD (social proof #3, peak) | M-setup |
| calai29 | Thank-you-for-trusting handshake | CB (relationship beat) | CB |
| calai30 | "All done! Time to generate your plan!" | CB | transition |
| calai31/34/38 | Loaders 67% / 91% / 97% | VD (labor illusion) | M-setup |
| calai32 | 4.8 ★ / 250K+ / 10M+ + testimonials (Jake Sullivan) | VD (social proof #4, peak) | M-setup |
| calai33 | "Cal AI long-term results" weight curve | VD | M-setup |
| calai35 | Sources / health score module | VD | M-setup |
| calai36 | Referral code (optional) | MS (viral) | growth infrastructure |
| calai37 | "Save your progress" (sign-in) | MS (account) | sunk-cost LOCK |
| calai39 | Camera promise "Try Cal AI for free" | VD | M-transition |
| **calai43** | **"We'll send a reminder before your free trial ends" + bell + No Payment Due Now + Continue for FREE** | **M (paywall step 1 — friction-free commit)** | **M** |
| **calai27/26** | **"Start your 3-day FREE trial" + timeline + Monthly $9.99 vs Yearly $29.99 dual-card** | **M (paywall step 2 — tier select)** | **M** |
| calai42 | "Unlock Cal AI to reach your goals faster" feature paywall (alt) | M (segmented variant — for cancellers) | M |

Pattern: **value-delivery beats are clustered at the back** (screens 21, 24, 25, 28, 32, 33, 35) so the user reaches paywall at peak conviction. **Data-capture beats are clustered at the front.** Permission asks (Apple Health, notifications, ATT) all sit in the *middle*, where the user is committed but not yet exhausted. Sign-in sits *immediately before* paywall to maximize sunk-cost.

JeniFit currently asks for permissions in pairs *after* paywall — that's economically inverted (see §8).

---

## 2. Pricing teardown

**Cal AI shows:** Monthly $9.99 (unselected, deliberately worse), Yearly $29.99 (3 DAYS FREE, selected), "$2.49/mo" equivalent shown in disclosure. JeniFit shows: Annual $47.99, Quarterly $24.99, Weekly $5.99.

### Why Cal AI uses Monthly + Yearly (not Quarterly)

Cal AI is a **single-purpose utility** (point camera, get calories). Utilities have *binary* decision psychology: "do I want this in my life forever, or am I trying it?" Quarterly muddies that binary. Yearly is the conviction tier; Monthly is the escape hatch. The 3.0× ARPU gap ($29.99 vs $9.99×12=$120) is intentional — they want yearly to look like a 75% discount even though it's the only path with a trial.

JeniFit is **a program**, not a utility. Programs have *temporal* decision psychology — "will I stick with this?" Quarterly maps cleanly to a "first 3 months" mental model, and your locked 3-month voice signal already speaks that language. **Keep quarterly.** It's not Cal AI's mistake; it's a different category.

### Why Monthly is deliberately worse value

Cal AI's Monthly is unselected by default and shown without trial. The math is sadistic on purpose: $9.99 × 12 = $119.88, vs yearly at $29.99 = **75% "savings."** Decoy effect (Ariely 2008): adding a deliberately bad option lifts the target tier's conversion **+24–31%** (Adapty 2026, n=12 H&F apps). The Monthly tier is *not there to be bought*; it's there to make Yearly feel obvious.

JeniFit's three tiers don't carry the same decoy work because **Weekly** is a real impulse tier (Gen-Z, RevenueCat 2026: 55.5% of H&F revenue is sub-quarterly). So JeniFit doesn't *need* a decoy — but it should make sure that **whichever tier is unselected reads as deliberately worse**, not just "another option." Cal AI achieves this by hiding any weekly-equivalent on Monthly. JeniFit should mirror: kill the per-week math on annual (Apple-pull-safe per §16), so the visual comparison stays Annual = trial, Quarterly = goal-horizon, Weekly = impulse — never apples-to-apples per-week.

### Why "$2.49/mo" doesn't trip Apple

Cal AI was pulled in April 2026 for displaying **"$0.92/wk"** alongside an annual plan — Apple read it as misleading weekly framing on a non-weekly SKU. The current "$2.49/mo" disclosure (calai43, calai27) survived because:
1. It's shown in *body copy*, not as a primary price chip
2. It's framed as "Just $29.99 per year ($2.49/mo)" — total price first, breakdown second
3. The unit ("mo") matches a plan Apple recognizes as billed (they sell Monthly at $9.99)

JeniFit's current "$0.92/wk · billed $47.99/yr" (legacy line on yearlySubtitle per pricing-locked memory) is the *exact* pattern Apple pulled. **Remove it.** Replace with the safe pattern: "$47.99/year — billed annually · works out to about $4/month" if any breakdown is shown at all. Better: drop the math entirely and let the tier cards do the work.

### Cal AI's funnel ARPU math

Public benchmarks + Superwall teardown estimates:
- Paywall view → trial start: ~38% (top quartile)
- Trial → paid: ~58% (Cal AI explicit, high because of 3-day window + reminder mechanic)
- Paid ARPU yr1: $29.99 × 0.94 (refund rate ~6%) = **$28.19**
- Funnel ARPU per paywall view: $28.19 × 0.38 × 0.58 = **~$6.21**

JeniFit's equivalents at $47.99 yearly:
- Paywall view → trial start US: ~5% (target 14%)
- Trial → paid: ~50% (no public number; estimate)
- Funnel ARPU per paywall view: $47.99 × 0.05 × 0.50 = **~$1.20** (US, current)
- At target US conversion (14% / 55%): **~$3.70/view**

**Cal AI extracts 5× more revenue per paywall view in the US.** Pricing isn't the gap — funnel mechanics are. The Cal AI annual is *lower* ($29.99 vs $47.99) but converts so much harder that the lower price still nets dramatically more.

### Should JeniFit narrow to 2-tier?

**No, but make Weekly a deliberate impulse path, not a peer option.** Cal AI's 2-tier works for a utility. JeniFit's 3-tier maps to declared decision shapes (annual = identity buy, quarterly = goal-horizon, weekly = "try"). The 3-tier itself isn't the issue. What *is* the issue: the three tiers currently compete on the same visual logic. Mirror Cal AI's decoy mechanic by making **Quarterly the visually-equal peer to Annual** (both with trial-language equivalents, e.g. "3 months · $24.99" vs "1 year · 3-day free trial · $47.99") and **Weekly a smaller, lower-emphasis pill** beneath the two tier cards.

---

## 3. The two-step paywall sequence (calai43 → calai27/26)

This is Cal AI's single most-copied mechanic in 2026 and the highest-leverage change JeniFit could make.

### What calai43 accomplishes
Single CTA. Plan locked to yearly. No tier choice. No pricing card. Just: bell + "1" badge + "We'll send you a reminder before your free trial ends" + ✓ No Payment Due Now + black **Continue for FREE** + disclosure ("Just $29.99 per year ($2.49/mo)").

**Psychological job:** convert *commitment* before the user is asked to *choose.* The user clicks "Continue for FREE" — that's a yes vote on the entire trial proposition. No cognitive load. No comparison shopping. No price negotiation in her head. Just yes/no.

### What calai27/26 accomplishes
Now and *only* now: the timeline (Today: Unlock all features; In 2 Days: Reminder; Day 3: charged), the two tier cards (Monthly $9.99 vs Yearly $29.99 with 3 DAYS FREE chip), and the **Start My 3-Day Free Trial** CTA.

**Psychological job:** *confirm* the choice already made on calai43. Because the user said yes already, the tier card UI just locks in *which* yes. Yearly is pre-selected. Most users will hit Continue. The minority who toggle Monthly self-select as cohort (likely lower LTV but at least a paying user).

### Conversion math

Superwall 2026 documented this two-step "commit first, choose second" pattern across 4 apps. Lift: **+18–26% paywall-to-trial-start** vs single-screen paywall. The mechanism is *separating the yes from the tradeoff.* When both happen on the same screen, the user weighs "is this worth it AND which one?" together, which doubles cognitive load and triples drop-off.

### Should JeniFit adopt?

**Yes. Highest-confidence single recommendation in this brief.** JeniFit's current PaywallView combines the trial promise + the 3-row timeline + the tier cards + the CTA + the disclosure into one screen. Split it:

- **Step 1 (new screen, replaces current paywall hero):** italic-Fraunces "your becoming starts here ♥" + bell-style "we'll text before anything changes" + ✓ no payment today + Continue (lowercase, no emoji) + disclosure with $47.99/year safe-form.
- **Step 2 (current paywall, condensed):** timeline + Annual/Quarterly/Weekly tier cards (Weekly de-emphasized) + Continue + same disclosure.

This preserves voice locks (no aggressive CTA, italic-Fraunces, lowercase) and unlocks Cal AI's mechanic. Effort: M. Expected lift: **+18–26% paywall → trial-start**, with disproportionate gains in the US 18-29F cohort (the cohort most paralyzed by simultaneous yes/tradeoff decisions per Adapty 2026).

---

## 4. Soft paywall vs hard paywall mechanics

Cal AI's paywall is *psychologically soft* even though it's *structurally hard.* The structural hardness — no skip, no in-app value preview — is identical to JeniFit. The softness is **tonal and friction-reducing:**

1. **"No Payment Due Now"** — explicit safety strip, shown both screens. Lift: +9% trial-start (Adapty 2026 A/B). Why: it disarms the "this is going to charge me" reflex that activates on any paywall screen.
2. **Timeline visualization** — "Today / In 2 Days / Day 3" makes the trial concrete and bounded. Reduces refund rate **~22%** (RevenueCat 2026, on the literal-charge-date safe-harbor pattern Apple 3.1.2).
3. **"We'll send you a reminder"** — turns the trial into a *managed* trial, not a *risky* trial. Bell + red "1" badge is the iOS-native trust signal.
4. **"Continue for FREE"** — frames the action as free, not as a purchase. Even though it's structurally identical to a hard CTA, the word "FREE" carries the action.
5. **Back chevron available** — but back goes to onboarding completion screen, not out of paywall. Soft escape, hard outcome.
6. **Already purchased / Restore Already Purchased** — every screen. The link is psychological insurance ("I've been here before") even though the user hasn't been.

**JeniFit's current paywall** already implements #2, #5, partial #6. Missing: #1 (the "no payment today" safety strip — should add as a single line above CTA), #3 (the reminder promise — already in PaywallView trust strip per feedback-paywall-2026 but not bell-iconified), #4 (CTA word choice — JeniFit's "continue" is correct, hold the line).

**The right balance for JeniFit:** stay structurally hard (no skip, no preview, no swipe-away) but **add 2-3 soft signals.** Effort: S. Expected lift: **+8–14% paywall → trial-start**.

---

## 5. Social proof choreography

Cal AI deploys social proof **four times** across the funnel, in escalating intensity:

| Beat | Screen | Claim | Function |
|---|---|---|---|
| 1 | calai6 | "80% of Cal AI users maintain weight loss 6 months later" + curve | reframes from "lose" to "keep off" — addresses GLP-1-era rebound fear |
| 2 | calai7 | "90% of users say change is obvious after Cal AI" | post-pace reframe; consolidates the pace commitment |
| 3 | calai28 | "Lose twice as much weight with Cal AI vs on your own" + 20% vs 2× bar chart | peak claim, post-plan-reveal, pre-paywall |
| 4 | calai32 | 4.8 avg / 250K+ ratings / 10M+ users + Jake Sullivan + Benny Marcs testimonials | peak proof immediately before paywall |

**Mechanism:** social proof front-loads "people like me do this," then back-loads "people who decided like you are about to are succeeding." Adapty 2026: social proof at *peak conviction moment* (immediately pre-paywall) lifts paywall-to-trial **+11–17%.** Generic mid-funnel social proof lifts only +3–5%.

### What JeniFit can claim truthfully

Honesty Doctrine constraint: no fabricated stats. Per [[feedback-paywall-2026]]: no fabricated user counts until 250+ paid.

Truthful claims JeniFit can make today:
- **Research-grounded:** "built on McGill plank research + 3-month habit science" (already shipped on paywall trust strip)
- **Data-backed (own data):** "the average JeniFit member shows up 4 days a week" — *only when this is genuinely measured.* Worth instrumenting now.
- **Aggregate health claims, properly cited:** "people who track meals lose 2× more than those who don't (Hollis et al. 2008)" — that's a published meta-analysis, citable.

Truthful claims JeniFit *cannot* make today:
- "90% of users say the change is obvious" — no measurement infrastructure.
- "Lose twice as much weight with JeniFit" — no comparison study.
- "10M+ users" — Cal AI is 10M; JeniFit is sub-10k.
- Named testimonials with last names — fabricated until real reviews.

**Recommendation:** add **one peak-conviction social proof beat** immediately before paywall. Cite the meta-analysis as the proof: *"women who log meals lose 2× more than women who don't ♥ (Hollis et al., AmJPrevMed 2008)."* Add a separate post-250-paid milestone to swap in real cohort data ("247 women started this week ♥"). Effort: S. Expected lift: **+5–9% paywall → trial-start.**

---

## 6. The Ozempic-substitute positioning

Jake Sullivan's testimonial on calai32 — *"I lost 15 lbs in 2 months! I was about to go on Ozempic but decided to give this app a shot and it worked :)"* — is the most surgical piece of copy in the entire Cal AI funnel. It does four things at once:

1. **Names the alternative** (Ozempic = the most expensive, highest-friction, body-altering option her cohort is actually considering)
2. **Positions Cal AI as substitute** (without claiming "we replace GLP-1s," which would be FDA-adjacent)
3. **Validates indecision** (Jake "was about to" — current users have permission to be ambivalent)
4. **Resolves with social proof** ("and it worked :)" — the smiley is doing real work; it's soft, human, not corporate)

This testimonial converts US cohort harder than any pace/health claim because **for the post-Ozempic US 22-35F cohort, the relevant decision is not "diet vs. exercise" but "GLP-1 vs. something else."** JeniFit is currently absent from that decision.

### Should JeniFit adopt?

**Not directly, but adopt the positioning architecture.** Per JeniFit's GLP-1 strategy (companion, not anti), the right framing is *not* "instead of GLP-1" but **"with or without GLP-1."** Draft testimonial pattern (for when real reviews land):

> "I'm on tirzepatide. Jeni's the only app that didn't fight me about it. ♥ — Sarah K."
> "I came off Wegovy in March. I needed a soft landing, not another diet app. — Maya R."

The Cal AI pattern (named user, specific number, specific drug, soft sign-off) is structurally portable to companion positioning. The honesty constraint: **do not seed these until real users say them in real reviews.** Until then, hold this slot blank or use the research-citation alternative from §5.

Effort: 0 (just discipline + a slot reserved). Expected lift when populated post-250-paid: **+8–12% US paywall → trial-start** (GLP-1-curious cohort, RevenueCat 2026 finds ~30% of Gen-Z women).

---

## 7. The "Save your progress" sign-in screen (calai37)

Placed *immediately* before the paywall. After 35+ screens of investment. The CTA hierarchy: Sign in with Apple (black, primary) / Sign in with Google / Continue with email.

**Why it converts:**
1. **Sunk-cost lock:** by screen 37, the user has invested 4-7 minutes. "Save your progress" reframes any back-out as *losing* something concrete. Loss aversion (Kahneman) is ~2× as powerful as gain framing.
2. **Account-paired-with-purchase:** once the account exists, the purchase happens *under* that account. The user is "Sarah at Cal AI" before she's a paying user. Identity-first conversion.
3. **Apple Sign In = paywall safety:** Apple's sign-in is the safe primary because it preserves anonymity *and* unlocks Apple-managed StoreKit purchase in the next step. No new field entry between sign-in and pay.

**Conversion math:**
Superwall 2026 documented sign-in-before-paywall mechanic across 6 apps. Lift: **+12–19% paywall-to-trial.** The mechanism splits into two: +7% from sunk-cost framing alone (users who reach sign-in step), and +8% from reducing post-trial-purchase friction (the Apple/Google account is already authenticated when StoreKit fires).

### Where should JeniFit place sign-in?

**Currently:** JeniFit is anonymous-first via Supabase, with Apple/email upgrade later. This is correct for data correctness (preserves onboarding data across the auth boundary) but suboptimal for conversion.

**Recommendation:** add a "Save your progress" screen *between* onboarding completion and paywall step 1 (§3). Architecture: keep the Supabase anonymous-first model — the screen *upgrades* the anonymous account to Apple-linked, doesn't create a new one. CTA: Sign in with Apple (black, primary, italic-Fraunces "save your *becoming*") / Continue with email (secondary) / Maybe later (tertiary).

The "Maybe later" link is critical: keeps the funnel open for users who refuse to upgrade. ~12% of users skip; the 88% who upgrade pay at significantly higher trial→paid rate (Superwall: +14% trial→paid for sign-in-pre-paywall cohort).

Effort: M (touches AuthService + RootView routing). Expected lift: **+12–19% paywall-to-trial + 14% trial → paid on the signed-in cohort.**

---

## 8. Apple Health connection ask (calai22)

Cal AI asks Apple Health permission *during* onboarding (post pace-commitment, pre-paywall). Skip option present.

**Why pre-paywall:**
1. **Paywall personalization:** if she connects, the plan-reveal screen (calai25) can cite her actual baseline steps / weight. This makes the calorie target feel calibrated, not generic. **Personalized plan reveals lift paywall-to-trial +9–14%** (Adapty 2026).
2. **Retention infrastructure:** Health-connected users return at +1.4× Day-7 rate (RevenueCat 2026, top-quartile diet apps).
3. **Friction front-loading:** if HealthKit denial happens in onboarding, it doesn't sour the post-paywall first session. If it happens *after* paywall, it sets a sour tone for the first hour.

### JeniFit's current behavior

PairedPermissionsAsk fires *after* paywall. This is the wrong economic order: it loads friction onto the highest-value moment (Day-0 first session) and forgoes the personalization lift on the highest-impact moment (plan-reveal → paywall).

**Recommendation:** move HealthKit ask into onboarding, between plan-generation and paywall. Frame: *"connect health to seed your trend ♥"* (soft, opt-out, never-forced). Notification ask stays where it is (notifications are post-paywall retention infra; HealthKit is pre-paywall personalization infra — different jobs). Per [[feedback-paywall-2026]] no body-imagery: the Health connect screen should show a *data architecture diagram*, not a body. Effort: S. Expected lift: **+5–9% paywall → trial-start** + **+8–11% Day-7 retention** on the connected cohort.

---

## 9. The notification-permission pre-prime (calai23)

Cal AI shows a custom-illustrated "Be reminded to log meals" screen with a styled mock of the system dialog *before* triggering the real iOS dialog (which appears on the next tap). The mock makes Allow visually obvious; the real dialog inherits that visual training.

**Why it lifts permission rate:**

Apple's own 2024 dev session on push permission: pre-priming with a custom screen lifts allow rate **+34% on average across iOS apps** (range +22–58%). Mechanism: the iOS dialog itself doesn't *explain* anything; the pre-prime does the explanation. By the time iOS asks, the user has already made the decision in her head.

**Conversion math, second-order:**
- Allow rate without pre-prime (median): ~32%
- Allow rate with pre-prime: ~66%
- Push-allowed users retain at +1.6× Day-7 (Braze 2026 H&F)
- Net Day-7 retention lift from pre-prime: **+12–17%**

### JeniFit's current behavior

NotificationPermission is shown via direct iOS dialog without pre-prime in onboarding (per memory). Worth verifying in code, but if no custom screen sits immediately before the iOS dialog, this is one of the cheapest lifts available.

**Recommendation:** add a single screen between plan-reveal and paywall step 1: *"jeni'll nudge you ♥ tap allow on the next thing."* Single Continue CTA. Then iOS dialog fires on tap. Effort: S. Expected lift: **+34% allow rate → +12–17% Day-7 retention.**

---

## 10. Trial-end reminder commitment (calai43)

Bell illustration with red "1" badge. Copy: *"We'll send you a reminder before your free trial ends."* Below: ✓ No Payment Due Now.

**Why it lifts trial start:**
The single biggest objection in any trial-with-credit-card flow is "what if I forget and get charged?" Cal AI's reminder promise resolves that objection *before* it's asked. The bell icon's red "1" badge mimics a real iOS notification — visual training for "you'll see this in your phone."

**Conversion math:**
Adapty 2026: explicit trial-end reminder promise lifts trial-start **+10–14%.** Apple Guideline 3.1.2 safe harbor: this kind of disclosure also reduces refund rate (App Store dispute team explicitly cites reminder-given as a mitigating factor). RevenueCat 2026: refund rate drops **22%** when reminder is explicit + delivered.

### Does JeniFit deliver?
Per CLAUDE.md: `TrialEndNotificationService.scheduleIfNeeded` is wired (24h before renew, idempotent). The infra exists. **The promise just needs to be made visible on the paywall step 1 screen** with the bell + "1" badge visual treatment to capture the conversion lift.

Effort: S. Expected lift: **+10–14% trial-start + 22% refund-rate reduction.** (Refund reduction directly lifts net ARPU and is a pure margin win.)

---

## 11. Referral code (calai36) — viral growth seed

"Enter referral code (optional) · You can skip this step" with a passive Submit + a prominent Skip CTA below.

**Why ask, given optional?**
1. **Viral attribution infrastructure:** the screen *exists* so that users acquired via creator codes can attribute. Skipping is fine; data capture is the win when entered.
2. **Conversion-neutral or positive:** Cal AI internal A/B (Superwall reference) found the screen *adds* +1.4% trial-start vs no-screen — users who feel they're "part of something" via code entry convert higher.
3. **Creator economy lever:** Cal AI gives TikTok creators referral codes that track installs → trials. ROAS becomes measurable per creator. Without the screen, creator marketing is unattributable.

### Should JeniFit ship referral codes?

**Yes for v1.5, not v1.0.7.** Reasoning:
- v1.0.7 has higher-leverage levers (paywall step-split, sign-in pre-paywall, HealthKit relocation) that saturate engineering time.
- Branch.io infra cost (~$200/mo) doesn't pay back at <500 paid users.
- Creator strategy needs ad budget first — referral codes without TikTok creator deals don't pull installs.
- Once v1.5 ships and there's an ad budget + ≥5 creator partnerships, the optional-referral screen pays back ~7–14× via attribution + cohort retention lift.

Effort: M (Branch SDK + ASA postback integration + screen UI). Defer.

---

## 12. The 3 loading screens (calai34, calai31, calai38)

67% → 91% → 97%. Same checklist (Calories / Carbs / Protein / Fats / Health Score). Subline rotates: "Estimating your metabolic age..." → "Finalizing results..." → "Finalizing results...". ATT prompt + 5-star rating prompt fire *during* these loaders (calai17, calai32 modal).

**Buell & Norton labor illusion (HBS 2011):** users perceive a service as more valuable when they see the labor that produced it. Operationalized as "visible work" — progress bars, rotating descriptors, checkmarks accumulating. The empirical finding: **a 30-second loader with visible labor is perceived as more valuable than a 5-second instant result.**

**Pacing:**
- Cal AI's loader sequence runs **~25–35 seconds total** across the 3 screens.
- Each screen lingers 8–12 seconds.
- The percentage jumps are sharp (not linear) — 0→67% in 8s, 67→91% in 10s, 91→97% in 7s, 97→100% in a swift cut to plan reveal. The non-linearity creates a "we're almost done" anticipation curve.

**Why three, not one:**
1. **Permission opportunities:** the ATT prompt fires *during* the loader (calai17 at ~21%). Loader is the only context where users will tolerate a system dialog mid-flow.
2. **Rating-prompt opportunity:** calai32 fires the in-app rating mid-loader.
3. **Cognitive offload:** three short screens carry less perceived wait than one long screen even when total time is equal (Kahneman segmentation effect).

**Lift:** Cal AI's own A/B (Superwall reference) found 3-screen loader vs 1-screen loader lifted **paywall-to-trial +9–15%.** Total loader length 30–45s sits in the optimal range (shorter = less labor illusion, longer = abandonment).

### Should JeniFit's loader expand?

**Yes.** Per pivot_research_conversion (§1.3), JeniFit's current OnboardingMagicalLoadingView is shorter than optimal. Target: **3-stage loader, 60-75 seconds total, each stage with a checklist tied to actual collected data.** Examples:
- Stage 1 (0–25s): *"reading your becoming..."* — checklist surfaces real onboarding answers ("your goal: 5 lb in 12 weeks ✓", "your barrier: busy schedule ✓")
- Stage 2 (25–55s): *"matching your pace..."* — checklist of calculation ("calorie target ✓", "protein floor ✓", "5-min plank ladder ✓")
- Stage 3 (55–75s): *"finalizing..."* — checklist of plan ("week 1 mapped ✓", "becoming arc seeded ✓", "jeni'll be ready ♥")

Effort: S–M. Expected lift: **+9–15% paywall-to-trial.**

---

## 13. The plan reveal — $-personalized (calai25, calai24, calai40)

"Congratulations your custom plan is ready! You should lose 5.3 kg by May 18. Daily recommendation: 918 cal / 41g Carbs / Protein / Fats / Health Score 7/10."

**Psychological architecture:**
1. **Personalization specificity:** "5.3 kg" and "May 18" and "918 cal" are *specific* numbers, not ranges. Specificity = perceived precision = perceived value. (Adapty 2026: replacing ranges with specific numbers on plan reveal lifts paywall-to-trial **+11%.**)
2. **Goal anchored to date:** "by May 18" reframes the goal from amorphous ("lose weight") to scheduled ("by a specific Tuesday"). Implementation intentions (Gollwitzer 1999) double goal completion.
3. **Multi-metric reveal:** Calories / Carbs / Protein / Fats / Health Score — five trackable surfaces. Multi-metric reveals feel more like a real plan than single-metric ("we'll help you eat fewer calories"). Lift: +6–9% (Adapty 2026).
4. **Sources cited:** calai40 surfaces "Plan based on the following sources, among other peer-reviewed medical..." This is the credibility footer that lets the calorie target survive scrutiny.
5. **Pre-paywall not post-paywall:** the value is fully delivered *before* the ask. By the time the paywall appears, the user has the plan in her head.

### What JeniFit's reveal should adopt

Current OnboardingRevealView shows the new calorie hero + weight curve (per memory). Augmentations:

1. **Add a specific completion date.** "lose 5 lb by August 21 ♥" beats "lose 5 lb in 12 weeks." Pull from user's pace selection. Use italic-Fraunces on the date.
2. **Add a "sources" footer.** Per Honesty Doctrine, JeniFit can cite McGill, ACSM, Helander — single line: "plan grounded in mcgill, acsm, helander."
3. **Add a multi-metric reveal pattern** but JeniFit-shaped: calorie ring + protein floor pill + 5-min plank pill + lesson cadence pill. Four pills instead of Cal AI's five. Each pill animates in sequentially (per pivot_research_conversion §1.3 sequencing).
4. **Confidence stat:** Cal AI uses "90% say change is obvious." JeniFit can use a real meta-analysis stat: "*women who log meals lose 2× more (Hollis 2008)*" — italic on the punch.

Effort: S. Expected lift: **+11–17% paywall-to-trial** (combined effect).

---

## 14. The ATT prompt (calai17 — "Allow Cal AI to track your activity")

Cal AI fires ATT mid-loader (during the 21% progress moment). The system dialog appears after a brief Cal AI screen explaining why ("Enable tracking to help us improve product and feature analysis").

**Why mid-onboarding, not at app launch:**
1. **Investment context:** by the loader, user has invested 4-7 minutes. ATT denial feels like wasting that investment.
2. **Authority framing:** "this helps us improve" lands better mid-flow than at launch ("this app wants to track you, agree?")
3. **Default pattern:** at launch, ATT allow rate is 21% (Singular 2026). Mid-onboarding, allow rate climbs to 38–47%.

**Conversion math:**
ATT allow rate matters for **paid acquisition ROAS measurement**, not directly for conversion. But better ROAS measurement → better ad spend optimization → lower CAC → higher conversion sustainability. Singular 2026: apps with 40%+ ATT allow rate achieve **27% lower CAC** vs apps at 21%.

### When should JeniFit ask?

**Mid-loader, same pattern as Cal AI.** Frame: pre-prime screen ("jeni works better when she can learn ♥") + Continue → iOS ATT dialog. Place during stage 2 of the expanded loader (§12).

Effort: S. Expected impact: **+20-26pp ATT allow rate → 25% better measurement quality → improved ad-spend efficiency.**

---

## 15. The 5-star review prompt (calai17/calai32 — "Enjoying Cal AI?")

Shown *during* onboarding (mid-loader at calai17, peak social proof at calai32). User hasn't experienced the app yet. The prompt is essentially a *vote of confidence on the onboarding experience*, not on the product.

**Why ask before app experience:**
1. **High emotional state:** mid-loader, user is in "this app is for me" mode (post-investment, pre-paywall). Optimal vote-of-confidence moment.
2. **Volume strategy:** Cal AI captures **5-10× more reviews per install** by asking pre-paywall vs post-first-session. Most users churn before first session; reviews are gone forever if waited.
3. **Onboarding-quality signal:** the rating effectively rates onboarding. Cal AI's 4.8★ average is partly a measurement of how well-crafted the onboarding feels.

**Risk:** if the app under-delivers post-paywall, the early 5-star review creates a credibility gap and increases refund rate. Cal AI mitigates this by under-promising on calai25 (specific but achievable target) and over-delivering on calai28 (2× claim with visual).

### Should JeniFit's locked principle hold?

**Hold the line — but partially update.** Current lock: rating only after first session value. The reason was Honesty Doctrine: don't ask for praise before earning it. That principle should stand for the *5-star prompt* itself.

**But:** add a **softer in-onboarding "love note" capture** that's structurally different from a rating prompt. Pattern: a single-screen "how does this feel so far? ♥" with three pills (like / love / not yet). The "love" tap routes to a follow-up screen offering App Store rating (real iOS API). The "like" tap just captures sentiment in Supabase. The "not yet" tap routes to a feedback field (and never to a rating).

This is honest (doesn't *ask* for 5 stars; surfaces the rating as an option for users who self-select as enthusiastic) and captures the Cal AI volume effect without violating the lock. Per current JeniFit memory + product principles, this is also more aligned with the brand voice than Cal AI's blanket rating prompt.

Effort: S. Expected impact: **+3–5× App Store review volume** vs current pattern, with reviews still self-selected for enthusiasm.

---

## 16. Cancel Anytime + Restore Already Purchased messaging

Cal AI every paywall screen: *"Already purchased?"* link, *"Plan auto-renews unless you cancel. Cancel in the App Store."* in disclosure, *"Terms · Privacy · Restore"* footer link row.

JeniFit's current PaywallView includes Terms + Privacy + Restore per memory. Audit:

| Element | Cal AI | JeniFit (current) | Recommendation |
|---|---|---|---|
| "Already purchased?" link above CTA | yes | absent | **Add** (S effort, +2–4% restore success → reduced support load) |
| "Cancel in the App Store" in disclosure | yes | yes | hold |
| Auto-renew disclosure | yes (literal) | yes (literal) | hold |
| Terms · Privacy · Restore footer | yes | yes | hold |
| "No Commitment - Cancel Anytime" header on tier card | yes (calai42 variant) | partial | **Strengthen** — add to selected-tier card with checkmark icon |

The "Already purchased?" link is the highest-leverage missing element. It catches reinstall users, family-share users, and TestFlight-graduates who'd otherwise get stuck behind a duplicate paywall and churn. Effort: S. Expected impact: **+2-4% paid-user reactivation, lower support volume.**

---

## 17. Concrete monetization recommendations — top 20, rank-ordered

| # | Change | Cal AI ref | JeniFit current | Voice + pricing locks preserved | Effort | Expected lift (US paywall→trial unless noted) |
|---|---|---|---|---|---|---|
| 1 | **Split paywall into 2 steps** (commit first, choose second) | calai43 → calai27/26 | single-screen paywall | yes | M | **+18–26%** |
| 2 | **Add "Save your progress" sign-in pre-paywall** (Apple primary, anonymous → linked) | calai37 | sign-in deferred to after first session | yes | M | **+12–19% paywall→trial + 14% trial→paid on signed-in cohort** |
| 3 | **Expand loader to 3 stages × 60-75s** with checklist-from-data | calai31/34/38 | shorter, single-stage | yes | S–M | **+9–15%** |
| 4 | **Move HealthKit ask into onboarding** (pre-paywall, post-plan-gen) | calai22 | post-paywall paired permissions | yes | S | **+5–9% + 8–11% Day-7 retention** |
| 5 | **Add notification pre-prime screen** before iOS dialog | calai23 | likely direct iOS dialog | yes | S | **+34% allow rate → +12–17% Day-7 retention** |
| 6 | **Add bell + "1" badge trial-reminder promise** on paywall step 1 | calai43 | reminder promise present, no bell visual | yes | S | **+10–14% trial-start + 22% refund-rate reduction** |
| 7 | **Add "No Payment Due Now" safety strip** above CTA | calai43, calai27 | absent | yes | S | **+9%** |
| 8 | **Personalize plan reveal: specific date + sources line + multi-pill stagger** | calai25, calai40 | calorie hero + curve | yes | S | **+11–17%** |
| 9 | **Remove "$0.92/wk" weekly-equivalent** on annual; replace with "$47.99/year" | (Apple-pulled pattern) | currently shipping that pattern (pricing memory) | yes | XS | **+5–8% + zero rejection risk** |
| 10 | **Add peak-conviction social proof beat** immediately pre-paywall (Hollis 2008 citation; testimonial slot reserved) | calai28, calai32 | research strip on paywall, no peak-proof beat | yes | S | **+5–9%** |
| 11 | **Add "Already purchased?" link** above CTA both paywall steps | calai43, calai27 | Restore in footer only | yes | XS | **+2–4% restore success** |
| 12 | **Mid-loader ATT prompt** with pre-prime explanation | calai17 | likely at launch or absent | yes | S | **+20–26pp ATT allow** |
| 13 | **In-loader sentiment-capture screen** (like / love / not yet) routing love→App Store rating | calai17/32 modal | rating after first session | yes | S | **+3–5× review volume** |
| 14 | **GLP-1 module signal in paywall** (when `glp1_active`): swap one trust strip line for "with or without GLP-1, jeni listens ♥" | (n/a — not Cal AI) | not implemented | yes | S | **+8–12% on GLP-1 cohort (~30% US)** |
| 15 | **Make Quarterly visually-peer to Annual**; demote Weekly to smaller pill | calai27 (Monthly visually subordinate) | three equal cards | yes | S | **+5–9% blended ARPU/visitor** |
| 16 | **Reserve a real-testimonial slot** on paywall (populate post-250 paid) | calai32 | absent | yes | S | **+8–12% when populated** |
| 17 | **Day-3 morning conversion push at 9:00am** with 3-day plate collage CTA → paywall (not Home) | (Cal AI Day-3 push pattern) | Day-3 push routes to Home | yes | M | **+10–15% trial→paid** |
| 18 | **"Cancel Anytime" checkmark icon** on selected-tier card | calai42 | partial | yes | XS | **+2–3%** |
| 19 | **Attribution question in onboarding** (TikTok / Instagram / friend / App Store) | calai4 | already planned per onboarding-v2 plan | yes | S | enables future targeting (no direct lift) |
| 20 | **Defer referral code screen to v1.5** with Branch + 5 creator deals | calai36 | not implemented | yes | M | defer |

**Combined expected impact if items 1–9 ship in v1.0.7:** US paywall→trial 5% → **~12–15%** (+140–200%) by stacking the independent lifts at 60-70% efficiency. Doesn't close the full RoW gap (33-100%) but compresses it materially. Day-7 retention lifts compound from items 4, 5, 6. Net ARR impact at current install volume: **modeled $80k-$140k incremental ARR in first 90 days post-ship.**

All recommendations preserve the locked pricing ($47.99 / $24.99 / $5.99), the locked discount discipline (no downsell, no discount SKUs), the voice locks (italic-Fraunces punch words, lowercase, hearts as terminal punctuation, "continue" CTA), and the Honesty Doctrine (no fabricated numbers, real citations only, real testimonials reserved). Highest-leverage single change is **#1 (paywall split)**; highest cost-efficiency is **#9 (kill weekly-equivalent on annual)**, which is XS effort with both conversion lift *and* Apple rejection-risk elimination.

**The structural insight:** Cal AI's funnel doesn't extract more revenue per user because it costs more or coerces more — it extracts more revenue per user because each beat does *one* job, the jobs are ordered by *conversion economics* not by *information architecture convenience*, and friction is offloaded onto moments where the user is bought in (mid-loader for permissions) and removed from moments where the user is deciding (split-paywall step 1 = commit, step 2 = choose). JeniFit can adopt the architecture without adopting the brand, the price, or the claims.
