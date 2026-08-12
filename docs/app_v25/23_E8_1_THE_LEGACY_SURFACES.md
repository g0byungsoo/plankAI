# E8.1 — THE LEGACY SURFACES: the record

2026-08-11 · `feat/app-v2` · RC 1.2.0 (30) · **paywall untouched**
(`git diff` over `Views/Paywall`, `Payment`, `AppPhase.swift`,
`WallView.swift`, `Views/FirstPlate`, `FirstPlateState.swift` is EMPTY
for this era; `e5.firstPlate.enabled` still defaults false).

Two jobs, in this order: close E8's two named ship-blockers, then bring
the three surfaces that were still built for an older product into this
one — Method, Breathwork, and Workout, which became Move.

Not a speculative era. Every change below is either a blocker, a defect
found by looking, or a legacy surface the founder named.

---

## 1 · THE FOOD SOURCE CONTRACT

E8 §10: *"`food_logs.source` still lies. Words, label and photo all
persist as `photo` in the synced record."*

**One question, one vocabulary, one column.** `food_logs.source` answers
WHICH DOOR a plate entered through, and its vocabulary is now the same
closed set the `entry_method` analytics property carries. `CaptureSource`
is deleted; `EntryMethod` is the only vocabulary, in the row, the event
and the plate.

| door | value | new to the column? |
|---|---|---|
| photograph of food | `photo` | no |
| photograph of a nutrition panel | `label` | **yes** |
| typed or dictated words | `words` | **yes** |
| product barcode | `barcode` | no |
| re-logged from her record | `again` | **yes** |
| restaurant placeholder | `restaurant_estimate` | no |
| pantry tile | `quick_add` | no |
| unattributed | `unknown` | **yes** |

**No value that has ever been written was renamed.** `restaurant_estimate`
and `quick_add` keep their historical spelling even though `restaurant`
and `pantry` read better, because a rename breaks every insight filtering
on them. This is E8 §3.1's precedent for `environment` applied again:
split a value, never rename one.

**No history is rewritten and none is invented.** Rows written before this
release say `photo` whether they were a photograph, a label or a
sentence. That ambiguity is a fact about a date. `EntryMethod
.persistedSourceValue` preserves the four legacy values (`im_out`,
`voice`, `menu`, `text`) verbatim rather than translating them — `text`
looks like it means `words`, and mapping it would invent a fact about a
row no shipped build can explain.

**Where the truth now comes from.** `FoodVisionService` serves the photo,
label and words doors from one response shape, so it can no longer name a
door at all: it omits `source` and the value defaults to `.unknown`.
`FoodCaptureDispatcher.dispatch` stamps it from the `FoodCapture` case —
the one place the distinction survives. `BarcodeRead` stamps its own,
because it reads live off the video output and never passes through the
dispatcher. A `FoodVisionServiceTests` assertion now pins `.unknown`, so
if the decoder ever claims a door again a test says so.

### What the lie was actually costing

Not only analytics. **`PlateDetailSheet` told the user the wrong thing to
her face**: it tested `source == "photo"` and rendered "read from your
photo · ranges, not exact" or "logged from your words · ranges, not
exact". So a plate she TYPED claimed to have been read from a photograph
she never took, and a barcode read claimed to have come from her words.
`provenanceLine(for:)` is now pure, per-door, and test-pinned — and
printed truth (a label, a barcode) stopped apologising for being an
estimate, because it is not one.

Also fixed, all from the same root:

- **`FoodLogPersister`'s "dining out" title branch was dead.** It tested
  `.imOut`, a value nothing has ever written (the dispatcher builds
  `.restaurantEstimate`), so the restaurant path fell through to
  "scanned plate" for its whole life.
- **`relog` inherited the original plate's door.** A relog keeps no
  photograph on purpose, so inheriting `photo` made the record promise a
  picture that was deliberately not saved. It is `again` now.
- **The chooser's again door fired no save event at all.** Three surfaces
  relog and only two recorded `food_log_saved`; the missing one was
  `RecentMealsSheet` — E4's headline "≤3 taps cold to a kept log", and
  the door a new payer is most likely to use. **Every "did she log food"
  funnel has been undercounting the cheapest path in the product.** The
  event now fires inside `FoodLogPersister.relog`, so a plate cannot land
  in the record without it.
- The upsert defaulted a missing source to `photo`, quietly inflating the
  largest real category with rows that had no attribution. It is
  `unknown` now.

**A claim I retracted mid-build.** The first draft of the migration
asserted that `PlatePriors` was rescaling nutrition-label reads, since
its guard only excludes `.barcode`. Checked: `applyPriors` is called ONLY
on the dispatcher's `.photo` branch, so E4's photo-only law is enforced
by scope and is correct today. The claim was removed before it shipped in
a comment.

