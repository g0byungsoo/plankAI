# her75 design extraction (2026-06-10)

Surgical extraction of her75's visual language for JeniFit. Scope is the 8
reference screenshots `IMG_6275.PNG` through `IMG_6282.PNG`. Translate the
*composition* + *typographic restraint* into JeniFit's coquette 3D glossy
sticker theme — do not copy her75's "75 hard" content register or its
lifestyle-photo collages.

---

## 1. The 8 her75 screens

- **IMG_6275** — App-Store-style hero (or onboarding cover). Centered serif
  headline "Matching *your* energy" with italic punch on *your*. Lifestyle
  photo collage bleeding off all four corners (ocean foam top-left, book stack
  top-right, lily bouquet bottom-left, matcha glass bottom-right), plus a
  centered circular avatar of a woman with a phone. Tiny pill caption
  "Among 24,000+ women" under the headline.
- **IMG_6276** — Partner-match card. Round portrait of "Mia" with green "live"
  dot + black "97% match" pill. Three pastel commitment chips (sage / butter /
  blush). Black pill CTA "Start with Mia" + underlined text link
  "Continue without partner."
- **IMG_6277** — Invite-friends paywall/upsell. 2-line italic-accent
  headline "Start the challenge *with* your friends?" + black social-proof
  pill "+30% success with friends." Cream invite-code card centered, two
  CTAs (greyed "Start solo" + filled black "Send invites" with share icon).
- **IMG_6278** — "Make *it* official" sticker reveal. Single editorial
  composition: a tall photo of a woman in a hallway with a "day one"
  challenge-rules sticker partially adhered over her, photo framed in a
  rounded portrait card. Italic-accent serif headline below, black pill
  CTA "Get my sticker," underlined "Skip" link.
- **IMG_6279** — The "day one" sticker artifact in isolation. White card,
  rounded, italic-Fraunces *day* + roman *one*, "mar 25 → jun 7" date
  range, numbered 1-5 list with emoji tail, footer eyebrow row
  "HER 75 CHALLENGE • BY HER 75" in tracked caps.
- **IMG_6280** — Personalization loading interstitial. Pure white field;
  centered 2-line headline "Personalizing *your* space" with italic on
  *your*; thin black progress bar at ~55%. Zero ornament. This is the
  her75 "luxury silence" beat.
- **IMG_6281** — Plan-reveal beat. 4-line headline "Congrats. You're *ready*
  to *start* your challenge" with italic on *ready* and *start*. Card
  preview of the day-one sticker centered. Black pill CTA "Start now."
- **IMG_6282** — Paywall. Photo strip (3 women hugging) inside a rounded pill
  + "+200,000 joined" caption. 3-line italic-accent headline
  "Join 200,000 *women* on their glow-up *journey*." Checkmark benefits
  list, 3 plan rows with "Most popular" tab + "Save 72%" pill. Black pill
  CTA "Continue," underlined legal links.

---

## 2. Typography system

Single serif family doing everything — appears to be Fraunces (or a
Fraunces-twin) at 72pt optical, in three roles: Light (rare), SemiBold
(default), SemiBoldItalic (the punch). DM Sans / system sans only on legal +
captions.

| Role | Family / weight | Est. pt | Tracking | Use |
|---|---|---|---|---|
| Hero headline 1-line | Fraunces SemiBold | 40–44 | −1.5% | IMG_6275, 6280 |
| Hero headline 2-line | Fraunces SemiBold + Italic punch | 36–40 | −1% | IMG_6277, 6278, 6282 |
| Hero headline 4-line | Fraunces SemiBold + Italic punch | 32–34 | −0.5% | IMG_6281 |
| Sticker masthead "day one" | Fraunces SemiBoldItalic + Roman | ~30 | 0 | IMG_6279, 6281 |
| Card title (name "Mia") | DM Sans SemiBold or Fraunces SemiBold | 20 | 0 | IMG_6276 |
| Body / pill copy | DM Sans / system Regular | 15–16 | 0 | All |
| Eyebrow caption | DM Sans Medium tracked | 11 | +6% caps | IMG_6279 footer |
| Button label | DM Sans SemiBold | 17 | 0 | All CTAs |
| Underlined link | DM Sans Regular underline | 14 | 0 | "Skip", "Restore" |

