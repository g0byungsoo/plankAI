# E3 ONE JENI — evidence (the loop's record)

2026-08-11 · what is PROVEN, how, and what remains. Architecture in
`12_E3_ONE_JENI.md`; the decision and its falsification conditions in
`11_E3_DECISION.md`. Frames are session-ephemeral by standing law; the
observations here are the durable record.

---

## 1 · PROOF LEDGER

### PROVEN IN TEST — 809/809 app (+26, zero regressions at every gate)

New suite `JeniToolsTests` (26 pins):

- **honest emptiness**: every read on an empty record returns
  `have:false` WITH a reason; an unlogged day carries no `kcal_total`
  at all and its refusal repeats S3's law verbatim; an unknown read is
  inert.
- **day resolution**: `weekday` never lands on today or the future
  (asked about friday ON a friday, "last friday" is the only honest
  reading); `days_ago` bounded 1…60 and beats `weekday` when both
  arrive; no argument resolves to nil rather than to today.
- **the authority law through the new door**: a prescribed head
  refuses, routes, and leaves **no chat-authored row underneath it**;
  an accepted proposal lands `preferred`; the stored (clamped) value is
  what gets reported back; proposals are user-scoped.
- **value coherence**: a word where an int belongs, a vocabulary word
  from the wrong kind, `proteinAdjust`, `movesAdjust` and `readAnchor`
  all refuse.
- **memory redlines**: doses, brands, diagnoses, symptoms, body
  judgements, ED language, and app-owned numbers all refused; a refused
  note leaves the store empty AND tells jeni not to claim otherwise;
  legitimate notes accepted; restatement supersedes; duplicates
  collapse; topics stay bounded; forgetting is real; user-scoped;
  envelope verbatim.
- **the standing floors at the new surface**: numeric suppression
  strips kcal/weight from every read (plates included); no read returns
  a drug brand name.
- **drift guard**: catalog and router are one list; every tool has a
  wire form with a schema; no tool description or card label carries an
  em-dash; every state-changing tool asks first.

### PROVEN IN SIMULATOR (QA-iPhone16, frames inspected)

1. **The read loop.** `--uitest-chat-read weight` on a seeded account:
   "am i actually losing?" → typing bubble with **"reading your trend"**
   beneath it → *"not enough weigh-ins to call a direction yet. the
   line needs a few more mornings."* **This is the era's most important
   frame.** Asked the question a weight-loss app exists to answer, jeni
   went to the real `WeightWeekReadEngine`, found `sufficiency ==
   insufficient`, and refused to state a direction. The provenance law
   survives into conversation.
2. **Reads that have data.** "what did i eat yesterday?" → *"yesterday
   you logged 5 plates, about 3,265 calories and 206g of protein."*
   "how was my week?" → *"you logged on 7 of the last 7 days, averaging
   133g protein on those days."* First time in the product's history
   that jeni has answered a question about a past day from the record.
3. **THE COMPOUNDING LOOP, closed end to end.** "can you make my step
   goal 6000?" → "your call. want me to make it official?" → card
   *"make your step goal 6,000?"* → yes → "done. that's yours now." →
   **relaunch** → Today composes **"6,000 steps · 2,100 steps left ·
   about 20 minutes"** as a real checklist row. A sentence changed
   tomorrow.
4. **What jeni remembers** (`--debug-jeni-memory --uitest-seed-memory`):
   hero, four hairline sections named as sentences, notes verbatim,
   `forget` per row, `forget all of it`, identity line at the foot.
   Empty state renders its own honest sentence.
5. **XXXL floor** on the memory page: hero wraps to two lines, body
   scrolls, no horizontal overflow.

### REQUIRES FOUNDER ACTION — §4

### REQUIRES PRODUCTION OBSERVATION

Every success metric. `jeni_read_tool_called{tool, had_data}`,
`jeni_memory_written{topic}`,
`jeni_program_proposal_accepted{kind}` are registered, hygiene-ruled
and DEBUG-asserted, and **none has fired for a real user**, because
this build has not shipped. Nothing in §5 is claimable today.

---

## 2 · ADVERSARIAL LOOPS

| state | how it behaves | how it's held |
|---|---|---|
| empty record | every read refuses with a reason | pinned ×7 |
| sparse week (<4 logged days) | `sparse: true` + a note that averages describe only those days | pinned via `FoodWeekRead.loggedDaysFloor` |
| one weigh-in / stale weigh-in | no direction, ever; `direction_note` says which | pinned; E2's ladder untouched |
| numeric-suppressed cohort | no kcal, no weight, plates carry neither | pinned |
| prescribed fact | refuses + routes; nothing written underneath | pinned |
| malformed proposal | card never renders (a button that promises nothing is worse than no button) | `handleToolCall` guard |
| model invents a tool name | inert (`actImmediate`, `unknown_tool`) | pinned |
| model loops on reads | hard cap 2/turn; a late read is dropped, the written answer stands | `maxReadRounds` |
| read returns nothing AND she writes nothing | "i don't have enough in your record to answer that yet" rather than a blank bubble | `finishStreaming` |
| no medication | `read_dose_history` and `open_dose_sheet` both refuse honestly | code + walked |
| non-medicated / daily cadence | no cycle in the dose read (nil by construction, E2) | E2 pins stand |
| old app + new function | function falls back to its built-in seven | by construction |
| new app + old function | client tools ignored; the seven act tools still work; reads simply never fire | by construction |
| crisis / ED language | still screened client-side BEFORE the model, unchanged | E1/v2 pins stand |

