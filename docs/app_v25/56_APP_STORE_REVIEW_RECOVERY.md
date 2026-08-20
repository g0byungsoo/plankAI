# 56 — APP STORE REVIEW RECOVERY

**This is not a product pass.** It is a release/review incident record for
the 2026-08-20 rejection of **1.1.7 (32)**. Pass 55 is closed and was not
reopened. Nothing here was archived, uploaded or submitted.

Written so that if this rejection — or one like it — happens again, the
next reader has the mechanism, not just the outcome.

---

## 1. THE REJECTION, VERBATIM

```
Submission ID:     b7b6a6d4-914a-44d0-b391-58d18db9aeef
Review date:       August 20, 2026
Review Device:     iPhone 17 Pro Max
Version reviewed:  1.1.7 (32)
```

**Guideline 3.1.2(c) — Business — Payments — Subscriptions**

> One or more auto-renewable subscriptions are marketed in the purchase
> flow in a way that may mislead or confuse users about the subscription
> terms or pricing. Specifically:
> - The auto-renewable subscription displays the weekly calculated pricing
>   for the subscription more clearly and conspicuously than the billed
>   amount.
>
> Next steps: Revise the auto-renewable subscription purchase flow to
> ensure that the billed amount is the most clear and conspicuous pricing
> element in the layout. Any other pricing elements, including free trial,
> introductory pricing, and calculated pricing information, must be
> displayed in a subordinate position and size to the total billed amount.
> Factors that contribute to whether the billed amount is clear and
> conspicuous include, but are not limited to, the font, size, color, and
> location of the billed amount.

**Guideline 5.6 — Developer Code of Conduct**

> The app attempts to manipulate customers into making unwanted In-App
> Purchases. Specifically, after we dismissed the purchase screen, another
> one was displayed.

Both were treated as authoritative. Neither was argued with.

The reviewer's own resolution text is the operative spec for 3.1.2(c) —
it is more specific than the public guideline, whose 3.1.2(c) body only
requires that you "clearly describe what the user will get for the price"
and defers to Schedule 2 of the Developer Program License Agreement. The
"clear and conspicuous / subordinate in position and size" language names
four measurable factors, and this pass treated those four as the design
law: **font, size, colour, location.**

---

## 2. STATE BEFORE ANY CHANGE

| | |
|---|---|
| PRE-FIX BRANCH | `feat/app-v2` |
| PRE-FIX HEAD | `8d9b0b3e5a1ef2985b746dc1dcec4daa2a11b5c9` |
| PRE-FIX REMOTE HEAD | `af9e962649f92ee5ff6f0c8a63b5ee829c873605` (8 commits behind local) |
| PRE-FIX DIRTY TREE | 2 files, both `.gstack/` browser-tool logs |
| PRE-FIX STAGED | none |
| PRE-FIX UNTRACKED | none |
| MARKETING_VERSION | `1.2.0` |
| CURRENT_PROJECT_VERSION | `33` |
| Baseline Release build | **BUILD SUCCEEDED, 0 errors** (run before touching anything) |

### 2.1 The Pass 55 checkpoint — committed, then pushed

Pass 53/54/55 were **fully committed but never pushed**: `feat/app-v2` was
8 commits ahead of `origin/feat/app-v2`, 0 behind. All eight are
legitimate completed product work (`a151a71` regimen … `8d9b0b3` the pass
55 record). No new commit was needed to preserve them; they needed a push.

The tree at `8d9b0b3` was verified by a Release build **before** the push
and before any edit.

```
PRE-FIX COMMITS CREATED : 0  (nothing was uncommitted)
PRE-FIX PUSH            : af9e962..8d9b0b3  feat/app-v2 -> feat/app-v2
VERIFIED                : git ls-remote origin refs/heads/feat/app-v2
                          → 8d9b0b3e5a1ef2985b746dc1dcec4daa2a11b5c9
                          local == remote, 0 ahead / 0 behind
```

The two `.gstack/` files were **not** committed. They are browse-tool
audit logs from a 2026-08-18 web search, the directory is in
`.gitignore`, and the two files are tracked only because they predate
that rule. They are disposable and unrelated to this work. They are the
only dirt in the tree at the end of this session, and they are named here
so "clean" is never claimed for something unexplained.

