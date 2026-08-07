# v12 THE CRAFT PASS — the evidence (2026-08-07)

THE LOOP's record: what the film caught, what changed because of it.
Commits: `f59274b` direction · `7b51454` C1 kit · `2a573c7` C2/C3
home · `62f9ef4` C4/C5 becoming · `b74259d` C6 detail · `855fdf2`
C7/C8 moments+care.

## The instrument change (this pass's tooling discovery)

**Synthesized XCUI drags cannot scroll this sim runtime.** Proven
with a three-mechanism probe (`testGalleryProbe`: app.swipeUp,
scrollView.swipeUp, coordinate press-drag — all three left the page
byte-identical) against a page whose content provably spanned 2,391pt
in an 852pt viewport. This is why the house's `--uitest-*-bottom`
proxy-scroll doors exist. The pass's answer: **self-driving tour
doors** — `--debug-gallery-tour`, `--uitest-walk-strip`,
`--uitest-walk-scope`, `--uitest-open-tile <kind>`,
`--uitest-mark-lead`, `--uitest-land-plate` (now seeds a real plate)
— deterministic scenes the camera rides along. Taps still work;
recordings pair with `simctl io recordVideo` + ffmpeg `-vsync 0`
(every dumped frame = a real screen change; static holds emit
nothing).

