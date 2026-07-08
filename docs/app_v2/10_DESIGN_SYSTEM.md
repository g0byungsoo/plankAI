# 10 — Design system direction: JeniKit

## What "the onboarding feeling" actually is

Deconstructed from the OV5 module (not vibes — mechanics):

1. **Hairline discipline.** 0.33pt rules at 12% cocoa separate
   content; borders are 0.66-1.5pt or absent. Elevation is rare and
   soft. Cards are the exception, not the default — LISTS ARE RULED,
   NOT BOXED.
2. **Two-beat entrance.** Headline rides the page dissolve with a
   6pt settle; everything else arrives as ONE unit at +0.34s
   (ov5Beat1/2). Never per-element bloom spam.
3. **The cross-off.** Deciding = a 1.5pt strike drawn left-to-right
   with capped tick haptics. v2 makes this the app-wide completion
   gesture (plan beats strike when done).
4. **Serif hero + italic punch.** One serif moment per screen
   (JeniHeroSerif), italic on 1-3 load-bearing words, -0.4 kerning,
   negative leading. Numbers: serif for heroes, DMSans tabular for
   support (founder: no italic numerals).
5. **Receipts.** Data mirrored back as quiet-cause (caption) →
   consequence (serif italic) hairline rows. v2 uses this grammar
   for day receipts, chat action cards, migration beats.
6. **Cocoa capsule CTAs**, 56pt, one per screen, docked over a
   gradient dissolve. Secondary actions are text, not buttons.
7. **Kicker eyebrows** (tracked uppercase 10pt) as page furniture;
   trust lines with lock glyphs for sensitive moments.
8. **Persistent atmosphere.** Background + chrome never re-animate;
   only content swaps (JFPageTransition).

## JeniKit inventory (`PlankApp/DesignSystem/Kit/`)

Prefix `JK`. All reduce-motion gated, all Dynamic-Type aware, all on
the 8 locked tokens. New components only where OV5 has no equivalent:

| Component | Job |
|---|---|
| `JKScreenChrome` | cream + optional PaperGrain, masthead slot, kicker |
| `JKMasthead` | day pill (serif italic) · date eyebrow · quiet marks |
| `JKBeatRow` | plan row: 44pt photo/sticker matte · title/sub · state circle; completed = strike + 38% fade (OV5SelectRow grammar, non-interactive strike) |
| `JKStateCircle` | the 26pt cross-off circle (empty/done/auto states, drawn check) |
| `JKProteinArc` | 96pt open arc gauge, serif numeral, target tick, cohort note slot |
| `JKStepsRing` | ring + tabular numeral (reuses existing iridescent shader on detail) |
| `JKPlateStrip` | horizontal 56×70 plate thumbs + [+] tile (photo-first) |
| `JKCoachLine` | jeni voice line: ItalicAccentText + optional chat chevron, breathing shadow |
| `JKReceiptRow` | the OV5 receipt row generalized (lead caption · punch trailing) |
| `JKSheetChrome` | unified sheet: cream, grabber-less, serif title, hairline sections |
| `JKEmptyState` | editorial empty: one serif line + one action, never an illustration dump |
| `JKTabBar` | 3 labels, active = serif italic + matched-geometry dot, haptic |
| `JKActionCard` | chat tool card: hairline capsule, confirm/cancel pills |
| `JKStreamText` | streaming text: word-fade commit, cursor shimmer while live |
| `JKChainLine` | the module-exit "next:" suggestion row |
| `JKCoachMark` | first-run captions: caption + 0.75pt hairline pointer, one-shot |
| `JKConfirmPill` | small paired yes/no pills (OV5StatementYesNo grammar) |

Reuse, not rebuild: `ItalicAccentText`, `JFContinueButton`,
`JFPageTransition`, `PaperGrainBackground`, `BreathingShadow`,
`Haptics`, `PressFeedbackStyle`, OV5CitationChip (promoted to
`JKCitationChip` alias), snapSweep/inkBleed/grain shaders, Lotties.

## Motion + haptic grammar (app-wide law)

- Screen swap: JFPageTransition.standard; tab swap: crossFade + soft.
- Content entrance: two-beat only (jkBeat1/jkBeat2 — port of
  ov5Beat, shared file so the cadence is literally the same code).
- Completion: strike 180ms + tick cascade (≤4) + one soft success.
- Numbers: easedFinal roll + perceptualLag after their visual.
- Ambient: breathing/chipPulse only — max ONE ambient loop per screen.
- Sheets: no springs on present; gentleSpring on drag-release only.
- NEVER: bounce on tap, parallax, per-character animation, skeleton
  shimmer (loading = quiet caption or nothing).

## Anti-slop checklist (every screen is audited against)

no gradients as decoration (gradients exist only as CTA-dock
dissolves + photo scrims) · no SF Symbol as hero art · no emoji ·
no drop shadow >0.06 opacity · no full-width bordered card stacks ·
no three-stat rows without hierarchy · no default List/Form chrome ·
no navigation title bars (mastheads instead) · empty states carry a
next action · every screen has exactly one serif moment · every
number is tabular or serif-hero, never both sizes adjacent.

## The plate catalog (journal reskin direction)

Food history stops being rows: day sections become spreads — date as
kicker, plates as a 2-col photo mosaic (photo 4:5, kcal as a quiet
white pill on-photo, title serif beneath, protein as the ONLY macro
shown at rest). Tap → existing matched-geometry detail. Text-only
entries render as cream "recipe card" tiles (serif title on paper
grain) so they hold the grid without grey-icon deadness. The macro
`p·c·f` line appears only inside detail. This is "magazine catalog,
not spreadsheet" made concrete.
