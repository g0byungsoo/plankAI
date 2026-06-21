# JeniFit notification system: full audit, voice spec, cadence architecture, and production copy library

**Date:** 2026-06-16
**Author:** notification-strategy specialist agent (Noom / Calm / Headspace / BetterMe / Reverse Health pattern depth)
**Audience:** founder, JeniFit (iOS solo)
**Posture:** ruthless rewrite where evidence supports it; preserve what's working. The current system is 80% there. The remaining 20% is what makes the difference between "another wellness app's notifications" and the one she lets stay on.

---

## 1. Diagnostic audit

Scoring framework: 1-10 across voice-fit, conversion intent clarity, anti-cancellation framing, cohort fit. Conversion intent and anti-cancellation framing weight 2x for trial-window surfaces.

### 1.1 Daily reminder (`daily_reminder`)

**Current copy:**
- Title: `today's short session.`
- Body (encouraging): `five minutes is enough today. small moves still count.`
- Body (balanced): `sam picked a short one. easy to finish.`
- Body (default/firm): `kira's got a short one ready today.`

**Scores:** voice 8 / conversion 4 / anti-cancellation 5 / cohort fit 2

**The problem.** This is a workout-app reminder bolted onto a diet-first product. The product pivoted toward food/satiety + plank + breathwork + steps as parallel rails. The push still says "session" — workout-coded. Also: this is the ONLY push that fires daily (high inventory cost), and it has zero cohort awareness. A `postGlp1` woman re-engaging her body sees the same `kira's got a short one ready today` as a generalWL user.

**Specific weak phrases:**
- `"today's short session"` — "session" is workout-coded, fights the diet-first pivot.
- `"easy to finish"` — implies effort + completion pressure; lower-intent than identity.
- `"kira's got a short one ready"` — coach-name in body burns a sentence on chrome that doesn't move the user toward the app.

**Verdict:** Redesign. The daily reminder is the single highest-inventory push you have (7 fires/week). Every other notification works around its weight. Get this right and the system reorganizes itself.

### 1.2 Day 0 anchor (`day0_anchor`, T+4h)

**Scores:**
- generalWL: voice 8 / conversion 7 / anti-cancellation 6 / cohort 10 (default)
- onGlp1: voice 7 / conversion 8 / anti-cancellation 6 / cohort 9
- postGlp1: voice 9 / conversion 8 / anti-cancellation 6 / cohort 9
- considering: voice 6 / conversion 5 / anti-cancellation 5 / cohort 5

**The problem.** `considering` is the weakest of the four. `"the daily work, day one"` sounds like a Calvinist obligation, not a permission to start. `onGlp1`'s `"protein floor + a breath card"` is overspecified for a Day 0 push. The user installed 4 hours ago — she doesn't yet have a mental model of what protein floor + breath card means in the app. This is brochure copy, not a return invitation.

### 1.3 Day 2 engagement (`day2_engagement`)

**Scores:**
- generalWL: voice 7 / conversion 6 / anti-cancellation 5 / cohort 8
- onGlp1: voice 7 / conversion 5 / anti-cancellation 4 / cohort 7
- postGlp1: voice 8 / conversion 6 / anti-cancellation 5 / cohort 9
- considering: voice 5 / conversion 4 / anti-cancellation 4 / cohort 5

**The problem.** `"haven't tried jeni yet?"` (generalWL) is accusatory. Calls attention to her failure to engage. The product knows she hasn't engaged; she knows. Acknowledging it on the lock screen invites her to swipe-cancel-trial in the same gesture. Anti-cancellation poison.

### 1.4 Trial-end T-24h, shownUp >= 3

**Scores:**
- generalWL: voice 8 / conversion 9 / anti-cancellation 8 / cohort 10
- onGlp1: voice 7 / conversion 8 / anti-cancellation 7 / cohort 9
- postGlp1: voice 9 / conversion 9 / anti-cancellation 8 / cohort 10
- considering: voice 7 / conversion 7 / anti-cancellation 7 / cohort 8

**The strongest set in the system.** `"look how far you've come"` + shown-up count + cancel-anytime disclosure is textbook anti-cancellation framing.

**Concerns:** `"shown up 1 times"` grammatically broken when `n == 1`. `"beside the shot"` reads awkward — try `"with the daily work."`

