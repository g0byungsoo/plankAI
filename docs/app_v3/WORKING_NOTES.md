# app v3 — working notes (session scratch, keep until superseded)

Date: 2026-07-05. These are raw audit observations feeding
00_THESIS / 01_FEATURE_VERDICTS / 02_DESIGN_LANGUAGE. Not a spec.

## My own eyes on the current build (iPhone 16e sim, seeded day 12)

Today tab:
- jeni's brief line is the strongest element on the screen (real
  voice, real data). Everything below it competes with it.
- The day is FOUR PARALLEL PASTEL CARDS with empty circle indicators
  on the right. The circles read as checkboxes; the pastel sticker
  thumbs (peach/poodle/bow/shoe) read as a toolbox. The homework
  metaphor is literally rendered.
- Future days in the strip wear PADLOCK glyphs. Locks are a
  gamification dark-pattern glyph; against soft-luxury.
- JKCoachMark ("tap a row to begin it...") CLIPS mid-sentence at the
  fold under the state band (seen at default scroll on 16e).
- Scrolled state: "TODAY SO FAR" tracked caption collides with the
  status-bar clock (no safe-area treatment when masthead scrolls off).

Jeni tab:
- Opens as a mostly-empty room: masthead + the SAME brief line Today
  just showed + 3 chips + composer. Feels like a chatbot shell, not
  a coach mid-thought about her. The letter register only appears
  once a conversation exists.

Becoming tab:
- Coherent insight layer. BUT the giant raw "163.6 lb" numeral is
  the visual hero (against trend>number doctrine), and the same
  −2.2 lb fact renders three times in one viewport (headline, badge,
  receipt row).

Evening close:
- Works. Plates without photos render as bare letter tiles ("g",
  "c") — fallback should be designed, not typographic residue.

## Glyph inconsistencies spotted
- Safety check-in intro uses ♡ U+2661 (OnboardingComponents.swift:1121).
- v5 her-file + projection walker shots show RED EMOJI hearts (❤️)
  — the U+FE0E fix didn't reach `OV5HerFile`/projection card? Verify
  in code; sweep all hearts to ♥ + FE0E.

## Structural seams (from code-reality agent, load-bearing)
1. stats.shown_up_count ONLY counts workouts (RetentionNotifications
   :939 called from saveRoutineSession). Becoming wins, briefs, wall,
   migration all read it. Any de-emphasis of workouts must first
   redefine "showing up" (lesson/snap/breath/weigh must count).
2. Dead beat cases .plank/.water/.measurements + TWO title systems
   (ProgramDayPrescription metadata vs TodayView.beatTitle).
3. THREE lesson-ordinal resolvers (TodayModules, BecomingView,
   TodayModuleHost) with divergent fallbacks; TWO lesson readers
   (LessonReaderView + legacy JeniMethodRitualView fallback); TWO
   completion stores (ProgramDayCheckRecord + JeniMethodState).
4. Steps goal: tier-varied in TargetsService (6000/7500/9000) but
   hardcoded 7500 in WeekState + TodayStepsSheet default.
5. LessonReaderView re-reads raw @AppStorage cohort keys, bypassing
   CohortStore.
6. Reset weeks change archetype rotation only — beats don't soften.
   "Permission week" is copy, not composition.
7. Chat transcript device-local; brief dual-owned (TodayStateService
   + ChatSession seed) — determinism contract must hold.
8. Evening (>=18:00) + Sunday receipt are wall-clock gated; no
   injected clock; only --uitest-force-* escapes.

## Production invariants (from safety agent — full report to be
## embedded in PRODUCTION_SAFETY.md)
- AppPhaseMachine.derive is the single gate; gates read
  effectiveHasProAccess; MainShell double-checks. DO NOT add gates
  reading raw hasProAccess.
- Rebuilding Today MUST re-wire: recordShownUpDay +
  markSessionCompleted (TodayModules:375,378) + refreshDailyAnchor
  (TodayView:336) or engagement counters, winback, milestones, and
  the anchor ladder silently die. NotificationOrchestrator DELETES
  daily_reminder when the ladder arms — if the ladder stops arming,
  users end up with NO pushes.
- appV2SeenAt stamped in MainShell.onAppear (+ MigrationMomentView).
- clearOnboardingUserDefaults (AppSync:607-686) must grow with every
  new identity-scoped @AppStorage key.
- SwiftData: additive nullable fields only; never rename @Model
  fields; food @Models stay OUT of the container (iOS 17 hang).
- Notification id changes = 4 sites (scheduler, cancelAll, AppSync
  sweep, NotificationDelegate.destination).
- Release truth: MARKETING_VERSION 1.1.4, build 24. --uitest-* seeds
  are #if DEBUG'd; --onboarding-v4 / --uitest-mock-chat / food
  --debug-* args are NOT (benign but inconsistent).
- Founder deploy deps: jeni-chat EF + 20260703 migration SQL +
  food-vision EF redeploy (photo+text context).

## v5 design seed (what extends inward)
- Serif editorial headline + italic punch, ONE hero per screen.
- Dossier/receipt card: tracked-caps label column + hairline rules +
  serif-italic value column ("maya file" card is the signature).
- Trust micro-copy under inputs ("never shown back as a grade").
- Tick ruler w/ haptic detents = the input instrument.
- Cocoa pill CTA; quiet text escapes; act eyebrows (tracked caps).
- Stickers ONLY on earned moments; real-photo cutouts from behind.
- Receipt-tape loader grammar for "she's working on it" moments.

## The founder's seven questions (the app must answer on open)
1. What is happening with my body and progress?
2. What matters today?
3. What is the one easiest thing I can do next?
4. Am I okay if today was messy?
5. What is Jeni noticing that I would not notice myself?
6. How do food/protein/steps/weight/medication/appetite/cravings/
   sleep/stress/consistency connect?
7. How do I stay on track without becoming obsessed?

Current mapping is scattered: 1→Becoming, 2/3→beats, 4→(nowhere
explicit), 5→insights (weekly-ish), 6→(nowhere), 7→(voice only).
The rebuild should make ONE surface answer 1-5 daily in one glance.
