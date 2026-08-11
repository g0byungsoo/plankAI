# THE NEXT ERA — investigation + decision (post-E4)

2026-08-11 · branch feat/app-v2 · E4 closed at `6d242ef` (830/830 app ·
125/125 package). Method: STATE + the complete v25 record read (00, 02,
03, 04, 05-16) → PostHog re-queried with a NEW question (not "who
returns" but "who ever arrives") → the gate read in code → the QA sim
walked at HEAD across 12 surfaces → MeAgain's 62 frames re-read as a
contact sheet → the Lovi chooser reference the founder supplied → one
era chosen.

**Verdict in one line: the next era is THE FIRST PLATE — Jeni must do
one real thing for a person BEFORE she asks them for money, because
today 90-94% of everyone who finishes onboarding never sees a single
screen of the product they were asked to buy.**

---

## 1 · THE FINDING THAT REFRAMES FOUR ERAS

### 1.1 Production evidence (PostHog 437953, queried 2026-08-11)

Every prior era asked *"why don't people come back?"* Nobody asked
*"how many ever get in?"* The answer, measured per app version so the
instrumentation age can't distort it (`main_tab_appeared` did not exist
before 1.1.3 — an earlier cut of this query mixed versions and had to
be redone):

| app version | onboarding completions | ever saw the main app | purchased | saw app WITHOUT paying |
|---|---|---|---|---|
| 1.1.6 | 236 | **18 (7.6%)** | 20 | 3 |
| 1.1.5 | 200 | **21 (10.5%)** | 18 | 3 |
| 1.1.4 | 103 | **6 (5.8%)** | 6 | 1 |

Three independent shipping builds agree: **6-10% of people who finish
onboarding ever reach one screen of Jeni**, and essentially all of them
are purchasers (the 1-3 per version who got in without a purchase are
restores/care entitlements).

Supporting production facts:
- `paywall_view` 2,436 users → `purchase_completed` 172 users = **7.1%**
  over 90 days. The wall is the single most-seen surface in the entire
  product — more people have seen Jeni's paywall than have seen Jeni.
- **Payers who paid ≥30 days ago (n=151): median 2.0 active days.**
  54% reach a 2nd active day, 15% reach a 7th, 12% are still active at
  day 28. The bucket leaks too — but it can only leak what gets in.
- 90-day reach of in-app surfaces, for scale: `food_scan_started` 86
  users · `jeni_chat_opened` 84 · `weight_logged` 72 · `becoming_opened`
  17. **Four eras of adaptive intelligence (E1-E4) currently serve a
  population of roughly twenty people per release.**

### 1.2 The gate, in code (verified at HEAD, not inferred)

`PlankApp/App/AppPhase.swift:84` —

```swift
guard i.hasPro || i.hasCareEntitlement else {
    return .wall(i.wasEverEntitled ? .expired : .fresh)
}
```

The file's own header states the intent: *"unpaid and expired users
never have main-app content in the hierarchy at all."* `WallView`'s
exit-intent chain ends in `standDown()`, which makes the wall **quiet**,
not **passable** (`WallView.swift:264`). There is no product behind it.

`FoodFlags` layer #2 is explicit: *"Non-paying users see no food UI at
all."*

There is no food beat anywhere in onboarding: `food_ai_consent_shown`
fires only from `PlankFood`, which only mounts inside `MainShell`, which
only mounts in `.main`.

**So the shape of a new user's life is: install → ~40 questions → a plan
reveal → a price → gone. They are asked to buy a coach they have never
met.**

### 1.3 The product's own law already forbids this

`00_THE_SYSTEM.md` §12, written before this era, names the banned
anti-loops:

> Anti-loops (named, banned): streak chains · guilt re-engagement ·
> notification volume as growth · **paywalling the record**.

And §3 finding 9, from `research/r1`: the trust vacuum is the opening —
**MeAgain's paywalled log is specifically cited as hated**. The shipping
product does the exact thing the master plan identifies as the
competitor's worst decision and lists as forbidden.

