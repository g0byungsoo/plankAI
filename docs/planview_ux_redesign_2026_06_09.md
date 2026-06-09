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