### The migration, and how it was tested

`supabase/migrations/20260811120000_food_source_truth.sql`.

- Drops every CHECK on `food_logs` that constrains `source` **by
  definition, not by name**. `food_logs` predates this migrations folder,
  so its constraint was created inline under Postgres's default name;
  dropping by name alone would silently no-op against a differently-named
  constraint and then ADD a second, contradictory one. The failure mode
  would have been `label` inserts rejected in production with a green
  migration.
- Adds `food_logs_source_door_check` over the union of the canonical
  vocabulary and every value any shipped build could have written.
- `RAISE NOTICE`s the distinct values present BEFORE widening, so if
  validation ever fails the migration output names the value that did it.
- Idempotent and replayable.

**Tested through the actual chain**, in a scratch Postgres 17 (the
founder's local Supabase port was in use by another project, so a bare
container was used rather than stopping it):

1. Bootstrapped Supabase-shaped scaffolding, then applied
   `scripts/schema.sql` — reproducing the exact pre-migration constraint:
   `CHECK (source = ANY (ARRAY['photo','quick_add','im_out','restaurant_estimate','barcode','voice','text','menu']))`.
2. Seeded three historical rows (`photo`, `restaurant_estimate`,
   `quick_add`) — the pre-fix reality.
3. Applied all 14 migrations in lexicographic order. **All 14 clean.**
4. Replayed the whole folder twice more. **Clean both times** —
   idempotency proven, not asserted.
5. Inserted all 12 vocabulary values: **all accepted**, historical rows
   intact (12 distinct values, 15 rows).
6. Attempted `relog`, `Photo`, `nonsense`, `photograph`, `''`: **all
   four refused** by `food_logs_source_door_check`.

`EntryMethodTests` duplicates the CHECK list and asserts every enum case
appears in it, so adding a case without a migration fails a test rather
than dropping a user's log to a silent 23514.

---

## 2 · THE PROTEIN CLOSE, FILMED

E8 §13: *"the gap branches are pinned by exact-string tests but NOT
filmed, because no QA seed produces an under-floor day."*

That was true, and the reason was structural. Every seeder writes a fixed
protein number while the floor is DERIVED from the latest weight, so the
gap is whatever arithmetic falls out of two independently-chosen
constants — and the branches cut at 25 g and 40 g. Tuning a seed constant
to hit a branch would need re-tuning every time the floor formula, the
seeded weight or the protein adjustment moved, and it would break
silently, because the failure looks like "a different line rendered".

`ProteinCloseQASeeder` works **backwards from the floor**:
`--uitest-protein-gap N` clears today's plates, reads the same
`TargetsService.proteinTargetG` the surface reads, and writes one plate
at `floor − N`. The branch is then correct by construction for any
weight, any formula and any adjustment.

**All four branches filmed and inspected** (`--uitest-force-hour 20`):

| gap | rendered |
|---|---|
| 0 | "one plate. 90 g of protein." / "*protein landed.* that is the part that holds the muscle while the weight moves." — and NO door, correctly |
| 18 | "one plate. *72 of 90 g of protein.*" / "there is *still time tonight.* 18 g would close it, and a cup of greek yogurt is about that." |
| 32 | "…*58 of 90 g*…" / "…a shake or a cup of cottage cheese is about half of what's left." |
| 60 | "…*30 of 90 g*…" / "…anything with protein in it helps, even something small." — the number correctly never named |

The floor-met frame confirms E7's denominator law visually: at 90 of 90
the ratio disappears and the line reads "90 g of protein."

### THE HOUR, CONVERGED

E8 listed "two hour sources" as debt. **There were three.** `HomeView`
had a private `greeting` reading `Calendar.current.component(.hour)`
directly, so `--uitest-force-hour 10` produced a morning day composer
under an "evening, maya." headline **in the same frame**. Caught by
filming, not by a test.

`AppClock` is now the one hour: `--uitest-force-hour N` wins, then
`--uitest-force-evening` (→ 20), then `--uitest-force-day` (→ 10), then
the wall clock. `isEvening` reads it too, so a named hour finally puts
the whole app in one coherent evening. Five in-app read sites converged
(`HomeView` ×2, `TodayStateService`, `JeniChatView` ×2, `TodayModules`,
`JKGauges`). **Deliberately NOT converged**: `NotificationOrchestrator`
(a forced hour must never move a real notification) and
`JeniAffirmations` / `OnboardingRevealView`, which already take a `date`
parameter and are pure.

---

## 3 · JENI METHOD — the job it had, and the job it has

