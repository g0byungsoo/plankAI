# THE LAST ORPHAN

**Status: `39`'s FIX ATTACKED AND HOLED · FOUR CLIENT-ONLY FIXES BUILT ·
PRODUCTION RE-CENSUSED READ-ONLY. 2026-08-14.**

`39` asked whether a deleted account disappears, found that Sign in with
Apple mints a new uid, and built the link that stops it. This pass has one
job:

> ▎ **AFTER THIS BUILD SHIPS, JENI MUST NEVER CREATE ANOTHER UNOWNED
> ▎ ANONYMOUS RECORD DURING A NORMAL ACCOUNT CONVERSION.**
>
> and, second:
>
> ▎ **ACCOUNT DELETION MUST DELETE EVERYTHING IT CAN ACTUALLY IDENTIFY,
> ▎ IDEMPOTENTLY, WITHOUT PRETENDING THE HISTORICAL ORPHANS CAN BE
> ▎ RE-ATTRIBUTED.**

`29`–`39` are frozen. No calorie formula, protein formula, merge
arithmetic, plan selection, restore path, safety rule, payment, paywall,
`AppPhase`, `Info.plist`, entitlement, analytics event or HealthKit type
moved. **No migration applied. No migration file written to
`supabase/migrations`. No Edge Function deployed. No production row
mutated. No reaper executed. No Apple credential or Developer Portal
change. `CURRENT_PROJECT_VERSION` is still 30.**

**This is not the tombstone pass.** Two-device record deletion was not
built, not designed further, and not blurred into this work.

---

## 0 · THE ANSWER FIRST

**`39`'s fix is correct and it is not enough — its fallback rebuilds the
orphan factory for a different population, and the merge it relies on
drops eleven of eighteen record families on the floor.**

| # | the finding | class |
|---|---|---|
| 1 | **THE FALLBACK IS THE ORPHAN FACTORY FOR EVERY RETURNING CUSTOMER.** GoTrue refuses `linkIdentityWithIdToken` with `identity_already_exists` when the Apple id already belongs to an account — a reinstall, a second phone, anyone coming back. `39`'s fallback then signs into that account and abandons the anonymous uid this device is holding, with everything she recorded before the tap still under it. Same P0, different population. **FIXED.** | **P0 — the orphan factory, moved** |
| 2 | **THE SIGN-IN MERGE RE-KEYS SEVEN OF EIGHTEEN `@Model` FAMILIES.** Doses, symptoms, her regimen, program facts, weekly reads, jeni memory, the transcript and her calibrations stay keyed to the abandoned uid — **on the phone in her hand**, invisible to every `@Query userId` in the product. `39` §3 recorded four of them as *"REKEYED"*. Production holds **164 regimen plans, 53 symptoms and 14 doses** under anonymous uids. **FIXED.** | **P0 — [CORR] on `39` §3** |
| 3 | **THE MERGE ALSO FIRES ON A NAMED → NAMED SWITCH**, carrying one customer's whole record into another customer's account on the same phone. Reachable from the re-auth sheet, the wall's recovery sheet and the paywall's. **FIXED.** | **P0 — cross-account leak** |
| 4 | **AFTER A SUCCESSFUL LINK THE APP DOES NOT KNOW SHE IS AN APPLE CUSTOMER.** GoTrue returns the user it loaded *before* the link, so `identities` is **empty** while `app_metadata.providers` already says `apple`. `authMethod` read identities only ⇒ `.unknown` for the whole session ⇒ Apple revocation handling stood down, the deletion sheet's Apple sentence did not render, and the profile re-upsert did not run — **for exactly the customers `39`'s fix was built for**. **FIXED.** | **P1 — the fix's own blind spot** |
| 5 | **[CORR] THE 30 OF 308 EMAIL TRANSITIONS ARE NOT CUSTOMERS.** All thirty are `@example.com`, all created within ONE SECOND of their user row, all on 2026-07-29/30, **all with zero profile rows and zero health rows** — they are `scripts/s5_pilot_proof.py`'s `POST /auth/v1/signup` test accounts. **Email conversion preserves the uid in 278 of 278 real conversions. 100%, not 90%.** | **[CORR] — `39` §3** |
| 6 | **[CORR] THE REAPER CANNOT REPAIR ANYTHING TODAY.** `39` made "fix the predicate, then run it" the repair for the existing orphans. With a *correct* predicate the project is **107 days old**, so a 120-day window matches **ZERO** accounts and a 90-day window matches **56** — 15 profile rows and 14 weigh-ins, out of 3,425 accounts and 3,046 health rows. | **[CORR] — `39`'s repair plan** |
| 7 | **`AccountDeletionIntent.clear()`'s doc comment claims `clearOnboardingUserDefaults` calls it. It did not** — the key appears in exactly one file. **The third false comment on a deletion path this line of work has found.** **FIXED.** | **P2 — a false contract** |
| 8 | **`patient_invitations.accepted_by` holds a raw patient uid with no FK, and all 10 accepted rows belong to ANONYMOUS accounts** — and all 10 also appear in `care_relationships.patient_id`, which cascades. So the identifier is redundant *and* retained. **Migration drafted, `SET NULL`.** | **P2 — sized and drafted** |

And the sentence that reframes what a repair can be:

> ▎ **THE ORPHANS CANNOT BE ATTRIBUTED, AND THEY CANNOT YET BE PROVEN
> ▎ ABANDONED EITHER — BECAUSE THE PRODUCT IS YOUNGER THAN ANY WINDOW
> ▎ THAT WOULD MAKE THE PROOF HONEST.**
>
> Prevention is not the best of several options. It is the only one that
> does anything this year.

---

## 1 · EVERY ACCOUNT TRANSITION JENI CAN PRODUCE, TRACED

Traced through the real code on both sides: `AuthService.completeAppleSignIn`
/ `signInWithEmail` / `signUpWithEmail`, `AppSync.onAuthChanged`, and
GoTrue's own `internal/api/token_oidc.go` · `identity.go` · `external.go`,
read this session rather than recalled. **No "should" anywhere below.**

Legend — **A** = the anonymous uid this device holds · **B** = whatever the
sign-in lands on · **RETIRE** = §3's new call, which deletes A's server rows
with A's own token at the instant of the switch.

| # | transition | OLD → NEW UID | UID CHANGES? | LOCAL DATA | SERVER DATA | MERGE RUNS? | DUPLICATE? | ORPHAN? | CROSS-ACCOUNT? | WHAT SHE SEES |
|---|---|---|---|---|---|---|---|---|---|---|
| **A** | anonymous → **new** Apple identity | A → **A** | **NO** | untouched, already hers | untouched, already hers | **no — nothing to merge** | no | **NO** | no | signed in; her record is exactly where it was |
| **B** | anonymous → Apple identity **owned by another Jeni account** | A → B | **YES** | re-keyed A→B, **all 18 families** (§2) | A's rows **RETIRED**; B's hydrate | **yes** | no | **NO** (was: yes) | no | signed in; her anonymous work joins the account |
| **C** | anonymous → Apple id used before **on this device** (reinstall) | A → B | **YES** | same as B; A is usually empty | same as B | yes | no | **NO** | no | her account comes back |
| **D** | anonymous → Apple id used before **on another device** | A → B | **YES** | same as B | same as B | yes | no | **NO** | no | same |
| **E** | link succeeds → **app killed immediately** | A → A | no | untouched | untouched | n/a | no | **NO** | no | relaunch: signed in, same record (§5) |
| **F** | link fails → fallback `signInWithIdToken` succeeds | A → B | **YES** | re-keyed | RETIRED + B hydrates | yes | no | **NO** | no | signed in |
| **G** | link succeeds → merge machinery still executes | A → A | no | **untouched — the guard refuses** | untouched | **NO** (`userIdChanged == false`) | no | **NO** | no | nothing |
| **H** | network dies during linking | A → A | no | untouched | untouched | no | no | **NO** | no | *"couldn't sign in"* — the fallback fails on the same network |
| **I** | Apple credential returned **twice** | A → A | no | untouched | untouched | no | no | **NO** | no | nothing — the second call is `identity_already_exists` on the SAME user, and the fallback lands back on A |
| **J** | **named** account → Sign in with Apple again (different Apple ID) | A → B | **YES** | **stays under A, preserved** | untouched | **NO — the new guard refuses** | no | no | **NO** (was: **YES**) | she is in the other account; the first account's data is not in it |
| **K** | anonymous → **email conversion** (`signUpWithEmail`) | A → **A** | **NO** | untouched | untouched | no | no | **NO** | no | unchanged — **278 of 278 in production** |
| **L** | existing **email** account → Apple, from an anonymous session | A → B | **YES** | re-keyed | RETIRED; GoTrue auto-links Apple to the email account | yes | no | **NO** | no | signed into her email account, now with Apple too |

**Case L, exactly, because it is the least obvious.** The link is attempted;
`linkIdentityToUser` creates the identity, then `targetUser.GetEmail() == ""`
sends it to `UpdateUserEmailFromIdentities`, which hits the unique index on
the email the existing account already owns ⇒ `ErrorCodeEmailExists` (400)
⇒ **plain error return, so the transaction ROLLS BACK and no identity is
created.** The fallback's `createAccountFromExternalIdentity` then finds no
apple identity but a user with that email in the same linking domain ⇒
decision `LinkAccount` ⇒ **GoTrue itself attaches the Apple identity to the
email account** and returns its session. The uid changes, so A is retired.

**Case J is the one that used to be a leak.** `onAuthChanged`'s merge branch
tested `userIdChanged && !isAnonNow` and nothing else, so a named → named
switch re-keyed account A's weigh-ins, plates, plans — and, once §2 lands,
her doses, symptoms, regimen and transcript — **into account B**. The
function's own doc comment has always said the merge is for *"the user's
anonymous-period work"*; `AppSync.shouldMergeAnonymousPeriod` now says it in
code.

---

## 2 · [CORR] THE MERGE WAS DROPPING ELEVEN OF EIGHTEEN FAMILIES

`39` §3 tabulated the transition and recorded **D (dose) REKEYED · S
(symptom) REKEYED · program plan / facts / weekly reads REKEYED**.

**Only `program plan` is.** `AppSync.reattributeModelRows` fetches exactly
seven types — `SessionLogRecord` · `SessionRatingRecord` ·
`DayProgressRecord` · `WeightLogRecord` · `ProgramPlanRecord` ·
`ProgramDayCheckRecord` · `BodyScanRecord` — plus the food JSONL. The
repository declares **eighteen** `@Model` types.