This is not a new strategy invented for this session. It is the plan
catching up with itself.

---

## 2 · WHY THE ROADMAP'S NEXT ERA LOSES

| candidate | why it loses now |
|---|---|
| **E5 THE DISPERSAL** (knowledge atoms + moment tools) — the roadmap's next number | Delivers teaching at the moment it applies. The moment requires being in the app. Reach: ≤20 people/release. A week-three feature for a population with a median of two days. |
| **E3 MOVEMENT** (deferred twice) | Same reach ceiling, plus its own evidence (steps drop after starting GLP-1) speaks to week 3+. Deferral stands for the third time — and stays *deferred, not cancelled*. |
| **E6 THE QUEUE** (clinician product) | Blocked on founder gates that are not code (BAA, counsel, insurance, pilot). Zero B2C reach. |
| **E4.1 the ONE clarifying question** (food accuracy) | Genuinely good, already specified, already founder-gated behind the food-vision deploy. It improves an experience 3.4% of onboarded users ever have. It should ride the deploy it is already bundled into — it is not an era. |
| **A pure design pass** | The founder's second mandate is real and is honoured inside this era, but reskinning surfaces nobody reaches moves nothing. |
| **THE FIRST PLATE** | Multiplies the reachable population of everything E1-E4 already built, uses zero new engines, needs zero server deploys, and is the only candidate that answers the founder's literal question: *does a new user experience real weight-loss value?* Today the answer is no, for 9 out of 10 of them. |

### The honest counter-argument, stated plainly

7% conversion on a hard, no-trial paywall is not a scandalous number for
the pattern. It is defensible that the real constraint is acquisition
volume (2,436 paywall views / 90 days ≈ 27/day). **That may also be
true.** But the founder's question was specifically about what a *new
user experiences*, and on that question there is no ambiguity: they
experience nothing. Acquisition work cannot be done from this repository;
this can.

---

## 3 · THE DECISION

### Era: **E5 — THE FIRST PLATE.**

**One sentence: before Jeni asks for money she does one real thing —
reads your first plate with the real camera and the real intelligence,
tells you one true thing about it, and starts a record that is yours
whether or not you buy.**

This is not the removal of the paywall. Price, tiers, the keep wall's
bands, the exit-intent chain, the downsell ladder and the pay-upfront
model are all untouched. The only change is **the order**: proof, then
the ask.

#### The loop, before and after

```
BEFORE  onboarding ──▶ THE WALL ──▶ (94% leave, having used nothing)

AFTER   onboarding ──▶ YOUR FIRST PLATE ──▶ THE WALL, which now knows
                       (real camera,          what you just did
                        real vision EF,
                        real reading,
                        real saved record)
                                 └──▶ if they buy, the plate is already
                                      in their record and their day
                                      already counts it
```

#### The builds

- **B1 THE PROOF PHASE** — `AppPhase.proof`, a bounded first-run state
  between `.onboarding` and `.wall`. It mounts the REAL
  `CaptureFlowView` (consent sheet included — Apple 5.1.2(i) is not
  skipped), the REAL `food-vision` EF, the REAL `FoodLogPersister`.
  Exactly one plate. `derive` stays pure and table-tested. No parallel
  store, no forked flow, no second capture pipeline.
- **B2 WHAT IT MEANS** — the reading already exists (v23, ONE PAGE). The
  era adds the first-time meaning beat: this plate against *her* protein
  floor, computed by `TargetsService` from the weight onboarding already
  collected. Provenance-stamped, hedged where thin, no score, no colour
  judgement. This is where "real weight-loss value" is actually
  delivered, once, honestly.
- **B3 THE WALL, EARNED** — a third `WallReason` whose opening beat is
  the receipt of what just happened, in her own numbers. Every existing
  control stays live (the 5.6 rejection is a standing lesson: nothing on
  the wall may be dead).
- **B4 THE SCAN CHOOSER, REDESIGNED** — the founder's explicit ask, and
  the food door for everyone already inside. Full rationale in §5.
