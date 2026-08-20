# THE ACCOUNT REALLY DISAPPEARS

**Status: PRODUCTION CENSUS RUN + FOUR CLIENT-ONLY FIXES BUILT.
2026-08-14.**

`38` closed RECORD deletion on the phone the customer is holding. This
pass asks the other question, and only that one:

> **WHEN A CUSTOMER DELETES HER JENI ACCOUNT, DOES THE ACCOUNT ACTUALLY
> DISAPPEAR?**
>
> Not "the UI logged her out". **No active account · no customer-owned
> server data · no customer-owned local data · no customer-owned storage
> object · no restorable app identity · no silently retained clinical
> payload** — except what we can explicitly prove must legally be
> retained.

`29`–`38` are frozen. No calorie formula, protein formula, merge
contract, plan selection, restore path, safety rule, payment, paywall,
`AppPhase`, `Info.plist`, entitlement, analytics event or HealthKit type
moved. **No migration applied. No migration file written to
`supabase/migrations`. No Edge Function deployed. No production row
mutated. No reaper executed. No Apple credential or Developer Portal
change. `CURRENT_PROJECT_VERSION` is still 30.**

**The census WAS run.** `docs/app_v25/deletion_audit.sql` was proven
read-only and executed against production. Everything below rests on it.

---

## 0 · THE ANSWER FIRST

**No — and the census overturned two of `38`'s own conclusions, one in
each direction.**

| # | the finding | class |
|---|---|---|
| 1 | **`signInWithApple` mints a NEW uid, always. 559 of 559 Apple identities in production were created in the SAME INSTANT as their uid — max gap ZERO seconds.** The email path preserves the uid in 278 of 308 cases (max gap 13.9 days). The doc comment on `signInWithApple` claimed the opposite; the database settles it. **FIXED at the source.** | **P0 — the orphan factory** |
| 2 | **The DEPLOYED `delete_user_account()` is NOT the repository script.** Production is `auth.uid()` check + `DELETE FROM auth.users`, and nothing else. **The storage purge that `38` §9 step 3a describes, and that `38` §11 calls "PROVEN BY CODE", is not in the deployed function.** It was proven by code that was never applied. | **P0 — a false proof** |
| 3 | **`storage.objects` is EMPTY, and the `food-photos` bucket DOES NOT EXIST.** Only `body-scans` exists (created 2026-08-04) and it holds nothing. So no customer photo has ever reached Supabase Storage — which is why (2) has caused no harm yet, and is exactly why it must be fixed before it can. | **P0-in-waiting, contained** |
| 4 | **`care_weekly_summaries` has ZERO ROWS.** `37` and `38` both scored it a P0 privacy hole with orphaned clinical payloads. There are none, there never have been, and the FK can therefore be added **and validated in one migration** with no repair step. The engineering blocker is gone; only the policy question remains. | **[CORR] — smaller than recorded** |
| 5 | **Jeni holds NO Apple credential that `/auth/revoke` accepts.** `authorizationCode` has zero call sites in first-party code, and `auth.identities.identity_data` carries `sub`/`email`/`iss` and no token of any kind. So `38`'s "P1, needs an Edge Function + the team key" is not the whole picture: **Apple's TN3194 documents a fallback for exactly this position, it needs no key and no server, and Jeni was doing none of its three steps.** **BUILT.** | **P1 → partly closed today** |
| 6 | **Account deletion was not idempotent, and one failure path ended in a lie.** Server RPC and local purge are two steps with nothing between them. A lost response aborted the local purge, the sheet said *"Couldn't delete account"*, and the retry — now on a **fresh anonymous uid** — deleted an empty account and reported **"account deleted."** while the real account's rows sat on the disk. **FIXED.** | **P0 — correctness** |
| 7 | **`public.patient_invitations.accepted_by` holds a patient's raw uid with no FK.** 10 accepted rows. Not in `38`'s census at all. | **P2 — named** |
| 8 | **The 90-day reaper has never been run.** 59 anonymous accounts sit past its own window today, 17 of them holding health data, the oldest dated 2026-04-30. | **operational** |

And the finding that decides what can honestly be claimed:

> **THE ORPHANS CANNOT BE ASSOCIATED BACK TO ANYONE.** The only record
> of a prior uid is `sync.pendingMergeV1` — a **UserDefaults dictionary,
> on one device, deleted the moment the merge completes**. There is no
> `previous_uid`, no lineage table, no merge receipt, nothing server-side
> at all.
>
> ▎ **The deletion endpoint cannot delete data it cannot associate with
> ▎ the authenticated customer.**

**Built, all client-only, no schema, no deploy:** the Apple identity link
· the deletion-intent marker and its launch finisher · TN3194's
revocation response · the deletion screen brought onto the current design
law (founder steer, mid-build).

---

## 1 · THE CENSUS WAS PROVEN READ-ONLY BEFORE IT WAS RUN

`deletion_audit.sql`, mechanically, not by reading:

| check | result |
|---|---|
| statements (split on `;`) | **8** |
| first token of every statement | **`SELECT` × 8** |
| `insert` · `update` · `delete` · `upsert` · `merge` (comment-stripped) | **0 · 0 · 0 · 0 · 0** |
| `alter` · `drop` · `create` · `truncate` · `grant` · `revoke` | **0 · 0 · 0 · 0 · 0 · 0** |
| `do $$` · `call` · `perform` · `refresh` · `vacuum` · `comment` · `set` · `lock` · `notify` · `copy` | **0 each** |
| every function called | `coalesce` · `count` · `exists` · `min` · `max` · `sum` · `pg_size_pretty` · `storage.foldername` — **all pure reads** |
| storage mutation | none — `storage.objects` appears only after `from` |

Comments were stripped first, so a keyword inside prose could not mask a
keyword in code. Run through `supabase db query --linked` as `postgres`
against `mtecqvykyeueumdynatd`. **No row was written.**

---

## 2 · Q1 · HOW MUCH CUSTOMER DATA SITS UNDER ANONYMOUS UIDS

### **NONZERO, AND LARGE.**

| figure | value |
|---|---|
| anonymous accounts | **3,424** |
| …holding at least one health row | **2,182** |
| weight rows | **2,326** |
| food rows | **652** |
| observation (symptom) rows | **53** |
| dose rows | **14** |
| oldest anonymous account | **2026-04-30** |
| newest | **2026-08-14** (today) |

Broken down by footprint, because "3,424" on its own overstates it:

| shape | accounts |
|---|---|
| completely empty (abandoned onboarding) | **1,242** |
| a `public.users` profile row | 2,161 |
| ≥1 weigh-in | **2,170** |
| ≥1 plate | 65 |
| ≥1 program plan | 124 |

**Movement is not server-backed** (`move.manual.v1` is UserDefaults, §38
§16), so it contributes nothing here by construction.

### Storage objects: **ZERO, and the reason matters**

```
storage.buckets   →  body-scans   (private, created 2026-08-04)
storage.objects   →  0 rows, all buckets
```

**The `food-photos` bucket does not exist in production.** The client
has a full upload path (`FoodPhotoSyncService`, bucket `"food-photos"`,
`{uid}/{entryId}.jpg`, with a persistent retry queue), so every upload
fails and self-queues, silently. **Out of scope and named, not fixed** —
it is a sync defect, not a deletion defect, and the brief freezes food.
Its consequence for THIS pass is precise: **there are no customer photos
on the server to orphan today, and the deployed RPC would not remove them
if there were.**

### **[CORR] Q1b is a defective predicate and its `0` means nothing**

Q1b counts anonymous accounts with health data **`and u.last_sign_in_at
is null`**. It returned **0** — but `signInAnonymously` *sets*
`last_sign_in_at`, so **no anonymous account in this project has ever had
a null there.** The query cannot return anything but 0. It is a
false-negative, not evidence. Recorded so the next reader does not quote
it as "no orphans".

### **HOW MANY OF THE 3,424 ARE ORPHANS? BOUNDED, NEVER GUESSED.**

An anonymous account is an ORPHAN only if it was **superseded** by a
named account. Nothing in the schema records that.

- **UPPER BOUND: 3,424** (2,182 with data). Every one of them *could* be
  a superseded uid.
- **LOWER BOUND: 559.** Every Apple sign-in mints a fresh uid (§3), and
  the app is anonymous-first, so each of the 559 Apple identities was
  preceded by an anonymous session that still exists unless reaped — and
  the reaper has never run (§7).
- **WHICH ONES: unknowable.** Stated plainly rather than estimated.

**No attempt was made to narrow this by timestamp proximity, device,
body metrics, food similarity, goal or email.** That is the fabrication
class this whole line of work exists to remove (`38`, DO-NOT-BUILD 6).

