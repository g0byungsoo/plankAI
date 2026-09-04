# 78 — THE FINISHED PRODUCT

**feat/app-v2 · built 2026-09-04, after 77.** The question this pass
was given: would I actually want to LIVE in this app? Method: the
pass 77 screenshots studied cold, as a customer, before reading any
caption or code; convictions ranked by frequency × pain × trust;
then walked, changed, re-walked on the sim (walker-arm + the new
`dragxy`), at standard type and AX5. The adaptive expenditure model
was explicitly not the objective and was not built.

## 1 · The cold look (what the evidence said before any code)

Judged excellent and left alone: Becoming's rich top (hero trend +
dose seat + honest chemistry), the stall persona's flat-week read,
the sparse persona's dignity, Home's composed instrument, the year
lens's labeled dose seams, the weight page's era ledger.

Convicted:

1. **The weigh-in receipt was a prototype wearing the product's
   best engine** (77_evidence 09/10): a ~60%-height sheet whose
   whole content was one display-scale word — "done", or "fixed",
   a word nobody could parse (saved? repaired?) — with the actual
   morning verdict beneath it in caption type. Inverted hierarchy
   on the #1 daily loop, floating in dead paper. And the whole
   receipt auto-dismissed after 1.5s — the 15-word spike answer
   was gone before a person could read it.
2. **The regimen page led with the form, not the tool** (11/12):
   six facts a weekly user almost never edits stood above the
   standing (next dose · day N · pen whisper); the two EMPTY
   optional rows shouted their invitations in display serif,
   louder than the facts; "in the pen", "on it since" and "how
   it's sitting" cost comprehension to sound designed.
3. **The AX5 composition class**: editorial serif scaled unbounded
   — the page title alone ate a quarter of the AX5 screen before
   any fact arrived, values hit ~100pt, chevrons stayed 11pt.
4. The stall screen's trend card holds visible dead space (see §4).

## 2 · What shipped

① **THE WEIGH-IN RECEIPT, REBUILT** (`JKWeightRitual` kept beat).
The number just committed stays standing (cause and effect share
one frame — the phase swap reads as the room settling); a quiet
tracked-caps eyebrow receipts the action — **"saved"**, or
**"updated"** when correcting — and **the trend verdict is the
serif hero**: "your trend reads down about 1.6 lb this week." /
"this morning sits above your line. the trend still reads down…"
First/second weigh-ins keep their milestone sentences. The dwell
now scales with the words on screen (~3 wps, floor receiptDwell,
cap 3.6s, +1.5s at accessibility sizes) and **a tap anywhere lands
the exit early** (filmed: Home at +1.3s). Filmed: ordinary verdict,
spike morning (ruler dragged +2.7 lb via the walker's new `dragxy`),
fallback aphorism face, AX5 (evidence 01 02 06 07 12).

The ledger's past-day correction gains the same whisper — a
correction changes the fold, and the recomputed trend is the honest
payoff — with the spike grammar gated off: `WeighInReceipt.whisper`
takes `savedKg: Double?` and **nil means "never say 'this
morning'"**, because a past-day edit isn't this morning (a sentence
the old signature would have gotten wrong).

② **THE REGIMEN PAGE IS A DAILY TOOL** (evidence 03 04 05).
The daily read leads: "next dose · thursday, 6:00pm" + "day 2 of
your dose week" + the pen whisper stand directly under the title;
"log a side effect" is one direct row; the facts follow; the
ledgers stay in their p33 order. **An invite is not a fact**: an
empty optional row renders its ask at the quiet caption tier
(`door(_:_:invite:)`), so the two things a person hasn't filled in
are no longer the loudest objects on the page. Vocabulary: "on it
since" → **"started"**, "in the pen" → **"doses left"** (value is
the bare count — the pair used to say it twice; PenSupply pins
updated in-commit), "how it's sitting" → **"side effects"** at all
three sites (regimen door, dose sheet door, logger title), "the
symptoms" heading → "side effects". Walker repinned in-commit.

③ **THE AX5 CLASS: chrome yields, content scales.** Sheet-title
chrome caps at accessibility2 (the standing JFContinueButton
family) across the class — regimen, dose sheet, side effects, care
connection ×2 — so a title no longer eats a quarter screen before
the first fact; door chevrons ride `.caption2` and scale. The
facts, values and ledgers keep scaling in full. Refilmed at AX5:
the daily read now fits the FIRST screen (it used to be four
screens down). The kept beat's verdict gained `relativeTo:` (it was
fixed-size — invisible to Dynamic Type), `fixedSize(vertical:)`
(at AX5 it truncated its own numeral: "about 1.6 l…", the p70
word-shear class, caught on my own new surface by refilming), and
the p48-lite overflow scroll.

④ **THE RECORD SPEAKS TO EVERYONE.** No rendered surface carried a
gendered default, but the coach envelope's prompt strings and the
VISIT PACKET did: "by her account", "computed from her weigh-ins",
"she has no goal weight on file", "how she moves". The envelope
speaks they/their now; the in-app packet preview speaks second
person ("computed from your weigh-ins"); the print renderer speaks
its own clinical register ("the patient's weigh-ins", beside its
existing "patient-recorded"). The capture primer's "her answer"
(whose?) became "the answer". CLAUDE.md's voice law now carries the
rule.

