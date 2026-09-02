# 69 — THE PRODUCT INTERFACE PASS

**feat/app-v2 · built 2026-09-02, after 68.** The founder's brief: a
convergence pass, not a redesign — make the whole product feel like
one exceptionally well-designed iOS app. Special attention to the
post-Snap result ("too much space communicating too little"),
presentation geometry as one system (the clipping classes), the
action grammar, and the language. "The app is the deliverable."

Method: the app driven FIRST — twenty-four surfaces filmed at rest
on the QA 16 before any code moved (Home, THE BOOK, plate page,
dose sheet + late face, side effects, regimen, becoming, chat desk,
move, weigh-ins, ritual, chooser, settings hub, evening close,
moments, letter, weekly read, method note, plan numbers, goal
ritual, care connect, reminders, paywall). Findings triaged into
classes; every change re-filmed; one founder steer taken mid-pass
and one of my own layouts reverted under it.

---

## 1. THE READING ANSWERS IN FIVE SECONDS (SnapResultView rebuilt)

The founder's question: *"I just photographed something I'm about
to eat. What do I actually want to know in the next five seconds?"*

Filmed before: the result spent ~550pt of its first viewport on two
white cards — a ~280pt protein card (one numeral and a bar over
mostly air) and a 96pt donut card whose legend restated three grams
— while fiber/sugar/sodium, the micros, the ITEMS and every
correction affordance sat below the fold. At the full detent the
micros row came to rest SHEARED MID-NUMBER under the footer fade
("b12 / 0.9 µg" cut in half) — the founder's exact
content-disappearing class, on the flagship surface.

Now, in reading order, all above the fold at rest:

