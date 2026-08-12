# E7 — SAY IT: the record

2026-08-11 · `feat/app-v2` · rides RC 1.2.0 (30) · no migration, no EF
deploy, **no paywall change**. The decision + hypothesis are in
`20_E7_DECISION.md`, written before any code.

---

## 1 · WHAT SHIPPED

**THE DOOR IS WORDS.** `ScanChooser` stops asking a camera question.
"what did you eat?" over a field, with today's protein standing under
it. E5's two big doors survive at full size (§4.1). One tap from the
tab bar to a keyboard; her own return key goes straight to the
estimate. `AppRouter.Route.foodDescribe` gains `spoken:` so words the
USER typed submit through, while jeni's own prefill (E3) still opens
the field and waits — words she authored are never submitted on the
user's behalf.

**PROTEIN LEADS.** The reading's hero was a 2×2 grid opening on
CALORIES: largest numeral, the only ring, captioned "37% of today".
`00_THE_SYSTEM` §9 says the opposite, and §7.6 says why (protein
1.2-2.0 g/kg is one of exactly two proven GLP-1 content pillars; lean
mass is 25-40% of drug-induced loss). Protein now takes the full width
and the day's floor as its denominator. The kcal ring is **deleted**,
not moved.

**THE ANSWER.** "add it" used to dismiss the sheet. The grid now
becomes one true sentence in its own real estate, then files.
`PlateAnswerEngine` is pure, table-driven, and reads the same
`TodayStateService` / `TargetsService` inputs every other surface
reads — one engine, two moments, so the question and its answer speak
in one voice.

**THE READING, REBUILT AROUND THE FOUNDER'S ASKS** (§3).

## 2 · THE LOOP, IN GESTURES

| | before | after |
|---|---|---|
| log a meal in words | tab → chooser → "a meal" → camera → "or write it" → type → add it → reading → add it | tab → type → return → reading |
| what the reading leads with | calories, with a ring and a % | protein, with the day's floor |
| what happens on "add it" | the sheet dismisses | the grid becomes a sentence, then files |
| what the capture surface knows | nothing | where today's protein stands |

## 3 · FOUNDER STEERS TAKEN MID-BUILD

Five, all in-session, all shipped:

1. **"these options better to be pill options so we can save space +
   make it signal that its clickable"** — the side-effect logger's 13
   full-width rows became a wrapped pill cloud. ~590pt → ~250pt, and a
   capsule is the one shape in this system that always means "tap me".
   The severity picker follows the cloud instead of splitting it
   (inline expansion in a wrap layout would reflow every pill after
   the open one, moving words under her thumb as she read them).
2. **"many pop ups ... are out of space and should be scrolled / or
   full screened"** — `JeniSheetHeight` (`.tall` 0.68 · `.brief` 0.42 ·
   `.tallFixed`) replaced `.medium` (a system detent pinned at HALF the
   screen) across 15 call sites. One token, not a dozen hand-picked
   fractions.
3. **"i like this better"** (E5's chooser vs this era's first cut) —
   the pill-based cut was discarded and E5's two big doors restored at
   full size, with the field added ABOVE them. The founder was right on
   craft: shrunk to 38pt marks the art stopped carrying information.
4. **"maybe use pie chart instead of bar charts ... to utilize the
   space better"** — one donut replaced FOUR objects (three per-cell
   bars plus the full-width split bar). Half the height, more
   information: the legend carries the grams the bars only implied.
   The denominator is the PLATE's own energy, never a daily budget —
   the donut answers "what is this made of", the protein lead above it
   answers "where does the day stand", and keeping those in separate
   objects is what stops the reading becoming a scorecard.
5. **"want to see fiber + sugar + sodium info + vitamin / mineral info
   as well"** — fiber/sugar/sodium were already computed and were
   being sheared in half by the footer. The vitamins were a real find:
   **`USDAClient` has parsed ten micronutrients since v1.0.9 and
   `CalorieMathService.compute` dropped them on the floor**, so a
   USDA-grounded plate knew its own vitamin C and could never say so.
   Carried through now (`CapturedItem.micros`), no EF deploy needed.

   The honesty rules, because this is where a nutrition app usually
   starts lying: zero means UNKNOWN, not "none"; a described meal that
   never touched USDA shows no panel; no percentages — the daily value
   only *ranks* which four are worth naming, the grams are what render;
   never "low", never "deficient", never red.

## 4 · WHAT I EXPECTED TO MATTER AND DIDN'T

- **The desk's ~150pt of dead space** (E6 §6.4). Real, captured,
  cosmetic. The desk is a surface she has to go to; the capture moment
  is one she is already in. Fixing the desk would have polished the
  wrong end of the loop.
