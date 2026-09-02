# 66 — ONE PRODUCT, ONE DESIGN SYSTEM

**feat/app-v2 · built 2026-09-02, after 65.** The founder's
convergence brief, with explicit bold-redesign authorization
("previous passes were too conservative; the current implementation
is not the specification"). Method: git state recorded (`6d4c266`,
clean, synced), three parallel inventory sweeps (the design-system
landscape · every Jeni-initiated surface · the consult's exact
choreography vs JeniActs), then the product walked on the QA sim —
Home, Move, the moment tiers ON FILM, the method note, the scan
chooser, Becoming, the letter, the evening arrival — before any
change. Every visual decision was made by looking at a render, and
the losing experiments were deleted with their verdicts.

---

## 1. THE CANONICAL SOURCE OF TRUTH (question 1 of the brief)

**Discovered, not invented.** The system already had one true code
home (`PlankApp/DesignSystem/Tokens.swift` + `Kit/`) and one true
law (`docs/design/00_JENI_DESIGN_LANGUAGE.md`) — what it had grown
was DEAD STRATA and unnamed dialects. The convergence:

- **The law document is THE source of truth**, now current: §4.1
  carries the speech grammar v2, §4.7 the two-register celebration
  engine, §5.2 the full action hierarchy, **§5.9 THE ILLUSTRATION
  REGISTER + §5.10 THE INTERRUPTION POLICY (new)**, §6 purged of ghosts (`JeniPage`, `JeniCard`,
  `JeniToolTile` rows removed; `JeniMoment` → the real
  `JeniMomentView`), and the migration log records this pass.
  `DESIGN.md` (the repo-root pointer) finally points AT the law —
  it never mentioned it.
- **~900 lines of provably dead kit deleted**, every deletion
  grep-verified across app + packages + widgets first: JKMasthead
  (143L) · JKBeatRow's view (its `JKBeatState` moved home into
  `BeatCompletion`, the authority that mints it) · JKPlateStrip ·
  the v2-era JKGallery + its `--debug-jenikit` route · JKChainLine ·
  JKCoachMark · JKCoachLine · JKStepsRing · JeniPage + JeniCard
  (zero shipping adopters — the four screens that stage arrivals
  own their flags directly; the v11 gallery inlines its own shell) ·
  LuxuryPressFeedback · TrainerButtonStyle (→ JKPress). Tokens.swift
  shed 7 dead Typo tokens, 6 dead Motion members, BreathingShadow,
  `pageIvory`, `frozenDay`, and 3 dead Space members.
- **A near-miss, recorded as law-of-the-trade:** `JKSilkSweep`
  greps dead by TYPE name and is live by MODIFIER name
  (`.jkSilkSweep` on Home). In a 2,000-line SwiftUI body a deleted
  symbol surfaces as *"unable to type-check in reasonable time"*,
  not *"cannot find"* — which is exactly how it hid. Restored;
  verify by both names before believing a zero.

## 2. THE CELEBRATION (the founder's most visceral complaint)

The p65 lifetime peak — "your record starts here." — was ~30 flecks
beside one word on an empty page. Filmed, it reads tasteful and
emotionally flat (`66_evidence/p65_baseline_peak_too_weak.png`).

