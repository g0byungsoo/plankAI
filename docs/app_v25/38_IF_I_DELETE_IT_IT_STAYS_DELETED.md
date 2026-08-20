# IF I DELETE IT, IT STAYS DELETED

**Status: AUDIT COMPLETE + THREE CLIENT-ONLY FIXES BUILT. 2026-08-14.**

Not an era. Not a feature. Not a redesign. One invariant, asked of every
customer-owned byte the product holds:

> **IF THE CUSTOMER DELETES SOMETHING, JENI MUST NEVER SILENTLY
> RESURRECT IT.**
>
> **IF THE CUSTOMER DELETES HER ACCOUNT, JENI MUST NOT RETAIN
> CUSTOMER-OWNED DATA UNLESS THERE IS AN EXPLICIT, DOCUMENTED, LEGALLY
> REQUIRED RETENTION CONTRACT.**

`29`–`37` are frozen. No calorie formula, protein formula, merge
contract, plan selection, restore path, safety rule, payment, paywall,
auth flow, `AppPhase`, `Info.plist`, entitlement, analytics event or
HealthKit type moved. **No migration applied. No migration file written
to `supabase/migrations`. No Edge Function deployed. No production SQL
executed. No production row read or mutated. `CURRENT_PROJECT_VERSION`
is still 30.**

---

## 0 · THE ANSWER FIRST

**No — and the reason is not the one `37` named.**

`37` §17 called the biggest remaining architectural lie *"that deleting a
record deletes it"*, and pointed at a two-device food resurrection. That
is real, it is proven end to end below, and it is now closed **on the
device the customer is holding**.

But the census found **four deletion holes `37` did not have, and two of
them are larger than the one it did**:

| # | the hole | population | class |
|---|---|---|---|
| 1 | **`move.manual.v1` is in no sweep at all.** Every workout the customer typed into MOVE survives *sign-out* — so the next account on the phone sees her sessions — and survives *"delete my account"* on disk and in every device backup afterwards. | everyone who used MOVE | **P0 — cross-account leak AND deletion hole** |
| 2 | **A complete server-side copy of everything she recorded before signing in survives account deletion, permanently.** The app is anonymous-first; signing in with Apple mints a NEW uid; `delete_user_account()` scopes to `auth.uid()`; the pre-sign-in rows stay under the orphaned anonymous uid. There is a founder-run reaper script, unscheduled, on a 90-day window. The privacy policy says *"No soft-delete; the data is unrecoverable."* | **every customer who onboarded anonymously and then signed in** | **P0 — retention contradiction** |
| 3 | **Sign in with Apple tokens are never revoked.** The RPC's own header states this as intended behaviour. Apple has required `appleid.apple.com/auth/revoke` on account deletion since June 2022. | every Apple-signed-in customer | **P1 — App Store compliance** |
| 4 | `public.care_weekly_summaries` has no foreign key and no delete policy, so a clinic patient's weekly jsonb payloads orphan permanently. (`37` §16, confirmed from schema, unchanged.) | clinic-pilot patients | **P0 — privacy, migration-gated, legally blocked** |

And **one correction that makes the two-device picture smaller and
sharper than `37` drew it:**

> **Only FOOD resurrects. Weight, dose and symptom do not.** All four
> hydrates are insert-only, but only food has a **push-back-by-diff**
> (`pushLocalFoodEntriesMissingFromServer`, every launch, unconditional).
> Weight, dose and symptom leave the server and stay gone; what they
> leave behind is a **ghost on the other device** — a row that is deleted
> everywhere except on the phone that already had it, and which for
> weight is the numerator of both daily targets.

And **one correction that shrinks `37` §6's consent finding to a
different, smaller defect** — §13 below. `37` reported that a clinic
patient *"cannot withdraw, from a new phone, a consent the server still
honours."* The server never honoured that scope for anything: the local
`ConsentGrantRecord` writes `visit_packet_sharing`, and every server RPC,
RLS policy and publisher gates on `visit_packet_view`, which is created
and revoked entirely server-side and works from any device today. The
real defect is a **display lie plus duplicate grant rows**, and it is
fixed here.

**Built, all client-only, no schema:** the `move.manual` sweep · **THE
DELETION LEDGER** (a deletion is now a fact this device records, not an
absence it infers) · `hydrateConsentGrants`.

**Named, not built:** the anonymous-orphan retention contradiction (needs
a production audit, then a decision) · Apple token revocation (needs an
Edge Function + the team key) · `care_weekly_summaries` (needs a **legal**
decision before a migration can be written) · server tombstones (the only
thing that makes a delete propagate TO the other device).

---

## 1 · THE DELETION CENSUS

Every customer-owned persisted record. **ON DELETE BEHAVIOR is read from
the schema file that creates the table, never inferred from a comment.**

Legend — **L** local write · **S** server write · **D-L** local delete
surface · **D-S** server delete · **PUSH** how it reaches the server ·
**HYD** how it comes back · **RES?** can it be resurrected.

### 1.1 · THE SYNCED CORE

| ENTITY | LOCAL MODEL | SERVER TABLE | PK | USER FK | ON DELETE | LOCAL DELETE | SERVER DELETE | SYNC PUSH | HYDRATE | MERGE POLICY | DELETION REPRESENTED AS | RES? | ACCOUNT-DELETE RESULT | VERDICT |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **food entry** | `FoodLogPersister` JSONL (`Entry`) | `public.food_logs` | `id` text | `user_id` → `auth.users` | **CASCADE** | `deleteEntry(id:)` | `deleteFoodLog` (RLS `delete_own`) | write-time upsert **+ `pushLocalFoodEntriesMissingFromServer` every launch, by set difference** | `fetchFoodLogs` → `mergeRemote` | **insert-only by id** | **absence** | **YES** | local JSONL wiped + cascade + bucket DELETE in RPC | **RESURRECTS — §3** |
| food photo | `FoodPhotoStore` (local file) | `storage.objects` `food-photos/{uid}/{entryId}.jpg` | object name | owner (SET NULL) | **no cascade** | deleted with the entry | `deleteRemotePhoto` | queue + retry | `hydrateMissingPhotos` | by presence | absence | follows the entry | **explicit DELETE by uid prefix + owner in the RPC** | SAFE |
| **weigh-in** | `WeightLogRecord` | `public.weight_logs` | `id` text | `user_id` → `auth.users` | **CASCADE** | `ChatToolRouter.remove` | `deleteWeightLog` | `pendingUpsert` sweep | `applyHydratedWeightLogs` | **insert-only by id** | **absence** | **partly** | swept + cascade | **GHOST ON THE OTHER DEVICE — §4** |
| weigh-in (Health-sourced) | same | same | same | same | CASCADE | same | same | **also re-created by `BodyMassImportService.importRecent` (30-day window, NEW id)** | same | insert-if-no-row-that-day | absence | **YES, and the app says so** | same | **DISCLOSED — §4.4** |
| **dose event** | `DoseEventRecord` | `public.dose_events` | `id` text (**deterministic per slot**) | `user_id` → `auth.users` | **CASCADE** | `DoseEventStore.delete` | `deleteDoseEvent` | `pendingUpsert` sweep | `hydrateDoseEvents` | **insert-only by id** | **absence** | no | `ObservationStore.deleteAll` + cascade | **GHOST — §4** |
| **symptom / observation** | `ObservationRecord` | `public.observations` | `id` text (**deterministic per kind×day**) | `user_id` → `auth.users` | **CASCADE** | `ObservationStore.delete` / `deleteSingular` | `deleteObservation` | `pendingUpsert` sweep | `hydrateObservations` | **insert-only by id** | **absence** | no | `deleteAll` + cascade | **GHOST — §4** |
| program plan | `ProgramPlanRecord` | `public.program_plans` | `id` uuid | `user_id` → `auth.users` | **CASCADE** | none (superseded, never deleted) | none | `pendingUpsert` sweep | `ProgramPlanMerge` (`31`) | dirty⇒local, clean⇒adopt | n/a | n/a | swept + cascade | SAFE |
| program day check | `ProgramDayCheckRecord` | `public.program_day_checks` | `id` | `user_id` + `program_plan_id` | **CASCADE ×2** | none | none | sweep | insert-only | n/a | n/a | n/a | swept + cascade | SAFE |
| program fact | `ProgramFactRecord` | `public.program_facts` | `id` | `user_id` → `auth.users` | **CASCADE** | none (superseded chains) | none | sweep | `hydrateProgramFacts` | insert-only | n/a | n/a | swept (`37`) + cascade | SAFE |
| weekly read | `WeeklyReadRecord` | `public.weekly_reads` | `id` | `user_id` → `auth.users` | **CASCADE** | none | none | sweep | `hydrateWeeklyReads` | insert-only | n/a | n/a | swept (`37`) + cascade | SAFE |
| regimen plan | `RegimenPlanRecord` | `public.regimen_plans` | `id` | `user_id` → `auth.users` | **CASCADE** | none (version chains) | none | sweep | `hydrateRegimenPlans` | insert-only | n/a | n/a | swept + cascade | SAFE |
| session log | `SessionLogRecord` | `public.session_logs` | `id` | `user_id` → `auth.users` | **CASCADE** | none | none | sweep | `hydrateFromCloud` | insert-only | n/a | n/a | swept + cascade | SAFE |
| day progress | `DayProgressRecord` | `public.day_progress` | composite | `user_id` → `auth.users` | **CASCADE** | none | none | sweep | insert-only | insert-only | n/a | n/a | swept + cascade | SAFE |
| session rating | `SessionRatingRecord` | `public.session_ratings` | `id` | `user_id` → `auth.users` | **CASCADE** | none | none | sweep (joins via session) | insert-only | insert-only | n/a | n/a | swept via session ids + cascade | SAFE |
| exercise calibration | `ExerciseCalibrationRecord` | `public.exercise_calibrations` | `id` | `user_id` → `auth.users` | **CASCADE** | none | none | — | — | — | n/a | n/a | swept + cascade | SAFE |
| profile row | `UserRecord` | `public.users` | `id` uuid = `auth.users.id` | **PK is the FK** | **CASCADE** | none | none | `upsertUser` (whole row) | `hydrateUser` + `restoreBodyDefaults` | clean-record guard | n/a | n/a | swept + cascade | SAFE |
| day reflection | `UserDefaults day.reflection.*` | `public.day_reflections` | `id` | `user_id` → `auth.users` | **CASCADE** | none | none | `upsertDayReflection` | `hydrateDayReflections` | restore-if-missing | n/a | n/a | **prefix-swept** + cascade | SAFE |
| **consent grant** | `ConsentGrantRecord` | `public.consent_grants` | `id` text | `user_id` → `auth.users` | **CASCADE** | none (revoke = `revoked_at`) | **no delete policy, by design** | `upsertConsentGrant` | **NONE → `hydrateConsentGrants` (built here)** | — | `revoked_at` timestamp | n/a | swept + cascade | **WAS DISPLAY-ONLY — §13** |
| body scan | `BodyScanRecord` + `BodyScanPhotoStore` | opt-in `storage.objects` `body-scans/{uid}/…` | `id` | owner (SET NULL) | **no cascade** | `BodyScanStore.delete` | `deleteAllRemote` | opt-in only | none (local by design) | n/a | absence | **cannot — local only** | pre-RPC purge + **explicit DELETE in the RPC** | SAFE — §15 |
| **jeni memory** | `JeniMemoryRecord` | **none** | `id` | n/a | n/a | `forget` / `forgetAll` | n/a | **none** | none | n/a | row removal | cannot | **swept (`37`)** | LOCAL ONLY |
| chat transcript | `ChatMessageRecord` | `public.coach_messages` — **zero client references, re-verified** | `id` | `user_id` → `auth.users` | CASCADE | `deletePersisted` | n/a | none | none | n/a | row removal | cannot | swept + (empty) cascade | LOCAL ONLY — §4B of `37` |
| **manual movement** | `UserDefaults move.manual.v1` | **none** | `id` in blob | n/a | n/a | `MoveManualStore.delete(id:)` | n/a | none | none | n/a | array removal | cannot | **✗ NOT SWEPT → ✓ FIXED §18.1** | **WAS A P0 HOLE** |