---

## 3. ROOT CAUSE — 3.1.2(c)

`PaywallView.anchorTierRow` built the price column in this order:

```swift
Text(perWeekLead)                                        // CALCULATED
  .font(.custom("Fraunces72pt-SemiBold", size: m.tierPriceSize + 1))
  .foregroundStyle(Palette.textPrimary)
+ Text(" /wk") …
Text(billedLine)                                         // THE CHARGE
  .font(.system(size: 11))
  .foregroundStyle(Palette.cocoaTertiary)
```

On the review device (`metrics(forHeight:)` else-branch, `tierPriceSize`
21) that is a **22pt serif in the primary ink, first in reading order**,
against an **11pt sans in the tertiary tone, second**. Every one of
Apple's four factors — font, size, colour, location — pointed at the
calculated rate.

**The tell was already in the file.** `perWeekEquivalent`'s doc comment
read:

> rendered at 10pt vs the 20pt billed price (Apple 3.1.2c: the equivalent
> must stay subordinate to the actual charge)

…describing compliance the render never implemented, on a helper whose
only consumer was the accessibility label. The shipping visual path was
`perWeekLead`, which did the exact inverse — and whose *name* encoded the
defect.

The deeper cause is structural and is this repo's §36 lesson for the
third time: **the rule lived inside a view body.** Four literals with
nothing able to read them, so no test could hold them and no reviewer of
the diff could see a rule being inverted.

The same inversion existed on `UpgradeMomentView`, plus a worse instance:
its **headline** read `keep going for $1.99 a week.` — a calculated rate
in the most conspicuous element on the screen while the charge sat at
11pt inside the card.

---

## 4. ROOT CAUSE — 5.6

`WallView.paywall(placement:)`:

```swift
onDismiss: { triggerExitIntent(abandonedPlan: nil) },
onPurchaseCancelled: { plan, _ in … triggerExitIntent(abandonedPlan: plan) }
```

`WallExitIntent.next` then answered:

| trigger | result |
|---|---|
| plain X, fresh install | `.smallerStep` → **SmallerStepSheet** — *"what if it was just a week?"* |
| yearly Apple-sheet cancel | `.discountedYear` → **DownsellPaywallView** |
| quarterly / weekly cancel | `.smallerStep` |
| either once-flag already spent | `.standDown` |

The first row is the reviewer's attachment, exactly.

**Why it survived a previous 5.6 pass.** On 2026-08-10 the app was
rejected for the opposite defect — a dead X — and the answer was to make
every press produce *something*, choosing an offer as that something:
"one tier-matched offer per install, then the wall stands down", reasoned
in-code as *"an offer is a recovery, a repeated offer is pressure."*

That made the **spent** state compliant. A reviewer meets the **fresh**
state. The compliant branch belonged to the returning user; the defective
branch was the only one a first launch could reach. Apple's line is not
*how many* — it is *none*.

---

## 5. EVERY PURCHASE SURFACE FOUND

| surface | reachable in Release at 1.1.7 (32)? | disposition |
|---|---|---|
| `PaywallView` (the wall) | yes — the `.wall` phase | **kept**, price hierarchy fixed |
| `SmallerStepSheet` | yes — auto-shown on dismissal | **DELETED** |
| `DownsellPaywallView` | yes — auto-shown on yearly cancel; also via the reclaim row | **DELETED** |
| the reclaim row (in `PaywallView`) | yes — but gated on `downsellShownOnce`, which only the auto-show ever set | **DELETED** (unreachable once the auto-show went) |
| `UpgradeMomentView` | yes — post-entitlement, weekly subscribers, program day ≥ 6, once ever | **kept**, price hierarchy fixed |
| `CancellationWinbackSheet` | **no** — only call site is `DebugPreviewRoutes` (`#if DEBUG`) | named, not deleted — no shipping path at HEAD, not part of this rejection |
| `PricingCard` (`Components.swift`) | **no** — constructed only inside `#Preview` blocks | named, not changed |
| `ForgingRevealView` | post-purchase receipt, states the charge (`"you chose: $X · renews quarterly"`) | compliant as-is, unchanged |

### Every automatic purchase-surface transition found

