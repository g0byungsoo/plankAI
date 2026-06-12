# JeniFit Theme — Visual System Reference

Canonical brand reference for v1.0. Pulled from `PlankApp/DesignSystem/Tokens.swift`
+ `Stickers.swift` + `Components.swift`. Use this as the source of truth when
generating new screens, marketing assets, or App Store screenshots.

The brand reads as a **soft, editorial scrapbook** — pink-cream surfaces, rose
accent, cocoa anchor, hand-drawn sticker scatter, italic-serif punch words.
Calm and confident, not loud. The aesthetic borrows from gen-Z/Alpha "soft
girl" scrapbook diaries, not the saturated neon of mainstream fitness apps.

> **Illustration system (2026-06-12):** all illustrated surfaces now run the
> it-girl editorial cutout register: true-alpha real-photo-style cutouts
> floating directly on cream, one subject per screen, generated via the
> Grok + Vision-cutout pipeline or founder-supplied PNGs. Generation
> hierarchy, placement grammar, per-screen inventory and the
> add-a-new-screen checklist live in
> `docs/itgirl_illustration_system_2026_06_12.md`. Sticker scatter remains
> locked to the 3 earned moments (welcome, plan reveal, graduation).

---

## 1. Palette

All values are sRGB hex from `Palette` enum. WCAG AA verified on `bgPrimary`
for normal-weight text.

### Backgrounds
| Token | Hex | Use |
|---|---|---|
| `bgPrimary` | `#FDF6F4` | App background. Soft pink-cream, the canvas. |
| `bgElevated` | `#FFFAF8` | Cards/sheets sitting above bgPrimary. Half-shade lighter. |
| `bgInverse` | `#3D2A2A` | Dark surfaces — primary CTAs, dark cards, chips. Cocoa-rose. |

### Text
| Token | Hex | Contrast | Use |
|---|---|---|---|
| `textPrimary` | `#3D2A2A` | 12.5:1 on bgPrimary | Body, headings — same hex as bgInverse. |
| `textSecondary` | `#7B5959` | 5.76:1 on bgPrimary | Muted body, captions, helper copy. |
| `textInverse` | `#FDF6F4` | — | Text on dark surfaces. |

### Accent (the pink)
| Token | Hex | Use |
|---|---|---|
| `accent` | `#C4677A` | Dusty rose. Selected states, accents, active progress, italic-Fraunces punch words sometimes. |
| `accentSubtle` | `#F5D5D8` | Pale pink. Selected pill backgrounds, frozen-day cells, sticker placeholder fills. |

**Accent rule:** primary CTAs use **cocoa (`bgInverse`)** with cream text, **not pink**.
Pink is for selection, celebration, and badging — not for "primary action."

### State
| Token | Hex | Use |
|---|---|---|
| `stateGood` | `#5F7345` | Sage. Success, streak active, weight goal hit. |
| `stateWarn` | `#8D6A2E` | Honey-bronze. Warnings, at-risk streak. |
| `stateBad` | `#B47272` | Soft red. Errors, delete-account warning. |
| `divider` | `#EFE0DC` | 1pt dividers, unselected pill borders. |

### Shadow
Warm rose tint, never black. Spec from `PlankShadow`:
- color: `rgba(196, 103, 122, 0.10)` (the accent at 10%)
- radius: `12`
- x: `0`, y: `2`

Pink shadows fade more visually than brown — alpha is 0.10 to keep elevation
legible on the cream bg.

---

## 2. Typography

Two families, both bundled. PostScript names matter — the SF stack is
**not** used.

### Fraunces (serif, editorial)
- `Fraunces72pt-Light` — display 56pt (heroes, plank-time numerics)
- `Fraunces72pt-Regular` — body serif when serif is needed
- `Fraunces72pt-SemiBold` — title 32pt (page titles, paywall headline)
- `Fraunces72pt-SemiBoldItalic` — **the JeniFit voice signal** (italic accent)

72pt optical size. "Medium" doesn't ship at 72pt — SemiBold is the closest.

### DM Sans (utility sans)
- `DMSans-Light`, `DMSans-Regular`, `DMSans-Medium`, `DMSans-SemiBold`