### 1.2 · TELEMETRY, CARE AND OPS — the tables that are NOT hers, and the ones that are

| TABLE | USER COLUMN | FK / ON DELETE | ACCOUNT-DELETE RESULT | VERDICT |
|---|---|---|---|---|
| `public.food_vision_telemetry` | `user_id` | `references auth.users on delete **set null**` | row survives, **de-identified** | **STATED CHOICE** — anonymisation, not retention |
| `public.jeni_chat_telemetry` | `user_id` | `on delete **set null**` | same | STATED CHOICE |
| `public.visit_packets` | `user_id` | CASCADE, **and a delete policy**, **and** `care_revoke_consent` deletes them on revoke | gone | **BEST IN THE SCHEMA** |
| `public.org_members` · `care_relationships` · `protocol_assignments` · `correction_requests` | `user_id` / `patient_id` | CASCADE | gone | SAFE |
| **`public.care_weekly_summaries`** | `user_id uuid not null` | **NO REFERENCES. NO CASCADE. NO DELETE POLICY.** | **a week of her record, orphaned permanently** | **P0 — §10** |
| `public.care_audit_events` | `patient_id uuid` | **no FK** (`org_id`/`actor_id` also bare) | audit trail survives | **arguably correct, but omitted rather than decided** — §10 |
| `private.invitation_attempts` | `user_id uuid not null` | no FK | rate-limit rows survive | acceptable (no health content); named |
| `public.ops_events` | `actor_id uuid` | no FK | survives | operational; no health payload; named |
| `public.pilot_requests` | `email`, `name`, `clinic` | no user at all | n/a — clinician inbound, not a customer record | out of scope |
| `public.protocols` · `protocol_items` · `organizations` · `exercise_bank` · `canonical_pantry` · `jenimethod_lessons` | — | — | n/a | reference/tenant data, not customer-owned |
| `public.food_log_items` · `public.food_corrections` | `user_id` | CASCADE | gone | **no client writer** — the item ledger rides `food_logs.payload` jsonb (re-verified: zero references in `PlankApp/`, `Packages/`, `supabase/functions/`) |
| `public.coach_messages` | `user_id` | CASCADE | gone (always empty) | **FALSE CONTRACT** — RLS + grants + zero writers. `37` §4B recommends deleting it; re-confirmed here. |

### 1.3 · THE DEVICE-ONLY FAMILIES — the census the sweep is measured against

Every `UserDefaults` family that holds something the customer produced,
against the two sweeps: **SIGN-OUT** (`clearOnboardingUserDefaults`, also
run by account deletion) and **ACCOUNT DELETE** (`clearLocalUserRecords`
+ the same sweep).

| KEY / PREFIX | WHAT IT HOLDS | CUSTOMER-AUTHORED? | SWEPT | VERDICT |
|---|---|---|---|---|
| **`move.manual.v1`** | **every workout she typed: kind, minutes, date** | **YES** | **✗ → ✓ FIXED** | **WAS P0** |
| `onb_v5_*` · `onb_med_*` · `safety_*` · `bodyScan.*` | consult answers, medication intake, safety-gate verdicts, scan prefs | yes | ✓ prefix | SAFE |
| `day.note.*` · `day.reflection.*` · `day.sit.*` · `day.dose.*` | her evening words, sit-checks, dose marks | **yes (free text)** | ✓ prefix | SAFE |
| `plan.*` · `review.*` · `presence.*` · `break.*` · `band.*` · `observations.*` | consented knobs, presence ledger, settle band | yes | ✓ prefix | SAFE |
| `onboarding*` · `onb_fear_*` · `onb_v8_door` / `_clinic_org` / `_code_path` | body facts, fears, clinic fork | yes | ✓ explicit | SAFE |
| `foodDailyTarget` · `foodDietaryPattern` · `foodExclusionsCSV` · `foodPhotoRetention` · `foodAIConsent*` | food prefs + AI consent | yes | ✓ explicit | SAFE |
| `method.ledger.v1` | which Method notes fired and when | no (behavioural) | **✗** | **P2 named** — the next identity on this phone inherits the previous one's once-ever cooldowns |
| `brain.ledger.v1` | notification budget + engagement counters | no (behavioural) | **✗** | **P2 named** — same shape |
| `notificationHour` / `notificationMinute` | her reminder time | yes (a preference) | **✗** | **P2 named** — restored from `users.onboarding_notification_*` for her own account; leaks to the next |
| `coach_notes_v1` | weekly LLM coach notes | would be free text | **✗** | **INERT** — `CoachNoteService` has **zero production call sites**; nothing writes it |
| `onb_food_cuisines` | cuisine preferences | yes | **✗** | **INERT** — read in one place, **written nowhere** |
| `e5.firstPlate.*` | proof-phase funnel state | no | ✗ | inert (`e5.firstPlate.enabled` is false) |
| `careProtocol.served.v1` | the care team's served protocol | no (clinic config) | ✗ | **P2 named** — a clinic protocol cached past the connection; re-fetched every launch, so it is stale-only |
| `weightUnit` · `heightUnit` · volumes · display prefs | device preferences | n/a | ✗ **by design** (`31` §18 G) | BY DESIGN |
| `PaymentService.*` · `analytics.*` | entitlement residue, analytics identity | n/a | ✓ via `clearDeviceEntitlementResidueForSignOut` + `Analytics.resetIdentity()` | SAFE |
| **`deletions.v1.<uid>` [NEW]** | **the deletion ledger** | derived from her deletes | **cleared on ACCOUNT DELETE ONLY, never on sign-out** | **§5** — sweeping it at sign-out would re-open every resurrection |

---

## 2 · EVERY DELETE VERB, CLASSIFIED

Repository-wide sweep for `delete` · `remove` · `forget` · `clear` ·
`reset` · `archive` · `abandon` · `signOut` · account deletion.

| OPERATION | CLASS | CUSTOMER-FACING BUTTON |
|---|---|---|
| `FoodLogPersister.deleteEntry(id:)` → `onEntryDeleted` → `SyncService.deleteFoodLog` | **REAL DELETE** (local + server) | THE BOOK · plate detail — *remove* |
| `ChatToolRouter.remove(id:userId:)` → `deleteWeightLog` | **REAL DELETE** | your weigh-ins — *remove this weigh-in* |
| `ObservationStore.delete` / `deleteSingular` → `deleteObservation` | **REAL DELETE** | the symptoms — *clear* |
| `DoseEventStore.delete(dayKey:)` → `deleteDoseEvent` | **REAL DELETE** | dose sheet — *unmark* |
| `JeniMemoryStore.forget(id:)` / `forgetAll` | **LOCAL-ONLY DELETE** (there is no server row) | Settings › what jeni remembers — *forget* |
| `MoveManualStore.delete(id:)` | **LOCAL-ONLY DELETE** | MOVE sheet — swipe |
| `ChatSession.deletePersisted(id:)` | **LOCAL-ONLY DELETE** | failed-turn retry (not a user delete) |
| `BodyScanStore.delete(_:)` + `BodyScanPhotoStore.delete` | **REAL DELETE** (local; remote only if backup on) | body scan detail |
| `ConsentService.revoke` | **STATE TRANSITION** (`revoked_at`, never a row delete) | *turn sharing off* |
| `CareConnectionService.revoke(orgId:disconnect:)` | **STATE TRANSITION + REAL DELETE** (revokes grants **and** deletes `visit_packets`) | Settings › care connection — *disconnect* |
| `ProgramFactStore` end/supersede | **STATE TRANSITION** (authority chains) | via chat / the weekly read |
| `RegimenService.applySelfRegimen` | **STATE TRANSITION** (append-only version chain) | the regimen home |
| `AppSync.clearOnboardingUserDefaults` | **ACCOUNT ISOLATION SWEEP** | sign out **and** delete account |
| `AppSync.clearLocalUserRecords` | **REAL DELETE** (every user-scoped local family) | delete account |
| `AppSync.deleteCurrentAccount` | **REAL DELETE** (server RPC + local) | Settings › account › delete account |
| `PaymentService.clearDeviceEntitlementResidueForSignOut` | **CACHE CLEAR** | sign out |
| `NutritionCache.clear` · `FoodCameraManager.clearFrozenFrame` · `SnapResultMath.reset*` | **CACHE CLEAR** / in-flight edit state | none |
| `FoodLogPersister.deleteAllEntriesForAllUsers` · `MethodLedger.wipe` · `MoveManualStore.wipe` · `*.resetForTesting` | **DEBUG DOOR** | none — `#if DEBUG` / QA-arg gated |

**The label test.** Every customer-facing word that says the record is
gone — *remove* · *clear* · *unmark* · *forget* · *delete account* —
maps to a REAL DELETE or a LOCAL-ONLY DELETE of a record that has no
server row. **No customer-facing button is a soft delete, an archive, or
a hide.** The failure was never a mislabelled verb; it was that a real
delete could be undone by a heal.

---

## 3 · THE RESURRECTION, REPRODUCED

Traced through the actual functions, in order, with line numbers.