---

## 3 · THE ANONYMOUS → ACCOUNT TRANSITION, PROVEN

### The implementation

| path | call | endpoint | preserves uid? |
|---|---|---|---|
| **email upgrade** (`signUpWithEmail`) | `supabase.auth.update(user:)` | `PUT /user` — mutates the CURRENT user | **YES** |
| **email sign-in** (`signInWithEmail`) | `auth.signIn(email:password:)` | `POST /token?grant_type=password` | **NO** — and its own doc comment says so |
| **Apple** (`completeAppleSignIn`) | `auth.signInWithIdToken(credentials:)` | `POST /token?grant_type=id_token`, **no `Authorization` header, no `linkIdentity` flag** | **NO** |
| *(available, unused until this build)* | `auth.linkIdentityWithIdToken(credentials:)` | same endpoint **+ `linkIdentity = true` + `Authorization: Bearer <current session>`** | **YES** |

### The production data, which settles it

| provider | named users | identity created WITH the uid (<10 s) | identity attached LATER | max gap | median gap |
|---|---|---|---|---|---|
| **apple** | **559** | **559** | **0** | **0 s** | **0 s** |
| **email** | 308 | 30 | **278** | 1,199,195 s (**13.9 days**) | 446 s (7.4 min) |

`auth.identities` holds **867 rows for 867 named users — every named user
has exactly one identity, and zero accounts have more than one.** So an
identity created 13.9 days after its user row can only mean the user row
existed first without any identity, i.e. it was anonymous and was
upgraded in place. **The email path demonstrably preserves. The Apple
path demonstrably does not, with zero exceptions across 559 sign-ins.**

> **A == B?**
> **EMAIL UPGRADE: YES. APPLE: NO. EMAIL SIGN-IN ON A NEW INSTALL: NO
> (and correctly so — she is reaching an existing account).**

`AuthService.signInWithApple`'s doc comment — *"this preserves the
user_id when called from an anonymous session — the anonymous account
links to the Apple identity rather than getting replaced"* — **is false,
and was false for every customer who ever used it.** Replaced in this
build with the measurement.

### What happens to each thing she recorded

Anonymous user A records food **F**, weigh-in **W**, dose **D**, symptom
**S**, plus program state. She signs in with Apple, becoming B.

| | LOCAL | SERVER |
|---|---|---|
| **F** (food) | **REKEYED** — `FoodLogPersister.reattributeEntries`, **NEW id** (the comment says why: a same-id upsert is an UPDATE that RLS rejects) | **LEFT BEHIND** under A, and a fresh **COPY** is pushed under B ⇒ **DUPLICATED across uids** |
| **W** (weight) | **REKEYED**, new id, `pendingUpsert = true` | **LEFT BEHIND** under A + **COPY** under B |
| **D** (dose) | **REKEYED** | **LEFT BEHIND** + **COPY** |
| **S** (symptom) | **REKEYED** | **LEFT BEHIND** + **COPY** |
| program plan / facts / weekly reads | **REKEYED** | **LEFT BEHIND** + **COPY** |
| `public.users` profile row | rekeyed | **LEFT BEHIND** under A + a new row under B |
| **storage paths** | n/a | **nothing to leave** — the bucket does not exist and `storage.objects` is empty |

So the transition is **COPY + LEAVE BEHIND**, never MOVE. That is
`AppSync.onAuthChanged` → `writePendingMergeMarker` →
`reattributeLocalRows` → `retryPendingUpserts`, all of which act on the
**local** store only. Nothing has, or could have, a credential for A
after the switch.

---

## 4 · "PRIOR UID" — WHERE IS A RECORDED?

**Nowhere durable. Anywhere at all, for a few hundred milliseconds.**

| candidate | exists? |
|---|---|
| `previous_uid` / `anonymous_uid` column | **no** — repo-wide grep, zero hits in Swift, SQL or TypeScript |
| identity-link or lineage table | **no** |
| migration ledger / merge receipt | **no** |
| `auth.identities` second row | **no** — 0 accounts have >1 identity |
| **`sync.pendingMergeV1`** | **YES, and it is the only one** — a `UserDefaults` dictionary `{from: oldUid, to: newUid}`, written before reattribution, **cleared the moment the merge completes** (`clearPendingMergeMarker`), device-local, and swept by `clearOnboardingUserDefaults` |

It exists to make the merge crash-safe, not to record identity, and it is
correct for its job. It is worthless as lineage: it is gone within a
second of a successful sign-in, it never reaches the server, and it never
reaches a second device.

> ▎ **The deletion endpoint cannot delete data it cannot associate with
> ▎ the authenticated customer.**

**The minimum durable association needed** is one of exactly two things:

1. **Don't split the identity** — then there is no association to record,
   because there is only ever one uid. *(This is what was built.)*
2. **A server-side `old_uid → new_uid` row, written at merge time under a
   credential that can prove both** — which means it must be written
   while the anonymous session is still live, or by a SECURITY DEFINER
   RPC that accepts the outgoing uid and verifies the incoming one. Every
   variant is a migration plus a security review.

---

## 5 · THE SMALLEST CORRECT IDENTITY LINEAGE

| | **A · PRESERVE THE UID (link the identity)** | **B · STORE `old_uid → new_uid` LINEAGE** | **C · MIGRATE EVERY ROW, THEN DELETE THE OLD UID** | **D · SUPABASE'S OWN MECHANISM** |
|---|---|---|---|---|
| what it is | `linkIdentityWithIdToken` instead of `signInWithIdToken` | a new table + an RPC, written at merge | server-side copy of every family, then delete `auth.users` A | — |
| **NEW USERS** | **no orphan is ever created** | orphan created, then findable | orphan created, then removed | — |
| **EXISTING USERS** | **unchanged; the 559 existing orphans are untouched** | unchanged | unchanged | — |
| **OLD CLIENT (build 30)** | **unaffected** — no server contract changes | unaffected (writes nothing) | unaffected | — |
| **NEW CLIENT** | one call site | one call site + an RPC | large | — |
| **RLS** | **none** — GoTrue owns it | new policies on a new table | needs SECURITY DEFINER over both uids | — |
| **ACCOUNT DELETE** | **already correct — there is one uid** | RPC must follow the chain | already correct | — |
| **ROLLBACK** | delete four lines | drop table | irreversible mid-flight | — |
| **MIGRATION?** | **NO** | yes | yes | — |
| **SERVER DEPLOY?** | **NO** | yes | yes | — |
| **FAILURE MODE** | link refused ⇒ **falls back to today's exact call** | a lineage row written for the wrong pair ⇒ deletes someone else's data | a partial copy ⇒ data in two places, one of them about to be deleted | — |

**D is not a fourth option.** Supabase's documented route for converting
an anonymous user with an OAuth provider **is** `linkIdentity` /
`linkIdentityWithIdToken` — option A. There is no other supported
mechanism.

### **CHOSEN: A. And the reason is the brief's own rule.**

> *Prefer removing the possibility of an orphan over cleaning orphans
> later.*

An orphan, once created, **can never be associated back to her** (§4). So
every orphan is permanent by construction, and the only intervention with
leverage is the one that stops making them.

### Why Jeni was not doing this already

Not a decision — **an unexamined belief.** The doc comment asserted that
`signInWithIdToken` links from an anonymous session, the email path
genuinely does preserve the uid (so the belief was true of half the
product), and the whole merge machinery built around the Apple path is
itself the evidence that it does not. Nobody measured it until now.

### What shipped

```swift
let strategy = AppleIdentityPolicy.strategy(
    hasSession: currentSession != nil || supabase.auth.currentSession != nil,
    isAnonymous: isAnonymous
)
if strategy == .linkToCurrentUser {
    do    { session = try await supabase.auth.linkIdentityWithIdToken(credentials:) }
    catch { session = try await supabase.auth.signInWithIdToken(credentials:) }   // today's call
} else {
    session = try await supabase.auth.signInWithIdToken(credentials:)             // today's call
}
```

**The safety property that lets this touch auth on a frozen candidate:**
linking is attempted **only** from an anonymous session, and **every**
failure falls back to the exact call the product makes today. There is no
input for which this is worse than shipping nothing. The expected failure
is the common one — a returning customer whose Apple id already owns an
account gets `identity_already_exists`, and signing in is the correct
outcome.

