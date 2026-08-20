# 44 · WOULD I SHIP THIS TO 10,000 PEOPLE?

**THE RELEASE-CANDIDATE ADVERSARIAL AUDIT (feat/app-v2). 2026-08-15.**

> **A note on the number.** The brief asked for this record at
> `43_WOULD_I_SHIP_THIS_TO_10000_PEOPLE.md`. `43` is taken —
> `43_THE_REAL_DEVICE.md`, written earlier the same day, after the brief
> was drafted. Two files sharing a number is how a series stops being
> readable, so this is `44`. Nothing else about the brief was changed.

---

## EXECUTIVE VERDICT

**Build 31 is safe to ship, and one thing in it was not.**

Fourteen passes (`30`–`43`) sit uncommitted on this branch, and the
question this pass asked was not "is the new work good" but "what would
I regret at 10,000 customers". The answer was **one P0, and it is the
newest capability in the build.**

▎ **`34` gave the weigh-in a `remove it`. For every customer whose
▎ weight comes from a scale, it undid itself on the next launch.**

`BodyMassImportService` re-reads ninety days of Apple Health at every
launch and on every observer fire, and decides **by calendar day**: a day
with no local row is a day it creates one for — under a **fresh uuid**.
The deletion ledger names the id she removed, so it could never see the
replacement. The screen says *"every weigh-in lands here with its date,
and you can fix or remove any of them."* It was not true, and the
resurrected number went straight back to being the numerator of **both**
daily targets and a row in the clinician packet.

The delete affordance is new in this build. **The defect is new in this
build.** It is fixed, RED-proven at 3 failures of 4 new tests.

Three P1s follow, all bounded and all fixed. And the census found the
thing this pass would most have regretted *not* looking at:

▎ **`public.program_facts` and `public.weekly_reads` hold ZERO ROWS,
▎ because `authenticated` has NO privileges on either table.**

E1 THE SPINE — the authority chain the entire v25 line stands on — has
never synced, for anyone, since 2026-08-10. Its migration wrote nine
policies and not one `grant`. Every write 42501s into a `try?`; every
hydrate 42501s into a `catch` that only prints under DEBUG. It is a
one-statement repair, it is **written and deliberately not applied**, and
**Build 31 is safe without it** — the product behaves exactly as build 30
does.

**P0 REMAINING: 0. SAFE TO ARCHIVE: YES.**

---

## SYSTEM MAP

Re-derived this pass from the repository and the **live catalog**, not
inherited from `37`–`43`.

**18 `@Model` types** (`grep -rl '^\s*@Model'` → 3 files declaring 18
classes). Seventeen are customer-owned; `ExerciseRecord` is the exercise
library. **All 18 are in the deletion sweep. All 17 customer-owned are in
the identity merge** (`applyReattribution` 7 + `IdentityMerge
.carryRemainingFamilies` 8 + profile + consent, the last two REFUSED and
removed).

**36 foreign keys reference `auth.users`.** 34 CASCADE. Two SET NULL
(`account_handoffs.source_user_id`, by design; the two telemetry tables,
which hold **token counts, cost and latency only** — verified column by
column, no content, no health data). **Two tables carry a `user_id` with
no FK at all**: `private.invitation_attempts` (rate-limit bookkeeping)
and `public.care_weekly_summaries` (**0 rows**).

**Storage: one bucket, `body-scans`, 0 objects. `food-photos` DOES NOT
EXIST.**

| domain | source of truth | local | server | hydrate | delete | switch | reinstall | 2nd device |
|---|---|---|---|---|---|---|---|---|
| AUTH | GoTrue | Keychain session | `auth.users` | bootstrap | RPC → cascade | re-key | restore or re-anon | independent |
| HANDOFF | server receipt | `sync.pendingMergeV1` | `account_handoffs` | `complete` at launch | cascade / SET NULL | ADOPT only | discharges with no local state | n/a |
| DELETE ACCT | server | `AccountDeletionIntent` | `delete_user_account()` | — | 34 cascades | intent survives sweep | intent finishes at launch | independent |
| PROFILE | server | `UserRecord` | `public.users` | `hydrateUser` (skips pending) | CASCADE | B wins, A's row removed | EXACT | EXACT |
| WEIGHT | local+HK+server | `WeightLogRecord` | `weight_logs` | insert-only | ledger + server delete | fresh/preserved id | EXACT | resurrection possible |
| FOOD | JSONL | `FoodLogPersister` | `food_logs` | two-way | ledger + server delete | re-key | EXACT (**photos: MISSING**) | resurrection possible |
| PROGRAM | server | `ProgramPlanRecord` | `program_plans` | `ProgramPlanMerge` | CASCADE | one live plan | EXACT | EXACT |
| TARGETS | derived | `@AppStorage` | `users` columns | `restoreBodyDefaults` | swept | swept then restored | EXACT (4 body + 7 cohort) | EXACT |
| REGIMEN | local | `RegimenPlanRecord` | `regimen_plans` | insert-only | CASCADE | foreign authority REFUSED | EXACT | EXACT |
| DOSES | local | `DoseEventRecord` | `dose_events` | insert-only | ledger + delete | prefix swap | EXACT | EXACT |
| SYMPTOMS | local | `ObservationRecord` | `observations` | insert-only | ledger + delete | prefix swap | EXACT | EXACT |
| PROGRAM FACTS | **local only** | `ProgramFactRecord` | `program_facts` **(0 rows)** | **42501** | CASCADE | prefix swap | **LOST** | **LOST** |
| WEEKLY READS | **local only** | `WeeklyReadRecord` | `weekly_reads` **(0 rows)** | **42501** | CASCADE | prefix swap | **LOST** | **LOST** |
| JENI MEMORY | local only | `JeniMemoryRecord` | none (drafted) | n/a | in sweep | re-key in place | **LOST** (named) | **LOST** (named) |
| CHAT | local only | `ChatMessageRecord` | `coach_messages` (0 rows, no client) | n/a | in sweep | re-key in place | **LOST** (named) | **LOST** (named) |
| MOVE | local only | `move.manual.v1` | none | n/a | in sweep | swept | **LOST** (named) | **LOST** (named) |
| BODY SCANS | local-first | `BodyScanRecord` | `body-scans` (opt-in, 0 objects) | opt-in | pre-RPC purge | re-key | opt-in only | opt-in only |
| CONSENT | server | `ConsentGrantRecord` | `consent_grants` | insert-only | CASCADE | **REFUSED + removed** | EXACT | EXACT |
| SUBSCRIPTION | RevenueCat | cached flags | RC | stream | device residue swept | `logIn` | `syncPurchases` recovery | EXACT |
| CARE PROTOCOL | server | `careProtocol.served.v1` | `protocols` | every launch | **was: never swept** | **was: leaked** | re-resolved | re-resolved |

