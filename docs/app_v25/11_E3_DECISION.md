# THE NEXT ERA — investigation + decision (post-E2)

2026-08-11 · branch feat/app-v2 · E2 closed at `9871066` (783/783 app ·
113/113 package). Method: canonical docs read → repository inspected →
**first-party PostHog re-queried today** → QA sim walked and frames
inspected → primary literature checked on the one question that
decides the era → roadmap challenged → one era chosen.

`00_THE_SYSTEM.md` §15 proposes **E3 KEEP WHAT YOU BUILT** (strength
floor + workout-library kill) next. `07_NEXT_ERA_DECISION.md` kept the
E1→E7 order and re-cut E2's scope.

**Verdict in one line: the roadmap's order breaks here. The next era is
not movement — it is the coach's ability to read her own record,
remember, and change the plan in words. Movement moves behind it.**

---

## 1 · WHAT THE DATA SAYS NOW (PostHog 437953, re-queried 2026-08-11)

### 1.1 The ur-metric, worse than the 2.0 baseline suggested

`07_NEXT_ERA_DECISION.md` §2.1 measured **median 2.0 active days** among
73 payers. Widening to everyone who has ever *finished onboarding* and
had ≥21 days to come back (120-day window):

| distinct active days after onboarding | people |
|---|---|
| **1** | **1,832 (82%)** |
| 2 | 230 |
| 3 | 84 |
| 4–6 | 63 |
| 7–13 | 16 |
| 14–29 | 9 |
| 30+ | **3** |

**28 people out of 2,237 have ever reached a second week.** Every
mechanic Jeni has shipped in five eras — the weekly read (needs 7 days),
cycle patterns (3 cycles), `foodNoiseReturn` (≥3 consecutive cycles),
the weight sufficiency ladder (multiple weigh-ins), the adaptive step
goal (≥5 recorded days) — speaks only to that 28-person tail.

**Jeni is exquisitely built for a user who does not exist yet.** That
is the sentence this era answers to.

### 1.2 What people actually do after day 1

Post-onboarding events (≥12h after `onboarding_complete`, onboarded
≥14 days ago), by distinct people:

| event | people |
|---|---|
| paywall_view | 257 |
| diet_education_lesson_viewed | 132 |
| jenis_note_viewed | 108 |
| steps_viewed_home | 80 |
| workout_start | 64 |
| **food_scan_started** | **40** |
| **food_log_saved** | **39** |
| purchase_completed | 25 |
| **jeni_chat_opened** | **25** |

The single most common thing a returning user does is *meet the paywall
again*. Food, the flagship, reaches 39 people past day 1.

Two numbers cut against the "content is evidence-dead" line in
`00_THE_SYSTEM.md` §3: **132 people opened a lesson** post-onboarding —
the #2 activity in the product. Opening is not value, and the r3
evidence on lesson libraries stands, but the method is not the corpse
the audit described. **Killing it is not this era's business** and the
claim gets re-tested with real data, not assumed.

### 1.3 Chat is small and hot

30-day totals: `jeni_chat_opened` **479 events / 52 people (9.2 opens
per person who opens it)** · `jeni_chat_message_sent` 100 / 24 ·
`jeni_chat_tool_called` 55 / 24. Compare food: 217 logs / 24 people.

Chat has the highest per-user return rate of any surface in the product
and roughly the same reach as food logging — on a build whose coach can
see almost nothing.

### 1.4 The release picture, unchanged and now worse

Live population, 21 days: **1.1.6 = 277 people**; 1.2.0 = 108 (mostly
TestFlight); 1.1.7 = 19. `feat/app-v2` is **469 commits ahead of main**.
v21 · v22 · v23 · v24 · v25 E1 · v25 E2 have never reached a public
user. Every food number above was produced by the module v23 deleted.

**This is the sixth consecutive unreleased era.** The scope below is cut
so it ships with that merge; §6 names the gates plainly.

### 1.5 Also observed, worth naming

`$rageclick`: **722 events across 231 people**, ~93% of them on
1.1.5/1.1.6's root hosting controller. Not diagnosable from the
screen-name property alone (SwiftUI reports one controller for the whole
tree), but 231 of ~600 monthly actives rage-tapping *something* is a
real friction signal and a reason to instrument screens properly.
Recorded as an open question, not acted on here.

