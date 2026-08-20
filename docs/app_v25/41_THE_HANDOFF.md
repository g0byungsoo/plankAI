# THE HANDOFF

**Status: `40`'s FIX ATTACKED AND HOLED · SIX CLIENT-ONLY FIXES BUILT ·
THE SERVER HANDOFF DESIGNED, WRITTEN AND STAGED. 2026-08-14.**

`39` stopped the orphan factory for a new Apple identity. `40` attacked
that fix, found its fallback rebuilt the same P0 for returning customers,
and closed it with a client-side retirement it correctly described as
un-retryable. This pass has one job:

> ▎ **AN ACCOUNT TRANSITION IS NOT COMPLETE UNTIL EVERY CUSTOMER-OWNED
> ▎ RECORD HAS ONE KNOWN OWNER AND THE SOURCE IDENTITY HAS REACHED ITS
> ▎ EXPLICIT TERMINAL STATE.**
>
> ▎ **NAMED → NAMED IS ACCOUNT SWITCHING. IT IS NEVER DATA MIGRATION.**
>
> ▎ **NO CUSTOMER RECORD MAY DISAPPEAR MERELY BECAUSE ITS USER_ID
> ▎ CHANGED.**

`29`–`40` are frozen. No calorie formula, protein formula, plan
selection, restore path, safety rule, payment, paywall, `AppPhase`,
`Info.plist`, entitlement, analytics event or HealthKit type moved. **No
migration applied. No migration file written to `supabase/migrations`. No
Edge Function deployed. No production row mutated. No reaper executed. No
Apple credential or Developer Portal change. `CURRENT_PROJECT_VERSION` is
still 30.**

**This is not the tombstone pass, the Jeni-memory-sync pass, the
historical-orphan-repair pass, the food-vision deploy or the Apple `.p8`
pass.** None of them was built, designed further, or blurred into this
work.

---

## 0 · THE ANSWER FIRST

**`40`'s fix is correct, and attacking it found five more ways an account
transition goes wrong — three of them the same shape: a decision that
belongs to ONE identity being carried into another.**

| # | the finding | class |
|---|---|---|
| 1 | **THE CARRY CAN FAIL SILENTLY AND PERMANENTLY, AND ITS MOST LIKELY COLLISION WAS UNGUARDED.** `DayProgressRecord.compositeKey` is `@Attribute(.unique)` and the re-key rewrote it to `"<newUid>:<day>"` with no destination check — the ONE unguarded unique key in the whole merge. The server has the same shape: **`public.day_progress`'s PRIMARY KEY is `(user_id, program_day)`**, read from the live catalog. Both accounts holding day 1 is the normal case (43 anonymous and 64 permanent accounts hold day-progress rows). SwiftData does not throw on it — **it silently collapses the two rows and nothing specifies which survives** — and the whole carry is one context and one `try?` `save()`, with the receipt cleared immediately after. **FIXED.** | **P0 — silent, unspecified loss** |
| 2 | **A PRESCRIPTION FOLLOWED THE PERSON.** The deployed RLS refuses a client insert of a care-team regimen (`authority = 'self' AND org_id IS NULL AND source_protocol_id IS NULL`) or a prescribed program fact (`authority <> 'prescribed'`). The merge re-keyed both. The push is rejected 42501 forever, silently; locally `RegimenService.activeCareTeamMedicationPlan` then returns a clinic-assigned plan **for an account that clinic has never met**, which makes her regimen read-only, renders *"assigned by your care team"*, and hands `CareReconciliation` a prescription to confirm. **Production holds nine care-team regimen rows and ALL NINE are under anonymous accounts.** **FIXED.** | **P0 — clinical authority leak** |
| 3 | **NAMED → NAMED STILL CARRIED HER WORDS.** `40` closed the SwiftData half. The cross-account isolation sweep runs on explicit sign-out and account deletion **and on nothing else**, so a sign-in that changed accounts left every device-scoped customer-authored key in place: `move.manual.v1` (every workout she typed, counted in Home's strength tile), `day.note.*` and `day.reflection.*` (her evening words, which reach Jeni's context envelope), `day.sit.*`, the whole `safety_*` family, and her body facts wherever B's profile row carries a null. **FIXED.** | **P0 — the other half of the firewall** |
| 4 | **SIGNING OUT MID-HANDOFF STRANDED THE ANONYMOUS PERIOD FOREVER.** The same sweep removed `sync.pendingMergeV1`, the only record that a carry was owed. The identical shape applies to `AccountDeletionIntent` at `.serverComplete`: signing out in that window discharged a CONFIRMED deletion's local purge and left every row of a deleted account on disk. **BOTH FIXED.** | **P1 — convergence** |
| 5 | **[CORR] THE RETIREMENT COULD DESTROY THE ONLY COPY.** `40` §3.4 reason 2 states *"every server row under A was pushed FROM this device, so the local store is a superset of it"* as a fact. It is not, in one reachable state: the Supabase session lives in the Keychain, which survives deleting the app, so a reinstall can re-adopt the same anonymous uid with an EMPTY store — and if the launch hydrate has not landed, retiring A deletes the only copy that exists. **FIXED.** | **[CORR] on `40` §3.4** |
| 6 | **[CORR] REFUSED WAS NOT THE SAME AS REMOVED.** `40` refuses to overwrite the destination's profile and refuses to carry consent — both right — and then left both rows on disk keyed to a uid about to be retired. The profile holds her height, weight, goal, sex and cohort; nothing queries it, nothing hydrates it, and `clearLocalUserRecords` scopes to the account she is now in, so **"delete my account" never reached either.** The same shape `37` closed for jeni memory, program facts and weekly reads. **FIXED — found by a test asserting `footprint(source) == 0`.** | **P1 — privacy** |
| 7 | **[CORR] THE COUNT.** The repository declares **eighteen** `@Model` types, but `ExerciseRecord` is the exercise LIBRARY (`type` / `unlockDay` / `isStatic`, no `userId`, seeded from a static array). **Seventeen are customer-owned, and the pre-`40` merge dropped TEN, not eleven.** And `@Model` was never the ownership inventory: food, food photos, **`public.day_reflections` — a SERVER table of her free text that is in no merge at all** — `move.manual.v1`, the deletion ledger and the body-scan JPEGs are customer-owned and are not `@Model` rows. | **[CORR] on `40` §2** |
| 8 | **RLS PROVES THE TRANSFER BELONGS SERVER-SIDE, MECHANICALLY.** Every UPDATE policy on every customer table is `USING (auth.uid() = user_id)` **and** `WITH CHECK (auth.uid() = user_id)`. On an ownership change Postgres evaluates USING against the OLD row and WITH CHECK against the NEW one, so **no single bearer token can satisfy both halves.** That is not a gap; it is the policies working, and it is the answer to the brief's §8. | **the design constraint** |

And the sentence that decides what could be shipped:

> ▎ **THE SERVER HANDOFF AND THE CLIENT THAT CALLS IT ARE ONE CHANGE WITH
> ▎ AN ORDER.** The client mints fresh record ids *because* the cloud row
> still belongs to the old uid; after a server move it must not. So the
> id policy is not separable from the migration, the migration must be
> verified in production first, and **a client written against an
> unverified contract is the same class of error as `38` §11's storage
> purge that was "PROVEN BY CODE" and had never been applied.**

**SHIPPED, all client-only, no schema, no deploy:** the three operations
as explicit contracts · the named→named firewall extended to
device-scoped customer state · the day-progress collision guard · the two
authority refusals · the plan and regimen conflict rules · the receipt
that survives a sweep · the retirement's carry gate · refused rows
removed rather than stranded.

**READY — NOT APPLIED:** `docs/app_v25/41_packages/E1_account_handoffs.sql`
— the receipt table, `begin_account_handoff`, `complete_account_handoff`
and the private per-family transfer, with an authorization that is **not
a bearer credential** and needs nothing persisted on the device.

---

## 1 · EVERY SEQUENCE, TRACED THROUGH THE SHIPPING CODE

No "should". Traced through `AuthService.completeAppleSignIn` /
`signInWithEmail` / `signUpWithEmail`, `AppSync.onAuthChanged` /
`onLaunch`, `AnonymousAccountRetirement`, `IdentityMerge` and
`clearOnboardingUserDefaults`, as they stand after this build.

Legend — **A** the outgoing uid · **B** the incoming uid · **carry** the
local re-key · **retire** the one best-effort `delete_user_account()`
call with A's own token.

| # | sequence | SOURCE→DEST UID | TOKENS | LOCAL WRITE | SERVER WRITE | DELETED | REKEYED | COPIED | LEFT BEHIND | RECEIPT |
|---|---|---|---|---|---|---|---|---|---|---|
| **A** | anonymous → **new** Apple identity | A → **A** | A's, kept | none | none | nothing | nothing | nothing | nothing | **none — an upgrade owes none** |
| **B** | anonymous → **existing** Apple account | A → B | A's held in memory for the length of the call; B's from the switch | carry, all 17 families | `pendingUpsert` push under B | A's server rows, via `retire` | 17 families, fresh or prefix-swapped ids | nothing | **nothing — `footprint(A) == 0` is asserted** | `sync.pendingMergeV1` written **at the switch** |
| **C** | anonymous → email conversion (`signUpWithEmail`) | A → **A** | A's, kept | none | profile re-upsert | nothing | nothing | nothing | nothing | none |
| **D** | **named A → named B** | A → B | A's dropped, B's installed | **isolation sweep only** | none | **nothing** | **nothing** | **nothing** | A's SwiftData rows, deliberately — she can sign back in | **none, and any in-flight one SURVIVES** |
| **E** | anonymous A → Apple B, **link fails** | A → B | as B | as B | as B | as B | as B | — | — | as B |
| **F** | anonymous A → Apple B, **link succeeds** | A → **A** | A's, kept | none | none | nothing | nothing | nothing | nothing | none |
| **G** | anonymous A → Apple B, **network dies after the session changes** | A → B | A's token lost with the process | carry resumes at next launch | resumes | **A survives — the hole E closes** | 17 families | — | **A's server rows** | receipt survives sign-out now, so the carry converges |
| **H** | anonymous A → Apple B, **carry interrupted** | A → B | B's | partial carry; the rest at next launch | at next launch | — | remainder | — | — | **kept until the carry COMMITS** |

**What changed in this table versus `40`'s.** Row **D** used to sweep
nothing. Row **B** used to leave a profile row and a consent row keyed to
A. Rows **G** and **H** used to discharge the receipt whether or not the
carry committed, and to lose it entirely on a sign-out.

**Row G is the residue, and it is the one the staged migration closes.**
Its shortest exact path to NO is §9–§13.

---

## 2 · THE CANONICAL OWNERSHIP INVENTORY, RE-DERIVED

**Not inherited from `40`.** Derived from `grep -rlE "^[[:space:]]*@Model"`,
from the live catalog for the server side, and from the sweep lists for
the device-scoped families.

### 2.1 · The `@Model` families — SEVENTEEN, not eighteen