### Type scale (`Typo` enum)
| Token | Family / Size | Use |
|---|---|---|
| `display` | Fraunces Light 56pt | Hero numerics, splash. |
| `title` | Fraunces SemiBold 32pt | Page titles, paywall headline. |
| `titleItalic` | Fraunces SemiBoldItalic 32pt | Italic punch slot inside titles. |
| `heading` | DM Sans SemiBold 20pt | Section headers, card titles. |
| `body` | DM Sans Regular 16pt | Body copy. |
| `caption` | DM Sans Medium 13pt | Captions, helper, metadata. |
| `eyebrow` | DM Sans SemiBold 12pt | Section eyebrows, ALL-CAPS labels. |

All tokens use `Font.custom(_:size:relativeTo:)` so they Dynamic-Type-scale.

### The italic-Fraunces accent rule (signature voice signal)

One word per heading is **italic Fraunces SemiBold**, the rest is upright
Fraunces SemiBold. This is the JeniFit voice on screen — not optional.

Real examples from the app:
- *"Become **her** in 30 days."* — paywall (italic on "her")
- *"Define your **flat belly** in 30 days."* — paywall, flatBelly bodyFocus
- *"becoming her, one ordinary day at a time."* — Home subtitle (italic on "becoming")
- *"**becoming**"* — Becoming tab label (entirely lowercase, italic)
- *"**Today** counts."* — splash quote
- *"**Strong** is gorgeous."* — Welcome subtitle

Helper: `ItalicAccentText(_ string, italic: [String])` in `Components.swift`.

### Casing rule
**Lowercase casual** for nav labels, subtitles, body copy. Title-case for
hero headlines. Never ALL CAPS except `eyebrow` (12pt section labels).

---

## 3. Sticker system (the visual signature)

27 hand-drawn stickers in `Assets.xcassets/Stickers/`, partitioned into two
visual languages by `StickerStyle`:

### Line-art (4 stickers, opacity 1.0)
Single-color hand-drawn ink. Reads "diary doodle."
- `sticker_ribbon_lineart`
- `sticker_star_lineart`
- `sticker_camera_lineart`
- `sticker_hearts_lineart`

### Painterly (23 stickers, opacity 0.85)
Saturated 3D / painted illustrations. Knocked back to 85% so they recede
behind content.

**Original 13 (Phase 14a):**
- `sticker_heart_glossy`, `sticker_sparkle_glossy`
- `sticker_bow_satin`, `sticker_bow_iridescent`
- `sticker_flower_3d`, `sticker_tulip_bouquet`
- `sticker_seashell`
- `sticker_cherries`, `sticker_strawberry`
- `sticker_balloon_dog`, `sticker_teddy_plaid`, `sticker_teddy_pink`, `sticker_gummy_bear`

**Phase 19c additions (10, iridescent / dreamy):**
- `sticker_candy_iridescent`, `sticker_candy_long`, `sticker_candy_pearl`
- `sticker_disco_ball`, `sticker_perfume`, `sticker_cherub`
- `sticker_ice_cream`, `sticker_strawberry_ripe`
- `sticker_heart_lock`, `sticker_butterfly_ring`

### Scatter rules (from `StickerScatter` + welcomeDefault)
- **Position**: relative coordinates `(0..1, 0..1)`. Always **edge-hugging** —
  margins at `x ≤ 0.18` or `x ≥ 0.82`. Center column stays clear for content.
- **Size**: 32–44pt typical. Hero stickers up to 44pt; ambient ones at 32–36pt.
- **Rotation**: ±15° max. Never axis-aligned.
- **Count per screen**: 4 for ambient (auth/loader), 5 for hero (welcome), 6+ for celebratory (post-session, plan reveal).
- **Mix**: at least one line-art among painterly so the cluster doesn't read
  as all-glossy. Welcome uses 3 line-art + 2 painterly.
- **Phase delay**: stagger entrance + idle drift via `phaseDelay` 0.0–1.0.
  Adjacent stickers must pick distinct values so the cluster never breathes
  in unison.
