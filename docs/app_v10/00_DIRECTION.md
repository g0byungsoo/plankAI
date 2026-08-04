# app v10 — THE MIRROR PASS

**Status: IN PROGRESS (2026-08-04, feat/app-v2). The founder's brief,
same day the v9 program closed: the architecture is done; the FEEL
is not. "Within three seconds of opening the application, users
should immediately understand: this app is about my body
transformation." This doc is the law for the pass; §9 is the
running shipped record.**

Reading order: `docs/app_v9/00_MISSION.md` (L1-L7 stand untouched) →
`docs/app_v9/04_DESIGN.md` (the 100× constitution, this pass's
engine) → this file. Evidence (before/after frames, recordings) in
`docs/app_v10/evidence/`.

---

## 1. The founder's brief, distilled (2026-08-04)

- Not architecture. Not features. **Emotion, delight, craft, beauty,
  clarity, motivation, confidence.** Build the product the
  architecture deserves.
- Body Vision is not a feature — it is the center. Food, movement,
  sleep, medication exist to explain body progress; coaching exists
  to continue it.
- **Home: redesign aggressively. Preserve the underlying
  architecture. Do NOT preserve the current information hierarchy.**
  First screen must say "I am becoming someone different."
- Becoming: the emotional heart — a personal transformation
  journal, her own body the hero, the compare unforgettable.
- Capture: iconic — Face ID / ECG / Vision Pro register, calm,
  confident, magical.
- Remove over add. Photography, body imagery, typography,
  whitespace up; chrome down. Never generic.
- Verify continuously on the simulator: record, extract frames,
  inspect motion. "Do not trust screenshots. Verify movement."
- Stop only when it feels inevitable.

### The unlock

The 2026-07-27 "Home = the checklist" steer and D1's narrow grant
(trend whisper + lead hero only) are **superseded by this brief**
for Home's presentation layer: "Redesign Home aggressively… Do NOT
preserve the current information hierarchy." The checklist's
*content* (CarePlanEngine's lead/supporting/offered, the caps, the
verb law, never-debt) is architecture and stands; its *placement
and dress* are now design material. Recorded here so the
supersession is explicit, not silent.

## 2. The diagnosis (before-frames in evidence/)

Three seconds on each surface today says:

- **Home** (`before_home.png`): dateline → day rail → "add the
  *next* plate" with a pastel peach sticker → two more rows →
  four pastel sticker tools → calorie/protein/steps rings.
  Reads: *a cute habit tracker.* Zero body presence on a normal
  day — with three scans sitting in the store.
- **Becoming cover** (`before_becoming_cover.png`): a strong serif
  read ("*down* about 3 lb this week.") over ~55% empty paper.
  Reads: *an essay.* Her figure is one swipe + one tap + one sheet
  away.
- **Body page** (`before_body_page.png`): the only surface with her
  figure — matted with visible pillarbox seams (white card vs
  paper silhouette), a crude capsule seed figure, an invisible
  fore-edge rail.
- **Capture**: the only screen that abandons the app's paper
  entirely — raw camera + black scrim; the arming streak renders
  nowhere (`Arming.progress` is a dead accessor); the ~0.3-2s
  silhouette render has no processing state; the countdown numeral
  sits on arbitrary camera pixels.

The Body OS is real underneath. The product still wears the
calorie tracker's clothes.

## 3. The thesis

**The ink figure becomes the app's protagonist.** One material
system — her figure in ink on the house paper — appears at every
altitude: Home opens with it (the mirror), becoming is its journal,
the capture chamber creates it, and the record compares it. Nothing
else in the category can show this screen: no photos-by-default, no
numbers-from-pixels, no rings. The privacy law (L4) and honesty law
(L3) are not constraints on the design — they ARE the design.

Three seconds after open: her figure, her change line, her one
thing. That is "I am becoming someone different."

## 4. The surfaces

### 4a. HOME — the mirror opens (Phase A)

One screen, no scroll (the composition law survives; the contents
change):

1. **Dateline** eyebrow (kept) — "tuesday, august 4 · day 12" +
   the program caption folded in ("week 2 of 20 · finding steady",
   tap → becoming). Gear stays.
2. **THE MIRROR** — her latest figure, matted on paper (~38-44% of
   the viewport), with the change line as the serif hero beside/
   beneath: BodyChangeRead's floor-gated line when floors pass,
   else the trend line, else the honest early state. Tap → the
   becoming body room. Zero scans → the drawn figure outline
   (dotted ghost) + "your record starts with one scan" → tap
   opens the scan. Body-first even at zero data.
3. **THE DAY** — the lead row (hero treatment, engine untouched) +
   supporting/offered rows. Row badges move from pastel stickers
   to the clinical treatment the body-scan row already ships
   (hairline ring + ink glyph): the daily surface joins the
   clinical-calm register. Stickers remain the celebration
   language on earned moments (scatter law untouched).
4. **The four doors** (weigh · method · breathe · move) — kept,
   restyled quiet: small ink marks, no pastel discs.