### What its job used to be

An 84-lesson CBT curriculum about diet culture and body image, keyed to
`canonicalDay`, one lesson per program day for twelve weeks. Six pillars,
four acts, Beck (2007), a 400 KB manifest. Built for a women-focused CBT
app whose user was expected to read daily for three months.

### Why it cannot work here, measured

- **82%** of everyone who finishes onboarding has exactly ONE active day;
  28 of 2,237 have ever reached a second week (E3).
- The payer median is **2.0** active days (E5).
- 90 days of production: **464** people opened a lesson and only **23.5%**
  of them ever paid — it is auto-presented after purchase, not chosen.
  **1.66** distinct days per user. **39** people have ever completed one.
  (For scale: 82 people logged food, at **4.04** distinct days each. Food
  reaches fewer people and holds them twice as long.)

A curriculum indexed by program day can therefore only ever deliver
lessons one and two. **Lessons 3 through 84 are not under-read; they are
unreachable by construction**, and no amount of content quality changes
that. The 22 lessons that address the reader as female (E8 §6) were debt
on a shelf nobody walks past.

### What its job is now

> Jeni notices something in her record, teaches the one thing that makes
> the next decision better, offers one action she can take today, and
> remembers what happened.

### The research that decided the architecture

Not a hunch. **Koh et al 2025, a scoping review of 35 just-in-time
adaptive intervention studies for weight management** (J Med Internet Res
27:e76625) found the support types used were prompts (33 studies) and
feedback (24), coping strategies (7) — and **educational information in
5**. Education is the least-used component in the literature of the exact
thing this product is trying to do. The review also found greater
engagement associated with better weight outcomes, and that **68.6% were
rule-based rather than machine-learned**: the binding constraint is which
moment you choose, not model capacity.

Nahum-Shani's six design elements, as that review summarises them, are
implemented literally:

| element | here |
|---|---|
| tailoring variables | `MethodFacts`, read from the SAME engines the surfaces render from |
| decision points | the moments the app already composes |
| decision rules | `MethodEngine`, pure and tested |
| intervention options | `MethodNote` |
| proximal outcome | `FollowUp`, checked against her own record |
| distal outcome | active days, weight trend |

The review's own framing of a good threshold — states of
**vulnerability**, **opportunity**, and receptivity — is the taxonomy for
`MethodNote.Kind`. To which this product adds the option the literature
leaves implicit and this cohort needs most: **silence**.

### What did not change

**`RepEngine` already held ten genuinely good interventions** — "the
scale is up two pounds overnight", "small appetite today, one plate
maybe", "four days away, the app is open again". Every one is a state,
described. They were keyed to `canonicalDay`, so the scale note fired on
program day 19 whether or not her scale had moved. **The Method already
contained the interventions; it was firing them on a calendar instead of
on her life.** The fix is a trigger layer, not new prose.

### The content system

- `MethodNote` — `Codable`, so a clinician's note is the SAME object
  arriving from somewhere else and no second code path exists anywhere.
- `noticed` is a **template**. `{tokens}` fill from her record, and a note
  whose tokens cannot all be filled is **dropped** rather than rendered
  with a hole. The provenance rule, enforced by construction.
- Versioned per note and per catalog, so a rewrite never rewrites what
  someone was told.
- `suppressedForm` on every note: under `numericsSuppressed` the note
  renders words or nothing, never numbers ripped out into nonsense.
- Content lives in ONE file (`MethodCatalog`), not scattered through
  views.

### The default B2C content: 13 notes

Each passed five questions before it was written — WHO it helps, WHEN it
appears, WHY it matters, WHAT she understands afterwards, WHEN Jeni stays
quiet — and one more that killed several candidates: **what action
follows**. A note with no next move is an article.

| # | trigger | the teaching |
|---|---|---|
| 1 | protein under floor repeatedly | protein is a per-meal habit, not a daily total (25-40 g × 3-4 meals) |
| 2 | scale jumped against the trend | a kilo of fat is ~7,700 kcal; overnight is water |
| 3 | trend flat while still logging | loss goes in steps, not a slope |
| 4 | returned after a gap | nothing is owed. **names no number of days** |
| 5 | late in the dose week | appetite returning is pharmacology, not a lapse |
| 6 | weekend record disappears | a rough note beats a blank day |
| 7 | movement below her own baseline | movement protects muscle; it is not repayment |
| 8 | first plate on file | what a record is FOR |
| 9 | trend just readable | which number to trust from here |
| 10 | protein floor met, first time | what that number was protecting |
| 11 | losing without resistance work | protein is the material, loading is the signal |
| 12 | first week closing | week one flatters you and means least |
| 13 | entering maintenance | a band, not a target |