- **MeAgain's medication-level curve.** Their best object, and Jeni
  must not build it — v24 §11 and `00_THE_SYSTEM` §9 both already
  refuse PK curves on provenance grounds. Refused again, on purpose.
- **The chooser's art.** E5 fixed the art. The chooser's problem was
  its *question*.
- **"QA cloud pollution surviving simctl erase"** — the debt E4 and E6
  both recorded. It was never the cloud (§5.2).

## 5 · WHAT THE WALK CAUGHT

`SayItWalkUITests` (4 legs) drives the loop for real. Four defects, none
of which a screenshot would have found.

**5.1 The steps detail's ring was a Metal shader.** `iridescentRingFlow`
swept deep rose → coral → **peach-gold** around the ring at 30fps — the
only object in the app painted outside the eight locked tokens and
outside the rose ramp v21 made the data language. Reported off-palette
twice (`19_E6` §6.1) and left standing both times. One colour now, the
same rule every other ring follows: dusty under the goal, berry over
it. The shader function is deleted; this was its only caller.

**5.2 The wipe door never worked, and three eras had the reason wrong.**
`--uitest-wipe-food` was recorded as blocked by "QA cloud pollution
that survives `simctl erase`". It is not. **`--uitest-seed-program`
writes two plates further down the same launch task**, and the two
flags are almost always passed together, so the wipe was undone within
the same launch. The seeder yields now. (The wipe was also scoped to
`auth.currentUser`, which a cold launch has not resolved, so it failed
OPEN and silently — it clears the device's whole food store now, and
traces that it did.) Empty-state faces are filmable for the first time
since E4 named the debt.

**5.3 The chooser overflowed under the status bar** with the keyboard
up — the serif question sat behind the clock. Three passes to fix: a
content margin moved it 25pt; wrapping the whole ZStack inset the scrim
and exposed a band of un-softened page; the answer is a bottom-anchored
scroll on the GROUP, inset by the window's own safe area. And while she
types, the again door and the close step back — the keyboard costs
~330pt, tapping outside already dismisses, and the two big doors are
the alternatives worth keeping in view.

**5.4 My own tests lied twice.** A `CONTAINS '0 g of protein'` matcher
fired on "9**0 g** of protein"; the reading leg asserted the grid six
seconds after launching with `--uitest-file-plate`, by which time the
answer had correctly replaced it. Both rewritten. An assertion that
fires on prose it should allow teaches the next person to delete it.

## 6 · WHAT FRAME REVIEW CAUGHT

Recorded at 12 and 20fps, dumped, inspected neighbour by neighbour.

1. **The answer cross-faded ON TOP of the half-faded grid** for ~80ms —
   two type sizes of the same words overlapping, exactly the "pop" this
   era set out to hunt. Now two phases: the grid leaves (0.22s), the
   sentence arrives into the space it vacated (spring 0.42/0.84).
2. **The "add it" pill greyed out** while the answer showed — a
   disabled primary reads as a failure state on the one beat meant to
   feel like completion. The chrome fades with the rest instead.
3. **The reading's last row sheared in half** against the scroll view's
   own clip. A soft bottom edge dissolves the overflow, so "there is
   more below" reads as an invitation rather than a rendering fault.
4. **`TextEditor` swallowed ~380pt** of QuickAdd — it is greedy
   vertically and was unbounded, opening a void on a screen whose
   entire argument is speed.
5. **The calories cell sat shorter than its neighbours** once its ring
   was deleted, reading as unfinished.
6. **"123 of 90 g" read as a typo** once the floor was met. Below the
   floor a ratio is a position; at or above it, it stops being the
   interesting fact — so it stops being said.
7. The describe header's **question mark inherited the heart's rose**
   and read as a colour bug.

## 7 · VERIFIED

- **890/890 app** (+20 this era) · **125/125 package** · **4/4 walk** ·
  zero regressions.
- `PlateAnswerEngineTests`: 20 assertions. The honesty table row by
  row, plus the refusal set (verdicts, praise, blame, percentages,
  em-dashes, hearts, exclamation marks, case) asserted across a
  **200-input cross-product**, plus the rule that matters most — no
  denominator ever renders without a floor on file.
- The answer morph filmed and inspected frame by frame through the
  same `fileIt()` the button fires.
- The zero state, the keyboard-up state and the floor-covered state all
  captured in the walk's own screenshots.
- **The paywall is untouched.** `git diff` over `PlankApp/Views/Paywall`,
  `PlankApp/Payment`, `AppPhase.swift`, `WallView.swift` and
  `Views/FirstPlate` is empty for this era. `e5.firstPlate.enabled`
  still defaults false.

## 8 · UNISEX AUDIT

