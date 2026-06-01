# Voice clip orphan audit — 2026-06-01

Cross-referenced 1,156 .m4a files under `PlankApp/Resources/VoiceClips/` against
all known clip-resolution patterns in `RoutineAudioManager.swift`, exercise IDs
in `ExerciseBankData.swift` (128 IDs), and literal cue references in code.

**Result: 63 base names with no code reference found** (likely ~100-120 files
counting coach variants, ~3-5 MB total).

Not actioned in this pass because per-file savings are too small to justify
the risk of false positives. Saving the list here for a future cleanup pass —
ideally bundled with the next ElevenLabs re-recording run (skip generating
these base names) OR after an On-Demand Resources migration that splits
clips by coach.

## High-confidence dead (likely safe to remove)

These have no pattern referenced AND no literal string match in source:

- `camera_bad_1`, `camera_bad_2` — camera form-feedback feature appears unused
- `guide_good_1-3`, `guide_setup_1-3` — old plank-session guide clips
- `kira_preview`, `method_preview_jeni`, `method_preview_kira`, `method_preview_matson`, `preview` — old coach-selector previews
- `end_bad`, `end_good` — old session-end variants
- `start_1`, `start_2`, `stopped_1-4`, `routine_start_1-3` — old session-state cues

## Unknown — verify before removing

These MAY be referenced via dynamic constructors not caught by the grep:

- `tempo_1-4`, `tempo_drive_1-2`, `tempo_twist_1-2` — tempo cues (8 clips)
- `milestone_10/30/60/90/120` — plank-duration milestones (5 clips)
- `shoulder_1-4`, `hip_pike_1-4`, `hip_sag_6` — plank form cues (9 clips)
- `countdown_10` — extended countdown (1 clip)
- `intro_<exerciseID>` for IDs NOT in the current 128-ID exercise bank (~15 clips)

## Verification before cleanup

Run app, walk through:
1. A full workout session (verifies prep_, rest_, encourage_, roast_, hold_, switch_sides_ all play)
2. A plank check-in (verifies hip_sag_, hip_pike_, shoulder_ if these are plank form cues)
3. A plank session at increasing durations (verifies milestone_X plays at the X-second mark)
4. Coach selector with audio preview (verifies preview clips)

Anything that plays a clip = the clip is in use. Cross-check with this list.

## Bigger lever

Voice clips are perfect On-Demand Resources candidates. Split clips by coach
prefix (`jeni_*`, `matson_*`, no-prefix Kira). User picks a coach in onboarding,
their coach's clips prefetch via ODR. The other coaches' clips never download.

- Per-coach clip total: ~12-15 MB
- Savings: 25-30 MB off install size for any user who isn't multi-coach
