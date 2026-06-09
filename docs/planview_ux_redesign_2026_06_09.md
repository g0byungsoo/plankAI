# PlanView UX redesign — top nav + module-bound rows

**Date:** 2026-06-09
**Author:** Sr. UX (her75 alum)
**Status:** Spec for founder approval, then engineering implementation
**Supersedes:** the implicit "no top nav, sticky-note-only rows" pattern in the first cut at `/Users/bko/plankAI/PlankApp/Views/Plan/PlanView.swift`
**Honors as locked:** soft pink scroll, white program cards, italic-Fraunces hero, ProgramStickyNote pastel paper-square row marker, cocoa CTA, today/becoming tabs, 5-row checklist, no em-dashes, lowercase casual.

---

## 1. ASCII mockup — Day 12 of 75

iPhone 15 width: 393pt. Safe-area top ~59pt, bottom tab bar ~83pt. Drawing the visible body region only.

```
┌─────────────────────────────────────────────────────────────┐ ← status bar
│  9:41                              · · · · · · ·            │
├─────────────────────────────────────────────────────────────┤
│                                                             │ ← 28pt
│  day 12 of 75                                               │ ← eyebrow (Fraunces SB 11pt)
│                                                             │ ← 12pt
│  today,                                                     │ ← Fraunces Light 52pt
│  gently.                                                    │ ← Fraunces SBItalic 52pt
│                                                             │ ← 28pt
│  ┌───┬───┬───┬───┬───┬───┬───┐                              │
│  │ 9 │10 │11 │12 │13 │14 │15 │   ←  day strip               │
│  │ ✓ │ ✓ │ ✓ │ • │ 🔒│ 🔒│ 🔒│                              │
│  └───┴───┴───┴───┴───┴───┴───┘                              │
│   ← swipe to see all 75 days →                              │ ← tiny hint (caption, fades after first use)
│                                                             │ ← 24pt
│  ┌─────────────────────────────────────────────────────┐    │
│  │                                                     │    │
│  │  ╔═══╗   today's lesson           ›        ◉        │    │ ← checked (user complete)
│  │  ║ 1 ║   why protein keeps you full   2 min          │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   snap a meal              ›        ◉        │    │ ← checked (user complete)
│  │  ║ 2 ║   2 logged today                              │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   move                     ›        ◯        │    │ ← empty (tap row to enter)
│  │  ║ 3 ║   18 min, gentle today                       │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   steps                            ░◐░       │    │ ← auto, in-progress (no chevron)
│  │  ║ 4 ║   4,820 of 7,500                             │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   weigh-in                  ›       ◯        │    │ ← empty (tap row to enter)
│  │  ║ 5 ║   sunday check                                │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │ ← 32pt
│  3 of 5 done. you're showing up.                            │ ← micro-copy (caption, cocoaTertiary)
│                                                             │
└─────────────────────────────────────────────────────────────┘
              [ today ]      [ becoming ]                       ← tab bar
```

Key proportions: hero block consumes ~180pt, day strip ~76pt (cells + hint), checklist card ~440pt (5 rows × ~76pt + 12pt internal pad × 2). Comfortably one-screen on iPhone 15 (852pt usable).

---

## 2. Top navigation — **option (a) horizontal day-pill strip**, refined

**Picked: 7-day window centered on today, swipe-paginates through all 75 days.**

### Why over the alternatives

- **(b) week-row S/M/T/W/T/F/S** (Apple Fitness): leaks calendar semantics ("oh, it's Thursday") that don't match the program register. JeniFit's program is *day N of 75*, not *Thursday*. Mapping a 75-day program onto weekday columns also fights the math — weeks 1–10 don't align cleanly and the user has to count.
- **(c) compact "Day 12 / 75" + chevrons + lock icon**: too quiet. The founder's whole point is that the user should **feel the structure**. A pair of chevrons hides it. The trial-conversion lever lives in seeing locked days, not in reading a number.
- **(a) day-pill strip**: lets the user literally see locked days sitting to the right of today on first paint. That's the trial-commitment device made visual. Her75 didn't need it because their challenge is binary self-check; we have real per-day state.