5. **The ledger** — the rings die. Day numbers render as one
   receipt line in the evening-ledger grammar ("860 in · 62g
   protein · 6.4k steps"), bottom-docked, only once the day has
   data. The landed moment (96pt kcal swell) survives — it is
   earned. Signals receipts join this ledger line.

**Removed from Home:** the 7-cell day rail row (program continuity
lives in the dateline caption; past-day receipts remain reachable
via becoming's journey), the pastel sticker discs, the tools'
pastel treatment, the metric rings band, the separate signals band.
Evening keeps its inversion (EveningClose) — the mirror compresses
to its line, the receipt ledger grows.

### 4b. BECOMING — the journal (Phase B)

- **The landing becomes HER.** When scans exist, the body page and
  the cover merge into one landing page: her figure hero (matted,
  seam-fixed), the WeeklyBodyReview read beneath it (outcome →
  mechanisms → preservation → move — engine untouched). Opening
  becoming = seeing yourself + this week's entry. When no scans:
  today's cover (read + invitation) stands.
- **D2 honored:** the *cover-art slot* (her scan as cover art in
  place of plate photography) keeps its explicit opt-in. The
  landing's figure is the page she navigated to, not ambient cover
  art — same surface class as the shipped body page.
- **YOUR RECORD** — the mat seams die (mat renders in the
  silhouette's own paper); week groups + strip stay; **the compare
  gains physics**: haptic detents at the poles, release settles to
  the nearest pole with a damped spring (a balance coming to
  rest — no more ambiguous mid-blend parking), the date ends flip
  weight with the settle. One gesture, now with a floor.
- **The seed figures become human** (QA-only): drawn silhouettes
  with real shoulders/waist/hips that narrow week to week, so
  every design frame and reel is honest-looking.

### 4c. CAPTURE — the chamber (Phase C)

- **The paper chamber**: the camera lives inside a large rounded
  aperture on the house paper (the mat, live) — the coaching line
  and countdown render on paper below the aperture, never on
  camera pixels. The app's identity holds through its most
  important moment; legibility stops depending on her bathroom.
- **The arming ring**: `Arming.progress` finally renders — a
  hairline ink ring around the aperture that draws closed as the
  12-frame streak holds and unwinds when she drifts; when it
  closes, the countdown begins. Face ID's ring, in our material.
- **THE DEVELOP** (the signature): shutter → freeze → the
  photograph develops into ink — an ink-bleed mask reveal (the
  lesson reader's `inkBleedReveal` material at frame scale) that
  performs the privacy promise: the photo becomes ink, on your
  phone, in front of her. Lands matted; "keep it" beneath.
- Craft fixes: the 8s manual-door timer restarting on re-entry;
  processing state named; countdown numeral on paper.
- QA: a DEBUG synthetic-pose door so the sim can walk the arming
  ring + countdown + develop without a person.

### 4d. The connective tissue (Phase D)

- The figure travels: Home mirror → becoming landing → record
  share one continuous material (mat grammar, transition).
- One haptic vocabulary for the figure surfaces: the capture
  arming tick / arm / success family reused by the compare detents.
- Chrome sweep on the touched surfaces; XXXL, Reduce Motion,
  VoiceOver floors as tested law (every figure surface speaks a
  sentence).

## 5. What does not change

All of `docs/app_v9/02_PLAN.md` §5 (onboarding v7, keep wall,
AppPhase, three tabs, auth/sync, chat, clinic loop, tokens/palette/
identity/voice/verb laws, GLP-1 floors, bundle id) **plus**: every
engine this pass re-dresses (CarePlanEngine, TodayStateService,
BodyStateService, WeeklyBodyReview, BodyChangeRead, BodyScanStore/
PhotoStore/Alignment, InsightEngine, Signals), the QA door
contract, the walkers' reachability (ids updated where a surface
moved, never dropped), and the 488-test suite's green.

## 6. Design laws for this pass (composing with L1-L7)

- One signature interaction per surface; spend boldness there.
- The figure is always matted on its own paper — never pillarboxed,
  never floating on white.
- Numbers on body surfaces: never (L3/L4 unchanged). Numbers on
  day surfaces: receipt grammar, not gauges.
- No red, no shame states, trend-as-hero (house floors).
- Every new motion: physically believable, reduce-motion gated,
  recorded + frame-inspected before it ships.
- Copy in the clinical-calm register; all new user-facing strings
  are D10 drafts listed in §9 for founder voice review.

## 7. Verification ritual (every phase)

Build once per batch → install on QA-iPhone16 (259952D4) →
`--uitest-inapp-qa --uitest-pro-access --uitest-seed-program
--uitest-reset-body-scan --uitest-seed-scans` (+ per-surface doors)
→ screenshot every touched state (incl. zero-scan, evening, XXXL,
RM) → record every new motion (`simctl io recordVideo` + ffmpeg
frames) → affected walker legs solo → full unit suite per commit
batch.

## 8. Founder review ledger (V-items; defaults chosen, say the word)

- **V1 — the day rail removal.** Home loses the 7-cell rail;
  program continuity lives in the dateline caption. Restore = one
  view line.
- **V2 — stickers leave the daily chrome.** Checklist badges +
  tools go ink-clinical; stickers stay on earned moments. The
  2026-07-27 sticker mapping is preserved in code for the
  celebration surfaces.
- **V3 — the rings retire into the ledger line.** The landed swell
  survives.
- **V4 — the becoming landing merge** (body page + cover become
  one page when scans exist).
- **V5 — the compare settles to poles** (was: parks anywhere).
- **V6 — all new copy** (mirror lines, chamber lines, develop
  state, ledger labels) — D10 drafts in §9.
- **V7 — the landing-figure default (D2-adjacent).** Once a record
  exists, becoming opens on her matted figure by DEFAULT
  (`bodyScan.landingFigure`, default ON) — the brief's "her body is
  the hero" made literal. The record sheet keeps a one-tap door
  off ("your figure opens becoming"), which restores the old cover
  + body page. The face follows her consent-time renderMode choice
  (women who chose photographs chose the mirror); say the word and
  the landing pins silhouette-always instead. D2's cover-art
  opt-in language is superseded by this recorded default — not
  silently: this is the item to veto. The Home mirror (Phase A)
  follows the shipped body-page norm (figure on a record surface,
  silhouette-first), same review.

## 9. Shipped record (running)

*(appended per phase with design evidence blocks)*
