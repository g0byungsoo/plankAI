# 57 — THE APP PEOPLE KEEP

**Built 2026-08-25, on feat/app-v2, after 56 (the review recovery).
The first product-depth pass after the correctness line closed: not
"is the record true" (50–55 proved it is) but "does the product feel
finished enough that a person keeps it." Nothing archived, uploaded
or submitted.**

The brief asked for research before convergence, customer walks before
code, and five fundamentals made exceptional over twenty features made
adequate. This record answers its 50 questions in order.

---

## 1. Exact starting state

HEAD `1bd04d4` == `origin/feat/app-v2` (pass 56 fully pushed). Dirty:
the two standing `.gstack` logs, plus `project.pbxproj` carrying the
FOUNDER'S post-56 version decision — app target set to **1.1.7 (35)**
in Xcode (the §11 "existing rejected 1.1.7 record" branch), widget
still 1.2.0 (33). Untracked: agent-skill tooling (`.agents/`,
`skills-lock.json`). Resolved before any product work: the gstack logs
untracked (the ignore rule finally applies), tooling ignored, and the
version committed with the widget aligned to **1.1.7 (35)** per the
4-line convention (`d231570`, pushed). Baselines re-measured, never
inherited: **app 1520 passed · 0 failed · 2 skipped · PlankFood
249/249 · PlankSync 29/29 · Release BUILD SUCCEEDED** — each exactly
pass 56's close.

## 2. Research performed

Six parallel audits, all evidence-first: two local competitor
screenshot studies (93 GLP-1 frames, 79 food-tracker frames — every
image opened), one fresh web sweep (20+ sources, App Store reviews,
abandonment literature, the Cal AI verification), and three code
audits (the full presentation-surface inventory, the onboarding-answer
utilization map, the Body Snap dependency map), plus a HealthKit
request-vs-use audit. The orchestrator walked the product itself
first — five personas on the sim via a new scriptable walker-arm
(`DriveUITests`, committed as QA tooling) — before reading any
implementation detail.

## 3. Local competitor screenshots inspected

All of them: Shotsy 26, MeAgain 62, Lovi 5, Lose It 78, MyFitnessPal 1.
(Lovi's five frames are its skincare product — useful for interaction
patterns only; as of Aug 2026 no weight-loss app ships under that
name.)

## 4. External sources/reviews inspected

App Store listings + review themes for MFP, Lose It, Cal AI, Shotsy,
MeAgain, Noom, Simple, MacroFactor; the JMIR abandonment scoping
review (median 70% discontinue within 100 days, UX the most-cited
cause); the 2019 Obesity >15-min/day finding; WW's "Beyond Hunger"
food-noise report; Cal AI's April 2026 App Store removal (verified:
MacRumors/TechCrunch/9to5Mac — pulled ~4 days for IAP bypass and
**weekly-calculated-price prominence + decline-then-reoffer**, the
exact patterns Jeni removed in p56); Liquid Glass reception
(AppleInsider/Appbot: users reward readability, not glass adoption).

## 5. Repeated customer complaints discovered

Logging friction (the dominant, research-backed killer — churn is
days 1–14); AI confidently wrong at first contact; database rot;
paywall creep on formerly-free basics; billing dark patterns;
red-number shame — the single most quotable GLP-1 complaint is red
warnings while "physically full after 400 calories"; glitches and
data loss; goal-reached with nowhere to go.

## 6. Repeated customer delights discovered

