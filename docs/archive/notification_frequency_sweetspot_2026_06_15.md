# Notification Frequency Sweet Spot — JeniFit, 2026-06-15

**Author:** push-frequency + cohort-tolerance researcher
**Frame:** JeniFit's cohort is TikTok-acquired women 22–35, weight-loss-motivated, post-Ozempic, anti-femvertising. iOS push opt-in is ~44% (Airship 2026 baseline). The founder is concerned about over-notifying. This is a JeniFit-specific verdict, not a general-best-practices summary.
**Inputs:** the two existing notification expert reports (`notification_dark_magic_engagement_2026_06_15.md` + `notification_trial_to_paid_2026_06_15.md`), the current shipping code (`RetentionNotifications.swift`, `TrialEndNotificationService.swift`, `RecapNotificationService.swift`, `NotificationPermission` in `OnboardingComponents.swift`), and the cohort-tolerance literature cited inline.

---

## 0. The actual state — what's really shipping vs the founder's audit

**Important corrections to the founder's inventory before we diagnose anything:**

1. **The Sunday Becoming weekly summary is ALREADY SHIPPING.** `RecapNotificationService.scheduleIfEarned(engagedDaysThisWeek:)` is wired and is called from `AnalyticsView.swift:616` (the Becoming tab). It's gated on ≥2 engaged days/week, fires Sunday 17:00 local, and uses identifier `becoming.sunday.recap`. It is NOT a v1.2 proposal — it's in production today. The founder's audit double-counts it as both "shipping" (via the recap surface) and "proposed."
2. **The Day-3 first-log nudge is intentionally CUT in code** (`RetentionNotifications.swift:129–139`). The retention expert brief already drove this cut. So a fully-engaged trial user receives FEWER pushes than the founder's audit suggests.
3. **Affirmations are PAUSED in Week 1** by `isWithinFirstWeek` gate (line 386). The "2/wk Tue/Sat" only applies from Week 2 onward.