---

## NEW FINDINGS

### 1 · P0 — A REMOVED WEIGH-IN COMES BACK FROM APPLE HEALTH

`WeightLogWriter.remove` tombstones the row **id**. That is exactly right
for the resurrections `38` was built for — an insert-only hydrate, or a
stale second device re-pushing the row it kept — because those re-insert
**the same id**.

A weigh-in has a second author and it does not work that way:

```swift
// BodyMassImportService.importRecent — before
if let row = existingByDay[day] {
    guard row.source == "healthkit" else { continue }   // manual wins its day
    ...
} else {
    let row = WeightLogRecord(userId: userId, weightKg: kg, ...) // FRESH uuid
    context.insert(row)
}
```

`else` means *"this day has no row"*. It cannot mean *"she cleared this
day"*, because nothing told it the difference. So:

1. smart scale writes to Health → row inserted, `source = "healthkit"`;
2. she opens `your weigh-ins` and taps **remove it** → id tombstoned, row
   gone locally, row deleted server-side;
3. next launch (or the next observer fire, which is immediate) → the day
   is empty → **a new row, a new uuid, the same number**;
4. the ledger names an id that no longer exists anywhere.

**It is not cosmetic.** The freshest weigh-in is
`TargetsService.resolvedWeightKg` — the numerator of the calorie target
AND the protein floor — and `VisitPacketBuilder.weightSection` reads the
same rows into the clinician packet.

**FIXED.** The retraction is recorded against the thing she actually
cleared: **the day**. `DeletionLedger.clearedWeightDayId(userId:dayKey:)`
follows the deterministic-id shape this codebase already uses
(`<uid>-dose-<day>`, `<uid>-symptom-<s>-<day>`), so `IdentityMerge
.rekeyedDeterministicId`'s prefix swap and `DeletionLedger.carry`
translate it for free, and `sweep` ignores it — it can never match a real
row id, and it is not meant to. `BodyMassImportService.importDecision` is
now a pure function over (day, existing source, ledger), so the rule is a
sentence a test reads rather than a branch inside an async HealthKit walk.

**Deliberately not superseded by a later weigh-in.** A row on that day
makes the importer stand down anyway (manual wins its day), and if she
removes that row too the tombstone is simply re-recorded. Clearing a day
stays cleared until the account goes.

### 2 · P1 — E1 THE SPINE HAS NEVER SYNCED, FOR ANYONE

Read from the live catalog:

```
has_table_privilege('authenticated','public.program_facts','SELECT') → false
                                              INSERT/UPDATE/DELETE   → false
has_table_privilege('authenticated','public.weekly_reads', ...)      → false ×4
select count(*) from public.program_facts   → 0
select count(*) from public.weekly_reads     → 0
```

Both tables have **RLS enabled with four policies each**. The policies
were written; the grant never was.
`20260810090000_v25_e1_program_spine.sql` contains **nine `create policy`
statements and zero `grant` statements**. Its sibling from the day
before, `20260809090000_v24_medication_platform.sql`, has
`grant select, insert, update, delete on public.dose_events to
authenticated;` on line 81. One migration remembered; the next did not.

**Why five passes read past it:** every write is fire-and-forget inside a
`try?`, every hydrate is wrapped in a `catch` that only prints under
DEBUG, and the local store answers every read correctly — because it is
the only store there is. No number moves. No screen changes. No test
fails.

The client's own comments deny it in writing:
`ProgramFactStore.bootstrapIfNeeded` says *"a second device must see the
first device's migration rows and write nothing"*, and `hydrateAndSync`
orders `hydrateProgramFacts` **before** the bootstrap for exactly that
reason. The ordering is correct and the call has never returned a row.

**The clinic side is unaffected** — `care_set_program_fact` /
`care_end_program_fact` are SECURITY DEFINER owned by `postgres`, so they
bypass the missing grant. Only the customer's own client is locked out of
her own rows.

**WRITTEN, NOT APPLIED:** `docs/app_v25/44_packages/G1_e1_spine_grants.sql`.
Applying it changes behaviour for 4,293 accounts on a release candidate,
and "expected to be safe" is what `41`'s E1 was before `42` audited it as
hostile code and found eight corrections including a blocker. **Build 31
is safe without it.**

### 3 · P1 — THE PLATE PHOTOS HAVE NO DESTINATION, AND THE CLIENT PAID FOR IT EVERY LAUNCH

`storage.buckets` holds exactly one row: `body-scans`. **`food-photos`
has never existed.** `storage.objects` holds zero rows in total.

