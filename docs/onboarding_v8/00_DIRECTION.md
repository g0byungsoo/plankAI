# Onboarding v8 — THE CONSULT (direction + build law)

2026-08-05. Founder brief, verbatim in intent: **forget the current
onboarding** — order, transitions, questions, assumptions. The
engineering, backend and architecture are done; this session builds
one of the best onboarding experiences on the App Store. Two jobs
only: convince the user they have a real problem; convince them Jeni
is the best solution. Sell transformation, never features
(consistency not calorie tracking, visible progress not body
scanning, confidence not AI, understanding not macros). The product
has evolved: Jeni is a **universal Body Transformation platform**
(B2C weight loss + B2B clinic patients). The language becomes
**universal — never feminine, never masculine. Premium. Calm.
Scientific. Human.** Every screen fights for its life; every answer
must change something later; onboarding + paywall are one funnel.
A reference video (motion benchmark) was reverse-engineered
frame-by-frame; Jeni must reach the same motion quality with its own
identity. Verify in the simulator, frame-by-frame, repeatedly.

## 1. What the reference does (decoded at 60fps, corrected to 1×)

The reference is a **conversation, literally rendered**. Its grammar:

1. **One surface, two states.** A near-black consult surface for
   dialogue; a deep-brand chapter surface for declarations and
   evidence. Transitions are IN-PLACE color crossfades (~450ms);
   chrome persists; nothing ever pushes or slides.
2. **The typewriter voice.** Every app utterance types char-by-char
   (~14-18 chars/s, pauses at punctuation), holds ~600ms, then dims
   to ~45% and rises to a "previous" slot as the next line types at
   the active slot. Older lines fade to ~18%, then out. Max two
   history lines visible. New typing overlaps the old line's rise.
