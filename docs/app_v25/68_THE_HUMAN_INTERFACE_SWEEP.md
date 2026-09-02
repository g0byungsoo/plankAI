# 68 — THE HUMAN INTERFACE SWEEP

**feat/app-v2 · built 2026-09-02, after 67.** The founder's brief:
Jeni still sometimes feels like a designer wrote it instead of a
person speaking, and some screens are UI containers rather than
effortless interactions. More human, more obvious, more tactile,
more visual; less wordy, less poetic, less cramped. "Do not treat
Pass 67 as finished design. Its conclusions are evidence, not
doctrine."

Method: baseline recorded (`9e85271`, clean, synced). Two parallel
inventories before any change — the complete sheet census (every
`jeniSheet`/`foodSheet` call site measured against its content's
real height) and the complete rendered-copy census (every string at
the top-traffic moments, in reading order). The whole doodle library
(`~/Pictures/doodle_icons`, ~450 icons over 15 categories) inspected
VISUALLY via generated contact sheets before any icon was chosen.
Every consequential change filmed; two changes were made and
REVERTED on film.

---

## 1. THE SHEET SWEEP (the census, then the knife)

The founder's law for the pass: a sheet's arrival must answer WHAT
IS THIS / WHAT MATTERS / WHAT CAN I DO without a discovery scroll.
The census graded all 41 presentation sites; eight were wrong, three
of them badly.

- **SideEffectSheet ("how it's sitting") → `.full`.** At 0.68 the
  13-pill cloud clipped MID-WORD at the fold ("hair shedd…" /
  "period chang…") and the severity panel landed below it — the
  sheet's own `scrollTo("detail")` was a scripted scroll
  compensating for a wrong detent. Filmed before/after; the severity
  panel, note field and pinned "done" now all stand visible.
- **IngredientEditorSheet → `.full` (both sites).** Every field is
  keyboard-driven; at 0.68 the keyboard left ~124pt of visible form —
  you could not see the field you were typing in. The highest-
  frequency food correction surface.
- **PlateRepairSheet → `.full`** (a 4-item plate opened the editor
  already scrolled, stacked over a strip of its own parent).
- **ForgotPasswordView → `.full`** (auto-focused keyboard buried the
  send button on arrival — an account-recovery dead end).
- **DeleteAccountSheet** — the destructive confirm AND its cancel
  lived inside the scroll; with the Apple-revocation note both
  started below the fold. The decision is PINNED now (§5.2).
- **JKWeightRitual** — `tallFixed` is the documented ruler exception,
  but the sheet had no scroll and no `.large` escape, so AX sizes
  could not reach "not now" or the remove link. The p48 pattern:
  ONE ScrollView, disabled unless the measured column overflows —
  the ruler's drag untouched at standard sizes.
- **GalleryConfirmSheet** (verbs pinned, words scroll) and
  **VolumeSheet** (scrolls at AX) close the AX reachability holes.
- **One-question sheets → `.brief`**: the visit-packet consent, the
  hard-lock explainer, mark-as-done (0.68 around ~300pt of content
  was dead paper).
- **REVERTED ON FILM: the dose sheet stays `tall`.** At `.large` the
  everyday face floated over ~500pt of dead paper. Taller is not
  automatically better; the detent was re-decided by looking, both
  ways. (The late face's extra rows remain a named item below.)
- The dead trial-nudge sheet in MainShell (a `get: { false }`
  binding since the pay-upfront pivot) is deleted.

## 2. THE CELEBRATION GETS ITS OBJECT (§5.9 grown)

The founder: "a protein-goal celebration probably should not be
almost entirely typography floating in empty space." It was — filmed
at rest, the crest page held two lines and a pill on a void of ink.

Now the moment page carries the celebrated thing, DRAWN, from the
founder's own doodle set at illustration scale (~190pt):

- **the crossing → the dartboard with the arrow in the bullseye**
  (the literal "goal hit"). The first import shipped `target-2` and
  the film showed a crosshair reticle — a weapon scope, not a goal;
  `target` is the dartboard. Chosen by LOOKING, the whole point.
- **first plate ever → applause** (the clap, with its motion lines).
- **the day's first plate → the dish** (the cloche, on paper —
  spark stays light).

The doodle pops in WITH the burst and the haptic — one event: spring
from 0.6 scale, then the ambient Lissajous drift takes over. The pop
now originates FROM the doodle (the §4.7 origin law follows the
object); the shower still owns the page. On ink the doodle is
paper-tinted; Reduce Motion arrives whole and still; AX5 filmed —
the flexible doodle absorbs the type growth and the pill stays.

