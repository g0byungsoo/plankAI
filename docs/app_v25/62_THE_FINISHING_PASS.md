# 62 — THE FINISHING PASS

**feat/app-v2 · built 2026-09-01, after 61.** The founder's brief:
take the app one meaningful level forward — end the quality variance,
make the whole product feel like ONE interaction system, pay down the
drift debt, hold the product before and after every change. Method:
the app WALKED first (driver walks across all four tabs, the record
surfaces, the regimen home, settings, the letter, the close, the
capture stage, the words door — before any code moved), three
parallel audits (market refresh · design drift · presentation
grammar), then decide → implement → film → iterate. Every visual
claim below is frame-caught; every behavioral claim is RED-proven or
pinned.

---

## 1. ONE DIRECTOR EVERYWHERE (the pass's biggest find)

**Becoming was the second, unreformed interaction director** — the
exact defect class p57/p61 removed from Home, still shipping one tab
over. The weekly read (the category's proven retention ritual, per
r6) scheduled itself from `refresh()` — which runs on every plate
log, body-scan change and scope tap — **stamped its once-per-week
flag AT SCHEDULE TIME**, and its +0.7s closure checked only its own
cover binding: open THE BOOK (or any of four sibling covers) and the
read died against the one-modal rule with its week already burned.
Worse, a plain tab switch INTO becoming scheduled **nothing** — a
due read routinely greeted nobody until she pulled to refresh.

Now: `BecomingAutoPresent` (pure, pinned 6/6) — arrival-only (tab
arrival · appear · foreground while visible), ONE settle beat
(`HomeAutoPresent.settleBeat`), **stamp on actual present**,
materialize like its siblings (the read used to SLIDE while every
other moment materialized — the p61 cover grammar, completed).
"read the whole week" stays the mid-session door; a blocked winner
keeps its week.

**PresentationGate became an owner SET** (shell · home · becoming).
Becoming's five covers and the scan chooser used to occupy the
one-modal slot invisibly — Home's reconcile could burn its
per-session flag into an open BOOK. Every cover owner raises the
gate; every director asks "anyone up besides me?". Home publishes
its own occupancy; MainShell adds the chooser. Gate pinned 2/2
(tested through the singleton — a MainActor class deinit aborts on
the 26.2 sim, the recorded gotcha, re-confirmed live when the first
run crashed the runner into the `Executed 0 tests` trap and was
caught by the case listing).

The timing lived in view bodies (the §36 lesson: no seam, no honest
RED) — the pure extraction IS the fix; 16/16 pins hold the law.
Filmed: a tab arrival presents the read after one settle beat.

## 2. THE GRAMMAR CROSSES THE PACKAGE BOUNDARY (p61 §8, closed)

The food rail's three hand-rolled sheets (ingredient editor · repair
editor · gallery/error pair) rendered with the SYSTEM corner radius
and background — one visible step off every sheet in the app — on
three heights no token names (0.72 · 0.66 · `.medium`, the detent
`JeniSheetHeight` exists to abolish). `foodSheet` (FoodTheme.swift)
now mirrors the app fold's four properties exactly; all five
presenter sites converge on `tall`/`brief`; the two system
controllers stay exempt by the sweep's own rule.
`PresentationGrammarTests` walks `Packages/PlankFood/Sources` too —
it went honestly RED on the share-activity presenter (the package's
wrapper is `ShareActivityView`, a name the marker list didn't know)
before green. Filmed: the ingredient editor at `tall` fits its grid
and all three actions, wearing the app's chrome.

## 3. ONE COMMIT BEAT · ONE RECORD HAND · TOKENED CASCADES

- `JeniMotion.commitDwell` (0.45) + `receiptDwell` (1.5): four
  hand-picked values made the same commit-then-close gesture at four
  speeds (dose sheet 0.45 · letter seal 0.45 · weekly-read decline
  0.35 · program commit 0.4 · weight ritual 1.5). The weight
  ritual's longer hold is now a NAMED beat — a receipt she reads —
  not an outlier.
- The p58 one-hand law reached the two record commits it missed: a
  strength session ("record it" spoke the hero swell) and a symptom
  (spoke `land`) now speak `JeniHaptic.record()`.
- `UpgradeMomentView`'s hand-rolled four-dialect reveal cascade
  became the kit's `arrive` + `stagger` (CTA usable at ~0.4s, was
  1.15s — ceremony on a commerce surface).

