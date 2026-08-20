# 52 — THE FIRST DAY

**feat/app-v2 · 2026-08-18 · THE ACTIVATION PASS on top of pass 51's
build-33 tree.** One contract, from the brief verbatim: **PURCHASE →
FIRST TRUSTED RECORD → FIRST USEFUL RESPONSE**, within six meaningful
decisions and under three minutes, without buying activation by
weakening truth. NOT archived, NOT uploaded, no deploy, no migration,
no production SQL, no paywall or consult-above-the-wall change.

Every product change below was proven RED first against an
honest-BEFORE stub (§19), and the BEFORE state was FILMED on the real
purchase-shaped path before any source changed (§2).

---

## 1 · THE HARNESS (how "from successful purchase" was made real)

`WallView`'s completed purchase makes exactly two mutations: the
entitlement flips and `postPurchase.firstRunPending` is stamped. The
harness reproduces the instant after that, with everything upstream
REAL:

1. `simctl erase` a non-QA simulator (virgin keychain, all permissions
   `notDetermined`).
2. Run the REAL v8 consult wall-to-wall via the standing walker
   (`testWalkV8ToPaywall`; `TEST_RUNNER_GLP1_COHORT` picks the cohort)
   — the app's own bootstrap mints an anonymous account, the consult's
   own writers store her profile/weight/regimen, and the walk ends ON
   the hard wall.
3. Terminate; stamp `postPurchase.firstRunPending` into the app
   container's own preferences domain; relaunch with
   `--uitest-pro-access` (the standing entitlement door).
4. Walk `Pass52ActivationUITests` — new instrumented legs that
   screenshot every beat and log `P52 <leg> · <beat> · dt · taps`.

The QA sims' standing accounts were deliberately NOT erased (the
pass-50/51 posture); the two film sims (iPhone 17 Pro, 17 Pro Max) were
erased instead. **Production account ledger: 4 anonymous accounts
minted by the app's own bootstrap (2 BEFORE + 2 AFTER), each owning
one consult footprint + this pass's walk records — the same class
`45` observed and `46`'s reaper covers. No SQL was run.**

Legs: A words-first-record (measured end to end) · B photo door · C
weigh-in · D GLP-1 dose action · E kill-mid-corridor relaunch · F
first-estimate failure (`--food-debug-timeout`, the transport's own
URLError at the real seam) · H consent-decline coherence.

## 2 · THE BEFORE FILM (build 33, walked 2026-08-18, ~13:15–13:40 PT)

