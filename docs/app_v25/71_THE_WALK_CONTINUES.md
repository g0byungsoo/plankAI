# 71 — THE WALK CONTINUES

**feat/app-v2 · built 2026-09-02, after 70.** The standing mandate:
use Jeni as a real customer, find what breaks trust or reads as old
Jeni, fix classes not screenshots. Method: the DriveUITests
walker-arm across ~24 drive sessions (iPhone 16 + SE at AX5), the
accessibility tree dumped whenever a tap misbehaved, every fix
refilmed. Findings either fixed RED→GREEN or refused with reasons.

---

## 1. THE SCRIM CLASS (walk-caught on film)

THE BOOK's rows scrolled straight through the status-bar clock
("yesterday" colliding with 9:41 — filmed). p62's one masthead-scrim
law stopped at the tab pages: **four full-page covers never got it**
— FoodJournalView, WeighInLedgerSheet, VisitPacketView, ReSigningView
(via JKScreenChrome, which carries no scrim). All four wear
`jeniMastheadScrim()` now. BodyTimelineView exempt by construction
(fixed header above its scroll). Filmed before/after.

## 2. DAY-LEVEL ABSENCE (p70's named-not-done, closed)

p70 closed the absence class at the plate level; three DAY-level
consumers still flattened absence to zero:

- **HomeDayRecap** summed the raw macro fields — a stated protein
  bar's day printed "carbs 0 g · fat 0 g" and drew a 100% protein
  split; and the card carried **no numeric-suppression gate at all**
  (every sibling record surface has one — the suppressed cohort saw
  the kcal numeral here). The totals fold is pure now
  (`HomeDayRecap.dayTotals`, pinned ×4): a macro no plate measured
  prints "—", the split draws only when every plate's composition is
  known, suppression silences the numeral.
- **Home's rest line** printed "carbs 0 g · fat 0 g" on a stated
  protein-only day; carbs/fat now follow the same absence rule
  fiber/sugar/sodium always had (pin updated + RED-shape pin added —
  the old code fails it by construction).
- **THE BOOK's spread head** printed "· 0 g protein" over a day that
  never measured protein; the clause drops instead.

jeni's tools and envelope were checked and carry no day-level macro
totals — closed per-plate in p70.

## 3. THE DEAD TARGET KNOB (the pass's biggest trust find)

Food settings showed **"YOUR DAILY TARGET · 1650 kcal/day · tap to
adjust"** — a live editable field writing `foodDailyTarget`, a
v1-era AppStorage knob that **nothing on the arithmetic path reads**
(SnapResultView's own comment calls it "the legacy AppStorage value…
previews, package tests"). A paying customer edited her daily target
and Home ignored her — a dead control presented as THE daily target,
on the exact "why doesn't the app listen to me" cancel path. It also
showed its numeral to the numerically-suppressed cohort, and its
caption ("seeded from your goal pace + body data") was implementation
prose. The section is READ-ONLY now: the number TargetsService
actually uses, "set by your plan. to change it, adjust weight,
movement or pace in your numbers.", honest absence when there is no
number, invisible under suppression. Filmed: 1,460 kcal/day agreeing
exactly with Home's own 860 eaten + 600 left. The knob itself
survives for its onboarding-era consumers (reveal stamp, paywall
projection, preview backstop).

## 4. A GRADE IN REPORT'S CLOTHING

Becoming's BODY card printed "protein landed 1 of 7 logged days"
under the no-trend headline (walk-caught; p70 had named the seat).
The narrower truth: `WeeklyBodyReview.mechanismLines` printed ANY
ratio, including a shame-shaped one, while its sibling
(`InsightEngine.trendStory`) lets the ratio speak only when protein
actually landed (≥4 met days). One floor now; under it the
preservation ladder carries the protein story with evidence and a
move. Pin updated + a shame-shape refusal pin. 22/22.

## 5. THE EDITOR SHOWS ABSENCE AS ABSENCE (p70's named-not-done)

The item editor opened a stated plate's unstated macros as editable
**"0"s** — reading as recorded zeros. The four number fields are
optional bindings now: an absent field opens EMPTY ("—"
placeholder), typing makes a statement, **clearing a field revokes
one** (new capability), the reset restores the scan's own statements
(previously `stated` survived a reset), and portion scaling
preserves absence instead of minting scaled zeros. The whole drawn
field box focuses its field (the content-sized TextField left most
of the box dead). Filmed on the stated bar; PlankFood 311/311.

## 6. VOICEOVER COULD NOT FIND THE FIX DOOR

The plate page applied one container-level `accessibilityLabel`
("log it again as a fresh entry today") across its bottom action
stack — it overrode BOTH buttons, so VoiceOver heard two identical
"log it again" buttons and **"off? fix this plate" was unfindable**
(tree-dump caught; it also broke the walker the same way). Removed;
each button speaks its own words. One site — the class was swept.

## 7. AX5 ON THE RECAP (the p70 word-shear class, new instance)

SE·AX5: the recap's header sheared "TUESDA / Y," mid-word against
the today pill; the four macro pairs shared one HStack; the kcal
numeral could compress. The standing laws applied (p33 stack-at-AX
×2, p51-D2 scale floor). Filmed before/after: words wrap at spaces,
pairs stack.

## 8. QUIET WORDS, FLOORS, AND TWO OLD SENTENCES

- **The regimen editors** kept four underlined captions (back · not
  sure yet · keep ×2) after p67 retired their own page's overview
  set; quiet words now, with the 44pt floor they were missing
  (leading/trailing-aligned frames — the shared `tappableArea`
  centers a short word and visibly indents it, filmed). The
  clinical-verb underline family (packet · dose retraction · move
  remove · reconciliation) **stands** — refused for removal twice on
  evidence (p62, p63); the §5.2 wording and that family remain in
  tension for a future ruling.
- **The chat composer's send** was 34×34 — the §10.5 class p63 fixed
  on ScanChooser, missed here; it wears the fold.
- **The chain row's receipt words**: "seen" under "want a dinner
  idea from jeni?" read as a read-receipt on the question; "kept"
  named nothing → "plate logged" / "session logged".
- **Two plank-era sentences at promise moments**: "sign in to back
  up your routine" → "sign in so your record survives a new phone.";
  the deletion sheet's "routine history" → "your account and your
  whole record: plates, weigh-ins, doses, notes." (The reveal's
  "your routine is locked in" and the consult's "food, movement,
  and routine" were left — conversion surface and legitimate use.)

## 9. WALKED AND SOUND (no change earned)

- **The usuals loop** — "greek yogurt bowl" typed → instant priced
  answer from her own record ("your usual · from your record" +
  "count it fresh" + "250 left today after this") → one tap files.
  The product's best repeated-use flow; filmed.
- **The chat tool loop** — "what did i eat yesterday?" answered with
  the record's exact numbers (2,180 kcal / 172 g agreeing with the
  BOOK after a day-move) and the stated bar rendered without
  invented macros.
