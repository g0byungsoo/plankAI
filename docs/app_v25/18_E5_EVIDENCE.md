# E5 — THE FIRST PLATE: the loop's record

2026-08-11 · branch feat/app-v2 · rides RC 1.2.0 (30) · **no migration,
no EF deploy, no price change.** `17_E5_DECISION.md` is why this era;
this document is what shipped, what it was walked against, and what is
still open.

---

## 1 · WHAT SHIPPED

### B1 — THE PROOF PHASE

`AppPhase` gains `.proof`, mounted between `.onboarding` and `.wall`.
`derive` stays pure; the table (`AppPhaseTests`, +9 rows) now pins the
closed set of people who must NOT get the beat:

| state | routes to | why |
|---|---|---|
| new, unpaid, flag on | `.proof` | the era |
| resolved `.logged` | `.wall(.afterProof)` | offered once |
| resolved `.skipped` | `.wall(.fresh)` | offered once |
| `wasEverEntitled` | `.wall(.expired)` | a lapsed payer gets the welcome-back wall, never a freebie |
| `hasLegacyFootprint` | `.wall(.fresh)` | they already had the app |
| `hasPro` / `hasCareEntitlement` | `.main` | already past the ask |
| flag off | the byte-for-byte pre-E5 gate | D6 |
| auth mid-transition | holds `.proof` | an identity swap must not yank the camera out from under someone's lunch |

`FirstPlateFlow` mounts the REAL `CaptureFlowView` — the same one every
other caller uses, so the Apple 5.1.2(i) consent sheet, the scan
deadline, the retry card and the refine loop all come for free. The
plate is persisted through the real `FoodLogPersister` under her real
user id: **if she subscribes later, her first plate is already in the
record she opens.**

Whether a plate landed is decided by asking the RECORD (plate count
before vs after), not by trusting a callback — `CaptureFlowView`
dismisses identically on "log it", on close, and on a declined consent.

### B2 — WHAT IT MEANS

`FirstPlateReadingEngine` — a pure engine with a 12-case honesty table:

- protein leads; kcal speaks only when protein cannot; `it's on file`
  when neither can
- **no floor without a weight on file.** No weight → no meaning, no
  provenance, and the invite renders its floorless face
- fractions render in coarse WORDS (`about a third of your day`), never
  a percentage — the vision pipeline is ±30% (r2) and a percent claims
  precision it does not have
- no verdict words (11 pinned), no em-dash, no capital opener
- the floor itself is `TargetsService.proteinTargetG` — the same
  formula Today, Becoming, the reading and chat render. One formula,
  five surfaces.

### B3 — THE WALL, EARNED

`WallReason.afterProof` follows `ExpiredWelcomeView`'s existing
two-state precedent (say the true thing, then show the same plans), so
**`PaywallView` is not touched at all**. Price, tiers, bands, the
downsell ladder, the exit-intent chain and the stand-down are unchanged.
The opening beat carries her plate's photograph and three receipt rows
(`you logged` / `which is` / `against your floor`).

### B4 — THE SCAN CHOOSER, REDESIGNED

The founder pointed at this screen. Rebuilt against the four structural
faults recorded in `17_E5_DECISION` §5.2:

| before | after |
|---|---|
| white card → grey tile → drawing (card-in-card) | art sits on the card's own paper at real scale |
| three capsules in a ring, reading as an audio waveform | her own last plate's **photograph**; the drawn fallback is the scan tab's corner brackets around a plate — a picture of the ACTION |
| a heavy black torso, the loudest object on screen | an outline figure with the measured band across the waist |
| card · card · capsule pill · circle (four geometries) | card · card · card · circle (two) |
| vertically centred with a void beneath | bottom-anchored in the thumb zone, close tight to the group |
| `ultraThinMaterial` + 12% ink → grey noise | material + an ink gradient; the page behind stays legible |
| body first | **meal first** (frequency, and the thesis) |

Jeni's own idea, and the part that is not borrowed: **the doors are made
of her record.** The meal door wears her photograph; the again door
names the dish (`again · chicken poke bowl`). The body door stays drawn
on purpose — body privacy (L4) says her scans are not chooser art.

The meal door prefers the last *photographed* plate rather than the last
plate: a meal logged in words has no photo, and falling back to a
drawing because yesterday's last entry happened to be typed would hide a
record she actually has.

### B5 — FIXES FOUND BY LOOKING (not by testing)

1. **The consent sheet named a processor that never sees the photo.**
   It said "jeni shares your photo with vision models from OpenAI and
   Anthropic". There is not one reference to Anthropic in any edge
   function or in `PlankFood`; `food-vision` reads `OPENAI_API_KEY` and
   defaults to gpt-5. A consent sheet is the one screen that must be
   exactly true. Corrected.