**Measured, not asserted** — `20_E7_DECISION` §7 has the numbers. The
headline: **62 of 84 lessons (74%) in `manifest_v1.json` carry
female-coded language** (63 page headlines, 69 page bodies), and the
`voicePlaybook` authoring rules are gendered too, so any new lesson
inherits the defect. Act III's signature form is literally *"a woman
who [chose] her 20"* — an identity line the reader is invited to
inhabit, on a product that is no longer women-only and whose method
library is the #2 activity.

**Not fixable inside this era** and deliberately not attempted:
rewriting 74% of a therapeutic corpus is an era of its own, and the
Method's fate (dispersal vs retirement) is an open roadmap question
that should decide the voice before the rewrite. Sized here so it can
be scheduled instead of re-discovered a fourth time.

**Fixed this era:** the food rail's own copy swept (clean), the new
surfaces written unisex from the start, and `food-vision`'s authoring
comment de-gendered ("reads the plate WITH her words" → "with those
words"; a comment, no behaviour change, no deploy needed).

**Preserved on purpose:** study populations stated as such —
`BreathworkProtocols`' "n=40 women", the 2016 image-feed review's
"young women", Alleva & Tylka's sample. And `jeni-chat`'s system prompt
keeps the word "woman" inside the anti-gendering rule itself ("never
write to a generic woman, never write to a generic man"), which is
correct.

## 9 · WHAT IS STILL BELOW THE BAR

1. **The Method corpus** (§8). 62 lessons. The largest single debt in
   the product.
2. **Method + breathwork photography** is female-only. An asset
   library, not a copy pass.
3. **The workout library** — ~128 `woman-doing-X` animations, 100%
   female-presenting, reached by 203 users/90d. Roadmap E3's kill,
   deferred a third time.
4. **Home's hero carousel still opens on `.calories`** and reaches
   `.protein` only on a swipe. The same law E7 fixed in the reading is
   still inverted on the most-seen surface in the app. Left alone
   deliberately: Home is not in this loop, and re-ordering a paged
   carousel that other surfaces deep-link into is its own change with
   its own frame review. **This is the first thing to fix next.**
5. **The desk's dead space** (E6 §6.4), unchanged.
6. **The describe path's picks rail** bleeds a chip off the screen
   edge. Correct for a scroll rail, but it reads as clipping in a
   still.

## 10 · WHAT SHOULD BE MEASURED IN PRODUCTION

Nothing here is measurable until `feat/app-v2` merges — now seven eras
deep. Post-merge, in priority order:

1. **The falsification condition itself.** `food_log_created` within
   24h of `purchase_completed`, split by source (`quick_add` vs
   `photo`). E7 dies if the day-0 rate does not move AND the words path
   takes a minority of entries.
2. **The accuracy trade.** `FoodCorrectionSheet` open-rate on
   describe-path readings vs photo readings. Words buying speed at the
   cost of trust is the one trade this product cannot make.
3. **Scan-start rate** (`3.4%` today) — the number this era attacked.
4. Micronutrient coverage: what share of logged plates carry a
   non-empty `micros` set, which tells us how often the new panel can
   speak at all.

## 11 · FOUNDER ACTIONS

The standing set carries forward unchanged: apply the v24 + E1 + E2
migrations · deploy `jeni-chat` and `food-vision` (the prompts still
say "gen-z women" in production until then — **still outstanding from
E3**) · archive/TestFlight 1.2.0 (30) · **merge `feat/app-v2` → main**.

New this era: **a device walk of the words path.** The simulator cannot
reach the vision EF, so the one thing the walk could not prove is that
a typed sentence actually returns a good estimate on real hardware over
a real network. That is the single highest-risk unverified link in the
era.

No new migration. No new EF deploy required by E7 itself.

## 12 · WHAT THE NEXT ERA SHOULD BE

E7's own evidence points at one thing, and it is not another feature.

**Every era since E1 has been building for a user who cannot see any of
it.** Seven eras are stacked on an unmerged branch; production is
running a build from before E1. The desk's proof line, the morning
read, the plate's memory, the coach's read tools, the answer — none of
it has met a paying user. The `00_THE_SYSTEM` roadmap has three more
eras queued behind them.

So the next era should be **THE MERGE**: get seven eras in front of the
~2 payers/day who arrive, and instrument the four questions in §10 so
the *next* decision has data instead of a walked opinion. E6 recorded
that production cannot currently discriminate between features; that is
not a fact of nature, it is a consequence of never shipping and never
instrumenting. E7 cannot be falsified until this happens — and neither
can E1 through E6.

If the founder wants a product era instead, the ranked candidate is
**Home's hierarchy** (§9.4): the same protein-first law E7 proved in
the reading, applied to the surface every payer actually sees, plus
the carousel's information architecture reconsidered rather than
re-ordered. It is small, it is evidence-backed by the same §7.6 finding,
and it finishes the argument this era started.
