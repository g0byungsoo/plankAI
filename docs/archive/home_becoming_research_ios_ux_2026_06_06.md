# Home + Becoming — iOS-native UX research

_Author: senior iOS UX designer (advisory)_
_Date: 2026-06-06_
_Audience: JeniFit founder + iOS engineering_

---

## Executive recommendation

The current JeniFit Home + Becoming is brand-strong but iOS-incoherent in three load-bearing ways: the **camera FAB overlaid on the tab bar is a direct HIG anti-pattern** that will only get more conspicuous when iOS 26 Liquid Glass ships the floating, minimize-on-scroll tab bar this fall; **Becoming's 5 "chapters" should be presented as scroll-content with iOS-native section grammar (large title + grouped cards), not as a paginated bento that fights NavigationStack**; and **iOS 18+'s real native superpowers for a weight-loss app — Lock Screen widgets, interactive Home Screen widgets, and Dynamic Island for the scan flow — are currently unused**, which is the biggest miss because they're where Cal AI's gen-Z users already have muscle memory. The fix is not to flatten the coquette scrapbook into Apple-stock chrome. It's to **keep the scrapbook chrome inside the cards and inside the screens**, and make the iOS-native shell around them (tab bar, navigation bar, status surfaces like Dynamic Island / Lock Screen) read as system-native. The cocoa pill, italic-Fraunces punch words, and ♥ punctuation are surface-level brand signals — they survive iOS-native architecture untouched. The 1.5pt cocoa border + offset shadow is the one piece of chrome to **scope to content cards only**, never to navigation chrome (tab bar, nav bar, sheets). That single rule resolves 80% of the "bolted on" feeling. The other 20% is collapsing the camera FAB into a tab-or-toolbar pattern (Recommendation §2) and adopting iOS 18 interactive widgets + Dynamic Island for the food rail so food stops feeling like a fourth thing pasted into a three-tab app.

---

## 1. iOS-native cohesion diagnostic

### What helps JeniFit feel iOS-native today

- **Cocoa pill CTAs.** Apple's own primary buttons in iOS 18+ are pill-shaped (Messages send, Wallet pay, Health "Get Started"). Saturating with cocoa instead of system tint reads as brand-coded, not anti-system. Keep.
- **Lowercase casual copy.** Apple Notes, Journal, and Maps use sentence-case freely; iOS does not enforce title case in body copy. Lowercase reads as native voice + brand voice simultaneously.
- **Scrolling card surface.** Vertical scroll-of-cards is the dominant iOS 18 health pattern (Apple Health Summary, Apple Fitness Summary) — Mobbin's Apple Health Summary screenshot is the canonical reference. ([Mobbin — Apple Health iOS Health Summary](https://mobbin.com/explore/screens/5e311abb-f8f6-4e0b-9d44-a03671426672))
- **NavigationStack + push detail.** JeniFit's tap-card-to-drill pattern is correct iOS grammar.
- **Italic Fraunces on punch words.** Apple App Store editorial uses inline-italic emphasis in feature copy; brand differentiation via italic is HIG-compatible.

### What fights iOS-native conventions

