# 82 · 1.1.8 FINAL RELEASE HARDENING

**Built 2026-09-07, after 81.** The founder's brief: the final
comprehensive product + engineering hardening pass before 1.1.8 is
archived; the marketing-version decision is made (**1.1.8**); use the
product like a customer, attack the data truth, close what is material,
stop at the archive/upload/submit/deploy boundary. Method: cold start
(law + p81 read in full, tree inspected, product launched and walked
before any code), nine parallel audit lanes (temporal truth · SIWA ·
notifications · HealthKit · data integrity · chat boundary · onboarding
· copy register · purchase/settings), findings triaged by consequence,
fixes RED→GREEN, films for every product-visible change. Evidence in
`82_evidence/` (12 items).

---

## 1 · The risk map, resolved

Classification at discovery → outcome. Everything below was found by
this pass's own walks and lanes; nothing was inherited untested.

### RELEASE BLOCKER (found 1 · fixed 1)

- **Medication reminders survived account deletion.** No identity
  boundary (sign-out / delete-account / Apple-credential revocation)
  removed `MedicationReminders.allIds`, and the weekly/daily reminders
  are REPEATING triggers — "today's your shot day." kept firing on the
  device indefinitely, under the next identity, after the account was
  gone. Health-category lock-screen content surviving deletion = the
  p37/p38 law. **FIXED**: `NotificationCensus.identityBoundaryIds`
  (one census, medication family included) read by the one sweep all
  three boundaries share; census + source pinned.

### MATERIAL BEFORE SHIP (found 6 · fixed 6)

1. **The dose-backfill door defaulted to "took it just now".**
   "+ add a past shot" opened the DoseSheet with the just-now chip
   preselected; an untouched confirm recorded `takenAt = now`,
   re-anchoring CyclePosition and the interval chain to TODAY — the
   exact opposite of the door's premise, on the founder's own named
   scenario. FIXED: the backfill door seeds the slot's own day
   (`DoseSheet.defaultWhenTakenDay`, pinned; the open-slot late face
   deliberately keeps "just now"). Filmed E2E: the sheet opens with
   "on saturday, forgot to log" selected; the ledger records "sep 5 ·
   0.5 mg" with no lateness annotation (evidence 04–06).
2. **Resolved slots re-fired their own reminders.** Weekly + daily
   repeating triggers had no resolved-today awareness — the
   morning-marked shot still got "mark it when it's taken." at her
   hour that evening, every week. FIXED: `plannedStandingRequests`
   (pure, pinned) downgrades a resolved slot's repeating trigger to a
   one-shot at the next unresolved occurrence (the interval branch's
   own arithmetic); any refresh restores the rhythm. Interval behavior
   pinned unchanged.
3. **"Master off" could be scheduled around.** A workout save re-armed
   the winback with the master toggle off; the food-settings evening
   toggle scheduled without master/auth checks and stamped the budget
   ledger. FIXED at the chokepoint: `NotificationGate.shouldSchedule`
   enforces the master toggle at the one door every non-medication
   send passes through; refusals never stamp. Pinned both ways.
4. **The chat consent sheet under-disclosed.** The envelope sends the
   menstrual-cycle phase (the app's most carefully gated signal), her
   meals, and jeni's memories; the sheet named none of them
   (5.1.2(i) sensitivity class). FIXED: the disclosure names "meals,
   … cycle rhythm, … and what jeni remembers" (pinned; filmed,
   evidence 10).
5. **A consent checkbox that gated nothing.** The consult's signature
   surface rendered "use my answers to personalize my plan" — a
   checkbox whose answer had ZERO readers, beside a sibling that
   really gates. An uncheckable fact presented as a choice (L8
   stated-promise violation, named since p29). FIXED: it is a
   DISCLOSURE row now ("your answers shape your plan"); the two real
   consents keep their boxes; the stored key keeps its wire shape
   with the honest value. Filmed (evidence 07). *Named for founder
   review since p29 once tagged the key founder/legal.*
6. **The consult was uncompletable at AX5 on the SE.** The signature +
   health moments were fixed VStacks with no scroll container (the
   p48 one-ScrollView law covered the talk column only): at AX5 the
   REQUIRED medical ack truncated and the CTA sat off-screen,
   unreachable. Filmed RED (evidence 08), FIXED with the standing
   §5.2 AX escape (the whole moment scrolls at accessibility sizes;
   titles wrap), filmed GREEN (evidence 09). Shipped this way in
   approved 1.1.7 — found by this pass's film, not inherited.

