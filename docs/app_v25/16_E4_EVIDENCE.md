# E4 DAY TWO — evidence (the loop's record)

2026-08-11 · what is PROVEN, how, and what remains. The decision in
`14_E4_DECISION.md`; the law in `15_E4_DAY_TWO.md`. Frames are
session-ephemeral by standing law; the observations here are the
durable record.

---

## 1 · PROOF LEDGER

### PROVEN IN TEST — app suite green (zero regressions at every gate)

New pins:

- **`MorningReadTests` (25)** — the receipt exists only when
  yesterday left a record and never on day 1; numeric suppression
  strips numbers, keeps words; a weigh-in alone earns a receipt (L5);
  the day-two clause reads the file back and falls through when
  nothing was logged; the held floor is named without judgment (no
  "only", no "missed"); a zero-protein plate never prints "0g"; the
  clause retires after week 1 while the receipt keeps riding;
  suppressed cohorts never get the numbers clause; tender and
  comeback outrank the read; the first weigh-in earns "your line is
  forming" and an established trend drops it; **"proud" is read back
  after four eras of being write-only** and never overwrites a real
  second sentence; "okay" stays a receipt word; the kept promise
  outranks everything; **prose and ledger never say the same numbers
  twice** (frame-caught, then pinned).
- **`PlatePriorsTests` (12)** — normalize strips case + "+ N more";
  only corrected rows build priors; the latest correction wins;
  application scales the whole plate coherently to her number;
  agreement within ±15% leaves the plate alone; no prior no touch;
  barcode is printed truth; a 3× absurd factor refuses; never applies
  twice; revert restores the model exactly and is inert without a
  prior; corrections ride the rebuilt plate through the edit session.

### PROVEN IN SIMULATOR (QA-iPhone16, frames inspected)

1. **THE MORNING READ, day 2.** Seeded day-2 morning: the letter
   reads *"your file started. 5 plates yesterday. about 206g protein
   on record. today's floor is 90g."* over the jeni dateline. The
   first version repeated the numbers in the ledger row directly
   beneath the prose — frame-caught, de-dup law added, re-filmed
   clean.
2. **THE DAY-TWO LOOP, walked by a machine** (`testDayTwoLoop`,
   green): the again sheet opens → ONE tap relogs "chicken poke
   bowl" → **Home's food row carries the filled check without the
   camera ever opening** (J1 in pixels), the strip's today cell
   earns its mark, the ring re-counts 1,660 → 2,180, the tools tile
   reads "5 plates today" → becoming → "your plates" opens THE BOOK
   ("27 plates since july", the protein-led week band leading).
3. **THE CHOOSER'S THIRD DOOR.** "or log a recent plate again" sits
   between the doors and the close — pill grammar matching the
   camera's "or write it", present only when a plate exists.
4. **THE AGAIN SHEET.** "add it *again*" serif header, hairline
   rows (title · kcal · protein · relative day), one-tap plus,
   "kept ✓" beat. The dead-heart remnant (an empty Text after the
   v22 heart sweep) replaced with a drawn check.

### REQUIRES FOUNDER ACTION — §4

### REQUIRES PRODUCTION OBSERVATION

`morning_read_shown{clause, has_receipt}` ·
`food_relog_used{surface}` · `food_prior_applied{kind, action}` ·
`food_correction` persistence rate — all registered, hygiene-ruled,
none fired for a real user. Nothing in §5 is claimable today.

---

## 2 · ADVERSARIAL LOOPS

| state | behavior | held by |
|---|---|---|
| unlogged yesterday | no receipt, no clause — absence, never zero | pinned ×2 |
| day 1 | no receipt (no yesterday in-program) | pinned |
| numeric-suppressed cohort | receipt words only; numbers clause never fires | pinned ×2 |
| away ≥2 days | comeback outranks; receipt naturally empty | pinned |
| tender evening | claims the whole morning; read yields | pinned |
| 0g-protein plate | never prints "0g" | pinned |
| onboarding weight seed | never a weigh-in | assembly filter, pinned via L5 tests |
| barcode / label / describe | priors never touch (printed truth / her words / the correction channel) | engine guard + dispatcher scope, pinned |
| model agrees ±15% | plate untouched, no revert chip | pinned |
| family-size prior vs slice scan | 3× clamp refuses | pinned |
| correction after a prior | prior dissolves — her words outrank her old numbers | SnapRefine seam |
| plate deleted to zero | changeNotifier guard never marks the beat | code guard |
| relog with the capture cover open | listener yields to the flow's own dismiss handler | activeCover guard |
| becoming route with today mounted | Home returns early; becoming consumes | code + walked |