### 1.5 Trial-end T-24h, shownUp < 3 (the danger zone)

**Scores:**
- generalWL: voice 6 / conversion 4 / anti-cancellation 2 / cohort 10
- onGlp1: voice 5 / conversion 6 / anti-cancellation 4 / cohort 8
- postGlp1: voice 6 / conversion 6 / anti-cancellation 5 / cohort 9
- considering: voice 6 / conversion 5 / anti-cancellation 5 / cohort 8

**This is the system's biggest problem.** A user with shownUp < 3 is mathematically MORE likely to refund-then-chargeback. The generalWL copy `"your free trial ends tomorrow. your trial becomes a membership tomorrow."` is doubly bad:
1. Says "ends" then "becomes" — confusing.
2. Zero value pitch. Just billing.
3. Maximizes refund probability — charged for unused product.

Cohort variants carry a value pitch but say `"yours after tomorrow"` — implies content unlocks tomorrow, when it's actually behind the same paywall she's already on.

**Most dangerous phrase:** `"your free trial ends tomorrow."` (generalWL title). Reads as ACTION REQUIRED.

### 1.6 Evening Plate Review (`evening_plate_review`)

**Current:** title `today's plate ♥` / body `a soft look back. tap in when you're ready.`

**Scores:** voice 9 / conversion 5 / anti-cancellation 6 / cohort 1

Beautiful voice. Zero cohort routing. Zero state awareness. For a user who logged zero meals today, the push reads as a guilt trigger ("look back at what you didn't log"). **Add state gating — never fire on a day she logged zero meals.**

### 1.7 Affirmations (`affirmation_drop_*`, Tue + Sat)

**Scores:** voice 10 / conversion 3 / anti-cancellation 8 / cohort 4

Strongest voice work in the system. Keep nearly verbatim.

**Specific issues:** `"be the kind of friend to yourself you'd be to someone you love"` — 16 words. Lock-screen-truncates ugly.

### 1.8 Milestones (`milestone_*`)

**Critical issue:** Day 30 contains an **em-dash**: `"thirty days. this isn't a phase anymore — it's you."` Voice spec violation. Must fix.

Also: no name on Day 7, 30, 50 (`tail` is empty on those). Inconsistent.

### 1.9 Win-back (`winback_lapse`)

**Scores:** voice 9 / conversion 5 / anti-cancellation 8 / cohort 1

Solid. Only nit: `"five minutes is enough to feel like you again"` — "again" implies she lost herself. Subtle undertow contradiction.

### 1.10 Sunday recap (`becoming.sunday.recap`)

**Scores:** voice 9 / conversion 6 / anti-cancellation 9 / cohort 1

Good. `"your week, kept"` is the strongest title in the system.

---

## 2. Voice & style spec (codified — any future copy must pass)

**Required:**
1. Lowercase throughout (proper nouns + sentence-start excepted).
2. Heart ♥ as terminal punctuation only. Max one per body. Never two.
3. Period termination preferred. Question mark allowed only when rhetorical (rare).
4. Title: 4-7 words MAX. iOS truncates at ~30 chars on the lock screen.
5. Body: 50-120 chars sweet spot. Hard cap 178 chars.
6. Personalization slot `{name}, ` opens the body when set; otherwise blank.
7. Cohort variants change the NOUN, never the VERB or the VOICE.
8. Identity-led: "the woman who shows up" — avoid 2nd-person imperatives.
9. Numbers must trace to collected data. Allowed: shown-up count, week count, day-of-program count, distinct lessons completed.

**Banned:**
- em-dash between words
- double-hyphen between words
- `*italic*` markers
- ALL CAPS words
- exclamation points (one allowed per WEEK across entire library; current: zero, keep it)
- emojis other than ♥
- labor verbs: crush, shred, burn, earn, grind, smash, dominate, push, work (use "show up," "begin," "tap in," "come back")
- scale words: pounds, lbs, kg, weight, scale, weigh, before, after
- streak-loss threats: "don't break," "you're falling behind," "X days lost"
- AI-coded language
- urgency manufacturing: "last chance," "ends tonight," "expires," "act now"
- accusation questions: "haven't tried X yet?" "missing in action?"
- drug brand names + equivalence claims
- first-party weight-loss numeric claims