### The founder's two temporal questions, answered

**(a) A forgotten GLP-1 shot with its actual date — YES.** The whole
chain was verified end-to-end in code: "+ add a past shot" (14 days)
→ the one DoseSheet → `takenAt` on the chosen day → interval chain
re-anchors (`intervalDueDays` from the event), CyclePosition anchors
to the taken day, reminders re-derive (`nextDoseDate(events:)`), pen
count respects the statement instant, the envelope carries
`cycle_day`/`open_dose_slot` from the same engine, and the ledger
prints lateness only when real. The ONE defect in the chain was the
default chip (fix #1). Chat can now also answer "when was my last
dose?" with a dated `last_dose_day` (takenDayKey outranks the slot),
and the envelope's doors text names the backfill door.

**(b) A Food Snap assigned to the actual meal date/time — DATE yes,
TIME deliberately no, and the display stopped lying.** The words door
files "last night…" to yesterday automatically (celebration-safe,
beat-safe, HK-correct — all verified); any filed plate moves across
14 days via the plate page's day row (same id, photo travels, cloud
UPDATE). Meal TIME remains unrepresentable by law — inventing a time
is inventing a fact — but THE BOOK was printing the TELL-time as if
it were the meal's ("· 8:04am" on yesterday's spread). **Built: the
tell-clock.** `clockIsTellTime` lands on the entry (stamped at the
stated-past-day persist and at every day-move, monotone), rides the
p55 one-re-init, all five sync builds and the payload jsonb
(`clock_is_tell_time` — no schema, absent on old rows), and THE
BOOK's ledger row, facts line and VoiceOver drop the time segment for
those rows (the suppressed cohort reads "logged later" so the line
never goes empty). RED 3/4 → GREEN 4/4.

### PRODUCT QUALITY (fixed this pass)

- Lock-screen "taken" on a lingering delivered reminder filed TODAY's
  slot; it now files the reminder's own delivery day
  (`actionSlotDayKey`, pinned; ≤7-day clamp, else today).
- Copy register (the p67/p78 laws): "a snack on the record"→"logged";
  "your first down week on record."→trimmed; `cadenceWord` unknown
  "on file"→"not stated"; two chat payloads "on record"→"logged";
  em-dashes out of three Becoming plan lines, the persisted edit-note
  generator (→ interpunct, RED-pinned; historical rows keep their
  dashes, documented) and one a11y label; the day-5 onGlp1 push body
  "it's working"→"keep going" (no efficacy verdicts on a GLP-1 lock
  screen); sign-in/sign-up/forgot-password join the lowercase
  register; the sign-out alert describes her experience, not disk
  state.
- `jenimethod.*`: 4 of 5 keys were in no sign-out sweep (the §38
  class — the next account inherited enrollment/skip/ritual state).
  Swept; source-pinned against `JeniMethodState.allKeys`.
- The HK dietary-energy toggle stayed ON after write denial (the
  dead-knob class); it turns itself off now. The evening check-in
  subtitle stops naming an hour the bucket doesn't keep.
- PaywallView `purchase()` re-entrancy guard (parity with
  UpgradeMomentView); one-in-flight restore on wall + paywall.
- Notification settings time/toggle changes invalidate the ladder
  guard — the new hour takes effect today, not tomorrow.
- `PlateDetailSheet.dayWord` POSIX-pinned (its regimen twin already
  was).
- jeni-chat EF **prepared source**: the permitted-♥ line died (the
  client strips every heart glyph — the line was unreachable theater).
  NOT deployed; the founder's standing deploy gate carries it.
- New film doors: `--debug-signature-moment` · `--debug-health-moment`.

### EXONERATED (walk-caught, chased, cleared)

- **The chat "368g protein average" bubble** (walk 1): the persisted
  transcript of a pre-exoneration seeded record. A fresh live send
  answers "**73 grams** across the 6 days you logged" — agreeing with
  THE BOOK's visible days exactly (evidence 11). The tool arithmetic
  and the one fold agree; the record's own history simply preserves
  what was said when the QA seed was polluted (p81's exonerated
  class).
- **Becoming "22.4 lb to go" vs Settings goal "159.8 lb"** — not a
  goal fork: both read one goal; the to-go folds the TREND (182.2)
  while the hero prints the latest raw weigh-in (181.2). Structural,
  ~1 lb whenever the trend lags a loss week; both numbers are
  individually true (the hero is her number per p78; every sentence
  folds per p74). Changing either mid-RC risks more than it fixes —
  **deferred, named** as a composition question for the founder
  (options: hero speaks the fold; or the to-go line names its basis).
