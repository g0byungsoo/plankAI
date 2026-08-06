# APP v11 — THE REBIRTH

**Status:** design approved 2026-08-05. Implementation not started.
**This document is the law.** It supersedes `docs/app_v10/*` entirely and
supersedes `docs/app_v9/04_DESIGN.md` on matters of visual form. Where any
older doc disagrees with this one, this one wins.

---

## 1. The brief

The founder's brief, verbatim in intent:

> I do NOT want a prettier version of the current app. I want the current app
> to disappear. The architecture stays. The business logic stays. The product
> experience is reborn.

Jeni is a **Body Transformation Operating System**. Every surface answers only
three questions:

1. Am I changing?
2. Why am I changing?
3. What should I do today?

Everything else is secondary.

The reference set that defines the target: Jeni's own onboarding (the visual
language), `simpleness.jpeg` (calm, hierarchy, near-zero chrome), MyFitnessPal
(**information architecture only**, never appearance), Lovi (premium native iOS
UX — navigation, sheets, component sizing), Apple Fitness Summary (the
chart-driven summary IA for Becoming).

The interface should feel closer to Apple Health, Notion Calendar, Gentler
Streak and Lovi than to any calorie tracker. Jeni is a premium consumer
product, not a productivity tool — emotional, editorial, human, calm.

**The execution mandate (founder, 2026-08-05): this is a DESIGN PASS, not an
implementation pass.** The architecture work is largely done. The cycle's
entire attention goes to aesthetics, interaction quality, hierarchy, and
craft — this is the pass where people stop saying "this looks AI-generated."
The verification loop in §11 is the core activity of the cycle and matters
more than adding anything new. Custom SwiftUI components, a custom chart
engine, custom transitions, and Metal shaders are all pre-authorised wherever
they genuinely improve the experience. Do not optimise for preserving
existing UI; optimise for making Jeni unforgettable.

---

## 2. The central finding

**The design language already exists in the codebase.** `Tokens.swift` already
carries the exact registers the onboarding is admired for:

| token | value |
|---|---|
| `Typo.questionHero` | JeniHeroSerif 34pt, italic punch, lineGap −17 |
| `Typo.displayHero` | JeniHeroSerif 38pt, lineGap −19 |
| `Typo.editorialEyebrow` | Fraunces 11pt, uppercase, letterspaced |
| `Palette.bgPrimary` | paper `#FCFAF7` |
| `Palette.textPrimary` | ink `#2A1F1E` |

Onboarding renders these. **The in-app screens invented a parallel vocabulary**
instead — mastheads, arc ribbons, beat discs, bento tiles, metric rings, plate
strips, page-turns. That divergence *is* the "everything after onboarding feels
like another app" problem.

Therefore v11 is **promotion, not invention**: lift the onboarding register into
a shared in-app kit, then rebuild the surfaces on top of it and delete the
parallel vocabulary.

---

## 3. Design laws (binding)

- **L1 — Typography first.** Hierarchy is carried by type size and weight, not
  by boxes, borders, or colour.
- **L2 — Whitespace is the divider.** No horizontal rules between sections. The
  only separator is a section header with air above it.
- **L3 — Almost no icons.** Rows carry words. Icons appear only where a word
  cannot do the job (tab bar, back chevron, drill-in chevron).
- **L4 — One primary action per screen.** At most one ink pill visible.
- **L5 — No borders, no shadows.** `JeniCard` is white on paper with radius and
  no stroke. Nothing else is a card.
- **L6 — Everything earns its place.** Remove beats add. If a element does not
  serve one of the three questions, it is deleted, not shrunk.
- **L7 — Never a number from a photo.** Body fat is never inferred from imagery.
  Provenance ladder only (Apple Health reading, else Deurenberg 1991 band from
  height/weight/age/sex). The consent promise holds. *(carried from v9 L4 / v10.4)*
- **L8 — Every number traces to a collected field.** No fabricated data, ever.
- **L9 — Voice law holds.** Lowercase casual, italic-Fraunces punch words, no
  hearts, no em-dashes between words, no "AI" in user copy, direct-coach
  register ("sugar intake", never "sweetness"). *(carried from the Jeni release)*
- **L10 — Anti-shame.** No red bars, no "over budget" framing, no earned-food
  grammar. Under-target is stated as room remaining.
