# Feature-Gap Synthesis — 3 Cohorts, 1 Convergent Product
**Date:** 2026-06-16
**Source:** synthesizes `feature_gap_post_glp1_*.md` + `feature_gap_on_glp1_*.md` + `feature_gap_generic_wl_*.md`
**Audience:** founder, decision-maker
**Constraint:** solo iOS founder, ≤10 weeks total

---

## The headline finding

**The product converges. It does not bifurcate.**

Across 44 features identified by 3 independent cohort-specific research agents, **11 features serve 2 or 3 cohorts at once** — the same engine, the same UI, with cohort-translated copy and threshold tuning. The on-GLP-1 cohort adds an additional 12 cohort-specific features (most are the injection ritual: dose log, site map, side-effect log, etc.). The post-GLP-1 cohort adds 3 cohort-specific features (12-week Keep-It-Off curriculum, regain-risk card, "we're not Calibrate" trust strip). The generic-WL cohort adds essentially zero cohort-specific features — almost every generic-WL feature ALSO serves at least one GLP-1 cohort.

**Practical translation:** there isn't a "post-GLP-1 app" vs "general WL app." There's ONE app where 60% of the surface area serves everyone, and a thin per-cohort surface routes in/out based on the onboarding question. This collapses the engineering surface dramatically vs building three apps.

The implication for the round-2 phasing: Phase 1 (weeks 1-3) should ship the **convergent foundation**, not just cohort segmentation. The convergent stack is also what closes the 7-14% US conversion leak for the generic-WL cohort AND substantiates the conviction claim for the post-GLP-1 cohort AND establishes table-stakes for the on-GLP-1 cohort.

---

## The convergent stack (11 features serving 2+ cohorts)

Ranked by composite priority across the 3 reports. These should ship FIRST.