---

## 2 · WHAT THE PRODUCT ACTUALLY IS (walked, not assumed)

QA sim 259952D4, fresh build at `94378ad`, seeded program + week +
injectable regimen.

**E1 and E2 are real and good.** Today leads with "take today's shot ·
your dose day. the week starts here"; the plate reading is the best page
in the product (counted numeral, macro ledger, "of today's protein 24 of
62g", "share of today's calories · about a third", "logged from your
words · ranges, not exact"); the chat surface itself is beautifully
built — YOUR FILE (chapter / pace / protein floor), two voices, the
confirm card.

**And the coach is blind.** Three structural findings, all confirmed in
code:

1. **Chat cannot look anything up.** `ChatSession.handleToolCall` runs
   non-confirming tools and then *stops* — "Navigation tools act
   immediately; no continuation needed." Only `confirmTool` (a mutating
   tool, after a tap) sends a continuation turn. A read tool would
   execute, produce data, and **the model would never see the result**.
   The 7 shipped tools are all *act* tools for exactly this reason.
   Worse, `finishStreaming` deletes the streaming entry when a turn is
   tool-only, so a read would render as a bare card labelled with the
   tool's name.
2. **Everything she knows is one flat snapshot of today.**
   `CoachContextAssembler` is rich and disciplined but strictly
   present-tense: today's plates, current EMA delta, last 5 symptoms,
   the last weekly read's decision. There is no path to "what did i eat
   on friday", "how did last week compare", "what changed since my dose
   went up" — the questions a coach exists to answer.
3. **The plan is not negotiable in words.** E1 built `ProgramFactStore`
   with a full authority law (prescribed › preferred › recommended ›
   defaulted, consent-gated, iOS never writes prescribed). Chat cannot
   reach it. The only door to the program's memory is the weekly read —
   which needs a week, which 82% of users never have.

**And the coach's own voice was never swept.** The 2026-08-10 unisex
pass (`278ff71`, `3b88451`, 87 rewrites across 30 files) moved the
client. It did not touch the two server-side LLM prompts, which is where
most of Jeni's user-facing language is actually generated:

- `jeni-chat/index.ts:50` — *"you are jeni, the coach inside jenifit —
  a weight-loss and weight-management program **for women**"*, plus
  she/her throughout the science posture, redlines and tool
  descriptions.
- `food-vision/index.ts:270` — *"you are a food vision model for a
  weight-loss app serving **gen-z women**"*, and again at :314 for the
  recognition priors.

The commit message for the sweep says the prompt engines were done
"first, because those generate all of Jeni's language". The two that
matter most were missed. Also live: the desk's disclaimer *"jeni
supports your plan — not medical care."* carries a banned em-dash on the
chat tab's most-seen line, and its bubble tails collide with it.

**Frame-caught, food:** `--uitest-open-food-journal` still no-ops (gap-map
T2, open since 07_NEXT_ERA §1.2) — THE BOOK has no door.

---

## 3 · THE LITERATURE CHECK

One question decides between "movement next" and "the coach next":
**does an LLM coach wired into a behaviour-change product actually move
engagement, or is it a demo?** Re-checked rather than assumed.

**Bloom** (arXiv 2510.05449, randomized field study, N=54, 4 weeks,
May–June 2025) is the closest primary evidence that exists:

- Treatment participants **spent more than five times as much time in
  the app** than control (5.6×) — the largest engagement effect in this
  literature.
- The LLM condition's mechanisms were exactly three: **tool access to
  the user's own tracked data** (HealthKit queries + generated
  summaries), **generating and modifying the structured plan** as JSON,
  and **summary-based memory across the four weeks**. Control had the
  same app with template notifications and a menu-driven plan editor.
- Psychological outcomes moved (belief in benefit, enjoyment,
  self-compassion when goals were missed). Physical activity rose in
  **both** arms; **no significant treatment–control difference at 4
  weeks**. Engagement ≠ outcome, and the paper is honest about it.

**The design lesson is the important part, and it cuts against the
obvious build.** Participants named *"plans, the ambient display and
notifications — not chat"* as their accountability. LLM-generated data
summaries were "infrequently mentioned". Some treatment users never
opened the chatbot at all. What they *did* value was negotiating the
plan in natural language ("can I switch it to a bike ride?").

