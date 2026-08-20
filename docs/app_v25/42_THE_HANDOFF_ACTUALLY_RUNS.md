# THE HANDOFF ACTUALLY RUNS

**Status: E1 AUDITED AS HOSTILE CODE, CORRECTED IN EIGHT PLACES, APPLIED
TO PRODUCTION, VERIFIED READ-ONLY, ATTACKED, AND SPOKEN TO BY A SHIPPED
CLIENT — END TO END OVER THE REAL API. 2026-08-15.**

`41` ended with an intentionally incomplete architecture: the client
safety fixes shipped, the server contract was designed, and the two were
not connected — because the migration had never been executed against a
Postgres. That caution was correct, and this pass is the reason.

> ▎ **THE CLIENT MAY REQUEST AN OWNERSHIP TRANSITION.**
> ▎ **ONLY THE SERVER MAY DECLARE IT COMPLETE.**
>
> ▎ **A SESSION CHANGE IS NOT A HANDOFF RECEIPT.**
>
> ▎ **A HANDOFF THAT CANNOT SURVIVE THE CLIENT DYING IS NOT A HANDOFF.**
>
> ▎ **NAMED → NAMED IS NEVER DATA MIGRATION.**

---

## 0 · THE ANSWER FIRST

**`41`'s E1 would never have worked. Not once, for anyone, ever.**

| # | the finding | class |
|---|---|---|
| 1 | **[CORR-1 · BLOCKER] `storage.objects` CARRIES A STATEMENT-LEVEL DELETE GUARD.** `protect_objects_delete` is `BEFORE DELETE … FOR EACH STATEMENT` and raises `42501` unless `storage.allow_delete_query` is `'true'`. **A statement-level trigger fires even when ZERO ROWS MATCH.** So `complete_account_handoff` threw on its `delete from storage.objects` on **every call**, aborting the whole handoff transaction. Proven against production before anything was applied: a delete against a bucket that does not exist, matching nothing, raised 42501. **Fixed with one `set_config(…, is_local => true)`.** | **P0 — the migration was DOA** |
| 2 | **[CORR-1b] PACKAGE A1 HAS THE IDENTICAL DEFECT, AND IT IS WORSE.** `40`'s staged storage purge for `delete_user_account()` would have thrown the same 42501 before reaching `DELETE FROM auth.users` — so **"delete my account" would have failed for 100% of customers**, on the one path Apple requires under 5.1.1(v). Its safety matrix says *"it deletes strictly more, and today there is nothing more to delete"*; that is false, because the trigger does not care whether there is anything to delete. It was one founder action from being applied. **Corrected file staged, NOT applied.** | **P0 — a staged package that breaks deletion** |
| 3 | **[CORR-2] THE DETERMINISTIC-ID REWRITE LOWERCASED ITS TAIL, AND PRODUCTION HAS UPPERCASE.** `41` wrote `substring(lower(id) …)`. The client mints `userId.lowercased()` as the PREFIX and leaves the tail alone, and `ObservationKind.rawValue` is camelCase — production `observations.id` values verifiably contain uppercase. The server would have produced `…-foodnoise-…` where the client mints `…-foodNoise-…`, so her next log of that symptom on that day would create a **second row**: the exact duplication a deterministic id exists to prevent, introduced by the function whose job is to preserve it. | **P0 — silent duplication** |
| 4 | **[CORR-3] `provider = 'email'` IS AN EXFILTRATION PATH, NOT AN INJECTION ONE.** BEGIN necessarily runs BEFORE the sign-in. An Apple `sub` arrives inside a token Apple SIGNED for this device; a typed email address is a string nobody has verified. **A single typo landing on another real customer's address creates an open receipt that the stranger's next sign-in redeems — her entire record moves into his account and hers is retired.** That is a different and worse animal than the injection residual `41` named. **`email` removed from the CHECK constraint and from BEGIN.** | **P0 — account takeover by typo** |
| 5 | **[CORR-4] `program_day_checks` DOES HAVE A PER-USER UNIQUE KEY.** `UNIQUE (user_id, program_plan_id, program_day, item_key)`, read from the live catalog. `41` §24 called it uncollidable *"because the plan id is rewritten to a fresh uuid"* — that is the CLIENT's re-key; the server PRESERVES plan ids, so the reasoning does not transfer. Unreachable in practice, unguarded in fact, and an unguarded unique key inside a one-transaction merge is precisely `41`'s own day-progress finding. **Guarded.** | **P1 — the same shape `41` found** |
| 6 | **[CORR-5] `public.coach_messages` WAS IN NO LIST AT ALL** — neither transferred nor refused. A handoff would have deleted her transcript with the source account and nobody would have decided that. Zero rows today, which is when a rule is cheapest to make. **Named and transferred.** | **P1 — a 25th family** |
| 7 | **[CORR-6] THE RECEIPT CAP WAS PER-SUBJECT ONLY**, so one anonymous session could insert unbounded rows by varying the hash. **Per-source cap added.** | **P2 — bounded DoS** |
| 8 | **[CORR-7] THE PROFILE RULE WAS HALF-IMPLEMENTED.** `41` §25's own rule is *"the source's row is used ONLY when the destination has none"*; the server implemented only "destination wins", so a destination account with **no** `public.users` row lost her height, weight, goal, sex and cohort to the cascade. **87 of 867 permanent accounts are in exactly that state.** **Filled, monotonically, and only into a total absence.** | **P1 — data loss** |
| 9 | **[CORR-8] A SAME-UID UPGRADE LEFT A DANGLING AUTHORIZATION ARTIFACT.** BEGIN runs before the link; when the link SUCCEEDS the receipt names the caller as its own source and sits `open` for thirty days. **Closed deterministically** — COMPLETE deletes open receipts whose source is the caller, which can only ever be the caller's own. | **P2 — hygiene** |

And the sentence that this pass exists to convert from a design into a fact:

> ▎ **THE SOURCE'S RETIREMENT NO LONGER NEEDS A CREDENTIAL FOR THE
> ▎ SOURCE.** Proven in production: an anonymous account was retired by a
> ▎ call made **as the destination**, and its weigh-in arrived under the
> ▎ destination **with its id unchanged**.

---

## 1 · E1 AUDITED AS HOSTILE CODE

`41` wrote it. This pass reviewed it as if it came from an untrusted
contributor.

### 1.1 · Every statement, classified

Comments stripped before classification, and function BODIES separated
from top-level statements, because the two run at different times.

| kind | count | statements |
|---|---|---|
| DDL | 3 | `create schema if not exists private` · `create table if not exists public.account_handoffs` · `alter table … enable row level security` |
| INDEX | 2 | the partial unique index · the partial subject index |
| COMMENT | 1 | `comment on table` |
| FUNCTION | 3 | `private.transfer_account_rows` · `public.begin_account_handoff` · `public.complete_account_handoff` |
| DCL | 6 | 4 `revoke`, 2 `grant` |
| **total** | **15** | |

**DML AT APPLY TIME: `insert` 0 · `update` 0 · `delete` 0 · `truncate` 0
· `merge` 0 · `copy` 0.** Every `update`/`delete`/`insert` in the file is
inside a function body, which runs only when called.

> ▎ **APPLYING THE MIGRATION CANNOT MUTATE A CUSTOMER ROW, AND THAT IS A
> ▎ MECHANICAL PROPERTY OF THE FILE RATHER THAN A PROMISE.**

`drop`: 0 (the rollback block is commented out). `alter`: 1, on the new
table only.

### 1.2 · The privilege questions, answered from the live catalog

