# JeniFit Workout Session Rules

Source of truth for the WorkoutGenerator, the routine session UX, and the voice
coaching system. When implementations diverge from this doc, this doc wins —
update the doc, then update the code.

Last updated: 2026-05-08.

---

## 1. Adaptivity (per-user calibration)

Every session must be adaptive to the user's collected data — both targeted
area (`bodyFocus`) and performance level (`startingTier` / recent ratings).

### Difficulty bounds

| User tier        | Min difficulty | Max difficulty |
| ---------------- | -------------- | -------------- |
| 1 (beginner)     | 1              | 2              |
| 2 (intermediate) | 2              | 4              |
| 3 (advanced)     | 3              | 5              |

- **Beginners never see hard exercises.** Difficulty cap is the strict ceiling —
  a difficulty-3 plank variation must not surface for a tier-1 user.
- **Advanced users never see easy exercises.** Difficulty floor exists so a
  tier-3 user doesn't get foundational dead-bug filler when capable of harder.

### Tier resolution

Cold start: `startingTier` from onboarding signals (experience + baseline plank +
activity level + age range).

After 3+ session ratings exist:

- avg ≥ 4.0 (too easy) → bump tier up by 1, capped at 3
- avg ≤ 2.5 (too hard) → drop tier down by 1, floored at 1
- otherwise hold

---

## 2. Ordering rules (in priority order)

When the engine picks the slot order for a session, sort by these rules. Higher
rules win over lower ones.

### 2.1. Position blocks (highest priority)

Group exercises by body position. Order:

```
standing → quadruped → plank → prone → side-lying → supine → seated
```

Within a session, all standing moves come first, then all quadruped, etc. The
user never has to flip from plank to standing back to plank. This is the
Pamela Reif / growingannanas convention — minimize body-orientation changes.

For side-lying unilaterals: batch all-left then all-right so the user lies on
one side for the whole block instead of flipping every exercise.

### 2.2. Same-area grouping (within a position block, lower priority)

For multi-area sessions, group same-primary-area exercises together inside each
position block. E.g., within "plank" block, plank-abs moves come together
before plank-shoulders moves. Position grouping is the harder constraint; area
grouping is preference, not law.

### 2.3. Within-block scoring (tiebreakers)

When position + area are tied:

- compound (≥2 target areas) before single-area
- bilateral > alternating > unilateral
- reps before holds (isometric finishers land naturally last)

---

## 3. Duration + rest

### Per-exercise duration

Allowed values: **30, 35, 40, 45, 50, 55, 60 seconds.**

- Short sessions (5–10 min) → favor 30–40s (more variety, more moves, less
  monotony).
- Long sessions (15–45 min) → favor 50–60s (fewer moves needed; 30s × 30 moves
  feels rushed and cluttered).
- Holds (`pace = .hold`) trend shorter (30–45s) than reps (35–55s) at the same
  difficulty.
- Tier 3 may extend by +5s beyond tier 2.

### Rest between exercises

Allowed values: **5, 10, 15, 20 seconds.** Stacked offsets — none dominates,
each is a mini factor on top of the goal base:

- **Goal base.** Cardio / `goal = .definition` sessions short (10s base);
  strength long (18s base). The heat is the work for cardio; output recovery
  matters for strength.