2. **A QA door made a walker leg vacuous.**
   `--uitest-force-first-plate` overrode the outcome *getter*, so the
   flow could never resolve — `testDecliningLandsOnTheOrdinaryWall`
   passed while the app sat on the invite the entire time. Caught by
   looking at the frame, not the checkmark. The door now clears the
   stored outcome once at launch, and the leg asserts the beat is GONE.
3. **An empty capture is not always a decline.** On a first run a
   dropped network or a denied camera permission looks identical to
   backing out, and the vision call is the one step that can fail
   through no fault of hers. One retry, then resolve. Never a loop
   (pinned).
4. **`--uitest-wipe-food`** (the E4-named QA debt) now also suppresses
   the cloud pull for that launch — the first half-fix deleted locally
   and watched 16 plates hydrate straight back in.

---

## 2 · THE DESIGN LOOP (what changed between passes)

Every surface below was implemented, run in the simulator, captured,
critiqued and fixed. The passes are recorded because the deltas are the
argument.

**The invite, pass 1 → 2**
- an em-dash shipped in body copy, violating a standing app-wide law.
  Removed, and an engine-level guard test added so the next one fails a
  build instead of a review.
- two body paragraphs said nearly the same thing; the second duplicated
  a promise the wall makes later. Cut to one line.
- the CTA sat 24pt further left than the copy column: `JFContinueButton`
  already applies `Space.lg`, and nesting it inside the gutter
  double-applied it. Moved to a `safeAreaInset` and the left edge now
  agrees.
- the composition was centred and read as two disconnected halves.
  Bottom-anchored into one block; all the air moved above it.

**The chooser, pass 1 → 2 → 3**
- pass 1 fixed the structure but I stacked `.regularMaterial` + a 42%
  paper wash and **erased the page completely** — the exact failure the
  file's own header warns about, committed a second time. Reverted to
  ink-over-blur; the page behind is legible again.
- the body figure was a magnified silhouette clipped by a window: it
  sliced the shoulders off and ran a rule across the entire card.
  Redrawn whole, band narrowed to sit inside the waist.
- the drawn plate was still weak. Replaced with the scan tab's own
  corner brackets around a plate: the empty state now depicts the
  action rather than the noun.
- the photo's corner radius was not concentric with the door's
  (14 inside 24 at a 14pt inset). Set to 12.

**The after-proof wall, pass 1 → 2**
- the view did `replacingOccurrences` surgery on the reading's sentence
  to fit a receipt row — one copy edit away from rendering a fragment.
  The engine now composes a tested short form.
- it stated her plate without showing it. Added one 68pt thumbnail of
  her own photograph — the only image the wall carries.

---

## 3 · VERIFIED

- **857/857 app unit tests** (+27 this era: 9 gate rows, 11 reading
  honesty, 7 state) · **125/125 package** · zero regressions.
- **`FirstPlateWalkUITests` 4/4**, run solo: the invite with a floor,
  the invite without one, decline → the real wall with live tiers,
  start → the real consent sheet.
- Frames inspected for: the invite (both faces), the chooser (photo /
  drawn / empty), the after-proof wall (with and without a thumbnail),
  the consent sheet, the paywall after a decline.

### Adversarial states walked or pinned

| state | behaviour |
|---|---|
| no weight on file | floorless invite; no invented number (asserted in the walker) |
| capture closed with nothing logged | one retry, then the ordinary wall |
| repeated empty returns | resolves, never loops (pinned) |
| a plate logged in words (no photo) | chooser falls back to the last photographed plate; the wall shows no thumbnail |
| lapsed payer | welcome-back wall, never a free plate (pinned) |
| legacy footprint | no proof beat (pinned) |
| clinic-connected | straight to `.main` (pinned) |
| auth swap mid-capture | `.proof` held (pinned) |
| flag off | pre-E5 gate exactly (pinned) |
| relaunch mid-beat | unstamped, so the invite returns — correct, she has not resolved it |

### B2C / clinic behaviour

B2C is the whole subject of this era. **Clinic-connected users are
explicitly excluded**: `hasCareEntitlement` routes to `.main` before the
proof branch is reached (pinned). A patient's entitlement comes from
their provider; asking them to prove anything to a paywall they never
meet would be nonsense.

---

## 4 · UNISEX AUDIT

- Every file this era touched: **clean.** No gendered copy, pronouns,
  defaults or examples. The reading engine addresses "you" only.
