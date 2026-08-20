# BUILD 31 — DISTRIBUTION HANDOFF

**2026-08-15. NOT a pass. No product code changed.**

This document is numbered `47` because it follows `46` on disk. It is
**not** "Pass 47". No architecture was reviewed, no defect was fixed, no
feature was added. The single purpose was to turn the frozen Build 31
into the exact artifact Apple receives, test that artifact through
Apple's distribution path, and prepare the submission.

**THE HEADLINE: BUILD 31 IS UPLOADED AND PROCESSING AT APPLE.**
Delivery UUID `60934d9b-87d2-4563-82ca-42188a727a23`, accepted
2026-08-15 18:49:30 UTC, **0 errors and 0 warnings** from App Store
Connect's package and SPI analysis. **`46` ASSUMED THE DISTRIBUTION
EXPORT WAS A FOUNDER STEP. IT WAS NOT** — the cloud-managed distribution
certificate is fetchable headlessly, and the whole export → validate →
upload chain ran from this machine without a single credential being
typed. Everything from here is a physical-device gate or an App Store
Connect gate, and both need the founder.

---

## FROZEN SOURCE

**HELD. 0 source files changed.**

| | |
|---|---|
| HEAD | `723d0b82cd1c6d068463671605f24cfba637ab52` |
| branch | `feat/app-v2` |
| MARKETING_VERSION | `1.2.0` (4 build configs, all agree) |
| CURRENT_PROJECT_VERSION | `31` (4 build configs, all agree) |
| working tree at start | 55 tracked modifications · 69 untracked |
| working tree at end | 55 tracked modifications · 69 untracked |

The freeze was not asserted, it was **measured**. A manifest of every
`.swift` / `.pbxproj` / `.plist` / `.entitlements` / `.ts` / `.xcconfig`
file under `PlankApp`, `Packages`, `plankAITests`, `plankAIUITests`,
`supabase` and `plankAI.xcodeproj` — excluding `.build` and
`DerivedData` — was hashed at session start:

```
1573 files
manifest sha256  df5a1924a1e483c23cc5968dcc4f7f93056fe2393b23bd18c50c9580b1bb5c97
```

Re-hashed twice: once mid-session, once immediately before the upload.
**Both IDENTICAL, all 1573 files.** The uncommitted working tree is the
accumulated state of passes `30`–`46` and is exactly what `46` froze; it
is not drift introduced here.

**ONE NON-SOURCE CHANGE WAS MADE AND IT IS REPORTED BECAUSE IT WAS A
DELETION.** See PRODUCTION HYGIENE → *Disk*.

---

## SIGNING

### CAN THIS MACHINE CREATE AN APP STORE DISTRIBUTION ARCHIVE? **YES.**

This corrects `46`'s closing sentence — *"THE ARCHIVE IS
DEVELOPMENT-SIGNED — `get-task-allow` is the proof — so the distribution
export and upload remain the founder's step."* The archive being
development-signed is true and **irrelevant to the question**: an archive
is re-signed at export time. `46` inferred the gate from the archive's
signature and did not test the export.

The first evidence looked like it agreed with `46`:

```
security find-identity -v -p codesigning
  1) "Apple Development: Byungsoo Ko (9782CF4X6D)"
     1 valid identities found            <- no Apple Distribution
```

and the only provisioning profile on disk belongs to **a different app
entirely** (`AK7RQAKLYW.com.daylike.app`, an Expo project). No App Store
profile for `com.bk.plankAI` existed locally, no App Store Connect API
key was configured (`~/.appstoreconnect/private_keys` absent), no
fastlane, no `Xcode-Token` in the login keychain.

**The export was run anyway, deliberately without
`-allowProvisioningUpdates`** so it could not create anything in the
Apple account, and it **succeeded**:

```
certificate type   Cloud Managed Apple Distribution
certificate SHA1   DAAE63069DCD7C04F694EFC9551D5A1ABCB40502
expires            4/2/27
```

Xcode fetches the cloud-managed distribution certificate on demand; it is
never a persistent login-keychain identity, which is exactly why
`find-identity` cannot see it and why reading `find-identity` alone
produces the wrong answer.

| | |
|---|---|
| team | `AK7RQAKLYW` — bay82 Studio LLC (Company) |
| bundle id | `com.bk.plankAI` |
| signing authority | `Apple Distribution: Byungsoo Ko (AK7RQAKLYW)` |
| chain | → Apple WWDR CA → Apple Root CA |
| profile | `iOS Team Store Provisioning Profile: com.bk.plankAI` |
| provisioned devices | **0** (= App Store, not ad-hoc) |

