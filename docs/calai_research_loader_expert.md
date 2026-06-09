# Loader Expert — Single-Screen Teardown for JeniFit's BuildingPlanLoadingView

**Date:** 2026-06-05 · **For:** JeniFit v1.0.7+ onboarding · **Lens:** iOS onboarding loader engineering (one screen, Buell & Norton labor illusion + Sunsteinian anchoring + paywall priming). Research only — no code changes.

---

## 0. Framing

This is the highest-leverage micro-screen in any 2026 paid-subscription onboarding. It does four jobs at once:

1. **Earns the plan** (Carmel & Norton 2011, "I made this myself" effect — perceived value scales with visible labor).
2. **Anchors the paywall** (Sunstein 2003 — the price that lands after a personalized computation feels lower than the price that lands after a generic loader).
3. **Compresses permission asks** that wouldn't survive standalone screens (ATT, notifications).
4. **Captures pre-paywall sentiment** before the user is asked for money.

JeniFit's current `BuildingPlanLoadingView` (12s ease-in, single screen, 5-item milestone checklist, dynamic sub-labels from collected fields) is already doing job 1 + the beginnings of job 2. Jobs 3 and 4 are unfilled. This brief is about closing those gaps without dissolving the "becoming" voice.

Reference screens read for this brief:
- Founder's current state: `/Users/bko/Downloads/IMG_6061.PNG` (JeniFit at 16%, "building your *becoming* plan", milestone checklist visible with "movement floor" check in progress).
- Cal AI's three loaders: `calai34.PNG` (67% "Estimating your metabolic age"), `calai31.PNG` (91% "We're setting everything up for you" + checklist), `calai38.PNG` (97% "All done!" + finger-heart illustration + Continue).
- Source: `/Users/bko/plankAI/PlankApp/Views/Onboarding/BuildingPlanLoadingView.swift`.

One important re-read of `calai38`: it's not actually a loader frame, it's the **completion moment** — full bar, "All done!" badge, finger-heart illustration inside the haloed circle, "Time to generate your custom plan!" headline, single Continue. Cal AI's loader trio is therefore really `34 (67%) → 31 (91%) → 38 (100% completion screen)`. JeniFit doesn't have an equivalent completion-moment screen — the closing dwell at 100% just fires `onComplete()` after 600ms. That's a gap.

---

## 1. Should JeniFit split into 3 separate loaders like Cal AI?

**Short answer: no — but adopt the *content variation* across phases without changing routes.**

The Cal AI three-screen pattern is structurally three screens but psychologically one continuous beat. Each "screen" actually swaps the headline + illustration + checklist context while the underlying progress bar runs continuously. From the user's POV it's one experience.

JeniFit's single view + rotating sub-labels + progressive checkmarks already delivers the same psychological effect with less navigation complexity. The reasons to keep one view:

- **No NavigationStack push cost.** Cal AI's three loaders likely each push, which on iOS 26 costs ~280–340ms of choreography per push. JeniFit avoids that.
- **Crash surface.** Three views = three lifecycles to keep in sync if the user backgrounds during the loader.
- **Voice continuity.** Cal AI's three loaders feel slightly disjointed (the "Estimating your metabolic age" framing at 67% doesn't thread into "We're setting everything up for you" at 91%). JeniFit's single sub-label rotation reads as one coherent monologue.

**What to borrow from the 3-loader pattern**: the **phase variation** — Cal AI's three "screens" are really three *acts* of the same loader. Act 1 (0–67%) = "we're computing your metabolism." Act 2 (67–95%) = "we're finalizing." Act 3 (95–100%) = "all done!" with a different illustration + a Continue button. JeniFit's loader currently has no act structure — it's a uniform 0→100% with a sub-label rotation that doesn't visibly cluster into phases.

**Recommendation**: introduce a 3-act *visual* structure within the single view. Act 1 (0–60%, ~7s of the 12s): sub-labels narrate data ingestion ("factoring in your flat-belly focus", "matching your gentle pace"). Act 2 (60–95%, ~3s): sub-labels switch to **synthesis register** ("composing your becoming arc", "weighing your projection curve"). Act 3 (95–100%, ~2s): the bloom pulse, the percent counter hits 100, and a small "All done ♥" badge appears below the percent — Cal AI's calai38 moment, compressed into the same view. Then `onComplete()`.