| # | Feature | Post-GLP-1 | On-GLP-1 | Generic WL | Effort | JeniFit close? |
|---|---------|:---:|:---:|:---:|---|---|
| 1 | **Cohort onboarding question** (5-bucket: on / post / curious / never / not sure) | P0 | P0 | P0 | 1 day | Partial — onb v4.5 needs new screen + `onb_v5_glp1_status` |
| 2 | **Food noise / hunger-return tracker** (daily 0-10 + 3 chips) | P0 (#2: hunger return) | P1 (food noise return day 6-7) | P0 (#4: food noise journal) | 4-5 days | No — net new field; trivial schema |
| 3 | **Adaptive protein floor** (1.2-1.6 g/kg, cohort-tuned target) | P0 (#3) | P0 (#9) | (mechanism layer) | 1-2 days | Partial — food rail tracks; goal is generic 100g |
| 4 | **Pre-eat permission card** (Jeni-voiced 10s decision) | (food rail aware) | (injection-day aware) | P0 (#2) | 3-4 days | Yes — pre-eat mode ships; needs Home promotion + Jeni voice + 3 response variants |
| 5 | **Daily Plate Score** (4-up grid + 1-line caption + share-as-image) | (protein-hit visual) | (injection-day plate view) | P0 (#1) | 5-7 days | Partial — scrapbook polaroid layer exists; daily-collapse missing |
| 6 | **Weekly recalibration / regain-risk card** (Sunday "this week your body" composite) | P0 (#1) | (post-ramp tie-in) | P0 (#5) | 5-7 days | Partial — engine in `ProgramGoalCalculator` + EMA exists; surface is gap |
| 7 | **Cohort-aware Jeni voice + lesson sequence** (3 cohort libraries, 8-12 new lessons) | P1 (#8) | P0 (#13) | (general lessons) | 5-7 days | Yes — JeniMethod manifest + 42 hero photos shipped; need cohort routing |
| 8 | **Sunday weekly recap ritual** (recap → Monday intention) | P1 (#12) | (recovery-week recap) | P1 (Sunday card) | 3-4 days | Partial — `SundayCard.swift` exists |
| 9 | **Silent-week re-engagement** (no-shame "it's been 6 days" nudge) | P1 (#13) | (general retention) | (retention) | 2 days | Partial — `CancellationWinbackSheet.swift` exists; silent-week detector is net new |
| 10 | **Citation footer on research-backed claims** | P2 (#16) | (clinical credibility) | (credibility) | 2 days | Partial — breathwork + Becoming already cite; CBT lessons need it |
| 11 | **Sleep-as-leading-indicator card** (7-day rolling sleep avg) | P1 (#9) | (recovery context) | (general retention) | 2-3 days | Yes — `SleepService.swift` + `LastNightSleepCard.swift` in current diff |

**Convergent stack total effort: ~40-50 dev days = ~6-7 weeks of solo founder work.** This is the foundation that serves ALL cohorts and unblocks the conviction-led positioning.

---

## Cohort-specific stack — Post-GLP-1 only (3 features)

After the convergent stack ships, these complete the post-GLP-1 positioning:

| # | Feature | Priority | Effort | JeniFit close? |
|---|---------|:---:|---|---|
| P1 | **12-week "Keep-It-Off" curriculum** (DPP-shaped, named, finishable) | P0 | 4-5 days | Yes — JeniMethod infra; need curated 12-week sequence + week-numbered PlanView hero |
| P2 | **"We're not Calibrate" non-Rx trust strip** (paywall + settings) | P0 | 1 day | No — net new copy, but easy |
| P3 | **30-day "first month off" milestone** (one-time sticker scatter) | P2 | 1 day | Yes — earned-moment scatter pattern shipped, just new trigger |

**Post-GLP-1 specific total: ~6-7 dev days.**

---

## Cohort-specific stack — On-GLP-1 only (12 features)

This is the heavy stack — the injection ritual + nausea management + dose-aware product behavior. Phase 3 (weeks 6-10) of round-2 plan.

| # | Feature | Priority | Effort | JeniFit close? |
|---|---------|:---:|---|---|
| O1 | **Weekly dose log + injection-day reminder** | P0 (table-stakes) | 2 days | No — greenfield (`InjectionLog` entity) |
| O2 | **Injection-site rotation map** (visual body diagram, 8 zones) | P0 (table-stakes) | 3-4 days | No — greenfield SwiftUI |
| O3 | **Side-effect severity log** (15-20 symptoms, 1-5 scale) | P0 (table-stakes) | 3 days | Partial — `SessionRatings` shape works |
| O4 | **Dose-history timeline view** | P1 | 1-2 days | No, but trivial after O1 |
| O5 | **Nausea-rescue protocol** (in-the-moment 4-step) | P1 (differentiator) | 2-3 days | Yes — breathwork + Jeni voice + LessonReader are 80% of chrome |
| O6 | **Hair-shedding correlation trigger** (3+ logs → protein lesson) | P1 | 1 day | Partial — needs cohort-specific lesson + trigger rule |
| O7 | **Injection-day eating mode** (food rail flips based on InjectionLog) | P1 (differentiator) | 3 days | Yes — food rail v3 + conditional mode |
| O8 | **Hydration anchor** (HealthKit water log + Home strip) | P1 | 1 day | Partial — extend Home health pattern |
| O9 | **Resistance-training program** (3 bodyweight routines, ~15 exercises, 2-day/week template) | P1 (differentiator) | 4-5 days | Partial — workout engine + voice cascade exist |
| O10 | **Body-composition HealthKit sync** (lean mass + body fat %) | P2 | 1-2 days | Yes — extend HealthKit infra |
| O11 | **Dose-cadence notification register** (day-0 / 2-4 / 5-7 voice variants) | P1 | 2 days | Yes — extend `NotificationTimeBucket` |
| O12 | **Off-ramp readiness module** (4-lesson, provider gate) | P1 (long-LTV bet) | 3-4 days | Yes — JeniMethod manifest |

**On-GLP-1 specific total: ~26-32 dev days = ~4 weeks.**

DEFERRED to v1.2: GI-pattern correlation (~5 days), sister-cohort community (3+ weeks, moderation cost).

---

## Cohort-specific stack — Generic WL only (3 features)

After convergent stack, these complete the generic-WL CPP positioning:

| # | Feature | Priority | Effort | JeniFit close? |
|---|---------|:---:|---|---|
| G1 | **Day-1 first-scan magic moment** (onboarding "first scan now" → editorial reveal) | P0 (the conversion-leak fix) | 5-7 days | Partial — scan pipe exists, not wired to onboarding |
| G2 | **Voice food logging** (Whisper API → parse → FoodEntry) | P1 (parity table-stakes) | 5-7 days | No — net new |
| G3 | **NSV chips** (Sunday "which of these did you notice?") | P1 | 3-4 days | No — Becoming barrier-resolved card is close in spirit |

**Generic-WL specific total: ~13-18 dev days = ~2 weeks.**

DEFERRED to v1.2: cycle-aware adaptive program (~6-8 days), streak-free explicit framing (~1 day, copy-only).

---

## The total: ~12-13 weeks of work, ranked by ship sequence

The round-2 plan said 10 weeks. The aggregate from the 3 feature gap reports is ~12-13 weeks. To stay in 10 weeks, defer 2-3 features:
- Defer O10 (body composition HealthKit) to v1.2 — only ~30% of cohort owns smart scale
- Defer G2 (voice logging) to v1.2 — parity table-stakes but not conversion-critical
- Defer O12 (off-ramp module) to v1.2 if needed — long-LTV bet but cohort doesn't need it for first 6 months on the drug

**Net trimmed: ~10 weeks.**

---

## Recommended 10-week phasing (revised from round 2)

### Phase 1 (weeks 1-3) — Convergent foundation that serves ALL cohorts
| Week | Ship | Effort |
|---|---|---|
| 1 | Cohort onboarding question (1d), Adaptive protein floor (2d), Pre-eat permission card promotion + Jeni voice (3d) | 6d |
| 2 | Daily Plate Score (5-7d) | 6d |
| 3 | Food noise / hunger-return tracker (4-5d), Citation footer (2d) | 6d |

**End of week 3:** convergent foundation live. **Cohort routing + daily ritual + protein floor + pre-eat decision + food noise tracker** all ship. The conviction copy on the App Store now has substantiating product behind it. Generic-WL conversion-leak features (pre-eat + plate score + food noise tracker) all live for the generic CPP.

### Phase 2 (weeks 4-5) — Post-GLP-1 positioning depth
| Week | Ship | Effort |
|---|---|---|
| 4 | 12-week "Keep-It-Off" curriculum (4-5d), "We're not Calibrate" trust strip (1d) | 6d |
| 5 | Weekly recalibration/regain-risk card (5-7d) | 6d |

**End of week 5:** post-GLP-1 positioning is fully substantiated. The conviction CPP has the curriculum + the leading-indicator regain card + the trust strip. Phase 2 also adds **Sunday recap ritual + silent-week re-engagement** for retention (3-4d + 2d = 6d) — fits in weeks 4-5 if curriculum is parallelized.

### Phase 3 (weeks 6-10) — On-GLP-1 cohort acquisition
| Week | Ship | Effort |
|---|---|---|
| 6 | Weekly dose log (2d), Site rotation map (3-4d) | 6d |
| 7 | Side-effect log (3d), Cohort-aware Jeni voice + 8-12 lessons (5-7d) | 8d (writing-heavy) |
| 8 | Injection-day eating mode (3d), Resistance routines (4-5d) | 7d |
| 9 | Nausea-rescue protocol (2-3d), Hydration anchor (1d), Dose-cadence notification register (2d), Dose-history timeline (1-2d) | 7d |
| 10 | Off-ramp readiness module (3-4d), Sleep-as-leading-indicator card finalization (2d), QA + cohort routing wiring | 6d |

**End of week 10:** on-GLP-1 cohort dedicated paid acquisition can launch. All cohort-specific features shipped. Day-1 first-scan magic moment slots into onboarding flow somewhere in weeks 7-9.

---

## Top 5 P0 ships if you can only do 5 things in the next 3 weeks

These 5 are the highest-leverage features by composite score across the 3 cohort reports:

1. **Cohort onboarding question** (1 day) — without this, every subsequent feature lands on the wrong user. Cheapest, foundational. Ship Monday.
2. **Adaptive protein floor** (1-2 days) — 1.2g/kg cohort-tuned target. Serves all 3 cohorts. Reuses food rail.
3. **Pre-eat permission card promotion** (3-4 days) — the Cal AI moat + the Jeni voice asset. Already 80% built.
4. **Food noise / hunger-return tracker** (4-5 days) — the lingua franca metric no competitor has. Serves all 3 cohorts. Anti-Noom wedge.
5. **Daily Plate Score** (5-7 days) — the missing 20-second daily ritual. Closes the 7-14% US conversion leak.

**Total: 14-19 dev days = ~3 weeks for one founder.**

After these 5 ship, JeniFit has: cohort routing, the daily ritual, the convergent food rail loop, the leading-indicator metric, and the protein floor. **That's enough to test the conviction-led positioning AND the post-GLP-1 cohort lead simultaneously** at the App Store + paid creative level.

---

## Top 3 P1 differentiators that no competitor has

These are the "uncopyable" features once the P0 stack lands:

1. **Food noise as a tracked metric** (chip-driven + numeric, surfaced in weekly recalibration card) — MeAgain tracks injections; WW tracks Points; nobody tracks the subjective return of the noise. Cohort lingua franca per PEAK Wellness + Northwell + Ubie Health.
2. **Non-Rx trust strip + honest pricing** — the cohort is burned by telehealth bundles ($300-1500/mo) and by deceptive billing (Cal AI App Store removal April 2026, MFP 1.4-star Trustpilot). Being publicly, structurally NOT in those games is a moat the bundle competitors cannot match without destroying their LTV math.
3. **Off-ramp readiness module + 12-week Keep-It-Off curriculum** — Embla is the only validated off-ramp in market and it's enterprise-only. Consumer space is open. Owning the off-ramp lesson sequence is the on-GLP-1 → post-GLP-1 cohort transition bridge — 12+ month LTV bet aligned with v2 strategy.

---

## What's already in flight (per current diff)

Of the 26 unique features identified across the 3 reports, **5 are already being built** in the current uncommitted diff — strong signal the founder's intuition is converging with the research:

- `PlankApp/Health/SleepService.swift` — Sleep-as-leading-indicator (convergent #11)
- `PlankApp/Views/Analytics/LastNightSleepCard.swift` — Sleep card surface (convergent #11)
- `PlankApp/Views/Paywall/CancellationWinbackSheet.swift` — Re-engagement pattern (convergent #9 foundation)
- `PlankApp/Notifications/NotificationTimeBucket.swift` + `RetentionNotifications.swift` — Cadence notification infra (convergent #8 + on-GLP-1 #O11)
- `PlankApp/Views/Trial/` — Trial flow (paywall + cohort routing infra)

The proposal is to **explicitly cohort-frame** what's already being built and ship the top-5 P0 net-new pieces alongside.

---

## What to NOT ship (anti-features)

Across all 3 reports, these features were explicitly rejected:

- **AI face scan / "Future Me" visualization** (Noom Oct 2025) — brand-incompatible with anti-femvertising
- **Streaks** (v2 strategy non-negotiable) — anti-cohort psychology
- **Public leaderboards / challenges** — anti-shame violation
- **Calorie-deficit explicit framing** — toxic-tracker register the cohort is fleeing
- **Sister-cohort community / forums** — solo founder cannot moderate at safe latency; defer to v1.2
- **GLP-1 brand names on App-controlled surfaces** (Apple 5.2.1)
- **First-party numeric weight-loss claims** (FTC NextMed precedent)
- **"GLP-1 alternative" / "natural Ozempic"** (FDA Feb 2026 warning letters)

---

## Sources

- `docs/feature_gap_post_glp1_2026_06_16.md` — 16 features, post-GLP-1 cohort deep-dive
- `docs/feature_gap_on_glp1_2026_06_16.md` — 16 features, on-GLP-1 cohort competitive teardown
- `docs/feature_gap_generic_wl_2026_06_16.md` — 12 features, generic-WL CPP + Cal AI/MFP/Noom landscape
- `docs/positioning_research_r2_final_2026_06_16.md` — round-2 positioning report (parent context)
