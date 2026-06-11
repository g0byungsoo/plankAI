# Becoming below-fold extension + shipped-screen fixes
2026-06-11 · her75 designer · responds to founder ask on IMG_6339 ("fill the
empty space... useful and beautiful, worthy to share")

Premise check first: the founder is right that ~400pt of cream after the
insight line reads unfinished, but the answer is NOT more analytics modules.
The scroll-rhythm rule (page gets quieter as it descends) and the founder's
"dense + share-worthy" reconcile through ONE move: the below-fold zone gets a
single quiet accumulation artifact (the program map) plus receipts, instead of
a second stack of metric tiles. Quieter in chrome, not emptier in content.

---

## §1 Candidate verdicts

| Candidate | Verdict | Why |
|---|---|---|
| (a) program chapter map (day grid) | **PICK — the anchor** | the accumulation visual the screen is missing; pure day-check data; her75 calendar-artifact DNA; makes the full-page screenshot a planner spread |
| (b) weekly recap entry row, blooms Sundays | **PICK** | already in the locked depth map; 1 quiet row, P3's natural doorway |
| (c) plank mastery curve, 2nd naked sparkline | **KILL on surface** | benchmark data is sparse, diet-first pivot demotes plank, and it already lives in the depth sheet. A second sparkline dilutes the trend artifact's authority |
| (d) lesson shelf | **IMPROVE → ledger row** | lessons are the engagement winner (75%+) but a "shelf" is chrome-heavy. Becomes one row in the receipts ledger ("lessons read · 4") |
| (e) cohort care footnote | **PICK, conditional** | onboarding flags exist today; one caption line, quietest thing on the page, renders only for GLP-1 / perimenopause / restriction-history |
| (f) day-card share entry | **PICK, P3-gated** | plan puts the entry on folio tap; a second below-fold entry costs one text link and catches her at the bottom of the read |
| (new) receipts ledger | **PROPOSE** | program-to-date totals (sessions, lessons, plates, best hold). The map shows accumulation as shape; the ledger shows it as numbers. All from existing logs |

---

## §2 Below-fold zone map (continues from the insight line)

```
│  protein's been showing up on your       │  insight line (shipped)
│  plates this week.                       │
│                                          │  ~20pt air
│  ──────────────────────────────────────  │  hairline
│  the map                  week 1 of 12   │  eyebrow + DM Sans 12 count
│                                          │
│  ●●◐○○○○                                 │  ZONE 6 · THE MAP
│  ○○○○○○○                                 │  one row per program week,
│  ○○○○○○○                                 │  7 dots each (6pt, 5pt gap,
│  ○○○○○○○        ... (N/7 rows,           │  ~16pt row pitch). filled
│  ○○○○○○○         reads plan.totalDays)   │  cocoa = done · today gets
│  ○○○○○○○                                 │  the accent ring · EVERY
│  ○○○○○○○                                 │  other day is the same faint
│                                          │  open dot, past or future
│                                          │  ~24pt air
│  since jun 9              (eyebrow)      │  ZONE 7 · THE RECEIPTS
│  ──────────────────────────────────────  │  ledger rows (atom 3):
│  sessions moved              5     ▸     │  DM Sans 15 label · right
│  ──────────────────────────────────────  │  tabular numeral · 40pt ·
│  lessons read                4     ▸     │  hairline dividers, no fill
│  ──────────────────────────────────────  │  each row → its depth sheet
│  plates logged              11     ▸     │
│  ──────────────────────────────────────  │
│                                          │  ~24pt air
│  week one recap · sunday                 │  ZONE 8 · FOOTNOTES
│  keep today's page →                     │  recap row + share entry,
│                                          │  caption register, no chrome
│  on glp-1: appetite shifts are part      │  cohort care-line,
│  of the plan ♥                           │  textSecondary 12pt
│                                          │  page fades out
├──────────────────────────────────────────┤
│        today        ·     becoming       │  tab bar
└──────────────────────────────────────────┘
```

Chrome descends correctly: hairline grid → bare rows → text links → caption.
Nothing below the insight line wears a border (the artifact-card budget is
spent above the fold). Budget math: map header 24 + grid ~190 (12-wk plan) +
receipts 24 + 3×40 + footnotes ~70 + air ≈ 440pt — the cream gap is consumed
with one screen of gentle scroll overflow on short programs, none on phones
with taller safe areas.

---

## §3 Module specs

**Zone 6 · the map** (register: typographic artifact, no card)
- Data: `plan.startDate` + `plan.totalDays` (NEVER hardcode 84) + per-day
  done states from program_day_checks/activeDates. One row per week.
- Anti-shame load-bearing rule: **a missed past day renders IDENTICAL to a
  day that hasn't arrived yet** (same faint `divider`-stroke open dot). The
  map only ever records what she DID. This is what keeps it on the right
  side of the "no calendar heatmap" lock — that lock bans recorded misses
  and red intensity, not accumulation. No per-day labels, no week labels on
  rows, no X, no red, no fill behind the grid.
- Today: accent ring (same idiom as the week dot-row above the fold — the
  two surfaces visibly rhyme; the week row is literally the map's current
  line magnified).
- Serif budget: the "week 1 of 12" count stays DM Sans 12 — below-fold adds
  ZERO serif numerals; the page's three are spent above.
- Tap: whole map → the existing activity-calendar depth sheet.
- Collapse: no active plan → entire zone absent (engagement-day users see
  the page end at the receipts). Never a placeholder grid.

**Zone 7 · the receipts** (register: ledger rows, atom 3)
- Rows, provenance-gated, max 4, in this order: `sessions moved` (workout +
  breathwork session logs), `lessons read` (lesson session logs), `plates
  logged` (food entries, FoodFlags-gated), `longest hold` (plank PR,
  mm:ss, only if a benchmark exists). Counts are program-to-date (since
  plan.startDate), eyebrow reads "since jun 9" from the plan.
- DM Sans tabular numerals only. Each row taps to its existing depth sheet
  (sessions → recentSessions, lessons → lesson log, plates → food depth,
  hold → plank mastery curve — candidate (c)'s honest home).
- Collapse: a zero row disappears; fewer than 2 qualifying rows collapses
  the whole ledger (a one-row ledger looks like an apology).

**Zone 8 · footnotes** (register: caption, no chrome)
- Recap row: pre-Sunday it reads "week one recap · sunday" in textSecondary;
  on Sundays it blooms (accent dot + "ready ♥") and opens the P3 takeover.
  Hidden until P3 ships; skipped on zero-activity weeks per the plan.
- Share entry: "keep today's page →" opens the P3 day-card sheet. Renders
  only after ≥1 done module today (the card must have content). P3-gated.
- Cohort care-line: one line max, GLP-1 > perimenopause > restriction
  priority, from onboarding profile flags. This is the P4 "cohort variants"
  item's cheapest slice — flag it to the founder as ship-now-able since the
  fields exist and it's copy-only.
- The "more depth ↗" link DIES as a standalone row: the receipts rows now
  carry the depth sheet entries, so the link's job is absorbed. (If founder
  wants a catch-all, it survives as the last footnote line, same register.)

---

## §4 Share-crop verdict

- The top-70% crop (folio → trend artifact → stat pair) was already the
  share unit and stays untouched — but it is currently POISONED by the "up
  5.7" hero (fix #1 below). No one screenshots a gain headline.
- The map changes what the FULL-page screenshot says: today the page ends in
  cream (reads unfinished); with the map, a full-screen shot reads top =
  horizon ("day three of 84"), bottom = accumulation (her filled dots). That
  is the her75 planner-spread grammar — date range + her marks — and it gets
  stronger every week she fills it. The below-fold zone doesn't compete with
  the top crop; it creates a second crop that matures with tenure (day 40+
  users share the map, day 3 users share the folio).
- Keep the tab bar out of the share story: the footnote zone's quiet caption
  type acts as the fade-out margin so a near-full crop still composes.

---

## §5 Shipped-screen fix list (IMG_6339)

1. **"up 5.7" serif hero on a gain — the one real violation.** Two weigh-ins
   three days apart is noise, not a trend, and the page headlines it in the
   36pt artifact slot. Two gates: (a) coverage — no delta numeral until ≥2
   weeks span or ≥4 weigh-ins; early state shows the current weight small
   with "settling in. trends take about two weeks to mean anything"; (b)
   direction — the 36pt serif delta is for down-or-steady only. On a real
   sustained gain, direction goes to language ("up a little. the line
   smooths this") and the numeral demotes to the receipt line. Color never
   changes.
2. **"0 of 7" serif zero on day 3.** Never headline a zero. When doneCount
   is 0, drop the count and let the dot row + "the week starts here" carry
   it; the serif count returns at 1.
3. **Steps "— today / — this week" double placeholder** breaks rule 10
   (empty modules never apologize). No HealthKit grant → the cell becomes a
   quiet "connect steps →" action; granted-but-zero → show the week line
   only; both zero → plates takes the full width and the column rule goes.
4. **"YOUR TREND" all-caps eyebrow** breaks anti-boring rule 5 (lowercase
   eyebrows only). → "your trend".
5. **Insight contradicts its own receipt:** "protein's been showing up"
   while the plates chip says "protein led, 1 of 3 days". Tighten the gate
   to proteinLedDays ≥ 2; fallback sentence is the neutral "three days of
   plates logged. the pattern is forming."
6. **Identity caption over-claims:** "you're showing it" under an up-trend
   and a 0-of-7 week. Gate the caption on an actual consistency signal
   (≥3 done days in 7); otherwise it reads "becoming light starts with
   showing up" (forward-framed, no false evidence).
7. "of her 84" ambiguity — already fixed in code to "of 84 days" per the
   2026-06-11 founder QA note. Confirmed, no action.
