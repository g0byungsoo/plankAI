# education (jenimethod lesson) redesign spec — 2026-06-11

her75 register applied to the lesson player (`JeniMethodRitualView` + `LessonPage`).
Design spec only. Precedents: BreathworkIntroView (card + citation), BecomingFolio
(masthead/dot idioms), `docs/her75_typeface_spec_2026_06_10.md` (Jeni Hero Serif).
Locks honored: primer-style tappable pages stay (feedback_jenimethod_design); 2-page
days 2–14 / 4-page day 1 stays; scatter-free (lessons are teach beats per
feedback_scatter_milestone_rule); AI illustrations permanently dead (Direction A).

## 0. what changes at a glance

| current (Phase 10 player) | new register |
|---|---|
| pink bg + breathwork-primer StickerScatter | cream `bgPrimary` only, zero scatter |
| centered text column | left-aligned editorial column (breathwork-intro grid) |
| uppercase Fraunces eyebrow in accent pink, tracking 1.6 | lowercase DM Sans Medium 13 kicker in `textSecondary` |
| Grok paper-craft PNG in 196pt pink-bordered frame | typographic fact card (see §2); delete `lesson_d*` imagesets + the `illustration` render path (dead-code rule) |
| sticker accent on text pages (`page.sticker`) | removed; pages carry on type alone |
| 0.45s easeInOut crossfade between pages | JFPageTransition (200ms exit / 60ms gap / 350ms entrance) |
| heavy + success double haptic on finish | one `Haptics.soft` receipt beat (quieter than breathwork) |

Keep: fullScreenCover entry, RitualMusicPlayer ambient, back chevron + X circles
(restyle stroke to `divider`-on-`white.opacity(0.5)` like breathwork), CTA-advances
(no story-tap zones — a mis-tap skipping a 2-page lesson costs too much), re-read
suppression, RitualToWorkoutSplash handoff bridge.

## 1. page anatomy

Column: `.padding(.horizontal, Space.lg)`, everything `alignment: .leading`.
Background: `bgPrimary` cream (the only background; `programBgPrimary` is an alias).

**Top bar** — back chevron (pages > 1) · page dots centered · X. Page dots reuse the
BecomingWeekRow dot grammar at lesson scale: read pages = filled cocoa 7pt, current =
filled cocoa + accent ring 11pt (`todayDone` state), unread = `divider` stroke circle.
2 dots for days 2–14, 4 for day 1. No "2 of 2" text; the dots carry it.

**Kicker** (replaces eyebrow) — DM Sans Medium 13, `textSecondary`, lowercase:
`lesson four · the method` on page 1; page 2+ reuses the per-page slug ("real talk",
"one more thing") same style. Separator is the folio `·` in `divider` color.

**Headline** — `Typo.heroHeadline` 38pt Jeni Hero Serif roman + `heroHeadlineItalic`,
kerning −0.4, `lineSpacing(Typo.heroHeadlineLineGap)` (−0.505 × size), left-aligned,
`fixedSize(horizontal: false, vertical: true)`. Italic mixing per typeface spec §5:
ONE payload word/phrase max ("the boring hold *wins*.", "muscle changes the *math*.");
flourish-letter moments allowed but rare. Existing `italic:` arrays mostly comply —
audit each script for >1 italic run and trim to the payload. Never below 16pt serif.

**Body** — `Typo.body` DM Sans, `textPrimary`, left-aligned, lineSpacing 4. Body stays
OUT of the fact card: the card holds the number + source, the paragraph holds the story.

**Breath line** (intro pages) — keep, restyled: `Typo.body` italic-free, `textSecondary`,
one line, sits directly under body with `Space.sm`. No bubble, no animation.

