# PASS 55 — THE PRODUCT I WOULD SHIP

**Built 2026-08-20, on feat/app-v2, after pass 54 (THE JENI METHOD).
The convergence pass: not "what else can we build" but "what would make
100 paying strangers distrust, misunderstand, abandon, or regret."
Nothing archived, uploaded or submitted. `CURRENT_PROJECT_VERSION`
stays 33 (the archive-time convention stands).**

This record answers the brief's 46 questions in order, then closes
with the verdict block.

---

## 1. What exact product did Pass 55 start with?

HEAD `af9e962` ("v25: converge record, first day, answering record,
and Jeni Method"), `CURRENT_PROJECT_VERSION = 33`, `MARKETING_VERSION
= 1.2.0`, tree clean except the `.gstack` browse logs. Baselines
re-measured from xcresult, never inherited: **app 1483 passed · 0
failed · 2 skipped (1485 total) · PlankFood 242/242 · PlankSync 29/29
· Release BUILD SUCCEEDED, 0 errors** — each exactly pass 54's
recorded close.

## 2. What founder-gated operations existed?

Five, from the pass-54 record: ① apply the pass-53 migration
(`20260818090000`); ② the EF envelope block (season/band_zone/
method_now) deploy; ③ the waist-trend `ObservationKind` decision;
④ the v4.5 OnboardingView sweep; ⑤ the archive-time bump 33→34.
This pass **executed ① (the brief explicitly authorized it, gated on
the hostile audit) and ④ (the brief's §15 instruction)**. ② and ③
remain founder-gated; ⑤ remains the archive convention.

## 3. Was the Pass 53 migration correct as written?

**YES — audited as hostile input against the live catalog first.**
Read-only audit (queries mechanically proven read-only: one statement,
SELECT-only, zero write keywords) of `regimen_plans` + `dose_events`
on production established: none of the five columns pre-existed (no
silent `if not exists` type-collision), **`schedule_rule` carries NO
CHECK constraint** (so `intervalDays` as a value was never refused —
only the unknown columns failed pre-migration, exactly as §5 of the
p53 record stated), grants are TABLE-level SIUD for `authenticated`
(new columns inherit them), RLS policies are row-scoped (new columns
covered), no triggers. Wire-shape check: all five DTO fields ride
`encodeIfPresent` optionals with types matching the columns (int↔Int?,
date↔"yyyy-MM-dd" dayKey, text↔String?); Codable ignores unknown keys,
so old clients are safe in both directions. The account-handoff mover
(`private.transfer_account_rows`, read from `pg_proc`) rewrites
ownership with `update … set user_id` — whole rows, never an INSERT
column list — so handoff preserves the new fields **by construction**.
Deletion is covered by the `on delete cascade` FKs to `auth.users` on
both tables (read from the live constraints).

## 4. Was it applied?

**YES.** `supabase db push --linked` after a dry-run confirmed exactly
one pending migration. sha256
`31681bcfa64f2bf042616d005f8b60cffc6953fed8ebd52f68042f7a0e26152a`.
`supabase_migrations.schema_migrations` now records `20260818090000`.

## 5. What live verification proves it?

Post-apply catalog read: all five columns present. Then a **13/13 live
round-trip probe as a real client principal** (publishable key only —
the app's own surface; two throwaway anonymous accounts, both deleted
through the shipped `delete_user_account()` RPC): upsert of a
`schedule_rule='intervalDays'` plan carrying all four new fields →
**read back verbatim** · `dose_label` on an event → read back · replay
upsert idempotent (one row, same values) · PATCH edit round-trips ·
**B cannot read or rewrite A's plan (RLS, 0 rows)** · bare anon key
401 · `delete_user_account` removes everything (plan invisible to any
principal afterwards). **Net production mutation: zero rows, zero
accounts.**

## 6. What did the ordinary weight-loss journey expose?

The door-free reviewer journey (fresh erased sim → real v8 consult →
wall → every exit → relaunch) passed on the post-deletion build — see
§45. The record-side journey exposed the pass's biggest food finding:
**the defaulted-init drop family had three NEW instances (#7–#9)**.
`setLoggedDay` and BOTH sign-in merge branches re-init `Entry` by hand
and predate p53's `edits`/`barcode` fields — so **redating a plate, or
signing in after an anonymous period, silently erased her hand edits
and the verify-once barcode key from BOTH copies of the record** (the
whole-row upsert pushes the nulls). RED 5-of-6 → GREEN: the three
sites now go through ONE `Entry.with(id:userId:loggedAt:)` mutation
helper that names every field exactly once — the family is closed at
the persister the way `CapturedFood` closed it at the capture layer.
Also fixed: the words door's missing empty-plate guard (an unparseable
sentence filed a 0-kcal "scanned plate"), and the double-tap file
latch (the old guard engaged only once the answer provider returned;
with no provider a double-tap filed two plates).

## 7. What did the GLP-1 journey expose?

**Five P0-class regimen findings, all the same defect class pass 54
closed in the Method (M1) — surviving in other consumers**, all
verified firsthand, all RED→GREEN (`red_regimen.xcresult` retained,
9 failures of 12; the 3 that passed were the weekly controls):

- **Home's dose-day lead said "the week starts here" to every interval
  and split user** (`BrandVoice.doseDay` took no cadence; the gate
  excluded only daily). A Mon+Thu user heard "the week starts here"
  twice a week. Now cadence-aware: weekly keeps its sentence; every-N
  gets "the rhythm starts here"; splits get the plain fact.
- **The evening prep line** ("tomorrow is your dose day. the week
  starts there.") — same defect, one screen earlier. Same fix through
  `EveningCloseEngine.Input.tomorrowDoseCadence`.
- **CarePlanEngine still ran the hardcoded `dayInDoseWeek >= 6`** —
  M1's exact arithmetic in its third consumer. A q10d user heard
  "appetite often stirs about now" on days 6–7 (mid-cycle, false) and
  a q5d user never heard it at all (her waning band is days 4–5, the
  gate started at 6). The Input now carries the cycle-length pair and
  the gate is `CyclePosition.band == .waning` — the engine's own law,
  fourth consumer converged.
- **The clinician packet proposed "mention how the weekly rhythm is
  fitting" at every cadence** — against its own header line ("your
  medication, every 10 days"). The word "weekly" is deleted; "the
  rhythm" is true for every plan.
- **Two `isDoseDay` calls omitted `events:`** (a silent `[]` default):
  `DoseStanding` read the un-re-anchored grid, so a q10d user whose
  first shot ran late saw **"your shot is today" on a phantom day and
  nothing on her real dose day**; worse, the mark chokepoint
  (`currentDoseSlotKey`) could resolve a tap onto a day that is not a
  slot in her chain. Both fixed — and **the `events:` default is
  REMOVED from the signature**, so a caller with genuinely no events
  now writes `events: []` where a reviewer can see the decision.

## 8. What did the non-standard regimen journey expose?

Beyond §7: **the pattern engine's final open cycle was hardcoded to 7
days**, so a food-noise onset on day 8+ of a q10d cycle was invisible
to the signature observation built for exactly those users (fixed:
`cycleLengthDays` threaded from the plan's own facts at both call
sites, pinned by a day-8 test) · **the regimen sheet named a bare
weekday for a next dose up to 13 days out** ("thursday" — which
Thursday?); >7 days out it now reads "in 12 days · thursday" ·
**`rhythmLine`'s `default:` said "weekly · pick a day" to an
`asNeeded` plan** (reachable the moment a care team hydrates one) —
now "as needed". The engine itself was clean: every `switch` over
`Cadence` audited, no branch collapses everyN/twiceWeekly into weekly;
re-anchoring reaches reminders, Home, the packet's adherence math and
the evening line; `doseStageLabel` has no reader that could print the
plan's label over the event's.

## 9. What did repeated-food/correction testing expose?

The subtractive half of the qualifier law was missing: the normalizer
strips the persister's `" + N more"` suffix, so **typing "greek
yogurt" exact-matched a filed "greek yogurt + 2 more" and re-served
granola and honey she never said**. The additive half ("half a…")
has been law since p27; the subtractive direction now is too: a plate
holding foods beyond the sentence is contradictory evidence and never
matches (naming the whole plate, artifact and all, still re-serves
it). Also: **fix-with-words after a hand edit erased the hand edit**
(`SnapRefine`'s re-init dropped `editNotes` — in the one file whose
header declares the family closed); the composition is now a pure,
tested seam that carries `editNotes` + `usualApplied`. And **a spoken
fix on a barcode/label plate kept the printed-truth stamp over numbers
the model just produced** ("these are the package's numbers" — a lie
from inside); a fixWords on a printed-truth source now restamps
`.words`, the honest door for what just happened.

## 10. Can Jeni now remember a corrected usual reliably?

**YES — through every mutation path, pinned.** `Pass55FieldCarryTests`
(RED 5/6 → GREEN 7/7, artifact `red_food_carry.xcresult`): redating
keeps edits+barcode+corrections+`wasVerified`; both merge branches
carry everything; the refine seam carries the memory; the barcode
verify-once key survives every re-key. And the p53 promise that was
dead code now works: **"use the package" renders on the barcode door**
(the raw package read is held aside when a verified usual replaces it,
one tap restores it — `onEstimateFresh` was simply never passed on
that door).

## 11. What did the Apple Health provenance journey expose?

**The importer kept the day's LATEST Health sample while the entire
trend fold is calibrated on the fasted-morning bias** — for every
scale user, the one row per day the import writes was the evening
number, and the canonical earliest-of-day reduction then faithfully
returned it. Now earliest-per-day at the importer. Deletion held
clean under attack: id + day + zone-proof instant tombstones all
honored, correction relabels to `manual` so the importer stands down,
and **the deletion-ledger sweep is no longer gated behind the launch
hydrate** — a settled payer (no locally-empty family) never hydrated,
so an offline delete whose server call failed was never re-asserted
and returned on reinstall. The sweep now runs on every launch.

## 12. Does weight have exactly one customer-facing truth?

**Closer than it has ever been; the full-codebase sweep found 52
consumers and the exceptions are now converged or named.** Fixed this
pass: **the band whisper fed the RAW newest row into
`BandModel.zone(emaKg:)`** — the exact violation BandModel's own
header forbids; one salty morning made the save-moment whisper
contradict Home's band field (now reads the snapshot's own zone) ·
**the fast fold's undocumented consumers converged on the canonical
fold**: ONE loss rate (the brief's "faster than 1% a week" ran a
14-point fast-EMA span while the preservation read ran a raw 21-day
first-vs-last — same threshold, adjacent sentences, different
answers), ONE flat-weeks count (the arc's "bend" could name a plateau
the Method and the weekly read refuse), and the three dead fast-fold
helpers are deleted · **the Method's jump notes subtracted across two
universes** (latest = raw newest row including the sign-up
self-report; previous = row-level excluding it) — both now read the
canonical day-reduced series, so a same-day pair can never fake an
overnight jump and the consult answer can never be the "latest" term ·
**Becoming's tile folded a window-truncated series** (the τ-EMA
re-seeded at the chart edge, so the tile's weekly delta could differ
from Home's) — the fold runs over the whole record now; the window
only decides what the chart draws · the tile's "from your weigh-ins"
caption over a sign-up-only record now says "from your sign-up
answer" · `priorWeighInCount` excludes the sign-up row (a genuine
first weigh-in gets the first-weigh-in words) · the care summary
counts weigh-in DAYS, not rows · the dead `trendJustReadable` note
(unsatisfiable gate: `weighInCount == 3` fed by fast-fold points,
while a band needs ≥4 obs) now fires at the true crossing (band
exists while the record's span is ≤21 days, once ever) · the v8
consult's projection figure spoke lb to kg users — unit-aware now.
**Named, not fixed** (semantics, not accidents): "current weight" =
the ladder's newest row everywhere; the trend's "latest" = the
morning sample the drawn line ends on — when a day holds both, jeni's
read tool now carries an in-band note explaining the difference
instead of embodying it. "Start" = the enrollment statement, one
semantic across journey/envelope.

## 13. What did movement testing expose?

Pass 53's "counts everywhere" claim verified at all seven consumers —
plus two it didn't claim (chat envelope, follow-up falsification). Two
real defects fixed: **the Home strength tile read `MoveManualStore`
during body evaluation but nothing invalidated Home when the Move
SHEET dismissed** — a session she just deleted stayed counted (and
"strength met this week" stood) until the next backgrounding; the
sheet path now refreshes like the cover path always did · **the
clinician packet published her hand-recorded sessions inside a bare
integer** — the one surface where a self-report read as a measurement
changes a decision now carries `strengthRecordedByHand7` and renders
"3 sessions · 2 recorded by her" (app + print + payload). The Home
tile also gained the `everRequested` gate its two siblings had.
**Named, not fixed:** HealthKit+manual double-counting has no dedup
anywhere — the door is named "add what health missed" and MoveSheet
discloses the split ("1 from health, 1 you recorded"), so the honest
fix is behavioral, and inventing a time-window dedup heuristic would
guess; deletion emits no analytics retraction (P3).

## 14. What did the GLP-1 nutrition/hydration evidence review establish?

A full evidence review (primary sources opened; the two 2025 anchor
documents — the ACLM/ASN/OMA/TOS Joint Advisory and the Obesity
Pillars Delphi — read against each other): intake reduction magnitude
is PROVEN (−24%/−35% ad libitum; durable at 60 weeks) · GI adverse
rates and their titration clustering are PROVEN (STEP/SURMOUNT
pooled) · **the labels' dehydration→AKI warning is REGULATORY tier**
("the majority of reported events… in patients who had experienced
nausea, vomiting, or diarrhea, leading to volume depletion") · the
drug class **blunts thirst itself** (Winzeler 2021: −490 ml/day, RCT)
— so "drink when thirsty" is not a safe heuristic here · protein
targets (1.2–1.6 g/kg) are CONSENSUS, not trial-proven; observed
inadequacy (mean ~0.78 g/kg; 43% reach 1.2) is LIKELY · lean-loss
fractions PROVEN (~40% STEP-1, ~26% SURMOUNT-1); mitigation on GLP-1
specifically is extrapolated (LEAN-PREP still running) · the ≥2 L/day
figure exists only in the Delphi, self-graded "Observational,"
self-caveated for HF/kidney — **the Joint Advisory deliberately
publishes no number**.

## 15. Which GLP-1 nutrition claims were proven / plausible / consensus / unknown / folklore?

The full tiering is in the pass's research ledger; the load-bearing
classifications: PROVEN — intake reduction, GI time-course, label AKI
warning, reduced high-fat preference (small RCTs), lean-loss
fractions. LIKELY — reduced fluid intake (mechanism + adjacent RCT;
magnitude in this cohort unmeasured), observed protein inadequacy.
CONSENSUS — the protein floor, ≥2L fluids (Delphi only). UNKNOWN —
individual appetite trajectories, fluid intake magnitudes.
**FOLKLORE — "GLP-1 users eat carbs instead of protein and fat"**
(contradicted twice: trial ad-libitum composition unchanged;
real-world carb share BELOW the AMDR while fat sat above — everything
shrinks together; the real phenomenon is days-long bland-food symptom
behavior). Also folklore: "alcohol hits harder" (the only pilot shows
a *delayed* rise). A citable dissociation worth keeping: **hunger
feelings return by week 40–60 while measured intake stays lower** —
"feeling hungry again" is not "the drug stopped working."

## 16. Did hydration earn a place in Jeni?

**The refusal to prescribe a volume or build a tracker STANDS —
re-verified against the strongest counter-evidence** (the Delphi's
2 L is consensus-tier, self-caveated; FRESH-UP actually *weakened*
the case for restriction being harmed by liberal intake but created
no license for a diagnosis-blind app to push a number). What earned a
place is one **label-tier routing signal**, not a tracker — see §17.
The standing copy-only surfaces (queasy-day fluids note, menses-onset
water) were re-read against the evidence and hold; the queasy note
already carries the PI's own mechanism and the thirst-blunting fact.
A thirst-reassurance sweep of all copy found zero instances of "let
thirst guide you" — the one mention of thirst in the product warns it
is being quieted, which is the honest direction.

## 17. If hydration was implemented, what is the smallest useful version and why?

**One new symptom word and one routing note.** `dizzy`
("lightheaded") joins the side-effect vocabulary (the logger, chart,
packet and sync all generalize; the live `observations` table has no
CHECK constraints — verified read-only — so the value syncs freely).
`dizzy_fluid_loss_v1` (tier `.strong`, the labels' own warning):
lightheadedness logged in the same window as a GI-loss symptom →
"lightheaded, in the same stretch as {her own symptom word}. that
pairing is worth telling your prescriber about." It ROUTES, never
diagnoses; no volume, ever; it sits above the fluids teaching in
priority and — deliberately — does **not** stand down for the
adequacy net: a routing note is not a teaching, and the label's
warning outranks the one-voice law. Pinned by 4 tests (dizzy alone =
silence; GI alone = the unchanged teaching; the pair = the route,
even over the net) plus the catalog's own tripwires, all of which
fired on the addition exactly as designed (priority pin, tier table,
fingerprint, analytics vocabulary — each demanded a deliberate
re-pin).

## 18. If hydration was not implemented, why not?

The tracker/volume half was not implemented because no evidence
supports an app-prescribed fluid number for a population whose
fluid-restricted members (HF, advanced CKD, hyponatremia) are
invisible to the app — and the strongest available fact (the label's
"take precautions to avoid fluid depletion" during GI trouble) is
better expressed as event-conditioned interpretation of HER record
than as a daily denominator she must feed.

## 19. Did the existing protein system require any change?

**No new protein feature** — the floor lands exactly on both 2025
consensus documents, the adequacy net's direction (under-eating
flagged, never celebrated) matches the observed risk, and the
count-up grammar is the epistemically correct register for a
consensus-tier number. What changed is truth-preservation around it:
the morning-gap/under-floor notes now read canonical weight inputs
(§12) and their windows still exclude today (M9's law, untouched).

## 20. What did Method adversarial collisions expose?

**No defect — and the determinism is now pinned where the brief
demanded it.** `Pass55MethodCollisionTests` (7, green on first run —
an honest finding that the engine already answers every collision):
salty + menses on one morning → salt (the more specific fact), with
BOTH triggers active underneath · every salty note on cooldown → the
cycle explanation speaks instead of silence · q10d waning + adequacy
net → the net wins; without it, day 9 of 10 IS the teaching · queasy +
constipated → fluids outrank fiber · ended medication + a jump →
the frightening morning is answered first, the support note fires
tomorrow · interval waning + salty bump → the scale question wins ·
the kitchen sink (7 simultaneous triggers) → exactly one note, the
head of the priority-filtered list. The one-note-per-day re-render,
cooldown fall-through and suppression paths all behaved.

## 21. What did chat-context auditing expose?

The envelope is provenance-disciplined and **rebuilt on every send**
(no stale context by construction): user-stated facts carry
attribution (`treatment_months_basis` = "her own account"), computed
numbers carry basis notes (`kcal_basis`, `kcal_note`), withheld facts
arrive as in-band absence notes (`no_trend_note`, `no_goal_note`,
`kcal_missing_note`) — ambiguity is never disguised as fact. The
brief's question list is answerable or honestly refusable: "when was
my last shot" (read_dose_history), "what do I usually eat"
(read_food_week's `repeated_dishes` with sparse gating), "have I been
drinking enough" (the record holds no fluid quantity and nothing
claims one), "should I increase my dose" (the EF prompt routes to the
prescriber; the ended-medication chatSeed forbids the lane — the
prompt half is deploy-gated and stated as such). One addition: the
same-day two-rows case now ships `latest_note` (§12). Account switch:
the envelope's stores are all swept or per-uid (§30's sweeps close
the last gaps).

## 22. What did Becoming auditing expose?

Walked seeded on SE: the body card and the weight tile speak the same
number and the same band; scope pills, medication section, and the
"not enough to read yet" honesty header render clean at default and
AX5. The one arithmetic defect (window-truncated fold) is fixed —
§12. No new surfaces, no metric added; the redundancy pass found the
BODY card and WEIGHT tile intentionally two altitudes of one number
(a summary and its instrument), not duplication worth deleting.

## 23. Does Body Snap earn its place?

**KEEP — walked as a stranger, it answers every §9 question from its
own screen**: what it records ("an ink line of your waist… the
mirror, kept honestly"), privacy ("your scans live on this iPhone.
nowhere else, unless you turn on backup"), honesty ("no number is
ever read from a photo. a scan is evidence, not a measurement"),
control ("delete any scan, or all of them, anytime"), capture ("stand
so your waist fills the window. hold still. it takes itself"). It
promises evidence, not precision, and delivers exactly that. No BF%
from photos, ever — unchanged and re-affirmed.

## 24. What is the waist-trend founder recommendation?

**Defer — do not build for this release.** (A) B2C value: modest — a
manual waist number adds a second body series to maintain, against
the simplicity thesis; the silhouette already answers "is my shape
changing" without a number to type. (B) Clinician value: real (WC is
a legitimate marker) but the packet's current consumers have not
asked for it. (C) Evidence: WC is clinically validated; nothing about
*app-recorded* waist trends improving outcomes. (D) Input burden: a
tape measurement is the highest-friction record in the product — the
opposite of "recorded in seconds." (E) Privacy: fine (a number, not a
photo). (F) Server: rides `ObservationKind`, where the live CHECK
constraint means client-first shipping 400s on sync — the §31
ordering hazard; it needs a migration FIRST. (G) Material improvement
today: no. If built later: migration → client, one ledger row + one
packet line, never a Home surface.

## 25. What did notification day-simulation expose?

Code-level day tables over the post-p54 system (every scheduler read):
ordinary week-2 day = 1 consented morning anchor + at most 1 budgeted
evening push (cancelled the moment a plate lands) · dose day adds the
consented medication reminder · weekly-read day adds the consented
knock · a silent day 3+ ends the ladder ("begin again" rung, then the
winback owns the gap under its own budget). **Worst realistic day = 3
arrivals, exactly one uninvited.** Master toggle sweeps
`allNonMedicationIds` + retired ids; every schedule site guards OS
authorization; re-grant invalidates the refresh guard; and the
timezone case is genuinely handled — `HomeView.refresh()` runs on
foreground activation AND on `NSCalendarDayChanged`, which iOS posts
on timezone changes, so `MedicationReminders.refresh` re-arms (the
p53 claim, verified to its mechanism this time). One correction to
p53's phrasing: there is no time-change *observer*; the re-arm rides
the day-changed notification + foreground, which covers every case a
running-or-foregrounded app can cover. The new dizzy note adds NO
notification (the Method never pushes — p54's law, untouched).

## 26. What did accessibility testing expose?

Sampled at AX5 (`simctl ui content_size accessibility-extra-extra-
extra-large`) on the SE — the smallest phone at the largest type:
Home wraps word-whole (greeting, dose standing, protein instrument),
the regimen sheet stacks label-over-value with no mid-word breaks,
Becoming's cards scale and scroll. The pass-52/54 laws (wraps-or-
scales, min-height ScrollView, ≥accessibility1 stacking) held on
every surface sampled; no new violation found. The v8 projection
figure's unit fix (§12) is also an AX fix — the spoken sentence and
the drawn label now agree for kg users.

## 27. What did frame-level inspection expose?

The film pass walked Home, Becoming, the regimen sheet and Body Snap
at default + AX5 on SE with contact-sheet inspection of the stills;
no ghosting, no clipped text, no background mismatch, no stale
content. The film harness's own trap fired once more in new clothes —
a deep-link `openurl` raised the SpringBoard "Open in Jeni?" dialog
that then sat over two launches — caught on the second frame and
routed around via the in-app `--uitest-start-tab` door (the §12.1
lesson: always inspect the frame, never trust the launch). The
`Executed 0 tests` trap also fired once (the journey walker addressed
by FILE name — that file holds nine classes) and was caught by the
zero count; re-addressed by class, it ran and passed. Entrance
animations were not re-filmed at 60fps this pass: no motion law
changed and the p53/p54 films stand — stated, not claimed.

## 28. What did network/interruption testing expose?

Fixed: the offline-delete hole (§11 — the sweep now runs every
launch) and the words door's lost-text/empty-plate paths (§6). Verified
by architecture + standing tests: the JSONL write precedes the cloud
push (kill-during-write loses nothing local; the launch reconcile
pushes it), `pendingUpsert` survives kills, the §45 structural
reporter names refusals. **NOT RUN this pass: a live offline-at-launch
walk** (p46's PASS stands for the shipped launch path, which this
pass did not modify).

## 29. What did identity/account/deletion testing expose?

The live handoff/deletion machinery was re-proven at the wire this
pass only where it intersects the new columns (§5: RLS refusal,
deletion cascade, mover semantics — all green). The client-side
sweeps are §30's story. The p39–51 suites (handoff contracts,
deletion contracts, reattribution) all run green in the final suite —
the standing laws are intact.

## 30. What user-scoped state was found outside existing sweeps?

**The recurring defect class, found again — the fourth harvest.**
RED 27 failures → GREEN (`red_sweep.xcresult` retained):

- **P1 — `WeeklyReviews/reviews.jsonl`**: her re-signing decisions
  (decision, stamp line, reason line, week name) survived "delete my
  account" on disk and in every backup — the `move.manual.v1` shape,
  one level up in the filesystem where a UserDefaults grep cannot
  see it. Now purged per-user at deletion (scoped rewrite, other
  users' rows survive) + the process-lifetime cache (the
  `CareProtocolStore.current` bug class, second instance) resets at
  sign-out. A **container-walk assertion** now pins it: after the
  purge, no file under Application Support may contain the deleted
  uid — the mechanical defense that catches every future JSONL store.
- **P1 — the notification brain's `brain.*` family**: A's 7-day
  budget stamps, ignore streaks and silence flags crossed accounts —
  B's first-week interruptions were rationed by A's spent budget, and
  a category A ignored six times arrived MUTED for B. Swept by
  prefix.
- **P2 — `analytics.cohortIdentity.fingerprint`**: a plaintext
  medication-status string that outlived deletion — and whose
  dedup short-circuit silently kept B's cohort properties from ever
  reaching analytics. Swept.
- Plus: `coach_notes_v1` (shelved coach notes about her weeks),
  `visitq.removed.*` (packet-question tombstones), the notification
  opt-outs + her chosen hour, the rating one-shots, the same-day
  evening/letter gates, the missed breathwork sibling, the per-week
  weight-milestone one-shots, `coach_intro_shown_at`,
  `cohortIntakeBackfillV1Done`, `onb_v8_last_answer`,
  `postPurchase.firstRunPending`, the walk-analytics day stamps —
  and **`FirstPlateState.reset()` finally has a caller** (its comment
  claimed the sweep called it; zero callers — the FOURTH false
  comment on a deletion path this line of work has found; the comment
  is true now). Also fixed while there: the first-plate cuisine hint
  read a key written nowhere (`onb_food_cuisines` → the live
  `onboardingCuisinePreference`).

**Named, not swept** (deliberate): `weightUnit`/`heightUnit` stay
device-level (the sweep's own recorded trade); flagged that the
clinical packet stamps `displayUnit` from it — a founder call whether
the packet should re-derive per identity.

## 31. What legacy code/assets were deleted?

**The v4.5 `OnboardingView` is GONE.** Unreachability proven first:
both mounts sat inside `#if DEBUG` behind `--onboarding-v4` /
`--debug-medication`; the file's twelve top-level symbols were
swept for external users and exactly two were live — `OnboardingData`
(the assembled consult record the shipping v8 flow hands to
`handleOnboardingComplete`) and `PressFeedbackStyle` (the paywall/
auth/v5 press wrapper) — extracted verbatim to
`OnboardingShared.swift` (58 lines). Deleted: the 9,645-line file,
both DEBUG mounts, the pbxproj reference, and **33 orphaned
imagesets — the 17 only it referenced, plus `bodytype-0…5` and
`social-1…10`, which orphaned the moment it died** (pass 48 kept
them because the file referenced them). Measured: **source −9,645
lines (+58 extracted); asset catalog 58,004 → 21,560 KB (−35.6 MB)**;
every remaining `onb-*` literal in the tree still resolves (v5's
DEBUG flow keeps its own). Debug build + full suite green after.
Also deleted: the three dead fast-fold helpers (§12). **Named, not
deleted**: `RapidLossTripwire`, `WeightOutcomeInstrumentation`,
`Signals.BodyLine`, `CoachSummary.seasonNote`,
`WeightAnalytics.subtitle` — dead interpretive bodies that carry live
test classes; removing them is churn without customer value on
release eve (the pass-54 stance, re-affirmed).

## 32. What was deliberately NOT built?

Waist trend (§24) · a water tracker / fluid volume (§16) · HK+manual
movement dedup heuristics (§13) · a usuals chat tool (an EF-gated
tool name; `repeated_dishes` already answers) · a compounded-units
dose calculator (real-harm vector; `dose_label` free text already
records "35 units" as HER stated words — the record, never the
arithmetic) · food export · a chain-restaurant database ·
micronutrient persistence/interpretation · the §16 prohibited list
in its entirety.

## 33. What fresh competitor complaints still matter?

The targeted review scan's verdict: **no repeated high-severity
core-job complaint remains unsolved.** The market's five loudest 2026
complaints — confidently-wrong AI estimates (a July 2026 study:
photo apps understate ~250–345 kcal/meal, worst on high-fat), the
GLP-1 half-portion problem, subscription distrust (Cal AI was pulled
from the App Store in April 2026 over deceptive billing), barcode
database gaps, data loss on update/phone change — map onto Jeni's
shipped correction/memory/provenance/pay-upfront/tombstone answers.
Two cheap follow-ups noted for the founder, not built: a one-off QA
probe of the vision EF on 3–4 high-fat plates (measuring the
documented fat-underestimation bias), and the barcode-miss path
(verified in code this pass: unknown code exits in-surface to the
label door with "the label works every time" — graceful, filmed in
p53).

## 34. What competitor complaints did you deliberately refuse to chase?

The PK medication-level curve (Shotsy's signature; scientifically
dishonest — the v24 refusal stands, now with p54's evidence tiers
behind it) · pen supply/refill tracking (feature-wish, shortage-era
salience faded) · community feeds, streaks, gamification · a deeper
proprietary food database (the correction flywheel is the moat, not
DB breadth).

## 35. Where can every consequential customer fact be viewed / corrected / deleted?

Food: THE BOOK (view) · plate sheet fix/relog/redate/remove ·
corrections render in YOUR NUMBERS. Weight: the weigh-in ledger, any
row, any day. Doses: the dose ledger; any past slot; backfill.
Regimen: the sheet (rhythm/dose/tenure editable; care-team rows
refuse). Symptoms (now including lightheaded): the logger, 14 days
back, clear that clears. Movement: MoveSheet's recorded list +
remove. Memory: settings › what jeni remembers, per-row forget.
Method: the told-list (settings), swept at sign-out. Weekly reviews:
Becoming; **and now purged at deletion** (§30). Cycle: her recorded
starts; stand-downs govern reads. Body scans: the scan record, delete
any or all. The §18 audit found **no data type that affects coaching
without an inspection surface**.

## 36. What still requires another app?

The honest residue, unchanged from p53 and re-affirmed: a period
tracker for *prediction* (Jeni only reads recorded starts, by law) ·
a lifting programmer (sets/reps out of scope) · pre-purchase
micronutrient database browsing · lab results/clinical documents ·
travel-week dose planning. New honest entries from this pass's
audits: **bulk export of her record** (nothing in-app exports; a
founder-roadmap item), and chain-restaurant lookup (the words door +
model estimate is the product's answer; a database is not).

## 37. What still requires a physical device?

The standing list, none of it new: TestFlight install + one reviewer
walk on hardware · StoreKit purchase/restore/cancel against the real
sandbox · real-HealthKit Move/weight import behavior on a device with
a watch · the notification-permission dance on real iOS · the v8
consult's camera/photo permission sheets under real privacy prompts.
Nothing this pass changed touches device-only surfaces beyond what
the sim proved (the projection figure, dose copy and packet lines all
render in-sim).

## 38. What still requires founder action?

1. **The EF envelope block deploy** (season/band_zone/method_now —
   client half live, prompt half gated) — unchanged.
2. **The waist-trend decision** (§24 recommends defer).
3. **The archive-time bump 33 → 34** at the next archive.
4. The two cheap §33 follow-ups if desired (high-fat EF probe;
   nothing blocks release on them).
5. The `displayUnit`-in-packet question (§30, one line, judgement).
6. The standing §37 device checklist at TestFlight time.

## 39. What migrations/deployments occurred?

**One migration APPLIED to production**: `20260818090000_v25_p53_
regimen_interval_tenure.sql` (pass 53's, under the brief's explicit
§0 authorization, after the hostile audit; §3–§5). **No Edge Function
deploys, no storage changes, no other SQL.**

## 40. What production mutations occurred?

The migration DDL (5 additive columns + comments; zero DML at apply
time). The 13/13 round-trip probe created **two throwaway anonymous
accounts and deleted both through the shipped RPC** — net zero rows,
net zero accounts. The reviewer journey's erased QA sim minted one
anonymous bootstrap account on its walk (the §45-documented
mechanism, observed again; no credential exists for it; left per the
standing precedent). No other production reads or writes.

## 41. What are the exact before/RED/after test counts?

- **Before (re-measured)**: app 1483/0/2 (1485) · PlankFood 242 ·
  PlankSync 29.
- **RED, artifacts retained**: regimen truth 9 failures of 12
  (`red_regimen.xcresult`; the 3 passes were the weekly controls) ·
  food field-carry 5 failures of 6 (`red_food_carry.xcresult`; the
  pass was the single-food control) · sweep 27 failures across 3
  (`red_sweep.xcresult`) · the dizzy addition went RED through the
  catalog's own four tripwires (priority pin, tier table,
  fingerprint, analytics vocabulary — each fired on the unpinned
  note, which is the machinery working) · the Method collision suite
  was **green on first run** — an honest characterization result,
  not a manufactured RED: the engine already answered every
  collision, and the suite pins it.
- **After, all from xcresult**: **app 1509 passed · 0 failed · 2
  skipped (1511 total; +26 reconciled EXACTLY: +7 collisions, +12
  regimen truth, +3 sweep, +4 dizzy)** · **PlankFood 249/249 (+7 =
  6 field-carry + 1 printed-truth restamp)** · **PlankSync 29/29** ·
  **DayKeyVocabularyTests 3/3 under `-testLanguage ar -testRegion
  SA`** · **Release configuration BUILD SUCCEEDED, 0 errors** (see
  the verdict block) · the door-free reviewer journey walked solo on
  an erased sim (§45).
- The cwd trap and the `Executed 0 tests` trap each fired once and
  were each caught (§27); every count above was re-read from an
  xcresult bundle or an explicit `Executed N` line, never a piped
  tail.

## 42. What is P0 remaining?

**0.** Every P0-class finding this pass surfaced (five regimen truth
defects, three food field-drops, the whisper's raw-number band, the
deletion-sweep gate, the reviews-survive-deletion residue, the
cross-account notification ledger) is fixed RED→GREEN.

## 43. What is P1 remaining?

**0 new.** Named-not-fixed items are P2/P3 with owners: HK+manual
movement dedup (behavioral) · the `displayUnit` packet stamp (one
founder line) · the dead interpretive bodies (§31) · analytics
delete-retraction for movement · the words-door offline draft is
kept in-field but not queued (the honest copy names it) · zero-kcal
foods can't become usuals (the `kcal > 0` rank gate; black coffee —
small, named) · the redated-plate hour policy (midnight dinners keep
their clock) · standing p51 §18 server-authority items, inherited.