| family | was | now | id rule | why |
|---|---|---|---|---|
| `DoseEventRecord` | **dropped** | **REKEY** | prefix swap `"<uid>-dose-<day>"` | fresh-id invariant AND determinism at once |
| `ObservationRecord` | **dropped** | **REKEY** | prefix swap `"<uid>-symptom-<s>-<day>"` | same |
| `WeeklyReadRecord` | **dropped** | **REKEY** | prefix swap `"<uid>-read-<week>"` | a fresh uuid would give her a **second row for one week** |
| `RegimenPlanRecord` | **dropped** | **REKEY** | fresh uuid, `previousPlanId` follows | the v24 version chain must stay joined |
| `ProgramFactRecord` | **dropped** | **REKEY** | fresh uuid, `previousFactId` follows | the E1 authority chain |
| `ExerciseCalibrationRecord` | **dropped** | **REKEY** | `compositeKey` rebuilt | |
| `JeniMemoryRecord` | **dropped** | **REKEY in place** | id untouched | no server row exists, so no fresh id is needed |
| `ChatMessageRecord` | **dropped** | **REKEY in place** | id untouched | same |
| `UserRecord` (profile) | dropped | **B WINS; carried only to fill an ABSENCE** | id = uid | carrying a device profile over an account's would overwrite her height, weight, goal and cohort — the shape `29` spent a pass removing |
| `ConsentGrantRecord` | dropped | **REFUSED, and it is a decision** | — | a grant made as one identity must not become another's answer. *Unknown consent is never permission* (`38` §13) |
| `SessionRatingRecord`… (the seven) | REKEY | REKEY, unchanged | — | |

**THE DETERMINISTIC-ID RULE, because it is the load-bearing detail.**
`DoseEventStore.deterministicId` is `"<uid>-dose-<dayKey>"` and
`SideEffectLog.id` is `"<uid>-symptom-<symptom>-<dayKey>"`. Swapping the uid
prefix satisfies **both** invariants the merge has to hold at once: the id
is NEW, so the push is a clean INSERT the new account owns rather than an
UPDATE RLS rejects with 42501 (the reason weight and sessions get fresh
uuids); and it is exactly the id the new account **would mint** for that
slot, so her next mark of that dose day upserts onto this row instead of
creating a second. A random uuid satisfies the first and silently breaks the
second. **An id that does not carry the outgoing uid is left alone, never
guessed at.**

**COLLISIONS: THE ACCOUNT'S OWN ROW WINS.** If the destination already holds
that exact id — hydrated from another device — the incoming row is dropped.
Content is never compared and nothing is merged by similarity: *two weigh-ins
on the same day are not automatically duplicates, and two dose events must
never be merged because they look alike.* One id means one slot on one day
for one account; two rows cannot both be it, and the row already inside the
account is the one that stays.

**WHY IT WAS INVISIBLE FOR SIX PASSES.** Nothing throws, nothing logs, no
number moves. The rows are still on disk and still valid; they answer to a
name the app no longer uses. Every audit that read the **deletion** sweep saw
all eighteen families — it is exhaustive. Only the **merge** is short, and no
test ever compared the two lists. The new test does, by counting the
footprint rather than listing what it expects.

**AND `39`'s LINK FIX ALREADY REMOVES MOST OF THIS.** The dominant path — an
anonymous customer with a brand-new Apple identity — no longer changes the
uid, so there is nothing to re-key. What remains is every path where the uid
genuinely must change, which is §1 rows B, C, D, F and L.

---

## 3 · THE FALLBACK, AND WHY IT NEEDED MORE THAN A COMMENT

### 3.1 · Every link failure, classified

Read from `internal/api/identity.go` and `token_oidc.go`, not inferred:

```go
if identity != nil {
    if identity.UserID == targetUser.ID {
        return … ErrorCodeIdentityAlreadyExists, "Identity is already linked"
    }
    return … ErrorCodeIdentityAlreadyExists, "Identity is already linked to another user"
}
```

| failure | can it happen? | what the fallback does | verdict |
|---|---|---|---|
| **identity already linked to THIS user** | yes — a double-tapped button, a retried call | `signInWithIdToken` → `AccountExists` → **the same uid** | **SAFE TO FALL BACK** |
| **identity linked to ANOTHER user** | **yes — every returning customer** | signs into B and **abandons A** | **MUST NOT FALL BACK SILENTLY → RETIRE A FIRST** |
| **manual linking disabled** | **NO — does not apply.** `IdTokenGrant` + `linkIdentityToUser` never read `config.Security.ManualLinkingEnabled`; that check lives on the OAuth-redirect `/user/identities/authorize` endpoint, which Jeni does not use | n/a | **N/A — verified from source** |
| **invalid / expired token, nonce mismatch** | yes | the fallback posts the SAME token to the SAME checks and fails identically | **SAFE** — sign-in fails, no uid moves, no orphan |
| **network failure** | yes | the fallback fails on the same network | **SAFE** |
| **Supabase 5xx** | yes | the fallback may still succeed and land on a **different** uid | **RETIRE covers it** |
| **Apple failure** (no id token) | yes | never reaches Supabase | **SAFE** |
| **`email_exists` (400)** — the Apple email already belongs to an email account | yes (§1 case L) | GoTrue auto-links Apple to that account; uid changes | **RETIRE covers it** |
| **`email_not_confirmed` (422)** — Apple's id token carried no email claim | rare: GoTrue's Apple parser marks the email `Verified: true` unconditionally, so this needs an id token with **no email claim at all** | this one is a `CommitWithError` — **the identity IS linked to A** — so the fallback lands back on **A** | **SAFE** — and the only branch where the error is a lie about what happened |

> ▎ **LOGIN AVAILABILITY IS NOT MORE IMPORTANT THAN DATA OWNERSHIP — AND
> ▎ THIS PASS DID NOT HAVE TO CHOOSE.** The fallback still runs, always, so
> ▎ nobody is ever locked out. What changed is that the account it abandons
> ▎ is no longer left on the server.

### 3.2 · The error is not the signal. The outcome is.

The two `identity_already_exists` cases have **opposite** safety and share an
error code, differing only by an English sentence. A 5xx link followed by a
successful sign-in abandons the uid just as completely with no error to read.
So the decision is made on the one thing that cannot lie:

> ▎ **THE ANONYMOUS UID WAS ABANDONED IF, AFTER THE SIGN-IN, THE SESSION
> ▎ NAMES A DIFFERENT ACCOUNT.**

`AnonymousRetirementPolicy.decide(outgoingUid:outgoingWasAnonymous:outgoingAccessToken:incomingUid:)`,
pure, four outcomes, and the `outgoingWasAnonymous` gate is checked **first**
so the function is structurally incapable of nominating a named account.

### 3.3 · THE COLLISION MERGE, PER FAMILY

The inventory §3 of the brief asks for. **A** is the anonymous uid this
device holds; **B** is the permanent account she reached.

| owned by | A (anonymous, this device) | B (permanent) | rule | why |
|---|---|---|---|---|
| `public.users` profile | one row | one row | **B WINS** | the account's own body facts are authoritative |
| `program_plans` | re-keyed to B | hydrates | **KEEP BOTH → `reconcileLivePlans`** | shipped rule: earliest `startDate` stays live, the rest archive |
| food | re-keyed, fresh ids | hydrates | **KEEP BOTH** | a plate is not a duplicate because it looks like one |
| weight | re-keyed, fresh ids | hydrates | **KEEP BOTH** | **two weigh-ins on one day are not automatically duplicates** |
| dose | re-keyed, prefix | hydrates | **KEEP BOTH, unless the id collides ⇒ B WINS** | **two dose events are never merged because they look similar** |
| observations | re-keyed, prefix | hydrates | same | |
| regimen / facts / weekly reads | re-keyed, chains follow | hydrates | **KEEP BOTH** | |
| jeni memory · chat | re-keyed in place | none exists | **KEEP BOTH** | local-only families |
| consent | **REFUSED** | hydrates | **B WINS** | permission is not portable across identities |
| storage | none exists (§9) | none exists | n/a | |
| `UserDefaults` | device-scoped, follows the device | — | **KEEP** | not uid-keyed; `move.manual.v1` is swept at sign-**out** only (`38` §16) |
| deletion ledger `deletions.v1.<A>` | cleared at the merge | B's own | **DROP A's** | every id it protected was just re-keyed, so it can never match again |
| **A's SERVER rows** | — | — | **DELETE (RETIRE)** | they are a strict subset of the local rows that just moved to B, and no credential will ever name them again |

**Nothing is deduplicated by content anywhere.** A customer-owned record
survives unless identity is *provably* duplicate — which, here, means one id.

### 3.4 · Why retiring A destroys nothing

1. An anonymous uid is minted by **this install** and can never be signed
   back into by anyone, on any device, ever. No password, no email, no
   identity row.
2. Every server row under A was pushed **from this device**, so the local
   store is a superset of it.
3. The shipping merge re-keys those local rows to B with fresh ids and marks
   them `pendingUpsert`, so they are re-uploaded under the account she
   reached. **Her record MOVES; only the unreachable copy goes.**
4. `delete_user_account()` is `SECURITY DEFINER` scoped to `auth.uid()`, so
   the **token decides the victim**. A token for A can only ever delete A.

### 3.5 · The one thing it cannot do, stated rather than dressed up

**IT CANNOT BE RETRIED.** A retry needs a credential, and the only credential
is a bearer token we refuse to persist — writing an access token into
`UserDefaults` to make a cleanup retryable would be a worse defect than the
one it fixes. So this is **one best-effort attempt at the one moment it is
possible**. If it fails, the outcome is exactly today's: an orphan, and a
categorical analytics exception that records *that* one was created, never
*whose*.

---

## 4 · ONE UID AFTER CONVERSION

**THE POSTCONDITION.** After a successful anonymous → permanent conversion:

| | resolves to |
|---|---|
| `auth.uid()` | **B** |
| `public.users.user_id` | **B** — cascade-owned, hydrated or re-keyed |
| program owner · food owner · weight owner · dose owner · observation owner | **B** |
| storage prefix | **B** (`{uid}/…`; no objects exist today, §9) |
| local account identity (every `@Query userId`) | **B** |
| A's server rows | **deleted**, not orphaned |
| A's local rows | **zero** — asserted by counting the footprint, not by listing families |

`testAfterAConversionNoRecordStillAnswersToTheOldAccount` seeds one of every
family and asserts `footprint(A) == 0` **and** `footprint(B) == 10` — moving
is not the same as vanishing, and a test that only checks the first cannot
tell them apart.

**`sync.pendingMergeV1` LIFECYCLE, corrected.** It is written **at the
switch** now, inside `AuthService`, not when `AppSync.onAuthChanged`
eventually runs. `onAuthChanged` is driven by a SwiftUI `onChange`, so there
was a window between the session moving and the merge beginning in which a
process death left the local rows keyed to a uid the app would never use
again, **with nothing anywhere recording that a merge was owed**. It still
clears only after the merge AND its retry push. The receipt now means
MIGRATION IN PROGRESS, not WE TRIED ONCE.

---