So since the seam shipped on 2026-07-25, every plate-photo upload has
failed and landed in an **uncapped** on-disk queue, and
`flushPendingUploads` re-attempted **the whole queue, sequentially,
awaited**, at every launch — from inside `AppSync.onLaunch`, **ahead of
the launch hydrate**. Production today: 144 photographed plates across 11
customers, the heaviest holding **58**. That customer makes 58 failing
round trips before the restore `43` already measured as the slowest thing
on a returning payer's launch.

The download half is worse on a reinstalled device: the object can never
exist, so `entriesMissingPhoto` never shrinks and the sweep made up to
**200 failing round trips at every launch, twice** (`onLaunch`, and again
after `hydrateFoodLogs`), forever.

▎ **THE BUCKET IS DELIBERATELY NOT CREATED.**

The deployed `delete_user_account()` is, in full:

```sql
requesting_user_id := auth.uid();
IF requesting_user_id IS NULL THEN RAISE EXCEPTION ... END IF;
DELETE FROM auth.users WHERE id = requesting_user_id;
```

Nothing else. **[CORR] `AppSync.deleteCurrentAccount`'s comment claims
*"the updated delete_user_account RPC now purges the body-scans bucket
server-side as the backstop."* It does not.** `storage.objects` has no FK
to `auth.users`, so creating `food-photos` before a corrected storage
purge exists would make **every plate photograph survive account
deletion**. `40` §A1 wrote the ordering itself — *apply the purge before
the bucket exists* — and `42` [CORR-1] found that purge as written would
throw on a zero-row delete. Founder gate, sequenced.

**FIXED (the client half):** the flush stands down after 3 consecutive
failures; the download sweep runs at most once per user per day, and
**spends the day only when there is real work** (on a reinstall
`onLaunch` calls it before the journal has hydrated, so an
unconditional stamp would burn the day and skip the real sweep); the
queue is capped at 500, newest kept.

### 4 · P1 — A CLINIC'S CLINICAL CONFIG CROSSED INTO THE NEXT ACCOUNT

`careProtocol.served.v1` caches the last sane config a **clinic** served
to **one** account, and `CareProtocolStore.current` is a process-lifetime
static that `bootstrapFromCacheIfNeeded()` adopts at cold start **before
any network call**. Neither was in any sweep, and `clearOnboarding
UserDefaults` is sign-out, account switch **and account deletion**.

So after account A (a clinic patient) signed out, account B's protein
floor, pace ceiling and hydration aim were composed from a protocol B's
clinic never served — the sentence `41` §2 wrote for care-team regimen
rows, one layer down. Online it healed at the first `hydrate`; **offline
it never healed at all**, and it survived "delete my account" on disk.

**FIXED.** `CareProtocolStore.forgetServedProtocol()` clears the cache,
resets `current` to the bundled `.default` and re-arms the cold-start
read; the sweep calls it. Bounded by the sanity gate either way, but a
clinic's judgement is not this device's to lend.

### 5 · P1 — TOMORROW'S INTENTION WAS IN NO SWEEP

`day.note.`, `day.reflection.`, `day.sit.` and `day.dose.` are all swept
prefixes. `day.intention.` — the fifth `day.` family — was not.
`HomeEvening` writes `day.intention.<tomorrow>` and
`day.intention.text.<tomorrow>`; `TodayStateService` reads the text back
as `morningIntention`; `DailyBriefEngine` prints it. So the decision she
made last night arrived in the **next account's** morning brief, and
survived "delete my account" on disk and in every device backup after it.

Same sentence as `move.manual.v1` in `38`: it changes no arithmetic,
which is why six passes read past it, and it is customer-authored, which
is why it belongs in the sweep. **FIXED**, one prefix.

### 6 · P2 — `ISO8601DateFormatter()` CANNOT READ A SERVER-WRITTEN TIMESTAMP

Six sites parse a Postgres `timestamptz` with a bare
`ISO8601DateFormatter()`. Measured:

```
"2026-08-15T06:25:18+00:00"         -> 2026-08-15 06:25:18 +0000
"2026-08-15T06:25:18.123456+00:00"  -> NIL
```

Client-written values carry whole seconds and parse. **Server-written
ones carry microseconds and do not** — `complete_account_handoff` sets
`archived_at = now()`, and so did `43`'s own production write
`W1_archive_duplicate_plan.sql`. So `ProgramPlanMerge` adopts
`archivedAt = nil` for a plan the server archived.

**It is latent, and the census proves it:** `phase` travels with
`archived_at` in both writers, every reader checks `phase` first
(`livePlanPhases.contains(phase) && archivedAt == nil`), and
production holds **zero** plans with `archived_at` set and a live phase.
Named rather than fixed, because the fix is a formatter change across six
call sites on a frozen candidate and nothing today depends on it. **The
day a writer sets `archived_at` without `phase`, this becomes a P0.**

### 7 · NOT A DEFECT — THE AUTHORIZATION BOUNDARY HOLDS

The deployed `complete_account_handoff` takes
`(p_source_user_id uuid DEFAULT NULL, p_mode text DEFAULT 'move')`, and
the client sends only `p_mode`. A client-supplied uid is present in the
signature, so §25's question is live. Reading the deployed body:

```sql
-- the subjects THIS caller demonstrably owns, computed server-side
select ... from auth.identities i where i.user_id = v_dest and i.provider='apple'
...
where h.subject_hash = any(v_subjects)
  and h.source_user_id <> v_dest
  and (p_source_user_id is null or h.source_user_id = p_source_user_id)
```

`p_source_user_id` is a **pure narrowing filter applied after** the
server-computed subject set. It cannot widen anything. Anonymous
destinations are refused `42501`; the source's anonymity is re-checked
**at use**, not only at BEGIN; the `auth.users` delete asserts
`is_anonymous is true` on the DELETE itself. **No privileged RPC trusts a
client uid.**