| family | server table | PK | owner key | server copy? | carried today | rule | conflict | if lost |
|---|---|---|---|---|---|---|---|---|
| `UserRecord` | `public.users` | **`id` IS the uid** | `id` | yes | **B WINS; A's row REMOVED** | destination wins | **cannot move — the PK is the uid** | her body facts; the account's own are authoritative |
| `SessionLogRecord` | `session_logs` | `id` | `user_id` | yes | rekey, fresh uuid | move | none | workout history |
| `SessionRatingRecord` | `session_ratings` | `id` | `user_id` | yes | rekey, fresh uuid | move | none | how a session felt |
| `DayProgressRecord` | `day_progress` | **`(user_id, program_day)`** | in the PK | yes | **rekey, DESTINATION WINS** | destination wins | **guaranteed on any shared day** | which day she is on |
| `WeightLogRecord` | `weight_logs` | `id` | `user_id` | yes | rekey, fresh uuid | move | none | **the numerator of both daily targets** |
| `ExerciseCalibrationRecord` | `exercise_calibrations` | **`(user_id, exercise_type)`** | in the PK | yes | rekey, destination wins | destination wins | on a shared exercise | difficulty tier |
| `ProgramPlanRecord` | `program_plans` | `id` uuid | `user_id` | yes | rekey, fresh uuid | **DESTINATION'S LIVE PLAN WINS; A's arrives archived** | one live plan | her program's day anchor |
| `ProgramDayCheckRecord` | `program_day_checks` | `id` | `user_id` | yes | rekey, fresh uuid | move | none (plan id is fresh) | kept-item state |
| `ObservationRecord` | `observations` | `id` (deterministic) | `user_id` | yes | prefix swap, destination wins | destination wins | on a shared kind×day | **symptoms; `VisitPacket` reads them** |
| `ConsentGrantRecord` | `consent_grants` | `id` | `user_id` | yes | **REFUSED and REMOVED** | refused | — | nothing — permission is not portable |
| `RegimenPlanRecord` | `regimen_plans` | `id` | `user_id` | yes | **self only; care-team REFUSED**; live head ends if B has one | refused / ended | one live medication head | her medication regimen |
| `DoseEventRecord` | `dose_events` | `id` (deterministic) | `user_id` | yes | prefix swap, destination wins | destination wins | on a shared slot day | **every shot she marked** |
| `ProgramFactRecord` | `program_facts` | `id` | `user_id` | yes | **non-prescribed only** | refused | chain heads | her program's authority chains |
| `WeeklyReadRecord` | `weekly_reads` | `id` (deterministic) | `user_id` | yes | prefix swap, destination wins | destination wins | **a second row for one week** | the read's decisions |
| `BodyScanRecord` | none (local) | `id` | `userId` | **no** | rekey in place | move | none | her scans |
| `ChatMessageRecord` | `coach_messages` (**zero writers**) | `id` | `userId` | effectively no | rekey in place | move | none | the transcript |
| `JeniMemoryRecord` | none | `id` | `userId` | **no** | rekey in place | move | none | **free text she asked Jeni to keep** |

*(`ExerciseRecord` is the eighteenth `@Model` and is NOT customer-owned:
it has no `userId` and is the seeded exercise library.)*

### 2.2 · The families that are not `@Model` rows — SEVEN more

| family | store | server | carried today | rule |
|---|---|---|---|---|
| **food journal** | `FoodLogPersister` JSONL | `food_logs` (+ `food_log_items`, `food_corrections`, both **0 rows, no client writer**) | rekey, fresh ids, photo follows | move |
| **food photos** | local files keyed by entry id | `storage.objects` bucket `food-photos` — **the bucket does not exist** | follow the entry | move |
| **`move.manual.v1`** | UserDefaults, **device-scoped** | none | **follows the device** | **device-scoped: follows the PERSON, swept on a SWITCH** |
| **`day.note.*` · `day.reflection.*`** | UserDefaults, day-keyed | **`public.day_reflections`** — a server table of her evening words, **in NO merge** | follows the device | device-scoped |
| **`day.sit.*` · `day.dose.*` · `band.*`** | UserDefaults | partly `observations` | follows the device | device-scoped |
| **`safety_*` / `onb_*` body + cohort facts** | UserDefaults | partly `public.users` | follows the device | device-scoped |
| **`deletions.v1.<uid>`** | UserDefaults, uid-keyed | none | cleared for A on a committed carry | **REFUSED — never crosses** |

> ▎ **A DEVICE-SCOPED CUSTOMER-AUTHORED FACT FOLLOWS THE PERSON.** So it
> follows an ADOPT — the same person — and it must not follow a SWITCH,
> which is a different person on the same phone. Before this build the
> first was true by accident and the second was false.

**`public.day_reflections` is the one server-backed family no merge has
ever covered**, in either direction. It is device-keyed locally, so it
follows the person on an ADOPT (correct) and was carried on a SWITCH
(wrong, now swept). Its server rows stay under A and are deleted with A.
Five rows exist in production.

---

## 3 · THREE OPERATIONS, WRITTEN AS THREE CONTRACTS

`PlankApp/Auth/AccountOperation.swift`. Pure, nonisolated, one rule.

> ▎ **THE FORBIDDEN INFERENCE: `oldUid != newUid ⇒ MERGE`.**
> A uid change is the one fact all three operations share, so it is
> evidence of none of them.

| | **A · UPGRADE IDENTITY** | **B · ADOPT** | **C · SWITCH ACCOUNT** |
|---|---|---|---|
| shape | anonymous A → permanent A | anonymous A → permanent B | permanent A → permanent B |
| uid | **same** | different | different |
| carries the anonymous period | **no** | **YES — the only one** | **no** |
| isolates the outgoing account | no | no (same person) | **YES** |
| may retire the source | no | **yes** | **never** |
| writes a receipt | no | yes | no |
| server handoff (staged) | none — nothing to hand off | BEGIN + COMPLETE | **refused at BEGIN: a permanent account cannot open one** |

**The classification uses POSITIVE PROOF.** `.adopt` requires
`previousMethod == .anonymous`. Not a different uid, not a missing
profile, not a fresh account, not the absence of an Apple identity.
**`.unknown` is not a weaker `.anonymous`** — it is the absence of proof,
and `40` §0 finding 4 showed a just-linked Apple customer genuinely reads
it — so it classifies as a SWITCH, the outcome that moves nothing.

**Every caller that used to choose.** `AppSync.onAuthChanged` was the only
one, and it chose with `userIdChanged && !isAnonNow` (+ `40`'s
`previousMethod` guard). It now classifies once and reads the operation's
own properties. `AppSync.shouldMergeAnonymousPeriod` — which
`LastOrphanContractTests` pins — is unchanged in signature and now
**delegates to the classifier**, so there is one rule in the product
rather than a condition here and a second one wherever the next caller
needs it.

---

## 4 · THE NAMED → NAMED FIREWALL

**`40` closed the SwiftData half and it holds.** The gate is positive
proof that the source was anonymous, and after this build there is a
SECOND gate the client cannot reach around: `begin_account_handoff`
raises `42501` unless `auth.users.is_anonymous` is true for the caller,
so once the migration is applied a permanent account cannot open a
handoff at all.

**The half that was open is not SwiftData.** The isolation sweep
(`clearOnboardingUserDefaults`, ~100 explicit keys + 22 prefixes) runs
from `AccountView.performSignOut` and from `deleteCurrentAccount`, and
from nowhere else. `AppSync.applyIsolationIfNeeded(for:)` now runs it on
a SWITCH, **first — before the RevenueCat re-key, before any hydrate,
before anything reads for the incoming account.**

**Where a switch is reachable, checked rather than recalled:**

| door | gate | named → named reachable? |
|---|---|---|
| `AccountView` → `SignInPromptView` | `auth.isAnonymous \|\| !auth.isAuthenticated` | **no** |
| `MainShell` re-auth sheet | `auth.needsReauth` | **yes** — the SDK-wiped-linked-session branch keeps `currentUser` named |
| `WallView` *"signed in before? sign in"* (two call sites) | none | **yes** — a lapsed payer is still signed in |
| `PaywallView` sign-in sheet | none | **yes** |

**The trade this makes, stated.** The sweep runs before the incoming
account's own answers can be restored, so between it and
`syncUserDefaultsFromUserRecord` the device holds neither account's
onboarding state. `35` already tested and accepted exactly this trade for
the `safety_` family at sign-out: *the sweep runs before the next
identity is known, so the choice is between losing device-local state and
handing it to a stranger.* A switch is the same moment with the same
choice — and unlike a cold launch, a switch has just completed a network
round trip, so the hydrate that restores B's own answers is the likely
case rather than the hopeful one.

**Proved with two fully populated permanent accounts:**
`testSwitchingBetweenTwoAccountsLeavesBothRecordsIntact` seeds A and B
with a weigh-in, a regimen, a dose, a symptom, a memory and a transcript
each, switches, asserts **zero of A's rows changed owner and zero of B's
rows changed because A existed**, then switches back and finds A intact.
`testASwitchClearsHerDeviceScopedRecordAndAnAdoptKeepsIt` asserts the
device-scoped half in both directions.

---

## 5 · SAME-UID UPGRADE MUST NOT MERGE — AND IT IS BORING

`testASameUidUpgradeCarriesNothingAndMintsNoId` asserts, on a fully
seeded account:

- the operation classifies as `.upgradeIdentity`, whose three properties
  are all false;
- the merge machinery **refuses the same-uid pair by construction**, so
  even a caller that ignored the operation moves nothing;
- **no row is copied**, `footprint` before == after;
- **no id is minted** — the regimen's id is identical;
- **no timestamp moves** — `updatedAt` is identical;
- **no receipt is written.**

**Nothing about this path changed in this build.** The test exists
because "it does nothing" is a contract, and an untested contract is a
comment.

---

## 6 · THE EXISTING-ACCOUNT COLLISION — THE REAL HANDOFF

The desired final state, and the two things it may not be:

- **It cannot be "sign into B and delete A."** Deletion before a
  successful transfer is data loss — and §5's finding shows the shipping
  code could do exactly that when the local store was empty.
- **It cannot be "copy everything and hope."** That creates clinical
  duplicates, and content-similarity dedup is forbidden (§7).

**What ships now (client-only).** The carry moves all seventeen `@Model`
families plus food, with per-family collision rules; the profile and
consent are refused **and removed**; care-team regimen and prescribed
facts are refused **and removed**; the destination's live plan and live
medication head keep the present tense; A's server rows are retired with
A's own token, **only when this device is carrying A's record**.

**What the staged migration adds.** The retirement becomes durable and
retryable without any bearer token, and the transfer becomes
**id-preserving** — because server-side there is no RLS reason to mint a
fresh id.

---

## 7 · NO HEALTH RECORD IS DEDUPLICATED BY SIMILARITY

The rule, everywhere, on both sides:

