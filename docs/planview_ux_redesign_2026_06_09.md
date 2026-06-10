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

---

# Revision v3 (2026-06-09 evening) — hero drop + today-pinned strip

## v3.1 What changed and why

Founder pulled two threads in the same QA pass:

1. **Drop the 52pt italic-Fraunces hero.** It was eating ~110pt of vertical real estate that the program structure (strip + checklist) needs more than the brand needs an editorial moment. Without the hero, the question is *where the JeniFit voice signature lives* — it can't disappear, only relocate.
2. **Pin today to the visible center of the day-strip at all times.** v2's "scroll today into center on appear, then user can pan freely" is replaced with "today is anchored — the strip never rests off-center." Together with #1, this turns PlanView from *masthead → strip → checklist* into *strip → checklist*, with the strip as the new first read.

The intent I'm reading: the program — not the prose around it — is the brand on PlanView. her75 reads the same way (no hero, just title + mosaic + rows). The italic-Fraunces hero belongs on screens where the user is being *introduced* to something (paywall, onboarding, becoming tab). PlanView is the *daily ritual* surface; daily rituals don't need a headline every time you open them.

## v3.2 New ASCII mockup — Day 12 of 75, hero removed, today pinned center

iPhone 15 width: 393pt. Visible body region.

```
┌─────────────────────────────────────────────────────────────┐ ← status bar
│  9:41                              · · · · · · ·            │
├─────────────────────────────────────────────────────────────┤
│                                                             │ ← 24pt
│  day 12 of 75                                  ⋯            │ ← eyebrow L + overflow R
│                                                             │ ← 18pt
│  ┌───┬───┬───┬───┬───┬───┬───┐                              │
│  │ 9 │10 │11 │12 │13 │14 │15 │   ← today pinned center      │
│  │ ✓ │ ✓ │ ✓ │ • │ 🔒│ 🔒│ 🔒│   (cell 4 of 7 = today)      │
│  └───┴───┴───┴───┴───┴───┴───┘                              │
│            ─── today ───                                    │ ← tiny center marker (caption italic)
│                                                             │ ← 22pt
│  ┌─────────────────────────────────────────────────────┐    │
│  │                                                     │    │
│  │  ╔═══╗   today's lesson           ›        ◉        │    │
│  │  ║ 1 ║   why protein keeps you full · 2 min          │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   snap a meal              ›        ◉        │    │
│  │  ║ 2 ║   2 logged today                              │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   move                     ›        ◯        │    │
│  │  ║ 3 ║   18 min, gentle today                       │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   steps                            ░◐░       │    │
│  │  ║ 4 ║   4,820 of 7,500                             │    │
│  │                                                     │    │
│  │  ─────────────────────────────────────────          │    │
│  │                                                     │    │
│  │  ╔═══╗   weigh-in                  ›       ◯        │    │
│  │  ║ 5 ║   sunday check                                │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │ ← 24pt
│  3 of 5 done. you're *showing up*.                          │ ← italic Fraunces on punch word
│                                                             │
└─────────────────────────────────────────────────────────────┘
              [ today ]      [ becoming ]                       ← tab bar
```

Key proportions: eyebrow row ~28pt, strip block (cells + tiny marker) ~92pt, checklist card ~440pt, micro-caption ~24pt. Total ~620pt — comfortably fits on iPhone 15's 852pt usable region with a generous 80pt tab-bar buffer. The hero's 110pt is reclaimed and redistributed: ~22pt back to top inset breathing, ~88pt back to bottom tab-bar/card breathing. **The screen feels less crammed, not just less editorial.**

## v3.3 Hero replacement decision — (c) voice signature migrates DOWN to the micro-caption

Picked: **eyebrow stays as the only top-of-screen text; the italic-Fraunces punch word migrates from the hero into the micro-caption below the card.**

Why not (a) pure no-hero, eyebrow only:
- Loses the JeniFit voice entirely from PlanView. The brand becomes invisible on the most-opened screen. Bad trade.

Why not (b) tiny "today" label / date / day-name:
- A "Friday" or "Today, Jun 9" line just adds calendar register. The eyebrow `day 12 of 75` already does the temporal anchoring, and the strip's pinned-center today-cell does it visually. A third label is noise.