```
DEVICE A                                    SERVER              DEVICE B (stale)
────────────────────────────────────────────────────────────────────────────────
persist(F)                              →   food_logs: F    →   mergeRemote([F]) → F local
FoodLogPersister.deleteEntry(F)
  AppSync:1103 deleteFoodLog
  SyncService:2203 DELETE .eq(id)       →   food_logs: —        F still local (insert-only)
                                                                AppSync.onLaunch:168
                                                                  pushLocalFoodEntriesMissing…
                                                                  AppSync:1131 allSyncableEntries → [F]
                                                                  AppSync:1133 fetchFoodLogIds  → { }
                                            food_logs: F    ←   AppSync:1135 upsertFoodLog(F)
hydrateAndSync:467 hydrateFoodLogs
  AppSync:1155 fetchFoodLogs → [F]
  FoodLogPersister:316 mergeRemote
    F not in localIds → INSERT           ←   F                   F still local
F IS BACK ON A.
```

**Every step is unconditional except the last.** `AppSync.onLaunch:168`
runs `pushLocalFoodEntriesMissingFromServer` on **every launch, for every
user, anonymous identities included** — so the **server** row returns
within one launch of device B, always. The return **to A's screen** is
gated by `shouldHydrateOnLaunch` (`AppSync:1788`), which fires when any
synced family is locally empty — **always true on a reinstall or a new
phone**, and true for any account with an empty family that day.

This is a refinement of `37` §15, which called the whole chain "the
steady state": the server half is the steady state; the screen half is
gated, and **certain on reinstall**.

**The customer promise the test has to make, and does:**
`testAPlateDeletedOnThisPhoneNeverComesBackToThisPhone` — not
`testTombstoneRecorded`.

---

## 4 · IT IS NOT ONLY FOOD — but only food resurrects

The same conceptual test run against every synchronised mutable record.

