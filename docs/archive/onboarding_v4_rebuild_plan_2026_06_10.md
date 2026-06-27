# Onboarding v4 — full rebuild spec
2026-06-10 · grounded in founder device screenshots (IMG_6315–6335) vs her75 reference set

The v3 passes restyled in place and failed. v4 rebuilds the onboarding on
four pillars: a screen scaffold that CANNOT break, the her75 typeface
(not Fraunces), a revised question set for the custom-program doctrine,
and one CTA system. Implementation is phased; every phase ships visibly.

---

## A. The scaffold — "progress bar + button never move" guarantee

Diagnosed failures (from device screenshots):
- IMG_6331 (hormonal, 6 options + care card): content overflows; SwiftUI
  collapses spacers; navBar pushed into the status bar; CTA off-position.
- IMG_6332/6316 (GLP-1): same overflow; care card pushes Continue down.
- IMG_6335/6334 (plan reveal): hero text CLIPPED off both screen edges.
- Buttons render at different sizes/colors/cases per screen.

Root cause: every screen is a free-form VStack. Spacers flex; nothing
docks the CTA; nothing clips content.

### The fix: `OnboardingScaffold`

ONE container view that every onboarding screen renders inside:

```
┌─ safe area top ────────────────────────┐
│ NAV DOCK     fixed 56pt (eyebrow slot + back + 2pt hairline)
├────────────────────────────────────────┤
│ HERO DOCK    fixed 140pt, topLeading   │  ← headline wraps INSIDE
├────────────────────────────────────────┤
│ CONTENT      flex, .clipped()          │  ← options/slider/card
│              scrolls INTERNALLY only   │     never pushes siblings
│              if > available height     │
├────────────────────────────────────────┤
│ CTA DOCK     fixed, via safeAreaInset  │  ← JFContinueButton, SAME
│              (bottom)  56pt + insets   │     pixel Y on every screen
└─ safe area bottom ─────────────────────┘
```

- CTA rendered with `.safeAreaInset(edge: .bottom)` on the scaffold —
  mathematically impossible for content to move it.
- Content region `.clipped()` — overflow can never collide with nav.
- Hero dock fixed 140pt (38–40pt Didone wraps 3 lines max inside).
- jfQuestion / jfMulti / jfYesNo / sliders / teach / bridge ALL render
  through the scaffold. Zero free-form VStacks left in the flow.

### Density rules (prevent overflow at the source)
- ≤4 options → single column, 60pt slim rows.
- 5–6 options → TWO-COLUMN grid (her75 "biggest challenge" pattern),
  with photo/text cards where the content earns it.
- 7+ options → cut options. Hard cap.
- Icon circles on list rows: REMOVED (the pink camera/leaf/lock circles
  read survey-app; her75 rows are text + radio only). This alone removes
  ~28pt of height per row and fixes most overflow.
- Duty-of-care cards (163/164): compact to a single footnote line under
  the options ("we adjust for GLP-1 — satiety-aware portions, no
  restrictive windows."), not a chunky card.

---

## B. The typeface — swap the display serif

Fraunces ≠ her75. her75's serif is a high-contrast Didone (Saol/Canela
family vibes): razor-thin hairlines, vertical stress, sharp ball
terminals, dramatic italics. Founder authorized the swap.

### Plan
- Add **Bodoni Moda** (Google Fonts, OFL — free, ships static weights +
  true italics) for ALL hero/display typography. Fallback candidate:
  Playfair Display (same license profile).
- Display ladder swap (in Typo tokens only — one place):
  - `heroHeadline` → Bodoni Moda SemiBold ~40pt (Didone x-height is
    smaller; 40pt Didone ≈ 38pt Fraunces optical size)
  - `heroHeadlineItalic` → Bodoni Moda Italic SemiBold ~40pt
  - lineGap: retune on device; start -10 (Didones need less negative
    leading to "touch" because ascenders/descenders are shorter)
  - celebration: Bodoni Moda 46pt
- DM Sans stays for: body, options, captions, CTA label.
- Fraunces retires from heroes. (Sticker numerals/ornaments may keep it.)
- Rollout = swap the token definitions; every surface updates at once
  because v3 already centralized the call sites.

---

## C. One CTA system

- `JFContinueButton` (DM Sans SemiBold 16, 56pt, cocoa fill, cream text,
  lowercase "continue") is the ONLY advance control. Replace:
  - `Button("Continue").buttonStyle(.ctaPrimary)` in sliders (Title case
    + different chrome — visible in IMG_6315/6333)
  - the italic-Fraunces lowercase capsules ("continue", "see your plan")
  - the pink "Not me / Yeah, that's me" pair on psychometrics → two
    equal-height 56pt pills docked in the CTA region (outline + filled),
    DM Sans, same width split
- Disabled state: cocoa 35% — identical everywhere.
- NEVER italic serif inside a button. her75 buttons are plain sans.

---

## D. Question set v4 (custom-program doctrine)

Founder: "we're offering a custom weight-loss program without focusing
on one side of body" — the program decides, the user informs.