- **L11 — ADA floor.** Contrast floors tested; VoiceOver labels on every
  interactive element; XXXL must not clip. *(carried from v9 04_DESIGN)*
- **L12 — Nothing appears; everything arrives.** Charts draw, bars grow,
  numbers count, sheets settle with physics, scrolling feels intentional.
  One orchestrated arrival per screen — choreography, never per-element
  confetti. Haptics reinforce moments; they never decorate.
- **L13 — Continuity with onboarding.** Leaving onboarding must never feel
  like entering another application. What transfers is the philosophy —
  editorial spacing, large confident headlines, quiet minimalism — not
  merely the fonts.

---

## 4. F — The editorial kit

Seven primitives. Nothing else may appear on a Jeni screen.

| primitive | responsibility |
|---|---|
| `JeniPage` | paper shell, 24pt gutters, generous top, scroll-gated header |
| `JeniSectionHeader` | 11pt uppercase letterspaced label — **the only separator** |
| `JeniHeadline` | serif line with italic punch; registers `.page` 34 / `.hero` 38 / `.band` 26; reuses `ItalicAccentText` |
| `JeniRow` | universal list row: 60pt, borderless, dividerless, iconless, full-width tap, render-only trailing state |
| `JeniPrimaryButton` | the ink pill — `JFContinueButton` promoted so onboarding and app share **one** button |
| `JeniSheet` | bottom-sheet grammar: paper, 28pt radius, grabber, headline register, exactly one primary action |
| `JeniCard` | the only card: white on paper, 20pt radius, no border, no shadow |

### Spacing scale

New editorial scale, additive to `Space`:

```
gutter     24
blockGap   20
sectionGap 44
heroGap    56
```

`Space.section` is currently 36, which is why in-app reads cramped against the
onboarding's rhythm. The kit uses `sectionGap 44`.

### The motion layer (L12 made concrete)

The kit ships with a motion vocabulary that animates the seven primitives.
Default SwiftUI transitions are banned on v11 surfaces.

```
Motion.arrive    opacity + 6pt rise, ~0.45s custom ease-out — the standard entry
Motion.stagger   60–80ms per index — lists, tiles, bars land one at a time
Motion.draw      ~0.9s ease-out — chart trace-in
Motion.settle    soft spring — sheets, physical elements, scrub release
```

- `.jeniArrive(index:)` — the arrival modifier; a screen orchestrates ONE
  arrival sequence on push, driven by a phase advanced in `.task` (never
  `withAnimation`-over-`@State` inside `Canvas` — v10.1 lesson).
- **Counting numerals** — hero numbers count to their value on arrival
  (`contentTransition(.numericText)` or engine-drawn), never just appear.
- **Tile → page** — Becoming tiles open their detail with a matched-geometry
  expansion, not a bare push.
- Haptic grammar, used sparingly: `tick` (detent, staggered bar landing) ·
  `land` (completion) · `swell` (hero moment, at most one per flow).
- Metal is already in the house style (`JKShaders`, `snapSweep`, `jkDawn`);
  new shaders are welcome where they genuinely improve the experience, never
  as decoration.

### Deleted with the kit

`JKMasthead`, `JKArcRibbon`, `BeatDisc`, bento tiles (`StepsBentoTile`,
`BreathworkBentoTile`), metric rings, sticker row badges, `JKDayRail`,
`ScrapbookCard`.

---

## 5. C — The chart engine

One `Canvas`-based engine, `JeniChart`. **SwiftUI Charts is removed from the
app.**

- Hairline strokes, 1.0–1.4pt. Ink for the live series, `hairlineCocoa` for
  context series.
- **No gridlines, no legends, no axis boxes.** Two end labels maximum, in
  `Typo.numeralMeta`.
- Forms: `.line` (trend) · `.band` (a range) · `.bars` (thin vertical hairlines —
  the `simpleness.jpeg` form) · `.spark` (tile-sized, axis-free).
- **Staged draw-on is the signature.** The line draws left→right on ease-out.
  On `.bars`, bars land **one at a time on a stagger, each with a soft haptic
  tick**. This is the interaction the founder called out and it is not optional.
- Scrub: drag reveals a value with detents and haptics.

### Implementation constraint (learned the hard way in v10.1)

