# Lesson retention mechanics — expert brief (2026-06-11)

Scope: retention MECHANICS of the JeniMethod lesson surface (entry, completion, continuity,
lesson→action chain). Grounded in current code: `JeniMethodState.swift` (engagement-day lesson
mapping, day 15+ → `.generic`), `JeniMethodRitual.swift` (2-page drops, 1-page generic loop),
`JeniMethodRitualView.swift` (handoff CTA), `PlanView.swift` (checklist row → `openLesson()`,
auto-complete on `onComplete`), `JeniMethodReReadView.swift` (exists, buried in Settings).

Signal being protected: lessons are the magnetic surface (75%+ completion vs 23% workouts,
84% of WAU). Cohort: skeptical-but-hopeful Gen-Z women drowning in conflicting WL content —
the lesson IS the "stop searching, do this" authority promise. Everything below optimizes
for daily-open habit, not time-in-app.

---

## 1. The day-15+ cliff

Today: `lessonId(forDay:)` returns `.generic` (rawValue 15) forever after day 14 — one page,
three rotating one-liners picked by day-of-year mod 3. On the highest-engagement surface,
day 15 is where the product's best habit loop degrades to a fortune cookie.

What the category leaders do when curriculum ends:
- **Noom** never lets the curriculum end inside the paid window — the course is longer than the
  median subscriber's life (16+ weeks). Lesson: match content runway to billing horizon. JeniFit's
  program is 60-90 days custom; 14 days of content against a ~75-day program is the actual bug.
- **Duolingo** post-course = personalized practice of YOUR past material (mistake review, spaced
  repetition in the Practice Hub). New content is generated from the user's own history, not authored.
- **Headspace** pivots from course to **Daily** — "The Daily Headspace," one fresh short item per
  day, editorial, low production. The daily slot survives the curriculum because the slot itself
  (not the curriculum) is the habit.

**v1-cheap (ship with the redesign, ~zero new content):** replace the single generic page with a
rotating **review ritual** built from the 14 lessons already written:
- Day 15+ resolves to a 2-page drop: page 1 = the *fact* page of a past lesson, re-framed
  ("remember this one?") on a spaced schedule (revisit lesson N at +7d, +21d, +60d after first
  read — coarse Leitner, computed from `lastCompletedLessonId` + engagement day, no schema).
- Page 2 = one weekly variant: on the user's 7th/14th/21st engagement day, swap page 2 for a
  **her-week-in-numbers** page from existing records (steps days, meals snapped, weight logs,
  breath minutes). Data-provenance rule holds: only collected fields, never estimates.
- Keep the 3 rotating intentions as the fallback when nothing is due.
This converts the cliff into Duolingo-style "practice your own material" at the cost of a
resolver function and ~6 short re-frame headlines.