### CUT (stop asking; stop writing old columns; leave columns in DB)
| Case | Question | Why cut |
|---|---|---|
| 110 | "which areas do you want to work on" (bodyFocus multi) | spot-training framing contradicts custom-program doctrine |
| 25 | session length ("how much time can you give") | program derives session length from tier + activity; asking implies user-assembled workouts |
| 17 | commitment days picker | program derives weekly cadence from tier; keep tier pick only |
| 2  | "training now?" experience | folds into activity level (case 8) |

### Replacement signals → NEW storage (never reuse old columns)
- `onb_v4_movement_baseline` — single Q merging activity + experience:
  "how does movement fit your life right now?" (4 options: barely /
  walks here and there / regular-ish / very active)
- The generator maps tier × movement_baseline → session length +
  weekly cadence internally (defaults in WorkoutGenerator; no schema
  change required server-side; new AppStorage keys + UserRecord columns
  added additively).

### KEEP (the program-engine signals)
goal weight pair, height, age, hormonal stage, GLP-1, sleep, stress,
eating cadence/window, food relationship, pace/tier, psychometrics,
name, attribution.

Net flow target: ~30–34 screens (from 55). Fewer, denser, every screen
on the scaffold.

---

## E. Screen-by-screen kill/restyle list (the "ugly" set)

| Screen | Today | v4 |
|---|---|---|
| Teach beats (230/231/233/234/166) | eyebrow-caps + ❤️ emoji + "— signature" italic line | 2-line Didone hero + ONE plain sub line. No eyebrow, no emoji, no signature. Merge 230+231; cut 233 or 234 (one teach beat per chapter max) |
| Section dividers (200–205) | "PART SIX" caps + hero + sub | cut to 3 dividers max; single Didone line only ("your story" / "the numbers" / "almost yours"); no PART label |
| Bridges (280/281/282/283) | mixed | fold into dividers above; 283 cohort keeps its line + (future) photo huddle |
| Psychometrics (171–173) | pink circle sticker + serif statement + pink button pair | her75 register: statement only, centered, Didone with italic chunk; two docked pills. No sticker circle |
| Loader | pink blob + gradient bar + sticker scatter + checklist + dots | IMG_6280 clone: centered Didone "personalizing your plan" + 2pt hairline (200pt wide) + NOTHING else |
| "ready ♥" | red emoji heart + italic capsule | "ready." Didone hero + standard CTA. No emoji ever (♥ text glyph only, sparingly) |
| Method preview (250) | AI-generated Jeni portrait | KILL the AI portrait (Direction A: no AI faces). Restructure as typographic 5-row list (her75 day-one card register) |
| Plan reveal | clipped hero + bordered tile grid + curve | fix clip; restyle as her75-3 "day one" card: white card, hand-script numerals optional, slim rows; ONE card not nested grids |
| Attribution/hormonal/GLP-1 lists | 6 tall icon-circle rows | 2-col text cards or slim no-icon rows per density rules |

---

## F. Photo / illustration guidance (actionable summary)

Locked direction (art synthesis + founder calibration): real-photo
editorial, coquette accents ≤2, NO AI faces, NO illustration heroes.

Where photos go (only these; everything else typography-only):
1. **Welcome** — full-bleed or collage of 3 faceless lifestyle photos
   (matcha being whisked, journal page w/ handwriting, shoulder-down
   mirror selfie). her75.webp register.
2. **Cohort proof (283)** — 3 round faceless portraits in a huddle OR
   3 photo cards (her75-share.webp register).
3. **Plan reveal** — "day one" white card OVER a faceless lifestyle
   photo (her75-3.webp / IMG_6278 register). The single most premium
   move available to us.
4. **Paywall** — photo collage modules (her75-2.webp register).

Sourcing (until the 30-photo library is commissioned):
- Curate from Pexels/Stocksy-style ONLY with the locked rubric:
  faceless (crop above eyes or shoulder-down), warm natural light,
  film grain, max 3 hue families, harmonizes with cream #FDF6F4,
  saturation -15 in post. NO gym, NO scales, NO branded products.
- Ship v4 with 6–8 curated photos (welcome ×3, cohort ×3, reveal ×1,
  paywall ×4 can reuse). Commission the full library after.

---

## G. DB / migration strategy

- New questions write to NEW AppStorage keys (`onb_v4_*`) + additive
  UserRecord columns. Old columns (bodyFocus, sessionLength,
  commitmentDays, experience) stay in schema + keep their data for
  existing users; generator reads new keys with fallback to old.
- Existing users who completed onboarding are untouched (flow only
  runs for new installs).

---

## H. Phases

1. **R1 — Scaffold + CTA unification.** OnboardingScaffold + dock all
   screens + JFContinueButton everywhere + slim no-icon rows + 2-col
   grids + compact care footnotes. (Fixes every "broken" screenshot.)
2. **R2 — Typeface.** Bodoni Moda bundled + token swap + leading retune.
3. **R3 — Question set v4.** Cuts + movement_baseline merge + new keys.
4. **R4 — Kill list.** Teach/divider/loader/psychometric/ready/method
   restyles per §E.
5. **R5 — Photos.** Curate 6–8 photos, wire the 4 surfaces.

Each phase: build + device screenshots + founder eyes before the next.
