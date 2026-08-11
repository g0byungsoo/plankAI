# THE NEXT ERA — investigation + decision (post-E3)

2026-08-11 · branch feat/app-v2 · E3 closed at `3f17d0d` (809/809 app ·
113/113 package). Method: STATE + E3 docs read → the founder's new
brief (day-one utility, MeAgain design reference, unisex continuation)
→ two deep code maps (food end-to-end; the new user's first 24 hours)
→ PostHog re-queried today → the QA sim walked at HEAD → MeAgain's 62
frames studied → one era chosen.

**Verdict in one line: the next era is DAY TWO — the product must turn
what a person does on day one into visible understanding the next
time they open the app, and food is the engine that does it.**

---

## 1 · WHAT THE DATA SAYS (PostHog 437953, re-queried 2026-08-11)

The standing number: 82% of onboarded users have exactly ONE active
day; 28 of 2,237 ever reach a second week. New queries sharpen it:

- **Day-0 food logging is the strongest return signal in the
  product.** Of 2,308 onboarded (≥14d ago), those who logged food
  within 12h of finishing onboarding returned later at **76.2%
  (32/42)**. Everyone else: **16.6%** (376/2,266). Correlational,
  selection-biased, and still the largest behavioral split we have.
- **Among payers (n=162): 26% logged food on day 0; 56% returned.**
  Food+returned = 67% vs 52% for non-food payers.
- **The capture funnel does not leak — the door to it does.** Day-0:
  78 saw the food-AI consent → 67 accepted → 42 started a scan →
  42 completed → 42 saved. **100% completion once started; 3.4% of
  onboarded ever start.** (Old build: food sat behind the wall.)
- **46% of all food loggers logged exactly one day** (38 of 82).
  The second logging day, not the first, is where food dies.
- **App opens spread across the day** (UTC histogram flat-ish,
  evening-weighted US). The "reveal" moment must anchor to *the next
  open*, not to a fixed morning hour.

## 2 · WHAT THE CODE SAYS (two full maps, 2026-08-11)

The day-1 → day-2 loop is broken at every joint. A user who logs two
meals and a weight on day one wakes up to exactly ONE acknowledgment:
a berry ring on yesterday's calendar cell.

Confirmed, with file:line evidence (see the maps in this commit's
message trail and 15_E4 §refs):

- **L1** The kept-promise celebration — the strongest first-win line
  in the product — is structurally unreachable (the letter presents
  before the plate exists; day-2 morning it checks TODAY's plates).
- **G1** Nothing on Home acknowledges yesterday: greeting is
  hour+name; the day-2 letter falls through every floor-gated clause
  to archetype boilerplate ("movement day").
- **L2** The evening "proud / okay / tender" answer: only "tender"
  is ever read back. Two of three answers are write-only.
- **L5** A day-1 weigh-in produces zero copy anywhere next morning.
- **J1** A plate logged through jeni (`log_food_text`) never marks
  the food beat or earns the kept ring — only the camera flow marks.
- **Corrections evaporate** (E4 gap-map G7 confirmed): fix-with-words
  works, then the correction text/delta is discarded. "Flywheel"
  appears six times in comments; nothing writes one.
- **`RecentMealsSheet` — a finished one-tap relog rail — is DEAD
  code** behind `--debug-again-sheet`. Production repeat logging is
  4-5 taps deep inside the book. (Evidence bar: repeat meals are the
  single highest-leverage logging feature — r2 §4.)
- **The vision EF gets zero user context**: `cuisine_profile` is
  threaded from onboarding to `CaptureFlowView` and dies there —
  never reaches the photo path, label path, or refine. No history,
  no priors ever sent.
- **The notification brain starves its own best pushes**: the anchor
  ladder stamps 5 ids and permanently vetoes `winback_lapse` (the
  D2 recovery push for the 82%) and loses `milestone_3` forever
  (veto returns before the done-flag). `lapse_support` can never arm
  (blocked by a default-ON toggle). `RecapNotificationService` has
  zero call sites. `recordIgnored` is never called.
- **Correction to the record:** the gap map's T2 ("THE BOOK has no
  door") is WRONG — the door exists (Becoming → your record → "your
  plates", `BecomingSummaryView.swift:1041`). The QA arg just needs
  `--uitest-start-tab becoming`. The real gap: the book is one
  scroll deep in a tab, and the evening-review push lands on the
  tab root, not the book.

## 3 · WHAT MEAGAIN TEACHES (62 frames, studied 2026-08-11)

Not copied — critiqued. What it gets right, and Jeni's translation:

1. **Capture is never far**: one global "+" opens every log action
   (food scan/search/barcode/voice · dose/weight/side effects) in
   ≤2 taps from anywhere. Jeni's scan tab already gives food ONE
   tap — the gap is *repeat* speed, not first-capture speed.
2. **The next event is a hero fact** ("6d 20h" to next dose in a
   ring). Calm, useful, glanceable.
3. **Direct-manipulation input** (weight ruler), **segmented scopes**
   on every chart, **native list rows** for settings — quiet iOS.
4. **Methodology one tap away** (ⓘ → plain-language method +
   sources). Jeni's provenance-in-words is the stronger version of
   this; keep it.
5. **Ingredient rows with include/exclude + macro chips** — legible,
   editable. Jeni's ledger is close; portion steppers are better.

What it gets wrong (and Jeni must not import): streak flame ·
capybara mascot/pet · the pseudo-quantitative "medication level
estimate" curve (provenance-illegal here) · 0-10 side-effect sliders
· community poll on Home · paywalled-widget lock icons · emoji as
data iconography · "100% activity" on zero data. The bento-of-cards
Home has no hierarchy of importance; Jeni's composed day is the
stronger idea — it just never speaks about yesterday.

Design conclusion: Jeni's editorial paper+ink identity is stronger
and stays. What this era imports is *ubiquity of repeat capture*,
*the next-thing-as-fact*, and *the reveal moment* (Oura's morning
read — r6's strongest retention pattern: passive data in, one
anchored reveal out).

## 4 · THE DECISION

### Era: **E4 — DAY TWO (the morning after).**

Named for the day the product loses 82% of its users. One sentence:
**everything a person gives Jeni on day N comes back as visible
understanding on day N+1 — starting with food, without a single new
engagement trick.**

Five builds, one loop:

- **B1 THE MORNING READ** — the first open of each day composes an
  honest read of yesterday from the record (plates · protein vs her
  floor · weigh-in · kept beats · her feeling word — every clause
  provenance-gated, n=1-honest) and ends in ONE action for today
  (MacroFactor law: a read ends in an action, never a summary).
  Rides the letter (DailyBriefEngine EVOLVED, not a new engine) +
  a quiet yesterday acknowledgment on Home. Fixes L1, L2, L5, G1.
- **B2 THE PLATE'S MEMORY** — the roadmap's E4 core, cut to day-one
  scale, zero EF deploy: `RecentMealsSheet` ships as the first-class
  "again" (≤3 taps from cold open); corrections PERSIST (entry
  payload, migration-free); a priors engine matches a new
  recognition against her corrected record and applies her numbers
  with a provenance line + one-tap revert; the cuisine-profile
  threading bug fixed so the EF finally hears the onboarding answer.
- **B3 LOOP HYGIENE** — chat-logged plates mark the beat (J1, one
  chokepoint); the past-day recap shows the whole day (food + kept
  beats + weight + feeling, R1); the evening push lands ON the book;
  `Route.trend`/`.weeklyRead` stop being swallowed; the book's QA
  door works from any tab.
- **B4 THE BRAIN, UNSTARVED** — the anchor ladder stops eating the
  whole budget (≤3 rungs); `winback_lapse` becomes reachable;
  `milestone_3` is no longer permanently lost on veto;
  `lapse_support`'s dead branch fixed; the day-2 anchor push carries
  the morning read's headline WHEN yesterday has a record ("2
  plates, 76 g protein — your read is ready"). No new pushes; same
  budget; better payloads.
- **B5 THE DESIGN PASS** — every surface this era touches meets the
  bar or is redesigned: the letter's morning-read face, the scan
  chooser + camera "again" affordance, the past-day recap, the
  becoming zero-state wall (13 "not enough to read yet" rows on day
  1 compress to one honest section), and the desk's consumer copy
  ("your coach between visits" renders for non-care users — G9
  verified in pixels today).

### Explicitly NOT in scope
- No EF schema changes; the ONE clarifying question (SnappyMeal,
  r2 §2) is E4.1, bundled into the already-gated food-vision deploy.
- No streaks, badges, fake urgency, new notification categories.
- No new tab, no new DB, no accuracy claims, no scores.
- Movement stays deferred (E3 decision D9 unchanged). Method
  untouched (D8 unchanged). Clinic UI untouched (E6).

## 5 · DECISION LEDGER

| # | decision | why | declined |
|---|---|---|---|
| D1 | DAY TWO before everything else | 82% single-day; day-0 food loggers return 4.6× base; every mechanic shipped so far needs a week | executing roadmap E4 as written (accuracy-first) |
| D2 | the reveal anchors to next-open, not a clock hour | opens are spread across the day (PostHog histogram) | a fixed 8am "morning report" push |
| D3 | the morning read EVOLVES DailyBriefEngine | chokepoint law; the letter already owns the daily sentence | a parallel MorningReadEngine beside it |
| D4 | priors apply client-side from her record, post-recognition, with provenance + revert | zero deploy, deterministic, SnappyMeal's memory result without a server change | injecting history into the EF prompt (needs deploy, non-deterministic) |
| D5 | "again" ships as the existing RecentMealsSheet, promoted | the surface is built and polished; evidence says repeat is the #1 logging lever | rebuilding a favorites system |
| D6 | ladder capped, winback freed, payload enriched — same budget | timely value not volume; the brain's law already says ≤5/wk | any new push category |
| D7 | becoming zero-wall compressed | 13 empty meters is the first Becoming impression for every new user | leaving it (honest but demoralizing) |
| D8 | book stays in becoming; pushes and routes point AT it | v23 information architecture holds; the wound was reachability, not location | a fifth tab / Home journal tile |

## 6 · WHAT WOULD VALIDATE OR FALSIFY (production, post-merge)

New instrumentation (hygiene-ruled, categorical): `morning_read_shown
/{clauses}` · `morning_read_acted` · `food_relog_used{surface}` ·
`food_prior_applied{kind}` · `food_correction_persisted`.

- **Confirm:** day-0 food share of payers rises off 26%; users whose
  first open of day N+1 shows a morning read with ≥1 record clause
  return on day N+2 at a higher rate than boilerplate-read users;
  repeat share of logs reaches ≥25% (roadmap bar); corrections per
  dish DECLINE over repeats (priors working).
- **Kill:** morning-read-with-record shows no return lift over
  boilerplate after the merge ships → the reveal is not the lever;
  look at activation into the first plate (B2's other half) or
  upstream (price, acquisition).
- **The gate above all of them, unchanged from E3:** none of this is
  measurable until `feat/app-v2` merges and ships.
