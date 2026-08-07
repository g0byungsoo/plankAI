# v12 — THE CRAFT PASS (2026-08-06)

The founder's brief, the same day the design law was written: **STOP.
Nothing about the product changes. The architecture, the information
architecture, the business logic, the data model and the navigation
are already where they should be. This cycle exists to make the
EXISTING product feel like one of the highest-quality native iOS apps
on the App Store.**

The onboarding (v8 THE CONSULT) is the benchmark. When onboarding ends
and Home appears, the reaction must be *"of course this belongs to the
same app"* — never *"I entered another product."*

`docs/design/00_JENI_DESIGN_LANGUAGE.md` remains THE LAW. This
document records how this pass applies it, what was decided, and what
was rejected. Where this doc is silent, the law speaks.

---

## 1. The reference teardown (what the founder attached, reverse-engineered)

Six references. Not to copy — to understand why they feel premium.

**R1 — "Your Life Dashboard" (monochrome phone render).** One scalar
leads (DAILY SCORE 82). Every card is label + ONE visual. No second
accent, no chrome. Premium = *consistency of card rhythm + typography
doing all hierarchy.* → Our tiles already speak this; the gap is that
our numbers sit flat where theirs are the composition's anchor.

**R2 — the 2×2 soft-card grid (calories ring / water ring / sleep
bars / weight spark).** The metric-card grammar: quiet label row →
large numeral + low-contrast unit → a SMALL true chart, right-aligned.
Generous inner air. Premium = *the visual is real data, small, and
calm; the numeral is the hero.* → the model for our nutrition
centerpiece and tile faces.

**R3 — MyFitnessPal Today.** Already our Home IA (v11 chose it). The
detail worth stealing: the macro tri-column with tiny bars beneath
numbers — three answers in one glance — and "1,967 left" as the lead's
second clause. Premium = *remaining-first framing, three-column scan.*

**R4 — Lovi coach screen.** A destination, not a feature list: mascot,
warm serif hello, suggestion chips that are personal, history beneath.
Premium = *a place with state, not a button.* → the model for TOOLS
(each tool carries a living state line) and the chat door.

**R5 — the purple dashboard 3-up.** The Daily Breakdown screen is the
"3-second nutrition read": one large ring (460/1600 in its center),
macro chips, then the secondary nutrients as quiet rows (fiber, net
carbs, sugar, sodium). Premium = *hierarchy by size: one ring, three
chips, four whispers.* We take the hierarchy, never the palette (the
one-colour law stands; no traffic-light dots — anti-shame law).

**R6 — "7 weeks" streak screen.** Cream paper, tracked-caps header,
a MASSIVE numeral with a small word, one dot-row figure mid-page, one
plain sentence at the foot. Premium = *typography IS the design; one
fact; air everywhere.* This is already Jeni's native register — it
becomes the grammar for the weekly insight carousel and for
full-screen moments (daily welcome, weekly review, evening close).

**The synthesis.** Jeni's paper+ink editorial language (kept) +
R2/R5's metric-card glanceability (new) + R6's editorial numeral
moments (new). Nothing in the synthesis requires a ninth colour, a
border, or an icon system — it is all size, air, drawing and motion.

---

## 2. What this pass builds (per surface, architecture untouched)

### 2.1 Kit growth (§6 of the law gains five pieces)

| piece | what it is |
|---|---|
| `JeniRing` | the drawn arc gauge — hairline track, ink arc that traces in on a self-driven phase, round caps. Hero (kcal) and mini sizes. Never a colour code. |
| `JeniScopeBar` | the time-scope selector (today · week · month · 3 months · year · all) — the ink capsule MORPHS between words (matched geometry, tick haptic), content re-keys beneath. |
| `JeniMetricBar` | the labelled micro progress bar (label · value/target · 3pt track) for macro columns. Bars land, staggered. |
| `JeniWeekDots` | the R6 dot row — seven discs, filled where something happened, drawn check on the special one. |
| `JeniInsightPager` | the editorial insight carousel — paging cards in the R6 grammar (eyebrow → huge numeral+word → one drawn figure → one sentence), snap paging, ink page dots, tick per page. |

### 2.2 HOME (anatomy binding per law §7.3 — unchanged)

