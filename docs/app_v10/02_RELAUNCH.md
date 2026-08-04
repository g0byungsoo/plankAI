# app v10.2 — THE RELAUNCH (the waist record)

**Status: IN PROGRESS (2026-08-04, feat/app-v2). The founder's
third brief of the day: "pretend none of it exists… Apple keeps
everything underneath and redesigns the application for a
late-2026 launch." The one concrete new product directive: the
capture takes ONLY the abdomen and waist — consistency over
completeness. This file extends `01_REINVENTION.md`; laws carried.**

## 1. Why the waist changes everything

The waist is the region she already checks in the mirror; it is
where change shows first; and it is exactly what a front camera
sees at a natural chest-height hold. Capturing only the band:

- makes week-over-week **consistency** achievable (one region, one
  guide, no full-figure staging);
- strengthens **L4** (no face, no full body — the record holds a
  band of a torso and nothing else);
- turns every record image into a **wide editorial plate** — the
  photography the whole app is built from;
- keeps **L3** intact (the band is evidence; nothing is measured).

## 2. The system

- **`WaistCrop`** (pure, unit-tested): pose joints → the abdomen
  band rect in image space (between the ribs' lower reach and the
  hip crest, derived from shoulder/hip joints); a centered default
  band when no joints exist. `fire()` stores ONLY the crop — the
  full frame is never written.
- **THE BAND** replaces the ghost: two mirror-legible hairlines
  (a soft field between) mark where her last band sat; she aligns
  her waist into it. Stillness or her thumb fires (MirrorGate
  unchanged). Guidance is the band + at most one small word.
- **The record** gains an additive `region` ("waist"; absent =
  full-figure era). Old full-figure scans coexist honestly; the
  journey blends any pair via the same anchor transform (band
  top/bottom/centerX ride the existing anchor fields).
- **The plate**: silhouettes render frameless on the paper
  everywhere (their ground IS the page); photograph-mode keeps the
  mat. Home's hero and becoming's cover become the wide plate +
  the headline; THE RECORD in the journal stacks recent plates
  full-width, Photos-like; the journey stage is the wide plate.

## 3. V-ledger additions

- **V11 — waist-only capture.** New check-ins record the band, not
  the figure. The full-figure era remains in her record untouched.
- **V12 — the ghost retired for THE BAND** (a guide, not an
  overlay of her body).
- **V13 — frameless silhouettes app-wide** (mats remain for
  photographs only).

## 4. Verification

The house ritual: pure-math tests for the crop; the proof legs
re-pointed at the band ritual; recordings frame-reviewed; XXXL;
the suite green; reel v3.

## 5. Shipped record

### W — the waist record, end to end (one pass)

- **`WaistCrop`** (pure, 10 tests): joints → the abdomen band on
  the shoulder→hip axis; the centered default when personless; the
  crop = the band × a centered horizontal window (±33% around the
  body's center — no dead camera margins); a degenerate crop never
  breaks a keep. `fire()` stores ONLY the crop (L4 strengthened);
  the band's bounds ride the existing anchor fields, so the
  journey's alignment works unchanged across eras.
- **`BodyScanRecord.region`** (additive): "waist" for new
  check-ins; absent = the full-figure era. Both coexist; nothing
  rewrites (L2).
- **THE BAND** replaced the ghost (V12): two dual-tone hairlines
  (ink on a paper halo — legible over a dark room, a bright
  mirror, or bare paper) with a soft field between, seeded from
  her last waist scan's band, centered default until. Captions:
  "find your waist in the band · or tap" / "hold still".
- **The wide plate everywhere**: heroes and thumbs follow each
  plate's own aspect; ink renders frameless on the page (V13 —
  photographs keep the mat); the zero-scan invitation is a dashed
  empty plate; consent + intro speak the waist line (D10).
- **Seeds** wear the waist era (narrowing ink bands, region +
  band anchors); the pose script's joints match the drawn figure's
  proportions so the sim's crop lands on the drawing's waist.

**Verified:** 498/498-scope unit suite green per the gate runs
(WaistCrop 10 + MirrorGate 8 among them; the documented flake's
status per run recorded in the session) · all three scan proof
legs green on the final tree · the band guide, the developed
waist plate, and both heroes frame-verified · reel v3.

### v10.3 — the founder's correction: the REAR camera

The mirror is for FRAMING; the rear camera is for CAPTURE. She
faces her bathroom mirror, screen toward her, back lens toward the
glass — the phone records her reflection at full sensor quality
while she frames on the screen she is already looking at. Session:
`.back` default, no mirroring (her mirror already flips her — the
record reads exactly as her mirror does), no camera switch (a flip
door returns only if the device walk demands one). Repeatability
gains its word: when her live band's thickness clearly drifts from
last week's (>±25-30%), the caption says "a step back" / "a touch
closer" — the band's thickness is the distance proxy; never a
number (L3).

Plus the de-chrome pass the brief asked for: the cabinet's rings
died (bare ink marks + whispered words), the check circles
lightened (22pt, 18%), the gear receded, the contents rows lost
their chevrons — the serif line is the affordance.

**Verified:** 3/3 scan proof legs · core walker 1/1 · 505/506
units (the documented flake) · the quiet Home frame in evidence/.

### v10.3b — the device walk's findings, fixed

The founder's real-bathroom walk caught what no simulator could:

1. **The "halved" scan** — two orientation bugs. (a) The pose
   buffers were handed to Vision as `.up` while a portrait app's
   BACK camera delivers sensor-landscape frames → every joint (and
   so the band) lived in a rotated space. Now `.right`. (b) The
   still's EXIF orientation: cropping the raw cg buffer with a
   portrait-space rect mangled the frame. `WaistCrop.image` now
   normalizes to `.up` first — proven by a unit test that builds a
   camera-style rotated image and asserts the crop reads DISPLAY
   space (11 WaistCrop tests).
2. **"No result screen"** — the arc ended at keep and dumped to a
   list. THE KEPT MOMENT now follows every keep (the pattern the
   category's best share — ZOZOFIT's compare-first results,
   MeThreeSixty's immediate on-device result): "kept." · the
   dateline · last time (smaller, quieter) beside today · the
   record's standing line · done. First scans read "one scan kept.
   the next one starts the comparison."

**Verified:** WaistCrop 11/11 (incl. the oriented-photo proof) ·
3/3 scan proof legs (now walking keep → kept → done → record) ·
506/507 units (the documented flake) · the kept frame in
evidence/. The next device walk should confirm: the band lands on
the waist, the plate is whole, the kept comparison reads.

### Founder gates (v10.2 additions)

1. The in-hand mirror walk: does the band sit where her mirror
   check happens; is ±33% the right window; is the band's field
   visible enough over a real bathroom.
2. V11-V13 review.
3. D10: the waist lines above.