Three `.p8` files exist on this machine (`~/credentials`, `~/Downloads`).
**None was used and none was read.** Their purpose is unverified and no
App Store Connect Issuer ID is stored anywhere, so none of them is usable
as an ASC API key today. They are noted only so the founder knows they
are lying in `~/Downloads`.

---

## DISTRIBUTION ARCHIVE

Per the brief, `46`'s archive was **not** reused as the shipping artifact.
A fresh archive was built from the frozen source.

```
xcodebuild archive -project plankAI.xcodeproj -scheme plankAI \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Jeni_1.2.0_31_dist.xcarchive
** ARCHIVE SUCCEEDED **        2026-08-15 18:45:37Z
```

| | |
|---|---|
| CFBundleShortVersionString | `1.2.0` |
| CFBundleVersion | `31` |
| CFBundleIdentifier | `com.bk.plankAI` |
| Team | `AK7RQAKLYW` |
| Configuration | Release |
| Architectures | `arm64` |
| dSYMs | `plankAI.app.dSYM` · `JenifitWidgets.appex.dSYM` |

**THE FIRST ATTEMPT FAILED AND THE REASON IS WORTH RECORDING: THE DISK
WAS FULL.** `LLVM ERROR: IO failure on output stream: No space left on
device` during `GenerateDSYMFile`, with **191 MB free on a 460 GB
volume**. It is a failure mode that looks like a build error and is not
one — the compile succeeded, only the dSYM write failed. See PRODUCTION
HYGIENE → *Disk*.

### DID DISTRIBUTION CHANGE PRODUCT CONTENT? **NO.**

Two comparisons were run, not one.

**(A) fresh archive vs `46`'s archive** — does rebuilding the frozen
source reproduce the same product?

```
file inventory (name+size)   1292 vs 1292   IDENTICAL
Info.plist content           78 keys        IDENTICAL
JenifitWidgets strings                      IDENTICAL
main binary __TEXT extent    0 22249472     IDENTICAL
main binary size             25303008 both  IDENTICAL
main binary strings                         DIFFER
Assets.car                   63805608 both  same size, different bytes
```

The strings difference was chased to the bottom rather than waved at.
It is **78 strings out, 78 strings in, one-for-one**, and every one of
them is a build path baked into PostHog's vendored libwebp C sources:

```
/Users/bko/plankAI/build/dd46arch/SourcePackages/.../libwebp/enc.c
/Users/bko/plankAI/build/dd47/SourcePackages/.../libwebp/enc.c
```

Normalising **only** the DerivedData directory name makes the two
binaries' string tables **identical**, and the count of differing strings
that are *not* a build path is **0**. `Assets.car` differing at identical
size is `actool` non-determinism. `LC_UUID` differs because it is a
per-link identifier. **The product is the same product.**

**(B) exported distribution `.app` vs its own archive** — the literal
question the brief asks.

```
plankAI strings              IDENTICAL
JenifitWidgets strings       IDENTICAL
__TEXT extent                IDENTICAL
Info.plist content           IDENTICAL (78 keys)
appex Info.plist content     IDENTICAL
embedded.mobileprovision     DIFFERS   (expected — re-provisioned)
binary bytes                 DIFFER    (expected — re-signed)
```

The binary size delta was not accepted as "probably the signature", it
was proven to be the signature:

```
code signature dataoff   25087552  ==  25087552     <- identical
code signature datasize    215456  vs    213536
binary size delta            1920  ==  signature delta 1920
```

Identical `dataoff` means every byte of code preceding the signature sits
at the same offset in both. The only thing distribution changed is the
signature blob and the provisioning profile.

---

## ARCHIVE INSPECTION

Run against the **actual `.app` extracted from the uploaded `.ipa`**, not
against DerivedData.