**So: the value is not a better chat tab. The value is an LLM with
tools, memory, and write access to the structured plan — whose effects
show up in the structured surfaces.** That is precisely the founder's
standing instruction ("I don't want a chatbot sitting beside the
product") and it is the era below.

Caveats recorded: N=54, 4 weeks, one domain, no outcome difference, and
the safety evaluation was explicitly preliminary. This is a *promising*
mechanism with one good randomized field study, not a proven one.

Category check (Aug 2026): MeAgain ships "Capy", a capybara AI
companion; GLP AI ships a "24/7 AI coach" beside a 0–100 meal score and
an estimated-medication-level chart (the pseudo-quantitative artifact
our provenance law already refuses). Nobody is shipping a coach that
reads the user's own longitudinal record and writes the program with
recorded authority. **The lane is open, and it is the one lane five
eras of accumulated data unlock.**

---

## 4 · SCORING (the same weights as 07, one criterion added)

Weights unchanged from `07_NEXT_ERA_DECISION.md` §4 — retention ×3,
E1/E2 leverage ×3, works-at-current-scale ×3, differentiation ×2, B2C
×2, compounding data ×2, one-system ×2, frequency ×2, user value ×2,
clinical ×1.5, acquisition ×1, B2B ×1, impl. risk ×1.

| | **ONE JENI** | E3 movement | E4 plate's memory | E5 method atoms | E6 queue |
|---|---|---|---|---|---|
| retention (×3) | 4 | 2 | 4 | 2 | 1 |
| E1+E2 leverage (×3) | **5** | 3 | 3 | 3 | 3 |
| works at current scale (×3) | **5** | 3 | 1 | 3 | 2 |
| differentiation (×2) | **5** | 3 | 3 | 3 | 5 |
| B2C (×2) | 5 | 3 | 5 | 4 | 1 |
| compounding data (×2) | **5** | 2 | 5 | 2 | 3 |
| one system (×2) | **5** | 3 | 4 | 4 | 3 |
| frequency (×2) | 4 | 3 | 5 | 3 | 2 |
| user value (×2) | 5 | 4 | 5 | 3 | 4 |
| clinical (×1.5) | 3 | 4 | 4 | 4 | 3 |
| acquisition (×1) | 3 | 2 | 5 | 2 | 1 |
| B2B (×1) | 4 | 3 | 3 | 4 | 5 |
| impl. risk (×1, 5=low) | 3 | 3 | 3 | 3 | 2 |
| **weighted total** | **119.5** | 74.5 | 97.0 | 80.0 | 62.5 |

Where ONE JENI wins, and why the numbers are not the argument:

- **Leverage.** It is the only era that makes *all five previous eras*
  more valuable without touching them. The dose chain, the cycle, the
  weight EMA, the symptom timeline, the food week, the program facts —
  every one of them becomes answerable the day this ships. Movement adds
  a sixth pile of data nobody can ask about.
- **Works at current scale.** A coach that can read the record is useful
  on the **first** message. She can answer "is this enough protein"
  from the plate you just logged, and "what changed since my dose went
  up" three months later. Nothing else in the product has both ends.
- **Compounding.** The founder's test — *"something the user does today
  should make Jeni meaningfully better tomorrow"* — is literally what a
  memory is. Today it does not exist.
- **Clinical scores only 3.** This is the era's real cost: an LLM with
  more reach is more surface for redlines to fail on. §5 of
  `12_E3_ONE_JENI.md` treats that as the primary design constraint, not
  a footnote.

---

## 5 · THE DECISION

### Next era: **E3 — ONE JENI**, replacing the roadmap's E3.

**Goal:** the coach can *read* her own record, *remember* what she
learns, and *change the plan* in words — through the same chokepoints
and the same authority law the surfaces use. One Jeni, not a chatbot
beside a tracker.

**In scope**
1. **The tool loop** — a read tool can return data and Jeni continues
   the turn. Multi-tool, round-capped. The EF accepts client-declared
   tools behind a server allowlist, so **this is the last jeni-chat
   deploy a tool addition ever needs**.
2. **JeniReads** — food day/week · weight trend (E2's
   `WeightWeekReadEngine`) · dose history + cycle (E2) · symptoms (E2) ·
   patterns (v24) · activity (E1) · program facts + authority (E1).
   Every read renders from the same engine the surfaces render from, so
   chat and UI can never disagree.
3. **JeniRemembers** — a small, typed, consent-visible memory. Written
   only through a tool that shows a card, readable by the whole product,
   viewable and deletable in settings.
4. **The plan negotiable in words** — `propose_program_fact` through
   `ProgramFactStore` with the full authority law: prescribed facts
   REFUSE and route to the correction door; accepted changes land as
   `preferred`, announced, superseding never mutating.
5. **The voice corrected** — both EF prompts unisex; the AI-identity
   disclosure the CA/IL/TX statutes require and §8 of the master plan
   promised; the em-dash and collision on the desk.
6. **A richer envelope that needs no deploy** — so the *currently
   deployed* EF answers better the moment this build ships.

**Explicitly NOT in scope**
- No new tab, no mascot, no proactive chat pushes (the desk stays quiet
  — §8 of the master plan).
- No method/lesson work and **no library kill** — §1.2 says the claim
  needs data we do not have.
- No food-vision accuracy work (that is E4, still behind its
  measurement gate).
- No clinic UI (E6, founder-gated).
- No PK curves, no dosing math, no diagnosis — standing.

### Roadmap change: **movement moves to E4-or-later, and shrinks.**

The strength floor is good work with real evidence behind it (lean mass
is 25–40% of drug-induced loss). It is also a week-3 feature for a
population that does not reach week 2, and the workout-library kill is
housekeeping wearing an era's clothes. It waits until either (a) the
merge ships and week-2 retention becomes observable, or (b) the medicated
cohort is measured and large enough to design for.

---

## 6 · DECISION LEDGER

| # | decision | why | declined |
|---|---|---|---|
| D1 | ONE JENI next, not movement | only era that compounds all five prior eras; useful on message 1; founder's #1 stated area; movement scores lowest on the measured failure | executing E3 as written |
| D2 | the tool loop is the era's spine | chat *structurally* cannot look anything up today; every other item depends on it | more context-stuffing instead of tools |
| D3 | tools declared client-side, allowlisted server-side | five eras have queued behind founder deploys; this makes it the LAST deploy a tool addition needs | server-owned tool list forever |
| D4 | memory is written only through a visible card | the adaptation-consent law (§13) applied to knowledge; silent profiling is a bug class | silent LLM-extracted user profiling |
| D5 | chat writes program facts as `preferred`, never `prescribed` | the S4/E1 law, unchanged; the clinic patient's plan stays the clinician's | a chat-only shadow of the program |
| D6 | the two EF prompts swept unisex | they generate most of Jeni's language; the 08-10 sweep missed them; the founder's correction is not done until they move | leaving the deployed voice gendered |
| D7 | AI-identity disclosure shipped now | CA/IL/TX in force; statute outranks the no-"AI"-in-copy style law (§8 already recorded this) | deferring to E5 as planned |
| D8 | the method library is NOT killed | 132 post-onboarding openers make it the #2 activity; the audit's "evidence-dead" verdict is about *lesson libraries in the literature*, not about this corpus in this product | executing the audit's REMOVE line unexamined |
| D9 | movement deferred, not cancelled | it needs a week-2 population to serve | shipping a strength protocol for 28 people |
| D10 | Bloom read as *promising*, not proven | N=54, 4 weeks, no outcome difference between arms | citing 5.6× as an outcome claim |

---

## 7 · WHAT WOULD FALSIFY THIS

Recorded before the build, so the next session can check honestly:

- **Kill signal:** after release, `jeni_read_tool_called` fires for
  <15% of chat sessions, or sessions with a read tool show no higher
  return rate than sessions without. Then the coach's reach is not the
  constraint and the answer is upstream (activation, price, acquisition
  quality).
- **Redirect signal:** memory writes cluster in a handful of kinds and
  the rest go unused → cut the schema to what people actually tell her.
- **Confirm signal:** chat sessions that end in a program-fact change or
  a logged action return at a higher rate than sessions that do not;
  median active days moves off 1.
- **The gate above all of them:** none of this is measurable until
  `feat/app-v2` merges and ships. That remains the highest-leverage work
  in the project and it is not work a Claude session can do.
