# 45 · MAKE THE SPINE REAL

**THE ONE REMAINING P1, CLOSED (feat/app-v2). APPLIED TO PRODUCTION
2026-08-15.**

▎ **IF THE PRODUCT CALLS SOMETHING ACCOUNT-DURABLE, PROVE THAT IT
▎ ACTUALLY LEAVES THE PHONE AND COMES BACK.**

---

## EXECUTIVE VERDICT

**It leaves the phone and it comes back. Measured, not inferred.**

`44` left exactly one P1: `public.program_facts` and
`public.weekly_reads` held zero rows because `authenticated` had no
privileges on either, so E1 THE SPINE — the authority chain the whole
v25 line stands on — had never synced, for anyone, since 2026-08-10.

This pass re-proved the failure from the live catalog, audited `44`'s
`G1` as hostile input, applied it as a recorded migration, verified the
result against the catalog, attacked the RLS over the real API with four
throwaway identities, and then proved the shipping client end to end.

**Three things the pass found that `44` did not.**

▎ ① **IT WAS NEVER "ONE MIGRATION REMEMBERED AND THE NEXT FORGOT".
▎ THIS PROJECT'S DEFAULT PRIVILEGES GRANT NO DATA API AT ALL.**

From `pg_default_acl`, grantor `postgres`, schema `public`, tables:

```
anon=Dxtm  authenticated=Dxtm  service_role=Dxtm
```

`D`=TRUNCATE `x`=REFERENCES `t`=TRIGGER `m`=MAINTAIN. **None of
SELECT/INSERT/UPDATE/DELETE.** Every migration in this repo runs as
`postgres`, so **every table it creates in `public` is born with no
data-API privilege whatsoever.** The tables that work carry an explicit
`grant`; the tables that do not, do not. The defect class is therefore
not a lapse of style — it is structural, it fires silently every time,
and it is mechanically checkable. `44`'s diagnosis was right; the
mechanism is sharper than it recorded.

▎ ② **THE SAME DEFECT IS ON A THIRD SHIPPING TABLE, AND ITS FIX MUST
▎ NOT SHIP FIRST.**

`public.care_weekly_summaries` carries three RLS policies and zero
grants, and `SyncService.publishWeeklySummary` writes it from the app —
from `AppSync.onLaunch`, on every launch, outside `#if DEBUG`. So the
call is live and it cannot succeed.