- **B5 THE RECORD** — analytics, films, tests, docs.

#### Explicitly NOT in this era
- No price, tier, band, downsell or wall-commerce change.
- No EF deploy. Nothing in this era is founder-gated behind a server
  push. (The vision EF verifies a JWT and applies a 30/day per-user cap
  plus a global daily budget — it never checked entitlement.)
- No second free thing. One plate. Not a free week, not a free tab.
- No new engine, no new table, no migration.
- The chat desk's blank room (§5.3) is named, ranked, and deliberately
  left for the next era.
- Movement, method, clinic UI: unchanged.

---

## 4 · DECISION LEDGER

| # | decision | why | declined |
|---|---|---|---|
| D1 | the gate before everything else | 6-10% of onboarded ever see the product across three shipping builds; the master plan already bans paywalling the record | roadmap E5 dispersal (reach ≤20/release) |
| D2 | proof BEFORE the ask, not a free tier | keeps pay-upfront intact; changes order, not model | removing/softening the wall; reinstating trials |
| D3 | exactly ONE plate | bounded, honest, cheap (≤1 vision call per new user, under the EF's existing caps), and it is the beat production evidence associates with return (day-0 food loggers return 76.2% vs 16.6%) | a free day, a free week, a free tab |
| D4 | the plate is REAL and PERSISTS | the compounding promise kept: pay, and your record is already started | a demo plate, a canned reading, a simulated result |
| D5 | reuse `CaptureFlowView` whole | chokepoint law; the consent gate, the deadline, the retry card and the refine loop all come for free | a trimmed "onboarding camera" fork |
| D6 | ship behind `FirstPlateFlag` | this is a business-affecting change; the founder can disable it in one line without a revert | hard-wiring it |
| D7 | the scan chooser is redesigned, not repainted | the founder pointed at it directly; its faults are structural (nested tiles, three geometries, floating composition), not cosmetic | a colour/type pass on the existing structure |
| D8 | body imagery stays OUT of the chooser | body-privacy law L4 — a scan thumbnail in a chooser is shoulder-surfable; the meal door may carry her own plate photo, the body door stays drawn | symmetric photographic doors |

---

## 5 · THE DESIGN AUDIT (the founder's second mandate)

### 5.1 Ranking (frequency × thesis-importance × inconsistency × usability × perceived quality)

Walked in the simulator at HEAD, 2026-08-11.

| rank | surface | 90-day reach | verdict |
|---|---|---|---|
| 1 | the wall | 2,436 users | commerce untouched; **its arrival moment** is rebuilt by B3 |
| 2 | Home / Today | canonical | reference. Left alone. |
| 3 | Becoming | canonical | reference. Left alone. |
| 4 | **the scan chooser** | every food entry | **REDESIGNED (B4)** |
| 5 | the reading | every scan | first-time face added (B2); the v23 page structure stands |
| 6 | the chat desk | 84 users | **real debt, deliberately deferred** — see 5.3 |
| 7 | the book / your plates | low | v23 grammar holds; QA gradient art is seed data, not product |
| 8 | settings, regimen, dose sheet | low | coherent with the language. Left alone. |
| 9 | the migration moment | legacy users only | **defect found, see 5.4** |

### 5.2 The scan chooser — why it fails and what replaces it

Its own header says it was already an attempt at the Lovi grammar. It
misses for four structural reasons, all visible in the capture:

1. **Nested containers.** Each door is a white card containing a grey
   rounded tile containing a drawing. Card-in-card is the first item on
   the founder's suspicion list.
2. **The art carries no information.** The meal door's three capsules in
   a ring read as an audio waveform, not food. The body door renders a
   heavy black torso — the loudest object on the screen, in a product
   whose law is body-neutrality.
3. **Four geometries in 350pt** — card, card, capsule pill, circle —
   floating in a vertically-centred stack with a large void beneath.
4. **The dim erases instead of softening.** `ultraThinMaterial` + 12%
   ink over a cream app leaves grey noise, so the "your page went soft"
   idea never lands.

**What MeAgain and Lovi were actually useful for** (principles, not
pixels): a chooser is a *bottom-anchored composed object* in the thumb
zone, not a floating centred stack; the interior of a door should carry
substance rather than an icon; the close affordance belongs tight to the
group it closes; and the page behind should stay legible enough to read
as *softened*, not replaced.

**Jeni's own interpretation** (the part that is not Lovi): the doors are
made of *her record*. The meal door carries her last plate's own
photograph; the "again" door names the dish by name. Nothing decorative
is added — the substance inside the card is data she created. The body
door stays drawn, on purpose, because L4 says her body is not
decoration.

### 5.3 Named, ranked, deliberately NOT built

**The chat desk is a blank room.** A j-mark, a greeting, three starter
chips, then ~200pt of dead space above a thin composer. The founder's
brief names "Jeni Chat as a natural interface into the whole product" as
a product area, and MeAgain's global "+" sheet (capture + log + "ask
Capy" in one object) is a genuinely better answer to that than what
Jeni ships. It is real debt and it is the strongest candidate for the
era after this one. It is not in this era because it serves the 84
people already inside, and this era is about the 2,300 who never get in.

### 5.4 Defect found while walking (fixed in this era)

The migration moment — the first in-app screen a legacy user sees —
promises four things under "WHAT'S INSIDE", two of which the product
does not keep: *"movement — matched to your energy"* (the movement era
is deferred for the third time) and *"the method — a 2-minute read, most
days"* (the method's library was audited REMOVE/rebuild and the
dispersal era has not shipped). A first screen that makes promises the
product does not keep is a trust defect, and trust is the strategy.