**The words got human.** "protein goal hit." + "23 g of protein.
that's 122 of 120 g. nice work." read as three number clauses from a
machine (the founder's own example of the failure). The crest now
says a sentence and states the DAY — the plate's grams were just
read on the result page:

> you hit your *protein goal*.
> 122 of 120 g today. nice work.

The way out says **"done"**, not "continue" — nothing continues.
The evening close's met line joins the same voice ("you hit your
protein goal today. nice work."). A first plate that crosses keeps
both facts on the one page (the p65 law, pinned). New pin:
`testOrdinaryCrossingCrestStatesTheDay`.

**The goodnight moon.** The terminus was words alone in the dark.
One quiet drawn crescent now drifts above "that's the day." — no
burst, no haptic, the close stays calm; the dark reads as night
instead of absence. Filmed through the real evening walker leg.

## 3. THE SNAP RESULT ANSWERS ITS OWN QUESTION

A scan result asks exactly one thing: IS THIS RIGHT? p67 had made
"add it" the standing CTA and shrunk the correction path to a 14pt
dim word. The founder: "the correction path is not an insignificant
tertiary action." Both decisions live in the thumb zone now — "add
it" stays the dominant ink pill; "retake" / "start over" (door-aware)
is a real full-width quiet button beneath it; share stays the page's
one quiet word above. Filmed.

## 4. BECOMING'S DETAILS ARRIVE AT THE RECORD (founder steers ×2)

The tile detail's medium rest height showed a hero + chart that
LOOKED complete while the ledger, the read and provenance hid below
with no cue — filmed on the calories tile, the founder's named
complaint, invisible from the code (the sheet census had correctly
reported "no half-height sheets in Becoming"; the clipping lived in
a custom morph layer). The tile itself is the glance; a tap means
"show me more" — the detail now arrives at FULL. Medium survives as
the rest stop on the drag down; the v19 physics are untouched.

The film then caught two more, fixed the same hour:
- at FULL, 0.95 of (height + safeTop) put the sheet's top edge 13pt
  ABOVE the screen — the eyebrow and the X rendered behind the
  clock. The sheet now clamps below the status bar.
- (founder steer, mid-pass) the page landed on card-white and the X
  scrolled away with the content. The surface now blends to Jeni's
  PAPER as it grows — a full page is a page — and the eyebrow + X
  are pinned; only the record scrolls between the bands (§5.2).

## 5. THE COPY PASS (in context, not in a spreadsheet)

- Move said "while the weight comes off" twice in one viewport
  (caption + read line); the caption drops its tail once the week
  has something in it.
- Two p67 "floor" survivors in the food notes ("a real step toward
  your floor" / "keeps your floor in reach") → "protein goal".
- Two retention pushes were missing the periods between their
  clauses ("you showed up once the door stays open.") — punctuation
  bugs, fixed.
- The care-code button says what it does: "find my clinic" (was
  "continue").
- The day-one reminder ask says what she gets ("it covers your shot
  day too"), not which switch the system reuses ("your shot-day one
  uses the same switch" — the system explaining its plumbing).
- Kept deliberately: "how it's sitting" (a Jeni-ism carrying real
  meaning), "a quiet day. it still counts.", the greek-yogurt gap
  line (specific and useful is the register at its best).

## 6. VERIFIED

- **plankAITests: 1660 total · 2 skipped · 0 failed** (p67's 1659 +
  exactly the new crest pin; the one first-run failure was the
  day-one pin meeting the new ask copy — updated with the change,
  same semantic assertion).
- **PlankFood: 291/291.**
- **SayItWalk UI legs** re-run against the new footer; **Release
  BUILD SUCCEEDED.**
- Filmed: the symptom sheet before/after · the crest bake
  (crosshair caught → dartboard) · all three moment tiers · the
  doodle pop + shower mid-flight · the goodnight moon through the
  real walker leg · the snap-result footer · the Becoming detail at
  medium (looked complete), at full (clock collision caught), and
  landed (paper + pinned X) · crest at AX5. Evidence in
  `68_evidence/`.
- Mid-pass housekeeping: ~33 GB of stale pass-era derived-data trees
  under `build/` (DD, dd-att-*, DD-meta*, dd47, DDR, DemoDD…)
  deleted after the disk filled mid-build; the xcarchives and
  exports were kept.

## 7. NAMED, NOT DONE

- **Device checks**: the doodle pop's spring feel, the moon's drift,
  the shower + doodle composition at 60fps.
- **The dose sheet's late face** still adds rows above the site grid
  at `tall` — wants its own filmed judgment (a per-state initial
  detent or a reordered late block).
- **Doodle candidates not yet placed**: trophy, star, balloon
  (imported, unused — awaiting moments that earn them: maybe the
  first-ever weigh-in, the week's strength met).
- **The copy long tail**: ResultDetailCopy's jeniNote variants still
  read clinical-adjacent in places; chat/coach envelope prose.
- p67's standing list (weekly-read/letter/breathwork ink candidates,
  CareConnectionSheet structure, NotificationSettings wheel,
  RegimenSheet's full split, SPM extraction, haptics door
  migration).

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