| check | result |
|---|---|
| `get-task-allow` (app) | **`false`** |
| `get-task-allow` (JenifitWidgets.appex) | **`false`** |
| `get-task-allow` (profile) | `false` |
| `beta-reports-active` | `true` — the TestFlight entitlement only App Store signing grants |
| `codesign --verify --deep --strict` | valid on disk · satisfies its Designated Requirement |
| debug doors | **0** |
| UI-test doors | **0** |
| persona doors | **0** |
| food-debug doors | **0** |
| service-role credential | **0** |
| `.p8` / private key material | **0** |
| test-account password | **0** |
| localhost backend selected | **0** (see below) |
| staging backend | **0** |
| XCTest embedded | **none** (no `Frameworks` dir at all — static linking) |
| privacy manifests | 6, including the app's own `PrivacyInfo.xcprivacy` |
| `ITSAppUsesNonExemptEncryption` | `false` — export compliance answered in `Info.plist` |
| MinimumOSVersion | 17.6 |

**A ZERO IS ONLY EVIDENCE WITH A CONTROL**, the lesson this repo has
learned repeatedly. The same `strings` run that returns 0 for every door
returns `Supabase` 36 · `supabase` 20 · `jeni` 111 · `protein` 217 ·
`HealthKit` 6. The scan can see.

**THE TWO LOOPBACK STRINGS ARE NOT A BACKEND AND WERE VERIFIED, NOT
ASSUMED.** `strings` reports `localhost` 1 and `127.0.0.1` 1. The first
is `http://localhost:9999`, which is `defaultAuthURL` inside
`supabase-swift`'s own `Auth/Internal/Constants.swift` — a library
constant this app never selects, since it always passes
`SupabaseConfig.url` explicitly. The second is a bare `127.0.0.1` with no
scheme or port from a dependency. The demo backend is
`http://127.0.0.1:54321` and lives entirely inside `#if DEBUG`; the
discriminating markers all read **0**:

```
54321                                   0
http://127.0.0.1:54321                  0
demo-backend                            0
sb_publishable_ACJWlzQHlZjBrEguHvfOxg   0   (demo anon key)
isDemoBackend                           0
debug.invalid                           0
sb_publishable_HiM0VWqTOXOa6c…          1   <- CONTROL: production key present
```

**Production backend identity is intentional:** exactly one Supabase host
in the binary, `https://mtecqvykyeueumdynatd.supabase.co`. The other
hosts are RevenueCat, PostHog (EU), USDA FDC, `jenifit.app`, and
`api.anthropic.com` / `api.elevenlabs.io` — which `46` proved
unreachable (no `Info.plist` key → `.missingKey`; `VoiceProvider` never
instantiated). That finding is inherited, not re-derived.

### Entitlements, recorded from the signed binary

```
application-identifier                        AK7RQAKLYW.com.bk.plankAI
beta-reports-active                           true
com.apple.developer.applesignin               [Default]
com.apple.developer.healthkit                 true
com.apple.developer.healthkit.background-delivery  true
com.apple.developer.team-identifier           AK7RQAKLYW
get-task-allow                                false
```

No `aps-environment` — consistent with an app that uses local
notifications only.

---

## APPLE VALIDATION

**PASS. 0 errors, 0 warnings.**

Validation was not run as a separate step because Xcode's upload
destination performs it inline and aborts on failure. It cleared every
stage:

```
Analyzing package…
Sending analysis to App Store Connect…              -> accepted
Sending SPI analysis to App Store Connect…          -> accepted
Requesting upload instructions from App Store Connect…
```

From the distribution log bundle:

```
IDEDistribution.critical.log        0 bytes
"errors"   : [ ]
"warnings" : [ ]
"processingErrors" : [ ]
uploadEvent  errors='()'  warnings='()'
```

| classification | count |
|---|---|
| BLOCKING | 0 |
| NON-BLOCKING | 0 |
| UNKNOWN | 0 |

No source was modified for any warning, because there were none.

---

## UPLOAD

**PASS.**

| | |
|---|---|
| bundle id | `com.bk.plankAI` |
| version | `1.2.0` |
| build | `31` |
| delivery UUID | **`60934d9b-87d2-4563-82ca-42188a727a23`** |
| provider | `ddfd0a58-b0dd-4c6a-bbd2-1f4b0e6b5a41` |
| signing cert SHA1 | `DAAE63069DCD7C04F694EFC9551D5A1ABCB40502` |
| uploaded | 2026-08-15 **18:49:30 UTC** |
| final state | `Uploaded package is processing.` → `Upload succeeded.` |

`manageAppVersionAndBuildNumber` was set **false** so Xcode could not
silently rewrite `1.2.0 (31)`.

