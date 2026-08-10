# E1 THE SPINE — evidence (the loop's record)

2026-08-10 · what was PROVEN, how, and what remains. Architecture +
decisions live in `05_E1_SPINE.md`. Media under the session
scratchpad `read/` (frames are session-ephemeral by standing law;
the observations here are the durable record).

## 1 · THE CRITICAL END-TO-END LOOP (filmed + relaunch-proven)

The sequence the era demanded, executed on the QA sim (fresh build,
seeded history):

1. **History** — seeded program (day 12) + food week (7 days logged,
   protein 5/7) + weekly injectable regimen + a believable 28-day
   step history (60th percentile ≈ 6,200).
2. **The read arrives** — dose-day anchor ("after the dose"), title
   "your dose week, read.", one-clause hero, signals band (6,757
   steps a day vs 5,300 your usual · 7 days logged · 5 days protein
   floor), floor-gated observations, teaching line, ONE offer.
3. **The clinical rule leads honestly** — with protein cleared 5/7,
   the v4 protein-firm offer outranked the step recalc (filmed);
   with the QA cooldown door, the step-goal offer surfaced: "a
   walking goal: 6,200 a day — fit to your own last two weeks, not a
   slogan number."
4. **Consent on film** — `--uitest-walk-read` drove "let's try it";
   the SIGNED stamp landed ("your walking goal: 6,200 a day" + rose
   dot) with the proposal crossfading beneath (frames f_010-f_018,
   loop_accept.mp4).
5. **Program memory changed** — a `program_facts` row (stepGoal,
   authority=recommended, acceptedAt set, source=weekly_read) + a
   deterministic `weekly_reads` decision row.
6. **Today changed** — relaunch (NO read doors): TODAY reads
   "0 of 3"; the third row is THE WALKING ACTION — "6,200 steps ·
   2,100 steps left · about 20 minutes" (the founder's exact
   concept, from her own consented goal). The greeting followed the
   forced hour ("afternoon") — the composition is coherent.
7. **Terminate → relaunch again** — state and provenance survive;
   the signed window stays silent (no re-present); Becoming carries
   the journey stamp.
8. **Notification policy follows** — the read knock is brain-gated
   (weeklyRead lane), the dose-anchored variant schedules the
   morning after dose day; support sends ride the hard budget.
9. **Telemetry records the lifecycle** — weekly_read_shown →
   weekly_read_decision {anchor, offer, decision, fact_written} →
   program_fact_changed {kind, authority, source}; notif_candidate /
   notif_delivered / notif_silenced at the brain; all payloads
   categorical (hygiene law audited by eye at every call site — no
   free text, no values-with-units, no medication names).

## 2 · ADVERSARIAL LOOPS

- **NO DATA**: a truly virgin user (fresh container, broken-door
  battery run) lands in ONBOARDING — no read, no fake intelligence
  (filmed: welcome screen). Engine pin: a no-anchor no-program user
  resolves nothing (`testNothingDueWithNoAnchorsAndNoProgram`).
- **SPARSE**: <3 elapsed days = no read (the v4 honesty floor,
  unit-pinned); a sparse week composes the quiet hero + the
  logging-lighten offer (`testQuietWeekReadsHonestly`,
  `testLoggingLightenOnSparseWeek`).
- **DECLINE**: filmed — auto-decline door; cover exits quietly;
  Becoming clean beneath; window signed-silent; kind cools down 14
  days (`testDeclinedKindsWithinCooldown`, `testDeclinedKindCoolsDown`).
- **USER OVERRIDE**: preferred facts out-rank accepted
  recommendations (`testPreferredBeatsAcceptedRecommendation`);
  settings-pace edits write preferred (store law).
- **CLINICIAN OVERRIDE**: prescribed rows out-render everything;
  iOS cannot author them (chokepoint + RLS `authority <>
  'prescribed'`); ending a prescription RESUMES her preference
  (`testPrescriptionOutRendersThenEndResumesPreferred`) — the
  no-silent-overwrite law, structural.