**What was considered and left out, with reasons** (recorded in the
catalog itself):

- *emotional eating, body image, identity, motivation* — real, and the
  old corpus' actual subject. The product cannot DETECT them. A note that
  fires on a guess about someone's feelings is worse than silence.
- *restaurants, travel, alcohol, social eating, shopping, meal prep,
  portion awareness* — situational, no situation signal. These are what a
  person ASKS about, and chat answers from the same evidence. A note is
  the right surface for an observation; chat is the right surface for a
  question.
- *coming off medication / regain after stopping* — **the single
  highest-value teaching in the domain**: one year after stopping
  semaglutide, people had regained two thirds of what they lost, steeply
  in the first 12-16 weeks, with cardiometabolic gains reverting and
  normoglycemia falling from 93.6% to 43.3% (Wilding et al 2022, STEP 1
  extension). NOT shipped because the product cannot yet tell "stopped"
  from "hasn't logged a dose lately", and getting that wrong means
  telling someone still on the drug that she is about to regain
  everything. **First note to write once `RegimenPlanRecord` exposes an
  ended state.**
- *sleep, stress* — signals exist for one; the honest teaching for both
  is "be gentler today", which the day composer already does.
- *goal setting, habit formation, problem solving* — not content. That is
  what the weekly read and the program facts DO.

### How contextual Method works

`MethodEngine.note(_:)` returns **at most one** note, or nil. There is
**no fallback**: nothing generic fires to fill the slot, and the Today
beat marks itself and closes when the engine has nothing to say. That
single decision is what separates this from the thing it replaces — the
old Method always had a lesson for today, so it always spoke, so it
became wallpaper. `testAQuietDayProducesNothing` is the test that
notices if a fallback ever returns.

Priority is by **time-criticality**, not importance: she came back
(nothing else matters) → a frightened morning → transitions that are only
true today → patterns, which keep → conditions, last.

**Two defects the tests caught in my own design**, both the same shape:
"once-ever" was being enforced only by a 3,650-day cooldown, so
`trendJustReadable` (`weighInCount >= 3`) was permanently true and
outranked everything, and `proteinFloorMetFirstTime` never checked the
field built for it. Both are real transitions now (`== threshold`, and
`!metProteinFloorBeforeToday`, which is deliberately named "before today"
because "ever" would make the first-time note unfireable).

### B2B: the clinician content contract

A clinician's Method content **is** `MethodNote` — the same struct, with
`authority = .careTeam(attribution:)`. That is the whole interface: the
engine, ledger, view, analytics and chat need no second path, and a
clinic that authors nothing changes nothing.

| rule | behaviour |
|---|---|
| DEFAULT | Jeni's note for a trigger, always present |
| OVERRIDE | a clinic note for the SAME trigger replaces it. Never both — two voices on one observation is how a patient ends up weighing generic content against her clinician |
| ADD | a clinic note for a trigger Jeni has none for simply fires |
| SUPPRESS | a clinic can silence a Jeni note by id, leaving **silence, not a substitute**. It cannot suppress its own |
| EXPIRE | `expiresAt` retires it and **Jeni's default returns** — an expired instruction is not an instruction to stay silent |
| END | clinic notes stop being eligible immediately; defaults return. What she was already TOLD stays in the ledger, attributed, forever: a record of instruction belongs to the patient |
| ATTRIBUTION | always rendered, never optional, **never colour alone** (a word plus a drawn stethoscope mark) |

**What a clinician cannot do is a type, not a policy.** `MethodNote` has
no route field, only a `Door` token from a closed enum, so clinic content
cannot send a patient anywhere arbitrary. It has no numbers of its own
either — its `{tokens}` fill from HER record through the same renderer,
so a clinic note cannot state a fact about a patient her data does not
support. **Unattributed clinic content is refused at the door.**

Built here: the resolution rules, the decode path, and
`--uitest-clinic-method` so all three authority rules are walkable in one
launch. **Not built**: the authoring side, which belongs to
`/Users/bko/jeni-health-web` — it already has the org/patient/consent
model this hangs off, and `program_facts` / `care_weekly_summaries` are
the precedent for how clinic-authored rows reach a patient. Building the
CMS here would be building the smaller half of a system whose larger half
is not designed yet.

### Method + One Jeni

Two envelope keys, **zero edge-function deploy** (a new read-tool name
needs the server allowlist, and five eras have queued behind those
gates):

- `method_told` — the last six notes: trigger, days ago, whether she
  acted, `authored_by`, and whether the proximal outcome was met.
- `method_now` — the currently-active triggers, so "why does my weight
  keep jumping" is answered from the SAME observation the note surface
  would have made, at the same thresholds.