> ▎ **A CUSTOMER-OWNED RECORD SURVIVES UNLESS IDENTITY IS PROVABLY
> ▎ DUPLICATE — WHICH MEANS ONE KEY, NEVER ONE RESEMBLANCE.**

| forbidden | what happens instead |
|---|---|
| same weight + same day = duplicate | **both survive.** `weight_logs` has no per-user unique constraint; two weigh-ins on one day are two weigh-ins |
| same dose + same day = duplicate | one **id** means one slot for one account. The destination's row wins that id; content is never read |
| same symptom + same severity = duplicate | same, keyed on kind × day |
| same meal + similar timestamp = duplicate | **both survive** — a plate is not a duplicate because it looks like one |
| same regimen dose = duplicate | **both survive**; A's live head is ENDED, not merged, so her dose eras stay in the record |

**The only rows dropped are dropped on a KEY**, and the row already
inside the destination account is the one that stays. `day_progress`,
`exercise_calibrations` and `day_reflections` are dropped whole, because
their key contains the uid and two rows cannot both be it.

---

## 8 · IDENTITY-PRESERVING TRANSFER — CAN THE ID SURVIVE?

| family | id survives today (client)? | why not | id survives under the staged migration? |
|---|---|---|---|
| weight · sessions · ratings · plans · checks · food | **NO — fresh uuid** | *"the cloud row already exists under the old uid, so a same-id upsert is an UPDATE that RLS rejects with 42501"* | **YES — the server changes the owner, not the id** |
| dose · observation · weekly read | **prefix swap** — new, and exactly the id the destination WOULD mint | both invariants at once: a clean INSERT, and determinism | **prefix swap, same rule, same value** |
| jeni memory · chat · body scan | **YES, untouched** | no server row exists | yes |
| profile | n/a | the PK **is** the uid | n/a — never moves |
| day progress · calibration · reflection | n/a | the uid is IN the key | rewritten with the key; destination wins |

> ▎ **RLS PREVENTS A CLIENT REKEY, AND THAT IS THE EVIDENCE THE TRANSFER
> ▎ BELONGS SERVER-SIDE.** `USING` sees the old row, `WITH CHECK` sees
> the new one; the source's token fails the second and the destination's
> fails the first. Read off `pg_policies`, not inferred.

**A fresh uuid is never minted merely because the client cannot update
`user_id`** — it is minted because RLS makes the alternative a silent
42501, and the staged migration removes that reason.

**Idempotency without ids.** The carry only ever fetches rows still keyed
to the OLD uid, so a completed pass is a no-op and a half-finished one
picks up the remainder. `testReplayingTheHandoffDoesNotDuplicateHerRecord`
runs it twice and asserts the second run adds nothing. The server half is
idempotent the same way, plus a terminal receipt state.

---

## 9 · THE SERVER RECEIPT — THE SMALLEST DURABLE FACT

`public.account_handoffs`. Nine columns, and each one answers a question
the brief asks.

| column | answers | why not more |
|---|---|---|
| `id` | — | |
| `source_user_id` | SOURCE UID | **FK `on delete set null`**, so retiring the source anonymises the receipt in the same statement |
| `destination_user_id` | DESTINATION UID | FK `on delete cascade` — the receipt is hers and goes with her account |
| `provider` | OPERATION TYPE | `apple` \| `email` |
| `subject_hash` | the authorization (§11) | a one-way digest, **nulled at completion** |
| `state` | STARTED? · COMPLETE? | `open` \| `completed` |
| `created_at` · `expires_at` | WHEN? · RETRYABLE? | |
| `completed_at` · `source_retired_at` | TRANSFER COMPLETE? · SOURCE RETIRED? | |

**No health payload. No Apple token. No email address and no `sub` — only
a digest, and only until the handoff terminates.** No `last_error_class`:
a failed transfer rolls back to `open`, and a value written by a
transaction that rolls back is a value that does not exist.

---

## 10 · THE SERVER OWNS THE CRITICAL WINDOW

The dangerous window is: **the session switches A → B, A still exists,
and the client no longer holds any credential that can name A.**

The staged design removes the dependency entirely:

- the receipt is written **while A is still authenticated**;
- the completion is performed **as B**, whose credential is permanent and
  legitimately hers;
- so a retry needs **no** persisted secret, at any point.

**Not done, and each is a rule rather than an oversight:** no service-role
credential in the client; no anonymous access token in `UserDefaults`; no
access token in SwiftData; **no access token in the Keychain either** —
the subject-binding design (§11) means there is no smaller architecture
that needs one, so the Keychain exemption the brief allows is not taken.

---

## 11 · AUTHORIZATION — THE HARDEST PART

**An endpoint that accepts `source_uid` + `destination_uid` and trusts
the caller is an account-takeover primitive.** This design accepts
neither as an authorization input.

```
while authenticated as A (and ONLY if A.is_anonymous):
    BEGIN  →  receipt { source = auth.uid(), subject_hash = sha256(provider:subject) }
                        ▲ never a parameter    ▲ the destination A is about to reach

… Apple / email sign-in …

authenticated as B (and ONLY if B is permanent):
    COMPLETE → the server computes the subject hashes B DEMONSTRABLY OWNS
               from B's own auth.identities / auth.users rows, and acts
               only on open receipts whose pre-commitment is in that set.
```

> ▎ **THE PROOF IS NOT A BEARER CREDENTIAL.** It cannot be stolen and
> ▎ replayed, because redeeming it requires *being* the account that owns
> ▎ the pre-committed subject. Nothing secret is persisted on the device —
> ▎ the client keeps only the two uids it already keeps.

**A client that lies at BEGIN produces a receipt nobody, including
itself, can ever complete. A lie only locks the liar out.** That property
is what makes it safe for the client to read the `sub` claim locally
rather than making the server verify an Apple id token against Apple's
JWKS.

### The adversarial matrix

| attack | outcome | why |
|---|---|---|
| **B names a random anonymous A** | **REFUSED** | there is no argument that names a source for authorization; the only filter is *"a receipt A itself opened, pre-committed to a subject B owns"* |
| B names a permanent C | REFUSED | `source_user_id` must be `is_anonymous`, re-checked **at use**, and asserted again on the `DELETE` itself |
| stolen receipt id | **not an input** — the function takes no receipt id | |
| replayed after completion | no-op | `state = 'completed'` is terminal and outside the `open` filter |
| expired receipt | no-op | `expires_at > now()` |
| receipt for A used by C | REFUSED | C's subject set does not contain A's pre-commitment |
| completed on an unrelated account | REFUSED | same |
| **an anonymous caller tries to absorb** | REFUSED | a destination must be permanent — checked before any lookup |
| source deleted before completion | no-op | the FK nulled `source_user_id`; the row is filtered out |
| destination deleted before completion | no-op | the receipt cascaded away |
| source became permanent by another path | **skipped** | re-checked at use, not only at BEGIN |
| tampered `p_source_user_id` | **narrows only** | it can only restrict the already-authorized set |
| tampered `p_mode` | affects only the caller's own data | `move` vs `retire`; neither can name a victim |
| BEGIN twice | one row | partial unique index `(source_user_id, subject_hash) where state = 'open'` |
| **spamming receipts for one subject** | capped at 10 | bounds the residual below |

**The residual, named.** An attacker who ALREADY KNOWS a victim's Apple
`sub` for this app could pre-commit their own anonymous account to it, and
the victim's next sign-in would absorb the attacker's rows. That is data
INJECTION, not exfiltration — nothing of the victim's leaves — and the
`sub` is per-developer-team, is not derivable from an email address, and
lives only in `auth.identities.identity_data`, which no client can read.
It is bounded by the `is_anonymous` gate on the source and by the
ten-receipt cap. **A security argument that names no residual is not a
security argument.**

**Every assertion above is `NO UNAUTHORIZED ROW CHANGED OWNER`, not an
error type.** They are written as the migration's own preconditions
rather than as tests, because there is no local Postgres in this session
to run them against (§34).

---

## 12 · BEGIN BEFORE THE SESSION SWITCH — ATTACKED

The brief asks for this shape to be evaluated and attacked rather than
assumed. It survives, with one change: **BEGIN happens only once an Apple
credential (or a typed email) is in hand**, so the subject is known and a
cancelled sheet writes nothing.

| killed at | receipt | uid on relaunch | converges? |
|---|---|---|---|
| before BEGIN | none | A | nothing was owed |
| after BEGIN | `open` | A — the session never moved | **yes**: she is still A, her record is untouched, and the next sign-in re-uses the same receipt (idempotent) |
| after the Apple credential, before the link | `open` | A | yes |
| after the link attempt, no answer | `open` | A, possibly now owning the identity | yes — `bootstrap` reads the user back |
| **after the destination session arrives** | `open` | **B** | **yes — COMPLETE at the next launch. This is the case that is impossible today.** |
| before the server transfer | `open` | B | yes |
| **during the server transfer** | `open` | B | yes — one transaction, so it rolled back whole |
| after rows transfer, before retirement | **impossible** — same transaction | | |
| after source retirement | `completed` | B | done |
| before local convergence | `completed` | B | the local receipt still owes the carry |
| during local convergence | `completed` | B | the carry only fetches rows keyed to A |
| after local convergence | `completed` | B | done |

**The proof is not a bearer credential with an unbounded lifetime — it is
not a bearer credential at all**, which is why `expires_at` can be thirty
days without a security cost. Expiry here is garbage collection; the long
window is what lets an offline stretch, a crash or a reinstall still
complete rather than orphan.

---

## 13 · ONE TRANSACTION, SO THERE IS NO STATE MACHINE

Rows, `storage.objects` and `auth.users` are all ordinary DML in the same
Postgres transaction. A handoff either happens or does not.

**So the ladder the brief sketches — PREPARED → ROWS_TRANSFERRED →
SOURCE_RETIRED → COMPLETE — is not built, because no failure boundary
requires it.** Two states, the second terminal, and a transient failure
rolls back to the first, which is already the retry state.

*(Storage is deleted inside the same transaction, before `auth.users`,
because `storage.objects` has NO foreign key to `auth.users` — verified
from the live catalog — so once the auth row is gone nothing can name
those objects again. It is duplicated from Package A1 deliberately: the
handoff must be correct whether or not A1 has been applied.)*

---

## 14 · THE LOCAL HANDOFF — ONE INVENTORY, ONE ORCHESTRATOR

`PlankApp/Sync/LocalHandoffInventory.swift` is the one list; the rules
table is §2. `AppSync.applyIsolationIfNeeded(for:)` and the classified
branch in `onAuthChanged` are the one orchestrator. **No re-key call was
added to a view**, and the sweep is no longer three lines inside an async
body — `36` §2's rule: *a rule inside a body cannot be tested, which is
why nobody notices it is a rule.*

`LocalHandoffInventory.footprint(of:in:)` counts every customer-owned
local family for one uid. It has two callers that need the same answer:
the tests, which assert `footprint(source) == 0` **and**
`footprint(destination) > 0` — because a test that only checks the first
cannot tell MOVED from VANISHED — and `SourceRetirementSafety`, §23.