**THE UPLOAD WAS NOT DECLARED SUCCESSFUL BECAUSE A COMMAND EXITED 0.**
This repo has been bitten twice by `Executed 0 tests` + exit 0. The
success claim rests on four independent artifacts: the `Upload succeeded`
line, the `Uploaded to Apple` event stamped 18:49:30 UTC, a
zero-byte critical log, and a delivery UUID issued by Apple's content
delivery service.

**SUBMITTING FOR REVIEW WAS NOT DONE.** The brief authorises upload and
explicitly does not authorise submission.

---

## PROCESSING

**NOT VERIFIED — FOUNDER GATE.**

Apple accepted the package and reported it as processing. Whether it
*finished* processing, and whether Apple raised any post-processing issue
(invalid binary, missing compliance, entitlement or privacy-manifest
warning), **cannot be read from this machine**: App Store Connect is not
signed in in Chrome (`authResult=FAILED`), and no ASC API key + Issuer ID
pair exists to query the API.

Signing in was not attempted. Entering an Apple ID password and
completing 2FA is the founder's action, not one to automate.

---

## TESTFLIGHT

**NOT RUN — FOUNDER GATE.**

Build 31 cannot be pushed to a tester or installed from TestFlight from
this environment. The rule the brief sets — *test the build Apple
processed, not another locally installed build* — is exactly right and is
the reason no local install was substituted here. **No TestFlight test is
claimed.**

---

## PHYSICAL DEVICE

**NOT RUN — FOUNDER GATE.** No physical iPhone is reachable from this
session. Nothing about cold launch, onboarding, the paywall, the food or
weight doors, or Settings has been re-walked on the processed build.
`46`'s simulator walk of the Release binary stands as the most recent
evidence and is **not** a substitute for this gate.

---

## STOREKIT PURCHASE

**NOT RUN — FOUNDER GATE.** Purchase against Apple's sandbox requires a
sandbox account and physical interaction with Apple's purchase sheet.
Never invented.

### A CORRECTION TO THE BRIEF'S PRICE TABLE

The brief lists the expected products as:

```
yearly             $49.99
discounted yearly  $29.99      <- MISLABELLED
weekly             $5.99
```

**`46` measured `$29.99` as the QUARTERLY, not the discounted yearly** —
its record reads *"the year **$49.99** · quarter **$29.99** · week
**$5.99**"*. The source documents the discounted yearly separately:

```
RevenueCatConfig.swift:90   /// $34.99/year — 50% off the standard yearly
                            static let yearlyDiscount = "jenifit_yearly_discount"
```

So there are **four** prices in play, not three, and testing "$29.99
discounted yearly" would be testing a product that does not exist at that
price. **App Store Connect remains the source of truth** — the numbers
above are what to check against, not what to assert.

---

## STOREKIT RESTORE

**NOT RUN — FOUNDER GATE.**

Restore reachability was verified in shipping source so the founder knows
where to tap:

- subscription screen — `PlankApp/App/WallView.swift:81, 92, 111, 132`
  (`onRestore` on the stand-down screen, the first-plate welcome, the
  expired welcome, and the paywall itself)
- discounted-year sheet — `Views/Paywall/DownsellPaywallView.swift:505`
- Settings — `Views/Settings/AccountView.swift:282` (`restorePurchasesRow`)

---

## PREVIOUS REJECTION

**NOT RE-RUN ON TESTFLIGHT — FOUNDER GATE.**

The fix is in the uploaded binary and its behaviour is pinned in source.
`WallExitIntent.next` is a **total function with no "do nothing" case —
that absence is the fix**:

```
if smallerStepShownOnce || downsellShownOnce  -> .standDown
if abandonedPlan == "yearly"                  -> .discountedYear
otherwise                                     -> .smallerStep
```

`.standDown` renders `StandDownView(onSeePlans:onRestore:)`
(`WallView.swift:76-83`) — a real screen with a way back to the plans and
a restore, not a dismissal into nothing.

**One claim was checked rather than assumed.** `WallView.swift:210-233`
shows the smaller-step sheet's `onDismiss` can open the discounted year —
but **only** when `yearQueuedAfterSave` is set, and that is set **only**
by `onWantYear`, a voluntary "or the year" tap. A plain decline returns
to the plans. The one-offer-per-install law holds, and the discounted
year stays a door she opens herself.

Both flags are `@AppStorage`, so the post-relaunch state — the state that
produced the original dead X — is precisely the state that now stands the
wall down on the first press.

