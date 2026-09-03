# 72 — THE STATED DAY

**feat/app-v2 · built 2026-09-03, after 71.** The standing mandate:
use Jeni as a paying customer (weight-loss and GLP-1), find what
breaks trust or reads as old Jeni, fix classes. Method: DriveUITests
walker-arm drive sessions on the iPhone 16 QA sim, two live research
sweeps over current GLP-1 and food-tracker communities (2025-26
complaints, not feature requests), every fix RED→GREEN where a seam
existed, every changed surface refilmed.

The research anchored the walk: the five most-repeated food-tracker
frictions are re-logging, correction cost, wrong-but-confident scans,
**backfilling yesterday**, and **asking the record a question**; the
five most-repeated GLP-1 frictions are dose changes destroying the
record, **symptoms floating free of the dose timeline**, appetite-blind
logging, nothing to show the prescriber, and pay-then-lose. Jeni
already answers most of these better than the category (usuals, repair
loop, era chains, the visit packet, absence honesty). The walk went at
the two it didn't.

---

## 1. THE STATED DAY SURVIVES THE WORDS DOOR (the flagship, a truth class)

Filmed as-found: typing **"last night i had a bowl of chicken soup"**
filed a plate stamped "snack · 11:43pm" — TODAY. Home's dial dropped
78 → 58 g protein to go and 736 → 486 kcal left **for a meal she ate
yesterday**; yesterday stayed empty. Both days wrong, from a sentence
that stated the day plainly. Her stated NUMBERS have survived verbatim
since p61 (`StatedPlate`), her qualifiers since p53 ("half a turkey
sandwich" never matches the whole one); her stated DAY was silently
discarded — the same class p70 closed for macros.

Fixed end to end, client-only:

- **`SpokenDayReference`** (pure, PlankFood) — V1 understands exactly
  one past day, yesterday ("yesterday", "yesterday's", "last night"),
  and REFUSES over guessing: same-day words alongside → nil; "same as
  yesterday" / "more than yesterday" (comparisons) → nil; "leftovers
  from last night" (provenance, eaten today) → nil; "day before
  yesterday" → nil (V1 never guesses 2). nil = file to now, the exact
  pre-p72 behavior.
- **`CapturedFood.statedDaysAgo`** — stamped once at the words door's
  one chokepoint (all three submit exits: usual, stated, model), and
  carried by the p51 mutation-copy law with zero copy-site changes —
  the law working exactly as designed.
- **`FoodLogPersister.statedLoggedAt`** — `setLoggedDay`'s own
  clock-preserving arithmetic applied at birth instead of as a repair.
  The Apple Health export rides the same `loggedAt` — correct by
  construction.
- **The reading shows the day before she confirms**: the chip says
  "yesterday" (the wall-clock pair stands down — "snack · 11:43pm" was
  the moment she TOLD us, dressed as the moment she ate), the protein
  target drops "today", and the day line says "this *goes on
  yesterday*" instead of claiming today's room
  (`FoodModule.dayLine(statedDaysAgo:)`, pure + pinned for both
  cohorts).
- **The commit answers with a quiet receipt** ("logged on
  yesterday.") — never today's answer, never a celebration ("today's
  first plate" over a backfill would be false).

RED proven: the persist pin fails against the old `Date()` stamp
(1 failure, reverted-and-restored). Filmed: the reading's yesterday
chip, the receipt, **Home's dial unmoved** after the commit, and
yesterday's recap carrying the soup.

## 2. THE PAST DAY ANSWERS IN PLACE (p71's composition question)

A past day on Home rendered one summary card ("plates 16 · 6,120
kcal"), a weak door ("the full record is in becoming" — which landed
on the TAB ROOT, not the record), and ~65% dead paper — while "what
did I eat last Tuesday" is the category's most-repeated history ask.
The page IS that answer and refused to give it.

Now: the day's own plates render beneath the card in THE BOOK's
ledger grammar (title · time | kcal · protein — suppression keeps
protein only, unmeasured protein prints nothing), **each row opens
the existing plate page** with its full repair loop (fix, re-date,
remove), and the door keeps its promise: "open the book" routes
through the `.plates` deep-link the instrument has used since p54.
Filmed: the ledger in place; a row → the plate page. While there,
one number grammar: the ledger kcal gains thousands separators in
BOTH sites (the BOOK printed "1380 kcal" under a card saying
"6,120").

## 3. THE PATTERN OBSERVATION REACHES THE REGIMEN PAGE (GLP-1 #2)

The regimen page puts the doses, the symptoms and the dose changes in
one column — and its own dose-ledger comment has said since `33` that
"the pattern engine is the only thing in this product allowed to
observe" — but the engine's observation rendered only on a Becoming
tile, a tab away. The seeded proof case (dose bump aug 13 → queasy
every few days after, one headache in six weeks before) sat on screen
as three lists with the correlation left as homework — the #2 named
GLP-1 frustration ("does this follow my shot or my dose bump?").

Fixed as a class: the three consumers (Becoming tile, jeni's
`read_patterns`, and now the regimen page) each hand-built the
engine's `Inputs` from five stores — a drift in any one would fork
the floors (a consumer forgetting p58's schedule-change exclusion
would feed "picked up after the dose changed" from a rhythm edit).
**One composer now** (`MedicationPatternEngine.composedInputs`),
pinned by `PatternComposerTests`: the real stores compose into the
engine's proof case RED-shape (a seeded dose bump + symptom cluster
fires the observation; a quiet record composes to silence). The
regimen page renders ≤3 observations in its own whisper grammar
between the symptom ledger and the era record. Filmed: three
floor-gated sentences exactly where the question is asked, ending
"worth a mention at your next visit."

## 4. THE WIDGET SPOKE A RETIRED REGISTER (old Jeni on the Home Screen)

`JeniWidgetSnapshot.proteinReading` still said "24 g to the floor" /
"floor met" — p58's words, two passes after p67 retired "the floor"
everywhere in-app — because the p58 pin froze LITERALS instead of
Home's function. The mechanism fixed, not just the words:
`ProteinBandWords` is the band's one register (Home's
`proteinState` reads it), and `WidgetSnapshotTests` pins the
snapshot's words EQUAL to it across a grid — rewording either side
without the other now fails a test. The sweep the drift survived was
then run: **two more shipping "floor" strings** died
(`WeeklyBodyReview`'s "protein under the floor" muscle-loss line,
`WeeklyReview`'s "the floor can rise 5g" offer reason). The DEBUG
harness's mock faces keep theirs (never shipped).

## 5. THE REMINDERS PAGE JOINS THE PRODUCT (p67/p71 standing, closed)

Filmed as-found: a 200pt wheel whose choice did NOTHING until a
mid-scroll "save time" pill — the standing-CTA object on a settings
form (§5.2's named tension), on a page whose two toggles commit
instantly. Two interaction grammars on one screen, and the product's
last save button. Now: **"delivered at · 7:00 AM"** — one row, a
compact system picker, commit-on-change (keys instantly — the
preview follows live; the UNUserNotificationCenter write debounced
0.5s). The permission warning was a treasure map ("enable them under
Settings → Jeni → Notifications"); **the sentence is the door now**
(opens the app's own Settings page). And the page finally
acknowledges the one reminder a medicated customer opens it for:
"YOUR MEDICATION · shot reminder · evening ›" — a pointer into the
regimen sheet, never a second editor ("dose reminder" for oral
plans). Filmed before/after.

## 6. SMALL TRUTHS

- The plate page's "the day" row was `.buttonStyle(.plain)` —
  press-DEAD, §5.1's first-find class, on the exact control this
  pass's flagship leans on. JKPress now.
- The regimen's "on it since" and "in the pen" rows both invited
  with an identical big-serif "add it, if you like" stacked twice;
  each names its own ask now ("add the month…" / "add the count…").

## 6b. THE SE·AX5 SWEEP OF THIS PASS'S OWN SURFACES

The new surfaces walked at AX5 on the SE: the recap's plate rows
STACK (title wraps at spaces, time + facts beneath — the p33 law
built in), the reminders page wraps beside its toggle, the pattern
lines wrap. Two strays into food settings caught two real breaks
there:

- **The read-only daily target wrapped MID-NUMBER** ("1,59 / 6" —
  filmed) — the p51-D2 class on the very section p71 rebuilt. The
  numeral scales now, never wraps.
- **The choice chips ran off the screen edge mid-word** ("keep with
  my plat…") — `FoodChipFlowLayout` wrapped whole chips to new rows
  but proposed UNBOUNDED width to each, so a single chip wider than
  the screen clipped. The layout caps proposals at its container
  now (an oversized chip wraps its words inside the capsule), and
  the chips shed their press-dead `.plain` (§5.1). Filmed
  before/after ×2.

## 7. WALKED AND SOUND (no change earned)

- **Chat as a product surface** — "when did i last have pizza?"
  answered "you haven't logged any pizza in the last two weeks" — a
  scope `read_food_week(days: 14)` can honestly see; "what did i eat
  yesterday?" itemized the day and agreed with the BOOK exactly.
  Real answers, right length, honest scope.
- **"your numbers"** — clean set table, honest footer, sticky done.
- **The visit packet** — sections cover the researched
  clinician-prep need (doses, symptoms with timing notes, weight,
  protein, movement, her own questions, gaps, sharing, PDF).
- **The dose ledger / era chain / backfill / pause door** — the
  GLP-1 walk's change-dose/miss/late/pause paths all hold.

## 8. REFUSED / DEFERRED, WITH REASONS

- **The workout sheet's her75 sticker assets** (pink 3D dumbbells +
  star lineart on a v25 surface) — inside the founder-gated
  workout-library retirement (E7/E8 standing); converging its
  visuals would invest in a module awaiting a retirement trigger.
- **The movement tile detail's composition** (a full-screen cover
  holding four lines) — same class as the recap question this pass
  DID fix; named for a composition pass with film.
- **"notes appear when your record shows something"** — wordy but
  it is the only explainer of a silence-first feature; trimming it
  buys nothing a customer feels.
- **Chat's habit of ending answers with a question** ("how's today
  feeling so far?") — a register question that lives in the
  jeni-chat EF prompt; an EF deploy is founder-gated. Named.
- **The compact picker prints "7:00 AM"** in system case against
  the lowercase voice — the system control speaking its own
  language; not worth a custom control.

## 9. VERIFIED

- **plankAITests: 1670 · 2 skipped · 0 failures** — p71's 1667 + 2
  `PatternComposerTests` + 1 widget equality pin, reconciled
  exactly. (SpokenDay/dayLine tests live in PlankFood's suite.)
- **PlankFood: 319/319** — 311 + 7 `SpokenDayTests` + 1 stated-day
  dayLine pin. RED proven for the persist law (1 failure against
  the old stamp).
- **SayItWalk 4/4 solo · Release BUILD SUCCEEDED** (final gate).
- Films in `72_evidence/` (17 frames: stated-day before ×2 /
  after ×2, recap ledger + row→plate, regimen before/after,
  reminders before/after, widget faces, SE·AX5 recap rows +
  reminders + food-settings shear/chips before/after).

## 10. NAMED, NOT DONE

- `SpokenDayReference` V2: weekday names ("on monday i had…") — the
  read-tools grammar exists; the detector stays yesterday-only until
  the shape proves itself.
- The stated-day receipt is app-language "yesterday" only; a
  multi-day backfill still goes log-then-move (deliberate).
- The §5.2 underline wording vs the clinical-verb family · reminders
  wheel structure is CLOSED but the "save time" ink pill's sibling
  (p67's mid-scroll pill list) should be re-swept · food settings
  rose chips · oral supply · p70/p71 standing device checks.
- The movement-tile composition class (above).
- The dead SourceKit noise aside: `MedicationPatternEngine` now
  imports SwiftData/PlankFood/PlankSync for its composer extension —
  the pure core is untouched; a purist split (Engine + Composer
  files) is cosmetic and deferred.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
