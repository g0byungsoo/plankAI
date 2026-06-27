# Becoming tab restructure: the her75 designer brief
2026-06-10 · senior product designer, shipped her75 · for the JeniFit program pivot

Scope: design direction only. Final module list pending the two parallel research
briefs; this document defines the *architecture and registers* any module list
slots into.

---

## 1. Decoding her75's "premium journey" surfaces

What the screenshots actually do, mechanically:

**The headline IS the interface.** Every her75 screen opens with a 2-line Didone
serif at enormous scale ("Become that *girl*", "Make *it* official", "Follo*w*
your *routine*"), tight leading, italic swapped mid-phrase, sometimes mid-WORD
(the *w* in "Follow", the *t* in "Start"). Black on white, nothing competing.
The headline carries 60% of the screen's emotional work before any UI renders.

**The day-one card is a paper artifact, not a widget.** Small white rounded card
floating over a full-bleed photo: serif italic "day one", a date range
("mar 16 → apr 24"), then a numbered list with oldstyle serif numerals. It reads
like a page torn from a planner. Crucially: the END DATE is printed. The journey
has a shape, a horizon, a finish line you can screenshot.

**Numbers are typography, never charts.** "Day 75." "+6,256 joined." Serif
numerals in lists. Dates. That's the entire quantitative vocabulary. The day
count is the only metric, and it's set like a magazine folio.

**Photos are aspiration mood, not data.** The 4-up filmstrips (gym, vegetables,
journal, bed) are Pinterest-board texture proving the lifestyle exists. Real
photography, warm, no stock-gloss. Sticky-note numerals on the checklist bring
paper-craft warmth into an otherwise stark layout.

**The share artifact is the product.** "Make it official" frames the day-one
card inside an IG-story chrome ("you · 2min"). The progress surface is designed
backwards from the screenshot she'll post.

**Conspicuously ABSENT:** line charts, bar charts, percentages, rings, progress
bars, streak flames, badges, XP, color-coded deltas, dashboard grids, ANY
gamification chrome. her75 tracks a 75-day transformation with zero graphs.
The restraint is the luxury.

---

## 2. What reads 2026 vs 2019-fitness-app for this cohort

| 2019 fitness app | 2026 editorial (her75 / this cohort) |
|---|---|
| dashboard grid of equal tiles | one hero per viewport, magazine scroll rhythm |
| chart walls, axes, gridlines | one artifact-styled chart, annotated like a print |
| percentage rings everywhere | the day count as a serif folio |
| green/red delta arrows | direction in language ("trending down, gently") |
| streak flames + badges | a dated paper card she can post |
| BMI and body-comp prominence | identity statements, NSVs, horizon dates |
| uniform card chrome | a chrome LADDER (hero → card → row → footnote) |
| data density = value | whitespace = value, one number set large |

**Scroll rhythm is the layout system.** Modern editorial progress surfaces read:
hero → breathing room → one module → breathing room → quieter module →
footnotes. The page gets visually QUIETER as you scroll. Equal-weight bento
grids read as a settings page because nothing is allowed to matter most.

**Narrative type moments beat chart accuracy.** "you've been at this *nineteen*
days" set in 42pt Fraunces does more retention work than a 19-cell calendar
heatmap. The chart's job is to be the receipt under the headline, not the
headline.

---

## 3. Becoming restructure: the scroll map

The tab becomes a **monthly-magazine issue about her**, top-heavy, quieting as
it descends. Five zones. One hero. One chromed card. Everything else is rows.

```
┌─────────────────────────────────────┐
│                              ☰      │  nav: thin menu mark only
│  ZONE 1 · THE FOLIO (hero, no card) │
│                                     │
│  day nineteen                       │  Fraunces 52pt, "nineteen" italic
│  of her 84                          │  Fraunces 32pt upright, cocoa
│  apr 2 → jun 25                     │  DM Sans 13pt, textSecondary
│                                     │  (plan.totalDays, never "75")
│  becoming steady.                   │  one identity line, 16pt,
│                                     │  italic punch on the trailer
│         ~ 48pt air ~                │
├─────────────────────────────────────┤
│  ZONE 2 · THE ARTIFACT (one card)   │
│ ┌─────────────────────────────────┐ │  the ONLY scrapbook-chromed
│ │ trend                       👁  │ │  card on the tab
│ │                                 │ │
│ │ 142.6 lb                        │ │  Fraunces Light 44pt numeral
│ │ down 1.4 since she started      │ │  language, never a delta chip
│ │                                 │ │
│ │   ·····~~~——____                │ │  EMA line styled as an artifact:
│ │   ↑apr 2          you, today↑   │ │  1.5pt cocoa stroke, NO axes,
│ │                                 │ │  NO gridlines, two serif-numeral
│ │ the line smooths daily noise ♥  │ │  annotations, dotted ACSM pace
│ └─────────────────────────────────┘ │  ghost-line in divider color
│         ~ 32pt air ~                │
├─────────────────────────────────────┤
│  ZONE 3 · THE LEDGER (slim rows)    │
│  this week            (eyebrow)     │
│  ───────────────────────────────    │  hairline dividers, NO borders
│  checklist        5 of 7 days       │  label DM Sans 16 · numeral
│  ───────────────────────────────    │  Fraunces 20, right-aligned
│  steps            41,200            │
│  ───────────────────────────────    │
│  plates logged    11   ▸            │
│  ───────────────────────────────    │
│         ~ 32pt air ~                │
├─────────────────────────────────────┤
│  ZONE 4 · THE SPREAD (photo strip)  │
│  her week in plates   (eyebrow)     │
│  [📷][📷][📷][📷]                   │  4-up filmstrip of HER OWN
│                                     │  food-log photos (her75 strip
│         ~ 32pt air ~                │  technique, zero stock)
├─────────────────────────────────────┤
│  ZONE 5 · FOOTNOTES (quietest)      │
│  on glp-1: appetite shifts are      │  cohort lines (GLP-1, peri-
│  part of the plan. under-eating     │  menopause): caption register,
│  days get a gentler target.         │  textSecondary, no card at all
│                                     │
│  week 3 recap → sunday              │  recap entry row, quiet
└─────────────────────────────────────┘
```

**Zone rules:**

- **Zone 1, the folio.** No card, no border, type directly on cream. The day
  count in words ("nineteen", her75 day-one register) with the date range and
  horizon date beneath. This is the one place the program pivot pays off: the
  tab now opens on "where am I in MY program" before any metric. The identity
  trailer (existing behavior-derived cascade: steady / stronger / clear /
  consistent / present) survives as the single line under the folio.
- **Zone 2, the artifact.** Weight trend keeps the hero-card slot it already
  earned, but restyled (see §3a). When weight is stale or hidden (eye toggle),
  the artifact swaps to checklist adherence, same chrome, so the page shape
  never changes.
- **Zone 3, the ledger.** Adherence, steps, food cadence as hairline rows with
  serif numerals. NO borders, NO tiles. Tapping a row opens its depth sheet
  (absorbs the current "more depth ↗" content). This is where the founder's
  "no scrolling" instinct and editorial hierarchy reconcile: rows are 44pt,
  three rows cost less than one bento tile.
- **Zone 4, the spread.** The only photography zone. Her own food photos as a
  filmstrip. If she hasn't logged photos this week, the zone collapses
  entirely (never a placeholder grid).
- **Zone 5, footnotes.** Cohort care-lines and the recap entry. Smallest type,
  no chrome. The page literally fades out.

### 3a. Editorializing the weight chart

Swift Charts defaults are the 2019 tell. The artifact treatment:

- one 1.5pt cocoa EMA line, rounded caps. NO raw-daily scatter dots by default
  (raw dots appear only inside the depth sheet).
- NO y-axis, NO x-axis, NO gridlines. Two annotations only: start ("apr 2",
  serif numeral) and now ("you, today"). Annotations set like print captions.
- the ACSM pace projection as a dotted ghost-line in `divider` color, labeled
  "her pace" in 11pt. Aspiration drawn as a pencil sketch, not a target band.
- under-target safety net: if trend dips below the GLP-1/restriction floor,
  the caption swaps to the care line. Color never changes (no red, ever).
- caption beneath in lowercase: "the line smooths daily noise ♥". Uncertainty
  in language, never a confidence %.

### 3b. The share artifact for Becoming

Food already ships 9:16. Becoming's artifact is **the day card**, lifted
straight from her75's day-one card but JeniFit-voiced:

```
┌──────────────────┐   cream card (bgElevated), 24pt corners,
│  day nineteen    │   floating on a 9:16 export canvas.
│  apr 2 → jun 25  │   serif italic title, date range,
│                  │   then 3 numbered serif-numeral facts
│  1  5/7 checklist│   pulled ONLY from her real data
│  2  41,200 steps │   (data-provenance rule).
│  3  trend ↓ 1.4  │   no brand wordmark larger than 11pt.
└──────────────────┘
```

Export from the folio (quiet share glyph) and auto-offered inside recaps. The
canvas behind the card: cream with the hard-offset rose shadow, or one of her
own logged photos blurred (her choice, never stock).

---

## 4. The chrome ladder (replaces uniform scrapbook cards)

Current failure: every module wears identical 24pt-corner 1.5pt-border chrome,
so nothing has weight. The ladder:

| Register | Chrome | Budget per screen | Used for |
|---|---|---|---|
| 1 · hero typographic moment | none. type on cream | exactly 1 | the folio (zone 1), recap headlines |
| 2 · editorial artifact card | full scrapbook chrome (24pt, 1.5pt accent border, rose offset shadow) | exactly 1 | the trend artifact (zone 2) only |
| 3 · slim data row | hairline `divider` rule, 44pt height, no fill | 3 to 5 | ledger rows (zone 3) |
| 4 · footnote | none. caption type, textSecondary | as needed | cohort lines, methodology captions, recap entry |

The scrapbook border becomes meaningful again BECAUSE it appears once. Same
logic as the locked scatter-milestone rule: contrast is what makes both
registers work. Depth sheets opened from rows may use register-2 chrome
internally since they are their own surface.

---

## 5. The weekly recap and milestone moments

How her75 would design "week 3 done" or "first kg of trend movement":
a **full-screen takeover**, not a card. The dashboard whispers; the moment
shouts. Mechanics:

- **Trigger:** recap waits as the quiet zone-5 row until Sunday, then on first
  tab-open becomes a full-screen cover (cream, slow crossfade per the
  calm-motion rule, never popping from the top).
- **Page 1, the headline:** line-cascade hero reveal (existing her75 pattern,
  soft haptic per line, reduce-motion gated):
  "week *three*." / "she kept *showing up*." 42pt heroHeadline register.
- **Page 2, the receipts:** her75's numbered-list idiom. 3 to 4 serif-numeral
  facts from her own week (days kept, steps, trend movement, plates logged).
  One care-frame line if the week was quiet: "quiet weeks count too.
  tomorrow resets ♥". Never a comparison to last week's number in red.
- **Page 3, the artifact:** the day card pre-rendered, one CTA "keep it"
  (saves/share-sheet), one quiet "not now".
- **Sticker policy:** the locked rule reserves full StickerScatter for
  welcome / plan reveal / graduation. Recaps and milestones get AT MOST one
  sticker used as a wax-seal on the day card (single, corner-anchored, ±8°),
  which is a new sub-register and needs founder sign-off. If declined, recaps
  stay type-and-photo only and lose nothing.
- **Milestones vs recaps:** first-kg-of-trend, halfway day, and graduation are
  the same takeover template with a bigger headline register
  (programHeroDisplay 52pt, celebration peak per the typography ladder).
  Graduation alone earns the full scatter.

---

## 6. Anti-patterns for this cohort

1. **Chart density.** More than ONE chart per viewport reads as MyFitnessPal
   2014. Axes, gridlines, and legend chips are the giveaway.
2. **Red anything.** Deltas, down-arrows, missed-day cells. Direction lives in
   language. (Locked: no shame colors, `stateBad` is for account-delete only.)
3. **BMI prominence.** Already killed in round 10 (NIH 2023 bias note). Do not
   let it back in via the research briefs. If a cohort brief needs it, it
   lives inside a depth sheet behind an explicit tap, footnote register.
4. **Dashboard-grid sameness.** The 2-up bento tile is the single strongest
   "settings page" signal. Zero 2-up grids on the main scroll.
5. **Calendar heatmaps and streak flames.** Locked anti-pattern (anti-shame
   memo). Adherence is "5 of 7 days" in serif, never 30 colored cells.
6. **Percentage rings as default.** One ring max, and only if a research brief
   proves the WHO ring earns its slot; otherwise the ledger row carries it.
7. **Daily-number-as-hero.** Trend is the hero, today's weight is the caption.
   (Locked: trend-as-hero.)
8. **Wordy literary captions.** Pill labels 2-4 words, subheads 5-7
   (copy-succinct rule). The folio does the poetry; everything else is terse.
9. **Fabricated motivation stats.** Every numeral on this tab traces to a
   collected field (data-provenance rule). No "users like you lost…".

---

## Handoff notes

- The existing becomingStack (streak strip → balance card → WHO ring → trend
  hero → more-depth link) maps cleanly: streak + balance + WHO collapse into
  zone-3 rows + depth sheets; trend hero keeps zone 2; the folio is new.
- Open decisions for the founder: (a) the single-sticker wax-seal on day
  cards, (b) whether today's-balance keeps a row or lives only in depth,
  (c) photo-strip privacy default for the food filmstrip.
- Pending: the two parallel research briefs decide the FINAL module list;
  this architecture absorbs any list by assigning each module a ladder
  register, never by adding chrome.