**Categorical only.** Never the rendered sentence and never the numbers
inside it: the model already has her record and can restate the facts, so
shipping the prose would duplicate medical logic into a prompt.
`authored_by` is load-bearing — a clinician's instruction and Jeni's
education must stay distinguishable inside the conversation too.

### The browse surface

`what jeni has told you`, in settings, beside `what jeni remembers`. That
page is what the person told Jeni; this is what Jeni told the person.
Between them the whole relationship is auditable.

It is **not a library**, and the record says why: nobody browses a shelf
of things they have never seen. What people revisit is something they
were told once. No unread badge, no count of what she skipped, no
completion state — nothing on this page may imply debt.

### The retention hypothesis, and what falsifies it

**H1.** A note fired by her own record produces an action she would not
otherwise have taken, and that action shows up in the record.

**H2.** Contextual notes are opened at a materially higher rate than the
day-indexed lessons they replace (baseline: 1.66 distinct days/user, 39
lifetime completions across 90 days).

**H3.** A person who acts on a note returns more than one who dismisses
it.

**Pre-registered falsification** — any of these kills it:

- `method_note_action / method_note_shown` **< 15%**. The old surface got
  a captive auto-present; if a note that names her own data cannot beat
  that, the observation is not the active ingredient.
- `method_follow_up{met:true}` **< 25%** of notes with a non-`none`
  follow-up. The action is achievable by design; if it does not happen,
  the notes are asking for the wrong thing.
- **Active-day retention of note-actors ≤ non-actors.** If acting does
  not predict returning, the loop is decoration.
- `method_note_shown` fires on **> 60% of active days**. That would mean
  the engine is not silent enough and the surface is becoming wallpaper
  again — the exact failure it was built to avoid.

Four events, and no more: `method_note_shown{trigger,kind,authority}`,
`_action{door}`, `_dismissed`, `method_follow_up{met}`. **Deliberately
absent**: reading time, scroll depth, lesson counts, completion rates —
the metrics the old Method was optimised for, and optimising them is what
produced 84 unreachable lessons.

### The old corpus

`manifest_v1.json` and `LessonReaderView` stay in the repo, no longer
reachable from the Method beat. Not deleted: the corpus is real work and
git history is not a product decision. Shipping it was the defect — 22
lessons address the reader as female, and a day-indexed shelf cannot be
delivered to a 2.0-day median. If individual lessons are worth reusing,
the path is to rewrite them as notes bound to a trigger.

---

## 4 · JENI BREATHWORK — before → after

**It survives, and the reason is now specific rather than generic.**

Usage says it is used: 149 users started a session in 90 days, 101
completed (**68% of starts**), 322 sessions (**2.16 per user**), 54% of
them payers, still firing today. It is the one thing in the product
people genuinely repeat.

Evidence says what it is FOR, and it is not meditation and not fat loss.
A breathing pattern with a longer out-breath than in-breath **lowered
food craving and impulsivity in a randomized trial in people with
obesity** (Complementary Medicine Research 2024;31(4):376) — which is
precisely the urge-management job the occasion chips ("a craving wave",
"food noise is loud") already describe. Five minutes a day beat
mindfulness meditation for mood in a Stanford trial (Balban et al, Cell
Reports Medicine 2023, n=111), already cited on the protocol card.

| | before | after |
|---|---|---|
| the intro's lower half | a **female-presenting photograph** of a woman cross-legged, colliding with the duration row and sitting behind the CTA | **deleted.** Nothing replaced it |
| the claim | "the real lever is cortisol… breath just lowers the cortisol telling it to hold on" + a paragraph on fat leaving as CO₂ | "this is not a fat-burning exercise… it is for the ten minutes you are standing in", then the craving/impulsivity trial |
| the void the photo left | — | **her own record**: "6 on file · the last one on tuesday", or an invitation. Never a zero, never a streak |
| completion | a **glossy heart sticker** | retired (1.2.0 retired hearts brand-wide; this one survived on a day-1 path nobody re-walked) |
| the close mark | `Color.white.opacity(0.5)` | `Palette.bgPrimary` |

**The claim change is the important one.** The old chain was: breathing
lowers cortisol, cortisol tells the body to hold on to fat, therefore
breathing helps you let go of it. Step one has trial support. Steps two
and three do not, and together they are a mechanistic claim about fat
storage this product has no business making.

**Removing the photograph fixed three things with one deletion** — the
women-only read, the meditation-app read, and a layout collision that
had eaten the 5-minute option's tap target. Remove before add.

