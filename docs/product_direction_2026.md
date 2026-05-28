# JeniFit — Product Direction 2026

Status: Draft 1
Last updated: 2026-05-27
Owner: bko

This document is the strategic + design source of truth for the next
phase of JeniFit. It captures the vision, the locked constraints, the
data we already collect, and the redesign that ships next — built to
preserve onboarding, the workout engine, sync, payment, and the DB
schema as they exist today.

Companion docs:
- `docs/THEME.md` — y2k coquette aesthetic spec (locked)
- `docs/workout_session_rules.md` — engine rules (locked)
- `docs/diet_education_plan.md` — original ritual plan (superseded for
  post-purchase placement; content kept, relocated to opt-in surface)
- `docs/weight_loss_analytics_research.md` — Becoming-tab research base

---

## 1. Vision

JeniFit is the weight-loss program for women 22-35 who are determined
to succeed without GLP-1s. Jeni is their personal coach — she shows up
every day, knows their story, runs their program, and adjusts as they
go. The product is *built with AI under the hood* and *presented
entirely as Jeni*. There is no "AI" framing anywhere in the user
experience, ever.

Future product surface (built incrementally on the same data model):

- **Phase A — now:** workouts + Jeni-as-coach post-purchase + Becoming
  tab as retention spine
- **Phase B — Q3 2026:** food logging (Jeni sees your plate)
- **Phase C — Q4 2026:** weekly check-in photo (Jeni tracks your
  becoming)
- **Phase D — 2027:** adaptive coach intelligence (LLM-driven plan
  adjustment, *always voiced as Jeni*, never surfaced as AI)

The destination is a Noom-alternative weight-loss program for the
non-GLP-1 cohort, with Jeni as the parasocial coach who replaces both
the lecture-heavy curriculum (because users don't want lectures from
strangers) and the AI assistant framing (because the demo is actively
hostile to AI signaling in 2026).

---

## 2. Audience

**Primary:** TikTok-acquired women, 22-35, beginner fitness, weight-loss
motivated.

**What they want (research-validated, 2024-2026):**
- A program shape, not "an app of workouts"
- A coach who feels like a real person who knows them
- Soft commitment (daily ritual, returnable after a miss)
- Identity language ("becoming someone who shows up") over body-change
  language ("drop the pounds")
- Privacy — their weight and photos live on-device by default

**What they reject:**
- Any AI signaling (anti-AI is now a values position, not a complaint)
- Streak-loss copy, fire emojis, "don't break your streak"
- Before/after photo grids and BMI banner displays (SkinnyTok-coded)
- Bro-coded language: crush, destroy, beast mode, shred, torch
- Aggressive femvertising: "babe", "snatched", "summer body"
- Pre-paywall lectures that feel like content gates
- Subscription apps that don't earn the daily open

**Acceptable weight-loss register in 2026:**
- Capability language: "hold a 90-second plank", "show up 4 days this
  week"
- Identity language: "becoming", "the kind of person who"
- Ritual language: "morning movement", "today with jeni"
- Body-neutrality: "how your body feels", never "how your body looks"

---

## 3. Strategic positioning

JeniFit is **a weight-loss program with a parasocial coach** — not a
fitness app, not an AI assistant, not a content library.

Category placement (from research):

| Category | Apps | JeniFit fit? |
|---|---|---|
| Pure fitness tool | Cal AI, Fitbod, Strava | ❌ Too utilitarian |
| Lecture-heavy curriculum | Noom, Lasta | ❌ Wrong: forces content gate |
| Coach-branded fitness | Sweat, Future, Ladder | ⚠️ Closest, but lacks weight-loss program shape |
| Parasocial companion | Finch, Replika | ⚠️ Mechanic insight (no penalties), wrong topic |
| **Weight-loss program + parasocial coach** | **JeniFit** | ✅ **The slot** |

The pattern that wins this slot (synthesized across competitor +
psychology + Gen Z research):

1. **Soft commitment + asymmetric care.** Jeni shows up for the user;
   the user doesn't have to show up for Jeni. Finch's $30M bootstrapped
   ARR is the proof. No streak-shame, ever.
2. **Single program-shape signal.** "Week N · day M of 12 weeks" — that's
   enough. Heavy calendar chrome over-promises and pulls toward
   workout-app identity.
