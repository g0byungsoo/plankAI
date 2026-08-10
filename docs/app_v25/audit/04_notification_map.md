# 04 — NOTIFICATION MAP (v25 E1 recon, 2026-08-10)

Read-only inventory of the notification system as shipped through v24.
Everything local (UNUserNotificationCenter); zero remote push. All paths
relative to repo root. Line numbers from feat/app-v2 @ e3bb8f4.

## 0. The estate

`PlankApp/Notifications/` — 8 files, 2,107 lines total:

| file | role |
|---|---|
| `NotificationOrchestrator.swift` (349) | anchor ladder + re-signing knock + 3 JITAI pings |
| `RetentionNotifications.swift` (1028) | Glp1Cohort copy + winback/affirmations/day1/day5/evening review/milestones/first-log |
| `MedicationReminders.swift` (240) | v24 dose reminders — the ONLY actionable category |
| `NotificationDelegate.swift` (104) | UNUserNotificationCenterDelegate, deeplink routing |
| `TrialEndNotificationService.swift` (133) | T-24h trial push (currently DISABLED) |
| `RecapNotificationService.swift` (64) | Sunday recap push (DEAD — zero callers) |
| `NotificationTimeBucket.swift` (142) | bucket→hour mapping per PushIntent |
| `ActivationPushPolicy.swift` (47) | pure D1-D3 activation cap (≤3) |

Outside the folder but scheduling: `NotificationPermission` in
`PlankApp/Views/Onboarding/OnboardingComponents.swift:235` (daily reminder +
day-1 promise). Sweeping only: `BreakState` (`PlankApp/Program/DayModel.swift:194`),
`AppSync` (`PlankApp/Sync/AppSync.swift:1425,1131,1457`),
`NotificationSettingsView` master-off (`PlankApp/Views/Settings/NotificationSettingsView.swift:48`).

## 1. Identifier registry (complete)

| id | scheduler (def) | trigger | repeats |
|---|---|---|---|
| `anchor_d1`…`anchor_d7` | Orchestrator:28 | calendar Y/M/D+h:m | one-shot ×7 |
| `daily_reminder` | OnboardingComponents:242 (`dailyReminderIdentifier`) | calendar h:m | repeating daily |
| `daily-plank` | legacy, swept only (OnboardingComponents:243, Orchestrator:29) | — | — |
| `resigning_knock` | Orchestrator:114 | calendar Y/M/D 19:00 | one-shot |
| `keeping_zone` | Orchestrator:201 | calendar next-morning | one-shot |
| `keeping_line_quiet` | Orchestrator:202 | calendar +8d | one-shot |
| `lapse_support` | Orchestrator:203 | calendar today 20:30 | one-shot |
| `med_dose_reminder` | MedicationReminders:31 | calendar h:m (daily) or weekday+h:m (weekly) | REPEATING |
| `med_dose_snooze` | MedicationReminders:32 | interval 3600s | one-shot |
| `med_dose_open` | MedicationReminders:33 | calendar day-after-slot 9:30 | one-shot |
| `winback_lapse` | RetentionNotifications:192 | interval 2d (:298,604) | one-shot, re-armed |
| `affirmation_drop_0`…`_5` | RetentionNotifications:196 (lookahead 6 :304) | calendar Tue/Sat, bucket hour | one-shots |
| `day1_morning` | RetentionNotifications:207 | calendar D1 bucket hour | one-shot |
| `day5_anti_refund` | RetentionNotifications:216 | calendar charge+5d bucket hour | one-shot |
| `evening_plate_review` | RetentionNotifications:224 | calendar h:30 (19/20/21 by bucket) | REPEATING daily |
| `food_first_log_nudge` | RetentionNotifications:230 | calendar D3 12:30 | scheduling COMMENTED OUT :338 |
| `milestone_3/7/14/30/50/100` | RetentionNotifications:952,307 | calendar tomorrow bucket hour | one-shot each |
| `day1_promise` | OnboardingComponents:333 (`day1PromiseIdentifier`) | calendar her chosen time | one-shot |
| `becoming.sunday.recap` | RecapNotificationService:21 | calendar Sun 17:00 | DEAD — `scheduleIfEarned` has NO caller (only sweeps at DayModel:216, RetentionNotifications:562, delegate map :84) |
| `jenifit.trial.ending.reminder` (+legacy `absmaxxing.…`) | TrialEndNotificationService:27,30 | calendar T-24h | schedule call commented out (PaymentService.swift:638, pay-upfront) |
| `day0_anchor` / `day2_engagement` | legacy v1.0.7, swept only (RetentionNotifications:474-475,546-547) | — | — |