## 5 · CRASH CONSISTENCY — KILLED AFTER EVERY LINE

| killed after | uid on relaunch | data | resumes? | duplicate? | orphan? | cross-account? |
|---|---|---|---|---|---|---|
| Apple credential obtained | A | untouched | n/a | no | no | no |
| **link requested, no answer** | A — and if GoTrue committed, A now **owns** the identity; `bootstrap`'s `auth.user()` reads it back and `authMethod` becomes `.apple` | untouched | **yes, by converging on the same uid** | no | no | no |
| **link succeeded, session installed** | A (linked) | untouched | nothing to resume | no | no | no |
| **fallback sign-in succeeded (B)** | B | local rows still keyed to A | **YES — the merge receipt was written at the switch; `onLaunch` → `resumePendingMergeIfNeeded` finishes it** | no | orphan A remains (today's behaviour) | no |
| **A retired, before the local merge** | B | local rows keyed to A | **YES — same receipt** | no | **no** | no |
| **local rows re-keyed, push not sent** | B | rows carry `pendingUpsert` | yes — `retryPendingUpserts` at the next launch | no | no | no |
| **profile merged / plan merged** | B | — | idempotent (`reconcileLivePlans` is a pure re-run) | no | no | no |
| **`pendingMergeV1` cleared** | B | complete | done | no | no | no |

**The merge is idempotent by construction**: `reattributeLocalRows` only ever
fetches rows still keyed to the OLD uid, so a completed pass is a no-op and a
half-finished one picks up the remainder. `IdentityMerge` runs inside the
same function, on the same context, **before its single `save()`** — so a
merge is one transaction and a crash cannot half-apply it.

**Account deletion's own crash consistency is `39`'s and is unchanged**,
except that `AccountDeletionIntent` is now cleared by
`clearOnboardingUserDefaults` — **last, deliberately**. Discharged before the
sweep finishes, a death mid-sweep would leave the remaining keys behind with
nothing recording that they are owed.

---

## 6 · SUPABASE CONFIGURATION — THREE COLUMNS, ANSWERED SEPARATELY

| | answer | how it was established |
|---|---|---|
| **LOCAL SDK SUPPORT** | **YES** | `supabase-swift 2.44.0` (pinned, `Package.resolved` revision `e0b1663`), `AuthClient.linkIdentityWithIdToken` at `Sources/Auth/AuthClient.swift:1221`: sets `credentials.linkIdentity = true`, posts to `/token?grant_type=id_token` with `Authorization: Bearer <session>`, emits `.userUpdated` |
| **PRODUCTION AUTH CONFIG** | **NOT REQUIRED — the setting does not gate this path** | GoTrue's `IdTokenGrant` requires only an `Authorization` header and a resolvable user; `linkIdentityToUser` contains **no reference to `ManualLinkingEnabled`**, and neither does `external.go`. `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED` gates the OAuth-redirect `/user/identities/authorize` flow, which Jeni does not call |
| **CLIENT IMPLEMENTATION** | **YES, shipped in `39` and unchanged here** | `AuthService.completeAppleSignIn`, gated on `AppleIdentityPolicy.strategy` |

**A YES in one column is not a YES in the others, and one column is still
UNKNOWN.** The project's live auth configuration was **not read**: it needs
the Management API `GET /v1/projects/{ref}/config/auth` and a personal access
token, and the CLI exposes only `config push` (a mutation). **Read-only was
the constraint, so the honest answer for the raw config value is UNKNOWN** —
and the finding above makes it moot for this path, from the source rather
than from a successful local run.

> **DO NOT INFER FROM LOCAL SUCCESS.** Nothing in this build proves
> `linkIdentityWithIdToken` succeeds against **this project's** GoTrue. It
> needs a real Apple credential and a live sign-in. That remains the
> founder's one-line check (§24), exactly as `39` left it.

---

## 7 · [CORR] THE 30 OF 308 EMAIL TRANSITIONS ARE TEST ACCOUNTS

`39` §3 reported *"the email path preserves the uid in 278 of 308 cases"* and
left the other 30 unexplained. Classified from production, counts only:

| measure | email | apple |
|---|---|---|
| identities | 308 | 559 |
| gap `identity.created_at − user.created_at` **< 1 s** | **30** | **559** |
| gap 1 s – 10 s | 0 | 0 |
| gap 10 s – 1 h | 263 | 0 |
| gap > 1 h | 15 | 0 |
| max gap | **1,199,195 s (13.9 days)** | **< 1 s** |
| **date range of the sub-second set** | **2026-07-29 → 2026-07-30** | 2026-04-30 → 2026-08-13 |
| **date range of the attached-later set** | 2026-04-30 → 2026-07-23 | — |

And the classification, proven rather than selected:

| the 30 | count |
|---|---|
| with a `public.users` profile row | **0** |
| with any health row | **0** |
| still `is_anonymous` | **0** |
| **whose address ends `@example.com`** | **30 of 30** |

`scripts/s5_pilot_proof.py:64` — `email = f"s5proof-{tag}-{secrets.token_hex(4)}@example.com"`
then `POST /auth/v1/signup`, which creates a user and its email identity in
the **same request**. The file is dated 2026-07-29. `scripts/care_demo.py`
uses `POST /auth/v1/admin/users`, likewise same-instant. There are **31**
`@example.com` users in the project in total.

> ▎ **EMAIL CONVERSION PRESERVES THE UID IN 278 OF 278 REAL CONVERSIONS.**
> The two populations are also **disjoint in time** — the last real email
> upgrade is 2026-07-23, the test accounts are 2026-07-29/30 — which is a
> second, independent confirmation.

**DOES THE APPLE FIX ALTER EMAIL CONVERSION? NO.** `signUpWithEmail` —
`supabase.auth.update(user:)` — is **byte-identical to `1710180`**. The
`upgraded` branch in `onAuthChanged` (`previousMethod == .anonymous && !userIdChanged`)
is unchanged. `shouldMergeAnonymousPeriod` cannot fire on it, because
`userIdChanged` is false.

**What DID change on the email side, deliberately and stated:**
`signInWithEmail` — the **returning-customer** door, not the conversion —
now runs the same retirement. It abandons an anonymous uid in exactly the
way the Apple fallback does, and leaving one door open would be choosing
which customers get an orphan.

---

## 8 · THE DEPLOYED DELETION CONTRACT — PRODUCTION IS THE TRUTH

Read from `pg_proc` and the live catalog on 2026-08-14. **Where production
and the repository differ, production is recorded.**

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

**`scripts/delete_user_account.sql` contains a `DELETE FROM storage.objects`
block. The deployed function still does not.** Re-verified independently of
`39`.

| RESOURCE | REPO DELETE? | DEPLOYED DELETE? | FK CASCADE? | RLS | RETAINED? | WHY |
|---|---|---|---|---|---|---|
| `auth.users` | yes | **yes** | — | SECURITY DEFINER | no | the one statement that exists |
| `public.users` | — | via cascade | **cascade** | own-row | no | |
| `weight_logs` · `food_logs` · `food_log_items` · `food_corrections` | — | via cascade | **cascade** | own-row | no | |
| `dose_events` · `observations` | — | via cascade | **cascade** | own-row | no | |
| `program_plans` · `program_day_checks` · `program_facts` · `weekly_reads` | — | via cascade | **cascade** | own-row | no | |
| `regimen_plans` · `session_logs` · `session_ratings` · `day_progress` · `day_reflections` · `exercise_calibrations` | — | via cascade | **cascade** | own-row | no | |
| `consent_grants` · `coach_messages` · `visit_packets` · `org_members` · `care_relationships` · `correction_requests` · `protocol_assignments` | — | via cascade | **cascade** | scoped | no | 24 tables cascade in total |
| `food_vision_telemetry` (1,113 rows) | — | — | **set null** | — | **row survives, de-identified** | a stated choice |
| `jeni_chat_telemetry` (230 rows) | — | — | **set null** | — | same | a stated choice |
| **`care_weekly_summaries`** (0 rows) | — | **NO** | **NO FK** | insert/update/select only, **no delete policy** | **yes** | §12 — undecided, and free to decide |
| **`care_audit_events.patient_id`** (135) · `.actor_id` (206) | — | **NO** | **NO FK** | scoped | **yes** | §11 — defensible, undecided |
| **`patient_invitations.accepted_by`** (10) | — | **NO** | **NO FK** | scoped | **yes** | §11 — **`SET NULL` drafted** |
| **`private.invitation_attempts.user_id`** (29) | — | **NO** | **NO FK** | private schema | **yes** | §11 — rate limiting |
| **`public.ops_events.actor_id`** (0) | — | **NO** | **NO FK** | — | **yes** | §11 — operational |
| **`storage.objects`** | **yes** | **NO** | **NO FK — `owner` and `owner_id` both read NO_FK in the live catalog** | own-prefix | **would be, if any existed** | §9 — the repo header's *"owner is SET NULL on user deletion"* is **wrong about this project** |
| everything under a **prior anonymous uid** | — | **NO — unreachable** | — | — | **yes** | §14 |

Orphan counts across every no-FK column: **zero**. Nothing is marked
"probably".

---

## 9 · STORAGE — FIX THE MECHANISM, NOT THE EMPTY TABLE

| bucket | exists? | can the CURRENT client write? | path format | owner | delete-account behaviour |
|---|---|---|---|---|---|
| **`food-photos`** | **NO** | **it tries** — `FoodPhotoSyncService` (bucket `"food-photos"`) with a persistent retry queue, so **every upload fails and self-queues, silently** | `{uid}/{entryId}.jpg` | uploader | **nothing would remove it** |
| **`body-scans`** | **yes** (private, created 2026-08-04) | yes, opt-in backup only | `{uid}/{dayKey}/…` | uploader | client's pre-RPC `BodyScanSyncService.deleteAllRemote` — **the only thing in the product that removes an object** |
| any other | — | none. Repo-wide, `supabase.storage.from(...)` appears in exactly two services | — | — | — |

```
storage.buckets  →  body-scans   (private, 2026-08-04)   objects: 0
storage.objects  →  0 rows, all buckets
```

> ▎ **ZERO CURRENT CUSTOMER IMPACT.** No customer photo has ever reached
> Supabase Storage.
>
> ▎ **AND THE MECHANISM IS STILL BROKEN.** `storage.objects` has exactly one
> foreign key — to `storage.buckets`. There is **no** `owner → auth.users`
> reference, so nothing happens to those rows when a user is deleted. The
> day the `food-photos` bucket exists, every meal photo of every deleted
> account survives, unreachable by any credential and removable by no
> client.

**The bucket was NOT created to satisfy this audit.** Migration **A1**
restores the purge and must land **before** the bucket does. The anonymous
retirement reaches the same RPC, so an abandoned anonymous account's storage
goes with it once A1 is applied.

---

## 10 · THE DELETE CONTRACT, AS PHASES

The brief asks for the minimum architecture Jeni actually needs, and
explicitly warns against adding a state machine to an operation that is
already idempotent without one.

**It does not need one.** `39` already built the only durable state the
operation requires — a two-stage intent — and everything else converges
because every step is predicate-driven.

| # | phase | safe to retry? | safe if already absent? | if the previous step succeeded | if the next step fails |
|---|---|---|---|---|---|
| 1 | authenticate | yes | n/a | — | nothing happened |
| 2 | **mark intent `.requested`** | yes (overwrite) | yes | — | nothing is purged on the strength of it |
| 3 | purge opt-in body-scan objects (client, pre-RPC, awaited) | yes — delete by prefix | **yes** | — | **best-effort; never blocks** |
| 4 | **RPC** — storage objects, then `auth.users` | **yes — `DELETE … WHERE id = auth.uid()` finds nothing on a second call** | **yes** | — | verdict `.retryable`; **nothing local is destroyed** |
| 5 | **mark intent `.serverComplete`** | yes | yes | the purge is now OWED | the next launch finishes it |
| 6 | local SwiftData purge | yes | yes | — | intent stands; next launch |
| 7 | UserDefaults sweep, notifications, payment residue, analytics identity | yes | yes | — | intent stands |
| 8 | **discharge the intent — LAST** | yes | yes | complete | — |
| 9 | sign out + re-bootstrap | yes | yes | — | **does not rethrow**; self-heals |

> ▎ **DELETE BEATS UPDATE. ABSENT IS SUCCESS.** A definitive rejection
> (`user_not_found`, session gone, 401/403) is the server saying the account
> is *already gone*, and `AccountDeletionVerdict.classify` reads it as
> `.serverComplete`, not as a failure. A timeout says nothing about the
> server and stays `.retryable`, because purging locally while the server
> keeps its copy is strictly worse than not starting.

**Apple revocation is NOT a phase of this.** It sits **before** step 4 when
it exists at all, and it never blocks (§18).

---

## 11 · THE FIVE NO-FK TABLES

| # | table.column | rows | class | verdict |
|---|---|---|---|---|
| 1 | `public.care_weekly_summaries.user_id` | **0** | **CLINICAL** | **UNKNOWN — FOUNDER / LEGAL** (§12) |
| 2 | `public.care_audit_events.patient_id` (135) · `.actor_id` (206) | 341 | **AUDIT** | **RETAIN** — an audit record the audited party can erase is not an audit record. **Comment drafted (A3)** |
| 3 | `public.patient_invitations.accepted_by` | **10** | **INVITATION** | **ANONYMIZE — `on delete set null`. Migration drafted (A2)** |
| 4 | `private.invitation_attempts.user_id` | 29 | **OPERATIONAL** | **RETAIN** — rate limiting, no health content; a limit an attacker clears by deleting an account is not a limit. **Comment drafted (A3)** |
| 5 | `public.ops_events.actor_id` | **0** | **OPERATIONAL** | **RETAIN.** **Comment drafted (A3)** |

*(Also no-FK but clinician-side, not customer-owned:
`correction_requests.resolved_by` · `protocol_assignments.assigned_by` ·
`patient_invitations.created_by` (17) · `private.org_provisioning_codes.used_by`
— the last was not in `39`'s census either.)*

**"No FK" is not a synonym for "bug".** Four of the five are defensible
retentions; what is not defensible is that they are **omissions rather than
decisions**, and one `comment on table` each fixes that at zero cost and zero
behaviour change.

### `patient_invitations.accepted_by`, in full, because it is the one that changed

| measure | value |
|---|---|
| rows | 17 |
| accepted (`accepted_by` not null) | **10** |
| orphaned | **0** |
| **also present in `care_relationships.patient_id`** (which cascades) | **10 of 10** |
| **belonging to an anonymous account** | **10 of 10** |

The row is the **clinic's**: they created it (`created_by`, `org_id`), it
records that an invitation was issued and accepted, and `care_relationships`
already carries the relationship and already cascades. So the patient
identifier is **redundant AND retained**.

| option | consequence |
|---|---|
| **SET NULL** ✅ | the clinic keeps its record of issuing and acceptance; the patient identifier goes with her account. Matches the schema's own `set null` telemetry precedent |
| CASCADE | **deletes another party's record**, including the fact they ever issued an invitation. A customer's deletion right covers her data, not the clinic's ledger. **REFUSED** |
| pseudonymize | a hash column, a backfill and a rewrite of every reader, to preserve a join nothing makes. **REFUSED as disproportionate** |
| retain | what happens today, by omission. Needs the §12 OPTION B treatment — a comment, a policy sentence and the consent copy — before it can be called a policy |

---

## 12 · `care_weekly_summaries` — PAST: NONE. FUTURE: UNRESOLVED.

| figure | value |
|---|---|
| total rows | **0** |
| orphan rows | **0** |
| `care_relationships` | 10 |
| `consent_grants` | 31 |
| `visit_packets` | 4 |
| `org_members` | 30 |

> **PAST DATA PROBLEM: NONE.** `37` §16 and `38` §10 both scored this a live
> P0 privacy leak. `39` §9 corrected it; this pass confirms the zero a
> second time. **It is no longer described as a current data leak anywhere.**
>
> **FUTURE CONTRACT: UNRESOLVED.** The writer runs on every launch for every
> connected org holding `visit_packet_view`, and ten care relationships
> exist. The first summary can be written on any day.

Both migrations are drafted in `docs/app_v25/40_packages/D_care_weekly_summaries.sql`
— **OPTION A** (`on delete cascade`, validates in one statement, no repair
step) and **OPTION B** (retain under a stated obligation: a table comment
**plus** a privacy-policy sentence **plus** the clinic consent copy, because
a retention obligation the customer was not told about is a surprise, not an
obligation). **Neither is written to `supabase/migrations`. Neither is
applied.**

**With zero rows, nobody's data is at stake either way. It will never be
cheaper to decide.**

---

## 13 · THE REAPER PREDICATE

### Why the existing one is unsafe, with the number

`scripts/cleanup_orphaned_anon_users.sql` matches
`is_anonymous AND coalesce(last_sign_in_at, created_at) < now() - 90d`.
**`last_sign_in_at` is written once, at `signInAnonymously`, and never moves
again** — the SDK refreshes the *token*, which does not touch it.

| measured 2026-08-14 | value |
|---|---|
| anonymous accounts | **3,425** |
| **whose real activity is NEWER than `last_sign_in_at`** | **2,344 (68%)** |
| matching the old 90-day predicate | **59** |
| …of those, **active within 90 days by a real signal** | **3** |
| …of those, active within 30 days | 0 |

> ▎ **THE OLD SCRIPT WOULD DELETE THREE LIVING CUSTOMERS' RECORDS TODAY.**
> Do not run it.

### The strongest activity signal Jeni actually possesses

The newest of **every** trace this project can produce for one uid:

- **auth** — `users.created_at` · `last_sign_in_at` · `sessions.refreshed_at`
  / `updated_at` / `created_at` · `refresh_tokens.created_at` / `updated_at`
- **customer** — `weight_logs` · `food_logs` · `dose_events` ·
  `observations` · `day_progress` · `program_plans` · `program_day_checks` ·
  `session_logs` · `day_reflections` · `program_facts` · `weekly_reads` ·
  `regimen_plans` · `consent_grants` · `exercise_calibrations`
- **product** — `food_vision_telemetry` · `jeni_chat_telemetry`

A row missing from that list can only make an account look **staler** than it
is, so every omission biases toward **retention**. That is the correct
direction: *prefer false retention over false deletion.*

> **AN ANONYMOUS ACCOUNT IS ELIGIBLE ONLY IF** it is anonymous, it was
> created more than N days ago, **and nothing anywhere in this project has
> recorded a single act by it for N days**.

### A guard that was tested and REJECTED

"Exclude accounts that still hold a live refresh token" sounds like the
protection for a device that is still installed. **It separates nothing:**
GoTrue never revokes an abandoned anonymous refresh token and these sessions
carry no expiry, so **all 56** of the 90-day-silent accounts still hold a
live, unrevoked token and a live session — as do **3,418 of the 3,425**.
Measured, not assumed, and not used.

### What the predicate protects

| must survive | does it? | how |
|---|---|---|
| an active anonymous customer | **yes** | any token refresh or row write moves `last_activity` |
| an offline customer | **yes** at 180 d — a device offline for six unbroken months while the app is in use is not a credible reading of total silence |
| a recent customer with no health row | **yes** | auth signals count, not just data rows |
| a conversion in progress | **yes** | the conversion itself refreshes tokens |
| a failed conversion | **yes** | same |
| a pending merge | **yes** | the device is live by definition |
| **a customer who returns after a long gap** | **this is the reason the window is long.** Reaping a dormant-but-still-installed anonymous account is destructive in a way reaping a superseded one is not: her local rows are still on her phone, and deleting her `auth.users` row makes the next launch mint a fresh uid that cannot see them |

---

## 14 · ATTRIBUTION vs ABANDONMENT — AND THE FOUR POPULATIONS

**These are different claims and this pass keeps them apart.**

> **ATTRIBUTION** — *"this anonymous uid became that named account."*
> **IMPOSSIBLE.** Nothing records it: zero accounts have more than one
> identity, there is no lineage table, no `previous_uid` column anywhere in
> Swift, SQL or TypeScript, and `sync.pendingMergeV1` is a device-local
> `UserDefaults` dictionary deleted the moment the merge completes.
>
> **ABANDONMENT** — *"nothing anywhere has recorded an act by this account
> for N days."* **PROVABLE, and it is all the reaper needs.**

"An Apple sign-in happened at a similar time" is **not identity evidence**
and was not used, joined, or inferred — not on timestamps, devices, body
metrics, food, goals or email. It is at most a bound on abandonment, and it
was not used as one either.

### The 3,425, classified by what the data ACTUALLY supports

| # | population | how it is identified | count | with health | with profile | completely empty |
|---|---|---|---|---|---|---|
| **1** | **ACTIVE ANONYMOUS** — last act ≤ 7 days | activity signal | **80** | 49 | 44 | 31 |
| **1b** | **RECENTLY ACTIVE** — 8–30 days | activity signal | **437** | 276 | 265 | 161 |
| **1c** | **QUIET** — 31–90 days | activity signal | **2,852** | 1,844 | 1,838 | 1,008 |
| **3** | **SILENT** — 91–180 days | activity signal | **56** | 14 | 15 | 41 |
| — | over 180 days | — | **0** | 0 | 0 | 0 |

**Population 2 — SUCCESSFULLY CONVERTED, SAME UID — is not in this table by
construction:** those accounts are `is_anonymous = false` and are not
anonymous rows at all. Today there are none created by Apple (all 559 split);
**278 exist via email.** From this build forward, every Apple conversion
joins it.

**Population 4 — EXISTING PERMANENT ACCOUNT COLLISION — has no historical
count and cannot have one.** It is a *transition*, not a row shape. From this
build forward it is the case §3 retires.

> ▎ **A SUPERSEDED UID AND A DORMANT-BUT-INSTALLED UID ARE INDISTINGUISHABLE
> ▎ FROM THE SERVER.** That is the attribution problem restated, and it is
> ▎ exactly why the window has to be long. **They are not all "orphans", and
> ▎ this document does not call them that.**

### Can any historical orphan ever be safely reaped? YES — LATER, AND NOT MANY

| window | accounts reaped | why |
|---|---|---|
| 90 days | **56** (15 profile rows · 14 weigh-ins · **0** food · **0** symptoms · **0** doses · 0 plans · 0 storage objects) | and it risks a dormant customer who returns |
| **120 days** | **0** | |
| **180 days** | **0** | |
| 365 days | **0** | |

**The project's oldest `auth.users` row is 107 days old.** Every window at or
above 120 days is empty **by construction**.

> ▎ **[CORR] `39`'s "fix the predicate, then run it — that is what makes the
> ▎ sentence true for the EXISTING orphans" IS WRONG ON THE NUMBERS.** At a
> ▎ defensible window a safe reaper removes **nothing** today, and at an
> ▎ aggressive one it removes 56 of 3,425. **The reaper is maintenance that
> ▎ becomes useful with time. It is not the repair.**
>
> The repair is prevention, and prevention is the only lever that moves this
> year.

---

## 15 · THE REAPER, WRITTEN AND NOT RUN

`scripts/reap_abandoned_anon_accounts.sql` — **supersedes**
`scripts/cleanup_orphaned_anon_users.sql`, which must not be run.

| requirement | how |
|---|---|
| **DRY RUN DEFAULT** | Steps 1 and 2 are `select`. Step 3 is **commented out** |
| **COUNTS FIRST** | Step 1 counts at 90/120/180/270/365 days in one pass |
| **NO PAYLOAD OUTPUT** | no jsonb, no health value, no object name anywhere |
| **NO IDENTITIES PRINTED** | no uid, no email, no name; `RAISE NOTICE` emits counts only |
| **TRANSACTIONAL** | one `do $$` block — a partial reap is the one outcome worse than none |
| **IDEMPOTENT** | every delete is predicate-driven; a second run matches nothing new |
| **EXPLICIT CUTOFF** | one `retention_days` constant, defaulted to **180**, named in both steps with a warning to keep them in sync |
| **EXPLICIT EXCLUSIONS** | `is_anonymous = true` re-asserted **on the delete itself** as belt and braces, so a named account can never be matched |
| **STORAGE INCLUDED** | **first**, before auth — there is no FK, so deleting auth first strands every object permanently |
| **CHILD TABLES ACCOUNTED FOR** | 24 cascade; the **five no-FK tables are counted individually** in step 2 and handled explicitly in step 3 (`patient_invitations.accepted_by` → `SET NULL`; the other three deliberately untouched pending §11's decision, and the script says so rather than choosing silently) |
| **AUTH USER LAST** | step 3d |

Step 2 reports exactly how many **accounts · health rows · profile rows ·
plans · storage objects** would go, at the chosen window.

**NO PRODUCTION MUTATION IN THIS SESSION.**

---

## 16 · APPLE REVOCATION — THE REAL PATH FOR NEW ACCOUNTS

`39` shipped TN3194's documented fallback for the legacy position (delete the
data · tell her to revoke manually · honour the revocation notice). **It is
kept, unchanged, and it is still the right thing for all 559 existing Apple
customers**, because Jeni holds none of the three credentials Apple accepts.

For **new** Apple sign-ins, the complete path is designed:

```
client  1  capture credential.authorizationCode beside the identityToken
        2  POST it to the `apple-identity` function over her own Supabase JWT
server  3  build client_secret: ES256 JWT signed with the team .p8
             iss=TEAM_ID  aud=https://appleid.apple.com  sub=BUNDLE_ID
             kid=KEY_ID   iat=now  exp=now+600s
        4  POST /auth/token  grant_type=authorization_code  → refresh_token
        5  store {uid → refresh_token} in private.apple_provider_tokens
             RLS on, NO policies, NO grants — service role only
later   6  account deletion:
             a  revoke BEFORE the DB delete, while a credential still exists
             b  POST /auth/revoke  token_type_hint=refresh_token
             c  on success, DELETE the stored row
             d  CONTINUE THE DELETION REGARDLESS OF (b)
```

**The private key never goes in the app.** It is a Supabase secret read only
by the function.

**Not stored, deliberately:** the identity token (a short-lived assertion
carrying her email, needed by nothing in this flow) and the access token (the
refresh token is what Apple accepts for the life of the grant).

Files: `docs/app_v25/40_packages/B1_apple_provider_tokens.sql` ·
`docs/app_v25/40_packages/B2_apple-identity/index.ts`. **Neither is in
`supabase/migrations` or `supabase/functions`. Neither is deployed.**

**`credential.authorizationCode` is STILL not captured in the client**, for
the reason `39` gave and this pass agrees with: it is worthless without step
3, and capturing a credential the app cannot use is dead code that looks like
compliance.

---

## 17 · THE `.p8` — THE EXACT FOUNDER ACTION

**No credential was created, rotated, printed or requested. Do not paste the
`.p8` into a chat, an issue, or this repository.**

| what | where it comes from |
|---|---|
| **key capability** | Apple Developer › Certificates, Identifiers & Profiles › **Keys** › **＋** › enable **Sign in with Apple**, then **Configure** and choose the **primary App ID** (`com.bk.plankAI`) |
| **the `.p8` file** | downloaded **once**, at creation. Apple never offers it again. If it is lost, the key is revoked and a new one is made |
| **Key ID** | shown on the key's page after creation, 10 characters |
| **Team ID** | Apple Developer › **Membership**, 10 characters |
| **`client_id` Jeni should use** | the **Bundle ID**, `com.bk.plankAI` — a native app authenticates as its App ID, not as a Services ID (a Services ID is for the web flow, which Jeni does not use) |
| **server config entries** | `supabase secrets set APPLE_TEAM_ID=… APPLE_KEY_ID=… APPLE_CLIENT_ID=com.bk.plankAI` and `APPLE_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"` — newlines preserved |

**The private key belongs in Supabase secret storage. Never the repository.
Never the app bundle. Never `UserDefaults`. Never a log.** The function reads
it from `Deno.env` and neither logs it nor returns it on any branch.

---

## 18 · THE REVOCATION FUNCTION — PREPARED, NOT DEPLOYED

`apple-identity`, two actions, ~180 lines. It:

- **authenticates the Jeni user** from the caller's JWT and takes the uid
  from that alone — there is no path that accepts a `user_id` from the body;
- loads the stored refresh token with the **service role**;
- **generates `client_secret` server-side** (ES256 over P-256 via
  `crypto.subtle`, ten-minute expiry so a leaked secret is worthless almost
  immediately);
- POSTs Apple's `/auth/revoke`;
- treats Apple's documented semantics correctly: **200 with no body on
  success *and* when the token was already invalidated**, so revocation is
  idempotent by Apple's own contract and there is no "already revoked"
  branch to write; a `400 invalid_grant` is the same end state;
- **erases** the stored token after a successful revocation, rather than
  marking it — a revoked token has no further use and keeping it is keeping
  a credential for no reason;
- **never returns the token and never logs it**, on any branch.

### The ordering invariant

> ▎ **FAILURE TO REACH APPLE MUST NEVER BECOME FAILURE TO DELETE CUSTOMER
> ▎ DATA.**

| Apple's answer | what Jeni does |
|---|---|
| 200 | token row deleted; deletion continues; nothing shown to her |
| 200 (already invalidated) | identical — Apple documents the same response |
| 400 `invalid_grant` | treat as done; deletion continues |
| timeout / 5xx / DNS | **deletion continues**; nothing surfaced to her |
| no stored token (all 559 today) | **success** — TN3194's fallback is what the app does, and it is not an error state |

**The function returns `200 { ok: true, revoked: <bool> }` on every one of
those**, deliberately, so the client has nothing to branch on. This is proven
by construction rather than by a test that fakes an Apple outage: revocation
is **not in the deletion path at all** — `deleteCurrentAccount` neither calls
it nor awaits it, so there is no code path on which an Apple failure can
reach the deletion. `39`'s `AccountDeletionContractTests` pins that, and it
stays true.

---

## 19 · APPLE SERVER-TO-SERVER EVENTS — NOT BUILT, AND WHY

**WHAT FAILURE WOULD IT CLOSE?** Three candidate events:

| event | closed by the native path today? | verdict |
|---|---|---|
| `consent-revoked` | **YES** — `39` shipped `AppleCredentialWatcher` on `credentialRevokedNotification`, confirmed by `getCredentialState` where the identifier is known. The device is the party that must revert to unauthenticated, and it is the party that gets told | **DO NOT BUILD** — a second delivery of the same fact |
| `email-disabled` / `email-enabled` | Jeni never emails a customer at her Apple relay address | **DO NOT BUILD** — no failure to close |
| **`account-delete`** — the customer deleted her **Apple ID** | **NO.** Nothing tells Jeni, and TN3194 treats it as a request to delete her account data. If she never opens the app again, her Jeni record stands forever | **the ONE material gap. NAMED, SIZED, NOT BUILT** |

**Recommendation: not now, and revisit with Package B.** Today the endpoint
would have nothing to act on beyond deleting rows for a customer who has not
asked Jeni for anything — a deletion triggered by a third-party webhook, with
no in-app confirmation, is its own risk. **Once server-side refresh tokens
exist (Package B), the calculus changes**: the endpoint's job becomes "revoke
and erase the stored credential", which is unambiguous and cheap. It needs an
Edge Function plus an Apple Developer Portal change; neither was made.

---

## 20 · ACCOUNT-DELETION COPY — AUDIT ONLY

Three distinct operations, and the screen must not blur them:

| operation | what the shipping copy says | verdict |
|---|---|---|
| **DELETE JENI ACCOUNT** | *"this permanently deletes your routine history, progress, and account."* | **TRUE. UNTOUCHED.** |
| **CANCEL APP STORE SUBSCRIPTION** | *"if you have an active subscription, cancel it from your iOS settings first. **deletion does not cancel App Store subscriptions.**"* | **TRUE, and it states the negative explicitly.** Apple requires the app to notify the customer that billing continues and to request cancellation; this does both, in the sentence before the button. **UNTOUCHED.** |
| **REVOKE SIGN IN WITH APPLE** | *"you signed in with apple. deleting here removes your data, but only you can take back the apple sign-in itself: settings › your name › sign-in and security › sign in with apple."* | **TRUE, and it never implies Jeni did the revoking.** **UNTOUCHED.** |

**Nothing implies deleting Jeni cancels the subscription, so nothing was
rewritten.** One thing did change about who sees it: the Apple sentence is
gated on `authMethod == .apple`, and a customer who had just LINKED read
`.unknown`, so **she was not shown the one step Jeni genuinely cannot do for
her**. §0 finding 4 fixes that. **No redesign. Zero characters changed.**

---

## 21 · THE DEPLOYMENT PACKAGE — NOTHING APPLIED

Staged in `docs/app_v25/40_packages/`, **not** in `supabase/migrations` or
`supabase/functions`, because a file in those directories is applied or
deployed by name.

### PACKAGE A — ACCOUNT DELETION CORRECTNESS

| file | why | forward | rollback | old client | new client | order | secret | founder |
|---|---|---|---|---|---|---|---|---|
| **A1** `delete_user_account` storage purge | the deployed function has no storage delete; `storage.objects` has no FK to `auth.users` | `CREATE OR REPLACE` + the `DELETE FROM storage.objects` block | re-apply the deployed body | **SAFE** — deletes strictly more, and there is nothing to delete today | **SAFE** | **standalone; BEFORE `food-photos` is ever created** | none | apply |
| **A2** `patient_invitations.accepted_by` | a raw patient uid, no FK, redundant with `care_relationships` | `add constraint … on delete set null` + a column comment | `drop constraint` | **SAFE** — the RPC only ever writes `auth.uid()`, always a live user | SAFE | standalone | none | confirm SET NULL, then apply |
| **A3** three `comment on table` | turn three omissions into three decisions | comments | `is null` | SAFE | SAFE | any | none | read the three sentences and confirm each is true |

**STATUS: READY.**

### PACKAGE B — APPLE TOKEN CAPTURE / REVOCATION

| file | why | order | secret | founder |
|---|---|---|---|---|
| **B1** `private.apple_provider_tokens` | Apple's `/auth/revoke` needs a refresh token and Jeni holds none | **SERVER FIRST — the only server-first item in the package** | none | create the Apple key first |
| **B2** `apple-identity` Edge Function | mints `client_secret`, exchanges the code, revokes | after B1 | **APPLE_TEAM_ID · APPLE_KEY_ID · APPLE_CLIENT_ID · APPLE_PRIVATE_KEY** | §17 |
| — | one client line to capture `authorizationCode` | after B2 | — | a later build |

**STATUS: BLOCKED** — on a `.p8` that does not exist.

### PACKAGE C — SAFE ANONYMOUS REAPER

`scripts/reap_abandoned_anon_accounts.sql`. No migration, no secret, no
client. **STATUS: READY TO READ (steps 1–2), DELIBERATELY NOT RUNNABLE
(step 3 commented out).** Founder action: run step 1, choose a window, run
step 2, then decide.

### PACKAGE D — RETENTION-DECISION TABLES

`D_care_weekly_summaries.sql`, OPTION A **or** OPTION B, mutually exclusive.
**STATUS: BLOCKED — founder / counsel.** OPTION B additionally blocks on a
privacy-policy edit and the clinic consent copy landing **before or with**
it.

---

## 22 · WHAT THE TESTS PROVE

`plankAITests/LastOrphanContractTests.swift`, **20 tests.**

| the brief's contract | test | status |
|---|---|---|
| anonymous → new Apple: **SAME UID** | `39`'s `testSigningInWithAppleFromAnAnonymousSessionKeepsHerUserId` | **GREEN** (inherited, unchanged) |
| anonymous → existing Apple account: **NO SILENT ORPHAN** | `testWhenSignInLandsOnAnotherAccountTheAnonymousOneIsRetired` | **GREEN** |
| link success → crash: **RECOVERS** | §5 — the merge receipt is written at the switch; `resumePendingMergeIfNeeded` is shipped machinery pinned by `ReattributionTests` | **GREEN by construction** |
| link failure: **NO SILENT DATA ABANDONMENT** | `testWhenSignInLandsOnAnotherAccountTheAnonymousOneIsRetired` + `testWithoutACredentialNothingIsDeleted` | **GREEN** |
| network failure: **NO SILENT DATA ABANDONMENT** | `testWithoutACredentialNothingIsDeleted` (nothing is deleted on a guess) | **GREEN** |
| duplicate Apple callback: **IDEMPOTENT** | `testWhenTheIdentityLinkedNothingIsRetired` | **GREEN** |
| email conversion: **NO REGRESSION** | `signUpWithEmail` byte-identical to `1710180`; full suite +20 and nothing else | **GREEN** |
| account B on the same device: **NO ACCOUNT-A DATA** | `testOneAccountsRecordIsNeverMergedIntoAnother` | **GREEN** |
| **conversion succeeds: ONE UID OWNS ALL REACHABLE RECORDS** | `testAfterAConversionNoRecordStillAnswersToTheOldAccount` — footprint(A)==0 **and** footprint(B)==10 | **GREEN** |
| pending merge: **NOT CLEARED UNTIL PROVEN COMPLETE** | unchanged shipped lifecycle; the receipt now starts earlier | **GREEN** |
| a named account is never deleted | `testANamedAccountIsNeverRetired` | **GREEN** |
| the call carries the OUTGOING token | `testTheRetirementCallCarriesTheOutgoingTokenAndNothingElse` | **GREEN** |
| only a confirmed delete counts | `testOnlyAConfirmedDeleteCountsAsRetired` | **GREEN** |
| doses · symptoms · regimen · reads · memory follow | `testHerDosesSymptomsRegimenAndReadsFollowTheAccount` | **GREEN** |
| determinism survives the re-key | `testARekeyedDoseKeepsTheIdTheNewAccountWouldMintForThatDay` | **GREEN** |
| an underivable id is never guessed at | `testTheDeterministicRekeyRefusesAnIdItCannotDerive` | **GREEN** |
| version chains survive | `testTheVersionChainsSurviveTheRekey` | **GREEN** |
| the account's own row wins a collision | `testTheAccountsOwnRecordWinsAnIdCollision` | **GREEN** |
| consent is never carried | `testConsentIsNeverCarriedAcrossAnIdentitySwitch` | **GREEN** |
| the account's profile is never overwritten | `testAnExistingAccountsProfileIsNeverOverwrittenByTheDevices` | **GREEN** |
| a linked customer is recognised as Apple | `testAJustLinkedAppleCustomerIsRecognisedAsAnAppleCustomer` + `…StepReachesAJustLinkedCustomer` | **GREEN** |
| a deletion intent never reaches the next person | `testADeletionIntentNeverReachesTheNextPersonOnThisPhone` | **GREEN** |

### RED, MEASURED

With five cores at their pre-session behaviour — `AnonymousRetirementPolicy`
always leaves, `classify` never confirms, the retirement request carries no
`Authorization`, `IdentityMerge` a no-op, `rekeyedDeterministicId` always
nil, `AuthService.method` identities-only, `shouldMergeAnonymousPeriod`
without its `previousMethod` gate, and `AccountDeletionIntent` out of the
sweep:

```
Executed 20 tests, with 25 failures (0 unexpected)
** TEST FAILED **     exit 65
```

**14 of 20 methods red, 25 assertion failures.** The six that passed, and
why each is honest:

| passed under the stub | why |
|---|---|
| `testANamedAccountIsNeverRetired` | **a refusal test, and a stub that refuses everything satisfies it.** It cannot tell *"refused rightly"* from *"cannot act at all"* — **the seventh session running** |
| `testConsentIsNeverCarriedAcrossAnIdentitySwitch` | same shape: with the merge dead, nothing carries |
| `testAnExistingAccountsProfileIsNeverOverwrittenByTheDevices` | same |
| `testTheAccountsOwnRecordWinsAnIdCollision` | refusal-shaped — the incoming row never arrives, so exactly one remains. It exists beside the tests that DO move |
| `testIdentityStillDecidesAndAnonymousStaysAnonymous` | **a control** — it asserts the OLD behaviour is preserved, and the stub IS the old behaviour |
| `testAConfirmedDeletionIsStillOwedUntilTheSweepCompletes` | **`39`'s shipped finisher.** This file does not get to claim credit for it; it is the regression pin |

### What these tests CANNOT prove, stated

1. **That `linkIdentityWithIdToken` succeeds against THIS project's GoTrue.**
   Unchanged from `39`. Still the founder's one-line check.
2. **That the retirement RPC actually removed A's rows in production.** It
   needs a live anonymous session and a live collision. Proven from the
   deployed function's own text (§8) and from the RPC's `auth.uid()` scope,
   not from a call. **No server success was faked and no fake was used to
   simulate one.**
3. **That a deletion propagates to a second device.** It still does not
   (`38` §21.1). Out of scope, unchanged.

---

## 23 · PRODUCTION PROBES — READ-ONLY, PROVEN MECHANICALLY

Four SQL files, each proven read-only **before** it was run, by stripping
comments first so a keyword in prose could not mask a keyword in code:

| file | statements | first token of each | `insert`/`update`/`delete`/`upsert`/`merge` | DDL/DCL | result shape |
|---|---|---|---|---|---|
| `probe_schema.sql` | 1 | `select` | 0 · 0 · 0 · 0 · 0 | 0 | 135 column rows |
| `A_contract.sql` | 6 | `select` × 6 | 0 · 0 · 0 · 0 · 0 | 0 | function text · FK map · buckets · counts |
| `B_identity.sql` | 1 | `with` | 0 · 0 · 0 · 0 · 0 | 0 | 9 label rows |
| `C_population.sql` | 1 | `with` | 0 · 0 · 0 · 0 · 0 | 0 | 33 label rows |
| `D_guards.sql` | 1 | `with` | 0 · 0 · 0 · 0 · 0 | 0 | 20 label rows |

*(The word `delete` appears in `A_contract.sql` only inside the identifiers
`confdeltype` and `on_delete_action` and the literals `'set null'` /
`'cascade'` — the word-boundary count is 0 and every statement's first token
is `select`. Recorded rather than glossed.)*

Run through `supabase db query --linked` against `mtecqvykyeueumdynatd`.
**No row was written. No RPC was called. No reaper, migration, Edge Function
or Apple configuration was touched. No customer identity, email, name, health
value or jsonb payload was selected anywhere** — the one apparent exception,
`email like '%@example.com'`, returns a COUNT and selects no address.

---

## 24 · WHAT REQUIRES DEPLOYMENT OR FOUNDER ACTION

① **Ship this build.** Prevention is the only lever that moves this year.
② **One device check after the first Apple sign-in on this build** —
   `auth.users.created_at` should be **older** than that customer's
   `auth.identities.created_at`. (Unchanged from `39` §21.19 ⑦.)
③ **Apply A1** — the storage purge — **before the `food-photos` bucket is
   ever created.**
④ **Confirm A2** (`accepted_by` → `SET NULL`) and apply.
⑤ **Read A3's three sentences** and confirm each is the policy you intend.
⑥ **Answer §12** — OPTION A or OPTION B for `care_weekly_summaries`.
⑦ **Run the new reaper's step 1**, choose a window, run step 2. **Do not run
   step 3 yet, and never run `cleanup_orphaned_anon_users.sql`.**
⑧ **Create the Apple `.p8`** (§17), then deploy B1 → B2 → the client line.
⑨ **The archive-time bump to build 31.**

---

## 25 · RELEASE PROOF

Every command run **serially**, unpiped, `$?` captured directly.

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/LastOrphanContractTests` | 20 | **20** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` (full app suite) | 1308 | **1308** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.7 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is a SUCCEEDED line.** App suite **1288 → 1308, exactly +20**, which
is `LastOrphanContractTests` and nothing else: **no existing test changed and
none needed to.**

*(One run of WallExit exited 66 with `'plankAI.xcodeproj' does not exist` —
a `cd` left over from the package suites, not a test failure. Re-run from the
repository root and recorded from that run. Noted rather than quietly
re-run.)*

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **86 MB, 123,283 strings** — size and
total stated first, because *a zero from a file that does not exist is the
`Executed 0 tests` trap in different clothes* (`35`).

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `debug-delete-account` | **0** |
| `account.deletion.intent.v1` | **1** |
| `apple.user.identifier.v1` | **1** |
| **`rest/v1/rpc/delete_user_account`** | **1** — the retirement call ships |
| `sign-in and security` | **1** — Apple's fallback step still ships |
| `sync.pendingMergeV1` | **1** — the receipt written at the switch |
| `AnonymousRetirementPolicy` · `AnonymousAccountRetirement` · `IdentityMerge` · `AppleIdentityPolicy` · `AccountDeletionIntent` (`nm`) | **2 · 14 · 80 · 6 · 16** |

**No new DEBUG door was added this session.**

### Protected paths

| path | vs `1710180` | **this session** |
|---|---|---|
| `PlankApp/Payment` · `Views/Paywall` | **EMPTY** | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** | **EMPTY** |
| **`supabase/migrations`** | **EMPTY** | **EMPTY** |
| `supabase/` | `27`'s food-vision EF, still undeployed | **EMPTY** |
| `PlankApp/Analytics` | `31`'s +6 | **EMPTY** |
| `Packages/PlankFood` | `26`/`27`/`34` | **EMPTY** |
| `Packages/PlankSync` | `31`/`34`/`36`/`38` | **EMPTY** |
| **`PlankApp/Auth`** | +229 −18 | **MOVED — and it is the only place the orphan can be prevented** |
| **`PlankApp/Sync`** | +509 −18 | **MOVED** |

> **`PlankApp/Auth` MOVED AGAIN. Stated first, not buried.** Every addition
> is gated on the outgoing session being **anonymous** and the incoming uid
> being **different**; the retirement cannot throw, cannot fail a sign-in,
> and cannot name an account other than the one whose token it holds.
> `signOut`, **`signUpWithEmail`** and `classifyVerifyFailure` are
> **byte-identical to `1710180`**, verified function by function.
> `bootstrap` differs from `1710180` by **exactly `39`'s
> `AppleCredentialWatcher.start` block and nothing else** (diffed, not
> asserted) — **untouched this session**, and the restore ladder inside it
> is unchanged.

**All three files that declare a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **ZERO DIFF against
`1710180`**, re-derived this session with `grep -rlE "^[[:space:]]*@Model"`.
**There is no SwiftData store migration to fail.**

The `project.pbxproj` diff contains **only file references** — verified by
filtering out every `PBXBuildFile` / `PBXFileReference` / group-child line
and getting an empty result. **`CURRENT_PROJECT_VERSION` is still 30**,
`MARKETING_VERSION` still `1.2.0`.

### This session's files — fourteen

`Auth/AnonymousAccountRetirement.swift` **(new, 194)** ·
`Sync/IdentityMerge.swift` **(new, 325)** · `Auth/AuthService.swift` ·
`Sync/AppSync.swift` · `plankAITests/LastOrphanContractTests.swift`
**(new, 511, 20 tests)** · `plankAI.xcodeproj/project.pbxproj` (three file
references) · `scripts/reap_abandoned_anon_accounts.sql` **(new, 310)** ·
`docs/app_v25/40_packages/` **(6 new files)** · this document.

---

## 26 · THE TWENTY-FIVE ANSWERS

**1 · CAN THIS BUILD CREATE A NEW ORPHAN DURING NORMAL APPLE CONVERSION?**
**NO** for the conversion itself — the identity links and the uid never
splits. **NO** for the collision either, which is the case `39` left open:
the abandoned anonymous account is retired with its own credential at the
instant of the switch. The only residue is a **failed** retirement (offline,
5xx), which is exactly today's behaviour and is recorded categorically.

**2 · WHAT HAPPENS IF IDENTITY LINKING FAILS?**
The fallback signs her in — always, because a customer who cannot sign in is
a worse failure than an orphan. Then the OUTCOME is examined: if the session
now names a different account, the anonymous one is retired. Nine failure
modes are classified in §3.1; six are structurally safe, three are covered by
the retirement, and **`manual_linking_disabled` does not apply to this path
at all** — verified from GoTrue's source, not from a successful run.

**3 · DOES THE FALLBACK FROM `39` REINTRODUCE THE ORIGINAL P0?**
**IT DID — for every returning customer instead of every new one — AND IT NO
LONGER DOES.** `identity_already_exists` is returned for two opposite
situations under one error code, and `39`'s fallback treated them alike. That
is the single largest finding of this pass.

**4 · WHAT HAPPENS WHEN THE APPLE IDENTITY ALREADY BELONGS TO AN EXISTING
JENI ACCOUNT?**
GoTrue refuses the link (`"Identity is already linked to another user"`,
transaction rolled back). Jeni signs into that account, re-keys **all
eighteen** local families into it, pushes them, and retires the anonymous
account's server rows. Her record moves; nothing is deduplicated by content.

**5 · CAN THAT COLLISION LOSE THE ANONYMOUS CUSTOMER'S DATA?**
**NO.** Everything under the anonymous uid was pushed from this device, so
the local store is a superset of it; the merge carries the local rows and
`pendingUpsert` re-uploads them. **Before this build it lost eleven of
eighteen families — not to the server, but from her own screen.**

**6 · AFTER SUCCESSFUL CONVERSION, HOW MANY UIDS OWN HER RECORD?**
**ONE.** Asserted by counting the footprint under the old uid (zero) *and*
under the new one (ten of ten families), because a test that only checks the
first cannot tell moving from vanishing.

**7 · CAN A CRASH DURING CONVERSION CREATE AN ORPHAN?**
**It can leave one un-retired** — the retirement is one best-effort attempt
and cannot be retried, because retrying needs a bearer token this build
refuses to persist. **It can no longer strand her local rows**: the merge
receipt is written at the switch rather than when the merge starts, so
`onLaunch` finishes it. Every crash point is tabulated in §5.

**8 · WHEN IS `pendingMergeV1` CLEARED?**
Only after the merge AND its retry push have both run — unchanged. What
changed is when it is **written**: at the identity switch, not when
`onAuthChanged` eventually fires. It means MIGRATION IN PROGRESS, not WE
TRIED ONCE.

**9 · IS PRODUCTION SUPABASE CONFIGURED FOR THE LINKING PATH?**
**The setting does not gate this path.** `IdTokenGrant` and
`linkIdentityToUser` contain no reference to `ManualLinkingEnabled`; that
check belongs to the OAuth-redirect endpoint Jeni does not call. **The raw
production config value is UNKNOWN and is recorded as UNKNOWN** — reading it
needs the Management API and a personal access token, and this session was
read-only. **Local SDK support: YES. Client implementation: YES.**

**10 · WHY DID 30 OF 308 EMAIL TRANSITIONS NOT PRESERVE UID?**
**They are not transitions.** All 30 are `@example.com`, created sub-second
with their user row on 2026-07-29/30, with zero profile rows and zero health
rows — `scripts/s5_pilot_proof.py`'s `POST /auth/v1/signup` test accounts.
**Email conversion preserves the uid in 278 of 278 real conversions.**

**11 · DID THE APPLE FIX CHANGE EMAIL BEHAVIOR?**
**NO.** `signUpWithEmail` is byte-identical to `1710180` and the `upgraded`
branch is untouched. `signInWithEmail` — the **returning-customer** door, not
the conversion — gained the same orphan prevention, deliberately and stated.

**12 · WHAT DOES THE DEPLOYED DELETE FUNCTION MISS?**
**The storage purge** (in the repository, never deployed), the **five no-FK
tables**, the two `set null` telemetry tables (a stated choice), and
**everything under a prior anonymous uid**. 24 tables cascade correctly.

**13 · WHAT STORAGE CAN JENI ACTUALLY WRITE TODAY?**
`body-scans` (exists, private, opt-in, **0 objects**) and `food-photos`
(**the bucket does not exist**, so every upload fails and re-queues). Total
`storage.objects`: **0**.

**14 · IS STORAGE DELETION CORRECT EVEN THOUGH PRODUCTION HAS ZERO OBJECTS?**
**NO — and it is contained, not fixed.** `storage.objects` has no foreign key
to `auth.users`, so nothing removes an object when its owner is deleted. The
client's pre-RPC body-scan purge is the only thing in the product that ever
does. **Migration A1 restores the mechanism and must land before the
`food-photos` bucket is created.**

**15 · NAME THE FIVE NO-FK TABLES AND THEIR DELETION POLICY.**
`care_weekly_summaries` (0 rows) — **UNKNOWN, founder/legal** ·
`care_audit_events` (341) — **RETAIN**, comment drafted ·
`patient_invitations.accepted_by` (10) — **ANONYMIZE**, `SET NULL` drafted ·
`invitation_attempts` (29) — **RETAIN**, comment drafted ·
`ops_events` (0) — **RETAIN**, comment drafted. Zero orphans in all five.

**16 · IS `care_weekly_summaries` A CURRENT DATA PROBLEM?**
**NO. Zero rows, zero orphans, and no customer has ever been affected.** The
FUTURE contract is unresolved and both migrations are drafted; with zero rows
at stake it will never be cheaper to decide.

**17 · WHAT IS THE CORRECT REAPER PREDICATE?**
`is_anonymous` **AND** `created_at < now() − N` **AND** the newest of *every*
auth, customer and product timestamp for that uid `< now() − N`.
`last_sign_in_at` alone is wrong for **68%** of the population. A live
refresh token is **not** a usable guard — all 3,418 token-holding anonymous
accounts have a live one.

**18 · HOW MANY PRODUCTION ACCOUNTS WOULD THE SAFE REAPER REMOVE TODAY?**
**At 180 days: ZERO. At 120 days: ZERO. At 90 days: 56 accounts — 15 profile
rows, 14 weigh-ins, 0 food, 0 symptoms, 0 doses, 0 plans, 0 storage
objects.** The project is **107 days old**; every window ≥120 days is empty
by construction.

**19 · CAN ANY HISTORICAL ORPHAN BE ATTRIBUTED TO A CURRENT CUSTOMER?**
**NO, and it never will be.** Zero accounts have more than one identity;
there is no lineage table and no `previous_uid` column anywhere; the only
record of a prior uid is a device-local `UserDefaults` dictionary deleted the
moment the merge completes. No timestamp, device, body-metric, food, goal or
email join was used, and none may be.

**20 · CAN ANY HISTORICAL ORPHAN BE PROVEN ABANDONED WITHOUT ATTRIBUTING IT?**
**YES — abandonment is a different and provable claim.** 56 anonymous
accounts have produced no trace of any kind for over 90 days. **But a
superseded uid and a dormant-but-still-installed uid are indistinguishable**,
so the window must be long enough that total silence cannot mean "in use" —
and at that window the population is currently empty.

**21 · CAN A NEW APPLE USER NOW PRODUCE A REVOCABLE SERVER TOKEN?**
**NO.** The table, the function and the ordering are designed and staged;
none is deployed, because the `.p8` does not exist. Apple's documented
fallback is what the app does, and as of `39` it does all three steps of it —
and as of this build a **just-linked** customer is actually shown step 2,
which she was not.

**22 · WHAT EXACTLY MUST I DO WITH THE `.p8`?**
Create a **Sign in with Apple** key in Apple Developer › Keys, configured
against the primary App ID `com.bk.plankAI`; download it **once**; record the
Key ID and Team ID; then `supabase secrets set APPLE_TEAM_ID · APPLE_KEY_ID ·
APPLE_CLIENT_ID=com.bk.plankAI · APPLE_PRIVATE_KEY="$(cat AuthKey_….p8)"`.
**Never the repository, never the app bundle, never `UserDefaults`, never a
log, and never pasted into a chat.**

**23 · IF APPLE `/auth/revoke` IS DOWN, DOES JENI DATA STILL DELETE?**
**YES — by construction, not by a branch.** Revocation is not in the deletion
path at all: `deleteCurrentAccount` neither calls it nor awaits it. When the
function exists it returns `200 { ok: true, revoked: false }` on every Apple
failure precisely so the client has nothing to branch on. **An Apple outage
must never become a Jeni retention event.**

**24 · WHAT EXACTLY REQUIRES DEPLOYMENT OR FOUNDER ACTION?**
The nine items in §24. Only **one** is blocked on something engineering
cannot answer (§12), and it now blocks nothing but itself.

**25 · SAFE FOR NEXT BUILD: YES.**
Every change is additive and device-local except the retirement, which can
only ever delete an **anonymous** account whose token it holds, at the one
instant that account is being abandoned. No arithmetic moved, no `@Model`
changed, no schema, no deploy, no production SQL beyond read-only SELECTs,
`supabase/migrations` **EMPTY**.

---

# SCORECARD

Graded hard. Anything below 9 names the exact blocker.

| domain | `39` | now | the exact blocker |
|---|---|---|---|
| **NEW-ORPHAN PREVENTION** | 8 | **9** | Every transition Jeni can produce is closed. **Blocker: the retirement is one best-effort attempt and cannot be retried, because retrying requires persisting a bearer token. An offline collision still leaves an orphan.** |
| **IDENTITY COLLISION** | — | **9** | The abandoned account is retired and the record moves whole. **Blocker: the same single attempt.** |
| **CRASH RECOVERY** | — | **9** | Resumable from persisted state at every point in §5. **Blocker: an RPC that succeeds with a lost response still shows a failure on the first tap; closing it needs a server-side idempotency key.** |
| **ACCOUNT DELETION** | 8 | **9** | Idempotent, convergent, and the intent is now swept. **Blocker: `patient_invitations.accepted_by` retains a raw uid until A2 is applied.** |
| **SERVER DATA DELETION** | 7 | **8** | 24 tables cascade; four of the five no-FK tables now have drafted decisions. **Blocker: `care_weekly_summaries` is a founder/legal answer, and A1–A3 are unapplied.** |
| **STORAGE DELETION** | 5 | **6** | **Blocker: the deployed RPC still has no storage delete.** Contained only because `storage.objects` is empty and `food-photos` does not exist. Migration A1 is written, forward and rollback, old- and new-client safe. |
| **APPLE REVOCATION** | 6 | **7** | TN3194's fallback is complete **and now actually reaches a just-linked customer**, which it did not. **Blocker: Jeni holds no revocable token; capturing one needs a `.p8`, an Edge Function and a table, all staged and none deployed.** |
| **ANONYMOUS REAPER** | — | **8** | The predicate is correct, measured, and refuses the guard that does not work. **Blocker: it is a maintenance job that cannot repair anything for months, because the project is younger than any safe window — and it is written, not run.** |
| **PRIVACY CONTRACT** | 7 | **8** | *"No soft-delete; the data is unrecoverable"* is now true for **every** future account, including collisions. **Blocker: still false for the ~559–3,425 historical anonymous accounts, and no reaper can honestly reach them yet.** |
| **OLD-CLIENT SAFETY** | — | **10** | Nothing about the server contract changed. Build 30 behaves exactly as it does today, and every staged migration is old-client-safe in every cell. |

---

# THE FIVE BUCKETS

### BUILD NOW
1. **The anonymous retirement** — the fallback's own orphan, closed at the
   one instant a credential exists.
2. **The merge extension** — eleven families that vanished from her own
   phone on every uid change.
3. **The named → named merge guard** — a cross-account leak.
4. **The `authMethod` fallback** — a just-linked Apple customer is an Apple
   customer.
5. **The merge receipt at the switch, and the deletion-intent sweep.**

*(All five are in this build.)*

### READY — DO NOT DEPLOY
1. **A1** `delete_user_account` storage purge — forward and rollback,
   standalone, **before `food-photos` is ever created**.
2. **A2** `patient_invitations.accepted_by` → `SET NULL`.
3. **A3** three `comment on table` decisions.
4. **B1/B2** the Apple token store and revocation function — complete,
   blocked on a key that does not exist.
5. **`scripts/reap_abandoned_anon_accounts.sql`** — steps 1–2 read-only,
   step 3 commented out.

### FOUNDER ACTION
1. **Answer §12** — OPTION A or OPTION B for `care_weekly_summaries`. The
   only genuinely blocked item, and it is free of consequence today.
2. **Create the Apple `.p8`** (§17).
3. **Confirm A2 and A3's sentences**, then apply Package A.
4. **The device check after the first Apple sign-in on this build.**
5. **The archive-time bump to build 31.**

### PRODUCTION REPAIR
1. **Nothing that helps this year.** Stated plainly: at a defensible window
   the safe reaper removes **zero** accounts, and at 90 days it removes 56 of
   3,425. **The repair is prevention, and it is in this build.**
2. Run the new reaper's steps 1–2 to see it for yourself.

### DO NOT TOUCH YET
1. **`scripts/cleanup_orphaned_anon_users.sql`** — it would delete three
   living customers' records today. Superseded; do not run it, ever.
2. **The server tombstone.** Still `41`'s work, still blocked on a filtering
   client reaching the installed base (`38` §6).
3. **The `food-photos` bucket / photo sync.** Creating the bucket before A1
   opens the storage hole for real.
4. **An Apple server-to-server endpoint.** Revisit with Package B; today it
   closes nothing the native notification does not (§19).
5. **Backfilling an anonymous → named uid link from row shapes.** The
   fabrication class this whole line of work exists to remove.
6. **Syncing Jeni memory, chat, movement or body scans.** *We do not sync
   more customer data until deletion semantics are trustworthy.*

---

## THE THREE SENTENCES

> ▎ **CAN A CUSTOMER ON THIS BUILD CREATE A NEW UNOWNED UID BY SIGNING IN
> ▎ WITH APPLE?**

**UNDER EXACTLY ONE CONDITION: the sign-in lands on a different account
AND the single retirement call does not reach the server** — offline, a
Supabase 5xx, or the process dying in that window. In every other case the
uid either never splits or the abandoned account is deleted.

*The shortest exact path to NO:* the retirement needs to be retryable, which
needs a durable credential, which this build refuses to persist. The clean
answer is a **server-side merge receipt written while the anonymous session
is still live** — an `old_uid → new_uid` row an RPC can act on later. That is
a migration plus a security review, and it is `41`'s work, not a line of
code.

> ▎ **CAN I SAFELY CLEAN THE HISTORICAL ORPHANS TODAY?**

**NO.**

*The shortest exact path to YES:* there isn't a short one, and pretending
otherwise is the thing to avoid. A safe predicate exists and is written; the
population it can honestly touch is **zero at 120 days and 56 at 90 days**,
because the project is 107 days old. **Wait.** Run
`scripts/reap_abandoned_anon_accounts.sql` step 1 monthly; the eligible set
grows on its own, and by then this build will have stopped adding to it.

> ▎ **CAN I TRUTHFULLY SAY "DELETE MY ACCOUNT REMOVES MY JENI DATA"?**

**For a customer who signs in on this build or later: YES.** Her identity
does not split, and if it must, the account it leaves behind is deleted in
the same breath.

**For the customers already here: NO.**

*The shortest exact path to YES:* ① ship this build — from here the set stops
growing; ② apply A1 before any bucket exists; ③ apply A2 and answer §12;
④ let the silent set age past a defensible window, then reap it. Steps ①–②
are today. Step ④ is arithmetic and patience.

---

## THE REMAINING PRODUCTION TRUTH

Not "the tests are green". This is what is true of the database right now,
after everything above:

- **3,425 anonymous accounts** hold **2,327 weigh-ins · 652 plates · 164
  regimen plans · 53 symptoms · 14 doses · 2,162 profile rows.** Nobody can
  name which of them were superseded, and nobody ever will.
- **80 of those accounts acted in the last seven days.** They are not
  orphans. They are customers.
- **56 have been silent for more than 90 days. None has been silent for
  more than 180**, because the product is 107 days old.
- **The deployed `delete_user_account()` is one `DELETE FROM auth.users`.**
  It has never contained the storage purge the repository has always shown.
- **`storage.objects` is empty and `food-photos` does not exist**, so the
  hole that fact opens has never cost a customer anything — and it is one
  `create bucket` away from costing every customer something.
- **`care_weekly_summaries` has zero rows and no foreign key.** The cheapest
  moment to decide its retention is now, and it has been now for three
  passes.
- **867 named accounts hold exactly 867 identities.** Not one has two.
- **Not one Apple customer has a token Jeni can revoke.**

**The last orphan Jeni creates should be the one made the day before this
build ships.**