3. **Specific personalization beats generic warmth.** Jeni naming the
   user's actual barrier, weight gap, and identity feeling does more
   parasocial work than any "you got this" line.

---

## 4. Brand voice — locked rules

Already in CLAUDE.md and prior memory; consolidated here for the AI-tell
audit (new addition based on 2026 Gen Z research).

**Voice rules:**
- Lowercase casual
- Italic-Fraunces accent on punch words only (e.g., *becoming*, *today*,
  *fit me*)
- Hearts as terminal punctuation only (never decorative mid-sentence)
- No brand-coined verbs
- "We" and "us" pronouns; coach voice is collaborative not authoritative
- Concrete numbers over vague ones ("five minutes" not "a few minutes")
- Permission language over commands ("we can" not "you must")

**Banned vocabulary — AI-tell audit (NEW):**

Run as a CI grep over `Localizable.strings` + Swift `Text(...)` literals.
Failing build on hit.

| Banned | Why |
|---|---|
| `—` (em dash) | #1 Gen Z AI-slop tell in 2026 |
| `delve`, `leverage`, `embrace`, `journey`, `dive in`, `elevate` | Generic AI-coach vocab |
| `It's not X, it's Y` / `less about X, more about Y` | Negative parallelism = AI tell |
| Three-adjective bursts (e.g., `gentle, grounded, and present`) | Rule-of-three = AI tell |
| `I'm here for you` repeated, `unconditional` | Replika tell — coach gives direction, not validation |
| `crush`, `destroy`, `beast mode`, `shred` | Bro-coded |
| `torch`, `burn`, `shed`, `melt the fat` | Fatphobic, dated |
| `snatched`, `summer body`, `dream body`, `bikini body` | Femvertising-coded |
| `analyze`, `process`, `data-driven`, `algorithm`, `AI-powered`, `your data` | AI signaling |

**Acceptable replacements (voice samples):**

| Instead of | Use |
|---|---|
| "based on your data, today is..." | "i was thinking about you. today we..." |
| "AI-powered workout" | "today's workout, made for you" |
| "let's dive in" | "let's go" or just the action |
| "you've got this!" | "i'll see you in 5 mins ♥" |
| "your AI coach" | "jeni" |
| "we'll analyze your progress" | "i'll see how it feels" |

---

## 5. Design principles

Three load-bearing principles, in priority order. Every design decision
should pass these in order.

1. **No AI signaling, anywhere.** Includes stylistic tells, not just the
   word. The 2026 Gen Z AI-skepticism is values-level — getting flagged
   as "an AI app" is brand damage that compounds.
2. **Single program-shape signal, not a calendar grid.** Just the week
   indicator + day dots. Over-engineering calendar chrome reads as
   workout-app identity. Under-engineering (no signal at all) reads as
   "an app of workouts" without program legibility.
3. **Soft commitment, never loss aversion.** Streak-shame, fire emojis,
   "don't lose your streak" copy, hearts-as-lives — all banned. Replace
   with nurturing metrics ("weeks shown up") + free Rest Day pill.

---

## 6. What's locked — do not change

Everything in this section is shipped and load-bearing. Phase A
redesign is built *around* these, not *on top of* them.

**Database schema (Supabase):** profile, session_logs, day_progress,
weight_logs, session_ratings. No new tables for Phase A. Phase B (food
log) and Phase C (body scan) will require schema changes — gated.

**Onboarding flow:** 54 cases in `OnboardingView.swift` flowOrder; all
questions and persistence intact. Phase A leverages every field currently
collected. The only known orphan (case 160 — `reshapeTransitionScreen`)
is unrelated and tracked separately.

**Workout session algorithm:** `docs/workout_session_rules.md` and the
five DEBUG validators. Position-block ordering, family clustering,
rest mini-factors, voice cascade — all stay. Phase A does not touch the
engine.

**Voice cascade:** Existing `Packages/PlankVoice/` infrastructure. Phase
A leverages it; Phase A+ extends it for non-workout Jeni voice memos.

**Auth + sync:** Anonymous-first Supabase, Apple + email upgrade,
typed Codable upserts. Phase A does not touch.

**Payment:** RevenueCat + customerInfoStream + paywall personalization.
Phase A does not touch the paywall itself; only what happens *after*
purchase.

**Becoming tab:** Already research-validated (WHO ring, EMA weight trend,
ACSM goal pace, AHA BMI banding, Bandura mastery curve, barrier-resolved
card). Phase A *promotes* this surface, doesn't change it.