It is **deliberately excluded from this pass.** `care_weekly_summaries`
has **no foreign key to `auth.users`** (`37` §16, `38` §4, `44` P2 #7),
so granting INSERT before the FK lands converts *"0 rows, latent"* into
*"rows that survive account deletion"* — the `food-photos` ordering, one
table over. **P2, sequenced, named for `46`.**

▎ ③ **NO CUSTOMER LOST ANYTHING, AND THAT IS A MEASUREMENT, NOT A HOPE.**

Since 2026-08-10 there have been **340 `program_fact_changed` events
across 66 identities — and 340 of 340 carry `environment: debug` and
`is_test_user: true`.** In the same window the same project recorded
**2,492 `environment: production` events from 54 people**, so the
property is live and the absence is evidence. Under
`24_MEASUREMENT_CONTRACT.md` **zero production customers have ever
written a program fact or a weekly read.** Every write that did happen
still sits on its own device with `pendingUpsert = true`, and
`retryPendingUpserts` runs on every launch — so the backlog pushes
itself with no repair code and nothing to reconstruct.

**P0 REMAINING: 0. P1 REMAINING: 0. Build 31 is a true release
candidate.**

---

## WHY THE SPINE NEVER SYNCED

`20260810090000_v25_e1_program_spine.sql` creates both tables, enables
RLS and writes **nine `create policy` statements and zero `grant`
statements.** With the project's default ACL granting no data privilege,
the policies were decorative: PostgREST never reached the point of
evaluating one.

Four calls, four refusals, every launch:

| call | site | result |
|---|---|---|
| `upsertProgramFact` | `SyncService.swift:1340` | 42501, `try?`, swallowed |
| `hydrateProgramFacts` | `SyncService.swift:1391` | 42501, `catch` prints under DEBUG only |
| `upsertWeeklyRead` | `SyncService.swift:1468` | 42501, `try?`, swallowed |
| `hydrateWeeklyReads` | `SyncService.swift:1515` | 42501, `catch` prints under DEBUG only |

No number moves, no screen changes, no test fails — the local store
answers every read correctly because it is the only store there is. The
client's own comments deny it in writing: `ProgramFactStore
.bootstrapIfNeeded` says *"a second device must see the first device's
migration rows and write nothing"*, and `hydrateAndSync` orders
`hydrateProgramFacts` **before** the bootstrap for exactly that reason.
The ordering is correct and the call had never returned a row.

---

## LIVE PRIVILEGES BEFORE

`docs/app_v25/45_probes/P1_live_privileges_before.sql` — read only,
mechanically proven (1 statement, first word `with`, 0 write-keyword
hits) by `prove_read_only.py`, then executed.

```
                       SELECT  INSERT  UPDATE  DELETE
program_facts  anon      f       f       f       f
               authenticated  f  f       f       f
               service_role   f  f       f       f
weekly_reads   anon      f       f       f       f
               authenticated  f  f       f       f
               service_role   f  f       f       f

relacl  postgres=arwdDxtm ; anon=Dxtm ; authenticated=Dxtm ; service_role=Dxtm
RLS     enabled=true  forced=false     policies=4 on each table
rows    program_facts 0 · weekly_reads 0
column-level grants   REFERENCES only (the table-level `x`, expanded) —
                      nothing hiding underneath
```

**WHAT EXACTLY RETURNED 42501, MEASURED OVER THE REAL API** (not
inferred — `45_probes/api_proof.py before`, four throwaway identities,
publishable key only):

```
A anon INSERT own program_fact      403 · 42501
B anon SELECT own program_fact      403 · 42501
C perm INSERT own program_fact      403 · 42501
D perm SELECT own program_fact      403 · 42501
E anon INSERT own weekly_read       403 · 42501
F anon SELECT own weekly_read       403 · 42501
G perm INSERT own weekly_read       403 · 42501
H perm SELECT own weekly_read       403 · 42501
upsert-as-update, PATCH             403 · 42501
unauthenticated anon role           401 · 42501
```

PostgREST even printed the repair in its own `hint`:
*"Grant the required privileges to the current role with: GRANT SELECT
ON public.program_facts TO authenticated;"* — a sentence nobody had ever
seen, because the `catch` that received it only printed under DEBUG.

**23 of 23 assertions passed; every throwaway account deleted; counts
back to 4293 / 3426 / 867.**

---

## G1 AUDIT

`docs/app_v25/44_packages/G1_e1_spine_grants.sql`, read as hostile input.

| statement | why required | shipping call site | role | still limited by |
|---|---|---|---|---|
| `grant select on program_facts` | the hydrate reads it, **and the shipping upsert needs it** | `hydrateProgramFacts`; `upsert` with `return=representation` | `authenticated` | `program_facts_select_own` |
| `grant insert on program_facts` | a new fact version | `upsertProgramFact` | `authenticated` | `..._insert_own` + `authority <> 'prescribed'` |
| `grant update on program_facts` | the upsert's `ON CONFLICT DO UPDATE`; same-day coalesce; supersede stamp | `ProgramFactStore.apply`, `retryPendingUpserts` | `authenticated` | `..._update_own` + `authority <> 'prescribed'` |
| `grant select/insert/update on weekly_reads` | as above | `upsertWeeklyRead` / `hydrateWeeklyReads` | `authenticated` | `weekly_reads_*_own` |

**VERDICT: G1 IS SUBSTANTIVELY CORRECT AS WRITTEN.** The privilege set
is exactly minimal, the reasoning for withholding DELETE is right, and
the `authenticated`-only target is right. Three things it did not say,
all of which are now in the applied migration:

1. **SELECT is load-bearing on the WRITE path, not only the read path.**
   `PostgrestQueryBuilder.upsert` defaults `returning: .representation`
   (read from the vendored SDK), so the shipping statement sends
   `Prefer: resolution=merge-duplicates,return=representation` and
   PostgREST must read the row back. Anyone trimming this to "INSERT
   only" would break the write.
2. **UPDATE is required on the very first write.** PostgREST's upsert is
   `INSERT … ON CONFLICT DO UPDATE`, which Postgres requires UPDATE to
   plan at all — and it is genuinely exercised afterwards by the
   same-day coalesce, the supersede stamp, and every re-push.
3. **`TO authenticated` INCLUDES EVERY ANONYMOUS CUSTOMER**, and that is
   the most important sentence about this grant in this product.

**COULD THE GRANT EXPOSE ANOTHER CUSTOMER'S ROW?** No. Every policy keys
on `(select auth.uid()) = user_id`, and `auth.uid()` reads the verified
JWT subject — a client-supplied `user_id` can only narrow. Attacked in
both directions after applying; results below.

**COULD AN ANONYMOUS SUPABASE USER USE IT?** Yes. A Supabase anonymous
user carries the Postgres `authenticated` role.

**SHOULD SHE?** **Yes**, proven from the product, not assumed:

- **3,426 of 4,293 accounts are anonymous.** The app is anonymous-first.
- The spine's writers run long before any sign-in — onboarding, the
  bootstrap migration, `AdaptiveStepsEngine`, the weekly read, and
  `propose_program_fact` from chat.
- `private.transfer_account_rows` **already moves both families from an
  anonymous source to a permanent destination** (read from the live
  `pg_proc`, and exercised in this pass). A spine an anonymous period
  could never write would give the handoff nothing to move.
- No sibling family carries an `is_anonymous` restriction —
  `dose_events`, `observations`, `weight_logs`, `program_plans`,
  `regimen_plans` all grant flat to `authenticated`.

**No `is_anonymous` restriction was added.** The claim exists in the
JWT; adding a restriction merely because it exists would break the
handoff and diverge from every other family.

**`service_role` deliberately gets nothing.** No Edge Function names
either table (`food-vision`, `jeni-chat`, `nutrition-lookup`,
`food-photo-cleanup` — zero hits), and `service_role` bypasses RLS, so
an unused grant there is strictly more dangerous. The clinic path is
already unaffected: `care_set_program_fact`, `care_end_program_fact` and
`care_get_program_facts` are SECURITY DEFINER owned by `postgres`.

---

## MINIMUM PRIVILEGE

| table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `program_facts` | **YES** — hydrate + `return=representation` | **YES** — new version | **YES** — `ON CONFLICT DO UPDATE`, coalesce, supersede | **NO** |
| `weekly_reads` | **YES** — same two reasons | **YES** — decided read | **YES** — same window re-decided; every re-push | **NO** |

**DELETE IS NOT GRANTED, AND THE PRODUCT DOES NOT NEED IT.**

- There is no client delete call site on either table — grepped; both
  are append-only chains and a superseded fact is superseded, never
  removed. `ProgramFactStore.endFact` exists and has **zero call sites**.
- **Account deletion is not a client operation.** It runs through the
  SECURITY DEFINER `public.delete_user_account()`, and both tables carry
  `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE`
  (read from `pg_constraint`).
- The handoff's own removals — the prescribed fact it refuses to carry,
  the source row that loses a deterministic-id collision — live inside
  `private.transfer_account_rows`, also DEFINER.

Proven negatively too: after the grant, `DELETE /rest/v1/program_facts`
still answers `403 · 42501` with the hint *"GRANT DELETE ON
public.program_facts TO authenticated"*.

---

## RLS ATTACK

`45_probes/api_proof.py after` — same contract as the shipping iOS app,
publishable key only, four throwaway identities (2 anonymous, 2
permanent).

| | result |
|---|---|
| A · anonymous writes own `program_fact` | **201** |
| B · anonymous reads own `program_fact` | **200** |
| C · permanent writes own `program_fact` | **201** |
| D · permanent reads own `program_fact` | **200** |
| E · anonymous writes own `weekly_read` | **201** |
| F · anonymous reads own `weekly_read` | **200** |
| G · permanent writes own `weekly_read` | **201** |
| H · permanent reads own `weekly_read` | **200** |
| the upsert's UPDATE branch really fired | `i:5150 → i:6000`, `end_reason=reset` |
| **A cannot INSERT for B** | 403 · 42501 |
| **A cannot READ B** | 200 · **0 rows** |
| **A cannot UPDATE B** | 200 · **0 rows changed** |
| **A cannot DELETE B** | 403 · 42501 (never granted) |
| **P cannot INSERT for Q** | 403 · 42501 |
| **P cannot READ Q** | 200 · **0 rows** |
| unfiltered `select` (no `WHERE`) | **only own rows** |
| unauthenticated `anon` role | 401 · 42501 on both tables |

**THE AUTHORITY LAW, NOW PROVEN BY THE POLICY RATHER THAN BY ABSENCE:**

Before the grant, *every* refusal looked identical, so "iOS cannot write
a prescription" was untested — it was indistinguishable from "iOS cannot
write anything". After the grant:

```
anon INSERT authority=prescribed        403 · 42501
own fact PATCHed to authority=prescribed
    403 · "new row violates row-level security policy for table
           program_facts"
```

Two different refusals from two different mechanisms, on a table the
same caller can otherwise write freely. **iOS still cannot author or
promote a prescription.**

**26 of 26 assertions passed. Every throwaway account deleted through
the shipping `delete_user_account()` RPC; both tables back to 0 rows;
and measured immediately afterwards, `auth.users` 4293 / anon 3426 /
permanent 867 / apple 559 / email 308 — byte-identical to `43` and
`44`.** (The pass's final `auth.users` figure is **4294**; the extra row
arrived hours later from a UI-walker app launch and is accounted for in
the FINAL GATE.)

---

## MIGRATION APPLICATION

**CUSTOMER DATA DML: NONE.**

**SCHEMA / PRIVILEGE CHANGE — exactly two statements:**

```sql
grant select, insert, update on public.program_facts to authenticated;
grant select, insert, update on public.weekly_reads  to authenticated;
```

Proven mechanically before applying, by
`45_probes/prove_no_dml.py` — comments and single-quoted literals
stripped, then **every** semicolon-separated statement matched in full
against the strict shape `GRANT|REVOKE <privileges> ON <object> TO|FROM
<roles>`, the privilege list checked against a legal-token set, and the
object/role halves re-scanned for row-touching keywords so a payload
cannot hide there:

```
OK  GRANT privs=['insert','select','update'] object=public.program_facts to=authenticated
OK  GRANT privs=['insert','select','update'] object=public.weekly_reads  to=authenticated
statements: 2 · CUSTOMER DATA DML: NONE · PRIVILEGE-ONLY: YES · exit 0
```

**The checker has a negative control.** Run against
`20260810090000_v25_e1_program_spine.sql` it reports `PRIVILEGE-ONLY:
NO` and **exit 1** — an absence is only evidence with a control
(`44`'s own `strings` lesson).

**APPLIED THROUGH THE NORMAL MECHANISM.** `supabase migration list
--linked` showed 15 local and 15 remote, perfectly in sync, so
`supabase db push --linked` applied exactly one file and nothing else:

```
supabase/migrations/20260815090000_v25_e1_spine_grants.sql
sha256  e9fa9bc728460023ca7c65cb1f9ef58c5e838126beee5c86e0fd15cb9cb0ad43
Applying migration 20260815090000_v25_e1_spine_grants.sql...
Finished supabase db push.
```

Recorded in history — read back from `supabase_migrations
.schema_migrations`:

```
20260815090000  v25_e1_spine_grants
20260814120000  v25_e1_account_handoffs
20260811120000  food_source_truth
```

No migration state was invented. `docs/app_v25/44_packages/G1_e1_spine_grants.sql`
is left as `44` wrote it; the applied file is the migration, and it
carries the audit above in its header.

---

## LIVE PRIVILEGES AFTER

Re-read from the catalog. **Do not trust "Finished".**

```
                       SELECT  INSERT  UPDATE  DELETE
program_facts  anon      f       f       f       f
               authenticated  T  T       T       f
               service_role   f  f       f       f
weekly_reads   anon      f       f       f       f
               authenticated  T  T       T       f
               service_role   f  f       f       f

relacl  postgres=arwdDxtm ; anon=Dxtm ; authenticated=arwDxtm ; service_role=Dxtm
RLS     enabled=true  forced=false     policies=4 on each table (unchanged)
```

`authenticated=arwDxtm` is **exactly the shape `consent_grants` and
`day_reflections` already carry** — this project's existing
minimum-privilege precedent, not a new one.

**NO UNRELATED PRIVILEGE DRIFT.** The full 38-table matrix was captured
before and re-captured after and diffed:

```
tables now: 38
DRIFT vs before (authenticated S/I/U/D):
  program_facts   was[f f f f]  now[T T T f]
  weekly_reads    was[f f f f]  now[T T T f]
```

Two rows changed. `anon` gained nothing, anywhere.

---

## REAL API PROOF

Above, in RLS ATTACK. `before` 23/23 · `after` 26/26 · every throwaway
identity deleted · counts identical to `43`.

---

## CLIENT END-TO-END PROOF

`plankAITests/SpineLiveSyncTests.swift`, gated behind
`TEST_RUNNER_JENI_LIVE_SPINE=1` so it never runs in the ordinary suite.
Every call is a shipping one — the brief forbids inventing a debug path
and calling that proof:

```
ProgramFactStore.apply            the E1 write chokepoint
WeeklyReadStore.recordDecision    the weekly read's chokepoint
SyncService.retryPendingUpserts   the launch sweep      (AppSync:191)
SyncService.hydrateProgramFacts   the launch hydrate    (AppSync:660)
SyncService.hydrateWeeklyReads    the launch hydrate    (AppSync:661)
ProgramFactStore.headValue        the consumer read — the same call
                                  TargetsService and AdaptiveStepsEngine make
supabase.rpc("delete_user_account")  the shipping deletion
```

**SCENARIO 1 — fresh anonymous customer → produce a program fact and a
weekly read → push → remove the local copy → hydrate. PASSED.**

The load-bearing assertion is `pendingUpsert == false`: the flag is
cleared **only** inside the success branch after `.execute()` returns.
For these two families it was `true` on every device, forever, until
today. After the wipe, `hydrateProgramFacts` returned the row with its
id, kind (`stepGoal`), value (`i:5150`) and authority (`preferred`)
intact and `pendingUpsert = false` — a hydrated row must not queue a
push back, and does not.

**SCENARIO 3 — account A, sign out, account B. PASSED.** B hydrating
A's uid produced nothing; B hydrating B produced nothing. The server
answers to the token, never to the argument. Cleanup steps back into A's
session with `setSession` and deletes it too, so no orphan is left.

**SCENARIO 2 — the handoff — is proven separately below**, because
reaching it through the UI needs an Apple ID that has never signed into
Jeni, which is still `43`'s open blocker and is not this pass's to close.

**WHAT THIS DOES NOT CLAIM.** It does not drive the UI, and the
"reinstall" is the account's local rows deleted rather than a container
wiped — `TestModelContainer` is process-wide by necessity (a second
in-memory container hangs the main thread on this schema). What it does
prove is that the row came back **from the server**, because after the
wipe there was nowhere else for it to come from.

---

## HANDOFF

`45_probes/handoff_proof.py`. Two throwaway anonymous accounts seeded
over the real API in the app's own shapes, then the **deployed**
`private.transfer_account_rows` run inside a transaction that **always
aborts** — the `DO` block ends in `raise exception`, so the rollback is
structural rather than a statement someone has to remember, and the
assertions ride out in the exception message.

Seeded: the source holds a preferred fact, a prescribed fact (inserted
as `postgres`, since the RLS correctly refuses the client), a weekly
read for a window the destination **also** holds, and a weekly read for
a window of its own. The destination holds its own fact and its own read
for the shared window.

```
BEFORE  src_facts=2 dst_facts=1 src_reads=2 dst_reads=1
AFTER   src_facts=0 dst_facts=2 src_reads=0 dst_reads=2
        prescribed_surviving=0
        dst_shared_window_rows=1
        carried_window_rows=1
        rows_still_src_prefixed=0
```

**DOES E1 MOVE THEM?** Yes, both families, and the live `pg_proc` body
names both tables.

**DOES THE LOCAL POLICY AGREE?** Yes. `program_facts` ids are uuids and
the server **preserves** them; `IdentityMerge` under `.preserve` keeps
them too, and `HandoffIdPolicy` writes `.preserve` the moment a receipt
exists. `weekly_reads` ids are `"<uid>-read-<windowStartDay>"` and both
sides do a **prefix swap with the tail's case preserved** —
`IdentityMerge.rekeyedDeterministicId` on the client, `42`'s [CORR-2]
`substring(id from v_plen + 1)` on the server.

**CAN BOTH SIDES HOLD THE SAME LOGICAL KEY? WHAT WINS?** Yes, for
`weekly_reads` — one week, two accounts, the normal case. **The
destination's row wins, whole, and content is never compared.** Proven:
`dst_shared_window_rows=1` (exactly one row for the shared window, and
it is the destination's own id) while `carried_window_rows=1` (the
source's own window arrived re-prefixed) and `rows_still_src_prefixed=0`
(nothing was stranded). The client's `IdentityMerge` applies the
identical rule via `destinationReadIds`.

**CAN A UNIQUE COLLISION SILENTLY DESTROY ONE?** No. The server deletes
the losing source row **before** the update, so the unique index is
never asked to resolve anything — the `41` §1 defect shape, guarded.

**CAN A CARE-TEAM-OWNED FACT MOVE?** **No — it is deleted, not
re-owned.** `prescribed_surviving=0`. A prescription assigned to one
identity by a clinic that never met the other is not a record with a new
owner. The client refuses identically
(`IdentityMerge.carriesForeignAuthority`).

**CAN A FACT THAT SHOULD BE DEVICE-LOCAL MOVE?** There is no
device-local authority in this vocabulary — `prescribed` › `preferred` ›
`recommended` › `defaulted` are all account facts, and only `prescribed`
is refused. The device-local knobs (`WeeklyReview.proteinAdjustKey` and
friends) are `@AppStorage` written **through** from the resolved head,
never the other way round.

**The transaction rolled back and both accounts were deleted: 4293 /
3426 / 867, both tables 0 rows, zero probe residue.** No production row
was changed.

---

## DELETE ACCOUNT

| | |
|---|---|
| server rows | `FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE` on **both** tables, read from `pg_constraint` |
| performed by | **a SECURITY DEFINER function, not the client** — `public.delete_user_account()` is `delete from auth.users where id = auth.uid()` |
| local rows | `AppSync.clearLocalUserRecords` deletes both families (`37`'s fix, lines 2143-2154) |
| abandoned anonymous source | retired by `AnonymousAccountRetirement` with its own still-live token, or by `complete_account_handoff`'s `delete from auth.users` — both cascade |
| does the new grant change any of this? | **No.** DELETE is not granted; deletion never was a client operation |

**PROVEN LIVE, not read.** The API proof wrote spine rows under four
throwaway accounts, deleted the accounts through the shipping RPC, and
`select count(*)` on both tables returned to **0**. The handoff proof
did the same with two more.

---

## SILENT FAILURE FIX

`44` named why this survived five passes: the writes are fire-and-forget
inside a `try?` and the hydrates turn 42501 into DEBUG-only information.
That is a second defect, and it is the one that made the first
survivable.

▎ **A REFUSAL THE SERVER WILL GIVE AGAIN IS NEWS.
▎ A CONNECTION THAT DROPPED IS NOT.**

**The requirement is the behaviour, not the mechanism.** No error
framework was built. The smallest thing already compatible with this
app is its own analytics vocabulary, which since `E2` has been governed
by `AnalyticsHygiene` as a **mechanism** rather than a convention.

**Three pieces:**

1. **`SyncFailureClassifier`** (pure) — maps a code to
   `permission_denied` · `schema_mismatch` · `authorization` ·
   `constraint_rejected` · `unclassified` · `transient`.
2. **`SyncHealth.report`** — silent for `transient`; otherwise emits
   `sync_structural_failure` **once per family per reason per calendar
   day per install**. Two hundred failing launches in a day are one
   event.
3. **`SyncService.structuralFailureReporter`** — a hook the package
   calls from the four spine `catch` blocks. It reports the **family**
   and the **code**, and nothing else. It decides nothing; a host that
   installs no reporter behaves exactly as before.

**THE POLARITY IS DELIBERATE.** Silence is granted only to codes
**positively identified** as transient — `urlerror`, the Postgres
connection-exception class, the resource-limit codes, the
cancellation/serialization codes, and PostgREST's two cannot-reach-the-
database codes. **Anything unrecognised is reported.** `42501` was an
unrecognised code once, and assuming harmlessness by default is exactly
the habit that lost five passes.

**NOTHING THE SERVER SAID IN PROSE TRAVELS.** PostgREST's 42501 body
carries a `hint` that prints the exact `GRANT` and names the table, and
a `message` that names it too. The payload is three categorical values —
`family`, `reason`, `code` — and a code of unexpected shape is flattened
to `"other"` before it can become one. `Analytics.trackException`
exists and sends `$exception_message`; it is deliberately **not** used
here.

Against each requirement:

| requirement | how |
|---|---|
| no customer-facing scary database error | it is a telemetry event; no UI is touched |
| no crash | no assertion, no force-unwrap, no fatalError |
| no fabricated success | `pendingUpsert` still governs; nothing is marked done |
| no infinite retry storm | the report is once/day; the RETRY is unchanged — one pass per launch |
| no DEBUG-only disappearance | `Analytics.track` is not `#if DEBUG`; the `print` beside it still is |

**SCOPE.** Wired for `program_facts` and `weekly_reads` only — the two
families this pass is scoped to. A vocabulary naming families it does
not report would be a false contract, so the hygiene rule's `family`
word list contains exactly those two.

---

## SAME-DEFECT SCAN

`45_probes/P2_grant_matrix_public.sql` — every table in `public`, its
RLS state, its policy count, and the effective privilege of each API
role. **38 tables.**

**Four tables carry RLS policies and zero data-API privileges for
`authenticated`:**

| table | policies | client path? | verdict |
|---|---|---|---|
| `program_facts` | 4 | **yes** — `SyncService` | **THE DEFECT. FIXED THIS PASS.** |
| `weekly_reads` | 4 | **yes** — `SyncService` | **THE DEFECT. FIXED THIS PASS.** |
| `care_weekly_summaries` | 3 | **yes** — `WeeklySummaryPublisher` → `SyncService.publishWeeklySummary`, called from `AppSync.onLaunch` on **every** launch, outside `#if DEBUG` | **THE SAME DEFECT. P2, sequenced — see below.** |
| `patient_invitations` | 1 | **no** — 5 SECURITY DEFINER functions name it, and it holds **17 rows**, so the flow works | **NOT A DEFECT** — DEFINER-only by design |

`account_handoffs` has **0 policies and no grant**, which is `42`'s
deliberate design (DEFINER-only, verified there). Four telemetry/ops
tables are service_role-only by design.

**IS G1 AN ISOLATED MISTAKE? NO — AND THE MECHANISM SAYS WHY IT COULD
NOT HAVE BEEN.** With `pg_default_acl` granting `Dxtm` and nothing else,
*every* client-facing table needs an explicit grant. Fifteen tables have
one (`arwdDxtm` for full CRUD; `arwDxtm` for `consent_grants` and
`day_reflections`, which is exactly G1's shape). Three did not.

**`care_weekly_summaries` IS CLASSIFIED P2 AND LEFT FOR `46`, WITH THE
REASON:**

- **The fix is not the same bounded privilege correction.** The table
  has **no foreign key to `auth.users`** — named in `37` §16, `38` §4
  and `44` P2 #7, re-measured this pass and still true. Granting INSERT
  before the FK lands turns *"0 rows, latent"* into *"customer rows that
  survive account deletion"*. That is the `food-photos` ordering exactly:
  **the client must not be able to create the rows before the deletion
  path can reach them.**
- **Nobody is losing anything today.** 0 rows; 9 active care
  relationships and 4 live `visit_packet_view` consents, all inside the
  internal clinic alpha (`docs/app_v8`: dev alpha, test data only, no
  BAA). The longitudinal series simply does not exist yet.
- **THE FINDING IS THE CATALOG, NOT THE ROW COUNT.** `authenticated` has
  no privilege on the table, so the call cannot succeed whoever makes it
  — that is proven from `pg_class.relacl` and does not depend on
  inferring that a particular customer's summary was refused. The 0 rows
  are consistent with it, not the evidence for it. **[OBS]** Its
  sibling `public.visit_packets` — which does hold 4 rows and does have
  the grant — turns out to have **exactly one call site, and it is
  inside `#if DEBUG runCareQAHooksIfNeeded`**, gated on
  `--uitest-care-connect-code` / `--uitest-care-refresh`. The two
  publishers share a byte-identical gate
  (`connections.filter { $0.isActive && $0.scopes.contains(.visitPacket) }`)
  and differ in that one ships and one does not. Recorded, not touched.
- **It is not P0**, so this pass does not stop; and it is not "the same
  bounded correction", so this pass does not smuggle it in.

**IDENTICAL MISSING-GRANT DEFECTS ELSEWHERE: 1.**

**One more thing the matrix showed, named and deliberately not
touched:** `anon` and `authenticated` hold **TRUNCATE** (`D`) on nearly
every public table, because that is what this project's default ACL
grants. TRUNCATE bypasses RLS, and it is **not reachable through the
data API** — PostgREST exposes SELECT/INSERT/UPDATE/DELETE and RPC, and
every RPC is a fixed function body. It is also *more* restrictive than
Supabase's own default (`GRANT ALL`, which includes TRUNCATE **and** the
four data privileges). Revoking it across 38 tables on a release
candidate is precisely the unbounded change this pass must not make.
**Recorded for `46`.**

---

## HISTORICAL IMPACT

**Absence is not automatically loss.** The question is what a customer
actually lost.

| question | answer |
|---|---|
| Did the authoritative local copy remain? | **Yes, on every device that wrote one** — and with `pendingUpsert` still `true`, because the flag is only cleared on success. `retryPendingUpserts` runs on every launch, so the whole backlog pushes itself on the next launch after G1. **No repair code, nothing to reconstruct.** |
| Could a customer who reinstalled lose program facts? | In principle yes — the local copy was the only copy. In fact, **no customer was ever in that position** (below). |
| Could a customer who switched devices lose them? | Same answer, same reason. |
| Could `weekly_reads` be reconstructed? | It would not need to be: the decision's *effect* is a `program_fact`, which is on the same device. The read row is the court record, not the mechanism. |
| Did it affect target arithmetic? | **No.** Every engine resolves through `ProgramFactStore.head` over the local store, which answered correctly because it was the only store. |
| Did it affect safety? | **No.** The safety cap rides `safety_*` keys and `TargetsService.resolvedSafetyCap` (`35`), not the spine. |
| Did it affect Jeni? | **No.** `read_program` and `propose_program_fact` go through the same local chokepoint. |
| Did it affect clinician output? | **No, and this is the one that could have.** `care_set_program_fact` is DEFINER and was never blocked, so a clinician *could* have written a prescribed fact that the patient's phone could never read. **`program_facts` holds 0 rows, so no clinician ever did.** |

**THE MEASUREMENT.** Since 2026-08-10, from the project's own analytics:

```
program_fact_changed   340 events · 66 identities · 08-10 19:51 → 08-15 08:58
weekly_read_decision     2 events ·  2 identities
weekly_read_shown       16 events ·  5 identities

program_fact_changed by environment / test flag / version
  debug · is_test_user=true · 1.2.0 (30)   324 events · 61 people
  debug · is_test_user=true · 1.1.7 (29)    16 events ·  5 people
  production                                 0 events ·  0 people
```

**AND THE CONTROL, because an absence is only evidence with one:** in
the same window the same project recorded **2,492 `environment:
production` events from 54 people**. The property is live and being
stamped; the spine's absence from it is real.

Under `24_MEASUREMENT_CONTRACT.md` (production = `environment
= 'production'` ∧ no `is_test_user` ∧ `app_version ≥ '1.2.0 (30)'`):

▎ **CUSTOMER DATA HISTORICALLY LOST BECAUSE G1 WAS ABSENT: NONE.**

E1's writers are only reachable from builds that are not on the App
Store — 1.2.0 (30) was accepted by ASC on 2026-08-12 and has not been
released. **Nothing needs reconstruction, and nothing may be
reconstructed by inference.**

---

## RESTORE

§14, run from zero local state for the account:

1. The account's local `ProgramFactRecord` and `WeeklyReadRecord` rows
   are deleted; both fetches return empty.
2. `hydrateProgramFacts` + `hydrateWeeklyReads` — the shipping launch
   calls, in the shipping order.
3. Both rows return with id, kind, value, authority, window and decision
   intact, and `pendingUpsert = false`.
4. **The restored fact reaches its consumer:** `ProgramFactStore
   .headValue(.stepGoal, …)` returns `.int(5150)` — the same resolver
   `TargetsService` and `AdaptiveStepsEngine` read, and the one Home and
   the plan surfaces render from. `WeeklyReadStore.latest` returns the
   restored row.

**A 200 is not a restore, and this is not claimed on one.** The fetch
returning is step 3; step 4 is the proof.

---

## FAILURE SEMANTICS

**Retry semantics, stated exactly. Nothing about the retry changed this
pass — what changed is that a permanent refusal now says so.**

| failure | classified | reported? | the row | the retry |
|---|---|---|---|---|
| offline write | `URLError` → **transient** | no | stays `pendingUpsert = true` | next launch |
| network dies mid-write | `URLError` → **transient** | no | stays pending | next launch |
| server 500 with no code | `unknown` → **unclassified** | once/day | stays pending | next launch |
| expired token / 401 | `PGRST301` → **authorization** | once/day | stays pending | SDK refreshes; next launch pushes |
| 403 / 42501 | **permission_denied** | once/day | stays pending **forever** until the server changes | next launch — **this was the last five days, now visible** |
| timeout | `URLError` → **transient** | no | stays pending | next launch |
| app killed during push | never classified — the process is gone | no | stays pending (the flag is cleared only *after* `.execute()` returns) | next launch |
| relaunch | — | — | — | `AppSync.onLaunch` → `retryPendingUpserts()`, unconditional, once |

**DOES THE FIX TURN "NEVER SYNCED" INTO "DUPLICATE FOREVER"? NO — and
structurally, not by luck:**

- `program_facts.id` is a client-minted uuid, stable for the life of the
  row; the push is an upsert on the primary key.
- `weekly_reads.id` is `"<uid>-read-<windowStartDay>"`, deterministic per
  (user, window), so **two devices converge on one row** by construction.
- If the app dies after the server commits but before the flag clears,
  the next launch re-pushes **the same id** → `ON CONFLICT DO UPDATE` →
  the row is updated in place. Not a second row.
- The hydrate is insert-by-id and `continue`s on a row it already has
  (only a `prescribed` row is overwritten, deliberately —
  server-authoritative). A hydrated row is inserted with `pendingUpsert
  = false`, so a pull never queues a push back: no ping-pong.
- There is **no in-launch retry loop** for these families and none was
  added. A permanent refusal costs exactly two requests per launch per
  family.

**THE ONE BOUNDED CONSEQUENCE, NAMED.** A customer with two devices,
each of which independently wrote a `preferred` chain for the same kind
while the grant was missing, will now push both chains and each device
will hydrate the other's. `ProgramFacts.head` is total and
deterministic — authority precedence, then `createdAt` — so the newest
active row wins. More rows than a clean history would hold, one
unambiguous answer, no crash. Measured population today: **zero.**

---

## TEST PROOF

Run serially on `QA-iPhone16` (`259952D4-…`). Every figure is the
`Executed …` line from the run named, and every exit code is unpiped.

| suite | expected | actual | exit | line |
|---|---|---|---|---|
| `SpineSyncHealthTests` **RED** (stub = the before state) | ≥1 failure | **10 of 12 failed · 32 assertion failures** | 65 | `** TEST FAILED **` |
| `SpineSyncHealthTests` **GREEN** | 12 | **12, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| `SpineLiveSyncTests` (live, `TEST_RUNNER_JENI_LIVE_SPINE=1`) | 2 | **2 passed, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| **full app suite** (`plankAITests`) | 1354 + 14 = **1368** | **1368, 2 skipped, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| PlankSync (`swift test`) | 9 | **9, 0 failures** | 0 | `Test Suite 'All tests' passed` |
| PlankFood (package scheme, iOS sim) | 200 | **200, 0 failures** | 0 | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests` (solo) | 1 | **1 passed** (`testSpentWallCloseButtonAlwaysResponds`, 9.9s) | 0 | `** TEST SUCCEEDED **` |
| Release build (`generic/platform=iOS`, clean derived data) | — | 0 compile errors | 0 | `** BUILD SUCCEEDED **` |

`+14` is exactly the number of tests added, and `1368 − 14 = 1354`
matches `44`'s recorded figure. **The 2 skipped are `SpineLiveSyncTests`,
which is env-gated** — a skipped test with `TEST SUCCEEDED` is the
`Executed 0 tests` trap in new clothes, so it was run separately with
`TEST_RUNNER_JENI_LIVE_SPINE=1` and the per-test lines were read, not the
summary. (`JENI_LIVE_SPINE=1` alone does **not** reach the test process:
`xcodebuild` forwards only `TEST_RUNNER_`-prefixed variables. The first
attempt "passed" with both tests skipped.)

**PlankFood cannot be run the way `44` implies.** `xcodebuild -scheme
PlankFood` from the app project answers *"Scheme PlankFood is not
currently configured for the test action"*, and `swift test` inside the
package fails to compile (`FoodLogPersister` imports `UIKit`). The run
above is from `Packages/PlankFood` against the iOS simulator, which is
the only invocation that works.

### THE UI WALKER BUNDLE IS NOT GREEN ON THIS BRANCH

Stated, not buried. The `plankAI` scheme also carries `plankAIUITests`,
which the last five passes' recorded proof does not include. Run this
pass, **four legs fail — and they fail SOLO, not only chained**, so this
is not the documented parallel-clone flake:

| leg | failure |
|---|---|
| `BodyScanProofUITests` | 2 of 5 — *"the evening page never rendered"*; the `settings` button never became hittable |
| `DownsellSheetUITests` | *"downsell CTA should render"* — the StoreKit path |
| `InAppQAUITests` | 1 of 4 — the `coach, jeni` settings row never became hittable |
| `MoveHealthProofUITests` | *"active energy row missing — the read path dropped a real sample"* — needs HealthKit samples the simulator does not have (already open debt since `E8.2`) |

**EXONERATED, NOT ASSUMED.** This pass's only launch-path change is one
closure assignment in `AppSync.configure`. It was commented out and
`BodyScanProofUITests` re-run: **identical result — 5 executed, the same
2 tests, the same 2 assertions, exit 65.** The line was then restored and
verified present. None of the four legs touches program facts, weekly
reads, sync error handling or analytics.

**WHAT THEY LOOK LIKE ON INSPECTION.** Reading the walker traces rather
than the summaries: `InAppQAUITests` reaches Settings successfully
(attachment `01_settings_opened`) and then fails to tap a row further
down the list; `BodyScanProofUITests` fails on a nav-bar button's
*hittability*, not its existence. That is the shape of this repo's own
recorded limitation — **"synthesized XCUI drags can't scroll the iOS
26.2 sim (probe-proven) — tours film what walkers cannot"** (`v12`
CRAFT). `MoveHealthProofUITests` needs HealthKit samples the simulator
does not have, which has been open debt since `E8.2`; `DownsellSheetUITests`
needs the StoreKit sheet, whose sim behaviour is already documented as
needing manual dismissal.

**So the likeliest reading is environmental, and this pass does not
assert it.** What it asserts is the part it measured: **the failures are
not this pass's**, proven by disabling its only launch-path change and
getting an identical result. **Left for `46`** — chasing four UI-walker
legs on surfaces this pass is scoped away from is exactly the silent
expansion the brief forbids, and calling them "fine" without a device
run would be worse.

**RED WAS PROVEN, AND THE TWO THAT PASSED ARE THE TWO CONTROLS.** The
stub was written as the honest *before* state — everything classifies as
`transient`, nothing is ever reported — which is literally what the
product did from 2026-08-10 until today. Under that stub,
`testTransientCodesAreSilent` and `testATransientFailureReportsNothing`
**pass**, because a classifier that calls everything transient is
indistinguishable from one that is correctly quiet.

▎ **A SILENCE TEST CANNOT TELL "CORRECTLY SILENT" FROM "CANNOT SPEAK AT
▎ ALL" — the refusal lesson for the TENTH session running.**

---

## RELEASE BINARY

Release, `generic/platform=iOS`, unsigned, **clean derived data**
(`/tmp/45_release_dd`, not an incremental build). `** BUILD SUCCEEDED **`,
exit 0, 0 compile errors.

| check | result |
|---|---|
| binary size / string count | **84 MB / 122,857 strings** |
| `uitest` · `--debug` · `--food-debug` · `debug-weigh-ins` · `--demo-backend` · `debug_anthropic_api_key` | **0 · 0 · 0 · 0 · 0 · 0** |
| backend hosts in the binary | **`https://mtecqvykyeueumdynatd.supabase.co` only** |
| `service_role` · `SUPABASE_SERVICE` · a JWT header (`eyJhbGciOiJIUzI1NiIs`) · `BEGIN PRIVATE KEY` · `sb_secret_` · `postgres://` · `ASC_KEY` | **0 · 0 · 0 · 0 · 0 · 0 · 0** |
| this pass's live-test identifiers — `JENI_LIVE_SPINE` · `45-probe` · `SpineLiveSync` | **0 · 0 · 0** — the live test is in the test bundle and does not ship |

**THE NEW DIAGNOSTIC MECHANISM SHIPS, AND IT IS SUPPOSED TO.**

```
sync_structural_failure    1
permission_denied          2
schema_mismatch            0
sync.health.               0
```

`sync_structural_failure` being **present** is the point of the whole
§11 fix: a structural refusal that only exists under `#if DEBUG` is what
hid a five-day outage from five passes. It is an analytics event name
with a three-value categorical payload; it carries no message, no hint,
no row, no id and no uid, and it fires at most once per family per
reason per day.

**AND IT IS THE CONTROL THAT MAKES THE ZEROS READABLE.**
`schema_mismatch` and `sync.health.` read 0 despite being compiled in —
Swift stores some literals in a form `strings` does not surface, which
is exactly what `44` found for `-weightday-`, `-dose-`, `-symptom-` and
`deletions.v1.`. Because a known-present sibling from the same file
reads 1, the zeros are a property of `strings`, not evidence of absence.
The proof the fix is compiled in is the test run: 12/12 green, from 10
red.

**A note on the size.** `44` recorded 87 MB / 124,103 strings. This is a
clean build in a fresh derived-data path rather than an incremental one,
which is the likeliest cause of the difference; the figure above is what
was measured, not reconciled to the previous one.

---

## PROTECTED PATHS

Mechanically enumerated: every file under `PlankApp`, `Packages`,
`plankAITests`, `plankAIUITests`, `supabase`, `JenifitWidgets` and
`plankAI.xcodeproj` modified after this pass's first probe was written
(`find -newer`), excluding `.build` artefacts and Xcode user state.

**THIS SESSION — the complete list, nine files:**

| file | change |
|---|---|
| `supabase/migrations/20260815090000_v25_e1_spine_grants.sql` | **NEW · APPLIED** — two `grant` statements and the audit that earned them |
| `Packages/PlankSync/Sources/PlankSync/SyncService.swift` | `structuralFailureReporter` + `reportStructuralFailure` (additive), and one line in each of four existing `catch` blocks |
| `PlankApp/Sync/SyncHealth.swift` | **NEW** — `SyncFailureClassifier` + `SyncHealth` |
| `PlankApp/Sync/AppSync.swift` | one hunk: installs the reporter at `configure` |
| `PlankApp/Analytics/AnalyticsManager.swift` | one enum case, `sync_structural_failure` |
| `PlankApp/Analytics/AnalyticsHygiene.swift` | one registry rule with two closed vocabularies |
| `plankAITests/SpineSyncHealthTests.swift` | **NEW** — 12 tests |
| `plankAITests/SpineLiveSyncTests.swift` | **NEW** — 2 live tests, env-gated |
| `plankAI.xcodeproj/project.pbxproj` | three file references, nothing else |

Plus `docs/app_v25/45_probes/` (7 files) and this record.

**THIS SESSION — EMPTY, mechanically (none appear in the `-newer`
list):** `PlankApp/Payment` · `PlankApp/Views/Paywall` ·
`PlankApp/Auth` · `PlankApp/App/AppPhase.swift` · `Info.plist` ·
`plankAI.entitlements` · `PlankApp/Notifications` · `PlankApp/Care` ·
`PlankApp/BodyScan` · `PlankApp/Views/Workout` · `JenifitWidgets` ·
`Packages/PlankFood` · `supabase/functions` (Edge Functions) · all three
`@Model`-declaring files.

`plankAI.xcodeproj/xcshareddata/xcschemes/plankAI.xcscheme` has a newer
mtime and **zero content diff** (xcodebuild touched it).

**PRIOR SESSIONS vs the reviewed release `1710180`** — unchanged by this
pass, restated so the two are never conflated:

| path | vs `1710180` |
|---|---|
| Payment · Paywall · AppPhase · Info.plist · entitlements · Notifications · Care · BodyScan · Workout · widgets | **EMPTY** |
| all three `@Model` files | **ZERO DIFF** — no store migration exists to fail |
| `Packages/PlankFood` | 23 files, +2358/−135 (passes `27`/`34`) |
| `supabase/functions` | 1 file, +124/−3 (pass `27`, still not deployed) |

---

## RELEASE DECISION

**BUILD 31 IS A TRUE RELEASE CANDIDATE.**

`44` said Build 31 was safe *without* G1, and that was correct — nothing
regressed by leaving it. What it cost was that the spine the last eight
passes were built on had never once left the phone. It has now, both
directions, for an anonymous customer and a permanent one, over the real
API and through the shipping client.

`CURRENT_PROJECT_VERSION` is still **30**, and `32`'s mechanical step
still stands: build 30 is already accepted by ASC, so the archive must
set it to **31**.

---

## THE TWENTY ANSWERS

**1. WHY DID `program_facts` NEVER SYNC?**
`20260810090000_v25_e1_program_spine.sql` created it with RLS and four
policies and no `grant`, and this project's default privileges give a
new `public` table `Dxtm` only — TRUNCATE, REFERENCES, TRIGGER,
MAINTAIN, and none of SELECT/INSERT/UPDATE/DELETE. Every call returned
42501 into a `try?` or a DEBUG-only `catch`.

**2. WHY DID `weekly_reads` NEVER SYNC?** The same migration, the same
omission, the same four refusals.

**3. WAS G1 EXACTLY CORRECT AS WRITTEN?** Substantively yes — the
privilege set, the withheld DELETE and the `authenticated`-only target
are all right. It understated three things, now in the applied
migration: SELECT is required by the *write* (`return=representation`),
UPDATE is required on the *first* write (`ON CONFLICT DO UPDATE`), and
`TO authenticated` reaches every anonymous customer. It was also not in
`supabase/migrations/`, so applying it as written would have left no
history.

**4. WHAT PRIVILEGES WERE ACTUALLY REQUIRED?** `SELECT, INSERT, UPDATE`
on both tables, to `authenticated` only. Nothing else, for anyone.

**5. DID G1 GRANT ANY PRIVILEGE THE CLIENT DOES NOT NEED?** No. All
three are exercised by the shipping code, and the UPDATE branch was
proven to actually fire (`i:5150 → i:6000` on a second upsert).

**6. CAN AN ANONYMOUS CUSTOMER USE THESE TABLES?** Yes — a Supabase
anonymous user carries the `authenticated` role. Proven live: 201 on
write, 200 on read, both tables.

**7. SHOULD THEY BE ABLE TO?** Yes. 3,426 of 4,293 accounts are
anonymous; the spine's writers run through onboarding and the weekly
read long before any sign-in; and `private.transfer_account_rows`
already moves both families from an anonymous source to a permanent
destination — a spine the anonymous period could never write would give
the handoff nothing to move.

**8. CAN CUSTOMER A READ CUSTOMER B?** No. Filtered read: 0 rows.
Unfiltered read: only her own. Unauthenticated: 401.

**9. CAN CUSTOMER A WRITE CUSTOMER B?** No. INSERT 403 · 42501; UPDATE 0
rows changed; DELETE 403 (never granted). Tested anonymous→anonymous and
permanent→permanent.

**10. DOES ACCOUNT HANDOFF PRESERVE BOTH FAMILIES?** Yes — proven
against the deployed `private.transfer_account_rows` in a transaction
that aborts by construction. Facts move with ids preserved; reads move
with the prefix swapped and the tail's case intact. A **prescribed** fact
is deleted, not re-owned.

**11. CAN HANDOFF COLLIDE WITH AN EXISTING DESTINATION ROW?** Yes, for
`weekly_reads` — one week, two accounts, the normal case. The
destination wins, whole, content never compared, and the losing source
row is deleted **before** the update, so the unique index is never asked
to resolve anything. `program_facts` cannot collide: uuid keys.

**12. DOES DELETE ACCOUNT REMOVE BOTH FAMILIES?** Yes. Both carry
`ON DELETE CASCADE` to `auth.users`, deletion runs through the SECURITY
DEFINER `delete_user_account()`, and the local sweep removes both. Proven
six times over this pass: rows written, accounts deleted, both tables
back to 0.

**13. DOES A REINSTALL NOW RESTORE BOTH FAMILIES?** Yes — write, push,
local wipe, hydrate, and the restored fact reaches `ProgramFactStore
.headValue`, the resolver every surface reads.

**14. WHAT CUSTOMER DATA WAS HISTORICALLY LOST BECAUSE G1 WAS ABSENT?**
**None.** 340 of 340 spine writes since 2026-08-10 carry `environment:
debug` and `is_test_user: true`, against a control of 2,492 production
events in the same window. 1.2.0 (30) is accepted by ASC and not
released, so E1's writers have never run in a production build.

**15. CAN THAT DATA BE SAFELY RECONSTRUCTED?** There is nothing to
reconstruct, and nothing may be inferred. What does exist — every local
row written on a debug install — still carries `pendingUpsert = true`
and pushes itself at the next launch through the existing sweep.

**16. DID THE SAME MISSING-GRANT DEFECT EXIST ON ANY OTHER SHIPPING
TABLE?** **Yes, on one:** `public.care_weekly_summaries` (3 policies, 0
grants, a live client writer, 0 rows while its sibling `visit_packets`
holds 4). Classified **P2 and left for `46`**, because its fix is not the
same bounded correction — the table has no FK to `auth.users`, so the
grant must land *after* the FK or it creates rows that survive account
deletion. `patient_invitations` looked similar and is not a defect:
DEFINER-only by design, 17 rows, working.

**17. CAN A STRUCTURAL SYNC FAILURE STILL DISAPPEAR INTO `try?` /
DEBUG?** No, for these two families. A permission, schema, authorization
or constraint refusal — and anything unrecognised — emits
`sync_structural_failure` once per family per reason per day, outside
`#if DEBUG`, with a categorical payload. The server's message and hint
never travel.

**18. WHAT HAPPENS ON TEMPORARY NETWORK FAILURE NOW?** Nothing visible,
deliberately. `URLError` and the connection/resource/cancellation codes
are classified `transient` and stay silent; the row keeps
`pendingUpsert = true` and the existing once-per-launch sweep carries
it. A phone in a lift is the normal case, not news.

**19. WHAT P0/P1 REMAINS AFTER THIS PASS?** **P0: 0. P1: 0.** Open P2s,
all named and none blocking: `care_weekly_summaries` (grant, behind its
FK) · the `food-photos` bucket (behind a corrected storage purge) · six
`ISO8601DateFormatter()` sites that cannot parse a fractional-second
timestamp · `private.*` PUBLIC execute (proven unreachable) ·
`users.program_mode`/`goal_direction` 100% NULL · TRUNCATE in the
project's default ACL (unreachable through the data API) · **and one
UNRESOLVED item this pass surfaced and deliberately did not chase: four
`plankAIUITests` legs fail solo, on surfaces this pass never touched,
proven not to be its doing.**

**20. IS BUILD 31 NOW A TRUE RELEASE CANDIDATE?** **Yes.**

---

## FINAL GATE

```
G1 AUDITED:                         YES
G1 APPLIED:                         YES
G1 VERIFIED LIVE:                   YES
ANONYMOUS API PROOF:                PASS
PERMANENT API PROOF:                PASS
CROSS-ACCOUNT RLS PROOF:            PASS
HANDOFF PROOF:                      PASS
REINSTALL RESTORE PROOF:            PASS
IDENTICAL MISSING-GRANT DEFECTS
  ELSEWHERE:                        1  (care_weekly_summaries — P2, sequenced)
P0 REMAINING:                       0
P1 REMAINING:                       0
PRODUCTION CUSTOMER-ROW MUTATIONS:  NONE THAT SURVIVED — see below
CURRENT_PROJECT_VERSION:            30
SAFE TO BUMP TO 31:                 YES
SAFE TO ARCHIVE:                    YES
SAFE TO SUBMIT:                     YES
```

**ONE CAVEAT ON THE LAST TWO, STATED RATHER THAN HIDDEN.** `YES` covers
this pass's change and the release-gate items `44` verified. It does
**not** mean the `plankAIUITests` bundle is green — four legs fail, they
fail solo, they are proven not to be this pass's, and their most likely
cause is the simulator limitations this repo has already recorded. That
question is `46`'s, and it is the first thing `46` should look at.

**PRODUCTION CUSTOMER-ROW MUTATIONS, stated exactly rather than as
`NONE`:** this pass created **10 throwaway identities** (8 anonymous, 2
email, all `@example.com`) and wrote **synthetic spine rows** under them
— `kind=stepGoal`, `value=i:5150`, `window_start_day` in 2001, source
`45-probe`. **Every one was deleted through the shipping
`delete_user_account()` RPC**, and the counts were re-read to 4293 /
3426 / 867 after each of the three probe runs. The handoff proof ran
inside a transaction that aborts by construction. **No row belonging to
a customer was read, written, moved or deleted.** Both spine tables end
the pass at **0 rows**; `identities` end at **apple 559 · email 308**,
byte-identical to `43` and `44`.

▎ **AND ONE ROW THAT IS NOT A PROBE, REPORTED BECAUSE THE COUNT MOVED.**

`auth.users` ends at **4294, not 4293.** The extra row is an anonymous
account created at **09:02:20Z**, which is the second the UI walker
bundle launched the app (`BodyScanProofUITests` started 02:02:27 PDT).
It is the app's own anonymous bootstrap doing exactly what it does on
every simulator launch against production, and it owns what the walkers
drove: **1 profile · 1 plan · 1 weigh-in · 5 food logs · 0 program
facts · 0 identities.**

That is not a probe and it is not customer data — it is the mechanism by
which this project's **3,426 anonymous accounts** accumulated, observed
directly and dated for once rather than inferred (`40` §6 measured the
population; this is one of them being made). It was left in place: there
is no credential for it, and deleting an `auth.users` row by hand is a
production DML this pass has no reason to perform. **`44`'s "zero drift"
figure held through every probe; it is the QA launch that moved it.**

▎ **DID THE SPINE ACTUALLY LEAVE THE PHONE AND COME BACK?**

**YES.**