**This is source-level and simulator-level evidence. It is NOT the
TestFlight walk the brief asks for.**

---

## ACCOUNT DELETION

**NOT RUN — FOUNDER GATE.**

Reachability verified in source: `Views/Settings/AccountView.swift:275-280`,
a red row labelled **"delete account"**, carrying the guideline in its own
comment — *"Apple App Store Review Guideline 5.1.1(v) requires every
account-creating app to expose this in-app"* — presenting
`DeleteAccountSheet` which calls `AppSync.shared.deleteCurrentAccount()`.

No deletion-architecture audit was started. That is `46`'s P2 list and it
stays there.

---

## PRODUCTION HYGIENE

### Synthetic identities

| | |
|---|---|
| CREATED | **0** |
| DELETED | **0** |
| SURVIVING | **0** |

**This is a mechanical claim, not an intention.** An account is minted
when the app launches and `AuthService.bootstrap()` signs in anonymously
— the mechanism `45` measured and `46` isolated. This session **never
launched the app**: no `simctl boot`, no `simctl install`, no
`xcodebuild test`, no app run of any kind. The only commands issued were
git and hash reads, `xcodebuild archive` / `-exportArchive`, and
`strings` / `codesign` / `otool` inspection of files on disk.

Two simulators (`QA-iPhone16`, `QA-iPhoneSE3`) are still **Booted** —
they are leftovers from `46` and were not booted here. A booted simulator
with no app installed creates nothing.

No Supabase query was run in either direction, so no production counter
was read or moved. `46`'s closing state stands untouched.

### Disk — the one deletion, reported because it was a deletion

The first archive died on a full disk: **191 MB free of 460 GB.**
`build/` held **49 GB** across fourteen DerivedData directories
accumulated by earlier passes. Each was verified to have DerivedData
shape (`Build/`, `Logs/`, `SourcePackages/`, `ModuleCache.noindex`) and
checked to contain no `.xcarchive` before anything was removed.

**Removed (15 directories, all regenerable build cache):**
`dd` · `dd2` · `dd46` · `dd46arch` · `dd46b` · `dd46dev` · `dd46rel` ·
`ddpf` · `ddrel` · `DemoDD` · `DerivedData` · `DerivedDataRelease` ·
`ReleaseDD` · `SwiftExplicitPrecompiledModules` · `XCBuildData`

**Deliberately kept:** `build/Jeni_1.2.0_31.xcarchive` (`46`'s archive —
needed as the comparison baseline, and it earned its keep) and
`build/dd47`.

Free space went **191 MB → 24 GB**. No source file, no document, and no
archive was touched. The cost of this deletion is one slower cold build.

---

## APP STORE CONNECT

**NOT VERIFIED — FOUNDER GATE.** None of the following could be read,
because App Store Connect is not signed in here and no API credential
exists:

Build 31 selected · description · keywords · support URL · privacy URL ·
screenshots · age rating · App Privacy answers · export compliance ·
App Review contact · review notes.

Two things are known without ASC access and both matter:

**1. Export compliance is already answered in the binary.**
`ITSAppUsesNonExemptEncryption = false` is set in `Info.plist`, so
Build 31 should not stall on the export-compliance question.

**2. THE REPOSITORY'S METADATA DRAFT DESCRIBES A DIFFERENT APP, AND THIS
IS A REAL GUIDELINE 2.3 RISK.** `docs/app_store_metadata.md` is headed
*"For App Store Connect submission of v1.0.0"* and sells:

> subtitle: `calm, smart, at-home fitness`
> "Every day you get one workout…"
> "on-device form check… your camera watches your alignment"
> "128-move library"

The shipping product is a GLP-1-aware weight-loss coaching app built
around food, weight, doses, targets and a coach. **If the live listing
still reads like the draft, the screenshots and description do not
describe Build 31.** `24` flagged this and it has never been closed.

**This is not a claim that the live listing is wrong — it is a claim that
the only copy of it in this repo is wrong, and nobody has checked the
live one.** It is the single highest-value thing the founder can look at
in the next five minutes, and it is checked by opening the listing, not
by changing any file here. No metadata was modified.

---

## IAP REVIEW STATE

**NOT VERIFIED — FOUNDER GATE.** Whether each product is in a state Apple
can review cannot be read without ASC access.

The product identifiers **Build 31 actually contains** were read out of
the uploaded binary, so the founder has the exact list to check:

| product id | role | price per `46` / source |
|---|---|---|
| `jenifit_yearly_v2` | ACTIVE yearly | $49.99 (measured in Release) |
| `jenifit_quarterly` | ACTIVE quarterly | $29.99 (measured in Release) |
| `jenifit_weekly_v2` | ACTIVE weekly | $5.99 (measured in Release) |
| `jenifit_yearly_discount` | downsell yearly | $34.99 documented in source |
| `jenifit_yearly_discount_v2` | pre-staged | not resolved by active paths |

`jenifit_quarterly_discount` and `jenifit_weekly_discount` are declared in
`RevenueCatConfig` but do **not** appear as strings in the shipped binary,
so Build 31 does not expose them.

**The pre-staged IDs are self-gating by design** — if a RevenueCat
offering contains no package with that product id, the card simply does
not render (`RevenueCatConfig.swift:98-103`). So a product missing from
ASC hides itself rather than showing a broken row. **That is the reason
this is not being called a blocker from here** — but it is also the
reason it must be *looked at* rather than assumed: a product that DOES
resolve and is NOT reviewable would block review, and only ASC can say
which resolve.

**No product was hidden in code as a shortcut.** No source changed.

---

## APP REVIEW NOTE

Ready. Every sentence is verified against shipping source, and the
verification is listed after it.

```
Hello App Review,

Thank you for the previous report about the subscription screen's close
button.

Build 31 fixes it. The close button now always responds. The first close
may present one alternative offer; declining it returns to the
subscription plans, and closing again leaves the purchase screen for a
non-purchase screen with "see the plans" and "restore purchases". From
there you can return to the plans and close again. This holds after the
app is relaunched, which was the state that previously produced an
unresponsive button.

At most one alternative offer is presented per install. After that,
close always exits the purchase screen.

Restore Purchases is available on the subscription screen and in
Settings.

No account is required to use the app, so no demo account is needed.
Sign in with Apple is optional. Account deletion is available in
Settings > Account > "delete account".

Thank you.
```

| sentence | verified at |
|---|---|
| close always responds; one offer per install; then exits | `WallExitIntent.swift:47-61` — total function, no "do nothing" case |
| declining returns to the plans | `WallView.swift:210-233` — plain `onDismiss` only clears the sheet |
| a non-purchase screen with see-the-plans and restore | `WallView.swift:76-83` — `StandDownView` |
| holds after relaunch | both flags are `@AppStorage` |
| restore on the subscription screen and in Settings | `WallView.swift:81,92,111,132`; `AccountView.swift:282` |
| account deletion in Settings | `AccountView.swift:275-280` |
| no account required | anonymous-first auth; sign-in is an upgrade, not a gate |

Contains no architecture, no test counts, no Supabase, no migrations, no
deletion ledger, no P0/P1 vocabulary, no audit history. **No review
credentials are named because none are needed** — the app runs without an
account.

**One honest limit: the sequence is proven by source and by `46`'s
Release-binary simulator walk. It has not been re-walked on the
Apple-processed build.** If the founder wants the note to say "we
re-tested this in this build", that walk has to happen first.

---

## WHAT'S NEW

```
Your record, in one place — and correctable.

• Food, weight, doses and side effects all live in one record. Fix or
  remove any entry, including ones from an earlier day.
• See and change the numbers behind your plan: goal weight, pace,
  height, and your daily calorie and protein targets.
• More reliable sign-in, restore and syncing, so your record follows
  you to a new phone.
• Fixes to subscription screen navigation.
```

Every line traces to shipped work: the ledgers (`33`, `34`, `36`), the
correctable past (`34`, `36`), `JKGoalRitual` + `GoalWeightStore` (`29` —
until then no surface could show or change the goal weight),
`JKPlanNumbersSheet` 4 rows → 7 (`31`), the restore ordering fix (`43`),
the spine grants (`45`), and `WallExitIntent`.

Deliberately absent: anything about account deletion internals, orphaned
accounts or the handoff (customer-invisible, and naming them invites
questions the copy cannot answer); any security or privacy-defect
language; any number that was never measured; the word "AI", which the
design law bans in user copy.

**Assumption the founder must check:** the last version actually
*released* to customers is not readable from here. 1.2.0 (30) was
uploaded and never released; 1.1.7 (28) was rejected. The text describes
the 1.2.0 line as a whole and overclaims nothing either way.

