# THE REAL DEVICE

**Status: `linkIdentityWithIdToken` HAS NOW RUN AGAINST THIS PROJECT'S
LIVE GOTRUE, FROM A PHYSICAL iPHONE, FOUR TIMES. 2026-08-15.**

`42` ended with exactly one blocker, and it was the only claim in the
whole series that rested on reading rather than on running. This pass
ran it.

> ▎ **THE ERROR IS NOT THE SIGNAL. THE UID IS.** Confirmed live, four
> ▎ times, with the exact ambiguous code `40` predicted from source.
>
> ▎ **THE SOURCE'S RETIREMENT NEEDS NO CREDENTIAL FOR THE SOURCE.**
> ▎ Confirmed on the founder's own phone, against his own account.
>
> ▎ **AND THE FACTS MUST NOT ARRIVE LAST.** The device test found a
> ▎ customer-facing defect no harness could have found, because it is a
> ▎ RACE BETWEEN A THIRTY-FIVE SECOND HYDRATE AND A HUMAN THUMB.

---

## 0 · THE ANSWER FIRST

| # | the finding | class |
|---|---|---|
| 1 | **THE BLOCKER IS CLOSED.** `linkIdentityWithIdToken` reached this project's live GoTrue and was answered by `linkIdentityToUser` itself — which is reached only after `requireAuthentication` accepted the anonymous bearer token, the Apple provider resolved, the audience was accepted and the nonce was verified. **The entire link path is now live-verified up to its identity lookup.** | **the pass's purpose** |
| 2 | **[CORR] MANUAL LINKING DOES NOT GATE THIS PATH, AND THE BRIEF'S PREMISE WAS WRONG.** In the deployed version's own router, `requireManualLinkingEnabled` is applied to exactly two routes — `GET /user/identities/authorize` and `DELETE /user/identities/{id}`. `POST /token?grant_type=id_token` is not under it. There was never a setting to change. | corrects the brief |
| 3 | **[CORR] `moved` COUNTS RECEIPTS, NOT ROWS.** `v_moved := v_moved + 1` runs once per receipt in the loop. `42`'s headline `{"moved":1,"retired":1}` is one receipt processed and one `auth.users` row deleted. On this device the source owned **zero** customer rows, so **zero rows changed owner** — and the four device runs therefore prove the LINK, the REFUSAL, the FALLBACK, the RECEIPT, the AUTHORIZATION and the RETIREMENT, **but not the row transfer**, which remains proven only by `42`'s production run. | precision |
| 4 | **[P0, FOUND ON THE PHONE] THE RESTORE IS THIRTY-FIVE SECONDS LATE, AND THE APP IS DESTRUCTIVE IN THE MEANTIME.** `syncUserDefaultsFromUserRecord` is the LAST step of a seventeen-call hydrate chain. Until it lands a returning payer has no height, weight, goal or pace, so `MainShell` shows her **"start my program"** — and tapping it mints a second LIVE plan with `started_at = today`. **It happened, to the founder, on his own account, at 06:25:18.** | **P0, FIXED** |
| 4b | **[P0, THE SAME DEFECT'S WORSE HALF] `ProgramService.startProgram` ARCHIVES THE LIVE PLAN AND MINTS A NEW ONE UNCONDITIONALLY.** So the onramp tap is not "an extra row" — when her plan HAS hydrated it **archives her real enrollment and resets her program day to 1, permanently**, with nothing left for `reconcileLivePlans` to heal because only one live plan then exists. **THE WORSE OUTCOME IS THE ONE WHERE THE APP KNOWS MORE.** The founder's account survived only because the plan had NOT hydrated yet, which left two live plans and a repairable state. And the day-one greeting he filed is the same line: `DailyBriefEngine` gates *"day one. one card a day"* on `ctx.programDay == 1` **and nothing else**. | **P0, FIXED at the gate** |
| 5 | **[CORR] THE RESTORE ITSELF WAS NEVER BROKEN**, and the device said so: record found, exact-case matched, `pendingUpsert=false`, every fact present, and the one missing key filled. Three hypotheses died on that one line — the uid-case hazard, the `pendingUpsert` block, and `IdentityMerge`'s profile re-key. **Late is the whole defect.** | corrects the diagnosis |
| 6 | **TWO `onAuthChanged` FIRINGS RACE, AND ONE OF THEM CLASSIFIES THE TRANSITION AS `op=none`.** Both are correct given what each captured — `onLaunch` seeds `lastUserId`, and the two concurrent Tasks capture it on either side of the write. The correct `.adopt` arrived from the other firing. It worked; it is decided by which Task resumes first. | **P2, named not fixed** |
| 7 | **`authenticated` HAS NO `SELECT` ON `public.program_facts` OR `public.weekly_reads`.** The client 42501s on both hydrates at every sign-in, for every customer. Both tables hold **0 rows**, so nothing is lost today and the client degrades correctly. It is a grant, not a schema change. | **P2, named not fixed** |
| 8 | **[CORR] `auth.identities.last_sign_in_at` DOES NOT MOVE ON A REAL SIGN-IN.** Measured: it still reads 2026-04-30 while `updated_at` moved to 06:25:xx. Any future reaper predicate must use `updated_at`. | sharpens `40` §6 |

---

## 1 · THE LIVE AUTH CONFIG, READ FROM THE LIVE SERVER

Nothing was changed. Everything below was read.

| question | answer | source |
|---|---|---|
| anonymous sign-ins enabled? | **YES** | `GET /auth/v1/settings` → `external.anonymous_users: true` |
| Apple provider enabled? | **YES** | same → `external.apple: true`; and 559 live Apple identities already prove the audience (`aud` = bundle id) is configured, because the shipping non-link path runs the identical `getProvider` audience check |
| **manual identity linking enabled?** | **IRRELEVANT — IT DOES NOT GATE THIS PATH** | the deployed version's own `api.go`: `requireManualLinkingEnabled` wraps only `/user/identities/*` |
| deployed GoTrue | **v2.195.0** | `supabase services` (the repo's cached `gotrue-version` was **stale at v2.191.0** — `token_oidc.go` and `identity.go` are byte-identical between the two; `api.go` differs only by a SCIM server) |
| deployed Postgres · PostgREST | 17.6 · v14.5 | same |
| Supabase Swift SDK | **2.44.0**, rev `e0b16631` | `Package.resolved`, all three |
| the call | `POST {url}/token?grant_type=id_token`, body `link_identity: true` (snake-case encoder), header `Authorization: Bearer <current session>` | `AuthClient.swift:1221` |
| the call site | `AuthService.completeAppleSignIn`, only when `AppleIdentityPolicy.strategy == .linkToCurrentUser` (`hasSession && isAnonymous`) | — |
| the fallback | `catch` → `AppleIdentityPolicy.fallback(after:)` returns `.signInAsAppleUser` **unconditionally, without inspecting the error** → `signInWithIdToken`. The `guard … else { throw error }` is unreachable by construction. | — |
| **the error-code handling** | **THERE IS NONE.** The client keys nothing off a code or a message. | — |

### 1.1 · Three things the deployed server's source says that the record never stated

- **For Apple, GoTrue sets `Verified: true` UNCONDITIONALLY** in
  `parseAppleIDToken` — even when the email claim is empty. So the
  `email_not_confirmed` branch inside `linkIdentityToUser`, the one that
  **commits the link and still returns an error**, is unreachable for
  Apple. That branch was the most dangerous shape in the function.
- **`is_anonymous` is cleared only inside `if targetUser.GetEmail() == ""`**,
  which is exactly the anonymous case. Link success and de-anonymisation
  are the same transaction.
- **A failure mode nobody has named:** `UpdateUserEmailFromIdentities` can
  raise **`email_exists` (400)** when the Apple email already sits on
  another user row — a different code from `identity_already_exists`,
  landing in the same blind fallback. Not reached on this device.

---

## 2 · THE DEVICE, THE BUILD, AND THE FOUR RUNS

| | |
|---|---|
| device | **iPhone14,8**, iOS **26.5.2** |
| build | Debug on device from Xcode, `1.2.0 (30)`, `com.bk.plankAI`, production Supabase |
| project | `mtecqvykyeueumdynatd` |
| runs | **4 Apple sign-ins**, 05:48 · 05:57 · ~06:0x (unlogged) · 06:25 UTC |
| receipts afterwards | **4, all `completed`, 0 open, 0 with a source, 0 with a digest, 1 distinct destination** |

Run 1 followed a sign-out. Run 2 followed a **delete-and-reinstall**
(the IDFV changed and TikTok logged `InstallApp`), which independently
proves the flow carries nothing across an install. Run 4 followed a
sign-out and is the fully instrumented one.

### 2.1 · Run 4, the observed sequence

```
06:24:44   launch, already anonymous
06:25:04   PRE       uid=DAF49A3C-EEA1-4FA8-9F4A-BA8E851020FE  anon=true
                     hasToken=true  strategy=linkToCurrentUser
06:25:04   BEGIN     opened            ← receipt written while she still owns the record
06:25:05   LINK      HTTP 422   x-sb-error-code: identity_already_exists
                     "Identity is already linked to another user"
                     sb-request-id 01a00418-6cd1-7604-8094-f96f7cd65276
06:25:05   fallback  signInWithIdToken → the EXISTING April identity row's updated_at moves
06:25:05   POST      uid=280CAA8E-B635-49B7-8BF1-CA725F71798A
                     anon=false  sameUid=false  identities=1  providers=apple  method=apple
06:25:05   AUTHCHANGE op=none  uidChanged=false                    ← firing A
06:25:05   AUTHCHANGE op=adopt(source: DAF49A3C…, destination: 280CAA8E…)
                      uidChanged=true carries=true isolates=false   ← firing B
06:25:05   MERGE     profile outgoingExists=false destinationExists=true arm=none
06:25:05   COMPLETE  {"moved": 1, "retired": 1}
06:25:05   RETIRE    retired            ← the client's legacy retirement STOOD DOWN
06:25:10   program_invite_tapped        ← the onramp, because no fact had arrived yet
06:25:18   ***A SECOND LIVE PROGRAM PLAN IS MINTED, started_at = today***
~06:25:40  RESTORE   record found · exact-case · pendingUpsert=false · every fact present
```

Runs 1 and 2 produced the identical first half, to the request id.

### 2.2 · The observation, and what it was forbidden

Seven `#if DEBUG` print sites tagged `[43-OBS]`, in three files. They
emitted uids, booleans, an enum case name, a structured error code, an
HTTP status, provider **names** and counts, and **presence** flags for
body facts. **Never** an id token, an access token, a refresh token, an
authorization code, a nonce, an email, a name, an Apple subject, or any
health value — a weight, a height and a goal were reported as `true` or
`false`, never as numbers. All seven were removed in §7.

---

## 3 · THE DATABASE, BEFORE → AFTER

`T0 = 2026-08-15 05:26:45Z`, one `select` and 35 `union all select`,
mechanically proven read-only before running.

| | BEFORE | AFTER |
|---|---|---|
| `auth.users` | 4,293 | **4,293** |
| anonymous / permanent | 3,426 / 867 | **3,426 / 867** |
| **apple identities** | 559 | **559**, and **0 created since T0** |
| `account_handoffs` | **0** | 4 completed · **0 open** · 0 sources · 0 digests |
| profiles · food · sessions · checks · day_progress · reflections · observations · doses · regimens · consent · care · coach_messages · storage | — | **every one identical** |
| `weight_logs` | 3,283 | 3,284 — **the weigh-in the founder logged at 05:48:32**, and `B` has exactly one weight row created after 05:00 |
| `program_plans` | 289 | 290 — **the duplicate minted by the onramp race**, archived in §5 |

**Every retired source is gone and owns nothing:** for the two logged
sources, `auth.users` = 0 and all fifteen ownership families = 0.

`identities_apple` unchanged at 559 is the strongest single line here:
**had any link succeeded there would be 560.**

---

## 4 · CLASSIFICATION

**B · EXISTING-ACCOUNT HANDOFF.** Four times, identically. Not C.

| `42` §6-B expected | observed |
|---|---|
| receipt created correctly | yes, at 06:25:04.x, **before** the token exchange |
| B is the authenticated destination | yes, `dst = B` on all four receipts, one distinct destination |
| server COMPLETE runs | yes, `{moved: 1, retired: 1}` |
| allowed rows move exactly once | **zero rows to move** — the source was seconds old (see §0 finding 3) |
| forbidden clinical/consent facts do not move | `consent_grants` 31, `care_relationships` 10, `regimen_plans` 164 — **all unchanged** |
| source retirement completes | yes, four times; `auth.users` row gone each time |
| replay harmless | four receipts, zero open, no duplicates |
| no record receives a third uid | one distinct destination across all four |

**Only one account has ever held this Apple subject** (`accounts_sharing_B_subject = 1`),
so the pre-committed digest could never have been redeemed by anyone else.

---

## 5 · THE DEFECT THE DEVICE FOUND, AND THE FIX

> ▎ **NO HARNESS COULD HAVE FOUND THIS, BECAUSE IT IS A RACE BETWEEN A
> ▎ THIRTY-FIVE SECOND HYDRATE AND A HUMAN THUMB.**

The founder reported it in his own words: *"everytime i logout and login
back, it loses current weight, goal weight, current height and every
options."*

**The server is not at fault.** His row holds height, current weight,
goal weight, sex, activity, age band, commitment days, GLP-1 status,
hormonal stage, sleep, stress, weight trend and food relationship — and
across the whole base, **780 of 780 permanent profiles have both height
and goal weight.**

**The client restore is not at fault either.** Measured on the phone:

```
RESTORE userId=280CAA8E… recordsOnDisk=1 idsMatchExactly=1 idsMatchAnyCase=1
RESTORE record pendingUpsert=false hasHeight=true hasWeight=true hasGoal=true hasSex=true hasGlp1=true
RESTORE defaults BEFORE height=true weight=false goal=true onboardingDone=true enrolled=true
RESTORE defaults AFTER  height=true weight=true  goal=true onboardingDone=true enrolled=true
```

It found the record, matched the uid exactly, refused nothing, and
filled the one key that was missing.

**It is the SCHEDULE.** `syncUserDefaultsFromUserRecord` is the last of
seventeen steps in `hydrateAndSync`. For the whole of that window the app
is interactive and knows none of her facts, so `MainShell` offers the
onramp — and the tail of that very function already names the
consequence: *"a re-enroll mints a fresh plan with startDate = today,
resetting the day the founder saw disappear."* The repair was written.
It was scheduled behind seventeen network calls.

**SHIPPED:** the restore is now called **three** times in `hydrateAndSync`
— once **before any network call** (which heals the sign-out case in
milliseconds, because the record is already on disk), once after the
profile and the plans have landed (which heals the reinstall case after
four calls instead of seventeen), and once at the end as before.

**Calling it early is safe as a property, not as a hope:** every write it
makes is **monotone**. It sets `hasCompletedOnboarding`,
`programEraEnabled` and `hasEnrolledInProgram` only to TRUE, never to
false; `restoreBodyDefaults` and `restoreCohortDefaults` refuse a pending
record and never adopt an absent server value. Both refusals are already
pinned by `BodyInputsRestoreTests`
(`testACleanRecordWithAnEmptyColumnDeletesNothing`,
`testEmptyRecordWritesNothing`). **An extra call can restore a fact
sooner. It cannot remove one.**

### 5.0 · AND SCHEDULING IS NOT ENOUGH — THE GATE ITSELF WAS THE FLAG

The founder filed two screenshots: **"your plan is here · start my
program"**, and **"day one. one card a day"**. They are one line of code.

`TodayHost` decided the onramp from `@AppStorage("programEraEnabled")`
alone — **and that key is one of the 94 the sign-out sweep removes.**
Meanwhile `ProgramService.startProgram` archives the live plan and mints
a new one with **no check that one already exists**, so the button under
that screen is not additive, it is a **day reset**. `DailyBriefEngine`
then gates the day-one card on `ctx.programDay == 1` and nothing else,
which is why the greeting followed the plan.

> ▎ **A LIVE PLAN OUTRANKS A DEVICE FLAG, BECAUSE THE FLAG IS SWEPT AND
> ▎ THE PLAN IS NOT.**

Rescheduling the restore *shrinks* the window; on a slow network it opens
right back up, and a slow network is exactly when a returning customer
sits longest on the wrong screen. **`TodayHost` now also derives from a
live plan (`@Query`, reactive), so the instant the hydrate inserts the
row the view flips and there is no window to lose a race in.** A
genuinely new customer still gets the onramp — she has no plan — and so
does a graduated one, whose plans are all archived: the same rule
`AppSync` already applies when it restores the flag.

**`startProgram` was deliberately NOT changed.** Refusing there would
break the legitimate re-enroll and graduation flows, which are the only
other callers. The reachable path is closed at the gate; the unguarded
write is **named, not fixed**.

**There is no "welcome back" copy to write, and none was invented.**
`DailyBriefEngine` already carries the returning voice at
`daysSinceLastOpen >= 4` and `>= 14`. What the founder was missing was
not a sentence — it was **not being treated as new**, and that is the
program day.

### 5.1 · The sweep-versus-restore census

Mechanically diffed: **sign-out sweeps 94 keys, sign-in restores 29, and
65 have no restore path at all.** The load-bearing ones, with reader
counts outside the sync layer:

`program_mode` (21) · `onboarding_goal_direction` (16) ·
`onb_v4_movement_baseline` (13, and it **outranks** the alias the restore
does write) · `onboardingAgeRange` (8) · `medicalDisclaimerAckAtISO` (6) ·
`onboardingGoalDate` (2) · `onboardingPaceChoice` (1, the pace that owns
the deficit rate) · the six food settings and the food-AI consent.

Three of them are exactly `35`'s named-not-fixed item, now **measured**
rather than predicted: `program_mode` and `goal_direction` are **still
NULL on the founder's own row**, so there is nothing on the server to
restore them from. **The columns have existed since 2026-07-03 and still
have zero writers.** Not fixed here: it is a write path in a frozen area.

### 5.2 · The one production write this pass made

`docs/app_v25/43_probes/W1_archive_duplicate_plan.sql`, on the founder's
explicit instruction. One `update`, one row, five independent guards in
the `WHERE`, and a `DO` block that **raises and rolls back** unless
exactly one live plan remains and it is the 2026-08-04 one.

**ARCHIVED, NOT DELETED** — `phase='abandoned' + archived_at` is how this
model already carries a superseded enrollment (`42` §8.3), it keeps the
history honest, and `ProgramPlanMerge` (`31`) carries it to the device
with no founder action. A delete risked the phone pushing it back.

Verified after: `plans_live = 1`, the survivor is
`15ec87d9…` started 2026-08-04, the duplicate is `abandoned` with
`archived_at` set, `program_plans` 290 (nothing deleted), `auth.users`
4,293.

---

## 6 · WHAT WAS NOT PROVEN, AND WHY

### 6.1 · ANONYMOUS → A **NEW** APPLE IDENTITY (same-uid upgrade)

**NOT PROVEN ON A REAL DEVICE, AND NOT SIMULATED.**

It cannot be reached with the founder's Apple ID, because that subject
already belongs to account B — which is precisely why all four runs took
the other branch. It needs an Apple ID that has never signed into Jeni.

Removing the identity from B to force the branch was considered and
**refused**: it would leave a real, paying account with zero identities.

What the device *did* narrow: the 422 came **from inside
`linkIdentityToUser`**, so everything before its identity lookup is
live-verified. The unproven statements are exactly `createNewIdentity`,
`UpdateUserEmailFromIdentities`, `Confirm`, the `is_anonymous = false`
write and `UpdateAppMetaDataProviders`.

### 6.2 · CRASH RECOVERY

**NOT PROVEN ON A REAL DEVICE.** The window between the Apple sheet
dismissing and `COMPLETE` returning is **~780 ms**, measured. Two
attempts to kill the process inside it missed; both instead produced a
clean completion, which is evidence of the happy path and not of
recovery.

It is proven in production by `42` §9 with **zero client state**, and the
mechanism is not in doubt — `complete_account_handoff()` **takes no
arguments**. But it has not run on the phone, and that is stated rather
than rounded up.

---

## 7 · THE OBSERVATION IS GONE

`grep -rn "43-OBS" --include="*.swift"` over `PlankApp`, `Packages`,
`plankAITests`, `plankAIUITests` → **0**.

Release binary, `Release-iphoneos/plankAI.app/plankAI`, **85 MB /
122,513 strings** — size and total stated first, because a zero from a
file that does not exist is the `Executed 0 tests` trap in different
clothes (`35`).

| string | count |
|---|---|
| `43-OBS` | **0** |
| `RESTORE defaults` · `AUTHCHANGE` · `MERGE profile` · `DISCHARGE` | **0 · 0 · 0 · 0** |
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `debug-delete-account` · `debug-plan-numbers-focus` | **0 · 0** |
| `transfer_account_rows` · `account_handoffs` | **0 · 0** |
| `begin_account_handoff` · `complete_account_handoff` | 1 · 1 (controls) |
| `rest/v1/rpc/delete_user_account` | 1 (control) |

**No auth uuid, auth error or token diagnostic ships. No new DEBUG door
was added.**

---

## 8 · GREEN, MEASURED

Every command run serially, unpiped, count checked against expectation.

| suite | expected | actual | verdict |
|---|---|---|---|
| `-only-testing:plankAITests` (full app) | 1346 | **1346, 0 failures** | `** TEST EXECUTE SUCCEEDED **` |
| PlankSync (`swift test`) | 9 | **9, 0 failures** | `Test Suite 'All tests' passed` |
| PlankFood (package scheme, iOS sim) | 200 | **200, 0 failures** | `** TEST SUCCEEDED **` |
| `WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | `** BUILD SUCCEEDED **` |

**1346 → 1346, exactly zero change**, because this pass added no test and
no test needed changing.

### 8.1 · RED, and the honest absence of one

**NO RED→GREEN IS CLAIMED FOR THE FIX, AND NONE WAS MANUFACTURED.**
`hydrateAndSync` is a private async function wrapping seventeen network
calls with no injection seam, so a test of the ORDERING would be a test
of a mock. What the fix *depends* on — that the restore is monotone and
needs no network — is already pinned by two existing tests named in §5.
**The proof of the defect is the device measurement and a production row
with `started_at = 2026-08-15 06:25:18`.**

### 8.2 · Protected paths and the boundary

`PlankApp/Payment` · `Views/Paywall` · `App/AppPhase.swift` ·
`Notifications` · `Care` · `BodyScan` · `supabase/migrations` ·
`scripts/`: **EMPTY diff vs `1710180`**, and untouched this session.

**All three files that declare a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **ZERO DIFF
against `1710180`**, re-derived with `grep -rlE "^[[:space:]]*@Model"`.
**There is no SwiftData store migration to fail.**

`CURRENT_PROJECT_VERSION` **30**, `MARKETING_VERSION` **1.2.0**.

**This session's behavioural change is two lines in
`PlankApp/Sync/AppSync.swift`** — two additional calls to a function that
was already called, in a function that already called it — **and one gate
in `PlankApp/App/MainShell.swift`**, which now reads a live plan
alongside the flag it already read. `MainShell.swift` is not on any
protected path.

Re-verified after the gate change: **1346/1346 · WallExit 1/1 · Release
`** BUILD SUCCEEDED **`, 85 MB / 122,529 strings, `43-OBS` 0, debug doors
0.**

**No schema change. No migration. No deploy. No RLS, grant, function or
policy touched. The handoff protocol is byte-identical to `42`.**

---

# THE TEN ANSWERS

**1 · DID `linkIdentityWithIdToken` RUN AGAINST LIVE GOTRUE?** **YES.**
Four times, from a physical iPhone, against project `mtecqvykyeueumdynatd`,
GoTrue **v2.195.0**. It was authenticated, routed, and answered by
`linkIdentityToUser`.

**2 · ON A NEW APPLE IDENTITY, DID THE UID STAY THE SAME?** **UNKNOWN —
NOT REACHED.** All four runs presented an Apple subject that already
belonged to account B, so the link was refused every time. **Not
simulated.**

**3 · DID THAT PATH MOVE EXACTLY ZERO CUSTOMER ROWS?** **NOT MEASURED ON
DEVICE**, for the same reason. `42` proves it server-side and both client
gates still hold; nothing in this pass touched them.

**4 · WHAT EXACT ERROR DID AN ALREADY-OWNED APPLE IDENTITY PRODUCE?**
**HTTP 422**, `x-sb-error-code: identity_already_exists`, body message
*"Identity is already linked to another user"*. Identical in every run.
**The session did NOT change on the error** — it changed afterwards, on
the fallback. The uid changed only via the fallback. The fallback ran
every time.

**5 · DID THE FALLBACK LAND ON THE EXISTING ACCOUNT B?** **YES**, and on
the *same* identity row created 2026-04-30 — its `updated_at` moved to
06:25:05 while `identities_apple` stayed at **559**. No account was
minted.

**6 · DID THE DEPLOYED HANDOFF COMPLETE A → B?** **YES**, four times:
`{"moved": 1, "retired": 1}`, receipt `completed`, `destination = B`,
source and digest NULLed.

**7 · DID A DISAPPEAR OR REMAIN DURABLY OWED?** **A DISAPPEARED.** Every
logged source's `auth.users` row is gone and it owns zero rows in all
fifteen families — **retired by a call made as the destination, with no
credential for the source.**

**8 · DID KILLING THE APP LOSE THE HANDOFF?** **NOT TESTED ON DEVICE.**
The window is ~780 ms and two attempts missed it. Proven in production by
`42` §9 with zero client state; not proven on the phone.

**9 · DID ANY TEMPORARY DEBUG OBSERVATION REACH RELEASE?** **NO.** Zero
`43-OBS` in the source, zero in the 122,513-string Release binary, and
zero for each individual observation string.

**10 · DID THIS PASS REQUIRE PRODUCT CODE CHANGES?** **YES — TWO LINES IN
`AppSync` AND ONE GATE IN `MainShell`**, and none of it for the handoff.
The real-device test surfaced a P0 the harnesses could not: the sign-in
restore arrives last, the onramp decides from a key the sign-out sweep
removes, and `startProgram` archives a live plan without checking, so a
returning payer can reset her own program day with one tap. **The handoff
protocol itself needed no change, and got none.**

---

# THE FINAL GATE

**REAL DEVICE — NEW APPLE: NOT PROVEN.**
*Needs an Apple ID that has never signed into Jeni. Not simulated.*

**REAL DEVICE — EXISTING APPLE: PROVEN.**
*Four runs, one of them after a full delete-and-reinstall.*

**CRASH RECOVERY: NOT PROVEN.**
*On device. Proven in production by `42` §9 with zero client state.*

**PRODUCTION GOTRUE: PROVEN.**
*v2.195.0, project `mtecqvykyeueumdynatd`, four request ids on file.*

**SAFE FOR BUILD 31: YES.**
*No schema, no migration, no `@Model`, no paywall/payment/auth-phase
path. Two lines, both scheduling an existing repair earlier.
`CURRENT_PROJECT_VERSION` still 30.*

**HANDOFF CLOSED: NO.**

**THE ONE BLOCKER:** *anonymous → a **NEW** Apple identity has still
never run.* It is the common path for every new customer, and it is the
one branch this device cannot reach, because its Apple subject already
belongs to account B. **One Apple ID that has never signed into Jeni,
one sign-in, one line of the console.**

---

> ▎ **THE LOGIN CHANGED.**
> ▎ **THE ACCOUNT MOVED.**
> ▎ **THE OLD ONE IS GONE, AND NOTHING OF HERS WENT WITH IT.**
> ▎ **MEASURED ON THE PHONE CUSTOMERS ACTUALLY USE.**
