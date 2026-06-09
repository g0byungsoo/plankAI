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