- **Move** — the record form's honest estimate line and sticky CTA.
- **The dose sheet, side-effect sheet, pen flow** — the p70 pen
  feature walked end-to-end as a customer: state 4 → "4 doses left"
  → runway "the last one lands sep 23." → restate → "stop counting".
- **The morning read, letter numbers** — agree with the BOOK.
- **The plate day-move loop** — stated bar moved to yesterday; every
  consumer (letter receipt, BOOK, recap) followed.

## 10. REFUSED / DEFERRED, WITH REASONS

- **Bulldozing every `.underline()`** on §5.2's wording — the
  clinical-verb underline family is a deliberate, twice-refused
  grammar; only the regimen editors (whose own page had been ruled
  on) converged. The law-text-vs-family tension is named for a
  future pass or founder ruling.
- **The reminders page's mid-scroll "save time" ink pill** (a second
  primary above the fold end; §5.2 tension) — commit-on-spin needs
  debounced rescheduling; deferred, named.
- **The BOOK photo-card caption asymmetry** (hero quieter than
  grid cards) — defensible editorial hierarchy; the day ledger
  above carries all times.
- **The repair sheet's third-level editor** could not be cleanly
  walked (layered a11y label collisions defeat the walker); the
  mechanism is shared with the reading (proven there) and p68
  filmed both sites. Not chased further.
- **Rose-tinted chips on the food settings page** (old chip
  grammar) — cosmetic; the page's truth defect outranked it this
  pass; named for a visual-convergence pass.

## 11. VERIFIED

- **plankAITests: 1667 · 2 skipped · 0 failures** — p70's 1661
  + 4 HomeDayRecapTotalsTests + 1 rest-line RED-shape pin + 1
  shame-shape refusal pin (the modified protein-line pin counts
  once). Reconciled exactly.
- **PlankFood 311/311** (the editor refactor changed no contract).
- **Release BUILD SUCCEEDED** (fresh tree — the stale Release
  derived-data was deleted for disk).
- Films in `71_evidence/` (15 frames: scrim before/after, stated-day
  Home/recap, AX5 before/after ×3, the honest editor, pen quiet
  words, the dead knob before/after, chat, usuals, plate page,
  becoming as found).

## 12. NAMED, NOT DONE

- The §5.2 underline wording vs the clinical-verb family (founder
  or law-doc ruling).
- The reminders wheel + "save time" structure (p67 standing).
- Food settings' rose chip restyle (visual convergence).
- The becoming recap card for a past day leaves ~60% of Home empty
  (composition question; the full record is one tap away).
- Oral supply · pen sync/packet line · p67/p68 device checks —
  unchanged from p70.
- The `--uitest-force-hour` door doesn't reach the words door's
  meal-chip clock (QA-only inconsistency; shipped path consistent).

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases; the SE sim's type size restored to medium.