| RECORD | CAN B RECREATE A ROW A DELETED? | WHY |
|---|---|---|
| **FOOD** | **YES** | `pushLocalFoodEntriesMissingFromServer` pushes by **set difference**, not by `pendingUpsert`. B cannot tell "never uploaded" from "deleted elsewhere". |
| **WEIGHT** | **NO** (server) / **YES** (B's own screen, forever) | B's hydrated row carries `pendingUpsert == false`, and `retryPendingUpserts` (`SyncService:578`) only pushes `true`. Nothing pushes it back. **But `applyHydratedWeightLogs` is insert-only, so B keeps the row.** And if B *edits* that ghost, `ChatToolRouter.update` sets `pendingUpsert = true` and **the row returns to the server**. |
| **DOSE** | **NO** | Same shape. Ids are deterministic per slot, so a later legitimate re-mark reuses the id — a re-creation, not a resurrection. |
| **SYMPTOM** | **NO** | Same shape. Ids are deterministic per kind × day. |

### 4.1 · Can stale A overwrite an edit made on B?
**Yes, at row granularity, and that is the documented contract** (`37`
§15): last write to reach the server wins. A goal edited offline three
days ago beats one edited online five minutes ago. Unchanged here.

### 4.2 · Can DELETE beat UPDATE? Can UPDATE beat DELETE?
**Before this build: whichever reached the server last, with no memory.**
A deletes F; B edits F; B's upsert re-creates the row with B's numbers.
**After this build, on the deleting device: DELETE WINS, permanently.**
The ledger is consulted after every hydrate, so a re-created row is
removed again and the server delete is re-asserted. This is a deliberate
rule and it is written down: **a deletion is a decision about whether the
record exists; an edit is a decision about what it says. The first
outranks the second.**

### 4.3 · Both offline · timestamps tie · after reinstall · after 30 days

| SCENARIO | BEFORE | AFTER (this build) |
|---|---|---|
| both devices offline, then both reconnect | last to reconnect wins; delete usually loses | delete wins on the deleting device; server flaps until B updates or the tombstone migration lands |
| timestamps tie | irrelevant — **there is no `updated_at` the client reads on any of these tables** | unchanged; the ledger does not use time to decide, only membership |
| **after reinstall of the deleting device** | the row returns | **the row returns** — the ledger is device-local. **THIS IS THE RESIDUAL HOLE, and it is exactly what a server tombstone fixes.** §5 |
| after 30 days | no change — nothing expires | ledger entries do not expire; capped at 2,000 per account, oldest evicted (§7) |

### 4.4 · The one single-device resurrection, and it is disclosed

`BodyMassImportService.importRecent` (`:186`) inserts a **new**
`WeightLogRecord` with a **fresh id** for any day in the last 30 that has
an Apple Health body-mass sample and no local row. So a customer who
removes a Health-sourced weigh-in gets it back on the next launch, on the
**same** device, with no second phone involved.

**It is not a lie, and it is not silent.** `WeightLedger.removalNote`
renders, on the removal confirmation itself:

> *"this one came from apple health. taking it out here doesn't take it
> out there, **and a later sync can bring it back**."*

**Deliberately not "fixed".** The ledger is keyed by **id**, and the
importer mints a new id, so the ledger leaves this behaviour exactly as
the copy describes. Suppressing it would need a day-keyed tombstone and a
copy change on a frozen candidate, and the honest version of that rule
("a day you removed never receives an automatic import again") is a
product decision, not a correctness one. **Named, sized, offered, not
taken.**

---

## 5 · THE DELETION CONTRACT, IN ENGLISH FIRST

**The defect stated exactly:** *deletion is represented as absence, and
absence is ambiguous.* A row that is not there may mean

1. it never existed,
2. it has not hydrated yet,
3. the write failed,
4. **it was deleted somewhere else.**

Three heals exist to fix (2) and (3), and each one resolves the ambiguity
**against** (4):

| heal | reads absence as | resurrects |
|---|---|---|
| `pushLocalFoodEntriesMissingFromServer` | "the server never got it" | the server row |
| `BodyMassImportService.importRecent` | "never imported" | a local row (new id) |
| `mergeRemote` / `applyHydratedWeightLogs` / `hydrateObservations` / `hydrateDoseEvents` | "I don't have it yet" | the local row |

So the contract must make CREATE, UPDATE and **DELETE** all durable
facts:

> **A DELETION IS A FACT THIS DEVICE RECORDS, NOT AN ABSENCE IT INFERS.**

### The four options, against THIS architecture

| | **A · SERVER TOMBSTONE** (`deleted_at` or a `deletions` table) | **B · VERSIONED ROWS** | **C · CHANGE LOG** | **D · LOCAL DELETION LEDGER** (existing mechanism: `UserDefaults` + the existing hydrate chokepoints) |
|---|---|---|---|---|
| migration | **required** | required + rewrites every write path | required + a new table + a cursor per device | **NONE** |
| old-client (build 30) read | **BROKEN** — `fetchFoodLogs` is `.select()` with no filter, so build 30 hydrates soft-deleted rows | broken | safe (it ignores the log) | safe (build 30 unaffected) |
| old-client write | **safe** — PostgREST upsert only sets the columns it sends, so build 30 re-pushing a soft-deleted row leaves `deleted_at` set | safe | build 30 writes no log entries ⇒ its deletes are invisible | build 30 keeps resurrecting; the new client re-deletes |
| offline edits | fine | fine | fine | fine |
| two-device | **solves it fully** | solves it | solves it | **solves it on the deleting device only** |
| storage growth | one row/col per deletion, forever | every version of every row | unbounded log + compaction policy | ~60 bytes per deletion, device-local |
| query complexity | every read gains `deleted_at is null` — **8 read paths** | high | a cursor per device per family | **zero server queries** |
| RLS | new policies on every table | new policies | a new table's full policy set | none |
| account deletion | cascades | cascades | cascades | cleared with the account |
| rollback | `drop column`, but any client filtering on it breaks | very hard | drop table | delete a defaults key |
| eventual cleanup | needs a policy (or never) | needs a policy | needs compaction | capped, evict-oldest |
| SwiftData complexity | none (server-side) | high | medium | **none — no `@Model` changes at all** |

### The finding

**A server tombstone is the correct END STATE, and it is NOT the smallest
correct thing to do first — because it cannot ship alone.** Its read half
requires every hydrate to filter `deleted_at is null`, which means build
30 (which does not filter) would *hydrate soft-deleted rows*. So option A
needs a client release before the migration, which is the same ordering
gate `37` §8 identified for the food-vision EF and `31` §21 for the
`users` upsert. **Migration-first is wrong here; client-first is
mandatory.**

**Option D closes the customer's actual question with zero migration,
zero deploy, zero schema, zero `@Model` change and zero server read
change** — and it is a *prevent-an-insert* mechanism, so its worst-case
failure is that a deletion is not honoured, never that data is destroyed.

> **CHOSEN: D now, A next, and D is not thrown away when A lands** — the
> ledger is what makes the deleting device correct *before* the migration
> and *for old servers*, and it is what makes `deleted_at` enforceable on
> a device that pushed the delete while offline.

**Rejected, and why, so nobody re-proposes them:**

- **B, versioned rows.** The product already keeps version chains where
  they earn their place (`RegimenPlanRecord`, `ProgramFactRecord`). A
  weigh-in is not a chain; it is a number on a day. Versioning it
  multiplies every read for one bit of information.
- **C, change log.** A per-device cursor is a device registry, and §7 is
  explicit that there is no reliable one. Building it to serve deletion
  is the largest possible answer to the smallest question.
- **A local list on the deleting device only helps the deleting device.**
  True (`37` §15 says so) — **and the deleting device is the phone the
  customer is holding when she asks the question.** `37` treated that as
  a reason to do nothing; it is the reason to do this first.

### The mechanism, exactly

```
DeletionLedger                        UserDefaults "deletions.v1.<uid>"
  record(id, userId)      at every real delete, before the network call
  supersede(id, userId)   when the SAME id is legitimately re-created locally
                          (dose slots and symptom days have deterministic ids)
  contains(id, userId)    the predicate
  sweep(userId, context)  after every hydrate: any local row whose id is
                          tombstoned is deleted again AND the server delete
                          is re-asserted
  clear(userId)           account deletion only — NEVER the sign-out sweep
```

**Why `supersede` is not optional.** Dose events and symptoms use
deterministic ids (`user × slot`, `user × kind × day`). Without it, a
customer who unmarks a dose and then marks it again could never see that
slot hydrate on another device — the ledger would refuse her own new
record. It is wired at the write chokepoints, not at the call sites.

**Why the sweep re-asserts the server delete.** It is the only way the
deletion propagates outward at all before tombstones exist: the deleting
device re-deletes the row every time a stale device pushes it back. It
flaps until device B updates. **Stated, not dressed up.**

---

## 6 · THE OLD CLIENT PROBLEM

Build 30 is live. It knows nothing about deletion metadata, and it never
will.

|  | **CURRENT SERVER CONTRACT** (today, and after this build) | **SERVER-TOMBSTONE CONTRACT** (option A, not applied) |
|---|---|---|
| **BUILD 30 · CREATE** | SAFE | SAFE — insert, `deleted_at` defaults null |
| **BUILD 30 · UPDATE** | SAFE | SAFE — upsert sets only the columns it sends, so a tombstone is **not** cleared |
| **BUILD 30 · DELETE** | SAFE — a hard DELETE; new clients see the row gone | **DEGRADED** — a hard DELETE where the new contract expects a soft one, so no tombstone is recorded and a stale device can still resurrect it |
| **BUILD 30 · HYDRATE** | SAFE | **RESURRECTION** — `.select()` with no `deleted_at is null` filter, so build 30 pulls soft-deleted rows back onto its own screen |
| **BUILD 31 · CREATE** | SAFE | SAFE |
| **BUILD 31 · UPDATE** | SAFE | SAFE |
| **BUILD 31 · DELETE** | SAFE — hard DELETE **plus a local tombstone** | SAFE — soft delete + local tombstone |
| **BUILD 31 · HYDRATE** | SAFE — **the ledger removes anything a stale device pushed back** | SAFE — filtered read **and** the ledger |

**Two conclusions, both load-bearing:**

1. **This build's fix is old-client-safe in every cell.** Nothing about
   the server contract changes, so build 30 behaves exactly as it does
   today. The only asymmetry is that a build-30 device keeps pushing back
   rows a build-31 device deleted, and the build-31 device keeps removing
   them. **The customer's phone is right; the network is noisy.**
2. **A tombstone migration must NOT be applied before a client that
   filters on it has reached the installed base** — otherwise build 30
   turns every deletion into a resurrection **on the deleting device
   itself**, which is strictly worse than today. That is the single most
   important sentence in this document for whoever approves the
   migration.

**Can old clients resurrect rows after this fix? YES — on their own
screen, and briefly on the server.** That is stated in §21 rather than
hidden: a deletion fix bounded by adoption is still a deletion fix for
the device in her hand, and this one requires no coordination to ship.

---

## 7 · TOMBSTONE LIFETIME

**How long must deletion metadata survive?** Until nothing can resurrect
the record. Since there is **no reliable registry of a customer's
devices** — and building one to serve deletion would be the largest
possible answer to the smallest question — the honest answer is **for the
lifetime of the account**.

**No acknowledgement system was invented.** It was considered and
rejected: it needs a device table, a per-device cursor, a liveness
policy, and a decision about a phone that is thrown in a river.

**The cost, quantified.** A ledger entry is one lowercased uuid string +
an epoch double ≈ **60 bytes**.

| population | deletions each | rows | storage |
|---|---|---|---|
| 10,000 users | 20 | 200,000 | **12 MB** (server-side equivalent) / 1.2 KB per device |
| 100,000 users | 20 | 2,000,000 | **120 MB** |
| 1,000,000 users | 50 | 50,000,000 | **3 GB** |

A million users deleting fifty things each is three gigabytes of
Postgres, which is a rounding error against the food photos those same
users store. **The cost is trivial and correctness wins.** No cleanup
policy is proposed for the server tombstone; a cleanup policy is a second
way to resurrect a record.

**The device-side cap is 2,000 entries per account, oldest evicted.** For
context, `MoveManualStore` caps at 400 and the whole food corpus of a
two-year daily logger is roughly 2,000 plates. The eviction is stated
rather than hidden: **a customer who deletes more than two thousand
records on one device can, in principle, see the two-thousand-and-first
oldest deletion resurrect from a stale device.** That is the honest
boundary of a device-local mechanism, and it is another argument for the
server tombstone as the end state.

---

## 8 · CORRECTION VS DELETION — every correction path audited

The rule: **a correction must remain the SAME record.** Delete-plus-
recreate interacts badly with tombstones and with stale devices.

| CORRECTION | PATH | ID PRESERVED? | EVIDENCE |
|---|---|---|---|
| a plate's numbers (fix with words) | `SnapRefineMerge` → `persist` on the same entry | **YES** | `corrections` accumulate on the entry |
| **a plate's day** | `FoodLogPersister.setLoggedDay` | **YES** — `id: existing.id` is named explicitly, and the comment says why: *"the cloud row is keyed by id, so this is an UPDATE of `logged_at` — no migration, no second row"* | `:1074` |
| **a weigh-in's number** | `ChatToolRouter.update` | **YES** — *"The id, the day and the user are untouched — it is the same weigh-in, with the number she meant."* | `:319` |
| **a dose slot** | `DoseSheet` → `MedicationLog.resolve(slotDayKey:)` | **YES** — the id is **deterministic** from `user × slot`, so a correction is an upsert onto the same row by construction | `DoseEventStore.deterministicId` |
| **an injection site** | same record, `site` field | **YES** | same |
| **a symptom's day / severity** | `SideEffectLog.record(dayKey:)` | **YES for severity** (deterministic id per kind × day); **a DAY change is a delete + a create, and correctly so** — the id encodes the day, so moving a symptom from Tuesday to Wednesday is genuinely a different record | `SideEffectLog.id(userId:symptom:dayKey:)` |
| **repeat a meal ("again")** | `FoodLogPersister.relog` | **NEW id, deliberately** — a second plate on a second day is not a correction | `:948` |
| **the sign-in merge** | `reattributeEntries` / `applyReattribution` | **NEW id, deliberately** — *"the cloud row already exists under the old uid, so a same-id upsert is an UPDATE that RLS rejects"* | `:1150` |

**Result: every correction the customer can perform preserves record
identity, with two documented exceptions that are not corrections** (a
repeat, and a re-key). The symptom-day case is a genuine delete + create
and the ledger's `supersede` covers it: the new day's id was never
tombstoned, and if she moves it back, the write chokepoint clears the old
tombstone.

---

## 9 · ACCOUNT DELETION, STEP BY STEP

`Settings › account › delete account` →
`DeleteAccountSheet` → `AppSync.deleteCurrentAccount()`.

| # | STEP | CODE | RESULT |
|---|---|---|---|
| 1 | confirmation sheet | `DeleteAccountSheet` | typed confirmation |
| 2 | **opt-in body-scan cloud copies purged FIRST, awaited** | `BodyScanSyncService.deleteAllRemote` | needs a living `auth.uid()` for the storage RLS — the ordering is deliberate and commented |
| 3 | server RPC | `AuthService.deleteAccount()` → `public.delete_user_account()` | **throws ⇒ the whole thing aborts and nothing local is touched** |
| 3a | RPC: storage purge | `DELETE FROM storage.objects WHERE bucket_id IN ('food-photos','body-scans') AND (name LIKE uid||'/%' OR owner = uid)` | both buckets, by prefix **and** owner |
| 3b | RPC: `DELETE FROM auth.users WHERE id = auth.uid()` | cascade | every table with `references auth.users(id) on delete cascade` |
| 3c | **NOT deleted by 3b** | — | **`care_weekly_summaries` (no FK)** · `care_audit_events` (no FK) · `invitation_attempts` (no FK) · `ops_events` (no FK) · telemetry (`set null`, deliberate) · **everything under a prior anonymous uid (§9.1)** |
| 4 | local SwiftData sweep | `clearLocalUserRecords(userId:in:)` | sessions · ratings · day progress · `UserRecord` · calibrations · observations · regimen plans · dose events · body scans + their JPEGs · weight logs · plans · day checks · chat · consent grants · **jeni memory · program facts · weekly reads** (`37`) · **the deletion ledger [NEW]** · the food JSONL + its photos |
| 5 | UserDefaults sweep | `clearOnboardingUserDefaults()` | ~90 explicit keys + 18 prefixes + **`move.manual.v1` [NEW]** |
| 6 | notifications | `RetentionNotifications.cancelAll()` · `TrialEndNotificationService.cancelAllTrialReminders()` · the ladder / legacy / JITAI / re-signing ids | no stray push to a deleted account |
| 7 | payment residue | `PaymentService.clearDeviceEntitlementResidueForSignOut()` | `wasEverEntitled` + cached entitlement cleared so the next account is not silently entitled |
| 8 | analytics identity | `Analytics.resetIdentity()` | posthog-ios ignores `identify()` with a new distinct id until `reset()` |
| 9 | keychain / session | `AuthService.signOut()` → SDK clears the session, bootstraps a fresh anonymous identity | **does not rethrow** — the account IS deleted; a failed sign-out self-heals next launch |
| 10 | routing | `hasCompletedOnboarding` swept ⇒ `RootView` → welcome | fresh-device-equivalent, unauthenticated-equivalent |

### 9.1 · THE STEP THAT IS MISSING — P0

`delete_user_account()` scopes to `auth.uid()`. The app is
**anonymous-first**: a customer onboards, logs food, weighs in and builds
a plan under an anonymous uid, then signs in with Apple. That exchange
mints a **different** uid — which is why `AppSync` carries
`writePendingMergeMarker`, `reattributeLocalRows` and
`FoodLogPersister.reattributeEntries`, and why the latter says in so many
words: *"the cloud row already exists under the old uid, so a same-id
upsert is an UPDATE that RLS rejects (auth.uid() != the row's old
user_id)"*.

The merge re-keys the **local** rows and pushes fresh copies. **The old
server rows are never deleted, and cannot be — the client no longer holds
a credential that can reach them.**

`scripts/cleanup_orphaned_anon_users.sql` says this out loud:

> *"Those orphans survive account deletion (delete_user_account only
> scopes to the CALLING uid) and accumulate forever."*

It is a **founder-run, dry-run-first, 90-day-window maintenance script**
that is *"NOT WIRED TO ANYTHING"*. So the guarantee a customer is given
today is: *your pre-sign-in health data is deleted whenever someone
remembers to run a SQL file, and no sooner than 90 days.*

Meanwhile `AuthService.signInWithApple`'s own doc comment claims the
opposite — *"this preserves the user_id when called from an anonymous
session — the anonymous account links to the Apple identity rather than
getting replaced"* — which is contradicted by the entire merge machinery
built around it. **A false contract in a comment, on the auth path.**

**Not fixed here.** The fix is either (a) an RPC change so the client can
hand the deletion its prior uids, which needs a trustworthy record of
those uids and is a migration + a security review, or (b) scheduling the
reaper, which is an ops decision. **It needs the production audit in §16
first: the count is unknown, and it may be very large.**

---

## 10 · `care_weekly_summaries` — P0 PRIVACY, AND IT IS BLOCKED ON A LEGAL ANSWER