**And the downstream code already handles the preserved-uid shape**:
`AppSync.onAuthChanged`'s `upgraded` branch (`previousMethod ==
.anonymous && newMethod == .apple && !userIdChanged`) exists, is
exercised in production by 278 email upgrades, and re-upserts the profile.
**Nothing new had to be taught to the sync layer.**

---

## 6 · THE EXISTING ORPHANS

**Q1 is NONZERO, so they are not deleted blindly and they are not
"recoverably hers".**

| allowed evidence of ownership | present? |
|---|---|
| an explicit persisted identity relationship | **NO** (§4) |

| **not** allowed, and not used | |
|---|---|
| same device · same timestamps · same body metrics · same food · same goal · same Apple email · similar sequence | **none of these were queried, joined, or inferred** |

> **VERDICT: the rows are ORPHANED, not recoverably hers. Ownership was
> not fabricated and cannot be.**

**Retention/deletion strategy, kept separate from identity recovery, as
the brief requires:**

1. The rows are customer-owned health data under a credential nobody
   holds. They are unreachable by any client, by RLS, and by
   `delete_user_account()`.
2. The only lawful, honest disposition is **deletion on a schedule** —
   which is what `scripts/cleanup_orphaned_anon_users.sql` is for, and it
   has never been run (§7).
3. **A one-time reap is NOT recommended before §7's safety questions are
   answered**, because the script's own definition of "orphaned" would
   currently delete live customers (§7).

---

## 7 · THE 90-DAY REAPER, AUDITED

`scripts/cleanup_orphaned_anon_users.sql`. Founder-run, dry-run-first,
two steps, `NOT WIRED TO ANYTHING`.

| question | answer |
|---|---|
| **Why 90 days?** | **No stated reason anywhere.** The header names the parameter and its default; nothing justifies the number. It is not derived from a retention policy, a support window, or the privacy policy (which promises the opposite — immediate, unrecoverable deletion). **An unexplained constant guarding a destructive sweep.** |
| **What qualifies as orphaned?** | `is_anonymous = true AND coalesce(last_sign_in_at, created_at) < now() - 90 days`. **That is "stale", not "orphaned".** It does not test whether the account was superseded, because nothing can. |
| **Could it delete an anonymous user still actively using Jeni?** | **YES — and this is the sharpest defect.** `last_sign_in_at` is set once, at `signInAnonymously`. The SDK refreshes the *token*, which does **not** move `last_sign_in_at`. So a customer who has used Jeni every day for 91 days without ever signing in matches the predicate and **her whole record is deleted with no warning and no undo.** Today that is **59 accounts, 17 of them holding health data.** |
| **Could it delete a legitimate offline customer's data?** | Yes, the same way, and sooner — an offline device never refreshes anything. |
| **Could it delete an account mid-conversion?** | Only for a >90-day-old anonymous session converting now. Narrow, but not zero, and the window has no interlock. |
| **What happens to storage?** | Step 2a deletes `food-photos` + `body-scans` objects by prefix **and** owner, before the users. **Correct — and strictly better than the deployed `delete_user_account()`, which does neither.** |
| **What happens to `auth.users`?** | Hard `DELETE`. |
| **Every child table?** | 24 tables cascade (§8). The five no-FK columns do **not**, so `care_audit_events`, `invitation_attempts`, `ops_events`, `care_weekly_summaries` and `patient_invitations.accepted_by` survive a reap exactly as they survive a deletion. |
| **Idempotent?** | **Yes.** Both steps are predicate-driven deletes; a second run matches nothing new. |
| **Why founder-run?** | It runs as `postgres` and bypasses RLS. That is the right reason and it is stated in the header. |
| **What schedules it today?** | **NOTHING.** |

### Proof it has never been run

59 anonymous accounts currently sit **past its own 90-day window** —
oldest `2026-04-30`, newest stale `2026-05-16`, which is exactly 90 days
before today. If it had ever run, that set would be empty.

> **IS THE 90-DAY REAPER SAFE? NO.** Not because it deletes too much, but
> because **its liveness signal is wrong**: `last_sign_in_at` does not
> move for an anonymous user who is using the app. It must not become a
> cron job until it tests real activity — the newest row across
> `weight_logs` / `food_logs` / `dose_events` / `observations` /
> `day_progress` for that uid — instead of an auth timestamp that is
> written once and never again.

---

## 8 · `delete_user_account()` — THE DEPLOYED FUNCTION, LINE BY LINE

Read from `pg_proc` in production, not from the repository:

```sql
CREATE OR REPLACE FUNCTION public.delete_user_account()
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE requesting_user_id uuid;
BEGIN
    requesting_user_id := auth.uid();
    IF requesting_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;
    DELETE FROM auth.users WHERE id = requesting_user_id;
END;
$function$
```

**`scripts/delete_user_account.sql` in the repository contains a
`DELETE FROM storage.objects` block. The deployed function does not.**
`38` §9 step 3a describes that block as live and `38` §11 records object
storage as **"PROVEN BY CODE"**. It was proven by code that was never
applied. **A repository file is not a deployed function, and this is the
second time that class of error has been recorded** (`38` §0 found the
same shape in `AuthService.signInWithApple`'s comment).

### Every customer-owned table, from the live catalog

**CASCADE — deleted by `DELETE FROM auth.users` (24):** `public.users` ·
`weight_logs` · `food_logs` · `food_log_items` · `food_corrections` ·
`dose_events` · `observations` · `program_plans` · `program_day_checks` ·
`program_facts` · `weekly_reads` · `regimen_plans` · `session_logs` ·
`session_ratings` · `day_progress` · `day_reflections` ·
`exercise_calibrations` · `consent_grants` · `coach_messages` ·
`visit_packets` · `org_members` · `care_relationships` ·
`correction_requests` · `protocol_assignments`.

**SET NULL — row survives, de-identified (2), a stated choice:**
`food_vision_telemetry` (1,112 rows, 1 currently null) ·
`jeni_chat_telemetry` (228 rows, 0 currently null).

**NOT TOUCHED — no FK, no cascade, no delete policy (5 customer-facing):**

| table.column | rows | verdict |
|---|---|---|
| `public.care_weekly_summaries.user_id` | **0** | §9 |
| `public.care_audit_events.patient_id` | 135 (0 orphans) | audit trail; defensible, undecided |
| `public.patient_invitations.accepted_by` | **10** | **NEW — not in `38`'s census.** A patient's raw uid on a clinic invitation |
| `private.invitation_attempts.user_id` | 29 (0 orphans) | rate limiting, no health content |
| `public.ops_events.actor_id` | 0 | operational |

*(Also no-FK but clinician-side, not customer-owned:
`correction_requests.resolved_by` · `protocol_assignments.assigned_by` ·
`patient_invitations.created_by` · `private.org_provisioning_codes.used_by`.)*

**STORAGE — not touched by the RPC at all.** `storage.objects` has
exactly one foreign key, `objects_bucketId_fkey`, to `storage.buckets`.
**There is no `owner → auth.users` foreign key**, so the "owner is SET
NULL on user deletion" reasoning in the repo script's header is wrong
about this project — nothing happens to those rows on user deletion,
because nothing connects them. The client's pre-RPC
`BodyScanSyncService.deleteAllRemote` is currently the **only** thing
that removes a storage object on account deletion.

**`auth.users`** — deleted. **`private` schema** — only
`invitation_attempts` (above). **`care` schema** — does not exist; the
care tables live in `public`. **`coach_messages`** — 0 rows, cascades,
still a false contract (`37` §4B).

**No table is marked "probably".**

---

## 9 · `care_weekly_summaries` — THE ENGINEERING BLOCKER IS GONE

### Q2, from production

| figure | value |
|---|---|
| total rows | **0** |
| rows with a living user | 0 |
| **orphan rows** | **0** |
| distinct orphaned user ids | **0** |
| earliest / latest week | null / null |

**`37` §16 and `38` §10 both scored this a P0 with a clinic patient's
weekly jsonb payloads orphaned permanently. There are none. There never
have been.** The writer (`WeeklySummaryPublisher.publishIfConnected`) is
gated on an active `visit_packet_view` consent, and although 10
`care_relationships` and 31 `consent_grants` exist, not one summary has
ever been written.

### **CAN AN FK BE ADDED IMMEDIATELY? YES.**

Q2 = 0 orphans, so `not valid` is **not** required and no repair step
exists. The FK can be added **and validated in a single migration**.

**That is the engineering answer. It is not the decision.**

---

### OPTION A — DELETE WITH THE ACCOUNT

```sql
-- FORWARD
alter table public.care_weekly_summaries
  add constraint care_weekly_summaries_user_fk
  foreign key (user_id) references auth.users(id) on delete cascade;
-- Q2 = 0 rows, so this validates immediately. No `not valid` step.

-- ROLLBACK
alter table public.care_weekly_summaries
  drop constraint care_weekly_summaries_user_fk;