Also checked and clean: `care_log_client_event` is anon-callable and
SECURITY DEFINER, and it is properly defended — a 19-value `kind`
whitelist, `^[A-Za-z0-9_.:-]+$` plus a length cap on every text argument,
a status range check, and a 30-events-per-15-minutes cap per caller.

---

## CORRECTIONS TO 29–42

**[CORR-1] on `39`/`43` — the deployed `delete_user_account()` purges
NOTHING but `auth.users`.** `AppSync.deleteCurrentAccount`'s comment says
the RPC *"now purges the body-scans bucket server-side as the backstop"*.
Read from `pg_proc`: it is four statements and one of them is the delete.
The **fourth false comment on a deletion path** in this line of work
(`38` §0 on `signInWithApple`, `39` §8 on the deployed RPC, `40` on
`AccountDeletionIntent.clear`). It costs nothing today — `storage
.objects` holds **0 rows in total** — and it is exactly the belief that
would let someone create the `food-photos` bucket.

**[CORR-2] on `43` — `authenticated` has no privileges AT ALL on
`program_facts` / `weekly_reads`, not just no SELECT.** `43` recorded
*"`authenticated` has NO SELECT on `public.program_facts` or
`public.weekly_reads`, so both hydrates 42501 on every sign-in for
everyone (0 rows today; a grant, not a schema change)"*. INSERT and
UPDATE are missing too, which changes what "0 rows today" means: it is
not that nobody has written any yet, it is that **nobody ever can**. The
feature has never worked, not once, for anyone.

**[CORR-3] on `40` §A1 — `food-photos` still does not exist, and that is
now load-bearing in the other direction.** `40` said *"apply A1 before it
does"*. Since then the client has been failing into an uncapped queue
that is re-walked at every launch. The absence is no longer neutral: it
has a running cost, and the fix that removes the cost is on the client,
not on the bucket.

**[CORR-4] on `37` §16 / `38` §4 — `care_weekly_summaries` is still
FK-less and it is still 0 rows.** Three passes have named it; the census
re-measured it rather than inheriting it. It remains free to decide.

**[CORR-5] on `34` — the weigh-in delete was incomplete in a way `34`
could not have seen from the weight rail alone.** `34` correctly found
that `applyHydratedWeightLogs` is insert-only and added the server
delete, calling a delete that undoes itself *"worse than no delete at
all"*. The sentence was right and the inventory was short by one author:
Apple Health.

**Re-derived, not inherited:** 18 `@Model` types (`41` §7 said 18
declared / 17 customer-owned — confirmed); 36 FKs into `auth.users`; 25
server families; `auth.users` 4293 / anon 3426 / permanent 867 and
identities 559 apple / 308 email — **byte-identical to `43`'s baseline,
zero drift.**

---

## P0

| # | finding | status |
|---|---|---|
| 1 | A weigh-in removed from `your weigh-ins` is re-created from Apple Health on the next launch under a fresh uuid, and resumes driving both daily targets and the clinician packet. | **FIXED** |

**P0 REMAINING: 0.**

## P1

| # | finding | status |
|---|---|---|
| 2 | `authenticated` has zero privileges on `program_facts` + `weekly_reads`; both are empty; E1's spine has never synced. | **MIGRATION WRITTEN, NOT APPLIED** (`44_packages/G1`) |
| 3 | `food-photos` bucket does not exist → uncapped failing upload queue re-walked every launch ahead of the hydrate; up to 200 failing downloads per launch on a reinstall. | **CLIENT FIXED**; bucket is a sequenced founder gate |
| 4 | `careProtocol.served.v1` + the in-memory `current` crossed accounts and survived deletion. | **FIXED** |
| 5 | `day.intention.*` in no sweep — reached the next account's morning brief, survived deletion. | **FIXED** |

**P1 REMAINING: 1** (#2, explicitly deferred and founder-gated; Build 31
is safe without it).

## P2

| # | finding |
|---|---|
| 6 | `ISO8601DateFormatter()` cannot parse server-written fractional-second timestamps (6 sites). Latent — `phase` carries the meaning; 0 production rows exposed. |
| 7 | `public.care_weekly_summaries` has no FK to `auth.users` (0 rows). Legal question from `38` §10 still unanswered. |
| 8 | `users.program_mode` and `users.goal_direction` are **100% NULL** (0 of 2,943). Columns applied 2026-07-03, zero writers — confirms `35`/`43`. |
| 9 | Unswept keys with no clinical or content impact: `onb_food_cuisines`, `breathwork.weekly_day_keys`, `notif.day0_anchor_done`, `notif.day2_engagement_done`, `PaymentService.entitlementVerifiedAt`, `visitq.removed.*`, `evening.moment.presentedDayKey`, `letter.presentedDayKey`, `app.lastOpenDayKey`. |
| 10 | `CoachNoteService` has **zero call sites**; `coach_notes_v1` is therefore never written. Dead, and dead *quietly* — the singleton is never instantiated, so it costs nothing at runtime. |
| 11 | `private.environment()` and `private.has_clinical_authority(uuid)` are SECURITY DEFINER with **PUBLIC** execute. **Proven unreachable** — the live API answers `PGRST106 · "Only the following schemas are exposed: public, graphql_public"`. The grant is still wider than the intent and is one `revoke` from being right. |
| 12 | 8 production accounts hold **more than one live plan**. The client heals this (`reconcileLivePlans` after hydrate, then pushes the archive), so Build 31 repairs them on their next launch — recorded so the count can be re-read afterwards. |
| 13 | 17 live plans are maintenance-shaped (`goal >= start`) and `program_mode`/`goal_direction` are NULL for everyone, so each of those 17 is one account transition away from `.unknown` and the *"losing or holding?"* ask. That is `35`'s designed refusal working, not a defect — recorded because it is a real support-visible population. |