- Both server prompts re-checked: E3's fix **held**. The only match in
  `jeni-chat` is the instruction enforcing it ("the person may be any
  sex, any age... never write to a generic woman, never write to a
  generic man"). `food-vision`: clean.
- **Legitimately sex-specific, left alone on purpose:**
  `TargetsService` passes a sex term to Mifflin-St Jeor and already
  handles `.unspecified` correctly; `BreathworkProtocols` cites
  "n=40 women" because that is the study's actual sample. Removing
  either would be inaccuracy dressed as inclusion.
- **Real remaining debt, reported not fixed:** every one of the ~128
  animations in `PlankApp/Workout/ExerciseBankData.swift` is a
  `woman-doing-X` asset. That library is reached (`workout_start`: 203
  users / 90 days) and it is 100% female-presenting. Fixing it means
  either regenerating 128 clips or killing the library — the latter is
  roadmap E3's scope, and doing it here would be exactly the
  uncontrolled expansion the brief warns against.
- QA seeders pin `gender = female` for deterministic physiology in
  fixtures. Noted: the team therefore never *sees* a male or
  unspecified user in a screenshot. Low product risk, real review-bias
  risk. `TEST_RUNNER_GENDER` already exists for the onboarding walker.

---

## 5 · WHAT WAS DELIBERATELY NOT BUILT

- **The chat desk's blank room.** A j-mark, a greeting, three chips and
  ~200pt of dead space above a thin composer, on a surface the founder
  named as a product area. It is the strongest candidate for the next
  era and it is not in this one, because it serves the ~84 people
  already inside and this era is about the ~2,300 who never get in.
- **A second free thing.** One plate. Not a free day, not a free tab.
- **Any price, tier, band or downsell change.** Untouched by design.
- **The EF's ONE clarifying question (E4.1).** Still bundled into the
  already-gated food-vision deploy; it is not an era.
- **Movement, method, clinic UI.** Unchanged.
- **The workout library's gendered assets.** See §4.

---

## 6 · STILL OPEN

- **QA cloud pollution, half paid down.** `--uitest-wipe-food` now holds
  for the launch it runs in, and the after-proof wall was filmed
  through it. The chooser's *again* row still rendered a stale dish in
  one wiped run; the empty meal-door ART is verified, the empty again
  row is not filmed (its condition is a one-line `if let`, shipped and
  walked in E4). Not chased further on purpose.
- **The proof plate's cost.** ≤1 extra vision call per new onboarding
  completion (~15/day at current volume), inside the EF's existing
  30/day per-user and global daily budget caps. Worth a look at the
  `food-vision` telemetry table after the merge.
- **Everything here is unobservable until `feat/app-v2` merges.** Five
  eras deep, that remains the largest standing risk in the project.

---

## 6.5 · PRODUCTION CONFIGURATION (founder steer, 2026-08-11)

**THE FIRST PLATE SHIPS OFF.** The hard-paywall funnel is under an
active production test; proof-before-paywall is a different experiment
and mixing them would make neither measurable — any movement in the
purchase rate could be attributed to either change.

Production order is therefore UNCHANGED:

```
onboarding → hard paywall → purchase / valid entitlement → jeni
```

The flag was rebuilt as an **explicit enable**, not a kill switch:
`e5.firstPlate.enabled`, default **false**. A `disabled` key fails
open — a wiped UserDefaults, a fresh install or a restored backup would
silently ship the experiment. An `enabled` key fails closed. Pinned in
`FirstPlateStateTests` with the old `disabled` key asserted inert.

Both states verified, not just asserted:
- **OFF (production)**: onboarded + unpaid + no flag → the hard paywall,
  captured. No proof beat anywhere in the route.
- **ON (the future experiment)**: `FirstPlateWalkUITests` 4/4, which
  forces the flag on — invite, floorless invite, decline → the real
  wall, start → the real consent sheet.

Nothing else about the era changed. Every path stays built, walked and
pinned, so turning the experiment on later is one key and no code.

---

## 7 · FOUNDER GATES

Standing set unchanged (E3/E4): jeni-chat + food-vision deploys ·
v24/E1 migrations · key rotation · archive/TestFlight 1.2.0 (30) ·
**the merge** · device walk.

New for this era:

1. ~~**The business call.**~~ **ANSWERED 2026-08-11: ships OFF.** See
   §6.5. Not a rejection of E5 — experiment sequencing. Turn it on with
   `e5.firstPlate.enabled` when the hard-paywall test concludes.
2. **Device walk**: the proof beat on real hardware with a real meal —
   the vision call over cellular, the consent sheet, the camera
   permission, and the after-proof wall's thumbnail on a real photo.
3. **Post-merge read**: `first_plate_offered` / `_started` /
   `_completed` / `_skipped{at, resolved}`, and the onboarded → purchase
   rate against the 5.8-10.5% band recorded in `17_E5_DECISION` §1.1.

---

## 8 · WHAT SHOULD PROBABLY COME NEXT

1. **THE DESK** — chat as the way into the whole product rather than a
   blank room (§5). MeAgain's global "+" sheet is a better answer than
   what Jeni ships, and E3 already built the tools behind it.
2. **E4.1 + the deploy** — the ONE clarifying question, riding the
   food-vision push that is already gated.
3. **Then re-read the numbers.** If the proof beat moves the purchase
   rate, the population that reaches E1-E4's intelligence grows by an
   order of magnitude and the roadmap's original ordering (dispersal,
   movement, the queue) starts making sense again for the first time.