## 44. What would you most regret shipping to 10,000 customers tomorrow?

Before this pass: the answer was §6/§7 — a q10d user being told her
week starts on a phantom dose day while redating a plate silently
erased her corrections. Those are closed. The honest answer NOW: **the
food photos' single-copy story** — the bucket is founder-gated (for
the right deletion-ordering reasons), and until it ships her photos'
durability rests on the device backup this pass just turned back on
(they were excluded from backup on the strength of a cloud mirror
that has never existed). It is mitigated, not solved, and it is the
first thing the founder-gated storage work should close after
release.

## 45. Would you personally submit this exact build?

**YES**, after the founder's device checklist (§37). The door-free
reviewer journey — erased sim, real consult, wall, every exit,
relaunch — **passed solo** on this exact tree; the full suite is
green; Release builds clean; the record's promises (correct once,
remembered, one truth per fact, deletion means deletion) now hold
under the adversarial histories this brief demanded.

## 46. Is another autonomous product pass justified before real-user evidence?

**NO.** The convergence criteria are met: no P0, no release-blocking
P1, the journeys are coherent, records survive correction/relaunch/
sync, the surfaces agree, the smallest phone works at the largest
type, and what remains requires hardware, founder credentials, or
real users. The next information this product needs is a paying
stranger's.

