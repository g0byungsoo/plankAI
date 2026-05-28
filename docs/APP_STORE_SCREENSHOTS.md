# JeniFit — App Store Screenshot Spec

Reference shot list for App Store Connect marketing screenshots. Pair with
`docs/THEME.md` (palette, typography, sticker rules) when handing this to
a designer or another Claude design session.

## Required sizes

App Store Connect (as of 2026) requires:
- **6.9" iPhone** — 1320×2868 (iPhone 16 Pro Max) — **required**
- **6.7" iPhone** — 1290×2796 (iPhone 15 Pro Max) — **required**
- **6.5" iPhone** — 1284×2778 — accepts 6.7" upscale
- **iPad** — only if iPad target; we're iPhone-only for v1.0, skip.

**5–10 screenshots** per locale. Recommend **8** for visual rhythm.

## Marketing frame template (applies to all 8)

Each screenshot is a composition of:
1. **Background**: solid `Palette.bgPrimary` (#FDF6F4) or `accentSubtle` (#F5D5D8) for accent shots
2. **Headline strip** (top ~22% of frame): one short editorial line, Fraunces SemiBold ~96pt, italic punch word, `Palette.textPrimary`
3. **Eyebrow** (above headline): one line DM Sans SemiBold ~32pt, `Palette.textSecondary`, lowercase
4. **Device mockup**: iPhone 15 Pro Max frame, centered, 65–75% of frame height, screenshot of the actual app screen inside
5. **Sticker scatter**: 3–4 stickers floating outside the device frame at the edges (NOT overlapping the device), per scatter rules in THEME.md
6. **No CTAs, no pricing, no badges** — Apple App Store renders price + "GET" itself

Color rotation across the 8 screens: bgPrimary (cream) for 6, accentSubtle (pink) for 2 (#3 paywall, #6 becoming-tab pride moment).

---

## The 8 shots

### 1. Hero / value prop

- **Eyebrow**: `for the soft girl getting strong`
- **Headline**: `Become **her** in 30 days.` (italic on "her")
- **App screen**: Welcome screen (`AffirmationScreen` final frame) — JeniFit wordmark + "Strong is gorgeous." + 5-sticker hero scatter
- **Background**: `bgPrimary`
- **Marketing stickers around device**: `heartsLineart` top-left, `bowIridescent` top-right, `sparkleGlossy` bottom-right
- **Why this shot first**: brand-first introduction. Establishes voice + aesthetic before any feature.

### 2. The plan reveal

- **Eyebrow**: `built around your answers`
- **Headline**: `Your **30-day** plank plan.` (italic on "30-day")
- **App screen**: Plan reveal screen from end of onboarding (the "Why JeniFit works" / plan card)
- **Background**: `bgPrimary`
- **Marketing stickers**: `cherub` upper-left, `flower3D` lower-right
- **Why**: shows personalization without saying "AI." Concrete deliverable.

### 3. Form-watching session (the differentiator)

- **Eyebrow**: `she watches your form`
- **Headline**: `Real-time **coaching**.` (italic on "coaching")
- **App screen**: SessionView with the camera card visible, timer running, gradient border (the SetLog-inspired card per memory feedback_session_design.md)
- **Background**: `accentSubtle` (pale pink — make this one stand out)
- **Marketing stickers**: `cameraLineart` upper-left (echoes the camera card), `starLineart` lower-right
- **Why**: the camera coaching is the moat. Lead with it on a pink panel for visual punctuation.

### 4. Becoming tab — research-grounded analytics

- **Eyebrow**: `becoming, by the numbers`
- **Headline**: `Trends you can **trust**.` (italic on "trust")
- **App screen**: Becoming tab scrolled to show Weight Trend EMA + Goal Pace Projection cards (the scrapbook chrome cards)
- **Background**: `bgPrimary`
- **Marketing stickers**: `discoBall` upper-right, `tulipBouquet` lower-left
- **Why**: shows depth without being clinical. Cite-grounded copy is JeniFit's defense against "another fitness app."

### 5. Streaks + freeze-day

- **Eyebrow**: `slow days count too`
- **Headline**: `Streaks that **breathe**.` (italic on "breathe")
- **App screen**: Home with active streak visible + a frozen-day cell in the activity calendar (lavender `frozenDay` pill)
- **Background**: `bgPrimary`
- **Marketing stickers**: `bowSatin` upper-left, `ribbonLineart` lower-right
- **Why**: differentiates from punishing streak apps. The "you don't have to earn rest" positioning.

### 6. Progress moment — body-type morph

- **Eyebrow**: `from where you are`
- **Headline**: `**becoming** her, day by day.` (italic on "becoming", lowercase)
- **App screen**: BMI card or body-type morph from Becoming tab (the bodytype-0 → bodytype-goal slider)
- **Background**: `accentSubtle` (pink — second pink shot, balance #3)
- **Marketing stickers**: `butterflyRing` upper-right, `perfume` lower-left, `heartGlossy` lower-right
- **Why**: emotional payoff. "Becoming" is the verb the brand is built on.

### 7. Voice coaching with Jeni

- **Eyebrow**: `meet your coach`
- **Headline**: `Jeni, in your **ear**.` (italic on "ear")
- **App screen**: Mid-session view with voice cue surfaced — or PreSession showing the trainer card
- **Background**: `bgPrimary`
- **Marketing stickers**: `seashell` upper-left, `cherries` lower-right
- **Why**: humanizes the "AI." The coach has a name; she sounds like a friend.

### 8. Plank check-in / mastery

- **Eyebrow**: `know what your time means`
- **Headline**: `From **30 seconds** to two minutes.` (italic on "30 seconds")
- **App screen**: Plank check-in screen with the McGill Waterloo norms reference table + last-hold pill
- **Background**: `bgPrimary`
- **Marketing stickers**: `gummyBear` lower-left, `sparkleGlossy` upper-right
- **Why**: closes with research credibility + concrete outcome. The "you'll actually get stronger" promise.

---

## Voice rules (from THEME.md, repeated for designer convenience)

- **Lowercase casual** in eyebrows, body. **Title case** in hero headlines (except where lowercase is intentional, like #6).
- **One italic punch word per headline.** Never two italic words. Never zero.
- **No emoji.** Stickers carry that role.
- **No "AI", "smart", "powered by", "personalized."** Talk about *what*, never *how*.
- **No exclamation marks.** Affirmation, not exhortation.
- **JeniFit** — one word, capital J, capital F. Never "Jeni Fit" / "JENIFIT" / "Jenifit."

## Asset inventory for the designer

**Direct PNGs they can use** (already in repo):
- All 27 stickers: `PlankApp/Assets.xcassets/Stickers/sticker_*.imageset/`
- App icon: `PlankApp/Assets.xcassets/AppIcon.appiconset/`
- Body-type illustrations: `PlankApp/Assets.xcassets/bodytype-{0,1,goal}.imageset/`

**Fonts to install** (`PlankApp/Resources/Fonts/`):
- Fraunces72pt: Light, Regular, SemiBold, SemiBoldItalic
- DM Sans: Light, Regular, Medium, SemiBold

**Recommended source-of-truth screenshots** (take these from the simulator
to use as the "actual app screen" inside each device mockup):
1. Welcome screen (cold launch, after AffirmationScreen settles) — for shot #1
2. Onboarding plan reveal screen — for shot #2
3. SessionView with camera active, timer at ~0:32 — for shot #3
4. Becoming tab scrolled to Weight Trend + Goal Pace cards — for shot #4
5. Home with 7-day streak + one frozen day — for shot #5
6. Becoming tab BMI / body-type morph card — for shot #6
7. PreSessionView or mid-Session voice surface — for shot #7
8. Plank check-in screen with norms table — for shot #8

Capture on **iPhone 15 Pro Max simulator** at default scale to match the
6.7" required size; downscale for 6.5" if needed.

## Localization note

v1.0 is English-only. If/when you localize, the italic punch word needs
re-selection per language — Korean / Japanese / etc. don't have italic in
the same sense, so the punch becomes a font-weight contrast (Regular →
SemiBold) or color contrast (`textPrimary` → `accent`).