| question | answer |
|---|---|
| WHAT OBJECTS DOES IT CREATE? | one table, two indexes, three functions. Nothing else. |
| WHAT EXISTING OBJECTS CAN IT MUTATE? | **none.** `create schema if not exists private` is a no-op (the schema exists, owner `postgres`); no existing function, policy, grant or column is touched. |
| WHAT ROLE OWNS EACH FUNCTION? | `postgres` — the same owner as the deployed `delete_user_account`, which is the empirical proof it can reach `auth.users`. |
| SECURITY INVOKER OR DEFINER? | all three DEFINER, and each needs it: two read `auth.identities`/`auth.users`, one writes `auth.users`. |
| SEARCH_PATH? | `search_path=""` on all three, with `pg_catalog` qualification wherever a DEFAULT is resolved at CREATE time. |
| CAN `PUBLIC` EXECUTE? | **NO.** The ACLs are explicit: `postgres=X/postgres,authenticated=X/postgres`. There is no bare `=X/`. |
| CAN `anon`? | **NO** — all three false. |
| CAN `service_role`? | **NO** — all three false, and it has no USAGE on `private`. |
| WHAT CAN `authenticated` EXECUTE? | exactly `begin_account_handoff(text,text)` and `complete_account_handoff(uuid,text)`. **`private.transfer_account_rows` is false.** |
| CAN A DIRECT TABLE WRITE BYPASS THE RPC? | **NO.** RLS on, **zero policies**, and `revoke all … from anon, authenticated`. Proven at both layers. |
| IS RLS ENABLED? | yes, with no policies — deny-all for every non-BYPASSRLS role. |
| DOES THE CLIENT NEED DIRECT TABLE ACCESS? | **no**, and it has none. |
| CAN A CUSTOMER READ ANOTHER'S RECEIPT? | no customer can read ANY receipt. HTTP 403. |
| CAN A CUSTOMER CREATE A RECEIPT FOR ANOTHER SOURCE UID? | **the function takes no source.** `source_user_id` is `auth.uid()`. |
| CAN A CUSTOMER COMPLETE SOMEONE ELSE'S RECEIPT? | only if it owns the pre-committed subject, computed server-side from its own identity rows. |
| CAN THE DESTINATION UID BE SUPPLIED? | **there is no destination parameter.** |
| CAN THE SOURCE UID BE SUPPLIED? | `p_source_user_id` exists and can only **NARROW** an already-authorized set. Attacked and proven. |
| CAN IT BE REPLAYED? | yes, and it is a no-op — `state='completed'` is terminal and outside its own filter. |
| CAN ONE SOURCE HAVE TWO ACTIVE HANDOFFS? | yes, for **different subjects**, capped at 5 (CORR-6). One per subject, by the partial unique index. |
| CAN ONE RECEIPT TARGET TWO DESTINATIONS? | no — `destination_user_id` is written once, at completion, from `auth.uid()`. |
| CAN SEARCH_PATH HIJACKING CHANGE WHAT A DEFINER FUNCTION CALLS? | no. `search_path=""`, every relation qualified, `pg_catalog.sha256` / `convert_to` / `gen_random_uuid` / `set_config` / `jsonb_populate_record` explicitly qualified. |

### 1.3 · What the live catalog disproved

| E1 assumed | the catalog said | recorded as |
|---|---|---|
| a delete on `storage.objects` executes | it raises 42501 from a **statement-level** trigger | **[CORR-1]** |
| `program_day_checks` has no per-user unique constraint | `UNIQUE (user_id, program_plan_id, program_day, item_key)` | **[CORR-4]** |
| the deterministic tail may be lowercased | production `observations.id` contains uppercase | **[CORR-2]** |
| `private` needs creating | it already exists, owner `postgres`, and **`authenticated` HAS USAGE on it** — so the `revoke` is load-bearing, not a belt to a schema wall | recorded |
| the family list was complete | `public.coach_messages` is in no list | **[CORR-5]** |

**Verified and TRUE:** all 43 columns E1 names exist with the expected
types · all four composite keys are as stated · `program_plans.phase`
accepts `'abandoned'` · `regimen_plans.end_reason` is unconstrained ·
**all 34 foreign keys to `auth.users` are CASCADE or SET NULL**, so the
retirement cannot fail on a constraint · `sha256`, `convert_to`,
`gen_random_uuid` are in `pg_catalog` on this server (Postgres 17.6) ·
zero user triggers on any table the transfer writes · `postgres` has
DELETE on `auth.users` and on `storage.objects`.

### 1.4 · The dry run

The corrected file was executed inside a transaction and **rolled back**
before it was applied for real. It created the table, both indexes and
all three functions, and the four grant assertions were checked inside
that transaction. Afterwards: table gone, functions gone, `auth.users`
4,292, `weight_logs` 3,282 — unchanged.

---

## 2 · APPLIED

| | |
|---|---|
| **file applied** | `supabase/migrations/20260814120000_v25_e1_account_handoffs.sql` |
| **SHA-256** | `5bf4897e93967370fb88f594ff16958fe9a03ba426c9ec59c3aa9b3b7db82ac3` |
| `41`'s staged file, unmodified | `453d41244ade4d52b1f6bce451a76d62e84de340eb7b18abf7da80441dd320e9` |
| **applied at** | 2026-08-15 ~02:45 UTC, project `mtecqvykyeueumdynatd` |
| migration history | `supabase_migrations.schema_migrations` version `20260814120000` |

**The applied file is NOT byte-identical to `41`'s.** `41` is left
unmodified as its own record; every difference is a `[CORR-n]` above and
is marked in the migration's own header.

### 2.1 · No customer row moved

29 tables counted before and after applying:

```
TABLES WITH DRIFT: 0
```

`auth.users` 4,292 · `weight_logs` 3,282 · `food_logs` 972 ·
`program_day_checks` 877 · `program_plans` 289 · `day_progress` 282 ·
`regimen_plans` 164 · `users` 2,942 · `observations` 70 · `dose_events`
14 · `day_reflections` 5 · `storage.objects` 0 — every one identical.

---

## 3 · VERIFIED FROM THE LIVE DATABASE

Not from "Success". From `pg_class`, `pg_proc`, `pg_constraint`,
`pg_indexes`, `pg_policies` and `has_*_privilege`.

| check | result |
|---|---|
| table exists · owner · RLS · policies | yes · `postgres` · **enabled** · **0** |
| table ACL | `postgres=arwdDxtm/postgres \| service_role=Dxtm/postgres` — **no `anon`, no `authenticated`, and service_role holds no read or write** |
| columns | 10, exactly as designed |
| constraints | PK · FK `source→auth.users ON DELETE SET NULL` · FK `destination→auth.users ON DELETE CASCADE` · `provider = 'apple'` · `state in ('open','completed')` · `subject_hash ~ '^[0-9a-f]{64}$'` |
| indexes | `account_handoffs_open_uniq (source_user_id, subject_hash) WHERE state='open'` · `account_handoffs_subject_open_idx` |
| function owner / security / volatility / config | all three: `postgres` · DEFINER · VOLATILE · `search_path=""` |
| `has_function_privilege('authenticated', 'begin_account_handoff', 'EXECUTE')` | **true** |
| `has_function_privilege('authenticated', 'complete_account_handoff', 'EXECUTE')` | **true** |
| `has_function_privilege('authenticated', 'private.transfer_account_rows', 'EXECUTE')` | **false** |
| the same three for `anon` and `service_role` | **false · false · false** |
| `authenticated` SELECT / INSERT / UPDATE on the table | **false · false · false** |

---

## 4 · THE AUTHORIZATION BOUNDARY, ATTACKED

`docs/app_v25/42_probes/H1_attack_authorization.sql` — **57 assertions,
0 failures**, inside one transaction that **rolled back**. Fixtures are
fixed test uuids; production counts were identical afterwards.

| attack | result |
|---|---|
| a PERMANENT account begins a handoff | **42501** — the named→named firewall, server-side |
| unauthenticated begins | **28000** |
| the email door | **22023** (CORR-3) |
| a malformed subject | **22023** |
| an ANONYMOUS account tries to RECEIVE | **42501** |
| **C completes and absorbs only its OWN committed source** | `{moved:1, retired:1}`, and A and A2 untouched, and C received **none** of A's rows |
| an unrelated destination with no matching receipt | `{moved:0, retired:0}` |
| **N names A as `p_source_user_id`** | `{moved:0, retired:0}` — **A still exists** |
| N tries `mode:'retire'` on A | `{moved:0, retired:0}` |
| an unknown mode | **22023** |
| an EXPIRED receipt | outside the filter, inert |
| a source that became permanent between BEGIN and COMPLETE | **skipped, never deleted, keeps its rows** |
| BEGIN twice | one row |
| the per-SOURCE cap | **54000** at the sixth |
| **direct INSERT into the receipt table** as `authenticated` | **42501** |
| **direct UPDATE of receipt state** | **42501** |
| **direct SELECT of receipts** | **42501** |
| **direct call to `private.transfer_account_rows`** | **42501** |
| **direct ownership rewrite** (`update weight_logs set user_id`) under RLS | **0 rows** |

> ▎ **THE ASSERTION IS NOT "THE RPC RETURNED AN ERROR". IT IS ZERO
> ▎ UNAUTHORIZED CUSTOMER ROWS CHANGED OWNER — and every one of the
> ▎ nine hostile cases above asserts a row count, not an error type.**

### 4.1 · The positive path, per family