```

| | |
|---|---|
| **schema** | one constraint. Zero rows to validate. |
| **product behavior** | unchanged for everyone; a future clinic patient's summaries vanish with her account |
| **privacy policy** | *"No soft-delete; the data is unrecoverable"* becomes true for this table |
| **clinic consequence** | a clinician loses the weekly series for a patient who deletes her account, with no notice |
| **App Store** | fully aligned with 5.1.1(v) |
| **implementation** | one migration, no client change, build 30 unaffected |
| **old/new client** | both safe — no client reads or writes `user_id` differently |
| **deploy order** | standalone; no ordering constraint |

### OPTION B — RETAIN UNDER AN EXPLICIT POLICY

```sql
-- FORWARD
comment on table public.care_weekly_summaries is
  'RETAINED BEYOND ACCOUNT DELETION under clinical-record policy <ref>.
   user_id is intentionally NOT a foreign key. See <policy doc>.';

-- ROLLBACK
comment on table public.care_weekly_summaries is null;
```

| | |
|---|---|
| **schema** | a comment; the omission becomes a decision |
| **product behavior** | unchanged |
| **privacy policy** | **must change** — the "unrecoverable" sentence acquires a named, bounded exception, and the exception must state the obligation and the period |
| **clinic consequence** | continuity of care preserved |
| **App Store** | **permitted** — Apple allows data that must legally be retained, provided the retention is legitimate and the deletion behaviour is transparent to the user |
| **implementation** | comment + privacy-policy edit + **the consent sheet must say so before the next clinic patient connects** |
| **deploy order** | the copy must land **before or with** the comment; a retention obligation the customer was not told about is not an obligation, it is a surprise |

*(A third shape — retain de-identified — is named in `38` §10(c) and not
re-drafted. Q2 = 0 removes its only advantage, which was avoiding a
backfill.)*

> ### **FOUNDER / COUNSEL DECISION REQUIRED**
>
> **The question is narrow and it is now cheap:** with zero rows on the
> table, **nobody's data is at stake either way**, and the choice can be
> made before the first clinic patient generates a summary rather than
> after.
>
> This document does **not** decide whether Jeni is a covered entity,
> whether these are medical records, or whether a retention obligation
> exists. It records that the standing law says *"internal dev alpha,
> test data only, NO BAA"*, which means the question has never been
> answered, not that it does not apply.
>
> **Neither migration is written to `supabase/migrations`.** A file in
> that directory is applied by the next `supabase db push`, and this
> choice must be made by a person first.

---

## 10 · SIGN IN WITH APPLE — RE-EVALUATED AGAINST APPLE'S CURRENT DOCS

Sources read this session, not recalled:

- **TN3194: *Handling account deletions and revoking tokens for Sign in
  with Apple*** — first published **2025-10-03**.
- **Token revocation** (`POST https://appleid.apple.com/auth/revoke`).
- **Offering account deletion in your app.**

### What Apple requires

- Apps supporting Sign in with Apple **must use the REST API to revoke
  user tokens** on account deletion. Enforced since **June 30, 2022**.
- `/auth/revoke` takes `client_id`, `client_secret`, `token`,
  `token_type_hint` (`refresh_token` | `access_token`), as
  `application/x-www-form-urlencoded`. **A valid refresh token OR access
  token is required.** An identity token is not accepted; a `sub` is not
  accepted.
- It returns **`200` with no body on success *or if the token was already
  invalidated*** — **revocation is idempotent by Apple's own contract**,
  which matters for §13.
- **The documented fallback, verbatim:** *"If you don't have the user's
  refresh token, access token, or authorization code, you must still
  fulfill the user's account deletion request and meet the account
  deletion requirement… 1. Delete the user's account data from your
  systems. 2. Direct the user to manually revoke access for your client.
  3. Respond to the credential revoked notification to revert the client
  to an unauthenticated state."*
- **Subscriptions:** notify the user that auto-renewable billing
  continues through Apple, and **request that they cancel before
  deleting**.

### What Jeni actually possesses

| credential | held? | where |
|---|---|---|
| **`authorizationCode`** | **NO** | Apple hands it to the delegate; `AppleSignInService` reads `identityToken`, `fullName`, `email` and **never `credential.authorizationCode`**. Repo-wide: **zero call sites in first-party code** |
| **`identityToken`** | transiently | passed to Supabase, never persisted by Jeni |
| **Apple `accessToken`** | **NO** | requires exchanging the authorization code at `/auth/token`; never done |
| **Apple `refreshToken`** | **NO** | same |
| **does Supabase hold one?** | **NO** | `auth.identities.identity_data` for all 559 apple rows holds exactly `email`, `phone_verified`, `email_verified`, `sub`, `custom_claims`, `provider_id`, `iss`. **No token key of any kind** — `signInWithIdToken` never receives an authorization code, so GoTrue has nothing to store |

*(Key NAMES only were selected. No token, email, name or `sub` value was
read or printed.)*

> ### **CAN JENI REVOKE TODAY? NO.**
>
> And the gap is one step earlier than `38` recorded. It is not "we never
> call `/auth/revoke`". It is **"we throw away the only credential that
> could ever reach it."**

### **THE PRIORITY IS RECLASSIFIED**

`38` called this **P1, blocked on an Edge Function and the team key**.
That is true of *token* revocation. It is **not** true of the
*requirement*: Apple's own fallback needs **no key, no server, and no
Developer Portal change**, and Jeni was doing **none of its three steps**
— it did not tell her to revoke, and it observed no revocation
notification anywhere (`ASAuthorizationAppleIDProvider` appeared in
exactly one place in the repository: creating the sign-in request).

**So the compliance-relevant half is P0-shaped and client-only, and it
shipped here.** The token path stays P1 and stays gated.

---

## 11 · THE SERVER PATH, DESIGNED AND GATED

**The Apple private key never goes in the app.** Designed, not built.

```
1  client  · capture credential.authorizationCode alongside the identityToken
2  client  · POST it to a new Edge Function over the customer's Supabase JWT
3  server  · build client_secret: ES256 JWT signed with the team .p8
              iss=TEAM_ID  aud=https://appleid.apple.com  sub=BUNDLE_ID
              iat=now      exp<=now+6mo
4  server  · POST /auth/token  grant_type=authorization_code  → refresh_token
5  server  · store {supabase_uid → apple_refresh_token} encrypted, RLS-denied
              to `authenticated`, readable only by the function's role
6  later   · account deletion:
              a  read the stored refresh token
              b  POST /auth/revoke  token_type_hint=refresh_token
              c  on 200, delete the stored token row
              d  CONTINUE THE DELETION REGARDLESS OF (b)
```

### Exact ordering, and the one question that matters

> **If Apple revocation fails temporarily, should customer data deletion
> fail too? NO. Emphatically.**

Making a privacy deletion depend on a third party's availability means an
Apple outage becomes a Jeni retention event. Apple's own fallback assumes
the app may have no usable token at all and still requires the deletion
to complete. **Revocation is best-effort and never blocks.**

Ordering: **revoke BEFORE the DB delete** (while a credential still
exists to look the token up with), then delete regardless of the outcome.

| Apple's answer | what Jeni does |
|---|---|
| **200** | token row deleted; continue deletion; nothing shown to her |
| **200 (already invalidated)** | identical — Apple documents the same response, so no special case exists |
| **400** (`invalid_grant`, token already dead) | treat as done; continue deletion |
| **timeout / network failure** | **continue the deletion**; leave the token row for a retry sweep; **never surface it to her** |
| **any 5xx** | same as timeout |
| **legacy account with no refresh token** (all 559 today) | **Apple's documented fallback**: delete the data, tell her the one step she must take, and honour the revocation notice when it arrives — which is what shipped |

**Required to build it:** one Edge Function · one Apple `.p8` Sign in
with Apple key + Key ID + Team ID as Supabase secrets · one table for the
stored tokens (migration) · one client line to capture the authorization
code. **All four are founder-gated. None was created.**

**`credential.authorizationCode` was deliberately NOT captured in this
build.** It is worthless without step 3, and capturing a credential the
app cannot use is dead code that looks like compliance.

---

## 12 · CREDENTIAL REVOCATION EVENTS

| | before | after |
|---|---|---|
| `ASAuthorizationAppleIDProvider.credentialRevokedNotification` | **not observed** | **observed** (`AppleCredentialWatcher`, started from `bootstrap` beside the auth-event listener) |
| `getCredentialState(forUserID:)` | never called | called to **confirm** before acting |
| server-to-server `consent-revoked` endpoint | **none** | **still none — deliberately** |

