# app v10.1 — THE REINVENTION (the journal & the mirror)

**Status: IN PROGRESS (2026-08-04, feat/app-v2). The founder's
second brief, hours after the mirror pass shipped: "Forget that
this application has ever looked the way it currently does… Imagine
Apple acquired this technology… hired an entirely new world-class
design team to build the product experience from scratch. Keep the
architecture. Reinvent the experience." This file supersedes
`00_DIRECTION.md` §4 where they conflict; everything else there
(laws carried, V-ledger, D10 process) stands.**

## 1. The identity

Jeni is a **Body Transformation Journal**. Not a calorie tracker
with Body Vision added — the product Body Vision would have grown
if it had come first. The body is the story; food, movement,
sleep, medication, and jeni explain it.

## 2. The three moves

### 2a. THE MIRROR CHECK-IN (capture, rebuilt around the ritual)

The shipped capture optimized for taking a photograph: stand back,
satisfy a pose gate, wait through a countdown. The founder's
diagnosis: people already check themselves in the bathroom mirror —
the product should join THAT ritual, not stage a photo shoot.

The new ritual: **bathroom · mirror · front camera · phone in
hand · five seconds · done.**

- She stands at her mirror as she already does, lifts the phone to
  her chest with the screen toward the mirror, and glances at the
  mirror — never at the device.
- The interface is designed to be read IN THE MIRROR: the state
  signals are symmetric (a filling ring, an inking border, a paper
  flash) so reflection cannot garble them; any word on the glass is
  small, for the phone-in-hand moments only.
- **No countdown. No ghost overlay. No full-figure gate.** A person
  present + ~a second of stillness fires the shutter; a thumb tap
  anywhere fires it immediately (she is holding the phone — her
  thumb is the shutter). Strong haptics carry confirmation; the
  border flash shows in the mirror.
- The develop (the photograph becoming ink in the mat) survives —
  it is the privacy promise performed, and it happens phone-in-hand.
- Architecture untouched: BodyCaptureSession, the silhouette
  renderer, BodyScanStore/PhotoStore, anchors, consent, the QA
  doors. `MirrorGate` (new, pure, unit-tested) replaces the
  arming/countdown pair as the fire decision; BodyScanAlignment
  stays for anchors + pose quality (a fact on the record, no longer
  a gate).

### 2b. HOME — the front page

Not a dashboard; the day's edition of her journal. Composition:
dateline → **her figure, full-width and tall, the change line set
as the headline** → the day, as pure typography (the row discs
die; words + the check carry it) → the four doors and the receipt
line, whispering at the foot. Every production behavior is intact:
rows mark and open modules, evening keeps its close, covers and
letters present as before.

### 2c. BECOMING — the journal

The horizontal issue-carousel and its fore-edge retire. Becoming
becomes a **vertically read journal**:

1. **The cover spread** — her figure and this week's read (the
   v10 record cover, now the journal's opening page).
2. **THE RECORD** — her scans inline, week by week, matted like
   plates in a book; the compare room one tap away.
3. **THE CONTENTS** — the existing chapters (weight, food, sleep,
   movement, …) as an editorial table of contents; each row opens
   its full page (the shipped page views, unchanged) as a push.

The compare becomes **THE JOURNEY SCRUB**: one drag across ALL of
her scans — every scan a haptic detent, dates turning as she
crosses them, release settling on the nearest scan. Browsing her
own journey becomes the interaction, not a feature.

## 3. What cannot move

Engines, stores, services, sync, analytics events, feature flags,
consent flows, the AppPhase machine, the three tabs, the keep
wall, onboarding v7, tokens/identity/voice (the brand is the
material this is built FROM), anti-shame floors, L3/L4/L6, the QA
door contract (semantics may adapt; doors never vanish), and the
suite's green. Walkers are updated in the same commit as any
surface they walk.

## 4. Verification

Per phase: build → drive on QA-iPhone16 → record every new motion →
frame-inspect → proof legs updated + green → full suite. The
mirror-check feel (in-hand, at a real mirror) joins the founder
device walk.

