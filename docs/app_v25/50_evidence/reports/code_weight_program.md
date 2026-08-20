# AGENT EXTRACT — weight + program-day audit (a81d4eee)

## RANKED FINDINGS (new)
1. **P1 — typed weigh-in over a same-day Health row silently reverted**: WeightLogWriter.persist updates today's row IN PLACE without relabeling source (ChatToolRouter:272-276); healthkit row stays "healthkit" → BodyMassImportService .update overwrites her typed number next launch/observer (>0.01kg). "A row she typed always wins its day" enforced only on the CORRECTION path (sourceAfterCorrection→"manual"), not the daily chokepoint. (= the Withings resurrection class users punish hardest.)
2. **P1 — program day +1 on reinstall/new device/handoff for non-UTC users**: start_date rendered UTC date-only (SyncService:1750, 2567-72), re-parsed UTC midnight (:1859), re-anchored LOCAL startOfDay (ProgramScheduleCalculator:85) → two devices can sit on day 11 and day 12 same morning; re-signing windows shift. Merge protects existing rows but not fresh hydrates.
3. **P2 — graduation dead end**: ChapterCompleteView has NO mount site; phase="completed" has ZERO writers vs THREE doc contracts; plan stays active past goalDate forever; programDay caps at totalDays+1 → Home dateline "day 120 of 119" indefinitely (HomeView:645 no post-goal branch).
4. **P2 — VisitPacket weight includes the onboarding self-report** (all 8 consumer reads exclude it) AND uses latest-of-day while WeightWeekReadEngine enforces earliest-of-day — two "day's weigh-in" numbers on two surfaces.
5. **P3 — timezone travel**: weightday tombstones + import day-buckets both local-tz at call time → cleared day can resurrect; one physical weigh-in can duplicate across a tz change. programDay recomputed per render in current tz (fly west across midnight → day rolls BACKWARD, self-consistent, transient).
6. Nits: stale "thirty-day" comments (code = 90d); importDecision's unused calendar param; **TodayModuleHost:287 ruler seed `?? 65` kg hardcoded fallback bypasses onboarding-weight rung (returning payer pre-hydrate opens ruler at 143 lb)**; unsorted existingByDay → manual-wins order-dependent when a day holds 2 rows; EngagementDayCalculator stale "single source of truth" header; 3 different kg plausibility ranges; TWO EMA ENGINES over two row sets (WeightTrendChart α=2/8 incl. onboarding rows vs WeightWeekReadEngine τ9.5d excl. onboarding) → Becoming's drawn line and jeni's spoken direction can disagree at the margin.

## PART A ESSENTIALS
Writers: persist (update-today-or-insert, callers: today ritual, plan-numbers sheet=NEW row, chat log_weight w/ 25-350 bounds) · onboarding seed · HK import (90d, latest-per-day, 20-400, per-day rule manual-skip/hk-update/insert-unless-day-tombstone, fresh uuid) · hydrate insert-only (null source → "manual") · correct/remove any day (remove writes row-id + day tombstones BEFORE network).
Readers: ladder = TargetsService.resolvedWeightKg (latest ?? onboarding ?? plan) for ALL arithmetic + coach + PlanSummary ✓. Raw-latest display layer: BodyStateService snapshot (incl. onboarding rows). Source-filter inconsistent: 8 sites exclude onboarding, 8 don't (incl. VisitPacket, NotificationOrchestrator, InsightEngine).
Units: kg storage; ONE display authority `weightUnit` (onb_v5_unit_lb mirrored at pick; survives sign-out as device-level). Unit-error defenses: engine ×2.2 skip, 3 bounds ranges.
Same-day dupes: single device impossible; two devices possible (ledger honestly shows both w/ times; VisitPacket/WeeklyReview latest-of-day vs engine earliest-of-day).

## PART B — PROGRAM DAY
One user-facing formula: plan.startDate → ProgramScheduleCalculator (days-between +1, clamp [1, totalDays+1], LOCAL gregorian; advances on inactive days). Week = ((day-1)/7)+1. All surfaces derive from it ✓ (activePlan selection ≡ reconcile heal, earliest startDate).
Deliberate second vocabularies, scoped: EngagementDayCalculator (legacy, stale SoT header, stamps DayProgressRecord.programDay w/ different semantics — trap), WeeklyReadAnchor ladder, CyclePosition 1..7, shown-up count. RepEngine canonicalDay: DEAD (zero call sites).

## PART C — GLP-1 START: NOT A RECORDED FACT
No medication-start-date field anywhere; RegimenPlanRecord.startedAt = "when Jeni learned this" (stamped now; inherited only for schedule_changed). Categorical only: onboarding_glp1_phase (just_started/few_months/established). No backfill, no editor, no chat tool, no server column. Months-into-treatment persona reads as day-one; no "since March" narrative, no tenure line for clinician.

## PART D — RESTART
startProgram = unconditional archive("abandoned")+mint — NO phase param; reachable reset closed at TodayHost @Query gate. Graduation designed (Maintenance30/Recomp60/NewGoal75/SoftPause) but UNMOUNTED. At-goal WORKS: EnergyBasis .maintenance by arrival, "· holding", goal/pace edits move finish line only (same id/startDate/history).