**Tonal moves to use deliberately:**
- "permission" frame for food: "permission to begin," "fits today"
- "soft" + "quiet" + "steady" cluster for action verbs
- 3-day frame for short windows, 3-month for medium
- "the one who" / "the woman who" identity pull
- "today" + "tomorrow" + "morning" for time anchors

---

## 3. Cadence architecture recommendation

### 3.1 Trim the surface count from 9 to 7

**Drop:** Day 0 anchor (T+4h). Half her cohort hasn't granted permission by T+4h — silent fail. Of those who did, you're competing with onboarding euphoria. Needy.

**Replace with:** Day 1 morning push (T+18-26h), bucket-anchored. Higher signal: she went a sleep cycle without opening.

**Drop:** Day 2 engagement (current design). The 55% Day 0 cancels are gone. 23% workout completion means most non-quitters haven't done a session on Day 2 either — push goes to everyone. Spray, not engagement.

**Replace with:** Day 2 value-spotlight, fires only when shownUp == 0 by Day 2 evening bucket hour. State-gated.

**Add:** Post-paywall Day 5 anti-refund push. 90-day refund window peaks at Days 5-14. Currently NOTHING in this window.

**Add:** Pre-trial-end T-30h "soft tap" for shownUp < 2 — gentler, earlier nudge that's NOT the billing reminder, just "the door is still open." Splits the conversion ask into two beats.

**Add:** Trial-end T-2h disclosure push (pure FTC anti-dark-pattern hygiene).

**Keep:** Daily reminder (redesigned), Trial-end T-24h (rewritten), Evening Plate Review (state-gated), Affirmations Tue+Sat, Milestones, Win-back, Sunday recap.

### 3.2 Week-1 push budget: 4-6 max (current: 10 = 2x Airbridge ceiling)

**Fix:** During trial week, daily reminder fires Mon/Wed/Fri only. After Day 7, switches to daily. 3-line code change.

**Week 1 budget after fix:**
- Daily reminder: 3 (Mon/Wed/Fri)
- Day 1 morning push: 1
- Day 2 value-spotlight: 0 or 1 (gated)
- Pre-trial T-30h soft tap: 0 or 1 (gated)
- Trial-end T-24h: 1
- Trial-end T-2h disclosure: 1
- **Total: 5-7 max**

### 3.3 Lower the shownUp recap threshold from 3 to 2

A user who showed up 2/3 trial days is HIGHLY engaged. Currently she gets cold billing copy. Drop threshold to 2. Add dedicated `shownUp == 1` middle-branch copy.

### 3.4 Trial-end push: add T-2h disclosure (NOT a sales push)

For ambivalent users, the second touch creates a real decision moment. Must read as pure disclosure. Tone: "your trial converts at 2pm. cancel anytime in iOS settings." FTC anti-dark-pattern hygiene.

---

## 4. Full copy library (production-ready)

### 4.1 Daily reminder (replaces `today's short session`)

**Trial week (Mon/Wed/Fri):**

| voicePref | title | body |
|---|---|---|
| encouraging | `five minutes, today.` | `{opener}small moves still count. they always have ♥` |
| balanced | `five minutes, today.` | `{opener}sam picked a short one. open when you can.` |
| firm | `five minutes, today.` | `{opener}kira's got a short one ready.` |

**Post-week-1 (daily), rotates 4 lines per voicePref:**

```
encouraging body rotation:
0: "{opener}five minutes is enough today. small moves still count."
1: "{opener}come back to the rhythm. today's a soft one ♥"
2: "{opener}the version of you that shows up is already winning."
3: "{opener}five minutes. that's the whole ask today."

balanced body rotation:
0: "{opener}sam picked a short one. easy to begin."
1: "{opener}a five-minute breath card is waiting today."
2: "{opener}today's short. open when you have a moment."
3: "{opener}sam's got a quiet one ready."

firm body rotation:
0: "{opener}kira's got a short one ready today."
1: "{opener}today's a tap-in day. five minutes."
2: "{opener}kira chose short. show up when you can."
3: "{opener}five minutes. then you're done for today."
```