1. `onDismiss` → `triggerExitIntent` → offer sheet. **REMOVED.**
2. `onPurchaseCancelled` → `triggerExitIntent` → offer sheet. **REMOVED**
   (analytics only now).
3. `showingSmallerStep`'s `onDismiss` → `yearQueuedAfterSave` →
   `showingDownsell`. A sheet queued to open *after another sheet
   finished dismissing*. **REMOVED.**
4. DEBUG timers `--uitest-save-moment` / `--uitest-open-downsell`
   (`asyncAfter(2.2)`) and the root-level `--uitest-downsell-preview`
   cover. **REMOVED** — a QA door that presents an offer sheet is still
   an offer sheet in the tree.
5. `maybeOfferUpgradeMoment` → `UpgradeMomentView`. **KEPT.** It is not
   reached from a dismissal; it is a once-ever upgrade offer to an
   existing subscriber, which 3.1.2(b) contemplates. Its own dismissal
   (`onDone`) sets a flag false and chains nothing.

---

## 6. WHAT CHANGED

### 6.1 `SubscriptionPriceBlock` (new)

The decision moved out of the view body. One type owns which string is
dominant, which is subordinate, and at what size:

```
dominant     = the billed amount, base + 1 pt, primary ink, rendered first
periodSuffix = " /year" | " /quarter" | " /week"  (compact: " /yr" | " /qtr" | " /wk")
subordinate  = "<weekly equivalent> a week", 11pt, receded, rendered second
               nil for the weekly tier — its charge already IS the weekly rate
```

`PaywallView.anchorTierRow` and `UpgradeMomentView.quarterCard` render
from it and hold **no pricing literal of their own**.

### 6.2 Deleted, call sites proven empty first

```
PlankApp/App/WallExitIntent.swift               62 lines
PlankApp/Views/Paywall/SmallerStepSheet.swift  387 lines
PlankApp/Views/Paywall/DownsellPaywallView.swift 744 lines
plankAITests/WallExitIntentTests.swift         128 lines
```

plus, from `WallView`: `showingDownsell`, `showingSmallerStep`,
`yearQueuedAfterSave`, `downsellShownOnce`, `smallerStepShownOnce`,
`lastAbandonedPlan`, `downsellTrigger`, `triggerExitIntent`, and both
sheet modifiers. **There is no state left in `WallView` that can present
a price** — which is why the fix is structural rather than conditional.

Kept deliberately, each now carrying a note so the next reader does not
rewire it by accident:

- the **X** itself — removing it would rebuild the 1.1.7 (28) dead end
- `RevenueCatConfig.discountOfferingID` — the RevenueCat offering and its
  grandfathered subscribers still exist; nothing in the client reads it
- the `downsell_*` analytics cases — historical PostHog series keep their
  names and stop cleanly rather than becoming unresolvable

### 6.3 The removed second price

`weeklyAnnualTruth` — *"$311/year if billed weekly"* — is gone. It sat in
the price column Apple measured, on a row whose actual charge is $5.99,
and it stated a figure larger than anything ever billed.

### 6.4 Savings claims — verified, kept

Checked mechanically against the products as priced at review
(year $49.99 · quarter $29.99 · week $5.99):

```
weekly annualized  = 5.99 × 52          = 311.48
yearly   save 84%  = (311.48 − 49.99) / 311.48 = 83.95%  → 84  ✓ matches
quarterly per week = 29.99 / 13         = 2.3069        → $2.31 ✓ matches
quarterly save 61% = (5.99 − 2.3069) / 5.99 = 61.49%    → 61   ✓ matches
```

Both are computed at render time from two live StoreKit prices, both are
comparisons against the weekly plan visible on the same screen, and both
sit at 12pt in the secondary tone in the *left* column. They are
subordinate on all four of Apple's factors and Apple did not cite them.
Kept unchanged — changing them would be a conversion decision this pass
has no mandate for.

---

## 7. THE FINAL HIERARCHY

Rendered, measured on device buckets, not asserted from constants.

| tier | dominant (charge) | subordinate (calculated) |
|---|---|---|
| the year | **$49.99** ` /year` — Fraunces SemiBold 22pt, `textPrimary`, first | *$0.96 a week* — 11pt, `cocoaTertiary`, second |
| the quarter | **$29.99** ` /quarter` — same treatment | *$2.31 a week* |
| one week | **$5.99** ` /week` | *none* — the charge is the weekly rate |