- **Camera FAB overlaid on the tab bar.** Apple HIG explicitly cautions against the Material-style floating action button: tab bars are reserved for navigation, and there is "no exact iOS equivalent for a solitary, highlighted action." ([UX Planet — FAB alternatives on iOS](https://uxplanet.org/3-alternatives-to-the-floating-action-button-54f6b7c96714)) iOS 26's floating-tab-bar that minimizes on scroll will make any overlaid FAB visually collide with system chrome. This is the single largest source of "bolted on" feeling. ([Donny Wals — iOS 26 tab bars](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/))
- **1.5pt cocoa border + hard offset shadow on full-screen chrome.** Inside a content card this reads as scrapbook. Applied to a sheet, tab bar, or navigation bar it reads as anti-HIG. The audit needs to confirm the border is not bleeding onto navigation surfaces (sheets, modals, tab bar background).
- **24pt corner radii everywhere.** iOS 18 system materials use 10pt (small), 16pt (medium), 22pt (continuous large). 24pt is fine for content cards (it reads as "warmer than Apple"), but applied to grouped-list rows or sheets it reads as Android Material. Scope 24pt to **content cards and hero modules only**.
- **Becoming's "chapters" framing.** Chapters imply sequential reveal (Stories, Wrapped). Becoming is actually a dashboard. Naming + chrome currently fight each other.
- **No Dynamic Island, no Live Activities, no widgets.** For a Gen-Z TikTok-acquired cohort already on iOS 18+, missing all three reads as "not a real iOS app." Cal AI ships interactive Dynamic Island; MacroFactor ships interactive widgets. ([MacroFactor widgets announcement](https://macrofactor.com/widgets-announcement/), [Nutrient Metrics — Quick Log widget audit 2026](https://www.nutrientmetrics.com/en/guides/widget-lock-screen-quick-log-feature-audit))
- **Hearts ♥ in body chrome.** As terminal punctuation in copy, fine. If they appear as repeated UI decoration (button glyphs, tab icons), HIG-incompatible. Keep the rule strict.

### Cohesion principle (the one rule)

> **Scrapbook chrome lives inside content. iOS-native chrome lives outside it.**
>
> - Inside a card: 24pt corners, 1.5pt cocoa border, hard offset shadow, italic-Fraunces, hearts, lowercase.
> - Outside a card (tab bar, nav bar, sheet background, status surfaces): system materials, system corner radii, system tint = cocoa, no FAB, no custom borders on navigation chrome.

Apply that rule and the "bolted on" feeling collapses.

---

## 2. Tab bar architecture

### Current: 3 tabs + camera FAB

Home / Becoming / camera FAB overlaid on the tab bar.

**Diagnosis:** The FAB is the problem, not the tab count. Apple HIG is explicit: tab bars on iPhone support 3–5 destinations; FABs are not an iOS pattern. ([Apple HIG — Tab bars (tab-count + nav-only guidance summarized)](https://developer.apple.com/design/human-interface-guidelines/tab-bars), [uiuxdesigning.com — iOS Tab Bar 2026](https://uiuxdesigning.com/ios-tab-bar/))

### Recommendation: **3 tabs, no FAB. Camera becomes a tab.**

```
┌──────────────────────────────────────────┐
│  Home         Becoming        +log       │  <- 3 tabs, system chrome
└──────────────────────────────────────────┘
```

- **Home** (system house glyph or custom Fraunces "j")
- **Becoming** (system sparkle.magnifyingglass or custom)
- **+log** (system plus.circle.fill OR camera glyph)

The third tab is the camera + log entry, but it's a **tab**, not a floating button. On tap, instead of pushing a tab content view, it presents a **bottom sheet with `presentationDetents([.medium, .large])`** that holds the camera + quick-log + manual entry options. The tab stays in the bar; the sheet does the work. ([Sarunw — presentationDetents bottom sheet](https://sarunw.com/posts/swiftui-bottom-sheet/))

This pattern is used by Apple Wallet (Add) and Apple Notes (compose) — tab-or-toolbar item triggers a sheet, never a FAB.

**Why not 4 tabs (Home / Becoming / Food / +log)?**
Food does not need a top-level destination. Today's Plate already lives on Home (slot 2). Drilling into a dedicated Food tab would duplicate Home's hero. Cal AI does this and gets "cluttered home + redundant food tab" complaints in its 2026 reviews. ([MyFitnessPal 2026 redesign critique](https://platelens.app/blog/myfitnesspal-alternatives-2026) — same architectural mistake noted)

**Why not 2 tabs?**
Becoming is the retention surface; demoting it below a tab is wrong for a TikTok-acquired cohort whose dopamine loop is "what's changing." Keep it surfaced.

**iOS 26 readiness:** With `tabBarMinimizeBehavior(.onScrollDown)` and the new floating Liquid Glass tab bar, this 3-tab + sheet-on-third-tab pattern collapses cleanly. The current FAB will visibly fight the floating tab bar. ([Donny Wals — iOS 26 tab bars](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/), [createwithswift — minimize on scroll](https://www.createwithswift.com/making-the-tab-bar-collapse-while-scrolling/))

**Tab glyphs:**
Use **SF Symbols with custom rendering** (`.palette` with cocoa + cream) rather than custom drawn icons. SF Symbols ship with Dynamic Type scaling, accessibility labels, and Liquid Glass response baked in. Brand differentiation comes from the tint + the selected-state label (italic Fraunces caption), not from drawing custom glyphs.

---

## 3. Dynamic Island integration

### Strong yes: food scan in progress

The food scan is the textbook Dynamic Island use case — a discrete, short-duration event with a clear start and end, exactly what ActivityKit was designed for. ([Apple Developer — Explore Live Activities and the Dynamic Island](https://developer.apple.com/news/?id=bkm73839))

```
Compact leading: small camera glyph (cream on cocoa)
Compact trailing: "analyzing..." with subtle dot animation
Expanded: photo thumbnail + "*finding* what's on the plate ♥"
Minimal: cocoa dot
```

Duration is 3–8 seconds typically — well under any Dynamic Island norm. On completion, tap-to-expand reveals the result card; auto-dismiss after 30s.

### Strong no: persistent daily calorie ring

Live Activities cap at 8 hours active + 4 hours grace = 12 hours maximum visibility. ([Airship — Live Activities](https://www.airship.com/explainer/ios-live-activities-explained/)) A daily calorie ring would need 16+ hours and would compete with every other Live Activity on the user's device. This is what widgets are for, not Live Activities.

### Conditional yes: trial countdown — but ONLY in the last 24h

A 3-day trial Live Activity for the full 72 hours would violate the 12-hour cap and feel like ransom. A **last-24h-only countdown Live Activity** is legitimate (it has a real end event) and converts on the Cal AI / Rise pattern. Gate behind a paywall A/B test before shipping.

### No: weight log streak

Streaks belong in widgets and notifications, not Dynamic Island. A persistent streak counter in the Island is anti-shame-violating: a low streak in the user's face every time they pick up their phone is the exact "labor verb" feel the brand voice locks out.

### Recommendation priority
1. **Ship food scan Dynamic Island in v1.0.7** alongside the food rail. It's the highest-impact + cheapest implementation.
2. **Defer trial countdown to v1.1** after A/B test.
3. **Never ship calorie ring / streak Live Activity.**

---

## 4. Live Activities — converts vs gimmicky

| Live Activity | Verdict | Why |
|---|---|---|
| Food scan in progress (3–8s) | **Ship** | Textbook event with start/end; high "wow" moment for TikTok demo clips |
| Restaurant Mode session (active 30–90 min) | **Ship in v1.1** | Real time-bounded event; gives the pre-eat decision a system surface |
| Daily calorie ring | **Skip** | Violates 12h cap; widget territory |
| Weight log streak | **Skip** | Anti-shame violation |
| Workout in progress | **Ship eventually** | Time-bounded; HealthKit-aligned. Defer until workout is back as hero |
| Trial last-24h countdown | **A/B then ship** | Conversion lever, but ransom feel if mis-tuned |

The "TikTok demo" angle matters specifically for this audience. The food-scan Dynamic Island is the single most screenshottable moment in the app — Gen-Z users are already trained by Cal AI marketing to show the Island in screen-recordings.

---

## 5. Widget strategy

For a TikTok-acquired Gen-Z cohort, widgets are the **#1 underused engagement lever**. Cal AI ships them; MacroFactor ships them; MyFitnessPal ships them. JeniFit shipping zero widgets is a real gap. ([MacroFactor widgets](https://macrofactor.com/widgets-announcement/), [Nutrient Metrics — Quick Log widget audit 2026](https://www.nutrientmetrics.com/en/guides/widget-lock-screen-quick-log-feature-audit))

### Lock Screen widgets (iOS 16+)

Three accessory families: `accessoryInline`, `accessoryCircular`, `accessoryRectangular`. ([LogRocket — Lock Screen widgets](https://blog.logrocket.com/building-ios-lock-screen-widgets/))

| Family | Content | Verdict |
|---|---|---|
| `accessoryCircular` | Weight trend mini-arc OR daily food ring | **Ship — pick one (food ring)** |
| `accessoryRectangular` | "your *becoming*" trend line + last weight (anti-shame: shows trend, not number alone) | **Ship** |
| `accessoryInline` | Today's affirmation OR "you've logged *2* meals today" | **Ship — affirmation rotation** |

### Home Screen widgets (small / medium / large)

| Widget | Content | iOS 17 interactive? | Verdict |
|---|---|---|---|
| Small: Today's Plate | Calorie ring + 2 meal pills | No (just glanceable) | **Ship** |
| Small: Trend | Sparkline + EMA delta | No | **Ship** |
| Medium: Quick log | Buttons: photo + barcode + "same as yesterday" | **Yes — AppIntent** | **Ship — this is the engagement lever** |
| Medium: Coach quote | Daily italic-Fraunces affirmation, rotates | No | Ship in v1.1 |
| Large: Becoming snapshot | 4-module bento (trend, plate, breath, lesson) | No | Defer |

The **interactive medium "Quick Log" widget** is the highest-ROI build. FoodNoms has shown that one-tap preset logging reduces time-to-log to 2–3 seconds, which correlates with adherence in digital self-monitoring research. ([Apple — Interactive widgets docs](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [Nutrient Metrics — Quick Log widget audit](https://www.nutrientmetrics.com/en/guides/widget-lock-screen-quick-log-feature-audit))

### Smart Stack / Suggestions

Define `TimelineProvider` to surface the food widget around mealtimes (11:30, 17:30) and the trend widget on Sunday morning (weekly check-in moment). Apple's Smart Stack will rotate the right widget to the top.

### Recommendation priority for v1.0.7
1. **Lock Screen accessoryCircular** (food ring) + **accessoryRectangular** (trend line). ~1 day each.
2. **Home Screen small Today's Plate** + **small Trend**. ~2 days.
3. **Interactive medium Quick Log widget.** ~3–5 days. Highest engagement payoff.

Total: ~1.5 weeks of widget work, well-scoped for v1.0.7's food rail sprint.

---

## 6. Home layout — slot-by-slot iOS-native + brand

### Current
cocoa note → food card → JeniMethod → steps+breath compact → workout (demoted)

### Proposed structure

iOS-native chrome: `NavigationStack` with **large title that scrolls into inline** ("jenifit" or omitted entirely for a stickered hero). `ScrollView` + `LazyVStack` (not List — the brand needs custom card chrome that List would fight). ([SwiftUI ScrollView vs List](https://swiftprogramming.com/scrollview-vs-list-swiftui/))

```
┌─────────────────────────────────────────┐
│  ☉                              ⌃       │  <- iOS 18 inline nav: settings glyph
│                                         │     top-right (HIG default), tiny
│                                         │
│   good morning, han ♥                   │  <- HERO: cocoa note, italic
│   today's ritual                        │     punch on "ritual"
│                                         │
├─ TODAY ────────────────────────────────┤  <- iOS section header, all-caps,
│                                         │     cocoa70%, 11pt, like Apple Health
│  ┌────────────────────────────────┐    │
│  │  today's *plate*               │    │  <- Slot 1: Food card (scrapbook
│  │  ◐  1,247 / 1,650 cal          │    │     chrome: 24pt corners, border,
│  │  ▱▱▱▱▱▱▱▱▱▱  fits ♥           │    │     shadow). ~180pt.
│  │  [breakfast pill][lunch pill]  │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  *becoming* moves              │    │  <- Slot 2: Movement (workout +
│  │  ▶  10-min plank + glow        │    │     plank). Compact card, ~140pt.
│  │  breath after if you want      │    │
│  └────────────────────────────────┘    │
│                                         │
├─ HEALTH ──────────────────────────────┤
│  ┌─────────┬─────────┬─────────────┐   │
│  │ steps   │ breath  │ weight      │   │  <- Slot 3: 3-ring health strip
│  │ 7,432   │ 3 min   │ 64.2 ▾      │   │     (replaces steps+breath
│  │ ◐ 99%   │ ◐ 60%   │ trend ↘     │   │     compact). ~120pt.
│  └─────────┴─────────┴─────────────┘   │
│                                         │
├─ LEARN ───────────────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  today's *lesson*              │    │  <- Slot 4: JeniMethod swipe card.
│  │  why *protein* feels different │    │     ~200pt.
│  │  ⏱ 2 min  ●●○○○                │    │
│  └────────────────────────────────┘    │
│                                         │
│   ⌄ what's *changing* ⌄                 │  <- Subtle hint to Becoming tab
│                                         │
└─────────────────────────────────────────┘
```

### Slot heights (compact iPhone SE3 4.7" floor)

| Slot | Height | Why |
|---|---|---|
| Nav bar (inline) | 44pt | iOS standard |
| Hero cocoa note | 96pt | Above-fold, never scrolls past |
| Section header | 28pt | Apple Health pattern |
| Food card | 180pt | Hero of the new food rail |
| Movement card | 140pt | Demoted but visible |
| Health strip (3-ring) | 120pt | Glanceable, links each to detail |
| Lesson card | 200pt | High-engagement (75%+ completion) |
| Becoming hint | 44pt | Light tap target |
| Tab bar | 56pt (iOS 18) → 64pt floating (iOS 26) | System |

Total above-fold on SE3: hero + food card + half of movement = visible. Everything else scrolls. On iPhone 15+, food card + movement + half of health strip visible above fold.

### iOS 18+ patterns to lean into

- **`refreshable {}`** on the ScrollView for pull-to-refresh syncing weight + steps. Native gesture, free.
- **`.contextMenu`** on each card (long-press → "skip today", "log later", "hide for now"). HIG-canonical. Anti-shame: "skip today" with no penalty.
- **`.swipeActions`** would require List — not worth abandoning custom card chrome for it. Use context menu instead.
- **`.scrollTransition`** for subtle entrance bloom (already established in motion tokens).
- **Header card pattern** from iOS 18 (title card that fades into inline nav as you scroll) — apply to the hero cocoa note so "good morning, han ♥" becomes "jenifit" in the nav bar when scrolled. ([Verkoeyen — iOS 18 navigation title cards](https://jeffverkoeyen.com/blog/2024/08/24/iOS-18-Navigation-Title-Cards/))

### What changes from current
- **Workout demoted further** to inside Movement card (combined with plank), not its own slot. Plank-only doesn't deserve a slot; 7,500-step pulse doesn't deserve a slot; breath doesn't deserve a slot. Bundle them.
- **3-ring health strip** replaces 2 compact rails (steps + breath). Adds weight. Each ring taps into detail.
- **Section headers** ("TODAY", "HEALTH", "LEARN") are new and iOS-native. They give the page a Apple-Health-Summary readability without flattening the brand.

---

## 7. Becoming layout — iOS-native cohesion

### Current
5 chapters: your week / what you ate / how you moved / what's changing / what's worked

### Diagnosis

"Chapters" is the wrong mental model. Becoming is a **dashboard you scroll through, not a story you page through**. The current naming + visual treatment suggest sequential reveal (Stories, Wrapped) but the implementation is a long scroll. Resolve the contradiction.

### Recommendation: rename to **modules**, present as a single scrollable surface with iOS-native section grouping

iOS-native chrome: `NavigationStack` with **large title "becoming ♥"** (custom-font Fraunces, scales correctly with `relativeTo: .largeTitle`). ([Hacking with Swift — Dynamic Type with custom font](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-dynamic-type-with-a-custom-font))

```
┌─────────────────────────────────────────┐
│                                  ⋯      │
│                                         │
│  *becoming* ♥                           │  <- Large title, italic-Fraunces
│  week 3 of your jenifit                  │     punch word
│                                         │
├─ THIS WEEK ───────────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  identity hero                  │    │  <- Q140 + Q111 hero card,
│  │  "i'm someone who *shows up*"   │    │     scrapbook chrome
│  │  for *3* weeks now              │    │
│  └────────────────────────────────┘    │
│                                         │
├─ WHAT YOU ATE ────────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  ╱╱╱╱╱── trend line ╲╲         │    │  <- Trend-as-hero card, large
│  │  this week fits like           │    │     (no daily numbers)
│  │  *yesterday* mostly             │    │
│  └────────────────────────────────┘    │
│                                         │
├─ HOW YOU MOVED ───────────────────────┤
│  ┌──────────────┬─────────────────┐   │
│  │ activity     │ plank curve     │   │  <- 2-up: WHO ring + Mastery
│  │ ring          │ Bandura/Annesi  │   │
│  └──────────────┴─────────────────┘   │
│                                         │
├─ WHAT'S CHANGING ─────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  weight EMA + goal pace         │    │  <- Single card, ACSM overlay
│  │  ↘ 0.7%/wk, on pace ♥          │    │
│  └────────────────────────────────┘    │
│                                         │
├─ WHAT'S WORKED ───────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  barrier resolved               │    │  <- Rhodes & de Bruijn card
│  │  "*sleep* was the lever"        │    │
│  └────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### Why ScrollView + LazyVStack (not List)

Apple Health Summary uses a custom card-stack pattern over a `UIScrollView`, not `UITableView`. Same logic applies in SwiftUI: List would impose system row chrome that fights the 24pt cocoa-bordered card. ([Mobbin — Apple Health Summary](https://mobbin.com/explore/screens/5e311abb-f8f6-4e0b-9d44-a03671426672))

### Section headers — iOS-native voice + brand voice

Use system-style all-caps section headers (`Typo.eyebrow` cocoa70% 11pt) the way Apple Health does ("FAVORITES", "HEART", "RESPIRATORY"). Caps section headers are **the** iOS-native readability signal. Lowercase casual everywhere else preserves brand voice. The contrast actually reinforces both.

### Header card pattern

Apply the iOS 18 navigation title card pattern: "becoming ♥" large title at top fades into "becoming" inline as you scroll. This is the single most iOS-18-native touch you can add — Apple Notes, Mail, Settings all do this. ([Verkoeyen — iOS 18 nav title cards](https://jeffverkoeyen.com/blog/2024/08/24/iOS-18-Navigation-Title-Cards/))

### Tap targets + drill-down

Each module card pushes via NavigationLink to its detail view (existing). Becoming becomes the **directory of meaning**; details are the depth. iOS-canonical pattern.

### What changes from current
- **"Chapters" → "modules"** internally; user-facing copy drops the word entirely.
- **Section headers added** (5 ALL-CAPS).
- **Large title with italic-Fraunces punch** replaces flat title.
- **2-up grid** for "how you moved" (WHO ring + Mastery curve) instead of stacked.

---

## 8. Accessibility + Dynamic Type with custom Fraunces

### The constraint

Fraunces is a custom font. Without explicit scaling configuration, custom fonts do NOT respond to Dynamic Type, which fails WCAG and is a common App Review flag for health apps. ([Hacking with Swift — Custom font + Dynamic Type](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-dynamic-type-with-a-custom-font), [Sarunw — scale custom font](https://sarunw.com/posts/swiftui-scale-custom-font-dynamic-type/))

### The fix (already partially in place per CLAUDE.md)

Every Typo token already uses `Font.custom(_:size:relativeTo:)` per project notes. Audit needs:

1. **Verify every `Font.custom(...)` call site passes `relativeTo:`** — not size-only. Project notes say this is done; confirm with a grep.
2. **`@ScaledMetric` for layout numerics** — corner radii, padding, icon sizes that should breathe with text. ([avanderlee — @ScaledMetric](https://www.avanderlee.com/swiftui/scaledmetric-dynamic-type-support/))
3. **`dynamicTypeSize(...accessibility1)` clamps on hero numerics** — already done for 88pt timer, 64pt weight, 64pt onboarding %. Extend to:
   - Home hero "good morning" if it goes above ~28pt
   - Becoming large title if it goes above 34pt
   - Lesson card title if above 22pt
4. **Adaptive layout at accessibility sizes** — `@Environment(\.dynamicTypeSize)` in card layouts. When `dynamicTypeSize >= .accessibility1`:
   - 3-ring health strip collapses to vertical stack (not 3-up)
   - 2-up Becoming "how you moved" collapses to vertical
   - Food card meal-pill row wraps instead of horizontally scrolling
5. **`accessibilityElement(children: .combine)`** on every multi-component card (already done for 5 row types per project notes; extend to new home cards).

### Italic-Fraunces specifically

Italics are an accessibility concern for users with dyslexia. Mitigations:
- Keep italic punch words **short (1–3 words)**, never a full sentence. Already the brand rule.
- Ensure underlying weight is the readable Fraunces weight at small sizes (Fraunces variable axes — opsz, wght, soft). Tune `opsz` axis to "Display" only at >24pt; use "Text" at ≤17pt body.
- Test with Larger Text settings turned all the way up + VoiceOver. Add to the existing QA harness.

### Reduce Motion

Project notes confirm Reduce Motion gates on HomeView animateIn, refresh rotation, AnalyticsView cascade, ChangeTrainerView cascade, BrowseWorkoutsView swell. Extend the same to:
- Becoming module entrance bloom
- Dynamic Island scan animation (provide a static "scanning..." text fallback when Reduce Motion is on)
- Widget Quick Log button feedback (no haptic + no scale animation under Reduce Motion)

### VoiceOver labels

- Tab bar third tab: label as "log food and weight" — not just "plus" or "log".
- Camera scan Dynamic Island: announce "scanning food, finished" on completion.
- Trend lines in widgets: provide `accessibilityValue` with the numeric delta ("down 0.4 kilograms this week").

---

## Sources

- [Apple HIG — Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [WWDC24 — Elevate your tab and sidebar experience](https://developer.apple.com/videos/play/wwdc2024/10147/)
- [WWDC25 — Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [WWDC25 — Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- [Apple Newsroom — Liquid Glass announcement (2025-06)](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [Donny Wals — Exploring tab bars on iOS 26 with Liquid Glass](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)
- [createwithswift — Making the tab bar collapse while scrolling](https://www.createwithswift.com/making-the-tab-bar-collapse-while-scrolling/)
- [Apple Developer — Explore Live Activities and the Dynamic Island](https://developer.apple.com/news/?id=bkm73839)
- [WWDC23 — Design dynamic Live Activities](https://developer.apple.com/videos/play/wwdc2023/10194/)
- [WWDC23 — Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2023/10184/)
- [Apple Developer — DynamicIsland documentation](https://developer.apple.com/documentation/widgetkit/dynamicisland)
- [Apple Developer — Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [WWDC23 — Bring widgets to life](https://developer.apple.com/videos/play/wwdc2023/10028/)
- [Apple Developer — WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Apple HIG — Activity rings](https://developer.apple.com/design/human-interface-guidelines/activity-rings)
- [Apple Developer — SwiftUI building lists and navigation tutorial](https://developer.apple.com/tutorials/swiftui/building-lists-and-navigation)
- [WWDC22 — The SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/)
- [Verkoeyen — iOS 18 navigation title cards](https://jeffverkoeyen.com/blog/2024/08/24/iOS-18-Navigation-Title-Cards/)
- [Hacking with Swift — Dynamic Type with custom font](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-dynamic-type-with-a-custom-font)
- [Sarunw — Scale custom font with Dynamic Type](https://sarunw.com/posts/swiftui-scale-custom-font-dynamic-type/)
- [avanderlee — @ScaledMetric](https://www.avanderlee.com/swiftui/scaledmetric-dynamic-type-support/)
- [Sarunw — Bottom sheet with presentationDetents](https://sarunw.com/posts/swiftui-bottom-sheet/)
- [UX Planet — FAB alternatives on iOS](https://uxplanet.org/3-alternatives-to-the-floating-action-button-54f6b7c96714)
- [uiuxdesigning — iOS Tab Bar 2026](https://uiuxdesigning.com/ios-tab-bar/)
- [MacRumors — iPadOS 18 tab bar + sidebar](https://www.macrumors.com/2024/06/13/ipados-18-tab-bar-apps/)
- [Mobbin — Apple Health iOS Summary](https://mobbin.com/explore/screens/5e311abb-f8f6-4e0b-9d44-a03671426672)
- [Mobbin — MacroFactor iOS Dashboard](https://mobbin.com/explore/screens/c82256d1-7c67-4bb8-bc51-86bc460c79ef)
- [Mobbin — Apple Fitness Summary](https://mobbin.com/explore/screens/f8ca0d70-c83d-41de-94d0-2c45cd3c266d)
- [MacroFactor widgets announcement](https://macrofactor.com/widgets-announcement/)
- [Nutrient Metrics — Lock Screen & Widget Quick Log feature audit 2026](https://www.nutrientmetrics.com/en/guides/widget-lock-screen-quick-log-feature-audit)
- [Airship — iOS Live Activities explained](https://www.airship.com/explainer/ios-live-activities-explained/)
- [LogRocket — Building iOS Lock Screen widgets](https://blog.logrocket.com/building-ios-lock-screen-widgets/)
- [MacroFactor vs Cal AI 2026](https://macrofactor.com/macrofactor-vs-cal-ai/)
- [PlateLens — MyFitnessPal alternatives 2026 (redesign critique)](https://platelens.app/blog/myfitnesspal-alternatives-2026)