Titles rotate every other day:
```
0: "five minutes, today."
1: "today's gentle one."
2: "tap in when you can."
```

Hash day-of-year against rotation length — deterministic, no state needed.

### 4.2 Day 1 morning push (NEW; replaces Day 0 anchor)

Fires T+18-26h, bucket-anchored. Cancelled on any saved session.

| cohort | title | body |
|---|---|---|
| generalWL | `your first morning here.` | `{opener}five minutes today. that's how the rhythm begins ♥` |
| onGlp1 | `the work alongside the shot.` | `{opener}today's the day you start the daily piece ♥` |
| postGlp1 | `the rhythm that keeps it.` | `{opener}five minutes today. that's how the keep-it-off habit starts ♥` |
| considering | `the daily piece, day one.` | `{opener}five minutes today. begin where you are ♥` |

### 4.3 Day 2 value-spotlight (gated: shownUp == 0)

Fires Day 2 evening bucket hour, ONLY if zero sessions logged.

| cohort | title | body |
|---|---|---|
| generalWL | `the door's still open.` | `{opener}a five-minute breath card is the softest way in.` |
| onGlp1 | `the lessons are waiting.` | `{opener}the protein floor + food noise piece. five minutes ♥` |
| postGlp1 | `the keep-it-off lessons.` | `{opener}the rhythm that holds. five minutes when you can ♥` |
| considering | `your five minutes.` | `{opener}breath card, plate check. the daily piece begins when you do ♥` |

### 4.4 Pre-trial-end soft tap (NEW; T-30h, gated: shownUp < 2)

| cohort | title | body |
|---|---|---|
| generalWL | `still here for you.` | `{opener}a five-minute breath card is enough to feel like you ♥` |
| onGlp1 | `the daily piece is yours.` | `{opener}five minutes today. the layer underneath the shot ♥` |
| postGlp1 | `the rhythm is yours.` | `{opener}five minutes today. the keep-it-off piece begins when you do ♥` |
| considering | `the daily piece, ready.` | `{opener}five minutes is enough to feel the shape of it ♥` |

### 4.5 Trial-end T-24h, shownUp >= 2 (CELEBRATION branch)

| cohort | title | body |
|---|---|---|
| generalWL | `look how far you've come.` | `you've shown up {n} times ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.` |
| onGlp1 | `look how far you've come.` | `you've shown up {n} times for the daily piece ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.` |
| postGlp1 | `look how far you've come.` | `you've shown up {n} times for the keep-it-off rhythm ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.` |
| considering | `look how far you've come.` | `you've shown up {n} times for the daily piece ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings.` |

Notes:
- Singular handling: when `n == 1`, render `"you've shown up once"` not `"shown up 1 times"`.
- "manage anytime" — shorter than "manage or cancel anytime," same legal cover.
- Universal title + cohort body keeps the celebration register clean.

### 4.6 Trial-end T-24h, shownUp == 1 (NEW middle branch)

| cohort | title | body |
|---|---|---|
| generalWL | `your trial wraps tomorrow.` | `you showed up once ♥ the door stays open. manage anytime in iOS settings.` |
| onGlp1 | `your trial wraps tomorrow.` | `you started the daily piece. it's yours tomorrow ♥ manage anytime in iOS settings.` |
| postGlp1 | `your trial wraps tomorrow.` | `you started the rhythm. it's yours tomorrow ♥ manage anytime in iOS settings.` |
| considering | `your trial wraps tomorrow.` | `you started the daily piece. it's yours tomorrow ♥ manage anytime in iOS settings.` |

### 4.7 Trial-end T-24h, shownUp == 0 (the cold zone — rewrite)

| cohort | title | body |
|---|---|---|
| generalWL | `the rhythm is here when you are.` | `your trial converts tomorrow. five minutes is enough to begin. manage anytime in iOS settings.` |
| onGlp1 | `the daily piece, alongside the shot.` | `the protein floor, the food noise quieting, the breath cards. yours tomorrow. manage anytime in iOS settings.` |
| postGlp1 | `the keep-it-off rhythm, ready.` | `the post-shot rhythm, the protein floor, the daily piece. yours tomorrow. manage anytime in iOS settings.` |
| considering | `the daily piece, ready.` | `the breath cards, the protein floor, the food noise piece. yours tomorrow. manage anytime in iOS settings.` |