### Spec

- **Cell width**: 44pt fixed (HIG min hit target), **gap**: 8pt, **height**: 56pt
- **7 cells visible**: `[today-3, today-2, today-1, today, today+1, today+2, today+3]`. On day 1 the window snaps to `[1..7]`; on day 75 it snaps to `[69..75]`.
- **Strip is a single horizontally-scrolling `ScrollView`** with snap behavior — swipe pages by 7. No paging dots; the day numbers ARE the position indicator.
- **No outer card chrome** on the strip itself. It sits naked on the pink scroll, just like her75 rows sit naked on cream. This keeps it from competing with the checklist card below.

### Cell visual states (44×56pt rounded-10)

| State | Fill | Border | Numeral | Icon/dot |
|---|---|---|---|---|
| **today** (active) | `Palette.cocoaPrimary` (cocoa) | none | `Palette.textInverse` (cream), DM Sans SemiBold 17 | tiny 4pt cream dot below numeral |
| **completed** (past, ≥3 of 5 rows done) | `Palette.programCard` (white) | none | cocoa, DM Sans Regular 15 | 8pt `checkmark.circle.fill` in `Palette.stateGood` |
| **partial** (past, 1–2 of 5 rows done) | `Palette.programCard` | none | cocoa, DM Sans Regular 15 | 6pt dot in `Palette.cocoaTertiary` |
| **missed** (past, 0 rows) | transparent | none | `Palette.cocoaTertiary` | none |
| **locked** (future) | transparent | none | `Palette.cocoaTertiary`, DM Sans Regular 15 | 9pt `lock.fill` in `Palette.cocoaTertiary`, below numeral |

Critical: **no green checkmarks on cream "frozen day" blue**, no bright accent colors. The strip stays cocoa+cream+sage so it composes with the her75 register. The lock glyph is the SF `lock.fill` at 48% cocoa — visible but not alarming. **The lock is wistful, not punitive.**

### Tap behavior

- **Tap today** — no-op (haptic light only). You're already here.
- **Tap past day** — `crossFade` swap the checklist card content to that day's snapshot. Read-only: rows render with their final state, the CTAs hide, a soft "viewing day 8" pill appears under the hero (tap to return to today). Locked-feeling minimal navigation, not a separate screen.
- **Tap locked day** — haptic `medium` (denied feel without being harsh), then sheet bottom-sheet detent (`.medium`) with the trial-conversion micro-narrative (see §5). On screens where user has `effectiveHasProAccess == true`, locked-future days still show locked — **you can't time-travel into the future regardless of subscription**. The lock is structural to the program, not a paywall. Sheet copy differs: pro users see "day 13 starts tomorrow"; trial users see the longer commitment line.

### "How the lock reads as commitment device, not shame"

Three rules:

1. **No red, no warning iconography.** Just a small soft lock at 48% cocoa. Reads as "not yet" not "you can't."
2. **No counter of locked days** ("63 more locked!"). The visual cluster does that work; numbering it makes it feel like a wall.
3. **Lock copy uses future tense for the program ("waits for you"), not past tense for the user ("you missed it").** Cf. §5.

---

## 3. Module-bound checklist row — adopt BetterMe mechanic, her75 chrome

