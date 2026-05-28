# Exercise L/R Balance Audit

**Source of truth:** `Resources/workout.xlsx` (sheet: `exercises`).
**Generated Swift:** `PlankApp/Workout/ExerciseBankData.swift` (auto-built
by `Scripts/build_workout_data.py` — never hand-edit; will be wiped on
the next regen).

## What "L/R balance" means

For exercises where the Lottie animation only depicts **one side of the
body** doing the work (e.g. a hip stretch on the left leg, a quad
stretch on the right leg), the engine needs to emit **two slots** — one
for the side the animation natively shows, and one for the opposite
side rendered with `mirrorHorizontally = true`. Without this, users only
ever stretch / work one side, which compounds asymmetries.

The mechanism lives in `ExerciseMirror.renderings(for:)`:

- `.bilateral` / `.alternating` → 1 rendering, `side = nil`. No mirroring.
- `.unilateral` → 2 renderings, `side = .left` then `.right`. Right
  rendering's `mirrorHorizontally` flag flips the animation horizontally.

So: any exercise whose Lottie shows only one side must be
`symmetry = .unilateral` with `defaultSide` set to the side the
animation actually depicts.

## How to spot a miscategorized exercise

The fastest heuristic: **`symmetry = alternating` combined with
`pace = hold`** is almost always wrong. "Alternating" implies a dynamic
back-and-forth motion (alternating knees, alternating arms, etc.);
"hold" implies you stay in one position for the whole duration. Those
two don't coexist — a static hold can't alternate. When you see that
pairing, the exercise is almost certainly a single-side static stretch
that should be `unilateral` instead.

Exceptions to the heuristic (legitimately `alternating + hold`):

- **Whole-spine mobility** like Cat-Cow — both halves of the body
  cycle through the same shape, not L/R alternation. The cleaner
  classification would be `bilateral + rep`, but `alternating + hold`
  doesn't break L/R balance, so leaving it is harmless.
- **Position holds with alternating accents** like Tabletop Hold + Knee
  Lift — you hold tabletop and lift each knee in turn. The Lottie
  needs visual review to decide; if it shows both knees lifting in
  alternation, `alternating` is correct. If it shows only one knee,
  promote to `unilateral`.

## Fixes applied (2026-05-11)

Updated in `Resources/workout.xlsx` (the source of truth) AND mirrored
to `ExerciseBankData.swift` so the change is visible before the next
regen. `default_side` matches the side the Lottie natively animates.

| id                       | previous symmetry  | new symmetry  | default_side |
|--------------------------|--------------------|---------------|--------------|
| `side_tilt`              | alternating + hold | unilateral    | left         |
| `standing_hip_abduction` | alternating + rep  | unilateral    | left         |
| `lizard_pose`            | alternating + hold | unilateral    | left         |

After each fix, the engine emits the exercise as two back-to-back
slots — left first, then right (mirrored) — and the
`WorkoutGenerator`'s unilateral L/R batching keeps them adjacent so the
user feels the pair as one experience.

## Reverted (2026-05-12)

`kneeling_quad_stretch` was initially promoted from `alternating + hold`
to `unilateral + left` under the same heuristic that caught the three
above, but visual review of the Lottie showed it's actually the
**bilateral hero pose / vajrasana** — the model kneels on both shins
and both quads stretch simultaneously. No L/R balance needed.

Final state: `symmetry = bilateral`, `default_side = ` (blank). The
takeaway: the `alternating + hold` heuristic flags candidates worth
inspecting, but the call still needs a visual check — some
`alternating + hold` exercises are actually `bilateral + hold`
(whole-body holds) rather than one-sided stretches.

## Flagged for visual review (not auto-fixed)

These pair `alternating + hold` (the suspicious heuristic) but might
legitimately animate both sides — needs eyeballing the Lottie:

- `tabletop_hold_knee_lift` — if the Lottie alternates both knees in
  view, current `alternating` is correct. If only one knee lifts,
  promote to `unilateral`.
- `cat_cow` — bilateral whole-spine movement. Not an L/R issue, but the
  classification could shift to `bilateral + rep` for accuracy. Leaving
  alone since it doesn't affect balance.
- Any future `alternating + hold` candidate — see the `kneeling_quad_stretch`
  reverted entry above. The heuristic flags candidates; visual review
  decides between `unilateral` (Lottie shows one side, mirror needed)
  and `bilateral` (Lottie shows whole-body hold, no mirror needed).

## How to add new exercises with the balance check in mind

When adding a row to `Resources/workout.xlsx`:

1. Watch the Lottie at native speed. Does the work happen on one side
   only, or both?
2. **One side only** → `symmetry = unilateral`, `default_side` =
   whichever side the animation actually animates (the engine mirrors
   the other). Add a `note` referencing this (template:
   *"Lottie shows the {side} side; engine emits L+R pair so both sides
   get worked. Other slot mirrors the animation horizontally."*).
3. **Both sides cycle alternately** (left, right, left, right…) →
   `symmetry = alternating`, `default_side = ` (blank). Use this for
   rep-paced exercises only.
4. **Whole body, same motion both sides** → `symmetry = bilateral`,
   `default_side = ` (blank).
5. After editing the xlsx, run `python3 scripts/build_workout_data.py`
   to regenerate `ExerciseBankData.swift`.

## Engine reference

- `Packages/PlankEngine/Sources/PlankEngine/` — ExerciseMirror and the
  unilateral L/R batching live here.
- Rule reference: `docs/workout_session_rules.md` §2.3 "Unilateral
  exercises".