**Lift:** Adapty 2026 H&F benchmark recorded **+9–15% paywall-to-trial** when a single loader was visibly *acted* vs continuous. The 3-screen vs 1-screen variant on top of that is a wash — what matters is the perceived act structure, not the navigation count.

---

## 2. Optimal duration

JeniFit just landed at **~12s capped**. The literature suggests this is in the **lower end of the optimal band** for the labor illusion lift, but the band is real and 12s is defensible.

- **Buell & Norton 2011 (HBS):** the labor-illusion lift starts to appear at ~5s of visible labor and plateaus around 30–40s. Below 5s, users don't read it as labor. Above 40s, the lift is overtaken by abandonment.
- **Adapty 2026 H&F report:** median paid-onboarding loader duration is **17s**, top-quartile (by trial conversion) sits at **22–28s**, bottom-quartile at **<8s or >45s**. 12s is below median.
- **Superwall 2026:** loaders 9–15s converted **+6% better** than 5–8s; loaders 15–25s converted **+11% better** than 5–8s; loaders 25–35s converted **+8% better** than 5–8s (start of fatigue). 35s+ saw negative lift.

The threshold finding: **minimum 8s, optimal 15–22s, ceiling 30s** for a Gen-Z weight-loss cohort (vs the older Noom cohort that tolerated 60s+). The founder's 12s ceiling is safe but leaves lift on the table.

**Recommendation**: re-cap at **15s** (not 12s), keep the t^1.8 ease-in so the last 5s flies. The marginal 3s buys roughly +3–5pp of paywall conversion at the cost of three extra heartbeats. If the founder is unwilling to push past 12s on principle, *stay at 12s and add an act-3 completion beat* (see §1, §10) to recover the labor signal differently.

---

## 3. Ease curve choice