### Inspected, not assumed

| question | answer |
|---|---|
| **schema** | `id text pk · user_id uuid not null · org_id uuid not null · week_key text · payload jsonb not null · generated_at · app_version · created_at`. **`user_id` has no `references`.** |
| **writer** | `WeeklySummaryPublisher.publishIfConnected` → `AppSync.publishWeeklySummary` → `SyncService`. Runs on **every launch**, once per connected org holding `visit_packet_view`. |
| **reader** | `public.care_get_weekly_summaries(p_org, p_patient)` — SECURITY DEFINER, gated on active org membership **and** `private.has_consent(...,'visit_packet_view')`, clamped to the consent window, capped at 26 weeks, and it writes a `summary.viewed` audit event. |
| **RLS** | `cws_insert_own_consented` · `cws_update_own_consented` · `cws_select_own`. **No delete policy — and the migration says why: *"history is append-only for everyone at the policy layer."*** So the omission of the FK sits next to a deliberate refusal to allow deletes. |
| **user identifier** | a raw `auth.users.id` uuid — **not pseudonymous** |
| **payload** | a full week of her record (`CareWeekSummary.compose`) |
| **clinic relationship** | `org_id`, also with no FK |
| **legitimate retention obligation?** | **UNKNOWN — and this is the blocker.** |
| **does deletion touch it anywhere?** | **No.** Not in the RPC, not in `care_revoke_consent` (which deletes `visit_packets` but not summaries), not in any client path. |

### Why an FK cannot simply be added

`care_revoke_consent` already implements an Apple-shaped precedent for
`visit_packets`: *"stop-sharing removes the shared copy."* Weekly
summaries were deliberately excluded from that, and the table comment
frames them as a clinical *series* rather than a snapshot.

That is the difference between a shared copy and a clinical record. **If
these rows are part of a clinician's record of care, deleting them on
patient request may be exactly what a covered entity must NOT do.** This
product's own standing law says *"internal dev alpha, test data only, NO
BAA — never say HIPAA compliant"*, which means the question has never
been answered, not that it does not apply.

> **STOP. This is a founder/legal decision, not an engineering one.**
>
> **THE QUESTION:** when a clinic-pilot patient deletes her Jeni account,
> must `care_weekly_summaries` rows (a) be deleted, (b) be retained in
> full for a stated period under a stated obligation, or (c) be retained
> de-identified?
>
> Nothing can be written to `supabase/migrations` until this is answered,
> because each answer is a **different migration**, and two of the three
> are irreversible in the wrong direction.

### The three migrations, drafted here and NOT written to `supabase/migrations`

**(a) If the answer is DELETE** — the FK, matching every other
user-owned table in the schema:

```sql
-- NOT APPLIED. Requires the §16 orphan census first: adding a FK
-- validates existing rows, and any row whose user_id no longer exists
-- in auth.users will FAIL the constraint.
alter table public.care_weekly_summaries
  add constraint care_weekly_summaries_user_fk
  foreign key (user_id) references auth.users(id) on delete cascade
  not valid;                          -- accept history, enforce new rows
-- Then, only after the census proves zero orphans (or they are removed):
alter table public.care_weekly_summaries
  validate constraint care_weekly_summaries_user_fk;
```
- **Backward compatibility:** total. No client reads or writes `user_id`
  differently; build 30 is unaffected.
- **Rollback:** `alter table public.care_weekly_summaries drop constraint
  care_weekly_summaries_user_fk;`
- **Ordering:** census → `not valid` add → clean orphans → `validate`.
  **`not valid` first is mandatory** — a plain `add constraint` on a
  table that already holds orphan rows errors out and the migration
  fails.

**(b) If the answer is RETAIN** — then the omission must become a
decision, in the schema and in the consent copy:

```sql
comment on table public.care_weekly_summaries is
  'RETAINED BEYOND ACCOUNT DELETION by clinical-record policy <ref>.
   user_id is intentionally not a foreign key. See <policy doc>.';
```
…**and the consent sheet must say so before the next clinic patient
connects.** A retention obligation the customer was not told about is not
a retention obligation, it is a surprise.

**(c) If the answer is RETAIN DE-IDENTIFIED** — the largest of the three:
a pseudonymous patient key column, a backfill, a rewrite of
`care_get_weekly_summaries`, and a change to the audit-event join.
Drafted only as far as naming it, because it should not be chosen by
default.

### `care_audit_events` — the same shape, and the opposite verdict

`patient_id uuid` with no FK. **An audit trail that outlives the row it
audits is defensible** — arguably required. But the schema records it as
an *omission*, not a decision. **One `comment on table` makes it a
decision.** Same for `private.invitation_attempts` (rate-limit rows, no
health content) and `ops_events.actor_id`.

---

## 11 · ACCOUNT-DELETION PROOF — what the tests assert

Not "the RPC returned success". The aftermath.

| ASSERTION | HOW | STATUS |
|---|---|---|
| **LOCAL: zero customer records** | a fixture account carrying one of **every** local family — user row · weigh-in · plan · day check · session + rating · food entry · observation · regimen · dose event · body scan · chat message · consent grant · jeni memory · program fact · weekly read · **manual movement** · **a deletion-ledger entry** — then `clearLocalUserRecords` + `clearOnboardingUserDefaults`, then count every family | **GREEN — `DeletionContractTests`** |
| **ACCOUNT B INHERITS NOTHING** | two accounts on one device; delete A; assert every one of B's families intact | **GREEN** |
| **SERVER: zero customer-owned rows** | proven by schema, not by a live call: every table's `on delete` is read from its `create table` and asserted against an explicit expected list; the three `set null` tables and the four no-FK tables are named as the documented exceptions | **DOCUMENTED — §1.2** |
| **OBJECT STORAGE: zero owned artifacts** | the RPC deletes both buckets by uid prefix **and** owner; the upload paths are `food-photos/{uid}/{entryId}.jpg` and `body-scans/{uid}/{dayKey}/…`, so every object is under the prefix | **PROVEN BY CODE** |
| **AUTH: account unavailable** | `DELETE FROM auth.users` | RPC |
| **NEXT LAUNCH: fresh unauthenticated state** | `hasCompletedOnboarding` swept ⇒ welcome; sign-out re-bootstraps anonymous | existing |
| **SIGN-IN CANNOT HYDRATE DELETED DATA** | the rows are gone; RLS scopes to `auth.uid()` | by construction |
| **…EXCEPT** | **the prior-anonymous-uid copies (§9.1)** and **`care_weekly_summaries` (§10)** | **NAMED, NOT CLOSED** |

**No live server assertion is made.** This session did not read or mutate
a production row, and a test that pretends to have done so would be the
`Executed 0 tests` trap in different clothes.

---

## 12 · SIGN IN WITH APPLE — NOT N/A, AND NOT DONE

Jeni supports Sign in with Apple (`AppleSignInService`,
`AuthService.signInWithApple`, `completeAppleSignIn`, and Apple's
first-class `SignInWithAppleButton` in `SignInPromptView`).

**Does deleting the Jeni account revoke the Sign in with Apple
credential? NO.** There is **no call to `appleid.apple.com/auth/revoke`
anywhere in the repository** — no Swift call site, no Edge Function, no
SQL. `scripts/delete_user_account.sql` states it as intended:

> *"Apple Sign-In note: deleting the Supabase user does NOT revoke the
> Apple Services ID linkage… That's the desired behavior — they get a
> clean slate."*

**That reasoning is about the sign-in experience and it does not answer
the requirement.** Apple's App Review guidance for apps that offer both
Sign in with Apple and account deletion requires the app to call the
token revocation endpoint. The "clean slate" outcome the comment wants
still holds after revocation: the customer signs in again and gets a new
account.

**Why it is not built here:** revocation needs a `client_secret` signed
with the team's Sign in with Apple **private key** (`.p8`), which means a
new Edge Function and a new secret. That is a deploy and a credential —
both outside this pass's budget, both founder-gated.

**Sized:** one Edge Function (~60 lines: ES256 JWT → `POST
/auth/revoke`), one secret, one client call inserted between step 2 and
step 3 of §9, best-effort and never blocking the deletion the customer
asked for. **P1, App Store compliance class.**

---

## 13 · CONSENT — [CORR] A SMALLER, DIFFERENT DEFECT THAN `37` RECORDED

`37` §6 and its scorecard record that a clinic patient *"cannot withdraw,
from a new phone, a consent the server still honours"*, that
`WeeklySummaryPublisher` stops publishing, and scores SYNC 8 on it.
**Traced end to end, two of those three clauses are wrong, and the third
is right for a different reason.**

**There are two consent vocabularies, and they never meet:**

| | `visit_packet_sharing` | `visit_packet_view` |
|---|---|---|
| written by | `ConsentService.grant` (device-local `ConsentGrantRecord`) | `care_accept_invitation` RPC, **server-side** |
| `org_id` | **nil** | the clinic |
| revoked by | `ConsentService.revoke` (needs a LOCAL row) | `care_revoke_consent` RPC — **works from any device, no local state** |
| read by | **`VisitPacketView`'s own toggle label. Nothing else.** | `private.has_consent`, every care RPC, the `care_weekly_summaries` insert/update RLS, `CareConnectionService.connections()` |
| gates a publish? | **NO** | **YES** |

- `WeeklySummaryPublisher.publishIfConnected` gates on
  `CareConnectionService.connections()` — a **server** read — and RLS
  enforces `visit_packet_view` independently. It never read the local
  grant. **`37`'s "stops publishing" is false.**
- `CareConnectionSheet`'s *disconnect* calls `care_revoke_consent`, which
  revokes every grant for the org **and deletes the shared
  `visit_packets`**, from any device. **`37`'s "cannot withdraw from a new
  phone" is false for the consent that does anything.**
- The consent sheet's own copy is explicit that this toggle is
  prospective: *"when a care team connects later, this consent lets jeni
  share your visit packet with them… no clinic is connected today;
  nothing is sent today."*

**So what IS wrong?** The toggle is presented as her account's answer and
is stored only on the device that answered:

1. **It displays a device fact as an account fact.** New phone ⇒ reads
   *off* while the server row says granted.
2. **Revoking on device B leaves the server row active**, and device A
   still believes it is granted. The day anything reads
   `visit_packet_sharing` server-side, **unknown consent would read as
   permission** — the exact rule this pass is not allowed to break.
3. **Re-granting on a new device inserts a SECOND active row** —
   `grant()` is idempotent only against the local store — so the audit
   trail accumulates duplicate grants for one decision.