Worst-case pending ≈ 25 (7 ladder + knock + 3 JITAI + 3 med + winback +
6 affirmations + day1 + day5 + review + milestone + promise). **No code
anywhere counts pending or manages the iOS 64 cap** — the only
`pendingNotificationRequests()` read is TrialEnd's cancel no-op check
(TrialEndNotificationService:117). Safe today at ~25, but an arbiter adding
sources must own the budget.

## 2. Per-scheduler detail

### 2a. NotificationOrchestrator (enum, @MainActor entry points)
- **`refreshDailyAnchor(programDay:totalDays:)`** :32 — called from HomeView's
  composition point `PlankApp/Views/Home/HomeView.swift:1363` (enrolled only);
  day-rollover re-fire via `.NSCalendarDayChanged → refresh()` HomeView:400.
  Guards: once/day key `orchestrator.anchorRefreshDayKey` :26,35 · master
  `notificationsEnabled` :36 · `!BreakState.isActive` :37 · in-program :38 ·
  `.authorized` only :41.
- **Ladder** `scheduleLadder` :54 — removes ladder+legacy first :56 (replace-
  never-stack), then 7 one-shots. Hour: saved `notificationHour`/`notificationMinute`
  wins, else bucket `.reminder`, else 9 (:64-67 — release-audit fix so
  Settings' saved time isn't discarded). Content carries USER DATA: lowercased
  `userName` :68, program day in title :88, week-intent name :184; rungs ≥3 use
  begin-again register :166-167. userInfo deeplink `jenifit://today` :94.
- **Re-signing knock** `scheduleReSigningKnock` :116 — week's closing day 19:00,
  deeplink `jenifit://becoming` :141. **`cancelReSigningKnock()`** :151 called at
  sign time `PlankApp/Views/Becoming/ReSigningView.swift:281`. 4-site id protocol
  (scheduler · BreakState sweep · sign-cancel · delegate map) :108-112.