- **Tier offset.** Tier 1 +3, tier 3 −3. Fitter users recover faster.
- **Pace offset.** Holds −3 vs. reps (isometric has lower cardio load).
- **Exercise mini-factor** (rules-doc 2026-05-08 update). Layered:
  - Impact: low −2, med 0, high +3 (jump squats, burpees earn rest)
  - Type: mobility / balance −2 (stretches don't need recovery), core 0,
    strength +1, cardio +1
  - Difficulty: 4-5 +1, 1-2 −1
  - Clamped to ±5s so this stays the tweak, not the driver.
- **L→R same-exercise transitions** get half-rest (the user is "switching
  sides", not recovering).

---

## 4. Variety + repeats

For mid-to-long sessions (15+ min), exercise variety beats strict no-repeats:

- ✅ squat → sumo squat → split squat → side lunge → reverse lunge → repeat
- ❌ squat → squat → squat (boring, no progressive overload signal)

Engine rules:

- Hard penalty on repeating the **exact same exerciseId** within a session.
- Soft preference for **same family** (squats, lunges, planks, etc.) when a
  long session needs more slots than the unique-pool can fill.
- Recent-session penalty (`-3 score`) for IDs seen in last 7 days — drives
  cross-session variety for daily users.

---

## 5. Balance + safety

- Every unilateral exercise emits **both** `.left` and `.right` slots. No
  one-sided sessions.
- Side-lying unilaterals batch by side (all L, then all R) for body-flip
  efficiency.
- Warmups and cooldowns also balance L/R — asymmetric flexibility is an injury
  risk, not just a discipline.
- Only exercises from `ExerciseBank` (canonical 128) are used. Never invent
  exercise IDs.

---

## 6. Pamela Reif / growingannanas as baseline

We hommage their structural patterns, customize the content. Reference set:

### Pamela Reif "Booty" routine (~5 min × 2 = 10 min)

```
squat with core twist          – 30s
jump squat with pulse          – 30s
squat walk alternating sides   – 30s
squat hold                     – 30s
plank to jump squat            – 30s
straight leg kickback          – 30s/leg
donkey kick with pulses        – 30s/leg
plank with kickback            – 30s/leg
leg circles                    – 30s/leg
leg kickback hold              – 30s/leg
[ Repeat ]
```

What we copy:

- Heavy variety within a focus (10 distinct moves on glutes/legs)
- Position progression: standing → standing-jump → plank → prone-kickback
- L/R always paired
- "Repeat" pattern for longer sessions (10 moves × 30s × 2 = 10 min)
- 30s default; "Break" 30s segments between blocks for longer sets

### Pamela Reif "Abs" routine (~8 min)

16 different ab moves at 30s each, with side-plank variants always L+R paired.

### Pamela Reif "Arms" routine (~5–6 min)

11 different upper-body moves at 30s each, "Break" 30s segments between blocks.

---

## 7. Voice coaching

### Pre-session preview

Before the user taps Start, the trainer should explain:

- What today's session is (focus area + length)
- What's good about it (research-grounded benefit)
- How it'll help (reframe to user goals)

This currently lives on `PreRoutineView` as text. Voice version is future work.

### In-session prep cue (during prep/rest)

When the rest window allows, the trainer tells the user **what's next** + **how
to get into position**:

- Long rest (≥15s) → "Next up is leg raise. Lie on your back, hands by your
  hips."
- Short rest (5–10s) → "Next up is leg raise. Get down on the mat."
- Very short (3–5s, between L/R sides) → silent or just "Switch sides."

### Hard rule: voice never gets cut

If a voice clip is 4 seconds long and the rest window is 3 seconds, **don't
play it**. Plan the clip length against the available time window. A cut
mid-sentence reads as broken, not energetic.

For ElevenLabs voice generation:

- Always estimate the clip duration before queuing it.
- Have short / medium / long variants of each cue keyed by available rest.

### Voice characters

| Name  | Personality                                                |
| ----- | ---------------------------------------------------------- |
| Sarah | Mindful, cheerful, kind. The default for v1.               |
| Kira  | Sassy, roasting, AAVE-influenced, funny, blunt.            |
| Sam   | Chill vibe, flirting, humorous, supportive. (was "Matson") |

> **Migration note:** existing voice clips and asset names use `Jeni` (mindful),
> `Kira` (sassy), `Matson` (chill). The "Sarah" / "Sam" naming is the target
> state for the next ElevenLabs re-generation pass. Code, asset names, and
> prefix logic in `RoutineAudioManager.prefix` still use the legacy names —
> rename them in lockstep with the re-recorded clips.

### Short trainer phrases

Cues we generate:

- "Go!"
- "Rest."
- "Good work."
- "Next up is squats."
- "Three, two, one."
- Per-exercise prep cues ("get on hands and knees", "lie on your side", etc.)

Short phrases sound robotic at default TTS settings. Use the recommended
defaults below to make them sound natural without over-stylizing.

### Voice clip taxonomy (what to generate)

The engine resolves clips by name with a fallback cascade. Generate clips at
the file names below for full coverage; missing variants fall through to
broader cues without breaking the session.

**Per-trainer prefix.** Trainer is selected via `voicePreference` AppStorage:

- `encouraging` → prefix `jeni_` (target: `sarah_` after the rename pass)
- `keepItReal` → prefix `kira_`
- `balanced` → prefix `matson_` (target: `sam_` after the rename pass)

The legacy un-prefixed clips (`intro_*.m4a`) act as a defensive fallback if a
trainer-specific clip is missing.

**Routine prep cues (in priority order, longest → shortest):**

| Filename                                | When it plays                | Approx duration | Content                                           |
| --------------------------------------- | ---------------------------- | --------------- | ------------------------------------------------- |
| `prep_full_<exerciseId>.m4a`            | Prep window ≥ 12s            | 4–6s            | Exercise name + position cue ("Next up is squats. Stand with feet shoulder-width.") |
| `prep_short_<exerciseId>.m4a`           | Prep 6–11s, or full not avail. | 2–3s            | Exercise name only ("Next up is squats.")          |
| `intro_<exerciseId>.m4a` (legacy)       | Last-resort fallback         | 2–3s            | Existing per-trainer intro line — already shipping |
| `switch_sides_1.m4a` / `switch_sides_2` | Switch-side hop              | 1–2s            | Just "Switch sides" / "Other side now"             |

Prep windows under 5s play **no** cue — voice would risk getting cut.

**Other cues already in use** (no change needed for the rules pass):

- `routine_done_1` … `routine_done_5` — full session celebration
- `exercise_countdown` — t-3-2-1 lead-in to active phase
- `exercise_almost` — fires at 5s remaining inside active
- `exercise_done` — between exercises in main block
- `rest_1` … `rest_4` — start-of-prep rest cue (not the prep-cue chain)
- `skip_1` / `skip_2` — when user skips an exercise
- `encourage_1` … `_5` — random in-active motivation
- `roast_1` … `_4` — Kira/Sam-only roast clips (Jeni doesn't roast)
- `hold_1` … `_6` — periodic in-active cue for `pace = .hold` exercises
- `tempo_1` … `_4`, `tempo_twist_1` … `_2`, `tempo_drive_1` … `_2` —
  periodic in-active cue for `pace = .rep` exercises

### ElevenLabs default settings (short workout cues)

```json
{
  "stability": 0.55,
  "similarity_boost": 0.85,
  "style": 0.0,
  "use_speaker_boost": true
}
```

- `stability: 0.55` — balances natural variation with consistency.
- `similarity_boost: 0.85` — keeps each clip recognizably the same voice.
- `style: 0.0` — short cues lack context; over-styling reads weird.
- `use_speaker_boost: true` — improves intelligibility under BGM.

For longer clips (pre-session previews, multi-sentence motivational pieces),
`style` can rise to 0.2–0.4 because there's enough context for the model to
land the prosody.

---

## 8. Effective + scientific

Sessions must be effective + scientific, not arbitrary. The exercise bank
exists for this reason — every move was selected with research backing
(Compendium of Physical Activities for MET values, McGill for core endurance,
Donnelly/ACSM for dose-response). Adding new moves goes through the same gate.

For session structure, defer to the ACSM 2018 Position Stand on physical
activity:

- Adults: 150–300 min/wk moderate or 75–150 min vigorous, plus 2+ strength
  sessions
- Core endurance: 3 sets of 30–60s isometric holds per session, 2–3×/week
- Recovery: 48 hours between hard same-muscle-group sessions

---

## 9. Test against the rules

Whenever the engine changes, run the validator:

- `WorkoutGenerator.validateBalance(_:)` — confirms every unilateral has paired
  L+R slots.
- (TODO) `validatePositionFlow` — confirm position blocks are monotonic, no
  back-and-forth between standing and supine.
- (TODO) `validateDifficultyBounds` — confirm tier-3 sessions have no
  difficulty-1 moves; tier-1 sessions have no difficulty-3+ moves.
- (TODO) `validateDurationGrid` — confirm every slot duration is in {30, 35,
  40, 45, 50, 55, 60}.

The validator runs in DEBUG; test failures should be loud (`assertionFailure`
preferred over `print`) so regressions surface during dev.