---

## 3 · FRAME-CAUGHT FIXES (the loop working)

1. **The letter said the same numbers twice** — prose read "5 plates
   … 206g protein" with the ledger row repeating both beneath it.
   De-dup law: on read-claiming clauses the row keeps only what the
   prose didn't say. Pinned.
2. **The leg's assertion was stale, not the product** — once marked,
   the food row drops its "N plates logged" subtitle; the assertion
   moved to the tools tile's live count.
3. **A "kept ✓" beat replaced a dead heart** in RecentMealsSheet (an
   empty `Text("")` left by the v22 heart sweep).
4. **"cal" → "kcal"** on the again rows (one unit word everywhere).

---

## 4 · FOUNDER GATES

E4 adds **no migration** (corrections ride the payload jsonb; the
JSONL decodes old rows tolerantly; `recentMeals`/`relog` were already
shipped code).

1. Standing and unchanged from E3: **deploy `jeni-chat`**, **deploy
   `food-vision`** (its prompt still says "gen-z women" in production
   until then), apply `20260809090000` + `20260810090000`, key
   rotation, archive/TestFlight 1.2.0 (30), **merge feat/app-v2 →
   main**, device walk.
2. **E4.1, bundled into the food-vision deploy when it happens**: the
   ONE SnappyMeal clarifying question (r2 §2) — schema + prompt in
   the same founder-gated push. Nothing in this era depends on it.
3. **Device walk for this era**: a real relog from the chooser on
   hardware; the morning-after push payload on a lock screen; a real
   correction → next-day same-dish scan → the "your numbers" row.
4. **PostHog after release** (§5).

---

## 5 · WHAT WOULD VALIDATE OR FALSIFY

Recorded in `14_E4_DECISION.md` §6 before the build:

- **Confirm:** day-0 food share of payers rises off 26%; mornings
  with `has_receipt` return next-day at a higher rate than
  boilerplate mornings; repeat share of logs reaches ≥25%;
  corrections per dish decline over repeats.
- **Kill:** receipt-mornings show no return lift after the merge
  ships → the reveal is not the lever; the answer is upstream.
- **The gate above all of them, unchanged:** none of this is
  measurable until `feat/app-v2` merges and ships.

---

## 6 · KNOWN LIMITATIONS + DEBT

- **QA cloud pollution**: `--uitest-inapp-qa` signs into a
  deterministic account whose cloud tables now hold every seed this
  session pushed; even `simctl erase` restores them on hydrate. The
  compressed becoming zero state is therefore **code-verified but
  not re-filmed** (this morning's pre-seed frames show the old
  13-row wall it replaces). A QA-side wipe door (or a per-run anon
  account) is the fix — named, not built.
- The morning-rung push carries plate count + protein composed at
  schedule time; a plate logged after the last refresh of the
  evening still updates it only if the app wakes again. Honest
  limitation of local scheduling; the copy claims nothing timed.
- Priors match EXACT normalized titles only — "chicken burrito" and
  "chicken burritos" are different dishes. Deliberate (fuzzy match
  invents memories); revisit only with production evidence.
- `RecentMealsSheet` surfaces 6 recents, newest first — no pinning,
  no search. Deliberate scope.
- Beyond-XXXL accessibility remains the app-wide named debt.
- The kept-promise clause still requires `day1PromiseAction` — users
  who skipped the post-purchase promise get the day_two clause
  instead. Correct, noted.

---

## 7 · TEST COUNTS + DOORS

- Era opened **809/809 app + 113/113 package**; closes **830/830 app
  + 125/125 package** (+21 app, +12 package, zero regressions).
- New doors: `--uitest-open-again-sheet` · `--uitest-seed-week` (now
  a launch door) · `--uitest-open-food-journal` (works from any tab)
  · walker leg `testDayTwoLoop`.
