# 29 — Identity & data scoping audit (v2.8)

The founder's standard: one user's data must never surface in
another user's experience, even locally after sign-out. Sweep of
every local read/cache, verdict per store:

| Store | Scoping | Verdict |
|---|---|---|
| SwiftData (weights, checks, plans, sessions, chat) | @Query/#Predicate userId everywhere (ChatSession.loadHistory verified this pass) | SAFE |
| FoodLogPersister entries | allEntries(userId:) now case-insensitive | FIXED (v2.7/2.8) |
| FoodLogPersister macros | todayMacros(userId:) overload; unscoped variant remains ONLY on the dead HomeFoodCard tile | FIXED |
| Snap result context | userId plumbed through capture chain | FIXED (this pass) |
| Share renderers | Daily: macros scoped this pass; Weekly: reads scoped entries | FIXED/SAFE |
| RecentMealsSheet | userId-scoped | SAFE |
| FoodPhotoStore | keyed by entryId (entry rows are user-scoped) | SAFE |
| @AppStorage onboarding/cohort | swept at sign-out (v1.1.1 list) | SAFE |
| day.note.* / day.reflection.* / lesson.rep.kept.* / stats.shown_up_count / day1Promise* / anchor guard | **WERE NOT SWEPT** — the note reaches jeni's context envelope, so this was a private-words-to-the-next-account leak. Prefix sweep added to clearOnboardingUserDefaults + pinned by test | FIXED (this pass) |
| Anchor ladder (anchor_d1..7) | carries her name + program day; now removed at sign-out alongside legacy ids (trial-end/promise untouched — RetentionNotifications.cancelAll already handled those) | FIXED (this pass) |
| Chat context envelope | assembled per-turn from the scoped snapshot + swept keys | SAFE (after sweep fix) |
| StepsService (HealthKit) | device-level by nature; HealthKit is the same physical person across app accounts — acceptable, documented | ACCEPTED |
| CohortStore reads | AppStorage keys in the sweep list | SAFE |

## Production safety delta
Client-only pass (no server artifacts touched; the migration + EF
remain undeployed and unchanged this pass). Gating untouched.
Regression tests: CrossAccountScopingTests (3 green).