---

## 6 · EVIDENCE CLASSES (kept separate, per the brief)

- **Production evidence**: §1.1 — all first-party PostHog, filtered to
  non-test users, split by app version. The version split matters: an
  earlier version-blind cut of the reach query had to be discarded.
- **Code evidence**: §1.2 — read at HEAD, quoted with file:line.
- **Research evidence**: `research/r1`, `r2`, `r6` (cited in
  `00_THE_SYSTEM` §3): self-monitoring is the intervention; photo
  logging is the wedge; the trust vacuum is the opening.
- **Competitor observation**: MeAgain paywalls its log and is disliked
  for it (r1 §9). Cal AI, MacroFactor and MeAgain all allow capture
  before purchase.
- **Design-reference observation**: MeAgain's 62 frames (contact-sheeted
  this session) and the Lovi "Make a New Scan" sheet supplied by the
  founder.
- **Inference**: that a person who has used nothing converts worse than
  one who has used something. Standard, well-supported in the category,
  **not measured here.**
- **Hypothesis (the era's bet)**: showing proof before the ask raises
  both purchase rate and post-purchase survival, because the buyer now
  knows what they bought.
- **Unknown**: the size of the effect; whether some users log one plate
  and leave who would otherwise have paid blind. **This is a real risk
  and it is why D6 puts the era behind a flag.**

---

## 7 · WHAT WOULD VALIDATE OR FALSIFY (production, post-merge)

New instrumentation (hygiene-ruled, categorical only):
`first_plate_offered` · `first_plate_started` · `first_plate_completed`
· `first_plate_skipped` · `wall_view {after_proof: true|false}`.

- **Confirm**: onboarded → purchase rises off the 5.8-10.5% band; among
  purchasers, the share reaching a 2nd active day rises off 54%; the
  saved proof plate appears in the paid record (the compounding promise
  observable end-to-end).
- **Kill**: purchase rate flat or down after a fair window → the ask
  was never the problem; the constraint is acquisition or price, and
  this era's flag goes off in one line (D6).
- **The gate above all of them, unchanged since E1**: none of this is
  measurable until `feat/app-v2` merges and ships. Five eras of work are
  currently unobservable. That, not any single feature, is the largest
  standing risk in the project.