**Not done**: the session view's own choreography was not redesigned. It
is already Reduce-Motion-aware, already science-locked (breathwork
contributes zero kcal by design), and the founder's bar is "if something
merely could be different but already meets the quality bar, stop
touching it".

---

## 5 · JENI MOVE — before → after

### What it used to be

Two unrelated things: ~128 `woman-doing-X` Lottie animations behind a
generator, and a steps sheet showing a ring, seven dots and one line.
Between them they answered "did you walk 7,500 steps" and "here is an
exercise video".

**Meanwhile `MovementService` has been reading four more HealthKit
signals the whole time and every one was dropped before it reached a
screen**: active energy, distance, workout minutes, and strength-shaped
sessions. Same defect shape as E7's micronutrients (parsed since v1.0.9,
discarded at a struct boundary) — the expensive part was already done.

### What it is now

The movement record, in this order: **strength this week** → **today,
measured** → **the week as rhythm** → **one line**.

**Strength is the headline, and that is the whole judgement Move makes.**
Lean mass is roughly 25-39% of the weight lost on tirzepatide and
semaglutide in the published trials, and the 2025/26 consensus pairs
protein (1.2-1.6 g/kg, spread across 3-4 meals) with resistance work at
least twice weekly. The reason is mechanical: protein supplies the
material, loading is the signal to keep it. Steps are good for a hundred
other things and are not that signal.

Absent on purpose: a second ring, a score, a goal to close, and any
arithmetic between movement and food.

### The HealthKit data contract

| signal | source | rendered |
|---|---|---|
| steps today | HealthKit | measured |
| 28-day step mean | HealthKit | **her own baseline** — the only thing Move compares her to |
| active energy | HealthKit | measured, or **not at all** |
| distance | HealthKit | measured |
| workout minutes | HealthKit | measured |
| strength sessions (7d) | HealthKit workout types | measured |
| manual activity | her | entered, with an **estimated** energy figure |

No double counting: every measured value comes from exactly one
HealthKit read, and manual entries are **never written back to
HealthKit**. Writing a Jeni estimate into the store every other app
reads as measurement would launder it — it would return through
`MovementService` as `measured` on the next refresh.

### Measured vs estimated energy

1. Where Health supplies active energy, that value is used and labelled
   `from health`. Nothing overrides it.
2. Where it does not, **Move shows no energy figure at all.** It does not
   reconstruct one from steps. The sheet it replaces did exactly that —
   `StepsEnergy` = steps × weight × a constant — and printed the result
   in the same typeface as everything else.
3. The only estimated energy comes from an activity **she entered**,
   where the alternative is nothing and she already knows it is an
   estimate. Labelled `estimated` at every render site.
4. An estimate needs her weight. **No weight on file, no number** — a MET
   model with no body mass has no scale.

Model: `kcal ≈ MET × 3.5 × kg / 200 × minutes`, compendium midpoints at
the **conservative** end of each range, rounded to 5 kcal. Over-estimating
energy out is the error that leads someone to eat it back, and single-kcal
precision would claim resolution the model does not have. "Something
else" carries the lowest MET, because an unknown activity must not be the
most generous one.

`MoveProvenance` has three cases and each renders a **word** on every
number, always. A measurement and an estimate that look alike are the
same number.

### Manual activity

Two taps: what (six kinds) and how long (five choices). No sets, reps,
load or RPE — the only judgement Move makes is "did something heavy
happen twice this week", and none of those change the answer. Only
`.strength` counts toward the two-a-week signal; a generous definition
would quietly retire the judgement.

### The old workout library

**Not retired, and not preserved as the answer.** The honest position:

- The Jeni problem is muscle preservation during substantial weight loss,
  which needs resistance work twice a week — not 128 exercise animations.
- But 203 users reached `workout_start` in 90 days and 47.5% finished
  their first. Deleting a working, if imperfect, behaviour from a product
  that struggles to get anyone to do anything is not a call to make on a
  hunch in a convergence release.
- Redesigning 128 female-presenting animations is not this release's job
  either.

So: **the library stays exactly as it is, and its retirement now has a
measurable trigger.** Move's strength row and the Method's
`losingWithoutResistanceWork` note both point at *recording* strength
work. Post-release, compare `workout_start` against strength sessions
(HealthKit + `move_activity_recorded{counts_as_strength}`). If people
record instead of playing animations, the library retires with evidence
instead of an opinion.

### A unisex defect in arithmetic