- **"my pace · not set" on a day-16 paced plan** — the settings row
  reads `onboardingPickedTier`, which the sign-out sweep removes and
  nothing restores (p43's census class). The plan's ARITHMETIC is
  unaffected (the live plan carries the rate); the row and the pace
  editor's preselection are display/baseline gaps. **Deferred,
  named**: the lossless fix is persisting the tier to the
  existing-but-writerless `users.program_intensity_tier` column —
  a protected-path + column-verify change, next release.
- The becoming movement thin page's "from apple health" provenance
  under denial — MoveSheet carries the full denial grammar; the thin
  page states provenance for a "quiet week" read that is true under
  denial (nothing came through). Left.

### SAFE TO DEFER (verified, named, unchanged)

- **SIWA token revocation — the deferral is RE-VERIFIED on fresh
  evidence, not inherited**: Apple's TN3194 (2025-10) explicitly
  blesses the implemented no-token fallback (all three steps present
  in code: deletion + manual-revocation guidance + credential-revoked
  observer); 1.1.7 was approved with this exact shape; and the staged
  B1/B2 server package carries a defect that would fail its first
  call (B2 addresses `private.apple_provider_tokens` through
  PostgREST, which does not expose `private`, and `service_role`
  holds no data grants under this project's default ACL) — it must be
  revised before ANY deploy. Founder list, next release.
- Notifications: `keeping_line_quiet` is blind to HealthKit scale
  imports (small keeping-chapter cohort); the re-signing knock can
  re-arm the same evening after signing (narrow, non-dose-anchored
  users); a second device's plate doesn't cancel tonight's review
  (the p37 two-device standing class); the interval reminder chain
  goes quiet after one unmarked slot for fully-dormant users (the
  "taken" action, any launch, or any mark re-arms it); winback's
  lapse timer measures launches, not in-app actions.
- Temporal: meal time-of-day stays unrepresentable (the clock law);
  words door stays yesterday-only V1; dose backfill capped at 14
  days; moving today's only plate off today leaves the food beat's
  done row standing (it reads "meal logged" with no invented count —
  the act happened today; every number tells the truth).
- HealthKit: sleep has no grant door after onboarding (dead
  `requestAccess`, zero callers); HRV/cycle/leanBodyMass are
  structurally ungrantable for the onboarding-granted majority;
  reinstall loses the movement/bodyMass request flags while grants
  survive (a one-record disagreement until MoveSheet's ask); the HK
  dietary export is append-only (repairs/day-moves/deletes leave the
  original sample; the in-code comment is honest); sleep multi-source
  double-count.
- Data: breathwork's uid-namespaced counters survive deletion
  on-disk; offline-delete server latency until next hydrate;
  day-reflections have no retry family; `retryPendingUpserts` is not
  uid-scoped (a switched account retries the prior account's rows
  into RLS 403s — noise, nothing crosses); the prescribed-adopt
  stance (p51 §18) stands.
- Purchase: no app-level offerings timeout (SDK's own governs); no
  auto-refetch on network return; two currency-formatter fallback
  nits on subordinate rates; the documented-but-unwired 72h offline
  re-verify signal (`entitlementVerificationIsStale`, zero consumers
  — wire or delete next pass).
- Onboarding: no mid-consult position resume (answers survive; ~30
  beats replay after a kill); the cut-question ghost scaffolding
  (nsv/fears/glp1Phase/cuisine personalization slots that can never
  fire, `actIndex`'s 13 ghost ids, `onboardingEatingCadence`'s
  always-NULL server column); the reveal's band-midpoint age vs the
  paid app's exact age (≤ ~25 kcal).
- Copy (founder rulings owed): the "floor" vocabulary family
  (MethodCatalog ×5 + consult + paywall — one ruling, then the
  fingerprint tripwire); the Info.plist purpose strings' em-dashes
  (approved binary; system-alert register); B4's dead
  `Signals.CoachSummary` "tell them plainly it's working" string
  (dead code, delete when its family goes).
- Settings (product calls, not defects): no per-family weekly-read
  toggle; no affirmative "Health connected" row; data export is a
  mailto handoff; build number not shown beside the version.

### NOT A PROBLEM (verified sound by lane + walk)

One wire path to OpenAI with every route consent-gated; the deletion
ledger / tombstones / hydrate present-only / retry idempotency /
pull-before-push launch order all standing at their chokepoints; the
one-fold laws (trendSeries, recordedKcal) hold for every consumer
added since p53; HK purpose strings enumerate exactly the 12 read
types with honest denial grammar everywhere and clean analytics;
notification lock-screen privacy (no compound/dose/weight/symptom
words — verified by quoting every payload); deep-link map complete,
wall-clock triggers DST-safe; dose backfill re-anchors everything
(§ above); backdated plates cannot fire celebrations or mark beats,
and export to HK at the stated day; the pricing hierarchy + no-
second-surface laws machine-verified again on this tree; entitlement
authority is one (`effectiveHasProAccess`), cold-launch/new-device/
sign-out/offline paths verified; pending purchases (Ask to Buy)
handled through the one `purchase_completed` fire site; restores
honest with nothing to restore; the consult's safety gate writes all
its keys on every branch; ATT single-owner at first settled surface;
units round-trip; projection math single-authority; the §45
mechanism, the p60 ATT architecture and the p27 food consent all
verified standing.

## 2 · Test results

- **App target: 1756 executed · 2 skipped · 0 failures** — p81's
  1744 + exactly the 12 new pins (`Pass82HardeningTests`), declared ==
  executed. RED proven before GREEN: 13 failures across 6 of 10 (the
  4 passers were controls); the jenimethod + taken-action pins landed
  after (the taken-action pin's pure fn was written correct at
  introduction — no separate RED artifact exists for it, stated
  plainly).
- **PlankFood: 326 executed · 0 failures** (p81's 321 + 1 interpunct
  pin + 4 tell-clock pins; tell-clock RED 3/4 with the ordinary-plate
  control passing).
- **PlankSync: 29/29** (payload field is additive; suite exact).
- **WallExitWalk 1/1 · PurchaseFlowReviewWalk 4/4 · SayItWalk 4/4**,
  each solo — both prior rejection classes re-verified dead on this
  tree, and the words-door food walk green over the changed persister.
- The `Executed 0 tests` trap fired once (new test file not in the
  test target) and was caught by count reconciliation before any
  conclusion was drawn.

## 3 · Films (evidence index)

00 cold launch (wall, pricing hierarchy standing) · 01 Home cold ·
02 becoming + lens · 03 THE BOOK (day sums reconcile to rows) ·
04 backfill DoseSheet with "on saturday, forgot to log" PRESELECTED ·
05 the ledger after: "sep 5 · 0.5 mg", no lateness annotation ·
06 regimen after backfill · 07 signature disclosure row (SE) ·
08 signature at AX5-SE, RED (ack truncated, CTA unreachable) ·
09 the same, GREEN (scrolls from the top, whole-word wraps) ·
10 the chat consent sheet naming meals/cycle/memories ·
11 the live tool answer: 73 g average agreeing with THE BOOK
(and the live EF's homework-question anti-pattern on display — the
deploy gate's necessity, re-filmed).

## 4 · Release build + scans

- `CFBundleShortVersionString = 1.1.8`, `CFBundleVersion = 37` (all
  four sites), bumped after the suites ran green on the tested tree.
- Release BUILD from clean artifacts: see §7 verdict (run after the
  bump; strings scans with firing debug-dylib controls — the p81
  lesson that Debug's real code lives in `plankAI.debug.dylib`).
- Secrets scan over tracked source: 0 hits (every match is
  documentation about keys or the staged EF's PEM-header strip).
- Customer-data scan over evidence + fixtures: 0 hits (every frame
  carries the synthetic maya persona).
- One sim consequence owned: chat film sent ONE live message on the
  standing QA account (precedented; the transcript now carries one
  more turn).

## 5 · Production dependencies (unchanged from p81, re-verified)

1. **`supabase functions deploy jeni-chat`** — the live EF still
   emits the retired register (filmed AGAIN this pass: a homework
   question on evidence 11). The prepared source gained one more
   redline (the ♥ line). Founder deploy, then one live spot-check.
2. **Publish the privacy policy** to jenifit.app/privacy from
   `docs/privacy_policy.md` (chat/OpenAI section must be live before
   1.1.8's consent sheet points at it) + confirm /terms.
3. **ASC metadata** (no "no advertising trackers" claim; Health
   mention; the EULA line) + **age-rating questionnaire** re-answer.
4. Next release, accepted: SIWA revocation (REVISE B1/B2 first — §1's
   schema/ACL defect), `users.program_intensity_tier` writer for the
   pace row, `energyAdjust` fact-kind migration, corrected A1 storage
   purge.

## 6 · Device checks owed (consolidated, unchanged + this pass's)

The standing §5/p81 list (ruler drag · scrub · sheet physics ·
haptics · ProMotion · VoiceOver order · Newsreader on OLED · ATT
recording · sandbox purchase/restore/cancel) **plus**: one backfilled
dose on hardware (chips + chain), the AX5 consult signature on a
physical SE-class device, and a real lock-screen "taken" tap the
morning after (the delivery-day slot fix).

## 7 · The final release walk

`testReviewerJourneyReleaseWalk`, solo, from an ERASED device with no
doors: the whole real consult → the wall (live prices) → close stands
the wall down immediately and NEVER offers → "see the plans" is
reversible → every later press identical → relaunch with no arguments
→ still lawful, restore present. **PASSED (345s).** The first run
FAILED — and the failure was the walker, not the product: the leg
predated the p56 5.6 fix (the offer machinery is deleted; the X never
offers) and had not run since p48, so it asserted the OLD
offer-then-stand-down ladder while the product performed the current
law that `WallExitWalkUITests` verified green on this same tree
minutes earlier. The stale-walker class (p46/p68), repaired to the
current law with the evidence in hand — nothing was changed to make
it pass.

Two sim erases this pass ⇒ up to two anonymous bootstrap accounts on
their next launches (the §45 mechanism, precedented and owned; no
credential exists for them).

## 8 · Release build proof

- `Release BUILD SUCCEEDED` from clean artifacts (`build/dd_p82rel`,
  fresh derived data; disk pre-cleaned to 18 GiB free before the
  first build — no ENOSPC window; the Debug launcher stub measured
  58,128 B, the un-truncated size).
- Product: `CFBundleShortVersionString 1.1.8` ·
  `CFBundleVersion 37` · 6 fonts in the app, 5 in the widget ·
  `PrivacyInfo.xcprivacy` present.
- Strings on the Release binary: **0 `--uitest` · 0 `--debug` ·
  0 `Fraunces` · 0 `Bodoni`**, against firing controls (the Debug
  dylib: 120/108 door markers; `JeniHeroSerif` 2 in Release — the
  p81 debug-dylib lesson applied).
- Declared `func test` census 1,756 == executed 1,756.

## VERDICT

**1.1.8 RELEASE READY — YES**, on the same two conditions p81 set
(they are prerequisites for the submission being truthful, not
product work): the jeni-chat register deploy and the live
privacy-policy publish. Every blocker and material item this pass
found in the client is fixed, RED→GREEN pinned, and filmed; both
prior rejection classes are machine-verified dead on this tree; the
full journey walks green from an erased device; the release binary is
proven clean with firing controls.

### FOUNDER RELEASE CARD

- **Marketing version:** 1.1.8 · **build:** 37 (all four pbxproj
  sites; bumped after the suites ran green).
- **Commits this pass:** the notification/backfill/consent cluster ·
  the copy/guard/sweep batch · the tell-clock · the consult AX escape
  · the walker repair + bump (this commit). Tested tree == committed
  tree.
- **Tests:** app 1,756 · 2 skipped · 0 failed (== declared) ·
  PlankFood 326/326 · PlankSync 29/29 · WallExitWalk 1/1 ·
  PurchaseFlowReviewWalk 4/4 · SayItWalk 4/4 · ReviewerJourney 1/1
  from an erased device — all solo.
- **Release build:** SUCCEEDED, clean artifacts, unsigned
  (distribution export per the standing p46/47 runbook at archive
  time); binary scans clean with firing controls.
- **Real-device checks completed by me:** none (simulator pass);
  the consolidated hardware list is §6 — led by the Newsreader-on-
  OLED look, the ATT recording for review notes, one sandbox
  purchase/restore/cancel, one backfilled dose, the AX5 consult
  signature.
- **Production/server actions requiring you:**
  ① `supabase functions deploy jeni-chat` (+ one live spot-check —
  the stale register was re-filmed this pass);
  ② publish `docs/privacy_policy.md` to jenifit.app/privacy, confirm
  /terms.
- **ASC actions requiring you:** metadata rewrite (no tracker claim ·
  Health mention · EULA line) · age-rating questionnaire · attach the
  ATT device recording to review notes.
- **Archive/upload status: NOT ARCHIVED, NOT UPLOADED, NOT
  SUBMITTED.** Nothing was deployed; no schema, no migration, no
  production mutation.
- **Exact final sequence:** device pass (§6) → deploy jeni-chat +
  publish privacy policy → verify both live → archive → export →
  validate → upload (p46/47 runbook) → ASC metadata + age rating →
  submit with the review note naming the ATT surface + recording.