---

## PRODUCTION CENSUS

`docs/app_v25/release_candidate_census.sql`. **READ ONLY**, counts and
bounds only, no email / name / Apple subject / health payload / free text
/ token / uid.

**Proven read-only mechanically before execution:** comments and
single-quoted literals stripped, then every one of
`insert · update · delete · truncate · drop · alter · create · grant ·
revoke · copy · call · do · merge · refresh · vacuum · analyze · comment ·
set · begin · commit · rollback · lock · notify · execute · nextval ·
setval · pg_sleep · dblink` matched as a whole word → **0 hits**;
**1 semicolon-separated statement, and it starts with `select`.**

Executed 2026-08-15. Headline answers:

```
Q1  buckets                     body-scans (0 objects) · food-photos ABSENT
Q2  FKs into auth.users         36 (34 CASCADE, 2 SET NULL)
Q2  user_id with NO FK          private.invitation_attempts · public.care_weekly_summaries
Q3  care_weekly_summaries       0 rows, 0 already-orphaned
Q3  telemetry                   1115 / 230 rows — tokens, cost, latency only
Q4  secdef outliers             3 anon-executable care fns (all defended) + 2 PUBLIC in `private`
Q5  handoffs                    7 total · 0 open · 7 completed · 0 expired · 0 digests retained
Q6  drift vs 43                 4293 / 3426 / 867 · apple 559 · email 308  — IDENTICAL
Q7  plans                       138 accounts with one live plan · 8 with MORE THAN ONE
Q7  plans                       17 maintenance-shaped · 0 archived-with-live-phase
Q8  facts                       780 permanent profiles · 0 without height · 2 without a goal
Q8  facts                       program_mode non-null 0 · goal_direction non-null 0
Q9  grants                      program_facts + weekly_reads: authenticated has NOTHING
Q10 food                        891 photo · 70 quick_add · 5 words · 144 photo-door since 07-25
Q10 food                        largest single-customer photo queue: 58
```

**PRODUCTION DATA MUTATIONS THIS PASS: NONE.** Every statement executed
against production was a `SELECT` or a `pg_catalog` introspection.

---

## FIXES MADE

Five source files, two test files. Every one traces to a reproduced or
mechanically proven customer-facing defect.

| file | change |
|---|---|
| `PlankApp/Sync/DeletionLedger.swift` | `clearedWeightDayId(userId:dayKey:)` — the day-shaped tombstone, and why it is day-shaped |
| `PlankApp/Chat/ChatToolRouter.swift` | `WeightLogWriter.remove` records the day alongside the id |
| `PlankApp/Health/BodyMassImportService.swift` | `ImportDecision` + `importDecision(forDay:existingSource:userId:)` — the per-day rule as a pure function; the import loop switches on it |
| `PlankApp/Program/CareProtocolStore.swift` | `forgetServedProtocol()` — cache + `current` + cold-start re-arm |
| `PlankApp/Sync/AppSync.swift` | `day.intention.` prefix; `CareProtocolStore.forgetServedProtocol()`; `FoodPhotoSyncService.sweepStampKey` in the sweep |
| `PlankApp/Sync/FoodPhotoSyncService.swift` | 3-consecutive-failure stand-down; once-per-day download sweep spent only on real work; 500-entry queue cap |
| `plankAITests/DeletionContractTests.swift` | +4 — the scale (P0), day scoping, account scoping, and a control |
| `plankAITests/CrossAccountScopingTests.swift` | +4 — the intention, the clinic protocol, the sweep stamp, the queue cap |

**No new product feature. No screen redesigned. No abstraction added. No
paywall, payment, auth, notification, care, body-scan, workout, widget or
`@Model` file touched.**

---

## MIGRATIONS / DEPLOYS

| | |
|---|---|
| **MIGRATIONS WRITTEN THIS PASS** | 1 — `docs/app_v25/44_packages/G1_e1_spine_grants.sql` |
| **MIGRATIONS APPLIED THIS PASS** | 0 |
| **VERIFIED LIVE THIS PASS** | 0 (G1 is unapplied; its verification block is written and unrun) |
| **`supabase/migrations/`** | untouched this pass. It holds one untracked file, `20260814120000_v25_e1_account_handoffs.sql`, which `42` applied and `43` verified. |
| **EDGE FUNCTIONS** | zero diff |
| **PRODUCTION WRITES** | NONE |

---

## KNOWN LIMITATIONS

Stated, not hidden. None of these blocks Build 31.

1. **A deletion does not travel to the other device.** Only a server
   tombstone can, and `38` proved it cannot ship before a filtering
   client reaches the installed base. Unchanged.
2. **A reinstall of the deleting device loses its ledger** — including
   the new weight-day tombstones. Same boundary as every other entry.
3. **Plate photos do not survive a reinstall**, because there is nowhere
   for them to go. Nothing in the product promises they do — `photo
   retention` offers *keep with my plates* vs *discard after analysis*,
   both of which are true of a local store. Sequenced behind the storage
   purge.
4. **Program facts and weekly reads do not survive a reinstall** until G1
   is applied.
5. **Jeni's memory, the chat transcript and MOVE's typed sessions are
   local-only** and are lost on reinstall. Named since `34`/`37`/`38`.
