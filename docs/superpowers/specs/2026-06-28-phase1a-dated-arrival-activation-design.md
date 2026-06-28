# Phase 1a — "The Honest Arrival" Activation Loop (Design Spec)

**Date:** 2026-06-28
**Status:** Approved design, ready for implementation plan
**Owner:** founder + Claude
**Related memory:** `project_results_engine_positioning_2026_06_28`, `project_monetization_pay_upfront_2026_06_27`, `project_posthog_findings_2026_06_21`, `project_medical_grade_roadmap`, `project_glp1_cohort_strategy`

---

## 1. Why

PostHog (last 2–9 days) shows the funnel-to-paid is healthy (~7.6% install→paid) but **retention collapses**: D0→D1 return ~6% (healthy = 25–40%), only ~5% of onboarding-completers touch any feature, and even **payers return at ~32% over 2 days**. On a no-trial / pay-upfront model that 32% is a refund/churn risk.

Validated positioning (6-expert panel + 3-reviewer design audit): JeniFit is a **"results engine"** — a guided, *dated*, adherence-maximizing, plateau-proof, safety-gated plan — not a passive tracker (Cal AI) and not a feel-good soft app. Tagline: **"the serious plan that actually works — built so it won't hurt you."** North-star metric = **D30 engagement**, not D1.

Phase 1a is the first build: fix **payer activation and the ~32% payer-return problem** by making the post-paywall experience deliver *payoff before task*, on a **forgiving, habit-based arrival horizon**, with **clinical safety brakes baked in**. Non-payer (pre-paywall) activation is deliberately parked.

## 2. Goal / Non-goals

**Goal:** Every new payer (a) gets an instant, competent, *realistic* read of their situation as the first thing they see; (b) makes one near-zero-effort promise that schedules their Day-1 return; (c) returns Day-1 to collect a kept-promise win; (d) is never exposed to an unsafe pace, a weight-deadline, or a shame trigger.

**Non-goals (explicitly out of Phase 1a):**
- Pre-paywall free action for non-payers (parked).
- Adaptive targets / real-TDEE recalibration (Phase 3).
- Plateau-detection + re-anchor engine (Phase 3).
- Full validated ED screen / SCOFF intake (Phase 2). *Only the cheap guardrails move into 1a.*
- GLP-1 protein-first threading, satiety signal, share card (→ **Phase 1b**, fast-follow).

## 3. The core reframes (from the review panel)

1. **"On-track" = on-track-with-your-HABITS, never on-track-to-a-weight.** The progress indicator measures *behavior completion* (promises kept, actions done), never predicted pounds. This is simultaneously the clinical-safety, the compliance (FTC/Apple — no implied numeric weight-loss claim), and the UX-backfire fix.
2. **The date is a forgiving arrival HORIZON, not a deadline.** Displayed as "~[date]", recomputes gently, **never turns red, never says "behind."** A missed day moves the date by a day, framed *"your timeline is yours."*
3. **Payoff before task.** Plan reveal becomes an **assessment-as-payoff**; the first *real* log is committed to tomorrow (no forced day-0 log).
4. **Amplifier and brake ship together.** The dated hero + daily ritual (motivation amplifiers) cannot ship without the safety brakes (§5) in the same release.
5. **Medical-grade = trust via restraint + transparency, not clinical coldness.** Dual register on the same surface: a warm identity line (JeniHeroSerif) + a quiet data line (DMSans). Keep the cream palette; no hospital aesthetic.

## 4. Components

### 4.1 Assessment-as-payoff plan reveal *(highest leverage)*
At plan reveal, synthesize the user's *own* onboarding inputs into a competent, transparent, **realistic** read of her arc — delivered before any to-do.
- **Content:** a one-line identity statement (serif) + a quiet data line citing *her* inputs and the derived plan, e.g. `pace 0.5%/wk · arrival ~Sep 14 · set conservatively`. Transparent provenance: *"because you sleep ~6h, we set a gentler pace."*
- **Credibility beat:** one quiet line — *"paced like a clinician would — slower is what lasts."* This is the anti-scam trust signal.
- **Word discipline:** lead with **"realistic."** Never a first-party numeric weight-loss promise.
- **Code hook:** `OnboardingRevealView` reveal sequence (steps enum lines ~64–81, body switch ~92–135); enrich the `.projection` step (`BecomingProjectionCard`) or insert a dedicated `.assessment` step before the existing reveal tail. Reads derived plan from `ProgramGoalCalculator` / active `ProgramPlanRecord`.

### 4.2 Safety guardrails (moved into 1a from Phase 2)
- **Pace clamp:** implied loss clamped to **≤0.5–1% body weight/week**. If a user's desired date implies a faster rate, **move the date out, not the deficit up**, and say so. Implemented in `ProgramGoalCalculator`.
- **BMI floor:** never let a derived goal weight imply BMI < ~18.5–20; soften/refuse underweight targets.
- **Rapid-loss tripwire:** render-time check on existing weight logs (EMA/trend) — if trend-weight drops faster than the safe envelope over a rolling 2–3 weeks, soften the plan and surface a gentle care check-in ("you're losing faster than we plan for — let's make sure you're eating enough"). No new intake.
- **Logged disclaimer + exclusion ack:** a lightweight, logged "not medical advice / not for pregnancy / talk to your clinician if…" + data-use acknowledgment before plan reveal. Required for App Review (healthcare-fitness) and partnerability.
- **Clinical baseline capture:** persist clean, timestamped typed fields — height, starting weight, computed BMI, age, goal weight, target rate (lb/wk *and* %/wk), and the existing `onboarding_glp1_status` as a queryable clinical field. Most are already collected; formalize them as the clinical record so future outcome data is auditable.
- **Defer to Phase 2:** the full validated ED screen — and when built, it is **triage-to-resources, not pass/fail clinical clearance** (SCOFF is not validated for sub-threshold disordered eating).