- **Hit testing**: stickers are `allowsHitTesting(false)` — taps fall through.
- **A11y**: `accessibilityHidden(true)` — they're decorative.

### Default 5-sticker hero scatter (`StickerScatter.welcomeDefault`)
| Sticker | Position | Size | Rotation |
|---|---|---|---|
| `heartsLineart` | (0.13, 0.18) | 40 | -12° |
| `starLineart` | (0.86, 0.10) | 34 | +14° |
| `bowIridescent` | (0.82, 0.42) | 42 | -10° |
| `cameraLineart` | (0.88, 0.82) | 36 | -8° |
| `gummyBear` | (0.12, 0.86) | 44 | +11° |

---

## 4. Layout & chrome

### Spacing (4pt base, `Space` enum)
- `xs: 4`, `sm: 8`, `md: 16`, `lg: 24`, `xl: 48`
- `screenPadding: 16`, `cardPadding: 16`, `minTapTarget: 44`

### Corner radius (`Radius` enum)
- `sm: 8` (chips, pills)
- `md: 14` (buttons, small cards)
- `lg: 24` (large cards — the scrapbook size)

### Scrapbook chrome (the recurring card pattern)
Spec from CLAUDE.md (applied on Home, all 6 Settings sub-pages, Becoming tab
modules, Browse, PreSession, LogWeightSheet, PostSession, PostRoutine):
- **Corner radius**: 24pt (`Radius.lg`)
- **Border**: 1.5pt accent (`Palette.accent`)
- **Shadow**: hard offset (warm rose tint, see Shadow section)
- **Background**: `bgElevated` (#FFFAF8)

### Hit targets
44pt × 44pt minimum (HIG). Use `.tappableArea(_)` modifier to expand the
hit area without changing visible chrome — applied to icon buttons that
visually sit at 30–32pt.

### Home screen layout spec (Phase 10 — Gen-Z visual-craft research)
Governing rule: **spacing is proportional to relationship**, never uniform.
A gap that's both large and unanchored reads as "didn't finish loading," not
a designed breath. The home is ONE designed screen, not stacked widgets.

**Hierarchy (top → bottom):**
1. ONE coach voice line — Jeni avatar + a single daily line (one italic punch
   word). Flat, voice not a card; the only coach surface (no second greeting).
   Seed of the future coach-agent surface.
2. ONE hero session card — the only elevated, fully-pink, scrapbook-chromed
   object, and the only primary CTA. Lesson when due (tap → lesson → workout),
   otherwise today's workout.
3. Momentum strip — "day N of 14" dots + "shown up N times". The single home
   for the day count (the hero never repeats it). Flat, low emphasis.
4. Below fold: quick actions, then de-emphasized future-feature rails
   (steps / food / body-scan seeds).

**Spacing (hero card):** screen margins 20 · gap between cards 16 · hero
internal padding 20 · inside the hero: eyebrow→title 4, title→meta 8,
meta/list→CTA 20 (loose = its own unit). Internal padding ≤ inter-card gap.
No orphaned controls — a lone icon never sits in a full-width row (pair it
with the eyebrow on one baseline, or float it as a quiet corner overlay).

**Type:** ~5 roles max; negative tracking (−0.5 to −2%) on Fraunces display/
title; +6% on eyebrows; ONE italic punch word per surface; never set body in
Fraunces (display face, ≥20pt only).

**Color/depth:** one saturated accent, reserved for CTA + punch word + sticker
highlight only (all other pinks are tints). Warm rose-tinted offset shadow,
never grey. One elevation level — only the hero is raised.

**Stickers:** ≤3 per screen, 1 hero sticker per card, corner-anchored bleeding
~30–40% off the edge, rotated 4–8°; 100% opacity on the punctuation sticker /
8–15% on background motifs; never behind text or a CTA.

Sources: NN/g (visual hierarchy, color+signal), Baymard (card consistency),
Refactoring UI (proportional space, de-emphasis, constrained scale),
Material/Atlassian (8pt grid), Apple HIG (type, 44pt targets).

---

## 5. Motion (calm, mindful, magical)

From `Motion` enum. Philosophy: slow swells over snap, high-damping springs,
generous staggers, slow ambient loops.

| Token | Curve | Use |
|---|---|---|
| `entrance` | easeOut 0.55s | First-time element appearance (heroes, list rows, modal contents). |
| `entranceSoft` | easeOut 0.42s | Quieter reveals (toasts, badges). |
| `exit` | easeIn 0.32s | Dismissals. Pair with `.transition(.opacity)`. |
| `crossFade` | easeInOut 0.45s | Content swaps inside the same surface. |
| `tap` | easeOut 0.16s | Press response. Never a spring (bounce reads cheap). |
| `gentleSpring` | spring(0.55, 0.88) | Drag release, scale-pop, sticker landings. |
| `stagger` | 0.10s | Inter-element delay for cascades. |
| `breathing` | easeInOut 1.6s | Ambient loops (loaders, breathing pulses). |
| `loadingTotalSeconds` | 2.4 | Loading-screen choreography baseline. |

**Reduce-motion**: ALL decorative motion drops on the accessibility flag —
sticker idle drift, sticker entrance scale, HomeView animateIn cascade,
refresh icon rotation, AnalyticsView 9-section cascade. Snap to final state.

---

## 6. Voice & tone

- **Lowercase casual** for nav, subtitles, body. Never "Settings → Account" —
  always "settings → account."
- **Italic-Fraunces punch word** on every hero ("Become *her*", "*becoming*", "*today*").
- **Anti-AI language** — never "AI-powered," "smart algorithm," "personalized
  by AI." Talk about *what* the app does, never *how* in tech terms.
- **Research-grounded numbers** — every metric in the UI traces to a collected
  field or cited research (McGill plank norms, ACSM weight pace, Helander 2014
  EMA window). No fabricated stats, no placeholder estimates.
- **Affirmation register** — present tense, second person, calm. "You already
  started." "Show up. That's the whole thing." "Today counts."
- **Brand**: always **JeniFit** (one word, capital J, capital F). Never
  "Jenifit" / "Jeni Fit" / "JENIFIT."

---

## 7. Imagery

- **Coach photography**: not yet shot. Slot uses `EditorialPlaceholder` —
  diagonal pink-stripe block with a small label tag in the corner. Reads
  "intentionally unfinished," not broken.
- **No stock photos.** No AI-generated photography. Stickers + typography
  + palette carry the visuals.
- **Body-type illustrations** (`bodytype-0`, `bodytype-1`, `bodytype-goal`)
  are line-art figures matching the line-art sticker family.

---

## 8. Component catalog (for screenshot reference)

Located in `PlankApp/DesignSystem/Components.swift`. The ones a designer
generating marketing screens needs to know:

- **`JeniFitWordmark`** — the wordmark, Fraunces SemiBold, optional color override.
- **`ItalicAccentText`** — the italic-punch helper.
- **`StickerScatter`** + `Sticker` — the scatter system.
- **`OnboardingProgressBar`** — 4pt capsule, dusty rose fill on divider track.
- **`PulsingDots`** — the loading affordance (3 dots, accent color, breathing).
- **`PlankShadow`** modifier — the warm-rose elevation shadow.
- **Scrapbook card pattern** — not a single component; recurring shape:
  `RoundedRectangle(cornerRadius: 24)` with `.fill(Palette.bgElevated)`,
  `.stroke(Palette.accent, lineWidth: 1.5)`, `.plankShadow()`.

---

## 9. Anti-patterns (what JeniFit is NOT)

- ❌ Neon green / electric blue / safety orange (mainstream fitness palette)
- ❌ Sans-serif "tech" headlines (no Inter, no SF Display)
- ❌ Pure black backgrounds or pure black text
- ❌ Glossy gradient buttons, glassmorphism, drop-shadow stacks
- ❌ "Smash your goals" / "Crush it" / "Beast mode" copy
- ❌ Bouncy spring animations on taps
- ❌ Stock fitness photography (gym mirror, weight rack, protein shake)
- ❌ Centered everything — JeniFit lets things sit asymmetric, scrapbook-style
- ❌ All-uppercase headlines (only `eyebrow` 12pt labels are caps)