6. **Sign in with Apple revocation is still manual.** Jeni holds none of
   the three credentials Apple accepts — the `authorizationCode` has zero
   first-party call sites and Supabase stores no provider token — so
   TN3194 step 2 (*"direct the user to manually revoke access"*) is the
   only honest thing the sheet can say, and it says it, to Apple
   customers only. **Data deletion does not depend on Apple:**
   `delete_user_account()` removes the `auth.users` row and 34 cascades
   fire regardless. The fallback is **not** equivalent to programmatic
   revocation and is not described as such.
7. **65 of 94 swept keys still have no restore path** (`43`'s census).
   Unchanged; the two that mattered clinically were closed in `35`.
8. **The `.preserve` id policy can strand an anonymous period for up to
   30 days** if BEGIN succeeds and COMPLETE never does. `dischargeOwed
   HandoffIfNeeded` retries at every launch; the receipt expires at 30
   days. Structural, and the cheaper of the two wrong guesses.

---

## APP REVIEW GATE

| requirement | verdict |
|---|---|
| Subscription close always responds | **YES** — `WallExitIntent.next` is total, has no "do nothing" case, and `standDown()` always changes the screen. The 1.1.7(28) rejection state (`--uitest-wall-spent`) is a first-class QA door. |
| Restore Purchases reachable | **YES** — on the paywall, on `ExpiredWelcomeView`, and on `StandDownView`. |
| Sign In reachable | **YES** — `StandDownView`, `ExpiredWelcomeView`, and the re-auth sheet in `MainShell`. |
| Account deletion reachable | **YES** — Settings, and the sheet scrolls at AX5 (`39`'s fix; the pre-fix screen put both buttons off-screen). |
| Deletion actually deletes | **YES** — 34 cascades verified from `pg_constraint`. Retained: two telemetry tables (tokens/cost/latency only, `user_id` SET NULL) and `care_weekly_summaries` (**0 rows**, no FK). Storage retains nothing — 0 objects exist. |
| Sign in with Apple deletion path | **HONEST** — see Known Limitations 6. |
| No debug/test UI in Release | **VERIFIED** — see TEST PROOF. |
| No review-only behavior | **YES** — no branch keys off a review flag; `BuildChannel` is observability only and gating never reads it. |

---

## TEST PROOF

Run serially, on `QA-iPhone16` (`259952D4-…`).

| suite | expected | actual | exit | line |
|---|---|---|---|---|
| baseline app (before any change) | 1346 | **1346, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| `DeletionContractTests` **RED** | ≥1 failure | **3 failures of 4 new** (the control correctly passed) | 65 | `** TEST FAILED **` |
| `DeletionContractTests` **GREEN** | 18 | **18, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| `CrossAccountScopingTests` **RED** | ≥1 failure | **5 assertion failures across 2 new tests** | 65 | `** TEST FAILED **` |
| `CrossAccountScopingTests` **GREEN** | 7 | **7, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| **full app suite** | 1346 + 8 | **1354, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| PlankSync (`swift test`) | 9 | **9, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| PlankFood (package scheme) | 200 | **200, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests` (device walker) | 1 | **1 passed** (`testSpentWallCloseButtonAlwaysResponds`, 10.6s) | 0 | `** TEST SUCCEEDED **` |
| Release build (`generic/platform=iOS`) | — | — | 0 | `** BUILD SUCCEEDED **` |

**RED was proven for both fixes, and the controls held.**
`testManualStillWinsItsDayAndAHealthRowStillUpdates` did **not** go red —
it asserts the two rules that were already correct, which is the point of
having it. `+8` is exactly the number of tests added.

Baseline was **re-measured, not inherited**: 1346 matches `43`'s recorded
figure exactly.

### Binary + diff proof

Release, `generic/platform=iOS`, unsigned. **`** BUILD SUCCEEDED **`**

| check | result |
|---|---|
| binary size / string count | **87 MB / 124,103 strings** |
| `--uitest` · `--debug` · `--food-debug` · `debug-weigh-ins` · `--demo-backend` · `debug_anthropic_api_key` | **0 · 0 · 0 · 0 · 0 · 0** |
| backend hosts in the binary | **`https://mtecqvykyeueumdynatd.supabase.co` only** |
| observation strings from this pass (`44-OBS`) | **0** |
| all three `@Model`-declaring files vs `1710180` | **ZERO DIFF** — no store migration exists to fail |
| `PlankApp/Payment`, `Views/Paywall`, `App/AppPhase.swift`, `Info.plist`, `plankAI.entitlements`, `Notifications`, `Care`, `BodyScan`, `Workout`, `JenifitWidgets` vs `1710180` | **EMPTY** |
| `supabase/` this pass | **untouched** |
| Edge Functions this pass | **untouched** |
| `Packages/` this pass | **untouched** |
| `plankAI.xcodeproj/project.pbxproj` this pass | **untouched** — no file added to the project |
| `CURRENT_PROJECT_VERSION` | **30**, not bumped |

**A `strings` ABSENCE IS ONLY EVIDENCE WITH A CONTROL.** The new
tombstone fragment `-weightday-` returns 0 hits — and so do `-dose-`,
`-symptom-` and `deletions.v1.`, three fragments that have shipped for
passes and are unquestionably present. Swift stores interpolation
fragments in a form `strings` does not surface, so the count proves
nothing either way. The proof that the fix is compiled in is the test
run: 1354/1354 with the four scale tests green, which went from 3
failures to 0 across exactly this change. Same shape as `35`'s
empty-PATH trap and `32`'s `Executed 0 tests` — **always check a
known-present control before reading a zero.**

---

## RELEASE DECISION

**SHIP IT**, with G1 as the founder's next call and the `food-photos`
bucket sequenced behind a corrected storage purge.

The build is better than the one it replaces on the one axis that
matters here: a capability it introduced (`remove it` on a weigh-in) no
longer reverses itself, and three cross-account or per-launch costs that
were live in build 30 are gone.

---

## THE THIRTY ANSWERS

**1. WHAT WAS THE WORST NEW DEFECT FOUND?**
A weigh-in removed through `your weigh-ins` was re-created from Apple
Health on the next launch under a fresh uuid the deletion ledger could
not see — and it resumed driving the calorie target, the protein floor
and the clinician packet.

**2. COULD IT AFFECT A REAL CUSTOMER TODAY?**
Not today — the delete affordance is new in Build 31. It would have
affected every customer with a smart scale from the day 31 shipped.

**3. DID ANY CUSTOMER DATA FABRICATION REMAIN?**
No. `EnergyBasis.unknown` publishes no number; `planAgreesWithHer`
refuses a plan aimed at nobody; `planHoldsWithUnknownDirection` asks
rather than guesses; `missingEnergyInput` names the missing fact. The
census found only 2 of 780 permanent profiles without a goal and 0
without a height.

**4. DID ANY CUSTOMER DATA LOSS PATH REMAIN?**
Yes, two, both named and neither new: **program facts and weekly reads
are lost on reinstall** until G1 is applied, and **Jeni's memory, the
chat transcript and MOVE's typed sessions** are local-only by design.

**5. CAN ACCOUNT A LEAK INTO ACCOUNT B?**
No longer. Two live leaks were found and closed this pass (the served
care protocol, tomorrow's intention). The merge refuses named→named, the
isolation sweep runs first on a switch, and 17 of 17 customer-owned
families are covered.

**6. CAN A SAFETY DECISION LEAK INTO ANOTHER ACCOUNT?**
No. The whole `safety_` family is swept by prefix, and the served
protocol — the last clinical config that crossed — is now swept too.

**7. CAN A PAID CUSTOMER LOSE ACCESS INCORRECTLY?**
Not durably. `isInAuthTransition` holds the last stable phase through a
re-key, `EntitlementRecoveryDecision` posts the receipt silently on the
walled-payer signature, and the interactive-sign-in trigger waives
`wasEverEntitled` for reinstalls.

**8. CAN AN UNPAID CUSTOMER RECEIVE PAID STATE INCORRECTLY?**
Only for the sub-second auth-transition window, where the paywall is
deliberately suppressed to stop a flicker. The device entitlement residue
is swept on sign-out, so B never inherits A's wall variant or arms a
transfer against the wrong account.

**9. CAN A DELETED RECORD SILENTLY RETURN ON THE SAME DEVICE?**
It could — that was the P0 — and it cannot now. Food, weight, dose and
symptom are all ledger-protected, and the weight rail's second author
(Apple Health) is now covered by a day-shaped tombstone.

**10. WHAT CAN STILL RETURN ON A SECOND DEVICE?**
Anything the other device still holds and re-pushes: a plate, a weigh-in,
a dose, a symptom. The deleting device removes it again on its next
hydrate and re-asserts the server delete. It flaps until the other device
updates. Only a server tombstone closes it.

**11. WHAT DOES NOT SURVIVE REINSTALL?**
Plate photographs (no bucket), program facts and weekly reads (no grant),
Jeni's memory, the chat transcript, MOVE's typed sessions, body scans
without backup, and the deletion ledger itself.

**12. IS EVERY SUCH LOSS DISCLOSED OR INTENTIONAL?**
Intentional and disclosed for body scans (*"your scans live on this
iPhone"*). Intentional and **named in the record but not on screen** for
memory, transcript and MOVE. **Neither** for photos and program facts —
those are the two defects, and both are sequenced.

**13. CAN HOME AND JENI DISAGREE?**
Not on the facts checked: both resolve weight through
`TargetsService.resolvedWeightKg`, the pace word through
`IntensityTier.paceWord`, and the envelope omits rather than defaults.

**14. CAN JENI CLAIM A WRITE SUCCEEDED WHEN IT FAILED?**
`log_weight` returns `logged: true` on the **local** commit, which is the
same promise every other surface makes; the cloud push is retried by
`pendingUpsert`. `propose_program_fact` and `remember` return the store's
own answer. No tool returns success on a refusal.

**15. CAN HOME AND THE CLINIC EXPORT DISAGREE ABOUT A RECORDED FACT?**
Not after the P0 fix. Before it, a weigh-in she deleted could be absent
from Home and present in the packet on the same launch.

**16. CAN A CARE-TEAM FACT CROSS TO AN UNAUTHORIZED ACCOUNT?**
Not as a row — `IdentityMerge.carriesForeignAuthority` refuses and
removes both a care-team regimen and a prescribed program fact. It could
cross as **config** until this pass; it cannot now.

**17. CAN A LEGACY PLAN PRODUCE A WRONG TARGET?**
No. `planAgreesWithHer` refuses a plan whose goal is at or above the body
it is computing for, and `ProgramPlanMerge` adopts a support repair on a
clean row.

**18. CAN A MISSING FACT PRODUCE A FABRICATED TARGET?**
No. Missing weight, height, goal or direction each return `nil` and name
themselves.

**19. CAN TIMEZONE CHANGE MOVE A RECORD TO THE WRONG DAY?**
Day keys are local-calendar throughout and the parsers that read them set
`timeZone = calendar.timeZone`. A record logged before a westward flight
can read one day earlier afterwards — the same behaviour every calendar
app has, and one event never becomes two days on two screens.

**20. CAN UNIT CONVERSION CHANGE THE UNDERLYING TRUTH?**
No. kg is canonical; display rounds; `display → toKg` converges after one
step (~0.045 kg in lb, below every threshold that moves a target) and is
pinned by `WeightUnitTests.testRoundTripAcrossUnits`.

**21. CAN NETWORK FAILURE CREATE A THIRD STATE?**
No unrecoverable one. Every write is local-first with `pendingUpsert`;
deletion is gated on `AccountDeletionVerdict == .serverComplete`; the
handoff is one server transaction and the receipt is the retry state.

**22. CAN PROCESS DEATH CREATE A THIRD STATE?**
No. `AccountDeletionIntent` survives the sweep and finishes at launch;
`sync.pendingMergeV1` carries the id policy and is discharged only on a
commit; `reattributeModelRows` is one context and one `save()` and
reports whether it committed.

**23. DOES ACCOUNT DELETION REMOVE WHAT THE PRODUCT CLAIMS?**
Yes. 34 cascades, 0 storage objects, and the local sweep covers all 18
`@Model` families plus the JSONL journal and 94 keys. Retained:
de-identified metering, and an FK-less table holding **0 rows**.

**24. WHAT EXACTLY REMAINS OF SIGN IN WITH APPLE REVOCATION?**
Everything except the programmatic call. Jeni holds no
`authorizationCode`, no refresh token and no client secret, so it cannot
POST `appleid.apple.com/auth/revoke`. The sheet says so, to Apple
customers only, and never implies Jeni did the revoking. Data deletion
does not depend on it.

**25. DOES ANY PRIVILEGED RPC TRUST A CLIENT UID?**
No. `complete_account_handoff`'s `p_source_user_id` narrows a
server-computed set and cannot widen it; `delete_user_account()` takes no
arguments; every `care_*` function resolves the actor from `auth.uid()`.

**26. DOES ANY OLD DEAD SYSTEM STILL EXECUTE IN PRODUCTION?**
Not measurably. `37` removed the launch-time CBT manifest decode.
`CoachNoteService` and `RepEngine` have zero call sites and their
singletons are never instantiated. The one dead system that **did** still
execute — the plate-photo upload queue, walking a bucket that does not
exist, at every launch — is fixed.

**27. HOW MANY P0s REMAIN?** **0.**

**28. HOW MANY P1s REMAIN?** **1** — the E1 grant, written and
deliberately not applied.

**29. WHAT EXACTLY BLOCKS BUILD 31, IF ANYTHING?**
**Nothing.** One mechanical step the founder owns and `32` already named:
build 30 is accepted by ASC, so the archive must set
`CURRENT_PROJECT_VERSION = 31`.

**30. WOULD YOU SHIP THIS TO 10,000 PEOPLE TOMORROW?**
**Yes.**

---

## SCORECARD

| domain | score | the exact defect, where it is below 9 |
|---|---|---|
| DATA INTEGRITY | 8 | Program facts and weekly reads cannot reach the server at all; both tables hold 0 rows. |
| ACCOUNT ISOLATION | 9 | Two live leaks closed this pass. What keeps it off 10 is that isolation is a hand-maintained key list, and this pass found two more entries for it. |
| AUTH | 10 | |
| RESTORE | 7 | Photos, program facts, weekly reads, memory, transcript and MOVE do not come back. |
| SYNC | 8 | Insert-only hydrates plus a device-local ledger; a deletion cannot reach the second device. |
| DELETION | 9 | Complete against the live catalog. `care_weekly_summaries` has no FK — 0 rows, so latent. |
| PRIVACY | 9 | The served protocol crossed accounts until this pass; the class is closed, the audit method (a full key census) is now written down. |
| FOOD | 8 | Photographs have no destination and never had one. |
| WEIGHT | 9 | The P0 is fixed; the second-device resurrection remains. |
| PROGRAM | 9 | 8 accounts hold two live plans today; the client heals them on next launch. |
| TARGETS | 10 | |
| GLP-1 | 9 | Dose, symptom and regimen are complete and correction-capable; `med_hypo`'s cap is still not derivable after an account transition. |
| NON-GLP-1 | 10 | |
| JENI TRUTH | 9 | Every fact traces or is omitted; tool results report the local commit, and the cloud push is a retry, not a claim. |
| CLINICAL PROVENANCE | 9 | Refusals are correct; the served-protocol leak was the one gap and is closed. |
| SUBSCRIPTION | 10 | |
| NETWORK FAILURE | 9 | Everything is local-first and retried; a `.preserve` handoff can strand an anonymous period for up to 30 days. |
| PROCESS-DEATH RECOVERY | 10 | |
| LEGACY UPGRADE | 10 | No `@Model` changed since `1710180`; there is no store migration to fail. |
| ACCESSIBILITY | 9 | Every destructive and gate action is reachable at AX5 after `39`'s scroll fix; this pass did not re-film, so the claim rests on `39`'s measurement. |
| APP REVIEW READINESS | 10 | |

---

## FINAL RELEASE GATE

```
P0 REMAINING:                    0
P1 REMAINING:                    1   (E1 grant — written, not applied)
MIGRATIONS WRITTEN THIS PASS:    1   (docs/app_v25/44_packages/G1_e1_spine_grants.sql)
MIGRATIONS APPLIED THIS PASS:    0
PRODUCTION DATA MUTATIONS:       NONE
CURRENT_PROJECT_VERSION:         30
APP REVIEW READY:                YES
SAFE TO BUMP BUILD TO 31:        YES
SAFE TO ARCHIVE:                 YES
SAFE TO SUBMIT:                  YES
```

▎ **IF THIS BUILD WENT TO 10,000 PEOPLE TOMORROW, WHAT IS THE SINGLE
▎ MOST LIKELY THING I WOULD REGRET?**

Not shipping the E1 grant with it — and therefore learning, from ten
thousand people at once, that the spine the last eight passes were built
on has never once left the phone.