**FIXED, client-only, no migration** (`consent_grants` already grants
`select` and `update` to `authenticated`; there is no delete policy and
none is needed because revocation is `revoked_at`):
`SyncService.hydrateConsentGrants` + one call in `hydrateAndSync`,
insert-only by id with the same `userId` case-normalisation every other
hydrate uses. After it: the toggle shows the account's answer on any
device, a revoke made anywhere is visible everywhere, and `grant()` finds
the hydrated row and stays idempotent.

**Monotonicity, stated:** the hydrate can only ever *add* knowledge of a
grant or of its revocation. It never invents permission — an unhydrated
or failed read leaves the toggle **off**, which is the safe direction.

---

## 14 · JENI MEMORY — the §4A proposal, re-validated against THIS architecture

`37` §4A drafted `public.jeni_memories` with RLS, grants, rollback and
ordering. **Not applied, not built, and correctly so.** Re-examined
against the deletion contract:

| question | under `37`'s proposal as drafted | verdict |
|---|---|---|
| Can one memory be forgotten everywhere? | **NO.** The draft's client plan is *"upsert + insert-only hydrate + a real delete on forget"* — which is **exactly the weight-log shape**, and §4 proves that shape leaves a **ghost on every other device**. | **REWRITE** |
| Can a stale device resurrect a forgotten memory? | **Only if the client also pushes by set difference.** It must not. With `pendingUpsert`-gated push only, the server row stays deleted. | **SAFE if specified** |
| Does account deletion delete it? | **YES** — `on delete cascade` server-side, and `clearLocalUserRecords` already sweeps `JeniMemoryRecord` since `37`. | SAFE |
| Can a superseded memory stay local without becoming server truth? | **YES, and it must** — `37` is right that `supersededAt` rows are local bookkeeping. The upsert must filter to active notes. | SAFE |

**THE REWRITE, and it is one sentence:** *the client half must ship with
the deletion ledger wired to `JeniMemoryRecord` before the first note
syncs.* The table SQL in `37` §4A needs no change — the **client plan**
does. Without it, a note she forgot on her phone comes back on her iPad
and stays there, which is worse than not syncing at all, because
*"forget"* is the most explicit deletion verb in the product.

Sequencing, unchanged and re-affirmed: **migration → verify applied →
client (upsert active-only + insert-only hydrate + real delete + ledger).
DO NOT APPLY. Nothing is prepared.**

---

## 15 · BODY SCANS — [CORR] it IS stated

`37` §14 records body scans as *"BY DESIGN, unstated"*. Verified against
the running surface: `BodyScanFlowView` renders, as a first-class truth
row inside the scan flow itself:

> *"your scans live on this iPhone. nowhere else, unless you turn on
> backup."*

Copy swept for the false-expectation words — **saved · record · history ·
account · backup · sync** — across `PlankApp/BodyScan/` and
`Views/Settings/`: the only occurrences are the truth row above, the
Settings row `scan backup · off`, and its off-confirmation. **No surface
implies a body scan follows the account.** Nothing to fix; `37`'s note is
corrected rather than acted on.

**Deletion:** local records + JPEGs go through `BodyScanStore.deleteAll`
in the account sweep; the opt-in cloud copies are purged **before** the
RPC while the session is alive, with the RPC's own `storage.objects`
DELETE as the server backstop. `BodyScanPhotoStore` also sets
`isExcludedFromBackup = true`, so the files are absent from iCloud
backups. **This is the best-handled family in the product** and it is the
model the other media should follow.

---

## 16 · MANUAL MOVEMENT — the P0 this pass found

`MoveManualStore` — `UserDefaults move.manual.v1`, ≤400 entries, each one
a kind + minutes + a stamped estimate. `37` §4C classified it *"LOST
HISTORY, P2 — recorded as a choice, not an oversight"* on the question of
whether it should SYNC.

**It asked the wrong question of it.** The census asks a different one:

> **Is it swept?**

**No. By nothing.** It is not in `clearOnboardingUserDefaults`'s ~90-key
list, and it matches none of the 18 swept prefixes. The only two callers
of `MoveManualStore.wipe()` in the repository are a `#if DEBUG` preview
route and a QA seeder. Therefore:

| transition | before |
|---|---|
| **sign out → a different account signs in** | the new account's MOVE sheet lists **the previous customer's workouts**, and the Home tile counts them (`HomeView:1220` reads `MoveManualStore.strengthLastWeek()`) |
| **delete account** | every session she typed **survives on disk and in every device backup taken afterwards** |

**Does it affect calorie math?** No — re-verified: `MoveEnergy.estimatedKcal`
is stamped at record time for display only; there is no exercise
compensation anywhere in the product (`29` §3), `read_activity` reads
`StepsService`, and `WeeklyReadComposer` never sees it. **So it is not a
correctness defect. It is a privacy defect**, and it is the same shape as
the one `37` fixed for `JeniMemoryRecord`: a small, non-arithmetic,
customer-authored list that no sweep had ever heard of.

**FIXED** — `move.manual.v1` added to the sweep. It runs on sign-out as
well as account deletion, which means **her own manual movement does not
survive her own sign-out**. That is the deliberate trade `35` already
tested and accepted for the `safety_` family: *the sweep runs at sign-OUT,
before the next identity is known,* so the choice is between losing a
device-local list and handing it to a stranger. **Stated in the answer to
§21.19 rather than buried.**

---

## 17 · WHAT THE PRODUCT PROMISES VS WHAT IT DOES

| PROMISE, verbatim | WHERE | REALITY | VERDICT |
|---|---|---|---|
| *"Delete everything anytime. Settings → account → delete account removes your cloud rows, your photos, and your local data."* | `docs/privacy_policy.md:43` | true for the current uid; **false for the prior anonymous uid (§9.1)** and **false for `care_weekly_summaries` (§10)** | **IMPLEMENTATION DEBT** |
| *"permanently deletes your rows from Supabase, your photos from cloud storage, and the local data on your device. **No soft-delete; the data is unrecoverable.**"* | `privacy_policy.md:189` | the strongest sentence in the document, and the two exceptions above contradict it directly | **IMPLEMENTATION DEBT — the strongest claim, the clearest gap** |
| *"your journal is yours to edit or delete entry by entry"* | `privacy_policy.md:186` | true, and now durable on the deleting device | SAFE after this build |
| *"Access is per-account. The storage bucket is private…only your signed-in account can read, write, or delete objects under your own folder."* | `privacy_policy.md:87` | true — verified against both bucket policy sets | SAFE |
| *"deleting your account removes all of your meal photos"* | `privacy_policy.md:92` | true for the current uid; **the prior-anon-uid photos are the same gap** | see §9.1 |
| *"your scans live on this iPhone. nowhere else, unless you turn on backup."* | `BodyScanFlowView` | true | SAFE |
| *"this one came from apple health… a later sync can bring it back."* | `WeightLedger.removalNote` | **true, and it is the only place in the product that discloses a resurrection** | **SAFE — the model for how to say it** |
| *"what jeni remembers"* + per-row *forget* | Settings | true on device; **there is no server row**, so *forget* is complete today | SAFE (and §14 must keep it so) |
| *"nothing is sent anywhere. sharing a pdf is always your own action."* | `VisitPacketView` | true | SAFE |
| *"when a care team connects later, this consent lets jeni share your visit packet with them… nothing is sent today."* | consent sheet | true — and it is why §13's defect is smaller than `37` said | SAFE |

**No copy was rewritten.** Two sentences in the privacy policy are
**over-promises the backend does not keep**, and the brief is right that
this is implementation debt, not copy debt: the correct response is
§9.1 and §10, not softer words. **Both are named for the founder in the
four buckets.**

---

## 18 · WHAT WAS BUILT

Three client-only fixes. No schema, no deploy, no production SQL, no
build bump.

### 18.1 · P0 · `move.manual.v1` IS SWEPT

One key added to `clearOnboardingUserDefaults`. §16.

### 18.2 · THE DELETION LEDGER

`PlankApp/Sync/DeletionLedger.swift` — a deletion is now a fact this
device records.

- `record(id:userId:)` at all four real deletes, **before** the network
  call, so a delete that fails offline is still remembered.
- `supersede(id:userId:)` at the write chokepoints that can legitimately
  reuse a deterministic id (`DoseEventStore.mark`, `ObservationStore.record`).
- `sweep(userId:in:)` after every hydrate: any local row whose id is
  tombstoned is removed again **and** the server delete is re-asserted.
- `clear(userId:)` from `clearLocalUserRecords` — account deletion only.
  **Never the sign-out sweep**, because sign-out preserves the rows and
  a ledger swept at sign-out would re-open every resurrection.

**Zero files under `Packages/PlankFood`.** The sweep drives
`FoodLogPersister.deleteEntry(id:)`, which is the same public function
the customer's own *remove* uses, so the re-deletion also re-fires
`onEntryDeleted` and the server row goes again.

### 18.3 · `hydrateConsentGrants`

§13. `Packages/PlankSync` +1 method (insert-only by id, the same shape as
the four hydrates beside it), `AppSync` +1 call.

---

## 19 · RED → GREEN

`plankAITests/DeletionContractTests.swift`. Every test is a customer
promise, not a mechanism.

| test | the promise |
|---|---|
| `testAPlateDeletedOnThisPhoneNeverComesBackToThisPhone` | food · device B pushes it back, A's hydrate re-inserts it, A must remove it again |
| `testAWeighInDeletedOnThisPhoneNeverComesBackToThisPhone` | weight |
| `testADoseDeletedOnThisPhoneNeverComesBackToThisPhone` | dose |
| `testASymptomClearedOnThisPhoneNeverComesBackToThisPhone` | symptom |
| `testMarkingTheSameDoseSlotAgainIsNotBlockedByTheOldDeletion` | the `supersede` control — a deterministic id must survive its own tombstone |
| `testTheLedgerNeverReachesAnotherAccount` | cross-account isolation of the ledger itself |
| `testDeletingTheAccountLeavesNoWorkoutSheTypedOnThisDevice` | `move.manual.v1` |
| `testDeletingTheAccountLeavesNoDeletionLedgerBehind` | the ledger is customer-derived data and goes with the account |
| `testSigningOutKeepsTheDeletionLedger` | the trap: sweeping it at sign-out re-opens every resurrection |
| `testAnotherAccountOnThisDeviceInheritsNothing` | two accounts, one device |
| `testHydratingAConsentGrantShowsTheAccountsAnswerNotTheDevices` | consent display |
| `testAnUnknownConsentIsNeverPermission` | monotonicity — a failed hydrate leaves the toggle off |

**RED before GREEN, measured, in §20.**