Second discovery: **a page-level `.onTapGesture(count: 2)` swallowed
every synthesized drag** (the gallery's restart gesture). It died.

## Frame-caught fixes (the loop earning its keep)

1. **The six scope words overflowed the gutter** (gallery film) —
   paddings tightened 13→11, spacing 4→2; the horizontal scroll
   stays as the SE/XXXL floor.
2. **Below-fold choreography fired invisibly at page load** (design
   flaw found while reasoning over tour frames): everything armed on
   `arrived`, so a chart below the fold was already dead when she
   reached it. THE VISIBILITY GATE: glance pieces + JeniChart +
   JeniCountingNumeral arm on `arrived AND first-visible`.
3. **The landed plate reset the numeral to zero** (code-read during
   C2): the old `id(landedPulse)` re-mounted the numeral. Now the
   value MORPHS — film shows 860 blurring into 1,100 with rolling
   digits while "613 left" counts down to "373 left".
4. **Bars landed in the trace's last breath on sparse wide windows**
   (3-months film: three logged days sat in slots 28-30, so nothing
   moved for 90% of the draw) — the landing clock now runs over REAL
   bars, not slots.
5. **Waiting rows lied at bucketed scopes** ("logging · 1 of 3
   days" while counting weeks) — rows now count what the scope
   counts ("1 of 3 weeks").
6. **The detail page title ran behind the island** (weight-page
   still) — top air Space.xl.
7. **The provenance block hid under the floating tab bar** (calories
   still) — 120pt bottom clearance.
8. **Scrolled serif collided with the clock on Becoming** (tools
   capture) — Becoming inherits Home's masthead scrim; both gain
   iOS 26's soft scroll edge, availability-gated (law §13).
9. **The lesson-title status ellipsized ugly** ("…has a scri…") —
   scale floor 0.78.
10. **Scope-change re-traces ticked 7-30 haptics** (code-read):
    bar-landing ticks are first-trace-only now.

## What the film PROVED (the keeps)

- The centerpiece reads in three seconds: numeral + "613 left" +
  ring fraction + protein bar + chemistry whisper (home2 film).
- The lead mark cascades: card dims + check draws + TODAY chip rolls
  0→1 + the STRIP's today disc draws its own check — one action,
  one connected system (home2 f_0480).
- The recap slides from the side the strip travelled, both
  directions (D13; home2 f_0700).
- The scope capsule morphs mid-travel on film (bec2 f_0500) while
  tiles keep identity and re-count in place.
- The insight card is R6 in our voice: "1 · of 3 days" + lettered
  week dots + "you reached your 90g floor *1 day* this week."
  (bec2 f_0380).
- The evening close opens on "12 · of 140 days" at 96pt, counted,
  then types; the receipt ledger and feeling words follow (evening
  f_0620).
- Care-connected Becoming leads with YOUR CARE, visit packet first,
  clinical register (care_becoming still).

## The chart craft verdict (founder's mid-pass steer)

No library. Swift Charts stays banned (v11 law) — the craft moved
into the one engine: monotone-cubic smoothing (no overshoot — a
curve that cannot invent a value), 2.2pt round-cap ink, 10% wash,
context lines 1.5pt @20%, bars ≤24pt with rounded data-ends and a
SQUARE baseline on a grounding hairline, today-in-full-ink faces
(`emphasizeLast`), the 8pt surface-ringed end dot. Weight hero
before/after is the proof pair (baseline_becoming.png vs bec2).

## Verification (final tree)

- Unit suite: see §below (recorded when green).
- Legs solo: testHomeAnatomyDayAndEvening ·
  testGalleryWalk (tour) · testZeroDataFirstRun.
- XXXL captures: Home + Becoming at accessibility XXXL.
- Reduce Motion: every new piece has an explicit RM path
  (ring/bars/dots/numerals jump to final; tours still move by
  scroll only).

## Open (honest deferrals)

- The insight pager pages full-width; a peek-next-card variant was
  considered and parked (TabView page style keeps the native snap;
  a custom scroll-target build is a later refinement).
- Sleep/steps hold 7-day windows at every scope (the services store
  a week); span labels say so. Widening the stores is engine work,
  not presentation.
- ReSigningView (weekly review) still opens in its own v4-era
  grammar; the numeral moment is built and proven — applying it
  there is a small follow-up.
- The scan chooser, chat, and food rail keep their shipped
  registers (design-language migration list §16 unchanged).

---

# v13 — THE REDUCTION PASS (same day, founder's second brief)

"Engineers ask how to show information; designers ask what can
disappear." Same loop, opposite instinct. The cuts, each verified on
fresh captures + the squint test (64px blurred renders — one hero
per page, hierarchy legible as blobs):

1. **The dateline left the caps register** — two tracked-caps meta
   lines read as a fourth section header; now one lowercase line
   ("day 12 of 140 · finding steady"). Headers alone wear caps.
2. **No track without a collected target** — carbs/fat resting
   hairlines died (decoration implying unmeasured bars); the layout
   answered with luck-made hierarchy: protein's floor bar stretches,
   carbs/fat hug as quiet numbers.
3. **Tool glyphs died** — words carry identity, state lines carry
   life; an icon was a second voice saying the same thing.
4. **Supporting + offered tasks became ROWS** — the lead alone earns
   a container (grouping, not framing). Home's containers: 4 → 2.
5. **Becoming's hero left its card** — typography + full-width chart
   ON the paper, the way the consult opens. The "needs 4 logged
   days" apology left the face (a hero states, never apologizes;
   the requirement still lives in the expanded read).
6. **Per-tile chevrons died** — eight arrows saying "tap me" eight
   times; the tile is the affordance.
7. **Detail pages lost all three caps labels** — WHAT THE PLAN DOES /
   WHY IT MATTERS / WHERE THIS COMES FROM were headers explaining
   one-sentence content; the sentences group by air, provenance
   closes the page as a whisper.
8. **The language sweep** — "can speak" / "a quiet page" / "not
   written yet" / "(never your worth)" / the weather metaphor all
   rewritten direct; the C5 em-dash bug fixed; "18 days of showing
   up, unbroken" → "you've shown up 18 days in a row".
9. **Motion shortened** — arrive 0.5→0.42, draw 0.90→0.72, stagger
   0.07→0.055, settle/morph tightened. Effortless, not theatrical.

Verified: build green · testHomeAnatomyDayAndEvening solo green ·
strip-walk film clean with the new language ("nothing logged this
day." / "the full record is in becoming") · squint renders hold on
Home, Becoming and the weight detail page.
