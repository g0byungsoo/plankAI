# 1.1.8 (37) — FOUNDER RELEASE PACK

Companion to `82_1_1_8_FINAL_RELEASE_HARDENING.md`.
Frozen commit: **`c40f0f2c`** on `feat/app-v2` (pushed; local == remote).
Everything below is founder-gated. Nothing here has been executed.

---

## A · THE HARDWARE PASS (the minimum that justifies archive)

Simulator cannot prove these. Build to your own iPhone from
`c40f0f2c` (Debug is fine except where noted) and walk them in this
order. **~25 minutes.** Anything marked ✋ is a stop-and-tell-me.

### A1 · Fresh install, first run (≈6 min)
1. Delete Jeni from the device first (clean install matters — ATT and
   HealthKit only prompt once).
2. Launch. **ATT prompt must appear over the first consult screen,
   ~1 second in.** ✋ if it never appears — that is the p60 rejection.
   → **Screen-record this leg.** Apple wants it in the review notes.
3. Walk the consult to the paywall. Watch for: Newsreader on OLED
   (does the serif hold at 11pt eyebrows and at the 64pt hero, or does
   anything look thin/washed?), and the ruler beats — age, height,
   weight. **Drag each ruler.** ✋ if a ruler feels sticky, overshoots,
   or the haptic lands after the number changes.
4. At the signature beat, set the device to **AX5**
   (Settings → Accessibility → Display & Text Size → Larger Text, max)
   and confirm you can still reach and tap "signed". ✋ if the medical
   ack or the CTA is unreachable.

### A2 · Purchase (≈5 min) — needs a **sandbox Apple ID**
5. At the wall: prices load, **billed-today leads each row**.
6. Buy the weekly (cheapest sandbox spend). Confirm entitlement lands
   and Home appears without a relaunch.
7. Force-quit → relaunch. **No wall flash**; you land on Home.
8. Settings → account → **restore**. Confirm it says you are current.
9. (Optional, if convenient) Cancel in sandbox Settings and confirm
   the app does not lock you out mid-session.

### A3 · The daily loop, felt (≈5 min)
10. Weigh in: **drag the ruler**, save. Watch the receipt dwell and the
    haptic. ✋ if the haptic fires before the number settles.
11. Snap one real meal. Watch the scan → reading transition on
    ProMotion. ✋ on any hitch or double-animation.
12. Open Becoming → weight page → **hold-then-drag the chart scrub**.
    ✋ if the page scrolls instead of scrubbing.
13. Open any sheet and half-dismiss it — sheet physics should feel
    native, not sticky.

### A4 · GLP-1 + notifications (≈6 min) — the p82 fixes
14. Settings → your medication → set up a weekly injectable, reminder
    ON, and **allow notifications**.
15. Scroll to the record → **"+ add a past shot"** → pick a weekday.
    **The sheet must open with "on ⟨that day⟩, forgot to log" already
    selected** (not "took it just now"). Mark it taken. Confirm the
    ledger row shows that day. ✋ if the chip defaults wrong.
16. Set the reminder hour to ~2 minutes out, background the app, and
    wait for the notification. **Long-press it → "taken".** Confirm the
    dose files against the reminder's own day.
17. Tap a notification body (not the action) → confirm it deep-links
    into Today, not a blank screen.
18. Confirm no notification ever shows a compound name, dose, weight
    or symptom on the lock screen.

### A5 · HealthKit, for real (≈3 min)
19. Grant Health when asked. Confirm steps/workouts actually appear
    (Move sheet, Home steps row) — not "0", not a spinner.
20. Revoke one type in Settings → Health → Data Access → Jeni, reopen
    Jeni, and confirm the surface degrades to honest absence rather
    than showing a stale number. ✋ if a stale value persists.

### A6 · VoiceOver spot-check (≈2 min)
21. Turn VoiceOver on, on Home only. Swipe through the masthead → dial
    → today rows. Order should read top-to-bottom and the dial should
    speak its remainder as a sentence. ✋ on nonsense order.

**Not owed for this release:** exhaustive VoiceOver across all pages,
Live Activity, iPad, or a second device. Named, deferred.

---

## B · GATE A — the jeni-chat deploy (production, founder-gated)

**Why it is required:** the live function still emits the retired
register. Re-filmed this pass — evidence 11 shows it closing with a
homework question, and p81's evidence 20 shows *"it looks like this
dose has been effective for you"*, a clinical efficacy verdict Jeni
must never give. The client cannot fix a server register.

**Exact command (run from the repo root at `c40f0f2c`):**

```
supabase functions deploy jeni-chat --no-verify-jwt
```

⚠️ **Keep the flag.** The function verifies auth in-code via
`getUser()`; it was deployed `--no-verify-jwt` and dropping the flag
turns on gateway JWT verification and changes its auth posture on
release day. (p81/p82 both wrote the command without it; corrected.)

**What this deploys:** exactly one function. The diff versus what is
live is **prompt text only** — three hunks: no hearts/emoji, no vague
open questions (the homework pattern), no exclamation-praise, and a
science-posture rule that forbids judging whether a medication or dose
is "working" while explicitly permitting Jeni to *show* the observed
trend. No tool, auth, allowlist, model, cap or secret change.
`deno check` is byte-identical in error signature to the deployed
version (2× TS2345, 1× TS2739 — pre-existing, zero introduced). The
staged SIWA `B1/B2` package lives under `docs/` and is structurally
unreachable by this command.

**Verify after deploying (2 min, QA account):** open chat and ask
*"is my dose working?"* — a good answer shows the trend and routes the
judgment to her prescriber; it must **not** say the dose is effective,
must not end on "is there anything specific you'd like to discuss?",
and must not open with "that's solid progress!".

---