**Fact card** (replaces the illustration slot) — the breathwork protocol card adapted:
- container: `white.opacity(0.55)`, 20pt continuous radius, 1pt `divider` stroke,
  `Space.md` padding, full width. NO accent border, NO offset shadow (this surface
  follows the dashboard's hairline register, not scrapbook chrome).
- row 1: the lesson's ONE number as a serif moment — `JeniHeroSerif-Italic` 28
  (`stickyNumeral` register): "3×", "66 days", "25%". Right-aligned on the same
  baseline: its unit/label, DM Sans SemiBold 14 `textSecondary` ("more burn at rest").
  Serif-numeral budget: max 1 per page (dashboard rule is 3 per viewport; lessons are
  sparser). Lessons without a clean number (day 9 kindness, day 14 begin-again) get
  no card — type-only pages are correct per Direction A's "teach beats stay
  typography-only".
- row 2: one-line takeaway, `Typo.body` `textSecondary`.
- row 3: citation line (§4).
- Direction A photo upgrade: when the 30-photo library exists, the card MAY gain a
  real-photo stamp (4:5, ≤40% card width, axis-aligned, 2–3px `#FFFAF8` halo) left of
  the numeral. Gated on the library; never stock, never AI. Until then: pure type.

**CTA** — `JFContinueButton` docked via `safeAreaInset(edge: .bottom)` (onboarding-v4
scaffold pattern; replaces the in-VStack pinned button). Labels lowercase:
"continue" mid-lesson; last page per §3.

Vertical rhythm top→bottom: topBar → `Space.lg` → kicker → 6pt → headline →
`Space.md` → body → `Space.md` → fact card → `Space.sm` → breath line → Spacer → CTA.

## 2. entry + page transitions

- **Open** (PlanView row → cover): fullScreenCover stays (slide-up is iOS-native and
  the cover is cream-on-cream, so it reads as a sheet of paper rising). Inside, the
  page content mounts invisible and enters with `Motion.pageEntrance` delayed by
  `Motion.pageGap` — the cover arrives blank-cream for ~60ms, then the page settles.
  Stagger kicker → headline → body → card with `Motion.cascadeTight` (0.06s).
- **Page turn** (continue / back): replace the `contentVisible` crossfade with
  `.id(pageIndex)` on the page container + `.transition(JFPageTransition.standard)`
  — exit easeIn 0.20s, 60ms silent gap, entrance easeOut 0.35s. `Haptics.light` on
  the tap, nothing on the landing.
- **Close** (X / done-without-workout): plain cover dismissal; no exit choreography.
  Workout handoff keeps the existing RitualToWorkoutSplash pink bridge timing.
- Reduce-motion: snap to final (existing gate pattern), JFPageTransition's opacity
  base already degrades safely.

## 3. last page + the receipt

The retention expert owns WHAT the last page does; this is how any version LOOKS.

**Last-page layout**: same anatomy as page 1 (kicker → headline → body), no fact card.
The headline is the identity line (existing scripts already end on identity copy).

**The receipt — quieter than breathwork's.** A lesson is 3 minutes of reading; the
receipt is a line, not a moment. On final-CTA tap, before dismissal/handoff:
1. the current page dot ticks from accent-ringed to plain filled cocoa (`Motion.tap`),
2. one line fades in under the headline area is NOT added — instead the CTA label
   itself confirms (see below). No checkmark draw, no scatter, no fireworks, no
   serif "done." card. One `Haptics.soft`. Total added dwell ≤ 250ms.
3. if the handoff path runs, the pink splash bridge proceeds as today.

**CTA states** (skinning whichever behavior ships):
- workout-handoff: cocoa pill, "start today's movement".
- plain done: cocoa pill, "done".
- **next-row chain** (if chosen): cocoa pill stays the primary; beneath it a quiet
  hairline row in the breathwork duration-link register — DM Sans Medium 13
  `textSecondary`, "next on your plan · log a meal", trailing chevron 12pt, no
  capsule, no card, 30pt height, full-width tap. Never two pills.

**Re-read mode**: identical visuals; final CTA reads "close", no dot tick haptic.

## 4. citation / evidence line

Precedent: the breathwork protocol card's citation. The register, verbatim:
- `DMSans-Medium` 11pt, `textSecondary.opacity(0.7)`, left-aligned, single line
  (truncate, never wrap to 3).
- lowercase, source + year + one qualifier, `·`-separated:
  `herman pontzer, duke · constrained energy model` ·
  `lally et al., ucl 2010 · median 66 days`.
- Lives as the LAST row inside the fact card, `Space.sm` above the card's bottom
  padding. Pages without a fact card put it directly under the body, same style.
- No links, no "studies show", no % confidence (uncertainty lives in the body's
  language per anti-shame rules). Max one citation per page.
- It is evidence furniture, not a flex: if a page's claim is common-sense coaching,
  ship no citation rather than a padded one.

## 5. wireframes

```
PAGE 1 — hook (day 4)                 PAGE 2 — fact + takeaway
┌─────────────────────────┐           ┌─────────────────────────┐
│ ‹      ● ◌            ✕ │           │ ‹      ● ◉            ✕ │
│                         │           │                         │
│ lesson four · the method│           │ real talk               │
│                         │           │                         │
│ the boring hold         │           │ stillness is            │
│ 𝑤𝑖𝑛𝑠.                   │           │ 𝑡𝑟𝑎𝑖𝑛𝑖𝑛𝑔.              │
│  (38pt serif, lineGap   │           │                         │
│   −19, left, 1 payload) │           │ body paragraph, DM Sans │
│                         │           │ 15, textPrimary, the    │
│ body paragraph. DM Sans │           │ story behind the number.│
│ left-aligned, the setup │           │                         │
│ for the fact.           │           │ ┌─────────────────────┐ │
│                         │           │ │ 𝟹×    more burn     │ │
│ first, one slow breath. │           │ │       at rest       │ │
│ make the exhale long.   │           │ │ one-line takeaway.  │ │
│   (textSecondary)       │           │ │ pontzer, duke ·     │ │
│                         │           │ │ constrained energy  │ │
│                         │           │ └─(white .55, 1pt     │ │
│                         │           │    divider, r20)──────┘ │
│ ┌─────────────────────┐ │           │ ┌─────────────────────┐ │
│ │      continue       │ │           │ │      continue       │ │
│ └─(cocoa pill, docked)┘ │           │ └─────────────────────┘ │
└─────────────────────────┘           └─────────────────────────┘

LAST PAGE — action (look only; behavior TBD by retention)
┌─────────────────────────┐
│ ‹      ● ●            ✕ │   ← dot ticks filled on CTA tap (the receipt)
│                         │
│ today                   │
│                         │
│ hold it ten seconds     │
│ longer than 𝑦𝑒𝑠𝑡𝑒𝑟𝑑𝑎𝑦. │
│                         │
│ identity body line.     │
│ short. then quiet.      │
│                         │
│         (no card,       │
│          no scatter)    │
│                         │
│ ┌─────────────────────┐ │
│ │ start today's       │ │
│ │ movement            │ │
│ └─────────────────────┘ │
│  next on your plan ·    │
│  log a meal          ›  │
└─────────────────────────┘
```

## 6. content/model deltas (for the implementing pass)

- `LessonPage`: retire `illustration` + `sticker`; add `factNumeral: String?`,
  `factLabel: String?`, `factTakeaway: String?` (citation field stays). Eyebrow
  copy survives as the kicker string.
- Audit all 14 scripts: one payload italic per headline, citations to the §4 format,
  fact numbers extracted from bodies into the card fields.
- Delete `lesson_d*` imagesets + `Resources/lesson_illustrations/` +
  `scripts/generate_lesson_illustrations.py` in the same change.
- `LessonID.coverIllustration` (Home card / re-read index art) is a separate surface;
  out of scope here but flag it: same dead-Grok-asset family.