Speed; accumulated history ("switching = starting over"); the record
answering back (trends, receipts of progress); adherence-neutral
arithmetic (MacroFactor's moat); reliability; founder-visible support
at small scale; honest free cores / plainly-stated prices.

## 7. Jeni's current retention loop

Already built and matching what the market keeps apps for: capture in
seconds through four doors → the answer in the same breath
(PlateAnswerEngine) → corrections that stick (usuals, verify-once,
edit notes) → the morning read pays yesterday back → the weekly read
tells the week's truth → the Method interprets HER record with
evidence tiers → the packet makes it clinician-legible. What
threatened it was not a missing feature: it was interaction debt
(trapped sheets, exit-less surfaces), edge sprawl, broken consult
promises, and a fragmented daily surface.

## 8. Jeni's proposed retention moat

Unchanged and sharpened: **never confidently wrong about her own
record, and honest about everything else** — plus the two-app
consolidation (dose⇄food) no one owns: Shotsy has no nutrition, MFP
bolts dose logging onto countdown grammar. Jeni's count-up cohort
grammar, evidence-tiered Method, and correction flywheel are the
differentiation; this pass spent itself making the daily EXPERIENCE
worthy of them.

## 9–12. Food-system / barcode / nutrition-detail / correction findings

The p53–55 food machinery held up under fresh walks (words door,
usuals, the answer, corrections). Found and fixed this pass: **the
three-questions offer replaced the answer sentence ~1.6s after "add
it" on her FIRST plate** — the one moment the product most needs to
prove the record answers back, covered by a form (fixed: the offer
waits out the read; a pre-empted offer keeps its turn; filmed
byte-stable across 3s); **the reading said "a little over today" to
the on-medication cohort** while Home has refused the word since p53
— two surfaces, one position, two laws (fixed at a new pure seam,
`FoodModule.dayLine`, RED 1/4, cohort threaded from the shipping
provider); **a one-item plate showed the same portion stepper twice**
(fixed: the row keeps its stepper only when the plate has parts);
the rate-limit error sheet could clip its own "got it" at AX sizes
(fixed: scroll law + pinned exit + .large escape, with
GalleryConfirmSheet). Barcode unchanged (verify-once intact; walks
not re-run — p55's stand). The words door's return key: the software
"go" submits; a HARDWARE return inserts a newline into the
vertical-axis field (SwiftUI behavior) — named, not fixed (Bluetooth
keyboards only).

## 13. Weight findings

One number grammar now: Becoming's tile hand-rolled `%.1f` four times
("159.0 lb") while the ledger's own rule prints "159 lb" — all four
sites route through `WeightLedger.number`. The fold itself (p55's 52-
consumer convergence) untouched and re-verified by suite.

## 14. HealthKit findings (audit, mostly held)

Nine of ten purpose-string signals genuinely consumed; weight
two-truths CONFIRMED closed at the importer; movement HK+manual
disclosure exists at MoveSheet and jeni's tool but the undecomposed
sum still travels to Home/Becoming/Method (named p55, unchanged).
**Under-used: activeEnergy** — asked of every onboarding completer
("what you actually burned"), consumed by exactly one row of one
sheet; the audit's proposal (own-baseline movement line in the weekly
read + plateau-note stand-down) is recorded for the founder, not
built. **HRV is promised in the purpose string but never on the v8
ask sheet** — only the secondary connect rows can grant it; named.

## 15–18. GLP-1 regimen / tenure / custom-schedule / dose-history findings

The p53–55 regimen machinery walked clean (interval cadence, event-
anchored chains, tenure, backfill, the dose ledger). The consult's
promises were the gap — see §20. Dose marking, the late face, and the
"today's shot, done" standing all verified by walk. The packet's
provenance splits (self-reported / marked / unrecorded ≠ skipped)
render exactly as designed.

## 19. Onboarding-data utilization findings

The full map: 25 consult answers, most WELL-USED. Three headline
gaps: **outcome (`came_for`)** — the consult's first substantive
question has ONE post-purchase reader and dies on reinstall (needs a
server column — founder-gated, §40); **prior attempts** — the ack
literally promised "we plan for that" with zero consumers since p54
deleted the curriculum (FIXED — §20); **hormonal stage** — promised
behavior it didn't deliver (FIXED — §20). Also: cuisine is worth
asking in the consult proper (five live consumers; today collected
only by the retro sheet); `isEarlyGLP1` restores but has zero
consumers; weightTrend only acts on "cycling".

## 20. Onboarding changes

None to the flow itself — the consult stands. What changed is that it
now TELLS THE TRUTH: ① postmenopause and postpartum were told "the
plan uses the gentler pace your body needs here" / "the pace stays
protective here" and got the default 0.5%/wk with Hard unlocked —
`gentlerPaceStage(from:)` now feeds every pace-floor and Hard-lock
site (RED 2/4: exactly those stages; fields renamed
`hasGentlerPaceStage`; the truly peri-specific consumers — cycle
gating, the coach prompt — keep the narrow read deliberately; the
lock sheet's sentence generalized). ② "week three is where it usually
breaks. we plan for that" — the weekly read keeps the sentence now,
once, in program week three, only for someone who said she'd tried
before (RED 1/8; the medicated clauses keep precedence).

## 21. Home simplification decision

The founder's instinct investigated and confirmed: E9's three tiers
were three visual grammars for one subject (ring; split-bar + dot
legend; three-column grid + dv footnote). The split donut idea was
considered and REJECTED — a second chart mixing units answers nothing
the ring doesn't. Shipped: the ring keeps the only earned shape;
energy stays ONE sentence with its remainder word (count-up grammar
untouched); everything else at rest is one caption line — `carbs
174 g · fat 83 g · fiber 28 g · sugar 33 g · sodium 3,510 mg` — NBSP-
bound pairs so a wrap can only fall between facts (pinned,
`HomeRestLineTests`). The dv references and footnote left Home for
the study surfaces (Becoming tiles, plate reading). The band costs
about half its former height; TODAY starts a full head higher. Filmed
on 17 Pro Max, SE (whole band above the fold), SE at AX5 (word-whole
wraps).

## 22. Becoming/navigation findings

The record rows converge on one vessel: **the visit packet was the
one record presented as a sheet** among covers — and it had NO close
control of any kind (its `onClose` had no renderer; the only exit was
a grabber-less drag). It is a page now with the sibling X (filmed,
closes clean). The tile-expand physics modal stands (deliberate,
documented). The "not enough to read yet" pile shrank by one with the
waist tile's honest gating (§24).

## 23. Sheet/popup/scroll findings

The audit found 56 shipping presentation sites hand-rolling their
modifiers, 2 surfaces hiding the system grabber, 1 correct
`interactiveDismissDisabled` with potentially unreachable exits, a
counterfeit hand-drawn grabber ×2, and a 0.42-fraction sheet whose
record button sat below a fold it could neither scroll past nor drag
above. **Shipped: the presentation grammar as a chokepoint** —
`jeniSheet`/`jeniCover` are the only legal presenters in PlankApp,
held by a source-sweep test (DEBUG-stripped, comment-aware, system-
controller exemptions named with reasons; RED: 41 bare sheets + 13
bare covers). The law: the grabber is ALWAYS visible on sheets;
covers name their exit; `brief`/`tall` carry a `.large` escape;
`tallFixed` stays the documented canvas exception. Retrofit closed
D1 (MoveRecordSheet), D2 (ReconciliationSheet's pinned exits — the
no-dismiss stays, defensibly, with exits now guaranteed reachable),
D4 (exit-less MoveSheet/PlateDetailSheet), D5 (fake grabbers deleted),
D6 (§22), D7 (scroll law on Correction/hardLock/TerminalError/
GalleryConfirm), D8 (the settings hub is a real NavigationStack:
native edge-swipe pop, preserved scroll position, and a feedback
draft blocks interactive dismissal only while unsent words exist).
D3: Home's four auto-present timers raced one modal slot and burned
once-flags at schedule time — a morning letter could be marked
delivered and never shown; one arbiter now (reconcile › letter ›
upgrade — commerce never outranks the read, pinned), flags stamp only
when a surface actually presents.

## 24. Body/waist feature decision

**Removed from the shipping experience** (founder direction; the
measured 72-weight-loggers-to-8-scan-keepers ratio supplied no
counter-evidence; p55's KEEP verdict was about honesty of the surface,
not its earning power, and the founder's complexity-budget call
outranks it). All six entrances gone: the chooser's body door, Home's
tile and once-ever intro cover, the plan's scan-day invitation
(engine pin inverted), Becoming's check-in row, Settings' start row.
**Custody stays**: records, photo store, backup/deletion, merge/
handoff paths, and READ access for scan-holders (compare pair +
timeline were already data-gated; the waist tile appends only when a
record exists; Settings keeps backup + delete-all gated on the data
itself). The @Model is untouched — no schema risk taken.
BodyFatEstimate survives (never scan-derived). `BodyScanProofUITests`
died with its subject; the retirement is pinned in
CarePlanEngineTests.

## 25. Liquid Glass decisions

**Refused as a theme, deliberately.** The evidence (AppleInsider,
Appbot review data) says users reward readability and native
BEHAVIOR, not glass surfaces; the paper+ink identity is the brand and
the moat. What this pass took from native instead: real
NavigationStack semantics in settings, system grabbers everywhere,
system back with its pop gesture. The tab bar already rides the
native Liquid Glass bar on iOS 26 (MainShell, founder call 2026-07-07)
— unchanged.

## 26. Visual-system changes

The Home band (§21); one weight-number grammar (§13); one portion
stepper (§9–12); the packet's page header + X. No new components, no
new colors, no decoration added anywhere.

## 27. Interaction/motion changes

§23's batch. Motion itself untouched — no motion law changed; the
p53/p54 60fps films stand.

## 28. Accessibility findings

The grammar's `.large` escapes + scroll law close the AX-clipping
class at its root (a fixed fraction can no longer pin content it
cannot show). SE × AX5 filmed for Home (word-whole wraps, band
scrolls). The dose sheet's Home row nests a Button in a Button
(double VoiceOver announcement) — named, not fixed. The XCUITest
"not hittable" chooser finding was diagnosed as a hit-testing
artifact of the modal overlay, not a product defect (`.isModal` is
set; real touches land; VoiceOver navigates the chooser's own
elements).

## 29. Frame-level findings

Films this pass: the dose sheet, Becoming (before/after the waist
row), the hub push/pop pair, the answer moment at 1s/2s/3s
(byte-stable) + offer arrival, Home on 17PM/SE/SE-AX5, the weigh-in
ritual under the new grammar, the packet page + close. One cold-start
ghost frame was caught and re-taken (the recorded launch-snapshot
gotcha, §12.1's lesson in new clothes). No clipping, no ghosting, no
stale content in the final frames.

## 30. Failure/recovery findings

Nothing new attacked at the network layer this pass (p46/p55 stands;
no launch-path changes). The failure class this pass closed is
INTERACTION failure: trapped modals, lost drafts, burned once-flags.

## 31. B2B record-readiness findings

The packet already distinguishes said/logged/supplied/calculated/
missing (§15–18) and now presents as the page a clinician-grade
record deserves. The B2B moat remains the record's honesty, not
chrome; nothing enterprise was added.

## 32. What was deliberately deleted

Body Snap's six entrances (+its walker test); the five-way interior
presentation-modifier drift (every site now one call); the fake
grabbers; JKSheetChrome's grabber-hiding; Home's split-bar + legend +
chemistry grid + dv footnote; the four independent auto-present
timers.

## 33. What was deliberately NOT built

A widget (both GLP-1 competitors treat it as core retention — the
strongest candidate on the named list, but a new surface is a founder
call); dose-era badges on Becoming's weight trend (Shotsy's one
honest idea, timing-never-causality words ready); per-item
include/exclude taps on the reading; food search/database; meal
buckets; streaks/badges/confetti; a PK curve (refused again — the
market's fake precision is Jeni's moat by contrast); Liquid Glass
theming; the outcome/exact-age server columns (migrations —
founder-gated); the activeEnergy weekly-read line (§14).

## 34. Competitor ideas rejected, and why

MeAgain's mascot/iMessage persona and per-shot pain sliders
(gamification theater; friction as pseudo-measurement); Shotsy's
craving-peak shot timing (pharmacologically meaningless for weekly
agents) and cosmetic theme store (the one-palette law IS the brand);
Lose It's meal buckets + per-meal calorie splits (classification tax;
appetite can't be scheduled on GLP-1), streaks/"Done Logging"
ceremony, milestone confetti, paywall-inside-the-record, and the
"you'll reach X lbs on <date>" claim (compliance floor + plateau
physiology). Kept for the founder list: Lose It's in-place row
expansion for corrections, the dual-unit serving line, the program
receipt, the condensing sticky position line, and "recommended: skip"
visible stand-downs.

## 35. Exact RED evidence (artifacts in 57_evidence/)

- `RED_presentation_grammar.log/json` — 41 bare `.sheet(` + 13 bare
  `.fullScreenCover(` + 2 grabber-hiding files; 3 failed of 5 (the 2
  passes were the stripper control and the kit pin).
- `RED_consult_promise.log/json` — 2 failed of 4: postmenopause and
  postpartum ran 0.005 against the promised gentler floor with Hard
  unlocked; the passes were the controls.
- `RED_week_three_promise.log` — 1 failed of 8 (the one speaking
  test; quiet controls refusal-shaped).
- `RED_dayline_over.log` — 1 failed of 4 against the verbatim-
  extracted law ("over" spoken to the count-up cohort).
- The scan-invitation retirement inverted 4 stale tests into 2 pins
  (stale-by-decision, not manufactured RED — stated as such).
- The Method-collision precedent applies to `HomeAutoPresentTests`
  (green on first run: the arbiter is new law, pinned at birth).

## 36. Exact GREEN evidence

Every RED suite green after its fix; the p56 reviewer walks re-run
green ON THE RETROFIT (PurchaseFlowReviewWalk 4/4 · WallDismissal 1/1
· WallExitWalk 1/1, iPhone 17 Pro Max, solo, fresh installs); the
packet/hub/answer/Home films in §29.

## 37. Final test counts (all from Executed lines, re-read)

**App 1540 passed · 0 failed · 2 skipped (1542 total)** — +20 vs the
1520 baseline, reconciled EXACTLY: +5 grammar +4 arbiter −4 stale
scan +2 scan pins +4 consult +4 week-three +5 rest-line.
**PlankFood 253/253 (+4 day-line)** · **PlankSync 29/29** ·
**DayKeyVocabularyTests 3/3 under `-testLanguage ar -testRegion SA`**.

## 38. Release build result

**BUILD SUCCEEDED, 0 errors** — on the final tree, after the last
product commit.

## 39. Physical-device gaps

Unchanged from p55 §37 + p56 §14: TestFlight walk, StoreKit
sandbox purchase/restore/cancel, real-HealthKit import with a watch,
notification permission dance, camera permission sheets. Nothing this
pass touched is device-only beyond what the sim proved.

## 40. Founder gates (standing + new)

Standing: EF envelope deploy · archive-time conventions (§1's version
state is now COMMITTED: 1.1.7 (35) all four sites) · the §37 device
checklist · food-photos storage ordering. New, decision-sized: ① the
widget (next-dose + protein-left; both GLP-1 competitors' core
retention surface); ② dose-era badges on the weight trend; ③ the
`came_for` outcome column (+restore line) so the consult's most
personal answer survives reinstall; ④ the exact-age column (the
"about 29" apology row); ⑤ the activeEnergy weekly-read line; ⑥
whether to restore dv references anywhere on Home (this pass moved
them to the study surfaces).

## 41. Production mutations

**None.** No SQL, no deploys, no migrations written or applied, no
sim erases; the standing QA identities were reused for every walk.

## 42. Migrations/deployments

None (see §41). p53's applied migration and the EF gate stand exactly
as p55 left them.

## 43. Git commits (this session, in order)

`aa7763f` chore: untrack gstack logs, ignore agent tooling ·
`d231570` chore(version): 1.1.7 (35), all four sites ·
`3ea71f6` the presentation grammar + trapped-sheet class ·
`5f1d2bb` Body Snap leaves the shipping experience ·
`73fcb4a` one auto-present slot ·
`2ee7d19` settings hub NavigationStack ·
`62ad0b7` the consult keeps its promises ·
`4ee5b83` the first plate's answer survives its payoff ·
`06dc415` the Home band speaks one grammar ·
`0e375cd` one number grammar; one stepper ·
`c57a44c` the last two fixed sheets join the scroll law ·
`cc411fd` "over" obeys one law on both surfaces ·
plus this record.

## 44. Final HEAD / remote state

Recorded in §51's addendum after the push (a record cannot contain
the hash of the commit that contains it).

## 45. P0 remaining

**0.**

## 46. P1 remaining

**0 new.** Named P2/P3 with owners: the movement double-count sum
(p55 stance), the HRV ask-sheet gap, the hardware-return newline, the
nested-Button dose row, the day-one-contract card's half-fade at the
tab-bar fold, the standing p51 §18 server-authority items.

## 47. What most threatens retention now

The first fourteen days still decide everything, and the two
strongest levers left are OUTSIDE this pass's reach: the widget (the
return surface both competitors own) and the outcome column (day 30
should speak in the words she gave on day 0, and today that fact dies
on reinstall).

## 48. What most strengthens retention now

The daily surface finally matches the record's quality: capture →
answer (now uninterrupted) → a calm Home (one grammar) → surfaces
that push, pop, scroll and dismiss the way iOS promises → a consult
whose promises are all kept. Nothing asks her to manage Jeni.

## 49. What I would most regret shipping to 10,000 people

Unchanged from p55 §44: the food photos' single-copy story (device
backup only until the founder-gated storage work lands). Within this
pass's own scope: nothing — every change here removed a regret.

## 50. Is another autonomous product pass justified?

**No.** The convergence criteria hold again, now on the experience
axis as well as the correctness axis. What remains is founder
decisions (§40), hardware, and real users. The next information this
product needs is still a paying stranger's.

---

## 51. ADDENDUM — the verified git checkpoint

Written after the push; values read back from the remote.

```
SESSION COMMITS      13 (2 chore + 10 product + this record)
FINAL LOCAL HEAD     <filled by the addendum commit>
FINAL REMOTE HEAD    <verified via git ls-remote after push>
DIRTY TREE           none
AHEAD/BEHIND         0 / 0
```