## 4. THE UPGRADE COVER LEARNS TO SCROLL (frame-caught, before/after)

The one commerce surface with no scroll container: at AX sizes the
old cover clipped BOTH edges with the X and CTA unreachable
(filmed). Now: the p54 min-height ScrollView law (composition
byte-identical at standard sizes), the card's four `.fixedSize()`
runs allowed to wrap, columns stack from accessibility sizes (the
p33 law), the CTA capsule grows instead of clipping. **The iteration
loop caught two of my own regressions:** freeing the price to wrap
let the SE break "$29.99" mid-number ("$29." / "99") — a price never
breaks; it keeps `fixedSize` + layout priority and the prose wraps
instead; then the unbreakable price row at AX5 re-widened the SE
page — the display price stops growing at AX2 (the badge's own
pattern). Filmed: SE standard · SE/AX5 · 16/AX5, all inside the
screen, all scrollable.

## 5. THE DRIFT DEBT

- **One masthead scrim law** (`jeniMastheadScrim()`): Home and
  becoming each hand-rolled a 54pt linear fade whose decay left the
  clock over ~40% opacity — becoming's scrolled serif read straight
  through the status bar (frame-caught: "sodi" behind the clock).
  Solid paper through the bar, then the decay; both converge;
  refilmed clean.
- **The close's fold lines get the paper fade** (frame-caught: the
  last chip row sat half-clipped against the goodnight capsule; a
  scrolled hero sliced sharp under the pinned eyebrow — "on file."
  read as "on tile."). Both fold lines dissolve now.
- **`Radius.tile = 16`** (+ FoodTheme mirror): the one shape with no
  name, typed raw 28 times across nine surfaces. Plus the mechanical
  pass: every raw `cornerRadius` literal that already had an exact
  token (22/18/14/13/8/24) now says the token's name — 38 files,
  zero visual change by construction. `20` deliberately left:
  `programCard` is program-scoped semantics.
- **One contact shadow, callable** (`jeniContactShadow()`): the chat
  bubbles' double-layer stack (the texture §6.1 killed), the beat
  row's hard-offset `.black` one-off, and the gauge tip's colored
  halo (§6.1: glow is dead) all converge. Home refilmed — the dot
  separates by fill alone.
- **~976 dead lines left**, grep-proven first: LastNightSleepCard
  (558L, reachable only from two DEBUG harnesses; its header still
  cited tiles p61 deleted) + both harnesses + routes; JeniMoment
  (203L, ZERO call sites while design-law §6.5 instructed future
  work to use it — **the law now records the component's death and
  keeps the LAW**); LabReadoutRow/Block (DEBUG gallery only).
  **Stickers.swift left alone — the audit called `StickerStyle` dead
  but `Sticker` carries it live** (the audit-overreach lesson).
- `scrollDismissesKeyboard(.interactively)` on the nine text-entry
  surfaces that lacked it.

## 6. WORDS AND TRUST

- becoming's "not enough to read yet" header contradicted the rows
  beneath it (weight 163.6 lb, body fat's band, right under a claim
  of nothing to read — engine language for "no TREND yet"). Now
  **"still filling in"** — true for a trend that needs days, a
  connection not made, an estimate awaiting a measurement.
- **A repeated identical edit note prints once.** The standing QA
  plate carried "had half of it" TWICE — one repair per walk
  session, each appending the identical sentence verbatim
  (`updateEntry` merged without dedup). RED 1/1 with the exact
  doubled list from the film, then GREEN; order and every distinct
  statement survive, and the numbers still carry the arithmetic
  (half of half = 265, pinned in the same test).

