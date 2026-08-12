# E8 — THE MERGE: the reconstructed state, the ledger, the record

2026-08-11 · `feat/app-v2` · RC 1.2.0 (30) · **paywall untouched**
(`git diff` over `Views/Paywall`, `Payment`, `AppPhase.swift`,
`WallView.swift`, `Views/FirstPlate`, `FirstPlateState.swift` is EMPTY
for this era; `e5.firstPlate.enabled` still defaults false).

The mandate: stop building a hypothetical Jeni and ship the one already
built. Nothing speculative — every change below is either required to
make the product measurable, or a founder steer taken mid-build.

---

## 1 · THE ACTUAL BRANCH STATE (measured, not inherited)

The standing number in every prior doc was wrong, and so was the local
ref that produced it.

| claim carried forward | measured 2026-08-11 |
|---|---|
| "475 commits" | **149** commits `main..feat/app-v2` |
| "the merge is the risk" | **fast-forward**; `origin/main` IS an ancestor. Conflicts are structurally impossible |
| — | 427 files, +48,749 / −14,886 |
| — | local `main` was a **stale pointer 343 commits behind `origin/main`** (at `a3fc7f4`, an onboarding-polish commit from before the v11 rebirth). Any divergence measured against it was fiction |

Local `main` has been reset to `origin/main`. The remaining action is a
push, which is a founder gate (§7).

## 2 · WHAT THE RECONSTRUCTION EXPOSED

**Two founder gates carried through five eras were already closed.**
E3 through E7 each recorded "deploy `jeni-chat` and `food-vision` — the
prompts still say *gen-z women* in production until then." Downloaded
the deployed bundles and diffed them against local:

- `jeni-chat` — **byte-identical**, 576/576 lines. Deployed 2026-08-11
  14:09 PDT. Unisex, carries the CA/IL/TX identity line.