- **NON-GLP-1 / DAILY MEDICATION**: the anchor ladder passes nil for
  any non-weekly regimen — enrollment rhythm, zero injection
  vocabulary (`testDailyMedicationUserFallsToEnrollment`,
  `testNonMedicationUserFallsToEnrollment`). Film caveat: the sim
  keychain survives reinstall, so the daily-med FILM inherited the
  account's cloud regimen (see §4 limitations); the engine law is
  unit-pinned.
- **OFFLINE / SYNC**: local-first by construction — both new tables
  defer gracefully (pendingUpsert outbox + retry sweep families;
  migrations unapplied = the founder-gate path exercised ALL
  session); the accidental keychain-restore run PROVED hydrate
  rebuilds the spine's inputs from the cloud on a clean install.
  Authority split on hydrate: prescribed rows server-authoritative,
  everything else client-owned (code-mirrors the S4 regimen law).
- **ACCESSIBILITY**: XXXL capture of the read (signals wrap, nothing
  clips); Reduce Motion path settles the cascade instantly
  (existing `reduceMotion` branch preserved).
- **NOTIFICATION COLLISIONS / STALE**: same-id replaces are free
  (`testSameIdReplaceIsFree`); budget vetoes excess
  (`testBudgetAdmitsUnderCapAndVetoesOver`); category auto-silence +
  engagement reset (`testCategoryAutoSilencesAfterIgnoreStreak`,
  `testEngagementResetsTheIgnoreStreak`); medication never silences,
  never budgets, never holds out (three pins).
- **AUTHORITY CONFLICTS**: competing chains coexist without data
  loss (`testPreferredAndAcceptedRecommendationChainsCoexist`);
  clamps are authority-aware; proteinAdjust rides the safety band
  for EVERY authority.

## 3 · FRAME-CAUGHT FIXES (the loop working)

1. Hero line truncated mid-word (3-clause hero) → one-clause hero
   law + test.
2. The protein fact told three times (signal + observation + offer
   reason) → observation yields to a protein offer + test.
3. "protein floor met" label wrap → "protein floor".
4. The signed stamp's "→" ligated as a slashed arrow in
   JeniHeroSerif → colon grammar.
5. The signals band's width-only hairlines expanded to the proposed
   height and dragged the band down the page → `.fixedSize`.
6. Steps auto-complete fired on the baked tier goal → the RESOLVED
   goal (a consented 5,150 would have completed at 7,500).

## 4 · KNOWN LIMITATIONS + REAL-DEVICE GATES

- **Founder gates**: apply `20260810090000_v25_e1_program_spine.sql`
  (stacked after the still-open v24 migration; everything defers
  local-first until then) · device walk (the read in hand, the knock
  on a real lock screen, a real timezone crossing) · the 12 teaching
  lines + offer copy voice pass.
- **QA determinism**: the sim keychain survives reinstall — a
  "fresh" container keychain-restores the account and hydrates cloud
  data; true no-data walks need `simctl erase` or a signed-out run.
  The zsh unquoted-`$VAR` launch-arg trap re-bitten and re-recorded.
- **Ignore-streak capture is approximate**: engagement records on
  tap; ignores accrue via brain vetoes/replaces, not via delivered-
  but-unread detection (needs a notification service extension —
  deliberately out of E1).
- **Walker leg debt**: the read has film doors + engine pins; a
  dedicated XCUI leg (tap-driven accept/decline on an erased sim)
  is named debt for the next era's leg pass.
- **The v4 JSONL journey ledger** keeps receiving enrollment-window
  records for continuity; retirement is E-next debt.
- Steps sourced phone-only; carry-habit undercount self-corrects via
  percentile-of-own-days; never compared to watch-wearers.

## 5 · TEST COUNTS

- Full unit suite at era close: **see final run in the shipping
  report** (started 587 → grew through 623 / 646 / 695 / 709 with
  zero regressions at every gate).
- New E1 suites: ProgramFacts 20 · ProgramFactStore 16 ·
  AdaptiveStepsEngine 12 · CarePlanEngine +11 walk laws ·
  WeeklyReadAnchor 12 · WeeklyReadOffers 12 · WeeklyReadStore 6 ·
  WeeklyReadComposer 12 · NotificationBrain 12.
- Every engine RED→GREEN (behavior failures observed before
  implementation; two suite-internal contradictions caught at RED
  and resolved with recorded reasoning).