- **the protein lead** — still first and still the largest numeral
  (§9's law stands: protein leads, kcal quiet), but a ~64pt open
  row on the paper: berry dot · "protein" · "of 90 g today" · the
  counted grams.
- **the donut** (founder steer, mid-pass: *"bar chart doesn't fit
  in the screen after food snap. donut charts work better here"*)
  — my first cut replaced it with a full-width protein bar + flat
  2×3 table; the founder is right that the bar reads stretched on
  this sheet. The donut returned at 86pt carrying kcal + its ± band
  in the center and the plate's composition around it; the
  full-width bar died. Swatch dots on protein/carbs/fat are its
  legend.
- **the set table** — the five remaining facts as a two-column set
  beside the donut: carbs · fat / fiber · sugar / sodium — the SAME
  set-table grammar the plate page (PlateDetailSheet.restRow) has
  spoken since p59, so the reading before the log and the plate
  after it are finally one surface. Denominators only where one was
  truly collected: fiber "of 28 dv", sodium "of 2,300 dv" (21 CFR
  101.9, marked `dv`), the kcal ± band. TOTAL sugar carries none,
  deliberately. Unstated prints "—", never "0 g" (p61's law).
  `SnapResultMath.setCells` is pure and PINNED (absence law + dv
  law, 2 new tests).
- **the day line** rests above the fold; **the items ledger** —
  what jeni thinks the food is — begins at the fade (a list
  mid-flow is the one thing that shears gracefully); the **micros
  row** follows the items it came from (depth, not five-second
  facts), un-shearable by construction.
- The whole-dish note, provenance rows, correction chips,
  composers, and jeni's note are unchanged in place — everything
  simply rose with the ~370pt the two cards handed back.
- rest detent 0.72 → 0.75 so the fold lands between sections; the
  scroll mask's fade zone tightened (0.90 → 0.93).

**What jeni refuses to claim, still:** no micronutrient panel
unless the WHOLE plate is USDA-grounded (`publishesMicros`); no
percentages; no verdict words; no polyphenol/compound inference the
pipeline has no data for; a described meal that never touched USDA
names nothing. The "notable qualities" surface IS the honest one:
716 mg beside "of 2,300 dv" says "salty" without grading anyone.

**AX:** at accessibility sizes the table folds to label·value rows
(kcal keeps its row; the donut never renders), the dish title
yields to one line (VoiceOver and the editor carry the full name),
and the protein target folds beneath its label (AX5-SE filmed
"of 90 g to…" before the fold). SE + SE-AX5 + the answer morph +
the arrival all filmed.

## 2. THE HARNESS STOPPED LYING ABOUT WIDTH

The result harness's mock photo — `Image().resizable()
.scaledToFill()` unconstrained in the stage ZStack — PROPOSED its
fill size to the stack, so every film of this sheet for two eras
rendered 479pt wide on a 393pt screen: ~43pt of sheet pushed off
both edges, gutters invisible, the donut clipped at the screen
edge. Caught by measuring the film against the code
(`padding(.horizontal, 22)` could not produce a 6pt gutter).
`Color.clear.overlay(...).clipped()`; the films now show shipped
geometry. The shipped stage always clipped its photo — only the
harness lied.

## 3. THE CLIPPING CLASS, SWEPT

- **The evening close** — the "how did today sit?" pill cloud
  sheared MID-WORD ("backed up") against the pinned goodnight
  capsule at rest: the p68 SideEffectSheet class, on the close, its
  24pt fade too short to read as anything but a cut. The taller
  ramp (52pt, early full stop) dissolves the row into paper;
  filmed both ways.
- The dose sheet's **late face** (p68's named-not-done): filmed at
  `tall` — the when-chips, the label's missed-dose rule and the
  pinned decision all stand above the fold; the site grid below has
  a rotation-chosen default. **Kept at tall**; the p68 worry does
  not reproduce as a defect.
- CareConnectionSheet: filmed on suspicion, ACQUITTED — the
  upper-third seat is a commented, deliberate optical decision; the
  CTA already rides JFContinueButton. No change.
- Home/Becoming content under the floating tab pill: the p51/p66
  ramp, reviewed and left standing (deliberate).

## 4. ONE COACH (a live brand breach found by walking)

Settings › "coach — jeni" opened **ChangeTrainerView**: the
plank-era trainer chooser offering "kira · sassy & real (*'My mama
planks better than this.'*)" and "sam · chill & playful", each with
a PHOTOGRAPH — jeni herself rendered as a woman's portrait, against
the identity line the product states in its own chat ("jeni is a
digital coach. not a person, not your clinician", the CA/IL/TX
disclosure) and the brand law that jeni's face is the drawn j mark.
The screen claimed to switch "your coach" while actually governing
only legacy routine-audio clips.

Row removed; view deleted (354 lines + pbxproj refs); both
settings walkers updated to pin the current product (the p46
stale-walker class, headed off in the same commit). Stored
`voicePreference` values still drive `RoutineAudioManager`
unchanged — nobody's session audio silently switches. The
notification preview now wears the **j mark** instead of the
photograph and says what is true: the morning read is jeni's no
matter which voice reads a workout ("what jeni sends at 7:00 am";
"a note from jeni"). Residue, named: a user who once picked
kira/sam now has no switch back (guided-session audio only) — if
that choice matters it belongs on the session surface, founder's
call.

## 5. THE ACTION GRAMMAR CONVERGES

The last three 52pt italic-Fraunces capsule CTAs — settings
sign-in, reminders save, feedback send — joined **JFContinueButton**
(56pt, DMSans, standard press + haptic, disabled ghost), whose own
header has named exactly this drift class since v3 P11.6. The
`saved ✓` morph became a label morph ("save time" → "saved"); the
send button keeps its empty-disable through `isEnabled`.

## 6. THE LANGUAGE PASS

The em-dash law (design law: no em-dashes between words) finally
swept the shipped copy — sixteen user-facing strings across plan
numbers, dose sheet, weekly read, medication sites, weight ledger,
plate repair, snap result; pins updated in the same commit.
Model-facing envelope strings and the "— jeni" signature are
exempt by design. Two captions got true rewrites while open:

- "approximate — signing back in brings your age range home, not
  the year." (the system explaining its plumbing) → **"close, from
  your age range. tap to set it exactly."**
- "these numbers disagree with each other — worth a look" →
  **"the calories and macros don't quite agree. worth a look"**

The p68-named jeniNote tail (ResultDetailCopy): "below a meal's
worth / steady intake protects energy", "protein-first is the
priority", "the pattern that preserves muscle", "a composed plate …
single-item meals", "consistent records make your weekly review
reliable" → the same facts the way a person says them ("when
appetite is low, protein comes first. this plate does that." · "a
mixed plate: X and 2 more. easier to balance than one big thing." ·
"550 calories, logged. days like this make your weekly read
true."). Honesty rules and registers untouched.

## 7. LIGHT / INK / CELEBRATION — deliberately left alone

The p67-p68 system (ink scenes, moment doodles, the shower, the
goodnight moon) is fresh and filmed; rarity is its law. Nothing
added, nothing spread. The unplaced doodles (trophy · star ·
balloon) stay unplaced until a moment earns them.

## 8. VERIFIED

- **plankAITests: 1660 tests · 2 skipped · 0 failures** (the p68
  baseline exactly — structure and words changed, not contracts).
- **PlankFood: 293/293** (p68's 291 + exactly the two set-cell
  pins). **SayItWalk: 4/4 solo** on the new anatomy.
- **Release BUILD SUCCEEDED.**
- Films in `69_evidence/`: reading before (both detents, the
  sheared micros) · the bar variant the founder rejected · the
  donut composition at true width · SE rest · SE-AX5 (title +
  target folds) · arrival-to-answer E2E · the close's pill shear
  before/after · the trainer picker as found · the hub after · the
  reminders page with the j mark · the dose late face judgment.

## 9. NAMED, NOT DONE

- **The plate page's "0 g"**: `FoodLogEntry` flattens unstated
  macros to 0 at persist, so a stated plate ("protein bar, 190
  cal, 20 g protein") renders "carbs 0 g · fat 0 g" and a 100%%
  protein split bar on the plate page. The reading now refuses this
  ("—"); the RECORD can't yet distinguish 0 from unstated —
  absence-awareness is derivable from the payload ledger, but that
  is record-pipeline work, not a visual fix.
- Kira/sam voice-preference residue (above).
- Device checks: the donut draw + answer morph at 60fps on
  hardware; the close's new fade over real content.
- p67/p68 standing lists (weekly-read/letter/breathwork ink
  candidates, RegimenSheet full split, NotificationSettings wheel,
  SPM extraction, haptics door migration) — unchanged.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