**GATED, not faked:** there is no test asserting that a delete propagates
**to** the other device, because it cannot without the tombstone
migration. §21 answers that question honestly instead of proving it with
a repository-local simulation. **CODE READY ≠ SYSTEM SAFE AFTER
MIGRATION.**

---

### RED, MEASURED

With the four cores reverted to their pre-session behaviour —
`DeletionLedger.record` a no-op, `DeletionLedger.sweep` returning 0,
`move.manual.v1` removed from the sweep list, and `DeletionLedger.clear`
removed from `clearLocalUserRecords`:

```
Executed 14 tests, with 10 failures (0 unexpected)
** TEST FAILED **     exit 65
```

**10 of 14 red.** The four that passed, and why each one is honest:

| passed under the stub | why |
|---|---|
| `testAnUnknownConsentIsNeverPermission` | **A REFUSAL TEST, and a stub that can do nothing satisfies it.** It cannot tell *"refused for the right reason"* from *"cannot act at all"* — the lesson `34`, `35`, `36` and `37` each recorded, now **five sessions running**. It exists as the pin beside the test that does move. |
| `testHydratingAConsentGrantShowsTheAccountsAnswerNotTheDevices` | `hydrateConsentGrants` needs a live PostgREST client, so the test pins what happens **after** the row lands, not the fetch. **Stated, not dressed up:** this fix is proven by construction and by the shape of the four hydrates beside it, not by this test going red. |
| `testMarkingTheSameDoseSlotAgainIsNotBlockedByTheOldDeletion` | **A CONTROL.** It asserts the ledger does NOT eat her own re-mark. With the ledger dead there is nothing to eat it. A control cannot go red against a stub; that is what makes it a control. |
| `testLoggingTheSameSymptomAgainIsNotBlockedByTheOldClear` | same |

### GREEN

