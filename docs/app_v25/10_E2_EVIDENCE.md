# E2 THE MEDICATED YEAR — evidence (the loop's record)

2026-08-10 · what is PROVEN, how, and what remains. Architecture +
decisions live in `09_E2_MEDICATED_YEAR.md`. Frames are
session-ephemeral by standing law; observations here are the durable
record.

## 0 · recon walk (before any code)

QA sim 259952D4, fresh build at c316a7e, seeded program + week +
medication history (the sim keychain restored the account's cloud
CARE-TEAM regimen — Wegovy 1 mg mondays — so this walk doubles as the
B2B face check):

- **The read** (`--uitest-force-read-day`): "your dose week, read. ·
  7 days logged." — signals 6,757 steps vs 5,300 usual · 7 days
  logged · 5 days protein floor; observations protein 5/7 + steps
  27% fuller; teaching; walking-goal proposal. **Zero dose content,
  zero weight — the brief's central claim confirmed on screen.**
- **Becoming**: BODY card reads "163.6 lb · down about 1 lb this
  week" with the trend chart — weight intelligence EXISTS here and
  never reaches the read.
- **Today** (dose day): "take today's shot · your dose day" leads,
  0 of 2; move support is the static ghost "10 min · steady".
- **THE DOSE SHEET** (B2B): "WEGOVY · 1 MG / today's shot / assigned
  by your care team. you record what you took." — six site cells,
  rotation pre-selected, mark it taken. v24 stands.
- **THE REGIMEN home** (B2B): facts read-only, correction door
  ("something look wrong?"), privacy line. v24 stands.
- **FR2 reconciliation cover** rendered on first launch (care plan
  arrival announced). v24/v8 stands.

## 1 · proof ledger

**PROVEN IN TEST** (783/783 app · 113/113 package, zero regressions):
- cycle position: event-anchored, 1…7 always, open-slot-outranks,
  zero daily/non-med leakage, late-take anchoring, seam-day
  schedule fallback (10 pins, RED→GREEN)
- label facts: 7 products' windows/gaps/frames verbatim vs FDA PIs,
  verified negatives (no interruption rule on ozempic/tirzepatide/
  trulicity), compounded-nil-by-construction, attribution law, no
  "take it now", no dose amounts, routing always closes,
  record-gated interruption line (17 pins)
- symptom vocabulary raws + count + mood support-first flag;
  severity re-record fix (custom-id upsert carries valueNum + syncs)
- food-noise return: 3-cycle floor, 2-day cluster, onset ≥ day 3,
  first-entry-per-cycle, broken-run silence (6 pins)
- weight: EMA time-aware fold, clamp, unit-error rejection, band
  thresholds, sufficiency ladder, stale withholding, one-per-day (10)
- the read: dose-week stories × 5, weight signal + early-read
  provenance + cap interplay, drift anti-shame, teaching precedence
  ladder (offer › waning › era › plateau › silence), zero-leakage
  non-med read (16 pins) — E1's 12 composer pins untouched
- evening ask scope: 5-case pure pin
- correction scope: unmentioned-drift discard, hallucination drop,
  1:1 rename, no-silent-delete, global-note wholesale (7 pins)
- analytics: hygiene registry completeness + refusals; cohort
  identity derivation + fingerprint (13 pins)