**Line-gap (negative leading)** — the her75 signature. Multi-line heroes
clamp so the phrase reads as a single editorial unit:
- 2-line at ~38pt: roughly **−14 to −16** (lines almost touch at
  descender/ascender — see IMG_6277, 6280, 6282).
- 4-line at ~34pt: roughly **−10 to −12** (IMG_6281). Tighter is
  unreadable at 4 lines.

**Punch-word placement** — the italic always sits on the *possessive*,
*adverb*, or *emotional verb* — never the noun:
- *"your"* (6275, 6280) — possessive
- *"with"* (6277) — preposition
- *"it"* (6278) — pronoun
- *"ready"* + *"start"* (6281) — verbs
- *"women"* + *"journey"* (6282) — exception: noun pair, because the
  whole phrase is the emotional point

Italic never appears on the first word or last word of a hero. It sits
mid-phrase to break the upright cadence.

---

## 3. Color + chrome

her75 runs **off-white #FAFAFA** + **near-black #0E0E0E** + tiny pastel
chip moments. The whole palette is:

| Role | Approx hex | Notes |
|---|---|---|
| Background | #FAFAFA / #F4F4F4 | Slightly cool, near-white |
| Text | #0E0E0E | True near-black, not warm |
| Card | #FFFFFF | Pure white card on the off-white field |
| Card border | none or 1pt #E5E5E5 | Often shadow-only, no stroke |
| Primary CTA fill | #0E0E0E | Solid black pill |
| Secondary CTA fill | #F1F1F1 | Greyed-out (IMG_6277 "Start solo") |
| Chip pastel sage | ~#D9E5BE | IMG_6276 |
| Chip pastel butter | ~#F4E58B | IMG_6276 |
| Chip pastel blush | ~#F3CBC1 | IMG_6276 |
| Status "live" green | ~#2BB661 | IMG_6276 dot |
| Save pill mint | ~#A9E3B8 | IMG_6282 "Save 72%" |
| Image bleed | full color | photos carry all color saturation |

**Card treatment**: rounded ~28pt corners, pure white fill on off-white
field, shadow only — no stroke. Cards float; they don't have JeniFit's
1.5pt accent border.

**Button shape**: full-pill (capsule). Heights ~56pt. Black fill, white
DM Sans SemiBold ~17pt label, often with a 14pt leading icon (share,
arrow). Secondary = grey-fill pill with greyed-out label. Tertiary =
underlined text link.

**JeniFit translation**: keep cocoa (`bgInverse #3D2A2A`) over true black —
black would break the warm-rose system. Keep the **shadow-only card** as a
new variant of the scrapbook card for editorial beats; the 1.5pt accent
border stays the default elsewhere. Pure white card on warm-cream feels
"clean luxury" without losing brand.

---

## 4. Sticker / photo treatment — and the JeniFit translation

### What her75 actually does

- **Real lifestyle photography**, never illustration. Photos are saturated
  but slightly grain-treated (subtle film-grain texture on the bouquet +
  ocean foam in IMG_6275).
- **Edge-bleed composition**: photos hug the four corners and bleed
  ~30–40% off the edge. Center column stays clear for the serif headline.
  Count per screen: 1 (IMG_6278), 3 (IMG_6282), 4–5 (IMG_6275).
- **Round portrait crop** for any face (IMG_6275 avatar, IMG_6276 "Mia",
  IMG_6282 group hug). The roundness is the calming move.
- **Sticker-on-photo composite** (IMG_6278): a paper-card "day one"
  sticker is photographically applied over the woman's body. The
  composite *is* the hero — the headline plays support below.
- **Pill of social proof** sitting between image and headline:
  "Among 24,000+ women" (6275), "+30% success with friends" (6277),
  "+200,000 joined" (6282). Always small, always grounded in a number.

### The JeniFit translation

JeniFit can't use lifestyle photos — wrong brand register (see
[[feedback_visual_richness_over_restraint]] + project memory: no stock,
no AI photography). But the *compositional move* maps cleanly:

