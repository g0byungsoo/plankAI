# PARITY BEFORE MOAT — the boring things, measured

**Status: BUILT 2026-08-13.** Not an era. A deliberate change of
altitude: stop deepening, and ask whether Jeni is already obviously
useful for the basic job.

No migration. Zero diff against the reviewed release (`1710180`) in
Payment, Paywall, Auth, Sync, `supabase/migrations`, `AppPhase`,
entitlements, `Info.plist`. **Zero HealthKit read-type change. Zero new
analytics events.** `e5.firstPlate.enabled` still false. The Edge
Function is untouched — still written, still not deployed.

7 files modified, 4 added, 353 insertions.

---

## 1 · THE QUESTION, AND WHAT ANSWERED IT

The brief asked whether we have over-invested in product intelligence
while the most valuable needs are embarrassingly simple. The answer is
yes, and **production said so more sharply than any review did.**

Same three-day window, identical instrumentation age (all three events
shipped 2026-08-10 21:21), internal test users excluded:

| | users |
|---|---|
| configured a medication regimen | **42** |
| logged a side effect | **34** |
| **ever marked a dose taken** | **3** |

`dose_marked` last fired at 22:00 on the hour it shipped. `regimen_changed`
and `side_effect_logged` have fired every day since, including today.
**39 of 42 people who told Jeni what they are on have never once
recorded taking it.** That is not a cold-start artifact — it is a live
funnel with a hole, on the one action every competing product is built
around.

And 90 days, current build:

| action | users |
|---|---|
| `food_log_saved` | 82 |
| **`weight_logged`** | **72** |
| `body_scan_kept` | **8** |

---

## 2 · THE FIVE JOBS, FROM REVIEWS NOT MARKETING

Read across Shotsy (4.8★ / 29K ratings), MeAgain (4.34★), and the
long tail — Pep, Redose, WeTide, Dosio, Gala, GLP-1.COM.

1. **"When is my next shot, and did I take the last one?"** Countdown,
   reminders, shot history, injection-site rotation. It is why people
   install one of these at all. *("Helps my ADHD brain stay on track."
   "Helps me remember injection sites to avoid repeated spots.")*
2. **"How much have I lost?"** Start → now → goal. The number people
   screenshot. *("I can check the results tab when I feel discouraged."
   "Lost 47 lbs in four months.")*
3. **"Did I get enough protein / fiber / water?"** Explicitly **not**
   calories. MeAgain reviewers name fiber as the surprise that made them
   stay; their own copy sells "protein, fiber and water goals tuned for
   reduced appetites".
4. **"Log this meal in under ten seconds."** Photo, barcode, repeat —
   plus a correction button, which is MeAgain's top open request and
   which Jeni has had since E4.
5. **"Give me something for my doctor."** PDF export is repeatedly the
   stated reason people keep paying.

**What the reviews changed my mind about.** I expected the estimated
medication-level curve to be the signature feature worth copying — it
is named in four of ten top Shotsy reviews. It should not be built. A
clinical pharmacologist's verdict on these charts is blunt (*"fun only
and scientifically inaccurate"*): time-to-peak ranges 8-72h across
individuals, apps use a fixed curve, and no concentration-effect
relationship for weight outcome is established. It is a beautiful
instrument for a number we cannot know, which is the exact defect
`27_THE_PORTION_AND_THE_SOURCE` was written about. **Refused.**

---

## 3 · JENI AGAINST THAT LIST, WALKED

| job | before |
|---|---|
| next shot / did I take it | **below the fold on dose day, absent every other day** |
| how much have I lost | **the arithmetic did not exist** |
| protein · fiber · water | **best in class** |
| log a meal fast | good; the body-scan door held half the target area |
| something for my doctor | `VisitPacket` exports a real PDF — **parity, already** |

### Three things I found by walking that the record did not say

**① On dose day the most time-sensitive fact in the product sat ~1,400pt
down the page**, under the protein ring, the macro split, the fiber row
and a daily-value footnote. The screen above it was **byte-identical**
to a non-medicated user's. On any *other* day Home said nothing about
her medication at all — she could not learn when her next shot was
without opening a sheet behind a row she had to scroll to find.