`EnergyLedger.bmrFemale` hardcoded Mifflin-St Jeor's female constant
(−161) under the comment *"the cohort is exclusively women"*. The male
constant is +5, so a male user's basal rate was understated by ~166
kcal/day. **A unisex defect in arithmetic rather than in copy, which is
the kind that survives a copy sweep.** It was also dead — nothing called
it, and the live calorie path has been sex-aware all along through
`CalorieTargetCalculator.dailyTarget(sex:)`. Deleted, with the false
comment. `spentKcal` and `isLighterDay` have no callers either; they are
left in place and recorded as debt, because removing a designed feature's
engine is a product decision.

---

## 6 · HOW THE THREE CONNECT

- **Home / Today** — the Method note IS the Today lesson beat. Move is
  the `.steps` beat's destination and the `.move` route. Breathwork is
  the `.breath` route.
- **Jeni** — `method_told` + `method_now` in the envelope; the Method's
  `askJeni` door opens chat with the observation as a seed.
- **Food** — the Method's most common action door is E7's words path.
  Protein notes read the same `TargetsService` floor the ring renders.
- **Weight** — the scale and plateau notes read the same
  `BodyStateService` EMA the trend chart draws.
- **Medication** — the late-dose-week note reads E2's event-anchored
  `CyclePosition`; the adequacy net suppresses Method protein notes
  entirely, the same rule the protein close obeys.
- **Move ↔ Method** — `losingWithoutResistanceWork` and
  `movementBelowOwnBaseline` both route into Move; Move's strength count
  reads the HealthKit signal the Method's trigger reads.
- **Breathwork ↔ Method** — the `breath` door exists on the note's
  closed `Door` enum for the craving-shaped states.
- **Clinic** — one authority ladder, E1's, reused rather than duplicated.

---

## 7 · WHAT THE WALK CAUGHT THAT TESTS COULD NOT

1. **A third hour source.** `--uitest-force-hour 10` produced "evening,
   maya." over a morning day composer in one frame.
2. **Breathwork's photograph** colliding with the duration row and the
   CTA — and the ~450pt void its removal left, which needed filling.
3. **Move rendered with no horizontal padding**, clipping today's step
   count off the trailing edge (`JKSheetChrome` pads its header, not its
   content closure).
4. **Move filmed "3 of 2".** Two bugs: the debug harness accumulated
   sessions across runs (UserDefaults survives relaunch — the same
   seeder-ordering trap E7 recorded for food), and the surface violated
   the product's own denominator law. The denominator drops once the
   target is met now, exactly as protein does.
5. **A hardcoded "two"** in Move's next-line contradicting a week with
   three sessions in it.
6. **The Method cover raced the snapshot load** — opened on the first
   frame, found a nil snapshot, and dismissed itself before the engine
   had any inputs. A real bug, not a QA one.
7. **The Method note was correctly silenced by its own once-ever
   cooldown**, which made every once-ever state filmable exactly once per
   simulator. `--uitest-wipe-method` fixes the blindness, not the
   behaviour.
8. **Move's week caption truncated to "THE WE… · YOUR…" at XXXL.** It
   stacks at accessibility sizes now.

**And a check I nearly claimed without doing it.** My first XXXL pass
used `simctl ui content-size`; the option is `content_size`. The command
failed silently and the frames were at default size. Verified the setting
applied before re-shooting.

---

## 8 · ANALYTICS TRUST BOUNDARY

**From which build forward can each metric be trusted?**

| metric | trustworthy from | why not before |
|---|---|---|
| `environment == "production"` excludes internal testers | **first release carrying E8** (1.2.0 / 30) | TestFlight compiled as RELEASE and stamped `production`; unrepairable retroactively |
| `food_log_saved{entry_method}` / `{source}` | **first release carrying E8** for the event; **E8.1** for the column | one decoder stamped `photo` for three doors |
| `food_logs.source` as the door | **E8.1**, after migration `20260811120000` | same lie, in the record |
| the `again` door's saves | **E8.1** | `RecentMealsSheet` fired no save event; every food funnel undercounted |
| `food_scan_started{mode}` incl. `words` | **first release carrying E8** | the words path was uninstrumented |
| `method_note_*`, `method_follow_up` | **E8.1** | new |
| `move_opened`, `move_activity_recorded` | **E8.1** | new |
| `breathwork_*` | already trustworthy, **but** `session_started` is partly a scripted post-purchase step, so use day-offset ≥ 1 to isolate chosen sessions | — |
| `diet_education_lesson_viewed` | **stops** at E8.1 | the surface is gone; do not compare across the boundary |
| medication cohort person properties | first release carrying E2 | — |

**Distinguishability, proven.** `BuildChannel` resolves debug /
testflight / production at runtime from the receipt name, and 9
`BuildChannelTests` pin it. Confirming `environment: testflight` on a
real TestFlight install remains a founder gate — it cannot be proven from
a simulator, and E8 already recorded that if it does not hold, no cohort
read below matters.