---

## 15 · JENI MEMORY, CHAT AND MANUAL MOVEMENT

**This is not memory sync, and the two questions are kept apart:**

> **ACCOUNT HANDOFF** — does a local-only record created under anonymous
> A follow her into permanent B, on this phone?
> **CROSS-DEVICE SYNC** — does it reach her other phone?
>
> **A local record may need to follow an identity transition without ever
> becoming cloud-synced.**

| family | follows an ADOPT? | follows a SWITCH? | syncs? |
|---|---|---|---|
| `JeniMemoryRecord` | **YES**, id untouched | **no** | **no, and nothing here changes that** |
| `ChatMessageRecord` | **YES**, id untouched | **no** | no (`coach_messages` has zero client writers) |
| `move.manual.v1` | **YES** — device-scoped, so it follows the person by construction | **no — swept** | no |

The id is untouched for the two `@Model` families because **no server row
exists**, so the fresh-id invariant has nothing to satisfy; the id is a
local handle and `forget` addresses it. This is the treatment
`BodyScanRecord` already had, for the same reason.

---

## 16 · PROGRAM AND REGIMEN CONFLICTS

These are not append-only ledgers. Their heads are CURRENT-STATE claims,
and two current-state claims cannot both be current.

| fact | rule | why | production today |
|---|---|---|---|
| **live program plan** | **DESTINATION WINS**; A's arrives archived | §17 | 23 permanent accounts have a live plan; 124 anonymous accounts have a plan |
| **live medication regimen** | **DESTINATION WINS**; A's arrives ENDED (`end_reason = 'ended'`) | `RegimenService.activeMedicationPlan` resolves two heads by `createdAt` DESC, which on a hydrated row is the hydration instant — `31`'s trap | **0 permanent accounts have a regimen**; 19 anonymous accounts do |
| **care-team regimen** | **REFUSED** — removed, never carried | an authority granted to one identity is not another's; and the RLS proves the client could never have authored it under B | **9 rows, all under anonymous accounts** |
| **prescribed program fact** | **REFUSED** — removed | E1's law: iOS writes `prescribed` NEVER | **0 rows — the cheapest moment this rule will ever be made** |
| **preferred / recommended / defaulted facts** | carried, chains follow | hers | 0 rows |
| **goal, pace** | carried on the `UserRecord` **only when the destination has no profile row** | the account's own body facts are authoritative (`40`) | 780 permanent accounts have a profile |

**A refused current-state fact is preserved as history where the model
supports it honestly** — a regimen chain has `endedAt` / `endReason`, and
a plan has `phase` / `archivedAt`, so both survive as history. **Where the
model does not support it — a care-team regimen has no honest home under
an account that clinic never met — the row is refused outright rather
than given a synthetic resolution.** No authority is ever downgraded to
make a row carryable.

---

## 17 · PLAN IDENTITY

**A has an active plan and B has an active plan. What happens?**

`31` built `reconcileLivePlans` to keep the EARLIEST `startDate` live,
which was right for the case it was built for: an interim junk plan
minted at a forced re-enrollment always has `startDate = today`, so
earliest-wins archives it.

**The two rules differ in exactly one shape, and it is a real one: an
anonymous period that began BEFORE the account's own plan.** Earliest-wins
then archives the journey she has actually been living in and re-dates her
program from a plan she built while logged out.

So on a handoff the rule is **DESTINATION WINS**, applied before
`reconcileLivePlans` runs, which leaves that function a no-op. A's plan
is not discarded and no goal is silently overwritten — **it arrives
`abandoned` + `archivedAt`, which is how this model already carries a
superseded enrollment.** One live plan, always.

**ASK was considered and not taken.** It is acceptable for a rare
ambiguous collision, and this one is not ambiguous: the account she chose
to keep is the account whose plan she is living in. Adding a modal to a
sign-in for 23 permanent accounts' worth of exposure would be a question
where a rule will do. `testTheDestinationsLivePlanSurvivesAnOlderAnonymousOne`
pins it. **Silent fabrication is not on the table anywhere.**

---

## 18 · CONSENT DOES NOT TRANSFER, AND NOW IT DOES NOT LINGER

The consent authority, traced in `38` §13 and unchanged: the clinic-facing
scope is **`visit_packet_view`**, created and revoked SERVER-side by
`care_accept_invitation` / `care_revoke_consent`, revocable from any
device. The local `ConsentGrantRecord` writes **`visit_packet_sharing`**,
which gates nothing and is read by its own toggle.

| object | transfers? | why |
|---|---|---|
| `ConsentGrantRecord` (local) | **NO — and it is now REMOVED, not stranded** | a grant made as one identity is not another's answer |
| `consent_grants` (server) | **NO** | cascades with the retired account |
| `visit_packet_view` | **NO** | it is a server fact about a relationship between a clinic and an identity |
| `patient_invitations.accepted_by` | **NO** | §40 §11's `SET NULL` decision, unchanged |
| `care_relationships` · `visit_packets` · `org_members` · `protocol_assignments` · `correction_requests` | **NO** | all cascade with the source |

> ▎ **CONSENT DOES NOT BECOME BROADER BECAUSE ACCOUNTS MERGED. UNKNOWN
> ▎ CONSENT IS NEVER PERMISSION.**

Production: 31 consent grants, 30 org-scoped; **10 care relationships,
all with anonymous patients.** So the population that goes through a
handoff is exactly the population that holds clinic consent — which is
why the refusal had to become a removal.

---

## 19 · THE DELETION LEDGER ACROSS A HANDOFF

`deletions.v1.<uid>` is keyed per uid. Per operation:

| operation | A's ledger | B's ledger | why |
|---|---|---|---|
| **UPGRADE** | untouched — the uid did not change | n/a | nothing moved, so nothing is owed |
| **ADOPT** | **cleared, and only after the carry COMMITS** | untouched | every id it protected was re-keyed or retired, so it can never match again |
| **SWITCH** | **kept** | kept | sign-out preserves the rows it protects, and so must a switch |
| **account deletion** | cleared | cleared | it is derived from her deletions and is hers |

**DELETE BEATS TRANSFER, and a deletion is scoped to the account that
made it.** A tombstone A wrote is an assertion about A's rows; it must
never be asserted about B's rows, which she never deleted.
`testTheDeletionLedgerNeverCrossesIntoTheDestination` pins both halves.

**A deleted A record can never become a live B record**, because a
deleted local row is not in the carry set and its server row is already
gone — and if the delete never reached the server, A's account is retired
whole.

**The transaction-boundary bug this pass fixed:** `DeletionLedger.clear`
is a `UserDefaults` write and is therefore **not** part of the SwiftData
transaction. It used to run whether or not the carry committed, so a
failed carry destroyed a ledger whose ids were still live. It now runs
only on a commit.

---

## 20 · CRASH MATRIX — THE SHIPPING CLIENT

| killed after | auth uid | server owner | source exists? | dest exists? | local owner | receipt | relaunch |
|---|---|---|---|---|---|---|---|
| the Apple credential | A | A | yes | yes | A | none | nothing owed |
| the link request, no answer | A | A | yes | yes | A | none | `bootstrap` reads the user back; if GoTrue committed, `authMethod` is now `.apple` |
| the link succeeded | A | A | yes | yes | A | none | nothing to resume |
| **the destination session arrived** | **B** | A | yes | yes | **A** | **written at the switch** | `onLaunch` → `resumePendingMergeIfNeeded` carries |
| the retirement was refused / unreachable | B | A | **yes — the residue** | yes | A | present | the carry converges; **A is not retired** (§23) |
| A retired, carry not started | B | — | no | yes | A | present | the carry converges |
| **mid-carry** | B | — | no | yes | mixed | **present, because the carry did not COMMIT** | the carry re-runs; it only fetches rows keyed to A |
| carry committed, push not sent | B | — | no | yes | **B** | cleared | `retryPendingUpserts` at the next launch |
| **a sign-out in any of the above** | anonymous C | — | — | yes | A | **PRESENT — this is finding 4** | the carry still converges |
| receipt cleared | B | B | no | yes | B | none | done |

**Every non-terminal state converges, and none needs a founder.** The one
row that does not fully converge is *"the retirement was refused"* — the
source's `auth.users` row and its server data survive. That is the hole
the staged migration closes, and it is the only one.

---

## 21 · RETRY MATRIX

Every action run twice, expected: the same final state.

| action | twice | result |
|---|---|---|
| the local carry | ✔ | **no duplicate weight, dose, symptom, regimen, plan or profile** — it only fetches rows keyed to the OLD uid, so the second pass is a no-op. `testReplayingTheHandoffDoesNotDuplicateHerRecord` |
| the isolation sweep | ✔ | idempotent by construction (removals) |
| the retirement | ✔ | `DELETE … WHERE id = auth.uid()` finds nothing the second time |
| **BEGIN** (staged) | ✔ | one row — partial unique index; the second call only extends `expires_at` |
| **COMPLETE** (staged) | ✔ | `state = 'completed'` is terminal and outside the `open` filter |
| **TRANSFER** (staged) | ✔ | every statement is `where user_id = source`, which matches nothing after the first |
| **RETIRE** (staged) | ✔ | the source is gone; the receipt is filtered out |

**No second receipt can represent the same transition** while the first
is open, and a completed one cannot be re-opened. A genuinely new
transition — she signs out, uses the app anonymously again, signs back in
— mints a new anonymous uid and therefore a new receipt, which is
correct.

---

## 22 · WHAT THE TESTS PROVE

`plankAITests/HandoffContractTests.swift`, **22 tests.**