| assertion | result |
|---|---|
| B completes its own committed handoff | `{moved:1, retired:1}` |
| the source's `auth.users` row | **gone** |
| weight ids | `A-W1,A-W2` — **preserved** |
| food id · `coach_messages` (CORR-5) | preserved · transferred |
| **observation id case (CORR-2)** | `<B>-foodNoise-…` present, `<B>-foodnoise-…` **absent** |
| dose prefix swap + destination wins its slot | both correct, two rows survive |
| weekly read prefix swap | correct |
| **day_progress: the destination's own day 1 survives with its own content** | `99`, unread and uncompared |
| A's day 7 followed · calibration destination-wins | yes · yes |
| **`day_reflections` transferred, destination wins the shared day** | `A-R2, B-R1` |
| the destination's plan stays live; A's arrives `abandoned` + `archived_at`, owned by B | yes |
| **care-team regimen REFUSED and removed** | 0 |
| **prescribed program fact REFUSED and removed** | 0; the preferred one followed |
| one live medication head; A's arrives `end_reason='ended'` | yes |
| the destination's profile untouched; the source's removed with the account | 170; 0 |
| **CORR-7: an empty destination inherits the source's profile** | `155/60` |
| the receipt | `completed` / digest **NULL** / source **NULL** / destination recorded |
| COMPLETE ×2 and ×3 | `{0,0}`, no duplicate weigh-ins |
| **CORR-8: a same-uid upgrade closes its own pre-link receipt** | 0 rows left, `{0,0}` moved |

---

## 5 · THE FAILURE BOUNDARIES

`docs/app_v25/42_probes/H2_failure_boundaries.sql` — **27 assertions, 0
failures**, one transaction, rolled back.

### §8 · Killed after BEGIN, nothing else happens

Receipt `open`, `completed_at`/`source_retired_at` both NULL, expiry ~30
days out. **The source still exists and still owns every row; the
destination received nothing.** A stale BEGIN cannot be weaponised:
redeeming it requires *being* the account that owns the pre-committed
subject, and once expired it is outside the filter entirely (proven).

### §9 · Killed after the destination authenticated — the defect `40` could not close

> ▎ **CAN THE SYSTEM DISCOVER THAT A HANDOFF IS OWED?**
>
> **YES, AND IT NEEDS NOTHING FROM THE DEVICE.**

`complete_account_handoff` **takes no arguments.** There is no bearer
token to persist, no uid in `UserDefaults`, no timestamp to guess from,
no profile to match. The server matches the caller's own
`auth.identities` rows against receipts the source pre-committed while
it was still authenticated. Proven: with zero client state,
`complete_account_handoff()` recovered the transition and moved her
record.

The client's route is `AppSync.dischargeOwedHandoffIfNeeded()`, called
unconditionally at launch for any permanent session. On a device with
nothing owed it is one indexed lookup returning `{0,0}`.

### §10 · Failure DURING complete — atomicity, forced

A constraint was injected so the transfer would fail **after**
weight/food/plans had already been rewritten, then COMPLETE was called:

```
S10a a mid-transfer failure raises            → 23514
S10b nothing moved (weight)                   → 0
S10c nothing moved (food)                     → 0
S10d nothing moved (plan)                     → 0
S10e source NOT retired                       → 1
S10f receipt rolled back to the retry state   → open
S10g source still owns everything             → 2
```

**Only BEFORE or AFTER is externally visible.** No "profile moved but
dose didn't", no "source deleted but records remain", no "receipt
complete but source still owns rows". There is no ladder because no
failure boundary requires one — `auth.users`, `storage.objects` and
every customer table are ordinary DML in the same transaction.

### §11 · Source retirement

The retirement cannot fail on its own; it shares the transaction. **The
obligation lives in `state='open'`**, which §10 proved survives a
failure. After success the source is gone, and a third call is harmless.

### §24 · Sign-out mid-handoff

The obligation is a **server** row. Signing out mints a fresh anonymous
uid on the device and cannot touch it; the local receipt survives the
isolation sweep (`41` §4, re-pinned this pass for the new id-policy
field). **No UI change was made and none is needed** — there is nothing
to refuse, because nothing is lost.

### §25 · Account delete during handoff — DELETE BEATS TRANSFER

