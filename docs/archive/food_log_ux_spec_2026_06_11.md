# Food Journal UX Spec — v1.0.10 candidate (2026-06-11)

Source study: docs/ref_fable_calorie_app_article_2026_06_11.md (Morsel, ex-Apple
designer) + 5 screenshots. Brand locks: THEME.md, IMG_6339 Becoming register,
anti-shame food doctrine, no red, lowercase, hearts terminal-only, no em-dashes.
Italics below are notated `*word*`; in code they are ItalicAccentText, never
markdown markers.

## 0. The translation thesis: catalog → scrapbook

Morsel is a **magazine catalog**: AI studio dishes floating on warm white,
whitespace-only separation, zero cards. Its beauty depends on image consistency
JeniFit will never have. Her photos are 480px thumbnails, kitchen lighting,
half-eaten plates, and many entries have no photo at all. Floating those on
cream reads broken. Framed as **scrapbook polaroids**, the same photos read
intentional: a diary documents, a catalog advertises. We keep Morsel's
hierarchy machine (eyebrow date / serif day word / quiet numerals / whitespace
rhythm, zero card chrome) and swap its image language for ours.

### The plate system (used on every surface)
- **Polaroid matte**: center-crop square, 14pt continuous corners, 5pt matte
  border in `#FFFFFF` (pure white pops on cream; bgElevated is too close),
  0.5pt `divider` hairline outside the matte, warm rose `PlankShadow`.
- **Harmonizing pass** (render-time, cheap): overlay `bgPrimary` at 6% +
  saturation +0.05. Pulls mixed kitchen lighting toward the cream canvas so
  eight photos from eight lamps still read as one spread.
- **Rotation rhythm**: deterministic by index within day: −2°, +1.5°, −1°,
  repeat. Never 0° in the collage (0° is reserved for the meal-detail hero
  settling). Scrapbook asymmetry per THEME §9.
- **Two sizes only**: `hero` 200pt square (first photo entry of the day) and
  `standard` 104pt square. No alternating-scale cleverness; the article's own
  steering note ("alternating layout is a bit cheesy") agrees.
- **No-photo tile** (the load-bearing piece): same matte shape and size slot,
  cream `bgElevated` fill instead of a photo, dish name set centered in hero
  serif italic lowercase 15pt cocoa, 3-line max, kcal caption beneath inside
  the tile. One tiny line-art glyph top-corner inside the matte, 14pt, by
  source: `sticker_camera_lineart` never here; use fork.knife (im_out),
  pencil (quick_add/text), continuing FoodLogTimelineView's source map. It
  reads as a handwritten recipe card slipped between photos. NEVER a grey
  placeholder, never an icon-only bubble. A no-photo tile can take the hero
  slot if the day has no photos: hero-size card, name at 20pt.
- **Caption under every tile** (outside the matte): name lowercase
  `caption` cocoa, 1 line truncated, then `kcal` in `caption` textSecondary.

## 1. The journal timeline (full screen, from Becoming)

```
┌──────────────────────────────────────┐
│ your *journal*                ⌃share ✕│  existing log header idiom
│ this week · averaging 1,540 cal      │  eyebrow rollup, textSecondary
│                                  🍒  │  cherries overhang (HomeFoodCard kin)
│ WEDNESDAY · JUNE 11                  │  eyebrow, +6% tracking, textSecondary
│ today                      1,460 cal │  serif 34pt   ·   caption quiet total
│ ┌────────────┐                       │
│ │            │ −2°  ┌─────┐ +1.5°    │  hero 200pt + standard 104pt
│ │  photo     │      │photo│          │
│ │            │      └─────┘          │
│ └────────────┘      iced latte       │
│ greek yogurt        90 cal           │
│ 320 cal                              │
│ ┌─────┐ −1°  ┌─────┐ −2°             │
│ │ the │      │photo│                 │  no-photo recipe-card tile sits
│ │bagel│      └─────┘                 │  in the same rhythm
│ └─────┘                              │
│                                      │
│ TUESDAY · JUNE 10                    │
│ yesterday                  1,710 cal │
│ ┌────────────┐  ┌─────┐              │
│ └────────────┘  └─────┘       ( + )  │  floating add, bottom-right (keep)
└──────────────────────────────────────┘
```