Animation **must self-drive** from a phase advanced inside `.task`. Driving a
`Canvas` with `withAnimation` over `@State` freezes the trace-in under
navigation pushes.

---

## 6. H — Home, from zero

MyFitnessPal's information architecture, Jeni's skin. **Body progress is not on
Home** — it lives in Becoming.

`TodayView`'s 1,686-line layout is deleted. `CarePlanEngine`,
`ProgramDayPrescription`, `TargetsService` and every other engine are
**untouched**; Home becomes a thin renderer over the day model that already
exists.

```
  M   T   W   T   F   S   S      calendar strip — today filled ink,
  ·   ·   ·   ●   ·   ·   ·      past days tap into their receipt

  1,240                820 left  serif numeral + DMSans meta
  ──────────────────··········   one hairline bar, no colour

  protein   64 / 120             three thin bars, ink only,
  carbs     98 / 180             no colour coding, no red (L10)
  fat       41 / 60

  TODAY
  add protein before noon        JeniRow, reading register
  10 min movement
  body check-in                  the scan invitation when offered

  TOOLS
  snap a plate
  weigh in
  ask jeni
```

Below the fold, the evening ask, day receipts and the care-team reconciliation
moment survive with logic intact, re-dressed in the kit.

Home answers question 3 ("what should I do today?") and nothing else.

---

## 7. B — Becoming, chart-driven

Apple Fitness Summary's IA in paper and ink. Becoming answers questions 1 and 2.

```
  becoming                        page headline, serif
  Wednesday, Aug 5

  ┌──────────────────────────────┐
  │ BODY                         │   the hero read
  │ down 2.1 lb, and your        │
  │ waist reads narrower.        │
  │       ──\__/─\___  4 weeks   │   draws in on appear
  └──────────────────────────────┘

  ┌ WEIGHT   › ┐  ┌ PROTEIN   › ┐    every tile carries a live
  │ 164.2 lb   │  │ 112 g       │    .spark chart and drills into
  │ ╌╌╌\__     │  │ ▏▎▍▏▎▍▏     │    a full page
  └────────────┘  └─────────────┘
  ┌ FIBER    › ┐  ┌ SUGAR     › ┐
  ┌ SODIUM   › ┐  ┌ SLEEP     › ┐
  ┌ STEPS    › ┐  ┌ MOVEMENT  › ┐

  BODY PROGRESS
  [ first ] [ latest ]              the two plates + the compare drag
```

### The nutrition set — division of labour with Home

Home carries the **daily window**: calories, protein, carbs, fat. Becoming
carries the **weekly nutrients that explain the body**. All eight are captured
end-to-end today (food-vision EF → USDA / OpenFoodFacts / canonical pantry →
`food_logs.payload` jsonb), so every tile is provenance-backed (L8).

| tile | why it earns a tile |
|---|---|
| **protein** | muscle preservation — the wycherley 2012 mechanism the whole plan rests on |
| **fiber** | satiety; explains why a week felt easy or hard |
| **sugar** | the direct-coach register calls this *sugar intake*, never "sweetness" (L9) |
| **sodium** | **explains scale noise** — the single best answer to "why did the scale jump?" This tile is what makes the app read as smart rather than decorative. |

Saturated fat, carbs and fat live inside the drill-in pages, not as top-level
tiles — they do not independently explain weight change.

Each tile drills into a full page: the large chart, the read in words, and the
mechanism. Never a bare number.

### What Becoming loses

`BecomingView`'s 2,522-line journal — the cover, HER RECORD, THE CHAPTERS, the
page-turn and the story-pager — is **deleted**. The compare/scrub physics from
THE JOURNEY SCRUB is genuinely good and **survives**, relocated inside BODY
PROGRESS where it belongs.

---

## 8. Documentation cleanup

The founder's instruction: organise the old design docs so future agents are not
confused, and delete what is no longer relevant. Everything below is recoverable
from git history.

### Deleted