3. **Questions that need UI rise to the top.** The question travels
   from the active slot to the top of the screen; a caption ("select
   all that apply") fades in; option cards fade+rise in as a group
   (~350ms, slight stagger); the ghost continue pill arrives last.
4. **Answers live inside the transcript.** Name entry is a bare
   caret in the conversation column (no field chrome), keyboard
   slides up, typed text renders as dialogue.
5. **Everything is acknowledged.** After every answer the options
   dissolve and the app replies in words that echo the choice
   ("Hello Yu, it's great to meet you!" · "Just exploring? That's a
   great place to start."). The acks are the soul: proof of
   listening, delivered at conversational cadence.
6. **Evidence on the chapter surface.** Big stat + caption + source
   line + illustration; cards dissolve between (never slide); dots.
7. **The opening ritual.** The logo mark draws itself on black →
   the surface warms to brand color → the mark shrinks to a corner
   (a live shared element) → the headline types → subtitle fades →
   a numbered promise staggers in one-by-one → CTA last.
8. **Ambient life.** Chapter surfaces carry slow-drifting soft
   blooms. Nothing is ever perfectly still.

## 2. The Jeni translation (identity, inverted)

The reference types white on black. **Jeni writes ink on paper.**
That inversion is the whole identity move:

- **Consult surface** = paper (`Palette.bgPrimary`), jeni's lines in
  `JeniHeroSerif` 30pt — the serif IS her written voice (the chat's
  letter register, promoted). The typewriter becomes *jeni writing
  to you*.
- **Chapter surface** = ink (`Palette.bgInverse` #2A1F1E), paper
  type (`textInverse`), for: the arrival, the mirror, evidence, your
  file. Chapters DECLARE via the her75 line-cascade (line-by-line
  rise, soft tick per line) — a register distinct from the consult's
  char-typing. Ultra-soft warm blooms (textInverse ≤4%) drift on
  mutually-prime orbits (self-driven `.task`, Canvas law).
- **The arrival ritual** = the official JeniMark revealing under a
  soft directional wipe on ink (the mark is a raster: wipe + settle,
  never redrawn artwork), then the first typed line. One-colour law
  holds everywhere.
- **Selection language** = JeniSurface soft cards; press = spring
  compression (JeniPressable); selected = ink fill, paper text.
  Multi-select rows carry JeniCheck-style marks; one ink pill.
- **Haptic grammar**: tick per option select, ruler detent and
  cascade line; land on ack landing; swell exactly once (the hold).

## 3. Register (supersedes v7's her-register in onboarding)

Universal, premium, calm, scientific, human. Lowercase jeni voice;
italic punch by composition only; no hearts; no em-dashes between
words; no "AI"; question+reason on sensitive asks; no controlling
verbs; gain-frame. v7's four laws still bind: **persona** (now
routing-only: physiology beats + formula; register is universal for
everyone), **consequence** (every ask changes plan/experience or
dies), **evidence** (number + unit + named source; only the vetted
chips — nejm step 1 lean-mass · jama 2025 discontinuation · hayashi
2023 food-cue · wycherley 2012 protein · acsm 0.5-1%/wk band ·
morgan 1999 SCOFF · fda benchmark/dpp 5-7%), **register** (clear
beats charming; zero wit on safety/billing). Compliance floors
(glp1_strategy): no drug brand names, no equivalence claims, no
first-party numeric weight-loss claims. Data provenance: every
number traces to a collected field; the answer count is computed.

## 4. The machine (what survives, what dies)

**Survives byte-for-byte:** `OV5Store` (every AppStorage key, the
mirrors, assembleData, the v4.5 completion contract), the reveal
pipeline (`beginReveal → OnboardingRevealView cover →
completeAfterReveal → onComplete`), the wall as its own phase,
anonymous-first auth, the sign-in door, ATT-mid-loader, analytics
event names (`ov5_step_advanced` etc.; `onboarding_version: v8`).

**Dies:** every OV5 screen file's composition, the OV5Step order,
GrainfieldBackground-under-cards, the per-screen dissolve
transition model, the act eyebrows, the receipts-as-screens, the
her-register photo grid.

**The new host:** `OnboardingV8Flow` mounts ONE continuous
`V8Stage`. Paper stretches render a **beat feed** (typed utterances,
inline inputs, acknowledgments) — step boundaries are invisible;
the transcript flows across them. Structured moments (snap demo,
rulers, safety gate, signature, healthKit, hold) mount inside the
same surface without a push. Chapters flip the surface in place.

## 5. The flow (beats; store key in parens; Δ = branch)

**ACT 0 — ARRIVAL (ink)**
A1 arrival: mark wipe-on → "i'm jeni. i build body transformations
   that hold." → begin · quiet sign-in door.

**ACT I — THE CONSULT OPENS (paper)**
C1 hello lines (auto-advance) → C2 name (name; skippable; ack
   echoes) → C3 outcome "what are you here to change?" (outcome;
   per-answer ack) → C4 history "have you done this before?"
   (onboardingPriorAttempts; ack normalizes: systems, not effort)
   → C5 food "how does food feel, day to day?"
   (onboardingFoodRelationship; loud answers get the hayashi
   mechanism ack).
CH1 mirror (ink): what we know so far — name + outcome + history
   mirrored in 2-3 cascade lines; "none of this is a willpower
   problem." → "here's how this works."

**ACT II — METHOD + COHORT (paper)**
M1 medication "are you using a weight loss medication?"
   (onboarding_glp1_status) Δ current: phase (glp1_phase) →
   appetite rhythm (onb_v5_appetite_rhythm) → shot day
   (onb_v5_shot_day, skippable) → muscle-math ack + nejm chip.
   Δ past: stop window (stop_window) → appetite return
   (appetite_return; warm ack) → jama regain ack. Δ considering:
   agency ack ("the plan doesn't require it"). Δ no: through.
M2 cadence (onboardingEatingCadence) → M3 dietary (onboarding_
   dietary, multi) → M4 cuisine (onboardingCuisinePreference,
   multi) → M5 supports (onb_v5_supports, multi, skippable).
M6 snap demo — "let me show you how i read a plate." (real
   pipeline, restaged in-conversation; writes snap_demo_meal).
M7 protein teach ack + wycherley chip (cohorts without muscle-math).
CH2 evidence (ink): counting numerals + vetted chips only; then
   "now let's make it yours."

**ACT III — THE NUMBERS (paper; rulers arrive under the question)**
N1 bridge line (typed, not a screen) → N2 formula ask (onb_v5_
   gender → onboardingGender; neutral ack = conservative formula
   truth) → N3 age → N4 height → N5 weight (rulers; unit toggles;
   warm ack after weight) → N6 trend (onboarding_weight_trend) →
   N7 direction (onboarding_goal_direction) → N8 goal ruler
   (skipped on maintain) + reframe ack: computed weeks + acsm band
   → N9 movement → N10 sleep → N11 stress → N12 beyond-the-scale
   multi (onboardingNsvPriority) → N13 conditions
   (onboarding_medication_status) → safety gate (SCOFF + pregnancy
   where applicable — quiet clinical, morgan 1999 byline, zero wit).

**ACT IV — THE PART NOBODY ASKS (paper → ink)**
P1 hormonal (non-male; onboardingHormonalStage) → P2 identity
   "which version of you is this for?" (onb_v5_identity; typography
   cards, universal) → P3 fears "tap any that are yours." (one
   multi writes all five onb_fear_* keys; strike-render on tap;
   ack: "the plan answers each of these.") → P4 attribution
   (onb_v5_attribution, quick).
CH4 your file (ink): dossier assembles — cohort noun, protein
   floor, nsv picks, computed answer count.
P5 signature: consents + medical ack (D4 wiring intact) →
P6 healthKit ask → P7 hold-to-build (swell) → reveal → wall.

**Cut and folded (≈14 screens):** welcome collage, antiShame,
credibility, foodNoise + preEat (teach-only; foodNoiseLoudness
derives from foodRelationship — verified), regainTruth +
consideringAgency screens (→ acks), numbersBridge + careBridge
(→ typed lines), dataMirror + three receipts (→ chapters), fears
1-2-3 (→ one multi), targetReframe screen (→ ack), herFile screen
(→ chapter). No key a downstream consumer reads goes unwritten.

## 6. Motion law (numbers are binding until THE LOOP amends them)

- type: 30ms/char; `,` +180ms; sentence end +350ms; next line of
  same beat +450ms; ack begins 150ms after options dissolve.
- transcript: active slot anchored ~30% from top; advance = spring
  (0.55/0.9), previous dims 1.0 → 0.42 → 0.16 → out.
- options: 240ms after question completes; group fade + 6pt rise,
  50ms stagger; selection holds 180ms before dissolve (fade + 8pt
  down, 200ms).
- question-rise (rulers/grids): to top slot, spring 0.6; history
  fades out beneath.
- surface flip: 500ms crossfade in place; chrome persists and
  re-inks; never a push, never a slide, anywhere.
- chapters: cascade 350ms/line + tick; evidence numerals count on
  arrival; dissolve between evidence pages.
- tap anywhere: typing → complete instantly; complete + no input →
  advance. Back chevron re-mounts fully-typed (never re-types).
- Reduce Motion: whole-line fades, still blooms, 200ms flips.
  VoiceOver: full text posts on arrival (typing is visual only).
  Dynamic Type: relativeTo scaling; transcript scrolls at XXL.

## 7. Verification (law §11 applies in full)

THE LOOP after every act: drive → record → dump frames → compare
neighbours → fix → repeat, until no obvious issue remains. Legs:
generalWL + current + past cohorts, male + neutral personas, Reduce
Motion, XXL, SE class. Unit suite + router tests updated to v8
routing. Walker updated to the conversation (tap-to-complete makes
legs fast). Frame-proof required for: the arrival wipe, a full
typewriter beat, the dim-advance, an option dissolve → ack, a
surface flip, an evidence count, the hold seal.

## 8. Success criteria

1. Watching Jeni's onboarding next to the reference reads as equal
   craft with a different soul (ink on paper, serif, one colour).
2. Every answer is visibly received (ack or mirrored later); zero
   Barnum lines; zero dead questions.
3. The two jobs land: the problem is named as systemic (not
   effort), and the solution is transformation (consistency,
   understanding, visible progress, care-grade guardrails).
4. Universal register throughout; persona touches physiology only.
5. Store contract intact: same keys, same reveal, same wall, same
   funnel events with `onboarding_version: v8`.
6. The gate: would Apple ship this? Frame inspection says yes.

## 9. Founder steers (2026-08-06, mid-build — binding amendments)

1. **Register: everyday, succinct.** Straightforward everyday
   language, lightly gen-z but professional and clinic-safe. Not
   poetic. No aphorisms, no mirrored clauses, no metaphor doing a
   fact's job. Short sentences, plain verbs, concrete consequences
   ("noted. short sleep raises appetite, so the plan accounts for
   it."). Applied across the script 2026-08-06.
2. **The two jobs argue with animated numbers and charts.** Drawn
   evidence rides the conversation and the chapters (V8Figures):
   rebound curve on the repeat-starter ack (job 1), noise wave on the
   food-noise acks + evidence page (job 1), muscle-composition bar on
   both protein teaches + evidence page (job 2), half-dots for the
   jama discontinuation stat (job 2), and HER projection curve
   drawing under the goal acknowledgment with computed lb + weeks
   (job 2, the money moment). Everything draws; numerals count;
   provenance law unchanged.