- **JITAI pings** :194-317. `onWeighSaved(userId:in:)` :233 — sole caller is the
  weigh chokepoint `WeightLogWriter.persist` tail (`PlankApp/Chat/ChatToolRouter.swift:176`;
  Today's weigh-in routes through it too, TodayModules:427). Keeping-chapter
  only + master toggle + `!BreakState.isActive` :234-237. Arms `keeping_zone`
  (band-crossing copy :216-227, next-morning bucket hour) and re-arms
  `keeping_line_quiet` (+8d watcher, each save cancels+reslates :271-286).
  `armLapseSupportIfEligible` :293 slated daily with the ladder (:47), 20:30,
  gate `lapseSupportEligible` :209 (day 1-42, NOT when evening review enabled —
  "≤1 uninvited evening push" — and not on break). **`cancelLapseSupport()`** :314
  fired when a plate lands (`PlankApp/Views/Today/TodayModules.swift:265`).
- Shared one-shot plumbing gates every add on `.authorized` :335-336.

### 2b. RetentionNotifications (enum) + Glp1Cohort copy
- **`reschedule(now:)`** :320 — called once per launch from
  `PlankApp/PlankAIApp.swift:2215` (post-sync `.task`). Stamps
  `notif.first_seen_at` :496; `.authorized`-gated :323 (`isAuthorized()` :1024
  — authorized ONLY, not provisional). Fans out: `armWinback` :591 ·
  `scheduleAffirmations` :630 · `scheduleDay1MorningIfNeeded` :744 ·
  `retryDay5IfNeeded` :886 · `scheduleEveningPlateReview` :420.
- **Winback** :591-607 — gate `notif.winback_enabled` + `!BreakState.isActive`
  :594-597; interval trigger 2d :298,604-605; body rotates 4 lines with name :609-622.
- **Affirmations** :630-683 — gate `notif.affirmations_enabled`, paused during
  first week :642 (`isWithinFirstWeek` :512, 5-pushes/week ceiling); Tue/Sat
  :301, bucket `.affirmation` hour :667; content: name + `identityFeeling` +
  coach display name :646-720.
- **Day 1 morning** :744-852 — one-shot flag `notif.day1_morning_done`. THE
  DAY-2 CONSENT GATE lives here (see §4). Suppressed by an existing day-1
  promise (`day1PromiseTimeISO` non-empty :777). Engaged vs cold copy via
  `Glp1Cohort.day1ContinueContent`/`day1MorningContent` :826-828 (cohort from
  `onboarding_glp1_status` :40-45). Cold variant passes ActivationPushPolicy
  :809-821 and increments `notif.activation_nudges_scheduled` :845-850.
  **`markSessionCompleted`** :462 (caller TodayModules:405) re-arms winback and
  REPLACES day1 with the engaged variant :484-486.
- **Day 5 anti-refund** :854-948 — entry `scheduleDay5AntiRefundIfNeeded(chargeDate:)`
  :873 from `PlankApp/Payment/PaymentService.swift:668` on real trial→paid
  (guards :662-667: periodType != .trial, willRenew, non-weekly); launch retry
  :886 off `notif.day5_charge_date`; shownUp>0 gate :918-919; cohort body with
  shownUp count :156-168.
- **Evening plate review** :420-456 — repeating daily :449, hour by
  `.eveningReflection` bucket (19/20/21/20) :446; gates: `notif.evening_plate_review_enabled`
  :423 + `!BreakState.isActive` :424 + not-first-week :432. Re-armed directly by
  FoodSettingsView toggle (`PlankApp/Views/Settings/FoodSettingsView.swift:219`,
  AppStorage mirror of the same key :33).
- **Milestones** :950-1020 — `recordShownUpDay(count:)` :961 from PresenceLedger
  (`PlankApp/Program/DayModel.swift:123`); shares the affirmations toggle :979;
  per-count done flags `notif.milestone_N_done` :242; fires next morning bucket
  hour; name+count in body :1008-1019. `markMilestonesDone(upTo:)` :969 heals
  without pushes (DayModel:180).
- **First-log nudge** — cancel path alive (`cancelFirstLogNudge` :347, fired on
  `food_first_log_saved` analytics event, PlankAIApp.swift:325); scheduling cut :338.
- **`applyTogglesChanged()`** :524 — settings toggles → surgical removes + full
  reschedule. **`cancelAll()`** :540 — the big sweep (all retention ids + jitaiIds
  + `day1_promise` + dead recap id :561-564) + clears one-shot UserDefaults state
  :566-586. Called on delete-account (AppSync:1131) and sign-out (AppSync:1457).

### 2c. MedicationReminders (v24, @MainActor enum)
- **`refresh(userId:in:)`** :80 — removes `allIds` FIRST :82 then re-derives.
  Gates: master `notificationsEnabled` :84 · active plan + per-regimen
  `plan.reminderEnabled` :85-86 · `.authorized` OR `.provisional` :88-89.
  NO BreakState guard and NO day-2 consent — the v24 carve-out lives here as an
  ABSENCE, documented :20-23 ("medical rhythm, not engagement: they SURVIVE
  breaks"). Callers: HomeView composition :1384 · dose mark tail
  (`PlankApp/Program/MedicationLog.swift:115`) · regimen mutations
  (`PlankApp/Views/Today/RegimenSheet.swift:106,217`) · onboarding bridge
  (PlankAIApp.swift:2396). "Significant-time-change" coverage is HomeView's
  `.NSCalendarDayChanged` → composition (HomeView:400).
- Trigger: weekly `weekday+h:m` repeating (ISO→Apple weekday conversion :108) or
  daily `h:m` repeating :123-126; wall-clock (DST/travel-safe) by design :16-18.
  Copy NEVER names the medication :11-14 — "your shot"/"your pill", oral
  empty-stomach variant :113-121. Weekly-only follow-up `med_dose_open` :146-179
  (slot+1d 9:30, via `MedicationScheduleEngine.nextDoseDate`).
- **Category** `MED_DOSE` :37, actions `MED_TAKEN`/`MED_SNOOZE` (background) and
  `MED_LOG_LATER` (.foreground) :49-71; registered at `install()`
  (NotificationDelegate:24-26). **`handleAction`** :185 — taken → cancel
  snooze+follow-up + `onTakenAction?()` (container-bound closure assigned at
  PlankAIApp.swift:2025 → `MedicationLog.resolve(.taken…, source: .notification)`);
  snooze → +1h `med_dose_snooze` :210-222; log later → falls through to deeplink.
- **`onDoseMarked()`** :225 — cancels pending snooze/follow-up AND removes
  DELIVERED reminder+snooze (the only `removeDeliveredNotifications` in the app)
  :226-231. Called from MedicationLog:73,99. **`cancelAll()`** :235 for the
  master-toggle-off sweep (NotificationSettingsView:59).

### 2d. NotificationPermission (OnboardingComponents.swift:235)
- `daily_reminder` :242; `scheduleDailyReminder(at:)` :283 — repeating h:m
  :306-315, title "five minutes, today." :302, voice-routed body with name
  `dailyReminderBody()` :361-370. Callers: settings save
  (NotificationSettingsView:245), onboarding nudge grant
  (OnboardingRevealView:1863), chat tool `set_reminder_hour`
  (ChatToolRouter:116 — also rewrites `plankTime` bucket :111).
- Day-1 promise :330-352 — HER OWN WORDS (action/anchor/name :336-339);
  conditional deeplink `jenifit://snap` :345-349; scheduled at seal if already
  authorized (OnboardingRevealView:2527-2531) and BACK-FILLED at the nudge
  grant (OnboardingRevealView:1873-1883 — seal happens pre-permission, so the
  grant moment re-schedules).

### 2e. TrialEnd + Recap (both effectively idle)
- TrialEnd: `scheduleIfNeeded` :39 never called (PaymentService:638 commented,
  pay-upfront); `cancelTrialEndReminder` :115 still live (PaymentService:641,
  AppSync:1132,1464). Reads-never-requests permission :64-71 (authorized OR
  provisional). Content: `Glp1Cohort.trialEndContent(shownUp:)` (RetentionNotifications:76-106).
- Recap: fully coded (≥2 engaged days, Sunday 17:00, break-gated :29) but
  **zero call sites** — dead since the v11+ rebirths.

## 3. Master toggle + per-surface keys

- **`notificationsEnabled`** (default false) — read by Orchestrator :36,235,
  MedicationReminders :84; set true at onboarding nudge grant
  (OnboardingRevealView:1861) and persisted via `handleOnboardingComplete`
  (PlankAIApp.swift:2276); hydrated from profile sync (AppSync:478); swept on
  sign-out (AppSync:1274). **RetentionNotifications does NOT read it** — its
  pushes gate on OS authorization + per-category keys only. Toggle-off sweep
  (NotificationSettingsView:48-59): daily reminder + ladder + jitai + knock +
  med ids — but NOT winback/affirmations/evening review/day1/day5 (own toggles
  or authorization-only).
- Per-surface `notif.*` (all default ON via nil-reads):
  `notif.affirmations_enabled` :235/:278 (also gates milestones :979; UI
  NotificationSettingsView:15,101) · `notif.winback_enabled` :236/:282 (UI :16,106) ·
  `notif.evening_plate_review_enabled` :237/:286 (UI lives in FoodSettingsView:33,
  "evening check-in") · bookkeeping keys :238-268 (`notif.last_session_at`,
  `stats.shown_up_count`, `notif.milestone_N_done`, `notif.first_seen_at`,
  `notif.day1_morning_done`, `notif.day5_anti_refund_done`, `notif.day5_charge_date`,
  `notif.first_log_nudge_done`, `notif.activation_nudges_scheduled`).
- Settings UI (NotificationSettingsView): hero "notifications." · "daily
  check-in" master row :29-35 · wheel time picker + save (writes
  `notificationHour`/`notificationMinute` :226-235, ONLY writer; ladder reads them
  Orchestrator:64-65) · live coach preview rendering the REAL
  `dailyReminderBody()` :183-185 · "gentle extras" (affirmations, winback)
  :100-119 with `requestPermission()` on enable (:248-253, `[.alert, .sound]`) ·
  denied-warning row :121-132. Medication reminders have NO row here — their
  toggle is per-regimen `reminderEnabled` in RegimenSheet.

## 4. The day-2 consent gate

`onb_consent_day2` — onboarding signature row "check on me in the first days".
Default TRUE (OnboardingView:264, OV5Flow:330). SEMANTICS (RetentionNotifications:761-775):
read only inside `scheduleDay1Morning`; explicit `false` suppresses BOTH day-1
variants and stamps `day1_morning_done`; missing key = shipped default (fires).
It gates ONLY the day-1 morning push — daily reminder, trial-end, day-5,
winback, affirmations, evening review, medication are explicitly separate
consents (:773-774; MedicationReminders:22-23). Swept on sign-out AppSync:1304.
ActivationPushPolicy (ActivationPushPolicy.swift:38-46) additionally caps cold
activation pushes at 3 per install (D1-D3 slots; only D1 wired today) and never
applies to the engaged "continue" variant :809-812.

## 5. Breaks

`BreakState` (DayModel:194-255): `break.activeSince`/`break.ranges` UserDefaults.
**`begin()`** :207 immediately removes ladder + legacy + jitai + knock +
`winback_lapse` + `evening_plate_review` + `becoming.sunday.recap` :211-218.
Schedulers ALSO guard at build time: Orchestrator :37,236,299; winback :597;
evening review :424; recap :29. **The v24 carve-out is purely the absence of any
BreakState check in MedicationReminders.refresh (:80-140) plus the absence of
med ids from BreakState.begin's sweep** — documented at MedicationReminders:20-23.
Nothing re-arms retention pushes at `end()` :222 — they return via the next
launch/composition pass.

## 6. NotificationDelegate

Installed at app init (PlankAIApp.swift:29). Foreground: `willPresent` returns
`[]` :61-67 — ALL notifications are invisible while the app is open (a
foreground dose reminder simply never shows). `didReceive` :29-57: med category
actions first (:42-45; taken/snooze complete WITHOUT navigation; log-later falls
through), then explicit `userInfo["deeplink"]` :47-51, else the static id→URL
map `destination(forNotificationId:)` :71-103 (day1_promise→snap,
evening_plate_review→becoming (v23 fix :76-81), first-log→snap, recap→becoming,
lapse_support→breath, daily/winback/day1/day5/keeping_*/milestone_*/
affirmation_drop_*→today; trial→nil). Routes hand to `AppRouter.shared.handle(url:)`
— pending state consumed only by `.main`-phase surfaces, so expired users
resolve at the wall :8-12.

## 7. Permission flow

- No provisional request anywhere; provisional is only ACCEPTED by
  MedicationReminders :88 and TrialEnd :66 (and requestOrOpenSettings :265).
  RetentionNotifications/Orchestrator require full `.authorized` (:1025-1026, :41).
- Ask sites: (1) onboarding nudge screen (NudgePermissionAsk in
  OnboardingRevealView; `allow()` :1854-1885 → `requestOrOpenSettings()`
  OnboardingComponents:261-272 — denied opens iOS settings deep-link; grant sets
  `notificationsEnabled`, schedules daily reminder at bucket time
  (7/13/19/9 :1906-1915), back-fills day-1 promise). The banner mock is
  `PlankApp/Views/Onboarding/NudgeNotificationBanner.swift`. (2) Settings
  toggles (NotificationSettingsView:248-253, `[.alert, .sound]`). Legacy
  OnboardingView "case 19" documented :8745-8751. `request()` uses
  `[.alert, .badge, .sound]` :246-254; no badge is ever set anywhere.
- Denied: schedulers silently no-op; only NotificationSettingsView:121-132
  surfaces it.

## 8. Time windows / quiet hours

`NotificationTimeBucket` (NotificationTimeBucket.swift:41-142) is the only
window system: `plankTime` bucket → hour per `PushIntent` (:62-90; primary
hours 8/14/19/10 :100-107; eveningReflection 19/20/21/20; trialEnd/postCharge
nil = billing-anchored). There is NO quiet-hours/DND engine (the `QuietHours`
type in `PlankApp/Program/Signals.swift` is sleep-data narration, unrelated).
Hardcoded off-bucket times: lapse 20:30, knock 19:00, med follow-up 9:30,
recap 17:00, first-log 12:30, med reminder at her per-regimen minutes.

## 9. Hazards for a wrapping arbiter (observed, not prescribed)

1. **Five independent removal authorities** mutate the same id space
   (schedulers' replace-first, BreakState.begin, RetentionNotifications.cancelAll,
   AppSync sign-out, Settings master-off) — the "4-site id protocol"
   (Orchestrator:108-112) is convention, not enforcement; an arbiter must own
   ids or every sweep site needs updating.
2. **Split brains on time + gating**: saved `notificationHour` vs bucket
   (Orchestrator:64-67 vs everything else); `.authorized`-only vs
   provisional-accepting schedulers; master toggle read by 2 of 5 schedulers.
3. **Cadence is opportunistic**: launch task (retention), Home composition
   once/day (ladder+med), event chokepoints (weigh/dose/session/payment) —
   there is no single re-plan tick; day rollover only re-plans if Home is alive
   (HomeView:400).
4. **Category registration is a single global set** (`setNotificationCategories`
   MedicationReminders:71) — any new category must merge, not replace.
5. **Content builders read live UserDefaults at schedule time** (name, cohort,
   voice, identityFeeling) — pre-scheduled one-shots go stale across identity
   changes; sign-out sweeps exist precisely for that (AppSync:1421-1430).