---

## BLOCKERS

**P0: 0 · P1: 0.**

Nothing found in this session blocks review. The distribution artifact is
clean on every mechanical check that can be run without Apple.

What remains is **not a defect list, it is a gate list** — six things that
need a human, a phone, or an Apple login:

1. Confirm Build 31 finished processing in App Store Connect
2. Install Build 31 from TestFlight on a physical iPhone
3. One reviewer-shaped walk of the processed build
4. StoreKit sandbox purchase · restore · cancel
5. Re-run the rejection sequence on the TestFlight build
6. Account deletion on the processed build, synthetic identity only

Plus one thing that is **not** a gate and **is** a risk:

7. **Verify the live App Store listing describes this product.** The only
   copy of the metadata in this repo describes a v1.0.0 at-home fitness
   app with a plank form checker. See APP STORE CONNECT.

---

## FINAL HANDOFF

| question | answer |
|---|---|
| 1. Did source change after freeze? | **NO** — 1573 files, hash-identical, verified twice |
| 2. Is the archive actually distribution-signed? | **YES** — `Apple Distribution: Byungsoo Ko (AK7RQAKLYW)`, cloud-managed, App Store profile, 0 provisioned devices |
| 3. Is `get-task-allow` absent/false? | **FALSE** — app, widget extension, and profile |
| 4. Did distribution change product content? | **NO** — strings identical; size delta 1920 B == signature delta |
| 5. Did Apple validation pass? | **YES** — 0 errors, 0 warnings |
| 6. Did Build 31 upload? | **YES** — delivery `60934d9b-87d2-4563-82ca-42188a727a23`, 18:49:30 UTC |
| 7. Did Apple process Build 31? | **UNKNOWN** — accepted and reported processing; completion needs ASC |
| 8. Did Build 31 reach TestFlight? | **NOT RUN** |
| 9. Was the processed build tested on a device? | **NOT RUN** |
| 10. Did purchase pass? | **NOT RUN** |
| 11. Did restore pass? | **NOT RUN** |
| 12. Did cancel pass? | **NOT RUN** |
| 13. Did the rejected X sequence pass on TestFlight? | **NOT RUN** — fix present and source-verified |
| 14. Did account deletion pass? | **NOT RUN** — reachability source-verified |
| 15. How many test identities survive? | **0** — none created; app never launched |
| 16. Are all visible IAPs reviewable? | **UNKNOWN** — 5 product ids enumerated; needs ASC |
| 17. Is ASC metadata complete? | **UNKNOWN** — not signed in; 2.3 listing risk named |
| 18. What manual founder action remains? | the six gates + the listing check |
| 19. Is Build 31 ready to add for review? | **YES**, once processing is confirmed |
| 20. Is Build 31 ready to submit for review? | **NO** — not until the device gates pass |

---

```
SOURCE FREEZE:            HELD
VERSION:                  1.2.0
BUILD:                    31
DISTRIBUTION SIGNING:     PASS
get-task-allow:           FALSE
APPLE VALIDATION:         PASS
UPLOAD:                   PASS
APPLE PROCESSING:         PENDING
TESTFLIGHT:               NOT RUN
PHYSICAL DEVICE:          FOUNDER ACTION REQUIRED
PURCHASE:                 FOUNDER ACTION REQUIRED
RESTORE:                  FOUNDER ACTION REQUIRED
CANCEL:                   NOT RUN
PREVIOUS REJECTION:       NOT RUN
ACCOUNT DELETION:         NOT RUN
VISIBLE IAPS REVIEWABLE:  UNKNOWN
SURVIVING TEST DATA:      0
APP REVIEW NOTE:          READY
APP STORE CONNECT:        NOT READY
CODE CHANGES AFTER FREEZE: 0
P0:                       0
P1:                       0
READY TO ADD FOR REVIEW:  YES
READY TO SUBMIT FOR REVIEW: NO
```

**FOUNDER ACTION — the one smallest blocker:**

> Open App Store Connect and confirm Build 31 (1.2.0) finished
> processing. Everything else is downstream of that one fact.

**BUILD 31 IS NO LONGER AN ENGINEERING PROJECT. IT IS A SUBMISSION
ARTIFACT WITH ONE NAMED BLOCKER: IT HAS NOT BEEN RUN ON A PHONE SINCE
APPLE TOUCHED IT.**