**v2-right (next content cycle):** **seasons + her own highlights.**
- Season 2: 14 more lessons themed food/satiety/food-noise (matches the diet-first pivot;
  the curriculum should at minimum cover the program's `totalDays`, ideally in 14-day chapters
  with a named chapter break — endowed-progress reset, fresh-start effect per the existing
  day-14 lesson's own citation).
- Save-a-line (see §2d) feeds spaced repetition: HER highlighted sentences resurface as day-15+
  page 1 ("you saved this on day 6"). Self-generated content is the only infinitely scalable,
  personally relevant supply — this is the Duolingo move, and it compounds with tenure.
- Skip UGC-ish free-text reflection prompts as a content source: this cohort lurks, doesn't
  journal in-app; blank-text-box abandonment is high and the content can't be reused safely.

---

## 2. Completion loop — what the last page should DO

Current state: every numbered lesson's last page CTA is "start today's workout" with
`isHandoff: true`, but PlanView passes no `onCompleteAndStartWorkout`, so the button labeled
"start today's workout" silently just dismisses. That's worse than broken — it's a trust leak
on the surface where trust is the product. Fix or relabel before anything else.

Ranked verdict:

**1. (b) Chain to next unchecked row — adopt.** The lesson is the highest-intent moment of
the day (she just finished something; 75%+ get here). Momentum chaining is the single best
documented session-end mechanic (Headspace "next up", Duolingo session-end funnel). And it
solves the broken CTA correctly: instead of hardcoding "workout," the last page reads the
checklist and offers the FIRST unchecked row — "next: *snap a meal*" / "next: *2 minutes of
breath*" / "next: today's movement." This routes lesson energy into the 23%-completion surfaces
instead of assuming workout intent the data says she doesn't have. Always pair with a quiet
secondary "done for today" — chain must be an offer, not a toll gate. If all rows are done,
fall through to (a).

**2. (a) Plain done → checklist — the floor, and the secondary action.** Honest, fast,
respects the checklist as the home of state. Never wrong; just leaves the momentum on the table.

**3. (d) Save-a-line — adopt in v2, but NOT as a last-page prompt.** As a terminal step it's
friction theater ("pick a sentence to leave"). As an **inline affordance** (long-press a body
line → subtle heart-mark, auto-saved) it's near-zero cost and creates the §1 v2 content asset
plus a Becoming module. The retention value is in the RESURFACING, not the saving — ship it
only with the resurfacing loop, otherwise it's a write-only journal (theater).

**4. (c) Micro-commitment ("tomorrow I'll...") — skip as a mechanic.** Implementation
intentions (Gollwitzer) work only when concrete (when-then) AND resurfaced at the moment of
action. A tappable chip that doesn't come back tomorrow is pure theater, and a free-text box
is abandonment. The day-14 lesson already does this in copy, which is the right weight. Only
revisit if the chosen chip can show up on tomorrow's checklist header — that's a v2+ system,
not a last-page button.

---

## 3. Re-read shelf

**Yes — and it's already built.** `JeniMethodReReadView` exists but lives behind Settings,
which is where features go to be forgotten. Move the entry to a **Becoming depth sheet**
(matches the steps-rail bento depth pattern; tabs stay reserved for program surfaces):

- Becoming bento tile: "her lessons" + progress fragment ("9 of 14") + the most recent
  lesson's headline. Endowed progress + collection display does the retention work even when
  re-read taps are rare — the shelf's job is identity ("I'm someone who's read 9 chapters"),
  not traffic.
- Reuse the existing view; only the row chrome needs the scrapbook pass.
- Fix while moving: in `isReread` mode the final page still renders "start today's workout"
  (handoff label is baked into the script). Re-read terminal CTA must read "done" — second
  instance of the §2 trust leak.
- Lock future lessons visibly ("day 12 · unlocks as you go") — visible-but-locked is the
  established pattern (Hard tier precedent) and adds an anticipation pull to the shelf.

---

## 4. Gain-framed continuity spec (no loss threats)

Constraint locks honored: no streak-loss framing, no broken-chain visuals, streak lives on
Becoming only, engagement-day is derived not stored.

- **Counter: "chapters read" — monotonic, can only go up.** Derive count of completed lessons
  (distinct lesson-completion engagement days) the same way `EngagementDayCalculator` derives
  programDay — computed, never persisted, self-healing. A counter that cannot decrease has no
  loss state to threaten with; this is the Finch model, and it fits the engagement-day design
  already in place (missing a calendar day never skips or punishes — keep that, it's rare and
  correct).
- **Display:** last page of every lesson gets one quiet line: "that's *12* mornings of
  learning." (italic-Fraunces on the number's word, per voice signals). Same number on the
  Becoming lessons tile. No flame iconography.
- **Weekly gain frame:** Becoming shows "3 lessons this week" — resets forward (a new week is
  a fresh opportunity), never shows last week's miss.
- **Milestones, not streaks:** soft celebration at 7 / 14 (chapter close, existing terminal
  event) / 30 / totalDays. Milestones are pure-gain by construction.
- Explicitly do NOT add: lesson-specific streak, "don't break it" copy, freeze tokens
  (nothing breaks, so nothing needs freezing).

---

## 5. Notification tie-in (≤5/wk cap)

The lesson is the cheapest open-driver because the payload is concrete and 2 minutes. The
best-performing daily-content pushes (Headspace Daily, Duolingo's non-guilt variants) share
three properties: **name the specific content, state the cost, never reference absence.**

Mechanic: the notification body should be the actual next lesson's `headline` — it already
exists per `LessonID`, costs nothing, and gives automatic variety (variable copy beats any
single optimized template; same finding behind template rotation at Duolingo scale). Budget
2-3 lesson nudges/wk inside the 5/wk cap, leaving room for the existing trial-week +
affirmation categories. Skip the nudge on any day the lesson was already opened
(`hasShownRitualToday` gate already exists).

Copy register (lowercase, no guilt, no "AI", no streak):
- "today's two pages: *sleep is where the change happens.*"
- "lesson 8 is short. one idea, two minutes."
- "a new chapter is up. it's about why one slip doesn't undo you."
- day-15+ review variant: "remember day 6? small beats heroic. quick revisit."
- weekly data variant: "your week in numbers is in. 4 walks, 2 weigh-ins."

Banned shapes: "you missed yesterday's lesson", "keep your streak alive", anything that
implies the app was waiting/disappointed, time-pressure ("last chance").

---

## Ship order

1. Fix the lying CTA (relabel or wire) + re-read terminal label — trust, same day.
2. Last page → chain-to-next-unchecked + "done for today" + chapters-read line (§2, §4).
3. Day-15 v1 review resolver + weekly numbers page (§1).
4. Becoming "her lessons" tile relocating the re-read shelf (§3).
5. Lesson-headline notification category, 2-3/wk (§5).
6. v2: Season 2 content + inline save-a-line with resurfacing (§1, §2d).