Dropped "your free trial ends tomorrow" entirely. "Converts" + "yours" reads softer + still discloses.

### 4.8 Trial-end T-2h (NEW; pure disclosure)

Title: `quick note ♥`
Body: `your trial converts at {hh:mm}. manage anytime in iOS settings.`

Same copy all cohorts. NEVER value-pitch this push — that's where dark-pattern lawsuits start. Disclosure-only.

### 4.9 Day 5 anti-refund push (NEW; post-charge for annual + quarterly converters)

Fires 5 days after trial→paid charge. Skip weekly.

| cohort | title | body |
|---|---|---|
| generalWL | `five days in ♥` | `you've shown up {n} times since you joined. small moves still count.` |
| onGlp1 | `five days in ♥` | `the daily piece is taking shape. {n} times shown up so far ♥` |
| postGlp1 | `five days in ♥` | `the rhythm is forming. {n} times shown up so far ♥` |
| considering | `five days in ♥` | `you're {n} days into the daily piece ♥` |

Gate: skip if shownUp == 0 since the push fires. (Silence > guilt trip → refund.)

### 4.10 Evening Plate Review (refined gating + copy)

Title stays: `today's plate ♥`
Body rotation:
```
0: "a soft look back. tap in when you're ready."
1: "the day fits when you flip through it ♥"
2: "today's plate is here when you are."
```

**Critical new gating:**
- Skip if user logged zero meals today.
- Skip if user opened "today's plate" view within last 3h.
- Skip during trial week 1 entirely.

### 4.11 Affirmations (refined library)

```
becoming-line (from identityFeeling):
- "powerful" / "strong" → "you're becoming someone strong."
- "calm"              → "you're becoming someone steady ♥"
- "light"             → "you're becoming someone light on her feet."
- "radiant"           → "you're becoming someone who glows ♥"
- default             → "you're becoming someone who shows up."

rest of library:
1: "small moves still count. they always have ♥"
2: "you don't have to feel ready. you just have to begin."
3: "the version of you that shows up is already winning."
4: "progress is quiet. you're making it anyway."
5: "be gentle with yourself today ♥"
6: "{name}, today's a good day to be soft on yourself."
7: "the woman who came back is already the woman you wanted."
8: "five minutes still counts. it always did ♥"
```

Removed: `"be the kind of friend to yourself..."` (16 words, lock-screen-truncates).

### 4.12 Milestones (fixes em-dash + name consistency)

```
3:   "three days in{tail}. you're building something ♥"
7:   "you've shown up seven times{tail}. that's who you are now."
14:  "two weeks of showing up{tail}. look at you ♥"
30:  "thirty days{tail}. this isn't a phase anymore. it's you."
50:  "fifty times{tail}. quietly, you became someone consistent."
100: "one hundred{tail}. you're not the same person as day one ♥"
```

Fixes: Day 30 em-dash → period. Day 7/30/50 add `{tail}` for consistency. Day 14 adds heart.

### 4.13 Win-back (refined rotation)

```
0: "{opener}one slip doesn't undo you. a short one's still here when you are ♥"
1: "{opener}no catching up needed. just come back when you can."
2: "{opener}five minutes is enough to feel like you ♥"
3: "{opener}the door's still open. tap in when you're ready ♥"
```

Removed `"again"` from line 2 (subtle undertow contradiction). Added line 3 to expand rotation pool.

### 4.14 Sunday recap (small refinement)

Title: `your week, kept.`
Body: `the recap is ready. {n} days. quiet ones still count ♥`

---

## 5. Anti-cancellation + anti-refund specific moves

### 5.1 The 3-day trial window — exact cadence

**Day 0:** onboarding completes → permission prompt fires. DO NOT fire any push at T+4h. Daily reminder schedules for tomorrow's bucket hour (Mon/Wed/Fri trial cadence).

**Day 1:** morning bucket hour: Day 1 morning push IF shownUp == 0. Bucket hour: Daily reminder if Mon/Wed/Fri.

**Day 2:** evening bucket hour: Day 2 value-spotlight IF shownUp == 0. No additional pushes unless milestone fires.