## C · GATE B — the privacy publish (production, founder-gated)

**[CORR] The live page is not the v1.1.4 draft.** It reads
*"Last updated: 2026-08-19 · App version: 1.2.0"* and already
discloses TikTok, OpenAI, Apple Health, cycle information, RevenueCat,
Supabase, Sign in with Apple and account deletion; its "no advertising
pixels" language is correctly scoped to the website. The old
blanket-claim risk is **closed**.

**What is still wrong — and it is the real 1.1.8 blocker:** both the
live page and (until this pass) our own document state
**"We do not use the Meta SDK."** That is false. The shipping binary
embeds FBSDKCoreKit + FBAEMKit + FBSDKCoreKit_Basics, carries a
production `FacebookAppID`, initializes the SDK at launch, declares
`ep1.facebook.com` as a tracking domain, and syncs the advertising
identifier after ATT resolves. The code is correct and ATT-gated; the
disclosure was not.

`docs/privacy_policy.md` is **fixed in this commit**. Three edits are
owed on `/Users/bko/jenifit-web` (`src/app/privacy/page.tsx`) —
I did not touch that repository:

1. **Remove** "the Meta SDK" from the do-not-use sentence
   (~line 590: *"We do not use the Meta SDK, Meta Pixel, TikTok Pixel
   on the website, Firebase, …"*). Keep "Meta Pixel" — that one is
   true.
2. **Add** a Meta ad-attribution paragraph beside the TikTok one, in
   the same register (install/activation/purchase events; automatic
   in-app event logging off; IDFA only with ATT consent; no health,
   food, medication or in-app answers).
3. **Bump** the header: `App version: 1.2.0` → `1.1.8`, and
   `Last updated` → publish date.

Then confirm both `https://jenifit.app/privacy` and
`https://jenifit.app/terms` load.

---

## D · APP STORE CONNECT (prepare now, submit later)

| Item | State | Action |
|---|---|---|
| Version / build | 1.1.8 (37) | Create 1.1.8, attach build 37 after upload |
| What's New | drafted below | paste |
| Description / subtitle / keywords | unchanged | **verify the LIVE listing** carries no "no advertising trackers" claim and no plank-era fitness copy |
| Privacy nutrition label | ⚠️ **must change** | tracking = **YES**, naming **TikTok *and* Meta**; health & fitness linked to identity |
| Health disclosure | HealthKit read + optional write | confirm the Health questions match the purpose strings |
| Age rating | July-2025 questionnaire | re-answer: medical/wellness topics; **AI chatbot capability = yes** |
| Subscriptions | 3 tiers live | confirm attached and in "Ready to Submit" |
| EULA | p60 requirement | keep `Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` in the description |
| Review contact | — | your email + phone |
| Demo credentials | **not needed** | anonymous-first; reviewer reaches everything without an account |
| ATT recording | owed | the A1 step-2 screen recording |

### What's New (draft)

```
a calmer, more honest record.

· forgot to log a shot? "+ add a past shot" now records the day it
  actually happened — and your dose week follows the real date.
· a meal you log later keeps the day you ate it, and stops showing a
  time you never gave.
· reminders end when your account does, and a dose you already logged
  stops pinging you that evening.
· the consult is fully usable at the largest accessibility text sizes.
· jeni now tells you exactly what travels with your question before
  your first message.
```

### Review notes (draft — paste into ASC)

```
Jeni is a weight-management companion for people using GLP-1
medications and people who are not. It records; it does not prescribe.

ACCOUNT: no sign-in is required to review. The app creates an
anonymous account on first launch and every feature below is reachable
without credentials. Sign in with Apple is offered but optional.

ATT: the App Tracking Transparency prompt appears on the FIRST settled
screen of the first launch, roughly one second into the opening
consult question. A screen recording of that moment is attached. If
the prompt does not appear, tracking has already been answered for the
bundle — delete the app and reinstall to see it again.

SUBSCRIPTION: the paywall follows the consult. Each tier leads with
the amount billed today; "restore purchases", the terms link and the
privacy link are on the same screen. Dismissing the paywall stands it
down and never presents a second purchase offer.

HEALTH: Apple Health access is optional and read-only except for one
opt-in, off-by-default write of logged meal calories as Dietary
Energy. The app is fully functional if Health is denied.

MEDICATION (GLP-1): the app records what the user tells it — the
compound, the dose they were prescribed, the day they took it, and how
they felt. It never calculates, recommends, or adjusts a dose, and it
never judges whether a medication is working. Dose questions are
routed to the user's prescriber.

AI: chat replies are generated by a third-party model (OpenAI). Before
the first message, an explicit consent screen names OpenAI and lists
exactly what travels with the question; nothing is sent until the user
accepts. Meal photo analysis has its own separate consent primer.

ACCOUNT DELETION: Settings → account → delete account. This deletes
the server record and the local record. Users signed in with Apple are
additionally shown how to revoke the Apple credential in iOS Settings,
per TN3194.
```

---

## E · ARCHIVE (do not run until A–C are done and you authorize it)

Archive must come from **`c40f0f2c`** with the tree clean, and the
build number must stay **37**.

```
git -C /Users/bko/plankAI status --porcelain        # must be empty
git -C /Users/bko/plankAI rev-parse HEAD            # must be c40f0f2c…

xcodebuild -scheme plankAI -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Jeni_1.1.8_37.xcarchive archive
```

Then export → validate → upload per the p46/p47 runbook, and prove the
chain before submitting:

```
SOURCE c40f0f2c → ARCHIVE Info.plist 1.1.8 (37) → signed product
  → validation → the build ASC shows as 1.1.8 (37)
```

✋ If Xcode offers to auto-increment the build number, **decline** —
that would break the 1.1.8 (37) provenance this record rests on.