**If she revokes Jeni from Apple Settings, does Jeni become
unauthenticated?** **Before: no** — she stayed signed in, with her record
on the phone, indefinitely. **Now: yes**, and TN3194's required response
runs — local data deleted, session dropped, app reverted to
unauthenticated.

**If Apple tells the server consent was revoked, what happens?**
**NOTHING — the gap is named, not closed.** No S2S endpoint is
registered. TN3194 offers it as the route *for web services*; Jeni is a
native client and the native notification is its documented route.
Building both would be a deploy plus a Developer Portal change for a
second delivery of the same fact.

### The one honest limitation, stated

`getCredentialState` needs the Apple user identifier, which Jeni never
stored — so for **all 559 existing Apple customers the state cannot be
read**. A watcher that stayed silent without one would help nobody who
currently has the problem. So: **state readable ⇒ confirm; state
unreadable ⇒ act on the notification**, because the system posts it for
*this app's* credential and reverting is recoverable in one tap. From
this build forward the identifier is stored (`apple.user.identifier.v1`,
an identifier and not a token, already on the server as
`identity_data.sub`, swept with the account) and the confirming path is
the normal one.

**What this does NOT do:** it does not delete her server rows. Revoking
Sign in with Apple is not a request to delete an account. Apple issues
the same `sub` for the same Apple ID and team, so signing in again lands
on the same Supabase user and hydrates the record back.

---

## 13 · ACCOUNT DELETE MUST BE IDEMPOTENT

**Before this build, the sequence was:** body-scan purge → RPC → *(throw
⇒ abort everything)* → local SwiftData sweep → UserDefaults sweep →
notifications → sign-out.

| # | failure | WHAT REMAINS (before) | CAN RETRY FINISH? | CAN RETRY MAKE IT WORSE? | AFTER |
|---|---|---|---|---|---|
| **A** | storage deleted, DB fails | body-scan cloud copies gone, everything else intact | yes | no | unchanged, and correct — the purge is best-effort and never blocks |
| **B** | DB deleted, Apple revoke fails | n/a today (no revoke) | — | — | **revoke never blocks; deletion proceeds** (§11) |
| **C** | Apple revoke succeeds, DB fails | n/a today | — | — | deletion is retryable; the revoke is idempotent by Apple's contract |
| **D** | auth user deleted, cleanup retry occurs | — | — | — | the RPC is `DELETE … WHERE id = auth.uid()`; a second call finds nothing. **Idempotent** |
| **E** | **app dies after server success, before local purge** | **EVERY local record, forever.** No marker existed anywhere that the purge was owed | **NO** | — | **`AccountDeletionIntent` at stage `.serverComplete` ⇒ `finishInterruptedAccountDeletion` completes it at the next launch, scoped to that uid** |
| **F** | **she taps Delete twice** | **the lie.** First tap's RPC succeeded but the response was lost ⇒ throw ⇒ local purge skipped ⇒ *"Couldn't delete account"*. Second tap runs on a **fresh anonymous uid**, deletes that empty account, and the screen says **"account deleted."** while the real account's rows are still on disk | **NO — it converged on a false success** | **YES** | the marker names **whose** purge is owed; the second tap's dead session classifies **definitive ⇒ serverComplete ⇒ the right account is purged** |

### The two states, and why there must be two

```
.requested       she asked; the server's answer is UNKNOWN.
                 Nothing is purged on the strength of this.
.serverComplete  confirmed, or confirmed by absence.
                 The local purge is OWED and will finish.
```

**Deletion converges toward deletion — but never toward data loss with
the server intact.** On a transient failure the device destroys nothing,
because purging locally while the server keeps its copy is strictly worse
than not starting: she loses the only copy she can still reach.

**And the finisher runs the WHOLE local purge, not the SwiftData half.**
Found by a test that measures the footprint rather than the sweep: with
`clearLocalUserRecords` alone, **every workout she typed into MOVE
survived an interrupted deletion** — `move.manual.v1` lives in
`UserDefaults`, which is exactly the hole `38` closed for the completed
path and which this one would have re-opened. **A defect found in my own
fix, by the test, before it shipped.**

### The one boundary that remains

An RPC that **succeeds and whose response is lost** cannot be
distinguished from one that failed. It converges on the retry — the
session is dead by then, which classifies definitive — but the first tap
still shows a failure for a deletion that happened. **Stated, not dressed
up.** Closing it needs an idempotency key on the RPC, which is a server
change.

---

## 14 · FAILURE UX

Settings was not redesigned; the deletion state was audited and the
minimum was changed.

| state | condition | what she sees |
|---|---|---|
| **SUCCESS** | verdict `.serverComplete` **and** local purge completed | `account deleted.` |
| **PARTIAL / RETRYABLE** | verdict `.retryable` — the server did not confirm | the existing failure line, and **it is now true**: before, this sentence could appear when the server HAD deleted |
| **LOCAL CLEANUP REQUIRED** | intent at `.serverComplete`, purge unfinished | **nothing** — the next launch finishes it. There is no action for her to take, so asking her to take one would be theatre |
| **SERVER COMPLETE** | as above | same |

**The screen can no longer say "account deleted." for a deletion that
only half happened**, because `.succeeded` is now reachable only through
`.serverComplete`. And it does not trap her: an Apple revocation failure
never blocks the deletion, so there is no state where a third party's
availability leaves her unable to finish.

### THE SCREEN, BROUGHT ONTO THE CURRENT DESIGN LAW

**Founder steer, mid-build:** *"the design of the screen is not up to
date with current design of jeni."* Correct — it predated v21 and still
wore the old chrome. Against `docs/design` and `37` §13 that was four
violations:

| was | law | now |
|---|---|---|
| a boxed warning card, 24pt radius, 1.5pt coloured stroke, offset shadow rectangle | the one card is white, 20pt, no border, no shadow, and **never boxes prose** | eyebrow · serif masthead · **one hairline** · prose on paper |
| a **rose-filled** primary capsule | **one ink capsule** (`26` retired the last rose primary) | `JFContinueButton` — the same object every other primary action in Jeni is made of |
| a **bordered** secondary capsule with a second offset shadow | secondary CTA is **bare text, no border** | its tertiary text link |
| a 52pt filled green `checkmark.circle.fill` on success | no slot in the palette for a filled system glyph in a state colour | the sentence alone, in the same eyebrow-over-masthead shape as the question |

`permanent` keeps the state tint: it is the one word that names the
stakes, and it is a word, not a box.

### **AND FILMING FOUND A PRE-EXISTING ACCESSIBILITY DEFECT**

At **AX5**, filmed **before** anything was added: the warning card alone
is taller than the display, so the masthead sat above the top edge and
**`delete account` and `cancel` were both off the bottom, with no way to
reach either.** Guideline 5.1.1(v) requires account deletion to be
initiable in the app; **at accessibility text sizes it was not.**

Pre-existing, in the shipping build, found by filming rather than by
reading — the fifth time (`27`, `33`, `36`, `37`) that has happened. The
added Apple sentence made it three lines worse. **Fixed with a
`ScrollView` + `.scrollBounceBehavior(.basedOnSize)`**, so nothing moves
at any size that already fits. Re-filmed at default and AX5: masthead
visible, hairline correct, nothing truncated, both actions reachable.

---

## 15 · SUBSCRIPTIONS

Apple requires the app to notify the customer that auto-renewable billing
continues through Apple and to **request cancellation** before deletion.

**The shipping copy already does both, verbatim:**

> *"this permanently deletes your routine history, progress, and account.
> **if you have an active subscription, cancel it from your iOS settings
> first. deletion does not cancel App Store subscriptions.**"*

**True, explicit, and unchanged.** Deleting a Jeni account does not touch
a StoreKit subscription and the screen says so in the sentence before the
button. **No subscription management was built.** The only sentence added
to this screen is Apple's revocation step, and it is shown to Apple
customers only.

---

## 16 · WHAT WAS BUILT, AND WHAT EVERY CHANGE REQUIRES

### CLIENT ONLY — shipped in this build

| # | change | files |
|---|---|---|
| 1 | **`AppleIdentityPolicy` + link-first Apple sign-in.** Stops the orphan factory. Falls back to today's exact call on any failure | `Auth/AppleAccountPolicy.swift` (new) · `Auth/AuthService.swift` |
| 2 | **`AccountDeletionIntent` + `AccountDeletionVerdict` + `AppSync.finishInterruptedAccountDeletion`.** Deletion converges | `Sync/AccountDeletionIntent.swift` (new) · `Sync/AppSync.swift` |
| 3 | **`AppleRevocationPolicy` + `AppleCredentialWatcher` + `handleAppleCredentialRevoked`.** TN3194 step 3, and the Apple user identifier it needs | `Auth/AppleAccountPolicy.swift` · `Auth/AppleSignInService.swift` · `Auth/AuthService.swift` · `Sync/AppSync.swift` |
| 4 | **`DeleteAccountCopy` + the design-law pass + the AX5 scroll fix** | `Views/Settings/DeleteAccountSheet.swift` |