| the brief's contract | test | status |
|---|---|---|
| anonymous → existing account with **food · dose · symptom · regimen · memory · movement** | `testHerOwnRegimenDosesAndSymptomsStillFollowTheAccount` + `testEveryFamilyThatCanCollideIsGuardedSoTheHandoffCommits` (`footprint(A) == 0`, `footprint(B) > 0`) | **GREEN** |
| **named → named never merges** | `testOneAccountsRecordIsNeverMergedIntoAnother` · `testSwitchingBetweenTwoAccountsLeavesBothRecordsIntact` · `testASwitchClearsHerDeviceScopedRecordAndAnAdoptKeepsIt` | **GREEN** |
| **same-uid upgrade does not merge** | `testASameUidUpgradeCarriesNothingAndMintsNoId` | **GREEN** |
| failed source retirement remains recoverable | §23 + `testTheHandoffReceiptSurvivesASignOut` | **GREEN for the local half; the server half is the staged migration** |
| **crash after the destination session remains recoverable** | `testTheHandoffReceiptSurvivesASignOut` · `testAConfirmedDeletionIsStillOwedAfterASignOut` | **GREEN** |
| **replay does not duplicate** | `testReplayingTheHandoffDoesNotDuplicateHerRecord` | **GREEN** |
| malicious B cannot absorb random A | §11 — the migration's own preconditions | **DESIGNED, NOT RUNNABLE HERE** (§34) |
| **delete beats transfer** | `testTheDeletionLedgerNeverCrossesIntoTheDestination` | **GREEN** |
| **two live plans do not emerge** | `testTheDestinationsLivePlanSurvivesAnOlderAnonymousOne` | **GREEN** |
| **consent does not widen** | `testConsentIsNeverCarriedAcrossAnIdentityTransition` | **GREEN** |
| the three operations are named, never inferred | `testTheThreeOperationsAreNamedAndNeverInferredFromAUidChange` · `testAnUnprovenSourceIsNeverTreatedAsAnonymous` | **GREEN** |
| a colliding day does not discard the whole carry | `testADayTheDestinationAlreadyLived…` + `testTheDestinationsOwnDayWinsAndContentIsNeverCompared` | **GREEN** |
| a prescription never follows the person | `testACareTeamRegimenNeverBecomes…` · `testAPrescribedProgramFactNeverFollowsThePerson` | **GREEN** |
| one live medication regimen | `testTheDestinationsLiveRegimenStaysTheOnlyPresentTense` | **GREEN** |
| the receipt goes with the account it names | `testAnAccountDeletionTakesItsHandoffReceiptWithIt` | **GREEN** |
| **an account this device is not carrying is never retired** | `testAnAccountThisDeviceHoldsNoRowsForIsNeverRetired` | **GREEN** |
| a named account is never retired | `testANamedAccountIsStillNeverRetired` | **GREEN** |

### RED, MEASURED

With ten cores at their pre-session behaviour — the classifier reverted
to the forbidden inference, `isolatesTheOutgoingAccount` always false,
`mayRetire` always true, no day-progress guard, no destination-live-plan
rule, no destination-live-regimen rule, `carriesForeignAuthority` always
false, the refused profile and grant left on disk,
`sync.pendingMergeV1` back in the sweep, the deletion intent discharged
unconditionally, the carry's `save()` back to `try?`, and the receipt no
longer following a deleted account:

```
Executed 22 tests, with 38 failures (0 unexpected)
** TEST FAILED **     exit 65
```

**15 of 22 methods red, 38 assertion failures.** The seven that passed,
and why each is honest:

| passed under the stub | why |
|---|---|
| `testASameUidUpgradeCarriesNothingAndMintsNoId` | **a control** — it asserts the OLD behaviour is preserved, and the stub IS the old behaviour |
| `testADayTheDestinationAlreadyLivedDoesNotDiscardTheWholeHandoff` | **a control, and its green is the finding.** SwiftData does not throw on a duplicate `@Attribute(.unique)` key — it silently collapses the two rows — so a footprint test cannot tell a resolved collision from a correct carry. That is exactly why this was invisible. The determinism is asserted next door, on the pure mutation, where it DOES go red |
| `testHerOwnRegimenDosesAndSymptomsStillFollowTheAccount` | **a control beside the two refusals** — with nothing refused, everything carries. It exists to prove the refusals do not over-refuse |
| `testConsentIsNeverCarriedAcrossAnIdentityTransition` | **a refusal test, and a stub that refuses everything satisfies it.** It cannot tell *"refused rightly"* from *"cannot act at all"* — **the EIGHTH session running** |
| `testTheDeletionLedgerNeverCrossesIntoTheDestination` | refusal-shaped, same |
| `testANamedAccountIsStillNeverRetired` | **`40`'s shipped gate.** This file does not claim credit for it; it is the regression pin |
| `testReplayingTheHandoffDoesNotDuplicateHerRecord` | idempotency is true by construction — the carry only fetches rows keyed to the OLD uid — so it stays green. It is the pin that this pass's five new refusals did not break it |

### What these tests CANNOT prove, stated

1. **That `begin_account_handoff` / `complete_account_handoff` behave as
   designed against a live Postgres.** The migration is written and NOT
   applied; there is no local Postgres and no running Docker in this
   session, so it is not even syntax-checked against a server. Every
   table, column and builtin it names was verified read-only from the
   live catalog first (§34), which is the difference between an unverified
   file and a guessed one — **and it is not the same as a green run.**
2. **That the retirement RPC removed A's rows in production.** Unchanged
   from `40`. Proven from the deployed function's own text and the RPC's
   `auth.uid()` scope, not from a call.
3. **That `linkIdentityWithIdToken` succeeds against this project's
   GoTrue.** Unchanged from `39` and `40`. Still the founder's one-line
   device check.
4. **That a deletion propagates to a second device.** It still does not
   (`38` §21.1). Out of scope, unchanged.

---

## 23 · WHAT MAKES THE SOURCE SAFE TO DELETE

Two conditions, and the second is new:

1. **The outgoing session was provably anonymous and the incoming session
   names a different account** — `40`'s `AnonymousRetirementPolicy`,
   unchanged, with the anonymity gate checked first so the function is
   structurally incapable of nominating a named account.
2. **This device is carrying the source's record** —
   `SourceRetirementSafety.mayRetire(sourceLocalRowCount:)`, new.

> ▎ **A HANDOFF MAY ONLY RETIRE AN ACCOUNT WHOSE RECORD THIS DEVICE IS
> ▎ ACTUALLY CARRYING.**

The trade is explicit and cheap to be wrong about in the safe direction:
an anonymous account with zero local rows is either genuinely empty — in
which case retiring it removes nothing, and leaving it costs an
`auth.users` row with no data, **the shape 1,242 of the 3,425 anonymous
accounts already have** — or it is a record this device has not seen, in
which case retiring it is data loss. From here the two are
indistinguishable. **Never delete what you are not carrying; accept an
empty identity row.**

**When the retirement fails, it is retryable server-side under the staged
migration and nowhere else.** The client cannot retry, will not persist a
token to make it possible, and this document does not pretend otherwise.

---

## 24 · SERVER FAMILIES THAT CANNOT REKEY — INVENTORIED FIRST

Read from `pg_constraint` on 2026-08-14 (`41_probes/P1`), because **the
base schema is not in this repository** — `supabase/migrations` starts at
2026-06-23 and the customer tables predate it.

| table | blocking constraint | behaviour |
|---|---|---|
| **`public.users`** | `PRIMARY KEY (id)` and `id` **IS** the uid | **cannot move.** Destination wins; the source's row is deleted with the account |
| **`day_progress`** | `PRIMARY KEY (user_id, program_day)` | delete the colliding source row, then move |
| **`exercise_calibrations`** | `PRIMARY KEY (user_id, exercise_type)` | same |
| **`day_reflections`** | `UNIQUE (user_id, day_key)` | same |
| **`org_members`** | `PRIMARY KEY (org_id, user_id)` | **not transferred** — clinic membership is not portable |
| `program_day_checks` | `UNIQUE (user_id, program_plan_id, program_day, item_key)` | **cannot collide** — the plan id is rewritten to a fresh uuid |
| `patient_invitations` | `UNIQUE (code_hash)` | not transferred |
| `dose_events` · `observations` · `weekly_reads` | `PRIMARY KEY (id)`, id carries the uid | prefix swap; destination wins a rewritten-id collision |
| everything else | `PRIMARY KEY (id)` only | plain ownership rewrite, **id preserved** |
| `care_weekly_summaries` | `PRIMARY KEY (id)`, **NO user FK** (re-confirmed) | untouched — §12 of `40` is still unanswered and this pass does not answer it |
| `care_audit_events` | `PRIMARY KEY (id)`, no FK at all | untouched — `40` §11's RETAIN decision |
| `food_vision_telemetry` · `jeni_chat_telemetry` | FK `on delete set null` | untouched — a stated choice (`38` §1.2) |

**Nothing was discovered by trial and error.** Each column the transfer
function names was read from `information_schema.columns` first
(`41_probes/P5`), and each builtin it calls was confirmed present in
`pg_catalog` on this server (`41_probes/P6`, Postgres **17.6**).

---

## 25 · THE PROFILE IS NOT AN APPEND-ONLY ROW

`public.users` / `UserRecord`, field by field:

| class | fields | merge semantics |
|---|---|---|
| **IDENTITY** | `id` | **the PK IS the uid — it cannot move** |
| **ONBOARDING HISTORY** | goal · experience · motivation · barriers · prior attempts · focus area | **B WINS**; A's are used only to fill a total absence |
| **CURRENT BODY FACT** | height · current weight · gender | **B WINS** — they drive `TargetsService`, and a device's numbers must never overwrite an account's |
| **GOAL** | goal weight · goal date | **B WINS** — `29` spent a whole pass removing the shape where a goal came from somewhere other than her |
| **PROGRAM FACT** | activity level · commitment days · pace | **B WINS** |
| **SAFETY FACT** | pregnancy · eating-pattern screen · pace cap · numeric suppression | **B WINS, AND NOTHING IS INFERRED.** `35`'s law stands: a safety answer is never derived from a proxy, and **unknown is not permission** |
| **COHORT FACT** | GLP-1 status · phase · medication status · hormonal stage · sleep · stress · food relationship | **B WINS** |
| **PREFERENCE** | notification hour · units | device-level; not identity-scoped by existing decision |
| **DERIVED** | — | never merged |
| **DEPRECATED** | `program_status` · `program_intensity_tier` · `program_goal_date` | **zero writers, zero readers** (`35`); not merged, and still awaiting deprecation |

**The rule in one line:** the destination account's profile is
authoritative in every class; the source's row is used **only** when the
destination has none, and is otherwise **removed** — which is finding 6.

---

## 26 · NO HISTORICAL ORPHAN REPAIR

**Nothing was touched, joined, matched or inferred.** No timestamp
proximity, no device, no Apple-event correlation, no profile similarity,
no body-metric or food join. The four populations `40` named are
unchanged and are still named separately.

Historical cleanup remains governed by
`scripts/reap_abandoned_anon_accounts.sql`, unchanged and unrun, and by
the honest current result: **at 120 days, ZERO.** The project's oldest
`auth.users` row is **106 days** old, re-measured this session.

`scripts/cleanup_orphaned_anon_users.sql` **must never be run.**

---

## 27 · PACKAGE A FROM `40` — REVIEWED, UNCHANGED

**Does THE HANDOFF change any assumption behind them? No.** All three are
byte-identical and no migration was churned for style.

| | assumption | still true? |
|---|---|---|
| **A1** storage purge | the deployed `delete_user_account()` has no storage delete | **YES — re-verified this session**: the deployed function is 419 characters and `ilike '%storage.objects%'` matches **zero** |
| | `food-photos` does not exist | **YES** — one bucket (`body-scans`), `storage.objects` **0 rows** |
| **A2** `accepted_by` → `SET NULL` | 10 accepted rows, 0 orphans, all also in `care_relationships` | **YES** — and now sharper: all 10 patients are **anonymous**, so they are exactly the population a handoff retires |
| **A3** three `comment on table` | three defensible retentions, recorded as omissions | **YES** |

**A1 becomes slightly more urgent, not less.** Package E's
`complete_account_handoff` deletes the source's storage objects itself,
so the handoff does not depend on A1 — but every OTHER deletion path
still does, and the bucket is one `create bucket` away from mattering.

