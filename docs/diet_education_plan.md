# The JeniFit Method — Post-Purchase Diet Education Plan

**Status:** Phases 1–7 complete + merged behind default-off flag. Phase 8 is ready to ship — copy-review-gated; see TODOS.md "JeniFit Method — Phase 8 unblock playbook" for the one-line flag-flip diff + TestFlight checklist.
**Audience:** Young women new to strength training, often coming from a history
of restrictive diets. **Elevated ED risk** drives every content rule below.
**Date:** 2026-05-24

## Locked decisions (from review — applied throughout)

1. **Goal-gate.** Only fat-loss-oriented goals enroll: allowlist
   `{loseWeight, slimLegs, toneCore, fullBody}`; `growGlutes` excluded (no
   flow in v1). Gate lives in `JeniMethodState.shouldEnroll(for:)` as a
   single editable constant.
2. **Lesson 5 action is off the scale.** `.acknowledge` a non-scale win
   ("notice one thing that felt easier this week"). No Becoming-tab deep
   link, no weight presence-detection.
3. **No portion-sizing anywhere.** Lesson 4 is purely qualitative ("put a
   protein on the plate first"). The invariant test bans portion analogies
   (`palm`, `fist`, `cupped hand`, `size of your`, `serving size`,
   `portion the size`).
4. **Forward-only enrollment**, idempotent via
   `jenimethod.lesson_1_started_at`. Restore == purchase. No backfill.
5. **Open-question defaults locked:** separate beat after celebration; card
   does not auto-open on Day 2; skipping the workout still completes the
   lesson; no new notifications; no re-read telemetry.
6. **Mandatory second-eyes copy review on Lessons 4 AND 5** before the
   flag is turned on. Hard gate in TODOS.md, not optional.

This document is the v1 implementation plan for a 5-lesson post-purchase
education layer that reframes JeniFit from "a workout app" to "a coached
fat-loss program." Each lesson is 3-5 screens following the Daily Reset
structure: Learn → tiny Action → Complete → Preview-tomorrow. State lives
in UserDefaults; content is a typed Swift literal; the trigger piggybacks
on the existing post-paywall flow. **Hard safety guardrails are codified
in §5 and operationalized in §8 and §9** — they are not negotiable.

---

## 1. Goal and non-goals

### Goal
- Reposition JeniFit as a coached fat-loss program by teaching the science
  of healthy fat loss in 5 short, daily lessons that begin immediately after
  a user starts a trial or subscription.
- Tie each lesson's "tiny action" to the workouts the user already gets from
  the existing engine, so the education layer reinforces, never replaces,
  the core product.

### Non-goals (v1)
- No new SwiftData fields, no Supabase columns, no migrations.
- No RevenueCat offering / product / entitlement / paywall changes.
- No specific calorie targets, gram-per-kg protein math, body-fat percent
  numbers, or any other quantitative nutrition prescription shown to the
  user.
- No body-shape avatars, no before/after framing, no timeline promises.
- Not a meal-planning feature. Not a food log. Not a calorie tracker.
- No backend dependency for content. All copy ships in the app binary.

---

## 2. Trigger, cadence, and re-entry

### 2.1 First lesson — post-paywall
Lesson 1 fires immediately **after** the existing `PremiumWelcomeScreen`
celebration completes. Concretely:

- `PlankAIApp.swift:342` already observes `.onChange(of: payment.effectiveHasProAccess)`.
- `PlankAIApp.swift:357` already presents `PremiumWelcomeScreen` via
  `.fullScreenCover(isPresented: $justSubscribed)` and clears
  `justSubscribed` in its `onComplete` closure (line 366).
- Wire a new `@State showingJeniMethod` that flips to `true` inside the
  `PremiumWelcomeScreen` `onComplete` closure (i.e. as celebration dismisses).
- Add a third `.fullScreenCover(isPresented: $showingJeniMethod)` presenting
  `JeniMethodLessonView(lesson: .day1, source: .postPurchase)`.

This gives the deterministic ordering called for in the brief:
**paywall → celebration → education flow → MainTabView.**

### 2.2 Lessons 2-5 — daily cadence via HomeView card
Forcing 5 consecutive fullScreenCovers would be hostile. Instead:

- Lesson 1 finishes → user lands on MainTabView (Home).
- On Days 2-5, when the user opens the app, `HomeView` shows a
  `JeniMethodTodayCard` at the top of the scroll if the next lesson is
  available and not yet completed.
- Tapping the card opens the same `JeniMethodLessonView` as a sheet (NOT a
  fullScreenCover — sheet is dismissable, signals optionality).
- The card disappears once today's lesson is completed.
- "Day" boundary follows the existing `dailyRefreshDate` pattern in
  `HomeView.swift:25-26` — timezone-aware, midnight local.

### 2.3 Day index logic
Two pieces of state in UserDefaults:
- `jenimethod.enrolled_at` (ISO date string) — set when Lesson 1 starts.
- `jenimethod.last_lesson_completed_id` (Int) — last lesson completed, 0..5.

Available lesson index =
`min(5, days_since(enrolled_at) + 1)` capped by `last_completed_id + 1`.

This means:
- If the user does Lesson 1 on Day 0, Lesson 2 becomes available on Day 1.
- If the user skips a day, the next lesson is still the next sequential one
  (not "today's day-of-week" lesson). No "you missed Day 3" shame.
- If the user is offline for a week, they come back and the next lesson is
  ready immediately — no catch-up debt.

### 2.4 Re-entry on cold launch
- The post-purchase fullScreenCover only fires once per
  `payment.effectiveHasProAccess` false→true transition. To avoid re-firing
  on every cold launch:
  - Set `jenimethod.lesson_1_started_at` when Lesson 1 first opens.
  - The `showingJeniMethod` flag only flips true if this key is unset AND
    the user just paid.
- All subsequent re-entry happens via the HomeView card (sheet, dismissable).

### 2.5 Skip handling
- Each lesson has a small "skip for today" affordance in the top-right (the
  same X button pattern as PaywallView, with `accessibilityLabel("Close")`).
- Tapping it fires `diet_education_skipped` with the screen index reached,
  closes the lesson, and the HomeView card returns the next day.
- Skipping does NOT advance `last_lesson_completed_id`. The user comes back
  to the same lesson tomorrow.
- A lesson reaches "completed" only by tapping Continue on the Preview-
  tomorrow screen. This is the analytics-clean "done" signal.

### 2.6 Final-state — what after Lesson 5
- "Preview-tomorrow" screen on Lesson 5 becomes "Preview your week."
- HomeView card disappears.
- A new entry in Settings ("The JeniFit Method") lets the user re-read any
  lesson on demand (read-only, no completion tracking on re-reads).
- One analytic: `diet_education_completed` with lessons completed / skipped.

---

## 3. Lesson content outlines (universal copy direction)

For each lesson the copy below is **direction, not final copy.** Final
writing happens in `JeniMethodContent.swift` and goes through a separate
copy-review pass before TestFlight. The "Avoid" lines are the safety
guardrails translated into per-lesson rules.

Every Learn screen renders the **standing safety line** at the bottom in
small `textTertiary`:

> JeniFit is a fitness app, not medical advice. If you're pregnant, have a
> medical condition, or a history of disordered eating, talk to a healthcare
> professional before changing how you eat.

### Lesson 1 — "Why this works (and why crash diets don't)"

**Topic:** A gentle, sustained deficit beats a steep one. Starvation isn't
a strategy; it's a setback.

**Learn screen (1-2 short paragraphs):**
- Direction: Most "diets" fail not because the user lacked willpower, but
  because they ate so little their body started fighting them — slower
  metabolism, ravenous hunger, lost muscle, fast rebound. The science
  agrees with what you've already felt.
- Frame the program as "gentle enough to keep, strong enough to work."
- One concrete "this is what we mean" example, qualitative: "If you used
  to skip lunch and binge at night — we're going the other way."
- **Avoid:** any number of calories, "X% deficit," "lose Y pounds per week,"
  comparison to other diets by name, fear-based imagery, scale numbers.

**Tiny action:** "Today's win — just show up for your workout."
- The button launches the user's existing planned workout via
  `WorkoutGenerator` with no modifications. (Daily Reset and the regular
  Home flow both already do this.)
- Skippable: if the user already trained today, the action becomes a one-
  tap "I trained earlier today — count it" that records completion.

**Complete screen:** AffirmationScreen choreography with the user's `name`
and a short identity beat: "you started." Tap to continue.

**Preview-tomorrow:** "Tomorrow: the muscle conversation. Why eating-only
is the trap, and how training changes the math." One line, one tap to
dismiss.

### Lesson 2 — "Don't lose the good stuff"

**Topic:** Diet-only weight loss strips muscle; muscle is what keeps you
strong, energetic, and able to eat without rebounding. ~24% of weight lost
to diet-only is muscle; with training it's closer to ~11%. **Show this
qualitatively — never with the numbers.**

**Learn:**
- Direction: When the body needs to lose weight without a reason to keep
  muscle, it cuts both. "Lighter on the scale" can mean "smaller and weaker."
  We don't want smaller and weaker — we want lighter *and* stronger.
- Land the punch: "this is why diets stop working after a few weeks — there
  was less of *you* keeping the metabolism running."
- **Avoid:** percentages, gram targets, "you'll lose X lbs of muscle,"
  before/after silhouettes, anything that frames the body as a project to
  shrink.

**Tiny action:** A 3-5 minute strength micro-flow (selected by experience
level — see §4). Same `WorkoutGenerator` engine, short cap.

**Complete:** "you protected something today." Identity word from
`onboardingIdentityFeeling` if set.

**Preview-tomorrow:** "Tomorrow: how your workouts do the protecting."

### Lesson 3 — "Your workouts are the protection"

**Topic:** Strength work tells the body "keep the muscle," so the weight
that goes is fat. This is why JeniFit's plan looks the way it does.

**Learn:**
- Direction: Cardio burns the moment; strength changes what your body
  *defends.* You don't have to live in the gym — the right consistency at
  the right intensity does it. "Beginners get a head start: your body
  responds faster than someone who's been training for a decade." (This
  is true and on-message; recomposition is most pronounced for novices.)
