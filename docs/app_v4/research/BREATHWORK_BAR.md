# The premium breathwork bar (2025–2026) + the evidence for acute stress/craving downshift

**Research date: 2026-07-06.** Compiled from four parallel live-web research passes
(~200 searches/fetches) plus a direct read of JeniFit's shipping breathwork code.
This feeds the App v4 rebuild of the breathwork feature. Founder verdict on the
current build: *"feels low quality. It should feel closer to a premium breathwork app."*

**Evidence tags:** `[strong]` = replicated / large RCT · `[moderate]` = small RCT or
consistent mechanism · `[weak]` = single small study, mechanistic-only, or popular-but-
unproven · `[product-fact]` = sourced from the company/app's own listing, docs, or press ·
*[reviewer]* = third-party impression · **unverified** = no source confirmed it (we do not guess).

**Golden rule for this doc:** no citation is invented. Where an agent could only see a
search snippet and not the primary text, it is flagged. Cortisol/vagal framing only —
**never a fat-burn or metabolic claim** (locked project constraint).

---

## 0. Baseline — what JeniFit ships today (the "low quality" diagnosis)

Read directly from `PlankApp/Views/DietEducation/BreathCircle.swift` +
`PlankApp/Views/Welcome/BreathworkSessionView.swift` +
`PlankApp/Health/BreathworkProtocols.swift` (2026-07-06):

| Dimension | Current implementation | Why it reads "meditation-app default" |
|---|---|---|
| **Visual** | `breath_bloom.png` **raster** asset, scaled `0.45 ↔ 1.05` | Raster (not resolution-independent / not a shader); a scaled PNG cannot hold an editorial-luxury bar at all sizes |
| **Breath curve** | `withAnimation(.easeInOut(duration: inhaleSec))` symmetric in/out | `.easeInOut` is closer than linear, but it is applied **symmetrically** and per-phase; no asymmetric velocity profile, no true breath-shaped curve tuned to zero-velocity at the turns |
| **Countdown** | Big `Fraunces` **numeric countdown inside the bloom** (`"3"`, `"2"`, `"1"`) | Premium apps show **no countdown numbers mid-breath**. A number to read is the opposite of eyes-soft breathing |
| **Phase words** | 44pt `Fraunces` word swaps mid-breath (`"breathe in"` / `"let it go"`) | Text mid-breath survives in the premium set only as *one* word max; a 44pt hard-swapping headline pulls the eye every phase |
| **Haptics** | `Timer.scheduledTimer` firing **discrete** `Haptics.soft()` every `0.55s`/`0.75s` + `.medium()` at apex/bottom | This is the discrete-tap approach. It is **not** a continuous CoreHaptics curve. It is the single clearest "default" tell in the build |
| **Audio** | `RitualMusicPlayer(lesson_zen_lofi)` loop + optional Jeni bookend voice; **no per-cycle audio** | Fine as far as it goes, but not decoupled/mixable, no breath-cue sound layer, tones don't "lean" toward the next phase |
| **Completion** | Serif line + 7-dot week row + hand-back line + `Haptics.success()`; day-1 adds a heart sticker | Actually on the *right* side (evidence-receipt, not confetti) — but the heart sticker + success haptic lean celebratory |

**Verdict:** the bones (occasion doorways, honest receipt copy, protocol library,
reduce-motion handling, generation-guarded timers) are good. The **sensory core** —
raster visual, symmetric easing, discrete-tap haptics, mid-breath numbers and words — is
exactly the cluster that separates "default" from "premium" below.

---

# LANE 1 — the product bar

## Per-app in-session teardown

### Othership — "cinema for the ears" (no visual pacer at all)
- **Visual:** Evidence points to **no animated pacer**. In-session screen is a media
  player — "standard play/pause controls, 15-second rewind/forward buttons" *[reviewer,
  screensdesign.com]*. App-wide it's "incredibly polished and atmospheric," opening on a
  "cinematic video montage." Its own 2021 listicle credits *competitors* with "Breath
  Ball" animations and claims none for itself. Easing: **unverified** (there's nothing to ease).
- **Audio (the core):** "Music-driven breathwork… soundscapes from sound healing
  musicians, artists and DJs" `[product-fact, App Store]`. A **recorded human breath is
  audible under the guide voice** *[t3.com, 2022]*; **music tempo is arranged to carry the
  breath pace**, mood-matched per category.
- **Haptics: unverified** (no source; no Watch app).
- **Arc:** "as little as 60 seconds… up to 60 minutes" `[product-fact]`; guidance
  front-loads then **recedes, leaving you alone with the breath track holding rhythm**.
- **Cueing:** entirely by ear — facilitator voice + audible breath track + music tempo. No
  on-screen phase cue confirmed.
- **Completion:** streaks + a "benchmark breathing test," Apple Health Mindful Minutes.
- **Most distinctive:** pacing by a *recorded human breath* under DJ-produced tempo-matched
  music — works fully eyes-closed; the screen is deliberately just a player.