---

## The closing test, answered as the customer

Record in seconds — words, photo, barcode, again: yes, and the words
door now refuses to file nothing. Fix her when she's wrong — one tap,
and the fix survives redating, sign-in, refine and re-scan: yes,
pinned. All parts agree — one weight fold, one loss rate, one plateau
count, one cadence vocabulary: yes, converged this pass. Knows when
not to speak — silence is the engine's default return value and the
quiet days are pinned quiet: yes. GLP-1 without making the medication
her identity — the rhythm is HER stated rhythm in every sentence now,
and "less" is never "better": yes. Trust the record — deletion means
deletion down to the last JSONL, and her decisions no longer outlive
her account: yes. Would I pay? The moat was never the estimate — it
is that the app is never confidently wrong about HER OWN record. That
is what this pass spent itself on.

---

## VERDICT

PASS 53 MIGRATION: **APPLIED** (hostile-audited first; sha256 `31681bcf…`; recorded in schema_migrations)
LIVE ROUND-TRIP: **PASS** — 13/13 as a real client principal; all five fields verbatim; replay idempotent; net-zero production rows
FOOD RECORD: **PASS** — field-drop family closed at the persister (one `with()` re-init); empty-plate + double-tap guards
FOOD CORRECTIONS: **PASS** — survive redate, both merges, refine; printed-truth restamp on spoken fixes
FOOD USUALS: **PASS** — subtractive qualifier law shipped; single-food loop pinned
BARCODE: **PASS** — verify-once intact; "use the package" escape hatch finally renders; unknown-code exits to the label door
WEIGHT: **PASS** — 52 consumers swept; whisper/Method/tile/importer/care-count converged on the canonical fold; remaining semantics named, not silent
APPLE HEALTH: **PASS** — earliest-of-day import; tombstones re-proven; deletion sweep ungated from hydrate
MOVEMENT: **PASS** — same-launch Home refresh; clinician provenance split; dedup NAMED
GLP-1 REGIMEN: **PASS** — no weekly grammar reaches interval/split users on any surface; `isDoseDay` events-required by signature
GLP-1 HISTORY: **PASS** — re-anchored chains decide the standing, the mark chokepoint, and the pattern engine's final cycle
GLP-1 NUTRITION: **PASS** — evidence-tiered; carb-substitution folklore refused; count-up grammar unchanged
PROTEIN: **PASS** — floor matches both 2025 consensus documents; no new feature; adequacy net primary
HYDRATION: **SMALLEST TRUE VERSION** — no tracker, no volume, ever; one label-tier routing note (lightheaded + GI-loss → prescriber) + the dizzy symptom word
METHOD: **PASS** — 21 notes; 7 collision pins green; tripwires (priority/tier/fingerprint/vocabulary) all fired and re-pinned; silence still the default
CHAT CONTEXT: **PASS** — per-send assembly; provenance classes; absence notes; same-day weight note added
BECOMING: **PASS** — one number, both cards; fold un-truncated; no surface added
BODY SNAP: **KEEP** — honest promise, walked as a stranger; waist trend: DEFER (memo §24)
NOTIFICATIONS: **PASS** — worst realistic day 3 arrivals/1 uninvited; brain ledger now per-identity; timezone re-arm verified to mechanism
ACCOUNT ISOLATION: **PASS** — brain.*/fingerprint/reviews-cache leaks closed; RLS re-proven live on the new columns
ACCOUNT DELETION: **PASS** — reviews.jsonl purged; container-walk assertion pins the class; live RPC re-proven
OFFLINE / RETRY: **PASS (code-proven)** — sweep every launch; JSONL-first writes; offline-at-launch walk NOT RUN this pass (p46's stands)
ACCESSIBILITY: **PASS (sampled)** — SE × AX5 across Home/Becoming/regimen/Body Snap; wraps-or-scales laws hold
FRAME-LEVEL POLISH: **PASS (stills)** — no clipping/ghosting/mismatch; 60fps entrance films not re-taken (no motion law changed; p53/p54 films stand)
LEGACY CLEANUP: **DONE** — v4.5 OnboardingView deleted (−9,645 lines; catalog −35.6 MB; 33 imagesets; live types extracted)
APP TESTS: **1509 passed · 0 failed · 2 skipped (1511; +26 reconciled exactly)**
PLANKFOOD: **249/249 (+7)**
PLANKSYNC: **29/29** · DayKey 3/3 under ar_SA
RELEASE BUILD: **BUILD SUCCEEDED, 0 errors**
PRODUCTION MUTATIONS: **the authorized migration DDL + 2 probe accounts created and deleted (net zero) + 1 anonymous bootstrap on the erased QA sim (the §45 mechanism, documented)**
MIGRATIONS APPLIED: **20260818090000** (the only one; none written this pass)
P0 REMAINING: **0**
P1 REMAINING: **0 new** (named P2/P3 in §43)
PHYSICAL DEVICE REQUIRED: TestFlight walk · StoreKit sandbox · real-HealthKit import · notification permission dance (§37)
FOUNDER ACTIONS: EF envelope deploy · waist decision (defer recommended) · archive bump 33→34 · §38's small list
SAFE TO BUMP TO 34: **YES (at archive time, per the convention)**
SAFE TO ARCHIVE: **YES**
SAFE TO UPLOAD: **YES**
SAFE TO SUBMIT: **YES, after the §37 device checklist**