- `food-vision` — differs by **one line**, and it is a code comment
  (E7's de-gendering of an authoring note). Zero behavioural drift.

The gate was real when E3 wrote it and stale by E4. Nobody re-measured.
The only remaining action is a cosmetic redeploy (§8).

**Two migrations were never in the founder-gate list.** The standing set
named `20260809090000` (v24) and `20260810090000` (E1). `supabase
migration list` shows **four** unapplied:

```
20260804090000_p6_weekly_summaries      ← never named in any E-series gate
20260809090000_v24_medication_platform
20260810090000_v25_e1_program_spine
20260811090000_care_program_facts       ← never named; E6-era, RPC-only
```

Order is lexicographic = chronological = dependency order.
`care_program_facts` is `create or replace function` only and requires
`program_facts` from E1's migration, so it must not be applied first.

## 3 · WHY PRODUCTION COULD NOT ANSWER ANYTHING

E6 concluded "production data cannot currently discriminate between
in-app features." That is not a fact of nature. Three defects caused it,
all fixed here.

**3.1 TestFlight was indistinguishable from a paying customer.**
`environment` was a compile-time stamp: `#if DEBUG` → "debug", else
"production". **TestFlight builds compile as RELEASE.** So every
internal tester, every device walk, every founder session landed in
PostHog wearing a real customer's clothes — on the event AND the person
profile, where `is_test_user` never got set. E5's finding that "105 of
160 `main_tab_appeared` users never purchased on a hard-gated app" is
only explicable this way. The data was not mute; it was contaminated,
and nothing in the pipeline could say so.

`BuildChannel` resolves the channel at runtime from the receipt name
(`sandboxReceipt` → TestFlight). Three values, `production` keeps its
historical string so this SPLITS a value rather than renaming one — no
existing insight, funnel or cohort filter breaks.

**No attempt to reclassify history.** Events before this build carry the
old two-value stamp and cannot be repaired. Cohort reads should be dated
from the first release carrying `environment == "testflight"`.

**3.2 E7's falsification condition was unmeasurable.**
`21_E7_EVIDENCE` §10.1 names the era's own kill test: "`food_log_created`
within 24h of `purchase_completed`, split by source (`quick_add` vs
`photo`)". Two things were wrong with that sentence:

- The event is `food_log_saved`. `food_log_created` does not exist.
- More seriously: `FoodVisionService`'s decoder is shared by three
  inputs and hardcodes `source: .photo` for all of them. **A typed
  sentence, a nutrition-label photograph and a photograph of food all
  arrive as `photo`.** Written in v1.0.9, when only one of the three
  existed.

So E7 could never have been falsified, merged or not. `EntryMethod` is
derived from the INPUT case at the dispatcher chokepoint and rides
`food_log_saved` as `entry_method`. Deliberately analytics-only and NOT
persisted: correcting `food_logs.source` means touching a CHECK
constraint that no migration in this repo owns (`food_logs` predates
this migrations folder), and repairing the record is a migration's job,
not a telemetry fix. Recorded as open debt (§10).

**3.3 The words path was invisible.** E7 made words the product's front
door and shipped it with **no instrumentation at all** — no
`food_scan_started`, no mode. Photo, label and library all reported one.
Every funnel counting "scans" silently excluded the door E7 built.
Also fixed: the library path sent `source` where its own `scan_started`
sent `mode`, so it was a null bucket on every mode-grouped funnel
(started 100, completed 0).

### The twelve questions, after E8

| question | answerable | how |
|---|---|---|
| purchase → first meaningful action | ✅ | `purchase_completed` → `main_tab_appeared` / `food_log_saved` |
| food capture source | ✅ **new** | `food_log_saved{entry_method}` |
| food log within 24h of purchase | ✅ | `food_log_saved` (note: not `food_log_created`) |
| words vs photo vs barcode vs label | ✅ **new** | `entry_method` ∈ words/photo/label/barcode/again/pantry/restaurant |
| correction behaviour | ✅ | `food_scan_correction_opened` / `_saved` |
| repeat food logging | ✅ | `food_log_saved` over time · `food_relog_used` |
| jeni engagement | ✅ | `jeni_chat_opened` / `_message_sent` / `jeni_read_tool_called` |
| active-day return | ✅ | `main_tab_appeared` |
| day 1 → day 2 | ✅ | `morning_read_shown{clause, has_receipt}` |
| medication cohort (categorical) | ✅ | `CohortIdentity` person properties |
| weekly-read reach | ✅ | `weekly_read_shown` |
| feature exposure denominators | ⚠️ partial | exposure events exist for walk/read/scan; not for every surface |
| **interpretable production cohort** | ✅ **new** | `environment == "production"` now excludes TestFlight |

No new sensitive payloads. `entry_method` is a closed 8-value
categorical carrying nothing about what was eaten; the food family joined
`AnalyticsHygiene`, whose DEBUG assertion refuses free text and
unregistered keys, and a test pins the vocabulary against the enum.

## 4 · HOME — BEFORE → AFTER

**The question asked first** (per the brief, not the fix): what must
Home answer in three seconds, for whom?

| who | what they need | what Home said |
|---|---|---|
| new payer, nothing logged | what do I do first? | `0` inside a calorie ring, "1,800 left" — a budget with nothing in it |
| returning, sparse | am I on track on the thing that matters? | calories |
| **GLP-1 user** | did I get enough protein? | a ring counting UP toward a calorie budget — an instrument that rewards the one behaviour the drug already over-supplies, while the floor protecting lean mass sat one swipe away |
| non-medicated | same protein-first law | calories |
| clinic-connected | care first | (already correct — G9 gates hold) |
| dense data | all five faces | calories first |

Every persona wanted the same lead. `00_THE_SYSTEM` §9 already said it
("protein floor + fiber lead; kcal quiet") and §7.6 said why (protein
1.2–2.0 g/kg is one of exactly two proven GLP-1 content pillars; lean
mass is 25–40% of drug-induced loss). E7 had already applied it in the
reading and deleted the kcal ring there. The most-seen surface in the
app was the last place it was still inverted. With a payer median of
**2.0 active days**, Home's first three seconds are close to the whole
relationship.

E7 deferred this on the grounds that "other surfaces deep-link into the
carousel". **Checked: nothing does.** The `.calories` hits elsewhere are
`NutrientKind` cases in Becoming, a different type;
`--debug-result-carousel` is the food result carousel. The stated reason
was not true.

| | before | after |
|---|---|---|
| lead face | calories, always | **protein**, whenever a floor is on file |
| calories | the lead | second, and in the resting strip with **her** target |
| no protein floor on file | — | calories still lead (E7's law: no denominator without a floor) |
| protein instrument | full-width bar | **ring** (founder steer) |
| other nutrition | one swipe away | **at rest**: kcal · carbs · fat · fiber · sugar · sodium (founder steer) |
| what a ceiling means | unmarked (founder: "kinda confusing") | kcal = her target · fiber/sodium = FDA Daily Value, marked `dv` + footnoted · carbs/fat/sugar = **no denominator** |
| steps in the to-do list | only when six gates aligned | **always**, as an offered row |
| ordering law | one array literal in a private view property | a pure function with 11 tests |

**The sugar decision is deliberate.** The FDA limit is on *added*
sugars; this figure is *total* sugars (USDA "sugars"). Pairing them
would overstate every plate containing fruit or milk. It is the one
comparison a nutrition app is most tempted to get wrong, so sugar gets
no ceiling at all.

**Steps** join as an *offered* row, which matters: offered moves are
excluded from `actionableBeats`, so a standing steps row can never
become debt in the "0 of N" count or read as a missed task. E1's
adaptive walking ask keeps its consent gate and its rank as a support.

## 5 · THE EVENING CLOSE — BEFORE → AFTER

Founder: *"saying that's the day and tomorrow is a balanced day doesn't
tell users much insights or values"* and *"the clickables always need to
be pill formatted."*

Both were right, and the first is the defect E6 fixed on the desk
("your coach, day to day." → "4 plates and 123 g of protein, on file.")
still standing on the surface a returning payer meets every evening.

| | before | after |
|---|---|---|
| line 1 | "that's the day, maya." | "4 plates. 123 g of protein." |
| line 2 | "tomorrow: a balanced day." | "tomorrow is a balanced day. protein first, then whatever else." |
| the taps | three bare 28pt serif words, no affordance | rose chips: blush at rest, jeweled rose when chosen |
| medication taps | bare words | chips selecting by contrast (rose never appears on a clinical surface — 2026-07-28 refinement) |

`EveningCloseEngine` is pure and table-driven, inheriting every honesty
law: protein leads, no denominator without a floor, the denominator
drops once the floor is met (E7 §6.6 — "123 of 90 g" read as a typo),
never "0 g", no verdict, suppression yields words only, and a day with
nothing on file gets *"a quiet day. it still counts."* — never a
fabricated number, never a reprimand (pinned against ten reprimand
words). A line that says nothing cannot say anything wrong; a line that
says something can, which is why the engine is tested at 43 assertions
including a 100+ line cross-product.

E4's de-dup law re-applied: the ledger no longer restates the protein
the typed line just said.

## 6 · UNISEX RELEASE AUDIT — decisions, not a grep count

| system | exposure | verdict |
|---|---|---|
| `jeni-chat` + `food-vision` prompts | every generated sentence | ✅ **already fixed and deployed** (verified byte-level) |
| Home · Today · Food · Chat · Becoming · Wall · post-purchase | the entire first 48 hours | ✅ **already clean.** Swept: the only hits are code comments, `ClinicDemoSeeder` test data, and `case "female"` in a physiology branch — a legitimate sex-specific clinical calculation, preserved |
| the daily Method beat (`RepEngine`/`RepView`) | the method's every-day surface | ✅ **clean** — hand-authored Swift, not the manifest. Only comments carry "she" |
| **Method lesson corpus** (`manifest_v1.json`) | one tap below the rep ("the whole idea") + settings; #2 activity, 132 openers | **KEEP + FIX, scheduled.** Measured 64/84, but that number conflates three things: **22** where the READER is assumed female (must fix), **39** third-person female characters (replace later), **3** study populations (**preserve** — the brief is explicit) |
| `voicePlaybook` authoring rules | every FUTURE lesson | ✅ **FIXED this era.** North star was "the smartest **girlfriend** you've ever had"; anti-shame absolutes said "She did not fail diets". De-gendered, plus a standing rule that study populations are never de-gendered. Lesson content byte-identical, verified |
| Method + breathwork photography | the lesson reader | **REPLACE LATER** — an asset library, not a copy pass. Verified by opening `jm_hero_diet_brain_learned_d1` (day 1's hero): a female-presenting cutout |
| workout library (~128 `woman-doing-X` Lottie) | reachable from Today; 203 users/90d | **RETIRE** — roadmap E3's library kill, deferred a fourth time. Not an E8 fix |

The finding that matters: **the normal product path is already unisex.**
The debt is concentrated in a content corpus and an asset library, both
one layer below the first 48 hours.

## 7 · MIGRATIONS — EXACT ORDER

`supabase db push` applies these in order. **Verify against staging
first if one exists**; all four are additive and idempotent by house
convention, but three have never run anywhere.

```
1. 20260804090000_p6_weekly_summaries.sql      (care_weekly_summaries)
2. 20260809090000_v24_medication_platform.sql  (dose_events + regimen columns)
3. 20260810090000_v25_e1_program_spine.sql     (program_facts + weekly_reads)
4. 20260811090000_care_program_facts.sql       (RPCs; REQUIRES #3)
```

```bash
cd /Users/bko/plankAI
supabase migration list          # confirm the four are still pending
supabase db push                 # applies in lexicographic order
supabase migration list          # confirm Local/Remote now match
```

Until they run the client defers gracefully (local-first, pendingUpsert
outbox) — that path has been exercised by every era since v24.

## 8 · EDGE FUNCTIONS — the gate is closed

Both are deployed and current. The only outstanding item is cosmetic:

```bash
# optional — carries E7's de-gendered code comment. No behaviour change.
cd /Users/bko/plankAI
supabase functions deploy food-vision
```

`jeni-chat` needs nothing: deployed source is byte-identical to local.

## 9 · OTHER FOUNDER ACTIONS

**The merge itself.** Local `main` is reconciled and the merge is a
clean fast-forward. Left unpushed deliberately — publishing to `main` is
the irreversible outward action.

```bash
cd /Users/bko/plankAI
git checkout main
git merge --ff-only feat/app-v2     # 149 commits, no conflicts possible
git push origin main
git checkout feat/app-v2
git push origin feat/app-v2         # 50 unpushed commits incl. E8
```

**Then, in order:**
1. Archive + TestFlight **1.2.0 (30)**.
2. **Device walk** — the simulator cannot reach the vision EF, so the
   single highest-risk unverified link is still E7's: does a typed
   sentence return a good estimate on real hardware over a real network?
3. **Confirm the TestFlight split works** — install the TestFlight build
   and check PostHog shows `environment: testflight`, `is_test_user:
   true`. If that does not hold, every cohort read below is still
   contaminated and nothing else on this list matters.
4. Post-release: read `entry_method` on `food_log_saved`, and
   `food_scan_started{mode: words}` against the 3.4% scan-start baseline.

## 10 · WHAT IS NOT SAFE TO SHIP / OPEN DEBT

- **`food_logs.source` still lies.** Words, label and photo all persist
  as `photo` in the synced record. Analytics is now correct; the record
  is not. Fixing it needs the CHECK constraint verified and probably a
  migration — deliberately not done here, because repairing production
  by hand is exactly what the brief forbids.
- **Historical analytics cannot be cleaned.** Any pre-E8 funnel mixes
  TestFlight with real customers and cannot be separated retroactively.
  Date cohort reads from the first `testflight`-stamped release.
- **Two hour sources.** `HomeView.isEvening` reads the real clock while
  `TodayStateService.hourOfDay` honours `--uitest-force-hour`. A QA
  inconsistency (`--uitest-force-day` is the working door), not a
  production bug — but they should converge.
- **The Method corpus** (§6) — 22 lessons where the reader is assumed
  female. The largest remaining unisex debt.
- **Beyond-XXXL** app-wide debt unchanged.
- The `--uitest-force-hour` / evening-close interaction, the desk's dead
  space (E6 §6.4) and the describe path's clipped picks rail all stand.

## 11 · VERIFIED

- **933/933 app** (+43) · **133/133 package** (+8) · zero regressions.
- New suites: `BuildChannelTests` (9), `HomeHierarchyTests` (11),
  `EveningCloseEngineTests` (18), `EntryMethodTests` (8), plus 5 hygiene
  tests for the food family.
- **The paywall is untouched** — `git diff` over the six paywall /
  payment / entitlement paths is empty for this era, and
  `e5.firstPlate.enabled` still defaults false.
- Walked on the simulator in four states (empty, dense, evening, and the
  post-fix re-walks), each captured and inspected.

**What the walk caught that tests could not:** the protein face left
~120pt of void on a brand-new payer the moment it started leading (it
had been leaning on a week sparkline that needs two days of data, on a
page nobody ever arrived at); and the nutrition strip sheared its second
row — labels rendered, values clipped — against a face height sized for
the protein block alone.

**What my own tests got wrong:** two assertions failed on correct
output, and they were the exact trap E7 §5.4 recorded — a
`contains("0 g")` matcher firing on "4**0 g**", and an `of`-check
firing on the phrase "72 g **of** protein". Both rewritten as anchored
regexes with a test for the matchers themselves.

## 12 · WHAT E9 SHOULD BE

Not decided here — E8's job was to stop building and ship. But the
evidence points one way: **for the first time, the next decision can be
made from production instead of from a walked opinion.** E1–E7 are
seven stacked hypotheses that have never met a payer; four weeks of
clean `environment == "production"` data against the questions in §3
would falsify or confirm several of them at once.

The ranked product candidate, if the founder wants one anyway, remains
E7's: the Method corpus (§6) — it is the largest single quality debt
left, it is the #2 activity, and it is the one place the product still
reads as women-only.

---

## 13 · THE EVENING CLOSE, SECOND PASS (expert review)

The founder read the rebuilt close and said *"the contents here are not
so useful"*, then asked for a weight-management expert to decide what
belongs. The review's diagnosis was sharper than the brief:

> the screen makes up to **seven asks and pays out once**, and every
> payout lands on day N+1 — tomorrow's shape, smaller plates tomorrow,
> fiber tomorrow — on a base whose median payer lives **2.0 active days**.

E7 named that pattern and fixed it in the reading. The evening is where
it survived, including in code I had just written: `sitAck` answered a
person who had said she felt queasy with *"mild plates + fluids
tomorrow."*

**Built: THE PROTEIN CLOSE.** The one sentence on the screen that can
still change today. It replaces tomorrow's line whenever a gap is open,
and it carries a door (`Route.foodDescribe(text:"", spoken:false)` —
E7's path, empty, because jeni never authors a plate).

```
gap ≤ 25 g   there is still time tonight. 18 g would close it, and a
             cup of greek yogurt is about that.
gap 26-40 g  there is still time tonight. a shake or a cup of cottage
             cheese is about half of what's left.
gap > 40 g   there is still time tonight. anything with protein in it
             helps, even something small.
floor met    protein landed. that is the part that holds the muscle
             while the weight moves.
```

Two mechanisms, and the second is why it belongs in THIS product:
feedback pointing at the next action beats feedback pointing at the self
(Kluger & DeNisi 1996 — a large minority of feedback interventions make
performance worse, and self-directed feedback is that variety); and **on
a GLP-1 the gap is invisible to her** — ad-lib intake falls sharply, so
she is not hungry and has no internal signal that she is 30 g short.
This is the clearest case in the product for a number a person cannot
feel.

The named foods are the cold / soft / low-odor set on purpose: delayed
gastric emptying makes warm, rich, large food the worst answer here, and
that same list is the nausea-safe one. One list serves the full stomach
and the queasy one, so the feature needs no branching.

Guards, all tested: no floor on file → no line (E7's law) · floor met →
no gap, no door · a gap over 40 g never names its number, because at
that size the number is a rebuke not a target · suppression keeps the
offer and drops every numeral · **the medication adequacy net suppresses
it entirely**, so a person the care net is about to speak to gently is
never counted grams at.

**Also built: the acknowledgments now act tonight.** `sitAck` moved off
"tomorrow" — "staying upright a while tends to help", "cold and plain
sits easier than warm and rich". GI symptoms are the leading reason
people stop these medicines, and the moment of the complaint is the only
moment the help is wanted. Clinical register unchanged: observed never
prescribed, no dosing guidance.

**NOT done, and deliberately left to the founder.** The review also
recommended cutting the day-number hero ("12 of 140 days" — the only
number on the screen that isn't hers, and a goal gradient running
backwards) and the nightly trend row (a weight verdict delivered every
night, which sits badly with the product's own opt-in stance on daily
weighing). Both arguments are good. Both are settled product decisions
(v12 R6 established the hero deliberately), and E8 is a convergence era
— reversing them is a founder call, not mine.

**Verified**: 942/942 app (+9). The floor-met branch is filmed; the gap
branches are pinned by exact-string tests but NOT filmed, because no QA
seed produces an under-floor day. That is an honest gap in the visual
record, not a claim of coverage.
