# app v5 — the experience pass (report)

Date: 2026-07-07. Branch `feat/app-v2`, commits 492c9c2…HEAD.
Evidence: `docs/app_v5/evidence/` (gitignored per screenshot policy —
on disk, not in history; SE set in `evidence/se/`, Dynamic Type XXL
in `evidence/xl/`, motion in `motion_tour.mp4` + the v4 archive's
breath/re-signing recordings which still bind). 194/194 unit tests.

## 1. The diagnosis (what was actually wrong)

v4 built the right skeleton — the arc, named weeks, the weekly
consented check-in, receipts-never-absence — and then wrapped it in
a private language. "the re-signing", "the plate story", "the trend
fed 3 times", "a plan you keep beats a plan you dodge", "the bend,
named". Onboarding feels premium because comprehension is instant
and the craft lands on top; the main app made her translate first,
so the same craft read as vagueness. Five compounding failures:
private language, text-as-only-material, double taxonomy (phase +
week + ordinal stacked three deep), trust leaks (day-one trend
claims, unit mismatches, unlabeled chips), and zero first-use
teaching. Full analysis: `00_DIRECTION.md`.

## 2. What changed (by surface)

**The reading (Today's opening line)**
- Day one now teaches the ritual: "welcome to day one. one small
  thing a day, i read the rest ♥ … today's is on the card below."
  The old day-one rendered the day-30 layout and (with any prior
  weight data) claimed "your trend line eased down this week."
- Trend language now requires 3+ weigh-ins spanning 5+ days
  (`trendIsEstablished` floor in TodayStateService → cascade gates
  on tiers 3 + 4). Two points a day apart can never claim a week.

**Today**
- "the plate story" → "today's plates"; empty state "your first
  plate sets up the day [snap it]"; suppressed-cohort line "protein
  is what matters today ♥"; zero-kcal line "the count starts with
  your first plate".
- Evening feeling chips sit under a visible question ("how did
  today feel?") — they floated context-free.
- Lesson rhythm rows carry their frame ("2 min · the inner critic
  has a script") instead of a bare lesson title reading as a claim.
- Plate thumbs 56×70 → 64×80; photo-less entries render as blush
  recipe-card minis (accentSubtle + jeweled serif initial) on Today
  AND the week pages — the week page previously showed dead grey
  icon boxes that read as broken thumbnails.

**Becoming / the journey**
- ONE header object: eyebrow "week 2 of 20 · finding steady" (+
  "44 days to go" appended past the midpoint — the Koo & Fishbach
  flip moved here), ribbon, one intent line. The 22pt repeated
  phase title died; "finding steady" no longer appears three times
  on one screen. `ProgramArc.leadLine` retired (dead code + tests).
- The trend story speaks her unit: "the line eased down about 1 lb
  this week" (was "about 500g" over a lb headline), and no longer
  stitches an unrelated insight's caption beneath itself (the
  `?? cards.first?.detail` fallback died).
- "trend · sixty" → "trend · last 60 days" / "last 90 days" / "the
  whole line". "the weeks" → "past weeks".
- Week cards: today's dot finally renders distinct (the passthrough
  never marked it), and each card closes with the week's EMA delta
  ("−0.8 lb" / "steady") in neutral ink — same source as the canvas,
  ≥3 in-week points required.
- "the pattern is the product. everything else compounds from it."
  → "that's the number that predicts the rest."

**The weekly check-in (mechanics untouched)**
- Surface renamed "your weekly review" (the dateline said "the
  re-signing" — the ritual's most private words at its most
  important moment). Cascade, dots, consent verbs, stamps all stay.
- Week stories: "2 plates logged · weighed in 3 times", never "the
  trend fed". Quiet week: "a quiet week. it still counts."
- Proposal reasons lead with her facts: "the plan asked for 4 and
  the week said no. a smaller plan you keep beats a bigger one you
  dodge." / "90g landed 1 of 6 days. a floor you can reach beats a
  noble one." Titles: "you pick next week's focus" (was "lane").
- "the bend, named" week → "the plateau week".

**Day receipts**
- Plain lines with the metaphors retired: "plates logged", "moved",
  "the method, done", "one breath session", "steps goal reached".
  The weigh-in line yields to the weight row (which carries the
  number) instead of duplicating it as "the trend fed".
- Today's receipt says "today is still being written." — it wore
  "a quiet day" as a verdict on a day still open (v4's own law,
  now actually enforced).

**Jeni tab (the coaching moment)**
- The transcript reads as dated letters: quiet seams ("yesterday",
  "monday, july 6") open each day's group, and each new day's
  letter is signed with the JENI kicker again.
- The deterministic reading no longer seeds itself twice verbatim
  on consecutive held-trend days (letters don't repeat themselves).
- Starter chips (already state-aware) now show whenever she hasn't
  spoken today — the `count <= 1` gate buried them forever after
  one day of history. First-open now offers three doors instead of
  55% dead cream.

**Breathwork**
- The bloom takes the stage: 360pt field, petal radii +14%, wider
  warmer atmosphere (0.38×, alpha .19), petal alphas +0.05, firmer
  cocoa still-point. It read as a small washed blob floating in
  cream. Clock math, haptics, words, dots untouched.

**Steps**
- Sheet line speaks numbers: "3 of 7 days reached 7,500. the
  easiest lever, working." Low days get the honest science: "the
  benefit starts far below 10k. that number was marketing."

**Motion**
- Tab arrivals settle with the 4pt rise the MainShell comment
  always promised (offset+opacity only, reduce-motion gated) — the
  code had gone flat.

**Workout completion, the rep, snap carousel** — verified live and
left alone: "kept." + fact rows + one feeling question; the rep's
scenario→door→response→"kept. it's on today ♥" chain; the camera
and result carousel. These already meet the bar.

## 3. How it teaches now (no tutorials)

Day one: the reading explains the whole contract in one line and
points at the card. Empty states invite the first action in plain
words (plates, trend, jeni, archive). The week ribbon names her
week from day one. Everything else is learned by receipt — do a
thing, watch it become a fact everywhere (today's plates → week
page → day receipt → weekly review → jeni's context).

## 4. Evidence index

- `a1_day1.png` — day-one teaching reading, ribbon, one thing
- `a1_day12_scrolled.png` / `a1_day12_evening.png` — today's
  plates + labeled evening close
- `b2_becoming_final.png` — one-header journey, unit-correct story,
  week-card delta
- `b1_review_d15.png` — your weekly review, facts-first
- `b1_weekpage_d5.png` — plain week page + recipe-card minis
- `c1_jeni_tab.png` — dated letters + starter chips
- `0*_breath_*.png` — the bloom at presence, receipt copy
- `0*_rep_*.png` — the rep chain (verified, untouched)
- `4*_*.png` — signed review, journey arc at week 3, week page,
  day receipt (today = "still being written")
- `v_postroutine.png` — kept receipt (verified, untouched)
- `se/` — SE 375pt: day one, becoming, review (no wraps, no clips)
- `xl/` — Dynamic Type XXL: today + becoming (graceful wraps)
- `motion_tour.mp4` — tabs/note/journey walk on the final build

## 5. Deliberately left alone

Engines and math (arc/week/review/band/presence), schema, EFs,
RevenueCat/paywall/gating, notification protocol, onboarding v5,
snap capture + carousel, the reader's long form, the workout
player, chat engine + her-file mechanics, the three-tab IA and the
tab names (today / jeni / becoming are learn-once proper nouns; the
insides now speak plainly).

## 6. Honest remaining gaps

1. **Jeni tab dead space** on short histories (bottom-anchored
   scroll) — fills as letters accrue; a top-anchored short-history
   layout is a contained follow-up.
2. **Quiet-day receipts** are one line in a full-height page — the
   today-verdict is fixed, the density isn't. Candidate: medium
   sheet detent for day receipts.
3. **Week-name copy**: "the early read", "the fresh angle", "kept,
   quietly", "naming your settle" survive (their intent lines carry
   them); only the worst ("the bend, named") was renamed. A
   founder-taste pass on the full name table is cheap.
4. **The seeded QA user shows "snap your first plate"** occasionally
   on relaunch (seed hydration race in the harness, not product).
5. Inherited from v4 unchanged: BreathHaptics needs a device pass;
   snap E2E motion needs the deployed food-vision EF + real camera;
   the widget; earlier-weeks seam doesn't expand; day receipts
   don't reconstruct that morning's reading; re-signing knock fixed
   at 19:00; rep content at 16 scenarios (founder-present work);
   PostHog dashboards for journey events.
6. **Post-purchase → first Today transition** not redesigned this
   pass (onboarding fence).
