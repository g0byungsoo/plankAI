# 70 — ABSENCE AND THE PEN

**feat/app-v2 · built 2026-09-02, after 69.** The founder's widened
mandate: no longer interface convergence only — walk the shipped
product and progressively turn every remaining old-Jeni surface,
behavior, sentence and data path into the product Jeni should be now.
Correctness and data integrity first; missing high-value behavior
built, not documented; language, interface and polish behind them.
"Treat the app as the deliverable."

Method: the p57 scriptable walker-arm (`DriveUITests`) driven as a
real customer — a stated plate filed through the actual words door
and followed into its own record; the settings tree, regimen,
becoming, desk, move, weigh-ins, weekly read and symptom sheet all
walked; AX5 walked on the SE; the sim's SwiftData store opened and
read directly when two surfaces disagreed. Ten drive sessions, every
finding either fixed RED→GREEN or named with its owner.

---

## 1. ABSENCE SURVIVES THE RECORD (the p69 named-not-done, closed)

p69's reading refused to print an unstated macro ("—", never "0 g")
— and the RECORD kept flattening it one step later: `ItemDetail`
wrote `carbsG ?? 0` at both persist sites, so a stated "protein bar,
190 cal, 20g protein" filed *carbs 0 · fat 0* and the plate page
rendered a **100% protein split bar over "carbs 0 g · fat 0 g"** —
three statements she never made, filed under her name and re-served
to every reader. Walked first, on film, through the real words door.

Closed end to end, one law — **what she did not state stays absent,
all the way through**:

- `ItemDetail` kcal/protein/carbs/fat are optional; both persist
  sites pass absence through; the wire `ItemRow` mirrors (payload
  jsonb — no schema, no migration; old rows carry literal numbers
  and decode unchanged; new absence encodes as an absent key). A
  stated **0** is a statement and survives as 0.
- `FoodLogEntry.measuredProtein/Carbs/Fat` + `splitIsKnown` derive
  absence from the ledger; ledger-less rows (dining out, pre-ledger)
  keep the standing 0-means-not-collected convention.
- The plate page: the split draws only when the composition is
  known; legends print "—"; **kcal leads the hero when protein was
  never measured** (the reading's own law reaching this sheet — a
  stated "chips, 300 cal" used to open with "0 g protein" in a 44pt
  serif); VoiceOver says "not counted". THE BOOK's rows stop
  printing "0 g". The recap's day-level face left alone (sums).
- jeni's own tools (`read_food_day` + the envelope) OMIT unmeasured
  macros — the file's own comment had named the defect for sodium
  ("handing a model a 0 it will read as 'no sodium'") while handing
  it `carbs_g: 0` two lines up.

## 2. AUTHORSHIP SURVIVES THE RECORD

The reading says "your numbers, as you gave them" (p61's rule, from
`CapturedItem.nutritionSource`); the plate page said **"logged from
your words · ranges, not exact" about the same plate** — an
estimate's hedge over her verbatim declaration, exactly what
`StatedPlate`'s own header forbids. The record dropped WHO authored
the numbers at persist. Now `ItemDetail.source` carries it
(payload-tolerant), `FoodLogEntry.isUserStated` answers from the
record, the plate page + both model-facing "how" lines agree with
the reading, and the **usuals reconstruction keeps authorship** — a
relogged stated plate no longer degrades into an anonymous estimate
with re-invented zeros. Tree-dump proof: the hedge is gone.

## 3. THE EDITOR STOPS TESTIFYING OVER ABSENCE

Following the class into its last consumer: the item editor opens a
stated plate's absent macros as editable 0s, and — nudging her
protein 28→30 g **re-derived kcal by Atwater over the absences and
rewrote her stated 250 kcal to 120**; a kcal edit scaled her one
stated macro by a shape that never existed; any save minted the zero
statements. `plateDisagrees` has said it since p53: *absence never
testifies.* The editor now tracks which fields are STATEMENTS
(`statedAtOpen`, pure+pinned), runs both coherence rules only over a
complete composition (`coherenceMayRun`, pure+pinned), and keeps
absence at save for fields never touched. Full-macro items behave
exactly as before.