- **Day section anatomy** (Morsel's, re-voiced): eyebrow full date, serif day
  word below at 34pt lowercase ("today" / "yesterday" / "tuesday"), total
  right-aligned on the day-word baseline.
- **Anti-shame reasoning on the daily total**: the number itself is her data;
  the verdict framing is the harm. So the total renders in `caption`
  textSecondary (metadata register, smaller than the day word, no bar, no
  target, no "of 2,000") while the **weekly rollup is the only evaluative
  voice** and it speaks in trend: "this week · averaging 1,540 cal". Trend-as-
  hero doctrine, inverting Morsel where the cal total is co-hero with the day.
- **Collage composition by count**: 1 entry = hero alone, left-aligned, day
  breathes (whitespace IS the design, do not center). 2 to 3 = hero left +
  standards stacked right column. 4+ = hero anchors row one, remaining flow in
  a 3-across grid (104pt + 16pt gutters), odd rows offset +12pt vertically for
  the stagger. Whitespace-only separation between days: 44pt, no dividers, no
  cards anywhere on this screen (the current FoodLogRowView card-rows retire).
- **Empty past days are skipped entirely**, like blank scrapbook pages you
  flip past. No "no entries" rows, no guilt gaps. If **today** is empty, the
  today section renders an invitation instead of a collage: serif italic
  "today's page is blank." + caption "scan your first plate." +
  `sticker_camera_lineart` 36pt at the right margin.
- Tap tile → meal detail (transition T2). Tap day header → day page.
  Long-press tile → existing remove confirmation dialog.

## 2. The day page

```
┌──────────────────────────────────────┐
│ ← journal                            │  caption back link, lowercase
│ WEDNESDAY · JUNE 11                  │  eyebrow
│ today                                │  serif 42pt (heroHeadline register)
│                                      │
│ 1,460                                │  display serif Light 56pt, −1% track
│ cal so far                           │  caption textSecondary, no target #
│ ───────────●────┊───                 │  2pt hairline: accent fill, divider
│                                      │  track, tick ┊ at her line; past the
│ *a lighter day* ♡                    │  tick fill desaturates, NEVER red
│                                      │
│ 64        142        48              │  DM Sans SemiBold 20pt
│ protein   carbs      fat             │  eyebrow labels, grams implied
│ ▂▂▂▂▂     ▂▂▂        ▂▂▂▂            │  MacroMicroBars idiom (D3.A), ticks
│                                      │
│ her meals, chronological:            │
│ ┌────┐ 8:14am   greek yogurt   320   │  56pt mini-polaroid (or recipe
│ └────┘          p22 · c34 · f9      │  card) + time + name + kcal row
│ ┌────┐ 12:40pm  the bagel      290   │
│ └────┘                               │
└──────────────────────────────────────┘
```

- **Translating "300 of 2,000 cal"**: the big numeral stays (her data, earned),
  the spoken target goes. "of 2,000" becomes a silent tick on the hairline,
  continuity with WeeklyAvgBar + MacroMicroBars which already do exactly this.
  No "remaining" number anywhere. Caption is temporal ("cal so far"), not
  evaluative.
- **The earned mark** (visual register for the program expert's deficit-day
  gate): when the gate passes, one line fades in under the hairline,
  `stateGood` sage, hero serif italic 15pt: "*a lighter day* ♡". Heart is
  terminal punctuation, allowed. Appears only when earned; absence is silence,
  there is no opposite state, no warn color, no "over" line. User-visible copy
  never says "deficit" (post-Ozempic vocabulary lock). Entrance:
  `entranceSoft` + soft haptic, reduce-motion snaps.
- Macro row is Morsel's bold-number tiny-label idiom, already half-shipped in
  HomeFoodCard; reuse targets proteinTargetG etc.
- Meal rows: 56pt mini version of the plate system (matte 3pt, corners 10pt,
  0° rotation at row scale), time in caption monospacedDigit, kcal right-
  aligned. Tap → meal detail (T2 from here too).

## 3. Meal detail

```
┌──────────────────────────────────────┐
│ ✕                                    │
│    ┌──────────────────────────┐      │  full-width polaroid, 8pt matte,
│    │                          │ −1.5°│  18pt corners, rose shadow; settles
│    │       her photo          │      │  from collage rotation via T2
│    │                          │      │
│    └──────────────────────────┘      │  no-photo: hero recipe card, name
│                                      │  at serif italic 24pt centered
│ greek yogurt with honey              │  serif 28pt lowercase
│ 320                                  │  display Light 48pt + "cal" caption
│ 22% of today · 8:14am                │  caption textSecondary, middots
│                                      │
│ protein  ▬▬▬▬▬▬▬          22g        │  4pt capsule bars, accent fill,
│ carbs    ▬▬▬▬             34g        │  divider track, right-aligned grams
│ fat      ▬▬               9g         │  DM Sans Medium 13pt monospacedDigit
│                                      │
│ ( edit )  ( new photo )  ( remove )  │  quiet pills: 1pt divider stroke,
│                                      │  caption cocoa; remove in stateBad
└──────────────────────────────────────┘
```

- Morsel's "9% OF THE DAY · 20:01" survives almost verbatim, re-voiced
  lowercase: "22% of today · 8:14am". The percent is context, not verdict;
  it answers "how big was this" without scoring her. Hide the percent while
  it is the day's only entry (100% reads absurd, render time alone).
- Hero is the one place a polaroid earns full width. The matte thickens
  (5→8pt) and rotation relaxes to −1.5°: the photo you pull out of the book
  to look at. No sticker on this screen when a photo exists; one
  `sticker_star_lineart` 28pt near the top-right margin on no-photo entries.
- Macro bars scale relative to the largest of the three (Morsel's trick),
  not to targets: this screen describes the meal, it doesn't grade it.

## 4. The Becoming embed

Founder rejected dot map + ledger. The teaser is the **plate fan**: her three
most recent photo polaroids, 64pt, fanned −8°/0°/+8° with 24pt overlap, sitting
in the existing "plates" block of the Becoming bento (IMG_6339 slot).

```
│ plates                               │  eyebrow (existing)
│  ⧉⧉⧉   3 days logged                 │  fan + DM Sans Medium 15
│        protein led, 1 of 3 days      │  existing caption line stays
│        your *journal* ↗              │  caption link, italic punch
```

- Fewer than 3 photos: fan whatever exists; zero photos: single 64pt recipe
  card of the latest entry; zero entries: `sticker_camera_lineart` 32pt +
  "no plates yet". Never an empty grey slot.
- Tap anywhere in the block → journal via transition T1.

## 5. Type, spacing, motion

**Type ladder** (existing tokens first; serif = Jeni Hero Serif display face)
- journal header: existing "your *log*" idiom renamed "your *journal*"
- weekly rollup + eyebrows: `Typo.eyebrow` 12pt caps +6% tracking
- timeline day word: serif 34pt lowercase (questionHero register)
- day-page day word: serif 42pt (heroHeadline register)
- big numerals: `Typo.display` Light 56pt (day page), 48pt (meal detail),
  −1% tracking, monospacedDigit, dynamicTypeSize clamp at accessibility1
- meal name: serif 28pt; tile captions + metadata: `Typo.caption` 13pt
- macro numbers: DM Sans SemiBold 20pt; labels `Typo.eyebrow`

**Spacing**: screenPadding 20 · day-section gap 44 (whitespace is the
separator) · header-to-collage 16 · tile gutters 16 · stagger offset 12 ·
caption-to-tile 6 · day-page numeral block bottom 24.

**Three transitions worth custom work** (the "tiles flow between views" lesson)
- **T1 fan → journal**: matchedGeometryEffect on the 3 fan polaroids flying
  from Becoming into their day-collage positions while the journal canvas
  fades up (`entrance`); remaining tiles cascade with `stagger` 0.10.
- **T2 tile → meal detail**: matched-geometry photo scales tile → hero while
  matte animates 5→8pt and rotation eases collage-angle → −1.5°;
  `gentleSpring`. Metadata below fades in `entranceSoft`. Reverse on dismiss.
- **T3 the landing**: after a scan saves, the new polaroid drops into today's
  collage scaled 1.15 → 1.0 with `gentleSpring` + soft haptic (sticker-landing
  idiom). The journal is where logging feels rewarded.
- Reduce-motion: all three snap to final frames; T3 keeps the haptic.

**Sticker placement** (≤3 per screen, never overlapping, edge-hugging)
- journal: `sticker_cherries` header top-right overhang (HomeFoodCard
  continuity) + `sticker_camera_lineart` only on today-empty state.
- day page: one painterly, `sticker_strawberry` 34pt bottom-right margin −8°.
- meal detail: none with photo; `sticker_star_lineart` on no-photo only.
- Becoming embed: camera line-art on zero-entries only. All decorative:
  allowsHitTesting(false), accessibilityHidden(true).

**Accessibility**: every tile `accessibilityElement(children: .combine)`,
label "name, kcal calories, time"; collage order follows logged time; fan is
one element labeled "your journal, N days logged".
