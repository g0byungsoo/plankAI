# v1.0.9 plan — three deliverables (post-expert-synthesis)

Status: synthesis · 2026-06-08
Supersedes: docs/v1_0_9_theme_a_spec.md (USDA micronutrient path retired)

Three experts consulted in parallel: Cal AI/competitor product teardown,
Gen-Z viral-format research, JeniFit creative theming. Full agent
output preserved in this session's git log around `f291d0f`.

---

## D1 — Quick-add overhaul (chips + form)

### Lock-in

- **18 chips** hardcoded, each with display label + kcal + P/C/F.
  Full list in §1 below. Covers ~70% of cohort intake based on Cal AI
  top-50 + TikTok food-trend audits.
- **3 pill filters**: *eating out · drinks · made at home*. Default
  filter = *eating out* (highest log-intent moment).
- **Chips-first layout**, NOT 50/50 form/chips. Search bar at top
  ("what'd you eat?") — chips fill the rest of the screen — quiet
  "*type it instead*" link below the chips routes to the form.
  Typing in the search filters chips live; no match → "log as written"
  CTA on the typed string.
- **One-tap log** per chip — taps the chip, fires CapturedFood with
  the chip's hardcoded macros + the user's selected portion (default
  1.0× chip portion; pinch / + / − adjusts before confirm).

### §1 — The 18 chips

**Eating out (8)**
- Chipotle chicken bowl — 665 kcal / 45 P / 60 C / 25 F
- Sweetgreen Harvest Bowl — 705 / 32 / 70 / 36
- Cava chicken + greens bowl — 580 / 42 / 48 / 24
- Chick-fil-A grilled nuggets (8ct) + side salad — 235 / 28 / 12 / 8
- Raising Cane's 3-finger combo — 1,160 / 47 / 105 / 58
- Erewhon Hailey Bieber smoothie — 485 / 8 / 78 / 17
- Joe & The Juice Tunacado — 605 / 28 / 52 / 32
- Starbucks egg white + red pepper bites — 170 / 13 / 11 / 8

**Drinks (4)**
- Starbucks iced brown sugar oatmilk shaken espresso (grande) — 120 / 1 / 23 / 3
- Matcha latte, oat milk (12oz) — 165 / 4 / 25 / 6
- Dunkin cold brew, black (medium) — 5 / 0 / 1 / 0
- Protein smoothie (banana + whey + almond milk) — 320 / 28 / 38 / 6

**Made at home (6)**
- Avocado toast (sourdough + ½ avo + egg) — 380 / 16 / 32 / 22
- Greek yogurt parfait (nonfat + berries + granola) — 310 / 22 / 42 / 6
- Oatmeal w/ banana + peanut butter — 415 / 13 / 58 / 16
- Salmon + rice + greens bowl — 590 / 38 / 52 / 24
- Caesar salad w/ grilled chicken — 470 / 38 / 18 / 28
- Two scrambled eggs + toast — 340 / 18 / 24 / 18

### Avoid (per expert + voice locks)

- "i'm out" naming → rename to "dining out" (covers brunch/lunch/dinner)
- Red over-budget bars / negative remaining numbers
- Log streaks (keep streaks on workouts only)
- Meal-time naming pressure ("you haven't logged dinner")

---

## D2 — JeniFit theming for photo scan

### Lock-in

#### Color (split-role pink)

| Element | Idle | Scanning |
|---|---|---|
| Border | `#FF7AD9` softer | `#FF13F0` neon |
| Shutter ring | `#FF13F0` | `#FF13F0` |
| Inner disc | white | `#FFE7F7` sugar-pink tint |
| Scanline halo | rose `#C4677A` | rose (keep) |

Net: camera reads *warmer* at rest, jolts to neon at capture. Energy
becomes a brand beat, not constant noise.

#### Shutter "revolves as a unit"

Apply ONE `rotationEffect` to the whole `ZStack` (ring + disc + 📷
emoji). Drives:
- Idle: no rotation, gentle 6s scale 1.0 → 1.02 → 1.0 breathe
- Scanning: full rotation at 3.0s/rev, counter-direction to border
  shimmer (parallax)
- Sticker `-4°` tilt baked into emoji's own rotation INSIDE the
  spinning parent → reads as "sticker stuck to a coin"
- Drop the redundant white arc overlay entirely

#### Six JeniFit details