Ratio at the review device: **22pt primary vs 11pt tertiary — exactly
2×**, plus a tone step and reading order. Not a technical difference.

**CTA**: `keep my plan · $49.99 today`, and it follows selection —
proven by walk, not by reading (§9).

**Smallest phone (iPhone SE, `tierPriceSize` 19)**: `$47.99 /yr` ·
`$24.99 /qtr` · `$5.99 /wk`, untruncated.

### 7.1 Two failed cuts, both caught by filming

The first cut spelled the period out at every width and **clipped on SE**
(`$47.99 /ye…`, `$24.99 /quar…`). The charge was intact and dominant, but
a truncated term is its own clarity problem.

The second cut tried `fixedSize()` on the charge with `layoutPriority(1)`
so the period would yield first. **It made it worse** (`$47.99…`, period
gone entirely) — the pass-51 trap again, recorded there as *"with
fixedSize the floor never engages"*. A `minimumScaleFactor` cannot fire
inside a run that has been told never to compress.

The shipped cut is a single concatenated run that scales as one unit,
with an **adaptive period**: spelled out where there is room, `/yr ·
/qtr · /wk` on the bucket that has none. Refilmed clean on both devices.

Screenshots: `56_evidence/shots/` —
`before_17promax_paywall.png` · `after_17promax_paywall.png` ·
`se_firstcut_period_clipped.png` · `after_se_paywall.png` ·
`after_17promax_dismissal_standdown.png`.

*(Simulator screenshots render the DEBUG mock prices — $47.99 / $24.99 /
$5.99 — because RevenueCat resolves no products in a simulator with no
StoreKit configuration attached to the scheme. The layout, hierarchy and
type scale are the shipping ones; only the numerals differ from the live
$49.99 / $29.99 / $5.99. Apple's own attachment is the before-image at
live prices.)*

---

## 8. BEHAVIOUR, EXIT BY EXIT

| exit | before | after |
|---|---|---|
| X on the wall | SmallerStepSheet | `StandDownView` — no price, no offer |
| Apple sheet cancelled (year) | DownsellPaywallView | stays on the wall; abandon analytics only |
| Apple sheet cancelled (quarter/week) | SmallerStepSheet | stays on the wall |
| purchase failure | (same exit-intent path) | stays on the wall |
| second X | stand-down | stand-down |
| relaunch after a dismissal | reclaim row could appear | nothing; the flag that unlocked it no longer exists |
| Restore with no entitlement | alert | alert, unchanged, no offer follows |
| sign-in | sheet | sheet, unchanged, no offer follows |
| successful purchase | entitlement stream leaves the wall | unchanged |

**Where a dismissal lands** (`StandDownView`, unchanged by this pass):
states no price, makes no offer, and keeps all three doors — *see the
plans* · *already subscribed · restore* · *signed in before? sign in*.
Reversible by her choice, never by ours.

---

## 9. PROOF

### RED — observed before any fix

**5.6** — against the unmodified shipping rule, product code untouched:

```
Executed 3 tests, with 8 failures
  "A plain dismissal produced smallerStep — a second purchase surface."
  "Cancelling the yearly sheet produced discountedYear — …"
```

The passing combinations are the controls, and they are the finding: the
already-spent states stood down correctly even then.

**3.1.2(c)** — `SubscriptionPriceBlock.make` temporarily set to the
arrangement as shipped, transcribed literally from
`PaywallView.anchorTierRow`:

```
Executed 10 tests, with 18 failures
  "year @21.0: the dominant price is '$0.96', which is not the billed amount."
  "quarter @21.0: the dominant price is '$2.31', …"
```

**2 of the 10 passed, and they locate the defect precisely**:
`testCalculatedEquivalentsAreDecisivelySmaller` and
`testTheChargeHoldsTheStrongerContrast`. The size ratio and the contrast
were *already correct*. The type scale was never the bug — **which string
occupied the dominant slot was.**

Logs: `56_evidence/RED_5.6_wall_exit_intent.log`,
`56_evidence/RED_3.1.2c_price_hierarchy.log`.