## 4. THE PEN, COUNTED (new capability)

The mandate's GLP-1 journey audit found nothing in the product about
supply — and a pen that runs out before the refill is in hand is the
cohort's most common real-world failure. Built tight and
boundary-safe: **one stated fact, one subtraction.**

- The regimen page gains "in the pen · 4 doses left" (the page's own
  door grammar; "add it, if you like" when unstated). She states the
  count once; **remaining DERIVES** from her taken doses after the
  statement — nothing decrements, un-marking gives the count back,
  restating replaces the fact.
- A run-out day only on fixed-interval rhythms: filmed, 4 doses from
  the sep 9 slot → "at this rhythm, the last one lands sep 30."
  twiceWeekly/as-needed get the count and **no date** (an invented
  denominator otherwise). Today's already-taken dose correctly does
  not subtract.
- The whisper speaks only at 1 and 0 ("the next dose is this pen's
  last, by your count. a refill keeps the rhythm.") — her count, her
  arithmetic, logistics named, never urged; **no notification**.
- Injections only (a daily-oral supply is a pill bottle — named, not
  built). Storage is the `move.manual.v1` shape exactly: device-
  scoped, customer-authored, registered in `LocalHandoffInventory`
  and the sign-out sweep; the handoff isolation pin covers the key.

## 4b. THE PIE (founder steer, mid-pass, twice)

*"even if it's small, pie chart is recommended for the better design
on the result page of food snap"* — then *"or any visualization that
helps user to get snapshot of what he/she is eating in one second."*

The reading's 13pt donut ring read as a progress track; **filled
wedges read parts-of-a-whole in one second**, which is the surface's
actual question ("what is this made of", never "how did you do" —
the p58 donut rejection was about budgets on Home, not composition
here). `MacroDonut` → `MacroPie`: filled, 78pt, rose ramp only, no
labels, no percentages, draws once on arrival. The kcal that lived
in the ring's center joined the set table (± band beneath it) — six
facts in a balanced 2×3, and kcal got QUIETER, closer to §9's law.

And the steer flushed out the absence class's last instance: the old
ring drew a **100% protein wedge from "20g protein" alone** — the
reading itself testifying about macros she never mentioned, one
section above the set table that refused to. The pie draws only when
the composition is known (`SnapResultMath.compositionKnown`,
pure+pinned); an unknown composition folds to the honest label·value
rows (the AX fold, now serving both states — filmed: the stated
greek salad reads kcal 320 with "—" down the column, no chart).

## 5. THE V5 SWEEP (~2,900 lines of old Jeni out)

Settings-era walking found the superseded v5 consult still compiling
into Release behind a DEBUG escape whose own comment said "remove
with the v5 sweep" — with its old register ("your food story, on
file."). Following the p55 v4.5 precedent: the seven screen files,
the OV5Step/OV5Router/OV5Flow machine, the Act II screens and the
escape are deleted (pbxproj cleaned); the LIVE OV5 component library
the v8 consult still speaks — OV5Store, persona, rulers, select
lists, teach views, chip cloud, demos — stays, named;
`OV5ReboundCurve` rescued into OV5Components (the teach figure still
draws it). Nine routing pins died with the flow they pinned;
store/persona/handoff pins stay.

## 6. WALK-CAUGHT TRUTHS

- **One entitlement authority**: AccountView read raw `hasProAccess`
  while every other surface reads `effectiveHasProAccess`
  (Release-identical; disagreed under the QA door), and its
  un-entitled state named a **"free plan" this pay-upfront product
  never sold** → "not active" + restore as the remedy, not an
  upsell line.
- **The nameless plan invites**: a shot-day-only regimen (the v8
  shape — she gave a day, never a drug name) rendered the circular
  "medication · your medication" → "add it", the dose row's own
  grammar. The film's deeper scare — hub "ozempic · 0.5" vs sheet
  "your medication" — was chased into the sim's OWN STORE and
  acquitted: the documented QA-sim uid rotation (p53), one bare
  plan row, not a product defect; `setShotDay`'s spec-carry
  preserves name/dose on the shipped path.
- **The drawn line obeys the spoken fold**: becoming's BODY card
  said "a few more weigh-ins and your trend line starts." OVER a
  drawn EMA trend line. When the band is withheld the smoothed
  series no longer draws; her raw weigh-ins still do. Filmed both
  ways.
- **The weekly read said it twice**: "the plan holds steady"
  (title) directly over "…the plan holds." (reason) — the p68
  doubled-sentence class on the read. Reasons carry evidence only;
  two pins hold the title out of them.
- **One sentence shape, one meaning**: the plate hero's "of 153 g
  today" (the day's logged total) wore the identical shape as the
  reading's "of 90 g today" (the goal), a screen apart → "of 153 g
  logged today".

## 7. THE AX5 WORD-SHEAR CLASS

Walking the SE at AX5 found three instances of one class, all
pre-existing: becoming's title broke "beco / ming" mid-word;
`JFPageHero` broke "notification / s." on every page it titles; the
insight card's value+word pair scaled to their floors and still
truncated ("dow… vs last…") while its 2-line cap censored the
sentence ("the scale read…"). Fixed with the standing laws: the
p51-D2 scale floor for single words, the JFContinueButton
accessibility2 cap for the kit hero, the p33 stack-at-AX law for the
pair, and the line cap yields to the words at accessibility sizes.
Refilmed: one word again.

## 8. VERIFIED

- **plankAITests: 1661 · 2 skipped · 0 failures** — reconciled
  exactly: p69's 1660 + 1 stated-provenance pin + 2 weekly-read pins
  + 8 PenSupply − 9 v5 routing pins deleted with their flow − 1
  (the modified steady-hold pin counted once).
- **PlankFood: 311/311** (p69's 293 + 15 absence/authorship + 2
  editor pins + 1 composition pin). **PlankSync: 29/29.**
  **SayItWalk: 4/4 solo, twice** (once on the new plate anatomy,
  once on the pie).
- **Release BUILD SUCCEEDED** (re-run after the pie).
- Films in `70_evidence/`: the stated plate before (100% split +
  invented zeros) and after (—, kcal-led, authorship line) · the
  BOOK rows honest · **the pie** (a protein-light plate reads in a
  glance) and the stated plate's folded rows · the pen
  row/editor/runway/whisper · becoming's fold before/after · AX5
  shears · settings tree · the regimen nameless state · weekly
  read · symptom sheet · plan numbers · weigh-ins · desk · move.

## 9. NAMED, NOT DONE

- **Oral supply** (a pill bottle, not a pen) — different count,
  founder-shaped.
- The pen's count is device-scoped v1 (no sync, no VisitPacket
  line, not in jeni's envelope) — syncing a supply is a decision
  for when there is a reason; the packet line is the natural next
  step for "what happened between visits".
- The day-level recap card can still print a macro the day never
  measured (needs a day-level absence walk; the plate level is
  closed).
- The editor shows an absent macro as an editable "0" — the honest
  affordance would be an empty field; cosmetic, view-only.
- Kira/sam voice residue, device checks (donut draw, close fade),
  p67/p68 standing lists — unchanged from p69.
- The becoming BODY card's support line ("protein landed 4 of 7
  logged days") still renders under a no-trend headline — informative
  but oddly seated; a composition question, not a truth one.
- QA-seed pollution in THE BOOK (midnight duplicates, "the day's
  plates" title) — the standing QA-cloud class, not shipping code.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