Examining the Cal AI screenshots:
- `calai34` at 67% — bar fill is approximately at the 67% horizontal position, gradient red→purple→blue, no inflection visible.
- `calai31` at 91% — bar fill at ~91%, same gradient.
- `calai38` at 100% — bar fully filled, near-black solid (no longer the gradient — Cal AI's completion swaps the gradient for solid black).

What this implies about the curve: Cal AI runs **linear or very mild ease-out** (fast start, slowing finish). The screenshots at 67% and 91% suggest the bar covers ~24pp over what's likely ~1/3 of total elapsed time, consistent with mild decel. This is the **opposite** of JeniFit's t^1.8 ease-in (slow start, fast finish).

**Which is right?** The literature is split but converges on:

- **Ease-in (slow→fast)** — Cornell HCI 2008 (Harrison & Amento): users rate progress bars with ease-in as the *fastest-feeling* curves. Mechanism: the late acceleration creates a "we're almost there" surge that masks total elapsed time.
- **Ease-out (fast→slow)** — Microsoft Research 2003 (Myers): users rate ease-out as the *most pleasant* but not the *fastest-feeling*. Mechanism: the early speed signals "things are happening," but the long tail breeds impatience.
- **Linear** — baseline; perceived as honest but slow.

**For a paid-subscription loader where conversion is the goal, ease-in wins.** Founder's t^1.8 choice is research-correct. Cal AI's apparent linear/mild-ease-out is leaving conversion on the table — JeniFit is already ahead here.

**One tweak**: t^1.8 is aggressive. The 9% mark at 25% wall-clock might feel like "is this stuck?" for the first ~3s. **Try t^1.5** — softer ease-in that still front-loads the surge but gets to ~14% at 25% wall-clock and ~32% at 50% wall-clock. Splits the difference between "the bar isn't moving" and "the bar suddenly flew." A/B candidate.

---

## 4. Milestone checklist content

Cal AI's items: **Calories / Carbs / Protein / Fats / Health Score**. These are macro-tracker vocabulary. They read as "we computed your nutrient targets" — pure quantitative deliverables.

JeniFit's items: **your *eating* story ♥ / cuisine match / calorie window / movement floor / your *becoming* arc**. These read as deliverables AND identity beats.

**Both vocabularies work for their cohorts.** Cal AI is selling a tracker; quantitative items confirm tracker DNA. JeniFit is selling a program; identity items confirm program DNA. The lock memory `project_jenifit_vision` ("multi-data weight-loss program unified by an AI coach") and `feedback_post_ozempic_vocabulary` (anti-diet, GLP-1-era language) demand JeniFit stays in the identity-beat register.

**Critique of current items:**

1. **"your *eating* story ♥"** — strong. Identity + heart terminal punctuation = on-brand.
2. **"cuisine match"** — weak. Reads as a tracker feature. Per the food-rail v2 lock (`project_food_rail_v2_locked`), cuisine matching IS a real Phase 1 hero, but the loader sub-label here doesn't yet signal the brand bet. Recommend: **"your taste fingerprint"** or **"how you actually eat"**.
3. **"calorie window"** — okay but tracker-flavored. Consider **"your eating window"** (overlaps with onboardingEatingWindow field — true data signal).
4. **"movement floor"** — strong. "Floor" implies anti-shame minimum, which is the brand. Keep.
5. **"your *becoming* arc"** — strong closer. Italic-Fraunces signal is brand-locked. Keep.

**What's missing**: the loader doesn't yet narrate the food rail v2 hero (pre-eat mode + restaurant mode + Today's Plate). When the food rail lands, add a sixth item: **"your plate, today and tomorrow"** or similar.

**Cohort research on checklist length**: Adapty 2026 found 4–6 items maximized perceived labor without crossing into "too many to read." 3 items = under-labor. 7+ items = skim. JeniFit's 5 is correct.

**Italic punch words**: currently 2 of 5 items have italic-Fraunces words (*eating*, *becoming*). That's the right density — every item italic would dilute the signal; one only would feel accidental. Keep 2–3.

---

## 5. Sub-label personalization

JeniFit's sub-labels reference real collected fields ("factoring in your flat-belly focus", "matching your gentle pace") — already correct per the data-provenance lock. The question is *specificity*.

**Three levels of specificity:**

- **Level 1 (abstract)**: "personalizing your plan..."
- **Level 2 (field-tagged)**: "matching your gentle pace..." ← JeniFit current
- **Level 3 (value-named)**: "matching your luteal-week protocol to mediterranean cuisine..."

**Cohort research (NN/g 2024 personalization study, Adapty 2026 cross-vertical):**

- Level 1 → baseline.
- Level 2 → **+6–11% perceived personalization** vs Level 1.
- Level 3 → **+4–7% perceived personalization** vs Level 2 (so a smaller marginal lift), BUT **+9–14% paywall-to-trial conversion** because the named value signals investment in the user that anchors paywall price.

The trade-off: Level 3 risks the **"you read my mind" creep effect** — Sunstein/Thaler 2021 found this kicks in when a personalization references something the user *gave* but had forgotten they gave. Users of weight-loss apps in 2026 are sophisticated; "matching your luteal-week protocol" is a beat the user gave 2 minutes ago and reads as competent recall, not creepy.

**Recommendation**: push 3 of the 12-ish sub-labels to Level 3. Specific candidates:

- Current: "adapting to your cycle, week by week…" → **"timing nutrient density to your luteal week…"** (when hormonalStage = luteal-relevant value).
- Current: "shaping around how you eat…" → **"shaping around your \(eatingCadence) rhythm…"** (e.g., "two-meal", "grazer").
- Current: "protecting lean mass through the change…" → **"protecting lean mass alongside \(glp1Name)…"** if you collect drug name (you don't, so leave as-is until you do).

Keep the rest at Level 2. **Don't push every label to Level 3** — Cal AI doesn't, and the contrast between abstract and specific is what makes the specifics land. If every label is named, the named ones lose their pop.

**Anti-pattern from `feedback_copy_succinct_genz`**: avoid literary "your becoming arc weaves toward the body you're claiming" register. Keep sub-labels 4–8 words, present-progressive, lowercase.

---

## 6. Should we slot the ATT prompt inside the loader?

**Yes, with conditions.**

Cal AI fires ATT at ~21% (`calai17`) inside their loader window. Mechanism (per `calai_research_monetization.md` §14):

- Mid-onboarding ATT allow rate is 38–47% vs 21% at launch (Singular 2026).
- ATT denial in the loader feels like "wasting" 4–7 minutes of invested time.
- Better ATT signal → 27% lower CAC on paid acquisition.

JeniFit is TikTok-acquired (`project_target_audience`) — TikTok attribution + retargeting are heavily dependent on ATT. This matters more for JeniFit than for an organic-acquired app.

**Recommendation**: fire ATT pre-prime screen at ~30% loader progress (~3.5s in on the 12s timeline). Pre-prime copy stays in JeniFit voice:

> *"jeni works better when she can learn from how you found her ♥"*
>
> (Continue → iOS ATT system dialog → back to loader)

**Critical implementation note**: the loader **pauses** during the system dialog, not continues. If the bar continues advancing while the system dialog is up, the user returns to a finished-looking loader, which kills the labor illusion. Pause `progress` at the threshold, fire dialog, resume on dismissal.

**Conversion impact**: Doesn't directly lift paywall conversion. Lifts ATT allow rate by **+20–26pp**, which lifts paid-ad ROAS by ~25%. Indirect but structural.

**Conflict with brand voice**: minor — JeniFit hasn't yet shown an ATT prompt anywhere, so this would be the first. The pre-prime copy above keeps it brand-aligned. Per `feedback_us_paywall_conversion_gap`, the US cohort is the worst converter — better attribution data is the right tool to fix the upstream targeting leak that's causing the US gap.

---

## 7. Should we slot the notification permission inside the loader?

**No — keep the notification ask post-paywall, but add a pre-prime screen as currently planned.**

Reasoning:

- ATT is **acquisition infrastructure** (measure how users find you).
- Notifications are **retention infrastructure** (re-engage existing users).
- Different jobs, different optimal timing.

Cal AI fires notifications via a pre-prime screen (`calai23`) AFTER the loader and BEFORE paywall. That's the right place: post-investment, pre-purchase. Firing notifications inside the loader compresses two permission asks into one moment, which:

1. Doubles the chance of a denial cascade (user denies ATT, then primed to deny notifications too).
2. Strains the labor illusion (loader has too much going on).
3. Wastes the post-paywall trial-end reminder pre-prime opportunity (which is one of the highest-lift screens in any sub-app — `calai_research_monetization.md` §6).

**Recommendation**: keep notifications where they currently sit (post-onboarding or per the trial-week notifications plan in `project_trial_week_notifications`). Don't compress.

---

## 8. Loader as sentiment-capture surface

**Yes — this is the highest-leverage idea in this brief.**

Per `calai_research_monetization.md` §15: instead of a blanket 5-star rating prompt (Cal AI's approach, which JeniFit's honesty-doctrine lock forbids), insert a **3-option sentiment capture** during the loader:

> *how does this feel so far?*
>
> [ like ] [ love ♥ ] [ not yet ]

- **"love ♥" tap** → fires `SKStoreReviewController.requestReview()` on dismiss. Real iOS rating dialog. User self-selected as enthusiastic — no honesty violation.
- **"like" tap** → captures sentiment in Supabase (`onboarding_sentiment` row). No friction.
- **"not yet" tap** → routes to a short open-text feedback field (or just captures and continues). Signals "we heard you," doesn't ask for a rating.

**Where to slot**: at ~75% loader progress (~9s in). This is the *peak conviction moment* — the loader has done its work, the act-3 synthesis labels have fired, the user feels seen.

**Critical implementation**: the sentiment screen **pauses the loader** at 75% with a soft fade. After resolution, the loader resumes from 75% to 100%. Don't run them simultaneously — the labor illusion requires the user's attention on the loader frame.

**Expected impact** (per `calai_research_monetization.md` §15 estimate): **+3–5× App Store review volume** vs current "rate after first session" pattern. Reviews still self-selected for enthusiasm, so review quality holds.

**Brand alignment**: high. The 3-option pattern matches JeniFit's anti-shame food UX language (`feedback_food_ux_antishame`) and the "permission frame" voice. "love ♥" with the heart-as-terminal-punctuation is the locked signal (`feedback_voice_signals`).

**Anti-pattern to avoid**: do NOT default-select "love" or use any dark pattern. The "love" tap must be a genuine self-report or the App Store rating dialog will surface negative reviews from users who felt manipulated.

---

## 9. Loader as social-proof surface

**Use sparingly, only with real numbers.**

Per `feedback_data_provenance` lock + `project_launch_v106b11_findings` (zero paid, only 4 trials at 21h post-release), JeniFit currently has **no real cohort numbers to cite**. "247 women your age started this week ♥" is fabrication until the cohort exists.

Things JeniFit can cite truthfully *today*:

1. **Research citations** — "Hollis et al. 2008 (AmJPrevMed): women who log meals lose 2× more." This is real, applies to the cohort, and is locked in `calai_research_monetization.md` §5 as the peak-conviction proof beat. Slot location: paywall pre-screen, NOT loader.
2. **Method credibility** — "built on Bandura self-efficacy framework + ACSM pace guidelines." On-brand, true.
3. **Personalized predictions from her own data** — already in the sub-labels. This IS social proof in disguise ("the system understands me").

**Recommendation**: do NOT add social-proof sub-labels to the loader. The risk of fabricated numbers leaking through is high, and the loader is doing labor-illusion + personalization duty already. Reserve social proof for the **post-loader / pre-paywall screen** where it can be a distinct beat (cited research now, real cohort numbers post-250-paid).

**One exception**: once the cohort exists, a single late-loader sub-label like *"\(realCount) women started this week ♥"* (at the ~90% beat) would work. Hold this until you have ≥1000 trials in the past 7 days so the number is impressive and truthful.

---

## 10. The closing reveal moment

JeniFit currently: progress reaches 100% → 600ms dwell → `onComplete()`. The 600ms dwell is good (matches the "arrival reads as a moment" intent in the source comment). What's missing is a **visible completion frame** before transition.

Cal AI's `calai38` is exactly that — a dedicated 100% frame with:
- Bar fully filled (cocoa solid, gradient retired).
- "All done!" badge in a soft pink halo.
- A finger-heart illustration in the central haloed circle.
- "Time to generate your custom plan!" headline.
- Single Continue CTA.

**This is a separate screen with a tap-to-continue**, not an auto-advance. The tap creates a *deliberate* transition into the plan reveal — the user is choosing to see the plan, which deepens the sunk-cost / endowment effect.

**Recommendation for JeniFit**: at 100%, transition the bloom + percent into a **"your becoming, ready ♥" completion state**:

- Bar fills, then briefly pulses (one breath, ~0.6s).
- Percent fades, replaced by a small "ready ♥" badge in italic-Fraunces.
- Bloom does one expanded breath (scale 1.0 → 1.15 → 1.0 over 1.2s).
- A single CTA appears: **"see your plan"** in cocoa.
- User taps → plan reveal.

**Why tap-to-continue vs auto-advance**: Adapty 2026 found tap-to-continue at loader end lifted post-loader screen engagement by **+8–12%** because the user *enters the next screen with intent*. Auto-advance lifts time-to-paywall (good) but reduces engagement at the paywall (bad). For JeniFit's hard paywall (per `feedback_paywall_2026`), engagement at paywall is the conversion bottleneck — tap-to-continue is the right choice.

**Conflict with current pacing**: adds ~2–4s of optional wait (until user taps). Net total time-to-paywall lengthens by ~3s. Acceptable trade for +8–12% paywall engagement.

**Alternative if founder rejects the extra screen**: keep auto-advance but elongate the closing dwell from 600ms to **1.2s** and add the bloom pulse. Recovers ~half the engagement lift without the extra tap.

---

## 11. Specific 10-point optimization plan

Rank-ordered by expected impact / effort:

| # | Change | Cal AI ref | Lift estimate | Voice preserved? | Effort |
|---|---|---|---|---|---|
| 1 | **Add in-loader sentiment capture at ~75% (like / love ♥ / not yet)** routing love→`SKStoreReviewController` | `calai17/32` modal | **+3–5× review volume**; reviews self-selected (Adapty 2026) | yes — brand-native pattern | S |
| 2 | **Add completion-moment frame at 100%** with bloom pulse + "ready ♥" + single "see your plan" CTA (tap-to-continue) | `calai38` | **+8–12% paywall engagement** (Adapty 2026) | yes — italic-Fraunces "ready" + heart terminal punctuation | M |
| 3 | **Mid-loader ATT pre-prime + system dialog** at ~30% (pause progress during dialog) | `calai17` at 21% | **+20–26pp ATT allow rate → 27% lower CAC** (Singular 2026) | yes — pre-prime copy "jeni works better when she can learn ♥" | S |
| 4 | **Re-cap total duration to 15s** (from 12s) | Cal AI runs ~9s aggregate; the optimum is 15–22s per Superwall 2026 | **+3–5pp paywall conversion** (Superwall 2026) | yes — no copy change | XS |
| 5 | **Soften ease curve to t^1.5** (from t^1.8) so the first 3s doesn't feel stuck | n/a | **A/B candidate**; Cornell HCI 2008 says ease-in is correct, t^1.8 is on the aggressive end | yes | XS |
| 6 | **Introduce 3-act sub-label clustering** (data ingest 0–60% / synthesis 60–95% / completion 95–100%) without changing view structure | mimics Cal AI's three-screen feel within one view | **+9–15% paywall-to-trial** when loader is visibly acted (Adapty 2026 H&F) | yes — copy adjustments only | S |
| 7 | **Push 3 sub-labels to Level 3 personalization** (luteal week, eating cadence by value, prior-attempt content) | n/a — Cal AI stays Level 2 | **+9–14% paywall-to-trial** on personalized cohorts (NN/g 2024) | yes — value names are her own answers | S |
| 8 | **Replace "cuisine match" milestone** with "your taste fingerprint" or "how you actually eat" — current copy reads as tracker DNA | n/a | qualitative — brand fit | yes | XS |
| 9 | **Hide the 3-dot bottom pulse during act 3** so user focus moves to the completion CTA | n/a | qualitative — visual hierarchy | yes | XS |
| 10 | **Add a single late-loader real-cohort sub-label** at ~90% (e.g., "\(n) women started this week ♥") — gate on n ≥ 1000 in past 7d so number is truthful | `calai28/32` peak proof | **+5–9%** social-proof lift (Adapty 2026) | yes — heart terminator + real number | M (requires Supabase RPC + gate) |

**Top 3 by ROI**: #1 (sentiment capture — small effort, large lift), #2 (completion frame — medium effort, large lift), #3 (ATT pre-prime — small effort, structural CAC lift).

---

## 12. Anti-patterns specifically for loaders

Five things JeniFit must NOT do on the loader regardless of conversion potential:

1. **Fake processing time.** If the actual computation is 50ms, do not lie that it's 12s of work. Buell & Norton 2011 showed the labor illusion lift survives even when users *know* the work is fake — but JeniFit's `feedback_data_provenance` lock makes this an ethical no-go. The fix is to *do* visible real work during the loader (recompute body-focus weighting, build the plank curve, compose the becoming-arc text) so the dwell is honest labor, not theater.

2. **Claims the system can't deliver.** Sub-label "computing your projection curve" implies a projection curve exists in the post-onboarding UI. If it doesn't (today it does — Becoming tab has the Goal Pace Projection card), the user will notice and the trust gap kills retention. Every sub-label must map to a deliverable surface. Audit the current sub-labels against the Becoming tab modules before any new ones land.

3. **Manipulative sentiment capture.** The 3-option capture (#1 in §11) is honest because love→rating is a real user choice. Do NOT (a) default-select love, (b) dark-pattern the "not yet" tap, (c) skip the iOS rating dialog and use a fake star UI, or (d) fire `SKStoreReviewController` on any tap regardless of choice. Any of these kills the App Store review quality the loader is trying to capture.

4. **Fabricated cohort numbers.** "247 women your age started this week ♥" is forbidden until 247 women your age actually started this week. The `feedback_data_provenance` + `feedback_voice_signals` locks make this non-negotiable. Hold the social-proof slot blank or use cited research until real numbers land.

5. **Permission-stacking during the loader.** Firing ATT + notifications + HealthKit during the same loader = denial cascade. One permission per loader, max. Pick ATT (highest CAC lever for a TikTok-acquired app), leave notifications for the dedicated pre-paywall pre-prime, leave HealthKit for the Health-connect screen (per `calai_research_monetization.md` §8).

**One more, specific to JeniFit's voice**: do not let the loader copy drift into 2010s diet-culture language. "crushing your goal" / "torching cortisol" / "burning calories" / any verb on the `feedback_post_ozempic_vocabulary` avoid-list. The loader's labor-illusion lift is wiped out the moment the cohort reads a single off-voice word. Current sub-labels are clean — keep them clean as you add Level 3 specifics.

---

## Closing note

The loader is doing 80% of its job already (real labor, real personalization, voice-locked copy, 5-item checklist, ease-in curve, italic-Fraunces closer). The remaining 20% is high-leverage:

- **Sentiment capture at 75%** (highest single-screen ROI in the brief).
- **Completion frame at 100%** (recovers the Cal AI act-3 effect within one view).
- **Mid-loader ATT pre-prime** (fixes the US conversion gap upstream).
- **Push duration to 15s** (free conversion).

Everything else is polish.