### GREEN

| suite | result |
|---|---|
| Both invariant suites | **18 tests, 0 failures** |
| Full app unit suite | **1520 executed · 2 skipped · 0 failures** |
| PlankFood | **249 / 249** |
| PlankSync | **29 / 29** |
| Release build | **BUILD SUCCEEDED, 0 errors** (19,217-line log) |

**Count reconciled exactly**: pass 55's 1509 passed + 2 skipped = 1511
executed. 1511 + 18 added (12 pricing + 6 dismissal) − 9 removed
(`WallExitIntentTests`) = **1520**.

*(PlankFood reads 249 against pass 55's recorded 242. `Packages/` is
byte-untouched by this pass — `git diff 8d9b0b3 -- Packages/` is empty —
so the delta is a measurement difference, not a change. Reported as
measured rather than reconciled to the older figure.)*

### The regression coverage now standing

| # | claim | held by |
|---|---|---|
| A | a calculated rate cannot outrank the charge | `SubscriptionPricingHierarchyTests` (size, colour, location) |
| B | a dismissal cannot trigger another purchase surface | `PurchaseDismissalInvariantTests` + 3 UI walks |
| C | selection changes the dominant charge | `testEveryTierLeadsWithItsChargeAndTheCtaFollowsSelection` |
| D | the CTA names the selected charge | same |
| E | Restore reachable and invocable | `testRestoreSignInTermsAndPrivacyAreReachable` |
| F | Terms + Privacy reachable and they open | same |
| G | purchase cancel presents no offer | `testCancellingThePurchaseSheet…` + the KeepWall leg |
| H | purchase failure presents no offer | same path — both route to the same callback, which now only tracks |
| I | relaunch resurrects no offer | `testDismissingTheWall…` (terminate → relaunch → assert) |
| J | selection, CTA and plumbing agree | C/D, plus the row labels are built from the same block the purchase uses |

`PurchaseDismissalInvariantTests` is a **source sweep**, the mechanism
p54 used for the notification chokepoint: it asserts the three deleted
types are absent from disk and unused anywhere in the app target, that
`WallView` carries none of the presentation state, that `WallView`
**defers nothing** (`asyncAfter`, `DispatchQueue.main.async`,
`Task.sleep` — a sheet one runloop later is the same sheet), and that the
stand-down prints no currency amount while keeping all three doors.

### Reviewer walk — iPhone 17 Pro Max, Apple's exact device

`F350D22E-E76D-430E-A399-60FF735254B6`, fresh install each launch.

```
PurchaseFlowReviewWalkUITests                            4 passed, 0 failed, 68.0s
  testCancellingThePurchaseSheetPresentsNoSecondPurchaseSurface   passed
  testDismissingTheWallPresentsNoSecondPurchaseSurface            passed
  testEveryTierLeadsWithItsChargeAndTheCtaFollowsSelection        passed
  testRestoreSignInTermsAndPrivacyAreReachable                    passed
WallDismissalUITests  / testDismissingTheWallPresentsNoOffer      passed
WallExitWalkUITests   / testWallCloseButtonAlwaysStandsDownAndNeverOffers  passed
```

### The Release binary itself

`strings`/byte probes against `Release-iphonesimulator/plankAI.app/plankAI`.

**An absence is only evidence with a control that fires**, and the naive
version of this check is worthless here: Swift stores string literals of
**≤ 15 UTF-8 bytes inline** (small-string optimisation), so `"keep my
plan"` (12 B) and `"see the plans"` (13 B) read 0 *while present*. Only
probes longer than 15 bytes are admissible.

```
POSITIVE CONTROLS (must be > 0)
  "already a member? sign in"      2     "money-back guarantee"          2
  "paced to ACSM guidance"         2     "apple will ask to confirm"     2
  "your answers are saved and your plan"                                 2

DELETED OFFER SURFACES (must be 0)
  "what if it was just a week"     0     "same plan. same jeni."         0
  "or the year, at the lower price" 0    "your discounted year is saved" 0
  "nothing was charged"            0     "DownsellPaywallView"           0
  "SmallerStepSheet"               0

REMOVED PRICE LINE (must be 0)
  "/year if billed weekly"         0

DEBUG DOORS (must be 0)
  "--uitest-downsell-preview" 0  "--uitest-inapp-qa"   0
  "--uitest-save-moment"      0  "--uitest-wall-spent" 0
```