**The bake-off** (`--debug-moment-gallery` + `--uitest-moment-fx`):
all six bundled effect Lotties were mounted ON the real moment page
and filmed. Verdict — every one lost: the glossy fireworks render
as a hot-magenta streak, the line-art pair last 0.58-0.75s
(blink-and-miss comps), confetti reads as a loading spinner at
comp scale, and every candidate is candy-pink (#FF3377-class)
against the dusty rose ramp
(`66_evidence/bakeoff_lottie_losers.png`).

**The winner is native: `JeniBurst.shower`** — a full-page volley of
the same torn paper: two corner cannons aimed inward + a center
lift, three pulses, flecks that rise past the headline and
flutter-fall at terminal velocity (closed-form drag physics, pure
in `t`), same deterministic LCG, same rose-ramp + ink palette
(`66_evidence/bakeoff_shower_winner_moment_tier.png`). Tier law by
construction, pinned in `JeniBurstShowerTests` (5 pins): spark —
NEVER a shower (several-times-a-day stays light); crest — 78 flecks
(`66_evidence/shower_crest_tier_proportional.png`); moment — 130.
The pop stays word-anchored and untouched (pinned). The losing
Lottie plumbing was deleted with the verdict. Recognizable
celebration language is sanctioned; stock assets for it are not,
because color truth, scale, determinism and honest Reduce Motion
all live in the native engine.

The temporal composition is one directed sequence: commit persists
→ page arrives → haptic + pop at the words + the sky fills → fact →
the standing CTA arrives on its own beat → continue → Home current.

## 3. THE SPEECH GRAMMAR v2 (why p65's reveal wasn't "speaking")

The consult study produced the exact delta: onboarding acknowledges
every thought against the thumb (`tick` per word at 0.09s throttle,
`land` at sentence ends), holds absorb dwells (`statementHold`
1.05s), and lands the input as its OWN event (`optionsDelay` +
`inputArrive` + the page re-seating). JeniActs had none of that —
a flat 0.55s metronome in silence, which is precisely "card +
opacity delay".

**`JeniActs.run` now speaks:** each THOUGHT lands with the grammar's
`tick`; the FINAL act — the decision, by the grammar's own "way out
arrives last" law — waits one extra absorb breath
(`actionPause = 0.30s`) and arrives silent: its motion says "your
turn". Tap-to-land stays silent (skipping a performance should not
applaud it); Reduce Motion still arrives whole. `FoodActs` mirrors
both constants and both behaviors, and the mirror is pinned from
BOTH sides (`JeniActsGrammarTests` + `FoodActsTests` — the
FoodThemeTests mechanism applied to time). Every acts surface —
evening close, reconcile, day-one card, method note, weekly read,
moment page, consent, questions offer — rides the upgrade with zero
call-site changes.

## 4. MOVE (the affordance evidence, rebuilt)