**② There is no "how much have I lost" anywhere in the codebase.**
`grep -rn "startWeight\|sinceStart\|totalChange"` → no matches.
`BodyStateService.weightRead` computes a 7-day EMA delta, a weekly loss
rate, a stall flag and a too-fast flag — a rich clinical read with no
answer to the question people came for. Becoming's body card therefore
led with *"down about 1 lb this week"*, which on a twelve-day record is
the least motivating true sentence available. And **`goalWeightKg` is
asked in onboarding, stored, fed to the calorie target, and appears in
no view outside the screens that collect it.**

**③ Home carried no weight number.** The weigh-in tile said *"last
logged yesterday"* — a fact about **logging** — beside an unlabelled
sparkline. Every other tile names the thing ("4 plates today",
"strength met this week").

---

## 4 · WHAT SHIPPED

### `DoseStanding` — where she is in the dose week, as one sentence

One pure engine, no stored field, no migration. One line directly under
the calendar strip, above everything. Four standings:

- **due today** → *"your shot is today · mark it when you take it"*
- **late** → *"sunday's shot is still open · log it, or let it go"* (a
  dose she can still take outranks a dose she will take)
- **done / skipped today** → *"today's shot, done"*
- **between doses** → *"your next shot is sunday · in 3 days"* — the
  state Home has never been able to speak, five days out of seven

**It names no medication.** Home is a screen she may hand to someone;
the existing to-do row's discretion is the precedent this follows. A
pill is never called a shot (the catalog's own noun, every branch), and
"in 1 days" is unreachable by construction.

**It is not an addition — it is a relocation.** On dose day the
duplicate to-do row is suppressed at the RENDER, so the list gets
shorter and one fact lives in one place. Suppression never touches
`CarePlanEngine`: completion counting, quick-mark and analytics all
still see the beat, and only the two numbers `HomeView` itself draws
change (verified: TODAY went `1 of 2` → `1 of 1`).

**For a non-medicated user it draws nothing.** `doseStanding` is nil by
construction without a scheduled regimen. Proven, not asserted: a pixel
diff of Home before vs after for a non-medicated user is **0 differing
pixels of 346,800**.

### `WeightJourney` — the whole distance

The second most-used action in the product finally has its arithmetic.
Start, now, total change, the goal she named, and what is left.

- **The present is a trend; the start is a fact.** Today's endpoint is
  the EMA, never the scale. The start is her earliest logged weight,
  because `WeightTrendChart.computeEMA` **windows to 60 days** — its
  first point means "sixty days ago", not "when you started", and
  reading a total off it would quietly shorten every record older than
  two months. A test pins exactly this (78→74 must read 4 kg, not the
  2 kg the window would report).
- **It waits for a record worth reading** — the threshold is
  `BodyStateService`'s existing `trendEstablished` (≥3 logs over ≥5
  days), not a second invented one. Daily noise is not a journey.
- **A goal only speaks when it is hers and still ahead.** A remaining
  figure that counts up from a met goal is a scold.
- A gain is stated as flatly as a loss, direction is a word never a
  colour, and sub-tenth movement reads as *"holding where you started"*.

Two render sites, no new height: Becoming's body card caption becomes
*"down 1.3 lb since you started. 21.6 lb to go."* (a **swap** — the week
keeps its own door), and Home's weigh-in tile states the distance
instead of the logging cadence.

### Body Scan — DEMOTED, on evidence

E5 gave the meal and the body equal halves of the scan chooser. Measured
over 90 days on the shipping build: **82 users saved a food log, 8 kept
a body scan.** A door used by one person in ten held half the primary
target area on a tab whose overwhelming job is food — while the busiest
action in the product was a half-width tile.

The meal door takes the width it earns. The body door keeps its place in
the **same row material** as `again` — demoted, not deleted, still one
tap from here, no fourth geometry introduced. Every other entrance
(Home tile, Becoming cover, the check-in row) is untouched.

