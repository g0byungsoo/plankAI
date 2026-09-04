# 79 — THE LEARNED BURN

**feat/app-v2 · built 2026-09-04, after 78.** The brief: the record
should compound — "what can Jeni know after months that it could not
have known on day one?" — while the design keeps evolving. Method:
four fresh research lanes run in parallel BEFORE any decision
(adaptive-expenditure systems · GLP-1 lived dose-weeks · competitor
friction 2026 · iOS motion/interaction benchmark; all four reports in
`79_evidence/r1–r4`), then a cold walk over the seeded personas, then
the builds the evidence demanded. One founder steer landed mid-pass
(the weekly read's poetic register) and was taken immediately.

## 1 · What the research established

- **r1 (adaptive targets):** build it as an adaptive READ, never a
  restriction engine. MacroFactor's validated shape: back-calculate
  expenditure from logged intake minus trend-weight change; targets
  move only at consented check-ins; accuracy dies below ~90% logging
  completeness — partially-logged days are the poison. Named failure
  modes: the under-logging death spiral, expenditure-drop panic,
  target whiplash, dose-change straddle. **The GLP-1 × adaptive
  expenditure intersection is unoccupied in the market.** The one
  version that must never ship: a system that ratchets an
  already-under-eating medicated customer's target downward.
- **r2 (GLP-1 daily life):** the dose week has a universal shape
  (day 1–2 landing, quiet middle, day 5–7 waning when appetite and
  food noise return) and people learn their own pattern. The #1
  moment-anchored question is the waning morning: "why am I so
  hungry — is it failing?" Competitors answer with population PK
  curves; the differentiated move is to speak HER OWN recorded week
  at the moment she's living it.
- **r3 (competitor friction):** MFP's 2026 paywall relocation is
  litigated; AI photo logging survives only as "an estimator, not a
  verdict"; long-tenure users stay for honest adaptive reads
  (MacroFactor), psychological smoothing (Happy Scale), and speed —
  never streaks or coach personas.
- **r4 (design benchmark):** the motion/haptic checklist is mostly
  already embodied here (ruler detents, numericText everywhere, one
  motion voice, RM substitution). The practitioner bar that decides
  "finished vs prototype": instant first-frame response,
  interruptibility, and NO content teleporting.

## 2 · What shipped

① **THE LEARNED BURN** — the record finally learns the person.
`ExpenditureRead` (pure, 16 pins): a 21-day window over the ONE
canonical trend fold (`WeightWeekReadEngine.trendSeries` — no second
smoother) against her logged day intakes. Band output only
(±150/200 by data density, 25-kcal rounding). Gates, every one a
named silence: established trend sufficiency · ≥9 weigh-in days in
window · ≥14 usable logged days with no rolling week under 4 ·
fragments excluded by HER OWN median (never an absolute calorie
judgment — on this cohort a small day is the medication working) ·
a dose-era boundary younger than the p74 titration floor HOLDS the
read ("early to read at this dose") · numeric suppression ⇒ silent.
**The death spiral dies structurally:** a computed burn below
~0.9×BMR means the record contradicts the scale, and the read goes
silent instead of confidently low — so it can never ratchet an
under-eater downward. `ExpenditureReadAssembler` is the one live
assembler (three consumers, one fold — the p51 lesson).

② **THE TARGET LEARNS ONLY BY CONSENT** —
`WeeklyReadOffer.energyRecalc` (11 pins): implied target = observed
burn − the deficit her own pace implies; the offer walks toward it
in bounded steps (≤150 kcal/week, cumulative ±400, 75-kcal
materiality), each step proposed at the weekly read with its cause,
declinable, cooldown-respecting. **Eating MORE is a first-class
direction** (filmed: "daily energy: 1,694 · your record reads your
burn higher than the plan assumed. eating a little more still holds
the pace you picked." — the fastloss persona). The down direction
carries two extra refusals: never for the medicated cohort (the
count-up law), and never when logged intake already sits under the
target (a lower ceiling for someone under the ceiling is a ratchet,
not a fit). An accepted step writes a device knob
(`plan.energyAdjustKcal` — deliberately NOT a new ProgramFactKind:
the server's kind CHECK would 400 until a founder migration; the
knob re-derives weekly, is identity-swept by the standing `plan.`
prefix, and TargetsService re-applies max(1200, BMR) after it, so
the learned number obeys the same floor as the formula it corrects).
The one-target law holds by construction — Home, the plan sheet and
jeni's envelope read the knob through the ONE function
(OneTargetEverywhereTests +1).

③ **THE SEATS.** Becoming gains the YOUR BURN card (dose-seat
grammar: eyebrow pair · serif band · derivation caption — "1,225 to
1,625 · learned from 15 logged days against your weigh-ins"),
rendered ONLY on an established read; not a door (a detail page
would be an algorithm dashboard — refused). The plan-numbers sheet
carries the receipt when a step is applied: "your target runs 150
kcal above this equation. that's the step you accepted at a weekly
read…" — "why did Jeni change this?" always has an answer.

④ **THE FELT WEEK REACHES THE MORNING** (r2's #1). The morning
read speaks the waning open, once per cycle, on its first day:
"day 6 of your dose week. appetite often comes back in this
stretch." — and when her own record holds the food-noise signature
(≥3 clustered cycles, the E2 arithmetic now exposed as
`foodNoiseSignature`, one arithmetic two speakers), it speaks HER
pattern: "food noise has come back near day 6 in your last cycles."
Never a verdict on the medication, never "the next shot fixes it"
(banned-word pinned). **Ladder position walked, not assumed:** the
first film showed the daily trend receipt starving the clause
forever (it fires every losing morning); the once-per-cycle moment
now stands above the routine receipts, below safety flags and the
once-ever first-down-week (DoseWaningBriefTests 7 pins; filmed on
the new `glp1waning` persona — evidence 08).

⑤ **THE WEEKLY READ SPEAKS EVERYDAY ENGLISH** (founder steer,
mid-pass: "so many poetic, non-straightforward language"). The
riddle headline died — "arriving on support, reviewed." →
"here's how your week went." (the week NAME survives on the
journey's signed cards, where it is memory, not instruction);
eyebrow "your week, read" → "the weekly read"; "nothing needs a
reset." DELETED (it doubled the hold offer's own "nothing needs to
change this week." in poetry); "the week's shape:" label dropped;
"N of M doses carried it" → "doses logged"; the last two shipping
"protein floor" titles → "protein goal" (the p67 ruling's
survivors). Before/after: evidence 06/07.

⑥ **TWO TRUST FIXES ON THE CORE FOOD LOOP** (cold-walk finds,
filmed as-found — evidence 03/04):
- **The reading's protein lead printed "0 g"** for a stated plate
  whose protein was never stated — the page's largest numeral
  testifying to a statement she never made (`totals.protein` folds
  nil→0; the set table refused the same zero since p69). The plate
  page's own p70 law now applies pre-commit too:
  `SnapResultMath.proteinMeasured` gates the lead; unmeasured →
  the set table's kcal cell leads, nothing said twice.
- **StatedPlate filed "…avocado, maybe"** — the hedge words people
  actually type ("maybe/probably/i think/like/say/…ish") belong to
  the number, not the dish; the qualifier vocabulary consumes them
  and the kcal stays hers verbatim (PlankFood +2 pins).

⑦ **THE RITUAL'S SAVE KEEPS ITS NUMBER** (motion, filmed RED first).
The weigh-in save was a two-subtree phase switch: filmed at 15fps,
the sheet stood fully BLANK for ~3 frames and the number she had
just committed vanished, then re-faded in a new seat — the exact
"content teleporting" class r4 names as the prototype tell, on the
product's #1 daily loop. `JKWeightRitual` is ONE column now: the
readout never leaves the tree — on save it travels to center as the
entry chrome dissolves and the verdict fades in beneath the standing
glyphs (evidence 09 before / 10 after, frame strips). The refilm at
AX5 caught my own follow-on bug (the entry's retained scroll offset
clipped the standing numeral) — fixed with a scroll-to-top at the
phase change, refilmed whole (evidence 11). RM path: instant swap,
by construction.

⑧ **QA infrastructure that makes personas honest:** every seeded
persona now OWNS ITS WHOLE BODY (height, start/goal, cohort keys —
the QA account's rotating identity had made persona walks
nondeterministic: the same launch sometimes had a calorie target and
sometimes none, the p77 class). New film variants: `fastloss` (the
record that honestly earns the energy up-offer) and `glp1waning`
(dose anchor at day 6). New DEBUG door `--debug-burn-dump` writes
the read + proposal decision to the app container for host-side
diagnosis.

## 3 · Refused / deferred, with reasons

- **A burn detail page** — the card IS the whole statement; a tap
  into windows/coefficients is the algorithm dashboard the brief
  forbids.
- **`navigationTransition(.zoom)` for Becoming's tile flights** —
  the hand-built in-tree morph was filmed and refined across
  v11.5–p76; replacing a walked-good system for API modernity is
  churn, not evidence.
- **Auto-applied expenditure targets / continuous drift** — the read
  moves daily; the TARGET moves only through consented weekly steps.
  This is the load-bearing trust split (r1) and it is structural.
- **A new `energyAdjust` ProgramFactKind** — the server CHECK gates
  new kinds behind a founder-applied migration; shipping the client
  first would fail-and-retry sync for every acceptor. Device-scoped
  v1 loses at most one accepted step, which the next read
  re-proposes from the same record. Migration drafted mentally, not
  smuggled; founder call.
- **Cohort framing on the burn card** (a medicated customer's
  honestly-low burn could read as "my metabolism is broken") — the
  card states the number plainly; interpretation lives where
  interpretation lives (the read, the Method). NAMED for founder
  judgment rather than decided in an autonomous pass.
- **Renaming the WeekIntent names product-wide** — they left the
  read's headline (the founder's steer); on journey cards they are
  frozen memory and were left.
- **Weight-number milestones** — re-refused (p63 founder law;
  p77's reasoning stands).

## 4 · Verified

- `ExpenditureReadTests` 16/16 · `WeeklyReadOffersTests` 23/23
  (11 new energy pins incl. the medicated/under-eater refusals and
  the ±400 rail) · `OneTargetEverywhereTests` 7/7 (the knob moves
  all three readers inside the safety rails) ·
  `DoseWaningBriefTests` 7/7 (banned-register sweep included) ·
  `WeeklyReadE2Tests`/`WeeklyReadComposerTests`/`WeeklyReviewTests`
  repinned in-commit for the register rewrite · PlankFood
  StatedPlate/SnapResultMath +2.
- Films (79_evidence): burn card in situ (05) + AX5 (12) · energy
  offer face (07) · waning letter day 6 (08) · reading absence law
  before/after (03/04) · ritual save frame-strips before/after +
  AX5 (09/10/11) · the read register before/after (06/07) · burn
  dump values (quoted in §2②: read 2,500–2,800 @ 19 usable days,
  offer +150 → 1,694).
- **PROOF: app 1739 · 2 skipped · 0 failed (p78's 1704 + exactly 35:
  16 ExpenditureRead + 11 energy-offer + 7 dose-waning + 1
  one-target-knob) · PlankFood 321/321 (319 + 2) · Release BUILD
  SUCCEEDED, verified on the result line itself (the first check
  greped flag noise — the standing `Executed 0 tests` trap in
  Release clothing, caught by re-running for the line).**

## 5 · The final questions

**If she uses Jeni for another six months, what improves because
Jeni remembers the previous six?** Now, concretely: her calorie
target stops being a formula's guess — the weekly read walks it
toward what her own plates and weigh-ins prove, in steps she
approves, and the plan sheet can always say why. Her dose-week
morning knows her own food-noise day. The trend verdict, the era
ledger, the burn band, and the chat envelope all speak from the one
fold that only gets sharper.

**Strip the motion, haptics, typography — still exceptionally
useful?** Yes: trend verdict at the weigh-in, learned burn, protein
adequacy, consented target steps, the dose ledger and felt week.
**Restore them — more human and understandable, not just
decorated?** The save now literally keeps her number under her
thumb; the read speaks kitchen English; the ruler ticks under her
finger. Both answers are yes, and both are newly truer than at p78.

## 6 · Named, not done

- The energy offer's ACCEPT walked live end-to-end on the sim (the
  knob write + target move are unit-pinned; the accept tap ran only
  through the offers suite, not a filmed walk).
- The intake-inconsistent silence deserves its ask surface (r1's
  "you didn't log tuesday — did you eat that day?" pattern) — v2 of
  the learned burn.
- The dose-day morning clause (r2 #2/#9: shot-day site recall and
  the week's receipt) — the felt week shipped its #1 moment only.
- Maintenance-mode proposals (the knob applies; proposals are
  deficit-only v1).
- SE films of the new surfaces (AX5 verified; SE is the lower-risk
  composition, the p78 note).
- The EF system prompt's register (deploy-gated, founder; standing
  since p77).
- p70–p78 standing lists.

**No migration, no schema, no SQL, no deploy, no production
mutation. NOT ARCHIVED, NOT UPLOADED, NOT SUBMITTED.**