Every command run **serially**, unpiped, `$?` captured directly (`32`
§13 — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/DeletionContractTests` | 14 | **14** | **0** | `** TEST EXECUTE SUCCEEDED **` |
| `-only-testing:plankAITests` (full app suite) | 1273 | **1273** | **0** | `** TEST EXECUTE SUCCEEDED **` |
| `-scheme PlankSync` (from the package dir) | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` (from the package dir) | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.4 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is a SUCCEEDED line.** App suite **1259 → 1273, exactly +14**,
which is `DeletionContractTests` and nothing else: **no existing test
changed and none needed to.** `PlankSync` gained a method and no test —
its 9 are unchanged and green, which is the correct outcome for an
additive hydrate whose fetch cannot be driven offline.

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **86 MB, 123,631 strings** — size
and total stated first, because *a zero from a file that does not exist
is the `Executed 0 tests` trap in different clothes* (`35`).

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `persona-customer` · `persona-autym` · `debug-weigh-ins` | **0 · 0 · 0** |
| `uitest-cbt-lesson` | **0** |
| `move.manual.v1` | **1** — the new sweep entry is in the shipping binary |
| `DeletionLedger` (symbol table) | **141** — the new type ships; `strings` shows 0 because the symbol lives in `nm`, not the literal pool |

*(Method note, unchanged from `37`: Swift stores literals of ≤15 UTF-8
bytes inline in the `String` struct, so `deletions.v1.` (13 bytes) and
`consent_grants` (14 bytes) are invisible to `strings` **by
construction** and both correctly report 0. They are proven by the test
suite and by `nm`, not by a grep that cannot see them.)*

### Protected paths vs the reviewed release `1710180`

| path | diff |
|---|---|
| `PlankApp/Payment` · `Views/Paywall` · `Auth` | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** |
| **`supabase/migrations`** | **EMPTY** |
| `PlankApp/Analytics` | `31`'s +6 allowlist lines. **This session: EMPTY.** |
| `Packages/PlankFood` | `26`/`27`/`34`. **This session: EMPTY.** |
| `supabase/` | `27`'s food-vision EF, written and NOT deployed. **This session: EMPTY.** |
| `Packages/PlankSync` | `31` + `34` + `36`, **and this session: `hydrateConsentGrants`, additive, +88 lines, one new method** |

**All three files in the repository that declare a `@Model`**
(`PlankSync/Models.swift`, `Chat/ChatModels.swift`, `Chat/JeniMemory.swift`)
have a **zero diff against `1710180`**, re-derived this session with
`grep -rlnE "^[[:space:]]*@Model"` rather than inherited. **There is no
SwiftData store migration to fail.** The deletion ledger deliberately
lives in `UserDefaults` rather than in a new `@Model` for exactly this
reason.

The `project.pbxproj` diff contains **only file references** — verified
by filtering the diff for anything that is not a `PBXBuildFile` /
`PBXFileReference` / group-child / sources-phase line and getting an
empty result. `CURRENT_PROJECT_VERSION` is still **30** and
`MARKETING_VERSION` still **1.2.0**; the archive-time bump to **31**
stands and is the founder's step.

### This session's files — nine

`Sync/DeletionLedger.swift` **(new)** · `Sync/AppSync.swift` ·
`Chat/ChatToolRouter.swift` · `Program/ObservationStore.swift` ·
`Program/DoseEventStore.swift` ·
`Packages/PlankSync/Sources/PlankSync/SyncService.swift` ·
`plankAITests/DeletionContractTests.swift` **(new, 14)** ·
`plankAI.xcodeproj/project.pbxproj` (two file references) ·
this document + `docs/app_v25/deletion_audit.sql` **(new, read-only,
NOT executed)**.

**No new DEBUG door was added.** No production row was read or mutated.

---

## 21 · THE TWENTY ANSWERS

**1 · IF I DELETE A MEAL ON MY IPHONE AND OPEN MY OLD IPHONE, CAN IT
COME BACK?**
**On the iPhone you deleted it from: NO, as of this build, permanently.**
On the old iPhone it never left, and it will keep re-uploading the row
until that phone updates too — at which point the deleting phone deletes
it again server-side on its next hydrate. **Before this build the answer
was YES**, with no offline step: the old phone re-uploads on **every
launch**, and the new phone pulls it back on its next hydrate (certain on
a reinstall, gated by `shouldHydrateOnLaunch` otherwise). §3.

**2 · SAME QUESTION FOR WEIGHT.**
**NO on the deleting phone**, and it never reached the server again
anyway: weight has no push-back-by-diff, and a hydrated row carries
`pendingUpsert == false` so nothing re-pushes it. The old phone keeps a
**ghost** — a weigh-in that is deleted everywhere except there — and
that ghost is the numerator of both its daily targets. **One exception,
disclosed on screen:** a weigh-in that came from Apple Health is
re-imported by `BodyMassImportService` with a fresh id, and the removal
sheet says so in as many words. §4.4.

**3 · SAME QUESTION FOR DOSE.** **NO**, on either phone, and it never
could — same shape as weight, minus the Health importer. The ghost on the
other phone remains until it updates.

**4 · SAME QUESTION FOR SYMPTOMS.** **NO**, same as dose — and this is
the one where it mattered most, because `VisitPacket` reads these rows
and a resurrected symptom could reach a clinician's PDF.

**5 · WHAT EXACTLY REPRESENTS "DELETED" IN THE SYSTEM?**
**On the server: nothing. Absence.** The row is hard-deleted and no
record of the deletion exists anywhere in Postgres.
**On the device, as of this build: an entry in `deletions.v1.<uid>`** —
the id, lowercased, and when she removed it. That entry is consulted
after every hydrate, and a record whose id it holds is removed again and
re-deleted server-side.

**6 · CAN BUILD 30 UNDERSTAND THAT REPRESENTATION?**
**It does not need to.** The ledger is device-local and changes no server
contract, so build 30 behaves today exactly as it did yesterday — which
is why this could ship without coordination. **A server tombstone is the
opposite:** build 30's `fetchFoodLogs` is `.select()` with no
`deleted_at is null` filter, so it would *hydrate soft-deleted rows*.
§6.

**7 · CAN BUILD 30 RESURRECT DATA AFTER THE FIX?**
**Yes, on its own screen, and briefly on the server.** A build-30 device
keeps pushing back rows a build-31 device deleted; the build-31 device
removes them again and re-asserts the delete each hydrate. **The
customer's current phone is right; the network is noisy until the other
phone updates.** Said plainly rather than claimed away.

**8 · HOW LONG MUST DELETION STATE LIVE?**
**For the lifetime of the account.** There is no reliable registry of a
customer's devices, and inventing one to serve deletion is the largest
possible answer to the smallest question. The cost is trivial — ~60 bytes
per deletion; a million customers deleting fifty things each is ~3 GB of
Postgres for the eventual server tombstone, against the photos those same
customers already store. **No cleanup policy is proposed: a cleanup
policy is a second way to resurrect a record.** The device-side cap is
2,000 per account, oldest evicted, and that boundary is stated in §7
rather than hidden.

**9 · DOES CORRECTING A RECORD PRESERVE ITS ID?**
**Yes, on every correction the customer can perform** — a plate's
numbers, a plate's day, a weigh-in's number, a dose slot, an injection
site, a symptom's severity. Two paths mint a new id and both are correct
and documented: **a repeat** ("again" is a second plate, not a
correction) and **the sign-in merge** (the cloud row belongs to the old
uid, so a same-id upsert is an RLS rejection). Moving a symptom to a
different day is a delete + create because the id encodes the day, and
`supersede` covers it. §8.

**10 · DOES DELETE ACCOUNT REMOVE EVERY CUSTOMER-OWNED LOCAL FACT?**
**Yes, as of this build.** `37` closed three families; this pass closed
the fourth — **`move.manual.v1`, every workout she typed, which was in no
sweep at all** — and added the deletion ledger to the sweep because it is
derived from her own deletions. **Two per-identity behavioural ledgers
remain unswept and are named as P2**, neither customer-authored:
`method.ledger.v1` and `brain.ledger.v1`, plus her reminder hour. §1.3.

**11 · DOES DELETE ACCOUNT REMOVE EVERY CUSTOMER-OWNED SERVER FACT?**
**No, in two places, and one of them is much larger than `37` knew.**
**(a)** Everything she recorded before signing in survives under an
orphaned anonymous uid, permanently, because the RPC scopes to
`auth.uid()`. There is a founder-run, unscheduled, 90-day reaper script.
**(b)** `care_weekly_summaries` has no foreign key and no delete policy.
Three more tables (`care_audit_events`, `invitation_attempts`,
`ops_events`) also outlive the account by omission rather than by
decision. §9.1, §10.

**12 · WHAT HAPPENS TO `care_weekly_summaries`?**
**Nothing. It is not touched by the RPC, by `care_revoke_consent`, or by
any client.** A connected patient's weekly jsonb payloads stay under her
raw uuid forever, reachable by no credential and removable by no client.
**Three migrations are drafted in §10 and NONE is written to
`supabase/migrations`, because the choice between them is a legal
question, not an engineering one** — and because adding the FK without
the §16 census first would fail on any pre-existing orphan row.

**13 · CAN A SECOND DEVICE ACCIDENTALLY RE-GRANT CLINIC CONSENT?**
**No — and `37` had the wrong table.** The clinic-facing consent is
`visit_packet_view`, created and revoked entirely server-side by
`care_accept_invitation` / `care_revoke_consent`, and revocation works
from any device today. What device B could do was show *off* while the
server said *granted*, silently create a **second** active
`visit_packet_sharing` row for one decision, and leave A believing a
consent B had withdrawn. **Fixed here** by `hydrateConsentGrants`, and
the hydrate is monotonic in the safe direction: a failed read leaves the
toggle **off**, because unknown consent is never permission. §13.

**14 · DOES SIGN IN WITH APPLE REVOCATION WORK, IF APPLICABLE?**
**Applicable, and NO.** There is no call to `appleid.apple.com/auth/revoke`
anywhere in the repository, and `scripts/delete_user_account.sql` records
its absence as intentional on a "clean slate" argument that does not
answer the requirement. **P1, App Store compliance class**, sized at one
Edge Function and one secret in §12. **Not built — it is a deploy and a
credential, both outside this pass's budget.**

**15 · CAN ANY CUSTOMER-OWNED OBJECT STORAGE ARTIFACT ORPHAN?**
**Under her current uid: no.** Both buckets are private with own-folder
RLS, every upload path is `{uid}/…`, and the RPC deletes by uid prefix
**and** by owner — belt and braces, and body scans are additionally
purged pre-RPC while the session is still alive. **Under a prior
anonymous uid: yes**, the same gap as §9.1, and Q1c of the audit sizes
it.

**16 · WHAT PRODUCTION QUERY MUST I RUN?**
**`docs/app_v25/deletion_audit.sql`** — read-only, counts and bounds
only, no emails, no names, no payloads, **written and NOT executed.**
Three questions: **(Q1)** how much health data sits under orphaned
anonymous uids · **(Q2)** how many `care_weekly_summaries` rows are
already orphaned (this decides whether the FK needs `not valid` first) ·
**(Q3)** how many customers actually run two devices, read as a bound
rather than a figure. The file states what each answer changes.

**17 · WHAT MIGRATION MUST I APPROVE?**
In order: **(a)** the `care_weekly_summaries` foreign key — **blocked on
a legal answer, then on Q2** · **(b)** the server tombstone for food /
weight / dose / observation — **and it must ship AFTER a client that
filters on it**, never before · **(c)** `jeni_memories` (`37` §4A, table
SQL unchanged, **client plan rewritten in §14**) · **(d)**
`users.onboarding_age_years`. **None written. None applied.**

**18 · WHAT MUST SHIP CLIENT-FIRST?**
**Everything in this pass, and the tombstone migration's reader.** The
deletion ledger, the `move.manual` sweep and `hydrateConsentGrants` all
ship with no server change at all. Then a client that filters
`deleted_at is null` must reach the installed base **before** the
tombstone migration is applied — the same ordering hazard `31` §21 found
for the `users` upsert and `37` §8 for the food-vision EF, and the third
time it has decided a sequence.

**19 · WHAT MUST DEPLOY SERVER-FIRST?**
**Only `jeni_memories`** — a table a client references must exist before
that client ships, or every note 404s. Nothing else in this document
deploys before a client. And **nothing at all deploys until the founder
answers §10.**

**20 · SAFE FOR NEXT BUILD: YES.**
Every change is additive and device-local. Nothing existing writes
differently, no arithmetic moved, no `@Model` changed, no schema, no
deploy, no production SQL. The single behaviour change a customer can
notice is that a record she removed stays removed — and, for anyone
signing out on a shared phone, that her MOVE sessions do not follow the
next person.

---

# SCORECARD

Graded hard. Anything below 9 names the exact remaining blocker.

| domain | `37` | now | the exact defect |
|---|---|---|---|
| **RECORD DELETION** (does *remove* mean removed, here) | — | **10** | — |
| **TWO-DEVICE DELETION** | 6 | **7** | the deletion does not travel TO the other device; that device keeps a ghost and, for food, keeps re-uploading it. **Blocker: the server tombstone migration, which cannot be applied before a filtering client reaches the installed base.** |
| **ACCOUNT DELETION** | 8 | **6** | **a complete server-side copy of everything she recorded before signing in survives, permanently, under an orphaned anonymous uid.** Lower than `37` because the census found the hole, not because anything regressed. **Blocker: `deletion_audit.sql` Q1, then a decision.** |
| **CONSENT REVOCATION** | 8 (as SYNC) | **9** | — the clinic-facing scope always worked from any device; the local toggle now shows the account's answer |
| **CROSS-ACCOUNT ISOLATION** | — | **9** | `method.ledger.v1`, `brain.ledger.v1` and the reminder hour still cross a sign-out. Behavioural, not customer-authored, one line each. |
| **OLD-CLIENT COMPATIBILITY** | — | **10** | — nothing about the server contract changed, so build 30 is unaffected in every cell of §6 |
| **PRIVACY CONTRACT** (does the copy match the backend) | — | **5** | *"No soft-delete; the data is unrecoverable"* is the strongest sentence in the privacy policy and it is **false in two places** (§9.1, §10). **The fix is the backend, not the words.** |

---

# THE FOUR BUCKETS

### 1 · SAFE IN CLIENT NOW — shipped this build

1. **`move.manual.v1` is swept.** P0 privacy: a cross-account leak AND a
   deletion hole, in no sweep at all.
2. **THE DELETION LEDGER.** A deletion is a fact this device records.
   Food, weight, dose, symptom. Zero schema, zero deploy, zero `@Model`.
3. **`hydrateConsentGrants`.** The toggle shows her account's answer;
   revoking works from any phone; no duplicate grant rows.

### 2 · MIGRATION READY — NEEDS FOUNDER APPROVAL

1. **`jeni_memories`** — `37` §4A's table SQL stands unchanged; **its
   client plan is rewritten in §14** (the drafted "upsert + insert-only
   hydrate + delete" is the weight-log shape, which leaves a ghost on
   every other device — the ledger must be wired to `JeniMemoryRecord`
   before the first note syncs).
2. **`users.onboarding_age_years`** — one nullable int, `37` §5,
   unchanged.
3. **Deprecate then delete the false contracts** — `public.coach_messages`
   (re-verified: zero client references), `users.program_status` /
   `program_intensity_tier` / `program_goal_date`.
4. **`comment on table`** for `care_audit_events`,
   `private.invitation_attempts` and `ops_events` — turn three omissions
   into three decisions. Costs nothing, changes no behaviour.

### 3 · REQUIRES PRODUCTION AUDIT FIRST

1. **Run `docs/app_v25/deletion_audit.sql`.** Read-only, three questions,
   written and not executed. **Nothing in bucket 2 or 4 should be decided
   before Q1 and Q2 come back.**
2. **The `care_weekly_summaries` foreign key.** Blocked twice: on the
   legal answer in §10, and on Q2 (a plain `add constraint` fails if any
   orphan row already exists).
3. **The orphaned-anonymous-uid retention contradiction.** Q1 sizes it.
   Either the reaper gets scheduled, or the deletion path learns her
   prior uids, or the privacy policy stops promising what the backend
   does not do — and the first two are better than the third.
4. **The server tombstone.** Q3 sizes how much it is worth.

### 4 · DO NOT BUILD YET

1. **The server tombstone before a filtering client ships.** It would
   turn every deletion into a resurrection on build 30's own screen —
   strictly worse than today. §6.
2. **Syncing Jeni memory, chat, body scans or manual movement.** The
   brief's own rule, and now an architectural one: *we do not sync more
   customer data until deletion semantics are trustworthy.*
3. **Versioned rows or a change log for deletion.** §5 evaluates and
   rejects both; a per-device cursor is a device registry.
4. **Suppressing the Apple Health re-import.** It is disclosed on the
   removal sheet in the product's own words, and the honest version of
   the rule is a product decision, not a correctness one. §4.4.
5. **Softening the privacy policy.** The sentence is right; the backend
   is wrong.
6. **Backfilling an anonymous uid → named uid link from row shapes.** It
   would be a guess about identity, which is the fabrication class this
   whole line of work exists to remove.

---

## SAFE FOR NEXT BUILD: YES

Not because the suites are green. Because every change is **additive and
device-local**:

- **Nothing existing writes differently.** The ledger only ever prevents
  an insert or removes a row it was already told to remove; it cannot
  destroy a record the customer still has. That is why it is safe to ship
  before the migration that would complete it.
- **The arithmetic is untouched.** Not one constant moved; the golden
  matrix, `OneTargetEverywhere`, `AutymRecovery`, `UpgradeBoundary`,
  `PlanIdentity`, `SafetyRestore`, `RecordRepair`, `PastRecordRepair` and
  `OneRecord` are all green and all unchanged.
- **No `@Model` changed**, so no SwiftData migration exists to fail — the
  ledger lives in `UserDefaults` deliberately.
- **No schema change, no deploy, no production SQL, no production data
  read or mutated.** `supabase/migrations` is EMPTY against the reviewed
  release.
- Twelve protected paths **EMPTY**, `Packages/PlankSync` +1 additive
  method, the binary strings-clean, and the 5.6 exit path re-verified
  green.

> **Can I tell a customer, without qualification, "when you delete
> something in Jeni, it stays deleted"?**
>
> **NO — and the shortest exact sequence to YES is:**
>
> 1. **Ship this build.** *"When you delete something, it stays deleted
>    on that phone"* becomes true and unqualified today.
> 2. **Run `deletion_audit.sql`.** Q1 and Q2. Nothing else moves first.
> 3. **Answer §10's legal question**, then apply the
>    `care_weekly_summaries` FK (or write the retention comment and the
>    consent copy).
> 4. **Close the anonymous-orphan hole** — schedule the reaper, or teach
>    the deletion path her prior uids. Until then, *"delete account"* is
>    not unqualified for anyone who onboarded anonymously and then signed
>    in, which is the default path.
> 5. **Ship a client that filters `deleted_at is null`, let it reach the
>    installed base, THEN apply the tombstone migration.** Only now does
>    the sentence hold across two phones.
> 6. **Add Apple token revocation** to the deletion path.
>
> Steps 1–4 make it true of the customer's data. Step 5 makes it true of
> her devices. Step 6 makes it true of her identity. **Nothing in that
> list is large. Only step 3 is blocked on something engineering cannot
> answer.**