**The corridor a real v8 payer walks** (both cohorts filmed
identically): forging cascade ("your program is *activated*… let's
*begin*", auto-advances at 7s) → coach intro (v3-era: illustrated
portrait in a pink circle, sparkle burst, ambient music, "DAY 1 WITH
JENI", close = **"today. five minutes. that's all i'm asking."** — a
workout-era promise) → breathwork primer (CTA **"skip to workout"** —
there is no workout next) → the consult's own oath replayed
("tomorrow, at 8am, you'll snap your first real meal." — the consult
itself defers the first record to TOMORROW) → Today tab = onramp
("your plan is here." 159→143 + the EACH-DAY receipt) → **subflow =
the COMMITMENT PAGE ONLY** → HomeView → **THE LETTER presents over
Home** ("day one. one card a day, i count the rest. your file starts
with one plate. add the last thing you ate. — jeni").

**[CORR] on 50 §5 (screens):** the real payer path is NOT "goal-date
reveal → intensity pick → commitment". The pre-wall reveal's own
PacePicker stores `onboardingPickedTier` (even at its untouched
default), so the shipping subflow was ONE page. The 3-page shape
exists only for tier-less arrivals (re-enrollment, account-transition
sweeps, QA fixtures). Measured on the container plist after the real
consult: `onboardingPickedTier = medium`.

**[CORR] on 50 R1 (the notification claim):** "no notification
permission is ever requested on the shipping path" is WRONG. The v8
reveal chain carries the legacy "allow notifications" beat PRE-WALL
(`OnboardingRevealView`, walked + `notificationsEnabled=true` observed
on the container). R1's real defect stands corrected as: **the ask
exists at the weakest possible moment — before she has paid, before
any value, in a chain she is tapping through to reach the wall** — and
there was no post-value moment at all.

**The first record (words), BEFORE, filmed on the erased sim:** center
tab → chooser → typed "greek yogurt with honey and a banana" → count
it → GATE 1 consent primer (photo copy over a typed sentence; drawn
camera-framing teachings) → GATE 2 "before your first plate" (three
question groups) → **THE TRAP, FILMED: the gates exited to the CAMERA
— the iOS camera-permission dialog rose over a typed meal**, her
sentence surviving only as a hidden prefill behind "or write it" →
recovery tap → her sentence auto-submitted → reading (protein-first,
"15 g of 85 g today", "1,200 left today after this") → add it →
filed. **The words-door estimate completed in ~4s on the erased sim's
fresh account — pass 50/51's recorded words-door stall does not
reproduce on a fresh session, which localizes that blocker to the QA
sims' stale keychain sessions, not the pipeline.**

**Measured BEFORE (walker cadence; the walker taps ~2s/beat and reads
nothing, so times are floors, not medians):**

| milestone | dt from post-purchase launch | taps |
|---|---|---|
| corridor cleared (4 beats) | 16.6s | 5 |
| onramp "start my program" | 19.8s | 6 |
| plan committed ("i'm in") | 42.6s¹ | 7 |
| HOME (plan live) | 43.9s | 7 |
| + the letter ("keep it") | +≈5s | 8 |
| chooser open → sentence typed | ≈+7s | 10 |
| consent gate | 54.0s² | 11 |
| questions gate | 57.5s² | 12 |
| **camera trap + OS camera dialog** | 64.3s² | 13 |
| reading arrived (after recovery) | 68.7s² | 14 |
| **record kept** | **72.0s²** | **15** |

¹ ≈18s of that is walker element-search overhead on pages that no
longer existed; a human path is ~8s shorter. ² measured on the
continuation run from Home (dt rebased; add ~44s for the corridor).
**Single-session BEFORE total ≈ 105–115s walker-floor · 13–15 taps ·
8 surfaces before the first possible record.** A reading human
(~8s/screen) lands ~2½–3 minutes — under the wire only if nothing
goes wrong, and the trap sits in the middle of it.

**Decisions BEFORE (words path):** breathe-or-skip · consent ·
the questions page · (+ the record itself) = **3 + record**, plus two
stale promises ("five minutes", "skip to workout"), one category-error
permission (camera over words), and a commitment card promising a
retired product ("today's lesson · 3 min · before lunch", "breathe ·
1 min · before bed").

**Leg C (weigh-in) BEFORE:** Home → "weigh in" tool → ruler → "keep
it" = **2 taps, ~6s** from Home. Already effortless; untouched.
**Leg B (photo) BEFORE:** post-gates, meal door → camera ~3s. **Leg D
(GLP-1) BEFORE:** the consult's own regimen bridge worked — Home led
with "your shot is today · mark it when you take it" (today was her
answered shot day), one tap to the dose sheet (site pre-selected by
rotation, "mark it taken", "only you see this. never named in
notifications."). The GLP-1 payer's first relevant action was already
1 tap from Home + 1 tap to record. The generic corridor stood in
front of it like everyone else's.

## 3 · FRICTION INVENTORY → the classification the brief demanded

| beat | classification | disposition |
|---|---|---|
| forging reveal | KEEP (the receipt moment; auto-advances; carries the paid-price line) | restyled canvas only |
| coach intro | KEEP → becomes THE HANDOFF + jeni's first LETTER | rebuilt (§5) |
| breathwork primer | **DELETE from corridor** (teaching detour; stale CTA; Home's "breathe" tool keeps the surface) | `BreathworkPrimerView` deleted (orphaned) |
| promise confirmation | KEEP (the consult's own oath, replayed once) | unchanged |
| onramp intro | KEEP (the best screen in the path — 50 §14 named it) | unchanged |
| goal-date reveal page | **DELETE** (explainer; only interaction "continue"; unreachable for real payers anyway) | page deleted; ACSM line moved to the pace page |
| pace page (tier-less arrivals) | KEEP — the one real decision | now COMMITS directly ("i'm in") |
| commitment page (real payers) | KEEP — the commit | stale ritual card replaced with true rows |
| THE LETTER | KEEP (it already says "add the last thing you ate") | unchanged |
| consent gate | KEEP (5.1.2(i)) | door-aware copy; exits to HER door |
| "before your first plate" questions | **JUST-IN-TIME → post-first-reading OFFER** | never before record #1; offered once, skippable |
| camera permission | JUST-IN-TIME | now fires only when the camera door is chosen |
| notification permission | JUST-IN-TIME → **the day-one contract card** | after the first record; never at launch |
| HealthKit | unchanged this pass (asked in the consult, above the wall — frozen) | posture documented §11 |

## 4 · WHAT SHIPPED (each RED→GREEN)

1. **The gates exit to the door she chose.** `CaptureGateFlow`
   (new, pure): `landing(entry:prefill:)` — words → words, camera →
   camera, a handed-in sentence → words; `firstPhase(consented:)` —
   consent is the ONLY pre-record gate; `offersQuestionsAfterLog` —
   the three questions offer themselves once, AFTER the first filed
   plate. `CaptureFlowView` wires all three (the `.firstScanOnboarding`
   pre-phase is GONE; a `.questionsOffer` post-log phase replaces it).
2. **Door-aware consent.** `FoodAIConsentCopy` (pure copy authority) +
   `FoodAIConsentSheet(door:)`: the words door leads with "what
   happens to your words" / "your sentence goes to OpenAI's model to
   be counted", still discloses the photo's future trip (one
   acceptance covers the feature honestly), and the three drawn
   camera teachings render on the photo door only. The photo door's
   copy is pinned byte-identical to the reviewed sheet.
3. **The corridor.** `PostPurchaseCorridor.next` (pure) drives
   `PostPurchaseFlowView`: forging → coach intro → [oath] → finish.
   The breathwork primer/session phases are gone from the corridor;
   `BreathworkPrimerView` deleted (it had no other caller);
   `BreathworkSessionView` lives on under Home's "breathe" tool.
4. **The handoff.** The coach intro's close is
   `"say your last meal and i'll count it."` / `"a sentence is
   enough. that's day one started."` (statics, test-pinned; the stale
   "today. five minutes." died). Barrier beats' workout-era copy
   ("every session is guided", "five minutes") rewritten in the
   product's real verbs.
5. **The subflow is ONE page per arrival.** `SubflowPagePlan` (pure):
   tier on file → commitment; tier-less → the pace page, which now
   commits directly ("i'm in") and carries the ACSM line + "day one
   is today.". The goal-date explainer page and the 3-step progress
   track are deleted. The commitment page's day-1 ritual card now
   tells the truth: "tell jeni what you eat · a sentence or a photo",
   steps "offered never owed", "the morning read · tomorrow, built
   from today".
6. **The day-one contract = the notification moment (R1's close).**
   `DayOneContract.decide` (pure, test-pinned): after her FIRST
   record files, one Home card says *"that's on file. tomorrow's
   morning read is built from what you give me today."* and asks
   *"want it as a quiet note?"* (GLP-1 with a consult reminder word:
   *"your shot-day nudge rides the same switch."*). Renders ONLY
   while the OS ask is `notDetermined`, only when a record SHE made
   exists today, answered at most once, ever. Grant →
   `notificationsEnabled` + the orchestrator's once-guard invalidated
   so the anchor ladder arms on THAT refresh +
   `MedicationReminders.refresh` re-derives through the same call.
   Deny (OS or card) → quiet; the card never returns; nothing else
   changes. The OS is re-read on every appear/foreground — never
   remembered.
7. **The correction taught at the first reading.** One quiet line
   under the reading's composer, once ever: *"off? your fix is kept,
   and the next reading starts from it."* (converts the market's open
   correction moat into a first-session lesson; 50 §5.4).
8. **The desk teaches instead of claiming.** The jeni tab's empty
   line is now *"ask me anything about your record. i can read it."*
   (care-connected claim untouched; 3 pins re-pinned to the new
   truth).
9. **The corridor joined the design language (founder steer,
   mid-pass, with screenshots).** The corridor's canvas was the
   v3-era welcome: pink program ground + glossy sticker scatter;
   the coach intro added an illustrated portrait in a pink circle, a
   sparkle burst and ambient music. Per the law (§1.1b: the corridor
   is a MOMENT → editorial serif on paper): the shared canvas is now
   `bgPrimary` paper with no scatter, and the coach intro was rebuilt
   as **jeni's FIRST LETTER** — the same anatomy as the morning read
   (name rule "JENI ——— day one of N", serif greeting/beat/handoff,
   "— jeni" signature) so tomorrow's letter is already familiar. The
   portrait assets and `RitualMusicPlayer`/AVAudio session are no
   longer touched by the corridor; `ForgingRevealView`'s serif
   cascade (her75-sanctioned) survives unchanged on the paper ground.

## 5 · THE AFTER JOURNEY (design; measurements in §6)

purchase → forging (auto, the paid receipt) → **jeni's first letter**
(the handoff arms the sentence) → [her own oath replayed] → onramp →
one commit tap → Home → THE LETTER ("add the last thing you ate") →
center tab → type the sentence → count it → **consent, speaking about
her words, exits BACK to her words** → reading (protein-first + the
answer + the fix taught) → add it → **the questions, as an offer, after
the record is safe** → Home + **the day-one contract card** → one tap
→ the system ask, pre-qualified.

**Decisions AFTER (words path): consent · the questions offer
(skippable) · the notification offer = 3, all offers with honest
declines** (+ the record itself). Surfaces before the first possible
record: forging · letter · [oath] · onramp · commitment · home = 5–6.
WORDS stays WORDS; PHOTO stays PHOTO; the camera dialog can no longer
fire over a typed meal, by construction (`CaptureGateFlow` pinned).

## 6 · AFTER MEASUREMENTS (same harness, same erase-consult-stamp
protocol, iPhone 17 Pro / Pro Max, 2026-08-18 ~14:35 PT)

**Leg A — words first record, single continuous session:**

| milestone | dt | taps | BEFORE |
|---|---|---|---|
| corridor cleared (forging → letter → oath) | 13.9s | 4¹ | 16.6s · 5 |
| onramp "start my program" | 17.0s | 5 | 19.8s · 6 |
| plan committed ("i'm in") | 40.3s² | 6 | 42.6s · 7 |
| THE LETTER read + kept | 42.6s | 6 | (after Home) |
| HOME (plan live) | 45.8s | 7 | 43.9s+letter · 8 |
| chooser open | 51.0s | 8 | 48.0s · 8 |
| sentence typed + submitted | 57.0s | 10 | ~51+ · 10 |
| consent (WORDS copy) shown | 58.1s | 10 | 54.0s (photo copy) |
| ~~questions gate~~ | — | — | 57.5s · 12 |
| ~~camera trap + OS camera dialog~~ | — | — | **64.3s · 13** |
| **READING arrived** | **64.7s** | 11 | 68.7s · 14 |
| **record kept** | **68.0s** | **12** | 72.0s · 15 |
| questions OFFER (post-record) | 69.5s | 12 | (was a pre-record gate) |
| response frame | 74.2s | 13 | — |

¹ the walker double-taps the coach CTA (element-tap flake + press
retry); a human makes 3 corridor taps. ² ~20s of the 23s gap is the
walker searching for pages that no longer exist; a reading human
commits in ~8-10s.

**The activation deltas that matter:** the camera trap is GONE (no OS
camera dialog exists anywhere on the words path — by construction,
pinned); the pre-record gate count fell 2 → 1 (consent only); taps to
record-kept 15 → 12 (walker) / ~13 → ~10 (human); surfaces before the
first possible record 8 → 6 (forging · letter · oath · onramp ·
commit · home). Wall-clock walker-floor ≈ 68s BEFORE-equivalent 72s —
the seconds were never the defect; the trap, the category-error
dialog, the stale promises and the dead gates were, and they are
gone. The reading arrived 6.6s after consent-accept (estimate
round-trip included).

**Leg D — GLP-1:** corridor identical (14.0s/4 taps) → Home 45.6s →
**"your shot is due today. mark it when you take it." found at 47.6s
— one tap from Home** → the dose sheet (site pre-selected by
rotation) → mark it taken. Her first relevant medication action needs
zero navigation beyond the row Home leads with.

**Leg C (weigh-in)** re-ran unchanged: Home → ruler → keep = 2 taps.

**The contract card did not render on legs A/D — CORRECTLY:** both
AFTER consults ANSWERED the pre-wall notification beat (the walker
allows), so the OS ask was already spent and
`DayOneContract.decide` returned `.hidden` on real OS state — the
engine refusing to nag a user who already answered. The card's shown
path is filmed on the SE leg (§13), whose account had never been
asked.

## 7 · DOOR-AWARE CONSENT MATRIX

| entrance | gate copy | teachings | exits to | prompts |
|---|---|---|---|---|
| words (chooser field, jeni's prefill, evening close, method note) | "how jeni counts a meal" / your words | none | HER SENTENCE (auto-submits) | none |
| photo (meal door, snap tool) | "how jeni reads a plate" / the photo | 3 drawn marks | the camera | OS camera, at the camera |
| barcode / label | (modes inside the camera surface — consent already given at the door that led here) | — | camera modes | OS camera |
| weigh-in | none (no third party) | — | the ruler | none |
| dose | none | — | the dose sheet | none |
| again/relog | none (consent given at first log) | — | the recent sheet | none |

One acceptance covers the feature; BOTH variants disclose both
channels, so the order she meets the doors in cannot out-run the
disclosure.

## 8 · PERMISSION MATRIX (the whole first day)

| permission | when asked | by what | if denied |
|---|---|---|---|
| notifications (pre-wall) | the reveal's legacy beat, above the wall — FROZEN this pass, named as residue (§16) | OnboardingRevealView | consult continues; the contract card later stands down (OS ask spent) |
| camera | first CAMERA door only | PhotoCaptureView | words/barcode-less paths unaffected; camera face explains itself; no trap (leg H) |
| notifications (post-value) | the day-one contract card, after record #1, only if still notDetermined | HomeView + `NotificationPermission.request` | quiet; card gone; nothing nags; orchestrator stands down on real OS state |
| HealthKit | the consult's sheet (above the wall — frozen) | V8 flow | manual paths first-class: ruler weigh-in, words food, manual move |
| ATT | the consult's plan-build loader (frozen) | BuildingPlanLoadingView | nothing user-visible |

Notifications are never scheduled to "prove machinery": the grant arms
the EXISTING ladder/reminders through the existing refresh path only.

## 9 · GLP-1 PATH

The consult's own bridge already builds her regimen (v24 chokepoint) —
filmed: Home leads with "your shot is today · mark it when you take
it"; the dose sheet is 1 tap; site pre-selected; "mark it taken".
Pass 52 added NOTHING to the regimen model (G1/G2 remain pass 53's,
per the brief): no interval model, no split dosing, no history. The
contract card's only GLP-1 branch is one sentence about the shot-day
nudge, shown only when her consult asked for reminders
(`onb_med_hour != none`), never medication-naming (the reminder copy
itself remains the never-named v24 law). Blocked-for-53 documented:
N-day intervals, split doses, `treatmentStartedAt`, per-event mg —
the consult asks none of these, so no question was added whose answer
the model cannot store.

## 10 · NON-GLP-1 PATH

Identical corridor; zero medication pixels (the onramp's medication
row and Home's dose row render nil; the contract card's ask is the
plain variant). Filmed as leg A.

## 11 · HEALTHKIT

Not made a prerequisite anywhere: the corridor, gates, first record,
and contract card never touch HK. The consult's union ask (above the
wall) is unchanged and FROZEN per the brief; pass 50's H1-H3
(unrendered resting HR, unwired menstrualFlow) remain P2s for 53 —
no new types requested, no broadening. Manual entry remains
first-class on every door (leg C's ruler; the words door; manual
move). Pass 51's import law (typed-over-Health becomes HERS and the
importer stands down) re-ran green in this pass's regression gate.

## 12 · NOTIFICATION MOMENT — proofs

- notDetermined + record today + unanswered → card shows (pinned).
- record absent → hidden (pinned: "a promise about nothing is a nag").
- OS resolved (granted OR denied, incl. changed in Settings while
  backgrounded) → hidden; re-read on every appear/foreground.
- answered once → never again (device-scoped stamp, deliberately not
  identity-swept: the permission it mirrors is a device fact).
- grant → ladder armed same-refresh (`invalidateRefreshGuard` — found
  while wiring: the orchestrator's once-per-state guard would have
  silently deferred a freshly-granted ladder to tomorrow), dose
  reminders re-derived through the same refresh; deny → nothing
  scheduled, nothing renders, nothing nags.
- copy: voice-lawful (no em-dash, no "AI", lowercase, no streak
  language) — swept in tests.

**FILMED (leg G, SE):** the card standing over a real record → "yes,
a quiet note" → the SYSTEM dialog → Allow → the card gone, asserted
never-returning (`G_card` / `G_system_dialog` / `G_after_grant`).
**The OS-resolved stand-down was filmed the other way on the two
erased sims:** their consult walks answered the PRE-WALL beat, so the
card correctly never rendered — the engine refusing to double-ask a
person the OS has already answered for. The v8 pre-wall ask itself is
above the wall and FROZEN this pass; its existence corrects pass 50's
"no ask exists on the shipping path" (§2), and its weak placement is
now compensated for by the post-record moment for everyone who
declines it — the population R1 was actually about.

## 12b · THE FIXTURE-ONLY COVER RACE, named

On the standing QA-SE account (enrolled, letter eligible) a manually
stamped purchase flag can race HomeView's letter cover and lose the
corridor presentation. **No real payer can hold that state**: a fresh
payer has no plan (the letter gates on enrollment), and a lapsed
re-purchaser with history never receives the corridor stamp
(`shouldShowOnPurchase(hasExistingActivity:)` suppresses it). The
harness drives those legs with the standing `--uitest-suppress-letter`
door; recorded so the next walker does not rediscover it.

## 13 · SE / STANDARD / AX5 EVIDENCE

- **Standard (402/430pt, iPhone 17 Pro / Pro Max):** the full AFTER
  loop filmed twice (legs A, D) — corridor, letter, onramp, commit,
  chooser, words consent, reading, offer, dose sheet.
- **SE (375pt, standard type):** the full loop WALKED to record-kept
  (85.2s) — corridor 2 taps, consent, reading, offer, the contract
  card standing (below the fold on 667pt — reachable, filmed in
  leg G). Home renders clean (the earlier SE frame: shot row, floor
  ring, day band, dv rows all whole).
- **SE at AX5 (the harshest combo):** the walk surfaced TWO defects
  and both were FIXED and re-shot this pass:
  1. **THE LETTER (JKReadingDay) had no scroll container** — the
     pass-48 defect class on the first-day surface: the serif hero
     compressed into tail-truncation ("your first d…"), the dateline
     wrapped mid-word ("tuesd/ay"). Fixed with the min-height scroll
     law (visually identical when content fits) + never-wrap dateline.
  2. **My own new coach letter had the same disease** ("you made i…",
     "say your la…") — the walk caught the pass's own surface within
     the hour. Same fix + the name rule STACKS at accessibility sizes
     ("JENI / day one of 140", re-shot whole).
  - The chooser at SE+AX5 keeps its doors whole; the words field sits
    above the fold-line and reaches by the bottom-anchored scroll
    (its own E7 machinery); the walker cannot synthesize that scroll
    (the repo's recorded sim limitation) so the AX5 words walk stops
    at the chooser — stated, not scored.

## 14 · RELAUNCH / INTERRUPTION

- **Kill mid-corridor (leg E, asserted):** one beat in, killed,
  relaunched — lands coherent on the shell; the ceremonial corridor
  does not re-run (its flag is one-shot by design) and nothing is
  trapped. The oath and coach beats are ceremony, not state: nothing
  a death here can corrupt.
- **Kill at the consent gate (filmed):** app killed with the gate up
  → relaunch → Home whole; the gate simply returns at her next food
  door (flag unset until accept).
- **Relaunch after the first record (leg A's own D2-pattern):** the
  record survives (the P51 journey re-ran green — §15); the letter's
  once-per-day stamp holds; the answered contract card never returns
  (leg G assertion).
- **The OS ask mid-flight:** the card's grant flow re-reads real
  authorization on every appear/foreground — a Settings change while
  backgrounded is honored on return (engine-pinned).

## 15 · PASS-51 REGRESSION GATE (activation may not outrank truth)

- **Full app suite SOLO: 1398/1398, 2 skipped (the standing
  env-gated pair), 0 failures** — 1386 (pass 51's count) + 12
  (`FirstDayActivationTests`) exactly. Includes untouched-green:
  `RecordMustNotLieTests` (typed-over-Health stands), `WeightOneStoryTests`
  (canonical readers), `DayKeyVocabularyTests`, `FieldPreservation`'s
  app-side kin, `DeletionContractTests`, `RecordRepairTests`,
  `AppPhaseTests`, the golden calorie matrix, upgrade-boundary suite.
- **DayKeyVocabularyTests under `-testLanguage ar -testRegion SA`:
  3/3** (both-locale law re-proven).
- **PlankSync 29/29 · PlankFood 225/225** (215 + 10 new, exactly).
- **The pass-51 flagship sim journey re-walked green (64s):**
  weigh-in kept → listed as HERS → removed → relaunch (hydrate +
  import both run) → still gone.
- One earlier full-suite invocation died mid-run while three
  simulators walked concurrently (221 executed, 0 failures, runner
  lost) — re-run SOLO per the repo's own law; the solo run is the
  gate. **`Executed 0 tests` did not fire this pass; the count
  arithmetic (1386+12, 215+10, 29+0) was checked instead.**
- **Re-run once more at the FINAL tree** (after the letter-scroll,
  rule-stack and chip-grammar fixes): 1398/1398 (2 skipped) ·
  PlankFood 225/225 · PlankSync 29/29. **Release configuration BUILD
  SUCCEEDED** on the final tree.

## 16 · REMAINING P0/P1 + NAMED RESIDUE

**P0: 0 known.**
**P1, named with owners:**
1. **The pre-wall notification beat** (OnboardingRevealView) still
   asks before value for every v8 payer — above the wall, FROZEN by
   this pass's own brief. The post-record contract card now catches
   everyone who declines it; moving/removing the pre-wall beat is a
   consult-side decision for the founder (it would also raise the
   contract card's reach from decliners-only to everyone).
2. **Pass 51's §18 items stand unchanged** (regimen/facts authority
   branches, day_progress retry, weekly_reads hydrate, insert-only
   edit propagation, G1/G2 → pass 53).
**Residue, named:**
- The AX5 chooser's words field needs the hand-scroll (walker-only
  limitation; the machinery is the E7 bottom-anchored scroll).
- The contract card sits below the fold on SE — visible after one
  natural scroll; acceptable, noted for a future Home-order pass.
- `coachIntroAudioPlayed` analytics event now has zero emitters (the
  music died with the portrait); the enum case stays for history.
- The questions sheet's `asOffer: false` framing ("before your first
  plate") is now reachable only from code that never mounts it — the
  Settings food editor has its own form; deleting the old framing is
  a one-line cleanup left with the sheet's next owner.

## 17 · DELIBERATELY NOT CHANGED

The wall and everything above it (paywall, consult, the pre-wall
notification beat — named, not touched). The onramp intro. THE
LETTER's presentation. The reading's corridor (no interstitial touches
gesture→reading). `startProgram`. The regimen model (G1/G2 → 53). The
usuals system (53). HealthKit asks. The trigger fold. No App Store
metadata, no analytics vendor work, no monetization change. The
promise phase's ticket internals (only its parent canvas changed).
Pass 51's record architecture — untouched and re-proven (§15).

## 18 · FILES CHANGED (mechanically enumerated by `find -newer` against
the pass anchor; 19 modified + 1 deleted + pbxproj)

**PlankFood (5 src, 1 test):** `CaptureGateFlow.swift` (new — the
door-law engine + consent copy authority) · `CaptureFlowView.swift`
(gates exit to the door; questions → post-log offer) ·
`FoodAIConsentSheet.swift` (door param, copy from the authority,
teachings photo-only) · `FoodOnboardingSheet.swift` (offer variant +
"not now") · `SnapResultView.swift` (the one-time fix-teach line) ·
`FirstRecordGateTests.swift` (new).
**PlankApp (9):** `PostPurchaseFlowView.swift` (corridor table + paper
canvas; breath phases gone) · `CoachIntroView.swift` (jeni's first
letter; handoff; portrait/music/scatter dead) ·
`ProgramSetupSubflow.swift` (one page per arrival; explainer page
deleted; truthful commit card) · `HomeView.swift` (the day-one
contract card + OS-state reads) · `DayOneContract.swift` (new) ·
`NotificationOrchestrator.swift` (guard invalidation only — named,
not smuggled: the grant must arm the ladder it just earned) ·
`AnalyticsHygiene.swift` (the new event family registered, per its own
law) · `JeniDeskAwareness.swift` + `JeniChatView.swift` (the desk's
teaching line).
**Deleted:** `PlankApp/Views/Welcome/BreathworkPrimerView.swift`
(corridor was its only mount; `BreathworkSessionView` lives on under
Home's breathe tool).
**Tests:** `FirstDayActivationTests.swift` (new) ·
`JeniDeskAwarenessTests.swift` (3 pins re-pinned to the new copy).
**Harness:** `Pass52ActivationUITests.swift` (new; legs A–H).
**pbxproj:** registrations for the 4 new files + the primer's removal.

## 18b · PROTECTED PATHS

Payment · Paywall · Auth · AppPhase · Info.plist · entitlements ·
widgets · `supabase/` (schema, migrations, Edge Functions) · every
`@Model` file — **EMPTY this pass** (no store migration exists to
fail). Everything above the wall (consult, reveal chain, its
notification beat) — EMPTY. Named touches outside the historical
quiet set, each for this pass's own law: `NotificationOrchestrator`
(+9 lines, guard invalidation), `AnalyticsHygiene` (+7 lines, event
registry).

## 18c · PRODUCTION MUTATIONS + MIGRATIONS

**No SQL run, no deploy, no migration, no schema read.** Four
anonymous production accounts were minted by the app's own bootstrap
on the two erased film simulators (two BEFORE, two AFTER) — the exact
mechanism `45` observed and `46`'s reaper covers; each owns its
consult footprint (profile · onboarding weigh-in · GLP-1 regimen where
applicable) plus this pass's walk records (a plan, a food log, a
weigh-in, a marked dose), all written through shipped paths. The QA
sims' standing accounts took the same walker-class seeds every pass
takes. Nothing was hand-written to any production table.

## 19 · RED→GREEN LEDGER

- `FirstDayActivationTests` (app): **RED 10 failures / 12** against
  honest-BEFORE stubs (corridor routed through the primer; pace page
  didn't commit; no contract card; stale handoff). The 2 that passed
  are hidden-expecting controls — a decide() stubbed to refuse
  everything passes refusal tests, the standing lesson, recorded
  again. GREEN 12/12 after the real engines.
- `FirstRecordGateTests` (PlankFood): **RED 7 failures / 10** (gates
  exited to camera; questions gated; one copy for both doors;
  teachings over words). The 3 passers are controls (camera-door
  landing, photo copy byte-pin, consent-first). GREEN 10/10.
- `JeniDeskAwarenessTests`: 3 pins re-pinned to the new teaching line
  (the change IS the copy; the suite caught it exactly as pins
  should). 15/15.

## 20 · EVIDENCE LOCATIONS

`docs/app_v25/52_evidence/` (uncommitted, the pass-50 pattern):
before/ (the filmed trap, the old-theme coach intro, the GLP-1 sheet),
after/ (door-aware consent, the reading, the post-record offer, the
day-one letter, the contract card + system dialog + granted, the AX5
letter fixed), adversarial/ (estimate-failed banner, camera-denied
face, kill-relaunch). Full frame sets + trees in
`/private/tmp/jenifit_pass52/` and the session scratchpad's `film/`.
The P52-prefixed beat logs live in the xcodebuild logs quoted in §2/§6.

---

FIRST-DAY ACTIVATION: PASS — a paying stranger reaches a true record through her own door, is answered from it, and is offered (never charged) everything optional
PURCHASE → FIRST ACTION: the sentence is armed in the coach's letter before Home is seen; the letter re-asks it; the centre tab is standing (walker floor 51s incl. ~20s search overhead; human ≈ 45-60s of reading)
PURCHASE → FIRST TRUSTED RECORD: 68s walker floor · 12 taps (BEFORE 72s · 15 taps · through a camera trap); weigh-in Home+2 taps; GLP-1 dose Home+2 taps
PURCHASE → FIRST USEFUL RESPONSE: the reading answers in the same breath (protein of her floor + "1,200 left today after this"), then the contract card names tomorrow's payout
MEANINGFUL DECISIONS: 3 on the words path (consent · the questions OFFER · the notification OFFER) — both offers carry honest declines; BEFORE was 3 gates + 2 stale promises + a category-error permission
WORDS PATH: WORDS STAYS WORDS — consent speaks about her sentence and exits back onto it; the camera cannot appear, by pinned construction
PHOTO PATH: unchanged door, byte-pinned consent copy, camera permission only at the camera
WEIGHT PATH: unchanged (already 2 taps); pass-51 laws re-proven
GLP-1 PATH: the consult's own regimen leads Home ("your shot is today"), sheet in 1 tap, marked in 2; no new model questions asked (G1/G2 → 53)
PERMISSION DENIAL: consent decline → Home whole (asserted); camera denied → honest face + "or write it" (filmed); notification deny → quiet forever; estimate dead → banner over her preserved sentence (asserted)
NOTIFICATIONS: R1 CLOSED as a product moment — the day-one contract card after record #1, notDetermined-gated, once-ever, grant arms the existing ladder same-refresh (filmed end to end); [CORR] pass 50: a pre-wall ask DOES exist and is named P1 residue
HEALTHKIT: untouched, never a prerequisite; manual first-class on every door; typed-over-Health law re-proven green
SE: full loop walked to record-kept; layouts whole
AX5: two truncation defects found (the letter had no scroll container — the pass-48 class — and this pass's own new letter repeated it), both fixed and re-shot whole
PASS-51 REGRESSION: 1398/1398 solo (2 skipped) · ar_SA 3/3 · PlankSync 29/29 · PlankFood 225/225 · the weigh-in journey re-walked green — activation bought nothing from truth
PRODUCTION MUTATIONS: none by hand; 4 walker-class anonymous accounts via the app's own bootstrap, named in §18c
MIGRATIONS: none — @Model zero-diff, no store migration exists to fail
P0 REMAINING: 0
P1 REMAINING: the pre-wall notification beat (founder's consult-side call) + pass 51 §18's standing five
SAFE FOR PASS 53: YES — the usuals/memory surfaces this pass deliberately did not build have their seams intact (corrections channel untouched, the offer sheet reusable, the letter now scroll-safe)

— end of pass 52 —