**Food sources, proven.** 140/140 package tests including a CHECK-list
pin; the migration's constraint accepts the 12-value vocabulary and
refuses everything else, demonstrated against a real Postgres.

**No exhaust.** Six new events total across three features. Method's
`trigger` is a closed categorical naming an OBSERVATION TYPE, never its
value: `protein_under_floor_repeatedly` carries no grams,
`late_in_dose_week` carries no drug and no dose. Move ships no step
counts, energies or distances — those are health measurements and belong
in her record. Every new event is in `AnalyticsHygiene` with a pinned
vocabulary, and tests assert the registry equals the enums.

---

## 9 · AUTHORITY AUDIT — what stays distinguishable

| kind | how it is marked |
|---|---|
| patient-entered fact | `you recorded this` (Move); her own words verbatim (memory) |
| HealthKit measurement | `from health` on every value |
| Jeni estimate | `estimated`, plus the uncertainty stated in words |
| Jeni inference | the note's observation line, always from her own numbers |
| education | `from jeni` in the note eyebrow + an evidence line |
| AI suggestion | chat is visibly a conversation; the identity line stands |
| clinician instruction | `from dr. x · clinic` + a drawn stethoscope mark |

**Never colour alone**, anywhere. No dosing calculations. No causality
invented: the plateau note says "the body settles", not "because you".

---

## 10 · VERIFIED

- **997/997 app** (+55: 35 Method, 12 Move, 8 food-source contract) ·
  **140/140 package** (+7). Zero regressions.
- **The paywall is untouched** — `git diff` over the six paywall /
  payment / entitlement paths is empty; `e5.firstPlate.enabled` still
  defaults false.
- **The migration chain replays clean 3×** against a real Postgres 17,
  with historical rows intact and out-of-vocabulary values refused.
- Filmed and frame-inspected: 4 protein-close branches · the Method note
  (Jeni authority, clinic authority) · Move (zero / one session / met) ·
  Breathwork intro (before and after) · Home (protein leading, morning
  greeting correct) · XXXL on Method, Move and Breathwork.

## 11 · FOUNDER GATES

```bash
cd /Users/bko/plankAI

# 1 · migrations — FIVE now, in order (E8 listed four)
supabase migration list
supabase db push
supabase migration list          # Local/Remote must match

# 2 · edge functions — cosmetic only; jeni-chat needs nothing
supabase functions deploy food-vision

# 3 · the merge (fast-forward, conflicts structurally impossible)
git checkout main
git merge --ff-only feat/app-v2
git push origin main
git checkout feat/app-v2
git push origin feat/app-v2
```

Then, in order:

1. Archive + TestFlight **1.2.0 (30)**.
2. **Confirm TestFlight stamps `environment: testflight` and
   `is_test_user: true`.** If it does not, every cohort read is still
   contaminated and nothing else on this list matters.
3. **Device walk** — the simulator cannot reach the vision EF. Highest-risk
   unverified links: a typed sentence returning a good estimate over a real
   network (E7's, still open), and **Move against real HealthKit data**,
   which the simulator cannot supply at all.
4. Post-release reads: `entry_method` on `food_log_saved` ·
   `method_note_shown` → `_action` rate against the 15% kill line ·
   `move_activity_recorded{counts_as_strength}` against `workout_start`.

## 12 · OPEN DEBT

- **Move's real HealthKit rows are unverified.** The simulator supplies no
  active energy, distance or workout data, so those rows have been proven
  by construction and by tests, not by a frame. Device walk required.
- **Move's top content clipped under the status bar at XXXL in the debug
  harness**, which root-mounts a view designed to be a sheet. Not
  reproduced in the real sheet path and not chased further; recorded
  rather than guessed at.
- **`EnergyLedger.spentKcal` / `isLighterDay` are dead.** The v1.1
  "lighter days" mark is not rendered anywhere.
- **The medication-discontinuation note is unwritten** because the signal
  does not exist. Highest-value content in the domain; needs
  `RegimenPlanRecord` to expose an ended state.
- **The `--uitest-open-method` door presents the cover but the note does
  not render**, while `--debug-method-note` does. The engine returns the
  right note (proven by log and by 35 tests); the in-app door has an
  ordering problem that was worked around rather than solved.
- **The old Method corpus** (84 lessons, 22 female-addressed) is
  unreachable but still bundled — ~400 KB.
- **The workout library** is unchanged, with a measurable retirement
  trigger rather than a date.
- Historical analytics cannot be de-contaminated. Pre-E8 funnels mix
  TestFlight with real customers.
- Beyond-XXXL app-wide debt unchanged.