- Tie to the user's plan: "the program you already have is built around
  this. The workouts are doing this whether you think about it or not."
- **Avoid:** "build muscle in N weeks," before/after photos, prescriptive
  set/rep schemes outside the existing generator, claims about specific
  body parts shrinking ("toned arms in 21 days" — never).

**Tiny action:** Either the next scheduled workout in the plan OR a 4-
minute "find your strength" mini-flow targeting `onboardingBodyFocus.first`.

**Complete:** "this is the work."

**Preview-tomorrow:** "Tomorrow: food. Specifically, eating *enough.*"

### Lesson 4 — "Eat to fuel, not to punish"

**Topic:** Adequate eating + a protein-forward plate keeps muscle in a
deficit; under-eating undoes the work of the workout. **Qualitative only.**

**Learn:**
- Direction: The cheat code is eating *enough,* not less. A plate that
  starts with protein, then adds plants and starches, holds you longer and
  helps the body keep the muscle the training is asking it to keep. No
  measuring, no apps, no perfection.
- Three soft heuristics, all qualitative:
  - "Plan the protein first" — chicken, fish, eggs, tofu, beans, Greek
    yogurt, cottage cheese.
  - "Don't train hungry, don't train stuffed." Fuel before, refuel after.
  - "If you're tired all the time, you're eating too little, not too much."