### Breathwrk (Peloton-owned) — the "tri-channel pacer"
- **Visual:** circular visualizations; "beautifully designed animations that guide your
  pacing" `[product-fact]`. **Time-of-day adaptive theming**: "bright visuals match your
  active day, muted colors prepare you for a restful night" `[product-fact,
  breathwrk.com]`. Documented flaw: sound/visual **sync drift** *[App Store review, 2025]*.
  Morph/easing specifics: **unverified**.
- **Audio:** three layers — "customizable soundscapes, functional music, and expert voice
  coaching" `[product-fact]`; classes cue by **spoken counting** ("in, two, three, four;
  out, two, three, four, five, six") `[product-fact, Peloton blog, 2025]`. Owns a
  functional-music label, Soundwrk.
- **Haptics (strongest confirmed of all 10):** "**Tactile Haptics: precise vibrations
  synchronized to your breathing patterns, allowing you to practice with your eyes closed**"
  `[product-fact, Google Play]`. Curve-vs-tap mechanics: **unverified**. (Trap: the
  "vibration builds on inhale, fades on exhale" line belongs to a *different* app,
  Breathworkk.app — do not borrow it.)
- **Arc:** timed inhales/exhales/holds; benefits "in as little as 60 secs"; ~1–5 min
  exercises, 1–15 min classes; user-adjustable. Endings criticized: "finish abruptly, like
  midway through the final exhale" *[review, 2024]*.
- **Completion:** streaks, levels, "lung score," Peloton sync — but "too many screens pop
  up after finishing" *[review, 2023]* (anti-pattern).
- **Most distinctive:** eyes-closed **haptic pacing as a first-class mode** + adaptive
  time-of-day session color.

### Open (o-p-e-n.com) — "orb + live physiology"
- **Visual:** minimalist player with a "**hypnotic, color-shifting orb**… a simple
  pulsating gradient and subtle audio cues" *[reviewer, screensdesign.com]*. Second layer:
  **camera-PPG biofeedback charts HR/HRV live during the session** — "your nervous system,
  charted live" *[selfpause.com, 2026; approximate, not clinical]*. Easing beyond
  "pulsating/hypnotic": **unverified**.
- **Audio:** artist-commissioned scores (Ólafur Arnalds, Blood Orange, KAYTRANADA…)
  `[product-fact]`; teacher voice over music; "subtle audio cues."
- **Haptics: unverified** (no source).
- **Arc:** "5-minute breathwork techniques to 60-minute classes" `[product-fact]`; named
  classes (Quick Clearing 6 min, 4:7:8 Sleep Well 10 min); a 1-min "Expresso Shot."
- **Cueing:** teacher voice + orb-as-state-display; explicitly anti-text.
- **Completion (the premium receipt):** a "Performance Tracking Insights" screen with a
  **BPM graph showing heart-rate decrease during breathwork** `[product-fact, App Store
  screenshots]`.
- **Most distinctive:** your own nervous-system downshift **charted live** over a
  color-shifting orb; the receipt is your BPM curve, not a streak.

### Oak — "one-word minimal pacer" (2017-era, still instructive)
- **Visual:** concentric-circle pacer on a **light** ground; halo disc + ring + inner disc
  **with the phase word set inside the circle**, over a low-opacity watercolor landscape;
  hairline coral progress bar `[product-fact, App Store screenshots]`. Scale-vs-dial
  mechanics + easing: **unverified**.
- **Audio:** guide voice primary — names phases and **counts the seconds**; **v2.2 (2018)
  added an audio-only mode** "no more looking at the screen" `[product-fact]`; separate
  voice/background sliders.
- **Haptics: unverified.**
- **Arc:** pre-session info card with an **explicit safety note** ("discontinue if
  feeling lightheaded") + method list → BEGIN; three exercises (4-7-8 / box / 6-2); default
  ~1.5 min, adjustable to 6.
- **Cueing:** phase word **inside** the pacer circle (eye never leaves the graphic) + voice
  redundantly counts.
- **Completion:** no in-session ceremony; a Growth tab with lifetime "Breaths Taken 511"
  counters + a live "Breathing Now: 17" community count.
- **Most distinctive:** radical single-word minimalism (word *inside* the pacer) + every
  breath tracked as a unit.

### Balance — "stitched-voice + felt-haptics"
- **Visual:** "**smooth, pulsing visuals that guide your breath rhythm without being
  overwhelming**," controls fade away during meditation *[reviewer, productivity-apps.com,
  2025]*. A touch-interactive variant: "**follow a circle with your fingers and match your
  breathing to the circle's movements**" *[choosingtherapy.com, 2024]*.
- **Audio:** signature **stitched-voice engine** assembles a daily session from thousands
  of clips `[product-fact]`; two coaches; deliberate guidance/silence balance.
- **Haptics (as content, not accent):** "Immersive Meditations" are "a unique
  vibration-based experience" — hold phone on chest/leg — built on **Core Haptics, iPhone
  8+/iOS 13+ only** `[product-fact, support docs]`. Haptic pacing inside the *standard*
  breathing exercises: **unverified**.
- **Arc:** daily check-in tailors the session; durations 3/5/10 up to ~30 min; a **Breathe**
  + **SOS** category.
- **Completion (most instrumented):** end screen **asks you to rate current mood**, then
  logs time + tools; "quick feedback… genuinely improve future recommendations"
  *[productivity-apps.com, 2025]*.
- **Most distinctive:** Core Haptics meditations you physically feel on your chest + a
  completion mood-delta that feeds personalization.

### Calm — "breathe bubble" (the mainstream default, for contrast)
- **Visual:** single expanding/contracting bubble over full-screen nature scene; **phase
  words on screen** ("Breathe In – Hold – Breathe out") `[product-fact, Calm YouTube]`.
  Exact easing **unverified** (community recreations use an eased ~4s scale).
- **Audio:** two decoupled layers with **separate volume sliders** — "Breathe" guidance vs
  "Scene" ambience `[product-fact, Calm Help Center]`.
- **Haptics:** exist as a **user toggle** `[product-fact]`; pattern **unverified**.
- **Arc:** 60-second default; pace user-set to 4 / 6 / 8 breaths/min.
- **Cueing:** bubble scale + **on-screen words** + guidance audio (words are the crutch).
- **Completion: unverified** (the tool just loops).
- **Note:** this is the *default* the founder wants to beat — scene video + on-screen
  words + voice + ambience all firing at once.

### Apple watchOS Breathe / Mindfulness — **THE haptic + curve reference**
- **Visual:** a flower of **6 overlapping translucent circles** in two teal hues,
  screen-blended; the cluster **scales 0.15 → 1.0 while rotating 180°** on a
  **`cubic-bezier(0.5, 0, 0.5, 1)` curve over ~4s per direction, alternating** (≈ ease-in-
  out-sine, ~8s full cycle at the 7 bpm default) *[CSS-Tricks teardown, measured]*. **Petals
  = one per session minute** — ornament that encodes data `[reviewer]`. Sibling "Reflect"
  = a slow morphing abstract `[product-fact, Apple Newsroom 2021]`.
- **Audio:** essentially **silent by design** — guidance is visual + haptic. No breath-cue
  tones documented.
- **Haptics (precise, `[product-fact]` via Apple support + AppleToolBox):**
  - **Prominent (default):** continuous rhythmic pulsing on the wrist **during the
    inhale**; the pulses **stop to cue the exhale** — "when they stop, you should be
    exhaling." The exhale cue is the **absence** of stimulus.
  - **Minimal:** discrete grammar — "one tap = inhale, two taps = exhale."
  - **None.**
- **Arc:** 1–5 min (Digital Crown, 1-min steps); breath rate **4–10 bpm, default 7**; a
  "be still" settling beat before pacing.
- **Cueing:** grow = in, shrink = out, pulse-train = in, silence = out. **Zero mid-breath
  text.**
- **Completion:** ends on **heart rate** + breaths taken + time (a **physiological
  receipt**), into the Health app. No confetti.

### State (by B-Reel) — anti-meditation-app minimalism
- **Visual:** B-Reel "distanced the look… from mainstream meditation apps… black and
  restrained key colors to keep the app distraction-free" `[product-fact, B-Reel case
  study]`. Specific in-session shape: **unverified**.
- **Audio:** sound is a first-class breath cue; reviews imply **voiceless** sessions
  ("no extra words and distractions").
- **Haptics: unverified.**
- **Arc:** onboarding "fingerprinting" calibrates and keeps adapting; six goal-states;
  deliberately **very short** sessions.
- **Completion:** a metrics dashboard tied to the adaptive algorithm.
- **Note:** originally developed with input from Andrew Huberman + Brian Mackenzie
  *[LBBOnline]*.

### Superhuman — **identity finding: no verifiable breath pacer**
- No app titled exactly "Superhuman: Breathwork & Wellness" could be verified. Best match =
  "Superhuman" (Mimi Bouchard), now renamed "Activations: Daily Motivation" — an
  **audio-first** product with **no documented breath-pacing visual**. Lesson for us is
  *register*, not mechanics: cinematic, identity-forward, loud emotive audio that will
  "make me feel alive" — the opposite of whisper-register meditation `[product-fact,
  Refinery29 2024]`.

### Endel — generative, cue-free entrainment
- **Visual:** monochrome **generative** abstraction that drifts with the sound; "no colour,
  minimalist" *[reviewer]*; continuous slow morph, no phase snapping.
- **Audio (the core):** real-time generative engine; **pentatonic scales, simple ratios,
  slow chord changes, BPM matched to heart rate then slowed to entrain it downward**
  `[product-fact, Amazon Science]`. Uses **wave textures shaped like human breathing**.
  Sound designer: "the less detail there is, the less attention is dedicated to that task."
- **Haptics: unverified.**
- **Arc:** soundscapes are *endless* by design; a breathing "Exercises" feature adds
  guided-voice + animated visuals + completion messages *[Pratt IXD critique, 2026]*.
- **Completion:** low-friction completion messages; soundscapes have no end.
- **Note:** Apple Watch App of the Year 2020.

---

## What separates "premium" from "meditation-app default" (the synthesis)

**1. The breath curve is sinusoidal, never linear — because breathing is.**
The one hard number in this research: Apple Breathe is `cubic-bezier(0.5, 0, 0.5, 1)`
(≈ ease-in-out-sine) over ~4s per half-cycle. Real tidal airflow starts at **zero velocity
at the turn**, peaks mid-phase, decelerates back to zero — a sine scale curve mirrors that
velocity profile, so it *feels* like a lung. Linear scaling has constant velocity and an
**instantaneous reversal at the extremes** — that hard corner at the top of the inhale is
exactly the moment a real breath is softest, which is why it reads as mechanical bellows.
Character animators teach the same asymmetry (inhale eased differently from exhale). **The
curve's derivative must hit zero at every turn**, and exhale should run longer than inhale
at 4–10 bpm paces.

**2. Phase transitions are *anticipated*, not *announced*.**
Apple's exhale cue is the pulse train *stopping* — you feel the last pulse land and release;
nothing startles. WWDC19 #810 ("Designing Audio-Haptic Experiences") formalizes why:
**Causality** (obvious what caused the feedback), **Harmony** ("things should feel the way
they look, the way they sound… play in the same tempo"), **Utility** ("use moderation").
Plus the **"ghost effect"** — a soft priming transient played *before* the main haptic so
the skin doesn't miss the real cue. That priming transient **is** the anticipation pattern:
a ~200–400ms pre-signal before each turn (a swelling tone, a ghost tap, the visual already
decelerating) so the turn *confirms* what the body already sensed. Endel does the audio
version continuously (crescendo/decrescendo always *leaning* toward the next state).
**Default apps switch; premium ones lean.**

**3. One continuous element, and silence as a cue.**
Every premium example is a single morphing subject (Apple's flower, Open's orb, Endel's
field, Calm's bubble). **None uses progress bars, countdown rings, or countdown numbers
mid-breath.** The strongest cue in the whole set is an *absence*: Apple cues the exhale with
haptic silence. Reserve stimulus for the effortful phase (inhale); let release be felt as
release.

**4. Restraint is measurable, not a vibe.**
Concretely: **no mid-breath text** (Apple / State / Endel pass; Calm fails), **≤2 concurrent
sensory channels per phase**, chrome fully hidden during pacing, at most **one word inside
the pacer** (Oak). Endel's mechanism: "the less detail, the less attention dedicated to that
task."

**5. Audio is layered/decoupled, and tones are physical.**
Calm's one premium move is **separate volume sliders** for guidance vs ambience. WWDC19 #810
sets the tone-design bar: continuous haptics pair with smooth swelling sounds; low haptic
**sharpness feels "round, soft, organic,"** high feels "precise, mechanical" — a breath app
lives at **low sharpness, moderate intensity, intensity enveloped along the same sine as the
visual.** Othership's recorded-human-breath track and Endel's breathing-shaped wave textures
are the ambient-cue frontier.

**6. Completion is an evidence receipt, not a badge.**
Apple ends on heart rate; Open draws your live BPM-downshift graph; Balance asks a mood
delta that feeds personalization. The default pattern (streaks, confetti, share sheets)
appears **nowhere** in the premium set. Documented **anti-patterns**: Breathwrk's "too many
screens after finishing" and sessions that end "midway through the final exhale."

**7. Duration honesty.**
The premium cluster is short and exact: Apple 1–5 min (default 1, 7 bpm), Calm 60s default,
resonance apps 5–6 bpm. A premium mobile breath session is a **1–5 minute precision
instrument**, not a 20-minute commitment. Long-form is Endel's niche.

**White space (nobody owns it):** a **continuous breath-shaped CoreHaptics curve** is
claimed by no major player (Breathwrk syncs vibrations but the curve is unverified; Balance
uses haptics as content). Discrete inhale→hold→exhale **chimes are unverified across all 10
apps** — an open slot. **Redundant multi-channel cueing that degrades to eyes-closed is
table stakes.**

---

# LANE 2 — the evidence

## Q1 — Physiological sigh / cyclic sighing

**Anchor `[strong]` (with `[moderate]` single-study caveat):** Yilmaz Balban M, Neri E,
Kogon MM, et al. (2023). "Brief structured respiration practices enhance mood and reduce
physiological arousal." *Cell Reports Medicine* 4(1):100895. DOI 10.1016/j.xcrm.2022.100895
· PMC9873947 · NCT05304000. https://pmc.ncbi.nlm.nih.gov/articles/PMC9873947/
- **Cyclic sighing mechanics (double inhale + extended exhale):** inhale slowly through the
  nose; when the lungs feel full, **inhale again** (shorter, to maximally fill); then
  **slowly, fully exhale through the mouth**. Repeated continuously. The paper emphasizes
  prolonged exhalation but **does not publish a fixed numeric ratio** (the popular ~1:2 is
  not quantified in Balban's protocol).
- **Dose:** **5 min/day for 28 days**, all arms. **Sample:** 108 enrolled, 100 analyzed
  (cyclic sighing n=30; box n=21; cyclic hyperventilation n=33; mindfulness meditation
  n=24).
- **Result:** cyclic sighing gave the **largest increase in positive affect** and the
  **greatest reduction in respiratory rate**, both significantly better than mindfulness
  meditation. Note: **respiratory rate**, not HR or HRV, was the physiological marker that
  moved most.

**Newer acute test `[weak/moderate]`:** Hanley AW, Davis A, Worts P, Pratscher S. (2025).
"Cyclic sighing in the clinic waiting room may decrease pain: results from a pilot RCT."
*J Behav Med* 48(2):385–393. PMID 39904867. https://pubmed.ncbi.nlm.nih.gov/39904867/
- A single **4-minute** cyclic-sighing audio reduced **pain** intensity/unpleasantness vs
  control — but **anxiety and depression did NOT differ**. This is the closest thing to an
  acute single-session cyclic-sighing RCT, and it did not move anxiety.

**Mechanistic origin (for honest framing):** Li P, Yackle K, et al. (2016), *Nature*
530:293–297 `[strong, but animal/mechanistic]` — identified the brainstem sigh circuit;
Severs, Vlemincx & Ramirez (2022), *Biological Psychology* 170:108313 `[review]` — sighs as
arousal/brain-state "reset" transitions.

**Honesty flag:** the popular "1–3 sighs = calm in 30 seconds" claim is **not RCT-tested**.
Balban's proof is 5 min/day over ~4 weeks; the only acute single-session RCT moved *pain*,
not anxiety. The double-inhale **mechanics** are well-sourced; the **instant-calm dose** is
mechanistic/popularized, not proven.

## Q2 — Minimum effective dose for acute state change

**Bottom line: the verified acute floor is ~5 minutes, and longer does not beat 5 min in one
sitting. A rigorous 60-second effect is NOT established — do not claim it.**

- `[strong]` You M, Laborde S, et al. (2021). "Single Slow-Paced Breathing Session at Six
  Cycles per Minute: Dose-Response on Cardiac Vagal Activity." *IJERPH* 18(23):12478.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8656666/ — n=59; tested **5, 10, 15, 20 min** at
  6 cpm (4s in / 6s out). **All durations raised RMSSD vs control (d ≈ −1.1 to −1.3), with
  NO difference between durations.** 5 min = 20 min acutely.
- `[moderate–strong]` Magnon V, Dutheil F, Vallet GT. (2021). "Benefits from one session of
  deep and slow breathing on vagal tone and anxiety." *Scientific Reports* 11:19267.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8481564/ — one **5-minute** session at 6 bpm
  raised HF power and **lowered state anxiety** (both p<0.001).
- `[moderate]` Bates ME, et al. (2026). "Functional Connectivity Within the Central
  Autonomic Network Increases During Resonance Paced Breathing at 0.1 Hz." *Psychophysiology*
  63(2):e70263. https://pmc.ncbi.nlm.nih.gov/articles/PMC12929929/ — single **5-min** 0.1 Hz
  session shifted central autonomic connectivity.
- `[weak / not verified]` Sub-5-min (1–2 min) bouts appear in secondary sources and clinical
  primers but **no primary study rigorously establishing a 60-second acute effect** was
  located. Report ~5 min as the verified floor; treat 60s as a plausible **state-nudge**, not
  the proven dose.

## Q3 — Exhale-emphasized ratios (4:6, 4-7-8, "longer exhale")

**The important honest split: the *mechanism* (prolonged exhale → parasympathetic) is real,
but making the exhale *longer than the inhale* added NO measurable HRV benefit when the rate
was held at 6 bpm. The slow rate itself does most of the work. 4-7-8 specifically is weakly
studied.**

- `[weak, mechanism-confirming]` Komori T. (2018). "The relaxation effect of prolonged
  expiratory breathing." *Mental Illness* 10(1):7669.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC6037091/ — n=10; 4s in / 6s out raised HF and
  lowered LF/HF (parasympathetic dominance). Grounds the physiology (RSA: HR falls on exhale
  via vagal input).
- `[moderate] — the key nuance` Meehan ZM, Shaffer F. (2024). "Do Longer Exhalations
  Increase HRV During Slow-Paced Breathing?" *Applied Psychophysiology and Biofeedback*
  49(3):407–417. https://pmc.ncbi.nlm.nih.gov/articles/PMC11310264/ — compared **1:1 vs 1:2**
  at 6 bpm across two small RCTs (n=26, n=16): **no difference** in any HRV metric.
  Contradicts four earlier studies that favored longer exhales — so the exhale-longer claim
  is **genuinely mixed** when rate is constant.
- `[weak]` Vierra J, Boonla O, Prasertsri P. (2022). 4-7-8 effects on HRV/BP/glucose,
  *Physiological Reports* 10(13):e15389. https://pmc.ncbi.nlm.nih.gov/articles/PMC9277512/ —
  acute 4-7-8 lowered HR (~3–5 bpm), lowered systolic BP (~4 mmHg), raised HF power. Single
  session, n=43. **4-7-8 as a specific protocol is thin** — multiple reviews call
  effectiveness claims largely anecdotal.

**Copy implication:** lead with **slow pace (~6 breaths/min)** as the active ingredient; a
longer exhale is a comfortable, low-risk *way to reach that pace* — not a separately proven
lever. Don't present the 4-7-8 pattern (esp. the 7s hold) as well-validated.

## Q4 — Paced breathing for FOOD CRAVING (the honesty flag that hits JeniFit copy)

**Bottom line: direct food-craving evidence is genuinely thin AND mixed. The cleanest acute
test found slow breathing did NOT reduce craving in the moment — craving actually *rose*
during the breathing block.**

- `[weak; NEGATIVE for the acute claim]` Meule A, Kübler A. (2017). "A Pilot Study on the
  Effects of Slow Paced Breathing on Current Food Craving." *Appl Psychophysiol Biofeedback*
  42(1):59–68. https://pmc.ncbi.nlm.nih.gov/articles/PMC5344958/ — 65 women; 6 vs 9 breaths/
  min for 10 min while viewing a preferred food. **Craving rose *during* the breathing block
  and fell during the rest periods**, identically in both rates. Slow rate had only a delayed
  effect on *hunger*. This is the cleanest in-the-moment test and it does **not** support
  "breathe now to kill a craving now."
- `[moderate; multi-session, not acute]` Meule et al. (2012). "HRV Biofeedback Reduces Food
  Cravings in High Food Cravers." *Appl Psychophysiol Biofeedback* 37(4):241–251.
  https://pubmed.ncbi.nlm.nih.gov/22688890/ — **12 sessions**; craving tied to *lack of
  control* fell in the trained group — but **emotional-eating cravings did NOT**, and the
  benefit came **without** the expected HRV rise. A training effect over weeks, not a rescue.
- `[moderate; single small RCT — strongest acute positive]` Telles S, et al. (2024).
  "Volitionally Regulated Breathing with Prolonged Expiration Influences Food Craving and
  Impulsivity." *Complementary Medicine Research* 31(4):376–389.
  https://pubmed.ncbi.nlm.nih.gov/38955170/ — n=40 with obesity; single session of **12
  breaths/min with prolonged expiration (~72% of the breath on the exhale)** reduced state
  food-craving, reduced impulsivity, and raised HF-HRV/RMSSD vs a metronome control. Points to
  **long-exhale pacing** (not merely "slow") as the acute active ingredient.
- **Transferable `[moderate–strong for acute]`:** Shahab L, Sarkar B, West R (2013). "Acute
  effects of yogic breathing on craving and withdrawal in abstaining smokers."
  *Psychopharmacology* 225(4):875–882. https://pubmed.ncbi.nlm.nih.gov/22993051/ — RCT n=96;
  10 min breathing dropped all three craving measures vs control, **but the effect vanished
  by 24h** (low adherence). Acute urge-surfing works; it doesn't persist without repeated use.
  (Also McClernon 2004, smoking, small/older `[moderate]`, primary text not directly read.)
- **Indirect `[strong for mindfulness broadly]`:** Sancho et al. (2023), *BMC Neuroscience*,
  mindfulness-for-craving meta-analysis (17 RCTs, n=1,228, pooled ≈ −0.70).
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10583418/ — not isolated slow-breathing, so only
  indirect support.

**Verdict:** defensible to say brief **long-exhale / paced breathing can help *ride out* an
urge acutely** (best support: Telles 2024 + the nicotine literature). **Not** defensible to
claim it durably reduces food cravings, or that "slow breathing lowers cravings" as a
general fact — one good study shows craving *rises during* the breath itself. **This directly
implicates JeniFit's current framing:** the `.settled` occasion label "a craving wave," the
`whenSituations` tag "cravings that aren't hunger," and the day-1 receipt line "less stress,
fewer cravings that aren't really hunger" all lean on the weakest, partly-contradicted claim.
Reframe as urge-*surfing* ("ride the wave, it crests and passes") rather than
craving-*suppression*.

## Q5 — Haptic-guided / vibrotactile breathing

**Bottom line: moderate and multi-lab-consistent — the strongest of the two evidence bases
here. Eyes-free vibrotactile pacing is followable and mildly anxiolytic; visuo-haptic beats
visual alone. Small samples, no large clinical RCT yet.**

- `[moderate]` Miri P, et al. (2020). "Evaluating a Personalizable, Inconspicuous
  Vibrotactile (PIV) Breathing Pacer for In-the-Moment Affect Regulation." *CHI 2020.* DOI
  10.1145/3313831.3376757. https://dl.acm.org/doi/10.1145/3313831.3376757 — abdomen tactors;
  treatment group showed **reduced anxiety under a cognitive stressor vs control, Cohen's d =
  0.33, p = 0.004**. Real but modest eyes-free effect.
- `[moderate]` Miri P, et al. (2020). "PIV: Placement, Pattern, and Personalization…" *ACM
  TOCHI* 27(1). DOI 10.1145/3365107 — users **can entrain breathing to vibration**;
  frequency-based, **strong-exhale-phase patterns** work best; personalization matters.
- `[moderate; small]` Bouny P, et al. (2023). "Guiding Breathing at the Resonance Frequency
  with Haptic Sensors Potentiates Cardiac Coherence." *Sensors* 23(9):4494.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10181630/ — n=32; 5 min at 0.1 Hz.
  **Visuo-haptic (0.55) > haptic (0.34) > visual (0.28)** on cardiac coherence
  (visuo-haptic vs visual p<0.05). **Combining haptic with visual beats visual alone.**
- `[moderate]` Azevedo RT, et al. (2017). doppel wristband, *Scientific Reports* 7:2285.
  https://www.nature.com/articles/s41598-017-02274-2 — a slow **heartbeat-like wrist
  vibration** lowered anxiety + skin-conductance during public-speaking anticipation
  (sham-controlled). Caveat: paces to a heartbeat, not the breath — supports "discreet
  eyes-free wrist haptic can calm," not a breathing pacer per se.
- `[weak–moderate; feasibility]` Yu B, et al. (2021). "ViBreathe." *IJHCI* 37(16):1551–1570.
  https://www.tandfonline.com/doi/full/10.1080/10447318.2021.1898827 — eyes-free tangible
  interface rated less tiresome / more engaging; feasibility + acceptability, no controlled
  outcome.

**Verdict:** safe product framing — "guided by gentle vibration so you don't have to watch a
screen," backed by CHI/Sensors evidence — but avoid implying clinical-grade or large-trial
proof. Design cue: **the exhale phase is where vibrotactile patterns land best** (PIV);
**pair haptic with visual** rather than replacing it (Bouny).

---

# The JeniFit session spec implications

What a best-in-class **60s–3min** JeniFit breath session must include. Each line names the
change from today's build (§0) and the evidence/product-fact behind it.

### Visual
- **Replace the raster `breath_bloom.png` with a resolution-independent, animatable element**
  — a **Metal shader** (allowed by the design system if tasteful) rendering a single soft,
  cream/rose gradient orb-or-bloom that morphs in scale (and optionally hue-drift, à la
  Open's "hypnotic color-shifting orb" / Endel's generative field). **One continuous element,
  no second animation.** [product-fact: Open, Endel, Apple all use a single morphing subject]
- **Fix the breath curve.** The scale must follow a **sinusoidal / ease-in-out-sine velocity
  profile whose derivative reaches zero at every turn** — never symmetric-linear, never a
  hard reversal at the apex. Match Apple's `cubic-bezier(0.5, 0, 0.5, 1)` character.
  **Exhale animates longer than inhale** (e.g. 4s in / 6s out) — both because it's the pace
  and because the slow rate is the active ingredient. [Apple curve, measured; Q2/Q3]
- **Remove the numeric countdown inside the bloom.** Premium apps show **no countdown
  numbers or rings mid-breath**; the orb's size *is* the timing. [synthesis #3]
- **At most one phase word**, low-contrast, cross-fading (not a 44pt hard swap). Better:
  drop text during cycling entirely and let visual + haptic + optional voice carry it, so the
  eye can soft-focus or close. [Oak = one word inside pacer; Apple/State/Endel = no text]
- Keep **reduce-motion** handling (already solid). Hide all chrome (the X can auto-dim)
  during the paced phase. [synthesis #4]

### Audio
- **Keep the ambient bed but decouple it** — separate, mixable guidance vs ambience volumes
  (Calm's one premium move), and allow **ambience-only / silent**. [product-fact: Calm]
- Consider an **audible breath-track layer** (a soft recorded human breath under the bed,
  Othership's signature) and/or **tones that "lean"** — a gentle crescendo into the inhale,
  decrescendo into the exhale (Endel/Bernardi) — so audio *anticipates* rather than
  *announces*. [synthesis #2, #5]
- If tones mark phases, keep them **low-sharpness (round, soft, organic)**, paired with the
  haptic envelope, per WWDC19 #810's Harmony rule. Discrete phase chimes are an **open slot**
  (unverified in all 10 apps) — usable, but keep them subtle.
- Jeni's bookend voice (intro + close) stays; **no per-cycle voice counting** is fine given
  the visual+haptic carry the pace.

### Haptic (the highest-leverage upgrade)
- **Replace the `Timer`-based discrete `Haptics.soft()` pulse train with a continuous
  `CoreHaptics` (`CHHapticPattern` / AHAP) curve** whose **intensity + sharpness envelope
  rides the *same* sine as the visual** (Harmony). This is the single clearest fix for
  "low quality," and it is **genuine white space** — no major player ships a continuous
  breath-shaped haptic curve. [synthesis #6/white-space; §0 diagnosis]
- **Adopt Apple's cue grammar:** haptic **swells through the inhale**, then **decays to
  silence to cue the exhale** (absence as signal); the exhale phase is precisely where
  vibrotactile patterns land best. [Apple Watch `[product-fact]`; PIV `[moderate]`]
- **Add an anticipation transient** — a soft "ghost" pre-tap or intensity dip ~200–400ms
  before each phase turn, so the turn confirms what the body already sensed. [WWDC19 #810
  "ghost effect"]
- **Pair haptic *with* visual, don't replace it** (visuo-haptic > visual alone), and make
  haptics a **toggle** (battery + preference). [Bouny 2023; product-fact: Breathwrk/Calm]
- Net effect: the session becomes **fully eyes-closed-capable** (table stakes). [synthesis
  #1; Q5]

### Session arc
- **Intro (settle):** a brief "be still" beat (Apple), Jeni's one-line intro, orb holding.
  Offer duration up front.
- **Paced phase:** the honest doses — **offer 1 / 3 / 5 min; make 5 min the "full dose"** and
  frame <5 min (60s) honestly as a **state-nudge / urge-surf**, not the proven dose. Default
  pace ~6 breaths/min (4 in / 6 out) for the calming/stress protocol. [Q2: 5 min verified,
  60s not; You 2021, Magnon 2021]
- **Flagship acute-stress protocol = cyclic sighing** (double inhale + long exhale) — the
  best-evidenced exhale-emphasized practice (Balban 2023) — but describe its proof honestly
  (mood + slower breathing over daily practice; not "instant calm"). Keep the current
  protocol library; soften over-claims.
- **Never end mid-exhale.** Let the final exhale complete, then a gentle settle before the
  receipt. [anti-pattern: Breathwrk]

### Completion
- **Evidence receipt, not a badge.** The current serif line + 7-dot week + hand-back is on
  the right side — keep it, but **drop the celebratory heart sticker + `Haptics.success()`**
  in favor of a quieter close (a single soft haptic, an exhale-into-place). [synthesis #6;
  premium set ends on evidence/quiet, not confetti]
- **Consider a light physiological receipt** where permitted — the app already has a
  HealthKit rails; an honest **"your heart rate settled"** line or a small before/after
  cue echoes Apple's HR summary and Open's live BPM curve **without** camera-PPG complexity.
  Only show a number that traces to a real measurement (project data-provenance rule).
- **One screen, one CTA.** Avoid Breathwrk's "too many screens after finishing."

### Copy honesty (locked constraints + the new craving flag)
- **Reframe craving language from suppression to urge-surfing.** The evidence does **not**
  support "breathe now to kill a craving now" (Meule 2017 found craving *rose* during the
  breath); it supports *riding out* an urge (Telles 2024 long-exhale + nicotine literature,
  effect fades without repeated use). Revise `.settled` framing, the `whenSituations`
  "cravings that aren't hunger" tag, and the day-1 receipt line accordingly — e.g. "cravings
  crest and pass; the long exhale is how you ride the wave" (already close in
  `occasionLine`) rather than "fewer cravings."
- **Lead the mechanism with slow pace (~6 bpm) + vagal/parasympathetic downshift + slower
  respiratory rate** (Balban's actual moving marker was respiratory rate). The long exhale is
  a comfortable route to that pace, not a separately proven lever (Meehan & Shaffer 2024).
- **Cortisol only as downstream of stress-arousal. Never a fat-burn / metabolic claim.**
  Don't over-cite 4-7-8 as validated. Keep citations as receipts (author · venue · year).

---

## Source index (all primary-verified unless flagged)

**Evidence:** Balban 2023 (PMC9873947) · Hanley 2025 (PMID 39904867) · Li 2016 (Nature,
PMID 26855425) · Severs/Vlemincx/Ramirez 2022 (PMC9204854) · You 2021 (PMC8656666) ·
Magnon 2021 (PMC8481564) · Bates 2026 (PMC12929929) · Komori 2018 (PMC6037091) ·
Meehan & Shaffer 2024 (PMC11310264) · Vierra 2022 (PMC9277512) · Meule & Kübler 2017
(PMC5344958) · Meule 2012 (PMID 22688890) · Telles 2024 (PMID 38955170) · Shahab 2013
(PMID 22993051) · McClernon 2004 *(primary text not directly read — direction corroborated)*
· Sancho 2023 (PMC10583418) · Miri 2020 CHI (10.1145/3313831.3376757) · Miri 2020 TOCHI
(10.1145/3365107) · Bouny 2023 (PMC10181630) · Azevedo 2017 (Nature s41598-017-02274-2) ·
Yu 2021 ViBreathe (10.1080/10447318.2021.1898827).

**Product:** Apple watchOS Breathe support guide + Newsroom 2021 · WWDC19 #810 "Designing
Audio-Haptic Experiences" · CSS-Tricks Breathe recreation (curve measurement) · AppleToolBox
(haptic grammar) · Calm Help Center + official YouTube · Othership App Store + t3.com 2022 +
screensdesign.com · Breathwrk App Store/Google Play + Peloton blog 2025 + choosingtherapy
2024 · Open (o-p-e-n.com) + screensdesign.com + selfpause.com 2026 + App Store screenshots ·
Oak App Store + TechCrunch 2017 + TidBITS 2022 · Balance App Store + support.balanceapp.com +
productivity-apps.com 2025 · State App Store + B-Reel case study + LBBOnline · Endel Google
Play + Amazon Science + Pratt IXD 2026 · Superhuman/Activations App Store + Refinery29 2024
*(exact "Breathwork & Wellness" title unverified)*.

**Unverified surfaces (design white space):** exact haptic patterns for Calm/State/Othership/
Open/Oak/Endel; discrete inhale→hold→exhale chimes (none of the 10 confirmed); a continuous
breath-shaped CoreHaptics curve (claimed by no major player).
