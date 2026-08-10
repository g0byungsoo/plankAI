# v25 GAP MAP — the walked product vs THE SYSTEM (2026-08-10)

Method: the shipping v24 build (1.1.7 (28), e3bb8f4) walked on the QA
sim (`audit/03_walk_notes.md`, frames verified by the orchestrator's
own eyes: home top/bottom, dose sheet, b2b regimen, becoming
top/bottom); compared surface by surface against `00_THE_SYSTEM.md`.
Coverage honesty: the walk could not reach the food interior (THE
BOOK/READING), chat in conversation, carousel faces 2-5, settings
depth, or onboarding interior (§13 of the walk notes) — those gaps
are asserted from code reality (`audit/01_app_reality.md`), not
pixels.

The headline: **the surfaces are ready; the system behind them is
missing.** v21-v24 built instrument-grade surfaces that already obey
THE SYSTEM's information architecture (the ≤3-action cap, supports
outside it, authority-split regimen faces, provenance-honest
becoming). What does not exist yet is the adaptive layer those
surfaces are waiting for: no program memory, no weekly ritual, no
notification brain, no measurement. The gap is architecture, exactly
as the era intended.

---

## THE RANKED GAPS

**G1 — The weekly ritual does not exist.** (SYSTEM §7, §12 loop 3)
Becoming shows reads (the sodium card is an observation) but nothing
reviews the week, teaches once, and offers ONE change; ReSigningView
is a quiet door, not a dose-day-anchored ritual; nothing ends in a
plan adjustment. The defining loop of the product is absent. → E1.

**G2 — No program memory.** (SYSTEM §6-7)
Targets are derived + static: the walk caught the calorie target
flipping 1,473 ↔ 1,596 with seed order (derivation, not record);
steps anchor is a hard-coded 7,500; no fact carries authority
(prescribed/preferred/recommended) or basis (measured/inferred);
nothing supersedes, nothing is consented. The b2b regimen face proves
the pattern exists for medication only. → E1.

**G3 — Five notification schedulers, no brain.** (SYSTEM §9)
Orchestrator, retention, medication, recap, dormant-trial all schedule
independently; no shared budget, no timing heuristics, no
auto-silence, no holdouts. The <5/week cap is a convention, not an
enforced arbiter. → E1.

**G4 — The system cannot see itself.** (SYSTEM §14)
v24 medication shipped zero analytics events; Becoming's interior and
Home's checklist marks are dark; orphaned constants mislead. No
adaptive claim is verifiable until this floor exists. → E1.

**G5 — Today has no movement intelligence.** (SYSTEM §9 MOVEMENT)
The walk shows "move · 10 min · steady" as a static ghost chip; there
is no walking-gap action ("2,100 steps left"), no post-meal walk
composition, no strength beat, no HealthKit-workout absorption. → E1
(walking + absorption) and E3 (strength).

**G6 — The medication arc stops at logging.** (SYSTEM §9 MEDICATION)
The dose sheet + regimen home + era record are pixel-perfect — but
nothing frames the cycle day ("day 6 of 7"), food noise is not a
vital, the late face carries no label facts, the symptom vocabulary
misses the underreported set, and there is no maintenance era.
Walk-caught polish item in the same area: **the becoming medication
tile hides under NOT ENOUGH TO READ YET despite an active regimen on
a dose day** — the tally floor is tuned stricter than the era-facts
read requires. → E2.

**G7 — Food logs but does not learn.** (SYSTEM §9 FOOD)
Corrections exist (FoodCorrectionSheet live) but evaporate — no
priors, no clarifying question, "again" lives only inside the book
(which no door reaches — the walk could not open it), no lighter
modes for week 4+, no repeat-first logging. → E4.

**G8 — The method still sells the dead form.** (SYSTEM §9 METHOD)
The tools tile reads "your inner critic has a script" — a lesson
library pitch the evidence buried; no moment-tools shelf exists; the
84-lesson corpus sits unreachable behind the settings archive. → E5.

**G9 — Jeni answers without her record.** (SYSTEM §8)
The empty state asks the right questions ("explain my trend") but the
tool set has no longitudinal reads to answer them with; walk flag:
"your coach between visits" renders for a consumer-seeded profile —
verify cohort gating of care-flavored copy. → E5 (copy check: now).

**G10 — The clinic has data but no judgment.** (SYSTEM §10-11)
The b2b patient face is shipped and correct; the dashboard is
list-only — no attention queue, no four-signal model, no silence
detection, no one-pager v2, no HOLD/SLOW, no knobs; nothing is
deployed anywhere. → E6 (build against demo tenant; founder gates
pace the pilot).

**G11 — Becoming reads, but never proposes.** (SYSTEM §7)
Insight cards observe ("less held water") and stop; the
review-and-plan grammar (data → one teaching → one accepted if-then)
has no slot. Subsumed by G1's ritual. → E1.

**G12 — iOS-surface absence.** (SYSTEM §9 NOTIFICATIONS, E7)
No widgets, no dose-day Live Activity (only the scan Live Activity
exists). Deliberately last: surfaces before the brain would add
noise. → E7.

## TOOLING GAPS (the loop's own instruments — riders, not eras)

**T1 — The film doors do not self-drive.** All six `--uitest-walk-*`
doors + `--debug-gallery-tour` armed XCUITest walkers and filmed a
static Home; v25's verification method requires either walker-driven
recording legs or true in-app film drivers. Fix as an E1 rider (the
weekly read needs a filmable door from day one).
**T2 — THE BOOK has no direct door** (`--uitest-open-food-journal`
no-ops — points at a retired journal). E4 rider.
**T3 — Seed determinism**: self med-seed cannot replace a b2b seed
(correct law, surprising QA); calorie target drifts with seed order
(G2's smell made visible); `--uitest-becoming-bottom` needs
`--uitest-start-tab becoming`. E1 riders.
**T4 — The program-ready gate rides INSIDE the tab shell** — tabs
visible and presumably tappable before a program exists; verify
becoming/scan behave sanely pre-start. Immediate check in E1.

## WHAT THE WALK CONFIRMED IS ALREADY RIGHT (no gap)

- The ≤3-cap + supports-outside-it grammar (SYSTEM §5) — shipped, in
  pixels, lovely.
- The authority split on regimen faces (SYSTEM §2) — self = editable
  doors; clinic = read-only + correction door + "not a prescription";
  the reconciliation pattern exists.
- Provenance honesty everywhere ("no nights read yet", "estimated",
  "not connected") — the uncertainty register SYSTEM §7 requires is
  already the house style.
- The keep wall (billed-today, honest anti-anchor math) — exempt and
  healthy.
- One visual system: rose-as-data, ink trajectories, serif facts —
  the design law holds on every walked surface; v25 needs no visual
  reset, only new composition inside it.

## THE VERDICT

The ranked gaps cluster exactly as the roadmap predicted: G1-G5 (+
G11, T1, T3, T4) are ONE era — the spine. G6 is E2, G7 is E4, G8-G9
are E5, G10 is E6, G12 is E7. The first implementation era stands
confirmed: **E1 THE SPINE** (`04_FIRST_ERA.md`).