- This is the most ED-sensitive lesson. The framing is **abundance**, not
  restriction. The word "diet" appears only to reject it.
- **Avoid:** any number (grams, calories, ounces). **No portion analogies
  at all** — no "size of your palm," "size of a fist," "cupped hand," or
  any other measurement metaphor (locked decision #3). Any "good food /
  bad food" language. Any fasting, "clean eating," elimination, or
  "earn your meals" framing. Any mention of weight in this lesson's
  copy at all.

**Tiny action:** "Today: pick one meal and put a protein on the plate
first." That's it. No tracking, no photo, no checklist beyond a single
"done" button.

**Complete:** "you fed the work."

**Preview-tomorrow:** "Tomorrow: the scale. Why it lies — and what to look
at instead."

### Lesson 5 — "Trust the trend"

**Topic:** Body weight is noisy day-to-day (water, sodium, hormones, sleep,
glycogen). Direction matters; single readings don't. Recomposition can
leave the scale flat while clothes get looser.

**Learn:**
- Direction: A single weigh-in is one data point in a cloud. A two-week
  trend is the truth. The scale will go up some mornings. That doesn't
  mean the work isn't working — it means you're a human with a body.
- Tie to existing JeniFit features: "the Becoming tab shows your trend on
  purpose. We don't show you yesterday's number because yesterday's number
  isn't the story."
- End on identity, not number: "in a month you won't recognize what used
  to feel hard."
- **Avoid:** specific weight numbers in the copy; any "you should weigh X";
  any "weigh yourself every day" prescription; any chart of expected loss.

**Tiny action:** A soft `.acknowledge` non-scale-win — "notice one thing
that felt easier this week." No Becoming-tab deep link, no weight
presence-detection, no scale reference anywhere on this screen.
(Locked decision #2.)

**Complete:** "five days in. this is what becoming looks like."

**Preview-your-week:** "From here, your plan keeps going. Open the app any
day this week and the next workout is ready." No re-engagement gimmick,
no new mechanic. Hands back to the existing product.

---

## 4. Personalization branches

### 4.1 What we read (existing UserRecord fields)

Per the investigation doc §3 and §5, the high-signal, reliably-populated
fields we use here are:

| Field | Used for | Branches |
|---|---|---|
| `onboardingExperience` | difficulty of the tiny action; pacing of the muscle conversation | 3 buckets: `beginner` (`neverTried`, `triedFailed`), `casual` (`sometimes`), `experienced` (`regularly`) |
| `onboardingGoal` | which "primary outcome" the lessons echo back | 5 enum: `loseWeight`, `fullBody`, `toneCore`, `growGlutes`, `slimLegs` → mapped to 2 frames: `fatLossPrimary` (`loseWeight`) vs `recompPrimary` (the others). All 5 still see the same lessons; only the headline angle shifts. |
| `onboardingBodyFocus[]` | which body area the tiny action targets when not tied to plan | first item; defaults to "full body" if `[]` |
| `onboardingVoicePreference` | tone of voice (encouraging / balanced / roast) | **see §4.3 — "roast" is OVERRIDDEN for diet lessons; uses "balanced" voice** |
| `name` | first-person addressing on Complete screens | n/a (substitution only) |
| `onboardingIdentityFeeling` | identity word on Complete + Preview screens when present | 5 enum (`powerful`, `calm`, `light`, `strong`, `radiant`) → 5 line variants per Complete screen |

### 4.2 What we read but don't *branch on* (yet)

- `onboardingCurrentWeightKg` / `onboardingGoalWeightKg` — only to detect
  presence in Lesson 5 ("today is your starting line" vs "you've been
  tracking already"). **Never quoted back to the user.**
- `onboardingMotivation` ("summer," "self-love," "confidence," etc.) —
  candidate for v1.1; not used in v1 to keep content surface area down.
- `onboardingHeightCm`, body-type sliders, weights — investigation §3.5
  flagged these as default-contaminated. Don't use.
- `onboardingRelatability1/2/3` — investigation §3.5 flagged
  `false ≡ nil` ambiguity on the wire. Don't use as a personalization gate
  in v1.

### 4.3 Voice override for diet content

The brand voice has three modes: `encouraging`, `balanced`, `roast`. The
"roast" tone is fine for workout cues ("don't fake your last rep") but is
**absolutely not used for diet/eating copy.** A young woman in calorie
restriction does not need her app to roast her about food.

**Rule:** If `onboardingVoicePreference == "roast"`, the Lesson 4 ("Eat to
fuel") and the entire Complete-screen Diet content set use the `balanced`
voice instead. Workout-cue voice elsewhere in the app is unchanged.

Implement this as a single `voiceForDietContent(_ pref: String) -> String`
helper that maps `roast → balanced` and passes everything else through.

### 4.4 Branch matrix (sketch, for content authoring)

Per lesson, copy variants needed:

| Slot | Variants |
|---|---|
| Learn body | 1 universal × 3 experience buckets × 2 goal frames = up to 6 variants per lesson; many can collapse to "universal + 1 beginner-soft variant" |
| Learn headline | 2 (fatLossPrimary / recompPrimary) |
| Tiny action label | 3 experience buckets (sets the difficulty bar) |
| Complete identity beat | 5 (one per identityFeeling) + 1 universal fallback |
| Preview-tomorrow headline | 1 universal per lesson; teases tomorrow's topic |

Cap: **no more than 6 distinct copy strings per slot per lesson.** If we
need more, we cut the personalization, not the safety. This is a content
explosion guardrail.

### 4.5 Resolver pattern

Single helper in `JeniMethodContent.swift`:

```swift
struct ResolvedLesson {
    let id: Int
    let topic: String
    let learnHeadline: String
    let learnBody: String
    let standingSafetyLine: String   // always the same string
    let actionLabel: String
    let actionKind: ActionKind       // .launchWorkout / .openTab(.becoming) / .acknowledge
    let completeLine: String
    let previewLine: String
    let voice: String                // post-override
}

static func resolve(
    lesson: LessonID,
    user: UserRecord
) -> ResolvedLesson
```

`resolve` does field reads + voice override + branch selection. Tests for
this helper are cheap and protect against the matrix going wrong silently.

---

## 5. Hard safety guardrails (operationalized)

The brief gives the rules. This section is how we enforce them in code so
they can't drift.

### 5.1 Content-time invariants

A unit test (`JeniMethodContentTests.swift`) walks every string in
`JeniMethodContent` and asserts:

1. **No digits adjacent to nutrition words.** Regex like
   `\b\d+\s*(calorie|kcal|gram|g|mg|protein|carb|fat|lb|kg|oz|%)\b` →
   test fails if matched anywhere in a Learn/Action/Complete/Preview slot.
   (Lesson 5 may quote weights in tests because it doesn't — but the test
   stays strict.)
2. **No banned framings.** A wordlist test:
   `["starve", "crash diet", "cheat day", "earn", "burn it off", "guilty",
   "naughty", "punish", "clean eating", "detox", "skinny",
   "before and after"]` — any match outside the documented "we reject this
   word" sentence fails the test.
3. **No timeline promises.** Forbidden patterns:
   `(?:in|by|within)\s+\d+\s+(day|week|month)` — fails on any "lose 10 lbs
   in 2 weeks"-style phrasing.
4. **Standing safety line present on every Learn screen.** The resolver
   helper *always* populates `standingSafetyLine` from a single source
   constant; the view always renders it; the test checks both.
5. **No portion-sizing analogies** (locked decision #3). Wordlist:
   `["palm", "fist", "cupped hand", "size of your", "serving size",
   "portion the size", "the size of a"]`. Any match in a user-facing slot
   fails the test. The standing safety line is exempt (it has none anyway).

These tests live in the XCTest target alongside the existing
`WorkoutGenerator` tests (CLAUDE.md notes the harness exists via
`Scripts/add_test_target.rb`).

### 5.2 Render-time invariants

- The Learn screen template hard-renders the standing safety line. There
  is no code path that hides it.
- The "tiny action" screen has no input field for food, weight, or any
  number. It is a single button.
- No screen in the flow accepts free text from the user.

### 5.3 Telemetry invariants

Analytics properties for diet education are explicitly enumerated (see §7).
None of them include numeric body data. A code review checklist line:
"diet education event must not carry weight/age/numeric body data."

### 5.4 Audience-aware copy review

**Mandatory second-eyes copy review on Lessons 4 AND 5** before the flag
flips on (locked decision #6). The ED-risk lens is explicitly named in the
review request. Hard gate in TODOS.md, not optional. This is a process
step, not a code step.

---

## 6. File list

### New files

| Path | Responsibility | Approx size |
|---|---|---|
| `PlankApp/Views/DietEducation/JeniMethodContent.swift` | Typed Swift literal: all 5 lessons × all copy variants. Modeled on `ExerciseBankData.swift`. Includes `ResolvedLesson`, `LessonID`, `ActionKind` types and the `resolve(lesson:user:)` helper. | ~400-600 LOC |
| `PlankApp/Views/DietEducation/JeniMethodLessonView.swift` | The 4-screen container (Learn / Action / Complete / Preview). Case-switch over screen index, modeled on `OnboardingView`'s pattern but much smaller. Reuses `AffirmationScreen` choreography for Complete and `PremiumWelcomeScreen`-style reveal for Preview. | ~300-400 LOC |
| `PlankApp/Views/DietEducation/JeniMethodTodayCard.swift` | The HomeView card surfaced on Days 2-5 when a lesson is available. Scrapbook chrome (see DesignSystem precedent). Tap → opens sheet with `JeniMethodLessonView`. | ~120 LOC |
| `PlankApp/Views/DietEducation/JeniMethodState.swift` | Thin namespace over UserDefaults keys + day-index logic + the idempotency gate for the post-purchase trigger. All keys prefixed `jenimethod.`. | ~120 LOC |
| `PlankApp/Views/DietEducation/JeniMethodSafetyLine.swift` | A 6-line file exporting the standing safety string as a single constant. Imported by both the view and the content test so they can't drift. | ~15 LOC |
| `plankAITests/JeniMethodContentTests.swift` | The §5.1 invariant suite: digit-near-nutrition-word check, banned framings, timeline promises, standing-safety-line presence. | ~150 LOC |
| `plankAITests/JeniMethodResolverTests.swift` | Personalization branch coverage: roast→balanced override, identity feeling fallback, missing-onboarding-field defaults, all 5 lessons resolve cleanly across a representative user matrix. | ~150 LOC |

### Modified files (minimal surface — read-only against trigger points)

| Path | Change | Risk |
|---|---|---|
| `PlankApp/PlankAIApp.swift` | Add `@State private var showingJeniMethod = false`. In the `PremiumWelcomeScreen` `onComplete` (~line 366), flip `showingJeniMethod = true` iff feature flag on AND `JeniMethodState.shouldShowOnPurchase()`. Add a `.fullScreenCover(isPresented: $showingJeniMethod)` directly after the existing celebration cover. | Low — does not touch PaymentService, PaywallView, or the existing `justSubscribed` lifecycle. |
| `PlankApp/Views/Home/HomeView.swift` | Add `JeniMethodTodayCard` to the top of the existing scroll, gated by `JeniMethodState.todaysLessonForCard()`. If nil, card is omitted (no layout shift on completed days). | Low — additive, no existing layout impacted when card is hidden. |
| `PlankApp/Analytics/AnalyticsManager.swift` | Add 5 new cases to `AnalyticsEvent` enum: `dietEducationStarted`, `dietEducationLessonViewed`, `dietEducationActionCompleted`, `dietEducationCompleted`, `dietEducationSkipped`. | None — additive to enum. |
| `PlankApp/Views/Settings/SettingsView.swift` | After Lesson 5 completes, add a "The JeniFit Method" entry that opens a read-only index of past lessons. (Can ship in Phase 7 / cut from v1 without changing other phases.) | Low — additive row. |
| `PlankApp/Config/PostHogAppConfig.swift` (if present and used for flags) OR `PlankApp/Views/DietEducation/JeniMethodFeatureFlag.swift` (new) | Feature flag source: `Analytics.flag("diet_education_v1")` returning a bool, defaulted false. Used by the trigger and the HomeView card. | Low — default-off means existing TestFlight is unaffected if we ship before content is finalized. |

### Files we do **not** touch

- `PlankApp/Payment/PaymentService.swift`
- `PlankApp/Views/Paywall/PaywallView.swift`
- `PlankApp/Views/Paywall/DownsellPaywallView.swift`
- `PlankApp/Notifications/TrialEndNotificationService.swift`
- `PlankApp/Views/Welcome/PremiumWelcomeScreen.swift` (we only flip a flag in its `onComplete` closure from the caller side — the screen itself is unchanged)
- `Packages/PlankSync/Sources/PlankSync/Models.swift` (no SwiftData @Model changes)
- `Packages/PlankSync/Sources/PlankSync/SyncService.swift` (no Supabase upserts)
- `scripts/schema.sql` (no migrations)

---

## 7. Analytics event spec

All through the `Analytics` facade (`AnalyticsManager.swift:107-141`).
**No numeric body data** is carried on any of these events (§5.3).

| Event | When | Properties |
|---|---|---|
| `diet_education_started` | First time Lesson 1 opens (post-purchase fullScreenCover appears) | `paid_status` ("trial" / "subscribed"), `user_goal`, `experience` |
| `diet_education_lesson_viewed` | Each Learn screen `onAppear` | `lesson_id` (1-5), `lesson_topic` (string slug, e.g. "why_this_works"), `user_goal`, `experience`, `paid_status` |
| `diet_education_action_completed` | User taps the action button (workout launched OR "count it" OR "ok" depending on `ActionKind`) | `lesson_id`, `lesson_topic`, `action_kind` ("launch_workout" / "acknowledge" / "open_tab"), `user_goal`, `experience` |
| `diet_education_completed` | Tapping Continue on Lesson 5's Preview-your-week screen | `lessons_completed` (Int, 1-5), `lessons_skipped` (Int, 0-5), `days_elapsed` (Int), `user_goal`, `experience` |
| `diet_education_skipped` | Tapping X on any screen | `lesson_id`, `screen` ("learn" / "action" / "complete" / "preview"), `user_goal`, `experience` |

`paid_status` is derived from
`customerInfo.entitlements["pro"]?.periodType == .trial` at event-emit time
(read on-demand, not cached) — matching the precedent in
`PaymentService.swift:165`.

The existing coalesce-by-step-id pattern in `AnalyticsManager.swift:150-160`
handles re-entry de-duplication.

---

## 8. Phase order

Each phase is small, reviewable, and leaves the app shippable. Default-off
feature flag means we can merge as we go without exposing half-finished
work to TestFlight.

| Phase | Scope | Reviewable artifact | Touches |
|---:|---|---|---|
| 0 | **Plan review (this doc).** ✅ Done. Locked decisions captured at top of file. | This file. | — |
| 1 | **Skeleton + tests.** ✅ Done. 5 source files in `PlankApp/Views/DietEducation/` (`JeniMethodFeatureFlag`, `JeniMethodSafetyLine`, `JeniMethodState`, `JeniMethodContent`, `JeniMethodLessonView`) plus 2 test files (`JeniMethodContentTests`, `JeniMethodResolverTests` — latter holds resolver + goal-gate + day-index test classes). New helper `scripts/add_test_file.rb` for registering test files. Universal-copy stubs pass the full §5.1 invariant suite (digits-near-nutrition, banned framings, timeline promises, safety line, portion analogies). 29 new tests, full project suite 58/58 green. Feature flag defaults false; nothing in production paths references the new code. | Skeleton flow runs via SwiftUI previews on `JeniMethodLessonView`. | 5 new app files + 2 new test files + 1 new script + plan doc edits. No edits to existing source files. |
| 2 | **Wire the trigger.** ✅ Done. Added `@State showingJeniMethod`, chained Lesson 1 from `PremiumWelcomeScreen.onComplete` (synchronous `markEnrolled()` then `showingJeniMethod = true`), added a third `.fullScreenCover` after the celebration cover, plus helpers `shouldTriggerJeniMethodPostPurchase()` (3 ANDed gates: flag + goal allowlist + idempotency) and `jeniMethodUserContext()` (builds the personalization snapshot from @AppStorage mirrors). Build + 58/58 tests green. | Trigger fires once post-celebration for an allowlisted goal; restore-purchase + cold-relaunch + `growGlutes` + flag-off + pre-flag-paid all skip the trigger by gate predicates. | `PlankAIApp.swift` only (+state, +helpers, +1 cover). |
| 3 | **HomeView card.** ✅ Done. Added `JeniMethodTodayCard` (scrapbook chrome, combined-accessibility, opens lesson on tap). Made `LessonID: Identifiable` to use `.sheet(item:)`. Lifted `JeniMethodUserContext.fromAppStorage(_:)` as a shared helper (both RootView and HomeView consume it). HomeView gained: gated `jeniMethodCardLessonId` computed property (flag + goal-gate + state) and `@AppStorage("jenimethod.last_lesson_completed_id")` observer so the card auto-hides on completion without manual refresh. Card sits at the top of the scroll (slot 0, shares stagger beat with greeting); when nil, nothing is rendered (zero layout shift). Sheet, not fullScreenCover. 3 new tests (`fromAppStorage` populated/empty + `LessonID: Identifiable` smoke); 61/61 green. | Manual QA below. | `HomeView.swift` (additive: 1 computed property, 3 state, 1 `if let` block, 1 sheet modifier); `JeniMethodContent.swift` (added `fromAppStorage` + Identifiable conformance); `PlankAIApp.swift` (swapped private helper for shared one); 1 new file `JeniMethodTodayCard.swift`. |
| 4 | **Personalization resolver.** ✅ Done. Replaced universal stubs with branched copy: headline by goal-frame (loseWeight = fatLossPrimary; rest = recompPrimary; Lessons 1-3 only, Lessons 4-5 stay universal), body by experience bucket (beginner ⊇ neverTried+triedFailed / casual = sometimes / experienced = regularly; Lesson 1, 2, 3, 5 only — Lesson 4 stays universal per locked decision #6), completeLine by identityFeeling (5 named + 1 universal fallback for every lesson). Voice override (`roast → balanced`) was already wired in Phase 1; reused as-is. Added `GoalFrame` / `ExperienceBucket` classifier enums + helper functions (`byGoalFrame`, `byExperience`, `identityComplete`) to keep per-lesson resolvers tight. Safety invariants strengthened: `allSlots()` now walks the full 5×5×5×6 = 750-resolve matrix (4 500 strings per test) so any new branch that violates digits/banned/timeline/portion rules fails CI. New §4.4 variant-cap test (≤ 6 distinct strings per (lesson, slot)). 12 new tests across both files; full project suite green. | Targeted run: 30/30 in JeniMethod tests; full suite: TEST SUCCEEDED. | `JeniMethodContent.swift` (resolver branching), `JeniMethodContentTests.swift` (matrix enumeration + cap test), `JeniMethodResolverTests.swift` (classifiers + per-axis branching tests). |
| 5 | **Action wiring.** ✅ Done. `JeniMethodLessonView` action button now branches on `resolved.actionKind`. `.launchWorkout(focus, capMinutes)` generates a real `WorkoutPreset` via `WorkoutGenerator` (mirror of `HomeView.generateDailyWorkout` with shorter cap and tier-matched via `WorkoutGenerator.startingTier`), presents `PreRoutineView` → `RoutineSessionView` in a `.fullScreenCover` over the lesson, and on completion (or PreRoutineView cancel) advances the lesson to its Complete screen per locked decision #5. Sessions ≥ 70% threshold persist via inline mirror of `HomeView.saveRoutineSession` (kept in sync with a `// Mirror of … — kept in sync` comment) — counts toward streak + day progress + Supabase sync. `.acknowledge` (Lessons 4 + 5) unchanged: advance-only. Build + 73/73 tests green. | Verified by code paths: tier helper uses same signal set as HomeView; persistence helper is an exact mirror; 70% threshold gate same as HomeView; PreRoutineView cancel + RoutineSessionView completion both advance to Complete. | `JeniMethodLessonView.swift` only. No HomeView / PlankAIApp / PaymentService changes. |
| 6 | **Analytics + safety audit + copy review.** ✅ Done. Added 5 cases to `AnalyticsEvent` enum (`dietEducationStarted`, `_lessonViewed`, `_actionCompleted`, `_completed`, `_skipped`). New `JeniMethodAnalytics` facade centralizes property assembly so the §5.3 invariant (no numeric body data) is enforced in one place. Wired all 5 events: `_started` in PlankAIApp's Lesson 1 trigger (same beat as `markEnrolled`); `_lessonViewed` on Learn `.onAppear` (de-duped by AnalyticsManager's 0.5s coalesce window); `_actionCompleted` on action button tap (before the action so a force-quit mid-launch doesn't lose the event); `_skipped` on X tap (also bumps `JeniMethodState.skipCount`); `_completed` on Lesson 5's terminal tap with cohort totals. `paid_status` reported as binary `entitled`/`not_entitled` from `PaymentService.shared.hasProAccess` (deviation from §7 spec's `trial`/`subscribed` documented in the helper — splitting would require modifying PaymentService, which violates the observe-only contract). §5.1 invariant suite (4 500-string matrix walk) runs in every test invocation and is green. 13 new tests including the §5.3 no-body-data check. Hard gate added to TODOS.md for mandatory Lessons 4 & 5 copy review before Phase 8 flag-on. | Targeted: 9 analytics-helper tests + 4 skip-count state tests; full suite 86/86. | `AnalyticsManager.swift` (enum), `JeniMethodAnalytics.swift` (new), `JeniMethodState.swift` (+skipCount), `JeniMethodLessonView.swift` (event wiring), `PlankAIApp.swift` (_started wiring), `TODOS.md` (copy review gate). |
| 7 | **Settings re-read index.** ✅ Done. Added `SettingsSheet.jeniMethod` case → `JeniMethodReReadView` (new file: scrollable index of all 5 lessons, each a tap-target showing day + headline; opens lesson as nested sheet). HomeView's settings Menu conditionally surfaces "The JeniFit Method" row when `JeniMethodFeatureFlag.isEnabled && jeniMethodLastCompletedId >= 5` — visible only after the user finishes Lesson 5. `JeniMethodLessonView` gained `isReread: Bool = false` parameter; in re-read mode only the Learn screen renders (continue dismisses), every side effect is suppressed (no `_lessonViewed` / `_skipped` events, no `incrementSkipCount`, action/complete/preview screens unreachable by construction so their `markLessonCompleted` + `_completed` paths are dead). Default `false` keeps every existing call site (PlankAIApp post-purchase, HomeView card) bit-identical. Build + 86/86 tests green. | Read-only contract enforced by gate on `isReread` at the three side-effect call sites + unreachability of forward-motion screens. | `SettingsView.swift` (+1 case + 1 dispatch), `HomeView.swift` (+1 conditional menu row), `JeniMethodLessonView.swift` (+isReread param + 3 gates), `JeniMethodReReadView.swift` (new). |
| 8 | **Flag-on + TestFlight.** 🟡 Ready, copy-review-gated. All code merged; flag stays `false` until the Lessons 4 & 5 copy review signs off per locked decision #6. Full unblock playbook (review checklist + the exact one-line `JeniMethodFeatureFlag.swift` diff + TestFlight + funnel-monitor steps + rollback) lives in `TODOS.md` under "JeniFit Method — Phase 8 unblock playbook". | TestFlight slice; PostHog funnel. | `JeniMethodFeatureFlag.swift` (one-line default change, captured in TODOS.md); build number bump. |

Phases 1-7 are mergeable individually behind the flag. Phase 8 is the one
visible-to-users moment and can be staged via the flag's percentage rollout
(or just default-on after a TestFlight pass).

---

## 9. Open questions

These need an answer before Phase 2 ships — they're not blockers for
Phase 1 (skeleton) but they shape the trigger/card behavior.

1. **Is Lesson 1 part of the celebration moment, or a separate beat?**
   Spec says "AFTER the existing PremiumWelcomeScreen celebration," which I
   read as: celebration plays first (2.5s auto-dismiss, unchanged), then
   Lesson 1 opens as its own cover. Confirm. *Default if unclear: separate
   beat.*

2. **Cold launch on Day 2 — does the card auto-open Lesson 2 if untouched,
   or stay as a card?** My read: stay as a card (less hostile). User can
   close the app and come back without losing the lesson. *Default if
   unclear: stay as a card.*

3. **Does skipping Lesson 1's "tiny action" (the workout) still count as
   completing Lesson 1?** My read: yes — the lesson is the *education*,
   not the workout. The action is a soft nudge, not a gate. So tapping
   "skip action" still advances the lesson and shows Complete + Preview.
   *Default if unclear: skipping action does not block lesson completion.*

4. **Notifications for tomorrow's lesson — schedule one, or rely on the
   user opening the app?** My read: rely on the user. Adding a second
   daily notification on top of the existing `daily_reminder` is noisy and
   risks collision (investigation §4.2 risk table). *Default if unclear:
   no new notifications; HomeView card carries it.*

5. **Re-read behavior — does re-reading a lesson fire `lesson_viewed`?**
   My read: no. Re-reads are read-only and skip telemetry to keep
   "lesson_viewed" a clean funnel signal. *Default if unclear: no
   re-read telemetry.*

6. **For users who paid before this ships — do they retroactively get the
   flow?** Two options:
   (a) Backfill: on first launch after upgrade, treat them as "just paid"
       and start Lesson 1. Catches existing trialists in the warm window.
   (b) Forward-only: only users whose `payment.effectiveHasProAccess`
       transitions false→true *after* the flag flips get the flow.
   My read: forward-only is safer, simpler, and respects the "existing
   users must not break" constraint more strictly. *Default if unclear:
   forward-only.* Backfill is a separate v1.1 decision.

7. **Lesson 4 (food) — the sensitive one. Do we want a second
   subject-matter eye on this lesson specifically before any user sees
   it?** My read: yes. This is the lesson where a wrong word does the
   most harm. Flag it in TODOS.md for explicit copy review before
   Phase 8. *Default if unclear: extra copy review on Lesson 4.*

---

## 10. Risks to the no-migration / no-paywall-change contract

| Risk | Likelihood | Mitigation |
|---|---|---|
| The third `fullScreenCover` competes with `justSubscribed` celebration | Low | Trigger Lesson 1 from `PremiumWelcomeScreen.onComplete` (sequential), not from the same onChange handler (parallel). The existing cover dismisses first; the new one presents on the *next* run loop tick. |
| Future `PremiumWelcomeScreen` refactor drops the `onComplete` closure | Low | The wiring is a single call site; rename/refactor is mechanical. Test: a UI test that just verifies Lesson 1 fires post-celebration would catch this immediately. (v1.1 nice-to-have.) |
| `JeniMethodState.shouldShowOnPurchase` returns the wrong answer for restored purchases | Medium | Treat "restore" the same as "purchase" — both flip `payment.effectiveHasProAccess` to true. Idempotency key (`lesson_1_started_at`) means a user who already saw the lesson won't see it again on restore. Verify in Phase 2 QA. |
| HomeView card shifts layout, regressing the existing scrapbook scroll | Low | Card is appended at the top of the existing scroll inside an `if let card = ...` branch. When nil, no view is rendered — no spacer, no padding. Same pattern as the existing first-session hint. |
| Content invariant test misses a Unicode look-alike digit (e.g., `１ gram`) | Medium | Test regex uses Unicode-aware digit class `[\p{Nd}]+` instead of `\d+`. Documented in the test file. |
| Voice override flag (roast → balanced for diet) gets bypassed by a future copy author who hardcodes a voice in the content struct | Medium | The `ResolvedLesson.voice` field is the *only* voice source the view reads. Content authors don't set voice in `JeniMethodContent` literals — the resolver sets it from the user preference + override. Architectural fence. |
| Feature flag stays default-off forever and the work gates rot | Low | Phase 8 is explicitly "flip the flag." Calendar it. |
| Cross-device sign-in mid-program loses progress (state is `@AppStorage`-only per §6) | Known (per investigation §6 open questions) | Accept for v1. UX cost: a user who signed up on device A and continued on device B sees Lesson 1 again. Worth re-evaluating after PostHog tells us what % of users actually sign in on a second device during their first 5 days. Schema-change avoidance is worth the friction in v1. |
| `paid_status` derivation reads `customerInfo` on every event emit | Low | Cheap — `Purchases.shared.customerInfo` is in-memory after first emit. If profiling shows this hot, cache the most recent value in `JeniMethodState` with a short TTL. |
| Lesson 5's "open Becoming tab" deep-link breaks when the Becoming tab is restructured | Low | Use the existing tab-selection pattern from `MainTabView`. Restructuring would touch all deep links, not just ours. |
| Content surface area explodes once we add Lesson 4's branches | Medium | §4.4 caps it at 6 variants per slot. If exceeded, cut branches before adding them. The resolver test will fail fast on a forgotten branch combo, surfacing the explosion. |
| New `jenimethod.*` UserDefaults keys aren't cleared on account-delete | Low | The existing `DeleteAccountSheet` flow already targets app data. Add `jenimethod.*` key prefix to its clear-list in Phase 4. |

---

## 11. Out of scope (named so it doesn't sneak in)

These would be great but are not v1:

- Meal logging, calorie tracking, macro counting — any of them. None of
  this. Not a fitness-with-nutrition app in v1; a fitness app that *talks
  honestly about* nutrition.
- Photo-based "before / after" comparisons.
- Branching by motivation, relatability, or weight delta — investigation
  §6 sketched these for Daily Reset; for diet education they're cut to
  keep the content matrix sane.
- Push notifications for next-day lessons.
- A/B testing different lesson orders.
- A "Lesson 6" expansion of any kind.
- Localization beyond English. (The existing app is English-only as of
  v1.0.)
- Cross-device sync of education completion state.

End of plan. Awaiting review before starting Phase 1.