⑤ **Chat: the send button gets a name.** The icon-only composer
control read as "sparkle" to VoiceOver on a core loop; it announces
"send" / "stop" now. And p77's unverified named-not-done is closed:
walked live end-to-end, "how has 1 mg been going?" comes back
quoting the era fold ("…over 8 weeks") from the p77 envelope
(evidence 08).

⑥ Walker-arm: `dragxy x1 y1 x2 y2` (point-to-point drag for canvas
controls — the ruler was unreachable by label commands).

## 3 · Walked and left alone / refused, with reasons

- **The Becoming lens as global temporal navigation** — walked all
  five ranges on the glp1 persona (evidence 09 10): month speaks a
  materially different sentence than week ("down 4.5 lb this month.
  about 1.1 lb a week."), year draws labeled dose seams, span
  labels stay honest ("6 months" on a 6-month record). Selected
  state unmistakable. Unchanged.
- **The insight pager's fixed shared height** (the stall film's
  dead space) — sized, then refused: the fixed frame is a
  deliberate no-reflow law (v16/p73), and with any figure card in
  the set a measured-max height equals today's height; the void is
  the shorter card's share of its tallest sibling's frame. A
  per-page hugging height would reflow the page beneath the swipe —
  the worse trade.
- **"kept", "landed", "holding", "the whole story", "the whole
  distance", "rhythm"** — each judged in place and kept: they carry
  their meaning ("kept" is a kept promise; "the whole story" sits
  under a card that just told the short one). The words that died
  were the ones costing comprehension ("fixed", "in the pen", "how
  it's sitting", "on it since").
- **"your next shot" (Home) vs "next dose" (regimen)** — left:
  "shot" is the injectable cohort's own word; "dose" is the page's
  generic register (orals live there too).
- **The weekly read** — re-seen mid-walk (evidence 11): the p77
  zero-grade fix stands (no "protein goal · 0 days" cell), the
  easing proposal carries the week. Untouched.

## 4 · Named, not done

- **The EF system prompt's register** (deploy-gated, founder):
  the live era answer still opens with "that's a solid progress!"
  (grading-adjacent praise), closes with an unnecessary question,
  and says "this dose has been effective for you" — a causal read
  the envelope's own timing-never-causality note forbids. The
  envelope outranks it on facts; the register fix is server-side.
- The composer's return key inserts a newline (vertical-axis
  field); send is the button. Native chat behavior — left, but
  named because the walker tripped on it twice across two passes.
- The kept beat at SE (small iPhone) — composition is
  center-stacked with the overflow scroll, lower risk than AX5
  (verified there); not separately filmed this pass.
- The adaptive expenditure model — still the biggest justified
  build (p77 §4's case stands). Its own pass.
- p70–p77 standing lists.

## 5 · Verified

- **PROOF: app 1704 · 2 skipped · 0 failed — the exact p77
  baseline (this pass repinned in place and added no tests:
  presentation, hierarchy and words; the frames are the proof) ·
  PlankFood 319/319 · Release BUILD SUCCEEDED.** Repins:
  `WeighInReceiptTests` 13/13 (optional `savedKg`, they/their
  modelLine) · `PenSupplyTests` 8/8 (bare-count row word) ·
  `Pass53RecordUITests` ("started").
- Films in `78_evidence/` (12 items): weigh-in ordinary / spike /
  fallback / AX5 / tap-skip, regimen standard + AX5 ×2, chat live
  era answer, lens month + year, weekly read as-met.
- Walked flows: weigh → save → verdict → dismiss (auto and
  tap-skip, standard + AX5) · regimen overview (standard + AX5,
  scrolled) · Becoming five lenses · chat one live question ·
  weekly read arrival + decline.

## 6 · The uncomfortable question

IF I HAD TO USE JENI EVERY DAY FOR THE NEXT YEAR, WHAT WOULD STILL
MAKE ME WANT TO STOP?

Honest answer, in order: **(1) The calorie/protein targets never
learn me.** A year of my own intake against my own trend is sitting
in the record and the target is still formula+pace; MacroFactor
users stay for exactly this compounding. It is the named,
founder-gated expenditure pass — the one thing here that a year of
honest use makes MORE valuable and Jeni currently wastes. **(2)
Chat's register** — on the twentieth "solid progress!! any specific
aspects you want to discuss?" I would stop asking Jeni questions,
and chat is where the connected record should shine; the fix is one
EF deploy away and it is not mine to ship. **(3) The morning loop
is now answered at the moment — but only for weight.** The dose-day
morning ("day 6, my candy thoughts are back — is that normal for
ME?") still answers in a weekly review and a pattern read a tab
away, not at the moment. The event-anchored position (p77) is the
seat to grow that from, with the same honesty gates.

None of (1)–(2) is fixable inside this pass's safety boundary;
(3) is the next pass-sized product question.

**No migration, no schema, no SQL, no deploy, no production
mutation. Chat/EF calls were the shipping read paths on the
standing QA account. NOT ARCHIVED, NOT UPLOADED, NOT SUBMITTED.**