| her75 does | JeniFit should do |
|---|---|
| 4-corner lifestyle photo bleed | 4-corner sticker scatter (already shipped via `StickerScatter.welcomeDefault`) — but bigger: 56–72pt hero stickers bleeding 30–40% off edge, ±6° rotation, not the current 32–44pt ambient size |
| Centered round portrait of a person | Centered round sticker hero (single 96–120pt glossy hero like `sticker_flower_3d` or `sticker_disco_ball`) inside a thin cocoa ring, mirroring IMG_6275's avatar move |
| Sticker-on-photo composite (IMG_6278) | Polaroid-card mock with a 3D glossy sticker "adhered" on top + 6° tilt + warm-rose paper shadow. This is what "Make it official" should look like as a JeniFit moment |
| Social-proof pill grounded in a number | Same pattern, same placement (between visual + headline), JeniFit version pulls from real Supabase counts (women shipped, sessions logged) per [[feedback_data_provenance]]. Cocoa fill + cream text instead of black |
| Pastel chip commitments (IMG_6276) | Already exists in JeniFit's `goalChip` family — keep the chip register, push the pastels to `accentSubtle` + sage `stateGood` + honey `stateWarn` to stay in palette |
| Pure white card | New variant: shadow-only `bgElevated` card with no accent border, reserved for editorial beats only (paywall hero, onboarding reveal, post-session celebration) |

The principle: **bleed coquette stickers as compositional structure**,
not as confetti. her75 uses photos as composition; JeniFit's stickers must
do the same load-bearing work, not just decorate.

---

## 5. Motion vocabulary (inferable from static state)

We can't see her75's motion in static screenshots, but compositional
restraint + IMG_6280's "Personalizing your space" interstitial imply:

- **Line cascade** on hero headlines — fade + ~6pt rise per line, ~340ms
  per line, ~120ms inter-line stagger. We already have `LineCascadeText`
  per [[feedback_her75_line_cascade]] — apply it on EVERY 2+ line hero
  (paywall, reveal, ChapterCompleteView). Italic punch animates within
  the same line as the upright neighbors.
- **Progress-bar fill** (IMG_6280) — easeInOut over `loadingTotalSeconds`
  (2.4s in our `Motion` enum). Single black bar on a faint grey track.
  No sticker idle drift during loading — the silence is the point.
- **Page transition** — best guess is `crossFade 0.45s easeInOut` per
  `Motion.crossFade`, not slide. Slides would feel app-y; her75 reads
  as page-to-page editorial.
- **Card landing** (paywall plan rows, day-one sticker) — single
  spring landing per-card, `gentleSpring` (0.55, 0.88), stagger 0.10s.
  Matches our existing `Motion.stagger` perfectly.
- **No hover-y or bounce-y reactive states**. Press = 0.16s easeOut
  fade-darken on the pill. Matches `Motion.tap`.

**Verdict**: zero new motion tokens needed. The Motion enum already
covers her75 — what we're missing is *applying* `LineCascadeText` to the
3-4 hero beats that don't yet use it (paywall hero, plan reveal,
post-onboarding "your plan is ready," ChapterCompleteView).

---

## 6. Five typography tokens JeniFit should add or tune

Mapping to `enum Typo` in `PlankApp/DesignSystem/Tokens.swift`:

1. **`heroHeadline` (NEW)** — Fraunces SemiBold 42pt, lineGap -16,
   relativeTo: .largeTitle. The IMG_6275 / IMG_6280 single-line scale.
   Currently we top out at `displayHero` (38pt Light) and `questionHero`
   (34pt SemiBold). her75 goes one register larger when the screen is
   silent. Use on: paywall hero, ProgramIntroFullScreenCover, app-store
   marketing screens. Pair with `heroHeadlineItalic` (Fraunces
   SemiBoldItalic 42pt).
2. **`heroSubpill` (NEW)** — DM Sans SemiBold 13pt, cocoa fill, 24pt
   capsule, +0.2 kerning. The IMG_6275 "Among 24,000+ women" /
   IMG_6277 "+30% success with friends" social-proof slot. Sits between
   visual + headline; never above headline; always anchored to a real
   number. New component `SocialProofPill`.
3. **`mastheadSticker` (NEW)** — Fraunces SemiBoldItalic 30pt for
   *day*, Fraunces SemiBold (upright) 30pt for *one*. The IMG_6279
   sticker masthead. We have `stickyNumeral` (28pt italic) but it's
   for row numerals, not titles. This token unlocks the
   ProgramStickyNoteHeader pattern.
4. **`captionTracked` (NEW or replace `editorialEyebrow`)** —
   DM Sans Medium 11pt, uppercase, tracking +0.18em (was +0.06 on
   `statLabel`). The IMG_6279 footer "HER 75 CHALLENGE • BY HER 75"
   register. Wider tracking than our current eyebrow — luxury-magazine
   convention.