The source deletes her account after BEGIN: the FK's `ON DELETE SET
NULL` **anonymises the receipt in the same statement**, the loop's
`source_user_id is not null` filter drops it, `{moved:0, retired:0}`,
and **her deleted rows never reappear**. If the DESTINATION deletes her
account, an `open` receipt has no destination yet so nothing cascades;
it expires. Named, not hidden.

---

## 6 · THE CLIENT

Five files. The smallest thing that speaks the verified protocol.

| file | what it is |
|---|---|
| `PlankApp/Auth/AccountHandoff.swift` **(new)** | the digest, the `sub` reader, two pure request builders, two classifiers, two never-throwing calls — and `HandoffIdPolicy` |
| `PlankApp/Auth/AuthService.swift` | BEGIN before the token exchange; COMPLETE after the switch; stand down the legacy retirement when the server retired |
| `PlankApp/Sync/AppSync.swift` | `dischargeOwedHandoffIfNeeded()` at launch; the id policy threaded through the carry; the receipt carries the server's answer |
| `PlankApp/Sync/IdentityMerge.swift` | the id policy for the other ten families |
| `PlankApp/Sync/DeletionLedger.swift` | `carry(from:to:)` — a tombstone follows the row it names |
| `Packages/PlankFood/…/FoodLogPersister.swift` | `reattributeEntries(preservingIds:)` |

### 6.1 · The three operations, and no fourth

`41`'s `AccountOperation` is unchanged and is still the only classifier.
The server now enforces the same rule independently: `begin_account_handoff`
raises 42501 unless `auth.users.is_anonymous`.

| | UPGRADE IDENTITY | ADOPT | SWITCH ACCOUNT |
|---|---|---|---|
| BEGIN | opens a receipt (before the link) | opens a receipt | **refused, 42501** |
| COMPLETE | **closes its own dead receipt**, moves nothing | moves and retires | never reached |
| id policy | n/a | `.preserve` when a receipt was opened | n/a |
| local carry | none | yes | none — isolation only |

### 6.2 · THE ID POLICY — the thing `41` said could not ship first

> ▎ **MINTING A FRESH ID AFTER A SERVER MOVE DUPLICATES HER ENTIRE
> ▎ RECORD. KEEPING ONE WITHOUT A SERVER MOVE STRANDS IT.**

The client has minted fresh uuids for weight, sessions, plans, checks
and food since v1.1 for a precise reason — RLS rejects a same-id upsert
of a row the old uid still owns. `complete_account_handoff(mode:'move')`
removes that reason, and then the old behaviour becomes the bug:
`pushLocalFoodEntriesMissingFromServer` diffs by id every launch, so a
fresh id makes every plate look absent from the server and uploads her
whole journal a second time.

**`.preserve` is written the moment a receipt EXISTS, and is never
downgraded**, because the two wrong guesses are not symmetrical:

- guessing `.mintFresh` when the server DID move → her record is
  duplicated, permanently, unrecoverably;
- guessing `.preserve` when it did NOT → her rows are re-keyed locally
  and unpushed, and **the very next launch repairs it** by completing
  the still-open receipt.

Under `.preserve` the carry also does **not** force `pendingUpsert`. It
leaves each row's flag alone: a row the server never received stays
owed (and its preserved id makes the push a clean INSERT), and a row the
server holds stays clean so `ProgramPlanMerge` adopts the server's
answer instead of the device pushing back over a decision the server
made from a better vantage point.

**Deterministic ids and composite keys are unaffected by the policy.**
The uid is inside the key, so both sides always do the same prefix swap
— and after CORR-2, to the same case.

### 6.3 · Degrade, never break

A project without the migration answers 404 (`PGRST202`). The client
catches it, `handoffOpened` stays false, the policy is `.mintFresh`, and
the behaviour is **byte-for-byte build 31**. Same for an offline BEGIN,
an id token with no `sub`, and the entire email door.

---

## 7 · THE 25 OWNERSHIP FAMILIES, RE-DERIVED AFTER IMPLEMENTATION

**`41` said twenty-four. It is TWENTY-FIVE** — `public.coach_messages`
was in no list (CORR-5). Derived from `pg_class` (37 public tables, of
which 24 carry a `user_id`/`patient_id`), from `grep -rlE "^\s*@Model"`,
and from the sweep lists.

| family | src local | src server | dest local | dest server | HANDOFF ACTION | after | id kept | provenance | delete kept | retry safe |
|---|---|---|---|---|---|---|---|---|---|---|
| profile `UserRecord` / `public.users` | yes | yes | maybe | maybe | **dest wins; source FILLS A TOTAL ABSENCE (CORR-7), else removed** | dest's own | PK is the uid | ✔ | n/a | ✔ |
| `weight_logs` | yes | yes | — | — | move | dest | **YES** | ✔ | ledger follows | ✔ |
| `food_logs` (+ items, corrections) | JSONL | yes | — | — | move | dest | **YES** | ✔ | ledger follows | ✔ |
| `session_logs` · `session_ratings` | yes | yes | — | — | move | dest | **YES** | ✔ | n/a | ✔ |
| `program_day_checks` | yes | yes | — | — | move, **guarded (CORR-4)** | dest | **YES** | ✔ | n/a | ✔ |
| `coach_messages` **(CORR-5)** | local | 0 rows | — | — | move | dest | **YES** | ✔ | n/a | ✔ |
| `dose_events` | yes | yes | maybe | maybe | prefix swap, dest wins the slot | dest | **the id dest would mint** | ✔ | ledger follows | ✔ |
| `observations` | yes | yes | maybe | maybe | prefix swap, **case preserved (CORR-2)** | dest | same | ✔ | ledger follows | ✔ |
| `weekly_reads` | yes | yes | maybe | maybe | prefix swap | dest | same | ✔ | n/a | ✔ |
| `day_progress` | yes | yes | maybe | maybe | **dest wins the day, whole row, content never compared** | dest's own | key holds the uid | ✔ | n/a | ✔ |
| `exercise_calibrations` | yes | yes | maybe | maybe | dest wins | dest's own | same | ✔ | n/a | ✔ |
| **`day_reflections`** | device keys | yes | maybe | maybe | **move; dest wins a shared day** | dest | **YES** | ✔ | n/a | ✔ |
| `program_plans` | yes | yes | maybe | maybe | move; **dest's live plan wins**, A's arrives archived | one live | **YES** | ✔ | n/a | ✔ |
| `regimen_plans` (self) | yes | yes | maybe | maybe | move; A's live med head arrives ENDED | one live | **YES** | ✔ | n/a | ✔ |
| **care-team regimen** | yes | 9 rows | — | — | **REFUSED and DELETED** | gone with A | — | **not forged** | n/a | ✔ |
| **prescribed `program_facts`** | yes | 0 rows | — | — | **REFUSED and DELETED** | gone with A | — | **not forged** | n/a | ✔ |
| other `program_facts` | yes | yes | — | — | move, chains follow | dest | **YES** | ✔ | n/a | ✔ |
| `consent_grants` | yes | yes | — | — | **REFUSED**; local removed, server cascades | gone with A | — | ✔ | n/a | ✔ |
| `BodyScanRecord` + JPEGs | yes | no | — | — | re-key in place | dest | **YES** | ✔ | n/a | ✔ |
| `JeniMemoryRecord` | yes | no | — | — | re-key in place | dest | **YES** | ✔ | n/a | ✔ |
| `move.manual.v1` | device | no | — | — | device-scoped: follows the PERSON | dest sees it | n/a | ✔ | n/a | ✔ |
| `day.note` / `day.reflection` / `day.sit` / `band` | device | partly | — | — | device-scoped | dest sees it | n/a | ✔ | n/a | ✔ |
| `safety_*` / `onb_*` | device | partly | — | — | device-scoped | dest sees it | n/a | **never inferred** | n/a | ✔ |
| `deletions.v1.<uid>` | device | no | — | — | **carried ONLY under `.preserve`** | translated | n/a | ✔ | **the point** | ✔ |
| clinic tables (`care_relationships`, `visit_packets`, `org_members`, `correction_requests`, `protocol_assignments`) | — | yes | — | — | **NOT transferred** — cascade with A | gone with A | — | **not forged** | n/a | ✔ |

**Not transferred by existing decision, unchanged:** `food_vision_telemetry`
· `jeni_chat_telemetry` (SET NULL, `38` §1.2) · `care_weekly_summaries`
(no FK, `40` §12 still unanswered) · `care_audit_events` ·
`patient_invitations.accepted_by` · `private.invitation_attempts` ·
`ops_events` (`40` §11's retention decisions).

### 7.1 · `public.day_reflections`, audited separately (§20)

| question | answer |
|---|---|
| does it transfer? | **YES**, and this is the first pass in which it does. Keyed `(user_id, day_key)`, destination wins a shared day. |
| does it hydrate? | **NO.** `AppSync.upsertDayReflection` writes; nothing reads back. Her evening words reach Jeni through the device-local `day.note.*` keys, which follow the person on an ADOPT by being device-scoped. Unchanged, and now stated. |
| does Jeni read it? | via `day.note.*` / `day.reflection.*` in `CoachContextAssembler`, not via the table. |
| does deletion remove it? | yes — CASCADE from `auth.users`. |
| does account deletion remove it? | yes, same cascade. |
| does named → named isolate it? | yes — `day.note.` and `day.reflection.` are prefix-swept by the isolation contract. |
| does a handoff preserve its identity? | yes — `id` preserved, `day_key` preserved. |
| does retry duplicate it? | no — the second pass matches nothing. |

**It is not family 25 discovered in pass 43. `coach_messages` was, and
it is closed.**

### 7.2 · REFUSED IS NOT REMOVED (§21) — what happens to the source copy

| refused family | the source copy |
|---|---|
| profile | **filled into an empty destination first (CORR-7)**, then DELETED with the account |
| local `ConsentGrantRecord` | DELETED locally (`41`); the server row cascades |
| care-team regimen | DELETED — no honest home exists under an account that clinic never met |
| prescribed program fact | DELETED |
| clinic relationship tables | DELETED by cascade. **NAMED CONSEQUENCE: all 10 care relationships in production have an ANONYMOUS patient, so the first handoff for such a patient ENDS her clinic relationship and she must re-accept an invitation under her new account. This is already true of the shipping client-side retirement; the migration makes it durable, not new. The clinic's own audit trail survives (`care_audit_events` has no FK).** Founder-visible, not fixed here. |
| `deletions.v1.<uid>` under `.mintFresh` | cleared once the carry commits — its ids can never match again |

**No retired uid leaves a customer-owned local fact unreachable
forever.** `41` §14's `footprint(source) == 0` still holds and is still
asserted.

---

## 8 · THE COLLISIONS, DECIDED IDENTICALLY ON BOTH SIDES

### 8.1 · Day progress (§17)

**A has day 1. B has day 1. What should B see?**

> ▎ **THE DAY THE ACCOUNT SHE IS KEEPING ACTUALLY LIVED.**

A day of the anonymous period is not evidence about a day the
destination account already lived, and the two cannot both be
`(user_id, program_day)`. The source row is DROPPED WHOLE — content is
never compared, never averaged, never "best of".

**It cannot depend on SwiftData's silent collapse**, which is `41`'s
finding, and it does not: the client checks the destination's keys and
returns the loser for deletion; the server deletes the colliding source
row before the update. Proven on both sides — the server test asserts
the destination's own `primary_hold_time` (99) survived untouched.

### 8.2 · Prescriptions do not follow the person (§18)

The deployed RLS refuses a client insert of a care-team regimen
(`authority='self' AND org_id IS NULL AND source_protocol_id IS NULL`)
or a prescribed fact (`authority <> 'prescribed'`). **They are equally
not the app's to MOVE.** Both sides delete rather than carry, and
**no authority is ever downgraded to make a row carryable** — rewriting
`care_team` to `self` would be fabricating a prescription's provenance.

A dose recorded against a refused care-team regimen **survives** with a
dangling `regimen_plan_id`: `dose_events.regimen_plan_id` has **no
foreign key** (verified), so her shots are not cascaded away with a
prescription that was never hers to move. Client and server agree.

### 8.3 · Program and regimen (§29, §30)

One live plan, always: **the destination's.** A's arrives `abandoned` +
`archived_at`, which is how this model already carries a superseded
enrollment — nothing discarded, no goal overwritten, no ASK for a
question that is not ambiguous. One live medication head: the
destination's; A's arrives `end_reason='ended'` so her dose eras stay in
the record. Supplements have no single authority and carry live.

**No target is published from a two-live-plan state, because that state
never exists** — the server resolves it inside the transaction, before
any client reads.

---

## 9 · THE DELETION LEDGER ACROSS AN ID-PRESERVING MOVE — [CORR] on `41` §19

`41` ruled the ledger must **never** cross into the destination, and
gave the right reason: *a deletion she made as one identity is not an
assertion about another account's rows.* That is exactly true **while
the carry mints fresh ids** — a tombstone for A's id names nothing that
exists under B.

**A server move breaks the premise, not the principle.** It is the same
physical row with the same id, now owned by B. A tombstone that named
that row still names it, and dropping it would let
`pushLocalFoodEntriesMissingFromServer` and the insert-only hydrates
resurrect a plate she deleted — `38`'s entire defect, re-opened by the
migration meant to make ownership honest.

> ▎ **A DELETION FOLLOWS THE ROW IT NAMES, AND ONLY WHEN THE ROW KEPT
> ▎ ITS NAME.**

`DeletionLedger.carry(from:to:)` runs **only** under `.preserve` and
**only** on a committed carry. Uid-prefixed ids are translated by the
same prefix swap the merge and the server both use; other ids copy
verbatim; an id it cannot derive is dropped rather than guessed at.
Under `.mintFresh` nothing crosses, exactly as `41` wrote.

**The remaining limitation, unchanged and not faked:** this is still
device-local. A deletion made on one phone does not reach another. Only
a server tombstone closes that, and it still cannot ship before a
filtering client reaches the installed base (`38` §6). **Not built.**

---

## 10 · CONSENT (§27)

Nothing here creates, broadens, transfers, re-grants or duplicates
consent. The clinic-facing scope is `visit_packet_view`, created and
revoked SERVER-side; the local `ConsentGrantRecord` writes
`visit_packet_sharing` and is refused **and removed**; `consent_grants`
cascades with the retired account. The transfer function writes nothing
to any consent table — provable by reading it: the word does not appear
outside a comment.

> ▎ **UNKNOWN CONSENT IS NEVER PERMISSION.**

---

## 11 · THE PROFILE, FIELD BY FIELD (§28)

Every class has an explicit rule. Nothing is inferred, nothing is
"probably".

| class | fields | rule |
|---|---|---|
| IDENTITY | `id` | **the PK IS the uid — it cannot move** |
| ONBOARDING HISTORY | goal · experience · motivation · barriers · prior attempts · focus | **B WINS** |
| CURRENT BODY FACT | height · weight · sex | **B WINS** — they drive `TargetsService` |
| GOAL | goal weight · goal date | **B WINS** (`29`) |
| PROGRAM FACT | activity · commitment days · pace | **B WINS** |
| **SAFETY FACT** | pregnancy · eating-pattern screen · pace cap · numeric suppression | **B WINS, AND NOTHING IS INFERRED** (`35`) |
| COHORT FACT | GLP-1 status/phase · medication · hormonal · sleep · stress · food relationship | **B WINS** |
| PREFERENCE | notification hour · units | device-level, existing decision |
| DEPRECATED | `program_status` · `program_intensity_tier` · `program_goal_date` | zero writers, zero readers; not merged |

**And the half `41` stated but did not implement:** when the destination
has **no** `public.users` row at all, the source's row is copied with
`id = p_dst` — monotone, never overwriting, inside the same transaction
(CORR-7). Proven on 200 real rows before it was written, and asserted in
the harness.

**No "A is newer". No "B is permanent". No safety inference. No clinic
inference.**

---

## 12 · REINSTALL AND TWO DEVICES (§22, §23)

`41` disproved *"local is a superset"*. This pass acts on it.

> ▎ **A SERVER-BACKED OWNERSHIP TRANSFER IS BASED ON SERVER TRUTH. LOCAL
> ▎ CONVERGENCE COMES AFTER.**

`private.transfer_account_rows` reads `public.*` — never the device. A
device that has hydrated nothing still transfers **food, weight, dose,
symptom, day reflection, program and regimen** in full, because the
handoff never asks the device what exists. *Not currently local* can no
longer be read as *does not exist*, because nothing consults the local
store to decide what moves.

`SourceRetirementSafety` (`41` §23) still gates the CLIENT's legacy
retirement on carrying at least one row — and it is now the fallback
rather than the mechanism, which is the right place for a heuristic.

**Two devices:** device 2 signing into B receives every transferred
family through B's normal hydrate, because they are B's rows. Old device
1 converges at its next launch: its receipt is `completed` or its
`open` one is discharged by `dischargeOwedHandoffIfNeeded`.
**Deletion cross-device semantics remain `38`'s known limitation and
were not touched.**

---

## 13 · RETRY EVERYTHING (§31)

| run twice | result |
|---|---|
| BEGIN | one row (partial unique index); the second call extends the expiry |
| destination auth callback | classified once; the operation is a pure function of four facts |
| COMPLETE | `{0,0}` — terminal state is outside its own filter. Proven twice AND a third time |
| local convergence | the carry only fetches rows keyed to the OLD uid |
| source retirement | the source is gone; the receipt is filtered out |
| relaunch recovery | `{0,0}` |

**No duplicate food, weight, dose, symptom, day reflection, plan,
regimen, profile, memory or movement. No widened consent. No duplicate
receipt. No resurrected deleted record.** Asserted in both harnesses and
over HTTP.

---

## 14 · PRODUCTION RUNTIME PROOF — THE REAL API, NOT A UNIT TEST

Two throwaway anonymous accounts were created **through the real GoTrue
endpoint** the app uses, exercised through **PostgREST** exactly as the
client does, and deleted. No pre-existing row was read or written.

| # | request | result |
|---|---|---|
| 1 | `POST /rest/v1/rpc/begin_account_handoff` as anonymous A | **HTTP 200**, receipt `2b33927b-…` |
| 2 | `POST /rest/v1/rpc/complete_account_handoff` as anonymous A | **HTTP 403** `42501 An anonymous account may not receive a handoff` |
| 3 | `GET /rest/v1/account_handoffs` as a real client | **HTTP 403** `permission denied for table account_handoffs` |
| 4 | `POST /rest/v1/rpc/transfer_account_rows` as a real client | **HTTP 404** `PGRST202` — the mover is not even in the schema cache |
| 5 | BEGIN as **permanent** B | **HTTP 403** `42501 Only an anonymous account may begin a handoff` |
| 6 | BEGIN with `provider: "email"` | **HTTP 400** `22023 Unsupported provider` (CORR-3) |
| 7 | **COMPLETE as destination B** | **HTTP 200** `{"moved": 1, "retired": 1}` |
| 8 | COMPLETE again | **HTTP 200** `{"moved": 0, "retired": 0}` |

And the database afterwards:

```
source_auth_row       0          ← retired, with no credential for it
dest_auth_row         1
weigh_in_owner        5047a119-…  ← the destination
weigh_in_id_kept      1           ← 'prod-proof-w1', ID PRESERVED
receipt_state         completed
receipt_source        NULL        ← anonymised by its own FK
receipt_digest        NULL        ← dropped at completion
receipt_retired_at    set
open_receipts_total   0
```

**The client's SHA-256 equalled the server's, byte for byte**, computed
independently on both sides (`1b8ff53d…`). That equality is now pinned
by a unit test against a vector production itself produced.

**Cleanup verified: 0 test users, 0 test identities, 0 test rows, 0
receipts — and 0 tables drifted from the pre-session baseline.**

---

## 15 · OLD-CLIENT COMPATIBILITY (§33)

| | BUILD 30 (live) | BUILD 31 (`41`) | BUILD 32 (this) |
|---|---|---|---|
| sign in · create anonymous users · link identity · switch account · delete account | **unchanged** | unchanged | unchanged |
| read/write normal tables | **unchanged** | unchanged | unchanged |
| accidentally call the new RPCs | **NO** — they call no function by these names | NO | deliberately, and only from an anonymous session |
| read a receipt | **NO** — 403 | NO | never tries |
| move another user's data | **NO — structurally impossible** | NO | NO |

Proven rather than asserted: **`delete_user_account` is still 266
characters and still contains no storage reference** — byte-identical to
before this session, so A1 remains unapplied and untouched. `public`
holds **38 tables and 38 with RLS**. The new table has **0 policies**.
`anon` still cannot select `weight_logs`; `authenticated` still can.
**Nothing outside the migration's own indexes depends on the new table.**

---

## 16 · OBSERVABILITY (§34)

The two-state design genuinely has no FAILED state, and none was
invented for a dashboard. An `open` receipt whose source is still
anonymous **is** the owed-retirement state, and it is countable:

```sql
select count(*) filter (where state = 'open'   and expires_at > now()) as pending,
       max(now() - created_at) filter (where state = 'open' and expires_at > now()) as oldest_pending,
       count(*) filter (where state = 'completed')                     as completed,
       count(*) filter (where state = 'open'   and expires_at <= now()) as expired_unredeemed
  from public.account_handoffs;