### 4.3 Forgiving habit-based arrival horizon (home hero)
- Home hero shows **"~[date]"** + a **habit/behavior** status (e.g. "you're showing up — 4 of 5 this week"), render-only.
- **Never** displays projected weight, "behind," red, or a countdown. Recomputes gently on a miss with *"your timeline is yours."*
- **Code hook:** Today/Plan home surface + `PlanView`; reads the active `ProgramPlanRecord` date + a behavior-completion count.

### 4.4 Commitment ritual: form → promise *(replaces the dead `.trialPromise` step)*
The no-trial decision makes `TrialPromisePresentation` obsolete — replace it with the ritual as the reveal's emotional climax.
- **Mechanic:** an implementation intention — *"tomorrow at [time], after [anchor], I'll [first action]."*
- **Form → promise:** pre-fill smart defaults from known data (short sleeper → "after I wake up"; logged morning routine → "coffee") so she **confirms a promise**, not fills a form. Replay it back in her own words in JeniHeroSerif — *"tomorrow, after coffee, you begin."* Soft haptic on commit. Saved as an artifact surfaced at the top of Day 1.
- **Schedules** the Day-1 notification in her words at her chosen time.
- **Code hook:** replace `.trialPromise` in `OnboardingRevealView` (line ~135); store to `@AppStorage`; new `NotificationPermission.scheduleDay1Promise(at:body:)` (in `OnboardingComponents.swift` alongside `scheduleDailyReminder`, id namespaced e.g. `day1_promise`).

### 4.5 Earned-only endowed progress
At plan reveal show progress as **earned + explained** — *"step 1 of your plan: complete (you did the assessment)"* — **never** a naked percentage on a body she hasn't changed. Naked % reads as manipulation to a Cal-AI-trained skeptic and erodes medical-grade trust.

### 4.6 Payer routing: payoff → promise (no blank home)
On purchase success, route into the assessment-payoff + ritual, **not** the root tab and **not** a forced day-0 log.
- **Code hook:** `PlankAIApp.swift` `onSubscribed` → `presentPostPurchaseFlowIfEligible()` (~line 2343).

### 4.7 Day-1 kept-promise win
Day-1 push fires her own words → she taps → does the one small action → the app marks the **promise kept** (not a streak) and the arrival horizon visibly "locks in" one notch. First win = *"I did the thing I said I would"* (self-efficacy), never the scale.

### 4.8 D0–D3 notifications keyed to activation-state
- Branch `RetentionNotifications` on "completed onboarding && no core action yet."
- **Hard cap 3 across 3 days**, each in **her words or her data**, never generic "don't forget to log," never deficit/scale-flavored, never streak-loss. Suppress if she already acted that day.
- **Code hook:** `PlankApp/Notifications/RetentionNotifications.swift` (cohort-aware variants already exist) + `NotificationPermission`.

## 5. Compliance (FTC / Apple floors)
- **No implied first-party numeric weight-loss claim.** "On-track" is defined in-product as on-track-with-habits; the date is a goal/horizon, not a prediction. One quiet disclaimer: timelines are goals, individual results vary.
- Notifications stay identity/behavior-framed — never "you'll lose / you're down / on pace to lose."
- No drug names, no drug-equivalence, no "GLP-1 alternative" framing on any surface.
- Provenance rule honored: every number traces to a collected field.

## 6. Data model additions
- Clinical baseline fields (§4.2) — typed, timestamped.
- Behavior-completion / "promises kept" counter (drives §4.3 + §4.7).
- (Phase 1b seeds, schema only: `dose_phase` enum, protein-attainment + satiety history.)

## 7. Success metrics
- **Primary:** payer D2 return rate (baseline ~32% → target ↑), D7 + D30 engagement (north star).
- **Secondary:** % of payers who complete the ritual; % who collect the Day-1 kept-promise win; % of completers reaching any first action.
- **Guardrail/safety:** count of rapid-loss tripwire fires; zero goals shipped below BMI floor; zero red/"behind"/deadline strings in shipped copy.

## 8. Risks & guards
| Risk | Guard |
|---|---|
| Desperation paradox (fast disappointment) | First win = kept-promise + being assessed, never the scale; payoff before task |
| Goal-date as failure deadline | Forgiving "~date," recomputes, never red/"behind" |
| Shame / ED triggers | No red bars, no "behind," no streak-loss, no good/bad food; clamp + BMI floor + tripwire |
| Over-promise → trust collapse | Word "realistic"; conservative pace as a feature; no numeric promises |
| Endowed progress reads as manipulation | Only earned, explained progress; no naked % |
| Over-clinical coldness | Dual register (serif identity + quiet data line); keep cream; no hospital aesthetic |
| Notification nagging | Cap 3, personalized, activation-state-keyed |

## 9. Open questions
- Exact placement of the assessment-payoff: enrich existing `.projection` step vs a new `.assessment` step? (Decide during implementation against the current reveal sequence.)
- Behavior-completion status copy for the home hero (needs founder voice pass).
- Whether the rapid-loss tripwire check runs at app-open vs on weight-log write (prefer on-write + at-open re-evaluate).