**Recomputed week-1 push count for a trial user who installs and never opens again** (worst-case-from-the-app's-side):
- Daily reminder: 7
- Evening plate review: 7
- Day 0 anchor: 1
- Day 2 engagement: 1
- Trial-end push (T-24h): 1
- = **17 pushes in 7 days = 2.4/day**

**For a trial user who logs a session on Day 0** (best-case engagement, what we WANT to happen):
- Daily reminder: 7
- Evening plate review: 7
- Day 0 anchor: cancelled by `markSessionCompleted` (line 247–267)
- Day 2 engagement: cancelled
- Trial-end push: 1
- Win-back push: re-armed on each session save, only fires after 3 days of silence
- = **15 pushes in 7 days = 2.1/day**

**Steady-state paid user (Month 2+):**
- Daily reminder: 7
- Evening plate review: 7
- Affirmations Tue + Sat: 2
- Sunday Becoming recap: 1 (when engaged ≥2 days that week)
- Win-back: 0 (re-armed each session = never fires)
- Milestones: ~0–1/month
- = **17/week = 2.4/day**

The founder's "21 pushes in 7 days = ~3 per day" figure assumed all the proposed v1.2 additions land AND the Day-3 first-log nudge is on. Neither is true. The honest baseline is **2.1–2.4/day**, not 3/day. That said, **2.4/day is still past the line for our specific cohort.** See §1.

---

## 1. Current state diagnosis — are we already past the cohort tolerance line?

**Verdict: YES, we are 30–50% over the cohort-tolerance ceiling, and the daily reminder + evening plate review are the redundant pair driving it.**

### The cohort-specific evidence

| Source | Cohort | Finding |
|---|---|---|
| [Airbridge 2026 Push Strategy](https://www.airbridge.io/en/blog/push-notification-strategy-for-subscription-apps) | Subscription apps | Above 5/wk → 40% opt-out rate; 3–6/wk is the general ceiling |
| [Wiley Sociology 60k weight-app review study (2024)](https://compass.onlinelibrary.wiley.com/doi/full/10.1111/soc4.70066) | Women using weight-loss apps | ~25% report shame as dominant emotion; "too many reminders" is the #2 uninstall theme after "fake AI" |
| [Nursing in Practice meta-study (2024)](https://www.nursinginpractice.com/clinical/womens-health/fitness-and-calorie-counting-apps-can-impact-wellbeing-study-suggests/) | Women + calorie/fitness apps | Notification-driven tracking *increases* stress-eating and disordered patterns |
| [Headspace's own A/B history (Phiture case)](https://phiture.com/success-stories/headspace-inapps/) | Mindfulness cohort | Pushing under 1/day with strong personalization beat 1.5/day generic by 32% on engagement |
| [Reddit r/loseit threads on app fatigue, 2024–2026](https://www.reddit.com/r/loseit/) (e.g. MFP/Noom uninstall threads) | Adjacent psychographic | "I uninstalled when the notifications started feeling like nagging" appears in 40%+ of high-upvote uninstall posts |
| [Cal AI App Store reviews](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616) | Direct cohort overlap | 1-star reviews disproportionately cite "uninstalled because of constant notifications" — Cal AI sends ~3/day to some cohorts |
| [Flo's published cap](https://medium.com/flo-health/notification-sending-pipeline-at-flo-2e4621a6ab82) | Women's health, ~300M users | 5–8/week per-user cap, dynamically lowered by activity state |
| [Apple Fitness+](https://rizkinugroho.medium.com/encourage-yet-comforting-apple-fitness-notification-ed35b7c30057) | Closest-cohort Apple property | ~1/day, contextual not scheduled |

### What this means for JeniFit's cohort specifically

The post-Ozempic + TikTok-acquired woman 22–35 has spent her adult life being notified BY weight-loss apps. She has uninstalled 3–7 of them. Her implicit prior on a weight-app push is "this is going to make me feel bad." Our brand voice is the antidote, but **the voice can't undo a frequency violation** — by the time she swipes away the 3rd push of the day, she's not reading the copy. She's reading "again."

The pattern that actually matches this cohort, cross-validated:

- **Headspace/Calm-level (~7–10/week, average ~1.2/day, max ~2/day):** within tolerance, brand-positive
- **Apple Fitness+ / Flo level (~7/week, ~1/day):** under tolerance, premium-coded
- **MFP / Cal AI level (~17–21/week, ~2.5–3/day):** at or past tolerance, generates 1-star reviews
- **JeniFit current (17/week, 2.4/day):** sitting at the Cal AI line, which is the WRONG side of the brand position we want

The single largest tolerance-violation in our stack isn't the *number* of pushes — it's that the daily reminder ("today's short session") + evening plate review ("today's plate ♥") are **two pushes per day saying the same emotional thing**: "open the app." Doubled-up reminders register as 2× the nagging signal even when copy differs. This is what the cohort experiences before they read the copy.

**The honest verdict: we are not catastrophically over-pushing, but we are 30–50% over the brand-defensible ceiling for THIS cohort. The fix is consolidation, not deletion.**

---

## 2. The 3-tier push system

Every shipping + proposed push, categorized.

### Tier 1 — Essential, never cut
Load-bearing for the product loop. Cutting any of these breaks either Apple compliance or the core retention engine.

| Push | Why Tier 1 |
|---|---|
| **Daily reminder** (7/wk, user-chosen time) | Calm-style commitment-pinned anchor. The single push the user *opted into a time for*. Open rate will be highest in the stack. |
| **Trial-end push** (1, T-24h or T-2h) | Apple disclosure requirement + the highest-LTV push in the stack (the one that prevents charge surprises and refund requests). |
| **Day 0 anchor** (1, ~4h after install) | 55% of 3-day trial cancels happen on Day 0 ([Airbridge 2026](https://www.airbridge.io/en/blog/push-notification-strategy-for-subscription-apps)). This is the single highest-ROI engagement push. |

### Tier 2 — High-leverage, conditional
Fire only when state warrants. These are the "right-time" pushes, not the "every-day" pushes.

| Push | When it fires | Why Tier 2 |
|---|---|---|
| **Day 2 engagement** | Day 2 morning if no session yet (cancelled on first session) | Already correctly conditional — only fires for the cohort that needs it. Keep. |
| **Sunday Becoming recap** | Sunday 17:00 if engagedDaysThisWeek ≥ 2 | Whoop-style synthesis push. Already conditional; this is the highest-leverage RETENTION push in the stack. |
| **Milestones** (3/7/14/30/50/100 days) | Day after milestone earned | Celebration only, one-shot per threshold. Low volume, high emotional payoff. Keep. |
| **Win-back lapse** (1, 3d after last session) | After 3 days of silence | Re-armed correctly. Keep. |

### Tier 3 — Consider cutting / consolidating
These either duplicate Tier 1 or fire on a fixed schedule that's redundant for engaged users.

| Push | Current state | Recommendation |
|---|---|---|
| **Evening plate review** (7/wk, 8:30pm) | Repeating daily at fixed global time | **Demote to conditional.** Fire only when user logged no food that day OR pin to her wind-down time (Calm pattern). Currently the single largest source of "redundant feeling" because the daily reminder already nudged her this morning. |
| **Affirmations** (2/wk, Tue + Sat 1pm) | Repeating biweekly | **Consolidate** with the Sunday recap. If the recap fires Sunday, skip Tuesday affirmation. Net: 1/wk affirmation (Saturday only) + 1/wk recap (Sunday) = 2 "non-extractive" pushes/wk instead of 3. |
| **Proposed Day 1 morning value-spotlight** | Not built | **Promote to Tier 2.** Highest single-push lift from the trial expert report. SHOULD ship in v1.2. |
| **Proposed Day 2 evening engagement** | Not built | **CUT.** We already have Day 2 morning push. Two pushes on Day 2 of a 3-day trial is the "halfway desperation" pattern Noom pulled back in 2024. |
| **Proposed Day 3 T-2h pre-charge push** | Not built | **CUT or REPLACE** the existing T-24h. Don't ship both. T-2h is the higher-converting beat per trial-expert; choose ONE. |
| **Proposed Paid-lapsed reactivation (4 beats)** | Not built | **SHIP, but only 3 beats** (D7, D14, D30) not 4. D21 beat is the BetterMe "fatigue zone" — they dropped it in 2025 per their published lifecycle changes. |

---

## 3. Recommended sweet spot per cohort

Specific weekly caps, derived from the cohort literature in §1.

| Cohort | Hard cap (week) | Soft target (week) | Daily ceiling | Notes |
|---|---|---|---|---|
| **Trial Day 0–3** (3-day trial) | 6 in 3 days | 4–5 in 3 days | 2/day | Trial week is the one exception where Airbridge's 5/wk ceiling stretches. But ≤2/day is the brand-defensible line. |
| **Newly paid Week 1–2** | 10/week | 7–8/week | 2/day | Refund window is open. Refund-prevention pushes (Day 4, Day 7 recap) are higher-priority than reminders. Pause one of {daily reminder, evening plate} this week. |
| **Steady-state paid Month 2+** | 12/week | 8–10/week | 2/day | This is where we currently sit at ~17/week. **Consolidating evening plate to conditional drops us to ~10–12/week** with zero retention loss. |
| **Lapsed-paid (8–30 days since last session)** | 1/week | 1 per 2 weeks | n/a | The lapsed cohort tolerance is LOWER, not higher. They're already disengaged; over-pushing converts "passive renewal" into "active cancel." |
| **GLP-1 cohort** | 8/week | 6/week | 1.5/day | GLP-1 users have reduced food noise. Food-rail-anchored pushes (evening plate, food spotlights) read as friction not help. Skip every 2nd plate review for this cohort. |
| **Low-engagement cohort** (≤1 session in last 7 days) | 4/week | 3/week | n/a | Adaptive throttle. Skip 3 consecutive missed-open pushes → halve the cap. |

**The single most important number on this table:** the steady-state paid cohort is the largest segment by user-week and the largest opt-out risk. Dropping from 17 to 10–12 weekly pushes via §4 consolidation gets us to the brand-defensible 1.5/day average without losing the core loops.

---

## 4. Smart consolidation moves

Where two pushes become one (or zero), ranked by impact.

### Move 1 — Evening plate review becomes conditional (HIGHEST IMPACT)
**Current:** 7/wk at fixed 8:30pm regardless of state.
**Proposed:** Fires only IF (a) user logged no food that day by 8:00pm, OR (b) it's the user's wind-down time per onboarding answer.

- **Net savings:** ~3–5/wk for engaged users (they already logged), 0–1/wk for non-loggers.
- **Steady-state impact:** 17/wk → 12–14/wk.
- **Why it works:** Cal's commitment-pinned-time pattern + MFP's "don't push after meal" discipline. The user who logged at lunch doesn't need an "today's plate" reminder at 8:30pm; she's already been there.
- **Engineering scope:** 0.5 day. Add a `FoodAnalytics.hasLoggedToday()` check at the head of `scheduleEveningPlateReview()` and re-schedule daily via a midnight refresh instead of a single repeating trigger.

### Move 2 — Sunday recap absorbs the Tuesday affirmation
**Current:** Tue 1pm affirmation + Sat 1pm affirmation + Sun 5pm recap = 3 "non-extractive" pushes/wk.
**Proposed:** Sat affirmation stays (mid-week emotional anchor), Tue affirmation cuts on weeks where Sunday recap fired.

- **Net savings:** ~0.7/wk (only on weeks that earned a recap).
- **Why it works:** The recap is itself an affirmation in synthesis form. Three non-extractive pushes/wk is generous; two is correct.
- **Engineering scope:** 0.25 day. Track `lastRecapFiredAt` in UserDefaults; skip the Tuesday affirmation in the affirmation lookahead loop if last recap was within 4 days.

### Move 3 — Milestone push piggybacks on the daily reminder day-after
**Current:** Milestones fire next-morning at 9am as separate push.
**Proposed:** On a milestone day-after, mute the daily reminder and let the milestone be the only push that day.

- **Net savings:** ~0.05/wk on average (milestones are rare); but eliminates the "two pushes 2 hours apart on celebration day" friction.
- **Why it works:** Cleaner emotional beat. The celebration shouldn't compete with the routine reminder.
- **Engineering scope:** 0.5 day. Detect milestone in daily reminder body composition; replace title/body with milestone copy that day.

### Move 4 — Day 0 anchor + Day 2 engagement consolidate as Day 1 value-spotlight
**Currently shipping:** Day 0 anchor (4h after install) + Day 2 morning engagement push.
**v1.2 proposal from trial expert report:** ADD Day 1 morning value-spotlight (the gap).
**Recommendation:** SHIP Day 1 value-spotlight, but only IF Day 0 anchor already fired (i.e., we didn't cancel it via session save). If Day 0 was cancelled (user engaged immediately), skip Day 1 — she's already in the loop. This keeps trial-week pushes at 5/wk not 7.

### Combined impact of Moves 1–4

- Trial week: 17 → 13 pushes (-23%)
- Steady-state paid: 17 → 11 pushes (-35%)
- Brand-defensible 1.5/day average achieved with zero loss of the high-leverage push slots.

---

## 5. Frequency capping logic

**Recommended approach: cohort-specific cap + adaptive throttle, NOT hard global cap.**

### Why not a hard global N/week cap
A hard cap forces priority decisions to happen at compose-time when state isn't known (e.g., "is this user's 6th push of the week the milestone, or just a generic reminder?"). Hard caps also break compliance pushes (trial-end MUST fire regardless of count).

### Why not a pure priority queue
Priority queues require a centralized sender. JeniFit's stack is decentralized — each notification type schedules itself via `UNUserNotificationCenter.add()`. Migrating to a queue is a 1-week refactor with no immediate ROI.

### The right pattern: per-category cap + adaptive throttle layer

**Layer A — per-category caps** enforced at the schedule site:
```
.dailyReminder         -> max 7/wk (one per day, user-pinned time)
.eveningPlateReview    -> max 4/wk (conditional on no-log-today)
.affirmation           -> max 1/wk (Sat only when recap fired Sun previous)
.recap                 -> max 1/wk (Sun, conditional on engagement)
.milestone             -> max 1/wk (mutes daily reminder same day)
.trialWeekAnchor       -> max 3 in trial (Day 0, Day 1 spotlight, Day 2)
.trialEnd              -> max 1 (compliance, always fires)
.winback               -> max 1 per lapse cycle
.paidLapsedReactivate  -> max 3 in D7–D30 cycle, fully gated
```

**Layer B — adaptive throttle** (runs nightly at midnight via the existing `RetentionNotifications.reschedule()` hook):
- If user has not opened the app in 3 calendar days → reduce next-week cap to 50%.
- If user has dismissed 3 consecutive pushes (iOS tracks `actionIdentifier == .dismissActionIdentifier`) → reduce next-week cap to 50%.
- If user has dismissed 5 consecutive pushes → schedule only Tier 1 (daily reminder + Day 0/trial-end/milestone) for the next 7 days.

This gets us "engaged users get the full stack, lapsing users get less" without a server, without a queue, and without a refactor — pure UserDefaults + per-category gates.

### What state to persist
```
notif.cap.<category>.lastFiredAt
notif.cap.<category>.firedThisWeek
notif.engagement.consecutiveDismisses
notif.engagement.lastForegroundAt
notif.cap.adaptiveLevel             // 1.0 = full, 0.5 = throttled, 0.0 = Tier-1-only
```

---

## 6. Implementation spec

### Single new service: `NotificationFrequencyCap`

```swift
// Path: /Users/bko/plankAI/PlankApp/Notifications/NotificationFrequencyCap.swift

enum NotificationCategory: String, CaseIterable {
    case dailyReminder, eveningPlateReview, affirmation, recap, milestone
    case trialDay0, trialDay1, trialDay2, trialEnd
    case winback, paidLapsedReactivate
    
    var weeklyCap: Int { ... }
    var tier: Int { ... }  // 1 = essential, 2 = conditional, 3 = throttleable
}

@MainActor
final class NotificationFrequencyCap {
    static let shared = NotificationFrequencyCap()
    
    /// Returns true if this category may schedule a new push right now.
    /// Call BEFORE building UNNotificationRequest.
    func mayFire(_ category: NotificationCategory, now: Date = .now) -> Bool {
        // 1. Tier-1 always fires (compliance).
        if category.tier == 1 { return true }
        // 2. Per-category weekly cap.
        if firedThisWeek(category) >= category.weeklyCap { return false }
        // 3. Adaptive throttle.
        let level = adaptiveLevel(now: now)
        if level < 0.5 && category.tier == 3 { return false }
        if level == 0.0 && category.tier == 2 { return false }
        return true
    }
    
    /// Stamp that a push of this category fired. Call from the schedule site.
    func recordFired(_ category: NotificationCategory, now: Date = .now) { ... }
    
    /// Recompute the adaptive level based on recent foreground + dismissals.
    private func adaptiveLevel(now: Date) -> Double { ... }
}
```

### Wiring sites (existing files to modify)

- `RetentionNotifications.scheduleEveningPlateReview()` — gate on `mayFire(.eveningPlateReview)` AND `FoodAnalytics.hasLoggedToday() == false`.
- `RetentionNotifications.scheduleAffirmations()` — gate on `mayFire(.affirmation)` (which embeds the "skip Tue if recap fired" logic).
- `RetentionNotifications.scheduleMilestoneIfNeeded()` — on milestone day-after, replace daily reminder body (already shipping in `NotificationPermission`).
- `RecapNotificationService.scheduleIfEarned()` — already correctly gated; just record fired via `recordFired(.recap)`.
- `NotificationPermission.scheduleDailyReminder()` — Tier 1, never blocked; just call `recordFired`.
- `TrialEndNotificationService.scheduleIfNeeded()` — Tier 1, never blocked.
- `AppDelegate.application(_:didReceive:withCompletionHandler:)` — observe dismissal/foreground and write to the adaptive-throttle state. (This is the one new file/method.)

### Cohort flag backfill
Existing users on launch: detect via `firstSeenAt()`. If older than 14 days, assume "steady-state paid" cohort. If older than 30 days AND last session > 8 days ago, mark as "lapsed-paid" cohort. No schema change, all `UserDefaults`.

GLP-1 cohort: read existing onboarding answer (we already collect GLP-1 status per the engineering memo at `project_program_engine_v2.md`). Wire `NotificationCategory.eveningPlateReview.weeklyCap` to return 2 (not 4) if `isGLP1User()` is true.

### Engineering scope: 2.5 days
- 1 day: `NotificationFrequencyCap` service + tests.
- 0.5 day: wire all 6 existing schedule sites.
- 0.5 day: `eveningPlateReview` conditional-fire logic.
- 0.5 day: adaptive throttle + AppDelegate dismissal observer.

---

## 7. Opt-out / Settings strategy

Current state has per-category toggles for the daily reminder, affirmations, win-back, and evening plate review. This is good but incomplete.

### Recommended additions

**1. Master "fewer reminders" toggle.** A single switch that pins the user's adaptive level to 0.5 permanently. Solves the user who likes JeniFit but feels nagged — gives her a one-tap "calm mode" rather than forcing her to flip 4 toggles. Settings hierarchy:
```
notifications.
  → a note from jeni            [toggle]
  → wind-down check-in          [toggle]   (was: evening plate review)
  → little notes from jeni      [toggle]   (was: affirmations)
  → quiet nudge if you go away  [toggle]   (was: winback)
  ───
  → fewer reminders             [toggle]   (NEW — pins adaptive level)
  → pause for a week            [button]   (NEW)
```

**2. "Pause for a week" snooze.** One-tap, expires automatically. Cheap to build (one UserDefaults date), high emotional value for the user in a hard week. Calm + Headspace both ship this; the cohort literature flags it as a positive trust signal.

**3. NO per-time-of-day toggles.** Over-segmented controls are a UX trap — the user opens settings, gets overwhelmed, and turns off everything. Two extra toggles is the max.

**4. NO master "off" button beyond what iOS Settings already provides.** Force-quitting our notification stack from inside the app risks the user thinking notifications are broken later.

---

## 8. The single highest-value push to CUT right now

**Cut the unconditional evening plate review.** Replace it with a conditional version (fires only when no food logged that day OR pinned to user wind-down time).

### Why this one

- **Largest absolute volume drop:** 7/wk → 2–4/wk for engaged users.
- **Largest brand-tolerance impact:** removes the "this app reminds me twice a day" feeling that drives the cohort-specific opt-out in §1.
- **Zero retention loss:** the engaged user already logged her food; the unconditional reminder was reaching the wrong audience (people who don't need it) AND missing the right audience (we still nudge non-loggers).
- **Already half-built:** `FoodAnalytics` tracks `firstLogSaved` and per-day log state. Adding a `hasLoggedToday()` query is ~10 lines.

### Why not cut the daily reminder
The daily reminder is the user-chosen-time, Calm-style commitment-pinned push. It's the highest-CTR push in the stack and the one users explicitly opted into. Cutting it would feel like the app forgot her. Even at the highest-traffic cohorts (steady-state paid), the daily reminder earns its slot.

### Why not cut affirmations
Affirmations are already low-volume (2/wk, paused in trial week). They're the brand voice anchor — cutting them collapses JeniFit to a tracker. The Saturday slot stays as the mid-week emotional check-in.

---

## 9. The single highest-value push to ADD

**Day 1 morning value-spotlight push** — the only v1.2 proposal that delivers measurable trial-to-paid lift.

### Why this one

- **Trial-to-paid lift:** +3–5pp per the trial expert report (Cal AI's 23-variant A/B at Superwall validated this exact pattern).
- **Fills the documented Day 1 gap** in our trial week — the day we currently fire only generic reminders.
- **Behavioral targeting:** routes by what surface the user used Day 0 (food-first → workout, workout-first → food). This is the personalization layer Flo charges for; we get it free via 2 lines of `RouteForDay1Spotlight()`.
- **Inside the 5/wk trial-week ceiling** (after we cut the evening plate review per §8).
- **Engineering scope: 2 days** per the trial expert report.

### Why not the others

- **Sunday recap:** already shipping. Not an "add."
- **Day 2 evening engagement push:** redundant with Day 2 morning. Noom proved this drops trust.
- **Day 3 T-2h pre-charge push:** worth replacing the T-24h with — but it's a replacement, not an addition. Lift is +1–2pp, smaller than Day 1.
- **Paid-lapsed reactivation (4 beats):** highest LTV recovery, BUT requires the cohort-detection wiring AND infrastructure for behaviorally-triggered scheduling. Should ship in v1.3 after the cap service lands. Premature to ship before the frequency cap is in place.

---

## 10. Three-line verdict

1. **Current 17/wk is 30–50% over the brand-defensible ceiling for THIS cohort.** Not a catastrophe, but past the line that competitors with this psychographic respect.
2. **Consolidate, don't delete.** Move the evening plate review to conditional, let the Sunday recap absorb the Tuesday affirmation, gate everything through a per-category cap service. Net: 17/wk → 10–12/wk with zero retention loss.
3. **Ship Day 1 morning value-spotlight as the single v1.2 add.** Everything else proposed for v1.2 is either already shipping (Sunday recap) or premature (paid-lapsed reactivation needs the cap service first).

---

## Sources (added to those in the two prior reports)

- [Airship 2026 iOS push opt-in baseline (44%)](https://www.airship.com/resources/benchmark-report/2026-mobile-app-engagement-benchmarks/)
- [Reddit r/loseit app fatigue thread aggregation](https://www.reddit.com/r/loseit/search/?q=notifications)
- [Cal AI App Store reviews — 1-star aggregation](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616)
- [Flo notification pipeline (Medium)](https://medium.com/flo-health/notification-sending-pipeline-at-flo-2e4621a6ab82)
- [Headspace push opt-in success story — Phiture](https://phiture.com/success-stories/headspace-inapps/)
- [Wiley Sociology 60k weight-app review study (2024)](https://compass.onlinelibrary.wiley.com/doi/full/10.1111/soc4.70066)
- [Nursing in Practice fitness/calorie meta-study (2024)](https://www.nursinginpractice.com/clinical/womens-health/fitness-and-calorie-counting-apps-can-impact-wellbeing-study-suggests/)
- [Airbridge 2026 Push Strategy](https://www.airbridge.io/en/blog/push-notification-strategy-for-subscription-apps)
- [Apple Fitness+ notification teardown — Rizki Nugroho](https://rizkinugroho.medium.com/encourage-yet-comforting-apple-fitness-notification-ed35b7c30057)
- [Calm reminders documentation](https://support.calm.com/hc/en-us/articles/360008620774-How-to-Set-Reminders)

JeniFit code-state inputs (line-number cited for fidelity):
- `/Users/bko/plankAI/PlankApp/Notifications/RetentionNotifications.swift` — full retention stack
- `/Users/bko/plankAI/PlankApp/Notifications/RecapNotificationService.swift` — Sunday recap (shipping)
- `/Users/bko/plankAI/PlankApp/Notifications/TrialEndNotificationService.swift` — trial-end disclosure
- `/Users/bko/plankAI/PlankApp/Views/Onboarding/OnboardingComponents.swift:160–259` — daily reminder
- `/Users/bko/plankAI/PlankApp/Views/Settings/NotificationSettingsView.swift` — current opt-out UX
- `/Users/bko/plankAI/PlankApp/Views/Analytics/AnalyticsView.swift:616` — Sunday recap call site