1. Cherries sticker top-left of camera frame, 36pt, `-8°`, idle-only
2. Bow_satin replaces glass `xmark` on result-mode close
3. Italic-Fraunces on `mealTypeLabel` (dish-name treatment)
4. Verify scrapbook border on NutritionCarousel (cream + 1.5pt
   rose border + hard offset shadow)
5. Microcopy → `Fraunces72pt-SemiBoldItalic 15pt + .tracking(0.3)`
6. Result-land haptic `.soft`

#### Bottom toolbar refresh

```
📷 snap   ✍︎ quick log   🍷 dining out
```

Active pill: white bg + cocoa text + 1pt rose border + hard offset
shadow (2,2). Micro-scrapbook chrome at chip scale. Spring on tap.

#### Microcopy lock

| Surface | Copy |
|---|---|
| Idle prompt | `find good *light* ♥` |
| Scan label rotator | `*looking* at your plate` → `*finding* the good stuff` → `*tallying* portions ♥` |
| Result-reveal | `*got it* ♥` |

#### Wow detail (the wedge)

**Sticker confetti on result-land.** 3-5 micro-stickers (cherries,
bow_satin, flower_3d, gummy_bear) burst from the shutter position
on a 0.8s spring, settle around the carousel card edges with random
`-12°` to `+12°` rotation, fade to `opacity 0.4` after 1.2s and stay
as scrapbook decoration. Reduce-motion gated. Plays once per result.

**Implementation files:**
- PhotoCaptureView.swift (rotation, microcopy, chips, confetti, haptic)
- RotatingScanBorder.swift (split-role pink)
- ScanningOverlay.swift (rotator copy)
- FoodTheme.swift (add `cameraIdlePink` + `cameraScanPink` tokens)

---

## D3 — Macro dashboard + food log + 9:16 shareables

### Macro dashboard

