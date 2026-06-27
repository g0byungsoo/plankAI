# Deficit Insight + Food-Log Retention: Program-Science Brief
**Author:** Weight-loss program science expert (post-GLP-1 2026 cohort)
**Date:** 2026-06-11 · Supersedes the map/ledger build from `becoming_below_fold_program_2026_06_11.md` for the energy-balance question. Anti-shame doctrine (`feedback_food_ux_antishame.md`) remains binding.

---

## Part 1 — The honest deficit-day spec

The founder's ask is NOT the killed daily gained-vs-spent card. Daily verdict = a judgment delivered TO her each day. This is weekly **accumulation counting** plus **self-directed inquiry into her own logs**. Both are buildable honestly. The killed card's two failure modes (shame surface, ±20% EE error rendered as a confident daily number) are handled by classification gates + count-only framing, not by refusing the feature.

### 1a. Accuracy stack, and what it permits

| Layer | Method | Error | Receipt |
|---|---|---|---|
| RMR | Mifflin-St Jeor from height/weight/age/sex | ±10% for ~82% of non-obese, ~70% of obese individuals; worse tails | Frankenfield, Roth-Yousey & Compher 2005, *J Am Diet Assoc* (ADA evidence analysis: MSJ is the best predictive equation, but 1-in-5 women miss by >10% ≈ ±150 kcal) |
| Activity EE | steps + session-minutes (MET-based; no HR sensor) | ≥±20% on activity portion; wrist devices with MORE sensors run 27–93% error | [Shcherbina et al. 2017, *J Pers Med*](https://pmc.ncbi.nlm.nih.gov/articles/PMC5491979/), [Stanford Medicine](https://med.stanford.edu/news/all-news/2017/05/fitness-trackers-accurately-measure-heart-rate-but-not-calories-burned.html) — "no device achieved EE error below 20%" |
| Intake | photo-AI estimate | ±20–30% per plate, plus **missed events**: self-reported intake under-reports by ~20–30% vs doubly labeled water, up to 47% in diet-resistant cohorts (Lichtman et al. 1992, *NEJM*) | domain food-vision benchmarks per `feedback_food_vision_models` |

Combined daily balance uncertainty: realistically **±350–500 kcal**, and the bias is **one-directional in the dangerous way** — intake errors run low (unlogged snacks/drinks, AI portion underestimates), EE errors run high. An ungated counter would systematically over-award deficit days. That asymmetry, not the noise itself, sizes the buffer.

### 1b. Classification rule (internal name `DeficitDay`; the word "deficit" never renders — kill-list per `feedback_post_ozempic_vocabulary`)

A day classifies as **on-pace** only when ALL hold:

1. **Completeness gate:** ≥2 logged eating events spanning ≥5 hours, AND logged intake ≥ 0.6 × BMR. Below this, the data can't support any claim → day = **unclassified** (neutral paper, copy: "not enough logged to read this day"). Never renders as failure.
2. **Buffer:** `spent − gained ≥ max(300, 0.2 × gained)` kcal. 300 absorbs the ±10% RMR band + activity-EE noise; the 20%-of-intake term scales for big-intake days where photo-AI error dominates. This makes a false "on-pace" award unlikely even at the bad tail of every estimate simultaneously.
3. **Floor (the GLP-1 clause):** logged intake ≥ max(1200, BMR − 750) kcal. A day below the floor does NOT classify on-pace no matter how large the gap — it's unclassified AND fires the existing under-eating safety line ("your body needs more — let's aim higher tomorrow", anti-shame rule #6). On-pace is therefore a **corridor, not a one-sided threshold**: restriction cannot farm the counter. This is load-bearing, not decorative — a deficit-day counter is structurally a restriction-reinforcer; the corridor is what makes it shippable for a cohort with GLP-1 users (appetite already suppressed; lean-mass loss 25–40% of total, Wilding et al. 2021) and ED-adjacent members.
4. **Timing:** classification computes after day close (3am local), surfaces next morning at earliest. Never a real-time verdict while she's eating.

**Cohort guards:** `onb_glp1` flag → floor +100 kcal and protein line joins the weekly summary. The onboarding-v2 `food relationship` key at its most strained values → counter defaults OFF (weekly summary shows scan-days + protein pattern instead); opt-in via settings. Never show consecutive-day chains, never streaks.

### 1c. Counting psychology — both directions, honestly

**For:** Consistent dietary self-monitoring is the single best-replicated predictor of weight-loss success (Burke, Wang & Sevick 2011, *J Am Diet Assoc* systematic review; Harvey et al. 2019 dose-response). Accumulation framing ("4 days this week") exploits the small-area effect (Koo & Fishbach 2012) and avoids the abstinence-violation spiral that daily fail-verdicts trigger (Marlatt & Gordon 1985).

**Against:** Calorie-tracking apps correlate with ED symptomatology in college women (Simpson & Mazzeo 2017, *Eat Behav*); 73% of ED patients using MyFitnessPal perceived it as contributing to their disorder (Levinson et al. 2017). The harm mechanism in that literature is **dichotomous daily judgment** → counter-regulatory "what-the-hell" eating (Polivy & Herman) and good/bad food moralizing — not counting per se.

**Synthesis:** count only successes, render non-on-pace days as neutral paper (identical to chapter-map missed-day rule), aggregate weekly + program-level ("11 on-pace days this program"), corridor floor, no streak mechanics. That keeps Burke's monitoring benefit while removing every mechanism Simpson & Mazzeo's harm pathway runs on.

**Copy rules:** user-facing label = **"on-pace days"** (descriptive of trajectory, not food morality). Weekly line: "3 on-pace days this week. logged enough to read 5." Program line: "11 on-pace days so far." Banned: deficit, burn, earn, over/under budget, fail, streak, red anything. Italic-Fraunces punch on *on-pace* only.

### 1d. "Which food caused me to fail" → descriptive pattern inquiry

Causal single-food attribution is both statistically unsound (a day's balance is multi-factor at n≈1) and the exact moralizing pathway in the ED literature. Dichotomous good/bad food thinking independently predicts weight REGAIN (Byrne, Cooper & Fairburn 2003, *Behav Res Ther*). The honest version is **shared-context surfacing + her own eyes**:

1. **She browses, the app never accuses.** Tap any week dot → that day's plate timeline (already built, v1.0.9 food log). The inquiry tool is the journal itself.
2. **Pattern lines are descriptive, context-noun, gated n≥3:** "your three highest days this month share restaurant dinners" / "lighter lunches showed up before your biggest evenings" / "your highest days were weekends." Contexts allowed: meal timing, restaurant/quick-add flag, skipped-earlier-meal, day-of-week. **Food nouns banned as pattern subjects** ("pizza days" never renders).
3. **No causal verbs.** "share / showed up / tend to" yes; "caused / blew / ruined" never. The skipped-lunch→big-dinner pattern is the one place a gentle mechanism line is evidence-backed (compensatory later intake): "days with an early plate ran steadier."
4. Patterns live in the depth sheet / weekly recap, never push notifications.

---

## Part 2 — Food-log + photo retention policy

### Competitor receipts

| App | Logs | Photos | Export | Receipt |
|---|---|---|---|---|
| **MyFitnessPal** | free tier: 2-year diary look-back only (since Nov 2019); Premium keeps history | progress photos cloud-side; user reports of loss | **Premium-only** export | [MFP 2-year announcement](https://community.myfitnesspal.com/en/discussion/10768857/beginning-nov-1-2019-the-free-version-of-the-diary-will-only-save-data-for-last-two-years), [Export FAQ](https://support.myfitnesspal.com/hc/en-us/articles/360032273352-Data-Export-FAQs) |
| **Cal AI** | no fixed period: "as long as necessary to fulfill the purposes" | meal photos collected server-side; no stated photo retention window; deletion on request only | portability on request (legal-rights boilerplate) | [Cal AI Privacy Notice](https://www.calai.app/privacy) |
| **Lose It (Snap It)** | account lifetime | photos explicitly harvested to "train the next generation of the app" | CSV (premium) | [Engadget on Snap It](https://www.engadget.com/2016-09-29-lose-it-snap-it-app.html) |
| **MacroFactor** | account lifetime, full granularity | retained until account/photo deletion; in-app deletion path | **free lifetime spreadsheet export** + Apple Health write | [MF data-protection page](https://macrofactorapp.com/app-personal-data-protection-information/), [export note](https://macrofactor.com/mm-march-2022/) |
| **Yazio** | persists after PRO cancellation; user-initiated reset available | — | account-data flows | [Yazio help](https://help.yazio.com/hc/en-us/articles/204913272-I-want-to-start-from-scratch-and-delete-all-entries-How-does-that-work) |

Industry norm: **logs live for the account lifetime at full granularity**; the only major app that prunes (MFP's 2-year free cliff) did it as a monetization lever and its own forums treat it as betrayal. Photos: the big players hold them in cloud indefinitely and (Cal AI, Lose It) reserve training rights — which is precisely the privacy posture JeniFit's no-trackers brand can undercut.

### Storage math

40KB × 14 scans/wk × 52wk ≈ **29MB/year** per typical heavy scanner; the 41-scans-day outlier worst case ≈ 600MB/yr. Log rows (~200B) ≈ 150KB/yr. **Pruning is not a storage necessity at any realistic horizon.** Compaction would be solving a problem we don't have while breaking a promise we can make.

### Recommended policy

1. **Logs: forever, full granularity, never aggregated away.** They are the inquiry corpus (Part 1d) and the corrections-as-moat asset. No free/paid retention split — the anti-MFP position is itself marketing.
2. **Photos: on-device, kept indefinitely by default.** No 90-day compaction. Optional user-initiated "tidy older plates" in settings (delete, never auto). Photos never leave the device except the transient scan upload, which is not retained server-side — make that sentence true in the privacy policy and say it in-app.
3. **No training on her plates. Ever.** Cal AI/Lose It's harvest posture is the contrast line.
4. **Export free for everyone** (CSV + photo bundle via share sheet). MacroFactor-grade, vs MFP's paywalled export.
5. **Journal UX promise:** "your plates, kept. on your phone, as long as you want them." (lowercase, italic-Fraunces on *kept*).
6. **Engineering caveats (the real risks, neither is storage):** (a) UserDefaults is a stop-gap — it loads wholesale into memory and isn't the durability the promise implies; migrate log rows to SwiftData + Supabase sync before the promise ships in copy. Photos stay device-only (sync the rows, not the pixels — phone loss costs pictures, never the record). (b) iCloud device backup covers photos for most users; note it in the journal settings copy.

---

## Verdict for the founder

You're right, and the version you described is buildable without re-litigating the killed card: the danger was never energy-balance data, it was a confident daily verdict built on ±400 kcal of stacked estimate error. Count **on-pace days** weekly and program-level, classify a day only when she logged enough to read it (≥2 meals, ≥0.6×BMR), award it only inside a corridor (gained ≤ spent − 300 AND above the 1200/BMR−750 floor so restriction can't farm the counter), render everything else as neutral paper, and let "which food did it" be her own browsing of her own plate timeline plus descriptive context patterns ("your highest days share restaurant dinners") — never a causal food-blame line. On retention: keep every log forever and every photo on-device indefinitely; at ~29MB/year pruning is solving nothing, and "your plates, kept — on your phone, never used to train anything, export free" beats Cal AI's silent cloud harvest and MFP's 2-year paywall cliff at their own game. The one real engineering debt is the UserDefaults stop-gap: migrate rows to SwiftData + Supabase before the keep-forever promise goes in copy.