---

## 3 · FRAME-CAUGHT FIXES (the loop working)

1. **The desk's disclaimer carried a banned em-dash** on the most-seen
   line in the tab and disclosed nothing about what jeni is. Replaced
   with the statutory identity line.
2. **The desk's bubble tails collided with that footnote** — the tails
   hang below their frames, so a flush caption sat on them.
3. **My own copy gendered Jeni** ("things you've told HER… SHE only
   writes one down") on a page about a unisex product. Rewritten
   pronoun-free, per the 08-10 rule.
4. **The memory debug host seeded AFTER the page read the store**, so a
   populated account first rendered empty. The page was fine; the
   harness lied, which is worse.
5. **Notes read as reports about a stranger** ("can't do anything on
   their knees") in a list addressed to you. The tool description now
   demands no pronoun at all.
6. **The mock had no continuation latency**, so the reading line was
   real but unfilmable. A film of a state nobody can see is a film that
   lies.

---

## 4 · FOUNDER GATES

E3 adds **no migration**. `JeniMemoryRecord` is an app-target
`@Model` that lightweight-migrates; an empty store is the correct
first-launch state. Chat stays device-local.

1. **Deploy `supabase/functions/jeni-chat`** — carries v24's
   timing-empathy rule, E2's cycle + week rules, **and E3's unisex
   rewrite, identity rule, read-tool instructions and client-declared
   tool acceptance**. Until it lands, the app's reads are declared but
   never offered by the live function (the richer envelope still
   works). *This is the last deploy a tool addition will need.*
2. **Deploy `supabase/functions/food-vision`** — no functional change,
   but its prompt still says "gen-z women" in production until it does.
3. Standing and unchanged: apply `20260809090000` then
   `20260810090000`; ElevenLabs key rotation; archive/TestFlight
   1.2.0 (30); **merge `feat/app-v2` → `main`** (now 474+ commits);
   device walk.
4. **Device walk for this era**: a real chat turn against the deployed
   function (does the model reach for a read unprompted?), the identity
   answer, a proposal accepted on hardware, and a voice pass on the
   reading lines + the memory page.
5. **PostHog after release**: `jeni_read_tool_called` share of chat
   sessions, `had_data` rate (the honesty metric — how often the record
   was there when she went looking), memory-write topics, proposal
   accept rate.

---

## 5 · WHAT WOULD VALIDATE OR FALSIFY THIS

Recorded in `11_E3_DECISION.md` §7 before the build, repeated so it
cannot be quietly forgotten:

- **Kill**: `jeni_read_tool_called` fires for <15% of chat sessions, or
  sessions with a read return no better than sessions without → the
  coach's reach was not the constraint; look upstream.
- **Redirect**: memory writes cluster in one or two topics → cut the
  schema to what people actually say.
- **Confirm**: sessions ending in a program-fact change or a logged
  action return at a higher rate; median active days moves off 1.
- **The gate above all**: none of it is measurable until the merge
  ships.

---

## 6 · KNOWN LIMITATIONS + DEBT

- **The model's judgement is unproven.** Every read is pinned; whether
  a real `gpt-5.1` reaches for the right one at the right moment is a
  prompt question that only the deployed function can answer. The mock
  proves the plumbing and the copy, not the choice.
- **`read_patterns` is medication-only.** The food-week and weight
  engines expose bands rather than observation sentences, so only
  `MedicationPatternEngine` contributes. A food/weight observation
  vocabulary is E4 material.
- **`read_symptoms` returns presence + severity**, not the
  severity-weighted patterns E2 named as debt.
- **`open_weekly_read` routes to Becoming and relies on the read
  auto-presenting when due.** When none is due the page shows the
  record instead, and the tool's note tells jeni not to promise one.
  A forced-present path is queued, not built.
- **No transcript sync** (device-local since v2) and **no memory
  sync** — a new device starts jeni's memory empty. Deliberate for now:
  the table would need a migration and this era added none.
- **Accessibility sizes beyond XXXL** remain the app-wide named debt
  from E2; the memory page inherits it.
- `notif_silenced` still cannot fire (E1's debt, unchanged).

---

## 7 · TEST COUNTS

- Era opened **783/783**; closes **809/809 app + 113/113 package**
  (+26 app, zero package change, zero regressions at every gate).
- New suite: `JeniToolsTests` 26.
- Doors added: `--uitest-chat-read <food-day|food-week|weight|dose|
  program|activity>` · `--uitest-chat-propose <steps|remember>` ·
  `--uitest-chat-auto-confirm` · `--debug-jeni-memory` ·
  `--uitest-seed-memory`.