**This reverses a founder steer from E5 ("the body door stays drawn per
L4"), which was made two days before this usage data existed.** It is
one line to put back.

---

## 5 · WHAT I REFUSED TO BUILD

- **The estimated medication-level curve** (§2). The single most-praised
  competitor feature, and false precision.
- **A water tracker.** E9's reasoning stands: no credible body
  prescribes a personal fluid volume, and restriction is standard care
  in HF/CKD/hyponatremia. The medicated user already gets the *reason*
  as a to-do row.
- **A home-screen widget.** Every competitor has a next-shot countdown
  widget and `JenifitWidgets` contains only a scan Live Activity. It is
  the right next boring feature and it is **named, not smuggled** — it
  needs an app-group container and a `pbxproj` target change, which is
  more surface than a build going into review deserves.
- **A dose calculator** (units ↔ mg for compounded vials), a "skip
  injection" state, custom shot frequencies. All real, all named in
  reviews, none measured here.
- **Food Book depth.** Asked of it only the brief's five questions —
  can I understand, find, repeat, inspect, correct. All yes. **Left
  alone.**
- A migration, an analytics event, a paywall/pricing change, a health
  score, a streak.

---

## 6 · WHAT FRAME REVIEW CAUGHT

1. **Two `bandGap`s stacked** under the standing row — ~100pt of dead
   air above the protein ring. Invisible in code, obvious in a frame.
2. **At AX5 the repeat door read `"again · chick…"`** — the dish name is
   the only content that row carries. Pre-existing; the demote surfaced
   it by putting two rows side by side. Two lines now.
3. **The `.upcoming` standing had no door to film**, because every
   medication QA variant anchors the dose to today. Added
   `--uitest-seed-medication next`.

**And a fixture that lied, twice, the same way.** My first
`.upcoming` unit test seeded no events — so every past slot was
unresolved and the engine correctly returned `.late`. I fixed the
fixture, then wrote the *seeder* with the same bug: fixed day offsets
(-4/-11/-18/-25) that assumed where the anchor landed, so every "taken"
event missed its slot and the app read `.late` on screen too. **The
engine was right both times and the fixture was wrong both times.** The
seeder derives its slot days from `MedicationScheduleEngine.slotDays`
now.

---

## 7 · PROOF

- **1035/1035 app** (was 1009; **+26**) · **192/192 package**.
- Release configuration compiles.
- Protected paths verified **empty** against `1710180`: Payment,
  Paywall, Auth, Sync, migrations, `AppPhase`, `Info.plist`,
  entitlements. The only `pbxproj` change is four new file references.
- **Zero HealthKit diff, zero analytics diff this session.**
- Filmed: all four dose standings · Home medicated/non-medicated
  before+after · Becoming before+after · the chooser before+after ·
  AX5 on both changed surfaces.
- **0 of 346,800 pixels differ** on non-medicated Home, before vs after.
- Every new test pins a law, not a pixel: the anchor that survives the
  60-day window · the threshold that refuses noise · a goal that never
  counts up · "in 1 days" unreachable · a pill never called a shot ·
  only the late standing carries a slot to open.

New DEBUG door: `--uitest-seed-medication next`.

---

## 8 · B2C / B2B

No authority work needed. Nothing reads or writes `program_facts`;
`CareProtocol` and `MethodNote.authority` are untouched. `DoseStanding`
reads through `RegimenService.facts`, so a care-team-assigned regimen
produces the standing by the same path as a self-set one, and the
clinician's `instruction` still belongs to the sheet. `WeightJourney` is
the figure a clinician asks for first and the `VisitPacket` already
carries the underlying series.

---

## 9 · THE EDGE FUNCTION — STILL A FOUNDER GATE

Untouched this session (`git status supabase/` is clean). The previous
pass's verification stands:

```
supabase functions deploy food-vision --no-verify-jwt
```

---

## 10 · WHAT STILL FEELS BELOW THE BAR

- **The post-purchase screen personalizes nothing.** *"we used what you
  told us in onboarding to build your plan"* is followed by four generic
  promises. She just answered ~45 questions and the payoff names not one
  of her own numbers. **The single biggest first-run miss I found.**
- **Onboarding is ~45 screens** and at least one question
  (`goalWeight`) had no user-visible consequence until today. Auditing
  every question against "what changes because of it" is a session of
  its own.
- **No home-screen widget** (§5).
- **Becoming draws the weight number and its chart twice**, ~700pt
  apart. Observed, not fixed: the tile is a different door (the weight
  page) from the card's own ("read the whole week"), so removing it
  removes navigation.
- **Nothing here can be falsified against a payer.** The measurement
  contract's first clean read still gates every product decision.

**SAFE FOR NEXT BUILD: YES.**