```

No health payload, no email, no Apple identifier, no uid leaves the
database — after completion the row holds neither the source's uid nor
the subject digest. **No analytics SDK event carrying health data was
added.** The client's only telemetry on this path is `40`'s existing
categorical exception when a retirement does not land.

---

## 17 · RED, MEASURED

`plankAITests/HandoffRuntimeTests.swift`, **16 tests.** With the pre-42
behaviour restored — `queuesAPush` always true, both `carriedId`
functions always minting, the food persister ignoring `preservingIds`,
`DeletionLedger.carry` a no-op, and the marker dropping the policy:

```
Executed 16 tests, with 10 failures (0 unexpected)
** TEST FAILED **
```

**10 assertion failures across 7 of 16 methods.** The nine that passed,
each classified:

| passed under the stub | class | why |
|---|---|---|
| `testTheSubjectDigestMatchesTheDeployedServerExpression` | **SERVER CONTRACT** | it pins the client against a vector production computed. A behavioural stub cannot change a hash function; its value is catching drift on either side, which no local stub simulates |
| `testTheAppleSubjectIsReadFromTheTokenAndGarbageIsRefused` | **SERVER CONTRACT** | same — the stub reverted behaviour, not the parser |
| `testNoRequestCarriesAnyIdentityAtAll` | **REFUSAL** | it asserts an ABSENCE (no uid on the wire). A stub that removes capability cannot make an absence present |
| `testAnUnappliedMigrationDegradesToTodaysBehaviour` | **CONTROL** | it describes the DEGRADE path, which *is* the pre-42 behaviour. The stub is what it asserts |
| `testAnUnreadableCompletionIsReportedAsHavingMovedNothing` | **REFUSAL** | a stub that never preserves ids trivially satisfies "assume nothing moved" |
| `testWithoutAServerMoveTheCarryStillMintsFreshIds` | **CONTROL** | it asserts the OLD behaviour is PRESERVED, and its green is the point: the new policy did not break the legacy path |
| `testADeterministicIdIsRewrittenIdenticallyUnderEitherPolicy` | **CONTROL** | prefix swapping predates this pass; this pins that the policy did not disturb it |
| `testAFreshIdCarryNeverCrossesTheLedger` | **REFUSAL** | `41`'s own rule, and a stub that never carries anything satisfies it. **It cannot tell "refused rightly" from "cannot act at all" — the NINTH session running** |
| `testNoIdPolicyMakesASwitchIntoAHandoff` | **CONTROL** | `40`'s shipped gate, re-pinned; not this pass's work |

**The server contracts do not go red under a client stub at all**, which
is why they are proven in the SQL harnesses instead — against the real
deployed function, where a mock would only prove the mock.

---

## 18 · GREEN, MEASURED

Every command run **serially**, unpiped, exit captured directly.

| suite | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/HandoffRuntimeTests` | 16 | **16** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` (full app) | 1346 | **1346** | **0** | `** TEST SUCCEEDED **` |
| PlankSync (`swift test`) | 9 | **9** | **0** | `Test Suite 'All tests' passed` |
| PlankFood (iOS sim) | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.7 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |
| **H1 attack harness** (production) | 57 | **57** | — | **0 failures** |
| **H2 failure harness** (production) | 27 | **27** | — | **0 failures** |
| **PostgREST end-to-end** (production) | 8 | **8** | — | **as expected** |

App suite **1330 → 1346, exactly +16**, which is `HandoffRuntimeTests`
and nothing else. **No existing test changed and none needed to** —
every new parameter is defaulted to the legacy behaviour.

### 18.1 · Release binary

`Release-iphoneos/plankAI.app/plankAI`, **86 MB, 124,458 strings** —
size and total stated first, because a zero from a file that does not
exist is the `Executed 0 tests` trap in different clothes (`35`).

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `debug-delete-account` | **0** |
| `begin_account_handoff` · `complete_account_handoff` | **1 · 1** |
| **`transfer_account_rows`** | **0** — the client cannot name the mover |
| **`account_handoffs`** | **0** — the client never names the table |
| `rest/v1/rpc/delete_user_account` | 1 — the legacy retirement still ships |
| `sync.pendingMergeV1` · `move.manual.v1` | 1 · 1 |
| `AccountHandoff` · `HandoffIdPolicy` · `LocalHandoffInventory` · `IdentityMerge` (`nm`) | 46 · 3 · 41 · 111 |

**No new DEBUG door was added.**

### 18.2 · Protected paths

| path | vs `1710180` | this session |
|---|---|---|
| `PlankApp/Payment` · `Views/Paywall` | **EMPTY** | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** | **EMPTY** |
| `PlankApp/Analytics` | `31`'s +6 | **EMPTY** |
| `supabase/functions` | `27`'s undeployed food-vision EF | **EMPTY** |
| `scripts/` | — | **EMPTY** |
| **`supabase/migrations`** | — | **+1 FILE — and that is the point of this pass** |
| `PlankApp/Auth` · `PlankApp/Sync` | `41`'s, plus this pass | **MOVED** |
| `Packages/PlankFood` | `26`/`27`/`31`/`34`/`38`, plus this pass | **MOVED** — one additive, defaulted parameter |

**All three files that declare a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **ZERO DIFF
against `1710180`**, re-derived this session with
`grep -rlE "^[[:space:]]*@Model"`. **There is no SwiftData store
migration to fail.**

The `project.pbxproj` diff contains **only file references** — verified
by filtering out every `PBXBuildFile` / `PBXFileReference` /
group-child line and getting an empty result. **`CURRENT_PROJECT_VERSION`
is still 30**, `MARKETING_VERSION` still `1.2.0`.

### 18.3 · This session's files

`supabase/migrations/20260814120000_v25_e1_account_handoffs.sql`
**(new — APPLIED)** · `PlankApp/Auth/AccountHandoff.swift` **(new)** ·
`PlankApp/Auth/AuthService.swift` · `PlankApp/Sync/AppSync.swift` ·
`PlankApp/Sync/IdentityMerge.swift` · `PlankApp/Sync/DeletionLedger.swift` ·
`Packages/PlankFood/…/FoodLogPersister.swift` ·
`plankAITests/HandoffRuntimeTests.swift` **(new, 16 tests)** ·
`plankAI.xcodeproj/project.pbxproj` (two file references) ·
`docs/app_v25/42_probes/` **(6 new)** ·
`docs/app_v25/42_packages/A1_CORRECTED_…sql` **(new, staged)** ·
this document.

---

## 19 · CORRECTIONS TO THE RECORD

`41` is **not rewritten.** The history of how the architecture was
disproven is the most useful thing in this series.

**[CORR] on `41` §13 and the E1 header** — *"Storage is deleted inside
the same transaction"* was never reachable. `storage.objects` refuses a
direct delete from any statement, matching or not. **[CORR-1].**

**[CORR] on `40` §11 / `41` §27 — Package A1's safety matrix.** *"It
deletes strictly more, and today there is nothing more to delete"* is
false: the guard fires on the STATEMENT, so A1 would have broken account
deletion for every customer. `41` re-verified A1's assumptions and found
them true — they are. **The assumption nobody tested was that the
statement would execute.**

**[CORR] on `41` §8 and §24 — `program_day_checks` "cannot collide".**
That reasoning belongs to the CLIENT's fresh-uuid plan re-key; the
server preserves plan ids. **[CORR-4].**

**[CORR] on `41` §11 — the residual is not only injection.** The
`email` provider makes an EXFILTRATION path out of a typo. **[CORR-3].**

**[CORR] on `41` §2.1 / §37 answer 8 — the count is TWENTY-FIVE**, not
twenty-four. `public.coach_messages` was in no list. **[CORR-5].**

**[CORR] on `41` §19 — the deletion ledger.** The rule was right for the
carry it was written against and wrong for an id-preserving server move.
**A deletion follows the row it names, and only when the row kept its
name.** §9 above.

**[CORR] on `41` §25 — the profile.** The stated rule had two halves and
the server implemented one. **[CORR-7].**

**[CORR] on `41` §12 — the pre-link receipt.** *"a cancelled sheet
writes nothing"* is true, but a SUCCESSFUL link still leaves an open
receipt naming its own caller. Inert, and now closed rather than left.
**[CORR-8].**

---

## 20 · APPLE REVOCATION (§37)

**Untouched, and no `.p8` work was done.** `authorizationCode` is still
not captured; B1/B2 remain READY and blocked on the key. Account
deletion completes whether or not Apple revocation ever runs — they are
separate contracts sharing a screen. Nothing in this pass moved either
way.

---

## 21 · NO HISTORICAL REPAIR (§35)

**Nothing was touched, joined, matched or inferred.** The four
populations `40` named are unchanged. `scripts/cleanup_orphaned_anon_users.sql`
was not run and **must never be run**. `scripts/reap_abandoned_anon_accounts.sql`
was not run; at a defensible window it still matches **zero**, because
the project is **106 days old** (re-measured this session). `scripts/`
has an **EMPTY** diff.

**This pass prevents future orphans. It does not invent ownership of old
ones.**

---

# THE TWENTY-FIVE ANSWERS

**1 · IS E1 ACTUALLY DEPLOYED?** **YES** —
`20260814120000_v25_e1_account_handoffs.sql`, SHA-256
`5bf4897e…`, recorded in `supabase_migrations.schema_migrations`.

**2 · DOES LIVE POSTGRES MATCH THE FILE?** **YES**, and the file is not
`41`'s. Table, both indexes, all six constraints, three functions, all
owners/security/volatility/`search_path`, and every grant — read back
from `pg_class` / `pg_proc` / `pg_constraint` / `pg_indexes` /
`has_*_privilege`.

**3 · CAN PUBLIC EXECUTE ANY PRIVILEGED HANDOFF FUNCTION?** **NO.** The
ACLs are explicit and contain no bare `=X/`.

**4 · CAN ANON?** **NO** — false for all three, at the catalog and over
HTTP.

**5 · WHAT CAN AUTHENTICATED EXECUTE?** Exactly
`public.begin_account_handoff(text,text)` and
`public.complete_account_handoff(uuid,text)`. **Not**
`private.transfer_account_rows`, which PostgREST cannot even see.

**6 · CAN A CLIENT CHOOSE AN ARBITRARY SOURCE UID?** **NO.** BEGIN takes
no source (`auth.uid()`); COMPLETE's `p_source_user_id` can only NARROW
an already-authorized set. Attacked from an unrelated permanent account
naming a real anonymous uid: `{moved:0, retired:0}`, and **A still
existed.**

**7 · CAN A CLIENT CHOOSE AN ARBITRARY DESTINATION UID?** **NO. There is
no destination parameter.** It is always `auth.uid()`.

**8 · CAN B ABSORB RANDOM ANONYMOUS A?** **NO.** Only a receipt A itself
opened, pre-committed to a subject B demonstrably owns. Proven: C
absorbed only its own committed source and received none of A's rows.

**9 · DOES ANONYMOUS → NEW APPLE STILL KEEP THE UID?** **YES** — `39`'s
`linkIdentityWithIdToken`, untouched. Still the founder's one-line
device check.

**10 · DOES THAT PATH MOVE ZERO CUSTOMER ROWS?** **YES.** It classifies
as `.upgradeIdentity`, whose three permissions are all false; the merge
refuses a same-uid pair by construction; and COMPLETE returns `{0,0}`
while deleting the dead pre-link receipt. Asserted on both sides.

**11 · DOES ANONYMOUS → EXISTING B COMPLETE THROUGH THE SERVER?**
**YES**, in production, over PostgREST: `{"moved": 1, "retired": 1}`,
the source's `auth.users` row gone, her weigh-in under B **with its id
unchanged**.

**12 · IF THE CLIENT DIES AFTER B AUTHENTICATES, WHAT RECOVERS IT?**
`complete_account_handoff()` — **called with no arguments at all**, from
`AppSync.dischargeOwedHandoffIfNeeded()` at launch. It needs no token
for A, no local marker, no uid and no guess. Proven with zero client
state.

**13 · IF SOURCE RETIREMENT FAILS, WHERE DOES THE OBLIGATION LIVE?** In
`public.account_handoffs.state = 'open'`, on the server. Proven by
forcing a mid-transfer failure: the receipt rolled back to `open`, which
is already the retry state.

**14 · CAN THAT OBLIGATION SURVIVE SIGN-OUT?** **YES** — it is a server
row; signing out cannot reach it. (The local receipt survives the sweep
too, and now carries the id policy.)

**15 · CAN IT SURVIVE REINSTALL?** **YES**, for the same reason, and
this is the case `40` and `41` could not close. The transfer reads
server truth, so a device that has hydrated nothing still moves
everything.

**16 · CAN NAMED → NAMED MOVE ANY SERVER RECORD?** **NO.** Three
independent gates: the client's `AccountOperation` (positive proof of
anonymity), `begin_account_handoff`'s 42501, and
`complete_account_handoff`'s re-check at use **and** on the DELETE
itself. Proven over HTTP: `Only an anonymous account may begin a
handoff`.

**17 · CAN NAMED → NAMED LEAK ANY LOCAL CUSTOMER WORD?** **NO** —
`41`'s isolation sweep runs first on a SWITCH, covering `move.manual.v1`,
`day.note.*`, `day.reflection.*`, `day.sit.*`, `band.*`, `safety_*`,
`onb_med_*` and the rest by prefix. Re-derived this session from the
shipping list, not inherited.

**18 · WHAT IS THE REAL OWNERSHIP-FAMILY COUNT NOW?** **TWENTY-FIVE.**
`41` said twenty-four; `public.coach_messages` was in no list at all.

**19 · WHAT HAPPENS TO DAY-PROGRESS COLLISIONS?** **The destination's
own day wins, whole row, content never compared** — on both sides, by
an explicit rule rather than by SwiftData's silent collapse or
Postgres's error. Proven: B's `primary_hold_time` survived untouched and
A's non-colliding day followed.

**20 · CAN A CARE-TEAM PRESCRIPTION CROSS ACCOUNTS?** **NO.** Refused
and deleted on both sides; no authority is ever downgraded to make a row
carryable. Her doses recorded against it survive (no FK).

**21 · WHAT HAPPENS TO PUBLIC.DAY_REFLECTIONS?** It **transfers** for
the first time, keyed `(user_id, day_key)`, destination wins a shared
day, id preserved, retry-safe, cascaded on deletion, isolated on a
switch. **It still does not hydrate** — named, unchanged, and not
smuggled in as a feature.

**22 · IS COMPLETE IDEMPOTENT?** **YES** — proven three times in the
harness and twice over HTTP. `{0,0}`, no duplicates.

**23 · WHAT REMAINS UNSAFE ACROSS TWO DEVICES?** **Deletion
propagation, and only that.** A record deleted on one phone can still be
pushed back by a stale second phone; the device-local ledger removes it
again and re-asserts the server delete, and it flaps until the other
device updates. Only a server tombstone closes it, and it still cannot
ship before a filtering client reaches the installed base (`38` §6).
**Unchanged, out of scope, not faked.**

**24 · WHAT IS THE NEXT SERVER MIGRATION, IF ANY?**
**`docs/app_v25/42_packages/A1_CORRECTED_delete_user_account_storage_purge.sql`**
— and it is now urgent for a new reason: the file `40` staged would
break account deletion outright. After it, `40`'s A2 and A3. **None is
applied.**

**25 · SAFE FOR BUILD 31: YES.** The schema is additive and invisible to
build 30. The client degrades to build 31's exact behaviour on a 404. No
arithmetic moved, no `@Model` changed, no paywall/payment/auth-phase
path moved, `CURRENT_PROJECT_VERSION` still 30.

---

# SCORECARD

Graded hard. Anything below 9 names the exact blocker.

| domain | `41` | now | the exact blocker |
|---|---|---|---|
| **LIVE SERVER CONTRACT** | 7 | **10** | Applied, verified from the catalog, exercised over the real API. |
| **AUTHORIZATION** | 9 | **10** | No identity is an input anywhere. Nine hostile cases assert row counts, not error types. |
| **ACCOUNT-TAKEOVER RESISTANCE** | 9 | **9** | The `email` exfiltration path is closed; the injection residual remains: an attacker who already holds a victim's Apple `sub` could pre-commit their own anonymous rows. Bounded by two caps, named, not zero. |
| **SAME-UID UPGRADE** | 10 | **10** | Carries nothing, mints nothing, and now cleans up its own pre-link receipt. |
| **EXISTING-ACCOUNT HANDOFF** | 9 | **10** | Server-side, id-preserving, one transaction, proven in production. |
| **NAMED-ACCOUNT ISOLATION** | 10 | **10** | Three independent gates, one of them now enforced by Postgres. |
| **LOCAL CONVERGENCE** | 10 | **10** | One inventory, one orchestrator, and the id policy follows the server's answer rather than a guess. |
| **SERVER CONVERGENCE** | — | **10** | Two states, second terminal, atomic. Forced mid-transfer failure rolls back whole. |
| **CRASH RECOVERY** | 9 | **10** | Recovery needs no local state at all: the RPC takes no arguments. |
| **REINSTALL RECOVERY** | 8 | **10** | The transfer reads server truth; a sparse device no longer decides what exists. |
| **SOURCE RETIREMENT** | 7 | **10** | Durable, retryable, and needs no credential for the retired account. Proven in production. |
| **IDEMPOTENCY** | 9 | **9** | Every action is idempotent on both sides. **Blocker: an RPC that succeeds with a lost response is still indistinguishable from one that failed. For the HANDOFF the receipt closes it; for ACCOUNT DELETION it does not, and that needs its own idempotency key.** |
| **PROGRAM CONFLICT SAFETY** | 10 | **10** | One live plan, one live medication head, destination wins, A's survives as history, nothing fabricated. |
| **CLINICAL PROVENANCE** | — | **9** | Prescriptions never follow the person, on either side, and nothing is downgraded. **Blocker: retiring an anonymous source ENDS her clinic relationship — 10 of 10 in production are anonymous. Already true of build 31; named here, and a founder decision.** |
| **CONSENT** | 10 | **10** | Nothing creates, broadens, transfers, re-grants or duplicates it. |
| **DELETION INTERACTION** | 9 | **9** | Delete beats transfer, proven; the ledger now follows an id-preserving move. **Blocker: deletion still does not propagate to a second device — `38`'s tombstone, unchanged and out of scope.** |
| **OLD-CLIENT COMPATIBILITY** | 10 | **10** | `delete_user_account` byte-identical, 0 policies added, RLS coverage unchanged, the receipt table unreachable and depended on by nothing. |
| **PRODUCTION OBSERVABILITY** | — | **9** | Countable from the real state machine with no health data and no invented FAILED state. **Blocker: it is a SQL query a founder runs, not an alert — there is no scheduled check that a pending handoff has aged.** |

---

# THE FIVE BUCKETS

### SHIPPED CLIENT
1. `AccountHandoff` — the digest, the `sub` reader, both requests, both
   classifiers, and the two never-throwing calls.
2. **BEGIN before the token exchange**, while the source is still the
   account that owns the record.
3. **COMPLETE after the switch**, as the destination — which is what
   makes the retirement durable and needs no credential for A.
4. **`dischargeOwedHandoffIfNeeded()` at launch** — the recovery that
   needs no local state.
5. **`HandoffIdPolicy`**, threaded through the whole carry, the food
   persister and the receipt.
6. **`DeletionLedger.carry`** — a tombstone follows the row it names.

### DEPLOYED SERVER
1. **`public.account_handoffs`** + the partial unique index + the
   subject index, RLS on, no policies, no grants.
2. **`public.begin_account_handoff(text, text)`** — apple only,
   anonymous only, two caps.
3. **`public.complete_account_handoff(uuid, text)`** — no identity in,
   subjects computed server-side, one transaction.
4. **`private.transfer_account_rows(uuid, uuid)`** — 25 families, every
   collision decided, execute revoked from every client role.

### READY — DO NOT DEPLOY
1. **`42_packages/A1_CORRECTED_…sql`** — and **`40`'s A1 must NOT be
   applied**; it would break account deletion for every customer.
2. **A2** `patient_invitations.accepted_by` → `SET NULL`. Unchanged, and
   sharper: all 10 accepted rows are anonymous patients — exactly the
   population a handoff retires.
3. **A3** three `comment on table` retention decisions. Unchanged.
4. **B1/B2** the Apple token store + revocation EF. Unchanged, blocked
   on a `.p8`.
5. `scripts/reap_abandoned_anon_accounts.sql` — steps 1–2 read-only,
   step 3 commented out. Still matches zero.

### FOUNDER ACTION
1. **Read §0 finding 2 before touching Package A**, then apply the
   CORRECTED A1 and delete a throwaway account through the app to prove
   it. **Do not apply `40`'s A1.**
2. **The device check after the first Apple sign-in on this build** —
   the one thing no harness here can do: `linkIdentityWithIdToken`
   against this project's live GoTrue.
3. **Answer `40` §12** — OPTION A or B for `care_weekly_summaries`.
   Still zero rows. Now five passes overdue.
4. **Decide the clinic consequence** (scorecard: CLINICAL PROVENANCE) —
   a handoff ends an anonymous patient's clinic relationship.
5. Confirm A2 and A3's sentences, then apply them.
6. Create the Apple `.p8` (`40` §17).
7. **The archive-time bump to build 31.**

### DO NOT TOUCH YET
1. **The server tombstone.** Still blocked on a filtering client
   reaching the installed base (`38` §6).
2. **`scripts/cleanup_orphaned_anon_users.sql`** — superseded; never
   run it.
3. **Historical orphan repair.** Attribution is impossible and remains
   so. No ownership relation has become provable, and none was invented.
4. **The `food-photos` bucket.** Creating it before the corrected A1
   opens the storage hole for real.
5. **Widening the handoff to `email`.** It needs a way to prove the
   destination BEFORE the sign-in, and there isn't one today.
6. **Syncing Jeni memory, chat, movement or body scans.** A handoff that
   follows the person on one phone is not the same as a record that
   follows her to a second one.

---

# THE FINAL GATE

> ▎ **IF THE CUSTOMER IS ANONYMOUS A AND APPLE RESOLVES TO EXISTING B,
> ▎ CAN THE APP DIE AT ANY POINT WITHOUT LOSING THE FACT THAT A → B IS
> ▎ OWED?**

**YES.**

*The invariant:* the fact is a **server** row, written while A was still
authenticated, and the call that redeems it **takes no arguments**. No
token, no marker, no uid, no timestamp. Every crash row in the matrix —
before BEGIN, after BEGIN, after the credential, after the link attempt,
after the session arrives, mid-transfer, after retirement, after a
sign-out, after a reinstall — converges, and each was exercised.

> ▎ **CAN ONE FAILED SOURCE-RETIREMENT REQUEST CREATE A PERMANENT
> ▎ ORPHAN?**

**NO.**

*The invariant:* the retirement shares the transaction with the
transfer, so it cannot fail alone; and if the whole transaction fails,
the receipt rolls back to `open`, **which is already the retry state**.
`41`'s honest residue is closed. Forced and measured.

> ▎ **CAN NAMED ACCOUNT A TRANSFER A SINGLE CUSTOMER-OWNED FACT INTO
> ▎ NAMED ACCOUNT B MERELY BY SWITCHING ACCOUNTS?**

**NO.**

*The invariant:* three independent gates, and one of them is now
Postgres refusing a permanent caller with `42501` — proven over HTTP.
The device-scoped half is swept first, before anything reads for the
incoming account.

> ▎ **CAN A CARE-TEAM PRESCRIPTION FOLLOW THE HUMAN INTO AN ACCOUNT THAT
> ▎ CARE TEAM NEVER AUTHORIZED?**

**NO.**

*The invariant:* refused and deleted on both sides, and **no authority
is ever downgraded to make a row carryable.** The RLS that forbids the
client from authoring one is the same sentence that forbids the server
from moving one.

> ▎ **CAN A MALICIOUS AUTHENTICATED CUSTOMER ABSORB AN ANONYMOUS UID
> ▎ THEY DO NOT CONTROL?**

**NO.**

*The invariant:* **no identity is a trusted input.** There is no
destination parameter; the source parameter can only narrow a set the
server computed from the caller's own identity rows; and the
pre-commitment can only be written by a client holding the source's
session. Attacked from three directions and asserted as **zero
unauthorized rows changed owner.**

> ▎ **HAS THE ACTUAL PRODUCTION SERVER CONTRACT BEEN EXERCISED, NOT
> ▎ MERELY UNIT-TESTED?**

**YES.** Through the real GoTrue signup endpoint and the real PostgREST
RPC surface, with the client's own request shape and the client's own
digest — `{"moved": 1, "retired": 1}`, the source retired, her weigh-in
under the destination with its id unchanged, and every test identity
deleted afterwards. **Zero tables drifted from the pre-session
baseline.**

---

**SAFE FOR BUILD 31: YES.**

**HANDOFF CLOSED: NO.**

**THE ONE BLOCKER:** *the Apple link itself has still never been
executed against this project's live GoTrue.* Every branch after it is
now proven — the receipt, the transfer, the retirement, the recovery,
the refusals — but `linkIdentityWithIdToken` succeeding (and therefore
the same-uid upgrade being the common path rather than the collision
handoff) rests on `39`'s reading of the SDK and nothing else. It is one
device, one sign-in, one line of the console.

---

> ▎ **THE LOGIN MAY CHANGE.**
> ▎ **THE DEVICE MAY DIE.**
> ▎ **THE NETWORK MAY FAIL.**
> ▎ **THE RECORD STILL HAS ONE OWNER.**