---

## 28 · THE APPLE TOKEN PACKAGE STAYS SEPARATE

**B1/B2 are untouched and no `.p8`-dependent behaviour was implemented.**
Apple's token-revocation contract is about an IDENTITY PROVIDER's grant;
the handoff is about OWNERSHIP OF ROWS. They share a screen and nothing
else.

**Account handoff works before the `.p8` exists**, and Package E requires
no secret of any kind. The two are not sequenced against each other in
either direction.

---

## 29 · THE MIGRATION — MINIMUM, AND WHY EACH PART IS THERE

`docs/app_v25/41_packages/E1_account_handoffs.sql`. **NOT written to
`supabase/migrations`. NOT applied.**

| component | why it is the minimum |
|---|---|
| `public.account_handoffs` | the durable fact. Nine columns; every one answers a question in §9 |
| the partial unique index | makes BEGIN idempotent — a double tap is one row |
| `public.begin_account_handoff(provider, subject_hash)` | writes the receipt from `auth.uid()`, **refuses a permanent caller** |
| `public.complete_account_handoff(source?, mode?)` | takes **no identity**; computes the caller's own subjects; moves and retires in one transaction |
| `private.transfer_account_rows(src, dst)` | the per-family rules. **In `private`, execute revoked from every client role**, because a function taking (source, destination) IS the admin merge endpoint the brief forbids |

**Requirements, each met:** RLS enabled with **no policies and no grants**
so the table is unreachable, not merely unreadable · `SECURITY DEFINER`
only where the function must read `auth.identities` or write `auth.users`
· `search_path = ''` on all three, with `pg_catalog` qualification where
a DEFAULT is resolved at CREATE time · idempotent at every entry point ·
**old-client safe** (§30) · rollback is four `drop` statements and nothing
depends on them · **no production mutation in this session.**

**It is impossible to invoke a source→destination transfer for arbitrary
users**: the only mover is `private`, execute is revoked, and the public
entry point derives both ends itself.

---

## 30 · OLD-CLIENT COMPATIBILITY

| | **BUILD 30** (live) | **BUILD 31** (this session) | **a later client carrying the protocol** |
|---|---|---|---|
| trigger a handoff? | **NO** — calls no function by these names | **NO** — deliberately | yes, and only from an anonymous session |
| read a receipt? | **NO** — no grant, no policy, RLS on | NO | NO — it never reads one |
| write a receipt? | **NO** | NO | via BEGIN only |
| move another user's data? | **NO** | NO | **NO** — structurally impossible |
| break login? | **NO** — nothing in the auth path changed | NO | falls back to today on a 404 |
| lose local data? | **NO** | NO | NO |

**The server contract is additive in the strictest sense: invisible to
every client that exists.** And a client carrying the protocol *before*
the migration is applied gets `PGRST202` from BEGIN, catches it, and
behaves exactly as today — the v24 / E1 precedent, *"the client defers
gracefully."*

---

## 31 · DEPLOY ORDER, DERIVED

| # | step | old client safe? | new client safe? | rollback | **what if ONLY this step ships?** |
|---|---|---|---|---|---|
| **1** | **apply E1** | **YES — invisible** | YES | four `drop`s | **nothing happens.** No client calls it. This is the safest possible first step and it is why the schema goes first |
| **2** | **verify in production, read-only** | — | — | — | the contract is proven before a line of client code is written against it |
| **3** | **ship the client that calls BEGIN + COMPLETE** | YES | YES | ship again | if step 1 were skipped: BEGIN 404s, the client behaves exactly as today. **Degrades, never breaks** |
| **4** | adoption window | — | — | — | the installed base converges; nothing is required of anyone |
| **5** | consider retiring the client-side best-effort retirement | — | — | keep it | **it should probably never be removed** — it is the only thing that works when the network dies between BEGIN and COMPLETE |

**Why the client protocol is NOT in this build, stated plainly.** The
client mints fresh record ids *because* the cloud row still belongs to the
old uid. After a server move it must not, or the same record exists twice.
So the id policy depends on whether the server handoff succeeded, which
depends on a contract that has never been executed. Shipping that against
an unverified function is `38` §11's error — *"proven by code that was
never applied"* — with a customer's health record as the stake.

**Step 2, exactly:** the table exists, both public functions exist,
`has_function_privilege('authenticated', 'public.begin_account_handoff(text,text)', 'EXECUTE')`
is **true**, and
`has_function_privilege('authenticated', 'private.transfer_account_rows(uuid,uuid)', 'EXECUTE')`
is **false**.

---

## 32 · CAN THE LEGACY FALLBACK DIE? NOT YET, AND HERE IS THE CLASSIFICATION

`39`'s fallback — *any* link error falls through to `signInWithIdToken` —
is still the right shape, because **a customer who cannot sign in is a
worse failure than an orphaned uid**, and `40` proved the error alone
cannot decide anything:

```go
if identity != nil {
    if identity.UserID == targetUser.ID {
        return … ErrorCodeIdentityAlreadyExists, "Identity is already linked"
    }
    return … ErrorCodeIdentityAlreadyExists, "Identity is already linked to another user"
}
```

**Two opposite situations, one stable error code, differing only by an
English sentence.** Parsing that sentence would be exactly the
localized-string dependency the brief forbids, and it would still not
cover the 5xx-then-successful-sign-in case, which abandons the uid with
no error to read at all.

> ▎ **THE ERROR IS NOT THE SIGNAL. THE OUTCOME IS — and once E1 is
> ▎ applied, the DURABLE HANDOFF STATE is.**

So the target behaviour is: link succeeds ⇒ same-uid upgrade · identity
belongs elsewhere ⇒ the outcome says so and the receipt makes the
collision handoff durable · transient failure ⇒ retry or stay anonymous.
The first and third already hold. **The fallback stands until step 4.**

---

## 33 · ACCOUNT SWITCH UI — AUDITED, NOT REDESIGNED

**Zero characters changed.** The three surfaces from which named → named
is reachable are the re-auth sheet, the wall's recovery sheet and the
paywall's, and all three are `SignInPromptView(mode: .signIn)` behind
*"signed in before? sign in"* or a re-auth prompt. The customer intent
they express is **"continue with my existing account"**, which is what
happens.

**The reason no copy changed is not that the copy is perfect — it is that
the semantics stopped being destructive.** Before this build the same
button could carry account A's record into account B; it cannot now, and
after the isolation sweep it cannot carry A's words either. A warning
about a consequence that no longer exists would be theatre. If a
deliberate "attach this sign-in method to this account" feature is ever
built, it gets its own control and its own words.

---

## 34 · PRODUCTION READS — SIX PROBES, EACH PROVEN READ-ONLY FIRST

`docs/app_v25/41_probes/`. Comments were stripped **before** the check so
a keyword in prose could not mask a keyword in code.

| file | statements | first token | `insert`/`update`/`delete`/`upsert`/`merge` | DDL/DCL | what it answered |
|---|---|---|---|---|---|
| `P1_ownership_constraints.sql` | 1 | `select` | 0 · 0 · 0 · 0 · 0 | 0 | **71** constraint rows — **the four composite keys** |
| `P2_rls_update_shape.sql` | 1 | `select` | 0 · 0 · 0 · 0 · 0 | 0 | **65** policy rows — **USING + WITH CHECK on every UPDATE** |
| `P3_handoff_population.sql` | 1 | `with` | 0 · 0 · 0 · 0 · 0 | 0 | 44 label rows — the collision population |
| `P4_deployed_contract.sql` | 1 | `with` | 0 · 0 · 0 · 0 · 0 | 0 | A1 unapplied · no handoff table exists · buckets |
| `P5_transfer_columns.sql` | 1 | `select` | 0 · 0 · 0 · 0 · 0 | 0 | 49 column rows — every column E1 names |
| `P6_server_capabilities.sql` | 1 | `select` | 0 · 0 · 0 · 0 · 0 | 0 | Postgres **17.6**; `sha256`, `gen_random_uuid`, `convert_to` all in `pg_catalog` |

Run through `supabase db query --linked` against `mtecqvykyeueumdynatd`.
**No row was written. No RPC was called. No migration, Edge Function,
reaper or Apple configuration was touched. No customer identity, email,
name, health value or jsonb payload was selected anywhere** — every
projected column is a catalog name, a policy expression, a text label or
a bigint count.

### What production says today

| measure | value |
|---|---|
| anonymous accounts · permanent accounts | **3,425 · 867** |
| identities (apple · email) · accounts with two identities | 867 (559 · 308) · **0** |
| anonymous accounts holding: profile · weigh-in · plate | 2,162 · 2,171 · 65 |
| …regimen · dose · symptom · plan | **19** · 2 · 9 · 124 |
| …day progress · day reflection · session log · consent | **43** · 1 · 43 · **11** |
| permanent accounts holding: profile · **live plan** · regimen | 780 · **23** · **0** |
| …**day progress** · day reflection · program fact | **64** · 3 · 0 |
| **regimen rows total · not-`self` authority · org-scoped** | 164 · **9** · **9** |
| **…and how many of those nine are under anonymous accounts** | **9 of 9** |
| program-fact rows total · `prescribed` | **0** · **0** |
| care relationships with an anonymous patient | **10 of 10** |
| `day_progress` rows · `day_reflections` · `exercise_calibrations` | 282 · 5 · 0 |
| `food_log_items` · `food_corrections` · `care_weekly_summaries` | 0 · 0 · **0** |
| `storage.objects` · buckets · `food-photos` exists? | **0** · 1 · **NO** |
| deployed `delete_user_account` mentions `storage.objects` | **0 — A1 still unapplied** |
| tables named like a handoff receipt | **0** |
| project's oldest `auth.users` row | **106 days** |

---

## 35 · RELEASE PROOF

Every command run **serially**, unpiped, `$?` captured directly.

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/HandoffContractTests` | 22 | **22** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` (full app suite) | 1330 | **1330** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.1 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is a SUCCEEDED line.** App suite **1308 → 1330, exactly +22**,
which is `HandoffContractTests` and nothing else: **no existing test
changed and none needed to.**

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **86 MB, 123,579 strings** — size
and total stated first, because *a zero from a file that does not exist
is the `Executed 0 tests` trap in different clothes* (`35`). The first
lookup this session returned NOT FOUND and the check **refused to print
zeros**, which is the guard working.

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `debug-delete-account` | **0** |
| `sync.pendingMergeV1` | **1** — the receipt that now survives a sweep |
| `move.manual.v1` | **1** — the key the switch now sweeps |
| `account.deletion.intent.v1` · `apple.user.identifier.v1` | **1 · 1** |
| `rest/v1/rpc/delete_user_account` | **1** — the retirement still ships |
| `sign-in and security` | **1** — Apple's fallback step still ships |
| `AccountOperation` · `LocalHandoffInventory` · `SourceRetirementSafety` · `IdentityMerge` (`nm`) | **38 · 41 · 2 · 105** |

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
| `Packages/PlankFood` · `Packages/PlankSync` | `26`/`27`/`31`/`34`/`36`/`38` | **EMPTY** |
| `scripts/` | `40`'s reaper | **EMPTY** |
| **`PlankApp/Auth`** | +268 −18 | **MOVED** — the three operations and the retirement gate |
| **`PlankApp/Sync`** | +784 −37 | **MOVED** — the orchestrator, the inventory, the collision and authority rules |