## 5. Founder review additions (extends the V-ledger)

- **V8 — the mirror check-in replaces the guided pose gate.** The
  pose gate demanded whole-figure framing; the mirror ritual
  accepts what her mirror shows (anchors + quality recorded when
  the figure is whole; the compare's alignment degrades gracefully
  otherwise — the L3 posture unchanged).
- **V9 — the carousel retires** (fore-edge, page-turn, page jump
  door semantics change to contents-push).
- **V10 — the countdown + ghost retire** from capture.

## 6. Shipped record (running)

### Phase M — THE MIRROR CHECK-IN (33bfff5)

Capture rebuilt around the ritual: `MirrorGate` (pure, 8 tests —
person + ~1s stillness fires; her thumb always fires; latch +
reset under test); the instrument speaks symmetric, mirror-legible
signals (the border inks with steadiness, a small ring fills, a
paper flash marks the shutter); countdown, ghost overlay, and the
whole-figure gate retired from the flow (V8/V10 — verdict/Arming
kept under their tests pending sign-off). The develop survives
untouched. The guided proof leg now proves the STILLNESS path (no
tap occurs in it); the P1 leg drives the thumb path.
**Also fixed:** the build-check ritual itself (grep "error"
matched Swift-6 warnings; head truncated real errors) and a stale
emitted-module interface that hid new types from the test target.

### Phase H — THE FRONT PAGE (ae646a5)

Home is the day's edition: the ink figure stands ON the paper (no
card — its ground IS the page; photographs keep the mat), the
change line sets beneath as the display headline, THE DAY follows
as pure typography (row discs and act discs died; the check is the
only mark). The page accepts an editorial scroll; the lead stays
above the fold with the next row peeking. Walkers taught to bring
below-fold rows up.

### Phase J — THE JOURNAL + THE JOURNEY SCRUB (d45c24c + close-out)

The carousel, fore-edge, and page-turn retired (V9; `JKPageTurn` /
`JKCarouselOffsetKey` uses removed — the struct kept-unused joins
the V-ledger holdings). Becoming reads vertically: the cover
spread (content-sized — XXXL never clips), HER RECORD as matted
plates, THE CHAPTERS as an editorial contents pushing the shipped
page views (chapter bar: back + kicker; masthead lives inside the
stack). `--uitest-becoming-page` pushes its chapter.
THE JOURNEY SCRUB: one drag across ALL scans — a haptic detent per
scan, the nearest scan's serif date beneath, release settles on a
scan; week thumbs glide the journey. Pairwise anchor alignment; no
number surfaces (L3).
**Found + fixed:** the trend canvas' trace-in (withAnimation over
raw @State inside Canvas froze mid-draw under a push — now drives
itself, the JKSilkSweep lesson) and chapter arming (appear/
disappear through a navigation transition unreliable — armed from
the push path; print-instrumented to ground truth, then removed).

### Verified across v10.1

496/496 units once and 495/496 twice (the documented OV5Store
flake, solo-green ×4 today) · all three scan proof legs green on
every phase tree · core + every-surface walkers solo green · the
guided ritual, the develop, the journey settle, and the chapter
draw-in verified on recordings/pixels · XXXL floors on consent,
the landing, the journal, the chapters · reel v2 (26.5s, all real
screen) in evidence/.

### D10 additions (founder voice review)

"find yourself in the mirror · or tap" · "hold still" · "THE DAY"
kicker · "THE CHAPTERS" / "YOUR RECORD" kickers · the journey's
a11y line ("your journey, scan by scan" / "showing {date}").

### Founder gates (v10.1 additions)

1. The device walk: the mirror ritual IN HAND at a real mirror
   (fire timing, flash visibility, haptic weight).
2. V8-V10 review; then delete verdict/Arming/coachingLine +
   JKPageTurn + JKCarouselOffsetKey + JKDayRail per dead-code law.
3. D10 drafts above.