**Post-workout afterglow:** Shipped in commits e9229cb / 22c3e2d. Phase A
keeps as-is — already the right pattern (gentle reinforcement, soft
return reason).

**The y2k coquette aesthetic:** `docs/THEME.md`. Phase A inherits
visually.

---

## 7. Data inventory — what we already collect

Everything below is in `@AppStorage` or `UserDefaults` today. The new
post-purchase + home redesign templates against these. Zero new
onboarding questions needed for Phase A.

**Identity:**
- `userName` — required for personalization
- `identityFeeling` — powerful/calm/light/strong/radiant
- `ageRange` — for tone calibration (don't surface)
- `voicePreference` — encouraging/balanced/keepItReal

**Goal:**
- `userMotivation` — loseWeight/fullBody/toneCore/growGlutes/slimLegs
  (the "why")
- `bodyFocus` — multi-select: flatBelly/fullBody/roundButt/slimLegs/
  tonedArms (the aesthetic zone)
- `focusArea` — abs/obliques/lowerBack/fullCore (anatomy for engine)
- `userGoal` — derived from focusArea, drives WorkoutGoal pipeline

**Body math:**
- `onboardingCurrentWeightKg` — starting weight
- `onboardingGoalWeightKg` — target weight
- *Derived:* `weightToLose` = currentKg − goalKg
- *Derived:* `predictionDate()` exists in `OnboardingView.swift:5278`:
  84 days base (12 weeks) ± 14 days for `activityLevel`. Currently
  computed inline; **Phase A persists it as `onboardingGoalDate`** via
  a one-line addition to `handleOnboardingComplete`. Same date the user
  saw on the projection chart, now available to `CoachIntroView` and
  `JenisNoteCard` for "{weeksRemaining} weeks left" messaging.
- *Derived:* `weeksToGoal` = dateDiff(now, onboardingGoalDate) ÷ 7

**Friction signal:**
- `userBarriers` — multi-select; Phase A uses the first as `topBarrier`
  in coach intro

**Capability baseline:**
- `userBaselineSeconds` — plank baseline from onboarding
- `plankTime` — current plank time
- `userExperience` — neverTried/triedFailed/sometimes/regularly
- `activityLevel` — for calibration (don't surface)

**Cadence:**
- `commitmentDays` — sessions/week target
- `sessionLengthPref` — minutes/session
- `notificationHour` / `notificationMinute` — for daily reminder
- `notificationsEnabled` — opt-in state

**JeniMethod state:**
- `jenimethod.feature_enabled` — kill switch
- `jenimethod.lesson_1_started_at` — idempotency
- `jenimethod.last_lesson_completed_id` — progression
- `jenimethod.enrolled_at` — day-index math
- `jenimethod.skip_count` — UX signal
- `jenimethod.ritual_last_shown_at` — once-per-day gate

**Logs (Supabase):** session completion, ratings, weight entries, day
progress — fully synced and queryable for the daily Jeni note.

---

## 8. Phase A — the redesign that ships now

Six changes, none of which touch the locked surfaces (DB, onboarding,
workout engine, voice cascade, payment, auth).

### 8.1 `CoachIntroView` — replaces the post-purchase ritual gate

**Replaces:** `JeniMethodRitualView` fullScreenCover at
`PlankAIApp.swift:430-462` and the `pendingPostRitualWorkoutLaunch`
relay.

**Behavior:** Single screen, ~60-75s. Personalized voice-memo cadence
in text (Phase A+ adds real audio). Direct workout launch from CTA — no
UserDefaults relay, no HomeView round-trip.

**Personalization fields used (all already collected):** `userName`,
`onboardingCurrentWeightKg`, `onboardingGoalWeightKg`, `onboardingGoalDate`
(NEW persistence — see §7), `identityFeeling`, `userBarriers[0]`,
`commitmentDays`, `voicePreference` (selects audio tone register).

**Format: audio + text (dual-layer).** Audio carries the parasocial
weight (real Jeni voice memo, ~30-45s, recorded once, NOT personalized
at the audio layer). Text on-screen carries the personalization (math,
date, barrier, identity feeling). Together they read as "Jeni talking
to me specifically" — the audio makes it feel real, the text makes it
feel known.

**Voice sample — text layer (subject to copy review):**

```
hi, {name}. ♥

i was thinking about you.

you want to lose {weightToLose} lbs by {goalDateShort}.
you said you want to feel {identityFeeling}.
and {topBarrier}. i hear you. we'll work on that.

okay. here's how we'll do it.

12 weeks together to set the pattern.
then we keep going — as long as you want me.

today: one workout. 5 minutes.
that's it.

then i'll see how it felt.

[ let's go ]
```

**Voice sample — audio layer (recorded once, ~40s, plays under text):**

```
hi there. it's jeni.

so glad you're here.

ok, here's how we'll do this together.

we start small. five minutes a day.
i'll see how it feels for you, and we'll
build from there.

we'll do twelve weeks to set the pattern.
the real changes happen after that — and
i'll be right here for as long as you want me.

ready? let's start with today.
```

**12-week + annual framing rationale:** The 12-week line is the
concrete commitment frame (what the user can grasp immediately). The
"as long as you want me" line is the asymmetric-care frame — Jeni
*offers* continued presence; doesn't demand commitment back. This
implicitly justifies the annual subscription (Jeni stays the whole
year and beyond) without sounding like upsell. Research-validated:
asymmetric care + soft commitment outperforms contract-style
commitment for this demo (Finch model, $30M ARR with zero penalties).

**Files to add:**
- `PlankApp/Views/Paywall/CoachIntroView.swift` (~140 lines)
- `PlankApp/Resources/Audio/coach_intro_jeni.m4a` (Phase A.1 — produced
  via ElevenLabs voice clone of chosen Jeni voice, ~40s)

**One-line additions to existing files:**
- `PlankAIApp.swift:handleOnboardingComplete` — persist
  `onboardingGoalDate` derived from `predictionDate()` logic
- `PlankAIApp.swift:430-462` — replace fullScreenCover content

**Ship strategy:**
- Phase A.0 (this sprint): text-only, no audio
- Phase A.1 (next sprint, after audio production lands): swap in audio layer

**Events:** `coach_intro_viewed`, `coach_intro_audio_started`,
`coach_intro_audio_completed`, `coach_intro_continued`

### 8.2 `WeekProgressStrip` — program-shape signal on Home

Top of HomeView, lightweight. "Week 1 · day 3 of 12" + 7 dots showing
this week's days. Reads from `jenimethod.enrolled_at` (or earliest
session date as fallback).

**File to add:** `PlankApp/Views/Home/WeekProgressStrip.swift` (~40 lines)

**Events:** none — passive surface

### 8.3 `JenisNoteCard` — daily templated coach message

Above the workout hero card. Voice-memo cadence in text. References
yesterday's session (from `session_logs`), today's plan, and one
personalized line from `bodyFocus` or `identityFeeling`. Hides on days
where no real content can be generated (don't fake it).

**Templating logic:** new file `PlankApp/Voice/JenisNoteTemplate.swift`.
Pure function: takes user context + recent logs, returns 1-3 sentence
note or nil. Phase D swaps this for LLM-generated under the hood, same
output shape, voiced identically as Jeni.

**File to add:** `PlankApp/Views/Home/JenisNoteCard.swift` (~80 lines)

**Events:** `jenis_note_viewed` (per-day, deduped)

### 8.4 Move ritual content to opt-in `TodaysLessonCard`

The existing `JeniMethodRitual.day1Beats` content stays — relocates from
post-purchase gate to an opt-in card on Home. Surface hides when there's
no real content for the user's current day (Days 2-5 are stubs; hide
those until written).

**Existing file changes:** `HomeView.swift` — add `TodaysLessonCard`,
fed from the existing `JeniMethodRitualView` opened in a sheet (not
fullScreenCover). Existing ritual code stays intact.

**Events:** `lesson_card_viewed`, `lesson_card_tapped`, plus per-beat
heartbeat (`diet_education_beat_viewed`) added to the existing ritual
view — finally gives us per-beat survival data for the opt-in cohort.

### 8.5 Locked rail stubs — Phase B/C preview

Two grayed cards at the bottom of Home:
- "📷 food + jeni" — caption: "jeni's working on this. soon."
- "📸 weekly check-in photo" — caption: "your time capsule. soon."

Tappable to a small explainer sheet (one paragraph, coach voice).
Captures intent signal via `future_rail_tapped` events with `rail_id`
property — tells us which Phase B/C feature to ship first based on
actual demand.

**Files to add:** `PlankApp/Views/Home/FutureRailCard.swift`,
`PlankApp/Views/Home/FutureRailExplainer.swift`

### 8.6 Soft-streak replacement + AI-tell audit

**Streak:** replace any "don't lose your streak" copy with "weeks shown
up" framing. Extend `StreakCalculator` with a `rest_credit: Int` field
(one free Rest Day per calendar month). Surface as a tappable pill on
Home, not a fire emoji.

**AI-tell audit:** grep the entire `Localizable.strings` + Swift `Text`
literals for the banned list in §4. Patch every hit. Add CI gate as a
`Scripts/lint_voice.sh` script run pre-commit.

**Estimated patch surface:** ~30-60 strings (largely in the existing
ritual, paywall, and home subtitle modules — most are already
voice-rule-compliant but em dashes are everywhere).

---

## 9. Roadmap — phases beyond A

### Phase B (Q3 2026) — Food + Jeni

User feature: photo of a meal, voice-coached log, Jeni "saw" your plate
and writes a brief note in response.

**Under the hood:** Apple on-device Foundation Models (iOS 26+) for food
recognition; fall back to Vision + a server-side LLM for older devices.
**Framed as Jeni, never as "AI" or "calorie scanner."**

**DB schema additions (gated, opt-in):** `food_logs` table — image URL or
hash, parsed nutrients, Jeni's response. Sync rules mirror `weight_logs`.

### Phase C (Q4 2026) — Weekly check-in photo

User feature: weekly self-photo as a private "time capsule." Jeni
references the cadence ("3 weeks since your first photo") but doesn't
*compare* photos visually — that's a SkinnyTok-coded UX we explicitly
avoid.

**DB schema additions:** `body_check_ins` table — image hash, optional
note. Photos stored on-device by default; opt-in sync.

### Phase D (2027) — Adaptive coach intelligence

Server-side LLM (or on-device for newer hardware) generates Jeni's daily
notes, rest-day suggestions, and workout adjustments based on logs.
**Surface is unchanged from Phase A** — the `JenisNoteCard` and the
workout card already have the right shape; the templating layer behind
them gets smarter.

**Critical:** Jeni's voice rules apply to LLM output too. The AI-tell
audit becomes a runtime filter on generated copy.

---

## 10. Anti-patterns — what we explicitly don't do

From the convergent research, these are not on the roadmap, not in a
future phase, not "maybe later." They are out.

- ❌ Pre-action lectures or curriculum gates post-purchase
- ❌ Streak-loss copy, fire emojis, hearts-as-lives, "don't miss tomorrow"
- ❌ Before/after photo grids; SkinnyTok-coded comparison UX
- ❌ Prominent BMI display (current de-emphasis is correct)
- ❌ Bro-coded language; femvertising-coded language; weight-shame copy
- ❌ Public leaderboards, friend feeds, social comparison (anxiety-driving
  for this demo; Finch did $30M ARR with zero social features)
- ❌ "Good food / bad food" categorical labels (Kurbo cautionary tale)
- ❌ Any UI copy referring to "AI", "algorithm", "your data", "analyze",
  "process" — Jeni voice only
- ❌ Em dashes in any user-facing copy
- ❌ Mandatory tutorials anywhere; everything skippable except the
  post-purchase coach intro CTA (single tap, no skip needed)
- ❌ Reverse obligation ("don't let Jeni down" / pet-care-style guilt
  loops); asymmetric care — Jeni shows up for the user, not vice versa

---

## 11. Success metrics — what we measure for Phase A

**Activation (primary KPI):**
- `purchase_completed → first_workout_start` rate
- Time-to-first-workout (target: <2 min)
- `coach_intro_viewed → coach_intro_continued` rate (target: ~95%)

**Daily engagement (program-fit signal):**
- D1 / D3 / D7 return rate
- `jenis_note_viewed` per-week per-user
- Days-active-in-week distribution

**Retention proxies (until D30 is reachable):**
- Refund rate (RevenueCat)
- Active days in first 14 days
- Lesson-card opt-in tap rate (validates the moved-content thesis)

**Future feature signal:**
- `future_rail_tapped` by `rail_id` — which Phase B/C feature has more
  pull
- Lesson-card opt-in by user goal — does the curriculum want differ by
  motivation?

**Comparison baseline:** May 26 launch-day cohort (ritual gate active).
No A/B (move-fast posture); directional rolling-7-day before/after the
Phase A swap.

---

## 12. Open questions — decisions log

### Resolved 2026-05-27

1. ✅ **Program length: 12 weeks** with explicit annual framing.
   `CoachIntroView` carries both: "12 weeks together to set the pattern.
   then we keep going — as long as you want me." The 12-week frame is
   the concrete commitment for the user; the open-ended line implicitly
   justifies the annual subscription as continued Jeni presence (not as
   contract). `WeekProgressStrip` displays "Week N · day M of 12 weeks".

2. ✅ **`CoachIntroView` format: audio + text dual-layer.**
   - Audio = ~40s Jeni voice memo, recorded once, NOT personalized at
     audio layer. Carries the parasocial weight.
   - Text = personalized stats + identity references on-screen during
     audio playback. Carries the "she knows me" weight.
   - Ship strategy: Phase A.0 = text-only; Phase A.1 = swap in audio
     after ElevenLabs production lands.

3. ✅ **`goalDate` exists** — `predictionDate()` in
   `OnboardingView.swift:5278` computes it from `activityLevel`. Phase A
   adds one-line persistence at onboarding completion
   (`onboardingGoalDate`). Same date the user already saw on the
   projection chart; now available app-wide for `CoachIntroView`,
   `JenisNoteCard`, and future "{weeksRemaining} weeks left" messaging.

### Open

4. **Rest Day pill cadence:** one free per calendar month (default), or
   adjust based on `commitmentDays`? Recommend a simple monthly default,
   iterate based on observed Rest Day tap rate.
5. **Days 2-5 lesson content:** write now (week 3-4 of Phase A) or hide
   surface until ready? Recommend hide; write Day 2 as the first
   priority, surface incrementally.
6. **Live Activity for today's workout:** ship in Phase A.0 or A.1?
   ActivityKit setup is ~1 day; gives us iOS 26 baseline behavior.
   Recommend Phase A.1 (after CoachIntroView + Home redesign).
7. **Voice talent for Phase A.1 audio:** ElevenLabs voice clone of an
   existing JeniMethod voice asset (Jeni / Kira / Matson per
   `method_preview_*` audio convention), or a fresh voice profile? Most
   coherent with existing brand is to clone whichever voice the user
   selected at onboarding (`voicePreference`) — three audio files
   (`coach_intro_jeni.m4a`, `coach_intro_kira.m4a`,
   `coach_intro_matson.m4a`) mirroring the existing
   `method_preview_*.m4a` naming pattern.

---

## 13. Research sources

This direction synthesizes four targeted research passes (2026-05-27):

- Competitor post-purchase first-session patterns (18+ fitness/wellness
  apps; Sweat, Cal AI, Fitbod, Future, etc.)
- Post-purchase psychology (Festinger dissonance, Norton/Mochon/Ariely
  IKEA effect, Nunes & Drèze endowed progress, Fogg/Clear identity
  habit formation, Neff self-compassion for women)
- Relationship-vs-tool app taxonomy (Noom, BetterMe deep dives;
  Headspace/Sweat/Ladder/Finch identity-beat patterns)
- Weight-loss program category (Noom 1B ARR retention math, BetterMe
  $75M ARR action-shaped flow, Calibrate/WW/Lasta patterns,
  post-Ozempic non-GLP-1 women psychology)
- 2026 fitness app UX state-of-the-art (Cal AI / FORM / Pam home
  patterns; iOS 26 Live Activities; streak gamification critique;
  voice/audio coaching evolution)
- 2026 Gen Z women behavioral + aesthetic shifts (anti-AI sentiment
  specifics, underconsumption-core, post-Ozempic body-image landscape,
  scrapbook UI trend, parasocial coach mechanics)

Internal data inputs (with caveats):
- 3 days of post-launch production data (insufficient for D7 retention
  measurement)
- 15 real buyers, 5 activated, ritual launched May 26
- Skip-pattern analysis: 78% of skip events followed by Application
  Backgrounded within 5 min (skip = quit, not speed-tap)

This document supersedes the original `docs/diet_education_plan.md` for
post-purchase placement decisions only. The ritual *content* in that doc
remains canonical — Phase A relocates it to the opt-in lesson card.