> **`PlankApp/Auth` and `PlankApp/Sync` MOVED. Stated first, not buried.**
> Every addition is gated on an operation that requires POSITIVE PROOF the
> source was anonymous. The retirement gained a gate and lost none:
> it still cannot throw, cannot fail a sign-in, and cannot name an account
> other than the one whose token it holds — and it now additionally
> refuses an account this device is not carrying. `signOut`,
> `signUpWithEmail`, `bootstrap` and `classifyVerifyFailure` are
> **byte-identical to `1710180`**.

**All three files that declare a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **ZERO DIFF
against `1710180`**, re-derived this session with
`grep -rlE "^[[:space:]]*@Model"`. **There is no SwiftData store migration
to fail.**

The `project.pbxproj` diff contains **only file references** — verified by
filtering out every `PBXBuildFile` / `PBXFileReference` / group-child line
and getting an empty result. **`CURRENT_PROJECT_VERSION` is still 30**,
`MARKETING_VERSION` still `1.2.0`.

### This session's files — eleven

`Auth/AccountOperation.swift` **(new, 144)** ·
`Sync/LocalHandoffInventory.swift` **(new, 153)** ·
`Auth/AnonymousAccountRetirement.swift` · `Auth/AuthService.swift` ·
`Sync/AppSync.swift` · `Sync/IdentityMerge.swift` ·
`plankAITests/HandoffContractTests.swift` **(new, 22 tests)** ·
`plankAI.xcodeproj/project.pbxproj` (three file references) ·
`docs/app_v25/41_probes/` **(6 new, read-only)** ·
`docs/app_v25/41_packages/E1_account_handoffs.sql` **(new, staged)** ·
this document.

**ZERO files under `Packages/`, `supabase/` or `scripts/`.**

---

## 36 · CORRECTIONS TO THE RECORD

`39` and `40` are **not rewritten**. The history of how the architecture
was disproven is the most useful thing in this series.

**[CORR] `39`'s client retirement was not durable, and `40` said so
first.** `40` §3.5 named it *"one best-effort attempt"* and named the
reason. This pass confirms it and closes it with a server receipt rather
than by arguing with it.

**[CORR] `39`'s merge-family inventory was incomplete** — corrected by
`40` §2, and corrected again here on the count: seventeen customer-owned
`@Model` families, not eighteen, so **ten were dropped, not eleven**, and
`@Model` is not the inventory at all (§2.2).

**[CORR] named → named was reachable by the merge machinery** — found and
fixed by `40` §1 case J for SwiftData. **It was still reachable for every
device-scoped customer-authored key**, which is finding 3 here.

**[CORR] same-uid Apple linking returns a pre-link user shape whose
`identities` cannot be used as immediate proof of Apple linkage** — `40`
§0 finding 4, confirmed and now load-bearing in a second place: it is
exactly why `.unknown` must classify as a SWITCH and never as a handoff.

**[CORR] on `40` §3.4** — *"the local store is a superset of A's server
rows"* is false after a reinstall whose hydrate has not landed (§23).

**[CORR] on `40` §2's collision rule** — *"the account's own row wins"*
was written for id collisions and was correct there. It was **not applied
to the one composite key that is not an id**, and SwiftData's silent
resolution meant nothing surfaced.

**[CORR] on `40` §2's profile and consent refusals** — both are the right
decision and both left the refused row on disk under the retired uid.
**REFUSED IS NOT THE SAME AS REMOVED.**

---

## 37 · THE TWENTY-FIVE ANSWERS

**1 · WHAT ARE THE THREE DISTINCT ACCOUNT OPERATIONS?**
**UPGRADE IDENTITY** (anonymous A → permanent A, same uid, carries
nothing), **ADOPT** (anonymous A → permanent B, the only ownership
transfer), **SWITCH ACCOUNT** (permanent A → permanent B, zero transfer,
and it isolates A). Named in `AccountOperation`, chosen by
`AccountOperationClassifier`, and the rule `oldUid != newUid ⇒ merge` is
forbidden in writing.

**2 · CAN NAMED → NAMED EVER MOVE CUSTOMER DATA NOW?**
**NO.** SwiftData: refused by the classifier (`40`'s guard, now the one
rule). Device-scoped keys: swept by the isolation contract. Server:
`begin_account_handoff` refuses a permanent caller with `42501` and
`complete_account_handoff` re-checks `is_anonymous` at use **and** on the
`DELETE` itself. Three independent gates.

**3 · DOES ANONYMOUS → NEW APPLE KEEP THE SAME UID?**
**YES** — `39`'s `linkIdentityWithIdToken`, unchanged. Still unproven
against this project's live GoTrue; still the founder's one-line device
check.

**4 · DOES THAT SAME-UID PATH RUN ANY MERGE?**
**NO.** It classifies as `.upgradeIdentity`, whose three permissions are
all false, and the merge machinery refuses a same-uid pair by
construction. No row copied, no id minted, no timestamp moved, no
receipt. Asserted.

**5 · WHAT EXACTLY HAPPENS WHEN APPLE ALREADY BELONGS TO B?**
GoTrue refuses the link (`identity_already_exists`, transaction rolled
back). The fallback signs into B. The operation classifies as `.adopt`.
All seventeen local families plus food carry into B under the §2 rules;
the profile, consent, care-team regimen and prescribed facts are refused
**and removed**; the destination's live plan and live medication head
keep the present tense; A's server rows are retired with A's own token,
**only if this device is carrying A's record.**

**6 · HOW DOES THE SERVER PROVE THE CALLER CONTROLLED SOURCE A?**
It does not have to. **A proves it itself, while authenticated**, by
opening a receipt from `auth.uid()` that pre-commits to a one-way digest
of the destination subject. B then proves itself by *being* the account
that owns that subject, computed server-side from B's own
`auth.identities` / `auth.users` rows. Nothing secret is persisted
anywhere.

**7 · CAN B NAME A RANDOM ANONYMOUS UID AND ABSORB IT?**
**NO.** There is no argument that names a source for authorization —
`p_source_user_id` can only NARROW an already-authorized set. B cannot
cause a stranger's anonymous account to pre-commit to B's subject,
because only a client holding that account's session can call BEGIN.

**8 · HOW MANY CUSTOMER-DATA FAMILIES EXIST, RE-DERIVED?**
**TWENTY-FOUR.** Seventeen customer-owned `@Model` families (of eighteen
declared — `ExerciseRecord` is the exercise library), plus the food
journal, food photos, `move.manual.v1`, the `day.note`/`day.reflection`
family behind `public.day_reflections`, the `day.sit`/`day.dose`/`band`
family, the onboarding + `safety_*` device keys, and the deletion ledger.
**`40`'s "eighteen" counted the exercise library and omitted seven.**

**9 · HOW MANY OF THEM FOLLOW A → B?**
**Twenty-two.** All seventeen `@Model` families follow except
`ConsentGrantRecord` (refused) and the profile (destination wins), and
all seven non-`@Model` families follow — the device-scoped ones by
construction, because the person did not change. **Two are refused.**

**10 · WHICH FAMILIES CANNOT BE BLINDLY MERGED?**
The profile (its PK is the uid) · `day_progress`,
`exercise_calibrations` and `day_reflections` (the uid is IN their key) ·
the live program plan and the live medication regimen (current-state
claims) · care-team regimens and prescribed facts (foreign authority) ·
consent (not portable) · every clinic table (a relationship between a
clinic and an identity).

**11 · WHAT HAPPENS IF A AND B BOTH HAVE A LIVE PLAN?**
**B's stays live. A's arrives archived**, so nothing is discarded and no
goal is silently overwritten. Earliest-startDate is `31`'s rule for a
different problem and it re-dates the journey she is living in.

**12 · WHAT HAPPENS IF A AND B BOTH HAVE A REGIMEN?**
**B's medication head stays live. A's arrives ENDED** (`end_reason =
'ended'`), so her dose eras stay in the record and the present tense stays
single. Supplements have no single authority and carry live. Production:
zero permanent accounts have a regimen, so this rule is being made before
it is needed rather than after.

**13 · WHAT HAPPENS TO CONSENT?**
**Nothing transfers, and the local grant is now removed rather than
stranded.** The clinic-facing scope is `visit_packet_view`, server-side,
tied to an identity. **Consent does not become broader because accounts
merged.**

**14 · WHAT HAPPENS TO JENI MEMORY, CHAT AND MANUAL MOVEMENT?**
All three **follow her into B on an ADOPT** — memory and chat re-keyed in
place with their ids, movement by being device-scoped — and **none
follows a SWITCH.** None of them starts syncing. A local record can follow
an identity transition without becoming cloud-synced, and that
distinction is now written down.

**15 · WHAT HAPPENS TO A'S DELETION LEDGER?**
**Cleared, and only once the carry has COMMITTED.** Its ids were re-keyed
or retired, so it can never match again. **It is never unioned into B's**:
a deletion she made as one identity is not an assertion about another
account's rows.

**16 · ARE RECORD IDS PRESERVED?**
**Today: partly.** Jeni memory, chat and body scans keep theirs; doses,
symptoms and weekly reads get exactly the id the destination would mint;
weight, sessions, plans, checks and food get fresh uuids **because RLS
rejects a same-id upsert of a row the old uid still owns**.
**Under the staged migration: yes, everywhere** — the server changes the
owner, not the id.

**17 · WHAT DURABLE SERVER FACT REPRESENTS AN IN-PROGRESS HANDOFF?**
**None today — that is the residue.** Under E1: one `open` row in
`public.account_handoffs`, written while the source was still
authenticated, naming the source and a digest of the destination it
pre-committed to.

**18 · CAN THE CLIENT DIE AFTER AUTH SWITCH AND STILL RECOVER?**
**YES for the local half, and that is new**: the receipt is written at the
switch, survives a sign-out, and is discharged only when the carry
COMMITS. **The server half needs E1.**

**19 · CAN SOURCE RETIREMENT FAIL AND LATER COMPLETE WITHOUT A'S TOKEN?**
**Not today. Yes under E1** — `complete_account_handoff` is called as B,
whose credential is permanent and legitimately hers, and it retires A
without any credential for A ever existing again. **This is the exact
hole `40` left, and closing it is the whole reason the migration exists.**

**20 · CAN THE HANDOFF BE REPLAYED WITHOUT DUPLICATING DATA?**
**YES.** The local carry only ever fetches rows keyed to the OLD uid;
BEGIN is guarded by a partial unique index; COMPLETE's terminal state is
outside its own filter; every transfer statement matches nothing on a
second run.