### MIGRATION — drafted, NOT written to `supabase/migrations`

| # | migration | blocked on |
|---|---|---|
| a | **`care_weekly_summaries` FK** — OPTION A or B, §9. Q2 = 0 so it validates in one statement | **founder / counsel** |
| b | **The storage purge restored to `delete_user_account()`** — forward/rollback below | founder apply |
| c | `comment on table` for `care_audit_events`, `patient_invitations`, `invitation_attempts`, `ops_events` — four omissions become four decisions | founder |
| d | Apple refresh-token storage table (§11) | founder + the `.p8` |
| e | `jeni_memories` (`37` §4A / `38` §14) · `users.onboarding_age_years` — unchanged, still gated | founder |

**(b), in full:**

```sql
-- FORWARD — restores the block the repository has always had and the
-- deployed function has never had. Additive to the function body.
CREATE OR REPLACE FUNCTION public.delete_user_account()
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE requesting_user_id uuid;
BEGIN
    requesting_user_id := auth.uid();
    IF requesting_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;
    DELETE FROM storage.objects
    WHERE bucket_id IN ('food-photos', 'body-scans')
      AND (name LIKE requesting_user_id::text || '/%'
           OR owner = requesting_user_id);
    DELETE FROM auth.users WHERE id = requesting_user_id;
END;
$function$;

-- ROLLBACK — re-apply the currently deployed body (drop the storage DELETE).
```

- **OLD CLIENT (build 30): SAFE.** It calls the same RPC by name and
  reads no result; it deletes strictly more, and today there is nothing
  to delete (`storage.objects` is empty).
- **NEW CLIENT: SAFE.** Identical, plus the client's pre-RPC body-scan
  purge stays as the belt to this braces.
- **DEPLOY ORDER: standalone.** No client depends on it. It should land
  **before** the `food-photos` bucket is ever created.

### EDGE FUNCTION — designed, not written (§11)
### SUPABASE AUTH CONFIG — none required (linking is a client call)
### APPLE DEVELOPER CONFIG — a Sign in with Apple `.p8` key, Key ID, Team ID (§11). **Not created.**

### ONE-TIME DATA REPAIR — proposed, NOT run

**The orphan reap.** `cleanup_orphaned_anon_users.sql` must first have
its liveness predicate corrected (§7) — `last_sign_in_at` does not move
for an active anonymous user, and 59 accounts (17 with health data) match
its window today. **Do not schedule it and do not run it until that is
fixed.**

### LEGAL / FOUNDER DECISION — §9, and only §9.

---

## 17 · RED → GREEN

`plankAITests/AccountDeletionContractTests.swift`, **15 tests.** Every one
is a customer promise.

### RED, MEASURED

With the four cores at their pre-session behaviour (`AppleIdentityPolicy`
always `.signInAsAppleUser`, `AppleRevocationPolicy` always `.ignore`,
`AccountDeletionVerdict` always `.retryable`, `AccountDeletionIntent` and
`finishInterruptedAccountDeletion` no-ops):

```
Executed 14 tests, with 10 failures (0 unexpected)
** TEST FAILED **     exit 65
```

**8 of 14 methods red, 10 assertion failures.** The six that passed, and
why each is honest:

| passed under the stub | why |
|---|---|
| `testAReturningCustomerSigningInOnANewPhoneStillReachesHerAccount` | **a control** — it asserts the OLD behaviour is preserved, and the stub IS the old behaviour |
| `testWhenLinkingIsImpossibleSignInStillSucceedsTheOldWay` | same — the fallback is today's call |
| `testARevocationNoticeNeverSignsOutSomebodyItDoesNotConcern` | **a refusal test, and a stub that ignores everything satisfies it.** It cannot tell *"refused rightly"* from *"cannot act at all"* — **the sixth session running** |
| `testTheDeletionCopyStaysTrueAndStaysInVoice` | vacuous against a nil string; it pins the copy once the copy exists |
| `testDeletingTheAccountLeavesNothingSheAuthoredOnThisDevice` | **passed correctly** — this is `38`'s shipped sweep, and this file does not get to claim credit for it. It is the regression pin |
| `testTheDeletionMarkerNeverOutlivesTheAccountItNamed` | vacuous while `pending()` always returns nil |

The 15th test (`testARevocationIsHonouredEvenWhenTheCredentialStateCannotBeRead`)
was written after that measurement, so it was **proved red separately**
by reverting its one branch:

```
Executed 1 test, with 1 failure (0 unexpected)
** TEST FAILED **     exit 65
```

### A defect this session found in its own work

`finishInterruptedAccountDeletion` first ran `clearLocalUserRecords`
only, and two tests went red at `1` instead of `0`: **`move.manual.v1`
survived an interrupted deletion.** The finisher now runs the whole local
purge. **The test measured the footprint, not the sweep, which is the
only reason it caught it.**

### And a fixture leak of my own, fixed in MY file