## 7. DECIDED BY LOOKING, REFUSED ON EVIDENCE

- **RegimenSheet's 55-magic-spacing normalization (p61 §8):
  REFUSED.** Walked with the GLP-1 seed and filmed — the surface
  reads clean and coherent (facts as doors, serif values, one
  register). Re-typing 55 numbers to move rows ±2pt is invisible
  churn with regression risk on a daily GLP-1 surface.
- **The reveal chain's 49-spacing pass (p61 §8): DEFERRED, named.**
  The conversion surface the founder loves, with no conversion
  funnel evidence to steer by; p61 already converged its chrome and
  type. Film-first when it's opened.
- **The clinical family's underlined text links: NOT drift.** 16
  sites, consistent within one family (regimen · dose · care); the
  design law is silent; converting is a taste re-decision, not
  repair.
- **VisitPacket's system fonts: NOT drift** — they live in the PRINT
  renderer (white paper, print sizes), the PDF a clinician receives.
  The audit misread the print body as a screen surface.
- **ScanChooser's heavier shadows and third vessel: deliberate**
  (elevation over camera blur; materialize layer with X + scrim
  exits, graded by size).
- **The letter's ActivationHaptics seal and ~1.9s door arrival:
  left** — the felt signature and the reading rhythm are design, on
  the product's most-loved surface.

## 8. MARKET RESEARCH (Sept 2026, refreshed)

The category's year was trust self-destruction: MFP's diary redesign
crashed its rating 3.24→1.54 and drew a class action; Lose It doubled
price and gated macros. **The law extracted: never relocate the
record, never add taps to the core loop.** MacroFactor is the
counter-model (adaptive engine over her own data). Shotsy leads GLP-1
(~1M installs) with free provider PDF export and ONE monetized thing —
the medication-level curve; the most-quoted review connects that
curve to food-noise timing. Liquid Glass stalled (iOS 26 ~15-18%
adoption; Apple shipped a tone-down) — Jeni's twice-recorded refusal
is market-validated. **Flags for founder thought** (not built; two
touch settled law): a drawn her-own-pattern cycle rhythm (the PK
refusal stands; the honest substitute is HER pattern, not the
drug's), one-tap food-noise logging against shot day
(`foodNoiseReturn` exists; a door doesn't), the maintenance era
(two-thirds regain; only Shotsy has one), oral-era grammar parity,
self-serve packet reachability (verified: already reachable without
a care connection).

## 9. VERIFIED

- **plankAITests: 1592 · 2 skipped · 0 failed** (p61's 1584 + 6
  BecomingAutoPresent + 2 PresentationGate, exact).
- **PlankFood: 289/289** (288 + 1 dedupe, RED→GREEN).
- **PlankSync: 29/29.** **Release BUILD SUCCEEDED.**
- Walked before AND after on film: Home entry · becoming (scrim,
  header, weekly-read arrival) · THE BOOK · the plate page · the
  repair loop → ingredient editor (new chrome) · weigh-ins · the
  regimen home (GLP-1 seed) · settings · the evening close
  (rest + scrolled, fold fades) · the capture stage · the words
  door → stated plate (absent macros print "—") · the upgrade cover
  (16 · SE · SE/AX5 · 16/AX5).

## 10. NAMED, NOT DONE

- The two motion vocabularies (`Motion` 181 sites vs `JeniMotion`
  98, plus V8Motion and FoodMotion) — the split is by era, not
  intent; this pass converged the surfaces users feel daily (the
  reads, the dwells, the upgrade cascade). A full migration is its
  own mechanical pass with film gates.
- The reveal chain's deeper spacing pass (§7 above).
- Two-device food pull / offline retry queue (pre-existing,
  tombstone-migration-gated since p37; do not half-ship).
- The book's swipe actions / undo-on-relog (delete lives one tap
  deeper on the plate page today).
- Research flags in §8 for founder thought.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** The standing QA identities
were reused for every walk; no sim erases.