**21 · WHAT EXACTLY MAKES SOURCE A SAFE TO DELETE?**
Three things, all required: the outgoing session was **provably
anonymous**; the incoming session names a **different** account; and
**this device is carrying A's record** (§23). Under E1 a fourth is added
server-side: the source is still `is_anonymous`, re-checked at use and
asserted on the `DELETE` itself.

**22 · CAN ANY HISTORICAL ORPHAN BE REPAIRED BY THIS?**
**NO, and none was touched.** Attribution is impossible and remains so.
The reaper is unchanged and unrun; at a defensible window it still
matches **zero**, because the project is 106 days old.

**23 · WHAT MIGRATION / FUNCTION MUST SHIP?**
`docs/app_v25/41_packages/E1_account_handoffs.sql` — one table, one
partial index, two public `SECURITY DEFINER` functions and one private
one. No secret. Plus `40`'s Package A, unchanged.

**24 · WHAT IS THE EXACT DEPLOY ORDER?**
1 apply E1 · 2 verify read-only in production · 3 ship the client
carrying the protocol · 4 adoption window · 5 reconsider the legacy
fallback (recommendation: keep it). **Every step is safe alone**, in
both directions.

**25 · SAFE FOR NEXT BUILD: YES.**
Every change is additive and device-local. No arithmetic moved, no
`@Model` changed, no schema, no deploy, no production SQL beyond
read-only SELECTs, `supabase/migrations` **EMPTY**. The one behaviour a
customer can notice is that switching from one account to another on the
same phone no longer shows her the other person's workouts, evening words
or safety answers.

---

# SCORECARD

Graded hard. Anything below 9 names the exact blocker.

| domain | `40` | now | the exact blocker |
|---|---|---|---|
| **IDENTITY UPGRADE** | — | **10** | Named, contract-tested, carries nothing, mints nothing, writes no receipt. |
| **EXISTING-ACCOUNT COLLISION** | 9 | **9** | Every family carries or is deliberately refused, and `footprint(source) == 0` is asserted. **Blocker: the retirement is still one best-effort attempt until E1 is applied.** |
| **NAMED-ACCOUNT ISOLATION** | 9 | **10** | Three independent gates, and the device-scoped half is closed. Two fully populated accounts, switched both ways, prove it. |
| **SERVER OWNERSHIP TRANSFER** | — | **7** | Designed, written, per-family, id-preserving, one transaction. **Blocker: NOT APPLIED, and not syntax-checked against a live Postgres — there is no local server in this session.** |
| **LOCAL OWNERSHIP TRANSFER** | 8 | **10** | One inventory, one orchestrator, every family decided, refusals removed rather than stranded. |
| **CRASH RECOVERY** | 9 | **9** | The receipt is written at the switch, survives a sign-out and is discharged only on a commit. **Blocker: a crash between the switch and a failed retirement still leaves the source account, until E1.** |
| **RETRY / IDEMPOTENCY** | 9 | **9** | Every action is idempotent on both sides. **Blocker: an RPC that succeeds with a lost response still cannot be distinguished from one that failed — closing it needs a server idempotency key, which E1's receipt would provide for the handoff but not for account deletion.** |
| **HEALTH RECORD PRESERVATION** | 9 | **10** | Nothing is deduplicated by similarity anywhere; every drop is on a key; the day-progress collapse is deterministic instead of silent. |
| **PROGRAM CONFLICT SAFETY** | — | **10** | One live plan, one live medication head, the destination's own wins, A's survives as history, nothing fabricated. |
| **CONSENT SAFETY** | 9 | **10** | Refused, removed, and re-pinned beside two new refusals so they cannot drift apart. |
| **DELETION SEMANTICS** | 9 | **9** | Delete beats transfer; the ledger is scoped to the account that made it; a confirmed deletion's purge now survives a sign-out. **Blocker: a deletion still does not propagate to a second device — `38`'s tombstone, unchanged and out of scope.** |
| **OLD-CLIENT SAFETY** | 10 | **10** | Nothing about the server contract changed in this build, and E1 is invisible to every client that exists. |
| **SECURITY / ACCOUNT-TAKEOVER RESISTANCE** | — | **9** | No identity is a trusted input; the proof is not a bearer credential; the mover is unreachable. **Blocker: the injection residual in §11 — an attacker holding a victim's Apple `sub` could pre-commit their own anonymous rows. Bounded, named, and not zero.** |

---

# THE FIVE BUCKETS

### BUILD NOW
1. **The three operations**, with positive proof of anonymity.
2. **The named → named firewall's device-scoped half** — B was reading
   A's workouts, evening words and safety answers.
3. **The day-progress collision guard** — the one unguarded unique key,
   silently collapsing rows.
4. **The two authority refusals** — a clinic's prescription must not
   follow a person into an account that clinic never met.
5. **The plan and regimen conflict rules** — one present tense, A's
   preserved as history.
6. **The receipt that survives a sweep, the intent that survives a
   sign-out, the carry that reports whether it committed, and the
   retirement that refuses an account it is not carrying.**

*(All six are in this build.)*

### READY — DO NOT DEPLOY
1. **E1** `account_handoffs` + `begin` + `complete` + the private
   transfer. Forward, rollback, safety matrix, deploy order.
2. **A1** the storage purge — **before `food-photos` is ever created.**
3. **A2** `patient_invitations.accepted_by` → `SET NULL`.
4. **A3** three `comment on table` decisions.
5. **B1/B2** the Apple token store and revocation function — unchanged,
   still blocked on a `.p8`.
6. `scripts/reap_abandoned_anon_accounts.sql` — steps 1–2 read-only,
   step 3 commented out.

### FOUNDER ACTION
1. **Read §11's authorization argument, then apply E1.** It is the only
   thing that closes *"the source uid survives forever because one delete
   request failed"*.
2. **Run step 2's four verification lines** before any client is written
   against the contract.
3. **Answer `40` §12** — OPTION A or B for `care_weekly_summaries`. Still
   zero rows. Still free. Now four passes overdue.
4. **Confirm A2 and A3's sentences**, then apply Package A.
5. **Create the Apple `.p8`** (`40` §17).
6. **The device check after the first Apple sign-in on this build.**
7. **The archive-time bump to build 31.**

### PRODUCTION REPAIR
1. **Nothing that helps this year, and that is unchanged.** At a
   defensible window the safe reaper removes **zero** accounts; the
   project is 106 days old. **Prevention is the repair, and it is in this
   build.**
2. Run the reaper's steps 1–2 to see it for yourself. Monthly.

### DO NOT TOUCH YET
1. **The client that calls E1.** Step 3, and it must not precede step 2.
2. **`scripts/cleanup_orphaned_anon_users.sql`** — it would delete three
   living customers' records today. Superseded; never run it.
3. **The server tombstone.** Still blocked on a filtering client reaching
   the installed base (`38` §6).
4. **The `food-photos` bucket.** Creating it before A1 opens the storage
   hole for real.
5. **An Apple server-to-server endpoint.** Revisit with Package B.
6. **Backfilling an anonymous → named uid link from row shapes.** The
   fabrication class this whole line of work exists to remove.
7. **Syncing Jeni memory, chat, movement or body scans.** *We do not sync
   more customer data until deletion semantics are trustworthy* — and a
   handoff that follows the person on one phone is not the same as a
   record that follows her to a second one.

---

# THE FINAL GATE

> ▎ **IF AN ANONYMOUS CUSTOMER SIGNS INTO AN EXISTING APPLE ACCOUNT, CAN
> ▎ ANY RECORD SHE CREATED DISAPPEAR?**

**NO.**

*The invariant that makes it impossible:* every carry is asserted by
**footprint** rather than by a list — `footprint(source) == 0` **and**
`footprint(destination) > 0`, across all twenty-four families — so a
family nobody added to a list cannot hide, and moving cannot be confused
with vanishing. Every drop is on a KEY and never on a resemblance. Every
refusal either preserves the record as history (the plan, the regimen) or
removes a row whose account is being deleted anyway (the profile,
consent, a foreign prescription). And the carry now reports whether it
committed, so a failure keeps the receipt that retries it.

> ▎ **CAN A PERMANENT CUSTOMER SIGN INTO ANOTHER PERMANENT ACCOUNT
> ▎ WITHOUT EITHER ACCOUNT ABSORBING THE OTHER?**

**YES.**

*The invariant:* a handoff requires **positive proof that the source was
anonymous** — `AuthMethod.anonymous`, never a uid difference, a missing
profile, a fresh account or an absent identity — and `.unknown` is the
absence of proof, so it classifies as the operation that moves nothing.
Account A's device-scoped record is cleared under the existing
cross-account isolation contract; account B hydrates its own.

> ▎ **IF THE APP DIES AT THE WORST POSSIBLE MILLISECOND DURING A → B,
> ▎ DOES THE SERVER STILL KNOW WHAT REMAINS TO BE DONE?**

**NO — and this is the one honest NO in this document.**

The DEVICE knows: the receipt is written at the switch, survives a
sign-out, and is discharged only on a commit. **The SERVER knows nothing
until E1 is applied.**

*The shortest exact path to YES:* **apply
`docs/app_v25/41_packages/E1_account_handoffs.sql`.** One table, two
public functions, one private one, no secret, invisible to every client
that exists. Then verify it read-only, then ship the client that calls
it. Nothing else in this document is required.

> ▎ **CAN A MALICIOUS USER CLAIM ANOTHER ANONYMOUS USER'S HEALTH DATA BY
> ▎ NAMING THEIR UID?**

**NO.**

*The invariant:* **no identity is a trusted input.** The destination is
always `auth.uid()`. The source is never an authorization argument — it
can only narrow a set the server already computed from the caller's own
identity rows. And the pre-commitment that authorizes a transfer can only
be written by a client that held the source's session, which is the
device that is about to sign into the destination.

> ▎ **CAN THE SOURCE ANONYMOUS UID SURVIVE FOREVER SOLELY BECAUSE ONE
> ▎ CLIENT DELETE REQUEST FAILED?**

**YES, today. This is the residue, and it is the reason this pass
exists.**

*The shortest exact path to NO:* the same one sentence — **apply E1.**
After it, the retirement is owed by a durable server fact, retryable by
the destination's own permanent credential, and needs no bearer token for
the account it retires. Until then the answer is offline-or-5xx-shaped
and rare, and it is not nothing.

---

**SAFE FOR NEXT BUILD: YES.**

**READY FOR HANDOFF MIGRATION DEPLOYMENT: YES** — the schema is additive,
invisible to build 30 and build 31, rollback is four `drop` statements,
and no client depends on it. **It has not been executed against any
Postgres, and step 2 of §31 exists to catch that before a client is
written against it.**

---

> ▎ **ONE PERSON.**
> ▎ **ONE OWNED RECORD.**
> ▎ **AN IDENTITY MAY CHANGE.**
> ▎ **OWNERSHIP MAY NOT BECOME AMBIGUOUS.**