Why (c) — relocate the italic-Fraunces to the micro-caption:
- The hero was carrying *two* jobs: editorial mood-setter AND voice-signature carrier. Removing it killed the mood-setter (fine — daily ritual doesn't need one) but orphaned the voice job. The micro-caption is already cocoa-tertiary supporting copy at the bottom of the screen; promoting it from plain DM Sans to "DM Sans with one italic Fraunces punch word" lets it carry the brand without competing with the strip + card for attention.
- This matches the **[[feedback-voice-signals]]** rule literally — italic Fraunces ONLY on punch words. The hero was breaking that rule subtly (full phrases italicized). Migrating to the micro-caption restores the original discipline.
- It also means the brand voice signs *the user's accomplishment*, not the screen's greeting. "you're *showing up*." sits underneath what she actually did today, not above. That's a meaningfully more dignified register for the cohort.

New micro-caption copy with punch-word italics (italic = Fraunces SBItalic, surrounding text = DM Sans Regular 13pt):
- 0/5: "a fresh page. *start anywhere*."
- 1/5: "you *opened* the door."
- 2/5: "you're *moving*."
- 3/5: "you're *showing up*."
- 4/5: "one to go. or don't. *either's fine*."
- 5/5: "all 5. you *closed* the day."

Eyebrow stays: `day 12 of 75`, Fraunces SB 11pt, uppercase, cocoaTertiary, 0.66 kerning. **Critical: the eyebrow now also reflects scrapbook mode** — when `viewingDay` is set, it reads `day 8 of 75` (not `viewing day 8`). The scrapbook-mode signal moves to the strip cell + the pill below it (see §v3.4).

## v3.4 Day-strip interaction model — (b) swipe-allowed, snaps back to today-centered on release

Picked: **the strip CAN be swiped (for scrapbook browsing) but auto-recenters today on release.** A long pan with no tap = strip springs back. Only a tap on a specific past cell commits to scrapbook mode.

Why not (a) fixed 7-cell window with no swipe:
- Solves "today is always centered" but kills tactile discovery. The user with a 60-day program can't browse her own history without context-switching to the Becoming tab. The strip is RIGHT THERE on every open — making it inert wastes the affordance. Also: fixed-only forces a second navigation surface (Becoming grid) to do work the strip should do for the day-1-of-60 case.
- BetterMe uses fixed-with-chevrons; her75 has no strip at all. Neither pattern earns the inert version.

Why not (c) two strips:
- Overengineered. A second affordance to do what one affordance can do well. Skip.

Why (b) — swipe-allowed, snap-back:
- The strip's primary job is "show me today + the locks I haven't earned + the past I've completed." That job needs today centered at rest. The strip's secondary job is "let me peek at day 5 from day 47." That job needs touch responsiveness. Snap-back gives both: at rest, today is centered; mid-pan, the user is browsing; on release without tap, it springs home.
- Founder gets the "today always centered" guarantee for every open + every non-committal swipe. Cohort gets the discovery for the cases that need it.
- The interaction reads as "today is gravity." Releasing the strip feels like releasing a soft elastic. This composes with the cocoa+cream sticky-note craft register — the strip behaves like a piece of paper that wants to lie flat on today.

### Exact gesture spec

- **Default state**: today cell sits at horizontal center of the visible viewport. The 3 cells to the left + 3 cells to the right are visible (= 7-cell window centered on today).
- **Pan gesture (horizontal drag)**: strip follows the finger 1:1 within the bounds of `[1...totalDays]`. No rubber-banding past day 1 or day N.
- **Release WITHOUT a tap during the pan**: with `Motion.gentleSpring` (response 0.55, damping 0.88), the strip animates back to today-centered. ~400ms.
- **Tap on a past cell during the pan** (or after release while still off-center): commits scrapbook mode. The tapped cell animates to the visible center, the cell highlights (subtle `Palette.accentSubtle` ring 1pt for 600ms then fades), and the checklist card cross-fades to that day's snapshot. The strip STAYS centered on the tapped past day until the user either taps the today cell, taps the scrapbook-mode pill, or pans + releases without tapping (which springs back to today).
- **Tap on a locked cell**: lock sheet fires (unchanged from v2). Strip does NOT shift center to the locked cell — locked cells are tap-to-narrate, not tap-to-navigate. After sheet dismiss, the strip snaps back to today-centered.
- **Tap on the today cell** while in scrapbook mode: exits scrapbook (same as v2). Strip is already centered.
- **`onScrollGeometryChange` threshold for "user has scrolled"**: stays at 40pt pan distance, same as v2, used to dismiss the first-launch hint.

### Walking the day-47-of-60 user to day 1

1. She opens PlanView. Strip shows days 44–50, today (47) centered.
2. She drags right (pan finger left-to-right). Strip moves with finger; days 41–47 visible, then 35–41, etc.
3. She keeps dragging until day 1 is on screen.
4. She taps day 1. Strip animates so day 1 is the centered cell, checklist crossfades to her day 1 snapshot. Scrapbook pill appears: "*viewing* day 1" — italic on "viewing" (new — see below).
5. She taps the pill OR taps the today cell on the strip (still tappable; it's just off-center now). Strip springs back to centering day 47, checklist crossfades back to today.

This is a one-handed-thumb workflow on iPhone 15. No need to context-switch to Becoming. Becoming's `ProgressGridView` stays as the canonical "see every day in a grid" surface but it's a *complement*, not the only path — for the "I want to glance back at last week" case the strip is faster.

### "But what about day 60 of 60 case where the user wants day 1 fast"

- Strip-drag at native iPhone scroll speed crosses ~40 days in ~1.5s. Day 1 of a 60-day program is ~2s away with one fling. Acceptable.
- For 90-day or 120-day programs (v2+ scope) we'd revisit — possibly add a long-press-on-eyebrow shortcut that opens Becoming's grid. Not v3 scope.

### Scrapbook-mode pill — small copy refresh

Current: `viewing day 8`. v3: italicize the verb to match the new voice-signal location:

```
*viewing* day 8   ×
```

`Typo.caption` for the surrounding text, Fraunces SBItalic 13pt for `viewing`. Same accentSubtle capsule. This is consistent with the new "italic-Fraunces lives on punch words below-the-fold" rule and reinforces that scrapbook mode is a *soft state*, not a navigation.

## v3.5 Strip layout change

v2 was 44pt cells, 8pt gap, height 56pt — that math (7 × 44 + 6 × 8 = 356pt) fits 393pt iPhone 15 width with 24pt horizontal padding (= 345pt available). **It does NOT fit comfortably.** It crams. The brief flagged this. Founder is right to push.

**New: 42pt cell width, 8pt gap, 56pt height.**

- 7 × 42 + 6 × 8 = `294 + 48 = 342pt`. Within 345pt available with 1.5pt visual breathing on each side. Feels intentional, not crammed.
- Cell is still ≥40pt × ≥56pt; tap target wrapped with `tappableArea(_)` to 44pt minimum so HIG is preserved (same as v2). The 42pt × 56pt visual reduction is purely chrome — the touchable hit zone stays 44pt.
- Cell internal layout unchanged: numeral on top, 4pt gap, state glyph (lock / check / dot) below. The 42pt-wide cell still comfortably renders DMSans-SemiBold 17pt digits + the 8–9pt state glyph.
- Corner radius stays 10pt.

**Strip area total height**: 56pt cell + 4pt gap + 14pt "── today ──" marker line = **74pt**. Down from v2's 56pt-cell + 24pt hint-spacing-block = 80pt+. Net: roughly the same vertical footprint but with more useful information (always-on today marker vs first-launch-only hint).

### New "── today ──" center marker

A thin horizontal hairline + tiny "today" label centered directly below the strip, replacing the old `← swipe to see all N days →` hint. Spec:

- Two 28pt-wide 0.5pt hairlines in `Palette.hairlineCocoa`, with the word `today` centered between them in Fraunces SBItalic 11pt, `Palette.cocoaTertiary`.
- Total marker block: ~80pt wide, centered horizontally under the strip.
- The marker pulls the eye to *exactly* the center cell at rest. In scrapbook mode, the marker copy changes to `── day 8 ──` (number replaces "today") so the user always has a written confirmation of which cell is centered. The italic stays.
- **This replaces the first-launch hint entirely.** The marker is always-on, not a one-time tutorial. It does triple duty: (1) visually reinforces "today is the anchor," (2) confirms which cell is the active context in scrapbook mode, (3) is itself a small piece of italic-Fraunces brand voice tucked into the strip chrome.
- AppStorage keys `planview_strip_hint_dismissed_count` and `planview_strip_user_scrolled` become **unused** — kill them in code (see §v3.8).

## v3.6 Voice signature relocation — summary

The italic-Fraunces JeniFit voice signal now lives in **two quiet places** on PlanView instead of one loud place:

1. **The strip's center marker**: `── today ──` (italic Fraunces 11pt). Always-on, sub-strip chrome.
2. **The micro-caption below the card**: `you're *showing up*.` (italic Fraunces 13pt on the punch word). Promoted from plain DM Sans.

Both are small. Both are punch-word-only (rule preserved). Both sit *below* primary content, supporting it rather than headlining it. Brand presence is preserved without competing for the user's first read.

Net effect: where v2 said "JeniFit greets you with a poetic line, then shows you the program," v3 says "JeniFit shows you the program, and signs its work at the bottom." That's the more confident posture for a daily-ritual surface.

## v3.7 Updated screen composition spacing

Vertical rhythm from safeArea-top → bottom tab bar buffer:

| From | To | Pt |
|---|---|---|
| safeArea top | eyebrow | 24 |
| eyebrow | strip | 18 |
| strip | center marker | 4 |
| center marker | scrapbook pill (if visible) | 16 |
| scrapbook pill (or marker if no pill) | checklist card | 22 |
| checklist card | micro-caption | 24 |
| micro-caption | tab bar buffer | 60 |

Notes vs v2:
- Top inset 28 → 24 (the eyebrow doesn't need as much air without the hero crowning it).
- Strip → card was 24 + 8 (hint) + 24 in v2 ≈ 56pt; v3 is 4 + 22 = 26pt (the center marker replaces the hint and tucks closer to the strip, the card moves up).
- Card → micro-caption was 28 in v2; trimmed to 24 because the italic Fraunces in the caption now carries more weight visually and wants slightly less air above it.

## v3.8 What this changes downstream

### PlanView.swift

- Delete: the `hero` view + `Typo.programHeroDisplay/Italic/programHeroLineGap` references on PlanView (the typography tokens themselves stay for use elsewhere — onboarding, paywall, becoming).
- Delete: `stripHint` view + `shouldShowStripHint` computed + `stripHintDismissedCount` + `stripUserScrolled` `@AppStorage` properties + the increment branch in `onAppear()`. **The strip hint is gone.**
- Update: `viewingPastPill` copy from `"viewing day \(d)"` to italic-Fraunces `viewing` + `" day \(d)"` — likely a small helper that returns `Text + Text` with mixed fonts (same pattern as `hero`'s current "gently" + "." composition).
- Update: `eyebrow` view stays, but `viewingDay` is now sourced from the strip's *centered* day, not from a separate `@State` (these were already coupled in v2 but the rule is now strict: `eyebrow.day = stripCenteredDay`, where `stripCenteredDay = viewingDay ?? schedule.programDay`).
- Update: top-level `VStack` spacing from §v3.7. The `Spacer().frame(height: ...)` ladder gets rewritten.
- Update: `PlanViewMicroCaption` is now responsible for mixed-font rendering (italic Fraunces on punch word). New API: takes the bucket index, internally maps to a `(prefix: String, italic: String, suffix: String)` tuple, renders `Text + Text + Text`.

### ProgramDayStrip.swift

- **Behavior overhaul** — this is the biggest code change:
  - Cell width 44 → 42.
  - Replace `.scrollTargetBehavior(.viewAligned)` with custom snap-back-to-today logic. SwiftUI doesn't ship a "snap to a specific id on drag-end" affordance, so the implementation path is: wrap the `ScrollView` in a `GeometryReader` to measure offset, track drag with a `DragGesture(minimumDistance: 4)`, and on `onEnded` (no tap committed) animate `ScrollViewReader.scrollTo(programDay, anchor: .center)` with `Motion.gentleSpring`.
  - Track "did the pan resolve with a tap?" via a `@State var didTapDuringPan: Bool = false`. Tap handlers (`onTap` per cell) set this true; the gesture `onEnded` checks it before deciding whether to spring back.
  - Add `@Binding var stripCenteredDay: Int` — bidirectional with PlanView so the eyebrow + center marker can read the centered day. PlanView writes nil to reset to today; ProgramDayStrip writes the tapped-past-day value on commit.
- **Cell visual**: width 44 → 42 only. Internals unchanged.
- **Center marker**: NEW. Render as a `HStack { Hairline; Text("today" or "day \(d)"); Hairline }` underneath the ScrollView, in a tightly-coupled VStack so the marker doesn't drift if the strip changes height. Total strip height bumps from `.frame(height: 56)` to `.frame(height: 74)`.
- **Accessibility**: VoiceOver announce of strip should now read "Day strip. Today is day 12 of 75. Swipe through to view past days." (combined VoiceOver label on the outer container).

### PlanRow / ProgramStickyNote / ProgramLockSheet

- **No changes.** All three are locked from v2.

### Removed AppStorage

```swift
@AppStorage("planview_strip_hint_dismissed_count") // DELETE
@AppStorage("planview_strip_user_scrolled")        // DELETE
```

No migration needed — these were write-only flags that gated a UI hint. Cleaning them is pure code deletion.

## v3.9 Open questions

1. **Snap-back animation feel — is `gentleSpring` (damping 0.88) the right resistance, or should it be slightly springier (damping 0.78) so it feels more "alive" when the user releases a fast pan?** My vote: ship gentleSpring (clean luxury > novelty), revisit if QA flags it as too dead.

2. **Should locked cells be tappable at all in v3, or is "tap-to-narrate" still the right behavior?** Now that today is pinned and the strip is more clearly a "program structure visualizer" than a "navigation widget," locked cells could plausibly become non-interactive (visual only). My vote: keep tap-to-narrate — the lock sheet is doing real trial-conversion narrative work per [[v2 §5]] and removing it for visual purity loses the commitment-device function the strip exists to provide.

3. **Eyebrow during scrapbook mode — does it read `day 8 of 75` (clean) or `day 8 of 75 ·   viewing` (explicit)?** v3 spec says clean (the scrapbook pill below the strip carries the "viewing" signal). Want founder confirm before code lands — if she wants belt + suspenders, we add the suffix.

---

# Revision v4 (2026-06-09 evening) — PlanRow anatomy: drop chevron, type-aware leading icon, progress rows split out

## v4.1 What changed and why

Three v3-shipped problems caught in founder QA on the row pattern itself (strip + composition + outer card all stay locked):

1. **Every row used the same chevron + checkbox trailing.** Five rows × two-affordance trailing module reads as "spreadsheet of pending tasks" — exactly the productivity-app register PlanView was supposed to escape. Worse: the steps row, which can't be checked off because it's HealthKit-driven, was rendering an inert disabled checkbox + a `sparkle` glyph that fired *only after* the goal was hit. Pre-goal state was a non-tappable empty circle that looked broken.
2. **56pt sticky-notes dominate.** They were the v2 craft signal when each row had less trailing weight. v3 piled a chevron + checkbox into the trailing region and the sticky-note's visual mass collided with that — now both sides shout, the title text gets squeezed, and the row stops feeling like a list and starts feeling like a row of cards.
3. **Chevron 13pt + checkbox 26pt at 8pt apart fails the thumb test.** I called this out softly in v2 (§3 "small enough to feel like one trailing module, big enough that thumb taps don't fight") and it was wrong. The 8pt gap is not big enough. BetterMe (the reference I anchored on) puts them on OPPOSITE ENDS of the row — checkbox far left, chevron far right — and that spatial separation is doing 90% of the ergonomics work. Forcing both to the right was a misread.

The intent I'm reading now: each row should declare its own *kind* on first glance. A lesson is a thing-to-tap-and-read. A snap-meal is a thing-to-tap-and-capture. Steps are a thing-the-phone-is-doing-for-you. Weigh-in is a Sunday ritual. A uniform row template flattens those into one ambient surface and loses the per-row affordance literacy the cohort needs to feel the program working.

## v4.2 The decision matrix — pick (a) BetterMe-pattern (drop chevron, keep checkbox, split out progress rows)

Walked through all four:

- **(a) drop chevron, keep checkbox, row IS the module-launcher** — what BetterMe does. Single primary affordance on the row body. Checkbox is a small explicit secondary on the right. Progress rows replace the checkbox with a thin bar + numeric label, no checkbox at all. **Picked.**
- **(b) drop checkbox, keep chevron, auto-complete only** — pure telemetry trust + hidden swipe action for manual override. Beautiful in theory. Wrong for this cohort. The user *needs* to feel agency over the checklist; an empty row that filled itself "because the phone saw you opened the lesson" is opaque and uncontrollable. Also: lesson + breath + meal capture all need user-explicit confirmation moments today because telemetry isn't 100% reliable (offline use, app-switching mid-session, etc.). Manual checkbox is load-bearing.
- **(c) checkbox left + chevron right (full BetterMe trailing-region split)** — solves ergonomics, but doubles the chrome per row (we'd have leading sticky + leading checkbox + center text + trailing chevron = four columns of affordance). Reads as gym-app density. Also forces a 2x leading-region rework when the steps row replaces the left checkbox with something else. The cost-benefit doesn't land.
- **(d) something else** — nothing better surfaced.

Why (a) over (c) specifically: **the chevron in v3 was never carrying its weight.** It was a visual hint that the row was tappable, but the entire row body is already tappable, the sticky-note pulls the eye, the title sits at the top of a v-stack — the row reads as tappable without the glyph. Removing the chevron sheds chrome without removing affordance. BetterMe ships their chevron because their rows host *both* photo-thumbnail content (which reads as media, not as a button) AND module-launching; the chevron compensates for the photo's button-uncertainty. Our sticky-note reads as marker, not media, so the row is unambiguously a button without help.

Founder ref-tier check: her75 ships zero chevrons, zero progress bars, zero auto-rows. We're going *further* than her75 here, not copying — because her75 doesn't have telemetry-backed rows or HealthKit-backed rows, and we do. The pattern is: her75 chrome restraint + BetterMe row mechanic + a JeniFit-specific third pattern (progress row) the references don't have.

## v4.3 Leading element redesign — shrink sticky-note 56→40 AND add a type glyph

Picked: **40pt sticky-note, numeral shrunk proportionally, with a small SF symbol type-icon centered on the sticky's face instead of the integer.**

The numeral 1-2-3-4-5 in v3 carried no information — row order is already conveyed by row position. The sticky's *job* was the craft signal (paper square, warm pastel, hand-rotated). The integer was filler. Replacing the integer with a per-row-type SF symbol turns the sticky into BOTH craft signal AND type identifier in the same 40×40pt — net win, no extra chrome.

### Sticky-note v4 spec

- **Size**: 40pt × 40pt (down from 56pt — 29% area reduction)
- **Corner radius**: 5pt (down from 6pt, proportional)
- **Rotation**: ±1.5° alternating by index (down from ±2° — smaller note, lower rotation reads as more controlled)
- **Shadow**: unchanged — `Color.black.opacity(0.06), radius 3, x 0, y 1`
- **Fill**: same `stickyMint/Butter/Rose/Olive` cycle BUT now keyed by **row type**, not row index. Lesson = mint, snap = butter, move = rose, steps = olive, breath = mint, weigh-in = butter, water = rose, measurements = olive. Type-consistent color across days = users learn to recognize the row at a glance. (This is the BetterMe thumbnail-recognition pattern done in 40pt sticker form.)
- **Center glyph**: SF symbol at 16pt, weight `.medium`, color `Palette.cocoaPrimary`. Per type:
  - **today's lesson** → `book.closed`
  - **snap a meal** → `camera`
  - **move** → `figure.run` (works; existing JeniFit asset register uses this)
  - **steps** → `figure.walk`
  - **breath** → `leaf` (matches Becoming tab breathwork tile precedent)
  - **weigh-in** → `scalemass`
  - **water** (Phase 3) → `drop`
  - **measurements** (Phase 2) → `ruler`

### What this preserves of her75 craft register

- The pastel paper-square *shape* and *rotation* and *shadow* are intact. That's what made the sticky read as craft, not the integer. The 40pt size is still distinctly hand-cut sticky-note, not iOS app-icon.
- The font that carried craft in v3 (Fraunces SBItalic numeral) is *not* gone from PlanView — it lives in the micro-caption italic punch word and the strip's `── today ──` marker (both locked from v3.6). The Fraunces voice signal didn't depend on the sticky; the sticky was just one of three places it lived.
- The 56pt v3 sticky was honestly a *bit* of a brand cosplay — her75's stickies are 56pt because her75 has no other content in the row. Once we added title + subtitle + chevron + checkbox, the 56pt was over-allocation. 40pt is the right size for OUR row composition, not theirs.

### What we lose

- Numerical ordering glyph. Trade is fine: row position conveys order, the integer was redundant in v3, and SF symbols give us per-type identity which is more functional. If founder wants to keep a *trace* of the numeric register, we can put a tiny 8pt index numeral in the top-right corner of the sticky in Fraunces SBItalic — that preserves the "five-thing checklist" feel without the integer dominating. **Default ship: no corner numeral.** Add only if founder requests after seeing the render.

## v4.4 Progress-row pattern (new — steps, water, anywhere with auto numeric target)

Steps was the row that broke the v3 spec. v3 said "auto-completed rows show a half-circle progress glyph in the checkbox slot." But steps is auto-progressing *all day*, not auto-completing at a discrete moment. The half-circle was static (rendered once at 50% regardless of actual progress) and the actual completion ratio lived only in the subtitle as text. Both were wrong.

v4 splits progress rows into a fully separate pattern:

### Progress-row trailing region

```
[ 4,820 / 7,500  ▭▭▭▭▭▭▱▱▱▱ ]
   numeric label    thin bar
```

- **Bar**: 64pt wide, 3pt tall, fully rounded ends (1.5pt corner radius). Background fill `Palette.hairlineCocoa` (12% cocoa, same hairline color the dividers use). Filled portion uses `Palette.stateGood` (sage green) at the user's actual progress fraction.
- **Numeric label**: directly LEFT of the bar with 8pt gap. `Typo.caption` (DM Sans Medium 13pt), `Palette.cocoaSecondary`. Format: `4,820 / 7,500` — slash separator (not "of"), no unit appended for steps (the row title says "steps"). For water: `6 / 8 cups` — slash + unit, because "6 / 8" alone is ambiguous.
- **No checkbox.** Period. There's nothing to check.
- **No chevron.** Already dropped per §v4.2 for all rows.
- **No sparkle until 100%.** Pre-100, the row just looks like itself — bar filling, label updating. The savvy user recognizes this *is* auto from the absence of a checkbox.
- **Subtitle in the row's center v-stack**: rendered slightly differently — instead of progress text (which now lives trailing as the numeric label), the subtitle carries *context* copy. For steps: "your daily walk" or "7,500 is your target." For water: "small sips throughout the day." Quiet supporting copy, not progress data.

### Progress-row complete state

When `progress >= target`:

- Bar fills 100% in `Palette.stateGood`.
- Numeric label flips to italic-Fraunces: `7,500 / 7,500` becomes `*reached* · 7,500`. Italic punch on "reached" is the JeniFit voice signal honoring [[feedback-voice-signals]] (the same italic Fraunces SBItalic rule the micro-caption uses). 13pt.
- Small `sparkle` glyph (SF symbol, 8pt, `Palette.cocoaTertiary`) appears to the immediate right of the bar. This is the v2/v3-spec "system did this for you" signal — *only fires when auto completion has actually completed*, not pre-completion.
- Row remains non-interactive (tap is noop with light haptic + 600ms tooltip "syncs from your steps" via popover if the user taps the bar — see §v4.6).

### "Does the progress bar look like a gym-tracker bar?"

Risk acknowledged. Mitigations:

- 3pt height (not 6, not 8) — reads as hairline, not gym-app fitness bar.
- 64pt width, no rounded-rect outer chrome, no gradient fill, no percentage label. Just the bar + the count.
- Sage `stateGood` color, not lime/electric green. Same `stateGood` used for the checkmark fill on binary rows, so the visual language is unified.
- Sits next to a *numeric* label (4,820 / 7,500), not a *percentage* label. Avoids "60%" productivity-tracker register per [[v2 §8 anti-patterns]].
- her75 has no progress bars because they have no auto-tracked rows. BetterMe's progress treatment is a 1pt full-row-width green underline at the bottom edge of the row — too gym-app-coded for us. Our 3pt 64pt inline bar is the cleaner-register cousin.

## v4.5 Per-row-type affordance table

```
ROW              LEADING            CENTER (title / sub)            TRAILING
─────────────────────────────────────────────────────────────────────────────
today's lesson   📖 sticky-mint     today's lesson                  ◯ checkbox
                                    why protein keeps you full · 2m
─────────────────────────────────────────────────────────────────────────────
snap a meal      📷 sticky-butter   snap a meal                     ◯ checkbox
                                    2 logged today
─────────────────────────────────────────────────────────────────────────────
move             🏃 sticky-rose     move                            ◯ checkbox
                                    18 min, gentle today
─────────────────────────────────────────────────────────────────────────────
steps            🚶 sticky-olive    steps                           4,820 / 7,500 ▭▭▭▭▭▱▱
                                    your daily walk
─────────────────────────────────────────────────────────────────────────────
breath           🍃 sticky-mint     breath                          ◯ checkbox
                                    1 min, calming
─────────────────────────────────────────────────────────────────────────────
weigh-in         ⚖ sticky-butter   weigh-in                        ◯ checkbox
                                    sunday check
─────────────────────────────────────────────────────────────────────────────
water            💧 sticky-rose     water                           6 / 8 cups ▭▭▭▭▭▭▱▱
   (Phase 3)                        small sips throughout the day
─────────────────────────────────────────────────────────────────────────────
measurements     📏 sticky-olive    measurements                    ◯ checkbox
   (Phase 2)                        monthly check
─────────────────────────────────────────────────────────────────────────────
```

Two trailing patterns total:
- **Binary** (lesson / snap / move / breath / weigh-in / measurements): 26pt circle checkbox, right-aligned, 20pt from row edge. Empty = 1.5pt cocoa-tertiary stroke. User-marked complete = `checkmark.circle.fill` in `stateGood`. Auto-marked complete (telemetry, e.g. snap-meal auto-fires on FoodScanRecord insert) = `checkmark.circle.fill` in `stateGood` + 8pt `sparkle` glyph 4pt to the left.
- **Progress** (steps / water): numeric label + 64pt × 3pt bar, right-aligned, 20pt from row edge. No checkbox. Complete state per §v4.4.

The `in-progress` half-circle from v3 is **deleted entirely.** Binary rows are either empty or complete — there's no "started but not done" because the action that triggers them (read lesson, open camera, finish session, log weight) is atomic and the telemetry fires once.

The `.skipped` and `.restDay` states from v3 also lose their checkboxes (em-dash glyph stays, sized to align with the 26pt checkbox column). They're shipping-locked for v2/v3 future scope so the spec keeps them, just rendered without the chevron column.

## v4.6 Tap-zone separation — the new gesture model

With chevron gone and progress rows separated out, the tap zones get dramatically simpler than v3:

### Binary rows

- **Row body tap** (sticky + center v-stack + the trailing region MINUS the checkbox 44pt zone) → enters the module. `contentShape(Rectangle())` on the row body Button. Hit area = ~340pt × 76pt minus the 44pt checkbox.
- **Checkbox tap** (44pt hit zone, top-right of row, padded around 26pt visual) → toggles `onCheckToggle`. Uses `simultaneousGesture` / split-button pattern from v3 so it doesn't propagate to row tap. Already wired correctly in v3 `PlanRow.swift` — the checkbox is its own Button outside the row-body Button.
- **Long-press on row body** → no-op for v4 (future scope: "mark skipped" sheet, currently not in scope).
- **Long-press on checkbox** → no-op (future scope: hidden swipe-action to mark skipped).

### Progress rows

- **Row body tap** (sticky + center v-stack + numeric label + bar) → opens a small `.height(280)` bottom sheet with: the day's step graph (or water cups grid for water), the target, a "change target" link routing to existing `StepsDetailView` / `WaterDetailView`. Not a noop — but not a primary navigation either. Light haptic only.
- **Tap on the bar specifically** → same as row body. Don't fragment the affordance.
- **No tap target on a "complete" state** that differs from in-progress — same sheet either way. Once at 100%, the sheet also shows the small "you reached today's target" line.

The reason progress rows DO have a tap target (vs being fully inert):
- Founder's instinct in the brief was "tappable progress bar opens StepsDetailView? noop? popover?" — noop is too cold, full nav to StepsDetailView is too heavy (kicks user out of PlanView, and StepsDetailView is becoming-tab-coded). A small sheet with the day's detail is the middle path. Lets the curious user check the hourly distribution without leaving Plan.
- It also gives a controlled answer to "what happens if I tap the row that has no chevron and no checkbox?" — the screen does *something*, just something lightweight.

### Steps tap-handler precedent (existing code)

Reuse the SheetPresenter pattern from `HomeView` for the StepsBottomSheet. Don't build a new modal harness.

## v4.7 Updated row ASCII mockup — 5 rows, mixed types

iPhone 15 width: 393pt. Card horizontal padding 20pt → row width ~353pt.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │ ← 14pt top pad
│  ┌──┐                                                       │
│  │📖│  today's lesson                              ◯        │ ← binary, empty
│  └──┘  why protein keeps you full · 2 min                   │
│                                                             │
│  ───────────────────────────────────────────────────        │ ← 0.5pt hairline, leading 80pt indent
│                                                             │
│  ┌──┐                                                       │
│  │📷│  snap a meal                                ✓✨       │ ← binary, auto-complete
│  └──┘  2 logged today · auto                                │
│                                                             │
│  ───────────────────────────────────────────────────        │
│                                                             │
│  ┌──┐                                                       │
│  │🏃│  move                                        ◯        │ ← binary, empty
│  └──┘  18 min, gentle today                                 │
│                                                             │
│  ───────────────────────────────────────────────────        │
│                                                             │
│  ┌──┐                                                       │
│  │🚶│  steps                       4,820 / 7,500 ▭▭▭▭▭▭▱▱▱ │ ← progress, in-progress
│  └──┘  your daily walk                                      │
│                                                             │
│  ───────────────────────────────────────────────────        │
│                                                             │
│  ┌──┐                                                       │
│  │⚖│  weigh-in                                    ◯        │ ← binary, empty
│  └──┘  sunday check                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘ ← 14pt bottom pad
```

Visual contrast notes:
- The two patterns sit comfortably in the same card. The steps row has more horizontal trailing content (label + bar) but the *visual weight* matches a checkbox because the bar is 3pt and the label is `caption`-sized. The row doesn't feel taller or busier than the binary rows.
- Sticky-notes at 40pt sit tight to the title baseline — feels like a marker beside the line, not a tile. Compare v3 where the 56pt sticky was as tall as both lines of text combined and read as a "card within the row."
- The empty checkbox + the progress bar both terminate at the same 20pt trailing margin. The vertical alignment column on the right edge is preserved — the user's eye tracks a clean right edge down the card.
- Total card height with 5 rows + 14pt top + 14pt bottom + 4 hairline dividers ≈ 410pt (down from v3's ~440pt at 76pt rows × 5). The row height target stays ~76pt but the leading element shrinking gives back ~6pt of internal vertical air per row.

## v4.8 What this changes in code (≤200 words)

**`PlanRow.RowState` enum:**
- Delete `.inProgress(currentValue: String?)` — half-circle pattern killed.
- Keep `.empty`, `.completeUser(completedAt: String?)`, `.completeAuto`, `.skipped`, `.restDay`.
- Add `.progress(current: Int, target: Int, label: String)` — `label` is the unit suffix (`""` for steps, `"cups"` for water). State carries enough to render the bar + numeric label.

**`PlanRow.swift` body:**
- Delete the chevron `Image(systemName: "chevron.right")` block entirely.
- Replace checkbox switch with a `trailing` ViewBuilder that branches: `.progress` → `ProgressTrail(current, target, label)` view, all other states → existing checkbox switch.
- Update `state.hidesChevron` → delete (no chevron at all). Rename `state.rowIsInteractive` semantics: `.progress` is interactive (opens sheet), `.restDay` stays non-interactive.
- Row body Button onAction: for `.progress`, call new `onProgressTap` closure → opens sheet. For all others, existing `onEnter`.

**`ProgramStickyNote.swift`:**
- New API: `ProgramStickyNote(rowType: ProgramRowType)`. Takes a type enum (lesson/snap/move/steps/breath/weighIn/water/measurements), not an index.
- Render: 40×40pt fill keyed by type → color, SF symbol centered keyed by type → glyph, ±1.5° rotation alternating by type's `index` in the row order (deterministic per day).
- Delete `index: Int` param + numeric `Text("\(index)")` render.

**`PlanView.swift`:**
- StepsBottomSheet wiring + `onProgressTap` closure per progress row.

**Sparkle relocation:**
- Stays in place on `.completeAuto` binary rows (4pt left of checkmark, 8pt size).
- Adds to `.progress` rows when `current >= target` (4pt right of bar). Same glyph, same size, same color.

## v4.9 Open questions

1. **Type-keyed sticky color vs index-keyed sticky color** — I picked type-keyed (lesson always mint, snap always butter) for recognition. Founder may prefer index-keyed (preserves the v2/v3 cycling pattern, no "lesson = mint" semantic to remember). Trade is recognition speed vs visual variety per day. **My vote: type-keyed. The cohort opens this screen 30+ times in 75 days; consistent type-color halves the cognitive load by day 10.**

2. **Tiny 8pt corner numeral on the sticky (preserve the "1/2/3/4/5" trace) or no?** v4 default is no. If founder misses the "5 things" countability, the 8pt Fraunces SBItalic top-right corner numeral is a 5-minute add. **My vote: ship without; if founder requests after seeing the render, add.**

3. **Progress-row tap behavior — small sheet vs noop vs route to StepsDetailView in becoming tab?** Spec says small sheet (the middle path). The noop option is cleaner-register but reads as broken on a non-trivial percentage of attempts. Routing to StepsDetailView crosses the tab boundary which is wrong. **My vote: small sheet. Build StepsBottomSheet as a new component; reuse the data layer from StepsDetailView.**

---

# Revision v5 (2026-06-09 late) — load-bearing rows go fat, ritual rows stay compact

## v5.1 What changed and why

v4 shipped a uniform 76pt row across all five daily checklist rows. Founder QA in the evening session caught the right thing:

> "i believe we can have a fat row for some of the modules where it needs to show more like steps - bar chart of tracking progress, calorie module [snap a meal], and move row with some preview of the workout for today."

The intent: the rows the user actually uses to *make decisions* (will I walk more? will I eat this? what's my workout today?) get more home-tab real estate. The rows that are *rituals* (open a lesson, breathe, sunday weigh-in) stay compact. v4 treated all rows as equal weight; the user doesn't. Bento-density per-row, not uniform-row-density.

This is a JeniFit-specific innovation — her75 doesn't have telemetry rows, BetterMe's homescreen ships uniform rows even though their Progress screen is rich with mini-charts. We get to put the Progress-screen density INSIDE the daily checklist, which neither reference does. That's the right move for our cohort (TikTok-acquired beginner women checking their phone 30+ times a day) — they shouldn't have to navigate to a "Progress" screen to see today's steps distribution; today's steps distribution should sit ON the daily ritual surface.

I'm overriding v4's uniform-row decision. The reasoning that supported it (her75's chrome restraint) still holds for ritual rows, but it never anticipated load-bearing rows. v4 was right about chrome restraint; v5 corrects the load-bearing oversight.

## v5.2 The three fat rows — anatomy

### Fat row 1: steps (~140pt)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │ ← 14pt top pad
│  ┌──┐                                                       │
│  │🚶│  steps                                  4,820 / 7,500 │ ← row header line
│  └──┘  your daily walk                                      │
│                                                             │ ← 8pt gap
│      ▁ ▁ ▂ ▂ ▁ ▃ ▅ ▆ ▇ ▆ ▄ ▃ ▂ ▁ ▁ ▁ ▁ ▁ ▁ ▁ ▁ ▁ ▁ ▁     │ ← 24-bar hour chart, 44pt tall
│      6a    9a    12p    3p    6p    9p                      │ ← axis labels 9pt
│                                                             │ ← 14pt bottom pad
└─────────────────────────────────────────────────────────────┘
```

Concrete spec:

- **Header line** (same as compact row): sticky-note + title + subtitle on left, numeric label `4,820 / 7,500` on the right where the bar+label was in v4. NO trailing bar on the header line — the inline chart below carries that information now. **The 64pt × 3pt bar from v4 §4.4 is deleted from the steps row in v5** (it's now a 24-bar full-width hour chart instead).
- **24 bars** representing today's 24 hours, 0–23 local time. Bar width: `(rowWidth - 40pt left inset - 20pt right inset) / 24 - 2pt gap` ≈ 11pt × bar. Bar fills 0% to 100% of available bar height (44pt) scaled to **today's peak hour**, not to a fixed step count. (Scaling to the goal divided by 24 makes most bars look flat for low-activity users; scaling to today's peak makes the distribution visible regardless of total activity. The numeric label `4,820 / 7,500` on the header line carries the absolute number.)
- **Bar color**: `Palette.cocoaPrimary` at 70% opacity for past hours, `Palette.cocoaTertiary` at 30% opacity for future hours (the user can SEE that hours 4pm-11pm haven't happened yet — implicitly cues "the day isn't over, keep walking"). Current hour: solid `Palette.cocoaPrimary` at 100% with a tiny 1pt cream highlight on top edge. No sage/state-good color here — the chart is data, the COMPLETE state when target hit lives in the header label flip to `*reached* · 7,500` per v4 §4.4.
- **Axis labels**: 6 markers `6a / 9a / 12p / 3p / 6p / 9p` in `Typo.caption2` (9pt), `Palette.cocoaTertiary`. Below the bars. No y-axis. The numeric label on the header IS the y-axis equivalent.
- **No goal line** drawn across the chart. The goal lives in the `/ 7,500` header label. A horizontal goal line would compete with the bars for visual weight and tip the chart into gym-tracker register. The bars + the header count + the future-hour transparency is enough to read "where am I vs where I'm trying to be."

Empty state (day 1 morning, no steps yet): all 24 bars rendered at minimum 1pt height in `Palette.hairlineCocoa` so the chart structure is visible (not a blank gap), axis labels visible, header reads `0 / 7,500`. The intentional-not-broken signal is the visible chart skeleton — same shape as a populated chart, just flat. **Avoids the "did this load?" doubt that an empty rectangle would create.**

### Fat row 2: snap a meal (~155pt)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │ ← 14pt top pad
│  ┌──┐                                                       │
│  │📷│  snap a meal                                ✓✨       │ ← row header line (auto-complete state shown)
│  └──┘  2 logged today                                       │
│                                                             │ ← 10pt gap
│      ┌────────┐  1,247 cal  ·  74p  ·  138c  ·  42f         │ ← meal thumb + macro strip
│      │ [meal] │                                             │
│      │ [photo]│                                             │
│      └────────┘                                             │
│                                                             │ ← 14pt bottom pad
└─────────────────────────────────────────────────────────────┘
```

Concrete spec:

- **Header line** (same as compact row): sticky-note + title + subtitle on left, checkbox/auto-complete badge on the right. Unchanged from v4 binary trailing.
- **Meal thumb**: 48pt × 48pt rounded-6pt square, leading-aligned (20pt from card edge, same column as the sticky), shows the MOST RECENT meal photo from `FoodLogPersister.todayLogs.last`. If no photo (text-only entry), shows the `camera` SF symbol at 22pt centered on `Palette.bgPrimary` fill. Soft 1pt cocoa-hairline border.
- **Macro strip** (right of thumb, 12pt gap): single line of text, `Typo.caption` (DM Sans Medium 13pt). Format: `1,247 cal · 74p · 138c · 42f` — total kcal first in DM Sans **SemiBold** for emphasis, then `cal` lowercase, then dot-separator macros with single-letter unit suffixes (`p` `c` `f`) in `Palette.cocoaSecondary`. Single letter is intentional: keeps the strip on one line at 353pt row width without truncating, and the cohort is GLP-1-era literate on protein-carbs-fat without needing full words.
- **No mini macro bars.** A protein/carb/fat triple-bar would be redundant with the strip text AND would import gym-tracker register. The numbers ARE the visualization at this density.
- **No "remaining" calculation.** This row shows what was eaten, not what's left in a daily target. The cohort is post-Ozempic, anti-calorie-tracker — per [[feedback-food-ux-antishame]] we don't render a daily kcal target. The header `2 logged today` is the only count signal.

Empty state (no meals yet today): meal thumb slot renders the 48pt `camera` SF symbol at 22pt centered on `Palette.bgPrimary` with 1pt cocoa-hairline border (looks like a placeholder picture frame, not a broken image). Macro strip text reads: `*tap to snap your first*` — italic Fraunces on "tap to snap your first", DM Sans-less, full italic phrase (single italic block is acceptable here because it's a CTA-as-copy, mirroring the v3.6 punch-word voice signal sized up to a full line). This is the only place in v5 where italic Fraunces runs a full phrase instead of a punch word; the rule bends because the empty state needs to read as "do this" not "data goes here."

### Fat row 3: move (~170pt)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │ ← 14pt top pad
│  ┌──┐                                                       │
│  │🏃│  move                                        ◯        │ ← row header line
│  └──┘  18 min · gentle today                                │
│                                                             │ ← 10pt gap
│      ┌──┐ ┌──┐ ┌──┐         ·  + 4 more                     │ ← exercise preview row
│      │1 │ │2 │ │3 │                                         │
│      │  │ │  │ │  │                                         │
│      └──┘ └──┘ └──┘                                         │
│      bridge   plank   bird-dog                              │ ← exercise names 10pt
│                                                             │ ← 14pt bottom pad
└─────────────────────────────────────────────────────────────┘
```

Concrete spec:

- **Header line** (same as compact row): sticky-note + title + subtitle on left, checkbox on right. Subtitle gets a small spec tweak: `18 min · gentle today` (dot-separator vs v4's comma) to match the rhythm of the macro strip in the snap row. Minutes + tier on one line.
- **Exercise preview row**: 3 exercise tiles, each 56pt × 56pt rounded-6pt. Tile fill: `Palette.bgPrimary` (cream). Tile content: the exercise's display number (`1` `2` `3`) in Fraunces SBItalic 22pt, `Palette.cocoaPrimary`, top-left-aligned with 8pt inset. No exercise illustration — we don't have per-exercise photography and the cohort doesn't need to recognize the silhouette to commit to the session (the title carries that).
- **Exercise names**: under each tile, the exercise name in `Typo.caption2` (DM Sans Regular 10pt), `Palette.cocoaSecondary`, single-line, truncated with `…` at tile width if needed. Names pulled from the prescribed session's first 3 exercises via `WorkoutGenerator.previewExercises(prescription:limit:3)`.
- **"+ N more" indicator**: to the right of the 3 tiles with 16pt gap, vertically center-aligned with the tile row (not the name row), reads `· + 4 more` in `Typo.caption` (DM Sans Medium 13pt), `Palette.cocoaTertiary`. Total exercise count minus 3. If the session has ≤3 exercises (rare — short sessions), the indicator is hidden.
- **No total time / no tier badge on the preview row.** Both already live on the header line subtitle. Repeating them in the preview would be chrome cosplay.

Empty state (workout not yet generated, e.g. cold-start morning before `WorkoutGenerator` has run): exercise tiles render at 30% opacity with the numerals only, name labels read `—` (em-dash glyph, the only em-dash allowed in the spec because it's a placeholder for missing data, not between-words punctuation). Header subtitle reads `loading today's session…` instead of `18 min · gentle today`. Auto-resolves within ~200ms of cold-start since `WorkoutGenerator` is in-memory.

## v5.3 Heights and iPhone 15 fit math

Per-row heights:

| Row | Compact (v4) | Fat (v5) | Delta |
|---|---|---|---|
| today's lesson | 76pt | 76pt (compact) | 0 |
| snap a meal | 76pt | **155pt (fat)** | +79 |
| move | 76pt | **170pt (fat)** | +94 |
| steps | 76pt | **140pt (fat)** | +64 |
| breath / weigh-in / plank / water (one slot) | 76pt | 76pt (compact) | 0 |

Card chrome: 14pt top pad + 14pt bottom pad + 4 dividers × 0.5pt = ~30pt.

**Total card height with 5 rows** (1 lesson + 1 snap-fat + 1 move-fat + 1 steps-fat + 1 ritual): `76 + 155 + 170 + 140 + 76 + 30 = 647pt`.

**Total screen height above tab bar** at iPhone 15:

| From | To | Pt |
|---|---|---|
| safeArea top | eyebrow | 24 |
| eyebrow | strip | 18 |
| strip + center marker | checklist card | 22 + 56 (strip) + 18 (marker block + spacing) = 96 |
| checklist card | micro-caption | 24 |
| micro-caption block height | — | ~24 |
| micro-caption | tab bar buffer | 60 |
| **Subtotal: chrome around card** | | **246pt** |

Card 647pt + chrome 246pt = **893pt total**. iPhone 15 usable above tab bar = 852pt (393×852 frame minus 59pt safe-area top minus 83pt tab bar = ~710pt visible).

**Conclusion: the card scrolls.** ~183pt of the card falls below the fold for the modal day-1 cohort. That's the last 1.5 rows. Specifically: with the rows ordered `lesson → snap (fat) → move (fat) → steps (fat) → ritual`, what sits below the fold is the bottom ~25% of the steps fat row (≈30pt of the 24-bar chart) + the entire ritual row at the bottom + the micro-caption.

### Is "card scrolls" acceptable?

Yes, with specific row ordering. Re-ordering rules:

1. **lesson stays at top** — fastest single-tap commit, primes the user's first action of the day.
2. **snap-meal is row 2** — the "decide before eating" surface needs to be above the fold *every morning* because pre-breakfast is the high-leverage tap window. Snap fat row top-aligned ~76pt below the lesson row puts its top at 76pt; its 155pt height extends to 231pt within the card. Comfortably above the fold (card top is at ~246pt into the screen, card visible portion is ~710 − 246 = 464pt, so the first ~464pt of card content is above fold).
3. **move is row 3** — workout preview deserves the second above-fold fat slot. Position: 76 + 155 = 231pt into card → bottom at 401pt. Still above fold.
4. **steps is row 4** — steps is a passive-tracking row; the user doesn't *act* on it at app-open time, they GLANCE at it during the day. Below-fold is acceptable because the data accumulates throughout the day and the user reopens. Position: 401pt into card → bottom at 541pt. Card visible region is 464pt, so the BOTTOM ~77pt of steps falls below fold. That's roughly the bottom 50% of the chart bars + axis labels.
5. **ritual row (breath / weigh-in / plank) is row 5** — last. The ritual rows are the LEAST decision-critical; they're "did I do this" markers, not "what should I do" surfaces. Falling fully below the fold + requiring a small scroll is fine. **They were less load-bearing in the founder's brief and they get the below-fold tax.**

### Scroll behavior

- Card is inside the existing `ScrollView`. No separate scroll. The user scrolls the whole PlanView and the card moves with the eyebrow + strip.
- **No sticky strip header.** Tempting (the strip stays visible while user scrolls) but breaks the her75 paper-on-paper register — sticky chrome is iOS-app-coded, not editorial-coded. The user already sees the strip on every fresh open; scrolling within a session to reveal one more row doesn't need it pinned.
- **Bottom-fold tease**: aim to have the ritual row's TOP visible above the fold (just the sticky + title peek). This is the magazine "see something below the fold to invite the scroll" pattern. With current math, the ritual row top sits at 541pt into the card → 541 + 246 = 787pt into the screen. iPhone 15 visible to fold = ~710pt. So the ritual row peek is ~78pt BELOW the fold (not visible). **Fix: drop the steps fat-row height from 140pt to 124pt** by tightening the bar chart top/bottom pads — moves steps bottom from 541 to 525, then ritual top to 525 + ritual-row offset, peek lands at fold +/- 10pt. Acceptable. Adjusted heights baked into §v5.7.
- **Plank rows day**: on plank-included days (config-driven, not every day), the card grows by 76pt. Plank row goes at the BOTTOM (row 6, after ritual). Ritual row gets pushed further below fold. Acceptable — plank is an active program day and the user expects the card to grow.

## v5.4 Visual cohesion strategy — picked (a) embedded mini-component below the subtitle line

Walked the four options:

- **(a) same row chrome + embedded mini-component below the subtitle line as expanded subtitle area** — what I'm picking. The fat row is structurally a compact row + a content block underneath, inside the same row's vertical bounds. No new chrome, no internal hairline, no nested card. The mini-component lives in the same indentation column as the title/subtitle (40pt left indent past the sticky-note).
- **(b) separate visual region with internal hairline** — explicitly rejected. An internal hairline above the embedded chart breaks the row into "two things in one row," doubling the hairline frequency in the card (the row dividers are already 0.5pt hairlines; adding internal hairlines means the user sees them at twice the density). Tips the card from "five rows" into "five rows of sub-cards" — gym-app density.
- **(c) restructure with mini-component to the RIGHT of the title (vs below) for steps so the row stays one-line tall** — rejected. 24-hour bar chart can't fit horizontally in the trailing region (would compress to ~140pt width = ~5pt per bar = unreadable). Macro strip already DOES sit horizontally next to the title in row 2 (snap-meal header line carries `1,247 cal · 74p · 138c · 42f` to the right of the title in compact form during day) — but for the FAT version with the meal thumb the thumb has to be its own block.
- **(d) something else** — considered: per-fat-row card-within-card with a 1pt border. Too much chrome. Considered: full-width edge-to-edge mini-component (chart extends to card horizontal edges, breaking the 40pt indent). Wrong — breaks the her75 leading-indent grid that ties the card together.

(a) is the her75-compatible move. The fat row reads as "a row with more to say," not "a row that became a different thing." Cohesion is preserved by:

1. **Indent column**: ALL embedded content (chart bars, meal thumb, exercise tiles) starts at the same 40pt left indent as the title text. The sticky-note column to the left stays empty in the embedded region. Reads as a single visual column structure.
2. **No internal chrome**: no internal hairline, no internal background, no card-within-card. The embedded content sits on the white card surface directly.
3. **Top/bottom padding inside the row stays at the compact-row's 14pt** — fat rows just have more *between* the header and the bottom padding. Card-level vertical rhythm is preserved.
4. **Dividers between rows stay at the same indented-hairline pattern (leading 80pt, 0.5pt cocoa-hairline)** — same as v4. The eye reads "5 rows separated by hairlines" identically whether some rows are tall or short. The fat rows just have more breath inside the hairline-to-hairline gap.

## v5.5 Tap behavior on fat rows

### Steps fat row

- **Row body tap** (sticky + title + subtitle + chart area + numeric label): opens StepsBottomSheet (the v4 §4.6 small sheet — already speced). Light haptic.
- **Tap on a specific hour bar**: same as row body tap. Don't fragment the affordance into per-bar interaction. A per-bar tap-to-see-that-hour pattern is over-engineered for a 24-bar chart at this density — the bars are 11pt wide, smaller than HIG, and the user can SEE the distribution at a glance. If they want hourly detail, the sheet handles it.
- **No long-press**: progress row, manual override not applicable (HealthKit is canonical).

### Snap-meal fat row

- **Row body tap** (sticky + title + subtitle + meal thumb + macro strip + checkbox area): opens the food camera (`FoodCameraView`). Same as v4 binary-row tap.
- **Tap on the meal thumb specifically**: opens `FoodLogView` scrolled to that meal's detail (not the camera). The thumb visually reads as a media element — tapping it should view the media, not start a new capture. This IS a fragmented affordance, and it's the right one because the thumb is a recognizable media element whereas the bars in the steps row are not.
- **Tap on the macro strip text**: same as row body — opens camera. The strip is text, text is row-body.
- **Long-press on row** (binary fat row): MarkAsDoneSheet, same as v4. The user can mark snap-meal done without snapping if they ate without their phone. Unchanged.

### Move fat row

- **Row body tap** (sticky + title + subtitle + exercise tile row + checkbox area): opens `BrowseWorkoutsView` or the prescribed session preview (`PreSessionView`) per existing routing. Same as v4 binary-row tap on the move row.
- **Tap on an exercise tile specifically**: opens the prescribed session preview scrolled to that exercise. Similar logic to the meal thumb — the tile reads as a discrete content element, tapping it should preview that element specifically.
- **Tap on "+ 4 more" indicator**: same as row body — opens session preview at top. The indicator IS the row-body for that horizontal region.
- **Long-press on row** (binary fat row): MarkAsDoneSheet, same as v4.

### Universal rule

Embedded mini-components inside fat rows are **read-only by default + selectively tappable on recognizable media elements** (meal thumb, exercise tile). Chart bars are NOT individually tappable. The principle: if the embedded element looks like a button/tile/thumb, tapping it does a specific thing; if it looks like data visualization (bars, dots, lines), tapping it falls through to the row body. This matches user instinct — cohort doesn't try to tap chart bars, they DO try to tap photos and tiles.

## v5.6 Subtitle treatment with fat rows

v4 subtitle was one line of context copy directly below the title. Decision for v5: **subtitle stays in the header line, unchanged. The embedded data lives BELOW the subtitle, not in place of it.**

Reasoning: the subtitle copy carries the row's *meaning* (what this row is about today). The data carries the row's *state* (where the user is on it). They're different jobs. Replacing the subtitle with data ("4,820 / 7,500" replacing "your daily walk") would make the row feel like a number, not a ritual. Keeping both lets the row read as "this is what walking means today" + "here's how today's walk is going."

Specific subtitle copy per fat row:

| Row | Subtitle (v5, unchanged from v4 with minor tweaks) |
|---|---|
| steps | `your daily walk` — context, not data. |
| snap a meal | `2 logged today` when logs exist; `one photo · we read the plate` when empty (v4 copy). |
| move | `18 min · gentle today` — minutes + tier. Dot-separator change from v4's comma to match snap-row rhythm. |

The numeric label `4,820 / 7,500` (steps), macro strip (snap), exercise tiles (move) all live in the embedded region BELOW the header line. The numeric label exception: steps' `4,820 / 7,500` is so tightly coupled to the row identity that it lives on the header LINE (right edge, where the v4 trailing label was) AND the chart lives below — the label is the count, the chart is the distribution. Two different pieces of information.

## v5.7 Empty / pre-data states

Founder's instinct holds: empty states should look intentional, not broken. Per fat row:

### Steps empty (Day 1 morning, 0 steps)

- Chart: all 24 bars rendered at 1pt minimum height in `Palette.hairlineCocoa` (12% cocoa). Chart skeleton visible, axis labels visible.
- Header numeric label: `0 / 7,500` in standard `Typo.caption` cocoaSecondary.
- Subtitle: `your daily walk` (unchanged).
- **Why this works**: structure is visible, count is honest, no "loading…" spinner, no "no data" emoji. The flat-bars state IS the morning state.

### Snap-meal empty (no meals logged today)

- Meal thumb: 48pt × 48pt rounded-6pt cream-fill with `camera` SF symbol at 22pt centered, 1pt cocoa-hairline border. Reads as picture-frame-placeholder.
- Macro strip: `*tap to snap your first*` in Fraunces SBItalic 13pt, full-italic line, `Palette.cocoaPrimary` (not cocoaSecondary — slightly more presence because it's a CTA-as-copy).
- Subtitle: `one photo · we read the plate` (v4 copy).
- Header trailing checkbox: empty 26pt cocoa-tertiary stroke circle (v4 binary-empty default).
- **Why this works**: the empty state mirrors the populated state's shape (thumb-on-left + text-on-right) so the row doesn't reflow when the user logs their first meal. The italic CTA-as-copy makes "tap to snap" feel inviting, not commanding.

### Move empty (workout not yet generated)

- Exercise tiles: 3 tiles rendered at 30% opacity, numerals visible (`1` `2` `3`) faint.
- Exercise names: em-dash glyph `—` per tile in cocoaTertiary.
- Header numeric label: subtitle reads `loading today's session…` in cocoaSecondary.
- Header trailing checkbox: empty.
- **Why this works**: the structural placeholder reads as "session is being prepared," not "no workout exists." Resolves within ~200ms of `WorkoutGenerator` in-memory hit. If for some reason generation fails (it shouldn't — fallback exists), the row collapses to compact form with subtitle `rest day, no move scheduled` (v4 fallback).

### Move on a rest day (engine says no workout)

- Falls back to v4 compact row — fat row only renders when there IS a workout to preview. The rest-day row reads at 50% opacity with em-dash trailing, same as v4 `.restDay`. No embedded content because there's nothing to embed.

## v5.8 What stays compact for now / Phase 2 candidates

Founder asked me to recommend keep-compact vs fat-in-phase-2 for each remaining row.

| Row | Recommendation | Reasoning |
|---|---|---|
| **today's lesson** | **Keep compact in v5. Phase 2 candidate: fat for lesson with embedded 3-bullet preview.** | Lesson title + 2-min subtitle is enough commitment device for tap-to-read. Adding 3 bullet preview would steal the lesson's own hook — the lesson screen IS where the bullets live. The compact row's job is "make me tap"; the bullets' job is "keep me reading once I'm tapped." Different jobs, different surfaces. Phase 2 fat could ship a single 1-line preview pulled from lesson copy (the "WHY this matters today" line) but not the full 3-bullet outline. |
| **breath** | **Keep compact permanently.** | Breath is a 1-2 min ritual with no progression to show. The user doesn't make a decision about whether to breathe today based on past data; they decide based on how they feel. A "last 7 days breathwork" embed would import streak-anxiety register (per [[feedback-voice-signals]] anti-streak rule). The ritual stays compact. |
| **weigh-in (Sunday)** | **Keep compact in v5. Phase 2 candidate: fat for weigh-in with 4-week trend mini-chart.** | Sunday is once-a-week and the moment of weigh-in is high-emotion. Adding the trend chart to the row WOULD be load-bearing (the trend is the anti-shame frame — see [[feedback-anti-shame-food-ux]] trend>number). BUT: weigh-in row appears once a week on Sundays. Adding a fat treatment for one day out of seven means 6 days of "where did the chart go?" inconsistency. **Better path**: keep weigh-in row compact, route the trend chart to the Becoming tab where it already lives (Weight Trend EMA module). The row's job is "log the weight today"; the chart's job is "see the trajectory." Different surfaces. |
| **plank (when active)** | **Keep compact permanently.** | Plank check-in is a single-data-point input row, max 1 minute. Same shape as weigh-in but daily. Compact. |
| **water (Phase 3)** | **Fat at ship time.** | When water lands, it's a progress row with a clear visualization (cups grid, 8 droplets, fill state). Same fat-row treatment as steps: header line with `6 / 8 cups` numeric label + embedded 8-cup grid below. Don't ship water as compact then refactor to fat — ship fat from day 1. |
| **measurements (Phase 2)** | **Fat at ship time.** | Monthly cadence. When measurements lands, embed the last-3-measurements delta (chest +0.2 / waist −0.3 / hips +0.1) as a 3-row mini-text under the header. Same fat pattern, smaller embedded region (~24pt of embed). |

Phase 2 summary: at v5 ship, 3 fat + 4 compact possible per-day. At Phase 2 ship, water + measurements are fat too → up to 5 fat + 3 compact possible per day. The card grows, fold pushes further, more rows below fold. Acceptable — by Phase 2 the user is months into the program and the daily checklist scrolling is muscle memory.

## v5.9 iPhone 15 fit math — final, with v5.3 height adjustment

Per v5.3 conclusion, drop steps fat-row height from 140pt to 124pt (tighter chart pads). Updated:

| Row | Height |
|---|---|
| today's lesson (compact) | 76pt |
| snap a meal (fat) | 155pt |
| move (fat) | 170pt |
| steps (fat) | 124pt (was 140pt) |
| ritual (breath/weigh-in/plank) (compact) | 76pt |
| Card chrome (top + bottom pad + 4 dividers) | 30pt |
| **Card total** | **631pt** |

Screen vertical budget (iPhone 15, 393×852 frame):

| From | To | Pt |
|---|---|---|
| safeArea top | eyebrow | 24 |
| eyebrow | strip | 18 |
| strip | strip center marker | 4 |
| strip block height (cells) | — | 56 |
| strip center marker height | — | 18 |
| strip block | checklist card | 22 |
| **Subtotal: chrome above card** | | **142pt** |
| Checklist card | — | 631 |
| Card | micro-caption | 24 |
| Micro-caption height | — | 24 |
| Micro-caption | tab bar buffer | 60 |
| **Total above tab bar** | | **881pt** |

iPhone 15 visible above tab bar = ~710pt. So `881 − 710 = 171pt` falls below the fold.

Below the fold for the modal day-1 cohort:
- Bottom ~38pt of the steps fat row (≈ bottom 30% of chart bars + axis labels)
- Entire ritual row (76pt)
- Card bottom padding (14pt)
- Micro-caption (24pt)
- Tab bar buffer (60pt)

Above the fold:
- Eyebrow (24pt) ✓
- Strip (56pt) + center marker (18pt) ✓
- Card top padding + lesson row (76pt) ✓
- Snap-meal fat row (155pt) ✓
- Move fat row (170pt) ✓
- Top ~70% of steps fat row (header line + ~60% of chart bars) ✓

**The above-fold story**: user opens app → sees today's identity (eyebrow + strip) → sees lesson + snap + move + most of steps. Three of the three "load-bearing" rows are fully above fold. Steps shows enough to read distribution at a glance even with the bottom 30% clipped (the axis labels falling below the fold means the user can see the bar shapes but loses the time labels — acceptable, the bars themselves convey the morning/afternoon/evening distribution by their relative position).

**The below-fold story**: scroll down ~170pt to see the rest of steps + the ritual row + the caption. Easy thumb scroll. The "peek" at the top of the ritual row above the fold is **not achieved** (it's 38pt below fold). Trade: keeping move + snap fat above fold is more important than ritual peek. Founder can override in code by tightening the snap or move height by 38pt total if she wants the peek, but my recommendation is **don't** — the fat rows need their breath.

## v5.10 What this changes in code (≤200 words)

**`PlanRow.swift` body:**
- Add `isFatRow: Bool` computed off prescription type. Lesson/breath/weigh-in/plank → false. Snap/move/steps → true (subject to fat-row content being available — steps with 0 HK data still fat, snap with 0 logs still fat per empty state spec, move during workout-generation-loading still fat).
- Body switches: compact branch (existing v4) when `!isFatRow`, fat branch when `isFatRow`. Fat branch is a `VStack(spacing: 10) { headerLine; embeddedContent }`.
- Each fat row gets its own embedded view: `StepsHourChartEmbed`, `SnapMealEmbed`, `MoveExerciseEmbed`. Each pulled into its own file under `PlankApp/Views/Plan/Embeds/`.
- Padding stays at `.padding(.vertical, 14).padding(.horizontal, 20)`.

**`StepsHourChartEmbed.swift` (new):**
- Reads `StepsService.shared.hourlyBreakdown()` (new method — needs adding) returning `[Int]` of 24 step-count-per-hour values.
- Renders 24 `Capsule`s in HStack with 2pt spacing, height-scaled to max value, color per past/current/future hour rule.
- Axis labels in HStack below with `Spacer`s spacing them at 6 / 9 / 12 / 3 / 6 / 9 positions.

**`SnapMealEmbed.swift` (new):**
- Reads `FoodLogPersister.todayLogs.last` for thumb + `.todayMacros()` for the strip.
- Falls back to empty-state placeholder when `todayLogs.isEmpty`.

**`MoveExerciseEmbed.swift` (new):**
- Reads `WorkoutGenerator.previewExercises(profile:bodyFocus:limit:3)` (new method — needs adding) returning `[(displayNumber: Int, name: String)]`.
- Renders 3 tiles + names + "+ N more" indicator. Empty-state placeholder when generator hasn't resolved.

**`PlanView.swift`:**
- No layout changes — card still iterates `todayPrescriptions` and the row decides its own height. Card auto-grows.

## v5.11 Open questions

1. **Steps chart bar color — cocoa for past hours or sage for past hours?** Spec says cocoa (data-color, neutral). Alternative: sage `Palette.stateGood` for past hours to signal "this happened, it's good." My vote: cocoa. The chart is information, not encouragement. Sage would push us into gym-tracker register (filled green = good). Cocoa stays editorial.

2. **Snap-meal thumb on text-only entries — show the camera-icon placeholder thumb, or show a different glyph (`text.alignleft`?) so the user knows the log was text-not-photo?** Spec says camera placeholder regardless. My vote: camera placeholder. Differentiating text-vs-photo at this density is fine-grained and probably illegible at 48pt; the user's mental model is "I logged that meal" not "I logged that meal with a photo vs without." Phase 2 if we add a text-icon variant, do it then.

3. **Move exercise tiles — should the tile FILL be type-keyed (mint for warmups, rose for cardio, etc.) to match the sticky-note color system?** Tempting because it would visually link the embedded tiles to the sticky-note craft signal. My vote: no — keep all tiles cream `Palette.bgPrimary`. The sticky-note carries the type identity ONCE per row. Repeating it on the 3 exercise tiles would import too much pastel into the card and break the white-card visual restraint. Tile chrome stays neutral.