**The reviewer cannot reach *"what if it was just a week?"* in a Release
build. The sentence is not in the binary.**

---

## 10. SCOPE — WHAT WAS NOT TOUCHED

`git diff 8d9b0b3 --stat` is 19 files. Mechanically verified **EMPTY**:

```
PlankApp/Payment · PlankApp/Auth · PlankApp/App/AppPhase.swift ·
PlankApp/Info.plist · plankAI.entitlements · JenifitWidgets ·
PlankApp/BodyScan · PlankApp/Notifications · PlankApp/Health ·
supabase/ · Packages/ · scripts/
```

All three files that **declare** a `@Model` (`ChatModels.swift`,
`JeniMemory.swift`, `PlankSync/Models.swift`) are **ZERO-DIFF** — there
is no store migration to fail.

**No SQL. No migration written or applied. No deploy. No production
mutation. No App Store Connect configuration touched.** No subscription
product or price was changed anywhere — every price on screen still comes
from `storeProduct.localizedPriceString`, localized by StoreKit, and
Release builds still refuse to render an invented one.

---

## 11. VERSION AND BUILD — FOUNDER DECISION, NOT APPLIED

**Nothing was changed.** The repo still reads:

```
MARKETING_VERSION        = 1.2.0
CURRENT_PROJECT_VERSION  = 33
```

This pass deliberately preserved the archive-time convention pass 55
recorded (`archive-time bump 33→34`, a founder gate).

**There is a discrepancy the founder must resolve, and it is why the
`1.1.8 (34)` in the brief was not applied blindly:**

- Apple reviewed **1.1.7 (32)**.
- The repo has read `MARKETING_VERSION = 1.2.0` since `9871066` (v25 E2).
  `1.1.7` was last in this file at `57c6edd` and was replaced.
- `CFBundleShortVersionString` is `$(MARKETING_VERSION)`, and App Store
  Connect requires the binary's short version to match the version record
  it is attached to. So **the archived binary carried a marketing version
  that is not what is committed** — set at archive time, outside git,
  the same way the build number is.

Constraints that are certain from this machine:

- build **32 is consumed** (uploaded and reviewed); ASC will refuse it.
- the status of build 33 **cannot be determined from here** — there is no
  ASC credential, `fastlane` config, or export options plist on this
  machine, and this pass did not attempt to authenticate.

So the correct next pair depends on facts only App Store Connect holds.
**Recommendation, for the founder to confirm against ASC:**

- if the resubmission goes against a **new** version record `1.1.8`, then
  `MARKETING_VERSION = 1.1.8` and `CURRENT_PROJECT_VERSION = 34` is
  consistent with both the reviewed train and pass 55's recorded gate;
- if it goes against the **existing rejected** `1.1.7` record, the
  marketing version must stay `1.1.7` and only the build advances;
- either way the committed `1.2.0` should be reconciled deliberately
  rather than left to diverge again at the next archive.

**PREPARED, NOT APPLIED.**

---

## 12. THE APP REVIEW RESPONSE

Every sentence below was checked against the final implementation.

> Hello App Review,
>
> Thank you for the clear feedback. We addressed both issues in this
> submission.
>
> For Guideline 3.1.2(c), the subscription selection screen now makes the
> amount actually billed the primary and most prominent price for every
> plan. On each option the billed amount is rendered first, in the largest
> type on the row and in the highest-contrast colour, with its billing
> period beside it. Where a calculated weekly equivalent is shown it
> appears beneath the billed amount at roughly half the type size and in a
> lighter tone. The weekly plan shows only its billed weekly price, and we
> removed the annualized figure that previously appeared on that row. The
> purchase button states the amount that will be charged today for the
> selected plan.
>
> For Guideline 5.6, dismissing the purchase screen no longer presents
> another purchase or alternative-offer screen. We removed the automatic
> post-dismissal offer flow entirely, along with the two offer screens it
> presented. Closing the purchase screen now leads to a screen that states
> no price and makes no offer, from which the customer can choose to view
> the plans again, restore a purchase, or sign in. Cancelling the App
> Store purchase sheet returns the customer to the same purchase screen
> and presents nothing further.
>
> Restore Purchases, sign-in for existing members, Terms of Use, and
> Privacy Policy all remain directly accessible from the subscription
> screen.
>
> Thank you for reviewing the updated build.

