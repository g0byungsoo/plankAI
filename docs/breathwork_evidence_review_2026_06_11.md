# Breathwork evidence review — occasion map for the intro screen
2026-06-11 · in-line literature pass (the agent route was blocked by a content
filter twice; this review was done directly). Science-honesty lock applies:
JeniFit claims the stress/cortisol mechanism only, never metabolic effects.

## The occasion map

| occasion | protocol | pacing | duration | evidence | honest claim line |
|---|---|---|---|---|---|
| **reset** (acute stress, the default) | cyclic sighing | double inhale through nose (one full + one short top-up), long slow mouth exhale | 5 min | **STRONG** — Balban et al. 2023 (Cell Reports Medicine, n=108-114 randomized): beat box breathing, hyperventilation-with-retention, AND mindfulness for mood lift + respiratory-rate drop; effects from a single 5-min session, growing over 28 days | "two sips of air in, one long sigh out. stanford's trial found five minutes of this lifts mood more than meditation." |
| **before a meal** (the pause) | slow paced breathing | in 4s, out 6s (≈6 breaths/min) | 2-3 min | **EXPLORATORY** — Meule & Kübler 2017 pilot: no direct craving reduction DURING breathing; delayed effect on state hunger only. HRV ↔ eating-self-regulation association is real but correlational. DO NOT claim craving reduction. | "a slower minute before you eat. not magic, just a pause that lets you choose on purpose." |
| **wind-down** (sleep onset) | extended exhale / 4-7-8 | in 4s, hold 7s, out 8s (or simple in-4 out-8 if holds feel hard) | 5 min | **MODERATE** — 2025 scoping review (15 studies): consistent stress/anxiety reduction + HRV improvement; 20-min slow-paced pre-sleep breathing reduced sleep-onset latency in a small insomnia study; 4-7-8-specific sleep trials still thin | "a long exhale tells your body the day is over. slower breath before bed is linked to falling asleep faster." |
| **morning** (start) | cyclic sighing, short | same as reset | 2 min | MODERATE (generalizes from Balban's any-time-of-day dosing; no morning-specific trial) | "before the day starts asking. two minutes is enough to begin." |

Notes:
- **Cyclic sighing is the hero protocol** — it won its head-to-head and it's the
  one already shipped in BreathworkSessionView. The occasion map adds pacing
  variants, not a new library.
- **Post-meal glucose**: emerging, unverified here — DO NOT SHIP any claim.
- Weight-relevance framing (intro copy, once): stress→cortisol is the only
  bridge JeniFit claims (Epel/Yale citation already in-app), plus sleep's role
  via the engine's existing Nedeltcheva grounding for the wind-down occasion.
  Never "breathing burns calories", never appetite-suppression claims.

## Dosing
- Minimum honest dose: one 5-min session (Balban measured single-session
  effects); the 28-day daily arm grew the effect. "five minutes, most days"
  is the honest habit line. The 2-3 min occasions are framed as a pause, not
  the studied dose.

## End-screen content (what we can honestly say)
- Subjective check: optional one-tap "how do you feel" (calmer / same) —
  Balban's outcome was self-reported affect, so asking her IS the measurement.
- Mechanism line per protocol: reset → "your exhale just slowed your heart
  rate. that's the brake pedal."; wind-down → "your nervous system got the
  day-is-done signal."; before-a-meal → "you gave yourself a beat. that's
  the whole point."
- Streak/celebration weight: LIGHT — a 5-min breath session ends quieter than
  a 20-min workout. Count it ("3 breath days this week"), never confetti.
- NEVER on the end screen: calories, fat, metabolism, appetite numbers,
  weight references of any kind.

## Unsupported-claims screen list (copy review checklist)
1. "Breathing burns fat / boosts metabolism" — unsupported, kill on sight.
2. "Kills cravings" — the one pilot showed cravings did NOT drop during
   breathing; only delayed hunger effects. Frame as a pause, never a killer.
3. "Detoxes / alkalizes" — pseudoscience.
4. "Equivalent to exercise" — no.
5. "Lowers cortisol N%" with a number — the cortisol link is mechanistic
   framing (Epel), not a measured in-app outcome; keep it qualitative.
6. Senobi "boosts metabolism" claims beyond Sato 2010's tiny n=40 — keep
   Senobi as a fun stretch reference only, not an occasion protocol.

Sources:
- [Balban et al. 2023, Cell Reports Medicine](https://www.cell.com/cell-reports-medecine/fulltext/S2666-3791(22)00474-8) · [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC9873947/)
- [Meule & Kübler 2017 pilot, slow paced breathing + food craving](https://pmc.ncbi.nlm.nih.gov/articles/PMC5344958/)
- [4-7-8 scoping review 2025](https://www.researchgate.net/publication/394625657_Exploring_4-7-8_Breathing_for_Stress_Relief_and_Improved_Quality_of_Life_in_Chronic_and_Degenerative_Diseases_A_Scoping_Review) · [4-7-8 RCT (tinnitus cohort, PSQI improvement)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12895279/)
- [HRV ↔ eating self-regulation context](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4050420/)