5. **`questionHero` (TUNE)** — currently 34pt SemiBold, lineGap -14.
   For 4-line heroes like IMG_6281 ("Congrats. You're *ready* to
   *start* your challenge"), 34pt with -14 wraps badly. Add an
   `questionHero4Line` variant at **30pt, lineGap -10**, OR adopt the
   rule: any hero exceeding 3 lines drops one size token. Encode in a
   `dynamicHeroSize(_ lineCount:)` helper rather than a new static.

All five share the **`.kerning(-0.4)`** call-site convention at heroHeadline
size (matches her75's measured tracking of ~-1%).

---

## 7. Grok Imagine prompt brief — 5 prompts

Each prompt is self-contained; paste directly into Grok Imagine. All
share a baseline style suffix so the family reads coherent. Keep the
suffix in a code constant `GROK_JENIFIT_STYLE_SUFFIX` so all illustrations
ship with the same render.

**Shared style suffix** (append to every prompt):
> Photorealistic 3D glossy sticker render, gummy / iridescent / satin
> finish, sub-surface scattering, soft warm-rose key light at 30°, no
> shadow on the asset itself, isolated subject floating on a flat
> #FDF6F4 pink-cream background, square 1:1 framing, sticker bleeds
> ~6% off the bottom-right at a +5° tilt, tiny film-grain overlay 2%,
> dusty rose #C4677A accent highlights only, no other colors saturated,
> no text, no logo, no people, no faces, no hands. Coquette y2k editorial
> mood. Tactile, candy-like, premium. 2048x2048.

### (a) Goal-setting moment
> A single glossy 3D heart-shaped padlock charm rendered in dusty rose
> satin, with a tiny gold key suspended mid-air just above it on an
> invisible thread, both elements floating dead-center. The padlock has
> a subtle bow ribbon detail tied around its top loop. Reads as
> "committing to yourself, sealing in the intention" — the visual
> shorthand for setting a goal that's been made deliberate, not casual.

### (b) Social-proof "you're not alone" feel
> A loose huddle of three glossy 3D iridescent bows (pearl, blush, dusty
> rose) overlapping slightly at their knot-centers like friends standing
> shoulder-to-shoulder, each bow at a slightly different tilt and scale
> (largest bow center, smaller bows flanking). No people, but the
> composition reads unmistakably as "three friends together." Each bow
> has a tiny pearl detail in its knot.

### (c) Commitment-architecture "this is the version of you" symbol
> A single glossy 3D mirror compact (round, satin-rose case, partially
> open at a 30° angle), with the open mirror surface catching a soft
> iridescent reflection — not a face, just a swirl of dusty-pink and
> pearl light suggesting *future self*. The closed half of the compact
> has a tiny embossed bow detail on its lid. Reads as "the version of
> you that's already on its way."

### (d) Ritual / habit anchor
> A single glossy 3D perfume bottle in dusty-rose satin glass with a
> pearlescent rounded stopper, sitting upright dead-center. A thin
> iridescent ribbon is loosely tied around the bottle's neck, trailing
> down to one side. The bottle has no label. Reads as "the small daily
> ritual" — something you reach for at the same time every day.

### (e) Celebration / projection
> A cluster of glossy 3D iridescent objects floating in a loose
> arrangement: one center disco ball (palm-sized, pearl-finish), two
> small 3D sparkle stars in dusty rose flanking it, one heart-shaped
> charm in satin blush, and one tiny iridescent bow at the bottom-right.
> Objects orbit the disco ball at varying depths with mild parallax,
> all floating, no ground. Reads as "the moment you actually arrive."

---

## Files referenced

- `/Users/bko/plankAI/screenshots/IMG_6275.PNG` through `IMG_6282.PNG`
- `/Users/bko/plankAI/docs/THEME.md`
- `/Users/bko/plankAI/PlankApp/DesignSystem/Tokens.swift` (Typo enum, lines 18-211)
- `/Users/bko/.claude/projects/-Users-bko-plankAI/memory/feedback_her75_line_cascade.md`
- `/Users/bko/plankAI/PlankApp/DesignSystem/Components.swift` (LineCascadeText, ItalicAccentText, StickerScatter)