---

## 13. NAMED, NOT FIXED

- **`CancellationWinbackSheet`** — a retention surface with no shipping
  call site at HEAD (only `DebugPreviewRoutes`, `#if DEBUG`). Not
  implicated in this rejection; left in place rather than widening the
  diff. If it is ever wired up, it must not be wired to a dismissal.
- **`PricingCard`** (`Components.swift`) — a design-system row with a
  `perWeekEquivalent` slot, constructed only inside `#Preview` blocks, so
  it does not ship. If it is ever adopted, it should render from
  `SubscriptionPriceBlock`.
- **`MARKETING_VERSION` divergence** — §11.
- **StoreKit configuration is not attached to the scheme.** There is a
  `PlankApp/Resources/absmaxxing.storekit` file, unreferenced. Because of
  this, simulator runs exercise the DEBUG mock-price path rather than real
  StoreKit products. **The purchase transaction itself — a real
  StoreKit sheet completing a real purchase — was NOT proven in this
  environment** and remains a device/sandbox check (§14).

---

## 14. WHAT STILL NEEDS HARDWARE OR THE FOUNDER

Simulator evidence is not device evidence, and none is claimed as such.

1. One physical-device pass on the purchase screen at default and large
   Dynamic Type.
2. A real sandbox purchase, restore, and cancel against live StoreKit
   products — including confirming the Apple sheet's price matches the
   row and the CTA for each of the three plans.
3. Resolve the version/build question against App Store Connect (§11).
4. Archive · export · upload · submit — all founder-gated, none performed.

---

## FINAL VERDICT

```
PRICING ROOT CAUSE:              the tier row drew the CALCULATED weekly rate
                                 first, at 22pt in the primary ink, and the
                                 billed amount second at 11pt in the tertiary
                                 tone — all four of Apple's factors inverted.
                                 The rule lived inside a view body (§36).
ANNUAL BILLED AMOUNT DOMINANT:   YES — $49.99 /year, 22pt primary, first
QUARTERLY BILLED AMOUNT DOMINANT:YES — $29.99 /quarter, 22pt primary, first
WEEKLY BILLED AMOUNT DOMINANT:   YES — $5.99 /week, 22pt primary, only price
CALCULATED PRICES SUBORDINATE:   YES — 11pt tertiary, second, ~half size;
                                 removed entirely from the weekly row
CTA BILLING DISCLOSURE:          "keep my plan · $X today", follows selection,
                                 walk-proven on all three tiers
AUTOMATIC DOWNSELL AFTER DISMISSAL: NONE — the transition, the rule and both
                                 offer screens are deleted, not gated
PURCHASE CANCEL → SECOND PAYWALL: NO — analytics only (walk-proven)
PURCHASE FAILURE → SECOND PAYWALL: NO — same callback, same treatment
RELAUNCH → DISMISSAL DOWNSELL:   NO — walk-proven (terminate → relaunch)
PRODUCT SELECTION → PURCHASE CONSISTENCY: PROVEN for row → dominant price →
                                 CTA. The StoreKit transaction itself is NOT
                                 proven in this environment (no StoreKit
                                 config attached) — device/sandbox check.
RESTORE:                         PRESENT and invocable (walk-proven), on both
                                 the paywall and the stand-down
SIGN IN:                         PRESENT and invocable (walk-proven), both
TERMS:                           PRESENT, opens, returns (walk-proven)
PRIVACY:                         PRESENT (walk-proven)
APP TESTS:                       1520 executed · 2 skipped · 0 failures
                                 (+18 −9 vs pass 55, reconciled exactly)
                                 PlankFood 249/249 · PlankSync 29/29
RELEASE BUILD:                   BUILD SUCCEEDED, 0 errors
IPHONE 17 PRO MAX REVIEW WALK:   6 tests, 0 failures (4 + 2), fresh install
PHYSICAL DEVICE REQUIRED:        YES — real StoreKit purchase / restore /
                                 cancel, and one Dynamic Type pass
PRE-FIX HEAD:                    8d9b0b3e5a1ef2985b746dc1dcec4daa2a11b5c9
PRE-FIX PUSH:                    af9e962..8d9b0b3, verified via ls-remote
REVIEW-FIX COMMITS:              faf07c0 pricing hierarchy
                                 8b9dd11 dismissal presents nothing
                                 <this record>
FINAL LOCAL HEAD:                ead3d7e + this addendum (§15)
FINAL REMOTE HEAD:               ead3d7e + this addendum, verified (§15)
FINAL PUSH:                      8d9b0b3..ead3d7e, then the addendum (§15)
DIRTY TREE AFTER PUSH:           2 .gstack/ browser-tool logs, named (§15)
MARKETING VERSION:               1.2.0 — UNCHANGED (founder call, §11)
BUILD:                           33 — UNCHANGED (archive-time bump, §11)
ARCHIVED:                        NO
UPLOADED:                        NO
SUBMITTED:                       NO
READY FOR FOUNDER RELEASE AUTHORIZATION: YES — after §11 and §14
```