**Day 3:** NO daily reminder today. T-30h pre-trial soft tap IF shownUp < 2. T-24h trial-end push (branch by shownUp count). T-2h disclosure push.

**What NOT to send during trial:** affirmations (already gated), milestones unless threshold crossed, Evening Plate Review (skip week 1), Sunday recap (if week ends in trial), win-back (3-day lapse impossible in 3-day trial).

### 5.2 The 5-14 day refund window

**Day 5 anti-refund push:** the single most leveraged push. Refund requests spike Days 5-14 (post-charge regret + first credit card statement). Warm "you're 5 days in, here's what you did" reframes spend as earned.

**Days 6-14:** standard cadence resumes — daily reminder daily, affirmations Tue/Sat, Evening Plate Review (with gating), win-back after 3-day lapse.

**Days 15-30:** standard. Milestones at Day 14 + Day 30.

### 5.3 When silence is the right answer (code these as guards)

1. Trial Day 0 evening AND user just completed onboarding within last 6h → silence.
2. User saved session within last 4h → silence on Evening Plate Review.
3. User logged zero meals today AND it's evening → silence on Evening Plate Review.
4. User has shownUp == 0 on Day 5+ post-charge → silence on Day 5 anti-refund push.
5. User has paywall_dismissed timestamp within last 2h → silence ALL pushes for next 2h.
6. `UIApplication.shared.applicationState == .active` when scheduled time fires → skip silently.
7. User toggled `notif.disable_all` → drop the whole channel.

### 5.4 Cohort-routing reactivity

When `onboarding_glp1_status` UserDefaults value changes, call `RetentionNotifications.reschedule()` immediately. Same for `voicePreference`, `userName`, `identityFeeling`, `plankTime` (the bucket key).

### 5.5 The "manage anytime" disclosure

Don't shorten to "cancel anytime." Apple specifically discourages making "cancel" the headline action — can trigger 3.1.2 review concerns about "promoting cancellation." "Manage" is the safe word.

---

## 6. Implementation diff sketch (surgical for solo dev)

```
File: PlankApp/Notifications/RetentionNotifications.swift

SURGICAL CHANGES:
1. Drop scheduleDay0AnchorIfNeeded(); add scheduleDay1MorningIfNeeded()
   fires T+18-26h (next bucket hour after a sleep cycle)
2. Rewrite scheduleDay2EngagementIfNeeded() to be state-gated:
   skip if shownUp > 0 by the time it would fire
3. Add scheduleTrialPreEndSoftTapIfNeeded()
   fires T-30h before trial end, gated shownUp < 2
4. Add scheduleDay5AntiRefundIfNeeded()
   called from PaymentService when trial→paid charge succeeds
5. Refactor milestoneBody() — fix em-dash on Day 30, add tail on 7/30/50
6. Refactor winbackBody() — drop "again" undertow
7. Refactor affirmationLibrary() — tighten + add 3 lines
8. Add isInTrialWeek1() check to evening plate review schedule path
9. Add hasLoggedAnyMealToday() check to evening plate review fire path

File: Glp1Cohort (inside RetentionNotifications.swift)

Update existing content helpers + add:
  day1MorningContent(opener:)
  day2ValueSpotlightContent(opener:)
  preTrialEndSoftTapContent(opener:)
  trialEndContent(shownUp:) — update threshold to 2 + add shownUp == 1 branch
  day5AntiRefundContent(opener:, shownUp:)
  trialEndDisclosureContent() — universal, no cohort

File: PlankApp/Notifications/TrialEndNotificationService.swift

1. scheduleIfNeeded(trialEndDate:) — additionally schedules:
   - T-30h soft tap (gated on shownUp < 2)
   - T-2h disclosure push (always)
2. cancelTrialEndReminder() — sweep all 3 trial-end identifiers

File: PlankApp/Notifications/PostChargeNotificationService.swift (NEW)

Mirrors TrialEndNotificationService pattern.
scheduleDay5AntiRefundIfNeeded(chargeDate:) — schedules T+5d push.
Called from PaymentService.customerInfoStream on trial→paid transition.

File: PlankApp/Views/Onboarding/OnboardingComponents.swift

In NotificationPermission.scheduleDailyReminder(at:):
1. Check RetentionNotifications.isWithinFirstWeek().
   If true: schedule with daysOfWeek = [Mon, Wed, Fri].
   If false: existing daily repeats schedule.
2. dailyReminderBody() picks from rotation pool keyed by day-of-year hash.
3. Add titleRotation() returning 1 of 3 titles.

File: PlankApp/Payment/PaymentService.swift

On customerInfoStream branch that detects trial→paid:
  await PostChargeNotificationService.shared.scheduleDay5AntiRefundIfNeeded(
    chargeDate: customerInfo.latestActiveTransactionDate
  )
```