**PROVEN IN SIMULATOR** (erased QA sim, fresh containers, frames
inspected): the read with the dose observation + weight signal
("−1.2 lb · the weight trend · an early read") + teaching (film) ·
dose day naming the week · THE LATE ROW as first support ("friday's
dose is still open") · THE LATE FACE with the wegovy label card +
attribution + routing · the mark ceremony (video) · the taken face's
"how it's sitting" door · the widened chip list · the mood card
support-first with 988 in-view (scroll fix on film) · the evening
dose ask present on a dose-day evening with cohort set · late-slot
resolution clearing the Today row · XXXL floors on the read + late
face (standing law) · B2B faces (recon walk §0).

**REQUIRES FOUNDER ACTION**: see §5.

**REQUIRES PRODUCTION OBSERVATION**: every §14 success metric —
medicated share (the kill/redirect trigger), dose-resolution rates,
read funnel, food-noise adoption, late-dose card → resolution, the
ur-metric (median active days vs the 2.0 baseline). This build has
not shipped; none of these are claimable today.

## 2 · adversarial loops

- **non-medicated / daily-medication**: composer + anchor pins (zero
  cycle/injection vocabulary; daily keeps its 7-slot count line);
  walked non-med read on sim.
- **on-time / late / skipped / open / missed dose**: all five
  dose-week stories pinned; late face + late row walked; late-take
  cycle anchoring pinned.
- **sparse / dense / stale / absent weight**: sufficiency ladder
  pinned (single weigh-in NEVER speaks a direction; stale withholds);
  suppression honored at assembly (read) + the Becoming weight tile
  gate fixed.
- **unit error / spike days**: rejection + clamp pinned.
- **terminate → relaunch**: local stores; the read's window-signing +
  fact persistence proven in E1 and untouched at the seam; sim
  relaunches through the film sequences held state per container.
- **timezone / DST**: cycle math rides calendar day components on
  the v24 wall-clock engine (its DST pins stand); cycle pins run in
  America/New_York.
- **clinician-prescribed vs self**: care-team resolver precedence
  untouched; B2B faces walked in recon; iOS-never-writes-prescribed
  law untouched (E1 pins stand).
- **notification collisions**: no new sends added (zero budget
  change); the late door is IN-APP; medication exemption pins stand.
- **empty/error states**: no-plan sheet renders the generic label
  line + routing (pinned); freeform medication pinned.

## 3 · frame-caught fixes (the loop working)

1. Em-dashes in the dose observation + six label-fact lines + the
   mood card (voice-law violations) → periods/commas, tests re-pinned.
2. The late row's subtitle truncated ("…or let…") → the row states
   the fact; the sheet carries the verbs.
3. The mood support card opened below the medium detent, unseen →
   the sheet scrolls an expanded chip into view (real-user fix, not
   just film).
4. The dose-sheet film door raced anon-auth restore (+0.4s fixed
   delay opened a plan-less sheet, marks landed on the wrong slot)
   → the door waits for identity.
5. Film-sequence containers cross-contaminated (idempotent seeds
   guard only against themselves) → uninstall-per-scenario
   discipline recorded for E-next legs.

## 4 · known limitations + debt

- **The erased sim's anonymous-auth identity is unstable across
  launches** (a new/late-resolving user per launch until a session
  settles), so multi-launch film proofs (mark → next-evening-quiet)
  are unreliable on this rig. The evening-scope law is pinned pure
  instead. Named debt: an identity-stable QA door (fixed local QA
  user) for multi-launch legs.
- **Accessibility-size Dynamic Type (beyond XXXL)**: the read's
  lines overflow horizontally at accessibility-XXXL — pre-existing
  on the E1 surface (standing floors are non-a11y XXXL, which
  HOLD). Named debt for an app-wide a11y-sizes pass.
- The mood support card is a fixed local resource line (988 /
  findahelpline) — matches ChatSafety's precedent; a tappable link
  treatment is queued polish.
- SymptomDay carries no severity into the pattern engine (presence
  is the v1 signal); severity-weighted patterns are E2.1 material.
- `notif_silenced` still cannot fire (recordIgnored has no
  production caller) — E1's named debt, unchanged by design.

## 5 · founder gates (the era lands WITH the release, or not at all)

E2 adds **no migration and no new founder gate**. The standing gates,
audited:

1. **Apply `supabase/migrations/20260809090000_v24_medication_platform.sql`**
   then **`20260810090000_v25_e1_program_spine.sql`** (order matters;
   E2 rides both, adds nothing). Until then every store defers
   local-first by design.
2. **Deploy `supabase/functions/jeni-chat`** — carries v24's
   timing-empathy rule + E2's cycle + week rules.
3. **`food-vision` EF**: no E2 change (the correction-scope fix is
   client-side; the prompt change rides the same deployed text path).
   The v23-era accuracy deploy remains queued as before.
4. **ElevenLabs key rotation** (v1.1.7 audit, still open — live in
   git history).
5. **Version**: bumped in-repo to **1.2.0 (30)** (1.1.7(28) was the
   old-main RC; 1.2.0(27) never reached Apple). Founder: archive,
   TestFlight, App Store submission — credentials required.
6. **Merge `feat/app-v2` → `main`** — the 448+ commit elephant. This
   era's scope was cut so it ships with that merge, not behind it.
7. **Device walk**: the read in hand · a real lock-screen
   notification action · a real timezone crossing · the late face on
   a real late week · voice pass on the new lines (dose-week
   observations, teachings, label facts, mood card).
8. **PostHog after release**: verify cohort_identified $set arrives,
   med/dose/read families fire, then read the kill/redirect number
   (medicated share of actives).

## 6 · test counts

- Era opened **709/709**; closes **783/783 app + 113/113 package**
  (+74 app / +7 package, zero regressions at every gate).
- New suites: MedicationCycleTests 11 · MedicationLabelFactsTests 16
  · WeeklyReadE2Tests 16 · WeightWeekReadTests 10 ·
  AnalyticsHygieneTests 8 · CohortIdentityTests 5 ·
  SnapRefineMergeTests 7 (package) · MedicationPlatformTests +9.
- RED→GREEN observed for the cycle engine (14 behavioral failures
  before implementation).