Before: one action mid-scroll wearing a mechanism riddle ("add what
health missed", left-aligned, 48pt), a chrome-less serif line for
the guided session, five tracked-caps labels, 6pt week specks that
film as dust, and an empty bottom half. After: **the onboarding's
action anatomy** — ONE standing `JFContinueButton` ("record a
session") bottom-anchored in the thumb zone on its own paper fade,
the guided door as its built-in secondary; the week marks at a
legible 9pt with their label folded into "your usual is N a day";
the record sheet's eyebrow speaks provenance ("recorded by you").
The screen now answers WHAT IS THIS / WHAT MATTERS / WHAT CAN I DO /
WHAT NEXT at a glance.

## 5. ONE PRIMARY ACTION OBJECT

§5.2 now names the full hierarchy (primary = the standing CTA,
big, thumb-zone; secondary = hairline capsule or the CTA's built-in
slot; quiet = text at the 44pt floor) — and the last two hand-rolled
ink pills on Jeni-speaking surfaces died: the method note's
serif-in-capsule (which broke the her75 CTA register lock) and the
letter's 4pt-short "reply" twin are both `JFContinueButton` now,
which gained `padded: false` for embedded columns and — found while
consolidating — **Dynamic Type on its label** (the app's most
important control carried the one fixed-size font).

## 6. THE INTERRUPTION POLICY (§5.10, new law)

The full inventory of Jeni-initiated surfaces was drawn (arbiter,
evening close, letter, weekly read, 21 method notes, day-one card,
three-questions offer, moment page, upgrade cascade, chain rows,
desk starters — file:line in the pass records). The policy the
inventory earned: an interruption must remind a today-action,
surface an insight she'd miss, ask for a missing fact in the value
shape (X → why → give → Y), or prevent a mistake — never
conversational filler; one interruption per arrival; each gated
once-per-day/once-ever by construction; **and every interruption
must discharge its reason**. The audit found the surfaces largely
already lawful (well-gated, record-triggered) with ONE real defect:
**a letter read BY HAND from the dateline never stamped its
day-key** — the unread dot stayed up and the same letter stayed
eligible to auto-present over her on the next arrival. Fixed
(`openLetterByHand` stamps).

## 7. THE BOTTOM CHROME (named since p59, finally closed)

p51's 14pt bottom fade only ever covered the home indicator while
the floating pill sits ~50pt above it — every filmed Home shot
showed raw ink through the bar's gaps. The ramp now covers the
pill's zone (safe+104, soft 5-stop curve) and scrollers rest 72pt
clear. **Tried and reverted:** a paper-filled bar via
`toolbarBackground` — iOS 26's glass pill ignores it; the pill's
own material is system-owned (the sim renders its blur poorly, the
device frosts properly — named for the device check).

## 8. DECIDED AND REFUSED

- **Every Lottie celebration candidate** — filmed, lost, deleted
  (§2). The films are the argument.
- **A paper-filled tab bar** — reverted on evidence (§7).
- **Typewriter text in-app** — the consult keeps its own register;
  in-app speech gets the tick + absorb + action-arrival grammar
  without per-character cost (repeat users wait for nothing).
- **Redesigning Home's dial/minis carousel** — walked, judged
  strong (p59's founder-steered design holds; the founder's own
  "don't redesign Home to demonstrate activity").
- **StripCellPress kept** — a 32pt cell needs its stronger 0.9
  compression; folding it into JeniPressable would erase a
  deliberate difference.
- **The PlankDesignSystem SPM extraction deferred** — the
  FoodTheme header's own TODO now has its third consumer (the
  widget), but the extraction is a package-graph + pbxproj move
  with zero user-visible payoff this pass; the mirrors are pinned
  by tests instead (FoodThemeTests, FoodActsTests). Named for a
  structural pass.

## 8b. THE STICKY ANATOMY + THE ILLUSTRATION REGISTER (founder laws, mid-pass)

Two laws arrived from the founder mid-pass and were built in:

- **Sticky actions** (§5.2): the big primary action pins at the
  bottom edge; the X/back pins at the top; content scrolls between.
  Applied: Move (already rebuilt that way), the method note (its X
  and CTA both used to scroll — restructured to pinned header /
  optical-center scroll / pinned decision block, filmed), the move
  record sheet (commit → safeAreaInset). The moment page, letter and
  evening close already complied.
- **The illustration register** (§5.9): `JeniDoodle` — the founder's
  hand-drawn doodle set (451 icons, already living in the product at
  chip scale on Home's task rows) at illustration scale (~140pt),
  ink-tinted template vectors drifting on a slow Lissajous motion
  path (RM still, VoiceOver hidden). Adopted: `JKEmptyState` gains
  the doodle slot; Move's two Health states carry `doodle-heart-beat`;
  the empty BOOK carries `doodle-dish` (filmed drifting). New assets
  follow the existing `doodle-*` imageset convention (vector,
  template).

## 9. ACCESSIBILITY

- Reduce Motion: the shower renders nothing (engine guard, shared
  with the pop); the moment page still arrives whole with words +
  haptic; acts still arrive whole.
- The standing CTA's label finally scales with Dynamic Type
  (capped by its 56pt frame + minimumScaleFactor — small sizes
  byte-identical).
- Move lost its AX-truncating joined caption (the label died; the
  baseline sentence wraps).
- Un-arrived acts stay un-hittable and hidden from VoiceOver
  (unchanged law, re-verified through the upgraded engine).

## 10. VERIFIED

- **plankAITests: 1659 total · 2 skipped · 0 failed** (p65's 1652
  + exactly 7: 5 shower-physics pins + 2 acts-grammar pins, first
  run, no reruns).
- **PlankFood: 291/291** (289 + the 2 FoodActs mirror pins).
- **Release BUILD SUCCEEDED.**
- Filmed/shot: the bake-off (6 Lottie candidates + baseline +
  winner at moment and crest tiers) · Move before/after · the
  method note on the standing CTA · the letter · the bottom ramp
  at three strengths · Home smoke after every sweep.

## 11. NAMED, NOT DONE

- **Physical device:** the pill bar's glass blur (sim renders it
  raw), the shower's texture at 60fps over real content, the
  speech ticks' feel (sim has no haptics).
- **The PlankDesignSystem SPM extraction** (three palette mirrors
  + the widget's unguarded WPalette want one home; the widget pin
  test wants the extraction first).
- **The haptic door count** (241 raw `Haptics.*` call sites vs the
  four-word `JeniHaptic` grammar — a mechanical migration with a
  sweep test, its own pass).
- **Spacing/type lint sweeps** (87% of `spacing:` literals are
  unnamed; 512 `.custom` fonts lack `relativeTo:` — the
  PresentationGrammarTests mechanism extends, one dimension per
  pass).
- Breath/session completion moments (p65's leftover, still open).
- The onboarding's `PressFeedbackStyle` dialect (13 sites on live
  auth screens) → JeniPressable, when those screens next open.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