**Lives on Home slot 5** (per Cal AI + MacroFactor pattern, opposite
of MFP's diary-tab buried-ness). Single horizontal `TodayPlate` card:

- 3 thin macro bars (protein / carbs / fat) with target ticks
- kcal trend arrow (not a remaining number — anti-MFP)
- Tap → full day log

Slot 5 was already reserved in `[[project-home-architecture]]` memory
for the 3-ring strip; food card slots cleanly there.

### Food log timeline

**Chronological scroll** with photo/icon thumbnails + soft timestamps
("2:14pm"). NO meal-grouping (MFP-style "is a 4pm smoothie lunch or
snack?" forces decisions the cohort hates). Group header is just the
date ("today" / "yesterday"). Week view = 7 stacked-bar columns, tap
to expand.

### Daily 9:16 shareable (1080×1920)

```
[top 180px]    date in lowercase Fraunces italic — "*tuesday*, june 7"
[180-280px]    one-line mood/intention, lowercase 22pt SF — pulled
               from her own log
[280-1280px]   2×2 polaroid grid of meal photos, slight rotation
               (-3°, +2°, -1°, +4°), 24px white polaroid border,
               soft drop shadow. Each polaroid 440×500px.
               Caption 16pt SF italic: "matcha + toast"
[1280-1500px]  three soft pills, lowercase 18pt SF — NO kcal numbers
               "protein on track ♡ · hydrated · walked 8k"
[1500-1700px]  one Fraunces italic pull-quote, 32pt, centered:
               "*today fits*" (rotated daily from a curated 12)
[1700-1820px]  scattered stickers: cherry + bow + flower3D (3 max)
[1820-1920px]  "jenifit" wordmark, bottom-center, 14pt rose, 40% opacity
```

Background: cream `#F7F1E8` (NOT white — journal-page feel)

### Weekly 9:16 shareable

Different from daily — **trend-as-hero**:

```
[top]          "*this week i*" Fraunces italic 36pt
[upper-mid]    7 tiny polaroid thumbnails horizontal strip
               (one favorite photo per day, 120×140px each)
[mid hero]     soft hand-drawn-style trend line on cream
               (weight EMA or "days that felt good") — NO axis labels
[lower-mid]    3 stat pills: "logged 6 days ♡ · 4 walks · showed up"
[bottom]       Fraunces italic caption: "*becoming, slowly*"
[corner]       jenifit wordmark, 14pt, bottom-right
```

### Share output color palette

| Token | Hex | Use |
|---|---|---|
| Background | `#F7F1E8` cream | full bg |
| Text primary | `#3D2B2B` cocoa | body |
| Punch | `#C4677A` rose | italic Fraunces words + wordmark only |
| Dusty blush | `#E8B4B8` | pills + sticker glow |
| Cotton candy | `#FFD9DC` | sticker highlights |
| Peach | `#F5C3A0` | sticker highlights |

### Typography

Add **ONE** display font for share-only — recommend **Cormorant
Garamond** (Google Fonts, free, ships everywhere). Tan Pearl ($40)
is the Pinterest-trendier pick if license budget exists. Used ONLY
for date headers + pull quotes. Fraunces stays for in-body punch
words. SF stays for pills + captions. 3 fonts max.

### Viral hook (the share trigger)

```
"*today fits*. ♡"
```

Burned into every daily share, 24pt Fraunces italic, bottom-center
above the wordmark. Variants rotated daily from a curated 12:
*slow and on purpose*, *proud of this one*, *becoming, quietly*,
*a soft day*, …

Post-Ozempic vocab (permission, not performance). Anti-shame (no
number to compare). Brand-voiced. Screenshot-bait by reframing the
boring "I logged my food" act as a soft-girl identity moment.

---

## THREE PLACES THE EXPERTS PUSHED BACK — FOUNDER CALL NEEDED

### Q1. Brand pink: keep hot pink during scan, or go fully softer?

Founder asked "maybe our light pink instead of hot pink?"

Agent 3 pushed back: hot pink IS the camera-mode wedge. Switching
loses distinctiveness. Recommended middle ground: softer `#FF7AD9`
idle, neon `#FF13F0` only during scan.

Founder call:
- **(A)** Accept agent's split-role (warmer idle, neon scan). Best
  for brand distinctiveness.
- **(B)** Go fully softer (use `#FF7AD9` both idle + scan). Best for
  coquette consistency.
- **(C)** Go EVEN softer — use brand rose `#C4677A` for both. Loses
  camera wedge but maximally on-brand.

Agent recommends (A). Default if no override.

### Q2. Macro dashboard placement: Home slot 5 vs Becoming card?

Founder wife specifically wanted the dashboard "live somewhere in
becoming/home."

Agent 1 strongly recommended Home slot 5 (Cal AI, MacroFactor
pattern). Becoming risks analytics-graveyard burial. Home slot 5
was already reserved for the future 3-ring strip per
`[[project-home-architecture]]`.

Founder call:
- **(A)** Home slot 5 — accept agent's call (recommended)
- **(B)** Becoming tab — wife's suggestion, slower to discover but
  matches existing analytics surface
- **(C)** Both — Home card is summary, Becoming has the full view
  (more code, more polish surface area)

Agent recommends (A). Default if no override.

### Q3. Food log grouping: chronological vs meal-grouped?

Founder wife's screenshot showed meal-grouped (Breakfast / Snack / etc).

Agent 1 pushed back: meal-grouping forces "is a 4pm smoothie lunch
or snack?" decisions that abandon the log. Recommended Cal AI's
chronological scroll with soft timestamps.

Founder call:
- **(A)** Chronological scroll, no meal labels (agent's recommend)
- **(B)** Meal-grouped (wife's reference) — familiar but forces
  taxonomy decisions
- **(C)** Hybrid — chronological default, meal-group toggle for
  users who want it. More code, accommodates both prefs.

Agent recommends (A). Default if no override.

---

## Implementation order (if all locks land)

1. **D2 — Photo scan theming** (smallest, highest visual wow, lowest risk)
   - Most surgical changes; ships in 1-2 days
   - Confetti is the wedge that gets people to record screen on TikTok
2. **D1 — Quick-add overhaul** (medium, replaces existing weak surface)
   - Hardcoded 18-chip catalog is straightforward
   - 2-3 days incl. search filtering
3. **D3 — Dashboard + log + shareables** (largest, highest cohort retention impact)
   - TodayPlate Home card first (smallest piece)
   - Daily log timeline second
   - 9:16 shareable last (uses ImageRenderer like existing food share)
   - 4-5 days total

Total: 7-10 days of focused work. Could ship as v1.0.9 build 17.

---

## Theme A retirement

The USDA-micronutrient work in commit `f291d0f` stays — cheap to
leave, useful when we eventually wire real micronutrient data.
`docs/v1_0_9_theme_a_spec.md` should be marked superseded by this
doc. The food rail's slide 2 carousel either stays as-is (heuristic
scores from real macro intake — current behavior) or gets retired
once the Home macro dashboard lands. **Founder call**: keep carousel
slide 2 or fold its data into the Home dashboard?