The full suite failed once on
`ReattributionTests.testReattributeModelRows_movesAnonRows_scopesToOldId_remapsPointers`
(`3` vs `2`, *"a no-match reattribution must not add, drop, or duplicate
rows"*). `testAnUnconfirmedDeletionNeverDestroysHerDataOnItsOwn`
deliberately leaves its record standing — that is its whole assertion —
and so it is also the test that must clean up after itself. **Fixed with
`defer { wipe(uid) }` in my file. The other test was not weakened.** The
identical trap `36` recorded.

---

## 18 · WHAT THE TESTS PROVE, AND WHAT THEY CANNOT

| the brief's contract | status |
|---|---|
| ANONYMOUS → records data → signs in → deletes → zero recoverable data | **local half GREEN**; the server half is now *structurally* true because the uid no longer splits (§5), and that half is **NOT** asserted by a test |
| SIGNED-IN → records data → deletes → zero recoverable data | **GREEN locally** (`testDeletingTheAccountLeavesNothingSheAuthoredOnThisDevice`) |
| DELETE ACCOUNT TWICE → converges safely | **GREEN** (`testDeletingTwiceFinishesTheFirstAccountNotTheSecond`) |
| server delete succeeds / local purge interrupted → next launch finishes | **GREEN** (`testAServerDeletionThatWasInterruptedFinishesOnTheNextLaunch`) |
| Apple revocation fails → deletion still converges | **GREEN by construction** — revocation is not in the deletion path at all; it never blocks |
| Apple revocation succeeds / DB cleanup retries → eventually zero | **partly** — the notice path is GREEN; the token path does not exist (§11) |
| ACCOUNT B ON SAME PHONE → inherits zero account-A facts | **GREEN** (`testDeletingTwiceFinishesTheFirstAccountNotTheSecond` + `38`'s two-account control) |

### **WHAT REMAINS UNPROVEN IN PRODUCTION, STATED PLAINLY**

**No server success was faked and no fake was used to simulate one.**
Three things cannot be proven from this repository and are not claimed:

1. **That `linkIdentityWithIdToken` succeeds against THIS project's
   GoTrue.** It needs a real Apple credential and a live sign-in. The
   fallback makes the worst case identical to today, which is why it is
   shippable — but **the first Apple sign-in on a device is the founder's
   check**, and the proof is one SQL line: after it, that customer's
   `auth.users.created_at` should be **older** than her
   `auth.identities.created_at`.
2. **That the deployed RPC drops every cascading row.** Proven from the
   live catalog (§8), not from a call.
3. **That a deletion propagates to a second device.** It still does not
   (`38` §21.1). Unchanged and out of scope.

---

## 19 · THIS IS NOT THE TOMBSTONE PASS

`38` identified the server-tombstone migration for RECORD deletion across
two devices. **It was not built here, not designed further, and not
blurred into this work.** Record deletion and account deletion are
related and distinct: `38` finished the first on the deleting device,
`39` finishes the second, and `40` can finish network-wide record
deletion. Q3 sizes it: **12 accounts of 4,279 have more than one session,
max 9; zero have more than one identity.** Read as a bound, not a figure
— a session is not a device.

---

## 20 · RELEASE PROOF

Every command run **serially**, unpiped, `$?` captured directly (`32`
§13 — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/AccountDeletionContractTests` | 15 | **15** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` (full app suite) | 1288 | **1288** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` (from the package dir) | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` (from the package dir) | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.1 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is a SUCCEEDED line.** App suite **1273 → 1288, exactly +15**,
which is `AccountDeletionContractTests` and nothing else: **no existing
test changed and none needed to.**

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **85 MB, 123,492 strings** — size
and total stated first, because *a zero from a file that does not exist
is the `Executed 0 tests` trap in different clothes* (`35`). The first
lookup this session returned **NOT FOUND and the check refused to print
zeros**, which is the guard working.

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `debug-delete-account` (this session's new door) | **0** |
| `persona-customer` · `uitest-cbt-lesson` | **0 · 0** |
| `sign-in and security` | **1** — Apple's fallback step ships |
| `account.deletion.intent.v1` | **1** — the convergence marker ships |
| `apple.user.identifier.v1` | **1** — the revocation confirmation ships |
| `AppleIdentityPolicy` · `AppleRevocationPolicy` · `AccountDeletionIntent` · `AppleCredentialWatcher` (`nm`) | **6 · 3 · 16 · 43** |

### Protected paths vs the reviewed release `1710180`

| path | diff |
|---|---|
| `PlankApp/Payment` · `Views/Paywall` | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** |
| **`supabase/migrations`** | **EMPTY** |
| `supabase/` | `27`'s food-vision EF, still undeployed. **This session: EMPTY.** |
| `PlankApp/Analytics` | `31`'s +6. **This session: EMPTY.** |
| `Packages/PlankFood` | `26`/`27`/`34`. **This session: EMPTY.** |
| `Packages/PlankSync` | `31`/`34`/`36`/`38`. **This session: EMPTY.** |
| **`PlankApp/Auth`** | **+91 −12, and it is ALL this session** — `38` recorded it EMPTY |

> **`PlankApp/Auth` IS A PROTECTED PATH AND IT MOVED. Stated first, not
> buried.** It is the only place the orphan can be prevented, the change
> is gated on `isAnonymous`, and **every failure falls back to the exact
> call the product makes today** — so the worst case is today's
> behaviour. Nothing in the paywall, payment, entitlement or `AppPhase`
> chain was touched, and `signInWithEmail`, `signUpWithEmail`, `signOut`,
> `bootstrap`'s restore ladder and `classifyVerifyFailure` are all
> byte-identical.

**All three files that declare a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **zero diff
against `1710180`**, re-derived this session with
`grep -rlE "^[[:space:]]*@Model"`. **There is no SwiftData store
migration to fail.** The deletion intent lives in `UserDefaults` for
exactly that reason, following `38`'s ledger.

The `project.pbxproj` diff contains **only file references** — verified by
filtering for anything that is not a `PBXBuildFile` / `PBXFileReference` /
group-child line and getting an empty result.
**`CURRENT_PROJECT_VERSION` is still 30**, `MARKETING_VERSION` still
`1.2.0`; the archive-time bump to 31 stands and is the founder's step.

### This session's files — eight

`Auth/AppleAccountPolicy.swift` **(new, 235)** ·
`Sync/AccountDeletionIntent.swift` **(new, 153)** ·
`Auth/AuthService.swift` · `Auth/AppleSignInService.swift` ·
`Sync/AppSync.swift` · `Views/Settings/DeleteAccountSheet.swift` ·
`App/DebugPreviewRoutes.swift` ·
`plankAITests/AccountDeletionContractTests.swift` **(new, 15 tests, 370)**
· `project.pbxproj` (three file references) · this document.

**One new DEBUG door**, and it is stated: `--debug-delete-account`
(`--debug-delete-account-email` for the control face). It mounts the
sheet **alone** — walking to it through Settings films the paywall on the
way (`30` §12.1, `36`). **0 occurrences in the Release binary.**

---

## 21 · THE TWENTY ANSWERS

**1 · HOW MANY ORPHANED ANONYMOUS USERS EXIST IN PRODUCTION?**
**Between 559 and 3,424, and which ones is unknowable.** There are
**3,424** anonymous accounts, **2,182** holding health data (upper
bound). **559** Apple sign-ins each definitively abandoned an anonymous
uid (lower bound). **1,242 are completely empty** — abandoned onboarding.
No link exists between an anonymous uid and the named uid that replaced
it, so no query can name the orphans, and none was invented.

**2 · HOW MANY CUSTOMER-OWNED ROWS DO THEY HOLD?**
**3,045 health rows** across all anonymous accounts: **2,326 weigh-ins ·
652 plates · 53 symptoms · 14 doses**, plus **2,161 profile rows** and
**124 program plans**. **Zero storage objects** — the `food-photos`
bucket does not exist and `storage.objects` is empty.

**3 · WHICH RECORD FAMILIES ARE AFFECTED?**
`weight_logs` · `food_logs` · `observations` · `dose_events` ·
`program_plans` · `public.users`, plus every other cascading family that
happens to be non-empty for a given uid. **Not** movement (device-only),
**not** photos (none exist), **not** body scans (none exist).

**4 · WHY DO THOSE ROWS SURVIVE ACCOUNT DELETION?**
`delete_user_account()` scopes to `auth.uid()`. After an Apple sign-in
the customer's `auth.uid()` is a **different** uid, and the client no
longer holds any credential that can reach the old one. The RPC cannot
delete what it cannot name, and nothing anywhere names it.

**5 · DOES SIGNING IN PRESERVE THE ANONYMOUS UID?**
**Email upgrade: YES** (278 of 308 in production, max gap 13.9 days).
**Apple: NO — 559 of 559, max gap ZERO seconds.** The doc comment
claiming otherwise was false for every customer who ever used it.

**6 · IF NOT, WHAT IS THE MINIMUM CORRECT IDENTITY-LINEAGE FIX?**
**Do not split the identity.** `linkIdentityWithIdToken` instead of
`signInWithIdToken` when the current session is anonymous, falling back
to `signInWithIdToken` on any failure. **No migration, no deploy, no auth
config, no RLS, one call site**, and the method is already in the pinned
supabase-swift. **BUILT.**

**7 · CAN EXISTING ORPHANS BE SAFELY ASSOCIATED WITH CURRENT USERS?**
**NO.** The only record of a prior uid is `sync.pendingMergeV1`, a
device-local UserDefaults dictionary deleted the moment the merge
completes. Timestamps, devices, body metrics, food, goals and Apple
emails were **not** used and must not be. **They are orphaned, not
recoverably hers.**

**8 · IS THE 90-DAY REAPER SAFE?**
**NO.** Its liveness signal is `last_sign_in_at`, which is written once
at `signInAnonymously` and **never moves for an anonymous customer who is
actively using Jeni**. Today **59 accounts match its window, 17 of them
holding health data.** It is otherwise well built — idempotent, dry-run
first, and its storage purge is *better* than the deployed RPC's. **Do
not schedule it until the predicate tests real row activity.** Nothing
schedules it today.

**9 · HOW MANY `care_weekly_summaries` ARE ORPHANED?**
**ZERO. The table has zero rows.** `37` and `38` both scored this a P0
with orphaned clinical payloads; there are none and never have been. The
FK can be added **and validated in one statement**.

**10 · SHOULD `care_weekly_summaries` CASCADE ON ACCOUNT DELETE?**
**FOUNDER / COUNSEL DECISION REQUIRED.** OPTION A (delete) and OPTION B
(retain under a stated, disclosed policy) are drafted in §9 with schema,
product, privacy-policy, clinic, App Store and implementation
consequences. **Neither is written to `supabase/migrations`.** The
decision is now free of consequence for existing customers — nobody's
data is at stake either way — which is the best possible moment to make
it.

**11 · WHAT EXACTLY DOES `delete_user_account()` MISS TODAY?**
**The storage purge — it is in the repository and NOT in the deployed
function.** Plus, by design or omission: `care_weekly_summaries` (0
rows), `care_audit_events` (135), `patient_invitations.accepted_by` (10,
**not previously censused**), `invitation_attempts` (29), `ops_events`
(0), the two `set null` telemetry tables (a stated choice), and
**everything under a prior anonymous uid.**

**12 · DOES SIGN IN WITH APPLE TOKEN REVOCATION WORK TODAY?**
**NO.** No call to `/auth/revoke` exists — and, one step earlier, **no
credential exists that could reach it.**

**13 · WHAT APPLE CREDENTIAL IS MISSING, IF ANY?**
**`authorizationCode`** — the only one that can be exchanged for a
refresh token. Apple hands it to the delegate on every sign-in and Jeni
reads `identityToken`, `fullName` and `email` and drops it. **Zero call
sites in first-party code.** Supabase holds no provider token either:
`identity_data` carries `sub`/`email`/`iss`/`custom_claims` and nothing
else.

**14 · WHAT MUST CHANGE TO SUPPORT `/auth/revoke`?**
Four things, all founder-gated, all designed in §11 and none created: a
Sign in with Apple `.p8` key + Key ID + Team ID as Supabase secrets · one
Edge Function that mints the ES256 `client_secret` and calls `/auth/token`
then `/auth/revoke` · one table for the stored refresh tokens · one
client line to capture the authorization code. **Meanwhile Apple's own
documented fallback needs none of them, and it shipped.**

**15 · WHAT HAPPENS IF APPLE REVOCATION FAILS DURING ACCOUNT DELETE?**
**The deletion completes anyway.** Privacy deletion is never made
dependent on a third party's availability — an Apple outage must not
become a Jeni retention event, and Apple's own guidance assumes an app
may hold no usable token and still requires the deletion to finish. 200,
400, timeout, network failure and already-revoked all converge to the
same behaviour; Apple returns **200 for an already-invalidated token**,
so revocation is idempotent by contract.

**16 · DOES ACCOUNT DELETION REMOVE STORAGE OBJECTS?**
**Today the question is empty and the mechanism is broken.**
`storage.objects` has **0 rows** and the `food-photos` bucket **does not
exist**, so there is nothing to remove — and the **deployed RPC contains
no storage delete**, so the moment a photo lands it would survive. The
client's pre-RPC `BodyScanSyncService.deleteAllRemote` is currently the
only thing that removes an object. **Migration (b) in §16 restores the
purge; it must land before the bucket does.**

**17 · DOES ACCOUNT DELETION REMOVE EVERY LOCAL FACT?**
**YES when it completes, and now also when it is interrupted.** `37`
closed three families, `38` closed `move.manual.v1` and added the
deletion ledger, and this pass closed the case where the sweep **never
ran at all** because the process died between the server call and the
purge. Two per-identity behavioural ledgers remain unswept and are still
P2, neither customer-authored: `method.ledger.v1` and `brain.ledger.v1`,
plus her reminder hour.

**18 · DOES ACCOUNT DELETION REMOVE EVERY SERVER FACT?**
**NO — in three places, and one is new to this pass.** (a) Everything
recorded before an Apple sign-in, under an orphaned anonymous uid —
**prevented going forward, still present for existing accounts.** (b)
Five no-FK tables, of which `patient_invitations.accepted_by` was never
censused. (c) **Storage, if a photo ever reaches it**, because the
deployed function has no storage delete.

**19 · WHAT EXACTLY REQUIRES MY APPROVAL / DEPLOYMENT?**
① **Answer §9** — OPTION A or OPTION B for `care_weekly_summaries`.
② **Apply migration (b)** — the storage purge, before any bucket is
created. ③ **Fix the reaper's liveness predicate, then decide whether to
schedule it.** ④ **Create the Apple `.p8` + deploy the revocation Edge
Function** (P1). ⑤ **The `comment on table` decisions** for the four
no-FK tables. ⑥ **The archive-time bump to build 31.** ⑦ **One device
check after the first Apple sign-in on this build** — that customer's
`auth.users.created_at` should now be *older* than her
`auth.identities.created_at`.

**20 · SAFE FOR NEXT BUILD: YES.**
Every change is additive and device-local except the Apple link, which
falls back to today's exact call on any failure. No arithmetic moved, no
`@Model` changed, no schema, no deploy, no production SQL beyond
read-only SELECTs, `supabase/migrations` EMPTY.

---

# SCORECARD

Graded hard. Anything below 9 names the exact blocker.

| domain | `38` | now | the exact defect |
|---|---|---|---|
| **ANONYMOUS → ACCOUNT IDENTITY** | — | **8** | Fixed at the source for every future sign-in, and **unproven against live GoTrue** — it needs one real Apple sign-in to confirm. **Blocker: a device check the founder owns.** Existing orphans are unaffected by design. |
| **ACCOUNT DELETION** | 6 | **8** | The uid no longer splits, and the interrupted case now converges. **Blocker: the 559 pre-existing orphaned uids, which no credential and no query can associate back to a person.** |
| **SERVER DATA DELETION** | — | **7** | 24 tables cascade. **Blocker: five no-FK tables (one of them, `patient_invitations.accepted_by`, previously uncensused) and the `care_weekly_summaries` policy decision.** |
| **LOCAL DATA DELETION** | 10 | **10** | — the completed path was already whole, and the interrupted path now finishes at the next launch |
| **STORAGE DELETION** | — | **5** | **The deployed RPC has no storage delete.** Contained only because `storage.objects` is empty and `food-photos` does not exist. **Blocker: migration (b), before any bucket is created.** |
| **SIGN IN WITH APPLE REVOCATION** | — | **6** | Apple's documented fallback is now fully implemented — the sentence, the notification, the revert. **Blocker: Jeni holds no revocable token, and capturing one needs a `.p8`, an Edge Function and a table.** |
| **RETRY / IDEMPOTENCY** | — | **9** | An RPC that succeeds with a lost response still shows a failure on the first tap; it converges on the retry. Closing it needs a server-side idempotency key. |
| **PRIVACY CONTRACT** | 5 | **7** | *"No soft-delete; the data is unrecoverable"* is now true for every future account and still false for the pre-existing orphans. **Blocker: the same 559.** |

---

# THE FIVE ANSWERS

### BUILD NOW
1. **The Apple identity link.** Every day it waits is more permanent
   orphans, at roughly the current Apple sign-in rate.
2. **The deletion-intent marker and its launch finisher.**
3. **TN3194's revocation response.**
4. **The design-law pass and the AX5 scroll fix** — the second is an
   accessibility defect on a 5.1.1(v) surface.

*(All four are in this build.)*

### READY BUT DO NOT DEPLOY
1. **Migration (b): the storage purge in `delete_user_account()`** —
   forward and rollback SQL in §16, old- and new-client safe, standalone.
2. **The Apple revocation Edge Function** — architecture, ordering and
   every failure branch specified in §11; needs a key that does not
   exist.

### FOUNDER / LEGAL DECISION
1. **`care_weekly_summaries`: OPTION A or OPTION B** (§9). The only
   genuinely blocked item, and it is now free of consequence for existing
   customers.
2. **The four `comment on table` decisions** — turn four omissions into
   four decisions. Costs nothing, changes no behaviour.

### PRODUCTION REPAIR REQUIRED
1. **Fix the reaper's liveness predicate** (`last_sign_in_at` → newest
   row across her data), **then** decide whether to schedule it.
2. **Then, and only then, the orphan reap** — 3,424 anonymous accounts,
   2,182 with health data, 59 already past the window.

### DO NOT TOUCH YET
1. **The server tombstone** — `40`'s work, and still blocked on a
   filtering client reaching the installed base (`38` §6).
2. **A one-time reap under the current predicate** — it would delete
   living customers.
3. **Backfilling an anonymous → named uid link from row shapes.** Still
   the fabrication class.
4. **The `food-photos` bucket / photo sync.** A real defect, out of
   scope, and creating the bucket before migration (b) would open the
   storage hole for real.
5. **Syncing Jeni memory, chat, movement or body scans.** *We do not sync
   more customer data until deletion semantics are trustworthy.*

---

## THE QUESTION

> ▎ **If a customer taps "delete my account" today, can I truthfully tell
> ▎ her: "Your Jeni account and the data associated with it are gone"?**

# NO.

**For a customer who signs in on this build or later: YES, and that is
new.** Her identity no longer splits, so there is nothing left behind to
be honest about.

**For the customers who are already here, NO** — and the reason is one
sentence: *everything she recorded before she signed in with Apple lives
under a uid nobody can name.*

### The shortest exact path to YES

1. **Ship this build.** From here, no new orphan is created. Everything
   else on this list is finite and shrinking; this is the only item that
   was growing.
2. **Apply migration (b)** — the storage purge — **before the
   `food-photos` bucket is ever created.** One statement.
3. **Answer §9** and apply OPTION A or write OPTION B's comment and copy.
   Zero rows are at stake; it will never be cheaper.
4. **Fix the reaper's liveness predicate, then run it.** That is what
   makes the sentence true for the **existing** orphans — not by
   recovering them, which is impossible, but by deleting them. It is the
   only lawful disposition for customer health data under a credential
   nobody holds.
5. **Create the `.p8` and deploy the revocation function.** Until then
   Apple's documented fallback is what Jeni does, and as of this build it
   does all three steps of it.

**Steps 1–4 make it true of her data. Step 5 makes it true of her
identity. Only step 3 is blocked on something engineering cannot
answer — and it now blocks nothing but itself.**
