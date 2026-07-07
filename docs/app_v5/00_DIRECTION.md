# app v5 — the experience pass (direction)

Date: 2026-07-07. Branch `feat/app-v2`. Founder brief: fresh in-app
UX/UI reimagination; make the main app as premium as onboarding or
better; simple, direct, feminine, premium, alive in motion; solve
the deeper problem, not the wording.

Inputs: v4 report + evidence archive, four code maps (Today/shell,
Journey/re-signing, engines/interiors, design system/onboarding
vocabulary), my own simulator walk (16e + SE: day 1, day 5, day 12
morning/evening, becoming, week page, day receipt, jeni tab,
re-signing, breath entry/session frames, launch ritual frames).

v4's structure (arc, named weeks, weekly check-in mechanics,
receipts-never-absence, provenance) is right and stays. This pass
rebuilds the EXPERIENCE LAYER on top of it: language, visual
material, hierarchy, first-use teaching, motion, moments.

---

## 1. Diagnosis (why the main app trails onboarding)

1. **The app speaks a private language.** "the re-signing", "the
   plate story", "the trend fed 3 times", "a plan you keep beats a
   plan you dodge", "the pattern is the product", "the bend, named".
   Onboarding asks plain questions, so its beauty lands instantly;
   the main app makes her translate before it can feel premium.
   Copy points at the SYSTEM's metaphors instead of HER facts.
   Evidence: every walk capture; re-signing captures; day receipt.
2. **Text is the only material.** Every main surface is typography
   on cream; the only images are 24px pastel icons and gray
   placeholder plate thumbs. Onboarding has rulers, strikes, photo
   cards, a live camera demo. Data never becomes an object she can
   look at. Evidence: walk_03/04/07; week page gray boxes.
3. **Double taxonomy + repetition.** Phase name ("finding steady") +
   week name ("the arriving week") + week ordinal stack on one
   screen; becoming said "finding steady" three times; the jeni tab
   opens with the same reading twice (dated-echo render).
4. **Trust leaks on day one.** The reading claims trend movement
   before enough weigh-ins exist to claim anything; "6 kept" can
   exceed the day count (seed artifact but a real display class);
   feeling chips render with no question above them; "trend · sixty".
5. **Nothing teaches.** Day 1 renders the day-30 layout minus data.
   No in-flow first-use voice; empty states describe rather than
   invite.
6. **The evening close is a form.** Chip stacks with no receipt
   moment, no closure gesture.
7. **The jeni tab wastes its moment.** ~55% dead space, duplicate
   reading, no state-aware conversation starters.
8. **Motion exists but rarely guides.** Two-beat entrance is
   everywhere (good); the re-signing cascade and breath bloom are
   genuinely premium; but tab swaps are plain crossfades, the
   journey opens with no sense of travel, completions barely land.
   The breath field reads small and washed against the cream.
9. **List grammar dominates.** Week page = 7 chevron rows; ledger =
   stacked text cards; evening = chip stacks. Calm is right;
   undifferentiated lists are not.

## 2. The organizing principle

**One program, spoken plainly, shown beautifully.**

- Direct first; poetry only as the punch word, never as the noun.
  Every screen answers its one question in words a 24-year-old
  reads in two seconds.
- Her facts over our metaphors: "you weighed in 3 times", never
  "the trend fed 3 times".
- Data becomes objects: plates are photos, protein is a filling
  arc, the week is seven breathing dots, the trend is the drawn
  line. Rich through interaction, not density.
- Proper nouns she learns once (today / jeni / becoming / her
  plates) stay; everything inside them is plain.
- Teach in her voice, in flow, once: day-1 reading explains the
  ritual; empty states invite the first action; no tooltips.
- Numbers only where provenance exists (unchanged law).

## 3. Surface decisions

- **Today** — job: "what do I do now, how's today going?"
  Masthead + ribbon stay; reading gets a day-1 intro thread and a
  data floor before trend claims; one-thing card stays; rhythm
  subtitles become plain ("2 minutes · one scenario", lesson topic
  in plain words); plate story renamed "today's plates", photo-first
  strip, protein ring + kcal sentence kept (best line in the app);
  evening = receipt first, labeled question ("how did today feel?"),
  tonight plan kept, then quiet rows.
- **Becoming (the journey)** — job: "where am I in the plan, is it
  working?" ONE header object (ribbon + "week 2 of 20 · finding
  steady" + intent line, no repeats); trend canvas hero with plain
  badge ("last 60 days", direction word + weekly delta); this-week
  card = live receipt (dots + facts); past-week cards get a visual
  spine (dots + delta + plates); filler aphorisms die; doors named
  plainly.