Estimated total: ~250 LOC across 6 files. Single PR. 2-3 hour solo session including QA on simulator.

---

## 7. Open questions for founder

1. **Drop Day 0 anchor entirely?** Recommended yes. Easy to add back as A/B if numbers show a hole.

2. **shownUp recap threshold: 2 or 3?** Recommended 2.

3. **Daily reminder default: on or off post-onboarding?** Recommended default ON, scheduled at bucket-hour. Mon/Wed/Fri week-1 cadence keeps it from overwhelming.

4. **Cohort-update reactivity:** is there a settings UI for changing GLP-1 status post-onboarding? If yes — wire the rescheduling observer.

5. **Day 5 anti-refund push gate:** fire ONLY for annual + quarterly converters; skip weekly. Confirm.

6. **Trial-end T-2h disclosure: does iOS itself send an Apple subscription notification at similar time?** Worth checking sandbox.

7. **Cancel-anytime language: "manage" or "manage or cancel"?** Recommended "manage anytime" — softer, same legal cover.

8. **Sunday recap: keep on Sunday 5pm fixed or move to bucket-hour Sunday?** Recommended bucket-anchor it via PushIntent.weeklySummary (already exists in NotificationTimeBucket). ~3 lines.

9. **First-log nudge (`food_first_log_nudge`):** the scheduler + canceller remain but are CUT. Recommended: leave dormant.

10. **Affirmation cadence: stays Tue + Sat?** Recommended yes. Mondays goal-loaded, Fridays compete with social plans, Sundays carry recap. Tue + Sat is calmest pair.

---

## Closing diagnosis

The system today is competent: voice mostly right, architecture clean, toggles correct. Two real wounds:
(a) Day 0 / Day 2 anchor pair fires into onboarding noise rather than catching attention drift.
(b) Trial-end shownUp < 3 branch is the system's softest belly — exactly where the dollars decide.

Fix those two zones and conversion + anti-refund both move. The strongest copy — Sunday recap title, trial-end celebration, win-back rotation, affirmation library — should model everything else.

Ship the rewrites in §4 as one PR, ship the cadence reorganization in §3 as a second PR, gate the Day 5 anti-refund + T-2h disclosure behind a Remote Config flag so you can compare before/after refund rates in PostHog within 30 days.

---

## Sources

- [RevenueCat 2026 State of Subscription Apps](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/) — 55% Day 0 cancel rate, 10.7% Day 35 hard paywall median, 35% Month 1 churn
- [Adapty 2026 Health & Fitness Benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) — Day 0 + Day 4-14 conversion bimodal pattern
- [Adapty Refund Rate Research](https://adapty.io/blog/how-to-cut-your-apps-subscription-refund-rate/) — 40-60% refund rate reduction via automated management + onboarding optimization
- [Airbridge Push Notification Strategy for Subscription Apps](https://www.airbridge.io/en/blog/push-notification-strategy-for-subscription-apps) — 5/week ceiling, 40% disable rate above ceiling
- [PushPilot Best Time to Send Push Notifications 2026](https://pushpilot.ai/blog/best-time-to-send-push-notifications-2026) — wellness app morning preference, 12-1pm underrated window, 50% open-rate lift via peak-window timing
- [FTC Dark Patterns 2026 Guidance](https://cookie-script.com/privacy-laws/dark-patterns-2026-the-ftc-new-click-to-cancel-rule) — pre-conversion reminder with charge amount + direct cancel link
- [Auto-Renewal Subscription Compliance 2026](https://toslawyer.com/auto-renewal-and-subscription-compliance-what-saas-and-e-commerce-companies-must-fix-in-2026/) — forced continuity enforcement
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 3.1.2(c) subscription disclosure