`docs/app_v2` · `docs/app_v3` · `docs/app_v4` · `docs/app_v5` · `docs/app_v6` ·
`docs/app_v7` · `docs/app_v10` · `docs/archive/` (≈100 files, explicitly "history,
not guidance" — the single largest confusion source) · `docs/onboarding_v5` ·
`docs/onboarding_v6` · `docs/retention_v1_1_2` · `docs/snap_food_fix` ·
`docs/superpowers/specs` + `docs/superpowers/plans` (all shipped or superseded) ·
the loose June/July research one-offs · **and the rest of `docs/app_v9/`**
(`01_AUDIT`, `02_PLAN`, `03_DECISIONS`, `05_BUILD` — the v9 programme shipped;
only `00_MISSION.md` and `04_DESIGN.md` survive as standing law).

### Kept

| path | why |
|---|---|
| `docs/app_v8` | the care platform is live product surface |
| `docs/app_v9/00_MISSION.md`, `04_DESIGN.md` | safety laws + the design constitution |
| `docs/app_v11` | this document |
| `docs/onboarding_v7` | current onboarding law |
| `docs/jeni_release` | brand identity law |
| `docs/STATE.md` | authoritative state |
| `docs/THEME.md`, `her75_typeface_spec` | typography + narrative reference |
| `docs/glp1_strategy_2026_06_16.md` | compliance floors |
| privacy / terms / App Store metadata | legal + release |

`CLAUDE.md`'s project-status block collapses from nine stacked eras to the
current era plus a short history line.

---

## 9. Carried forward (still binding after the cleanup)

These constraints outlive the docs that recorded them and are restated here so
deleting those docs loses nothing:

- Body fat never comes from a photo; the provenance ladder and consent promise
  hold (L7).
- `WaistCrop` is tested law: the fixed window aspect, the `.up` normalisation of
  EXIF-oriented stills, the sensor-landscape `.right` fix. Do not re-derive.
- `BandProfile` reads silhouette → per-row width → ribs/navel/lower-abdomen →
  words. 3% noise floor. Fuller weeks are never scolded. Never a number.
- Body scan records are local-first; cloud backup defaults **off**.
- Fasting vocabulary never renders. Observed-never-prescribed is enforced in
  code.
- No drug brand names, no drug-equivalence claims, no first-party numeric
  weight-loss claims.
- The clinic surface is internal dev alpha with no BAA — never "HIPAA
  compliant".

---

## 10. Not in this cycle

- **S — Body Scan.** The illustrated instrument (rear camera in a 30–40% window
  inside a drawn figure that teaches positioning without words) and the magical
  result page (body progress, estimated body fat clearly labelled, comparison
  with the previous scan, weekly change, confidence, what changed, today's
  recommendation).
- **N — Navigation.** The Lovi centre action: tab bar → blurred scan chooser
  offering BODY and PLATE.

Both build on the kit and the chart engine delivered here.

---

## 11. THE LOOP — verify your own design

This section is the core of the cycle. The founder cares more about this loop
than about anything new being added. Never assume the work looks good — prove
it, on the simulator, with your own eyes.

### The loop

```
build → install → DRIVE the flow yourself → record video
      → dump frames (ffmpeg) → inspect frames → compare neighbours
      → find issues → fix → repeat
```

Exit condition: you honestly cannot find another obvious design issue. Not
"one pass was done" — *cannot find another*.

Tooling verified 2026-08-05: ffmpeg installed, `simctl io recordVideo`
available, dedicated `QA-iPhone16` sim booted. SE + XXXL walks ride the same
loop (L11).

### The hunt list (what a frame inspection looks for)

Visual glitches · layout inconsistencies · awkward spacing · typography
issues · visual noise · animation hitches · transition pops · clipping ·
alignment problems · hierarchy problems.

And the AI-generated tells, hunted by name: uniform card grids ·
default-transition pops · mechanically even spacing where optical spacing is
needed · centred-everything layouts · decoration carrying no information ·
gradient soup.

### The gate (per major screen)

Ask, in order: *Would Apple ship this? Would it hold up in a WWDC keynote?
Would Alan Dye reject it?* If the answer is "probably not" — delete it,
redesign it, try again. No emotional attachment to the current
implementation, including the one this cycle just built.

### Evidence required before the cycle is called done

- Recorded walks of Home and Becoming (arrive, scroll, drill-in, scrub) with
  frame analysis notes — at default, SE, and XXXL.
- Frame-level proof of the chart draw-on and the staggered bar landing with
  its haptic.
- Full unit suite green; UI proof legs run solo.
- A written record of what was deleted and what replaced it.