- **Greeting** gains ONE living sub-line, chosen by a priority ladder
  from real stores (kept-day streak → trend word → week-of-program →
  today's plates), hour-flavoured. One line, caption register, never
  noise. Every fact traces (law §1.6).
- **Calendar strip**: page-settle tick, a quiet dot above today's
  letter, directional continuity — selecting an earlier day slides
  the recap in from the left, a later day from the right (the strip
  and the page move as one object).
- **Nutrition** becomes the centerpiece (R2+R5 hierarchy): kcal
  numeral counts + "left" clause; the ring draws beside it; the macro
  tri-column with landing bars (protein carries its floor; carbs and
  fat speak plain grams — no invented denominators, law §1.6); fiber
  · sugar intake · sodium as one whisper row (sodium summed from the
  day's plates). Staged internal arrival; a landed plate re-counts
  the numeral and re-draws the ring delta.
- **Tasks**: completion morphs — the check draws (kept), the title
  settles into its dimmed state on the morph spring, the section
  header counts ("2 of 4" whisper). All-done keeps the silk sweep.
- **Tools** become destinations: word-first cards that each carry a
  living state line ("2 plates today", "last weighed tue", "due
  sunday"). The glyph stays quiet (L3-tempered). No dead buttons.

### 2.3 BECOMING (IA unchanged; the dashboard breathes)

- **`JeniScopeBar`** under the title. Scope feeds the SAME stores
  through wider windows (7d / 30d / 91d / 365d / all; "today" reads
  the day). Nothing reloads: values re-count
  (`contentTransition(.numericText)`), charts re-draw their phase,
  ribbons re-spring. A store that holds less than the scope says so
  in its span label — the axis never claims more record than exists
  (law §1.6).
- **Tile faces** gain an honest delta whisper vs the previous window
  ("down 8% vs last week") where floors allow. Anti-shame framing
  everywhere (a fuller week is never scolded).
- **Weekly insight carousel** (R6): computed cards — protein days
  hit, sodium moving, consistency run, sleep delta, scan count,
  water-masking read, clinician note when connected. Cards render
  ONLY when their floor is met.
- **Detail pages** deepen: larger scrubbable chart, this-week vs
  last-week comparison pairs, the mechanism, "what the plan does
  with this" (observed-never-prescribed — Becoming still never says
  "do this"), clinician line when care-connected, provenance last.

### 2.4 Moments + chrome

- `JeniMoment` gains the hero-numeral register (R6): eyebrow → huge
  numeral + small word → typed lines. Applied to the evening close
  and the weekly review's opening beat.
- Liquid Glass exactly per law §13: chrome only (tab bar, sheets,
  floating pills), availability-gated iOS 26+, `.ultraThinMaterial`
  floor beneath. Content surfaces stay opaque paper.

### 2.5 B2B (care-connected patients)

Same architecture, adapted priorities: dose/care tasks lead TODAY
(CarePlanEngine already does this — verified, not rebuilt), the
clinician's presence reads first-class on Becoming (care section
higher, clinical register), care surfaces stay ornament-free (v8
clinical-register law).

---

## 3. Decisions + rejected ideas (running ledger)

| # | decision | why |
|---|---|---|
| D1 | No color-coded nutrition states (green/red rings) despite R5 showing them | one-colour law + anti-shame law beat the reference; state is words + fraction |
| D2 | Carbs/fat get numerals, not bars | no collected target exists → a bar would invent a denominator (law §1.6). Protein alone carries its floor |
| D3 | Sodium summed from plates at the view layer | snapshot doesn't carry it; plates do — same store, zero data-model change |
| D4 | Tools keep quiet SF glyphs, gain living state lines | drawing six bespoke glyphs risks the "generic icon set" smell in mirror image; identity comes from state, not pictograms |
| D5 | Task list order never re-sorts on completion | the order IS CarePlanEngine's clinical composition; presentation may dim, never re-rank care |
| D6 | Scope bar words, not a segmented control | the app's selection grammar is the ink capsule morph (§5.4); a UISegmentedControl would be the one foreign object on the page |
| D7 | Sleep/steps beyond stored history: honest span labels, never synthetic backfill | L8; services hold ~7 nights today |
| D8 | "Recommendations" on detail pages framed as "what the plan does" | three-questions law: Becoming answers *am I changing / why* — the plan acts on Home, Becoming reports it |
| D9 | Insight carousel cards gated by data floors | an insight without data is decoration; only cards that read render |
| D10 | REJECTED: mascot/avatar for the coach door (R4's smiley) | Jeni's identity is the drawn j mark + voice; a face would be a second brand |
| D11 | REJECTED: BMI band visual (R5 bottom) | numeric-classification shame surface; the band-words system already answers it kindly |
| D12 | REJECTED: giant "daily score" scalar (R1) | a composite score is a number no collected field produces (§1.6); the day's receipt already answers "how did I do" |
| D13 | The strip's recap slides directionally (earlier=from left) | continuity: the page and the strip move as one object (§4.4) |

(The ledger grows as the pass runs; frame-caught fixes land in
`01_EVIDENCE.md`.)

---

## 4. The loop (verification, per law §15)

Per surface: build → install → drive (XCUI leg or scripted taps) →
record → dump frames (ffmpeg) → inspect neighbours → fix → repeat.
Exit only at "cannot find another obvious issue". Gates per screen:
*Would Apple ship this? Would it hold in a keynote? Does frame-by-frame
inspection embarrass us?*

Evidence lands in `01_EVIDENCE.md` with the frame numbers.