---

## 15. ADDENDUM — THE GIT CHECKPOINT, VERIFIED

Written after the push, because a final HEAD cannot be recorded inside
the commit that creates it. The values below were read back from the
remote, not from local state.

```
PRE-FIX BRANCH        feat/app-v2
PRE-FIX HEAD          8d9b0b3e5a1ef2985b746dc1dcec4daa2a11b5c9
PRE-FIX REMOTE HEAD   af9e962649f92ee5ff6f0c8a63b5ee829c873605
PRE-FIX DIRTY TREE    2 files, both .gstack/ browser-tool logs
PRE-FIX COMMITS       0 created — pass 53/54/55 were committed, not pushed
PRE-FIX PUSH          af9e962..8d9b0b3   VERIFIED via git ls-remote

REVIEW-FIX COMMITS    faf07c0  fix(paywall): the amount billed is the
                               dominant price, on every tier
                      8b9dd11  fix(wall): a dismissal presents nothing, and
                               the offers it summoned are gone
                      ead3d7e  docs: 56 — the app store review recovery
                      <tip>    docs: 56 §15 — the verified checkpoint

PUSH                  8d9b0b3..ead3d7e   VERIFIED
                      git ls-remote origin refs/heads/feat/app-v2
                        → ead3d7e8fc04b94585cc72b77b455b438856832e
                      local == remote, 0 ahead / 0 behind
```

**Remote content verified, not just the ref.** `git ls-tree -r
origin/feat/app-v2` confirms the remote tree carries
`SubscriptionPriceBlock.swift`, `PurchaseDismissalInvariantTests.swift`,
`PurchaseFlowReviewWalkUITests.swift`, this record and all five
screenshots — and that `WallExitIntent.swift`, `SmallerStepSheet.swift`,
`DownsellPaywallView.swift` and `WallExitIntentTests.swift` are **absent
from the remote tree**. The whole recovery is recoverable from the remote
without this machine.

### The working tree is NOT clean, and here is exactly what is in it

```
 M .gstack/browse-audit.jsonl
 M .gstack/browse-network.log
```

Both are browser-tool audit logs, appended to by a web search on
2026-08-18. `.gstack/` is in `.gitignore`; these two files are tracked
only because they predate that rule. They are disposable, unrelated to
this work, and were deliberately not committed into the review patch.
**Nothing else is modified, staged or untracked.**

### Commit boundaries, and why the first two are separable

`PaywallView.swift` is touched by both fixes, so the two commits were
split at hunk level rather than by file: hunks 2 and 4–8 (the price
column, the block, the accessibility label, the dead
`perWeekEquivalent`) went to `faf07c0`; hunks 0, 1, 3 and 9 (the
`onReclaimDownsell` parameter, the `downsellShownOnce` unlock, the
reclaim render site and `reclaimRow` itself) went to `8b9dd11`.

The split was verified, not assumed: the pricing-only tree was built,
**compiled and tested green on its own** (12/12) before `faf07c0` was
made, and the reassembled `PaywallView.swift` was `diff`-confirmed
byte-identical to the final state before `8b9dd11`. Neither commit is a
broken intermediate.
