# 08 — Existing-user migration + first-run education

## Who gets what

| User | Experience |
|---|---|
| Existing paid, has program | `migration` phase: "the new jenifit" moment (once), plan continuity, land on Today |
| Existing paid, never enrolled | same moment; third beat becomes "begin your plan" → v2 onramp |
| New purchase (post-v2) | `firstRun`: rebuilt post-purchase flow |
| Existing unpaid / expired | wall (07); after paying they get the migration moment too |

Flag: `appV2SeenAt` (ISO). `hasLegacyFootprint` = any
SessionLogRecord/DayProgressRecord/ProgramPlanRecord exists OR
programEraEnabled was true.

## The migration moment (≤40 seconds, skippable after beat 1)

Three beats in the OV5 language over the persistent atmosphere, an
earned moment (sticker scatter allowed — it's a welcome):

1. **"jenifit grew up ♥"** — serif hero + one paragraph: her data is
   intact, her plan continues, day N acknowledged by name and number
   (provenance from her real plan).
2. **"meet jeni, properly."** — chat teaser card with her REAL first
   brief line (generated from her actual state; not lorem) + "she
   reads your plan, plates, and trend."
3. **"today, redesigned."** — mini device-frame render of HER actual
   Today (live SwiftUI, reusing the JFDeviceDemoFrame technique with
   real beats) + hold-to-continue seal (the onboarding's signature
   gesture) → Today.

Program continuity rules: active `ProgramPlanRecord` is preserved
untouched — same start date, same day number, same goal date. Only
the *rendering* changes (prescription engine v2 composes from the
same plan + tier). If plan fields needed by v2 are missing (goal
weights nil), TargetsService degrades to non-numeric gracefully.
Checks history renders in the new strip unchanged
(ProgramDayCheckRecord is untouched).

Key backfills on migration commit: `appV2SeenAt`, `wasEverEntitled`,
canonical cohort keys pushed to users columns (06.B) so her next
device gets them.

## First-run (new payers) — rebuilt PostPurchaseFlow

Keeps the single-cover, internal-crossfade architecture. New beats:

1. **forging** (kept, retimed) — the plan seals.
2. **meet jeni** — replaces CoachIntroView's video-era intro: one
   screen, her first message types itself (JKStreamText locally, no
   network), one suggestion chip ("what do we do first?") that
   pre-seeds the chat later. Sets the relationship register.
3. **first two things** — two rows in device-demo grammar:
   "breathe with her, 60 seconds" (starts breath cover inline) and
   "snap tonight — {promise anchor}" citing her demo meal
   (`onb_v5_snap_demo_meal`) + promise hour. Both optional, one CTA:
   "open today."
4. Lands on Today with the day-1 plan and jeni's brief waiting.

Education happens IN the surfaces, not a tour: first-open coach
marks (3 max, one-time): the cross-off gesture on the first beat
row ("tap to enter · it strikes through when done"), the camera
mark, the jeni tab dot. Each is a quiet caption + hairline pointer,
dismissed on first interaction, never modal.

## Comms

No push about the update (policy: useful > announcements). The
migration moment IS the announcement. Release notes stay factual.