BetterMe nailed the dual-affordance row. Adopt the mechanic, drop the thumbnail (it's the wrong register for our brand).

### Row anatomy (left to right)

```
[ ProgramStickyNote 56×56 ] [ title + subtitle, V-stack ] [ chevron ] [ checkbox ]
       leading 20pt          flex, gap-16pt from sticky    8pt gap     20pt trailing
```

**Leading — ProgramStickyNote stays.** Confirmed. The sticky-note IS the her75 craft signal. Do not replace with thumbnails — BetterMe's photo-thumbnails are warm-stock-photo-coded and JeniFit's brand is editorial+coquette, not lifestyle stock. Thumbnails would also force us to generate/license 5 photos per day for 75 days, which is dead-weight.

**Center — title + subtitle, two lines max.**
- **Title**: `Typo.body` (DM Sans Regular 16pt), `Palette.cocoaPrimary`. e.g. "today's lesson", "snap a meal", "move", "steps", "weigh-in".
- **Subtitle**: `Typo.caption` (DM Sans Medium 13pt), `Palette.cocoaSecondary`. Carries the **module-specific micro-state**:
  - lesson: "why protein keeps you full · 2 min"
  - snap meal: "2 logged today" / "tap to log your first"
  - move: "18 min, gentle today" / "rest day, no move scheduled"
  - steps: "4,820 of 7,500" (live; auto-updates from HealthKit on appear)
  - weigh-in: "sunday check" / "last logged 4 days ago"
  - breath: "1 min, calming"

**Trailing — chevron + checkbox, both visible, both tappable as separate hit zones.**

This is the BetterMe move and it works because each affordance has a clear job:
- **Chevron** = "enter the module" (lesson player, food camera, session pre-view, weight sheet, breath player)
- **Checkbox** = "mark done without entering" (escape valve for users who already did it offline, did a walk that didn't auto-detect, etc.)

The visual distinction:
- **Chevron**: SF `chevron.right`, 13pt, `Palette.cocoaTertiary` (48% — quiet). Right-aligned. Hit target padded to 44pt via the existing `tappableArea(_)` modifier.
- **Checkbox**: 26pt circle, `Palette.cocoaTertiary` 1.5pt stroke when empty, `Palette.stateGood` filled `checkmark.circle.fill` when complete. Hit target padded to 44pt.
- **Gap between them**: 8pt. Small enough to feel like one trailing module, big enough that thumb taps don't fight.

The row's `contentShape(Rectangle())` covers the leading sticky + center text region; this opens the module. The chevron is just a visual hint that the row is tappable — its hit area is folded into the row-tap zone. The **checkbox** has an explicit smaller hit zone that **does not propagate** to the row tap (SwiftUI `simultaneousGesture` or split-button pattern).

### Row height + spacing

- **Row height**: 76pt (was ~80pt in the current impl; trim 4pt to fit the strip + 5 rows + hero on one screen)
- **Internal vertical padding**: 14pt top/bottom (keeps the visual 76pt with the 56pt sticky + breathing room)
- **Internal horizontal padding**: 20pt
- **Divider between rows**: 0.5pt hairline at `Palette.hairlineCocoa` (12% cocoa). Indent: leading 88pt (past the sticky-note), trailing 20pt. Cleaner than the current 1pt divider; matches the [[feedback-clean-luxury-aesthetic]] "always 0.5pt, never 1pt" rule.

### State visuals (per row)

| State | Sticky | Title | Subtitle | Chevron | Checkbox | Behavior |
|---|---|---|---|---|---|---|
| **empty** (no progress) | full color | cocoaPrimary | cocoaSecondary | shown | empty circle | tap row = enter module; tap box = mark done |
| **in-progress** (started, not done) | full color | cocoaPrimary | shows progress ("4,820 of 7,500") | shown | **dotted half-circle** in cocoaTertiary | tap row = re-enter / continue |
| **complete (user-marked)** | full color | cocoaPrimary, strikethrough optional* | "logged at 9:42a" | shown | `checkmark.circle.fill` stateGood | tap row = still enters module (no penalty for re-entry) |
| **complete (auto from HK/sync)** | full color | cocoaPrimary, no strikethrough | "7,500 of 7,500 · auto" | **hidden** | `checkmark.circle.fill` stateGood + tiny `sparkle` glyph 8pt inline | row not tappable; checkbox not tappable; quiet visual that says "the system did this for you" |
| **skipped** (user-explicit skip, future state) | 50% opacity | cocoaTertiary | "skipped today" | hidden | em-dash glyph `—` in cocoaTertiary | tap row = re-open module |
| **rest day** (engine says no module today) | 50% opacity | cocoaTertiary, "move" stays as label | "rest day, no move scheduled" | hidden | em-dash glyph `—` in cocoaTertiary | non-interactive |

*Strikethrough on completed title: **omit**. her75 uses strikethrough; JeniFit's brand is anti-shame and post-Ozempic-vocabulary-aligned, and strikethrough on "weigh-in" reads as crossing-off-the-scale. The filled checkbox carries the "done" signal.

### Auto-completing rows (steps) — visual differentiation

Founder ask: "how auto-completing rows differ from tap-to-launch rows vs self-check rows."

Auto rows have **three deletions** from the standard row:

1. **No chevron** (you can't "enter" steps — it's just data)
2. **No tappable checkbox** (the checkbox renders but ignores taps; haptic-light feedback only on attempt + tooltip "syncs from your steps")
3. **Tiny `sparkle` glyph** (SF symbol, 8pt) inline to the right of the checkmark when complete. Subtle. Tells the savvy user "this happened automatically."

This is the **third state** the her75 model doesn't have, and getting it right is part of why JeniFit's program reads as smarter than a paper checklist. **One sparkle, one row** — never on lesson/snap/move/weigh-in.

---

## 4. Hero composition with the new nav

**Decision: hero stays at top. Day-pill strip slots BETWEEN hero and checklist card.**

```
[ eyebrow: "day 12 of 75" ] ← stays. it grounds the day-strip below.
[ hero: "today, / gently." ] ← unchanged.
[ 7-day pill strip          ] ← new. ~24pt below hero.
[ tiny scroll hint           ] ← new. fades after first launch.
[ white checklist card       ] ← unchanged structure, refined rows.
[ micro-progress caption     ] ← new (see §6).
```

### Why this order

- **Eyebrow stays.** Founder might be tempted to drop it now that the day-strip shows the number. Keep it. Reasons:
  1. The strip cells show a small numeral inside each pill; on glance you read "12" as a 12pt digit. The eyebrow makes the program scale ("of 75") legible without forcing the eye to count cells.
  2. her75 has "75 Day Hard" above their list — a written anchor IS the her75 pattern.
  3. SEO-of-eyeballs: when the user opens the app, the first three glyph clusters should be `day 12 of 75 / today, gently. / [strip]`. That's the editorial register Cereal+Aesop use — eyebrow, title, image.
- **Strip below hero**, not above. Above-hero strip = nav-bar register = competes with the eyebrow + reads as utility chrome. Below-hero = "now that I've grounded you in today's mood, here's the scaffolding." Same composition as a magazine: masthead → title → image grid.
- **Strip above the white card**, not inside it. Inside-card would make the card feel like a chrome wrapper; outside, the strip lives on the pink scroll and the card stays a pure list. Cleaner separation, less visual weight.

### Concrete spacing

- 28pt top inset (down from `Space.hero = 40`)
- eyebrow → hero: 12pt
- hero → strip: 28pt
- strip → hint text: 8pt
- hint → card: 24pt
- card → micro-caption: 28pt
- bottom: 80pt for tab bar clearance

---

## 5. Trial-conversion micro-narrative

### Locked-day tap sheet

Bottom sheet, `.medium` detent. White card, 24pt radius top corners, soft programPaperShadow. Inside:

```
                  🔒
                ─────

         day 13 of 75


    a small lock, a longer story.

    your program is built day by
    day. day 13 unlocks tomorrow.

    showing up beats jumping ahead.


  ┌─────────────────────────────────┐
  │       got it                     │   ← cocoa CTA pill, full width
  └─────────────────────────────────┘
```

Copy notes (all anti-em-dash):
- "a small lock, a longer story." — italic-Fraunces 22pt (`Typo.pullQuote`). Punch word: none, full italic — this is a quote-register moment.
- Body: DM Sans Regular 15pt, cocoaSecondary, line-height 1.45, ~3 short lines max.
- CTA: "got it." (lowercase, cocoa pill).
- For users **on day N where day+1 is the lock tapped**: copy reads "day 13 unlocks tomorrow." (closer/warmer).
- For users tapping a far-future lock (e.g. day 12 user taps day 60): copy reads "day 60 is 48 days away. your future self is waiting." (still anti-shame, future-positive).

### What this does NOT do

- **No paywall CTA on this sheet.** Confusing the lock with a paywall would cheapen the program. Users already paid (or are trialing) — they should never see "unlock pro" here. The trial-conversion is *retention*, not *purchase*.
- **No "unlock all days" affordance.** The program is the program. Skipping is meaningless.
- **No mention of price/trial status.** Brand-clean.

### Animation + haptic

- **Lock tap**: `UIImpactFeedbackGenerator(style: .medium)` (light feels like an accept, medium feels like a soft denial). Concurrently, the tapped cell does a **single-bounce wobble** (rotate +2° → -2° → 0° over 320ms with `Motion.gentleSpring`), echoing the sticky-note craft register.
- **Sheet entrance**: standard SwiftUI sheet at `.medium` detent. Slow enough to feel mindful (the system default is fine — don't customize).

### First-launch nudge

- On the user's **first 3 opens** of PlanView, render the tiny "← swipe to see all 75 days →" hint text below the strip in `Typo.caption`, `Palette.cocoaTertiary`, centered, fading in 0.6s after appear.
- Persist `AppStorage("planview_strip_hint_dismissed_count")` Int. Increment on each appear; hide once it hits 3 OR when the user has actually scrolled the strip (`onScrollGeometryChange` — once they've panned >40pt, kill the hint forever via a separate `AppStorage` flag).
- This is the her75 "Become that girl" instructional moment but at a tenth the volume — they have a full editorial cover, we have one quiet line of text.

---

## 6. JeniFit-specific innovations (beyond copying)

### (1) Quiet completion caption below the card

```
3 of 5 done. you're showing up.
```

`Typo.caption`, `Palette.cocoaTertiary`, centered, 28pt below the card. Copy varies by completion bucket:
- 0/5: "a fresh page. start anywhere."
- 1/5: "you opened the door."
- 2/5: "you're moving."
- 3/5: "you're showing up." (default)
- 4/5: "one to go. or don't. either's fine."
- 5/5: "all 5. you closed the day."

**Why beyond her75/BetterMe:** her75 has zero feedback below the list (cold). BetterMe has a percentage bar (gym-app-coded). JeniFit cohort is anti-shame post-Ozempic-vocabulary — the right move is a single calm sentence that names what the user did. "4 of 5. one to go. **or don't. either's fine.**" — that "either's fine" is the JeniFit voice signature; her75 would never write it because their brand is more drill-sergeant.

### (2) Auto-completion `sparkle` glyph

Spelled out in §3. The differentiation between user-marked complete and system-detected complete is **information**, not chrome. Cohort understands the difference (they're Apple Health-savvy 22-35 women) and it primes them to trust the program with more data later (Phase 2 food auto-log, Phase 3 weight scale integration).

### (3) Wistful past-day read-only mode

Tapping a past completed day swaps the checklist to that day's snapshot — no separate screen, no back button, just an inline "viewing day 8" pill that tap-dismisses to today. **The whole interaction is the her75 "scrapbook" register**: leafing back through your program like flipping the pages of a journal, not navigating a calendar app. The pill itself uses `Palette.accentSubtle` (the only place pink shows up on PlanView) so the user can see they've left "today" without it feeling like an alarm.

---

## 7. Implementation guidance (≤200 words)

**New components:**
- `ProgramDayStrip` — horizontal scroll, 7-cell window, snap paging. Drives off `ProgramScheduleCalculator.compute(...)` + `FetchDescriptor<ProgramDayCheckRecord>` query for past completion counts.
- `ProgramDayCell` — 44×56 rounded-10, 5 visual states from §2. Pure render off enum.
- `ProgramLockSheet` — `.medium` detent sheet, copy from §5.
- `PlanViewMicroCaption` — single Text, 6 completion buckets.

**Modify:**
- `PlanRow` — add chevron, split tap zone, add auto-completion `isAutoSource: Bool` flag and `isInteractive: Bool` flag. State derivation expands from binary `isCompleted` to the 6-state enum in §3.
- `PlanView` — slot the strip + hint between greeting and checklist; thread a `@State viewingDay: Int?` (nil = today, value = past snapshot mode); fade-pill when non-nil.

**AppStorage keys:**
- `planview_strip_hint_dismissed_count` Int (default 0)
- `planview_strip_user_scrolled` Bool (default false)

**SwiftData queries:**
- Past completion counts: fetch `ProgramDayCheckRecord` by `planId` + `programDay IN [strip range]`, group by `programDay`, count `state == .complete`. Cache in `[Int: Int]` keyed by programDay; recompute on `onAppear` only (not on scroll).

**Motion:**
- Strip cell tap: `Motion.modernPop`.
- Lock wobble: ad-hoc `withAnimation(Motion.gentleSpring)`.
- Card content swap (past-day snapshot): `Motion.crossFade`.
- All staggered entrances honor `.modernEntrance` already in `Tokens.swift`.

---

## 8. Open questions for the founder

1. **Past-day read-only mode — ship in Phase 1 or punt to Phase 2?** It's the most ambitious of the three innovations and the riskiest to implement well (needs a per-day `[String: ChecklistState]` rehydrate path, not just today's). Phase 1 minimum-viable could lock past-day taps to "viewing past days coming soon" sheet, ship full snapshot in Phase 1.B. **My vote: punt to 1.B.** It's not on the trial-conversion critical path.

2. **Day-strip starting position on first launch.** If user just enrolled and is on day 1, do we show `[1..7]` (the natural left-edge) or `[1..7]` with a soft tutorial overlay pointing at the locks? Tutorial overlays violate the clean-luxury rule but day 1 users are also the most likely to bounce. **My vote: no overlay. The `← swipe to see all 75 days →` hint is the tutorial.** Trust the cohort.

3. **Should the lock sheet show ANYTHING program-specific** (e.g. "your day 13 lesson: emotional eating") or stay totally abstract? Showing a teaser would be the BetterMe move and would help conversion; staying abstract preserves the surprise and matches the her75 register. **Trade-off**: conversion vs craft. My vote: abstract for v1.1, A/B test teasers in v1.2.

4. **Auto-completion sparkle glyph — too clever for the cohort or just right?** It's a 2026 design-language flex (Things 3, Linear, Reflect all use micro-glyphs to signal "system did this"). If you think TikTok-acquired beginner women will read sparkle as decoration not signal, we drop it and let the absence of chevron carry the auto-state load. My vote: ship the sparkle.

5. **What happens on day 76 if the user hasn't tapped "next program"?** Strip presumably caps at 75 cells. Does the user see a 76th cell with a checkmark+confetti, an empty `+` cell prompting program selection, or does the strip just vanish? This is Phase 5 territory but design needs the answer before strip rendering is finalized. **My vote: 75-cell cap, swipe-right reveals a `+ new program` cell after day 75, no autoplay.**

---

## Appendix — what NOT to do (anti-patterns the founder should refuse from any future iteration)

- **Per-cell completion percentage** (e.g. "60%" inside the pill). Reads as a productivity app. JeniFit is a program, not a project tracker.
- **Color-graded heatmap calendar** (green→yellow→red by completion). Anti-shame violation.
- **Streak counter anywhere on PlanView**. Streaks belong on the becoming tab if anywhere; on the today tab they create loss aversion. The day-strip + the completion caption are already enough commitment device.
- **Coach avatar in the header**. Locked by paywall research; restated here because it'll get suggested again.
- **Photo thumbnails on rows**. Wrong register. Sticky-note is the move.
- **Em-dashes anywhere in the lock sheet copy.** I had to police my own draft three times. Watch this in QA.