- **Week page** — plain summary line ("2 plates logged · weighed in
  twice"), tappable day rows stay, plates strip with real thumbs +
  proper placeholder.
- **Day receipt** — receipts with numbers ("2 plates · 62g protein",
  "moved 12 minutes", "8,200 steps"), that morning's reading read
  back when available, compact sheet for quiet days.
- **Weekly check-in (the re-signing mechanics unchanged)** — facts
  first, plainly: "you kept 3 of 4 workouts. next week starts at
  3." Consent verbs stay ("keep it" / "not this week"). The cascade
  + consent thunk stay.
- **Jeni tab** — opens as today's letter (dated card, letter
  register) + her file + 2-3 state-aware starter chips; the echo
  duplication dies.
- **Food** — plates photo-first everywhere; placeholder becomes a
  drawn plate mark, never a gray box. Snap capture/carousel
  untouched.
- **Weight** — canvas mechanics stay; label + badge speak plainly;
  first-weigh states stay.
- **Steps / breath / method / workout completion** — registers
  kept; subtitles and value lines made direct; breath field gains
  presence (larger, deeper center, chrome recedes); completion
  receipts keep numbers.
- **First-use** — day-1 reading teaches; empty states invite; one
  whisper line under new rows on their first render only.
- **Motion** — one page-transition grammar app-wide; ribbon→journey
  continuity; plate-land and weigh-in moments land visibly;
  completions sweep once. Haptics: every state change she causes,
  nothing she didn't.

## 4. What deliberately stays

Engines, schema, EFs, RevenueCat/paywall/gating, notifications
protocol, snap capture + carousel, onboarding v5, the reader's
long form, BandModel/PresenceLedger/BreakState, chat engine + her
file mechanics, the arc/week/check-in math, receipts-never-absence,
cohort numeric suppression.

## 5. Passes

A. Language + trust (copy sweep, day-1 reading, data floors,
   labeled questions, plate placeholder, display clamps).
B. Today (plates module, rhythm subtitles, evening close, whispers).
C. Journey (header, ledger cards, week page, day receipt, doors).
D. Jeni tab + check-in copy + interior touch-ups.
E. Motion/haptic cohesion + SE/Dynamic Type + evidence sweep.

Each pass: build once, screenshot, commit. Evidence in
`docs/app_v5/evidence/` (gitignored), decisions logged here.

---

## 6. THE RE-STEER (founder, 2026-07-07): the story rebuild

Passes A–E improved the old structure; the founder wants the
structure itself rethought. Verdict accepted: becoming still reads
as a dashboard/ledger; Home still reads as old-Home-improved. The
onboarding demo surfaces are the bar: one idea per screen, one
large visual that speaks instantly.

**Becoming = a swipeable insight story.** A horizontal pager of
near-full-screen pages, one insight each, jeni walking her through
her own body and plan:

1. weight — the trend canvas as hero, the insight sentence as the
   headline ("the line eased down about 1 lb this week.")
2. food — one big protein arc + the week's protein fact; her-plates
   door lives here now
3. movement — the week's step rhythm, large; the gentle-floor fact
4. this week (plan) — the week's name + large day dots + arc ribbon
   + signed stamp + the review re-offer; "her weeks" door
5. the band (keeping chapter only) — maintenance as its own page
6. from jeni — the reflection letter (pattern insight or the
   reading), talk-it-through door, the practice door

Page grammar (JKStoryPage): eyebrow → serif headline (the insight,
plain words) → large visual → caption → quiet doors. Custom page
dots; soft haptic per turn; the canvas draw-in fires on arrival.
No grids, no stacked cards, no vertical ledger at the top level.

**Home = a calm command center.** Masthead → THE DAY RAIL (new: the
program week as seven tappable day cells — weekday letters, state
dots, today as a filled numbered pill, dotted future; caption
"finding steady · week 2 of 20 →" opens becoming; past cells open
day receipts) → jeni's note → THE ONE THING → quiet rhythm rows →
plates memory strip with a one-line day answer (the big ring moves
to becoming's food page). The rail is the calendar-strip answer,
returned to the top of Home as a designed object.

**Plan history = her weeks**, one level in: a full-screen timeline
behind the plan page (this week + past week receipt cards + quiet
seams + the future shape at the foot). The ledger relocated and
demoted, not deleted — history on demand, story up front.

Failure standards adopted verbatim: becoming must not feel like a
dashboard; Home must not feel like old Home; the plan over time
must be visible; one insight per screen; onboarding-parity premium.
